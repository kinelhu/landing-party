-- The weapon sounds (sounds.lua; the user chose them on the sheet, 2026-11-09): each decided entry to its units and their
-- plated variants, by final name (Grubstake's copies are made from Kessler-Hayashi's in corps.lua). A gun's attack sound
-- is its sound's files at its speed and volume; layers play beside it a few ticks later (a delayed trigger: the slug
-- buggy's second barrel); a burst (rounds, gap) is one hit a shot and that many pulses of its sound gap ticks apart (the
-- trooper's laser: a shot every 66 ticks, three pulses 5 apart, its damage a second as before). A beam fired with its own sound gets a copy of its beam without the beam's hum (the laser drone's, the
-- trooper's: lp-kh-laser-beam hums for the turrets that keep it).
do
  local list = require("__landing-party__.sounds")
  local PLATES = {"", "-physical", "-fire", "-laser"}
  -- A beam's attack sound as an effect of its shot: attack_parameters.sound is "Played once at the start of the attack if
  -- these are ProjectileAttackParameters" (prototype-api), so a beam's was never heard. Its hum taken off, the laser
  -- drone fired in silence (the user, 2026-11-13, watching an air raid: "laser drones don't make sounds when they fire"),
  -- and the trooper's first pulse of three was silent too.
  local function beam_sound(d, s)
    d.source_effects = d.source_effects or {}
    if d.source_effects.type then d.source_effects = {d.source_effects} end
    table.insert(d.source_effects, 1, {type = "play-sound", sound = s})
  end
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
              -- The burst: one hit a shot, its old damage a second (one hit of its beam every cooldown: measured, arms,
              -- 840 ticks), the pulses its sounds, the first with the shot and the rest gap ticks apart (delayed
              -- triggers, as the layers). (Its beam set to hit rounds times gap apart landed about one of them, its damage
              -- cut to 40% and two of its pulses unheard: arms 840 ticks to 2,040, the arena's 13%, 0.2.258 to 0.2.270.)
              local name = d.beam .. "-" .. e.id
              if not made[name] then
                local b = table.deepcopy(data.raw.beam[d.beam])
                b.name, b.working_sound = name, nil
                for _, t in ipairs(b.action.action_delivery.target_effects) do
                  if t.type == "damage" then t.damage.amount = t.damage.amount * e.every / a.cooldown end
                end
                data:extend({b})
                made[name] = true
              end
              -- Shorter than its damage interval: one hit.
              d.beam, d.duration = name, math.min(e.gap * (e.rounds - 1) + 3, data.raw.beam[name].damage_interval)
              a.cooldown = e.every
              beam_sound(d, s)
              for r = 2, e.rounds do
                local tname = "lp-sound-" .. e.id .. "-pulse-" .. r
                if not made[tname] then
                  data:extend({{type = "delayed-active-trigger", name = tname, delay = e.gap * (r - 1),
                    action = {type = "direct", action_delivery = {type = "instant",
                      target_effects = {{type = "play-sound", sound = s}}}}}})
                  made[tname] = true
                end
                d.source_effects = d.source_effects or {}
                if d.source_effects.type then d.source_effects = {d.source_effects} end
                table.insert(d.source_effects, {type = "nested-result", action = {type = "direct",
                  action_delivery = {type = "delayed", delayed_trigger = tname}}})
              end
            elseif d then
              local name = d.beam .. "-quiet"
              if not made[name] then
                local b = table.deepcopy(data.raw.beam[d.beam])
                b.name, b.working_sound = name, nil
                data:extend({b})
                made[name] = true
              end
              d.beam = name
              beam_sound(d, s)
            elseif a.type == "beam" then
              -- (A beam with no beam of its own here, a chain's: its delivery plays it, as above. The Prism, the Shock and
              -- the Tesla trooper were silent too.)
              local act = a.ammo_type and a.ammo_type.action
              local first = act and (act.action_delivery and act or act[1])
              local dl = first and first.action_delivery
              if dl and dl.type == nil and dl[1] then dl = dl[1] end
              if dl then beam_sound(dl, s) else a.sound = s end
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
  -- What a turret's shot does and how often (lp-turret-hit, read by threat.turret_dps): an electric turret's own attack by
  -- damage type, an ammo turret's cooldown and damage modifier (its damage its ammo's: lp-ammo-hit), each by its
  -- ammo category for the force's modifiers. A fluid turret's burn is its fire profile's (threat.profile), not here. For
  -- what a Synthexis sweep must pay to cross a fire (herd.sweepers_at; the user, 2026-11-12: "I would steer clear of hard
  -- coding. Can we not scale the number of sweepers to something?").
  local function shot(action)
    local out = {}
    for _, item in ipairs(list(action)) do
      for _, del in ipairs(list(item.action_delivery)) do
        if del.type == "projectile" and data.raw.projectile[del.projectile] then
          walk(data.raw.projectile[del.projectile].action, out, item.repeat_count or 1)
        elseif del.type == "beam" and data.raw.beam[del.beam] then
          local bm = data.raw.beam[del.beam]
          walk(bm.action, out, math.max(1, math.floor((del.duration or 1) / (bm.damage_interval or 20))))
        end
      end
    end
    walk(action, out, 1)
    return out
  end
  local thits = {}
  for _, ty in ipairs({"ammo-turret", "electric-turret"}) do
    for name, t in pairs(data.raw[ty] or {}) do
      local ap = t.attack_parameters
      if ap and (ap.cooldown or 0) > 0 then
        local e = {cooldown = ap.cooldown, mod = ap.damage_modifier or 1, cat = ap.ammo_category or (ap.ammo_categories and ap.ammo_categories[1])}
        local at = ap.ammo_type and (ap.ammo_type[1] or ap.ammo_type)
        if ty == "electric-turret" and at and at.action then
          e.dmg = shot(at.action)
          e.cat = e.cat or at.category
        end
        thits[name] = e
      end
    end
  end
  local ahits = {}
  for name, a in pairs(data.raw.ammo or {}) do
    local at = a.ammo_type and (a.ammo_type[1] or a.ammo_type)
    if at and at.action then
      local out = shot(at.action)
      if next(out) then ahits[name] = {dmg = out, cat = a.ammo_category or at.category} end
    end
  end
  data:extend{{type = "mod-data", name = "lp-turret-hit", data = {turrets = thits, ammo = ahits}}}
end

-- The player's troops' effects (the user, 2026-11-09: "I feel like we could do a FX pass on player troops", the six
-- proposals taken, and "Tank needs oomph too, like the aegis"). By final name, so the anti-air passes above have run.
do
  local util = require("collision-mask-util")
  local COLOR = {["lp-trooper"] = {r = 1, g = 0.82, b = 0.55}, ["lp-breacher"] = {r = 0.75, g = 0.9, b = 0.45},
    ["lp-rocket-trooper"] = {r = 0.95, g = 0.6, b = 0.4}, ["lp-flame-trooper"] = {r = 0.95, g = 0.4, b = 0.18},
    ["lp-skyguard"] = {r = 0.85, g = 0.9, b = 1}, ["lp-technician"] = {r = 0.85, g = 1, b = 0.8}}
  local function sound(files, speed, volume)
    local v = {}
    for _, f in ipairs(files) do v[#v + 1] = {filename = f, volume = volume} end
    return {variations = v, speed = speed, category = "weapon"}
  end
  -- (A shot to its target only, never what stands between: the tank's shell's rule, units.lua.)
  local function to_target(p)
    p.collision_box, p.hit_collision_mask, p.force_condition = nil, {layers = {}}, "not-same"
    p.direction_only, p.piercing_damage = false, 0
    return p
  end

  -- (Red blood was tried, the biters' small blood tinted: its particles and ground splats keep their own purple, and every
  -- trooper hit sprayed purple on film, the finale, 0.2.266. The troopers spark as before.)

  -- A body where a trooper falls (the character's own dead picture, its mask in the trooper's colour), not a small
  -- vehicle's explosion and scrap. Two lying poses, the picture's two frames.
  local dead = data.raw["character-corpse"]["character-corpse"].pictures
  dead = dead and (dead[1] or dead)
  for name, color in pairs(COLOR) do
    for _, plate in ipairs({"", "-physical", "-fire", "-laser"}) do
      local u = data.raw.unit[name .. plate]
      if u and dead and dead.layers then
        local poses = {}
        for f = 0, 1 do
          local layers = {}
          for _, l in ipairs(dead.layers) do
            local c = table.deepcopy(l)
            c.frame_count, c.direction_count, c.x = nil, 1, f * c.width
            c.usage, c.apply_runtime_tint = nil, nil
            if c.filename:find("mask", 1, true) then c.tint = {r = color.r, g = color.g, b = color.b, a = 1} end
            layers[#layers + 1] = c
          end
          poses[#poses + 1] = {layers = layers}
        end
        local body = table.deepcopy(data.raw.corpse["small-remnants"])
        body.name, body.animation = name .. "-body", poses
        body.localised_name = {"entity-name." .. name}
        if not data.raw.corpse[body.name] then data:extend({body}) end
        u.corpse = body.name
        u.dying_explosion = nil
      end
    end
  end

  -- The trooper's rifle: a tracer to its target, not an instant hit.
  local tracer = to_target(table.deepcopy(data.raw.projectile["cannon-projectile"]))
  tracer.name = "lp-trooper-tracer"
  tracer.animation = {filename = "__base__/graphics/entity/bullet/bullet.png", draw_as_glow = true, width = 3, height = 50,
    priority = "high", scale = 0.7, tint = {r = 1, g = 0.9, b = 0.55, a = 1}}
  tracer.final_action, tracer.smoke = nil, nil
  data:extend({tracer})
  for _, plate in ipairs({"", "-physical", "-fire", "-laser"}) do
    local u = data.raw.unit["lp-trooper" .. plate]
    local d = u and u.attack_parameters.ammo_type.action.action_delivery
    if d and d.type == "instant" then
      local p = table.deepcopy(tracer)
      p.name = "lp-trooper-shot" .. plate
      p.action = {type = "direct", action_delivery = {type = "instant", target_effects = table.deepcopy(d.target_effects)}}
      data:extend({p})
      u.attack_parameters.ammo_type.action.action_delivery = {type = "projectile", projectile = p.name, starting_speed = 1.6,
        max_range = 20, source_effects = d.source_effects}
    end
  end

  -- The breacher throws its grenade (the game's grenade, lobbed), its blast where it lands; the throw's sound.
  for _, plate in ipairs({"", "-physical", "-fire", "-laser"}) do
    local u = data.raw.unit["lp-breacher" .. plate]
    -- (Its action a list once air.lua has passed over it: the first is the throw.)
    local act = u and u.attack_parameters.ammo_type.action
    local first = act and (act[1] or act)
    local d = first and first.action_delivery
    if d and d.type == "instant" then
      local g = table.deepcopy(data.raw.projectile.grenade)
      g.name = "lp-breacher-grenade" .. plate
      g.action = {type = "direct", action_delivery = {type = "instant", target_effects = table.deepcopy(d.target_effects)}}
      g.final_action = nil
      data:extend({g})
      first.action_delivery = {type = "projectile", projectile = g.name, starting_speed = 0.35}
      local t = {}
      for k = 1, 5 do t[#t + 1] = "__base__/sound/fight/throw-grenade-" .. k .. ".ogg" end
      u.attack_parameters.sound = sound(t, 1, 0.6)
    end
  end

  -- The flame trooper sounds as the flamethrower does.
  local ft = data.raw.gun.flamethrower and data.raw.gun.flamethrower.attack_parameters
  for _, plate in ipairs({"", "-physical", "-fire", "-laser"}) do
    local u = data.raw.unit["lp-flame-trooper" .. plate]
    if u and ft then
      u.attack_parameters.cyclic_sound = table.deepcopy(ft.cyclic_sound)
      u.attack_parameters.sound = table.deepcopy(ft.sound)
    end
  end

  -- The Skyguard's shot a small fast missile and a flak puff where it bursts (its hit stays the instant one): not the
  -- railgunner's red tracer; the rocket launcher's sound, higher.
  local missile = to_target(table.deepcopy(data.raw.projectile.rocket))
  missile.name = "lp-skyguard-missile"
  local function shrink(t, seen)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    if t.filename or t.filenames then t.scale = (t.scale or 1) * 0.6 end
    for _, v in pairs(t) do shrink(v, seen) end
  end
  shrink(missile.animation, {}); shrink(missile.shadow, {})
  missile.acceleration = 0.02
  missile.action = {type = "direct", action_delivery = {type = "instant", target_effects = {
    {type = "create-entity", entity_name = data.raw.explosion["lp-flak-puff"] and "lp-flak-puff" or "explosion"}}}}
  missile.final_action = nil
  data:extend({missile})
  local rl = data.raw.gun["rocket-launcher"] and data.raw.gun["rocket-launcher"].attack_parameters.sound
  for _, plate in ipairs({"", "-physical", "-fire", "-laser"}) do
    local u = data.raw.unit["lp-skyguard" .. plate]
    local acts = u and u.attack_parameters.ammo_type.action
    if acts and acts[1] and acts[1].action_delivery and acts[1].action_delivery.type == "beam" then
      acts[1] = {type = "direct", action_delivery = {type = "projectile", projectile = missile.name, starting_speed = 0.6,
        source_effects = {{type = "create-explosion", entity_name = "explosion-gunshot-small"}}}}
      if rl then
        local s = table.deepcopy(rl)
        s.speed = 1.4
        u.attack_parameters.sound = s
      end
    end
  end

  -- The battle tank's shell, the Aegis's: twice the size, warm, lit, a smoke trail, a big explosion where it lands.
  for name, p in pairs(data.raw.projectile) do
    if name:find("^lp%-battle%-tank%-heavy%-shell") then
      p.animation = {filename = "__base__/graphics/entity/bullet/bullet.png", draw_as_glow = true, width = 3, height = 50,
        priority = "high", scale = 3, tint = {r = 1, g = 0.8, b = 0.45, a = 1}}
      p.light = {intensity = 0.6, size = 5, color = {r = 1, g = 0.7, b = 0.35}}
      p.smoke = {{name = "smoke-fast", deviation = {0.15, 0.15}, frequency = 1, position = {0, 0}, starting_frame = 3,
        starting_frame_deviation = 5}}
      local function bigger(t, seen)
        if type(t) ~= "table" or seen[t] then return end
        seen[t] = true
        if t.type == "create-entity" and t.entity_name == "explosion" then t.entity_name = "big-explosion" end
        for _, v in pairs(t) do bigger(v, seen) end
      end
      bigger(p.action, {})
    end
  end
end

-- The mod's own icons, last (icons.lua).
require("icons")
