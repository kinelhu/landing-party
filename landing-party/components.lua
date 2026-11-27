-- Faction components (docs/reviews/2026-10-15-faction-loot-consult.md, part B; the user: rare faction components the
-- player uses to research faction technology). Items, stack 10, no recipe: taken from the corporations' wrecks. What you
-- keep is paid once (a technology takes them only to research it, through a teardown); what you spend costs one each.
-- Grubstake's are smelly, cheap and many; Serenity's precise and few. Loaded after corps.lua, so each corporation's own
-- prototypes carry its own (Grubstake's are copies of Serenity's, made before this).
local shared = require("shared")
local SHEETS = require("__landing-party-graphics__.graphics.sheets")
-- The player's devices modelled (tools/blender/player_buildings.py; the user, 2026-11-10: "I still see some gross
-- recolors"): three had been drawn in the world with their items' icons, the bait as an empty barrel, the trade post a
-- tinted steel chest. A still body and shadow and its lights' frames (an entity that can animate), or the lights' first
-- frame (a container's picture is a sprite).
local function modelled(key, still)
  local S = SHEETS["player/" .. key].north
  local function f(part) return "__landing-party-graphics__/graphics/player/" .. key .. "/north-" .. part .. ".png" end
  local body = {filename = f("body"), width = S.width, height = S.height, scale = 0.5, shift = S.shift}
  local shadow = {filename = f("shadow"), width = S.width, height = S.height, scale = 0.5, shift = S.shift, draw_as_shadow = true}
  local glow = {filename = f("glow"), width = S.width / 2, height = S.height / 2, scale = 1, shift = S.shift, draw_as_glow = true,
    blend_mode = "additive"}
  if still then return {layers = {body, glow, shadow}} end
  if S.body_frames then
    -- (A body that moves, the claim marker's flag and the bait's cloud: its frames and its shadow's, the glow's count.)
    body.frame_count, body.line_length = S.body_frames, S.line_length
    shadow.frame_count, shadow.line_length = S.body_frames, S.line_length
  else
    body.repeat_count, shadow.repeat_count = S.frames, S.frames
  end
  glow.frame_count, glow.line_length, glow.animation_speed = S.frames, S.line_length, 0.15
  body.animation_speed, shadow.animation_speed = 0.15, 0.15
  return {layers = {body, glow, shadow}}
end

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
  table.insert(e.loot, {type = "item", name = item, independent_probability = p or 1, amount_min = min, amount_max = max})
end
add("radar", "lp-grubstake-pacifier", "lp-pheromone-gland", 3, 5)
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

-- Pheromone bait (Grubstake, three glands): a canister the player places, one gland each, calling the idle biters round
-- it (scripts/bait.lua). Not a military target: the corporations' turrets do not shoot it on sight.
data:extend(teardown("lp-pheromone-gland", 3, "lp-gland-schematic", "__base__/graphics/icons/poison-capsule.png",
  {r = 1, g = 0.85, b = 0.6, a = 1}))
data:extend({
  {type = "simple-entity-with-owner", name = "lp-player-bait", icon = "__base__/graphics/icons/poison-capsule.png",
    icon_size = 64, flags = {"placeable-neutral", "placeable-player", "player-creation", "placeable-off-grid"},
    max_health = 100, is_military_target = false, collision_box = {{-0.3, -0.3}, {0.3, 0.3}},
    selection_box = {{-0.5, -0.7}, {0.5, 0.4}}, dying_explosion = "explosion",
    animations = modelled("pheromone-bait")},
  {type = "item", name = "lp-bait", icons = {{icon = "__base__/graphics/icons/poison-capsule.png", tint = G}}, stack_size = 20,
    place_result = "lp-player-bait", subgroup = "lp-components", order = "y-bait"},
  {type = "recipe", name = "lp-bait", enabled = false, energy_required = 5,
    ingredients = {{type = "item", name = "lp-pheromone-gland", amount = 1}, {type = "item", name = "iron-plate", amount = 5}},
    results = {{type = "item", name = "lp-bait", amount = 1}}},
  {type = "technology", name = "lp-pheromone-bait", icon = "__base__/graphics/technology/military.png", icon_size = 256,
    prerequisites = {"military"}, research_trigger = {type = "craft-item", item = "lp-gland-schematic"},
    effects = {{type = "unlock-recipe", recipe = "lp-bait"}}},
})

-- Pact breaker (Grubstake, one crystal; after Pheromone bait) and claim marker (two crystals): devices the player places
-- (scripts/marker.lua). The breaker suspends Grubstake's pact for shared.BREAKER_MINUTES where it stands in a Grubstake
-- claim (a crystal each); the marker makes Grubstake leave the player's buildings within shared.CLAIM_MARK_RADIUS alone
-- (two crystals each). Their descriptions take those numbers as __1__.
data:extend(teardown("lp-pacifier-crystal", 1, "lp-crystal-schematic", "__base__/graphics/icons/advanced-circuit.png",
  {r = 1, g = 0.85, b = 0.6, a = 1}))
local function device(name, icon, health, extra)
  local d = {type = "simple-entity-with-owner", name = name, icons = {{icon = icon, tint = G}},
    flags = {"placeable-neutral", "placeable-player", "player-creation"}, max_health = health,
    minable = {mining_time = 0.5, result = name}, is_military_target = false,
    collision_box = {{-0.4, -0.4}, {0.4, 0.4}}, selection_box = {{-0.5, -0.5}, {0.5, 0.5}}, dying_explosion = "explosion",
    picture = {filename = icon, size = 64, scale = 0.5, tint = G}}
  for k, v in pairs(extra or {}) do d[k] = v end
  local key = name:gsub("^lp%-", "")
  if SHEETS["player/" .. key] then d.picture, d.animations = nil, modelled(key) end
  return d
end
local BREAKER_DESC = {"entity-description.lp-pact-breaker", tostring(shared.BREAKER_MINUTES)}
local MARKER_DESC = {"entity-description.lp-claim-marker", tostring(shared.CLAIM_MARK_RADIUS)}
data:extend({
  device("lp-pact-breaker", "__base__/graphics/icons/radar.png", 200, {minable = nil, localised_description = BREAKER_DESC}),
  device("lp-claim-marker", "__base__/graphics/icons/small-lamp.png", 300, {localised_description = MARKER_DESC}),
  {type = "item", name = "lp-pact-breaker", icons = {{icon = "__base__/graphics/icons/radar.png", tint = G}}, stack_size = 10,
    place_result = "lp-pact-breaker", subgroup = "lp-components", order = "y-breaker", localised_description = BREAKER_DESC},
  {type = "item", name = "lp-claim-marker", icons = {{icon = "__base__/graphics/icons/small-lamp.png", tint = G}},
    stack_size = 10, place_result = "lp-claim-marker", subgroup = "lp-components", order = "y-marker",
    localised_description = MARKER_DESC},
  {type = "recipe", name = "lp-pact-breaker", enabled = false, energy_required = 10,
    ingredients = {{type = "item", name = "lp-pacifier-crystal", amount = 1}, {type = "item", name = "electronic-circuit", amount = 10},
      {type = "item", name = "steel-plate", amount = 5}},
    results = {{type = "item", name = "lp-pact-breaker", amount = 1}}},
  {type = "recipe", name = "lp-claim-marker", enabled = false, energy_required = 10,
    ingredients = {{type = "item", name = "lp-pacifier-crystal", amount = 2}, {type = "item", name = "steel-plate", amount = 5}},
    results = {{type = "item", name = "lp-claim-marker", amount = 1}}},
  {type = "technology", name = "lp-pact-breaker", icon = "__base__/graphics/technology/military.png", icon_size = 256,
    prerequisites = {"lp-pheromone-bait"}, research_trigger = {type = "craft-item", item = "lp-crystal-schematic"},
    effects = {{type = "unlock-recipe", recipe = "lp-pact-breaker"}},
    localised_description = {"technology-description.lp-pact-breaker", tostring(shared.BREAKER_MINUTES)}},
  {type = "technology", name = "lp-claim-marker", icon = "__base__/graphics/technology/military.png", icon_size = 256,
    prerequisites = {"military"}, research_trigger = {type = "craft-item", item = "lp-crystal-schematic", count = 2},
    effects = {{type = "unlock-recipe", recipe = "lp-claim-marker"}},
    localised_description = {"technology-description.lp-claim-marker", tostring(shared.CLAIM_MARK_RADIUS)}},
})

-- Grubstake's claim stake (prospect.lua; Fable's notices consult): planted on a prospected patch, a signal post in its
-- colour with a lamp (drawn: amber, red in the last minutes); pulled down, the claim is off.
data:extend({
  {type = "simple-entity-with-force", name = "lp-claim-stake", icons = {{icon = "__base__/graphics/icons/rail-signal.png", tint = G}},
    flags = {"placeable-neutral", "placeable-off-grid"}, max_health = 150, is_military_target = false,
    collision_box = {{-0.3, -0.3}, {0.3, 0.3}}, selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    picture = {filename = "__base__/graphics/icons/rail-signal.png", size = 64, scale = 0.5, tint = G}},
})

-- Serenity's invoice post (ledger.lua): a steel chest in its colour, raised by script at its line, of the player's force
-- so the player can open it; no item, not minable, not destructible (set at creation).
local invoice = table.deepcopy(data.raw.container["steel-chest"])
invoice.name = "lp-invoice-post"
invoice.minable = nil
invoice.icons = {{icon = invoice.icon or invoice.icons[1].icon, icon_size = invoice.icon_size, tint = S}}
invoice.icon = nil
invoice.next_upgrade = nil
invoice.fast_replaceable_group = nil
invoice.localised_description = {"entity-description.lp-invoice-post", tostring(shared.INVOICE_GRACE)}
invoice.flags = {"placeable-neutral", "not-blueprintable", "not-deconstructable", "not-upgradable"}
if invoice.picture and invoice.picture.layers then
  for _, l in ipairs(invoice.picture.layers) do if not l.draw_as_shadow then l.tint = S end end
end
data:extend({invoice})

-- Grubstake's yard (skim.lua): where the skim's trucks and its raids leave what they took, a chest in its colour, made
-- by script (no item); what it holds spills when it dies.
for _, k in ipairs({{"lp-skim-yard", "steel-chest", 600}}) do
  local c = table.deepcopy(data.raw.container[k[2]])
  c.name = k[1]
  c.minable = nil
  c.max_health = k[3]
  c.icons = {{icon = c.icon or c.icons[1].icon, icon_size = c.icon_size, tint = G}}
  c.icon = nil
  c.next_upgrade = nil
  c.fast_replaceable_group = nil
  c.flags = {"placeable-neutral", "placeable-player", "player-creation", "not-blueprintable", "not-deconstructable"}
  c.is_military_target = true
  if c.picture and c.picture.layers then
    for _, l in ipairs(c.picture.layers) do if not l.draw_as_shadow then l.tint = G end end
  end
  data:extend({c})
end

-- Rail rifle (Serenity, two coils; after Military 3): the railgunner's weapon in the engineer's hands, a slug that
-- pierces a 30-tile line for 150 physical, every 90 ticks, its enemies only (the consult). Paid once in coils (the
-- research); the rifle and its slugs are ordinary crafts (a coil a slug would starve it: coils come from 1 railgunner
-- in 5).
data:extend(teardown("lp-rail-coil", 2, "lp-coil-schematic", "__base__/graphics/icons/copper-cable.png",
  {r = 0.9, g = 0.95, b = 1, a = 1}))
data:extend({
  {type = "ammo-category", name = "lp-rail"},
  {type = "gun", name = "lp-rail-rifle", icons = {{icon = "__base__/graphics/icons/submachine-gun.png", tint = S}},
    subgroup = "gun", order = "z[landing-party]-rail-rifle", stack_size = 5,
    localised_description = {"item-description.lp-rail-rifle", tostring(shared.RAIL_RANGE)},
    attack_parameters = {type = "projectile", ammo_category = "lp-rail", cooldown = 90, movement_slow_down_factor = 0.5,
      range = shared.RAIL_RANGE, sound = table.deepcopy(data.raw.gun["tank-cannon"].attack_parameters.sound)}},
  {type = "ammo", name = "lp-rail-slug", icons = {{icon = "__base__/graphics/icons/piercing-rounds-magazine.png", tint = S}},
    ammo_category = "lp-rail", magazine_size = 1, stack_size = 50, subgroup = "ammo", order = "z[landing-party]-rail-slug",
    localised_description = {"item-description.lp-rail-slug", tostring(shared.RAIL_RANGE)},
    ammo_type = {target_type = "direction", clamp_position = true, action = {type = "line", range = shared.RAIL_RANGE, width = 1.5,
      force = "enemy", action_delivery = {type = "instant",
        target_effects = {{type = "damage", damage = {amount = 150, type = "physical"}},
          {type = "create-entity", entity_name = "explosion-hit"}},
        source_effects = {type = "create-explosion", entity_name = "explosion-gunshot"}}}}},
  {type = "recipe", name = "lp-rail-rifle", enabled = false, energy_required = 10,
    ingredients = {{type = "item", name = "steel-plate", amount = 10}, {type = "item", name = "advanced-circuit", amount = 5},
      {type = "item", name = "copper-cable", amount = 20}},
    results = {{type = "item", name = "lp-rail-rifle", amount = 1}}},
  {type = "recipe", name = "lp-rail-slug", enabled = false, energy_required = 2,
    ingredients = {{type = "item", name = "steel-plate", amount = 1}, {type = "item", name = "copper-cable", amount = 3}},
    results = {{type = "item", name = "lp-rail-slug", amount = 1}}},
  {type = "technology", name = "lp-rail-rifle", icon = "__base__/graphics/technology/military.png", icon_size = 256,
    prerequisites = {"military-3"}, research_trigger = {type = "craft-item", item = "lp-coil-schematic"},
    effects = {{type = "unlock-recipe", recipe = "lp-rail-rifle"}, {type = "unlock-recipe", recipe = "lp-rail-slug"}},
    localised_description = {"technology-description.lp-rail-rifle", tostring(shared.RAIL_RANGE)}},
})

-- Orbital strike (Serenity, one beacon; after the rocket silo): a strike beacon the player places on power, charging
-- 50 MJ at up to 5 MW, then calling the orbital barrage within shared.STRIKE_RADIUS (scripts/strike.lua). One orbital beacon each.
data:extend(teardown("lp-orbital-beacon", 1, "lp-beacon-schematic", "__base__/graphics/icons/beacon.png",
  {r = 0.9, g = 0.95, b = 1, a = 1}))
data:extend({
  {type = "electric-energy-interface", name = "lp-strike-beacon", icons = {{icon = "__base__/graphics/icons/beacon.png", tint = S}},
    flags = {"placeable-neutral", "placeable-player", "player-creation"}, max_health = 300,
    collision_box = {{-0.7, -0.7}, {0.7, 0.7}}, selection_box = {{-1, -1}, {1, 1}}, dying_explosion = "medium-explosion",
    picture = {filename = "__base__/graphics/icons/beacon.png", size = 64, scale = 0.9, tint = S}, gui_mode = "none",
    energy_source = {type = "electric", usage_priority = "secondary-input", buffer_capacity = "50MJ",
      input_flow_limit = "5MW", output_flow_limit = "0W"},
    energy_production = "0W", energy_usage = "0W",
    localised_description = {"entity-description.lp-strike-beacon", tostring(shared.STRIKE_RADIUS)}},
  {type = "item", name = "lp-strike-beacon", localised_description = {"entity-description.lp-strike-beacon",
    tostring(shared.STRIKE_RADIUS)}, icons = {{icon = "__base__/graphics/icons/beacon.png", tint = S}},
    stack_size = 5, place_result = "lp-strike-beacon", subgroup = "lp-components", order = "y-strike"},
  {type = "recipe", name = "lp-strike-beacon", enabled = false, energy_required = 30,
    ingredients = {{type = "item", name = "lp-orbital-beacon", amount = 1}, {type = "item", name = "processing-unit", amount = 10},
      {type = "item", name = "steel-plate", amount = 20}},
    results = {{type = "item", name = "lp-strike-beacon", amount = 1}}},
  {type = "technology", name = "lp-orbital-strike", icon = "__base__/graphics/technology/military.png", icon_size = 256,
    prerequisites = {"rocket-silo"}, research_trigger = {type = "craft-item", item = "lp-beacon-schematic"},
    effects = {{type = "unlock-recipe", recipe = "lp-strike-beacon"}},
    localised_description = {"technology-description.lp-orbital-strike", tostring(shared.STRIKE_RADIUS)}},
})

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
shell.localised_description = {"item-description.lp-cluster-artillery-shell", tostring(shared.CLUSTER_BOMBLETS)}
shell.ammo_type.action.action_delivery.projectile = "lp-cluster-artillery-projectile"
local projectile = table.deepcopy(data.raw["artillery-projectile"]["artillery-projectile"])
projectile.name = "lp-cluster-artillery-projectile"
projectile.action = {projectile.action, {type = "cluster", cluster_count = shared.CLUSTER_BOMBLETS, distance = 6, distance_deviation = 3,
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
