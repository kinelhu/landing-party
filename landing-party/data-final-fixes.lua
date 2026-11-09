-- The weapon sounds (sounds.lua; the user chose them on the sheet, 2026-11-09): each decided entry to its units and their
-- plated variants, by final name (Grubstake's copies are made from Kessler-Hayashi's in corps.lua). A gun's attack sound
-- is its sound's files at its speed and volume; layers play beside it a few ticks later (a delayed trigger: the slug
-- buggy's second barrel); a burst (rounds, gap) is its beam hitting that many times as it lasts, each hit its sound and
-- its share of the damage (the trooper's laser: 3 hits in a beam of 13 ticks, a burst every 66, its damage a second as
-- before). A beam fired with its own sound gets a copy of its beam without the beam's hum (the laser drone's, the
-- trooper's: lp-kh-laser-beam hums for the turrets that keep it).
do
  local list = require("__landing-party__.sounds")
  local PLATES = {"", "-physical", "-fire", "-laser"}
  local function path(f) return "__" .. f:match("^([^/]+)") .. "__/" .. f:gsub("^[^/]+/", "") end
  local function sound(files, speed, volume)
    local v = {}
    for _, f in ipairs(files) do v[#v + 1] = {filename = path(f), volume = volume} end
    return {variations = v, speed = speed, category = "weapon"}
  end
  local function beam_of(a)
    local d = a.ammo_type and a.ammo_type.action and a.ammo_type.action.action_delivery
    return d and d.type == "beam" and d or nil
  end
  local made = {}
  for _, e in ipairs(list) do
    if e.decided == "keep" and e.units then
      for _, base in ipairs(e.units) do
        for _, plate in ipairs(PLATES) do
          local u = data.raw.unit[base .. plate]
          local a = u and u.attack_parameters
          if a then
            local s = sound(e.files, e.speed, e.volume)
            local d = beam_of(a)
            if d and (e.rounds or 1) > 1 then
              -- The burst: its own beam, hitting rounds times gap apart, each hit the sound and its share.
              local name = d.beam .. "-" .. e.id
              if not made[name] then
                local b = table.deepcopy(data.raw.beam[d.beam])
                b.name, b.working_sound = name, nil
                b.damage_interval = e.gap
                local hit = b.action.action_delivery.target_effects
                local per = 0
                for _, t in ipairs(hit) do
                  if t.type == "damage" then
                    -- Per hit: the old damage a second over the new burst's rounds (old: a hit every cooldown).
                    t.damage.amount = t.damage.amount * e.every / (a.cooldown * e.rounds)
                    per = t.damage.amount
                  end
                end
                hit[#hit + 1] = {type = "play-sound", sound = s}
                data:extend({b})
                made[name] = per
              end
              d.beam, d.duration = name, e.gap * (e.rounds - 1) + 3
              a.cooldown = e.every
              a.sound = nil
            elseif d then
              local name = d.beam .. "-quiet"
              if not made[name] then
                local b = table.deepcopy(data.raw.beam[d.beam])
                b.name, b.working_sound = name, nil
                data:extend({b})
                made[name] = true
              end
              d.beam = name
              a.sound = s
            else
              a.sound = s
            end
            -- Layers: a delayed trigger beside the shot, offset ticks on.
            for i, l in ipairs(e.layers or {}) do
              local tname = "lp-sound-" .. e.id .. "-" .. i
              if not made[tname] then
                data:extend({{type = "delayed-active-trigger", name = tname, delay = math.max(1, l.offset or 0),
                  action = {type = "direct", action_delivery = {type = "instant",
                    target_effects = {{type = "play-sound", sound = sound(l.files, l.speed, l.volume)}}}}}})
                made[tname] = true
              end
              local del = a.ammo_type.action.action_delivery
              del.source_effects = del.source_effects or {}
              if del.source_effects.type then del.source_effects = {del.source_effects} end
              table.insert(del.source_effects, {type = "nested-result", action = {type = "direct",
                action_delivery = {type = "delayed", delayed_trigger = tname}}})
            end
          end
        end
      end
    end
  end
end

-- Hulls turn slower (shared.HULL.TURN): a unit of ours wider than HULL.WIDTH, not a flier.
do
  local shared = require("__landing-party__.shared")
  for name, u in pairs(data.raw.unit) do
    local box, m = u.collision_box, u.collision_mask
    local flier = m and m.layers and m.layers["lp-air"]
    if name:sub(1, 3) == "lp-" and box and not flier then
      local half = math.max(math.abs(box[2][1] - box[1][1]), math.abs(box[2][2] - box[1][2])) / 2
      if half > shared.HULL.WIDTH then u.rotation_speed = shared.HULL.TURN end
    end
  end
end

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
  -- What each unit does with one attack, by damage type, through its projectile where it fires one, and its cooldown
  -- (lp-unit-hit, read by threat.unit_dps): how fast a raid breaks a wall its owner's robots put back (ops.mended_floor).
  local hits = {}
  for name, u in pairs(data.raw.unit or {}) do
    local ap = u.attack_parameters
    local action = ap and ap.ammo_type and ap.ammo_type.action
    if action then
      local out = {}
      for _, item in ipairs(list(action)) do
        for _, del in ipairs(list(item.action_delivery)) do
          if del.type == "projectile" and data.raw.projectile[del.projectile] then
            walk(data.raw.projectile[del.projectile].action, out, item.repeat_count or 1)
          elseif del.type == "beam" and data.raw.beam[del.beam] then
            -- (A beam hits every damage_interval while it lasts: Kessler-Hayashi's infantry fire one, and read without it,
            -- their damage to a wall was 0.)
            local bm = data.raw.beam[del.beam]
            walk(bm.action, out, math.max(1, math.floor((del.duration or 1) / (bm.damage_interval or 20))))
          end
        end
      end
      walk(action, out, 1)
      for t, v in pairs(out) do out[t] = v * (ap.damage_modifier or 1) end
      if next(out) and (ap.cooldown or 0) > 0 then hits[name] = {dmg = out, cooldown = ap.cooldown} end
    end
  end
  data:extend{{type = "mod-data", name = "lp-unit-hit", data = hits}}
end
