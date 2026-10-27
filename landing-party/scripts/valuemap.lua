-- What a base is worth, where: the foe's buildings read once, bucketed by cell, each weighed by one table. With the fire
-- map (firemap.lua), its soft hearts: the places worth most for what it costs to get in and take them. No shape assumed: a
-- heart is wherever worth gathers and fire does not, a factory behind a ring of guns, an outpost in the open, a power plant
-- left at the edge (the user, 2026-10-27: "a way to identify the soft heart or soft hearts of the base ... I hope this can
-- lead to surprising raids"). Every stage of a wave asks it, the farm choosing a place, the herd at the breach, inside and
-- each biter after its next target; before it, each kept its own table and its own grid, and an outpost of 95 drills read
-- as worth 0 to one of them.
-- A leaf but for the fire map: it reads the surface only.
local firemap = require("__landing-party__.scripts.firemap")

local valuemap = {}

-- Worth by type; NAMES over it where one type spans small and great (a substation feeds a block, a wooden pole a few).
valuemap.WORTH = {
  reactor = 8, ["fusion-generator"] = 8, ["rocket-silo"] = 10, generator = 3, ["burner-generator"] = 3,
  ["electric-energy-interface"] = 3, boiler = 2, ["solar-panel"] = 0.5, accumulator = 0.5, ["lightning-attractor"] = 0.5,
  roboport = 4, radar = 2, beacon = 2, lab = 2, ["assembling-machine"] = 2, furnace = 1, ["mining-drill"] = 1,
  ["electric-pole"] = 0.5, ["offshore-pump"] = 1, pump = 0.5, ["storage-tank"] = 0.5, inserter = 0.2,
  splitter = 0.1, ["underground-belt"] = 0.05, ["transport-belt"] = 0.05,
}
valuemap.NAMES = {substation = 3, ["big-electric-pole"] = 1, ["medium-electric-pole"] = 1}
valuemap.CELL = 32             -- the grid its hearts are read on (tiles)
valuemap.SPREAD = 0.5          -- a cell's worth gathers this much of each neighbour's (a heart is no one cell)
valuemap.FAR = 300             -- a heart this far off is worth half as much

-- All the types it weighs, for a read that wants every one, and CORE, those worth CORE_MIN or more (the belts make a
-- factory's read large, thousands: reads over hundreds of tiles take CORE).
valuemap.CORE_MIN = 0.5
valuemap.TYPES, valuemap.CORE = {}, {}
for t, v in pairs(valuemap.WORTH) do
  valuemap.TYPES[#valuemap.TYPES + 1] = t
  if v >= valuemap.CORE_MIN then valuemap.CORE[#valuemap.CORE + 1] = t end
end
table.sort(valuemap.TYPES)
table.sort(valuemap.CORE)

function valuemap.worth_of(e) return valuemap.NAMES[e.name] or valuemap.WORTH[e.type] or 0 end

local function xy(p) return p.x or p[1], p.y or p[2] end

-- The buildings of `forces` within `radius` of `at`, of `types` (all it weighs by default), on cells of `cell` tiles.
function valuemap.read(surface, at, radius, forces, types, cell)
  local x, y = xy(at)
  local size = cell or valuemap.CELL
  local cells = {}
  for _, e in ipairs(surface.find_entities_filtered{position = {x, y}, radius = radius, type = types or valuemap.TYPES,
    force = forces}) do
    local w = valuemap.worth_of(e)
    if w > 0 then
      local i, j = math.floor(e.position.x / size), math.floor(e.position.y / size)
      local k = i .. "," .. j
      local c = cells[k]
      if not c then
        c = {i = i, j = j, worth = 0, sx = 0, sy = 0, list = {}}
        cells[k] = c
      end
      c.worth, c.sx, c.sy = c.worth + w, c.sx + e.position.x * w, c.sy + e.position.y * w
      c.list[#c.list + 1] = e
    end
  end
  for _, c in pairs(cells) do c.mid = {x = c.sx / c.worth, y = c.sy / c.worth} end
  return {cells = cells, size = size, at = {x = x, y = y}}
end

-- What stands within r of pos is worth (its cells' buildings, counted one by one).
function valuemap.worth_near(map, pos, r)
  local x, y = xy(pos)
  local size = map.size
  local total = 0
  for i = math.floor((x - r) / size), math.floor((x + r) / size) do
    for j = math.floor((y - r) / size), math.floor((y + r) / size) do
      local c = map.cells[i .. "," .. j]
      if c then
        for _, e in ipairs(c.list) do
          if e.valid and (e.position.x - x) ^ 2 + (e.position.y - y) ^ 2 <= r * r then total = total + valuemap.worth_of(e) end
        end
      end
    end
  end
  return total
end

-- What a wave of n keeps of what it is worth to reach a place whose way costs `cost` turrets, there and back, each `price`
-- of its own: all of it with nothing to cross, none at HOLD of its number lost (it turns home there: herd.lua). A ring
-- of guns read as five turrets against an outpost's three, a little dearer; it cost waves of 60 half their number going
-- in, and they came home with nothing, while the outpost's drills fell (2026-10-27).
valuemap.HOLD = 0.5
function valuemap.keeps(n, cost, price) return valuemap.keeps_lost(n, cost * (price or firemap.AFFORD)) end
-- The same, from what the way there costs it one way, in its own (costmap.lua): there and back.
function valuemap.keeps_lost(n, lost) return math.max(0, 1 - 2 * lost / (n * valuemap.HOLD)) end

-- The soft hearts, best first: each cell's worth with SPREAD of its neighbours', times what a wave of n keeps of it
-- (valuemap.keeps: the way in there and back), over the walk from `from` (FAR). The way in: opts.lost(mid) when given, what
-- getting there costs it in its own (costmap.lua), else from outside (firemap.entry_cost over `reach`). opts.price:
-- a turret's cost (firemap.AFFORD unlearned); opts.min: none nearer `from` than this; opts.most: how many (MOST). Those
-- it keeps nothing of are left out. Each {cell, at = its building with the least fire on it, nearest its middle, worth,
-- cost, keeps, far, score}.
valuemap.MOST = 8
function valuemap.hearts(map, fire, n, from, reach, opts)
  opts = opts or {}
  local most = opts.most or valuemap.MOST
  local fx, fy = xy(from)
  local out = {}
  for _, c in pairs(map.cells) do
    local d = math.sqrt((c.mid.x - fx) ^ 2 + (c.mid.y - fy) ^ 2)
    if not opts.min or d > opts.min then
      local w = c.worth
      for di = -1, 1 do
        for dj = -1, 1 do
          local o = (di ~= 0 or dj ~= 0) and map.cells[(c.i + di) .. "," .. (c.j + dj)]
          if o then w = w + valuemap.SPREAD * o.worth end
        end
      end
      local lost = opts.lost and opts.lost(c.mid)
      local cost = not opts.lost and firemap.entry_cost(fire, c.mid, reach) or 0
      local keeps = lost and valuemap.keeps_lost(n, lost) or (not opts.lost and valuemap.keeps(n, cost, opts.price) or 0)
      if keeps > 0 then
        out[#out + 1] = {cell = c, worth = w, cost = cost, lost = lost, keeps = keeps, far = d,
          score = w * keeps / (1 + d / valuemap.FAR)}
      end
    end
  end
  table.sort(out, function(a, b) return a.score > b.score end)
  for k = #out, most + 1, -1 do out[k] = nil end
  -- Its target there: of the buildings nearest its middle, the one with the least fire on it.
  for _, h in ipairs(out) do
    local c, best, bf, bd = h.cell, nil, nil, nil
    for _, e in ipairs(c.list) do
      if e.valid then
        local f = firemap.count(fire, e.position, bf)
        local dd = (e.position.x - c.mid.x) ^ 2 + (e.position.y - c.mid.y) ^ 2
        if not bf or f < bf or (f == bf and dd < bd) then best, bf, bd = e, f, dd end
      end
    end
    h.at = best
  end
  return out
end

return valuemap
