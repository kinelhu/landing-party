-- What it costs a wave to get anywhere round a base, in its own lost: one search over a grid (cells of CELL tiles), each
-- step costing the walk, the fire on the cell (firemap: each gun covering it, its price over the cells its reach spans),
-- the foe's walls there to break, more under fire the bigger the wave (a wave of 120 files through a gap of two pieces,
-- under the guns all the while). Inside and outside are no categories: inside is where the cost jumps, the shell is where
-- it jumps most, a hole whose guns are dead is a cheap way in until it is mended (the user, 2026-10-27: "how do our
-- scripts know out from in?"; four proxies had answered it, a flood from a staging point, rays to walls, a margin past
-- the guns, a guess 24 tiles past the last building on a ray). No shape is assumed.
-- From the edge of its box (the world outside, every side open) or from one point (a wave where it stands).
-- A leaf but for the fire map: it reads the surface only.
local firemap = require("__landing-party__.scripts.firemap")

local costmap = {}

costmap.CELL = 16           -- tiles a cell
costmap.WALK = 1 / 400      -- of its own a tile walked (the long way round must cost something)
costmap.WALL = 1            -- of its own a cell of the foe's wall, out of fire (breaking it takes time)
costmap.FUNNEL = 60         -- a wall cell's fire is (1 + n / FUNNEL) times as dear: the bigger the wave, the longer under it
costmap.WATER = math.huge   -- water: no way

local WALLS = {"wall", "gate"}
local NEIGHBOURS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}

local function xy(p) return p.x or p[1], p.y or p[2] end

-- The price of a cell: its walk, its fire, its walls (read once each, as the search reaches it).
local function cell_cost(map, i, j)
  local k = i * map.h + j
  local c = map.cell_cost[k]
  if c then return c end
  local size = map.size
  local cx, cy = map.x0 + (i + 0.5) * size, map.y0 + (j + 0.5) * size
  local s = map.surface
  if s.count_tiles_filtered{position = {cx, cy}, radius = size / 2, collision_mask = "water_tile", limit = 1} > 0
    and s.count_tiles_filtered{position = {cx, cy}, radius = 2, collision_mask = "water_tile", limit = 1} > 0 then
    c = costmap.WATER
  else
    local fire = 0
    for _, t in ipairs(firemap.cover(map.fire, {cx, cy})) do
      fire = fire + map.price * size / (2 * (firemap.REACH[t.type] or 20))
    end
    local walls = s.count_entities_filtered{area = {{cx - size / 2, cy - size / 2}, {cx + size / 2, cy + size / 2}},
      type = WALLS, force = map.forces, limit = 1} > 0
    c = size * costmap.WALK + fire
    if walls then c = c + costmap.WALL + fire * map.n / costmap.FUNNEL end
  end
  map.cell_cost[k] = c
  return c
end

-- The search over the box of `radius` round `center`: from opts.from (a point) or from every cell on the box's edge.
-- opts: fire (a firemap read over the box), price (a gun's cost in its own), n (the wave's size), cell (CELL).
function costmap.read(surface, center, radius, forces, opts)
  local size = opts.cell or costmap.CELL
  local x, y = xy(center)
  local w = math.ceil(2 * radius / size)
  local map = {surface = surface, forces = forces, fire = opts.fire, price = opts.price or firemap.AFFORD, n = opts.n or 60,
    size = size, x0 = x - radius, y0 = y - radius, w = w, h = w, cell_cost = {}, cost = {}, came = {}}
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
  if opts.from then
    local fx, fy = xy(opts.from)
    seed(math.max(0, math.min(w - 1, math.floor((fx - map.x0) / size))), math.max(0, math.min(w - 1, math.floor((fy - map.y0) / size))), 0)
  else
    for i = 0, w - 1 do seed(i, 0, 0); seed(i, w - 1, 0) end
    for j = 1, w - 2 do seed(0, j, 0); seed(w - 1, j, 0) end
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
            if step < costmap.WATER then
              local nc = c + step * ((d[1] ~= 0 and d[2] ~= 0) and 1.414 or 1)
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

-- The way in to pos: where it starts (the last cell of the cheapest way still out of all fire and short of any wall), where
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
    local quiet = map.cell_cost[k] <= map.size * costmap.WALK + 1e-9
    if not met and quiet then start = p else met = true end
    if met and step > worst then breach, worst = p, step end
  end
  return {start = start, breach = breach or pos, cost = costmap.cost(map, pos)}
end

return costmap
