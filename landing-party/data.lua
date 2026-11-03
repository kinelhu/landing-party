-- Prototypes: the faction's machines are retinted vanilla ones, never craftable by the player.
local shared = require("shared")

local function watts(w) return tostring(math.abs(w) / 1000) .. "kW" end
local function one_second(w) return tostring(math.abs(w) / 1000) .. "kJ" end

-- Multiply the tint of every sprite layer in a graphics table, shadows and lights excepted.
-- Space Age's buildings as the corporations' (the graphics pass, the user, 2026-11-03: "less multipurpose ones, and more
-- identifiable units/buildings"; the Space Age kitbash chosen): sprite layers copied at a scale, their shifts with them.
local function scaled(layers, k)
  local out = {}
  for _, l in ipairs(layers) do
    local c = table.deepcopy(l)
    c.scale = (c.scale or 1) * k
    if c.shift then c.shift = {c.shift[1] * k, c.shift[2] * k} end
    out[#out + 1] = c
  end
  return out
end
-- As one sprite facing one way (a radar's pictures): its first frame, direction_count 1.
local function still(layers)
  for _, l in ipairs(layers) do
    l.frame_count, l.line_length, l.repeat_count, l.animation_speed, l.frame_sequence = nil, nil, nil, nil, nil
    l.direction_count = 1
  end
  return layers
end
local function sa(t, n) return data.raw[t] and data.raw[t][n] end

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

-- Ordinary loot (docs/reviews/2026-10-15-faction-loot-consult.md; the user: no salvage currency, Factorio's own items):
-- what a faction building of this cost is made of, iron cost/2, copper cost/4, circuits cost/10, and its kind's own.
-- Under 8 parts (walls, gates, pylons, bins, lamps, mines, flamers) nothing, or every wall would be a mine. Dropped on
-- death at 80%, half to all of each (the engine's loot, put in a wreck: control.lua); its ruins and captures mine to all of it.
local FLAVOUR = {["lp-turret"] = {{"firearm-magazine", 2, 5}}, ["lp-gun-turret"] = {{"firearm-magazine", 2, 5}},
  ["lp-scrap-cannon"] = {{"firearm-magazine", 2, 5}}, ["lp-generator"] = {{"engine-unit", 1, 1}},
  ["lp-drill"] = {{"iron-gear-wheel", 2, 2}}, ["lp-depot"] = {{"steel-plate", 10, 10}},
  ["lp-lander"] = {{"steel-plate", 20, 20}}, ["lp-uplink"] = {{"steel-plate", 40, 40}}}
local function made_of(name, cost)
  local out = {}
  if cost and cost >= 8 then
    for _, m in ipairs({{"iron-plate", cost / 2}, {"copper-plate", cost / 4}, {"electronic-circuit", cost / 10}}) do
      if m[2] >= 1 then table.insert(out, {m[1], math.max(1, math.floor(m[2] / 2)), math.floor(m[2])}) end
    end
  end
  for _, f in ipairs(FLAVOUR[name] or {}) do table.insert(out, f) end
  return out
end
local function loot_of(list)
  local loot = {}
  for _, m in ipairs(list) do table.insert(loot, {type = "item", name = m[1], independent_probability = 0.8, amount_min = m[2], amount_max = m[3]}) end
  return #loot > 0 and loot or nil
end
local function mined_of(list)
  local results = {}
  for _, m in ipairs(list) do table.insert(results, {type = "item", name = m[1], amount = m[3]}) end
  return results
end

-- A faction copy of a vanilla prototype: renamed, retinted, not blueprintable. Nothing the faction owns can be mined,
-- only its ruins once a settlement falls, or what the player captured: to what it is made of (made_of).
local MILITARY = {["lp-turret"] = true, ["lp-gun-turret"] = true, ["lp-flamer"] = true, ["lp-gate"] = false, ["lp-mortar"] = true, ["lp-howitzer"] = true, ["lp-orbital-relay"] = true, ["lp-dome-projector"] = true, ["lp-depot"] = true, ["lp-radar"] = true, ["lp-pacifier"] = true, ["lp-lander"] = true,
  ["lp-uplink"] = true, ["lp-launchpad"] = true, ["lp-scrap-cannon"] = true,
  ["lp-optics-lab"] = true, ["lp-line-lab"] = true, ["lp-siege-lab"] = true}
local function copy(type, name, new)
  local name_new = new
  local p = table.deepcopy(data.raw[type][name])
  p.name = new
  local cost = shared.cost[new]
  local stuff = made_of(new, cost)
  p.minable = cost and {mining_time = 1, results = mined_of(stuff)} or nil
  p.loot = loot_of(stuff)
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
-- The scrap cannon's burst and each of its six fragments (physical).
local SCRAP_BURST, SCRAP_FRAGMENT = 12, 6
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
-- A military target as built (a camp's mortars draw biters off its other guns: made none, a hazard clearance's camp
-- held worse, 2026-11-01), changeable at runtime: a siege's mortar against a player is made none on deployment
-- (siege.lua), so the player's artillery does not pick it by itself (the user, 2026-11-01: "force players to manually
-- target if they want it dead"; one shell killed every siege's mortar under artillery in 5 s, phase visit). An
-- artillery remote still aims at it. The howitzer stays one: outranged by the player's artillery by design.
mortar.allow_run_time_change_of_is_military_target = true
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
-- The orbital shell (the user: Serenity "shells from above, before landing ... a very dramatic entrance"): the shell at
-- eight times its blow (as the howitzer's), more bomblets, a bigger burst; fired by script from the sky (war.lua).
local orbital = table.deepcopy(projectile)
orbital.name = "lp-orbital-projectile"
local blast = orbital.action[1].action_delivery.target_effects
for _, e in ipairs(blast) do
  if e.type == "nested-result" then
    for _, d in ipairs(e.action.action_delivery.target_effects) do d.damage.amount = d.damage.amount * 8 end
  elseif e.type == "create-entity" then
    e.entity_name = "massive-explosion"
  end
end
orbital.action[2].cluster_count = 10
orbital.action[2].distance = 6
-- Its lance (the user, 2026-11-03: the strike "more visual, more orbital"): the laser beam's own graphics, white-cyan and
-- wider, drawn by script from high above each shell's point to the ground as it falls (orbital.lua); no damage of its own.
local lance = table.deepcopy(data.raw.beam["laser-beam"])
lance.name = "lp-orbital-lance"
lance.working_sound = nil
lance.action = nil
lance.width = 1.5
local LANCE_TINT = {r = 0.75, g = 0.95, b = 1, a = 1}
local function tint_all(t)
  for _, v in pairs(t) do
    if type(v) == "table" then
      if v.filename or v.filenames then v.tint = LANCE_TINT; v.scale = (v.scale or 0.5) * 2 end
      tint_all(v)
    end
  end
end
tint_all(lance.graphics_set or {})
data:extend({lance})

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
-- Deployed, the howitzer truck (units.lua): the tank's hull under the cannon, facing as the truck stood (siege.lua
-- gives it the truck's direction), the hull's colour on its mask as the truck's.
-- One frame of a rotated layer laid out in stripes (the tank's): the direction's cell, its first frame.
local function stripe_frame(l, d)
  local seen, start = {}, 0
  for _, st in ipairs(l.stripes) do
    if not seen[st.filename] then
      seen[st.filename] = true
      if d < start + st.height_in_frames then
        return {filename = st.filename, width = l.width, height = l.height, x = 0, y = (d - start) * l.height,
          shift = l.shift, scale = l.scale, draw_as_shadow = l.draw_as_shadow,
          tint = l.apply_runtime_tint and shared.TINT or nil}
      end
      start = start + st.height_in_frames
    end
  end
end
local function hull(d)
  local layers = {}
  for _, l in ipairs(data.raw.car.tank.animation.layers) do table.insert(layers, stripe_frame(l, d)) end
  return {layers = layers}
end
howitzer.base_picture = {north = hull(0), east = hull(16), south = hull(32), west = hull(48)}
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

-- The howitzer parked at home (base.park): its look, as a prop. Not a turret and not a military target (a parked
-- artillery turret was the rivals' first raid target and was counted as a howitzer out on a siege); it can be shot.
local function frame(layer)
  return {filename = layer.filenames and layer.filenames[1] or layer.filename, width = layer.width, height = layer.height,
    x = 0, y = 0, shift = layer.shift, scale = layer.scale, tint = layer.tint, draw_as_shadow = layer.draw_as_shadow}
end
local parked_layers = {}
-- The truck parked: its hull, the cannon raised on it as the turret draws it (cannon_base_shift).
for _, l in ipairs(hull(0).layers) do table.insert(parked_layers, l) end
for _, set in ipairs({howitzer.cannon_base_pictures, howitzer.cannon_barrel_pictures}) do
  for _, l in ipairs(set.layers or {set}) do
    local f = frame(l)
    local sh = f.shift or {0, 0}
    f.shift = {sh[1], sh[2] - howitzer.cannon_base_shift[3]}
    table.insert(parked_layers, f)
  end
end
local parked_howitzer = {type = "simple-entity-with-force", name = "lp-parked-howitzer", hidden = true,
  icons = table.deepcopy(howitzer.icons), flags = {"placeable-neutral", "placeable-enemy", "not-blueprintable"},
  max_health = howitzer.max_health, resistances = table.deepcopy(howitzer.resistances),
  collision_box = howitzer.collision_box, selection_box = howitzer.selection_box, render_layer = "object",
  dying_explosion = howitzer.dying_explosion, is_military_target = false, picture = {layers = parked_layers}}
data:extend({parked_howitzer})

-- A gun turret (a corporation may build these instead of lasers: shared.CORPS bases; fed by script) and a gate.
local gun_turret = copy("ammo-turret", "gun-turret", "lp-gun-turret")
local gate = copy("gate", "gate", "lp-gate")
-- A flamethrower turret covering a gate (Serenity), kept in light oil by script.
local flamer = copy("fluid-turret", "flamethrower-turret", "lp-flamer")
-- No circuit network (2.1 gave the flamethrower turret 8 connectors where a copy takes 4).
flamer.circuit_connector = nil
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
-- The orbital relay (an armed camp's, war.lua): its sweeps are called through it; destroyed or without power, none.
local relay = copy("radar", "radar", "lp-orbital-relay")
relay.energy_usage = watts(shared.power["lp-radar"])
relay.max_health = 2000
data:extend({relay})
-- The dome projector (a Kessler-Hayashi hub's dome, dome.lua): up while it stands with power. (A radar's body for now.)
local projector = copy("radar", "radar", "lp-dome-projector")
projector.energy_usage = watts(shared.power["lp-radar"])
projector.max_health = 1500
-- Its body: Space Age's tesla turret at three quarters (4x4 to the projector's 3x3), unarmed, the tower its catches will
-- fire from (the user's idea, 2026-11-03: "Enlarged Tesla tower, fires a bolt at the shell").
local tesla = sa("electric-turret", "tesla-turret")
-- Its own body, modelled and rendered in Blender (tools/blender/tesla_tower.py, sheet.py; the user, 2026-11-03: "Can you
-- also make its anim sprites?"): 32 frames as a radar's 32 directions, so its turning plays the loop (a pulse climbing
-- the coil, the emitter breathing, arcs at its crown) while it has power, and it stands still without. Frame size and
-- shift from sheet.json. The tesla turret kitbash below is the fallback.
local TOWER = {width = 335, height = 370, shift = {0.8359375, -1.0078125}}
local function tower(file, extra)
  local l = {filename = "__landing-party__/graphics/serenity/tower/" .. file .. ".png", width = TOWER.width,
    height = TOWER.height, direction_count = 32, line_length = 8, scale = 0.5, shift = TOWER.shift}
  for k, v in pairs(extra or {}) do l[k] = v end
  return l
end
local TOWER_ON = true
local bv = tesla and tesla.graphics_set and tesla.graphics_set.base_visualisation
bv = bv and (bv.animation and bv or bv[1])
if bv and bv.animation and bv.animation.layers then
  local layers = scaled(bv.animation.layers, 0.75)
  -- And its coil (the head at rest, its first direction), the tower the base alone was not.
  for _, h in ipairs((tesla.prepared_animation or {}).layers or {}) do
    local c = scaled({h}, 0.75)[1]
    c.x, c.y = 0, 0
    layers[#layers + 1] = c
  end
  projector.pictures = {layers = still(layers)}
end
-- Its catch (dome.lua): a hemisphere of light spreading from where a shell is caught and fading (the user, 2026-11-03),
-- rendered in Blender (tools/blender/dome_ripple.py, anim_sheet.py: 16 frames, 32 px a tile, frame size and shift from
-- sheet.json), drawn as glow.
data:extend({{type = "explosion", name = "lp-dome-ripple", flags = {"not-on-map"}, hidden = true,
  animations = {{filename = "__landing-party__/graphics/serenity/ripple/sheet.png", width = 290, height = 335,
    frame_count = 16, line_length = 8, scale = 1, shift = {0, -0.71875}, draw_as_glow = true, blend_mode = "additive",
    animation_speed = 0.5}},
  light = {intensity = 0.5, size = 12, color = {r = 0.3, g = 0.75, b = 1}}}})
if TOWER_ON then
  projector.pictures = {layers = {tower("body"), tower("glow", {draw_as_glow = true, blend_mode = "additive"}),
    tower("shadow", {draw_as_shadow = true})}}
  projector.rotation_speed = 0.006
end
data:extend({projector})

-- Research labs (rd.lua): a vanilla lab, lit as if always researching, one kind a branch of the corporation's tree.
-- Military targets: what a player's turrets and squads go for.
-- A size up (4x4, the vanilla art at 4/3: the user, 2026-10-21, "they look a little puny"), and always at work: a lab
-- animates only while researching, and the faction's research is scripted, so its body is drawn by script (base.lua,
-- lab_look: the animation lp-lab-busy, its blinking lights included) over the entity's own floor plate and shadow.
local LAB_SCALE = 4 / 3
local function lab_layer(l)
  local c = table.deepcopy(l)
  c.scale = (c.scale or 1) * LAB_SCALE
  if c.shift then c.shift = {c.shift[1] * LAB_SCALE, c.shift[2] * LAB_SCALE} end
  return c
end
local vanilla_lab = data.raw.lab.lab.on_animation.layers
-- Each its own body, from a Space Age building (the graphics pass): its still layers the plate, its moving ones the busy
-- animation drawn over it (base.lab_look). Optics: the electromagnetic plant (4x4, at scale); line: the cryogenic plant;
-- siege: the foundry (both 5x5, at four fifths). Without Space Age, the vanilla lab for all three.
local function file_of(l) return l.filename or (l.filenames and l.filenames[1]) or "" end
local function find(layers, pat)
  for _, l in ipairs(layers or {}) do if file_of(l):find(pat, 1, true) then return l end end
end
local function wv(set, pat)
  for _, v in ipairs(set.working_visualisations or {}) do
    local a = v.animation
    for _, l in ipairs(a and (a.layers or {a}) or {}) do if file_of(l):find(pat, 1, true) then return l end end
  end
end
local LAB_BODY = {}
do
  local em = sa("assembling-machine", "electromagnetic-plant")
  if em and em.graphics_set then
    local g = em.graphics_set
    LAB_BODY["lp-optics-lab"] = {k = 1, still = g.idle_animation and g.idle_animation.layers or {},
      moving = {wv(g, "main-rotate-continue"), wv(g, "shadow-rotate-continue")}}
  end
  local cryo = sa("assembling-machine", "cryogenic-plant")
  if cryo and cryo.graphics_set then
    local g = cryo.graphics_set
    LAB_BODY["lp-line-lab"] = {k = 0.8, still = {find(g.animation.layers, "cryogenic-plant-main"), find(g.animation.layers, "cryogenic-plant-shadow")},
      moving = {find(g.animation.layers, "anim1-base"), wv(g, "anim1-working")}}
  end
  local foundry = sa("assembling-machine", "foundry")
  if foundry and foundry.graphics_set then
    local g = foundry.graphics_set
    LAB_BODY["lp-siege-lab"] = {k = 0.8, still = {find(g.animation.layers, "foundry-base"), find(g.animation.layers, "foundry-shadow")},
      moving = {find(g.animation.layers, "foundry-anim-1"), wv(g, "foundry-lights-1")}}
  end
end
local labs = {}
for _, name in ipairs({"lp-optics-lab", "lp-line-lab", "lp-siege-lab"}) do
  local l = copy("lab", "lab", name)
  l.energy_source = {type = "void"}
  l.max_health = 600
  l.collision_box = {{-1.9, -1.9}, {1.9, 1.9}}
  l.selection_box = {{-2, -2}, {2, 2}}
  local plate = {layers = {}}
  for _, v in ipairs(vanilla_lab) do
    if v.repeat_count then table.insert(plate.layers, lab_layer(v)) end
  end
  local body = LAB_BODY[name]
  if body and #body.still > 0 and #body.moving > 0 then
    plate = {layers = scaled(body.still, body.k)}
    for _, s in ipairs(plate.layers) do s.frame_count, s.line_length, s.repeat_count = 1, 1, nil end
    table.insert(labs, {type = "animation", name = name .. "-busy", layers = scaled(body.moving, body.k)})
  else
    -- (The vanilla lab tinted; a Space Age body is recoloured by corporation, scripts/make_sprites.py, or kept as it is.)
    tint(plate, {})
  end
  l.on_animation = plate
  l.off_animation = table.deepcopy(plate)
  table.insert(labs, l)
end
local busy = {type = "animation", name = "lp-lab-busy", layers = {}}
for _, v in ipairs(vanilla_lab) do
  if v.frame_count then table.insert(busy.layers, lab_layer(v)) end
end
tint(busy, {})
table.insert(labs, busy)
data:extend(labs)

-- The pacifier (scripts/pact.lua): a radar dish broadcasting to the biters; while one stands, its corporation and they
-- hold fire on each other. Self-powered, reveals nothing.
local pacifier = copy("radar", "radar", "lp-pacifier")
pacifier.max_health = 1500
pacifier.energy_source = {type = "void"}
pacifier.max_distance_of_sector_revealed = 0
pacifier.max_distance_of_nearby_sector_revealed = 0
pacifier.rotation_speed = 0.03
-- A size larger than a radar (and slow-turning), so it is not taken for one: the player's target.
pacifier.collision_box = {{-1.9, -1.9}, {1.9, 1.9}}
pacifier.selection_box = {{-2, -2}, {2, 2}}
local function grow(t, k, seen)
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if t.filename or t.filenames or t.stripes then
    t.scale = (t.scale or 1) * k
    if t.shift then t.shift = {t.shift[1] * k, t.shift[2] * k} end
  end
  for _, v in pairs(t) do grow(v, k, seen) end
end
grow(pacifier.pictures, 1.4, {})

-- The scrap cannon (Grubstake's "dirty flak": the user; docs/reviews/2026-10-15-grubstake-flavour-consult.md): a gun
-- turret's body a size up, lobbing a shell that bursts over the target. Many soft hits over an area (the railgun's
-- answer is one hard hit along a line): deadly to a blob of troopers or biters, next to nothing against walls and
-- turrets. Short (16: past a Line trooper's 15, which stood off and shot a cannon of 14 unanswered; inside a gun turret's 18), slow, its enemies only. Fed by script (base.lua), as the gun turrets are.
local cannon = copy("ammo-turret", "gun-turret", "lp-scrap-cannon")
grow(cannon.graphics_set, 1.25, {})
cannon.max_health = 500
cannon.attack_parameters = {type = "projectile", ammo_categories = {"lp-scrap"}, cooldown = 40, range = 16,
  projectile_creation_distance = 1.4, turn_range = 1, sound = table.deepcopy(data.raw.gun["tank-cannon"].attack_parameters.sound)}
local scrap_frag = table.deepcopy(data.raw.projectile["grenade"])
scrap_frag.name = "lp-scrap-fragment"
scrap_frag.action = {{type = "direct", action_delivery = {type = "instant", target_effects = {
    {type = "create-entity", entity_name = "explosion-hit"}}}},
  {type = "area", radius = 1.2, force = "enemy", action_delivery = {type = "instant", target_effects = {
    {type = "damage", damage = {amount = SCRAP_FRAGMENT, type = "physical"}}}}}}
scrap_frag.light = nil
grow(scrap_frag.animation, 0.5, {})
local scrap_burst = table.deepcopy(data.raw.projectile["grenade"])
scrap_burst.name = "lp-scrap-burst"
scrap_burst.light = nil
scrap_burst.action = {{type = "direct", action_delivery = {type = "instant", target_effects = {
    {type = "create-entity", entity_name = "explosion"}}}},
  {type = "area", radius = 2.5, force = "enemy", action_delivery = {type = "instant", target_effects = {
    {type = "damage", damage = {amount = SCRAP_BURST, type = "physical"}}}}},
  {type = "cluster", cluster_count = 6, distance = 3, distance_deviation = 1.5, action_delivery = {type = "projectile",
    projectile = "lp-scrap-fragment", direction_deviation = 0.6, starting_speed = 0.25, starting_speed_deviation = 0.3}}}
local scrap_shell = table.deepcopy(data.raw.ammo["firearm-magazine"])
scrap_shell.name = "lp-scrap-shell"
scrap_shell.hidden = true
scrap_shell.ammo_category = "lp-scrap"
scrap_shell.magazine_size = 1
scrap_shell.ammo_type = {target_type = "position", clamp_position = true, action = {type = "direct", action_delivery = {
  type = "projectile", projectile = "lp-scrap-burst", starting_speed = 0.5}}}

-- The depot: Space Age's cargo landing pad at half size, a pad pods come down on (the user, 2026-10-21: "depots are
-- still roboports? I thought we were going space age"; a cargo bay alone read as a small hatch box, it is drawn to sit in a
-- row of them); a roboport's body without its graphics. Both 4x4.
local roboport = data.raw.roboport.roboport
local depot = copy("container", "iron-chest", "lp-depot")
depot.collision_box = roboport.collision_box
depot.selection_box = roboport.selection_box
local hub = data.raw["cargo-landing-pad"] and data.raw["cargo-landing-pad"]["cargo-landing-pad"]
local HUB_SCALE = 0.5
if hub and hub.graphics_set and hub.graphics_set.picture then
  local layers = {}
  for _, part in ipairs(hub.graphics_set.picture) do
    -- Not the hatch's occluder (a mask over the cargo pods' hatch, nothing to see on its own).
    for _, l in ipairs(part.layers or {part}) do
      if not (l.filename or ""):find("occluder") then
        local c = table.deepcopy(l)
        c.scale = (c.scale or 1) * HUB_SCALE
        if c.shift then c.shift = {c.shift[1] * HUB_SCALE, c.shift[2] * HUB_SCALE} end
        table.insert(layers, c)
      end
    end
  end
  depot.picture = {layers = layers}
else
  depot.picture = table.deepcopy(roboport.base)
end
tint(depot.picture, {})
depot.inventory_size = 48
depot.max_health = 1000

-- The launch pad: the rocket silo's base as a container.
local silo = data.raw["rocket-silo"]["rocket-silo"]
local launchpad = copy("container", "iron-chest", "lp-launchpad")
launchpad.collision_box = silo.collision_box
launchpad.selection_box = silo.selection_box
-- The whole silo, shut (the user, 2026-10-21: the base ring alone read as a bare ring on sand): its shadow, the hole, the
-- closed doors, the base and its front.
launchpad.picture = {layers = {}}
for _, k in ipairs({"shadow_sprite", "hole_sprite", "door_back_sprite", "door_front_sprite", "base_day_sprite", "base_front_sprite"}) do
  local l = silo[k] and table.deepcopy(silo[k])
  if l then
    if k == "shadow_sprite" then l.draw_as_shadow = true end
    table.insert(launchpad.picture.layers, l)
  end
end
tint(launchpad.picture, {})
launchpad.inventory_size = 10
launchpad.max_health = 2000

-- Belts in its districts (layout.belts; belts.lua moves parts along them while a player is near): a transport belt.
local belt = copy("transport-belt", "transport-belt", "lp-belt")
belt.max_health = 150
belt.related_underground_belt = nil
data:extend({belt})

local lamp = copy("lamp", "small-lamp", "lp-lamp")
lamp.light = {intensity = 0.9, size = 40, color = {0.6, 0.8, 1}}
-- A cordon post's lamp (Fable's look consult: the lit line): no grid out there, so it burns on nothing; cold white.
local post_lamp = copy("lamp", "small-lamp", "lp-post-lamp")
post_lamp.energy_source = {type = "void"}
-- Blue enough to stay cold on sand (white light on desert read orange in the first screenshots).
post_lamp.light = {intensity = 0.9, size = 30, color = {0.55, 0.75, 1}}
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
-- Its body: Space Age's fusion reactor (6x6, at scale), the faction's link home lit as if running (the graphics pass: a
-- radar dish at twice the size read as a radar).
local fusion = sa("fusion-reactor", "fusion-reactor")
if fusion and fusion.graphics_set and fusion.graphics_set.structure then
  local layers = scaled(fusion.graphics_set.structure.layers, 1)
  -- (Its glow in Kessler-Hayashi's cyan, the reactor's own magenta read as nobody's.)
  for _, gl in ipairs((fusion.graphics_set.working_light_pictures or {}).layers or {}) do
    local c = table.deepcopy(gl)
    c.tint = {r = 0.45, g = 0.9, b = 1, a = 1}
    layers[#layers + 1] = c
  end
  uplink.pictures = {layers = still(layers)}
end

local road_of = shared.CORPS[shared.DEFAULT_CORP].road
local road = table.deepcopy(data.raw.tile[road_of.tile] or data.raw.tile[road_of.fallback or "refined-concrete"])
road.name = "lp-road"
road.minable = nil
road.placeable_by = nil
road.tint = shared.TINT
road.map_color = {r = 0.32, g = 0.38, b = 0.46}

data:extend({
  lander, generator, pylon, drill, bin, fabricator, turret, wall, radar, pacifier, depot, road, launchpad, lamp, post_lamp, mine, uplink,
  gun_turret, gate, flamer, flamer_stream, cannon, scrap_frag, scrap_burst, scrap_shell,
  {type = "ammo-category", name = "lp-scrap", hidden = true},
  mortar, mortar_gun, mortar_shell, projectile, bomblet, orbital, howitzer, howitzer_gun, {type = "ammo-category", name = "lp-mortar", hidden = true},
  {type = "recipe-category", name = "lp-fabrication"},
  {type = "item", name = "lp-feedstock", icon = "__base__/graphics/icons/stone.png", hidden = true,
    stack_size = 200, subgroup = "other"},
  {type = "item", name = "lp-part", icon = "__base__/graphics/icons/iron-gear-wheel.png", hidden = true,
    stack_size = 200, subgroup = "other"},
  {type = "recipe", name = "lp-parts", categories = {"lp-fabrication"}, hidden = true, enabled = true,
    energy_required = shared.PART_SECONDS,
    ingredients = {{type = "item", name = "lp-feedstock", amount = shared.FEEDSTOCK_PER_PART}},
    results = {{type = "item", name = "lp-part", amount = 1}}},
})

-- A wreck (shared.wreck): the crash site's wreck chest, what the corporations' dead leave, mined to what it holds.
local wreck = table.deepcopy(data.raw.container["crash-site-chest-1"])
wreck.name = "lp-wreck"
wreck.hidden = true
wreck.minable = {mining_time = 0.5}
wreck.inventory_size = 16
wreck.max_health = 100
wreck.flags = {"placeable-neutral", "placeable-off-grid", "not-blueprintable"}
wreck.loot = nil
wreck.corpse = nil
-- Blocks nothing: one where a turret died had stood in its rebuild's way (defend: the outpost's turrets never came back).
wreck.collision_mask = {layers = {}}
data:extend({wreck})

-- The pheromone bait's smoke (scripts/bait.lua): a tall orange column the script puffs while it burns (it was Grubstake's
-- flare canister's until the flare was retired, 2026-10-22).
local flare_smoke = table.deepcopy(data.raw["trivial-smoke"]["smoke"])
flare_smoke.name = "lp-flare-smoke"
flare_smoke.color = {r = 1, g = 0.45, b = 0.1, a = 0.7}
flare_smoke.duration = 360
flare_smoke.fade_away_duration = 120
flare_smoke.start_scale = 0.6
flare_smoke.end_scale = 3
flare_smoke.affected_by_wind = false
flare_smoke.movement_slow_down_factor = 0
flare_smoke.cyclic = true
data:extend({flare_smoke})

-- The claim jumper's rig (scripts/jumper.lua): an electric drill's body a size up, in Grubstake's colour, 1,200 health,
-- a military target; dust puffs from it and from the mound it digs toward while it works.
local rig_anim = table.deepcopy(data.raw["mining-drill"]["electric-mining-drill"].graphics_set.animation.north)
grow(rig_anim, 1.3, {})
for _, l in ipairs(rig_anim.layers) do
  if not l.draw_as_shadow then l.tint = shared.CORPS.grubstake.tint end
end
local claim_rig = {type = "simple-entity-with-force", name = "lp-claim-rig", hidden = true,
  icon = "__base__/graphics/icons/electric-mining-drill.png", icon_size = 64,
  flags = {"placeable-neutral", "placeable-enemy", "not-blueprintable", "not-deconstructable"},
  max_health = 1200, is_military_target = true, collision_box = {{-1.9, -1.9}, {1.9, 1.9}},
  selection_box = {{-2, -2}, {2, 2}}, dying_explosion = "big-explosion",
  resistances = {{type = "physical", decrease = 4, percent = 20}},
  animations = rig_anim, map_color = {r = 0.8, g = 0.55, b = 0.2}}
local dust_smoke = table.deepcopy(data.raw["trivial-smoke"]["smoke"])
dust_smoke.name = "lp-dust-smoke"
dust_smoke.color = {r = 0.55, g = 0.42, b = 0.28, a = 0.6}
dust_smoke.duration = 180
dust_smoke.fade_away_duration = 90
dust_smoke.start_scale = 0.5
dust_smoke.end_scale = 2
data:extend({claim_rig, dust_smoke})

-- Serenity's jammer (scripts/jammer.lua; Fable's fortress consult: "an entity in the emplacement, a tall mast, a lamp
-- ring, arcs that strike robots entering the radius, visibly"): a big pole's mast in Serenity's colour, 1,500 health, a
-- military target (the player's turrets and artillery go for it). The arcs and the lamp ring are drawn by script.
local mast_layers = {}
for _, l in ipairs(data.raw["electric-pole"]["big-electric-pole"].pictures.layers) do
  table.insert(mast_layers, {filename = l.filename, width = l.width, height = l.height, shift = l.shift, scale = (l.scale or 1) * 1.15,
    x = 0, y = 0, draw_as_shadow = l.draw_as_shadow, tint = (not l.draw_as_shadow) and {r = 0.62, g = 0.8, b = 1, a = 1} or nil})
end
data:extend({{type = "simple-entity-with-force", name = "lp-jammer", hidden = true,
  icon = "__base__/graphics/icons/big-electric-pole.png", icon_size = 64,
  flags = {"placeable-neutral", "placeable-enemy", "not-blueprintable", "not-deconstructable"},
  max_health = 1500, is_military_target = true, collision_box = {{-0.65, -0.65}, {0.65, 0.65}},
  selection_box = {{-1, -1}, {1, 1}}, dying_explosion = "big-explosion",
  resistances = {{type = "physical", decrease = 4, percent = 20}, {type = "laser", percent = 20}},
  picture = {layers = mast_layers}, map_color = {r = 0.5, g = 0.75, b = 1}}})
-- Its own mast, modelled and rendered in Blender (tools/blender/jammer_mast.py, sheet.py; the graphics pass, 2026-11-03):
-- a lattice mast on a 2x2 footing, arcs jumping between the three nodes at its crown, 16 frames looping while it stands.
-- Frame size and shift from sheet.json; the big pole above is the fallback.
do
  local J = {width = 337, height = 422, shift = {1.3984375, -1.953125}}
  local function jam(file, extra)
    local l = {filename = "__landing-party__/graphics/serenity/jammer/" .. file .. ".png", width = J.width, height = J.height,
      frame_count = 16, line_length = 8, scale = 0.5, shift = J.shift, animation_speed = 0.4}
    for k, v in pairs(extra or {}) do l[k] = v end
    return l
  end
  local jammer = data.raw["simple-entity-with-force"]["lp-jammer"]
  jammer.picture = nil
  jammer.animations = {layers = {jam("body"), jam("glow", {draw_as_glow = true, blend_mode = "additive"}),
    jam("shadow", {draw_as_shadow = true})}}
end

-- The power tap (scripts/tap.lua): a small lamp's body as a clamp on the player's line, in Grubstake's colour; an energy
-- interface drawing what the script sets. Not a military target (turrets pass it by). Its receiver at the end of the
-- camp's line gives the camp what it draws: unseen, untouchable.
local lamp_pic = table.deepcopy(data.raw.lamp["small-lamp"].picture_off)
for _, l in ipairs(lamp_pic.layers or {lamp_pic}) do
  if not l.draw_as_shadow then l.tint = shared.CORPS.grubstake.tint end
end
local power_tap = {type = "electric-energy-interface", name = "lp-power-tap", hidden = true,
  icon = "__base__/graphics/icons/small-lamp.png", icon_size = 64,
  flags = {"placeable-neutral", "placeable-enemy", "not-blueprintable", "not-deconstructable"},
  max_health = 150, is_military_target = false, collision_box = {{-0.3, -0.3}, {0.3, 0.3}},
  selection_box = {{-0.5, -0.5}, {0.5, 0.5}}, dying_explosion = "explosion", picture = lamp_pic, gui_mode = "none",
  energy_source = {type = "electric", usage_priority = "secondary-input", buffer_capacity = "1MJ"},
  energy_production = "0W", energy_usage = "0W",
  loot = {{type = "item", name = "copper-cable", independent_probability = 1, amount_min = 5, amount_max = 10}}}
local power_receiver = {type = "electric-energy-interface", name = "lp-power-receiver", hidden = true,
  icon = "__base__/graphics/icons/small-lamp.png", icon_size = 64,
  flags = {"placeable-neutral", "placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable"},
  selectable_in_game = false, max_health = 1, collision_box = {{-0.1, -0.1}, {0.1, 0.1}}, collision_mask = {layers = {}},
  picture = {filename = "__core__/graphics/empty.png", size = 1}, gui_mode = "none",
  energy_source = {type = "electric", usage_priority = "primary-output", buffer_capacity = "1MJ"},
  energy_production = "0W", energy_usage = "0W"}
data:extend({power_tap, power_receiver})

require("units")
require("player")
require("corps")
require("look")
require("plates")
require("components")
require("biotech")
