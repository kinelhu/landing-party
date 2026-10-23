-- Units on vanilla bones, tinted, with the faction's own stats (shared.units).
--   lp-infantry  the engineer's body: a ground unit, breaches walls, mines and fire reach it.
--   lp-tank      the tank's hull: slow, armoured, explosive shells.
--   lp-walker    a spider-unit on the spidertron: steps over walls, rockets.
--   lp-harrier   an air unit on its own collision layer (lp-air), so walls, cliffs and water do not block
--                it and mines (which trigger on building layers) never see it; its trigger target type
--                (lp-air-unit) is what turrets ignore when they cannot shoot up (data-final-fixes.lua).
local shared = require("shared")

-- Where a sprite carries the engine's colour masks (the character's, the tank's and the car's player-colour layers),
-- only the masks take the colour and the art underneath stays natural (the user, 2026-10-14: refined colours, not
-- the whole thing tinted); a sprite without masks (the harrier) is tinted whole, as before.
local function tint(t, seen, color)
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if type(t.layers) == "table" then
    local masked = false
    for _, l in ipairs(t.layers) do if type(l) == "table" and l.apply_runtime_tint then masked = true end end
    if masked then
      for _, l in ipairs(t.layers) do
        if type(l) == "table" and l.apply_runtime_tint then
          l.apply_runtime_tint = false
          l.tint = color or shared.TINT
        end
      end
      return
    end
  end
  if (t.filename or t.filenames or t.stripes) and not (t.draw_as_shadow or t.draw_as_light or t.draw_as_glow) then
    t.tint = color or shared.TINT
  end
  for _, v in pairs(t) do tint(v, seen, color) end
end

-- Weapon sounds by ammunition: units on a biter's bones otherwise growl and fire silently.
local SOUND = {bullet = data.raw.gun["submachine-gun"].attack_parameters.sound,
  ["cannon-shell"] = data.raw.gun["tank-cannon"].attack_parameters.sound,
  rocket = data.raw.gun["rocket-launcher"].attack_parameters.sound}
local function gun(damage, range, cooldown, category)
  return {
    sound = table.deepcopy(SOUND[category or "bullet"]),
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
  -- Machines, not biters: no growls, no hisses.
  u.working_sound = nil
  u.dying_sound = nil
  u.walking_sound = nil
  u.running_sound_animation_positions = nil
  return u
end

data:extend({
  {type = "trigger-target-type", name = "lp-biter"},
  {type = "collision-layer", name = "lp-air"},
  {type = "trigger-target-type", name = "lp-air-unit"},
})

-- Infantry: the engineer's body, as ERM's RedArmy does. Runs with its gun; fires from the idle pose. The
-- faction's drones in cold blue; the player's troopers (player.lua) in their own colour.
local character = data.raw.character.character.animations[1]
-- The engineer's animation set for an armour (Space Age's mech armour, base's heavy armour...); the plain one without.
local function wearing(armor)
  for _, a in ipairs(data.raw.character.character.animations) do
    for _, n in ipairs(a.armors or {}) do if n == armor then return a end end
  end
  return character
end
local function make_infantry(name, color, armor)
  local look = armor and wearing(armor) or character
  local u = base_unit(name)
  u.max_health = shared.units["lp-infantry"].health
  u.movement_speed = 0.12
  u.distance_per_frame = 0.13
  u.vision_distance = 30
  u.collision_box = {{-0.2, -0.2}, {0.2, 0.2}}
  u.selection_box = {{-0.4, -1.4}, {0.4, 0.2}}
  u.run_animation = table.deepcopy(look.running_with_gun)
  -- Ranges stay at most a turret's 18 less the wall in front of it (~3): anything shooting a wall stands
  -- in turret range. A tank at 22, then 17, shelled walls from outside the turrets' reach.
  local a = gun(6, 15, 20)
  a.animation = table.deepcopy(look.idle_with_gun)
  u.attack_parameters = a
  u.dying_explosion = "explosion"
  -- Bodies (the user, 2026-10-21: "Do units leave bodies?"): what is left of a suit, a vehicle, a drone where it fell,
  -- the engine's own remnants, gone after their usual time.
  u.corpse = "small-remnants"
  u.resistances = {{type = "physical", decrease = 2, percent = 10}}
  tint(u.run_animation, {}, color)
  tint(u.attack_parameters.animation, {}, color)
  return u
end
-- Who wears what (Space Age): Serenity's Line troopers and railgunners the mech armour, the player's troopers the heavy
-- armour their recipe takes, Grubstake's Shotgun hands heavy armour too, in its colours.
local infantry = make_infantry("lp-infantry", nil, "mech-armor")
local trooper = make_infantry("lp-trooper", {r = 1, g = 0.82, b = 0.55, a = 1}, "heavy-armor")
-- 8 a round (6 until the RTS pass, 2026-10-21: a bandwidth of troopers lost to every rifle squad of the corporations).
trooper.attack_parameters.ammo_type.action.action_delivery.target_effects[2].damage.amount = 8

-- Each corporation's own infantry (docs/reviews/2026-10-14-identity-trees-consult.md): you know who attacks by ear.
-- Serenity's Line trooper fires a laser beam: about 7 laser a shot every 25 ticks (the laser turret's beam, 10 a hit,
-- scaled), range 15, ammunition category laser (its research covers its laser turrets too), laser 20% resisted.
infantry.attack_parameters = {
  type = "beam", ammo_category = "laser", cooldown = 25, range = 15, range_mode = "bounding-box-to-bounding-box",
  damage_modifier = 0.7, source_direction_count = 8, source_offset = {0, -0.6},
  animation = infantry.attack_parameters.animation,
  ammo_type = {action = {type = "direct", action_delivery = {type = "beam", beam = "laser-beam", max_length = 16,
    duration = 20, source_offset = {0, -1}}}},
}
table.insert(infantry.resistances, {type = "laser", percent = 20})
-- Grubstake's Shotgun hand: three heavy pellets of 9 (lp-pellet), range 9, every 60 ticks (45: 570 ticks; 55: 600 to 660), a little quicker on its feet
-- (four of 4 every 30 ticks held parity with the beam but barely scratched a biter: its armour takes 4 to 12 a hit;
-- eight light ones destroyed the parity targets in 420 ticks to the beam's 780, five in 540, four in 630).
-- Deadly at the fence, useless against a turret line (which its temper never attacks). Built as its infantry
-- through its CORPS.bases (corps.lua renames it lp-grubstake-infantry).
local shotgun_hand = make_infantry("lp-shotgun-hand", nil, "heavy-armor")
-- A swarm that wins once it closes (the RTS pass, 2026-10-21; the user: "Grubstake infantry seems a little
-- underwhelming?"): in the arena it lost to every light infantry, dying on the way in from 15 to its 9 and then
-- missing with a wide spread. Quicker (0.13 -> 0.17) and a tighter spread (0.3 -> 0.15).
shotgun_hand.movement_speed = 0.17
shotgun_hand.attack_parameters = {
  -- 64 with Space Age loaded (60 gave 630 ticks against the Line troopers' 810, out of parity; base alone 690).
  type = "projectile", ammo_category = "shotgun-shell", cooldown = 64, range = 9, min_range = 0,
  range_mode = "bounding-box-to-bounding-box", cooldown_deviation = 0.15,
  sound = table.deepcopy(data.raw.gun["shotgun"].attack_parameters.sound),
  animation = shotgun_hand.attack_parameters.animation,
  ammo_type = {action = {type = "direct", repeat_count = 3, action_delivery = {type = "projectile",
    projectile = "lp-pellet", starting_speed = 1, starting_speed_deviation = 0.1, direction_deviation = 0.15,
    range_deviation = 0.3, max_range = 11}}},
}
local pellet = table.deepcopy(data.raw.projectile["shotgun-pellet"])
pellet.name = "lp-pellet"
-- Heavy shot: a biter's armour takes 4 (medium) to 12 (behemoth) off every hit, and pellets of 4 did next to nothing.
pellet.action.action_delivery.target_effects.damage.amount = 9
-- Through its own side (force_condition defaults to all: six Shotgun hands lost 555 of 720 health to each other).
pellet.force_condition = "not-same"

-- Breacher: the player's infantry with demolition charges. Bullets barely scratch walls (2.4 of 6 damage), so
-- troopers alone died in front of walled lasers (siege). A charge bursts over 2.5 (enemies
-- only), thrown 12 tiles: walls take 63 of 100 (a segment in 8 throws, several at once), a turret 100.
local breacher = make_infantry("lp-breacher", {r = 0.75, g = 0.9, b = 0.45, a = 1}, "heavy-armor")
-- Thrown from 12: from 8 they crossed 16 tiles of laser fire to reach a wall.
breacher.attack_parameters.range = 12
breacher.attack_parameters.cooldown = 180
breacher.attack_parameters.ammo_category = "grenade"
breacher.attack_parameters.sound = nil
-- Against units, 15 (the RTS pass, 2026-10-21: at 100 to everything, one bandwidth of breachers beat 18 of 20 kinds in
-- the arena, troopers 3; at 30, still 16; a demolition specialist is a poor fighter). Buildings (placeable-neutral:
-- walls, turrets, every building) take the full 100.
breacher.attack_parameters.ammo_type.action.action_delivery.target_effects = {
  {type = "create-entity", entity_name = "grenade-explosion"},
  {type = "nested-result", action = {type = "area", radius = 2.5, force = "enemy", action_delivery = {
    type = "instant", target_effects = {{type = "damage", damage = {amount = 15, type = "explosion"}}}}}},
  {type = "nested-result", action = {type = "area", radius = 2.5, force = "enemy", entity_flags = {"placeable-neutral"},
    action_delivery = {type = "instant", target_effects = {{type = "damage", damage = {amount = 85, type = "explosion"}}}}}},
}

-- Rocket trooper: the player's answer to armour (the RTS pass, the user, 2026-10-21: a trooper's 6 a bullet does about 2
-- to a hull, so tanks and turrets were the only answer). A rocket of 110 explosion to its target every 2.5 seconds, from 18
-- (beyond a tank's 15), the rocket launcher's own sound and round, flying to its target only (as the tanks' shells do);
-- it hits fliers too. Slow to fire and weak against a crowd: a rifleman (120) takes two rockets, 5 seconds; a hull loses
-- 70 or more to each. (At 100 every 2 s it beat light infantry as well as a trooper did; at 80 it lost to tanks.)
local rocket_trooper = make_infantry("lp-rocket-trooper", {r = 0.95, g = 0.6, b = 0.4, a = 1}, "heavy-armor")
local rocket = table.deepcopy(data.raw.projectile["rocket"])
rocket.name = "lp-trooper-rocket"
rocket.direction_only = false
rocket.collision_box = nil
rocket.hit_collision_mask = {layers = {}}
rocket.force_condition = "not-same"
rocket.action = {type = "direct", action_delivery = {type = "instant", target_effects = {
  {type = "create-entity", entity_name = "explosion"},
  {type = "damage", damage = {amount = 110, type = "explosion"}}}}}
rocket.final_action = nil
rocket_trooper.attack_parameters.range = 18
rocket_trooper.attack_parameters.cooldown = 150
rocket_trooper.attack_parameters.ammo_category = "rocket"
rocket_trooper.attack_parameters.sound = table.deepcopy(SOUND.rocket)
rocket_trooper.attack_parameters.ammo_type = {action = {type = "direct", action_delivery = {type = "projectile",
  projectile = "lp-trooper-rocket", starting_speed = 0.6, max_range = 24}}}
data:extend({rocket_trooper, rocket})

-- Tank: the tank's hull as a unit (its turret does not turn on its own). A square box: units rotate. The
-- faction's in cold blue; the player's battle tank (4 of command bandwidth) in its own colour.
local tank_car = data.raw.car.tank
-- Its shell (the user, 2026-10-21: "tank sounds but look like they fire SMGs ... a unit that should be good against
-- bases"): the tank cannon's own round, flash and scorch, `direct` explosion to what it hits and a blast of `siege` over
-- 1.5 tiles to buildings only (entity flag placeable-neutral: every building, the corporations' and the player's, and the
-- player's vehicles; no unit, character or nest carries it). Against a squad it hits as before; against a wall line or a
-- turret cluster three times as hard.
local function shell(unit_name, direct, siege)
  local p = table.deepcopy(data.raw.projectile["cannon-projectile"])
  p.name = unit_name .. "-shell"
  p.direction_only = false
  p.piercing_damage = 0
  -- To its target only (a shell that hit what stood in its way, trees and walls, left a siege's assault short:
  -- bombard aborted with 9 of 22 left; the instant hit it replaced always reached its target).
  p.collision_box = nil
  p.hit_collision_mask = {layers = {}}
  p.force_condition = "not-same"
  p.action = {
    {type = "direct", action_delivery = {type = "instant", target_effects = {
      {type = "damage", damage = {amount = direct, type = "explosion"}},
      {type = "create-entity", entity_name = "explosion"}}}},
    {type = "area", radius = 1.5, force = "not-same", entity_flags = {"placeable-neutral"}, action_delivery = {
      type = "instant", target_effects = {{type = "damage", damage = {amount = siege, type = "explosion"}}}}},
  }
  data:extend({p})
  return {action = {type = "direct", action_delivery = {type = "projectile", projectile = p.name, starting_speed = 1,
    max_range = 30, source_effects = {type = "create-explosion", entity_name = "explosion-gunshot"}}}}
end
-- A hull crowned (the design sheet, the user, 2026-10-21: units told apart by their silhouette, from vanilla parts): a
-- turning head's layers added to a hull's, scaled and moved, held to the hull's frames and pace (layers of one
-- animation advance alike).
local function crowned(hull, heads)
  local a = table.deepcopy(hull)
  local base = a.layers[1]
  for _, h in ipairs(heads) do
    local src = table.deepcopy(h[1])
    for _, l in ipairs(src.layers or {src}) do
      local k = h[2] or 1
      l.scale = (l.scale or 1) * k
      local sh = l.shift or {0, 0}
      l.shift = {sh[1] * k + (h[3] or 0), sh[2] * k + (h[4] or 0)}
      l.frame_count, l.repeat_count = 1, base.frame_count or 1
      l.line_length = l.line_length or 8
      l.animation_speed, l.max_advance = base.animation_speed, base.max_advance
      table.insert(a.layers, l)
    end
  end
  return a
end

-- heads: the turning heads on its hull; by default the tank's own cannon turret (the units had the hull only).
local function make_tank(name, color, heads)
local tank = base_unit(name)
tank.max_health = shared.units["lp-tank"].health
tank.movement_speed = 0.09
tank.distance_per_frame = 0.5
tank.vision_distance = 30
tank.collision_box = {{-1, -1}, {1, 1}}
tank.selection_box = {{-1.2, -1.4}, {1.2, 1.4}}
tank.run_animation = crowned(tank_car.animation, heads or {{tank_car.turret_animation}})
local ta = gun(35, 15, 90, "cannon-shell")
ta.ammo_type = shell(name, 40, 80)
ta.sound = table.deepcopy(data.raw.gun["tank-cannon"].attack_parameters.sound)
ta.animation = table.deepcopy(tank.run_animation)
tank.attack_parameters = ta
tank.dying_explosion = "medium-explosion"
tank.corpse = "tank-remnants"
-- Armour that yellow ammo still hurts: a flat 10 made a gun turret's 5-damage rounds useless (seed 4242:
-- seven raids, no unit lost).
tank.resistances = {{type = "physical", decrease = 3, percent = 20}, {type = "fire", percent = 60},
  {type = "explosion", decrease = 5, percent = 30}, {type = "laser", decrease = 5}, {type = "electric", decrease = 5}}
tint(tank.run_animation, {}, color)
tint(tank.attack_parameters.animation, {}, color)
return tank
end
local tank = make_tank("lp-tank")
local battle_tank = make_tank("lp-battle-tank", {r = 1, g = 0.82, b = 0.55, a = 1})
-- The player's siege weapon: heavier shells, a little more reach than its armour's 15. With the faction's
-- 35, five tanks did 2,100 damage to turrets over a whole assault (siege).
battle_tank.attack_parameters.range = 18
-- 50 to what it hits (70 until the RTS pass, 2026-10-21: at 4 then 6 of bandwidth it beat every ground kind in the
-- arena); its siege blast unchanged: the player's siege weapon, not a better aegis.
battle_tank.attack_parameters.ammo_type = shell("lp-battle-tank-heavy", 50, 120)

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
    {type = "explosion", decrease = 10, percent = 30}, {type = "acid", percent = 50}, {type = "laser", decrease = 5}, {type = "electric", decrease = 5}},
  height = spidertron.height, torso_rotation_speed = spidertron.torso_rotation_speed,
  distraction_cooldown = 300, min_pursue_time = 600, max_pursue_distance = 50, vision_distance = 40,
  ai_settings = {destroy_when_commands_fail = false, allow_try_return_to_spawner = false},
  is_military_target = true,
  dying_explosion = "spidertron-explosion", corpse = "spidertron-remnants",
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
-- Airborne: the destroyer's body drawn a tile up, over its own shadow on the ground (a combat robot is lifted by the
-- engine, a unit is not: drawn where it stood, its selection box hung a tile above it; the user's screenshot, 2026-10-21).
local function flying()
  local a = {layers = {}}
  for _, l in ipairs(table.deepcopy(defender.in_motion).layers) do
    l.shift = {(l.shift or {0, 0})[1], (l.shift or {0, 0})[2] - 1}
    table.insert(a.layers, l)
  end
  local sh = table.deepcopy(defender.shadow_in_motion)
  sh.draw_as_shadow = true
  table.insert(a.layers, sh)
  return a
end
harrier.run_animation = flying()
local ha = gun(10, 15, 15)
ha.animation = flying()
harrier.attack_parameters = ha
harrier.dying_explosion = "destroyer-robot-explosion"
harrier.corpse = "destroyer-remnants"
harrier.resistances = {{type = "fire", percent = 100}}
tint(harrier.run_animation, {})
tint(harrier.attack_parameters.animation, {})

-- Hauler: the car's hull, slow and armoured, lightly armed: it carries a settlement's exports to the uplink.
local car = data.raw.car.car
local hauler = base_unit("lp-hauler")
hauler.max_health = shared.units["lp-hauler"].health
-- Slower than every escort with a margin (tanks 0.09): at 0.08, tank escorts could not regain their station.
hauler.movement_speed = 0.065
hauler.distance_per_frame = 0.5
hauler.vision_distance = 20
hauler.collision_box = {{-0.8, -0.8}, {0.8, 0.8}}
hauler.selection_box = {{-1, -1.2}, {1, 1.2}}
hauler.run_animation = table.deepcopy(car.animation)
local hla = gun(4, 10, 30)
hla.animation = table.deepcopy(car.animation)
hauler.attack_parameters = hla
hauler.dying_explosion = "medium-explosion"
hauler.corpse = "car-remnants"
hauler.resistances = {{type = "physical", decrease = 4, percent = 30}, {type = "fire", percent = 50},
  {type = "explosion", percent = 20}}
tint(hauler.run_animation, {}, {r = 1, g = 0.75, b = 0.45, a = 1})
tint(hauler.attack_parameters.animation, {}, {r = 1, g = 0.75, b = 0.45, a = 1})

-- Buggy: the car's hull, fast and light, a machine gun (Grubstake's raider and convoy escort).
local buggy = base_unit("lp-buggy")
buggy.max_health = shared.units["lp-buggy"].health
buggy.movement_speed = 0.2
buggy.distance_per_frame = 0.5
buggy.vision_distance = 30
buggy.collision_box = {{-0.7, -0.7}, {0.7, 0.7}}
buggy.selection_box = {{-0.9, -1.1}, {0.9, 1.1}}
buggy.run_animation = table.deepcopy(car.animation)
local ba = gun(5, 13, 10)
ba.animation = table.deepcopy(car.animation)
buggy.attack_parameters = ba
buggy.dying_explosion = "medium-explosion"
buggy.corpse = "car-remnants"
buggy.resistances = {{type = "physical", decrease = 2, percent = 15}}
tint(buggy.run_animation, {})
tint(buggy.attack_parameters.animation, {})

-- Tree units (docs/reviews/2026-10-14-identity-trees-consult.md; scripts/rd.lua buys them into a corporation's mix).
-- Lance (Serenity's Optics): a heavier, slower beam that outranges the player's troopers (15): 24 laser a shot every 60
-- ticks, range 17 (still inside a gun turret's 18), 110 health. Serenity's answer to armour (the RTS pass, 2026-10-21:
-- a hit heavy enough to go through a hull's flat 5; at 12 a shot it was a weaker rifle).
local lance = make_infantry("lp-lance", nil, "mech-armor")
lance.max_health = shared.units["lp-lance"].health
lance.attack_parameters = table.deepcopy(infantry.attack_parameters)
lance.attack_parameters.damage_modifier = 2.4
lance.attack_parameters.range = 17
lance.attack_parameters.cooldown = 60
lance.attack_parameters.ammo_type.action.action_delivery.max_length = 18
lance.resistances = table.deepcopy(infantry.resistances)
-- Slug buggy (Grubstake's Scrap arms): one heavy slug of 55 physical every 50 ticks, range 15, 240 health; shotgun
-- shells, so its Hand-loads cover it. The answer to vehicles (the RTS pass, 2026-10-21: three scattered pellets of 14
-- landed a quarter of their damage on a tank at range, and slugs lost to every hull; an anti-armour unit hits surely,
-- from as far as the hulls it hunts: at 12 against a tank's 15 they died closing in).
local slug = table.deepcopy(buggy)
slug.name = "lp-slug"
slug.max_health = shared.units["lp-slug"].health
slug.attack_parameters = gun(55, 15, 50, "shotgun-shell")
slug.attack_parameters.sound = table.deepcopy(data.raw.gun["shotgun"].attack_parameters.sound)
slug.attack_parameters.animation = table.deepcopy(buggy.attack_parameters.animation)
-- Plated against shells: a vehicle hunter carries armour against its prey's weapon (it lost to tanks with the slug fixed).
slug.resistances = {{type = "physical", decrease = 2, percent = 15}, {type = "explosion", percent = 40}}

-- Shock trooper (Serenity's Optics, after Lances): an electric beam that arcs to the next target and the next (a chain
-- on the destroyer's electric beam, base game: spiked 2026-10-14), a brief stun on the one it hits; 10 electric a hit and
-- six jumps, every 45 ticks, range 14, 160 health. The answer to massed troopers. The RTS pass (2026-10-21): range 12 ->
-- 14 (rifles at 15 outranged the unit meant to punish them); 12 a hit and four jumps -> 10 and six, so its damage is in
-- small hits that a hull's flat armour shrugs off (armour beats splash).
local arc_bounce = table.deepcopy(data.raw.beam["electric-beam-no-sound"])
arc_bounce.name = "lp-arc-bounce"
local arc_chain = {type = "chain-active-trigger", name = "lp-arc-chain", max_jumps = 6, max_range_per_jump = 6,
  jump_delay_ticks = 6, fork_chance = 0,
  action = {type = "direct", action_delivery = {type = "beam", beam = "lp-arc-bounce", max_length = 6.5, duration = 20,
    add_to_shooter = false, destroy_with_source_or_target = false, source_offset = {0, 0}}}}
local shock = make_infantry("lp-shock", nil, "mech-armor")
shock.max_health = shared.units["lp-shock"].health
shock.attack_parameters = {
  type = "beam", ammo_category = "electric", cooldown = 45, range = 14, range_mode = "bounding-box-to-bounding-box",
  damage_modifier = 1.0, source_direction_count = 8, source_offset = {0, -0.6},
  animation = infantry.attack_parameters.animation,
  ammo_type = {action = {type = "direct", action_delivery = {type = "instant", target_effects = {
    -- The chain first, in case the beam kills the target (as Space Age's tesla turret does).
    {type = "nested-result", action = {type = "direct", action_delivery = {type = "chain", chain = "lp-arc-chain"}}},
    {type = "nested-result", action = {type = "direct", action_delivery = {type = "beam", beam = "electric-beam",
      max_length = 15, duration = 20, add_to_shooter = false, destroy_with_source_or_target = false,
      source_offset = {0, -1}}}},
    {type = "create-sticker", sticker = "electric-mini-stun"},
  }}}},
}
shock.resistances = table.deepcopy(infantry.resistances)
table.insert(shock.resistances, {type = "electric", percent = 50})
-- Dynamite sapper (Grubstake's Scrap arms; the user chose it over a flamethrower buggy): a Shotgun hand's body that
-- throws dynamite, 80 explosion over 3 tiles, enemies only (the breacher's charge), from 11 tiles every 3 seconds.
-- Against a blob of troopers, and against the fence or wall in the way.
local sapper = make_infantry("lp-sapper", nil, "heavy-armor")
sapper.max_health = shared.units["lp-sapper"].health
sapper.movement_speed = 0.13
sapper.attack_parameters.range = 11
sapper.attack_parameters.cooldown = 180
sapper.attack_parameters.ammo_category = "grenade"
sapper.attack_parameters.sound = nil
sapper.attack_parameters.ammo_type.action.action_delivery.target_effects = {
  {type = "create-entity", entity_name = "grenade-explosion"},
  {type = "nested-result", action = {type = "area", radius = 3, force = "enemy", action_delivery = {
    type = "instant", target_effects = {{type = "damage", damage = {amount = 80, type = "explosion"}}}}}},
}

-- Aegis tank (Serenity's Line, after Warden armour): the tank's hull with a laser cannon, 45 laser a shot every 60 ticks,
-- range 15, 1,100 health, physical 30% and 5, explosion 40%. The answer to the player's battle tanks.
local aegis = make_tank("lp-aegis")
aegis.max_health = shared.units["lp-aegis"].health
aegis.attack_parameters = table.deepcopy(infantry.attack_parameters)
aegis.attack_parameters.damage_modifier = 4.5
aegis.attack_parameters.cooldown = 60
aegis.attack_parameters.animation = table.deepcopy(tank.attack_parameters.animation)
aegis.resistances = {{type = "physical", decrease = 5, percent = 30}, {type = "explosion", decrease = 5, percent = 40},
  {type = "laser", decrease = 5}, {type = "electric", decrease = 5}}
-- Dozer (Grubstake's Wheels, after Slug buggies): the hauler's hull, 1,800 health, physical 40% and 5, a ram (60
-- physical at 2 tiles, every 60 ticks), slow. Its one heavy: it pushes a fence or wall open for the shotguns.
local dozer = table.deepcopy(hauler)
dozer.name = "lp-dozer"
dozer.max_health = shared.units["lp-dozer"].health
dozer.movement_speed = 0.07
dozer.resistances = {{type = "physical", decrease = 5, percent = 40}, {type = "fire", percent = 50},
  {type = "explosion", decrease = 5, percent = 20}, {type = "laser", decrease = 5}, {type = "electric", decrease = 5}}
dozer.attack_parameters = gun(60, 2, 60, "melee")
dozer.attack_parameters.sound = nil
dozer.attack_parameters.animation = table.deepcopy(hauler.attack_parameters.animation)
-- Scavenger harrier (Grubstake's Wheels): a harrier with rockets, 18 explosion every 40 ticks, range 14, 180 health.
-- It flies over walls to the player's artillery, mortars and radars.
local scavenger = table.deepcopy(harrier)
scavenger.name = "lp-scavenger"
scavenger.max_health = shared.units["lp-scavenger"].health
local sa = gun(18, 14, 40, "rocket")
sa.ammo_type.action.action_delivery.target_effects[2].damage.type = "explosion"
sa.animation = table.deepcopy(harrier.attack_parameters.animation)
scavenger.attack_parameters = sa

-- Railgunner (Serenity; the user: "a biter clearing unit like a hand mounted railgun that's at its best against biters"):
-- a slug that pierces everything on a line 30 tiles long (out of a medium worm's reach), 250 to what carries the lp-biter
-- trigger target (biters, spawners, worms: data-final-fixes.lua; two kill a big biter), 10 to anything else, every 90 ticks; laser, so
-- Serenity's research covers it. 140 health. A packed biter attack dies in a row; a wall barely notices it.
-- Its tracer: the laser turret's beam without the beam's own damage (it did most of the harm to walls).
local rail_beam = table.deepcopy(data.raw.beam["laser-beam"])
rail_beam.name = "lp-rail-beam"
rail_beam.action = nil
-- Its look: Serenity's charcoal (its walls' and turrets'), not the Line trooper's slate-teal, and a size larger, so it
-- reads as the heavy one at a glance.
local railgunner = make_infantry("lp-railgunner", {r = 0.32, g = 0.35, b = 0.38, a = 1}, "mech-armor")
-- Its firing pose: its own (the mech armour's, tinted once). The Line trooper's, tinted again, went black (a second tint
-- finds no mask left and darkens the whole body; the user, 2026-10-20: "turn black only when they fire").
local rail_pose = railgunner.attack_parameters.animation
local function grow(t, k, seen)
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if t.filename or t.filenames or t.stripes then
    t.scale = (t.scale or 1) * k
    if t.shift then t.shift = {t.shift[1] * k, t.shift[2] * k} end
  end
  for _, v in pairs(t) do grow(v, k, seen) end
end
grow(railgunner.run_animation, 1.15, {})
railgunner.max_health = shared.units["lp-railgunner"].health
railgunner.movement_speed = 0.1
railgunner.vision_distance = 34
local function rail(amount, mask)
  return {type = "line", range = 30, width = 1.5, force = "enemy", trigger_target_mask = mask,
    action_delivery = {type = "instant", target_effects = {{type = "damage", damage = {amount = amount, type = "physical"}},
      {type = "create-entity", entity_name = "explosion-hit"}}}}
end
railgunner.attack_parameters = {
  type = "projectile", ammo_category = "laser", cooldown = 90, cooldown_deviation = 0.1, range = 30,
  range_mode = "bounding-box-to-bounding-box",
  -- Space Age's railgun gunshot (the tank cannon's without it). Its beam drawn along the shot's line (range_effects
  -- on the line) was tried and withdrawn: with it the railgunners' shots fared worse in a siege's assault, which then
  -- failed (bombard, seed 12345: 10 of 22 back and aborted, against 17 of 22 and done without it; reverting that line
  -- alone restored it).
  sound = table.deepcopy((data.raw.gun["railgun"] or data.raw.gun["tank-cannon"]).attack_parameters.sound),
  animation = (function() grow(rail_pose, 1.15, {}); return rail_pose end)(),
  ammo_type = {action = {
    {type = "direct", action_delivery = {type = "beam", beam = "lp-rail-beam", max_length = 31, duration = 8,
      source_offset = {0, -1}}},
    rail(250, {"lp-biter"}),
    rail(10, {"common"}),
  }},
}
railgunner.resistances = table.deepcopy(infantry.resistances)

-- The design sheet's picks (the user, 2026-10-21; tests/lp-shots/data.lua mocks them).
-- Prism (Serenity's Optics, after Lances): a tank with its turret and a small laser head on top; a laser of 14 (and the
-- beam's own 10) that splits on what it hits to the targets round it (five jumps of 10, forking), every 50 ticks, range 16.
-- Against a blob of troopers; little against a wall (one target, one beam) or a hull (the RTS pass, 2026-10-21: 22 and
-- three jumps of 12 before, moved into more, smaller hits that flat armour shrugs off).
local laser_head = data.raw["electric-turret"]["laser-turret"].prepared_animation
local prism = make_tank("lp-prism", nil, {{tank_car.turret_animation}, {laser_head, 0.5, 0, -1.0}})
prism.max_health = shared.units["lp-prism"].health
local function beam_copy(src, name, color, damage, dtype)
  local b = table.deepcopy(data.raw.beam[src])
  b.name = name
  local seen = {}
  local function paint(t)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    if t.filename or t.filenames then t.tint = color end
    for _, v in pairs(t) do paint(v) end
  end
  paint(b.graphics_set)
  b.action = damage and {type = "direct", action_delivery = {type = "instant", target_effects = {
    {type = "damage", damage = {amount = damage, type = dtype}}}}} or nil
  return b
end
local prism_split = beam_copy("laser-beam", "lp-prism-split", {r = 0.85, g = 0.45, b = 1, a = 1}, 10, "laser")
local prism_chain = {type = "chain-active-trigger", name = "lp-prism-chain", max_jumps = 5, max_range_per_jump = 6,
  jump_delay_ticks = 3, fork_chance = 0.6, fork_chance_increase_per_quality_level = 0,
  action = {type = "direct", action_delivery = {type = "beam", beam = "lp-prism-split", max_length = 6.5, duration = 18,
    add_to_shooter = false, destroy_with_source_or_target = false, source_offset = {0, 0}}}}
prism.attack_parameters = {
  type = "beam", ammo_category = "laser", cooldown = 50, range = 16, range_mode = "bounding-box-to-bounding-box",
  source_direction_count = 8, source_offset = {0, -1.6}, animation = table.deepcopy(prism.run_animation),
  ammo_type = {action = {type = "direct", action_delivery = {type = "instant", target_effects = {
    {type = "nested-result", action = {type = "direct", action_delivery = {type = "chain", chain = "lp-prism-chain"}}},
    {type = "nested-result", action = {type = "direct", action_delivery = {type = "beam", beam = "laser-beam",
      max_length = 17, duration = 20, add_to_shooter = false, destroy_with_source_or_target = false, source_offset = {0, -1.6}}}},
    {type = "damage", damage = {amount = 14, type = "laser"}},
  }}}},
}
prism.resistances = {{type = "physical", decrease = 3, percent = 20}, {type = "laser", decrease = 5}, {type = "electric", decrease = 5},
  {type = "explosion", percent = 10}}

-- Tesla (Serenity's Siege): the tesla turret's head on a tank's hull; lightning of 20 that jumps along seven more targets
-- (12 each, 8 tiles a jump; 30, five of 18 before the RTS pass, 2026-10-21: smaller hits, which hulls shrug off), every
-- 75 ticks, range 14. What it strikes that holds a charge (a laser turret, an
-- accumulator, a roboport) loses most of it (control.lua, on_entity_damaged): a turret line goes dark a moment.
local tesla_turret = data.raw["electric-turret"]["tesla-turret"]
local tesla_head = tesla_turret and tesla_turret.prepared_animation or laser_head
local tesla = make_tank("lp-tesla", nil, {{tesla_head, 0.6, 0, 0.9}})
tesla.max_health = shared.units["lp-tesla"].health
local tesla_jump = beam_copy("electric-beam-no-sound", "lp-tesla-jump", {r = 0.7, g = 0.85, b = 1, a = 1}, 12, "electric")
local tesla_chain = {type = "chain-active-trigger", name = "lp-tesla-chain", max_jumps = 7, max_range_per_jump = 8,
  jump_delay_ticks = 4, fork_chance = 0,
  action = {type = "direct", action_delivery = {type = "beam", beam = "lp-tesla-jump", max_length = 8.5, duration = 20,
    add_to_shooter = false, destroy_with_source_or_target = false, source_offset = {0, 0}}}}
tesla.attack_parameters = {
  type = "beam", ammo_category = "electric", cooldown = 75, range = 14, range_mode = "bounding-box-to-bounding-box",
  source_direction_count = 8, source_offset = {0, -1.4}, animation = table.deepcopy(tesla.run_animation),
  ammo_type = {action = {type = "direct", action_delivery = {type = "instant", target_effects = {
    {type = "nested-result", action = {type = "direct", action_delivery = {type = "chain", chain = "lp-tesla-chain"}}},
    {type = "nested-result", action = {type = "direct", action_delivery = {type = "beam", beam = "electric-beam",
      max_length = 15, duration = 20, add_to_shooter = false, destroy_with_source_or_target = false, source_offset = {0, -1.4}}}},
    {type = "damage", damage = {amount = 20, type = "electric"}},
  }}}},
}
tesla.resistances = {{type = "physical", decrease = 3, percent = 20}, {type = "electric", decrease = 5, percent = 80},
  {type = "explosion", percent = 10}, {type = "laser", decrease = 5}}

-- Scorcher (Grubstake's Scrap arms): the flamethrower turret's head on a tank's hull; a machine gun (6 a round, 6 a
-- second, range 13) most of the time, and three bursts of flame for walls, turrets and packed units, fired by script
-- (scripts/scorcher.lua) and refilled slowly. Fire does not hurt it.
local flamer_head = data.raw["fluid-turret"]["flamethrower-turret"].prepared_animation.north
local scorcher = make_tank("lp-scorcher", nil, {{flamer_head, 0.95, 0, -0.2}})
scorcher.max_health = shared.units["lp-scorcher"].health
local sca = gun(6, 13, 10)
sca.animation = table.deepcopy(scorcher.run_animation)
scorcher.attack_parameters = sca
scorcher.resistances = {{type = "physical", decrease = 3, percent = 25}, {type = "fire", percent = 100},
  {type = "explosion", decrease = 5, percent = 30}, {type = "laser", decrease = 5}, {type = "electric", decrease = 5}}
data:extend({prism, prism_split, prism_chain, tesla, tesla_jump, tesla_chain, scorcher})

-- The howitzer truck (the user, 2026-10-23: "the take-away howitzer a mortar truck ... the arty sprites but stuck onto
-- a tank"): the artillery's cannon on a tank's hull, a hauler's pace and gun. It is the hauler of any siege that takes
-- the howitzer, and gives way to the howitzer turret once deployed (siege.lua); it never fires the cannon.
local art = data.raw["artillery-turret"]["artillery-turret"]
local truck = make_tank("lp-howitzer-truck", nil, {{art.cannon_base_pictures, 1, 0, -0.97}, {art.cannon_barrel_pictures, 1, 0, -0.97}})
-- Its cannon in the faction's colour, as the howitzer's is (the hull takes it on its mask only).
-- The cannon's art has 256 directions and the hull 64: the engine picked the cannon's frame by the hull's direction (a
-- truck facing south-east had its barrel north-north-east). Read as 64 directions of four frames, frame 0 held, its
-- frame for each direction is every fourth of the 256: the hull's own bearing.
for i = #tank_car.animation.layers + 1, #truck.run_animation.layers do
  local l = truck.run_animation.layers[i]
  if not l.draw_as_shadow then l.tint = shared.TINT end
  l.direction_count, l.frame_count, l.repeat_count = 64, 4, nil
  l.frame_sequence = {1, 1}
end
truck.max_health = 1200   -- the howitzer's (siege.lua carries health across the change)
for _, k in ipairs({"movement_speed", "distance_per_frame", "vision_distance", "resistances"}) do truck[k] = table.deepcopy(hauler[k]) end
local tra = table.deepcopy(hauler.attack_parameters)
tra.animation = table.deepcopy(truck.run_animation)
truck.attack_parameters = tra
truck.loot = {{item = "steel-plate", probability = 0.5, count_min = 8, count_max = 8}}
data:extend({truck})

-- Loot (the faction loot consult): a unit drops a little of its own kit, half the time. The player's units (trooper,
-- breacher, rocket trooper, battle tank) drop nothing: they are the player's.
local UNIT_LOOT = {[infantry] = {{"electronic-circuit", 1, 1}}, [shotgun_hand] = {{"shotgun-shell", 1, 3}},
  [buggy] = {{"engine-unit", 1, 1}}, [harrier] = {{"engine-unit", 1, 1}}, [tank] = {{"steel-plate", 4, 4}, {"engine-unit", 1, 1}},
  [walker] = {{"steel-plate", 8, 8}, {"advanced-circuit", 2, 2}}, [hauler] = {{"steel-plate", 8, 8}},
  [lance] = {{"electronic-circuit", 2, 2}}, [slug] = {{"piercing-shotgun-shell", 2, 4}}, [shock] = {{"battery", 1, 1}},
  [sapper] = {{"explosives", 1, 2}}, [aegis] = {{"steel-plate", 4, 4}}, [dozer] = {{"steel-plate", 6, 6}, {"engine-unit", 1, 1}},
  [scavenger] = {{"rocket", 1, 2}}, [railgunner] = {{"steel-plate", 2, 2}, {"advanced-circuit", 1, 1}}}
for u, list in pairs(UNIT_LOOT) do
  u.loot = {}
  for _, m in ipairs(list) do table.insert(u.loot, {item = m[1], probability = 0.5, count_min = m[2], count_max = m[3]}) end
end

data:extend({infantry, tank, walker, harrier, trooper, breacher, battle_tank, hauler, buggy, shotgun_hand, pellet,
  lance, slug, arc_bounce, arc_chain, shock, sapper, aegis, dozer, scavenger, rail_beam, railgunner})
