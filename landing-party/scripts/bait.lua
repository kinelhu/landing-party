-- Pheromone bait (the player's; the faction loot consult, technology 1: Grubstake's gland taken apart): a canister the
-- player places; the idle biters round it are called to attack whatever they meet there, as Grubstake's pheromone flare once called
-- them. Grubstake's pact keeps them off Grubstake: it is the player's way to set the biters on Serenity, or on a
-- Grubstake camp once its pact is broken. It burns BURN, then the biters lose interest; destroyed, at once.
local bait = {}

local BURN = 3 * 3600
local PULL_RADIUS = 400           -- idle biters this near the canister answer it, the nearest first (150 called none
                                  -- round a cleared deathworld base: its nests were 250 to 400 tiles out)
local PULL_BASE, PULL_EVO = 12, 24  -- 12 + 24 x evolution of them
local AREA = 30                   -- the group attacks what it meets this near the canister

-- The idle biters (in no group) within PULL_RADIUS of `at`, the nearest 12 + 24 x evolution, as one group told to attack
-- whatever it meets within AREA of it (no nest spawns for the player). Returns the group (nil: none) and how many.
-- (It was Grubstake's pheromone flare's call until the flare was retired, 2026-10-22.)
local function call(s, at)
  local evo = game.forces.enemy.get_evolution_factor(s)
  local n = math.floor(PULL_BASE + PULL_EVO * evo)
  local found = {}
  for _, u in pairs(s.find_entities_filtered{type = "unit", force = "enemy", position = at, radius = PULL_RADIUS}) do
    if not u.commandable.parent_group then
      table.insert(found, {u, (u.position.x - at.x) ^ 2 + (u.position.y - at.y) ^ 2})
    end
  end
  table.sort(found, function(x, y) return x[2] < y[2] end)
  if #found == 0 then return nil, 0 end
  local group = s.create_unit_group{position = found[1][1].position, force = "enemy"}
  local k = 0
  for i = 1, math.min(n, #found) do group.add_member(found[i][1]); k = k + 1 end
  group.set_command{type = defines.command.attack_area, destination = at, radius = AREA,
    distraction = defines.distraction.by_enemy}
  return group, k
end

function bait.placed(ent)
  storage.baits = storage.baits or {}
  local group, k = call(ent.surface, ent.position)
  table.insert(storage.baits, {entity = ent, at = {x = ent.position.x, y = ent.position.y}, surface = ent.surface.index,
    lit = game.tick, group = group, called = k})
  storage.baits_called = (storage.baits_called or 0) + k
end

function bait.tick(tick)
  if tick % 30 ~= 11 or not storage.baits then return end
  for i = #storage.baits, 1, -1 do
    local b = storage.baits[i]
    if not b.entity.valid or tick - b.lit > BURN then
      if b.group and b.group.valid then
        b.group.set_command{type = defines.command.wander, radius = 10, distraction = defines.distraction.by_enemy}
      end
      if b.entity.valid then b.entity.destroy() end
      table.remove(storage.baits, i)
    else
      game.surfaces[b.surface].create_trivial_smoke{name = "lp-flare-smoke", position = b.at}
    end
  end
end

return bait
