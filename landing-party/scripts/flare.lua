-- The pheromone flare (Grubstake; the user; docs/reviews/2026-10-15-grubstake-flavour-consult.md): Grubstake is felt
-- before it is seen. A buggy drops a canister just past the reach of a guarded player target's turrets and leaves; the
-- canister calls a wave: the idle biters round it first, and the nearest nests make up the rest (spawned for it: a flare
-- that only called idle biters was a trickle or nothing, the user, 2026-10-17). They attack what they meet there. Its
-- tell is in the world: orange smoke, then the wave (no notice: the user, "nothing is communicated through notices in
-- factorio"). Its counter: shoot the canister (FLARE_HEALTH), and the wave goes idle. Only
-- while the pact holds (the biters listen to Grubstake's chemistry because of it), and once its ladder against the
-- player has reached the first rung: against guarded ground, where its own raids would not go (soft_only) or not alone.
local shared = require("__landing-party__.shared")
local tune = require("__landing-party__.scripts.tune")
local base = require("__landing-party__.scripts.base")
local war = require("__landing-party__.scripts.war")
local ops = require("__landing-party__.scripts.ops")
local pact = require("__landing-party__.scripts.pact")
local pool = require("__landing-party__.scripts.pool")

local flare = {}

local COOLDOWN = 10 * 3600        -- a settlement's flares are this far apart
local BURN = 3 * 3600             -- a canister burns this long, then fizzles
local DRIVE = 2 * 3600            -- a buggy that has not reached its drop by then turns back
local REACH = 19                  -- the drop keeps out of every player turret's reach by this much (a gun turret's 18)
local DROP_MIN, DROP_MAX = 20, 40 -- from the target, toward the camp
local PULL_RADIUS = 400           -- idle biters this near the canister answer it, the nearest first (150 called none
                                  -- round a cleared deathworld base: its nests were 250 to 400 tiles out)
local PULL_BASE, PULL_EVO = 12, 24  -- the player's bait (flare.call): idle biters only
local WAVE_BASE, WAVE_EVO = 20, 40  -- a flare's wave: 20 + 40 x evolution, idle biters first, the nests the rest
local NEST_RADIUS = 600             -- nests this near the canister send their share
local NESTS = 3                     -- at most this many nests, the nearest
local AREA = 30                   -- the group attacks what it meets this near the canister
local RUNG = 1

local function home(b)
  for _, d in ipairs(b.depots or {}) do if d.valid then return d end end
  if b.lander and b.lander.valid then return b.lander end
end

-- Where to drop: from the target toward home, the first spot past every turret's reach.
local function drop_point(b, s, owner, tpos, hpos)
  local dx, dy = hpos.x - tpos[1], hpos.y - tpos[2]
  local len = math.sqrt(dx * dx + dy * dy)
  if len < DROP_MAX then return nil end
  for d = DROP_MIN, DROP_MAX, 2 do
    local q = {tpos[1] + dx / len * d, tpos[2] + dy / len * d}
    if s.count_entities_filtered{position = q, radius = REACH, force = owner,
      type = {"ammo-turret", "electric-turret", "fluid-turret"}, limit = 1} == 0 then
      return s.find_non_colliding_position("lp-flare", q, 4, 0.5)
    end
  end
end

-- Whether anything would answer a canister at `at`: a nest within NEST_RADIUS, or an idle biter within PULL_RADIUS.
local function answered(s, at)
  if s.count_entities_filtered{type = "unit-spawner", force = "enemy", position = at, radius = NEST_RADIUS, limit = 1} > 0 then
    return true
  end
  for _, u in pairs(s.find_entities_filtered{type = "unit", force = "enemy", position = at,
    radius = storage.flare_radius or PULL_RADIUS}) do
    if not u.commandable.parent_group then return true end
  end
  return false
end

-- The guarded targets nearest the camp first (turrets reach them). Not "what its raids would not take"
-- (ops.temper_allows): at its top rung Grubstake raids anything, and the flare goes first (the consult's ladder); that
-- choice found nothing there.
local function candidates(b, owner, hpos)
  local list = {}
  for _, t in pairs(b.intel and b.intel.targets or {}) do
    if t.owner == owner and t.pos and (t.exposure or t.defence or 0) > 0 and not ops.marked(b, t.pos) then
      list[#list + 1] = {t, (t.pos[1] - hpos.x) ^ 2 + (t.pos[2] - hpos.y) ^ 2}
    end
  end
  table.sort(list, function(x, y) return x[2] < y[2] end)
  return list
end

-- Send a buggy from the garrison to drop a canister at `at` (a flare against target position `tpos`).
function flare.launch(b, at, tpos)
  local buggy
  for i = #b.garrison, 1, -1 do
    local u = b.garrison[i]
    if u.valid and shared.kind_of(u.name) == "lp-buggy" then buggy = table.remove(b.garrison, i); break end
  end
  if not buggy then return false end
  buggy.commandable.set_command{type = defines.command.go_to_location, destination = at, radius = 3,
    distraction = defines.distraction.none}
  b.flare = {phase = "drive", buggy = buggy, at = {x = at.x or at[1], y = at.y or at[2]}, target = tpos, started = game.tick}
  b.flares = (b.flares or 0) + 1
  base.trace(b, string.format("flare %d: a buggy drives a canister to %.0f,%.0f (target at %.0f,%.0f)", b.flares,
    b.flare.at.x, b.flare.at.y, tpos[1], tpos[2]))
  return true
end

-- The player's pheromone bait (bait.lua): the idle biters (in no group) within PULL_RADIUS of `at`, the nearest
-- 12 + 24 x evolution, as one group told to attack whatever it meets within AREA of it (no nest spawns for the player).
-- Returns the group (nil: none) and how many.
function flare.call(s, at)
  local evo = game.forces.enemy.get_evolution_factor(s)
  local n = math.floor(PULL_BASE + PULL_EVO * evo)
  local found = {}
  for _, u in pairs(s.find_entities_filtered{type = "unit", force = "enemy", position = at,
    radius = storage.flare_radius or PULL_RADIUS}) do
    if not u.commandable.parent_group then
      table.insert(found, {u, (u.position.x - at.x) ^ 2 + (u.position.y - at.y) ^ 2})
    end
  end
  table.sort(found, function(x, y) return x[2] < y[2] end)
  if #found == 0 then return nil, 0 end
  local group = s.create_unit_group{position = found[1][1].position, force = "enemy"}
  local k = 0
  for i = 1, math.min(n, #found) do group.add_member(found[i][1]); k = k + 1 end
  group.set_command{type = defines.command.attack_area, destination = at, radius = AREA,
    distraction = defines.distraction.by_enemy}
  return group, k
end

-- What a nest spawns at evolution `evo`: its result units weighted as the engine weighs them (linear between points).
local function pick_unit(spawner, evo)
  local total, weights = 0, {}
  for _, def in ipairs(spawner.prototype.result_units or {}) do
    local pts, w = def.spawn_points, 0
    for i, pt in ipairs(pts) do
      local nx = pts[i + 1]
      if evo <= pt.evolution_factor then w = (i == 1) and pt.weight or w; break end
      if not nx then w = pt.weight
      elseif evo < nx.evolution_factor then
        w = pt.weight + (nx.weight - pt.weight) * (evo - pt.evolution_factor) / (nx.evolution_factor - pt.evolution_factor)
        break
      end
    end
    if w > 0 then total = total + w; weights[#weights + 1] = {def.unit, total} end
  end
  if total <= 0 then return nil end
  local r = math.random() * total
  for _, uw in ipairs(weights) do if r <= uw[2] then return uw[1] end end
  return weights[#weights][1]
end

-- Gather at the canister, then attack the target it was dropped for. Told only to attack within AREA of the canister
-- (out of turret reach, 20 to 40 from the target), the wave arrived and waited outside the wall (the user, 2026-10-17:
-- "a wave of biters chilling just beyond my walls").
local function send(group, at, target)
  local cmds = {{type = defines.command.go_to_location, destination = at, radius = 8,
    distraction = defines.distraction.by_enemy}}
  if target then
    cmds[#cmds + 1] = {type = defines.command.attack_area, destination = {x = target[1], y = target[2]}, radius = AREA,
      distraction = defines.distraction.by_anything}
  end
  cmds[#cmds + 1] = {type = defines.command.attack_area, destination = at, radius = AREA,
    distraction = defines.distraction.by_enemy}
  group.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = cmds}
end

-- The wave: idle biters near the canister first (flare.call's), then the nearest nests, each spawning an equal share of
-- what is missing, as its own group sent at the canister. Returns the groups and how many biters in all, and from where.
local function wave(s, at, target, corp)
  local evo = game.forces.enemy.get_evolution_factor(s)
  -- Grubstake's strength lever (tune.lua): its chemistry calls more.
  local want = math.floor(((storage.flare_wave or WAVE_BASE) + WAVE_EVO * evo) * tune.strength(corp))
  local groups, k, from = {}, 0, {}
  local found = {}
  for _, u in pairs(s.find_entities_filtered{type = "unit", force = "enemy", position = at,
    radius = storage.flare_radius or PULL_RADIUS}) do
    if not u.commandable.parent_group then
      table.insert(found, {u, (u.position.x - at.x) ^ 2 + (u.position.y - at.y) ^ 2})
    end
  end
  table.sort(found, function(x, y) return x[2] < y[2] end)
  if #found > 0 then
    local g = s.create_unit_group{position = found[1][1].position, force = "enemy"}
    for i = 1, math.min(want, #found) do g.add_member(found[i][1]); k = k + 1 end
    send(g, at, target)
    groups[#groups + 1] = g
    from[#from + 1] = string.format("%d idle", k)
  end
  local short = want - k
  if short > 0 then
    local nests = s.find_entities_filtered{type = "unit-spawner", force = "enemy", position = at, radius = NEST_RADIUS}
    table.sort(nests, function(x, y)
      return (x.position.x - at.x) ^ 2 + (x.position.y - at.y) ^ 2 < (y.position.x - at.x) ^ 2 + (y.position.y - at.y) ^ 2
    end)
    local n = math.min(NESTS, #nests)
    for i = 1, n do
      local nest, share = nests[i], math.ceil(short / n)
      local g = s.create_unit_group{position = nest.position, force = "enemy"}
      local made = 0
      for _ = 1, share do
        local name = pick_unit(nest, evo)
        local p = name and s.find_non_colliding_position(name, nest.position, 12, 0.5)
        local u = p and s.create_entity{name = name, position = p, force = "enemy"}
        if u then g.add_member(u); made = made + 1 end
      end
      if made > 0 then
        send(g, at, target)
        groups[#groups + 1] = g
        k = k + made
        from[#from + 1] = string.format("%d from the nest at %.0f,%.0f", made, nest.position.x, nest.position.y)
      else
        g.destroy()
      end
    end
  end
  return groups, k, table.concat(from, ", ")
end

-- Over. Only a shot canister calls its wave off (the counter); burned out, the wave goes on: stood down then, a wave from
-- nests 250 to 400 tiles off arrived after the burn and wandered by the player's wall (the user's autosave, 2026-10-17).
local function release(b, f, why, keep)
  for _, g in ipairs(keep and {} or f.groups or {f.group}) do
    if g.valid then g.set_command{type = defines.command.wander, radius = 10, distraction = defines.distraction.by_enemy} end
  end
  if f.tag and f.tag.valid then f.tag.destroy() end
  if f.canister and f.canister.valid then
    f.canister.surface.create_entity{name = "explosion", position = f.canister.position}
    f.canister.destroy()
  end
  if f.buggy and f.buggy.valid then pool.give_one(b, f.buggy) end
  base.trace(b, "flare over: " .. why)
  b.flare = nil
  b.next_flare = game.tick + (storage.flare_cooldown or tune.sooner(b.corp, COOLDOWN))
end

local function drop(b, f)
  local s = game.surfaces[b.surface]
  local p = s.find_non_colliding_position("lp-flare", f.buggy.position, 4, 0.5)
  f.canister = p and s.create_entity{name = "lp-flare", position = p, force = f.buggy.force}
  if not f.canister then return release(b, f, "no room to drop") end
  f.phase, f.lit = "burn", game.tick
  local h = home(b)
  if h then
    -- It drops and leaves: free to engage on the way home, it drove at the outpost's turrets and died (scenario flare).
    f.buggy.commandable.set_command{type = defines.command.go_to_location, destination = h.position, radius = 8,
      distraction = defines.distraction.none}
  end
  pool.give_one(b, f.buggy)
  f.buggy = nil
  local from
  f.groups, f.pulled, from = wave(s, f.canister.position, f.target, b.corp)
  base.trace(b, string.format("flare lit at %.0f,%.0f: %d biters called (%s)", f.canister.position.x, f.canister.position.y,
    f.pulled, from))
end

local function step(b, f)
  if f.phase == "drive" then
    if not f.buggy.valid then return release(b, f, "the buggy was lost") end
    if game.tick - f.started > DRIVE then return release(b, f, "the buggy never got there") end
    local p = f.buggy.position
    if (p.x - f.at.x) ^ 2 + (p.y - f.at.y) ^ 2 < 5 * 5 then drop(b, f) end
  elseif f.phase == "burn" then
    if not f.canister.valid then return release(b, f, "the canister was destroyed") end
    if game.tick - f.lit > (storage.flare_burn or BURN) then return release(b, f, "the canister burned out", true) end
    f.canister.surface.create_trivial_smoke{name = "lp-flare-smoke", position = f.canister.position}
  end
end

-- Whether this settlement fires a flare now, and at what.
local function consider(b)
  if storage.flare_off or not (shared.CORPS[b.corp].temper or {}).flares then return end
  if b.fallen or b.quiescent or not b.mature or game.tick < (b.next_flare or 0) then return end
  if not (pact.has(b.corp) and storage.pact_state and storage.pact_state[b.corp]) then return end
  local owner, rung = war.at_war(b, "flare")
  if not owner or (rung or 0) < RUNG then return end
  if ops.truce and ops.truce(b, owner) then return end
  local h = home(b)
  if not h then return end
  -- The nearest few targets whose drop point a nest or a biter would answer: a canister nothing answers is a blank (the user,
  -- 2026-10-17: lit in front of the wall, nothing came).
  local s = game.surfaces[b.surface]
  local list = candidates(b, owner, h.position)
  if #list == 0 then return end
  for i = 1, math.min(5, #list) do
    local t = list[i][1]
    local at = drop_point(b, s, owner, t.pos, h.position)
    if at and answered(s, at) then
      if not flare.launch(b, at, t.pos) then b.next_flare = game.tick + 3600 end
      return
    end
  end
  base.trace(b, string.format("flare: nothing would answer a drop by the %d nearest guarded targets (no nest within %d, "
    .. "no idle biter within %d); not sent", math.min(5, #list), NEST_RADIUS, storage.flare_radius or PULL_RADIUS))
  b.next_flare = game.tick + 3600
end

-- An answer (ops' reaction table, Grubstake's "flare"): a canister by the culprit, now, if the pact holds and something
-- would answer it there. Its ladder and cooldown do not apply: the answer has its own. "launched", or why not.
function flare.answer(b, tpos, owner)
  if storage.flare_off or not (shared.CORPS[b.corp].temper or {}).flares then return "no flares" end
  if b.flare then return "a flare already out" end
  if not (pact.has(b.corp) and storage.pact_state and storage.pact_state[b.corp]) then return "no pact" end
  local h = home(b)
  local s = game.surfaces[b.surface]
  local at = h and drop_point(b, s, owner, tpos, h.position)
  if not at then return "no drop point" end
  if not answered(s, at) then return "nothing would answer it" end
  if not flare.launch(b, at, tpos) then return "no buggy" end
  b.next_flare = math.max(b.next_flare or 0, game.tick + tune.sooner(b.corp, COOLDOWN))
  return "launched"
end
ops.answer_flare = flare.answer

-- debug_flare: a flare from settlement b at a target position, chosen and dropped as consider() would (pact included).
function flare.debug(b, tpos)
  if not (pact.has(b.corp) and storage.pact_state and storage.pact_state[b.corp]) then return "no pact" end
  local h = home(b)
  local owner = shared.owner_at(game.surfaces[b.surface], tpos)
  local at = h and owner and drop_point(b, game.surfaces[b.surface], owner, tpos, h.position)
  if not at then return "no drop point" end
  return flare.launch(b, at, tpos) and "launched" or "no buggy"
end

function flare.tick(tick)
  if tick % 30 ~= 7 then return end
  for _, b in pairs(storage.bases or {}) do
    if b.flare then
      step(b, b.flare)
    elseif tick % 600 == 7 then
      consider(b)
    end
  end
end

return flare
