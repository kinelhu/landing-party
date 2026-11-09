-- reel-scenes.lua's dozer siege alone, filmed again for cut 24 (the user, 2026-11-09, of cut 23: "the dozer scene is a
-- little underwhelming ... dozers derping around their broken walls and buggies spazzing out at the back"): one strip
-- widened a dozer, not six; its buggies held behind its breach; sparks at the blade, a burst where a piece gives way; the
-- east wall's turrets with fifty rounds; at dusk, closer. Its save rebuilt (LP_MIX=scenes scripts/showcase.sh 12345 3).
--   scripts/film.sh scenes scenes.zip docs/trailer/scene-dozers.lua
local T = 11160
return {name = "scene-dozers", resolution = {1920, 1080}, anti_alias = true, speed = 1, fast_until = T - 60, fight = true,
  dev = {{tick = T + 30, args = {"dozers", "2"}, at = {80, 0}}},
  moves = {
    -- (From the call, the first take spent 15 s on the labs inside while the dozers drove 45 tiles in: from their
    -- approach to the wall, through the breach and the buggies' rush.)
    {name = "sc1-dozers", tick = 11900, frames = 1620, every = 1, track = true,
      from = {pos = "fight", zoom = 1.3, daytime = 0.3}, to = {zoom = 1.5, daytime = 0.3}},
  }}
