-- The power tap (Grubstake; the user, 2026-10-16: "steal power from unprotected lines ... with a progressively
-- increasing draw", and "connected to their camp through pylons, no?"). A settlement at war runs a line of its own pylons
-- from its nearest pylon toward a player pole no turret covers, and clamps a tap (lp-power-tap) beside it: a Grubstake
-- device drawing from the player's network (an entity of any force in a player pole's supply area is powered by it:
-- spike, DESIGN Engine notes). What it draws reaches the camp at the line's last pylon (lp-power-receiver, hidden there)
-- while the line stands unbroken to the camp's network; the draw rises step by step. Cut the line anywhere and the theft
-- stops until the camp rebuilds the gap; break the tap and it is over.
local shared = require("__landing-party__.shared")
local base = require("__landing-party__.scripts.base")
local war = require("__landing-party__.scripts.war")

local tap = {}

local COOLDOWN = 20 * 3600        -- after a tap is broken or the line given up
local RANGE = 160                 -- a pole this near the camp's nearest pylon
local SAFE = 30                   -- no player turret this near the pole
local GAP = 12                    -- the line ends this far from the pole (its supply area keeps off the tap)
local START, GROW, MAX = 100000, 1.5, 4000000   -- watts: the first draw, its rise each step, the most
local STEP = 5 * 3600

local function tell(b, key, at, extra)
  local s = game.surfaces[b.surface]
  for _, f in pairs(game.forces) do
    if #f.players > 0 and not shared.is_corp(f.name) then
      f.print({key, shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", at.x, at.y, s.name), extra})
    end
  end
end

local function nearest(list, pos)
  local best, bd
  for _, e in ipairs(list) do
    if e.valid and shared.is_corp(e.force.name) then
      local d = (e.position.x - pos.x) ^ 2 + (e.position.y - pos.y) ^ 2
      if not bd or d < bd then best, bd = e, d end
    end
  end
  return best, bd and math.sqrt(bd)
end

-- Queue a line of pylons from the camp's pylon `from` to `to` (a module of its own: rebuilt when lost, never captured).
local function lay(b, from, to)
  local dx, dy = to.x - from.x, to.y - from.y
  local len = math.sqrt(dx * dx + dy * dy)
  local n = math.max(1, math.ceil(len / (shared.PYLON_REACH - 3)))
  local m = {kind = "tapline", center = {to.x, to.y}, entities = {}}
  for k = 1, n do
    table.insert(b.queue, {name = "lp-pylon", pos = {from.x + dx * k / n, from.y + dy * k / n}, module = m})
  end
  return m, n
end

-- The line's end: its pylon nearest the tap's spot, on the camp's network.
local function end_pylon(b, t)
  local best = nearest(t.module.entities, t.goal)
  return best
end

function tap.launch(b, pole)
  if not (pole and pole.valid) then return "no pole" end
  local from = nearest(b.pylons, pole.position)
  if not from then return "no pylon" end
  local dx, dy = from.position.x - pole.position.x, from.position.y - pole.position.y
  local len = math.max(1, math.sqrt(dx * dx + dy * dy))
  local goal = {x = pole.position.x + dx / len * GAP, y = pole.position.y + dy / len * GAP}
  local m, n = lay(b, from.position, goal)
  b.tap = {phase = "line", pole = pole, owner = pole.force.name, module = m, goal = goal, started = game.tick}
  b.taps = (b.taps or 0) + 1
  base.trace(b, string.format("tap %d: a line of %d pylons toward a %s at %.0f,%.0f", b.taps, n, pole.name,
    pole.position.x, pole.position.y))
  return "launched"
end

local function over(b, t, why)
  if t.tap and t.tap.valid then t.tap.destroy() end
  if t.receiver and t.receiver.valid then t.receiver.destroy() end
  if t.cable and t.cable.valid then t.cable.destroy() end
  b.tap_watts = 0
  base.trace(b, string.format("tap over: %s (%.0f MJ taken)", why, (t.taken or 0) / 1e6))
  b.tap = nil
  b.next_tap = game.tick + (storage.tap_cooldown or COOLDOWN)
end

local function clamp(b, t)
  local s = game.surfaces[b.surface]
  local p = s.find_non_colliding_position("lp-power-tap", t.pole.position, 3, 0.5)
  local e = p and s.create_entity{name = "lp-power-tap", position = p, force = b.lander.force}
  if not e then return over(b, t, "no room by the pole") end
  local last = end_pylon(b, t)
  local r = s.create_entity{name = "lp-power-receiver", position = last.position, force = b.lander.force}
  r.destructible = false
  t.tap, t.receiver, t.phase, t.draw, t.next_step, t.taken = e, r, "draw", START, game.tick + (storage.tap_step or STEP), 0
  t.cable = rendering.draw_line{from = e, to = last, surface = s, color = {0.85, 0.5, 0.2, 0.9}, width = 2}
  tell(b, "lp.tap", e.position)
  base.trace(b, string.format("tap clamped at %.0f,%.0f, %d W to start", e.position.x, e.position.y, START))
end

local function step(b, t)
  if t.phase == "line" then
    if t.module.failed then return over(b, t, "the line could not be laid") end
    if not t.pole.valid then return over(b, t, "the pole is gone") end
    if t.module.built then
      local last = end_pylon(b, t)
      if last and last.electric_network_id == base.network(b) then clamp(b, t) end
    end
    return
  end
  if not t.tap.valid then
    tell(b, "lp.tap-cut", t.receiver and t.receiver.valid and t.receiver.position or t.goal, string.format("%.0f", t.taken / 1e6))
    return over(b, t, "the tap was broken")
  end
  if game.tick >= t.next_step then
    t.draw = math.min(MAX, t.draw * GROW)
    t.next_step = game.tick + (storage.tap_step or STEP)
  end
  -- Home: the end pylon on the camp's network (a cut anywhere splits it off).
  local last = end_pylon(b, t)
  local home = last and last.valid and last.electric_network_id == base.network(b)
  if t.receiver.valid and last and (t.receiver.position.x ~= last.position.x or t.receiver.position.y ~= last.position.y) then
    t.receiver.teleport(last.position)
  end
  local per_tick = home and t.draw / 60 or 0
  -- What it got over the last second (the buffer it was meant to drain, refilled by the player's network).
  local got = math.min(1, t.tap.energy / math.max(1, t.tap.electric_buffer_size or 1))
  t.tap.electric_buffer_size = math.max(1, per_tick * 2)
  t.tap.power_usage = per_tick
  local watts = per_tick * 60 * (per_tick > 0 and got or 0)
  if t.receiver.valid then
    t.receiver.power_production = watts / 60
    t.receiver.electric_buffer_size = math.max(1, watts / 60 * 2)
  end
  b.tap_watts = watts
  t.taken = t.taken + watts
end

local function consider(b)
  if storage.tap_off or not (shared.CORPS[b.corp].temper or {}).taps then return end
  if b.fallen or b.quiescent or not b.mature or game.tick < (b.next_tap or 0) then return end
  local owner = war.at_war(b)
  if not owner then return end
  local s = game.surfaces[b.surface]
  local h = b.lander.position
  local best, bd
  for _, pole in pairs(s.find_entities_filtered{type = "electric-pole", force = owner, position = h,
    radius = RANGE + (b.claim_radius or 100)}) do
    local p, d = nearest(b.pylons, pole.position)
    if p and d <= RANGE and pole.electric_network_id and (not bd or d < bd)
      and s.count_entities_filtered{position = pole.position, radius = SAFE, force = owner,
        type = {"ammo-turret", "electric-turret", "fluid-turret"}, limit = 1} == 0 then
      best, bd = pole, d
    end
  end
  if not best then b.next_tap = game.tick + 5 * 3600; return end
  if tap.launch(b, best) ~= "launched" then b.next_tap = game.tick + 5 * 3600 end
end

-- debug_tap: a tap from settlement b on the player pole nearest pos.
function tap.debug(b, pos)
  local pole = game.surfaces[b.surface].find_entities_filtered{type = "electric-pole", force = "player", position = pos,
    radius = 10, limit = 1}[1]
  return tap.launch(b, pole)
end
function tap.state(b)
  local t = b.tap
  return t and {phase = t.phase, draw = t.draw, taken = t.taken, watts = b.tap_watts, pylons = #t.module.entities,
    built = t.module.built, tap = t.tap and t.tap.valid and {t.tap.position.x, t.tap.position.y}} or {}
end

function tap.tick(tick)
  if tick % 60 ~= 23 then return end
  for _, b in pairs(storage.bases or {}) do
    if b.tap then
      step(b, b.tap)
    elseif tick % 600 == 23 + 60 * 5 then
      consider(b)
    end
  end
end

return tap
