-- Shots 9 to 11 (storyboard): Kessler-Hayashi's siege of nw's south wall, from the trailer visit's save at minute 16
-- (LP_MIX=rich-trailer-seed3-saveat9-saveat16-saveat19-saveat38, scripts/visit_saves.sh): the pods land near +3380 ticks,
-- the strike paints near +5140. 1080p, a frame every 2 ticks (3 for the drop), eased moves.
--   LP_FILM_SIM=<the visit's profile> scripts/film.sh original-rich-trailer-seed3-saveat9-saveat16-saveat19-saveat38 t16.zip docs/trailer/shots-09-11.lua
-- (base = "siege": the visit's camp is not base 1, and the escort was never found. Dusk, not the storyboard's night: a
-- screenshot's own daytime ignores the surface's min_brightness, and at 0.47 to 0.5 the unlit ground filmed black,
-- 2026-11-04.)
local T0 = 11972351 + 16 * 3600
return {name = "shots-09-11", base = "siege", resolution = {1920, 1080}, anti_alias = true, moves = {
  -- 9: the march reaching its hold, held on its escort, dusk deepening.
  {name = "s09", tick = T0 + 2480, frames = 180, from = {pos = "escort", zoom = 1.0, daytime = 0.37}, to = {off = {0, -4}, daytime = 0.38}},
  -- 10: the drop, the site and the wall in frame, the guns assembled where the pods land.
  {name = "s10", tick = T0 + 3200, frames = 300, every = 3, from = {pos = {-137, 366}, zoom = 0.72, daytime = 0.39}, to = {pos = {-137, 365}, zoom = 0.75, daytime = 0.4}},
  -- 11: the strike, a push-in on the wall through the paint, then the lances.
  {name = "s11", tick = T0 + 5140, frames = 310, from = {pos = {-140, 356}, zoom = 0.5, daytime = 0.41}, to = {pos = {-140, 352}, zoom = 0.85, daytime = 0.42}},
}}
