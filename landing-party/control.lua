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
local tune = require("__landing-party__.scripts.tune")
local jammer = require("__landing-party__.scripts.jammer")
local scanner = require("__landing-party__.scripts.scanner")
local roads = require("__landing-party__.scripts.roads")
local pods = require("__landing-party__.scripts.pods")
script.on_event(defines.events.on_cargo_pod_finished_descending, pods.on_landed)
local stance = require("__landing-party__.scripts.stance")
local dev = require("__landing-party__.scripts.dev")
local rd = require("__landing-party__.scripts.rd")
local war = require("__landing-party__.scripts.war")
local pact = require("__landing-party__.scripts.pact")
local flare = require("__landing-party__.scripts.flare")
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
local map = require("__landing-party__.scripts.map")
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
  command.init()
end

script.on_init(init)
script.on_configuration_changed(function() init(); base.heal_lines() end)

script.on_event(defines.events.on_tick, function(e)
  biters.tick(); base.tick(e.tick); faction.tick(e.tick); command.tick(e.tick); phases.tick(e.tick); rd.tick(e.tick); war.tick(e.tick); pact.tick(e.tick); flare.tick(e.tick); jumper.tick(e.tick); tap.tick(e.tick); bait.tick(e.tick); strike.tick(e.tick); marker.tick(e.tick); crew.tick(e.tick); prospect.tick(e.tick); standing.tick(e.tick); border.tick(e.tick); road.tick(e.tick); trade.tick(e.tick); ledger.tick(e.tick); skim.tick(e.tick); map.tick(e.tick); jammer.tick(e.tick); scanner.tick(e.tick); roads.tick(e.tick); pods.tick(e.tick)
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
  "lp-turret", "lp-wall", "lp-radar", "lp-depot", "lp-launchpad", "lp-lamp", "lp-scrap-cannon"})) do
  table.insert(BUILDINGS, {filter = "name", name = n})
end
script.on_event(defines.events.on_entity_damaged, function(e)
  -- Any other force: a rival corporation's fire raises the alarm as the player's does.
  if e.force and e.force ~= e.entity.force then
    ops.provoke(e.entity.force.name, e.force.name, e.cause and e.cause.valid and e.cause or e.entity)
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
  -- Cleared ground (docs/reviews/2026-10-14-biter-country-consult.md): a spawner's death, whoever killed it, is a
  -- corridor for 30 minutes (ops.route lets marches through it).
  if ent.type == "unit-spawner" then ops.cleared(ent.surface, ent.position) end
  -- Grubstake's yard (the skim's, the raids'): what it held spills.
  if ent.type == "container" and shared.is_corp(ent.force.name) then skim.died(ent) end
  local kind = shared.kind_of(ent.name)
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
  -- Lost to biters: the hazard ledger (ops.hazard_clear).
  if shared.is_corp(ent.force.name) and e.force and e.force.name == "enemy" and ent.unit_number then
    local own = storage.owner[ent.unit_number]
    local hb = storage.bases[own and own.base or storage.unit_owner[ent.unit_number] or 0]
    if hb and not hb.fallen then ops.hazard_note(hb, ent.position, ent.type == "unit" or ent.type == "spider-unit") end
  end
  if shared.is_corp(ent.force.name) then
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
        rd.tally(b, e.cause, ent.name)
        if e.force then ops.provoke(b.force, e.force.name, e.cause and e.cause.valid and e.cause or ent.position) end
      end
    else
      base.on_died(ent, e.force and e.force.name)
    end
  elseif e.force and shared.is_corp(e.force.name) and ent.force.name ~= "neutral" and ent.force.name ~= "enemy" then
    -- A player building razed by a corporation, whatever did it, its killer dead or alive: the ladder's clock
    -- (ops.ladder) and the tally (lasers and artillery kept falling on the user's save with the tally still).
    if not shared.is_corp(ent.force.name) then
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
    if t.tap_step ~= nil then storage.tap_step = t.tap_step end
    if t.capture_off ~= nil then storage.capture_off = t.capture_off end
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
    if t.flare_burn ~= nil then storage.flare_burn = t.flare_burn end
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
  -- Tests only: the route planner from a settlement's home to pos (nests and turrets as for a sneaking march).
  debug_route = function(id, to)
    local b = storage.bases[id]
    local r = ops.route(b, {b.origin.x, b.origin.y}, to, {turrets = true, nests = true})
    return {found = r ~= nil, waypoints = r and #r or 0, corridors = #(storage.corridors or {}), last = ops.last_route,
      route = r, from = {b.origin.x, b.origin.y}}
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
  ledger = function(id) local b = storage.bases[id]; return b and ledger.stats(b) end,
  next_ore = function(id) local b = storage.bases[id]; return b and {at = b.next_ore, targets = b.ore_targets or 0} end,
  crew_stats = function(id) return storage.bases[id] and crew.stats(storage.bases[id]) end,
  breaks = function() return {breaks = storage.pact_breaks or 0, till = storage.pact_suspended_till} end,
  strikes = function() return {fired = storage.strikes_fired or 0, targets = storage.strike_targets or 0} end,
  baits = function() return {called = storage.baits_called or 0, burning = #(storage.baits or {})} end,
  debug_tap = function(id, pos) return storage.bases[id] and tap.debug(storage.bases[id], pos) end,
  tap_state = function(id) return storage.bases[id] and tap.state(storage.bases[id]) end,
  debug_jumper = function(id, pos) return storage.bases[id] and jumper.launch(storage.bases[id], pos) end,
  debug_flare = function(id, pos) return storage.bases[id] and flare.debug(storage.bases[id], pos) end,
})
