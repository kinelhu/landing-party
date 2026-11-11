-- Unit shadows at full strength (0.2.323: the units' sheets had been packed at 0.55 of their shadows' alpha, half of
-- vanilla's; tools/blender/shadow_full.py restored them). Vanilla's tank and car first, then every unit whose sheet
-- changed, on grass, day. Shot early, before the forces meet.
--   scripts/film.sh rating fresh.zip docs/review/stills-unitshadows.lua
local row = {{"tank", "player"}, {"car", "player"}, {"lp-tank", "lp-serenity"}, {"lp-aegis", "lp-serenity"},
  {"lp-prism", "lp-serenity"}, {"lp-tesla", "lp-serenity"}, {"lp-laser-drone", "lp-serenity"}, {"lp-buggy", "lp-grubstake"},
  {"lp-slug", "lp-grubstake"}, {"lp-flak-buggy", "lp-grubstake"}, {"lp-dozer", "lp-grubstake"}, {"lp-scorcher", "lp-grubstake"},
  {"lp-hauler", "lp-grubstake"}, {"lp-harrier", "lp-grubstake"}, {"lp-scavenger", "lp-grubstake"}}
local build = {}
for i, e in ipairs(row) do build[#build + 1] = {name = e[1], force = e[2], pos = {((i - 1) % 5) * 6, math.floor((i - 1) / 5) * 6}} end
return {name = "unitshadows", pad = {-6, -6, 30, 18}, tile = "grass-1", build = build, resolution = {1600, 1200},
  shots = {{name = "unitshadows-day", tick = 110, pos = {12, 6}, zoom = 1.1, daytime = 0.05, hide_clouds = true}}}
