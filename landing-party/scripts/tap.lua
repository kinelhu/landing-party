-- The power tap (Grubstake; the user, 2026-10-16: "steal power from unprotected lines ... with a progressively
-- increasing draw", and "connected to their camp through pylons, no?"). A settlement at war runs a line of its own pylons
-- from its nearest pylon toward a player pole no turret covers, and clamps a tap (lp-power-tap) beside it: a Grubstake
-- device drawing from the player's network (an entity of any force in a player pole's supply area is powered by it:
-- spike, DESIGN Engine notes). What it draws reaches the camp at the line's last pylon (lp-power-receiver, hidden there)
-- while the line stands unbroken to the camp's network; the draw rises step by step. Cut the line anywhere and the theft
-- stops until the camp rebuilds the gap; break the tap and it is over.
-- A discreet operation, as the heist is (the user: "does grubstake detect exposed poles? is it able to sneak path to
-- them?"): it taps only a pole its own sensors have seen exposed (no turret reaches it: intel's exposure), lays the line
-- along a route clear of every turret's reach (ops.route, the heist's), and says nothing when it clamps: the player finds
-- it in the power statistics, in brownouts, or by the line. The notice comes only when the tap is broken.
-- An operation, not construction (the user: "strange that the tap is built directly from the lander ... a hauler buggy
-- building the pylon line to the player pole"): the camp pays for the line, and a buggy from its garrison drives the
-- route, planting a pylon at each spot and the tap at the end, then goes home. Killed on the way, the operation is over,
-- the half-laid line left standing. A cut line is mended the same way: a buggy drives out to the missing pylons. The
-- line's pylons are the operation's: the camp's own rebuilding never touches them.
local shared = require("__landing-party__.shared")
local base = require("__landing-party__.scripts.base")
local war = require("__landing-party__.scripts.war")
local ops = require("__landing-party__.scripts.ops")

local tap = {}

local COOLDOWN = 20 * 3600        -- after a tap is broken or the line given up
local RANGE = 160                 -- a pole this near the camp's nearest pylon
local SAFE = 30                   -- no player turret this near the pole
local GAP = 12                    -- the line ends this far from the pole (its supply area keeps off the tap)
local START, GROW, MAX = 100000, 1.5, 4000000   -- watts: the first draw, its rise each step, the most
local STEP = 5 * 3600
local DRIVE = 60 * 60             -- a buggy no nearer its next spot for this long is stuck: the run is given up
local REPAIR_WAIT = 2 * 3600      -- after a repair buggy is lost

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

-- The spots for a line along `points` (from the camp's pylon to the goal): a pylon every SPACING along the way, and one at
-- the goal (the last moved there when it falls short by under half a span: two pylons 2 tiles apart made a cut there
-- bridgeable).
local SPACING = shared.PYLON_REACH - 4
local function spots_along(points)
  local goal = points[#points]
  local out, carry = {}, 0
  for i = 2, #points do
    local a, c = points[i - 1], points[i]
    local dx, dy = c.x - a.x, c.y - a.y
    local len = math.sqrt(dx * dx + dy * dy)
    local d = SPACING - carry
    while d <= len do
      table.insert(out, {x = a.x + dx * d / len, y = a.y + dy * d / len})
      d = d + SPACING
    end
    carry = len - (d - SPACING)
  end
  if carry > SPACING / 2 or #out == 0 then table.insert(out, {x = goal.x, y = goal.y})
  elseif carry > 0 then out[#out] = {x = goal.x, y = goal.y} end
  return out
end

-- A buggy from the garrison (nil: none at home).
local function buggy(b)
  for i = #b.garrison, 1, -1 do
    local u = b.garrison[i]
    if u.valid and shared.kind_of(u.name) == "lp-buggy" then return table.remove(b.garrison, i) end
  end
end

local function home_of(b)
  for _, d in ipairs(b.depots or {}) do if d.valid then return d end end
  return b.lander
end

-- Send a run (the laying or a repair) to plant pylons at the spots listed by index.
local function drive(b, t, u, todo)
  t.run = {buggy = u, todo = todo, k = 1, best = math.huge, best_at = game.tick}
  local sp = t.spots[todo[1]]
  u.commandable.set_command{type = defines.command.go_to_location, destination = sp, radius = 1.5,
    distraction = defines.distraction.none}
end

local function run_over(b, t)
  local r = t.run
  if r and r.buggy.valid then
    table.insert(b.garrison, r.buggy)
    local h = home_of(b)
    if h and h.valid then
      r.buggy.commandable.set_command{type = defines.command.go_to_location, destination = h.position, radius = 8,
        distraction = defines.distraction.none}
    end
  end
  t.run = nil
end

-- One step of a run: plant at the spot it has reached, then on to the next. Returns "done", "lost" or nil.
local function run_step(b, t)
  local r = t.run
  if not r.buggy.valid then return "lost" end
  local i = r.todo[r.k]
  local sp = t.spots[i]
  local p = r.buggy.position
  local d = (p.x - sp.x) ^ 2 + (p.y - sp.y) ^ 2
  if d < r.best - 1 then r.best, r.best_at = d, game.tick end
  if game.tick - r.best_at > DRIVE then return "lost" end
  if d > 3 * 3 then return end
  local s = game.surfaces[b.surface]
  local name = shared.variant(b.corp, "lp-pylon")
  local q = s.find_non_colliding_position(name, sp, 4, 0.5)
  local e = q and s.create_entity{name = name, position = q, force = b.lander.force, auto_connect = true}
  if e then base.unwire(e) end
  t.line[i] = e
  r.k = r.k + 1
  if r.k > #r.todo then return "done" end
  r.best, r.best_at = math.huge, game.tick
  r.buggy.commandable.set_command{type = defines.command.go_to_location, destination = t.spots[r.todo[r.k]], radius = 1.5,
    distraction = defines.distraction.none}
end

-- The line's end: the pylon at its last spot.
local function end_pylon(b, t)
  local e = t.line[#t.spots]
  return e and e.valid and e or nil
end

function tap.launch(b, pole)
  if not (pole and pole.valid) then return "no pole" end
  local from = nearest(b.pylons, pole.position)
  if not from then return "no pylon" end
  local dx, dy = from.position.x - pole.position.x, from.position.y - pole.position.y
  local len = math.max(1, math.sqrt(dx * dx + dy * dy))
  local goal = {x = pole.position.x + dx / len * GAP, y = pole.position.y + dy / len * GAP}
  -- Out of every turret's reach (the heist's route); no way round, no tap.
  local route = ops.route(b, {from.position.x, from.position.y}, {goal.x, goal.y}, {turrets = true})
  if not route then return "no route" end
  local points = {{x = from.position.x, y = from.position.y}}
  for _, w in ipairs(route) do table.insert(points, {x = w[1], y = w[2]}) end
  table.insert(points, goal)
  local spots = spots_along(points)
  local cost = #spots * (shared.cost["lp-pylon"] or 0)
  if b.parts < cost then return "short of parts" end
  local u = buggy(b)
  if not u then return "no buggy" end
  b.parts = b.parts - cost
  b.tap = {phase = "lay", pole = pole, owner = pole.force.name, spots = spots, line = {}, goal = goal, started = game.tick}
  local todo = {}
  for i = 1, #spots do todo[i] = i end
  drive(b, b.tap, u, todo)
  b.taps = (b.taps or 0) + 1
  base.trace(b, string.format("tap %d: a buggy lays a line of %d pylons toward a %s at %.0f,%.0f", b.taps, #spots,
    pole.name, pole.position.x, pole.position.y))
  return "launched"
end

local function over(b, t, why)
  run_over(b, t)
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
  -- The buggy sets the tap by the pole on its way home.
  local p = s.find_non_colliding_position("lp-power-tap", t.pole.position, 3, 0.5)
  local e = p and s.create_entity{name = "lp-power-tap", position = p, force = b.lander.force}
  if not e then return over(b, t, "no room by the pole") end
  local last = end_pylon(b, t)
  local r = s.create_entity{name = "lp-power-receiver", position = last.position, force = b.lander.force}
  r.destructible = false
  t.tap, t.receiver, t.phase, t.draw, t.next_step, t.taken = e, r, "draw", START, game.tick + (storage.tap_step or STEP), 0
  t.cable = rendering.draw_line{from = e, to = last, surface = s, color = {0.85, 0.5, 0.2, 0.9}, width = 2}
  base.trace(b, string.format("tap clamped at %.0f,%.0f, %d W to start", e.position.x, e.position.y, START))
end

local function step(b, t)
  if t.phase == "lay" then
    if not t.pole.valid then return over(b, t, "the pole is gone") end
    local r = run_step(b, t)
    if r == "lost" then return over(b, t, "the buggy was lost on the way (the line left as it stands)") end
    if r == "done" then
      local last = end_pylon(b, t)
      if not (last and last.electric_network_id == base.network(b)) then
        return over(b, t, "the line did not reach the camp's network")
      end
      clamp(b, t)
      run_over(b, t)
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
  -- A repair run: a buggy to the line's missing pylons (killed on the way, another after REPAIR_WAIT).
  if t.run then
    local r = run_step(b, t)
    if r == "lost" then
      base.trace(b, "tap: the repair buggy was lost")
      run_over(b, t)
      t.next_repair = game.tick + REPAIR_WAIT
    elseif r == "done" then
      base.trace(b, "tap: the line mended")
      run_over(b, t)
    end
  elseif not home and game.tick >= (t.next_repair or 0) then
    local todo = {}
    for i = 1, #t.spots do
      if not (t.line[i] and t.line[i].valid) then table.insert(todo, i) end
    end
    local cost = #todo * (shared.cost["lp-pylon"] or 0)
    local u = #todo > 0 and b.parts >= cost and buggy(b)
    if u then
      b.parts = b.parts - cost
      drive(b, t, u, todo)
      base.trace(b, string.format("tap: the line is cut; a buggy goes to mend %d pylons", #todo))
    end
  end
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

-- Exposed poles it has seen (intel's line cells), nearest its pylons first; the first it can reach unseen.
local function consider(b)
  if storage.tap_off or not (shared.CORPS[b.corp].temper or {}).taps then return end
  if b.fallen or b.quiescent or not b.mature or game.tick < (b.next_tap or 0) then return end
  local owner = war.at_war(b)
  if not owner then return end
  local s = game.surfaces[b.surface]
  local cands = {}
  for _, t in pairs(b.intel and b.intel.targets or {}) do
    local proto = t.kind and prototypes.entity[t.kind]
    -- Exposed: no turret reaches it (intel's exposure). Intel's line cells (no turret within 60) were too strict: on a
    -- deathworld base of 205 gun turrets the camps knew 0 to 2 such poles in 3 hours, and tapped none.
    local exposed = t.line or (t.exposure or 1) == 0
    if t.owner == owner and exposed and t.pos and proto and proto.type == "electric-pole" and not ops.marked(b, t.pos) then
      local pole = s.find_entities_filtered{type = "electric-pole", force = owner, position = t.pos, radius = 1, limit = 1}[1]
      local d
      if pole then _, d = nearest(b.pylons, pole.position) end
      if pole and d and d <= RANGE and pole.electric_network_id
        and s.count_entities_filtered{position = pole.position, radius = SAFE, force = owner,
          type = {"ammo-turret", "electric-turret", "fluid-turret"}, limit = 1} == 0 then
        table.insert(cands, {pole, d})
      end
    end
  end
  table.sort(cands, function(x, y) return x[2] < y[2] end)
  local why
  for k = 1, math.min(3, #cands) do
    why = tap.launch(b, cands[k][1])
    if why == "launched" then return end
  end
  -- Why not (traced once in a while): how many exposed poles it knows, how many in reach.
  if game.tick >= (b.tap_said or 0) then
    b.tap_said = game.tick + 30 * 3600
    local lines = 0
    for _, t in pairs(b.intel and b.intel.targets or {}) do
      local proto = t.kind and prototypes.entity[t.kind]
      if t.owner == owner and (t.line or (t.exposure or 1) == 0) and proto and proto.type == "electric-pole" then
        lines = lines + 1
      end
    end
    base.trace(b, string.format("tap: none (%d exposed poles known, %d in reach and unguarded%s)", lines, #cands,
      why and (", the last: " .. why) or ""))
  end
  b.next_tap = game.tick + 5 * 3600
end

-- debug_tap: a tap from settlement b on the player pole nearest pos.
function tap.debug(b, pos)
  local pole = game.surfaces[b.surface].find_entities_filtered{type = "electric-pole", force = "player", position = pos,
    radius = 10, limit = 1}[1]
  -- A buggy if none is at home (a young camp), as /lp flare does.
  local has
  for _, u in ipairs(b.garrison) do if u.valid and shared.kind_of(u.name) == "lp-buggy" then has = true end end
  if not has and b.lander.valid then
    local s = b.lander.surface
    local name = shared.variant(b.corp, "lp-buggy")
    local q = s.find_non_colliding_position(name, b.lander.position, 20, 1)
    local u = q and s.create_entity{name = name, position = q, force = b.lander.force}
    if u then table.insert(b.garrison, u) end
  end
  return tap.launch(b, pole)
end
function tap.state(b)
  local t = b.tap
  if not t then return {} end
  local n = 0
  for i = 1, #t.spots do if t.line[i] and t.line[i].valid then n = n + 1 end end
  return {phase = t.phase, draw = t.draw, taken = t.taken, watts = b.tap_watts, pylons = n, spots = #t.spots,
    run = t.run ~= nil, tap = t.tap and t.tap.valid and {t.tap.position.x, t.tap.position.y}}
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
