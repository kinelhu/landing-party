-- The Tesla restaged (the user on cut 6, 2026-11-05, of reel-tesla: "the power pole on the side of the attacker and a pink
-- debug generator in view, no wall... I would set it up with some fodder player units too"): scenario teslawall, a stone wall
-- at x 401 (y -24 to 24), eleven lasers behind it at x 397 (y -15 to 15), substations at 392 and 377, the power at 362 (out
-- of frame); thirty troopers and breachers before the wall; Kessler-Hayashi's assault set off at 5400: five Teslas from
-- x 443, sixteen infantry from 461, three tanks from 457 to 463.
-- Headless, seed 12345 (docs/sim/teslawall-12345): the fodder runs out to meet it and fights at x 418 to 429, dying 5460 to
-- 6180, the Teslas' bolts among it (the Teslas at x 439 to 424); the first drain on the line 6000; the Teslas at x 411 by
-- 6240, draining the lasers 6000 to 7440 (361 drains; the line's mean charge 42 to 56% from 6240 to 7000); the lasers fall
-- 6960 to 7560 (all eleven, and the power behind them). Teslas 3 of 5 standing, escort 18 of 19.
--   scripts/film_fork.sh teslawall 12345 7     (the fork saved at minute 1, tick 3540; strike minute 7)
--   LP_FILM_SIM=<the fork's sim dir, fork-teslawall-12345-7> scripts/film.sh teslawall-film fork.zip docs/trailer/reel-teslawall.lua
return {name = "reel-teslawall", resolution = {1920, 1080}, anti_alias = true, speed = 8, fast_until = 5350, moves = {
  -- The approach and the fodder's fight: the wall and lasers at the left, the fodder and the Teslas coming in at the right.
  {name = "w1-fodder", tick = 5460, frames = 300, every = 2, from = {pos = {420, 0}, zoom = 0.9, daytime = 0.3}, to = {pos = {414, 0}, zoom = 1.0, daytime = 0.3}},
  -- The Teslas at the line: their lightning along the lasers, the first lasers down at the end.
  {name = "w2-drain", tick = 6060, frames = 600, every = 2, from = {pos = {410, 0}, zoom = 1.0, daytime = 0.3}, to = {pos = {405, 0}, zoom = 1.2, daytime = 0.3}},
}}
