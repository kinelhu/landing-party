local shared = require("shared")
local base = require("scripts.base")
local site = require("scripts.site")
local rng = require("scripts.rng")
local faction = require("scripts.faction")
local achievements = require("__landing-party__.scripts.achievements")
local command = require("scripts.command")
local cards = require("scripts.cards")
local phases = require("__landing-party__.scripts.phases")
local biters = require("__landing-party__.scripts.biters")
faction.on_trigger = phases.on_launch
local ops = require("__landing-party__.scripts.ops")
local veterancy = require("__landing-party__.scripts.veterancy")
local pool = require("__landing-party__.scripts.pool")
local army = require("__landing-party__.scripts.army")
local watch = require("__landing-party__.scripts.watch")
local tune = require("__landing-party__.scripts.tune")
local jammer = require("__landing-party__.scripts.jammer")
local scanner = require("__landing-party__.scripts.scanner")
local roads = require("__landing-party__.scripts.roads")
local pods = require("__landing-party__.scripts.pods")
local landfx = require("__landing-party__.scripts.landfx")
local burstfx = require("__landing-party__.scripts.burstfx")
script.on_event(defines.events.on_cargo_pod_finished_descending, pods.on_landed)
-- The engine's groups (its answer to artillery) take no railgunner of a corporation's (army.lua).
script.on_event(defines.events.on_unit_added_to_group, army.on_unit_added_to_group)
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
local road = require("__landing-party__.scripts.road")
local ledger = require("__landing-party__.scripts.ledger")
local skim = require("__landing-party__.scripts.skim")
local prowl = require("__landing-party__.scripts.prowl")
local dome = require("__landing-party__.scripts.dome")
local lights = require("__landing-party__.scripts.lights")
local studies = require("__landing-party__.scripts.studies")
local orbital = require("__landing-party__.scripts.orbital")
local belts = require("__landing-party__.scripts.belts")
local scorcher = require("__landing-party__.scripts.scorcher")
local stun = require("__landing-party__.scripts.stun")
local fall = require("__landing-party__.scripts.fall")
local lifeline = require("__landing-party__.scripts.lifeline")
local separate = require("__landing-party__.scripts.separate")
local cannon = require("__landing-party__.scripts.cannon")
local ram = require("__landing-party__.scripts.ram")
local map = require("__landing-party__.scripts.map")
local aim = require("__landing-party__.scripts.aim")
local herd = require("__landing-party__.scripts.herd")
local firemap = require("__landing-party__.scripts.firemap")
local threat = require("__landing-party__.scripts.threat")
local valuemap = require("__landing-party__.scripts.valuemap")
local director = require("__landing-party__.scripts.director")
director.base = base  -- (its departures: base.depart; required here, not at runtime)
local director_gui = require("__landing-party__.scripts.director_gui")
local squadgui = require("__landing-party__.scripts.squadgui")
local paving = require("__landing-party__.scripts.paving")
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
-- The engine's paths asked by script (prowl.lua: its ring's legs).
script.on_event(defines.events.on_script_path_request_finished, function(e) prowl.on_path(e) end)
script.on_event(defines.events.on_ai_command_completed, function(e)
  herd.on_command_completed(e)
  prowl.on_command_completed(e)
end)
script.on_event(defines.events.on_entity_spawned, farm.on_spawned)
script.on_event(defines.events.on_script_trigger_effect, function(e)
  if e.effect_id == "lp-army-shot" then return command.on_shot(e) end
  if e.effect_id:sub(1, 7) == "lp-hit:" then return command.on_hit(e) end
  aim.on_trigger(e); studies.on_trigger(e); burstfx.on_trigger(e)
end)
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
  for _, f in pairs(game.forces) do command.sync_tiers(f) end
end

script.on_init(init)
-- (A tier's order once its base order and its round are both researched, 0.2.470.)
script.on_event({defines.events.on_research_finished, defines.events.on_research_reversed},
  function(e) command.sync_tiers(e.research.force) end)
-- (A reset re-applies the technologies' effects and drops what a script enabled.)
script.on_event(defines.events.on_technology_effects_reset, function(e) command.sync_tiers(e.force) end)
script.on_configuration_changed(function() init(); base.heal_lines(); base.heal_labs(); cell.refloor(); command.drop_musters() end)

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
  -- (First: a promotion swaps a unit before any module walks its lists this tick.)
  veterancy.tick(e.tick)
  biters.tick(); base.tick(e.tick); faction.tick(e.tick); command.tick(e.tick); cards.tick(e.tick); phases.tick(e.tick); rd.tick(e.tick); war.tick(e.tick); pact.tick(e.tick); jumper.tick(e.tick); tap.tick(e.tick); bait.tick(e.tick); strike.tick(e.tick); marker.tick(e.tick); crew.tick(e.tick); prospect.tick(e.tick); standing.tick(e.tick); road.tick(e.tick); ledger.tick(e.tick); skim.tick(e.tick); prowl.tick(e.tick); dome.tick(e.tick); dome.player_tick(e.tick); orbital.tick(e.tick); map.tick(e.tick); jammer.tick(e.tick); scanner.tick(e.tick); roads.tick(e.tick); pods.tick(e.tick); landfx.tick(e.tick); burstfx.tick(e.tick); belts.tick(e.tick); scorcher.tick(e.tick); stun.tick(e.tick); fall.tick(e.tick); separate.tick(e.tick); ram.tick(e.tick); ram.charge_tick(e.tick); cannon.tick(e.tick); herd.tick(e.tick); farm.tick(e.tick); creep.tick(e.tick); know.tick(e.tick); director.tick(e.tick); director_gui.tick(e.tick); lifeline.tick(e.tick)
  if e.tick % 60 == 40 then squadgui.tick() end
  paving.tick()
  oplog.tick(e.tick)
  watch.tick(e.tick, WATCH_DEPS)
end)

-- A tile laid or taken up: the road router reads that chunk again (scripts/paving.lua).
script.on_event({defines.events.on_player_built_tile, defines.events.on_robot_built_tile,
  defines.events.on_player_mined_tile, defines.events.on_robot_mined_tile, defines.events.script_raised_set_tiles,
  defines.events.on_space_platform_built_tile, defines.events.on_space_platform_mined_tile}, paving.forget)

local PLAYER_BUILT = {{filter = "name", name = "lp-barracks"}, {filter = "name", name = "lp-rally-beacon"},
  {filter = "name", name = "lp-command-relay"}, {filter = "name", name = "lp-supply-depot"},
  {filter = "name", name = "lp-player-dome"}}
-- The player's poles too: one built by a corporation's pylon is not wired to it (base.unwire).
local BUILT = {{filter = "type", type = "electric-pole"}, {filter = "name", name = "lp-player-bait"},
  {filter = "name", name = "lp-strike-beacon"}, {filter = "name", name = "lp-pact-breaker"},
  {filter = "name", name = "lp-claim-marker"}, {filter = "name", name = "lp-threat-scanner"}}
for _, f in ipairs(PLAYER_BUILT) do table.insert(BUILT, f) end
-- What a player builds inside Serenity's territory provokes it (ops.encroached).
for _, t in ipairs(ops.ENCROACH_TYPES) do table.insert(BUILT, {filter = "type", type = t}) end
local function on_built(e)
  local ent = e.entity
  ops.encroached(ent)
  if ent and ent.valid and ent.name == "lp-player-bait" then
    if studies.has(ent.force, "lp-bait-made") then marker.as_breaker(ent) end
    return bait.placed(ent)
  end
  if ent and ent.valid and ent.name == "lp-strike-beacon" then return strike.placed(ent) end
  if ent and ent.valid and (ent.name == "lp-pact-breaker" or ent.name == "lp-claim-marker") then return marker.placed(ent) end
  if ent and ent.valid and ent.name == "lp-threat-scanner" then return scanner.placed(ent) end
  if ent and ent.valid and ent.name == "lp-player-dome" then return dome.player_built(ent) end
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
-- Every other building of the corporations' (read from the prototypes: the list above, typed early, missed the gates,
-- mortars, flamers, Teslas, the uplink, howitzers, belts, mines and lamps added after it, and a hit on one raised no
-- alarm; the user, 2026-11-17). Named lp-, with an owner, not a unit or a vehicle; the player's own pass the handler's
-- corporation check and return.
do
  local listed, mobile = {}, {unit = true, ["spider-unit"] = true, car = true, ["spider-vehicle"] = true, character = true,
    ["combat-robot"] = true, ["construction-robot"] = true, ["logistic-robot"] = true, ["spider-leg"] = true}
  for _, f in ipairs(BUILDINGS) do if f.name then listed[f.name] = true end end
  for name, p in pairs(prototypes.entity) do
    if name:sub(1, 3) == "lp-" and not listed[name] and p.is_entity_with_owner and not mobile[p.type] then
      table.insert(BUILDINGS, {filter = "name", name = name})
    end
  end
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
-- Shelling (command.on_shelled): explosions on walls, gates, turrets and radars, a squad on D answers the gun. (Every
-- explosion on these: the player's artillery on a corporation's walls too, turned away by force at once.)
local SHELLED = {wall = true, gate = true, ["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true,
  ["artillery-turret"] = true, radar = true}
for t in pairs(SHELLED) do
  table.insert(BUILDINGS, {filter = "type", type = t})
  table.insert(BUILDINGS, {filter = "damage-type", type = "explosion", mode = "and"})
end
-- Units and walls, electric hits only ("and" binds before "or"): the lightning's stun on units (stun.lua), and a Tesla's
-- aim at a laser in its reach whatever its bolt struck (scorcher.aim: on what holds a charge alone, it never turned in a
-- run where its bolts went into troopers and the wall). (A unit's other hits stay unseen: every bullet on a biter.)
for _, t in ipairs({"unit", "wall"}) do
  table.insert(BUILDINGS, {filter = "type", type = t})
  table.insert(BUILDINGS, {filter = "damage-type", type = "electric", mode = "and"})
end
-- The player's own units, every hit: a selected one's bar moves on the hit (scripts/cards.lua), not up to a refresh later.
for _, name in pairs(shared.ORDERS) do table.insert(BUILDINGS, {filter = "name", name = name}) end
script.on_event(defines.events.on_entity_damaged, function(e)
  local et = e.entity.type
  if e.damage_type and e.damage_type.name == "explosion" and e.cause and SHELLED[et] then command.on_shelled(e) end
  if et == "unit" and e.entity.force.name == "player" then cards.on_hit(e.entity) end
  if et == "unit" or et == "wall" then
    if e.damage_type and e.damage_type.name == "electric" then
      if et == "unit" then stun.on_hit(e) end
      if e.cause and e.cause.valid and shared.kind_of(e.cause.name) == "lp-tesla" then scorcher.aim(e.cause, e.entity) end
    end
    -- (Units came through for these alone: the rest of a unit's hits belong to the handlers below only for the probe's
    -- runts, filtered by name; returning for every unit blinded Synthexis's probe to the turrets, herd probe, 0.2.249.)
    if et == "unit" and e.entity.name ~= "lp-runt" then return end
  end
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
    base.on_damaged(e.entity, e.cause)
  end
end, BUILDINGS)

-- A flier shot down falls (fall.lua): its wreck, left by its death, taken up again to fall.
script.on_event(defines.events.on_post_entity_died, function(e) fall.on_post_died(e) end, {{filter = "type", type = "unit"}})

-- The command tool: select (drag), release (shift-drag), order (right-click or right-drag; shift: attack-move).
local TOOL = "lp-command-tool"
-- The orbital remote (scripts/cannon.lua): a click or a drag, its middle the strike's point.
local function remote_fire(e)
  local p = game.get_player(e.player_index)
  local a = e.area
  cannon.fire(p.force, e.surface, {x = (a.left_top.x + a.right_bottom.x) / 2, y = (a.left_top.y + a.right_bottom.y) / 2}, p)
end
script.on_event(defines.events.on_player_selected_area, function(e)
  if e.item == TOOL then command.select(e.player_index, e.entities); cards.refresh(e.player_index) end
  if e.item == "lp-orbital-remote" then remote_fire(e) end
end)
script.on_event(defines.events.on_player_alt_selected_area, function(e)
  if e.item == TOOL then command.release(e.player_index, e.entities); cards.refresh(e.player_index) end
  if e.item == "lp-orbital-remote" then remote_fire(e) end
end)
script.on_event(defines.events.on_player_reverse_selected_area, function(e)
  if e.item == TOOL then command.order(e.player_index, e.surface, e.area, false, squadgui.set_size) end
end)
script.on_event(defines.events.on_player_alt_reverse_selected_area, function(e)
  if e.item == TOOL then command.order(e.player_index, e.surface, e.area, true) end
end)
-- Retiring the selection: the key, or the army panel's button (scripts/command.lua).
-- Retiring loses the units: the first press arms it (told at the cursor), the second within 3 s retires (command.retire).
local function retire(index)
  local done = command.retire(index)
  local p = game.get_player(index)
  if done == 0 and command.retire_armed(index) and p then
    local n = 0
    for k in pairs((storage.cmd.selected or {})[index] or {}) do if storage.cmd.troopers[k] then n = n + 1 end end
    p.create_local_flying_text{text = {"lp.army-retire-armed", n}, create_at_cursor = true, time_to_live = 120}
  end
  command.gui_tick()
end
script.on_event("lp-retire", function(e) retire(e.player_index) end)
script.on_event(defines.events.on_gui_click, function(e)
  if e.element and e.element.valid and e.element.name == "lp_army_retire" then retire(e.player_index) end
  if cards.on_click(e) then command.gui_tick() end
  director_gui.on_click(e)
  squadgui.on_click(e)
  if e.element and e.element.valid and (e.element.name == "lp_army_all" or e.element.name == "lp_army_idle") then
    cards.select_army(e.player_index, e.element.name == "lp_army_idle"); cards.refresh(e.player_index); command.gui_tick()
  end
end)
-- Which units are whose (scripts/squadgui.lua): hover links, and the squad panel beside a rally beacon's window.
script.on_event(defines.events.on_selected_entity_changed, function(e)
  squadgui.on_selected(e)
  local p = game.get_player(e.player_index)
  if p then command.on_hover(p) end
end)
script.on_event(defines.events.on_gui_opened, function(e) squadgui.on_opened(e) end)
-- The selection's cards and control groups (scripts/cards.lua).
cards.on_select = function(pi) command.rings(pi) end
cards.ammo_of = command.ammo_of
cards.round_of = command.round_of
cards.round_factor = function(unit, item)
  local lad = command.ladder(unit)
  return lad and lad.factor[item] or 1
end
for n = 1, cards.GROUPS do
  script.on_event("lp-group-keep-" .. n, function(e)
    local k = cards.keep_group(e.player_index, n)
    local p = game.get_player(e.player_index)
    if p and k > 0 then p.create_local_flying_text{text = {"lp.group-kept", n, k}, create_at_cursor = true} end
  end)
  script.on_event("lp-group-" .. n, function(e)
    if cards.recall_group(e.player_index, n, e.tick) > 0 then cards.refresh(e.player_index); command.gui_tick() end
  end)
end
script.on_event({defines.events.on_player_display_resolution_changed, defines.events.on_player_display_scale_changed},
  function(e) cards.on_display_changed(e) end)

-- Deaths: the faction's buildings are queued for rebuild, its units counted lost, and what its units
-- destroy is counted razed (attributed through the unit that did it).
script.on_event(defines.events.on_entity_died, function(e)
  local ent = e.entity
  -- (A unit of a corporation's killed by a gun of the player's: the director's grudge, a strike force's retaliation.)
  if ent.valid and ent.type == "unit" and e.cause and e.cause.valid and ent.force.name:sub(1, 3) == "lp-" then
    director.note_unit_loss(ent.force.name, e.cause)
  end
  -- (The minute's losses by force and kind, for the event stream: shared.event, director.tick.)
  if storage.trace and ent.valid and ent.force.name ~= "neutral" then
    storage.ev_minute = storage.ev_minute or {}
    local f = ent.force.name
    local k = f .. ":" .. (ent.type == "unit" and "unit" or "building")
    storage.ev_minute[k] = (storage.ev_minute[k] or 0) + 1
    -- (Buildings by the force that killed them, "player:by:enemy": who razed in a lull, the corporations held or the
    -- map's biters; fun_report's truce losses.)
    -- (Units too, by what killed them: a strike force breaking before its first hit, railbase_end 0.2.417.)
    if ent.type == "unit" and f:sub(1, 3) == "lp-" then
      local c = f .. ":unit-cause:" .. (e.cause and e.cause.valid and e.cause.name or (e.force and e.force.name) or "none")
      storage.ev_minute[c] = (storage.ev_minute[c] or 0) + 1
    end
    if ent.type ~= "unit" then
      local by = f .. ":by:" .. (e.force and e.force.name or "none")
      storage.ev_minute[by] = (storage.ev_minute[by] or 0) + 1
      -- (And by what: the killer's entity, "player:cause:fire-flame".)
      local cause = f .. ":cause:" .. (e.cause and e.cause.valid and e.cause.name or "none")
      storage.ev_minute[cause] = (storage.ev_minute[cause] or 0) + 1
    end
  end
  fall.skip(e)
  -- What the factions know: every loss of theirs, by whom (scripts/know.lua).
  know.loss(e)
  -- Merit for the killer (veterancy.lua).
  veterancy.on_died(e)
  studies.on_died(e)
  biters.on_died(e)
  herd.on_died(e)
  burstfx.on_died(e)
  if ent.name == "lp-pen" then farm.on_pen_died(e) end
  oplog.on_died(e)
  -- Cleared ground (docs/reviews/2026-10-14-biter-country-consult.md): a spawner's death, whoever killed it, is a
  -- corridor for 30 minutes (ops.route lets marches through it).
  if ent.type == "unit-spawner" then ops.cleared(ent.surface, ent.position); ledger.nest_died(ent, e.force) end
  -- Grubstake's yard (the skim's, the raids'): what it held spills.
  if ent.type == "container" and shared.is_corp(ent.force.name) then skim.died(ent) end
  local kind = shared.kind_of(ent.name)
  -- What a corporation's building or unit is made of (the engine's loot) is not left at all: its remnants are (the
  -- user, 2026-11-03: "I don't like the units dropping materials... ok for cosmetic wrecks that may disappear over time,
  -- but not items... it's annoying"; a wreck of its plates and circuits since 2026-10-21).
  -- Its own items stay, in a wreck (the components research reads, a cluster fuze from a mortar: mechanic items, as the
  -- command core; cleared with the materials, fuze failed "a mortar drops a fuze", the regression after 0.2.182).
  if shared.is_corp(ent.force.name) and e.loot and not e.loot.is_empty() then
    local keep = {}
    for i = 1, #e.loot do
      local st = e.loot[i]
      if st.valid_for_read and st.name:sub(1, 3) == "lp-" then
        keep[#keep + 1] = {name = st.name, count = st.count, quality = st.quality.name}
      end
    end
    e.loot.clear()
    if #keep > 0 then shared.wreck(ent.surface, ent.position, keep) end
  end
  if kind == "lp-uplink" then faction.uplink_lost(ent); achievements.uplink(ent, e.force) end
  if kind == "lp-radar" then phases.on_died(ent) end
  if kind == "lp-pacifier" then pact.lost(ent) end
  -- Command cores from the wreckage: a depot gives one, a lander three.
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
      -- (Or still being assembled where its pod came down: siege.lua's deploy.)
      local kit = false
      for _, m in pairs(o.op and o.op.kits or {}) do if m == ent then kit = true end end
      if o.parked == ent or home_run or kit or o.op and (o.op.howitzer == ent or o.op.hauler == ent
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
        -- A siege's losses: what killed them, how far from the site and in which phase (diagnostic, first ten an
        -- operation; a clearance's first, every siege's since 0.2.155), and by kind of killer (op.killers).
        if b.op and b.op.kind == "siege" and b.op.site then
          local killer = e.cause and e.cause.valid and e.cause.name or "?"
          b.op.killers = b.op.killers or {}
          b.op.killers[killer] = (b.op.killers[killer] or 0) + 1
          if (b.op.deaths_traced or 0) < 10 then
            b.op.deaths_traced = (b.op.deaths_traced or 0) + 1
            base.trace(b, string.format("%s: %s killed by %s at %.0f tiles from the site (%s)", b.op.clearance and "clearance" or "siege",
              shared.kind_of(ent.name), killer, math.sqrt((ent.position.x - b.op.site[1]) ^ 2 + (ent.position.y - b.op.site[2]) ^ 2),
              b.op.phase or "?"))
          end
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
      director.note_loss(ent.force.name, ent, e.cause, e.force.name)
      local corp = standing.corp_of_force(e.force.name)
      if corp then standing.incident(corp, "razed", ent.position, ent.name) end
    end
    -- Razed counts the player's structures only (trees felled by shells once inflated it by half).
    local id = e.cause and e.cause.valid and storage.unit_owner[e.cause.unit_number]
    local b = id and storage.bases[id]
    -- (Or its lander, the cause of its orbital strike's shells: orbital.lua.)
    if not b and e.cause and e.cause.valid and e.cause.type ~= "unit" then
      for _, o in pairs(storage.bases) do if o.lander == e.cause then b = o; break end end
    end
    if b then
      b.razed = b.razed + 1
      b.razed_at = e.tick
      b.fail_streak = 0
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
  -- Tests: a rocket launch at a point (faction.on_launch reads the silo's surface and position only).
  debug_launch = function(x, y) faction.on_launch({surface = game.surfaces[1], position = {x = x, y = y}, valid = true}) end,
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
    for _, k in ipairs({"blast_off", "landfill_off", "pier_off", "air_trace", "air_straight", "dismantle_off", "vet_off", "vet_trace", "rewire_off"}) do if t[k] ~= nil then storage[k] = t[k] or nil end end
    if t.grow_to_line_off ~= nil then storage.grow_to_line_off = t.grow_to_line_off or nil end
    if t.wfc_core_off ~= nil then storage.wfc_core_off = t.wfc_core_off or nil end
    if t.cordon_off ~= nil then storage.cordon_off = t.cordon_off or nil end
    if t.labs_off ~= nil then storage.labs_off = t.labs_off or nil end
    if t.belts_always ~= nil then storage.belts_always = t.belts_always or nil end
    -- The arena (tests/lp-arena): a surface with no camp whose Scorchers still burn.
    if t.arena_surface then storage.arena_surfaces = storage.arena_surfaces or {}; storage.arena_surfaces[t.arena_surface] = true end
    if t.tap_step ~= nil then storage.tap_step = t.tap_step end
    if t.biotech_unlearned ~= nil then storage.biotech_unlearned = t.biotech_unlearned or nil end
    if t.biotech_no_orders ~= nil then storage.biotech_no_orders = t.biotech_no_orders or nil end
    -- march_trace: each marching herd's group every second to the log (where, its state, its order; debugging).
    if t.march_trace ~= nil then storage.march_trace = t.march_trace or nil end
    if t.biotech_no_hold ~= nil then storage.biotech_no_hold = t.biotech_no_hold or nil end
    -- biotech_no_ranks: a siege's rams all at once, as before 0.2.212 (herd.lua: herd.rk; the ranks test's control).
    if t.biotech_no_ranks ~= nil then storage.biotech_no_ranks = t.biotech_no_ranks or nil end
    -- biotech_slow_rams: its rams looked at once a second, as before 0.2.213 (herd.lua: herd.rk.look_every; its check's control).
    if t.biotech_slow_rams ~= nil then storage.biotech_slow_rams = t.biotech_slow_rams or nil end
    -- biotech_rank_doubles: a rank killed short doubles the next, as before 0.2.213 (herd.rk.size_next; its check's control).
    if t.biotech_rank_doubles ~= nil then storage.biotech_rank_doubles = t.biotech_rank_doubles or nil end
    -- biotech_no_muster: a rank's rams sent from where each was held, as before 0.2.213 (herd.rk.muster_point; its check's control).
    if t.biotech_no_muster ~= nil then storage.biotech_no_muster = t.biotech_no_muster or nil end
    -- biotech_no_gun_rank: its herd through its open gap with its rams still held, as before 0.2.213 (herd.rk.gun_rank).
    if t.biotech_no_gun_rank ~= nil then storage.biotech_no_gun_rank = t.biotech_no_gun_rank or nil end
    -- biotech_no_keep_line: its rush left to the engine's path past a mended piece of its gap, as before 0.2.215
    -- (herd.rk.keep_line; its check's control).
    if t.biotech_no_keep_line ~= nil then storage.biotech_no_keep_line = t.biotech_no_keep_line or nil end
    -- biotech_no_herd_through: its rush through when its group's order is done, however much of it is outside, as before
    -- 0.2.216 (herd.rk.hold_rush; its check's control).
    if t.biotech_no_herd_through ~= nil then storage.biotech_no_herd_through = t.biotech_no_herd_through or nil end
    -- biotech_through_rank: its rush through once no more than a rank of it is outside, as before 0.2.354, not by whether
    -- those outside are coming (herd.rk.hold_rush; the control).
    if t.biotech_through_rank ~= nil then storage.biotech_through_rank = t.biotech_through_rank or nil end
    -- old_stock: Synthexis's army bred by the engine and standing at its incubators, as before 0.2.90 (farm.lua hatching).
    if t.old_stock ~= nil then storage.biotech_old_stock = t.old_stock or nil end
    if t.prospect_window ~= nil then storage.prospect_window = t.prospect_window end
    if t.prospect_pace ~= nil then storage.prospect_pace = t.prospect_pace end
    if t.prospect_uncharted ~= nil then storage.prospect_uncharted = t.prospect_uncharted end
    if t.prospect_radius ~= nil then storage.prospect_radius = t.prospect_radius end
    if t.prospect_home ~= nil then storage.prospect_home = t.prospect_home end
    if t.road_haul ~= nil then storage.road_haul = t.road_haul end
    if t.road_lapse ~= nil then storage.road_lapse = t.road_lapse end
    -- tesla_off: the Tesla's lightning does nothing to what holds a charge (scorcher.lua; the teslawall checks' control).
    if t.tesla_off ~= nil then storage.tesla_off = t.tesla_off or nil end
    if t.army_off ~= nil then storage.army_off = t.army_off end
    if t.yard_off ~= nil then storage.yard_off = t.yard_off end
    if t.raids_off ~= nil then storage.raids_off = t.raids_off end
    if t.ops_off ~= nil then storage.ops_off = t.ops_off end
    if t.phases_fast ~= nil then storage.phases_fast = t.phases_fast end
    -- (false clears it: the era read from the player's research, ops.era.)
    if t.era ~= nil then storage.era_override = t.era or nil end
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
    if t.landfx_off ~= nil then storage.landfx_off = t.landfx_off end
    if t.strangle_off ~= nil then storage.strangle_off = t.strangle_off end
    if t.next_ore_off ~= nil then storage.next_ore_off = t.next_ore_off end
    if t.sever_off ~= nil then storage.sever_off = t.sever_off end
    if t.hazard_off ~= nil then storage.hazard_off = t.hazard_off end
    if t.hazard_hold ~= nil then storage.hazard_hold = t.hazard_hold end
    if t.air_off ~= nil then storage.air_off = t.air_off or nil end
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
    if t.seed_salt ~= nil then storage.seed_salt = t.seed_salt end
    if t.dump_ways ~= nil then storage.dump_ways = t.dump_ways end
    if t.domes_off then storage.domes = false end
    if t.armed ~= nil then storage.armed = t.armed end
    if t.armed_off then storage.armed = false end
    if t.sweeps_off ~= nil then storage.sweeps_off = t.sweeps_off end
    if t.drop_off ~= nil then storage.drop_off = t.drop_off end
    if t.drop_debug ~= nil then storage.drop_debug = t.drop_debug end
    if t.strikes_off ~= nil then storage.strikes_off = t.strikes_off end
    -- A siege's way at a closed wall (assault.lua): its pick forced (walled, wallfire; false: its own), options off by
    -- name ({wallfire = true}).
    if t.kh_way ~= nil then storage.kh_way = t.kh_way or nil end
    if t.kh_tactics_off ~= nil then storage.kh_tactics_off = t.kh_tactics_off or nil end
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
    -- Tests: the berth between camps and farms off (shared.berth; system LP_MIX=berthoff, the check seen failing).
    if t.berth_off ~= nil then storage.berth_off = t.berth_off end
    -- Tests: no lander's stores (base.lua; watchdog economy stalls a camp on purpose).
    if t.stores_off ~= nil then storage.stores_off = t.stores_off end
    -- The director forced on with a personality (no opening, no grace), its priors overridden (shared.DIRECTOR's keys).
    if t.director ~= nil then storage.director_force = t.director or nil end
    if t.director_tune ~= nil then storage.director_tune = t.director_tune end
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
  -- Tests: what a corporation's unit was doing (its settlement's lists): op:<kind>, response, raid, patrol, garrison, other.
  -- The corporation units taken out of the engine's groups (army.on_unit_added_to_group), of them railgunners, and all
  -- the engine grouped.
  debug_ungrouped = function()
    return storage.engine_ungrouped or 0, storage.rails_ungrouped or 0, storage.engine_grouped or 0
  end,
  debug_role = function(u)
    local id = storage.unit_owner and u.unit_number and storage.unit_owner[u.unit_number]
    local b = id and storage.bases[id]
    if not b then return "unowned" end
    local function has(list) for _, x in ipairs(list or {}) do if x == u then return true end end end
    if b.op and (has(b.op.members) or has(b.op.guards)) then return "op:" .. tostring(b.op.kind) end
    for _, r in ipairs(b.raids or {}) do if has(r.members) then return r.kind or "raid" end end
    if has(b.patrol) then return "patrol" end
    if b.prowl and b.prowl.unit == u then return "prowl" end
    if has(b.garrison) then return "garrison" end
    return "other"
  end,
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
  -- Tests only: the share its attempts at a place lost to area damage (tactics.area_share), and a spread's option there
  -- beside its siege's as its menu weighs them (farm.lua spread_op).
  debug_area_share = function(faction, foe, pos, methods) return tactics.area_share(faction, foe, pos, methods, nil, nil) end,
  debug_spread_op = function(sg) return farm.debug_spread_op(sg) end,
  -- Tests only: its plan from `from` at `target` for a wave of n (herd.plan), nil where it reads no way.
  debug_plan = function(surface_index, from, target, n)
    return herd.plan(game.surfaces[surface_index], from, target, {"player"}, n or shared.WAVE_MIN)
  end,
  -- Tests only: a spread's points (herd.spread_points), at most `most`, on the maps of a plan of its farm's kind from `from`
  -- at `target`, its breach and start those given (the test's wall, not where the plan would go round it).
  debug_spread_points = function(surface_index, from, target, most, breach, start)
    local s = game.surfaces[surface_index]
    local pl = herd.plan(s, from, target, {"player"}, shared.WAVE_MAX)
    if not pl then return nil end
    if breach then pl.breach, pl.start, pl.cost = breach, start, math.huge end
    local pts = herd.spread_points(s, pl, {"player"}, most)
    if not pts then return {breach = pl.breach, start = pl.start} end
    -- (And the flamethrowers covering each, for the test: herd.spread_points takes none covering two.)
    local map = firemap.read(s, pl.breach, 120, {"player"}, nil)
    local out = {breach = pl.breach, start = pl.start, points = {}}
    for _, q in ipairs(pts) do
      local burn = {}
      for _, t in ipairs(firemap.entries(map, q)) do if t.burn then burn[#burn + 1] = t.e.unit_number end end
      out.points[#out.points + 1] = {q.x, q.y, burn = burn, cover = q.cover}
    end
    return out
  end,
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
  -- Tests and the siege lab: a settlement's random source drawn anew (a corporation's replicates of one save).
  debug_reseed_base = function(id, seed)
    local b = storage.bases[id]
    if b then b.rng = rng.new(seed) end
    return b ~= nil
  end,
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
  -- Tests only: the size of a siege's next rank after one of `size` killed short, from its reading (herd.rk.size_next).
  debug_rank_size = function(size, read) return herd.rk.size_next({rank_size = size, rank_n = 1, rank_read = {read}}) end,
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
  -- Tests: how many places Synthexis keeps a lesson of (herd.lua's lessons; its learning lever).
  herd_lessons = function()
    local n = 0
    for _ in pairs(know.of("biotech").lessons or {}) do n = n + 1 end
    return n
  end,
  -- Tests only: a faction's losses within `window` ticks, what each died of and to whom (know.loss).
  debug_losses = function(key, window)
    local out = {}
    for _, l in ipairs(know.losses(key, window)) do out[#out + 1] = {damage = l.damage, killer = l.killer, kind = l.kind, unit = l.unit} end
    return out
  end,
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
  debug_strikes = function(id) local b = storage.bases[id]; return b and {called = b.strikes or 0, shells = b.strike_shells or 0,
    off = b.strikes_off_called or 0, guns = b.strike_guns or 0} end,
  debug_modules = function(id, pos, r) return base.debug_modules(storage.bases[id], pos, r) end,
  -- Tests and showcases only: parts for a settlement (a young one has no surplus to export).
  -- Tests only: the command tool without a mouse (player index 1 need not exist).
  debug_select_units = function(units, pi) return command.select(pi or 1, units) end,
  debug_select = function(area)
    local s = game.surfaces[1]
    return command.select(1, s.find_entities_filtered{area = area, force = "player", type = "unit"})
  end,
  debug_release_units = function(units) return command.release(1, units) end,
  debug_release = function(area)
    return command.release(1, game.surfaces[1].find_entities_filtered{area = area, force = "player", type = "unit"})
  end,
  debug_order = function(area, attackmove) return command.order(1, game.surfaces[1], area, attackmove, squadgui.set_size) end,
  debug_retire = function(now) return command.retire(1, now) end,
  -- Tests only: the migration a save from before 0.2.448 gets on loading (muster points off the map).
  debug_drop_musters = function() return command.drop_musters() end,
  -- Tests only: which settlement an entity belongs to, and where it stands.
  debug_owner = function(e)
    local o = e.valid and e.unit_number and storage.owner[e.unit_number]
    local b = o and storage.bases[o.base]
    return o and {base = o.base, fallen = b and b.fallen ~= nil, origin = b and b.origin, module = o.module} or nil
  end,
  -- Tests only: how many generators a lander's hover points to (squadgui.hull_gens).
  debug_hull_gens = function(lander) return #squadgui.hull_gens(lander) end,
  -- Tests only: the squad panel's buttons (scripts/squadgui.lua), and what a beacon shows, in plain values.
  debug_squad_size = function(beacon, unit, n) return squadgui.set_size(beacon, unit, n) end,
  -- Tests only: an order with all it returns (a right-click on a beacon: units assigned, "assign", units held).
  debug_order_detail = function(area, attackmove)
    local n, kind, held = command.order(1, game.surfaces[1], area, attackmove, squadgui.set_size)
    return {n = n, kind = kind, held = held}
  end,
  -- Tests only: the road router (scripts/paving.lua): a search, its result, and per-tick timings to script-output.
  debug_paving_request = function(from, to) return paving.request(game.surfaces[1], from, to) end,
  debug_paving_result = function(id) return paving.result(id) end,
  debug_routes = function()
    local out = {}
    for key, list in pairs(storage.cmd.routes or {}) do
      for _, r in ipairs(list) do
        local pts = {}
        for _, q in ipairs(r.path or {}) do pts[#pts + 1] = string.format("%.0f,%.0f", q.x, q.y) end
        out[#out + 1] = {key = key, from = string.format("%.0f,%.0f", r.from.x, r.from.y), path = r.path == false and "none" or table.concat(pts, " ")}
      end
    end
    return out
  end,
  debug_paving_prof = function(on) storage.paving_prof = on; return paving.stats() end,
  -- Tests only: a unit's ammunition (rounds, its loadout's, dry, where it rearms).
  -- The arena only: a unit fighting unregistered given a round (ammunition tiers, LP_ARENA_TIER).
  -- The arena and tests only: the tier power in force (an override of shared.TIER_EXP, or nil to read it).
  debug_tier_exp = function(x)
    if x then storage.cmd.tier_exp = x end
    return storage.cmd.tier_exp or shared.TIER_EXP
  end,
  -- Tests only: a unit's ladder, best round first (ammunition tiers).
  debug_ammo_ladder = function(name)
    local lad = command.ladder(name)
    if not lad then return nil end
    local out = {}
    for _, it in ipairs(lad.best) do out[#out + 1] = it.name end
    return out
  end,
  debug_tier_raw = function(item) return shared.TIER_RAW[item] end,
  -- The arena only: a corporation's damage tracks at their top (rd.max_tracks).
  debug_rd_max = function(corp) return rd.max_tracks(corp) end,
  debug_tier = function(u, round)
    storage.cmd.tier_test = storage.cmd.tier_test or {}
    storage.cmd.tier_test[u.unit_number] = round
  end,
  debug_ammo = function(u)
    local t = storage.cmd.troopers[u.unit_number]
    if not t then return nil end
    local a, full = command.ammo_of(t)
    return {ammo = a, full = full, dry = t.dry == true, key = t.key, fired = t.fired or 0, alerted = t.alerted == true,
      round = command.round_of(t), shown = t.round_mark and t.round_mark.valid and t.round_shown or nil}
  end,
  -- Tests only: a beacon's squad's ammunition, as its panel shows it (0.2.465).
  debug_beacon_ammo = function(b) return command.beacon_view(b).ammo end,
  -- Tests only: a unit's beacon and hand order.
  debug_trooper_state = function(u)
    local t = storage.cmd.troopers[u.unit_number]
    return t and {beacon = t.beacon, manual = t.manual and t.manual.kind, join = t.manual and t.manual.join, key = t.key}
  end,
  debug_beacon_view = function(beacon)
    local v = command.beacon_view(beacon)
    return {stance = v.stance, answering = v.answering, count = v.count, caps = v.caps, n = #v.units}
  end,
  -- The selection's cards (scripts/cards.lua), headless: the model in plain numbers, the bars' shares, groups, picks.
  debug_cards = function()
    local m = cards.refresh(1)
    local out = {n = m.n, grouped = m.grouped, cards = {}, bars = 0, single = m.single and {name = m.single.unit.name,
      rank = m.single.rank, order = m.single.order} or nil}
    for _, c in ipairs(m.cards) do
      out.cards[#out.cards + 1] = {kind = c.kind, name = c.name, count = c.count, share = c.share, rank = c.rank,
        unit_number = c.unit_number, round = c.round, by_round = c.by_round}
    end
    local bars = storage.cards and storage.cards.bars and storage.cards.bars[1] or {}
    out.bar_share = {}
    for un, b in pairs(bars) do
      if b.bg.valid and b.fg.valid then out.bars = out.bars + 1; out.bar_share[un] = b.share end
    end
    return out
  end,
  debug_enlist = function(area)
    local n = 0
    for _, u in ipairs(game.surfaces[1].find_entities_filtered{area = area, force = "player", type = "unit"}) do
      command.enlist(u); n = n + 1
    end
    return n
  end,
  debug_group_keep = function(n) return cards.keep_group(1, n) end,
  -- (A player index, the multiplayer run's second client: scripts/mp.sh LP_ARMY=1; 1 otherwise.)
  debug_select_army = function(idle, pi) return cards.select_army(pi or 1, idle) end,
  -- (The windowed checks, tests/lp-shots and tests/lp-mp: the rings drawn as hovering the entity draws them; in a game
  -- window the mouse owns the selection, so a script's selected would not last.)
  -- (The windowed checks: n shots spent through the real handler, so a unit runs dry on cue.)
  debug_shots = function(u, n)
    for _ = 1, n do command.on_shot{source_entity = u} end
    return command.ammo_of(storage.cmd.troopers[u.unit_number])
  end,
  debug_hover = function(pi, entity)
    local p = game.get_player(pi)
    if not p then return false end
    command.on_hover(p, entity)
    return true
  end,
  -- Where a unit's order sends it (a formation's slot, or the point clicked).
  -- An older save's pads relaid (cell.refloor, run on configuration changes): the tiles relaid.
  debug_refloor = function() return cell.refloor() end,
  debug_order_pos = function(un)
    local t = storage.cmd.troopers[un]
    return t and t.manual and t.manual.pos
  end,
  debug_bar_share = function(un)
    local b = storage.cards and storage.cards.bars and storage.cards.bars[1] and storage.cards.bars[1][un]
    return b and b.share
  end,
  debug_group_recall = function(n, tick) return cards.recall_group(1, n, tick) end,
  debug_pick = function(key, drop) return cards.pick(1, key, drop) end,
  cannon_readout = function() return cannon.readout(game.forces.player) end,
  cannon_stats = function() return cannon.stats() end,
  -- Tests only: a strike called at pos (as the remote), and why not.
  debug_cannon_fire = function(pos) local n, why = cannon.fire(game.forces.player, game.surfaces.nauvis, {x = pos[1], y = pos[2]}); return {spent = n, why = why} end,
  army_readout = function() return command.readout(game.forces.player) end,
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
  -- Tests only: merit (veterancy.lua) for every unit a settlement owns, or (id "player") the player's army.
  debug_merit = function(id, n)
    storage.merit = storage.merit or {}
    local list = {}
    if id == "player" then
      for _, t in pairs(storage.cmd.troopers) do list[#list + 1] = t.unit end
    else
      for _, u in pairs(pool.roster(storage.bases[id])) do list[#list + 1] = u end
    end
    local k = 0
    for _, u in ipairs(list) do if u.valid then storage.merit[u.unit_number] = n; veterancy.check(u); k = k + 1 end end
    return k
  end,
  -- Tests only: the share a raid of these units turns home below, from `share` (veterancy.abort_share), and the first's
  -- scale.
  debug_abort_share = function(members, share) return {veterancy.abort_share(members, share), veterancy.scale(members[1])} end,
  -- Tests: a kill's merit, the victim's name and the killer's (veterancy.kill_merit).
  kill_merit = function(dead, by) return veterancy.kill_merit(dead, by) end,
  turret_merit = function(dead, force, by) return veterancy.turret_merit(dead, force, by) end,
  -- The event raised as a unit is promoted (veterancy.PROMOTED: {old, new, rank}, before the old one goes): for a mod
  -- that holds our units to put the copy where it held the old one.
  promoted_event = function() return veterancy.PROMOTED end,
  -- Tests: how the AI's readings weigh these units at their ranks (0.2.355): each one's rank scale, its threat prior (the
  -- corporations' fire maps) and Synthexis's price of it.
  -- Tests: the berth a camp and a farm keep (shared.berth).
  berth = function() return shared.berth_reach() end,
  -- Tests: how many places a landing keeps APART from (landers, failed sites, incubators).
  debug_landing_avoids = function(surface_index) return #faction.landers(game.surfaces[surface_index]) end,
  debug_rank_reads = function(unit_numbers)
    local want, out = {}, {}
    for _, n in ipairs(unit_numbers) do want[n] = true end
    for _, s in pairs(game.surfaces) do
      for _, e in ipairs(s.find_entities_filtered{type = {"unit", "spider-unit"}}) do
        if want[e.unit_number] then
          out[#out + 1] = {unit = e.unit_number, name = e.name, quality = e.quality.name, scale = shared.rank_scale(e),
            prior = threat.prior(e, 6), herd_price = herd.price_of(e)}
        end
      end
    end
    return out
  end,
  -- Tests and films: a unit given this much merit, promoted the next tick if it has earned a rank (veterancy.check).
  debug_promote = function(unit_number, n)
    -- (Searched: get_entity_by_unit_number finds only prototypes flagged get-by-unit-number, never a unit.)
    local u
    for _, s in pairs(game.surfaces) do
      for _, e in ipairs(s.find_entities_filtered{type = {"unit", "spider-unit"}}) do
        if e.unit_number == unit_number then u = e; break end
      end
      if u then break end
    end
    if not (u and u.valid) then return false end
    storage.merit = storage.merit or {}
    storage.merit[unit_number] = n
    veterancy.check(u)
    return true
  end,
  -- A unit's merit banked (veterancy.lua).
  merit = function(unit_number) return storage.merit and storage.merit[unit_number] end,
  -- Veterancy: promotions, the highest merit banked, and each force's units by rank (quality).
  veterancy = function()
    local out = veterancy.stats()
    out.by_force = {}
    for _, f in pairs(game.forces) do
      local q = {}
      for _, u in pairs(game.surfaces[1].find_entities_filtered{type = {"unit", "spider-unit"}, force = f}) do
        if u.name:sub(1, 3) == "lp-" then q[u.quality.name] = (q[u.quality.name] or 0) + 1 end
      end
      if next(q) then out.by_force[f.name] = q end
    end
    -- (And how many of the corporations' ranked units a settlement still owns: a promoted raider came home its own.)
    out.ranked_owned, out.ranked = 0, 0
    for _, u in pairs(game.surfaces[1].find_entities_filtered{type = {"unit", "spider-unit"}}) do
      if u.name:sub(1, 3) == "lp-" and u.quality.level > 0 and shared.is_corp(u.force.name) then
        out.ranked = out.ranked + 1
        if storage.unit_owner and storage.unit_owner[u.unit_number] then out.ranked_owned = out.ranked_owned + 1 end
      end
    end
    return out
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
    return {strength = tune.strength(b.corp), aggression = tune.aggression(b.corp), income = tune.income(b.corp),
      cap = army.cap(b), hour = tune.sooner(b.corp, 3600 * 60), rung = stance.rung("player", b.force), made = b.made,
      lever_in = b.lever_in or 0, lever_out = b.lever_out or 0}
  end,
  debug_parts = function(id, parts) local b = storage.bases[id]; if b then b.parts = b.parts + parts end end,
  -- A town grown at once, for pictures (scripts/shots.sh town): machine lots with their machines queued, then streets.
  debug_town = function(id, machines, streets) local b = storage.bases[id]; return b and layout.debug_town(b, machines, streets) end,
  -- Tests only: a depot beside the lander and parts, so a raid comes in minutes instead of half an hour.
  debug_depot = function(id, parts) return dev.depot(storage.bases[id], parts) end,
  -- The dome's looks on a projector (tests/lp-film): "wave" from an impact at `at`, or "rise"; `radius` its dome's.
  -- The lights its buildings get when the mod builds them (scripts/lights.lua), on one built by other hands (tests/lp-film).
  debug_light = function(ent) lights.attach(ent) end,
  pdome_stats = function() return dome.player_stats() end,
  study_counts = function(force) return studies.counts(force) end,
  debug_dome_fx = function(kind, anchor, radius, at)
    local d = {anchor = anchor, radius = radius}
    if kind == "wave" then dome.wave(d, at) else dome.rise(d) end
  end,
  snapshot = snapshot,
  rd = function(corp) return rd.summary(corp) end,
  debug_needed = function(id, pos) return ops.debug_needed(storage.bases[id], {x = pos[1], y = pos[2]}) end,
  -- Tests: the relevance a camp gives the target it knows nearest pos (sensed there first), as its choice weighs it
  -- against the player: the director's focus in it (scenario director LP_MIX=focus).
  debug_relevance = function(id, pos)
    local b = storage.bases[id]
    if not b then return nil end
    ops.debug_needed(b, {x = pos[1], y = pos[2]})
    local best, bd
    for _, t in pairs(b.intel and b.intel.targets or {}) do
      local d = (t.pos[1] - pos[1]) ^ 2 + (t.pos[2] - pos[2]) ^ 2
      if not bd or d < bd then best, bd = t, d end
    end
    return best and ops.relevance(b, best, {player = true, rung = 0}) or nil
  end,
  -- Tests: the /lp dev tools (scripts/dev.lua) at a position, as a player standing there would use them.
  dev = function(args, pos, surface_index) dev.remote(args, pos, surface_index) end,
  -- Tests and films only: an operation of settlement id forced now at the structure of `owner` (a rival corporation's
  -- force, or nil for the player's) nearest pos (ops.force). Returns nil when launched, else why not.
  debug_force_op = function(id, kind, pos, owner)
    local b = storage.bases[id]
    if not b then return "no settlement " .. tostring(id) end
    return ops.force(b, kind, {x = pos.x or pos[1], y = pos.y or pos[2]}, base.trace, army, owner)
  end,
  -- Tests and films only: an orbital strike of settlement id at pos now (orbital.force). Returns nil, else why not.
  debug_strike = function(id, pos)
    local b = storage.bases[id]
    if not b then return "no settlement " .. tostring(id) end
    return orbital.force(b, {pos.x or pos[1], pos.y or pos[2]})
  end,
  landfx_active = function() return landfx.active() end,
  -- A burst's look (scripts/burstfx.lua): its counts, and a burster set off by hand (a big burster's by herd.set_off).
  burstfx = function() return burstfx.stats() end,
  burst_set_off = function(unit)
    if unit and unit.valid and unit.name == "lp-bred-big-burster" then return herd.set_off(unit) end
    return burstfx.windup(unit)
  end,
  stats = function(id) return storage.bases[id] and base.stats(storage.bases[id]) end,
  achieved = function() return storage.lp_achieved or {} end,
  pact_state = function() return storage.pact_state end,
  director = function() return director.state() end,
  -- Tests and the debug panel: director.cmd (on, off, auto, spree [corp], lull, fill, empty, end).
  director_cmd = function(action, arg) return director.cmd(action, arg) end,
  -- Tests: the faction cues played, by name (shared.cue).
  sound_cues = function() return storage.sound_cues or {} end,
  -- Tests: the orbital strikes' builds made, how each ended (impact, spotter, called off), and those standing.
  orbital_builds = function()
    local left = 0
    for _, s in pairs(game.surfaces) do left = left + s.count_entities_filtered{name = {"lp-orbital-build", "lp-cannon-build"}} end
    return {n = storage.orbital_builds or 0, stopped = storage.orbital_builds_stopped or {}, left = left,
      off = storage.orbital_build_off or {}}
  end,
  -- Films only: the director's panel toggled for a player (/lp director without a console; the manual's still).
  debug_director_panel = function(index)
    local p = game.get_player(index) or game.connected_players[1]
    return p and director_gui.toggle(p) or false
  end,
  director_prior = function(k) return director.tune(k) end,
  -- Tests: what a corporation pays for a unit kind (shared.unit_cost), scenario director targets' pricing check.
  debug_unit_cost = function(corp, kind) return shared.unit_cost(corp, kind) end,
  director_lines = function() return director_gui.lines() end,
  -- Tests and visits: what the director reads of a player force, beside a fuller reading (director.readings).
  debug_readings = function(owner) return director.readings(owner) end,
  -- Tests: the cap on operations against a player at once, as ops reads it (the director's surge raises it).
  ops_budget = function(owner) return ops.budget(owner or "player") end,
  -- Tests: a span as a corporation's pace gives it now (tune.sooner, the director's tempo in it).
  sooner = function(corp, ticks) return tune.sooner(corp, ticks) end,
  notice_counts = function() return storage.notice_counts or {told = 0, held = 0} end,
  debug_notice = function(key) shared.notice(game.forces.player, {key, "test", "test"}) end,
  -- Tests only: one entity of kind `name` placed and registered for settlement `id` as its yard places it (scripts/lp-shots).
  debug_place = function(id, name, pos)
    local b = storage.bases[id]
    local e = b and base.place_job(b, {name = name, pos = pos})
    return e and e.unit_number
  end,
  scorcher_stats = function(unit_number) return scorcher.stats(unit_number) end,
  stun_stats = function() return stun.stats() end,
  stun_since = function(k) return stun.since(k) end,
  fall_stats = function() return fall.stats() end,
  separate_stats = function() return separate.stats() end,
  belt_stats = function(id) return storage.bases[id] and belts.stats(storage.bases[id]) end,
  debug_crew = function(id, pos, names) return storage.bases[id] and crew.debug_module(storage.bases[id], pos, names) end,
  -- Tests only: `danger` as the camp's given-up mines' ground (crew.lua's b.mine_danger).
  debug_mine_danger = function(id, danger) local b = storage.bases[id]; if b then b.mine_danger = danger end end,
  -- Tests only: the mine the planner would pick now with `danger` as the camp's given-up ground (site.mining), its cells
  -- and danger left as they were.
  debug_mine_pick = function(id, danger)
    local b = storage.bases[id]
    if not b then return nil end
    local cells, d0 = {}, b.mine_danger
    for k, v in pairs(b.cells) do cells[k] = v end
    b.mine_danger = danger
    local o = site.mining(game.surfaces[b.surface], b, math.huge, {n = math.huge})
    b.cells, b.mine_danger = cells, d0
    return o and {o[1], o[2]}
  end,
  standing = function(corp, owner) return standing.get(corp, owner or "player") end,
  -- Tests only: a mast of `corp` raised at `pos`, as a siege raises it.
  debug_jammer = function(corp, pos) local m = jammer.raise(game.surfaces[1], pos, game.forces[shared.CORPS[corp].force]); return m and m.unit_number end,
  ram_stats = function() return ram.stats() end,
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
  incidents = function() return storage.incidents or {} end,
  prospect_stats = function(id) return storage.bases[id] and prospect.stats(storage.bases[id]) end,
  cordon_stats = function(id) return storage.bases[id] and cordon.stats(storage.bases[id]) end,
  -- Tests only: one pass of the line cutting what crosses it, now.
  debug_sever = function(id) local b = storage.bases[id]; return b and ops.sever(b) end,
  debug_skim = function(id, pos) local b = storage.bases[id]; return b and skim.debug(b, pos) end,
  skim = function(id) local b = storage.bases[id]; return b and skim.state(b) end,
  -- Tests and films only: a staged hold between a corporation and a player force (stance "truce"); the player buys none
  -- since 0.2.325.
  debug_truce = function(corp, owner, minutes)
    storage.truces = storage.truces or {}
    storage.truces[corp .. "|" .. owner] = game.tick + minutes * 3600
  end,
  debug_bill = function(id, owner, cost) local b = storage.bases[id]; return b and ledger.debug(b, owner, cost) end,
  -- Tests and screenshots: its open bill overdue now, a collection called.
  clear_rails = function(piece) return ops.clear_rails(1, piece) end,
  debug_overdue = function(id) local b = storage.bases[id]; if b and b.ledger then ledger.collect(b, b.ledger) return true end end,
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
