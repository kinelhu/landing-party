-- A hull's ammunition cooking off (units.lua, COOKOFF; the user, 2026-11-09: "exploding tanks could show the scorcher burn
-- effect from their turret for a short time"): /lp kill lp-tank 3 and lp-prism on LP_MIX=scenes's flak stage, close.
--   scripts/film.sh scenes scenes.zip docs/trailer/cookoff-fx.lua
local T = 11160
return {name = "cookoff-fx", resolution = {1920, 1080}, anti_alias = true, speed = 1, fast_until = T - 60,
  dev = {
    {tick = T + 30, args = {"kill", "lp-tank", "3"}, at = {60, 180}},
    {tick = T + 150, args = {"kill", "lp-prism", "1"}, at = {60, 184}},
  },
  moves = {
    {name = "c1", tick = T, frames = 200, every = 2, from = {pos = {72, 181}, zoom = 2.2, daytime = 0.2}, to = {pos = {72, 181}, zoom = 2.2, daytime = 0.2}},
  },
}
