-- stage-kh.lua's c1-drop alone, filmed again on 0.2.268 (the user, of cut 22 at 0:28: "a buggy starts firing on the
-- waiting infantry which is frozen and does not respond while the mortars land"; its guards now answer in the deploy).
--   LP_FILM_SIM=<fork-trailer-12345-14> scripts/film.sh trailer-film fork.zip docs/trailer/stage-c1.lua
return {name = "stage-c1", base = 1, army = true, waves = true, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = 44600, moves = {
  {name = "c1-drop", tick = 44750, frames = 180, every = 3, from = {pos = {-548, 31}, zoom = 0.7, daytime = 0.25}, to = {pos = {-550, 31}, zoom = 0.72, daytime = 0.25}},
}}
