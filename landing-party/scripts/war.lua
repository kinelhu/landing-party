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
local stance = require("__landing-party__.scripts.stance")
local pool = require("__landing-party__.scripts.pool")

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

-- The player force this settlement may act against (stance.may: `act`, default "war": an enemy, not under a truce),
-- and its rung; nil when there is none. Before the stance it ignored truces and Grubstake's temper: an unprovoked rival
-- was "at war", held its rebuilds on a war footing and tapped under a paid truce (docs/ai.md).
local function at_war(b, act)
  local seen = {}
  for _, t in pairs(b.intel and b.intel.targets or {}) do
    local o = t.owner
    if o and not seen[o] and o ~= "enemy" and not shared.is_corp(o) and game.forces[o] then
      seen[o] = true
      if stance.may(b.corp, o, act or "war") then return o, ops.ladder(o, b.force) end
    end
  end
end
war.at_war = at_war

local function strength(b) return pool.strength(b) end

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
      shared.notice(f, {key, shared.corp_label(corp), string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y, s.name)})
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
      pool.enlist(to, u)
    end
  end
  return out
end

local function join(b, units)
  for _, u in ipairs(units) do
    if u.valid then
      table.insert(b.garrison, u)
      pool.enlist(b, u)
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
  d.chest_spent = (d.chest_spent or 0) + cost
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

-- The orbital barrage (the user: Serenity "shells from above, before landing ... a very dramatic entrance, with tons of
-- cluster ammo pummeling the nests"): a corporation that clears nests, landing with spawners within ORBITAL_RADIUS,
-- has every spawner and worm there shelled from the sky, nearest first, a shell every ORBITAL_EVERY ticks (as many as
-- its health takes),
-- each the howitzer's blow with ten bomblets; BARRAGE_RAILS railgunners join its garrison. Its kills (spawners' evolution
-- refunded, biters.lua). A howitzer by the lander fired 10 of its 60 shells: its nests were out of its line and reach.
local ORBITAL_RADIUS, ORBITAL_EVERY, ORBITAL_FALL, BARRAGE_RAILS = 120, 15, 30, 8
local ORBITAL_BLOW = 800          -- what a shell does to a spawner or a worm, about (resistances off its 960)
function war.barrage(b)
  if not shared.CORPS[b.corp].clears_nests or not (b.lander and b.lander.valid) then return end
  local s = b.lander.surface
  local c = b.lander.position
  local found = s.find_entities_filtered{position = c, radius = ORBITAL_RADIUS, type = {"unit-spawner", "turret"},
    force = "enemy"}
  if #found == 0 then return end
  table.sort(found, function(x, y)
    return (x.position.x - c.x) ^ 2 + (x.position.y - c.y) ^ 2 < (y.position.x - c.x) ^ 2 + (y.position.y - c.y) ^ 2
  end)
  -- As many shells as its health takes (a spawner has 3,500: one shell each left all five standing).
  local queue = {}
  for _, e in ipairs(found) do
    for _ = 1, math.max(1, math.ceil(e.health / ORBITAL_BLOW)) do table.insert(queue, e) end
  end
  storage.orbitals = storage.orbitals or {}
  table.insert(storage.orbitals, {base = b.id, surface = s.index, force = b.force, queue = queue, i = 1})
  local rails = {}
  for _ = 1, BARRAGE_RAILS do table.insert(rails, "lp-railgunner") end
  local units = spawn(b, rails, {c.x + 6, c.y + 6}, b)
  join(b, units)
  local spawners = 0
  for _, e in ipairs(found) do if e.type == "unit-spawner" then spawners = spawners + 1 end end
  base.trace(b, string.format("orbital barrage: %d spawners and %d worms within %d, %d shells; %d railgunners", spawners,
    #found - spawners, ORBITAL_RADIUS, #queue, #units))
  tell("lp.orbital", b.corp, b)
end

local function orbitals(tick)
  for k = #(storage.orbitals or {}), 1, -1 do
    local o = storage.orbitals[k]
    local s = game.surfaces[o.surface]
    -- The next target still standing (an earlier shell or its bomblets may have done for it).
    while o.queue[o.i] and not o.queue[o.i].valid do o.i = o.i + 1 end
    local e = o.queue[o.i]
    if not e or not s then
      local b = storage.bases[o.base]
      if b then base.trace(b, "orbital barrage over") end
      table.remove(storage.orbitals, k)
    else
      o.i = o.i + 1
      local p = e.position
      -- Its force and cause given (given the force alone, its blast, "enemy" of nobody, hurt nothing).
      local b = storage.bases[o.base]
      local shell = s.create_entity{name = "lp-orbital-projectile", position = {p.x - 10, p.y - ORBITAL_FALL}, target = e,
        speed = 1, force = o.force, cause = game.forces[o.force], source = b and b.lander.valid and b.lander or nil}
    end
  end
end

-- Standing down (the user: a hopeless camp goes quiet rather than lifting off): a settlement at war that has razed
-- nothing for QUIET_TICKS (failed or not tried: a camp facing ten lasers launched one raid in 30 minutes) launches
-- nothing more against the player
-- (self-defence excepted) and gets no relief, keeps mining and exporting (its parts fund the others), and leaves its
-- place to a new landing, due within QUIET_HASTE and away from its site. After QUIET_TICKS it tries again.
local QUIET_TICKS, QUIET_HASTE = 60 * 3600, 5 * 3600
local function quiet(tick)
  local span = storage.quiet_ticks or QUIET_TICKS
  for _, b in pairs(storage.bases) do
    -- Its rung against the player it is at war with, for the cap and the siege tier (army.cap, ops.siege_tier).
    local _, rung = at_war(b)
    b.war_rung = rung or 0
    if not b.fallen and b.lander.valid then
      if b.quiescent then
        if tick - b.quiescent >= span then
          b.quiescent, b.woke_at, b.aborted_mark = nil, tick, b.ops_aborted or 0
          base.trace(b, "stood down long enough: it tries again")
        end
      elseif at_war(b) then
        b.war_since = b.war_since or tick
        local since = math.max(b.razed_at or 0, b.war_since, b.woke_at or 0)
        local aborted = (b.ops_aborted or 0) - (b.aborted_mark or 0)
        if tick - since >= span then
          b.quiescent = tick
          b.stood_down = (b.stood_down or 0) + 1
          -- A rival again (Grubstake; Serenity never forgets): standing.lua.
          if war.forgive then war.forgive(b.corp) end
          storage.failed_sites = storage.failed_sites or {}
          table.insert(storage.failed_sites, {x = b.origin.x, y = b.origin.y})
          local f = storage.faction
          if f and f.next then f.next = math.min(f.next, tick + QUIET_HASTE) end
          base.trace(b, string.format("stands down: nothing razed in %d minutes, %d operations failed; a new landing within %d",
            (tick - since) / 3600, aborted, QUIET_HASTE / 3600))
          tell("lp.stood-down", b.corp, b)
        end
      else
        b.war_since = nil
      end
    end
  end
end

function war.tick(tick)
  if storage.orbitals and #storage.orbitals > 0 and tick % ORBITAL_EVERY == 0 then orbitals(tick) end
  if tick % 600 ~= 300 then return end
  quiet(tick)
  columns()
  if storage.relief_off then return end
  local period = storage.relief_ticks or RELIEF_TICKS
  for corp in pairs(shared.CORPS) do
    local d = corp_state(corp)
    if tick >= (d.next_relief or 0) and not d.withdrawing then
      -- The settlement at war on the highest rung, the most short of its cap.
      local pick, prung, powner, short
      for _, b in pairs(storage.bases) do
        if b.corp == corp and not b.fallen and b.lander.valid and not b.quiescent then
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
  return {chest = d.chest or 0, spent = d.chest_spent or 0, next_relief = d.next_relief, columns = #(storage.reliefs or {})}
end

return war
