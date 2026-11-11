-- Construction (split from base.lua, 2026-10-18, along the AI graph's seams: docs/ai-graph.md): how a settlement lays
-- its floors and places its buildings, makes way, pays (the reserve for its economy), rebuilds what it lost after a
-- delay, its build step, what it does when a building dies, and the repair of old saves' lines. The code is as it was
-- in base; install runs it with base's helpers bound (K) and returns what base calls.
local shared = require("__landing-party__.shared")

local construction = {}

function construction.install(ops, K)
local BUILD_TICKS = K.BUILD_TICKS
local OCCUPIERS = K.OCCUPIERS
local OCCUPY_RADIUS = K.OCCUPY_RADIUS
local REBUILD_DELAY = K.REBUILD_DELAY
local REBUILD_TILES_PER_SECOND = K.REBUILD_TILES_PER_SECOND
local army = K.army
local base = K.base
local clear_area = K.clear_area
local force = K.force
local join = K.join
local register = K.register
local site = K.site
local trace = K.trace
-- Lay road tiles, never over water or an existing road.
-- Floors in the corporation's own tiles: roads, and pads (paved yards, docs/corporations.md).
-- A post's pad remembers the ground under it (module.under), put back when the post comes down (cordon.lua: recovered
-- arcs and rings left their pads as litter, the user's screenshot and spread2).
local function pave(b, tiles, floor, module)
  local surface = game.surfaces[b.surface]
  local name = shared.variant(b.corp, "lp-" .. (floor or "road"))
  local out = {}
  local keep = module and module.kind == "post" and floor == "pad"
  if keep then module.under = module.under or {} end
  -- Water under its floor filled first, by a corporation that fills (shared.landfill: a pond, never a lake).
  shared.landfill(surface, tiles, b)
  for _, t in ipairs(tiles) do
    local tile = surface.get_tile(t[1], t[2])
    if tile.valid and tile.name ~= name and not tile.collides_with("water_tile") then
      table.insert(out, {name = name, position = t})
      if keep then table.insert(module.under, {name = tile.name, position = t}) end
    end
  end
  if #out > 0 then surface.set_tiles(out, true, false, true, false) end
  b.road_tiles = b.road_tiles + #out
end


-- Place one entity for a job. Returns the entity, or nil when the spot is blocked.
-- The drop's turrets and the settlement's own units give way to what it builds: a corner turret where the pad's wall
-- goes is packed up, units standing there step aside (with a drop escort, the pad's walls, turrets and flamer were
-- skipped for good: siegetier).
local function make_way(b, surface, name, pos)
  local cb = prototypes.entity[name].collision_box
  -- Two tiles of margin: a tank's box reaches past its position.
  local area = {{pos[1] + cb.left_top.x - 2, pos[2] + cb.left_top.y - 2},
    {pos[1] + cb.right_bottom.x + 2, pos[2] + cb.right_bottom.y + 2}}
  for _, e in pairs(surface.find_entities_filtered{area = area, force = force(b)}) do
    if e.type == "unit" or e.type == "spider-unit" then
      local p = surface.find_non_colliding_position(e.name, {pos[1], pos[2] + 10}, 16, 1)
      if p then e.teleport(p) end
    else
      for i, g in ipairs(b.drop_gens or {}) do
        if g == e then
          table.remove(b.drop_gens, i)
          for j = #b.gens, 1, -1 do if b.gens[j] == e then table.remove(b.gens, j) end end
          storage.owner[e.unit_number] = nil
          e.destroy()
          break
        end
      end
      for i, t in ipairs(b.camp_turrets or {}) do
        if e.valid and t == e then
          table.remove(b.camp_turrets, i)
          for j = #b.turrets, 1, -1 do if b.turrets[j] == e then table.remove(b.turrets, j) end end
          e.destroy()
          break
        end
      end
    end
  end
end

-- by_crew: a crew builds it (crew.lua), its parts paid when it left, its own effect drawn.
local function place(b, job, by_crew)
  local surface = game.surfaces[b.surface]
  local pos = job.pos
  -- Jobs name kinds; the corporation's own prototype is what is built. A corporation with flak builds every flak-th turret
  -- as a scrap cannon (Grubstake); a lost one is rebuilt as one (its kind is what is queued).
  local flak = shared.CORPS[b.corp].flak
  if job.name == "lp-turret" and flak then
    b.turrets_placed = (b.turrets_placed or 0) + 1
    if b.turrets_placed % flak == 0 then job.name = "lp-scrap-cannon" end
  end
  local name = shared.variant(b.corp, job.name)
  clear_area(surface, name, pos, b)
  make_way(b, surface, name, pos)
  if job.loose then pos = surface.find_non_colliding_position(name, pos, 4, 0.5) or pos end
  local ok = surface.can_place_entity{name = name, position = pos, direction = job.dir, force = force(b)}
  local e = ok and surface.create_entity{name = name, position = pos, direction = job.dir, force = force(b),
    auto_connect = (job.name == "lp-pylon") or nil}
  if not e then return nil end
  if not by_crew then b.parts = b.parts - (shared.cost[job.name] or 0) end
  register(b, e, job.module)
  if by_crew then
    -- the crew draws its own
  elseif shared.CORPS[b.corp].crews == "truck" then
    -- A yard with crews builds with a crane's sparks, no beam (the builders consult: the beam was "decorporealized").
    surface.create_entity{name = "explosion-hit", position = e.position}
  elseif shared.CORPS[b.corp].crews == "drone" then
    -- Serenity's yard: a short beam from its nearest depot or the lander (a warp-in), not always from the lander.
    local from, fd = b.lander.valid and b.lander or nil, math.huge
    if from then fd = (from.position.x - e.position.x) ^ 2 + (from.position.y - e.position.y) ^ 2 end
    for _, d in ipairs(b.depots or {}) do
      if d.valid then
        local dd = (d.position.x - e.position.x) ^ 2 + (d.position.y - e.position.y) ^ 2
        if dd < fd then from, fd = d, dd end
      end
    end
    if from then
      rendering.draw_line{from = from, to = e, surface = surface, color = {0.5, 0.8, 1, 0.6}, width = 1,
        time_to_live = BUILD_TICKS}
    end
  elseif b.lander.valid then
    rendering.draw_line{from = b.lander, to = e, surface = surface, color = {0.5, 0.8, 1, 0.6}, width = 1,
      time_to_live = BUILD_TICKS}
  end
  if job.name == "lp-pylon" then join(e) end
  if job.name == "lp-pylon" and base.network(b) and e.electric_network_id ~= base.network(b) then
    trace(b, string.format("pylon at %.1f,%.1f did not join the network", e.position.x, e.position.y))
  end
  return e
end

function base.place_job(b, job, by_crew) return place(b, job, by_crew) end
function base.pave_job(b, job) return pave(b, job.tiles, job.floor, job.module) end

-- Forces whose presence occupies ground: every force the faction is at war with, biters excepted.
local function occupied(b, surface, pos)
  local f = force(b)
  for _, other in pairs(game.forces) do
    if other ~= f and not shared.is_biters(other.name) and other.name ~= "neutral" and not f.get_cease_fire(other)
      and surface.count_entities_filtered{position = pos, radius = OCCUPY_RADIUS, force = other,
        type = OCCUPIERS, limit = 1} > 0 then
      return true
    end
  end
  return false
end
base.occupied = occupied
base.occupied = occupied
site.occupied = occupied

-- Rebuild first: the first lost entity whose ground is free. Occupied ground waits.
local ECONOMY = {["lp-generator"] = true, ["lp-fabricator"] = true, ["lp-drill"] = true, ["lp-pylon"] = true}
-- What makes parts comes first: with its fabricators destroyed, a settlement spent its last 646 parts on new blocks,
-- units and two turrets while their ground was held, and once it was free had nothing to rebuild them with, nor ever
-- again (scenario occupy). Parts kept back for every pending rebuild of what makes them.
-- And always a fabricator and its pylon, before any loss: kept back only once rebuilds were due, the parts were gone by
-- then (a camp at 13 parts lost its nine fabricators to a raid and, a fabricator costing 25, never made another, scenario
-- raid, 2026-10-24). Economy jobs still build below it. (One of every economy kind, 57, held a camp landed with 60 from
-- anything else: Kessler-Hayashi on seed 4242.)
local FLOOR = (shared.cost["lp-fabricator"] or 0) + (shared.cost["lp-pylon"] or 0)
-- `name`, what is to be built with the parts: a clearance saving for its parts (siege.lua, b.hazard_save) holds them from
-- everything but what makes parts and power, and its railgunners (the hazard at 0.2.324: walls, gates and radars
-- rebuilt as the waves broke them, and the last nest waited "parts 2 of 220" for the rest of the hour; its turrets kept
-- out of the saving, their rebuilds at 15 parts a drone took every part as it came, and it never passed 143).
local SAVE_EXEMPT = {["lp-railgunner"] = true}
-- Whether a clearance's saving holds the parts from `name` (crew.rebuild asks: a camp's drones rebuild its walls).
function base.saving_holds(b, name)
  local hs = b.hazard_save
  if not (hs and game.tick < hs.till) then return false end
  local k = name and shared.kind_of(name)
  return not (k and (ECONOMY[k] or SAVE_EXEMPT[k]))
end

function base.reserve(b, name)
  local reserve = 0
  for _, job in ipairs(b.rebuild) do
    if ECONOMY[shared.kind_of(job.name)] then reserve = reserve + (shared.cost[job.name] or 0) end
  end
  reserve = math.max(reserve, FLOOR)
  if base.saving_holds(b, name) then reserve = math.max(reserve, b.hazard_save.need) end
  return reserve
end
army.reserve = base.reserve

local function rebuild(b)
  local surface = game.surfaces[b.surface]
  for i, job in ipairs(b.rebuild) do
    local reserve = base.reserve(b, job.name)
    if game.tick < job.due then
      -- still on its way
    elseif base.footing and not base.footing(b, job) then
      -- At war and short of units: parts go to units first (scripts/war.lua).
    elseif base.crew_rebuild and base.crew_rebuild(b, job) then
      -- Beyond the yards: a crew's (crew.lua), out or waiting for one; taken, the list changed: next build step.
      if not job.crew_wait then return true end
    elseif occupied(b, surface, job.pos) then
      if not job.occupied then job.occupied = true; trace(b, string.format("cannot rebuild %s at %.0f,%.0f: occupied",
        job.name, job.pos[1], job.pos[2])) end
    else
      job.occupied = nil
      local economy = ECONOMY[shared.kind_of(job.name)]
      local need = (shared.cost[job.name] or 0) + (economy and 0 or reserve)
      -- Held back for the reserve: it steps aside, the rebuilds of what makes parts behind it go first.
      if b.parts < need and not economy and reserve > 0 then goto continue end
      if b.parts < need then b.waiting = job.name; return true end
      b.waiting = nil
      table.remove(b.rebuild, i)
      if place(b, job) then
        b.rebuilt = b.rebuilt + 1
        trace(b, string.format("rebuilt %s at %.0f,%.0f", job.name, job.pos[1], job.pos[2]))
      elseif (job.tries or 0) < 5 then
        -- Blocked (often a unit standing there): tried again in 30 s, five times (dropped at once, an outpost
        -- turret was never rebuilt, occupy).
        job.tries = (job.tries or 0) + 1
        job.due = game.tick + 30 * 60
        table.insert(b.rebuild, job)
        trace(b, string.format("cannot rebuild %s at %.0f,%.0f: blocked, again in 30 s", job.name, job.pos[1], job.pos[2]))
      else
        trace(b, string.format("cannot rebuild %s at %.0f,%.0f: blocked", job.name, job.pos[1], job.pos[2]))
      end
      return true
    end
    ::continue::
  end
  return false
end

-- Place the next queued entity if parts allow. A failed key entity abandons the rest of its module.
local function build(b)
  if rebuild(b) then return end
  -- Road tiles cost nothing and take no build step.
  -- Floors cost nothing and take no build step.
  -- A crew's module's floor waits for the crew (crew.take takes it with the rest): paved at once, a cordon post's pad
  -- lay out on the ground before its drone came (the user, 2026-10-17).
  while b.queue[1] and b.queue[1].tiles do
    if b.queue[1].module and base.crew_take and base.crew_take(b, b.queue[1]) then return end
    local job = table.remove(b.queue, 1)
    pave(b, job.tiles, job.floor, job.module)
  end
  local job = b.queue[1]
  if not job then return end
  -- A module beyond every yard goes to a crew (crew.lua), which takes its jobs off the queue or holds them for one.
  if base.crew_take and base.crew_take(b, job) then return end
  local cost = shared.cost[job.name] or 0
  -- (What makes parts and power builds below the reserve: the reserve is for it.)
  local held = ECONOMY[shared.kind_of(job.name or "")] and 0 or base.reserve(b, job.name)
  if b.parts < cost + held then
    -- What makes parts and power goes past a job waiting for parts: behind a turret or a launch pad the camp could
    -- not pay for, its first fabricator and its pylon waited for good (parked, grow; 2026-10-24).
    -- Moved to the head, it is built as the head is, next step (a crew's if its module is beyond the yards).
    for i = 2, #b.queue do
      local q = b.queue[i]
      if q.name and not q.tiles and ECONOMY[shared.kind_of(q.name)] and b.parts >= (shared.cost[q.name] or 0) then
        table.remove(b.queue, i)
        table.insert(b.queue, 1, q)
        break
      end
    end
    b.waiting = job.name
    return
  end
  b.waiting = nil
  table.remove(b.queue, 1)
  local e = place(b, job)
  if job.slot then job.slot.filled = e ~= nil end
  if not e and job.module.x0 then
    -- A block survives a blocked entity: skip it.
    trace(b, string.format("cannot place %s at %.1f,%.1f in %s: skipped", job.name, job.pos[1], job.pos[2], job.module.kind))
    return
  end
  if not e then
    trace(b, string.format("cannot place %s at %.1f,%.1f: %s abandoned", job.name, job.pos[1], job.pos[2], job.module.kind))
    job.module.failed = true
    local j = 1
    while b.queue[j] do
      if b.queue[j].module == job.module then table.remove(b.queue, j) else j = j + 1 end
    end
    return
  end
  -- Built when no entity job of the module is left (road tiles queued after it do not count: a module whose
  -- last job was paving was never marked, so it could never be captured, siege seed 777).
  local more = false
  for _, q in ipairs(b.queue) do
    if q.module == job.module and not q.tiles then more = true; break end
  end
  if not more and not job.module.built then
    job.module.built = true
    trace(b, string.format("built %s at %.0f,%.0f", job.module.kind, job.module.center[1], job.module.center[2]))
    -- The drop escort steps off once the pad is laid (spawned on landing, it stood where the pad's pylon goes).
    if job.module.kind == "pad" and b.escort_due then
      army.escort(b, b.escort_due)
      b.escort_due = nil
      base.corner_turrets(b)
    end
  end
end

-- A faction entity died: queue its rebuild at the same spot (nothing is rebuilt once the settlement fell).
function base.on_died(e, by)
  local own = storage.owner[e.unit_number]
  if not own then return end
  storage.owner[e.unit_number] = nil
  local b = storage.bases[own.base]
  local kind = shared.kind_of(e.name)
  if not b or b.fallen or kind == "lp-lander" or kind == "lp-uplink" then return end
  b.lost = b.lost + 1
  -- A lapsed claim (road.lua) is not rebuilt: it is there to take.
  if own.module and own.module.lapsed then return end
  army.alarm(b, e.position, trace)
  local d = 0
  if b.lander.valid then
    d = math.sqrt((e.position.x - b.lander.position.x) ^ 2 + (e.position.y - b.lander.position.y) ^ 2)
  end
  -- The invisible constructor's travel (a second a tile); where a crew goes (crew.lua), the crew travels instead.
  local far = base.crew_far and base.crew_far(b, {e.position.x, e.position.y})
  local due = game.tick + REBUILD_DELAY + (far and 0 or math.floor(d / REBUILD_TILES_PER_SECOND * 60))
  -- Generators come back in 90 s wherever they stand: a lander's hull holds while half of them do (hull).
  if kind == "lp-generator" then due = game.tick + 90 * 60 end
  -- (Tried and withdrawn, 2026-10-19: what a player destroyed of Grubstake's defence put back slowly, to wear a camp
  -- down. The parts it did not spend on them went into units: a bigger garrison held three camps of four that had all
  -- fallen before, the factory, four seeds.)
  -- What makes parts and power (generators, fabricators, drills, pylons) goes to the front: queued behind 20 walls, a
  -- camp's two generators were still waiting at the end, its hull down (loot).
  table.insert(b.rebuild, ECONOMY[kind] and 1 or #b.rebuild + 1, {name = kind, pos = {e.position.x, e.position.y},
    dir = e.direction, module = own.module, due = due})
  -- An outpost attacked earns a turret pair whatever the doctrine (the "defend" rule): a single medium biter cleared
  -- whole Grubstake outposts, whose sprawl doctrine never builds them (the user, in game, 2026-10-14).
  if own.module and own.module.kind == "mining" then own.module.attacked = true end
  trace(b, string.format("lost %s at %.0f,%.0f to %s: rebuild due at %d", e.name, e.position.x, e.position.y,
    by or "nothing", due))
end

-- Saves from before pylon spots knew their module (layout.connect): spots with no pylon and no pylon job at them are
-- dropped (a module given up left its spots as anchors), and a mining module whose pylon stands off the lander's
-- network is wired to the nearest pylon on it (the user's copper mine, chained to a coal mine never built).
function base.heal_lines()
  for _, b in pairs(storage.bases or {}) do
    if not b.fallen and b.lander and b.lander.valid and b.pylon_spots then
      local s, pylons = b.lander.surface, shared.variants("lp-pylon")
      local queued = {}
      for _, list in ipairs({b.queue, b.rebuild or {}}) do
        for _, j in ipairs(list) do
          if j.name == "lp-pylon" and j.pos then queued[string.format("%.1f,%.1f", j.pos[1], j.pos[2])] = true end
        end
      end
      local kept, dropped = {}, 0
      for _, p in ipairs(b.pylon_spots) do
        if p.m or queued[string.format("%.1f,%.1f", p[1], p[2])]
          or s.count_entities_filtered{name = pylons, position = {p[1], p[2]}, radius = 0.6, limit = 1} > 0 then
          kept[#kept + 1] = p
        else
          dropped = dropped + 1
        end
      end
      b.pylon_spots = kept
      local net, healed, fixing = base.network(b), 0, {}
      for _, m in ipairs(b.modules or {}) do
        local pylon
        if net and m.kind == "mining" and not (m.abandoned or m.failed) then
          for _, e in ipairs(m.entities or {}) do
            if e.valid and e.type == "electric-pole" then pylon = e; break end
          end
        end
        if pylon and pylon.electric_network_id ~= net and not fixing[pylon.electric_network_id] then
          fixing[pylon.electric_network_id] = true
          local best, bd
          for _, p in pairs(s.find_entities_filtered{name = pylons, force = pylon.force, position = pylon.position,
            radius = 400}) do
            if p.electric_network_id == net then
              local d = (p.position.x - pylon.position.x) ^ 2 + (p.position.y - pylon.position.y) ^ 2
              if not bd or d < bd then best, bd = p, d end
            end
          end
          if best then
            local a, x, y = best.position, pylon.position.x, pylon.position.y
            local n = math.ceil(math.sqrt(bd) / (shared.PYLON_REACH - 5)) - 1
            for i = 1, n do
              local t = i / (n + 1)
              local pt = {a.x + (x - a.x) * t, a.y + (y - a.y) * t}
              table.insert(b.queue, {name = "lp-pylon", pos = pt, loose = true, module = m})
              table.insert(b.pylon_spots, {pt[1], pt[2], m = m})
            end
            m.crew_ok, m.crew_route = nil, nil
            healed = healed + 1
          end
        end
      end
      if dropped > 0 or healed > 0 then
        trace(b, string.format("lines healed: %d stale pylon spots dropped, %d stranded mines rewired", dropped, healed))
      end
    end
  end
end
return {build = build, rebuild = rebuild}
end

return construction
