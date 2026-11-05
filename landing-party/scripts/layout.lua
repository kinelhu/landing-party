-- Settlement architecture. A settlement is a set of hubs; a hub is a grid of blocks (scripts/blocks.lua)
-- separated by roads, grown cell by cell in the order its archetype prefers, where the terrain allows.
-- Variety comes from the settlement's doctrine, each hub's archetype, each block's layout variant and
-- mirror/transpose, and the terrain cells drop out on. Every draw comes from the settlement's seeded rng.
local shared = require("__landing-party__.shared")
local blocks = require("__landing-party__.scripts.blocks")
local rng = require("__landing-party__.scripts.rng")
local wfc = require("__landing-party__.scripts.wfc")
local WFC_TILES = {serenity = require("__landing-party__.scripts.wfc_serenity")}
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

-- (Cliffs too: blown up when it builds, shared.blast.)
local CLEARABLE = {tree = true, ["simple-entity"] = true, resource = true, corpse = true, ["rail-remnants"] = true, cliff = true,
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
  local b = layout.measuring
  for _, e in pairs(surface.find_entities_filtered{area = ring}) do
    if not CLEARABLE[e.type] or (e.type == "cliff" and not shared.cliff_clears()) then shared.refused(b, e.type == "cliff" and "cliff" or "built") return false end
  end
  local inner = {{x0, y0}, {x0 + w, y0 + h}}
  local wet = surface.count_tiles_filtered{area = inner, collision_mask = "water_tile", limit = shared.LANDFILL_MAX + 1}
  if wet > 0 and not (shared.fills(b) and wet <= shared.LANDFILL_MAX) then
    shared.refused(b, "water") return false
  end
  if surface.count_tiles_filtered{area = inner, name = shared.variants(shared.FLOORS), limit = 1} > 0 then
    shared.refused(b, "floor") return false
  end
  if surface.count_entities_filtered{area = inner, type = "resource"} > (ore or 6) then shared.refused(b, "ore") return false end
  return true
end

local function push(b, job) table.insert(b.queue, job) end

-- Join a pylon to come at (x, y) to the network: a chain of pylons and a road along it when it is far.
function layout.connect(b, x, y, module)
  local pts, anchor = site.chain(b, x, y)
  -- Each spot remembers its module: one given up is no anchor (site.nearest_pylon). Untagged, a copper mine chained to
  -- the pylon of a coal mine given up by the player's wall, and stood unpowered (the user, deathworld10x, 2026-10-17).
  for _, pt in ipairs(pts) do
    push(b, {name = "lp-pylon", pos = pt, loose = true, module = module})
    table.insert(b.pylon_spots, {pt[1], pt[2], m = module})
  end
  -- Only long links get a road: a supply route worth driving, not a strip across a neighbouring block.
  if anchor and #pts > 1 then push(b, {tiles = layout.road_line(anchor, {x, y}, 1.5), module = module}) end
  table.insert(b.pylon_spots, {x, y, m = module})
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
-- A spread block's ground (layout.spread): the block and its road ring with its corners cut back CLUSTER_CUT, paved
-- whole; side by side they merge into one lobed plate (the user: "it's all squares everywhere").
local CLUSTER_CUT = 6
local function lobe(x0, y0, w, h)
  local r = {x0 - R, y0 - R, x0 + w + R, y0 + h + R}
  local out = {}
  for x = r[1], r[3] - 1 do
    for y = r[2], r[4] - 1 do
      local cx, cy = x + 0.5, y + 0.5
      if math.min(cx - r[1], r[3] - cx) + math.min(cy - r[2], r[4] - cy) > CLUSTER_CUT then table.insert(out, {x, y}) end
    end
  end
  return out
end

-- Its ground cleared when a block or district is founded (the user, 2026-10-21: trees stood inside the landing pad's
-- walls, over the lander; "a little deforestation"): trees, rocks and scrub go.
local function clear_ground(b, x0, y0, w, h)
  local s = game.surfaces[b.surface]
  local area = {{x0, y0}, {x0 + w, y0 + h}}
  for _, e in pairs(s.find_entities_filtered{area = area, type = {"tree", "simple-entity"}}) do e.destroy() end
  shared.blast(s, {{x0 - R, y0 - R}, {x0 + w + R, y0 + h + R}}, b)   -- its road margin too
  s.destroy_decoratives{area = area}
end
layout.clear_ground = clear_ground

-- Towns (Grubstake; the user, 2026-10-26: "WFC with larger chunks and very few walls so we get a sprawl that doesn't
-- block movement"). A town hub is a grid of LOT x LOT lots, hand-made in scripts/wfc/grubstake.tiles (previews:
-- scripts/wfc/sprawl.py; made into scripts/lots_grubstake.lua). Its streets grow as a tree from its pad (or, for a new
-- hub, from a crossing with its own generators, its compound): an open street end takes the lot the planner asks for (a
-- fabricator row, a generator lot, a depot yard), by chance a crossing, a turn or a stretch of street first, so the
-- streets branch. A lot's street runs through its middle and its machines stand either side, off its edges: every lot
-- is open ground to walk and drive through, and no wall stands but its pad's fence. Beside a new lot, by chance, a yard
-- of junk (wrecks, crates, a tank, ore heaps: neutral props, cleared when a lot takes the ground).
local LOT = 12
local LOTS = {grubstake = require("__landing-party__.scripts.lots_grubstake")}
local ROLE_LOTS = {fab = {fab = 1, fab_row = 1, fab3 = 1, corner_fab = 1, tee_fab = 1, corner_yard = 0.5},
  gen = {power = 1, power2 = 1, corner_power = 1, tee_power = 1}, depot = {depot = 1, depot2 = 1}, compound = {compound = 1}}
-- (guardpost: two of its guns either side of a street, behind junk: turrets in the town, not only at its ends.)
local CONNECT_LOTS = {straight = 3, straight_lamp = 2, corner = 2, tee = 2, cross = 1, guardpost = 0.6, parking = 1,
  radar = 0.4}
local YARD_LOTS = {scrap = 3, orepile = 2, stockpile = 2, tankfarm = 1, vehicle_yard = 1, fueldump = 1, wreckpile = 2,
  shacks = 2}
local BRANCH = 0.6             -- a crossing, turn or stretch laid before the lot asked for (0.35: 45 minutes in, a town of
                               -- three lots; Grubstake builds few machines, its sprawl is its streets)
local YARD = 0.7               -- a yard beside a new lot
local TREE_MARGIN = 4          -- trees cleared this far round a lot (twice that to its south)
local STREETS_PER_LOT, STREETS_FREE = 2, 4
local CAPITAL_PER_LOT, CAPITAL_FREE = 3, 12
local NEST_EVERY = 4           -- every this many lots with machines, a turret nest closes its farthest street end
local TOWN_CAP = 14            -- lots with machines in a town hub before a new hub is founded
local LETTER = {F = {"lp-fabricator", 3}, G = {"lp-generator", 2}, D = {"lp-depot", 4}, R = {"lp-radar", 3},
  T = {"lp-turret", 2}, P = {"lp-pylon", 1}, L = {"lp-post-lamp", 1}}
local DECOR = {W = 2, X = 1, C = 1, O = 2, K = 3, I = 1, V = 2, M = 3, U = 1}
-- Waterfront lots (the user, 2026-10-26, "water-incorporating WFC tiles"): a street end on a shore, its pier over the
-- water ('=' landfilled and gravelled, '~' water left), its far half water where the lot stands (pier_try).
local PIER_LOTS = {pier = 1, pier_pump = 1, pier_shack = 1}
local PIER_WET = 0.6           -- of its water half, water at least
local PIER_SHORE = 0.15        -- of its shore half, water at most (landfilled: a ragged shoreline)
local DECOR_NAMES = {["wooden-chest"] = true, ["storage-tank"] = true, pipe = true, ["big-rock"] = true, car = true,
  ["offshore-pump"] = true,
  ["small-electric-pole"] = true}
local POLE_CHANCE = 0.18
for k = 1, 6 do DECOR_NAMES["crash-site-spaceship-wreck-small-" .. k] = true end
for k = 1, 3 do DECOR_NAMES["crash-site-spaceship-wreck-medium-" .. k] = true end
local DIRS = {n = {0, -1}, s = {0, 1}, e = {1, 0}, w = {-1, 0}}
local BACK = {n = "s", s = "n", e = "w", w = "e"}

function layout.town(b)
  return (shared.CORPS[b.corp].arch or {}).town and LOTS[b.corp] ~= nil and not storage.town_off
end

-- Its capital (the user, 2026-10-26: "have the cap vary per town with room for one very large town existing at once";
-- "go with the capital idea"): the oldest standing town of its corporation. It grows CAPITAL_PER_LOT streets a lot
-- with machines and CAPITAL_FREE more, where the others grow STREETS_PER_LOT and STREETS_FREE, and it takes a second
-- depot (planner rule depot): the big town is where its big raids come from.
function layout.capital(b)
  local best, bid
  for id, o in pairs(storage.bases or {}) do
    if o.corp == b.corp and o.lander and o.lander.valid and not o.fallen and o.hubs and o.hubs[1] and o.hubs[1].lots
      and (not bid or id < bid) then best, bid = o, id end
  end
  return best == b
end

-- Variants by name, then by the sides their street opens on ("ns", "enw"...).
local function lot_index(corp)
  local set = LOTS[corp]
  if set.by then return set.by end
  set.by = {}
  for _, v in ipairs(set.variants) do
    set.by[v.name] = set.by[v.name] or {}
    set.by[v.name][v.opens] = set.by[v.name][v.opens] or {}
    table.insert(set.by[v.name][v.opens], v)
  end
  return set.by
end
local function sides(t)
  local out = {}
  for _, d in ipairs({"e", "n", "s", "w"}) do if t[d] then table.insert(out, d) end end
  return table.concat(out)
end

local function lot_xy(hub, i, j) return hub.x + i * LOT, hub.y + j * LOT end

-- Can the lot at (i, j) take a lot: generated, no water, no floor laid, little ore, nothing standing but trees, rocks
-- and a yard's props.
local function lot_free(b, hub, i, j)
  local k = i .. ":" .. j
  if hub.bad[k] or (hub.lots[k] and not hub.lots[k].yard) then return false end
  local surface = game.surfaces[b.surface]
  local x0, y0 = lot_xy(hub, i, j)
  if not generated(surface, x0, y0, x0 + LOT, y0 + LOT) then return false end
  local area = {{x0 + 0.1, y0 + 0.1}, {x0 + LOT - 0.1, y0 + LOT - 0.1}}
  local function bad(why) shared.refused(b, why) hub.bad[k] = true return false end
  for _, e in pairs(surface.find_entities_filtered{area = area}) do
    if (not CLEARABLE[e.type] or (e.type == "cliff" and not shared.cliff_clears()))
      and not (e.force.name == "neutral" and DECOR_NAMES[e.name]) then
      return bad(e.type == "cliff" and "cliff" or "built")
    end
  end
  if surface.count_tiles_filtered{area = area, collision_mask = "water_tile", limit = 1} > 0
    or surface.count_tiles_filtered{area = area, name = shared.variants(shared.FLOORS), limit = 1} > 0
    -- No ore: a town grows round its patches, never over them (its drills' and its claims' ground: prospect, road).
    or surface.count_entities_filtered{area = area, type = "resource", limit = 1} > 0 then
    return bad("water, floor or ore")
  end
  return true
end

local function decor(surface, ch, pos, r)
  local name = (ch == "W" or ch == "X") and ("crash-site-spaceship-wreck-small-" .. (1 + math.floor(r * 6)))
    or ch == "C" and "wooden-chest" or ch == "O" and "big-rock" or ch == "K" and "storage-tank" or ch == "I" and "pipe"
    or ch == "U" and "offshore-pump" or ch == "V" and "car" or ch == "M" and ("crash-site-spaceship-wreck-medium-" .. (1 + math.floor(r * 3)))
  if not name then return end
  local dir = defines.direction.north
  if name == "offshore-pump" then
    dir = nil
    for _, d in ipairs({defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west}) do
      if surface.can_place_entity{name = name, position = pos, direction = d} then dir = d break end
    end
    if not dir then return end
  elseif not surface.can_place_entity{name = name, position = pos} then return end
  local e = surface.create_entity{name = name, position = pos, force = "neutral", direction = dir}
  if not e then return end
  if name ~= "big-rock" then e.minable_flag = false end
  -- A parked car: set dressing, never a free ride.
  if name == "car" then e.operable, e.disabled_by_script = false, true end
end

-- Worn ground under a lot (the user, 2026-10-26: "changing the ground underneath the town also (perhaps dirt/sand). It
-- looks a little too clean"): its bare tiles turned to dirt, dry dirt and sand in clumps of WORN_CLUMP tiles, fading out
-- WORN_FADE tiles past its edge so no square shows. Natural ground only (never water, a floor laid or a street), set at
-- once and free: it is trodden earth, not something built.
local WORN = {"dirt-4", "dirt-5", "dirt-6", "dry-dirt", "sand-2", "dirt-3"}
local WORN_CLUMP, WORN_FADE = 4, 3
local function hash(x, y, k) return ((x * 73856093 + y * 19349663 + k * 83492791) % 1000003) / 1000003 end
local function worn(surface, x0, y0, skip)
  local tiles = {}
  for x = x0 - WORN_FADE, x0 + LOT + WORN_FADE - 1 do
    for y = y0 - WORN_FADE, y0 + LOT + WORN_FADE - 1 do
      local out = math.max(x0 - x, x - (x0 + LOT - 1), y0 - y, y - (y0 + LOT - 1), 0)
      local keep = 1 - out / (WORN_FADE + 1)
      if not skip[x .. "," .. y] and hash(x, y, 7) < keep then
        local t = surface.get_tile(x, y)
        local name = t.valid and t.name
        if name and not t.collides_with("water_tile") and not name:find("^lp%-") and not t.prototype.mineable_properties.minable then
          local cx, cy = math.floor(x / WORN_CLUMP), math.floor(y / WORN_CLUMP)
          table.insert(tiles, {name = WORN[1 + math.floor(hash(cx, cy, 3) * #WORN)], position = {x, y}})
        end
      end
    end
  end
  if #tiles > 0 then surface.set_tiles(tiles, true, false, true, false) end
end

-- Lay a lot: its street and yard floors, its machines (slots for the role asked, the rest queued), its props.
local function lot_open(b, hub, i, j, v, role)
  local surface = game.surfaces[b.surface]
  local x0, y0 = lot_xy(hub, i, j)
  clear_ground(b, x0, y0, LOT, LOT)
  for _, e in pairs(surface.find_entities_filtered{area = {{x0, y0}, {x0 + LOT, y0 + LOT}}, force = "neutral"}) do
    if DECOR_NAMES[e.name] then e.destroy() end
  end
  -- Trees round it too (TREE_MARGIN, more to the south): a tree's sprite stands tall over the ground north of it, and
  -- the forest beside a cleared lot hid its street and machines (screenshots, 2026-10-26).
  for _, e in pairs(surface.find_entities_filtered{type = "tree", area = {{x0 - TREE_MARGIN, y0 - TREE_MARGIN},
    {x0 + LOT + TREE_MARGIN, y0 + LOT + 2 * TREE_MARGIN}}}) do e.destroy() end
  local yard = YARD_LOTS[v.name] ~= nil
  local block = {kind = role or (yard and "yard" or "street"), hub = hub.id, x0 = x0, y0 = y0, w = LOT, h = LOT,
    center = {x0 + LOT / 2, y0 + LOT / 2}, entities = {}, slots = {}, opened = game.tick, walls = false, walled = false,
    lot = v.name, opens = v.opens, yard = yard or nil, liveried = true, embellished = true, weight = role and 1 or 0}
  hub.lots[i .. ":" .. j] = block
  if not yard then
    table.insert(b.blocks, block)
    table.insert(b.modules, block)
  end
  if role then hub.count = hub.count + 1 end
  local slot = role == "fab" and "F" or role == "gen" and "G" or nil
  local road, hazard, pier = {}, {}, {}
  local function at(c, r) local row = v.rows[r]; return row and row:sub(c, c) or nil end
  for r, row in ipairs(v.rows) do
    for c = 1, #row do
      local ch = row:sub(c, c)
      local x, y = x0 + c - 1, y0 + r - 1
      if ch == ":" or ch == "." then table.insert(road, {x, y})
      elseif ch == "%" then table.insert(hazard, {x, y})
      elseif ch == "=" then table.insert(pier, {name = "landfill", position = {x, y}}); table.insert(road, {x, y}) end
      local L = not yard and LETTER[ch]
      if L then
        local pos = {x + L[2] / 2, y + L[2] / 2}
        if ch == slot then
          table.insert(block.slots, {name = L[1], pos = pos})
        else
          if ch == "P" then layout.connect(b, pos[1], pos[2], block) end
          push(b, {name = L[1], pos = pos, module = block})
          -- A turret's pit: its fence on the bare tiles hugging it (the user, 2026-10-26: "turrets could have some walls
          -- around them ... very close to them, not enclosing a whole block"); open where it meets the street.
          if ch == "T" then
            for dc = -1, 2 do
              for dr = -1, 2 do
                local n = at(c + dc, r + dr)
                if (dc == -1 or dc == 2 or dr == -1 or dr == 2) and (n == " " or n == ".") then   -- (not on X: a wreck stands there)
                  push(b, {name = "lp-wall", pos = {x + dc + 0.5, y + dr + 0.5}, module = block})
                end
              end
            end
          end
        end
      elseif DECOR[ch] then
        decor(surface, ch, {x + DECOR[ch] / 2, y + DECOR[ch] / 2}, rng.next(b.rng))
      end
    end
  end
  -- Its pier: landfill first (the water under '='), the gravel over it in the road job.
  if #pier > 0 then surface.set_tiles(pier, true, false, true, false) end
  if #road > 0 then push(b, {tiles = road, module = block}) end
  if #hazard > 0 then push(b, {tiles = hazard, floor = "hazard", module = block}) end
  -- Wooden poles beside its street (the user: "some wooden poles in addition to the existing pylons ... make it look
  -- busier"): neutral props on bare tiles next to the gravel, POLE_CHANCE of them, wired to each other by the engine.
  if not yard then
    for r, row in ipairs(v.rows) do
      for c = 1, #row do
        if row:sub(c, c) == " " and c > 1 and c < LOT and r > 1 and r < LOT and hash(x0 + c, y0 + r, 11) < POLE_CHANCE
          and (at(c - 1, r) == ":" or at(c + 1, r) == ":" or at(c, r - 1) == ":" or at(c, r + 1) == ":") then
          local pos = {x0 + c - 0.5, y0 + r - 0.5}
          if surface.can_place_entity{name = "small-electric-pole", position = pos} then
            local e = surface.create_entity{name = "small-electric-pole", position = pos, force = "neutral"}
            if e then e.minable_flag = false end
          end
        end
      end
    end
  end
  local skip = {}
  for _, t in ipairs(road) do skip[t[1] .. "," .. t[2]] = true end
  for _, t in ipairs(hazard) do skip[t[1] .. "," .. t[2]] = true end
  worn(surface, x0, y0, skip)
  return block
end

-- A variant among `names` (name = weight) whose street opens on exactly `opens`, by weight.
local function pick_lot(b, names, opens)
  local by = lot_index(b.corp)
  local opts, total = {}, 0
  local order = {}
  for name in pairs(names) do table.insert(order, name) end
  table.sort(order)
  for _, name in ipairs(order) do
    for _, v in ipairs((by[name] or {})[opens] or {}) do
      local w = names[name] * v.weight
      table.insert(opts, {v = v, w = w})
      total = total + w
    end
  end
  if total <= 0 then return nil end
  local r = rng.next(b.rng) * total
  for _, o in ipairs(opts) do
    r = r - o.w
    if r <= 0 then return o.v end
  end
  return opts[#opts].v
end

-- A yard of junk beside a lot, by chance.
local function town_yard(b, hub, i, j)
  if rng.next(b.rng) >= YARD then return end
  for _, d in ipairs({"n", "e", "s", "w"}) do
    local ci, cj = i + DIRS[d][1], j + DIRS[d][2]
    if not hub.lots[ci .. ":" .. cj] and lot_free(b, hub, ci, cj) then
      local v = pick_lot(b, YARD_LOTS, "")
      if v then lot_open(b, hub, ci, cj, v) end
      return
    end
  end
end

-- The open street end to build on: nearest the hub first, by chance. Ends that can take no lot are dropped (their
-- street runs off into the open).
-- A lot may touch no other lot but the one its street comes from and yards (the previews' rule: else streets ran side by
-- side a lot apart, and ended against lots that did not open to them).
local function alone(hub, e)
  for d, v in pairs(DIRS) do
    local n = hub.lots[(e.i + v[1]) .. ":" .. (e.j + v[2])]
    if d ~= e.back and n and not n.yard then return false end
  end
  return true
end

-- A waterfront lot on end e (its street ending on a shore): a pier variant facing back, where its shore cells are all dry,
-- PIER_WET of its water cells water, and nothing stands on it but what a lot clears. Laid, or nil.
local function pier_try(b, hub, e)
  e.pier_tried = true
  if storage.pier_off then return nil end
  local function no(why)
    if layout.trace then layout.trace(b, string.format("town: no pier at lot %d,%d (back %s): %s", e.i, e.j, e.back, why)) end
    return nil
  end
  if hub.lots[e.i .. ":" .. e.j] then return no("taken") end
  if not alone(hub, e) then return no("not alone") end
  local surface = game.surfaces[b.surface]
  local x0, y0 = lot_xy(hub, e.i, e.j)
  if not generated(surface, x0, y0, x0 + LOT, y0 + LOT) then return nil end
  for _, en in pairs(surface.find_entities_filtered{area = {{x0 + 0.1, y0 + 0.1}, {x0 + LOT - 0.1, y0 + LOT - 0.1}}}) do
    if not CLEARABLE[en.type] and not (en.force.name == "neutral" and DECOR_NAMES[en.name]) then return no("built: " .. en.name) end
  end
  -- Each variant facing back tried against the ground, with no draw (a draw for every end looked at changed every
  -- later choice of its camp, on maps with no water at all: heist, plate grubstake); drawn among those that fit.
  local by = lot_index(b.corp)
  local fits, why = {}, "no variant"
  local names = {}
  for name in pairs(PIER_LOTS) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    for _, v in ipairs((by[name] or {})[e.back] or {}) do
      local wet, cells, shore, damp = 0, 0, 0, {}
      for r, row in ipairs(v.rows) do
        for c = 1, #row do
          local ch = row:sub(c, c)
          local t = surface.get_tile(x0 + c - 1, y0 + r - 1)
          local water = t.valid and t.collides_with("water_tile")
          if ch == "~" or ch == "=" then
            cells = cells + 1
            if water then wet = wet + 1 end
          else
            shore = shore + 1
            if water then damp[#damp + 1] = {name = "landfill", position = {x0 + c - 1, y0 + r - 1}} end
          end
        end
      end
      if #damp > PIER_SHORE * shore then why = string.format("%d of %d shore cells water", #damp, shore)
      elseif cells == 0 or wet < PIER_WET * cells then why = string.format("%d of %d water cells wet", wet, cells)
      else fits[#fits + 1] = {v = v, damp = damp} end
    end
  end
  if #fits == 0 then return no(why) end
  local f = fits[1 + math.floor(rng.next(b.rng) * #fits)]
  local v = f.v
  if #f.damp > 0 then surface.set_tiles(f.damp, true, false, true, false) end
  for idx, x in ipairs(hub.ends) do if x == e then table.remove(hub.ends, idx) break end end
  local block = lot_open(b, hub, e.i, e.j, v, nil)
  if block then b.piers = (b.piers or 0) + 1 end
  return block
end

local function town_end(b, hub)
  -- Ends on a shore get their waterfront lot first (pier_try), once each.
  local ends = {}
  for _, e in ipairs(hub.ends) do ends[#ends + 1] = e end
  for _, e in ipairs(ends) do
    if not e.pier_tried and not hub.lots[e.i .. ":" .. e.j] and not lot_free(b, hub, e.i, e.j) then pier_try(b, hub, e) end
  end
  local keep, best, bs = {}, nil, nil
  for _, e in ipairs(hub.ends) do
    if lot_free(b, hub, e.i, e.j) and alone(hub, e) then
      table.insert(keep, e)
      local sc = math.abs(e.i) + math.abs(e.j) + 3 * rng.next(b.rng)
      if not bs or sc < bs then best, bs = e, sc end
    end
  end
  hub.ends = keep
  return best
end

-- A lot on end e, among `names`, its street going on to `outs` (besides back the way it came).
local function lay(b, hub, e, names, role, outs)
  local open = {[e.back] = true}
  for _, d in ipairs(outs) do open[d] = true end
  local v = pick_lot(b, names, sides(open))
  if not v then return nil end
  for k, x in ipairs(hub.ends) do if x == e then table.remove(hub.ends, k) break end end
  local block = lot_open(b, hub, e.i, e.j, v, role)
  if not role and not block.yard then hub.streets = (hub.streets or 0) + 1 end
  -- Its street joined to the pad it starts from (the pad is narrower than its lots: a strip of grass stood between).
  local back = hub.lots[(e.i + DIRS[e.back][1]) .. ":" .. (e.j + DIRS[e.back][2])]
  if back and back.pad and hub.pad_box then
    local p, x0, y0 = hub.pad_box, lot_xy(hub, e.i, e.j)
    local t = {}
    if e.back == "s" or e.back == "n" then
      local ya, yb = e.back == "n" and p[4] or y0 + LOT, e.back == "n" and y0 - 1 or p[2] - 1
      for y = ya, yb do for x = x0 + 5, x0 + 6 do table.insert(t, {x, y}) end end
    else
      local xa, xb = e.back == "w" and p[3] or x0 + LOT, e.back == "w" and x0 - 1 or p[1] - 1
      for x = xa, xb do for y = y0 + 5, y0 + 6 do table.insert(t, {x, y}) end end
    end
    if #t > 0 then push(b, {tiles = t, module = block}) end
  end
  for _, d in ipairs(outs) do table.insert(hub.ends, {i = e.i + DIRS[d][1], j = e.j + DIRS[d][2], back = BACK[d]}) end
  return block
end

-- A town grows with its wealth (planner rule "town": parts to spare): a stretch of street, a turn or a crossing at an
-- open end of its newest town hub, a yard beside it by chance. A camp kept poor stays a few sheds round its pad; one
-- left alone sprawls. Nil when no end can take a lot.
function layout.town_grow(b)
  local hub
  for k = #b.hubs, 1, -1 do if b.hubs[k].lots and #b.hubs[k].ends > 0 then hub = b.hubs[k] break end end
  -- Streets in proportion to its industry (STREETS_PER_LOT a lot with machines, STREETS_FREE more): wealth shows as a
  -- town, not a grid of empty gravel (seed 777, 90 minutes: mostly empty streets).
  if not hub then return nil end
  local cap = layout.capital(b) and CAPITAL_PER_LOT * hub.count + CAPITAL_FREE
    or STREETS_PER_LOT * hub.count + STREETS_FREE
  if (hub.streets or 0) >= cap then return nil end
  local e = town_end(b, hub)
  if not e then return nil end
  local fwd = BACK[e.back]
  local others = {}
  for _, d in ipairs({"e", "n", "s", "w"}) do if d ~= e.back and d ~= fwd then table.insert(others, d) end end
  local r = rng.next(b.rng)
  local outs = r < 0.45 and {fwd} or r < 0.65 and {others[1 + math.floor(rng.next(b.rng) * 2)]}
    or r < 0.9 and {fwd, others[1 + math.floor(rng.next(b.rng) * 2)]} or {fwd, others[1], others[2]}
  local block = lay(b, hub, e, CONNECT_LOTS, nil, outs)
  if block then town_yard(b, hub, e.i, e.j) end
  return block
end

-- A town grown at once, for pictures (remote debug_town; scripts/shots.sh town): `machines` lots of fabricators and
-- generators (one in three), their machines queued, then up to `streets` street lots. Returns {machines, streets}.
function layout.debug_town(b, machines, streets)
  local m, st = 0, 0
  for k = 1, machines do
    local block = layout.open_role(b, k % 3 == 0 and "gen" or "fab")
    if block and block.slots then
      m = m + 1
      for _, s in ipairs(block.slots) do
        if not s.queued then
          s.queued = true
          push(b, {name = s.name, pos = s.pos, slot = s, module = block})
        end
      end
    end
  end
  for _ = 1, streets do if layout.town_grow(b) then st = st + 1 end end
  return {machines = m, streets = st}
end

-- A turret nest (two of its guns behind junk) closing the street end farthest from the hub, every NEST_EVERY lots
-- with machines: the town's guns stand where its streets run out, not round its machines.
local function town_nest(b, hub)
  if hub.count % NEST_EVERY ~= 0 then return end
  local far, fd
  for _, e in ipairs(hub.ends) do
    local d = math.abs(e.i) + math.abs(e.j)
    if (not fd or d > fd) and lot_free(b, hub, e.i, e.j) then far, fd = e, d end
  end
  if far then lay(b, hub, far, {end_nest = 1}, nil, {}) end
end

-- The lot for `role` in a town hub: at an open end, by chance after a stretch, a turn or a crossing. Nil when no end
-- can take it.
local function town_role(b, hub, role)
  for _ = 1, 3 do
    local e = town_end(b, hub)
    if not e then return nil end
    local fwd = BACK[e.back]
    local others = {}
    for _, d in ipairs({"e", "n", "s", "w"}) do if d ~= e.back and d ~= fwd then table.insert(others, d) end end
    local side = others[1 + math.floor(rng.next(b.rng) * 2)]
    if rng.next(b.rng) >= BRANCH then
      -- Its machines on a straight, a turn or a tee (each has its lots: machines at the town's bends too).
      local shapes = {{fwd}, {side}, {fwd, side}}
      local first = 1 + math.floor(rng.next(b.rng) * 3)
      for k = 0, 2 do
        local block = lay(b, hub, e, ROLE_LOTS[role], role, shapes[(first + k - 1) % 3 + 1])
        if block then town_yard(b, hub, e.i, e.j); town_nest(b, hub) return block end
      end
      return nil
    end
    local r = rng.next(b.rng)
    local outs = r < 0.35 and {fwd} or r < 0.6 and {side} or r < 0.9 and {fwd, side} or {fwd, others[1], others[2]}
    lay(b, hub, e, CONNECT_LOTS, nil, outs)
  end
  local e = town_end(b, hub)
  local block = e and lay(b, hub, e, ROLE_LOTS[role], role, {BACK[e.back]})
  if block then town_yard(b, hub, e.i, e.j); town_nest(b, hub) end
  return block
end

-- A town's first streets: from the sides of its pad (PAD_W x SIZE at the hub's corner).
local function town_pad(hub)
  local wi, hj = math.ceil(blocks.PAD_W / LOT), math.ceil(S / LOT)
  for i = 0, wi - 1 do for j = 0, hj - 1 do hub.lots[i .. ":" .. j] = {pad = true} end end
  hub.pad_box = {hub.x, hub.y, hub.x + blocks.PAD_W, hub.y + S}
  local mi, mj = math.floor(wi / 2), math.floor(hj / 2)
  hub.ends = {{i = mi - 1, j = -1, back = "s"}, {i = mi, j = hj, back = "n"}, {i = -1, j = mj, back = "e"},
    {i = wi, j = mj, back = "w"}}
end

-- A new town hub's compound: a crossing with its own generators, streets out four ways.
local function town_compound(b, hub)
  hub.ends = {{i = 0, j = 0, back = "s"}}
  local block = lay(b, hub, hub.ends[1], ROLE_LOTS.compound, "compound", {"n", "e", "w"})
  return block
end

-- Its launch pad: two lots by two beside an open end, the pad block laid in it.
local function town_launch(b, hub, open_block)
  for _ = 1, #hub.ends do
    local e = town_end(b, hub)
    if not e then return nil end
    local fwd = BACK[e.back]
    local side = (fwd == "n" or fwd == "s") and "e" or "s"
    local cells = {{e.i, e.j}, {e.i + DIRS[fwd][1], e.j + DIRS[fwd][2]}, {e.i + DIRS[side][1], e.j + DIRS[side][2]},
      {e.i + DIRS[fwd][1] + DIRS[side][1], e.j + DIRS[fwd][2] + DIRS[side][2]}}
    local ok = true
    for _, c in ipairs(cells) do if not lot_free(b, hub, c[1], c[2]) then ok = false end end
    for k, x in ipairs(hub.ends) do if x == e then table.remove(hub.ends, k) break end end
    if ok then
      local mi, mj = math.min(cells[1][1], cells[4][1]), math.min(cells[1][2], cells[4][2])
      local x0, y0 = lot_xy(hub, mi, mj)
      for _, c in ipairs(cells) do hub.lots[c[1] .. ":" .. c[2]] = {launch = true} end
      return open_block(b, hub, "launch", x0 + (2 * LOT - S) / 2, y0 + (2 * LOT - S) / 2, S, S, {})
    end
  end
end

local function open(b, hub, role, x0, y0, w, h, cells, lobed)
  clear_ground(b, x0, y0, w, h)
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
  local arch = shared.CORPS[b.corp].arch or {}
  -- Its spread clusters only: the core kept its blocks (lobed too, 23 scenarios turned: gates, power, hazards; the core
  -- is to be laid out by wave function collapse instead).
  if arch.lobed and role ~= "pad" and role ~= "picket" and hub and hub.spread then lobed = true end
  if lobed then
    block.walls = false
    block.embellished = true
    push(b, {tiles = lobe(x0, y0, w, h), floor = "pad", module = block})
    if hub and hub.walled then layout.wall_cluster(b, hub, block) end
    block.liveried = true
  elseif hub and hub.lots then
    -- A town's pad or launch pad: no road ring (its lots' streets reach it).
    block.walls = role == "pad" and block.walls
  else
    push(b, {tiles = road_ring(x0, y0, w, h), module = block})
    if role == "depot" then layout.livery(b, block) end
  end
  for _, e in ipairs(v.fixed) do
    local pos = at(e)
    if e[1] == "lp-pylon" then layout.connect(b, pos[1], pos[2], block) end
    if e[1] == "lp-launchpad" and not lobed then layout.launch_floor(b, block, pos) end
    push(b, {name = e[1], pos = pos, module = block})
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
  if layout.town(b) then hub.archetype, hub.lots, hub.ends = "town", {}, {} end
  table.insert(b.hubs, hub)
  return hub
end

-- Open a block of `role` in the newest hub, or found a new hub when it is full or boxed in.
-- Returns the block opened (a new hub's compound when one was founded), or nil.
function layout.open_role(b, role)
  local surface = game.surfaces[b.surface]
  local hub = b.hubs[#b.hubs]
  -- A settlement with no fabricator yet opens its first block by its hub whatever the doctrine's cap: sprawl's first hub
  -- is full with its pad, and its first fabricator went to a new hub 120 tiles out, beyond what its 90 parts could reach;
  -- it never made another part (Grubstake, seed 4242).
  local first = #(b.fabs or {}) == 0
  if hub.lots then
    if hub.count < TOWN_CAP or first then
      local block
      if role == "launch" then block = town_launch(b, hub, open) else block = town_role(b, hub, role) end
      if block then return block, hub end
    end
    return layout.found(b, (first or role == "launch") and role)
  end
  if hub.count < layout.DOCTRINES[b.doctrine].hub_cap or first then
    local cands = candidates(b, hub)
    for _, c in ipairs(cands) do
      local x0, y0 = hub.x + c.i * PITCH, hub.y + c.j * PITCH
      if layout.area_free(surface, x0, y0, S, S) then
        return open(b, hub, role, x0, y0, S, S, {{c.i, c.j}}), hub
      end
      hub.bad[c.k] = true
    end
  end
  -- No fabricator yet and no free cell by its hub (its own drop generators, pacifier, first outpost and cliffs took the
  -- four a street hub allows, seed 4242): its new hub goes near, not at the doctrine's reach, and opens as the block
  -- asked for (a walled compound first spent its last parts on walls: 4 left for a fabricator of 25).
  -- The launch pad too: founded as a compound, the rule asked again and founded another (eight on 12345 by minute 60,
  -- and never a pad; spread1, 2026-10-20).
  return layout.found(b, (first or role == "launch") and role)
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
function layout.found(b, near)
  -- near: the role of a block to open by the newest hub (a first fabricator's), not a compound at the doctrine's reach.
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
  if near then
    local a = 2 * math.pi * rng.next(b.rng)
    tx, ty = last.x + 2 * PITCH * math.cos(a), last.y + 2 * PITCH * math.sin(a)
  elseif far then
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
        if hub.lots then
          local block = town_compound(b, hub)
          if near and near ~= "launch" then block = town_role(b, hub, near) or block
          elseif near == "launch" then block = town_launch(b, hub, open) or block end
          return block, hub
        end
        local block = open(b, hub, near or "compound", x0, y0, S, S, {{0, 0}})
        return block, hub
      end
    end
  end
end

-- Serenity's spread (planner "spread"; the user: "organic looking bases that look menacing, like metastases on the map"):
-- a block by its newest cluster while it holds fewer than SPREAD_HUB (a depot, then compounds), else a new cluster
-- founded with a compound (its own generators: a hard point) out between the camp's edge and SPREAD_SHORT inside its
-- line, within SPREAD_ARC of the line's bearing. Returns the block, or nil when no ground is left.
local SPREAD_HUB, SPREAD_SHORT, SPREAD_ARC = 3, 30, math.rad(100)
local SPREAD_FREE = 160      -- before its line: no further out than this (unbounded, a cluster stood 50 tiles from the
                             -- player's wall, and its claim ran past every target its line had: the line never stepped)
local SPREAD_CLEAR = 60      -- from the player's buildings and rivals' claims

-- A spread cluster's wall (the user: "more varied block shapes? it's all squares everywhere ... Factorio walls can build
-- some nice looking shapes"): one wall round the cluster, not a square round each block. Its ground is the union of its
-- blocks with their roads, each block's corners cut back CLUSTER_CUT tiles: lobes where blocks join, chamfered points.
-- The wall stands on that ground's edge (8-neighbour: a diagonal joined side to side, no corner gaps); left open where
-- the road home crosses it; a gun turret every CLUSTER_TURRET_GAP tiles inside it (CLUSTER_TURRETS at most; fed, not
-- powered: lasers on every hub's wall ran demand past supply in nine scenarios).
local CLUSTER_TURRET_GAP, CLUSTER_TURRETS = 14, 8
-- `fresh`: a block opened in a hub already walled: the wall extended round it only (its lobe's edge; what stood between
-- stays as an inner wall), no new ways out (an unwalled plate by a walled core, core1).
function layout.wall_cluster(b, hub, fresh)
  if not hub or (hub.walled and not fresh) then return end
  hub.walled = true
  local surface = game.surfaces[b.surface]
  local rects = {}
  for _, k in ipairs(b.blocks) do
    if k.hub == hub.id then table.insert(rects, {k.x0 - R, k.y0 - R, k.x0 + k.w + R, k.y0 + k.h + R}) end
  end
  if #rects == 0 then return end
  local function ground(x, y)
    local cx, cy = x + 0.5, y + 0.5
    for _, r in ipairs(rects) do
      if cx > r[1] and cx < r[3] and cy > r[2] and cy < r[4]
        and math.min(cx - r[1], r[3] - cx) + math.min(cy - r[2], r[4] - cy) > CLUSTER_CUT then return true end
    end
    return false
  end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, r in ipairs(rects) do
    x0, y0, x1, y1 = math.min(x0, r[1]), math.min(y0, r[2]), math.max(x1, r[3]), math.max(y1, r[4])
  end
  local road = shared.variant(b.corp, "lp-road")
  local block = nil
  for _, k in ipairs(b.blocks) do if k.hub == hub.id then block = k break end end
  local edge, turrets = {}, {}
  for x = math.floor(x0), math.ceil(x1) do
    for y = math.floor(y0), math.ceil(y1) do
      if ground(x, y) then
        local out = {}
        for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}) do
          if not ground(x + d[1], y + d[2]) then table.insert(out, d) end
        end
        -- Extended: the old wall now inside the plate comes down (it sealed the new block off).
        if fresh and #out == 0 then
          for _, w in pairs(surface.find_entities_filtered{area = {{x + 0.1, y + 0.1}, {x + 0.9, y + 0.9}}, name = "lp-wall",
            force = b.force}) do
            storage.owner[w.unit_number] = nil
            w.destroy()
          end
          for i = #b.queue, 1, -1 do
            local q = b.queue[i]
            if q.name == "lp-wall" and math.floor(q.pos[1]) == x and math.floor(q.pos[2]) == y then table.remove(b.queue, i) end
          end
        end
        if #out > 0 then
          -- The road home: a road tile here with road beyond it is an opening.
          local open = false
          if surface.get_tile(x, y).name == road then
            for _, d in ipairs(out) do
              if surface.get_tile(x + d[1], y + d[2]).name == road then open = true end
            end
          end
          local mine = not fresh or (x >= fresh.x0 - R and x < fresh.x0 + fresh.w + R and y >= fresh.y0 - R
            and y < fresh.y0 + fresh.h + R)
          if not open and mine then
            push(b, {name = "lp-wall", pos = {x + 0.5, y + 0.5}, module = fresh or block})
            table.insert(edge, {x, y, out})
          end
        end
      end
    end
  end
  -- Its ways out: the four extremes of its edge, north, south, east, west, each left open four wide.
  for _, d in ipairs(fresh and {} or {{0, -1}, {0, 1}, {1, 0}, {-1, 0}}) do
    local bv = -math.huge
    for _, e in ipairs(edge) do bv = math.max(bv, e[1] * d[1] + e[2] * d[2]) end
    -- The middle of that flat edge (the first in scan order sat by a cut corner).
    local flat = {}
    for i, e in ipairs(edge) do if e[1] * d[1] + e[2] * d[2] == bv then table.insert(flat, i) end end
    local best = flat[math.max(1, math.ceil(#flat / 2))]
    if best then
      local e = edge[best]
      local horizontal = d[2] ~= 0
      for k = -2, 1 do
        local gx, gy = horizontal and e[1] + k or e[1], horizontal and e[2] or e[2] + k
        for i = #b.queue, 1, -1 do
          local q = b.queue[i]
          if q.name == "lp-wall" and q.module == block and math.floor(q.pos[1]) == gx and math.floor(q.pos[2]) == gy then
            table.remove(b.queue, i)
          end
        end
      end
      -- Open, two turrets inside it (gated, a raid stood behind it: a unit plans its path when ordered, and an outer
      -- gate far from it was shut then; gates).
      local ix, iy = -d[1] * 4, -d[2] * 4
      for _, side in ipairs({-4, 3}) do
        local tx, ty = horizontal and e[1] + side + 0.5 or e[1] + 0.5, horizontal and e[2] + 0.5 or e[2] + side + 0.5
        push(b, {name = "lp-gun-turret", pos = {tx + ix, ty + iy}, module = block, loose = true})
      end
    end
  end
  for _, k in ipairs(b.blocks) do if k.hub == hub.id then k.walled = true end end
  -- Turrets along it, inside, spaced (the edge tiles in scan order, kept apart).
  for _, e in ipairs(edge) do
    if #turrets >= CLUSTER_TURRETS then break end
    local far = true
    for _, t in ipairs(turrets) do if (t[1] - e[1]) ^ 2 + (t[2] - e[2]) ^ 2 < CLUSTER_TURRET_GAP ^ 2 then far = false end end
    if far then
      local ix, iy = 0, 0
      for _, d in ipairs(e[3]) do ix, iy = ix - d[1], iy - d[2] end
      local n = math.max(1, math.sqrt(ix * ix + iy * iy))
      local p = {e[1] + 0.5 + 3 * ix / n, e[2] + 0.5 + 3 * iy / n}
      table.insert(turrets, {e[1], e[2]})
      push(b, {name = "lp-gun-turret", pos = p, module = block, loose = true})
    end
  end
  b.cluster_walls = (b.cluster_walls or 0) + #edge
  return #edge
end

-- A compound laid out whole by wave function collapse (scripts/wfc.lua; the user: "Would WFC be a cool algorithm to
-- implement for Serenity?"): WFC_CELLS by WFC_CELLS cells of the tile set's size, a lobed mask (a disc and two more off
-- it), at (x0, y0) its top-left. Its floor paved, its walls, gates and buildings queued as jobs, a pylon chained to the
-- network, its rooms carved (wfc.rooms: partitions of wall, doors left open). One block record (kind "compound", WFC_WEIGHT of the cap). Nil when the ground is not free or no layout
-- passes in WFC_TRIES.
local WFC_CELLS, WFC_TRIES, WFC_WEIGHT = 11, 8, 3
local WFC_NAMES = {T = "lp-turret", G = "lp-generator", D = "lp-depot", F = "lp-fabricator", R = "lp-radar",
  P = "lp-pylon", L = "lp-lamp"}
-- Planned in one tick, laid out over the next (layout.wfc_step, once a second: the solve, then the rooms and the check,
-- each in its own tick; done at once a compound took 52 to 73 ms of one tick in game). True when planned.
function layout.wfc_plan(b, hub, x0, y0, need, lab)
  local tiles = WFC_TILES[b.corp]
  if not tiles or b.wfc_job then return false end
  local side = WFC_CELLS * tiles.size
  if not layout.area_free(game.surfaces[b.surface], x0, y0, side, side) then return false end
  b.wfc_job = {hub = hub.id, x0 = x0, y0 = y0, tries = 0, stage = "solve", need = need, lab = lab}
  return true
end

-- Districts (whole-camp WFC, the user: "Why not WFC for the whole base?"; the default since the factory found them about
-- even for the player, 2026-10-20; storage.wfc_core_off for scenarios that want blocks):
-- where its blocks would open a generator or fabricator block, a corporation with a tile set plans a compound by its
-- keep instead, at least two of what was asked in it; the nearest free ground round the lander, ring after ring, clear
-- of the player's buildings and rivals' claims. Its own wall and rooms: districts walled apart, the curtain round all.
function layout.districts(b) return not storage.wfc_core_off and WFC_TILES[b.corp] ~= nil end
-- role "lab": a research district, its lab (the kind `lab`) at its heart (its tile pinned at the middle cell).
function layout.district(b, role, lab)
  if b.wfc_job then return nil end
  local surface = game.surfaces[b.surface]
  local side = WFC_CELLS * WFC_TILES[b.corp].size
  local ox, oy = b.origin.x, b.origin.y
  for r = side / 2 + 30, side / 2 + 230, 20 do
    local steps = math.max(6, math.floor(2 * math.pi * r / 40))
    local a0 = 2 * math.pi * rng.next(b.rng)
    for k = 0, steps - 1 do
      local a = a0 + 2 * math.pi * k / steps
      local cx, cy = ox + r * math.cos(a), oy + r * math.sin(a)
      local clear = true
      for _, f in ipairs(shared.player_forces()) do
        if surface.count_entities_filtered{position = {cx, cy}, radius = side / 2 + 30, force = f, limit = 1} > 0 then clear = false end
      end
      for _, o in pairs(storage.bases) do
        if o ~= b and not o.fallen and o.surface == b.surface and o.claim_radius
          and (o.origin.x - cx) ^ 2 + (o.origin.y - cy) ^ 2 < (o.claim_radius + side / 2) ^ 2 then clear = false end
      end
      if clear then
        local h = new_hub(b, math.floor(cx), math.floor(cy))
        h.district, h.walled = true, true
        local need = role == "lab" and {B = 1} or role == "depot" and {D = 1} or {[role == "gen" and "G" or "F"] = 2}
        if layout.wfc_plan(b, h, math.floor(cx - side / 2), math.floor(cy - side / 2), need, lab) then
          return {kind = "district (planned)", center = {cx, cy}, wfc = true}
        end
        table.remove(b.hubs)
      end
    end
  end
end

local lay_out
local function base_trace(b, s) if layout.trace then layout.trace(b, s) end end

-- One stage of a planned compound: "solve" (a lobed mask, the collapse) or "rooms" (rooms carved, the ground checked;
-- laid out when it passes, solved again when not, given up after WFC_TRIES).
function layout.wfc_step(b)
  local job = b.wfc_job
  if not job then return end
  local tiles = WFC_TILES[b.corp]
  local n = WFC_CELLS
  local side = n * tiles.size
  local rand = function() return rng.next(b.rng) end
  if job.stage == "solve" then
    job.tries = job.tries + 1
    local c = (n - 1) / 2
    local discs = {{c + 0.5, c + 0.5, n / 3}}
    for _ = 1, 2 do
      local a = 2 * math.pi * rand()
      table.insert(discs, {c + 0.5 + n / 3.5 * math.cos(a), c + 0.5 + n / 3.5 * math.sin(a), n / 4.2})
    end
    local function mask(x, y)
      if x <= 0 or y <= 0 or x >= n - 1 or y >= n - 1 then return false end
      for _, d in ipairs(discs) do if (x + 0.5 - d[1]) ^ 2 + (y + 0.5 - d[2]) ^ 2 <= d[3] ^ 2 then return true end end
      return false
    end
    local fixed
    if job.lab then
      for i, v in ipairs(tiles.variants) do
        if v.name == "lab" then fixed = {[math.floor(c) .. "," .. math.floor(c)] = i}; break end
      end
    end
    local sol = wfc.solve(tiles, n, n, mask, rand, fixed, 3000)
    if sol then job.g, job.stage = wfc.render(tiles, sol, n, n), "rooms"
    elseif job.tries >= WFC_TRIES then b.wfc_job = nil end
    return
  end
  wfc.rooms(job.g, side, side, rand)
  -- What it was planned for (a district: generators, fabricators): enough of it, or solved again.
  local short = false
  for letter, n in pairs(job.need or {}) do
    local have = 0
    for _, bd in ipairs(wfc.buildings(job.g, side, side)) do if bd[1] == letter then have = have + 1 end end
    if have < n then short = true end
  end
  if not short and not wfc.check(job.g, side, side) then
    b.wfc_job = nil
    lay_out(b, b.hubs[job.hub], job.x0, job.y0, job.g, side, job.lab)
    if base_trace then base_trace(b, string.format("compound laid out at %.0f,%.0f (%d tries)%s", job.x0 + side / 2,
      job.y0 + side / 2, job.tries, job.lab and (", " .. job.lab) or "")) end
  elseif job.tries >= WFC_TRIES then
    b.wfc_job = nil
  else
    job.g, job.stage = nil, "solve"
  end
end

local APRON = {F = {3, 3}, R = {3, 3}, G = {2, 2}, D = {4, 4}, B = {4, 4}}
local HAZARD_RING = {D = true, B = true}
local WALLISH = {["#"] = true, w = true, g = true, ["="] = true}
lay_out = function(b, hub, x0, y0, g, side, lab)
  clear_ground(b, x0, y0, side, side)
  local block = {kind = "compound", lab = lab, hub = hub and hub.id, x0 = x0, y0 = y0, w = side, h = side,
    center = {x0 + side / 2, y0 + side / 2}, entities = {}, slots = {}, opened = game.tick, walls = false, walled = true,
    embellished = true, liveried = true, wfc = true, weight = WFC_WEIGHT}
  table.insert(b.blocks, block)
  table.insert(b.modules, block)
  if hub then hub.count = hub.count + 1 end
  -- Its floor varied (the user, 2026-10-21: "areas with hazard/refined concrete mixed in, without showing the sand"): the
  -- apron under each machine and a tile round it, a ring of hazard stripes round a lab or a depot, the deck elsewhere.
  local mark = {}
  for y = 0, side - 1 do
    for x = 0, side - 1 do
      local sz = APRON[g[y][x]]
      if sz then
        local ring = HAZARD_RING[g[y][x]]
        for dy = -1, sz[2] do
          for dx = -1, sz[1] do
            local edge = dx == -1 or dy == -1 or dx == sz[1] or dy == sz[2]
            local k = (x + dx) .. ":" .. (y + dy)
            if not (mark[k] == "hazard" and not edge) then mark[k] = (ring and edge) and "hazard" or "apron" end
          end
        end
      end
    end
  end
  local floor, lanes, apron, hazard = {}, {}, {}, {}
  for y = 0, side - 1 do
    for x = 0, side - 1 do
      local ch = g[y][x]
      -- Walls on the plate too (left bare, sand showed under every wall and partition: the user, in game).
      if ch ~= " " then
        local m = not WALLISH[ch] and mark[x .. ":" .. y]
        table.insert(ch == "=" and lanes or m == "hazard" and hazard or m == "apron" and apron or floor, {x0 + x, y0 + y})
      end
    end
  end
  push(b, {tiles = floor, floor = "pad", module = block})
  push(b, {tiles = lanes, floor = "road", module = block})
  push(b, {tiles = apron, floor = "apron", module = block})
  push(b, {tiles = hazard, floor = "hazard", module = block})
  local pylon
  for y = 0, side - 1 do
    for x = 0, side - 1 do
      local ch = g[y][x]
      -- Its gates left open (gated, a raid stood behind far gates: a unit plans its path when ordered, gates shut).
      if ch == "#" or ch == "w" then push(b, {name = "lp-wall", pos = {x0 + x + 0.5, y0 + y + 0.5}, module = block}) end
    end
  end
  -- What makes parts and power first (a district's crews build in batches: its walls first left it producing nothing).
  local ORDER = {P = 1, F = 2, G = 3, D = 4, B = 5, R = 6, T = 7, L = 8}
  local bds = wfc.buildings(g, side, side)
  table.sort(bds, function(p, q) return ORDER[p[1]] < ORDER[q[1]] end)
  local econ = {}
  for _, bd in ipairs(bds) do
    local name = bd[1] == "B" and lab or WFC_NAMES[bd[1]]
    local pos = {x0 + bd[2] + bd[4] / 2, y0 + bd[3] + bd[5] / 2}
    if name then table.insert(econ, {name = name, pos = pos, module = block}) end
    if bd[1] == "P" and not pylon then pylon = pos end
  end
  -- Ahead of its walls in the queue.
  local first = #b.queue + 1
  for i = #b.queue, 1, -1 do if b.queue[i].module == block and b.queue[i].name == "lp-wall" then first = i end end
  for k, j in ipairs(econ) do table.insert(b.queue, first + k - 1, j) end
  if pylon then layout.connect(b, pylon[1], pylon[2], block) end
  layout.belts(b, block, g, side, x0, y0)
  return block
end

-- Its belts (the user, 2026-10-21: "we did not incorporate any belts or logistics of any kind inside the clusters"): each
-- run of "c" (tiles run straight or turn, never branch) traced end to end and given its direction, toward the end beside
-- a depot when one is, from the end beside a fabricator; a loop runs round. Queued after the rest; block.belts keeps each
-- run's first and last tile for belts.lua, which puts parts on at the first and takes them off at the last.
local DIRS = {[0] = {[-1] = defines.direction.north, [1] = defines.direction.south},
  [1] = {[0] = defines.direction.east}, [-1] = {[0] = defines.direction.west}}
local N4 = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
function layout.belts(b, block, g, side, x0, y0)
  local function at(x, y) return g[y] and g[y][x] or " " end
  local foot = {}
  for _, bd in ipairs(wfc.buildings(g, side, side)) do
    for dx = 0, bd[4] - 1 do for dy = 0, bd[5] - 1 do foot[(bd[2] + dx) .. ":" .. (bd[3] + dy)] = bd[1] end end
  end
  local function beside(x, y, letter)
    for _, d in ipairs(N4) do if foot[(x + d[1]) .. ":" .. (y + d[2])] == letter then return d end end
  end
  local seen, runs = {}, {}
  for y = 0, side - 1 do
    for x = 0, side - 1 do
      if at(x, y) == "c" and not seen[x .. ":" .. y] then
        -- The run: its cells, and its ends (a cell with one belt neighbour).
        local cells, ends, stack = {}, {}, {{x, y}}
        seen[x .. ":" .. y] = true
        while #stack > 0 do
          local p = table.remove(stack)
          table.insert(cells, p)
          local n = 0
          for _, d in ipairs(N4) do
            local q = {p[1] + d[1], p[2] + d[2]}
            if at(q[1], q[2]) == "c" then
              n = n + 1
              if not seen[q[1] .. ":" .. q[2]] then seen[q[1] .. ":" .. q[2]] = true; table.insert(stack, q) end
            end
          end
          if n <= 1 then table.insert(ends, p) end
        end
        local start = ends[1] or cells[1]
        for _, e in ipairs(ends) do
          if beside(e[1], e[2], "D") then
            -- The other end starts it.
            for _, o in ipairs(ends) do if o ~= e then start = o end end
          end
        end
        -- Walked from its start, each tile pointing at the next; the last at the building beside it, else straight on.
        local order, done, p = {}, {}, start
        while p do
          table.insert(order, p)
          done[p[1] .. ":" .. p[2]] = true
          local nxt
          for _, d in ipairs(N4) do
            local q = {p[1] + d[1], p[2] + d[2]}
            if at(q[1], q[2]) == "c" and not done[q[1] .. ":" .. q[2]] then nxt = q break end
          end
          p = nxt
        end
        local last_d
        for i, c in ipairs(order) do
          local q = order[i + 1]
          local d
          if q then d = {q[1] - c[1], q[2] - c[2]}
          else
            -- A loop's last tile points at its first; an open run's at the depot or fabricator beside it, or on.
            local f = order[1]
            if #ends == 0 and math.abs(f[1] - c[1]) + math.abs(f[2] - c[2]) == 1 then d = {f[1] - c[1], f[2] - c[2]}
            else d = beside(c[1], c[2], "D") or beside(c[1], c[2], "F") or last_d or {0, 1} end
          end
          last_d = d
          table.insert(b.queue, {name = "lp-belt", pos = {x0 + c[1] + 0.5, y0 + c[2] + 0.5}, dir = DIRS[d[1]][d[2]],
            module = block})
        end
        table.insert(runs, {first = {x0 + order[1][1] + 0.5, y0 + order[1][2] + 0.5},
          last = {x0 + order[#order][1] + 0.5, y0 + order[#order][2] + 0.5}, loop = #ends == 0, n = #order})
      end
    end
  end
  if #runs > 0 then block.belts = runs end
end

-- The curtain (the user: "we need layers of walls too, closed clusters within the base etc. A huge blob with just an
-- outside wall is boring"): grown out (its spread done), one wall round the whole camp, a killing ground before its
-- compounds' own walls. Its ground: star-shaped round the lander (below), marked once, the edge traced over what is
-- marked (testing every tile against every block, as a cluster's wall does, was too slow at this size). The wall on its
-- edge (8-neighbour, joined side to side); open where a road leaves and at its
-- four extremes (two gun turrets inside each); a gun turret every CURTAIN_GAP tiles inside it. Built in CURTAIN_SECTORS
-- segments by bearing from the camp, each its own site for the drones. Once; a camp that grows after extends it.
local CURTAIN_KILL, CURTAIN_GAP, CURTAIN_SECTORS, CURTAIN_BINS = 14, 18, 16, 72
local N8 = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
function layout.curtain(b)
  if b.curtain or not b.origin or #b.blocks == 0 then return end
  local surface = game.surfaces[b.surface]
  local paint = {}
  local function mark(x, y) local r = paint[y] if not r then r = {} paint[y] = r end r[x] = true end
  local function on(x, y) local r = paint[y] return r and r[x] or false end
  -- One enclosure, star-shaped round the lander: in each of CURTAIN_BINS bearings, out to its furthest block corner and
  -- the killing ground; each bearing raised to most of its neighbours' (no deep spike between two compounds). Blocks
  -- grown and joined only where they touched gave a ring round each compound, not one round the camp (curtain1).
  local ox0, oy0 = b.origin.x, b.origin.y
  local NB = CURTAIN_BINS
  local rad = {}
  for i = 1, NB do rad[i] = 0 end
  local function bin(x, y) return math.floor(((math.atan2(y - oy0, x - ox0) + 2 * math.pi) % (2 * math.pi)) / (2 * math.pi) * NB) + 1 end
  for _, k in ipairs(b.blocks) do
    for _, c in ipairs({{k.x0, k.y0}, {k.x0 + k.w, k.y0}, {k.x0, k.y0 + k.h}, {k.x0 + k.w, k.y0 + k.h},
      {k.x0 + k.w / 2, k.y0}, {k.x0 + k.w / 2, k.y0 + k.h}, {k.x0, k.y0 + k.h / 2}, {k.x0 + k.w, k.y0 + k.h / 2}}) do
      local i = bin(c[1], c[2])
      rad[i] = math.max(rad[i], math.sqrt((c[1] - ox0) ^ 2 + (c[2] - oy0) ^ 2) + CURTAIN_KILL)
    end
  end
  for _ = 1, 3 do
    local nr = {}
    for i = 1, NB do
      local a, c = rad[(i - 2) % NB + 1], rad[i % NB + 1]
      nr[i] = math.max(rad[i], 0.8 * math.max(a, c), 0.5 * (a + c))
    end
    rad = nr
  end
  local rmax = 0
  for i = 1, NB do rmax = math.max(rmax, rad[i]) end
  for x = math.floor(ox0 - rmax) - 1, math.ceil(ox0 + rmax) + 1 do
    for y = math.floor(oy0 - rmax) - 1, math.ceil(oy0 + rmax) + 1 do
      local cx, cy = x + 0.5, y + 0.5
      local a = ((math.atan2(cy - oy0, cx - ox0) + 2 * math.pi) % (2 * math.pi)) / (2 * math.pi) * NB
      local i = math.floor(a) + 1
      local f = a - math.floor(a)
      local r = rad[i] * (1 - f) + rad[i % NB + 1] * f
      if (cx - ox0) ^ 2 + (cy - oy0) ^ 2 <= r * r then mark(x, y) end
    end
  end
  local ox, oy = b.origin.x, b.origin.y
  local road = shared.variant(b.corp, "lp-road")
  local segs = {}
  local function seg_of(x, y)
    local a = (math.atan2(y - oy, x - ox) + 2 * math.pi) % (2 * math.pi)
    local i = math.floor(a / (2 * math.pi) * CURTAIN_SECTORS) + 1
    if not segs[i] then segs[i] = {kind = "curtain", center = {0, 0}, entities = {}, n = 0, sx = 0, sy = 0} end
    return segs[i]
  end
  local edge = {}
  for y, row in pairs(paint) do
    for x in pairs(row) do
      local out = {}
      for _, d in ipairs(N8) do if not on(x + d[1], y + d[2]) then table.insert(out, d) end end
      if #out > 0 then
        local open = false
        if surface.get_tile(x, y).name == road then
          for _, d in ipairs(out) do if surface.get_tile(x + d[1], y + d[2]).name == road then open = true end end
        end
        if not open then table.insert(edge, {x, y, out}) end
      end
    end
  end
  table.sort(edge, function(p, q) if p[2] ~= q[2] then return p[2] < q[2] end return p[1] < q[1] end)
  -- Its ways out: the middle of its flattest edge at each extreme, four wide.
  local gaps = {}
  for _, d in ipairs({{0, -1}, {0, 1}, {1, 0}, {-1, 0}}) do
    local bv = -math.huge
    for _, e in ipairs(edge) do bv = math.max(bv, e[1] * d[1] + e[2] * d[2]) end
    local flat = {}
    for _, e in ipairs(edge) do if e[1] * d[1] + e[2] * d[2] == bv then table.insert(flat, e) end end
    local e = flat[math.max(1, math.ceil(#flat / 2))]
    if e then
      local horizontal = d[2] ~= 0
      for k = -2, 1 do gaps[(horizontal and (e[1] + k) or e[1]) .. "," .. (horizontal and e[2] or (e[2] + k))] = true end
      for _, side in ipairs({-4, 3}) do
        local tx, ty = horizontal and e[1] + side + 0.5 or e[1] + 0.5, horizontal and e[2] + 0.5 or e[2] + side + 0.5
        push(b, {name = "lp-gun-turret", pos = {tx - d[1] * 4, ty - d[2] * 4}, module = seg_of(e[1], e[2]), loose = true})
      end
    end
  end
  local turrets, walls = {}, 0
  for _, e in ipairs(edge) do
    local x, y = e[1], e[2]
    if not gaps[x .. "," .. y] then
      local m = seg_of(x, y)
      push(b, {name = "lp-wall", pos = {x + 0.5, y + 0.5}, module = m})
      m.n, m.sx, m.sy = m.n + 1, m.sx + x, m.sy + y
      walls = walls + 1
      local far = true
      for _, t in ipairs(turrets) do if (t[1] - x) ^ 2 + (t[2] - y) ^ 2 < CURTAIN_GAP ^ 2 then far = false break end end
      if far then
        local ix, iy = 0, 0
        for _, d in ipairs(e[3]) do ix, iy = ix - d[1], iy - d[2] end
        local n = math.max(1, math.sqrt(ix * ix + iy * iy))
        table.insert(turrets, {x, y})
        push(b, {name = "lp-gun-turret", pos = {x + 0.5 + 3 * ix / n, y + 0.5 + 3 * iy / n}, module = m, loose = true})
      end
    end
  end
  b.curtain = {segments = {}, walls = walls, turrets = #turrets}
  for _, m in pairs(segs) do
    m.center = m.n > 0 and {m.sx / m.n, m.sy / m.n} or {ox, oy}
    table.insert(b.curtain.segments, m)
    table.insert(b.modules, m)
  end
  base_trace(b, string.format("curtain: %d walls, %d turrets round the camp, %d segments", walls, #turrets,
    #b.curtain.segments))
end

function layout.spread(b)
  local surface = game.surfaces[b.surface]
  local ox, oy = b.origin.x, b.origin.y
  -- Short of its line; before it has one, a cluster's step beyond its furthest block.
  local rmax = b.perimeter and (b.perimeter - SPREAD_SHORT) or nil
  local function inside(x0, y0)
    return not b.perimeter or math.sqrt((x0 + S / 2 - ox) ^ 2 + (y0 + S / 2 - oy) ^ 2) <= b.perimeter - SPREAD_SHORT
  end
  local hub = b.spread_hub and b.hubs[b.spread_hub]
  if hub and hub.count < SPREAD_HUB then
    local role = hub.count == 1 and "depot" or "compound"
    for _, c in ipairs(candidates(b, hub)) do
      local x0, y0 = hub.x + c.i * PITCH, hub.y + c.j * PITCH
      if inside(x0, y0) and layout.area_free(surface, x0, y0, S, S) then
        local k = open(b, hub, role, x0, y0, S, S, {{c.i, c.j}}, true)
        k.walls = false
        return k
      end
      hub.bad[c.k] = true
    end
  end
  -- A new cluster: beyond its furthest block, short of its line.
  local rmin = 0
  for _, k in ipairs(b.blocks) do
    rmin = math.max(rmin, math.sqrt((k.center[1] - ox) ^ 2 + (k.center[2] - oy) ^ 2))
  end
  rmin = math.max(60, rmin - PITCH)
  rmax = rmax or math.min(SPREAD_FREE, rmin + 3 * PITCH)
  if rmax < rmin + PITCH then return nil end
  local bs = b.cordon_bearings
  local bearing = bs and #bs > 0 and math.rad(bs[#bs]) or nil
  for _ = 1, 24 do
    local a = bearing and (bearing + (rng.next(b.rng) - 0.5) * 2 * SPREAD_ARC) or 2 * math.pi * rng.next(b.rng)
    local r = rmin + rng.next(b.rng) * (rmax - rmin)
    local x0, y0 = math.floor(ox + r * math.cos(a) - S / 2), math.floor(oy + r * math.sin(a) - S / 2)
    local cx, cy = x0 + S / 2, y0 + S / 2
    local clear = true
    for _, f in ipairs(shared.player_forces()) do
      if surface.count_entities_filtered{position = {cx, cy}, radius = SPREAD_CLEAR, force = f, limit = 1} > 0 then clear = false end
    end
    for _, o in pairs(storage.bases) do
      if o ~= b and not o.fallen and o.surface == b.surface and o.claim_radius
        and (o.origin.x - cx) ^ 2 + (o.origin.y - cy) ^ 2 < (o.claim_radius + SPREAD_CLEAR / 2) ^ 2 then clear = false end
    end
    -- A tile set: the cluster is one compound laid out whole (layout.wfc_compound), centred where the block would be.
    if clear and WFC_TILES[b.corp] and not storage.wfc_off then
      local side = WFC_CELLS * WFC_TILES[b.corp].size
      local h = new_hub(b, x0, y0)
      h.spread, h.walled = true, true
      if layout.wfc_plan(b, h, math.floor(cx - side / 2), math.floor(cy - side / 2)) then
        b.spread_hub = nil
        -- Planned: its block comes once laid out (layout.wfc_step); for the planner's trace and pacing, a stand-in.
        return {kind = "compound (planned)", center = {cx, cy}, wfc = true}
      end
      table.remove(b.hubs)
    elseif clear and layout.area_free(surface, x0, y0, S, S) then
      -- The cluster before it is done: its wall goes up.
      layout.wall_cluster(b, hub)
      local h = new_hub(b, x0, y0)
      h.spread = true
      b.spread_hub = h.id
      local k = open(b, h, "compound", x0, y0, S, S, {{0, 0}}, true)
      k.walls = false
      return k
    end
  end
end

-- The landing pad: the first hub's two cells (0,0) and (1,0) as one walled area, the lander at its centre.
-- Returns the lander's position and the pad, or nil when nothing fits near pos.
-- Where a landing at pos would set its lander (layout.land's search, nothing placed): a cargo pod is sent there first.
-- pods: spots where cargo pods will stand (optional): ground whose ring holds one counts as taken, as it will be once
-- they are down (a pod's container is no clearable thing). landfx.lua asks it so, to draw the hull's fall onto the pad
-- the landing will take: its pod and escorts push it off their own pad (15 tiles on seed 12345).
local POD_BOX = {-0.5, 0, 0.5, 1.3}   -- the base game's cargo-pod-container collision box
local function holds_pod(pods, x0, y0)
  for _, p in ipairs(pods or {}) do
    if p[1] + POD_BOX[3] > x0 - R + 0.1 and p[1] + POD_BOX[1] < x0 + blocks.PAD_W + R - 0.1
      and p[2] + POD_BOX[4] > y0 - R + 0.1 and p[2] + POD_BOX[2] < y0 + S + R - 0.1 then
      return true
    end
  end
end
function layout.find_pad(surface, pos, pods)
  for r = 0, 80, 3 do
    local steps = math.max(1, math.floor(2 * math.pi * r / 6))
    for k = 0, steps - 1 do
      local a = 2 * math.pi * k / steps
      local x0, y0 = math.floor(pos[1] + r * math.cos(a)) - 20, math.floor(pos[2] + r * math.sin(a)) - 9
      if not holds_pod(pods, x0, y0) and layout.area_free(surface, x0, y0, blocks.PAD_W, S, 12) then
        return {x0 + blocks.PAD_W / 2 + 0.9, y0 + S / 2 - 0.6}
      end
    end
  end
end

function layout.land(b, surface, pos)
  for r = 0, 80, 3 do
    local steps = math.max(1, math.floor(2 * math.pi * r / 6))
    for k = 0, steps - 1 do
      local a = 2 * math.pi * k / steps
      local x0, y0 = math.floor(pos[1] + r * math.cos(a)) - 20, math.floor(pos[2] + r * math.sin(a)) - 9
      if layout.area_free(surface, x0, y0, blocks.PAD_W, S, 12) then
        local hub = new_hub(b, x0, y0)
        local pad = open(b, hub, "pad", x0, y0, blocks.PAD_W, S, {{0, 0}, {1, 0}})
        if (shared.CORPS[b.corp].arch or {}).pad then layout.pad_shape(b, pad) end
        if hub.lots then town_pad(hub) end
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

-- Off the ore: of the first FORT_CANDIDATES free squares nearest its landing point, the one with the least ore under it
-- (nearest first among equals). Its landing is chosen by ore, and the first free square stood on it: on nwa its fortress
-- and walls covered 9 of the 24 mining cells round it, and the camp matured at two blocks six minutes in (0.2.149).
local FORT_CANDIDATES = 12
-- (Armed landings alone, off_ore: the headquarters' fortress keeps the first free square, which its scenarios' forts
-- are laid out against.)
function layout.land_fortress(b, surface, pos, off_ore)
  local best, best_ore, found = nil, nil, 0
  for r = 0, 100, 4 do
    local steps = math.max(1, math.floor(2 * math.pi * r / 8))
    for k = 0, steps - 1 do
      local a = 2 * math.pi * k / steps
      local x0, y0 = math.floor(pos[1] + r * math.cos(a)) - FORT / 2, math.floor(pos[2] + r * math.sin(a)) - FORT / 2
      if layout.area_free(surface, x0, y0, FORT, FORT, 40) then
        local ore = off_ore and surface.count_entities_filtered{area = {{x0 - 4, y0 - 4}, {x0 + FORT + 4, y0 + FORT + 4}},
          type = "resource"} or 0
        if not best_ore or ore < best_ore then best, best_ore = {x0, y0}, ore end
        found = found + 1
        if not off_ore or ore == 0 or found >= FORT_CANDIDATES then goto chosen end
      end
    end
  end
  ::chosen::
  if best then
    local x0, y0 = best[1], best[2]
    do
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

-- Walls (and corner turrets) for the first block that should have them and has stood a while.
function layout.fortify(b)
  for _, block in ipairs(b.blocks) do
    if block.walls and not block.walled and game.tick - block.opened > 600 then
      block.walled = true
      for _, w in ipairs(wall_ring(block.x0, block.y0, block.w, block.h)) do
        push(b, {name = w[1], pos = {w[2], w[3]}, module = block})
      end
      local arch = shared.CORPS[b.corp].arch or {}
      local x0, y0, w, h = block.x0, block.y0, block.w, block.h
      local ox, oy = math.floor(w / 2) - blocks.OPENING / 2, math.floor(h / 2) - blocks.OPENING / 2
      if arch.gates then
        -- Gates in every opening: horizontal in the top and bottom walls, vertical in the sides.
        for k = 0, blocks.OPENING - 1 do
          for _, y in ipairs({0, h - 1}) do
            push(b, {name = "lp-gate", pos = {x0 + ox + k + 0.5, y0 + y + 0.5}, dir = defines.direction.east, module = block})
          end
          for _, x in ipairs({0, w - 1}) do
            push(b, {name = "lp-gate", pos = {x0 + x + 0.5, y0 + oy + k + 0.5}, dir = defines.direction.north, module = block})
          end
        end
      end
      if arch.flamers and arch.gates and (block.kind == "compound" or block.kind == "pad") then
        -- A flamethrower outside each gated opening of a hard point, beside it on the road (inside, every tile is
        -- taken). Hard points only: four on every walled block starved a bastion of parts (occupy, defend).
        push(b, {name = "lp-flamer", pos = {x0 + ox - 1, y0 - 2.5}, dir = defines.direction.north, module = block})
        push(b, {name = "lp-flamer", pos = {x0 + ox + blocks.OPENING + 1, y0 + h + 1.5}, dir = defines.direction.south, module = block})
        push(b, {name = "lp-flamer", pos = {x0 - 2.5, y0 + oy + blocks.OPENING + 1}, dir = defines.direction.west, module = block})
        push(b, {name = "lp-flamer", pos = {x0 + w + 1.5, y0 + oy - 1}, dir = defines.direction.east, module = block})
      end
      -- (No baffle walls inside the openings since 2026-10-24: the lane they left stopped its tanks, scenario blockexit.)
      if block.kind ~= "picket" and block.kind ~= "depot" then
        local corners = {{2, 2}, {w - 2, 2}, {2, h - 2}, {w - 2, h - 2}}
        for _, c in ipairs(corners) do
          push(b, {name = "lp-turret", pos = {x0 + c[1], y0 + c[2]}, module = block})
          if arch.pillboxes then
            -- The corner pocket walled off from the yard: the turret in a pillbox, reachable over the wall only.
            local sx = c[1] < w / 2 and 1 or -1
            local sy = c[2] < h / 2 and 1 or -1
            local cx, cy = x0 + c[1], y0 + c[2]
            for _, p in ipairs({{sx * 1.5, -sy * 0.5}, {sx * 1.5, sy * 0.5}, {-sx * 0.5, sy * 1.5}, {sx * 0.5, sy * 1.5}}) do
              push(b, {name = "lp-wall", pos = {cx + p[1], cy + p[2]}, module = block})
            end
          end
        end
      end
      return block
    end
  end
end

-- A block's floor livery: its yard paved in the corporation's pad floor, inside a one-tile border of its trim
-- (Serenity black concrete, Grubstake hazard stripes): large plain areas and straight edges, which tiles draw
-- well.
-- The landing pad in each corporation's own shape (the user: "the landing sites could perhaps vary a little more
-- between factions. Right now it's rectangles for everyone"), laid at landing, not at maturity: Serenity's landing
-- ring (an octagon of its floor inside a ring of its trim, the rectangle's corners bare ground), Grubstake's drop
-- site (rough patches of its floor round the lander, ragged at the edge, scraps of hazard stripe in it). The block
-- stays a rectangle for the planner.
local function pad_shape(b, block)
  local x0, y0, w, h = block.x0, block.y0, block.w, block.h
  local cx, cy = x0 + w / 2, y0 + h / 2
  local shape = (shared.CORPS[b.corp].arch or {}).pad
  local pad, trim = {}, {}
  for x = x0, x0 + w - 1 do
    for y = y0, y0 + h - 1 do
      local dx, dy = math.abs(x + 0.5 - cx) / (w / 2), math.abs(y + 0.5 - cy) / (h / 2)
      if shape == "ring" then
        -- An octagon: inside |dx| <= 1, |dy| <= 1 and |dx| + |dy| <= 1.45; a one-tile trim along its edge.
        local d = math.max(dx, dy, (dx + dy) / 1.45)
        local edge = 1 - 1.5 / math.min(w / 2, h / 2)
        if d <= 1 then table.insert(d > edge and trim or pad, {x, y}) end
      else
        -- Rough ground: an ellipse broken at the edge by a tile hash, hazard scraps inside.
        local n = ((x * 73 + y * 151 + (x * y) % 29 + b.id * 17) % 100) / 100
        local d = math.sqrt(dx * dx + dy * dy)
        if d + 0.35 * n < 1.05 then
          table.insert(((x * 31 + y * 57) % 23 == 0) and trim or pad, {x, y})
        end
      end
    end
  end
  push(b, {tiles = pad, floor = "pad", module = block})
  push(b, {tiles = trim, floor = "trim", module = block})
  block.liveried = true
end
layout.pad_shape = pad_shape

-- The launch pad's ground (the user, 2026-10-21: "looks a little unceremonious": a silo on sand among trees): cleared,
-- paved whole, the silo standing in a ring of hazard stripes (its apron where it has them), a cold lamp at each corner
-- of the ring.
function layout.launch_floor(b, block, silo)
  local x0, y0, w, h = block.x0, block.y0, block.w, block.h
  -- Its ground was cleared when the block was opened. The silo, 9 tiles across: the tiles within 4 of its centre tile
  -- under it, the ring 5 and 6 out.
  local cx, cy = math.floor(silo[1]), math.floor(silo[2])
  local hazard = shared.CORPS[b.corp].hazard and "hazard" or "trim"
  local pad, ring = {}, {}
  -- The whole block, out to its road (a band of sand had stood between the two: 12-launch-pad).
  for x = x0, x0 + w - 1 do
    for y = y0, y0 + h - 1 do
      local d = math.max(math.abs(x - cx), math.abs(y - cy))
      table.insert((d == 5 or d == 6) and ring or pad, {x, y})
    end
  end
  push(b, {tiles = pad, floor = "pad", module = block})
  push(b, {tiles = ring, floor = hazard, module = block})
  for _, c in ipairs({{-6, -6}, {6, -6}, {-6, 6}, {6, 6}}) do
    push(b, {name = "lp-post-lamp", pos = {cx + c[1] + 0.5, cy + c[2] + 0.5}, module = block})
  end
  block.liveried = true
end

function layout.livery(b, block)
  -- A pad with its corporation's own shape keeps it (laid at landing).
  if block.kind == "pad" and (shared.CORPS[b.corp].arch or {}).pad then
    if not block.liveried then pad_shape(b, block) end
    return
  end
  local x0, y0, w, h = block.x0, block.y0, block.w, block.h
  -- The whole block, the walls' own row included (left bare, it showed as a line of sand between the road and
  -- the trim, user 2026-10-13); the trim one tile inside.
  local pad, trim = {}, {}
  for x = x0, x0 + w - 1 do
    for y = y0, y0 + h - 1 do
      local ring = (x == x0 + 1 or x == x0 + w - 2) and y >= y0 + 1 and y <= y0 + h - 2
        or (y == y0 + 1 or y == y0 + h - 2) and x >= x0 + 1 and x <= x0 + w - 2
      table.insert(ring and trim or pad, {x, y})
    end
  end
  push(b, {tiles = pad, floor = "pad", module = block})
  push(b, {tiles = trim, floor = "trim", module = block})
end

-- Maturity on a hard point (pad, compound): lamps inside the walls, the yard paved, mines on the road
-- outside each opening. Once per block, after its walls.
function layout.embellish(b)
  for _, block in ipairs(b.blocks) do
    if (block.kind == "pad" or block.kind == "compound") and block.walled and not block.embellished then
      block.embellished = true
      local x0, y0, w, h = block.x0, block.y0, block.w, block.h
      layout.livery(b, block)
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
function layout.init(b, seed, doctrine, weights)
  b.rng = rng.new(seed)
  b.doctrine = doctrine or rng.weighted(b.rng, weights or {bastion = 1, sprawl = 1, picket = 1})
  b.hubs, b.blocks = {}, {}
end

return layout
