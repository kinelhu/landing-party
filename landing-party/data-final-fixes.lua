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

-- What a fluid turret's fire does (lp-fire, read by threat.profile): the sticker its stream leaves on what it lands on (its
-- hits, a hit's damage and type: a flamethrower's, 180 of 16.7 fire over 30 s, 3,000, a behemoth's health), and the arc it
-- turns through. The fire consult, docs/reviews/2026-10-30-flamethrower-consult.md: priced as a gun, two flamethrowers
-- that killed 686 mediums of a wave of 750 were learned at 37 each.
do
  local function list(x) if x == nil then return {} end; if x[1] ~= nil or next(x) == nil then return x end; return {x} end
  local function sticker_of(a, seen)
    for _, item in ipairs(list(a)) do
      for _, del in ipairs(list(item.action_delivery)) do
        for _, eff in ipairs(list(del.target_effects)) do
          if eff.type == "create-sticker" and data.raw.sticker[eff.sticker] then return data.raw.sticker[eff.sticker] end
          if eff.type == "nested-result" then local s = sticker_of(eff.action, seen); if s then return s end end
        end
        local via = del.stream and data.raw.stream[del.stream]
        if via and not seen[via.name] then
          seen[via.name] = true
          local s = sticker_of(via.initial_action, seen) or sticker_of(via.action, seen) or sticker_of(via.final_action, seen)
          if s then return s end
        end
      end
    end
  end
  local fire = {}
  for name, t in pairs(data.raw["fluid-turret"] or {}) do
    local ap = t.attack_parameters
    local st = ap and ap.ammo_type and sticker_of(ap.ammo_type.action, {})
    local dmg = st and st.damage_per_tick
    if dmg and dmg.amount and dmg.amount > 0 then
      fire[name] = {hits = math.floor((st.duration_in_ticks or 0) / (st.damage_interval or 1)), hit = dmg.amount,
        every = st.damage_interval or 1, type = dmg.type or "fire", arc = ap.turn_range or 1}
    elseif ap then
      fire[name] = {hits = 0, hit = 0, type = "fire", arc = ap.turn_range or 1}
    end
  end
  data:extend{{type = "mod-data", name = "lp-fire", data = fire}}
end

require("air")

-- How far each artillery shell's blast reaches (lp-splash, read by threat.splash): the runtime reads no action radii. The
-- widest area action through its deliveries and nested results. Kessler-Hayashi's siege sets its howitzer apart from its
-- mortars by its foes' widest (a 24 typed in once, for vanilla's 4), its orbital strike spaces its shells by its own.
do
  local function list(x) if x == nil then return {} end; if x[1] ~= nil or next(x) == nil then return x end; return {x} end
  local widest
  local function action(a, seen)
    local r = 0
    for _, item in ipairs(list(a)) do
      if item.type == "area" and item.radius then r = math.max(r, item.radius) end
      for _, del in ipairs(list(item.action_delivery)) do
        for _, eff in ipairs(list(del.target_effects)) do r = math.max(r, widest(eff, seen)) end
        local via = del.projectile and data.raw.projectile[del.projectile]
        if via and not seen[via.name] then
          seen[via.name] = true
          r = math.max(r, action(via.action, seen), action(via.final_action, seen))
        end
      end
    end
    return r
  end
  widest = function(eff, seen)
    if eff.type == "nested-result" then return action(eff.action, seen) end
    return 0
  end
  local splash = {}
  for name, p in pairs(data.raw["artillery-projectile"] or {}) do
    local r = math.max(action(p.action, {}), action(p.final_action, {}))
    if r > 0 then splash[name] = r end
  end
  data:extend{{type = "mod-data", name = "lp-splash", data = splash}}
end

-- What each artillery shell does where it lands, by damage type (lp-blow, read by threat.blow): its damage effects through
-- deliveries and nested results, its bomblets (clusters, random) left out. Kessler-Hayashi's orbital shells are counted
-- out by it against a target's health and resistances (an 800 typed in for the orbital shell against a spawner before).
do
  local function list(x) if x == nil then return {} end; if x[1] ~= nil or next(x) == nil then return x end; return {x} end
  local function walk(a, out, n)
    for _, item in ipairs(list(a)) do
      if item.type ~= "cluster" then
        local m = n * (item.repeat_count or 1)
        for _, del in ipairs(list(item.action_delivery)) do
          for _, eff in ipairs(list(del.target_effects)) do
            local k = m * (eff.repeat_count or 1)
            if eff.type == "damage" and eff.damage then
              local t = eff.damage.type or "physical"
              out[t] = (out[t] or 0) + k * (eff.damage.amount or 0)
            elseif eff.type == "nested-result" then
              walk(eff.action, out, k)
            end
          end
        end
      end
    end
  end
  local blow = {}
  for name, p in pairs(data.raw["artillery-projectile"] or {}) do
    local out = {}
    walk(p.action, out, 1)
    walk(p.final_action, out, 1)
    if next(out) then blow[name] = out end
  end
  data:extend{{type = "mod-data", name = "lp-blow", data = blow}}
end
