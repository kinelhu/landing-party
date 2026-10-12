local shared = require("shared")
local base = require("scripts.base")
local site = require("scripts.site")

local LANDING_DISTANCE = 350

local function init()
  storage.bases = storage.bases or {}
  storage.next_id = storage.next_id or 1
  storage.owner = storage.owner or {}
  storage.unit_owner = storage.unit_owner or {}
  if storage.trace == nil then storage.trace = false end
  if not game.forces[shared.FORCE] then game.create_force(shared.FORCE) end
end

script.on_init(init)
script.on_configuration_changed(init)

script.on_event(defines.events.on_tick, function(e) base.tick(e.tick) end)

-- Damage to the faction's buildings calls a response (filtered to them; army.alarm throttles).
local BUILDINGS = {}
for _, n in ipairs({"lp-lander", "lp-generator", "lp-pylon", "lp-drill", "lp-bin", "lp-fabricator", "lp-turret",
  "lp-wall", "lp-radar", "lp-depot"}) do table.insert(BUILDINGS, {filter = "name", name = n}) end
script.on_event(defines.events.on_entity_damaged, function(e)
  if e.force and e.force.name ~= shared.FORCE then base.on_damaged(e.entity) end
end, BUILDINGS)

-- Deaths: the faction's buildings are queued for rebuild, its units counted lost, and what its units
-- destroy is counted razed (attributed through the unit that did it).
script.on_event(defines.events.on_entity_died, function(e)
  local ent = e.entity
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

-- A landing site about `distance` from `from`: in the first of eight directions (seeded order) with a
-- rich enough patch within SITE_SEARCH tiles of the ring, the richest chunk of ore there. A single point
-- per direction found no ore at 300 tiles on most maps (seed 2: 7 of 8 directions empty).
local SITE_SEARCH = 120
local SITE_MIN_ORE = 300
local function landing_site(surface, from, distance)
  local start = surface.map_gen_settings.seed % 8
  local fallback, fallback_n = {from.x + distance, from.y}, -1
  for i = 0, 7 do
    local a = 2 * math.pi * ((start + i) % 8) / 8
    local p = {from.x + distance * math.cos(a), from.y + distance * math.sin(a)}
    surface.request_to_generate_chunks(p, math.ceil(SITE_SEARCH / 32) + 1)
    surface.force_generate_chunk_requests()
    local per = {}
    for _, r in pairs(surface.find_entities_filtered{position = p, radius = SITE_SEARCH, type = "resource",
      name = site.ORES}) do
      local k = math.floor(r.position.x / 32) .. ":" .. math.floor(r.position.y / 32)
      per[k] = (per[k] or 0) + 1
    end
    local best, bn = nil, 0
    for k, n in pairs(per) do
      if n > bn or (n == bn and best and k < best) then best, bn = k, n end
    end
    if best then
      local cx, cy = best:match("(-?%d+):(-?%d+)")
      local c = {tonumber(cx) * 32 + 16, tonumber(cy) * 32 + 16}
      local n = surface.count_entities_filtered{position = c, radius = 60, type = "resource", name = site.ORES}
      if storage.trace then
        helpers.write_file("landing-party/decisions.txt", string.format("site near %.0f,%.0f: richest chunk at %d,%d, %d ore tiles within 60\n",
          p[1], p[2], c[1], c[2], n), true)
      end
      -- Land beside the patch, not on it: a third of the way back towards the ring point.
      local spot = {c[1] + (p[1] - c[1]) / 3, c[2] + (p[2] - c[2]) / 3}
      if n > SITE_MIN_ORE then return spot end
      if n > fallback_n then fallback, fallback_n = spot, n end
    end
  end
  -- No direction rich enough: the best one seen (seed 2024 once landed blind on two drills' worth of ore).
  return fallback
end

local function land(surface, pos, announce, opts)
  local b = base.land(surface, pos, opts)
  if b and announce then
    for _, f in pairs(game.forces) do
      if #f.players > 0 then
        f.chart(surface, {{b.origin.x - 48, b.origin.y - 48}, {b.origin.x + 48, b.origin.y + 48}})
        f.print({"lp.landed", string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y, surface.name)})
      end
    end
  end
  return b
end

-- The arrival: the first rocket launch on a surface is heard.
script.on_event(defines.events.on_rocket_launched, function(e)
  local silo = e.rocket_silo
  if not (silo and silo.valid) then return end
  storage.heard = storage.heard or {}
  if storage.heard[silo.surface.index] then return end
  storage.heard[silo.surface.index] = true
  land(silo.surface, landing_site(silo.surface, silo.position, LANDING_DISTANCE), true)
end)

commands.add_command("lp-land", {"lp.command-land"}, function(cmd)
  local player = game.get_player(cmd.player_index)
  if not player then return end
  local d = tonumber(cmd.parameter) or 60
  land(player.surface, {player.position.x + d, player.position.y}, true)
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
    local b = land(game.surfaces[surface_index], pos, false, opts); return b and b.id end,
  -- As the real arrival does: a site `distance` from `from` with ore around it.
  arrive = function(surface_index, from, distance, opts)
    local surface = game.surfaces[surface_index]
    local b = land(surface, landing_site(surface, from, distance), false, opts)
    return b and b.id
  end,
  set_trace = function(on) storage.trace = on end,
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
