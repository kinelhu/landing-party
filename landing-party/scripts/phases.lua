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
  if wreck then wreck.insert{name = "lp-salvage", count = 30} end
  for k = 1, 3 do
    local q = surface.find_non_colliding_position("crash-site-spaceship-wreck-small-" .. k, {p.x + 4 * k - 8, p.y + 3}, 8, 1)
    if q then surface.create_entity{name = "crash-site-spaceship-wreck-small-" .. k, position = q, force = "neutral"} end
  end
  for _, pf in ipairs(players()) do pf.chart(surface, {{p.x - 16, p.y - 16}, {p.x + 16, p.y + 16}}) end
  s.signs = {tick = game.tick, pos = {p.x, p.y}, surface = surface.index}
  tell("lp.signs", gps(surface, p))
end

-- The first corporation: chosen once, from the map seed.
local function first_corp(surface)
  local s = state()
  if not s.corp then
    local names = {}
    for corp in pairs(shared.CORPS) do table.insert(names, corp) end
    table.sort(names)
    s.corp = names[(surface.map_gen_settings.seed % #names) + 1]
  end
  return s.corp
end

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
  local party = {radar, put("lp-drill", -6, 4), put("lp-drill", 6, 4), put("lp-lamp", 0, 4)}
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

-- The trigger: called on a rocket launch (Space Age) or found in the production statistics (base game).
function phases.trigger(surface, from)
  local s = state()
  if s.triggered then return end
  s.triggered = {tick = game.tick, surface = surface.index, from = {x = from.x or from[1], y = from.y or from[2]}}
end

local function arrived() return faction.state().surface ~= nil end

function phases.tick(tick)
  if tick % 3600 ~= 1800 then return end
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
    if not s.triggered and not script.active_mods["space-age"] then
      local stats = f.get_item_production_statistics(game.surfaces[1])
      if stats.get_input_count("chemical-science-pack") > 0 then
        phases.trigger(game.surfaces[1], f.get_spawn_position(game.surfaces[1]))
      end
    end
  end
  if s.survey then survey_step(s) end
  local due
  if s.triggered then due = s.triggered.tick + (s.delay or 0) end
  if s.early and (not due or s.early < due) then due = s.early end
  if due and tick >= due then
    local t = s.triggered or {surface = s.survey.surface, from = {x = 0, y = 0}}
    if not s.triggered then
      local spawn = game.forces.player.get_spawn_position(game.surfaces[t.surface])
      t.from = {x = spawn.x, y = spawn.y}
    end
    faction.arrive(game.surfaces[t.surface], t.from, {corp = s.corp or first_corp(game.surfaces[t.surface])})
    s.arrived = game.tick
  end
end

function phases.state() return state() end

return phases
