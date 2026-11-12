-- Kessler-Hayashi's arc flamer in motion (0.2.343): the turret alone, waves of medium biters from 60 tiles east every
-- 150 ticks; a 12 s clip at game speed (a frame every 2 ticks at 30 a second), day easing into night so its bolts are
-- seen both ways, the camera pushing in a little.
--   scripts/film.sh arcclip fresh.zip docs/review/clip-arcflamer.lua docs/sim/film-arcclip
--   scripts/clip.sh docs/sim/film-arcclip media/review/arc-flamer.mp4
local waves = 0
local function each(tick)
  if tick < 100 or waves >= 6 or tick < 100 + waves * 150 then return end
  local s = game.surfaces[1]
  -- (The gallery sets every force at peace: this turret and the biters at war again.)
  local kh, en = game.forces.player, game.forces.enemy
  kh.set_cease_fire(en, false); en.set_cease_fire(kh, false)
  kh.set_friend(en, false); en.set_friend(kh, false)
  local t = s.find_entities_filtered{name = "lp-flamer", area = {{-5, 395}, {5, 405}}, limit = 1}[1]
  for i = 0, 5 do
    local b = s.create_entity{name = "medium-biter", position = {50 + (i % 3) * 3, 392 + math.floor(i / 3) * 14}, force = "enemy"}
    if b and t then b.commandable.set_command{type = defines.command.attack, target = t, distraction = defines.distraction.none} end
  end
  waves = waves + 1
end
return {name = "arcclip", pad = {-8, 388, 40, 412}, tile = "grass-1", each = each, resolution = {1920, 1080},
  build = {{name = "lp-flamer", force = "player", pos = {0, 400}}},
  shots = {}, moves = {{name = "arc", tick = 200, frames = 360, every = 2,
    from = {pos = {16, 400}, zoom = 1.0, daytime = 0.05}, to = {pos = {12, 400}, zoom = 1.25, daytime = 0.5}}}}
