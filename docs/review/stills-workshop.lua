-- Grubstake's Workshop, modelled (0.2.496; faction_works.py workshop gs, a Quonset hut, the user: "Perhaps real material
-- now"): beside Grubstake's fabricator and depot, Kessler-Hayashi's Siege works and vanilla's lab, on grass and on sand,
-- by day and at night; its busy animation drawn as base.lab_look draws it (the gallery's buildings belong to no camp).
--   scripts/film.sh gallery fresh.zip docs/review/stills-workshop.lua docs/sim/film-workshop
local build, shots = {}, {}
local function put(name, force, x, y, ground) build[#build + 1] = {name = name, force = force, pos = {x, y}, ground = ground, ground_r = ground and 14} end
put("lp-grubstake-siege-lab", "lp-grubstake", 0, 0); put("lp-grubstake-fabricator", "lp-grubstake", 7, 0)
put("lp-grubstake-depot", "lp-grubstake", 12, 0); put("lab", "player", -6, 0); put("lp-siege-lab", "lp-serenity", -12, 0)
put("lp-grubstake-siege-lab", "lp-grubstake", 0, 30, "sand-1"); put("lp-grubstake-fabricator", "lp-grubstake", 7, 30)
put("lab", "player", -6, 30)
local drawn = false
local function each(tick)
  if drawn or tick < 60 then return end
  drawn = true
  for _, e in pairs(game.surfaces[1].find_entities_filtered{name = "lp-grubstake-siege-lab"}) do
    rendering.draw_animation{animation = "lp-grubstake-siege-lab-busy", target = e, surface = e.surface, render_layer = "object",
      animation_speed = 1 / 2}
    rendering.draw_light{sprite = "utility/light_medium", target = {entity = e, offset = {-0.3, 1.2}}, surface = e.surface,
      color = {r = 1, g = 0.7, b = 0.35}, intensity = 0.5, scale = 1.0, minimum_darkness = 0.3}
  end
end
shots[#shots + 1] = {name = "1-grass-day", tick = 200, pos = {0, 0}, zoom = 1.0, daytime = 0.05}
shots[#shots + 1] = {name = "2-grass-close", tick = 203, pos = {0, -0.5}, zoom = 2.0, daytime = 0.05}
shots[#shots + 1] = {name = "3-grass-night", tick = 206, pos = {0, 0}, zoom = 1.4, daytime = 0.5, hide_clouds = true}
shots[#shots + 1] = {name = "4-sand-day", tick = 209, pos = {0, 30}, zoom = 1.4, daytime = 0.05}
for k = 0, 5 do
  shots[#shots + 1] = {name = string.format("5-weld-%d", k), tick = 212 + k * 3, pos = {-0.3, 1}, zoom = 3.0, daytime = 0.05}
end
return {name = "workshop", pad = {-18, -10, 20, 40}, tile = "grass-1", build = build, each = each, shots = shots,
  resolution = {1600, 1000}}
