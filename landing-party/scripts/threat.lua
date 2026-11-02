-- What a weapon is, read from its prototype: the one source every faction's reading of a defence draws on (a consult,
-- docs/reviews/2026-10-27-synthexis-perception-consult.md: five modules each kept their own table of a turret's reach,
-- vanilla numbers typed in, and a modded turret or a range researched read as nothing; the user: "not sure how robust
-- your algorithms are to other turrets ... do they take into account the varying range? how do they treat artillery?").
-- Profiles come from prototypes alone, identical on every client and every load (memoised here for that reason only);
-- what changes in play (research, ammunition, power) is read from the entity or its force when asked.
-- A leaf: it reads prototypes, entities and forces only.
local threat = {}

threat.MARGIN = 2              -- a point this far past a turret's range still counts as in it (its own size, a biter's lunge)
-- The turrets that fire on units, and the kinds of what fires: by prototype type.
threat.FIRE = {"ammo-turret", "electric-turret", "fluid-turret"}
-- And what fires besides: armed units (a corporation's railgunners killed 202 of a wave of 265 marching past its camp, its
-- fire read from turrets only; 2026-10-27).
threat.ARMED = {"ammo-turret", "electric-turret", "fluid-turret", "unit"}
local KIND = {["ammo-turret"] = "ammo", ["electric-turret"] = "power", ["fluid-turret"] = "fluid",
  ["artillery-turret"] = "artillery", ["artillery-wagon"] = "artillery", turret = "worm", unit = "mobile", car = "mobile",
  ["spider-vehicle"] = "mobile"}
-- What leaves it silent, by its status (a dry gun, a dark laser, a flamethrower with nothing to burn).
local SILENT = {}
for _, k in ipairs({"no_ammo", "no_power", "no_input_fluid", "missing_required_fluid", "disabled", "disabled_by_script",
  "disabled_by_control_behavior", "frozen", "recharging_after_power_outage"}) do
  if defines.entity_status[k] then SILENT[defines.entity_status[k]] = true end
end

local profiles = {}
-- name -> {kind, reach (its range, plus MARGIN), min_reach, cooldown (ticks a shot), dmg (its ammunition category, or
-- its kind), artillery (its range, before research)}; nil for what does not fight.
function threat.profile(name)
  local p = profiles[name]
  if p ~= nil then return p or nil end
  local proto = prototypes.entity[name]
  local ap = proto and proto.attack_parameters
  local kind = proto and KIND[proto.type]
  if not (kind and (ap or proto.turret_range)) then profiles[name] = false; return nil end
  p = {kind = kind, reach = (ap and ap.range or 0) + threat.MARGIN, min_reach = ap and ap.min_range or 0,
    cooldown = ap and ap.cooldown or 60, dmg = ap and ap.ammo_categories and ap.ammo_categories[1] or kind,
    -- (Artillery's own range: turret_range where its prototype gives one, else its attack's.)
    artillery = kind == "artillery" and (proto.turret_range or (ap and ap.range)) or nil}
  -- A fluid turret's arc (the share of a circle it turns through about its facing) and its burn (data-final-fixes: lp-fire).
  local f = prototypes.mod_data["lp-fire"] and prototypes.mod_data["lp-fire"].data[name]
  if f then p.arc, p.burn = f.arc, f.hits > 0 and f or nil
  elseif ap and ap.turn_range and ap.turn_range < 1 then p.arc = ap.turn_range end
  profiles[name] = p
  return p
end

-- Whether a unit of this breed dies of the burn alone (its health no more than the burn's hits, each less what it resists).
local burnt = {}
function threat.burns(burn, name)
  local key = name .. "|" .. burn.hit .. "|" .. burn.hits
  local v = burnt[key]
  if v == nil then
    local u = prototypes.entity[name]
    local r = u and u.resistances and u.resistances[burn.type]
    local per = math.max(0, burn.hit - (r and r.decrease or 0)) * (1 - (r and r.percent or 0))
    v = u ~= nil and u.get_max_health() <= burn.hits * per
    burnt[key] = v
  end
  return v
end

-- How far it reaches (artillery: its range with its force's research).
function threat.reach(e)
  local p = threat.profile(e.name)
  if not p then return 0 end
  if p.artillery then return p.artillery * (1 + e.force.artillery_range_modifier) end
  return p.reach
end

-- What a unit's attack deals a second (data-final-fixes.lua: lp-bites, from its prototype; 0 for one that does not attack).
local bites
function threat.bite(name)
  bites = bites or prototypes.mod_data["lp-bites"].data
  return bites[name] or 0
end

-- Whether it fires now (not dry, not dark, not idle for want of fluid; a laser short of power still fires, slower).
function threat.firing(e) return not SILENT[e.status] end

local far
-- The longest reach of any turret that fires on units (plus MARGIN): how far round a point to look for what covers it.
function threat.far()
  if far then return far end
  far = 0
  for name in pairs(prototypes.get_entity_filtered{{filter = "type", type = threat.FIRE}}) do
    local p = threat.profile(name)
    if p and p.reach > far then far = p.reach end
  end
  return far
end

-- How many of the firing turrets of `forces` cover pos, each by its own reach and `spare` tiles more (at most `most`).
function threat.covering(surface, pos, forces, most, spare)
  local x, y = pos.x or pos[1], pos.y or pos[2]
  local n = 0
  spare = spare or 0
  for _, t in ipairs(surface.find_entities_filtered{position = {x, y}, radius = threat.far() + spare, type = threat.FIRE,
    force = forces}) do
    local r = threat.reach(t) + spare
    if (t.position.x - x) ^ 2 + (t.position.y - y) ^ 2 <= r * r and threat.firing(t) then
      n = n + 1
      if most and n >= most then return n end
    end
  end
  return n
end

-- What it should cost before any is learned (know.price): `base`, a mind's per_turret, alike for every prototype. (Scaled
-- by its force's research it started near 11 a gun on a deathworld whose guns cost 4.5 to 8 when crossed, and the farm
-- read its soft outpost as a poor bet: the research is in what crossing them costs, learned. A prior by kind awaits the
-- arena's numbers: the perception consult, step 2.)
--
-- Lasers and flamethrowers by kind, scaled by their force's research (damage, rate of fire, turret attack): a megabase's
-- laser kills a medium biter a shot, five a second, and crossing one cost its waves 15.4 learned; at the flat prior of 6
-- its plans read nw's laser walls at under half that, and a wave of 31 went at them, 28 dead (2026-10-28). The base at no
-- research is that price over nw's research (lasers four times the damage at 3.2 times the rate: 15.4 / 12.8; flamethrowers
-- 2.6 times by ammunition and 2.6 by turret: 25.5 / 6.8). Guns stay at `base` (the note above).
local BASE = {power = 1.2}
-- A flamethrower burns a share of the crowd that crosses it, and that share is near alike whatever its research: what one
-- cost its waves, measured, was 16.5 unresearched (a corporation's, a herd of 98) and 21 to 25.5 at a megabase's full
-- research (herds of 120 to 280). Scaled by research as a laser is, a corporation's camp of four read at 3.8 each, and a
-- siege walked past it and lost 66 there (2026-10-28).
local FLAME = 17
-- Armed units by name: the bred mediums each killed in the arena (unit_prior.lua, generated by scripts/unit_prior.py; at
-- the flat prior a corporation's camp of railgunners and tanks read as cheap to walk past).
local UNIT_PRIOR = require("__landing-party__.scripts.unit_prior")
function threat.prior(e, base) return threat.prior_of(e.name, e.force, base) end
-- The same by prototype name and force.
function threat.prior_of(name, f, base)
  if UNIT_PRIOR[name] then return UNIT_PRIOR[name] end
  local p = threat.profile(name)
  if p and p.kind == "fluid" then return FLAME end
  local b = p and BASE[p.kind]
  if not b then return base end
  f = type(f) == "string" and game.forces[f] or f
  if not f then return b end
  -- (Its ammunition category, where its prototype names one: a laser's is "laser", a flamethrower's "flamethrower".)
  local m = 1 + f.get_turret_attack_modifier(name)
  if prototypes.ammo_category[p.dmg] then
    m = m * (1 + f.get_ammo_damage_modifier(p.dmg)) * (1 + f.get_gun_speed_modifier(p.dmg))
  end
  return b * m
end

-- The longest reach of a force's artillery (its prototypes' ranges with its research): how far its guns can shell.
function threat.artillery_reach(force)
  local best = 0
  for name in pairs(prototypes.get_entity_filtered{{filter = "type", type = {"artillery-turret", "artillery-wagon"}}}) do
    local p = threat.profile(name)
    if p and p.artillery and p.artillery > best then best = p.artillery end
  end
  return best * (1 + force.artillery_range_modifier)
end

-- How far an artillery shell's blast reaches (data-final-fixes: lp-splash), 0 for one it does not know.
local splash
function threat.splash(name)
  splash = splash or prototypes.mod_data["lp-splash"].data
  return splash[name] or 0
end

local foe_splash
-- The widest blast of any artillery shell but Landing Party's own: how far a shell aimed at one piece reaches round it.
function threat.foe_splash()
  if foe_splash then return foe_splash end
  foe_splash = 0
  splash = splash or prototypes.mod_data["lp-splash"].data
  for name, r in pairs(splash) do
    if name:sub(1, 3) ~= "lp-" and r > foe_splash then foe_splash = r end
  end
  return foe_splash
end

-- How far round a spawner its biters come at what they see: the farthest sight of its result units, every evolution
-- (vanilla's 30; its idle biters stand at it). With its spawning radius added (40) routes kept so wide of a line of
-- spawners that a raid's straggler fell 49 tiles behind and the raid turned back (scenario pact, seed 12345).
local spawner_reaches = {}
local function spawner_reach(name)
  local r = spawner_reaches[name]
  if r then return r end
  local proto = prototypes.entity[name]
  local sight = 0
  for _, ru in ipairs(proto and proto.result_units or {}) do
    local u = prototypes.entity[ru.unit]
    if u and u.vision_distance and u.vision_distance > sight then sight = u.vision_distance end
  end
  r = sight
  spawner_reaches[name] = r
  return r
end

-- How far a nest is a danger: a worm by its range (plus MARGIN), a spawner by its biters' (spawner_reach).
function threat.nest_reach(e)
  if e.type == "unit-spawner" then return spawner_reach(e.name) end
  return threat.reach(e)
end

local nest_far
-- The farthest any nest is a danger (every spawner and worm prototype): how far round a point to look for one.
function threat.nest_far()
  if nest_far then return nest_far end
  nest_far = 0
  for name, proto in pairs(prototypes.get_entity_filtered{{filter = "type", type = {"unit-spawner", "turret"}}}) do
    local r = proto.type == "unit-spawner" and spawner_reach(name) or (threat.profile(name) or {reach = 0}).reach
    if r > nest_far then nest_far = r end
  end
  return nest_far
end

local sight
-- The farthest any spawner's biter sees: how near a foe's unit is already in the fight (spawner_reach's widest).
function threat.biter_sight()
  if sight then return sight end
  sight = 0
  for name in pairs(prototypes.get_entity_filtered{{filter = "type", type = "unit-spawner"}}) do
    local proto = prototypes.entity[name]
    for _, ru in ipairs(proto.result_units or {}) do
      local u = prototypes.entity[ru.unit]
      if u and u.vision_distance and u.vision_distance > sight then sight = u.vision_distance end
    end
  end
  return sight
end

-- What one shell of this artillery projectile does to an entity where it lands: its damage by type (data-final-fixes:
-- lp-blow) less the entity's resistances (its prototype's). 0 for a shell it does not know.
local blows
function threat.blow(proj, e)
  blows = blows or prototypes.mod_data["lp-blow"].data
  local d = blows[proj]
  if not d then return 0 end
  local res = prototypes.entity[e.name] and prototypes.entity[e.name].resistances or {}
  local total = 0
  for t, amount in pairs(d) do
    local r = res[t]
    total = total + math.max(0, amount - (r and r.decrease or 0)) * (1 - (r and r.percent or 0))
  end
  return total
end
-- How many such shells it takes (at least one).
function threat.shells_for(proj, e)
  local b = threat.blow(proj, e)
  return b > 0 and math.max(1, math.ceil(e.health / b)) or 1
end

return threat
