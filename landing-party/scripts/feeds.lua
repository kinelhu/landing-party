-- What keeps a foe's turrets fighting, and what cutting it would starve: each turret's supply read from the game's own
-- links, no layout assumed and no rule per kind of base (the user: "be wary of hardcoding too much"; the perception
-- consult, docs/reviews/2026-10-27-synthexis-perception-consult.md, section 4: a ring of guns fed by one ammunition belt,
-- and nothing could name the belt). One reader for each medium a turret hangs on:
--   ammunition: the inserters dropping into it (drop_target), what each picks from (pickup_target), and upstream along a
--     belt (belt_neighbours, an underground's other end: underground_belt_neighbour) while the line has one source, BELT_UP belts at most;
--   power: the pole whose loss darkens the most of its lasers (power.cut, Kessler-Hayashi's own reading of a power line).
-- A feed is worth what every way of feeding a turret passes through: one inserter on one belt, the whole line; two from
-- two lines, only what they share; so a base fed from two ends has no cheap cut, and that is its answer.
-- A leaf but for power and threat: it reads the surface only.
local power = require("__landing-party__.scripts.power")
local threat = require("__landing-party__.scripts.threat")

local feeds = {}

feeds.BELT_UP = 80          -- belts walked upstream from an inserter, at most
local BELTS = {["transport-belt"] = true, ["underground-belt"] = true, splitter = true}

-- One way a turret is fed: the inserter, then what it picks from and the belt upstream while it has one source.
local function chain_of(ins)
  local out = {ins}
  local src = ins.pickup_target
  if not (src and src.valid) then return out end
  if not BELTS[src.type] then out[#out + 1] = src; return out end
  local b, seen = src, {}
  for _ = 1, feeds.BELT_UP do
    if not (b and b.valid) or seen[b.unit_number] then break end
    seen[b.unit_number] = true
    out[#out + 1] = b
    local inputs = b.belt_neighbours.inputs
    if #inputs == 0 and b.type == "underground-belt" and b.belt_to_ground_type == "output" then
      local other = b.underground_belt_neighbour
      inputs = other and other.valid and {other} or {}
    end
    if #inputs ~= 1 then break end
    b = inputs[1]
  end
  return out
end

-- The feeds of the turrets of `forces` round `at` (radius): {[unit_number] = {e = entity, starves = turrets, price =
-- what they cost its reader, summed (price(turret): know.price; 1 each without)}}.
function feeds.read(surface, at, radius, forces, price)
  local x, y = at.x or at[1], at.y or at[2]
  local area = {{x - radius, y - radius}, {x + radius, y + radius}}
  local out = {}
  local function add(e, n, p)
    local k = e.unit_number
    if not k then return end
    local f = out[k] or {e = e, starves = 0, price = 0}
    out[k] = f
    f.starves = f.starves + n
    f.price = f.price + p
  end
  local function price_of(t) return price and price(t) or 1 end
  local turrets = surface.find_entities_filtered{area = area, type = threat.FIRE, force = forces}
  -- Ammunition: the inserters dropping into its turrets, read once over the box.
  local into = {}
  for _, ins in ipairs(surface.find_entities_filtered{area = {{area[1][1] - 4, area[1][2] - 4}, {area[2][1] + 4, area[2][2] + 4}},
    type = "inserter", force = forces}) do
    local d = ins.drop_target
    if d and d.valid and d.type == "ammo-turret" then
      into[d.unit_number] = into[d.unit_number] or {}
      table.insert(into[d.unit_number], ins)
    end
  end
  local lasers = {}
  for _, t in ipairs(turrets) do
    if t.type == "ammo-turret" and into[t.unit_number] then
      -- What every way of feeding it passes through.
      local common
      for _, ins in ipairs(into[t.unit_number]) do
        local set = {}
        for _, e in ipairs(chain_of(ins)) do if e.unit_number then set[e.unit_number] = e end end
        if not common then common = set else
          for k in pairs(common) do if not set[k] then common[k] = nil end end
        end
      end
      for _, e in pairs(common or {}) do add(e, 1, price_of(t)) end
    elseif t.type == "electric-turret" then
      lasers[#lasers + 1] = t
    end
  end
  -- Power: the pole whose loss darkens the most of its lasers, per force (power.cut reads one force's lines).
  local by_force = {}
  for _, t in ipairs(lasers) do
    by_force[t.force.name] = by_force[t.force.name] or {}
    table.insert(by_force[t.force.name], t)
  end
  for name, ts in pairs(by_force) do
    local cut = power.cut(surface, game.forces[name], ts, radius)
    if cut and cut.pole and cut.pole.valid and (cut.dark or 0) > 0 then
      local p = 0
      for _, t in ipairs(ts) do p = p + price_of(t) end
      add(cut.pole, cut.dark, cut.dark * p / #ts)
    end
  end
  return out
end

return feeds
