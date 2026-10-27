-- The fire a wave meets: the foe's turrets round a point, read once, then asked many times in Lua (one query a look, not
-- one per candidate). Synthexis asks it the same two questions at every stage: which turrets cover a point, and can a
-- wave of n take it, with AFFORD of its own to each turret covering it. The inner keep is no shape and no fixed count:
-- a point is the keep for a wave too small to take it (a review of the waves, 2026-10-27: "three turrets within 24" made
-- a whole ring of guns 8 tiles apart the keep, its ammo belt with it, and nothing on a base's perimeter could be touched).
-- A leaf: it reads the surface only.
local power = require("__landing-party__.scripts.power")

local firemap = {}

-- A turret's reach over a point, by type (a gun turret's 18, a laser's 24, a flamethrower's 30, plus 2).
firemap.REACH = {["ammo-turret"] = 20, ["electric-turret"] = 26, ["fluid-turret"] = 32}
firemap.AFFORD = 6            -- what a turret costs it, in its own, before it has learned (the price: herd.lua learns it
                              -- per foe from what crossing its guns cost; on a deathworld's ring of gun turrets, 6 to 7)
local TYPES = {"ammo-turret", "electric-turret", "fluid-turret"}
local FAR = 32                -- the longest reach: turrets this far past the map's radius still cover points in it
local CELL = 32               -- turrets bucketed by cell (no less than FAR: a point's cover is in its cell's 3x3)
-- The way in (entry_cost): from RAYS directions, a point every STEP tiles out to the reach given (at 12 the points stepped
-- over the wall line where the cover peaks: a ring's crossing read as 2 guns, its breach had 5; 2026-10-27).
firemap.RAYS, firemap.STEP = 8, 6

local function xy(p) return p.x or p[1], p.y or p[2] end

local function key(x, y) return math.floor(x / CELL) .. "," .. math.floor(y / CELL) end

-- The turrets of `forces` that can fire on points within `radius` of `at` (a dark laser fires on nothing).
function firemap.read(surface, at, radius, forces)
  local x, y = xy(at)
  local list, cells = {}, {}
  for _, t in ipairs(surface.find_entities_filtered{position = {x, y}, radius = radius + FAR, type = TYPES, force = forces}) do
    if not power.dark(t) then
      local e = {x = t.position.x, y = t.position.y, r = firemap.REACH[t.type] or 20, e = t}
      list[#list + 1] = e
      local k = key(e.x, e.y)
      cells[k] = cells[k] or {}
      table.insert(cells[k], e)
    end
  end
  return {list = list, cells = cells, surface = surface, forces = forces}
end

-- Each standing turret whose reach covers pos, to f (which returns true to stop).
local function each(map, pos, f)
  local x, y = xy(pos)
  local cx, cy = math.floor(x / CELL), math.floor(y / CELL)
  for i = cx - 1, cx + 1 do
    for j = cy - 1, cy + 1 do
      for _, t in ipairs(map.cells[i .. "," .. j] or {}) do
        if (t.x - x) ^ 2 + (t.y - y) ^ 2 <= t.r * t.r and t.e.valid and f(t) then return end
      end
    end
  end
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

-- The coolest of RAYS ways in: its cost (its hottest point) and its index.
local function best_ray(map, x, y, reach)
  local best, bk
  for k = 0, firemap.RAYS - 1 do
    local a = 2 * math.pi * k / firemap.RAYS
    local ca, sa = math.cos(a), math.sin(a)
    local worst = 0
    for d = 0, reach, firemap.STEP do
      local n = firemap.count(map, {x + ca * d, y + sa * d}, best)
      if n > worst then worst = n end
      if best and worst >= best then break end
    end
    if not best or worst < best then best, bk = worst, k end
    if best == 0 then break end
  end
  return best or 0, bk
end

-- What it costs to reach pos from outside, in turrets: of RAYS ways in from `reach` tiles out, the one whose hottest
-- point is coolest (a factory inside a ring of guns costs the ring whichever way; an outpost in the open, its own guns;
-- a hole its last wave broke in the ring, nothing; no shape assumed). The map must hold the turrets within reach of pos.
-- A quick reading, for the farm weighing dozens of places a look; a wave's own way in is priced whole (costmap.lua).
function firemap.entry_cost(map, pos, reach)
  local x, y = xy(pos)
  return (best_ray(map, x, y, reach))
end

-- Whether a wave of n can take pos, each turret covering it costing `price` of its own (AFFORD unlearned).
function firemap.affords(map, pos, n, price)
  local p = price or firemap.AFFORD
  return firemap.count(map, pos, math.floor(n / p) + 1) * p <= n
end

return firemap
