-- Reference factories (the user, 2026-10-18: "Can you look online for better control saves? ... Pretty sure lasers +
-- robots negating them completely is not good"; online, the 2.0 saves are benchmark megabases with no biters). Built by
-- script on a map with default biters, without Landing Party, and saved for scripts/visit.sh to load like a player's
-- save (scripts/make_reference.sh). One working core for all: assemblers making gears from infinity chests (they run,
-- so they pollute and draw real attacks), labs, belts, solar and accumulators, substations; mining outposts on the
-- nearest ore outside the wall, wired home by big poles (exposed lines, as players build them). Kinds:
--   belt       a wall ring with gun turrets every 8 tiles, ammunition in them; no robots; early military research
--   laser      lasers every 6 tiles, roboports over the core and the wall with construction robots and repair packs,
--              spares in storage, ghosts on death; laser research
--   artillery  the laser base and six artillery turrets with shells; artillery research
-- params.lua: {kind = "belt" | "laser" | "artillery", save_at = tick, evolution = 0..1}
local params = require("params")

local H, W = 60, 90           -- the core's half-size, the wall's
local CLEAR = 140             -- the cleared square's half-size

local function surface() return game.surfaces[1] end
local P = "player"

local function put(name, pos, extra)
  local s = surface()
  local spec = {name = name, position = pos, force = P}
  for k, v in pairs(extra or {}) do spec[k] = v end
  if not s.can_place_entity{name = name, position = pos, force = P, direction = spec.direction} then
    local q = s.find_non_colliding_position(name, pos, 3, 0.5)
    if not q then return nil end
    spec.position = q
  end
  return s.create_entity(spec)
end

local function clear_ground()
  local s = surface()
  s.request_to_generate_chunks({0, 0}, math.ceil(CLEAR / 32) + 8)
  s.force_generate_chunk_requests()
  local area = {{-CLEAR, -CLEAR}, {CLEAR, CLEAR}}
  for _, e in pairs(s.find_entities_filtered{area = area, type = {"tree", "simple-entity", "cliff", "unit-spawner", "turret", "unit"}}) do
    if e.valid and (e.force.name == "enemy" or e.force.name == "neutral") then e.destroy() end
  end
  local tiles = {}
  for _, t in pairs(s.find_tiles_filtered{area = area, collision_mask = "water_tile"}) do
    tiles[#tiles + 1] = {name = "grass-1", position = t.position}
  end
  if #tiles > 0 then s.set_tiles(tiles) end
end

local function power()
  -- Substations every 14 tiles over the walled square: their supply (9) reaches the turrets by the wall.
  for x = -84, 84, 14 do for y = -84, 84, 14 do put("substation", {x, y}) end end
  -- Solar and accumulators, the core's south side.
  for i = 0, 11 do for j = 0, 4 do put("solar-panel", {-36 + i * 3 + 1.5, 64 + j * 3 + 1.5}) end end
  for i = 0, 9 do put("accumulator", {-30 + i * 2 + 1, 80 + 1}) end
  -- And an interface for the rest (the core draws more than a field this size makes).
  local e = put("electric-energy-interface", {40, 70})
  if e then e.power_production, e.electric_buffer_size = 50e6 / 60, 50e6 end
end

local function core()
  -- Rows of assemblers making gears: plates in from an infinity chest, gears out into one that voids them.
  local n = 0
  for y = -48, 40, 11 do
    for x = -54, 50, 8 do
      local a = put("assembling-machine-2", {x + 1.5, y + 1.5})
      if a then
        a.set_recipe("iron-gear-wheel")
        put("inserter", {x + 1.5, y - 0.5}, {direction = defines.direction.south})
        local src = put("infinity-chest", {x + 1.5, y - 1.5})
        if src then src.set_infinity_container_filter(1, {name = "iron-plate", count = 100, mode = "exactly"}) end
        put("inserter", {x + 1.5, y + 3.5}, {direction = defines.direction.south})
        local sink = put("infinity-chest", {x + 1.5, y + 4.5})
        if sink then sink.remove_unfiltered_items = true end
        n = n + 1
      end
    end
  end
  -- Labs and a radar.
  for i = 0, 5 do put("lab", {-20 + i * 4 + 1.5, -58 + 1.5}) end
  put("radar", {30, -58})
  -- A belt loop round the core (what raids chew).
  for x = -H, H do put("transport-belt", {x + 0.5, -H + 0.5}, {direction = defines.direction.east}) end
  for y = -H, H do put("transport-belt", {H + 0.5, y + 0.5}, {direction = defines.direction.south}) end
  return n
end

local function wall(kind)
  for k = -W, W do
    for _, p in ipairs({{k, -W}, {k, W}, {-W, k}, {W, k}}) do put("stone-wall", {p[1] + 0.5, p[2] + 0.5}) end
  end
  local turret = kind == "belt" and "gun-turret" or "laser-turret"
  local step = kind == "belt" and 8 or 6
  local n = 0
  for k = -W + 4, W - 4, step do
    for _, p in ipairs({{k, -W + 3}, {k, W - 3}, {-W + 3, k}, {W - 3, k}}) do
      local t = put(turret, {p[1], p[2]})
      if t then
        n = n + 1
        if turret == "gun-turret" then t.insert{name = "piercing-rounds-magazine", count = 100} end
      end
    end
  end
  return n
end

local function robots()
  local n = 0
  for x = -80, 80, 40 do for y = -80, 80, 40 do
    local r = put("roboport", {x + 2, y + 2})
    if r then
      r.insert{name = "construction-robot", count = 30}
      r.insert{name = "repair-pack", count = 50}
      n = n + 1
    end
  end end
  for i = 0, 3 do
    local c = put("storage-chest", {-10 + i * 6 + 0.5, 50.5})
    if c then
      c.insert{name = "stone-wall", count = 400}
      c.insert{name = "laser-turret", count = 40}
      c.insert{name = "substation", count = 20}
      c.insert{name = "roboport", count = 4}
      c.insert{name = "repair-pack", count = 200}
    end
  end
  game.forces[P].create_ghost_on_entity_death = true
  return n
end

local function artillery()
  local n = 0
  for _, p in ipairs({{-60, -60}, {60, -60}, {-60, 60}, {60, 60}, {0, -70}, {0, 70}}) do
    local a = put("artillery-turret", p)
    if a then a.insert{name = "artillery-shell", count = 15}; n = n + 1 end
  end
  return n
end

-- Outposts: the two richest ore cells (64 tiles) between 120 and 320 tiles out, wired home by big poles every 26 tiles to
-- the nearest substation inside the wall. Their drills feed a belt that runs home (an L: along x, then y) through the
-- wall to a loader into an infinity chest that voids it, as a mid-game base belts its ore in (the user, 2026-10-19:
-- "Did you not test the skim on a ref save?"; the drills had filled chests, and no belt outside the wall carried
-- anything).
local DIRS = {east = defines.direction.east, west = defines.direction.west, north = defines.direction.north,
  south = defines.direction.south}
local function clear_tile(s, x, y)
  for _, e in pairs(s.find_entities_filtered{area = {{x - 0.4, y - 0.4}, {x + 0.4, y + 0.4}}}) do
    if e.valid and e.type ~= "resource" and e.type ~= "character" then e.destroy() end
  end
end
local function belt_home(c)
  local s = surface()
  local clamp = function(v) return math.max(-W + 8, math.min(W - 8, v)) end
  local x0, y0 = math.floor(c.x), math.floor(c.y)
  local tx, ty = clamp(x0), clamp(y0)
  local path = {}
  local sx = tx >= x0 and 1 or -1
  for x = x0, tx, sx do table.insert(path, {x, y0}) end
  local sy = ty >= y0 and 1 or -1
  if ty ~= y0 then for y = y0 + sy, ty, sy do table.insert(path, {tx, y}) end end
  -- Each tile toward the next; the last as the one before it.
  local function dir(a, b)
    if b[1] > a[1] then return "east" elseif b[1] < a[1] then return "west" elseif b[2] > a[2] then return "south" end
    return "north"
  end
  for i = 1, #path do path[i][3] = path[i + 1] and dir(path[i], path[i + 1]) or (path[i - 1] and path[i - 1][3] or "east") end
  local belts = {}
  for _, t in ipairs(path) do
    local pos = {t[1] + 0.5, t[2] + 0.5}
    clear_tile(s, pos[1], pos[2])
    if s.count_tiles_filtered{position = pos, radius = 0.5, collision_mask = "water_tile", limit = 1} > 0 then
      s.set_tiles({{name = "landfill", position = pos}})
    end
    local b = s.create_entity{name = "transport-belt", position = pos, direction = DIRS[t[3]], force = P}
    if b then table.insert(belts, {b, t}) end
  end
  -- The sink, past the belt's end: a loader into a chest that voids what it takes.
  local last = path[#path]
  local d = ({east = {1, 0}, west = {-1, 0}, north = {0, -1}, south = {0, 1}})[last[3]]
  local lp = {last[1] + d[1] + 0.5, last[2] + d[2] + 0.5}
  local cp = {last[1] + 2 * d[1] + 0.5, last[2] + 2 * d[2] + 0.5}
  clear_tile(s, lp[1], lp[2]); clear_tile(s, cp[1], cp[2])
  local sink = s.create_entity{name = "infinity-chest", position = cp, force = P}
  if sink then sink.remove_unfiltered_items = true end
  s.create_entity{name = "loader-1x1", position = lp, direction = DIRS[last[3]], type = "input", force = P}
  -- Drills on ore along the belt's first 24 tiles, both sides, facing it, with a pole by each.
  local drills = 0
  for i = 1, math.min(24, #belts), 3 do
    local b, t = belts[i][1], belts[i][2]
    local horizontal = t[3] == "east" or t[3] == "west"
    for side = -1, 1, 2 do
      local off = horizontal and {0, 2 * side} or {2 * side, 0}
      local face = horizontal and (side < 0 and "south" or "north") or (side < 0 and "east" or "west")
      local at = {b.position.x + off[1], b.position.y + off[2]}
      if s.count_entities_filtered{area = {{at[1] - 1.5, at[2] - 1.5}, {at[1] + 1.5, at[2] + 1.5}}, type = "resource", limit = 1} > 0 then
        for dx = -1, 1 do for dy = -1, 1 do clear_tile(s, at[1] + dx, at[2] + dy) end end
        local dr = s.create_entity{name = "electric-mining-drill", position = at, direction = DIRS[face], force = P}
        if dr then
          drills = drills + 1
          local pp = horizontal and {at[1] + 2, at[2] + side} or {at[1] + side, at[2] + 2}
          if s.can_place_entity{name = "medium-electric-pole", position = pp, force = P} then
            s.create_entity{name = "medium-electric-pole", position = pp, force = P}
          end
        end
      end
    end
  end
  return drills, #belts
end

local function outposts()
  local s = surface()
  s.request_to_generate_chunks({0, 0}, 12)
  s.force_generate_chunk_requests()
  local cells = {}
  for _, o in pairs(s.find_entities_filtered{area = {{-330, -330}, {330, 330}}, type = "resource"}) do
    local d = math.sqrt(o.position.x ^ 2 + o.position.y ^ 2)
    if d > 120 and d < 320 and o.prototype.mineable_properties.required_fluid == nil then
      local k = math.floor(o.position.x / 64) .. "," .. math.floor(o.position.y / 64)
      cells[k] = cells[k] or {n = 0, x = 0, y = 0}
      cells[k].n, cells[k].x, cells[k].y = cells[k].n + 1, cells[k].x + o.position.x, cells[k].y + o.position.y
    end
  end
  local list = {}
  for _, c in pairs(cells) do if c.n >= 60 then list[#list + 1] = {x = c.x / c.n, y = c.y / c.n, n = c.n} end end
  table.sort(list, function(a, b) return a.n > b.n end)
  local made, belts = 0, 0
  for i = 1, math.min(2, #list) do
    local c = list[i]
    for _, e in pairs(s.find_entities_filtered{position = {c.x, c.y}, radius = 40, type = {"unit-spawner", "turret", "tree"}}) do
      if e.force.name ~= P then e.destroy() end
    end
    local drills, n = belt_home(c)
    belts = belts + n
    -- The line home.
    local len = math.sqrt(c.x ^ 2 + c.y ^ 2)
    for d = len - 8, W - 4, -26 do put("big-electric-pole", {c.x / len * d, c.y / len * d}) end
    if drills > 0 then made = made + 1 end
  end
  return made, belts
end

local RESEARCH = {
  belt = {"military", "military-2", "turrets", "stone-wall", "physical-projectile-damage-1", "physical-projectile-damage-2",
    "physical-projectile-damage-3", "weapon-shooting-speed-1", "weapon-shooting-speed-2", "weapon-shooting-speed-3"},
  laser = {"laser-turret", "laser-weapons-damage-1", "laser-weapons-damage-2", "laser-weapons-damage-3",
    "laser-weapons-damage-4", "laser-shooting-speed-1", "laser-shooting-speed-2", "laser-shooting-speed-3",
    "laser-shooting-speed-4", "construction-robotics", "military-3", "stronger-explosives-1"},
}
RESEARCH.artillery = {"artillery"}
for _, t in ipairs(RESEARCH.laser) do table.insert(RESEARCH.artillery, t) end

script.on_event(defines.events.on_tick, function(e)
  if e.tick == 60 then
    local kind = params.kind
    clear_ground()
    for _, t in ipairs(RESEARCH[kind] or {}) do
      local tech = game.forces[P].technologies[t]
      if tech then pcall(function() tech.researched = true end) end
    end
    power()
    local machines = core()
    local turrets = wall(kind)
    local ports = (kind ~= "belt") and robots() or 0
    local guns = (kind == "artillery") and artillery() or 0
    local outs, belts = outposts()
    game.forces.enemy.set_evolution_factor(params.evolution or 0.4, surface())
    helpers.write_file("lp-ref/built.txt", string.format("%s: %d assemblers, %d turrets, %d roboports, %d artillery, %d outposts, %d belt tiles home\n",
      kind, machines, turrets, ports, guns, outs, belts))
  elseif e.tick == params.save_at then
    game.server_save("ref")
    helpers.write_file("lp-ref/saved.txt", tostring(e.tick))
  end
end)
