-- A close still of the Killdozer's charge for the thumbnail's Grubstake panel (the user, 2026-11-09: "an image of the dozer
-- actually charging through the wall? going right to left"): scene-dozers.lua's stage and call, the camera close on the
-- first dozer's lane (its piece at 80.5,-2.5, its rev 10 tiles east), a frame every 2 ticks through its charge (at the
-- wall about tick 11812 in cut 25's take: its clip a frame a tick, played at 30 a second).
--   scripts/film.sh scenes scenes.zip docs/trailer/still-charge.lua
local T = 11160
return {name = "still-charge", resolution = {1920, 1080}, anti_alias = true, speed = 1, fast_until = T - 60, fight = true,
  dev = {{tick = T + 30, args = {"dozers", "2"}, at = {80, 0}}},
  moves = {
    {name = "charge", tick = 11766, frames = 45, every = 2,
      from = {pos = {84, -2.5}, zoom = 2.6, daytime = 0.3}, to = {pos = {84, -2.5}, zoom = 2.6, daytime = 0.3}},
  }}
