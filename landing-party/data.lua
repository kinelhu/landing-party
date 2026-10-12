-- Prototypes: the faction's machines are retinted vanilla ones, never craftable by the player.
local shared = require("shared")

local function watts(w) return tostring(math.abs(w) / 1000) .. "kW" end
local function one_second(w) return tostring(math.abs(w) / 1000) .. "kJ" end

-- Multiply the tint of every sprite layer in a graphics table, shadows and lights excepted.
local function tint(t, seen)
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if (t.filename or t.filenames or t.stripes) and not (t.draw_as_shadow or t.draw_as_light or t.draw_as_glow) then
    t.tint = shared.TINT
  end
  for k, v in pairs(t) do
    if k ~= "sound" and k ~= "working_sound" then tint(v, seen) end
  end
end

-- A faction copy of a vanilla prototype: renamed, retinted, not minable, not blueprintable.
local function copy(type, name, new)
  local p = table.deepcopy(data.raw[type][name])
  p.name = new
  p.minable = nil
  p.next_upgrade = nil
  p.fast_replaceable_group = nil
  p.placeable_by = nil
  p.flags = {"placeable-neutral", "placeable-enemy", "not-blueprintable", "not-deconstructable"}
  p.hidden = true
  p.icons = {{icon = p.icon or (p.icons and p.icons[1].icon), tint = shared.TINT}}
  p.icon = nil
  tint(p, {})
  return p
end

-- The lander: the crash-site spaceship as the base's first power source.
local ship = data.raw.container["crash-site-spaceship"]
local lander = copy("electric-energy-interface", "electric-energy-interface", "lp-lander")
lander.collision_box = ship.collision_box
lander.selection_box = ship.selection_box
lander.picture = table.deepcopy(ship.picture)
tint(lander.picture, {})
lander.integration_patch = nil
lander.max_health = 3000
lander.gui_mode = "none"
lander.energy_source = {type = "electric", usage_priority = "primary-output",
  buffer_capacity = one_second(shared.power["lp-lander"])}
lander.energy_production = watts(shared.power["lp-lander"])
lander.energy_usage = "0kW"

local generator = copy("electric-energy-interface", "electric-energy-interface", "lp-generator")
generator.max_health = 400
generator.gui_mode = "none"
generator.energy_source = {type = "electric", usage_priority = "primary-output",
  buffer_capacity = one_second(shared.power["lp-generator"])}
generator.energy_production = watts(shared.power["lp-generator"])
generator.energy_usage = "0kW"

local pylon = copy("electric-pole", "medium-electric-pole", "lp-pylon")
pylon.maximum_wire_distance = shared.PYLON_REACH
pylon.supply_area_distance = shared.PYLON_SUPPLY

local drill = copy("mining-drill", "electric-mining-drill", "lp-drill")
drill.energy_usage = watts(shared.power["lp-drill"])
drill.module_slots = 0
drill.allowed_effects = nil

local bin = copy("container", "iron-chest", "lp-bin")
bin.inventory_size = 48

local fabricator = copy("assembling-machine", "assembling-machine-2", "lp-fabricator")
fabricator.crafting_categories = {"lp-fabrication"}
fabricator.crafting_speed = shared.FABRICATOR_SPEED
fabricator.fixed_recipe = "lp-parts"
fabricator.energy_usage = watts(shared.power["lp-fabricator"])
fabricator.energy_source = {type = "electric", usage_priority = "secondary-input", emissions_per_minute = {}}
fabricator.module_slots = 0
fabricator.allowed_effects = nil

local turret = copy("electric-turret", "laser-turret", "lp-turret")

local wall = copy("wall", "stone-wall", "lp-wall")
wall.max_health = 450

local radar = copy("radar", "radar", "lp-radar")
radar.energy_usage = watts(shared.power["lp-radar"])

-- The depot: a roboport's body as a container (it holds no robots yet).
local roboport = data.raw.roboport.roboport
local depot = copy("container", "iron-chest", "lp-depot")
depot.collision_box = roboport.collision_box
depot.selection_box = roboport.selection_box
depot.picture = table.deepcopy(roboport.base)
tint(depot.picture, {})
depot.inventory_size = 48
depot.max_health = 1000

local road = table.deepcopy(data.raw.tile["refined-concrete"])
road.name = "lp-road"
road.minable = nil
road.placeable_by = nil
road.tint = shared.TINT
road.map_color = {r = 0.32, g = 0.38, b = 0.46}

data:extend({
  lander, generator, pylon, drill, bin, fabricator, turret, wall, radar, depot, road,
  {type = "recipe-category", name = "lp-fabrication"},
  {type = "item", name = "lp-feedstock", icon = "__base__/graphics/icons/stone.png", hidden = true,
    stack_size = 200, subgroup = "other"},
  {type = "item", name = "lp-part", icon = "__base__/graphics/icons/iron-gear-wheel.png", hidden = true,
    stack_size = 200, subgroup = "other"},
  {type = "recipe", name = "lp-parts", category = "lp-fabrication", hidden = true, enabled = true,
    energy_required = shared.PART_SECONDS,
    ingredients = {{type = "item", name = "lp-feedstock", amount = shared.FEEDSTOCK_PER_PART}},
    results = {{type = "item", name = "lp-part", amount = 1}}},
})

require("units")
