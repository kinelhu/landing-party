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
local rd = require("__landing-party__.scripts.rd")

local ops = {}

local CELL = 32
local SENSE_TICKS = 2 * 3600          -- a full scan of the static sensors
-- The lander sees as far as the player's artillery reaches: a battery is seen when it is built, not when it fires.
local SENSORS = {["lp-lander"] = 300, ["lp-depot"] = 150, ["lp-radar"] = 250}
local FIELD_SIGHT = 40                -- what a unit away from home sees
local DEFENCE_RADIUS = 30             -- turrets this close to a target defend it
local MARKER_TICKS = 20 * 60 * 60     -- a death marker counts this long
local DECIDE_TICKS = 30 * 60
local RESERVE = 0.3                   -- share of the garrison cap that never leaves on an operation
-- Force needed: 3.5 a unit of weighted defence (ops.weigh), plus 4. Three a turret (assault: 12 took four); 5 once
-- lost to upgraded ammunition (18 units against three creeping turrets with bullet damage +0.8 lost two thirds,
-- defend), and with research now in the weight (x1.8 there) 5 counted it twice. At 3, the 21 sent there won once
-- and lost once (two thirds dead either way): 3.5 sends 23.
local PER_TURRET, BASE_FORCE = 3.5, 4
local THREAT_TICKS = 10 * 60 * 60     -- a static threat on the faction's ground stays a priority this long
local THREAT_BONUS = 10               -- value added to targets by it
local STAND_OFF = 34                  -- staging this far from the target: a laser's 24 and 10 to spare
local STAGE_TICKS = 90 * 60
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
  ["lp-uplink"] = 10, ["lp-lander"] = 8, ["lp-depot"] = 6, ["lp-generator"] = 5, ["lp-launchpad"] = 5,
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

-- Encroachment (Serenity's temper, "Please remain behind the line"): a player building inside its territory
-- provokes it as an attack does.
local function encroachment(b, surface)
  if not (shared.CORPS[b.corp].temper or {}).provoked_only or not b.claim_radius then return end
  for _, f in ipairs(enemies(game.forces[b.force])) do
    if not shared.is_corp(f.name) and surface.count_entities_filtered{position = {b.origin.x, b.origin.y},
      radius = b.claim_radius, force = f, type = TYPES, limit = 1} > 0 then
      ops.provoke(b.force, f.name)
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
  for _, o in pairs(storage.bases) do
    if o ~= b and not o.fallen and o.corp ~= b.corp and o.surface == b.surface and o.claim_radius then
      local d = math.sqrt((o.origin.x - b.origin.x) ^ 2 + (o.origin.y - b.origin.y) ^ 2)
      cap = math.min(cap, d - o.claim_radius)
    end
  end
  local new = math.min(cur + PERIMETER_STEP, cap)
  if new <= cur then return end
  b.perimeter = new
  b.perimeter_steps = (b.perimeter_steps or 0) + 1
  if ops.claim_map then ops.claim_map(b) end
  local where = string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y, surface.name)
  -- One step ahead: the structure the next step will enclose, named.
  local warn = near and near.valid and nd > new and nd <= new + PERIMETER_STEP and b.warned ~= near.unit_number
  if warn then b.warned = near.unit_number end
  for _, f in ipairs(enemies(game.forces[b.force])) do
    if #f.players > 0 and not shared.is_corp(f.name) then
      if b.perimeter_steps % 3 == 1 then
        f.print({"lp.perimeter", shared.corp_label(b.corp), where, math.floor(new)})
      end
      if warn then
        f.print({"lp.perimeter-warning", shared.corp_label(b.corp), near.localised_name,
          string.format("[gps=%d,%d,%s]", near.position.x, near.position.y, surface.name)})
      end
    end
  end
end

local function scan(b)
  local surface = game.surfaces[b.surface]
  if not b.lander.valid then return end
  sense_nests(b, surface)
  encroachment(b, surface)
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
      if by then ops.provoke(b.force, by) end
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

local function home(b)
  for _, d in ipairs(b.depots) do if d.valid then return d end end
end

local function cap(b, army) return army.cap(b) end
-- A battery shelling it: self-defence, not an operation of choice. The reserve goes too, the threat budget does
-- not hold it, and it can be besieged before the siege capability (campaign runs: a settlement that knew where
-- the battery was raided substations for 45 minutes until its lander died).
local function battery(t) return t.kind == "artillery-turret" or t.kind == "artillery-wagon" end
local function field(b, army)
  local reserve = math.ceil(RESERVE * cap(b, army))
  local n = 0
  for _, u in ipairs(b.garrison) do if u.valid then n = n + 1 end end
  return math.max(0, n - reserve), reserve
end

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
local function against_player(owner) return owner ~= nil and owner ~= "enemy" and not shared.is_corp(owner) end
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

-- Provocation (tempers): a player force that hurts a corporation's buildings or units is remembered for good.
function ops.provoke(corp_force, by)
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
end
-- Whether a corporation's temper lets it go for this target at all.
local function temper_allows(b, t)
  if not against_player(t.owner) then return true end
  if battery(t) then return true end
  local temper = shared.CORPS[b.corp].temper or {}
  if temper.provoked_only then
    local d = storage.corps and storage.corps[b.corp]
    if not (d and d.provoked and d.provoked[t.owner]) then return false end
  end
  if temper.soft_only and (t.defence or 0) > 0 then return false end
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
  local max_field = math.max(0, cap(b, army) - math.ceil(RESERVE * cap(b, army)))
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
  for key, t in pairs(b.intel.targets) do
    local player = against_player(t.owner)
    local held = player and in_flight >= budget(t.owner) and not battery(t)
    if held and game.tick >= (t.cool or 0) then storage.budget_holds = (storage.budget_holds or 0) + 1 end
    if not temper_allows(b, t) then held = true end
    if game.tick >= (t.cool or 0) and not cooling(t) and not held then
      local d = defence(b, t)
      -- Self-defence (a battery, or a static threat on its ground: turret creep) takes the reserve too: weighted,
      -- three upgraded creeping turrets needed 21 and a garrison of 28 kept 9 home (defend).
      if needed(d) <= ((battery(t) or threat_bonus(b, t) > 0) and cap(b, army) or max_field) then
        local dist = math.sqrt((t.pos[1] - h.position.x) ^ 2 + (t.pos[2] - h.position.y) ^ 2)
        local s = (t.value * (t.line and 2 or 1) + threat_bonus(b, t)) / (1 + d) ^ 1.5 / (1 + dist / 300)
          / (1 + (t.line and 0 or t.tried))
          * ((player and floor) and 3 or 1) * (battery(t) and 10 or 1)
        if not bs or s > bs then best, bs = key, s end
      end
    end
  end
  return best
end

-- Alerts (readability): an operation going in against a player puts a custom alert, with the corporation's icon,
-- on the nearest of that player's buildings, for every player of that force, on any surface they are on.
local function alert(b, t, key, at)
  if not (t and against_player(t.owner)) then return end
  local f = game.forces[t.owner]
  if not f or #f.players == 0 then return end
  local s = game.surfaces[b.surface]
  local p = at or t.pos
  local e = s.find_entities_filtered{position = p, radius = 40, force = f, limit = 1}[1]
  if not e then return end
  local c = shared.CORPS[b.corp]
  for _, player in pairs(f.players) do
    player.add_custom_alert(e, {type = "virtual", name = c.icon}, {key, c.name}, true)
  end
  storage.alerts = (storage.alerts or 0) + 1
end
ops.alert = alert

-- A notice to the players at war with this corporation, with a map link.
local function notify(b, key, at)
  local s = game.surfaces[b.surface]
  for _, f in ipairs(enemies(game.forces[b.force])) do
    if #f.players > 0 and not shared.is_corp(f.name) then
      f.print({key, shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", at[1], at[2], s.name)})
    end
  end
end

local function order_all(members, cmd)
  for _, u in ipairs(members) do if u.valid then u.commandable.set_command(cmd) end end
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
  if op.kind == "siege" then b.next_siege = game.tick + SIEGE_COOL end
  if op.kind == "strip" then
    b.next_strip = game.tick + (storage.strip_fast and 2 * 3600 or STRIP_COOL)
    for _, e in ipairs(op.camp or {}) do if e.valid then e.destroy() end end
  end
  for _, u in ipairs(op.members) do
    if u.valid then
      table.insert(b.garrison, u)
      if h then
        u.commandable.set_command{type = defines.command.go_to_location, destination = h.position, radius = 10,
          distraction = defines.distraction.by_damage}
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
    trace(b, string.format("raid razed nothing at %.0f,%.0f: resistance there now %d", t.pos[1], t.pos[2], t.resist))
  end
  if t then
    t.cool = game.tick + (t.line and COOL_TICKS / 2 or COOL_TICKS)
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
  b.next_op = game.tick + ((outcome == "done" or outcome == "spent" or outcome == "claimed") and GAP_DONE or GAP_ABORTED)
    + math.floor(lost / 5) * GAP_PER_5_LOST
  -- What it saw there at the end is the record: destroyed targets are forgotten (a raid set out again for
  -- creep it had already destroyed).
  if t then
    local pos = {x = t.pos[1], y = t.pos[2]}
    local tick = game.tick
    sense(b, game.surfaces[b.surface], pos, 40)
    for key, o in pairs(b.intel.targets) do
      if (o.pos[1] - pos.x) ^ 2 + (o.pos[2] - pos.y) ^ 2 <= 40 * 40 and o.seen < tick then b.intel.targets[key] = nil end
    end
  end
  b.ops_log = b.ops_log or {}
  table.insert(b.ops_log, {op = op.kind, kind = t and t.kind or "gone", owner = t and t.owner, outcome = outcome,
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
local function outside(b, t, ux, uy, off, len)
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
    if s.count_entities_filtered{position = p, radius = STAND_OFF, type = TURRETS, force = foes, limit = 1} == 0
      and not walled(p) then
      return p
    end
  end
  return {t.pos[1] + ux * off, t.pos[2] + uy * off}
end

-- Sneaking and breaching (Grubstake's temper; the user: "do they try to avoid turrets? And perhaps make holes in
-- undefended sections of the wall?"). From its staging point a sneaking raid plans its approach on a SNEAK_CELL grid
-- (A*), round every cell within a known turret's reach (REACH by type, plus SNEAK_MARGIN) and water, exposed only in
-- the last SNEAK_OPEN tiles to the target; it walks the route as waypoints. Walls round the target (within
-- BREACH_RADIUS): it picks the wall piece the fewest turrets can reach, knocks it and its neighbour out (a two-tile gap,
-- buggies fit), and goes through. Serenity keeps its straight, disciplined approach.
local SNEAK_CELL, SNEAK_MARGIN, SNEAK_OPEN, SNEAK_BOX = 6, 3, 16, 60
local BREACH_RADIUS = 30
local REACH = {["ammo-turret"] = 18, ["electric-turret"] = 24, ["fluid-turret"] = 30}

local function sneak_route(b, from, to)
  local s = game.surfaces[b.surface]
  local foes = enemies(game.forces[b.force])
  local x0 = math.min(from[1], to[1]) - SNEAK_BOX
  local y0 = math.min(from[2], to[2]) - SNEAK_BOX
  local w = math.ceil((math.max(from[1], to[1]) + SNEAK_BOX - x0) / SNEAK_CELL)
  local h = math.ceil((math.max(from[2], to[2]) + SNEAK_BOX - y0) / SNEAK_CELL)
  local turrets = s.find_entities_filtered{area = {{x0 - 30, y0 - 30}, {x0 + w * SNEAK_CELL + 30, y0 + h * SNEAK_CELL + 30}},
    type = {"ammo-turret", "electric-turret", "fluid-turret"}, force = foes}
  local function centre(i, j) return x0 + (i + 0.5) * SNEAK_CELL, y0 + (j + 0.5) * SNEAK_CELL end
  local blocked = {}
  local function open(i, j)
    if i < 0 or j < 0 or i >= w or j >= h then return false end
    local k = i * h + j
    if blocked[k] == nil then
      local cx, cy = centre(i, j)
      local bad = false
      if (cx - to[1]) ^ 2 + (cy - to[2]) ^ 2 > SNEAK_OPEN ^ 2 then
        for _, e in ipairs(turrets) do
          local r = (REACH[e.type] or 20) + SNEAK_MARGIN
          if (e.position.x - cx) ^ 2 + (e.position.y - cy) ^ 2 <= r * r then bad = true; break end
        end
      end
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
  -- A* over the grid, eight neighbours.
  local key = function(i, j) return i * h + j end
  local g, came, openset = {[key(si, sj)] = 0}, {}, {{si, sj}}
  local function hdist(i, j) return math.sqrt((i - ti) ^ 2 + (j - tj) ^ 2) end
  local closed = {}
  local found = false
  local steps = 0
  while #openset > 0 and steps < 4000 do
    steps = steps + 1
    local bi, bf = 1
    for n, c in ipairs(openset) do
      local f = g[key(c[1], c[2])] + hdist(c[1], c[2])
      if not bf or f < bf then bi, bf = n, f end
    end
    local c = table.remove(openset, bi)
    local ck = key(c[1], c[2])
    if c[1] == ti and c[2] == tj then found = true; break end
    closed[ck] = true
    for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}) do
      local ni, nj = c[1] + d[1], c[2] + d[2]
      local nk = key(ni, nj)
      if not closed[nk] and ((ni == ti and nj == tj) or open(ni, nj)) then
        local ng = g[ck] + ((d[1] ~= 0 and d[2] ~= 0) and 1.414 or 1)
        if not g[nk] or ng < g[nk] then
          if not g[nk] then table.insert(openset, {ni, nj}) end
          g[nk], came[nk] = ng, ck
        end
      end
    end
  end
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
      local c = 0
      for _, e in ipairs(turrets) do
        local r = REACH[e.type] or 20
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

-- Looting (Grubstake's temper: the user's heists, folded into its identity, docs/reviews/2026-10-14-identity-trees-consult
-- .md): a raid at the target first empties the player's chests within 16 tiles that one of its units stands by (6
-- tiles), valuable items first, up to LOOT_ITEMS a raid; what survivors carry home becomes parts (finish), by LOOT.
local LOOT = {["uranium-235"] = 20, ["uranium-fuel-cell"] = 10, ["processing-unit"] = 8, ["low-density-structure"] = 4,
  ["rocket-fuel"] = 3, ["advanced-circuit"] = 3, ["electronic-circuit"] = 1, ["engine-unit"] = 1,
  ["electric-engine-unit"] = 2, ["flying-robot-frame"] = 3, ["speed-module"] = 10, ["efficiency-module"] = 10,
  ["productivity-module"] = 10, ["speed-module-2"] = 20, ["efficiency-module-2"] = 20, ["productivity-module-2"] = 20,
  ["speed-module-3"] = 40, ["efficiency-module-3"] = 40, ["productivity-module-3"] = 40, ["steel-plate"] = 0.3}
local LOOT_ITEMS = 400
local function loot(b, op, t, pos, surface, trace)
  if not (shared.CORPS[b.corp].temper or {}).loots or not (t and against_player(t.owner)) then return end
  op.loot = op.loot or {items = 0, value = 0, looted = {}}
  if op.loot.items >= LOOT_ITEMS then return end
  for _, c in pairs(surface.find_entities_filtered{position = pos, radius = 16, type = {"container", "logistic-container"},
    force = t.owner}) do
    if not op.loot.looted[c.unit_number] and surface.count_entities_filtered{position = c.position, radius = 6,
      force = b.force, type = "unit", limit = 1} > 0 then
      op.loot.looted[c.unit_number] = true
      local inv = c.get_inventory(defines.inventory.chest)
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

local function launch(b, key, trace, army)
  local t = b.intel.targets[key]
  local h = home(b)
  local d = defence(b, t)
  local want = needed(d)
  local n, reserve = field(b, army)
  if battery(t) or threat_bonus(b, t) > 0 then n = n + reserve end
  if n < want then return false end
  local members = {}
  for i = #b.garrison, 1, -1 do
    if #members >= want then break end
    local u = b.garrison[i]
    if u.valid and (u.type == "unit" or u.type == "spider-unit") and shared.kind_of(u.name) ~= "lp-hauler" then
      table.insert(members, table.remove(b.garrison, i))
    end
  end
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
  b.op = {kind = "raid", target = key, phase = "stage", members = members, launched = #members, staging = stage,
    started = game.tick, phase_at = game.tick, kills_at = b.razed, last_kill = game.tick, razed0 = b.razed}
  -- A sneaking raid (Grubstake) marches to its staging point round the turrets it knows of and fights only what hits
  -- it: engaging on sight, it walked into five lasers on its way and lost 25 of 31 before the attack (sneak).
  if (shared.CORPS[b.corp].temper or {}).sneaks and not storage.sneak_off and against_player(t.owner) then
    local cmds = {}
    for _, w in ipairs(sneak_route(b, {h.position.x, h.position.y}, stage) or {}) do
      table.insert(cmds, {type = defines.command.go_to_location, destination = w, radius = 4,
        distraction = defines.distraction.by_damage})
    end
    table.insert(cmds, {type = defines.command.go_to_location, destination = stage, radius = 6,
      distraction = defines.distraction.by_damage})
    order_all(members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
      commands = cmds})
  else
    order_all(members, {type = defines.command.go_to_location, destination = stage, radius = 6,
      distraction = defines.distraction.by_enemy})
  end
  b.ops_launched = b.ops_launched + 1
  b.raids_sent = b.raids_sent + 1
  if against_player(t.owner) then storage.threat_last = game.tick end
  if t.owner == "enemy" then
    for _, f in pairs(game.forces) do
      if #f.players > 0 then
        f.print({"lp.clearing", shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", t.pos[1], t.pos[2],
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
      and not (against_player(t.owner) and in_flight >= budget(t.owner) and not battery(t))
      and not (against_player(t.owner) and not battery(t) and besieged(t.owner))
      and (not against_player(t.owner) or not (shared.CORPS[b.corp].temper or {}).provoked_only
        or (storage.corps[b.corp].provoked or {})[t.owner]) then
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
  k = math.min(k, #SIEGE_TIERS)
  local n, reserve = field(b, army)
  if battery(t) then n = n + reserve end
  while k > 1 and ((b.parts or 0) < SIEGE_TIERS[k].cost or n < SIEGE_TIERS[k].guards) do k = k - 1 end
  return k
end
ops.siege_tier = siege_tier

local function launch_siege(b, key, site, trace, army)
  local t = b.intel.targets[key]
  local tier = storage.siege_tier or siege_tier(b, t, army)
  local spec = SIEGE_TIERS[tier]
  local h = home(b)
  local s = game.surfaces[b.surface]
  local p = s.find_non_colliding_position(shared.variant(b.corp, "lp-hauler"), {h.position.x + (site[1] - h.position.x) * 0.1,
    h.position.y + (site[2] - h.position.y) * 0.1}, 20, 0.5)
  local hauler = p and s.create_entity{name = shared.variant(b.corp, "lp-hauler"), position = p, force = h.force}
  if not hauler then return false end
  local guards = {}
  -- Counter-battery (Serenity): against the player's artillery, its Shock troopers go first (up to six).
  if battery(t) and rd.has(b.corp, "counter") then
    for i = #b.garrison, 1, -1 do
      local u = b.garrison[i]
      if #guards < 6 and u.valid and shared.kind_of(u.name) == "lp-shock" then table.insert(guards, table.remove(b.garrison, i)) end
    end
  end
  for i = #b.garrison, 1, -1 do
    if #guards >= spec.guards then break end
    local u = b.garrison[i]
    if u.valid and u.type == "unit" then table.insert(guards, table.remove(b.garrison, i)) end
  end
  b.parts = math.max(0, b.parts - spec.cost)
  b.op = {kind = "siege", target = key, phase = "march", members = guards, launched = #guards, hauler = hauler,
    site = site, started = game.tick, phase_at = game.tick, shells_fired = 0, tier = tier,
    convoys_left = spec.convoys or 0}
  hauler.commandable.set_command{type = defines.command.go_to_location, destination = site, radius = 2,
    distraction = defines.distraction.none}
  order_all(guards, {type = defines.command.go_to_location, destination = hauler.position, radius = 6,
    distraction = defines.distraction.by_enemy})
  b.ops_launched = b.ops_launched + 1
  b.sieges = (b.sieges or 0) + 1
  if against_player(t.owner) then storage.threat_last = game.tick end
  trace(b, string.format("siege of %s at %.0f,%.0f (value %d, defence %.1f): tier %d, %d mortars to %.0f,%.0f, %d guards",
    t.kind, t.pos[1], t.pos[2], t.value, t.defence or 0, tier, spec.mortars, site[1], site[2], #guards))
  return true
end

local function siege_step(b, trace, army)
  local op = b.op
  local n = alive(op)
  if game.tick - op.started > SIEGE_MAX_TICKS then return finish(b, "aborted", trace, army) end
  if op.phase == "march" or op.phase == "deploy" then
    if not op.hauler.valid then
      trace(b, "siege: the hauler was destroyed on the way")
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
      distraction = defines.distraction.by_enemy})
    if (hp.x - op.site[1]) ^ 2 + (hp.y - op.site[2]) ^ 2 < 5 * 5 then
      op.phase, op.phase_at = "deploy", game.tick
      op.hauler.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none}
      -- Guards fight only what hits them: engaging what they saw, they walked from the site into turret range
      -- and four of six died (abort).
      order_all(op.members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = {{type = defines.command.go_to_location, destination = op.site, radius = 8,
          distraction = defines.distraction.by_damage},
          {type = defines.command.wander, radius = 8, distraction = defines.distraction.by_damage}}})
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
      local name = shared.variant(b.corp, "lp-mortar")
      local carry = op.carry
      op.mortars, op.carry = {}, nil
      if not carry then op.loaded = 0 end
      for k = 1, (carry and #carry or spec.mortars) do
        local a = 2 * math.pi * k / spec.mortars
        local off = spec.mortars > 1 and 4 or 0
        local p = s.find_non_colliding_position(name, {op.site[1] + math.cos(a) * off, op.site[2] + math.sin(a) * off}, 8, 0.5)
        local m = p and s.create_entity{name = name, position = p, force = op.hauler.force}
        if m then
          local shells = carry and carry[k] or spec.shells
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
      if rd.has(b.corp, "hardened") and not op.works then
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
      in_reach = in_reach + s.count_entities_filtered{position = m.position, radius = MORTAR_REACH, type = TURRETS, force = foes}
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
      if spec.mortars > 1 and not op.moved and left > 0 and op.hauler and op.hauler.valid and t
        and game.tick - (op.last_target or op.phase_at) > ASSAULT_IDLE then
        local site = siege_site(b, t)
        op.moved = true
        if site and (site[1] - op.site[1]) ^ 2 + (site[2] - op.site[2]) ^ 2 > 8 * 8 then
          op.carry = {}
          for _, m in ipairs(live) do
            table.insert(op.carry, m.get_inventory(defines.inventory.artillery_turret_ammo).get_item_count("lp-mortar-shell"))
            m.destroy()
          end
          op.mortars, op.mortar, op.site = {}, nil, site
          op.phase, op.phase_at, op.last_target = "march", game.tick, nil
          op.hauler.commandable.set_command{type = defines.command.go_to_location, destination = site, radius = 2,
            distraction = defines.distraction.none}
          trace(b, string.format("siege: moving up to %.0f,%.0f with %d shells", site[1], site[2], left))
          return
        end
      end
      -- The assault (tier 3 and up): nothing in reach for ASSAULT_IDLE after the mortars had targets, and the guards
      -- go in with what the garrison can add, sized to what is left at the target.
      if spec.assault and op.last_target and in_reach == 0 and game.tick - op.last_target > ASSAULT_IDLE and t then
        local want = needed(defence(b, t))
        for i = #b.garrison, 1, -1 do
          if #op.members >= want then break end
          local u = b.garrison[i]
          if u.valid and u.type == "unit" and shared.kind_of(u.name) ~= "lp-hauler" then
            table.insert(op.members, table.remove(b.garrison, i))
          end
        end
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
    if t.value == ops.VALUE["mining-drill"] and against_player(t.owner) and in_flight < budget(t.owner) then
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
  local guards = {}
  for i = #b.garrison, 1, -1 do
    if #guards >= STRIP_GUARDS then break end
    local u = b.garrison[i]
    if u.valid and u.type == "unit" then table.insert(guards, table.remove(b.garrison, i)) end
  end
  b.parts = b.parts - STRIP_COST
  b.op = {kind = "strip", target = key, phase = "march", members = guards, launched = #guards, hauler = hauler,
    site = site, started = game.tick, phase_at = game.tick, cargo = 0}
  hauler.commandable.set_command{type = defines.command.go_to_location, destination = site, radius = 2,
    distraction = defines.distraction.none}
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
    if near >= 0.8 * n or game.tick - op.phase_at > STAGE_TICKS then
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
        if want > n then
          rd.turned_back(b)
          trace(b, string.format("raid sees defence %.1f and units %.1f at the target, needs %d, has %d: turns back", seen,
            t.units, want, n))
          return finish(b, "aborted", trace, army)
        end
      end
      op.phase, op.phase_at, op.last_kill = "attack", game.tick, game.tick
      op.attacked = true
      alert(b, t, "lp.alert-raid")
      local pos = t and t.pos or op.staging
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
        order_all(op.members, {type = defines.command.attack_area, destination = pos, radius = 12,
          distraction = defines.distraction.by_anything})
        trace(b, string.format("raid attacks with %d of %d", n, op.launched))
      end
    end
  elseif op.phase == "breach" then
    -- Through the gap once its pieces are down; given up (and in) after STAGE_TICKS at the wall.
    local standing
    for _, w in ipairs(op.breach or {}) do if w.valid then standing = w end end
    local pos = t and t.pos or op.staging
    if n < 0.5 * op.launched then return finish(b, "aborted", trace, army) end
    if not standing or game.tick - op.phase_at > 2 * STAGE_TICKS then
      op.phase, op.phase_at, op.last_kill = "attack", game.tick, game.tick
      op.breached = not standing
      order_all(op.members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = {{type = defines.command.go_to_location, destination = op.breach_at, radius = 3,
          distraction = defines.distraction.by_damage},
          {type = defines.command.attack_area, destination = pos, radius = 12, distraction = defines.distraction.by_anything}}})
      trace(b, string.format("raid %s the wall at %.0f,%.0f and goes in with %d of %d",
        standing and "gave up on" or "breached", op.breach_at[1], op.breach_at[2], n, op.launched))
    else
      for _, u in ipairs(op.members) do
        if u.valid and not u.commandable.has_command then
          u.commandable.set_command{type = defines.command.attack, target = standing, distraction = defines.distraction.by_damage}
        end
      end
    end
  elseif op.phase == "attack" then
    if b.razed > op.kills_at then op.kills_at, op.last_kill = b.razed, game.tick end
    local pos = t and t.pos or op.staging
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
    if game.tick - op.last_kill > NO_KILL_TICKS then return finish(b, "aborted", trace, army) end
    if left == 0 then
      trace(b, string.format("raid finds nothing left within 16 of %.0f,%.0f (%d turrets within %d)", pos[1], pos[2],
        turrets, DEFENCE_RADIUS))
      return finish(b, "done", trace, army)
    end
    -- Units that finished their attack command and stand idle are sent again.
    for _, u in ipairs(op.members) do
      if u.valid and not u.commandable.has_command then
        u.commandable.set_command{type = defines.command.attack_area, destination = pos, radius = 12,
          distraction = defines.distraction.by_anything}
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

function ops.tick(b, tick, trace, army)
  if storage.ops_off then return end
  ops.init(b)
  if tick % 600 == 300 then stand_down(b) end
  if tick % SENSE_TICKS == (b.id * 97) % SENSE_TICKS then scan(b) end
  if tick % 3600 == (b.id * 53) % 3600 then ops.perimeter(b, tick) end
  if tick % 600 == 200 then field_sight(b) end
  if b.op then
    if tick % 300 == 100 then step(b, trace, army) end
  elseif tick % DECIDE_TICKS == 0 and tick >= (b.next_op or 0) and not storage.raids_off and not storage.army_off
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
      storage.unit_owner[u.unit_number] = b.id
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
  local n = 0
  for _ in pairs(b.intel and b.intel.targets or {}) do n = n + 1 end
  local t = b.op and b.intel.targets[b.op.target]
  return {known = n, op = b.op and (b.op.kind .. ":" .. b.op.phase) or nil, target = t and t.kind or nil,
    launched = b.ops_launched or 0, done = b.ops_done or 0, aborted = b.ops_aborted or 0, log = b.ops_log or {},
    siege_tier = b.op and b.op.tier, assaults = b.assaults or 0, assault_razed = b.assault_razed or 0,
    convoys_left = b.op and b.op.convoys_left, loaded = b.op and b.op.loaded, mortars = b.op and b.op.mortars and #b.op.mortars or 0,
    shells_fired = b.op and b.op.shells_fired, siege_phase = b.op and b.op.kind == "siege" and b.op.phase or nil,
    looted = b.looted or 0, works = b.op and b.op.works and #b.op.works or 0,
    route = b.op and b.op.route and #b.op.route or nil, breach_at = b.op and b.op.breach_at,
    breached = b.op and b.op.breached,
    sieges = b.sieges or 0, strips = b.strips or 0, stripped = b.stripped or 0, mortar = b.op and b.op.mortar and b.op.mortar.valid and
      {b.op.mortar.position.x, b.op.mortar.position.y} or nil}
end

return ops
