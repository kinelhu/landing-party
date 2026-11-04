-- The player's army: barracks turn trooper orders (crafted from items) into troopers; each trooper follows
-- the nearest rally beacon of its force. A beacon is a constant combinator: its signals (its own, or its
-- networks' when wired) set the stance, and X and Y move its rally point that many tiles from it:
--   signal A > 0   advance: attack the nearest faction turret within ATTACK_REACH of the rally point, then
--                  the military targets there no turret covers; with none left, occupy the nearest faction
--                  outpost in that reach, else hold
--   signal O > 0   occupy: go to the nearest faction outpost and stand on it (no rebuild there, then
--                  capture), fighting only what engages (an advance sent ten troopers at a hub's lasers)
--   signal R > 0   retreat to the nearest barracks
--   otherwise      hold: stay at the rally point
-- It reports on its own output: S its squad, E faction units and T faction turrets within reach of the
-- rally point.
local shared = require("__landing-party__.shared")

local command = {}

local ASSIGN_RANGE = 200
local ADVANCE_RANGE = 200          -- outposts an occupy order looks for
-- What an advance attacks: the beacon's own ground. At 200 one beacon sent its squad at a whole settlement,
-- lander included; the player steers an assault by where the beacon stands.
local ATTACK_REACH = 50
local TURRET_COVER = 25            -- a laser's 24 and a little
local REISSUE_TICKS = 600          -- an idle trooper is given its orders again after this long
-- Every corporation's prototypes of these kinds.
local MILITARY = shared.variants({"lp-turret", "lp-mortar", "lp-depot", "lp-radar", "lp-lander", "lp-uplink", "lp-launchpad",
  "lp-optics-lab", "lp-line-lab", "lp-siege-lab"})
local TURRETS = shared.variants({"lp-turret", "lp-mortar"})
local LASERS = shared.variants("lp-turret")
local BINS = shared.variants("lp-bin")
local SIGNAL_ADVANCE = {type = "virtual", name = "signal-A"}
local SIGNAL_RETREAT = {type = "virtual", name = "signal-R"}
local SIGNAL_OCCUPY = {type = "virtual", name = "signal-O"}

function command.init()
  storage.cmd = storage.cmd or {barracks = {}, beacons = {}, troopers = {}}
  storage.cmd.relays = storage.cmd.relays or {}
end

-- Command bandwidth. Capacity: RELAY_CAPACITY for each working relay, as many relays as research allows.
local function research_level(force)
  local level = 0
  for k = 1, 3 do
    local t = force.technologies["lp-command-bandwidth-" .. k]
    if t and t.researched then level = k end
  end
  -- The endless fourth: its level is the next one to research (4 before any), so 3 + done levels. Read as
  -- levels done, an unresearched fourth counted 3 extra levels (siege runs showed level 6).
  local inf = force.technologies["lp-command-bandwidth-4"]
  if inf and level == 3 then
    level = 3 + (inf.level - 4) + (inf.researched and 1 or 0)
  end
  return level
end

function command.capacity(force)
  local level = research_level(force)
  local allowed = shared.RELAYS_BY_LEVEL[math.min(level, 3)]
  if level > 3 then allowed = allowed + (level - 3) * shared.RELAYS_PER_EXTRA_LEVEL end
  local working = 0
  for k, r in pairs(storage.cmd.relays) do
    if not r.valid then
      storage.cmd.relays[k] = nil
    elseif r.force == force and r.status == defines.entity_status.working then
      working = working + 1
    end
  end
  return math.min(working, allowed) * shared.RELAY_CAPACITY
end

local function population(force)
  local p = 0
  for _, t in pairs(storage.cmd.troopers) do
    if t.unit.valid and t.unit.force == force then p = p + (shared.POPULATION[t.unit.name] or 1) end
  end
  return p
end

function command.on_built(e)
  local ent = e.entity
  if not (ent and ent.valid) then return end
  if ent.name == "lp-barracks" then
    storage.cmd.barracks[ent.unit_number] = ent
    if not ent.get_recipe() then ent.set_recipe("lp-trooper-order") end
  end
  if ent.name == "lp-rally-beacon" then storage.cmd.beacons[ent.unit_number] = ent end
  if ent.name == "lp-command-relay" then storage.cmd.relays[ent.unit_number] = ent end
  if ent.name == "lp-muster-point" then
    storage.cmd.musters = storage.cmd.musters or {}
    storage.cmd.musters[ent.unit_number] = ent
    -- Its floodlight on the rally ground at night (the user, 2026-11-04: "why not a built in light"): a chest has no light
    -- of its own; drawn on it, the light goes with it.
    rendering.draw_light{sprite = "utility/light_medium", target = {entity = ent, offset = {-0.2, 0.9}}, surface = ent.surface,
      scale = 1.4, intensity = 0.8, color = {r = 1, g = 0.92, b = 0.75}, minimum_darkness = 0.3}
  end
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

-- Orders in `inv` become units beside `at` (a barracks or a muster point), assigned to the nearest beacon, while the
-- force's bandwidth has room.
local function deploy(at, inv, room)
  local f = at.force
  for item, name in pairs(shared.ORDERS) do
    for _ = 1, inv and inv.get_item_count(item) or 0 do
      local need = shared.POPULATION[name]
      if room[f.index] < need then break end
      local p = at.surface.find_non_colliding_position(name, {at.position.x, at.position.y + 3}, 10, 0.5)
      local u = p and at.surface.create_entity{name = name, position = p, force = f}
      if u then
        room[f.index] = room[f.index] - need
        inv.remove{name = item, count = 1}
        local beacon = nearest(storage.cmd.beacons, at.position, f, ASSIGN_RANGE)
        storage.cmd.troopers[u.unit_number] = {unit = u, beacon = beacon and beacon.unit_number}
        storage.cmd.trained = (storage.cmd.trained or 0) + 1
      end
    end
  end
end

-- Packing (the user, 2026-10-18: "Trains could even play into the mix"): a barracks wired with P > 0 keeps its finished
-- orders as items in its output, for inserters to take and the player's logistics (trains, belts, robots) to carry to
-- a muster point near the front, which turns them into units there.
local PACK = {type = "virtual", name = "signal-P"}
local function packing(b)
  local red, green = defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green
  if not (b.get_circuit_network(red) or b.get_circuit_network(green)) then return false end
  return (b.get_signal(PACK, red, green) or 0) > 0
end

-- Finished orders become units beside the barracks (unless it packs) and from what a muster point holds.
-- A finished order waits in the barracks while bandwidth is full; with its output full, the barracks stops.
local function train()
  local room = {}
  local function has_room(f)
    if room[f.index] == nil then room[f.index] = command.capacity(f) - population(f) end
  end
  for k, b in pairs(storage.cmd.barracks) do
    if not b.valid then
      storage.cmd.barracks[k] = nil
    elseif not packing(b) then
      has_room(b.force)
      deploy(b, b.get_inventory(defines.inventory.crafter_output), room)
    end
  end
  for k, m in pairs(storage.cmd.musters or {}) do
    if not m.valid then
      storage.cmd.musters[k] = nil
    else
      has_room(m.force)
      deploy(m, m.get_inventory(defines.inventory.chest), room)
    end
  end
end

-- What a beacon says, by virtual signal name: its own signals unwired; wired, its networks (which carry its
-- own signals too, so they are not added twice).
local function signals(beacon)
  local red, green = defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green
  local out = {}
  if beacon.get_circuit_network(red) or beacon.get_circuit_network(green) then
    for _, x in pairs(beacon.get_signals(red, green) or {}) do
      if x.signal.type == "virtual" then out[x.signal.name] = x.count end
    end
  else
    local cb = beacon.get_control_behavior()
    if cb and cb.enabled then
      for _, section in pairs(cb.sections) do
        if section.active then
          for _, f in pairs(section.filters) do
            if f.value and f.value.type == "virtual" then out[f.value.name] = (out[f.value.name] or 0) + (f.min or 0) end
          end
        end
      end
    end
  end
  return out
end

-- A beacon's orders: the stance, and the rally point, the beacon moved by signals X and Y (tiles, capped):
-- a clock wired to it walks a patrol, a decider sends an attack.
local MAX_OFFSET = 300
local function plan(beacon)
  local sig = signals(beacon)
  local function v(name) return sig[name] or 0 end
  local st = "hold"
  if v(SIGNAL_RETREAT.name) > 0 then st = "retreat"
  elseif v(SIGNAL_ADVANCE.name) > 0 then st = "advance"
  elseif v(SIGNAL_OCCUPY.name) > 0 then st = "occupy" end
  local dx = math.max(-MAX_OFFSET, math.min(MAX_OFFSET, v("signal-X")))
  local dy = math.max(-MAX_OFFSET, math.min(MAX_OFFSET, v("signal-Y")))
  return {stance = st, pos = {x = beacon.position.x + dx, y = beacon.position.y + dy}, surface = beacon.surface}
end

-- What an advancing beacon goes for: the nearest faction turret, else the nearest military target, else the
-- nearest outpost bin.
local function objective(p, occupy)
  local s, at = p.surface, p.pos
  local f = shared.corp_forces()
  local best, bd, kind
  if not occupy then
    -- Turrets first: sent at the nearest military building, a squad of 60 shot a depot between two turret
    -- groups and died to them (siege, seed 12345).
    -- Then what no turret covers: those in reach are gone by now, so a cover is outside it (a depot in reach
    -- covered by a compound's turret beyond it drew the squad into that turret's fire, siege seed 12345).
    for _, names in ipairs({TURRETS, MILITARY}) do
      for _, e in pairs(s.find_entities_filtered{position = at, radius = ATTACK_REACH, force = f, name = names}) do
        local d = (e.position.x - at.x) ^ 2 + (e.position.y - at.y) ^ 2
        local covered = shared.kind_of(e.name) ~= "lp-turret" and s.count_entities_filtered{position = e.position,
          radius = TURRET_COVER, force = f, name = LASERS, limit = 1} > 0
        if not covered and (not bd or d < bd) then best, bd, kind = e, d, "attack" end
      end
      if best then return best, kind end
    end
  end
  -- An advance occupies only on the beacon's own ground: reaching beyond, a squad that had cleared its ground
  -- walked past a walled turret compound to an outpost 60 tiles on, and died (siege, seed 12345).
  for _, e in pairs(s.find_entities_filtered{position = at, radius = occupy and ADVANCE_RANGE or ATTACK_REACH,
    force = f, name = BINS}) do
    local d = (e.position.x - at.x) ^ 2 + (e.position.y - at.y) ^ 2
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

-- Units beyond capacity (a relay lost or unpowered) go offline, newest first, until bandwidth returns:
-- they stop where they are and only fight back.
local function offline_set()
  local by_force = {}
  local keys = {}
  for k, t in pairs(storage.cmd.troopers) do
    if t.unit.valid then table.insert(keys, k) else storage.cmd.troopers[k] = nil end
  end
  table.sort(keys)
  local out, used, cap = {}, {}, {}
  for _, k in ipairs(keys) do
    local u = storage.cmd.troopers[k].unit
    local f = u.force.index
    if cap[f] == nil then cap[f] = command.capacity(u.force); used[f] = 0 end
    used[f] = used[f] + (shared.POPULATION[u.name] or 1)
    if used[f] > cap[f] then out[k] = true end
  end
  return out
end

-- Units before buildings: a trooper with a faction unit near fights it. Ordered to attack a depot, a squad
-- of 20 kept shooting it while the depot's garrison killed every one and lost none (siege, seed 12345).
-- Leashed to the beacon's reach (not out of turret cover too: two tanks parked at a compound's cover edge then
-- shot a holding squad unanswered for half a minute): chasing a garrison as it fell back, troopers followed it into a walled
-- compound's lasers and mines and 33 of 45 died while their beacon said hold (siege, seed 12345).
local ENGAGE = 18
local function threat(u, p)
  local best, bd
  for _, e in pairs(u.surface.find_entities_filtered{position = u.position, radius = ENGAGE, force = shared.corp_forces(),
    type = {"unit", "spider-unit"}}) do
    local d = (e.position.x - u.position.x) ^ 2 + (e.position.y - u.position.y) ^ 2
    local leash = (e.position.x - p.pos.x) ^ 2 + (e.position.y - p.pos.y) ^ 2 <= ATTACK_REACH * ATTACK_REACH
    if leash and (not bd or d < bd) then best, bd = e, d end
  end
  return best
end

-- The beacon's orders drawn for its force: a ring of its reach at the rally point, coloured by stance, and a
-- line from the beacon when signals move the point.
local COLOR = {hold = {0.8, 0.8, 0.8, 0.4}, advance = {1, 0.25, 0.1, 0.6}, occupy = {1, 0.8, 0.1, 0.6},
  retreat = {0.3, 0.5, 1, 0.6}}
local function mark(k, beacon, p)
  storage.cmd.marks = storage.cmd.marks or {}
  local m = storage.cmd.marks[k]
  if not (m and m.ring.valid and m.line.valid) then
    m = {ring = rendering.draw_circle{color = COLOR.hold, radius = ATTACK_REACH, width = 2, filled = false,
           target = p.pos, surface = beacon.surface, forces = {beacon.force}, draw_on_ground = true},
         line = rendering.draw_line{color = COLOR.hold, width = 2, dash_length = 1, gap_length = 1, from = beacon,
           to = p.pos, surface = beacon.surface, forces = {beacon.force}, draw_on_ground = true}}
    storage.cmd.marks[k] = m
  end
  m.ring.target = p.pos
  m.ring.color = COLOR[p.stance]
  m.line.to = p.pos
  m.line.color = COLOR[p.stance]
end

-- The beacon's report, written into a section of its own (the first holding only report signals; made when
-- missing): S its squad, E faction units and T faction turrets within reach of the rally point. A decider
-- reading S can send A when the squad is full, or R when it is beaten.
local REPORTED = {["signal-S"] = true, ["signal-E"] = true, ["signal-T"] = true}
local function report(beacon, p, squad)
  local cb = beacon.get_or_create_control_behavior()
  local sec
  for _, s in pairs(cb.sections) do
    if s.is_manual and s.group == "" and #s.filters > 0 then
      local only = true
      for _, f in pairs(s.filters) do if not (f.value and REPORTED[f.value.name]) then only = false end end
      if only then sec = s; break end
    end
  end
  sec = sec or cb.add_section()
  if not sec then return end
  local s = p.surface
  local function v(name, n) return {value = {type = "virtual", name = name, quality = "normal"}, min = n} end
  sec.filters = {
    v("signal-S", squad),
    v("signal-E", s.count_entities_filtered{position = p.pos, radius = ATTACK_REACH, force = shared.corp_forces(),
      type = {"unit", "spider-unit"}}),
    v("signal-T", s.count_entities_filtered{position = p.pos, radius = ATTACK_REACH, force = shared.corp_forces(),
      name = LASERS}),
  }
end

-- Hand orders (the command tool). A unit picked by hand obeys its order over its beacon until released.
--   move        go there ignoring fire, then hold there
--   attackmove  go there fighting anything on the way, then hold
--   attack      attack a faction entity; when it falls, hold where it stood
local function manual(t)
  local m = t.manual
  local key = "m" .. m.seq
  if m.kind == "attack" then
    if m.target and m.target.valid then
      return order(t, {type = defines.command.attack, target = m.target, distraction = defines.distraction.by_enemy}, key)
    end
    m.kind = "hold"
  end
  if m.kind == "move" then
    order(t, {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = {
      {type = defines.command.go_to_location, destination = m.pos, radius = 3, distraction = defines.distraction.none},
      {type = defines.command.wander, radius = 5, distraction = defines.distraction.by_enemy}}}, key)
  elseif m.kind == "attackmove" then
    order(t, {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = {
      {type = defines.command.go_to_location, destination = m.pos, radius = 3, distraction = defines.distraction.by_anything},
      {type = defines.command.wander, radius = 6, distraction = defines.distraction.by_enemy}}}, key)
  else
    order(t, stay(m.pos, 5, defines.distraction.by_enemy), key .. "h")
  end
end

local function lead()
  local objectives = {}
  local plans = {}
  local squads = {}
  for _, t in pairs(storage.cmd.troopers) do
    if t.unit.valid and t.beacon then squads[t.beacon] = (squads[t.beacon] or 0) + 1 end
  end
  for k, b in pairs(storage.cmd.beacons) do
    if b.valid then
      plans[k] = plan(b)
      mark(k, b, plans[k])
      report(b, plans[k], squads[k] or 0)
    else
      storage.cmd.beacons[k] = nil
    end
  end
  for k, m in pairs(storage.cmd.marks or {}) do
    if not plans[k] then m.ring.destroy(); m.line.destroy(); storage.cmd.marks[k] = nil end
  end
  local offline = offline_set()
  for k, t in pairs(storage.cmd.troopers) do
    local u = t.unit
    if not u.valid then
      storage.cmd.troopers[k] = nil
    elseif offline[k] then
      if not t.offline then
        t.offline = true
        u.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.by_damage}
        t.key = "offline"
      end
    elseif t.manual then
      t.offline = nil
      manual(t)
    else
      t.offline = nil
      local beacon = t.beacon and storage.cmd.beacons[t.beacon]
      if not (beacon and beacon.valid) then
        beacon = nearest(storage.cmd.beacons, u.position, u.force, ASSIGN_RANGE)
        t.beacon = beacon and beacon.unit_number
      end
      local p = beacon and plans[beacon.unit_number]
      local st = p and p.stance
      local foe = p and st ~= "retreat" and threat(u, p)
      -- Holding at the rally point; the key carries the point, so a moved point is a new order.
      local function hold()
        if (u.position.x - p.pos.x) ^ 2 + (u.position.y - p.pos.y) ^ 2 > 12 * 12 then
          order(t, stay(p.pos, 6, defines.distraction.by_enemy), string.format("hold:%d,%d", p.pos.x, p.pos.y))
        end
      end
      if foe then
        order(t, {type = defines.command.attack, target = foe, distraction = defines.distraction.by_enemy},
          "fight:" .. foe.unit_number)
      elseif p then
        if st == "hold" then
          hold()
        elseif st == "retreat" then
          local home = nearest(storage.cmd.barracks, u.position, u.force, 1000)
          if home then
            order(t, {type = defines.command.go_to_location, destination = home.position, radius = 8,
              distraction = defines.distraction.none}, "retreat")
          end
        else
          -- Occupy locks onto its first outpost until the order or the rally point changes: re-chosen each
          -- time, a squad took one outpost after another down to the lander. Advance re-targets as targets fall.
          storage.cmd.locks = storage.cmd.locks or {}
          local here = string.format("%d,%d", p.pos.x, p.pos.y)
          local lock = storage.cmd.locks[beacon.unit_number]
          if st ~= "occupy" or (lock and (lock.stance ~= "occupy" or lock.at ~= here)) then
            storage.cmd.locks[beacon.unit_number] = nil; lock = nil
          end
          local o = objectives[beacon.unit_number]
          if st == "occupy" and lock then o = {pos = lock.pos, kind = "occupy", key = lock.key} end
          if o == nil then
            local target, kind = objective(p, st == "occupy")
            o = target and {target = target, pos = {target.position.x, target.position.y}, kind = kind,
              key = kind .. ":" .. target.unit_number} or false
            objectives[beacon.unit_number] = o
            if o and st == "occupy" then
              storage.cmd.locks[beacon.unit_number] = {stance = "occupy", pos = o.pos, key = o.key, at = here}
            end
          end
          if o and o.kind == "attack" then
            order(t, {type = defines.command.attack, target = o.target, distraction = defines.distraction.by_enemy}, o.key)
          elseif o then
            -- Occupying troopers fight back only when hit (attacking what they saw, they went on to destroy
            -- the lander of an undefended settlement).
            order(t, stay(o.pos, 4, defines.distraction.by_damage), o.key)
          else
            -- Nothing left in reach: to the rally point, to hold.
            hold()
          end
        end
      end
    end
  end
end

-- Field repair: the player's units near a powered barracks recover REPAIR_SHARE of their health a second, so
-- a squad pulled back (R) comes back whole; out in the field nothing mends them.
local REPAIR_RANGE = 30
local REPAIR_SHARE = 0.02
local UNIT_NAMES = {}
for _, name in pairs(shared.ORDERS) do table.insert(UNIT_NAMES, name) end
local function repair()
  for _, b in pairs(storage.cmd.barracks) do
    if b.valid and b.energy > 0 then
      for _, u in pairs(b.surface.find_entities_filtered{position = b.position, radius = REPAIR_RANGE, force = b.force,
        name = UNIT_NAMES}) do
        if u.health < u.max_health then u.health = math.min(u.max_health, u.health + u.max_health * REPAIR_SHARE) end
      end
    end
  end
end

-- The command tool's actions (control.lua passes the selection events; tests call these directly).
local function rings(player_index)
  storage.cmd.rings = storage.cmd.rings or {}
  for _, r in ipairs(storage.cmd.rings[player_index] or {}) do r.destroy() end
  local out = {}
  storage.cmd.rings[player_index] = out
  if not game.get_player(player_index) then return end
  for un in pairs(storage.cmd.selected[player_index] or {}) do
    local t = storage.cmd.troopers[un]
    if t and t.unit.valid then
      table.insert(out, rendering.draw_circle{color = {0.4, 1, 0.4, 0.8}, radius = t.unit.name == "lp-battle-tank" and 1.6 or 0.7,
        width = 2, filled = false, target = t.unit, surface = t.unit.surface, players = {player_index}, draw_on_ground = true})
    end
  end
end

function command.select(player_index, units)
  storage.cmd.selected = storage.cmd.selected or {}
  local sel, n = {}, 0
  for _, u in pairs(units) do
    if u.valid and storage.cmd.troopers[u.unit_number] then sel[u.unit_number] = true; n = n + 1 end
  end
  storage.cmd.selected[player_index] = sel
  rings(player_index)
  return n
end

function command.release(player_index, units)
  storage.cmd.selected = storage.cmd.selected or {}
  local sel = storage.cmd.selected[player_index] or {}
  local n = 0
  for _, u in pairs(units) do
    local t = u.valid and storage.cmd.troopers[u.unit_number]
    if t then t.manual, t.key = nil, nil; sel[u.unit_number] = nil; n = n + 1 end
  end
  rings(player_index)
  return n
end

-- An order for the selection: on a faction entity, attack it; elsewhere, move (or attack-move) to the middle
-- of the area clicked or dragged.
function command.order(player_index, surface, area, attackmove)
  storage.cmd.selected = storage.cmd.selected or {}
  local sel = storage.cmd.selected[player_index] or {}
  local lt, rb = area.left_top or area[1], area.right_bottom or area[2]
  local pos = {x = ((lt.x or lt[1]) + (rb.x or rb[1])) / 2, y = ((lt.y or lt[2]) + (rb.y or rb[2])) / 2}
  local target = surface.find_entities_filtered{area = {{pos.x - 1.5, pos.y - 1.5}, {pos.x + 1.5, pos.y + 1.5}},
    force = shared.corp_forces(), type = {"unit", "spider-unit", "electric-turret", "ammo-turret", "artillery-turret", "container",
      "electric-energy-interface", "radar", "assembling-machine", "mining-drill", "generator"}, limit = 1}[1]
  storage.cmd.seq = (storage.cmd.seq or 0) + 1
  local n = 0
  for un in pairs(sel) do
    local t = storage.cmd.troopers[un]
    if t and t.unit.valid then
      t.manual = {kind = target and "attack" or (attackmove and "attackmove" or "move"), pos = pos, target = target,
        seq = storage.cmd.seq}
      t.key = nil
      manual(t)
      n = n + 1
    else
      sel[un] = nil
    end
  end
  if n > 0 and game.get_player(player_index) then
    rendering.draw_circle{color = target and {1, 0.3, 0.2} or (attackmove and {1, 0.6, 0.2} or {0.4, 0.7, 1}),
      radius = 1.5, width = 3, filled = false, target = target or pos, surface = surface, players = {player_index},
      time_to_live = 45, draw_on_ground = true}
  end
  return n, target and "attack" or (attackmove and "attackmove" or "move")
end

function command.tick(tick)
  if tick % 60 == 0 then train(); repair() end
  if tick % 120 == 30 then lead() end
end

function command.stats()
  local alive, offline = 0, 0
  for _, t in pairs(storage.cmd.troopers) do
    if t.unit.valid then alive = alive + 1; if t.offline then offline = offline + 1 end end
  end
  local f = game.forces.player
  local orders = {}
  for _, t in pairs(storage.cmd.troopers) do
    if t.unit.valid then
      local k = (t.key or "none"):gsub(":%d+", "")
      orders[k] = (orders[k] or 0) + 1
    end
  end
  return {trained = storage.cmd.trained or 0, alive = alive, offline = offline, capacity = command.capacity(f),
    level = research_level(f), orders = orders, locks = storage.cmd.locks}
end

-- Command cores dropped by the faction's wreckage, lootable.
function command.drop_cores(surface, pos, count)
  shared.wreck(surface, pos, {{name = "lp-command-core", count = count}})
  storage.cmd.cores_dropped = (storage.cmd.cores_dropped or 0) + count
end

-- A captured outpost yields a core (base.lua cannot require this module's caller chain; it calls the hook).
require("__landing-party__.scripts.base").on_capture = function(surface, pos)
  command.drop_cores(surface, {x = pos[1], y = pos[2]}, 1)
end

return command
