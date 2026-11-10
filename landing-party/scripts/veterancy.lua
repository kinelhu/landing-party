-- Veterancy (DESIGN.md, "Veterancy"; the user, 2026-11-10: "Veterancy system for individual units à la C&C. Rewards the
-- AI mechanics we implemented that aim for attackers to return home"). A unit's rank is its quality: the engine raises a
-- unit's health 30% a level and its damage about 48% (scenario vetprobe). Kills earn merit in the field; the rank comes
-- at home: a corporation's unit back in its garrison (pool), the player's idle at its rally point (command). A unit is
-- not raised a quality in place (order_upgrade refuses units), so a promotion is a swap, done where no job holds it.
--   merit       storage.merit[unit_number]: points banked, carried across a swap
--   on_died     credits the killer: a unit killed its strength over the killer's, a building HALF, a spawner 1
--   promote     the unit, or its promoted copy (the caller puts it where the old one was)
-- A leaf (pool reads it): shared only.
local shared = require("__landing-party__.shared")
local veterancy = {}

veterancy.RANKS = {{quality = "uncommon", merit = 3}, {quality = "rare", merit = 8}, {quality = "epic", merit = 16}}
local LEVEL = {normal = 0, uncommon = 1, rare = 2, epic = 3, legendary = 4}
local BUILDING, SPAWNER, CAP = 0.5, 1, 4     -- merit for a building, a spawner; at most CAP for one kill

local function merit() storage.merit = storage.merit or {}; return storage.merit end

-- A unit's strength: its prototype's health (attempt.worth's measure, without its medium-biter scale, which cancels).
local function strength(name)
  local p = prototypes.entity[name]
  return p and p.get_max_health() or 1
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
    m = math.min(CAP, strength(dead.name) / math.max(1, strength(by.name)))
  elseif dead.type == "unit-spawner" then
    m = SPAWNER
  elseif dead.prototype.is_building then
    m = BUILDING
  else
    return
  end
  local t = merit()
  t[by.unit_number] = (t[by.unit_number] or 0) + m
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

function veterancy.stats()
  local out = {promoted = storage.promoted or 0, merit_max = 0}
  for _, m in pairs(storage.merit or {}) do out.merit_max = math.max(out.merit_max, m) end
  return out
end

return veterancy
