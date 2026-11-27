-- Hulls kept apart (the user, 2026-11-09: "having 2 columns of huge tanks just standing on each other looks terrible";
-- then, offered colliding or kept apart: "Soft separation"). A unit's mask lets it through other units, and tanks in a
-- column stood on each other. Colliding outright they wedged in crowds, a unit planning no way round another (0.2.258:
-- blockexit, four of five tanks in one block). So hulls pass through each other as before, and every HULL.EVERY ticks
-- any two closer than HULL.GAP times their half widths summed are nudged apart, each at most HULL.STEP, onto ground
-- where it could stand (can_place_entity: never into a wall, a building or water). Infantry and fliers are left alone, and
-- so is a hull on the move (STILL: moved less than that since the last look; the user's tanks were standing on each
-- other): nudged on its way, a unit lost its path, and the dozers' buggies, crowded at their breach, never got in (dev).
-- The dozers and their escort, steered by ram.lua, too. But two hulls on the move nearly on one point (closer than
-- DEEP) are pulled apart all the same: units set down where another stands (find_non_colliding_position takes no
-- account of units) march off on one path and stay stacked, the arena's columns and a camp's spawns alike.
-- The hulls found by name every SCAN ticks (find_entities_filtered over the map's generated chunks only), kept in
-- storage.sep.list between. (Not find_units over a box a million tiles either side: it walked that box, every look,
-- and its memory grew until macOS killed the game, the batch that ran it taking the user's Mac down, 2026-11-09.)
local shared = require("__landing-party__.shared")
local rng = require("__landing-party__.scripts.rng")

local separate = {}
local H = shared.HULL
local SCAN = 600
local SEP_SLICE = 24   -- hulls looked round a look (separate.tick)
local STILL = 0.1
local DEEP = 0.6

local half = {}
-- A unit's half width if it is a hull, else false.
local function hull(name)
  local h = half[name]
  if h == nil then
    h = false
    local p = prototypes.entity[name]
    if p and p.type == "unit" and name:sub(1, 3) == "lp-" then
      local m = p.collision_mask
      local flier = m and m.layers and m.layers["lp-air"]
      local cb = p.collision_box
      local lt, rb = cb.left_top or cb[1], cb.right_bottom or cb[2]
      local w = math.max((rb.x or rb[1]) - (lt.x or lt[1]), (rb.y or rb[2]) - (lt.y or lt[2])) / 2
      if not flier and w > H.WIDTH then h = w end
    end
    half[name] = h
  end
  return h
end
separate.half = hull

-- Every unit prototype name that is a hull (once per load: prototypes do not change in a game).
local names
local function hull_names()
  if not names then
    names = {}
    for n, p in pairs(prototypes.get_entity_filtered{{filter = "type", type = "unit"}}) do
      if hull(n) then names[#names + 1] = n end
    end
  end
  return names
end

local function nudge(s, u, x, y)
  local p = {u.position.x + x, u.position.y + y}
  if s.can_place_entity{name = u.name, position = p, force = u.force} then
    u.teleport(p)
    return true
  end
  return false
end

function separate.tick(tick)
  if tick % H.EVERY ~= 5 then return end
  storage.sep = storage.sep or {nudges = 0, looks = 0, rng = rng.new(20261111)}
  local st = storage.sep
  local hn = hull_names()
  if #hn == 0 then return end
  -- (A slice of the map's chunks each look, the whole in SCAN: one search of the whole map every SCAN ticks cost 27 ms
  -- on the user's nw save, "still too much of a spike". Those already listed and still valid kept; the new list swapped
  -- in when the slice reaches the end. Chunk ids in storage, numbers only.)
  if not st.cq or (st.ci or 1) > #st.cq then
    if st.next_list then
      local seen, out = {}, {}
      for _, u in ipairs(st.next_list) do if u.valid and not seen[u.unit_number] then seen[u.unit_number] = true; out[#out + 1] = u end end
      for _, u in ipairs(st.list or {}) do if u.valid and not seen[u.unit_number] then seen[u.unit_number] = true; out[#out + 1] = u end end
      st.list = out
    end
    -- (The chunk list built once, then kept by on_chunk_generated, separate.on_chunk: built every cycle on a map this
    -- size it cost 28 to 35 ms itself.)
    if not st.chunks then
      st.chunks = {}
      for _, s in pairs(game.surfaces) do
        for c in s.get_chunks() do st.chunks[#st.chunks + 1] = (s.index * 4096 + (c.x + 2048)) * 4096 + (c.y + 2048) end
      end
    end
    st.cq, st.ci, st.next_list = st.chunks, 1, {}
    st.list = st.list or {}
  end
  do
    local per = math.max(1, math.ceil(#st.cq / (SCAN / H.EVERY)))
    local last = math.min(#st.cq, st.ci + per - 1)
    for i = st.ci, last do
      local v = st.cq[i]
      local cy = v % 4096 - 2048
      local rest = (v - (cy + 2048)) / 4096
      local cx = rest % 4096 - 2048
      local si = (rest - (cx + 2048)) / 4096
      local s = game.surfaces[si]
      if s and s.is_chunk_generated({cx, cy}) then
        for _, u in ipairs(s.find_entities_filtered{area = {{cx * 32, cy * 32}, {cx * 32 + 32, cy * 32 + 32}}, type = "unit", name = hn}) do
          st.next_list[#st.next_list + 1] = u
        end
      end
    end
    st.ci = last + 1
  end
  -- Who stands still since the last look, and who ram.lua steers.
  st.at = st.at or {}
  local still, steered = {}, {}
  for k in pairs(storage.rams or {}) do steered[k] = true end
  for _, f in ipairs(storage.ram_followers or {}) do
    for _, u in ipairs(f.units or {}) do if u.valid then steered[u.unit_number] = true end end
  end
  local seen = {}
  for _, u in ipairs(st.list) do
    if u.valid then
      local k, p = u.unit_number, u.position
      local was = st.at[k]
      still[k] = was and math.abs(p.x - was[1]) + math.abs(p.y - was[2]) < STILL and not steered[k]
      st.at[k], seen[k] = {p.x, p.y}, true
    end
  end
  for k in pairs(st.at) do if not seen[k] then st.at[k] = nil end end
  do
    -- (SEP_SLICE hulls a look, in turn: all of them, each a search round it, took 7 ms a look with 78 tanks at one camp,
    -- the spike guard on the user's nw save.)
    local list = {}
    local all = st.list
    local from = (st.sep_cursor or 0) % math.max(1, #all) + 1
    local last = math.min(#all, from + SEP_SLICE - 1)
    st.sep_cursor = last >= #all and 0 or last
    for i = from, last do list[#list + 1] = all[i] end
    for _, a in ipairs(list) do
      local s = a.valid and not steered[a.unit_number] and a.surface
      if s then
        local ra = hull(a.name)
        st.looks = st.looks + 1
        for _, b in ipairs(s.find_entities_filtered{position = a.position, radius = 2 * ra * H.GAP + 1, type = "unit"}) do
          local rb = b ~= a and b.valid and b.unit_number > a.unit_number and not steered[b.unit_number] and hull(b.name)
          if rb then
            local need = H.GAP * (ra + rb)
            local dx, dy = a.position.x - b.position.x, a.position.y - b.position.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d < need and (d < DEEP or (still[a.unit_number] and still[b.unit_number])) then
              if d < 0.01 then
                local t = rng.next(st.rng) * 2 * math.pi
                dx, dy, d = math.cos(t), math.sin(t), 1
              end
              local step = math.min(H.STEP, (need - d) / 2)
              local ux, uy = dx / d * step, dy / d * step
              local moved = nudge(s, a, ux, uy)
              moved = nudge(s, b, -ux, -uy) or moved
              if moved then st.nudges = st.nudges + 1 end
            end
          end
        end
      end
    end
  end
end

-- A chunk generated: on the list the hulls are looked for in (its slice comes round in its turn).
function separate.on_chunk(e)
  local st = storage.sep
  if not (st and st.chunks) then return end
  st.chunks[#st.chunks + 1] = (e.surface.index * 4096 + (e.position.x + 2048)) * 4096 + (e.position.y + 2048)
end

function separate.stats()
  local st = storage.sep or {}
  return {nudges = st.nudges or 0, looks = st.looks or 0}
end

return separate
