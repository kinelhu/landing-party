-- The dome stopping a volley from every side (the user on cut 5, 2026-11-05): dome LP_MIX=ring 12345, six of the player's
-- artillery turrets set round Kessler-Hayashi's camp 100 tiles out at 7200 (its lander at -343,-3), its dome catching
-- their 60 shells; from its fork at minute 2 (scripts/film_fork.sh dome 12345 8 ring).
--   LP_FILM_SIM=<the fork's sim dir> scripts/film.sh dome-ring-film fork.zip docs/trailer/reel-dome.lua
return {name = "reel-dome", resolution = {1920, 1080}, anti_alias = true, speed = 8, fast_until = 7150, moves = {
  {name = "d1-volley", tick = 7220, frames = 900, every = 2, from = {pos = {-354, -6}, zoom = 0.45, daytime = 0.3}, to = {pos = {-354, -6}, zoom = 0.52, daytime = 0.31}},
}}
