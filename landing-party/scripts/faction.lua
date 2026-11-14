-- The faction across settlements: when landings come, where they land, and the tier its exports buy.
--   Landings: the first answers the player's first rocket launch; then one every landing interval (cadence), a later
--   launch bringing the late corporation's next one HASTE sooner (once between landings); at most its camps setting of a
--   corporation's settlements stand at once.
--   Tier: parts exported by mature settlements, faction-wide. Each tier unlocks units, adds damage and
--   garrison room (army.lua reads it).
local shared = require("__landing-party__.shared")
local threat = require("__landing-party__.scripts.threat")
local names = require("__landing-party__.scripts.names")
local site = require("__landing-party__.scripts.site")
local costmap = require("__landing-party__.scripts.costmap")
local firemap = require("__landing-party__.scripts.firemap")
local base = require("__landing-party__.scripts.base")
local layout = require("__landing-party__.scripts.layout")
local pods = require("__landing-party__.scripts.pods")
local landfx = require("__landing-party__.scripts.landfx")
local ops = require("__landing-party__.scripts.ops")
local army = require("__landing-party__.scripts.army")
local rd = require("__landing-party__.scripts.rd")
local war = require("__landing-party__.scripts.war")
local pact = require("__landing-party__.scripts.pact")

local faction = {}

local HASTE = 15 * 3600
-- The levers (settings, shared.lua's defaults): the time between landings (f.cadence a test's own), and a corporation's
-- standing camps, its headquarters counted. (Six standing in all was a cap of its own, MAX_ALIVE: the two corporations'
-- three each; the camps settings bound it now.)
local function cadence(f) return f.cadence or shared.setting("lp-landing-interval", shared.LANDING_MINUTES.default) * 3600 end
local function camps(corp) return shared.setting("lp-" .. corp .. "-camps", shared.MAX_CAMPS.default) end
local SECOND_CORP_LANDING = 2    -- the second corporation enters at the third landing
-- Headquarters (docs/reviews/2026-10-13-headquarters-consult.md): at level 3, or after HQ_FLOOR standing with two
-- settlements (an announced floor: a player who starves its exports must not freeze the arc), a corporation
-- consolidates and lands its headquarters CONSOLIDATE later, off the clock, HQ_DISTANCE from its richest
-- settlement. Its lander cannot be destroyed while the uplink stands; the uplink's fall brings it down and the
-- corporation withdraws: no building, rebuilding or operations; its weakest settlement falls every WITHDRAW.
local HQ_FLOOR = 5 * 3600 * 60
local CONSOLIDATE = 10 * 3600
local HQ_DISTANCE = 250
local WITHDRAW = 15 * 3600
local VACANCY_HASTE = 30 * 3600
local DISTANCE = 350
local CLEAR_OF_FACTORY = 150
local FACTORY = {"assembling-machine", "furnace", "mining-drill", "lab", "roboport", "electric-pole", "container",
  "logistic-container", "rocket-silo", "beacon", "storage-tank", "train-stop", "radar", "wall"}
-- A nest field: more than DENSE_MAX nests and worms within DENSE_RADIUS of a site (faction.site).
local DENSE_RADIUS, DENSE_MAX, DENSE_SEARCH = 150, 30, 480
local POD_WAIT = 20 * 60          -- a landing's pod takes 6.65 s to come down; past this, it lands without it
local APART = 200                -- a new landing keeps this far from every standing lander
local SITE_SEARCH = 120
local SITE_SCAN = 400             -- cells a band at most through the cheap ones (a lander's, the guns', the factory's)
local SITE_LOOK = 12              -- candidates a band, the richest, through the costly checks
local SQUAT_DISTANCE = 60         -- Grubstake's distance from the player's turrets and units
local SITE_MIN_ORE = 300
local ARTILLERY_SPARE = 20       -- past its artillery's reach (threat.artillery_reach: its prototypes, its research)

faction.TIERS = {3000, 8000, 20000, 45000}           -- parts exported to reach tiers 1..4

function faction.state()
  storage.faction = storage.faction or {tier = 0, exported = 0, landings = 0, tiers = faction.TIERS}
  return storage.faction
end

local function landers(surface)
  local out = {}
  for _, b in pairs(storage.bases) do if b.lander.valid then table.insert(out, b.lander.position) end end
  -- And the sites of settlements that stood down (war.lua): a new landing goes elsewhere.
  for _, p in ipairs(storage.failed_sites or {}) do table.insert(out, p) end
  -- And Synthexis's incubators (on nwa Kessler-Hayashi came down 204 tiles from a farm's middle, a minute after it, on
  -- the same nest field: its fortress grew into the farm; 0.2.355). A farm keeps APART from the camps in its turn.
  if surface and not storage.berth_off then
    for _, e in ipairs(surface.find_entities_filtered{name = "lp-pen", force = shared.BIOTECH.force}) do
      table.insert(out, e.position)
    end
  end
  return out
end
-- Tests: what a landing keeps APART from now.
faction.landers = landers

-- Ground generated round pos, r chunks each way. An asynchronous landing (faction.request) runs its search "dry":
-- ground not yet made is requested, not forced, and the search stops there until the engine has made it.
local function ground_ready(surface, pos, r)
  local cx, cy = math.floor(pos[1] / 32), math.floor(pos[2] / 32)
  for x = cx - r, cx + r do
    for y = cy - r, cy + r do
      if not surface.is_chunk_generated{x, y} then return false end
    end
  end
  return true
end

local function wait_for(surface, pos, r)
  if ground_ready(surface, pos, r) then return false end
  surface.request_to_generate_chunks(pos, r)
  faction.pending = true
  return true
end

-- Spawners within APPROACH_WIDTH of the straight way from a site to `from` (the player's ground), less those the
-- landing burns (base.clear_landing, 80 tiles).
local APPROACH_WIDTH, APPROACH_BURN, APPROACH_MAX = 40, 80, 6
local function approach(surface, spot, from)
  local ax, ay, bx, by = spot[1], spot[2], from.x, from.y
  local dx, dy = bx - ax, by - ay
  local len2 = math.max(1, dx * dx + dy * dy)
  local n, seen = 0, {}
  -- In boxes along the way, not the box round it: a diagonal way 1,150 tiles long read every spawner in a square of
  -- that side, and twelve candidates' searches took 22 to 30 ms (nwa, 0.2.370's timing).
  local len = math.sqrt(len2)
  local steps = math.max(1, math.ceil(len / (2 * APPROACH_WIDTH)))
  for k = 0, steps - 1 do
    local f0, f1 = k / steps, (k + 1) / steps
    local x0, y0, x1, y1 = ax + dx * f0, ay + dy * f0, ax + dx * f1, ay + dy * f1
    for _, e in pairs(surface.find_entities_filtered{area = {{math.min(x0, x1) - APPROACH_WIDTH, math.min(y0, y1) - APPROACH_WIDTH},
      {math.max(x0, x1) + APPROACH_WIDTH, math.max(y0, y1) + APPROACH_WIDTH}}, type = "unit-spawner", force = "enemy"}) do
      if not seen[e.unit_number] then
        seen[e.unit_number] = true
        local p = e.position
        local f = math.max(0, math.min(1, ((p.x - ax) * dx + (p.y - ay) * dy) / len2))
        local qx, qy = ax + dx * f - p.x, ay + dy * f - p.y
        if qx * qx + qy * qy <= APPROACH_WIDTH ^ 2 and (p.x - ax) ^ 2 + (p.y - ay) ^ 2 > APPROACH_BURN ^ 2 then n = n + 1 end
      end
    end
  end
  return n
end
faction.approach = approach

-- A landing site about `distance` from `from`, its band to `outer`: the richest cells of ore in it (ore_band) with no
-- lander within APART, out of the player's guns and factory, by the passes' rules on nests. Eight points a ring, one
-- spot each, until 0.2.370 (a point per direction had found no ore at 300 tiles on most maps, seed 2: 7 of 8 empty;
-- then the window round it, and on nwa 2 sites of 56 points).

-- Its candidates scored (faction AI step 6; docs/reviews/2026-10-23-faction-ai-audit.md), by its corporation's mind
-- (shared.CORPS[corp].mind.site): the ore by it (to three times SITE_MIN_ORE), the nests on the way to the player, the
-- nest density round it, and how far it lands from its rivals' camps (to 1,000 tiles). Scored only on a dry search
-- (an asynchronous landing, its candidates' ground requested and waited for): forcing eight candidates' ground in one
-- tick stalled a landing by over a second, so a direct landing keeps the first rich site.
local function site_score(w, surface, spot, n, density, from, corp)
  local rival = 1000
  for _, b in pairs(storage.bases or {}) do
    if b.corp ~= corp and not b.fallen and b.lander and b.lander.valid then
      local o = b.lander.position
      rival = math.min(rival, math.sqrt((o.x - spot[1]) ^ 2 + (o.y - spot[2]) ^ 2))
    end
  end
  return (w.ore or 0) * math.min(3, n / SITE_MIN_ORE) - (w.approach or 0) * approach(surface, spot, from) / APPROACH_MAX
    - (w.density or 0) * density / DENSE_MAX + (w.rival or 0) * rival / 1000
end

-- The way's map for a landing (faction.site, faction.request): what reaching `from` costs over land from each cell (water
-- no way), the guns of every faction this corporation is at war with but the player's on the way (rival camps; worms and
-- the spawners round it unless it has a pact with the biters; the user, 2026-11-02, on landings blind to one another:
-- "Yeah I'd fix that too"); the player's own guns left out, every site meets them at the end.
-- The player's edge round `from`: along EDGE_RAYS rays out from it, the last point within EDGE_STEP of a building of
-- the player's (FACTORY types), to `radius`. The way to the player is the way to its edge (read from its spawn, the
-- way ran the factory's breadth for free, and on nw a site 467 from its edge read dearer than one beyond it; 0.2.156).
local EDGE_RAYS, EDGE_STEP = 16, 32
local function player_edge(surface, from, radius)
  local pf = {}
  for _, f in pairs(game.forces) do if shared.is_player_force(f) then pf[#pf + 1] = f end end
  local out = {}
  for k = 0, EDGE_RAYS - 1 do
    local a = 2 * math.pi * k / EDGE_RAYS
    local last
    for d = 0, radius, EDGE_STEP do
      local p = {from.x + math.cos(a) * d, from.y + math.sin(a) * d}
      if surface.count_entities_filtered{position = p, radius = EDGE_STEP, force = pf, type = FACTORY, limit = 1} > 0 then last = p end
    end
    if last then out[#out + 1] = {last[1], last[2]} end
  end
  return #out > 0 and out or {{from.x, from.y}}
end

-- Built in slices (ways_start, ways_step): read at once, the 2,210-tile box of nwa's landings stalled the game about 620
-- ms (its firemap 65, its search 550; 0.2.370's timing). A landing job steps it every tick (faction.tick) before its
-- search, WAYS_FIRE tiles of the box's guns, then WAYS_CELLS cells of the search, its ground read WAYS_BLOCKS blocks at most
-- a step; kept in the job (storage), so a game saved or joined midway goes on from where it was.
-- (At 160, 3 and 120 its steps on nwa took up to 28 ms; a frame is 16.7.)
-- (At 40 cells, peaks of 9.7 ms; at 24, about 6, the whole about 8 s.)
local WAYS_FIRE, WAYS_BLOCKS, WAYS_CELLS = 64, 2, 24
local function ways_start(surface, from, radius, corp)
  local own = shared.CORPS[corp] and game.forces[shared.CORPS[corp].force]
  local shooters, types, deaths = {}, {"ammo-turret", "electric-turret", "fluid-turret", "unit"}, nil
  for _, f in pairs(game.forces) do
    if own and f ~= own and shared.is_corp(f.name) and not own.get_cease_fire(f) then shooters[#shooters + 1] = f end
  end
  if own and not pact.has(corp) then
    types[#types + 1] = "turret"
    deaths = {}
    for _, n in ipairs(shared.NEST_FORCES) do if game.forces[n] then shooters[#shooters + 1] = game.forces[n] end end
    for _, e in ipairs(surface.find_entities_filtered{position = from, radius = radius, type = "unit-spawner",
      force = shared.NEST_FORCES}) do
      deaths[#deaths + 1] = {e.position.x, e.position.y, ops.PER_TURRET}
    end
  end
  return {phase = "fire", surface = surface, from = {x = from.x, y = from.y}, radius = radius, deaths = deaths,
    fire = #shooters > 0 and firemap.start(surface, from, radius, shooters, ops.PER_TURRET, types) or nil}
end
-- One step (all of it, `whole`): returns the map once done.
local function ways_step(w, whole)
  if w.phase == "fire" then
    if w.fire then
      local m = firemap.step(w.fire, not whole and WAYS_FIRE or nil)
      if not m then return nil end
      w.fmap, w.fire = m, nil
    end
    w.phase = "cost"
    w.cm = costmap.start(w.surface, w.from, w.radius, {}, {sources = player_edge(w.surface, w.from, w.radius), n = 24,
      fire = w.fmap, deaths = w.deaths, cell = w.radius > 1200 and costmap.CELL * 3 or costmap.CELL * 2, sliced = true})
    if not whole then return nil end
  end
  if w.phase == "cost" then
    local m = costmap.step(w.cm, not whole and {blocks = WAYS_BLOCKS, cells = WAYS_CELLS} or nil)
    if not m then return nil end
    w.map, w.cm, w.phase = m, nil, "done"
  end
  return w.map
end
local function landing_ways(surface, from, radius, corp)
  -- (Its landing job's, built in slices, when it has one: faction.ways_ready.)
  if faction.ways_ready then return faction.ways_ready end
  return ways_step(ways_start(surface, from, radius, corp), true)
end
-- The way's box: out to the furthest ring (faction.arrive's far_ring) and 60 more.
local function ways_radius(opts)
  local d0 = (opts and opts.distance) or DISTANCE
  local far = d0
  for _, e in ipairs(storage.rings or {0, 120, 240, 480, 800, 1200, 1800}) do far = math.max(far, d0 + e) end
  return far + 60
end
-- Whether a landing comes armed (faction.arrive's test, without its side effects).
local function armed_for(corp, opts)
  local armed_era = (shared.CORPS[corp] or {}).armed_era
  if not armed_era or storage.armed == false or (opts and opts.uplink) then return false end
  local era = storage.era_override
  if not era then
    era = 0
    for _, pf in pairs(game.forces) do if shared.is_player_force(pf) then era = math.max(era, ops.era(pf)) end end
  end
  return era >= armed_era
end

-- The ore round the player by band (faction.site): each chunk whose centre lies from `lo` to `hi` tiles from `from`, its
-- ore from the map generator's noise at four points (every 16 tiles), ranked by the ore of it and the eight round it,
-- ties in an order turned by the landing count. The noise is the map's and never changes: kept (ORE_BANDS), which
-- changes no result, only the time.
local ORE_BANDS, ORE_BANDS_N, ORE_RAW = {}, 0, {}
local function ore_band(surface, from, lo, hi, turn)
  local raw_key = string.format("%d:%d:%d:%d:%d", surface.index, math.floor(from.x / 32), math.floor(from.y / 32),
    math.floor(lo), math.floor(hi))
  local key = raw_key .. ":" .. turn
  if ORE_BANDS[key] then return ORE_BANDS[key] end
  -- (The noise read once a band, sorted again for each turn: keyed by the turn alone, each landing read it again.)
  local raw = ORE_RAW[raw_key]
  if raw then
    local list = {}
    for i, c in ipairs(raw) do list[i] = {c[1], c[2], c[3], (c[5] - turn) % 8, c[5]} end
    table.sort(list, function(a, b)
      if a[4] ~= b[4] then return a[4] < b[4] end
      if a[3] ~= b[3] then return a[3] > b[3] end
      if a[1] ~= b[1] then return a[1] < b[1] end
      return a[2] < b[2] end)
    ORE_BANDS[key] = list
    return list
  end
  local cells, pts, of = {}, {}, {}
  for cx = math.floor((from.x - hi) / 32), math.floor((from.x + hi) / 32) do
    for cy = math.floor((from.y - hi) / 32), math.floor((from.y + hi) / 32) do
      local d2 = (cx * 32 + 16 - from.x) ^ 2 + (cy * 32 + 16 - from.y) ^ 2
      if d2 >= lo * lo and d2 < hi * hi then
        cells[#cells + 1] = {cx, cy}
        for _, o in ipairs({{8, 8}, {24, 8}, {8, 24}, {24, 24}}) do
          pts[#pts + 1] = {cx * 32 + o[1], cy * 32 + o[2]}; of[#pts] = #cells
        end
      end
    end
  end
  local names = {}
  for _, ore in ipairs(site.ORES) do names[#names + 1] = "entity:" .. ore .. ":probability" end
  local props = pts[1] and surface.calculate_tile_properties(names, pts) or {}
  local n = {}
  for i = 1, #pts do
    for _, v in pairs(props) do
      if v[i] > 0 then n[of[i]] = (n[of[i]] or 0) + 1; break end
    end
  end
  local grid = {}
  for i, c in ipairs(cells) do if n[i] then grid[c[1] .. ":" .. c[2]] = n[i] end end
  local list = {}
  for i, c in ipairs(cells) do
    if n[i] then
      local rich = 0
      for x = -1, 1 do for y = -1, 1 do rich = rich + (grid[(c[1] + x) .. ":" .. (c[2] + y)] or 0) end end
      -- Its direction, one of eight (centred on the rings' old points), tried in the order the landing count turns:
      -- landings spread round the player as they did, not all to the richest ground.
      local ang = math.atan2(c[2] * 32 + 16 - from.y, c[1] * 32 + 16 - from.x)
      local dir = math.floor(ang / (math.pi / 4) + 0.5) % 8
      list[#list + 1] = {c[1], c[2], rich, (dir - turn) % 8, dir}
    end
  end
  table.sort(list, function(a, b)
    if a[4] ~= b[4] then return a[4] < b[4] end
    if a[3] ~= b[3] then return a[3] > b[3] end
    if a[1] ~= b[1] then return a[1] < b[1] end
    return a[2] < b[2] end)
  ORE_BANDS_N = ORE_BANDS_N + 1
  if ORE_BANDS_N > 60 then ORE_BANDS, ORE_BANDS_N, ORE_RAW = {}, 1, {} end
  ORE_BANDS[key] = list
  local copy = {}
  for i, c in ipairs(list) do copy[i] = c end
  ORE_RAW[raw_key] = copy
  return list
end

-- Why each spot the search looked at was refused, by pass (the landing's trace): nwa's second camp took a site under
-- its guns, and no record said what refused the rest.
local function refuse(why)
  local r = faction.refused
  if not r then return end
  local k = "p" .. (faction.pass or "?") .. " " .. why
  r[k] = (r[k] or 0) + 1
end
faction.refuse_tally = function() return faction.refused end

function faction.site(surface, from, distance, count, outer)
  local mind = faction.site_corp and shared.CORPS[faction.site_corp] and shared.CORPS[faction.site_corp].mind
  local weigh = faction.dry and mind and mind.site
  local best, best_score
  local start = (surface.map_gen_settings.seed + 3 * (count or 0)) % 8
  local avoid = landers(surface)
  local fallback, fallback_n = nil, -1
  local among, among_density, dense, dense_density
  -- Under the guns (pass 2): the site the fewest of the player's artillery reach, not the first clear one. Its dome
  -- holds three minutes of any number of guns' fire and is down three, and under nwa's 59 a camp lost its hull's
  -- generators in that and fell within 16 minutes, two seeds of three (the visits at 0.2.362).
  local under, under_guns, under_score
  local function guns_on(spot)
    local n = 0
    for _, pf in pairs(game.forces) do
      if shared.is_player_force(pf) then
        n = n + surface.count_entities_filtered{position = spot, radius = threat.artillery_reach(pf) + ARTILLERY_SPARE,
          force = pf, type = {"artillery-turret", "artillery-wagon"}}
      end
    end
    return n
  end
  -- Every cell of the band with ore, richest first (ore_band), not one point a direction: nwa's second camp's search
  -- looked at 56 points and found 2 sites, both across water, and landed under the player's guns (0.2.369's trace).
  local lo, hi = math.max(0, distance - SITE_SEARCH), outer or (distance + SITE_SEARCH)
  local cands = ore_band(surface, from, lo, hi, start)
  -- The player's artillery, listed once (its reach by its research, threat.artillery_reach).
  local arty = {}
  for _, pf in pairs(game.forces) do
    if not shared.is_corp(pf.name) and not shared.is_biters(pf.name) and pf.name ~= "neutral" then
      local reach = threat.artillery_reach(pf) + ARTILLERY_SPARE
      for _, g in pairs(surface.find_entities_filtered{force = pf, type = {"artillery-turret", "artillery-wagon"},
        area = {{from.x - hi - reach, from.y - hi - reach}, {from.x + hi + reach, from.y + hi + reach}}}) do
        arty[#arty + 1] = {g.position.x, g.position.y, reach}
      end
    end
  end
  local looked, waiting = 0, {}
  for i, cell in ipairs(cands) do
    if looked >= SITE_LOOK or i > SITE_SCAN then break end
    local cx, cy = cell[1], cell[2]
    -- A chunk already generated holds what is really there (the player may have mined it out).
    if surface.is_chunk_generated{cx, cy} and surface.count_entities_filtered{area = {{cx * 32, cy * 32},
      {cx * 32 + 32, cy * 32 + 32}}, type = "resource", name = site.ORES, limit = 1} == 0 then
      refuse("ore gone")
    else
      local c = {cx * 32 + 16, cy * 32 + 16}
      -- Beside the patch, not on it: a third of the way back towards its direction's point on the ring.
      local a = 2 * math.pi * cell[5] / 8
      local p = {from.x + distance * math.cos(a), from.y + distance * math.sin(a)}
      local spot = {c[1] + (p[1] - c[1]) / 3, c[2] + (p[2] - c[2]) / 3}
      local clear = true
      for _, l in ipairs(avoid) do
        if (l.x - spot[1]) ^ 2 + (l.y - spot[2]) ^ 2 < APART * APART then clear = false end
      end
      if not clear then refuse("by a lander") end
      -- Not under the player's artillery (it fires on military targets by itself, about 224 tiles, more with
      -- research): a settlement landed there would die unseen. Against a megabase they ring it, just outside.
      if clear and not faction.under_guns then
        for _, g in ipairs(arty) do
          if (g[1] - spot[1]) ^ 2 + (g[2] - spot[2]) ^ 2 <= g[3] * g[3] then clear = false; refuse("artillery"); break end
        end
      end
      -- Not on the player's army: units or turrets within 100 tiles, as it keeps out of the player's artillery. A
      -- corporation with the pact (Grubstake, the thief) squats nearer: 60, beyond a gun turret's reach by 40, in sight of
      -- the soft targets (the biter-country consult).
      if clear then
        local keep = faction.pact_site and SQUAT_DISTANCE or 100
        for _, pf in pairs(game.forces) do
          if clear and not shared.is_corp(pf.name) and not shared.is_biters(pf.name) and pf.name ~= "neutral"
            and surface.count_entities_filtered{position = spot, radius = keep, force = pf,
              type = {"unit", "electric-turret", "ammo-turret", "fluid-turret", "car", "spider-vehicle"}, limit = 1} > 0 then
            clear = false; refuse("army")
          end
        end
      end
      -- Not in the player's factory: none of its buildings within CLEAR_OF_FACTORY (the open ground between a
      -- megabase's lasers counted as clear, and landings came down inside a 1,600-tile factory, visit).
      if clear then
        for _, pf in pairs(game.forces) do
          if clear and not shared.is_corp(pf.name) and not shared.is_biters(pf.name) and pf.name ~= "neutral"
            and surface.count_entities_filtered{position = spot, radius = CLEAR_OF_FACTORY, force = pf,
              type = FACTORY, limit = 1} > 0 then
            clear = false; refuse("factory")
          end
        end
      end
      -- The candidate's own ground, generated now: nests and the ore count below need real entities.
      -- (Dry: every candidate's ground asked for at once, below, not one a second.)
      if clear and faction.dry and not ground_ready(surface, spot, 2) then
        waiting[#waiting + 1] = spot; looked = looked + 1; clear = false
      end
      if clear then
        -- Counted for the landing's trace (each is up to 25 chunks generated within the tick).
        faction.generated = (faction.generated or 0) + (surface.is_chunk_generated{math.floor(spot[1] / 32),
          math.floor(spot[2] / 32)} and 0 or 1)
        faction.candidates = (faction.candidates or 0) + 1
        looked = looked + 1
        surface.request_to_generate_chunks(spot, 2)
        surface.force_generate_chunk_requests()
      end
      -- Not on biters: a settlement landed among nests could not build there (docs/campaign.md, biters).
      -- Further from them as they evolve: 60 tiles, 100 at full evolution (200 left a maximum-evolution world no site
      -- at all, visit). On a second pass (faction.arrive) nests do not refuse a site: the lander clears its ground.
      local evo = game.forces.enemy and game.forces.enemy.get_evolution_factor(surface) or 0
      local nested = clear and surface.count_entities_filtered{position = spot, radius = 60 + 40 * evo,
        type = "unit-spawner", limit = 1} > 0
      -- And not in a nest field: nests and worms within DENSE_RADIUS (the ground generated round a candidate). Serenity
      -- landed on nw with none within 100 and 132 within 250, and spent three hours at war with biters: 369 turrets
      -- and 227 units lost, nothing left for the player. Too many and the site is "among nests", where the least dense
      -- such site wins (the first found won).
      local density = 0
      if clear and not faction.pact_site then
        density = surface.count_entities_filtered{position = spot, radius = DENSE_RADIUS, force = "enemy",
          type = {"unit-spawner", "turret"}}
        if density > DENSE_MAX and not faction.dense_ok then nested = true end
      end
      -- By approach (docs/reviews/2026-10-15-biter-country-consult.md): what decides a settlement's war is the nests
      -- between it and the player, not those beside it (camps landed nest-free 1,000 to 2,100 tiles out had 130 nests
      -- on the way and razed nothing in three hours, visit). Too many on the way refuse the site; nests beside it are
      -- allowed (its landing burns them), a nest-free site in the same ring preferred.
      if clear and faction.approach_max and approach(surface, spot, from) > faction.approach_max then
        clear = false; refuse("nests on the way")
      end
      -- A corporation with a pact with the biters (Grubstake) lands among them: they let it be.
      if clear and nested and not (faction.ignore_nests or faction.dense_ok) and not faction.pact_site then
        if faction.approach_max then
          local n = surface.count_entities_filtered{position = c, radius = 60, type = "resource", name = site.ORES}
          -- Nests beside it, not a field round it: a field waits for the further rings, then the last pass.
          if n > SITE_MIN_ORE / 2 and density <= DENSE_MAX and (not among or density < among_density) then
            among, among_density = spot, density
          end
        end
        clear = false; refuse(density > DENSE_MAX and "nest field" or "nests beside")
      end
      -- Nests allowed (the last pass): a nest field is still the last choice, the least dense of them.
      if clear and (faction.ignore_nests or faction.dense_ok) and density > DENSE_MAX then
        if not dense or density < dense_density then dense, dense_density = spot, density end
        clear = false; refuse("nest field")
      end
      if clear then
        -- (Counted to three times SITE_MIN_ORE, where its score stops rising: a rich patch's thousands were most of a
        -- candidate's checks, nwa.)
        local n = surface.count_entities_filtered{position = c, radius = 60, type = "resource", name = site.ORES,
          limit = 3 * SITE_MIN_ORE + 1}
        if n <= SITE_MIN_ORE then refuse("little ore") end
        if n > SITE_MIN_ORE then
          refuse("usable")
          if faction.under_guns and not weigh then
            local g = guns_on(spot)
            if not under or g < under_guns then under, under_guns = spot, g end
            if g == 0 then return spot end
            goto next_dir
          end
          if not weigh then
            faction.site_scored = string.format("the first clear (pass %s), %d guns in reach", faction.pass or "?", guns_on(spot))
            return spot
          end
          local sc = site_score(weigh, surface, spot, n, density, from, faction.site_corp)
          -- (Weighed too, as a real landing's search is, faction.dry: under the guns the fewest win, its score after.
          -- 0.2.363 kept the guns to the first-clear search alone, and nwa's second camp landed where it had.)
          if faction.under_guns then
            local g = guns_on(spot)
            if not under or g < under_guns or (g == under_guns and sc > (under_score or -math.huge)) then
              under, under_guns, under_score = spot, g, sc
            end
          elseif not best_score or sc > best_score then best, best_score = spot, sc end
        end
        if n > fallback_n then fallback, fallback_n = spot, n end
      end
    end
    ::next_dir::
  end
  if waiting[1] then
    for _, w in ipairs(waiting) do surface.request_to_generate_chunks(w, 2) end
    faction.pending = true
    return nil
  end
  -- No direction rich and clear: the best clear one seen (seed 2024 once landed blind on two drills' worth); by
  -- approach, a site among nests next.
  if under then
    faction.site_scored = string.format("under %d guns, the fewest", under_guns)
    return under
  end
  if best then
    faction.site_scored = string.format("scored %.2f", best_score)
    return best
  end
  local last = fallback or among or dense
  -- Held, in a landing's pass (faction.hold_fallbacks): the best poor site of all its bands, tried only once no band had a
  -- rich one. Returned at once, a first band's poor site beat a rich one further out: seed 101's camp landed by 1 candidate
  -- with "little ore", its mines found no more cells 2 minutes in, and it stood at 4 drills at minute 30.
  if faction.hold_fallbacks then
    if last then
      local kind = fallback and 1 or among and 2 or 3
      local q = fallback and fallback_n or among and -among_density or -(dense_density or 0)
      local h = faction.held
      if not h or kind < h.kind or (kind == h.kind and q > h.q) then
        faction.held = {pos = last, kind = kind, q = q, label = string.format("%s (pass %s, held over its bands), %d guns in reach",
          fallback and "the richest clear" or among and "among nests" or "the least dense nest field", faction.pass or "?",
          guns_on(last))}
      end
    end
    return nil
  end
  if last then
    faction.site_scored = string.format("%s (pass %s), %d guns in reach", fallback and "the richest clear" or among and "among nests"
      or "the least dense nest field", faction.pass or "?", guns_on(last))
  end
  return last
end

-- Map tags: each settlement marked for the player's forces with its corporation's icon and name. A tag needs
-- charted ground, and charting takes a few ticks after the landing: missing tags are retried (faction.tick).
function faction.tag(b)
  if b.tags_done then return end
  local surface = game.surfaces[b.surface]
  local c = shared.CORPS[b.corp]
  b.tags = b.tags or {}
  local all = true
  for _, f in pairs(game.forces) do
    if #f.players > 0 and not b.tags[f.name] then
      local t = f.add_chart_tag(surface, {position = {b.origin.x, b.origin.y}, icon = {type = "virtual", name = c.icon},
        text = names.of(b)})
      if t then b.tags[f.name] = t else all = false end
    end
  end
  b.tags_done = all and next(b.tags) ~= nil
end

local function announce(b, surface)
  for _, f in pairs(game.forces) do
    if #f.players > 0 then
      f.chart(surface, {{b.origin.x - 48, b.origin.y - 48}, {b.origin.x + 48, b.origin.y + 48}})
      -- A corporation's first landing is told whatever the setting (the user: the ultimate resort, "pointing the first
      -- landing of a faction"); later ones as any notice.
      storage.landing_told = storage.landing_told or {}
      local msg = {"lp.landed", shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y, surface.name)}
      if not storage.landing_told[b.corp] then f.print(msg) else shared.notice(f, msg) end -- notice-ok: first landing
    end
  end
  storage.landing_told = storage.landing_told or {}
  storage.landing_told[b.corp] = true
  faction.tag(b)
end

-- A landing now, `distance` from `from` (a table with x, y). opts as for base.land.
function faction.arrive(surface, from, opts, quiet)
  local f = faction.state()
  -- An armed landing (the user, 2026-11-01: Kessler-Hayashi "a late mid-late game foe with high tech units and bases that
  -- are armed to the teeth"): a corporation with armed_era, landing against a player at that era or later, comes down as
  -- the fortress its headquarters has (base.land: three wall rings, 52 turrets, six generators, its parts and build
  -- burst), no uplink. It grew from small at the most hostile hour and fell in four of five fed nw runs. debug_tune armed
  -- = false: never.
  local corp = (opts and opts.corp) or shared.DEFAULT_CORP
  local armed_era = (shared.CORPS[corp] or {}).armed_era
  if armed_era and storage.armed ~= false and not (opts and opts.uplink) then
    local era = storage.era_override
    if not era then
      era = 0
      for _, pf in pairs(game.forces) do if shared.is_player_force(pf) then era = math.max(era, ops.era(pf)) end end
    end
    if era >= armed_era then
      local o = {}
      for k, v in pairs(opts or {}) do o[k] = v end
      o.armed = true
      opts = o
      -- Its army armed too: the corporation at armed_level at least (its garrison cap, drop escort and units: sieges at
      -- 1, walkers at 2), as if it had exported that far. Landed armed at level 0, its fortress stood and its raids were
      -- of 2 to 10, 13 of the player's buildings in two hours (artillery base, era 3, 0.2.134).
      local lvl = (shared.CORPS[corp] or {}).armed_level
      local d = faction.corp(corp)
      if lvl and d.level < lvl then
        d.level = lvl
        d.exported = math.max(d.exported or 0, shared.LEVELS[lvl] or 0)
      end
    end
  end
  -- Further rings when the first has no clear, ore-bearing site (seed 12345: two landings blocked their
  -- neighbours at 350 tiles and the other directions were barren).
  -- A site whose pad does not fit (a headquarters' fortress found no free square within 100 tiles of its site
  -- 25 times running, every 5 minutes, a 6-hour campaign) also moves on to the next ring.
  local pos, b
  -- Further rings out to a megabase's edge: clear of the factory (CLEAR_OF_FACTORY), the near rings were all refused.
  -- A second pass with nests allowed (the lander burns its clearing, base.clear_landing): in a maximum-evolution
  -- world every ring had nests near it, and Grubstake never landed.
  -- Pass 2, against a late player (era 3 and up): under its guns. Its artillery keeps its own range clear of nests, so on
  -- a megabase in biter country the band between its factory (CLEAR_OF_FACTORY) and its artillery's reach is the one
  -- nest-free approach (landed beyond it, settlements had 18 to 101 nests between them and the player, and a clearance's
  -- hauler died deploying every time, visit). There the corporation's turrets are shelled; its lander holds on its hull
  -- (artillery fires on its own at military targets, not at generators or units), and it can reach the player.
  -- Pass 3: nests allowed, the landing burns its clearing.
  -- Pass 0, first (the biter-country consult): by approach, near rings first, nests beside the site allowed and at most
  -- APPROACH_MAX on the way to the player (Serenity's clearances reach about that many). Not for a corporation with a
  -- pact: the biters let it through.
  local late = false
  for _, pf in pairs(game.forces) do
    if shared.is_player_force(pf) and ops.era(pf) >= 3 then late = true end
  end
  if storage.era_override then late = storage.era_override >= 3 end
  -- (Not at a site already chosen: its pod's landing runs this again with opts.at, and reset here the trace read "0
  -- candidate sites" of every podded landing, nwa's second camp's among them.)
  -- (Kept only where they are: they are not saved, and a podded landing whose search came before a load, or one handed
  -- its site, found them nil and crashed the trace; pool and heist at 0.2.370.)
  if not (opts and opts.at) or not faction.candidates then faction.generated, faction.candidates, faction.refused = 0, 0, {} end
  faction.pending = false
  faction.pact_site = opts and opts.corp and pact.has(opts.corp) or false
  -- Here (its pod touched down at this site): no search; failing that (built over meanwhile), the search as ever.
  if opts and opts.at then
    b = base.land(surface, opts.at, opts)
    if b then b.approach = approach(surface, opts.at, from) end
  end
  local landing_cm
  local far_ring = ((opts and opts.distance) or DISTANCE)
  for _, e in ipairs(storage.rings or {0, 120, 240, 480, 800, 1200, 1800}) do far_ring = math.max(far_ring, ((opts and opts.distance) or DISTANCE) + e) end
  faction.reach_refused = 0
  for pass = 0, 3 do
    if b then break end
    if pass == 2 and not late then goto next_pass end
    if pass == 0 and (faction.pact_site or storage.approach_off) then goto next_pass end
    faction.approach_max = pass == 0 and APPROACH_MAX or nil
    faction.under_guns = pass == 2
    faction.pass = pass
    faction.ignore_nests = pass == 3
    -- Nest fields (the user: "on some maps you will only get dense fields of nests"): the near rings (to DENSE_SEARCH)
    -- refusing them first; then the same rings again, the least dense site of a ring taken; only then further out
    -- (avoiding them everywhere, nw's landing went 900 tiles further out, away from the player). In a field it holds
    -- its ground by clearing it.
    local schedule = {}
    local rings = storage.rings or {0, 120, 240, 480, 800, 1200, 1800}
    for _, e in ipairs(rings) do if e <= DENSE_SEARCH then schedule[#schedule + 1] = {e, false} end end
    for _, e in ipairs(rings) do if e <= DENSE_SEARCH then schedule[#schedule + 1] = {e, true} end end
    for _, e in ipairs(rings) do if e > DENSE_SEARCH then schedule[#schedule + 1] = {e, true} end end
    -- Its bands' poor sites held till the last (faction.site): the best of them tried once no band had a rich one.
    faction.hold_fallbacks, faction.held = true, nil
    schedule[#schedule + 1] = {"held"}
    for _, ring in ipairs(schedule) do
      if ring[1] == "held" then
        faction.hold_fallbacks = false
        pos = faction.held and faction.held.pos
        if pos then faction.site_scored = faction.held.label end
        faction.held = nil
      else
      local extra = ring[1]
      faction.dense_ok = ring[2]
      faction.site_corp = (opts and opts.corp) or shared.DEFAULT_CORP
      -- Its band reaches to the next ring's (the rings' bands meet; the last SITE_SEARCH past it).
      local nxt
      for _, r in ipairs(rings) do if r > extra and (not nxt or r < nxt) then nxt = r end end
      local d0 = (opts and opts.distance) or DISTANCE
      pos = faction.site(surface, from, d0 + extra, f.landings, nxt and d0 + nxt - SITE_SEARCH or d0 + extra + SITE_SEARCH)
      faction.site_corp = nil
      end
      -- An armed landing refuses a site with no way over land to the player (its way's map, read once a landing: water no
      -- way): nwa's site by this search lay across a lake from the factory, and its sieges besieged nothing. Ranking
      -- every site by its way's price instead (0.2.154 to 0.2.156) moved nw's from where it had razed most to a nest
      -- field, then to a far corner, and it razed nothing; only the site that cannot reach is refused now.
      if pos and opts and opts.armed and not storage.reach_off then
        landing_cm = landing_cm or landing_ways(surface, from, far_ring + 60, (opts and opts.corp) or shared.DEFAULT_CORP)
        if not costmap.cost(landing_cm, {x = pos[1], y = pos[2]}) then
          faction.reach_refused = (faction.reach_refused or 0) + 1
          pos = nil; refuse("no way over land")
        end
      end
      -- Dry: the settlement's reach (base.land's 15x15 chunks) made by the engine first.
      if pos and faction.dry and wait_for(surface, pos, 7) then pos = nil end
      if faction.pending then
        faction.ignore_nests, faction.under_guns, faction.pact_site, faction.approach_max = false, false, false, nil
        faction.dense_ok, faction.hold_fallbacks, faction.held = false, false, nil
        return nil, "pending"
      end
      -- Site only (a landing that comes by cargo pod): where it would land, nothing placed.
      if pos and faction.site_only then
        local at = layout.find_pad(surface, pos)
        if at then
          faction.ignore_nests, faction.under_guns, faction.pact_site, faction.approach_max = false, false, false, nil
          faction.dense_ok, faction.hold_fallbacks, faction.held = false, false, nil
          return nil, "site", pos, at
        end
        pos = nil; refuse("no pad fits")
      end
      b = pos and base.land(surface, pos, opts)
      if pos and not b then refuse("land failed") end
      if b then
        if pass == 0 then b.approach = approach(surface, pos, from) end
        if pass == 2 then b.under_guns = true; base.trace(b, "landed under the player's guns (inside its artillery's reach)") end
        break
      end
    end
    if b then break end
    ::next_pass::
  end
  faction.hold_fallbacks, faction.held = false, nil
  -- (Its way checked: the sites refused for having none, traced; f.by_way counts the landings checked, `armed`.)
  if b and landing_cm then
    f.by_way = (f.by_way or 0) + 1
    base.trace(b, string.format("its way over land to the player checked: %d sites with none refused", faction.reach_refused or 0))
  end
  faction.ignore_nests = false
  faction.under_guns = false
  faction.pact_site = false
  faction.dense_ok = false
  faction.approach_max = nil
  -- No clearing burned by a corporation at peace with the biters.
  if b and not pact.has(b.corp) then base.clear_landing(b) end
  if b then pact.place(b) end
  if b then war.barrage(b) end
  if not b then
    -- Try again later, and say why: a failed landing retried silently every 10 s once.
    f.next = game.tick + 5 * 3600
    if storage.trace then
      helpers.write_file("landing-party/decisions.txt", string.format("%8d faction  landing failed: %s\n", game.tick,
        pos and string.format("no pad fits near %.0f,%.0f", pos[1], pos[2]) or "no site clear of other landers"), true)
    end
    return nil
  end
  -- (A drop wave's landing is off the count, as off the clock below: director.lua.)
  if not (opts and opts.wave) then f.landings = f.landings + 1 end
  faction.angry(b)
  -- A world already far along: the corporation arrives with the research it would have pushed it to (rd.history).
  rd.history(b.corp, surface)
  -- The drop escort: 6 + 4 a level, doubled by a grudge, and four corner turrets, once the pad is laid
  -- (army.escort, base.corner_turrets); a headquarters lands with its fortress.
  if not (opts and opts.uplink) then
    -- Evolution: up to ten more at full (at maximum evolution, a biter or two ate the camps).
    local evo = game.forces.enemy and game.forces.enemy.get_evolution_factor(surface) or 0
    local n = 6 + 4 * (faction.corp(b.corp).level or 0) + math.floor(10 * evo)
    b.escort_due = b.grudge and shared.GRUDGE_ESCORT * n or n
  end
  ops.heard_landing(b)
  local d = faction.corp(b.corp)
  d.landed = d.landed or game.tick
  if opts and opts.uplink then
    -- A landing with an uplink is its corporation's headquarters.
    d.hq = b.id
    b.hq = true
    b.lander.destructible = false
  end
  -- A headquarters lands off the clock: the faction's origin and next landing stay as they were; so does a director's
  -- drop wave (its landings an expedition, director.lua).
  if not (opts and (opts.hq or opts.wave)) then
    f.surface, f.from = surface.index, {x = from.x, y = from.y}
    f.next = game.tick + cadence(f)
  end
  base.trace(b, string.format("landing %d of the faction (tier %d): %d candidate sites, %d on new ground; %s%s", f.landings,
    f.tier, faction.candidates, faction.generated, b.approach and (b.approach .. " nests on the way to the player")
    or "by the older passes", faction.site_scored and ("; the best of its candidates, " .. faction.site_scored) or ""))
  if faction.refused and next(faction.refused) then
    local ks = {}
    for k in pairs(faction.refused) do ks[#ks + 1] = k end
    table.sort(ks)
    local parts = {}
    for _, k in ipairs(ks) do parts[#parts + 1] = k .. " " .. faction.refused[k] end
    base.trace(b, "landing search, spots by pass: " .. table.concat(parts, ", "))
  end
  faction.site_scored = nil
  if not quiet then announce(b, surface) end
  return b
end

-- The first launch is heard; each later one brings the next landing sooner.
-- The first launch triggers the arrival (scripts/phases.lua, which may delay it); later ones bring the next
-- landing sooner.
function faction.on_launch(silo)
  local f = faction.state()
  -- The opening's (phases.on_launch): before any landing a launch triggers the first; and, when its arrival is the
  -- rocket, it opens the late corporation's gate. (Called before the first landing only until 0.2.223: a launch after
  -- Grubstake's landing never opened the gate, and Kessler-Hayashi came to no real game; the visits ran gates_off.)
  local opened = faction.on_trigger and faction.on_trigger(silo.surface, silo.position)
  if f.surface and not opened and f.next and not f.haste_for then
    -- Its late corporation's landing alone, once between landings (the user, 2026-11-02, on Grubstake landing every 6
    -- minutes on nwa, its launches never stopping: "I didn't think every rocket launch should bring grubstake in...
    -- that's a different clock"). Grubstake keeps the cadence.
    local late = faction.late_corp
    local d = late and faction.corp(late)
    if late and d and shared.enabled(late) and not d.withdrawing and faction.alive(late) < camps(late)
      and (not faction.gate_open or faction.gate_open(late)) then
      f.next = math.max(game.tick, f.next - HASTE)
      f.haste_for = late
    end
  end
end

local function alive(corp)
  local n = 0
  for _, b in pairs(storage.bases) do
    -- A settlement stood down (war.lua) leaves its place to a new landing.
    -- (Nor an expedition, a director's drop wave, till it settles: director.lua.)
    if b.lander.valid and not b.quiescent and not b.expedition and (not corp or b.corp == corp) then n = n + 1 end
  end
  return n
end
faction.alive = alive
faction.camps = camps

-- Which corporation the clock lands: of those in the region (the first; the second from the third landing),
-- not withdrawn, under its cap, the one with fewer settlements standing (ties: the one that landed longer ago).
local function next_corp(f)
  local names = {}
  for corp in pairs(shared.CORPS) do table.insert(names, corp) end
  table.sort(names)
  local first = storage.phases and storage.phases.corp
  if not first then
    local lowest
    for _, b in pairs(storage.bases) do if not lowest or b.id < lowest.id then lowest = b end end
    first = lowest and lowest.corp or shared.DEFAULT_CORP
  end
  local best, bn, bt
  for _, corp in ipairs(names) do
    local d = faction.corp(corp)
    -- The late corporation as soon as its gate is open (phases.gate_open), whatever the count; the others from the
    -- second landing (with the gate open, the second landing went to Grubstake again, and Serenity waited a third).
    local gated = faction.gate_open and faction.late_corp == corp
    local entered = false
    if gated then entered = faction.gate_open(corp)
    else entered = (corp == first or f.landings >= SECOND_CORP_LANDING) and (not faction.gate_open or faction.gate_open(corp)) end
    local n = alive(corp)
    if entered and shared.enabled(corp) and not d.withdrawing and n < camps(corp) then
      local t = d.landed or -1
      if not best or n < bn or (n == bn and t < bt) then best, bn, bt = corp, n, t end
    end
  end
  -- None: the first landing was the late corporation, its gate shut, and the other waited for a second landing that
  -- could never come (no one landed again in an hour, faction). A corporation that is not gated comes then.
  if not best and f.landings >= 1 then
    for _, corp in ipairs(names) do
      local d = faction.corp(corp)
      local gated = faction.gate_open and faction.late_corp == corp
      if not gated and shared.enabled(corp) and not d.withdrawing and alive(corp) < camps(corp) then return corp end
    end
  end
  return best
end

-- Asynchronous landings: a landing generating its ground within one tick froze a megabase's game for 0.4 to 2.6 s
-- (visit). faction.request queues it; every second the search runs dry (ground missing is requested, not forced) until
-- the site and its reach are made, then lands as faction.arrive does, on the same site. Past LANDING_PATIENCE it lands
-- the old way. kind says what follows the landing: "cadence", "hq" (corp), "phases", "remote".
local LANDING_PATIENCE = 5 * 3600
function faction.request(surface, from, opts, quiet, kind, extra)
  storage.landing_jobs = storage.landing_jobs or {}
  local job = {surface = surface.index, from = {x = from.x, y = from.y}, opts = opts, quiet = quiet, kind = kind,
    since = game.tick, waits = 0}
  for k, v in pairs(extra or {}) do job[k] = v end
  table.insert(storage.landing_jobs, job)
end

function faction.pending_kind(kind)
  for _, job in ipairs(storage.landing_jobs or {}) do
    if job.kind == kind then return job end
  end
end

local after = {}

local function landing_jobs()
  local jobs = storage.landing_jobs
  if not (jobs and jobs[1]) then return end
  -- One at a time, oldest first: two searches would not see each other's lander.
  local job = jobs[1]
  local surface = game.surfaces[job.surface]
  if not surface then table.remove(jobs, 1); return end
  job.opts = job.opts or {}
  local late = game.tick - job.since > LANDING_PATIENCE
  -- An armed landing's way to the player first, in slices (faction.tick steps it); late, the rest at once.
  local corp = job.opts.corp or shared.DEFAULT_CORP
  if not job.opts.at and not job.pod and not storage.reach_off and armed_for(corp, job.opts) then
    job.ways = job.ways or ways_start(surface, job.from, ways_radius(job.opts), corp)
    if job.ways.phase ~= "done" then
      if not late then job.waits = job.waits + 1; return end
      ways_step(job.ways, true)
    end
  end
  -- By cargo pod (Space Age): the site first, a pod sent down to it, and the landing where it touches down (a pod lost
  -- or late by POD_WAIT, it lands all the same).
  if job.pod then
    if not pods.down(surface, job.pod) and game.tick - job.pod_at < POD_WAIT then return end
    job.opts.at, job.pod = job.site, nil
  elseif not storage.pods_off then
    faction.dry, faction.site_only = not late, true
    faction.ways_ready = job.ways and job.ways.map
    local _, why, pos, at = faction.arrive(surface, job.from, job.opts, job.quiet)
    faction.dry, faction.site_only = false, false
    faction.ways_ready = nil
    if why == "pending" then job.waits = job.waits + 1; return end
    if why == "site" then
      local corp = (job.opts and job.opts.corp) or shared.DEFAULT_CORP
      job.pod = pods.send(surface, at, shared.CORPS[corp].force)
      if job.pod then
        job.site, job.pod_at, job.pad = pos, game.tick, at
        -- Escorts beside it, for the look (a landing party, not a crate).
        for _, d in ipairs({{-9, 6}, {9, 6}}) do
          pods.send(surface, {at[1] + d[1], at[2] + d[2]}, shared.CORPS[corp].force)
        end
        -- Its hull's shadow and fall, timed to the landing, onto its pod's pad (landfx.lua: drawn only).
        landfx.descent(surface, pos, at, corp, game.tick + landfx.AFTER_POD)
        return
      end
      job.opts.at = pos
    end
  end
  faction.dry = not late and not job.opts.at
  faction.ways_ready = job.ways and job.ways.map
  local b, why = faction.arrive(surface, job.from, job.opts, job.quiet)
  faction.dry = false
  faction.ways_ready = nil
  job.opts.at = nil
  if why == "pending" then job.waits = job.waits + 1; return end
  table.remove(jobs, 1)
  storage.last_landing = {id = b and b.id, waits = job.waits, ticks = game.tick - job.since, forced = late, pad = job.pad,
    lander = b and b.lander.valid and {b.lander.position.x, b.lander.position.y} or nil}
  if b then
    base.trace(b, string.format("landed %d s after it was called (%d waits for ground)%s",
      math.floor((game.tick - job.since) / 60), job.waits, late and ", the last forced" or ""))
  end
  if after[job.kind] then after[job.kind](job, b) end
end

-- A director's drop wave's landing (director.start_wave): an expedition from its landing (director.lua resolves it).
after.wave = function(job, b)
  if not b then return end
  b.expedition = {since = game.tick, wave = job.wave}
  base.trace(b, string.format("an expedition of drop wave %s", tostring(job.wave)))
end

function faction.tick(tick)
  local lj = storage.landing_jobs and storage.landing_jobs[1]
  if lj and lj.ways and lj.ways.phase ~= "done" then ways_step(lj.ways) end
  if tick % 60 == 0 then landing_jobs() end
  if tick % 600 ~= 0 then return end
  for _, b in pairs(storage.bases) do
    if b.lander.valid and not b.tags_done then faction.tag(b) end
  end
  local f = faction.state()
  if f.next and tick >= f.next and f.surface then
    -- (A landing a launch hastened is its late corporation's: faction.on_launch.)
    local hasted = f.haste_for
    f.haste_for = nil
    local corp = hasted and alive(hasted) < camps(hasted) and hasted or next_corp(f)
    if faction.pending_kind("cadence") then
      -- Its ground is being made (faction.request).
    elseif corp then
      -- After a corporation withdrew, the survivor's next landing starts from the vacancy it left.
      local origin = f.from
      local from = origin
      if f.vacancy and f.vacancy.corp ~= corp then from = f.vacancy.pos; f.vacancy = nil end
      faction.request(game.surfaces[f.surface], from, {corp = corp}, storage.quiet, "cadence", {origin = origin})
    else
      f.next = tick + cadence(f)
    end
  end
  faction.headquarters(tick)
end

-- Headquarters: consolidation, the landing, withdrawal (see the constants above).
local function tell(key, ...)
  for _, force in pairs(game.forces) do
    if #force.players > 0 then shared.notice(force, {key, ...}) end
  end
end

function faction.headquarters(tick)
  local f = faction.state()
  if not f.surface then return end
  local fast = storage.hq_fast
  for corp in pairs(shared.CORPS) do
    local d = faction.corp(corp)
    local standing = alive(corp)
    if not d.hq and not d.withdrawing and standing > 0 then
      local floor = d.landed and tick - d.landed >= (fast and 2 * 3600 or HQ_FLOOR) and standing >= 2
      if not d.consolidating and (shared.capable(corp, "headquarters", d.level) or floor) then
        d.consolidating = tick + (fast and 3600 or CONSOLIDATE)
        tell("lp.consolidating", shared.corp_label(corp))
      elseif d.consolidating and tick >= d.consolidating then
        local richest
        for _, b in pairs(storage.bases) do
          if b.corp == corp and b.lander.valid and (not richest or (b.exported or 0) > (richest.exported or 0)) then
            richest = b
          end
        end
        if richest and not d.hq_pending then
          d.hq_pending = true
          faction.request(game.surfaces[richest.surface], richest.origin,
            {corp = corp, uplink = true, hq = true, distance = HQ_DISTANCE}, storage.quiet, "hq", {corp = corp})
        end
      end
    end
    -- Withdrawal: the weakest settlement falls every WITHDRAW until none stands.
    if d.withdrawing and standing > 0 and tick >= (d.next_withdraw or 0) then
      local weakest
      for _, b in pairs(storage.bases) do
        if b.corp == corp and b.lander.valid and (not weakest or (b.exported or 0) < (weakest.exported or 0)) then
          weakest = b
        end
      end
      if weakest then
        weakest.lander.destructible = true
        tell("lp.withdrawing-" .. corp, string.format("[gps=%d,%d,%s]", weakest.origin.x, weakest.origin.y,
          game.surfaces[weakest.surface].name))
        weakest.lander.die()
      end
      d.next_withdraw = tick + (fast and 2 * 3600 or WITHDRAW)
    end
  end
end

-- Tiers no longer add damage (a hidden evolution factor by another name, design review 2026-10-13); they will
-- buy capabilities per corporation (docs/campaign.md, development).

-- Parts sent off-world by a mature settlement.
-- A corporation's development (per corporation, from its own exports).
-- The grudge (docs/reviews/2026-10-14-artillery-consult.md, revised in the hull consult): a lander destroyed by a
-- player force provokes its own corporation against that force for good; the others take note (a threat where the
-- killer stood, its defences counted stronger) without being provoked, so a player fighting the thief does not make
-- the wall-builder an enemy. The fallen settlement's corporation lands its next settlement angry: able to besiege
-- whatever its level, a doubled escort, and double the garrison cap for 30 minutes from its first depot (army.cap).
function faction.grudge(b, by, at)
  ops.provoke(b.force, by)
  for _, o in pairs(storage.bases) do
    if o.force ~= b.force and not o.fallen and o.surface == b.surface and o.lander.valid then
      ops.alarmed(o, at or b.origin)
    end
  end
  local d = faction.corp(b.corp)
  d.grudges = (d.grudges or 0) + 1
  -- Its revenge (setting lp-revenge-landings): off, its corporation is provoked, its next landing comes as any other.
  if not shared.setting("lp-revenge-landings", true) then
    base.trace(b, "grudge: every corporation provoked by " .. by .. "; no revenge landing (off)")
    return
  end
  d.grudge = by
  base.trace(b, "grudge: every corporation provoked by " .. by .. "; the next landing comes angry")
  local f = game.forces[by]
  if f and #f.players > 0 then shared.notice(f, {"lp.grudge", shared.corp_label(b.corp)}) end
end

-- The next landing after a grudge carries it (called by arrive).
function faction.angry(b)
  local d = faction.corp(b.corp)
  if not d.grudge then return end
  b.grudge = d.grudge
  d.grudge = nil
  base.trace(b, "landed with a grudge against " .. b.grudge)
  local f = game.forces[b.grudge]
  if f and #f.players > 0 then
    shared.notice(f, {"lp.grudge-landed", shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y,
      game.surfaces[b.surface].name)})
  end
end

function faction.corp(corp)
  storage.corps = storage.corps or {}
  storage.corps[corp] = storage.corps[corp] or {level = 0, exported = 0}
  return storage.corps[corp]
end

local CAP_NOTICE = {["lp-harrier"] = "lp.cap-harrier", ["lp-walker"] = "lp.cap-walker", siege = "lp.cap-siege",
  pickets_see = "lp.cap-pickets", headquarters = "lp.cap-headquarters"}
function faction.develop(b, parts)
  local d = faction.corp(b.corp)
  d.exported = d.exported + parts
  rd.fund(b.corp, parts)
  war.fund(b.corp, parts)
  while shared.LEVELS[d.level + 1] and d.exported >= shared.LEVELS[d.level + 1] do
    d.level = d.level + 1
    local gained = {}
    for cap, lvl in pairs(shared.CORPS[b.corp].caps or {}) do
      if lvl == d.level and CAP_NOTICE[cap] then table.insert(gained, CAP_NOTICE[cap]) end
    end
    table.sort(gained)
    base.trace(b, string.format("%s reaches level %d: %s", b.corp, d.level, table.concat(gained, ", ")))
    local list = {""}
    for i, key in ipairs(gained) do
      if i > 1 then list[#list + 1] = ", " end
      list[#list + 1] = {key}
    end
    for _, f in pairs(game.forces) do
      if #f.players > 0 and #gained > 0 then
        shared.notice(f, {"lp.develop", shared.corp_label(b.corp), list})
      end
    end
  end
end

function faction.export(b, parts)
  local f = faction.state()
  f.exported = f.exported + parts
  b.exported = (b.exported or 0) + parts
  faction.develop(b, parts)
  while f.tiers[f.tier + 1] and f.exported >= f.tiers[f.tier + 1] do
    f.tier = f.tier + 1
    base.trace(b, string.format("faction tier %d (%d parts exported)", f.tier, f.exported))
  end
end

-- A headquarters' uplink falls: the headquarters falls with it, its corporation withdraws, the rival's next landing
-- comes sooner (from the vacancy), and the player gains the corporation's prize (a recipe).
function faction.uplink_lost(entity)
  local f = faction.state()
  local hq
  for _, b in pairs(storage.bases) do
    if b.uplink == entity or (b.hq and b.uplink and not b.uplink.valid and not b.fallen) then hq = b end
  end
  if not hq then return end
  local d = faction.corp(hq.corp)
  if d.withdrawing then return end
  d.withdrawing, d.hq_down = game.tick, game.tick
  d.next_withdraw = game.tick + (storage.hq_fast and 2 * 3600 or WITHDRAW)
  f.vacancy = {corp = hq.corp, pos = {x = hq.origin.x, y = hq.origin.y}}
  if f.next then f.next = math.max(game.tick, f.next - VACANCY_HASTE) end
  tell("lp.hq-down-" .. hq.corp, string.format("[gps=%d,%d,%s]", hq.origin.x, hq.origin.y, game.surfaces[hq.surface].name))
  for _, force in pairs(game.forces) do
    if not shared.is_corp(force.name) and not shared.is_biters(force.name) and force.name ~= "neutral" then
      local t = force.technologies["lp-prize-" .. hq.corp]
      if t then t.researched = true end
    end
  end
  base.trace(hq, string.format("%s headquarters destroyed: withdrawing", hq.corp))
  if hq.lander.valid then
    hq.lander.destructible = true
    hq.lander.die()
  end
end

-- Base reports exports through this hook (base cannot require this module: it is required by it).
base.on_export = faction.export
-- Where a landing by pod will stand, asked again once its pods are down (landfx.lua: its hull steers onto it).
landfx.locate = layout.find_pad

-- What follows an asynchronous landing (faction.request), by kind.
after.cadence = function(job, b)
  -- The cadence's origin stays where it was (a landing from a vacancy does not move it).
  faction.state().from = job.origin
end
after.hq = function(job, hq)
  local d = faction.corp(job.corp)
  d.hq_pending = nil
  if hq then
    d.consolidating = nil
    tell("lp.headquarters", shared.corp_label(job.corp), string.format("[gps=%d,%d,%s]", hq.origin.x, hq.origin.y,
      game.surfaces[hq.surface].name))
  else
    d.consolidating = game.tick + 5 * 3600
  end
end
after.dev = function(job, b)
  -- /lp land (dev.lua): its parts, and the player told where.
  local p = job.dev_player and game.get_player(job.dev_player)
  local corp = job.opts and job.opts.corp or shared.DEFAULT_CORP
  local msg = b and string.format("%s landed: %d [gps=%d,%d,%s]", shared.CORPS[corp].name, b.id, b.origin.x, b.origin.y,
    game.surfaces[b.surface].name) or "no site to land on at that distance"
  if b then b.parts = (b.parts or 0) + (job.dev_parts or 0) end
  if p then p.print(msg) else log("lp dev: " .. msg) end -- notice-ok: the dev tool's reply to its caller
end
after.phases = function(job, b)
  local phases = storage.phases
  if phases then phases.arrived = game.tick end
end

return faction
