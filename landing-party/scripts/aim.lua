-- Ground-only units look for a target they can hurt (the user, 2026-10-21, on air.lua's limit: "This will be very
-- problematic in mixed arms encounters?"). The engine lets a unit aim at any enemy in range, a flier included, and a
-- ground-only weapon's shot then does nothing: one harrier over a tank column would soak all its fire. Every such
-- weapon carries a script trigger that fires when its shot is aimed at a flier (air.lua); the shooter is then given a
-- distraction command, which the engine runs before going back to its own command: attack the nearest enemy it can
-- hurt within sight, units and turrets first, as an attack-move would; with none, stand down a moment without engaging
-- rather than fire at the sky. (Within its range + 8 only, fliers that outran their own ground army left it standing
-- down while they shot it: arena mixes, 2026-10-21.)
local aim = {}

local EFFECT = "lp-ground-at-air"
local SIGHT = 40                -- tiles it looks for a ground target (an army's attack_area radius)
local HOLD = 90                 -- ticks it stands down when nothing on the ground is in reach
local AGAIN = 30                -- ticks before the same unit is redirected again

local MILITARY = {"unit", "spider-unit", "character", "car", "spider-vehicle", "ammo-turret", "electric-turret",
  "fluid-turret", "artillery-turret", "turret", "unit-spawner"}

local air_names = {}
local function is_air(e)
  local v = air_names[e.name]
  if v == nil then
    v = e.prototype.collision_mask.layers["lp-air"] == true
    air_names[e.name] = v
  end
  return v
end

local function enemies_of(force)
  local out = {}
  for _, f in pairs(game.forces) do
    if f ~= force and force.is_enemy(f) then table.insert(out, f) end
  end
  return out
end

local function nearest(u, list)
  local best, bd
  local p = u.position
  for _, t in pairs(list) do
    if t.valid and t.destructible and t.is_entity_with_health and not is_air(t) then
      local dx, dy = t.position.x - p.x, t.position.y - p.y
      local d = dx * dx + dy * dy
      if not bd or d < bd then best, bd = t, d end
    end
  end
  return best
end

function aim.on_trigger(e)
  if e.effect_id ~= EFFECT then return end
  local u = e.cause_entity or e.source_entity
  if not (u and u.valid and u.commandable) then return end
  storage.aim_redirected = storage.aim_redirected or {}
  local last = storage.aim_redirected[u.unit_number]
  if last and game.tick - last < AGAIN then return end
  storage.aim_redirected[u.unit_number] = game.tick
  local radius = SIGHT
  local forces = enemies_of(u.force)
  if #forces == 0 then return end
  local s = u.surface
  local t = nearest(u, s.find_entities_filtered{position = u.position, radius = radius, force = forces, type = MILITARY})
    or nearest(u, s.find_entities_filtered{position = u.position, radius = radius, force = forces})
  if t then
    u.commandable.set_distraction_command{type = defines.command.attack, target = t, distraction = defines.distraction.none}
  else
    u.commandable.set_distraction_command{type = defines.command.stop, ticks_to_wait = HOLD,
      distraction = defines.distraction.none}
  end
end

-- Forget units long gone (called now and then).
function aim.sweep()
  if not storage.aim_redirected then return end
  local now = game.tick
  for k, t in pairs(storage.aim_redirected) do
    if now - t > 600 then storage.aim_redirected[k] = nil end
  end
end

return aim
