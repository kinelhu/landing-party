-- Action for shot 7: Synthexis's wave breaking into the farm siege scenario's wall (farm LP_MIX=siege, its fork at
-- minute 35): breach at 241,44 at tick 131166 (the same tick in three replays of the fork).
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh farm-film fork.zip docs/trailer/act-synthexis-breach.lua
return {name = "act-synthexis-breach", base = 1, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = 130700, moves = {
  {name = "b1", tick = 130800, frames = 360, from = {pos = {250, 40}, zoom = 0.7, daytime = 0.33}, to = {pos = {246, 36}, zoom = 0.75, daytime = 0.35}},
}}
