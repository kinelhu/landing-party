-- Scouting farm bigpens 12345's culture at minute 84 (its fork, scripts/film_fork.sh farm 12345 90 bigpens) for the
-- player's strike (reel-culture.lua): a grid of stills round its pod at 1000,0.
local shots, k = {}, 0
for gy = -120, 120, 60 do
  for gx = 880, 1120, 80 do
    k = k + 1
    shots[#shots + 1] = {name = string.format("%02d_%d_%d", k, gx, gy), tick = 302400 + k * 3, pos = {gx, gy}, zoom = 0.5, daytime = 0.1}
  end
end
return {name = "scout-culture", shots = shots, resolution = {1280, 720}}
