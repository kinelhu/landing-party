-- Turrets that cannot shoot up ignore air units: flamethrowers (fluid turrets) and artillery. Gun and laser
-- turrets keep the default (they hit everything); a dedicated anti-air turret comes later.
for _, type in ipairs({"fluid-turret", "artillery-turret"}) do
  for _, t in pairs(data.raw[type] or {}) do
    local mask = t.ignore_target_mask or {}
    table.insert(mask, "lp-air-unit")
    t.ignore_target_mask = mask
  end
end


-- Spawners and worms carry the lp-nest trigger target (the railgunner's full shot, units.lua), biters on their feet
-- lp-biter (its lighter one: a nest stands still, a wave does not; at full damage on both a camp with railgunners was
-- proof against any wave, the user, 2026-10-25). The faction's and the player's units are units too: only the enemy's
-- (not named lp-), and the biotech's (bred, and its pens).
local defaults = data.raw["utility-constants"].default.default_trigger_target_mask_by_type or {}
for _, type in ipairs({"unit", "unit-spawner", "turret"}) do
  for name, p in pairs(data.raw[type] or {}) do
    if name:sub(1, 3) ~= "lp-" or name:sub(1, 8) == "lp-bred-" or name == "lp-pen" then
      local mask = table.deepcopy(p.trigger_target_mask or defaults[type] or {"common"})
      table.insert(mask, type == "unit" and "lp-biter" or "lp-nest")
      p.trigger_target_mask = mask
    end
  end
end
-- And Synthexis's tumors (creep.lua): the railgunner's full shot is for what grows biters.
do
  local t = data.raw["simple-entity-with-force"]["lp-tumor"]
  local mask = table.deepcopy(t.trigger_target_mask or defaults["simple-entity-with-force"] or {"common"})
  table.insert(mask, "lp-nest")
  t.trigger_target_mask = mask
end


-- What each unit's attack deals a second (lp-bites, read by threat.bite): the runtime reads no damage amounts (a
-- TriggerEffectItem there has no damage), and Synthexis prices a stay by how fast its herd breaks what it came for.
-- Its damage effects summed through deliveries, streams, projectiles and nested results, times repeats, over its cooldown.
do
  local function list(x) if x == nil then return {} end; if x[1] ~= nil or next(x) == nil then return x end; return {x} end
  local damage
  local function action(a, seen)
    local d = 0
    for _, item in ipairs(list(a)) do
      local n = item.repeat_count or 1
      for _, del in ipairs(list(item.action_delivery)) do
        for _, eff in ipairs(list(del.target_effects)) do d = d + n * damage(eff, seen) end
        local via = del.stream and data.raw.stream[del.stream] or del.projectile and data.raw.projectile[del.projectile]
        if via and not seen[via.name] then
          seen[via.name] = true
          d = d + n * (action(via.initial_action, seen) + action(via.action, seen) + action(via.final_action, seen))
        end
      end
    end
    return d
  end
  damage = function(eff, seen)
    local n = eff.repeat_count or 1
    if eff.type == "damage" and eff.damage then return n * (eff.damage.amount or 0) end
    if eff.type == "nested-result" then return n * action(eff.action, seen) end
    return 0
  end
  local bites = {}
  for name, u in pairs(data.raw.unit or {}) do
    local ap = u.attack_parameters
    local hit = ap and ap.ammo_type and action(ap.ammo_type.action, {}) * (ap.damage_modifier or 1)
    if hit and hit > 0 then bites[name] = hit * 60 / math.max(1, ap.cooldown or 60) end
  end
  data:extend{{type = "mod-data", name = "lp-bites", data = bites}}
end

require("air")
