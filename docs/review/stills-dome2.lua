-- The dome's looks, second reel (a game session stalled at 226 screenshots, twice: reels under about 110): hits from the
-- north-west and south-east (night), and its rise at night. scripts/film.sh gallery fresh.zip docs/review/stills-dome2.lua
local R = 20
local shots, fx = {}, {}
local function take(tag, t0, n, daytime)
  for i = 0, n - 1 do
    shots[#shots + 1] = {name = string.format("%s-%03d", tag, i), tick = t0 + 2 * i, pos = {0, -6}, zoom = 0.62,
      daytime = daytime, hide_clouds = daytime > 0.3}
  end
end
local t = 200
fx[#fx + 1] = {tick = t + 4, kind = "wave", radius = R, at = {-R * 0.7, -R * 0.7}}
take("d-hit-northwest-day", t, 32, 0.05); t = t + 80
fx[#fx + 1] = {tick = t + 4, kind = "wave", radius = R, at = {R * 0.7, R * 0.7}}
take("f-hit-southeast-night", t, 32, 0.5); t = t + 80
fx[#fx + 1] = {tick = t + 4, kind = "rise", radius = R}
take("g-rise-night", t, 40, 0.5)
return {name = "dome2", pad = {-30, -34, 30, 30}, tile = "grass-1",
  build = {{name = "lp-dome-projector", force = "lp-serenity", pos = {0, 0}}}, fx = fx, ring = R, shots = shots,
  resolution = {1280, 720}}
