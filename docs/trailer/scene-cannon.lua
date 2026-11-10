-- The player's orbital cannons, a first look (0.2.275; the user, 2026-11-10: "Work overnight on the player orbital
-- strike"): on the scenes save (LP_MIX=scenes, scripts/showcase.sh 12345 3), five spawners put on the flak stage's open
-- ground, /lp cannon 8 (a platform over Nauvis, its targeting array, eight cannons charged), the camera across the
-- battery on the platform (its surface, platform-1), then /lp cannon fire on the nests and the strike from orbit.
--   scripts/film.sh scenes scenes.zip docs/trailer/scene-cannon.lua
local T = 11160
local NESTS = {{70, 186}, {80, 190}, {90, 184}, {100, 189}, {85, 196}}
local place = {}
for _, p in ipairs(NESTS) do place[#place + 1] = {tick = T + 10, name = "biter-spawner", pos = p, force = "enemy"} end
return {name = "scene-cannon", resolution = {1920, 1080}, anti_alias = true, speed = 1, fast_until = T - 60, place = place,
  dev = {{tick = T + 20, args = {"cannon", "8"}, at = {0, 0}}, {tick = T + 600, args = {"cannon", "fire"}, at = {85, 190}}},
  moves = {
    {name = "platform", tick = T + 60, frames = 300, every = 1, surface = "platform-1",
      from = {pos = {-12, 26}, zoom = 0.85}, to = {pos = {4, 27}, zoom = 1.0}},
    {name = "strike", tick = T + 560, frames = 480, every = 1,
      from = {pos = {85, 190}, zoom = 0.55, daytime = 0.2}, to = {pos = {85, 190}, zoom = 0.62, daytime = 0.2}},
  }}
