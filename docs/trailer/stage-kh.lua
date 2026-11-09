-- Kessler-Hayashi's drop on a Grubstake camp (stage.lua's c1-drop) filmed again on its redrawn units and cyan lasers
-- (the user, 2026-11-09, of cut 17: "I still see shots with old KH tanks and red KH lasers"), from the same fork of the
-- trailer scenario: its drop still deploys at 44800. stage-strike.lua's k2-strike could not be: on 0.2.246 the armed
-- camp's siege on the player's wall no longer comes (a rehearsal to 71300: after its pack at 53800, only the herd's
-- wave), and the cut takes reel-khwall's later moves in its place.
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh trailer-film fork.zip docs/trailer/stage-kh.lua
return {name = "stage-kh", base = 1, army = true, waves = true, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = 44600, moves = {
  {name = "c1-drop", tick = 44750, frames = 180, every = 3, from = {pos = {-548, 31}, zoom = 0.7, daytime = 0.25}, to = {pos = {-550, 31}, zoom = 0.72, daytime = 0.25}},
}}
