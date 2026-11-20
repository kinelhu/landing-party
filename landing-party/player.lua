-- The player's side: a barracks that trains troopers from items, and a rally beacon whose circuit signals
-- set their stance (scripts/command.lua). Unlocked from the start while this is a prototype.
local shared = require("shared")

local barracks = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
barracks.name = "lp-barracks"
barracks.localised_description = {"entity-description.lp-barracks", tostring(shared.SUPPLY_RANGE)}
barracks.minable = {mining_time = 0.5, result = "lp-barracks"}
barracks.next_upgrade = nil
barracks.fast_replaceable_group = nil
barracks.crafting_categories = {"lp-training"}
-- No fixed recipe: troopers, breachers or battle tanks (a new barracks starts on troopers).
barracks.module_slots = 0
-- Speed 1, so a recipe's time is its training time (assembling machine 2's 0.75 until 0.2.454: "30 s a trooper" took 40;
-- the recipes raised to what training took, the pace unchanged). No modules, no beacons: how fast a force trains is how
-- many barracks it has, each a command core earned from the corporations' wreckage.
barracks.crafting_speed = 1
barracks.allowed_effects = nil
-- Its own body, rendered in Blender (tools/blender/player_army.py barracks, sheet.py): a training plant, an assembler's
-- chamfered block in warm steel, a roll-up bay door; training, its roof fans turn, the strip over its door runs and its
-- amber lamp sweeps (16 frames). (An olive hangar with sandbags and a flag first, 2026-11-03: "less Army Men", the user.)
local SHEETS = require("graphics.sheets")
do
  local S = SHEETS["player/barracks"]
  local function bk(file, extra)
    local l = {filename = "__landing-party__/graphics/player/barracks/" .. file .. ".png", width = S.width,
      height = S.height, frame_count = S.frames, line_length = S.line_length, scale = 0.5, shift = S.shift,
      animation_speed = 0.4}
    for k, v in pairs(extra or {}) do l[k] = v end
    return l
  end
  barracks.graphics_set = {animation = {layers = {bk("body"), bk("shadow", {draw_as_shadow = true})}},
    working_visualisations = {{animation = bk("glow", {draw_as_glow = true, blend_mode = "additive"}),
      -- (Its lit window and bay strip light the ground while it trains: glow alone lit nothing at night, the gallery.)
      light = {intensity = 0.6, size = 9, shift = {0, 1}, color = {r = 1, g = 0.75, b = 0.45}}}}}
end

-- The command relay: a radar's body; each powered relay carries shared.RELAY_CAPACITY units of command
-- bandwidth, as many relays counting as the research allows (scripts/command.lua).
local relay = table.deepcopy(data.raw.radar.radar)
relay.name = "lp-command-relay"
relay.minable = {mining_time = 0.5, result = "lp-command-relay"}
relay.next_upgrade = nil
relay.energy_usage = "2MW"
relay.max_distance_of_sector_revealed = 0
relay.max_distance_of_nearby_sector_revealed = 3
relay.localised_description = {"entity-description.lp-command-relay", tostring(shared.RELAY_CAPACITY)}
-- Its own model (tools/blender/turning_buildings.py; the user, 2026-11-10: "I still see some gross recolors"): a lattice
-- mast, its antenna head turning, 32 steps (a radar's sprite turns whole), its lights and its shadow turning with it.
do
  local function sheet(key, part, extra)
    local S = SHEETS[key]
    local base = "__landing-party__/graphics/" .. key .. "/" .. part
    local l = {width = S.width, height = S.height, direction_count = S.frames, line_length = S.line_length, scale = 0.5, shift = S.shift}
    if S.files then
      l.filenames, l.lines_per_file = {}, S.lines_per_file
      for k = 1, S.files do l.filenames[k] = base .. "-" .. k .. ".png" end
    else
      l.filename = base .. ".png"
    end
    for k, v in pairs(extra or {}) do l[k] = v end
    return l
  end
  relay.pictures = {layers = {sheet("player/command-relay", "body"),
    sheet("player/command-relay", "glow", {draw_as_glow = true, blend_mode = "additive"}),
    sheet("player/command-relay", "shadow", {draw_as_shadow = true})}}
end

-- The rally beacon: a constant combinator. Its own signals give orders (opened like any combinator); wired, it
-- reads its network as well, for automation. A small lamp with a combinator wired to it once confused the
-- first player to try it.
local beacon = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
beacon.name = "lp-rally-beacon"
beacon.icon = "__base__/graphics/icons/small-lamp.png"
beacon.minable = {mining_time = 0.2, result = "lp-rally-beacon"}
beacon.next_upgrade = nil
beacon.fast_replaceable_group = nil

-- Their own models (tools/blender/player_buildings.py; the user, 2026-11-10: "I still see some gross recolors. Why not use
-- blender again?"): the beacon a mast with a pennant and an amber lamp, the scanner a low sensor head with a red sweep
-- light; four directions each, a still body with its shadow and its lights (a combinator's sprite does not animate), its
-- wire posts where the render put them (posts in the sheet's registry), no vanilla activity lamp.
local function combinator_look(e, key)
  local D = SHEETS[key]
  local function f(d, part) return "__landing-party__/graphics/" .. key .. "/" .. d .. "-" .. part .. ".png" end
  local sprites, points = {}, {}
  for _, d in ipairs({"north", "east", "south", "west"}) do
    local S = D[d]
    sprites[d] = {layers = {
      {filename = f(d, "body"), width = S.width, height = S.height, scale = 0.5, shift = S.shift},
      {filename = f(d, "glow"), width = S.width / 2, height = S.height / 2, scale = 1, shift = S.shift, draw_as_glow = true,
        blend_mode = "additive"},
      {filename = f(d, "shadow"), width = S.width, height = S.height, scale = 0.5, shift = S.shift, draw_as_shadow = true}}}
    local P = D.posts[d]
    points[#points + 1] = {wire = {red = P.wire.red, green = P.wire.green}, shadow = {red = P.shadow.red, green = P.shadow.green}}
  end
  e.sprites = sprites
  e.circuit_wire_connection_points = points
  e.activity_led_sprites = {filename = "__core__/graphics/empty.png", width = 1, height = 1}
  e.activity_led_light_offsets = {{0, 0}, {0, 0}, {0, 0}, {0, 0}}
end
combinator_look(beacon, "player/rally-beacon")

-- The threat scanner (scripts/scanner.lua; the user, 2026-10-18: "a building that scans for enemy units in a radius and
-- gives signals for each unit type"): a constant combinator the mod writes, a radar's icon; one virtual signal a role,
-- a total a corporation, the crews (builders, apart from the army) and the biters.
local scanner = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
scanner.name = "lp-threat-scanner"
scanner.icon = "__base__/graphics/icons/radar.png"
scanner.minable = {mining_time = 0.2, result = "lp-threat-scanner"}
scanner.localised_description = {"entity-description.lp-threat-scanner", tostring(shared.SCAN_RADIUS)}
scanner.next_upgrade = nil
combinator_look(scanner, "player/threat-scanner")
scanner.fast_replaceable_group = nil
local signals = {}
local function signal(name, icon, tint, order)
  table.insert(signals, {type = "virtual-signal", name = name, icons = {{icon = icon, tint = tint}},
    subgroup = "virtual-signal", order = "z[landing-party]-" .. order})
end
local S_TINT, G_TINT = {r = 0.62, g = 0.8, b = 1, a = 1}, {r = 1, g = 0.75, b = 0.35, a = 1}
for k, g in ipairs(shared.SCAN_GROUPS) do signal(g.signal, g.icon, nil, string.format("a%02d", k)) end
signal("lp-scan-crew", "__landing-party__/graphics/icons/units/lp-technician.png", nil, "b")
signal("lp-scan-serenity", "__base__/graphics/icons/signal/signal_S.png", S_TINT, "c")
signal("lp-scan-grubstake", "__base__/graphics/icons/signal/signal_G.png", G_TINT, "d")
signal("lp-scan-biters", "__base__/graphics/icons/small-biter.png", nil, "e")
signal("lp-scan-jammed", "__space-age__/graphics/icons/tesla-turret.png", S_TINT, "f")
-- With bred-biter telemetry (a field study, studies.lua): Synthexis's biters, and its scout.
signal("lp-scan-synthexis", "__landing-party__/graphics/icons/units/lp-bred-medium-biter.png", nil, "g")
signal("lp-scan-scout", "__landing-party__/graphics/icons/units/lp-bred-scout.png", nil, "h")
-- A squad's size by unit, set on a rally beacon (scripts/command.lua): the order's icon, the army's green.
local SQUAD_ICON = {["lp-trooper"] = "__base__/graphics/icons/firearm-magazine.png", ["lp-breacher"] = "__base__/graphics/icons/grenade.png",
  ["lp-rocket-trooper"] = "__base__/graphics/icons/rocket-launcher.png", ["lp-flame-trooper"] = "__base__/graphics/icons/flamethrower.png",
  ["lp-battle-tank"] = "__base__/graphics/icons/tank.png", ["lp-gun-buggy"] = "__base__/graphics/icons/car.png"}
local SQUAD_ORDER = {["lp-trooper"] = "a", ["lp-breacher"] = "b", ["lp-rocket-trooper"] = "c", ["lp-flame-trooper"] = "d", ["lp-battle-tank"] = "e",
  ["lp-gun-buggy"] = "c2"}
for unit, sig in pairs(shared.SQUAD_SIGNALS) do
  signal(sig, SQUAD_ICON[unit] or "__base__/graphics/icons/signal/signal_S.png", {r = 0.55, g = 1, b = 0.55, a = 1}, "s" .. (SQUAD_ORDER[unit] or "z"))
end
data:extend(signals)

-- The muster point (scripts/command.lua; the user, 2026-10-18: "Trains could even play into the mix"): a steel chest's
-- body; orders put in it (carried from a packing barracks by train, belt or robot) become units beside it, assigned to
-- its nearest rally beacon, while the force's bandwidth has room.
local muster = table.deepcopy(data.raw.container["steel-chest"])
muster.name = "lp-muster-point"
muster.icon = "__base__/graphics/icons/steel-chest.png"
muster.minable = {mining_time = 0.3, result = "lp-muster-point"}
muster.inventory_size = 16
muster.next_upgrade = nil
muster.fast_replaceable_group = nil
-- Retired in 0.2.448 (orders stockpiled and deployed at once at the front; the user, "defeats the purposes of our
-- barracks"): kept hidden only so a save's placed ones load, to be taken off the map with what they held refunded as kit
-- (command.drop_musters).
muster.hidden = true
-- Its own body, rendered in Blender (tools/blender/player_army.py muster): a post, a radio box, a whip antenna with a lit
-- tip, a floodlight (its light drawn by command.lua).
do
  local S = SHEETS["player/muster"]
  muster.picture = {layers = {
    {filename = "__landing-party__/graphics/player/muster/body.png", width = S.width, height = S.height, scale = 0.5,
      shift = S.shift},
    {filename = "__landing-party__/graphics/player/muster/glow.png", width = S.width, height = S.height, scale = 0.5,
      shift = S.shift, draw_as_glow = true, blend_mode = "additive"},
    {filename = "__landing-party__/graphics/player/muster/shadow.png", width = S.width, height = S.height, scale = 0.5,
      shift = S.shift, draw_as_shadow = true}}}
end

-- The player's dome (dome.lua; the user, 2026-11-04: "a repurposed dome (smaller than KH) that the player can use to
-- protect from shelling", in place of a directional shield projector that "looks like crap"): Kessler-Hayashi's
-- projector made over, an energy interface drawing shared.PLAYER_DOME.draw; its dome catches its foes' shells by their
-- rule. Its body the corporations' dome tower (tools/blender/tesla_tower.py): their technology, taken apart.
do
  local PD = shared.PLAYER_DOME
  local T = SHEETS["serenity/tower"]
  local function tw(file, extra)
    local l = {filename = "__landing-party__/graphics/serenity/tower/" .. file .. ".png", width = T.width, height = T.height,
      frame_count = T.frames, line_length = T.line_length, scale = 0.5, shift = T.shift, animation_speed = 0.5}
    for k, v in pairs(extra or {}) do l[k] = v end
    return l
  end
  local proj = {type = "electric-energy-interface", name = "lp-player-dome",
    icon = "__base__/graphics/icons/energy-shield-mk2-equipment.png", icon_size = 64,
    flags = {"placeable-player", "player-creation"},
    minable = {mining_time = 0.5, result = "lp-player-dome"}, max_health = 1200,
    collision_box = {{-1.2, -1.2}, {1.2, 1.2}}, selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    energy_source = {type = "electric", usage_priority = "secondary-input", buffer_capacity = string.format("%dJ", PD.draw * 2),
      input_flow_limit = string.format("%dW", PD.draw * 2), output_flow_limit = "0W"},
    energy_usage = string.format("%dW", PD.draw),
    animation = {layers = {tw("body"), tw("glow", {draw_as_glow = true, blend_mode = "additive"}), tw("shadow", {draw_as_shadow = true})}},
    radius_visualisation_specification = {sprite = {filename = "__core__/graphics/visualization-construction-radius.png",
      size = 12}, distance = PD.radius},
    gui_mode = "none"}
  data:extend({proj,
    {type = "item", name = "lp-player-dome", icon = proj.icon, icon_size = 64, subgroup = "defensive-structure",
      order = "z[lp-player-dome]", place_result = "lp-player-dome", stack_size = 10},
    {type = "recipe", name = "lp-player-dome", enabled = false, energy_required = 20,
      ingredients = {{type = "item", name = "energy-shield-mk2-equipment", amount = 2}, {type = "item", name = "processing-unit", amount = 20},
        {type = "item", name = "steel-plate", amount = 50}, {type = "item", name = "copper-cable", amount = 100}},
      results = {{type = "item", name = "lp-player-dome", amount = 1}}},
    {type = "technology", name = "lp-player-dome", icon = "__base__/graphics/technology/energy-shield-mk2-equipment.png",
      icon_size = 256, prerequisites = {"energy-shield-mk2-equipment", "military-4"},
      effects = {{type = "unlock-recipe", recipe = "lp-player-dome"}},
      unit = {count = 500, time = 60, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1},
        {"chemical-science-pack", 1}, {"military-science-pack", 1}, {"utility-science-pack", 1}}}}})
end

-- Roads (scripts/roads.lua; the user, 2026-10-18: "player constructed concrete surfaces that speed up army traversal"):
-- units walk at one speed whatever the floor (a spike: 33.8 tiles in 5 s on concrete, 33.9 on grass), so the floor's
-- bonus for the engineer is lent to the player's army by an invisible sticker, renewed while it walks on it.
for _, m in ipairs({13, 14, 15}) do
  data:extend({{type = "sticker", name = "lp-road-" .. m, hidden = true, duration_in_ticks = 45,
    target_movement_modifier = m / 10, flags = {"not-on-map"}}})
end

-- The supply depot (stage 2 of the army-logistics consult; the user: "Rearming and repairing seems like it could also be a
-- job done by logo bots"): a requester chest the player's robots, inserters or trains fill with ammunition; the player's
-- units within shared.SUPPLY_RANGE rearm from it (command.lua). Built from a requester chest with the logistic system
-- research: a cheaper requester before vanilla's would be a leak.
local depot = table.deepcopy(data.raw["logistic-container"]["requester-chest"])
depot.name = "lp-supply-depot"
-- Its own model (tools/blender/player_buildings.py supply_depot, sheet.py; 2026-11-20, in place of the requester chest
-- re-tinted green): a shell rack, slim two-part shells standing along its back and lying down its sides, vanilla magazines littered about, round an olive magazine whose robot hatch is the
-- requester's robot door, its two leaves opening over the door's 7 frames (vanilla's opened_duration and sound kept).
-- (Its icon: graphics/icons/lp-supply-depot.png, set by icons.lua with the others.)
depot.minable = {mining_time = 0.2, result = "lp-supply-depot"}
depot.max_health = 500
-- (2x2 since 0.2.469: the requester chest's 1x1 remnants and explosion replaced by vanilla's generic 2x2 ones.)
depot.corpse = "medium-remnants"
depot.dying_explosion = "medium-explosion"
depot.inventory_size = 32
depot.fast_replaceable_group = nil
depot.next_upgrade = nil
depot.localised_description = {"entity-description.lp-supply-depot", tostring(shared.SUPPLY_RANGE)}
do
  local S = SHEETS["player/supply-depot"]
  local function layer(file, extra)
    local l = {filename = "__landing-party__/graphics/player/supply-depot/" .. file .. ".png", priority = "extra-high",
      width = S.width, height = S.height, frame_count = S.frames, line_length = S.line_length, scale = 0.5, shift = S.shift}
    for k, v in pairs(extra or {}) do l[k] = v end
    return l
  end
  depot.robot_door.animation = {layers = {layer("body"), layer("shadow", {draw_as_shadow = true})}}
  -- Robots deliver at the hatch on the magazine's top (0.47 tiles up, 0.12 south of the centre: 0.35 up the screen).
  depot.robot_door.location_offset = {0, -0.35}
end
-- 2x2 (the user, 2026-11-20: 1x1 "unnecessarily tight"). What the requester carried for 1x1 goes or moves: its circuit
-- connector onto the magazine's front plate (0.3 east, 0.3 up, 0.49 south: 0.19 down the screen), its water reflection (a
-- chest's), its icon's draw scale (a chest's 0.7).
depot.collision_box = {{-0.9, -0.9}, {0.9, 0.9}}
depot.selection_box = {{-1, -1}, {1, 1}}
-- (The requester's own connector moved, not rebuilt: its builder is a global the globals lint refuses.)
do
  local M, SH = {0.21, 0.0}, {0.21, 0.04}   -- from the chest's main offset (0.09, 0.19 with its LEDs) to the plate
  local function move(v, d) if v then v[1], v[2] = v[1] + d[1], v[2] + d[2] end end
  for _, c in ipairs(depot.circuit_connector or {}) do
    for k, sp in pairs(c.sprites or {}) do
      if k == "blue_led_light_offset" or k == "red_green_led_light_offset" then move(sp, M)
      elseif type(sp) == "table" and sp.shift then move(sp.shift, sp.draw_as_shadow and SH or M) end
    end
    for _, col in ipairs({"red", "green"}) do
      move(c.points and c.points.wire and c.points.wire[col], M)
      move(c.points and c.points.shadow and c.points.shadow[col], SH)
    end
  end
end
depot.water_reflection = nil
depot.icon_draw_specification = nil

local function item(name, icon, place)
  return {type = "item", name = name, icon = icon, stack_size = 10, place_result = place, subgroup = "defensive-structure",
    order = "z[landing-party]-" .. name}
end

data:extend({
  barracks, beacon, relay, scanner, muster, depot,
  (function()
    local it = item("lp-supply-depot", "__landing-party__/graphics/icons/lp-supply-depot.png", "lp-supply-depot")
    it.localised_description = depot.localised_description
    return it
  end)(),
  {type = "recipe", name = "lp-supply-depot", enabled = false, energy_required = 2,
    ingredients = {{type = "item", name = "requester-chest", amount = 1}, {type = "item", name = "steel-plate", amount = 10}},
    results = {{type = "item", name = "lp-supply-depot", amount = 1}}},
  (function() local it = item("lp-muster-point", "__base__/graphics/icons/steel-chest.png", "lp-muster-point"); it.hidden = true; return it end)(),
  {type = "recipe", name = "lp-muster-point", enabled = false, hidden = true, energy_required = 5,
    ingredients = {{type = "item", name = "steel-chest", amount = 1}, {type = "item", name = "radar", amount = 1},
      {type = "item", name = "electronic-circuit", amount = 10}},
    results = {{type = "item", name = "lp-muster-point", amount = 1}}},
  (function()
    local it = item("lp-threat-scanner", "__base__/graphics/icons/radar.png", "lp-threat-scanner")
    it.localised_description = scanner.localised_description
    return it
  end)(),
  {type = "recipe", name = "lp-threat-scanner", enabled = false, energy_required = 5,
    ingredients = {{type = "item", name = "radar", amount = 1}, {type = "item", name = "constant-combinator", amount = 1},
      {type = "item", name = "electronic-circuit", amount = 10}},
    results = {{type = "item", name = "lp-threat-scanner", amount = 1}}},
  (function()
    local it = item("lp-command-relay", "__base__/graphics/icons/radar.png", "lp-command-relay")
    it.localised_description = relay.localised_description
    return it
  end)(),
  -- Salvaged from the faction (a depot destroyed, a lander destroyed, the survey party) or granted once by
  -- research: what a barracks is built around. Not craftable.
  {type = "item", name = "lp-command-core", icon = "__base__/graphics/icons/processing-unit.png", stack_size = 10,
    subgroup = "intermediate-product", order = "z[landing-party]-core"},
  {type = "recipe-category", name = "lp-training"},
  (function()
    local it = item("lp-barracks", "__base__/graphics/icons/assembling-machine-2.png", "lp-barracks")
    it.localised_description = barracks.localised_description
    return it
  end)(),
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
  {type = "recipe", name = "lp-trooper-order", categories = {"lp-training"}, enabled = false, hidden_in_factoriopedia = true,
    -- 40 s a trooper: even at the cap, a lost army takes time to replace.
    energy_required = 40,
    ingredients = {{type = "item", name = "heavy-armor", amount = 1}, {type = "item", name = "submachine-gun", amount = 1},
      {type = "item", name = "firearm-magazine", amount = 10}},
    results = {{type = "item", name = "lp-trooper-order", amount = 1}}},
  {type = "item", name = "lp-breacher-order", icon = "__base__/graphics/icons/grenade.png", hidden = true,
    stack_size = 10, subgroup = "other"},
  {type = "recipe", name = "lp-breacher-order", categories = {"lp-training"}, enabled = false, hidden_in_factoriopedia = true,
    icon = "__base__/graphics/icons/grenade.png", energy_required = 40,
    ingredients = {{type = "item", name = "heavy-armor", amount = 1}, {type = "item", name = "grenade", amount = 10},
      {type = "item", name = "electronic-circuit", amount = 5}},
    results = {{type = "item", name = "lp-breacher-order", amount = 1}}},
  {type = "item", name = "lp-rocket-trooper-order", icon = "__base__/graphics/icons/rocket-launcher.png", hidden = true,
    stack_size = 10, subgroup = "other"},
  -- Rocket troopers (the RTS pass, 2026-10-21): heavy armour, a rocket launcher and rockets; with the second level.
  {type = "recipe", name = "lp-rocket-trooper-order", categories = {"lp-training"}, enabled = false, hidden_in_factoriopedia = true,
    icon = "__base__/graphics/icons/rocket-launcher.png", energy_required = 53,
    ingredients = {{type = "item", name = "heavy-armor", amount = 1}, {type = "item", name = "rocket-launcher", amount = 1},
      {type = "item", name = "rocket", amount = 10}},
    results = {{type = "item", name = "lp-rocket-trooper-order", amount = 1}}},
  {type = "item", name = "lp-flame-trooper-order", icon = "__base__/graphics/icons/flamethrower.png", hidden = true,
    stack_size = 10, subgroup = "other"},
  -- Flamethrower troopers (2026-10-24): heavy armour, a flamethrower and its fuel; with the third level.
  {type = "recipe", name = "lp-flame-trooper-order", categories = {"lp-training"}, enabled = false, hidden_in_factoriopedia = true,
    icon = "__base__/graphics/icons/flamethrower.png", energy_required = 53,
    ingredients = {{type = "item", name = "heavy-armor", amount = 1}, {type = "item", name = "flamethrower", amount = 1},
      {type = "item", name = "flamethrower-ammo", amount = 10}},
    results = {{type = "item", name = "lp-flame-trooper-order", amount = 1}}},
  -- Gun buggies (0.2.438): a car, piercing rounds for its heavy machine gun, a battery; with the second level.
  {type = "item", name = "lp-gun-buggy-order", icon = "__base__/graphics/icons/car.png", hidden = true,
    stack_size = 10, subgroup = "other"},
  {type = "recipe", name = "lp-gun-buggy-order", categories = {"lp-training"}, enabled = false, hidden_in_factoriopedia = true,
    icon = "__base__/graphics/icons/car.png", energy_required = 80,
    ingredients = {{type = "item", name = "car", amount = 1}, {type = "item", name = "piercing-rounds-magazine", amount = 20},
      {type = "item", name = "battery-equipment", amount = 1}},
    results = {{type = "item", name = "lp-gun-buggy-order", amount = 1}}},
  {type = "item", name = "lp-battle-tank-order", icon = "__base__/graphics/icons/tank.png", hidden = true,
    stack_size = 10, subgroup = "other"},
  {type = "recipe", name = "lp-battle-tank-order", categories = {"lp-training"}, enabled = false, hidden_in_factoriopedia = true,
    icon = "__base__/graphics/icons/tank.png", energy_required = 160,
    -- (An exoskeleton and two energy shields since 0.2.438, the user: "I think the tank def needs more cost": per point of
    -- command bandwidth the cheapest unit, about 165 plates against a trooper's 425, and the strongest.)
    ingredients = {{type = "item", name = "tank", amount = 1}, {type = "item", name = "cannon-shell", amount = 20},
      {type = "item", name = "battery-equipment", amount = 2}, {type = "item", name = "exoskeleton-equipment", amount = 1},
      {type = "item", name = "energy-shield-equipment", amount = 2}},
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
  -- Retire the selection (scripts/command.lua: home to a barracks, its order again).
  {type = "custom-input", name = "lp-retire", key_sequence = "ALT + R", consuming = "game-only"},
})
-- Control groups (scripts/cards.lua): CONTROL + N keeps the selection as group N, ALT + N selects it again.
for n = 1, 9 do
  data:extend{
    {type = "custom-input", name = "lp-group-keep-" .. n, key_sequence = "CONTROL + " .. n, consuming = "none", order = "b[group]-a" .. n},
    {type = "custom-input", name = "lp-group-" .. n, key_sequence = "ALT + " .. n, consuming = "none", order = "b[group]-b" .. n}}
end
-- The selection cards' health bars (scripts/cards.lua): vanilla's health bar, a card wide and thin.
data.raw["gui-style"].default.lp_card_hp_bar = {type = "progressbar_style", parent = "health_progressbar", width = 40,
  bar_width = 5, top_padding = 0, bottom_padding = 0}

-- Command bandwidth: how many relays count. Level 1 unlocks the army and grants the first command core.
local function tech(level, prereq, packs, count, effects, extra)
  local t = {type = "technology", name = "lp-command-bandwidth-" .. level, icon = "__base__/graphics/technology/radar.png",
    icon_size = 256, prerequisites = prereq, effects = effects or {},
    unit = {count = count, time = 30, ingredients = packs}, upgrade = level > 1}
  -- What a level gives, in numbers (the user, playtest: "a little unclear in game how much max pop a level of bandwidth
  -- gives"): its relays that count and the units they carry; the endless level, what each level adds.
  if level <= 3 then
    local n = shared.RELAYS_BY_LEVEL[level]
    t.localised_description = {"technology-description.lp-command-bandwidth-level", tostring(n), tostring(n * shared.RELAY_CAPACITY)}
  else
    local n = shared.RELAYS_PER_EXTRA_LEVEL
    t.localised_description = {"technology-description.lp-command-bandwidth-more", tostring(n), tostring(n * shared.RELAY_CAPACITY)}
  end
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end
local red, green = {"automation-science-pack", 1}, {"logistic-science-pack", 1}
local blue, grey = {"chemical-science-pack", 1}, {"military-science-pack", 1}
data:extend({
  tech(1, {"military-2", "heavy-armor"}, {red, green}, 100, {
    {type = "unlock-recipe", recipe = "lp-barracks"}, {type = "unlock-recipe", recipe = "lp-command-relay"},
    {type = "unlock-recipe", recipe = "lp-rally-beacon"}, {type = "unlock-recipe", recipe = "lp-trooper-order"},
    {type = "unlock-recipe", recipe = "lp-breacher-order"}, {type = "unlock-recipe", recipe = "lp-threat-scanner"},
    {type = "give-item", item = "lp-command-core", count = 1}}),
  -- Gun buggies and rocket troopers with the second level, once the player has cars, piercing rounds and rocket launchers.
  tech(2, {"lp-command-bandwidth-1", "chemical-science-pack", "automobilism", "battery-equipment", "rocketry"}, {red, green, blue},
    200, {{type = "unlock-recipe", recipe = "lp-gun-buggy-order"}, {type = "unlock-recipe", recipe = "lp-rocket-trooper-order"}}),
  -- Battle tanks (since 0.2.438: an exoskeleton in each) and flamethrower troopers with the third.
  tech(3, {"lp-command-bandwidth-2", "military-3", "flamethrower", "tank", "exoskeleton-equipment", "energy-shield-equipment"},
    {red, green, blue, grey}, 300, {{type = "unlock-recipe", recipe = "lp-battle-tank-order"},
    {type = "unlock-recipe", recipe = "lp-flame-trooper-order"}}),
  tech(4, {"lp-command-bandwidth-3"}, {red, green, blue, grey}, nil, nil,
    {max_level = "infinite", unit = {count_formula = "150*L", time = 30, ingredients = {red, green, blue, grey}}}),
})

-- Prizes (docs/reviews/2026-10-13-headquarters-consult.md): a corporation whose headquarters falls leaves the player
-- one recipe, unlocked by a hidden technology the fall marks researched. Serenity: its mortar (and shells), the
-- wall's own weapon. Grubstake: its strip drill, twice an electric drill's speed at half the ore drain.
local mortar = table.deepcopy(data.raw["artillery-turret"]["lp-mortar"])
mortar.name = "lp-player-mortar"
mortar.allow_run_time_change_of_is_military_target = false
mortar.flags = {"placeable-neutral", "placeable-player", "player-creation"}
mortar.minable = {mining_time = 0.5, result = "lp-player-mortar"}
mortar.hidden = false
mortar.loot = nil
data.raw.ammo["lp-mortar-shell"].hidden = false
data.raw.ammo["lp-mortar-shell"].subgroup = "ammo"
local strip = table.deepcopy(data.raw["mining-drill"]["electric-mining-drill"])
strip.name = "lp-strip-drill"
strip.minable = {mining_time = 0.5, result = "lp-strip-drill"}
strip.mining_speed = 1
strip.resource_drain_rate_percent = 50
strip.next_upgrade = nil
strip.fast_replaceable_group = nil
-- Its own model (tools/blender/turning_buildings.py): Grubstake's open gantry, its drill head turning while it mines, four
-- directions; vanilla's wet-mining look (its own model's) gone with it.
do
  local function anim(d, part, extra)
    local S = SHEETS["player/strip-drill/" .. d]
    local l = {filename = "__landing-party__/graphics/player/strip-drill/" .. d .. "/" .. part .. ".png", width = S.width,
      height = S.height, frame_count = S.frames, line_length = S.line_length, scale = 0.5, shift = S.shift, animation_speed = 0.5}
    for k, v in pairs(extra or {}) do l[k] = v end
    return l
  end
  local a = {}
  for _, d in ipairs({"north", "east", "south", "west"}) do
    a[d] = {layers = {anim(d, "body"), anim(d, "glow", {draw_as_glow = true, blend_mode = "additive"}),
      anim(d, "shadow", {draw_as_shadow = true})}}
  end
  strip.graphics_set = {animation = a}
  strip.wet_mining_graphics_set = nil
end
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
    ingredients = {{type = "item", name = "steel-plate", amount = 20}, {type = "item", name = "explosives", amount = 10},
      {type = "item", name = "electronic-circuit", amount = 10}},
    results = {{type = "item", name = "lp-player-mortar", amount = 1}}},
  {type = "recipe", name = "lp-mortar-shell", enabled = false, energy_required = 4,
    ingredients = {{type = "item", name = "steel-plate", amount = 1}, {type = "item", name = "explosives", amount = 2}},
    results = {{type = "item", name = "lp-mortar-shell", amount = 1}}},
  {type = "recipe", name = "lp-strip-drill", enabled = false, energy_required = 4,
    ingredients = {{type = "item", name = "electric-mining-drill", amount = 1}, {type = "item", name = "steel-plate", amount = 10},
      {type = "item", name = "electronic-circuit", amount = 5}, {type = "item", name = "lp-drill-head", amount = 1}},
    results = {{type = "item", name = "lp-strip-drill", amount = 1}}},
  prize("serenity", {"lp-player-mortar", "lp-mortar-shell"}),
  prize("grubstake", {"lp-strip-drill"}),
})

-- The army against biters (the user, playtest: "my 40 unit army could not clear a 3 nest vanilla biter base"; scenario
-- nestclear: 40 units at three nests, evolution 0.49). Infantry trained from an armour take its acid resistance: acid
-- is the biters' and Synthexis's alone (no corporation deals it), half the damage the army took at the nests. Its other
-- resistances not: heavy armour's 6 flat physical and 20 explosion cancel the corporations' rifles, turrets and shells.
-- Vehicles none (spitters' acid stays the answer to a hull, biotech.lua). And each unit names the research that raises
-- its damage and rate of fire (the engine applies the force's ammo damage and gun speed modifiers of its attack's ammo
-- category: techprobe, +100% each, a trooper 24 a second to 96), read from the technologies' own effects.
local function unit_proto(name) return data.raw.unit[name] or data.raw.car[name] end
local by_category = {}
for _, t in pairs(data.raw.technology) do
  if not t.hidden then
    for _, e in ipairs(t.effects or {}) do
      if (e.type == "ammo-damage" or e.type == "gun-speed") and e.ammo_category then
        local base = t.name:gsub("%-%d+$", "")
        by_category[e.ammo_category] = by_category[e.ammo_category] or {}
        by_category[e.ammo_category][base] = true
      end
    end
  end
end
for item, unit in pairs(shared.ORDERS) do
  local u, r = unit_proto(unit), data.raw.recipe[item]
  if u and r then
    for _, ing in ipairs(r.ingredients) do
      local armor = data.raw.armor[ing.name]
      if armor and data.raw.unit[unit] then
        for _, res in ipairs(armor.resistances or {}) do
          if res.type == "acid" then
            u.resistances = u.resistances or {}
            table.insert(u.resistances, {type = "acid", decrease = res.decrease, percent = res.percent})
          end
        end
      end
    end
    local cat = u.attack_parameters and u.attack_parameters.ammo_category
    local techs = {}
    for base in pairs(by_category[cat] or {}) do techs[#techs + 1] = base end
    table.sort(techs)
    if #techs > 0 then
      local list = {""}
      for k, base in ipairs(techs) do
        if k > 1 then list[#list + 1] = ", " end
        list[#list + 1] = {"technology-name." .. base}
      end
      u.localised_description = {"lp.upgraded-by", list}
    end
  end
end

-- (The supply depot with the logistic system, beside vanilla's requester chest; above.)
do
  local ls = data.raw.technology["logistic-system"]
  if ls then
    ls.effects = ls.effects or {}
    table.insert(ls.effects, {type = "unlock-recipe", recipe = "lp-supply-depot"})
  end
end
