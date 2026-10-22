-- Synthexis's creep (docs/biotech.md "The build order with creep"; the user, 2026-10-22: "kind of a Zerg creep?").
-- A tumor (lp-tumor) grows creep (lp-creep) round itself, a ring every GROW_TICKS out to R_MAX. Creep is Gleba soil the
-- player cannot build on (its "object" layer); everything walks it. It flows round what stands: a tile under another
-- force's building is left as it is (the building stays, the player is not dispossessed), and it never covers water or a
-- floor someone laid (a mineable tile: concrete, the player's soils). The ground it covers is kept as the tile's hidden
-- tile, so it can withdraw to it. A culture plants one tumor by each incubator when it lands (farm.land).
-- Spread (creep.bud, from farm.tick): every BUD_TICKS, once its tumors are grown, a culture buds a tumor at its creep's edge
-- toward the nearest wild nest within HEDGE of it; creep that reaches the nest takes it (farm: an incubator). It grows
-- toward nests, never toward the player: an advancing front is Kessler-Hayashi's.
-- On creep (creep.tick): Synthexis's units are quicker and mend (stickers lp-creep-haste, lp-creep-mend) renewed each second
-- (a tile's walking speed does nothing to units: tested). Off it, plain.
-- A tumor killed: its creep withdraws a ring every RECEDE_TICKS to the ground it covered, but where a living tumor's
-- reaches. An incubator left off creep starves (farm.tick) and goes back to the wild.
-- Biomass (creep.drink): the pollution the engine's creep tiles absorb (shared.CREEP_ABSORB each, a second, up to what is
-- in the chunk) is counted to the culture whose tumor laid them; farm.lua spends it on breeding.
local shared = require("__landing-party__.shared")

local creep = {}

local B = shared.BIOTECH
creep.TILE = "lp-creep"
local TUMOR = "lp-tumor"
local R_MAX = 10               -- a tumor's creep reaches this far
local GROW_TICKS = 10 * 60     -- a ring each
local CHECK = 60
local RECEDE_TICKS = 5 * 60    -- a ring each, withdrawing
local BUD_TICKS = 2 * 3600     -- a culture buds a tumor this often, at most
local HEDGE = 160              -- wild nests this near a culture are its to take
local TUMORS_MAX = 40          -- per culture
local BONUS_RADIUS = 200       -- round a culture, its units looked at for the bonus

local function st()
  storage.creep = storage.creep or {tumors = {}}
  storage.creep.chunks = storage.creep.chunks or {}
  return storage.creep
end

-- Creep tiles per chunk, and the culture whose tumor laid them (its biomass).
local function count(si, x, y, n, culture)
  local cx, cy = math.floor(x / 32), math.floor(y / 32)
  local key = si .. ":" .. cx .. "," .. cy
  local chunks = st().chunks
  local c = chunks[key]
  if not c then
    if n < 0 then return end
    c = {surface = si, x = cx * 32 + 16, y = cy * 32 + 16, n = 0, culture = culture}
    chunks[key] = c
  end
  c.n = c.n + n
  if c.n <= 0 then chunks[key] = nil end
end

-- Plant a tumor near pos (on creep or ground, never water). Returns it.
function creep.plant(surface, pos, farm_id)
  local q = surface.find_non_colliding_position(TUMOR, pos, 10, 0.5)
  local e = q and surface.create_entity{name = TUMOR, position = q, force = B.force}
  if not e then return nil end
  -- Its glow at night, acid green (Kessler-Hayashi's camps light cold white, Grubstake's amber); gone with it.
  rendering.draw_light{sprite = "utility/light_medium", surface = surface, target = e, color = {0.55, 1, 0.3},
    scale = 1.6, intensity = 0.9, minimum_darkness = 0.3}
  st().tumors[e.unit_number] = {entity = e, surface = surface.index, pos = {x = q.x, y = q.y}, r = 0, next = game.tick,
    farm = farm_id}
  return e
end

-- The tiles under other forces' buildings (anything that collides with the "object" layer) in the box: left as they are.
local function blocked(surface, box)
  local out = {}
  for _, e in ipairs(surface.find_entities_filtered{area = box}) do
    local f = e.force and e.force.name
    if f ~= B.force and f ~= "enemy" and f ~= "neutral" and e.prototype.collision_mask.layers.object then
      local bb = e.bounding_box
      for x = math.floor(bb.left_top.x), math.ceil(bb.right_bottom.x) - 1 do
        for y = math.floor(bb.left_top.y), math.ceil(bb.right_bottom.y) - 1 do out[x .. "," .. y] = true end
      end
    end
  end
  return out
end

-- Whether a living tumor's creep reaches (x, y) (tile centre), on surface index si; `except` a tumor record left out.
local function reached(si, x, y, except)
  for _, rec in pairs(st().tumors) do
    if rec ~= except and not rec.dying and rec.surface == si and rec.entity.valid then
      local r = rec.r + 0.5
      if (x - rec.pos.x) ^ 2 + (y - rec.pos.y) ^ 2 <= r * r then return true end
    end
  end
  return false
end

local function coverable(t)
  if t.name == creep.TILE or t.name == "out-of-map" or t.collides_with("water_tile") then return false end
  return not t.prototype.mineable_properties.minable
end

-- The next ring: the tiles whose centres lie between r - 1 and r from the tumor.
local function grow(rec)
  local s = game.surfaces[rec.surface]
  rec.r = rec.r + 1
  local r, cx, cy = rec.r, rec.pos.x, rec.pos.y
  local box = {{cx - r - 1, cy - r - 1}, {cx + r + 1, cy + r + 1}}
  local no = blocked(s, box)
  local tiles, under = {}, {}
  for x = math.floor(cx - r), math.ceil(cx + r) do
    for y = math.floor(cy - r), math.ceil(cy + r) do
      local d = (x + 0.5 - cx) ^ 2 + (y + 0.5 - cy) ^ 2
      if d <= r * r and d > (r - 1) ^ 2 and not no[x .. "," .. y] then
        local t = s.get_tile(x, y)
        if coverable(t) then
          table.insert(tiles, {name = creep.TILE, position = {x, y}})
          table.insert(under, t.name)
        end
      end
    end
  end
  if #tiles == 0 then return 0 end
  s.set_tiles(tiles, true, false, true, false)
  for i, t in ipairs(tiles) do
    s.set_hidden_tile(t.position, under[i])
    count(rec.surface, t.position[1], t.position[2], 1, rec.farm)
  end
  return #tiles
end

-- A dead tumor's outermost ring withdraws: creep tiles there that no living tumor reaches go back to the ground kept.
local function recede(rec)
  local s = game.surfaces[rec.surface]
  local r, cx, cy = rec.r, rec.pos.x, rec.pos.y
  local tiles, at = {}, {}
  for x = math.floor(cx - r), math.ceil(cx + r) do
    for y = math.floor(cy - r), math.ceil(cy + r) do
      local d = (x + 0.5 - cx) ^ 2 + (y + 0.5 - cy) ^ 2
      if d <= r * r and d > (r - 1) ^ 2 and s.get_tile(x, y).name == creep.TILE
        and not reached(rec.surface, x + 0.5, y + 0.5, rec) then
        table.insert(tiles, {name = s.get_hidden_tile({x, y}) or "dirt-1", position = {x, y}})
        table.insert(at, {x, y})
      end
    end
  end
  if #tiles > 0 then
    s.set_tiles(tiles, true, false, true, false)
    for _, p in ipairs(at) do
      s.set_hidden_tile(p, nil)
      count(rec.surface, p[1], p[2], -1)
    end
  end
  rec.r = r - 1
end

-- Synthexis's units on creep: quicker and mending, a second at a time.
local function bonus(s, pos)
  for _, u in ipairs(s.find_entities_filtered{position = pos, radius = BONUS_RADIUS, force = B.force, type = "unit"}) do
    local p = u.position
    if s.get_tile(p.x, p.y).name == creep.TILE then
      s.create_entity{name = "lp-creep-haste", position = p, target = u}
      if u.health < u.max_health then s.create_entity{name = "lp-creep-mend", position = p, target = u} end
    end
  end
end

function creep.tick(tick)
  if tick % CHECK ~= 17 then return end
  local s = st()
  for id, rec in pairs(s.tumors) do
    if not rec.dying and not rec.entity.valid then
      rec.dying, rec.next = true, tick
    end
    if rec.dying then
      if tick >= rec.next then
        if rec.r <= 0 then s.tumors[id] = nil else recede(rec); rec.next = tick + RECEDE_TICKS end
      end
    elseif rec.r < R_MAX and tick >= rec.next then
      grow(rec)
      rec.next = tick + GROW_TICKS
    end
  end
  for _, c in pairs(s.cultures or {}) do
    local surface = game.surfaces[c.surface]
    if surface then bonus(surface, c.pos) end
  end
end

-- What the creep drank over `seconds`, to each culture's biomass: per chunk, its creep tiles' absorption, up to the
-- pollution there (the engine absorbs it itself; this counts it). Returns {culture = amount}.
function creep.drink(seconds)
  local out = {}
  for _, c in pairs(st().chunks) do
    local surface = game.surfaces[c.surface]
    local cul = st().cultures and st().cultures[c.culture]
    if surface and cul then
      local p = surface.get_pollution({c.x, c.y})
      local got = math.min(p, c.n * shared.CREEP_ABSORB * seconds)
      if got > 0 then
        cul.biomass = (cul.biomass or 0) + got
        cul.drunk = (cul.drunk or 0) + got
        out[c.culture] = (out[c.culture] or 0) + got
      end
    end
  end
  return out
end

-- A culture's record (its biomass lives there), or nil.
function creep.of(id) return st().cultures and st().cultures[id] end

-- Whether pos is on creep.
function creep.covered(surface, pos) return surface.get_tile(pos.x, pos.y).name == creep.TILE end

-- A culture's centre (farm.land), for its spread and its units' bonus.
function creep.culture(id, surface, pos)
  local s = st()
  s.cultures = s.cultures or {}
  s.cultures[id] = {surface = surface.index, pos = {x = pos.x, y = pos.y}, last_bud = game.tick, biomass = 0, drunk = 0}
end

function creep.forget(id) if st().cultures then st().cultures[id] = nil end end

-- Spread (farm.tick): the wild nest whose spawner the creep now reaches, for the farm to take; else, when every tumor
-- of the culture is grown and BUD_TICKS have passed, a tumor budded at the creep's edge toward the nearest wild nest
-- within HEDGE. Returns the spawner to take, or nil.
function creep.bud(id, tick)
  local s = st()
  local c = s.cultures and s.cultures[id]
  if not c then return nil end
  local surface = game.surfaces[c.surface]
  local mine, growing = {}, false
  for _, rec in pairs(s.tumors) do
    if rec.farm == id and not rec.dying and rec.entity.valid then
      table.insert(mine, rec)
      if rec.r < R_MAX then growing = true end
    end
  end
  if #mine == 0 then return nil end
  local nests = surface.find_entities_filtered{type = "unit-spawner", force = "enemy", position = c.pos, radius = HEDGE}
  local best, bd, from
  for _, n in ipairs(nests) do
    for _, rec in ipairs(mine) do
      local d = (n.position.x - rec.pos.x) ^ 2 + (n.position.y - rec.pos.y) ^ 2
      if not bd or d < bd then best, bd, from = n, d, rec end
    end
  end
  if not best then return nil end
  if math.sqrt(bd) <= from.r + 2 then return best end
  if growing or tick - c.last_bud < BUD_TICKS or #mine >= TUMORS_MAX then return nil end
  c.last_bud = tick
  local d = math.sqrt(bd)
  local step = math.min(R_MAX - 1, d)
  local at = {x = from.pos.x + (best.position.x - from.pos.x) / d * step, y = from.pos.y + (best.position.y - from.pos.y) / d * step}
  creep.plant(surface, at, id)
  return nil
end

function creep.state()
  local out = {tumors = {}, dying = 0}
  for id, rec in pairs(st().tumors) do
    if rec.dying then out.dying = out.dying + 1
    elseif rec.entity.valid then table.insert(out.tumors, {id = id, pos = rec.pos, r = rec.r, farm = rec.farm}) end
  end
  return out
end

return creep
