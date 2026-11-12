-- The player's orbital strike on a huge Synthexis culture (the user on cut 6, 2026-11-05: "the player strike could target
-- a huge synthexis culture (with incubators and labs well in view)"): farm bigpens 12345 at minute 84, its culture of 26
-- incubators at evolution 1 (scouted, docs/trailer/scout-culture.lua: its core round 1000,0, its pod by the lake at 936,10,
-- an eastern arm to 1130,30), from its fork (scripts/film_fork.sh farm 12345 90 bigpens). A strike beacon of the player's
-- set down in its core (P.place) and charged two seconds on: Kessler-Hayashi's own barrage on everything within 60
-- (until 0.2.346: a cannon salvo now, below).
--   LP_FILM_SIM=<the fork's sim dir> scripts/film.sh farm-bigpens-film fork.zip docs/trailer/reel-culture.lua
return {name = "reel-culture", resolution = {1920, 1080}, anti_alias = true,
  -- (Since 0.2.346 a player's cannon strike at full reach, nine cannons' 48 tiles (/lp cannon salvo 9: the strike a
  -- platform's would fall, nothing spent), the user's idea: "a nice spot for a player made max radius orbital strike";
  -- the one-shot beacon it replaced is retired. Called when the beacon fired, charged two seconds on.)
  dev = {{tick = 303020, args = {"cannon", "salvo", "9"}, at = {1000, 2}}},
  moves = {
  -- Low over its core: incubators, their cells, its technicians.
  {name = "c0-culture", tick = 302400, frames = 240, every = 2, from = {pos = {960, 0}, zoom = 0.9, daytime = 0.25}, to = {pos = {1010, -4}, zoom = 0.9, daytime = 0.25}},
  -- The beacon down, then the barrage, wide.
  {name = "c1-strike", tick = 302880, frames = 900, every = 2, from = {pos = {1000, 0}, zoom = 0.6, daytime = 0.27}, to = {pos = {1000, 0}, zoom = 0.5, daytime = 0.28}},
}}
