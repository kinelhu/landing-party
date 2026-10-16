-- Faction components (docs/reviews/2026-10-15-faction-loot-consult.md, part B; the user: rare faction components the
-- player uses to research faction technology). Items, stack 10, no recipe: taken from the corporations' wrecks. What you
-- keep is paid once (a technology takes them only to research it, through a teardown); what you spend costs one each.
-- Grubstake's are smelly, cheap and many; Serenity's precise and few. Loaded after corps.lua, so each corporation's own
-- prototypes carry its own (Grubstake's are copies of Serenity's, made before this).
local shared = require("shared")

local G, S = shared.CORPS.grubstake.tint, {r = 0.62, g = 0.8, b = 1, a = 1}
local COMPONENTS = {
  {"lp-pheromone-gland", "__base__/graphics/icons/poison-capsule.png", G, "a"},
  {"lp-pacifier-crystal", "__base__/graphics/icons/advanced-circuit.png", G, "b"},
  {"lp-drill-head", "__base__/graphics/icons/iron-gear-wheel.png", G, "c"},
  {"lp-rail-coil", "__base__/graphics/icons/copper-cable.png", S, "d"},
  {"lp-cluster-fuze", "__base__/graphics/icons/cluster-grenade.png", S, "e"},
  {"lp-orbital-beacon", "__base__/graphics/icons/beacon.png", S, "f"},
}
local out = {{type = "item-subgroup", name = "lp-components", group = "intermediate-products", order = "z[landing-party]"}}
for _, c in ipairs(COMPONENTS) do
  table.insert(out, {type = "item", name = c[1], icons = {{icon = c[2], tint = c[3]}}, stack_size = 10,
    subgroup = "lp-components", order = c[4]})
end
data:extend(out)

-- Where each comes from: added to the engine's loot of the corporation's own prototype (100% unless said). The
-- pacifier crystal is scripted (pact.lua): the landing's own pacifier always, a rebuilt one a quarter of the time.
local function add(type, name, item, min, max, p)
  local e = data.raw[type][name]
  e.loot = e.loot or {}
  table.insert(e.loot, {item = item, probability = p or 1, count_min = min, count_max = max})
end
add("radar", "lp-grubstake-pacifier", "lp-pheromone-gland", 3, 5)
add("simple-entity-with-force", "lp-flare", "lp-pheromone-gland", 1, 1)
add("simple-entity-with-force", "lp-claim-rig", "lp-drill-head", 2, 2)
add("unit", "lp-railgunner", "lp-rail-coil", 1, 1, 0.2)
add("artillery-turret", "lp-mortar", "lp-cluster-fuze", 1, 1)
add("artillery-turret", "lp-howitzer", "lp-cluster-fuze", 6, 6)
add("electric-energy-interface", "lp-lander", "lp-orbital-beacon", 1, 1)
add("radar", "lp-uplink", "lp-orbital-beacon", 2, 2)

-- Teardowns: a component taken apart on the bench ("X, disassembled") is what a faction technology's research trigger
-- asks for (craft-item). Its product is the schematic, kept by nobody: the trigger is the point.
local function teardown(component, n, schematic, icon, tint)
  return {
    {type = "item", name = schematic, icons = {{icon = icon, tint = tint}}, stack_size = 10, subgroup = "lp-components",
      order = "z-" .. schematic},
    {type = "recipe", name = schematic, enabled = true, energy_required = 10, subgroup = "lp-components",
      ingredients = {{type = "item", name = component, amount = n}}, results = {{type = "item", name = schematic, amount = 1}}},
  }
end

-- Cluster shells (Serenity, three fuzes): the player's artillery shell with a fuze, bursting into ten bomblets of its own
-- (Serenity's, 12 over 1.5 tiles, six of them, killed none of a ring of small biters at 7: 15 health). Its enemies only.
local player_bomblet = table.deepcopy(data.raw.projectile["lp-bomblet"])
player_bomblet.name = "lp-player-bomblet"
player_bomblet.action[2].radius = 2
player_bomblet.action[2].action_delivery.target_effects[1].damage.amount = 25
local shell = table.deepcopy(data.raw.ammo["artillery-shell"])
shell.name = "lp-cluster-artillery-shell"
shell.icons = {{icon = shell.icon or shell.icons[1].icon, icon_size = shell.icon_size, tint = S}}
shell.icon = nil
shell.order = (shell.order or "") .. "-lp-cluster"
shell.ammo_type.action.action_delivery.projectile = "lp-cluster-artillery-projectile"
local projectile = table.deepcopy(data.raw["artillery-projectile"]["artillery-projectile"])
projectile.name = "lp-cluster-artillery-projectile"
projectile.action = {projectile.action, {type = "cluster", cluster_count = 10, distance = 6, distance_deviation = 3,
  action_delivery = {type = "projectile", projectile = "lp-player-bomblet", direction_deviation = 0.6, starting_speed = 0.25,
    starting_speed_deviation = 0.3}}}
data:extend(teardown("lp-cluster-fuze", 3, "lp-fuze-schematic", "__base__/graphics/icons/cluster-grenade.png",
  {r = 0.9, g = 0.95, b = 1, a = 1}))
data:extend({shell, projectile, player_bomblet,
  {type = "recipe", name = "lp-cluster-artillery-shell", enabled = false, energy_required = 15,
    ingredients = {{type = "item", name = "artillery-shell", amount = 1}, {type = "item", name = "lp-cluster-fuze", amount = 1}},
    results = {{type = "item", name = "lp-cluster-artillery-shell", amount = 1}}},
  {type = "technology", name = "lp-cluster-shells", icon = "__base__/graphics/technology/artillery.png", icon_size = 256,
    prerequisites = {"artillery"}, research_trigger = {type = "craft-item", item = "lp-fuze-schematic"},
    effects = {{type = "unlock-recipe", recipe = "lp-cluster-artillery-shell"}}},
})
