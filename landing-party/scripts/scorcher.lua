-- The Scorcher's flame (units.lua; the user, 2026-10-21: "fire is quite OP in this game, probably they would have limited
-- flame autonomy ... and use their machine gun most of the time"): its own weapon is a machine gun; this gives it BURSTS
-- bursts of the flamethrower's stream, spent only on what fire is for (a wall, a turret or a gate within REACH, or PACK of
-- the player's units or characters within PACK_RADIUS), one every GAP, and refilled one every REFILL. Grubstake's pact:
-- never within NEST_CLEAR of a biter nest while its pact holds. And the Tesla's drain: what its lightning strikes that
-- holds a charge loses DRAIN of it.
local shared = require("__landing-party__.shared")

local scorcher = {}

local BURSTS = 3
local REFILL = 20 * 60
local GAP = 2 * 60
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
    s = {fuel = BURSTS, next = 0, refill = game.tick + REFILL}
    storage.scorch[u.unit_number] = s
  end
  return s
end

local function target(u)
  local s, p, f = u.surface, u.position, u.force
  local best, bd
  for _, e in pairs(s.find_entities_filtered{position = p, radius = REACH, type = BUILDINGS}) do
    if e.valid and e.force ~= f and not f.get_cease_fire(e.force) and e.force.name ~= "neutral" and e.force.name ~= "enemy" then
      local d = (e.position.x - p.x) ^ 2 + (e.position.y - p.y) ^ 2
      if not bd or d < bd then best, bd = e.position, d end
    end
  end
  if best then return best end
  -- A pack: the player's units or characters close together.
  for _, e in pairs(s.find_entities_filtered{position = p, radius = REACH, type = {"unit", "character"}}) do
    if e.valid and e.force ~= f and shared.is_player_force(e.force) then
      local n = s.count_entities_filtered{position = e.position, radius = PACK_RADIUS, force = e.force, type = {"unit", "character"}}
      if n >= PACK then return e.position end
    end
  end
end

function scorcher.tick(tick)
  if tick % TICKS ~= 7 or not storage.bases then return end
  local seen = {}
  for _, b in pairs(storage.bases) do
    if not b.fallen and not seen[b.surface] then
      seen[b.surface] = true
      local s = game.surfaces[b.surface]
      for _, u in pairs(s and s.find_entities_filtered{name = shared.variants("lp-scorcher")} or {}) do
        local st = state(u)
        if st.fuel < BURSTS and tick >= st.refill then st.fuel, st.refill = st.fuel + 1, tick + REFILL end
        if st.fuel > 0 and tick >= st.next then
          local holds = false
          for corp, c in pairs(shared.CORPS) do
            if c.force == u.force.name and storage.pact_state and storage.pact_state[corp] then holds = true end
          end
          local pact = holds and s.count_entities_filtered{position = u.position, radius = NEST_CLEAR, type = {"unit-spawner", "turret"},
              force = "enemy", limit = 1} > 0
          local at = not pact and target(u)
          if at then
            s.create_entity{name = "flamethrower-fire-stream", position = u.position, source = u, target = at, force = u.force}
            st.fuel, st.next = st.fuel - 1, tick + GAP
            if st.fuel == BURSTS - 1 then st.refill = tick + REFILL end
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
  end
end

-- The Tesla's drain: on_entity_damaged (electric, filtered in control.lua) from a corporation's Tesla or its chain.
local CHARGED = {["electric-turret"] = true, accumulator = true, roboport = true, ["electric-energy-interface"] = true}
function scorcher.drain(e)
  local ent = e.entity
  if not (ent and ent.valid and CHARGED[ent.type]) then return end
  if not (e.force and shared.is_corp(e.force.name)) then return end
  local cause = e.cause
  if cause and cause.valid and shared.kind_of(cause.name) ~= "lp-tesla" then return end
  if ent.energy and ent.energy > 0 then
    ent.energy = ent.energy * (1 - DRAIN)
    storage.tesla_drains = (storage.tesla_drains or 0) + 1
  end
end

function scorcher.stats()
  return {bursts = storage.scorch_bursts or 0, drains = storage.tesla_drains or 0}
end

return scorcher
