-- A built-up base (the user on cut 4, 2026-11-05: "Perhaps we are lacking shots of really built up enemy bases?"):
-- Kessler-Hayashi's settlement an hour grown, grow 12345 from its fork at minute 60 (scripts/film_fork.sh grow 12345 66):
-- (saved at 215940) 26 blocks, 68 turrets, its lander at -339,-2 and its walled clusters down to -250,190 (grow-12345 final.png).
--   LP_FILM_SIM=<the fork's sim dir> scripts/film.sh grow-film fork.zip docs/trailer/reel-base.lua
return {name = "reel-base", resolution = {1920, 1080}, anti_alias = true, moves = {
  -- (Scouted, docs/trailer/scout-base.lua: walled clusters at -430,9, -282,-22, -360,52 and -282,176; the lander -339,-2.)
  -- High and descending onto the lander and its northeast cluster.
  {name = "b1-over", tick = 216100, frames = 360, every = 2, from = {pos = {-370, 30}, zoom = 0.28, daytime = 0.1}, to = {pos = {-320, -5}, zoom = 0.45, daytime = 0.11}},
  -- Low, along the northeast cluster's turrets and works.
  {name = "b2-low", tick = 216900, frames = 300, every = 2, from = {pos = {-318, -22}, zoom = 0.85, daytime = 0.12}, to = {pos = {-252, -22}, zoom = 0.85, daytime = 0.12}},
  -- Low, along the middle cluster.
  {name = "b3-low", tick = 217600, frames = 300, every = 2, from = {pos = {-392, 52}, zoom = 0.85, daytime = 0.12}, to = {pos = {-330, 50}, zoom = 0.85, daytime = 0.12}},
}}
