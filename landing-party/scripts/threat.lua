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

return threat
