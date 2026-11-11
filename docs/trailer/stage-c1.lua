-- stage-kh.lua's c1-drop alone, filmed again on 0.2.268 (the user, of cut 22 at 0:28: "a buggy starts firing on the
-- waiting infantry which is frozen and does not respond while the mortars land"; its guards now answer in the deploy).
--   LP_FILM_SIM=<fork-trailer-12345-14> scripts/film.sh trailer-film fork.zip docs/trailer/stage-c1.lua
-- (Re-timed 2026-11-12 for the reshoot at 0.2.338, from the fork's rehearsal (FILM_REHEARSE, trace on): the drop's pods
-- at 45100 and its assault 49300, the armed camp's pods 66700, its strike painted 68500 and falling 69220, each 300 ticks
-- after 0.2.321's; the herd's way in now at 3,-300 (no wall) at 64997, its gap open 65692 at -38,-312.)
return {name = "stage-c1", base = 1, army = true, waves = true, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = 44600, moves = {
  {name = "c1-drop", tick = 45050, frames = 180, every = 3, from = {pos = {-548, 31}, zoom = 0.7, daytime = 0.25}, to = {pos = {-550, 31}, zoom = 0.72, daytime = 0.25}},
}}
