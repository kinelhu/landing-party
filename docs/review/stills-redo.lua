-- The redo round after the user's ratings (2026-11-10): each redone model beside vanilla's of its scale, on grass and on
-- desert (judged on the ground it stands on), day and night, at the rating page's close zoom and at play zoom.
--   scripts/film.sh gallery fresh.zip docs/review/stills-redo.lua
local row = {
  {"lab", "player"}, {"lp-optics-lab", "lp-serenity"}, {"lp-grubstake-optics-lab", "lp-grubstake"},
  {"small-lamp", "player"}, {"lp-pact-breaker", "player"}, {"lp-claim-marker", "player"},
  {"lp-rally-beacon", "player"}, {"lp-muster-point", "player"}, {"steel-chest", "player"}, {"lp-barracks", "player"},
  {"medium-electric-pole", "player"}, {"lp-pylon", "lp-serenity"}, {"lp-grubstake-pylon", "lp-grubstake"},
  {"lp-jammer", "lp-serenity"}, {"lp-orbital-relay", "lp-serenity"}, {"lp-pacifier", "lp-serenity"},
  {"lp-grubstake-pacifier", "lp-grubstake"}, {"lp-uplink", "lp-serenity"}, {"lp-grubstake-uplink", "lp-grubstake"},
  {"electric-mining-drill", "player"}, {"lp-strip-drill", "player"}, {"lp-grubstake-drill", "lp-grubstake"},
  {"radar", "player"}, {"lp-fabricator", "lp-serenity"}, {"lp-grubstake-flamer", "lp-grubstake"},
}
local GAP = 7
local build, shots = {}, {}
local GROUND = {{"grass-1", 0}, {"red-desert-0", 16}}
local t = 200
for gi, g in ipairs(GROUND) do
  for i, e in ipairs(row) do
    build[#build + 1] = {name = e[1], force = e[2], pos = {(i - 1) * GAP, g[2]}, ground = g[1], ground_r = 4}
  end
  for i = 1, #row, 3 do
    shots[#shots + 1] = {name = string.format("%d-%s-%02d", gi, g[1], i), tick = t, pos = {(i - 1 + 1) * GAP, g[2] - 0.5},
      zoom = 1.6, daytime = 0.05, hide_clouds = true}
    t = t + 2
  end
  for i = 1, #row, 8 do
    shots[#shots + 1] = {name = string.format("%d-%s-play-%02d", gi, g[1], i), tick = t, pos = {(i - 1 + 3.5) * GAP, g[2]},
      zoom = 0.75, daytime = 0.05}
    shots[#shots + 1] = {name = string.format("%d-%s-night-%02d", gi, g[1], i), tick = t + 2, pos = {(i - 1 + 3.5) * GAP, g[2]},
      zoom = 0.75, daytime = 0.5, hide_clouds = true}
    t = t + 4
  end
end
return {name = "redo", pad = {-8, -8, #row * GAP + 4, 24}, tile = "grass-1", build = build, shots = shots, resolution = {1920, 1080}}
