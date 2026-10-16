-- Orbital strike (the player's; the faction loot consult, technology 6: Serenity's orbital beacon taken apart): a beacon
-- the player places on power; charged (CHARGE), it calls Serenity's own barrage (war.lua's orbital shells, as many a
-- target as its health takes) on every nest, worm and corporation building within RADIUS, walls, gates and pylons
-- spared, and burns out. Striking a corporation is an attack: Serenity counts itself provoked.
local shared = require("__landing-party__.shared")

local strike = {}

local RADIUS = 60
local BLOW = 800                  -- what one orbital shell takes off (war.lua ORBITAL_BLOW)
local SPARE = {wall = true, gate = true, ["electric-pole"] = true}

local function hostile(force)
  local out = {"enemy"}
  for _, c in pairs(shared.CORPS) do
    if game.forces[c.force] and not force.get_friend(c.force) then table.insert(out, c.force) end
  end
  return out
end

function strike.placed(ent)
  storage.strikes = storage.strikes or {}
  table.insert(storage.strikes, {entity = ent, placed = game.tick})
end

local function fire(st)
  local e = st.entity
  local s = e.surface
  local c = e.position
  local found = {}
  for _, t in pairs(s.find_entities_filtered{position = c, radius = RADIUS, force = hostile(e.force)}) do
    if t.valid and t.health and t.type ~= "unit" and t.type ~= "spider-unit" and not SPARE[t.type] then
      table.insert(found, t)
    end
  end
  table.sort(found, function(x, y)
    return (x.position.x - c.x) ^ 2 + (x.position.y - c.y) ^ 2 < (y.position.x - c.x) ^ 2 + (y.position.y - c.y) ^ 2
  end)
  local queue = {}
  for _, t in ipairs(found) do
    for _ = 1, math.max(1, math.ceil(t.health / BLOW)) do table.insert(queue, t) end
  end
  storage.orbitals = storage.orbitals or {}
  if #queue > 0 then
    table.insert(storage.orbitals, {surface = s.index, force = e.force.name, queue = queue, i = 1})
  end
  storage.strikes_fired = (storage.strikes_fired or 0) + 1
  storage.strike_targets = (storage.strike_targets or 0) + #found
  e.force.print({"lp.strike", #found, #queue, string.format("[gps=%d,%d,%s]", c.x, c.y, s.name)})
  s.create_entity{name = "big-explosion", position = c}
  e.destroy()
end

function strike.tick(tick)
  if tick % 60 ~= 41 or not storage.strikes then return end
  for i = #storage.strikes, 1, -1 do
    local st = storage.strikes[i]
    if not st.entity.valid then
      table.remove(storage.strikes, i)
    elseif st.entity.energy >= 0.99 * st.entity.electric_buffer_size then
      fire(st)
      table.remove(storage.strikes, i)
    end
  end
end

return strike
