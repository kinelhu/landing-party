-- Roads (the user, 2026-10-18: "player constructed concrete surfaces that speed up army traversal"). Units walk at one
-- speed on any floor (the engine lends the floor's bonus to the engineer only), so twice a second each of the player's
-- army units standing on a floor that speeds the engineer (stone path 1.3, concrete 1.4, refined concrete 1.5) is given
-- the matching sticker (player.lua, lp-road-13/14/15), lasting 45 ticks: off the road, the bonus ends within a step.
-- A leaf: it reads the player's army (storage.cmd) and the floor.
local roads = {}

local EVERY = 30
local STICKERS = {[13] = "lp-road-13", [14] = "lp-road-14", [15] = "lp-road-15"}

local function sticker_for(surface, pos)
  local m = surface.get_tile(pos.x, pos.y).prototype.walking_speed_modifier or 1
  if m < 1.25 then return nil end
  return STICKERS[math.max(13, math.min(15, math.floor(m * 10 + 0.5)))]
end

function roads.tick(tick)
  if tick % EVERY ~= 11 or not (storage.cmd and storage.cmd.troopers) then return end
  for _, t in pairs(storage.cmd.troopers) do
    local u = t.unit
    if u and u.valid then
      local name = sticker_for(u.surface, u.position)
      if name then u.surface.create_entity{name = name, position = u.position, target = u} end
    end
  end
end

return roads
