-- A base: its economy (bins -> feedstock -> fabricators -> parts), its builder (a queue of entities
-- paid in parts) and its planner (the first rule that applies queues a module).
local shared = require("__landing-party__.shared")
local modules = require("__landing-party__.scripts.modules")
local site = require("__landing-party__.scripts.site")
local layout = require("__landing-party__.scripts.layout")
local chart = require("__landing-party__.scripts.chart")
local names = require("__landing-party__.scripts.names")
local blocks = require("__landing-party__.scripts.blocks")
local army = require("__landing-party__.scripts.army")
local rng = require("__landing-party__.scripts.rng")
local ops = require("__landing-party__.scripts.ops")

local base = {}

local ECONOMY_TICKS = 60
local BUILD_TICKS = 90
local PLAN_TICKS = 300
local START_PARTS = 150
-- A new mining module sits within reach of the network; the base looks further only when nothing nearer
-- fits (a long pylon line out to a distant patch is how it sprawls).
local REACHES = {40, 90, 160}
local SEARCH = 200           -- ore search radius around the lander
local SITE_BUDGET = 12       -- candidate mining sites tested per plan
local UPLINK_PARTS = 3000    -- the uplink lands with these: its fortress is built at once
local UPLINK_BURST = 6       -- entities placed per build step while the uplink stands
local DEFENCE_RADIUS = 14
-- A destroyed node is rebuilt unless a hostile turret, unit, vehicle, wall or character stands this close.
-- Walls do not count: occupation needs a military presence, not a cheap barrier.
local OCCUPY_RADIUS = 12
local OCCUPIERS = {"character", "ammo-turret", "electric-turret", "fluid-turret", "artillery-turret", "unit",
  "car", "spider-vehicle"}
-- A rebuild waits for its constructor: a fixed delay plus travel from the lander.
local REBUILD_DELAY = 60 * 60
local REBUILD_TILES_PER_SECOND = 1
local EMA = 0.1              -- smoothing of the per-minute rates, per economy tick

-- Feedstock one fabricator consumes per minute.
local FAB_FEED_PER_MIN = 60 * shared.FABRICATOR_SPEED / shared.PART_SECONDS * shared.FEEDSTOCK_PER_PART

local function force(b) return game.forces[b.force] end

local function trace(b, text)
  local line = string.format("%8d base %d  %s", game.tick, b.id, text)
  if storage.trace then helpers.write_file("landing-party/decisions.txt", line .. "\n", true) end
  table.insert(b.log, line)
  if #b.log > 30 then table.remove(b.log, 1) end
end
base.trace = trace

local LISTS = {["lp-pylon"] = "pylons", ["lp-bin"] = "bins", ["lp-drill"] = "drills",
  ["lp-fabricator"] = "fabs", ["lp-generator"] = "gens", ["lp-turret"] = "turrets", ["lp-radar"] = "radars",
  ["lp-wall"] = "walls", ["lp-depot"] = "depots", ["lp-launchpad"] = "launchpads", ["lp-lamp"] = "lamps",
  ["lp-mine"] = "mines", ["lp-flamer"] = "flamers", ["lp-scrap-cannon"] = "turrets", ["lp-gun-turret"] = "turrets"}

local function register(b, e, module)
  local list = LISTS[shared.kind_of(e.name)]
  -- Lists added after a settlement was saved are made on first use.
  if list then b[list] = b[list] or {}; table.insert(b[list], e) end
  if module then table.insert(module.entities, e) end
  storage.owner[e.unit_number] = {base = b.id, module = module}
end

-- Drop what is gone or no longer the faction's (a captured drill stays valid, on another force).
local function prune(list)
  local j = 0
  for i = 1, #list do
    if list[i].valid and shared.is_corp(list[i].force.name) then j = j + 1; list[j] = list[i] end
  end
  for i = #list, j + 1, -1 do list[i] = nil end
end

local function clear_area(surface, name, pos)
  local cb = prototypes.entity[name].collision_box
  local area = {{pos[1] + cb.left_top.x - 0.5, pos[2] + cb.left_top.y - 0.5},
    {pos[1] + cb.right_bottom.x + 0.5, pos[2] + cb.right_bottom.y + 0.5}}
  -- Items on the ground too: a wreck's loot lies where it stood, and a rebuild could not be placed over it (occupy, defend).
  -- What the player has not picked up by then, the corporation reclaims.
  for _, e in pairs(surface.find_entities_filtered{area = area, type = {"tree", "simple-entity", "item-entity"}}) do e.destroy() end
end

-- Land a settlement near pos. opts: seed, doctrine (else drawn from the seed).
function base.land(surface, pos, opts)
  opts = opts or {}
  local corp = opts.corp or shared.DEFAULT_CORP
  local f = game.forces[shared.CORPS[corp].force]
  -- The settlement's whole reach, generated now: the planner's scan reads ore and terrain from it (generating
  -- only the core and queueing the rest changed where outposts went, and three outpost scenarios failed).
  surface.request_to_generate_chunks(pos, 7)
  surface.force_generate_chunk_requests()
  local id = storage.next_id
  local b = {id = id, surface = surface.index, parts = START_PARTS, feedstock = 0, made = 0, mined = 0,
    rate_in = 0, rate_parts = 0, pylons = {}, bins = {}, drills = {}, fabs = {}, gens = {}, turrets = {},
    radars = {}, walls = {}, depots = {}, launchpads = {}, lamps = {}, mines = {}, flamers = {}, pylon_spots = {}, road_tiles = 0,
    modules = {}, cells = {}, queue = {}, rebuild = {}, lost = 0, rebuilt = 0, corp = corp, force = f.name,
    rule = "landed", log = {}, waiting = nil, landed = game.tick}
  local seed = opts.seed or (surface.map_gen_settings.seed + 7919 * id + 31 * math.floor(pos[1]) + math.floor(pos[2]))
  layout.init(b, seed, opts.uplink and "fortress" or opts.doctrine, shared.CORPS[corp].doctrines)
  army.init(b)
  local at, _, uplink_at
  if opts.uplink then
    at, _, uplink_at = layout.land_fortress(b, surface, pos)
    b.parts = b.parts + UPLINK_PARTS
    -- The uplink brings construction capacity: its fortress (~650 entities) took 16 minutes one at a time.
    b.burst = UPLINK_BURST
    b.fortress_planned = {}
    if at then
      for _, e in ipairs(layout.fortress_entities(b.blocks[1].x0, b.blocks[1].y0)) do
        b.fortress_planned[e[1]] = (b.fortress_planned[e[1]] or 0) + 1
      end
    end
  else
    at = layout.land(b, surface, pos)
  end
  if not at then return nil end
  clear_area(surface, shared.variant(corp, "lp-lander"), at)
  local lander = surface.create_entity{name = shared.variant(corp, "lp-lander"), position = at, force = f}
  if not lander then return nil end
  storage.next_id = id + 1
  b.lander = lander
  if uplink_at then
    clear_area(surface, shared.variant(corp, "lp-uplink"), uplink_at)
    b.uplink = surface.create_entity{name = shared.variant(corp, "lp-uplink"), position = uplink_at, force = f}
  end
  b.origin = {x = math.floor(lander.position.x), y = math.floor(lander.position.y)}
  base.claim_map(b)
  storage.bases[id] = b
  site.scan_init(b, SEARCH)
  if not opts.uplink then base.drop_power(b) end
  b.label = rendering.draw_text{text = "", surface = surface, target = {entity = lander, offset = {0, -5}},
    color = {0.7, 0.9, 1}, scale = 1.4, alignment = "center"}.id
  trace(b, string.format("landed at %.0f,%.0f: doctrine %s, first hub %s", at[1], at[2], b.doctrine,
    b.hubs[1].archetype))
  return b
end

-- The landing burns a clearing (the user: "a landing could significantly damage/destroy nests and biters in a
-- radius"): spawners, worms and biters within CLEAR_RADIUS of a new lander are destroyed, the corporation's kills (so
-- the spawners' evolution is refunded, biters.lua), with explosions where they stood; the players are told.
local CLEAR_RADIUS = 80
function base.clear_landing(b)
  local s = b.lander.surface
  local c = b.lander.position
  local f = b.lander.force
  local nests = 0
  for _, e in pairs(s.find_entities_filtered{position = c, radius = CLEAR_RADIUS, force = "enemy",
    type = {"unit-spawner", "turret", "unit"}}) do
    if e.valid then
      if e.type ~= "unit" then
        nests = nests + 1
        s.create_entity{name = "big-explosion", position = e.position}
      end
      e.die(f, b.lander)
    end
  end
  s.create_entity{name = "massive-explosion", position = c}
  b.cleared = nests
  if nests > 0 then
    trace(b, string.format("the landing burned a clearing: %d nests and worms destroyed", nests))
    for _, pf in pairs(game.forces) do
      if #pf.players > 0 and not shared.is_corp(pf.name) then
        shared.notice(pf, {"lp.landing-cleared", shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", c.x, c.y, s.name), nests})
      end
    end
  end
end

-- The drop escort's turrets (docs/reviews/2026-10-14-hull-consult.md): four gun turrets at the pad's corners,
-- fed from the settlement's stock (they are in b.turrets), so a camp is not bare for its first twenty minutes.
-- They are the drop's, not the settlement's: never rebuilt, and packed up CAMP_TICKS after landing (kept, they
-- made every young settlement too strong for a rival's raids, and two corporations never fought: rivals).
local CAMP_TICKS = 20 * 3600
-- The drop's power: two generators beside the lander from the moment it lands, so its hull holds (half its counted
-- generators standing; the player's artillery does not fire at generators by itself). Landed under a megabase's guns,
-- camps with none were shelled to death in 25 seconds, five of five (visit). The planner's own come later; these give
-- way to what it builds (make_way).
function base.drop_power(b)
  local s = b.lander.surface
  local name = shared.variant(b.corp, "lp-generator")
  local x, y = b.lander.position.x, b.lander.position.y
  b.drop_gens = {}
  for _, dx in ipairs({-6, 6}) do
    local p = s.find_non_colliding_position(name, {x + dx, y + blocks.SIZE / 2 + 4}, 8, 1)
    local g = p and s.create_entity{name = name, position = p, force = b.lander.force}
    if g then
      register(b, g, nil)
      table.insert(b.drop_gens, g)
    end
  end
end

function base.corner_turrets(b)
  local s = b.lander.surface
  -- The corporation's own turret where it is a gun turret (Grubstake's), else the default gun turret.
  local name = shared.variant(b.corp, "lp-turret")
  if prototypes.entity[name].type ~= "ammo-turret" then name = "lp-gun-turret" end
  local x, y = b.lander.position.x, b.lander.position.y
  for _, c in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
    local p = s.find_non_colliding_position(name, {x + c[1] * (blocks.PAD_W / 2 - 3), y + c[2] * (blocks.SIZE / 2 - 2)}, 4, 1)
    local t = p and s.create_entity{name = name, position = p, force = b.lander.force}
    if t then
      t.insert{name = "piercing-rounds-magazine", count = 20}
      table.insert(b.turrets, t)
      b.camp_turrets = b.camp_turrets or {}
      table.insert(b.camp_turrets, t)
    end
  end
end

local function pack_camp(b)
  if not b.camp_turrets or game.tick - (b.landed or 0) < CAMP_TICKS then return end
  for _, t in ipairs(b.camp_turrets) do
    if t.valid then
      for i = #b.turrets, 1, -1 do if b.turrets[i] == t then table.remove(b.turrets, i) end end
      t.destroy()
    end
  end
  b.camp_turrets = nil
  trace(b, "the drop's turrets packed up")
end

-- The base's network is the lander's: whatever is cut off from it stops counting.
-- Capture by holding: a mining outpost with hostile military on its ground (within OCCUPY_RADIUS of its
-- centre) and none of the faction's within CAPTURE_CLEAR for CAPTURE_TICKS changes hands, drills, bin and
-- pylon. No capture by damage (that is Proliferation's).
local CAPTURE_CLEAR = 20
local CAPTURE_TICKS = 60 * 60
-- Only the player's forces capture: a corporation's raid passing through a rival's outpost does not take it.
local function holder(b, surface, pos)
  local f = force(b)
  for _, other in pairs(game.forces) do
    if other ~= f and other.name ~= "enemy" and other.name ~= "neutral" and not shared.is_corp(other.name)
      and not f.get_cease_fire(other) then
      local e = surface.find_entities_filtered{position = pos, radius = OCCUPY_RADIUS, force = other, type = OCCUPIERS,
        limit = 1}[1]
      if e then return other end
    end
  end
end
local function capture(b)
  if storage.capture_off then return end
  local surface = game.surfaces[b.surface]
  for _, m in ipairs(b.modules) do
    local left = 0
    for _, e in ipairs(m.entities) do if e.valid and e.force.name == b.force then left = left + 1 end end
    -- Something must be left to take (a module with nothing standing was once "captured").
    if m.kind == "mining" and m.built and not m.captured and left > 0 then
      local by = holder(b, surface, m.center)
      local defended = surface.count_entities_filtered{position = m.center, radius = CAPTURE_CLEAR, force = force(b),
        type = {"unit", "spider-unit", "electric-turret", "ammo-turret"}, limit = 1} > 0
      if by and not defended then
        -- Occupied: it calls for help as a building under fire does (an undefended outpost was taken by holding it,
        -- and the corporation never knew, siege).
        if not m.held_since then army.alarm(b, {x = m.center[1], y = m.center[2]}, trace) end
        m.held_since = m.held_since or game.tick
        if game.tick - m.held_since >= CAPTURE_TICKS then
          m.captured = by.name
          local n = 0
          for _, e in ipairs(m.entities) do
            if e.valid and e.force.name == b.force then
              storage.owner[e.unit_number] = nil
              e.force = by
              n = n + 1
            end
          end
          b.captured = (b.captured or 0) + 1
          if base.on_capture then base.on_capture(surface, m.center) end
          trace(b, string.format("captured by %s: mining at %.0f,%.0f (%d entities)", by.name, m.center[1], m.center[2], n))
        end
      else
        m.held_since = nil
      end
    end
  end
end

army.on_deliver = function(b, cargo) if base.on_export then base.on_export(b, cargo) end end

-- A faction building under fire: the depot answers (throttled in army.alarm).
function base.on_damaged(e)
  local own = storage.owner[e.unit_number]
  local b = own and storage.bases[own.base]
  -- A fallen settlement raises no alarm (damage in the tick its lander died crashed the intel, which read the
  -- surface through the dead lander).
  if b and not b.fallen and b.lander.valid then army.alarm(b, e.position, trace) end
end

function base.network(b)
  return b.lander.valid and b.lander.electric_network_id or nil
end

-- Bins on the network empty into feedstock; fabricators are fed feedstock and emptied of parts.
local function economy(b)
  local net = base.network(b)
  local gained, made = 0, 0
  prune(b.bins); prune(b.fabs)
  for _, bin in ipairs(b.bins) do
    local inv = bin.get_inventory(defines.inventory.chest)
    local n = inv.get_item_count()
    -- A bin counts only while its drills share the lander's network (cut the line, lose the income).
    local own = storage.owner[bin.unit_number]
    if n > 0 and own and own.module and own.module.claim then
      -- A claim's ore: carried home by its trucks where the corporation has a road (road.lua), else counted at once.
      if not (shared.CORPS[b.corp].temper or {}).prospects then inv.clear(); gained = gained + n end
    elseif n > 0 and net then
      local p = bin.surface.find_entities_filtered{name = shared.variants("lp-pylon"), position = bin.position, radius = 5,
        limit = 1}[1]
      if p and p.electric_network_id == net then inv.clear(); gained = gained + n end
    end
  end
  b.feedstock = b.feedstock + gained
  b.mined = b.mined + gained
  local per = 2 * shared.FEEDSTOCK_PER_PART
  for _, fab in ipairs(b.fabs) do
    local input = fab.get_inventory(defines.inventory.crafter_input)
    local want = per - input.get_item_count("lp-feedstock")
    local give = math.min(want, b.feedstock)
    if give > 0 then b.feedstock = b.feedstock - input.insert{name = "lp-feedstock", count = give} end
    local out = fab.get_inventory(defines.inventory.crafter_output)
    local c = out.get_item_count("lp-part")
    if c > 0 then out.remove{name = "lp-part", count = c}; made = made + c end
  end
  b.parts = b.parts + made
  b.made = b.made + made
  -- Flamethrowers (Serenity's gates) are kept in light oil.
  for _, t in ipairs(b.flamers or {}) do
    if t.valid and t.get_fluid_count() < 50 then t.insert_fluid{name = "light-oil", amount = 100} end
  end
  -- Gun turrets (a corporation's choice instead of lasers) are kept in ammunition.
  for _, t in ipairs(b.turrets) do
    if t.valid and t.type == "ammo-turret" then
      local inv = t.get_inventory(defines.inventory.turret_ammo)
      local ammo = shared.kind_of(t.name) == "lp-scrap-cannon" and "lp-scrap-shell" or "piercing-rounds-magazine"
      if inv and inv.get_item_count() < 20 then inv.insert{name = ammo, count = 20} end
    end
  end
  local k = 3600 / ECONOMY_TICKS
  b.rate_in = (1 - EMA) * b.rate_in + EMA * gained * k
  b.rate_parts = (1 - EMA) * b.rate_parts + EMA * made * k
end

-- Wire a new pylon to every other network within reach, nearest first. The engine's auto-connect on a
-- scripted pylon left rebuilt lines dangling (seed 34: three rebuilt line pylons joined nothing).
local function join(e)
  local copper = defines.wire_connector_id.pole_copper
  local mine = e.get_wire_connector(copper, true)
  local near = e.surface.find_entities_filtered{name = shared.variants("lp-pylon"), force = e.force, position = e.position,
    radius = shared.PYLON_REACH}
  table.sort(near, function(a, c)
    local da = (a.position.x - e.position.x) ^ 2 + (a.position.y - e.position.y) ^ 2
    local dc = (c.position.x - e.position.x) ^ 2 + (c.position.y - e.position.y) ^ 2
    if da ~= dc then return da < dc end
    return a.unit_number < c.unit_number
  end)
  for _, p in ipairs(near) do
    if p ~= e and p.electric_network_id ~= e.electric_network_id then
      mine.connect_to(p.get_wire_connector(copper, true), true, defines.wire_origin.script)
    end
  end
  base.unwire(e)
end

-- Never wired to another force's pole: placed with auto_connect, a pylon was wired to a player pole within reach and the
-- two grids became one (the power tap's line ends 12 tiles from the player's pole: the camp ran on the player's power,
-- the user saw its drills in the player's network). Also called on the player's poles as they are built (control.lua).
function base.unwire(e)
  local mine = e.get_wire_connector(defines.wire_connector_id.pole_copper, false)
  if not mine then return end
  for _, c in ipairs(mine.connections) do
    if c.target.owner.force ~= e.force then mine.disconnect_from(c.target, c.origin) end
  end
end

-- Lay road tiles, never over water or an existing road.
-- Floors in the corporation's own tiles: roads, and pads (paved yards, docs/corporations.md).
local function pave(b, tiles, floor)
  local surface = game.surfaces[b.surface]
  local name = shared.variant(b.corp, "lp-" .. (floor or "road"))
  local out = {}
  for _, t in ipairs(tiles) do
    local tile = surface.get_tile(t[1], t[2])
    if tile.valid and tile.name ~= name and not tile.collides_with("water_tile") then
      table.insert(out, {name = name, position = t})
    end
  end
  if #out > 0 then surface.set_tiles(out, true, false, true, false) end
  b.road_tiles = b.road_tiles + #out
end


-- Place one entity for a job. Returns the entity, or nil when the spot is blocked.
-- The drop's turrets and the settlement's own units give way to what it builds: a corner turret where the pad's wall
-- goes is packed up, units standing there step aside (with a drop escort, the pad's walls, turrets and flamer were
-- skipped for good: siegetier).
local function make_way(b, surface, name, pos)
  local cb = prototypes.entity[name].collision_box
  -- Two tiles of margin: a tank's box reaches past its position.
  local area = {{pos[1] + cb.left_top.x - 2, pos[2] + cb.left_top.y - 2},
    {pos[1] + cb.right_bottom.x + 2, pos[2] + cb.right_bottom.y + 2}}
  for _, e in pairs(surface.find_entities_filtered{area = area, force = force(b)}) do
    if e.type == "unit" or e.type == "spider-unit" then
      local p = surface.find_non_colliding_position(e.name, {pos[1], pos[2] + 10}, 16, 1)
      if p then e.teleport(p) end
    else
      for i, g in ipairs(b.drop_gens or {}) do
        if g == e then
          table.remove(b.drop_gens, i)
          for j = #b.gens, 1, -1 do if b.gens[j] == e then table.remove(b.gens, j) end end
          storage.owner[e.unit_number] = nil
          e.destroy()
          break
        end
      end
      for i, t in ipairs(b.camp_turrets or {}) do
        if e.valid and t == e then
          table.remove(b.camp_turrets, i)
          for j = #b.turrets, 1, -1 do if b.turrets[j] == e then table.remove(b.turrets, j) end end
          e.destroy()
          break
        end
      end
    end
  end
end

-- by_crew: a crew builds it (crew.lua), its parts paid when it left, its own effect drawn.
local function place(b, job, by_crew)
  local surface = game.surfaces[b.surface]
  local pos = job.pos
  -- Jobs name kinds; the corporation's own prototype is what is built. A corporation with flak builds every flak-th turret
  -- as a scrap cannon (Grubstake); a lost one is rebuilt as one (its kind is what is queued).
  local flak = shared.CORPS[b.corp].flak
  if job.name == "lp-turret" and flak then
    b.turrets_placed = (b.turrets_placed or 0) + 1
    if b.turrets_placed % flak == 0 then job.name = "lp-scrap-cannon" end
  end
  local name = shared.variant(b.corp, job.name)
  clear_area(surface, name, pos)
  make_way(b, surface, name, pos)
  if job.loose then pos = surface.find_non_colliding_position(name, pos, 4, 0.5) or pos end
  local ok = surface.can_place_entity{name = name, position = pos, direction = job.dir, force = force(b)}
  local e = ok and surface.create_entity{name = name, position = pos, direction = job.dir, force = force(b),
    auto_connect = (job.name == "lp-pylon") or nil}
  if not e then return nil end
  if not by_crew then b.parts = b.parts - (shared.cost[job.name] or 0) end
  register(b, e, job.module)
  if by_crew then
    -- the crew draws its own
  elseif shared.CORPS[b.corp].crews == "truck" then
    -- A yard with crews builds with a crane's sparks, no beam (the builders consult: the beam was "decorporealized").
    surface.create_entity{name = "explosion-hit", position = e.position}
  elseif shared.CORPS[b.corp].crews == "drone" then
    -- Serenity's yard: a short beam from its nearest depot or the lander (a warp-in), not always from the lander.
    local from, fd = b.lander.valid and b.lander or nil, math.huge
    if from then fd = (from.position.x - e.position.x) ^ 2 + (from.position.y - e.position.y) ^ 2 end
    for _, d in ipairs(b.depots or {}) do
      if d.valid then
        local dd = (d.position.x - e.position.x) ^ 2 + (d.position.y - e.position.y) ^ 2
        if dd < fd then from, fd = d, dd end
      end
    end
    if from then
      rendering.draw_line{from = from, to = e, surface = surface, color = {0.5, 0.8, 1, 0.6}, width = 1,
        time_to_live = BUILD_TICKS}
    end
  elseif b.lander.valid then
    rendering.draw_line{from = b.lander, to = e, surface = surface, color = {0.5, 0.8, 1, 0.6}, width = 1,
      time_to_live = BUILD_TICKS}
  end
  if job.name == "lp-pylon" then join(e) end
  if job.name == "lp-pylon" and base.network(b) and e.electric_network_id ~= base.network(b) then
    trace(b, string.format("pylon at %.1f,%.1f did not join the network", e.position.x, e.position.y))
  end
  return e
end

function base.place_job(b, job, by_crew) return place(b, job, by_crew) end
function base.pave_job(b, job) return pave(b, job.tiles, job.floor) end

-- Forces whose presence occupies ground: every force the faction is at war with, biters excepted.
local function occupied(b, surface, pos)
  local f = force(b)
  for _, other in pairs(game.forces) do
    if other ~= f and other.name ~= "enemy" and other.name ~= "neutral" and not f.get_cease_fire(other)
      and surface.count_entities_filtered{position = pos, radius = OCCUPY_RADIUS, force = other,
        type = OCCUPIERS, limit = 1} > 0 then
      return true
    end
  end
  return false
end
base.occupied = occupied
base.occupied = occupied
site.occupied = occupied

-- Rebuild first: the first lost entity whose ground is free. Occupied ground waits.
local ECONOMY = {["lp-generator"] = true, ["lp-fabricator"] = true, ["lp-drill"] = true, ["lp-pylon"] = true}
-- What makes parts comes first: with its fabricators destroyed, a settlement spent its last 646 parts on new blocks,
-- units and two turrets while their ground was held, and once it was free had nothing to rebuild them with, nor ever
-- again (scenario occupy). Parts kept back for every pending rebuild of what makes them.
function base.reserve(b)
  local reserve = 0
  for _, job in ipairs(b.rebuild) do
    if ECONOMY[shared.kind_of(job.name)] then reserve = reserve + (shared.cost[job.name] or 0) end
  end
  return reserve
end
army.reserve = base.reserve

local function rebuild(b)
  local surface = game.surfaces[b.surface]
  local reserve = base.reserve(b)
  for i, job in ipairs(b.rebuild) do
    if game.tick < job.due then
      -- still on its way
    elseif base.footing and not base.footing(b, job) then
      -- At war and short of units: parts go to units first (scripts/war.lua).
    elseif base.crew_rebuild and base.crew_rebuild(b, job) then
      -- Beyond the yards: a crew's (crew.lua), out or waiting for one; taken, the list changed: next build step.
      if not job.crew_wait then return true end
    elseif occupied(b, surface, job.pos) then
      if not job.occupied then job.occupied = true; trace(b, string.format("cannot rebuild %s at %.0f,%.0f: occupied",
        job.name, job.pos[1], job.pos[2])) end
    else
      job.occupied = nil
      local economy = ECONOMY[shared.kind_of(job.name)]
      local need = (shared.cost[job.name] or 0) + (economy and 0 or reserve)
      -- Held back for the reserve: it steps aside, the rebuilds of what makes parts behind it go first.
      if b.parts < need and not economy and reserve > 0 then goto continue end
      if b.parts < need then b.waiting = job.name; return true end
      b.waiting = nil
      table.remove(b.rebuild, i)
      if place(b, job) then
        b.rebuilt = b.rebuilt + 1
        trace(b, string.format("rebuilt %s at %.0f,%.0f", job.name, job.pos[1], job.pos[2]))
      elseif (job.tries or 0) < 5 then
        -- Blocked (often a unit standing there): tried again in 30 s, five times (dropped at once, an outpost
        -- turret was never rebuilt, occupy).
        job.tries = (job.tries or 0) + 1
        job.due = game.tick + 30 * 60
        table.insert(b.rebuild, job)
        trace(b, string.format("cannot rebuild %s at %.0f,%.0f: blocked, again in 30 s", job.name, job.pos[1], job.pos[2]))
      else
        trace(b, string.format("cannot rebuild %s at %.0f,%.0f: blocked", job.name, job.pos[1], job.pos[2]))
      end
      return true
    end
    ::continue::
  end
  return false
end

-- Place the next queued entity if parts allow. A failed key entity abandons the rest of its module.
local function build(b)
  if rebuild(b) then return end
  -- Road tiles cost nothing and take no build step.
  -- Floors cost nothing and take no build step.
  -- A crew's module's floor waits for the crew (crew.take takes it with the rest): paved at once, a cordon post's pad
  -- lay out on the ground before its drone came (the user, 2026-10-17).
  while b.queue[1] and b.queue[1].tiles do
    if b.queue[1].module and base.crew_take and base.crew_take(b, b.queue[1]) then return end
    local job = table.remove(b.queue, 1)
    pave(b, job.tiles, job.floor)
  end
  local job = b.queue[1]
  if not job then return end
  -- A module beyond every yard goes to a crew (crew.lua), which takes its jobs off the queue or holds them for one.
  if base.crew_take and base.crew_take(b, job) then return end
  local cost = shared.cost[job.name] or 0
  if b.parts < cost + base.reserve(b) then b.waiting = job.name; return end
  b.waiting = nil
  table.remove(b.queue, 1)
  local e = place(b, job)
  if job.slot then job.slot.filled = e ~= nil end
  if not e and job.module.x0 then
    -- A block survives a blocked entity: skip it.
    trace(b, string.format("cannot place %s at %.1f,%.1f in %s: skipped", job.name, job.pos[1], job.pos[2], job.module.kind))
    return
  end
  if not e then
    trace(b, string.format("cannot place %s at %.1f,%.1f: %s abandoned", job.name, job.pos[1], job.pos[2], job.module.kind))
    job.module.failed = true
    local j = 1
    while b.queue[j] do
      if b.queue[j].module == job.module then table.remove(b.queue, j) else j = j + 1 end
    end
    return
  end
  -- Built when no entity job of the module is left (road tiles queued after it do not count: a module whose
  -- last job was paving was never marked, so it could never be captured, siege seed 777).
  local more = false
  for _, q in ipairs(b.queue) do
    if q.module == job.module and not q.tiles then more = true; break end
  end
  if not more and not job.module.built then
    job.module.built = true
    trace(b, string.format("built %s at %.0f,%.0f", job.module.kind, job.module.center[1], job.module.center[2]))
    -- The drop escort steps off once the pad is laid (spawned on landing, it stood where the pad's pylon goes).
    if job.module.kind == "pad" and b.escort_due then
      army.escort(b, b.escort_due)
      b.escort_due = nil
      base.corner_turrets(b)
    end
  end
end

-- A faction entity died: queue its rebuild at the same spot (nothing is rebuilt once the settlement fell).
function base.on_died(e, by)
  local own = storage.owner[e.unit_number]
  if not own then return end
  storage.owner[e.unit_number] = nil
  local b = storage.bases[own.base]
  local kind = shared.kind_of(e.name)
  if not b or b.fallen or kind == "lp-lander" or kind == "lp-uplink" then return end
  b.lost = b.lost + 1
  -- A lapsed claim (road.lua) is not rebuilt: it is there to take.
  if own.module and own.module.lapsed then return end
  army.alarm(b, e.position, trace)
  local d = 0
  if b.lander.valid then
    d = math.sqrt((e.position.x - b.lander.position.x) ^ 2 + (e.position.y - b.lander.position.y) ^ 2)
  end
  -- The invisible constructor's travel (a second a tile); where a crew goes (crew.lua), the crew travels instead.
  local far = base.crew_far and base.crew_far(b, {e.position.x, e.position.y})
  local due = game.tick + REBUILD_DELAY + (far and 0 or math.floor(d / REBUILD_TILES_PER_SECOND * 60))
  -- Generators come back in 90 s wherever they stand: a lander's hull holds while half of them do (hull).
  if kind == "lp-generator" then due = game.tick + 90 * 60 end
  -- What makes parts and power (generators, fabricators, drills, pylons) goes to the front: queued behind 20 walls, a
  -- camp's two generators were still waiting at the end, its hull down (loot).
  table.insert(b.rebuild, ECONOMY[kind] and 1 or #b.rebuild + 1, {name = kind, pos = {e.position.x, e.position.y},
    dir = e.direction, module = own.module, due = due})
  -- An outpost attacked earns a turret pair whatever the doctrine (the "defend" rule): a single medium biter cleared
  -- whole Grubstake outposts, whose sprawl doctrine never builds them (the user, in game, 2026-10-14).
  if own.module and own.module.kind == "mining" then own.module.attacked = true end
  trace(b, string.format("lost %s at %.0f,%.0f to %s: rebuild due at %d", e.name, e.position.x, e.position.y,
    by or "nothing", due))
end

-- Saves from before pylon spots knew their module (layout.connect): spots with no pylon and no pylon job at them are
-- dropped (a module given up left its spots as anchors), and a mining module whose pylon stands off the lander's
-- network is wired to the nearest pylon on it (the user's copper mine, chained to a coal mine never built).
function base.heal_lines()
  for _, b in pairs(storage.bases or {}) do
    if not b.fallen and b.lander and b.lander.valid and b.pylon_spots then
      local s, pylons = b.lander.surface, shared.variants("lp-pylon")
      local queued = {}
      for _, list in ipairs({b.queue, b.rebuild or {}}) do
        for _, j in ipairs(list) do
          if j.name == "lp-pylon" and j.pos then queued[string.format("%.1f,%.1f", j.pos[1], j.pos[2])] = true end
        end
      end
      local kept, dropped = {}, 0
      for _, p in ipairs(b.pylon_spots) do
        if p.m or queued[string.format("%.1f,%.1f", p[1], p[2])]
          or s.count_entities_filtered{name = pylons, position = {p[1], p[2]}, radius = 0.6, limit = 1} > 0 then
          kept[#kept + 1] = p
        else
          dropped = dropped + 1
        end
      end
      b.pylon_spots = kept
      local net, healed, fixing = base.network(b), 0, {}
      for _, m in ipairs(b.modules or {}) do
        local pylon
        if net and m.kind == "mining" and not (m.abandoned or m.failed) then
          for _, e in ipairs(m.entities or {}) do
            if e.valid and e.type == "electric-pole" then pylon = e; break end
          end
        end
        if pylon and pylon.electric_network_id ~= net and not fixing[pylon.electric_network_id] then
          fixing[pylon.electric_network_id] = true
          local best, bd
          for _, p in pairs(s.find_entities_filtered{name = pylons, force = pylon.force, position = pylon.position,
            radius = 400}) do
            if p.electric_network_id == net then
              local d = (p.position.x - pylon.position.x) ^ 2 + (p.position.y - pylon.position.y) ^ 2
              if not bd or d < bd then best, bd = p, d end
            end
          end
          if best then
            local a, x, y = best.position, pylon.position.x, pylon.position.y
            local n = math.ceil(math.sqrt(bd) / (shared.PYLON_REACH - 5)) - 1
            for i = 1, n do
              local t = i / (n + 1)
              local pt = {a.x + (x - a.x) * t, a.y + (y - a.y) * t}
              table.insert(b.queue, {name = "lp-pylon", pos = pt, loose = true, module = m})
              table.insert(b.pylon_spots, {pt[1], pt[2], m = m})
            end
            m.crew_ok, m.crew_route = nil, nil
            healed = healed + 1
          end
        end
      end
      if dropped > 0 or healed > 0 then
        trace(b, string.format("lines healed: %d stale pylon spots dropped, %d stranded mines rewired", dropped, healed))
      end
    end
  end
end

-- Queue a free-standing module (mining, outpost turrets). Mining modules lay the road spine beside them.
local function enqueue(b, m, origin, cx, cy)
  local ox, oy = origin[1], origin[2]
  local module = {kind = m.kind, center = {ox + (m.box[1] + m.box[3]) / 2, oy + (m.box[2] + m.box[4]) / 2},
    entities = {}}
  table.insert(b.modules, module)
  local first = m.entities[1]
  layout.connect(b, ox + first[2], oy + first[3], module)
  for _, s in ipairs(m.entities) do
    table.insert(b.queue, {name = s[1], pos = {ox + s[2], oy + s[3]}, dir = s[4], module = module})
  end
  if cx then
    -- The spine column next to this cell (every fourth column of the lattice is left as road).
    local L = modules.MINING_LATTICE
    local sc = cx % 4 == 2 and cx + 1 or (cx % 4 == 0 and cx - 1 or nil)
    if sc then
      local x0, y0 = b.origin.x + sc * L.x, b.origin.y + cy * L.y
      local t = {}
      for x = x0, x0 + L.x - 1 do for y = y0, y0 + L.y - 1 do table.insert(t, {x, y}) end end
      table.insert(b.queue, {tiles = t, module = module})
    end
  end
  return module
end

local function power(b)
  local supply, demand = 0, 0
  if b.lander.valid then supply = supply - shared.power["lp-lander"] end
  prune(b.gens); prune(b.drills); prune(b.turrets); prune(b.radars)
  supply = supply - #b.gens * shared.power["lp-generator"]
  -- What its power tap steals from a player's line counts as supply (scripts/tap.lua): it grows on the player's power.
  supply = supply + (b.tap_watts or 0)
  demand = #b.drills * shared.power["lp-drill"] + #b.fabs * shared.power["lp-fabricator"]
    + #b.turrets * shared.power["lp-turret"] + #b.radars * shared.power["lp-radar"]
  return supply, demand
end

-- A node (lander, generator, fabricator, mining) with no turret near it.
local function undefended(b, attacked_only)
  local surface = game.surfaces[b.surface]
  for _, m in ipairs(b.modules) do
    if m.built and m.kind == "mining" and not m.defended and (not attacked_only or m.attacked) then
      if surface.count_entities_filtered{name = shared.variants("lp-turret"), position = m.center, radius = DEFENCE_RADIUS} > 0 then
        m.defended = true
      else
        return m
      end
    end
  end
end

-- Queue a slot's entity (a fabricator or generator in a block), or open a block for it.
local function fill(b, role, entity)
  local slot, block = layout.slot(b, role, entity)
  if slot then
    slot.queued = true
    -- A settlement's first fabricator goes first: nothing makes parts without one (seed 4242's camp spent its last on
    -- other jobs and never had one).
    local first = entity == "lp-fabricator" and #b.fabs == 0
    table.insert(b.queue, first and 1 or #b.queue + 1, {name = entity, pos = slot.pos, slot = slot, module = block})
    return string.format("%s in %s block at %.0f,%.0f", entity, role, block.center[1], block.center[2])
  end
  if block then return string.format("opened %s block at %.0f,%.0f", block.kind, block.center[1], block.center[2]) end
end

-- Where the threat comes from: the nearest player-force building, else the player force's spawn.
local function threat(b)
  local surface = game.surfaces[b.surface]
  local p = game.forces.player
  local e = surface.find_nearest_enemy{position = b.lander.position, max_distance = 400, force = force(b)}
  if e then return {e.position.x, e.position.y} end
  local s = p.get_spawn_position(surface)
  return {s.x, s.y}
end

-- The planner's rules, in priority order. The first that applies and finds a place acts.
local function plan(b)
  local surface = game.surfaces[b.surface]
  local doc = layout.DOCTRINES[b.doctrine]
  local supply, demand = power(b)
  -- What awaits a rebuild still counts: the base knows what it lost and will replace it.
  local owed = {}
  for _, job in ipairs(b.rebuild) do owed[job.name] = (owed[job.name] or 0) + 1 end
  for _, job in ipairs(b.queue) do if job.name then owed[job.name] = (owed[job.name] or 0) + 1 end end
  -- And what its crews carry, not yet built (taken off the queue, they were planned again: demand 2.8 MW on 2.0, loot).
  for _, c in ipairs(b.crews or {}) do
    for i = c.k, #c.jobs do
      local job = c.jobs[i]
      if job.name and not c.rebuild then owed[job.name] = (owed[job.name] or 0) + 1 end
    end
  end
  local fab_cap = (#b.fabs + (owed["lp-fabricator"] or 0)) * FAB_FEED_PER_MIN
  supply = supply - (owed["lp-generator"] or 0) * shared.power["lp-generator"]
  local function mining()
    local budget = {n = SITE_BUDGET}
    for _, reach in ipairs(REACHES) do
      local o, _, cx, cy = site.mining(surface, b, reach, budget)
      if o then
        enqueue(b, modules.mining, o, cx, cy)
        return string.format("mining at %d,%d", o[1], o[2])
      end
    end
  end
  -- Maturity: enough blocks for the doctrine, or two minutes with nothing left to claim. A mature
  -- settlement stops expanding; its surplus is exported from a launch pad.
  if not b.mature then
    local mb = storage.mature_blocks or doc.mature
    -- Only plans where growth wanted ore and found no site count: counting every idle plan (waiting for
    -- parts included) matured settlements of two blocks after five minutes.
    if #b.blocks >= mb or ((b.grow_failed or 0) >= 12 and #b.fabs > 0) then
      b.mature = game.tick
      trace(b, string.format("mature: %d blocks, %d hubs", #b.blocks, #b.hubs))
    end
  end
  local function hub_needing(pred)
    for _, h in ipairs(b.hubs) do if pred(h) then return h end end
  end
  local rules = {
    {"power", function() return demand + 200000 > 0.9 * supply end, function() return fill(b, "gen", "lp-generator") end},
    -- Fabrication follows the flow of ore, never the stock: a backlog left by a raid is worked off by the
    -- fabricators the base has, not answered with more (a raid once doubled them).
    {"fabricate", function() return b.rate_in > fab_cap * 1.1 and b.rate_in > 0 end,
      function() return fill(b, "fab", "lp-fabricator") end},
    -- Mature, it only replaces lost income; young, it keeps the fabricators fed.
    {"mine", function()
      local floor = b.mature and 0.5 or 0.8
      return b.rate_in < fab_cap * floor or #b.drills + (owed["lp-drill"] or 0) == 0 end, mining},
    -- Walls wait for a working economy: spent first, they starved a settlement that had no fabricator yet.
    {"fortify", function() return b.parts > 80 and #b.fabs > 0 end, function()
      local block = layout.fortify(b)
      return block and string.format("walls round %s at %.0f,%.0f", block.kind, block.center[1], block.center[2]) end},
    {"defend", function()
      b.target = (doc.outpost_turrets and undefended(b)) or undefended(b, true)
      return b.target ~= nil and b.target ~= false end,
      function()
        local o = site.near(surface, b, modules.turrets, b.target.center[1], b.target.center[2], 3, 12)
        if not o then b.target.defended = "no site"; return end
        b.target.defended = true
        enqueue(b, modules.turrets, o)
        return string.format("turrets at %d,%d", o[1], o[2])
      end},
    {"picket", function() b.target = hub_needing(function(h) return h.pickets < doc.pickets end); return b.target ~= nil end,
      function()
        local block = layout.picket(b, b.target, threat(b))
        return block and string.format("picket at %.0f,%.0f", block.center[1], block.center[2]) end},
    {"depot", function()
      b.target = hub_needing(function(h) return h.count >= 3 and not h.depot end); return b.target ~= nil end,
      function()
        b.target.depot = true
        local block = layout.open_role(b, "depot")
        return block and string.format("opened %s block at %.0f,%.0f", block.kind, block.center[1], block.center[2]) end},
    {"launch", function() return b.mature and not b.launch_opened end, function()
      local block = layout.open_role(b, "launch")
      if block and block.kind == "launch" then b.launch_opened = true end
      return block and string.format("opened %s block at %.0f,%.0f", block.kind, block.center[1], block.center[2]) end},
    {"embellish", function() return b.mature and b.parts > 60 end, function()
      local block = layout.embellish(b)
      return block and string.format("lamps, paving and mines at %s %.0f,%.0f", block.kind, block.center[1],
        block.center[2]) end},
    {"grow", function() return not b.mature and b.parts > 100 end, mining},
  }
  for _, r in ipairs(rules) do
    if r[2]() then
      local did = r[3]()
      if did then
        b.rule = r[1]
        if r[1] == "grow" then b.grow_failed = 0 end
        trace(b, string.format("rule %s -> %s (parts %d, feed %d, in %.0f/min, fab cap %.0f, power %.1f/%.1f MW)",
          r[1], did, b.parts, b.feedstock, b.rate_in, fab_cap, demand / 1e6, supply / 1e6))
        return
      end
      if r[1] ~= "fortify" then trace(b, "rule " .. r[1] .. " applies but no site fits") end
      if r[1] == "grow" then b.grow_failed = (b.grow_failed or 0) + 1 end
    end
  end
  b.rule = "idle"
end

local function label(b)
  local o = rendering.get_object_by_id(b.label)
  if not o then return end
  local supply, demand = power(b)
  o.text = string.format("%s | parts %d | feed %d | in %.0f/min | parts %.1f/min | fabs %d drills %d | %.1f/%.1f MW",
    b.rule .. (b.waiting and (" (waiting: " .. b.waiting .. ")") or ""), b.parts, b.feedstock, b.rate_in,
    b.rate_parts, #b.fabs, #b.drills, demand / 1e6, supply / 1e6)
end

-- A mature settlement sends its surplus off-world once a minute, keeping a reserve for repairs and units.
local EXPORT_TICKS = 3600
local EXPORT_RESERVE = 300
local EXPORT_MAX = 1000
local function export(b)
  if not b.mature then return end
  local surplus = math.floor(b.parts - EXPORT_RESERVE)
  if surplus < 100 then return end
  local amount = math.min(surplus, EXPORT_MAX)
  -- While the uplink stands, exports travel to it by convoy (no pad needed); otherwise they leave from the pad.
  if army.convoy(b, amount, trace) then
    b.parts = b.parts - amount
    return
  end
  prune(b.launchpads)
  local pad = b.launchpads[1]
  if not pad then return end
  b.parts = b.parts - amount
  if base.on_export then base.on_export(b, amount) end
  rendering.draw_line{from = pad, to = {pad.position.x, pad.position.y - 60}, surface = pad.surface,
    color = {0.6, 0.85, 1, 0.8}, width = 6, time_to_live = 90}
  trace(b, string.format("exported %d parts", amount))
end

-- Territory on the map (map view only): the chunks it holds (scripts/chart.lua: a faint wash in the corporation's colour
-- and a hairline on the outer edge, as radar coverage is drawn), grown as it expands; grey once it falls. The player
-- sees the corporate map before a building (docs/campaign.md, readability). The claim stays a radius for the game.
local CLAIM_MARGIN = 24
function base.claim_map(b)
  local surface = game.surfaces[b.surface]
  local r = 60
  for _, m in ipairs(b.modules) do
    -- A claim (a strip camp kept on the player's ore) is far out: it has its own mark, not the disc.
    local d = math.sqrt((m.center[1] - b.origin.x) ^ 2 + (m.center[2] - b.origin.y) ^ 2) + CLAIM_MARGIN
    if d > r and not m.claim then r = d end
  end
  -- A perimeter that grows on its own (Serenity's moving line, ops.perimeter) claims at least that far.
  if b.perimeter and b.perimeter > r then r = b.perimeter end
  b.claim_radius = r
  -- Redrawn only when what it holds changes (a chunk is 32 tiles: the radius in whole tiles, and the fall).
  local key = string.format("%d|%s", math.floor(r), tostring(b.fallen or false))
  if b.claim_key == key and b.claim_marks then return end
  b.claim_key = key
  for _, o in ipairs({b.claim_fill, b.claim_edge}) do if o and o.valid then o.destroy() end end
  b.claim_fill, b.claim_edge = nil, nil
  chart.clear(b.claim_marks)
  local colour = b.fallen and {r = 0.45, g = 0.45, b = 0.45} or shared.CORPS[b.corp].color
  b.claim_marks = chart.territory(surface, {b.origin.x, b.origin.y}, r, colour)
end

ops.claim_map = base.claim_map
ops.trace = trace

-- A strip camp left alone twice on one patch stays (ops, strip_step): a mining module of the settlement,
-- rebuilt and capturable like any outpost. Its ore is hauled (no line home), marked on the map with its own disc.
function ops.settle(b, site, camp)
  local m = {kind = "mining", center = {site[1], site[2]}, entities = {}, built = true, claim = true}
  table.insert(b.modules, m)
  for _, e in ipairs(camp or {}) do if e and e.valid then register(b, e, m) end end
  local surface = game.surfaces[b.surface]
  local c = shared.CORPS[b.corp].color
  -- Its chunks, dashed: held, not settled ground (scripts/chart.lua).
  m.marks = chart.territory(surface, m.center, CLAIM_MARGIN, c, {dashed = true})
  b.claims_settled = (b.claims_settled or 0) + 1
end

-- The fall: a settlement whose lander is destroyed collapses. Its generators fail one by one (every
-- CASCADE_TICKS), so its turrets go dark; its units evacuate (army.disband). When the last generator is gone,
-- what stands becomes ruins: neutral and minable for salvage (the prototypes' results), except the mining
-- outposts, left to be taken by holding them with no one to stop it, and the mines, still live.
local CASCADE_TICKS = 90
function base.fall(lander)
  for _, b in pairs(storage.bases) do
    if b.lander == lander and not b.fallen then
      b.fallen = game.tick
      b.queue, b.rebuild = {}, {}
      prune(b.gens)
      b.cascade = {}
      for _, g in ipairs(b.gens) do table.insert(b.cascade, g) end
      rng.shuffle(b.rng, b.cascade)
      b.next_cascade = game.tick + CASCADE_TICKS
      local evacuated = army.disband(b, trace)
      b.evacuated = evacuated
      trace(b, string.format("lander destroyed: the settlement falls (%d generators to fail)", #b.cascade))
      local f = game.forces.player
      if f and #f.players > 0 then
        shared.notice(f, {"lp.fallen", shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y,
          lander.surface.name), names.of(b)})
      end
      for _, t in pairs(b.tags or {}) do
        if t.valid then t.text = names.of(b) .. " (fallen)" end
      end
      base.claim_map(b)
      if base.on_fall then base.on_fall(b) end
      return b
    end
  end
end

-- The powered hull (docs/reviews/2026-10-14-artillery-consult.md): a lander cannot be destroyed while at least half
-- the most generators its settlement has had still stand. A headquarters' lander answers to its uplink instead.
-- Only the generators within HULL_RADIUS of the lander count (the hull consult): a mature settlement's later hubs
-- lie 90-160 tiles out, and a battery in reach of the lander reached almost none of them (seed 777: 31,714 shells,
-- the hull never down). Fewer than two counted, and the hull is down.
local HULL_RADIUS = 80
local function hull(b)
  if b.hq then return end
  local n = 0
  local lx, ly = b.lander.position.x, b.lander.position.y
  for _, g in ipairs(b.gens) do
    if g.valid and g.force.name == b.force and (g.position.x - lx) ^ 2 + (g.position.y - ly) ^ 2 <= HULL_RADIUS ^ 2 then
      n = n + 1
    end
  end
  b.gens_max = math.max(b.gens_max or 0, n)
  b.gens_counted = n
  local held = n >= 2 and 2 * n >= b.gens_max
  if b.lander.destructible == held then
    b.lander.destructible = not held
    b.hull_down = (b.hull_down or 0) + (held and 0 or 1)
    trace(b, string.format("hull %s: %d of %d generators standing", held and "up" or "down", n, b.gens_max))
  end
end

local function ruin(b)
  local mining = {}
  for _, m in ipairs(b.modules) do
    -- By unit number: entity references are not stable table keys (keyed by them, outposts were ruined too).
    if m.kind == "mining" then for _, e in ipairs(m.entities) do if e.valid then mining[e.unit_number] = true end end end
  end
  local n = 0
  local surface = game.surfaces[b.surface]
  for _, e in pairs(surface.find_entities_filtered{force = force(b), position = {b.origin.x, b.origin.y}, radius = 400}) do
    local own = e.unit_number and storage.owner[e.unit_number]
    if own and own.base == b.id and not mining[e.unit_number] and shared.kind_of(e.name) ~= "lp-mine" then
      storage.owner[e.unit_number] = nil
      e.force = "neutral"
      n = n + 1
    end
  end
  b.ruins = n
  trace(b, string.format("%d buildings are ruins now", n))
end

local function collapse(b)
  if not b.cascade or game.tick < b.next_cascade then return end
  local g = table.remove(b.cascade)
  while g and not g.valid do g = table.remove(b.cascade) end
  if g then
    g.die()
    b.next_cascade = game.tick + CASCADE_TICKS
  else
    b.cascade = nil
    ruin(b)
  end
end

function base.tick(tick)
  for _, b in pairs(storage.bases) do
    if b.fallen then
      collapse(b)
      if tick % 600 == 300 then capture(b) end
    elseif b.lander.valid then
      if tick % 60 == 0 then hull(b); pack_camp(b) end
      if tick % 7200 == (b.id * 61) % 7200 then base.claim_map(b) end
      site.scan_step(game.surfaces[b.surface], b)
      if tick % ECONOMY_TICKS == 0 then economy(b) end
      -- A withdrawing corporation builds nothing more (its headquarters fell).
      local withdrawing = storage.corps and storage.corps[b.corp] and storage.corps[b.corp].withdrawing
      if tick % BUILD_TICKS == 0 and not withdrawing then
        build(b)
        -- The fortress's own jobs go faster; everything else at the usual pace (a burst for all once
        -- grew the uplink's settlement to 12 blocks in 11 minutes).
        for _ = 2, b.burst or 1 do
          local job = b.queue[1]
          if not (job and job.module and job.module.kind == "fortress") then break end
          build(b)
        end
      end
      army.tick(b, tick, trace)
      if tick % EXPORT_TICKS == 0 and not withdrawing then export(b) end
      if tick % 600 == 300 then capture(b) end
      if tick % PLAN_TICKS == 0 then
        local pending = false
        for _, job in ipairs(b.rebuild) do
          if not job.occupied and game.tick >= job.due then pending = true end
        end
        if #b.queue == 0 and not pending and not withdrawing then plan(b) end
        label(b)
      end
    end
  end
end

-- Tests only: the mining modules near a point and what capture sees there.
function base.debug_modules(b, pos, r)
  local out = {}
  local surface = game.surfaces[b.surface]
  for _, m in ipairs(b.modules) do
    if m.kind == "mining" and (m.center[1] - pos[1]) ^ 2 + (m.center[2] - pos[2]) ^ 2 <= r * r then
      local left = 0
      for _, e in ipairs(m.entities) do if e.valid and e.force.name == b.force then left = left + 1 end end
      local by = holder(b, surface, m.center)
      local def = surface.find_entities_filtered{position = m.center, radius = CAPTURE_CLEAR, force = force(b),
        type = {"unit", "spider-unit", "electric-turret", "ammo-turret"}, limit = 1}[1]
      table.insert(out, string.format("%.0f,%.0f built=%s captured=%s left=%d held=%s holder=%s defended=%s", m.center[1],
        m.center[2], tostring(m.built), tostring(m.captured), left,
        m.held_since and tostring(game.tick - m.held_since) or "-", by and by.name or "-",
        def and (def.name .. "@" .. math.floor(def.position.x) .. "," .. math.floor(def.position.y)) or "-"))
    end
  end
  return out
end

function base.stats(b)
  prune(b.bins); prune(b.fabs); prune(b.pylons); prune(b.walls)
  local supply, demand = power(b)
  return {id = b.id, tick = game.tick, rule = b.rule, parts = b.parts, feedstock = b.feedstock, mined = b.mined,
    made = b.made, rate_in = b.rate_in, rate_parts = b.rate_parts, fabs = #b.fabs, drills = #b.drills,
    gens = #b.gens, turrets = #b.turrets, pylons = #b.pylons, modules = #b.modules, queue = #b.queue,
    lost = b.lost, rebuilt = b.rebuilt, rebuild_pending = #b.rebuild,
    doctrine = b.doctrine, hubs = #b.hubs, blocks = #b.blocks, walls = #b.walls, road_tiles = b.road_tiles,
    radars = #b.radars, depots = #b.depots, garrison = #b.garrison, returning = #(b.returning or {}),
    roster = table_size(b.roster or {}), units_built = b.units_built,
    units_lost = b.units_lost, razed = b.razed, raids_sent = b.raids_sent, responses = b.responses or 0,
    mature = b.mature ~= nil, exported = b.exported or 0, lamps = #b.lamps, mines = #b.mines,
    launchpads = #b.launchpads, built_by = b.built_by, uplink = b.uplink and b.uplink.valid or false, hq = b.hq,
    turrets_n = #b.turrets, fortress_planned = b.fortress_planned, captured = b.captured or 0,
    patrol = #(b.patrol or {}), patrol_loops = b.patrol_legs or 0, route = b.route,
    convoys_sent = b.convoys_sent or 0, convoys_delivered = b.convoys_delivered or 0, convoys_stuck = b.convoys_stuck or 0,
    convoys_lost = b.convoys_lost or 0, cargo_lost = b.cargo_lost or 0, intercepts = b.intercepts or 0,
    convoy_spread = army.convoy_spread(b), convoy_debug = army.convoy_debug(b),
    fortress_box = b.blocks[1] and b.blocks[1].kind == "fortress" and
      {b.blocks[1].x0, b.blocks[1].y0, b.blocks[1].x0 + b.blocks[1].w, b.blocks[1].y0 + b.blocks[1].h} or nil,
    archetypes = (function() local t = {} for _, h in ipairs(b.hubs) do
      table.insert(t, h.archetype) end return table.concat(t, ",") end)(),
    supply = supply, demand = demand, network = base.network(b), lander = b.lander.valid,
    fallen = b.fallen, ruins = b.ruins, evacuated = b.evacuated, origin = b.origin, ops = ops.summary(b), corp = b.corp, force = b.force, claim_radius = b.claim_radius, claims_settled = b.claims_settled, landed = b.landed, gens_max = b.gens_max, hull_down = b.hull_down, perimeter = b.perimeter, perimeter_steps = b.perimeter_steps, warned = b.warned,
    grudge = b.grudge, grudge_till = b.grudge_till, cap = army.cap(b), escort = b.escort, gens_counted = b.gens_counted,
    cleared = b.cleared, under_guns = b.under_guns, reinforced = b.reinforced or 0, on_footing = b.on_footing,
    columns_arrived = b.columns_arrived or 0, quiescent = b.quiescent, stood_down = b.stood_down or 0,
    war_rung = b.war_rung or 0, map_text = b.map_text, name = b.name,
    claim_marks = #(b.claim_marks or {}), flares = b.flares or 0, jumps = b.jumps or 0, hands_back = b.hands_back or 0, gate_opens = b.gate_opens or 0, taps = b.taps or 0, tap_watts = b.tap_watts or 0, looted = b.looted or 0}
end

return base
