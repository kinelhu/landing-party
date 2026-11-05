-- Synthexis's bursters at the wall, close (the user, 2026-11-05: "missing a synthexis assault with bursters?"): the herd
-- scenario's wave (LP_MIX=burst) from its fork at minute 1 (scripts/film_fork.sh herd 12345 7 burst), locked on where a
-- scouting run of that fork on 0.2.206 breached (tick 7281 at 232,41; its gap open at 238,41 by 7567), from the last of
-- the march through the blasts to the herd pouring in.
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh herd-burst-film fork.zip docs/trailer/act-herd-burst-close.lua
return {name = "act-herd-burst-close", base = 1, waves = true, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = "wave:march", moves = {
  -- (Locked on the scout's tick and place it showed an empty wall corner: tracked on the wave instead, from 1600 ticks
  -- into its march, the herd at the wall about 1800 in.)
  {name = "b1-blast", after = "wave:march", dt = 1600, frames = 900, track = true, from = {pos = "wave", zoom = 1.0, daytime = 0.22}, to = {zoom = 0.85, daytime = 0.23}},
}}
