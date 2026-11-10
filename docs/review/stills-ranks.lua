-- Rank badges in game (veterancy.lua: one to three gold chevrons, 0.2.311): the player's trooper and tank, Kessler-Hayashi's
-- infantry and tank, Grubstake's infantry and buggy, each at Veteran, Elite and Heroic (merit 3, 8, 16, debug_promote),
-- a normal one beside them. Day and night.
--   scripts/film.sh gallery fresh.zip docs/review/stills-ranks.lua
local rows = {{"lp-trooper", "player"}, {"lp-battle-tank", "player"}, {"lp-infantry", "lp-serenity"}, {"lp-tank", "lp-serenity"},
  {"lp-grubstake-infantry", "lp-grubstake"}, {"lp-buggy", "lp-grubstake"}}
local MERIT = {0, 3, 8, 16}
local build = {}
for r, row in ipairs(rows) do
  for c = 1, 4 do build[#build + 1] = {name = row[1], force = row[2], pos = {(c - 1) * 4, (r - 1) * 4}} end
end
local done = false
local function each(tick)
  -- (Once, at the first call past 100: each runs every 60 ticks, not on a multiple of 60.)
  if done or tick < 100 then return end
  done = true
  for _, e in ipairs(game.surfaces[1].find_entities_filtered{type = "unit", area = {{-3, -3}, {16, 24}}}) do
    local c = math.floor(e.position.x / 4 + 0.5) + 1
    if MERIT[c] and MERIT[c] > 0 then remote.call("landing-party", "debug_promote", e.unit_number, MERIT[c]) end
  end
end
return {name = "ranks", pad = {-6, -6, 20, 26}, tile = "grass-1", build = build, each = each, resolution = {1280, 1280},
  shots = {{name = "ranks-day", tick = 240, pos = {6, 9.5}, zoom = 1.6, daytime = 0.05, hide_clouds = true},
    {name = "ranks-night", tick = 244, pos = {6, 9.5}, zoom = 1.6, daytime = 0.5, hide_clouds = true}}}
