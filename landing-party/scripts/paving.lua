-- Paved ground for the player's army (the user, 2026-11-17: "how army might change the face of the players factory
-- besides beacons"; data-final-fixes gives the player's units the tiles' walking speed). The engine's pathfinder ignores
-- a tile's speed (scenario paved: a trooper sent past a bent concrete road walked the straight line over the grass), so
-- a squad's way is searched here: a grid of CELL-tile cells, each costing its length over its tiles' mean walking speed
-- (read from the tile prototypes: no tile named here), water shut; A* from start to goal, BUDGET cells opened a tick
-- across all searches (a search never stalls a tick: the squad sets off straight meanwhile), its path pulled tight to
-- the points where it must turn.
-- What each map chunk holds is read once (two tile searches a chunk) and forgotten when a tile in it changes; the memo is
-- the map's own content, so it lives outside storage (a client that joins reads the same ground).
local paving = {}

local CELL = 2        -- tiles a cell: finer than the narrowest road worth having (a 2-wide path still shows)
local MARGIN = 40     -- tiles round the start-goal box the search may use (a road out of the way and back)
local BUDGET = 300    -- cells opened a tick, all searches together (5 us a cell measured: about 1.5 ms)
local SLACK = 1.02    -- a straight cut replaces a stretch of path when it costs no more than this times the stretch

local SPEED, FAST, PAVED
local function speeds()
  if SPEED then return end
  SPEED, FAST, PAVED = {}, 1, {}
  for name, t in pairs(prototypes.tile) do
    local m = t.walking_speed_modifier
    if m and m ~= 1 then
      SPEED[name] = m
      PAVED[#PAVED + 1] = name
      if m > FAST then FAST = m end
    end
  end
end

-- [surface index][chunk key] = {[cell key] = speed (nil: 1; false: water)}
local memo = {}
-- (Keys: two signed coordinates in one number, each offset into 0..65535.)
local function key(i, j) return (i + 32768) * 65536 + (j + 32768) end
local function unkey(k) return math.floor(k / 65536) - 32768, k % 65536 - 32768 end
local ckey = key

local function chunk(s, cx, cy)
  local m = memo[s.index]
  if not m then m = {}; memo[s.index] = m end
  local k = ckey(cx, cy)
  local c = m[k]
  if c then return c end
  speeds()
  c = {}
  local area = {{cx * 32, cy * 32}, {cx * 32 + 32, cy * 32 + 32}}
  local sum = {}
  if #PAVED > 0 then
    for _, t in pairs(s.find_tiles_filtered{area = area, name = PAVED}) do
      local p = t.position
      local kk = key(math.floor(p.x / CELL), math.floor(p.y / CELL))
      sum[kk] = (sum[kk] or 0) + (SPEED[t.name] - 1)
    end
  end
  local n = CELL * CELL
  for kk, d in pairs(sum) do c[kk] = 1 + d / n end
  for _, t in pairs(s.find_tiles_filtered{area = area, collision_mask = "water_tile"}) do
    local p = t.position
    c[key(math.floor(p.x / CELL), math.floor(p.y / CELL))] = false
  end
  m[k] = c
  return c
end

-- A cell's speed (false: shut), cell coordinates in CELL units.
local function cell_speed(s, i, j)
  local c = chunk(s, math.floor(i * CELL / 32), math.floor(j * CELL / 32))
  local v = c[key(i, j)]
  if v == nil then return 1 end
  return v
end

function paving.forget(e)
  local m = memo[e.surface_index]
  if not m then return end
  for _, t in pairs(e.tiles or {}) do
    m[ckey(math.floor(t.position.x / 32), math.floor(t.position.y / 32))] = nil
  end
end

-- The open set, a binary heap of {f, key}.
local function push(h, f, k)
  local n = #h + 1
  h[n] = {f, k}
  while n > 1 do
    local p = math.floor(n / 2)
    if h[p][1] <= h[n][1] then break end
    h[p], h[n] = h[n], h[p]
    n = p
  end
end
local function pop(h)
  local top = h[1]
  local n = #h
  h[1] = h[n]; h[n] = nil; n = n - 1
  local i = 1
  while true do
    local l, r, m = 2 * i, 2 * i + 1, i
    if l <= n and h[l][1] < h[m][1] then m = l end
    if r <= n and h[r][1] < h[m][1] then m = r end
    if m == i then break end
    h[i], h[m] = h[m], h[i]
    i = m
  end
  return top
end

-- The searches under way live in storage (a client joining mid-search must finish it as the others do).
local function state()
  local st = storage.paving
  if not st then
    st = {jobs = {}, next_id = 0, stats = {searches = 0, opened = 0, failed = 0}}
    storage.paving = st
  end
  return st
end
function paving.stats() return state().stats end

-- Worth a search: a walk at least `min` tiles long with a tile of another speed somewhere in the area it would search
-- (a player who has paved nothing never pays for one).
function paving.wanted(s, from, to, min)
  local dx, dy = to.x - from.x, to.y - from.y
  if dx * dx + dy * dy < min * min then return false end
  speeds()
  if #PAVED == 0 then return false end
  return s.count_tiles_filtered{area = {{math.min(from.x, to.x) - MARGIN, math.min(from.y, to.y) - MARGIN},
    {math.max(from.x, to.x) + MARGIN, math.max(from.y, to.y) + MARGIN}}, name = PAVED, limit = 1} > 0
end

-- A search from one position to another on a surface; its result arrives by paving.result(id) once done.
function paving.request(s, from, to)
  speeds()
  local st = state()
  st.next_id = st.next_id + 1
  local next_id = st.next_id
  local fi, fj = math.floor(from.x / CELL), math.floor(from.y / CELL)
  local ti, tj = math.floor(to.x / CELL), math.floor(to.y / CELL)
  local pad = math.ceil(MARGIN / CELL)
  local job = {id = next_id, s = s, from = {x = from.x, y = from.y}, to = {x = to.x, y = to.y},
    i0 = math.min(fi, ti) - pad, i1 = math.max(fi, ti) + pad, j0 = math.min(fj, tj) - pad, j1 = math.max(fj, tj) + pad,
    ti = ti, tj = tj, g = {}, came = {}, closed = {}, open = {}, opened = 0}
  local start = key(fi, fj)
  job.g[start] = 0
  push(job.open, 0, start)
  st.jobs[next_id] = job
  st.stats.searches = st.stats.searches + 1
  return next_id
end

local function h(job, i, j)
  local di, dj = i - job.ti, j - job.tj
  return math.sqrt(di * di + dj * dj) * CELL / FAST
end

-- The cost of walking straight between two points (tiles), from the cells it crosses (nil: through water).
local function line_cost(s, a, b)
  local dx, dy = b.x - a.x, b.y - a.y
  local len = math.sqrt(dx * dx + dy * dy)
  local steps = math.max(1, math.ceil(len / (CELL / 2)))
  local cost = 0
  for k = 0, steps - 1 do
    local t = (k + 0.5) / steps
    local v = cell_speed(s, math.floor((a.x + dx * t) / CELL), math.floor((a.y + dy * t) / CELL))
    if not v then return nil end
    cost = cost + (len / steps) / v
  end
  return cost
end

local function finish(job, goal)
  -- The cells walked back, as tile positions (cell centres; the ends exact).
  local cells = {}
  local k = goal
  while k do cells[#cells + 1] = k; k = job.came[k] end
  local pts = {job.from}
  for n = #cells - 1, 2, -1 do
    local c = cells[n]
    local ci, cj = unkey(c)
    pts[#pts + 1] = {x = (ci + 0.5) * CELL, y = (cj + 0.5) * CELL}
  end
  pts[#pts + 1] = job.to
  -- The path's cost from its start to each point, then pulled tight: from each kept point, the farthest point a straight
  -- walk reaches for no more than the path's own cost there.
  local acc = {0}
  for n = 2, #pts do acc[n] = acc[n - 1] + (line_cost(job.s, pts[n - 1], pts[n]) or math.huge) end
  local out, i = {}, 1
  while i < #pts do
    local best = i + 1
    for n = i + 2, #pts do
      local c = line_cost(job.s, pts[i], pts[n])
      if c and c <= (acc[n] - acc[i]) * SLACK then best = n else break end
    end
    out[#out + 1] = pts[best]
    i = best
  end
  job.path = out
  job.cost = acc[#pts]
  job.straight = line_cost(job.s, job.from, job.to)
end

local NEIGH = {{1, 0, 1}, {-1, 0, 1}, {0, 1, 1}, {0, -1, 1}, {1, 1, 1.4142}, {1, -1, 1.4142}, {-1, 1, 1.4142}, {-1, -1, 1.4142}}

local function step(job, budget)
  local s, open, g, came, closed = job.s, job.open, job.g, job.came, job.closed
  local goal = key(job.ti, job.tj)
  local used = 0
  while used < budget do
    if #open == 0 then job.done, job.failed = true, true; state().stats.failed = state().stats.failed + 1; return used end
    local k = pop(open)[2]
    if not closed[k] then
      closed[k] = true
      used = used + 1
      if k == goal then finish(job, k); job.done = true; return used end
      local i, j = unkey(k)
      local here = cell_speed(s, i, j) or 1
      for _, d in ipairs(NEIGH) do
        local ni, nj = i + d[1], j + d[2]
        if ni >= job.i0 and ni <= job.i1 and nj >= job.j0 and nj <= job.j1 then
          local nk = key(ni, nj)
          if not closed[nk] then
            local v = cell_speed(s, ni, nj)
            if v then
              local ng = g[k] + d[3] * CELL * 2 / (here + v)
              if not g[nk] or ng < g[nk] then
                g[nk], came[nk] = ng, k
                push(open, ng + h(job, ni, nj), nk)
              end
            end
          end
        end
      end
    end
  end
  return used
end

-- The searches, BUDGET cells a tick between them, oldest first.
function paving.tick()
  local st = storage.paving
  if not (st and next(st.jobs)) then return end
  speeds()
  local jobs = st.jobs
  local prof = storage.paving_prof and helpers.create_profiler()
  local left, n = BUDGET, 0
  for id, job in pairs(jobs) do
    if left <= 0 then break end
    if not job.done then
      local used = step(job, left)
      left, n = left - used, n + used
      job.opened = job.opened + used
    end
  end
  st.stats.opened = st.stats.opened + n
  if prof then
    prof.stop()
    helpers.write_file("landing-party/paving-prof.txt", {"", game.tick, " ", n, " ", prof, "\n"}, true)
  end
end

-- A finished search: {path = {positions}, cost, straight, opened} or {failed = true}; nil while it runs. Read once.
function paving.result(id)
  local jobs = state().jobs
  local job = jobs[id]
  if not job then return {failed = true, lost = true} end
  if not job.done then return nil end
  jobs[id] = nil
  return {path = job.path, cost = job.cost, straight = job.straight, opened = job.opened, failed = job.failed}
end

-- (The cells' keys hold x and y within +-32,768 cells, 65,536 tiles of the origin.)
paving.CELL = CELL
return paving
