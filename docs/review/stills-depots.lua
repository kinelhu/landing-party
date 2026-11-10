-- The factions' depots, launch pads and Grubstake's pole, modelled (phase 2 of the graphics pass): each beside the
-- other faction's and vanilla's own (a steel chest and a roboport for the depot's scale, the rocket silo for the pad's,
-- the medium pole for the pole's), day and night; three poles a faction, their wires on their posts (each row more than
-- a wire's reach from the next: the gallery makes every force friends, and rows 22 apart wired across).
--   scripts/film.sh gallery fresh.zip docs/review/stills-depots.lua
local build, shots = {}, {}
local function put(name, force, x, y) build[#build + 1] = {name = name, force = force, pos = {x, y}} end
put("lp-depot", "lp-serenity", 0, 0); put("lp-grubstake-depot", "lp-grubstake", 8, 0); put("roboport", "player", 16, 0)
put("steel-chest", "player", 21, 0)
put("lp-launchpad", "lp-serenity", 0, 16); put("lp-grubstake-launchpad", "lp-grubstake", 13, 16); put("rocket-silo", "player", 27, 16)
for j = 0, 2 do
  put("lp-pylon", "lp-serenity", j * 9, 44); put("lp-grubstake-pylon", "lp-grubstake", j * 9, 74)
  put("medium-electric-pole", "player", 40 + j * 6, 74)
end
shots[#shots + 1] = {name = "1-depots-day", tick = 200, pos = {10, 0}, zoom = 1.4, daytime = 0.05}
shots[#shots + 1] = {name = "1-depots-night", tick = 202, pos = {10, 0}, zoom = 1.4, daytime = 0.5, hide_clouds = true}
shots[#shots + 1] = {name = "2-pads-day", tick = 204, pos = {13, 15}, zoom = 0.75, daytime = 0.05}
shots[#shots + 1] = {name = "2-pads-night", tick = 206, pos = {13, 15}, zoom = 0.75, daytime = 0.5, hide_clouds = true}
shots[#shots + 1] = {name = "3-kh-poles", tick = 208, pos = {9, 42}, zoom = 1.2, daytime = 0.05}
shots[#shots + 1] = {name = "4-gs-poles", tick = 210, pos = {18, 72}, zoom = 0.9, daytime = 0.05}
shots[#shots + 1] = {name = "4-gs-poles-close", tick = 212, pos = {4.5, 72}, zoom = 2.2, daytime = 0.05}
shots[#shots + 1] = {name = "4-gs-poles-night", tick = 214, pos = {9, 72}, zoom = 1.2, daytime = 0.5, hide_clouds = true}
return {name = "depots", pad = {-8, -8, 56, 80}, tile = "grass-1", build = build, shots = shots, resolution = {1600, 1000}}
