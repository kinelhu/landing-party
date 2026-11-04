-- Action for shot 5 (the user, 2026-11-04: "Kind of low on action"): Grubstake's siege on the fortress scenario's laser
-- wall (fortress LP_MIX=grubstake, its fork at minute 14: scripts/film_fork.sh fortress 12345 20 grubstake), timed on
-- its phases: the march, its howitzer truck deploying, the barrage, the assault.
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh fortress-grubstake-film fork.zip docs/trailer/act-grubstake-siege.lua
return {name = "act-grubstake-siege", base = "siege", resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = "phase:march", moves = {
  {name = "g1-march", after = "phase:march", dt = 300, frames = 180, from = {pos = "escort", zoom = 0.7, daytime = 0.2}, to = {off = {0, -6}, daytime = 0.2}},
  {name = "g2-deploy", after = "phase:deploy", dt = 0, frames = 240, every = 3, from = {pos = "escort", zoom = 0.75, daytime = 0.2}, to = {off = {0, 0}, daytime = 0.2}},
  {name = "g3-bombard", after = "phase:bombard", dt = 120, frames = 240, from = {pos = "escort", zoom = 0.55, daytime = 0.2}, to = {off = {0, -8}, daytime = 0.2}},
  {name = "g4-assault", after = "phase:assault", dt = 0, frames = 300, from = {pos = "escort", zoom = 0.65, daytime = 0.2}, to = {off = {0, -10}, daytime = 0.2}},
}}
