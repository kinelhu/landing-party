-- Intel (split from ops.lua, 2026-10-18, along the AI graph's seams: docs/ai-graph.md): what a settlement knows of its
-- enemies' buildings and how it weighs them. Weighted defence and exposure (a dark turret weighs nothing: power.lua),
-- what stands by a target, the cells its sensors record and forget, the nests on its ground, the survey toward each
-- player's spawn, and what its units in the field see. The code is as it was in ops; install runs it with ops' helpers
-- bound (K) and returns what ops calls.
local shared = require("__landing-party__.shared")

local intel = {}

function intel.install(ops, K)
local CELL = K.CELL
local DEFENCE_RADIUS = K.DEFENCE_RADIUS
local FIELD_SIGHT = K.FIELD_SIGHT
local SENSORS = K.SENSORS
local TURRETS = K.TURRETS
local TYPES = K.TYPES
local power = K.power
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
    -- A dark turret (no power) is no defence: the Line goes through the dark stretch (the power strike).
    if k and k[1] > 0 and not power.dark(e) then
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
    local r = not power.dark(e) and EXPOSE[e.type]
    if r and (e.position.x - pos[1]) ^ 2 + (e.position.y - pos[2]) ^ 2 <= r * r then
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
    -- A cut (the power survey) is kept until the next survey says otherwise.
    if (t.pos[1] - pos.x) ^ 2 + (t.pos[2] - pos.y) ^ 2 <= r * r and t.seen < game.tick and not t.cut then
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
return {SURVEY_TICKS = SURVEY_TICKS, UNITS_TICKS = UNITS_TICKS, enemies = enemies, field_sight = field_sight, mobile = mobile, scan = scan, sense = sense, survey = survey}
end

return intel
