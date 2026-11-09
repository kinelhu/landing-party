-- The Scorcher's flame (units.lua; the user, 2026-10-21: "fire is quite OP in this game, probably they would have limited
-- flame autonomy ... and use their machine gun most of the time"): its own weapon is a machine gun; this gives it a burst
-- of the flamethrower's stream every COOLDOWN, spent only on what fire is for (a wall, a turret or a gate within REACH, or
-- PACK of a foe's units or characters within PACK_RADIUS). Grubstake's pact:
-- never within NEST_CLEAR of a biter nest while its pact holds. And the Tesla's drain: what its lightning strikes that
-- holds a charge loses DRAIN of it, and an electric turret it strikes stops for the game's tesla stun (scorcher.hold).
local shared = require("__landing-party__.shared")

local scorcher = {}

-- A cooldown, not a store (the user, 2026-11-09: "3 flame bursts is a little sad also... why not make it a cooldown
-- ability?"): a burst whenever it has a target and COOLDOWN has passed since the last. Three in store refilled one every
-- 20 s had flamed once in 20 s once spent; this is three times that, still a machine gun most of the time.
local COOLDOWN = 6 * 60
local REACH = 15                   -- past its machine gun's 13: it shoots from there
local PACK, PACK_RADIUS = 3, 9
local NEST_CLEAR = 30
local DRAIN = 0.6
local TICKS = 30

local BUILDINGS = {"wall", "gate", "ammo-turret", "electric-turret", "fluid-turret", "artillery-turret"}

local function state(u)
  storage.scorch = storage.scorch or {}
  local s = storage.scorch[u.unit_number]
  if not s then
    s = {next = 0}
    storage.scorch[u.unit_number] = s
  end
  return s
end

local function target(u)
  local s, p, f = u.surface, u.position, u.force
  local best, bd
  for _, e in pairs(s.find_entities_filtered{position = p, radius = REACH, type = BUILDINGS}) do
    if e.valid and e.force ~= f and not f.get_cease_fire(e.force) and e.force.name ~= "neutral" and not shared.is_biters(e.force.name) then
      local d = (e.position.x - p.x) ^ 2 + (e.position.y - p.y) ^ 2
      if not bd or d < bd then best, bd = e.position, d end
    end
  end
  if best then return best end
  -- A pack: any foe's units or characters close together, not the player's alone (the user, 2026-11-09, in the arena:
  -- "Our flame tanks also don't fire any flames": against Kessler-Hayashi's tanks it had only its machine gun).
  for _, e in pairs(s.find_entities_filtered{position = p, radius = REACH, type = {"unit", "character"}}) do
    if e.valid and e.force ~= f and e.force.name ~= "neutral" and not f.get_cease_fire(e.force) then
      local n = s.count_entities_filtered{position = e.position, radius = PACK_RADIUS, force = e.force, type = {"unit", "character"}}
      if n >= PACK then return e.position end
    end
  end
end

local release
function scorcher.tick(tick)
  if storage.tesla_held and next(storage.tesla_held) then release(tick) end
  scorcher.look(tick)
  if tick % TICKS ~= 7 or not storage.bases then return end
  local seen, list = {}, {}
  for _, b in pairs(storage.bases) do
    if not b.fallen and not seen[b.surface] then seen[b.surface] = true; table.insert(list, b.surface) end
  end
  for name in pairs(storage.arena_surfaces or {}) do
    if not seen[name] then seen[name] = true; table.insert(list, name) end
  end
  for _, name in ipairs(list) do
    do
      local s = game.surfaces[name]
      for _, u in pairs(s and s.find_entities_filtered{name = shared.variants("lp-scorcher")} or {}) do
        local st = state(u)
        if tick >= st.next then
          local holds = false
          for corp, c in pairs(shared.CORPS) do
            if c.force == u.force.name and storage.pact_state and storage.pact_state[corp] then holds = true end
          end
          local pact = holds and s.count_entities_filtered{position = u.position, radius = NEST_CLEAR, type = {"unit-spawner", "turret"},
              force = "enemy", limit = 1} > 0
          local at = not pact and target(u)
          if at then
            s.create_entity{name = "flamethrower-fire-stream", position = u.position, source = u, target = at, force = u.force}
            st.next = tick + COOLDOWN
            storage.scorch_bursts = (storage.scorch_bursts or 0) + 1
          end
        end
      end
    end
  end
  -- Forget the dead.
  if tick % 3600 == 7 then
    for k in pairs(storage.scorch or {}) do
      if not game.get_entity_by_unit_number(k) then storage.scorch[k] = nil end
    end
    for k in pairs(storage.tesla_aim or {}) do
      if not game.get_entity_by_unit_number(k) then storage.tesla_aim[k] = nil end
    end
  end
end

-- The Tesla's drain: on_entity_damaged (electric, filtered in control.lua) from a corporation's Tesla or its chain.
local CHARGED = {["electric-turret"] = true, accumulator = true, roboport = true, ["electric-energy-interface"] = true}
function scorcher.drain(e)
  local ent = e.entity
  if storage.tesla_off or not (ent and ent.valid and CHARGED[ent.type]) then return end
  if not (e.force and shared.is_corp(e.force.name)) then return end
  local cause = e.cause
  if cause and cause.valid and shared.kind_of(cause.name) ~= "lp-tesla" then return end
  if ent.energy and ent.energy > 0 then
    ent.energy = ent.energy * (1 - DRAIN)
    storage.tesla_drains = (storage.tesla_drains or 0) + 1
  end
  if ent.type == "electric-turret" then scorcher.hold(ent) else scorcher.aim(cause, ent) end
end

-- The Tesla's aim: its lightning on what holds a charge but cannot shoot (an accumulator, a roboport) while a laser stands
-- in its reach, it goes for the laser, then back to its order. Left to the engine's choice, a Tesla through a laser line
-- spent its bolts on the accumulators behind it: the lasers held 0 to 43% of their time at the line by the seed (teslawall
-- grid, seeds 12345, 777, 4242, 2026-11-09), the stun working whenever a bolt fell on one. Once per AIM_GAP a Tesla.
-- And once seen fighting, each Tesla is looked at every AIM_LOOK ticks while it lives (storage.tesla_seen): its bolts into
-- troopers and a wall, then the accumulators behind the line it had broken, set it off seldom (8 turns in 26 s, the
-- lasers held 4.7%, seed 12345, 0.2.254).
local AIM_GAP, AIM_LOOK = 75, 30
function scorcher.aim(u, struck)
  if not (u and u.valid and u.type == "unit") then return end
  storage.tesla_aim = storage.tesla_aim or {}
  storage.tesla_seen = storage.tesla_seen or {}
  local k = u.unit_number
  storage.tesla_seen[k] = {u = u, foe = struck.force}
  if (storage.tesla_aim[k] or -AIM_GAP) + AIM_GAP > game.tick then return end
  storage.tesla_aim[k] = game.tick
  local cm = u.commandable
  local now = cm and cm.command
  if now and now.type == defines.command.attack and now.target and now.target.valid and now.target.type == "electric-turret" then
    return
  end
  local reach = u.prototype.attack_parameters.range + 1
  local best, bd
  for _, t in ipairs(u.surface.find_entities_filtered{position = u.position, radius = reach, type = "electric-turret",
    force = struck.force}) do
    local d = (t.position.x - u.position.x) ^ 2 + (t.position.y - u.position.y) ^ 2
    if not bd or d < bd then best, bd = t, d end
  end
  if not best then return end
  local hit = {type = defines.command.attack, target = best, distraction = defines.distraction.none}
  -- Back to its order after, if that order still stands: one read back names a target that may have died since, and
  -- given again it is refused (the game stopped: "value for required field 'target' is missing", teslawall grid,
  -- 0.2.257). Then the laser alone.
  if not (now and pcall(cm.set_command, {type = defines.command.compound,
    structure_type = defines.compound_command.return_last, commands = {hit, now}})) then
    cm.set_command(hit)
  end
  storage.tesla_aims = (storage.tesla_aims or 0) + 1
end

-- The Tesla's hold (2026-11-06; the 11-05 adaptive tactics consult, section 5): the drain alone did nothing on a real
-- supply (teslawall LP_MIX=grid, 100 MW and 80 accumulators, a fraction of what feeds nw's south wall: the lasers hit as
-- often with it as without, 15.6 a second at the line against 15.9, and killed all five Teslas either way; a laser's
-- 801 kJ refills at 9,600 kW in 3 ticks). An electric turret its lightning strikes stops for the game's own tesla stun
-- (Space Age's tesla-turret-stun, read from the prototype: 30 ticks), each strike starting it again; its status says
-- why. No longer: a longer hold refreshed by a chain of 7 jumps keeps a whole laser line off while the Teslas live.
-- storage.tesla_held: unit number -> {e, till}; threat.firing reads a held turret as firing (Synthexis must not price a
-- laser held by Kessler-Hayashi's lightning as silent and learn from it).
local stun
local function stun_ticks()
  if stun == nil then
    local p = prototypes.entity["tesla-turret-stun"]
    stun = p and p.get_duration() or 0
  end
  return stun
end

function scorcher.hold(ent)
  local n = stun_ticks()
  if n <= 0 or not ent.unit_number then return end
  storage.tesla_held = storage.tesla_held or {}
  local h = storage.tesla_held[ent.unit_number]
  if not h then
    -- One already stopped by something else (a script, the circuit network) is left to it.
    if not ent.active then return end
    h = {e = ent}
    storage.tesla_held[ent.unit_number] = h
    ent.disabled_by_script = true
    ent.custom_status = {diode = defines.entity_status_diode.red, label = {"entity-status.lp-stunned"}}
    storage.tesla_holds = (storage.tesla_holds or 0) + 1
  end
  h.till = game.tick + n
end

function scorcher.look(tick)
  if tick % AIM_LOOK ~= 13 or not storage.tesla_seen then return end
  for k, t in pairs(storage.tesla_seen) do
    if not t.u.valid or not t.foe.valid then
      storage.tesla_seen[k] = nil
    else
      local foe = t.u.surface.find_entities_filtered{position = t.u.position, radius = t.u.prototype.attack_parameters.range + 1,
        type = "electric-turret", force = t.foe, limit = 1}[1]
      if foe then scorcher.aim(t.u, foe) end
    end
  end
end

release = function(tick)
  for k, h in pairs(storage.tesla_held) do
    if not h.e.valid then
      storage.tesla_held[k] = nil
    elseif tick >= h.till then
      h.e.disabled_by_script = false
      h.e.custom_status = nil
      storage.tesla_held[k] = nil
    end
  end
end

function scorcher.stats()
  return {bursts = storage.scorch_bursts or 0, drains = storage.tesla_drains or 0, holds = storage.tesla_holds or 0,
    held = table_size(storage.tesla_held or {}), aims = storage.tesla_aims or 0}
end

return scorcher
