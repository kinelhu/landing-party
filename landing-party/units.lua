-- Units on vanilla bones, tinted, with the faction's own stats (shared.units).
--   lp-infantry  the engineer's body: a ground unit, breaches walls, mines and fire reach it.
--   lp-tank      the tank's hull: slow, armoured, explosive shells.
--   lp-walker    a spider-unit on the spidertron: steps over walls, rockets.
--   lp-harrier   an air unit on its own collision layer (lp-air), so walls, cliffs and water do not block
--                it and mines (which trigger on building layers) never see it; its trigger target type
--                (lp-air-unit) is what turrets ignore when they cannot shoot up (data-final-fixes.lua).
local shared = require("shared")

local function tint(t, seen)
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if (t.filename or t.filenames or t.stripes) and not (t.draw_as_shadow or t.draw_as_light or t.draw_as_glow) then
    t.tint = shared.TINT
  end
  for _, v in pairs(t) do tint(v, seen) end
end

local function gun(damage, range, cooldown, category)
  return {
    type = "projectile", ammo_category = category or "bullet", range = range, cooldown = cooldown,
    cooldown_deviation = 0.15, range_mode = "bounding-box-to-bounding-box",
    ammo_type = {action = {type = "direct", action_delivery = {type = "instant",
      source_effects = {type = "create-explosion", entity_name = "explosion-gunshot-small"},
      target_effects = {{type = "create-entity", entity_name = "explosion-hit"},
        {type = "damage", damage = {amount = damage, type = "physical"}}}}}},
  }
end

local function base_unit(name)
  local u = table.deepcopy(data.raw.unit["medium-biter"])
  u.name = name
  u.icons = {{icon = u.icon, tint = shared.TINT}}
  u.icon = nil
  u.hidden = true
  u.loot = nil
  u.factoriopedia_simulation = nil
  u.flags = {"placeable-enemy", "placeable-off-grid", "not-repairable"}
  u.ai_settings = {destroy_when_commands_fail = false, allow_try_return_to_spawner = false, do_separation = true}
  u.absorptions_to_join_attack = nil
  u.healing_per_tick = 0
  return u
end

data:extend({
  {type = "collision-layer", name = "lp-air"},
  {type = "trigger-target-type", name = "lp-air-unit"},
})

-- Drone infantry: the engineer's body, as ERM's RedArmy does. Runs with its gun; fires from the idle pose.
local character = data.raw.character.character.animations[1]
local infantry = base_unit("lp-infantry")
infantry.max_health = shared.units["lp-infantry"].health
infantry.movement_speed = 0.12
infantry.distance_per_frame = 0.13
infantry.vision_distance = 30
infantry.collision_box = {{-0.2, -0.2}, {0.2, 0.2}}
infantry.selection_box = {{-0.4, -1.4}, {0.4, 0.2}}
infantry.run_animation = table.deepcopy(character.running_with_gun)
-- Ranges stay at most a turret's 18 less the wall in front of it (~3): anything shooting a wall stands in
-- turret range. A tank at 22, then 17, shelled walls from outside the turrets' reach.
local ia = gun(6, 15, 20)
ia.animation = table.deepcopy(character.idle_with_gun)
infantry.attack_parameters = ia
infantry.dying_explosion = "explosion"
infantry.corpse = nil
infantry.resistances = {{type = "physical", decrease = 2, percent = 10}}
tint(infantry.run_animation, {})
tint(infantry.attack_parameters.animation, {})

-- Tank: the tank's hull as a unit (its turret does not turn on its own). A square box: units rotate.
local tank_car = data.raw.car.tank
local tank = base_unit("lp-tank")
tank.max_health = shared.units["lp-tank"].health
tank.movement_speed = 0.09
tank.distance_per_frame = 0.5
tank.vision_distance = 30
tank.collision_box = {{-1, -1}, {1, 1}}
tank.selection_box = {{-1.2, -1.4}, {1.2, 1.4}}
tank.run_animation = table.deepcopy(tank_car.animation)
local ta = gun(35, 15, 90, "cannon-shell")
ta.ammo_type.action.action_delivery.target_effects[2].damage.type = "explosion"
ta.animation = table.deepcopy(tank_car.animation)
tank.attack_parameters = ta
tank.dying_explosion = "medium-explosion"
tank.corpse = nil
-- Armour that yellow ammo still hurts: a flat 10 made a gun turret's 5-damage rounds useless (seed 4242:
-- seven raids, no unit lost).
tank.resistances = {{type = "physical", decrease = 3, percent = 20}, {type = "fire", percent = 60},
  {type = "explosion", decrease = 5, percent = 30}}
tint(tank.run_animation, {})
tint(tank.attack_parameters.animation, {})

-- Walker: a spider-unit on the spidertron's body and legs (own copies of the legs, tinted). Steps over walls.
local spidertron = data.raw["spider-vehicle"].spidertron
local walker = {
  type = "spider-unit", name = "lp-walker", hidden = true,
  icons = {{icon = spidertron.icon, tint = shared.TINT}},
  flags = {"placeable-enemy", "placeable-off-grid", "not-repairable"},
  max_health = shared.units["lp-walker"].health,
  collision_box = spidertron.collision_box, selection_box = spidertron.selection_box,
  sticker_box = spidertron.sticker_box, drawing_box_vertical_extension = spidertron.drawing_box_vertical_extension,
  resistances = {{type = "physical", decrease = 3, percent = 20}, {type = "fire", percent = 60},
    {type = "explosion", decrease = 10, percent = 30}, {type = "acid", percent = 50}},
  height = spidertron.height, torso_rotation_speed = spidertron.torso_rotation_speed,
  distraction_cooldown = 300, min_pursue_time = 600, max_pursue_distance = 50, vision_distance = 40,
  ai_settings = {destroy_when_commands_fail = false, allow_try_return_to_spawner = false},
  is_military_target = true,
  dying_explosion = "spidertron-explosion",
  graphics_set = table.deepcopy(spidertron.graphics_set),
  spider_engine = table.deepcopy(spidertron.spider_engine),
  attack_parameters = gun(18, 15, 25, "rocket"),
}
walker.attack_parameters.use_shooter_direction = true
tint(walker.graphics_set, {})
local legs = {}
for _, leg in ipairs(walker.spider_engine.legs) do
  local copy = table.deepcopy(data.raw["spider-leg"][leg.leg])
  copy.name = "lp-walker-" .. leg.leg
  copy.hidden = true
  tint(copy, {})
  leg.leg = copy.name
  table.insert(legs, copy)
end
data:extend(legs)

local harrier = base_unit("lp-harrier")
local defender = data.raw["combat-robot"]["destroyer"]
harrier.max_health = shared.units["lp-harrier"].health
harrier.movement_speed = 0.25
harrier.vision_distance = 30
harrier.collision_box = {{-0.3, -0.3}, {0.3, 0.3}}
harrier.selection_box = {{-0.5, -1.5}, {0.5, -0.5}}
harrier.collision_mask = {layers = {["lp-air"] = true}, not_colliding_with_itself = true}
harrier.trigger_target_mask = {"lp-air-unit"}
harrier.render_layer = "air-object"
harrier.run_animation = table.deepcopy(defender.in_motion)
local ha = gun(10, 15, 15)
ha.animation = table.deepcopy(defender.in_motion)
harrier.attack_parameters = ha
harrier.dying_explosion = "destroyer-robot-explosion"
harrier.corpse = nil
harrier.resistances = {{type = "fire", percent = 100}}
tint(harrier.run_animation, {})
tint(harrier.attack_parameters.animation, {})

data:extend({infantry, tank, walker, harrier})
