-- The dome's looks as video (dome.lua through debug_dome_fx): its rise, then hits from the south, the east, the north-west
-- (mirrored) and the north, on a dome of radius 20 over a projector, a still every other tick; a dome ring drawn on the
-- ground as the game draws it. scripts/film.sh gallery fresh.zip docs/review/stills-dome.lua
local R = 20
local shots, fx = {}, {}
local function take(tag, t0, n, daytime)
  for i = 0, n - 1 do
    shots[#shots + 1] = {name = string.format("%s-%03d", tag, i), tick = t0 + 2 * i, pos = {0, -6}, zoom = 0.62,
      daytime = daytime, hide_clouds = daytime > 0.3}
  end
end
local t = 200
fx[#fx + 1] = {tick = t + 4, kind = "rise", radius = R}
take("a-rise-day", t, 40, 0.05); t = t + 100
for _, h in ipairs({{"b-hit-south", {0, R}}, {"c-hit-east", {R, 0}}, {"d-hit-northwest", {-R * 0.7, -R * 0.7}}, {"e-hit-north", {0, -R}}}) do
  fx[#fx + 1] = {tick = t + 4, kind = "wave", radius = R, at = h[2]}
  take(h[1] .. "-day", t, 32, 0.05); t = t + 80
end
fx[#fx + 1] = {tick = t + 4, kind = "wave", radius = R, at = {R * 0.7, R * 0.7}}
take("f-hit-southeast-night", t, 32, 0.5); t = t + 80
fx[#fx + 1] = {tick = t + 4, kind = "rise", radius = R}
take("g-rise-night", t, 40, 0.5)
return {name = "dome", pad = {-30, -34, 30, 30}, tile = "grass-1",
  build = {{name = "lp-dome-projector", force = "lp-serenity", pos = {0, 0}}}, fx = fx, ring = R, shots = shots,
  resolution = {1280, 720}}
