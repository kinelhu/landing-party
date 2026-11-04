-- The barracks at work on four grounds, by day, and at night. scripts/film.sh gallery fresh.zip docs/review/stills-barracks.lua
local G = {"refined-concrete", "grass-1", "sand-1", "dirt-4"}
local build, shots = {}, {}
for j, g in ipairs(G) do
  local pos = {(j - 1) * 14, 0}
  build[#build + 1] = {name = "lp-barracks", force = "player", pos = pos, ground = g}
  shots[#shots + 1] = {name = string.format("06-pl-barracks-%d-%s", j, g), tick = 300 + j * 5, pos = {pos[1], pos[2] - 1.5}, zoom = 3, daytime = 0.05}
end
shots[#shots + 1] = {name = "06-pl-barracks-night", tick = 340, pos = {14, -1.5}, zoom = 3, daytime = 0.5, hide_clouds = true}
shots[#shots + 1] = {name = "06-pl-barracks-night-b", tick = 353, pos = {14, -1.5}, zoom = 3, daytime = 0.5, hide_clouds = true}
return {name = "barracks", pad = {-8, -8, 50, 8}, tile = "grass-1", build = build, shots = shots, resolution = {1280, 720}}
