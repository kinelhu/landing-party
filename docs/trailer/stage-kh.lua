-- Kessler-Hayashi's two shots of the stage (stage.lua's c1-drop and stage-strike.lua's k2-strike) filmed again on its
-- redrawn units and cyan lasers (the user, 2026-11-09, of cut 17: "I still see shots with old KH tanks and red KH
-- lasers"), from the same fork of the trailer scenario, at the same beats: the drop deploys at 44800, the armed camp's
-- siege on the wall at 65800, paints 67600, its lances fall 68320. The plugin's events come from one settlement
-- (`base`): the armed camp is settlement 4, so its beats are rehearsed with base = 4 (with base = 1 it looked gone).
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh trailer-film fork.zip docs/trailer/stage-kh.lua
return {name = "stage-kh", base = 1, army = true, waves = true, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = 44600, moves = {
  {name = "c1-drop", tick = 44750, frames = 180, every = 3, from = {pos = {-548, 31}, zoom = 0.7, daytime = 0.25}, to = {pos = {-550, 31}, zoom = 0.72, daytime = 0.25}},
  {name = "k2-strike", tick = 67700, frames = 1000, from = {pos = {-29, 247}, zoom = 0.55, daytime = 0.3}, to = {pos = {-28, 241}, zoom = 0.75, daytime = 0.31}},
}}
