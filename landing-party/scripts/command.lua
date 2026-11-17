-- The player's army: barracks turn trooper orders (crafted from items) into troopers; each trooper follows
-- the nearest rally beacon of its force. A beacon is a constant combinator: its signals (its own, or its
-- networks' when wired) set the stance, and X and Y move its rally point that many tiles from it:
--   signal A > 0   advance: attack the nearest faction turret within ATTACK_REACH of the rally point, then
--                  the military targets there no turret covers; with none left, occupy the nearest faction
--                  outpost in that reach, else hold
--   signal O > 0   occupy: go to the nearest faction outpost and stand on it (no rebuild there, then
--                  capture), fighting only what engages (an advance sent ten troopers at a hub's lasers)
--   signal R > 0   retreat to the nearest barracks
--   signal D > 0   defend: hold, and answer an attack on the player within DEFEND_REACH of the rally point (a strike
--                  force told or landed, or enemy units at the player's buildings), then come back
--   otherwise      hold: stay at the rally point
-- It reports on its own output: S its squad, E faction units and T faction turrets within reach of the
-- rally point, W 1 while a defending squad is out.
local shared = require("__landing-party__.shared")
local paving = require("__landing-party__.scripts.paving")

local command = {}

local ASSIGN_RANGE = 200
local ADVANCE_RANGE = 200          -- outposts an occupy order looks for
-- What an advance attacks: the beacon's own ground. At 200 one beacon sent its squad at a whole settlement,
-- lander included; the player steers an assault by where the beacon stands.
local ATTACK_REACH = 50
local TURRET_COVER = 25            -- a laser's 24 and a little
local REISSUE_TICKS = 600          -- an idle trooper is given its orders again after this long
-- The player's own gates (scenario owngates: six troopers behind the player's gates never left, as many through a gap
-- did). A unit plans its path when ordered and takes a shut gate for wall, so an order opens its force's gates within
-- GATE_PLAN for its reissue time, and each pass of lead holds open those within GATE_NEAR of a trooper.
local GATE_PLAN = 40
-- Paved ways (scripts/paving.lua; the user, 2026-11-17): the engine's pathfinder ignores a tile's speed, so an order's
-- walk of ROUTE_MIN tiles or more, with paving in its area, is searched by the road router; the unit sets off straight
-- and takes the route when it comes, if it costs at most ROUTE_GAIN of the straight walk. A squad's units given the
-- same order within ROUTE_NEAR tiles of the first share its search. Waypoints within ROUTE_RADIUS (2 let a trooper
-- arrive a tile off-centre and walk a 4-wide road's edge, off the concrete: slower than the grass, scenario paved),
-- one every ROUTE_STEP tiles.
local ROUTE_MIN = 40
local ROUTE_GAIN = 0.97
local ROUTE_NEAR = 16
local ROUTE_RADIUS = 1
local ROUTE_STEP = 8
local ROUTE_KEEP = 60 * 60       -- a search's result is shared this long
local GATE_NEAR = 6
-- Every corporation's prototypes of these kinds.
local MILITARY = shared.variants({"lp-turret", "lp-mortar", "lp-depot", "lp-radar", "lp-lander", "lp-uplink", "lp-launchpad",
  "lp-optics-lab", "lp-line-lab", "lp-siege-lab"})
local TURRETS = shared.variants({"lp-turret", "lp-mortar"})
local LASERS = shared.variants("lp-turret")
local BINS = shared.variants("lp-bin")
local SIGNAL_ADVANCE = {type = "virtual", name = "signal-A"}
local SIGNAL_RETREAT = {type = "virtual", name = "signal-R"}
local SIGNAL_OCCUPY = {type = "virtual", name = "signal-O"}
local SIGNAL_DEFEND = {type = "virtual", name = "signal-D"}
-- The defend stance (the army consult, 2026-11-16: a squad fought only within 18 tiles of a unit and 50 of its rally
-- point, so nothing answered a strike or a raid unless the player was at the screen). What sets it off is what the player
-- is told or sees: a strike force whose pods the player's radar sees (or whose target the player is told), a strike
-- force landed, enemy units at the player's buildings. Never a raid's launch, which the player is not told.
local DEFEND_REACH = 150   -- tiles from the rally point it answers (a battle tank's 28 s)
local DEFEND_NEAR = 16     -- an enemy unit this close to a building of the player's is attacking it
local DEFEND_CLEAR = 30    -- an attack is over with no enemy unit this close for DEFEND_QUIET seconds
local DEFEND_QUIET = 60

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

-- Relays working and how many count (research), for the cap and its readout.
local function relays(force)
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
  return working, allowed, level
end

function command.capacity(force)
  local working, allowed = relays(force)
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

-- Squad sizes (the user, 2026-11-10: "Retiring: no signal for this? Manual only is not good"): a rally beacon's
-- lp-squad-<unit> signals (shared.SQUAD_SIGNALS) cap how many of that unit its squad keeps. An order deploys to the nearest
-- beacon in reach with room for its unit (one without a cap for it has room); with every beacon in reach full, it waits
-- where it is (a barracks' output fills and the barracks stops; a muster point holds it). Above a cap, the surplus walks
-- to a barracks and hands its orders in (enforce, below). squad_room: below, after signals.
local squad_room
local hint            -- (below: a stuck player's hint)
-- Orders in `inv` become units beside `at` (a barracks or a muster point), assigned to the nearest beacon with room for
-- them, while the force's bandwidth has room.
local function deploy(at, inv, room, squads)
  local f = at.force
  -- (By quality: an order's quality is its unit's, and back when retired. Read by name alone, a rare order deployed a
  -- normal unit and retired as a normal order; the army consult, 2026-11-16.)
  local stacks = {}
  for _, c in ipairs(inv and inv.get_contents() or {}) do
    if shared.ORDERS[c.name] then stacks[#stacks + 1] = c end
  end
  table.sort(stacks, function(a, b) if a.name ~= b.name then return a.name < b.name end return a.quality < b.quality end)
  for _, c in ipairs(stacks) do
    local item, name, quality = c.name, shared.ORDERS[c.name], c.quality
    for _ = 1, c.count do
      local need = shared.POPULATION[name]
      if room[f.index] < need then break end
      local beacon, full = squad_room(at.position, f, name, squads)
      if full then break end
      local p = at.surface.find_non_colliding_position(name, {at.position.x, at.position.y + 3}, 10, 0.5)
      local u = p and at.surface.create_entity{name = name, position = p, force = f, quality = quality}
      if u then
        room[f.index] = room[f.index] - need
        inv.remove{name = item, count = 1, quality = quality}
        if beacon then
          local c = squads.count[beacon.unit_number] or {}
          c[name] = (c[name] or 0) + 1
          squads.count[beacon.unit_number] = c
        end
        storage.cmd.troopers[u.unit_number] = {unit = u, beacon = beacon and beacon.unit_number}
        -- The first unit a force deploys with no beacon in reach stands where it is: told once why (the tutorial).
        if not beacon then hint(f, "no-beacon", at) end
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
-- A stuck player's hint (the user, 2026-11-10: "Yes to tutorial"), once a force: at the building, and in chat.
hint = function(f, key, at)
  storage.cmd.hints = storage.cmd.hints or {}
  local k = f.index .. ":" .. key
  if storage.cmd.hints[k] then return end
  storage.cmd.hints[k] = game.tick
  for _, p in pairs(f.connected_players) do
    p.create_local_flying_text{text = {"lp.hint-" .. key, ""}, position = at.position, time_to_live = 600, speed = 0.3}
  end
  shared.notice(f, {"lp.hint-" .. key, string.format("[gps=%d,%d,%s]", at.position.x, at.position.y, at.surface.name)})
end
command.hint = hint

local squad_counts   -- (below)
local function train()
  local room = {}
  local squads = squad_counts()
  local function has_room(f)
    if room[f.index] == nil then room[f.index] = command.capacity(f) - population(f) end
  end
  for k, b in pairs(storage.cmd.barracks) do
    if not b.valid then
      storage.cmd.barracks[k] = nil
    elseif not packing(b) then
      has_room(b.force)
      -- A finished order waiting with no bandwidth at all (no powered relay): told once why.
      local out = b.get_inventory(defines.inventory.crafter_output)
      if command.capacity(b.force) <= 0 and out and not out.is_empty() then hint(b.force, "no-relay", b) end
      deploy(b, out, room, squads)
    end
  end
  for k, m in pairs(storage.cmd.musters or {}) do
    if not m.valid then
      storage.cmd.musters[k] = nil
    else
      has_room(m.force)
      deploy(m, m.get_inventory(defines.inventory.chest), room, squads)
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

-- A beacon's squad sizes: unit name to its cap, nil where it sets none.
local function caps(beacon)
  local sig, out = signals(beacon), nil
  for unit, s in pairs(shared.SQUAD_SIGNALS) do
    if sig[s] then out = out or {}; out[unit] = math.max(0, sig[s]) end
  end
  return out
end
command.caps = caps

-- Each beacon's units by name (alive, not on their way to retire), and its caps, read once a pass.
squad_counts = function()
  local count, cap = {}, {}
  for _, t in pairs(storage.cmd.troopers) do
    if t.beacon and t.unit.valid and not (t.manual and t.manual.kind == "retire") then
      local c = count[t.beacon] or {}
      c[t.unit.name] = (c[t.unit.name] or 0) + 1
      count[t.beacon] = c
    end
  end
  return {count = count, cap = cap}
end

-- The beacon a new unit of `name` joins: the nearest in reach with room for it. Returns it (nil: none in reach), and
-- whether every beacon in reach is full for it (the order then waits).
squad_room = function(pos, force, name, squads)
  local list = {}
  for k, b in pairs(storage.cmd.beacons) do
    if not b.valid then
      storage.cmd.beacons[k] = nil
    elseif b.force == force then
      local d = (b.position.x - pos.x) ^ 2 + (b.position.y - pos.y) ^ 2
      if d <= ASSIGN_RANGE * ASSIGN_RANGE then list[#list + 1] = {b = b, d = d} end
    end
  end
  if #list == 0 then return nil, false end
  table.sort(list, function(x, y) return x.d < y.d end)
  for _, e in ipairs(list) do
    local id = e.b.unit_number
    if squads.cap[id] == nil then squads.cap[id] = caps(e.b) or false end
    local c = squads.cap[id] and squads.cap[id][name]
    if not c or ((squads.count[id] or {})[name] or 0) < c then return e.b, false end
  end
  return nil, true
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
  elseif v(SIGNAL_OCCUPY.name) > 0 then st = "occupy"
  elseif v(SIGNAL_DEFEND.name) > 0 then st = "defend" end
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

-- An order's first leg: its go_to_location, alone or first of a compound.
local function first_leg(cmd)
  if cmd.type == defines.command.go_to_location then return cmd, nil end
  if cmd.type == defines.command.compound and cmd.commands[1] and cmd.commands[1].type == defines.command.go_to_location then
    return cmd.commands[1], cmd
  end
end

-- The order with its first leg walked along a route: the route's turns, then the leg's own destination (a formation's
-- slot is each unit's own) and whatever followed it.
-- (A point every ROUTE_STEP tiles along each stretch: between two far points the engine walks its own way, straight
-- then diagonal, and three troopers of six walked the grass 10 tiles beside the road they had been routed down.)
local function routed(cmd, path, from)
  local leg, comp = first_leg(cmd)
  local cmds = {}
  local a = from
  for n = 1, #path - 1 do
    local b = path[n]
    local dx, dy = b.x - a.x, b.y - a.y
    local k = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / ROUTE_STEP))
    for m = 1, k do
      cmds[#cmds + 1] = {type = defines.command.go_to_location, destination = {x = a.x + dx * m / k, y = a.y + dy * m / k},
        radius = ROUTE_RADIUS, distraction = leg.distraction}
    end
    a = b
  end
  cmds[#cmds + 1] = leg
  for n = 2, comp and #comp.commands or 1 do cmds[#cmds + 1] = comp.commands[n] end
  return {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = cmds}
end

-- A route for this unit's order: shared from a squad mate's search begun near it, else a new search (nil: none wanted).
-- storage.cmd.routes[key] is the order's searches, each {id, from, surface, at, path (nil: searching; false: none)}.
local function route_for(t, cmd, key)
  local u = t.unit
  local leg = first_leg(cmd)
  if not leg then return nil end
  local to = {x = leg.destination.x or leg.destination[1], y = leg.destination.y or leg.destination[2]}
  if not paving.wanted(u.surface, u.position, to, ROUTE_MIN) then return nil end
  storage.cmd.routes = storage.cmd.routes or {}
  local list = storage.cmd.routes[key]
  if not list then list = {}; storage.cmd.routes[key] = list end
  local p = u.position
  for _, r in ipairs(list) do
    if r.surface == u.surface.index and (r.from.x - p.x) ^ 2 + (r.from.y - p.y) ^ 2 <= ROUTE_NEAR * ROUTE_NEAR then return r end
  end
  local r = {id = paving.request(u.surface, p, to), from = {x = p.x, y = p.y}, surface = u.surface.index, at = game.tick}
  list[#list + 1] = r
  storage.cmd.route_searches = (storage.cmd.route_searches or 0) + 1
  return r
end

local function order(t, cmd, key)
  local u = t.unit
  -- (Fighting: not given the same order again while it is distracted. Given again every REISSUE_TICKS, a unit in a fight on
  -- an attack-move broke off and walked on, deaf to the enemy for its distraction cooldown (5 s): the user, playtest:
  -- "Units often walk to their doom without firing a shot". Its order resumes when the fight is over. An attack-move's
  -- alone: a squad on hold is kept home by its order given again, and held so it chased its fight 190 tiles out, armyhold.)
  if t.key == key and t.manual and t.manual.kind == "attackmove" and u.commandable.distraction_command then
    storage.cmd.kept_fighting = (storage.cmd.kept_fighting or 0) + 1
    return
  end
  if t.key == key and u.commandable.has_command and game.tick - (t.at or 0) < REISSUE_TICKS then return end
  -- (Walking a route: not given its order again from where it stands, which would search again or walk back, unless it
  -- is still at it three times as long.)
  if t.key == key and t.routed and u.commandable.has_command and game.tick - (t.at or 0) < 3 * REISSUE_TICKS then return end
  for _, g in pairs(u.surface.find_entities_filtered{type = "gate", force = u.force, position = u.position, radius = GATE_PLAN}) do
    g.request_to_open(u.force, REISSUE_TICKS)
  end
  t.routed, t.route = nil, nil
  local r = route_for(t, cmd, key)
  if r and r.path then
    u.commandable.set_command(routed(cmd, r.path, r.from))
    t.routed = true
  else
    u.commandable.set_command(cmd)
    if r and r.path == nil then t.route = {key = key, id = r.id, cmd = cmd} end
  end
  t.key, t.at = key, game.tick
end

-- Searches come in: each unit still waiting on one, its order still the same, takes its route.
local function routes_tick()
  local routes = storage.cmd.routes
  if not routes then return end
  local landed = {}
  for key, list in pairs(routes) do
    for n = #list, 1, -1 do
      local r = list[n]
      if r.path == nil then
        local res = paving.result(r.id)
        if res then
          r.path = (not res.failed and res.path and #res.path > 1
            and (not res.straight or res.cost <= res.straight * ROUTE_GAIN)) and res.path or false
          landed[r.id] = r
          if r.path then storage.cmd.routes_taken = (storage.cmd.routes_taken or 0) + 1 end
        end
      elseif game.tick - r.at > ROUTE_KEEP then
        table.remove(list, n)
      end
    end
    if #list == 0 then routes[key] = nil end
  end
  if not next(landed) then return end
  for _, t in pairs(storage.cmd.troopers) do
    local w = t.route
    local r = w and landed[w.id]
    if w and not (t.unit.valid and t.key == w.key) then
      t.route = nil
    elseif r then
      t.route = nil
      -- (Not while it fights: the route set then broke the fight off, as above, and walked it back to where it searched.)
      if r.path and t.unit.commandable.distraction_command then
        storage.cmd.kept_fighting = (storage.cmd.kept_fighting or 0) + 1
      elseif r.path then t.unit.commandable.set_command(routed(w.cmd, r.path, r.from)); t.routed = true end
    end
  end
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
  for _, e in pairs(u.surface.find_entities_filtered{position = u.position, radius = ENGAGE, force = shared.hostile_forces(),
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
  retreat = {0.3, 0.5, 1, 0.6}, defend = {0.25, 0.85, 0.45, 0.6}}
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
  -- (A defending beacon's ring is the reach it answers in.)
  m.ring.radius = p.stance == "defend" and DEFEND_REACH or ATTACK_REACH
  m.line.to = p.pos
  m.line.color = COLOR[p.stance]
end

-- The beacon's report, written into a section of its own (the first holding only report signals; made when
-- missing): S its squad, E faction units and T faction turrets within reach of the rally point. A decider
-- reading S can send A when the squad is full, or R when it is beaten.
local REPORTED = {["signal-S"] = true, ["signal-E"] = true, ["signal-T"] = true, ["signal-W"] = true}
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
    v("signal-E", s.count_entities_filtered{position = p.pos, radius = ATTACK_REACH, force = shared.hostile_forces(),
      type = {"unit", "spider-unit"}}),
    v("signal-T", s.count_entities_filtered{position = p.pos, radius = ATTACK_REACH, force = shared.corp_forces(),
      name = LASERS}),
    v("signal-W", p.alarm and 1 or 0),
  }
end

-- Hand orders (the command tool). A unit picked by hand obeys its order over its beacon until released.
--   move        go there ignoring fire, then hold there
--   attackmove  go there fighting anything on the way, then hold
--   attack      attack a faction entity; when it falls, hold where it stood
local function manual(t)
  local m = t.manual
  local key = "m" .. m.seq
  if m.kind == "retire" then
    -- (Home to its barracks, undistracted: a retired unit is no longer the army's, retire_step.)
    if m.target and m.target.valid then
      return order(t, {type = defines.command.go_to_location, destination = m.target.position, radius = 4,
        distraction = defines.distraction.none}, key)
    end
    return
  end
  if m.kind == "attack" then
    if m.target and m.target.valid then
      return order(t, {type = defines.command.attack, target = m.target, distraction = defines.distraction.by_enemy}, key)
    end
    m.kind = "hold"
  end
  -- (In a formation, each to its own slot and close: radius 1, wandering 1.5, where a heap at one point took 3 and 5.)
  local r, w = m.slotted and 1 or 3, m.slotted and 1.5 or 5
  if m.kind == "move" then
    order(t, {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = {
      {type = defines.command.go_to_location, destination = m.pos, radius = r, distraction = defines.distraction.none},
      {type = defines.command.wander, radius = w, distraction = defines.distraction.by_enemy}}}, key)
  elseif m.kind == "attackmove" then
    order(t, {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = {
      {type = defines.command.go_to_location, destination = m.pos, radius = r, distraction = defines.distraction.by_anything},
      {type = defines.command.wander, radius = m.slotted and 2 or 6, distraction = defines.distraction.by_enemy}}}, key)
  else
    order(t, stay(m.pos, 5, defines.distraction.by_enemy), key .. "h")
  end
end

local function open_near(u)
  for _, g in pairs(u.surface.find_entities_filtered{type = "gate", force = u.force, position = u.position, radius = GATE_NEAR}) do
    g.request_to_open(u.force, 180)
  end
end

-- What a defending beacon answers, read once a pass for each force with one: its strike forces from the director's own
-- record (seen: the landing point; told: the target; landed: the live unit nearest its target, till it breaks or ends),
-- and the attacks on its buildings, found by scanning each defending beacon's reach (each kept, at the place it was
-- found, while an enemy unit stays within DEFEND_CLEAR of it, and DEFEND_QUIET seconds after). Active ones rank above
-- warnings.
local MOBILE = {"unit", "spider-unit", "character", "car", "spider-vehicle", "spider-leg", "corpse", "character-corpse",
  "item-entity"}
local function enemies_of(f)
  local out = {}
  for _, name in ipairs(shared.hostile_forces()) do
    local g = game.forces[name]
    if g and f.is_enemy(g) then out[#out + 1] = name end
  end
  return out
end
local function alarms(defending)
  local out, tick = {}, game.tick
  local by_force = {}
  for _, d in ipairs(defending) do
    local f = d.beacon.force
    by_force[f.name] = by_force[f.name] or {force = f, beacons = {}}
    table.insert(by_force[f.name].beacons, d)
  end
  storage.cmd.hits = storage.cmd.hits or {}
  for fname, g in pairs(by_force) do
    local list = {}
    out[fname] = list
    local foes = enemies_of(g.force)
    -- Strike forces.
    for key, k in pairs((storage.director or {}).strikes or {}) do
      local b = storage.bases and storage.bases[k.base]
      local surface = b and b.lander and b.lander.valid and b.lander.surface
      if k.owner == fname and surface and not k.broken then
        if k.landed_at then
          local best, bd
          for _, u in ipairs(k.units or {}) do
            if u.valid then
              local d = (u.position.x - k.target[1]) ^ 2 + (u.position.y - k.target[2]) ^ 2
              if not bd or d < bd then best, bd = u, d end
            end
          end
          if best then
            list[#list + 1] = {key = "s" .. key, pos = {x = best.position.x, y = best.position.y}, surface = surface, rank = 2}
          end
        elseif k.seen and k.land then
          list[#list + 1] = {key = "s" .. key, pos = {x = k.land[1], y = k.land[2]}, surface = surface, rank = 1}
        elseif k.advertised or k.intercepted then
          list[#list + 1] = {key = "s" .. key, pos = {x = k.target[1], y = k.target[2]}, surface = surface, rank = 1}
        end
      end
    end
    -- Attacks on its buildings.
    local hits = storage.cmd.hits[fname] or {}
    storage.cmd.hits[fname] = hits
    if #foes > 0 then
      for _, d in ipairs(g.beacons) do
        local s = d.beacon.surface
        for _, e in ipairs(s.find_entities_filtered{position = d.plan.pos, radius = DEFEND_REACH, force = foes,
          type = {"unit", "spider-unit"}}) do
          local known
          for _, h in pairs(hits) do
            if h.surface == s.index and (h.pos.x - e.position.x) ^ 2 + (h.pos.y - e.position.y) ^ 2 <= DEFEND_CLEAR * DEFEND_CLEAR then
              known = h; break
            end
          end
          if not known then
            local near = s.count_entities_filtered{position = e.position, radius = DEFEND_NEAR, force = g.force}
            local moving = s.count_entities_filtered{position = e.position, radius = DEFEND_NEAR, force = g.force, type = MOBILE}
            if near > moving then
              storage.cmd.hit_n = (storage.cmd.hit_n or 0) + 1
              hits[storage.cmd.hit_n] = {pos = {x = e.position.x, y = e.position.y}, surface = s.index, last = tick}
            end
          end
        end
      end
    end
    for n, h in pairs(hits) do
      local s = game.surfaces[h.surface]
      if s and #foes > 0 and s.count_entities_filtered{position = h.pos, radius = DEFEND_CLEAR, force = foes,
        type = {"unit", "spider-unit"}, limit = 1} > 0 then
        h.last = tick
      end
      if not s or tick - h.last > DEFEND_QUIET * 60 then
        hits[n] = nil
      else
        list[#list + 1] = {key = "h" .. n, pos = h.pos, surface = s, rank = 2}
      end
    end
  end
  return out
end

-- A defending beacon's answer: of its force's alarms on its surface within DEFEND_REACH of its rally point, an active one
-- before a warning, the nearest first; the one it is answering kept while it lasts, unless one of a higher rank comes.
-- (Re-chosen each pass, a landed strike force's place (its moving front) and the attacks at buildings round it took
-- turns as the nearest: nine answers in one fight, each a new order, and the squad, stopping to re-path, lost all 12
-- without breaking it; armydefend, 2026-11-16.)
local function answer(d, list, was)
  local best, br, bd
  local keep
  for _, a in ipairs(list or {}) do
    if was and a.key == was.key and a.surface == d.beacon.surface
      and (a.pos.x - d.plan.pos.x) ^ 2 + (a.pos.y - d.plan.pos.y) ^ 2 <= DEFEND_REACH * DEFEND_REACH then keep = a end
  end
  for _, a in ipairs(list or {}) do
    if a.surface == d.beacon.surface then
      local dd = (a.pos.x - d.plan.pos.x) ^ 2 + (a.pos.y - d.plan.pos.y) ^ 2
      if dd <= DEFEND_REACH * DEFEND_REACH and (not best or a.rank > br or (a.rank == br and dd < bd)) then
        best, br, bd = a, a.rank, dd
      end
    end
  end
  if keep and best and best.rank <= keep.rank then return keep end
  return best
end

local function lead()
  local objectives = {}
  local plans = {}
  local squads = {}
  for _, t in pairs(storage.cmd.troopers) do
    if t.unit.valid and t.beacon then squads[t.beacon] = (squads[t.beacon] or 0) + 1 end
  end
  local defending = {}
  for k, b in pairs(storage.cmd.beacons) do
    if b.valid then
      plans[k] = plan(b)
      if plans[k].stance == "defend" then defending[#defending + 1] = {beacon = b, plan = plans[k], k = k} end
    else
      storage.cmd.beacons[k] = nil
    end
  end
  storage.cmd.answering = storage.cmd.answering or {}
  if #defending > 0 then
    local by_force = alarms(defending)
    for _, d in ipairs(defending) do
      local was = storage.cmd.answering[d.k]
      local a = answer(d, by_force[d.beacon.force.name], was)
      d.plan.alarm = a
      -- (Counted once an answer: a squad sent, for the record and tests.)
      if a and not (was and was.key == a.key) then storage.cmd.defend_sent = (storage.cmd.defend_sent or 0) + 1 end
      storage.cmd.answering[d.k] = a and {key = a.key, pos = a.pos} or nil
    end
  end
  for k in pairs(storage.cmd.answering) do
    if not (plans[k] and plans[k].alarm) then storage.cmd.answering[k] = nil end
  end
  for k, b in pairs(storage.cmd.beacons) do
    mark(k, b, plans[k])
    report(b, plans[k], squads[k] or 0)
  end
  for k, m in pairs(storage.cmd.marks or {}) do
    if not plans[k] then m.ring.destroy(); m.line.destroy(); storage.cmd.marks[k] = nil end
  end
  local offline = offline_set()
  for k, t in pairs(storage.cmd.troopers) do
    local u = t.unit
    if not u.valid then
      storage.cmd.troopers[k] = nil
    elseif t.manual and t.manual.kind == "retire" then
      -- (Before offline: retiring is how a player over the cap frees it.)
      t.offline = nil
      manual(t)
    elseif offline[k] then
      if not t.offline then
        t.offline = true
        u.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.by_damage}
        t.key = "offline"
      end
    elseif t.manual then
      t.offline = nil
      manual(t)
      open_near(u)
    else
      t.offline = nil
      open_near(u)
      local beacon = t.beacon and storage.cmd.beacons[t.beacon]
      if not (beacon and beacon.valid) then
        beacon = nearest(storage.cmd.beacons, u.position, u.force, ASSIGN_RANGE)
        t.beacon = beacon and beacon.unit_number
      end
      local p = beacon and plans[beacon.unit_number]
      local st = p and p.stance
      -- (Defending, out: fights within reach of the attack, not of home.)
      local foe = p and st ~= "retreat" and threat(u, p.alarm and {pos = p.alarm.pos} or p)
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
        if st == "hold" or (st == "defend" and not p.alarm) then
          hold()
        elseif st == "defend" then
          -- Out to the attack, fighting on the way; there, staying round it while anything is left (the alarm keeps
          -- its place, so the order stands till it is over).
          order(t, {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = {
            {type = defines.command.go_to_location, destination = p.alarm.pos, radius = 4,
              distraction = defines.distraction.by_enemy},
            {type = defines.command.wander, radius = 10, distraction = defines.distraction.by_enemy}}},
            "defend:" .. p.alarm.key)
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

command.rings = rings

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

-- A move's formation (2026-11-12, with the selection's cards: every unit had the one point, radius 3, then wandered 5
-- round it, so thirty of them stood in a heap): a slot each on a square grid round the point, spaced by the largest
-- unit's size, filled from the middle out, and each unit given the free slot nearest where it stands in the group (its
-- place relative to the group's middle, moved to the point), so the group keeps its shape and nobody crosses it.
local function formation(units, pos)
  local n = #units
  if n == 0 then return {} end
  local cx, cy, size = 0, 0, 1
  for _, u in ipairs(units) do
    cx, cy = cx + u.position.x, cy + u.position.y
    local sb = u.prototype.selection_box
    size = math.max(size, (sb.right_bottom.x or sb.right_bottom[1]) - (sb.left_top.x or sb.left_top[1]))
  end
  cx, cy = cx / n, cy / n
  local gap = size + 0.6
  local side = math.ceil(math.sqrt(n))
  local slots = {}
  for i = 0, side - 1 do
    for j = 0, side - 1 do
      slots[#slots + 1] = {x = pos.x + (i - (side - 1) / 2) * gap, y = pos.y + (j - (side - 1) / 2) * gap}
    end
  end
  table.sort(slots, function(a, b)
    local da, db = (a.x - pos.x) ^ 2 + (a.y - pos.y) ^ 2, (b.x - pos.x) ^ 2 + (b.y - pos.y) ^ 2
    if da ~= db then return da < db end
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end)
  local out, taken = {}, {}
  -- (Units nearest the group's middle first: the middle slots go to the middle units.)
  local order_ = {}
  for i, u in ipairs(units) do order_[i] = {u = u, d = (u.position.x - cx) ^ 2 + (u.position.y - cy) ^ 2} end
  table.sort(order_, function(a, b) if a.d ~= b.d then return a.d < b.d end return a.u.unit_number < b.u.unit_number end)
  for _, o in ipairs(order_) do
    local u = o.u
    local wx, wy = pos.x + (u.position.x - cx), pos.y + (u.position.y - cy)
    local best, bd
    for k = 1, n do
      if not taken[k] then
        local d = (slots[k].x - wx) ^ 2 + (slots[k].y - wy) ^ 2
        if not bd or d < bd then best, bd = k, d end
      end
    end
    taken[best] = true
    out[u.unit_number] = slots[best]
  end
  return out
end
command.formation = formation

-- An order for the selection: on a faction entity, attack it; elsewhere, move (or attack-move) to the middle
-- of the area clicked or dragged, each to its slot of a formation.
function command.order(player_index, surface, area, attackmove)
  storage.cmd.selected = storage.cmd.selected or {}
  local sel = storage.cmd.selected[player_index] or {}
  local lt, rb = area.left_top or area[1], area.right_bottom or area[2]
  local pos = {x = ((lt.x or lt[1]) + (rb.x or rb[1])) / 2, y = ((lt.y or lt[2]) + (rb.y or rb[2])) / 2}
  local target = surface.find_entities_filtered{area = {{pos.x - 1.5, pos.y - 1.5}, {pos.x + 1.5, pos.y + 1.5}},
    force = shared.hostile_forces(), type = {"unit", "spider-unit", "electric-turret", "ammo-turret", "artillery-turret", "container",
      "electric-energy-interface", "radar", "assembling-machine", "mining-drill", "generator", "unit-spawner", "turret"},
    limit = 1}[1]   -- (unit-spawner and turret: Synthexis's incubators and its worms, 0.2.437)
  storage.cmd.seq = (storage.cmd.seq or 0) + 1
  local n = 0
  local units = {}
  for un in pairs(sel) do
    local t = storage.cmd.troopers[un]
    if t and t.unit.valid then units[#units + 1] = t.unit end
  end
  table.sort(units, function(a, b) return a.unit_number < b.unit_number end)
  local slots = target and {} or formation(units, pos)
  for un in pairs(sel) do
    local t = storage.cmd.troopers[un]
    if t and t.unit.valid then
      local at = slots[un] or pos
      t.manual = {kind = target and "attack" or (attackmove and "attackmove" or "move"), pos = {x = at.x, y = at.y},
        target = target, seq = storage.cmd.seq, slotted = slots[un] ~= nil}
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

-- The map round the army (the user, 2026-11-09: "are player units giving map view to the player? I think they should to
-- allow far ops"; they do not, read in a game with /lp chartcheck): every CHART_EVERY ticks, the chunks the player's units
-- stand in, and SIGHT chunks round each, charted for their force, but for those a radar already shows. One chart call a
-- chunk the army stands in, not a unit.
local CHART_EVERY = 60
local SIGHT = 1
-- A chunk charted by script stays in sight 600 ticks after the chart lands (measured in a game window, 2026-11-17), so
-- the army's chunks are charted again before that, each on its own. Charted only when its unit's own chunk was out of
-- sight, a ring stood unrefreshed while its unit walked into a chunk a neighbour's chart still lit, and went dark round a
-- fight in patches (the user, playtest: "lots of blind fighting interrupting visible fighting").
local CHART_REFRESH = 360
local function chart_army()
  local want, stood = {}, {}
  for _, t in pairs(storage.cmd.troopers) do
    local u = t.unit
    local s, p = u.valid and u.surface, u.valid and u.position
    local cx, cy = p and math.floor(p.x / 32), p and math.floor(p.y / 32)
    local here = p and (u.force.index .. ":" .. s.index .. ":" .. cx .. ":" .. cy)
    if here and not stood[here] then
      stood[here] = true
      for dx = -SIGHT, SIGHT do
        for dy = -SIGHT, SIGHT do
          local key = u.force.index .. ":" .. s.index .. ":" .. (cx + dx) .. ":" .. (cy + dy)
          if not want[key] then want[key] = {s = s, f = u.force, x = cx + dx, y = cy + dy} end
        end
      end
    end
  end
  local tick = game.tick
  local at = storage.cmd.chart_at or {}
  local keep = {}
  for key, c in pairs(want) do
    local last = at[key]
    if not c.f.is_chunk_visible(c.s, {c.x, c.y}) or (last and tick - last >= CHART_REFRESH) then
      c.f.chart(c.s, {{c.x * 32, c.y * 32}, {c.x * 32 + 32, c.y * 32 + 32}})
      storage.cmd.charted = (storage.cmd.charted or 0) + 1
      last = tick
    end
    keep[key] = last
  end
  -- (A chunk left behind keeps its record while it may still be in sight: wanted again then, it is refreshed in time.)
  for key, last in pairs(at) do
    if not keep[key] and tick - last < 600 then keep[key] = last end
  end
  storage.cmd.chart_at = keep
end

-- Retiring (the user, 2026-11-10: "How do you retire units?", there was no way): the selection walks to the nearest
-- barracks of its force on its surface and there hands in its order, laid beside it and marked for deconstruction (robots
-- carry it to storage; a muster point or a barracks' output deploys it again later), its bandwidth freed. Not into the
-- barracks' output: the barracks deploys what it holds there, and the order was back on the field a second later. With
-- no barracks, it hands in its order where it stands.
local ORDER_OF = {}
for item, name in pairs(shared.ORDERS) do ORDER_OF[name] = item end
local RETIRE_AT = 6

local function home_for(u)
  local best, bd
  for k, b in pairs(storage.cmd.barracks) do
    if not b.valid then
      storage.cmd.barracks[k] = nil
    elseif b.force == u.force and b.surface == u.surface then
      local d = (b.position.x - u.position.x) ^ 2 + (b.position.y - u.position.y) ^ 2
      if not bd or d < bd then best, bd = b, d end
    end
  end
  return best
end

local function unit_to_order(k, t, at)
  local u = t.unit
  local item = ORDER_OF[u.name]
  if item then
    u.surface.spill_item_stack{position = at and at.valid and {at.position.x, at.position.y + 2.5} or u.position,
      stack = {name = item, count = 1, quality = u.quality.name}, force = u.force, allow_belts = false}
  end
  storage.cmd.troopers[k] = nil
  for _, sel in pairs(storage.cmd.selected or {}) do sel[k] = nil end
  u.destroy()
  storage.cmd.retired = (storage.cmd.retired or 0) + 1
end

function command.retire(player_index)
  storage.cmd.selected = storage.cmd.selected or {}
  local sel = storage.cmd.selected[player_index] or {}
  storage.cmd.seq = (storage.cmd.seq or 0) + 1
  local n = 0
  for k in pairs(sel) do
    local t = storage.cmd.troopers[k]
    if t and t.unit.valid then
      local home = home_for(t.unit)
      if home then
        t.manual, t.key = {kind = "retire", target = home, seq = storage.cmd.seq}, nil
        manual(t)
      else
        unit_to_order(k, t, nil)
      end
      n = n + 1
    end
  end
  storage.cmd.selected[player_index] = {}
  rings(player_index)
  return n
end

local function retire_step()
  for k, t in pairs(storage.cmd.troopers) do
    local m = t.manual
    if m and m.kind == "retire" and t.unit.valid then
      if not (m.target and m.target.valid) then
        m.target = home_for(t.unit)
        if m.target then t.key = nil; manual(t) end
      end
      local h = m.target
      if not h then
        unit_to_order(k, t, nil)
      elseif (h.position.x - t.unit.position.x) ^ 2 + (h.position.y - t.unit.position.y) ^ 2 <= RETIRE_AT * RETIRE_AT then
        unit_to_order(k, t, h)
      end
    end
  end
end

-- Squad sizes kept (see squad_room): above a beacon's cap for a unit, the surplus, farthest from its rally point first,
-- joins the nearest other beacon in reach with room for it; with none, it walks to the nearest barracks and hands in its
-- orders, as a retired unit does. (Moving first since 2026-11-16, with the defend stance: a squad was whoever had deployed
-- nearest, and sizes the only lever, so lowering one beacon's tanks and raising another's moves them; it retired them.)
local function enforce()
  local squads = squad_counts()
  local units = {}
  for k, t in pairs(storage.cmd.troopers) do
    if t.beacon and t.unit.valid and not (t.manual and t.manual.kind == "retire") then
      units[t.beacon] = units[t.beacon] or {}
      local list = units[t.beacon][t.unit.name] or {}
      list[#list + 1] = {k = k, t = t}
      units[t.beacon][t.unit.name] = list
    end
  end
  for id, by in pairs(units) do
    local b = storage.cmd.beacons[id]
    local cap = b and b.valid and caps(b)
    if cap then
      local rally = plan(b).pos
      for name, list in pairs(by) do
        local c = cap[name]
        if c and #list > c then
          table.sort(list, function(x, y)
            local px, py = x.t.unit.position, y.t.unit.position
            return (px.x - rally.x) ^ 2 + (px.y - rally.y) ^ 2 > (py.x - rally.x) ^ 2 + (py.y - rally.y) ^ 2
          end)
          storage.cmd.seq = (storage.cmd.seq or 0) + 1
          for i = 1, #list - c do
            local e = list[i]
            local other = squad_room(e.t.unit.position, e.t.unit.force, name, squads)
            local home = not other and home_for(e.t.unit)
            if other then
              local from, to = squads.count[id] or {}, squads.count[other.unit_number] or {}
              from[name] = math.max(0, (from[name] or 1) - 1)
              to[name] = (to[name] or 0) + 1
              squads.count[id], squads.count[other.unit_number] = from, to
              e.t.beacon, e.t.key = other.unit_number, nil
              storage.cmd.moved = (storage.cmd.moved or 0) + 1
            elseif home then
              e.t.manual, e.t.key = {kind = "retire", target = home, seq = storage.cmd.seq}, nil
              manual(e.t)
            else
              unit_to_order(e.k, e.t, nil)
            end
            if not other then storage.cmd.auto_retired = (storage.cmd.auto_retired or 0) + 1 end
          end
        end
      end
    end
  end
end

-- The cap shown (the user, 2026-11-10: "Where is the unit cap displayed?", nowhere): a small panel at the top of the screen
-- for each player whose force has the army (command bandwidth 1), its units against the cap, the offline, and a button to
-- retire the selection.
local function waiting(force)
  local n = 0
  for _, b in pairs(storage.cmd.barracks) do
    if b.valid and b.force == force then
      local inv = b.get_inventory(defines.inventory.crafter_output)
      for item in pairs(shared.ORDERS) do n = n + (inv and inv.get_item_count(item) or 0) end
    end
  end
  return n
end

-- The readout's numbers (a function: the panel's, and scenario retire's, headless with no player to show it to).
function command.readout(f)
  local working, allowed, level = relays(f)
  local off = 0
  for _, t in pairs(storage.cmd.troopers) do if t.unit.valid and t.unit.force == f and t.offline then off = off + 1 end end
  return {units = population(f), cap = math.min(working, allowed) * shared.RELAY_CAPACITY, offline = off, working = working,
    allowed = allowed, level = level, waiting = waiting(f)}
end

function command.gui_tick()
  for _, p in pairs(game.connected_players) do
    local f = p.force
    local frame = p.gui.top.lp_army
    local r = command.readout(f)
    if r.level < 1 then
      if frame then frame.destroy() end
    else
      if not frame then
        frame = p.gui.top.add{type = "frame", name = "lp_army", direction = "horizontal", style = "slot_window_frame"}
        frame.style.padding = 4
        frame.add{type = "label", name = "lp_army_units", style = "caption_label"}
        frame.add{type = "button", name = "lp_army_retire", style = "tool_button"}
        -- (Selecting the army without a drag: scripts/cards.lua's select_army, 2026-11-12.)
        local all = frame.add{type = "button", name = "lp_army_all", style = "tool_button", caption = {"lp.army-all"},
          tooltip = {"lp.army-all-tooltip"}}
        all.style.width = 60
        local idle = frame.add{type = "button", name = "lp_army_idle", style = "tool_button", caption = {"lp.army-idle"},
          tooltip = {"lp.army-idle-tooltip"}}
        idle.style.width = 60
      end
      local units = frame.lp_army_units
      units.caption = r.offline > 0 and {"lp.army-units-offline", r.units, r.cap, r.offline} or {"lp.army-units", r.units, r.cap}
      units.tooltip = {"lp.army-tooltip", r.working, r.allowed, r.allowed * shared.RELAY_CAPACITY, r.waiting}
      local sel = 0
      for k in pairs((storage.cmd.selected or {})[p.index] or {}) do if storage.cmd.troopers[k] then sel = sel + 1 end end
      local b = frame.lp_army_retire
      b.caption = {"lp.army-retire", sel}
      b.tooltip = {"lp.army-retire-tooltip"}
      b.enabled = sel > 0
      b.style.width = 110
    end
  end
end

function command.tick(tick)
  if tick % 30 == 15 then retire_step() end
  if tick % 120 == 75 then enforce() end
  if tick % 60 == 20 then command.gui_tick() end
  if tick % 60 == 0 then train(); repair() end
  if tick % 120 == 30 then lead() end
  if tick % 10 == 5 then routes_tick() end
  if tick % CHART_EVERY == 45 then chart_army() end
end

-- For the squad panel and the hover links (scripts/squadgui.lua): a beacon's stance, what it answers, its units by name
-- and its sizes.
function command.beacon_view(beacon)
  local p = plan(beacon)
  local count, units = {}, {}
  for _, t in pairs(storage.cmd.troopers) do
    if t.beacon == beacon.unit_number and t.unit.valid and not (t.manual and t.manual.kind == "retire") then
      count[t.unit.name] = (count[t.unit.name] or 0) + 1
      units[#units + 1] = t.unit
    end
  end
  return {stance = p.stance, pos = p.pos, answering = (storage.cmd.answering or {})[beacon.unit_number], count = count,
    units = units, caps = caps(beacon) or {}}
end
function command.beacon_of(u)
  local t = storage.cmd.troopers[u.unit_number]
  local b = t and t.beacon and storage.cmd.beacons[t.beacon]
  return b and b.valid and b or nil
end

-- A unit of the player's made by script, enlisted as if trained (/lp chartcheck).
function command.enlist(u)
  storage.cmd.troopers[u.unit_number] = {unit = u}
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
  local hints = {}
  for k, t in pairs(storage.cmd.hints or {}) do hints[k] = t end
  return {trained = storage.cmd.trained or 0, retired = storage.cmd.retired or 0, auto_retired = storage.cmd.auto_retired or 0,
    moved = storage.cmd.moved or 0, defend_sent = storage.cmd.defend_sent or 0,
    route_searches = storage.cmd.route_searches or 0, kept_fighting = storage.cmd.kept_fighting or 0, routes_taken = storage.cmd.routes_taken or 0, hints = hints, alive = alive, offline = offline, capacity = command.capacity(f),
    level = research_level(f), orders = orders, locks = storage.cmd.locks, charted = storage.cmd.charted or 0}
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
