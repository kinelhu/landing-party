-- The buildings redone on 2026-11-04 (no plinth slab, more colour, the new barracks and muster point) on four grounds,
-- by day, and on grass by night. scripts/film.sh gallery fresh.zip docs/review/stills-ground.lua
local GROUNDS = {"refined-concrete", "grass-1", "sand-1", "dirt-4"}
local list = {
  {"kh-dome-projector", "lp-dome-projector", "lp-serenity"},
  {"kh-jammer", "lp-jammer", "lp-serenity"},
  {"kh-orbital-relay", "lp-orbital-relay", "lp-serenity"},
  {"kh-pacifier", "lp-pacifier", "lp-serenity"},
  {"gs-pacifier", "lp-grubstake-pacifier", "lp-grubstake"},
  {"pl-barracks", "lp-barracks", "player"},
  {"pl-muster-point", "lp-muster-point", "player"},
}
local GAP = 14
local build, shots = {}, {}
local t = 180
for i, it in ipairs(list) do
  for j, g in ipairs(GROUNDS) do
    local pos = {(j - 1) * GAP, (i - 1) * GAP}
    build[#build + 1] = {name = it[2], force = it[3], pos = pos, ground = g}
    shots[#shots + 1] = {name = string.format("%02d-%s-%d-%s", i, it[1], j, g), tick = t, pos = {pos[1], pos[2] - 1.5},
      zoom = 3, daytime = 0.05}
    t = t + 3
  end
  local pos = {GAP, (i - 1) * GAP}
  shots[#shots + 1] = {name = string.format("%02d-%s-night", i, it[1]), tick = t, pos = {pos[1], pos[2] - 1.5}, zoom = 3,
    daytime = 0.5, hide_clouds = true}
  t = t + 3
end
return {name = "ground", pad = {-8, -8, 3 * GAP + 8, (#list - 1) * GAP + 8}, tile = "grass-1", build = build,
  shots = shots, resolution = {1280, 720}}
