-- Orbital cannons (DESIGN.md, "Orbital cannons"; the user, 2026-11-10: "the player has to build actual orbital cannons on
-- a space platform above Nauvis ... build up readiness like a rocket silo"): the cannon, its shell, its targeting array,
-- the remote and the technology. Platform only (gravity 0, Space Age's crusher's rule). A cannon is a crafting machine
-- whose one recipe makes a charge from a shell and thruster fuel; at shared.CANNON.STORE charges the script stops it (the
-- silo's rhythm: no spam). (Not by its output's stack size: a crafting machine starts its next craft with its output
-- full, finishes it and holds it, and a strike's charge taken let it fall in at once: three stored, scenario cannon.) scripts/cannon.lua spends the charges of every cannon over Nauvis on a
-- strike. Graphics provisional (the assembling machine 3 and the radar, tinted) until the cannon's model is rendered.
local shared = require("shared")
local util = require("util")
local SHEETS = require("graphics.sheets")
-- A rendered sheet's layer (tools/blender/orbital_cannon.py, targeting_array.py; the barracks' way, player.lua).
local function layer(key, file, speed, extra)
  local S = SHEETS[key]
  local l = {filename = "__landing-party__/graphics/" .. key .. "/" .. file .. ".png", width = S.width, height = S.height,
    frame_count = S.frames, line_length = S.line_length, scale = 0.5, shift = S.shift, animation_speed = speed}
  for k, v in pairs(extra or {}) do l[k] = v end
  return l
end
local C = shared.CANNON
local TINT = {r = 0.75, g = 0.85, b = 1, a = 1}
local SPACE = {{property = "gravity", min = 0, max = 0}}

data:extend({{type = "recipe-category", name = "lp-orbital"}})

-- The charge: what a strike spends, kept in the cannon's output (never meant to leave it).
data:extend({
  {type = "item", name = "lp-orbital-charge", icon = "__base__/graphics/icons/artillery-shell.png", icon_size = 64,
    hidden = true, stack_size = 10, subgroup = "lp-components", order = "z-charge"},
  {type = "recipe", name = "lp-orbital-charge", categories = {"lp-orbital"}, hidden = true, enabled = true,
    energy_required = C.CYCLE, hide_from_player_crafting = true,
    ingredients = {{type = "item", name = "lp-orbital-shell", amount = 1},
      {type = "fluid", name = "thruster-fuel", amount = C.FUEL}, {type = "fluid", name = "thruster-oxidizer", amount = C.OXIDIZER}},
    results = {{type = "item", name = "lp-orbital-charge", amount = 1}}},
})

-- The shell (0.2.346; the user: shells "made in foundries or EM plants", on the ground): cast in a foundry on a planet
-- (gravity: not aloft) from molten iron, round a tungsten carbide penetrator (Vulcanus's) and explosives, its fuse an
-- electromagnetic plant's (Fulgora's supercapacitor); SHELL_KG, four a rocket: the silo is the cannons' supply line. (Made
-- aloft until then from 4 tungsten carbide, 10 explosives and 5 steel: 40 kg, a rocket an hour and a quarter a cannon.)
local GROUND = {{property = "gravity", min = 1}}
data:extend({
  {type = "item", name = "lp-orbital-shell", icons = {{icon = "__base__/graphics/icons/artillery-shell.png", tint = TINT}},
    stack_size = 10, weight = C.SHELL_KG * 1000, subgroup = "lp-components", order = "y-orbital-a"},
  {type = "item", name = "lp-orbital-fuse", icons = {{icon = "__space-age__/graphics/icons/supercapacitor.png", tint = TINT}},
    stack_size = 20, subgroup = "lp-components", order = "y-orbital-b"},
  {type = "recipe", name = "lp-orbital-fuse", enabled = false, categories = {"electromagnetics"}, energy_required = 20,
    ingredients = {{type = "item", name = "supercapacitor", amount = 1}, {type = "item", name = "processing-unit", amount = 2}},
    results = {{type = "item", name = "lp-orbital-fuse", amount = 1}}},
  {type = "recipe", name = "lp-orbital-shell", enabled = false, categories = {"metallurgy"}, energy_required = 30,
    surface_conditions = GROUND,
    ingredients = {{type = "fluid", name = "molten-iron", amount = 300}, {type = "item", name = "tungsten-carbide", amount = 10},
      {type = "item", name = "explosives", amount = 20}, {type = "item", name = "lp-orbital-fuse", amount = 1}},
    results = {{type = "item", name = "lp-orbital-shell", amount = 1}}},
})

-- The cannon: the assembling machine 3's body, fixed to its charge, platform only. Big (the user, 2026-11-10: "structures
-- you build on the side of a platform, pointing down? Something big is needed"): 12 by 18 on the deck at its edge, its
-- barrel out over the void (tools/blender/orbital_cannon.py), built only where the void is ahead of it (the asteroid
-- collector's and the thruster's rule: tile_buildability_rules). Its direction is the barrel's.
local cannon = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
cannon.name = "lp-orbital-cannon"
cannon.icons = {{icon = "__base__/graphics/icons/artillery-turret.png", tint = TINT}}
cannon.icon = nil
cannon.minable = {mining_time = 1, result = "lp-orbital-cannon"}
cannon.crafting_categories = {"lp-orbital"}
cannon.fixed_recipe = "lp-orbital-charge"
cannon.crafting_speed = 1
cannon.module_slots = 0
cannon.allowed_effects = {}
cannon.surface_conditions = SPACE
cannon.next_upgrade = nil
cannon.fast_replaceable_group = nil
cannon.max_health = 3000
cannon.energy_usage = C.POWER
cannon.disabled_when_recipe_not_researched = false
-- Its own body, a set a direction (cannon_sheets.py: the body and shadow one frame, the glow at half size, its coils lit in
-- turn while it charges).
local DIRS = SHEETS["player/orbital-cannon"]
local function dir_file(d, part) return "__landing-party__/graphics/player/orbital-cannon/" .. d .. "-" .. part .. ".png" end
local function still(d)
  local S = DIRS[d]
  return {layers = {
    {filename = dir_file(d, "body"), width = S.width, height = S.height, frame_count = 1, scale = 0.5, shift = S.shift},
    {filename = dir_file(d, "shadow"), width = S.width, height = S.height, frame_count = 1, scale = 0.5, shift = S.shift,
      draw_as_shadow = true}}}
end
local function glowing(d)
  local S = DIRS[d]
  return {filename = dir_file(d, "glow"), width = S.width / 2, height = S.height / 2, frame_count = S.frames,
    line_length = S.line_length, scale = 1, shift = S.shift, animation_speed = 0.2, draw_as_glow = true, blend_mode = "additive"}
end
-- Its barrel, apart (the user, 2026-11-10: "No firing animation? no recoil?"): a sprite a direction, drawn over the body by
-- scripts/cannon.lua and slid back along its axis as it fires.
for d, S in pairs(DIRS) do
  local B = S.barrel
  if B then
    data:extend({{type = "sprite", name = "lp-cannon-barrel-" .. d, filename = dir_file(d, "barrel"), width = B.width,
      height = B.height, scale = 0.5, shift = B.shift, flags = {"no-crop"}}})
  end
end
-- Its shot on the platform: the big explosion at the muzzle, the deck shaken (the strike's shock, lighter, no scorch).
local blast = table.deepcopy(data.raw.explosion["big-artillery-explosion"])
blast.name = "lp-cannon-blast"
blast.created_effect = {type = "direct", action_delivery = {type = "instant", source_effects = {
  {type = "camera-effect", duration = 18, ease_in_duration = 1, ease_out_duration = 17, strength = 1.4,
    full_strength_max_distance = 30, max_distance = 120}}}}
data:extend({blast})
-- Its fans, spinning while it works: a small sheet laid over the body's own.
local function fans(d)
  local F = DIRS[d].fans
  return {filename = dir_file(d, "fans"), width = F.width, height = F.height, frame_count = F.frames, line_length = 4,
    scale = 0.5, shift = F.shift, animation_speed = 0.5}
end
cannon.graphics_set = {animation = {north = still("north"), east = still("east"), south = still("south"), west = still("west")},
  working_visualisations = {
    {north_animation = fans("north"), east_animation = fans("east"), south_animation = fans("south"), west_animation = fans("west")},
    {north_animation = glowing("north"), east_animation = glowing("east"),
      south_animation = glowing("south"), west_animation = glowing("west"),
      light = {intensity = 0.6, size = 24, color = {r = 0.45, g = 0.85, b = 1}}}}}
cannon.graphics_set_flipped = nil
cannon.collision_box = {{-5.9, -8.9}, {5.9, 8.9}}
cannon.selection_box = {{-6, -9}, {6, 9}}
-- On the deck, and the void ahead of its muzzle's side, its barrel's width, as far as it reaches.
cannon.tile_buildability_rules = {
  {area = {{-5.9, -8.9}, {5.9, 8.9}}, required_tiles = {layers = {ground_tile = true}}, colliding_tiles = {layers = {empty_space = true}},
    remove_on_collision = true},
  {area = {{-2.9, -8.9 - C.REACH}, {2.9, -9.1}}, required_tiles = {layers = {empty_space = true}}, remove_on_collision = true},
}
-- Its thruster fuel and oxidizer from behind (the side away from the void): the fuel on the left, the oxidizer on the
-- right (0.2.346; fuel alone until then, both inputs one box).
local fb = table.deepcopy(cannon.fluid_boxes[1])
fb.production_type = "input"
fb.volume = math.max(C.FUEL, C.OXIDIZER) * 3   -- (room for a third charge's: a craft begun past the store holds)
fb.filter = "thruster-fuel"
fb.pipe_connections = {{flow_direction = "input", direction = defines.direction.south, position = {-4.5, 8.5}}}
local ob = table.deepcopy(fb)
ob.filter = "thruster-oxidizer"
ob.pipe_connections = {{flow_direction = "input", direction = defines.direction.south, position = {4.5, 8.5}}}
cannon.fluid_boxes = {fb, ob}
cannon.fluid_boxes_off_when_no_fluid_recipe = false
cannon.icon_draw_specification = {shift = {0, 1.5}, scale = 2}
cannon.localised_description = {"entity-description.lp-orbital-cannon", tostring(C.STORE), tostring(math.floor(C.CYCLE / 60))}
data:extend({cannon,
  {type = "item", name = "lp-orbital-cannon", icons = cannon.icons, place_result = "lp-orbital-cannon", stack_size = 1,
    weight = 1000000, subgroup = "lp-components", order = "y-orbital-b",
    localised_description = cannon.localised_description},
  {type = "recipe", name = "lp-orbital-cannon", enabled = false, energy_required = 120,
    ingredients = {{type = "item", name = "artillery-turret", amount = 2}, {type = "item", name = "processing-unit", amount = 100},
      {type = "item", name = "low-density-structure", amount = 100}, {type = "item", name = "electric-engine-unit", amount = 50},
      {type = "item", name = "tungsten-plate", amount = 50}, {type = "item", name = "steel-plate", amount = 400}},
    results = {{type = "item", name = "lp-orbital-cannon", amount = 1}}},
})

-- The strike's sound and weight (the user: "Do the orbital cannons scream super weapon to you?"): the railgun's charge as its
-- warning on the ground and its shot on the platform; each shell a shock felt on screen (the nuke's camera effect, much
-- less), the artillery's big explosion and a huge scorch.
data:extend({
  {type = "sound", name = "lp-cannon-charge", filename = "__space-age__/sound/entity/railgun-turret/railgun-turret-activate-1.ogg",
    volume = 1, audible_distance_modifier = 4},
  {type = "sound", name = "lp-cannon-fire", variations = {
    {filename = "__space-age__/sound/entity/railgun-turret/railgun-turret-gunshot-1.ogg", volume = 1},
    {filename = "__space-age__/sound/entity/railgun-turret/railgun-turret-gunshot-2.ogg", volume = 1},
    {filename = "__space-age__/sound/entity/railgun-turret/railgun-turret-gunshot-3.ogg", volume = 1}},
    audible_distance_modifier = 4},
})
local shock = table.deepcopy(data.raw.explosion["big-artillery-explosion"])
shock.name = "lp-cannon-shock"
shock.created_effect = {type = "direct", action_delivery = {type = "instant", source_effects = {
  {type = "camera-effect", duration = 24, ease_in_duration = 2, ease_out_duration = 22, strength = 2.2,
    full_strength_max_distance = 40, max_distance = 220},
  {type = "create-entity", entity_name = "huge-scorchmark-tintable", check_buildability = true}}}}
data:extend({shock})
-- Its arcs while it charges: Space Age's Tesla lightning, harmless and silent (scripts/cannon.lua draws them between its
-- towers' terminals and its first coil's contact posts; drawn into the sprite they read as scribbles, the user).
local arc = table.deepcopy(data.raw.beam["chain-tesla-turret-beam-start"])
arc.name = "lp-cannon-arc"
arc.action = nil
arc.working_sound = nil
arc.damage_interval = 1e6
data:extend({arc})

-- The targeting array: one a platform; Kessler-Hayashi's salvaged orbital beacon in it, or a targeting core made of
-- space science (a game without Kessler-Hayashi).
data:extend({
  {type = "simple-entity-with-owner", name = "lp-targeting-array", icons = {{icon = "__base__/graphics/icons/radar.png", tint = TINT}},
    flags = {"placeable-player", "player-creation"}, minable = {mining_time = 1, result = "lp-targeting-array"},
    max_health = 400, surface_conditions = SPACE, collision_box = {{-1.2, -1.2}, {1.2, 1.2}},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}}, dying_explosion = "medium-explosion",
    animations = {layers = {layer("player/targeting-array", "body", 0.15), layer("player/targeting-array", "glow", 0.15,
      {draw_as_glow = true, blend_mode = "additive"}), layer("player/targeting-array", "shadow", 0.15, {draw_as_shadow = true})}},
    localised_description = {"entity-description.lp-targeting-array"}},
  {type = "item", name = "lp-targeting-array", icons = {{icon = "__base__/graphics/icons/radar.png", tint = TINT}},
    place_result = "lp-targeting-array", stack_size = 5, weight = 500000, subgroup = "lp-components", order = "y-orbital-c"},
  {type = "recipe", name = "lp-targeting-array", enabled = false, energy_required = 20,
    ingredients = {{type = "item", name = "lp-orbital-beacon", amount = 1}, {type = "item", name = "processing-unit", amount = 10},
      {type = "item", name = "steel-plate", amount = 20}},
    results = {{type = "item", name = "lp-targeting-array", amount = 1}}},
  {type = "item", name = "lp-targeting-core", icons = {{icon = "__base__/graphics/icons/processing-unit.png", tint = TINT}},
    stack_size = 10, subgroup = "lp-components", order = "y-orbital-d"},
  {type = "recipe", name = "lp-targeting-core", enabled = false, energy_required = 60,
    ingredients = {{type = "item", name = "processing-unit", amount = 20}, {type = "item", name = "low-density-structure", amount = 10},
      {type = "item", name = "space-science-pack", amount = 50}},
    results = {{type = "item", name = "lp-targeting-core", amount = 1}}},
  {type = "recipe", name = "lp-targeting-array-core", enabled = false, energy_required = 20,
    ingredients = {{type = "item", name = "lp-targeting-core", amount = 1}, {type = "item", name = "steel-plate", amount = 20}},
    results = {{type = "item", name = "lp-targeting-array", amount = 1}},
    localised_name = {"recipe-name.lp-targeting-array-core"}},
})

-- The remote: a click on the map, as the artillery remote (a selection tool: the command tool's way, map view too).
data:extend({
  {type = "selection-tool", name = "lp-orbital-remote", icons = {{icon = "__base__/graphics/icons/artillery-targeting-remote.png",
    tint = TINT}}, flags = {"only-in-cursor", "not-stackable", "spawnable"}, hidden = true, stack_size = 1, subgroup = "other",
    select = {border_color = {0.55, 0.8, 1}, cursor_box_type = "copy", mode = {"any-tile"}},
    alt_select = {border_color = {0.55, 0.8, 1}, cursor_box_type = "copy", mode = {"any-tile"}}},
  {type = "shortcut", name = "lp-orbital-remote", order = "z[landing-party]-b", action = "spawn-item",
    item_to_spawn = "lp-orbital-remote", technology_to_unlock = "lp-orbital-cannon", unavailable_until_unlocked = true,
    icon = "__base__/graphics/icons/shortcut-toolbar/mip/artillery-targeting-remote-x56.png", icon_size = 56,
    small_icon = "__base__/graphics/icons/shortcut-toolbar/mip/artillery-targeting-remote-x24.png", small_icon_size = 24},
  {type = "custom-input", name = "lp-orbital-remote", key_sequence = "ALT + O", action = "spawn-item",
    item_to_spawn = "lp-orbital-remote", consuming = "game-only"},
})

-- The technology: after artillery and the space platform.
data:extend({
  {type = "technology", name = "lp-orbital-cannon", icon = "__base__/graphics/technology/artillery.png", icon_size = 256,
    prerequisites = {"artillery", "space-platform", "tungsten-carbide", "foundry", "electromagnetic-plant"},
    unit = {count = 1000, time = 60, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1},
      {"military-science-pack", 1}, {"chemical-science-pack", 1}, {"utility-science-pack", 1}, {"space-science-pack", 1}}},
    effects = {{type = "unlock-recipe", recipe = "lp-orbital-cannon"}, {type = "unlock-recipe", recipe = "lp-orbital-shell"},
      {type = "unlock-recipe", recipe = "lp-orbital-fuse"},
      {type = "unlock-recipe", recipe = "lp-targeting-array"}, {type = "unlock-recipe", recipe = "lp-targeting-core"},
      {type = "unlock-recipe", recipe = "lp-targeting-array-core"}},
    localised_description = {"technology-description.lp-orbital-cannon", tostring(C.R0), tostring(C.R_MAX)}},
})

-- The strike beacon retired (the cannons replace it): its technology and recipe hidden; a placed one fires as before.
if data.raw.technology["lp-orbital-strike"] then data.raw.technology["lp-orbital-strike"].hidden = true end
if data.raw.recipe["lp-strike-beacon"] then data.raw.recipe["lp-strike-beacon"].hidden = true end
-- And its beacon's teardown (crafting the schematic researched the retired technology): a salvaged beacon is the targeting
-- array's now, and the teardown would have used one up for nothing (the manual's review, 2026-11-10).
if data.raw.recipe["lp-beacon-schematic"] then
  data.raw.recipe["lp-beacon-schematic"].hidden = true
  data.raw.recipe["lp-beacon-schematic"].enabled = false
end
