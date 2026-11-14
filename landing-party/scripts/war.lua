-- War footing and the war chest (docs/reviews/2026-10-15-pressure-ramp-consult.md; the user: "it's not good that only
-- the first raid does anything"). A settlement's units came only from its drop escort and its own parts; under fire its
-- parts went to rebuilding what the player's guns broke, and its garrison fell to nought for good. Two changes:
--   War footing: a settlement at war (it knows a player's buildings and its temper lets it go for them) and short of its
--   unit cap rebuilds only its generators and depots; its parts go to units first (army.produce).
--   The war chest: a share of each corporation's exports (CHEST_SHARE, capped at CHEST_CAP), and Grubstake's salvage.
--   Every RELIEF_TICKS a corporation sends one settlement at war, ladder rung 1 or more, RELIEF_PER_RUNG units a rung,
--   paid from the chest at RELIEF_MARKUP. Grubstake's come down in a pod behind the lander; Serenity's march as a relief
--   column from its nearest other settlement along a planned route (none: no relief), or, with no other settlement,
--   drop at the lander at half strength.
local shared = require("__landing-party__.shared")
local strategy = require("__landing-party__.scripts.strategy")
local pods = require("__landing-party__.scripts.pods")
local tune = require("__landing-party__.scripts.tune")
local ops = require("__landing-party__.scripts.ops")
local army = require("__landing-party__.scripts.army")
local rng = require("__landing-party__.scripts.rng")
local base = require("__landing-party__.scripts.base")
local rd = require("__landing-party__.scripts.rd")
local stance = require("__landing-party__.scripts.stance")
local pool = require("__landing-party__.scripts.pool")
local threat = require("__landing-party__.scripts.threat")
local lights = require("__landing-party__.scripts.lights")
-- (What an armed camp's siege fund saves up to, siege.lua's: base cannot require ops.)
base.siege_goal = ops.siege_goal

local war = {}

local CHEST_SHARE, CHEST_CAP = 0.2, 6000
local RELIEF_TICKS = 10 * 3600
local RELIEF_PER_RUNG = 8
local RELIEF_MIN = 4
local RELIEF_MARKUP = 1.5
local POD_DISTANCE = 40
local COLUMN_PATIENCE = 10 * 3600
-- What makes parts too: a settlement whose fabricators were destroyed while at war rebuilt nothing, made no parts and
-- no units, for good (scenario occupy).
local ESSENTIAL = {["lp-generator"] = true, ["lp-depot"] = true, ["lp-fabricator"] = true, ["lp-drill"] = true,
  ["lp-pylon"] = true}

local function corp_state(corp)
  storage.corps = storage.corps or {}
  storage.corps[corp] = storage.corps[corp] or {level = 0, exported = 0}
  return storage.corps[corp]
end

function war.debug_chest(corp, parts)
  local d = corp_state(corp)
  d.chest = math.max(d.chest or 0, parts)
  return d.chest
end

function war.fund(corp, parts)
  local d = corp_state(corp)
  d.chest = math.min(CHEST_CAP, (d.chest or 0) + CHEST_SHARE * parts)
end

-- The player force this settlement may act against (stance.may: `act`, default "war": an enemy, not under a truce),
-- and its rung; nil when there is none. Before the stance it ignored truces and Grubstake's temper: an unprovoked rival
-- was "at war", held its rebuilds on a war footing and tapped under a paid truce (docs/ai.md).
local function at_war(b, act)
  -- The player force on its highest rung (the first in `pairs` order had been taken: with two players, an arbitrary
  -- rung; the faction AI audit, 2026-10-23).
  local seen, best, br = {}, nil, nil
  for _, t in pairs(b.intel and b.intel.targets or {}) do
    local o = t.owner
    if o and not seen[o] and game.forces[o] and shared.is_player_force(game.forces[o]) then
      seen[o] = true
      if stance.may(b.corp, o, act or "war") then
        local r = ops.ladder(o, b.force)
        if not br or r > br or (r == br and o < best) then best, br = o, r end
      end
    end
  end
  return best, br
end
war.at_war = at_war

local function strength(b) return pool.strength(b) end

-- base.rebuild asks before each job: false holds it (base.footing).
function war.footing(b, job)
  if ESSENTIAL[shared.kind_of(job.name)] then return true end
  if (b.war_checked or -1) ~= game.tick then
    b.war_checked = game.tick
    b.on_footing = ((b.posture and b.posture.war) or at_war(b) ~= nil) and strength(b) < army.cap(b)
  end
  return not b.on_footing
end
base.footing = war.footing

local function tell(key, corp, b)
  local s = game.surfaces[b.surface]
  for _, f in pairs(game.forces) do
    if #f.players > 0 and not shared.is_corp(f.name) then
      shared.notice(f, {key, shared.corp_label(corp), string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y, s.name)})
    end
  end
end

-- The detachment: n units of the settlement's mix and what they cost at the markup.
local function detachment(b, n)
  local m = army.mix(b)
  local names, cost = {}, 0
  for _ = 1, n do
    local name = rng.weighted(b.rng, m)
    if name == "lp-hauler" then name = "lp-infantry" end
    table.insert(names, name)
    cost = cost + RELIEF_MARKUP * shared.unit_cost(b.corp, name)
  end
  return names, cost
end

-- Units at `at` for settlement `to` (counted as its own from the start: a column's losses are its losses).
local function spawn(b, names, at, to)
  local s = game.surfaces[b.surface]
  local out = {}
  for _, name in ipairs(names) do
    local proto = rd.unit(b.corp, name)
    local p = s.find_non_colliding_position(proto, at, 16, 0.5)
    local u = p and s.create_entity{name = proto, position = p, force = b.force}
    if u then
      table.insert(out, u)
      pool.enlist(to, u)
    end
  end
  return out
end

local function join(b, units)
  for _, u in ipairs(units) do
    if u.valid then
      table.insert(b.garrison, u)
      pool.enlist(b, u)
    end
  end
end

-- Behind the lander, away from the player's buildings it knows (the pod comes down where the player is not).
local function behind(b, owner)
  local h = b.lander.position
  local sx, sy, n = 0, 0, 0
  for _, t in pairs(b.intel.targets) do
    if t.owner == owner and t.pos then sx, sy, n = sx + t.pos[1], sy + t.pos[2], n + 1 end
  end
  local dx, dy = 0, 1
  if n > 0 then
    dx, dy = h.x - sx / n, h.y - sy / n
    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
    dx, dy = dx / len, dy / len
  end
  return {h.x + dx * POD_DISTANCE, h.y + dy * POD_DISTANCE}
end

local function nearest_sister(b)
  local best, bd
  for _, o in pairs(storage.bases) do
    if o ~= b and o.corp == b.corp and not o.fallen and o.lander.valid and o.surface == b.surface then
      local d = (o.origin.x - b.origin.x) ^ 2 + (o.origin.y - b.origin.y) ^ 2
      if not bd or d < bd then best, bd = o, d end
    end
  end
  return best
end

local POD_LOAD = 4                -- units a relief pod carries
local function send(b, owner, rung)
  -- (No relief for an expedition, a director's drop wave: director.lua.)
  if b.expedition then return false end
  local d = corp_state(b.corp)
  local n = RELIEF_PER_RUNG * rung
  local sister = b.corp == "serenity" and nearest_sister(b)
  if b.corp == "serenity" and not sister then n = math.floor(n / 2) end
  local names, cost = detachment(b, n)
  while #names > RELIEF_MIN and cost > (d.chest or 0) do
    local name = table.remove(names)
    cost = cost - RELIEF_MARKUP * shared.unit_cost(b.corp, name)
  end
  if #names < RELIEF_MIN or cost > (d.chest or 0) then return false end
  if sister then
    -- A relief column from the sister settlement, along a route clear of turrets and nests (ops.route), or none.
    local from = {sister.lander.position.x, sister.lander.position.y + 8}
    local to = {b.lander.position.x, b.lander.position.y}
    local route = ops.route(sister, from, to, {turrets = true, nests = true})
    if not route then
      base.trace(b, "relief: no way from settlement " .. sister.id .. "; none sent")
      return false
    end
    local units = spawn(sister, names, from, b)
    local cmds = {}
    for _, w in ipairs(route) do
      table.insert(cmds, {type = defines.command.go_to_location, destination = w, radius = 4,
        distraction = defines.distraction.by_enemy})
    end
    table.insert(cmds, {type = defines.command.go_to_location, destination = to, radius = 10,
      distraction = defines.distraction.by_enemy})
    for _, u in ipairs(units) do
      u.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = cmds}
    end
    storage.reliefs = storage.reliefs or {}
    table.insert(storage.reliefs, {units = units, to = b.id, since = game.tick})
    base.trace(b, string.format("relief: a column of %d from settlement %d (%d waypoints), %.0f from the chest",
      #units, sister.id, #route, cost))
    tell("lp.relief-column", b.corp, b)
  elseif not storage.pods_off then
    -- By cargo pod (Space Age): four units a pod, landing behind the camp; they come out where it touches down
    -- (pods.handlers.relief).
    local at = behind(b, owner)
    local sent = 0
    for k = 1, #names, POD_LOAD do
      local load = {}
      for i = k, math.min(#names, k + POD_LOAD - 1) do load[#load + 1] = names[i] end
      local o = 3 * (sent - 1)
      if pods.send(game.surfaces[b.surface], {at[1] + o, at[2] + (sent % 2) * 3}, b.force,
        {kind = "relief", base = b.id, names = load}) then sent = sent + 1 end
    end
    base.trace(b, string.format("relief: %d pods of %d units to %.0f,%.0f, %.0f from the chest", sent, #names, at[1], at[2], cost))
    tell(b.corp == "grubstake" and "lp.relief-pod" or "lp.relief-drop", b.corp, b)
  else
    local at = behind(b, owner)
    local units = spawn(b, names, at, b)
    for _, u in ipairs(units) do
      u.commandable.set_command{type = defines.command.go_to_location, destination = b.lander.position, radius = 12,
        distraction = defines.distraction.by_enemy}
    end
    join(b, units)
    base.trace(b, string.format("relief: %s of %d at %.0f,%.0f, %.0f from the chest", b.corp == "grubstake" and "a pod" or "a drop",
      #units, at[1], at[2], cost))
    tell(b.corp == "grubstake" and "lp.relief-pod" or "lp.relief-drop", b.corp, b)
  end
  d.chest = d.chest - cost
  d.chest_spent = (d.chest_spent or 0) + cost
  b.reinforced = (b.reinforced or 0) + #names
  return true
end

-- A relief pod's units come out where it touched down and make for the camp.
pods.handlers.relief = function(p, surface, pos)
  local b = storage.bases[p.base]
  if not (b and not b.fallen and b.lander and b.lander.valid) then return end
  local units = spawn(b, p.names, {pos.x, pos.y}, b)
  for _, u in ipairs(units) do
    u.commandable.set_command{type = defines.command.go_to_location, destination = b.lander.position, radius = 12,
      distraction = defines.distraction.by_enemy}
  end
  join(b, units)
  b.pod_reliefs = (b.pod_reliefs or 0) + #units
end

-- Columns on the way join their settlement when they reach it (or after COLUMN_PATIENCE, wherever they are).
local function columns()
  for i = #(storage.reliefs or {}), 1, -1 do
    local r = storage.reliefs[i]
    local b = storage.bases[r.to]
    local live = {}
    for _, u in ipairs(r.units) do if u.valid then table.insert(live, u) end end
    r.units = live
    if not (b and b.lander.valid and not b.fallen) or #live == 0 then
      if b then base.trace(b, "relief: the column was lost") end
      table.remove(storage.reliefs, i)
    else
      local h = b.lander.position
      local near = 0
      for _, u in ipairs(live) do
        if (u.position.x - h.x) ^ 2 + (u.position.y - h.y) ^ 2 < 30 * 30 then near = near + 1 end
      end
      if near * 2 >= #live or game.tick - r.since > COLUMN_PATIENCE then
        join(b, live)
        b.columns_arrived = (b.columns_arrived or 0) + 1
        base.trace(b, string.format("relief: the column arrived, %d units", #live))
        table.remove(storage.reliefs, i)
      end
    end
  end
end

-- The orbital barrage (the user: Serenity "shells from above, before landing ... a very dramatic entrance, with tons of
-- cluster ammo pummeling the nests"): a corporation that clears nests, landing with spawners within ORBITAL_RADIUS,
-- has every spawner and worm there shelled from the sky, nearest first, a shell every ORBITAL_EVERY ticks (as many as
-- its health takes),
-- each the howitzer's blow with ten bomblets; BARRAGE_RAILS railgunners join its garrison. Its kills (spawners' evolution
-- refunded, biters.lua). A howitzer by the lander fired 10 of its 60 shells: its nests were out of its line and reach.
local ORBITAL_RADIUS, ORBITAL_EVERY, ORBITAL_FALL, BARRAGE_RAILS = 120, 15, 30, 8
-- An armed landing's (faction.arrive) takes the nests of the ground it grows into: every spawner within its mind's
-- ground of its lander (a prior: no prototype gives how far a spawner's waves come, which follow pollution and the
-- engine's attack groups), and every worm whose range reaches its blocks or depots (threat.nest_reach). On fed nw its
-- garrison, idle by depots 35 to 150 tiles from its lander, lost 160 units in its first hour to the worms and spitters of
-- nests 80 to 150 off (2026-11-02). Spawners by their biters' sight alone (0.2.138) left nwa's armed landing with no
-- barrage, its ground the fortress's box: behemoths took the lander nine minutes on (2026-11-02, the 200 had taken 106
-- spawners there).
-- Its sweeps are called through its orbital relay, by its lander under its dome (the user, 2026-11-02, on camp
-- howitzers: "Would defend from new expansions"; they could not, a6081de): destroyed or without power, no sweep, and the
-- nests grow back; put back RELAY_BACK after, its hull up.
-- And it keeps that ground from orbit: a sweep of the same whenever one stands there, looked for every SWEEP_LOOK, and
-- of the spawners nearest where its last losses to biters fell (its hazard log, siege.lua: learned, wherever they are).
-- No railgunners, no notice. Once was not enough on fed nw: the wild biters expanded back, 42 nests and worms within 200
-- at 30 minutes, 135 at 60, every depot (76 to 89 tiles out) gone (2026-11-02). Free: a share of its parts a shell (12)
-- starved the camp of everything else (the lane, 2026-10-19).
local SWEEP_LOOK = 60 * 60
local RELAY_BACK = 30 * 60 * 60
-- Its relay standing and powered; placed, or put back, where none stands.
local function relay(b, tick)
  local r = b.relay
  if r and r.valid then
    return r.status ~= defines.entity_status.no_power and r.status ~= defines.entity_status.low_power
  end
  if r ~= nil and not b.relay_down then
    b.relay_down, b.relays_lost = tick + RELAY_BACK, (b.relays_lost or 0) + 1
    base.trace(b, string.format("its orbital relay destroyed: no sweeps for %d minutes", RELAY_BACK / 3600))
  end
  if (b.relay_down or 0) > tick or not (b.lander.valid and not b.lander.destructible) then return false end
  -- (Once its fortress's jobs are done: placed at landing, it took a fortress turret's spot and the turret was skipped,
  -- nwa, 0.2.144. Its queue is never empty for long: the planner fills it again.)
  for _, job in ipairs(b.queue or {}) do
    if job.module and job.module.kind == "fortress" then return false end
  end
  local s = b.lander.surface
  local p = s.find_non_colliding_position("lp-orbital-relay", {b.lander.position.x + 8, b.lander.position.y + 8}, 20, 1)
  b.relay = p and s.create_entity{name = "lp-orbital-relay", position = p, force = b.force} or nil
  lights.attach(b.relay, b.corp)
  b.relay_down = nil
  if b.relay then base.trace(b, string.format("orbital relay up at %.0f,%.0f", p.x, p.y)) end
  return false
end
war.relay = relay
-- Its ground: its blocks' boxes and its depots, and how far from its lander the farthest of them is.
local function ground(b)
  local boxes, c, far = {}, b.lander.position, 0
  for _, k in ipairs(b.blocks or {}) do
    table.insert(boxes, {k.x0, k.y0, k.x0 + k.w, k.y0 + k.h})
  end
  for _, d in ipairs(b.depots or {}) do
    if d.valid then
      local p = d.position
      table.insert(boxes, {p.x - 2, p.y - 2, p.x + 2, p.y + 2})
    end
  end
  for _, x in ipairs(boxes) do
    for _, q in ipairs({{x[1], x[2]}, {x[3], x[4]}, {x[1], x[4]}, {x[3], x[2]}}) do
      far = math.max(far, math.sqrt((q[1] - c.x) ^ 2 + (q[2] - c.y) ^ 2))
    end
  end
  return boxes, far
end
-- The nests of its ground (above), nearest its lander first.
function war.threatening(b)
  local s, c = b.lander.surface, b.lander.position
  local boxes, far = ground(b)
  local reach = (shared.CORPS[b.corp].mind or {}).ground or 0
  local out, seen = {}, {}
  local function add(e) if not seen[e.unit_number] then seen[e.unit_number] = true; table.insert(out, e) end end
  for _, e in ipairs(s.find_entities_filtered{position = c, radius = math.max(reach, far + threat.nest_far()),
    type = {"unit-spawner", "turret"}, force = shared.NEST_FORCES}) do
    local p = e.position
    if e.type == "unit-spawner" and (p.x - c.x) ^ 2 + (p.y - c.y) ^ 2 <= reach * reach then
      add(e)
    else
      local r = threat.nest_reach(e)
      for _, x in ipairs(boxes) do
        local dx = math.max(x[1] - p.x, 0, p.x - x[3])
        local dy = math.max(x[2] - p.y, 0, p.y - x[4])
        if dx * dx + dy * dy <= r * r then add(e); break end
      end
    end
  end
  -- Learned: the spawner nearest where its losses to biters fell since its last look, and its neighbours within a
  -- biter's sight. (Its whole log, 30 minutes of it, walked the sweep outward a nest a minute on fed nw: the nearest
  -- shelled, the next nearest the old losses' middle was taken for theirs.)
  local h = {}
  for _, l in ipairs(b.hazard and b.hazard.log or {}) do if l[1] > (b.swept_at or 0) then table.insert(h, l) end end
  b.swept_at = game.tick
  if #h > 0 then
    local mx, my = 0, 0
    for _, l in ipairs(h) do mx, my = mx + l[2], my + l[3] end
    mx, my = mx / #h, my / #h
    local near, nd
    for _, e in ipairs(s.find_entities_filtered{position = {mx, my}, radius = reach + far, type = "unit-spawner",
      force = shared.NEST_FORCES}) do
      local d = (e.position.x - mx) ^ 2 + (e.position.y - my) ^ 2
      if not nd or d < nd then near, nd = e, d end
    end
    if near then
      for _, e in ipairs(s.find_entities_filtered{position = near.position, radius = threat.biter_sight(),
        type = {"unit-spawner", "turret"}, force = shared.NEST_FORCES}) do add(e) end
    end
  end
  table.sort(out, function(x, y)
    return (x.position.x - c.x) ^ 2 + (x.position.y - c.y) ^ 2 < (y.position.x - c.x) ^ 2 + (y.position.y - c.y) ^ 2
  end)
  return out
end
function war.barrage(b, sweep)
  if not shared.CORPS[b.corp].clears_nests or not (b.lander and b.lander.valid) then return end
  local s = b.lander.surface
  local c = b.lander.position
  local radius = ORBITAL_RADIUS
  local found
  if b.armed then
    found = war.threatening(b)
    -- Its ground clear (ops.tick: an armed camp sieges no player before), once: after that its sweeps keep it, and its
    -- sieges no longer wait (re-read at every look, in nest country it never read clear, 53 sweeps in an hour on nw, and
    -- it sent no siege on the player; 0.2.156).
    b.ground_clear = b.ground_clear or #found == 0
  else
    found = s.find_entities_filtered{position = c, radius = radius, type = {"unit-spawner", "turret"}, force = "enemy"}
  end
  if #found == 0 then return end
  table.sort(found, function(x, y)
    return (x.position.x - c.x) ^ 2 + (x.position.y - c.y) ^ 2 < (y.position.x - c.x) ^ 2 + (y.position.y - c.y) ^ 2
  end)
  -- As many shells as its health takes (a spawner has 3,500: one shell each left all five standing).
  local queue = {}
  for _, e in ipairs(found) do
    for _ = 1, threat.shells_for("lp-orbital-projectile", e) do table.insert(queue, e) end
  end
  storage.orbitals = storage.orbitals or {}
  table.insert(storage.orbitals, {base = b.id, surface = s.index, force = b.force, queue = queue, i = 1})
  if sweep then
    base.trace(b, string.format("orbital sweep: %d nests and worms within reach of its ground, %d shells", #found, #queue))
    return
  end
  local rails = {}
  for _ = 1, BARRAGE_RAILS do table.insert(rails, "lp-railgunner") end
  local units = spawn(b, rails, {c.x + 6, c.y + 6}, b)
  join(b, units)
  local spawners = 0
  for _, e in ipairs(found) do if e.type == "unit-spawner" then spawners = spawners + 1 end end
  base.trace(b, string.format("orbital barrage: %d spawners and %d worms %s, %d shells; %d railgunners", spawners,
    #found - spawners, b.armed and "within reach of its ground" or ("within " .. radius), #queue, #units))
  tell("lp.orbital", b.corp, b)
end

-- The corridor strike (an armed camp's sieges): the nests that can reach the rest of its hauler's route, each by how far it
-- is a danger and a biter's sight besides (threat.nest_reach, threat.biter_sight: spitters come out at what they see),
-- shelled from orbit nearest the hauler first, at its launch and at every look of its march (siege.lua). Its haulers on fed
-- nw died 120 to 175 tiles out to big worms and spitters of nests grown after it set out, 5 sieges of 8 (2026-11-02); a
-- bigger escort would have made a bigger siege. Shells already falling for that siege are not doubled.
local CORRIDOR_STEP = 6
function war.corridor(b, from, route, to)
  if not (b.armed and b.lander and b.lander.valid and shared.CORPS[b.corp].clears_nests) then return 0 end
  local s = b.lander.surface
  local pts, last = {}, from
  for _, w in ipairs(route or {}) do table.insert(pts, w) end
  table.insert(pts, to)
  local samples = {}
  for _, w in ipairs(pts) do
    local len = math.sqrt((w[1] - last[1]) ^ 2 + (w[2] - last[2]) ^ 2)
    for d = 0, len, CORRIDOR_STEP do
      table.insert(samples, {last[1] + (w[1] - last[1]) * d / math.max(len, 1), last[2] + (w[2] - last[2]) * d / math.max(len, 1)})
    end
    last = w
  end
  local queued = {}
  for _, o in ipairs(storage.orbitals or {}) do
    if o.base == b.id then for n = o.i, #o.queue do local e = o.queue[n]; if e.valid then queued[e.unit_number] = true end end end
  end
  local look = threat.nest_far() + threat.biter_sight()
  local found, seen = {}, {}
  for n, q in ipairs(samples) do
    -- (Every third sample for the search, each nest then tested against its own reach from every sample near it.)
    if n % 3 == 1 then
      for _, e in ipairs(s.find_entities_filtered{position = q, radius = look, type = {"unit-spawner", "turret"},
        force = shared.NEST_FORCES}) do
        local id = e.unit_number
        if not seen[id] then
          seen[id] = true
          local r = threat.nest_reach(e) + threat.biter_sight()
          for m = math.max(1, n - 12), math.min(#samples, n + 12) do
            local p = samples[m]
            if (e.position.x - p[1]) ^ 2 + (e.position.y - p[2]) ^ 2 <= r * r then
              if not queued[id] then table.insert(found, {e = e, at = m}) end
              break
            end
          end
        end
      end
    end
  end
  if #found == 0 then return 0 end
  table.sort(found, function(x, y) return x.at < y.at end)
  local queue = {}
  for _, f in ipairs(found) do
    for _ = 1, threat.shells_for("lp-orbital-projectile", f.e) do table.insert(queue, f.e) end
  end
  storage.orbitals = storage.orbitals or {}
  table.insert(storage.orbitals, {base = b.id, surface = s.index, force = b.force, queue = queue, i = 1, corridor = true})
  b.corridor_strikes, b.corridor_shells = (b.corridor_strikes or 0) + 1, (b.corridor_shells or 0) + #queue
  base.trace(b, string.format("corridor strike: %d nests and worms by its hauler's route, %d shells", #found, #queue))
  return #queue
end
ops.corridor = war.corridor

local function orbitals(tick)
  for k = #(storage.orbitals or {}), 1, -1 do
    local o = storage.orbitals[k]
    local s = game.surfaces[o.surface]
    -- The next target still standing (an earlier shell or its bomblets may have done for it).
    while o.queue[o.i] and not o.queue[o.i].valid do o.i = o.i + 1 end
    local e = o.queue[o.i]
    if not e or not s then
      local b = storage.bases[o.base]
      if b then base.trace(b, "orbital barrage over") end
      -- (Its landing barrage fallen, its ground counts as cleared for its sieges, ops.tick: in nest country no look of
      -- its sweeps ever read none within reach, and it never besieged the player, nw.)
      if b then b.ground_clear = true end
      table.remove(storage.orbitals, k)
    else
      o.i = o.i + 1
      local p = e.position
      -- Its force and cause given (given the force alone, its blast, "enemy" of nobody, hurt nothing).
      local b = storage.bases[o.base]
      local shell = s.create_entity{name = "lp-orbital-projectile", position = {p.x - 10, p.y - ORBITAL_FALL}, target = e,
        speed = 1, force = o.force, cause = game.forces[o.force], source = b and b.lander.valid and b.lander or nil}
    end
  end
end

-- Standing down (the user: a hopeless camp goes quiet rather than lifting off): a settlement at war that has razed
-- nothing for QUIET_TICKS (failed or not tried: a camp facing ten lasers launched one raid in 30 minutes) launches
-- nothing more against the player
-- (self-defence excepted) and gets no relief, keeps mining and exporting (its parts fund the others), and leaves its
-- place to a new landing, due within QUIET_HASTE and away from its site. After QUIET_TICKS it tries again.
local QUIET_TICKS, QUIET_HASTE = 60 * 3600, 5 * 3600
-- Or sooner, after FAIL_STREAK operations against the player failed in a row (ops.lua; times its aggression, two at least;
-- the user, 2026-11-04). A prior: a camp held by its ladder after each failure (tactics.lua) took 30 minutes for one.
local FAIL_STREAK = 3
local function quiet(tick)
  local span = storage.quiet_ticks or QUIET_TICKS
  for _, b in pairs(storage.bases) do
    -- Its rung against the player it is at war with, for the cap and the siege tier (army.cap, ops.siege_tier).
    local foe, rung = at_war(b)
    b.war_rung = rung or 0
    -- Its posture (strategy.lua): the cap's multiple and the footing's condition, in one place.
    -- And what its army lacks, at the mean price of what it builds (the planner leaves that much for it, by posture).
    local short, price, weight = 0, 0, 0
    if not b.fallen and b.lander.valid then
      short = math.max(0, army.cap(b) - strength(b))
      for kind, wt in pairs(army.mix(b) or {}) do price, weight = price + wt * shared.unit_cost(b.corp, kind), weight + wt end
    end
    b.posture = strategy.posture({corp = b.corp, rung = b.war_rung, at_war = foe ~= nil,
      grudge = b.grudge_till ~= nil and tick < b.grudge_till, threat = strategy.threat(b.corp), short = short,
      unit_cost = weight > 0 and price / weight or 0})
    if not b.fallen and b.lander.valid then
      if b.quiescent then
        if tick - b.quiescent >= span then
          b.quiescent, b.woke_at, b.aborted_mark, b.fail_streak = nil, tick, b.ops_aborted or 0, 0
          base.trace(b, "stood down long enough: it tries again")
        end
      elseif at_war(b) then
        b.war_since = b.war_since or tick
        local since = math.max(b.razed_at or 0, b.war_since, b.woke_at or 0)
        local aborted = (b.ops_aborted or 0) - (b.aborted_mark or 0)
        -- An aggressive corporation keeps at it longer before it stands down (tune.lua).
        local streak = math.max(2, math.floor(FAIL_STREAK * tune.aggression(b.corp) + 0.5))
        local losing = (b.fail_streak or 0) >= streak
        if tick - since >= span * tune.aggression(b.corp) or losing then
          b.quiescent = tick
          b.stood_down_streak = losing and (b.stood_down_streak or 0) + 1 or b.stood_down_streak
          b.stood_down = (b.stood_down or 0) + 1
          -- A rival again (Grubstake; Serenity never forgets): standing.lua.
          if war.forgive then war.forgive(b.corp) end
          storage.failed_sites = storage.failed_sites or {}
          table.insert(storage.failed_sites, {x = b.origin.x, y = b.origin.y})
          local f = storage.faction
          if f and f.next then f.next = math.min(f.next, tick + QUIET_HASTE) end
          if losing then
            base.trace(b, string.format("stands down: %d operations failed in a row; a new landing within %d",
              b.fail_streak, QUIET_HASTE / 3600))
          else
            base.trace(b, string.format("stands down: nothing razed in %d minutes, %d operations failed; a new landing within %d",
              (tick - since) / 3600, aborted, QUIET_HASTE / 3600))
          end
          b.fail_streak = 0
          tell("lp.stood-down", b.corp, b)
        end
      else
        b.war_since = nil
      end
    end
  end
end

function war.tick(tick)
  if storage.orbitals and #storage.orbitals > 0 and tick % ORBITAL_EVERY == 0 then orbitals(tick) end
  if tick % 600 ~= 300 then return end
  -- An armed camp's sweep (war.barrage): when a nest stands within reach of its ground, one at a time, none while its
  -- last is still falling.
  if not storage.sweeps_off then
    for _, b in pairs(storage.bases) do
      if b.armed and not b.fallen and b.lander and b.lander.valid and tick >= (b.sweep_next or 0) and relay(b, tick) then
        local falling = false
        for _, o in ipairs(storage.orbitals or {}) do if o.base == b.id then falling = true end end
        if not falling then
          b.sweep_next = tick + SWEEP_LOOK
          war.barrage(b, true)
        end
      end
    end
  end
  quiet(tick)
  columns()
  if storage.relief_off then return end
  local period = storage.relief_ticks or RELIEF_TICKS
  for corp in pairs(shared.CORPS) do
    local d = corp_state(corp)
    if tick >= (d.next_relief or 0) and not d.withdrawing then
      -- The settlement at war on the highest rung, the most short of its cap.
      local pick, prung, powner, short
      for _, b in pairs(storage.bases) do
        if b.corp == corp and not b.fallen and b.lander.valid and not b.quiescent then
          local owner, rung = at_war(b)
          local s = owner and army.cap(b) - strength(b)
          if owner and rung >= 1 and s > 0 and (not pick or rung > prung or (rung == prung and s > short)) then
            pick, prung, powner, short = b, rung, owner, s
          end
        end
      end
      if pick and send(pick, powner, prung) then d.next_relief = tick + period
      elseif pick then d.next_relief = tick + 2 * 3600 end
    end
  end
end

function war.summary(corp)
  local d = corp_state(corp)
  return {chest = d.chest or 0, spent = d.chest_spent or 0, next_relief = d.next_relief, columns = #(storage.reliefs or {})}
end

return war
