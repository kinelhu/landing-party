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
      {type = "fluid", name = "thruster-fuel", amount = C.FUEL}},
    results = {{type = "item", name = "lp-orbital-charge", amount = 1}}},
})

-- The shell: made in space only, of steel, explosives (sulfur shipped up) and low density structure.
data:extend({
  {type = "item", name = "lp-orbital-shell", icons = {{icon = "__base__/graphics/icons/artillery-shell.png", tint = TINT}},
    stack_size = 10, weight = 100000, subgroup = "lp-components", order = "y-orbital-a"},
  {type = "recipe", name = "lp-orbital-shell", enabled = false, energy_required = 30, surface_conditions = SPACE,
    ingredients = {{type = "item", name = "steel-plate", amount = 10}, {type = "item", name = "explosives", amount = 10},
      {type = "item", name = "low-density-structure", amount = 2}},
    results = {{type = "item", name = "lp-orbital-shell", amount = 1}}},
})

-- The cannon: the assembling machine 3's body, fixed to its charge, platform only.
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
cannon.max_health = 800
cannon.energy_usage = "1MW"
cannon.disabled_when_recipe_not_researched = false
-- Its own body (the cannon's model): the charge climbs its rings while it charges.
cannon.graphics_set = {animation = {layers = {layer("player/orbital-cannon", "body", 0.25),
  layer("player/orbital-cannon", "shadow", 0.25, {draw_as_shadow = true})}},
  working_visualisations = {{animation = layer("player/orbital-cannon", "glow", 0.25, {draw_as_glow = true, blend_mode = "additive"}),
    light = {intensity = 0.5, size = 8, color = {r = 0.45, g = 0.85, b = 1}}}}}
cannon.graphics_set_flipped = nil
cannon.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
cannon.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
cannon.localised_description = {"entity-description.lp-orbital-cannon", tostring(C.STORE), tostring(math.floor(C.CYCLE / 60))}
data:extend({cannon,
  {type = "item", name = "lp-orbital-cannon", icons = cannon.icons, place_result = "lp-orbital-cannon", stack_size = 5,
    weight = 1000000, subgroup = "lp-components", order = "y-orbital-b",
    localised_description = cannon.localised_description},
  {type = "recipe", name = "lp-orbital-cannon", enabled = false, energy_required = 30,
    ingredients = {{type = "item", name = "artillery-turret", amount = 1}, {type = "item", name = "processing-unit", amount = 20},
      {type = "item", name = "low-density-structure", amount = 20}, {type = "item", name = "steel-plate", amount = 50}},
    results = {{type = "item", name = "lp-orbital-cannon", amount = 1}}},
})

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
    prerequisites = {"artillery", "space-platform"},
    unit = {count = 1000, time = 60, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1},
      {"military-science-pack", 1}, {"chemical-science-pack", 1}, {"utility-science-pack", 1}, {"space-science-pack", 1}}},
    effects = {{type = "unlock-recipe", recipe = "lp-orbital-cannon"}, {type = "unlock-recipe", recipe = "lp-orbital-shell"},
      {type = "unlock-recipe", recipe = "lp-targeting-array"}, {type = "unlock-recipe", recipe = "lp-targeting-core"},
      {type = "unlock-recipe", recipe = "lp-targeting-array-core"}},
    localised_description = {"technology-description.lp-orbital-cannon", tostring(C.RADIUS)}},
})

-- The strike beacon retired (the cannons replace it): its technology and recipe hidden; a placed one fires as before.
if data.raw.technology["lp-orbital-strike"] then data.raw.technology["lp-orbital-strike"].hidden = true end
if data.raw.recipe["lp-strike-beacon"] then data.raw.recipe["lp-strike-beacon"].hidden = true end
