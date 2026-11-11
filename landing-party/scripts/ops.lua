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
local ram = require("__landing-party__.scripts.ram")
local tune = require("__landing-party__.scripts.tune")
local rd = require("__landing-party__.scripts.rd")
local know = require("__landing-party__.scripts.know")
local attempt = require("__landing-party__.scripts.attempt")
local tactics = require("__landing-party__.scripts.tactics")
local assault = require("__landing-party__.scripts.assault")
local ground = require("__landing-party__.scripts.ground")
local stance = require("__landing-party__.scripts.stance")
local pool = require("__landing-party__.scripts.pool")
local veterancy = require("__landing-party__.scripts.veterancy")
local jammer = require("__landing-party__.scripts.jammer")
local power = require("__landing-party__.scripts.power")
local threat = require("__landing-party__.scripts.threat")
local airraid = require("__landing-party__.scripts.airraid")

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
local PER_TURRET, BASE_FORCE = shared.PER_TURRET, 4
-- Desperate (the ladder's top rung against a player): its odds rule at this share of its mind's min_odds, not lifted.
-- Bolder, not blind (the counters and desperation consult, 2026-10-31): lifted, Kessler-Hayashi raided a laser wall with 4
-- to 40 again and again, lost all, and its learning (prices, the ladder) went for nothing.
local DESPERATE_ODDS, DESPERATE_SIEGE = 0.5, 2
ops.PER_TURRET = PER_TURRET
airraid.PER_TURRET = PER_TURRET
-- What shoots up within DEFENCE_RADIUS of a target (intel's sense; army.air_tilt).
function ops.air_near(s, pos, forces, corp) return airraid.weigh(s, pos, pos, forces, corp, DEFENCE_RADIUS) end
local THREAT_TICKS = 10 * 60 * 60     -- a static threat on the faction's ground stays a priority this long
local THREAT_BONUS = 10               -- value added to targets by it
-- Staging this far from the target: the longest reach of any turret (threat.far, from the prototypes: a flat 34 was a
-- laser's 24 and 10 to spare, inside a flamethrower's 30 and a modded turret's whatever) and 8 to spare.
local STAND_OFF = threat.far() + 8
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
local REACHED = 30                    -- an operation got to its target: a member came this near it (tactics.record)
local PLAYER_REACH = 31
local MORTAR_REACH = 36   -- its gun's range (data.lua: lp-mortar-gun, 36); at 35, out of a tesla's reach left it no site
local HOWITZER_REACH, HOWITZER_STAND = 98, 53   -- its reach, and how far from the nest it stands
local STUCK_TICKS = 60 * 60       -- a siege's hauler no nearer its site for this long is stuck
local CLEAR_RAILS = 8             -- railgunners a clearance waits for (its only guards; six could not hold, the user)
-- A clearance's guards shoot biters this near its pieces, and its site is out of every worm's reach by this more (at 24
-- round a site just out of reach, guards met the worms).
local CLEAR_GUARD = 12
-- The railgunners a clearance waits for, by the biters' evolution on its surface (the user, 2026-11-11: "some scaling to
-- KH strength based on biter evolution"): what it brings, never hidden health or damage (tiers' damage went as "a hidden
-- evolution factor by another name", 2026-10-13). CLEAR_RAILS, 6 more at full evolution, 4 more with a howitzer (a big
-- worm's nest; hazard worm: the waves broke its howitzer at the site and it waited half an hour for the next).
function ops.clear_rails(surface, piece)
  local f = game.forces.enemy
  local evo = f and f.get_evolution_factor(surface) or 0
  return CLEAR_RAILS + math.floor(6 * evo + 0.5) + (piece == "lp-howitzer" and 4 or 0)
end
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
  -- A mind without reprisals (a thief does not send punitive raids into a fortress: rivals, 2026-10-24) remembers its
  -- grievance (know.lua) and goes on as it was.
  if ((shared.CORPS[b.corp] or {}).mind or {}).reprisals == false then return end
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
local MARK_RADIUS = shared.CLAIM_MARK_RADIUS
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

-- Whether a corporation's temper lets it go for this target at all; by air (air), what its turrets reach on the ground
-- (exposure) is not asked: a thief flies over a wall (the user, 2026-11-10: "Grubstake should get air raids indeed"),
-- and choose holds it to what shoots up instead (its max_exposure, of the air defence).
local function temper_allows(b, t, air)
  if not against_player(t.owner) then
    -- A soft-only corporation keeps off a rival's guarded ground as off the player's (the system sim, 2026-10-23:
    -- Grubstake raided Kessler-Hayashi's walls and flamers 2 to 6 times in two hours and lost 4 to 78 units to it, 0 to
    -- 8 the other way): its rivals' drills, pylons and convoys, not their fortress. No ladder for a rival: 1.0 holds.
    -- (The higher of its exposure and defence: a rival's exposure is often 0, and its depot of defence 1.6 was raided.)
    local cap_ = ((shared.CORPS[b.corp] or {}).mind or {}).max_exposure
    if cap_ and not air and math.max(t.exposure or 0, t.defence or 0) > cap_ then return false end
    return true
  end
  if t.pos and ops.marked(b, t.pos) then return false end
  -- A staged hold (debug_truce, tests and films only): no raid on that player while it lasts; a battery shelling it is
  -- answered regardless of temper (counter-battery provokes anyway); else the stance (a provoked_only corporation once provoked).
  if stance.standing(b.corp, t.owner) == "truce" then return false end
  if battery(t) then return true end
  if not stance.may(b.corp, t.owner, "raid") then return false end
  if not ops.thief_hours(b) then return false end
  if ops.camp_hurt(b) then return false end
  local temper = shared.CORPS[b.corp].temper or {}
  -- Soft: what the player's turrets reach (exposure), up to 1.0 and LADDER_SOFT once the ladder relaxes it; at its top
  -- rung (cost no object) nothing (at a megabase every exposed spot was over 3, and nothing was ever razed, visit).
  local rung = ladder(t.owner, b.force)
  -- How much defence it will go up against (its mind's max_exposure; was the temper's soft_only at 1.0), relaxed to
  -- LADDER_SOFT from the first rung and lifted at the top.
  local cap_ = ((shared.CORPS[b.corp] or {}).mind or {}).max_exposure
  if cap_ and not air and rung < 3 and (t.exposure or t.defence or 0) > (rung >= 1 and math.max(cap_, LADDER_SOFT) or cap_) then return false end
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
-- Whether its raids weigh their way in: a mind that does (mind.way_in: Grubstake, the thief who goes round a wall;
-- Kessler-Hayashi's, weighing it, went quiet, and is to bring the force instead), or all with debug_tune way_in = true;
-- none with way_in = false.
function ops.weighs_way(b)
  if storage.way_in ~= nil then return storage.way_in end
  return ((shared.CORPS[b.corp] or {}).mind or {}).way_in == true
end
local function defence(b, t)
  local units = (t.units and game.tick - (t.units_at or 0) < UNITS_TICKS) and t.units or 0
  -- The way in when it outweighs the target's own (intel's ops.way_in; ops.weighs_way).
  local guns = ops.weighs_way(b) and math.max(t.defence or 0, t.way or 0) or (t.defence or 0)
  return (guns + (t.resist or 0) + units + math.floor(markers_near(b, t.pos, DEFENCE_RADIUS) / 3)
    + held_by(b, t.owner)) / rd.strength(b.corp, t.dmg)
end

local function needed(d) return math.ceil(PER_TURRET * d - 1e-9) + BASE_FORCE end

-- Its defence against fliers (airraid.lua): what shoots up on the straight way in and round the target, its mobile
-- defenders as on foot, over the corporation's strength. Weighed again after AIR_TICKS, at most AIR_NEW a choice (each
-- weighing looks along 400 tiles of line).
local AIR_TICKS, AIR_NEW = 10 * 3600, 4
local function air_defence(b, t, quota)
  if not t.air or game.tick - (t.air_at or 0) > AIR_TICKS then
    if quota.n <= 0 then return nil end
    quota.n = quota.n - 1
    local h = b.lander and b.lander.valid and b.lander.position or b.origin
    if not h then return nil end
    t.air, t.air_way = airraid.route(game.surfaces[b.surface], {h.x, h.y}, t.pos, t.owner and game.forces[t.owner] or enemies(game.forces[b.force]),
      b.corp, DEFENCE_RADIUS)
    t.air_at = game.tick
  end
  local units = (t.units and game.tick - (t.units_at or 0) < UNITS_TICKS) and t.units or 0
  return (t.air + units) / rd.strength(b.corp, t.dmg)
end

-- Its odds against a defence (the faction AI's chance of winning; docs/reviews/2026-10-23-faction-ai-audit.md): the
-- force it can send over the force that defence needs, r, and the odds r^2 / (1 + r^2) (0.5 at an even match, 0.8 at
-- twice). A corporation commits at its mind's min_odds and discounts a target by odds^caution (they replaced a hard
-- "needed <= what it can field"), and by what it would cost, (1 + defence)^loss_aversion: odds alone made every
-- target it could win look alike, and Kessler-Hayashi sent 41 at a Grubstake generator of defence 10.6 and took 108
-- of its buildings in 40 minutes (rivals, 2026-10-23).
local function odds(avail, d)
  local r = avail / math.max(1, needed(d))
  return r * r / (1 + r * r)
end
ops.odds = odds
local function mind_of(b) return (shared.CORPS[b.corp] or {}).mind or {min_odds = 0.5, caution = 1, loss_aversion = 1.5} end
-- Whether a desperate raid of n against defence d clears its odds at DESPERATE_ODDS of its min_odds.
function ops.desperate_ok(b, n, d) return odds(n, d) >= mind_of(b).min_odds * DESPERATE_ODDS - 1e-9 end

-- Why a target matters now (the faction AI's relevance, one place for what were seven multipliers in choose): each a
-- named weight a corporation's mind may set (shared.CORPS[corp].mind.weights), these the defaults.
--   pressure     a player's target while the floor holds (no op against it lately) or its ladder has climbed
--   battery      artillery shelling it
--   desperate    the ladder's top rung against that player
--   distracted   a rival's or nest's target while pressed against a player
--   ground       a player's building on its own claimed ground, at war
--   grudge       grievance against the owner (know.lua): 1 + grievance / grudge, at most grudge_max (a reprisal: four
--                lost Line troopers, 40 parts, made x5, as the reprisal's fixed weight did; now buildings lost count too,
--                and it is the faction's, not one camp's)
local LOOT_CAP = 24   -- a cell's carry-off worth (WORTH) that counts in full: eight drills
local WEIGHTS = {pressure = 3, battery = 10, desperate = 10, distracted = 0.2, ground = 2, grudge = 10, grudge_max = 5}
local function relevance(b, t, c)
  -- A mind sets the weights it differs on; the rest are these.
  local own = mind_of(b).weights or {}
  local w = setmetatable({}, {__index = function(_, k) local v = own[k]; if v == nil then v = WEIGHTS[k] end; return v end})
  local r = 1
  if c.player and (c.floor or c.rung >= 1) then r = r * w.pressure end
  if battery(t) then r = r * w.battery end
  if c.desperate then r = r * w.desperate end
  if not c.player and c.pressed and not reprisal(b, t) then r = r * w.distracted end
  if c.ground then r = r * w.ground end
  if t.owner then r = r * math.min(w.grudge_max, 1 + know.grievance(b.corp, t.owner) / w.grudge) end
  -- An overdue bill's collection (ledger.lua): the polluter's ground.
  if ops.collect_weight then r = r * ops.collect_weight(b, t) end
  return r
end

ops.relevance = relevance
ops.FLOOR_TICKS = FLOOR_TICKS
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
  -- Its fliers at home: by air only with AIRRAID.MIN at least (airraid.lua).
  local fliers, air_worth = airraid.fliers(b)
  local by_air = not storage.air_off and #fliers >= airraid.MIN
  if storage.air_trace then log(string.format("AIRDBG b%d fliers %d worth %.1f by_air %s", b.id, #fliers, air_worth, tostring(by_air))) end
  local air_budget = {n = AIR_NEW}
  local mode
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
    -- (Its temper by ground and by air apart: a guarded target a thief would not walk into it may still fly at.)
    local ground_ok = temper_allows(b, t)
    local air_only = not ground_ok and by_air and temper_allows(b, t, true)
    if not ground_ok and not air_only then held = true end
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
      local mind = mind_of(b)
      local p = odds((battery(t) or threat_bonus(b, t) > 0) and cap(b, army) or max_field, d)
      -- (On foot below its odds, it may still go by air: weighed both ways, s 0 for a way it cannot take.)
      local on_foot = ground_ok and p >= mind.min_odds * (desperate and DESPERATE_ODDS or 1) - 1e-9
      if on_foot or by_air then
        local dist = math.sqrt((t.pos[1] - h.position.x) ^ 2 + (t.pos[2] - h.position.y) ^ 2)
        local ground = player and b.claim_radius and not storage.strangle_off and stance.standing(b.corp, t.owner) == "enemy"
          and (t.pos[1] - b.origin.x) ^ 2 + (t.pos[2] - b.origin.y) ^ 2 <= b.claim_radius ^ 2
        local rel = relevance(b, t, {player = player, floor = floor, rung = player and ladder(t.owner, b.force) or 0,
          desperate = desperate, pressed = pressed, ground = ground})
        local function score(pp, dd)
          return (t.value * (t.line and shared.LINE_WORTH or 1) + threat_bonus(b, t)) * pp ^ mind.caution
            / (1 + dd) ^ mind.loss_aversion / (1 + dist / 300) / (1 + (t.line and 0 or t.tried)) * rel
        end
        local s = on_foot and score(p, d) or 0
        -- A thief's eye (mind.loot, with the prowl): a cell by what can be carried off from it, not only its most valuable
        -- building (a mine read as its power pole, 5, below a substation, 6; its drills were never taken, 2026-11-01).
        local thief_eye = (storage.prowl ~= false and mind.loot and t.loot) and (1 + mind.loot * math.min(t.loot, LOOT_CAP) / LOOT_CAP) or 1
        s = s * thief_eye
        local m
        -- By air (airraid.lua): its fliers' odds against what shoots up, and what fliers are for (SNIPE) the more.
        local da = by_air and t.owner ~= "enemy" and air_defence(b, t, air_budget)
        -- (Over a wall its temper keeps it off on foot, a thief flies only where little shoots up: its max_exposure,
        -- of the air defence now.)
        if da and air_only and da > (mind.max_exposure or math.huge) then da = nil end
        if storage.air_trace then log(string.format("AIRDBG b%d %s %s on_foot %s p %.2f d %.1f s %.3f air %s worth %.1f n %d", b.id, key, t.kind, tostring(on_foot), p, d, s, tostring(da), air_worth, #fliers)) end
        if da then
          local pa = odds(air_worth, da)
          if pa >= mind.min_odds - 1e-9 then
            -- (A thief's eye by air too, what it can carry off.) (By air where that alone is clearly the better way, then worth SNIPE more among targets: weighed with it,
            -- a radar went by air whatever shot up round it, airraid aa.)
            local sa = score(pa, da) * thief_eye
            if sa > s * airraid.EDGE then
              local proto = prototypes.entity[t.kind]
              s, m = sa * ((proto and airraid.SNIPE[proto.type]) or 1), "air"
            end
          end
        end
        if s > 0 and (not bs or s > bs) then best, bs, mode = key, s, m end
      end
    end
  end
  return best, bs, mode
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

-- Every gate of its camp asked open for `ticks`, before a departure's orders. A unit plans its path when ordered and
-- takes a shut gate for wall (scenario wayout: none out); army.lua opens a gate only for a unit within 5 tiles of it,
-- which a unit standing back in the yard never was. Returns how many.
-- Not a gate across a rail (the cordon's, which stop the player's trains: opened, a train ran past the line, scenario
-- cordon rail), nor any while gates are off (tests).
local RAILS = {"straight-rail", "half-diagonal-rail", "curved-rail-a", "curved-rail-b"}
local function open_gates(b, ticks)
  local n = 0
  if storage.gates_off then return 0 end
  if b.lander and b.lander.valid then
    local s = b.lander.surface
    for _, g in pairs(s.find_entities_filtered{position = b.lander.position,
      radius = (b.claim_radius or 150) + 60, type = "gate", force = b.lander.force}) do
      if s.count_entities_filtered{position = g.position, radius = 1, type = RAILS, limit = 1} == 0 then
        g.request_to_open(g.force, ticks); n = n + 1
      end
    end
  end
  return n
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

-- The howitzer truck and its howitzer, one for the other (the user, 2026-10-23: "it would become a building once
-- deployed"): deployed, the truck (a siege's hauler) gives way to the turret where it stood, facing as it faced;
-- packing up, the turret gives way to the truck. Health goes across as a share.
local TRUCK_PACK = 15 * 60
local function truck_down(op)
  local tr = op.hauler
  local d = math.floor((tr.orientation or 0) * 4 + 0.5) % 4
  local out = {pos = {tr.position.x, tr.position.y}, dir = d * 4, share = tr.health / tr.max_health}
  tr.destroy()
  return out
end
local function truck_up(b, piece)
  local s, force, pos = piece.surface, piece.force, {piece.position.x, piece.position.y}
  local share = piece.health / piece.max_health
  piece.destroy()
  local name = shared.variant(b.corp, "lp-howitzer-truck")
  local p = s.find_non_colliding_position(name, pos, 10, 0.5) or pos
  local tr = s.create_entity{name = name, position = p, force = force}
  if tr then tr.health = math.max(1, share * tr.max_health) end
  return tr
end
-- The piece the truck folds back into: the clearance's howitzer, or the siege's beside its mortars.
local function truck_piece(op)
  if op.howitzer and op.howitzer.valid then return op.howitzer end
  local m = op.mortars and op.mortars[1] or op.mortar
  if op.piece == "lp-howitzer" and m and m.valid then return m end
end

local function finish(b, outcome, trace, army)
  local op = b.op
  local h = home(b)
  -- Home on its wheels: the howitzer packs into its truck, which drives home as the hauler.
  if op.truck and not (op.hauler and op.hauler.valid) then
    local piece = truck_piece(op)
    if piece then
      if piece == op.howitzer then op.howitzer = nil end
      op.hauler = truck_up(b, piece)
    end
  end
  if op.mortar and op.mortar.valid then op.mortar.destroy() end
  for _, m in ipairs(op.mortars or {}) do if m.valid then m.destroy() end end
  -- (And a drop siege's guns still being assembled: siege.lua's deploy.)
  for _, m in pairs(op.kits or {}) do if m.valid then m.destroy() end end
  if op.howitzer and op.howitzer.valid then op.howitzer.destroy() end
  if ops.site_dome_down then ops.site_dome_down(b, op) end
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
      t.defence = math.max(t.defence or 0, (ops.weigh(game.surfaces[b.surface], t.pos, enemies(game.forces[b.force]), nil, b.corp)))
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
      -- (In one wreck, mined once: spilled over the ground until 2026-11-03.)
      local stacks = {}
      for _, g in pairs(op.loot.goods) do
        if g.count > 0 then stacks[#stacks + 1] = {name = g.name, count = g.count, quality = g.quality} end
      end
      if #stacks > 0 then shared.wreck(s, at, stacks) end
      trace(b, "raid lost; its loot spilled")
    end
  end
  for _, e in ipairs(op.works or {}) do if e.valid then e.destroy() end end
  if outcome == "done" or outcome == "spent" or outcome == "claimed" then b.ops_done = b.ops_done + 1 else b.ops_aborted = b.ops_aborted + 1 end
  -- Its losing streak (the user, 2026-11-04: stop after failures in a row): operations against a player that failed one
  -- after another, whatever their target; one done, or anything razed (control.lua), ends it. war.lua stands down on it.
  local tt_ = b.intel.targets[op.target]
  if tt_ and against_player(tt_.owner) and not op.clearance then
    if outcome == "done" or outcome == "spent" or outcome == "claimed" then b.fail_streak = 0
    else b.fail_streak = (b.fail_streak or 0) + 1 end
  end
  local lost = op.launched - alive(op)
  b.next_op = game.tick + tune.sooner(b.corp, (outcome == "done" or outcome == "spent" or outcome == "claimed") and GAP_DONE
    or GAP_ABORTED)
    + math.floor(lost / 5) * GAP_PER_5_LOST
  if op.clearance then b.next_op = game.tick + 3600 end
  -- A reprisal still owed keeps its pace: the losses that called it were often this op's own raiders, and its end set
  -- the next op ten minutes off (reprisal, 2026-10-23: paid back 13.6 minutes later).
  if b.reprisal and game.tick < b.reprisal.till then
    b.next_op = math.min(b.next_op, math.max(game.tick, b.reprisal.since + REPRISAL_SOON))
  end
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
  -- Its attempt, in its corporation's memory as Synthexis's are in its own (tactics.lua): what it sent and lost in mediums,
  -- what it razed, in if it razed anything, the defence it met. Read back by the ladder in its choice (ops.tick).
  local tpos = t and t.pos or (op.target_pos)
  if tpos and op.measured then
    local launched = math.max(1, op.launched or 1)
    local got = math.max(0, (b.razed or 0) - (op.razed0 or b.razed or 0))
    -- (The share of its units lost over the operation that died to area damage: the signal every attacker reads, as
    -- Synthexis's waves' (herd.area_of); the adaptive tactics consult, 2026-11-05.)
    local all, area = 0, 0
    for _, l in ipairs(know.losses(b.corp, game.tick - (op.started or game.tick))) do
      if l.unit then
        all = all + (l.value or 1)
        if l.damage and shared.AREA_DAMAGE[l.damage] then area = area + (l.value or 1) end
      end
    end
    local e = {sent = op.sent_worth or launched,
      spent = (op.sent_worth or launched) * (launched - alive(op)) / launched, got = got, inside = got > 0, sig = op.sig,
      -- (Got there: a member within REACHED of its target, a siege that fired, anything razed. Its attack begun was not
      -- enough: a raid of 2 attacked from its staging and died to the nests on its 7 waypoints, none near.)
      reached = ((op.closest or math.huge) <= REACHED or (op.shells_fired or 0) > 0 or got > 0) and true or false,
      rams = op.kind == "siege" and op.tier or nil, breach = {tpos[1], tpos[2]}, area = all > 0 and area / all or nil}
    tactics.record(b.corp, (t and t.owner) or op.owner or "player", tpos, op.kind, e)
    -- (And under the way its assault took at a closed wall, its menu's own record: assault.lua.)
    if op.way_method then
      e.rams = nil
      tactics.record(b.corp, (t and t.owner) or op.owner or "player", tpos, op.way_method, e)
    end
  end
  -- Its guns' prices from what they cost it (know.learn_price, as Synthexis's): where it got there, the units lost to each
  -- gun type over how many of them stood at its target; a sample a least when none came home; a small operation's moves a
  -- price less (its size over 30).
  if tpos and op.guns_at and (op.closest or math.huge) <= REACHED then
    local lost_to = {}
    for _, l in ipairs(know.losses(b.corp, game.tick - (op.started or game.tick))) do
      if l.unit and l.killer and op.guns_at[l.killer] then lost_to[l.killer] = (lost_to[l.killer] or 0) + 1 end
    end
    local owner = (t and t.owner) or op.owner or "player"
    for name, n in pairs(op.guns_at) do
      know.learn_price(b.corp, owner, name, (lost_to[name] or 0) / n, op.gun_prior[name], alive(op) == 0,
        math.min(1, (op.launched or 1) / 30))
    end
  end
  b.ops_log = b.ops_log or {}
  -- The owner as at launch (a target destroyed is forgotten, and its raid read as at nobody: nests).
  table.insert(b.ops_log, {op = op.kind, kind = t and t.kind or "gone", owner = t and t.owner or op.owner, outcome = outcome,
    launched = op.launched, started = op.started,
    back = alive(op), shells = op.shells_fired, site = op.site, cut = op.cut})
  if #b.ops_log > 10 then table.remove(b.ops_log, 1) end
  trace(b, string.format("%s %s: %d of %d came back (target %s; razed %d, %d to %d)", op.kind, outcome, alive(op), op.launched,
    t and t.kind or "gone", (b.razed or 0) - (op.razed0 or b.razed or 0), op.razed0 or -1, b.razed or -1))
  b.op = nil
end

-- Staging, routes and breaches: scripts/routing.lua (split from here).
local R = require("__landing-party__.scripts.routing").install(ops, {enemies = enemies, ladder = ladder,
  STAND_OFF = STAND_OFF, TURRETS = TURRETS})
local outside, sneak_route, push_escort, breach_point, wall_on_line = R.outside, R.sneak_route, R.push_escort,
  R.breach_point, R.wall_on_line
local PUSH_VALUE, PUSH_CROSSINGS, SNEAK_BOX = R.PUSH_VALUE, R.PUSH_CROSSINGS, R.SNEAK_BOX
-- (Synthexis stages its waves as raids stage, herd.lua through control.lua.)
ops.outside = outside
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
ops.STEAL_WORTH = WORTH
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
      shared.wreck(s, ent.position, {{name = g.name, count = share, quality = g.quality}})
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
-- What a raid at t should be: what got in there lately (tactics.best_size: its size in mediums, in its soldiers), before
-- the formula a point of defence (needed), as Synthexis copies the siege that worked where it worked (its raids at a laser
-- wall sized by the formula alone, one share a point set against gun turrets; the lane, 2026-10-31).
-- What a wall its owner's robots put back asks of a raid (a corporation with orbital intelligence; the user, 2026-11-03:
-- "walls should probably count for something"): enough of its infantry to break a piece of the first wall on its way in
-- before the robots have it back. Read: the piece's health, its infantry's damage to it (threat.unit_dps), the robots'
-- way to it (the nearest powered roboport covering it with robots to send, the construction robot's speed). A wall no
-- powered roboport covers asks nothing more (time only): a cut lane's walls, robots dark, are cheap again (blackout).
-- With walls priced flat in the defence, a raid of 4 at a mended wall lost the race (mended serenity), and once walls
-- weighed a cut laser line read dearer than the poles round it (blackout, 0.2.160).
local WALL_LOOK = 60
function ops.mended_floor(b, t)
  if not (b.origin and t and t.pos and t.owner and (shared.CORPS[b.corp] or {}).orbital_intel) then return 0 end
  local s = game.surfaces[b.surface]
  local foes = game.forces[t.owner]
  if not foes then return 0 end
  local dx, dy = t.pos[1] - b.origin.x, t.pos[2] - b.origin.y
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 2 then return 0 end
  local w
  for d = math.max(0, len - WALL_LOOK), len - 1 do
    w = s.find_entities_filtered{position = {b.origin.x + dx / len * d, b.origin.y + dy / len * d}, radius = 0.8,
      type = {"wall", "gate"}, force = foes, limit = 1}[1]
    if w then break end
  end
  if not w then return 0 end
  -- (The robots' trip, as a siege's wall fire reads its race: assault.mend_ticks.)
  local back = assault.mend_ticks(s, foes, w)
  if not back then return 0 end
  local proto = shared.variant(b.corp, rd.unit(b.corp, "lp-infantry"))
  local dps = threat.unit_dps(proto, w)
  if dps <= 0 then return 0 end
  return math.ceil(w.max_health / (dps * back))
end

function ops.raid_want(b, t)
  local want = math.max(needed(defence(b, t)), ops.mended_floor(b, t))
  if t and t.pos then
    local near = tactics.history_near(b.corp, t.owner or "player", t.pos, "raid",
      attempt.sig(game.surfaces[b.surface], t.owner or "player", t.pos))
    local r = tactics.attempt(b.corp, t.owner or "player", t.pos, "raid")
    if r then for _, h in ipairs(r.hist or {}) do if not h.breach then near[#near + 1] = h end end end
    local proven = tactics.best_size({hist = near}, 1, nil)
    if proven then
      local per = attempt.worth(shared.variant(b.corp, "lp-infantry"))
      want = math.max(1, math.ceil(proven / math.max(0.1, per)))
    end
  end
  return want
end

-- An air raid (airraid.lua; ops.choose weighed it): its fliers at home, as many as its air defence needs and at least
-- airraid.MIN, straight at the target (each flier on the target building itself first, then round it), home round the
-- worms after (finish: op.overflight).
local function launch_air(b, key, trace, army)
  local t = b.intel.targets[key]
  local h = home(b)
  local s = game.surfaces[b.surface]
  local da = t.air and air_defence(b, t, {n = 0}) or 0
  local want = needed(da)
  local inf = attempt.worth(shared.variant(b.corp, "lp-infantry"))
  local members, worth = {}, 0
  for _, u in ipairs(pool.take(b, #b.garrison, 0, function(u) return airraid.is_flier(u.name) end)) do
    -- (Till its worth covers what it needs, and airraid.MIN at least: two drones covered a raid's 4, and under the
    -- minimum it never went, airraid.)
    if worth < want or #members < airraid.MIN then
      members[#members + 1] = u
      worth = worth + attempt.worth(u.name) * veterancy.scale(u) / math.max(0.1, inf)
    else
      pool.give_one(b, u)
    end
  end
  if #members < airraid.MIN then
    for _, u in ipairs(members) do pool.give_one(b, u) end
    return false
  end
  local target = s.find_entities_filtered{name = t.kind, position = t.pos, radius = 1.5, limit = 1}[1]
  local cmds = {}
  -- (Its way's turns first, airraid.route: round what shoots up, not straight over it.)
  for _, p in ipairs(t.air_way or {}) do
    cmds[#cmds + 1] = {type = defines.command.go_to_location, destination = {p[1], p[2]}, radius = 6,
      distraction = defines.distraction.none}
  end
  -- A thief's fliers (Grubstake's scrap drones; the user, 2026-11-10: "They could perhaps do some air theft too?") land
  -- among what it can carry and take it (ops.loot, the attack phase, as on foot), shooting only what hits them; with
  -- nothing left, they attack (dismantle turns them).
  local tcmd, thief = thief_cmd(b, t, t.pos, s)
  if thief then
    cmds[#cmds + 1] = tcmd
  else
    if target then cmds[#cmds + 1] = {type = defines.command.attack, target = target, distraction = defines.distraction.none} end
    cmds[#cmds + 1] = {type = defines.command.attack_area, destination = {t.pos[1], t.pos[2]}, radius = 12,
      distraction = defines.distraction.by_anything}
  end
  order_all(members, {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = cmds})
  b.op = {kind = "raid", air = true, overflight = true, target = key, phase = "attack", members = members, launched = #members,
    staging = {h.position.x, h.position.y}, owner = t.owner, pos = {t.pos[1], t.pos[2]}, started = game.tick,
    phase_at = game.tick, kills_at = b.razed, last_kill = game.tick, razed0 = b.razed, attacked = true, thieving = thief}
  ops.appoint(b, b.op)
  alert(b, t, "lp.alert-raid")
  b.air_raids = (b.air_raids or 0) + 1
  if thief then b.air_thefts = (b.air_thefts or 0) + 1 end
  b.ops_launched = b.ops_launched + 1
  b.raids_sent = b.raids_sent + 1
  storage.threat_last = game.tick
  b.op.way = t.air_way
  trace(b, string.format("air raid on %s at %.0f,%.0f: %d fliers (worth %.1f) against air defence %.1f (on foot %.1f), %d turns%s",
    t.kind, t.pos[1], t.pos[2], #members, worth, da, defence(b, t), #(t.air_way or {}), thief and ", to take what it can carry" or ""))
  return true
end

local function launch(b, key, trace, army, opts)
  if opts and opts.air then return launch_air(b, key, trace, army) end
  local t = b.intel.targets[key]
  local h = home(b)
  local d = defence(b, t)
  local want = ops.raid_want(b, t)
  local n, reserve = field(b, army)
  local desperate = against_player(t.owner) and ladder(t.owner, b.force) >= 3
  local is_answer = opts and opts.answer
  if battery(t) or threat_bonus(b, t) > 0 or desperate or is_answer then n = n + reserve end
  -- Cost no object (the ladder): what the garrison has goes, however few.
  -- (Its reserve in and what it has sent, while that clears its odds at DESPERATE_ODDS; else it holds and saves.)
  if desperate then
    if not ops.desperate_ok(b, n, d) then return false end
    want = math.min(want, n)
  end
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
        if #air < 6 and (k == "lp-harrier" or k == "lp-scavenger" or k == "lp-laser-drone") then table.insert(air, table.remove(list, i)) end
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
  -- The ground it marches over, asked for now (ground.lua): by its first look at the staging point it is there.
  local s = game.surfaces[b.surface]
  local gen, from = {}, h.position
  for _, w in ipairs(route) do
    for _, c in ipairs(ground.corridor(s, from, w, 2)) do gen[#gen + 1] = c end
    from = w
  end
  for _, c in ipairs(ground.corridor(s, from, stage, 2)) do gen[#gen + 1] = c end
  local depart = {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = cmds}
  open_gates(b, STAGE_TICKS)
  order_all(members, depart)
  b.op_route = route
  b.op.depart, b.op.gen = depart, gen
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
  -- An overdue bill's collection (ledger.lua): the first raid on that player after it is the collection.
  if b.collect and t.owner == b.collect.owner and game.tick < b.collect.till and ops.on_collect then ops.on_collect(b) end
  if t.owner == "enemy" then
    for _, f in pairs(game.forces) do
      if #f.players > 0 then
        shared.notice(f, {"lp.clearing", shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", t.pos[1], t.pos[2],
          game.surfaces[b.surface].name)})
      end
    end
  end
  trace(b, string.format("raid on %s at %.0f,%.0f (value %d, defence %.1f, exposure %.1f, way in %.1f, rung %d): %d units stage at %.0f,%.0f",
    t.kind, t.pos[1], t.pos[2], t.value, d, t.exposure or -1, t.way or -1, t.owner and ladder(t.owner, b.force) or -1, #members, stage[1], stage[2]))
  return true
end

-- Siege: scripts/siege.lua (split from here, 2026-10-18).
local siege_ = require("__landing-party__.scripts.siege").install(ops, {
  ASSAULT_IDLE = ASSAULT_IDLE, CELL = CELL, CLEAR_GUARD = CLEAR_GUARD, CLEAR_RAILS = CLEAR_RAILS,
  COOL_TICKS = COOL_TICKS, DEFENCE_RADIUS = DEFENCE_RADIUS, DEPLOY_TICKS = DEPLOY_TICKS, FOOT = FOOT, SOLDIER = SOLDIER,
  HOWITZER_REACH = HOWITZER_REACH, HOWITZER_STAND = HOWITZER_STAND, MORTAR_REACH = MORTAR_REACH,
  NO_KILL_TICKS = NO_KILL_TICKS, PACK_TICKS = PACK_TICKS, PLAYER_REACH = PLAYER_REACH, RESUPPLY = RESUPPLY,
  SHELLS_CAP = SHELLS_CAP, SIEGE_COST = SIEGE_COST, SIEGE_GUARDS = SIEGE_GUARDS, SIEGE_MAX_TICKS = SIEGE_MAX_TICKS,
  SIEGE_SHELLS = SIEGE_SHELLS, SIEGE_TIERS = SIEGE_TIERS, STUCK_TICKS = STUCK_TICKS, TURRETS = TURRETS,
  TYPES = TYPES, against_player = against_player, alert = alert, alive = alive, battery = battery, budget = budget,
  defence = defence, enemies = enemies, field = field, finish = finish, floor_of = floor_of, home = home,
  jammer = jammer, needed = needed, order_all = order_all, pool = pool, push_escort = push_escort, rd = rd,
  sneak_route = sneak_route, stance = stance, threat_bonus = threat_bonus,
  TRUCK_PACK = TRUCK_PACK, truck_down = truck_down, truck_up = truck_up, truck_piece = truck_piece})
local choose_siege, launch_siege, siege_site, siege_step = siege_.choose_siege, siege_.launch_siege, siege_.siege_site, siege_.siege_step
function ops.siege_why(b, army) return siege_.siege_why(b, army) end
function ops.debug_siege_site(b, pos, owner) return siege_site(b, {pos = pos, owner = owner or "player"}) end
local siege_tier = siege_.siege_tier

-- Strip: scripts/strip.lua (split from here, 2026-10-18).
local strip_ = require("__landing-party__.scripts.strip").install(ops, {
  COOL_TICKS = COOL_TICKS, PLAYER_REACH = PLAYER_REACH, STRIP_COST = STRIP_COST, STRIP_DRILLS = STRIP_DRILLS,
  STRIP_GUARDS = STRIP_GUARDS, STRIP_TICKS = STRIP_TICKS, TURRETS = TURRETS, against_player = against_player,
  alert = alert, alive = alive, budget = budget, enemies = enemies, field = field, finish = finish,
  floor_of = floor_of, home = home, notify = notify, order_all = order_all, pool = pool, push_escort = push_escort,
  rd = rd, sneak_route = sneak_route, stance = stance})
local choose_strip, launch_strip, strip_site, strip_step = strip_.choose_strip, strip_.launch_strip, strip_.strip_site, strip_.strip_step

-- What it set out with, measured once as every attacker's is (attempt.lua): its members' worth in mediums, the defence at
-- its target, what it had razed before (tactics.record at its end).
local function measure(b, op)
  op.measured = true
  local sent = 0
  for _, m in ipairs(op.members or {}) do if m.valid then sent = sent + attempt.worth(m.name) end end
  op.sent_worth = sent
  op.razed0 = op.razed0 or b.razed
  local t = b.intel.targets[op.target]
  if t and t.pos then
    local s = game.surfaces[b.surface]
    op.sig = attempt.sig(s, t.owner or "player", t.pos)
    -- The guns at its target by name, and each one's weight by the formula (its prior when it learns their price).
    op.guns_at, op.gun_prior = {}, {}
    for _, e in ipairs(s.find_entities_filtered{position = t.pos, radius = DEFENCE_RADIUS, force = t.owner or "player",
      type = threat.FIRE}) do
      op.guns_at[e.name] = (op.guns_at[e.name] or 0) + 1
      if not op.gun_prior[e.name] then op.gun_prior[e.name] = PER_TURRET * (ops.weigh(s, e.position, t.owner or "player", 0.5) or 0) end
    end
  end
end

-- How near its nearest member has come to its target (op.closest, tiles): whether it got there (tactics.record).
local function closest(b, op)
  local t = b.intel.targets[op.target]
  if not (t and t.pos) then return end
  for _, m in ipairs(op.members or {}) do
    if m.valid then
      local d = math.sqrt((m.position.x - t.pos[1]) ^ 2 + (m.position.y - t.pos[2]) ^ 2)
      if not op.closest or d < op.closest then op.closest = d end
    end
  end
end

local function step(b, trace, army)
  local op = b.op
  if not op.measured then measure(b, op) end
  closest(b, op)
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
        -- Stalled at the first look, with its ground generated since it set out: ordered out again, its clock restarted
        -- (its first orders failed at once on ground not yet made, seed 1, 2026-10-24); called off at the next.
        if first and not closing and op.depart and not op.redone then
          local missing = ground.missing(game.surfaces[b.surface], op.gen)
          op.redone = true
          open_gates(b, op.stage_ticks or STAGE_TICKS)
          order_all(op.members, op.depart)
          op.phase_at, op.stage_dist, op.stage_waited = game.tick, nil, nil
          trace(b, string.format("raid stalled %.0f from its staging point (%d of %d chunks on its way still to be made): "
            .. "ordered out again", mean, missing, #(op.gen or {})))
          -- What it stands among (tracing only): its kinds, and the trees, cliffs, water and walls round them.
          if storage.trace then
            local s, kinds, cx, cy, m = game.surfaces[b.surface], {}, 0, 0, 0
            for _, u in ipairs(op.members) do
              if u.valid then
                kinds[u.name] = (kinds[u.name] or 0) + 1
                cx, cy, m = cx + u.position.x, cy + u.position.y, m + 1
              end
            end
            local at = {cx / math.max(1, m), cy / math.max(1, m)}
            local parts = {}
            for k, n in pairs(kinds) do parts[#parts + 1] = n .. " " .. k end
            trace(b, string.format("  stalled at %.0f,%.0f: %s; within 12: %d trees, %d cliffs, %d water tiles, %d walls",
              at[1], at[2], table.concat(parts, ", "), s.count_entities_filtered{position = at, radius = 12, type = "tree"},
              s.count_entities_filtered{position = at, radius = 12, type = "cliff"},
              s.count_tiles_filtered{position = at, radius = 12, collision_mask = "water_tile"},
              s.count_entities_filtered{position = at, radius = 12, type = {"wall", "gate"}}))
          end
          return
        end
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
        -- And the way in from where it stands (behind way_in): its leg to the target, read now.
        local guns = t.defence
        if ops.weighs_way(b) and op.staging then
          t.way = ops.way_in(s, op.staging, t.pos, foes, b.corp)
          guns = math.max(guns, t.way)
        end
        local want = needed((guns + (t.resist or 0) + t.units) / rd.strength(b.corp, t.dmg))
        -- Regrouping after its leader fell (ops.appoint), it goes in again with what it has: it had looked once.
        if want > n and not op.regrouping and not (t.owner and against_player(t.owner) and ladder(t.owner, b.force) >= 3) then
          rd.turned_back(b)
          trace(b, string.format("raid sees defence %.1f (its way in %.1f) and units %.1f at the target, needs %d, has %d: turns back", seen,
            t.way or 0, t.units, want, n))
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
      -- Each raider on a piece still standing: idle, wandering or its piece gone, it is told again. A dozer rams it
      -- (scripts/ram.lua: at its gun's 2 tiles it had stopped short and shot the wall like any gun, the user's trailer).
      for _, u in ipairs(op.members) do
        if u.valid and shared.kind_of(u.name) == "lp-dozer" then
          if not ram.busy(u) then ram.order(u, standing) end
        elseif u.valid and not busy(u) then
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
    -- (And sooner with its Elites in it: veterancy.abort_share.)
    local share = veterancy.abort_share(op.members, rd.has(b.corp, "prospector") and 0.7 or 0.5)
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
    -- (And when its strike asks, op.step_at: orbital.lua, at its paint and its fall.)
    if tick % 300 == 100 or (b.op.step_at and tick >= b.op.step_at) then
      b.op.step_at = nil
      step(b, trace, army)
    end
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
    local key, rs, rmode = choose(b, army)
    local ropts = rmode == "air" and {air = true} or nil
    if key and battery(b.intel.targets[key]) then return launch(b, key, trace, army, ropts) end
    -- Then the best of a raid, a siege and a strip, each weighed by what the corporation prefers (its mind's prefer;
    -- the faction AI's comparison, docs/reviews/2026-10-23-faction-ai-audit.md): a fixed order had a raid on a pylon
    -- always beat a siege on a factory block, and a thief strip before anything.
    local prefer = (b.armed and mind_of(b).armed_prefer) or mind_of(b).prefer or {raid = 1, siege = 0.5, strip = 1}
    local skey, ssite, ss, spiece = choose_siege(b, army)
    -- An armed camp sieges no player before its ground first reads clear (war.lua sets b.ground_clear, once): its first
    -- siege went out 1.8 minutes after landing, and its hauler died to the nests round it every time (fed nw,
    -- 2026-11-02). (10 minutes from its landing before, whatever stood there.)
    if skey and b.armed and not b.ground_clear and against_player((b.intel.targets[skey] or {}).owner) then
      skey = nil
    end
    local tkey, tsite, ts = choose_strip(b, army)
    -- (Desperate against a player: its siege weighs DESPERATE_SIEGE times as much, what it saves for.)
    local st_ = skey and b.intel.targets[skey]
    if st_ and against_player(st_.owner) and ladder(st_.owner, b.force) >= 3 then
      prefer = {raid = prefer.raid, siege = (prefer.siege or 0) * DESPERATE_SIEGE, strip = prefer.strip}
    end
    -- Each worth less where it failed lately (tactics.ladder: every attacker's), so the next method up has its turn.
    local function ladder(k, method)
      local t = k and b.intel.targets[k]
      if not (t and t.pos) then return 1 end
      return tactics.ladder(b.corp, t.owner or "player", t.pos, method,
        attempt.sig(game.surfaces[b.surface], t.owner or "player", t.pos), nil, nil, true)
    end
    local options = {}
    local lr, ls, lt = ladder(key, "raid"), ladder(skey, "siege"), ladder(tkey, "strip")
    -- (Set aside where it failed lately, tactics.LADDER_HOLD: it saves for the next method instead.)
    -- (Not a collection's (ledger.lua): an overdue bill is collected where it failed before; the hazard's collection was
    -- called and held there for the rest of the hour, 0.2.325.)
    local kt = key and b.intel.targets[key]
    local collecting = kt and ops.collect_weight and ops.collect_weight(b, kt) > 1
    if lr < tactics.LADDER_HOLD and not collecting then
      if key then trace(b, string.format("holds its raid at %s: it failed there lately (ladder %.2f)", key, lr)) end
      key = nil
    end
    -- (Its howitzer is the step past what failed there: not set aside by the ladder that called it, siege_plan.)
    if ls < tactics.LADDER_HOLD and spiece ~= "lp-howitzer" then skey = nil end
    if lt < tactics.LADDER_HOLD then tkey = nil end
    if key then options[#options + 1] = {"raid", (rs or 0) * (prefer.raid or 1) * lr} end
    if skey then options[#options + 1] = {"siege", (ss or 0) * (prefer.siege or 0) * ls} end
    if tkey then options[#options + 1] = {"strip", (ts or 0) * (prefer.strip or 0) * lt} end
    table.sort(options, function(x, y) return x[2] > y[2] end)
    if #options > 1 then
      local parts = {}
      for _, o in ipairs(options) do parts[#parts + 1] = string.format("%s %.2f", o[1], o[2]) end
      trace(b, "weighs " .. table.concat(parts, ", "))
    end
    local pick = options[1] and options[1][1]
    if pick == "raid" then launch(b, key, trace, army, ropts)
    elseif pick == "siege" then launch_siege(b, skey, ssite, trace, army, nil, nil, spiece)
    elseif pick == "strip" then launch_strip(b, tkey, tsite, trace, army) end
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
-- owner (tests and films: the trailer's corporations at war, 2026-11-04): a rival's structure nearest pos instead, that
-- force's (a corporation's), the operation as it would go against that rival.
-- Returns nil when launched, else why not (shown to the player).
function ops.force(b, kind, pos, trace, army, owner)
  ops.init(b)
  if b.op then return "busy with a " .. b.op.kind end
  local h = home(b)
  if not h then return "no depot" end
  local s = game.surfaces[b.surface]
  sense(b, s, pos, 60)
  local best, bd
  for key, t in pairs(b.intel.targets) do
    local whose = owner and t.owner == owner or (not owner and against_player(t.owner))
    if whose and (kind ~= "strip" or (t.drills or 0) > 0) then
      local d = (t.pos[1] - pos.x) ^ 2 + (t.pos[2] - pos.y) ^ 2
      if d <= 60 * 60 and (not bd or d < bd) then best, bd = key, d end
    end
  end
  if not best then
    if owner then return "no structure of " .. owner .. " within 60 tiles" end
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
  -- (A raid as its launch sizes it, ops.raid_want: by the defence alone, a forced raid fielded 4 where a mended wall
  -- asked 32, and launch, asking 32, sent none; mended serenity.)
  local want = (kind == "raid" and ops.raid_want(b, t) or SIEGE_GUARDS) + math.ceil(RESERVE * cap(b, army))
  local n = 0
  for _, u in ipairs(b.garrison) do if u.valid and u.type == "unit" and shared.kind_of(u.name) ~= "lp-hauler" then n = n + 1 end end
  local proto = shared.variant(b.corp, "lp-infantry")
  for _ = n + 1, want do
    -- Not inside a walled emplacement by the depot (army.spawn_point: a forced raid's hands were made in a scrap cannon's).
    local p = army.spawn_point(b, proto, {h.position.x, h.position.y + 4}, 20)
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
    reprisal_at = b.reprisal and (b.reprisal.since or b.reprisal.till - REPRISAL_TICKS), op_started = b.op and b.op.started, op_launched = b.op and b.op.launched,
    op_members = b.op and (function() local o = {} for _, u in ipairs(b.op.members or {}) do if u.valid then local c = u.commandable.command
      o[#o + 1] = {u.position.x, u.position.y, shared.kind_of(u.name), c and c.type or -1, c and c.commands and #c.commands or 0,
        u.commandable.moving_state, u.commandable.distraction_command and 1 or 0,
        (function() local d = u.commandable.distraction_command local tg = d and d.target
          return tg and tg.valid and (tg.name .. "@" .. math.floor(tg.position.x) .. "," .. math.floor(tg.position.y)) or (d and tostring(d.type)) or "" end)()} end end return o end)(),
    op_phase = b.op and b.op.phase, op_site = b.op and b.op.site, op_hold = b.op and b.op.hold, op_jump = b.op and b.op.jump,
    strike_center = b.op and b.op.strike_center or b.dev_strike and b.dev_strike.center,
    strike_paint = b.op and b.op.strike_paint or b.dev_strike and b.dev_strike.paint,
    strike_falling = b.op and b.op.strike_falling or b.dev_strike and b.dev_strike.falling,
    held = b.intel and b.intel.held and (function() local o = {} for k in pairs(b.intel.held) do o[k] = held_by(b, k) end
      return o end)() or nil,
    siege_tier = b.op and b.op.tier, answers = b.answers or 0, answered = b.answered, cuts_found = b.cuts_found or 0, recons = b.recons or 0, assaults = b.assaults or 0, assault_razed = b.assault_razed or 0,
    convoys_left = b.op and b.op.convoys_left, loaded = b.op and b.op.loaded, mortars = b.op and b.op.mortars and #b.op.mortars or 0,
    shells_fired = b.op and b.op.shells_fired, siege_phase = b.op and b.op.kind == "siege" and b.op.phase or nil, truck_packing = b.op and b.op.packing ~= nil,
    looted = b.looted or 0, carrying = b.op and b.op.loot and b.op.loot.items or 0, works = b.op and b.op.works and #b.op.works or 0, clearances = b.clearances or 0,
    hazards = b.hazards or 0, biter_losses = b.biter_losses or 0,
    leader = b.op and b.op.leader and b.op.leader.valid and b.op.leader.unit_number or nil, phase = b.op and b.op.phase,
    leaders_lost = b.leaders_lost or 0, broken = b.broken or 0, regrouped = b.regrouped or 0, dismantled = b.dismantled or 0,
    overflights = b.overflights or 0,
    air_raids = b.air_raids or 0,
    air_thefts = b.air_thefts or 0,
    air_tilt = b.air_tilt,
    route = b.op and b.op.route and #b.op.route or nil, breach_at = b.op and b.op.breach_at, route_points = b.op_route,
    breached = b.op and b.op.breached,
    way_method = b.op and b.op.way_method, wall_pieces = b.op and b.op.wall_pieces, way_open = b.op and b.op.way_open,
    sieges = b.sieges or 0, strips = b.strips or 0, stripped = b.stripped or 0, mortar = b.op and b.op.mortar and b.op.mortar.valid and
      {b.op.mortar.position.x, b.op.mortar.position.y} or nil}
end

return ops
