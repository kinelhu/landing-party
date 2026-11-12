-- The army's battle at the Grubstake camp (stage.lua's m3-battle and m4-battle) filmed again on Grubstake's redrawn
-- units (the user, 2026-11-09: "we don't have enough high action footage"), from the same fork of the trailer scenario.
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh trailer-film fork.zip docs/trailer/stage-battle.lua
return {name = "stage-battle", base = 1, army = true, waves = true, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = 40700, moves = {
  -- (0.2.338, the user: "a misplaced camera", then "underwhelming ... compared to previous versions", "a little too
  -- low": a scouting pass (scout-battle.lua) shows the army halting at the camp's west street (357,-137 from 41200)
  -- and its fight there 40900 to about 41500, its peak 41100 to 41300, wrecks by 41600: the old m3 at 41400 came
  -- after it. Both now on the peak, the camera north of the fight, the camp's street and buildings above it.)
  {name = "m3-battle", tick = 40900, frames = 240, from = {pos = {376, -147}, zoom = 0.65, daytime = 0.22}, to = {pos = {374, -146}, zoom = 0.72, daytime = 0.22}},
  {name = "m4-battle", tick = 41001, frames = 240, from = {pos = {372, -145}, zoom = 0.95, daytime = 0.22}, to = {pos = {373, -144}, zoom = 1.0, daytime = 0.22}},
}}
