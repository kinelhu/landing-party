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
-- and the player's units are units too: only the enemy's (not named lp-), and the biotech's (bred, and its pens).
local defaults = data.raw["utility-constants"].default.default_trigger_target_mask_by_type or {}
for _, type in ipairs({"unit", "unit-spawner", "turret"}) do
  for name, p in pairs(data.raw[type] or {}) do
    if name:sub(1, 3) ~= "lp-" or name:sub(1, 8) == "lp-bred-" or name == "lp-pen" then
      local mask = table.deepcopy(p.trigger_target_mask or defaults[type] or {"common"})
      table.insert(mask, "lp-biter")
      p.trigger_target_mask = mask
    end
  end
end
-- And Synthexis's tumors (creep.lua): the railgunner's full shot is for what grows biters.
do
  local t = data.raw["simple-entity-with-force"]["lp-tumor"]
  local mask = table.deepcopy(t.trigger_target_mask or defaults["simple-entity-with-force"] or {"common"})
  table.insert(mask, "lp-biter")
  t.trigger_target_mask = mask
end


require("air")
