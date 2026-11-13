-- The director (docs/director.md; Fable's consult, docs/reviews/2026-11-13-director-consult.md; the user, 2026-11-13:
-- "think rimworld storyteller", then "Shouldn't the director cover the possible operations stemming from all camps in
-- play?"). One layer above every camp: it decides when the pressure on the player rises and falls, never how. Its
-- first step (the consult's order): its state, budget and readings; two dials that act from the first camp on, tempo
-- (a corporation's spree: its gaps between operations shortened, tune.sooner) and lull (its operations held, the truce
-- standing, stance.standing); and the pressure floor (20 minutes without an operation, ops.choose and the perimeter)
-- taken over while it is on. Synthexis keeps its own waves (decision 2): its tempo is never touched.
-- Its budget is counted in landings: it fills by (1 + era / 2) times the difficulty and the personality each landing
-- interval, up to DIRECTOR.cap; a spree costs DIRECTOR.spree_cost. A spree, then a lull, then filling again: a rise, a
-- peak, a valley. No threat while the player's losses of the last half hour pass DIRECTOR.loss_share of their factory's
-- worth, and the fill halves while their guns are fewer than an hour ago (the slow spiral a window misses).
-- On after the opening's arrival (phases.lua) and DIRECTOR.grace more (decision 5), or by debug_tune director. Off
-- (setting lp-director), none of this runs and tune.sooner, the floor and the truces are as they were.
-- Its state is storage.director, all of it: a save, a load or a player joining sees the same director.
local shared = require("__landing-party__.shared")
local valuemap = require("__landing-party__.scripts.valuemap")
local ops = require("__landing-party__.scripts.ops")
local stance = require("__landing-party__.scripts.stance")
local faction = require("__landing-party__.scripts.faction")

local director = {}

-- The factory's worth, read cheaply (LuaForce.get_entity_count, not a search over its ground): these prototypes, each
-- weighed as valuemap weighs it; its guns counted apart.
local WORTH_NAMES = {"assembling-machine-1", "assembling-machine-2", "assembling-machine-3", "stone-furnace",
  "steel-furnace", "electric-furnace", "electric-mining-drill", "burner-mining-drill", "lab", "roboport", "radar",
  "substation", "beacon", "rocket-silo", "solar-panel", "accumulator", "steam-engine", "steam-turbine", "nuclear-reactor",
  "oil-refinery", "chemical-plant", "foundry", "electromagnetic-plant", "biochamber", "cryogenic-plant", "big-mining-drill"}
local GUN_NAMES = {"gun-turret", "laser-turret", "flamethrower-turret", "artillery-turret", "railgun-turret", "tesla-turret",
  "rocket-turret"}

local function tun(k)
  local t = storage.director_tune
  return t and t[k] or shared.DIRECTOR[k]
end

local function st()
  storage.director = storage.director or {budget = 0, phase = "fill", losses = {}, guns = {}, tempo = {}, beats = 0,
    last_spree = {}}
  return storage.director
end

local function trace(text)
  if storage.trace then
    helpers.write_file("landing-party/decisions.txt", string.format("%8d director  %s\n", game.tick, text), true)
  end
  local s = st()
  s.log = s.log or {}
  table.insert(s.log, {tick = game.tick, text = text})
  if #s.log > 40 then table.remove(s.log, 1) end
end

function director.personality()
  if storage.director_force then return storage.director_force end
  return shared.setting("lp-director", "steady")
end

-- On: a personality other than off, and the opening over by its grace (or forced by a test).
local function on(tick)
  if director.personality() == "off" then return false end
  if storage.director_force then return true end
  local arrived = storage.phases and storage.phases.arrived
  return arrived ~= nil and tick >= arrived + tun("grace") * 3600
end

-- A loss of the player's, for the half hour's window (control.lua, beside storage.player_razed).
function director.note_loss(owner, ent)
  if not (storage.director and storage.director.active) then return end
  local s = st()
  table.insert(s.losses, {game.tick, owner, valuemap.razed_of(ent)})
end

local function worth_of(force)
  local w, guns = 0, 0
  for _, n in ipairs(WORTH_NAMES) do
    local p = prototypes.entity[n]
    if p then
      local c = force.get_entity_count(n)
      if c > 0 then w = w + c * (valuemap.NAMES[n] or valuemap.WORTH[p.type] or 0) end
    end
  end
  for _, n in ipairs(GUN_NAMES) do
    if prototypes.entity[n] then guns = guns + force.get_entity_count(n) end
  end
  return w, guns
end

-- The corporations at war with this player with a camp standing, the one longest without a spree first.
local function pick(s, owner, tick)
  local best, bt
  for corp in pairs(shared.CORPS) do
    if faction.alive(corp) > 0 and stance.standing(corp, owner) == "enemy" then
      local t = s.last_spree[corp] or -math.huge
      if not best or t < bt then best, bt = corp, t end
    end
  end
  return best
end

local function tell(owner, key, ...)
  local f = game.forces[owner]
  if f and #f.players > 0 then shared.notice(f, {key, ...}) end
end

function director.tick(tick)
  if tick % 3600 ~= 0 then return end
  local s = st()
  local active = on(tick)
  if active ~= s.active then
    s.active = active
    if active then trace(string.format("on (%s)", director.personality())) end
  end
  if not active then return end
  local forces = shared.player_forces()
  local owner = forces[1] and forces[1].name
  if not owner then return end
  local f = game.forces[owner]
  -- Its readings.
  local era = storage.era_override or ops.era(f)
  local w, guns = worth_of(f)
  local cut = tick - 30 * 3600
  local k = 1
  while s.losses[k] and s.losses[k][1] < cut do k = k + 1 end
  if k > 1 then
    local keep = {}
    for i = k, #s.losses do keep[#keep + 1] = s.losses[i] end
    s.losses = keep
  end
  local lost = 0
  for _, l in ipairs(s.losses) do if l[2] == owner then lost = lost + l[3] end end
  if tick % (10 * 3600) == 0 then
    table.insert(s.guns, guns)
    if #s.guns > 7 then table.remove(s.guns, 1) end
  end
  local falling = #s.guns >= 7 and guns < s.guns[1]
  -- (A player with nothing left standing who is still losing is hurt too.)
  local hurt = lost > 0 and lost > tun("loss_share") * w
  s.read = {era = era, worth = w, guns = guns, lost = lost, falling = falling, hurt = hurt}
  -- Its budget, in landings a landing interval.
  local interval = shared.setting("lp-landing-interval", shared.LANDING_MINUTES.default)
  local d = shared.DIFFICULTY[shared.setting("lp-difficulty", "normal")] or 1
  local rate = (storage.director_tune and storage.director_tune.fill)
    or (1 + era / 2) * d * (tun("personality")[director.personality()] or 1) / math.max(1, interval)
  if falling then rate = rate / 2 end
  s.budget = math.min(tun("cap"), s.budget + rate)
  -- Its beats: a spree, then a lull, then filling again.
  if s.phase == "spree" and tick >= s.phase_till then
    director.start_lull(s, owner, tick)
  elseif s.phase == "lull" and tick >= s.phase_till then
    s.phase, s.phase_till = "fill", nil
    trace(string.format("fill: budget %.2f", s.budget))
  end
  if s.phase == "fill" and s.budget >= tun("spree_cost") then
    if hurt then
      if s.held_for ~= "hurt" then
        s.held_for = "hurt"
        trace(string.format("holds: %s lost %.0f of %.0f worth in half an hour", owner, lost, w))
      end
      return
    end
    local corp = pick(s, owner, tick)
    if not corp then return end
    s.held_for = nil
    s.budget = s.budget - tun("spree_cost")
    director.start_spree(s, owner, corp, tick, string.format("era %d, worth %.0f, guns %d", era, w, guns))
  end
end

-- A lull now: every corporation's operations against `owner` held lull_minutes (the truce standing).
function director.start_lull(s, owner, tick)
  local minutes = tun("lull_minutes")
  storage.truces = storage.truces or {}
  for corp in pairs(shared.CORPS) do storage.truces[corp .. "|" .. owner] = tick + minutes * 3600 end
  s.phase, s.phase_till = "lull", tick + minutes * 3600
  s.lulls = (s.lulls or 0) + 1
  trace(string.format("lull: every corporation's operations against %s held %d minutes", owner, minutes))
  tell(owner, "lp.director-lull", minutes)
end

-- A spree now: `corp`'s operations against `owner` spree_factor times as often for spree_minutes.
function director.start_spree(s, owner, corp, tick, why)
  local minutes = tun("spree_minutes")
  s.tempo[corp] = {factor = tun("spree_factor"), till = tick + minutes * 3600}
  s.last_spree[corp] = tick
  s.phase, s.phase_till = "spree", tick + minutes * 3600
  s.beats, s.sprees = s.beats + 1, (s.sprees or 0) + 1
  -- A spree pulls its camps' next operations in (a pace, never a hold: ops.finish's gaps, b.next_op_why).
  for _, b in pairs(storage.bases or {}) do
    if b.corp == corp and not b.fallen and b.next_op_why == "pace" and (b.next_op or 0) > tick then
      b.next_op = tick + math.floor((b.next_op - tick) / tun("spree_factor"))
    end
  end
  trace(string.format("spree: %s's operations against %s %dx as often for %d minutes (budget %.2f left; %s)",
    corp, owner, tun("spree_factor"), minutes, s.budget, why or "forced"))
  tell(owner, "lp.director-spree", shared.CORPS[corp].name, minutes)
end

-- The debug panel's and tests' hand on it (director_gui.lua, remote director_cmd): on (steady, no grace), off, a spree
-- now (`arg` a corporation, else the one it would pick), a lull now, the budget full or empty, the beat ended. Returns
-- what it did, or why not.
function director.cmd(action, arg)
  local s = st()
  local tick = game.tick
  local owner = (shared.player_forces()[1] or {}).name
  if action == "on" then
    storage.director_force = "steady"
    s.active = true
    trace("on (forced)")
    return "on"
  elseif action == "off" then
    storage.director_force = "off"
    s.active, s.phase, s.phase_till = false, "fill", nil
    for _, t in pairs(s.tempo) do t.till = tick end
    trace("off (forced)")
    return "off"
  elseif action == "auto" then
    storage.director_force = nil
    return "as the setting says"
  end
  if not owner then return "no player force" end
  if action == "spree" then
    local corp = arg or pick(s, owner, tick)
    if not corp or not shared.CORPS[corp] then return "no corporation at war with a camp standing" end
    director.start_spree(s, owner, corp, tick, "forced")
    return "spree: " .. corp
  elseif action == "lull" then
    director.start_lull(s, owner, tick)
    return "lull"
  elseif action == "fill" then
    s.budget = tun("cap")
    return "budget full"
  elseif action == "empty" then
    s.budget = 0
    return "budget empty"
  elseif action == "end" then
    if s.phase == "lull" and owner then
      for corp in pairs(shared.CORPS) do (storage.truces or {})[corp .. "|" .. owner] = tick end
    end
    for _, t in pairs(s.tempo) do t.till = tick end
    s.phase, s.phase_till = "fill", nil
    trace("beat ended (forced)")
    return "beat ended"
  end
  return "unknown: " .. tostring(action)
end

-- For the panel: its tune (the priors as they stand) and its personality.
function director.tune(k) return tun(k) end

function director.state() return storage.director end

return director
