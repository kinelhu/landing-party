-- Vanilla's sun (lpkit.SUN_DIR, 0.2.319): every building the kit made re-rendered, its shadow falling where vanilla's do,
-- each beside vanilla's of its kind; and the denser depots and launch pads beside vanilla's cargo pad and silo. Each row
-- twice, on grass and on desert (the user's ratings: judge on the ground it stands on), day; the pads at night too.
--   scripts/film.sh gallery fresh.zip docs/review/stills-shadows.lua
local rows = {
  {"assembling-machine-2", "lp-fabricator", "lp-grubstake-fabricator", "accumulator", "lp-generator", "lp-grubstake-generator",
   "radar", "lp-radar", "lp-grubstake-radar", "electric-mining-drill", "lp-drill", "lp-strip-drill"},
  {"gun-turret", "lp-turret", "lp-gun-turret", "lp-grubstake-turret", "flamethrower-turret", "lp-flamer", "lp-grubstake-flamer",
   "lp-flak-turret", "medium-electric-pole", "lp-pylon", "lp-grubstake-pylon", "lp-rally-beacon"},
  {"lp-barracks", "lp-muster-point", "lp-command-relay", "lp-threat-scanner",
   "lp-claim-marker", "lp-pact-breaker", "lp-player-bait", "lp-jammer", "lp-orbital-relay", "lp-pacifier"},
}
local FORCE = function(n)
  if n:find("grubstake") then return "lp-grubstake" end
  if n == "lp-fabricator" or n == "lp-generator" or n == "lp-radar" or n == "lp-drill" or n == "lp-turret" or n == "lp-gun-turret"
    or n == "lp-flamer" or n == "lp-pylon" or n == "lp-jammer" or n == "lp-orbital-relay" or n == "lp-pacifier" then return "lp-serenity" end
  return "player"
end
local GAP, ROWY = 7, 10
local build, shots = {}, {}
local GROUND = {{"grass-1", 0}, {"red-desert-0", 40}}
for _, g in ipairs(GROUND) do
  for r, row in ipairs(rows) do
    for i, n in ipairs(row) do
      build[#build + 1] = {name = n, force = FORCE(n), pos = {(i - 1) * GAP, g[2] + (r - 1) * ROWY}, ground = g[1], ground_r = 4}
    end
  end
end
-- The pads: vanilla's silo and cargo pad's scale beside the four, on grass and desert.
local PADS = {{"rocket-silo", "player"}, {"lp-launchpad", "lp-serenity"}, {"lp-grubstake-launchpad", "lp-grubstake"},
  {"roboport", "player"}, {"lp-depot", "lp-serenity"}, {"lp-grubstake-depot", "lp-grubstake"}}
for gi, g in ipairs(GROUND) do
  for i, p in ipairs(PADS) do
    build[#build + 1] = {name = p[1], force = p[2], pos = {100 + (i - 1) * 12, g[2] + 5}, ground = g[1], ground_r = 7}
  end
end
local t = 200
for gi, g in ipairs(GROUND) do
  for r = 1, #rows do
    for half = 0, 1 do
      shots[#shots + 1] = {name = string.format("%d-%s-row%d-%d", gi, g[1], r, half), tick = t, pos = {half * 42 + 17, g[2] + (r - 1) * ROWY},
        zoom = 0.95, daytime = 0.05}
      t = t + 2
    end
  end
  shots[#shots + 1] = {name = string.format("%d-%s-pads-day", gi, g[1]), tick = t, pos = {130, g[2] + 5}, zoom = 0.55, daytime = 0.05}
  shots[#shots + 1] = {name = string.format("%d-%s-pads-night", gi, g[1]), tick = t + 2, pos = {130, g[2] + 5}, zoom = 0.55,
    daytime = 0.5, hide_clouds = true}
  t = t + 4
end
return {name = "shadows", pad = {-6, -8, 170, 70}, tile = "grass-1", build = build, shots = shots, resolution = {1920, 1080}}
