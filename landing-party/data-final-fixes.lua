-- Turrets that cannot shoot up ignore air units: flamethrowers (fluid turrets) and artillery. Gun and laser
-- turrets keep the default (they hit everything); a dedicated anti-air turret comes later.
for _, type in ipairs({"fluid-turret", "artillery-turret"}) do
  for _, t in pairs(data.raw[type] or {}) do
    local mask = t.ignore_target_mask or {}
    table.insert(mask, "lp-air-unit")
    t.ignore_target_mask = mask
  end
end


-- Biters, spawners and worms carry the lp-biter trigger target (the railgunner's full shot, units.lua). The faction's
-- and the player's units are units too: only the enemy's (not named lp-).
local defaults = data.raw["utility-constants"].default.default_trigger_target_mask_by_type or {}
for _, type in ipairs({"unit", "unit-spawner", "turret"}) do
  for name, p in pairs(data.raw[type] or {}) do
    if name:sub(1, 3) ~= "lp-" then
      local mask = table.deepcopy(p.trigger_target_mask or defaults[type] or {"common"})
      table.insert(mask, "lp-biter")
      p.trigger_target_mask = mask
    end
  end
end
