-- Action for shot 7 (Synthexis breaks in): the herd scenario's wave (LP_MIX=mega) on its walled ring base, from its fork
-- at minute 1 (scripts/film_fork.sh herd 12345 7 mega). Tracked on the wave's centre as it marches (P.waves), then locked
-- on its breach and inside.
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh herd-mega-film fork.zip docs/trailer/act-herd-mega.lua
return {name = "act-herd-mega", base = 1, waves = true, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = "wave:march", moves = {
  {name = "h1-march", after = "wave:march", dt = 600, frames = 240, track = true, from = {pos = "wave", zoom = 0.6, daytime = 0.3}, to = {daytime = 0.31}},
  {name = "h2-breach", after = "wave:breach", dt = 0, frames = 300, from = {pos = "breach", zoom = 0.7, daytime = 0.32}, to = {off = {0, 0}, daytime = 0.33}},
  {name = "h3-inside", after = "wave:inside", dt = 120, frames = 240, track = true, from = {pos = "wave", zoom = 0.7, daytime = 0.33}, to = {daytime = 0.34}},
}}
