-- War footing and the war chest (docs/reviews/2026-10-15-pressure-ramp-consult.md; the user: "it's not good that only
-- the first raid does anything"). A settlement's units came only from its drop escort and its own parts; under fire its
-- parts went to rebuilding what the player's guns broke, and its garrison fell to nought for good. Two changes:
--   War footing: a settlement at war (it knows a player's buildings and its temper lets it go for them) and short of its
--   unit cap rebuilds only its generators and depots; its parts go to units first (army.produce).
--   The war chest: a share of each corporation's exports (CHEST_SHARE, capped at CHEST_CAP), and Grubstake's salvage.
--   Every RELIEF_TICKS a corporation sends one settlement at war, ladder rung 1 or more, RELIEF_PER_RUNG units a rung,
--   paid from the chest at RELIEF_MARKUP. Grubstake's come down in a pod behind the lander; Serenity's march as a relief
--   column from its nearest other settlement along a planned route (none: no relief), or, with no other settlement,
--   drop at the lander at half strength.
local shared = require("__landing-party__.shared")
local ops = require("__landing-party__.scripts.ops")
local army = require("__landing-party__.scripts.army")
local rng = require("__landing-party__.scripts.rng")
local base = require("__landing-party__.scripts.base")
local rd = require("__landing-party__.scripts.rd")

local war = {}

local CHEST_SHARE, CHEST_CAP = 0.2, 6000
local RELIEF_TICKS = 10 * 3600
local RELIEF_PER_RUNG = 8
local RELIEF_MIN = 4
local RELIEF_MARKUP = 1.5
local POD_DISTANCE = 40
local COLUMN_PATIENCE = 10 * 3600
-- What makes parts too: a settlement whose fabricators were destroyed while at war rebuilt nothing, made no parts and
-- no units, for good (scenario occupy).
local ESSENTIAL = {["lp-generator"] = true, ["lp-depot"] = true, ["lp-fabricator"] = true, ["lp-drill"] = true,
  ["lp-pylon"] = true}

local function corp_state(corp)
  storage.corps = storage.corps or {}
  storage.corps[corp] = storage.corps[corp] or {level = 0, exported = 0}
  return storage.corps[corp]
end

function war.fund(corp, parts)
  local d = corp_state(corp)
  d.chest = math.min(CHEST_CAP, (d.chest or 0) + CHEST_SHARE * parts)
end

-- The player force this settlement is at war with, and its rung; nil when at peace.
local function at_war(b)
  local temper = shared.CORPS[b.corp].temper or {}
  local d = corp_state(b.corp)
  local seen = {}
  for _, t in pairs(b.intel and b.intel.targets or {}) do
    local o = t.owner
    if o and not seen[o] and o ~= "enemy" and not shared.is_corp(o) and game.forces[o] then
      seen[o] = true
      if not temper.provoked_only or (d.provoked or {})[o] then return o, ops.ladder(o, b.force) end
    end
  end
end
war.at_war = at_war

local function strength(b) return #b.garrison + #(b.patrol or {}) end

-- base.rebuild asks before each job: false holds it (base.footing).
function war.footing(b, job)
  if ESSENTIAL[shared.kind_of(job.name)] then return true end
  if (b.war_checked or -1) ~= game.tick then
    b.war_checked = game.tick
    b.on_footing = at_war(b) ~= nil and strength(b) < army.cap(b)
  end
  return not b.on_footing
end
base.footing = war.footing

local function tell(key, corp, b)
  local s = game.surfaces[b.surface]
  for _, f in pairs(game.forces) do
    if #f.players > 0 and not shared.is_corp(f.name) then
      f.print({key, shared.corp_label(corp), string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y, s.name)})
    end
  end
end

-- The detachment: n units of the settlement's mix and what they cost at the markup.
local function detachment(b, n)
  local m = army.mix(b)
  local names, cost = {}, 0
  for _ = 1, n do
    local name = rng.weighted(b.rng, m)
    if name == "lp-hauler" then name = "lp-infantry" end
    table.insert(names, name)
    cost = cost + RELIEF_MARKUP * (shared.units[name] and shared.units[name].cost or 10)
  end
  return names, cost
end

-- Units at `at` for settlement `to` (counted as its own from the start: a column's losses are its losses).
local function spawn(b, names, at, to)
  local s = game.surfaces[b.surface]
  local out = {}
  for _, name in ipairs(names) do
    local proto = rd.unit(b.corp, name)
    local p = s.find_non_colliding_position(proto, at, 16, 0.5)
    local u = p and s.create_entity{name = proto, position = p, force = b.force}
    if u then
      table.insert(out, u)
      storage.unit_owner[u.unit_number] = to.id
    end
  end
  return out
end

local function join(b, units)
  for _, u in ipairs(units) do
    if u.valid then
      table.insert(b.garrison, u)
      storage.unit_owner[u.unit_number] = b.id
    end
  end
end

-- Behind the lander, away from the player's buildings it knows (the pod comes down where the player is not).
local function behind(b, owner)
  local h = b.lander.position
  local sx, sy, n = 0, 0, 0
  for _, t in pairs(b.intel.targets) do
    if t.owner == owner and t.pos then sx, sy, n = sx + t.pos[1], sy + t.pos[2], n + 1 end
  end
  local dx, dy = 0, 1
  if n > 0 then
    dx, dy = h.x - sx / n, h.y - sy / n
    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
    dx, dy = dx / len, dy / len
  end
  return {h.x + dx * POD_DISTANCE, h.y + dy * POD_DISTANCE}
end

local function nearest_sister(b)
  local best, bd
  for _, o in pairs(storage.bases) do
    if o ~= b and o.corp == b.corp and not o.fallen and o.lander.valid and o.surface == b.surface then
      local d = (o.origin.x - b.origin.x) ^ 2 + (o.origin.y - b.origin.y) ^ 2
      if not bd or d < bd then best, bd = o, d end
    end
  end
  return best
end

local function send(b, owner, rung)
  local d = corp_state(b.corp)
  local n = RELIEF_PER_RUNG * rung
  local sister = b.corp == "serenity" and nearest_sister(b)
  if b.corp == "serenity" and not sister then n = math.floor(n / 2) end
  local names, cost = detachment(b, n)
  while #names > RELIEF_MIN and cost > (d.chest or 0) do
    local name = table.remove(names)
    cost = cost - RELIEF_MARKUP * (shared.units[name] and shared.units[name].cost or 10)
  end
  if #names < RELIEF_MIN or cost > (d.chest or 0) then return false end
  if sister then
    -- A relief column from the sister settlement, along a route clear of turrets and nests (ops.route), or none.
    local from = {sister.lander.position.x, sister.lander.position.y + 8}
    local to = {b.lander.position.x, b.lander.position.y}
    local route = ops.route(sister, from, to, {turrets = true, nests = true})
    if not route then
      base.trace(b, "relief: no way from settlement " .. sister.id .. "; none sent")
      return false
    end
    local units = spawn(sister, names, from, b)
    local cmds = {}
    for _, w in ipairs(route) do
      table.insert(cmds, {type = defines.command.go_to_location, destination = w, radius = 4,
        distraction = defines.distraction.by_enemy})
    end
    table.insert(cmds, {type = defines.command.go_to_location, destination = to, radius = 10,
      distraction = defines.distraction.by_enemy})
    for _, u in ipairs(units) do
      u.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = cmds}
    end
    storage.reliefs = storage.reliefs or {}
    table.insert(storage.reliefs, {units = units, to = b.id, since = game.tick})
    base.trace(b, string.format("relief: a column of %d from settlement %d (%d waypoints), %.0f from the chest",
      #units, sister.id, #route, cost))
    tell("lp.relief-column", b.corp, b)
  else
    local at = behind(b, owner)
    local units = spawn(b, names, at, b)
    for _, u in ipairs(units) do
      u.commandable.set_command{type = defines.command.go_to_location, destination = b.lander.position, radius = 12,
        distraction = defines.distraction.by_enemy}
    end
    join(b, units)
    base.trace(b, string.format("relief: %s of %d at %.0f,%.0f, %.0f from the chest", b.corp == "grubstake" and "a pod" or "a drop",
      #units, at[1], at[2], cost))
    tell(b.corp == "grubstake" and "lp.relief-pod" or "lp.relief-drop", b.corp, b)
  end
  d.chest = d.chest - cost
  b.reinforced = (b.reinforced or 0) + #names
  return true
end

-- Columns on the way join their settlement when they reach it (or after COLUMN_PATIENCE, wherever they are).
local function columns()
  for i = #(storage.reliefs or {}), 1, -1 do
    local r = storage.reliefs[i]
    local b = storage.bases[r.to]
    local live = {}
    for _, u in ipairs(r.units) do if u.valid then table.insert(live, u) end end
    r.units = live
    if not (b and b.lander.valid and not b.fallen) or #live == 0 then
      if b then base.trace(b, "relief: the column was lost") end
      table.remove(storage.reliefs, i)
    else
      local h = b.lander.position
      local near = 0
      for _, u in ipairs(live) do
        if (u.position.x - h.x) ^ 2 + (u.position.y - h.y) ^ 2 < 30 * 30 then near = near + 1 end
      end
      if near * 2 >= #live or game.tick - r.since > COLUMN_PATIENCE then
        join(b, live)
        b.columns_arrived = (b.columns_arrived or 0) + 1
        base.trace(b, string.format("relief: the column arrived, %d units", #live))
        table.remove(storage.reliefs, i)
      end
    end
  end
end

-- The landing barrage (the user: Serenity lands with a howitzer, and railgunners): a corporation that clears nests,
-- landing with spawners within BARRAGE_RADIUS, puts a howitzer beside its lander that shells everything in its reach
-- for BARRAGE_TICKS (or until its shells are spent), and BARRAGE_RAILS railgunners join its garrison. At evolution 0.9,
-- landed among nests, Serenity lost 1,300 buildings to biter attacks in two hours and never got through (visit).
local BARRAGE_RADIUS, BARRAGE_TICKS, BARRAGE_SHELLS, BARRAGE_RAILS = 110, 10 * 3600, 60, 8
function war.barrage(b)
  if not shared.CORPS[b.corp].clears_nests or not (b.lander and b.lander.valid) then return end
  local s = b.lander.surface
  local c = b.lander.position
  local nests = s.count_entities_filtered{position = c, radius = BARRAGE_RADIUS, type = "unit-spawner", force = "enemy"}
  if nests == 0 then return end
  local name = shared.variant(b.corp, "lp-howitzer")
  local p = s.find_non_colliding_position(name, {c.x - 8, c.y + 8}, 16, 1)
  local gun = p and s.create_entity{name = name, position = p, force = b.lander.force}
  if gun then
    gun.insert{name = "lp-mortar-shell", count = BARRAGE_SHELLS}
    b.barrage = {gun = gun, till = game.tick + BARRAGE_TICKS}
  end
  local rails = {}
  for _ = 1, BARRAGE_RAILS do table.insert(rails, "lp-railgunner") end
  local units = spawn(b, rails, {c.x + 6, c.y + 6}, b)
  join(b, units)
  base.trace(b, string.format("landing barrage: %s, %d railgunners, %d spawners within %d", gun and "a howitzer" or "no room for the howitzer",
    #units, nests, BARRAGE_RADIUS))
end

local function barrages()
  for _, b in pairs(storage.bases) do
    local r = b.barrage
    if r then
      local left = r.gun.valid and r.gun.get_inventory(defines.inventory.artillery_turret_ammo).get_item_count("lp-mortar-shell") or 0
      if not r.gun.valid or left == 0 or game.tick >= r.till then
        if r.gun.valid then r.gun.destroy() end
        b.barrage = nil
        base.trace(b, string.format("landing barrage over (%d shells left)", left))
      end
    end
  end
end

function war.tick(tick)
  if tick % 600 ~= 300 then return end
  barrages()
  columns()
  if storage.relief_off then return end
  local period = storage.relief_ticks or RELIEF_TICKS
  for corp in pairs(shared.CORPS) do
    local d = corp_state(corp)
    if tick >= (d.next_relief or 0) and not d.withdrawing then
      -- The settlement at war on the highest rung, the most short of its cap.
      local pick, prung, powner, short
      for _, b in pairs(storage.bases) do
        if b.corp == corp and not b.fallen and b.lander.valid then
          local owner, rung = at_war(b)
          local s = owner and army.cap(b) - strength(b)
          if owner and rung >= 1 and s > 0 and (not pick or rung > prung or (rung == prung and s > short)) then
            pick, prung, powner, short = b, rung, owner, s
          end
        end
      end
      if pick and send(pick, powner, prung) then d.next_relief = tick + period
      elseif pick then d.next_relief = tick + 2 * 3600 end
    end
  end
end

function war.summary(corp)
  local d = corp_state(corp)
  return {chest = d.chest or 0, next_relief = d.next_relief, columns = #(storage.reliefs or {})}
end

return war
