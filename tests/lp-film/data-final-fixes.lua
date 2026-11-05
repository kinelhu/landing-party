-- The game's status icons drawn over entities in the world (no power, no ammo, a ghost's "no robots" and "too far from a
-- roboport", destroyed, ...), blanked for the film helper only (the user, 2026-11-05: "could we generally avoid showing
-- the yellow UI icons over destroyed player buildings in the trailer?"). take_screenshot has no switch for them.
local sprites = data.raw["utility-sprites"].default
for _, name in ipairs({"ammo_icon", "danger_icon", "destroyed_icon", "electricity_icon", "electricity_icon_unplugged",
    "fuel_icon", "fluid_icon", "frozen_icon", "lightning_warning_icon", "no_building_material_icon", "no_path_icon",
    "no_storage_space_icon", "not_enough_construction_robots_icon", "not_enough_repair_packs_icon", "recharge_icon",
    "too_far_from_roboport_icon", "warning_icon", "destination_full_icon", "resources_depleted_icon",
    "pipeline_disabled_icon"}) do
  if sprites[name] then
    sprites[name] = {filename = "__core__/graphics/empty.png", priority = "extra-high-no-scale", width = 1, height = 1,
      flags = {"icon"}}
  end
end
