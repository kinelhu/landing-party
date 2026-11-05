-- The strike on the player's wall again, framed on the wall (stage.lua's k2-strike had it at the frame's top edge): the
-- trailer scenario's fork on 0.2.206 (paint 67600, lances fall 68320 on the wall at -28,243, its assault 68321).
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh trailer-film fork.zip docs/trailer/stage-strike.lua
return {name = "stage-strike", base = 1, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = 67400, moves = {
  {name = "k2-strike", tick = 67700, frames = 1000, from = {pos = {-29, 247}, zoom = 0.55, daytime = 0.3}, to = {pos = {-28, 241}, zoom = 0.75, daytime = 0.31}},
}}
