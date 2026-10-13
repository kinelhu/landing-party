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

local ops = {}

local CELL = 32
local SENSE_TICKS = 2 * 3600          -- a full scan of the static sensors
local SENSORS = {["lp-lander"] = 200, ["lp-depot"] = 150, ["lp-radar"] = 250}
local FIELD_SIGHT = 40                -- what a unit away from home sees
local DEFENCE_RADIUS = 30             -- turrets this close to a target defend it
local MARKER_TICKS = 20 * 60 * 60     -- a death marker counts this long
local DECIDE_TICKS = 30 * 60
local RESERVE = 0.3                   -- share of the garrison cap that never leaves on an operation
-- Force needed: 5 a known turret, plus 4. Three a turret (assault: 12 took four) lost to upgraded ammunition:
-- 18 units against three creeping turrets with piercing rounds lost two thirds (defend).
local PER_TURRET, BASE_FORCE = 5, 4
local THREAT_TICKS = 10 * 60 * 60     -- a static threat on the faction's ground stays a priority this long
local THREAT_BONUS = 10               -- value added to targets by it
local STAND_OFF = 34                  -- staging this far from the target: a laser's 24 and 10 to spare
local STAGE_TICKS = 90 * 60
local NO_KILL_TICKS = 90 * 60
local COOL_TICKS = 10 * 60 * 60
local MAX_TICKS = 6 * 60 * 60

-- What a player structure is worth to the faction, mirroring what hurts the faction most: command, then
-- power and logistics, then production. Lamps, pipes, belts and walls are worth nothing.
ops.VALUE = {["lp-command-relay"] = 10, ["lp-barracks"] = 8, ["substation"] = 6, ["big-electric-pole"] = 5,
  ["train-stop"] = 5, ["locomotive"] = 5, ["roboport"] = 5, ["mining-drill"] = 4, ["assembling-machine"] = 3,
  ["furnace"] = 3, ["lab"] = 3, ["radar"] = 3, ["ammo-turret"] = 1, ["electric-turret"] = 1}
local TYPES = {"mining-drill", "assembling-machine", "furnace", "lab", "radar", "roboport", "train-stop",
  "locomotive", "electric-pole", "ammo-turret", "electric-turret", "fluid-turret"}
local TURRETS = {"ammo-turret", "electric-turret", "fluid-turret", "artillery-turret"}

local function value_of(e)
  return ops.VALUE[e.name] or ops.VALUE[e.type] or 0
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
  local f = game.forces[shared.FORCE]
  for _, other in ipairs(enemies(f)) do
    local cells = {}
    for _, e in pairs(surface.find_entities_filtered{position = pos, radius = r, force = other, type = TYPES}) do
      local v = value_of(e)
      if v > 0 then
        local key = math.floor(e.position.x / CELL) .. "," .. math.floor(e.position.y / CELL)
        local c = cells[key]
        if not c or v > c.value then cells[key] = {pos = {e.position.x, e.position.y}, kind = e.name, value = v} end
      end
    end
    for key, c in pairs(cells) do
      local t = b.intel.targets[key] or {tried = 0, cool = 0}
      t.pos, t.kind, t.value, t.seen = c.pos, c.kind, c.value, game.tick
      t.defence = surface.count_entities_filtered{position = c.pos, radius = DEFENCE_RADIUS, force = other, type = TURRETS}
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

local function scan(b)
  local surface = b.lander.surface
  local sensors = {b.lander}
  for _, d in ipairs(b.depots) do if d.valid then table.insert(sensors, d) end end
  for _, r in ipairs(b.radars or {}) do if r.valid then table.insert(sensors, r) end end
  for _, s in ipairs(sensors) do
    local r = SENSORS[s.name] or 100
    sense(b, surface, s.position, r)
    forget(b, s.position, r)
  end
end

-- What is around a building under fire: the faction knows who shoots at it (turret creep beyond every
-- sensor was never raided until alarms fed the intel).
function ops.sense_at(b, pos, r)
  ops.init(b)
  sense(b, b.lander.surface, {x = pos.x or pos[1], y = pos.y or pos[2]}, r or FIELD_SIGHT)
end

-- Units in the field see around them (patrols, responses, the operation's own force).
local function field_sight(b)
  local surface = b.lander.surface
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
local function field(b, army)
  local reserve = math.ceil(RESERVE * cap(b, army))
  local n = 0
  for _, u in ipairs(b.garrison) do if u.valid then n = n + 1 end end
  return math.max(0, n - reserve), reserve
end

-- Known defence of a target: turrets seen by it, and deaths there (a turret per three markers).
local function defence(b, t)
  return (t.defence or 0) + math.floor(markers_near(b, t.pos, DEFENCE_RADIUS) / 3)
end

local function needed(d) return PER_TURRET * d + BASE_FORCE end

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
  for key, t in pairs(b.intel.targets) do
    if game.tick >= (t.cool or 0) and not cooling(t) then
      local d = defence(b, t)
      if needed(d) <= max_field then
        local dist = math.sqrt((t.pos[1] - h.position.x) ^ 2 + (t.pos[2] - h.position.y) ^ 2)
        local s = (t.value + threat_bonus(b, t)) / (1 + d) ^ 1.5 / (1 + dist / 300) / (1 + t.tried)
        if not bs or s > bs then best, bs = key, s end
      end
    end
  end
  return best
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
  if t then
    t.cool = game.tick + COOL_TICKS
    -- The whole position cools after an abort, not the one cell: an area, so cells first seen later inherit
    -- it (the turret's cell next door, scanned a minute after, was raided nine minutes later).
    if outcome == "aborted" then
      b.intel.cool = b.intel.cool or {}
      table.insert(b.intel.cool, {pos = t.pos, till = game.tick + COOL_TICKS})
    end
    if outcome == "aborted" then
      t.tried = (t.tried or 0) + 1
      local seen = b.lander.surface.count_entities_filtered{position = t.pos, radius = DEFENCE_RADIUS,
        type = TURRETS, force = enemies(b.lander.force)}
      t.defence = math.max(t.defence or 0, seen)
    end
  end
  if outcome == "aborted" then b.ops_aborted = b.ops_aborted + 1 else b.ops_done = b.ops_done + 1 end
  -- What it saw there at the end is the record: destroyed targets are forgotten (a raid set out again for
  -- creep it had already destroyed).
  if t then
    local pos = {x = t.pos[1], y = t.pos[2]}
    local tick = game.tick
    sense(b, b.lander.surface, pos, 40)
    for key, o in pairs(b.intel.targets) do
      if (o.pos[1] - pos.x) ^ 2 + (o.pos[2] - pos.y) ^ 2 <= 40 * 40 and o.seen < tick then b.intel.targets[key] = nil end
    end
  end
  b.ops_log = b.ops_log or {}
  table.insert(b.ops_log, {kind = t and t.kind or "gone", outcome = outcome, launched = op.launched, back = alive(op)})
  if #b.ops_log > 10 then table.remove(b.ops_log, 1) end
  trace(b, string.format("raid %s: %d of %d came back (target %s)", outcome, alive(op), op.launched,
    t and t.kind or "gone"))
  b.op = nil
end

local function launch(b, key, trace, army)
  local t = b.intel.targets[key]
  local h = home(b)
  local d = defence(b, t)
  local want = needed(d)
  local n, reserve = field(b, army)
  if n < want then return false end
  local members = {}
  for i = #b.garrison, 1, -1 do
    if #members >= want then break end
    local u = b.garrison[i]
    if u.valid and (u.type == "unit" or u.type == "spider-unit") and u.name ~= "lp-hauler" then
      table.insert(members, table.remove(b.garrison, i))
    end
  end
  local dx, dy = h.position.x - t.pos[1], h.position.y - t.pos[2]
  local len = math.max(1, math.sqrt(dx * dx + dy * dy))
  local off = math.min(STAND_OFF, len)
  local stage = {t.pos[1] + dx / len * off, t.pos[2] + dy / len * off}
  b.op = {kind = "raid", target = key, phase = "stage", members = members, launched = #members, staging = stage,
    started = game.tick, phase_at = game.tick, kills_at = b.razed, last_kill = game.tick}
  order_all(members, {type = defines.command.go_to_location, destination = stage, radius = 6,
    distraction = defines.distraction.by_enemy})
  b.ops_launched = b.ops_launched + 1
  b.raids_sent = b.raids_sent + 1
  trace(b, string.format("raid on %s at %.0f,%.0f (value %d, defence %d): %d units stage at %.0f,%.0f", t.kind,
    t.pos[1], t.pos[2], t.value, d, #members, stage[1], stage[2]))
  return true
end

local function step(b, trace, army)
  local op = b.op
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
        local seen = b.lander.surface.count_entities_filtered{position = t.pos, radius = DEFENCE_RADIUS, type = TURRETS,
          force = enemies(b.lander.force)}
        -- What it sees now is the freshest word (a raid that had cleared the target on its way turned back
        -- on the defence it believed before).
        t.defence = seen
        if needed(t.defence) > n then
          trace(b, string.format("raid sees %d turrets at the target, needs %d, has %d: turns back", seen,
            needed(t.defence), n))
          return finish(b, "aborted", trace, army)
        end
      end
      op.phase, op.phase_at, op.last_kill = "attack", game.tick, game.tick
      local pos = t and t.pos or op.staging
      order_all(op.members, {type = defines.command.attack_area, destination = pos, radius = 12,
        distraction = defines.distraction.by_anything})
      trace(b, string.format("raid attacks with %d of %d", n, op.launched))
    end
  elseif op.phase == "attack" then
    if b.razed > op.kills_at then op.kills_at, op.last_kill = b.razed, game.tick end
    local pos = t and t.pos or op.staging
    local surface = b.lander.surface
    local turrets = surface.count_entities_filtered{position = pos, radius = DEFENCE_RADIUS, type = TURRETS,
      force = enemies(b.lander.force)}
    local left = surface.count_entities_filtered{position = pos, radius = 16, type = TYPES,
      force = enemies(b.lander.force)}
    if n < 0.5 * op.launched and turrets > 0 then return finish(b, "aborted", trace, army) end
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

function ops.tick(b, tick, trace, army)
  if storage.ops_off then return end
  ops.init(b)
  if tick % SENSE_TICKS == (b.id * 97) % SENSE_TICKS then scan(b) end
  if tick % 600 == 200 then field_sight(b) end
  if b.op then
    if tick % 300 == 100 then step(b, trace, army) end
  elseif tick % DECIDE_TICKS == 0 and not storage.raids_off and not storage.army_off then
    if not home(b) then return end
    local key = choose(b, army)
    if key then launch(b, key, trace, army) end
  end
end

-- For stats: what the settlement knows and is doing.
function ops.summary(b)
  local n = 0
  for _ in pairs(b.intel and b.intel.targets or {}) do n = n + 1 end
  local t = b.op and b.intel.targets[b.op.target]
  return {known = n, op = b.op and (b.op.kind .. ":" .. b.op.phase) or nil, target = t and t.kind or nil,
    launched = b.ops_launched or 0, done = b.ops_done or 0, aborted = b.ops_aborted or 0, log = b.ops_log or {}}
end

return ops
