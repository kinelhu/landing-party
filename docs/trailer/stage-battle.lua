-- The army's battle at the Grubstake camp (stage.lua's m3-battle and m4-battle) filmed again on Grubstake's redrawn
-- units (the user, 2026-11-09: "we don't have enough high action footage"), from the same fork of the trailer scenario.
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh trailer-film fork.zip docs/trailer/stage-battle.lua
return {name = "stage-battle", base = 1, army = true, waves = true, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = 41200, moves = {
  -- (0.2.338: the fight is round 366,-141 throughout, at the frame's bottom-left edge from 392,-158 and its top-right
  -- from the army's point 356,-133, the user: "a misplaced camera"; m4 at 42600 came after it, wrecks only: now 41900.)
  {name = "m3-battle", tick = 41400, frames = 240, from = {pos = {364, -143}, zoom = 0.75, daytime = 0.22}, to = {pos = {367, -141}, zoom = 0.8, daytime = 0.22}},
  {name = "m4-battle", tick = 41900, frames = 240, from = {pos = {366, -141}, zoom = 0.95, daytime = 0.22}, to = {pos = {368, -140}, zoom = 1.0, daytime = 0.22}},
}}
