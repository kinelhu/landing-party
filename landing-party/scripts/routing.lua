-- Routing (split from ops.lua, 2026-10-18, along the AI graph's seams: docs/ai-graph.md): where a raid stages (outside
-- every turret's reach and the player's walls), how it gets there (sneak_route: round turrets, nests and water, through
-- corridors cleared of nests), where it breaches, and whether a push through biter country is worth it. The code is as
-- it was in ops; install runs it with ops' helpers bound (K) and returns what ops calls.
local shared = require("__landing-party__.shared")
local threat = require("__landing-party__.scripts.threat")

local routing = {}

function routing.install(ops, K)
local enemies, ladder, STAND_OFF, TURRETS = K.enemies, K.ladder, K.STAND_OFF, K.TURRETS
-- A staging point on the line home from the target, at least `off` out: beyond every turret's reach and outside
-- the player's walls (no wall between it and home). Staged at a fixed offset, a raid's point fell inside a walled
-- base (-56,31 behind a wall at 70): it timed out there and attacked from outside, unhurt and harmless.
local outside_ray
-- The staging point: on the line from the target toward home, else (water, walls) on lines turned up to 90 degrees
-- either side: across a lake from home, every substation's line ended in the water, and a camp sent nothing in three
-- hours (visit nw).
local TURNS = {0, 20, -20, 40, -40, 60, -60, 80, -80}
local function outside(b, t, ux, uy, off, len)
  for _, deg in ipairs(TURNS) do
    local a = math.rad(deg)
    local vx, vy = ux * math.cos(a) - uy * math.sin(a), ux * math.sin(a) + uy * math.cos(a)
    local p = outside_ray(b, t, vx, vy, off, len, true)
    if p then return p end
  end
  return outside_ray(b, t, ux, uy, off, len, false)
end
outside_ray = function(b, t, ux, uy, off, len, strict)
  local s = game.surfaces[b.surface]
  local foes = enemies(game.forces[b.force])
  local function walled(p)
    for k = 4, math.min(160, len - 1), 4 do
      if s.count_entities_filtered{position = {p[1] + ux * k, p[2] + uy * k}, radius = 2.5, type = {"wall", "gate"},
        force = foes, limit = 1} > 0 then return true end
    end
    return false
  end
  for d = off, math.min(len, off + 160), 4 do
    local p = {t.pos[1] + ux * d, t.pos[2] + uy * d}
    -- Not among nests either (a staging point 35 tiles from a worm could never be reached round biter country).
    -- (t.margin: what a big herd needs past that, its own half-width: herd.lua waist.)
    if s.count_entities_filtered{position = p, radius = STAND_OFF + (t.margin or 0), type = TURRETS, force = foes, limit = 1} == 0
      and (t.owner == "enemy" or s.count_entities_filtered{position = p, radius = 50, type = {"unit-spawner", "turret"},
        force = shared.NEST_FORCES, limit = 1} == 0)
      -- Nor by water: staged on a lake shore, a raid on a substation found no way to its staging point, the same six
      -- points one after another for three hours (visit nw).
      and s.count_tiles_filtered{position = p, radius = 8, collision_mask = "water_tile", limit = 1} == 0
      and not walled(p) then
      return p
    end
  end
  -- Nowhere better: at the stand-off, unless that is water (nil: no staging point; a substation on a pier out in a
  -- lake was staged for in deep water, every few minutes for three hours, visit nw). A turned line takes only a clean
  -- point.
  if strict then return nil end
  local p = {t.pos[1] + ux * off, t.pos[2] + uy * off}
  if s.count_tiles_filtered{position = p, radius = 2, collision_mask = "water_tile", limit = 1} > 0 then return nil end
  return p
end

-- Sneaking and breaching (Grubstake's temper; the user: "do they try to avoid turrets? And perhaps make holes in
-- undefended sections of the wall?"). From its staging point a sneaking raid plans its approach on a SNEAK_CELL grid
-- (A*), round every cell within a known turret's reach (its prototype's range, threat.lua, plus SNEAK_MARGIN) and water, exposed only in
-- the last SNEAK_OPEN tiles to the target; it walks the route as waypoints. Walls round the target (within
-- BREACH_RADIUS): it picks the wall piece the fewest turrets can reach, knocks it and its neighbour out (a two-tile gap,
-- buggies fit), and goes through. Serenity keeps its straight, disciplined approach.
local SNEAK_CELL, SNEAK_MARGIN, SNEAK_OPEN, SNEAK_BOX = 6, 3, 16, 120
-- What blocks a herd's way (opts.solid): the foe's buildings, not its units, nor what a unit walks over (rails and belts:
-- counted, a deathworld's rail network and belt lines fenced off hundreds of tiles, and its herds staged 200 to 590
-- tiles out and marched that far under its guns to the wall).
local SOLID_TYPES = {"wall", "gate", "ammo-turret", "electric-turret", "fluid-turret", "assembling-machine", "furnace",
  "mining-drill", "inserter", "underground-belt", "splitter", "container", "logistic-container", "pipe", "pipe-to-ground",
  "storage-tank", "lab", "roboport", "solar-panel", "accumulator", "boiler", "generator", "radar", "beacon", "rocket-silo",
  "train-stop", "reactor", "heat-pipe", "pump", "offshore-pump"}
local BREACH_RADIUS = 30
-- A turret's range, from its prototype (threat.lua; a vanilla table here read modded turrets as guns).
local function range(e) return threat.reach(e) - threat.MARGIN end

-- Biter country (the user: "raids and sieges will also need to cross biter country to reach us sometimes"): every
-- corporation's marches route round spawners and worms, each by how far it is a danger (threat.nest_reach: a worm's range,
-- a spawner's biters' sight round it; a flat 50 for every worm, a behemoth's reach, and 30 for every spawner before) and
-- SNEAK_MARGIN and a cell; only Grubstake also keeps out of turret reach. opts: {turrets = bool, nests = bool}.
-- Corridors: where spawners died lately (any force: a clearance, the player's artillery, a landing's burn); within
-- CORRIDOR_RADIUS of one, nests do not block a cell (Grubstake follows Serenity's survey crews).
local CORRIDOR_TICKS, CORRIDOR_RADIUS = 30 * 3600, 30
function ops.cleared(surface, pos)
  storage.corridors = storage.corridors or {}
  table.insert(storage.corridors, {surface = surface.index, pos = {pos.x, pos.y}, tick = game.tick})
  -- Oldest first: drop the expired from the front.
  while storage.corridors[1] and (game.tick - storage.corridors[1].tick > CORRIDOR_TICKS or #storage.corridors > 400) do
    table.remove(storage.corridors, 1)
  end
end
-- Within box ({{x1, y1}, {x2, y2}}) when given: a megabase's artillery kills spawners all the time, far from any route
-- (a raid that failed for nests was planned again every two minutes on that, visit nw).
function ops.cleared_since(surface, tick, box)
  for i = #(storage.corridors or {}), 1, -1 do
    local c = storage.corridors[i]
    if c.tick <= tick then return false end
    if c.surface == surface and (not box or (c.pos[1] >= box[1][1] and c.pos[1] <= box[2][1] and c.pos[2] >= box[1][2]
      and c.pos[2] <= box[2][2])) then return true end
  end
  return false
end
-- A corporation at cease-fire with the biters, both ways (shared.CORPS temper.pact, control.lua).
function ops.pact(force)
  local f = game.forces[force]
  return f and game.forces.enemy and f.get_cease_fire("enemy") and game.forces.enemy.get_cease_fire(f) or false
end
local ENCLOSED_PROBE = 3000
local NEIGHBOURS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
local function sneak_route(b, from, to, opts, wide)
  opts = opts or {turrets = true, nests = true}
  -- opts.cell: a coarser grid for a long way (Synthexis's herds: on 6-tile cells a 1,000-tile route ran dry, wide or not,
  -- on 11 of 12 waves of two visits, and the herd walked straight into the player's lasers).
  local SNEAK_CELL = opts.cell or SNEAK_CELL
  local SNEAK_BOX = wide and 3 * SNEAK_BOX or SNEAK_BOX
  local s = game.surfaces[b.surface]
  local foes = enemies(game.forces[b.force])
  local x0 = math.min(from[1], to[1]) - SNEAK_BOX
  local y0 = math.min(from[2], to[2]) - SNEAK_BOX
  local w = math.ceil((math.max(from[1], to[1]) + SNEAK_BOX - x0) / SNEAK_CELL)
  local h = math.ceil((math.max(from[2], to[2]) + SNEAK_BOX - y0) / SNEAK_CELL)
  local box = {{x0 - 60, y0 - 60}, {x0 + w * SNEAK_CELL + 60, y0 + h * SNEAK_CELL + 60}}
  local turrets = opts.turrets and s.find_entities_filtered{area = box, type = {"ammo-turret", "electric-turret",
    "fluid-turret"}, force = foes} or {}
  -- Air units (opts.worms) keep clear of worms only: spawners do not shoot.
  -- A pact with the biters (Grubstake: "We don't fight bugs"): nests and worms let it pass (a cease-fire, both ways).
  local nests = (opts.nests and not ops.pact(b.force) and s.find_entities_filtered{area = box, type = {"unit-spawner", "turret"}, force = shared.NEST_FORCES})
    or (opts.worms and s.find_entities_filtered{area = box, type = "turret", force = shared.NEST_FORCES}) or {}
  local function centre(i, j) return x0 + (i + 0.5) * SNEAK_CELL, y0 + (j + 0.5) * SNEAK_CELL end
  -- Each turret's and nest's reach marked on the grid once (a cell then looks itself up): testing buckets of them per
  -- cell took 300 ms on a failed route through a deathworld (12,000 cells), and before the buckets, seconds against a
  -- megabase's thousands of turrets.
  local function mark(list, reach)
    local out = {}
    for _, e in ipairs(list) do
      local r = reach(e)
      local ex, ey = e.position.x, e.position.y
      for i = math.max(0, math.floor((ex - r - x0) / SNEAK_CELL)), math.min(w - 1, math.floor((ex + r - x0) / SNEAK_CELL)) do
        for j = math.max(0, math.floor((ey - r - y0) / SNEAK_CELL)), math.min(h - 1, math.floor((ey + r - y0) / SNEAK_CELL)) do
          local cx, cy = centre(i, j)
          if (ex - cx) ^ 2 + (ey - cy) ^ 2 <= r * r then out[i * h + j] = true end
        end
      end
    end
    return out
  end
  -- (opts.margin: a big herd's half-width besides, herd.lua waist: a wave of 200 is a blob 20 tiles wide.)
  local tmark = mark(turrets, function(e) return range(e) + SNEAK_MARGIN + (opts.margin or 0) end)
  -- Spawners and worms marked apart: a corridor (a spawner killed lately) lifts the spawners' marks, never the worms'
  -- (they shoot). Kessler-Hayashi's orbital sweeps (war.lua) kill spawners every 10 minutes, worms grew back inside the
  -- 30 minutes its corridors lasted, and its siege haulers routed through them: five of six on fed nw killed by big worms
  -- 105 to 140 tiles out (2026-11-02).
  local spawners, worms = {}, {}
  for _, e in ipairs(nests) do table.insert(e.type == "unit-spawner" and spawners or worms, e) end
  -- (And a cell besides: marks are tested at cells' middles and units cut corners between waypoints; at reach and margin
  -- alone a raid's route passed medium worms close enough to lose one raider, and it turned back, scenario pact.)
  local function nest_keep(e) return threat.nest_reach(e) + SNEAK_MARGIN + SNEAK_CELL end
  local nmark = mark(spawners, nest_keep)
  local wmark = mark(worms, nest_keep)
  -- Corridors on this surface within the box, once per route.
  local corr = {}
  for _, c in ipairs(storage.corridors or {}) do
    if c.surface == b.surface and game.tick - c.tick <= CORRIDOR_TICKS
      and c.pos[1] >= box[1][1] and c.pos[1] <= box[2][1] and c.pos[2] >= box[1][2] and c.pos[2] <= box[2][2] then
      table.insert(corr, c.pos)
    end
  end
  local function in_corridor(cx, cy)
    for _, c in ipairs(corr) do
      if (c[1] - cx) ^ 2 + (c[2] - cy) ^ 2 <= CORRIDOR_RADIUS ^ 2 then return true end
    end
    return false
  end
  local blocked = {}
  -- opts.gun_cost: within a turret's reach a cell costs that many times as much instead of being shut (a strike force
  -- walking home, director.lua, 0.2.428: out of a ring of guns by its gap if it has one, else by the shortest way through).
  local dear = {}
  local function open(i, j)
    if i < 0 or j < 0 or i >= w or j >= h then return false end
    local k = i * h + j
    if blocked[k] == nil then
      local cx, cy = centre(i, j)
      local bad = false
      if tmark[k] and (cx - to[1]) ^ 2 + (cy - to[2]) ^ 2 > SNEAK_OPEN ^ 2 then
        if opts.gun_cost then dear[k] = opts.gun_cost else bad = true end
      end
      if not bad and nmark[k] and not in_corridor(cx, cy) then bad = true end
      if not bad and wmark[k] then bad = true end
      -- (On a coarse grid, opts.cell, over more of the cell: water within 2 of a 16-tile cell's middle missed lakeshores,
      -- and the engine walked Synthexis's herds round lakes and cliffs between waypoints, loops of 500 tiles on the
      -- player's deathworld. opts.solid: cliffs and the foe's buildings block too, where a herd cannot pass.)
      local r = opts.cell and SNEAK_CELL / 2 or 2
      if not bad and s.count_tiles_filtered{position = {cx, cy}, radius = r, collision_mask = "water_tile", limit = 1} > 0 then
        bad = true
      end
      if not bad and opts.solid and (s.count_entities_filtered{position = {cx, cy}, radius = r, type = "cliff", limit = 1} > 0
        or s.count_entities_filtered{position = {cx, cy}, radius = r, force = type(opts.solid) == "table" and opts.solid or foes,
          limit = 1, type = SOLID_TYPES} > 0) then
        bad = true
      end
      blocked[k] = bad
    end
    return not blocked[k]
  end
  local function cell(p) return math.floor((p[1] - x0) / SNEAK_CELL), math.floor((p[2] - y0) / SNEAK_CELL) end
  local si, sj = cell(from)
  local ti, tj = cell(to)
  -- A staging point sealed in by turrets (Grubstake's sneaking leg inside a factory's ring): the search from home
  -- flooded the open country outside, 21,000 cells and 80 ms, before it failed, 43 times in three hours (visit nw).
  -- The pocket round the target is small: flooded first from there, within ENCLOSED_PROBE cells, it fails at once
  -- (the same cells and moves as the search, so it fails only where the search would). Bounded by the box's edge is
  -- not sealed: only a pocket walled in all round counts. The wide box has its own grid, so its own probe.
  -- (A partial search, opts.partial, wants the nearest it can reach to a sealed goal: no probe.)
  if not opts.partial then
    local seen, queue, qi, escapes = {[ti * h + tj] = true}, {{ti, tj}}, 1, false
    while queue[qi] and #queue <= ENCLOSED_PROBE and not escapes do
      local ci, cj = queue[qi][1], queue[qi][2]
      qi = qi + 1
      for _, d in ipairs(NEIGHBOURS) do
        local ni, nj = ci + d[1], cj + d[2]
        if (ni == si and nj == sj) or ni < 0 or nj < 0 or ni >= w or nj >= h then escapes = true; break end
        local nk = ni * h + nj
        if not seen[nk] and open(ni, nj) then seen[nk] = true; queue[#queue + 1] = {ni, nj} end
      end
    end
    if not escapes and not queue[qi] then
      local nb = 0
      for _, v in pairs(blocked) do if v then nb = nb + 1 end end
      ops.last_route = {nests = #nests, turrets = #turrets, blocked = nb, cells = w * h, found = false, steps = 0,
        enclosed = #queue}
      if not wide then return sneak_route(b, from, to, opts, true) end
      return nil
    end
  end
  -- A* over the grid, eight neighbours.
  local key = function(i, j) return i * h + j end
  local function hdist(i, j) return math.sqrt((i - ti) ^ 2 + (j - tj) ^ 2) end
  -- Open set as a binary heap on f (stale entries are skipped when popped).
  local heap = {}
  local function push(f, i, j)
    local n = #heap + 1
    heap[n] = {f, i, j}
    while n > 1 do
      local p = math.floor(n / 2)
      if heap[p][1] <= heap[n][1] then break end
      heap[p], heap[n] = heap[n], heap[p]
      n = p
    end
  end
  local function pop()
    local top, last = heap[1], table.remove(heap)
    if #heap > 0 then
      heap[1] = last
      local n = 1
      while true do
        local l, r, m = 2 * n, 2 * n + 1, n
        if heap[l] and heap[l][1] < heap[m][1] then m = l end
        if heap[r] and heap[r][1] < heap[m][1] then m = r end
        if m == n then break end
        heap[m], heap[n] = heap[n], heap[m]
        n = m
      end
    end
    return top
  end
  local g, came = {[key(si, sj)] = 0}, {}
  push(hdist(si, sj), si, sj)
  local closed = {}
  local found = false
  local steps = 0
  -- opts.partial: the cell nearest the goal it reached, for a route there when the goal cannot be reached (Synthexis's
  -- herd: the edge of the turrets' reach nearest its target inside a turreted perimeter, where it breaks in).
  local near, nd = key(si, sj), hdist(si, sj)
  while #heap > 0 and steps < (wide and 16000 or 4000) do
    local _, ci, cj = table.unpack(pop())
    local ck = key(ci, cj)
    if closed[ck] then goto next end
    steps = steps + 1
    if ci == ti and cj == tj then found = true; break end
    closed[ck] = true
    if opts.partial and hdist(ci, cj) < nd then near, nd = ck, hdist(ci, cj) end
    for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}) do
      local ni, nj = ci + d[1], cj + d[2]
      local nk = key(ni, nj)
      if not closed[nk] and ((ni == ti and nj == tj) or open(ni, nj)) then
        local ng = g[ck] + ((d[1] ~= 0 and d[2] ~= 0) and 1.414 or 1) * (dear[nk] or 1)
        if not g[nk] or ng < g[nk] then
          g[nk], came[nk] = ng, ck
          push(ng + hdist(ni, nj), ni, nj)
        end
      end
    end
    ::next::
  end
  local nb = 0
  for _, v in pairs(blocked) do if v then nb = nb + 1 end end
  local exposed = 0
  if found then
    local k = key(ti, tj)
    while k do if dear[k] then exposed = exposed + 1 end; k = came[k] end
  end
  ops.last_route = {nests = #nests, turrets = #turrets, blocked = nb, cells = w * h, found = found, steps = steps,
    exposed = exposed}
  -- Water the box could not get round: once more over a box three times as wide (a lake 100 tiles across kept Grubstake's
  -- raids home for 40 minutes, visit nw; left to the engine, the raiders stood at home: its pathfinder gave up the detour).
  if not found and not wide and steps < 4000 and not opts.partial then return sneak_route(b, from, to, opts, true) end
  if not found and not opts.partial then return nil end
  -- Back from the target, every third cell a waypoint (the engine's pathfinder walks between them).
  local cells = {}
  local k = found and key(ti, tj) or near
  while k do
    table.insert(cells, 1, k)
    k = came[k]
  end
  local route = {}
  for n = 2, #cells - 1 do
    if n % 3 == 0 then
      local i, j = math.floor(cells[n] / h), cells[n] % h
      local cx, cy = centre(i, j)
      table.insert(route, {cx, cy})
    end
  end
  -- A partial route ends at the nearest cell reached (its last point).
  if not found and #cells > 0 then
    local i, j = math.floor(cells[#cells] / h), cells[#cells] % h
    local cx, cy = centre(i, j)
    table.insert(route, {cx, cy})
    ops.last_route.partial = {cx, cy}
  end
  return route
end

ops.route = sneak_route

-- Pushing through biter country (the megabase consult): with no way round, an operation still goes when its target is
-- worth it (effective value PUSH_VALUE, the line and the ladder's triple counted) or the ladder has reached its second
-- rung, through at most PUSH_CROSSINGS nests: an escort of 4 a spawner and 2 a worm near the straight path, times
-- (1 + evolution), fights the way through. Returns the escort's size, or nil (not sent).
local PUSH_VALUE, PUSH_CROSSINGS = 6, 6
local function crossings(b, from, to)
  local s = game.surfaces[b.surface]
  local len = math.sqrt((to[1] - from[1]) ^ 2 + (to[2] - from[2]) ^ 2)
  local seen, sp, worms = {}, 0, 0
  for k = 0, math.max(1, math.floor(len / 20)) do
    local f = k / math.max(1, math.floor(len / 20))
    local p = {from[1] + (to[1] - from[1]) * f, from[2] + (to[2] - from[2]) * f}
    for _, e in pairs(s.find_entities_filtered{position = p, radius = 40, type = {"unit-spawner", "turret"}, force = shared.NEST_FORCES}) do
      if not seen[e.unit_number] then
        seen[e.unit_number] = true
        if e.type == "unit-spawner" then sp = sp + 1 else worms = worms + 1 end
      end
    end
  end
  return sp, worms
end
local function push_escort(b, t, from, to)
  local sp, worms = crossings(b, from, to)
  -- A corporation that besieges clears its way instead of pushing (ops.clearance, the biter-country consult: 27 units
  -- pushed through a wall of worms and 25 died); one that never does, at the top rung, goes through with all it has.
  if (sp + worms) > 0 and shared.capable(b.corp, "siege", 99) then return nil, sp, worms end
  if t.owner and ladder(t.owner, b.force) >= 3 then return 1000, sp, worms end
  if sp + worms > PUSH_CROSSINGS then return nil, sp, worms end
  local worth = (t.value or 0) * (t.line and 2 or 1) * ((t.owner and ladder(t.owner, b.force) >= 1) and 3 or 1)
  if worth < PUSH_VALUE and not (t.owner and ladder(t.owner, b.force) >= 2) then return nil, sp, worms end
  local evo = game.forces.enemy.get_evolution_factor(game.surfaces[b.surface])
  return math.ceil((4 * sp + 2 * worms) * (1 + evo)), sp, worms
end
ops.push_escort = push_escort

-- The wall piece by the target the fewest turrets can reach (ties: nearest the staging point), and its neighbour.
local function breach_point(b, t, from)
  local s = game.surfaces[b.surface]
  local foes = enemies(game.forces[b.force])
  local walls = s.find_entities_filtered{position = t.pos, radius = BREACH_RADIUS, type = {"wall", "gate"}, force = foes}
  if #walls == 0 then return end
  local turrets = s.find_entities_filtered{position = t.pos, radius = BREACH_RADIUS + 30,
    type = {"ammo-turret", "electric-turret", "fluid-turret"}, force = foes}
  local best, bc, bd
  for n, wl in ipairs(walls) do
    if n % 2 == 1 or #walls < 200 then
      -- Reach plus the room a crowd at the wall takes (a piece just out of reach left the raiders gathered round it
      -- inside the flank lasers' reach: 16 of 31 lost and the raid aborted, sneak).
      local c = 0
      for _, e in ipairs(turrets) do
        local r = range(e) + 6
        if (e.position.x - wl.position.x) ^ 2 + (e.position.y - wl.position.y) ^ 2 <= r * r then c = c + 1 end
      end
      local d = (wl.position.x - from[1]) ^ 2 + (wl.position.y - from[2]) ^ 2
      if not bc or c < bc or (c == bc and d < bd) then best, bc, bd = wl, c, d end
    end
  end
  if not best then return end
  local pieces = {best}
  local near = s.find_entities_filtered{position = best.position, radius = 1.5, type = {"wall", "gate"}, force = foes}
  for _, e in ipairs(near) do
    if e ~= best and #pieces < 2 then table.insert(pieces, e) end
  end
  return pieces, bc
end

-- The first wall piece (and its neighbour) on the straight line from `from` to `to`, for a raid that does not sneak:
-- Serenity's raids on substations behind a wall walked its length looking for a way in and gave up 360 tiles off
-- (visit nw).
local function wall_on_line(b, from, to)
  local s = game.surfaces[b.surface]
  local foes = enemies(game.forces[b.force])
  local dx, dy = to[1] - from[1], to[2] - from[2]
  local len = math.sqrt(dx * dx + dy * dy)
  for d = 2, len - 2, 2 do
    local q = {from[1] + dx / len * d, from[2] + dy / len * d}
    local w = s.find_entities_filtered{position = q, radius = 1.5, type = {"wall", "gate"}, force = foes, limit = 1}[1]
    if w then
      local pieces = {w}
      for _, e in ipairs(s.find_entities_filtered{position = w.position, radius = 1.5, type = {"wall", "gate"}, force = foes}) do
        if e ~= w and #pieces < 2 then table.insert(pieces, e) end
      end
      return pieces
    end
  end
end


return {outside = outside, sneak_route = sneak_route, push_escort = push_escort, breach_point = breach_point,
  wall_on_line = wall_on_line, crossings = crossings, PUSH_VALUE = PUSH_VALUE, PUSH_CROSSINGS = PUSH_CROSSINGS,
  SNEAK_BOX = SNEAK_BOX}
end

return routing
