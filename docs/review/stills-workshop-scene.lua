-- Grubstake's Workshop in a scene of its own, for the mod page's gallery (0.2.496): the Workshop, its fabricator and
-- depot, pylons and a few of its units, by day; its welder drawn as base.lab_look draws it.
--   FILM_MUTE=1 scripts/film.sh gallery fresh.zip docs/review/stills-workshop-scene.lua docs/sim/film-workshop-scene
local G = "lp-grubstake"
local build = {
  {name = "lp-grubstake-siege-lab", force = G, pos = {0, 0}}, {name = "lp-grubstake-fabricator", force = G, pos = {6.5, -1.5}},
  {name = "lp-grubstake-depot", force = G, pos = {-6, -1}},   -- (no pylons: a wire crossed the Workshop's roof)
  {name = "lp-grubstake-buggy", force = G, pos = {4, 5}}, {name = "lp-grubstake-buggy", force = G, pos = {7, 4}},
  {name = "lp-shotgun-hand", force = G, pos = {-2, 5.5}}, {name = "lp-shotgun-hand", force = G, pos = {-0.5, 6}},
  {name = "lp-shotgun-hand", force = G, pos = {-3.5, 6.5}},
}
local drawn = false
local function each(tick)
  if drawn or tick < 60 then return end
  drawn = true
  for _, e in pairs(game.surfaces[1].find_entities_filtered{name = "lp-grubstake-siege-lab"}) do
    rendering.draw_animation{animation = "lp-grubstake-siege-lab-busy", target = e, surface = e.surface, render_layer = "object",
      animation_speed = 1 / 2}
  end
end
local shots = {}
for k = 0, 3 do
  shots[#shots + 1] = {name = string.format("workshop-scene-%d", k), tick = 200 + k * 5, pos = {0.5, 1}, zoom = 2.0, daytime = 0.1}
end
return {name = "workshopscene", pad = {-14, -10, 14, 10}, tile = "dirt-4", build = build, each = each, shots = shots,
  resolution = {1920, 1080}}
