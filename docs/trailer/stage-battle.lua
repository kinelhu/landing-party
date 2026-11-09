-- The army's battle at the Grubstake camp (stage.lua's m3-battle and m4-battle) filmed again on Grubstake's redrawn
-- units (the user, 2026-11-09: "we don't have enough high action footage"), from the same fork of the trailer scenario.
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh trailer-film fork.zip docs/trailer/stage-battle.lua
return {name = "stage-battle", base = 1, army = true, waves = true, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = 41200, moves = {
  {name = "m3-battle", tick = 41400, frames = 240, from = {pos = {392, -158}, zoom = 0.75, daytime = 0.22}, to = {pos = {396, -158}, zoom = 0.8, daytime = 0.22}},
  {name = "m4-battle", tick = 42600, frames = 240, track = true, from = {pos = "army", zoom = 0.9, daytime = 0.22}, to = {daytime = 0.22}},
}}
