-- Synthexis's colours (the user, 2026-11-12: "recolor synthexis cultures slightly? Considering the purple creep and
-- bright green tumors and biters?"): its creep with tumors and bred units standing on it, a wild biter beside for the
-- vanilla look, on desert dirt and on grass, by day and at dusk. Filmed once a palette (biotech.lua's creep and tumor
-- tints, shared.BIOTECH's tint1 and tint2), the same stills each time.
--   scripts/film.sh gallery fresh.zip docs/review/stills-synthcolor.lua docs/sim/film-synthcolor-<palette>
local B = "lp-biotech"
-- (400 tiles north of the fresh save's own gallery: its turrets' range arcs crossed the first take.)
local OY = -400
local build = {
  -- On desert (the film's own ground): a culture's patch.
  {name = "lp-tumor", force = B, pos = {0, 0 + OY}, ground = "lp-creep", ground_r = 9},
  {name = "lp-tumor", force = B, pos = {7, 4 + OY}},
  {name = "lp-bred-big-biter", force = B, pos = {-4, 3 + OY}}, {name = "lp-bred-medium-biter", force = B, pos = {-1, 5 + OY}},
  {name = "lp-bred-big-burster", force = B, pos = {3, -4 + OY}}, {name = "lp-bred-medium-spitter", force = B, pos = {5, -1 + OY}},
  {name = "lp-bred-behemoth-biter", force = B, pos = {-6, -3 + OY}},
  {name = "big-biter", force = "enemy", pos = {13, -2 + OY}}, {name = "medium-biter", force = "enemy", pos = {14, 2 + OY}},
  -- On grass: the grass laid by the first unit's own ground, the creep over it by the tumor's.
  {name = "big-biter", force = "enemy", pos = {50, -3 + OY}, ground = "grass-1", ground_r = 15},
  {name = "lp-tumor", force = B, pos = {40, 0 + OY}, ground = "lp-creep", ground_r = 8},
  {name = "lp-tumor", force = B, pos = {44, 5 + OY}},
  {name = "lp-bred-big-biter", force = B, pos = {37, 3 + OY}}, {name = "lp-bred-medium-biter", force = B, pos = {41, -4 + OY}},
  {name = "lp-bred-big-burster", force = B, pos = {44, -2 + OY}}, {name = "medium-biter", force = "enemy", pos = {51, 2 + OY}},
}
local function shot(name, pos, zoom, daytime)
  return {name = name, tick = 240, pos = pos, zoom = zoom, daytime = daytime, hide_clouds = true}
end
return {name = "synthcolor", pad = {-16, -14 + OY, 60, 14 + OY}, tile = "dirt-4", build = build, resolution = {1920, 1080},
  shots = {shot("desert-day", {3, OY}, 1.0, 0.05), shot("grass-day", {44, OY}, 1.0, 0.05),
    shot("wide-day", {22, OY}, 0.5, 0.05), shot("desert-dusk", {3, OY}, 1.0, 0.3)}}
