-- Settlement architecture. A settlement is a set of hubs; a hub is a grid of blocks (scripts/blocks.lua)
-- separated by roads, grown cell by cell in the order its archetype prefers, where the terrain allows.
-- Variety comes from the settlement's doctrine, each hub's archetype, each block's layout variant and
-- mirror/transpose, and the terrain cells drop out on. Every draw comes from the settlement's seeded rng.
local shared = require("__landing-party__.shared")
local blocks = require("__landing-party__.scripts.blocks")
local rng = require("__landing-party__.scripts.rng")
local site = require("__landing-party__.scripts.site")

local layout = {}

local S, R, PITCH = blocks.SIZE, blocks.ROAD, blocks.PITCH

-- Doctrines: the character of a settlement.
--   hub_cap        blocks a hub grows to before a new hub is founded
--   walls          block roles that get a wall ring (and corner turrets)
--   outpost_turrets  mining outposts get a turret pair
--   pickets        walled radar pickets per hub, on the side facing the threat
--   reach          how far (tiles) a new hub may be founded from the last
layout.DOCTRINES = {
  bastion = {hub_cap = 7, mature = 10, walls = {pad = true, compound = true, fab = true, gen = true, depot = true, picket = true},
    outpost_turrets = true, pickets = 0, reach = 70},
  sprawl = {hub_cap = 4, mature = 8, walls = {pad = true, compound = true, picket = true}, outpost_turrets = false, pickets = 0,
    reach = 110},
  -- The uplink's settlement: everything walled, turreted outposts, pickets, a fortress at its heart.
  fortress = {hub_cap = 5, mature = 9, walls = {pad = true, compound = true, fab = true, gen = true, depot = true,
    picket = true}, outpost_turrets = true, pickets = 2, reach = 70},
  picket = {hub_cap = 5, mature = 8, walls = {pad = true, compound = true, picket = true}, outpost_turrets = true, pickets = 2,
    reach = 90},
}
layout.ARCHETYPES = {grid = 3, street = 2, cross = 2}

local CLEARABLE = {tree = true, ["simple-entity"] = true, resource = true, corpse = true, ["rail-remnants"] = true,
  fish = true}

local function generated(surface, x0, y0, x1, y1)
  for _, c in ipairs({{x0, y0}, {x1, y1}, {x0, y1}, {x1, y0}}) do
    if not surface.is_chunk_generated({math.floor(c[1] / 32), math.floor(c[2] / 32)}) then return false end
  end
  return true
end

-- Can a w x h area at (x0, y0) take a block? Its road ring must be clear of anything built, the area
-- itself also of water, roads already laid and more than `ore` ore tiles.
function layout.area_free(surface, x0, y0, w, h, ore)
  if not generated(surface, x0 - R, y0 - R, x0 + w + R, y0 + h + R) then return false end
  local ring = {{x0 - R + 0.1, y0 - R + 0.1}, {x0 + w + R - 0.1, y0 + h + R - 0.1}}
  for _, e in pairs(surface.find_entities_filtered{area = ring}) do
    if not CLEARABLE[e.type] then return false end
  end
  local inner = {{x0, y0}, {x0 + w, y0 + h}}
  if surface.count_tiles_filtered{area = inner, collision_mask = "water_tile", limit = 1} > 0 then return false end
  if surface.count_tiles_filtered{area = inner, name = shared.variants(shared.FLOORS), limit = 1} > 0 then return false end
  if surface.count_entities_filtered{area = inner, type = "resource"} > (ore or 6) then return false end
  return true
end

local function push(b, job) table.insert(b.queue, job) end

-- Join a pylon to come at (x, y) to the network: a chain of pylons and a road along it when it is far.
function layout.connect(b, x, y, module)
  local pts, anchor = site.chain(b, x, y)
  for _, pt in ipairs(pts) do
    push(b, {name = "lp-pylon", pos = pt, loose = true, module = module})
    table.insert(b.pylon_spots, pt)
  end
  -- Only long links get a road: a supply route worth driving, not a strip across a neighbouring block.
  if anchor and #pts > 1 then push(b, {tiles = layout.road_line(anchor, {x, y}, 1.5), module = module}) end
  table.insert(b.pylon_spots, {x, y})
end

-- Road tiles round a w x h area.
local function road_ring(x0, y0, w, h)
  local t = {}
  for x = x0 - R, x0 + w + R - 1 do
    for y = y0 - R, y0 + h + R - 1 do
      if x < x0 or x >= x0 + w or y < y0 or y >= y0 + h then table.insert(t, {x, y}) end
    end
  end
  return t
end

-- Road tiles along a segment, `half` tiles either side.
function layout.road_line(a, c, half)
  local t, seen = {}, {}
  local dx, dy = c[1] - a[1], c[2] - a[2]
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1 then return t end
  local nx, ny = -dy / len, dx / len
  for s = 0, len, 0.5 do
    for o = -half, half, 0.5 do
      local x = math.floor(a[1] + dx * s / len + nx * o)
      local y = math.floor(a[2] + dy * s / len + ny * o)
      local k = x .. ":" .. y
      if not seen[k] then seen[k] = true; table.insert(t, {x, y}) end
    end
  end
  return t
end

-- A wall ring on the edge tiles of a w x h area, with an opening in the middle of each side.
local function wall_ring(x0, y0, w, h)
  local out = {}
  local ox, oy = math.floor(w / 2) - blocks.OPENING / 2, math.floor(h / 2) - blocks.OPENING / 2
  for x = 0, w - 1 do
    for _, y in ipairs({0, h - 1}) do
      if x < ox or x >= ox + blocks.OPENING then table.insert(out, {"lp-wall", x0 + x + 0.5, y0 + y + 0.5}) end
    end
  end
  for y = 1, h - 2 do
    for _, x in ipairs({0, w - 1}) do
      if y < oy or y >= oy + blocks.OPENING then table.insert(out, {"lp-wall", x0 + x + 0.5, y0 + y + 0.5}) end
    end
  end
  return out
end

-- Open a block: record it, lay its road ring, queue its fixed entities. Slots are filled later.
local function open(b, hub, role, x0, y0, w, h, cells)
  local variants = blocks[role]
  local v = rng.pick(b.rng, variants)
  local t = {}
  if w == S and h == S then
    t = {flip_x = rng.next(b.rng) < 0.5, flip_y = rng.next(b.rng) < 0.5, transpose = rng.next(b.rng) < 0.5}
  end
  local block = {kind = role, hub = hub and hub.id, x0 = x0, y0 = y0, w = w, h = h, center = {x0 + w / 2, y0 + h / 2},
    entities = {}, slots = {}, opened = game.tick, walls = layout.DOCTRINES[b.doctrine].walls[role] or false,
    walled = false}
  local function at(e)
    local x, y = e[2], e[3]
    if w == S and h == S then x, y = blocks.transform(x, y, S, t) end
    return {x0 + x, y0 + y}
  end
  for _, e in ipairs(v.slots) do table.insert(block.slots, {name = e[1], pos = at(e)}) end
  table.insert(b.blocks, block)
  table.insert(b.modules, block)
  if hub then
    for _, c in ipairs(cells) do hub.cells[c[1] .. ":" .. c[2]] = block end
    hub.count = hub.count + 1
  end
  push(b, {tiles = road_ring(x0, y0, w, h), module = block})
  for _, e in ipairs(v.fixed) do
    local pos = at(e)
    if e[1] == "lp-pylon" then layout.connect(b, pos[1], pos[2], block) end
    if e[1] == "logo" then
      push(b, {logo = true, pos = pos, module = block})
    else
      push(b, {name = e[1], pos = pos, module = block})
    end
  end
  return block
end

-- Cells next to the hub's open cells that its archetype allows, best first.
local function candidates(b, hub)
  local out, seen = {}, {}
  for key in pairs(hub.cells) do
    local i, j = key:match("(-?%d+):(-?%d+)")
    i, j = tonumber(i), tonumber(j)
    for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
      local ci, cj = i + d[1], j + d[2]
      local k = ci .. ":" .. cj
      if not hub.cells[k] and not hub.bad[k] and not seen[k] then
        seen[k] = true
        local a, c = ci, cj
        if hub.axis == "y" then a, c = cj, ci end
        local ok, score = true, 0
        if hub.archetype == "grid" then score = math.abs(ci) + math.abs(cj) + 0.5 * math.max(math.abs(ci), math.abs(cj))
        elseif hub.archetype == "street" then ok = (c == 0 or c == 1); score = math.abs(a)
        elseif hub.archetype == "cross" then ok = (ci == 0 or cj == 0); score = math.abs(ci) + math.abs(cj) end
        if ok then table.insert(out, {i = ci, j = cj, k = k, score = score + 0.9 * rng.next(b.rng)}) end
      end
    end
  end
  table.sort(out, function(p, q) if p.score ~= q.score then return p.score < q.score end return p.k < q.k end)
  return out
end

local function new_hub(b, x0, y0)
  local hub = {id = #b.hubs + 1, x = x0, y = y0, cells = {}, bad = {}, count = 0,
    archetype = rng.weighted(b.rng, layout.ARCHETYPES), axis = rng.next(b.rng) < 0.5 and "x" or "y", pickets = 0}
  table.insert(b.hubs, hub)
  return hub
end

-- Open a block of `role` in the newest hub, or found a new hub when it is full or boxed in.
-- Returns the block opened (a new hub's compound when one was founded), or nil.
function layout.open_role(b, role)
  local surface = game.surfaces[b.surface]
  local hub = b.hubs[#b.hubs]
  if hub.count < layout.DOCTRINES[b.doctrine].hub_cap then
    for _, c in ipairs(candidates(b, hub)) do
      local x0, y0 = hub.x + c.i * PITCH, hub.y + c.j * PITCH
      if layout.area_free(surface, x0, y0, S, S) then
        return open(b, hub, role, x0, y0, S, S, {{c.i, c.j}}), hub
      end
      hub.bad[c.k] = true
    end
  end
  return layout.found(b)
end

-- A hub's open slot for `role` (fabricator, generator), opening a block if every one is taken.
-- Returns the slot, or the block opened instead (its slots are taken next time), or nil.
function layout.slot(b, role, entity)
  for _, block in ipairs(b.blocks) do
    if block.kind == role then
      for _, s in ipairs(block.slots) do
        if not s.queued and s.name == entity then return s, block end
      end
    end
  end
  return nil, layout.open_role(b, role)
end

-- Found a hub: near the outpost furthest from every hub when one is far, else a step from the newest hub.
function layout.found(b)
  local surface = game.surfaces[b.surface]
  local doc = layout.DOCTRINES[b.doctrine]
  local last = b.hubs[#b.hubs]
  local far, fd = nil, 90
  for _, m in ipairs(b.modules) do
    if m.kind == "mining" then
      local d = math.huge
      for _, h in ipairs(b.hubs) do
        d = math.min(d, math.sqrt((m.center[1] - h.x) ^ 2 + (m.center[2] - h.y) ^ 2))
      end
      if d > fd then far, fd = m, d end
    end
  end
  local tx, ty
  if far then
    -- Between the outpost and the network: a third of the way back towards the lander.
    tx = far.center[1] + (b.origin.x - far.center[1]) / 3
    ty = far.center[2] + (b.origin.y - far.center[2]) / 3
  else
    local a = 2 * math.pi * rng.next(b.rng)
    tx, ty = last.x + doc.reach * math.cos(a), last.y + doc.reach * math.sin(a)
  end
  for r = 0, 60, 4 do
    local steps = math.max(1, math.floor(2 * math.pi * r / 6))
    for k = 0, steps - 1 do
      local a = 2 * math.pi * k / steps
      local x0, y0 = math.floor(tx + r * math.cos(a)), math.floor(ty + r * math.sin(a))
      if layout.area_free(surface, x0, y0, S, S) then
        local hub = new_hub(b, x0, y0)
        local block = open(b, hub, "compound", x0, y0, S, S, {{0, 0}})
        return block, hub
      end
    end
  end
end

-- The landing pad: the first hub's two cells (0,0) and (1,0) as one walled area, the lander at its centre.
-- Returns the lander's position and the pad, or nil when nothing fits near pos.
function layout.land(b, surface, pos)
  for r = 0, 80, 3 do
    local steps = math.max(1, math.floor(2 * math.pi * r / 6))
    for k = 0, steps - 1 do
      local a = 2 * math.pi * k / steps
      local x0, y0 = math.floor(pos[1] + r * math.cos(a)) - 20, math.floor(pos[2] + r * math.sin(a)) - 9
      if layout.area_free(surface, x0, y0, blocks.PAD_W, S, 12) then
        local hub = new_hub(b, x0, y0)
        local pad = open(b, hub, "pad", x0, y0, blocks.PAD_W, S, {{0, 0}, {1, 0}})
        -- The lander's box is off-centre ({-8.7, -3.3} to {6.9, 4.5}): shift it to sit mid-pad.
        return {x0 + blocks.PAD_W / 2 + 0.9, y0 + S / 2 - 0.6}, pad
      end
    end
  end
end

-- The uplink's fortress: three hub cells by three (FORT tiles square) as one block. Three concentric wall
-- rings, each opened on a different side so there is no straight path in, a belt of turrets inside each
-- ring, generators between the rings, the lander and the uplink in the inner yard. Built at once, from
-- the parts the uplink lands with.
local FORT = 3 * PITCH - R
local RINGS = {0, 8, 16}
local OPENINGS = {"north", "east", "south"}
function layout.fortress_entities(x0, y0)
  local out = {}
  for _, p in ipairs({4.5, 22.5, 39.5, 57.5}) do
    for _, q in ipairs({4.5, 22.5, 39.5, 57.5}) do table.insert(out, {"lp-pylon", x0 + p, y0 + q}) end
  end
  for k, r in ipairs(RINGS) do
    local lo, hi = r, FORT - 1 - r
    local mid = math.floor(FORT / 2)
    local function opening(side, t) return OPENINGS[k] == side and t >= mid - 2 and t < mid + 2 end
    for t = lo, hi do
      if not opening("north", t) then table.insert(out, {"lp-wall", x0 + t + 0.5, y0 + lo + 0.5}) end
      if not opening("south", t) then table.insert(out, {"lp-wall", x0 + t + 0.5, y0 + hi + 0.5}) end
      if t > lo and t < hi then
        if not opening("west", t) then table.insert(out, {"lp-wall", x0 + lo + 0.5, y0 + t + 0.5}) end
        if not opening("east", t) then table.insert(out, {"lp-wall", x0 + hi + 0.5, y0 + t + 0.5}) end
      end
    end
    -- Turrets two tiles inside the ring, every six tiles, clear of the opening. The top and bottom rows
    -- take the corners; the sides start one step in (both once placed a turret on each corner, and one of
    -- each pair was blocked).
    for t = lo + 3, hi - 3, 6 do
      if math.abs(t - mid) > 4 then
        table.insert(out, {"lp-turret", x0 + t + 1, y0 + lo + 3})
        table.insert(out, {"lp-turret", x0 + t + 1, y0 + hi - 2})
        if t > lo + 3 and t < hi - 8 then
          table.insert(out, {"lp-turret", x0 + lo + 3, y0 + t + 1})
          table.insert(out, {"lp-turret", x0 + hi - 2, y0 + t + 1})
        end
      end
    end
  end
  -- Generators in the band between the outer two rings (two placed among turrets were blocked).
  for _, g in ipairs({{13, 5}, {48, 5}, {13, 57}, {48, 57}, {5, 31}, {57, 31}}) do
    table.insert(out, {"lp-generator", x0 + g[1], y0 + g[2]})
  end
  return out
end

function layout.land_fortress(b, surface, pos)
  for r = 0, 100, 4 do
    local steps = math.max(1, math.floor(2 * math.pi * r / 8))
    for k = 0, steps - 1 do
      local a = 2 * math.pi * k / steps
      local x0, y0 = math.floor(pos[1] + r * math.cos(a)) - FORT / 2, math.floor(pos[2] + r * math.sin(a)) - FORT / 2
      if layout.area_free(surface, x0, y0, FORT, FORT, 40) then
        local hub = new_hub(b, x0, y0)
        local cells = {}
        for i = 0, 2 do for j = 0, 2 do table.insert(cells, {i, j}) end end
        local block = {kind = "fortress", hub = hub.id, x0 = x0, y0 = y0, w = FORT, h = FORT,
          center = {x0 + FORT / 2, y0 + FORT / 2}, entities = {}, slots = {}, opened = game.tick, walls = false,
          walled = true}
        table.insert(b.blocks, block)
        table.insert(b.modules, block)
        for _, c in ipairs(cells) do hub.cells[c[1] .. ":" .. c[2]] = block end
        hub.count = hub.count + 1
        push(b, {tiles = road_ring(x0, y0, FORT, FORT), module = block})
        for _, e in ipairs(layout.fortress_entities(x0, y0)) do
          if e[1] == "lp-pylon" then layout.connect(b, e[2], e[3], block) end
          push(b, {name = e[1], pos = {e[2], e[3]}, module = block})
        end
        -- The lander sits mid-yard (its box is off-centre), the uplink above it.
        return {x0 + FORT / 2 + 0.9, y0 + FORT / 2 - 0.6 + 2}, block, {x0 + FORT / 2, y0 + 21}
      end
    end
  end
end

-- Walls (and corner turrets) for the first block that should have them and has stood a while.
function layout.fortify(b)
  for _, block in ipairs(b.blocks) do
    if block.walls and not block.walled and game.tick - block.opened > 600 then
      block.walled = true
      for _, w in ipairs(wall_ring(block.x0, block.y0, block.w, block.h)) do
        push(b, {name = w[1], pos = {w[2], w[3]}, module = block})
      end
      if block.kind ~= "picket" and block.kind ~= "depot" then
        local corners = {{2, 2}, {block.w - 2, 2}, {2, block.h - 2}, {block.w - 2, block.h - 2}}
        for _, c in ipairs(corners) do
          push(b, {name = "lp-turret", pos = {block.x0 + c[1], block.y0 + c[2]}, module = block})
        end
      end
      return block
    end
  end
end

-- Maturity on a hard point (pad, compound): lamps inside the walls, the yard paved, mines on the road
-- outside each opening. Once per block, after its walls.
function layout.embellish(b)
  for _, block in ipairs(b.blocks) do
    if (block.kind == "pad" or block.kind == "compound") and block.walled and not block.embellished then
      block.embellished = true
      local x0, y0, w, h = block.x0, block.y0, block.w, block.h
      local paving = {}
      for x = x0 + 1, x0 + w - 2 do for y = y0 + 1, y0 + h - 2 do table.insert(paving, {x, y}) end end
      push(b, {tiles = paving, floor = "pad", module = block})
      for _, p in ipairs({{4.5, 1.5}, {w - 4.5, 1.5}, {4.5, h - 1.5}, {w - 4.5, h - 1.5}}) do
        push(b, {name = "lp-lamp", pos = {x0 + p[1], y0 + p[2]}, module = block})
      end
      local mx, my = x0 + math.floor(w / 2), y0 + math.floor(h / 2)
      for _, d in ipairs({-1.5, 0.5}) do
        for _, out in ipairs({1.5, 3.5}) do
          push(b, {name = "lp-mine", pos = {mx + d + 0.5, y0 - out}, module = block})
          push(b, {name = "lp-mine", pos = {mx + d + 0.5, y0 + h + out - 1}, module = block})
          push(b, {name = "lp-mine", pos = {x0 - out, my + d + 0.5}, module = block})
          push(b, {name = "lp-mine", pos = {x0 + w + out - 1, my + d + 0.5}, module = block})
        end
      end
      return block
    end
  end
end

-- A walled radar picket between a hub and the threat, off the grid.
function layout.picket(b, hub, threat)
  local surface = game.surfaces[b.surface]
  local cx, cy = hub.x + S / 2, hub.y + S / 2
  local dx, dy = threat[1] - cx, threat[2] - cy
  local len = math.max(1, math.sqrt(dx * dx + dy * dy))
  local spread = (hub.pickets % 2 == 0 and 1 or -1) * math.ceil(hub.pickets / 2) * 0.6
  local a = math.atan2(dy, dx) + spread
  local d = math.min(55, len / 2)
  local P = blocks.PICKET
  for r = 0, 30, 3 do
    for k = 0, 7 do
      local x0 = math.floor(cx + d * math.cos(a) + r * math.cos(k * math.pi / 4)) - P / 2
      local y0 = math.floor(cy + d * math.sin(a) + r * math.sin(k * math.pi / 4)) - P / 2
      if layout.area_free(surface, x0, y0, P, P, 2) then
        hub.pickets = hub.pickets + 1
        return open(b, nil, "picket", x0, y0, P, P)
      end
    end
  end
  hub.pickets = hub.pickets + 1  -- no room: do not ask again for this one
end

-- Seed a settlement's character.
function layout.init(b, seed, doctrine)
  b.rng = rng.new(seed)
  b.doctrine = doctrine or rng.weighted(b.rng, {bastion = 1, sprawl = 1, picket = 1})
  b.hubs, b.blocks = {}, {}
end

return layout
