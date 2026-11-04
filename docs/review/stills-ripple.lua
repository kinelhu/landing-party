-- The dome's catch as video: a still every tick through two ripples over the projector, by day and by night, for ffmpeg.
-- scripts/film.sh gallery fresh.zip docs/review/stills-ripple.lua
local shots, ripples = {}, {}
for k, look in ipairs({{"day", 0.05}, {"night", 0.5}}) do
  local t0 = 200 + (k - 1) * 120
  ripples[#ripples + 1] = {tick = t0 + 10, pos = {0, 0}}
  for i = 0, 50 do
    shots[#shots + 1] = {name = string.format("%s-%03d", look[1], i), tick = t0 + i, pos = {0, -2}, zoom = 1.6,
      daytime = look[2], hide_clouds = look[1] == "night"}
  end
end
return {name = "ripple", pad = {-10, -12, 10, 8}, build = {{name = "lp-dome-projector", force = "lp-serenity", pos = {0, 0}}},
  ripples = ripples, shots = shots, resolution = {1280, 720}}
