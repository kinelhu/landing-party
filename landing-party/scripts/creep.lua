-- Synthexis's creep (docs/biotech.md "The build order with creep"; the user, 2026-10-22: "kind of a Zerg creep?").
-- A tumor (lp-tumor) grows creep (lp-creep) round itself, a ring every GROW_TICKS out to R_MAX. Creep is Gleba soil the
-- player cannot build on (its "object" layer); everything walks it. It flows round what stands: a tile under another
-- force's building is left as it is (the building stays, the player is not dispossessed), and it never covers water or a
-- floor someone laid (a mineable tile: concrete, the player's soils). The ground it covers is kept as the tile's hidden
-- tile, so it can withdraw to it. A culture plants one tumor by each incubator when it lands (farm.land).
-- Spread (creep.bud, from farm.tick): paid for (BUD_PRICE), a culture buds a tumor at its creep's edge
-- toward the nearest wild nest within HEDGE of it; creep that reaches the nest takes it (farm: an incubator). It grows
-- toward nests, never toward the player: an advancing front is Kessler-Hayashi's.
-- On creep (creep.tick): Synthexis's units are quicker and mend (stickers lp-creep-haste, lp-creep-mend) renewed each second
-- (a tile's walking speed does nothing to units: tested). Off it, plain.
-- A tumor killed: its creep withdraws a ring every RECEDE_TICKS to the ground it covered, but where a living tumor's
-- reaches. An incubator left off creep starves (farm.tick) and goes back to the wild.
-- Biomass (creep.drink): the pollution the engine's creep tiles absorb (shared.CREEP_ABSORB each, a second, up to what is
-- in the chunk) is counted to the culture whose tumor laid them; farm.lua spends it on breeding.
local shared = require("__landing-party__.shared")
local tune = require("__landing-party__.scripts.tune")
local costmap = require("__landing-party__.scripts.costmap")

local creep = {}

local B = shared.BIOTECH
creep.TILE = "lp-creep"
local TUMOR = "lp-tumor"
local R_MAX = 10               -- a tumor's creep reaches this far
local GROW_TICKS = 10 * 60     -- a ring each
local CHECK = 60
local RECEDE_TICKS = 5 * 60    -- a ring each, withdrawing
-- A bud is paid for (0.2.23; the user, 2026-10-25: "I want to see the sigmoid"): BUD_PRICE of biomass a tumor, as fast
-- as it can pay, BUD_MIN apart at least. On a two-minute clock its incubators rose in a straight line to their cap;
-- paid, its growth follows its income, and its income its creep: slow, then fast, then as the air allows.
local BUD_PRICE = 30
local BUD_MIN = 15 * 60
local HEDGE = 160              -- wild nests this near a culture are its to take
local STALL = 3                -- buds toward a nest without coming nearer: out of reach
local LAND_CELL = 8            -- tiles a cell of its reading of the ground round it (the walk to a nest over land)
local LAND_FOR = 10 * 3600     -- how long that reading holds (the ground, and the player's walls on it)
local STRAY = 0.9              -- a bud strays to a side, up to this share of a tumor's reach either way
local FOOD_HALF = 20           -- pollution in the 5 by 5 chunks round a nest that makes it count half as far
local FOUND_PRICE = 150        -- an incubator of its own, where no wild nest is near (five buds; a wild one is free)
local FOUND_APART = 16         -- from its other incubators
local STEP = R_MAX + 2         -- a bud toward the air, from a grown tumor
local SHY = 48
local DEAD_TREES = {"dry-tree", "dead-tree-desert", "dead-grey-trunk", "dead-dry-hairy-tree", "dry-hairy-tree"}
local DEAD_TREE = {}
for _, n in ipairs(DEAD_TREES) do DEAD_TREE[n] = true end                 -- nor within this of the player's buildings
local TUMORS_MAX = 40          -- per culture, at its 16 incubators (creep.bud: as many more for each it may have past 16)
creep.TUMORS_MAX = TUMORS_MAX
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
  -- The trees it reaches die (the user, 2026-10-26: "creep needs to make trees lose their leaves"): each becomes one of
  -- the game's dead trees (a tree's last gray stage only darkens its leaves: seen in screenshots, not bare).
  for _, t in pairs(s.find_entities_filtered{area = box, type = "tree"}) do
    local p = t.position
    if not DEAD_TREE[t.name] and (p.x - cx) ^ 2 + (p.y - cy) ^ 2 <= r * r then
      local name = DEAD_TREES[1 + math.floor(((p.x * 73 + p.y * 151) % 97) / 97 * #DEAD_TREES)]
      t.destroy()
      s.create_entity{name = name, position = p}
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

-- The player's defoliant (studies.lua): every creep tile within r of `at` back to the ground kept under it, at once,
-- whatever tumor reaches it (living tumors spread it again as they do).
function creep.defoliate(s, at, r)
  local cx, cy = at.x or at[1], at.y or at[2]
  local tiles, pts = {}, {}
  for x = math.floor(cx - r), math.ceil(cx + r) do
    for y = math.floor(cy - r), math.ceil(cy + r) do
      if (x + 0.5 - cx) ^ 2 + (y + 0.5 - cy) ^ 2 <= r * r and s.get_tile(x, y).name == creep.TILE then
        table.insert(tiles, {name = s.get_hidden_tile({x, y}) or "dirt-1", position = {x, y}})
        table.insert(pts, {x, y})
      end
    end
  end
  if #tiles == 0 then return 0 end
  s.set_tiles(tiles, true, false, true, false)
  for _, p in ipairs(pts) do
    s.set_hidden_tile(p, nil)
    count(s.index, p[1], p[2], -1)
  end
  return #tiles
end

-- A grown tumor sunk in its creep: Gleba's slime under it and nerve roots round it (decoratives, laid once its creep is
-- grown: growing, the creep's tiles clear what lies on them).
-- (Cream, red and grey on its violet: the purple ones were laid and could not be seen, 2026-10-26.)
local ROOTS = {"cream-nerve-roots-veins-dense", "red-nerve-roots-veins-sparse", "curly-roots-grey", "knobbly-roots",
  "cream-nerve-roots-veins-sparse"}
local SLIME = "polycephalum-slime"
local function sink(rec)
  local s = game.surfaces[rec.surface]
  if not s or not rec.entity.valid then return end
  local out = {{name = SLIME, position = {rec.pos.x, rec.pos.y}, amount = 1}}
  for k = 1, 7 do
    local a = k * 2.4 + rec.pos.x
    local r = 1.5 + (k % 3) * 1.2
    out[#out + 1] = {name = ROOTS[k % #ROOTS + 1], position = {rec.pos.x + math.cos(a) * r, rec.pos.y + math.sin(a) * r}, amount = 1}
  end
  s.create_decoratives{check_collision = false, decoratives = out}
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
      if rec.r >= R_MAX then sink(rec) end
    end
  end
  for _, c in pairs(s.cultures or {}) do
    local surface = game.surfaces[c.surface]
    if surface then bonus(surface, c.pos) end
  end
end

-- How much faster its incubators turn air into biomass at its evolution: as a wild spawner's births quicken, its cooldown
-- from 360 ticks to 150 over evolution (the game's own biter-spawner, data/base enemies.lua), EVO_QUICKEN times at the most.
-- (The user, 2026-10-27, on a megabase's map at full evolution: its income stayed what it was at the start, and its waves
-- of mediums were a quarter of what its defences took.)
local EVO_QUICKEN = 360 / 150
-- (EVO_ON: on deathworld, six timings each, 685 razed with it against 895 without, each side from 34 or 58 to over 1,500:
-- noise, 2026-10-28. On nw it took Synthexis from one culture to five.)
local EVO_ON = true
function creep.evo_rate(surface)
  if not EVO_ON then return 1 end
  local f = game.forces[B.force]
  local evo = f and f.get_evolution_factor(surface) or 0
  return 1 + (EVO_QUICKEN - 1) * evo
end

-- What a culture ate over `seconds`, to its biomass: per chunk, what its creep tiles and incubators there absorb
-- (shared.CREEP_ABSORB, PEN_ABSORB, PEN_SHARE), up to the pollution there, taken off the air (the engine's absorption on
-- both is off: this is it). pens: {culture = {incubator entities}}. Returns {culture = biomass}.
function creep.drink(seconds, pens)
  local at = {}
  local function chunk(si, x, y, culture)
    local cx, cy = math.floor(x / 32), math.floor(y / 32)
    local key = si .. ":" .. cx .. "," .. cy
    local c = at[key]
    if not c then
      c = {surface = si, x = cx * 32 + 16, y = cy * 32 + 16, n = 0, pens = 0, culture = culture}
      at[key] = c
    end
    return c
  end
  for _, c in pairs(st().chunks) do chunk(c.surface, c.x, c.y, c.culture).n = c.n end
  for id, list in pairs(pens or {}) do
    for _, e in ipairs(list) do
      if e.valid then
        local c = chunk(e.surface.index, e.position.x, e.position.y, id)
        c.pens = c.pens + 1
      end
    end
  end
  local out = {}
  for _, c in pairs(at) do
    local surface = game.surfaces[c.surface]
    local cul = st().cultures and st().cultures[c.culture]
    if surface and cul then
      local p = surface.get_pollution({c.x, c.y})
      local took = math.min(p, (c.n * shared.CREEP_ABSORB + c.pens * shared.PEN_ABSORB) * seconds
        + p * math.min(1, c.pens * shared.PEN_SHARE * seconds))
      if took > 0 then
        surface.pollute({c.x, c.y}, -took, c.pens > 0 and "lp-pen" or nil)
        local got = took * shared.YIELD * tune.income("biotech") * creep.evo_rate(surface)
        creep.earn(cul, got)
        cul.drunk = (cul.drunk or 0) + got
        cul.eaten = (cul.eaten or 0) + took
        out[c.culture] = (out[c.culture] or 0) + got
      end
    end
  end
  return out
end

-- The pollution round pos: its chunk and the chunks within `r` chunks of it. Where wild nests ring a factory's cloud they
-- eat its edge, and their own chunks read clean (deathworld10x, 2026-10-26: every nest field 200 to 450 tiles out read 0
-- in its 5 by 5 chunks); the air a little way in tells how near the cloud is.
function creep.food(surface, pos, r)
  local t = 0
  for dx = -r, r do
    for dy = -r, r do t = t + surface.get_pollution({pos.x + dx * 32, pos.y + dy * 32}) end
  end
  return t
end

-- A culture's living tumors (entities).
function creep.tumors_of(id)
  local out = {}
  for _, rec in pairs(st().tumors) do
    if rec.farm == id and not rec.dying and rec.entity.valid then table.insert(out, rec.entity) end
  end
  return out
end

-- A culture's record (its biomass lives there), or nil.
function creep.of(id) return st().cultures and st().cultures[id] end

-- A nest its creep is not to take again: an incubator gone back to the wild (farm.lua) is a new spawner where it stood.
function creep.block(c, nest)
  if not (c and nest and nest.valid) then return end
  c.blocked = c.blocked or {}
  c.blocked[nest.unit_number] = true
end

-- Whether pos is on creep.
function creep.covered(surface, pos) return surface.get_tile(pos.x, pos.y).name == creep.TILE end

-- A culture's centre (farm.land), for its spread and its units' bonus.
function creep.culture(id, surface, pos)
  local s = st()
  s.cultures = s.cultures or {}
  s.cultures[id] = {surface = surface.index, pos = {x = pos.x, y = pos.y}, last_bud = game.tick, biomass = 0, growth = 0,
    drunk = 0}
end

function creep.forget(id) if st().cultures then st().cultures[id] = nil end end

-- Its income in two pools (the user, 2026-10-29: "decouple growth from breeding for spending"): GROWTH_SHARE of all it
-- earns to its growth (buds, incubators of its own, technicians, carriers), the rest to its breeding, and neither waits
-- on the other. One pool, a siege priced at four hours of income took it all at minute 10 on nw: three incubators and
-- eight tumors for three hours, its creep short of the air that fed it, and one wave in five hours. Its growth still
-- follows its income (the sigmoid); what growth holds above GROWTH_HOLD (a carrier and an incubator: nothing left to grow
-- into) spills to its breeding. Young, YOUNG_SHARE (its farm sets c.share): at a third, a culture on a map with no
-- pollution bought 5 buds while it bred 113, and its creep never reached the far nest (creep spread, 2026-10-29); at
-- three quarters, a young culture grew 7 incubators in 40 minutes and bred half its first wave (farm).
creep.GROWTH_SHARE = 1 / 3
creep.YOUNG_SHARE = 1 / 2
creep.GROWTH_HOLD = 450
function creep.earn(c, amount)
  local share = c.share or creep.YOUNG_SHARE
  local g = (c.growth or 0) + amount * share
  local spill = math.max(0, g - creep.GROWTH_HOLD)
  c.growth = g - spill
  c.biomass = (c.biomass or 0) + amount * (1 - share) + spill
end

-- Growth paid from its own pool.
function creep.spend_growth(c, price)
  c.growth, c.spent = (c.growth or 0) - price, (c.spent or 0) + price
end

local function pay(c, tick, price)
  c.last_bud = tick
  creep.spend_growth(c, price)
end

-- No wild nest within HEDGE (the user, 2026-10-26: "in the cases of 0 nest being capturable in range, shouldn't we give
-- ability to establish a new one at cost?"): it grows its own. A grown tumor with no incubator within FOUND_APART gets
-- one, at FOUND_PRICE; else a tumor buds at the creep's edge toward the most pollution, never within SHY of the player's.
-- Returns {found = position} or nil; c.wants is the price it is saving for.
-- Room for an incubator near pos: no entity in its box. (find_non_colliding_position finds none on creep: the tile
-- is on the object layer, as buildings are, so the player cannot build on it.)
local function room(surface, pos)
  for r = 3, 9, 3 do
    for k = 0, 7 do
      local a = k * math.pi / 4
      local p = {x = pos.x + math.cos(a) * r, y = pos.y + math.sin(a) * r}
      -- (On its creep: off it, an incubator starves, farm.lua.)
      if surface.count_entities_filtered{area = {{p.x - 3, p.y - 3}, {p.x + 3, p.y + 3}}, limit = 1} == 0
        and creep.covered(surface, p) then return p end
    end
  end
end

-- Where it could found an incubator of its own now: a grown tumor with no incubator within FOUND_APART and room by it.
-- A nest set aside, and why (decisions.txt, when the planner's trace is on).
local function ctrace(n, why)
  if storage.trace then
    helpers.write_file("landing-party/decisions.txt", string.format("%8d %s  its creep sets aside the nest at %.0f,%.0f: %s\n",
      game.tick, "biotech", n.position.x, n.position.y, why), true)
  end
end

-- A corporation's camp a berth off (shared.berth): its creep takes no nest and founds no incubator there (on nwa its creep
-- took nests toward Kessler-Hayashi's fortress as the fortress grew toward it, and the farm fell to it; 0.2.355). Its
-- buildings only: their units walk where they like.
local MOBILE = {"unit", "car", "spider-vehicle", "character"}
local function by_camp(surface, pos)
  local fs = {}
  for _, c in pairs(shared.CORPS) do if game.forces[c.force] then fs[#fs + 1] = c.force end end
  if #fs == 0 then return false end
  local r = shared.berth()
  if r <= 0 then return false end
  return surface.count_entities_filtered{position = pos, radius = r, force = fs}
    > surface.count_entities_filtered{position = pos, radius = r, force = fs, type = MOBILE}
end
creep.by_camp = by_camp

local function found_spot(surface, mine)
  for _, rec in ipairs(mine) do
    if rec.r >= R_MAX
      and surface.count_entities_filtered{name = "lp-pen", position = rec.pos, radius = FOUND_APART, limit = 1} == 0
      and not by_camp(surface, rec.pos) and room(surface, rec.pos) then return rec end
  end
end

local function found(c, id, surface, mine, tick)
  for _, rec in ipairs(mine) do
    if rec.r >= R_MAX
      and surface.count_entities_filtered{name = "lp-pen", position = rec.pos, radius = FOUND_APART, limit = 1} == 0
      and not by_camp(surface, rec.pos) then
      local q = room(surface, rec.pos)
      if q then
        c.wants = FOUND_PRICE
        if tick - c.last_bud < BUD_MIN or (c.growth or 0) < FOUND_PRICE then return nil end
        pay(c, tick, FOUND_PRICE)
        c.founded = (c.founded or 0) + 1
        return {found = q}
      end
    end
  end
  if #mine >= (c.tumors_max or TUMORS_MAX) then return nil end
  c.wants = BUD_PRICE
  if tick - c.last_bud < BUD_MIN or (c.growth or 0) < BUD_PRICE then return nil end
  local forces = shared.player_forces()
  local at, best
  for _, rec in ipairs(mine) do
    if rec.r >= R_MAX - 1 then
      for k = 0, 7 do
        local a = k * math.pi / 4
        local p = {x = rec.pos.x + math.cos(a) * STEP, y = rec.pos.y + math.sin(a) * STEP}
        local new = true
        for _, o in ipairs(mine) do
          if (o.pos.x - p.x) ^ 2 + (o.pos.y - p.y) ^ 2 < R_MAX * R_MAX then new = false; break end
        end
        local t = new and surface.get_tile(p.x, p.y)
        if t and t.valid and not t.collides_with("water_tile") and t.name ~= "out-of-map" then
          -- The air first, then outward from the culture's middle.
          local score = surface.get_pollution(p) + 0.001 * ((p.x - c.pos.x) ^ 2 + (p.y - c.pos.y) ^ 2) ^ 0.5
          if (not best or score > best)
            and surface.count_entities_filtered{position = p, radius = SHY, force = forces, limit = 1} == 0 then
            at, best = p, score
          end
        end
      end
    end
  end
  if not at then return nil end
  pay(c, tick, BUD_PRICE)
  c.budded = (c.budded or 0) + 1
  creep.plant(surface, at, id)
  return nil
end

-- Spread (farm.tick): the wild nest whose spawner the creep now reaches, for the farm to take; else a tumor budded at the
-- creep's edge (BUD_PRICE, BUD_MIN apart) toward the wild nest within HEDGE that is nearest for the air round it (a nest
-- with FOOD_HALF of pollution in the chunks round it counts half as far: the creep leans toward the cloud); with none,
-- an incubator of its own (found). Returns the spawner to take, {found = position}, or nil.
-- tumors: its tumors at most (its farm's, by its incubators at most: at 40 a culture's creep held 15 incubators, and one
-- allowed 28 stopped there; farm bigpens).
function creep.bud(id, tick, tumors)
  local s = st()
  local c = s.cultures and s.cultures[id]
  if not c then return nil end
  c.tumors_max = tumors
  local surface = game.surfaces[c.surface]
  local mine = {}
  for _, rec in pairs(s.tumors) do
    if rec.farm == id and not rec.dying and rec.entity.valid then
      table.insert(mine, rec)
    end
  end
  c.wants = nil
  if #mine == 0 then return nil end
  -- Nests it found out of reach (STALL buds toward one brought the creep no nearer: across water) are left out; with
  -- none left, it grows its own (found).
  c.blocked = c.blocked or {}
  local nests = {}
  for _, n in ipairs(surface.find_entities_filtered{type = "unit-spawner", force = "enemy", position = c.pos, radius = HEDGE}) do
    -- (By a camp: read again with its reading of the ground, LAND_FOR.)
    c.berthed = c.berthed or {}
    local bt = c.berthed[n.unit_number]
    if not bt or tick - bt.t >= LAND_FOR then
      bt = {t = tick, near = by_camp(surface, n.position)}
      c.berthed[n.unit_number] = bt
      if bt.near then ctrace(n, "a corporation's camp within its berth") end
    end
    if not c.blocked[n.unit_number] and not bt.near then nests[#nests + 1] = n end
  end
  if #nests == 0 then return found(c, id, surface, mine, tick) end
  -- Over land: the walk from its middle to each nest, round water (a cost map of the ground, no fire: costmap). In a
  -- straight line, its creep went for nests across a lake arm from a megabase's shore, budded along the waterline for half
  -- an hour and took none (2026-10-27).
  c.land = c.land or {}
  local land = c.land.map
  if not land or tick - c.land.tick >= LAND_FOR then
    local m = costmap.read(surface, c.pos, HEDGE + 2 * R_MAX, {"player"}, {from = c.pos, cell = LAND_CELL})
    -- (Kept in storage: its numbers only, what costmap.cost and costmap.path read.)
    land = {x0 = m.x0, y0 = m.y0, size = m.size, w = m.w, h = m.h, cost = m.cost, came = m.came}
    c.land = {map = land, tick = tick}
  end
  local best, bs, path
  for _, n in ipairs(nests) do
    for _, rec in ipairs(mine) do
      local d = ((n.position.x - rec.pos.x) ^ 2 + (n.position.y - rec.pos.y) ^ 2) ^ 0.5
      -- Taken only on its creep, as an incubator is fed (creep.covered): within reach and two tiles but off it, a nest was
      -- taken, starved off its creep in three minutes, went wild and was taken again, 172 times in five hours on nw, its
      -- culture's breeding in debt all the while (2026-10-29). Within reach and still off it, it buds on toward it: its creep
      -- wanders (0.2.28) and a grown tumor's reach leaves bare ground, and set aside at once there, a nest 65 tiles out was
      -- never taken (the playtest's slower climb, 0.2.127; creep spread). Its buds no nearer, STALL, set it aside.
      if d <= rec.r + 2 and creep.covered(surface, n.position) then return n end
    end
    local walk = costmap.cost(land, n.position)
    if walk then
      local pull = 1 + creep.food(surface, n.position, 2) / FOOD_HALF
      local tiles = walk / costmap.WALK
      if not bs or tiles / pull < bs then best, bs = n, tiles / pull end
    else
      c.blocked[n.unit_number] = true; ctrace(n, "no walk to it")
    end
  end
  if not best then return found(c, id, surface, mine, tick) end
  path = costmap.path(land, best.position) or {}
  -- Its next step: the first point of that walk its creep does not cover yet, budded from the tumor nearest it.
  local k, to
  for i, q in ipairs(path) do
    local covered = false
    for _, rec in ipairs(mine) do
      if (q.x - rec.pos.x) ^ 2 + (q.y - rec.pos.y) ^ 2 <= rec.r * rec.r then covered = true; break end
    end
    if not covered then k, to = i, q; break end
  end
  if not to then k, to = #path + 1, {x = best.position.x, y = best.position.y} end
  -- The cheaper incubator (the user, 2026-10-28, on a megabase where its creep took one nest for 114 buds in three
  -- hours): the rest of the way to that nest in buds (its walk not yet covered, STEP a bud, BUD_PRICE each) against
  -- one of its own (FOUND_PRICE), where it has room for one.
  local left = math.max(0, #path - k + 1) * land.size
  if math.ceil(left / STEP) * BUD_PRICE > FOUND_PRICE and found_spot(surface, mine) then
    return found(c, id, surface, mine, tick)
  end
  local from, bd
  for _, rec in ipairs(mine) do
    local d = ((to.x - rec.pos.x) ^ 2 + (to.y - rec.pos.y) ^ 2) ^ 0.5
    if not bd or d < bd then from, bd = rec, d end
  end
  c.wants = BUD_PRICE
  if tick - c.last_bud < BUD_MIN or #mine >= (c.tumors_max or TUMORS_MAX) or (c.growth or 0) < BUD_PRICE then return nil end
  -- Progress along it: the farthest point of the walk its creep has covered. STALL buds without covering more, it is out
  -- of reach.
  c.aim = c.aim or {}
  local key = best.unit_number
  local a = c.aim[key]
  if not a or k > a.k then c.aim[key] = {k = k, n = 0}
  else
    a.n = a.n + 1
    if a.n >= STALL then c.blocked[key], c.aim[key] = true, nil; ctrace(best, string.format("%d buds no nearer (at %d of %d)", STALL, k, #path)) return nil end
  end
  pay(c, tick, BUD_PRICE)
  c.budded = (c.budded or 0) + 1
  -- Not a straight line of tumors (the user: "a little variation in tumor positioning to make it look more organic"):
  -- each bud steps a share of its reach and strays to a side, by a hash of where and when.
  bd = math.max(bd, 1)
  local ux, uy = (to.x - from.pos.x) / bd, (to.y - from.pos.y) / bd
  local h1 = ((from.pos.x * 73856093 + from.pos.y * 19349663 + tick * 83492791) % 1000003) / 1000003
  local h2 = ((from.pos.x * 19349663 + from.pos.y * 83492791 + tick * 73856093) % 1000003) / 1000003
  local step = math.min(R_MAX - 1, bd) * (0.7 + 0.3 * h1)
  local side = (h2 - 0.5) * STRAY * R_MAX
  local at = {x = from.pos.x + ux * step - uy * side, y = from.pos.y + uy * step + ux * side}
  creep.plant(surface, at, id)
  return nil
end

creep.BUD_PRICE = BUD_PRICE
creep.HEDGE = HEDGE

function creep.state()
  local out = {tumors = {}, dying = 0}
  for id, rec in pairs(st().tumors) do
    if rec.dying then out.dying = out.dying + 1
    elseif rec.entity.valid then table.insert(out.tumors, {id = id, pos = rec.pos, r = rec.r, farm = rec.farm}) end
  end
  return out
end

return creep
