-- Deaths, seen (2026-11-09): fliers shot down tumbling off to a spot near where they died (fall.lua) on the flak stage,
-- then the Prism stage's fight, where tanks die and cook off (units.lua, COOKOFF). LP_MIX=scenes's save.
--   scripts/film.sh scenes scenes.zip docs/trailer/death-fx.lua
local T = 11160
return {name = "death-fx", resolution = {1920, 1080}, anti_alias = true, speed = 1, fast_until = T - 60,
  dev = {
    {tick = T + 30, args = {"flak", "16"}, at = {60, 180}},
    {tick = T + 700, args = {"prism", "2"}, at = {60, 120}},
  },
  moves = {
    {name = "d1-flak", tick = T + 260, frames = 150, every = 2, from = {pos = {76, 176}, zoom = 2.0, daytime = 0.2}, to = {pos = {76, 176}, zoom = 2.0, daytime = 0.2}},
    {name = "d2-prism", tick = T + 760, frames = 450, every = 2, from = {pos = {80, 118}, zoom = 1.4, daytime = 0.2}, to = {pos = {80, 118}, zoom = 1.5, daytime = 0.2}},
  },
}
