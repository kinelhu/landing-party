-- The player's side: a barracks that trains troopers from items, and a rally beacon whose circuit signals
-- set their stance (scripts/command.lua). Unlocked from the start while this is a prototype.
local shared = require("shared")

local barracks = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
barracks.name = "lp-barracks"
barracks.minable = {mining_time = 0.5, result = "lp-barracks"}
barracks.next_upgrade = nil
barracks.fast_replaceable_group = nil
barracks.crafting_categories = {"lp-training"}
-- No fixed recipe: troopers, breachers or battle tanks (a new barracks starts on troopers).
barracks.module_slots = 0
barracks.allowed_effects = nil

-- The command relay: a radar's body; each powered relay carries shared.RELAY_CAPACITY units of command
-- bandwidth, as many relays counting as the research allows (scripts/command.lua).
local relay = table.deepcopy(data.raw.radar.radar)
relay.name = "lp-command-relay"
relay.minable = {mining_time = 0.5, result = "lp-command-relay"}
relay.next_upgrade = nil
relay.energy_usage = "2MW"
relay.max_distance_of_sector_revealed = 0
relay.max_distance_of_nearby_sector_revealed = 3

-- The rally beacon: a constant combinator. Its own signals give orders (opened like any combinator); wired, it
-- reads its network as well, for automation. A small lamp with a combinator wired to it once confused the
-- first player to try it.
local beacon = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
beacon.name = "lp-rally-beacon"
beacon.icon = "__base__/graphics/icons/small-lamp.png"
beacon.minable = {mining_time = 0.2, result = "lp-rally-beacon"}
beacon.next_upgrade = nil
beacon.fast_replaceable_group = nil

local function item(name, icon, place)
  return {type = "item", name = name, icon = icon, stack_size = 10, place_result = place, subgroup = "defensive-structure",
    order = "z[landing-party]-" .. name}
end

data:extend({
  barracks, beacon, relay,
  item("lp-command-relay", "__base__/graphics/icons/radar.png", "lp-command-relay"),
  -- Salvaged from the faction (a depot destroyed, an outpost captured, a lander destroyed) or granted once by
  -- research: what a barracks is built around. Not craftable.
  {type = "item", name = "lp-command-core", icon = "__base__/graphics/icons/processing-unit.png", stack_size = 10,
    subgroup = "intermediate-product", order = "z[landing-party]-core"},
  {type = "recipe-category", name = "lp-training"},
  item("lp-barracks", "__base__/graphics/icons/assembling-machine-2.png", "lp-barracks"),
  item("lp-rally-beacon", "__base__/graphics/icons/small-lamp.png", "lp-rally-beacon"),
  {type = "item", name = "lp-trooper-order", icon = "__base__/graphics/icons/firearm-magazine.png", hidden = true,
    stack_size = 10, subgroup = "other"},
  {type = "recipe", name = "lp-barracks", enabled = false, energy_required = 5,
    ingredients = {{type = "item", name = "assembling-machine-2", amount = 1}, {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "electronic-circuit", amount = 10}, {type = "item", name = "lp-command-core", amount = 1}},
    results = {{type = "item", name = "lp-barracks", amount = 1}}},
  {type = "recipe", name = "lp-command-relay", enabled = false, energy_required = 10,
    ingredients = {{type = "item", name = "radar", amount = 1}, {type = "item", name = "electronic-circuit", amount = 20},
      {type = "item", name = "steel-plate", amount = 10}},
    results = {{type = "item", name = "lp-command-relay", amount = 1}}},
  {type = "recipe", name = "lp-rally-beacon", enabled = false, energy_required = 2,
    ingredients = {{type = "item", name = "small-lamp", amount = 1}, {type = "item", name = "electronic-circuit", amount = 2}},
    results = {{type = "item", name = "lp-rally-beacon", amount = 1}}},
  -- Units are made of the engineer's own kit (personal equipment, rarely automated: a fresh logistics chain,
  -- user 2026-10-13): a trooper is heavy armour, a submachine gun and magazines.
  {type = "recipe", name = "lp-trooper-order", category = "lp-training", enabled = false, hidden_in_factoriopedia = true,
    -- 30 s a trooper: even at the cap, a lost army takes time to replace.
    energy_required = 30,
    ingredients = {{type = "item", name = "heavy-armor", amount = 1}, {type = "item", name = "submachine-gun", amount = 1},
      {type = "item", name = "firearm-magazine", amount = 10}},
    results = {{type = "item", name = "lp-trooper-order", amount = 1}}},
  -- Salvage from a fallen settlement's ruins, reclaimed in any assembler.
  {type = "item", name = "lp-salvage", icon = "__base__/graphics/icons/iron-gear-wheel.png", stack_size = 100,
    subgroup = "intermediate-product", order = "z[landing-party]-salvage"},
  {type = "recipe", name = "lp-salvage", enabled = true, energy_required = 2,
    icon = "__base__/graphics/icons/iron-gear-wheel.png", subgroup = "intermediate-product",
    ingredients = {{type = "item", name = "lp-salvage", amount = 1}},
    results = {{type = "item", name = "iron-plate", amount = 4}, {type = "item", name = "copper-plate", amount = 2},
      {type = "item", name = "electronic-circuit", amount = 1}}},
  {type = "item", name = "lp-breacher-order", icon = "__base__/graphics/icons/grenade.png", hidden = true,
    stack_size = 10, subgroup = "other"},
  {type = "recipe", name = "lp-breacher-order", category = "lp-training", enabled = false, hidden_in_factoriopedia = true,
    icon = "__base__/graphics/icons/grenade.png", energy_required = 30,
    ingredients = {{type = "item", name = "heavy-armor", amount = 1}, {type = "item", name = "grenade", amount = 10},
      {type = "item", name = "electronic-circuit", amount = 5}},
    results = {{type = "item", name = "lp-breacher-order", amount = 1}}},
  {type = "item", name = "lp-battle-tank-order", icon = "__base__/graphics/icons/tank.png", hidden = true,
    stack_size = 10, subgroup = "other"},
  {type = "recipe", name = "lp-battle-tank-order", category = "lp-training", enabled = false, hidden_in_factoriopedia = true,
    icon = "__base__/graphics/icons/tank.png", energy_required = 120,
    ingredients = {{type = "item", name = "tank", amount = 1}, {type = "item", name = "cannon-shell", amount = 20},
      {type = "item", name = "battery-equipment", amount = 2}},
    results = {{type = "item", name = "lp-battle-tank-order", amount = 1}}},
})

-- Command bandwidth: how many relays count. Level 1 unlocks the army and grants the first command core.
local function tech(level, prereq, packs, count, effects, extra)
  local t = {type = "technology", name = "lp-command-bandwidth-" .. level, icon = "__base__/graphics/technology/radar.png",
    icon_size = 256, prerequisites = prereq, effects = effects or {},
    unit = {count = count, time = 30, ingredients = packs}, upgrade = level > 1}
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end
local red, green = {"automation-science-pack", 1}, {"logistic-science-pack", 1}
local blue, grey = {"chemical-science-pack", 1}, {"military-science-pack", 1}
data:extend({
  tech(1, {"military-2", "heavy-armor"}, {red, green}, 100, {
    {type = "unlock-recipe", recipe = "lp-barracks"}, {type = "unlock-recipe", recipe = "lp-command-relay"},
    {type = "unlock-recipe", recipe = "lp-rally-beacon"}, {type = "unlock-recipe", recipe = "lp-trooper-order"},
    {type = "unlock-recipe", recipe = "lp-breacher-order"}, {type = "give-item", item = "lp-command-core", count = 1}}),
  -- Battle tanks with the second level, once the player has tanks of their own.
  tech(2, {"lp-command-bandwidth-1", "chemical-science-pack", "tank", "battery-equipment"}, {red, green, blue}, 200, {
    {type = "unlock-recipe", recipe = "lp-battle-tank-order"}}),
  tech(3, {"lp-command-bandwidth-2", "military-3"}, {red, green, blue, grey}, 300),
  tech(4, {"lp-command-bandwidth-3"}, {red, green, blue, grey}, nil, nil,
    {max_level = "infinite", unit = {count_formula = "150*L", time = 30, ingredients = {red, green, blue, grey}}}),
})
