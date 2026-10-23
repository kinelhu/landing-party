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
local jammer = require("__landing-party__.scripts.jammer")
local power = require("__landing-party__.scripts.power")

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
-- A clearance's guards shoot biters this near its pieces, and its site is out of every worm's reach by this more (at 24
-- round a site just out of reach, guards met the worms).
local CLEAR_GUARD = 12
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

-- Intel: scripts/intel.lua (split from here, 2026-10-18).
local intel_ = require("__landing-party__.scripts.intel").install(ops, {
  CELL = CELL, DEFENCE_RADIUS = DEFENCE_RADIUS, FIELD_SIGHT = FIELD_SIGHT, SENSORS = SENSORS, TURRETS = TURRETS,
  TYPES = TYPES, power = power})
local SURVEY_TICKS, UNITS_TICKS, enemies, field_sight = intel_.SURVEY_TICKS, intel_.UNITS_TICKS, intel_.enemies,
  intel_.field_sight
local mobile, scan, sense, survey = intel_.mobile, intel_.scan, intel_.sense, intel_.survey

-- Perimeter: scripts/perimeter.lua (split from here, 2026-10-18).
local perimeter_ = require("__landing-party__.scripts.perimeter").install(ops, {
  TYPES = TYPES, enemies = enemies, stance = stance})
local FLOOR_TICKS = perimeter_.FLOOR_TICKS

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

-- Reprisal (the user, 2026-10-21: Grubstake raided Serenity again and again, "I didn't witness a punitive raid on their
-- base though?"): a rival that kills REPRISAL_LOSSES of a camp's buildings or units within REPRISAL_TICKS has its own
-- targets weighed REPRISAL_WEIGHT times for REPRISAL_TICKS more, and the war on the player no longer holds them back.
local REPRISAL_LOSSES = 4
local REPRISAL_TICKS = 20 * 3600
local REPRISAL_WEIGHT = 5
local REPRISAL_SOON = 2 * 3600
function ops.wronged(b, by)
  if not b or b.fallen or not shared.is_corp(by) or by == b.force then return end
  b.wrongs = b.wrongs or {}
  local w = b.wrongs[by]
  if not w or game.tick - w.since > REPRISAL_TICKS then w = {since = game.tick, n = 0}; b.wrongs[by] = w end
  w.n = w.n + 1
  if w.n >= REPRISAL_LOSSES and not (b.reprisal and b.reprisal.owner == by and game.tick < b.reprisal.till) then
    b.reprisal = {owner = by, since = game.tick, till = game.tick + REPRISAL_TICKS}
    b.reprisals = (b.reprisals or 0) + 1
    -- Paid back soon: its next operation within REPRISAL_SOON, not at its usual pace (it came 14 minutes later, reprisal).
    b.next_op = math.min(b.next_op or 0, game.tick + REPRISAL_SOON)
    if ops.trace then ops.trace(b, string.format("reprisal: %d lost to %s in %d s; its targets weigh %dx for %d minutes", w.n, by,
      (game.tick - w.since) / 60, REPRISAL_WEIGHT, REPRISAL_TICKS / 3600)) end
  end
end
local function reprisal(b, t)
  return b.reprisal and b.reprisal.owner == t.owner and game.tick < b.reprisal.till
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
-- Railgunners stay out of operations against buildings: their 30 tiles outrange a gun turret's 18, and the user saw them
-- shoot at the player's turrets from beyond reach (deathworld, 2026-10-20). They clear nests (siege.lua) and guard home:
-- they count towards the floor kept home, not towards what can be sent.
local function fights(u) local k = shared.kind_of(u.name) return k ~= "lp-hauler" and k ~= "lp-railgunner" end
local function field(b, army)
  local floor = pool.floor(cap(b, army), "reserve")
  local home, rails = pool.home(b), 0
  for _, u in ipairs(b.garrison) do if u.valid and shared.kind_of(u.name) == "lp-railgunner" then rails = rails + 1 end end
  return math.max(0, math.min(home - floor, home - rails)), floor - pool.GUARD
end
local SOLDIER = function(u) return (u.type == "unit" or u.type == "spider-unit") and fights(u) end
local FOOT = function(u) return u.type == "unit" and fights(u) end
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
  if not shared.is_corp(corp_force) or by == nil or shared.is_corp(by) or shared.is_biters(by) or by == "neutral" then return end
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
    -- A corporation at war from landing (Serenity) answers trespass only (the user, 2026-10-19: every unit it lost had
    -- bought a raid on top of the war it already wages, and fighting it cost more than enduring it).
    local hostile = (shared.CORPS[b.corp].temper or {}).hostile
    if b.force == corp_force and not b.fallen and b.lander and b.lander.valid and not (hostile and kind ~= "trespass") then
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

-- A thief's camp hurt (Fable's engagement consult: "Grubstake pulls raiders home to guard a damaged lander, so raids
-- pause, which is itself the player's reward"): the lander below 60%, or its garrison bled: no raid on the player until
-- it is mended. Grubstake only (soft_only); Serenity fights on.
function ops.camp_hurt(b)
  if not (shared.CORPS[b.corp].temper or {}).soft_only or not (b.lander and b.lander.valid) then return false end
  -- Or its garrison bled: under half the strength it had at most in the last hour (the factory's strikes died to a man
  -- but took 31 to 48 of its units each, and it raided on as if nothing had happened).
  local st = pool.strength(b)
  b.peak = b.peak or {at = game.tick, n = st}
  if st >= b.peak.n or game.tick - b.peak.at > 60 * 3600 then b.peak = {at = game.tick, n = st} end
  local bled = b.peak.n >= 10 and st < 0.5 * b.peak.n
  -- Not its generators: down and slow to come back (construction.lua), they kept its raiders home to guard a camp that
  -- then held every strike off (the factory: one lander of four taken, against four of four).
  local hurt = b.lander.health < 0.6 * b.lander.max_health or bled
  if hurt and not b.hurt_said then
    b.hurt_said = true
    b.held_home = (b.held_home or 0) + 1
    if ops.trace then ops.trace(b, string.format("camp hurt (lander %.0f%%, generators %d of %d, garrison %d of %d): its raids held home",
      100 * b.lander.health / b.lander.max_health, b.gens_counted or 0, b.gens_max or 0, st, b.peak.n)) end
  elseif not hurt then
    b.hurt_said = nil
  end
  return hurt
end

-- Setbacks (the same consult: "each kill should remove an asset the corporation has to re-earn"): a skimming truck lost
-- or a raid broken by its leader's death holds the thief's next operation back SETBACK.
local SETBACK = 10 * 3600
function ops.setback(b, why)
  b.next_op = math.max(b.next_op or 0, game.tick + SETBACK)
  b.setbacks = (b.setbacks or 0) + 1
  if ops.trace then ops.trace(b, "setback: " .. why .. "; its next operation held 10 minutes") end
end

-- Thieves' hours (Grubstake's temper `night`; Fulgora Replicators' raid nights, the user: "that seems great"): its
-- thefts (raids on the player, skims, claim jumps) set out only after dark, so the player learns when it comes. A
-- surface with no night (always day, or day frozen) has no such hours: it steals when it will.
local NIGHT = 0.3                 -- darkness from which it is night
function ops.thief_hours(b)
  if storage.night_off or not (shared.CORPS[b.corp].temper or {}).night then return true end
  local s = game.surfaces[b.surface]
  if not s or s.always_day or (s.freeze_daytime and s.darkness < NIGHT) then return true end
  return s.darkness >= NIGHT
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
  if not ops.thief_hours(b) then return false end
  if ops.camp_hurt(b) then return false end
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
-- What a rival's camp has shown it holds (finish: two for each raid on it that razed nothing), halved every HELD_HALF.
local HELD_HALF = 30 * 3600
local function held_by(b, owner)
  local h = b.intel and b.intel.held and b.intel.held[owner]
  if not h then return 0 end
  return h.n * 0.5 ^ ((game.tick - h.at) / HELD_HALF)
end
local function defence(b, t)
  local units = (t.units and game.tick - (t.units_at or 0) < UNITS_TICKS) and t.units or 0
  return ((t.defence or 0) + (t.resist or 0) + units + math.floor(markers_near(b, t.pos, DEFENCE_RADIUS) / 3)
    + held_by(b, t.owner)) / rd.strength(b.corp, t.dmg)
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
    if pressed and not player and not battery(t) and threat_bonus(b, t) == 0 and not reprisal(b, t) then held = true end
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
          * (desperate and 10 or 1) * ((not player and pressed and not reprisal(b, t)) and 0.2 or 1)
          * (reprisal(b, t) and REPRISAL_WEIGHT or 1)
          * ((player and b.claim_radius and not storage.strangle_off and stance.standing(b.corp, t.owner) == "enemy"
            and (t.pos[1] - b.origin.x) ^ 2 + (t.pos[2] - b.origin.y) ^ 2 <= b.claim_radius ^ 2) and 2 or 1)
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
  if op.howitzer and op.howitzer.valid then op.howitzer.destroy() end
  jammer.lower(op.jammer)
  -- Its hits mended: a siege on a wall kept by robots that ends with their roboports still standing teaches it the
  -- jammer (rd).
  local tt = op.target and b.intel.targets[op.target]
  if op.with_howitzer and tt and game.surfaces[b.surface].count_entities_filtered{position = tt.pos, radius = 60,
    type = "roboport", force = enemies(game.forces[b.force]), limit = 1} > 0 then
    rd.mended(b)
  end
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
  if op.leader_mark and op.leader_mark.valid then op.leader_mark.destroy() end
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
    -- A rival corporation's camp is held as a whole (lines, patrols, districts): what one failed raid on it met, every
    -- target of that rival is weighed with (Grubstake raided Serenity's fortress seven times for nothing, each target
    -- new to it read "defence 0.0": factory-12345-labs1, the user's save).
    if shared.is_corp(t.owner) then
      b.intel.held = b.intel.held or {}
      local h = b.intel.held[t.owner] or {n = 0, at = game.tick}
      h.n = held_by(b, t.owner) + 2
      h.at = game.tick
      b.intel.held[t.owner] = h
    end
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
  -- Loot reaches home with whoever survives, as items in the yard (ops.stash, skim.lua) and its worth in parts; none
  -- survive, and it spills where they fell (the player takes back what was stolen).
  if op.loot and op.loot.value > 0 and alive(op) > 0 then
    b.parts = b.parts + math.floor(op.loot.value)
    b.looted = (b.looted or 0) + op.loot.items
    if op.loot.goods and ops.stash then ops.stash(b, op.loot.goods) end
    trace(b, string.format("raid home with %d items of loot: %d parts", op.loot.items, math.floor(op.loot.value)))
  elseif op.loot and op.loot.goods then
    local s = game.surfaces[b.surface]
    local at = op.last_pos or (t and t.pos and {x = t.pos[1], y = t.pos[2]})
    if at then
      for _, g in pairs(op.loot.goods) do
        if g.count > 0 then s.spill_item_stack{position = at, stack = {name = g.name, count = g.count, quality = g.quality},
          enable_looted = true} end
      end
      trace(b, "raid lost; its loot spilled")
    end
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
    back = alive(op), shells = op.shells_fired, site = op.site, cut = op.cut})
  if #b.ops_log > 10 then table.remove(b.ops_log, 1) end
  trace(b, string.format("%s %s: %d of %d came back (target %s)", op.kind, outcome, alive(op), op.launched,
    t and t.kind or "gone"))
  b.op = nil
end

-- Staging, routes and breaches: scripts/routing.lua (split from here).
local R = require("__landing-party__.scripts.routing").install(ops, {enemies = enemies, ladder = ladder,
  STAND_OFF = STAND_OFF, TURRETS = TURRETS})
local outside, sneak_route, push_escort, breach_point, wall_on_line = R.outside, R.sneak_route, R.push_escort,
  R.breach_point, R.wall_on_line
local PUSH_VALUE, PUSH_CROSSINGS, SNEAK_BOX = R.PUSH_VALUE, R.PUSH_CROSSINGS, R.SNEAK_BOX
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
-- What a raid carries, item by item (kept as items: home in the yard, or spilled where the raid died).
local function carry(op, name, quality, count)
  op.loot.goods = op.loot.goods or {}
  local k = name .. "|" .. (quality or "normal")
  local g = op.loot.goods[k] or {name = name, quality = quality or "normal", count = 0}
  g.count = g.count + count
  op.loot.goods[k] = g
end
-- Dismantling (the user, 2026-10-19: "Stealing items and buildings is genius for a more early game rival"): at the
-- target, a raider standing by one of the player's machines (DISMANTLE_REACH) takes it apart and carries it off, its
-- contents with it, leaving its ghost where it stood: the outline of what was stolen (robots rebuild it, at the player's
-- cost; with none, the hole stays). Machines first, by WORTH; one a raider a step, DISMANTLE_MAX a raid. Walls, turrets,
-- belts, pipes and rails are left (it steals what makes things, not what holds them).
local DISMANTLE_TYPES = {"assembling-machine", "furnace", "mining-drill", "lab", "solar-panel", "accumulator", "beacon",
  "radar", "boiler", "generator", "inserter", "electric-pole", "pump", "offshore-pump", "storage-tank", "roboport"}
local WORTH = {["assembling-machine"] = 3, furnace = 2, ["mining-drill"] = 3, lab = 3, ["solar-panel"] = 2, accumulator = 2,
  beacon = 8, radar = 2, boiler = 1, generator = 3, inserter = 0.5, ["electric-pole"] = 0.5, pump = 1, ["offshore-pump"] = 1,
  ["storage-tank"] = 1, roboport = 8}
local DISMANTLE_MAX, DISMANTLE_REACH = 12, 8
-- A thief walks in and takes rather than shoots (raiding as an army, it razed three of four assemblers before its first
-- step could take one, scenario dismantle): with something to carry at the target, its raiders go there answering
-- only what hits them; with nothing left (or its hands full), they attack as any raid does (ops.thief_done).
local function thief_cmd(b, t, pos, surface)
  if not storage.dismantle_off and (shared.CORPS[b.corp].temper or {}).loots and t and against_player(t.owner)
    and surface.count_entities_filtered{position = pos, radius = 16, type = DISMANTLE_TYPES, force = t.owner, limit = 1} > 0 then
    return {type = defines.command.go_to_location, destination = pos, radius = 4, distraction = defines.distraction.by_damage}, true
  end
  return {type = defines.command.attack_area, destination = pos, radius = 12, distraction = defines.distraction.by_anything}, false
end
local function dismantle(b, op, t, pos, surface, trace)
  -- Raids only: the claim jumper's heist loots through ops.loot too, with hands, not members (it crashed on nw, an
  -- assembler by the chests it emptied).
  if storage.dismantle_off or op.kind ~= "raid" or not op.members then return end
  op.loot.dismantled = op.loot.dismantled or 0
  local room = DISMANTLE_MAX - op.loot.dismantled
  local list = room > 0 and surface.find_entities_filtered{position = pos, radius = 16, type = DISMANTLE_TYPES, force = t.owner} or {}
  if #list == 0 then
    -- Nothing left to carry: the thieves attack as any raid does.
    if op.thieving then
      op.thieving = false
      order_all(op.members, {type = defines.command.attack_area, destination = pos, radius = 12,
        distraction = defines.distraction.by_anything})
    end
    return
  end
  table.sort(list, function(x, y) return (WORTH[x.type] or 0) > (WORTH[y.type] or 0) end)
  local hands = math.max(1, alive(op))
  for _, e in ipairs(list) do
    if hands <= 0 or room <= 0 then break end
    if e.valid and surface.count_entities_filtered{position = e.position, radius = DISMANTLE_REACH, force = b.force,
      type = "unit", limit = 1} > 0 then
      local name, at, dir, q, force = e.name, e.position, e.direction, e.quality and e.quality.name or "normal", e.force
      local kind = e.type
      local inv = game.create_inventory(48)
      if e.mine{inventory = inv, force = true, raise_destroyed = true} then
        for _, it in pairs(inv.get_contents()) do
          carry(op, it.name, it.quality, it.count)
          op.loot.items = op.loot.items + it.count
        end
        op.loot.value = op.loot.value + (WORTH[kind] or 1)
        op.loot.dismantled = op.loot.dismantled + 1
        op.last_kill = game.tick
        b.dismantled = (b.dismantled or 0) + 1
        -- Its ghost left for the player's robots, where one can stand: a captured camp's drill has no item to place it,
        -- and its ghost crashed (factory away, seed 5).
        local proto = prototypes.entity[name]
        if proto and proto.items_to_place_this and #proto.items_to_place_this > 0 then
          surface.create_entity{name = "entity-ghost", inner_name = name, position = at, direction = dir, force = force,
            quality = q}
        end
        hands, room = hands - 1, room - 1
        if not op.loot.alerted then
          op.loot.alerted = true
          alert(b, t, "lp.alert-loot", {at.x, at.y})
        end
        trace(b, string.format("dismantled a %s at %.0f,%.0f and carried it off (%d this raid)", name, at.x, at.y,
          op.loot.dismantled))
      end
      inv.destroy()
    end
  end
end
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
        if took > 0 then carry(op, it.name, it.quality, took) end
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
  dismantle(b, op, t, pos, surface, trace)
end

ops.loot = loot

-- The raid's leader (Jungle Raiders' Alpha; the user asked for inspiration, 2026-10-19): a raid of LEAD_MIN or more
-- has one, its corporation's icon over it, so the player can pick it out. Killed, Grubstake's raid breaks and runs home
-- with what it carries (a thief's courage is its foreman); Serenity's falls back to its staging point in order, a new
-- leader takes the icon, and it comes again (ops.leader_step). The two read apart under fire.
local LEAD_MIN = 3
function ops.appoint(b, op)
  if storage.leader_off or #op.members < LEAD_MIN then return end
  local best
  for _, u in ipairs(op.members) do
    if u.valid and (not best or shared.kind_of(u.name) == "lp-infantry") then best = u end
    if best and shared.kind_of(best.name) == "lp-infantry" then break end
  end
  if not best then return end
  if op.leader_mark and op.leader_mark.valid then op.leader_mark.destroy() end
  op.leader = best
  -- In its colour and a size up (at 0.6, white, it was hard to find in a screenshot, scripts/shots.sh).
  op.leader_mark = rendering.draw_sprite{sprite = "virtual-signal/" .. shared.CORPS[b.corp].icon, surface = best.surface,
    target = {entity = best, offset = {0, -2.2}}, x_scale = 1.1, y_scale = 1.1, tint = shared.CORPS[b.corp].color}
end

-- A raider killed with loot drops its share where it fell (Fulgora Replicators, the user's pointer: "killing a raider
-- makes it drop what it was carrying"; the loot had spilled only when the whole raid died). Grubstake's foreman carries
-- the haul (Fable's engagement consult: kill the leader and the party drops its load): it drops all of it, and the raid
-- breaks and runs home empty.
function ops.raider_died(b, ent)
  local op = b.op
  if op and op.leader == ent then op.leader_down = true end
  if not (op and op.loot and op.loot.goods and op.members) then return end
  local mine = false
  for _, u in ipairs(op.members) do if u == ent then mine = true break end end
  if not mine then return end
  local n = math.max(1, alive(op))
  if op.leader == ent and (shared.CORPS[b.corp].temper or {}).soft_only then n = 1 end
  local s = ent.surface
  for _, g in pairs(op.loot.goods) do
    local share = math.floor(g.count / n + 0.5)
    if share > 0 then
      s.spill_item_stack{position = ent.position, stack = {name = g.name, count = share, quality = g.quality}, enable_looted = true}
      g.count = g.count - share
      op.loot.items = math.max(0, op.loot.items - share)
      op.loot.value = math.max(0, op.loot.value - share * (LOOT[g.name] or 0.1))
    end
  end
end

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
    if took > 0 then carry(op, it.name, it.quality, took) end
    op.loot.items = op.loot.items + took
    op.loot.value = op.loot.value + took * (LOOT[it.name] or 0.1)
  end
end

-- 128 and 90 minutes (64 and 30 at first: on nw a fortress's staging points 115 apart each ran dry again every half hour,
-- 95 to 125 ms a search, nine times in three hours).
local DEAD_END_RADIUS, DEAD_END_TICKS = 128, 90 * 3600
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
  b.op = {kind = "raid", answer = is_answer or nil, cut = t.cut, target = key, phase = "stage", members = members, launched = #members, staging = stage, owner = t.owner,
    started = game.tick, phase_at = game.tick, kills_at = b.razed, last_kill = game.tick, razed0 = b.razed}
  ops.appoint(b, b.op)
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
        force = shared.NEST_FORCES}) do
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
        return (ops.clearance(b, near, trace, army, {t.pos[1], t.pos[2]}))
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
    trace(b, string.format("raid on %s at %.0f,%.0f: no way round the turrets or biter country; not sent (%s)", t.kind, t.pos[1], t.pos[2],
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
  -- A reprisal is one punitive raid (it had weighed the rival's targets for 20 minutes, raid after raid, and in rivals
  -- Serenity took Grubstake's camp in 37 minutes): spent when it goes.
  if reprisal(b, t) then
    b.reprisal.till = game.tick
    if ops.trace then ops.trace(b, "reprisal: the punitive raid goes; paid") end
  end
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

-- Siege: scripts/siege.lua (split from here, 2026-10-18).
local siege_ = require("__landing-party__.scripts.siege").install(ops, {
  ASSAULT_IDLE = ASSAULT_IDLE, CELL = CELL, CLEAR_GUARD = CLEAR_GUARD, CLEAR_RAILS = CLEAR_RAILS,
  COOL_TICKS = COOL_TICKS, DEFENCE_RADIUS = DEFENCE_RADIUS, DEPLOY_TICKS = DEPLOY_TICKS, FOOT = FOOT,
  HOWITZER_REACH = HOWITZER_REACH, HOWITZER_STAND = HOWITZER_STAND, MORTAR_REACH = MORTAR_REACH,
  NO_KILL_TICKS = NO_KILL_TICKS, PACK_TICKS = PACK_TICKS, PLAYER_REACH = PLAYER_REACH, RESUPPLY = RESUPPLY,
  SHELLS_CAP = SHELLS_CAP, SIEGE_COST = SIEGE_COST, SIEGE_GUARDS = SIEGE_GUARDS, SIEGE_MAX_TICKS = SIEGE_MAX_TICKS,
  SIEGE_SHELLS = SIEGE_SHELLS, SIEGE_TIERS = SIEGE_TIERS, STUCK_TICKS = STUCK_TICKS, TURRETS = TURRETS,
  TYPES = TYPES, against_player = against_player, alert = alert, alive = alive, battery = battery, budget = budget,
  defence = defence, enemies = enemies, field = field, finish = finish, floor_of = floor_of, home = home,
  jammer = jammer, needed = needed, order_all = order_all, pool = pool, push_escort = push_escort, rd = rd,
  sneak_route = sneak_route, stance = stance, threat_bonus = threat_bonus})
local choose_siege, launch_siege, siege_site, siege_step = siege_.choose_siege, siege_.launch_siege, siege_.siege_site, siege_.siege_step
local siege_tier = siege_.siege_tier

-- Strip: scripts/strip.lua (split from here, 2026-10-18).
local strip_ = require("__landing-party__.scripts.strip").install(ops, {
  COOL_TICKS = COOL_TICKS, PLAYER_REACH = PLAYER_REACH, STRIP_COST = STRIP_COST, STRIP_DRILLS = STRIP_DRILLS,
  STRIP_GUARDS = STRIP_GUARDS, STRIP_TICKS = STRIP_TICKS, TURRETS = TURRETS, against_player = against_player,
  alert = alert, alive = alive, budget = budget, enemies = enemies, field = field, finish = finish,
  floor_of = floor_of, home = home, notify = notify, order_all = order_all, pool = pool, push_escort = push_escort,
  rd = rd, sneak_route = sneak_route, stance = stance})
local choose_strip, launch_strip, strip_site, strip_step = strip_.choose_strip, strip_.launch_strip, strip_.strip_site, strip_.strip_step

local function step(b, trace, army)
  local op = b.op
  if op.kind == "siege" then return siege_step(b, trace, army) end
  if op.kind == "strip" then return strip_step(b, trace, army) end
  local t = b.intel.targets[op.target]
  local n = alive(op)
  if n == 0 then return finish(b, "aborted", trace, army) end
  if game.tick - op.started > MAX_TICKS then return finish(b, "aborted", trace, army) end
  -- Its leader fell (ops.appoint).
  if op.leader_down then
    op.leader_down = nil
    if op.leader_mark and op.leader_mark.valid then op.leader_mark.destroy() end
    b.leaders_lost = (b.leaders_lost or 0) + 1
    -- Serenity regroups once a raid: a second leader lost, it falls back home too (the factory scenario's engaged player
    -- killed each new leader as it rose: 63 regroups, a raid that never broke).
    if (shared.CORPS[b.corp].temper or {}).soft_only or op.regrouping then
      trace(b, string.format("raid: its %s fell; the raid %s home with %d", op.regrouping and "second leader" or "foreman",
        op.regrouping and "falls back" or "breaks and runs", n))
      local done = finish(b, "fled", trace, army)
      if (shared.CORPS[b.corp].temper or {}).soft_only then ops.setback(b, "a raid broken") end
      b.broken = (b.broken or 0) + 1
      do return done end
    end
    ops.appoint(b, op)
    op.phase, op.phase_at, op.regrouping = "stage", game.tick, true
    order_all(op.members, {type = defines.command.go_to_location, destination = op.staging, radius = 8,
      distraction = defines.distraction.by_damage})
    trace(b, string.format("raid: its leader fell; it falls back to %.0f,%.0f in order with %d, a new leader up", op.staging[1],
      op.staging[2], n))
    b.regrouped = (b.regrouped or 0) + 1
    return
  end
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
        -- Regrouping after its leader fell (ops.appoint), it goes in again with what it has: it had looked once.
        if want > n and not op.regrouping and not (t.owner and against_player(t.owner) and ladder(t.owner, b.force) >= 3) then
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
          local cmd, thief = thief_cmd(b, t, pos, game.surfaces[b.surface])
          op.thieving = thief
          table.insert(cmds, cmd)
          trace(b, string.format("raid sneaks in by %d waypoints with %d of %d%s", #op.route, n, op.launched,
            thief and ", to take what it can carry" or ""))
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
          local cmd, thief = thief_cmd(b, t, pos, game.surfaces[b.surface])
          op.thieving = thief
          table.insert(cmds, cmd)
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
      turrets = surface.count_entities_filtered{position = pos, radius = DEFENCE_RADIUS, force = shared.NEST_FORCES, type = "turret"}
      left = surface.count_entities_filtered{position = pos, radius = 16, force = shared.NEST_FORCES, type = "unit-spawner"}
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
    if op.loot then op.last_pos = {x = pos[1] or pos.x, y = pos[2] or pos.y} end
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
    -- Thieves (thief_cmd): each idle one walks to the nearest machine still to take, not to shoot it.
    if op.thieving then
      local goods = t and surface.find_entities_filtered{position = pos, radius = 16, type = DISMANTLE_TYPES, force = t.owner} or {}
      for _, u in ipairs(op.members) do
        if u.valid and not busy(u) and #goods > 0 then
          local e = surface.get_closest(u.position, goods)
          u.commandable.set_command{type = defines.command.go_to_location, destination = e.position, radius = 3,
            distraction = defines.distraction.by_damage}
        end
      end
      return
    end
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
  local r = CLEAR_GUARD + 6
  for _, u in ipairs(op.members) do
    if u.valid and (u.position.x - op.site[1]) ^ 2 + (u.position.y - op.site[2]) ^ 2 > r * r then
      u.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = {{type = defines.command.go_to_location, destination = op.site, radius = 6,
          distraction = defines.distraction.none},
          {type = defines.command.wander, radius = 5, distraction = defines.distraction.by_damage}}}
    end
  end
end
-- Cuts: scripts/cuts.lua (split from here, 2026-10-18).
local cuts_ = require("__landing-party__.scripts.cuts").install(ops, {
  home = home, power = power, stance = stance})
local CUT_TICKS, survey_power = cuts_.CUT_TICKS, cuts_.survey_power
-- Answers: scripts/answers.lua (split from here, 2026-10-18).
local answers_ = require("__landing-party__.scripts.answers").install(ops, {
  ANSWER_COOLDOWN = ANSWER_COOLDOWN, SIEGE_TIERS = SIEGE_TIERS, defence = defence, field = field, launch = launch,
  launch_siege = launch_siege, needed = needed, sense = sense, siege_site = siege_site, siege_tier = siege_tier,
  stance = stance, tune = tune})
local answer = answers_.answer

function ops.tick(b, tick, trace, army)
  if storage.ops_off then return end
  ops.init(b)
  if tick % 60 == 30 then siege_leash(b) end
  if tick % 600 == 300 then stand_down(b) end
  if tick % SENSE_TICKS == (b.id * 97) % SENSE_TICKS then scan(b) end
  if tick % 3600 == (b.id * 53) % 3600 then ops.perimeter(b, tick) end
  if tick % 1800 == (b.id * 59 + 13) % 1800 then ops.sever(b) end
  if tick % 600 == 200 then field_sight(b) end
  if tick % SURVEY_TICKS == (b.id * 131 + 7) % SURVEY_TICKS then survey(b) end
  if tick % CUT_TICKS == (b.id * 173 + 11) % CUT_TICKS then survey_power(b, trace) end
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
    -- Then a hazard on its ground: the nests whose waves it keeps losing to (siege.lua).
    if ops.hazard_clear(b, trace, army) then return end
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
    if against_player(t.owner) and (kind ~= "strip" or (t.drills or 0) > 0) then
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
    op_owner = t and t.owner or nil, reprisal = b.reprisal and game.tick < b.reprisal.till and b.reprisal.owner or nil,
    reprisal_at = b.reprisal and (b.reprisal.since or b.reprisal.till - REPRISAL_TICKS), op_started = b.op and b.op.started,
    held = b.intel and b.intel.held and (function() local o = {} for k in pairs(b.intel.held) do o[k] = held_by(b, k) end
      return o end)() or nil,
    siege_tier = b.op and b.op.tier, answers = b.answers or 0, answered = b.answered, cuts_found = b.cuts_found or 0, recons = b.recons or 0, assaults = b.assaults or 0, assault_razed = b.assault_razed or 0,
    convoys_left = b.op and b.op.convoys_left, loaded = b.op and b.op.loaded, mortars = b.op and b.op.mortars and #b.op.mortars or 0,
    shells_fired = b.op and b.op.shells_fired, siege_phase = b.op and b.op.kind == "siege" and b.op.phase or nil,
    looted = b.looted or 0, carrying = b.op and b.op.loot and b.op.loot.items or 0, works = b.op and b.op.works and #b.op.works or 0, clearances = b.clearances or 0,
    hazards = b.hazards or 0, biter_losses = b.biter_losses or 0,
    leader = b.op and b.op.leader and b.op.leader.valid and b.op.leader.unit_number or nil, phase = b.op and b.op.phase,
    leaders_lost = b.leaders_lost or 0, broken = b.broken or 0, regrouped = b.regrouped or 0, dismantled = b.dismantled or 0,
    overflights = b.overflights or 0,
    route = b.op and b.op.route and #b.op.route or nil, breach_at = b.op and b.op.breach_at, route_points = b.op_route,
    breached = b.op and b.op.breached,
    sieges = b.sieges or 0, strips = b.strips or 0, stripped = b.stripped or 0, mortar = b.op and b.op.mortar and b.op.mortar.valid and
      {b.op.mortar.position.x, b.op.mortar.position.y} or nil}
end

return ops
