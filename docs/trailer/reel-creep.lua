-- Synthexis at home (the user on cut 7, 2026-11-05: "a shot of technicians feeding incubators and creep spreading"):
-- farm 12345's young culture from minute 10 (scripts/film_fork.sh farm 12345 16; scouted, scout-young.lua: its
-- incubators round 1000,-4, its clinic by 1004,27). Close on its cells and technicians, then its creep over five
-- minutes, a frame a second.
--   LP_FILM_SIM=<the fork's sim dir> scripts/film.sh farm-film fork.zip docs/trailer/reel-creep.lua
return {name = "reel-creep", resolution = {1920, 1080}, anti_alias = true, speed = 8, moves = {
  {name = "t1-cells", tick = 36100, frames = 300, every = 2, from = {pos = {992, -10}, zoom = 1.6, daytime = 0.15}, to = {pos = {1004, -6}, zoom = 1.5, daytime = 0.15}},
  {name = "t2-creep", tick = 36800, frames = 300, every = 60, from = {pos = {1000, 2}, zoom = 0.7, daytime = 0.15}, to = {pos = {1000, 2}, zoom = 0.6, daytime = 0.15}},
}}
