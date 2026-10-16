-- The pheromone flare (Grubstake; the user; docs/reviews/2026-10-15-grubstake-flavour-consult.md): Grubstake is felt
-- before it is seen. A buggy drops a canister just past the reach of a guarded player target's turrets and leaves; the
-- canister calls the idle biters round it, sent at it as one group, and they attack what they meet. Its tell: a column
-- of orange smoke, an alert, a map tag. Its counter: shoot the canister (FLARE_HEALTH), and the group goes idle. Only
-- while the pact holds (the biters listen to Grubstake's chemistry because of it), and once its ladder against the
-- player has reached the first rung: against guarded ground, where its own raids would not go (soft_only) or not alone.
local shared = require("__landing-party__.shared")
local base = require("__landing-party__.scripts.base")
local war = require("__landing-party__.scripts.war")
local pact = require("__landing-party__.scripts.pact")

local flare = {}

local COOLDOWN = 10 * 3600        -- a settlement's flares are this far apart
local BURN = 3 * 3600             -- a canister burns this long, then fizzles
local DRIVE = 2 * 3600            -- a buggy that has not reached its drop by then turns back
local REACH = 19                  -- the drop keeps out of every player turret's reach by this much (a gun turret's 18)
local DROP_MIN, DROP_MAX = 20, 40 -- from the target, toward the camp
local PULL_RADIUS = 150           -- idle biters this near the canister answer it
local PULL_BASE, PULL_EVO = 12, 24
local AREA = 30                   -- the group attacks what it meets this near the canister
local RUNG = 1

local function tell(b, key, at)
  local s = game.surfaces[b.surface]
  for _, f in pairs(game.forces) do
    if #f.players > 0 and not shared.is_corp(f.name) then
      f.print({key, shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", at.x, at.y, s.name)})
    end
  end
end

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

-- The guarded target nearest the camp (turrets reach it). Not "what its raids would not take" (ops.temper_allows): at its
-- top rung Grubstake raids anything, and the flare goes first (the consult's ladder); that choice found nothing there.
local function pick(b, owner, hpos)
  local best, bd
  for _, t in pairs(b.intel and b.intel.targets or {}) do
    if t.owner == owner and t.pos and (t.exposure or t.defence or 0) > 0 then
      local d = (t.pos[1] - hpos.x) ^ 2 + (t.pos[2] - hpos.y) ^ 2
      if not bd or d < bd then best, bd = t, d end
    end
  end
  return best
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

local function pull(b, s, f)
  local evo = game.forces.enemy.get_evolution_factor(s)
  local n = math.floor(PULL_BASE + PULL_EVO * evo)
  local found = {}
  for _, u in pairs(s.find_entities_filtered{type = "unit", force = "enemy", position = f.canister.position,
    radius = storage.flare_radius or PULL_RADIUS}) do
    if not u.commandable.parent_group then
      table.insert(found, {u, (u.position.x - f.at.x) ^ 2 + (u.position.y - f.at.y) ^ 2})
    end
  end
  table.sort(found, function(x, y) return x[2] < y[2] end)
  if #found == 0 then return 0 end
  local group = s.create_unit_group{position = found[1][1].position, force = "enemy"}
  local k = 0
  for i = 1, math.min(n, #found) do group.add_member(found[i][1]); k = k + 1 end
  group.set_command{type = defines.command.attack_area, destination = f.at, radius = AREA,
    distraction = defines.distraction.by_enemy}
  f.group = group
  return k
end

local function release(b, f, why)
  if f.group and f.group.valid then
    f.group.set_command{type = defines.command.wander, radius = 10, distraction = defines.distraction.by_enemy}
  end
  if f.tag and f.tag.valid then f.tag.destroy() end
  if f.canister and f.canister.valid then
    f.canister.surface.create_entity{name = "explosion", position = f.canister.position}
    f.canister.destroy()
  end
  if f.buggy and f.buggy.valid then table.insert(b.garrison, f.buggy) end
  base.trace(b, "flare over: " .. why)
  b.flare = nil
  b.next_flare = game.tick + (storage.flare_cooldown or COOLDOWN)
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
  table.insert(b.garrison, f.buggy)
  f.buggy = nil
  f.pulled = pull(b, s, f)
  for _, pf in pairs(game.forces) do
    if #pf.players > 0 and not shared.is_corp(pf.name) then
      f.tag = pf.add_chart_tag(s, {position = f.canister.position, icon = {type = "virtual", name = shared.CORPS[b.corp].icon},
        text = "Pheromone flare"})
      for _, pl in pairs(pf.connected_players) do
        pl.add_custom_alert(f.canister, {type = "virtual", name = shared.CORPS[b.corp].icon}, {"lp.alert-flare"}, true)
      end
    end
  end
  tell(b, "lp.flare", f.canister.position)
  base.trace(b, string.format("flare lit at %.0f,%.0f: %d biters called", f.canister.position.x, f.canister.position.y,
    f.pulled))
end

local function step(b, f)
  if f.phase == "drive" then
    if not f.buggy.valid then return release(b, f, "the buggy was lost") end
    if game.tick - f.started > DRIVE then return release(b, f, "the buggy never got there") end
    local p = f.buggy.position
    if (p.x - f.at.x) ^ 2 + (p.y - f.at.y) ^ 2 < 5 * 5 then drop(b, f) end
  elseif f.phase == "burn" then
    if not f.canister.valid then return release(b, f, "the canister was destroyed") end
    if game.tick - f.lit > BURN then return release(b, f, "the canister burned out") end
    f.canister.surface.create_trivial_smoke{name = "lp-flare-smoke", position = f.canister.position}
  end
end

-- Whether this settlement fires a flare now, and at what.
local function consider(b)
  if storage.flare_off or not (shared.CORPS[b.corp].temper or {}).flares then return end
  if b.fallen or b.quiescent or not b.mature or game.tick < (b.next_flare or 0) then return end
  if not (pact.has(b.corp) and storage.pact_state and storage.pact_state[b.corp]) then return end
  local owner, rung = war.at_war(b)
  if not owner or (rung or 0) < RUNG then return end
  local h = home(b)
  if not h then return end
  local t = pick(b, owner, h.position)
  if not t then return end
  local s = game.surfaces[b.surface]
  local at = drop_point(b, s, owner, t.pos, h.position)
  if not at then b.next_flare = game.tick + 3600; return end
  if not flare.launch(b, at, t.pos) then b.next_flare = game.tick + 3600 end
end

-- debug_flare: a flare from settlement b at a target position, chosen and dropped as consider() would (pact included).
function flare.debug(b, tpos)
  if not (pact.has(b.corp) and storage.pact_state and storage.pact_state[b.corp]) then return "no pact" end
  local h = home(b)
  local owner = "player"
  local at = h and drop_point(b, game.surfaces[b.surface], owner, tpos, h.position)
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
