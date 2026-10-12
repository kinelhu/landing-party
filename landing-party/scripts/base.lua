-- A base: its economy (bins -> feedstock -> fabricators -> parts), its builder (a queue of entities
-- paid in parts) and its planner (the first rule that applies queues a module).
local shared = require("__landing-party__.shared")
local modules = require("__landing-party__.scripts.modules")
local site = require("__landing-party__.scripts.site")
local layout = require("__landing-party__.scripts.layout")

local base = {}

local ECONOMY_TICKS = 60
local BUILD_TICKS = 90
local PLAN_TICKS = 300
local START_PARTS = 150
-- A new mining module sits within reach of the network; the base looks further only when nothing nearer
-- fits (a long pylon line out to a distant patch is how it sprawls).
local REACHES = {40, 90, 160}
local SEARCH = 200           -- ore search radius around the lander
local DEFENCE_RADIUS = 14
-- A destroyed node is rebuilt unless a hostile turret, unit, vehicle, wall or character stands this close.
-- Walls do not count: occupation needs a military presence, not a cheap barrier.
local OCCUPY_RADIUS = 12
local OCCUPIERS = {"character", "ammo-turret", "electric-turret", "fluid-turret", "artillery-turret", "unit",
  "car", "spider-vehicle"}
-- A rebuild waits for its constructor: a fixed delay plus travel from the lander.
local REBUILD_DELAY = 60 * 60
local REBUILD_TILES_PER_SECOND = 1
local EMA = 0.1              -- smoothing of the per-minute rates, per economy tick

-- Feedstock one fabricator consumes per minute.
local FAB_FEED_PER_MIN = 60 * shared.FABRICATOR_SPEED / shared.PART_SECONDS * shared.FEEDSTOCK_PER_PART

local function force() return game.forces[shared.FORCE] end

local function trace(b, text)
  local line = string.format("%8d base %d  %s", game.tick, b.id, text)
  if storage.trace then helpers.write_file("landing-party/decisions.txt", line .. "\n", true) end
  table.insert(b.log, line)
  if #b.log > 30 then table.remove(b.log, 1) end
end
base.trace = trace

local LISTS = {["lp-pylon"] = "pylons", ["lp-bin"] = "bins", ["lp-drill"] = "drills",
  ["lp-fabricator"] = "fabs", ["lp-generator"] = "gens", ["lp-turret"] = "turrets", ["lp-radar"] = "radars",
  ["lp-wall"] = "walls", ["lp-depot"] = "depots"}

local function register(b, e, module)
  local list = LISTS[e.name]
  if list then table.insert(b[list], e) end
  if module then table.insert(module.entities, e) end
  storage.owner[e.unit_number] = {base = b.id, module = module}
end

local function prune(list)
  local j = 0
  for i = 1, #list do
    if list[i].valid then j = j + 1; list[j] = list[i] end
  end
  for i = #list, j + 1, -1 do list[i] = nil end
end

local function clear_area(surface, name, pos)
  local cb = prototypes.entity[name].collision_box
  local area = {{pos[1] + cb.left_top.x - 0.5, pos[2] + cb.left_top.y - 0.5},
    {pos[1] + cb.right_bottom.x + 0.5, pos[2] + cb.right_bottom.y + 0.5}}
  for _, e in pairs(surface.find_entities_filtered{area = area, type = {"tree", "simple-entity"}}) do e.destroy() end
end

-- Land a settlement near pos. opts: seed, doctrine (else drawn from the seed).
function base.land(surface, pos, opts)
  opts = opts or {}
  local f = force()
  surface.request_to_generate_chunks(pos, 7)
  surface.force_generate_chunk_requests()
  local id = storage.next_id
  local b = {id = id, surface = surface.index, parts = START_PARTS, feedstock = 0, made = 0, mined = 0,
    rate_in = 0, rate_parts = 0, pylons = {}, bins = {}, drills = {}, fabs = {}, gens = {}, turrets = {},
    radars = {}, walls = {}, depots = {}, pylon_spots = {}, road_tiles = 0,
    modules = {}, cells = {}, queue = {}, rebuild = {}, lost = 0, rebuilt = 0,
    rule = "landed", log = {}, waiting = nil}
  local seed = opts.seed or (surface.map_gen_settings.seed + 7919 * id + 31 * math.floor(pos[1]) + math.floor(pos[2]))
  layout.init(b, seed, opts.doctrine)
  local at = layout.land(b, surface, pos)
  if not at then return nil end
  clear_area(surface, "lp-lander", at)
  local lander = surface.create_entity{name = "lp-lander", position = at, force = f}
  if not lander then return nil end
  storage.next_id = id + 1
  b.lander = lander
  b.origin = {x = math.floor(lander.position.x), y = math.floor(lander.position.y)}
  storage.bases[id] = b
  b.label = rendering.draw_text{text = "", surface = surface, target = {entity = lander, offset = {0, -5}},
    color = {0.7, 0.9, 1}, scale = 1.4, alignment = "center"}.id
  trace(b, string.format("landed at %.0f,%.0f: doctrine %s, first hub %s", at[1], at[2], b.doctrine,
    b.hubs[1].archetype))
  return b
end

-- The base's network is the lander's: whatever is cut off from it stops counting.
function base.network(b)
  return b.lander.valid and b.lander.electric_network_id or nil
end

-- Bins on the network empty into feedstock; fabricators are fed feedstock and emptied of parts.
local function economy(b)
  local net = base.network(b)
  local gained, made = 0, 0
  prune(b.bins); prune(b.fabs)
  for _, bin in ipairs(b.bins) do
    local inv = bin.get_inventory(defines.inventory.chest)
    local n = inv.get_item_count()
    -- A bin counts only while its drills share the lander's network (cut the line, lose the income).
    if n > 0 and net then
      local p = bin.surface.find_entities_filtered{name = "lp-pylon", position = bin.position, radius = 5, limit = 1}[1]
      if p and p.electric_network_id == net then inv.clear(); gained = gained + n end
    end
  end
  b.feedstock = b.feedstock + gained
  b.mined = b.mined + gained
  local per = 2 * shared.FEEDSTOCK_PER_PART
  for _, fab in ipairs(b.fabs) do
    local input = fab.get_inventory(defines.inventory.crafter_input)
    local want = per - input.get_item_count("lp-feedstock")
    local give = math.min(want, b.feedstock)
    if give > 0 then b.feedstock = b.feedstock - input.insert{name = "lp-feedstock", count = give} end
    local out = fab.get_inventory(defines.inventory.crafter_output)
    local c = out.get_item_count("lp-part")
    if c > 0 then out.remove{name = "lp-part", count = c}; made = made + c end
  end
  b.parts = b.parts + made
  b.made = b.made + made
  local k = 3600 / ECONOMY_TICKS
  b.rate_in = (1 - EMA) * b.rate_in + EMA * gained * k
  b.rate_parts = (1 - EMA) * b.rate_parts + EMA * made * k
end

-- Wire a new pylon to every other network within reach, nearest first. The engine's auto-connect on a
-- scripted pylon left rebuilt lines dangling (seed 34: three rebuilt line pylons joined nothing).
local function join(e)
  local copper = defines.wire_connector_id.pole_copper
  local mine = e.get_wire_connector(copper, true)
  local near = e.surface.find_entities_filtered{name = "lp-pylon", force = e.force, position = e.position,
    radius = shared.PYLON_REACH}
  table.sort(near, function(a, c)
    local da = (a.position.x - e.position.x) ^ 2 + (a.position.y - e.position.y) ^ 2
    local dc = (c.position.x - e.position.x) ^ 2 + (c.position.y - e.position.y) ^ 2
    if da ~= dc then return da < dc end
    return a.unit_number < c.unit_number
  end)
  for _, p in ipairs(near) do
    if p ~= e and p.electric_network_id ~= e.electric_network_id then
      mine.connect_to(p.get_wire_connector(copper, true), true, defines.wire_origin.script)
    end
  end
end

-- Lay road tiles, never over water or an existing road.
local function pave(b, tiles)
  local surface = game.surfaces[b.surface]
  local out = {}
  for _, t in ipairs(tiles) do
    local tile = surface.get_tile(t[1], t[2])
    if tile.valid and tile.name ~= "lp-road" and not tile.collides_with("water_tile") then
      table.insert(out, {name = "lp-road", position = t})
    end
  end
  if #out > 0 then surface.set_tiles(out, true, false, true, false) end
  b.road_tiles = b.road_tiles + #out
end

-- Place one entity for a job. Returns the entity, or nil when the spot is blocked.
local function place(b, job)
  local surface = game.surfaces[b.surface]
  local pos = job.pos
  clear_area(surface, job.name, pos)
  if job.loose then pos = surface.find_non_colliding_position(job.name, pos, 4, 0.5) or pos end
  local ok = surface.can_place_entity{name = job.name, position = pos, direction = job.dir, force = force()}
  local e = ok and surface.create_entity{name = job.name, position = pos, direction = job.dir, force = force(),
    auto_connect = (job.name == "lp-pylon") or nil}
  if not e then return nil end
  b.parts = b.parts - (shared.cost[job.name] or 0)
  register(b, e, job.module)
  if b.lander.valid then
    rendering.draw_line{from = b.lander, to = e, surface = surface, color = {0.5, 0.8, 1, 0.6}, width = 1,
      time_to_live = BUILD_TICKS}
  end
  if job.name == "lp-pylon" then join(e) end
  if job.name == "lp-pylon" and base.network(b) and e.electric_network_id ~= base.network(b) then
    trace(b, string.format("pylon at %.1f,%.1f did not join the network", e.position.x, e.position.y))
  end
  return e
end

-- Forces whose presence occupies ground: every force the faction is at war with, biters excepted.
local function occupied(surface, pos)
  local f = force()
  for _, other in pairs(game.forces) do
    if other ~= f and other.name ~= "enemy" and other.name ~= "neutral" and not f.get_cease_fire(other)
      and surface.count_entities_filtered{position = pos, radius = OCCUPY_RADIUS, force = other,
        type = OCCUPIERS, limit = 1} > 0 then
      return true
    end
  end
  return false
end
base.occupied = occupied
site.occupied = occupied

-- Rebuild first: the first lost entity whose ground is free. Occupied ground waits.
local function rebuild(b)
  local surface = game.surfaces[b.surface]
  for i, job in ipairs(b.rebuild) do
    if game.tick < job.due then
      -- still on its way
    elseif occupied(surface, job.pos) then
      if not job.occupied then job.occupied = true; trace(b, string.format("cannot rebuild %s at %.0f,%.0f: occupied",
        job.name, job.pos[1], job.pos[2])) end
    else
      job.occupied = nil
      if b.parts < (shared.cost[job.name] or 0) then b.waiting = job.name; return true end
      table.remove(b.rebuild, i)
      if place(b, job) then
        b.rebuilt = b.rebuilt + 1
        trace(b, string.format("rebuilt %s at %.0f,%.0f", job.name, job.pos[1], job.pos[2]))
      else
        trace(b, string.format("cannot rebuild %s at %.0f,%.0f: blocked", job.name, job.pos[1], job.pos[2]))
      end
      return true
    end
  end
  return false
end

-- Place the next queued entity if parts allow. A failed key entity abandons the rest of its module.
local function build(b)
  if rebuild(b) then return end
  -- Road tiles cost nothing and take no build step.
  while b.queue[1] and b.queue[1].tiles do pave(b, table.remove(b.queue, 1).tiles) end
  local job = b.queue[1]
  if not job then return end
  local cost = shared.cost[job.name] or 0
  if b.parts < cost then b.waiting = job.name; return end
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
  if #b.queue == 0 or b.queue[1].module ~= job.module then
    job.module.built = true
    trace(b, string.format("built %s at %.0f,%.0f", job.module.kind, job.module.center[1], job.module.center[2]))
  end
end

-- A faction entity died: queue its rebuild at the same spot.
function base.on_died(e)
  local own = storage.owner[e.unit_number]
  if not own then return end
  storage.owner[e.unit_number] = nil
  local b = storage.bases[own.base]
  if not b or e.name == "lp-lander" then return end
  b.lost = b.lost + 1
  local d = 0
  if b.lander.valid then
    d = math.sqrt((e.position.x - b.lander.position.x) ^ 2 + (e.position.y - b.lander.position.y) ^ 2)
  end
  local due = game.tick + REBUILD_DELAY + math.floor(d / REBUILD_TILES_PER_SECOND * 60)
  table.insert(b.rebuild, {name = e.name, pos = {e.position.x, e.position.y}, dir = e.direction, module = own.module,
    due = due})
  trace(b, string.format("lost %s at %.0f,%.0f: rebuild due at %d", e.name, e.position.x, e.position.y, due))
end

-- Queue a free-standing module (mining, outpost turrets). Mining modules lay the road spine beside them.
local function enqueue(b, m, origin, cx, cy)
  local ox, oy = origin[1], origin[2]
  local module = {kind = m.kind, center = {ox + (m.box[1] + m.box[3]) / 2, oy + (m.box[2] + m.box[4]) / 2},
    entities = {}}
  table.insert(b.modules, module)
  local first = m.entities[1]
  layout.connect(b, ox + first[2], oy + first[3], module)
  for _, s in ipairs(m.entities) do
    table.insert(b.queue, {name = s[1], pos = {ox + s[2], oy + s[3]}, dir = s[4], module = module})
  end
  if cx then
    -- The spine column next to this cell (every fourth column of the lattice is left as road).
    local L = modules.MINING_LATTICE
    local sc = cx % 4 == 2 and cx + 1 or (cx % 4 == 0 and cx - 1 or nil)
    if sc then
      local x0, y0 = b.origin.x + sc * L.x, b.origin.y + cy * L.y
      local t = {}
      for x = x0, x0 + L.x - 1 do for y = y0, y0 + L.y - 1 do table.insert(t, {x, y}) end end
      table.insert(b.queue, {tiles = t, module = module})
    end
  end
  return module
end

local function power(b)
  local supply, demand = 0, 0
  if b.lander.valid then supply = supply - shared.power["lp-lander"] end
  prune(b.gens); prune(b.drills); prune(b.turrets); prune(b.radars)
  supply = supply - #b.gens * shared.power["lp-generator"]
  demand = #b.drills * shared.power["lp-drill"] + #b.fabs * shared.power["lp-fabricator"]
    + #b.turrets * shared.power["lp-turret"] + #b.radars * shared.power["lp-radar"]
  return supply, demand
end

-- A node (lander, generator, fabricator, mining) with no turret near it.
local function undefended(b)
  local surface = game.surfaces[b.surface]
  for _, m in ipairs(b.modules) do
    if m.built and m.kind == "mining" and not m.defended then
      if surface.count_entities_filtered{name = "lp-turret", position = m.center, radius = DEFENCE_RADIUS} > 0 then
        m.defended = true
      else
        return m
      end
    end
  end
end

-- Queue a slot's entity (a fabricator or generator in a block), or open a block for it.
local function fill(b, role, entity)
  local slot, block = layout.slot(b, role, entity)
  if slot then
    slot.queued = true
    table.insert(b.queue, {name = entity, pos = slot.pos, slot = slot, module = block})
    return string.format("%s in %s block at %.0f,%.0f", entity, role, block.center[1], block.center[2])
  end
  if block then return string.format("opened %s block at %.0f,%.0f", block.kind, block.center[1], block.center[2]) end
end

-- Where the threat comes from: the nearest player-force building, else the player force's spawn.
local function threat(b)
  local surface = game.surfaces[b.surface]
  local p = game.forces.player
  local e = surface.find_nearest_enemy{position = b.lander.position, max_distance = 400, force = force()}
  if e then return {e.position.x, e.position.y} end
  local s = p.get_spawn_position(surface)
  return {s.x, s.y}
end

-- The planner's rules, in priority order. The first that applies and finds a place acts.
local function plan(b)
  local surface = game.surfaces[b.surface]
  local doc = layout.DOCTRINES[b.doctrine]
  local supply, demand = power(b)
  -- What awaits a rebuild still counts: the base knows what it lost and will replace it.
  local owed = {}
  for _, job in ipairs(b.rebuild) do owed[job.name] = (owed[job.name] or 0) + 1 end
  for _, job in ipairs(b.queue) do if job.name then owed[job.name] = (owed[job.name] or 0) + 1 end end
  local fab_cap = (#b.fabs + (owed["lp-fabricator"] or 0)) * FAB_FEED_PER_MIN
  supply = supply - (owed["lp-generator"] or 0) * shared.power["lp-generator"]
  local function mining()
    for _, reach in ipairs(REACHES) do
      local o, _, cx, cy = site.mining(surface, b, reach, SEARCH)
      if o then
        enqueue(b, modules.mining, o, cx, cy)
        return string.format("mining at %d,%d", o[1], o[2])
      end
    end
  end
  local function hub_needing(pred)
    for _, h in ipairs(b.hubs) do if pred(h) then return h end end
  end
  local rules = {
    {"power", function() return demand + 200000 > 0.9 * supply end, function() return fill(b, "gen", "lp-generator") end},
    -- Fabrication follows the flow of ore, never the stock: a backlog left by a raid is worked off by the
    -- fabricators the base has, not answered with more (a raid once doubled them).
    {"fabricate", function() return b.rate_in > fab_cap * 1.1 and b.rate_in > 0 end,
      function() return fill(b, "fab", "lp-fabricator") end},
    {"mine", function() return b.rate_in < fab_cap * 0.8 or #b.drills + (owed["lp-drill"] or 0) == 0 end, mining},
    -- Walls wait for a working economy: spent first, they starved a settlement that had no fabricator yet.
    {"fortify", function() return b.parts > 80 and #b.fabs > 0 end, function()
      local block = layout.fortify(b)
      return block and string.format("walls round %s at %.0f,%.0f", block.kind, block.center[1], block.center[2]) end},
    {"defend", function() b.target = doc.outpost_turrets and undefended(b); return b.target ~= nil and b.target ~= false end,
      function()
        local o = site.near(surface, b, modules.turrets, b.target.center[1], b.target.center[2], 3, 12)
        if not o then b.target.defended = "no site"; return end
        b.target.defended = true
        enqueue(b, modules.turrets, o)
        return string.format("turrets at %d,%d", o[1], o[2])
      end},
    {"picket", function() b.target = hub_needing(function(h) return h.pickets < doc.pickets end); return b.target ~= nil end,
      function()
        local block = layout.picket(b, b.target, threat(b))
        return block and string.format("picket at %.0f,%.0f", block.center[1], block.center[2]) end},
    {"depot", function()
      b.target = hub_needing(function(h) return h.count >= 3 and not h.depot end); return b.target ~= nil end,
      function()
        b.target.depot = true
        local block = layout.open_role(b, "depot")
        return block and string.format("opened %s block at %.0f,%.0f", block.kind, block.center[1], block.center[2]) end},
    {"grow", function() return b.parts > 100 end, mining},
  }
  for _, r in ipairs(rules) do
    if r[2]() then
      local did = r[3]()
      if did then
        b.rule = r[1]
        trace(b, string.format("rule %s -> %s (parts %d, feed %d, in %.0f/min, fab cap %.0f, power %.1f/%.1f MW)",
          r[1], did, b.parts, b.feedstock, b.rate_in, fab_cap, demand / 1e6, supply / 1e6))
        return
      end
      if r[1] ~= "fortify" then trace(b, "rule " .. r[1] .. " applies but no site fits") end
    end
  end
  b.rule = "idle"
end

local function label(b)
  local o = rendering.get_object_by_id(b.label)
  if not o then return end
  local supply, demand = power(b)
  o.text = string.format("%s | parts %d | feed %d | in %.0f/min | parts %.1f/min | fabs %d drills %d | %.1f/%.1f MW",
    b.rule .. (b.waiting and (" (waiting: " .. b.waiting .. ")") or ""), b.parts, b.feedstock, b.rate_in,
    b.rate_parts, #b.fabs, #b.drills, demand / 1e6, supply / 1e6)
end

function base.tick(tick)
  for _, b in pairs(storage.bases) do
    if b.lander.valid then
      if tick % ECONOMY_TICKS == 0 then economy(b) end
      if tick % BUILD_TICKS == 0 then build(b) end
      if tick % PLAN_TICKS == 0 then
        local pending = false
        for _, job in ipairs(b.rebuild) do
          if not job.occupied and game.tick >= job.due then pending = true end
        end
        if #b.queue == 0 and not pending then plan(b) end
        label(b)
      end
    end
  end
end

function base.stats(b)
  prune(b.bins); prune(b.fabs); prune(b.pylons); prune(b.walls)
  local supply, demand = power(b)
  return {id = b.id, tick = game.tick, rule = b.rule, parts = b.parts, feedstock = b.feedstock, mined = b.mined,
    made = b.made, rate_in = b.rate_in, rate_parts = b.rate_parts, fabs = #b.fabs, drills = #b.drills,
    gens = #b.gens, turrets = #b.turrets, pylons = #b.pylons, modules = #b.modules, queue = #b.queue,
    lost = b.lost, rebuilt = b.rebuilt, rebuild_pending = #b.rebuild,
    doctrine = b.doctrine, hubs = #b.hubs, blocks = #b.blocks, walls = #b.walls, road_tiles = b.road_tiles,
    radars = #b.radars, archetypes = (function() local t = {} for _, h in ipairs(b.hubs) do
      table.insert(t, h.archetype) end return table.concat(t, ",") end)(),
    supply = supply, demand = demand, network = base.network(b), lander = b.lander.valid}
end

return base
