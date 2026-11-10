-- The factions' modelled buildings at game scale (the graphics pass, phase 2: fabricators, generators, radars, turrets,
-- flamers, Kessler-Hayashi's drill and pylon; judged so far only as renders), each row beside vanilla's own for scale:
-- Kessler-Hayashi's row, Grubstake's, vanilla's. Day and night stills, close and wide. Then the action: the factions'
-- forces turned against the biters and a small biter set by each flamer (its stream from the nozzle?), and the player's
-- flak turret against a Grubstake harrier (the buggy's black puffs, 0.2.315); the pylons' wires.
--   scripts/film.sh gallery fresh.zip docs/review/stills-factions.lua
local GAP = 11
local rows = {
  {y = 0, force = "lp-serenity", list = {"lp-lander", "lp-fabricator", "lp-generator", "lp-radar", "lp-drill", "lp-turret",
    "lp-gun-turret", "lp-flamer", "lp-depot", "lp-launchpad", "lp-lamp"}},
  {y = 22, force = "lp-grubstake", list = {"lp-grubstake-lander", "lp-grubstake-fabricator", "lp-grubstake-generator",
    "lp-radar", "lp-grubstake-drill", "lp-grubstake-turret", "lp-grubstake-scrap-cannon", "lp-grubstake-flamer",
    "lp-grubstake-depot", "lp-grubstake-launchpad", "lp-grubstake-lamp"}},
  {y = 44, force = "player", list = {"crash-site-spaceship", "assembling-machine-2", "accumulator", "radar",
    "electric-mining-drill", "laser-turret", "gun-turret", "flamethrower-turret", "steel-chest", "iron-chest", "small-lamp"}},
}
local build, shots = {}, {}
for _, r in ipairs(rows) do
  for i, name in ipairs(r.list) do
    local x = (i - 1) * GAP + (i > 1 and 6 or 0)
    build[#build + 1] = {name = name, force = r.force, pos = {x, r.y}, dir = defines.direction.south}
  end
end
-- Pylons, three a row, 9 apart (their wires meet their posts?), and the vanilla big pole's, behind the rows.
local POLE = {"lp-pylon", "lp-grubstake-pylon", "big-electric-pole"}
for k, r in ipairs(rows) do
  for j = 0, 2 do build[#build + 1] = {name = POLE[k], force = r.force, pos = {130 + j * 9, r.y}} end
end
-- The flak turret, the player's, apart; its harrier comes in from the east.
local FLAK = {40, 72}
build[#build + 1] = {name = "lp-flak-turret", force = "player", pos = FLAK}
local W = 160
local t = 200
for k, r in ipairs(rows) do
  shots[#shots + 1] = {name = string.format("%d-row-day", k), tick = t, pos = {W / 2 - 25, r.y}, zoom = 0.55, daytime = 0.05}
  shots[#shots + 1] = {name = string.format("%d-row-night", k), tick = t + 2, pos = {W / 2 - 25, r.y}, zoom = 0.55,
    daytime = 0.5, hide_clouds = true}
  for half = 0, 1 do
    shots[#shots + 1] = {name = string.format("%d-close-%d", k, half), tick = t + 4 + half, pos = {half * 60 + 22, r.y},
      zoom = 1.1, daytime = 0.05}
  end
  shots[#shots + 1] = {name = string.format("%d-pylons", k), tick = t + 6, pos = {139, r.y - 3}, zoom = 1.2, daytime = 0.05}
  t = t + 10
end
shots[#shots + 1] = {name = "0-all", tick = t, pos = {72, 26}, zoom = 0.3, daytime = 0.05}
-- The action, from ACT: flamers (column 8) and the flak.
local ACT = 420   -- (each runs every 60 ticks)
for f = 0, 23 do
  shots[#shots + 1] = {name = string.format("5-flamers-%02d", f), tick = ACT + 30 + f * 5, pos = {83, 11}, zoom = 0.9,
    daytime = 0.05}
end
for f = 0, 39 do
  shots[#shots + 1] = {name = string.format("6-flak-%02d", f), tick = ACT + 60 + f * 6, pos = {FLAK[1] + 6, FLAK[2] - 3},
    zoom = 1.0, daytime = 0.05}
end
local function each(tick)
  if tick ~= ACT then return end
  local s = game.surfaces[1]
  for _, a in ipairs({"lp-serenity", "lp-grubstake"}) do
    for _, b in ipairs({"enemy"}) do
      game.forces[a].set_friend(b, false); game.forces[b].set_friend(a, false)
      game.forces[a].set_cease_fire(b, false); game.forces[b].set_cease_fire(a, false)
    end
  end
  game.forces.player.set_friend("lp-grubstake", false); game.forces["lp-grubstake"].set_friend("player", false)
  game.forces.player.set_cease_fire("lp-grubstake", false); game.forces["lp-grubstake"].set_cease_fire("player", false)
  for _, f in ipairs(s.find_entities_filtered{type = "fluid-turret"}) do
    f.insert_fluid{name = "light-oil", amount = 100}
    s.create_entity{name = "small-biter", position = {f.position.x + 7, f.position.y + 4}, force = "enemy"}
  end
  for k = 0, 1 do
    local h = s.create_entity{name = "lp-grubstake-harrier", position = {FLAK[1] + 24, FLAK[2] - 4 + k * 3}, force = "lp-grubstake"}
    if h then h.commandable.set_command{type = defines.command.go_to_location, destination = {FLAK[1] - 20, FLAK[2]}} end
  end
end
return {name = "factions", pad = {-12, -14, W + 6, 82}, tile = "grass-1", build = build, shots = shots,
  resolution = {1920, 1080}, each = each}
