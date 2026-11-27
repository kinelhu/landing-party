-- Intel (split from ops.lua, 2026-10-18, along the AI graph's seams: docs/ai-graph.md): what a settlement knows of its
-- enemies' buildings and how it weighs them. Weighted defence and exposure (a silent turret weighs nothing: threat.lua),
-- what stands by a target, the cells its sensors record and forget, the nests on its ground, the survey toward each
-- player's spawn, and what its units in the field see. The code is as it was in ops; install runs it with ops' helpers
-- bound (K) and returns what ops calls.
local shared = require("__landing-party__.shared")
local threat = require("__landing-party__.scripts.threat")
local know = require("__landing-party__.scripts.know")

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
-- corp: a corporation's own reading, a turret type at the price its losses taught it (know.price, units lost a turret,
-- over PER_TURRET: what the formula's weight stands for) where it has one, as Synthexis prices each gun by what it cost
-- (Kessler-Hayashi's raids at a laser wall, weighed by a formula set against gun turrets, lost every one).
function ops.weigh(surface, pos, forces, r, corp)
  local w, by = 0, {}
  for _, e in pairs(surface.find_entities_filtered{position = pos, radius = r or DEFENCE_RADIUS, force = forces, type = TURRETS}) do
    local kind = e.type
    -- (The corporations' flamers are electric turrets burning nothing, 2026-11-11: weighed and answered as flamers, not
    -- lasers.)
    if kind == "electric-turret" and shared.kind_of(e.name) == "lp-flamer" then kind = "fluid-turret" end
    local k = WEIGHT[kind]
    local learned = corp and know.price(corp, e.force.name, e.name)
    -- Firepower: damage times rate of fire (defend's guns, bullet damage +0.8 and shooting speed +0.6: 2.88 each; three
    -- of them killed about 15 units whatever the raid's size, so 21 and 23 lost and 30 is what wins). Corporate
    -- research (rd.strength) is what keeps the raid a size a garrison can field.
    -- A dark turret (no power) is no defence: the Line goes through the dark stretch (the power strike).
    if k and k[1] > 0 and threat.firing(e) then
      local f = e.force
      local x = learned and learned / ops.PER_TURRET
        or k[1] * (1 + (k[2] and f.get_ammo_damage_modifier(k[2]) or 0)) * (1 + (k[2] and f.get_gun_speed_modifier(k[2]) or 0))
      w = w + x
      local dmg = DEALS[kind]
      if dmg then by[dmg] = (by[dmg] or 0) + x end
    end
  end
  local top, tw
  for dmg, x in pairs(by) do if not tw or x > tw then top, tw = dmg, x end end
  return w, top
end
-- The way in (2026-11-01, behind debug_tune way_in): the weighted turrets whose own reach covers any point of the line
-- from `from` to pos, its last WAY_LEN tiles (the assault's leg: a raid's route ends at its staging point out of reach,
-- and it goes straight in from there). A substation in a laser base's core weighed 0 within 30 tiles, and Kessler-
-- Hayashi sent 4 at it again and again, each time all dead at the wall 20 tiles from its lasers (phase visit, artillery).
local WAY_LEN, WAY_STEP = 150, 6
function ops.way_in(surface, from, pos, forces, corp)
  local dx, dy = pos[1] - from[1], pos[2] - from[2]
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1 then return 0 end
  local span = math.min(len, WAY_LEN)
  local seen, w = {}, 0
  for d = 0, span, WAY_STEP do
    local p = {pos[1] - dx / len * d, pos[2] - dy / len * d}
    for _, e in pairs(surface.find_entities_filtered{position = p, radius = threat.far(), force = forces, type = threat.FIRE}) do
      local id = e.unit_number
      if id and not seen[id] then
        local r = threat.firing(e) and WEIGHT[e.type] and threat.reach(e)
        if r and (e.position.x - p[1]) ^ 2 + (e.position.y - p[2]) ^ 2 <= r * r then
          seen[id] = true
          local k = WEIGHT[e.type]
          local learned = corp and know.price(corp, e.force.name, e.name)
          local f = e.force
          w = w + (learned and learned / ops.PER_TURRET
            or k[1] * (1 + f.get_ammo_damage_modifier(k[2])) * (1 + f.get_gun_speed_modifier(k[2])))
        end
      end
    end
  end
  return w
end
-- Exposure (the megabase consult): the weighted turrets whose own reach covers pos (threat.reach, from each one's
-- prototype). Grubstake's soft is exposure, not any turret within 30 tiles: a megabase's rails, big poles and far
-- substations sit just beyond its turrets' reach, and every one of them had counted as defended.
-- Walled in weighs over the ladder's soft (ops.lua, LADDER_SOFT 3): pressed, Grubstake still raided a walled base's
-- substations at 1.5; a thief breaks a perimeter only at its top rung, where no limit holds.
local ENCLOSE_REACH, ENCLOSE_RAYS, WALLED = 80, 6, 3.5
function ops.exposure(surface, pos, forces, fire_only)
  local w = 0
  for _, e in pairs(surface.find_entities_filtered{position = pos, radius = threat.far(), force = forces,
    type = threat.FIRE}) do
    local r = threat.firing(e) and WEIGHT[e.type] and threat.reach(e)
    if r and (e.position.x - pos[1]) ^ 2 + (e.position.y - pos[2]) ^ 2 <= r * r then
      local k = WEIGHT[e.type]
      local f = e.force
      w = w + k[1] * (1 + f.get_ammo_damage_modifier(k[2])) * (1 + f.get_gun_speed_modifier(k[2]))
    end
  end
  -- Behind a wall is not soft (2026-10-25): a substation in the middle of a walled base, out of every turret's reach,
  -- read as exposed 0, and Grubstake broke 54 walls and turrets on its way to it (system sim, seed 1). Walled in: of
  -- eight lines out to ENCLOSE_REACH, at least ENCLOSE_RAYS cross the owner's wall or gate.
  -- (Only where it decides anything: already exposed, it is; the count stops once six lines can no longer be walled.)
  -- (fire_only: the turrets' fire alone, Synthexis's reading of an approach: with the walled-in weight every point past
  -- a wall read 3.5 more, and a lone laser's back face outweighed a corner between a gun and a laser, herd test.)
  if w > WALLED or fire_only then return w end
  local rays = 0
  for k = 0, 7 do
    if rays + (8 - k) < ENCLOSE_RAYS then break end
    local a = k * math.pi / 4
    for d = 4, ENCLOSE_REACH, 4 do
      if surface.count_entities_filtered{position = {pos[1] + math.cos(a) * d, pos[2] + math.sin(a) * d}, radius = 2.5,
        force = forces, type = {"wall", "gate"}, limit = 1} > 0 then rays = rays + 1; break end
    end
  end
  if rays >= ENCLOSE_RAYS then w = w + WALLED end
  return w
end
-- Who stands by a target, at the staging look only (units move; the two-minute scan would be stale): characters 0.5,
-- units 0.5, cars and tanks 1.5, spidertrons 3, within 40 tiles. The player's army by what each unit is worth
-- (command.worth: its slots, research, rank and round), shared.SLOT_WEIGHT a slot: a fresh trooper weighs as before, a
-- battle tank its eight slots times its research, rank and round (the arms race's remainder, 0.2.478).
local MOBILE = {character = 0.5, unit = 0.5, car = 1.5, ["spider-vehicle"] = 3}
local command = require("__landing-party__.scripts.command")
local function mobile(surface, pos, forces)
  local w = 0
  for _, e in pairs(surface.find_entities_filtered{position = pos, radius = 40, force = forces,
    type = {"character", "unit", "car", "spider-vehicle"}}) do
    local worth = e.type == "unit" and command.worth(e)
    w = w + (worth and worth * shared.SLOT_WEIGHT or MOBILE[e.type] or 0)
  end
  return w
end
ops.units_near = mobile
local UNITS_TICKS = 5 * 3600

local function value_of(e)
  return ops.VALUE[shared.kind_of(e.name)] or ops.VALUE[e.type] or 0
end

local function enemies(f)
  local out = {}
  for _, other in pairs(game.forces) do
    if other ~= f and not shared.is_biters(other.name) and other.name ~= "neutral" and not f.get_cease_fire(other) then
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
-- A sensor's look, in two parts: its foes' structures within r found, by cell (sense_find), and each cell weighed
-- (sense_cell: its defence, exposure, anti-air, way in; each a search). The scan works them a few a tick (scan_step: a
-- radar over a factory found many cells, 19 ms a sensor, the spike guard); the rest call sense, both at once.
local function sense_find(b, surface, pos, r)
  local out = {}
  local f = game.forces[b.force]
  for _, other in ipairs(enemies(f)) do
    local cells = {}
    for _, e in pairs(surface.find_entities_filtered{position = pos, radius = r, force = other, type = TYPES}) do
      local v = value_of(e)
      if v > 0 then
        local key = math.floor(e.position.x / CELL) .. "," .. math.floor(e.position.y / CELL)
        local c = cells[key]
        if not c or v > c.value then
          cells[key] = {pos = {e.position.x, e.position.y}, kind = e.name, value = v, owner = e.force.name, type = e.type,
            drills = c and c.drills or 0, loot = c and c.loot or 0}
          c = cells[key]
        end
        -- Drills counted apart: a cell is named for its most valuable structure, and the substation feeding an
        -- outpost outranks its drills, so strip-mining knew none on a factory of drill outposts (factory, 8 seeds).
        if e.type == "mining-drill" then c.drills = c.drills + 1 end
        -- What a thief could carry off (ops.STEAL_WORTH: what its raids dismantle), for a thief's choice (mind.loot).
        c.loot = (c.loot or 0) + ((ops.STEAL_WORTH or {})[e.type] or 0)
      end
    end
    for key, c in pairs(cells) do out[#out + 1] = {key = key, c = c, other = other} end
  end
  table.sort(out, function(p, q) if p.key ~= q.key then return p.key < q.key end return p.other.name < q.other.name end)
  return out
end
local function sense_cell(b, surface, key, c, other)
      local t = b.intel.targets[key] or {tried = 0, cool = 0}
      t.pos, t.kind, t.value, t.seen, t.owner, t.drills, t.loot = c.pos, c.kind, c.value, game.tick, c.owner, c.drills, c.loot
      t.defence, t.dmg = ops.weigh(surface, c.pos, other, nil, b.corp)
      t.exposure = ops.exposure(surface, c.pos, other)
      -- What shoots up round it (army.air_tilt: fliers where the air is open).
      t.air_near = ops.air_near and ops.air_near(surface, c.pos, other, b.corp) or nil
      if ops.weighs_way(b) and b.origin then t.way = ops.way_in(surface, {b.origin.x, b.origin.y}, c.pos, other, b.corp) end
      -- A line cell: a pole or rail with no turret within 60 tiles and little else round it (transit far from
      -- defences: cheap to cut). Isolated: a substation inside a base, 66 tiles from its corner turrets, was
      -- raided every ten minutes and its raiders died on the way.
      t.line = (c.type == "electric-pole" or (c.type or ""):find("rail") ~= nil)
        and surface.count_entities_filtered{position = c.pos, radius = 60, force = other, type = TURRETS, limit = 1} == 0
        and surface.count_entities_filtered{position = c.pos, radius = 30, force = other, type = TYPES, limit = 8} < 8
      b.intel.targets[key] = t
end
local function sense(b, surface, pos, r)
  for _, it in ipairs(sense_find(b, surface, pos, r)) do sense_cell(b, surface, it.key, it.c, it.other) end
end

-- A sensor sweep over the cells it covers: what is gone is forgotten.
local function forget(b, pos, r, since)
  -- (Not seen since `since`, the scan's start when its sensors read over several ticks: read so, each forgot what the one
  -- before it had just seen, as stale, and the camps lost their targets; nests and strip failed, 0.3.1.)
  local before = since or game.tick
  for key, t in pairs(b.intel.targets) do
    -- A cut (the power survey) is kept until the next survey says otherwise.
    if (t.pos[1] - pos.x) ^ 2 + (t.pos[2] - pos.y) ^ 2 <= r * r and t.seen < before and not t.cut then
      b.intel.targets[key] = nil
    end
  end
end

-- Nests on its own territory, for a corporation that clears them (Serenity; Grubstake routes round them):
-- spawners within its claim are targets (value 3), worms by them their defence. Announced when raided.
local function sense_nests(b, surface)
  if not shared.CORPS[b.corp].clears_nests or not b.claim_radius then return end
  for _, sp in pairs(surface.find_entities_filtered{position = {b.origin.x, b.origin.y}, radius = b.claim_radius,
    force = shared.NEST_FORCES, type = "unit-spawner"}) do
    local key = "nest:" .. math.floor(sp.position.x / CELL) .. "," .. math.floor(sp.position.y / CELL)
    local t = b.intel.targets[key] or {tried = 0, cool = 0}
    t.pos, t.kind, t.value, t.seen, t.owner = {sp.position.x, sp.position.y}, sp.name, 3, game.tick, "enemy"
    t.defence = surface.count_entities_filtered{position = sp.position, radius = DEFENCE_RADIUS, force = shared.NEST_FORCES, type = "turret"}
    b.intel.targets[key] = t
  end
end

-- (Its sensors read SCAN_STEP a tick, not all in one: a camp of dozens of radars before the player's factory read them
-- in one tick, 100 to 131 ms every 2 minutes on the user's nw game, "huge stutters". Each sensor reads as before.)
local SCAN_CELLS = 4   -- cells weighed a step (sense_cell); a sensor's find is a step of its own
local function scan_step(b)
  local q = b.scan_queue
  if not q then return end
  local surface = game.surfaces[b.surface]
  local it = q[#q]
  if not it then b.scan_queue, b.scan_since = nil, nil return end
  if it.kind == "sensor" then
    -- A sensor: its find now, then its cells, then its forget, as items in its place.
    table.remove(q)
    local s = it.e
    if s.valid then
      local r = SENSORS[shared.kind_of(s.name)] or 100
      local pos = {x = s.position.x, y = s.position.y}
      q[#q + 1] = {kind = "forget", pos = pos, r = r}
      local found = sense_find(b, surface, pos, r)
      for i = #found, 1, -1 do q[#q + 1] = {kind = "cell", key = found[i].key, c = found[i].c, other = found[i].other} end
    end
  else
    for _ = 1, SCAN_CELLS do
      it = q[#q]
      if not it or it.kind ~= "cell" then break end
      table.remove(q)
      if it.other.valid then sense_cell(b, surface, it.key, it.c, it.other) end
    end
    it = q[#q]
    if it and it.kind == "forget" then
      table.remove(q)
      forget(b, it.pos, it.r, b.scan_since)
    end
  end
  if #q == 0 then b.scan_queue, b.scan_since = nil, nil end
end
local function scan(b)
  local surface = game.surfaces[b.surface]
  if not b.lander.valid then return end
  sense_nests(b, surface)
  local sensors = {b.lander}
  for _, d in ipairs(b.depots) do if d.valid then table.insert(sensors, d) end end
  for _, r in ipairs(b.radars or {}) do if r.valid then table.insert(sensors, r) end end
  -- (Read last first, table.remove: the lander first of all.)
  local q = {}
  for i = #sensors, 1, -1 do q[#q + 1] = {kind = "sensor", e = sensors[i]} end
  b.scan_queue, b.scan_since = q, game.tick
  scan_step(b)
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

-- Orbital sight (shared.CORPS orbital_intel; the user, 2026-11-26: "I thought we had given it an all seeing eye like
-- Synthexis?"): a camp knows every building of its foes within ORBIT_RANGE, not only what its radars, its units and the
-- survey's one line to the spawn see. On the user's nw game Kessler-Hayashi knew 14 of the player's cells, all on the
-- walled front its survey line met, and raided nothing in 15 minutes: the stretches defended by water alone it had never
-- seen. Spread over ticks: ORBIT_LOOK chunks looked at a step (one cheap count each), and ORBIT_SENSE of those with
-- buildings sensed (each its cells' defence, exposure and way in, as any sensor's), what is gone forgotten.
local ORBIT_RANGE, ORBIT_LOOK, ORBIT_SENSE = 1500, 32, 2
-- At most ORBIT_MAX of the player's targets known (the nearest kept, past it orbit only forgets): every decision weighs
-- each known target, and 321 of them cost the decider 110 to 160 ms and its sieges 520 ms every 30 s (the user's nw game,
-- 2026-11-26: "huge stutters"). Its raids go at the near ones.
local ORBIT_MAX = 80
local function player_targets(b)
  local out = {}
  for key, t in pairs(b.intel.targets) do
    local f = t.pos and t.owner and game.forces[t.owner]
    if f and shared.is_player_force(f) then out[#out + 1] = key end
  end
  return out
end
-- The farthest past ORBIT_MAX forgotten (not one an operation is at, nor a battery).
local function trim(b)
  local keys = player_targets(b)
  if #keys <= ORBIT_MAX then return #keys end
  local o, at = b.origin, b.op and b.op.target
  local function d2(key) local p = b.intel.targets[key].pos return (p[1] - o.x) ^ 2 + (p[2] - o.y) ^ 2 end
  table.sort(keys, function(p, q) local a, c = d2(p), d2(q) if a ~= c then return a < c end return p < q end)
  for i = #keys, ORBIT_MAX + 1, -1 do
    local t = b.intel.targets[keys[i]]
    if keys[i] ~= at and not (t.kind == "artillery-turret" or t.kind == "artillery-wagon") then b.intel.targets[keys[i]] = nil end
  end
  return ORBIT_MAX
end
local function orbit(b)
  if not ((shared.CORPS[b.corp] or {}).orbital_intel and b.origin and b.lander.valid) or storage.orbit_off then return end
  local s = game.surfaces[b.surface]
  local o = b.orbit
  if not o or not o.ring then
    -- A pass: the chunks within range, nearest first, and none queued yet.
    local cx, cy = math.floor(b.origin.x / 32), math.floor(b.origin.y / 32)
    local n = math.ceil(ORBIT_RANGE / 32)
    local ring = {}
    for dx = -n, n do for dy = -n, n do
      if dx * dx + dy * dy <= n * n then ring[#ring + 1] = {cx + dx, cy + dy, dx * dx + dy * dy} end
    end end
    table.sort(ring, function(p, q) return p[3] < q[3] end)
    o = {ring = ring, i = 1, queue = {}, passes = (o and o.passes or 0), sensed = (o and o.sensed or 0)}
    b.orbit = o
    o.known = trim(b)
  end
  local foes = {}
  for _, f in ipairs(enemies(game.forces[b.force])) do
    if shared.is_player_force(f) then foes[#foes + 1] = f end
  end
  if #foes == 0 then return end
  for _ = 1, ORBIT_LOOK do
    local c = o.ring[o.i]
    if not c then break end
    o.i = o.i + 1
    if s.is_chunk_generated({c[1], c[2]}) and s.count_entities_filtered{area = {{c[1] * 32, c[2] * 32}, {c[1] * 32 + 32, c[2] * 32 + 32}},
      force = foes, type = TYPES, limit = 1} > 0 then
      o.queue[#o.queue + 1] = {c[1], c[2]}
    end
  end
  for _ = 1, ORBIT_SENSE do
    local c = table.remove(o.queue, 1)
    if not c then break end
    local mid = {x = c[1] * 32 + 16, y = c[2] * 32 + 16}
    -- (Past ORBIT_MAX known, only what is gone forgotten; counted again each pass, and each 30 sensings.)
    if o.sensed % 30 == 0 then o.known = #player_targets(b) end
    if (o.known or 0) < ORBIT_MAX then sense(b, s, mid, 23) end
    forget(b, mid, 23)
    o.sensed = o.sensed + 1
  end
  if not o.ring[o.i] and #o.queue == 0 then o.ring, o.passes = nil, o.passes + 1 end
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
return {SURVEY_TICKS = SURVEY_TICKS, UNITS_TICKS = UNITS_TICKS, enemies = enemies, field_sight = field_sight, mobile = mobile, orbit = orbit, scan = scan, scan_step = scan_step, sense = sense, survey = survey}
end

return intel
