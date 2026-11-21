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

-- Suppression (2026-11-09, the user's "OK on your proposals"): a machine gun's rounds slow infantry caught under them, a
-- round in SUPPRESS_CHANCE to SUPPRESS_SPEED for SUPPRESS_TICKS. Infantry alone (the lp-soft trigger target, make_infantry):
-- a hull, a biter and the player's character shrug it off.
local SUPPRESS_CHANCE, SUPPRESS_SPEED, SUPPRESS_TICKS = 0.2, 0.45, 40
data:extend({{type = "trigger-target-type", name = "lp-soft"},
  {type = "sticker", name = "lp-suppressed", flags = {"not-on-map"}, hidden = true, duration_in_ticks = SUPPRESS_TICKS,
    target_movement_modifier = SUPPRESS_SPEED, vehicle_speed_modifier = 1}})
local function suppressing(a)
  local effects = a.ammo_type.action.action_delivery.target_effects
  -- (A small circle at the hit, not "direct": a direct action takes no mask, and the tanks were slowed with the troopers,
  -- scenario suppress; air.lua does the same for fliers.)
  effects[#effects + 1] = {type = "nested-result", action = {type = "area", radius = 0.3, force = "not-same",
    trigger_target_mask = {"lp-soft"}, action_delivery = {type = "instant", target_effects = {{type = "create-sticker", sticker = "lp-suppressed",
      probability = SUPPRESS_CHANCE}}}}}
  return a
end
local SOFT_MASK = table.deepcopy((data.raw["utility-constants"].default.default_trigger_target_mask_by_type or {}).unit
  or {"common", "ground-unit"})
table.insert(SOFT_MASK, "lp-soft")

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
  -- Struck, it sparks as the car does (the medium biter's hit, purple blood, had come with its body: the user, 2026-11-09,
  -- "everyone bleeds purple??").
  u.damaged_trigger_effect = table.deepcopy(data.raw.car.car.damaged_trigger_effect)

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
  {type = "trigger-target-type", name = "lp-nest"},
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
  -- Infantry: what a machine gun suppresses (lp-soft).
  u.trigger_target_mask = table.deepcopy(SOFT_MASK)
  -- (Ground units pass through each other, vanilla's unit mask: tried colliding, 2026-11-09, at the user's ask, "the
  -- infantry has no self collision ... they bunch up too much". Every unit colliding failed 13 of 305 runs (raids stuck
  -- at gaps, tanks in their blocks, herds through the camps); infantry alone failed 5 more, as a unit without
  -- not_colliding_with_itself collides with every unit that has it, biters and vehicles too: herds shoved through
  -- squads, crews blocked. A layer of their own (object, water_tile) keeps biters out but an open gate still blocks
  -- object: tanks shut in their blocks. Open: DESIGN.md.)
  u.selection_box = {{-0.4, -1.4}, {0.4, 0.2}}
  -- Its run: the engineer's running, 8 directions round the compass as a unit reads them. Running with a gun has 18,
  -- the gun's direction against the legs', north to south by the east only (the engine plays them backwards for the
  -- rest): read as 18 headings round the compass, a trooper walking south faced west (the user, 2026-11-08: "the
  -- troopers are basically moonskating ... their model is turned to the left"). The mech armour has no plain run: its 40 kept, its facings not yet
  -- checked (its 8 picked by stripes did not read right either; /lp parade ring).
  u.run_animation = table.deepcopy(look.running or look.running_with_gun)
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
-- armour their recipe takes, Grubstake's Shotgun hands heavy armour too, in its colours. Roles told apart by vanilla's
-- own armour sets (the unit pass, 2026-11-08: the user chose them, "Probably A", over a body of our own; each is drawn
-- frame by frame over the engineer, so it follows the run): Grubstake's sapper none (a light runner with its charges),
-- the player's breacher and flame trooper the power armour (bulky; told apart by their tints), the rocket trooper none.
-- The mech armour stays Kessler-Hayashi's look.
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
for _, t in ipairs(pellet.action.action_delivery.target_effects) do if t.type == "damage" then t.damage.amount = 9 end end
-- Through its own side (force_condition defaults to all: six Shotgun hands lost 555 of 720 health to each other).
pellet.force_condition = "not-same"

-- Breacher: the player's infantry with demolition charges. Bullets barely scratch walls (2.4 of 6 damage), so
-- troopers alone died in front of walled lasers (siege). A charge bursts over 2.5 (enemies
-- only), thrown 12 tiles: walls take 63 of 100 (a segment in 8 throws, several at once), a turret 100.
local breacher = make_infantry("lp-breacher", {r = 0.75, g = 0.9, b = 0.45, a = 1}, "power-armor")
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
local rocket_trooper = make_infantry("lp-rocket-trooper", {r = 0.95, g = 0.6, b = 0.4, a = 1})
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

-- Flamethrower trooper (the player's, with the third level; the user, 2026-10-24: "tackle player units too"): the arena
-- had every one of the player's units losing to biters from evolution 0.8 and to the big breeds; this is the answer to a
-- swarm. The handheld flamethrower's stream, its splash (2.5, its enemies only) and the burning it leaves on what it hits
-- (the fire sticker), but no burning ground: ground fire burns its own side as well, and the corporations' flamers had
-- killed eight to eleven of their own a run that way. Range 15: rifles and lances outrange it; armour shrugs it off.
local flame_trooper = make_infantry("lp-flame-trooper", {r = 0.95, g = 0.4, b = 0.18, a = 1}, "power-armor")
local trooper_stream = table.deepcopy(data.raw.stream["handheld-flamethrower-fire-stream"])
trooper_stream.name = "lp-trooper-fire-stream"
-- Its own burn: 4 fire a second for 4 seconds (vanilla's fire sticker, 10 a second for 30, on every target of the
-- splash, had it beating rifles +95 and tanks +51 in the arena, 2026-10-24).
local trooper_burn = table.deepcopy(data.raw.sticker["fire-sticker"])
trooper_burn.name = "lp-trooper-burn"
trooper_burn.duration_in_ticks = 4 * 60
trooper_burn.damage_per_tick = {amount = 4 / 60, type = "fire"}
trooper_burn.spread_fire_entity = nil
trooper_burn.fire_spread_cooldown = nil
local actions = {}
for _, a in ipairs(trooper_stream.action or {}) do
  if a.type == "area" then
    a.force = "not-same"
    for _, e in ipairs(a.action_delivery.target_effects or {}) do
      if e.type == "create-sticker" then e.sticker = "lp-trooper-burn" end
      -- 1 a lick, not 2 (at 2 with its burn it still beat rifles by +90).
      if e.type == "damage" then e.damage.amount = 1 end
    end
    table.insert(actions, a)
  end
end
trooper_stream.action = actions
flame_trooper.attack_parameters = {
  type = "stream", ammo_category = "flamethrower", cooldown = 4, range = 13, min_range = 0,
  range_mode = "bounding-box-to-bounding-box", fire_penalty = 0, gun_barrel_length = 0.6, gun_center_shift = {0, -1},
  sound = table.deepcopy(data.raw.gun["flamethrower"].attack_parameters.cyclic_sound and nil or data.raw.gun["flamethrower"].attack_parameters.sound),
  cyclic_sound = table.deepcopy(data.raw.gun["flamethrower"].attack_parameters.cyclic_sound),
  animation = flame_trooper.attack_parameters.animation,
  ammo_type = {action = {type = "direct", action_delivery = {type = "stream", stream = "lp-trooper-fire-stream"}}},
}
data:extend({flame_trooper, trooper_stream, trooper_burn})

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
-- A hull's ammunition cooking off when it dies (the user, 2026-11-09: "exploding tanks could show the scorcher burn effect
-- from their turret for a short time? (representing ammo cooking off inside)", then, on the first: "a little overdramatic
-- perhaps? or maybe we could have multiple versions of it?"). Each part on its own chance, so wrecks differ: a flame in
-- the hull (half of them; a fire of its own, COOK_TICKS, no spread), a couple of pops round the turret, a longer string
-- of them starting later, and now and then the turret going up a second and a half on. Looks: no damage beyond the
-- fire's own. The Scorcher's fuel blast replaces it (its dying effects, below). (The first: three flames, five pops on
-- every hull, a column of fire on each wreck.)
local COOK_TICKS = 150
local COOK = {
  {name = "lp-cookoff-short", chance = 0.6, delay = 6, pops = 2, gap = 25, blast = "explosion"},
  {name = "lp-cookoff-long", chance = 0.3, delay = 40, pops = 4, gap = 35, blast = "explosion"},
  {name = "lp-cookoff-turret", chance = 0.12, delay = 90, pops = 1, gap = 1, blast = "medium-explosion"},
}
local COOK_FIRE = 0.5
do
  local f = table.deepcopy(data.raw.fire["fire-flame"])
  f.name = "lp-cookoff-fire"
  f.initial_lifetime, f.maximum_lifetime, f.lifetime_increase_by = COOK_TICKS, COOK_TICKS, 0
  f.spread_delay, f.maximum_spread_count = 1e6, 0
  -- (Its scorch fades soon after: a fire stays an entity while its burnt patch shows, fire-flame's 30 s.)
  f.burnt_patch_lifetime = COOK_TICKS + 300
  f.damage_per_tick = {amount = 4 / 60, type = "fire"}
  f.emissions_per_second = nil
  f.hidden = true
  data:extend({f})
  for _, c in ipairs(COOK) do
    data:extend({{type = "delayed-active-trigger", name = c.name, delay = c.delay, repeat_count = c.pops,
      repeat_delay = c.gap, cancel_when_source_is_destroyed = false,
      action = {type = "direct", action_delivery = {type = "instant", target_effects = {
        {type = "create-explosion", entity_name = c.blast, offset_deviation = {{-0.6, -0.6}, {0.6, 0.6}}, offsets = {{0, -0.6}}}}}}}})
  end
end
local COOKOFF = {{type = "create-fire", entity_name = "lp-cookoff-fire", initial_ground_flame_count = 1, offsets = {{0, -0.3}},
  probability = COOK_FIRE}}
for _, c in ipairs(COOK) do
  COOKOFF[#COOKOFF + 1] = {type = "nested-result", probability = c.chance,
    action = {type = "direct", action_delivery = {type = "delayed", delayed_trigger = c.name}}}
end

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
tank.dying_trigger_effect = table.deepcopy(COOKOFF)
tank.corpse = "tank-remnants"
-- Armour that yellow ammo still hurts: a flat 10 made a gun turret's 5-damage rounds useless (seed 4242:
-- seven raids, no unit lost).
-- Fire: a flat 2 as well as 60% (the user, 2026-11-09, Scorchers against Kessler-Hayashi's tanks: "Perhaps some fire
-- resistance for all vehicles that deserve it?"): a hull shrugs off burning ground, its small ticks, and still takes the
-- stream's hit (the arena at 420 parts: seven tanks dead in 20 to 25 s to one to three Scorchers of six, its gun alone
-- doing about 14 a second).
tank.resistances = {{type = "physical", decrease = 3, percent = 20}, {type = "fire", decrease = 2, percent = 60},
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
-- Heavier and slower since 0.2.266, its damage a second the same (the user, 2026-11-09: "halve the fire rate of our tank
-- and double its damage"): 100 and 240 every 180 ticks, not 50 and 120 every 90.
battle_tank.attack_parameters.cooldown = 180
battle_tank.attack_parameters.ammo_type = shell("lp-battle-tank-heavy", 100, 240)

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

-- The fliers (the user, 2026-10-23: "give Kessler the actual high tech fliers, whereas Grubstake is a more scrappy
-- opponent ... simpler drones, if not even kamikaze drones"): Grubstake's scrap drone (lp-harrier: the distractor's
-- body, weak, cheap, many) and bomb drone (lp-scavenger: flies at a target and bursts on it), Kessler-Hayashi's laser
-- drone (the destroyer's body, armoured, a laser beam).
local harrier = base_unit("lp-harrier")
harrier.max_health = shared.units["lp-harrier"].health
harrier.movement_speed = 0.25
harrier.vision_distance = 30
harrier.collision_box = {{-0.3, -0.3}, {0.3, 0.3}}
harrier.selection_box = {{-0.5, -1.5}, {0.5, -0.5}}
-- Fliers collide with each other (the user, 2026-11-08: "the fact they don't collide with each other was bothering me").
-- Measured both ways (scenario airspace): passing through each other, 12 harriers strafing sat in one pile for 15 s, 35%
-- of them overlapping (28% in a raid, 23% of laser drones); colliding, 0 to 2%, the same arrival, none stuck.
harrier.collision_mask = {layers = {["lp-air"] = true}}
harrier.trigger_target_mask = {"lp-air-unit"}
harrier.render_layer = "air-object"
-- Airborne: the destroyer's body drawn a tile up, over its own shadow on the ground (a combat robot is lifted by the
-- engine, a unit is not: drawn where it stood, its selection box hung a tile above it; the user's screenshot, 2026-10-21).
local function flying(robot)
  local defender = data.raw["combat-robot"][robot or "distractor"]
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
-- A scrap drone: 6 a shot every 20 ticks, range 12.
local ha = gun(6, 12, 20)
ha.animation = flying()
harrier.attack_parameters = ha
harrier.dying_explosion = "distractor-robot-explosion"
harrier.corpse = "distractor-remnants"
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
local ba = suppressing(gun(5, 13, 10))
ba.animation = table.deepcopy(car.animation)
buggy.attack_parameters = ba
buggy.dying_explosion = "medium-explosion"
buggy.corpse = "car-remnants"
buggy.resistances = {{type = "physical", decrease = 2, percent = 15}}
tint(buggy.run_animation, {})
tint(buggy.attack_parameters.animation, {})

-- The player's gun buggy (0.2.438; the user, 2026-11-16: "we are lacking a unit at bandwidth 2 after all. Perhaps a buggy?
-- And instead of a mounted SMG, some kind of slightly higher caliber?"): vanilla's car in the player's colour, as the
-- battle tank is vanilla's tank. 10 tiles a second, the army's fastest, the one to reach a defend beacon's far edge in
-- time. Light: 380 health, a buggy's plating.
-- Its gun an autocannon (the user, the same night: "much lower ROF and impacts with oomph"): a high-explosive round every
-- 30 ticks to 16 (inside a gun turret's 18), 20 explosion to what it hits and a 1.25-tile blast of 6 round it, a small
-- explosion at the hit, suppressing infantry in the blast; the heavy gunshot, lower. Explosion, not physical: a hull's
-- flat 5 and 30% take a third of each round. Set in the arena at 4 of bandwidth: 25 physical and a 10 blast at 3 won 35
-- of 36, Kessler-Hayashi's tank and the Aegis among them; 20 and 6 explosion at 3 won 27, the Dozer and rocket troopers
-- among them; at 4 it wins 17, every infantry, buggy and flier, and loses to every hull, the bigger biters and Shock
-- troopers. (A machine gun before it, the same night: 12 every 10 ticks beat the hulls at 3; 5 every 4 won 20 at 3.)
local gun_buggy = base_unit("lp-gun-buggy")
gun_buggy.max_health = 380
gun_buggy.movement_speed = 0.17
gun_buggy.distance_per_frame = 0.5
gun_buggy.vision_distance = 30
gun_buggy.collision_box = {{-0.7, -0.7}, {0.7, 0.7}}
gun_buggy.selection_box = {{-0.9, -1.1}, {0.9, 1.1}}
gun_buggy.run_animation = table.deepcopy(car.animation)
local GB = {direct = 20, blast = 6, radius = 1.25, cooldown = 30, range = 16}
local gba = gun(GB.direct, GB.range, GB.cooldown)
gba.cooldown_deviation = 0.05
gba.sound = {variations = {{filename = "__base__/sound/fight/heavy-gunshot-1.ogg", volume = 0.7},
  {filename = "__base__/sound/fight/heavy-gunshot-2.ogg", volume = 0.7},
  {filename = "__base__/sound/fight/heavy-gunshot-3.ogg", volume = 0.7}}, speed = 0.8, category = "weapon"}
do
  local d = gba.ammo_type.action.action_delivery
  d.source_effects = {type = "create-explosion", entity_name = "explosion-gunshot"}
  d.target_effects = {{type = "create-entity", entity_name = "explosion"},
    {type = "damage", damage = {amount = GB.direct, type = "explosion"}},
    {type = "nested-result", action = {type = "area", radius = GB.radius, force = "not-same",
      action_delivery = {type = "instant", target_effects = {{type = "damage", damage = {amount = GB.blast, type = "explosion"}}}}}},
    -- (Suppression on infantry alone, the lp-soft mask, as suppressing() does: hulls and biters shrug it off.)
    {type = "nested-result", action = {type = "area", radius = GB.radius, force = "not-same", trigger_target_mask = {"lp-soft"},
      action_delivery = {type = "instant", target_effects = {{type = "create-sticker", sticker = "lp-suppressed",
        probability = 0.5}}}}}}
end
gba.animation = table.deepcopy(car.animation)
gun_buggy.attack_parameters = gba
gun_buggy.dying_explosion = "medium-explosion"
gun_buggy.corpse = "car-remnants"
gun_buggy.resistances = {{type = "physical", decrease = 2, percent = 15}, {type = "fire", decrease = 2, percent = 40}}
tint(gun_buggy.run_animation, {}, {r = 1, g = 0.82, b = 0.55, a = 1})
tint(gun_buggy.attack_parameters.animation, {}, {r = 1, g = 0.82, b = 0.55, a = 1})

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
local sapper = make_infantry("lp-sapper", nil)
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
-- Bomb drone (Grubstake's Wheels; id lp-scavenger, once a harrier with rockets): a scrap drone, quicker, that flies
-- over walls at the player's artillery, mortars and radars and bursts on arrival, BOMB explosion over BOMB_R tiles
-- (its enemies only), and dies in it (a damage effect on its attack's source: spiked, 2026-10-23).
-- Its blast spreads 2.5 and the target takes as much again (the arena, 2026-10-23: over 3 at 20 parts it beat squads
-- +40 to +85 and a turret line +5: its value moved to what it dives on).
local BOMB, BOMB_R = 150, 2.5
local scavenger = table.deepcopy(harrier)
scavenger.name = "lp-scavenger"
scavenger.max_health = shared.units["lp-scavenger"].health
scavenger.movement_speed = 0.3
-- Its own look (the user, 2026-10-23): the defender's body, the smallest of the three, in hazard red: the one with the
-- charge in it, told at a glance from the scrap drone (the distractor's) and the laser drone (the destroyer's).
local HAZARD = {r = 0.95, g = 0.32, b = 0.15, a = 1}
scavenger.run_animation = flying("defender")
tint(scavenger.run_animation, {}, HAZARD)
scavenger.dying_explosion = "defender-robot-explosion"
scavenger.corpse = "defender-remnants"
scavenger.attack_parameters = {type = "projectile", ammo_category = "rocket", range = 1.5, cooldown = 30,
  range_mode = "bounding-box-to-bounding-box", animation = table.deepcopy(scavenger.run_animation),
  ammo_type = {action = {type = "direct", action_delivery = {type = "instant",
    target_effects = {{type = "create-entity", entity_name = "big-explosion"},
      {type = "damage", damage = {amount = BOMB, type = "explosion"}},
      {type = "nested-result", action = {type = "area", radius = BOMB_R, force = "not-same", action_delivery = {
        type = "instant", target_effects = {{type = "damage", damage = {amount = BOMB, type = "explosion"}}}}}}},
    source_effects = {{type = "damage", damage = {amount = 10000, type = "physical"}}}}}}}
-- Shot down, its bomb goes off where it lands (fall.lua, shared.FALL): the same blast, from no one. Its wreck its own
-- (defender-remnants is the player's defenders' too, and the fall goes by the wreck).
do
  local b = table.deepcopy(data.raw.explosion["big-explosion"])
  b.name = "lp-scavenger-bomb"
  b.created_effect = {type = "direct", action_delivery = {type = "instant", target_effects = {{type = "nested-result",
    action = {type = "area", radius = BOMB_R, action_delivery = {type = "instant", target_effects = {
      {type = "damage", damage = {amount = BOMB, type = "explosion"}}}}}}}}}
  local w = table.deepcopy(data.raw.corpse["defender-remnants"])
  w.name = "lp-scavenger-wreck"
  data:extend({b, w})
end

-- Laser drone (Kessler-Hayashi's garrisons, in the harrier's place: army.lua): the destroyer's body in its colours,
-- armoured against small arms, a laser beam of about 12 every 20 ticks, range 16. Its sky is few and dear.
local laser_drone = table.deepcopy(harrier)
laser_drone.name = "lp-laser-drone"
laser_drone.max_health = shared.units["lp-laser-drone"].health
laser_drone.movement_speed = 0.2
laser_drone.run_animation = flying("destroyer")
laser_drone.attack_parameters = {type = "beam", ammo_category = "laser", cooldown = 20, range = 16,
  range_mode = "bounding-box-to-bounding-box", damage_modifier = 1.2, animation = flying("destroyer"),
  ammo_type = {action = {type = "direct", action_delivery = {type = "beam", beam = "laser-beam", max_length = 17,
    duration = 20, source_offset = {0, -1}}}}}
laser_drone.dying_explosion = "destroyer-robot-explosion"
laser_drone.corpse = "destroyer-remnants"
laser_drone.resistances = {{type = "fire", percent = 100}, {type = "physical", decrease = 3, percent = 40},
  {type = "laser", percent = 20}}
tint(laser_drone.run_animation, {})
tint(laser_drone.attack_parameters.animation, {})

-- Railgunner (Serenity; the user: "a biter clearing unit like a hand mounted railgun that's at its best against biters"):
-- a slug out of a medium worm's reach that pierces a few biters (RAIL_PIERCE below), heavy against what carries the
-- lp-biter trigger target (biters, spawners, worms: data-final-fixes.lua), light against anything else, every 90 ticks;
-- laser, so Serenity's research covers it. Its numbers are below and in shared.lua, not here.
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
-- Its slug pierces what it hits until RAIL_PIERCE is spent on their health (vanilla's own rule for a piercing shell):
-- about four medium biters, and a big one stops it. It was a line through everything in 30 tiles, which made a Kessler-
-- Hayashi camp with railgunners in it proof against any wave (the user, 2026-10-25: "makes KH bases virtually impregnable
-- to biters"; the arena: +1.00 against every breed of Synthexis's but the stomper): a nest stands still and dies the
-- same, a packed wave no longer dies row by row.
local RAIL_PIERCE = 300
local RAIL_UNIT = 40          -- to a biter on its feet; RAIL_NEST to what grows them (spawners, worms, incubators, tumors);
                              -- its railguns research (+60% a level, five, as the player's era allows) takes both up (the
                              -- user, 2026-10-25: "an investment for Kessler if they feel they need more clearance/biter
                              -- defense, and weaker at baseline"). The arena at 40: beats small and medium biters and
                              -- spitters, loses to big biters (-0.71), behemoths and biters at 0.95; at 60 it beat bigs
local RAIL_NEST = 250
-- (A small area at the hit, not "direct": a direct trigger's target mask did not keep the 250 to biters, and the slug
-- did 260 to tanks and turrets: seven tanks dead in six seconds in the arena.)
local function rail_hit(amount, mask)
  return {type = "area", radius = 0.5, force = "enemy", trigger_target_mask = mask, action_delivery = {type = "instant",
    target_effects = {{type = "damage", damage = {amount = amount, type = "physical"}}, {type = "create-entity", entity_name = "explosion-hit"}}}}
end
local rail_slug = table.deepcopy(data.raw.projectile["cannon-projectile"])
rail_slug.name = "lp-railgunner-slug"
rail_slug.piercing_damage = RAIL_PIERCE
rail_slug.force_condition = "enemy"
rail_slug.direction_only = true
-- Hit at the target's own position: at the edge of its box, a big biter's middle lay outside the 0.5 area, and four
-- railgunners left 15 of 16 big biters standing.
rail_slug.hit_at_collision_position = false
rail_slug.action = {rail_hit(RAIL_NEST, {"lp-nest"}), rail_hit(RAIL_UNIT, {"lp-biter"}), rail_hit(10, {"common"})}
rail_slug.final_action = nil
rail_slug.animation, rail_slug.shadow, rail_slug.smoke = nil, nil, nil
data:extend({rail_slug})

railgunner.attack_parameters = {
  -- Its own ammunition category (lp-rail, the player's rail rifle's too: force modifiers are a force's own): its
  -- research is Kessler-Hayashi's railguns track, bought when biters kill its units (shared.CORPS.serenity.tree).
  type = "projectile", ammo_category = "lp-rail", cooldown = 90, cooldown_deviation = 0.1, range = 30,
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
    {type = "direct", action_delivery = {type = "projectile", projectile = "lp-railgunner-slug", starting_speed = 2,
      max_range = 30}},
  }},
}
railgunner.resistances = table.deepcopy(infantry.resistances)

data:extend({{type = "damage-type", name = "lp-rail"}})
-- The Heavy tank's rail cannon (lp-aegis, Kessler-Hayashi's Line; the user, 2026-10-24: "Kessler has basically two types
-- of laser tanks. Seems redundant?"). Its job in the arena was always armour (it beat tanks and the Laser tank, lost to
-- swarms), but its heavy laser beam made it read as the Laser tank's twin. Now a rail cannon: one heavy kinetic slug,
-- 38 every 60 ticks at 16 (at 45 it beat rocket troopers +58; at 30 it lost to the battle tank -67, which it is
-- for), drawn with the railgunner's beam; single, not piercing (a line would cut through rows of
-- infantry: the Laser tank's work). Its damage its own type, lp-rail, that no armour resists: hulls are built against
-- physical and explosion, so a slug hard enough to hurt a tank wrecked everything soft (150 physical: it beat all but
-- fliers; 80 every 80: still rocket troopers +58 and lances +75, the arena, 2026-10-24). Light on everything, full on
-- a hull: the anti-armour gun, and rocket troopers and lances answer it from 18 and 17.
-- Ammunition category cannon-shell (0.2.479; laser until then): Kessler-Hayashi's Ordnance track scales it, damage and
-- shooting speed as the battle tank's research does. On laser it took Optics' damage alone (0.2.476: lasers take no
-- speed), and at the top of both sides' research the battle tank beat it in every round (the late arena, +1.00).
-- On cannon-shell, +0.78 there; a slug of 46 (tried, 2026-11-21) left that at +0.89 and won it 24 of its 37 plain
-- matchups (16 at 38), the trooper's among them: late, the battle tank's lead is its explosive uranium shells.
aegis.attack_parameters = {
  -- Range 16: rocket troopers (18) and lances (17) answer it from beyond its reach (at 20 it outranged both, +75 on each).
  type = "projectile", ammo_category = "cannon-shell", cooldown = 60, cooldown_deviation = 0.1, range = 16,
  range_mode = "bounding-box-to-bounding-box",
  sound = table.deepcopy((data.raw.gun["railgun"] or data.raw.gun["tank-cannon"]).attack_parameters.sound),
  animation = table.deepcopy(aegis.attack_parameters.animation),
  -- Its round a big shell in flight (the user, 2026-11-09: "the heavy tank has quite underwhelming FX... can we not
  -- give it big shells instead of the puny red laser?"): the explosive cannon shell's, drawn twice the size, warmer,
  -- a light round it, a muzzle flash, a medium explosion where it lands, to its target only. Its 38 of lp-rail as before.
  ammo_type = {action = {type = "direct", action_delivery = {type = "projectile", projectile = "lp-aegis-shell",
    starting_speed = 0.9, max_range = 30, source_effects = {{type = "create-explosion", entity_name = "explosion-gunshot"}}}}},
}
do
  local sh = table.deepcopy(data.raw.projectile["explosive-cannon-projectile"])
  sh.name = "lp-aegis-shell"
  sh.direction_only, sh.piercing_damage = false, 0
  -- To its target only, as the tank's shell (shell above): the explosive shell's collision stopped it on whatever stood in
  -- its way, the tank ahead in a column, and most never showed (the user: "1 every 10 shots or so? ... the shots from
  -- every tank behind the first one is stopped by a tank in front").
  sh.collision_box = nil
  sh.hit_collision_mask = {layers = {}}
  sh.force_condition = "not-same"
  sh.action = {type = "direct", action_delivery = {type = "instant", target_effects = {
    {type = "damage", damage = {amount = 38, type = "lp-rail"}}, {type = "create-entity", entity_name = "medium-explosion"}}}}
  sh.final_action = nil
  sh.animation = {filename = "__base__/graphics/entity/bullet/bullet.png", draw_as_glow = true, width = 3, height = 50,
    priority = "high", scale = 3, tint = {r = 1, g = 0.8, b = 0.45, a = 1}}
  sh.smoke = {{name = "smoke-fast", deviation = {0.15, 0.15}, frequency = 1, position = {0, 0}, starting_frame = 3,
    starting_frame_deviation = 5}}
  sh.light = {intensity = 0.6, size = 5, color = {r = 1, g = 0.7, b = 0.35}}
  data:extend({sh})
end

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
local prism_split = beam_copy("laser-beam", "lp-prism-split", {r = 0.35, g = 0.75, b = 1, a = 1}, 10, "laser")
-- The beam's own cyan images (scripts/kh_glow.py): a tint over the red beam read red on film (the user, 2026-11-08:
-- "Prism bounced lasers are red"), and a violet split beside a cyan beam read as another weapon ("why is the bounced
-- laser not simply the same color as the original?").
do
  local seen = {}
  local function repoint(t)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    if type(t.filename) == "string" and t.filename:find("__base__/graphics/entity/laser-turret/", 1, true) then
      t.filename = t.filename:gsub("__base__/graphics/entity/laser%-turret/", "__landing-party__/graphics/serenity/laser-turret/")
      t.tint = nil
    end
    for _, v in pairs(t) do repoint(v) end
  end
  repoint(prism_split.graphics_set)
end
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
-- accumulator, a roboport) loses most of it, and a laser or tesla turret it strikes stops for the game's tesla stun
-- (scripts/scorcher.lua, on_entity_damaged).
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
local sca = suppressing(gun(6, 13, 10))
sca.animation = table.deepcopy(scorcher.run_animation)
scorcher.attack_parameters = sca
scorcher.resistances = {{type = "physical", decrease = 3, percent = 25}, {type = "fire", percent = 100},
  {type = "explosion", decrease = 5, percent = 30}, {type = "laser", decrease = 5}, {type = "electric", decrease = 5}}
-- Its flame its own (scripts/scorcher.lua fires it): the flamethrower's stream with a burn of its own, BURN_TICKS at
-- BURN every 10 ticks, not vanilla's fire sticker, 30 s at 16.7 every 10 ticks (made for the player's flamethrower on
-- biters): one burst set a group of tanks burning half a minute, 35 a second through their armour, and Scorchers beat
-- tanks at equal spend in every round (the arena, 2026-11-09). Still enough for packed infantry; a sting on a hull.
do
  local BURN_TICKS, BURN = 240, 8
  local st = table.deepcopy(data.raw.sticker["fire-sticker"])
  st.name, st.duration_in_ticks = "lp-scorch-sticker", BURN_TICKS
  st.damage_per_tick = {amount = BURN, type = "fire"}
  st.hidden = true
  local stream = table.deepcopy(data.raw.stream["flamethrower-fire-stream"])
  stream.name = "lp-scorcher-stream"
  local function repoint(t, seen)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    if t.type == "create-sticker" and t.sticker == "fire-sticker" then t.sticker = st.name end
    for _, v in pairs(t) do repoint(v, seen) end
  end
  repoint(stream.action, {})
  data:extend({st, stream})
end
-- Its fuel goes up when it dies (the user, 2026-11-09: "flamer units ... could explode a little more forcefully on death
-- and leave a pool of fire, to reflect the fuel tanks"; then "the flame pool from scorcher explosions could be more
-- dramatic"): the game's massive explosion, BLAST explosive within BLAST_R (its own escort too), and its fuel burning
-- round its wreck, a fire of its own (lp-fuel-fire: FUEL_TICKS, spreading a little) at its middle and FIRES more out to
-- FIRE_R. (The first: a big explosion, the ground fire's few seconds, six within 2.5.) Kill it at range.
do
  local BLAST, BLAST_R, FIRES, FIRE_R, FUEL_TICKS = 60, 4, 12, 4, 20 * 60
  local f = table.deepcopy(data.raw.fire["fire-flame"])
  f.name = "lp-fuel-fire"
  f.initial_lifetime, f.maximum_lifetime = FUEL_TICKS, FUEL_TICKS + 300
  f.maximum_spread_count = 8
  f.burnt_patch_lifetime = FUEL_TICKS + 1800
  f.emissions_per_second = nil
  f.hidden = true
  data:extend({f})
  scorcher.dying_explosion = "massive-explosion"
  -- (The fires set down by a cluster, as a cluster grenade's: given offsets, the twelve merged into the one at the wreck,
  -- unitnode counting 1, the user: "it's just so small and doesn't spread around the wreck".)
  local effects = {{type = "create-fire", entity_name = "lp-fuel-fire", initial_ground_flame_count = 8},
    {type = "nested-result", action = {type = "cluster", cluster_count = FIRES, distance = FIRE_R * 0.6,
      distance_deviation = FIRE_R * 0.8, action_delivery = {type = "instant", target_effects = {
        {type = "create-fire", entity_name = "lp-fuel-fire", initial_ground_flame_count = 3}}}}}}
  effects[#effects + 1] = {type = "nested-result", action = {type = "area", radius = BLAST_R,
    action_delivery = {type = "instant", target_effects = {{type = "damage", damage = {amount = BLAST, type = "explosion"}}}}}}
  scorcher.dying_trigger_effect = effects
end
-- Kessler-Hayashi's hulls resist fire as its tank does: the Prism, the Tesla and the Aegis had armour of their own with
-- no fire in it, and the Scorcher's burn took them whole (the user, 2026-11-09: "5 heavy tanks still lost to 5
-- scorchers"; "some fire resistance for all vehicles that deserve it?"). Grubstake's buggies stay soft.
for _, u in ipairs({prism, tesla, aegis}) do
  local has = false
  for _, r in ipairs(u.resistances or {}) do if r.type == "fire" then has = true end end
  if not has then
    u.resistances = u.resistances or {}
    table.insert(u.resistances, {type = "fire", decrease = 2, percent = 60})
  end
end
data:extend({prism, prism_split, prism_chain, tesla, tesla_jump, tesla_chain, scorcher})

-- The lightning's stun (scripts/stun.lua): a glow over the unit while it lasts, Space Age's lightning strike's hit, its
-- arcing frames alone (13 to 24 of 36, there and back: the whole of it at 0.3 was a pixel-thin line on film, its first and
-- last frames near empty), at 0.45 over infantry, 0.9 over a hull. And arcs of current over it (stun.lua): the electric
-- beam in the Tesla's cyan, doing nothing. Movement and speed untouched: the script switches the unit off.
local util = require("util")
local arc_seq = {}
for i = 13, 24 do arc_seq[#arc_seq + 1] = i end
for i = 23, 14, -1 do arc_seq[#arc_seq + 1] = i end
data:extend({beam_copy("electric-beam-no-sound", shared.STUN.arc, {r = 0.7, g = 0.85, b = 1, a = 1})})
for _, fx in ipairs({{shared.STUN.fx, 0.45}, {shared.STUN.fx_big, 0.9}}) do
  data:extend({{type = "sticker", name = fx[1], flags = {"not-on-map"}, hidden = true,
    duration_in_ticks = shared.STUN.TICKS, target_movement_modifier = 1, vehicle_speed_modifier = 1,
    render_layer = "air-object", single_particle = true,
    animation = util.sprite_load("__space-age__/graphics/entity/lightning/lightning-attractor-hit-anim", {
      draw_as_glow = true, blend_mode = "additive", scale = fx[2], frame_count = 36, frame_sequence = arc_seq,
      animation_speed = 0.5, tint = {r = 0.75, g = 0.9, b = 1, a = 1}})}})
end

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
truck.loot = {{type = "item", name = "steel-plate", independent_probability = 0.5, amount_min = 8, amount_max = 8}}
data:extend({truck})

-- Synthexis's technician (the identity consult, step 4; scripts/cell.lua): a plain suit in white and green, unarmed (a
-- shove of 1 for the engine's sake; its walks are ordered undistracted), walking fruit from the substrate to the
-- biochambers. Not a corporation's unit (no parts, no arena row).
local technician = make_infantry("lp-technician", {r = 0.85, g = 1, b = 0.8, a = 1})
technician.max_health = 80
technician.movement_speed = 0.1
technician.attack_parameters = gun(1, 1, 60, "melee")
technician.attack_parameters.sound = nil
technician.attack_parameters.animation = table.deepcopy(technician.run_animation)
technician.map_color = shared.BIOTECH.color
technician.enemy_map_color = shared.BIOTECH.color
data:extend({technician})

-- Anti-air, one per side (the user, 2026-10-23: "Not super comfortable about the flier units"; the arena had air beating
-- splash and every breed by 100 and armour by 67, small arms its only answer). Each hits a flier hard and the ground
-- lightly (the user: "kinda attack ground units also ... flak could be a sort of weak ground splash"): a masked area at the target (an area honours trigger_target_mask, a direct hit does not: air.lua), so it is a
-- counter, not a better rifle. Each outranges the fliers' 15.
-- A flak puff: the fast smoke's burst, tinted near black, at a flier's height, held a beat (a trivial smoke in its place,
-- the third takes, read as faint grey wisps if at all).
data:extend({{type = "explosion", name = "lp-flak-puff", flags = {"not-on-map"}, hidden = true, render_layer = "air-object",
  animations = {{filename = "__base__/graphics/entity/smoke-fast/smoke-fast.png", priority = "high", width = 50, height = 50,
    frame_count = 16, animation_speed = 0.2, scale = 1.5, shift = {0, -1.2}, tint = {r = 0.07, g = 0.065, b = 0.06, a = 0.95}}}}})
local function anti_air(air, ground, dtype, radius, look, ground_radius, puffs)
  local function hit(amount, mask, r)
    return {type = "nested-result", action = {type = "area", radius = r, force = "enemy", trigger_target_mask = mask,
      action_delivery = {type = "instant", target_effects = {{type = "damage", damage = {amount = amount, type = dtype}}}}}}
  end
  local fx = {hit(air, {"lp-air-unit"}, radius), hit(ground, {"common"}, ground_radius or 0.5)}
  if look then table.insert(fx, 1, {type = "create-entity", entity_name = look}) end
  local delivery = {type = "instant", target_effects = fx}
  if puffs then
    -- The gun's flash at its muzzle (the user, 2026-11-09: "muzzle flash rarely show from the flak buggies": it had none).
    delivery.source_effects = {{type = "create-explosion", entity_name = "explosion-gunshot"}}
    -- Black puffs round the burst, at a flier's height (the user, on the flak scene: "underwhelming. Perhaps we add
    -- black puffs of smoke jittered around spots the flak fires on?").
    table.insert(fx, 1, {type = "create-entity", entity_name = "lp-flak-puff", repeat_count = 3,
      offset_deviation = {{-1.6, -1.2}, {1.6, 1.2}}})
  end
  return {type = "direct", action_delivery = delivery}
end
-- Anti-air trooper (lp-skyguard; Kessler-Hayashi's Line): a Laser trooper's body with a long tracking laser, 30 to a flier and 8 to the ground
-- every 30 ticks, range 22. Bought when fliers kill its units (shared.CORPS tree).
data:extend({{type = "ammo-category", name = "lp-anti-air", hidden = true}})
local skyguard = make_infantry("lp-skyguard", {r = 0.85, g = 0.9, b = 1, a = 1}, "mech-armor")
skyguard.max_health = shared.units["lp-skyguard"].health
skyguard.attack_parameters = {
  -- (Its own category, raised by no research, 0.2.476: on lasers its weak ground hit from range 22 took the arms race's
  -- x10.6, and at the top of both sides' research it beat all six of the player's units.)
  type = "projectile", ammo_category = "lp-anti-air", cooldown = 30, range = 22, range_mode = "bounding-box-to-bounding-box",
  sound = table.deepcopy(data.raw["electric-turret"]["laser-turret"].attack_parameters.sound),
  animation = table.deepcopy(infantry.attack_parameters.animation),
  ammo_type = {action = {
    {type = "direct", action_delivery = {type = "beam", beam = "lp-rail-beam", max_length = 23, duration = 6, source_offset = {0, -1}}},
    anti_air(30, 8, "laser", 1),
  }},
}
skyguard.resistances = table.deepcopy(infantry.resistances)
-- Flak buggy (Grubstake's Wheels): the buggy's hull with the car's gun turret, scrap flak bursting over 2 tiles, 22 to
-- fliers and 3 over 1.5 tiles to the ground (a weak ground splash; 6 over 2 beat every infantry by 75 to 95) every 30 ticks, range 22; bullets, so its Hand-loads cover it.
local flak_buggy = table.deepcopy(buggy)
flak_buggy.name = "lp-flak-buggy"
flak_buggy.max_health = shared.units["lp-flak-buggy"].health
flak_buggy.run_animation = crowned(car.animation, {{car.turret_animation}})
tint(flak_buggy.run_animation, {})
flak_buggy.attack_parameters = {
  type = "projectile", ammo_category = "bullet", cooldown = 30, range = 22, range_mode = "bounding-box-to-bounding-box",
  projectile_center = {0, -0.7}, projectile_creation_distance = 0.9,
  sound = table.deepcopy(data.raw.gun["submachine-gun"].attack_parameters.sound),
  animation = table.deepcopy(flak_buggy.run_animation),
  ammo_type = {action = anti_air(22, 3, "explosion", 2, "explosion", 1.5, true)},
}
data:extend({skyguard, flak_buggy})

-- Loot (the faction loot consult): a unit drops a little of its own kit, half the time. The player's units (trooper,
-- breacher, rocket trooper, battle tank) drop nothing: they are the player's. The bomb drone neither: it dies in every
-- blow (a drop a hit).
-- Grubstake's vehicles told apart from afar (the user, 2026-10-23: "Grubstake buggies also very much all look alike
-- from afar"): by outline first, then colour. The buggies now by their weapon modules (rendered_buggy below: a short gun,
-- a long barrel and a shell rack, twin raised barrels and a radar mast) and their accents (the slug's rust shield, the
-- flak's sky blue: anti-air; olive was lost on grass); the dozer and the Scorcher on the crawler (rendered_crawler).
-- Grubstake's buggies, rendered in Blender (tools/blender/buggy.py, sheet.py; the unit pass, 2026-11-08): one scrap desert
-- buggy for a chassis (a tube frame nose to tail, its cage painted amber, the engine hung at the back), and on its turret
-- ring a weapon module with its kit, a layer of its own: the machine gun and ammo cans (buggy), the slug gun, its shell
-- rack and ram plate (slug buggy), the twin flak and its drums and ranging radar (flak buggy). A unit has one picture a
-- direction, so the weapon faces where the hull does: 64 directions, one frame each. The module's sheet carries the
-- shadow of both. Frame sizes and shifts from each sheet.json. Only Grubstake fields them, so the kinds' own copies
-- draw them too.
local SHEETS = require("graphics.sheets")
-- A unit drawn from rendered layers (tools/blender: buggy.py, crawler.py): parts, bottom first, each {sheet, files}, under
-- graphics/<root>/<sheet>. One frame a direction, or an animated part's few (the buggy's antenna, the crawler's tracks):
-- the single-frame layers repeat to match. The direction count from the first part's sheet.
local function layered(u, root, parts)
  local DIRS = SHEETS[root .. "/" .. parts[1][1]].frames
  local most = 1
  for _, p in ipairs(parts) do most = math.max(most, SHEETS[root .. "/" .. p[1]].frames / DIRS) end
  local all = {}
  for _, p in ipairs(parts) do
    local B = SHEETS[root .. "/" .. p[1]]
    local fc = B.frames / DIRS
    for _, f in ipairs(p[2]) do
      local dir = "__landing-party__/graphics/" .. root .. "/" .. p[1] .. "/"
      local l = {width = B.width, height = B.height, direction_count = DIRS, frame_count = fc, repeat_count = most / fc,
        line_length = B.line_length, scale = 0.5, shift = B.shift}
      if B.files then                                  -- a tall sheet on several files (sheet.py)
        l.filenames, l.lines_per_file = {}, B.lines_per_file
        for k = 1, B.files do l.filenames[k] = dir .. f .. "-" .. k .. ".png" end
      else
        l.filename = dir .. f .. ".png"
      end
      if f == "glow" then l.draw_as_glow = true; l.blend_mode = "additive" end
      if f == "shadow" then l.draw_as_shadow = true end
      all[#all + 1] = l
    end
  end
  u.run_animation = {layers = all}
  u.attack_parameters.animation = table.deepcopy(u.run_animation)
end
-- The buggies: the module's shadow, the chassis, the module, the antenna (the user, 2026-11-08: "An antenna in the back?
-- ... animate it while moving?": its own layer of frames a direction; a run animation steps with the distance a unit
-- covers and holds when it stops, so the whip sways driving and stands parked).
-- Headlights at night (the unit pass, 2026-11-08): the car's two cones. Assumed, not seen: no vanilla unit carries a
-- light, so whether an oriented one turns with a unit is to be looked at in game (LP_MIX=buggies, at night).
local function headlights(u, ahead)
  u.light = table.deepcopy(data.raw.car.car.light)
  for _, l in ipairs(u.light) do l.shift = {l.shift[1], -(ahead or 14)} end
end
-- Wrecks (the unit pass, 2026-11-08: they left the car's and the tank's): each rendered unit's own corpse, charred,
-- slumped, a share of its parts thrown round it and a scorch under it, 4 directions as vanilla's remnants, its shadow
-- in the picture. The dying unit's direction picks the nearest of the four.
local function wreck(name, sheet)
  local W = SHEETS[sheet]
  local c = table.deepcopy(data.raw.corpse["car-remnants"])
  c.name = name
  c.animation = {filename = "__landing-party__/graphics/" .. sheet .. "/body.png", width = W.width, height = W.height,
    direction_count = W.frames, line_length = W.line_length, scale = 0.5, shift = W.shift}
  c.localised_name = nil
  data:extend({c})
  return name
end
local BUGGY_WRECK = wreck("lp-buggy-wreck", "grubstake/buggy/wreck")
local function rendered_buggy(u, module)
  -- Its wheels a layer of their own, 4 frames a direction, one turn over them: they roll driving, stand parked (no unit
  -- steers; the user asked, 2026-11-08, "Do wheels turn when turning?").
  layered(u, "grubstake/buggy", {{module, {"shadow"}}, {"chassis", {"body", "glow"}}, {"wheels", {"body"}},
    {module, {"body", "glow"}}, {"antenna", {"body"}}})
  headlights(u)
  -- It is longer than the car it replaced (2.3 tiles to 2): its selection box follows the sprite.
  u.selection_box = {{-0.8, -1.25}, {0.8, 1.25}}
  u.corpse = BUGGY_WRECK
end
rendered_buggy(buggy, "mg")
rendered_buggy(slug, "slug")
rendered_buggy(flak_buggy, "flak")
-- The crawler (tools/blender/crawler.py; the unit pass, 2026-11-08: Grubstake's tracked units on one bulldozer chassis,
-- "The kill dozer is a genius pull", "Mad Max as a general inspiration"): the module's shadow, the chassis with its
-- engine in the open, the tracks (4 frames a direction: they run driving, stand parked), the module. The dozer a
-- Killdozer (an armoured cab, the blade, the ripper), the Scorcher a beaked fighting compartment with its flamer, its
-- machine gun and three fuel tanks.
local function rendered_crawler(u, module)
  layered(u, "grubstake/crawler", {{module, {"shadow"}}, {"base", {"body", "glow"}}, {"anim", {"body"}}, {module, {"body", "glow"}}})
  headlights(u)
end
rendered_crawler(dozer, "dozer")
dozer.corpse = wreck("lp-dozer-wreck", "grubstake/crawler/wreck-dozer")
dozer.selection_box = {{-1.1, -1.5}, {1.1, 1.8}}
rendered_crawler(scorcher, "scorcher")
scorcher.corpse = wreck("lp-scorcher-wreck", "grubstake/crawler/wreck-scorcher")
scorcher.selection_box = {{-1.1, -1.4}, {1.1, 1.4}}
-- Kessler-Hayashi's tank (tools/blender/kh_tank.py; the unit pass, 2026-11-08): its own hull, slate teal and graphite,
-- maintained, the cannon head on it, the tracks running driving. Grubstake fields tanks too (its sprawl doctrine), so its
-- copy keeps the old look through its props until a tank of its own. (The player's battle tank keeps vanilla's.)
do
  local c = shared.CORPS.grubstake
  c.props = c.props or {}
  c.props["lp-tank"] = {run_animation = table.deepcopy(tank.run_animation), attack_parameters = table.deepcopy(tank.attack_parameters),
    corpse = tank.corpse}
  layered(tank, "serenity/tank", {{"cannon", {"shadow"}}, {"base", {"body", "glow"}}, {"anim", {"body"}}, {"cannon", {"body", "glow"}}})
  headlights(tank)
  -- Its wrecks (the user, 2026-11-08: "We didn't do KH wrecks also"), the head each carried on the hull: power gone, so
  -- no glow, the Prism's crystals shattered.
  tank.corpse = wreck("lp-kh-tank-wreck", "serenity/tank/wreck-cannon")
  -- The Prism on the same hull: no turret, a finned pylon carrying violet crystals (after the genre's prism tank: the
  -- user, "To avoid having such similar designs"). Grubstake's copy keeps its old look as the tank's does.
  c.props["lp-prism"] = {run_animation = table.deepcopy(prism.run_animation), attack_parameters = table.deepcopy(prism.attack_parameters),
    corpse = prism.corpse}
  layered(prism, "serenity/tank", {{"prism", {"shadow"}}, {"base", {"body", "glow"}}, {"anim", {"body"}}, {"prism", {"body", "glow"}}})
  headlights(prism)
  prism.corpse = wreck("lp-prism-wreck", "serenity/tank/wreck-prism")
end
-- The Tesla and the Aegis on the same hull, after the genre's tesla tank (twin coils, crowned) and its heavy tank (twin
-- rail guns, the user's "doubling the cannon"); Grubstake's copies keep theirs as the tank's do. Each wired once its
-- sheet is in sheets.lua.
for _, pair in ipairs({{tesla, "tesla"}, {aegis, "aegis"}}) do
  local u, head = pair[1], pair[2]
  if SHEETS["serenity/tank/" .. head] then
    local c = shared.CORPS.grubstake
    c.props = c.props or {}
    c.props[u.name] = {run_animation = table.deepcopy(u.run_animation), attack_parameters = table.deepcopy(u.attack_parameters),
      corpse = u.corpse}
    layered(u, "serenity/tank", {{head, {"shadow"}}, {"base", {"body", "glow"}}, {"anim", {"body"}}, {head, {"body", "glow"}}})
    headlights(u)
    if SHEETS["serenity/tank/wreck-" .. head] then u.corpse = wreck("lp-" .. head .. "-wreck", "serenity/tank/wreck-" .. head) end
  end
end
-- Kinds both corporations field get Grubstake's rendered look on Grubstake's copy alone, through its props in
-- shared.CORPS (corps.lua applies them to the copy it makes, plates.lua copies that); Kessler-Hayashi's keeps the
-- old look until it has its own.
local function grubstake_look(u, root, parts, extra)
  local g = {attack_parameters = table.deepcopy(u.attack_parameters)}
  layered(g, root, parts)
  local c = shared.CORPS.grubstake
  c.props = c.props or {}
  local p = {run_animation = g.run_animation, attack_parameters = g.attack_parameters}
  for k, v in pairs(extra or {}) do p[k] = v end
  c.props[u.name] = p
  return p
end
-- The hauler (tools/blender/hauler.py): a six-wheeled scrap bonnet truck, its hood amber, a tarped load on its bed.
do
  -- Its wheels a layer of 4 frames a direction (vehicle.rolling): they roll driving, stand parked.
  local p = grubstake_look(hauler, "grubstake/hauler", {{"bed", {"shadow"}}, {"base", {"body", "glow"}}, {"anim", {"body"}},
    {"bed", {"body", "glow"}}},
    {selection_box = {{-0.85, -1.45}, {0.85, 1.55}}, corpse = wreck("lp-hauler-wreck", "grubstake/hauler/wreck")})
  headlights(p, 16)
end
-- Kessler-Hayashi's hauler (the user, 2026-11-16: "a tank chassis with no turret, like an APC"): its tank's hull and
-- tracks, a sealed armoured casemate on the deck with roof hatches, a teal convoy beacon (tools/blender/kh_tank.py's
-- carrier, A of four clay candidates). The generic first truck until now, its manual portrait read as Grubstake's.
-- Grubstake's keeps its own (above, through its props).
if SHEETS["serenity/tank/carrier"] then
  layered(hauler, "serenity/tank", {{"carrier", {"shadow"}}, {"base", {"body", "glow"}}, {"anim", {"body"}}, {"carrier", {"body", "glow"}}})
  headlights(hauler)
  -- (Selected as the hull it now wears, the tank's; its collision kept, its convoys formed and pathed at that size.)
  hauler.selection_box = table.deepcopy(tank.selection_box)
  if SHEETS["serenity/tank/wreck-carrier"] then hauler.corpse = wreck("lp-kh-hauler-wreck", "serenity/tank/wreck-carrier") end
end
-- The howitzer truck (Grubstake's alone; tools/blender/hauler.py LP_LOAD=howitzer): the hauler's chassis carrying the
-- deployed howitzer's own housing and barrel (kh_guns.py's, read from there), its barrel down in a travel lock over the
-- cab, so the truck and the gun it becomes in a siege (siege.lua) are one machine (the user: "careful that it coheres
-- with the deployed howitzer"). Wired once its sheet is in sheets.lua.
if SHEETS["grubstake/hauler/howitzer"] then
  grubstake_look(truck, "grubstake/hauler", {{"howitzer", {"shadow"}}, {"base", {"body", "glow"}}, {"anim", {"body"}},
    {"howitzer", {"body", "glow"}}}, {selection_box = {{-0.85, -1.45}, {0.85, 1.55}}, corpse = "lp-hauler-wreck"})
  -- (Its collision box stays the tank's it had: how it paths and where a siege sets it down are not the look's to change.)
end
-- The harrier (tools/blender/harrier.py): a scrap autogyro, a pilot and a gunner, its rotor and pusher prop discs of
-- motion blur (a run animation holds when a unit stops: a modelled rotor would freeze while it hovers). And the bomb
-- drone (tools/blender/scavenger.py): a scrap quadcopter with its bomb slung under it, a red gas cylinder.
grubstake_look(harrier, "grubstake/harrier", {{"rotor", {"shadow"}}, {"base", {"body", "glow"}}, {"rotor", {"body"}}},
  {corpse = wreck("lp-harrier-wreck", "grubstake/harrier/wreck")})
-- Kessler-Hayashi's fliers (tools/blender/kh_drone.py): ducted-fan drones in teal and graphite, a soft blue glow in
-- their ducts (the user, 2026-10-23: "give Kessler the actual high tech fliers"): its scout drone on the harrier kind
-- (Grubstake's harrier has its autogyro through its props, set above), its laser drone; Grubstake's laser drone copy
-- keeps the old look. Each wired once its sheet is in sheets.lua.
if SHEETS["serenity/drone-scout/base"] then
  layered(harrier, "serenity/drone-scout", {{"fans", {"shadow"}}, {"base", {"body", "glow"}}, {"fans", {"body"}}})
  harrier.corpse = wreck("lp-kh-drone-wreck", "serenity/drone-scout/wreck")
end
if SHEETS["serenity/drone-laser/base"] then
  local c = shared.CORPS.grubstake
  c.props["lp-laser-drone"] = {run_animation = table.deepcopy(laser_drone.run_animation),
    attack_parameters = table.deepcopy(laser_drone.attack_parameters), corpse = laser_drone.corpse}
  layered(laser_drone, "serenity/drone-laser", {{"fans", {"shadow"}}, {"base", {"body", "glow"}}, {"fans", {"body"}}})
  laser_drone.corpse = wreck("lp-laser-drone-wreck", "serenity/drone-laser/wreck")
end
-- Kessler-Hayashi's constructor drone (crew.lua's drone body): the scout drone's airframe and look, passing through other
-- fliers. A site's crew hover over it together, and colliding they jammed: 4 of 50 crews stuck in scenario cordon, once
-- fliers collided (0.2.240). Combat fliers keep colliding.
do
  local c = table.deepcopy(harrier)
  c.name = "lp-constructor"
  c.collision_mask = {layers = {["lp-air"] = true}, not_colliding_with_itself = true}
  c.localised_name = {"entity-name.lp-constructor"}
  data:extend({c})
end
-- Their fall (scripts/fall.lua, shared.FALL): each kind's body, glow and rotor at heading 0 as one sprite, the body's middle
-- at the sprite's (the flier's height comes from the script), and its shadow apart; a small crash where it lands, 20
-- explosive within 1.5.
for _, k in pairs(shared.FALL.kinds) do
  local B, R = SHEETS[k.sheet .. "/base"], SHEETS[k.sheet .. "/" .. k.rotor]
  if B and R then
    local function layer(sheet, S, file, rel, extra)
      local l = {filename = "__landing-party__/graphics/" .. k.sheet .. "/" .. sheet .. "/" .. file .. ".png", width = S.width,
        height = S.height, x = 0, y = 0, scale = 0.5, shift = rel}
      for a, v in pairs(extra or {}) do l[a] = v end
      return l
    end
    local rel = {R.shift[1] - B.shift[1], R.shift[2] - B.shift[2]}
    data:extend({
      {type = "sprite", name = k.sprite, layers = {layer("base", B, "body", {0, 0}),
        layer("base", B, "glow", {0, 0}, {draw_as_glow = true, blend_mode = "additive"}), layer(k.rotor, R, "body", rel)}},
      {type = "sprite", name = k.sprite .. "-shadow", layers = {layer(k.rotor, R, "shadow", {0, 0}, {draw_as_shadow = true})}},
    })
  end
end
do
  local c = table.deepcopy(data.raw.explosion["medium-explosion"])
  c.name = shared.FALL.crash
  c.created_effect = {type = "direct", action_delivery = {type = "instant", target_effects = {{type = "nested-result",
    action = {type = "area", radius = 1.5, action_delivery = {type = "instant", target_effects = {
      {type = "damage", damage = {amount = 20, type = "explosion"}}}}}}}}}
  data:extend({c})
end
-- (It bursts on its target: its corpse stays the defender's small remnants.)
grubstake_look(scavenger, "grubstake/scavenger", {{"rotor", {"shadow"}}, {"base", {"body", "glow"}}, {"rotor", {"body"}}},
  {corpse = "lp-scavenger-wreck"})

local UNIT_LOOT = {[infantry] = {{"electronic-circuit", 1, 1}}, [shotgun_hand] = {{"shotgun-shell", 1, 3}},
  [buggy] = {{"engine-unit", 1, 1}}, [harrier] = {{"iron-gear-wheel", 1, 2}}, [laser_drone] = {{"advanced-circuit", 1, 1}}, [tank] = {{"steel-plate", 4, 4}, {"engine-unit", 1, 1}},
  [walker] = {{"steel-plate", 8, 8}, {"advanced-circuit", 2, 2}}, [hauler] = {{"steel-plate", 8, 8}},
  [lance] = {{"electronic-circuit", 2, 2}}, [slug] = {{"piercing-shotgun-shell", 2, 4}}, [shock] = {{"battery", 1, 1}},
  [sapper] = {{"explosives", 1, 2}}, [aegis] = {{"steel-plate", 4, 4}}, [dozer] = {{"steel-plate", 6, 6}, {"engine-unit", 1, 1}},
  [railgunner] = {{"steel-plate", 2, 2}, {"advanced-circuit", 1, 1}}}
for u, list in pairs(UNIT_LOOT) do
  u.loot = {}
  for _, m in ipairs(list) do table.insert(u.loot, {type = "item", name = m[1], independent_probability = 0.5, amount_min = m[2], amount_max = m[3]}) end
end

data:extend({infantry, tank, walker, harrier, trooper, breacher, battle_tank, gun_buggy, hauler, buggy, shotgun_hand, pellet,
  lance, slug, arc_bounce, arc_chain, shock, sapper, aegis, dozer, scavenger, laser_drone, rail_beam, railgunner})
