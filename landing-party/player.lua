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

-- The rally beacon: a constant combinator. Its own signals give orders (opened like any combinator); wired, it
-- reads its network as well, for automation. A small lamp with a combinator wired to it once confused the
-- first player to try it.
local beacon = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
beacon.name = "lp-rally-beacon"
beacon.icon = "__base__/graphics/icons/small-lamp.png"
beacon.minable = {mining_time = 0.2, result = "lp-rally-beacon"}
beacon.next_upgrade = nil
beacon.fast_replaceable_group = nil

-- The threat scanner (scripts/scanner.lua; the user, 2026-10-18: "a building that scans for enemy units in a radius and
-- gives signals for each unit type"): a constant combinator the mod writes, a radar's icon; one virtual signal a role,
-- a total a corporation, the crews (builders, apart from the army) and the biters.
local scanner = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
scanner.name = "lp-threat-scanner"
scanner.icon = "__base__/graphics/icons/radar.png"
scanner.minable = {mining_time = 0.2, result = "lp-threat-scanner"}
scanner.localised_description = {"entity-description.lp-threat-scanner", tostring(shared.SCAN_RADIUS)}
scanner.next_upgrade = nil
scanner.fast_replaceable_group = nil
local signals = {}
local function signal(name, icon, tint, order)
  table.insert(signals, {type = "virtual-signal", name = name, icons = {{icon = icon, tint = tint}},
    subgroup = "virtual-signal", order = "z[landing-party]-" .. order})
end
local S_TINT, G_TINT = {r = 0.62, g = 0.8, b = 1, a = 1}, {r = 1, g = 0.75, b = 0.35, a = 1}
for k, g in ipairs(shared.SCAN_GROUPS) do signal(g.signal, g.icon, {r = 1, g = 0.45, b = 0.4, a = 1}, string.format("a%02d", k)) end
signal("lp-scan-crew", "__base__/graphics/icons/construction-robot.png", {r = 1, g = 0.45, b = 0.4, a = 1}, "b")
signal("lp-scan-serenity", "__base__/graphics/icons/signal/signal_S.png", S_TINT, "c")
signal("lp-scan-grubstake", "__base__/graphics/icons/signal/signal_G.png", G_TINT, "d")
signal("lp-scan-biters", "__base__/graphics/icons/small-biter.png", nil, "e")
signal("lp-scan-jammed", "__space-age__/graphics/icons/tesla-turret.png", S_TINT, "f")
-- With bred-biter telemetry (a field study, studies.lua): Synthexis's biters, and its scout.
signal("lp-scan-synthexis", "__base__/graphics/icons/small-biter.png", shared.BIOTECH.tint1, "g")
signal("lp-scan-scout", "__base__/graphics/icons/small-biter.png", shared.BIOTECH.tint2, "h")
-- A squad's size by unit, set on a rally beacon (scripts/command.lua): the order's icon, the army's green.
local SQUAD_ICON = {["lp-trooper"] = "__base__/graphics/icons/firearm-magazine.png", ["lp-breacher"] = "__base__/graphics/icons/grenade.png",
  ["lp-rocket-trooper"] = "__base__/graphics/icons/rocket-launcher.png", ["lp-flame-trooper"] = "__base__/graphics/icons/flamethrower.png",
  ["lp-battle-tank"] = "__base__/graphics/icons/tank.png"}
local SQUAD_ORDER = {["lp-trooper"] = "a", ["lp-breacher"] = "b", ["lp-rocket-trooper"] = "c", ["lp-flame-trooper"] = "d", ["lp-battle-tank"] = "e"}
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

local function item(name, icon, place)
  return {type = "item", name = name, icon = icon, stack_size = 10, place_result = place, subgroup = "defensive-structure",
    order = "z[landing-party]-" .. name}
end

data:extend({
  barracks, beacon, relay, scanner, muster,
  item("lp-muster-point", "__base__/graphics/icons/steel-chest.png", "lp-muster-point"),
  {type = "recipe", name = "lp-muster-point", enabled = false, energy_required = 5,
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
  {type = "recipe", name = "lp-trooper-order", categories = {"lp-training"}, enabled = false, hidden_in_factoriopedia = true,
    -- 30 s a trooper: even at the cap, a lost army takes time to replace.
    energy_required = 30,
    ingredients = {{type = "item", name = "heavy-armor", amount = 1}, {type = "item", name = "submachine-gun", amount = 1},
      {type = "item", name = "firearm-magazine", amount = 10}},
    results = {{type = "item", name = "lp-trooper-order", amount = 1}}},
  {type = "item", name = "lp-breacher-order", icon = "__base__/graphics/icons/grenade.png", hidden = true,
    stack_size = 10, subgroup = "other"},
  {type = "recipe", name = "lp-breacher-order", categories = {"lp-training"}, enabled = false, hidden_in_factoriopedia = true,
    icon = "__base__/graphics/icons/grenade.png", energy_required = 30,
    ingredients = {{type = "item", name = "heavy-armor", amount = 1}, {type = "item", name = "grenade", amount = 10},
      {type = "item", name = "electronic-circuit", amount = 5}},
    results = {{type = "item", name = "lp-breacher-order", amount = 1}}},
  {type = "item", name = "lp-rocket-trooper-order", icon = "__base__/graphics/icons/rocket-launcher.png", hidden = true,
    stack_size = 10, subgroup = "other"},
  -- Rocket troopers (the RTS pass, 2026-10-21): heavy armour, a rocket launcher and rockets; with the second level.
  {type = "recipe", name = "lp-rocket-trooper-order", categories = {"lp-training"}, enabled = false, hidden_in_factoriopedia = true,
    icon = "__base__/graphics/icons/rocket-launcher.png", energy_required = 40,
    ingredients = {{type = "item", name = "heavy-armor", amount = 1}, {type = "item", name = "rocket-launcher", amount = 1},
      {type = "item", name = "rocket", amount = 10}},
    results = {{type = "item", name = "lp-rocket-trooper-order", amount = 1}}},
  {type = "item", name = "lp-flame-trooper-order", icon = "__base__/graphics/icons/flamethrower.png", hidden = true,
    stack_size = 10, subgroup = "other"},
  -- Flamethrower troopers (2026-10-24): heavy armour, a flamethrower and its fuel; with the third level.
  {type = "recipe", name = "lp-flame-trooper-order", categories = {"lp-training"}, enabled = false, hidden_in_factoriopedia = true,
    icon = "__base__/graphics/icons/flamethrower.png", energy_required = 40,
    ingredients = {{type = "item", name = "heavy-armor", amount = 1}, {type = "item", name = "flamethrower", amount = 1},
      {type = "item", name = "flamethrower-ammo", amount = 10}},
    results = {{type = "item", name = "lp-flame-trooper-order", amount = 1}}},
  {type = "item", name = "lp-battle-tank-order", icon = "__base__/graphics/icons/tank.png", hidden = true,
    stack_size = 10, subgroup = "other"},
  {type = "recipe", name = "lp-battle-tank-order", categories = {"lp-training"}, enabled = false, hidden_in_factoriopedia = true,
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
  -- Retire the selection (scripts/command.lua: home to a barracks, its order again).
  {type = "custom-input", name = "lp-retire", key_sequence = "ALT + R", consuming = "game-only"},
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
    {type = "unlock-recipe", recipe = "lp-breacher-order"}, {type = "unlock-recipe", recipe = "lp-threat-scanner"},
    {type = "unlock-recipe", recipe = "lp-muster-point"},
    {type = "give-item", item = "lp-command-core", count = 1}}),
  -- Battle tanks and rocket troopers with the second level, once the player has tanks and rocket launchers of their own.
  tech(2, {"lp-command-bandwidth-1", "chemical-science-pack", "tank", "battery-equipment", "rocketry"}, {red, green, blue}, 200, {
    {type = "unlock-recipe", recipe = "lp-battle-tank-order"}, {type = "unlock-recipe", recipe = "lp-rocket-trooper-order"}}),
  -- Flamethrower troopers with the third, once the player has flamethrowers.
  tech(3, {"lp-command-bandwidth-2", "military-3", "flamethrower"}, {red, green, blue, grey}, 300, {
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
