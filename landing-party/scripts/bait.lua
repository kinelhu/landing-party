-- Pheromone bait (the player's; the faction loot consult, technology 1: Grubstake's gland taken apart): a canister the
-- player places; the idle biters round it are called to attack whatever they meet there, as Grubstake's flare calls them
-- (flare.call). Grubstake's pact keeps them off Grubstake: it is the player's way to set the biters on Serenity, or on a
-- Grubstake camp once its pact is broken. It burns BURN, then the biters lose interest; destroyed, at once.
local flare = require("__landing-party__.scripts.flare")

local bait = {}

local BURN = 3 * 3600

function bait.placed(ent)
  storage.baits = storage.baits or {}
  local group, k = flare.call(ent.surface, ent.position)
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
