-- Corporate research (docs/reviews/2026-10-14-corporate-rd-consult.md; the user: "a 'smart' parallel to biter
-- evolution", so raids need not grow a hundredfold against a researched player). A share of each corporation's
-- exports goes to a fund (FUND_SHARE, capped at FUND_CAP); every CHOICE_TICKS it buys at most one thing, its choice
-- read from what it has been losing to:
--   weapons  a damage level for one of the ammunition categories its units fire (LEVEL_COST x k parts for level k,
--            +LEVEL_DAMAGE each, on the corporation's force: units and turrets alike), at most the player's era + 1
--   plate    when ten or more of its units died in the window and one damage type killed half of them, a plate
--            against it for the kind that died most (PLATE_COST, PLATE_SWITCH to change one); from the player's era 1.
--            A plate is a prototype (shared.PLATES): the depots build the plated kind from then on (rd.unit); units
--            already in the field keep what they have.
-- Order: two raids turned back for want of force in the window buy weapons; else a plate if one is called for; else
-- weapons.
-- Its own units' upgrades divide the defence it reads at a target (ops: rd.strength), so raids stay a size a
-- garrison can field. The ledger: units lost in the last WINDOW_TICKS by the damage the killer deals, and raids
-- turned back for want of force.
local shared = require("__landing-party__.shared")

local rd = {}

local FUND_SHARE, FUND_CAP = 0.3, 10000
local LEVEL_COST, LEVEL_DAMAGE, MAX_LEVEL = 400, 0.2, 5
local CHOICE_TICKS = 10 * 3600
local PLATE_COST, PLATE_SWITCH, PLATE_LOSSES = 1500, 1000, 10
local WINDOW_TICKS = 30 * 3600
-- What each unit kind fires (units.lua).
rd.CATEGORY = {["lp-infantry"] = "bullet", ["lp-buggy"] = "bullet", ["lp-harrier"] = "bullet",
  ["lp-tank"] = "cannon-shell", ["lp-walker"] = "rocket"}
-- Each corporation's own infantry (units.lua): Serenity's Line troopers fire lasers, Grubstake's Shotgun hands shells.
rd.CORP_CATEGORY = {serenity = {["lp-infantry"] = "laser"}, grubstake = {["lp-infantry"] = "shotgun-shell"}}
-- What a killer deals, by its type or name: the plate that would answer it (biters are not counted).
local DAMAGE = {["ammo-turret"] = "physical", character = "physical", car = "physical", ["electric-turret"] = "laser",
  ["fluid-turret"] = "fire", ["artillery-turret"] = "explosion", ["artillery-wagon"] = "explosion"}
local DAMAGE_BY_NAME = {["lp-trooper"] = "physical", ["lp-breacher"] = "explosion", ["lp-battle-tank"] = "explosion"}

function rd.state(corp)
  storage.corps = storage.corps or {}
  storage.corps[corp] = storage.corps[corp] or {level = 0, exported = 0}
  local d = storage.corps[corp]
  d.tech = d.tech or {fund = 0, weapons = {}, losses = {}, turned_back = {}, bought = 0}
  d.tech.plate = d.tech.plate or {}
  return d.tech
end

-- Exports feed the fund (faction.develop), apart from the level they also raise.
function rd.fund(corp, parts)
  local t = rd.state(corp)
  t.fund = math.min(FUND_CAP, t.fund + FUND_SHARE * parts)
end

local function prune(list)
  for i = #list, 1, -1 do if game.tick - list[i].tick > WINDOW_TICKS then table.remove(list, i) end end
end

-- A unit of b's lost to cause (control.lua, on_entity_died).
function rd.tally(b, cause, dead)
  if not (cause and cause.valid) or cause.force.name == "enemy" then return end
  local kind = shared.kind_of(cause.name)
  local dmg = DAMAGE_BY_NAME[kind] or DAMAGE[cause.type]
  if not dmg then return end
  local t = rd.state(b.corp)
  table.insert(t.losses, {tick = game.tick, damage = dmg, kind = shared.kind_of(dead)})
  if #t.losses > 200 then table.remove(t.losses, 1) end
end

-- A raid that turned back for want of force (ops).
function rd.turned_back(b)
  local t = rd.state(b.corp)
  table.insert(t.turned_back, {tick = game.tick})
end

-- The categories a corporation's units fire, heaviest in its mix first.
local function categories(corp)
  local w = {}
  for name, k in pairs(shared.CORPS[corp].mix or {}) do
    local c = (rd.CORP_CATEGORY[corp] or {})[name] or rd.CATEGORY[name]
    if c then w[c] = (w[c] or 0) + k end
  end
  local out = {}
  for c in pairs(w) do table.insert(out, c) end
  table.sort(out, function(a, b) return w[a] > w[b] or (w[a] == w[b] and a < b) end)
  return out
end
rd.categories = categories

-- The prototype a depot builds for a kind: plated once its corporation bought the plate.
function rd.unit(corp, kind)
  local d = storage.corps and storage.corps[corp]
  local plate = d and d.tech and d.tech.plate and d.tech.plate[kind]
  return shared.plated(corp, kind, plate)
end

-- What its units have over the defence they read: (1 + its damage modifier for its main category), times 1.4 when
-- one of its plates answers the damage the target's turrets mostly deal (dmg, from ops.weigh), 1.15 for any plate.
function rd.strength(corp, dmg)
  local f = game.forces[shared.CORPS[corp].force]
  local main = categories(corp)[1]
  local s = 1 + ((f and main) and f.get_ammo_damage_modifier(main) or 0)
  local plates = storage.corps and storage.corps[corp] and storage.corps[corp].tech and storage.corps[corp].tech.plate
  local a = 1
  for _, p in pairs(plates or {}) do
    if dmg and p == dmg then a = 1.4; break end
    a = 1.15
  end
  return s * a
end

-- The highest era among the player forces it faces (the cap: a player who stops researching freezes them).
local function player_era()
  if storage.era_override then return storage.era_override end
  local e = 0
  for _, f in pairs(game.forces) do
    if #f.players > 0 or f.name == "player" then e = math.max(e, rd.era and rd.era(f) or 0) end
  end
  return e
end

local function notify(corp, key, ...)
  for _, f in pairs(game.forces) do
    if #f.players > 0 and not shared.is_corp(f.name) then f.print({key, shared.corp_label(corp), ...}) end
  end
end

-- One purchase, if the fund affords it and the cap allows: the main category's next level, or, once it is at the
-- cap, the next category's.
local function buy_weapons(corp, t, cap)
  local f = game.forces[shared.CORPS[corp].force]
  for _, c in ipairs(categories(corp)) do
    local k = (t.weapons[c] or 0) + 1
    if k <= math.min(cap, MAX_LEVEL) then
      if t.fund < LEVEL_COST * k then return false end
      t.fund = t.fund - LEVEL_COST * k
      t.weapons[c] = k
      f.set_ammo_damage_modifier(c, LEVEL_DAMAGE * k)
      t.bought = t.bought + 1
      notify(corp, "lp.rd-weapons", {"lp.ammo-" .. c}, k)
      if rd.trace then rd.trace(corp, string.format("research: %s level %d (fund %d)", c, k, t.fund)) end
      return true
    end
  end
  return false
end

-- The plate its losses call for: the damage type behind half of PLATE_LOSSES or more deaths (explosion has no plate:
-- artillery and battle tanks stay the player's trump), for the plated kind that died most.
local function plate_called(t)
  if #t.losses < PLATE_LOSSES then return end
  local by, kinds = {}, {}
  for _, l in ipairs(t.losses) do by[l.damage] = (by[l.damage] or 0) + 1 end
  local top, tn
  for dmg, n in pairs(by) do if not tn or n > tn or (n == tn and dmg < top) then top, tn = dmg, n end end
  if not shared.PLATES[top] or 2 * tn < #t.losses then return end
  for _, l in ipairs(t.losses) do if l.damage == top then kinds[l.kind] = (kinds[l.kind] or 0) + 1 end end
  local kind, kn
  for _, k in ipairs(shared.PLATED) do
    if (kinds[k] or 0) > 0 and (not kn or kinds[k] > kn) then kind, kn = k, kinds[k] end
  end
  if kind and t.plate[kind] ~= top then return kind, top end
end

local function buy_plate(corp, t, kind, dmg)
  local cost = t.plate[kind] and PLATE_SWITCH or PLATE_COST
  if t.fund < cost then return false end
  t.fund = t.fund - cost
  t.plate[kind] = dmg
  t.bought = t.bought + 1
  notify(corp, "lp.rd-plate", {"lp.plate-" .. dmg}, {"entity-name." .. kind})
  if rd.trace then rd.trace(corp, string.format("research: %s plate for %s (fund %d)", dmg, kind, t.fund)) end
  return true
end

function rd.choose(corp)
  local d = storage.corps and storage.corps[corp]
  if not d or d.withdrawing then return end
  local t = rd.state(corp)
  prune(t.losses)
  prune(t.turned_back)
  local era = player_era()
  if #t.turned_back < 2 and era >= 1 then
    local kind, dmg = plate_called(t)
    if kind then return buy_plate(corp, t, kind, dmg) end
  end
  buy_weapons(corp, t, era + 1)
end

function rd.tick(tick)
  local every = storage.rd_fast and 3600 or CHOICE_TICKS
  if tick % every ~= 1234 % every then return end
  for corp in pairs(shared.CORPS) do
    if storage.corps and storage.corps[corp] then rd.choose(corp) end
  end
end

-- Tests: a research history set outright ({weapons = {cat = level}, plate = {kind = plate}}).
function rd.set(corp, tech)
  local t = rd.state(corp)
  local f = game.forces[shared.CORPS[corp].force]
  for c, k in pairs(tech.weapons or {}) do
    t.weapons[c] = k
    f.set_ammo_damage_modifier(c, LEVEL_DAMAGE * k)
  end
  for kind, p in pairs(tech.plate or {}) do t.plate[kind] = p end
end

-- For stats and tests.
function rd.summary(corp)
  local t = rd.state(corp)
  local by = {}
  prune(t.losses)
  for _, l in ipairs(t.losses) do by[l.damage] = (by[l.damage] or 0) + 1 end
  return {fund = t.fund, weapons = t.weapons, plate = t.plate, lost_by = by, turned_back = #t.turned_back,
    bought = t.bought, strength = rd.strength(corp)}
end

return rd
