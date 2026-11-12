-- The biotech's breeds and its pen (docs/biotech.md; engine tests 2026-10-22). Bred biters are the vanilla biters with
-- their mask layers retinted (green body, yellow bands: they read apart from wild ones at a glance) and their dots on
-- the map in its colour. The pen is a biter spawner drawn as Space Age's captive spawner: a nest that is held. A wild
-- spawner given to another force keeps the wild look and breeds wild biters (tested), so holding a nest means a pen in
-- its place (scripts/herd.lua).
local shared = require("shared")
local B = shared.BIOTECH

local function retint(t, n)
  if type(t) ~= "table" then return n end
  if t.tint then t.tint = (n % 2 == 0) and B.tint1 or B.tint2; n = n + 1 end
  for _, v in pairs(t) do n = retint(v, n) end
  return n
end

-- A bite is not a bullet (Fable's breeds consult, docs/reviews/2026-10-22-biotech-breeds-consult.md): the breeds bite
-- with their own damage type, which armoured hulls resist, so a tank drives through a herd (the stock as first built ate
-- tanks and walkers in the arena: bred against armour +71). Infantry, walls and turrets do not resist it: the breach
-- stays quick. The biotech's answer to armour is to be a breed of its own.
local BITE = "lp-bite"
local function bite(t)
  if type(t) ~= "table" then return end
  if t.type == "damage" and t.damage and t.damage.type == "physical" then t.damage.type = BITE end
  for _, v in pairs(t) do bite(v) end
end
local HULLS = {["lp-tank"] = 60, ["lp-aegis"] = 60, ["lp-dozer"] = 60, ["lp-scorcher"] = 60, ["lp-prism"] = 60,
  ["lp-tesla"] = 60, ["lp-battle-tank"] = 60, ["lp-walker"] = 40, tank = 60, spidertron = 40}

-- The spitter (tier 1, the breeds consult): its acid is its answer to armour (no hull resists acid); outranged by rifles
-- and lances, beaten by fire and air.
local BREEDS = {"small-biter", "medium-biter", "big-biter", "behemoth-biter", "medium-spitter"}
local out = {{type = "damage-type", name = BITE}}
for _, src in ipairs(BREEDS) do
  local u = table.deepcopy(data.raw.unit[src])
  u.name = "lp-bred-" .. src
  u.localised_name = {"entity-name.lp-bred", {"entity-name." .. src}}
  u.localised_description = {"entity-description.lp-bred"}
  retint(u.run_animation, 0)
  retint(u.attack_parameters.animation, 0)
  bite(u.attack_parameters.ammo_type)
  u.map_color = B.color
  u.enemy_map_color = B.color
  u.hidden_in_factoriopedia = true
  -- Never taken off the map by the engine (vanilla biters are destroyed when their commands keep failing, and no death is
  -- raised): its herd counts and orders every unit it sends. A big burster stuck among its incubators, its group's legs
  -- failing, went 6 s into the march with full health and no death, its siege had no ram, and what it lost was never
  -- counted (farm LP_MIX=siege, 12345, 2026-11-05). Every breed below is a copy of one of these.
  u.ai_settings = table.deepcopy(u.ai_settings or {})
  u.ai_settings.destroy_when_commands_fail = false
  table.insert(out, u)
end

-- The spore spitter (the user, 2026-10-23, on fliers: its class had no answer to them, -100 in the arena): a bred
-- spitter whose spit bursts into spores where it lands, aloft as well: 30 acid to a flier within 1.5 tiles, 18 to the
-- ground within 1, no burning pool; range 20, past the fliers' 15. Violet. Not ground-only (air.lua: shared.BREEDS air).
-- 45 to a flier changed nothing: it wins every fight with harriers and loses half its value doing it (a soft body).
do
  local src
  for _, p in ipairs(out) do if p.name == "lp-bred-medium-spitter" then src = p end end
  local u = table.deepcopy(src)
  u.name = "lp-bred-spore"
  u.localised_name = {"entity-name.lp-bred-spore"}
  u.localised_description = {"entity-description.lp-bred-spore"}
  local VIOLET1, VIOLET2 = {r = 0.62, g = 0.4, b = 1, a = 1}, {r = 0.85, g = 0.75, b = 1, a = 1}
  local function violet(t, n)
    if type(t) ~= "table" then return n end
    if t.tint then t.tint = (n % 2 == 0) and VIOLET1 or VIOLET2; n = n + 1 end
    for _, v in pairs(t) do n = violet(v, n) end
    return n
  end
  violet(u.run_animation, 0)
  violet(u.attack_parameters.animation, 0)
  local st = table.deepcopy(data.raw.stream["acid-stream-spitter-medium"])
  st.name = "lp-spore-stream"
  local function burst(amount, mask, r)
    return {type = "area", radius = r, force = "enemy", ignore_collision_condition = true, trigger_target_mask = mask,
      action_delivery = {type = "instant", target_effects = {{type = "damage", damage = {amount = amount, type = "acid"}}}}}
  end
  st.initial_action = {
    {type = "direct", action_delivery = {type = "instant", target_effects = {
      {type = "create-entity", entity_name = "gleba-blood-explosion-small"}}}},
    burst(30, {"lp-air-unit"}, 1.5), burst(18, {"common"}, 1)}
  st.action = nil
  u.attack_parameters.ammo_type = {action = {type = "direct", action_delivery = {type = "stream", stream = st.name}}}
  u.attack_parameters.damage_modifier = 1
  u.attack_parameters.range = 20
  table.insert(out, u)
  table.insert(out, st)
end

-- The stomper (tier 4, the breeds consult; built 2026-10-23 for the gap the arena's faction table found: Kessler-
-- Hayashi answered every breed at +100 and no breed answered its railgunner or its hulls). Space Age's small stomper
-- in Synthexis's green: a pentapod that steps over walls without a breach (spiked: in a unit group it marched with
-- six biters, crossed a wall of 21 pieces leaving all 21, and stomped the gun turret behind in 4 seconds, the biters
-- unhurt: its stomp is an area on enemy forces). Not tagged lp-biter (data-final-fixes tags units, spawners and worms,
-- not spider-units): to the railgunner, made to kill biters, it is another animal. Its stomp ground-only (a mask,
-- as the breeds' weapons: air.lua covers its spit). Physical 50% with no flat (vanilla's flat 2 made rifles useless),
-- laser 40% (vanilla 80%: lasers should hurt it), nothing against explosions: rockets, slugs, the battle tank,
-- fliers and artillery beat it. Its shell stays where it falls; the premature wrigglers its death spawned are dropped.
local STOMPER_HEALTH, STOMP_SHARE = 2000, 0.2
local STOMPER_MASK = {r = 0.55, g = 0.3, b = 0.85, a = 0.8}   -- violet, the creep's
do
  local src = data.raw["spider-unit"]["small-stomper-pentapod"]
  local u = table.deepcopy(src)
  u.name = "lp-bred-stomper"
  u.localised_name = {"entity-name.lp-bred-stomper"}
  u.localised_description = {"entity-description.lp-bred-stomper"}
  u.hidden_in_factoriopedia = true
  u.map_color = B.color
  u.enemy_map_color = B.color
  u.resistances = {{type = "physical", percent = 50}, {type = "laser", percent = 40}, {type = "impact", percent = 80}}
  -- Vanilla's (3,500 health, 7 a second healed, 44 a stomp) beat every ground kind at 150 in the arena, rocket troopers
  -- and the battle tank too: a late Gleba enemy. Its regeneration is the pen's, not the animal's (the breeds consult).
  u.max_health = STOMPER_HEALTH
  u.healing_per_tick = 0
  u.ai_settings = table.deepcopy(u.ai_settings or {})
  u.ai_settings.destroy_when_commands_fail = false
  local shell = {}
  for _, e in ipairs(u.dying_trigger_effect or {}) do
    if not (e.entity_name or ""):find("wriggler", 1, true) then table.insert(shell, e) end
  end
  u.dying_trigger_effect = shell
  -- Its plates only (the mask layers), the body's art left as vanilla draws it: tinted whole it read as a plastic toy
  -- (the user, 2026-10-23: "Tint looks too toy like").
  local function green(t, seen)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    local f = t.filename or (t.filenames and t.filenames[1])
    if t.tint and type(f) == "string" and f:find("-mask", 1, true) then t.tint = STOMPER_MASK end
    for _, v in pairs(t) do green(v, seen) end
  end
  green(u.graphics_set, {})
  local legs = {}
  for _, leg in ipairs(u.spider_engine.legs) do
    -- The stomp: on the ground only.
    for _, e in ipairs(leg.leg_hit_the_ground_when_attacking_trigger or {}) do
      if e.type == "nested-result" and e.action and e.action.type == "area" then
        e.action.trigger_target_mask = {"common"}
        for _, d in ipairs(e.action.action_delivery.target_effects or {}) do
          if d.type == "damage" then d.damage.amount = d.damage.amount * STOMP_SHARE end
        end
      end
    end
    local name = "lp-bred-stomper-leg"
    if not legs[name] then
      local l = table.deepcopy(data.raw["spider-leg"][leg.leg])
      l.name = name
      l.hidden = true
      green(l.graphics_set, {})
      legs[name] = l
      table.insert(out, l)
    end
    leg.leg = name
  end
  table.insert(out, u)
end

-- The runt (tier 2, the breeds consult): the probe's body, a bred small biter of its own name so the probe's losses
-- can be read (herd.lua: which turrets shot at it); spawned by script at probe time, never bred.
do
  local r
  for _, p in ipairs(out) do if p.name == "lp-bred-small-biter" then r = table.deepcopy(p) end end
  r.name = "lp-runt"
  r.localised_name = {"entity-name.lp-runt"}
  r.localised_description = {"entity-description.lp-runt"}
  -- Its death pops the mines round it (the user, 2026-10-28: "make runts pop mines in a radius around them"): a land
  -- mine's 15 of health, RUNT_POP over RUNT_POP_R, little to a wall or a turret; a runt of the sweep (herd.lua) set off on
  -- one clears the field round it, not that one alone.
  local RUNT_POP, RUNT_POP_R = 30, 4
  r.dying_trigger_effect = {{type = "nested-result", action = {type = "area", radius = RUNT_POP_R, force = "not-same",
    ignore_collision_condition = true, trigger_target_mask = {"common"},
    action_delivery = {type = "instant", target_effects = {{type = "damage", damage = {amount = RUNT_POP, type = "explosion"}}}}}}}
  table.insert(out, r)
end

-- The sapper (shared.SAPPER): a big biter's body in ochre, spawned by script for the sweep (herd.lua), never bred; its death
-- the blast that clears the mines round it, wherever it falls.
do
  local r
  for _, p in ipairs(out) do if p.name == "lp-bred-big-biter" then r = table.deepcopy(p) end end
  local SAP = shared.SAPPER
  r.name = "lp-sweeper"
  r.localised_name = {"entity-name.lp-sweeper"}
  r.localised_description = {"entity-description.lp-sweeper"}
  r.max_health, r.movement_speed = SAP.health, SAP.speed
  local OCHRE1, OCHRE2 = {r = 0.85, g = 0.6, b = 0.2, a = 1}, {r = 0.55, g = 0.35, b = 0.1, a = 1}
  local function ochre(t, n)
    if type(t) ~= "table" then return n end
    if t.tint then t.tint = (n % 2 == 0) and OCHRE1 or OCHRE2; n = n + 1 end
    for _, v in pairs(t) do n = ochre(v, n) end
    return n
  end
  ochre(r.run_animation, 0)
  ochre(r.attack_parameters.animation, 0)
  r.dying_trigger_effect = {{type = "create-entity", entity_name = "medium-explosion"},
    {type = "nested-result", action = {type = "area", radius = SAP.r, force = "not-same", ignore_collision_condition = true,
      trigger_target_mask = {"common"},
      action_delivery = {type = "instant", target_effects = {{type = "damage", damage = {amount = SAP.pop, type = "explosion"}}}}}}}
  table.insert(out, r)
end

-- The scout (the user, 2026-10-24: "visible scouting", the lone biter that circles the wall before a wave and that the
-- player learns to read): a small biter's body in pale cyan bands, the fastest of the breeds and frail, lit at night;
-- made by script when a wave sets out (herd.launch), never bred, so its loss costs the wave no fighter.
do
  local r
  for _, p in ipairs(out) do if p.name == "lp-bred-small-biter" then r = table.deepcopy(p) end end
  r.name = "lp-bred-scout"
  r.localised_name = {"entity-name.lp-bred-scout"}
  r.localised_description = {"entity-description.lp-bred-scout"}
  r.max_health, r.movement_speed = 30, 0.34
  local PALE1, PALE2 = {r = 0.45, g = 0.95, b = 1, a = 1}, {r = 0.9, g = 1, b = 1, a = 1}
  local function pale(t, n)
    if type(t) ~= "table" then return n end
    if t.tint then t.tint = (n % 2 == 0) and PALE1 or PALE2; n = n + 1 end
    for _, v in pairs(t) do n = pale(v, n) end
    return n
  end
  pale(r.run_animation, 0)
  pale(r.attack_parameters.animation, 0)
  table.insert(out, r)
end

-- The carrier (the Fable consult, docs/reviews/2026-10-25-synthexis-growth-research-consult.md: "spatial spread needs
-- a thing that travels"): a mature culture's seed, a big biter's body in deep violet, slow and tough, lit by script,
-- walking with an escort to a wild nest field where a new culture begins (farm.lua). Never bred: made when it sets out.
do
  local r
  for _, p in ipairs(out) do if p.name == "lp-bred-big-biter" then r = table.deepcopy(p) end end
  r.name = "lp-bred-carrier"
  r.localised_name = {"entity-name.lp-bred-carrier"}
  r.localised_description = {"entity-description.lp-bred-carrier"}
  r.max_health, r.movement_speed = 600, 0.12
  local V1, V2 = {r = 0.42, g = 0.12, b = 0.62, a = 1}, {r = 0.6, g = 1, b = 0.25, a = 1}
  local function violet(t, n)
    if type(t) ~= "table" then return n end
    if t.tint then t.tint = (n % 2 == 0) and V1 or V2; n = n + 1 end
    for _, v in pairs(t) do n = violet(v, n) end
    return n
  end
  violet(r.run_animation, 0)
  violet(r.attack_parameters.animation, 0)
  table.insert(out, r)
end

-- The burster (id cinder; tier 3, the breeds consult): a biter with acid bands that dies into the demolisher's fissure (a
-- telegraphed crack, then an eruption that breaks walls and turrets round it: fire would not, walls are immune to it,
-- and fire spreads). Shoot the banded one first, at range. Its eruption hurts any force but its own ("not-same"), so a
-- cinder killed at home cracks no incubator. Lit at night by script (farm.on_spawned).
-- A baneling since 0.2.7 (the user, 2026-10-24: "a little more fragile? perhaps on a small biter body that goes fast?
-- ... giving some time to react before they burst in your face"): a medium biter's body, faster than any breed, no
-- armour (it was a big biter's, whose physical 8 flat took a rifle's 8 down to 0.45: one held off ten troopers), and it
-- does not bite: in reach of its target it bursts, and dies of it.
-- In Synthexis's colours (the user, 2026-10-23: the banelings', "recolor the eruption to be more in theme"): violet
-- and acid bands, an acid-green crack and burst where vanilla's are lava.
local BURSTER = {health = 120, speed = 0.32}
local EMBER1, EMBER2 = {r = 0.72, g = 0.35, b = 1, a = 1}, {r = 0.6, g = 1, b = 0.2, a = 1}
local ACID, ACID_LIGHT = {r = 0.45, g = 1, b = 0.3, a = 1}, {r = 0.35, g = 1, b = 0.2}
local function acid(t, seen)
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if t.filename or t.filenames or t.stripes then t.tint = ACID end
  for _, v in pairs(t) do acid(v, seen) end
end
local function ember(t, n)
  if type(t) ~= "table" then return n end
  if t.tint then t.tint = (n % 2 == 0) and EMBER1 or EMBER2; n = n + 1 end
  for _, v in pairs(t) do n = ember(v, n) end
  return n
end
do
  local src
  for _, p in ipairs(out) do if p.name == "lp-bred-medium-biter" then src = p end end
  local c = table.deepcopy(src)
  c.name = "lp-bred-cinder"
  c.max_health, c.movement_speed, c.resistances = BURSTER.health, BURSTER.speed, {}
  -- Its attack is its end: the hit sets it off, and its death is the eruption below. Set off, it winds up first (the user,
  -- 2026-11-05: the burster "underwhelming graphically"): its attack raises shared.BURSTFX.windup, and scripts/burstfx.lua
  -- stops it, swells it in acid green and kills it after its wind-up, past harm meanwhile (set off, it bursts whole, as
  -- when the hit killed it on the spot, as the bomb drone's, until 0.2.211).
  c.attack_parameters.cooldown = 30
  c.attack_parameters.ammo_type = {target_type = "entity", action = {type = "direct", action_delivery = {type = "instant",
    source_effects = {{type = "script", effect_id = shared.BURSTFX.windup}}}}}
  c.localised_name = {"entity-name.lp-bred-cinder"}
  c.localised_description = {"entity-description.lp-bred-cinder"}
  ember(c.run_animation, 0)
  ember(c.attack_parameters.animation, 0)
  -- The demolisher's delayed chain (crack, then eruption, then damage) never fired from a dying unit (a test: the crack
  -- drew, no damage came): the death does it all at once, the crack and eruption as its look.
  local function area(r, amount)
    return {type = "nested-result", action = {type = "area", radius = r, force = "not-same", ignore_collision_condition = true, trigger_target_mask = {"common"},
      action_delivery = {type = "instant", target_effects = {{type = "damage", damage = {amount = amount, type = "explosion"}}}}}}
  end
  c.dying_trigger_effect = {
    {type = "create-entity", entity_name = "lp-cinder-fissure"},
    {type = "create-entity", entity_name = "lp-cinder-fissure-explosion"},
    {type = "create-entity", entity_name = "lp-cinder-fissure-scorchmark"},
    area(shared.CINDER_BURST.r, shared.CINDER_BURST.amount), area(shared.CINDER_BURST.core_r, shared.CINDER_BURST.core)}
  table.insert(out, c)
  -- The small demolisher's fissure set, renamed and its damage its own.
  local FROM, TO = "small-demolisher-fissure", "lp-cinder-fissure"
  local function rename(t)
    if type(t) ~= "table" then return end
    for k, v in pairs(t) do
      if type(v) == "string" and v:sub(1, #FROM) == FROM then t[k] = TO .. v:sub(#FROM + 1)
      else rename(v) end
    end
  end
  for _, protos in pairs(data.raw) do
    for name, p in pairs(protos) do
      if name:sub(1, #FROM) == FROM then
        local q = table.deepcopy(p)
        rename(q)
        q.localised_name = {"entity-name.lp-cinder-fissure"}
        if q.light then q.light.color = ACID_LIGHT end
        for _, k in ipairs({"animations", "animation", "decay_animation"}) do acid(q[k], {}) end
        -- The crack is a look only here (its delayed eruption and damage are the death's own, above).
        if q.name == TO then q.created_effect = nil end
        table.insert(out, q)
      end
    end
  end
end

-- The big burster (the user, 2026-10-27: "a big burster or behemoth burster? With a larger boom and large HP pool?"): a
-- behemoth's body that carries its blast to the turret line through the fire. The burster's 120 of health died before any
-- laser line and its 550 broke a gun turret (400), not a laser (1,000) or a flamethrower (1,400): on a megabase's wall of
-- 60 lasers 4 tiles apart, a wave of 262 mediums lost 235 crossing. This one's blast breaks every turret BIG_BURST.r of it,
-- three of such a line; slow, alone in front, it is what focused fire, rockets and artillery are for, and a wall that
-- holds it short of the turrets takes its blast.
local BIG_BURST = shared.BIG_BURST
do
  local src
  for _, p in ipairs(out) do if p.name == "lp-bred-behemoth-biter" then src = p end end
  local c = table.deepcopy(src)
  c.name = "lp-bred-big-burster"
  -- Half of laser and fire (the user, 2026-10-28: "more resistances for bursters at high evo"; it comes from 0.85): an answer
  -- to a wall of lasers and flamethrowers, none to bullets, rockets and artillery, its counters (balance keeps counters).
  c.max_health = BIG_BURST.health
  c.resistances = {{type = "laser", percent = 50}, {type = "fire", percent = 50}}
  -- Its bite the behemoth's. Its blast whole when its herd sets it off where it reaches the gun it is sent at or the wall
  -- (herd.lua detonate: its death and the rest of its blast in script); killed short of it, its core alone goes (BIG_BURST.core within half its reach): at the wall a hole half as
  -- wide, in the open nothing that matters (the user, 2026-10-30: one burster punched through any wall, and shot down at
  -- the wall its death blast opened it all the same, 68 wall pieces from two in the user's fort: nothing the player built
  -- could stop it. With no blast at all, the siege test's laser wall killed all 12 short of it and stood whole).
  c.localised_name = {"entity-name.lp-bred-big-burster"}
  c.localised_description = {"entity-description.lp-bred-big-burster"}
  ember(c.run_animation, 0)
  ember(c.attack_parameters.animation, 0)
  local function area(r, amount)
    return {type = "nested-result", action = {type = "area", radius = r, force = "not-same", ignore_collision_condition = true, trigger_target_mask = {"common"},
      action_delivery = {type = "instant", target_effects = {{type = "damage", damage = {amount = amount, type = "explosion"}}}}}}
  end
  c.dying_trigger_effect = {
    {type = "create-entity", entity_name = "lp-cinder-fissure"},
    {type = "create-entity", entity_name = "lp-cinder-fissure-scorchmark"},
    {type = "create-entity", entity_name = "lp-spore-cloud"},
    area(BIG_BURST.r / 2, BIG_BURST.core)}
  table.insert(out, c)
  -- Its spores (the user, 2026-11-03: "spore cloud on top of the explosion"): where it bursts, a cloud corroding what its
  -- foes built for SPORE.ticks, every SPORE.every a hit within SPORE.r, buildings too (the poison cloud hits only what
  -- breathes): the breach widens while the robots mend it, and the ground it burst on is no place to rebuild for a while.
  -- Its damage the type the player's stone wall resists least of acid and poison (read: 80% and none, so poison).
  local SPORE = {r = 5, ticks = 600, every = 30, share = 0.6}
  local wall = data.raw.wall and data.raw.wall["stone-wall"]
  local res = {}
  for _, x in ipairs(wall and wall.resistances or {}) do res[x.type] = x.percent or 0 end
  local kind = (res.poison or 0) <= (res.acid or 0) and "poison" or "acid"
  local hp = wall and wall.max_health or 350
  local per = hp * SPORE.share / (SPORE.ticks / SPORE.every) / (1 - (res[kind] or 0) / 100)
  local cloud = table.deepcopy(data.raw["smoke-with-trigger"]["poison-cloud"])
  cloud.name = "lp-spore-cloud"
  cloud.duration = SPORE.ticks
  cloud.action_cooldown = SPORE.every
  cloud.color = {r = 0.62, g = 0.72, b = 0.18, a = 0.6}
  cloud.action = {type = "direct", action_delivery = {type = "instant", target_effects = {type = "nested-result",
    action = {type = "area", radius = SPORE.r, force = "enemy", action_delivery = {type = "instant",
      target_effects = {type = "damage", damage = {amount = per, type = kind}}}}}}}
  table.insert(out, cloud)
  -- Its blast seen as what it does (the user, 2026-10-28: "we need to add a green explosion FX or something if they're
  -- going to be as strong as this"): the big artillery shell's explosion in the burster's acid green, its blast's breadth
  -- (BIG_BURST.r) across, and a green flash.
  local ex = table.deepcopy(data.raw.explosion["big-artillery-explosion"])
  ex.name = "lp-big-burst-explosion"
  ex.localised_name = {"entity-name.lp-bred-big-burster"}
  local GREEN = {r = 0.45, g = 1, b = 0.25, a = 1}
  local function green(t)
    if type(t) ~= "table" then return end
    if t.filename or t.filenames or t.stripes then t.tint = GREEN; t.scale = (t.scale or 1) * 1.4 end
    for _, v in pairs(t) do green(v) end
  end
  green(ex.animations)
  ex.light = {intensity = 1, size = BIG_BURST.r * 6, color = {r = 0.4, g = 1, b = 0.3}}
  table.insert(out, ex)
end

-- Its worms: two by each pen (the breeds consult: a farm's home guard; the only thing of its that reaches a flier).
local worm = table.deepcopy(data.raw.turret["medium-worm-turret"])
worm.name = "lp-bred-worm"
worm.localised_name = {"entity-name.lp-bred-worm"}
worm.localised_description = {"entity-description.lp-bred"}
worm.autoplace = nil
worm.hidden_in_factoriopedia = true
worm.map_color = B.color
worm.enemy_map_color = B.color
for _, k in ipairs({"folded_animation", "preparing_animation", "prepared_animation", "prepared_alternative_animation",
  "starting_attack_animation", "attacking_animation", "ending_attack_animation", "folding_animation", "graphics_set"}) do
  retint(worm[k], 0)
end
-- Its mask is a thin band: tinted alone, the worm read as a wild one (screenshot, 2026-10-23). Its body green too.
local function body(t)
  if type(t) ~= "table" then return end
  if t.filename and not t.draw_as_shadow and not t.filename:find("mask", 1, true) and not t.tint then
    t.tint = {r = 0.7, g = 1, b = 0.6, a = 1}
  end
  for _, v in pairs(t) do body(v) end
end
for _, k in ipairs({"folded_animation", "preparing_animation", "prepared_animation", "prepared_alternative_animation",
  "starting_attack_animation", "attacking_animation", "ending_attack_animation", "folding_animation", "graphics_set"}) do
  body(worm[k])
end
table.insert(out, worm)

local pen = table.deepcopy(data.raw["unit-spawner"]["biter-spawner"])
pen.name = "lp-pen"
pen.localised_name = {"entity-name.lp-pen"}
pen.localised_description = {"entity-description.lp-pen"}
pen.autoplace = nil
pen.captured_spawner_entity = nil
pen.hidden_in_factoriopedia = true
pen.graphics_set = {animations = {table.deepcopy(data.raw["assembling-machine"]["captive-biter-spawner"].graphics_set.animation)}}
-- Its flesh graded (tools/art/grade.py, palette half-plum; 0.2.344): moved half the way from the wild nest's orange to
-- rose-mauve, its metal, cables and glass as they were (the user, 2026-11-12: tinting "is also hitting the metal parts";
-- all green was "a little jarring" beside the wild nests: "Halfway is good").
for _, l in ipairs(pen.graphics_set.animations[1].layers) do
  if l.filename and l.filename:find("captive%-anim") then l.filename = "__landing-party__/graphics/synthexis/pen.png" end
end
pen.map_color = B.color
-- It eats by script (creep.drink), as a wild spawner would: the engine's absorption off, or it would eat uncounted.
pen.absorptions_per_second = nil
pen.enemy_map_color = B.color
-- Its stock is the wave: it breeds up to the cap and keeps them by its gate.
pen.max_count_of_owned_units = shared.PEN_CAP
pen.max_friends_around_to_spawn = shared.PEN_CAP
-- By the biotech force's own evolution (tested): the vanilla spawner's table, bred.
for _, r in ipairs(pen.result_units) do
  local name = r[1] or r.unit
  if r[1] then r[1] = "lp-bred-" .. name else r.unit = "lp-bred-" .. name end
end
-- Its cinders from evolution 0.45, a tenth of what it breeds from 0.65 (from 0.6 and 0.8 until 0.2.17: a third-hour
-- breed, while the arena's breach showed them the middle game's wall breaker, before big biters break a line alone).
do
  local first = pen.result_units[1]
  if first[1] then
    table.insert(pen.result_units, {"lp-bred-cinder", {{0.45, 0.0}, {0.65, 0.1}, {1.0, 0.1}}})
  else
    table.insert(pen.result_units, {unit = "lp-bred-cinder", spawn_points = {
      {evolution_factor = 0.45, weight = 0.0}, {evolution_factor = 0.65, weight = 0.1}, {evolution_factor = 1.0, weight = 0.1}}})
  end
end
-- Its big bursters are not bred by chance: hatched to order alone, once it has developed them (farm.lua: walls that held
-- its waves; the user, 2026-10-30: "a Synthexis tech they can develop once they can't siege without them"). Bred by chance
-- from 0.85, two came with a siege that had ordered none, and stood at the wall.
-- Its stompers from evolution 0.8, one in fifty of what it breeds from 0.95.
do
  local first = pen.result_units[1]
  if first[1] then
    table.insert(pen.result_units, {"lp-bred-stomper", {{0.8, 0.0}, {0.95, 0.02}, {1.0, 0.025}}})
  else
    table.insert(pen.result_units, {unit = "lp-bred-stomper", spawn_points = {
      {evolution_factor = 0.8, weight = 0.0}, {evolution_factor = 0.95, weight = 0.02}, {evolution_factor = 1.0, weight = 0.025}}})
  end
end
-- Its spore spitters from its arrival (evolution 0.25), a twentieth of what it breeds from 0.4: the herd's own guns up.
do
  local first = pen.result_units[1]
  if first[1] then
    table.insert(pen.result_units, {"lp-bred-spore", {{0.25, 0.0}, {0.4, 0.05}, {1.0, 0.06}}})
  else
    table.insert(pen.result_units, {unit = "lp-bred-spore", spawn_points = {
      {evolution_factor = 0.25, weight = 0.0}, {evolution_factor = 0.4, weight = 0.05}, {evolution_factor = 1.0, weight = 0.06}}})
  end
end
-- Its spitters from evolution 0.3, a sixth of what it breeds from 0.5 (the vanilla spitter spawner's medium comes at 0.4).
local first = pen.result_units[1]
if first[1] then
  table.insert(pen.result_units, {"lp-bred-medium-spitter", {{0.3, 0.0}, {0.5, 0.12}, {1.0, 0.15}}})
else
  table.insert(pen.result_units, {unit = "lp-bred-medium-spitter", spawn_points = {
    {evolution_factor = 0.3, weight = 0.0}, {evolution_factor = 0.5, weight = 0.12}, {evolution_factor = 1.0, weight = 0.15}}})
end
-- Killed, its gland (the player's pheromone bait research; it dropped from Grubstake's flare canisters until the flare
-- was retired, 2026-10-22).
pen.loot = {{type = "item", name = "lp-pheromone-gland", independent_probability = 1, amount_min = 1, amount_max = 2}}
table.insert(out, pen)

-- Creep (the user, 2026-10-22: "kind of a Zerg creep?"; scripts/creep.lua): Gleba's jellynut soil, not mineable, with
-- the "object" layer so nothing is built on it (turrets, walls, belts, rails, poles, chests, spawners: tested) while
-- everything walks it (biters, the player, cars, tanks, spidertrons). It drinks pollution (scripts/creep.lua): what it
-- drinks is Synthexis's biomass.
local creep = table.deepcopy(data.raw.tile["artificial-jellynut-soil"])
creep.name = "lp-creep"
creep.localised_name = {"tile-name.lp-creep"}
creep.minable = nil
creep.autoplace = nil
creep.collision_mask = {layers = {ground_tile = true, object = true}}
-- It eats by script (creep.drink, shared.CREEP_ABSORB a tile): the engine's absorption off.
creep.absorptions_per_second = nil
creep.map_color = {150, 50, 170}
-- Plum, graded (tools/art/grade.py, half-plum; 0.2.344): the first look (untinted) read as brown mud beside Nauvis dirt,
-- then a violet tint {0.8, 0.55, 1} shouted (the user, 2026-11-12: "the purple creep"): dark plum keeps its veins apart
-- and reads at the wide zoom as Synthexis's ground (nothing is built on it) while quiet beside dirt and grass.
creep.tint = nil
for _, v in ipairs(creep.variants.main) do v.picture = "__landing-party__/graphics/synthexis/creep.png" end
creep.variants.transition.spritesheet = "__landing-party__/graphics/synthexis/creep.png"
creep.hidden_in_factoriopedia = true
table.insert(out, creep)

-- The tumor: what grows the creep round it. A small egg raft out of the water, tinted; a military target the player's
-- turrets shoot. It does not collide with creep (no "object" layer), so it can stand on its own creep, but not on water.
local raft = data.raw["unit-spawner"]["gleba-spawner-small"]
local tumor = {type = "simple-entity-with-force", name = "lp-tumor", hidden_in_factoriopedia = true,
  localised_name = {"entity-name.lp-tumor"}, localised_description = {"entity-description.lp-tumor"},
  icon = raft.icon, icon_size = raft.icon_size or 64,
  flags = {"placeable-enemy", "placeable-off-grid", "not-repairable", "not-blueprintable", "not-deconstructable"},
  max_health = 400, is_military_target = true,
  collision_box = {{-0.9, -0.9}, {0.9, 0.9}}, selection_box = {{-1.2, -1.2}, {1.2, 1.2}},
  collision_mask = {layers = {item = true, player = true, water_tile = true, is_object = true, is_lower_object = true}},
  map_color = B.color, enemy_map_color = B.color,
  dying_explosion = raft.dying_explosion, corpse = raft.corpse, damaged_trigger_effect = raft.damaged_trigger_effect,
  resistances = {{type = "fire", percent = -50}, {type = "physical", decrease = 2}},
  -- Low: under the units walking its creep, sunk in it (the user, 2026-10-26: "look a little more buried"), with its
  -- slime and roots round it once grown (creep.lua).
  render_layer = "lower-object",
  animations = table.deepcopy(raft.graphics_set.animations)}
for _, a in ipairs(tumor.animations) do
  for _, l in ipairs(a.layers or {}) do
    l.scale = (l.scale or 1) * 1.3
    if l.shift then l.shift = {l.shift[1] * 1.3, l.shift[2] * 1.3} end
    -- Graded magenta (tools/art/grade.py, half-plum; 0.2.344; a green tint until then): lighter than the plum creep, so
    -- it still reads as the target it is, the herd alone green on its base.
    if not l.draw_as_shadow then
      local k = l.filename:match("spawner%-upper%-small%-(%d)")
      if k then l.filename = "__landing-party__/graphics/synthexis/tumor-" .. k .. ".png" end
    end
  end
end
table.insert(out, tumor)

-- On creep, Synthexis's units are quicker and mend (scripts/creep.lua renews these each second; a sticker with a negative
-- damage heals, tested). Its own damage type, so no resistance reduces the mending. No goo drawn.
table.insert(out, {type = "damage-type", name = "lp-mend", hidden = true})
local haste = table.deepcopy(data.raw.sticker["slowdown-sticker"])
haste.name, haste.animation, haste.duration_in_ticks = "lp-creep-haste", nil, 90
haste.target_movement_modifier = 1.3
haste.hidden = true
local mend = table.deepcopy(data.raw.sticker["slowdown-sticker"])
mend.name, mend.animation, mend.duration_in_ticks = "lp-creep-mend", nil, 90
mend.target_movement_modifier = 1
mend.damage_per_tick = {amount = -0.1, type = "lp-mend"}
mend.damage_interval = 1
mend.hidden = true
table.insert(out, haste)
table.insert(out, mend)
-- The cell (the identity consult, docs/reviews/2026-10-22-synthexis-identity-consult.md, step 2; scripts/cell.lua): beside
-- each incubator a pad of acid-green refined concrete, a biochamber at work on it and a lamp in its colour: glass and a
-- glow where Kessler-Hayashi has white light and Grubstake amber. The biochamber needs no power and no nutrients (it
-- crafts nothing, for ever: its animation and light are the tell that the incubator is fed).
table.insert(out, {type = "recipe-category", name = "lp-culture"})
table.insert(out, {type = "recipe", name = "lp-culture-feed", categories = {"lp-culture"}, hidden = true, enabled = true,
  energy_required = 20, ingredients = {}, results = {}, icon = "__space-age__/graphics/icons/biochamber.png"})
do
  local c = table.deepcopy(data.raw["assembling-machine"]["biochamber"])
  c.name = "lp-biochamber"
  c.localised_name = {"entity-name.lp-biochamber"}
  c.localised_description = {"entity-description.lp-biochamber"}
  c.hidden = true
  c.minable = nil
  c.flags = {"placeable-neutral", "placeable-enemy", "not-blueprintable", "not-deconstructable"}
  c.energy_source = {type = "void"}
  c.crafting_categories = {"lp-culture"}
  c.fixed_recipe = "lp-culture-feed"
  c.module_slots = 0
  c.allowed_effects = nil
  c.effect_receiver = nil
  c.fast_replaceable_group = nil
  c.next_upgrade = nil
  c.map_color = B.color
  c.enemy_map_color = B.color
  table.insert(out, c)
  local l = table.deepcopy(data.raw.lamp["small-lamp"])
  l.name = "lp-cell-lamp"
  l.localised_name = {"entity-name.lp-cell-lamp"}
  l.hidden = true
  l.minable = nil
  l.flags = {"placeable-neutral", "placeable-enemy", "not-blueprintable", "not-deconstructable"}
  l.energy_source = {type = "void"}
  l.always_on = true
  l.light = table.deepcopy(l.light)
  l.light.color = {r = 0.35, g = 1, b = 0.2}
  l.light_when_colored = nil
  l.circuit_connector = nil
  table.insert(out, l)
end

-- The substrate's heart (the identity consult, step 4; scripts/cell.lua): Space Age's heating tower as a prop, always
-- burning (its fire and light drawn as one animation), the site's silhouette from far and its glow at night.
do
  local h = data.raw.reactor["heating-tower"]
  local layers = {}
  for _, l in ipairs(table.deepcopy(h.picture.layers)) do l.repeat_count = 24; table.insert(layers, l) end
  for _, l in ipairs(table.deepcopy(h.working_light_picture.layers)) do table.insert(layers, l) end
  table.insert(out, {type = "simple-entity-with-force", name = "lp-heating-tower", localised_name = {"entity-name.lp-heating-tower"},
    hidden = true, icon = h.icon, icon_size = h.icon_size, flags = {"placeable-neutral", "placeable-enemy", "not-blueprintable"},
    max_health = 500, collision_box = h.collision_box, selection_box = h.selection_box, render_layer = "object",
    dying_explosion = h.dying_explosion, map_color = B.color, enemy_map_color = B.color,
    animations = {layers = layers}})
end

-- The clinic (the identity consult, step 5; scripts/cell.lua): Space Age's biolab as a prop, always at work, on the
-- substrate by the heating tower. While it stands Synthexis's breeds climb its tiers (farm.lua); the one building worth
-- artillery. A military target, so turrets in reach fire on it.
do
  local b = data.raw.lab["biolab"]
  table.insert(out, {type = "simple-entity-with-force", name = "lp-clinic", localised_name = {"entity-name.lp-clinic"},
    localised_description = {"entity-description.lp-clinic"}, hidden = true, icon = b.icon, icon_size = b.icon_size,
    flags = {"placeable-neutral", "placeable-enemy", "not-blueprintable"}, max_health = 1500, is_military_target = true,
    resistances = {{type = "fire", percent = 70}, {type = "acid", percent = 50}},
    collision_box = b.collision_box, selection_box = b.selection_box, render_layer = "object",
    dying_explosion = b.dying_explosion, corpse = b.corpse, map_color = B.color, enemy_map_color = B.color,
    animations = table.deepcopy(b.on_animation)})
end

data:extend(out)

-- Every corporation's variant of a hull kind, the player's battle tank, and the base game's tank and spidertron.
for _, type in ipairs({"unit", "spider-unit", "car", "spider-vehicle"}) do
  for name, e in pairs(data.raw[type] or {}) do
    local pct = HULLS[name] or HULLS[shared.kind_of(name)]
    if pct then
      e.resistances = e.resistances or {}
      table.insert(e.resistances, {type = BITE, percent = pct})
    end
  end
end
