-- Corporate research (docs/reviews/2026-10-14-corporate-rd-consult.md, made each corporation's own in
-- docs/reviews/2026-10-14-identity-trees-consult.md; the user: "a 'smart' parallel to biter evolution", and "actual
-- faction identity"). A share of each corporation's exports goes to a fund (FUND_SHARE, capped at FUND_CAP); every
-- CHOICE_TICKS it buys at most one node of its own tree (shared.CORPS[corp].tree), read from what it has been
-- losing to (rd.choose). Its own units' upgrades divide the defence it reads at a target (ops: rd.strength), so raids
-- stay a size a garrison can field. The ledger: units lost in the last WINDOW_TICKS by the damage the killer deals,
-- and raids turned back for want of force.
local shared = require("__landing-party__.shared")

local rd = {}

local FUND_SHARE, FUND_CAP = 0.3, 10000
local LEVEL_COST, LEVEL_DAMAGE, MAX_LEVEL = 400, 0.2, 5
local CHOICE_TICKS = 10 * 3600
local WINDOW_TICKS = 30 * 3600
-- What each unit kind fires (units.lua).
rd.CATEGORY = {["lp-infantry"] = "bullet", ["lp-buggy"] = "bullet", ["lp-harrier"] = "bullet",
  ["lp-tank"] = "cannon-shell", ["lp-walker"] = "rocket"}
-- Each corporation's own infantry (units.lua): Serenity's Line troopers fire lasers, Grubstake's Shotgun hands shells.
rd.CORP_CATEGORY = {serenity = {["lp-infantry"] = "laser", ["lp-lance"] = "laser", ["lp-shock"] = "electric"},
  grubstake = {["lp-infantry"] = "shotgun-shell", ["lp-slug"] = "shotgun-shell", ["lp-sapper"] = "grenade"}}
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
  d.tech.nodes = d.tech.nodes or {}
  d.tech.units = d.tech.units or {}
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
  -- Who killed it, for triggers on the killer: a character, a vehicle (cars and tanks), else its kind.
  local killer = cause.type == "character" and "character" or (cause.type == "car" and "vehicle") or kind
  table.insert(t.losses, {tick = game.tick, damage = dmg, kind = shared.kind_of(dead), killer = killer})
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

-- Units its tree has added to its mix, with their weights (army: mix).
function rd.mix(corp)
  local d = storage.corps and storage.corps[corp]
  return d and d.tech and d.tech.units or {}
end

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

-- The tree (shared.CORPS[corp].tree): nodes in the corporation's voice. A track node raises the damage of its
-- ammunition categories a level at a time (LEVEL_COST x k for level k, +LEVEL_DAMAGE each, at most the player's
-- era + 1); a plate node sets plates on unit kinds (rd.unit builds them), from its era. A trigger reads the ledger:
-- {damage = d, min = n} (n or more of its units killed by damage d in the window), {turned_back = n} (raids turned
-- back for want of force). The node whose trigger fires hardest wins (tree order breaks ties); with none, the first
-- track climbs. A winner it cannot yet afford is saved for: nothing else is bought meanwhile.
local function level_of(t, node) return (t.nodes[node.id] or 0) end
local function owned(t, node)
  if node.track then return level_of(t, node) >= (node.levels or MAX_LEVEL) end
  if node.unit then return t.units[node.unit.kind] ~= nil end
  for kind, p in pairs(node.plates or {}) do if t.plate[kind] ~= p then return false end end
  return true
end
local function allowed(t, node, era)
  if owned(t, node) then return false end
  if node.requires and not t.nodes[node.requires] then return false end
  if node.track then return level_of(t, node) + 1 <= era + 1 end
  return era >= (node.era or 0)
end
local function cost_of(t, node)
  if node.track then return node.cost * (level_of(t, node) + 1) end
  return node.cost
end
local function score(t, node)
  local tr = node.trigger or {}
  if tr.damage then
    local n = 0
    for _, l in ipairs(t.losses) do if l.damage == tr.damage then n = n + 1 end end
    if n >= (tr.min or 1) then return n end
  end
  if tr.killer then
    local n = 0
    for _, l in ipairs(t.losses) do
      for _, k in ipairs(tr.killer) do if l.killer == k then n = n + 1 end end
    end
    if n >= (tr.min or 1) then return n end
  end
  if tr.turned_back and #t.turned_back >= tr.turned_back then return 5 * #t.turned_back end
  return 0
end

local function apply(corp, t, node)
  local f = game.forces[shared.CORPS[corp].force]
  if node.track then
    local k = level_of(t, node) + 1
    t.nodes[node.id] = k
    for _, c in ipairs(node.track) do
      t.weapons[c] = k
      f.set_ammo_damage_modifier(c, LEVEL_DAMAGE * k)
    end
    notify(corp, "lp.node-" .. node.id, k)
  else
    t.nodes[node.id] = 1
    for kind, p in pairs(node.plates or {}) do t.plate[kind] = p end
    if node.unit then t.units[node.unit.kind] = node.unit.weight end
    notify(corp, "lp.node-" .. node.id)
  end
  t.bought = t.bought + 1
end

-- The node it would buy now, and whether a trigger called for it.
local function pick(corp, t, era)
  local best, bs, fallback
  for _, node in ipairs(shared.CORPS[corp].tree or {}) do
    if allowed(t, node, era) then
      local s = score(t, node)
      if s > 0 and (not bs or s > bs) then best, bs = node, s end
      if node.track and not fallback then fallback = node end
    end
  end
  return best or fallback, best ~= nil
end

function rd.choose(corp)
  local d = storage.corps and storage.corps[corp]
  if not d or d.withdrawing then return end
  local t = rd.state(corp)
  prune(t.losses)
  prune(t.turned_back)
  local node, called = pick(corp, t, player_era())
  if not node then return end
  local cost = cost_of(t, node)
  if t.fund < cost then
    t.saving = node.id
    return
  end
  t.fund = t.fund - cost
  t.saving = nil
  apply(corp, t, node)
  if rd.trace then
    rd.trace(corp, string.format("research: %s%s (%s, fund %d)", node.id,
      node.track and (" level " .. t.nodes[node.id]) or "", called and "called for" or "climbing", t.fund))
  end
  return node.id
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
  -- A node set outright takes effect as if bought (its units join the mix, its plates are worn).
  for id, k in pairs(tech.nodes or {}) do
    t.nodes[id] = k
    for _, node in ipairs(shared.CORPS[corp].tree or {}) do
      if node.id == id then
        if node.unit then t.units[node.unit.kind] = node.unit.weight end
        for kind, p in pairs(node.plates or {}) do t.plate[kind] = p end
      end
    end
  end
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
  return {fund = t.fund, weapons = t.weapons, plate = t.plate, nodes = t.nodes, units = t.units, saving = t.saving, lost_by = by,
    turned_back = #t.turned_back, bought = t.bought, strength = rd.strength(corp)}
end

return rd
