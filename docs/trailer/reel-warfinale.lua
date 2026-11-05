-- The finale (the user on cut 6, 2026-11-05: "an (artificial) shot of an all out war at the end? A biter wave rushing in
-- perpendicularly to a fight between player and KH, mixing in, then a big nuke going off for the send off"): scenario
-- warfinale on open ground round C = (430, 0). At 7200 the player's army (76) from x 391 to 410 and Kessler-Hayashi's (72)
-- from 450 to 474, set on each other; engaged 7340; twenty more a side every 4 s from 7560 to 8760, from x 376 and 484
-- (their tanks from 364 and 496); Synthexis's herd (200: 150 medium, 40 big, 10 cinders) set off from y -115 at 7920, in
-- (20 of it within 40 of C) at 8240; the player's atomic bomb fired from (402, 28) at 9140, off on C at 9210: of 60 within
-- 30 of it (27 of the herd, 19 of the player's, 14 of KH's) 2 left. Standing before it: the player's 45, KH's 43, the herd
-- 34; after: 16, 14, 0. Headless, seed 12345 (docs/sim/warfinale-12345).
--   scripts/film_fork.sh warfinale 12345 7     (the fork saved at minute 1, tick 3540; strike minute 7)
--   LP_FILM_SIM=<the fork's sim dir, fork-warfinale-12345-7> scripts/film.sh warfinale-film fork.zip docs/trailer/reel-warfinale.lua
return {name = "reel-warfinale", resolution = {1920, 1080}, anti_alias = true, speed = 8, fast_until = 7150, moves = {
  -- The armies meet, reinforcements coming in from both edges.
  {name = "f1-melee", tick = 7260, frames = 450, every = 2, from = {pos = {430, 0}, zoom = 0.62, daytime = 0.3}, to = {pos = {430, -4}, zoom = 0.55, daytime = 0.3}},
  -- The herd comes down from the north (the top of the frame) into the melee.
  {name = "f2-herd", tick = 8160, frames = 470, every = 2, from = {pos = {430, -18}, zoom = 0.55, daytime = 0.3}, to = {pos = {430, 0}, zoom = 0.5, daytime = 0.3}},
  -- The bomb: the rocket in from the south-west, the flash at 9210, the shockwave and the mushroom, wide.
  {name = "f3-nuke", tick = 9100, frames = 500, every = 2, from = {pos = {430, 0}, zoom = 0.4, daytime = 0.3}, to = {pos = {430, -6}, zoom = 0.32, daytime = 0.3}},
}}
