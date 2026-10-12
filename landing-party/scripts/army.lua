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
  prune(b.garrison)
  if #b.garrison >= cap(b) then return end
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
local RESPONSE_SIZE = 8
local RESPONSE_COOLDOWN = 60 * 60

function army.alarm(b, pos, trace)
  if game.tick < (b.next_response or 0) then return end
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
  local group = home.surface.create_unit_group{position = home.position, force = home.force}
  local members = {}
  local dest = {pos.x, pos.y}
  local cmd = {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = {
    {type = defines.command.go_to_location, destination = dest, radius = 16, distraction = defines.distraction.by_enemy},
    {type = defines.command.attack_area, destination = dest, radius = 30, distraction = defines.distraction.by_anything},
  }}
  for i = #b.garrison, HOME_GUARD + 1, -1 do
    if #members >= RESPONSE_SIZE then break end
    local u = table.remove(b.garrison, i)
    if u.type == "unit" then group.add_member(u) else u.commandable.set_command(cmd) end
    table.insert(members, u)
  end
  group.set_command(cmd)
  table.insert(b.raids, {group = group, members = members, target = dest, started = game.tick, home = home,
    kind = "response"})
  b.responses = (b.responses or 0) + 1
  trace(b, string.format("response %d: %d units to %.0f,%.0f", b.responses, #members, pos.x, pos.y))
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

function army.tick(b, tick, trace)
  if tick % 300 == 0 then settle(b, trace); launch(b, trace) end
  if tick % BUILD_TICKS == 0 then produce(b, trace) end
end

army.UNITS = {"lp-infantry", "lp-tank", "lp-walker", "lp-harrier"}

return army
