-- Veterancy (DESIGN.md, "Veterancy"; the user, 2026-11-10: "Veterancy system for individual units à la C&C. Rewards the
-- AI mechanics we implemented that aim for attackers to return home"). A unit's rank is its quality: the engine raises a
-- unit's health 30% a level and its damage about 48% (scenario vetprobe). Kills earn merit in the field; the rank comes
-- at home: a corporation's unit back in its garrison (pool), the player's idle at its rally point (command). A unit is
-- not raised a quality in place (order_upgrade refuses units), so a promotion is a swap, done where no job holds it.
--   merit       storage.merit[unit_number]: points banked, carried across a swap
--   on_died     credits the killer: a unit killed its value over the killer's (kill_merit), a turret its price's,
--               a spawner 1, another building BUILDING; at most to its next rank a kill
--   promote     the unit, or its promoted copy (the caller puts it where the old one was)
-- A leaf (pool reads it): shared and threat (a leaf) only.
local shared = require("__landing-party__.shared")
local threat = require("__landing-party__.scripts.threat")
local veterancy = {}

veterancy.RANKS = {{quality = "uncommon", merit = 3}, {quality = "rare", merit = 8}, {quality = "epic", merit = 16}}
local LEVEL = {normal = 0, uncommon = 1, rare = 2, epic = 3, legendary = 4}
local SPAWNER, BUILDING = 1, 0.1
-- What is not worth merit: what holds and carries (walls, belts, poles, pipes, rails), a corpse's worth of nothing.
local WORTHLESS = {wall = true, gate = true, ["transport-belt"] = true, ["underground-belt"] = true, splitter = true,
  ["electric-pole"] = true, pipe = true, ["pipe-to-ground"] = true, ["straight-rail"] = true, ["curved-rail-a"] = true,
  ["curved-rail-b"] = true, ["half-diagonal-rail"] = true, ["legacy-straight-rail"] = true, lamp = true}
local TURRETS = {["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true, ["artillery-turret"] = true,
  turret = true}

local function merit() storage.merit = storage.merit or {}; return storage.merit end

-- A unit's fighting value (the user, 2026-11-10: "Merit should earn careful balancing. Seems like a huge wave of small
-- biters should not give 1 point each if the max a behemoth will give is 4?"): its health times its damage a tick
-- (lp-unit-hit, the prototypes' own attack read in data-final-fixes), Lanchester's measure of what it takes to beat it.
-- A unit with no attack read (a spider unit) its health alone, against the killer's health alone.
local hits
local function value(name)
  hits = hits or prototypes.mod_data["lp-unit-hit"].data
  local p = prototypes.entity[name]
  local hp = p and p.get_max_health() or 1
  local h = hits[name]
  local dps = 0
  if h then for _, a in pairs(h.dmg) do dps = dps + a end; dps = dps / h.cooldown end
  return hp, dps
end
-- A turret's (or a worm's) merit (the user, 2026-11-10: "Turrets should earn though!"): what crossing one costs, in medium
-- biters lost (threat.prior_of: by kind, scaled by its owner's research; shared.PER_TURRET for a gun), each worth a
-- medium's kill to this killer. A gun turret to a trooper about two, a researched laser more.
-- A worm has no price by kind (a gun's flat one read a small worm as a behemoth's): its health in mediums, the measure
-- attempt.worth prices units by.
function veterancy.turret_merit(dead_name, dead_force, by_name)
  local p, med = prototypes.entity[dead_name], prototypes.entity["medium-biter"]
  local mediums = (p and p.type == "turret" and med) and p.get_max_health() / med.get_max_health()
    or threat.prior_of(dead_name, dead_force, shared.PER_TURRET)
  return mediums * veterancy.kill_merit("medium-biter", by_name)
end

-- A kill's merit: the victim's value over the killer's (measured, scenario vetprobe; to a trooper: a small biter 0.06, a
-- medium 0.67, a peer 1, a tank 25, a behemoth 113; to a tank, a trooper 0.04).
-- One kill raises a unit one rank at most (on_died): a last shot on what a turret line wore down is not a career.
function veterancy.kill_merit(dead_name, by_name)
  local vh, vd = value(dead_name)
  local kh, kd = value(by_name)
  if vd > 0 and kd > 0 then return (vh * vd) / (kh * kd) end
  return vh / math.max(1, kh)
end

function veterancy.rank(u) return LEVEL[u.quality and u.quality.name or "normal"] or 0 end

-- Whose units rank: the mod's own units (the corporations' and the player's), not the corporations' builders.
local function ranks(u)
  return u and u.valid and u.unit_number and (u.type == "unit" or u.type == "spider-unit") and u.name:sub(1, 3) == "lp-"
    and not (storage.crew_owner and storage.crew_owner[u.unit_number])
end

function veterancy.on_died(e)
  local dead, by = e.entity, e.cause
  if dead.unit_number and storage.merit then storage.merit[dead.unit_number] = nil end
  if storage.vet_off or not ranks(by) or dead.force == by.force then return end
  local m
  if dead.type == "unit" or dead.type == "spider-unit" then
    m = veterancy.kill_merit(dead.name, by.name)
  elseif dead.type == "unit-spawner" then
    m = SPAWNER
  elseif TURRETS[dead.type] then
    m = veterancy.turret_merit(dead.name, dead.force, by.name)
  elseif dead.prototype.is_building and not WORTHLESS[dead.type] then
    m = BUILDING
  else
    return
  end
  local t = merit()
  local had = t[by.unit_number] or 0
  -- (At most to the next rank above what it has banked.)
  local next_at
  for _, rk in ipairs(veterancy.RANKS) do if rk.merit > had then next_at = rk.merit; break end end
  t[by.unit_number] = next_at and math.min(had + m, next_at) or had + m
end

-- The rank its merit has earned: 0 to #RANKS.
local function earned(u)
  local m, r = merit()[u.unit_number] or 0, 0
  for k, rk in ipairs(veterancy.RANKS) do if m >= rk.merit then r = k end end
  return r
end
veterancy.earned = earned

-- Its promoted copy (at the rank it has earned, the same place, the same share of its health, its merit carried), the
-- old one gone; or the unit itself when it has earned nothing more, or the copy could not be placed.
function veterancy.promote(u)
  if storage.vet_off or not ranks(u) then return u end
  local r = earned(u)
  if r <= veterancy.rank(u) then return u end
  local q = veterancy.RANKS[r].quality
  local share = u.health / u.max_health
  local s, name, force, at = u.surface, u.name, u.force, u.position
  local n = s.create_entity{name = name, position = at, force = force, quality = q}
  if not n then return u end
  n.health = n.max_health * share
  local t = merit()
  t[n.unit_number], t[u.unit_number] = t[u.unit_number], nil
  if u.orientation then pcall(function() n.orientation = u.orientation end) end
  u.destroy()
  storage.promoted = (storage.promoted or 0) + 1
  if shared.notices_on() then
    rendering.draw_text{text = {"lp.rank-" .. r}, surface = s, target = {entity = n, offset = {0, -2}}, color = {1, 0.85, 0.3},
      scale = 1.2, alignment = "center", time_to_live = 180}
  end
  return n
end

-- A ranked unit's strength over its rank's normal (health times damage, the probe's: 1.3 and 1.48 a level): what the
-- AI's sums of worth count it as.
function veterancy.scale(u)
  local r = veterancy.rank(u)
  return (1 + 0.3 * r) * (1 + 0.48 * r)
end

-- The share of a raid's launched units it turns home below (ops: 0.5, a prospector's 0.7): with an Elite or a Hero in
-- it, at least ELITE_SHARE (the user: "preserving highly elite units vs throwing mass prod in the grinder").
veterancy.ELITE_SHARE = {[2] = 0.6, [3] = 0.7}
function veterancy.abort_share(members, share)
  local top = 0
  for _, u in ipairs(members or {}) do if u.valid then top = math.max(top, veterancy.rank(u)) end end
  return math.max(share, veterancy.ELITE_SHARE[math.min(top, 3)] or 0)
end

function veterancy.stats()
  local out = {promoted = storage.promoted or 0, merit_max = 0}
  for _, m in pairs(storage.merit or {}) do out.merit_max = math.max(out.merit_max, m) end
  return out
end

return veterancy
