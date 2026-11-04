-- Shot 1, cold open (storyboard): the factory at work, a drift west to east over its busiest blocks (scouted: the band at
-- y 0, x 0 to 300), zoom 0.5, 18 tiles a second for 6 s, full day. nw's visit copy, no corporation yet.
--   scripts/film.sh nw-rich-l165-seed1 visit.zip docs/trailer/shot-01.lua
return {name = "shot-01", resolution = {1920, 1080}, anti_alias = true, moves = {
  {name = "f", at_load = true, tick = nil, frames = 180, every = 2, from = {pos = {40, 0}, zoom = 0.5, daytime = 0.05},
    to = {pos = {148, 0}, zoom = 0.5, daytime = 0.06}}}}
