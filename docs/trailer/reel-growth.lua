-- Synthexis's culture growing (the user on cut 13, 2026-11-05: "The bases are basically asleep (frozen) most of the time,
-- and the tumors don't really spread meaningfully over the time lapse"): farm LP_MIX=growth 12345 (a dirty factory's
-- smog over its ground, room to grow: 4 incubators to 13 in 20 minutes), from its fork at minute 2, its harness run to
-- 40 (LP_FORK_MINUTES=40 scripts/film_fork.sh farm 12345 8 growth). Its pod round 1000,0 (farm 12345's).
--   g1: half an hour, a still every 6 s of game time (a minute of it in 1.7 s on screen), wide;
--   g2: its core at 25 minutes, close, a still every half second: its technicians, hatchlings, stock.
--   LP_FILM_SIM=<the fork's sim dir> scripts/film.sh farm-growth-film fork.zip docs/trailer/reel-growth.lua
return {name = "reel-growth", resolution = {1920, 1080}, anti_alias = true, speed = 8,
  lapse = {{from = 7200, to = 116000, speed = 16}},
  moves = {
  {name = "g1-lapse", tick = 7300, frames = 300, every = 360, from = {pos = {1000, 0}, zoom = 0.42, daytime = 0.2}, to = {pos = {1010, 0}, zoom = 0.3, daytime = 0.2}},
  {name = "g2-core", tick = 90000, frames = 240, every = 30, from = {pos = {995, -5}, zoom = 1.0, daytime = 0.2}, to = {pos = {1005, -2}, zoom = 0.9, daytime = 0.2}},
}}
