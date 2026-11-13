-- The prowl (Grubstake; the user, 2026-11-01: "Grubstake might steal buildings instead of destroying them", and its
-- deathworld10x mine "un defended"). A camp knows only what its sensors saw near it and along the line to the player's
-- spawn (intel's survey), so a thief never learned of an outpost round the far side: on the reference laser base it knew
-- only the core's substations, on deathworld10x never the player's undefended mine. Every AGAIN a camp sends one buggy
-- round the player's base on a ring clear of every turret's reach, POINTS points, each pushed out from the base until no
-- turret covers it; what the buggy passes within SIGHT goes into the camp's intel (ops.sense_at), as any unit's sight
-- does. Then it drives home and rejoins the garrison. The tell: a buggy circling at the edge of the guns. Killed, the
-- next goes after COOLDOWN, its ring keeping DANGER off where it died. On for corporations that prowl (shared.CORPS
-- prowls: Grubstake); debug_tune prowl = false turns it off.
local shared = require("__landing-party__.shared")
local base = require("__landing-party__.scripts.base")
local ops = require("__landing-party__.scripts.ops")
local pool = require("__landing-party__.scripts.pool")
local threat = require("__landing-party__.scripts.threat")

local prowl = {}
local POINTS = 12
local SIGHT = 60
local BAND, BANDS = 90, 3       -- each prowl's ring this much further out than the last, this many, then the edge again
local SPARE = 8                -- tiles beyond a turret's reach its ring keeps
local PUSH = 120               -- how far out a point is pushed looking for ground no turret covers
local AGAIN = 15 * 60 * 60     -- after a prowl home
local COOLDOWN = 20 * 60 * 60  -- after a buggy lost
local STEP = 120               -- ticks between looks
local STUCK = 60 * 60          -- no nearer its point for this long: the next point
local ARRIVE = 10
local LEG_DEPTH = 3            -- middle points a leg may get, halving it each time
local LEG_MAX = 20             -- tiles a leg at most
local DANGER = 40              -- tiles round where a buggy died that its ring keeps out of, for DANGER_TICKS
local DANGER_TICKS = 2 * 60 * 60 * 60

local function trace(b, msg) if base.trace then base.trace(b, "prowl: " .. msg) end end
local function is_buggy(u) return u.valid and shared.kind_of(u.name) == "lp-buggy" end

local function foes_of(b)
  local out = {}
  for _, f in pairs(game.forces) do
    if shared.is_player_force(f) and not f.get_cease_fire(b.force) then out[#out + 1] = f end
  end
  return out
end

-- Its ring: round the player's spawn, as far out as the edge its survey found (b.front), each point pushed outward
-- until no turret of the player's covers it.
local function ring(b, s, f)
  local sp = f.get_spawn_position(s)
  local front = b.front and b.front[f.name]
  local r = front and math.sqrt((front[1] - sp.x) ^ 2 + (front[2] - sp.y) ^ 2)
    or 0.6 * math.sqrt((b.origin.x - sp.x) ^ 2 + (b.origin.y - sp.y) ^ 2)
  -- Each prowl a band further out, BANDS of them, BAND apart, then the edge again: a ring at the guns' edge sees SIGHT
  -- either side of it, and an outpost 150 from spawn lay past one at 70 (prowl, 0.2.374's site on 12345).
  r = r + (b.prowl_band or 0) * BAND
  -- Its first point the one nearest the camp, so it sets out toward the base, not across it.
  local a0 = math.atan2(b.origin.y - sp.y, b.origin.x - sp.x)
  local pts = {}
  for k = 0, POINTS - 1 do
    local a = a0 + k * 2 * math.pi / POINTS
    local p
    for out = 0, PUSH, 10 do
      local q = {x = sp.x + math.cos(a) * (r + out), y = sp.y + math.sin(a) * (r + out)}
      if not s.is_chunk_generated{math.floor(q.x / 32), math.floor(q.y / 32)} then break end
      if threat.covering(s, q, {f}, 1, SPARE) == 0 then p = q; break end
    end
    -- Not where a buggy of its died lately (on deathworld10x one died at its second point ten prowls running).
    for _, dz in ipairs(b.prowl_danger or {}) do
      if p and game.tick < dz.till and (p.x - dz.pos[1]) ^ 2 + (p.y - dz.pos[2]) ^ 2 <= DANGER * DANGER then p = nil end
    end
    if p then
      local q = s.find_non_colliding_position(shared.variant(b.corp, "lp-buggy"), p, 12, 1)
      if q then pts[#pts + 1] = {q.x, q.y} end
    end
  end
  -- Each leg clear too, not its ends alone: a point dropped (a danger zone, ground not generated) left a leg across the
  -- gap that cut inside the ring, and on 0.2.370's 12345 prowl its buggy died crossing one under the guns, twice. A leg
  -- with a gun's reach on it gets a middle point, pushed out from spawn until no gun covers it, LEG_DEPTH deep.
  local function covered(x, y) return threat.covering(s, {x = x, y = y}, {f}, 1, SPARE) > 0 end
  local function leg(a, c, depth, out)
    local hit = false
    for t = 0.25, 0.75, 0.25 do
      if covered(a[1] + (c[1] - a[1]) * t, a[2] + (c[2] - a[2]) * t) then hit = true; break end
    end
    if hit and depth > 0 then
      local mx, my = (a[1] + c[1]) / 2, (a[2] + c[2]) / 2
      local dx, dy = mx - sp.x, my - sp.y
      local dl = math.max(1, math.sqrt(dx * dx + dy * dy))
      local m
      for push = 0, PUSH, 10 do
        local qx, qy = mx + dx / dl * push, my + dy / dl * push
        if not covered(qx, qy) then m = {qx, qy}; break end
      end
      if m then
        leg(a, m, depth - 1, out)
        out[#out + 1] = m
        leg(m, c, depth - 1, out)
        return
      end
    end
  end
  -- The ring closed, back to its first point (the nearest the camp), and home from there: from its last point straight
  -- home, its buggy crossed the base under the guns (prowl, 0.2.370's 12345, "lost at point 17 of 16").
  if #pts >= 3 then pts[#pts + 1] = {pts[1][1], pts[1][2]} end
  local full = {}
  for i, q in ipairs(pts) do
    full[#full + 1] = q
    local nxt = pts[i + 1]
    if nxt then
      leg(q, nxt, LEG_DEPTH, full)
      -- And no leg longer than LEG_MAX, each cut pushed clear: on a long one the engine's way wandered 11 tiles in
      -- from the line, round what stood on it, into a gun's reach.
      local last = full[#full]
      local dl = math.sqrt((nxt[1] - last[1]) ^ 2 + (nxt[2] - last[2]) ^ 2)
      local cuts = math.floor(dl / LEG_MAX)
      for c = 1, cuts do
        local t = c / (cuts + 1)
        local mx, my = last[1] + (nxt[1] - last[1]) * t, last[2] + (nxt[2] - last[2]) * t
        local dx, dy = mx - sp.x, my - sp.y
        local d0 = math.max(1, math.sqrt(dx * dx + dy * dy))
        for push = 0, PUSH, 10 do
          local qx, qy = mx + dx / d0 * push, my + dy / d0 * push
          if not covered(qx, qy) then full[#full + 1] = {qx, qy}; break end
        end
      end
    end
  end
  return full
end

-- Then standing, not idle: its order done at 4 tiles from a point, the engine set the buggy wandering until the next
-- step (2 s), and wandering it went for the player's buildings under the guns (prowl, 0.2.370's 12345: its order
-- seen as wander, 6, between steps; killed at -34,34).
local function go(u, p)
  u.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
    commands = {
      {type = defines.command.go_to_location, destination = {p[1], p[2]}, radius = 4, distraction = defines.distraction.none},
      {type = defines.command.stop, ticks_to_wait = 10 * 60, distraction = defines.distraction.none}}}
end

local function home_of(b)
  for _, d in ipairs(b.depots or {}) do if d.valid then return d end end
  return b.lander and b.lander.valid and b.lander or nil
end

-- Its way asked of the engine first, leg by leg (surface.request_path, its buggy's own box and mask), and followed as the
-- engine gives it: told only its points, the buggy took the engine's own way between them, and where a cliff barred the
-- way out there it found one in through the base, under the guns (prowl, 0.2.374's probe: five legs running on 12345 with
-- no straight way, the buggy killed at -38,40 each prowl). The ring runs to the first leg with no way, or a way some gun
-- covers, and back the way it came; at the least PLAN_MIN legs, else none this time.
local PLAN_MIN = 3
local PLAN_WAIT = 10 * 60      -- ticks the engine's answers are waited for
local PATH_GAP = 16            -- tiles between the points of the engine's way it follows
local PATH_SPARE = 2           -- tiles past a gun's reach a path's waypoint keeps

-- One direction's route: its legs from leg 0 while each has a way and no gun covers it; its count of good legs, and why
-- it stopped.
local function run_of(s, f, legs, n)
  local route, good, why = {}, 0, nil
  for i = 0, n - 1 do
    local leg = legs[i]
    if not leg then why = string.format("leg %d %s", i, leg == false and "no way" or "no answer"); break end
    for _, w in ipairs(leg) do
      -- (A gun's own reach and PATH_SPARE past it, not SPARE: that is the points' margin, and the engine's way round what
      -- stands on it bent a tile or two inside it on every leg that turned back.)
      if threat.covering(s, {x = w[1], y = w[2]}, {f}, 1, PATH_SPARE) > 0 then why = string.format("leg %d under a gun", i); break end
    end
    if why then break end
    for _, w in ipairs(leg) do route[#route + 1] = w end
    good = good + 1
  end
  return route, good, why
end

local function launch_plan(b, tick)
  local plan = b.prowl_plan
  b.prowl_plan = nil
  local s = game.surfaces[b.surface]
  local foes = foes_of(b)
  if #foes == 0 then return end
  local f = foes[1]
  -- Out one way round till its way ends, back; out the other way, back (a barrier on one side, as on 12345, left the far
  -- side unseen: the outpost there, never known).
  local fwd, gf, wf = run_of(s, f, plan.legs, plan.n)
  local rev, gr, wr = run_of(s, f, plan.rlegs or {}, plan.n)
  local route = {}
  local function out_and_back(r)
    for _, w in ipairs(r) do route[#route + 1] = w end
    for i = #r - 1, 1, -1 do route[#route + 1] = r[i] end
  end
  if gf >= PLAN_MIN + 1 then out_and_back(fwd) end
  if gf < plan.n and gr >= PLAN_MIN + 1 then out_and_back(rev) end
  if #route == 0 then
    trace(b, string.format("none (its way ran %d and %d of %d legs: %s; %s)", gf, gr, plan.n, wf or "?", wr or "?"))
    b.prowl_next = tick + AGAIN
    return
  end
  local u = pool.take(b, 1, pool.GUARD, is_buggy)[1]
  if not u then b.prowl_next = tick + 5 * 3600; return end
  b.prowl = {unit = u, pts = route, k = 1, best = math.huge, since = tick, started = tick, seen0 = 0}
  for _ in pairs(b.intel and b.intel.targets or {}) do b.prowl.seen0 = b.prowl.seen0 + 1 end
  b.prowls = (b.prowls or 0) + 1
  go(u, route[1])
  trace(b, string.format("a buggy sets out round the base, %d of %d legs one way%s (%d points on the engine's way)%s", gf,
    plan.n, gf < plan.n and string.format(" and %d the other", gr) or "", #route,
    gf < plan.n and string.format("; stopped by %s, and %s", wf or "?", wr or "?") or ""))
end

local function start(b, tick)
  local s = game.surfaces[b.surface]
  local foes = foes_of(b)
  if #foes == 0 then return end
  local pts = ring(b, s, foes[1])
  local h = home_of(b)
  if #pts < 3 or not h then
    trace(b, string.format("none (%d points of its ring clear of the guns)", #pts))
    b.prowl_next = tick + AGAIN
    return
  end
  local proto = prototypes.entity[shared.variant(b.corp, "lp-buggy")]
  if not proto then return end
  -- Leg 0 from home to the first point, then point to point. (From a free spot by home: a path asked from inside the
  -- depot found none, and no prowl went.) And the other way round: home to the last point, back along the ring.
  local hp = s.find_non_colliding_position(proto.name, h.position, 24, 1) or h.position
  local stops, rstops = {{hp.x, hp.y}}, {{hp.x, hp.y}}
  for _, q in ipairs(pts) do stops[#stops + 1] = q end
  for i = #pts, 1, -1 do rstops[#rstops + 1] = pts[i] end
  b.prowl_plan = {n = #stops - 1, legs = {}, rlegs = {}, left = 2 * (#stops - 1), asked = tick}
  storage.prowl_paths = storage.prowl_paths or {}
  for _, dir in ipairs({{stops, "legs"}, {rstops, "rlegs"}}) do
    local st = dir[1]
    for i = 1, #st - 1 do
      local id = s.request_path{bounding_box = proto.collision_box, collision_mask = proto.collision_mask,
        start = {st[i][1], st[i][2]}, goal = {st[i + 1][1], st[i + 1][2]}, force = b.force, radius = 4}
      storage.prowl_paths[id] = {base = b.id, leg = i - 1, set = dir[2]}
    end
  end
  b.prowl_next = tick + AGAIN
end

-- The engine's answer to one of its legs (on_script_path_request_finished, control.lua): its waypoints kept, every
-- PATH_GAP apart and the last; none, the leg false. All in, it goes.
function prowl.on_path(e)
  local r = storage.prowl_paths and storage.prowl_paths[e.id]
  if not r then return end
  storage.prowl_paths[e.id] = nil
  local b = storage.bases and storage.bases[r.base]
  local plan = b and b.prowl_plan
  if not plan then return end
  -- (One a PATH_GAP of tiles and the last, not every few waypoints: at every fourth a ring was 785 points, one a step,
  -- and a prowl took 26 minutes, its buggy out of the garrison all that time; strip claim, plate grubstake.)
  local pts = false
  if e.path and #e.path > 0 then
    pts = {}
    local lx, ly
    for i, w in ipairs(e.path) do
      local x, y = w.position.x, w.position.y
      if i == #e.path or not lx or (x - lx) ^ 2 + (y - ly) ^ 2 >= PATH_GAP * PATH_GAP then
        pts[#pts + 1] = {x, y}; lx, ly = x, y
      end
    end
  end
  plan[r.set or "legs"][r.leg] = pts
  plan.left = plan.left - 1
  if plan.left <= 0 then launch_plan(b, game.tick) end
end

local function finish(b, tick, lost)
  local p = b.prowl
  b.prowl_band = ((b.prowl_band or 0) + 1) % BANDS
  local n = 0
  for _ in pairs(b.intel and b.intel.targets or {}) do n = n + 1 end
  if lost then
    b.prowl_danger = b.prowl_danger or {}
    local at = p.last or p.pts[p.k]
    table.insert(b.prowl_danger, {pos = {at[1], at[2]}, till = tick + DANGER_TICKS})
    trace(b, string.format("the buggy was lost at point %d of %d (%d cells known, %d before)", p.k, #p.pts, n, p.seen0))
    b.prowl_next = tick + COOLDOWN
  else
    trace(b, string.format("the buggy is home (%d cells known, %d before)", n, p.seen0))
    pool.give_one(b, p.unit)
    b.prowl_next = tick + AGAIN
  end
  b.prowl = nil
end

local function step(b, tick)
  local p = b.prowl
  local u = p.unit
  if not u.valid then return finish(b, tick, true) end
  p.last = {u.position.x, u.position.y}
  ops.sense_at(b, u.position, SIGHT)
  local dest = p.home and p.home or p.pts[p.k]
  local d = math.sqrt((u.position.x - dest[1]) ^ 2 + (u.position.y - dest[2]) ^ 2)
  if d < ARRIVE or tick - p.since > STUCK then
    if p.home then return finish(b, tick, false) end
    p.fails = 0
    p.k = p.k + 1
    -- (Past every point already within reach, in one step.)
    while p.pts[p.k] and (u.position.x - p.pts[p.k][1]) ^ 2 + (u.position.y - p.pts[p.k][2]) ^ 2 < ARRIVE * ARRIVE do p.k = p.k + 1 end
    p.best, p.since = math.huge, tick
    if p.k > #p.pts then
      local h = home_of(b)
      if not h then return finish(b, tick, false) end
      p.home = {h.position.x, h.position.y}
    end
    go(u, p.home or p.pts[p.k])
  elseif d < p.best - 2 then
    p.best, p.since = d, tick
  end
  -- Its order kept: a way it could not find left the buggy without one, and it went home across the base under the
  -- guns (prowl, 0.2.370's 12345: from 58,4 toward its point at 68,10 it turned back and died at 45,-8).
  local c = u.valid and u.commandable
  local cmd = c and c.command
  if c and not (cmd and (cmd.type == defines.command.compound or cmd.type == defines.command.stop
      or cmd.type == defines.command.go_to_location)) then
    go(u, p.home or p.pts[p.k])
  end
end

-- Its buggy's order failed (on_ai_command_completed, control.lua): no way to that point (five legs running in a row with no
-- path on 12345, a barrier between them; the buggy, its order failed, idled and wandered into the guns at -38,40, prowl,
-- 0.2.374's probe). On to the next point at once; three failed running, home.
function prowl.on_command_completed(e)
  if e.result ~= defines.behavior_result.fail then return end
  for _, b in pairs(storage.bases or {}) do
    local p = b.prowl
    if p and p.unit and p.unit.valid and p.unit.unit_number == e.unit_number then
      p.fails = (p.fails or 0) + 1
      if p.home or p.fails >= 3 then
        local h = home_of(b)
        p.home = h and {h.position.x, h.position.y} or p.home
        p.k = #p.pts + 1
        if p.home then go(p.unit, p.home) end
        trace(b, string.format("its way failed %d times running: home", p.fails))
      else
        p.k = p.k + 1
        p.best, p.since = math.huge, game.tick
        local dest = p.pts[p.k]
        if dest then go(p.unit, dest) else
          local h = home_of(b)
          if h then p.home = {h.position.x, h.position.y}; go(p.unit, p.home) end
        end
      end
      return
    end
  end
end

function prowl.tick(tick)
  if storage.prowl == false or tick % STEP ~= 0 then return end
  for _, b in pairs(storage.bases or {}) do
    if not b.fallen and b.lander and b.lander.valid and (shared.CORPS[b.corp] or {}).prowls then
      if b.prowl then step(b, tick)
      elseif b.prowl_plan then
        -- (Its answers waited for PLAN_WAIT; then it goes with what came back.)
        if tick - b.prowl_plan.asked > PLAN_WAIT then launch_plan(b, tick) end
      elseif tick >= (b.prowl_next or 0) and b.intel then start(b, tick) end
    end
  end
end

return prowl
