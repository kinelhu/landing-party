-- The biotech's farms (docs/biotech.md; Fable's breeds consult, docs/reviews/2026-10-22-biotech-breeds-consult.md, "Home").
-- It comes once the wild biters' evolution on a surface reaches ARRIVE_EVO (there are mediums to breed by then): a cargo
-- pod comes down on the nearest nest field NEAR to FAR tiles from the player's factory (to FARTHEST if none), and up to
-- PENS of its spawners become pens, each with START bred and WORMS bred worms. The farm is charted for the player, with a
-- map tag; its first landing is told in chat, as a corporation's is. Far out on purpose: hunting it down along its
-- trails is the answer to it, and its waves have the long walk to make (a bred medium covers 14 tiles a second).
-- Its waves (scripts/herd.lua): one at a time, WAVE_GAP apart at the least, from its pens' stock but a home guard, at
-- most WAVE_MAX, sent from the pen nearest the target. A pen attacked recalls the wave on its way (the fight moves to the trail).
-- Every pen dead: the farm is gone (its tag too), and it lands again on another field RELAND later.
-- Creep (scripts/creep.lua): a tumor by each incubator; the creep spreads to the wild nests near, and each it reaches
-- becomes an incubator (up to PENS_MAX). An incubator left off creep (its tumors killed) starves for STARVE and goes
-- back to the wild, its stock with it.
-- The break with Grubstake: when Grubstake's ground meets its creep (a Grubstake building or unit within BREAK_NEAR of a
-- tumor: a claim or strip mine on its edge, a convoy across it) or Grubstake hurts an incubator or a tumor, they are at
-- war (herd.break_grubstake); its waves may then go for Grubstake's camps as for the player's factory.
-- Biomass: an incubator breeds only while its culture can pay (shared.BREEDS, the arena's prices): a culture earns what
-- its creep drinks of the pollution (creep.drink), TRICKLE an incubator a minute whatever the air, and START_BIOMASS its
-- pod brought. Spent at each birth (on_entity_spawned); at nothing left its incubators stop (inactive) until it earns.
local shared = require("__landing-party__.shared")
local herd = require("__landing-party__.scripts.herd")
local pods = require("__landing-party__.scripts.pods")
local creep = require("__landing-party__.scripts.creep")
local cell = require("__landing-party__.scripts.cell")
local tune = require("__landing-party__.scripts.tune")

local farm = {}

local B = shared.BIOTECH
local ARRIVE_EVO = 0.25
local NEAR, FAR, FARTHEST = 600, 1000, 1500
local SEARCH = 2500           -- nests looked at round the player's spawn, nearest first
local CANDIDATES = 80         -- of those, how many are weighed
local FIELD, FIELD_MIN = 40, 3
local PENS = 4
local PENS_MAX = 12           -- a culture's incubators at most, taken by its creep
local STARVE = 3 * 3600       -- off creep this long, an incubator goes wild
-- Its feed (the identity consult's weak point; scripts/cell.lua): an incubator whose biochamber is dead (or stopped,
-- no technician having come for five minutes) breeds nothing,
-- keeps FED_CAP of its stock (the rest goes feral: the wild's), and after UNFED_WILD goes back to the wild. A biochamber
-- hit calls no wave home (a pen hit does): the quiet kill, a raid on the feed while the herd is out.
local FED_CAP = 12
local UNFED_WILD = 10 * 3600
local BREAK_NEAR = 12          -- a Grubstake building or unit this near a tumor breaks the truce
local TRICKLE = 3             -- biomass an incubator earns a minute, clean air or not
local START_BIOMASS = 200     -- what its pod brought (its first wave, ten minutes on)
local START = 6
local WORMS = 2
local HOME_GUARD = 6          -- per pen, kept at the gate when a wave goes
-- A wave's most (the consult: waves of 20 to 60; the mega wave is an event at the top of its ladder, not the default).
-- Four full pens sent 135 in the first farm run.
local WAVE_MAX = 60
local WAVE_GAP = 20 * 3600
local FIRST_WAVE = 10 * 3600  -- after landing
local RELAND = 60 * 3600
local RETRY = 10 * 3600       -- a surface with no field for it is looked at again after this
local APART = 200             -- from a corporation's camp
local POD_WAIT = 2 * 3600

local function st()
  storage.farms = storage.farms or {list = {}, next = 1}
  return storage.farms
end

local function d2(a, b)
  local ax, ay = a.x or a[1], a.y or a[2]
  local bx, by = b.x or b[1], b.y or b[2]
  return (ax - bx) ^ 2 + (ay - by) ^ 2
end

local function players() return shared.player_forces() end

local function corp_forces()
  local out = {}
  for _, c in pairs(shared.CORPS) do if game.forces[c.force] then table.insert(out, c.force) end end
  return out
end

local function trace(text)
  if storage.trace then
    helpers.write_file("landing-party/decisions.txt", string.format("%8d %s  %s\n", game.tick, "biotech", text), true)
  end
end

-- The nearest nest field NEAR to `far` from the player's factory (none of its buildings within NEAR, some within far):
-- its middle and its spawners.
local function site(surface, far)
  local forces = players()
  if #forces == 0 then return nil end
  local origin = forces[1].get_spawn_position(surface)
  local nests = surface.find_entities_filtered{type = "unit-spawner", force = "enemy", position = origin, radius = SEARCH}
  table.sort(nests, function(a, b) return d2(a.position, origin) < d2(b.position, origin) end)
  local weighed = 0
  local corps = corp_forces()
  for _, sp in ipairs(nests) do
    if weighed >= CANDIDATES then break end
    local p = sp.position
    if surface.count_entities_filtered{position = p, radius = NEAR, force = forces, limit = 1} == 0 then
      weighed = weighed + 1
      if surface.count_entities_filtered{position = p, radius = far, force = forces, limit = 1} > 0
        and (#corps == 0 or surface.count_entities_filtered{position = p, radius = APART, force = corps, limit = 1} == 0) then
        local field = surface.find_entities_filtered{type = "unit-spawner", force = "enemy", position = p, radius = FIELD}
        if #field >= FIELD_MIN then
          local x, y = 0, 0
          for _, f in ipairs(field) do x, y = x + f.position.x, y + f.position.y end
          return {x = x / #field, y = y / #field}, field
        end
      end
    end
  end
end

local function bred_stock(surface, pen, n)
  local evo = game.forces[B.force].get_evolution_factor(surface)
  local name = evo >= 0.3 and "lp-bred-medium-biter" or "lp-bred-small-biter"
  local rec = herd.pen(pen.unit_number)
  for _ = 1, n do
    local q = surface.find_non_colliding_position(name, pen.position, 16, 0.5)
    local u = q and surface.create_entity{name = name, position = q, force = B.force}
    if u and rec then table.insert(rec.stock, u) end
  end
end

local function tag(f)
  local s = game.surfaces[f.surface]
  local all = true
  for _, pf in ipairs(players()) do
    if not (f.tags[pf.name] and f.tags[pf.name].valid) then
      pf.chart(s, {{f.pos.x - 64, f.pos.y - 64}, {f.pos.x + 64, f.pos.y + 64}})
      local t = pf.add_chart_tag(s, {position = f.pos, icon = {type = "item", name = "biter-egg"}, text = f.id == 1 and "Synthexis culture" or ("Synthexis culture " .. f.id)})
      if t then f.tags[pf.name] = t else all = false end
    end
  end
  f.tagged = all
end

-- The pod touched down: the field's spawners nearest it become pens.
function farm.land(surface, pos)
  local s = st()
  s.landing = nil
  local field = surface.find_entities_filtered{type = "unit-spawner", force = "enemy", position = pos, radius = FIELD + 10}
  table.sort(field, function(a, b) return d2(a.position, pos) < d2(b.position, pos) end)
  if #field == 0 then
    s.next_arrival = game.tick + RETRY
    trace("its pod came down on no nests; looks again later")
    return
  end
  local bf = game.forces[B.force]
  local enemy = game.forces.enemy
  if bf and enemy then bf.set_evolution_factor(enemy.get_evolution_factor(surface), surface) end
  local f = {id = s.next, surface = surface.index, pos = {x = pos.x, y = pos.y}, pens = {}, tags = {},
    last_wave = game.tick - tune.sooner("biotech", WAVE_GAP) + tune.sooner("biotech", FIRST_WAVE), landed = game.tick}
  s.next = s.next + 1
  for i = 1, math.min(PENS, #field) do
    local id = herd.capture(field[i])
    local rec = id and herd.pen(id)
    if rec then
      rec.farm = f.id
      table.insert(f.pens, id)
      bred_stock(surface, rec.pen, START)
      for _ = 1, WORMS do
        local q = surface.find_non_colliding_position("lp-bred-worm", {rec.pen.position.x + 6, rec.pen.position.y + 6}, 12, 1)
        if q then surface.create_entity{name = "lp-bred-worm", position = q, force = B.force} end
      end
      -- Its tumor, beside it: the creep grows from there (scripts/creep.lua).
      creep.plant(surface, rec.pen.position, f.id)
      -- Its cell: pad, biochamber, lamp (scripts/cell.lua).
      cell.build(id, rec.pen, f.id, f.pos)
    end
  end
  s.list[f.id] = f
  creep.culture(f.id, surface, pos)
  -- Its substrate and technicians (scripts/cell.lua).
  cell.site(f.id, surface, f.pos)
  creep.of(f.id).biomass = START_BIOMASS * tune.strength("biotech")
  tag(f)
  trace(string.format("farm %d landed at %.0f,%.0f: %d pens", f.id, pos.x, pos.y, #f.pens))
  if not s.told then
    s.told = true
    for _, pf in ipairs(players()) do
      -- Its first landing is told, as a corporation's is (the user: the last resort, "pointing the first landing").
      pf.print({"lp.biotech-landed", string.format("[gps=%d,%d,%s]", pos.x, pos.y, surface.name)}) -- notice-ok: first landing
    end
  end
end

pods.handlers["biotech-farm"] = function(_, surface, position) farm.land(surface, position) end

local function arrive(surface, far)
  local c = site(surface, far)
  if not c then return false end
  local s = st()
  local pod = pods.send(surface, c, B.force, {kind = "biotech-farm"})
  s.landing = {surface = surface.index, at = c, sent = game.tick}
  trace(string.format("its pod comes down on the nests at %.0f,%.0f", c.x, c.y))
  if not pod then farm.land(surface, c) end
  return true
end

-- Tests: an arrival now, whatever the evolution.
function farm.arrive_now(surface) return arrive(surface, FAR) or arrive(surface, FARTHEST) end

local function gone(f, why)
  for _, t in pairs(f.tags) do if t.valid then t.destroy() end end
  st().list[f.id] = nil
  creep.forget(f.id)
  cell.forget_site(f.id)
  st().next_arrival = game.tick + RELAND
  trace(string.format("farm %d gone (%s); lands again in %d minutes", f.id, why, RELAND / 3600))
end

-- The nearest of the player's guns and machines from pos (and Grubstake's, once at war with it), by rings (a bounded
-- search, then the nearest in it).
local function target_from(surface, pos)
  local forces = players()
  if herd.grubstake_broken() and game.forces[shared.CORPS.grubstake.force] then
    table.insert(forces, game.forces[shared.CORPS.grubstake.force])
  end
  for _, r in ipairs({200, 400, 800, 1600}) do
    local near = surface.find_entities_filtered{position = pos, radius = r, force = forces, type = herd.DRAW}
    if #near > 0 then
      local best, bd
      for _, e in ipairs(near) do
        local d = d2(e.position, pos)
        if not bd or d < bd then best, bd = e, d end
      end
      return best.position
    end
  end
end

local function send(f, tick)
  local s = game.surfaces[f.surface]
  local units, origin = {}, nil
  local target = target_from(s, f.pos)
  if not target then return end
  local bd
  for _, id in ipairs(f.pens) do
    local rec = herd.pen(id)
    if rec and rec.pen.valid then
      local stock = herd.stock(rec)
      table.sort(stock, function(a, b) return d2(a.position, rec.pen.position) < d2(b.position, rec.pen.position) end)
      local home = {}
      for i, u in ipairs(stock) do
        if i <= HOME_GUARD or #units >= WAVE_MAX then table.insert(home, u) else table.insert(units, u) end
      end
      rec.stock = home
      local d = d2(rec.pen.position, target)
      if not bd or d < bd then origin, bd = rec, d end
    end
  end
  if #units < shared.WAVE_MIN or not origin then
    -- Not enough yet: back into the pens' stock.
    for _, u in ipairs(units) do table.insert(origin and origin.stock or herd.pen(f.pens[1]).stock, u) end
    return
  end
  f.last_wave = tick
  -- Its probe's runts, if it will throw them (herd.lua), at their price.
  local cul = creep.of(f.id)
  if cul and game.forces[B.force].get_evolution_factor(s) >= herd.PROBE_EVO then
    local price = herd.PROBE_N * shared.BREEDS["lp-runt"].cost
    cul.biomass, cul.spent = cul.biomass - price, (cul.spent or 0) + price
  end
  herd.launch(origin, target, {units = units, farm = f.id})
  trace(string.format("farm %d sends %d at %.0f,%.0f", f.id, #units, target.x, target.y))
end

-- Its incubators breed while it has biomass, and stop when it has none.
local function breeding(f, on)
  for _, pid in ipairs(f.pens) do
    local rec = herd.pen(pid)
    local want = on and not (rec and rec.unfed)
    if rec and rec.pen.valid and rec.pen.disabled_by_script ~= not want then rec.pen.disabled_by_script = not want end
  end
end

-- An incubator whose biochamber is dead: its stock over FED_CAP goes feral (the wild's force, out of the incubator's
-- hold); true once it has been unfed UNFED_WILD.
local function unfed(rec, tick)
  rec.unfed = rec.unfed or tick
  local all = herd.stock(rec)
  local feral = 0
  for i = FED_CAP + 1, #all do
    local u = all[i]
    if u.valid then
      if u.commandable and u.commandable.spawner then u.commandable.release_from_spawner() end
      u.force = "enemy"
      feral = feral + 1
    end
  end
  if feral > 0 then
    local keep = {}
    for i = 1, math.min(FED_CAP, #all) do keep[#keep + 1] = all[i] end
    rec.stock = keep
    rec.feral = (rec.feral or 0) + feral
  end
  return tick - rec.unfed >= UNFED_WILD
end

function farm.tick(tick)
  if tick % 600 ~= 300 then return end
  local s = st()
  creep.drink(10)
  for id, f in pairs(s.list) do
    local left = {}
    local surface = game.surfaces[f.surface]
    -- Its substrate (older saves: built now) and its technicians' rounds.
    cell.site(id, surface, f.pos)
    cell.tick(id, surface, f.pens, tick)
    for _, pid in ipairs(f.pens) do
      local rec = herd.pen(pid)
      if rec and rec.pen.valid then
        -- Its cell (old saves had none: built now); its biochamber dead, it is unfed and goes wild in time.
        local c = cell.of(pid) or cell.build(pid, rec.pen, f.id, f.pos)
        -- Unfed: its biochamber dead, or stopped for want of a technician's visit.
        local hungry = c and (not (c.chamber and c.chamber.valid) or cell.hungry(c, tick))
        if not hungry and rec.unfed then rec.unfed = nil end
        if hungry and unfed(rec, tick) then
          cell.forget(pid)
          herd.release(pid)
          f.lost_to_feed = (f.lost_to_feed or 0) + 1
          trace(string.format("farm %d: an incubator unfed for %d minutes went wild", f.id, UNFED_WILD / 3600))
        -- Off creep it starves, then goes wild.
        elseif creep.covered(surface, rec.pen.position) then
          rec.starving = nil
          table.insert(left, pid)
        else
          rec.starving = rec.starving or tick
          if tick - rec.starving >= STARVE then
            cell.forget(pid)
            herd.release(pid)
            f.lost_to_starving = (f.lost_to_starving or 0) + 1
            trace(string.format("farm %d: an incubator starved off its creep and went wild", f.id))
          else
            table.insert(left, pid)
          end
        end
      else
        cell.forget(pid)
      end
    end
    f.pens = left
    local cul = creep.of(id)
    if cul then
      local t = #f.pens * TRICKLE / 6 * tune.strength("biotech")
      cul.biomass, cul.trickled = cul.biomass + t, (cul.trickled or 0) + t
      breeding(f, cul.biomass > 0)
    end
    -- Grubstake on its creep: the truce is over.
    if not herd.grubstake_broken() then
      local g = shared.CORPS.grubstake.force
      for _, t in ipairs(creep.tumors_of(id)) do
        if surface.count_entities_filtered{position = t.position, radius = BREAK_NEAR, force = g, limit = 1} > 0 then
          herd.break_grubstake(string.format("Grubstake at its tumor at %.0f,%.0f", t.position.x, t.position.y))
          break
        end
      end
    end
    -- The creep takes the wild nest it reaches.
    local take = #left < PENS_MAX and creep.bud(id, tick)
    if take then
      local pid = herd.capture(take)
      local rec = pid and herd.pen(pid)
      if rec then
        rec.farm = f.id
        table.insert(f.pens, pid)
        creep.plant(surface, rec.pen.position, f.id)
        cell.build(pid, rec.pen, f.id, f.pos)
        f.taken = (f.taken or 0) + 1
        trace(string.format("farm %d: its creep took the nest at %.0f,%.0f (%d incubators)", f.id, rec.pen.position.x,
          rec.pen.position.y, #f.pens))
      end
    end
    if #left == 0 then
      gone(f, "every pen dead")
    else
      if not f.tagged then tag(f) end
      if not storage.herd_off and not herd.out(id) and tick - f.last_wave >= tune.sooner("biotech", WAVE_GAP) then send(f, tick) end
    end
  end
  if s.landing and tick - s.landing.sent > POD_WAIT then
    farm.land(game.surfaces[s.landing.surface], s.landing.at)
  end
  if next(s.list) == nil and not s.landing and not storage.biotech_off and tick >= (s.next_arrival or 0) then
    local enemy = game.forces.enemy
    local came = false
    for _, surface in pairs(game.surfaces) do
      if not came and enemy and enemy.get_evolution_factor(surface) >= ARRIVE_EVO then
        came = arrive(surface, FAR) or arrive(surface, FARTHEST)
      end
    end
    if not came then s.next_arrival = tick + RETRY end
  end
end

-- A birth at an incubator: its breed's price off its culture's biomass; at nothing left, its incubators stop.
function farm.on_spawned(e)
  local sp = e.spawner
  if not (sp and sp.valid and sp.name == "lp-pen") then return end
  local rec = herd.pen(sp.unit_number)
  local f = rec and rec.farm and st().list[rec.farm]
  local cul = f and creep.of(f.id)
  if not cul then return end
  local price = shared.BREEDS[e.entity.name] and shared.BREEDS[e.entity.name].cost or 7
  -- A burster glows inside: lit at night, acid green, the one light in the herd.
  if e.entity.name == "lp-bred-cinder" then
    rendering.draw_light{sprite = "utility/light_small", surface = e.entity.surface, target = e.entity,
      color = {0.35, 1, 0.2}, scale = 1.2, intensity = 0.8, minimum_darkness = 0.3}
  end
  cul.biomass, cul.spent, cul.bred = cul.biomass - price, (cul.spent or 0) + price, (cul.bred or 0) + 1
  if cul.biomass <= 0 then breeding(f, false) end
end

-- A pen hit by anyone at war with it: its farm's wave on its way comes home.
function farm.on_damaged(e)
  local ent = e.entity
  if e.force and e.force.name == shared.CORPS.grubstake.force then
    herd.break_grubstake(string.format("Grubstake hit its %s at %.0f,%.0f", ent.name, ent.position.x, ent.position.y))
  end
  if ent.name == "lp-tumor" then return end
  if ent.name ~= "lp-pen" or not e.force or e.force.name == B.force or shared.is_biters(e.force.name) then return end
  local rec = herd.pen(ent.unit_number)
  if rec and rec.farm and herd.out(rec.farm) then herd.recall(rec.farm, "its farm is attacked") end
end

-- Dev: every farm sends a wave at its next check, its pens topped up to send one.
function farm.debug_wave()
  local any = false
  for _, f in pairs(st().list) do
    local s = game.surfaces[f.surface]
    for _, id in ipairs(f.pens) do
      local rec = herd.pen(id)
      if rec and rec.pen.valid then bred_stock(s, rec.pen, math.max(0, HOME_GUARD + 10 - #herd.stock(rec))) end
    end
    f.last_wave = -WAVE_GAP
    any = true
  end
  return any
end

function farm.state()
  local s = st()
  local out = {next_arrival = s.next_arrival, landing = s.landing, farms = {}}
  for id, f in pairs(s.list) do
    local tags = 0
    for _, t in pairs(f.tags) do if t.valid then tags = tags + 1 end end
    local unfed, feral = {}, 0
    for _, pid in ipairs(f.pens) do
      local rec = herd.pen(pid)
      if rec and rec.unfed then unfed[#unfed + 1] = {id = pid, since = rec.unfed, active = rec.pen.valid and rec.pen.active,
        stock = #herd.stock(rec)} end
      feral = feral + (rec and rec.feral or 0)
    end
    table.insert(out.farms, {id = id, pos = f.pos, pens = #f.pens, pen_ids = f.pens, tags = tags, last_wave = f.last_wave,
      landed = f.landed, taken = f.taken or 0, starved = f.lost_to_starving or 0, unfed = unfed, feral = feral,
      lost_to_feed = f.lost_to_feed or 0, biomass = creep.of(id) and {
        now = creep.of(id).biomass, drunk = creep.of(id).drunk, trickled = creep.of(id).trickled,
        spent = creep.of(id).spent or 0, bred = creep.of(id).bred or 0}})
  end
  return out
end

return farm
