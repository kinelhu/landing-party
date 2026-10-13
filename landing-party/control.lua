local shared = require("shared")
local base = require("scripts.base")
local site = require("scripts.site")
local faction = require("scripts.faction")
local command = require("scripts.command")


local function init()
  storage.bases = storage.bases or {}
  storage.next_id = storage.next_id or 1
  storage.owner = storage.owner or {}
  storage.unit_owner = storage.unit_owner or {}
  if storage.trace == nil then storage.trace = false end
  if not game.forces[shared.FORCE] then game.create_force(shared.FORCE) end
  command.init()
end

script.on_init(init)
script.on_configuration_changed(init)

script.on_event(defines.events.on_tick, function(e) base.tick(e.tick); faction.tick(e.tick); command.tick(e.tick) end)

local PLAYER_BUILT = {{filter = "name", name = "lp-barracks"}, {filter = "name", name = "lp-rally-beacon"},
  {filter = "name", name = "lp-command-relay"}}
for _, ev in ipairs({defines.events.on_built_entity, defines.events.on_robot_built_entity,
  defines.events.script_raised_built}) do
  script.on_event(ev, command.on_built, PLAYER_BUILT)
end

-- Damage to the faction's buildings calls a response (filtered to them; army.alarm throttles).
local BUILDINGS = {}
for _, n in ipairs({"lp-lander", "lp-generator", "lp-pylon", "lp-drill", "lp-bin", "lp-fabricator", "lp-turret",
  "lp-wall", "lp-radar", "lp-depot", "lp-launchpad", "lp-lamp"}) do
  table.insert(BUILDINGS, {filter = "name", name = n})
end
script.on_event(defines.events.on_entity_damaged, function(e)
  if e.force and e.force.name ~= shared.FORCE then base.on_damaged(e.entity) end
end, BUILDINGS)

-- Deaths: the faction's buildings are queued for rebuild, its units counted lost, and what its units
-- destroy is counted razed (attributed through the unit that did it).
script.on_event(defines.events.on_entity_died, function(e)
  local ent = e.entity
  if ent.name == "lp-uplink" then faction.uplink_lost(ent) end
  -- Command cores from the wreckage: a depot gives one, a lander three (captured outposts: base.lua).
  if ent.name == "lp-depot" then command.drop_cores(ent.surface, ent.position, 1) end
  if ent.name == "lp-lander" then command.drop_cores(ent.surface, ent.position, 3) end
  if ent.force.name == shared.FORCE then
    local id = storage.unit_owner[ent.unit_number]
    if id then
      storage.unit_owner[ent.unit_number] = nil
      local b = storage.bases[id]
      if b then b.units_lost = b.units_lost + 1 end
    else
      base.on_died(ent)
    end
  elseif e.force and e.force.name == shared.FORCE and e.cause and e.cause.valid
    and ent.force.name ~= "neutral" and ent.force.name ~= "enemy" then
    -- Razed counts the player's structures only (trees felled by shells once inflated it by half).
    local id = storage.unit_owner[e.cause.unit_number]
    local b = id and storage.bases[id]
    if b then b.razed = b.razed + 1 end
  end
end)

local function land(surface, pos, opts)
  return base.land(surface, pos, opts)
end

-- The arrival: the first rocket launch is heard; later launches hasten the next landing.
script.on_event(defines.events.on_rocket_launched, function(e)
  local silo = e.rocket_silo
  if silo and silo.valid then faction.on_launch(silo) end
end)

commands.add_command("lp-land", {"lp.command-land"}, function(cmd)
  local player = game.get_player(cmd.player_index)
  if not player then return end
  local d = tonumber(cmd.parameter) or 60
  local b = land(player.surface, {player.position.x + d, player.position.y})
  if b then faction.state() end
end)

commands.add_command("lp-trace", {"lp.command-trace"}, function(cmd)
  storage.trace = not storage.trace
  game.print("landing-party trace: " .. tostring(storage.trace))
end)

-- Snapshot of a base for the sim plots: its entities, the ore around it, and its stats, as one JSON line.
local function snapshot(id, file, radius)
  local b = storage.bases[id]
  if not b then return end
  local surface = game.surfaces[b.surface]
  local ax, ay = b.origin.x, b.origin.y
  local area = {{ax - radius, ay - radius}, {ax + radius, ay + radius}}
  local ents = {}
  for _, e in pairs(surface.find_entities_filtered{area = area, force = shared.FORCE}) do
    table.insert(ents, {e.name, e.position.x, e.position.y, e.electric_network_id or 0, e.status or 0})
  end
  local ore = {}
  for _, r in pairs(surface.find_entities_filtered{area = area, type = "resource", name = site.ORES}) do
    table.insert(ore, {r.name, r.position.x, r.position.y, r.amount})
  end
  local roads = {}
  for _, t in pairs(surface.find_tiles_filtered{area = area, name = "lp-road"}) do
    table.insert(roads, {t.position.x, t.position.y})
  end
  local s = base.stats(b)
  s.entities, s.ore, s.roads, s.origin, s.log = ents, ore, roads, b.origin, b.log
  helpers.write_file(file, helpers.table_to_json(s) .. "\n", true)
end

remote.add_interface("landing-party", {
  land = function(surface_index, pos, opts)
    local b = land(game.surfaces[surface_index], pos, opts); return b and b.id end,
  -- As the real arrival does: a site `distance` from `from` with ore around it.
  arrive = function(surface_index, from, distance, opts)
    opts = opts or {}
    opts.distance = distance
    local b = faction.arrive(game.surfaces[surface_index], from, opts, true)
    return b and b.id
  end,
  faction = function() return faction.state() end,
  army = function() local st = command.stats(); st.cores_dropped = storage.cmd.cores_dropped or 0; return st end,
  -- Tests only: shorten the faction's clocks and thresholds.
  debug_export = function(id, parts) faction.export(storage.bases[id], parts) end,
  debug_tune = function(t)
    local f = faction.state()
    if t.cadence_minutes then f.cadence = t.cadence_minutes * 3600; if f.next then f.next = game.tick + f.cadence end end
    if t.tiers then f.tiers = t.tiers end
    if t.quiet ~= nil then storage.quiet = t.quiet end
    if t.mature_blocks then storage.mature_blocks = t.mature_blocks end
    if t.army_off ~= nil then storage.army_off = t.army_off end
    if t.raids_off ~= nil then storage.raids_off = t.raids_off end
  end,
  set_trace = function(on) storage.trace = on end,
  debug_modules = function(id, pos, r) return base.debug_modules(storage.bases[id], pos, r) end,
  -- Tests and showcases only: parts for a settlement (a young one has no surplus to export).
  debug_parts = function(id, parts) local b = storage.bases[id]; if b then b.parts = b.parts + parts end end,
  -- Tests only: a depot beside the lander and parts, so a raid comes in minutes instead of half an hour.
  debug_depot = function(id, parts)
    local b = storage.bases[id]
    local s = b.lander.surface
    local p = s.find_non_colliding_position("lp-depot", {b.lander.position.x, b.lander.position.y + 16}, 30, 1)
    local d = p and s.create_entity{name = "lp-depot", position = p, force = b.lander.force}
    if d then table.insert(b.depots, d) end
    b.parts = b.parts + (parts or 0)
    return d ~= nil
  end,
  snapshot = snapshot,
  stats = function(id) return storage.bases[id] and base.stats(storage.bases[id]) end,
})
