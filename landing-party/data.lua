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

-- A faction copy of a vanilla prototype: renamed, retinted, not blueprintable. Minable for salvage (half its
-- cost in parts): nothing the faction owns can be mined, only its ruins once a settlement falls, or what the
-- player captured.
local MILITARY = {["lp-turret"] = true, ["lp-gun-turret"] = true, ["lp-flamer"] = true, ["lp-gate"] = false, ["lp-mortar"] = true, ["lp-howitzer"] = true, ["lp-depot"] = true, ["lp-radar"] = true, ["lp-pacifier"] = true, ["lp-lander"] = true,
  ["lp-uplink"] = true, ["lp-launchpad"] = true}
local function copy(type, name, new)
  local name_new = new
  local p = table.deepcopy(data.raw[type][name])
  p.name = new
  local cost = shared.cost[new]
  p.minable = cost and {mining_time = 1, results = {{type = "item", name = "lp-salvage",
    amount = math.max(1, math.floor(cost / 2))}}} or nil
  p.next_upgrade = nil
  p.fast_replaceable_group = nil
  p.placeable_by = nil
  p.flags = {"placeable-neutral", "placeable-enemy", "not-blueprintable"}
  p.hidden = true
  -- Player turrets and units fire on their own only at military targets. Military: what fights or
  -- commands (turrets, depots, radars, lander, uplink, launch pad). Not military: production and walls,
  -- so an outpost can be captured intact (a squad would otherwise shoot the drills it came to take) or
  -- destroyed on purpose. (All military once, so turret creep would hit drills; capture won.)
  p.is_military_target = MILITARY[name_new] or false
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
-- Armoured (docs/reviews/2026-10-14-artillery-consult.md): about 12 artillery shells, not 2; and indestructible while
-- half its settlement's generators stand (base.lua, hull).
lander.max_health = 12000
lander.resistances = {{type = "physical", percent = 50}, {type = "explosion", percent = 50}}
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

-- The mortar: a siege emplacement (scripts/ops.lua), the artillery turret's body at 60%, its own short gun
-- (36 tiles, beyond gun 18, laser 24 and flamethrower 30 turrets) and a light shell, hitting the player only.
local MORTAR_SCALE = 0.6
local function shrink(t, seen)
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if t.filename or t.filenames or t.stripes then
    t.scale = (t.scale or 1) * MORTAR_SCALE
    if t.shift then t.shift = {t.shift[1] * MORTAR_SCALE, t.shift[2] * MORTAR_SCALE} end
  end
  for _, v in pairs(t) do shrink(v, seen) end
end
local mortar = copy("artillery-turret", "artillery-turret", "lp-mortar")
for _, k in ipairs({"base_picture", "cannon_base_pictures", "cannon_barrel_pictures"}) do shrink(mortar[k], {}) end
mortar.water_reflection = nil
mortar.collision_box = {{-0.8, -0.8}, {0.8, 0.8}}
mortar.selection_box = {{-1, -1}, {1, 1}}
mortar.drawing_box_vertical_extension = 2
mortar.max_health = 800
mortar.turret_rotation_speed = 0.004
mortar.cannon_base_shift = {0, 0, mortar.cannon_base_shift[3] * MORTAR_SCALE}
mortar.gun = "lp-mortar-gun"
mortar.inventory_size = 1
mortar.ammo_stack_limit = 100
mortar.automated_ammo_count = 1
mortar.circuit_connector = nil
mortar.corpse = nil
mortar.resistances = {{type = "physical", decrease = 5, percent = 20}, {type = "explosion", decrease = 10, percent = 30},
  {type = "fire", percent = 50}}
local mortar_gun = table.deepcopy(data.raw.gun["artillery-wagon-cannon"])
mortar_gun.name = "lp-mortar-gun"
mortar_gun.hidden = true
mortar_gun.attack_parameters.ammo_category = "lp-mortar"
mortar_gun.attack_parameters.range = 36
mortar_gun.attack_parameters.min_range = 6
mortar_gun.attack_parameters.cooldown = 240
for _, p in ipairs(mortar_gun.attack_parameters.projectile_creation_parameters or {}) do
  p[2] = {p[2][1] * MORTAR_SCALE, p[2][2] * MORTAR_SCALE}
end
local mortar_shell = table.deepcopy(data.raw.ammo["artillery-shell"])
mortar_shell.name = "lp-mortar-shell"
mortar_shell.hidden = true
mortar_shell.ammo_category = "lp-mortar"
mortar_shell.ammo_type.action.action_delivery.projectile = "lp-mortar-projectile"
mortar_shell.ammo_type.action.action_delivery.starting_speed = 0.6
local projectile = table.deepcopy(data.raw["artillery-projectile"]["artillery-projectile"])
projectile.name = "lp-mortar-projectile"
projectile.reveal_map = false
shrink(projectile.picture, {})
shrink(projectile.shadow, {})
projectile.chart_picture = nil
projectile.action = {type = "direct", action_delivery = {type = "instant", target_effects = {
  {type = "nested-result", action = {type = "area", radius = 2.5, force = "enemy", action_delivery = {type = "instant",
    target_effects = {{type = "damage", damage = {amount = 30, type = "physical"}},
      {type = "damage", damage = {amount = 90, type = "explosion"}}}}}},
  {type = "create-entity", entity_name = "big-explosion"}}}}
projectile.final_action = nil
-- Cluster munitions (the user: "multiple small explosions around the main blast", Serenity's signature): each shell
-- throws six bomblets that burst round the impact, as the base game's cluster grenade does, small each (12 explosion
-- over 1.5 tiles, its enemies only).
local bomblet = table.deepcopy(data.raw.projectile["grenade"])
bomblet.name = "lp-bomblet"
bomblet.action = {{type = "direct", action_delivery = {type = "instant", target_effects = {
    {type = "create-entity", entity_name = "grenade-explosion"},
    {type = "create-entity", entity_name = "small-scorchmark-tintable", check_buildability = true}}}},
  {type = "area", radius = 1.5, force = "enemy", action_delivery = {type = "instant", target_effects = {
    {type = "damage", damage = {amount = 12, type = "explosion"}}}}}}
bomblet.light = nil
projectile.action = {projectile.action, {type = "cluster", cluster_count = 6, distance = 4, distance_deviation = 2.5,
  action_delivery = {type = "projectile", projectile = "lp-bomblet", direction_deviation = 0.6, starting_speed = 0.25,
    starting_speed_deviation = 0.3}}}

-- The howitzer (Serenity's clearances; the user, 2026-10-15): the artillery turret's body at full size and a long gun,
-- 100 tiles, standing out of a behemoth worm's 48, slow (360 ticks), for the nests whose worms outrange the mortar. It fires the
-- mortar's shells (one supply).
local howitzer = copy("artillery-turret", "artillery-turret", "lp-howitzer")
howitzer.water_reflection = nil
howitzer.max_health = 1200
howitzer.gun = "lp-howitzer-gun"
howitzer.inventory_size = 1
howitzer.ammo_stack_limit = 100
howitzer.automated_ammo_count = 1
howitzer.circuit_connector = nil
howitzer.corpse = nil
howitzer.resistances = table.deepcopy(mortar.resistances)
local howitzer_gun = table.deepcopy(data.raw.gun["artillery-wagon-cannon"])
howitzer_gun.name = "lp-howitzer-gun"
howitzer_gun.hidden = true
howitzer_gun.attack_parameters.ammo_category = "lp-mortar"
-- 100: at 60, standing out of a behemoth worm's reach, it reached two nests of a line (the user: "don't know if it'll
-- cover a real biter city").
howitzer_gun.attack_parameters.range = 100
howitzer_gun.attack_parameters.min_range = 12
howitzer_gun.attack_parameters.cooldown = 360
-- Eight times the mortar shell's blow (the user, watching: twenty shells for one nest at 1x, three at 5x, "one too
-- many"): two a spawner.
howitzer_gun.attack_parameters.damage_modifier = 8

-- A gun turret (a corporation may build these instead of lasers: shared.CORPS bases; fed by script) and a gate.
local gun_turret = copy("ammo-turret", "gun-turret", "lp-gun-turret")
local gate = copy("gate", "gate", "lp-gate")
-- A flamethrower turret covering a gate (Serenity), kept in light oil by script.
local flamer = copy("fluid-turret", "flamethrower-turret", "lp-flamer")
-- Its own stream: the base one's splash hurt every force, and the flamers beside the gates burned 8 to 11 of Serenity's
-- own units a run (review). The splash spares its own side; the burning ground stays (without it biters took a
-- settlement apart, visit b - rocket), and still burns whoever stands in it.
local flamer_stream = table.deepcopy(data.raw.stream["flamethrower-fire-stream"])
flamer_stream.name = "lp-flamer-stream"
for _, a in ipairs(flamer_stream.action) do
  if a.type == "area" then a.force = "not-same" end
end
flamer.attack_parameters.ammo_type.action.action_delivery.stream = "lp-flamer-stream"

local wall = copy("wall", "stone-wall", "lp-wall")
wall.max_health = 450

local radar = copy("radar", "radar", "lp-radar")
radar.energy_usage = watts(shared.power["lp-radar"])

-- The pacifier (scripts/pact.lua): a radar dish broadcasting to the biters; while one stands, its corporation and they
-- hold fire on each other. Self-powered, reveals nothing.
local pacifier = copy("radar", "radar", "lp-pacifier")
pacifier.max_health = 1500
pacifier.energy_source = {type = "void"}
pacifier.max_distance_of_sector_revealed = 0
pacifier.max_distance_of_nearby_sector_revealed = 0
pacifier.rotation_speed = 0.03

-- The depot: a roboport's body as a container (it holds no robots yet).
local roboport = data.raw.roboport.roboport
local depot = copy("container", "iron-chest", "lp-depot")
depot.collision_box = roboport.collision_box
depot.selection_box = roboport.selection_box
depot.picture = table.deepcopy(roboport.base)
tint(depot.picture, {})
depot.inventory_size = 48
depot.max_health = 1000

-- The launch pad: the rocket silo's base as a container.
local silo = data.raw["rocket-silo"]["rocket-silo"]
local launchpad = copy("container", "iron-chest", "lp-launchpad")
launchpad.collision_box = silo.collision_box
launchpad.selection_box = silo.selection_box
launchpad.picture = table.deepcopy(silo.base_day_sprite)
tint(launchpad.picture, {})
launchpad.inventory_size = 10
launchpad.max_health = 2000

local lamp = copy("lamp", "small-lamp", "lp-lamp")
lamp.light = {intensity = 0.9, size = 40, color = {0.6, 0.8, 1}}
local mine = copy("land-mine", "land-mine", "lp-mine")

-- The uplink: a radar dish at twice the size, the faction's link home. Destroying it ends the landings.
local uplink = copy("radar", "radar", "lp-uplink")
uplink.max_health = 6000
uplink.collision_box = {{-2.9, -2.9}, {2.9, 2.9}}
uplink.selection_box = {{-3, -3}, {3, 3}}
uplink.energy_source = {type = "void"}
uplink.max_distance_of_sector_revealed = 0
uplink.max_distance_of_nearby_sector_revealed = 6
local function double(t, seen)
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if t.filename or t.filenames or t.stripes then
    t.scale = (t.scale or 1) * 2
    if t.shift then t.shift = {t.shift[1] * 2, t.shift[2] * 2} end
  end
  for _, v in pairs(t) do double(v, seen) end
end
double(uplink.pictures, {})

local road = table.deepcopy(data.raw.tile["refined-concrete"])
road.name = "lp-road"
road.minable = nil
road.placeable_by = nil
road.tint = shared.TINT
road.map_color = {r = 0.32, g = 0.38, b = 0.46}

data:extend({
  lander, generator, pylon, drill, bin, fabricator, turret, wall, radar, pacifier, depot, road, launchpad, lamp, mine, uplink,
  gun_turret, gate, flamer, flamer_stream,
  mortar, mortar_gun, mortar_shell, projectile, bomblet, howitzer, howitzer_gun, {type = "ammo-category", name = "lp-mortar", hidden = true},
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
require("player")
require("corps")
require("look")
require("plates")
