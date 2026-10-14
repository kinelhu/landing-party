-- Corporate research (docs/reviews/2026-10-14-corporate-rd-consult.md; the user: "a 'smart' parallel to biter
-- evolution", so raids need not grow a hundredfold against a researched player). A share of each corporation's
-- exports goes to a fund (FUND_SHARE, capped at FUND_CAP); every CHOICE_TICKS it buys at most one thing, its choice
-- read from what it has been losing to:
--   weapons  a damage level for one of the ammunition categories its units fire (LEVEL_COST x k parts for level k,
--            +LEVEL_DAMAGE each, on the corporation's force: units and turrets alike), at most the player's era + 1
-- Its own units' upgrades divide the defence it reads at a target (ops: rd.strength), so raids stay a size a
-- garrison can field. The ledger: units lost in the last WINDOW_TICKS by the damage the killer deals, and raids
-- turned back for want of force.
local shared = require("__landing-party__.shared")

local rd = {}

local FUND_SHARE, FUND_CAP = 0.3, 10000
local LEVEL_COST, LEVEL_DAMAGE, MAX_LEVEL = 400, 0.2, 5
local CHOICE_TICKS = 10 * 3600
local WINDOW_TICKS = 30 * 3600
-- What each unit kind fires (units.lua).
rd.CATEGORY = {["lp-infantry"] = "bullet", ["lp-buggy"] = "bullet", ["lp-harrier"] = "bullet",
  ["lp-tank"] = "cannon-shell", ["lp-walker"] = "rocket"}
-- What a killer deals, by its type or name: the plate that would answer it (biters are not counted).
local DAMAGE = {["ammo-turret"] = "physical", character = "physical", car = "physical", ["electric-turret"] = "laser",
  ["fluid-turret"] = "fire", ["artillery-turret"] = "explosion", ["artillery-wagon"] = "explosion"}
local DAMAGE_BY_NAME = {["lp-trooper"] = "physical", ["lp-breacher"] = "explosion", ["lp-battle-tank"] = "explosion"}

function rd.state(corp)
  storage.corps = storage.corps or {}
  storage.corps[corp] = storage.corps[corp] or {level = 0, exported = 0}
  local d = storage.corps[corp]
  d.tech = d.tech or {fund = 0, weapons = {}, losses = {}, turned_back = {}, bought = 0}
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
    local c = rd.CATEGORY[name]
    if c then w[c] = (w[c] or 0) + k end
  end
  local out = {}
  for c in pairs(w) do table.insert(out, c) end
  table.sort(out, function(a, b) return w[a] > w[b] or (w[a] == w[b] and a < b) end)
  return out
end
rd.categories = categories

-- What its units have over the defence they read: (1 + its damage modifier for its main category).
function rd.strength(corp)
  local f = game.forces[shared.CORPS[corp].force]
  local main = categories(corp)[1]
  return 1 + ((f and main) and f.get_ammo_damage_modifier(main) or 0)
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

function rd.choose(corp)
  local d = storage.corps and storage.corps[corp]
  if not d or d.withdrawing then return end
  local t = rd.state(corp)
  prune(t.losses)
  prune(t.turned_back)
  buy_weapons(corp, t, player_era() + 1)
end

function rd.tick(tick)
  local every = storage.rd_fast and 3600 or CHOICE_TICKS
  if tick % every ~= 1234 % every then return end
  for corp in pairs(shared.CORPS) do
    if storage.corps and storage.corps[corp] then rd.choose(corp) end
  end
end

-- For stats and tests.
function rd.summary(corp)
  local t = rd.state(corp)
  local by = {}
  prune(t.losses)
  for _, l in ipairs(t.losses) do by[l.damage] = (by[l.damage] or 0) + 1 end
  return {fund = t.fund, weapons = t.weapons, lost_by = by, turned_back = #t.turned_back, bought = t.bought,
    strength = rd.strength(corp)}
end

return rd
