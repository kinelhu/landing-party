-- The faction across settlements: when landings come, where they land, and the tier its exports buy.
--   Landings: the first answers the player's first rocket launch; then one every CADENCE, each later launch
--   bringing the next one HASTE sooner; at most MAX_ALIVE settlements stand at once.
--   Tier: parts exported by mature settlements, faction-wide. Each tier unlocks units, adds damage and
--   garrison room (army.lua reads it).
local shared = require("__landing-party__.shared")
local site = require("__landing-party__.scripts.site")
local base = require("__landing-party__.scripts.base")
local ops = require("__landing-party__.scripts.ops")
local army = require("__landing-party__.scripts.army")
local rd = require("__landing-party__.scripts.rd")

local faction = {}

local CADENCE = 90 * 3600
local HASTE = 15 * 3600
local MAX_ALIVE = 6              -- standing settlements, all corporations
local MAX_PER_CORP = 3           -- per corporation, its headquarters counted
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
local APART = 200                -- a new landing keeps this far from every standing lander
local SITE_SEARCH = 120
local SITE_MIN_ORE = 300
local ARTILLERY_REACH = 300      -- vanilla artillery's 224 and a margin for range research

faction.TIERS = {3000, 8000, 20000, 45000}           -- parts exported to reach tiers 1..4

function faction.state()
  storage.faction = storage.faction or {tier = 0, exported = 0, landings = 0, cadence = CADENCE,
    tiers = faction.TIERS}
  return storage.faction
end

local function landers()
  local out = {}
  for _, b in pairs(storage.bases) do if b.lander.valid then table.insert(out, b.lander.position) end end
  return out
end

-- A landing site about `distance` from `from`: in the first of eight directions (seeded order, turned by
-- the landing count) with a rich enough patch within SITE_SEARCH tiles of the ring and no lander within
-- APART. A single point per direction found no ore at 300 tiles on most maps (seed 2: 7 of 8 empty).
function faction.site(surface, from, distance, count)
  local start = (surface.map_gen_settings.seed + 3 * (count or 0)) % 8
  local avoid = landers()
  local fallback, fallback_n = nil, -1
  for i = 0, 7 do
    local a = 2 * math.pi * ((start + i) % 8) / 8
    local p = {from.x + distance * math.cos(a), from.y + distance * math.sin(a)}
    -- Ore from the map generator's noise, sampled every 8 tiles: generating the search area round up to eight
    -- ring points stalled each landing for up to 1.4 s; the noise costs about 2 ms and matched the generated
    -- ore point for point (a spike, 625 of 625). Only the chosen ground is generated (base.land).
    local pts = {}
    for x = -SITE_SEARCH, SITE_SEARCH, 8 do
      for y = -SITE_SEARCH, SITE_SEARCH, 8 do
        if x * x + y * y <= SITE_SEARCH * SITE_SEARCH then table.insert(pts, {p[1] + x, p[2] + y}) end
      end
    end
    local names = {}
    for _, ore in ipairs(site.ORES) do table.insert(names, "entity:" .. ore .. ":probability") end
    local props = surface.calculate_tile_properties(names, pts)
    local per = {}
    for i, q in ipairs(pts) do
      for _, v in pairs(props) do
        if v[i] > 0 then
          local k = math.floor(q[1] / 32) .. ":" .. math.floor(q[2] / 32)
          per[k] = (per[k] or 0) + 1
          break
        end
      end
    end
    -- A chunk already generated holds what is really there (the player may have mined it out).
    for k in pairs(per) do
      local cx, cy = k:match("(-?%d+):(-?%d+)")
      cx, cy = tonumber(cx), tonumber(cy)
      if surface.is_chunk_generated{cx, cy} and surface.count_entities_filtered{area = {{cx * 32, cy * 32},
        {cx * 32 + 32, cy * 32 + 32}}, type = "resource", name = site.ORES, limit = 1} == 0 then
        per[k] = nil
      end
    end
    local best, bn = nil, 0
    for k, n in pairs(per) do
      if n > bn or (n == bn and best and k < best) then best, bn = k, n end
    end
    if best then
      local cx, cy = best:match("(-?%d+):(-?%d+)")
      local c = {tonumber(cx) * 32 + 16, tonumber(cy) * 32 + 16}
      -- Land beside the patch, not on it: a third of the way back towards the ring point.
      local spot = {c[1] + (p[1] - c[1]) / 3, c[2] + (p[2] - c[2]) / 3}
      local clear = true
      for _, l in ipairs(avoid) do
        if (l.x - spot[1]) ^ 2 + (l.y - spot[2]) ^ 2 < APART * APART then clear = false end
      end
      -- Not under the player's artillery (it fires on military targets by itself, about 224 tiles, more with
      -- research): a settlement landed there would die unseen. Against a megabase they ring it, just outside.
      if clear then
        for _, pf in pairs(game.forces) do
          if clear and not shared.is_corp(pf.name) and pf.name ~= "enemy" and pf.name ~= "neutral"
            -- Its range research too (a factory with 210 technologies outranged 224 tiles: eleven landings in three
            -- hours died within 25 seconds, visit).
            and surface.count_entities_filtered{position = spot, radius = ARTILLERY_REACH * (1 + pf.artillery_range_modifier),
              force = pf, type = {"artillery-turret", "artillery-wagon"}, limit = 1} > 0 then
            clear = false
          end
        end
      end
      -- Not on the player's army: units or turrets within 100 tiles, as it keeps out of the player's artillery.
      if clear then
        for _, pf in pairs(game.forces) do
          if clear and not shared.is_corp(pf.name) and pf.name ~= "enemy" and pf.name ~= "neutral"
            and surface.count_entities_filtered{position = spot, radius = 100, force = pf,
              type = {"unit", "electric-turret", "ammo-turret", "fluid-turret", "car", "spider-vehicle"}, limit = 1} > 0 then
            clear = false
          end
        end
      end
      -- Not in the player's factory: none of its buildings within CLEAR_OF_FACTORY (the open ground between a
      -- megabase's lasers counted as clear, and landings came down inside a 1,600-tile factory, visit).
      if clear then
        for _, pf in pairs(game.forces) do
          if clear and not shared.is_corp(pf.name) and pf.name ~= "enemy" and pf.name ~= "neutral"
            and surface.count_entities_filtered{position = spot, radius = CLEAR_OF_FACTORY, force = pf,
              type = FACTORY, limit = 1} > 0 then
            clear = false
          end
        end
      end
      -- The candidate's own ground, generated now: nests and the ore count below need real entities.
      if clear then
        surface.request_to_generate_chunks(spot, 2)
        surface.force_generate_chunk_requests()
      end
      -- Not on biters: a settlement landed among nests could not build there (docs/campaign.md, biters).
      -- Further from them as they evolve: 60 tiles, 100 at full evolution (200 left a maximum-evolution world no site
      -- at all, visit). On a second pass (faction.arrive) nests do not refuse a site: the lander clears its ground.
      local evo = game.forces.enemy and game.forces.enemy.get_evolution_factor(surface) or 0
      if clear and not faction.ignore_nests
        and surface.count_entities_filtered{position = spot, radius = 60 + 40 * evo, type = "unit-spawner", limit = 1} > 0 then
        clear = false
      end
      if clear then
        local n = surface.count_entities_filtered{position = c, radius = 60, type = "resource", name = site.ORES}
        if n > SITE_MIN_ORE then return spot end
        if n > fallback_n then fallback, fallback_n = spot, n end
      end
    end
  end
  -- No direction rich and clear: the best clear one seen (seed 2024 once landed blind on two drills' worth).
  return fallback
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
        text = c.name})
      if t then b.tags[f.name] = t else all = false end
    end
  end
  b.tags_done = all and next(b.tags) ~= nil
end

local function announce(b, surface)
  for _, f in pairs(game.forces) do
    if #f.players > 0 then
      f.chart(surface, {{b.origin.x - 48, b.origin.y - 48}, {b.origin.x + 48, b.origin.y + 48}})
      f.print({"lp.landed", shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y, surface.name),
        shared.CORPS[b.corp].motto})
    end
  end
  faction.tag(b)
end

-- A landing now, `distance` from `from` (a table with x, y). opts as for base.land.
function faction.arrive(surface, from, opts, quiet)
  local f = faction.state()
  -- Further rings when the first has no clear, ore-bearing site (seed 12345: two landings blocked their
  -- neighbours at 350 tiles and the other directions were barren).
  -- A site whose pad does not fit (a headquarters' fortress found no free square within 100 tiles of its site
  -- 25 times running, every 5 minutes, a 6-hour campaign) also moves on to the next ring.
  local pos, b
  -- Further rings out to a megabase's edge: clear of the factory (CLEAR_OF_FACTORY), the near rings were all refused.
  -- A second pass with nests allowed (the lander burns its clearing, base.clear_landing): in a maximum-evolution
  -- world every ring had nests near it, and Grubstake never landed.
  for pass = 1, 2 do
    faction.ignore_nests = pass == 2
    for _, extra in ipairs(storage.rings or {0, 120, 240, 480, 800, 1200, 1800}) do
      pos = faction.site(surface, from, ((opts and opts.distance) or DISTANCE) + extra, f.landings)
      b = pos and base.land(surface, pos, opts)
      if b then break end
    end
    if b then break end
  end
  faction.ignore_nests = false
  if b then base.clear_landing(b) end
  if not b then
    -- Try again later, and say why: a failed landing retried silently every 10 s once.
    f.next = game.tick + 5 * 3600
    if storage.trace then
      helpers.write_file("landing-party/decisions.txt", string.format("%8d faction  landing failed: %s\n", game.tick,
        pos and string.format("no pad fits near %.0f,%.0f", pos[1], pos[2]) or "no site clear of other landers"), true)
    end
    return nil
  end
  f.landings = f.landings + 1
  faction.angry(b)
  -- A world already far along: the corporation arrives with the research it would have pushed it to (rd.history).
  rd.history(b.corp, surface)
  -- The drop escort: 6 + 4 a level, doubled by a grudge, and four corner turrets, once the pad is laid
  -- (army.escort, base.corner_turrets); a headquarters lands with its fortress.
  if not (opts and opts.uplink) then
    -- Evolution: up to ten more at full (at maximum evolution, a biter or two ate the camps).
    local evo = game.forces.enemy and game.forces.enemy.get_evolution_factor(surface) or 0
    local n = 6 + 4 * (faction.corp(b.corp).level or 0) + math.floor(10 * evo)
    b.escort_due = b.grudge and 2 * n or n
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
  -- A headquarters lands off the clock: the faction's origin and next landing stay as they were.
  if not (opts and opts.hq) then
    f.surface, f.from = surface.index, {x = from.x, y = from.y}
    f.next = game.tick + f.cadence
  end
  base.trace(b, string.format("landing %d of the faction (tier %d)", f.landings, f.tier))
  if not quiet then announce(b, surface) end
  return b
end

-- The first launch is heard; each later one brings the next landing sooner.
-- The first launch triggers the arrival (scripts/phases.lua, which may delay it); later ones bring the next
-- landing sooner.
function faction.on_launch(silo)
  local f = faction.state()
  if not f.surface then
    if faction.on_trigger then faction.on_trigger(silo.surface, silo.position) end
  elseif f.next then
    f.next = math.max(game.tick, f.next - HASTE)
  end
end

local function alive(corp)
  local n = 0
  for _, b in pairs(storage.bases) do
    if b.lander.valid and (not corp or b.corp == corp) then n = n + 1 end
  end
  return n
end
faction.alive = alive

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
    local entered = corp == first or f.landings >= SECOND_CORP_LANDING
    local n = alive(corp)
    if entered and not d.withdrawing and n < MAX_PER_CORP then
      local t = d.landed or -1
      if not best or n < bn or (n == bn and t < bt) then best, bn, bt = corp, n, t end
    end
  end
  return best
end

function faction.tick(tick)
  if tick % 600 ~= 0 then return end
  for _, b in pairs(storage.bases) do
    if b.lander.valid and not b.tags_done then faction.tag(b) end
  end
  local f = faction.state()
  if f.next and tick >= f.next and f.surface then
    local corp = alive() < MAX_ALIVE and next_corp(f)
    if corp then
      -- After a corporation withdrew, the survivor's next landing starts from the vacancy it left.
      local origin = f.from
      local from = origin
      if f.vacancy and f.vacancy.corp ~= corp then from = f.vacancy.pos; f.vacancy = nil end
      faction.arrive(game.surfaces[f.surface], from, {corp = corp}, storage.quiet)
      f.from = origin
    else
      f.next = tick + f.cadence
    end
  end
  faction.headquarters(tick)
end

-- Headquarters: consolidation, the landing, withdrawal (see the constants above).
local function tell(key, ...)
  for _, force in pairs(game.forces) do
    if #force.players > 0 then force.print({key, ...}) end
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
        if richest then
          local hq = faction.arrive(game.surfaces[richest.surface], richest.origin,
            {corp = corp, uplink = true, hq = true, distance = HQ_DISTANCE}, storage.quiet)
          if hq then
            d.consolidating = nil
            tell("lp.headquarters", shared.corp_label(corp), string.format("[gps=%d,%d,%s]", hq.origin.x, hq.origin.y,
              game.surfaces[hq.surface].name))
          else
            d.consolidating = tick + 5 * 3600
          end
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
local function apply_tier(f) end

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
  d.grudge = by
  d.grudges = (d.grudges or 0) + 1
  base.trace(b, "grudge: every corporation provoked by " .. by .. "; the next landing comes angry")
  local f = game.forces[by]
  if f and #f.players > 0 then f.print({"lp.grudge", shared.corp_label(b.corp)}) end
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
    f.print({"lp.grudge-landed", shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y,
      game.surfaces[b.surface].name)})
  end
end

function faction.corp(corp)
  storage.corps = storage.corps or {}
  storage.corps[corp] = storage.corps[corp] or {level = 0, exported = 0}
  return storage.corps[corp]
end

local CAP_NOTICE = {["lp-harrier"] = "harriers", ["lp-walker"] = "walkers", siege = "siege operations",
  pickets_see = "pickets that report what they see", headquarters = "a headquarters"}
function faction.develop(b, parts)
  local d = faction.corp(b.corp)
  d.exported = d.exported + parts
  rd.fund(b.corp, parts)
  while shared.LEVELS[d.level + 1] and d.exported >= shared.LEVELS[d.level + 1] do
    d.level = d.level + 1
    local gained = {}
    for cap, lvl in pairs(shared.CORPS[b.corp].caps or {}) do
      if lvl == d.level and CAP_NOTICE[cap] then table.insert(gained, CAP_NOTICE[cap]) end
    end
    table.sort(gained)
    base.trace(b, string.format("%s reaches level %d: %s", b.corp, d.level, table.concat(gained, ", ")))
    for _, f in pairs(game.forces) do
      if #f.players > 0 and #gained > 0 then
        f.print({"lp.develop", shared.corp_label(b.corp), table.concat(gained, ", ")})
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
    apply_tier(f)
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
    if not shared.is_corp(force.name) and force.name ~= "enemy" and force.name ~= "neutral" then
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

return faction
