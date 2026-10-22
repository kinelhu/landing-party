-- The biotech's farms (docs/biotech.md; Fable's breeds consult, docs/reviews/2026-10-22-biotech-breeds-consult.md, "Home").
-- It comes once the wild biters' evolution on a surface reaches ARRIVE_EVO (there are mediums to breed by then): a cargo
-- pod comes down on the nearest nest field NEAR to FAR tiles from the player's factory (to FARTHEST if none), and up to
-- PENS of its spawners become pens, each with START bred and WORMS bred worms. The farm is charted for the player, with a
-- map tag; its first landing is told in chat, as a corporation's is. Far out on purpose: hunting it down along its
-- trails is the answer to it, and its waves have the long walk to make (a bred medium covers 14 tiles a second).
-- Its waves (scripts/herd.lua): one at a time, WAVE_GAP apart at the least, from its pens' stock but a home guard, at
-- most WAVE_MAX, sent from the pen nearest the target. A pen attacked recalls the wave on its way (the fight moves to the trail).
-- Every pen dead: the farm is gone (its tag too), and it lands again on another field RELAND later.
local shared = require("__landing-party__.shared")
local herd = require("__landing-party__.scripts.herd")
local pods = require("__landing-party__.scripts.pods")

local farm = {}

local B = shared.BIOTECH
local ARRIVE_EVO = 0.25
local NEAR, FAR, FARTHEST = 600, 1000, 1500
local SEARCH = 2500           -- nests looked at round the player's spawn, nearest first
local CANDIDATES = 80         -- of those, how many are weighed
local FIELD, FIELD_MIN = 40, 3
local PENS = 4
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
      local t = pf.add_chart_tag(s, {position = f.pos, icon = {type = "item", name = "biter-egg"}, text = "Biotech farm"})
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
    last_wave = game.tick - WAVE_GAP + FIRST_WAVE, landed = game.tick}
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
    end
  end
  s.list[f.id] = f
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
  st().next_arrival = game.tick + RELAND
  trace(string.format("farm %d gone (%s); lands again in %d minutes", f.id, why, RELAND / 3600))
end

-- The nearest of the player's guns and machines from pos, by rings (a bounded search, then the nearest in it).
local function target_from(surface, pos)
  local forces = players()
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
  herd.launch(origin, target, {units = units, farm = f.id})
  trace(string.format("farm %d sends %d at %.0f,%.0f", f.id, #units, target.x, target.y))
end

function farm.tick(tick)
  if tick % 600 ~= 300 then return end
  local s = st()
  for id, f in pairs(s.list) do
    local left = {}
    for _, pid in ipairs(f.pens) do
      local rec = herd.pen(pid)
      if rec and rec.pen.valid then table.insert(left, pid) end
    end
    f.pens = left
    if #left == 0 then
      gone(f, "every pen dead")
    else
      if not f.tagged then tag(f) end
      if not storage.herd_off and not herd.out(id) and tick - f.last_wave >= WAVE_GAP then send(f, tick) end
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

-- A pen hit by anyone at war with it: its farm's wave on its way comes home.
function farm.on_damaged(e)
  local ent = e.entity
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
    table.insert(out.farms, {id = id, pos = f.pos, pens = #f.pens, pen_ids = f.pens, tags = tags, last_wave = f.last_wave,
      landed = f.landed})
  end
  return out
end

return farm
