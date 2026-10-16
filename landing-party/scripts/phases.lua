-- The campaign's opening (docs/campaign.md section 3): signs, survey, arrival. Checked once a minute.
--   signs    a player force owns a radar: wreckage of an unknown craft 180 tiles from it, salvage inside
--   survey   oil processing researched: a survey party of the first corporation lands about 450 tiles out on
--            ore (a radar mast, two drills, a lamp, four guards). Destroyed, it drops a command core and the
--            arrival waits DELAY after its trigger; left alone it departs after SURVEY_TICKS and the arrival
--            comes EARLY after that, trigger or not
--   arrival  Space Age: the first rocket launch; base game: the first chemical science pack (a launch ends the
--            vanilla game)
local shared = require("__landing-party__.shared")
local faction = require("__landing-party__.scripts.faction")

local phases = {}

local SIGNS_DISTANCE = 180
local SURVEY_DISTANCE = 450
local SURVEY_TICKS = 60 * 60 * 60
local DELAY = 20 * 60 * 60
local EARLY = 30 * 60 * 60

local function state()
  storage.phases = storage.phases or {}
  return storage.phases
end

local function players()
  local out = {}
  for _, f in pairs(game.forces) do
    if f.name == "player" or (#f.players > 0 and not shared.is_corp(f.name)) then table.insert(out, f) end
  end
  return out
end

local function tell(key, ...)
  for _, f in ipairs(players()) do
    if #f.players > 0 then f.print({key, ...}) end
  end
end

local function gps(surface, p) return string.format("[gps=%d,%d,%s]", p.x or p[1], p.y or p[2], surface.name) end

local function signs(f, radar)
  local s = state()
  local surface = radar.surface
  local a = (game.tick % 360) * math.pi / 180
  local at = {radar.position.x + math.cos(a) * SIGNS_DISTANCE, radar.position.y + math.sin(a) * SIGNS_DISTANCE}
  local p = surface.find_non_colliding_position("crash-site-spaceship-wreck-big-1", at, 40, 1)
  if not p then return end
  local wreck = surface.create_entity{name = "crash-site-spaceship-wreck-big-1", position = p, force = "neutral"}
  -- Its cargo: ordinary parts (salvage, a currency of its own, was dropped: the faction loot consult). Two slots: four
  -- stacks left the circuits out.
  if wreck then
    for _, it in ipairs({{"electronic-circuit", 20}, {"iron-gear-wheel", 20}}) do
      wreck.insert{name = it[1], count = it[2]}
    end
  end
  for k = 1, 3 do
    local q = surface.find_non_colliding_position("crash-site-spaceship-wreck-small-" .. k, {p.x + 4 * k - 8, p.y + 3}, 8, 1)
    if q then surface.create_entity{name = "crash-site-spaceship-wreck-small-" .. k, position = q, force = "neutral"} end
  end
  for _, pf in ipairs(players()) do pf.chart(surface, {{p.x - 16, p.y - 16}, {p.x + 16, p.y + 16}}) end
  s.signs = {tick = game.tick, pos = {p.x, p.y}, surface = surface.index}
  tell("lp.signs", gps(surface, p))
end

-- Staggered arrival (the user: "Grubstake coming earlier with its sneaky raids, and Serenity coming in later with much
-- more firepower"): Grubstake, the cheap swarm, first, its survey party at oil processing and its arrival at the first
-- chemical science pack; Serenity, the high-tech one, only once its gate opens: the first rocket launch (Space Age), the
-- first utility science pack (base game, where a launch ends the game). Its first landing then comes within LATE_HASTE.
local EARLY_CORP, LATE_CORP = "grubstake", "serenity"
local LATE_HASTE = 5 * 3600
local function first_corp(surface)
  local s = state()
  s.corp = s.corp or EARLY_CORP
  return s.corp
end
phases.EARLY_CORP, phases.LATE_CORP = EARLY_CORP, LATE_CORP

local function survey(f, surface, from)
  local s = state()
  local corp = first_corp(surface)
  local force = game.forces[shared.CORPS[corp].force]
  local site = faction.site(surface, from, SURVEY_DISTANCE, 0)
  if not site then return end
  surface.request_to_generate_chunks(site, 3)
  surface.force_generate_chunk_requests()
  local function put(kind, x, y)
    local name = shared.variant(corp, kind)
    local p = surface.find_non_colliding_position(name, {site[1] + x, site[2] + y}, 10, 1)
    return p and surface.create_entity{name = name, position = p, force = force}
  end
  local radar = put("lp-radar", 0, 0)
  if not radar then return end
  -- Its drills on the ore the site was chosen for (the user, in game: at fixed offsets they stood on grass beside the
  -- coal): the two nearest ore tiles within 20, at least 5 apart; the offsets only where there is none.
  local drills = {}
  local ores = surface.find_entities_filtered{type = "resource", position = site, radius = 20}
  table.sort(ores, function(a, c)
    return (a.position.x - site[1]) ^ 2 + (a.position.y - site[2]) ^ 2 < (c.position.x - site[1]) ^ 2 + (c.position.y - site[2]) ^ 2
  end)
  local dname = shared.variant(corp, "lp-drill")
  for _, ore in ipairs(ores) do
    if #drills >= 2 then break end
    local far = true
    for _, d in ipairs(drills) do
      if (d.position.x - ore.position.x) ^ 2 + (d.position.y - ore.position.y) ^ 2 < 25 then far = false end
    end
    if far and ore.prototype.resource_category == "basic-solid" then
      local p = surface.find_non_colliding_position(dname, ore.position, 3, 0.5)
      local d = p and surface.create_entity{name = dname, position = p, force = force}
      if d then table.insert(drills, d) end
    end
  end
  while #drills < 2 do
    local d = put("lp-drill", #drills == 0 and -6 or 6, 4)
    if not d then break end
    table.insert(drills, d)
  end
  local party = {radar, drills[1], drills[2], put("lp-lamp", 0, 4)}
  for k = 1, 4 do
    local u = put("lp-infantry", -3 + 2 * k, -4)
    if u then
      u.commandable.set_command{type = defines.command.wander, radius = 15, distraction = defines.distraction.by_enemy}
      table.insert(party, u)
    end
  end
  s.survey = {tick = game.tick, radar = radar, party = party, pos = {radar.position.x, radar.position.y},
    surface = surface.index, corp = corp}
  for _, pf in ipairs(players()) do
    if #pf.players > 0 then
      pf.add_chart_tag(surface, {position = radar.position, icon = {type = "virtual", name = shared.CORPS[corp].icon},
        text = "Survey party"})
    end
  end
  tell("lp.survey", gps(surface, radar.position))
end

local function survey_step(s)
  local sv = s.survey
  if sv.done then return end
  local surface = game.surfaces[sv.surface]
  if not sv.radar.valid then
    sv.done = "destroyed"
    s.delay = DELAY
    surface.spill_item_stack{position = sv.pos, stack = {name = "lp-command-core", count = 1}, enable_looted = true}
    tell("lp.survey-destroyed", gps(surface, sv.pos))
  elseif game.tick - sv.tick >= (storage.phases_fast and 3 * 3600 or SURVEY_TICKS) then
    sv.done = "left"
    for _, e in ipairs(sv.party) do
      if e and e.valid then
        surface.create_entity{name = "medium-explosion", position = e.position}
        e.destroy()
      end
    end
    s.early = game.tick + (storage.phases_fast and 3 * 3600 or EARLY)
    tell("lp.survey-left", gps(surface, sv.pos))
  end
end

-- The early corporation's trigger: the first chemical science pack (found in the production statistics).
function phases.trigger(surface, from)
  local s = state()
  if s.triggered then return end
  s.triggered = {tick = game.tick, surface = surface.index, from = {x = from.x or from[1], y = from.y or from[2]}}
end

-- The late corporation's gate: the first rocket launch (Space Age, faction.on_launch) or utility science pack (base).
function phases.late(surface, from)
  local s = state()
  if s.late then return end
  if not s.triggered then phases.trigger(surface, from) end
  s.late = game.tick
  local f = faction.state()
  if f.next then f.next = math.min(f.next, game.tick + LATE_HASTE) end
  tell("lp.late-gate", shared.corp_label(LATE_CORP))
end

-- Whether a corporation may land yet (faction's choice of the next one).
function phases.gate_open(corp)
  return corp ~= LATE_CORP or state().late ~= nil or storage.gates_off
end
faction.gate_open = phases.gate_open
faction.late_corp = LATE_CORP

local function arrived() return faction.state().surface ~= nil end

function phases.tick(tick)
  if tick % 3600 ~= 1800 then return end
  -- The late gate in the base game, after the first arrival too.
  local st = state()
  if not st.late and not script.active_mods["space-age"] then
    for _, f in ipairs(players()) do
      if not st.late and f.get_item_production_statistics(game.surfaces[1]).get_input_count("utility-science-pack") > 0 then
        phases.late(game.surfaces[1], f.get_spawn_position(game.surfaces[1]))
      end
    end
  end
  if arrived() then return end
  local s = state()
  for _, f in ipairs(players()) do
    if not s.signs then
      local radar = game.surfaces[1].find_entities_filtered{force = f, type = "radar", limit = 1}[1]
      if radar then signs(f, radar) end
    end
    if not s.survey and f.technologies["oil-processing"] and f.technologies["oil-processing"].researched then
      survey(f, game.surfaces[1], f.get_spawn_position(game.surfaces[1]))
    end
    local stats = f.get_item_production_statistics(game.surfaces[1])
    if not s.triggered and stats.get_input_count("chemical-science-pack") > 0 then
      phases.trigger(game.surfaces[1], f.get_spawn_position(game.surfaces[1]))
    end

  end
  if s.survey then survey_step(s) end
  local due
  if s.triggered then due = s.triggered.tick + (s.delay or 0) end
  if s.early and (not due or s.early < due) then due = s.early end
  if due and tick >= due and not faction.pending_kind("phases") then
    local t = s.triggered or {surface = s.survey.surface, from = {x = 0, y = 0}}
    if not s.triggered then
      local spawn = game.forces.player.get_spawn_position(game.surfaces[t.surface])
      t.from = {x = spawn.x, y = spawn.y}
    end
    -- Asynchronous (faction.request): s.arrived is set when it lands.
    faction.request(game.surfaces[t.surface], t.from, {corp = s.corp or first_corp(game.surfaces[t.surface])}, false,
      "phases")
  end
end

function phases.state() return state() end

return phases
