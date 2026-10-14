local shared = require("shared")
local base = require("scripts.base")
local site = require("scripts.site")
local faction = require("scripts.faction")
local command = require("scripts.command")
local phases = require("__landing-party__.scripts.phases")
local biters = require("__landing-party__.scripts.biters")
faction.on_trigger = phases.trigger
local ops = require("__landing-party__.scripts.ops")
local dev = require("__landing-party__.scripts.dev")


local function init()
  storage.bases = storage.bases or {}
  storage.next_id = storage.next_id or 1
  storage.owner = storage.owner or {}
  storage.unit_owner = storage.unit_owner or {}
  if storage.trace == nil then storage.trace = false end
  for _, c in pairs(shared.CORPS) do
    local f = game.forces[c.force] or game.create_force(c.force)
    f.custom_color = c.color
  end
  command.init()
end

script.on_init(init)
script.on_configuration_changed(init)

script.on_event(defines.events.on_tick, function(e)
  biters.tick(); base.tick(e.tick); faction.tick(e.tick); command.tick(e.tick); phases.tick(e.tick)
end)

local PLAYER_BUILT = {{filter = "name", name = "lp-barracks"}, {filter = "name", name = "lp-rally-beacon"},
  {filter = "name", name = "lp-command-relay"}}
for _, ev in ipairs({defines.events.on_built_entity, defines.events.on_robot_built_entity,
  defines.events.script_raised_built}) do
  script.on_event(ev, command.on_built, PLAYER_BUILT)
end

-- Damage to the faction's buildings calls a response (filtered to them; army.alarm throttles).
local BUILDINGS = {}
for _, n in ipairs(shared.variants({"lp-lander", "lp-generator", "lp-pylon", "lp-drill", "lp-bin", "lp-fabricator",
  "lp-turret", "lp-wall", "lp-radar", "lp-depot", "lp-launchpad", "lp-lamp"})) do
  table.insert(BUILDINGS, {filter = "name", name = n})
end
script.on_event(defines.events.on_entity_damaged, function(e)
  -- Any other force: a rival corporation's fire raises the alarm as the player's does.
  if e.force and e.force ~= e.entity.force then
    ops.provoke(e.entity.force.name, e.force.name)
    base.on_damaged(e.entity)
  end
end, BUILDINGS)

-- The command tool: select (drag), release (shift-drag), order (right-click or right-drag; shift: attack-move).
local TOOL = "lp-command-tool"
script.on_event(defines.events.on_player_selected_area, function(e)
  if e.item == TOOL then command.select(e.player_index, e.entities) end
end)
script.on_event(defines.events.on_player_alt_selected_area, function(e)
  if e.item == TOOL then command.release(e.player_index, e.entities) end
end)
script.on_event(defines.events.on_player_reverse_selected_area, function(e)
  if e.item == TOOL then command.order(e.player_index, e.surface, e.area, false) end
end)
script.on_event(defines.events.on_player_alt_reverse_selected_area, function(e)
  if e.item == TOOL then command.order(e.player_index, e.surface, e.area, true) end
end)

-- Deaths: the faction's buildings are queued for rebuild, its units counted lost, and what its units
-- destroy is counted razed (attributed through the unit that did it).
script.on_event(defines.events.on_entity_died, function(e)
  local ent = e.entity
  biters.on_died(e)
  local kind = shared.kind_of(ent.name)
  if kind == "lp-uplink" then faction.uplink_lost(ent) end
  -- Command cores from the wreckage: a depot gives one, a lander three (captured outposts: base.lua).
  if kind == "lp-depot" then command.drop_cores(ent.surface, ent.position, 1) end
  -- A mortar destroyed in the field leaves its wreck's salvage.
  if kind == "lp-mortar" then
    ent.surface.spill_item_stack{position = ent.position, stack = {name = "lp-salvage", count = 15}, enable_looted = true}
  end
  if kind == "lp-lander" then
    command.drop_cores(ent.surface, ent.position, 3)
    local b = base.fall(ent)
    -- The grudge: a lander the player destroyed is answered by every corporation (faction.grudge).
    if b and e.force and not shared.is_corp(e.force.name) and e.force.name ~= "enemy" and e.force.name ~= "neutral" then
      faction.grudge(b, e.force.name, e.cause and e.cause.valid and e.cause.position or nil)
    end
  end
  -- Shelled: the corporation learns where the battery is (ops.counter_battery) before the owner records go.
  if shared.is_corp(ent.force.name) and e.cause and e.cause.valid
    and (e.cause.type == "artillery-turret" or e.cause.type == "artillery-wagon") then
    ops.counter_battery(ent.force.name, ent.surface, e.cause, e.force and e.force.name)
  end
  if shared.is_corp(ent.force.name) then
    local id = storage.unit_owner[ent.unit_number]
    if id then
      storage.unit_owner[ent.unit_number] = nil
      local b = storage.bases[id]
      if b then
        b.units_lost = b.units_lost + 1
        ops.on_unit_killed(b, e.cause)
        if e.force then ops.provoke(b.force, e.force.name) end
      end
    else
      base.on_died(ent)
    end
  elseif e.force and shared.is_corp(e.force.name) and e.cause and e.cause.valid
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

commands.add_command("lp", {"lp.command-dev"}, dev.command)

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
  for _, e in pairs(surface.find_entities_filtered{area = area, force = b.force}) do
    table.insert(ents, {e.name, e.position.x, e.position.y, e.electric_network_id or 0, e.status or 0})
  end
  local ore = {}
  for _, r in pairs(surface.find_entities_filtered{area = area, type = "resource", name = site.ORES}) do
    table.insert(ore, {r.name, r.position.x, r.position.y, r.amount})
  end
  local roads = {}
  for _, t in pairs(surface.find_tiles_filtered{area = area, name = shared.variants(shared.FLOORS)}) do
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
  threat = function() return {player_ops = ops.player_ops(), last = storage.threat_last, holds = storage.budget_holds or 0} end,
  corp = function(corp) return faction.corp(corp) end,
  phases = function()
    local s = phases.state()
    return {signs = s.signs ~= nil, survey = s.survey and {done = s.survey.done, pos = s.survey.pos, corp = s.survey.corp},
      triggered = s.triggered and s.triggered.tick, delay = s.delay, early = s.early, arrived = s.arrived, corp = s.corp}
  end,
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
    if t.ops_off ~= nil then storage.ops_off = t.ops_off end
    if t.phases_fast ~= nil then storage.phases_fast = t.phases_fast end
    if t.era ~= nil then storage.era_override = t.era end
    if t.hq_fast ~= nil then storage.hq_fast = t.hq_fast end
    if t.strip_fast ~= nil then storage.strip_fast = t.strip_fast end
    if t.perimeter_fast ~= nil then storage.perimeter_fast = t.perimeter_fast end
    if t.grudge_fast ~= nil then storage.grudge_fast = t.grudge_fast end
    -- Tests of operations' mechanics (not of tempers): every corporation already provoked by the player.
    if t.provoke then for _, c in pairs(shared.CORPS) do ops.provoke(c.force, "player") end end
    for corp, lvl in pairs(t.corp_level or {}) do faction.corp(corp).level = lvl end
  end,
  set_trace = function(on) storage.trace = on end,
  bases = function() local t = {} for id in pairs(storage.bases) do table.insert(t, id) end table.sort(t) return t end,
  debug_modules = function(id, pos, r) return base.debug_modules(storage.bases[id], pos, r) end,
  -- Tests and showcases only: parts for a settlement (a young one has no surplus to export).
  -- Tests only: the command tool without a mouse (player index 1 need not exist).
  debug_select = function(area)
    local s = game.surfaces[1]
    return command.select(1, s.find_entities_filtered{area = area, force = "player", type = "unit"})
  end,
  debug_release = function(area)
    return command.release(1, game.surfaces[1].find_entities_filtered{area = area, force = "player", type = "unit"})
  end,
  debug_order = function(area, attackmove) return command.order(1, game.surfaces[1], area, attackmove) end,
  debug_parts = function(id, parts) local b = storage.bases[id]; if b then b.parts = b.parts + parts end end,
  -- Tests only: a depot beside the lander and parts, so a raid comes in minutes instead of half an hour.
  debug_depot = function(id, parts) return dev.depot(storage.bases[id], parts) end,
  snapshot = snapshot,
  -- Tests: the /lp dev tools (scripts/dev.lua) at a position, as a player standing there would use them.
  dev = function(args, pos, surface_index) dev.remote(args, pos, surface_index) end,
  stats = function(id) return storage.bases[id] and base.stats(storage.bases[id]) end,
})
