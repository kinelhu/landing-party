-- Operations: the faction's military with intent (DESIGN "Operations"). A settlement knows only what it has
-- seen (intel), values what it knows (target values over known defence), sizes a force to it, stages out of
-- range, attacks, and aborts when it is losing. One operation per settlement at a time.
--   intel    b.intel.targets: one entry per 32-tile cell holding player structures:
--            {pos, kind, value, defence, seen, tried, cool}; b.intel.markers: where its units died and what
--            killed them (decays). Sensors: the lander, depots, radars, units in the field.
--   raid     stage (go to a point out of known turret range on the line from home), attack (the target's
--            cell, radius 12), return. Abort: below half strength with a turret still near the target, or
--            no kill for 90 s while attacking; or, from the staging point, more turrets seen than the force
--            can take (it turns back unhurt). An aborted target is remembered (tried, defence seen, cool).
local shared = require("__landing-party__.shared")
local tune = require("__landing-party__.scripts.tune")
local rd = require("__landing-party__.scripts.rd")
local stance = require("__landing-party__.scripts.stance")
local pool = require("__landing-party__.scripts.pool")

local ops = {}

local CELL = 32
local SENSE_TICKS = 2 * 3600          -- a full scan of the static sensors
-- The lander sees as far as the player's artillery reaches: a battery is seen when it is built, not when it fires.
local SENSORS = {["lp-lander"] = 300, ["lp-depot"] = 150, ["lp-radar"] = 250}
local FIELD_SIGHT = 40                -- what a unit away from home sees
local DEFENCE_RADIUS = 30             -- turrets this close to a target defend it
local MARKER_TICKS = 20 * 60 * 60     -- a death marker counts this long
local DECIDE_TICKS = 30 * 60
local RESERVE = pool.RESERVE           -- share of the garrison cap that never leaves on an operation (pool.floor)
-- Force needed: 3.5 a unit of weighted defence (ops.weigh), plus 4. Three a turret (assault: 12 took four); 5 once
-- lost to upgraded ammunition (18 units against three creeping turrets with bullet damage +0.8 lost two thirds,
-- defend), and with research now in the weight (x1.8 there) 5 counted it twice. At 3, the 21 sent there won once
-- and lost once (two thirds dead either way): 3.5 sends 23.
local PER_TURRET, BASE_FORCE = 3.5, 4
local THREAT_TICKS = 10 * 60 * 60     -- a static threat on the faction's ground stays a priority this long
local THREAT_BONUS = 10               -- value added to targets by it
local STAND_OFF = 34                  -- staging this far from the target: a laser's 24 and 10 to spare
local STAGE_TICKS = 90 * 60
local MARCH_SPEED = 0.08          -- tiles a tick, a slow column's pace
local NO_KILL_TICKS = 90 * 60
local COOL_TICKS = 10 * 60 * 60
local MAX_TICKS = 6 * 60 * 60
-- Cadence: after an operation a settlement waits before the next, longer after a failure and after losses.
-- Without it, raids came a minute apart, four units each, and stripped an undefended base in 35 minutes
-- (contact, the first-contact baseline): biter pacing, not a rival's.
local GAP_DONE = 5 * 60 * 60
local GAP_ABORTED = 10 * 60 * 60
local GAP_PER_5_LOST = 60 * 60
-- Siege: when no raid is affordable, a hauler carries a mortar and its shells to a site beyond the player's
-- turrets (31 tiles: a flamethrower's 30) and within its own reach (35) of one; guards ring it while it
-- deploys and shells; it packs up when the shells are spent or the guards are halved.
local SIEGE_COST = 100                -- parts: the emplacement and its shells
local SIEGE_SHELLS = 30
local SIEGE_GUARDS = 6
local SIEGE_COOL = 15 * 60 * 60
local DEPLOY_TICKS = 30 * 60
local PACK_TICKS = 10 * 60
local PLAYER_REACH = 31
local MORTAR_REACH = 35
local HOWITZER_REACH, HOWITZER_STAND = 98, 53   -- its reach, and how far from the nest it stands
local STUCK_TICKS = 60 * 60       -- a siege's hauler no nearer its site for this long is stuck
local CLEAR_RAILS = 8             -- railgunners a clearance waits for (its only guards; six could not hold, the user)
local GUARD_RADIUS = 24            -- a clearance's guards shoot biters this near its mortars
local SIEGE_MAX_TICKS = 15 * 60 * 60
-- Siege tiers (docs/reviews/2026-10-14-operations-depth-consult.md): by the corporation's level, held to the target
-- player's era + 1, one up for a grudge. Mortars, shells each, guards, parts; resupply convoys (a hauler with
-- RESUPPLY shells when the mortars are spent and a turret is still in reach; a dead convoy ends resupply); an
-- assault from the site once nothing is in reach for ASSAULT_IDLE (a phase of the same operation). Shells per siege
-- at most SHELLS_CAP. A tank sally still kills a mortar in seconds.
local SIEGE_TIERS = {
  {mortars = 1, shells = 30, guards = 6, cost = 100},
  {mortars = 2, shells = 40, guards = 10, cost = 220, convoys = 1},
  {mortars = 3, shells = 40, guards = 16, cost = 400, convoys = 1, assault = true},
  {mortars = 4, shells = 30, guards = 24, cost = 600, convoys = 1, assault = true},
}
local RESUPPLY, SHELLS_CAP = 40, 160
local ASSAULT_IDLE = 30 * 60
local ENEMY_SHARE = 0.5          -- a provoked Grubstake's raids: this share of what it can field, at least
-- Strip-mining (Grubstake's temper): a hauler and guards set up a camp on ore beside the player's drills, out of
-- their turrets' reach (a generator, a pylon, drills over bins), mine the real patch for STRIP_TICKS, pack up,
-- and the hauler carries the ore home as feedstock (lost if it dies on the way).
local STRIP_GUARDS = 4
local STRIP_TICKS = 10 * 60 * 60
local STRIP_COOL = 15 * 60 * 60
local STRIP_DRILLS = 3
local STRIP_COST = 40

-- What a player structure is worth to the faction, mirroring what hurts the faction most: command, then
-- power and logistics, then production. Lamps, pipes, belts and walls are worth nothing.
ops.VALUE = {["lp-command-relay"] = 10, ["lp-barracks"] = 8, ["substation"] = 6, ["big-electric-pole"] = 5,
  ["train-stop"] = 5, ["locomotive"] = 5, ["roboport"] = 5, ["mining-drill"] = 4, ["assembling-machine"] = 3,
  ["furnace"] = 3, ["lab"] = 3, ["radar"] = 3, ["ammo-turret"] = 1, ["electric-turret"] = 1,
  -- A rival corporation's buildings: its command (lander, uplink), its depots and its power first.
  ["lp-uplink"] = 10, ["lp-pacifier"] = 8, ["lp-lander"] = 8, ["lp-depot"] = 6, ["lp-generator"] = 5, ["lp-launchpad"] = 5,
  -- Transit (late pressure, docs/reviews/2026-10-13-late-pressure-consult.md): rails and their signals.
  ["straight-rail"] = 3, ["half-diagonal-rail"] = 3, ["curved-rail-a"] = 3, ["curved-rail-b"] = 3,
  ["rail-signal"] = 2, ["rail-chain-signal"] = 2,
  -- The player's artillery: the one thing that kills a lander from out of reach (campaign runs: four landers in
  -- six hours, 35 minutes after each landing). Found when it fires (ops.counter_battery).
  ["artillery-turret"] = 12, ["artillery-wagon"] = 8}
local TYPES = {"mining-drill", "assembling-machine", "furnace", "lab", "radar", "roboport", "train-stop",
  "locomotive", "electric-pole", "ammo-turret", "electric-turret", "fluid-turret", "electric-energy-interface",
  "container", "straight-rail", "half-diagonal-rail", "curved-rail-a", "curved-rail-b", "rail-signal",
  "rail-chain-signal", "artillery-turret", "artillery-wagon"}
local TURRETS = {"ammo-turret", "electric-turret", "fluid-turret", "artillery-turret"}

-- Weighted defence (docs/reviews/2026-10-14-operations-depth-consult.md): a turret weighs by its kind, scaled by its
-- force's damage and shooting-speed research for that kind (all turrets weighed 1, and raids sized for four turrets died to four
-- upgraded lasers; flamethrowers killed most of every campaign squad). Artillery cannot fire up close: 0.
local WEIGHT = {["ammo-turret"] = {1, "bullet"}, ["electric-turret"] = {1.5, "laser"}, ["fluid-turret"] = {2.5, "flamethrower"},
  ["artillery-turret"] = {0}}
local DEALS = {["ammo-turret"] = "physical", ["electric-turret"] = "laser", ["fluid-turret"] = "fire"}
-- Returns the weight and the damage the turrets mostly deal (for a plate that answers it: rd.strength).
function ops.weigh(surface, pos, forces, r)
  local w, by = 0, {}
  for _, e in pairs(surface.find_entities_filtered{position = pos, radius = r or DEFENCE_RADIUS, force = forces, type = TURRETS}) do
    local k = WEIGHT[e.type]
    -- Firepower: damage times rate of fire (defend's guns, bullet damage +0.8 and shooting speed +0.6: 2.88 each; three
    -- of them killed about 15 units whatever the raid's size, so 21 and 23 lost and 30 is what wins). Corporate
    -- research (rd.strength) is what keeps the raid a size a garrison can field.
    if k and k[1] > 0 then
      local f = e.force
      local x = k[1] * (1 + (k[2] and f.get_ammo_damage_modifier(k[2]) or 0)) * (1 + (k[2] and f.get_gun_speed_modifier(k[2]) or 0))
      w = w + x
      local dmg = DEALS[e.type]
      if dmg then by[dmg] = (by[dmg] or 0) + x end
    end
  end
  local top, tw
  for dmg, x in pairs(by) do if not tw or x > tw then top, tw = dmg, x end end
  return w, top
end
-- Exposure (the megabase consult): the weighted turrets whose own reach covers pos (gun 18, laser 24, flamethrower 30,
-- plus 2). Grubstake's soft is exposure, not any turret within 30 tiles: a megabase's rails, big poles and far
-- substations sit just beyond its turrets' reach, and every one of them had counted as defended.
local EXPOSE = {["ammo-turret"] = 20, ["electric-turret"] = 26, ["fluid-turret"] = 32}
function ops.exposure(surface, pos, forces)
  local w = 0
  for _, e in pairs(surface.find_entities_filtered{position = pos, radius = 32, force = forces,
    type = {"ammo-turret", "electric-turret", "fluid-turret"}}) do
    local r = EXPOSE[e.type]
    if (e.position.x - pos[1]) ^ 2 + (e.position.y - pos[2]) ^ 2 <= r * r then
      local k = WEIGHT[e.type]
      local f = e.force
      w = w + k[1] * (1 + f.get_ammo_damage_modifier(k[2])) * (1 + f.get_gun_speed_modifier(k[2]))
    end
  end
  return w
end
-- Who stands by a target, at the staging look only (units move; the two-minute scan would be stale): characters 0.5,
-- units 0.5, cars and tanks 1.5, spidertrons 3, within 40 tiles.
local MOBILE = {character = 0.5, unit = 0.5, car = 1.5, ["spider-vehicle"] = 3}
local function mobile(surface, pos, forces)
  local w = 0
  for _, e in pairs(surface.find_entities_filtered{position = pos, radius = 40, force = forces,
    type = {"character", "unit", "car", "spider-vehicle"}}) do
    w = w + (MOBILE[e.type] or 0)
  end
  return w
end
local UNITS_TICKS = 5 * 3600

local function value_of(e)
  return ops.VALUE[shared.kind_of(e.name)] or ops.VALUE[e.type] or 0
end

local function enemies(f)
  local out = {}
  for _, other in pairs(game.forces) do
    if other ~= f and other.name ~= "enemy" and other.name ~= "neutral" and not f.get_cease_fire(other) then
      table.insert(out, other)
    end
  end
  return out
end

function ops.init(b)
  b.intel = b.intel or {targets = {}, markers = {}}
  b.ops_launched, b.ops_done, b.ops_aborted = b.ops_launched or 0, b.ops_done or 0, b.ops_aborted or 0
end

-- Record what a sensor at pos sees within r: per cell, the most valuable structure and the turrets by it.
local function sense(b, surface, pos, r)
  local f = game.forces[b.force]
  for _, other in ipairs(enemies(f)) do
    local cells = {}
    for _, e in pairs(surface.find_entities_filtered{position = pos, radius = r, force = other, type = TYPES}) do
      local v = value_of(e)
      if v > 0 then
        local key = math.floor(e.position.x / CELL) .. "," .. math.floor(e.position.y / CELL)
        local c = cells[key]
        if not c or v > c.value then
          cells[key] = {pos = {e.position.x, e.position.y}, kind = e.name, value = v, owner = e.force.name, type = e.type}
        end
      end
    end
    for key, c in pairs(cells) do
      local t = b.intel.targets[key] or {tried = 0, cool = 0}
      t.pos, t.kind, t.value, t.seen, t.owner = c.pos, c.kind, c.value, game.tick, c.owner
      t.defence, t.dmg = ops.weigh(surface, c.pos, other)
      t.exposure = ops.exposure(surface, c.pos, other)
      -- A line cell: a pole or rail with no turret within 60 tiles and little else round it (transit far from
      -- defences: cheap to cut). Isolated: a substation inside a base, 66 tiles from its corner turrets, was
      -- raided every ten minutes and its raiders died on the way.
      t.line = (c.type == "electric-pole" or (c.type or ""):find("rail") ~= nil)
        and surface.count_entities_filtered{position = c.pos, radius = 60, force = other, type = TURRETS, limit = 1} == 0
        and surface.count_entities_filtered{position = c.pos, radius = 30, force = other, type = TYPES, limit = 8} < 8
      b.intel.targets[key] = t
    end
  end
end

-- A sensor sweep over the cells it covers: what is gone is forgotten.
local function forget(b, pos, r)
  for key, t in pairs(b.intel.targets) do
    if (t.pos[1] - pos.x) ^ 2 + (t.pos[2] - pos.y) ^ 2 <= r * r and t.seen < game.tick then
      b.intel.targets[key] = nil
    end
  end
end

-- Nests on its own territory, for a corporation that clears them (Serenity; Grubstake routes round them):
-- spawners within its claim are targets (value 3), worms by them their defence. Announced when raided.
local function sense_nests(b, surface)
  if not shared.CORPS[b.corp].clears_nests or not b.claim_radius then return end
  for _, sp in pairs(surface.find_entities_filtered{position = {b.origin.x, b.origin.y}, radius = b.claim_radius,
    force = "enemy", type = "unit-spawner"}) do
    local key = "nest:" .. math.floor(sp.position.x / CELL) .. "," .. math.floor(sp.position.y / CELL)
    local t = b.intel.targets[key] or {tried = 0, cool = 0}
    t.pos, t.kind, t.value, t.seen, t.owner = {sp.position.x, sp.position.y}, sp.name, 3, game.tick, "enemy"
    t.defence = surface.count_entities_filtered{position = sp.position, radius = DEFENCE_RADIUS, force = "enemy", type = "turret"}
    b.intel.targets[key] = t
  end
end

-- Encroachment (Serenity's temper, "Please remain behind the line"): a player building put up inside its territory
-- provokes it as an attack does. Judged when it is built (control.lua's on_built): what stood there before the line
-- moved onto it does not (the user, 2026-10-17, on Fable's notices consult: the line moving onto the player is the
-- corporation's act; enclosed unseen beyond radar, an outpost made Serenity an enemy for good).
local ENCROACH = {}
for _, t in ipairs(TYPES) do ENCROACH[t] = true end
ops.ENCROACH_TYPES = TYPES
function ops.encroached(ent)
  if not (ent and ent.valid) or not ENCROACH[ent.type] or ent.name:sub(1, 3) == "lp-" then return end
  local by = ent.force.name
  if shared.is_corp(by) or by == "enemy" or by == "neutral" then return end
  for _, b in pairs(storage.bases or {}) do
    if not b.fallen and b.claim_radius and b.surface == ent.surface.index
      and (shared.CORPS[b.corp].temper or {}).provoked_only
      and (ent.position.x - b.origin.x) ^ 2 + (ent.position.y - b.origin.y) ^ 2 <= b.claim_radius ^ 2 then
      ops.provoke(b.force, by, ent, "trespass")
    end
  end
end

-- Serenity's line moves (docs/reviews/2026-10-13-late-pressure-consult.md): a careful player could leave a
-- provoked-only corporation alone for ever. From PERIMETER_START after landing its perimeter grows PERIMETER_STEP
-- tiles every PERIMETER_TICKS (at once after FLOOR_TICKS with no operation against a player), announced every
-- third step, with a named warning one step before it encloses a player structure; it stops at the nearest
-- player structure + 40, at PERIMETER_MAX from its origin, and short of another corporation's claim. Enclosing
-- a structure provokes it (encroachment).
local FLOOR_TICKS = 20 * 60 * 60
local PERIMETER_START = 30 * 3600
local PERIMETER_TICKS = 10 * 3600
local PERIMETER_STEP = 30
local PERIMETER_MAX = 450
local function nearest_player(b, surface, r)
  local best, bd
  for _, f in ipairs(enemies(game.forces[b.force])) do
    if not shared.is_corp(f.name) then
      for _, e in pairs(surface.find_entities_filtered{position = {b.origin.x, b.origin.y}, radius = r, force = f,
        type = TYPES}) do
        local d = math.sqrt((e.position.x - b.origin.x) ^ 2 + (e.position.y - b.origin.y) ^ 2)
        if not bd or d < bd then best, bd = e, d end
      end
    end
  end
  return best, bd
end

function ops.perimeter(b, tick)
  if not (shared.CORPS[b.corp].temper or {}).provoked_only or not b.claim_radius then return end
  b.landed = b.landed or tick
  local fast = storage.perimeter_fast
  local start, every = fast and 3600 or PERIMETER_START, fast and 3600 or PERIMETER_TICKS
  if tick - b.landed < start then return end
  local quiet = tick - (storage.threat_last or 0) > FLOOR_TICKS and tick - (b.perimeter_floor or 0) > FLOOR_TICKS
  if tick < (b.perimeter_next or 0) and not quiet then return end
  if quiet and tick < (b.perimeter_next or 0) then b.perimeter_floor = tick end
  b.perimeter_next = tick + every
  local surface = game.surfaces[b.surface]
  local cur = b.claim_radius
  local cap = PERIMETER_MAX
  local near, nd = nearest_player(b, surface, PERIMETER_MAX + PERIMETER_STEP)
  if nd then cap = math.min(cap, nd + 40) end
  -- A border the player set and keeps (border.lua): the line holds short of it.
  local bc = ops.border_cap and ops.border_cap(b)
  if bc then cap = math.min(cap, bc) end
  for _, o in pairs(storage.bases) do
    if o ~= b and not o.fallen and o.corp ~= b.corp and o.surface == b.surface and o.claim_radius then
      local d = math.sqrt((o.origin.x - b.origin.x) ^ 2 + (o.origin.y - b.origin.y) ^ 2)
      cap = math.min(cap, d - o.claim_radius)
    end
  end
  local new = math.min(cur + PERIMETER_STEP, cap)
  if new <= cur then return end
  -- The cordon (cordon.lua): the step is an arc of posts its drones build; the claim follows once they stand.
  if ops.cordon_step and ops.cordon_step(b, new, near) then return end
  ops.perimeter_advance(b, new, near, nd)
end

-- The claim steps out to `new` (at once, or once its cordon's arc stands): the map, the notices, the named warning.
function ops.perimeter_advance(b, new, near, nd)
  local surface = game.surfaces[b.surface]
  b.perimeter = new
  b.perimeter_steps = (b.perimeter_steps or 0) + 1
  if ops.claim_map then ops.claim_map(b) end
  local where = string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y, surface.name)
  -- One step ahead: the structure the next step will enclose, named.
  local warn = near and near.valid and nd and nd > new and nd <= new + PERIMETER_STEP and b.warned ~= near.unit_number
  if warn then b.warned = near.unit_number end
  for _, f in ipairs(enemies(game.forces[b.force])) do
    if #f.players > 0 and not shared.is_corp(f.name) then
      if b.perimeter_steps % 3 == 1 then
        shared.notice(f, {"lp.perimeter", shared.corp_label(b.corp), where, math.floor(new)})
      end
      if warn then
        shared.notice(f, {"lp.perimeter-warning", shared.corp_label(b.corp), near.localised_name,
          string.format("[gps=%d,%d,%s]", near.position.x, near.position.y, surface.name)})
      end
    end
  end
end

local function scan(b)
  local surface = game.surfaces[b.surface]
  if not b.lander.valid then return end
  sense_nests(b, surface)
  local sensors = {b.lander}
  for _, d in ipairs(b.depots) do if d.valid then table.insert(sensors, d) end end
  for _, r in ipairs(b.radars or {}) do if r.valid then table.insert(sensors, r) end end
  for _, s in ipairs(sensors) do
    local r = SENSORS[shared.kind_of(s.name)] or 100
    sense(b, surface, s.position, r)
    forget(b, s.position, r)
  end
end

-- A landing is heard: every other corporation learns where a newcomer came down (as the player is told), and
-- sight, alarms and raids do the rest (two corporations 249 tiles apart, beyond each other's sensors, never
-- fought).
function ops.heard_landing(newcomer)
  for _, o in pairs(storage.bases) do
    if o ~= newcomer and o.force ~= newcomer.force and o.lander.valid then
      ops.sense_at(o, newcomer.lander.position, 60)
    end
  end
end

-- What is around a building under fire: the faction knows who shoots at it (turret creep beyond every
-- sensor was never raided until alarms fed the intel).
function ops.sense_at(b, pos, r)
  ops.init(b)
  sense(b, game.surfaces[b.surface], {x = pos.x or pos[1], y = pos.y or pos[2]}, r or FIELD_SIGHT)
end

-- The survey: a settlement always knows where its rivals' factories are (a factory that size cannot hide). Every
-- SURVEY_TICKS it looks along the line to each player force's spawn, in SURVEY_STEP steps up to SURVEY_RANGE, and
-- senses what stands within SURVEY_SIGHT of the first point where that force's buildings are (landings kept out of a
-- megabase's researched artillery reach stood far beyond their sensors and knew none of its buildings, visit).
local SURVEY_TICKS, SURVEY_STEP, SURVEY_RANGE, SURVEY_SIGHT = 10 * 3600, 50, 2500, 150
local SURVEY_TYPES = {"mining-drill", "assembling-machine", "furnace", "electric-pole", "straight-rail", "train-stop",
  "ammo-turret", "electric-turret", "radar", "roboport", "container", "lab"}
local function survey(b)
  local s = game.surfaces[b.surface]
  for _, f in pairs(game.forces) do
    if shared.is_player_force(f) and not f.get_cease_fire(b.force) then
      local sp = f.get_spawn_position(s)
      local dx, dy = sp.x - b.origin.x, sp.y - b.origin.y
      local len = math.sqrt(dx * dx + dy * dy)
      if len > 1 then
        for d = SURVEY_STEP, math.min(SURVEY_RANGE, len), SURVEY_STEP do
          local p = {b.origin.x + dx / len * d, b.origin.y + dy / len * d}
          if s.count_entities_filtered{position = p, radius = SURVEY_STEP, force = f, type = SURVEY_TYPES, limit = 1} > 0 then
            sense(b, s, {x = p[1], y = p[2]}, SURVEY_SIGHT)
            b.front = b.front or {}
            b.front[f.name] = p
            break
          end
        end
      end
    end
  end
end

-- Units in the field see around them (patrols, responses, the operation's own force).
local function field_sight(b)
  local surface = game.surfaces[b.surface]
  local seen = 0
  local lists = {b.patrol or {}, b.op and b.op.members or {}}
  for _, r in ipairs(b.raids or {}) do table.insert(lists, r.members) end
  for _, list in ipairs(lists) do
    for _, u in ipairs(list) do
      if u.valid and seen < 6 then sense(b, surface, u.position, FIELD_SIGHT); seen = seen + 1 end
    end
  end
end

-- A static threat on the faction's ground (turret creep): targets near it are a priority for a while.
-- Counter-battery: a corporation building or unit killed by artillery tells every settlement of that corporation
-- on the surface where the battery stands (seen, and a threat there for THREAT_TICKS), and shelling provokes.
function ops.counter_battery(force, surface, battery, by)
  for _, b in pairs(storage.bases) do
    if b.force == force and not b.fallen and b.surface == surface.index and b.lander.valid then
      ops.sense_at(b, battery.position, 30)
      ops.threatened(b, battery.position)
      if by then ops.provoke(b.force, by, battery) end
      if not b.battery_seen or game.tick - b.battery_seen > 3600 then
        b.battery_seen = game.tick
        if ops.trace then ops.trace(b, string.format("shelled: a battery at %.0f,%.0f", battery.position.x, battery.position.y)) end
      end
    end
  end
end

-- Another corporation's lander destroyed by a player (faction.grudge): this settlement sees where the killer stood,
-- marks a threat there, and counts the defences round it one turret stronger. No provocation.
function ops.alarmed(b, pos)
  pos = {pos.x or pos[1], pos.y or pos[2]}
  ops.sense_at(b, pos, FIELD_SIGHT)
  ops.threatened(b, pos)
  for _, t in pairs(b.intel.targets) do
    if (t.pos[1] - pos[1]) ^ 2 + (t.pos[2] - pos[2]) ^ 2 <= 48 * 48 then t.resist = (t.resist or 0) + 1 end
  end
end

function ops.threatened(b, pos)
  ops.init(b)
  b.intel.threats = b.intel.threats or {}
  table.insert(b.intel.threats, {pos = {pos.x or pos[1], pos.y or pos[2]}, till = game.tick + THREAT_TICKS})
  if #b.intel.threats > 10 then table.remove(b.intel.threats, 1) end
end

local function threat_bonus(b, t)
  for i = #(b.intel.threats or {}), 1, -1 do
    local z = b.intel.threats[i]
    if game.tick >= z.till then
      table.remove(b.intel.threats, i)
    elseif (z.pos[1] - t.pos[1]) ^ 2 + (z.pos[2] - t.pos[2]) ^ 2 <= 40 * 40 then
      return THREAT_BONUS
    end
  end
  return 0
end

-- A faction unit killed by a hostile cause: where the defence is.
function ops.on_unit_killed(b, cause)
  if not (b.intel and cause and cause.valid) then return end
  table.insert(b.intel.markers, {pos = {cause.position.x, cause.position.y}, kind = cause.name, tick = game.tick})
  if #b.intel.markers > 60 then table.remove(b.intel.markers, 1) end
end

local function markers_near(b, pos, r)
  local n = 0
  for i = #b.intel.markers, 1, -1 do
    local m = b.intel.markers[i]
    if game.tick - m.tick > MARKER_TICKS then
      table.remove(b.intel.markers, i)
    elseif (m.pos[1] - pos[1]) ^ 2 + (m.pos[2] - pos[2]) ^ 2 <= r * r then
      n = n + 1
    end
  end
  return n
end

-- Operations leave from a depot; with none, from the lander (a camp under a megabase's guns never kept a depot, the
-- player's artillery fires on them by itself, and its escort of sixteen stood idle at the player's edge, visit).
local function home(b)
  for _, d in ipairs(b.depots) do if d.valid then return d end end
  if b.lander and b.lander.valid then return b.lander end
end

local function cap(b, army) return army.cap(b) end
-- A battery shelling it: self-defence, not an operation of choice. The reserve goes too, the threat budget does
-- not hold it, and it can be besieged before the siege capability (campaign runs: a settlement that knew where
-- the battery was raided substations for 45 minutes until its lander died).
local function battery(t) return t.kind == "artillery-turret" or t.kind == "artillery-wagon" end
-- What an operation of choice can send, and the reserve it leaves home (pool.floor). Committing the reserve keeps the
-- guard home (GUARD), as every taker does.
local function field(b, army)
  local floor = pool.floor(cap(b, army), "reserve")
  return math.max(0, pool.home(b) - floor), floor - pool.GUARD
end
local SOLDIER = function(u) return (u.type == "unit" or u.type == "spider-unit") and shared.kind_of(u.name) ~= "lp-hauler" end
local FOOT = function(u) return u.type == "unit" and shared.kind_of(u.name) ~= "lp-hauler" end
local function floor_of(b, army, committed) return pool.floor(cap(b, army), committed and "guard" or "reserve") end

-- The threat budget (docs/campaign.md section 6): operations against a player force at once, across every
-- corporation, are capped by that player's era (1 + era; era 0-4 from research done), so corporations do not
-- stack into a flood; corporations' operations against each other are not counted. The floor: when no
-- operation has gone against a player for FLOOR_TICKS, player targets weigh triple in every choice.
local ERA_TECHS = {25, 60, 100, 150}
function ops.era(force)
  local n = 0
  for _, t in pairs(force.technologies) do if t.researched then n = n + 1 end end
  local era = 0
  for i, k in ipairs(ERA_TECHS) do if n >= k then era = i end end
  return era
end
local against_player = stance.against_player
function ops.player_ops()
  local n = 0
  for _, o in pairs(storage.bases) do
    local t = o.op and o.intel and o.intel.targets[o.op.target]
    if t and against_player(t.owner) then n = n + 1 end
  end
  return n
end
local function budget(owner)
  local f = game.forces[owner]
  return 1 + (f and (storage.era_override or ops.era(f)) or 0)
end

-- Provocation (tempers): a player force that hurts a corporation's buildings or units is remembered for good. The one
-- entry for every provoking act (docs/ai.md, section 4: reactions): `at`, the culprit (an entity, or a position), asks
-- the corporation's settlement nearest it for an answer.
-- kind: "loss" (a unit, drone or building hurt; the default) or "trespass" (its ground, its border, a turret covering its
-- camp): each corporation answers each its own way (shared.CORPS temper.answers, ops.answer).
function ops.provoke(corp_force, by, at, kind)
  if not shared.is_corp(corp_force) or by == nil or shared.is_corp(by) or by == "enemy" or by == "neutral" then return end
  for corp, c in pairs(shared.CORPS) do
    if c.force == corp_force then
      storage.corps = storage.corps or {}
      storage.corps[corp] = storage.corps[corp] or {level = 0, exported = 0}
      local d = storage.corps[corp]
      d.provoked = d.provoked or {}
      d.provoked[by] = d.provoked[by] or game.tick
    end
  end
  if at then ops.request_answer(corp_force, by, at, kind) end
end

-- The answer (docs/ai.md, section 4; the user, 2026-10-17: their turrets killed Serenity's drones, it turned enemy and
-- did nothing they could see for the rest of the session). Provoked, the corporation's settlement nearest the culprit
-- (within ANSWER_RANGE of its home) sends a squad at it within a minute or two: a raid on the player's building nearest
-- the spot, its reserve with it, at least ANSWER_MIN. At most one an ANSWER_COOLDOWN a settlement; it waits while an
-- operation runs; a truce stops it (stance.may).
local ANSWER_COOLDOWN = 5 * 3600
local ANSWER_RANGE = 500
local ANSWER_MIN = 6
function ops.request_answer(corp_force, by, at, kind)
  if not against_player(by) then return end
  local p = at
  if type(at) == "userdata" then
    if not at.valid then return end
    p = at.position
  end
  local x, y = p.x or p[1], p.y or p[2]
  if not x then return end
  local best, bd
  for _, b in pairs(storage.bases or {}) do
    if b.force == corp_force and not b.fallen and b.lander and b.lander.valid then
      local h = home(b)
      if h then
        local d = (h.position.x - x) ^ 2 + (h.position.y - y) ^ 2
        if d <= ANSWER_RANGE ^ 2 and (not bd or d < bd) then best, bd = b, d end
      end
    end
  end
  if not best or best.answer or game.tick < (best.next_answer or 0) then return end
  best.answer = {owner = by, pos = {x, y}, tick = game.tick, kind = kind or "loss"}
end

-- The ladder (docs/reviews/2026-10-14-megabase-pressure-consult.md; the user: "even if they don't punch through, they
-- should at least destroy some buildings, or else it makes no sense"): minutes since a corporation last razed a
-- building of this player force (storage.last_raze, control.lua), its clock started at first sight. 10 minutes: soft
-- relaxes (Grubstake goes for weighted defence up to LADDER_SOFT) and Serenity's targets on that player weigh triple;
-- 20: operations cross biter country; 30: cost no object, the target with the best value for its defence gets the whole
-- garrison, the reserve with it, and the raid does not turn back. (20, 40 and 60 minutes at first: against a deathworld
-- base walled with gun turrets Grubstake did nothing for its first hour, visit.)
local LADDER_SOFT = 3
-- Each corporation keeps its own clock (corp, its force's name): Serenity's razes reset Grubstake's too, and Grubstake,
-- knowing only a turret-lined power line, stayed at rung 1 and razed nothing in an hour (visit deathworld).
-- The ladder and the rival's hold live in the stance (scripts/stance.lua); the names stay for the callers.
local ladder = stance.rung
ops.ladder = ladder
ops.rival_holds = stance.rival_holds

-- The player's claim markers (marker.lua): Grubstake reads the player's buildings within MARK_RADIUS of one as its own
-- claim, and leaves them alone (raids, strips, flares, rigs, taps).
local MARK_RADIUS = 40
function ops.marked(b, pos)
  if not (shared.CORPS[b.corp].temper or {}).pact or not storage.claim_markers then return false end
  local x, y = pos[1] or pos.x, pos[2] or pos.y
  for _, m in ipairs(storage.claim_markers) do
    if m.valid and m.surface.index == b.surface and (m.position.x - x) ^ 2 + (m.position.y - y) ^ 2 <= MARK_RADIUS ^ 2 then
      return true
    end
  end
  return false
end

-- Whether a corporation's temper lets it go for this target at all.
local function temper_allows(b, t)
  if not against_player(t.owner) then return true end
  if t.pos and ops.marked(b, t.pos) then return false end
  -- A paid truce (trade.lua): no raid on that player while it lasts; a battery shelling it is answered regardless of
  -- temper (counter-battery provokes anyway); else the stance (a provoked_only corporation once provoked).
  if stance.standing(b.corp, t.owner) == "truce" then return false end
  if battery(t) then return true end
  if not stance.may(b.corp, t.owner, "raid") then return false end
  local temper = shared.CORPS[b.corp].temper or {}
  -- Soft: what the player's turrets reach (exposure), up to 1.0 and LADDER_SOFT once the ladder relaxes it; at its top
  -- rung (cost no object) nothing (at a megabase every exposed spot was over 3, and nothing was ever razed, visit).
  local rung = ladder(t.owner, b.force)
  if temper.soft_only and rung < 3 and (t.exposure or t.defence or 0) > (rung >= 1 and LADDER_SOFT or 1.0) then return false end
  -- A thief does not break the drills that show it where the ore is: those are for strip-mining (it raided them
  -- instead, and had nothing left to strip).
  if temper.strips and t.value == ops.VALUE["mining-drill"] then return false end
  return true
end
ops.temper_allows = temper_allows

-- Known defence of a target: turrets seen by it, and deaths there (a turret per three markers).
-- Seen turrets, death markers, and resistance learned the hard way: a raid that attacked and razed nothing
-- (robots out-repairing four infantry, five raids on one substation) counts one turret more each time.
-- Divided by what its own research gives its units (rd.strength): a researched army reads the same turrets as less.
local function defence(b, t)
  local units = (t.units and game.tick - (t.units_at or 0) < UNITS_TICKS) and t.units or 0
  return ((t.defence or 0) + (t.resist or 0) + units + math.floor(markers_near(b, t.pos, DEFENCE_RADIUS) / 3))
    / rd.strength(b.corp, t.dmg)
end

local function needed(d) return math.ceil(PER_TURRET * d - 1e-9) + BASE_FORCE end

-- The best target worth the force the settlement can field: value over defence, nearer preferred, tried
-- targets less, cooling targets not at all.
local function choose(b, army)
  local h = home(b)
  if not h then return end
  -- At least what stands at home beyond the reserve: a camp with no depot has a cap of nought, and its escort of sixteen
  -- could afford nothing (visit, under the guns).
  local max_field = math.max(0, cap(b, army) - math.ceil(RESERVE * cap(b, army)), (field(b, army)))
  local best, bs
  local zones = {}
  for i = #(b.intel.cool or {}), 1, -1 do
    local z = b.intel.cool[i]
    if game.tick >= z.till then table.remove(b.intel.cool, i) else table.insert(zones, z) end
  end
  local function cooling(t)
    for _, z in ipairs(zones) do
      if (z.pos[1] - t.pos[1]) ^ 2 + (z.pos[2] - t.pos[2]) ^ 2 <= 48 * 48 then return true end
    end
  end
  local in_flight = ops.player_ops()
  local floor = game.tick - (storage.threat_last or 0) > FLOOR_TICKS
  -- A player force it is at war with and has not hurt for 40 minutes comes before rivals and nests (a rival's lander,
  -- worth 8, was always chosen over the player's buildings, and the ladder never applied, visit).
  local pressed = false
  for _, f in pairs(game.forces) do
    if shared.is_player_force(f) and ladder(f.name, b.force) >= 2
      and temper_allows(b, {owner = f.name, defence = 0, exposure = 0}) then
      pressed = true
    end
  end
  for key, t in pairs(b.intel.targets) do
    local player = against_player(t.owner)
    local held = player and in_flight >= budget(t.owner) and not battery(t)
    if held and game.tick >= (t.cool or 0) then storage.budget_holds = (storage.budget_holds or 0) + 1 end
    if not temper_allows(b, t) then held = true end
    -- Pressed (the ladder's second rung against a player it is at war with): that player's targets only, self-defence
    -- excepted (weighted 0.2, a rival's lander still won every choice on the user's save: 48 raids on landers, none on
    -- the player, visit).
    if pressed and not player and not battery(t) and threat_bonus(b, t) == 0 then held = true end
    -- Stood down (war.lua): nothing against a player but self-defence.
    if b.quiescent and player and not battery(t) and threat_bonus(b, t) == 0 then held = true end
    if game.tick >= (t.cool or 0) and not cooling(t) and not held then
      local d = defence(b, t)
      -- Self-defence (a battery, or a static threat on its ground: turret creep) takes the reserve too: weighted,
      -- three upgraded creeping turrets needed 21 and a garrison of 28 kept 9 home (defend).
      local desperate = player and ladder(t.owner, b.force) >= 3
      if desperate or needed(d) <= ((battery(t) or threat_bonus(b, t) > 0) and cap(b, army) or max_field) then
        local dist = math.sqrt((t.pos[1] - h.position.x) ^ 2 + (t.pos[2] - h.position.y) ^ 2)
        local s = (t.value * (t.line and 2 or 1) + threat_bonus(b, t)) / (1 + d) ^ 1.5 / (1 + dist / 300)
          / (1 + (t.line and 0 or t.tried))
          * ((player and (floor or ladder(t.owner, b.force) >= 1)) and 3 or 1) * (battery(t) and 10 or 1)
          * (desperate and 10 or 1) * ((not player and pressed) and 0.2 or 1)
        if not bs or s > bs then best, bs = key, s end
      end
    end
  end
  return best
end

-- Alerts (readability): an operation going in against a player puts a custom alert, with the corporation's icon,
-- on the nearest of that player's buildings, for every player of that force, on any surface they are on.
local function alert(b, t, key, at)
  -- A notice too (shared.notice): the engine's own alerts fire when the operation hits.
  if not (t and against_player(t.owner)) or not shared.notices_on() then return end
  local f = game.forces[t.owner]
  if not f or #f.players == 0 then return end
  local s = game.surfaces[b.surface]
  local p = at or t.pos
  local e = s.find_entities_filtered{position = p, radius = 40, force = f, limit = 1}[1]
  if not e then return end
  local c = shared.CORPS[b.corp]
  for _, player in pairs(f.players) do
    player.add_custom_alert(e, {type = "virtual", name = c.icon}, {key, c.name}, true) -- notice-ok: gated above
  end
  storage.alerts = (storage.alerts or 0) + 1
end
ops.alert = alert

-- A notice to the players at war with this corporation, with a map link.
local function notify(b, key, at)
  local s = game.surfaces[b.surface]
  for _, f in ipairs(enemies(game.forces[b.force])) do
    if #f.players > 0 and not shared.is_corp(f.name) then
      shared.notice(f, {key, shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", at[1], at[2], s.name)})
    end
  end
end

local function order_all(members, cmd)
  for _, u in ipairs(members) do if u.valid then u.commandable.set_command(cmd) end end
end

-- Whether a unit is still about an order worth keeping: on its way in (a compound), or attacking something that stands.
-- Idle or wandering (what a finished order leaves), it is free for a new one.
local function busy(u)
  local c = u.commandable.command
  if not c then return false end
  if c.type == defines.command.compound or c.type == defines.command.go_to_location then return true end
  if c.type == defines.command.attack then return c.target ~= nil and c.target.valid end
  return c.type == defines.command.attack_area
end

local function alive(op)
  local n = 0
  for _, u in ipairs(op.members) do if u.valid then n = n + 1 end end
  return n
end

local function finish(b, outcome, trace, army)
  local op = b.op
  local h = home(b)
  if op.mortar and op.mortar.valid then op.mortar.destroy() end
  for _, m in ipairs(op.mortars or {}) do if m.valid then m.destroy() end end
  if op.convoy and op.convoy.valid then
    b.haulers_home = b.haulers_home or {}
    table.insert(b.haulers_home, {unit = op.convoy, till = game.tick + 3 * 3600})
    if h then
      op.convoy.commandable.set_command{type = defines.command.go_to_location, destination = h.position, radius = 12,
        distraction = defines.distraction.none}
    end
  end
  if op.hauler and op.hauler.valid then
    -- The hauler drives home and is stood down there (it joins no garrison).
    b.haulers_home = b.haulers_home or {}
    table.insert(b.haulers_home, {unit = op.hauler, till = game.tick + 3 * 3600, cargo = op.cargo})
    if h then
      op.hauler.commandable.set_command{type = defines.command.go_to_location, destination = h.position, radius = 12,
        distraction = defines.distraction.none}
    end
  end
  if op.label and op.label.valid then op.label.destroy() end
  if op.kind == "siege" then b.next_siege = game.tick + (op.clearance and 2 * 3600 or SIEGE_COOL) end
  if op.kind == "strip" then
    b.next_strip = game.tick + (storage.strip_fast and 2 * 3600 or STRIP_COOL)
    for _, e in ipairs(op.camp or {}) do if e.valid then e.destroy() end end
  end
  -- Home round biter country too (four raiders came back from the target and died on the straight way home, country).
  local back
  for _, u in ipairs(op.members) do
    if u.valid and h and not back then
      back = {}
      for _, w in ipairs(ops.route(b, {u.position.x, u.position.y}, {h.position.x, h.position.y},
        op.overflight and {turrets = false, worms = true} or {turrets = false, nests = true}) or {}) do
        table.insert(back, {type = defines.command.go_to_location, destination = w, radius = 4,
          distraction = defines.distraction.by_damage})
      end
      table.insert(back, {type = defines.command.go_to_location, destination = h.position, radius = 10,
        distraction = defines.distraction.by_damage})
    end
  end
  for _, u in ipairs(op.members) do
    if u.valid then
      pool.give_one(b, u)
      if h then
        u.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
          commands = back}
      end
    end
  end
  local t = b.intel.targets[op.target]
  -- Razed nothing and attacked, or razed nothing and lost raiders on the way: resistance there.
  if t and op.kind == "raid" and op.razed0 and b.razed == op.razed0 and (op.attacked or alive(op) < op.launched) then
    t.resist = (t.resist or 0) + 1
    -- Walls round it: the ledger notes them (a Dozer's trigger, scripts/rd.lua).
    if op.attacked and game.surfaces[b.surface].count_entities_filtered{position = t.pos, radius = 20, type = "wall",
      force = enemies(game.forces[b.force]), limit = 1} > 0 then
      rd.walls_met(b)
    end
    local closest = math.huge
    for _, u in ipairs(op.members) do
      if u.valid then closest = math.min(closest, math.sqrt((u.position.x - t.pos[1]) ^ 2 + (u.position.y - t.pos[2]) ^ 2)) end
    end
    trace(b, string.format("raid razed nothing at %.0f,%.0f: resistance there now %d (nearest raider %.0f tiles off)",
      t.pos[1], t.pos[2], t.resist, closest))
  end
  if t then
    -- The longer rest stands (a clearance's failed nest, siege_step).
    t.cool = math.max(t.cool or 0, game.tick + (t.line and COOL_TICKS / 2 or COOL_TICKS))
    -- The whole position cools after an abort, not the one cell: an area, so cells first seen later inherit
    -- it (the turret's cell next door, scanned a minute after, was raided nine minutes later).
    if outcome == "aborted" then
      b.intel.cool = b.intel.cool or {}
      table.insert(b.intel.cool, {pos = t.pos, till = game.tick + COOL_TICKS})
    end
    if outcome == "aborted" then
      t.tried = (t.tried or 0) + 1
      t.defence = math.max(t.defence or 0, (ops.weigh(game.surfaces[b.surface], t.pos, enemies(game.forces[b.force]))))
    end
  end
  -- Loot reaches home with whoever survives (none, and it is lost).
  if op.loot and op.loot.value > 0 and alive(op) > 0 then
    b.parts = b.parts + math.floor(op.loot.value)
    b.looted = (b.looted or 0) + op.loot.items
    trace(b, string.format("raid home with %d items of loot: %d parts", op.loot.items, math.floor(op.loot.value)))
  end
  for _, e in ipairs(op.works or {}) do if e.valid then e.destroy() end end
  if outcome == "done" or outcome == "spent" or outcome == "claimed" then b.ops_done = b.ops_done + 1 else b.ops_aborted = b.ops_aborted + 1 end
  local lost = op.launched - alive(op)
  b.next_op = game.tick + tune.sooner(b.corp, (outcome == "done" or outcome == "spent" or outcome == "claimed") and GAP_DONE
    or GAP_ABORTED)
    + math.floor(lost / 5) * GAP_PER_5_LOST
  if op.clearance then b.next_op = game.tick + 3600 end
  -- What it saw there at the end is the record: destroyed targets are forgotten (a raid set out again for
  -- creep it had already destroyed).
  if t then
    local pos = {x = t.pos[1], y = t.pos[2]}
    local tick = game.tick
    local s = game.surfaces[b.surface]
    sense(b, s, pos, 40)
    for key, o in pairs(b.intel.targets) do
      if (o.pos[1] - pos.x) ^ 2 + (o.pos[2] - pos.y) ^ 2 <= 40 * 40 and o.seen < tick then
        -- A nest still standing is kept with what it taught (sense sees no spawners: its resistance and tries were
        -- wiped, and four raiders went for one spawner six times, razing nothing, visit deathworld).
        if o.owner == "enemy" and s.count_entities_filtered{position = o.pos, radius = 3, type = "unit-spawner", limit = 1} > 0 then
          o.seen = tick
        else
          b.intel.targets[key] = nil
        end
      end
    end
  end
  b.ops_log = b.ops_log or {}
  -- The owner as at launch (a target destroyed is forgotten, and its raid read as at nobody: nests).
  table.insert(b.ops_log, {op = op.kind, kind = t and t.kind or "gone", owner = t and t.owner or op.owner, outcome = outcome,
    launched = op.launched, started = op.started,
    back = alive(op), shells = op.shells_fired, site = op.site})
  if #b.ops_log > 10 then table.remove(b.ops_log, 1) end
  trace(b, string.format("%s %s: %d of %d came back (target %s)", op.kind, outcome, alive(op), op.launched,
    t and t.kind or "gone"))
  b.op = nil
end

-- A staging point on the line home from the target, at least `off` out: beyond every turret's reach and outside
-- the player's walls (no wall between it and home). Staged at a fixed offset, a raid's point fell inside a walled
-- base (-56,31 behind a wall at 70): it timed out there and attacked from outside, unhurt and harmless.
local outside_ray
-- The staging point: on the line from the target toward home, else (water, walls) on lines turned up to 90 degrees
-- either side: across a lake from home, every substation's line ended in the water, and a camp sent nothing in three
-- hours (visit nw).
local TURNS = {0, 20, -20, 40, -40, 60, -60, 80, -80}
local function outside(b, t, ux, uy, off, len)
  for _, deg in ipairs(TURNS) do
    local a = math.rad(deg)
    local vx, vy = ux * math.cos(a) - uy * math.sin(a), ux * math.sin(a) + uy * math.cos(a)
    local p = outside_ray(b, t, vx, vy, off, len, true)
    if p then return p end
  end
  return outside_ray(b, t, ux, uy, off, len, false)
end
outside_ray = function(b, t, ux, uy, off, len, strict)
  local s = game.surfaces[b.surface]
  local foes = enemies(game.forces[b.force])
  local function walled(p)
    for k = 4, math.min(160, len - 1), 4 do
      if s.count_entities_filtered{position = {p[1] + ux * k, p[2] + uy * k}, radius = 2.5, type = {"wall", "gate"},
        force = foes, limit = 1} > 0 then return true end
    end
    return false
  end
  for d = off, math.min(len, off + 160), 4 do
    local p = {t.pos[1] + ux * d, t.pos[2] + uy * d}
    -- Not among nests either (a staging point 35 tiles from a worm could never be reached round biter country).
    if s.count_entities_filtered{position = p, radius = STAND_OFF, type = TURRETS, force = foes, limit = 1} == 0
      and (t.owner == "enemy" or s.count_entities_filtered{position = p, radius = 50, type = {"unit-spawner", "turret"},
        force = "enemy", limit = 1} == 0)
      -- Nor by water: staged on a lake shore, a raid on a substation found no way to its staging point, the same six
      -- points one after another for three hours (visit nw).
      and s.count_tiles_filtered{position = p, radius = 8, collision_mask = "water_tile", limit = 1} == 0
      and not walled(p) then
      return p
    end
  end
  -- Nowhere better: at the stand-off, unless that is water (nil: no staging point; a substation on a pier out in a
  -- lake was staged for in deep water, every few minutes for three hours, visit nw). A turned line takes only a clean
  -- point.
  if strict then return nil end
  local p = {t.pos[1] + ux * off, t.pos[2] + uy * off}
  if s.count_tiles_filtered{position = p, radius = 2, collision_mask = "water_tile", limit = 1} > 0 then return nil end
  return p
end

-- Sneaking and breaching (Grubstake's temper; the user: "do they try to avoid turrets? And perhaps make holes in
-- undefended sections of the wall?"). From its staging point a sneaking raid plans its approach on a SNEAK_CELL grid
-- (A*), round every cell within a known turret's reach (REACH by type, plus SNEAK_MARGIN) and water, exposed only in
-- the last SNEAK_OPEN tiles to the target; it walks the route as waypoints. Walls round the target (within
-- BREACH_RADIUS): it picks the wall piece the fewest turrets can reach, knocks it and its neighbour out (a two-tile gap,
-- buggies fit), and goes through. Serenity keeps its straight, disciplined approach.
local SNEAK_CELL, SNEAK_MARGIN, SNEAK_OPEN, SNEAK_BOX = 6, 3, 16, 120
local BREACH_RADIUS = 30
local REACH = {["ammo-turret"] = 18, ["electric-turret"] = 24, ["fluid-turret"] = 30}

-- Biter country (the user: "raids and sieges will also need to cross biter country to reach us sometimes"): every
-- corporation's marches route round spawners (NEST_KEEP.spawner) and worms (NEST_KEEP.worm: a behemoth worm's reach
-- and a margin); only Grubstake also keeps out of turret reach. opts: {turrets = bool, nests = bool}.
local NEST_KEEP = {spawner = 30, worm = 50}
-- Corridors: where spawners died lately (any force: a clearance, the player's artillery, a landing's burn); within
-- CORRIDOR_RADIUS of one, nests do not block a cell (Grubstake follows Serenity's survey crews).
local CORRIDOR_TICKS, CORRIDOR_RADIUS = 30 * 3600, 30
function ops.cleared(surface, pos)
  storage.corridors = storage.corridors or {}
  table.insert(storage.corridors, {surface = surface.index, pos = {pos.x, pos.y}, tick = game.tick})
  -- Oldest first: drop the expired from the front.
  while storage.corridors[1] and (game.tick - storage.corridors[1].tick > CORRIDOR_TICKS or #storage.corridors > 400) do
    table.remove(storage.corridors, 1)
  end
end
-- Within box ({{x1, y1}, {x2, y2}}) when given: a megabase's artillery kills spawners all the time, far from any route
-- (a raid that failed for nests was planned again every two minutes on that, visit nw).
function ops.cleared_since(surface, tick, box)
  for i = #(storage.corridors or {}), 1, -1 do
    local c = storage.corridors[i]
    if c.tick <= tick then return false end
    if c.surface == surface and (not box or (c.pos[1] >= box[1][1] and c.pos[1] <= box[2][1] and c.pos[2] >= box[1][2]
      and c.pos[2] <= box[2][2])) then return true end
  end
  return false
end
-- A corporation at cease-fire with the biters, both ways (shared.CORPS temper.pact, control.lua).
function ops.pact(force)
  local f = game.forces[force]
  return f and game.forces.enemy and f.get_cease_fire("enemy") and game.forces.enemy.get_cease_fire(f) or false
end
local ENCLOSED_PROBE = 3000
local NEIGHBOURS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
local function sneak_route(b, from, to, opts, wide)
  opts = opts or {turrets = true, nests = true}
  local SNEAK_BOX = wide and 3 * SNEAK_BOX or SNEAK_BOX
  local s = game.surfaces[b.surface]
  local foes = enemies(game.forces[b.force])
  local x0 = math.min(from[1], to[1]) - SNEAK_BOX
  local y0 = math.min(from[2], to[2]) - SNEAK_BOX
  local w = math.ceil((math.max(from[1], to[1]) + SNEAK_BOX - x0) / SNEAK_CELL)
  local h = math.ceil((math.max(from[2], to[2]) + SNEAK_BOX - y0) / SNEAK_CELL)
  local box = {{x0 - 60, y0 - 60}, {x0 + w * SNEAK_CELL + 60, y0 + h * SNEAK_CELL + 60}}
  local turrets = opts.turrets and s.find_entities_filtered{area = box, type = {"ammo-turret", "electric-turret",
    "fluid-turret"}, force = foes} or {}
  -- Air units (opts.worms) keep clear of worms only: spawners do not shoot.
  -- A pact with the biters (Grubstake: "We don't fight bugs"): nests and worms let it pass (a cease-fire, both ways).
  local nests = (opts.nests and not ops.pact(b.force) and s.find_entities_filtered{area = box, type = {"unit-spawner", "turret"}, force = "enemy"})
    or (opts.worms and s.find_entities_filtered{area = box, type = "turret", force = "enemy"}) or {}
  local function centre(i, j) return x0 + (i + 0.5) * SNEAK_CELL, y0 + (j + 0.5) * SNEAK_CELL end
  -- Each turret's and nest's reach marked on the grid once (a cell then looks itself up): testing buckets of them per
  -- cell took 300 ms on a failed route through a deathworld (12,000 cells), and before the buckets, seconds against a
  -- megabase's thousands of turrets.
  local function mark(list, reach)
    local out = {}
    for _, e in ipairs(list) do
      local r = reach(e)
      local ex, ey = e.position.x, e.position.y
      for i = math.max(0, math.floor((ex - r - x0) / SNEAK_CELL)), math.min(w - 1, math.floor((ex + r - x0) / SNEAK_CELL)) do
        for j = math.max(0, math.floor((ey - r - y0) / SNEAK_CELL)), math.min(h - 1, math.floor((ey + r - y0) / SNEAK_CELL)) do
          local cx, cy = centre(i, j)
          if (ex - cx) ^ 2 + (ey - cy) ^ 2 <= r * r then out[i * h + j] = true end
        end
      end
    end
    return out
  end
  local tmark = mark(turrets, function(e) return (REACH[e.type] or 20) + SNEAK_MARGIN end)
  local nmark = mark(nests, function(e) return e.type == "unit-spawner" and NEST_KEEP.spawner or NEST_KEEP.worm end)
  -- Corridors on this surface within the box, once per route.
  local corr = {}
  for _, c in ipairs(storage.corridors or {}) do
    if c.surface == b.surface and game.tick - c.tick <= CORRIDOR_TICKS
      and c.pos[1] >= box[1][1] and c.pos[1] <= box[2][1] and c.pos[2] >= box[1][2] and c.pos[2] <= box[2][2] then
      table.insert(corr, c.pos)
    end
  end
  local function in_corridor(cx, cy)
    for _, c in ipairs(corr) do
      if (c[1] - cx) ^ 2 + (c[2] - cy) ^ 2 <= CORRIDOR_RADIUS ^ 2 then return true end
    end
    return false
  end
  local blocked = {}
  local function open(i, j)
    if i < 0 or j < 0 or i >= w or j >= h then return false end
    local k = i * h + j
    if blocked[k] == nil then
      local cx, cy = centre(i, j)
      local bad = false
      if tmark[k] and (cx - to[1]) ^ 2 + (cy - to[2]) ^ 2 > SNEAK_OPEN ^ 2 then bad = true end
      if not bad and nmark[k] and not in_corridor(cx, cy) then bad = true end
      if not bad and s.count_tiles_filtered{position = {cx, cy}, radius = 2, collision_mask = "water_tile", limit = 1} > 0 then
        bad = true
      end
      blocked[k] = bad
    end
    return not blocked[k]
  end
  local function cell(p) return math.floor((p[1] - x0) / SNEAK_CELL), math.floor((p[2] - y0) / SNEAK_CELL) end
  local si, sj = cell(from)
  local ti, tj = cell(to)
  -- A staging point sealed in by turrets (Grubstake's sneaking leg inside a factory's ring): the search from home
  -- flooded the open country outside, 21,000 cells and 80 ms, before it failed, 43 times in three hours (visit nw).
  -- The pocket round the target is small: flooded first from there, within ENCLOSED_PROBE cells, it fails at once
  -- (the same cells and moves as the search, so it fails only where the search would). Bounded by the box's edge is
  -- not sealed: only a pocket walled in all round counts. The wide box has its own grid, so its own probe.
  do
    local seen, queue, qi, escapes = {[ti * h + tj] = true}, {{ti, tj}}, 1, false
    while queue[qi] and #queue <= ENCLOSED_PROBE and not escapes do
      local ci, cj = queue[qi][1], queue[qi][2]
      qi = qi + 1
      for _, d in ipairs(NEIGHBOURS) do
        local ni, nj = ci + d[1], cj + d[2]
        if (ni == si and nj == sj) or ni < 0 or nj < 0 or ni >= w or nj >= h then escapes = true; break end
        local nk = ni * h + nj
        if not seen[nk] and open(ni, nj) then seen[nk] = true; queue[#queue + 1] = {ni, nj} end
      end
    end
    if not escapes and not queue[qi] then
      local nb = 0
      for _, v in pairs(blocked) do if v then nb = nb + 1 end end
      ops.last_route = {nests = #nests, turrets = #turrets, blocked = nb, cells = w * h, found = false, steps = 0,
        enclosed = #queue}
      if not wide then return sneak_route(b, from, to, opts, true) end
      return nil
    end
  end
  -- A* over the grid, eight neighbours.
  local key = function(i, j) return i * h + j end
  local function hdist(i, j) return math.sqrt((i - ti) ^ 2 + (j - tj) ^ 2) end
  -- Open set as a binary heap on f (stale entries are skipped when popped).
  local heap = {}
  local function push(f, i, j)
    local n = #heap + 1
    heap[n] = {f, i, j}
    while n > 1 do
      local p = math.floor(n / 2)
      if heap[p][1] <= heap[n][1] then break end
      heap[p], heap[n] = heap[n], heap[p]
      n = p
    end
  end
  local function pop()
    local top, last = heap[1], table.remove(heap)
    if #heap > 0 then
      heap[1] = last
      local n = 1
      while true do
        local l, r, m = 2 * n, 2 * n + 1, n
        if heap[l] and heap[l][1] < heap[m][1] then m = l end
        if heap[r] and heap[r][1] < heap[m][1] then m = r end
        if m == n then break end
        heap[m], heap[n] = heap[n], heap[m]
        n = m
      end
    end
    return top
  end
  local g, came = {[key(si, sj)] = 0}, {}
  push(hdist(si, sj), si, sj)
  local closed = {}
  local found = false
  local steps = 0
  while #heap > 0 and steps < (wide and 16000 or 4000) do
    local _, ci, cj = table.unpack(pop())
    local ck = key(ci, cj)
    if closed[ck] then goto next end
    steps = steps + 1
    if ci == ti and cj == tj then found = true; break end
    closed[ck] = true
    for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}) do
      local ni, nj = ci + d[1], cj + d[2]
      local nk = key(ni, nj)
      if not closed[nk] and ((ni == ti and nj == tj) or open(ni, nj)) then
        local ng = g[ck] + ((d[1] ~= 0 and d[2] ~= 0) and 1.414 or 1)
        if not g[nk] or ng < g[nk] then
          g[nk], came[nk] = ng, ck
          push(ng + hdist(ni, nj), ni, nj)
        end
      end
    end
    ::next::
  end
  local nb = 0
  for _, v in pairs(blocked) do if v then nb = nb + 1 end end
  ops.last_route = {nests = #nests, turrets = #turrets, blocked = nb, cells = w * h, found = found, steps = steps}
  -- Water the box could not get round: once more over a box three times as wide (a lake 100 tiles across kept Grubstake's
  -- raids home for 40 minutes, visit nw; left to the engine, the raiders stood at home: its pathfinder gave up the detour).
  if not found and not wide and steps < 4000 then return sneak_route(b, from, to, opts, true) end
  if not found then return nil end
  -- Back from the target, every third cell a waypoint (the engine's pathfinder walks between them).
  local cells = {}
  local k = key(ti, tj)
  while k do
    table.insert(cells, 1, k)
    k = came[k]
  end
  local route = {}
  for n = 2, #cells - 1 do
    if n % 3 == 0 then
      local i, j = math.floor(cells[n] / h), cells[n] % h
      local cx, cy = centre(i, j)
      table.insert(route, {cx, cy})
    end
  end
  return route
end

ops.route = sneak_route

-- Pushing through biter country (the megabase consult): with no way round, an operation still goes when its target is
-- worth it (effective value PUSH_VALUE, the line and the ladder's triple counted) or the ladder has reached its second
-- rung, through at most PUSH_CROSSINGS nests: an escort of 4 a spawner and 2 a worm near the straight path, times
-- (1 + evolution), fights the way through. Returns the escort's size, or nil (not sent).
local PUSH_VALUE, PUSH_CROSSINGS = 6, 6
local function crossings(b, from, to)
  local s = game.surfaces[b.surface]
  local len = math.sqrt((to[1] - from[1]) ^ 2 + (to[2] - from[2]) ^ 2)
  local seen, sp, worms = {}, 0, 0
  for k = 0, math.max(1, math.floor(len / 20)) do
    local f = k / math.max(1, math.floor(len / 20))
    local p = {from[1] + (to[1] - from[1]) * f, from[2] + (to[2] - from[2]) * f}
    for _, e in pairs(s.find_entities_filtered{position = p, radius = 40, type = {"unit-spawner", "turret"}, force = "enemy"}) do
      if not seen[e.unit_number] then
        seen[e.unit_number] = true
        if e.type == "unit-spawner" then sp = sp + 1 else worms = worms + 1 end
      end
    end
  end
  return sp, worms
end
local function push_escort(b, t, from, to)
  local sp, worms = crossings(b, from, to)
  -- A corporation that besieges clears its way instead of pushing (ops.clearance, the biter-country consult: 27 units
  -- pushed through a wall of worms and 25 died); one that never does, at the top rung, goes through with all it has.
  if (sp + worms) > 0 and shared.capable(b.corp, "siege", 99) then return nil, sp, worms end
  if t.owner and ladder(t.owner, b.force) >= 3 then return 1000, sp, worms end
  if sp + worms > PUSH_CROSSINGS then return nil, sp, worms end
  local worth = (t.value or 0) * (t.line and 2 or 1) * ((t.owner and ladder(t.owner, b.force) >= 1) and 3 or 1)
  if worth < PUSH_VALUE and not (t.owner and ladder(t.owner, b.force) >= 2) then return nil, sp, worms end
  local evo = game.forces.enemy.get_evolution_factor(game.surfaces[b.surface])
  return math.ceil((4 * sp + 2 * worms) * (1 + evo)), sp, worms
end
ops.push_escort = push_escort

-- The wall piece by the target the fewest turrets can reach (ties: nearest the staging point), and its neighbour.
local function breach_point(b, t, from)
  local s = game.surfaces[b.surface]
  local foes = enemies(game.forces[b.force])
  local walls = s.find_entities_filtered{position = t.pos, radius = BREACH_RADIUS, type = {"wall", "gate"}, force = foes}
  if #walls == 0 then return end
  local turrets = s.find_entities_filtered{position = t.pos, radius = BREACH_RADIUS + 30,
    type = {"ammo-turret", "electric-turret", "fluid-turret"}, force = foes}
  local best, bc, bd
  for n, wl in ipairs(walls) do
    if n % 2 == 1 or #walls < 200 then
      -- Reach plus the room a crowd at the wall takes (a piece just out of reach left the raiders gathered round it
      -- inside the flank lasers' reach: 16 of 31 lost and the raid aborted, sneak).
      local c = 0
      for _, e in ipairs(turrets) do
        local r = (REACH[e.type] or 20) + 6
        if (e.position.x - wl.position.x) ^ 2 + (e.position.y - wl.position.y) ^ 2 <= r * r then c = c + 1 end
      end
      local d = (wl.position.x - from[1]) ^ 2 + (wl.position.y - from[2]) ^ 2
      if not bc or c < bc or (c == bc and d < bd) then best, bc, bd = wl, c, d end
    end
  end
  if not best then return end
  local pieces = {best}
  local near = s.find_entities_filtered{position = best.position, radius = 1.5, type = {"wall", "gate"}, force = foes}
  for _, e in ipairs(near) do
    if e ~= best and #pieces < 2 then table.insert(pieces, e) end
  end
  return pieces, bc
end

-- The first wall piece (and its neighbour) on the straight line from `from` to `to`, for a raid that does not sneak:
-- Serenity's raids on substations behind a wall walked its length looking for a way in and gave up 360 tiles off
-- (visit nw).
local function wall_on_line(b, from, to)
  local s = game.surfaces[b.surface]
  local foes = enemies(game.forces[b.force])
  local dx, dy = to[1] - from[1], to[2] - from[2]
  local len = math.sqrt(dx * dx + dy * dy)
  for d = 2, len - 2, 2 do
    local q = {from[1] + dx / len * d, from[2] + dy / len * d}
    local w = s.find_entities_filtered{position = q, radius = 1.5, type = {"wall", "gate"}, force = foes, limit = 1}[1]
    if w then
      local pieces = {w}
      for _, e in ipairs(s.find_entities_filtered{position = w.position, radius = 1.5, type = {"wall", "gate"}, force = foes}) do
        if e ~= w and #pieces < 2 then table.insert(pieces, e) end
      end
      return pieces
    end
  end
end

-- Looting (Grubstake's temper: the user's heists, folded into its identity, docs/reviews/2026-10-14-identity-trees-consult
-- .md): a raid at the target first empties the player's chests within 16 tiles that one of its units stands by (6
-- tiles), valuable items first, up to LOOT_ITEMS a raid; what survivors carry home becomes parts (finish), by LOOT.
local LOOT = {["uranium-235"] = 20, ["uranium-fuel-cell"] = 10, ["processing-unit"] = 8, ["low-density-structure"] = 4,
  ["rocket-fuel"] = 3, ["advanced-circuit"] = 3, ["electronic-circuit"] = 1, ["engine-unit"] = 1,
  ["electric-engine-unit"] = 2, ["flying-robot-frame"] = 3, ["speed-module"] = 10, ["efficiency-module"] = 10,
  ["productivity-module"] = 10, ["speed-module-2"] = 20, ["efficiency-module-2"] = 20, ["productivity-module-2"] = 20,
  ["speed-module-3"] = 40, ["efficiency-module-3"] = 40, ["productivity-module-3"] = 40, ["steel-plate"] = 0.3}
local LOOT_ITEMS = 400
ops.LOOT_VALUE = LOOT
local function loot(b, op, t, pos, surface, trace)
  if not (shared.CORPS[b.corp].temper or {}).loots or not (t and against_player(t.owner)) then return end
  op.loot = op.loot or {items = 0, value = 0, looted = {}}
  if op.loot.items >= LOOT_ITEMS then return end
  -- Wagons too (the megabase consult's heist: a train at an outpost station emptied).
  for _, c in pairs(surface.find_entities_filtered{position = pos, radius = 16, type = {"container", "logistic-container", "cargo-wagon"},
    force = t.owner}) do
    if not op.loot.looted[c.unit_number] and surface.count_entities_filtered{position = c.position, radius = 6,
      force = b.force, type = "unit", limit = 1} > 0 then
      op.loot.looted[c.unit_number] = true
      local inv = c.get_inventory(c.type == "cargo-wagon" and defines.inventory.cargo_wagon or defines.inventory.chest)
      local items = {}
      for _, it in pairs(inv and inv.get_contents() or {}) do table.insert(items, it) end
      table.sort(items, function(x, y) return (LOOT[x.name] or 0.1) > (LOOT[y.name] or 0.1) end)
      for _, it in ipairs(items) do
        local want = math.min(it.count, LOOT_ITEMS - op.loot.items)
        if want <= 0 then break end
        local took = inv.remove{name = it.name, count = want, quality = it.quality}
        op.loot.items = op.loot.items + took
        op.loot.value = op.loot.value + took * (LOOT[it.name] or 0.1)
      end
      if not op.loot.alerted then
        op.loot.alerted = true
        alert(b, t, "lp.alert-loot", {c.position.x, c.position.y})
      end
      trace(b, string.format("looting a %s at %.0f,%.0f: %d items carried (worth %.0f)", c.name, c.position.x,
        c.position.y, op.loot.items, op.loot.value))
    end
  end
end

ops.loot = loot

-- A container its raiders destroyed is looted from the wreck (the raid razed a chest before its looting step came
-- round, every 5 seconds, and took nothing: ability).
function ops.loot_wreck(b, ent)
  local op = b.op
  if not (op and op.kind == "raid" and (shared.CORPS[b.corp].temper or {}).loots) then return end
  op.loot = op.loot or {items = 0, value = 0, looted = {}}
  if op.loot.looted[ent.unit_number] or op.loot.items >= LOOT_ITEMS then return end
  op.loot.looted[ent.unit_number] = true
  local inv = ent.get_inventory(ent.type == "cargo-wagon" and defines.inventory.cargo_wagon or defines.inventory.chest)
  for _, it in pairs(inv and inv.get_contents() or {}) do
    local took = math.min(it.count, LOOT_ITEMS - op.loot.items)
    op.loot.items = op.loot.items + took
    op.loot.value = op.loot.value + took * (LOOT[it.name] or 0.1)
  end
end

local DEAD_END_RADIUS, DEAD_END_TICKS = 64, 30 * 3600
local function launch(b, key, trace, army, opts)
  local t = b.intel.targets[key]
  local h = home(b)
  local d = defence(b, t)
  local want = needed(d)
  local n, reserve = field(b, army)
  local desperate = against_player(t.owner) and ladder(t.owner, b.force) >= 3
  local is_answer = opts and opts.answer
  if battery(t) or threat_bonus(b, t) > 0 or desperate or is_answer then n = n + reserve end
  -- Cost no object (the ladder): what the garrison has goes, however few.
  if desperate then want = math.min(want, n) end
  -- An answer (ops.request_answer): at least ANSWER_MIN, what it has if fewer.
  if is_answer then want = math.min(math.max(want, ANSWER_MIN), n) end
  if n < want or n == 0 then return false end
  -- Grubstake provoked (an enemy of that player, standing.lua) raids with half what it can field, not what the target's
  -- known defence calls for: its camps of 31 to 54 sent raids of 4 at the user's poles, and the user saw "no hostile
  -- action" (2026-10-17).
  local cd = storage.corps and storage.corps[b.corp]
  if (shared.CORPS[b.corp].temper or {}).soft_only and against_player(t.owner) and cd and cd.provoked
    and cd.provoked[t.owner] then
    want = math.max(want, math.min(n, math.ceil(ENEMY_SHARE * n)))
  end
  local committed = battery(t) or threat_bonus(b, t) > 0 or desperate or is_answer
  local members = pool.take(b, want, floor_of(b, army, committed), SOLDIER)
  -- What field() counted may not be there to send (haulers, the dead): no raid of nought (a camp launched four, visit).
  if #members == 0 then return false end
  local dx, dy = h.position.x - t.pos[1], h.position.y - t.pos[2]
  local len = math.max(1, math.sqrt(dx * dx + dy * dy))
  -- Out of reach of the outermost turret, not of the target's centre (staged 34 from an assembler, a raid
  -- stood inside the range of the turrets on the walls 12 tiles out and lost 15 of 34 before attacking).
  local spread = 0
  for _, e in pairs(game.surfaces[b.surface].find_entities_filtered{position = t.pos, radius = DEFENCE_RADIUS, type = TURRETS,
    force = enemies(game.forces[b.force])}) do
    spread = math.max(spread, math.sqrt((e.position.x - t.pos[1]) ^ 2 + (e.position.y - t.pos[2]) ^ 2))
  end
  local off = math.min(STAND_OFF + spread, len)
  local stage = outside(b, t, dx / len, dy / len, off, len)
  if not stage then
    for _, u in ipairs(members) do table.insert(b.garrison, u) end
    t.cool = game.tick + 15 * 3600
    b.next_op = game.tick + 2 * 3600
    trace(b, string.format("raid on %s at %.0f,%.0f: no staging point on dry land; not sent", t.kind, t.pos[1], t.pos[2]))
    return false
  end
  b.op = {kind = "raid", answer = is_answer or nil, target = key, phase = "stage", members = members, launched = #members, staging = stage, owner = t.owner,
    started = game.tick, phase_at = game.tick, kills_at = b.razed, last_kill = game.tick, razed0 = b.razed}
  -- A sneaking raid (Grubstake) marches to its staging point round the turrets it knows of and fights only what hits
  -- it: engaging on sight, it walked into five lasers on its way and lost 25 of 31 before the attack (sneak).
  local sneaks = (shared.CORPS[b.corp].temper or {}).sneaks and not storage.sneak_off and against_player(t.owner)
  -- Round biter country, whoever marches (a nest as the target excepted: Serenity clears its ground).
  -- Nests that blocked this march still block it until a spawner dies (a corridor, ops.cleared): not planned again
  -- (Serenity re-planned the same failed raid on a Grubstake generator every two minutes, 300 ms each time, visit
  -- deathworld10x).
  -- Staging inside a factory's turrets (Grubstake's sneaking leg): one substation after another in the same enclosure,
  -- each search running dry over 20,000 cells, 100 ms each (visit nw). A staging point near one that failed for turrets
  -- lately, from the same home, is taken to fail too.
  local route, why
  local u = t.unrouted
  b.dead_ends = b.dead_ends or {}
  while b.dead_ends[1] and game.tick - b.dead_ends[1].tick > DEAD_END_TICKS do table.remove(b.dead_ends, 1) end
  local dead
  for _, d in ipairs(b.dead_ends) do
    if d.home == h.unit_number and (d.pos[1] - stage[1]) ^ 2 + (d.pos[2] - stage[2]) ^ 2 <= DEAD_END_RADIUS ^ 2 then dead = d end
  end
  if u and u.home == h.unit_number and not ops.cleared_since(b.surface, u.tick, u.box) then
    why = u.why
  elseif dead then
    why = "near a staging point that failed lately: " .. dead.why
  else
    route = sneak_route(b, {h.position.x, h.position.y}, stage, {turrets = sneaks, nests = t.owner ~= "enemy"})
    why = route and "" or string.format("to staging %.0f,%.0f (%s)", stage[1], stage[2], serpent.line(ops.last_route))
    -- The whole way, the attack leg too (staged short of a wall of nests, four raiders went straight through it, push).
    if route and t.owner ~= "enemy" and not sneak_route(b, stage, {t.pos[1], t.pos[2]}, {turrets = false, nests = true}) then
      route = nil
      why = "the attack leg " .. serpent.line(ops.last_route)
    end
    -- Nests alone: turrets (Grubstake's sneaking leg) can fall without a corridor opening.
    -- Every box the searches covered (the wide one, round both legs): a spawner killed in it may open a way.
    local m = 3 * SNEAK_BOX + 60
    local ubox = {{math.min(h.position.x, stage[1], t.pos[1]) - m, math.min(h.position.y, stage[2], t.pos[2]) - m},
      {math.max(h.position.x, stage[1], t.pos[1]) + m, math.max(h.position.y, stage[2], t.pos[2]) + m}}
    t.unrouted = not route and why:find("nests = [1-9]") and why:find("turrets = 0[,}]")
      and {home = h.unit_number, tick = game.tick, why = why, box = ubox} or nil
    if not route and not why:find("turrets = 0[,}]") then
      table.insert(b.dead_ends, {pos = {stage[1], stage[2]}, home = h.unit_number, tick = game.tick, why = why})
    end
  end
  -- Overflight (Grubstake, the biter-country consult: "We don't fight bugs"): no way round on the ground, and air
  -- units at home: up to six fly over the nests (round the worms, which shoot at them), take the target, and fly home.
  -- Only at the ladder's top rung (cost no object): spawners' defenders bite harriers out of the air (six of six over a
  -- wall of nests, overflight), and a trigger target mask on the biters' bite did not stop it.
  if not route and not shared.capable(b.corp, "siege", 99) and against_player(t.owner) and ladder(t.owner, b.force) >= 3 then
    -- From the raid as picked, then the garrison.
    local air = {}
    for _, list in ipairs({members, b.garrison}) do
      for i = #list, 1, -1 do
        local u = list[i]
        local k = u.valid and shared.kind_of(u.name)
        if #air < 6 and (k == "lp-harrier" or k == "lp-scavenger") then table.insert(air, table.remove(list, i)) end
      end
    end
    local aroute = #air >= 3 and sneak_route(b, {h.position.x, h.position.y}, {t.pos[1], t.pos[2]}, {turrets = false, worms = true})
    if aroute then
      for _, u in ipairs(members) do table.insert(b.garrison, u) end
      local cmds = {}
      for _, w in ipairs(aroute) do
        table.insert(cmds, {type = defines.command.go_to_location, destination = w, radius = 4, distraction = defines.distraction.none})
      end
      table.insert(cmds, {type = defines.command.attack_area, destination = {t.pos[1], t.pos[2]}, radius = 12,
        distraction = defines.distraction.by_anything})
      order_all(air, {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = cmds})
      b.op.members, b.op.launched, b.op.phase, b.op.phase_at = air, #air, "attack", game.tick
      b.op.attacked, b.op.overflight, b.op.last_kill, b.op.kills_at = true, true, game.tick, b.razed
      b.overflights = (b.overflights or 0) + 1
      b.ops_launched = b.ops_launched + 1
      b.raids_sent = b.raids_sent + 1
      storage.threat_last = game.tick
      trace(b, string.format("overflight on %s at %.0f,%.0f: %d air units over biter country (%d waypoints)", t.kind,
        t.pos[1], t.pos[2], #air, #aroute))
      return true
    end
    for _, u in ipairs(air) do table.insert(b.garrison, u) end
  end
  if not route then
    local escort, sp, worms = push_escort(b, t, {h.position.x, h.position.y}, {t.pos[1], t.pos[2]})
    -- Too many nests to push through, for a target the ladder or its worth says to go for: clear a way first, a raid
    -- on the nearest spawner by the straight path (the evolution refund stands, biters.lua).
    local worth = (t.value or 0) * (t.line and 2 or 1) * (ladder(t.owner, b.force) >= 1 and 3 or 1)
    local clears = shared.capable(b.corp, "siege", 99)
    if not escort and (clears or sp + worms > PUSH_CROSSINGS) and sp + worms > 0
      and (worth >= PUSH_VALUE or ladder(t.owner, b.force) >= 2) then
      -- The nest nearest home within 40 tiles of the straight way, worms as well as spawners (one clearance 33 tiles
      -- from the first spawner left the worms behind it in reach of the next raid).
      local s = game.surfaces[b.surface]
      local hx, hy = h.position.x, h.position.y
      local dx, dy = t.pos[1] - hx, t.pos[2] - hy
      local len2 = math.max(1, dx * dx + dy * dy)
      local near, nd
      for _, e in pairs(s.find_entities_filtered{position = {hx, hy}, radius = math.sqrt(len2), type = {"unit-spawner", "turret"},
        force = "enemy"}) do
        local f = math.max(0, math.min(1, ((e.position.x - hx) * dx + (e.position.y - hy) * dy) / len2))
        local off = (hx + dx * f - e.position.x) ^ 2 + (hy + dy * f - e.position.y) ^ 2
        local d = (e.position.x - hx) ^ 2 + (e.position.y - hy) ^ 2
        if off <= 40 * 40 and (not nd or d < nd) then near, nd = e, d end
      end
      if near and shared.capable(b.corp, "siege", 99) then
        -- Serenity extends its line through them: a clearance siege (ops.clearance), not a raid on a nest (18 of 18 lost).
        b.op = nil
        for _, u in ipairs(members) do table.insert(b.garrison, u) end
        t.cool = game.tick + 2 * 3600
        trace(b, string.format("raid on %s at %.0f,%.0f: %d nests in the way; a clearance first", t.kind, t.pos[1], t.pos[2],
          sp + worms))
        return ops.clearance(b, near, trace, army, {t.pos[1], t.pos[2]})
      elseif near and false then
        b.op = nil
        for _, u in ipairs(members) do table.insert(b.garrison, u) end
        local key = "nest:" .. math.floor(near.position.x / CELL) .. "," .. math.floor(near.position.y / CELL)
        b.intel.targets[key] = b.intel.targets[key] or {tried = 0, cool = 0}
        local nt = b.intel.targets[key]
        nt.pos, nt.kind, nt.value, nt.seen, nt.owner = {near.position.x, near.position.y}, near.name, 3, game.tick, "enemy"
        nt.defence = s.count_entities_filtered{position = near.position, radius = DEFENCE_RADIUS, force = "enemy", type = "turret"}
        trace(b, string.format("raid on %s at %.0f,%.0f: %d nests in the way; clears a way first, at %.0f,%.0f", t.kind,
          t.pos[1], t.pos[2], sp + worms, near.position.x, near.position.y))
        t.cool = game.tick + 2 * 3600
        return launch(b, key, trace, army)
      end
    end
    if escort then
      for _, u in ipairs(pool.take(b, escort, floor_of(b, army, committed), FOOT)) do table.insert(members, u) end
      b.op.launched, b.op.pushed = #members, true
      route = {}
      trace(b, string.format("raid on %s pushes through biter country (%d spawners, %d worms): %d units", t.kind, sp,
        worms, #members))
    end
  end
  if not route then
    -- Registered above: undone, or it went ahead anyway (four raiders attacked through the nests and died, country).
    b.op = nil
    for _, u in ipairs(members) do table.insert(b.garrison, u) end
    -- Briefly: it cost nothing, and the ladder may send it soon (cooled ten minutes, it was never tried again, push).
    -- The settlement waits too: one target after another refused every 30 s re-planned routes all night (visit).
    -- Longer when the march itself is the problem (water and turrets): the same unreachable substation was chosen every
    -- two minutes for half an hour while the factory had hundreds of others (visit nw).
    t.cool = game.tick + ((t.owner ~= "enemy" and not why:find("nests = [1-9]")) and 15 or 2) * 3600
    -- Behind turrets it cannot get round: guarded, whatever stands by it (a substation inside a laser wall counted as
    -- undefended, and Grubstake's flares, which go at guarded targets, never knew of one, visit nw).
    if why and not why:find("turrets = 0[,}]") then t.exposure = math.max(t.exposure or 0, 1) end
    b.next_op = game.tick + 2 * 3600
    trace(b, string.format("raid on %s at %.0f,%.0f: no way round biter country; not sent (%s)", t.kind, t.pos[1], t.pos[2],
      why or ""))
    return false
  end
  -- Every march answers only what hits it: engaging what it saw, Serenity's raids through nest country broke off at every
  -- passing biter and were 270 to 350 tiles from their targets when they gave up (visit nw, 85 units lost for nothing).
  local how = defines.distraction.by_damage
  local cmds = {}
  for _, w in ipairs(route) do
    table.insert(cmds, {type = defines.command.go_to_location, destination = w, radius = 4, distraction = how})
  end
  table.insert(cmds, {type = defines.command.go_to_location, destination = stage, radius = 6, distraction = how})
  order_all(members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
    commands = cmds})
  b.op_route = route
  -- Time to reach the staging point: by the march's length, more where the engine finds its own way round water (a
  -- fixed 90 s sent a raid in while its raiders were still 237 tiles off, walking round a lake, visit nw).
  local march, px, py = 0, h.position.x, h.position.y
  for _, w in ipairs(route) do march = march + math.sqrt((w[1] - px) ^ 2 + (w[2] - py) ^ 2); px, py = w[1], w[2] end
  march = march + math.sqrt((stage[1] - px) ^ 2 + (stage[2] - py) ^ 2)
  if #route == 0 then march = march * 1.6 end
  b.op.stage_ticks = STAGE_TICKS + math.floor(march / MARCH_SPEED)
  b.ops_launched = b.ops_launched + 1
  b.raids_sent = b.raids_sent + 1
  if against_player(t.owner) then storage.threat_last = game.tick end
  if t.owner == "enemy" then
    for _, f in pairs(game.forces) do
      if #f.players > 0 then
        shared.notice(f, {"lp.clearing", shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", t.pos[1], t.pos[2],
          game.surfaces[b.surface].name)})
      end
    end
  end
  trace(b, string.format("raid on %s at %.0f,%.0f (value %d, defence %.1f): %d units stage at %.0f,%.0f", t.kind,
    t.pos[1], t.pos[2], t.value, d, #members, stage[1], stage[2]))
  return true
end

-- A site for the mortar: from the target towards home (then at angles off that line), the first point beyond
-- every known player turret's reach with one of them within the mortar's, on dry land.
local function siege_site(b, t)
  local s = game.surfaces[b.surface]
  local h = home(b)
  local foes = enemies(game.forces[b.force])
  local base = math.atan2(h.position.y - t.pos[2], h.position.x - t.pos[1])
  for _, turn in ipairs({0, 0.35, -0.35, 0.7, -0.7}) do
    local a = base + turn
    for d = 20, 70, 2 do
      local p = {t.pos[1] + math.cos(a) * d, t.pos[2] + math.sin(a) * d}
      if s.count_entities_filtered{position = p, radius = PLAYER_REACH, type = TURRETS, force = foes} == 0 then
        if s.count_entities_filtered{position = p, radius = MORTAR_REACH, type = TURRETS, force = foes} > 0
          and s.count_tiles_filtered{position = p, radius = 4, collision_mask = "water_tile"} == 0 then
          return p
        end
        break
      end
    end
  end
end

-- At most one siege against a player force at a time, across corporations (a battery excepted).
local function besieged(owner)
  for _, o in pairs(storage.bases) do
    local t = o.op and o.op.kind == "siege" and o.intel and o.intel.targets[o.op.target]
    if t and t.owner == owner then return true end
  end
end

local function choose_siege(b, army, only_battery)
  if (b.parts or 0) < SIEGE_COST or game.tick < (b.next_siege or 0) then return end
  -- A capability, not every corporation's (Serenity's from level 1; Grubstake never besieges).
  -- A settlement landed with a grudge besieges whatever its corporation's level or temper (faction.grudge).
  local capable = shared.capable(b.corp, "siege", army.level(b)) or b.grudge ~= nil
  -- Against a battery, a corporation that ever besieges does so now (Grubstake never does: it raids).
  local counter = shared.capable(b.corp, "siege", 99)
  local in_flight = ops.player_ops()
  local n = field(b, army)
  if n < SIEGE_GUARDS then return end
  local h = home(b)
  local best, bs, site
  for key, t in pairs(b.intel.targets) do
    if (not only_battery or battery(t)) and (capable or (counter and battery(t))) and ((t.defence or 0) >= 2 or battery(t))
      and not (b.quiescent and against_player(t.owner) and not battery(t))
      and not (against_player(t.owner) and in_flight >= budget(t.owner) and not battery(t))
      and not (against_player(t.owner) and not battery(t) and besieged(t.owner))
      and stance.may(b.corp, t.owner, "siege") then
      local dist = math.sqrt((t.pos[1] - h.position.x) ^ 2 + (t.pos[2] - h.position.y) ^ 2)
      local s = (t.value + threat_bonus(b, t)) / (1 + dist / 300) * (battery(t) and 10 or 1)
      if not bs or s > bs then
        local p = siege_site(b, t)
        if p then best, bs, site = key, s, p end
      end
    end
  end
  return best, site
end

-- The tier this settlement can mount against t now: its level, held to a player's era + 1, a grudge one up, then down
-- to what its parts and field afford.
local function siege_tier(b, t, army)
  local k = math.max(1, army.level(b))
  if against_player(t.owner) then k = math.min(k, budget(t.owner)) end
  if b.grudge then k = k + 1 end
  -- The ladder's top rung against that player: a tier more, past the budget (b.war_rung, war.lua).
  if against_player(t.owner) and (b.war_rung or 0) >= 3 then k = k + 1 end
  k = math.min(k, #SIEGE_TIERS)
  local n, reserve = field(b, army)
  if battery(t) then n = n + reserve end
  while k > 1 and ((b.parts or 0) < SIEGE_TIERS[k].cost or n < SIEGE_TIERS[k].guards) do k = k - 1 end
  return k
end
ops.siege_tier = siege_tier

local function launch_siege(b, key, site, trace, army, tier_override, clearance)
  local t = b.intel.targets[key]
  local tier = tier_override or storage.siege_tier or siege_tier(b, t, army)
  local spec = SIEGE_TIERS[tier]
  local h = home(b)
  local s = game.surfaces[b.surface]
  -- Out past its own outermost wall on the way to the site: gates open for no unit, and a hauler made beside a depot in a
  -- gated block drove at its wall, 21 to 31 tiles short of its site, siege after siege (visit b - rocket).
  local hx, hy = h.position.x, h.position.y
  local dist = math.max(1, math.sqrt((site[1] - hx) ^ 2 + (site[2] - hy) ^ 2))
  local out = 0.1 * dist
  for d = 0, dist, 2 do
    local q = {hx + (site[1] - hx) * d / dist, hy + (site[2] - hy) * d / dist}
    if s.count_entities_filtered{position = q, radius = 2.5, force = h.force, type = {"wall", "gate"}, limit = 1} > 0 then
      out = math.min(d + 5, dist)
    end
  end
  local p = s.find_non_colliding_position(shared.variant(b.corp, "lp-hauler"), {hx + (site[1] - hx) * out / dist,
    hy + (site[2] - hy) * out / dist}, 20, 0.5)
  local hauler = p and s.create_entity{name = shared.variant(b.corp, "lp-hauler"), position = p, force = h.force}
  if not hauler then return false end
  local guards = {}
  -- Counter-battery (Serenity): against the player's artillery, its Shock troopers go first (up to six).
  local floor = floor_of(b, army, battery(t))
  if battery(t) and rd.has(b.corp, "counter") then
    guards = pool.take(b, 6, floor, function(u) return shared.kind_of(u.name) == "lp-shock" end)
  end
  -- A clearance (nests): its railgunners go first, the biter-clearing unit.
  if clearance or t.owner == "enemy" then
    for _, u in ipairs(pool.take(b, spec.guards - #guards, floor, function(u) return shared.kind_of(u.name) == "lp-railgunner" end)) do
      table.insert(guards, u)
    end
  end
  -- A clearance takes railgunners only: Line troopers next to them died to the nest's big biters and killed next to
  -- none (nine of them killed one of sixteen, scenario rail).
  if not (clearance or t.owner == "enemy") then
    for _, u in ipairs(pool.take(b, spec.guards - #guards, floor, function(u) return u.type == "unit" end)) do
      table.insert(guards, u)
    end
  end
  b.parts = math.max(0, b.parts - spec.cost)
  -- The guards ride out on the hauler: gates open for no unit, and guards walking from home were 33 to 49 tiles off when
  -- the biters broke the mortars (visit b - rocket).
  for _, u in ipairs(guards) do
    local q = u.valid and s.find_non_colliding_position(u.name, hauler.position, 12, 0.5)
    if q then u.teleport(q) end
  end
  b.op = {kind = "siege", target = key, phase = "march", members = guards, launched = #guards, hauler = hauler,
    site = site, started = game.tick, phase_at = game.tick, shells_fired = 0, tier = tier,
    convoys_left = spec.convoys or 0}
  b.op.clearance = clearance
  -- Round biter country (the hauler is slow and alone: through a nest field it never arrived).
  -- A clearance's march keeps out of its worms' reach (straight on, its guards walked into a behemoth's, review).
  local hroute = sneak_route(b, {hauler.position.x, hauler.position.y}, site,
    clearance and {turrets = false, worms = true} or {turrets = false, nests = (b.intel.targets[key] or {}).owner ~= "enemy"})
  if not hroute and clearance then hroute = sneak_route(b, {hauler.position.x, hauler.position.y}, site, {turrets = false}) end
  if not hroute and b.intel.targets[key] and push_escort(b, b.intel.targets[key], {hauler.position.x, hauler.position.y}, site) then
    hroute = {}
    b.op.pushed = true
    trace(b, string.format("hauler pushes through biter country to %.0f,%.0f", site[1], site[2]))
  end
  if not hroute then
    for _, u in ipairs(guards) do table.insert(b.garrison, u) end
    b.op = nil
    b.parts = b.parts + spec.cost
    hauler.destroy()
    local tt = b.intel.targets[key]
    if tt then tt.cool = game.tick + COOL_TICKS end
    trace(b, string.format("%s to %.0f,%.0f: no way round biter country; not sent", "siege", site[1], site[2]))
    -- The settlement waits too (re-planned every 30 s, all night, visit).
    b.next_siege = game.tick + 2 * 3600
    b.next_op = game.tick + 2 * 3600
    return false
  end
  local hcmds = {}
  for _, w in ipairs(hroute) do
    table.insert(hcmds, {type = defines.command.go_to_location, destination = w, radius = 4,
      distraction = defines.distraction.none})
  end
  table.insert(hcmds, {type = defines.command.go_to_location, destination = site, radius = 2,
    distraction = defines.distraction.none})
  hauler.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
    commands = hcmds}
  -- A clearance's guards answer only what hits them on the march: on sight, railgunners (vision 34, range 30) walked up
  -- to the worms they saw, into a behemoth's 48 (review of scenario clear).
  order_all(guards, {type = defines.command.go_to_location, destination = hauler.position, radius = 6,
    distraction = clearance and defines.distraction.by_damage or defines.distraction.by_enemy})
  b.ops_launched = b.ops_launched + 1
  b.sieges = (b.sieges or 0) + 1
  if against_player(t.owner) then storage.threat_last = game.tick end
  trace(b, string.format("siege of %s at %.0f,%.0f (value %d, defence %.1f): tier %d, %d mortars to %.0f,%.0f, %d guards",
    t.kind, t.pos[1], t.pos[2], t.value, t.defence or 0, tier, spec.mortars, site[1], site[2], #guards))
  return true
end

-- Clearance (Serenity, the biter-country consult): a siege on the nest nearest its way, from a site 33 tiles off
-- (beyond a medium worm's 30), always dug in, tier 2 (two mortars, a resupply convoy). Its mortars fire on the nests by
-- themselves; it packs up when nothing is left in reach, and the corridor it leaves (ops.cleared) lets marches through.
-- The site 33 tiles from a nest, towards `from` (then at angles off that line), out of every worm's own reach plus 2
-- (its prototype's range: a big worm's 38 and a behemoth's 48 outrange the mortars' 35, and at maximum evolution the
-- hauler died on the way every two minutes all night, visit). None: mortars cannot clear it.
local function out_of_worms(s, p)
  for _, w in pairs(s.find_entities_filtered{position = p, radius = 52, type = "turret", force = "enemy"}) do
    local ap = w.prototype.attack_parameters
    local r = (ap and ap.range or 30) + 2
    if (w.position.x - p[1]) ^ 2 + (w.position.y - p[2]) ^ 2 <= r * r then return false end
  end
  return true
end
local function clearance_site(s, nest, from, stand)
  stand = stand or 33
  local base = math.atan2(from[2] - nest.position.y, from[1] - nest.position.x)
  for _, turn in ipairs({0, 0.35, -0.35, 0.7, -0.7}) do
    local p = {nest.position.x + math.cos(base + turn) * stand, nest.position.y + math.sin(base + turn) * stand}
    if out_of_worms(s, p) and s.count_entities_filtered{position = p, radius = 4, collision_mask = "water_tile", limit = 1} == 0 then
      return p
    end
  end
end
-- The next nest on the way from `from` to `to` (within 40 tiles of the straight line, nearest `from`).
local function nest_on_way(s, from, to)
  local dx, dy = to[1] - from[1], to[2] - from[2]
  local len2 = math.max(1, dx * dx + dy * dy)
  local near, nd
  for _, e in pairs(s.find_entities_filtered{position = from, radius = math.sqrt(len2), type = {"unit-spawner", "turret"},
    force = "enemy"}) do
    local f = math.max(0, math.min(1, ((e.position.x - from[1]) * dx + (e.position.y - from[2]) * dy) / len2))
    local off = (from[1] + dx * f - e.position.x) ^ 2 + (from[2] + dy * f - e.position.y) ^ 2
    local d = (e.position.x - from[1]) ^ 2 + (e.position.y - from[2]) ^ 2
    if off <= 40 * 40 and (not nd or d < nd) then near, nd = e, d end
  end
  return near
end

function ops.clearance(b, near, trace, army, toward)
  if not shared.capable(b.corp, "siege", 99) or b.op then return false end
  local h = home(b)
  if not h then return false end
  local s = game.surfaces[b.surface]
  local key = "nest:" .. math.floor(near.position.x / CELL) .. "," .. math.floor(near.position.y / CELL)
  b.intel.targets[key] = b.intel.targets[key] or {tried = 0, cool = 0}
  local t = b.intel.targets[key]
  t.pos, t.kind, t.value, t.seen, t.owner = {near.position.x, near.position.y}, near.name, 3, game.tick, "enemy"
  t.defence = s.count_entities_filtered{position = near.position, radius = DEFENCE_RADIUS, force = "enemy", type = "turret"}
  -- A nest whose clearance failed rests (t.cool, siege_step; b.nest_rest outlives the intel, which forgets nests off
  -- its claim: the same refusal was traced every two minutes).
  b.nest_rest = b.nest_rest or {}
  if (t.cool or 0) > game.tick or (b.nest_rest[key] or 0) > game.tick then return false end
  local piece, reach = "lp-mortar", MORTAR_REACH
  local site = clearance_site(s, near, {h.position.x, h.position.y})
  if not site then
    -- Worms that outrange the mortar: the howitzer, from beyond a behemoth worm's reach.
    site = clearance_site(s, near, {h.position.x, h.position.y}, HOWITZER_STAND)
    piece, reach = "lp-howitzer", HOWITZER_REACH
  end
  if not site then
    t.cool = game.tick + 15 * 3600
    b.nest_rest[key] = t.cool
    trace(b, string.format("clearance: the nest at %.0f,%.0f outranges even the howitzer", near.position.x, near.position.y))
    return false
  end
  if (b.parts or 0) < SIEGE_TIERS[2].cost then return false end
  -- Railgunners to hold the site: the nest's defenders came out at the first shells and broke the mortars of eight Line
  -- troopers in 35 s (visit b - rocket). Until it has CLEAR_RAILS at home, it asks for them (army.produce) and waits.
  local rails = 0
  for _, u in ipairs(b.garrison) do if u.valid and shared.kind_of(u.name) == "lp-railgunner" then rails = rails + 1 end end
  b.want_rails = rails < CLEAR_RAILS * 2
  if rails < CLEAR_RAILS then
    if not b.rails_traced then
      b.rails_traced = true
      trace(b, string.format("clearance: waits for railgunners (%d of %d)", rails, CLEAR_RAILS))
    end
    return false
  end
  b.rails_traced = nil
  local ok = launch_siege(b, key, site, trace, army, 2, true)
  if ok then
    b.op.piece, b.op.reach = piece, reach
    b.op.clear_for = toward
    b.clearances = (b.clearances or 0) + 1
    trace(b, string.format("clearance: a siege on the nest at %.0f,%.0f from %.0f,%.0f%s", near.position.x, near.position.y,
      site[1], site[2], piece == "lp-howitzer" and ", a howitzer (its worms outrange the mortars)" or ""))
  end
  return ok
end

local function siege_step(b, trace, army)
  local op = b.op
  local n = alive(op)
  if game.tick - op.started > SIEGE_MAX_TICKS then
    if op.hauler and op.hauler.valid then
      local hp = op.hauler.position
      trace(b, string.format("siege: out of time in %s, the hauler at %.0f,%.0f, %.0f tiles from the site (%s)", op.phase, hp.x, hp.y,
        math.sqrt((hp.x - op.site[1]) ^ 2 + (hp.y - op.site[2]) ^ 2), op.hauler.commandable.has_command and "moving" or "no order"))
    end
    return finish(b, "aborted", trace, army)
  end
  if op.phase == "march" or op.phase == "deploy" then
    if not op.hauler.valid then
      trace(b, "siege: the hauler was destroyed on the way")
      -- A clearance's nest rests 15 minutes (retried every two, it lost a hauler each time, visit).
      local t = op.clearance and b.intel.targets[op.target]
      if t then t.cool = game.tick + 15 * 3600 end
      return finish(b, "intercepted", trace, army)
    end
  end
  if op.phase == "march" then
    local hp = op.hauler.position
    if not op.hauler.commandable.has_command then
      op.hauler.commandable.set_command{type = defines.command.go_to_location, destination = op.site, radius = 2,
        distraction = defines.distraction.none}
    end
    order_all(op.members, {type = defines.command.go_to_location, destination = hp, radius = 6,
      distraction = op.clearance and defines.distraction.by_damage or defines.distraction.by_enemy})
    -- Stuck (a hauler drove at the same spot 21 tiles short of its site for 15 minutes, visit b - rocket): no nearer for a
    -- minute, a clearance deploys where it stands if the nest is in the mortars' reach and it is out of the worms'; else
    -- the siege is called off now.
    local d2 = (hp.x - op.site[1]) ^ 2 + (hp.y - op.site[2]) ^ 2
    if not op.best_d2 or d2 < op.best_d2 - 4 then op.best_d2, op.best_at = d2, game.tick end
    if game.tick - op.best_at > STUCK_TICKS and d2 >= 5 * 5 then
      local t = b.intel.targets[op.target]
      local s = op.hauler.surface
      if op.clearance and t and (hp.x - t.pos[1]) ^ 2 + (hp.y - t.pos[2]) ^ 2 <= (op.reach or MORTAR_REACH) ^ 2
        and out_of_worms(s, {hp.x, hp.y}) then
        trace(b, string.format("siege: the hauler is stuck %.0f tiles short; it deploys where it stands", math.sqrt(d2)))
        op.site = {hp.x, hp.y}
        d2 = 0
      else
        trace(b, string.format("siege: the hauler is stuck %.0f tiles short of its site; called off", math.sqrt(d2)))
        if t then t.cool = math.max(t.cool or 0, game.tick + 15 * 3600) end
        return finish(b, "aborted", trace, army)
      end
    end
    if d2 < 5 * 5 then
      op.phase, op.phase_at = "deploy", game.tick
      op.hauler.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none}
      -- Guards fight only what hits them: engaging what they saw, they walked from the site into turret range
      -- and four of six died (abort).
      -- A clearance's guards are on guard duty instead (bombard).
      local guard_eye = defines.distraction.by_damage
      order_all(op.members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = {{type = defines.command.go_to_location, destination = op.site, radius = 8,
          distraction = guard_eye},
          {type = defines.command.wander, radius = 8, distraction = guard_eye}}})
      op.label = rendering.draw_text{text = "Deploying", surface = op.hauler.surface,
        target = {entity = op.hauler, offset = {0, -2}}, color = {1, 0.6, 0.3}, scale = 1.5, alignment = "center"}
      trace(b, string.format("siege: deploying at %.0f,%.0f", op.site[1], op.site[2]))
    end
  elseif op.phase == "deploy" then
    local share = (game.tick - op.phase_at) / DEPLOY_TICKS
    if op.label and op.label.valid then op.label.text = string.format("Deploying %d%%", math.min(100, share * 100)) end
    if share >= 1 then
      local s = op.hauler.surface
      local spec = SIEGE_TIERS[op.tier or 1]
      local name = shared.variant(b.corp, op.piece or "lp-mortar")
      local guns = op.piece == "lp-howitzer" and 1 or spec.mortars
      local carry = op.carry
      op.mortars, op.carry = {}, nil
      if not carry then op.loaded = 0 end
      for k = 1, (carry and #carry or guns) do
        local a = 2 * math.pi * k / spec.mortars
        local off = spec.mortars > 1 and 4 or 0
        local p = s.find_non_colliding_position(name, {op.site[1] + math.cos(a) * off, op.site[2] + math.sin(a) * off}, 8, 0.5)
        local m = p and s.create_entity{name = name, position = p, force = op.hauler.force}
        if m then
          local shells = carry and carry[k] or spec.shells * (op.piece == "lp-howitzer" and 2 or 1)
          if shells > 0 then m.insert{name = "lp-mortar-shell", count = shells} end
          if not carry then op.loaded = op.loaded + shells end
          table.insert(op.mortars, m)
        end
      end
      op.mortar = op.mortars[1]
      if not op.mortar then return finish(b, "aborted", trace, army) end
      if op.label and op.label.valid then op.label.destroy() end
      op.phase, op.phase_at = "bombard", game.tick
      alert(b, b.intel.targets[op.target], "lp.alert-siege", op.site)
      trace(b, string.format("siege: %d mortars up with %d shells", #op.mortars, op.loaded - op.shells_fired))
      -- Hardened siege (Serenity): the site digs in, a ring of wall open towards home and two gun pillboxes, cleared
      -- when the siege ends (op.works).
      if (rd.has(b.corp, "hardened") or op.clearance) and not op.works then
        op.works = {}
        local h = home(b)
        local away = h and math.atan2(h.position.y - op.site[2], h.position.x - op.site[1]) or 0
        for k = 0, 35 do
          local a = 2 * math.pi * k / 36
          local d = math.abs(((a - away + math.pi) % (2 * math.pi)) - math.pi)
          if d > 0.5 then
            local p = {op.site[1] + math.cos(a) * 7, op.site[2] + math.sin(a) * 7}
            local w = s.can_place_entity{name = shared.variant(b.corp, "lp-wall"), position = p, force = op.hauler.force}
              and s.create_entity{name = shared.variant(b.corp, "lp-wall"), position = p, force = op.hauler.force}
            if w then table.insert(op.works, w) end
          end
        end
        for _, dx in ipairs({-3, 3}) do
          local p = s.find_non_colliding_position("lp-gun-turret", {op.site[1] + dx, op.site[2] + 3}, 4, 0.5)
          local g = p and s.create_entity{name = "lp-gun-turret", position = p, force = op.hauler.force}
          if g then
            g.insert{name = "piercing-rounds-magazine", count = 50}
            table.insert(op.works, g)
          end
        end
        trace(b, string.format("siege: the site dug in (%d pieces)", #op.works))
      end
    end
  elseif op.phase == "bombard" or op.phase == "assault" then
    -- Guard duty (a clearance): biters that come for the mortars are shot, and the guards go back to the site. Told to
    -- engage on sight they charged the spawner 32 tiles off and died; told to answer only what hit them, they let the
    -- biters break the mortars (scenario clear, visit b - rocket).
    -- (siege_step runs every 300 ticks.)
    if op.clearance then
      local s = game.surfaces[b.surface]
      -- Tighter at a howitzer's site: 24 out from it, guards stood in behemoth worms' reach (82 of 111 lost to acid).
      local guard_r = op.piece == "lp-howitzer" and GUARD_RADIUS / 2 or GUARD_RADIUS
      local foes = s.find_entities_filtered{position = op.site, radius = guard_r, type = "unit", force = "enemy"}
      if #foes > 0 then
        -- Within the ring only, undistracted: chasing biters, they followed them into the worms (scenario clear: railgunners
        -- killed by behemoth worms 26 to 31 tiles out).
        order_all(op.members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
          commands = {{type = defines.command.attack_area, destination = op.site, radius = guard_r,
            distraction = defines.distraction.none},
            {type = defines.command.go_to_location, destination = op.site, radius = 6, distraction = defines.distraction.none},
            -- A lasting order at the end: idle, a unit attacks whatever it sees, and guards walked into the worms.
            {type = defines.command.wander, radius = 5, distraction = defines.distraction.by_damage}}})
      end
    end
    local live = {}
    for _, m in ipairs(op.mortars or {op.mortar}) do if m.valid then table.insert(live, m) end end
    op.mortars, op.mortar = live, live[1]
    if not op.mortar and op.phase == "bombard" then
      trace(b, "siege: the mortars were destroyed")
      return finish(b, "aborted", trace, army)
    end
    local left, empty = 0, {}
    for _, m in ipairs(live) do
      local k = m.get_inventory(defines.inventory.artillery_turret_ammo).get_item_count("lp-mortar-shell")
      left = left + k
      if k == 0 then table.insert(empty, m) end
    end
    op.shells_fired = (op.loaded or SIEGE_SHELLS) - left
    local s = game.surfaces[b.surface]
    local foes = enemies(game.forces[b.force])
    -- Nothing left in reach for a minute: done (with eight shells fired and every turret in reach destroyed,
    -- a mortar sat idle until the siege timed out).
    local in_reach = 0
    for _, m in ipairs(live) do
      -- A clearance's targets are the nests (the player's turrets for any other siege).
      in_reach = in_reach + (op.clearance
        and s.count_entities_filtered{position = m.position, radius = op.reach or MORTAR_REACH, type = {"unit-spawner", "turret"}, force = "enemy"}
        or s.count_entities_filtered{position = m.position, radius = op.reach or MORTAR_REACH, type = TURRETS, force = foes})
    end
    if in_reach > 0 then op.last_target = game.tick end
    -- Resupply: a convoy of shells when the mortars are spent and a turret is still in reach.
    if op.convoy and not op.convoy.valid then
      trace(b, "siege: the shell convoy was destroyed; no more resupply")
      op.convoy, op.convoys_left = nil, 0
    elseif op.convoy then
      local cp = op.convoy.position
      if not op.convoy.commandable.has_command then
        op.convoy.commandable.set_command{type = defines.command.go_to_location, destination = op.site, radius = 2,
          distraction = defines.distraction.none}
      end
      if (cp.x - op.site[1]) ^ 2 + (cp.y - op.site[2]) ^ 2 < 8 * 8 and op.mortar then
        -- To the spent mortars (every one, if none is spent by now).
        local to = #empty > 0 and empty or live
        local each = math.floor(RESUPPLY / #to)
        for _, m in ipairs(to) do m.insert{name = "lp-mortar-shell", count = each} end
        op.loaded = op.loaded + each * #to
        left = left + each * #to
        b.haulers_home = b.haulers_home or {}
        table.insert(b.haulers_home, {unit = op.convoy, till = game.tick + 3 * 3600})
        local h = home(b)
        if h then
          op.convoy.commandable.set_command{type = defines.command.go_to_location, destination = h.position, radius = 12,
            distraction = defines.distraction.none}
        end
        op.convoy = nil
        trace(b, string.format("siege: resupplied, %d shells", each * #to))
      end
    elseif #empty > 0 and in_reach > 0 and (op.convoys_left or 0) > 0 and (op.loaded or 0) + RESUPPLY <= SHELLS_CAP then
      local h = home(b)
      local p = h and s.find_non_colliding_position(shared.variant(b.corp, "lp-hauler"), h.position, 20, 0.5)
      op.convoy = p and s.create_entity{name = shared.variant(b.corp, "lp-hauler"), position = p, force = h.force}
      if op.convoy then
        op.convoys_left = op.convoys_left - 1
        op.convoy.commandable.set_command{type = defines.command.go_to_location, destination = op.site, radius = 2,
          distraction = defines.distraction.none}
        trace(b, "siege: a shell convoy sets out")
      end
    end
    local spec = SIEGE_TIERS[op.tier or 1]
    local t = b.intel.targets[op.target]
    if op.phase == "bombard" then
      -- Moving up (tier 2 and up, once): nothing in reach for ASSAULT_IDLE with shells left, the mortars pack and the
      -- hauler takes them to a site in reach of what still stands (two mortars spent 12 of 80 shells on the near
      -- side of a square and packed up).
      -- A clearance moves on along its way, nest after nest, while its shells last (one clearance per nest, each
      -- home and back, took 40 minutes for seven nests, push); any other siege moves up once.
      if spec.mortars > 1 and (op.clearance or not op.moved) and left > 0 and op.hauler and op.hauler.valid and t
        and game.tick - (op.last_target or op.phase_at) > ASSAULT_IDLE then
        local site
        if op.clearance then
          local nxt = op.clear_for and nest_on_way(s, op.site, op.clear_for)
          site = nxt and clearance_site(s, nxt, op.site, op.piece == "lp-howitzer" and HOWITZER_STAND or nil)
          op.steps = (op.steps or 0) + 1
          if op.steps > 8 then site = nil end
        else
          site = siege_site(b, t)
        end
        op.moved = true
        if site and (site[1] - op.site[1]) ^ 2 + (site[2] - op.site[2]) ^ 2 > 8 * 8 then
          op.carry = {}
          for _, m in ipairs(live) do
            table.insert(op.carry, m.get_inventory(defines.inventory.artillery_turret_ammo).get_item_count("lp-mortar-shell"))
            m.destroy()
          end
          op.mortars, op.mortar, op.site = {}, nil, site
          op.phase, op.phase_at, op.last_target = "march", game.tick, nil
          op.best_d2, op.best_at = nil, nil
          -- Round the worms too (a bare straight move led the march past them, review).
          local hp = op.hauler.position
          local mroute = op.clearance and sneak_route(b, {hp.x, hp.y}, site, {turrets = false, worms = true}) or {}
          local mcmds = {}
          for _, w in ipairs(mroute) do
            table.insert(mcmds, {type = defines.command.go_to_location, destination = w, radius = 3,
              distraction = defines.distraction.none})
          end
          table.insert(mcmds, {type = defines.command.go_to_location, destination = site, radius = 2,
            distraction = defines.distraction.none})
          op.hauler.commandable.set_command{type = defines.command.compound,
            structure_type = defines.compound_command.return_last, commands = mcmds}
          trace(b, string.format("siege: moving up to %.0f,%.0f with %d shells", site[1], site[2], left))
          return
        end
      end
      -- The assault: the barrage over (nothing in reach for ASSAULT_IDLE after the mortars had targets, or the shells
      -- spent with no convoy coming), the guards go in with what the garrison can add, sized to what is left at the
      -- target. Tier 3 and up always; below, only when the guards and the garrison (its reserve too) make the force a raid
      -- there would need (the user, 2026-10-17: "destroys turrets, then nothing happens. The whole group ends up packing
      -- up and leaving home").
      local over = op.last_target and ((in_reach == 0 and game.tick - op.last_target > ASSAULT_IDLE)
        or (left == 0 and not op.convoy))
      local want = over and t and not op.clearance and needed(defence(b, t))
      -- Its reserve too: the barrage paid for and won, the camp commits (with the pool counting the guards out against
      -- the cap, a tier-1 siege's guards and spare came to 21 of the 22 needed, and it went home, bombard).
      local home_n = (function() local f, r = field(b, army) return f + r end)()
      if want and not spec.assault and n + home_n < want and not op.told_short then
        op.told_short = true
        trace(b, string.format("siege: no assault (%d needed, %d guards and %d at home)", want, n, home_n))
      end
      if want and (spec.assault or n + home_n >= want) then
        for _, u in ipairs(pool.take(b, want - #op.members, pool.GUARD, FOOT)) do table.insert(op.members, u) end
        op.launched = #op.members
        op.phase, op.phase_at, op.last_kill, op.kills_at, op.razed_before = "assault", game.tick, game.tick, b.razed, b.razed
        b.assaults = (b.assaults or 0) + 1
        order_all(op.members, {type = defines.command.attack_area, destination = t.pos, radius = 16,
          distraction = defines.distraction.by_anything})
        alert(b, t, "lp.alert-raid")
        trace(b, string.format("siege: the assault goes in with %d units", #op.members))
        return
      end
      local idle = game.tick - (op.last_target or op.phase_at) > 60 * 60
      local waiting = op.convoy ~= nil
      if (left == 0 and not waiting) or idle or n < 0.5 * op.launched then
        op.phase, op.phase_at = "pack", game.tick
        op.packing_because = left == 0 and "spent" or (idle and "done" or "aborted")
        trace(b, string.format("siege: packing up (%s; %d shells fired, %d of %d guards)", op.packing_because,
          op.shells_fired, n, op.launched))
      end
    else
      if b.razed > op.kills_at then op.kills_at, op.last_kill = b.razed, game.tick end
      local remaining = t and s.count_entities_filtered{position = t.pos, radius = 16, type = TYPES, force = foes} or 0
      local done = remaining == 0 or game.tick - op.last_kill > NO_KILL_TICKS
      if done or n < 0.5 * op.launched then
        op.phase, op.phase_at = "pack", game.tick
        op.packing_because = done and "done" or "aborted"
        b.assault_razed = (b.assault_razed or 0) + b.razed - op.razed_before
        trace(b, string.format("siege: the assault ends (%s; %d of %d left, %d left standing at the target)",
          op.packing_because, n, op.launched, remaining))
        return
      end
      for _, u in ipairs(op.members) do
        if u.valid and not u.commandable.has_command and t then
          u.commandable.set_command{type = defines.command.attack_area, destination = t.pos, radius = 16,
            distraction = defines.distraction.by_anything}
        end
      end
    end
  elseif op.phase == "pack" then
    if game.tick - op.phase_at >= PACK_TICKS then return finish(b, op.packing_because, trace, army) end
  end
end

-- A camp site: ore within 45 tiles of a player's drill, 15 or more from it, beyond every player turret's reach
-- and clear of the player's buildings.
local function strip_site(b, t)
  local s = game.surfaces[b.surface]
  local foes = enemies(game.forces[b.force])
  -- Prospector's eye (Grubstake) looks half as far again for ore by the player's drills.
  local reach = rd.has(b.corp, "prospector") and 68 or 45
  for _, r in pairs(s.find_entities_filtered{position = t.pos, radius = reach, type = "resource", limit = 900}) do
    if r.prototype.resource_category == "basic-solid" then
      local p = r.position
      local d2 = (p.x - t.pos[1]) ^ 2 + (p.y - t.pos[2]) ^ 2
      if d2 >= 15 * 15 and s.count_entities_filtered{position = p, radius = PLAYER_REACH, type = TURRETS, force = foes} == 0
        and s.count_entities_filtered{position = p, radius = 10, force = foes, limit = 1} == 0
        and s.count_entities_filtered{position = p, radius = 6, type = "resource"} >= 25 then
        return {p.x, p.y}
      end
    end
  end
end

local function choose_strip(b, army)
  local temper = shared.CORPS[b.corp].temper or {}
  if not temper.strips or (b.parts or 0) < STRIP_COST or game.tick < (b.next_strip or 0) then return end
  if field(b, army) < STRIP_GUARDS then return end
  local h = home(b)
  local in_flight = ops.player_ops()
  local best, bd, site
  for key, t in pairs(b.intel.targets) do
    -- Any outpost with a camp site beyond turret reach (strip_site checks it): requiring an undefended drill as
    -- well left a careful player's outposts, each with two lasers, never stripped.
    if t.value == ops.VALUE["mining-drill"] and against_player(t.owner) and in_flight < budget(t.owner)
      and not ops.marked(b, t.pos) and stance.may(b.corp, t.owner, "strip") then
      local d = (t.pos[1] - h.position.x) ^ 2 + (t.pos[2] - h.position.y) ^ 2
      if not bd or d < bd then
        local p = strip_site(b, t)
        -- A patch it already holds (a camp kept there) is not stripped again.
        local held = p and (b.claims or {})[math.floor(p[1] / 64) .. "," .. math.floor(p[2] / 64)] or 0
        if p and held < 2 then best, bd, site = key, d, p end
      end
    end
  end
  return best, site
end

local function launch_strip(b, key, site, trace, army)
  local t = b.intel.targets[key]
  local h = home(b)
  local s = game.surfaces[b.surface]
  local p = s.find_non_colliding_position(shared.variant(b.corp, "lp-hauler"), {h.position.x + (site[1] - h.position.x) * 0.1,
    h.position.y + (site[2] - h.position.y) * 0.1}, 20, 0.5)
  local hauler = p and s.create_entity{name = shared.variant(b.corp, "lp-hauler"), position = p, force = h.force}
  if not hauler then return false end
  local guards = pool.take(b, STRIP_GUARDS, floor_of(b, army), function(u) return u.type == "unit" end)
  b.parts = b.parts - STRIP_COST
  b.op = {kind = "strip", target = key, phase = "march", members = guards, launched = #guards, hauler = hauler,
    site = site, started = game.tick, phase_at = game.tick, cargo = 0}
  -- Round biter country (the hauler is slow and alone: through a nest field it never arrived).
  local hroute = sneak_route(b, {hauler.position.x, hauler.position.y}, site,
    {turrets = false, nests = (b.intel.targets[key] or {}).owner ~= "enemy"})
  if not hroute and b.intel.targets[key] and push_escort(b, b.intel.targets[key], {hauler.position.x, hauler.position.y}, site) then
    hroute = {}
    b.op.pushed = true
    trace(b, string.format("hauler pushes through biter country to %.0f,%.0f", site[1], site[2]))
  end
  if not hroute then
    for _, u in ipairs(guards) do table.insert(b.garrison, u) end
    b.op = nil
    b.parts = b.parts + STRIP_COST
    hauler.destroy()
    local tt = b.intel.targets[key]
    if tt then tt.cool = game.tick + COOL_TICKS end
    trace(b, string.format("%s to %.0f,%.0f: no way round biter country; not sent", "strip camp", site[1], site[2]))
    b.next_strip = game.tick + 2 * 3600
    b.next_op = game.tick + 2 * 3600
    return false
  end
  local hcmds = {}
  for _, w in ipairs(hroute) do
    table.insert(hcmds, {type = defines.command.go_to_location, destination = w, radius = 4,
      distraction = defines.distraction.none})
  end
  table.insert(hcmds, {type = defines.command.go_to_location, destination = site, radius = 2,
    distraction = defines.distraction.none})
  hauler.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
    commands = hcmds}
  order_all(guards, {type = defines.command.go_to_location, destination = hauler.position, radius = 6,
    distraction = defines.distraction.by_enemy})
  b.ops_launched = b.ops_launched + 1
  b.strips = (b.strips or 0) + 1
  storage.threat_last = game.tick
  trace(b, string.format("strip-mining beside %s at %.0f,%.0f: a camp to %.0f,%.0f, %d guards", t.kind, t.pos[1],
    t.pos[2], site[1], site[2], #guards))
  return true
end

local function strip_step(b, trace, army)
  local op = b.op
  local n = alive(op)
  if game.tick - op.started > STRIP_TICKS + 8 * 3600 then return finish(b, "aborted", trace, army) end
  if (op.phase == "march" or op.phase == "deploy") and not op.hauler.valid then
    trace(b, "strip-mining: the hauler was destroyed on the way")
    return finish(b, "intercepted", trace, army)
  end
  local s = game.surfaces[b.surface]
  if op.phase == "march" then
    local hp = op.hauler.position
    if not op.hauler.commandable.has_command then
      op.hauler.commandable.set_command{type = defines.command.go_to_location, destination = op.site, radius = 2,
        distraction = defines.distraction.none}
    end
    order_all(op.members, {type = defines.command.go_to_location, destination = hp, radius = 6,
      distraction = defines.distraction.by_enemy})
    if (hp.x - op.site[1]) ^ 2 + (hp.y - op.site[2]) ^ 2 < 6 * 6 then
      op.phase, op.phase_at = "deploy", game.tick
      op.hauler.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none}
      order_all(op.members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = {{type = defines.command.go_to_location, destination = op.site, radius = 8,
          distraction = defines.distraction.by_damage},
          {type = defines.command.wander, radius = 8, distraction = defines.distraction.by_damage}}})
    end
  elseif op.phase == "deploy" then
    if game.tick - op.phase_at >= 20 * 60 then
      local f = game.forces[b.force]
      local function put(kind, x, y)
        local name = shared.variant(b.corp, kind)
        local p = s.find_non_colliding_position(name, {op.site[1] + x, op.site[2] + y}, 6, 0.5)
        return p and s.create_entity{name = name, position = p, force = f}
      end
      op.camp = {}
      local pylon = put("lp-pylon", 0, 0)
      table.insert(op.camp, pylon)
      table.insert(op.camp, put("lp-generator", -5, 0))
      op.bins = {}
      for k = 1, STRIP_DRILLS do
        local dx = (k - 2) * 4
        local pos = s.find_non_colliding_position(shared.variant(b.corp, "lp-drill"), {op.site[1] + dx, op.site[2] + 4}, 6, 1)
        local drill = pos and s.create_entity{name = shared.variant(b.corp, "lp-drill"), position = pos, force = f,
          direction = defines.direction.south}
        if drill then
          table.insert(op.camp, drill)
          local bin = s.create_entity{name = shared.variant(b.corp, "lp-bin"), position = drill.drop_position, force = f}
          if bin then table.insert(op.camp, bin); table.insert(op.bins, bin) end
        end
      end
      op.drills = 0
      for _, e in ipairs(op.camp) do if e and e.valid and e.type == "mining-drill" then op.drills = op.drills + 1 end end
      op.phase, op.phase_at = "mine", game.tick
      alert(b, b.intel.targets[op.target], "lp.alert-strip", op.site)
      trace(b, string.format("strip-mining: camp up at %.0f,%.0f with %d bins", op.site[1], op.site[2], #op.bins))
    end
  elseif op.phase == "mine" then
    local working = 0
    for _, e in ipairs(op.camp) do if e and e.valid and e.type == "mining-drill" then working = working + 1 end end
    local done = game.tick - op.phase_at >= (storage.strip_fast and 3 * 3600 or STRIP_TICKS)
    -- Unanswered (every drill standing, nobody lost): the patch is claimed; the second time, the camp stays as a
    -- Grubstake outpost on the player's ore (late pressure: ignoring two camps leaves a patch to assault).
    if done and working == (op.drills or working) and n >= op.launched then
      b.claims = b.claims or {}
      -- By patch (64-tile squares round the camp), not by target cell: the next camp may aim at another drill.
      local patch = math.floor(op.site[1] / 64) .. "," .. math.floor(op.site[2] / 64)
      local times = (b.claims[patch] or 0) + 1
      b.claims[patch] = times
      notify(b, times >= 2 and "lp.claim-outpost" or "lp.claim", op.site)
      if times >= 2 and ops.settle then
        ops.settle(b, op.site, op.camp)
        op.camp = nil
        trace(b, string.format("strip-mining: the camp at %.0f,%.0f stays as an outpost", op.site[1], op.site[2]))
        return finish(b, "claimed", trace, army)
      end
    end
    if working == 0 or n < 0.5 * op.launched or done then
      local cargo = 0
      for _, bin in ipairs(op.bins or {}) do if bin.valid then cargo = cargo + bin.get_inventory(defines.inventory.chest).get_item_count() end end
      op.cargo = cargo
      op.packing_because = done and "done" or "aborted"
      op.phase, op.phase_at = "pack", game.tick
      trace(b, string.format("strip-mining: packing up with %d ore (%s)", cargo, op.packing_because))
    end
  elseif op.phase == "pack" then
    if game.tick - op.phase_at >= 10 * 60 then return finish(b, op.packing_because, trace, army) end
  end
end

local function step(b, trace, army)
  local op = b.op
  if op.kind == "siege" then return siege_step(b, trace, army) end
  if op.kind == "strip" then return strip_step(b, trace, army) end
  local t = b.intel.targets[op.target]
  local n = alive(op)
  if n == 0 then return finish(b, "aborted", trace, army) end
  if game.tick - op.started > MAX_TICKS then return finish(b, "aborted", trace, army) end
  if op.phase == "stage" then
    local near = 0
    for _, u in ipairs(op.members) do
      if u.valid and (u.position.x - op.staging[1]) ^ 2 + (u.position.y - op.staging[2]) ^ 2 < 15 * 15 then
        near = near + 1
      end
    end
    -- Past its time and still closing in: it waits (up to three times its time). Stalled far off: called off, not sent
    -- in piecemeal (Serenity's raids went in with raiders still 181 tiles off, walking the engine's way round lakes and
    -- nests, and razed nothing, visit nw).
    local over = game.tick - op.phase_at > (op.stage_ticks or STAGE_TICKS)
    if over and near < 0.8 * n then
      local sum, k = 0, 0
      for _, u in ipairs(op.members) do
        if u.valid then
          sum = sum + math.sqrt((u.position.x - op.staging[1]) ^ 2 + (u.position.y - op.staging[2]) ^ 2); k = k + 1
        end
      end
      local mean = k > 0 and sum / k or 0
      local closing = op.stage_dist and mean < op.stage_dist - 5
      op.stage_dist = mean
      if mean > 40 then
        if closing and game.tick - op.phase_at < 3 * (op.stage_ticks or STAGE_TICKS) then return end
        -- No longer closing: it goes in from where it is, as it always did (called off at 60 tiles while fighting on the
        -- way, Serenity's raids razed a third of what they had on deathworld); only one stuck far off (walled in, lost
        -- round a lake) is called off.
        if not closing and op.stage_waited and mean > 150 then
          local cx, cy, m = 0, 0, 0
          for _, u in ipairs(op.members) do if u.valid then cx, cy, m = cx + u.position.x, cy + u.position.y, m + 1 end end
          cx, cy = cx / math.max(1, m), cy / math.max(1, m)
          local own = wall_on_line and game.surfaces[b.surface].count_entities_filtered{area = {{math.min(cx, op.staging[1]),
            math.min(cy, op.staging[2])}, {math.max(cx, op.staging[1]), math.max(cy, op.staging[2])}}, force = b.force,
            type = {"wall", "gate"}} or -1
          trace(b, string.format("raid never reached its staging point (its raiders %.0f off on average, about %.0f,%.0f; %d "
            .. "of its own wall pieces between): called off", mean, cx, cy, own))
          return finish(b, "aborted", trace, army)
        end
        local first = not op.stage_waited
        op.stage_waited = true
        if first and not closing then return end
      end
    end
    if near >= 0.8 * n or over then
      -- A look from the staging point first: more turrets than the force can take, and it turns back before
      -- a shot is fired (four raiders sent at a target armed after they left all died attacking it).
      if t then
        local s = game.surfaces[b.surface]
        local foes = enemies(game.forces[b.force])
        local seen, dmg = ops.weigh(s, t.pos, foes)
        t.dmg = dmg or t.dmg
        -- What it sees now is the freshest word (a raid that had cleared the target on its way turned back
        -- on the defence it believed before); who stands there counts too, for a while.
        t.defence = seen
        t.units, t.units_at = mobile(s, t.pos, foes), game.tick
        local want = needed((t.defence + (t.resist or 0) + t.units) / rd.strength(b.corp, t.dmg))
        if want > n and not (t.owner and against_player(t.owner) and ladder(t.owner, b.force) >= 3) then
          rd.turned_back(b)
          trace(b, string.format("raid sees defence %.1f and units %.1f at the target, needs %d, has %d: turns back", seen,
            t.units, want, n))
          return finish(b, "aborted", trace, army)
        end
      end
      op.phase, op.phase_at, op.last_kill = "attack", game.tick, game.tick
      op.attacked = true
      alert(b, t, "lp.alert-raid")
      -- The aim is fixed as it goes in: the target's record follows the newest building seen in its cell, and a raid's
      -- point moved 16 tiles off the pole it had hit, where it found nothing and gave up (the user's save, 2026-10-17).
      op.pos = t and {t.pos[1], t.pos[2]} or nil
      local pos = op.pos or op.staging
      if t and (shared.CORPS[b.corp].temper or {}).sneaks and not storage.sneak_off and against_player(t.owner) then
        local pieces, cover = breach_point(b, t, op.staging)
        op.route = sneak_route(b, op.staging, pieces and {pieces[1].position.x, pieces[1].position.y} or pos) or {}
        local cmds = {}
        for _, w in ipairs(op.route) do
          table.insert(cmds, {type = defines.command.go_to_location, destination = w, radius = 4,
            distraction = defines.distraction.by_damage})
        end
        if pieces then
          op.breach = pieces
          op.breach_at = {pieces[1].position.x, pieces[1].position.y}
          op.phase = "breach"
          table.insert(cmds, {type = defines.command.attack, target = pieces[1], distraction = defines.distraction.by_damage})
          trace(b, string.format("raid sneaks in by %d waypoints to breach the wall at %.0f,%.0f (%d turrets reach it)",
            #op.route, op.breach_at[1], op.breach_at[2], cover))
        else
          table.insert(cmds, {type = defines.command.attack_area, destination = pos, radius = 12,
            distraction = defines.distraction.by_anything})
          trace(b, string.format("raid sneaks in by %d waypoints with %d of %d", #op.route, n, op.launched))
        end
        order_all(op.members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
          commands = cmds})
      else
        -- The attack leg round biter country too (staged short of a nest field, four raiders went straight through
        -- it and died, country); a nest as the target excepted.
        local cmds = {}
        for _, w in ipairs((t and t.owner ~= "enemy" and sneak_route(b, op.staging, pos, {turrets = false, nests = true})) or {}) do
          table.insert(cmds, {type = defines.command.go_to_location, destination = w, radius = 4,
            distraction = defines.distraction.by_enemy})
        end
        -- A wall across the way: straight at it, through it, then in (the breach phase).
        local last = #cmds > 0 and cmds[#cmds].destination or op.staging
        local pieces = t and t.owner ~= "enemy" and wall_on_line(b, last, pos)
        if pieces then
          op.breach = pieces
          op.breach_at = {pieces[1].position.x, pieces[1].position.y}
          op.phase = "breach"
          table.insert(cmds, {type = defines.command.attack, target = pieces[1], distraction = defines.distraction.by_enemy})
          order_all(op.members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
            commands = cmds})
          trace(b, string.format("raid goes straight at the wall at %.0f,%.0f with %d of %d", op.breach_at[1],
            op.breach_at[2], n, op.launched))
        else
          table.insert(cmds, {type = defines.command.attack_area, destination = pos, radius = 12,
            distraction = defines.distraction.by_anything})
          order_all(op.members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
            commands = cmds})
          local far = 0
          for _, u in ipairs(op.members) do
            if u.valid then far = math.max(far, math.sqrt((u.position.x - op.staging[1]) ^ 2 + (u.position.y - op.staging[2]) ^ 2)) end
          end
          trace(b, string.format("raid attacks with %d of %d (%d waypoints; the furthest raider %.0f from staging)", n,
            op.launched, #cmds - 1, far))
        end
      end
    end
  elseif op.phase == "breach" then
    -- Through the gap once its pieces are down; given up (and in) after STAGE_TICKS at the wall.
    local standing, fell
    for _, w in ipairs(op.breach or {}) do if w.valid then standing = w else fell = true end end
    -- A piece that fell is the breach, even if the player's robots put it back before this step looked (5 s later, it
    -- never saw the gap): through it now.
    if fell then standing = nil end
    -- A wall the player's robots put back is breached again (one rebuilt in 5 s left the breach order done and the
    -- raiders wandering by it for 3 minutes, the user's save).
    if not standing and not fell and op.breach_at then
      local again = game.surfaces[b.surface].find_entities_filtered{position = op.breach_at, radius = 2.5,
        type = {"wall", "gate"}, force = enemies(game.forces[b.force])}
      if #again > 0 then op.breach, standing = again, again[1] end
    end
    local pos = op.pos or (t and t.pos) or op.staging
    if n < 0.5 * op.launched then return finish(b, "aborted", trace, army) end
    if not standing or game.tick - op.phase_at > 2 * STAGE_TICKS then
      op.phase, op.phase_at, op.last_kill = "attack", game.tick, game.tick
      op.breached = not standing
      -- Through the gap and at the nearest building: told to attack the area, inside the wall they took the wall itself,
      -- piece after piece from within, and the robots put each back (mended serenity).
      local inside = game.surfaces[b.surface].find_entities_filtered{position = pos, radius = 16, type = TYPES,
        force = enemies(game.forces[b.force])}
      local e = #inside > 0 and game.surfaces[b.surface].get_closest(op.breach_at, inside)
      order_all(op.members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = {{type = defines.command.go_to_location, destination = op.breach_at, radius = 3,
          distraction = defines.distraction.by_damage},
          e and {type = defines.command.attack, target = e, distraction = defines.distraction.by_damage}
            or {type = defines.command.attack_area, destination = pos, radius = 12, distraction = defines.distraction.by_anything}}})
      trace(b, string.format("raid %s the wall at %.0f,%.0f and goes in with %d of %d",
        standing and "gave up on" or "breached", op.breach_at[1], op.breach_at[2], n, op.launched))
    else
      -- Each raider on a piece still standing: idle, wandering or its piece gone, it is told again.
      for _, u in ipairs(op.members) do
        if u.valid and not busy(u) then
          u.commandable.set_command{type = defines.command.attack, target = standing, distraction = defines.distraction.by_damage}
        end
      end
    end
  elseif op.phase == "attack" then
    if b.razed > op.kills_at then op.kills_at, op.last_kill = b.razed, game.tick end
    local pos = op.pos or (t and t.pos) or op.staging
    local surface = game.surfaces[b.surface]
    local turrets, left
    if t and t.owner == "enemy" then
      -- A nest: its spawners, and the worms by them.
      turrets = surface.count_entities_filtered{position = pos, radius = DEFENCE_RADIUS, force = "enemy", type = "turret"}
      left = surface.count_entities_filtered{position = pos, radius = 16, force = "enemy", type = "unit-spawner"}
    else
      turrets = surface.count_entities_filtered{position = pos, radius = DEFENCE_RADIUS, type = TURRETS,
        force = enemies(game.forces[b.force])}
      left = surface.count_entities_filtered{position = pos, radius = 16, type = TYPES,
        force = enemies(game.forces[b.force])}
    end
    -- Prospector's eye (Grubstake): cowardice as doctrine, it leaves at 70% strength.
    local share = rd.has(b.corp, "prospector") and 0.7 or 0.5
    if n < share * op.launched and turrets > 0 then return finish(b, "aborted", trace, army) end
    loot(b, op, t, pos, surface, trace)
    -- The breach walled up again behind them before they were through, and nothing has fallen since: back at it (the
    -- player's robots put a piece back in 5 s, and Serenity's raiders stood at the rebuilt wall until the raid gave up,
    -- mended serenity).
    local got_in = false
    for _, u in ipairs(op.members) do
      if u.valid and (u.position.x - pos[1]) ^ 2 + (u.position.y - pos[2]) ^ 2 < 10 * 10 then got_in = true end
    end
    if op.breach_at and not got_in and game.tick - op.last_kill > 20 * 60 then
      local again = surface.find_entities_filtered{position = op.breach_at, radius = 2.5, type = {"wall", "gate"},
        force = enemies(game.forces[b.force])}
      if #again > 0 then
        op.breach, op.phase, op.phase_at = again, "breach", game.tick
        op.rebreached = (op.rebreached or 0) + 1
        for _, u in ipairs(op.members) do
          if u.valid then
            u.commandable.set_command{type = defines.command.attack, target = again[1], distraction = defines.distraction.by_damage}
          end
        end
        local near, inside = 1e9, 0
        for _, u in ipairs(op.members) do
          if u.valid then
            local d = math.sqrt((u.position.x - pos[1]) ^ 2 + (u.position.y - pos[2]) ^ 2)
            near = math.min(near, d)
            if d < 10 then inside = inside + 1 end
          end
        end
        trace(b, string.format("raid: the breach at %.0f,%.0f walled up again; at it again (nearest raider %.0f from the "
          .. "target, %d within 10)", op.breach_at[1], op.breach_at[2], near, inside))
        return
      end
    end
    if game.tick - op.last_kill > NO_KILL_TICKS then return finish(b, "aborted", trace, army) end
    if left == 0 then
      trace(b, string.format("raid finds nothing left within 16 of %.0f,%.0f (%d turrets within %d)", pos[1], pos[2],
        turrets, DEFENCE_RADIUS))
      return finish(b, "done", trace, army)
    end
    -- Raiders done with their order (idle, wandering, their target gone) are each set on a building within 16 of the
    -- point, the nearest: told to attack the area again, they found nothing there they would attack and stood idle
    -- until the raid gave up (the user's save).
    local ents
    for _, u in ipairs(op.members) do
      if u.valid and not busy(u) then
        ents = ents or surface.find_entities_filtered{position = pos, radius = 16, type = TYPES,
          force = enemies(game.forces[b.force])}
        local e = #ents > 0 and surface.get_closest(u.position, ents)
        u.commandable.set_command(e and {type = defines.command.attack, target = e, distraction = defines.distraction.by_damage}
          or {type = defines.command.attack_area, destination = pos, radius = 12, distraction = defines.distraction.by_anything})
      end
    end
  end
end

local function stand_down(b)
  for i = #(b.haulers_home or {}), 1, -1 do
    local r = b.haulers_home[i]
    local h = home(b)
    if not r.unit.valid then
      table.remove(b.haulers_home, i)
    elseif game.tick >= r.till or (h and (r.unit.position.x - h.position.x) ^ 2 + (r.unit.position.y - h.position.y) ^ 2 < 15 * 15) then
      -- Home: what it carries becomes the settlement's feedstock (stripped ore).
      if r.cargo and r.cargo > 0 then
        b.feedstock = b.feedstock + r.cargo
        b.mined = b.mined + r.cargo
        b.stripped = (b.stripped or 0) + r.cargo
      end
      r.unit.destroy()
      table.remove(b.haulers_home, i)
    end
  end
end

-- The siege leash (review of scenario clear): a clearance's guard more than its ring and a margin from the site is
-- called back, every second (between siege steps, 300 ticks, a railgunner walks 30 tiles: into a worm's reach).
local function siege_leash(b)
  local op = b.op
  if not (op and op.kind == "siege" and op.clearance and op.phase ~= "march") then return end
  local r = (op.piece == "lp-howitzer" and GUARD_RADIUS / 2 or GUARD_RADIUS) + 6
  for _, u in ipairs(op.members) do
    if u.valid and (u.position.x - op.site[1]) ^ 2 + (u.position.y - op.site[2]) ^ 2 > r * r then
      u.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = {{type = defines.command.go_to_location, destination = op.site, radius = 6,
          distraction = defines.distraction.none},
          {type = defines.command.wander, radius = 5, distraction = defines.distraction.by_damage}}}
    end
  end
end
-- Turrets of the owner's that cover a spot (a gun turret's 18, and a margin).
local ANSWER_COVER = 24
local function covered(s, owner, pos)
  return s.count_entities_filtered{position = pos, radius = ANSWER_COVER, force = owner,
    type = {"ammo-turret", "electric-turret", "fluid-turret"}, limit = 1} > 0
end
-- A second provocation this soon after an answer: Serenity's raid it would lose becomes a siege.
local ANSWER_AGAIN = 30 * 3600

-- The answer, by the corporation's reaction table (temper.answers) and the kind of provocation:
--   flare   Grubstake: biters on the culprit (flare.answer); where no turret covers it, a snatch raid instead
--   raid    a raid on the player's building nearest the spot; one it would lose: a siege if provoked again within
--           ANSWER_AGAIN, else nothing yet
--   siege   mortars on the nearest of the player's turrets there (or what is there); none possible: the raid
local function answer(b, trace, army)
  local a = b.answer
  b.answer = nil
  if not stance.may(b.corp, a.owner, "answer") then return end
  local how = ((shared.CORPS[b.corp].temper or {}).answers or {})[a.kind or "loss"] or "raid"
  local s = game.surfaces[b.surface]
  sense(b, s, {x = a.pos[1], y = a.pos[2]}, 30)
  local key, bd
  for k, t in pairs(b.intel.targets) do
    if t.owner == a.owner then
      local d = (t.pos[1] - a.pos[1]) ^ 2 + (t.pos[2] - a.pos[2]) ^ 2
      if d <= 40 * 40 and (not bd or d < bd) then key, bd = k, d end
    end
  end
  b.next_answer = game.tick + tune.sooner(b.corp, ANSWER_COOLDOWN)
  if not key then
    trace(b, string.format("answer: nothing of %s's to hit near %.0f,%.0f", a.owner, a.pos[1], a.pos[2]))
    return
  end
  local t = b.intel.targets[key]
  t.cool = 0
  local said = string.format("answer (%s, %s): provoked by %s at %.0f,%.0f, %ds ago: ", a.kind or "loss", how, a.owner,
    a.pos[1], a.pos[2], math.floor((game.tick - a.tick) / 60))
  local function done(what)
    b.answers = (b.answers or 0) + 1
    b.answered = b.answered or {}
    b.answered[what] = (b.answered[what] or 0) + 1
    b.last_answer = game.tick
    trace(b, said .. what)
    return true
  end
  local function siege()
    -- An answer is self-defence, as the counter-battery is: a corporation that sieges at all may answer with one before
    -- its level brings them (Serenity at level 0 sent nothing at a laser wall for three hours, visit nw).
    if not (shared.capable(b.corp, "siege", 99) or b.grudge) or not stance.may(b.corp, a.owner, "siege") then
      trace(b, said .. string.format("no siege (capable %s, may %s)", tostring(shared.capable(b.corp, "siege", army.level(b))),
        tostring(stance.may(b.corp, a.owner, "siege"))))
      return false
    end
    -- At the turret nearest the spot: the siege's target is a turret of its (siege_site).
    local tkey, td
    for k, x in pairs(b.intel.targets) do
      if x.owner == a.owner and prototypes.entity[x.kind] and prototypes.entity[x.kind].type:find("turret") then
        local d = (x.pos[1] - a.pos[1]) ^ 2 + (x.pos[2] - a.pos[2]) ^ 2
        if d <= 40 * 40 and (not td or d < td) then tkey, td = k, d end
      end
    end
    local site = tkey and siege_site(b, b.intel.targets[tkey])
    if not site then
      trace(b, said .. (tkey and "no siege (no mortar site)" or "no siege (no turret of theirs known there)"))
      return false
    end
    if launch_siege(b, tkey, site, trace, army) then return done("a siege") end
    trace(b, said .. "no siege (could not launch)")
    return false
  end
  local function raid() return launch(b, key, trace, army, {answer = true}) and done("a squad goes") or false end
  if how == "flare" then
    if not covered(s, a.owner, t.pos) and raid() then return end
    local why = ops.answer_flare and ops.answer_flare(b, t.pos, a.owner) or "no flares"
    if why == "launched" then return done("a flare on it") end
    trace(b, said .. "no flare (" .. why .. ")")
    return
  end
  if how == "siege" and siege() then return end
  -- A raid it can win (the defence there, against all it could send), else a siege when provoked again soon.
  local n, reserve = field(b, army)
  if needed(defence(b, t)) <= n + reserve then
    if raid() then return end
  elseif how ~= "siege" and b.last_answer and game.tick - b.last_answer < ANSWER_AGAIN and siege() then
    return
  elseif how ~= "siege" then
    b.last_answer = game.tick
    trace(b, said .. string.format("too strong for a raid (%d needed, %d to send); remembered", needed(defence(b, t)),
      n + reserve))
    return
  end
  trace(b, said .. "nothing to send")
end

function ops.tick(b, tick, trace, army)
  if storage.ops_off then return end
  ops.init(b)
  if tick % 60 == 30 then siege_leash(b) end
  if tick % 600 == 300 then stand_down(b) end
  if tick % SENSE_TICKS == (b.id * 97) % SENSE_TICKS then scan(b) end
  if tick % 3600 == (b.id * 53) % 3600 then ops.perimeter(b, tick) end
  if tick % 600 == 200 then field_sight(b) end
  if tick % SURVEY_TICKS == (b.id * 131 + 7) % SURVEY_TICKS then survey(b) end
  -- An answer goes before anything the decider would choose, and does not wait on its clock (b.next_op).
  if not b.op and b.answer and tick % 300 == 150 and not storage.raids_off and not storage.army_off
    and not army.withdrawing(b) and home(b) then
    return answer(b, trace, army)
  end
  if b.op then
    if tick % 300 == 100 then step(b, trace, army) end
  elseif tick % DECIDE_TICKS == 0 and tick >= (b.next_op or 0) and not storage.raids_off and not storage.army_off
    and not storage.choice_off
    and not army.withdrawing(b) then
    if not home(b) then return end
    -- Counter-battery first: a battery it knows is besieged before anything else (a raid on a substation was
    -- always available, so the siege was never considered); one that never besieges raids it (choose weighs
    -- it by its value and threat).
    local bkey, bsite = choose_siege(b, army, true)
    if bkey then return launch_siege(b, bkey, bsite, trace, army) end
    local key = choose(b, army)
    if key and battery(b.intel.targets[key]) then return launch(b, key, trace, army) end
    -- A thief strips first: a raid was always available before and the camp never went up.
    if (shared.CORPS[b.corp].temper or {}).strips then
      local tkey, tsite = choose_strip(b, army)
      if tkey then return launch_strip(b, tkey, tsite, trace, army) end
    end
    if key then
      launch(b, key, trace, army)
    else
      local skey, site = choose_siege(b, army)
      if skey then
        launch_siege(b, skey, site, trace, army)
      else
        local tkey, tsite = choose_strip(b, army)
        if tkey then launch_strip(b, tkey, tsite, trace, army) end
      end
    end
  end
end

-- Tests: the force a raid would need for the target nearest pos (sensed now), and that target's weighted defence.
function ops.debug_needed(b, pos)
  ops.init(b)
  sense(b, game.surfaces[b.surface], pos, 40)
  local best, bd
  for _, t in pairs(b.intel.targets) do
    local d = (t.pos[1] - pos.x) ^ 2 + (t.pos[2] - pos.y) ^ 2
    if not bd or d < bd then best, bd = t, d end
  end
  return best and {needed = needed(defence(b, best)), defence = best.defence, kind = best.kind}
end

-- Dev tools (/lp, scripts/dev.lua): an operation of this kind now, at the player structure nearest pos, whatever
-- the settlement's temper, budget, cadence and stock. Parts and the infantry it lacks are given at its depot.
-- Returns nil when launched, else why not (shown to the player).
function ops.force(b, kind, pos, trace, army)
  ops.init(b)
  if b.op then return "busy with a " .. b.op.kind end
  local h = home(b)
  if not h then return "no depot" end
  local s = game.surfaces[b.surface]
  sense(b, s, pos, 60)
  local best, bd
  for key, t in pairs(b.intel.targets) do
    if against_player(t.owner) and (kind ~= "strip" or t.value == ops.VALUE["mining-drill"]) then
      local d = (t.pos[1] - pos.x) ^ 2 + (t.pos[2] - pos.y) ^ 2
      if d <= 60 * 60 and (not bd or d < bd) then best, bd = key, d end
    end
  end
  if not best then
    return kind == "strip" and "no drill of yours within 60 tiles" or "no structure of yours within 60 tiles"
  end
  local t = b.intel.targets[best]
  t.cool, b.next_op = 0, 0
  local site
  if kind == "siege" then
    site = siege_site(b, t)
    if not site then return "no mortar site: it needs a turret of yours and ground beyond every turret's reach" end
  elseif kind == "strip" then
    site = strip_site(b, t)
    if not site then return "no camp site: ore 15-45 tiles from the drill, beyond your turrets' reach" end
  end
  b.parts = math.max(b.parts or 0, SIEGE_COST)
  local want = (kind == "raid" and needed(defence(b, t)) or SIEGE_GUARDS) + math.ceil(RESERVE * cap(b, army))
  local n = 0
  for _, u in ipairs(b.garrison) do if u.valid and u.type == "unit" and shared.kind_of(u.name) ~= "lp-hauler" then n = n + 1 end end
  local proto = shared.variant(b.corp, "lp-infantry")
  for _ = n + 1, want do
    local p = s.find_non_colliding_position(proto, {h.position.x, h.position.y + 4}, 20, 0.5)
    local u = p and s.create_entity{name = proto, position = p, force = h.force}
    if u then
      table.insert(b.garrison, u)
      pool.enlist(b, u)
    end
  end
  local ok
  if kind == "raid" then
    -- Its reserve goes too: a forced raid is sized to the target, not to what the settlement can spare.
    ok = launch(b, best, trace, army)
  elseif kind == "siege" then
    ok = launch_siege(b, best, site, trace, army)
  else
    ok = launch_strip(b, best, site, trace, army)
  end
  if not ok then return "launch failed (no room for a hauler, or too few units)" end
end

-- For stats: what the settlement knows and is doing.
function ops.summary(b)
  local n, np = 0, 0
  for _, t in pairs(b.intel and b.intel.targets or {}) do
    n = n + 1
    if against_player(t.owner) then np = np + 1 end
  end
  local t = b.op and b.intel.targets[b.op.target]
  -- What it knows of the players' (for the visits): kind, exposure, defence, rest left, whether its temper allows it.
  local pt = {}
  for _, o in pairs(b.intel and b.intel.targets or {}) do
    if against_player(o.owner) and #pt < 12 then
      table.insert(pt, string.format("%s@%.0f,%.0f e%.1f d%.1f r%.0f%s%s", o.kind, o.pos[1], o.pos[2], o.exposure or -1,
        o.defence or -1, o.resist or 0, game.tick < (o.cool or 0) and " cool" or "", temper_allows(b, o) and "" or " held"))
    end
  end
  return {known = n, known_player = np, player_targets = pt, ladder = (function()
    for _, f in ipairs(shared.player_forces()) do return ladder(f.name, b.force) end end)(), op = b.op and (b.op.kind .. ":" .. b.op.phase) or nil, target = t and t.kind or nil,
    launched = b.ops_launched or 0, done = b.ops_done or 0, aborted = b.ops_aborted or 0, log = b.ops_log or {},
    siege_tier = b.op and b.op.tier, answers = b.answers or 0, answered = b.answered, assaults = b.assaults or 0, assault_razed = b.assault_razed or 0,
    convoys_left = b.op and b.op.convoys_left, loaded = b.op and b.op.loaded, mortars = b.op and b.op.mortars and #b.op.mortars or 0,
    shells_fired = b.op and b.op.shells_fired, siege_phase = b.op and b.op.kind == "siege" and b.op.phase or nil,
    looted = b.looted or 0, works = b.op and b.op.works and #b.op.works or 0, clearances = b.clearances or 0,
    overflights = b.overflights or 0,
    route = b.op and b.op.route and #b.op.route or nil, breach_at = b.op and b.op.breach_at, route_points = b.op_route,
    breached = b.op and b.op.breached,
    sieges = b.sieges or 0, strips = b.strips or 0, stripped = b.stripped or 0, mortar = b.op and b.op.mortar and b.op.mortar.valid and
      {b.op.mortar.position.x, b.op.mortar.position.y} or nil}
end

return ops
