-- The howitzers' feet (the far pair splayed) by day, and the corporations' buildings' lights at night (scripts/lights.lua).
-- scripts/film.sh gallery fresh.zip docs/review/stills-lights.lua
local list = {
  {"kh-howitzer", "lp-howitzer", "lp-serenity"}, {"gs-howitzer", "lp-grubstake-howitzer", "lp-grubstake"},
  {"kh-dome-projector", "lp-dome-projector", "lp-serenity"}, {"kh-jammer", "lp-jammer", "lp-serenity"},
  {"kh-orbital-relay", "lp-orbital-relay", "lp-serenity"}, {"kh-pacifier", "lp-pacifier", "lp-serenity"},
  {"gs-pacifier", "lp-grubstake-pacifier", "lp-grubstake"}, {"kh-uplink", "lp-uplink", "lp-serenity"},
}
local build, shots, t = {}, {}, 180
for i, it in ipairs(list) do
  local pos = {((i - 1) % 4) * 16, math.floor((i - 1) / 4) * 18}
  build[#build + 1] = {name = it[2], force = it[3], pos = pos}
  shots[#shots + 1] = {name = string.format("%02d-%s-day", i, it[1]), tick = t, pos = {pos[1], pos[2] - 1}, zoom = 2.6, daytime = 0.05}
  shots[#shots + 1] = {name = string.format("%02d-%s-night", i, it[1]), tick = t + 4, pos = {pos[1], pos[2] - 1}, zoom = 2.6,
    daytime = 0.5, hide_clouds = true}
  t = t + 9
end
shots[#shots + 1] = {name = "00-all-night", tick = t + 4, pos = {24, 9}, zoom = 0.7, daytime = 0.5, hide_clouds = true}
return {name = "lights", pad = {-10, -10, 58, 28}, tile = "grass-1", build = build, shots = shots, resolution = {1280, 720}}
