-- Achievements granted (achievements.lua: the prototypes): each to every player of the force whose deed it was. A leaf.
local shared = require("__landing-party__.shared")

local achievements = {}

local function grant(name, force)
  if not (force and force.valid and shared.is_player_force(force)) then return end
  -- (Recorded too: a headless test has no player to receive it.)
  storage.lp_achieved = storage.lp_achieved or {}
  storage.lp_achieved[name] = (storage.lp_achieved[name] or 0) + 1
  for _, p in pairs(force.players) do p.unlock_achievement(name) end
end
achievements.grant = grant

-- A corporation's uplink destroyed (control.lua, its death): Grubstake's withdraws it, Kessler-Hayashi's is its link home.
function achievements.uplink(entity, force)
  local kind = shared.kind_of(entity.name)
  if kind ~= "lp-uplink" then return end
  grant(entity.force.name == shared.CORPS.grubstake.force and "lp-claim-jumped" or "lp-uplink-down", force)
end

-- A strike called off, its spotter killed during the paint (orbital.lua): to every player force at war with it.
function achievements.spotter(corp_force)
  for _, f in pairs(game.forces) do
    if shared.is_player_force(f) and not f.get_cease_fire(corp_force) then grant("lp-eyes-first", f) end
  end
end
achievements.siege_broken = function(corp_force)
  for _, f in pairs(game.forces) do
    if shared.is_player_force(f) and not f.get_cease_fire(corp_force) then grant("lp-siege-broken", f) end
  end
end

return achievements
