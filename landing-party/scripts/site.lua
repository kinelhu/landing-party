-- Where a module fits. Trees and rocks count as clearable; anything else built, cliffs and water do not.
local shared = require("__landing-party__.shared")
local modules = require("__landing-party__.scripts.modules")

local site = {}

site.ORES = {"iron-ore", "copper-ore", "coal", "stone"}
local CLEARABLE = {tree = true, ["simple-entity"] = true, resource = true, corpse = true, cliff = true,
  ["rail-remnants"] = true, fish = true}

local function box_at(m, ox, oy, margin)
  return {{ox + m.box[1] - margin, oy + m.box[2] - margin}, {ox + m.box[3] + margin, oy + m.box[4] + margin}}
end

local function generated(surface, area)
  for _, c in ipairs({area[1], area[2], {area[1][1], area[2][2]}, {area[2][1], area[1][2]}}) do
    if not surface.is_chunk_generated({math.floor(c[1] / 32), math.floor(c[2] / 32)}) then return false end
  end
  return true
end

-- Does module m fit with its origin at (ox, oy)? Ore modules need ore under both drills; the others
-- must not sit on ore (they would block the patch).
-- Set by the base module: true where hostile forces occupy the ground.
site.occupied = function() return false end

-- Ground the base must leave free: spots awaiting a rebuild, and ground the enemy occupies.
local function reserved(b, area)
  for _, job in ipairs(b.rebuild) do
    local x, y = job.pos[1], job.pos[2]
    if x >= area[1][1] - 2 and x <= area[2][1] + 2 and y >= area[1][2] - 2 and y <= area[2][2] + 2 then return true end
  end
  return site.occupied(b, game.surfaces[b.surface], {(area[1][1] + area[2][1]) / 2, (area[1][2] + area[2][2]) / 2})
end

function site.fits(surface, b, m, ox, oy)
  local area = box_at(m, ox, oy, 1)
  if not generated(surface, area) then return false end
  if reserved(b, area) then return false end
  for _, e in pairs(surface.find_entities_filtered{area = area}) do
    -- Its own units aside (construction moves them, make_way): standing at its yard (army.yard), they refused the ground
    -- it grew on, and occupy's camp grew five depots instead of one and could not rebuild after the strike.
    if (not CLEARABLE[e.type] or (e.type == "cliff" and not shared.cliff_clears())) and not shared.own_unit(b, e) then
      -- (What stood there, by type: the stats' refused_by.)
      b.refused_by = b.refused_by or {}
      local key = e.type .. ":" .. (e.force and e.force.name or "")
      b.refused_by[key] = (b.refused_by[key] or 0) + 1
      shared.refused(b, e.type == "cliff" and "cliff" or "built") return false
    end
  end
  local wet = surface.count_tiles_filtered{area = area, collision_mask = "water_tile", limit = shared.LANDFILL_MAX + 1}
  if wet > 0 and not (shared.fills(b) and wet <= shared.LANDFILL_MAX) then
    shared.refused(b, "water") return false
  end
  local inner = box_at(m, ox, oy, 0)
  local ore = surface.count_entities_filtered{area = inner, type = "resource", name = site.ORES}
  if m.ore then
    for _, spec in ipairs(m.entities) do
      if spec[1] == "lp-drill" then
        local x, y = ox + spec[2], oy + spec[3]
        if surface.count_entities_filtered{area = {{x - 1.5, y - 1.5}, {x + 1.5, y + 1.5}}, type = "resource",
          name = site.ORES} < 6 then return false end
      end
    end
    return true
  end
  return m.on_ore or ore == 0
end

-- Nearest pylon spot, built or queued (a queued block's pylon counts, or its neighbour would chain past it).
local function nearest_pylon(base, x, y)
  local best, bd = nil, math.huge
  for _, p in ipairs(base.pylon_spots) do
    if not (p.m and (p.m.abandoned or p.m.failed)) then
      local d = (p[1] - x) ^ 2 + (p[2] - y) ^ 2
      if d < bd then best, bd = p, d end
    end
  end
  return best, math.sqrt(bd)
end
site.nearest_pylon = nearest_pylon

-- First fitting origin on rings around (cx, cy), nearest first. Deterministic: no randomness.
function site.near(surface, b, m, cx, cy, rmin, rmax)
  for r = rmin, rmax, 2 do
    local steps = math.max(8, math.floor(2 * math.pi * r / 3))
    for i = 0, steps - 1 do
      local a = 2 * math.pi * i / steps
      local ox, oy = math.floor(cx + r * math.cos(a)), math.floor(cy + r * math.sin(a))
      if site.fits(surface, b, m, ox, oy) then return {ox, oy} end
    end
  end
end

-- The best mining origin: on the lattice, over ore, nearest to the base's network, within reach.
-- Returns origin and its distance to the network.
-- Ore near the lander is scanned once, one chunk per call, into lattice cells kept in storage. The planner
-- then reads the cells instead of querying every ore tile within 200 tiles each time it plans (a 5-6 ms
-- stutter every planning tick, seed 12345).
function site.scan_init(base, radius)
  local cx0, cy0 = math.floor(base.origin.x / 32), math.floor(base.origin.y / 32)
  local r = math.ceil(radius / 32)
  local queue = {}
  for x = cx0 - r, cx0 + r do
    for y = cy0 - r, cy0 + r do table.insert(queue, {x, y, (x - cx0) ^ 2 + (y - cy0) ^ 2}) end
  end
  table.sort(queue, function(a, b) if a[3] ~= b[3] then return a[3] < b[3] end
    if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
  base.ore_scan = {queue = queue, i = 1}
  base.ore_cells = base.ore_cells or {}
end

function site.scan_step(surface, base)
  local scan = base.ore_scan
  local c = scan and scan.queue[scan.i]
  if not c then return end
  scan.i = scan.i + 1
  if not surface.is_chunk_generated({c[1], c[2]}) then return end
  local L = modules.MINING_LATTICE
  local ax, ay = base.origin.x, base.origin.y
  for _, r in pairs(surface.find_entities_filtered{area = {{c[1] * 32, c[2] * 32}, {c[1] * 32 + 32, c[2] * 32 + 32}},
    type = "resource", name = site.ORES}) do
    local cx = math.floor((r.position.x - ax) / L.x)
    local cy = math.floor((r.position.y - ay) / L.y)
    local key = cx .. ":" .. cy
    -- Every fourth lattice column is left empty: a road spine through the patch.
    if cx % 4 ~= 3 and not base.ore_cells[key] then
      base.ore_cells[key] = {ax + cx * L.x + 1, ay + cy * L.y + 3, key, cx, cy}
    end
  end
end

-- The best mining origin: on the lattice, over ore, nearest to the network, within reach. At most `budget.n`
-- candidates are tested per plan (shared across reach steps); the rest wait for the next plan.
function site.mining(surface, base, reach, budget)
  local m = modules.mining
  local scored = {}
  for key, o in pairs(base.ore_cells) do
    if not base.cells[key] then
      local _, d = nearest_pylon(base, o[1], o[2])
      if d <= reach then table.insert(scored, {o = o, d = d}) end
    end
  end
  table.sort(scored, function(a, b) if a.d ~= b.d then return a.d < b.d end
    if a.o[1] ~= b.o[1] then return a.o[1] < b.o[1] end return a.o[2] < b.o[2] end)
  -- A cell is judged once: taken when chosen, bad when it does not fit.
  for _, c in ipairs(scored) do
    if budget.n <= 0 then return end
    budget.n = budget.n - 1
    if site.fits(surface, base, m, c.o[1], c.o[2]) then base.cells[c.o[3]] = "taken"; return c.o, c.d, c.o[4], c.o[5] end
    -- Held or reserved ground may free up later: only a cell that does not fit physically is dropped.
    if not reserved(base, box_at(m, c.o[1], c.o[2], 1)) then base.cells[c.o[3]] = "bad" end
  end
end

-- Intermediate pylon points joining a module's pylon at (x, y) to the network.
function site.chain(base, x, y)
  local p, d = nearest_pylon(base, x, y)
  if not p or d <= shared.PYLON_REACH - 0.2 then return {}, p end
  local step = shared.PYLON_REACH - 5
  local n = math.ceil(d / step) - 1
  local pts = {}
  for i = 1, n do
    local t = i / (n + 1)
    table.insert(pts, {p[1] + (x - p[1]) * t, p[2] + (y - p[2]) * t})
  end
  return pts, p
end

return site
