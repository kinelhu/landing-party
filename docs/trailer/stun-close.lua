-- The lightning's stun, close (the user, 2026-11-09: "a visual indicator of tesla-borne stuns would be nice to have
-- (electrical currents flowing all over the unit?)"): on LP_MIX=scenes's Prism stage (60,120, its troopers), three
-- Teslas from /lp tesla at them, a fixed framing between the two; and /lp chartcheck before and after, to read whether
-- the player's units chart the ground round them in a game (a benchmark run charts nothing).
--   scripts/film.sh scenes scenes.zip docs/trailer/stun-close.lua
local T = 11160
return {name = "stun-close", resolution = {1920, 1080}, anti_alias = true, speed = 1, fast_until = T - 60,
  dev = {
    {tick = T, args = {"chartcheck"}, at = {60, 120}},
    {tick = T + 30, args = {"tesla", "3"}, at = {60, 120}},
    {tick = T + 1700, args = {"chartcheck"}, at = {60, 120}},
  },
  moves = {
    {name = "st1-close", tick = T + 60, frames = 900, every = 2,
      from = {pos = {70, 120}, zoom = 1.6, daytime = 0.2}, to = {pos = {68, 120}, zoom = 1.8, daytime = 0.2}},
  },
}
