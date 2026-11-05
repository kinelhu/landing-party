-- The player's orbital strike on a huge Synthexis culture (the user on cut 6, 2026-11-05: "the player strike could target
-- a huge synthexis culture (with incubators and labs well in view)"): farm bigpens 12345 at minute 84, its culture of 26
-- incubators at evolution 1 (scouted, docs/trailer/scout-culture.lua: its core round 1000,0, its pod by the lake at 936,10,
-- an eastern arm to 1130,30), from its fork (scripts/film_fork.sh farm 12345 90 bigpens). A strike beacon of the player's
-- set down in its core (P.place) and charged two seconds on: Kessler-Hayashi's own barrage on everything within 60.
--   LP_FILM_SIM=<the fork's sim dir> scripts/film.sh farm-bigpens-film fork.zip docs/trailer/reel-culture.lua
return {name = "reel-culture", resolution = {1920, 1080}, anti_alias = true,
  place = {{tick = 302900, name = "lp-strike-beacon", pos = {1000, 2}, charge = 120}},
  moves = {
  -- Low over its core: incubators, their cells, its technicians.
  {name = "c0-culture", tick = 302400, frames = 240, every = 2, from = {pos = {960, 0}, zoom = 0.9, daytime = 0.25}, to = {pos = {1010, -4}, zoom = 0.9, daytime = 0.25}},
  -- The beacon down, then the barrage, wide.
  {name = "c1-strike", tick = 302880, frames = 900, every = 2, from = {pos = {1000, 0}, zoom = 0.6, daytime = 0.27}, to = {pos = {1000, 0}, zoom = 0.5, daytime = 0.28}},
}}
