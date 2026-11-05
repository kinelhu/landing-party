-- Guns firing (the user on cut 4, 2026-11-05: "Howitzers firing? We see a lot of mortars deploying again but no fire"):
-- Kessler-Hayashi's fortress siege, 12345, from its fork at minute 13 (scripts/film_fork.sh fortress 12345 19). Its
-- mortars and its howitzer fire from 52600 to 59200 (site -121,-222) on the laser wall at -85,-224; the assault 59200.
--   LP_FILM_SIM=<the fork's sim dir> scripts/film.sh fortress-film fork.zip docs/trailer/reel-fortress.lua
return {name = "reel-fortress", base = 2, resolution = {1920, 1080}, anti_alias = true, speed = 8, fast_until = 52300, moves = {
  -- The guns and the wall in one frame, the shells' arcs between them.
  {name = "f1-guns", tick = 52700, frames = 600, every = 2, from = {pos = {-110, -222}, zoom = 0.55, daytime = 0.3}, to = {pos = {-104, -223}, zoom = 0.6, daytime = 0.31}},
  -- Close on the battery firing.
  {name = "f2-battery", tick = 54000, frames = 360, from = {pos = {-121, -222}, zoom = 1.0, daytime = 0.31}, to = {pos = {-119, -222}, zoom = 1.1, daytime = 0.31}},
  -- Close on the wall taking it: lasers and roboports going down.
  {name = "f3-impact", tick = 55000, frames = 600, every = 2, from = {pos = {-90, -224}, zoom = 0.8, daytime = 0.32}, to = {pos = {-88, -224}, zoom = 0.9, daytime = 0.32}},
  -- The assault through what is left.
  {name = "f4-assault", tick = 59100, frames = 360, from = {pos = {-100, -222}, zoom = 0.75, daytime = 0.33}, to = {pos = {-92, -223}, zoom = 0.8, daytime = 0.33}},
}}
