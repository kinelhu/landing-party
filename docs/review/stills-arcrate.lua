-- The arc flamer's rating card (0.2.342, its own model): beside vanilla's flamethrower turret as stills-rating.lua's
-- pair was (zoom 2.4, 1280 by 760, 4.4 tiles apart), 400 tiles south of the fresh save's own gallery.
--   scripts/film.sh arcfilm fresh.zip docs/review/stills-arcrate.lua docs/sim/film-arcrate
return {name = "arcrate", pad = {-12, 392, 12, 408}, tile = "grass-1", resolution = {1280, 760},
  build = {{name = "lp-flamer", force = "lp-serenity", pos = {-2.2, 400}}, {name = "flamethrower-turret", force = "player", pos = {2.2, 400}}},
  shots = {{name = "20-kh-flamer", tick = 240, pos = {0, 399.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}}}
