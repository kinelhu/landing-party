-- The uplink rendered at home (tools/blender/uplink.py), both corporations, on grass and sand, by day and night, the dish at
-- two turns. scripts/film.sh gallery fresh.zip docs/review/stills-uplink.lua
local build, shots, t = {}, {}, 120
for i, it in ipairs({{"kh", "lp-uplink", "lp-serenity"}, {"gs", "lp-grubstake-uplink", "lp-grubstake"}}) do
  for j, g in ipairs({"grass-1", "sand-1"}) do
    local pos = {(j - 1) * 20, (i - 1) * 20}
    build[#build + 1] = {name = it[2], force = it[3], pos = pos, ground = g, ground_r = 9}
    shots[#shots + 1] = {name = string.format("%s-%s-day", it[1], g), tick = t, pos = {pos[1], pos[2] - 1.5}, zoom = 1.6, daytime = 0.05}
    shots[#shots + 1] = {name = string.format("%s-%s-day-b", it[1], g), tick = t + 200, pos = {pos[1], pos[2] - 1.5}, zoom = 1.6, daytime = 0.05}
    shots[#shots + 1] = {name = string.format("%s-%s-night", it[1], g), tick = t + 3, pos = {pos[1], pos[2] - 1.5}, zoom = 1.6,
      daytime = 0.5, hide_clouds = true}
    t = t + 10
  end
end
return {name = "uplink", pad = {-12, -12, 32, 32}, tile = "grass-1", build = build, shots = shots, resolution = {1280, 720}}
