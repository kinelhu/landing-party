-- Deaths, the second look (2026-11-09): five tanks cooking off, each wreck its own mix (units.lua, COOKOFF); Grubstake's
-- Scorcher going up (its fuel); three of its bomb drones shot down, each bursting where it lands (fall.lua). /lp kill on
-- LP_MIX=scenes's flak stage, close.
--   scripts/film.sh scenes scenes.zip docs/trailer/deaths2-fx.lua
local T = 11160
return {name = "deaths2-fx", resolution = {1920, 1080}, anti_alias = true, speed = 1, fast_until = T - 60,
  dev = {
    {tick = T + 30, args = {"kill", "lp-tank", "5"}, at = {56, 180}},
    {tick = T + 400, args = {"kill", "lp-grubstake-scorcher", "1"}, at = {62, 186}},
    {tick = T + 700, args = {"kill", "lp-grubstake-scavenger", "3"}, at = {60, 175}},
  },
  moves = {
    {name = "e1-tanks", tick = T, frames = 180, every = 2, from = {pos = {70, 180}, zoom = 1.9, daytime = 0.2}, to = {pos = {70, 180}, zoom = 1.9, daytime = 0.2}},
    {name = "e2-scorcher", tick = T + 380, frames = 150, every = 2, from = {pos = {71, 186}, zoom = 2.0, daytime = 0.2}, to = {pos = {71, 186}, zoom = 2.0, daytime = 0.2}},
    {name = "e3-bombs", tick = T + 680, frames = 120, every = 2, from = {pos = {71, 175}, zoom = 1.8, daytime = 0.2}, to = {pos = {71, 175}, zoom = 1.8, daytime = 0.2}},
  },
}
