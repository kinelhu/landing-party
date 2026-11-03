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

-- What a wave razed, in worth: a building's worth, and the defence's at its cost to build (an assembler is 2). A siege
-- that broke 22 walls and guns had razed 0 by worth_of, its attempts read as worthless and the farm held forever behind
-- them (the star fort, 2026-10-31; the user: count destroyed defences as gains). Not in WORTH: hearts are where worth
-- gathers and fire does not, a ring of guns is no heart.
valuemap.DEFENCE = {
  ["ammo-turret"] = 1, ["electric-turret"] = 2, ["fluid-turret"] = 2, turret = 2, ["artillery-turret"] = 6,
  wall = 0.1, gate = 0.2,
}
function valuemap.razed_of(e) return valuemap.worth_of(e) + (valuemap.DEFENCE[e.type] or 0) end

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

-- A turret starved of its feed (feeds.lua), in worth: as much as an assembler razed.
valuemap.STARVED = 2
-- An artillery piece that reaches its incubators, in worth for each (the perception consult, section 5: no danger to a
-- wave, mortal to the culture: it shells every pen in its reach until none is left): one covering four outweighs a factory.
valuemap.SHELLS = 50

-- A feed's worth where it stands (STARVED for each turret cutting it would starve), the most of any one cut in a cell:
-- one cut does it, and summed over the sixteen pieces of a belt line in a cell the ammunition belt behind a ring of guns
-- read as worth five factories, and waves fought for it under the guns (2026-10-27).
function valuemap.add(map, e, w)
  if not (e.valid and w > 0) then return end
  local size = map.size
  local i, j = math.floor(e.position.x / size), math.floor(e.position.y / size)
  local k = i .. "," .. j
  local c = map.cells[k]
  if not c then
    c = {i = i, j = j, worth = 0, sx = 0, sy = 0, list = {}}
    map.cells[k] = c
  end
  local more = w - (c.feed or 0)
  if more <= 0 then return end
  c.feed = w
  w = more
  c.worth, c.sx, c.sy = c.worth + w, c.sx + e.position.x * w, c.sy + e.position.y * w
  c.mid = {x = c.sx / c.worth, y = c.sy / c.worth}
  c.list[#c.list + 1] = e
  map.extra = map.extra or {}
  map.extra[e.unit_number or 0] = (map.extra[e.unit_number or 0] or 0) + w
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
          if e.valid and (e.position.x - x) ^ 2 + (e.position.y - y) ^ 2 <= r * r then
            total = total + valuemap.worth_of(e) + (map.extra and map.extra[e.unit_number or 0] or 0)
          end
        end
      end
    end
  end
  return total
end

-- What is worth something within r of pos, each to f: what a wave there has to break for that worth.
function valuemap.each_near(map, pos, r, f)
  local x, y = xy(pos)
  local size = map.size
  for i = math.floor((x - r) / size), math.floor((x + r) / size) do
    for j = math.floor((y - r) / size), math.floor((y + r) / size) do
      local c = map.cells[i .. "," .. j]
      if c then
        for _, e in ipairs(c.list) do
          if e.valid and (e.position.x - x) ^ 2 + (e.position.y - y) ^ 2 <= r * r
            and valuemap.worth_of(e) + (map.extra and map.extra[e.unit_number or 0] or 0) > 0 then
            f(e)
          end
        end
      end
    end
  end
end

-- What a wave of n keeps of what it is worth to reach a place whose way costs it `lost` of its own one way, there and
-- back: all of it with nothing to cross, none at HOLD of its number lost (it turns home there: herd.lua). A ring
-- of guns read as five turrets against an outpost's three, a little dearer; it cost waves of 60 half their number going
-- in, and they came home with nothing, while the outpost's drills fell (2026-10-27).
valuemap.HOLD = 0.5
-- (lost: what the way there costs it one way, in its own: costmap.lua, firemap.entry_cost.)
-- What a place keeps of its score however dear its way (Synthexis's culture landing, farm.lua; Kessler-Hayashi's siege
-- weighing): its score times this and the share kept.
valuemap.REACH_FLOOR = 0.25
function valuemap.keeps_lost(n, lost) return math.max(0, 1 - 2 * lost / (n * valuemap.HOLD)) end
-- What a wave of n keeps going one way at a cost of `lost` (it arrives with the rest): once it is on its way in, the way
-- back is its stay rule's to weigh, not the target's.
function valuemap.keeps_one_way(n, lost) return math.max(0, 1 - lost / math.max(1, n)) end

-- The soft hearts, best first: each cell's worth with SPREAD of its neighbours', times what a wave of n keeps of it
-- (valuemap.keeps: the way in there and back), over the walk from `from` (FAR). The way in: opts.lost(mid) when given, what
-- getting there costs it in its own (costmap.lua), else from outside (firemap.entry_cost over `reach`, the fire map
-- priced); opts.min: none nearer `from` than this; opts.most: how many (MOST); opts.keeps: what it keeps of n at a cost
-- (valuemap.keeps_lost, there and back, by default). Those
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
      local lost
      if opts.lost then lost = opts.lost(c.mid) else lost = firemap.entry_cost(fire, c.mid, reach) end
      local cost = lost
      local keeps = lost and (opts.keeps or valuemap.keeps_lost)(n, lost) or 0
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
