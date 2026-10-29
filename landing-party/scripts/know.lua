-- What each faction knows (the faction AI's knowledge layer; docs/reviews/2026-10-23-faction-ai-audit.md, step 2). One
-- record per faction, shared by its settlements (a corporation's id, or "biotech" for Synthexis), of what it has lived
-- through: its losses (who killed what of it, how, where) and, from them, its grievance against each force, fading by
-- half-life. Sightings are read from its settlements' intel (merged, not copied). Decisions read this, never the four
-- ledgers it replaces piecemeal (the tree's, the reprisal's wrongs, the hazard log, the death markers).
-- A leaf: reads storage and shared only.
local shared = require("__landing-party__.shared")

local know = {}

local WINDOW = 60 * 3600        -- losses kept this long
local LOSSES_MAX = 400
local GRIEVE_HALF = 20 * 3600   -- a grievance halves in this long

-- What a killer deals, by its type or name: the plate that would answer it (moved from rd.lua, its first reader).
local DAMAGE = {["ammo-turret"] = "physical", character = "physical", car = "physical", ["electric-turret"] = "laser",
  ["fluid-turret"] = "fire", ["artillery-turret"] = "explosion", ["artillery-wagon"] = "explosion",
  -- The player's combat robots (2026-10-23: unrecorded until anti-air was bought on what kills from the air).
  ["combat-robot"] = "physical"}
local DAMAGE_BY_NAME = {["lp-trooper"] = "physical", ["lp-breacher"] = "explosion", ["lp-battle-tank"] = "explosion",
  ["lp-rocket-trooper"] = "explosion", ["lp-flame-trooper"] = "fire", ["lp-aegis"] = "lp-rail", ["lp-harrier"] = "physical", ["lp-scavenger"] = "explosion",
  ["lp-laser-drone"] = "laser"}
know.DAMAGE, know.DAMAGE_BY_NAME = DAMAGE, DAMAGE_BY_NAME

local function st()
  storage.know = storage.know or {}
  return storage.know
end

-- The faction a force belongs to: a corporation's id, "biotech", or nil (players, biters, neutral).
function know.faction_of(force_name)
  if force_name == shared.BIOTECH.force then return "biotech" end
  for id, c in pairs(shared.CORPS) do if c.force == force_name then return id end end
end

function know.of(key)
  local s = st()
  s[key] = s[key] or {losses = {}, grievance = {}}
  return s[key]
end

-- What a weapon of a foe has cost the faction, in its own lost, per prototype (a gun turret, a laser, a modded one each
-- its own: one price for every turret could not learn that a laser line is dearer than a gun line; the perception
-- consult, docs/reviews/2026-10-27-synthexis-perception-consult.md). Learned from what crossing them cost, PRICE_LEARN of
-- each new sample, from the prior its first sample replaces. nil: nothing learned yet.
know.PRICE_LEARN, know.PRICE_MIN, know.PRICE_MAX = 0.4, 1, 40
function know.price(key, foe, proto)
  local p = know.of(key).price
  p = p and p[foe] and p[foe][proto]
  return p and p.per
end
-- How far its reading of the way in falls short, per foe: what crossing cost it (march, breach, way out) over what it
-- expected (costmap.way_in, there and back), learned at each wave that broke in (PRICE_LEARN of each; 1 before any): the
-- cost map's fire scaled by it when its mind calibrates (a deathworld's waves lost twice what they expected crossing, its
-- prices learned at the breach alone; 2026-10-27). Clamped to SCALE_MIN, SCALE_MAX.
know.SCALE_MIN, know.SCALE_MAX = 0.5, 4
function know.scale(key, foe)
  local s = know.of(key).scale
  return s and s[foe] or 1
end
function know.learn_scale(key, foe, sample)
  local k = know.of(key)
  k.scale = k.scale or {}
  local old = k.scale[foe]
  sample = math.min(know.SCALE_MAX, math.max(know.SCALE_MIN, sample))
  k.scale[foe] = old and old + (sample - old) * know.PRICE_LEARN or sample
  return k.scale[foe]
end

-- prior: what it priced it at before (its first sample moves from there, PRICE_LEARN of the way, not to the sample: one
-- wave wiped out at 15 lasers made a laser 2.5 from 15.4 at a stroke; 2026-10-28). floor: the sample is a least (a wave
-- that lost all it had could have lost more: it raises a price, never lowers it).
function know.learn_price(key, foe, proto, sample, prior, floor)
  local k = know.of(key)
  k.price = k.price or {}
  k.price[foe] = k.price[foe] or {}
  local p = k.price[foe][proto]
  sample = math.min(know.PRICE_MAX, math.max(know.PRICE_MIN, sample))
  if not p and prior then p = {per = prior, n = 0} end
  if floor and p and sample <= p.per then return p.per end
  if not p then p = {per = sample, n = 0} else p.per = p.per + (sample - p.per) * know.PRICE_LEARN end
  p.n = p.n + 1
  k.price[foe][proto] = p
  return p.per
end

-- What a thing of a faction is worth to it: a unit's or building's price (parts; a breed's, biomass), else 1.
local function worth(name)
  local kind = shared.kind_of(name)
  if shared.BREEDS[name] then return shared.BREEDS[name].cost end
  if shared.units[kind] then return shared.units[kind].cost end
  return (shared.cost and shared.cost[kind]) or 1
end

local function decayed(g, tick)
  if not g then return 0 end
  return g.v * 0.5 ^ ((tick - g.t) / GRIEVE_HALF)
end

-- Whether a place is a corporation's home ground: within one of its camps' claims and HOME_MARGIN beyond.
local HOME_MARGIN = 60
function know.at_home(key, pos)
  for _, b in pairs(storage.bases or {}) do
    if b.corp == key and not b.fallen and b.lander and b.lander.valid then
      local r = (b.claim_radius or 150) + HOME_MARGIN
      local o = b.lander.position
      if (o.x - (pos.x or pos[1])) ^ 2 + (o.y - (pos.y or pos[2])) ^ 2 <= r * r then return true end
    end
  end
  return false
end

-- A unit's death is a wrong done to its faction only at home and off any errand of its own: its convoy escorts and
-- patrols shot walking past Grubstake's turrets far from home made Kessler-Hayashi's reprisals ("4 lost in 2 s"), and
-- Grubstake's camp was gone in two hours (system 4242, 2026-10-24).
function know.resented(key, ent)
  return know.at_home(key, ent.position) and not know.on_errand(key, ent)
end

-- Whether a unit died on an errand of its own: a member of one of its faction's operations (a raid, a siege, a strip
-- camp). What a faction's own attacks cost it is not a wrong done to it: resented, it fed an escalation (rivals,
-- 2026-10-24: Kessler-Hayashi's raids on Grubstake lost 4, then 5, 22, 35, 70 units to its defenders, each loss a
-- reprisal, each reprisal a bigger raid, until Grubstake's camp was gone). Judged by distance from home first (its
-- claim and 60 tiles), it failed where the two camps stood 213 tiles apart: the raiders died "at home" (system 12345).
-- Synthexis's units are all on errands (its waves): never resented.
-- (A set of the units on errands, built once a tick per faction: the damage handler asks on every hit.)
local errands = {tick = -1, sets = {}}
function know.on_errand(key, ent)
  if key == "biotech" then return true end
  if errands.tick ~= game.tick then errands.tick, errands.sets = game.tick, {} end
  local set = errands.sets[key]
  if not set then
    set = {}
    for _, b in pairs(storage.bases or {}) do
      if b.corp == key then
        for _, u in ipairs(b.op and b.op.members or {}) do if u.valid and u.unit_number then set[u.unit_number] = true end end
        -- On its way back from one (pool.give): its raid over, it was still in the rival's ground, and a reprisal came
        -- 52 ticks after "raid razed nothing" (rivals, 2026-10-24).
        for _, u in ipairs(b.returning or {}) do if u.valid and u.unit_number then set[u.unit_number] = true end end
      end
    end
    errands.sets[key] = set
  end
  return ent.unit_number ~= nil and set[ent.unit_number] == true
end

-- A death (control.lua, on_entity_died): recorded when the dead belonged to a faction.
function know.loss(e)
  local ent = e.entity
  local key = know.faction_of(ent.force.name)
  if not key then return end
  local cause, by = e.cause and e.cause.valid and e.cause or nil, e.force and e.force.name or "none"
  local dmg, killer
  if cause then
    local kind = shared.kind_of(cause.name)
    local biter = shared.is_biters(cause.force.name)
    dmg = DAMAGE_BY_NAME[kind] or DAMAGE[cause.type]
    if biter then dmg = (cause.type == "turret" or cause.name:find("spitter", 1, true)) and "acid" or "physical" end
    -- Who killed it, for triggers on the killer: a character, a vehicle (cars and tanks), else its kind.
    killer = biter and "biter" or cause.type == "character" and "character" or (cause.type == "car" and "vehicle") or kind
  end
  local k = know.of(key)
  local value = worth(ent.name)
  table.insert(k.losses, {tick = game.tick, force = by, killer = killer, damage = dmg, kind = shared.kind_of(ent.name),
    unit = ent.type == "unit" or ent.type == "spider-unit", pos = {ent.position.x, ent.position.y}, value = value})
  if #k.losses > LOSSES_MAX then table.remove(k.losses, 1) end
  local unit = ent.type == "unit" or ent.type == "spider-unit"
  if by ~= "none" and by ~= "neutral" and by ~= ent.force.name and not (unit and not know.resented(key, ent)) then
    local g = k.grievance[by]
    k.grievance[by] = {v = decayed(g, game.tick) + value, t = game.tick}
  end
end

-- Its losses within `window` ticks (WINDOW at most), newest last; `filter(entry)` keeps those it returns true for.
function know.losses(key, window, filter)
  local k = know.of(key)
  local since = game.tick - math.min(window or WINDOW, WINDOW)
  local out = {}
  for i = #k.losses, 1, -1 do
    local l = k.losses[i]
    if l.tick < since then break end
    if not filter or filter(l) then out[#out + 1] = l end
  end
  for i = 1, math.floor(#out / 2) do out[i], out[#out + 1 - i] = out[#out + 1 - i], out[i] end
  return out
end

-- What it holds against a force now (value lost to it, fading by half-life).
function know.grievance(key, force)
  return decayed(know.of(key).grievance[force], game.tick)
end

-- What its settlements have seen, merged by cell (the freshest sighting of each): a corporation's (b.intel.targets).
function know.sightings(key)
  local out = {}
  for _, b in pairs(storage.bases or {}) do
    if b.corp == key and not b.fallen and b.intel then
      for cell, t in pairs(b.intel.targets or {}) do
        local have = out[cell]
        if not have or (t.seen or 0) > (have.seen or 0) then out[cell] = t end
      end
    end
  end
  return out
end

-- Old losses out (every few minutes).
function know.tick(tick)
  if tick % 3600 ~= 120 then return end
  for _, k in pairs(st()) do
    local keep = {}
    for _, l in ipairs(k.losses) do if tick - l.tick <= WINDOW then keep[#keep + 1] = l end end
    k.losses = keep
    for f, g in pairs(k.grievance) do if decayed(g, tick) < 1 then k.grievance[f] = nil end end
  end
end

-- Dev and tests: each faction's losses by killer force and its grievances now.
function know.state()
  local out = {}
  for key, k in pairs(st()) do
    local by = {}
    for _, l in ipairs(k.losses) do by[l.force] = (by[l.force] or 0) + 1 end
    local g = {}
    for f in pairs(k.grievance) do g[f] = math.floor(know.grievance(key, f) + 0.5) end
    out[key] = {losses = #k.losses, by = by, grievance = g}
  end
  return out
end

return know
