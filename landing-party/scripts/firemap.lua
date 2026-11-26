-- The fire a wave meets: the foe's turrets round a point, read once, then asked many times in Lua (one query a look, not
-- one per candidate). Synthexis asks it the same two questions at every stage: which turrets cover a point, and can a
-- wave of n take it, with AFFORD of its own to each turret covering it. The inner keep is no shape and no fixed count:
-- a point is the keep for a wave too small to take it (a review of the waves, 2026-10-27: "three turrets within 24" made
-- a whole ring of guns 8 tiles apart the keep, its ammo belt with it, and nothing on a base's perimeter could be touched).
-- A leaf: it reads the surface only.
local threat = require("__landing-party__.scripts.threat")

local firemap = {}

firemap.AFFORD = 6            -- a turret's price when its reader gives none (its readers learn one per prototype:
                              -- know.price; on a deathworld's ring of gun turrets, 4.5 to 10)
-- Turrets bucketed by cell, no smaller than the longest reach (threat.far): a point's cover is in its cell's 3x3.
local function cell_size() return math.max(32, math.ceil(threat.far())) end
-- The way in (entry_cost): from RAYS directions, a point every STEP tiles out to the reach given (at 12 the points stepped
-- over the wall line where the cover peaks: a ring's crossing read as 2 guns, its breach had 5; 2026-10-27).
firemap.RAYS, firemap.STEP = 8, 6

local function xy(p) return p.x or p[1], p.y or p[2] end

-- The turrets of `forces` (or what of `types`: threat.ARMED, its units too) that can fire on points within `radius` of `at`, each by its own reach (threat.lua: from its
-- prototype) and its price in the reader's own (price(turret): learned per prototype, know.price; AFFORD without one);
-- a silent one (a dark laser, a dry gun, a flamethrower with nothing to burn) fires on nothing.
-- A cost map's box of half-side r reaches r * BOX from its middle at its corners: a fire map read for one is read that far
-- (read to r alone, a megabase's corner of lasers lay outside the circle and inside the box, priced free, and a wave
-- planned through it met 15 lasers; 2026-10-28).
firemap.BOX = 1.42
function firemap.read(surface, at, radius, forces, price, types)
  local x, y = xy(at)
  local size = cell_size()
  local list, cells = {}, {}
  for _, t in ipairs(surface.find_entities_filtered{position = {x, y}, radius = radius + threat.far(), type = types or threat.FIRE,
    force = forces}) do
    if threat.firing(t) and threat.reach(t) > 0 then
      local e = {x = t.position.x, y = t.position.y, r = threat.reach(t), p = price and price(t) or firemap.AFFORD, e = t}
      -- (A turret that turns through less than a circle, about the way its base faces (its direction, 16 to a turn); its
      -- minimum reach; a fluid turret's burn: the fire consult, 2026-10-30.)
      local prof = threat.profile(t.name)
      if prof then
        if prof.arc and prof.arc < 1 then e.arc, e.o = prof.arc, (t.direction or 0) / 16 end
        if (prof.min_reach or 0) > 0 then e.r0 = prof.min_reach end
        e.burn = prof.burn
      end
      list[#list + 1] = e
      local k = math.floor(e.x / size) .. "," .. math.floor(e.y / size)
      cells[k] = cells[k] or {}
      table.insert(cells[k], e)
    end
  end
  return {list = list, cells = cells, size = size, surface = surface, forces = forces}
end

-- The same read sliced (a landing's way, costmap.start): the box round `at` read a strip of `rows` tiles a step. `prior`
-- prices each by threat.prior (a number, not a function: the job is kept in storage). Returns the map once done.
function firemap.start(surface, at, radius, forces, prior, types)
  local x, y = xy(at)
  local r = radius + threat.far()
  return {surface = surface, x = x, y = y, r = r, y1 = y - r, forces = forces, prior = prior, types = types or threat.FIRE,
    map = {list = {}, cells = {}, size = cell_size(), surface = surface, forces = forces}}
end
function firemap.step(job, rows)
  local map, r = job.map, job.r
  local y0 = job.y1
  local y1 = rows and math.min(job.y + r, y0 + rows) or job.y + r
  for _, t in ipairs(job.surface.find_entities_filtered{area = {{job.x - r, y0}, {job.x + r, y1}}, type = job.types,
    force = job.forces}) do
    local px, py = t.position.x, t.position.y
    -- (Its own strip's alone: one on the line between two is read by the first.)
    if py >= y0 and (py < y1 or y1 >= job.y + r) and (px - job.x) ^ 2 + (py - job.y) ^ 2 <= r * r
      and threat.firing(t) and threat.reach(t) > 0 then
      -- (A corporation's learned prices where the job names one, firemap.price_of, set by siege.lua: its siege ways read
      -- in slices, 0.3.1, priced as their one-tick read was.)
      local lp = job.corp and firemap.price_of and firemap.price_of(job.corp, t)
      local e = {x = px, y = py, r = threat.reach(t), p = lp or (job.prior and threat.prior(t, job.prior)) or firemap.AFFORD, e = t}
      local prof = threat.profile(t.name)
      if prof then
        if prof.arc and prof.arc < 1 then e.arc, e.o = prof.arc, (t.direction or 0) / 16 end
        if (prof.min_reach or 0) > 0 then e.r0 = prof.min_reach end
        e.burn = prof.burn
      end
      map.list[#map.list + 1] = e
      local k = math.floor(e.x / map.size) .. "," .. math.floor(e.y / map.size)
      map.cells[k] = map.cells[k] or {}
      table.insert(map.cells[k], e)
    end
  end
  job.y1 = y1
  if y1 >= job.y + r then return map end
  return nil
end

-- Whether a turret's arc takes in (x, y), d tiles off, with `give` tiles of slack across (a box's half).
local function in_arc(t, x, y, d, give)
  if not t.arc or d <= (give or 0) + 1 then return true end
  local o = (math.atan2(x - t.x, t.y - y) / (2 * math.pi)) % 1
  local diff = math.abs(o - t.o)
  diff = math.min(diff, 1 - diff)
  return diff <= t.arc / 2 + (give and math.atan(give / d) / (2 * math.pi) or 0)
end
firemap.in_arc = in_arc

-- Each standing turret whose reach covers pos (past its minimum reach, inside its arc), to f (which returns true to stop).
local function each(map, pos, f)
  local x, y = xy(pos)
  local cx, cy = math.floor(x / map.size), math.floor(y / map.size)
  for i = cx - 1, cx + 1 do
    for j = cy - 1, cy + 1 do
      for _, t in ipairs(map.cells[i .. "," .. j] or {}) do
        local d2 = (t.x - x) ^ 2 + (t.y - y) ^ 2
        if d2 <= t.r * t.r and d2 >= (t.r0 or 0) ^ 2 and in_arc(t, x, y, math.sqrt(d2)) and t.e.valid and f(t) then return end
      end
    end
  end
end

-- Whether a standing turret stands within d of pos (its ground defended, whatever covers pos itself).
function firemap.near(map, pos, d)
  local x, y = xy(pos)
  local size = map.size
  local cx, cy = math.floor(x / size), math.floor(y / size)
  local span = math.ceil(d / size)
  for i = cx - span, cx + span do
    for j = cy - span, cy + span do
      for _, t in ipairs(map.cells[i .. "," .. j] or {}) do
        if (t.x - x) ^ 2 + (t.y - y) ^ 2 <= d * d and t.e.valid then return true end
      end
    end
  end
  return false
end

-- The standing turrets whose reach covers pos, as the map holds them ({x, y, r, p, e}).
function firemap.entries(map, pos)
  local out = {}
  each(map, pos, function(t) out[#out + 1] = t end)
  return out
end

-- The standing turrets whose reach touches any of the square of half-side `half` round pos, not only its middle (a cost map's
-- cell: read at its middle, 32-tile cells fell between a ring of gun turrets 18 tiles in reach, its ways ran through them
-- priced free, and its waves were shot on the march; 2026-10-28).
function firemap.entries_box(map, pos, half)
  local x, y = xy(pos)
  local out = {}
  local s = map.size
  for i = math.floor((x - half) / s) - 1, math.floor((x + half) / s) + 1 do
    for j = math.floor((y - half) / s) - 1, math.floor((y + half) / s) + 1 do
      for _, t in ipairs(map.cells[i .. "," .. j] or {}) do
        local dx, dy = math.max(0, math.abs(t.x - x) - half), math.max(0, math.abs(t.y - y) - half)
        if dx * dx + dy * dy <= t.r * t.r and in_arc(t, x, y, math.sqrt((t.x - x) ^ 2 + (t.y - y) ^ 2), half * 1.42)
          and t.e.valid then out[#out + 1] = t end
      end
    end
  end
  return out
end

-- What the turrets covering pos cost to take, in the reader's own (their prices summed).
function firemap.cost(map, pos)
  local c = 0
  each(map, pos, function(t) c = c + t.p end)
  return c
end

-- The standing turrets whose reach covers pos.
function firemap.cover(map, pos)
  local out = {}
  each(map, pos, function(t) out[#out + 1] = t.e end)
  return out
end

-- How many standing turrets cover pos (stops counting at most, when given).
function firemap.count(map, pos, most)
  local n = 0
  each(map, pos, function() n = n + 1; return most and n >= most end)
  return n
end

-- The coolest of RAYS ways in: its cost (its hottest point, the turrets there priced) and its index.
local function best_ray(map, x, y, reach)
  local best, bk
  for k = 0, firemap.RAYS - 1 do
    local a = 2 * math.pi * k / firemap.RAYS
    local ca, sa = math.cos(a), math.sin(a)
    local worst = 0
    for d = 0, reach, firemap.STEP do
      local n = firemap.cost(map, {x + ca * d, y + sa * d})
      if n > worst then worst = n end
      if best and worst >= best then break end
    end
    if not best or worst < best then best, bk = worst, k end
    if best == 0 then break end
  end
  return best or 0, bk
end

-- What it costs to reach pos from outside, in the reader's own: of RAYS ways in from `reach` tiles out, the one whose hottest
-- point is coolest (a factory inside a ring of guns costs the ring whichever way; an outpost in the open, its own guns;
-- a hole its last wave broke in the ring, nothing; no shape assumed). The map must hold the turrets within reach of pos.
-- A quick reading, for the farm weighing dozens of places a look; a wave's own way in is priced whole (costmap.lua).
function firemap.entry_cost(map, pos, reach)
  local x, y = xy(pos)
  return (best_ray(map, x, y, reach))
end

-- Whether a wave of n can take pos: what the turrets covering it cost (their prices) no more than n.
function firemap.affords(map, pos, n) return firemap.cost(map, pos) <= n end

return firemap
