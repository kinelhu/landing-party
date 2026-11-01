local shared = require("shared")
local base = require("scripts.base")
local site = require("scripts.site")
local faction = require("scripts.faction")
local command = require("scripts.command")
local phases = require("__landing-party__.scripts.phases")
local biters = require("__landing-party__.scripts.biters")
faction.on_trigger = phases.late
local ops = require("__landing-party__.scripts.ops")
local pool = require("__landing-party__.scripts.pool")
local army = require("__landing-party__.scripts.army")
local watch = require("__landing-party__.scripts.watch")
local tune = require("__landing-party__.scripts.tune")
local jammer = require("__landing-party__.scripts.jammer")
local scanner = require("__landing-party__.scripts.scanner")
local roads = require("__landing-party__.scripts.roads")
local pods = require("__landing-party__.scripts.pods")
script.on_event(defines.events.on_cargo_pod_finished_descending, pods.on_landed)
local stance = require("__landing-party__.scripts.stance")
local dev = require("__landing-party__.scripts.dev")
local layout = require("__landing-party__.scripts.layout")
local rd = require("__landing-party__.scripts.rd")
local know = require("__landing-party__.scripts.know")
local war = require("__landing-party__.scripts.war")
local pact = require("__landing-party__.scripts.pact")
local jumper = require("__landing-party__.scripts.jumper")
local tap = require("__landing-party__.scripts.tap")
local bait = require("__landing-party__.scripts.bait")
local strike = require("__landing-party__.scripts.strike")
local marker = require("__landing-party__.scripts.marker")
local crew = require("__landing-party__.scripts.crew")
local cordon = require("__landing-party__.scripts.cordon")
local prospect = require("__landing-party__.scripts.prospect")
local standing = require("__landing-party__.scripts.standing")
local border = require("__landing-party__.scripts.border")
local road = require("__landing-party__.scripts.road")
local trade = require("__landing-party__.scripts.trade")
local ledger = require("__landing-party__.scripts.ledger")
local skim = require("__landing-party__.scripts.skim")
local prowl = require("__landing-party__.scripts.prowl")
local dome = require("__landing-party__.scripts.dome")
local belts = require("__landing-party__.scripts.belts")
local scorcher = require("__landing-party__.scripts.scorcher")
local map = require("__landing-party__.scripts.map")
local aim = require("__landing-party__.scripts.aim")
local herd = require("__landing-party__.scripts.herd")
local firemap = require("__landing-party__.scripts.firemap")
local threat = require("__landing-party__.scripts.threat")
local valuemap = require("__landing-party__.scripts.valuemap")
local costmap = require("__landing-party__.scripts.costmap")
local feeds = require("__landing-party__.scripts.feeds")
-- Synthexis's scouts take the corporations' way round turrets (herd.lua; a hook, not a require: ops is the corporations').
herd.route = function(...) return ops.route(...) end
-- And stages its waves as their raids stage (routing.outside) and reads an approach's fire as they do (ops.exposure).
herd.outside = function(...) return ops.outside(...) end
herd.exposure = function(surface, pos, forces) return ops.exposure(surface, pos, forces, true) end
herd.route_why = function() return ops.last_route end
local farm = require("__landing-party__.scripts.farm")
local creep = require("__landing-party__.scripts.creep")
local cell = require("__landing-party__.scripts.cell")
local oplog = require("__landing-party__.scripts.oplog")
local tactics = require("__landing-party__.scripts.tactics")
script.on_event(defines.events.on_ai_command_completed, herd.on_command_completed)
script.on_event(defines.events.on_entity_spawned, farm.on_spawned)
script.on_event(defines.events.on_script_trigger_effect, aim.on_trigger)
script.on_nth_tick(3600, aim.sweep)
war.forgive = standing.forgive
rd.era = ops.era
rd.trace = function(corp, text)
  if storage.trace then helpers.write_file("landing-party/decisions.txt", string.format("%8d %s  %s\n", game.tick, corp, text), true) end
end


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
  pact.apply()
  herd.init()
  command.init()
end

script.on_init(init)
script.on_configuration_changed(function() init(); base.heal_lines(); base.heal_labs() end)

-- The watchdog's view of a settlement (scripts/watch.lua).
local WATCH_DEPS = {
  trace = function(b, text) base.trace(b, text) end,
  units = function(b) return pool.roster(b) end,
  strength = function(b) return pool.strength(b) end,
  cap = function(b) return army.cap(b) end,
  reserve = function(b) return base.reserve and base.reserve(b) or 0 end,
  price = function(b)
    local price, weight = 0, 0
    for kind, w in pairs(army.mix(b) or {}) do price, weight = price + w * shared.unit_cost(b.corp, kind), weight + w end
    return weight > 0 and price / weight or 0
  end,
}
script.on_event(defines.events.on_tick, function(e)
  biters.tick(); base.tick(e.tick); faction.tick(e.tick); command.tick(e.tick); phases.tick(e.tick); rd.tick(e.tick); war.tick(e.tick); pact.tick(e.tick); jumper.tick(e.tick); tap.tick(e.tick); bait.tick(e.tick); strike.tick(e.tick); marker.tick(e.tick); crew.tick(e.tick); prospect.tick(e.tick); standing.tick(e.tick); border.tick(e.tick); road.tick(e.tick); trade.tick(e.tick); ledger.tick(e.tick); skim.tick(e.tick); prowl.tick(e.tick); dome.tick(e.tick); map.tick(e.tick); jammer.tick(e.tick); scanner.tick(e.tick); roads.tick(e.tick); pods.tick(e.tick); belts.tick(e.tick); scorcher.tick(e.tick); herd.tick(e.tick); farm.tick(e.tick); creep.tick(e.tick); know.tick(e.tick)
  oplog.tick(e.tick)
  watch.tick(e.tick, WATCH_DEPS)
end)

local PLAYER_BUILT = {{filter = "name", name = "lp-barracks"}, {filter = "name", name = "lp-rally-beacon"},
  {filter = "name", name = "lp-command-relay"}, {filter = "name", name = "lp-muster-point"}}
-- The player's poles too: one built by a corporation's pylon is not wired to it (base.unwire).
local BUILT = {{filter = "type", type = "electric-pole"}, {filter = "name", name = "lp-player-bait"},
  {filter = "name", name = "lp-strike-beacon"}, {filter = "name", name = "lp-pact-breaker"},
  {filter = "name", name = "lp-claim-marker"}, {filter = "name", name = "lp-border-stake"},
  {filter = "name", name = "lp-trade-post"}, {filter = "name", name = "lp-threat-scanner"}}
for _, f in ipairs(PLAYER_BUILT) do table.insert(BUILT, f) end
-- What a player builds inside Serenity's territory provokes it (ops.encroached).
for _, t in ipairs(ops.ENCROACH_TYPES) do table.insert(BUILT, {filter = "type", type = t}) end
local function on_built(e)
  local ent = e.entity
  ops.encroached(ent)
  if ent and ent.valid and ent.name == "lp-player-bait" then return bait.placed(ent) end
  if ent and ent.valid and ent.name == "lp-strike-beacon" then return strike.placed(ent) end
  if ent and ent.valid and (ent.name == "lp-pact-breaker" or ent.name == "lp-claim-marker") then return marker.placed(ent) end
  if ent and ent.valid and ent.name == "lp-border-stake" then return border.placed(ent) end
  if ent and ent.valid and ent.name == "lp-trade-post" then return trade.placed(ent) end
  if ent and ent.valid and ent.name == "lp-threat-scanner" then return scanner.placed(ent) end
  if ent and ent.valid and ent.type == "electric-pole" then
    if not shared.is_corp(ent.force.name) then base.unwire(ent) end
    return
  end
  command.on_built(e)
end
for _, ev in ipairs({defines.events.on_built_entity, defines.events.on_robot_built_entity,
  defines.events.script_raised_built}) do
  script.on_event(ev, on_built, BUILT)
end

-- Damage to the faction's buildings calls a response (filtered to them; army.alarm throttles).
local BUILDINGS = {}
for _, n in ipairs(shared.variants({"lp-lander", "lp-generator", "lp-pylon", "lp-drill", "lp-bin", "lp-fabricator",
  "lp-turret", "lp-wall", "lp-radar", "lp-depot", "lp-launchpad", "lp-lamp", "lp-scrap-cannon", "lp-optics-lab", "lp-line-lab",
  "lp-siege-lab"})) do
  table.insert(BUILDINGS, {filter = "name", name = n})
end
-- The biotech's pens: one attacked calls its farm's wave home (farm.lua).
table.insert(BUILDINGS, {filter = "name", name = "lp-pen"})
-- Its probe's runts: which of the player's turrets shoot at them (herd.lua).
table.insert(BUILDINGS, {filter = "name", name = "lp-runt"})
-- Its tumors: Grubstake hurting one breaks its truce (farm.on_damaged).
table.insert(BUILDINGS, {filter = "name", name = "lp-tumor"})
-- What holds a charge, for the Tesla's drain (scorcher.lua).
for _, t in ipairs({"electric-turret", "accumulator", "roboport", "electric-energy-interface"}) do
  table.insert(BUILDINGS, {filter = "type", type = t})
end
script.on_event(defines.events.on_entity_damaged, function(e)
  if e.damage_type and e.damage_type.name == "electric" then scorcher.drain(e) end
  if e.entity.name == "lp-pen" or e.entity.name == "lp-tumor" then return farm.on_damaged(e) end
  if e.entity.name == "lp-runt" then return herd.on_probe_hit(e) end
  if not shared.is_corp(e.entity.force.name) then return end
  -- Any other force: a rival corporation's fire raises the alarm as the player's does.
  if e.force and e.force ~= e.entity.force then
    -- Fighting at Serenity's line is fair war (the user, 2026-10-19, on hunting the line: each post hit had been
    -- answered, and the answers cost the factory more than the broken line saved): a cordon post's pieces raise its
    -- alarm (its units come to defend it) but provoke no answer.
    local own = e.entity.unit_number and storage.owner[e.entity.unit_number]
    -- Nor a unit hit on an errand of its own or away from home (know.resented): Grubstake's raid broke, the player's
    -- turrets shot the raiders running home, and it "answered" with a raid on the walled base it had just fled
    -- (system 1, 2026-10-25), as reprisals had before.
    local unit = e.entity.type == "unit" or e.entity.type == "spider-unit"
    local errand = unit and not know.resented(know.faction_of(e.entity.force.name), e.entity)
    if not (own and own.module and own.module.kind == "post") and not errand then
      ops.provoke(e.entity.force.name, e.force.name, e.cause and e.cause.valid and e.cause or e.entity)
    end
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
  -- What the factions know: every loss of theirs, by whom (scripts/know.lua).
  know.loss(e)
  biters.on_died(e)
  herd.on_died(e)
  if ent.name == "lp-pen" then farm.on_pen_died(e) end
  oplog.on_died(e)
  -- Cleared ground (docs/reviews/2026-10-14-biter-country-consult.md): a spawner's death, whoever killed it, is a
  -- corridor for 30 minutes (ops.route lets marches through it).
  if ent.type == "unit-spawner" then ops.cleared(ent.surface, ent.position); ledger.nest_died(ent, e.force) end
  -- Grubstake's yard (the skim's, the raids'): what it held spills.
  if ent.type == "container" and shared.is_corp(ent.force.name) then skim.died(ent) end
  local kind = shared.kind_of(ent.name)
  -- What a corporation's building or unit is made of (the engine's loot) goes into a wreck, not over the ground.
  if shared.is_corp(ent.force.name) and e.loot and not e.loot.is_empty() then
    local stacks = {}
    for i = 1, #e.loot do
      local st = e.loot[i]
      if st.valid_for_read then table.insert(stacks, {name = st.name, count = st.count, quality = st.quality.name}) end
    end
    e.loot.clear()
    shared.wreck(ent.surface, ent.position, stacks)
  end
  if kind == "lp-uplink" then faction.uplink_lost(ent) end
  if kind == "lp-pacifier" then pact.lost(ent) end
  -- Command cores from the wreckage: a depot gives one, a lander three (captured outposts: base.lua).
  if kind == "lp-depot" then command.drop_cores(ent.surface, ent.position, 1) end
  -- A mortar destroyed in the field (its loot is the prototype's: data.lua made_of).
  if kind == "lp-mortar" then
    local ob = storage.bases[storage.owner[ent.unit_number] or 0]
    for _, o in pairs(storage.bases) do if o.op and o.op.mortars then for _, m in ipairs(o.op.mortars) do if m == ent then ob = o end end end end
    if ob then
      local near = math.huge
      for _, u in ipairs(ob.op and ob.op.members or {}) do
        if u.valid then near = math.min(near, math.sqrt((u.position.x - ent.position.x) ^ 2 + (u.position.y - ent.position.y) ^ 2)) end
      end
      base.trace(ob, string.format("mortar at %.0f,%.0f destroyed by %s (%s); nearest guard %.0f tiles off", ent.position.x,
        ent.position.y, e.cause and e.cause.valid and e.cause.name or "?", e.force and e.force.name or "?", near))
    end
  end
  -- A howitzer destroyed in the field: its camp goes without one for HOWITZER_DOWN (siege.lua; Fable's consult: killing
  -- it cost Serenity nothing, a fresh one came with every siege).
  if kind == "lp-howitzer" or kind == "lp-parked-howitzer" or kind == "lp-howitzer-truck" then
    for _, o in pairs(storage.bases) do
      -- (In the field, or parked at home: base.park; or its truck, on the way or home.)
      local home_run = false
      for _, r in ipairs(o.haulers_home or {}) do if r.unit == ent then home_run = true end end
      if o.parked == ent or home_run or o.op and (o.op.howitzer == ent or o.op.hauler == ent
        or (o.op.piece == "lp-howitzer" and o.op.mortars and o.op.mortars[1] == ent)) then
        o.howitzer_down = game.tick + shared.HOWITZER_DOWN
        base.trace(o, string.format("howitzer at %.0f,%.0f destroyed by %s; none for %d minutes", ent.position.x,
          ent.position.y, e.force and e.force.name or "?", shared.HOWITZER_DOWN / 3600))
      end
    end
  end
  if kind == "lp-lander" then
    command.drop_cores(ent.surface, ent.position, 3)
    local b = base.fall(ent)
    -- The grudge: a lander the player destroyed is answered by every corporation (faction.grudge).
    if b and e.force and not shared.is_corp(e.force.name) and not shared.is_biters(e.force.name) and e.force.name ~= "neutral" then
      faction.grudge(b, e.force.name, e.cause and e.cause.valid and e.cause.position or nil)
    end
  end
  -- Shelled: the corporation learns where the battery is (ops.counter_battery) before the owner records go.
  if shared.is_corp(ent.force.name) and e.cause and e.cause.valid
    and (e.cause.type == "artillery-turret" or e.cause.type == "artillery-wagon") then
    ops.counter_battery(ent.force.name, ent.surface, e.cause, e.force and e.force.name)
  end
  -- Lost to biters: the hazard ledger (ops.hazard_clear).
  if shared.is_corp(ent.force.name) and e.force and e.force.name == "enemy" and ent.unit_number then
    local own = storage.owner[ent.unit_number]
    local hb = storage.bases[own and own.base or storage.unit_owner[ent.unit_number] or 0]
    if hb and not hb.fallen then ops.hazard_note(hb, ent.position, ent.type == "unit" or ent.type == "spider-unit") end
  end
  if shared.is_corp(ent.force.name) then
    -- Killed by a rival corporation: the camp it belonged to remembers (ops.wronged: a reprisal).
    -- (Not a unit lost on an errand of its own or away from home: know.resented.)
    local away = (ent.type == "unit" or ent.type == "spider-unit") and not know.resented(know.faction_of(ent.force.name), ent)
    if e.force and shared.is_corp(e.force.name) and e.force ~= ent.force and ent.unit_number and not away then
      local own = storage.owner[ent.unit_number]
      ops.wronged(storage.bases[own and own.base or storage.unit_owner[ent.unit_number] or 0], e.force.name)
    end
    -- A crew's truck or drone killed is an attack on the corporation, as on its garrison (the user, 2026-10-17: "it
    -- gets multiple haulers destroyed and doesn't turn hostile").
    local cid = storage.crew_owner and storage.crew_owner[ent.unit_number]
    if cid then
      storage.crew_owner[ent.unit_number] = nil
      if e.force then ops.provoke(ent.force.name, e.force.name, e.cause and e.cause.valid and e.cause or ent.position) end
    end
    local id = storage.unit_owner[ent.unit_number]
    if id then
      storage.unit_owner[ent.unit_number] = nil
      local b = storage.bases[id]
      pool.discharge(b, ent.unit_number)
      if b then
        b.units_lost = b.units_lost + 1
        ops.raider_died(b, ent)
        ops.on_unit_killed(b, e.cause)
        -- A clearance's losses: what killed them, and how far from the site (diagnostic, first ten an operation).
        if b.op and b.op.clearance and (b.op.deaths_traced or 0) < 10 then
          b.op.deaths_traced = (b.op.deaths_traced or 0) + 1
          base.trace(b, string.format("clearance: %s killed by %s at %.0f tiles from the site", shared.kind_of(ent.name),
            e.cause and e.cause.valid and e.cause.name or "?", math.sqrt((ent.position.x - b.op.site[1]) ^ 2
            + (ent.position.y - b.op.site[2]) ^ 2)))
        end
        if e.force then ops.provoke(b.force, e.force.name, e.cause and e.cause.valid and e.cause or ent.position) end
      end
    else
      base.on_died(ent, e.force and e.force.name)
    end
  elseif e.force and shared.is_corp(e.force.name) and ent.force.name ~= "neutral" and not shared.is_biters(ent.force.name) then
    -- A player building razed by a corporation, whatever did it, its killer dead or alive: the ladder's clock
    -- (ops.ladder) and the tally (lasers and artillery kept falling on the user's save with the tally still).
    -- (A building, not a wall piece or a mine: one wall piece a raid broke reset its war ladder, and its desperation with
    -- it; the counters and desperation consult, 2026-10-31.)
    if not shared.is_corp(ent.force.name) and ent.type ~= "wall" and ent.type ~= "gate" and ent.type ~= "land-mine" then
      storage.last_raze = storage.last_raze or {}
      storage.last_raze[ent.force.name] = e.tick
      storage.last_raze[ent.force.name .. "|" .. e.force.name] = e.tick
      storage.player_razed = storage.player_razed or {}
      local k = ent.force.name .. ":" .. ent.type
      storage.player_razed[k] = (storage.player_razed[k] or 0) + 1
      local corp = standing.corp_of_force(e.force.name)
      if corp then standing.incident(corp, "razed", ent.position, ent.name) end
    end
    -- Razed counts the player's structures only (trees felled by shells once inflated it by half).
    local id = e.cause and e.cause.valid and storage.unit_owner[e.cause.unit_number]
    local b = id and storage.bases[id]
    if b then
      b.razed = b.razed + 1
      b.razed_at = e.tick
      rd.salvage(b.corp, ops.VALUE[shared.kind_of(ent.name)] or ops.VALUE[ent.type])
      -- Grubstake's razing pays its next pod too (scripts/war.lua).
      if b.corp == "grubstake" then war.fund(b.corp, 50 + 25 * (ops.VALUE[shared.kind_of(ent.name)] or ops.VALUE[ent.type] or 0)) end
      if ent.type == "container" or ent.type == "logistic-container" or ent.type == "cargo-wagon" then ops.loot_wreck(b, ent) end
    end
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
  game.print("landing-party trace: " .. tostring(storage.trace)) -- notice-ok: the /lp-trace command
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
  -- The same, asynchronous (faction.request): the landing waits for its ground; landing_jobs counts those queued.
  arrive_async = function(surface_index, from, distance, opts)
    opts = opts or {}
    opts.distance = distance
    faction.request(game.surfaces[surface_index], from, opts, true, "remote")
  end,
  landing_jobs = function() return {queued = #(storage.landing_jobs or {}), last = storage.last_landing} end,
  faction = function() return faction.state() end,
  threat = function() return {player_ops = ops.player_ops(), last = storage.threat_last, holds = storage.budget_holds or 0} end,
  -- The ladder's state: the last raze per player force, its rung, and the player's buildings razed by type.
  pressure = function(force)
    local f = force or "player"
    -- The highest rung any corporation stands on against it (each keeps its own clock, ops.ladder).
    local rung = ops.ladder(f)
    for _, c in pairs(shared.CORPS) do rung = math.max(rung, ops.ladder(f, c.force)) end
    return {last_raze = (storage.last_raze or {})[f], ladder = rung, razed = storage.player_razed or {}}
  end,
  corp = function(corp) return faction.corp(corp) end,
  war = function(corp) return war.summary(corp) end,
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
    if t.crews_off ~= nil then storage.crews_off = t.crews_off or nil end
    -- (0.2.29's ground handling, each off: bisecting what it changed.)
    for _, k in ipairs({"blast_off", "landfill_off", "pier_off"}) do if t[k] ~= nil then storage[k] = t[k] or nil end end
    if t.grow_to_line_off ~= nil then storage.grow_to_line_off = t.grow_to_line_off or nil end
    if t.wfc_core_off ~= nil then storage.wfc_core_off = t.wfc_core_off or nil end
    if t.cordon_off ~= nil then storage.cordon_off = t.cordon_off or nil end
    if t.labs_off ~= nil then storage.labs_off = t.labs_off or nil end
    if t.belts_always ~= nil then storage.belts_always = t.belts_always or nil end
    -- The arena (tests/lp-arena): a surface with no camp whose Scorchers still burn.
    if t.arena_surface then storage.arena_surfaces = storage.arena_surfaces or {}; storage.arena_surfaces[t.arena_surface] = true end
    if t.tap_step ~= nil then storage.tap_step = t.tap_step end
    if t.capture_off ~= nil then storage.capture_off = t.capture_off end
    if t.biotech_unlearned ~= nil then storage.biotech_unlearned = t.biotech_unlearned or nil end
    if t.biotech_no_orders ~= nil then storage.biotech_no_orders = t.biotech_no_orders or nil end
    -- march_trace: each marching herd's group every second to the log (where, its state, its order; debugging).
    if t.march_trace ~= nil then storage.march_trace = t.march_trace or nil end
    if t.biotech_no_hold ~= nil then storage.biotech_no_hold = t.biotech_no_hold or nil end
    -- old_stock: Synthexis's army bred by the engine and standing at its incubators, as before 0.2.90 (farm.lua hatching).
    if t.old_stock ~= nil then storage.biotech_old_stock = t.old_stock or nil end
    if t.prospect_window ~= nil then storage.prospect_window = t.prospect_window end
    if t.prospect_pace ~= nil then storage.prospect_pace = t.prospect_pace end
    if t.prospect_uncharted ~= nil then storage.prospect_uncharted = t.prospect_uncharted end
    if t.prospect_radius ~= nil then storage.prospect_radius = t.prospect_radius end
    if t.prospect_home ~= nil then storage.prospect_home = t.prospect_home end
    if t.road_haul ~= nil then storage.road_haul = t.road_haul end
    if t.road_lapse ~= nil then storage.road_lapse = t.road_lapse end
    if t.army_off ~= nil then storage.army_off = t.army_off end
    if t.raids_off ~= nil then storage.raids_off = t.raids_off end
    if t.ops_off ~= nil then storage.ops_off = t.ops_off end
    if t.phases_fast ~= nil then storage.phases_fast = t.phases_fast end
    if t.era ~= nil then storage.era_override = t.era end
    if t.hq_fast ~= nil then storage.hq_fast = t.hq_fast end
    if t.strip_fast ~= nil then storage.strip_fast = t.strip_fast end
    if t.perimeter_fast ~= nil then storage.perimeter_fast = t.perimeter_fast end
    if t.grudge_fast ~= nil then storage.grudge_fast = t.grudge_fast end
    if t.siege_tier ~= nil then storage.siege_tier = t.siege_tier end
    if t.sneak_off ~= nil then storage.sneak_off = t.sneak_off end
    if t.history_off ~= nil then storage.history_off = t.history_off end
    if t.rings ~= nil then storage.rings = t.rings or nil end
    if t.ladder_fast ~= nil then storage.ladder_fast = t.ladder_fast end
    -- The levers (tune.lua) over the settings: {grubstake = {strength = 2, aggression = 0.5}, ...}.
    if t.levers ~= nil then storage.tune_levers = t.levers end
    -- Tests: no operation of choice (the decider), answers still on.
    if t.choice_off ~= nil then storage.choice_off = t.choice_off end
    if t.gates_off ~= nil then storage.gates_off = t.gates_off end
    if t.focus_off ~= nil then storage.focus_off = t.focus_off end
    if t.cuts_off ~= nil then storage.cuts_off = t.cuts_off end
    if t.pods_off ~= nil then storage.pods_off = t.pods_off end
    if t.strangle_off ~= nil then storage.strangle_off = t.strangle_off end
    if t.next_ore_off ~= nil then storage.next_ore_off = t.next_ore_off end
    if t.sever_off ~= nil then storage.sever_off = t.sever_off end
    if t.hazard_off ~= nil then storage.hazard_off = t.hazard_off end
    if t.hazard_hold ~= nil then storage.hazard_hold = t.hazard_hold end
    if t.ledger_off ~= nil then storage.ledger_off = t.ledger_off end
    if t.skim_off ~= nil then storage.skim_off = t.skim_off end
    if t.night_off ~= nil then storage.night_off = t.night_off end
    if t.leader_off ~= nil then storage.leader_off = t.leader_off end
    -- The biotech's pens send no wave on their own (tests send them: herd_wave).
    if t.herd_off ~= nil then storage.herd_off = t.herd_off end
    -- (Its big bursters developed, as if walls had held its waves: herd.develop_bursters.)
    if t.bursters ~= nil then know.of("biotech").bursters = t.bursters and game.tick or nil end
    -- No biotech arrival (farm.lua); tests that bring it do so with farm_arrive.
    if t.biotech_off ~= nil then storage.biotech_off = t.biotech_off end
    if t.way_in ~= nil then storage.way_in = t.way_in end
    if t.prowl ~= nil then storage.prowl = t.prowl end
    if t.domes ~= nil then storage.domes = t.domes end
    if t.dome_charge ~= nil then storage.dome_charge = t.dome_charge end
    if t.domes_off then storage.domes = false end
    if t.armed ~= nil then storage.armed = t.armed end
    if t.armed_off then storage.armed = false end
    -- Tests and the siege lab: its cultures bud no incubator (their waves' size held, farm.cap_of).
    if t.pens_hold ~= nil then storage.biotech_pens_hold = t.pens_hold end
    -- Tests only (the arc's control): the corporations build and grow but do nothing to the player.
    if t.harmless ~= nil then
      for _, k in ipairs({"ops_off", "jump_off", "tap_off", "skim_off", "prospect_off", "sever_off", "cuts_off",
        "strangle_off", "ledger_off", "raids_off"}) do storage[k] = t.harmless or nil end
    end
    if t.notices ~= nil then storage.notices = t.notices end
    if t.rd_fast ~= nil then storage.rd_fast = t.rd_fast end
    for corp, n in pairs(t.rd_fund or {}) do rd.state(corp).fund = n end
    for corp, tech in pairs(t.rd_tech or {}) do rd.set(corp, tech) end
    for corp, n in pairs(t.rd_walls or {}) do for _ = 1, n do rd.walls_met({corp = corp}) end end
    -- Tests of operations' mechanics (not of tempers): every corporation already provoked by the player.
    if t.provoke then for _, c in pairs(shared.CORPS) do ops.provoke(c.force, "player") end end
    -- The war chest (scripts/war.lua): its contents per corporation, the relief period, relief off.
    for corp, n in pairs(t.chest or {}) do faction.corp(corp).chest = n end
    if t.relief_minutes ~= nil then storage.relief_ticks = t.relief_minutes * 3600 end
    if t.relief_off ~= nil then storage.relief_off = t.relief_off end
    if t.pact_off ~= nil then storage.pact_off = t.pact_off; pact.apply() end
    if t.quiet_minutes then storage.quiet_ticks = t.quiet_minutes * 3600 end
    for corp, lvl in pairs(t.corp_level or {}) do faction.corp(corp).level = lvl end
  end,
  set_trace = function(on) storage.trace = on end,
  -- The biotech (scripts/herd.lua). Tests only: a wild spawner near pos becomes a pen; bred units into a pen's stock;
  -- a wave from a pen at pos (opts.sight: its biters' sight, 0 for the blind control); the herd's state and log.
  herd_capture = function(surface_index, pos)
    local sp = game.surfaces[surface_index].find_entities_filtered{position = pos, radius = 8, type = "unit-spawner",
      force = "enemy", limit = 1}[1]
    return sp and herd.capture(sp)
  end,
  herd_fill = function(pen_id, n, name)
    local p = storage.herd.pens[pen_id]
    local s = p.pen.surface
    for _ = 1, n do
      local q = s.find_non_colliding_position(name, p.pen.position, 30, 0.5)
      local u = q and s.create_entity{name = name, position = q, force = shared.BIOTECH.force}
      if u then table.insert(p.stock, u) end
    end
    return #p.stock
  end,
  -- (opts.planned, tests only: the wave follows a plan of its farm's kind, herd.plan, as a farm's wave does.)
  herd_wave = function(pen_id, pos, opts)
    local p = storage.herd.pens[pen_id]
    if opts and opts.planned then
      opts.plan, opts.planned = herd.plan(p.pen.surface, p.pen.position, pos, {"player"}, #(p.stock or {})), nil
    end
    return herd.launch(p, pos, opts)
  end,
  herd_wall_lesson = function(pos) herd.debug_wall_lesson(pos) end,
  herd_state = function() return herd.state() end,
  herd_drop_group = function(id) return herd.debug_drop_group(id) end,
  herd_add_stock = function(id, name, n) return herd.debug_add_stock(id, name, n) end,
  -- Tests and the siege lab: the last operation records closed, every faction's, read alike (oplog.lua, attempt.lua).
  oplog_recent = function() return oplog.recent() end,
  -- Tests and the siege lab: why a settlement launches nothing (its targets, its clock, the switches, its war).
  debug_corp_why = function(id)
    local b = storage.bases[id]
    if not b then return nil end
    local n, mine = 0, 0
    for _, t in pairs((b.intel and b.intel.targets) or {}) do
      n = n + 1
      if t.owner == "player" then mine = mine + 1 end
    end
    local f = game.forces[b.force]
    return {siege = ops.siege_why(b, army), targets = n, player_targets = mine, next_op = b.next_op, tick = game.tick, op = b.op and b.op.kind,
      enemy = f and f.is_enemy(game.forces.player), ops_off = storage.ops_off, raids_off = storage.raids_off,
      army_off = storage.army_off, choice_off = storage.choice_off, garrison = b.garrison and #b.garrison or 0,
      depot = b.depots and #b.depots or nil, parts = b.parts}
  end,
  -- Tests and the siege lab: a settlement's parts at `parts` at least (its siege costs SIEGE_COST: what the lab primes,
  -- as it primes Synthexis's biomass), and what its attempts have done (tactics.lua).
  -- Tests only: what a settlement's raid at pos would be (ops.raid_want: what got in there, else its formula).
  -- Tests and the siege lab: a corporation's war chest filled to `parts` at least (its reliefs paid from it, war.lua: the
  -- lab's chest was empty, and a desperate corporation could never find its force).
  debug_war_chest = function(corp, parts) return war.debug_chest(corp, parts) end,
  -- Tests only: the settlement a unit (or a mortar) is credited to (storage.unit_owner), by unit number.
  debug_unit_owner = function(unit_number) return storage.unit_owner and storage.unit_owner[unit_number] end,
  -- Tests only: where a settlement would set up a siege against pos (siege.lua siege_site), nil if nowhere.
  debug_siege_site = function(id, pos) local b = storage.bases[id]; return b and ops.debug_siege_site(b, pos) end,
  -- Tests only: a settlement's siege plan against pos (siege.lua siege_plan): its site and piece.
  debug_siege_plan = function(id, pos)
    local b = storage.bases[id]
    if not b then return nil end
    local site, piece = ops.siege_plan(b, {pos = pos, owner = "player"}, army)
    return {site = site, piece = piece}
  end,
  debug_desperate_ok = function(id, n, d) local b = storage.bases[id]; return b and ops.desperate_ok(b, n, d) end,
  debug_raid_want = function(id, pos, defence)
    local b = storage.bases[id]
    if not b then return nil end
    return ops.raid_want(b, {pos = pos, owner = "player", defence = defence})
  end,
  debug_corp_parts = function(id, parts)
    local b = storage.bases[id]
    if b then b.parts = math.max(b.parts or 0, parts) end
    return b and b.parts
  end,
  -- Tests and the siege lab: a corporation's development level at `level` at least (its siege from 1: the lab's camp sat
  -- at 0 and never weighed one).
  debug_corp_level = function(corp, level)
    storage.corps = storage.corps or {}
    storage.corps[corp] = storage.corps[corp] or {}
    storage.corps[corp].level = math.max(storage.corps[corp].level or 0, level)
    return storage.corps[corp].level
  end,
  debug_ladder = function(faction, foe, pos, method, near) return tactics.ladder(faction, foe, pos, method, nil, nil, nil, near) end,
  -- Tests only: the damage a killer's kills are put down to (know.lua), and the war ladder's clock for a player force.
  debug_damage_of = function(name) return know.DAMAGE_BY_NAME[name] end,
  debug_last_raze = function(key) return storage.last_raze and storage.last_raze[key] end,
  debug_failed_specialists = function(faction, foe, pos, method) return tactics.failed_specialists(faction, foe, pos, method, nil) end,
  -- Tests only: an option weighed as every attacker's are (tactics.expect): whether it is worth weighing, its ladder.
  debug_expect = function(faction, foe, pos, method)
    local op = {method = method, at = {x = pos[1], y = pos[2]}, gain = 10, lost = 1, sent = 10}
    local ok = tactics.expect(faction, op, foe, nil, {far = 300, min_gain = 2}, 10, 0)
    return {ok = ok, ladder = op.ladder}
  end,
  debug_tactics_record = function(faction, foe, pos, method, e) tactics.record(faction, foe, pos, method, e) end,
  -- Tests and the siege lab: a settlement shown what stands within r of pos, as its radar would (intel.lua, ops.sense_at).
  debug_sense = function(id, pos, r)
    local b = storage.bases[id]
    if b then ops.sense_at(b, {x = pos[1] or pos.x, y = pos[2] or pos.y}, r) end
    return b ~= nil
  end,
  -- Tests and the siege lab: each settlement's corporation and its operation now (kind, started), nil if none.
  bases_ops = function()
    local out = {}
    for id, b in pairs(storage.bases or {}) do
      out[#out + 1] = {id = id, corp = b.corp, op = b.op and {kind = b.op.kind, started = b.op.started} or nil, fallen = b.fallen}
    end
    return out
  end,
  rd_state = function(corp) return rd.state(corp) end,
  -- Tests only: a farm's arrival now, whatever the evolution (true if a field was found); the farms' state.
  farm_arrive = function(surface_index) return farm.arrive_now(game.surfaces[surface_index]) end,
  farm_debug_seed = function(id) return farm.debug_seed(id) end,
  -- Tests and the siege lab: incubators added to a farm, and the most it sends at once (farm.cap_of).
  farm_add_pens = function(id, n) return farm.debug_add_pens(id, n) end,
  farm_cap = function(id) return farm.debug_cap(id) end,
  farm_set_evo = function(id, v) return farm.debug_set_evo(id, v) end,
  farm_growth = function(id, amount) return farm.debug_growth(id, amount) end,
  farm_state = function() return farm.state() end,
  -- Tests only: what Synthexis has learned a prototype of `foe`'s costs it (nil: nothing yet).
  -- The siege lab (tests/lp-sim, mix lab): its culture primed for a trial, and its waves' units for the recorder.
  lab_prime = function(id, biomass) return farm.debug_lab_prime(id, biomass) end,
  lab_time_ways = function(id, cell) return farm.debug_time_ways(id, cell) end,
  debug_siege_size = function(id, pl, floor) return farm.debug_siege_size(id, pl, floor) end,
  debug_chance = function(id, killers) return farm.debug_chance(id, killers) end,
  debug_reseed = function(id, seed) return farm.debug_reseed(id, seed) end,
  lab_waves = function() return herd.lab_waves() end,
  -- Tests only: the size herd.best_size draws from an attempt's history (its sieges sized by what razed most per biomass).
  debug_best_size = function(hist, least, sig) return herd.best_size({hist = hist}, least, sig) end,
  debug_best_rams = function(hist, least, sig) return select(2, herd.best_size({hist = hist}, least, sig)) end,
  -- Tests only: attempts kept as a siege's would be (key: foe|cx,cy|method), and those near a breach (herd.history_near).
  debug_attempt_put = function(key, hist)
    local k = know.of("biotech")
    k.attempts = k.attempts or {}
    for _, h in ipairs(hist) do h.tick = h.tick or game.tick end
    k.attempts[key] = {n = #hist, spent = 0, got = 0, inside = 0, tick = game.tick, hist = hist}
  end,
  debug_history_near = function(foe, breach, method) return #herd.history_near(foe, breach, method, nil) end,
  debug_stopped = function(key, tick) herd.stopped(key, tick) return herd.held() end,
  debug_learn_reach = function(r0, set_off, sent, stuck) return herd.learn_reach(r0, set_off, sent, stuck) end,
  debug_held_back = function(alive_n, sent, guns, inside) return herd.held_back(alive_n, sent, guns, inside) end,
  -- Tests only: sets what it has learned of its rams' reach at `foe`, returning what it was.
  debug_reach = function(foe, r)
    local k = know.of("biotech")
    k.reach = k.reach or {}
    local was = k.reach[foe]
    k.reach[foe] = r
    return was
  end,
  debug_razed = function(list) local n = 0 for _, e in ipairs(list) do n = n + valuemap.razed_of(e) end return n end,
  lab_prices = function()
    local k, out = know.of("biotech"), {price = {}, scale = {}}
    for foe, ps in pairs(k.price or {}) do
      out.price[foe] = {}
      for proto, r in pairs(ps) do out.price[foe][proto] = r.per end
    end
    for foe, v in pairs(k.scale or {}) do out.scale[foe] = v end
    out.opens = {}
    for foe, v in pairs(k.opens or {}) do out.opens[foe] = v end
    return out
  end,
  debug_price = function(foe, proto) return know.price("biotech", foe, proto) end,
  -- Tests only: what it has learned a prototype costs it, set (as if its waves had died to it).
  debug_learn_price = function(foe, proto, per) return know.learn_price("biotech", foe, proto, per, per) end,
  -- Tests only: a corporation's price set (know.learn_price), and its weighing of a place (ops.weigh, its own reading).
  debug_corp_price = function(corp, foe, proto, per) return know.learn_price(corp, foe, proto, per, per) end,
  debug_weigh = function(surface_index, pos, corp, r)
    return (ops.weigh(game.surfaces[surface_index], {x = pos[1], y = pos[2]}, {"player"}, r or 0.5, corp))
  end,
  -- Tests only: a price learned from a sample at a weight (know.learn_price), from a prior.
  debug_learn_weighted = function(foe, proto, sample, prior, weight)
    return know.learn_price("biotech", foe, proto, sample, prior, false, weight)
  end,
  -- Tests only: biomass added to a farm's culture (a siege's breeds paid for without an hour of pollution).
  debug_biomass = function(id, amount)
    local c = creep.of(id)
    if c then c.biomass = c.biomass + amount end
    return c and c.biomass
  end,
  watch_state = function() return watch.state() end,
  creep_state = function() return creep.state() end,
  cell_state = function() return cell.state() end,
  cell_sites = function() return cell.sites() end,
  know_state = function() return know.state() end,
  -- Tests: a settlement's mix as it stands, and as its losses tilt it now (army.composition).
  debug_compose = function(id) local b = storage.bases[id]; local m = army.mix(b); return {mix = m, composed = army.composition(b, m)} end,
  farm_wave = function(n, deep, decide) return farm.debug_wave(n, deep, decide) end,
  bases = function() local t = {} for id in pairs(storage.bases) do table.insert(t, id) end table.sort(t) return t end,
  -- A camp's pending jobs (tests: what it waits on): queue head first, rebuilds, crews' loads, its fabricators' modules.
  debug_jobs = function(id)
    local b = storage.bases[id]
    if not b then return nil end
    local function s(j) return string.format("%s@%.0f,%.0f%s", j.name or (j.tiles and "tiles") or "?", j.pos and j.pos[1] or 0,
      j.pos and j.pos[2] or 0, j.module and (" [" .. tostring(j.module.kind) .. "]") or "") end
    local out = {queue = {}, rebuild = {}, crews = {}, parts = b.parts, waiting = b.waiting}
    for i, j in ipairs(b.queue) do if i <= 12 then out.queue[#out.queue + 1] = s(j) end end
    for _, j in ipairs(b.rebuild) do out.rebuild[#out.rebuild + 1] = s(j) end
    for _, c in ipairs(b.crews or {}) do out.crews[#out.crews + 1] = #(c.jobs or {}) .. " jobs, at " .. tostring(c.k) end
    return out
  end,
  -- What a camp's intel holds within r of pos (tests: the prowl), and how many prowls it sent.
  debug_knows = function(id, pos, r)
    local b = storage.bases[id]
    if not b then return nil end
    local out = {prowls = b.prowls or 0, cells = {}}
    for _, t in pairs(b.intel and b.intel.targets or {}) do
      if (t.pos[1] - pos[1]) ^ 2 + (t.pos[2] - pos[2]) ^ 2 <= r * r then
        out.cells[#out.cells + 1] = string.format("%s@%.0f,%.0f loot %s", t.kind, t.pos[1], t.pos[2], tostring(t.loot))
      end
    end
    return out
  end,
  debug_dome = function(id) local b = storage.bases[id]; return b and dome.state(b) end,
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
  -- Tests only: the route planner from a settlement's home to pos (nests and turrets as for a sneaking march).
  debug_route = function(id, to)
    local b = storage.bases[id]
    local r = ops.route(b, {b.origin.x, b.origin.y}, to, {turrets = true, nests = true})
    return {found = r ~= nil, waypoints = r and #r or 0, corridors = #(storage.corridors or {}), last = ops.last_route,
      route = r, from = {b.origin.x, b.origin.y}}
  end,
  -- Tests only: what Synthexis reads of the player's base from `from` (valuemap, firemap) and the soft hearts it finds for a
  -- wave of n, for scripts/wavemap.py.
  debug_base_maps = function(from, radius, n, reach)
    local s = game.surfaces[1]
    local forces = {game.forces.player}
    local vmap = valuemap.read(s, from, radius, forces, valuemap.CORE)
    local fmap = firemap.read(s, from, radius * firemap.BOX, forces, herd.price_of)
    local cells, turrets, hearts = {}, {}, {}
    for _, c in pairs(vmap.cells) do cells[#cells + 1] = {c.mid.x, c.mid.y, c.worth} end
    for _, t in ipairs(fmap.list) do turrets[#turrets + 1] = {t.x, t.y, t.r} end
    for _, h in ipairs(valuemap.hearts(vmap, fmap, n or 60, from, reach or 400, {most = 10})) do
      hearts[#hearts + 1] = {h.cell.mid.x, h.cell.mid.y, h.worth, h.cost, h.score, h.at and {h.at.position.x, h.at.position.y}}
    end
    return {cells = cells, turrets = turrets, hearts = hearts, cell = vmap.size}
  end,
  -- Tests only: what reaching every cell of the box round `center` costs from `from` (the cost map Synthexis's waves read:
  -- the player's walls and ground, everyone's guns and armed units, water): {x0, y0, size, w, cost = {[i * w + j] = c}}.
  debug_cost_grid = function(from, center, radius, cell)
    local s = game.surfaces[1]
    local fmap = firemap.read(s, {x = center[1], y = center[2]}, radius * firemap.BOX, herd.hostiles(), herd.price_of, threat.ARMED)
    local cm = costmap.read(s, {x = center[1], y = center[2]}, radius, {game.forces.player}, {fire = fmap,
      from = {x = from[1], y = from[2]}, cell = cell})
    local cost = {}
    for k, c in pairs(cm.cost) do cost[#cost + 1] = {math.floor(k / cm.h), k % cm.h, c} end
    return {x0 = cm.x0, y0 = cm.y0, size = cm.size, w = cm.w, cost = cost}
  end,
  -- Tests only: the cost map's cheapest way from `from` to `to` over the player's base (the box round both, `cell` tiles a
  -- cell): {cost, path = {{x, y}...}}.
  debug_cost_path = function(from, to, cell)
    local s = game.surfaces[1]
    local forces = {game.forces.player}
    local mid = {x = (from[1] + to[1]) / 2, y = (from[2] + to[2]) / 2}
    local radius = math.sqrt((from[1] - to[1]) ^ 2 + (from[2] - to[2]) ^ 2) / 2 + 150
    local fmap = firemap.read(s, mid, radius * firemap.BOX, forces, herd.price_of)
    local cm = costmap.read(s, mid, radius, forces, {fire = fmap, from = {x = from[1], y = from[2]}, cell = cell})
    local path = {}
    for _, q in ipairs(costmap.path(cm, {x = to[1], y = to[2]}) or {}) do path[#path + 1] = {q.x, q.y} end
    return {cost = costmap.cost(cm, {x = to[1], y = to[2]}), path = path}
  end,
  -- Tests only: what feeds.lua reads of the player's turrets' supply round pos: {name, x, y, starves} each.
  debug_feeds = function(pos, radius)
    local out = {}
    for _, f in pairs(feeds.read(game.surfaces[1], pos, radius, {game.forces.player})) do
      if f.e.valid then out[#out + 1] = {f.e.name, f.e.position.x, f.e.position.y, f.starves, f.held} end
    end
    return out
  end,
  -- Tests only: the weapon profiles threat.lua reads from prototypes, and the longest reach.
  debug_threat = function(names)
    local out = {far = threat.far()}
    for _, n in ipairs(names) do out[n] = threat.profile(n) or false end
    return out
  end,
  -- Tests only: the route planner between two points for Synthexis's herds (opts as the herd's).
  debug_herd_route = function(from, to, opts)
    local r = ops.route({surface = 1, force = shared.BIOTECH.force}, from, to, opts)
    return {waypoints = r and #r or 0, last = ops.last_route, route = r}
  end,
  -- Tests only: units of a kind straight into a settlement's garrison.
  debug_units = function(id, kind, n)
    local b = storage.bases[id]
    local s = b.lander.surface
    local name = shared.variant(b.corp, kind)
    for _ = 1, n do
      local p = s.find_non_colliding_position(name, {b.lander.position.x, b.lander.position.y + 10}, 20, 0.5)
      local u = p and s.create_entity{name = name, position = p, force = b.lander.force}
      if u then table.insert(b.garrison, u); pool.enlist(b, u) end
    end
  end,
  -- Tests only: take every unit a floor allows (pool.floor's kind), report what was left home, and give them back.
  debug_take = function(id, kind)
    local b = storage.bases[id]
    local before = pool.home(b)
    local floor = pool.floor(army.cap(b), kind)
    local taken = pool.take(b, 999, floor)
    local left = pool.home(b)
    for _, u in ipairs(taken) do table.insert(b.garrison, u) end
    return {before = before, floor = floor, taken = #taken, left = left}
  end,
  -- Tests only: a runtime-global setting changed as an admin would (only the owning mod may write it).
  debug_setting = function(name, value) settings.global[name] = {value = value} end,
  -- Tests only: what the levers read and drive for a settlement (tune.lua).
  debug_levers = function(id)
    local b = storage.bases[id]
    return {strength = tune.strength(b.corp), aggression = tune.aggression(b.corp), cap = army.cap(b),
      hour = tune.sooner(b.corp, 3600 * 60), rung = stance.rung("player", b.force)}
  end,
  debug_parts = function(id, parts) local b = storage.bases[id]; if b then b.parts = b.parts + parts end end,
  -- A town grown at once, for pictures (scripts/shots.sh town): machine lots with their machines queued, then streets.
  debug_town = function(id, machines, streets) local b = storage.bases[id]; return b and layout.debug_town(b, machines, streets) end,
  -- Tests only: a depot beside the lander and parts, so a raid comes in minutes instead of half an hour.
  debug_depot = function(id, parts) return dev.depot(storage.bases[id], parts) end,
  snapshot = snapshot,
  rd = function(corp) return rd.summary(corp) end,
  debug_needed = function(id, pos) return ops.debug_needed(storage.bases[id], {x = pos[1], y = pos[2]}) end,
  -- Tests: the /lp dev tools (scripts/dev.lua) at a position, as a player standing there would use them.
  dev = function(args, pos, surface_index) dev.remote(args, pos, surface_index) end,
  stats = function(id) return storage.bases[id] and base.stats(storage.bases[id]) end,
  pact_state = function() return storage.pact_state end,
  notice_counts = function() return storage.notice_counts or {told = 0, held = 0} end,
  debug_notice = function(key) shared.notice(game.forces.player, {key, "test", "test"}) end,
  -- Tests only: one entity of kind `name` placed and registered for settlement `id` as its yard places it (scripts/lp-shots).
  debug_place = function(id, name, pos)
    local b = storage.bases[id]
    local e = b and base.place_job(b, {name = name, pos = pos})
    return e and e.unit_number
  end,
  scorcher_stats = function() return scorcher.stats() end,
  belt_stats = function(id) return storage.bases[id] and belts.stats(storage.bases[id]) end,
  debug_crew = function(id, pos, names) return storage.bases[id] and crew.debug_module(storage.bases[id], pos, names) end,
  standing = function(corp, owner) return standing.get(corp, owner or "player") end,
  trade_stats = function() return trade.stats() end,
  -- Tests only: a mast of `corp` raised at `pos`, as a siege raises it.
  debug_jammer = function(corp, pos) local m = jammer.raise(game.surfaces[1], pos, game.forces[shared.CORPS[corp].force]); return m and m.unit_number end,
  jammer_stats = function() return {jammed = storage.jammed or 0, masts = #(storage.jammers or {}), beams = storage.jam_beams or 0} end,
  -- Tests only: the late corporation's gate opened as the first rocket launch opens it with Space Age.
  debug_late_gate = function() phases.late(game.surfaces[1], {x = 0, y = 0}) end,
  -- Tests only: one of the player's army, made and registered as a barracks does (its nearest beacon).
  debug_trooper = function(name, pos)
    local u = game.surfaces[1].create_entity{name = name, position = pos, force = "player"}
    if u then
      storage.cmd = storage.cmd or {barracks = {}, beacons = {}, troopers = {}}
      -- The nearest beacon within 100, as a barracks assigns it.
      local best, bd
      for k, bc in pairs(storage.cmd.beacons or {}) do
        if bc.valid then
          local d = (bc.position.x - pos[1]) ^ 2 + (bc.position.y - pos[2]) ^ 2
          if d <= 100 * 100 and (not bd or d < bd) then best, bd = k, d end
        end
      end
      storage.cmd.troopers[u.unit_number] = {unit = u, beacon = best}
    end
    return u and u.unit_number
  end,
  -- Tests only: the unit numbers of the crews out (a Serenity drone flies on a harrier's body).
  crew_units = function() local out = {} for n in pairs(storage.crew_owner or {}) do out[n] = true end return out end,
  road_stats = function(id) return storage.bases[id] and road.stats(storage.bases[id]) end,
  borders = function() return border.stats() end,
  incidents = function() return storage.incidents or {} end,
  prospect_stats = function(id) return storage.bases[id] and prospect.stats(storage.bases[id]) end,
  cordon_stats = function(id) return storage.bases[id] and cordon.stats(storage.bases[id]) end,
  -- Tests only: one pass of the line cutting what crosses it, now.
  debug_sever = function(id) local b = storage.bases[id]; return b and ops.sever(b) end,
  debug_skim = function(id, pos) local b = storage.bases[id]; return b and skim.debug(b, pos) end,
  skim = function(id) local b = storage.bases[id]; return b and skim.state(b) end,
  -- Tests only: a truce between a corporation and a player force, as the invoice post (ledger.lua) or the trade post sells.
  debug_truce = function(corp, owner, minutes)
    storage.truces = storage.truces or {}
    storage.truces[corp .. "|" .. owner] = game.tick + minutes * 3600
  end,
  debug_bill = function(id, owner, cost) local b = storage.bases[id]; return b and ledger.debug(b, owner, cost) end,
  ledger = function(id) local b = storage.bases[id]; return b and ledger.stats(b) end,
  next_ore = function(id) local b = storage.bases[id]; return b and {at = b.next_ore, targets = b.ore_targets or 0} end,
  crew_stats = function(id) return storage.bases[id] and crew.stats(storage.bases[id]) end,
  breaks = function() return {breaks = storage.pact_breaks or 0, till = storage.pact_suspended_till} end,
  strikes = function() return {fired = storage.strikes_fired or 0, targets = storage.strike_targets or 0} end,
  baits = function() return {called = storage.baits_called or 0, burning = #(storage.baits or {})} end,
  debug_tap = function(id, pos) return storage.bases[id] and tap.debug(storage.bases[id], pos) end,
  tap_state = function(id) return storage.bases[id] and tap.state(storage.bases[id]) end,
  debug_jumper = function(id, pos) return storage.bases[id] and jumper.launch(storage.bases[id], pos) end,
})
