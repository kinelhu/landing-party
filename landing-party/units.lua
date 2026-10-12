-- Units (spike stage): stand-in bones, real collision and targeting. Graphics come later.
--   lp-infantry  a ground unit on the default unit mask: walls block it, mines and fire reach it.
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

local infantry = base_unit("lp-infantry")
infantry.max_health = 100
infantry.movement_speed = 0.15
infantry.vision_distance = 30
local ia = gun(6, 14, 20)
ia.animation = infantry.attack_parameters.animation
infantry.attack_parameters = ia
tint(infantry.run_animation, {})
tint(infantry.attack_parameters.animation, {})

local harrier = base_unit("lp-harrier")
local defender = data.raw["combat-robot"]["defender"]
harrier.max_health = 150
harrier.movement_speed = 0.25
harrier.vision_distance = 30
harrier.collision_box = {{-0.3, -0.3}, {0.3, 0.3}}
harrier.selection_box = {{-0.5, -1.5}, {0.5, -0.5}}
harrier.collision_mask = {layers = {["lp-air"] = true}, not_colliding_with_itself = true}
harrier.trigger_target_mask = {"lp-air-unit"}
harrier.render_layer = "air-object"
harrier.run_animation = table.deepcopy(defender.in_motion)
local ha = gun(10, 18, 15)
ha.animation = table.deepcopy(defender.in_motion)
harrier.attack_parameters = ha
harrier.dying_explosion = "defender-robot-explosion"
harrier.corpse = nil
harrier.resistances = {{type = "fire", percent = 100}}
tint(harrier.run_animation, {})
tint(harrier.attack_parameters.animation, {})

data:extend({infantry, harrier})
