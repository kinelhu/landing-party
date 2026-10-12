-- The player's side: a barracks that trains troopers from items, and a rally beacon whose circuit signals
-- set their stance (scripts/command.lua). Unlocked from the start while this is a prototype.
local shared = require("shared")

local barracks = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
barracks.name = "lp-barracks"
barracks.minable = {mining_time = 0.5, result = "lp-barracks"}
barracks.next_upgrade = nil
barracks.fast_replaceable_group = nil
barracks.crafting_categories = {"lp-training"}
barracks.fixed_recipe = "lp-trooper-order"
barracks.module_slots = 0
barracks.allowed_effects = nil

local beacon = table.deepcopy(data.raw.lamp["small-lamp"])
beacon.name = "lp-rally-beacon"
beacon.minable = {mining_time = 0.2, result = "lp-rally-beacon"}
beacon.next_upgrade = nil
beacon.light = {intensity = 0.8, size = 12, color = {1, 0.7, 0.3}}

local function item(name, icon, place)
  return {type = "item", name = name, icon = icon, stack_size = 10, place_result = place, subgroup = "defensive-structure",
    order = "z[landing-party]-" .. name}
end

data:extend({
  barracks, beacon,
  {type = "recipe-category", name = "lp-training"},
  item("lp-barracks", "__base__/graphics/icons/assembling-machine-2.png", "lp-barracks"),
  item("lp-rally-beacon", "__base__/graphics/icons/small-lamp.png", "lp-rally-beacon"),
  {type = "item", name = "lp-trooper-order", icon = "__base__/graphics/icons/firearm-magazine.png", hidden = true,
    stack_size = 10, subgroup = "other"},
  {type = "recipe", name = "lp-barracks", enabled = true, energy_required = 5,
    ingredients = {{type = "item", name = "assembling-machine-2", amount = 1}, {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "electronic-circuit", amount = 10}},
    results = {{type = "item", name = "lp-barracks", amount = 1}}},
  {type = "recipe", name = "lp-rally-beacon", enabled = true, energy_required = 2,
    ingredients = {{type = "item", name = "small-lamp", amount = 1}, {type = "item", name = "electronic-circuit", amount = 2}},
    results = {{type = "item", name = "lp-rally-beacon", amount = 1}}},
  -- A trooper: ammunition, plates and circuits; the barracks turns the order into a unit.
  {type = "recipe", name = "lp-trooper-order", category = "lp-training", enabled = true, hidden_in_factoriopedia = true,
    energy_required = 8,
    ingredients = {{type = "item", name = "firearm-magazine", amount = 5}, {type = "item", name = "iron-plate", amount = 10},
      {type = "item", name = "electronic-circuit", amount = 2}},
    results = {{type = "item", name = "lp-trooper-order", amount = 1}}},
})
