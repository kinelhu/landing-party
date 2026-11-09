-- Fliers shot down falling (scripts/fall.lua; the user, 2026-11-09: "could we make fliers spin out and fall to the
-- ground"): /lp flak on LP_MIX=scenes's flak stage (60,180), framed as the trailer's sc4, closer.
--   scripts/film.sh scenes scenes.zip docs/trailer/fall-fx.lua
local T = 11160
return {name = "fall-fx", resolution = {1920, 1080}, anti_alias = true, speed = 1, fast_until = T - 60,
  dev = {
    {tick = T + 30, args = {"flak", "16"}, at = {60, 180}},
  },
  moves = {
    {name = "ff1", tick = T + 60, frames = 600, every = 2, from = {pos = {70, 178}, zoom = 1.3, daytime = 0.2}, to = {pos = {70, 178}, zoom = 1.4, daytime = 0.2}},
  },
}
