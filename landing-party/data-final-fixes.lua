-- Turrets that cannot shoot up ignore air units: flamethrowers (fluid turrets) and artillery. Gun and laser
-- turrets keep the default (they hit everything); a dedicated anti-air turret comes later.
for _, type in ipairs({"fluid-turret", "artillery-turret"}) do
  for _, t in pairs(data.raw[type] or {}) do
    local mask = t.ignore_target_mask or {}
    table.insert(mask, "lp-air-unit")
    t.ignore_target_mask = mask
  end
end

