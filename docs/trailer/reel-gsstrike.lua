-- Kessler-Hayashi's orbital strike on a Grubstake camp (the user on cut 6, 2026-11-05: "one or two other satisfying orbital
-- strikes"): the trailer scenario 12345 from its fork at minute 8 (scripts/film_fork.sh trailer 12345 14), its strike
-- forced (/lp strike, P.dev, from the nearest camp that has one) on the Grubstake camp its siege takes at 44800 (-573,33),
-- before that siege: painted 12 s, then it falls.
--   LP_FILM_SIM=<the fork's sim dir> scripts/film.sh trailer-film fork.zip docs/trailer/reel-gsstrike.lua
return {name = "reel-gsstrike", resolution = {1920, 1080}, anti_alias = true, speed = 8, fast_until = 43300,
  dev = {{tick = 43400, args = {"strike"}, at = {-573, 33}}},
  moves = {
  {name = "g1-strike", tick = 43400, frames = 900, every = 2, from = {pos = {-570, 33}, zoom = 0.7, daytime = 0.25}, to = {pos = {-573, 33}, zoom = 0.55, daytime = 0.26}},
}}
