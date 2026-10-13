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

-- The command tool (scripts/command.lua): drag over your units to select them (shift: release them to their
-- beacons); right-click or right-drag on the ground to move them, on a faction building to attack it (shift:
-- attack-move). For players who would rather not wire a beacon; beacons keep every unit not picked by hand.
local UNIT_NAMES = {}
for _, name in pairs(shared.ORDERS) do table.insert(UNIT_NAMES, name) end
table.sort(UNIT_NAMES)
data:extend({
  {type = "selection-tool", name = "lp-command-tool", icon = "__base__/graphics/icons/spidertron-remote.png",
    flags = {"only-in-cursor", "not-stackable", "spawnable"}, hidden = true, stack_size = 1, subgroup = "other",
    select = {border_color = {0.4, 1, 0.4}, cursor_box_type = "copy", mode = {"same-force", "any-entity"},
      entity_filters = UNIT_NAMES},
    alt_select = {border_color = {1, 0.8, 0.3}, cursor_box_type = "copy", mode = {"same-force", "any-entity"},
      entity_filters = UNIT_NAMES},
    reverse_select = {border_color = {0.4, 0.7, 1}, cursor_box_type = "not-allowed", mode = {"nothing"}},
    alt_reverse_select = {border_color = {1, 0.4, 0.3}, cursor_box_type = "not-allowed", mode = {"nothing"}}},
  {type = "shortcut", name = "lp-command-tool", order = "z[landing-party]", action = "spawn-item",
    item_to_spawn = "lp-command-tool", associated_control_input = "lp-command-tool",
    technology_to_unlock = "lp-command-bandwidth-1", unavailable_until_unlocked = true,
    icon = "__base__/graphics/icons/shortcut-toolbar/mip/new-rts-tool-x56.png", icon_size = 56,
    small_icon = "__base__/graphics/icons/shortcut-toolbar/mip/new-rts-tool-x24.png", small_icon_size = 24},
  {type = "custom-input", name = "lp-command-tool", key_sequence = "ALT + C", action = "spawn-item",
    item_to_spawn = "lp-command-tool", consuming = "game-only"},
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

-- Prizes (docs/reviews/2026-10-13-headquarters-consult.md): a corporation whose headquarters falls leaves the player
-- one recipe, unlocked by a hidden technology the fall marks researched. Serenity: its mortar (and shells), the
-- wall's own weapon. Grubstake: its strip drill, twice an electric drill's speed at half the ore drain.
local mortar = table.deepcopy(data.raw["artillery-turret"]["lp-mortar"])
mortar.name = "lp-player-mortar"
mortar.flags = {"placeable-neutral", "placeable-player", "player-creation"}
mortar.minable = {mining_time = 0.5, result = "lp-player-mortar"}
mortar.hidden = false
data.raw.ammo["lp-mortar-shell"].hidden = false
data.raw.ammo["lp-mortar-shell"].subgroup = "ammo"
local strip = table.deepcopy(data.raw["mining-drill"]["electric-mining-drill"])
strip.name = "lp-strip-drill"
strip.minable = {mining_time = 0.5, result = "lp-strip-drill"}
strip.mining_speed = 1
strip.resource_drain_rate_percent = 50
strip.next_upgrade = nil
strip.fast_replaceable_group = nil
local function prize(corp, recipes)
  local effects = {}
  for _, r in ipairs(recipes) do table.insert(effects, {type = "unlock-recipe", recipe = r}) end
  return {type = "technology", name = "lp-prize-" .. corp, hidden = true, icon = "__base__/graphics/technology/military.png",
    icon_size = 256, effects = effects, unit = {count = 1, time = 1, ingredients = {{"automation-science-pack", 1}}}}
end
data:extend({
  mortar, strip,
  {type = "item", name = "lp-player-mortar", icon = "__base__/graphics/icons/artillery-turret.png", stack_size = 10,
    place_result = "lp-player-mortar", subgroup = "defensive-structure", order = "z[landing-party]-mortar"},
  {type = "item", name = "lp-strip-drill", icon = "__base__/graphics/icons/electric-mining-drill.png", stack_size = 50,
    place_result = "lp-strip-drill", subgroup = "extraction-machine", order = "z[landing-party]-strip-drill"},
  {type = "recipe", name = "lp-player-mortar", enabled = false, energy_required = 10,
    ingredients = {{type = "item", name = "lp-salvage", amount = 20}, {type = "item", name = "steel-plate", amount = 10}},
    results = {{type = "item", name = "lp-player-mortar", amount = 1}}},
  {type = "recipe", name = "lp-mortar-shell", enabled = false, energy_required = 4,
    ingredients = {{type = "item", name = "lp-salvage", amount = 2}, {type = "item", name = "explosives", amount = 1}},
    results = {{type = "item", name = "lp-mortar-shell", amount = 1}}},
  {type = "recipe", name = "lp-strip-drill", enabled = false, energy_required = 4,
    ingredients = {{type = "item", name = "lp-salvage", amount = 15}, {type = "item", name = "steel-plate", amount = 10},
      {type = "item", name = "electronic-circuit", amount = 5}},
    results = {{type = "item", name = "lp-strip-drill", amount = 1}}},
  prize("serenity", {"lp-player-mortar", "lp-mortar-shell"}),
  prize("grubstake", {"lp-strip-drill"}),
})
