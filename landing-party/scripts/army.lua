-- The army: depots build units from parts up to a garrison cap, in the mix the doctrine prefers; a full
-- enough garrison raids the nearest player structure, and the survivors come home.
local shared = require("__landing-party__.shared")
local rng = require("__landing-party__.scripts.rng")

local army = {}

local BUILD_TICKS = 600          -- a depot turns out at most one unit per 10 s
local CAP_PER_DEPOT = 10
local RAID_SHARE = 0.7           -- a raid leaves when the garrison is this full
local HOME_GUARD = 2             -- units that stay home
local RAID_RANGE = 400           -- how far a settlement looks for a target
local RAID_COOLDOWN = 5 * 3600
local TARGET_TYPES = {"ammo-turret", "electric-turret", "fluid-turret", "artillery-turret", "wall", "gate",
  "assembling-machine", "furnace", "mining-drill", "electric-pole", "container", "logistic-container", "lab",
  "radar", "solar-panel", "accumulator", "generator", "boiler", "roboport", "inserter", "transport-belt",
  "rocket-silo", "reactor", "pipe", "storage-tank", "pumpjack", "oil-refinery", "chemical-plant", "lamp"}

army.MIX = {
  bastion = {["lp-infantry"] = 5, ["lp-tank"] = 3, ["lp-walker"] = 1, ["lp-harrier"] = 1},
  sprawl = {["lp-infantry"] = 3, ["lp-tank"] = 1, ["lp-walker"] = 1, ["lp-harrier"] = 4},
  picket = {["lp-infantry"] = 4, ["lp-tank"] = 2, ["lp-walker"] = 2, ["lp-harrier"] = 2},
  fortress = {["lp-infantry"] = 3, ["lp-tank"] = 2, ["lp-walker"] = 3, ["lp-harrier"] = 2},
}

local function prune(list)
  local j = 0
  for i = 1, #list do
    if list[i].valid then j = j + 1; list[j] = list[i] end
  end
  for i = #list, j + 1, -1 do list[i] = nil end
end

function army.init(b)
  b.garrison = b.garrison or {}
  b.raids = b.raids or {}
  b.units_built, b.units_lost, b.razed, b.raids_sent = b.units_built or 0, b.units_lost or 0, b.razed or 0,
    b.raids_sent or 0
  b.next_raid = b.next_raid or 0
end

local GARRISON_PER_TIER = 5     -- per depot
local function tier() return storage.faction and storage.faction.tier or 0 end
local function cap(b) return #b.depots * (CAP_PER_DEPOT + GARRISON_PER_TIER * tier()) end
local function strength(b) return #b.garrison + #(b.patrol or {}) end

-- The doctrine's mix, restricted to what the faction's tier has unlocked.
local function mix(b)
  local out = {}
  for name, w in pairs(army.MIX[b.doctrine]) do
    if tier() >= (shared.UNLOCK[name] or 0) then out[name] = w end
  end
  return out
end

-- One unit from the first depot with room, if parts allow; the doctrine weighs which.
local function produce(b, trace)
  if storage.army_off then return end
  prune(b.garrison)
  if strength(b) >= cap(b) then return end
  local name = b.next_unit or rng.weighted(b.rng, mix(b))
  b.next_unit = name
  local cost = shared.units[name].cost
  if b.parts < cost then return end
  for _, depot in ipairs(b.depots) do
    if depot.valid then
      local surface = depot.surface
      local p = surface.find_non_colliding_position(name, {depot.position.x, depot.position.y + 4}, 12, 0.5)
      local u = p and surface.create_entity{name = name, position = p, force = depot.force}
      if u then
        b.parts = b.parts - cost
        b.next_unit = nil
        b.units_built = b.units_built + 1
        b.built_by = b.built_by or {}
        b.built_by[name] = (b.built_by[name] or 0) + 1
        table.insert(b.garrison, u)
        storage.unit_owner[u.unit_number] = b.id
        return u
      end
    end
  end
end

-- The nearest player structure within reach of the lander, of any force at war with the faction.
local function target(b)
  local f = b.lander.force
  local best, bd
  for _, other in pairs(game.forces) do
    if other ~= f and other.name ~= "enemy" and other.name ~= "neutral" and not f.get_cease_fire(other) then
      for _, e in pairs(b.lander.surface.find_entities_filtered{position = b.lander.position, radius = RAID_RANGE,
        force = other, type = TARGET_TYPES}) do
        local d = (e.position.x - b.lander.position.x) ^ 2 + (e.position.y - b.lander.position.y) ^ 2
        if not bd or d < bd then best, bd = e, d end
      end
    end
  end
  return best
end

local SEARCH_TICKS = 30 * 60      -- a wide area query: not every few seconds (it tripled the run's cost)
local IDLE_SEARCH_TICKS = 120 * 60

local function launch(b, trace)
  if storage.army_off then return end
  prune(b.garrison)
  if #b.depots == 0 or game.tick < b.next_raid or game.tick < (b.next_search or 0) then return end
  if #b.garrison < math.max(6, RAID_SHARE * cap(b)) then return end
  local t = target(b)
  b.next_search = game.tick + (t and SEARCH_TICKS or IDLE_SEARCH_TICKS)
  if not t then return end
  local home = b.depots[1]
  if not (home and home.valid) then return end
  local surface = home.surface
  local group = surface.create_unit_group{position = home.position, force = home.force}
  local members = {}
  for i = #b.garrison, HOME_GUARD + 1, -1 do
    local u = table.remove(b.garrison, i)
    -- Spider-units do not join unit groups: they get the same orders on their own.
    if u.type == "unit" then group.add_member(u) end
    table.insert(members, u)
  end
  local dest = {t.position.x, t.position.y}
  local cmd = {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = {
    {type = defines.command.go_to_location, destination = dest, radius = 20, distraction = defines.distraction.by_enemy},
    {type = defines.command.attack_area, destination = dest, radius = 24, distraction = defines.distraction.by_anything},
  }}
  group.set_command(cmd)
  for _, u in ipairs(members) do
    if u.type ~= "unit" then u.commandable.set_command(cmd) end
  end
  table.insert(b.raids, {group = group, members = members, target = dest, started = game.tick, home = home})
  b.raids_sent = b.raids_sent + 1
  b.next_raid = game.tick + RAID_COOLDOWN
  local mix = {}
  for _, u in ipairs(members) do mix[u.name] = (mix[u.name] or 0) + 1 end
  local parts = {}
  for _, name in ipairs(army.UNITS) do if mix[name] then table.insert(parts, mix[name] .. " " .. name:sub(4)) end end
  trace(b, string.format("raid %d: %s against %s at %.0f,%.0f", b.raids_sent, table.concat(parts, ", "), t.name,
    dest[1], dest[2]))
end

-- Response: a building hit within reach of a depot calls out a squad from the garrison (the home guard
-- stays), at most once a minute per settlement. It goes as a raid does and comes home the same way.
local RESPONSE_RANGE = 300
-- Sized to the threat: three units for each hostile turret, unit, vehicle or character near the alarm, at
-- least four. A fixed eight died to the last unit against two gun turrets (defend, seed 12345).
local RESPONSE_PER_THREAT = 6       -- three per turret still died to the last unit against upgraded turrets
local RESPONSE_MIN = 6
local THREAT_RADIUS = 30
local THREATS = {"ammo-turret", "electric-turret", "fluid-turret", "artillery-turret", "unit", "car", "spider-vehicle",
  "character"}

local function threat_count(surface, pos, f)
  local n = 0
  for _, other in pairs(game.forces) do
    if other ~= f and other.name ~= "neutral" and not f.get_cease_fire(other) then
      n = n + surface.count_entities_filtered{position = pos, radius = THREAT_RADIUS, force = other, type = THREATS}
    end
  end
  return n
end
local RESPONSE_COOLDOWN = 60 * 60

function army.alarm(b, pos, trace)
  if storage.army_off or game.tick < (b.next_response or 0) then return end
  prune(b.garrison)
  local home, hd
  for _, d in ipairs(b.depots) do
    if d.valid then
      local dist = math.sqrt((d.position.x - pos.x) ^ 2 + (d.position.y - pos.y) ^ 2)
      if dist <= RESPONSE_RANGE and (not hd or dist < hd) then home, hd = d, dist end
    end
  end
  if not home or #b.garrison <= HOME_GUARD then return end
  b.next_response = game.tick + RESPONSE_COOLDOWN
  local size = math.max(RESPONSE_MIN, RESPONSE_PER_THREAT * threat_count(home.surface, pos, home.force))
  local group = home.surface.create_unit_group{position = home.position, force = home.force}
  local members = {}
  local dest = {pos.x, pos.y}
  local cmd = {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = {
    {type = defines.command.go_to_location, destination = dest, radius = 16, distraction = defines.distraction.by_enemy},
    {type = defines.command.attack_area, destination = dest, radius = 30, distraction = defines.distraction.by_anything},
  }}
  for i = #b.garrison, HOME_GUARD + 1, -1 do
    if #members >= size then break end
    local u = table.remove(b.garrison, i)
    if u.type == "unit" then group.add_member(u) else u.commandable.set_command(cmd) end
    table.insert(members, u)
  end
  group.set_command(cmd)
  table.insert(b.raids, {group = group, members = members, target = dest, started = game.tick, home = home,
    kind = "response"})
  b.responses = (b.responses or 0) + 1
  trace(b, string.format("response %d: %d units (wanted %d) to %.0f,%.0f", b.responses, #members, size, pos.x, pos.y))
end

-- A raid is over when its group has finished or broken up, or after five minutes: survivors go home.
local function settle(b, trace)
  for i = #b.raids, 1, -1 do
    local r = b.raids[i]
    local done = game.tick - r.started > 5 * 3600 or not r.group.valid
      or r.group.state == defines.group_state.finished
    if done then
      local alive = 0
      for _, u in ipairs(r.members) do
        if u.valid then
          alive = alive + 1
          table.insert(b.garrison, u)
          if r.home.valid then
            u.commandable.set_command{type = defines.command.go_to_location, destination = r.home.position, radius = 8,
              distraction = defines.distraction.by_enemy}
          end
        end
      end
      if r.group.valid then r.group.destroy() end
      trace(b, string.format("%s over after %ds: %d of %d came back", r.kind or "raid", (game.tick - r.started) / 60,
        alive, #r.members))
      table.remove(b.raids, i)
    end
  end
end

-- Patrols: a few units taken from the garrison walk a loop through the settlement (pickets, compounds,
-- outposts), fighting what they meet. The settlement looks alive, and soft outposts are visited.
army.PATROL = {bastion = 2, sprawl = 4, picket = 3, fortress = 3}
local function waypoints(b)
  local pts = {}
  for _, m in ipairs(b.modules) do
    if m.built and not m.captured and (m.kind == "mining" or m.kind == "picket" or m.kind == "compound"
      or m.kind == "pad") then table.insert(pts, m.center) end
  end
  return pts
end

local function patrol(b, trace)
  b.patrol = b.patrol or {}
  prune(b.patrol)
  local want = army.PATROL[b.doctrine] or 2
  while #b.patrol < want and #b.garrison > HOME_GUARD do table.insert(b.patrol, table.remove(b.garrison)) end
  if #b.patrol == 0 then return end
  -- A route of up to five stops, drawn once and redrawn when the settlement changes much.
  local pts = waypoints(b)
  if #pts < 2 then return end
  if not b.route or b.route_n ~= #pts then
    local route, used = {}, {}
    for _ = 1, math.min(5, #pts) do
      local k
      repeat k = rng.int(b.rng, 1, #pts) until not used[k]
      used[k] = true
      table.insert(route, {pts[k][1], pts[k][2]})
    end
    b.route, b.route_n = route, #pts
    trace(b, string.format("patrol route of %d stops for %d units", #route, #b.patrol))
  end
  for i, u in ipairs(b.patrol) do
    if not u.commandable.has_command then
      local cmds = {}
      for k = 0, #b.route - 1 do
        local p = b.route[(i + k - 1) % #b.route + 1]
        table.insert(cmds, {type = defines.command.go_to_location, destination = p, radius = 6,
          distraction = defines.distraction.by_enemy})
      end
      u.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = cmds}
      b.patrol_legs = (b.patrol_legs or 0) + 1
    end
  end
end

-- Convoys: while the uplink stands, a mature settlement's exports travel to it as a hauler with up to two
-- escorts, in legs of about 100 tiles (long single paths are where the pathfinder gives up). Arrival exports
-- the cargo (army.on_deliver, set by base); a destroyed hauler loses it.
local CONVOY_LEG = 100
local CONVOY_ESCORT = 2

local function uplink_settlement()
  local f = storage.faction
  local id = f and f.uplink_landed
  local u = id and storage.bases[id]
  if u and u.uplink and u.uplink.valid then return u end
end

function army.convoy(b, cargo, trace)
  local dest = uplink_settlement()
  if not dest or dest == b then return false end
  local surface = b.lander.surface
  local home = (b.depots[1] and b.depots[1].valid and b.depots[1]) or b.lander
  local p = surface.find_non_colliding_position("lp-hauler", {home.position.x, home.position.y + 6}, 20, 0.5)
  local hauler = p and surface.create_entity{name = "lp-hauler", position = p, force = home.force}
  if not hauler then return false end
  local escorts = {}
  prune(b.garrison)
  for i = #b.garrison, HOME_GUARD + 1, -1 do
    if #escorts >= CONVOY_ESCORT then break end
    if b.garrison[i].type == "unit" then table.insert(escorts, table.remove(b.garrison, i)) end
  end
  -- Dock outside the fortress, on the side the convoy comes from: sent to the uplink in the inner yard,
  -- haulers circled the outer ring (seed 12345), the offset openings being no road for a vehicle.
  local target = {dest.uplink.position.x, dest.uplink.position.y}
  local fort = dest.blocks[1]
  if fort and fort.kind == "fortress" then
    local cx, cy = fort.center[1], fort.center[2]
    local dx, dy = home.position.x - cx, home.position.y - cy
    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
    local r = fort.w / 2 + 6
    target = {cx + dx / len * r, cy + dy / len * r}
  end
  local c = {hauler = hauler, escorts = escorts, cargo = cargo, dest = target, dest_id = dest.id, started = game.tick,
    last = {hauler.position.x, hauler.position.y}, home = home}
  b.convoys = b.convoys or {}
  table.insert(b.convoys, c)
  army.route_convoy(c)
  b.convoys_sent = (b.convoys_sent or 0) + 1
  trace(b, string.format("convoy %d: %d parts to the uplink at %.0f,%.0f, %d escorts", b.convoys_sent, cargo,
    target[1], target[2], #escorts))
  return true
end

function army.route_convoy(c)
  local from = c.hauler.position
  local dx, dy = c.dest[1] - from.x, c.dest[2] - from.y
  local len = math.sqrt(dx * dx + dy * dy)
  local legs = math.max(1, math.ceil(len / CONVOY_LEG))
  local cmds = {}
  for k = 1, legs do
    table.insert(cmds, {type = defines.command.go_to_location, destination = {from.x + dx * k / legs, from.y + dy * k / legs},
      radius = k == legs and 6 or 12, distraction = defines.distraction.none})
  end
  local cmd = {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = cmds}
  c.hauler.commandable.set_command(cmd)
  for _, e in ipairs(c.escorts) do
    if e.valid then
      local ecmds = {}
      for _, x in ipairs(cmds) do table.insert(ecmds, {type = x.type, destination = x.destination, radius = x.radius + 4,
        distraction = defines.distraction.by_enemy}) end
      e.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = ecmds}
    end
  end
end

local function travel(b, trace)
  for i = #(b.convoys or {}), 1, -1 do
    local c = b.convoys[i]
    local done
    if not c.hauler.valid then
      b.convoys_lost = (b.convoys_lost or 0) + 1
      b.cargo_lost = (b.cargo_lost or 0) + c.cargo
      trace(b, string.format("convoy lost with %d parts", c.cargo))
      done = true
    elseif (c.hauler.position.x - c.dest[1]) ^ 2 + (c.hauler.position.y - c.dest[2]) ^ 2 < 20 * 20 then
      if army.on_deliver then army.on_deliver(b, c.cargo) end
      b.convoys_delivered = (b.convoys_delivered or 0) + 1
      trace(b, string.format("convoy delivered %d parts after %ds", c.cargo, (game.tick - c.started) / 60))
      c.hauler.destroy()
      done = true
    else
      -- Stalled (no progress since the last look): fresh orders from where it stands.
      local p = c.hauler.position
      if (p.x - c.last[1]) ^ 2 + (p.y - c.last[2]) ^ 2 < 4 then army.route_convoy(c) end
      c.last = {p.x, p.y}
    end
    if done then
      for _, e in ipairs(c.escorts) do
        if e.valid then
          table.insert(b.garrison, e)
          if c.home.valid then
            e.commandable.set_command{type = defines.command.go_to_location, destination = c.home.position, radius = 8,
              distraction = defines.distraction.by_enemy}
          end
        end
      end
      table.remove(b.convoys, i)
    end
  end
end

-- Interceptors: trains of a hostile force passing within INTERCEPT_RANGE of a settlement draw up to
-- INTERCEPT_SIZE units from its garrison, harriers first, at the nearest carriage. They come home as a
-- raid does. Rail lines near their ground become a liability.
local INTERCEPT_RANGE = 150
local INTERCEPT_SIZE = 4
local INTERCEPT_COOLDOWN = 2 * 3600

local function intercept(b, trace)
  if storage.army_off or game.tick < (b.next_intercept or 0) or #b.depots == 0 then return end
  prune(b.garrison)
  if #b.garrison <= HOME_GUARD then return end
  local f = b.lander.force
  local lp = b.lander.position
  local best, bd
  for _, other in pairs(game.forces) do
    if other ~= f and other.name ~= "enemy" and other.name ~= "neutral" and not f.get_cease_fire(other) then
      for _, train in pairs(game.train_manager.get_trains{surface = b.lander.surface, force = other}) do
        for _, car in pairs(train.carriages) do
          local d = (car.position.x - lp.x) ^ 2 + (car.position.y - lp.y) ^ 2
          if d < INTERCEPT_RANGE ^ 2 and (not bd or d < bd) then best, bd = car, d end
        end
      end
    end
  end
  if not best then return end
  b.next_intercept = game.tick + INTERCEPT_COOLDOWN
  local members = {}
  table.sort(b.garrison, function(x, y)
    local hx, hy = x.name == "lp-harrier" and 0 or 1, y.name == "lp-harrier" and 0 or 1
    if hx ~= hy then return hx > hy end
    return x.unit_number < y.unit_number
  end)
  for i = #b.garrison, HOME_GUARD + 1, -1 do
    if #members >= INTERCEPT_SIZE then break end
    local u = table.remove(b.garrison, i)
    u.commandable.set_command{type = defines.command.attack, target = best, distraction = defines.distraction.by_enemy}
    table.insert(members, u)
  end
  local group = b.lander.surface.create_unit_group{position = b.lander.position, force = f}
  table.insert(b.raids, {group = group, members = members, target = {best.position.x, best.position.y},
    started = game.tick, home = b.depots[1], kind = "intercept"})
  b.intercepts = (b.intercepts or 0) + 1
  trace(b, string.format("intercept %d: %d units at a %s at %.0f,%.0f", b.intercepts, #members, best.name,
    best.position.x, best.position.y))
end

function army.tick(b, tick, trace)
  if tick % 600 == 300 then intercept(b, trace) end
  if tick % 600 == 450 then travel(b, trace) end
  if tick % 300 == 0 then settle(b, trace); launch(b, trace) end
  if tick % 300 == 150 and not storage.army_off then patrol(b, trace) end
  if tick % BUILD_TICKS == 0 then produce(b, trace) end
end

army.UNITS = {"lp-infantry", "lp-tank", "lp-walker", "lp-harrier"}

return army
