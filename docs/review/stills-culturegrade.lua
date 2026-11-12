-- Synthexis's colour grade on a real culture (the user, 2026-11-12: the gallery's square pads flatter nothing): farm
-- bigpens 12345's culture at minute 84 (its core round 1000,0, its pod by the lake at 936,10; docs/trailer/reel-culture.lua),
-- at the trailer's zooms, once a palette (tools/art/grade.py).
--   LP_FILM_SIM=<the fork's sim dir> scripts/film.sh farm-bigpens-film fork.zip docs/review/stills-culturegrade.lua <out>
-- (Timed from load: the fork was re-saved headless past its own tick, 2026-11-12, for the migrated-content dialog.)
local function shot(name, at, pos, zoom)
  return {name = name, at_load = at, pos = pos, zoom = zoom, daytime = 0.25, hide_clouds = true}
end
return {name = "culturegrade", resolution = {1920, 1080}, anti_alias = true,
  shots = {shot("core-close", 120, {985, -2}, 0.9), shot("core-wide", 130, {1000, 0}, 0.5),
    shot("lake", 140, {945, 8}, 0.7)}}
