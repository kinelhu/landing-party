-- Scouting farm 12345's young culture at minute 10 (scripts/film_fork.sh farm 12345 16) for reel-creep.lua: a grid of
-- stills round its field at 1000,0.
local shots, k = {}, 0
for gy = -60, 60, 40 do
  for gx = 930, 1070, 70 do
    k = k + 1
    shots[#shots + 1] = {name = string.format("%02d_%d_%d", k, gx, gy), tick = 36000 + k * 3, pos = {gx, gy}, zoom = 0.8, daytime = 0.1}
  end
end
return {name = "scout-young", shots = shots, resolution = {1280, 720}}
