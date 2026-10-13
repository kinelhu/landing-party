-- Corporations and biters (docs/campaign.md section 7). Clean by default: settlements emit no pollution, so
-- biters leave them alone unless they meet. When a corporation destroys a spawner, the biters' evolution from
-- spawner kills is given back: corporations clearing nests out of sight must not evolve the biters that attack
-- the player (measured: a corporation's kill raised it by destroy_factor, as a player's does). The component
-- rises by a flat destroy_factor per spawner (measured at 0 and at 0.5: +0.002 each); the refund takes it back
-- a tick later, once per kill.
local shared = require("__landing-party__.shared")

local biters = {}

function biters.on_died(e)
  local ent = e.entity
  if not (ent and ent.valid and ent.type == "unit-spawner") then return end
  if not (e.force and shared.is_corp(e.force.name)) then return end
  storage.evo_refunds = storage.evo_refunds or {}
  local k = ent.surface.index .. ":" .. ent.force.name
  storage.evo_refunds[k] = (storage.evo_refunds[k] or 0) + 1
  storage.nests_cleared = (storage.nests_cleared or 0) + 1
end

function biters.tick()
  if not storage.evo_refunds or next(storage.evo_refunds) == nil then return end
  local d = game.map_settings.enemy_evolution.destroy_factor
  for k, n in pairs(storage.evo_refunds) do
    local si, fname = k:match("^(%d+):(.+)$")
    local surface, force = game.surfaces[tonumber(si)], game.forces[fname]
    if surface and force then
      local v = force.get_evolution_factor_by_killing_spawners(surface)
      v = math.max(0, v - n * d)
      force.set_evolution_factor_by_killing_spawners(v, surface)
    end
  end
  storage.evo_refunds = {}
end

return biters
