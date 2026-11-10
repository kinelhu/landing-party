-- The strip drill in its four facings (0.2.317: its east, south and west bodies had been empty, its shadow alone drawn),
-- the player's and Grubstake's, and Grubstake's radar beside Kessler-Hayashi's.
--   scripts/film.sh gallery fresh.zip docs/review/stills-drills.lua
local D = {defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west}
local build, shots = {}, {}
for i, d in ipairs(D) do
  build[#build + 1] = {name = "lp-strip-drill", force = "player", pos = {(i - 1) * 7, 0}, dir = d}
  build[#build + 1] = {name = "lp-grubstake-drill", force = "lp-grubstake", pos = {(i - 1) * 7, 8}, dir = d}
end
build[#build + 1] = {name = "lp-radar", force = "lp-serenity", pos = {0, 17}}
build[#build + 1] = {name = "lp-grubstake-radar", force = "lp-grubstake", pos = {7, 17}}
shots[1] = {name = "drills-day", tick = 200, pos = {10.5, 7}, zoom = 1.3, daytime = 0.05}
shots[2] = {name = "drills-night", tick = 204, pos = {10.5, 7}, zoom = 1.3, daytime = 0.5, hide_clouds = true}
return {name = "drills", pad = {-6, -6, 28, 22}, tile = "grass-1", build = build, shots = shots, resolution = {1600, 1200}}
