-- The player's army: barracks turn trooper orders (crafted from items) into troopers; each trooper follows
-- the nearest rally beacon of its force. A beacon's circuit signals set the stance:
--   signal A > 0   advance: attack the nearest faction military target within reach of the beacon; with
--                  none left, occupy the nearest faction outpost
--   signal O > 0   occupy: go to the nearest faction outpost and stand on it (no rebuild there, then
--                  capture), fighting only what engages (an advance sent ten troopers at a hub's lasers)
--   signal R > 0   retreat to the nearest barracks
--   otherwise      hold: stay by the beacon
local shared = require("__landing-party__.shared")

local command = {}

local ASSIGN_RANGE = 200
local ADVANCE_RANGE = 200
local REISSUE_TICKS = 600          -- an idle trooper is given its orders again after this long
local MILITARY = {"lp-turret", "lp-depot", "lp-radar", "lp-lander", "lp-uplink", "lp-launchpad"}
local SIGNAL_ADVANCE = {type = "virtual", name = "signal-A"}
local SIGNAL_RETREAT = {type = "virtual", name = "signal-R"}
local SIGNAL_OCCUPY = {type = "virtual", name = "signal-O"}

function command.init()
  storage.cmd = storage.cmd or {barracks = {}, beacons = {}, troopers = {}}
end

function command.on_built(e)
  local ent = e.entity
  if not (ent and ent.valid) then return end
  if ent.name == "lp-barracks" then storage.cmd.barracks[ent.unit_number] = ent end
  if ent.name == "lp-rally-beacon" then storage.cmd.beacons[ent.unit_number] = ent end
end

local function nearest(list, pos, force, range)
  local best, bd
  for k, e in pairs(list) do
    if not e.valid then
      list[k] = nil
    elseif e.force == force then
      local d = (e.position.x - pos.x) ^ 2 + (e.position.y - pos.y) ^ 2
      if d <= range * range and (not bd or d < bd) then best, bd = e, d end
    end
  end
  return best
end

-- Finished orders become troopers beside the barracks, assigned to the nearest beacon.
local function train()
  for k, b in pairs(storage.cmd.barracks) do
    if not b.valid then
      storage.cmd.barracks[k] = nil
    else
      local out = b.get_inventory(defines.inventory.crafter_output)
      local n = out.get_item_count("lp-trooper-order")
      for _ = 1, n do
        local p = b.surface.find_non_colliding_position("lp-trooper", {b.position.x, b.position.y + 3}, 10, 0.5)
        local u = p and b.surface.create_entity{name = "lp-trooper", position = p, force = b.force}
        if u then
          out.remove{name = "lp-trooper-order", count = 1}
          local beacon = nearest(storage.cmd.beacons, b.position, b.force, ASSIGN_RANGE)
          storage.cmd.troopers[u.unit_number] = {unit = u, beacon = beacon and beacon.unit_number}
          storage.cmd.trained = (storage.cmd.trained or 0) + 1
        end
      end
    end
  end
end

local function stance(beacon)
  local function sig(s)
    return beacon.get_signal(s, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green) or 0
  end
  if sig(SIGNAL_RETREAT) > 0 then return "retreat" end
  if sig(SIGNAL_ADVANCE) > 0 then return "advance" end
  if sig(SIGNAL_OCCUPY) > 0 then return "occupy" end
  return "hold"
end

-- What an advancing beacon goes for: the nearest faction military target, else the nearest outpost bin.
local function objective(beacon, occupy)
  local s = beacon.surface
  local f = game.forces[shared.FORCE]
  local best, bd, kind
  if not occupy then
    for _, e in pairs(s.find_entities_filtered{position = beacon.position, radius = ADVANCE_RANGE, force = f,
      name = MILITARY}) do
      local d = (e.position.x - beacon.position.x) ^ 2 + (e.position.y - beacon.position.y) ^ 2
      if not bd or d < bd then best, bd, kind = e, d, "attack" end
    end
    if best then return best, kind end
  end
  for _, e in pairs(s.find_entities_filtered{position = beacon.position, radius = ADVANCE_RANGE, force = f,
    name = "lp-bin"}) do
    local d = (e.position.x - beacon.position.x) ^ 2 + (e.position.y - beacon.position.y) ^ 2
    if not bd or d < bd then best, bd, kind = e, d, "occupy" end
  end
  return best, kind
end

-- Go somewhere and stay: an idle unit attacks whatever enemy it sees (troopers that had occupied an outpost
-- walked on and destroyed the lander), so arrival is followed by a wander that never ends.
local function stay(pos, radius, distraction)
  return {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = {
    {type = defines.command.go_to_location, destination = pos, radius = radius, distraction = distraction},
    {type = defines.command.wander, radius = radius, distraction = defines.distraction.by_damage},
  }}
end

local function order(t, cmd, key)
  local u = t.unit
  if t.key == key and u.commandable.has_command and game.tick - (t.at or 0) < REISSUE_TICKS then return end
  u.commandable.set_command(cmd)
  t.key, t.at = key, game.tick
end

local function lead()
  local objectives = {}
  for k, t in pairs(storage.cmd.troopers) do
    local u = t.unit
    if not u.valid then
      storage.cmd.troopers[k] = nil
    else
      local beacon = t.beacon and storage.cmd.beacons[t.beacon]
      if not (beacon and beacon.valid) then
        beacon = nearest(storage.cmd.beacons, u.position, u.force, ASSIGN_RANGE)
        t.beacon = beacon and beacon.unit_number
      end
      if beacon then
        local st = stance(beacon)
        if st == "hold" then
          local d = (u.position.x - beacon.position.x) ^ 2 + (u.position.y - beacon.position.y) ^ 2
          if d > 12 * 12 then
            order(t, stay(beacon.position, 6, defines.distraction.by_enemy), "hold")
          end
        elseif st == "retreat" then
          local home = nearest(storage.cmd.barracks, u.position, u.force, 1000)
          if home then
            order(t, {type = defines.command.go_to_location, destination = home.position, radius = 8,
              distraction = defines.distraction.none}, "retreat")
          end
        else
          -- Occupy locks onto its first outpost until the order changes: re-chosen each time, a squad took
          -- one outpost after another down to the lander. Advance re-targets as targets fall.
          storage.cmd.locks = storage.cmd.locks or {}
          local lock = storage.cmd.locks[beacon.unit_number]
          if st ~= "occupy" or (lock and lock.stance ~= "occupy") then storage.cmd.locks[beacon.unit_number] = nil; lock = nil end
          local o = objectives[beacon.unit_number]
          if st == "occupy" and lock then o = {pos = lock.pos, kind = "occupy", key = lock.key} end
          if o == nil then
            local target, kind = objective(beacon, st == "occupy")
            o = target and {target = target, pos = {target.position.x, target.position.y}, kind = kind,
              key = kind .. ":" .. target.unit_number} or false
            objectives[beacon.unit_number] = o
            if o and st == "occupy" then storage.cmd.locks[beacon.unit_number] = {stance = "occupy", pos = o.pos, key = o.key} end
          end
          if o and o.kind == "attack" then
            order(t, {type = defines.command.attack, target = o.target, distraction = defines.distraction.by_enemy}, o.key)
          elseif o then
            -- Occupying troopers fight back only when hit (attacking what they saw, they went on to destroy
            -- the lander of an undefended settlement).
            order(t, stay(o.pos, 4, defines.distraction.by_damage), o.key)
          end
        end
      end
    end
  end
end

function command.tick(tick)
  if tick % 60 == 0 then train() end
  if tick % 120 == 30 then lead() end
end

function command.stats()
  local alive = 0
  for _, t in pairs(storage.cmd.troopers) do if t.unit.valid then alive = alive + 1 end end
  return {trained = storage.cmd.trained or 0, alive = alive}
end

return command
