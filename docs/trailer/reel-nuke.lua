-- The war finale's nuke, close and at half speed (the user on cut 9, 2026-11-05: "We don't see the nuke?": the cut began
-- after its flash, and at zoom 0.4 its blast was small). warfinale 12345 from its fork (scripts/film_fork.sh warfinale
-- 12345 7): the rocket fired at 9140, its blast at 9210 on 430,0.
--   LP_FILM_SIM=<the fork's sim dir> scripts/film.sh warfinale-film fork.zip docs/trailer/reel-nuke.lua
return {name = "reel-nuke", resolution = {1920, 1080}, anti_alias = true, speed = 8, fast_until = 9000, moves = {
  {name = "n1-nuke", tick = 9130, frames = 480, every = 1, from = {pos = {428, -2}, zoom = 0.75, daytime = 0.3}, to = {pos = {430, -6}, zoom = 0.5, daytime = 0.3}},
}}
