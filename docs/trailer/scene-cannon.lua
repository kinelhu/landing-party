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
  -- (The big cannon, 0.2.281: /lp cannon 5 lays them along the deck's south edge, 13 apart, barrels south over the void;
  -- charged full they stand idle, so the platform is filmed after the strike, recharging: coils lit, fans, arcs.)
  dev = {{tick = T + 20, args = {"cannon", "5"}, at = {0, 0}}, {tick = T + 600, args = {"cannon", "fire"}, at = {85, 190}}},
  moves = {
    {name = "battery", tick = T + 60, frames = 240, every = 1, surface = "platform-1",
      from = {pos = {-20, 36}, zoom = 0.32}, to = {pos = {0, 38}, zoom = 0.36}},
    {name = "strike", tick = T + 560, frames = 480, every = 1,
      from = {pos = {85, 190}, zoom = 0.55, daytime = 0.2}, to = {pos = {85, 190}, zoom = 0.62, daytime = 0.2}},
    {name = "recharge", tick = T + 1100, frames = 360, every = 1, surface = "platform-1",
      from = {pos = {-4, 34}, zoom = 0.55}, to = {pos = {-4, 36}, zoom = 0.62}},
  }}
