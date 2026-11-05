-- The Tesla (the user on cut 4, 2026-11-05: "The Tesla units from KH?"): four of Kessler-Hayashi's Teslas at a line of powered
-- laser turrets, its lightning draining them; heavies LP_MIX=teslas 12345 from its fork at minute 1 (scripts/film_fork.sh heavies 12345 7 teslas; one Tesla alone died to the lasers before its lightning read).
-- The Tesla is set on the lasers at 7200 from 370,-42; the lasers at 366 to 373.5, -23.
--   LP_FILM_SIM=<the fork's sim dir> scripts/film.sh heavies-teslas-film fork.zip docs/trailer/reel-tesla.lua
return {name = "reel-tesla", resolution = {1920, 1080}, anti_alias = true, speed = 8, fast_until = 7150, moves = {
  {name = "t1-tesla", tick = 7200, frames = 600, every = 2, from = {pos = {370, -32}, zoom = 1.6, daytime = 0.3}, to = {pos = {370, -28}, zoom = 1.9, daytime = 0.3}},
}}
