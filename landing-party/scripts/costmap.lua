-- What it costs a wave to get anywhere round a base, in its own lost: one search over a grid (cells of CELL tiles), each
-- step costing the walk, the fire on the cell (firemap: each gun whose reach touches it, its price over the cells its reach spans),
-- the foe's walls there to break, more under fire the bigger the wave (a wave of 120 files through a gap of two pieces,
-- under the guns all the while). Inside and outside are no categories: inside is where the cost jumps, the shell is where
-- it jumps most, a hole whose guns are dead is a cheap way in until it is mended (the user, 2026-10-27: "how do our
-- scripts know out from in?"; four proxies had answered it, a flood from a staging point, rays to walls, a margin past
-- the guns, a guess 24 tiles past the last building on a ray). No shape is assumed.
-- From the edge of its box (the world outside, every side open) or from one point (a wave where it stands).
-- A leaf but for the fire map: it reads the surface only.
local firemap = require("__landing-party__.scripts.firemap")
local threat = require("__landing-party__.scripts.threat")

local costmap = {}

costmap.CELL = 16           -- tiles a cell
costmap.WALK = 1 / 400      -- of its own a tile walked (the long way round must cost something)
costmap.WALL = 1            -- of its own a cell of the foe's wall, out of fire (breaking it takes time)
costmap.FUNNEL = 60         -- a wall cell's fire is (1 + n / FUNNEL) times as dear: the bigger the wave, the longer under it
costmap.WATER = math.huge   -- water: no way
costmap.WATER_SHARE = 0.4  -- a cell this much water, or more, is no way
-- A cell this thick with trees (a tree a tile, so many): no way. The engine's pathfinder walks round a forest, and a way
-- drawn through one was walked round the long way: nw's biggest waves, sent at a forest of 0.2 to 0.26 trees a tile,
-- went round its edge through 0.12 to 0.18 and were turned home as taken off their way (2026-10-28).
costmap.FOREST = 0.2
-- And thinner woods dearer to cross from FOREST_SOFT, up to FOREST_DEAR more times the walk at FOREST: read as open, a wood
-- of 0.14 trees a tile north of the siege test's fort was walked round by the engine to the south, into the lasers' reach,
-- and the wave broke in there, its rams short of the wall (the playtest's slower climb, 0.2.127, set it out from elsewhere).
costmap.FOREST_SOFT = 0.05
costmap.FOREST_DEAR = 4
-- Cliff pieces in a cell that make it no way: one. (At two, a cliff line crossing cells corner to corner left one piece
-- in each, read as open: a plan ran along it 500 tiles from the user's fort, and its herd's legs failed one after another
-- until it scattered; the siege lab, 2026-10-30. A cliff's end closes a cell it need not: the safe side.)
costmap.CLIFFS = 1
-- Its foe's mines, seen (the user, 2026-10-28: "let it see the mines"): each in a cell costs it MINE of its own to cross, a
-- runt of its sweep and the time (herd.lua sweep): a mined way is dearer than an open one, and a field it can go round it
-- goes round.
costmap.MINE = 0.5
costmap.GROUND_COST = 0.5   -- of its own a cell of the foe's buildings, on a plan's way (herd.plan)
costmap.DEATH = 0.5         -- of its own a cell, for each of its own that died there lately to what no fire map shows

local WALLS = {"wall", "gate"}
-- What marks the foe's ground (its buildings, not its units or vehicles passing).
local GROUND = {"wall", "gate", "ammo-turret", "electric-turret", "fluid-turret", "assembling-machine", "furnace",
  "mining-drill", "container", "logistic-container", "electric-pole", "inserter", "transport-belt", "underground-belt",
  "splitter", "pipe", "pipe-to-ground", "storage-tank", "lab", "roboport", "solar-panel", "accumulator", "boiler",
  "generator", "radar", "beacon", "rocket-silo", "reactor", "pump", "offshore-pump"}
-- (Never its mines: hidden from it, they are what its deaths teach it, herd.deaths and herd.hidden_cost.)
local FROM_RING = 3          -- cells round a start on water searched for one that is not
local NEIGHBOURS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}

local function xy(p) return p.x or p[1], p.y or p[2] end

-- The price of a cell: its walk, its fire, its walls (read once each, as the search reaches it).
local ground   -- below: whether a cell holds the foe's buildings

-- Whether a cell or one round it holds anything of a kind (map.bins, read once over the box): a cell where none does needs
-- no query of its own for it, the same answer for a fraction of the calls (a weighing of the user's fort read every cell
-- of 16 tiles with six or seven queries, 92 ms of its 235 in one tick; 2026-10-31).
local function near(map, kind, i, j)
  local b = map.bins and map.bins[kind]
  if not b then return true end
  local hh = map.h + 2
  for di = -1, 1 do
    for dj = -1, 1 do
      if b[(i + di + 1) * hh + (j + dj + 1)] then return true end
    end
  end
  return false
end

local cell_cost_
local function cell_cost(map, i, j)
  local k = i * map.h + j
  local c = map.cell_cost[k]
  if c then return c end
  -- (Timed apart when its farm's weighing is: storage.biotech_time_parts.)
  if map.prof then
    map.prof.restart()
    c = cell_cost_(map, i, j, k)
    map.prof.stop()
    map.cells_read = (map.cells_read or 0) + 1
    return c
  end
  return cell_cost_(map, i, j, k)
end
cell_cost_ = function(map, i, j, k)
  local c
  local size = map.size
  local cx, cy = map.x0 + (i + 0.5) * size, map.y0 + (j + 0.5) * size
  local s = map.surface
  -- No way: ground its herds found none through (opts.blocked), or water at its middle or over WATER_SHARE of it (water at
  -- its middle only, a lake's strait read as open, and a herd sent across it was taken round the lake by the pathfinder;
  -- 2026-10-27).
  -- (By air, opts.air: what shoots up alone; water, woods, cliffs, walls and mines are nothing to a flier.)
  if map.air then
    local fire = 0
    for _, t in ipairs(firemap.entries_box(map.fire, {cx, cy}, size / 2 + map.margin)) do
      fire = fire + t.p * size / (2 * (t.r + map.margin) + size)
    end
    c = size * costmap.WALK + fire * map.scale + costmap.DEATH * (map.deaths[k] or 0)
  elseif map.blocked[k] or (not map.dry and (s.count_tiles_filtered{position = {cx, cy}, radius = 2, collision_mask = "water_tile", limit = 1} > 0
    or s.count_tiles_filtered{area = {{cx - size / 2, cy - size / 2}, {cx + size / 2, cy + size / 2}},
      collision_mask = "water_tile"} > costmap.WATER_SHARE * size * size)) then
    c = costmap.WATER
  elseif near(map, "tree", i, j) and s.count_entities_filtered{area = {{cx - size / 2, cy - size / 2}, {cx + size / 2, cy + size / 2}}, type = "tree"}
    >= costmap.FOREST * size * size then
    c = costmap.WATER
  -- A cliff line across it (CLIFFS or more cliff pieces): no way, as the engine's pathfinder has none. (Blind to them, its
  -- plans ran straight across a cliff south-east of the user's fort; every herd was walked round the cliff's end by the
  -- engine, past the fort's mined corner, and lost 23 to 27 to the mines on its march; the siege lab, 2026-10-30.)
  elseif near(map, "cliff", i, j) and s.count_entities_filtered{area = {{cx - size / 2, cy - size / 2}, {cx + size / 2, cy + size / 2}}, type = "cliff"}
    >= costmap.CLIFFS then
    c = costmap.WATER
  else
    local fire = 0
    -- Each gun covering it, its price over the cells its reach spans: crossing its reach costs about its price.
    if map.fire then
      -- (Each gun whose reach touches the cell, any of it: a way crossing its reach crosses about (2r + size) / size such
      -- cells, so each costs that share of its price, and the crossing about its price. Read at the cell's middle alone,
      -- coarse cells fell between a ring's guns and read free; 2026-10-28.)
      -- (And map.margin more, a herd's spread: its middle kept out of reach, a wave of 91 strung 30 tiles round a base walked
      -- its edges through the mines and lasers by the wall; 2026-10-28.)
      local margin = map.margin
      if map.prof_fire then map.prof_fire.restart() end
      for _, t in ipairs(firemap.entries_box(map.fire, {cx, cy}, size / 2 + margin)) do
        fire = fire + t.p * size / (2 * (t.r + margin) + size)
      end
      if map.prof_fire then map.prof_fire.stop() end
    end
    fire = fire * map.scale
    local walls = near(map, "wall", i, j) and s.count_entities_filtered{area = {{cx - size / 2, cy - size / 2}, {cx + size / 2, cy + size / 2}},
      type = WALLS, force = map.wall_forces or map.forces, limit = 1} > 0
    local mines = near(map, "mine", i, j) and s.count_entities_filtered{area = {{cx - size / 2, cy - size / 2}, {cx + size / 2, cy + size / 2}},
      type = "land-mine", force = map.forces} or 0
    local trees = near(map, "tree", i, j) and s.count_entities_filtered{area = {{cx - size / 2, cy - size / 2}, {cx + size / 2, cy + size / 2}},
      type = "tree"} or 0
    local wood = math.max(0, trees / (size * size) - costmap.FOREST_SOFT) / (costmap.FOREST - costmap.FOREST_SOFT)
    c = size * costmap.WALK * (1 + costmap.FOREST_DEAR * wood) + fire + costmap.DEATH * (map.deaths[k] or 0) + costmap.MINE * mines
    -- (What of it is standing at the wall to break it, kept apart: a siege whose rams blow the wall while its herd waits out
    -- of reach does not pay it, farm.lua siege_size.)
    if walls then map.wallc[k] = costmap.WALL + fire * map.n / costmap.FUNNEL end
    if walls then c = c + costmap.WALL + fire * map.n / costmap.FUNNEL
    -- (A plan's: the foe's buildings in its way, a pipe, a pole, cost a little to cross, so its way goes round them where it
    -- can: blocked by one, a herd breaks it, and a big burster's attack is its blast: on a megabase's outlying pipes they
    -- burst on the march, 9 of 14; 2026-10-28.)
    elseif map.ground_cost > 0 and ground(map, i, j) then c = c + map.ground_cost end
  end
  map.cell_cost[k] = c
  return c
end

-- Whether a cell holds the foe's buildings (its ground, defended or not).
ground = function(map, i, j)
  local k = i * map.h + j
  local v = map.ground[k]
  if v == nil then
    local size = map.size
    local cx, cy = map.x0 + (i + 0.5) * size, map.y0 + (j + 0.5) * size
    v = near(map, "ground", i, j) and map.surface.count_entities_filtered{area = {{cx - size / 2, cy - size / 2},
      {cx + size / 2, cy + size / 2}}, force = map.forces, type = GROUND, limit = 1} > 0
    map.ground[k] = v
  end
  return v
end

-- Whether a cell is the foe's defended ground: something of its there, and a gun of its within reach of it (where the hidden
-- price is paid, on the way in: mines guard defences; charged on any of its ground, a lone power line or an outpost far from
-- any gun cost a megabase's mined wall, and a small culture found nothing it could take; 2026-10-27).
local function held(map, i, j)
  local k = i * map.h + j
  local v = map.held[k]
  if v == nil then
    local size = map.size
    local cx, cy = map.x0 + (i + 0.5) * size, map.y0 + (j + 0.5) * size
    v = ground(map, i, j)
      and (not map.fire or firemap.near(map.fire, {cx, cy}, threat.far() + size / 2))
    map.held[k] = v
  end
  return v
end

-- The search over the box of `radius` round `center`: from opts.from (a point) or from every cell on the box's edge.
-- opts: sources ({x, y}...: from all of them at once), blocked ({x, y}: ground found to have no way through, herd.blocked), fire (a firemap read over the box), n (the wave's size), cell (CELL), seed (from the edge: what reaching it costs
-- at x, y), scale (its fire times this: what crossing has cost against what it expected, know.scale), hidden (what crossing its defended ground costs besides the guns, per crossing: herd.hidden_cost), deaths ({x, y, w}: where its own died lately
-- to what the fire map cannot show, mines, burning ground, units, each weighing w: the first wave into a minefield pays
-- for it, the next goes round; on a megabase's mined wall waves of 25 to 42 lost 24 to 37 each at the breach to mines no
-- turret reading saw, 2026-10-27).
function costmap.read(surface, center, radius, forces, opts)
  local size = opts.cell or costmap.CELL
  local x, y = xy(center)
  local w = math.ceil(2 * radius / size)
  local map = {surface = surface, forces = forces, fire = opts.fire, n = opts.n or 60,
    size = size, x0 = x - radius, y0 = y - radius, w = w, h = w, cell_cost = {}, cost = {}, came = {}, deaths = {},
    hidden = opts.hidden or 0, held = {}, ground = {}, blocked = {}, scale = opts.scale or 1, margin = opts.margin or 0,
    ground_cost = opts.ground_cost or 0, wallc = {},
    -- (Walls of these, not its target's alone: a corporation's camp walls on its way it walks into, and stuck on them under
    -- their flamers its herd lost 66 and left half behind; 2026-10-28.)
    wall_forces = opts.wall_forces, air = opts.air}
  if storage.biotech_time_parts then map.prof, map.prof_fire = helpers.create_profiler(true), helpers.create_profiler(true) end
  -- What stands in the box, by kind, binned by cell once (near): trees, cliffs, walls, mines, the foe's ground; and
  -- whether it holds any water at all (none: no cell asks).
  if not map.air then
    local area = {{map.x0 - size, map.y0 - size}, {map.x0 + (w + 1) * size, map.y0 + (w + 1) * size}}
    local hh = w + 2
    local function bin(list)
      local b = {}
      for _, e in ipairs(list) do
        local i, j = math.floor((e.position.x - map.x0) / size), math.floor((e.position.y - map.y0) / size)
        b[(i + 1) * hh + (j + 1)] = true
      end
      return b
    end
    map.bins = {
      tree = bin(surface.find_entities_filtered{area = area, type = "tree"}),
      cliff = bin(surface.find_entities_filtered{area = area, type = "cliff"}),
      wall = bin(surface.find_entities_filtered{area = area, type = WALLS, force = map.wall_forces or forces}),
      mine = bin(surface.find_entities_filtered{area = area, type = "land-mine", force = forces}),
      ground = bin(surface.find_entities_filtered{area = area, type = GROUND, force = forces}),
    }
    map.dry = surface.count_tiles_filtered{area = area, collision_mask = "water_tile", limit = 1} == 0
  end
  for _, b in ipairs(opts.blocked or {}) do
    local i, j = math.floor((b[1] - map.x0) / size), math.floor((b[2] - map.y0) / size)
    if i >= 0 and j >= 0 and i < w and j < w then map.blocked[i * map.h + j] = true end
  end
  for _, d in ipairs(opts.deaths or {}) do
    local i, j = math.floor((d[1] - map.x0) / size), math.floor((d[2] - map.y0) / size)
    if i >= 0 and j >= 0 and i < w and j < w then map.deaths[i * map.h + j] = (map.deaths[i * map.h + j] or 0) + (d[3] or 1) end
  end

  -- Dijkstra on a binary heap.
  local heap = {}
  local function push(c, k)
    local n = #heap + 1
    heap[n] = {c, k}
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
  local function seed(i, j, base)
    local k = i * map.h + j
    local c = cell_cost(map, i, j)
    if c == costmap.WATER then return end
    if not map.cost[k] or base + c < map.cost[k] then map.cost[k] = base + c; push(base + c, k) end
  end
  if opts.sources then
    -- (From several points at once, each at no cost: what reaching the nearest of them costs, read backwards.)
    for _, q in ipairs(opts.sources) do
      local qx, qy = xy(q)
      local i, j = math.floor((qx - map.x0) / size), math.floor((qy - map.y0) / size)
      if i >= 0 and j >= 0 and i < w and j < w then seed(i, j, 0) end
    end
  elseif opts.from then
    local fx, fy = xy(opts.from)
    local fi, fj = math.max(0, math.min(w - 1, math.floor((fx - map.x0) / size))), math.max(0, math.min(w - 1, math.floor((fy - map.y0) / size)))
    seed(fi, fj, 0)
    -- Its cell water (a shore: any water in it reads as none), from the nearest cells round it that are not: from a scout
    -- dead on a lake's edge nothing was seeded, no way anywhere, and its wave fell back on the nearest building, by a
    -- minefield (2026-10-27).
    for r = 1, FROM_RING do
      if next(heap) then break end
      for i = fi - r, fi + r do
        for j = fj - r, fj + r do
          if (math.abs(i - fi) == r or math.abs(j - fj) == r) and i >= 0 and j >= 0 and i < w and j < w then
            seed(i, j, r * size * costmap.WALK)
          end
        end
      end
    end
  else
    -- (opts.seed(x, y): what reaching the box's edge there costs, the walk from far off; else nothing.)
    local function base(i, j)
      return opts.seed and opts.seed(map.x0 + (i + 0.5) * size, map.y0 + (j + 0.5) * size) or 0
    end
    for i = 0, w - 1 do seed(i, 0, base(i, 0)); seed(i, w - 1, base(i, w - 1)) end
    for j = 1, w - 2 do seed(0, j, base(0, j)); seed(w - 1, j, base(w - 1, j)) end
  end
  local done = {}
  while #heap > 0 do
    local top = pop()
    local c, k = top[1], top[2]
    if not done[k] and c <= map.cost[k] then
      done[k] = true
      local i, j = math.floor(k / map.h), k % map.h
      for _, d in ipairs(NEIGHBOURS) do
        local ni, nj = i + d[1], j + d[2]
        if ni >= 0 and nj >= 0 and ni < w and nj < w then
          local nk = ni * map.h + nj
          if not done[nk] then
            local step = cell_cost(map, ni, nj)
            -- (Not corner to corner past water: between two cells of a lake meeting at a corner, its herds found no way
            -- through a strait the search had crossed so, and were taken round the lake into a minefield; 2026-10-27.)
            local diag = d[1] ~= 0 and d[2] ~= 0
            if diag and (cell_cost(map, ni, j) >= costmap.WATER or cell_cost(map, i, nj) >= costmap.WATER) then
              step = costmap.WATER
            end
            if step < costmap.WATER then
              local nc = c + step * ((d[1] ~= 0 and d[2] ~= 0) and 1.414 or 1)
              -- Onto the foe's ground from off it: what its defended ground costs besides its guns (opts.hidden: mines
              -- and the like, learned per breach: herd.hidden_cost), once a way in (a megabase mined its open ground as
              -- well as its walls, where there was neither gun nor wall to charge it to; 2026-10-27).
              if map.hidden > 0 and held(map, ni, nj) and not held(map, i, j) then nc = nc + map.hidden end
              if not map.cost[nk] or nc < map.cost[nk] then
                map.cost[nk], map.came[nk] = nc, k
                push(nc, nk)
              end
            end
          end
        end
      end
    end
  end
  if map.prof then helpers.write_file("landing-party/timing.txt", {"", string.format("    its %d cells' costs: ", map.cells_read or 0), map.prof, ", their fire: ", map.prof_fire, "\n"}, true); map.prof, map.prof_fire = nil, nil end
  return map
end

local function key_of(map, pos)
  local x, y = xy(pos)
  local i, j = math.floor((x - map.x0) / map.size), math.floor((y - map.y0) / map.size)
  if i < 0 or j < 0 or i >= map.w or j >= map.h then return nil end
  return i * map.h + j
end
local function centre(map, k)
  local i, j = math.floor(k / map.h), k % map.h
  return {x = map.x0 + (i + 0.5) * map.size, y = map.y0 + (j + 0.5) * map.size}
end

-- What it costs to get to pos (in its own lost; nil: no way, or outside the box).
function costmap.cost(map, pos)
  local k = key_of(map, pos)
  return k and map.cost[k]
end

-- The cheapest way to pos, from where the search began: its cells' middles, first to last.
function costmap.path(map, pos)
  local k = key_of(map, pos)
  if not (k and map.cost[k]) then return nil end
  local out = {}
  while k do
    table.insert(out, 1, centre(map, k))
    k = map.came[k]
  end
  return out
end

-- A way (costmap.path) cut to its turns: from each point kept, the farthest point of the way the straight line to which
-- crosses no cell dearer than the dearest the way itself crossed between them (a grid's way is a staircase of cell middles;
-- its fliers fly the straight legs, air raids).
function costmap.straighten(map, path)
  if not path or #path <= 2 then return path end
  local function dear(p)
    local k = key_of(map, p)
    return k and (map.cell_cost[k] or costmap.WATER) or costmap.WATER
  end
  local out, a = {path[1]}, 1
  while a < #path do
    local best = a + 1
    local worst = dear(path[a + 1])
    for j = a + 2, #path do
      worst = math.max(worst, dear(path[j]))
      local ax, ay, bx, by = path[a].x, path[a].y, path[j].x, path[j].y
      local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
      local ok = true
      for d = 0, len, map.size / 2 do
        if dear({ax + (bx - ax) * d / len, ay + (by - ay) * d / len}) > worst + 1e-9 then ok = false; break end
      end
      if ok then best = j end
    end
    out[#out + 1] = path[best]
    a = best
  end
  return out
end

-- What of the way to pos is standing at the foe's walls to break them (costmap.WALL and the funnel), summed over its cells.
function costmap.wall_along(map, pos)
  local k, b = key_of(map, pos), 0
  if not (k and map.cost[k]) then return 0 end
  while k do b = b + (map.wallc[k] or 0); k = map.came[k] end
  return b
end

-- The way in to pos: where it starts (the last cell of the cheapest way still out of all fire and short of the foe's ground), where
-- it breaks in (the dearest cell after that), and its cost. nil: no way.
function costmap.way_in(map, pos)
  local path = costmap.path(map, pos)
  if not path then return nil end
  local start, breach, worst = path[1], nil, -1
  local prev = 0
  local met = false
  for _, p in ipairs(path) do
    local k = key_of(map, p)
    local step = map.cost[k] - prev
    prev = map.cost[k]
    -- (Quiet: out of fire, no wall, none of the foe's buildings: walking at a field of solar panels it had priced as
    -- broken through, the herd's pathfinder went round it to the base's one gap, 380 tiles off and mined, and lost 46 of
    -- 48 there, a megabase, 2026-10-27; it stages short of the foe's ground and breaks in.)
    local i, j = math.floor(k / map.h), k % map.h
    local quiet = map.cell_cost[k] <= map.size * costmap.WALK + 1e-9 and not ground(map, i, j)
    if not met and quiet then start = p else met = true end
    if met and step > worst then breach, worst = p, step end
  end
  return {start = start, breach = breach or pos, cost = costmap.cost(map, pos)}
end

-- A plan's way in to pos (herd.plan): it breaks in at the dearest step of the way, and starts at the last cell before that
-- out of all fire (its walk alone). Not short of the foe's ground, as way_in reads it near a base: round a megabase its
-- rails and poles reach out to the nests, and a plan read that way staged at its own nest, 1,000 tiles from the wall, and
-- its big bursters, sent at guns within 120 tiles of there, found none (2026-10-28). nil: no way.
function costmap.staging(map, pos)
  local path = costmap.path(map, pos)
  if not path then return nil end
  -- (Where the most guns cover it, its fire's line: its bursters go at the guns covering its breach, and at the dearest step
  -- once its foe's mines were priced, its breach lay in a minefield no gun covered, and no siege could open it; 2026-10-28.
  -- The dearest step where no gun covers its way.)
  local prev, worst, bi, most = 0, -1, #path, 0
  for i, p in ipairs(path) do
    local k = key_of(map, p)
    local step = map.cost[k] - prev
    prev = map.cost[k]
    local n = map.fire and #firemap.cover(map.fire, p) or 0
    if n > most then most, bi = n, i
    elseif most == 0 and step > worst then worst, bi = step, i end
  end
  local start = path[1]
  for i = bi - 1, 1, -1 do
    if map.cell_cost[key_of(map, path[i])] <= map.size * costmap.WALK + 1e-9 then start = path[i]; break end
  end
  return {start = start, breach = path[bi], cost = costmap.cost(map, pos)}
end

return costmap
