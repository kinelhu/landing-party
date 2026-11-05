-- Synthexis's bursters at the wall, close (the user, 2026-11-05: "missing a synthexis assault with bursters?"): the herd
-- scenario's wave (LP_MIX=burst) from its fork at minute 1 (scripts/film_fork.sh herd 12345 7 burst), locked on where a
-- scouting run of that fork on 0.2.206 breached (tick 7281 at 232,41; its gap open at 238,41 by 7567), from the last of
-- the march through the blasts to the herd pouring in.
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh herd-burst-film fork.zip docs/trailer/act-herd-burst-close.lua
return {name = "act-herd-burst-close", base = 1, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = 6700, moves = {
  {name = "b1-blast", tick = 6900, frames = 780, from = {pos = {226, 41}, zoom = 1.0, daytime = 0.22}, to = {pos = {236, 41}, zoom = 0.9, daytime = 0.23}},
}}
