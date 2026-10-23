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
  st()[id] = {chamber = chamber, lamp = lamp, farm = farm_id, at = c}
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

function cell.state()
  local out = {}
  for id, c in pairs(st()) do
    out[#out + 1] = {id = id, farm = c.farm, chamber = c.chamber and c.chamber.valid or false,
      working = c.chamber and c.chamber.valid and c.chamber.status == defines.entity_status.working or false,
      lamp = c.lamp and c.lamp.valid or false, at = {c.at.x, c.at.y}}
  end
  return out
end

return cell
