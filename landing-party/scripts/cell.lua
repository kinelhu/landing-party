-- Synthexis's cells (the identity consult, docs/reviews/2026-10-22-synthexis-identity-consult.md, step 2; the user,
-- 2026-10-22: no "faction identity beside a small sprite on the captured nest"): beside each incubator a PAD of
-- acid-green refined concrete, a biochamber at work on it (biotech.lua: no power, no nutrients, its animation and light
-- the tell that the incubator is fed) and a lamp in its colour. Laid out of the culture's middle, past the incubator,
-- so the worms (on the other diagonal) and the herd's gate keep their ground. Its pad is a floor, not creep: the creep
-- grows round it (mineable tiles are skipped, creep.lua).
local shared = require("__landing-party__.shared")

local cell = {}

local B = shared.BIOTECH
local OUT = 7          -- tiles from the incubator, away from the culture's middle
local PAD = 2          -- the pad's half size (5x5)
local FLOOR = "acid-refined-concrete"

local function st()
  storage.cells = storage.cells or {}
  return storage.cells
end

-- The incubator pen (an entity) of pen id `id`, in farm `farm_id` whose middle is `mid`.
function cell.build(id, pen, farm_id, mid)
  if st()[id] or not (pen and pen.valid) then return st()[id] end
  local s, p = pen.surface, pen.position
  local dx, dy = p.x - mid.x, p.y - mid.y
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1 then dx, dy, len = -1, 0, 1 end
  local c = {x = math.floor(p.x + dx / len * OUT) + 0.5, y = math.floor(p.y + dy / len * OUT) + 0.5}
  local area = {{c.x - PAD - 0.5, c.y - PAD - 0.5}, {c.x + PAD + 0.5, c.y + PAD + 0.5}}
  -- Trees, rocks and remains off the pad.
  for _, e in pairs(s.find_entities_filtered{area = area, type = {"tree", "simple-entity", "corpse"}}) do
    if e.valid then e.destroy() end
  end
  local tiles, under = {}, {}
  for x = c.x - PAD - 0.5, c.x + PAD - 0.5 do
    for y = c.y - PAD - 0.5, c.y + PAD - 0.5 do
      local t = s.get_tile(x, y)
      if not t.collides_with("water_tile") then
        -- What lies under creep stays the ground under the pad.
        under[#under + 1] = {x, y, t.hidden_tile or t.name}
        tiles[#tiles + 1] = {name = FLOOR, position = {x, y}}
      end
    end
  end
  s.set_tiles(tiles, true, false)
  for _, u in ipairs(under) do
    if u[3] ~= FLOOR then s.set_hidden_tile({u[1], u[2]}, u[3]) end
  end
  local chamber = s.create_entity{name = "lp-biochamber", position = c, force = B.force, raise_built = false}
  local lamp = s.create_entity{name = "lp-cell-lamp", position = {c.x + PAD, c.y + PAD}, force = B.force}
  st()[id] = {chamber = chamber, lamp = lamp, farm = farm_id, at = c, fed_until = game.tick + 5 * 60 * 60}
  return st()[id]
end

function cell.of(id) return st()[id] end

-- An incubator gone wild or dead: its cell's machines go (the pad stays, a floor).
function cell.forget(id)
  local c = st()[id]
  if not c then return end
  for _, e in ipairs({c.chamber, c.lamp}) do if e and e.valid then e.destroy() end end
  st()[id] = nil
end

-- The substrate and its technicians (the identity consult, step 4). A culture's substrate: Gleba soil in a blot SOIL
-- round its heating tower (a lit prop) near its middle, yumako trees and jellystems on it. Its technicians (TECHS, more
-- with more incubators) walk from the tower to each biochamber in turn and wait there a while: each visit feeds that
-- biochamber FEED_LAST. A biochamber unvisited longer stops (inactive: its animation and light go), and its incubator is
-- unfed as if it were dead (farm.lua), back at work at the next visit. Every technician dead, a pod brings TECHS more
-- after DROP_WAIT: the reprieve, not a defence.
local SOIL = 5
local TECHS, TECHS_PER = 2, 4        -- two, and one more for every TECHS_PER incubators
local FEED_LAST = 5 * 60 * 60
local WAIT = 12 * 60                 -- at a biochamber (longer than the farm's 10-second look)
local DROP_WAIT = 10 * 60 * 60
local PLANTS = {"yumako-tree", "jellystem"}
local pods = require("__landing-party__.scripts.pods")

local function sites()
  storage.cell_sites = storage.cell_sites or {}
  return storage.cell_sites
end

local function spawn_techs(site, surface, n)
  local t = site.tower
  local at = t and t.valid and t.position or site.at
  for _ = 1, n do
    local q = surface.find_non_colliding_position("lp-technician", at, 10, 0.5)
    local u = q and surface.create_entity{name = "lp-technician", position = q, force = B.force}
    if u then table.insert(site.techs, {unit = u}) end
  end
end

pods.handlers["biotech-techs"] = function(payload, surface, position)
  local site = sites()[payload.farm]
  if site then
    site.drop_at = nil
    spawn_techs(site, surface, payload.n or TECHS)
  end
end

-- A culture's substrate, built once when it lands (or at its first look, in an older save).
function cell.site(farm_id, surface, mid)
  local site = sites()[farm_id]
  if site then return site end
  -- Clear of nests and worms by its blot and a margin: laid on an incubator, its soil took the creep from under it and
  -- the incubator starved and went wild, again and again (the first run).
  local p
  for r = 10, 40, 5 do
    for k = 0, 11 do
      local a = 2 * math.pi * k / 12
      local q = {x = mid.x + math.cos(a) * r, y = mid.y + math.sin(a) * r}
      if not p and surface.count_entities_filtered{position = q, radius = SOIL + 5, type = {"unit-spawner", "turret"}, limit = 1} == 0
        and surface.count_entities_filtered{position = q, radius = SOIL + 5, name = "lp-biochamber", limit = 1} == 0
        and surface.can_place_entity{name = "lp-heating-tower", position = q} then
        p = q
      end
    end
  end
  p = p or surface.find_non_colliding_position("lp-heating-tower", {mid.x, mid.y}, 30, 1) or {x = mid.x, y = mid.y}
  local c = {x = math.floor(p.x) + 0.5, y = math.floor(p.y) + 0.5}
  local tiles, under = {}, {}
  for dx = -SOIL, SOIL do
    for dy = -SOIL, SOIL do
      if dx * dx + dy * dy <= SOIL * SOIL + 2 then
        local x, y = math.floor(c.x) + dx, math.floor(c.y) + dy
        local t = surface.get_tile(x, y)
        if not t.collides_with("water_tile") then
          under[#under + 1] = {x, y, t.hidden_tile or t.name}
          tiles[#tiles + 1] = {name = "artificial-yumako-soil", position = {x, y}}
        end
      end
    end
  end
  surface.set_tiles(tiles, true, false)
  for _, u in ipairs(under) do
    if u[3] ~= "artificial-yumako-soil" then surface.set_hidden_tile({u[1], u[2]}, u[3]) end
  end
  local tower = surface.create_entity{name = "lp-heating-tower", position = c, force = B.force}
  site = {at = c, tower = tower, techs = {}, plants = {}}
  for k = 1, 8 do
    local a = 2 * math.pi * k / 8
    local q = surface.find_non_colliding_position(PLANTS[k % 2 + 1], {c.x + math.cos(a) * 3.5, c.y + math.sin(a) * 3.5}, 2, 0.5)
    local e = q and surface.create_entity{name = PLANTS[k % 2 + 1], position = q, force = "neutral"}
    if e then table.insert(site.plants, e) end
  end
  sites()[farm_id] = site
  spawn_techs(site, surface, TECHS)
  return site
end

-- Hungry: unvisited for FEED_LAST (never set: fed from its building, see cell.build).
function cell.hungry(c, tick) return c.fed_until ~= nil and tick > c.fed_until end

-- Every 10 seconds (farm.tick): the technicians' rounds, the biochambers' feed, a drop when every technician is dead.
function cell.tick(farm_id, surface, pen_ids, tick)
  local site = sites()[farm_id]
  if not site then return end
  local live = {}
  for _, t in ipairs(site.techs) do if t.unit.valid then table.insert(live, t) end end
  site.techs = live
  local want = TECHS + math.floor(#pen_ids / TECHS_PER)
  if #live == 0 and not site.drop_at then
    site.drop_at = tick + DROP_WAIT
  elseif site.drop_at and tick >= site.drop_at and not site.dropping then
    site.dropping = true
    local at = site.tower and site.tower.valid and site.tower.position or site.at
    if not pods.send(surface, {at.x + 4, at.y + 4}, B.force, {kind = "biotech-techs", farm = farm_id, n = TECHS}) then
      site.drop_at = nil
      spawn_techs(site, surface, TECHS)
    end
  end
  if #site.techs > 0 then site.dropping = nil end
  -- The cells of this culture with a biochamber standing.
  local cs = {}
  for _, id in ipairs(pen_ids) do
    local c = st()[id]
    if c and c.chamber and c.chamber.valid then table.insert(cs, c) end
  end
  for _, t in ipairs(site.techs) do
    local u = t.unit
    -- At its biochamber: fed.
    if t.to and t.to.chamber and t.to.chamber.valid then
      local q = t.to.chamber.position
      if (u.position.x - q.x) ^ 2 + (u.position.y - q.y) ^ 2 < 5 * 5 then t.to.fed_until = tick + FEED_LAST end
    end
    -- Not on a round (a unit made by script wanders, which counts as a command): sent to the next biochamber.
    local cmd = u.commandable.command
    if (not cmd or cmd.type ~= defines.command.compound) and #cs > 0 then
      site.next = (site.next or 0) % #cs + 1
      local c = cs[site.next]
      t.to = c
      local home = site.tower and site.tower.valid and site.tower.position or site.at
      -- To the pad's edge on the tower's side (the biochamber's middle is inside it: no path ends there).
      local q = c.chamber.position
      local dx, dy = home.x - q.x, home.y - q.y
      local len = math.max(1, math.sqrt(dx * dx + dy * dy))
      local stand = {q.x + dx / len * 3, q.y + dy / len * 3}
      u.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = {
          {type = defines.command.go_to_location, destination = stand, radius = 1.5, distraction = defines.distraction.none},
          {type = defines.command.stop, ticks_to_wait = WAIT, distraction = defines.distraction.none},
          {type = defines.command.go_to_location, destination = home, radius = 4, distraction = defines.distraction.none},
          {type = defines.command.stop, ticks_to_wait = 120, distraction = defines.distraction.none}}}
    end
  end
  -- Fed or not: a hungry biochamber stops.
  for _, c in ipairs(cs) do
    local on = not cell.hungry(c, tick)
    if c.chamber.disabled_by_script == on then c.chamber.disabled_by_script = not on end
    if c.lamp and c.lamp.valid and c.lamp.disabled_by_script == on then c.lamp.disabled_by_script = not on end
  end
  if #site.techs < want and not site.drop_at and tick - (site.staffed or 0) > DROP_WAIT then
    -- Grown (more incubators): one more technician walks out of the tower.
    site.staffed = tick
    spawn_techs(site, surface, 1)
  end
end

-- A culture gone: its technicians with it; its substrate stays (the trophy, step 6).
function cell.forget_site(farm_id)
  local site = sites()[farm_id]
  if not site then return end
  for _, t in ipairs(site.techs) do if t.unit.valid then t.unit.destroy() end end
  sites()[farm_id] = nil
end

function cell.sites()
  local out = {}
  for id, site in pairs(sites()) do
    local n, walks = 0, {}
    for _, t in ipairs(site.techs) do
      if t.unit.valid then
        n = n + 1
        local q = t.to and t.to.chamber and t.to.chamber.valid and t.to.chamber.position
        walks[#walks + 1] = {pos = {math.floor(t.unit.position.x), math.floor(t.unit.position.y)},
          to = q and {math.floor(q.x), math.floor(q.y)}, busy = t.unit.commandable.has_command,
          cmd = t.unit.commandable.command and t.unit.commandable.command.type}
      end
    end
    out[#out + 1] = {farm = id, at = {site.at.x, site.at.y}, tower = site.tower and site.tower.valid or false, techs = n,
      plants = #site.plants, drop_at = site.drop_at, walks = walks}
  end
  return out
end

function cell.state()
  local out = {}
  for id, c in pairs(st()) do
    out[#out + 1] = {id = id, farm = c.farm, chamber = c.chamber and c.chamber.valid or false,
      working = c.chamber and c.chamber.valid and c.chamber.status == defines.entity_status.working or false,
      lamp = c.lamp and c.lamp.valid or false, at = {c.at.x, c.at.y}, fed_until = c.fed_until}
  end
  return out
end

return cell
