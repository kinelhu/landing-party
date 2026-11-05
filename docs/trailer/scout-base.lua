-- Scouting grow 12345's base at minute 60 for reel-base.lua (the low pass found open ground): a grid of stills.
--   LP_FILM_SIM=<grow fork's sim dir> scripts/film.sh grow-film fork.zip docs/trailer/scout-base.lua
local shots, k = {}, 0
for gy = -100, 250, 70 do
  for gx = -480, -160, 80 do
    k = k + 1
    shots[#shots + 1] = {name = string.format("%02d_%d_%d", k, gx, gy), tick = 216000 + k * 3, pos = {gx, gy}, zoom = 0.4, daytime = 0.1}
  end
end
return {name = "scout-base", shots = shots, resolution = {1280, 720}}
