-- Synthexis's herd in the trailer scenario refilmed on 0.2.209 (the user on cut 6, 2026-11-05: "we only show a handful of
-- biters rushing through? Plus it seemed to break the wall from the inside to escape?": its rush went back out of its
-- gap and round the walls; now it pours through its gap to the heart, herd.lua). stage.lua's s1 to s3 from the same fork:
-- march 64080, breach 65400 (-39,-286), its gap open 65704, the rush 65844, at the heart (7,-303) about 66000.
--   LP_FILM_SIM=<the fork's sim dir> scripts/film.sh trailer-film fork.zip docs/trailer/stage-herd.lua
-- (Re-timed 2026-11-11 for the reshoot at 0.2.320, from the fork's rehearsal (FILM_REHEARSE, trace on, settlements 1
-- and 4): its herd breaches at 65112 (-38,-270), its gap open 65411 (-38,-288), its rush 65635; the drop's assault 49000;
-- the armed camp deploys 66400, paints 68200, its lances fall 68920.)
return {name = "stage-herd", base = 1, waves = true, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = 64200, moves = {
  {name = "s1-march", tick = 64300, frames = 180, track = true, from = {pos = "wave", zoom = 0.6, daytime = 0.33}, to = {daytime = 0.33}},
  {name = "s2-breach", tick = 64960, frames = 300, from = {pos = {-41, -290}, zoom = 0.75, daytime = 0.34}, to = {pos = {-36, -292}, zoom = 0.8, daytime = 0.34}},
  -- Through the gap and on to the heart: held on the gap, drifting toward the heart.
  {name = "s3-inside", tick = 65640, frames = 300, from = {pos = {-34, -290}, zoom = 0.6, daytime = 0.35}, to = {pos = {-10, -298}, zoom = 0.6, daytime = 0.35}},
}}
