-- Action for shot 7 (Synthexis breaks in): the herd scenario's wave (LP_MIX=ranks-mend: the ranks siege; its outer ring rebuilt as robots would as it rushes, a way round opened 22 tiles along; 0.2.215 keeps its gap's line) on its walled ring base, from its fork
-- at minute 1 (scripts/film_fork.sh herd 12345 7 ranks-mend). Tracked on the wave's centre as it marches (P.waves), then locked
-- on its breach and inside.
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh herd-ranks-mend-film fork.zip docs/trailer/act-herd-burst.lua
return {name = "reel-mend", base = 1, waves = true, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = "wave:march", moves = {
  {name = "h1-march", after = "wave:march", dt = 600, frames = 150, track = true, from = {pos = "wave", zoom = 0.8, daytime = 0.2}, to = {daytime = 0.31}},
  -- (The breach point framed alone missed the herd at the frame's corner, 2026-11-05: followed instead, close.)
  {name = "h2-breach", after = "wave:breach", dt = 0, frames = 900, every = 2, track = true, from = {pos = "wave", zoom = 1.0, daytime = 0.2}, to = {daytime = 0.2}},
}}
