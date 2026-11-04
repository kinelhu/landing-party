-- Stills of the art rendered on 2026-11-03 and 04, placed on a concrete pad by the film helper (tests/lp-film):
-- scripts/film.sh gallery fresh.zip docs/review/stills-gallery.lua
-- Each building alone, by day and by night; the whole row wide; the dome's ripple over its projector.
local GAP = 16
local list = {
  {"kh-dome-projector", "lp-dome-projector", "lp-serenity"},
  {"kh-jammer", "lp-jammer", "lp-serenity"},
  {"kh-orbital-relay", "lp-orbital-relay", "lp-serenity"},
  {"kh-pacifier", "lp-pacifier", "lp-serenity"},
  {"kh-uplink", "lp-uplink", "lp-serenity"},
  {"kh-mortar", "lp-mortar", "lp-serenity"},
  {"kh-howitzer", "lp-howitzer", "lp-serenity"},
  {"kh-parked-howitzer", "lp-parked-howitzer", "lp-serenity"},
  {"kh-howitzer-truck", "lp-howitzer-truck", "lp-serenity"},
  {"gs-pacifier", "lp-grubstake-pacifier", "lp-grubstake"},
  {"gs-mortar", "lp-grubstake-mortar", "lp-grubstake"},
  {"gs-howitzer", "lp-grubstake-howitzer", "lp-grubstake"},
  {"gs-parked-howitzer", "lp-grubstake-parked-howitzer", "lp-grubstake"},
  {"pl-barracks", "lp-barracks", "player"},
  {"pl-muster-point", "lp-muster-point", "player"},
  {"pl-command-relay", "lp-command-relay", "player"},
  {"pl-mortar", "lp-player-mortar", "player"},
}
local build, shots = {}, {}
local cols = 6
local t = 180
for i, it in ipairs(list) do
  local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
  local pos = {c * GAP, r * GAP}
  build[#build + 1] = {name = it[2], force = it[3], pos = pos}
  shots[#shots + 1] = {name = string.format("%02d-%s-day", i, it[1]), tick = t, pos = {pos[1], pos[2] - 1.5}, zoom = 3, daytime = 0.05}
  shots[#shots + 1] = {name = string.format("%02d-%s-night", i, it[1]), tick = t + 7, pos = {pos[1], pos[2] - 1.5}, zoom = 3, daytime = 0.5, hide_clouds = true}
  t = t + 14
end
local mid = {(cols - 1) * GAP / 2, GAP}
shots[#shots + 1] = {name = "00-all-day", tick = t, pos = mid, zoom = 0.45, daytime = 0.05}
shots[#shots + 1] = {name = "00-all-night", tick = t + 2, pos = mid, zoom = 0.45, daytime = 0.5, hide_clouds = true}
-- The ripple, over the projector, at three moments.
local ripples = {{tick = t + 30, pos = {0, -2}}}
for k, dt in ipairs({4, 12, 24}) do
  shots[#shots + 1] = {name = "01-kh-dome-ripple-" .. k, tick = t + 30 + dt, pos = {0, -2}, zoom = 2, daytime = 0.3}
end
return {name = "gallery", pad = {-10, -12, (cols - 1) * GAP + 10, 2 * GAP + 10}, build = build, ripples = ripples,
  shots = shots, resolution = {1280, 720}}
