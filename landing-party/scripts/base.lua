-- A base: its economy (bins -> feedstock -> fabricators -> parts), its builder (a queue of entities
-- paid in parts) and its planner (the first rule that applies queues a module).
local shared = require("__landing-party__.shared")
local modules = require("__landing-party__.scripts.modules")
local site = require("__landing-party__.scripts.site")
local layout = require("__landing-party__.scripts.layout")
local chart = require("__landing-party__.scripts.chart")
local names = require("__landing-party__.scripts.names")
local blocks = require("__landing-party__.scripts.blocks")
local army = require("__landing-party__.scripts.army")
local rng = require("__landing-party__.scripts.rng")
local tune = require("__landing-party__.scripts.tune")
local ops = require("__landing-party__.scripts.ops")
local lights = require("__landing-party__.scripts.lights")
local landfx = require("__landing-party__.scripts.landfx")

local base = {}

local ECONOMY_TICKS = 60
local IDLE_RUN = 0.08              -- a starved fabricator's chance a second of a run from nothing (about one in 12 s)
local BUILD_TICKS = 90
local PLAN_TICKS = 300
-- Minutes of its making a queue may hold before its planner grows its mining past it (a named prior; base.tick).
local QUEUE_LONG = 5
local START_PARTS = 150
-- A new mining module sits within reach of the network; the base looks further only when nothing nearer
-- fits (a long pylon line out to a distant patch is how it sprawls).
local REACHES = {40, 90, 160}
local SEARCH = 200           -- ore search radius around the lander
local SITE_BUDGET = 12       -- candidate mining sites tested per plan
local UPLINK_PARTS = 3000    -- the uplink lands with these: its fortress is built at once
local UPLINK_BURST = 6       -- entities placed per build step while the uplink stands
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

local function force(b) return game.forces[b.force] end

local function trace(b, text)
  local line = string.format("%8d base %d  %s", game.tick, b.id, text)
  if storage.trace then helpers.write_file("landing-party/decisions.txt", line .. "\n", true) end
  table.insert(b.log, line)
  if #b.log > 30 then table.remove(b.log, 1) end
end
base.trace = trace

local LISTS = {["lp-pylon"] = "pylons", ["lp-bin"] = "bins", ["lp-drill"] = "drills",
  ["lp-fabricator"] = "fabs", ["lp-generator"] = "gens", ["lp-turret"] = "turrets", ["lp-radar"] = "radars",
  ["lp-wall"] = "walls", ["lp-depot"] = "depots", ["lp-launchpad"] = "launchpads", ["lp-lamp"] = "lamps",
  ["lp-mine"] = "mines", ["lp-flamer"] = "flamers", ["lp-scrap-cannon"] = "turrets", ["lp-gun-turret"] = "turrets",
  ["lp-optics-lab"] = "labs", ["lp-line-lab"] = "labs", ["lp-siege-lab"] = "labs"}

local function register(b, e, module)
  local list = LISTS[shared.kind_of(e.name)]
  -- Lists added after a settlement was saved are made on first use.
  if list then b[list] = b[list] or {}; table.insert(b[list], e) end
  if module then table.insert(module.entities, e) end
  storage.owner[e.unit_number] = {base = b.id, module = module}
  base.lab_look(e)
  -- A worked patch is cleared ground (the user, 2026-10-21: "a little deforestation around mining areas"): the trees and
  -- the scrub round a drill go with it, a few tiles past its mining area.
  if shared.kind_of(e.name) == "lp-drill" then
    local p = e.position
    for _, t in pairs(e.surface.find_entities_filtered{type = "tree", position = p, radius = 6}) do t.destroy() end
    e.surface.destroy_decoratives{area = {{p.x - 4, p.y - 4}, {p.x + 4, p.y + 4}}}
  end
end

-- Labs from before their body was drawn (0.1.40, 0.1.41): their old sign taken down, the look drawn whole.
function base.heal_labs()
  if storage.lab_look then return end
  storage.lab_look = {}
  local old = {}
  for _, b in pairs(storage.bases or {}) do
    for _, e in ipairs(b.labs or {}) do if e.valid then old[e.unit_number] = e end end
  end
  if not next(old) then return end
  for _, o in ipairs(rendering.get_all_objects(script.mod_name)) do
    local t = o.valid and (o.type == "sprite" or o.type == "animation") and o.target
    if t and t.entity and t.entity.valid and old[t.entity.unit_number] then o.destroy() end
  end
  for _, e in pairs(old) do base.lab_look(e) end
end

-- A lab's look: its body at work (data.lua: lp-lab-busy, drawn by script since its research is) and its sign, its branch,
-- over it, for everyone; both gone with it. Once a lab (labs from 0.1.40 got theirs on the update: init).
function base.lab_look(e)
  local icon = shared.LAB_ICON[shared.kind_of(e.name)]
  if not icon then return end
  storage.lab_look = storage.lab_look or {}
  if storage.lab_look[e.unit_number] then return end
  storage.lab_look[e.unit_number] = true
  -- Its own body at work where it has one (data.lua: <lab>-busy, a Space Age building's moving parts), else the vanilla lab's.
  -- (helpers.is_valid_animation_path: the runtime has no prototypes.animation, and indexing it crashed a lab's first
  -- placement from 0.2.173; labs and breach "passed" on stale results until sim.sh cleared them, 0.2.179.)
  local valid = helpers.is_valid_animation_path
  local own = valid(e.name .. "-busy") and e.name .. "-busy" or shared.kind_of(e.name) .. "-busy"
  local has = valid(own)
  rendering.draw_animation{animation = has and own or "lp-lab-busy", target = e, surface = e.surface,
    render_layer = "object", animation_speed = has and 1 / 2 or 1 / 3}
  rendering.draw_sprite{sprite = icon, target = {entity = e, offset = {0, -2.8}}, surface = e.surface, x_scale = 1.2,
    y_scale = 1.2, render_layer = "air-object"}
end

-- Drop what is gone or no longer the faction's (a captured drill stays valid, on another force).
local function prune(list)
  local j = 0
  for i = 1, #list do
    if list[i].valid and shared.is_corp(list[i].force.name) then j = j + 1; list[j] = list[i] end
  end
  for i = #list, j + 1, -1 do list[i] = nil end
end

local function clear_area(surface, name, pos, b)
  local cb = prototypes.entity[name].collision_box
  local area = {{pos[1] + cb.left_top.x - 0.5, pos[2] + cb.left_top.y - 0.5},
    {pos[1] + cb.right_bottom.x + 0.5, pos[2] + cb.right_bottom.y + 0.5}}
  -- Items on the ground too: a wreck's loot lies where it stood, and a rebuild could not be placed over it (occupy, defend).
  -- What the player has not picked up by then, the corporation reclaims.
  for _, e in pairs(surface.find_entities_filtered{area = area, type = {"tree", "simple-entity", "item-entity"}}) do e.destroy() end
  -- A town's junk where it builds (shared.DECOR_PROPS).
  for _, e in pairs(surface.find_entities_filtered{area = area, force = "neutral"}) do
    if shared.DECOR_PROPS[e.name] then e.destroy() end
  end
  -- Cliffs in its way blown up (shared.blast); water under it filled, by a corporation that fills (shared.landfill).
  shared.blast(surface, area, b)
  if shared.fills(b) then
    local t = {}
    for x = math.floor(area[1][1]), math.ceil(area[2][1]) - 1 do
      for y = math.floor(area[1][2]), math.ceil(area[2][2]) - 1 do t[#t + 1] = {x, y} end
    end
    shared.landfill(surface, t, b)
  end
end

-- Land a settlement near pos. opts: seed, doctrine (else drawn from the seed).
function base.land(surface, pos, opts)
  opts = opts or {}
  local corp = opts.corp or shared.DEFAULT_CORP
  local f = game.forces[shared.CORPS[corp].force]
  -- The settlement's whole reach, generated now: the planner's scan reads ore and terrain from it (generating
  -- only the core and queueing the rest changed where outposts went, and three outpost scenarios failed).
  surface.request_to_generate_chunks(pos, 7)
  surface.force_generate_chunk_requests()
  local id = storage.next_id
  local b = {id = id, surface = surface.index, parts = START_PARTS, feedstock = 0, made = 0, mined = 0,
    rate_in = 0, rate_parts = 0, pylons = {}, bins = {}, drills = {}, fabs = {}, gens = {}, turrets = {},
    radars = {}, walls = {}, depots = {}, launchpads = {}, lamps = {}, mines = {}, flamers = {}, pylon_spots = {}, road_tiles = 0,
    modules = {}, cells = {}, queue = {}, rebuild = {}, lost = 0, rebuilt = 0, corp = corp, force = f.name,
    rule = "landed", log = {}, waiting = nil, landed = game.tick}
  -- (storage.seed_salt: tests' replicates of one save, a visit's LP_MIX=seedN; none in play.)
  local seed = opts.seed or (surface.map_gen_settings.seed + 7919 * id + 31 * math.floor(pos[1]) + math.floor(pos[2])
    + 104729 * (storage.seed_salt or 0))
  layout.init(b, seed, (opts.uplink or opts.armed) and "fortress" or opts.doctrine, shared.CORPS[corp].doctrines)
  army.init(b)
  local at, _, uplink_at
  if opts.uplink or opts.armed then
    at, _, uplink_at = layout.land_fortress(b, surface, pos, opts.armed)
    if at then
      b.parts = b.parts + UPLINK_PARTS
      -- The uplink brings construction capacity: its fortress (~650 entities) took 16 minutes one at a time.
      b.burst = UPLINK_BURST
      b.fortress_planned = {}
      for _, e in ipairs(layout.fortress_entities(b.blocks[1].x0, b.blocks[1].y0)) do
        b.fortress_planned[e[1]] = (b.fortress_planned[e[1]] or 0) + 1
      end
      b.armed = opts.armed or nil
    elseif opts.armed then
      -- No square for its fortress: a camp as any other (faction.arrive's armed landing).
      at = layout.land(b, surface, pos)
    end
  else
    at = layout.land(b, surface, pos)
  end
  if not at then return nil end
  clear_area(surface, shared.variant(corp, "lp-lander"), at)
  local lander = surface.create_entity{name = shared.variant(corp, "lp-lander"), position = at, force = f}
  if not lander then return nil end
  storage.next_id = id + 1
  b.lander = lander
  if uplink_at and opts.uplink then
    clear_area(surface, shared.variant(corp, "lp-uplink"), uplink_at)
    b.uplink = surface.create_entity{name = shared.variant(corp, "lp-uplink"), position = uplink_at, force = f}
    lights.attach(b.uplink, corp)
  end
  b.origin = {x = math.floor(lander.position.x), y = math.floor(lander.position.y)}
  base.claim_map(b)
  storage.bases[id] = b
  site.scan_init(b, SEARCH)
  if not opts.uplink then base.drop_power(b) end
  -- Its crash and the pods that follow it down (landfx.lua): drawn, nothing placed.
  landfx.crash(b)
  -- A developer's readout (its rule, parts, flow, power): shown only while tracing (dev, the sims); it had hung over
  -- every lander in every game (seen in the field guide's screenshots, 2026-10-24).
  b.label = rendering.draw_text{text = "", surface = surface, target = {entity = lander, offset = {0, -5}},
    color = {0.7, 0.9, 1}, scale = 1.4, alignment = "center", visible = storage.trace == true}.id
  trace(b, string.format("landed at %.0f,%.0f%s: doctrine %s, first hub %s", at[1], at[2], b.armed and " armed (its fortress)" or "",
    b.doctrine, b.hubs[1].archetype))
  return b
end

-- The landing burns a clearing (the user: "a landing could significantly damage/destroy nests and biters in a
-- radius"): spawners, worms and biters within CLEAR_RADIUS of a new lander are destroyed, the corporation's kills (so
-- the spawners' evolution is refunded, biters.lua), with explosions where they stood; the players are told.
local CLEAR_RADIUS = 80
function base.clear_landing(b)
  local s = b.lander.surface
  local c = b.lander.position
  local f = b.lander.force
  local nests = 0
  for _, e in pairs(s.find_entities_filtered{position = c, radius = CLEAR_RADIUS, force = "enemy",
    type = {"unit-spawner", "turret", "unit"}}) do
    if e.valid then
      if e.type ~= "unit" then
        nests = nests + 1
        s.create_entity{name = "big-explosion", position = e.position}
      end
      e.die(f, b.lander)
    end
  end
  s.create_entity{name = "massive-explosion", position = c}
  b.cleared = nests
  if nests > 0 then
    trace(b, string.format("the landing burned a clearing: %d nests and worms destroyed", nests))
    for _, pf in pairs(game.forces) do
      if #pf.players > 0 and not shared.is_corp(pf.name) then
        shared.notice(pf, {"lp.landing-cleared", shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", c.x, c.y, s.name), nests})
      end
    end
  end
end

-- The drop escort's turrets (docs/reviews/2026-10-14-hull-consult.md): four gun turrets at the pad's corners,
-- fed from the settlement's stock (they are in b.turrets), so a camp is not bare for its first twenty minutes.
-- They are the drop's, not the settlement's: never rebuilt, and packed up CAMP_TICKS after landing (kept, they
-- made every young settlement too strong for a rival's raids, and two corporations never fought: rivals).
local CAMP_TICKS = 20 * 3600
-- The drop's power: two generators beside the lander from the moment it lands, so its hull holds (half its counted
-- generators standing; the player's artillery does not fire at generators by itself). Landed under a megabase's guns,
-- camps with none were shelled to death in 25 seconds, five of five (visit). The planner's own come later; these give
-- way to what it builds (make_way).
function base.drop_power(b)
  local s = b.lander.surface
  local name = shared.variant(b.corp, "lp-generator")
  local x, y = b.lander.position.x, b.lander.position.y
  b.drop_gens = {}
  for _, dx in ipairs({-6, 6}) do
    local p = s.find_non_colliding_position(name, {x + dx, y + blocks.SIZE / 2 + 4}, 8, 1)
    local g = p and s.create_entity{name = name, position = p, force = b.lander.force}
    if g then
      register(b, g, nil)
      table.insert(b.drop_gens, g)
    end
  end
end

function base.corner_turrets(b)
  local s = b.lander.surface
  -- The corporation's own turret where it is a gun turret (Grubstake's), else the default gun turret.
  local name = shared.variant(b.corp, "lp-turret")
  if prototypes.entity[name].type ~= "ammo-turret" then name = "lp-gun-turret" end
  local x, y = b.lander.position.x, b.lander.position.y
  for _, c in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
    local p = s.find_non_colliding_position(name, {x + c[1] * (blocks.PAD_W / 2 - 3), y + c[2] * (blocks.SIZE / 2 - 2)}, 4, 1)
    local t = p and s.create_entity{name = name, position = p, force = b.lander.force}
    if t then
      t.insert{name = "piercing-rounds-magazine", count = 20}
      table.insert(b.turrets, t)
      b.camp_turrets = b.camp_turrets or {}
      table.insert(b.camp_turrets, t)
    end
  end
end

local function pack_camp(b)
  if not b.camp_turrets or game.tick - (b.landed or 0) < CAMP_TICKS then return end
  for _, t in ipairs(b.camp_turrets) do
    if t.valid then
      for i = #b.turrets, 1, -1 do if b.turrets[i] == t then table.remove(b.turrets, i) end end
      t.destroy()
    end
  end
  b.camp_turrets = nil
  trace(b, "the drop's turrets packed up")
end

-- The base's network is the lander's: whatever is cut off from it stops counting.
-- Capture by holding: a mining outpost with hostile military on its ground (within OCCUPY_RADIUS of its
-- centre) and none of the faction's within CAPTURE_CLEAR for CAPTURE_TICKS changes hands, drills, bin and
-- pylon. No capture by damage (that is Proliferation's).
local CAPTURE_CLEAR = 20
local CAPTURE_TICKS = 60 * 60
-- Only the player's forces capture: a corporation's raid passing through a rival's outpost does not take it.
local function holder(b, surface, pos)
  local f = force(b)
  for _, other in pairs(game.forces) do
    if other ~= f and shared.is_player_force(other) and not f.get_cease_fire(other) then
      local e = surface.find_entities_filtered{position = pos, radius = OCCUPY_RADIUS, force = other, type = OCCUPIERS,
        limit = 1}[1]
      if e then return other end
    end
  end
end
-- What holds a module's ground: a turret there, or a unit of this settlement's own. Another camp's unit there does not
-- (an evacuee of the fallen camp, now its neighbour's, wandered by the ruins and kept every outpost from being taken,
-- fall).
local function defender(b, surface, center)
  local t = surface.find_entities_filtered{position = center, radius = CAPTURE_CLEAR, force = force(b),
    type = {"electric-turret", "ammo-turret"}, limit = 1}[1]
  if t then return t end
  for _, u in pairs(surface.find_entities_filtered{position = center, radius = CAPTURE_CLEAR, force = force(b),
    type = {"unit", "spider-unit"}, limit = 20}) do
    if not u.unit_number or (storage.unit_owner or {})[u.unit_number] == b.id then return u end
  end
end

local function capture(b)
  if storage.capture_off then return end
  local surface = game.surfaces[b.surface]
  for _, m in ipairs(b.modules) do
    local left = 0
    for _, e in ipairs(m.entities) do if e.valid and e.force.name == b.force then left = left + 1 end end
    -- Something must be left to take (a module with nothing standing was once "captured").
    if m.kind == "mining" and m.built and not m.captured and left > 0 then
      local by = holder(b, surface, m.center)
      local defended = defender(b, surface, m.center) ~= nil
      if by and not defended then
        -- Occupied: it calls for help as a building under fire does (an undefended outpost was taken by holding it,
        -- and the corporation never knew, siege).
        if not m.held_since then army.alarm(b, {x = m.center[1], y = m.center[2]}, trace) end
        m.held_since = m.held_since or game.tick
        if game.tick - m.held_since >= CAPTURE_TICKS then
          m.captured = by.name
          local n = 0
          for _, e in ipairs(m.entities) do
            if e.valid and e.force.name == b.force then
              storage.owner[e.unit_number] = nil
              e.force = by
              n = n + 1
            end
          end
          b.captured = (b.captured or 0) + 1
          if base.on_capture then base.on_capture(surface, m.center) end
          trace(b, string.format("captured by %s: mining at %.0f,%.0f (%d entities)", by.name, m.center[1], m.center[2], n))
        end
      else
        m.held_since = nil
      end
    end
  end
end

army.on_deliver = function(b, cargo) if base.on_export then base.on_export(b, cargo) end end

-- A faction building under fire: the depot answers (throttled in army.alarm).
function base.on_damaged(e)
  local own = storage.owner[e.unit_number]
  local b = own and storage.bases[own.base]
  -- A fallen settlement raises no alarm (damage in the tick its lander died crashed the intel, which read the
  -- surface through the dead lander).
  if b and not b.fallen and b.lander.valid then
    -- (When a player last hurt it: an expedition takes the place only of a camp left alone, director.lua.)
    if e.force and shared.is_player_force(e.force) then b.player_hit_at = game.tick end
    army.alarm(b, e.position, trace)
  end
end

-- A camp leaves (a director's expedition withdrawn, or the camp it replaced): its units and buildings lifted out,
-- quietly, no fall (no cascade, no ruins, no command cores: the lander destroyed, not killed). Marked fallen and
-- departed, so every loop over camps passes it by.
function base.depart(b, why)
  if b.fallen then return false end
  b.fallen, b.departed = game.tick, game.tick
  b.queue, b.rebuild, b.cascade = {}, {}, nil
  local function gone(u) if u and u.valid then u.destroy() end end
  for _, u in ipairs(b.garrison or {}) do gone(u) end
  -- (Every unit it owns, the roster: its patrols, escorts and pickets are in no other list; three stood on after it.)
  for _, u in pairs(b.roster or {}) do gone(u) end
  b.roster = {}
  if b.op then
    for _, u in ipairs(b.op.members or {}) do gone(u) end
    gone(b.op.hauler)
    b.op = nil
  end
  for _, c in ipairs(b.crews or {}) do gone(c.unit) end
  b.crews = {}
  for _, r in ipairs(b.raids or {}) do for _, u in ipairs(r.members or {}) do gone(u) end end
  b.raids = {}
  local n = 0
  for _, m in ipairs(b.modules or {}) do
    for _, e in ipairs(m.entities or {}) do if e.valid then n = n + 1; e.destroy() end end
    if m.marks then chart.clear(m.marks) end
  end
  for _, list in ipairs({b.turrets, b.gens, b.depots, b.pylons, b.walls, b.bins, b.fabs, b.drills}) do
    for _, e in ipairs(list or {}) do if e.valid then n = n + 1; e.destroy() end end
  end
  gone(b.lander)
  for _, t in pairs(b.tags or {}) do if t.valid then t.destroy() end end
  for _, o in ipairs({b.claim_fill, b.claim_edge}) do if o and o.valid then o.destroy() end end
  chart.clear(b.claim_marks)
  trace(b, string.format("departs (%s): %d buildings lifted out, no fall", why or "-", n))
  shared.event("departed", {base = b.id, corp = b.corp, why = why, at = {b.origin.x, b.origin.y}})
  return true
end

function base.network(b)
  return b.lander.valid and b.lander.electric_network_id or nil
end

-- Bins on the network empty into feedstock; fabricators are fed feedstock and emptied of parts.
-- Its lander's stores (the user, 2026-11-12: "Shouldn't we just put a base income in?"): while it has no fabricator, its
-- lander gives a fabricator's price every STORES_EVERY, so a camp that cannot make parts can always pay for what makes them.
-- (Every 5 minutes was too slow: a starved camp spent each on a generator and its walls' rebuilds, and had no fabricator
-- after 20 minutes; armed starved.)
-- Both of Kessler-Hayashi's camps on nwa, their walls shelled from landing and every part spent on rebuilds, made no part
-- in two hours (the visits at 0.2.359 to 0.2.361). Working camps are untouched.
local STORES_EVERY = 60 * 60
-- (And only once it has gone STORES_GRACE without one: from its landing, a minute's stores changed every young camp's
-- first minutes, the regression at 0.2.362.)
local STORES_GRACE = 5 * 3600
local function stores(b)
  if #b.fabs > 0 or not (b.lander and b.lander.valid) or storage.stores_off then b.stores_at = nil; return end
  b.stores_at = b.stores_at or (game.tick + STORES_GRACE - STORES_EVERY)
  if game.tick - b.stores_at >= STORES_EVERY then
    b.stores_at = game.tick
    b.parts = b.parts + shared.cost["lp-fabricator"]
    b.stores_given = (b.stores_given or 0) + 1
    trace(b, string.format("its lander's stores: %d parts, no fabricator standing", shared.cost["lp-fabricator"]))
  end
end

local function economy(b)
  stores(b)
  local net = base.network(b)
  local gained, made = 0, 0
  prune(b.bins); prune(b.fabs)
  for _, bin in ipairs(b.bins) do
    local inv = bin.get_inventory(defines.inventory.chest)
    local n = inv.get_item_count()
    -- A bin counts only while its drills share the lander's network (cut the line, lose the income).
    local own = storage.owner[bin.unit_number]
    if n > 0 and own and own.module and own.module.claim then
      -- A claim's ore: carried home by its trucks where the corporation has a road (road.lua), else counted at once.
      if not (shared.CORPS[b.corp].temper or {}).prospects then inv.clear(); gained = gained + n end
    elseif n > 0 and net then
      local p = bin.surface.find_entities_filtered{name = shared.variants("lp-pylon"), position = bin.position, radius = 5,
        limit = 1}[1]
      if p and p.electric_network_id == net then inv.clear(); gained = gained + n end
    end
  end
  b.feedstock = b.feedstock + gained
  b.mined = b.mined + gained
  local per = 2 * shared.FEEDSTOCK_PER_PART
  -- A starved fabricator still runs now and then (the user, 2026-10-21: "fabricators could run (even if faking it)
  -- intermittently"): a batch from nowhere, its part thrown away (b.idle_runs counts what is owed back to nothing).
  b.idle_runs = b.idle_runs or {}
  for _, fab in ipairs(b.fabs) do
    local input = fab.get_inventory(defines.inventory.crafter_input)
    local have = input.get_item_count("lp-feedstock")
    local want = per - have
    local give = math.min(want, b.feedstock)
    if give > 0 then b.feedstock = b.feedstock - input.insert{name = "lp-feedstock", count = give}
    elseif have == 0 and not fab.is_crafting() and rng.next(b.rng) < IDLE_RUN then
      if input.insert{name = "lp-feedstock", count = shared.FEEDSTOCK_PER_PART} > 0 then
        b.idle_runs[fab.unit_number] = (b.idle_runs[fab.unit_number] or 0) + 1
      end
    end
    local out = fab.get_inventory(defines.inventory.crafter_output)
    local c = out.get_item_count("lp-part")
    if c > 0 then
      out.remove{name = "lp-part", count = c}
      local idle = math.min(c, b.idle_runs[fab.unit_number] or 0)
      if idle > 0 then
        b.idle_runs[fab.unit_number] = (b.idle_runs[fab.unit_number] > idle) and (b.idle_runs[fab.unit_number] - idle) or nil
      end
      made = made + c - idle
    end
  end
  -- An armed camp's siege fund (faction.arrive's armed landing): its mind's siege_save of what it makes, up to the cost of
  -- the costliest siege it may send (base.siege_goal, set by siege.lua: the tier the player's era allows, a grudge and the
  -- ladder's top rung a tier more each; a flat 600, a tier 4, before), kept from its growth and units for its sieges
  -- (siege.lua siege_tier and launch_siege). Without it every siege of its on fed nw went at tier 1, one mortar against a
  -- laser wall of 557, its parts at launch 32 to 168 (2026-11-02).
  local save_share = b.armed and (shared.CORPS[b.corp].mind or {}).siege_save or 0
  local goal = save_share > 0 and base.siege_goal and base.siege_goal(b) or 0
  if made > 0 and (b.siege_fund or 0) < goal then
    local save = math.min(math.floor(made * save_share + 0.5), goal - (b.siege_fund or 0))
    b.siege_fund = (b.siege_fund or 0) + save
    made = made - save
    b.made = b.made + save
  end
  -- Its income lever (tune.income, times the difficulty preset): what its fabricators make, scaled, the fraction carried
  -- to the next look (no rounding by chance).
  if made > 0 then
    -- (What went into the lever and what came out, for its test: levers.)
    b.lever_in = (b.lever_in or 0) + made
    local scaled = made * tune.income(b.corp) + (b.income_carry or 0)
    made = math.floor(scaled)
    b.income_carry = scaled - made
    b.lever_out = (b.lever_out or 0) + made
  end
  b.parts = b.parts + made
  b.made = b.made + made
  -- (Flamers burn nothing: Grubstake's oil flamer was kept in light oil here until its oil was abstracted, 2026-11-11.)
  -- Gun turrets (a corporation's choice instead of lasers) are kept in ammunition: uranium rounds once the biters have
  -- evolved to 0.6, as a player's turrets would be by then, at 5 parts a refill of 20 (piercing when it cannot pay; the
  -- user, 2026-11-11: KH's strength scaled to the biters' evolution, by what it brings).
  local enemy = game.forces.enemy
  local URANIUM_COST, URANIUM_RESERVE = 5, 50
  local late = enemy and enemy.get_evolution_factor(b.surface) >= 0.6
  for _, t in ipairs(b.turrets) do
    if t.valid and t.type == "ammo-turret" then
      local inv = t.get_inventory(defines.inventory.turret_ammo)
      if inv and inv.get_item_count() < 20 then
        local ammo = "piercing-rounds-magazine"
        if shared.kind_of(t.name) == "lp-scrap-cannon" then
          ammo = "lp-scrap-shell"
        -- (Only from what it has over a reserve, URANIUM_RESERVE: paid down to its last part, a settlement landing at
        -- evolution 1 among nests spent 95 parts on 19 refills in 3 minutes and never built a fabricator, scenario
        -- clearing, 0.2.336.)
        elseif late and b.parts >= URANIUM_RESERVE + URANIUM_COST then
          ammo, b.parts = "uranium-rounds-magazine", b.parts - URANIUM_COST
          b.uranium_refills = (b.uranium_refills or 0) + 1
        end
        inv.insert{name = ammo, count = 20}
      end
    end
  end
  local k = 3600 / ECONOMY_TICKS
  b.rate_in = (1 - EMA) * b.rate_in + EMA * gained * k
  b.rate_parts = (1 - EMA) * b.rate_parts + EMA * made * k
end

-- Wire a new pylon to every other network within reach, nearest first. The engine's auto-connect on a
-- scripted pylon left rebuilt lines dangling (seed 34: three rebuilt line pylons joined nothing).
local function join(e)
  local copper = defines.wire_connector_id.pole_copper
  local mine = e.get_wire_connector(copper, true)
  local near = e.surface.find_entities_filtered{name = shared.variants("lp-pylon"), force = e.force, position = e.position,
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
  base.unwire(e)
end

-- Never wired to another force's pole: placed with auto_connect, a pylon was wired to a player pole within reach and the
-- two grids became one (the power tap's line ends 12 tiles from the player's pole: the camp ran on the player's power,
-- the user saw its drills in the player's network). Also called on the player's poles as they are built (control.lua).
function base.unwire(e)
  local mine = e.get_wire_connector(defines.wire_connector_id.pole_copper, false)
  if not mine then return end
  for _, c in ipairs(mine.connections) do
    if c.target.owner.force ~= e.force then mine.disconnect_from(c.target, c.origin) end
  end
end

-- Construction: scripts/construction.lua (split from here, 2026-10-18).
local construction_ = require("__landing-party__.scripts.construction").install(ops, {
  BUILD_TICKS = BUILD_TICKS, OCCUPIERS = OCCUPIERS, OCCUPY_RADIUS = OCCUPY_RADIUS, REBUILD_DELAY = REBUILD_DELAY,
  REBUILD_TILES_PER_SECOND = REBUILD_TILES_PER_SECOND, army = army, base = base, clear_area = clear_area,
  force = force, join = join, register = register, site = site, trace = trace})
local build, rebuild = construction_.build, construction_.rebuild
-- Planner: scripts/planner.lua (split from here, 2026-10-18).
local planner_ = require("__landing-party__.scripts.planner").install(ops, {
  DEFENCE_RADIUS = DEFENCE_RADIUS, FAB_FEED_PER_MIN = FAB_FEED_PER_MIN, REACHES = REACHES,
  SITE_BUDGET = SITE_BUDGET, force = force, layout = layout, modules = modules, prune = prune, site = site,
  trace = trace, matured = function(b) if base.cordon_ring then base.cordon_ring(b) end end})
local plan, power = planner_.plan, planner_.power

local function label(b)
  local o = rendering.get_object_by_id(b.label)
  if not o then return end
  o.visible = storage.trace == true
  if not o.visible then return end
  local supply, demand = power(b)
  o.text = string.format("%s | parts %d | feed %d | in %.0f/min | parts %.1f/min | fabs %d drills %d | %.1f/%.1f MW",
    b.rule .. (b.waiting and (" (waiting: " .. b.waiting .. ")") or ""), b.parts, b.feedstock, b.rate_in,
    b.rate_parts, #b.fabs, #b.drills, demand / 1e6, supply / 1e6)
end

-- A mature settlement sends its surplus off-world once a minute, keeping a reserve for repairs and units.
local EXPORT_TICKS = 3600
local EXPORT_RESERVE = 300
local EXPORT_MAX = 1000
local function export(b)
  if not b.mature then return end
  -- Not while on a war footing (short of its cap at war: units first; it shipped its stock off regardless, the faction
  -- AI audit, 2026-10-23).
  if base.footing and not base.footing(b, {name = "lp-export"}) then return end
  local surplus = math.floor(b.parts - EXPORT_RESERVE)
  if surplus < 100 then return end
  local amount = math.min(surplus, EXPORT_MAX)
  -- While the uplink stands, exports travel to it by convoy (no pad needed); otherwise they leave from the pad.
  if army.convoy(b, amount, trace) then
    b.parts = b.parts - amount
    return
  end
  prune(b.launchpads)
  local pad = b.launchpads[1]
  if not pad then return end
  b.parts = b.parts - amount
  if base.on_export then base.on_export(b, amount) end
  rendering.draw_line{from = pad, to = {pad.position.x, pad.position.y - 60}, surface = pad.surface,
    color = {0.6, 0.85, 1, 0.8}, width = 6, time_to_live = 90}
  trace(b, string.format("exported %d parts", amount))
end

-- Territory on the map (map view only): the chunks it holds (scripts/chart.lua: a faint wash in the corporation's colour
-- and a hairline on the outer edge, as radar coverage is drawn), grown as it expands; grey once it falls. The player
-- sees the corporate map before a building (docs/campaign.md, readability). The claim stays a radius for the game.
local CLAIM_MARGIN = 24
function base.claim_map(b)
  local surface = game.surfaces[b.surface]
  local r = 60
  for _, m in ipairs(b.modules) do
    -- A claim (a strip camp kept on the player's ore) is far out: it has its own mark, not the disc.
    local d = math.sqrt((m.center[1] - b.origin.x) ^ 2 + (m.center[2] - b.origin.y) ^ 2) + CLAIM_MARGIN
    if d > r and not m.claim then r = d end
  end
  -- A perimeter that grows on its own (Serenity's moving line, ops.perimeter) claims at least that far.
  if b.perimeter and b.perimeter > r then r = b.perimeter end
  b.claim_radius = r
  -- Redrawn only when what it holds changes (a chunk is 32 tiles: the radius in whole tiles, and the fall).
  local key = string.format("%d|%s", math.floor(r), tostring(b.fallen or false))
  if b.claim_key == key and b.claim_marks then return end
  b.claim_key = key
  for _, o in ipairs({b.claim_fill, b.claim_edge}) do if o and o.valid then o.destroy() end end
  b.claim_fill, b.claim_edge = nil, nil
  chart.clear(b.claim_marks)
  local colour = b.fallen and {r = 0.45, g = 0.45, b = 0.45} or shared.CORPS[b.corp].color
  b.claim_marks = chart.territory(surface, {b.origin.x, b.origin.y}, r, colour)
end

ops.claim_map = base.claim_map
ops.trace = trace
layout.trace = trace

-- A strip camp left alone twice on one patch stays (ops, strip_step): a mining module of the settlement,
-- rebuilt and capturable like any outpost. Its ore is hauled (no line home), marked on the map with its own disc.
function ops.settle(b, site, camp)
  local m = {kind = "mining", center = {site[1], site[2]}, entities = {}, built = true, claim = true}
  table.insert(b.modules, m)
  for _, e in ipairs(camp or {}) do if e and e.valid then register(b, e, m) end end
  local surface = game.surfaces[b.surface]
  local c = shared.CORPS[b.corp].color
  -- Its chunks, dashed: held, not settled ground (scripts/chart.lua).
  m.marks = chart.territory(surface, m.center, CLAIM_MARGIN, c, {dashed = true})
  b.claims_settled = (b.claims_settled or 0) + 1
end

-- The fall: a settlement whose lander is destroyed collapses. Its generators fail one by one (every
-- CASCADE_TICKS), so its turrets go dark; its units evacuate (army.disband). When the last generator is gone,
-- what stands becomes ruins: neutral and minable for salvage (the prototypes' results), except the mining
-- outposts, left to be taken by holding them with no one to stop it, and the mines, still live.
local CASCADE_TICKS = 90
-- The howitzer at home (the legibility audit, step 1: "a kill's reward invisible; no warning before a siege"): a
-- corporation that clears nests (Serenity) keeps its howitzer parked by its lander (a prop: lp-parked-howitzer). Gone while
-- a siege or clearance has it out; killed there or here, the camp goes without one for HOWITZER_DOWN, its ghost on the
-- spot meanwhile. Its spot chosen once, free ground near the lander.
local function park(b)
  if not shared.CORPS[b.corp].clears_nests then return end
  local s = game.surfaces[b.surface]
  local name = shared.variant(b.corp, "lp-parked-howitzer")
  local out = b.op and (b.op.with_howitzer or b.op.piece == "lp-howitzer")
  -- (Or its truck still on the way home: ops.finish.)
  for _, r in ipairs(b.haulers_home or {}) do
    if r.unit.valid and shared.kind_of(r.unit.name) == "lp-howitzer-truck" then out = true end
  end
  local down = (b.howitzer_down or 0) > game.tick
  local here = b.parked and b.parked.valid
  if out or down then
    if here then b.parked.destroy() end
    b.parked = nil
    -- (Its own prototype can have no engine ghost, being hidden and unplaceable: its icon, faded, on the ground.)
    if down and b.howitzer_pad and not (b.parked_ghost and b.parked_ghost.valid) then
      b.parked_ghost = rendering.draw_sprite{sprite = "entity/" .. name, target = b.howitzer_pad, surface = s,
        x_scale = 3, y_scale = 3, tint = {0.45, 0.45, 0.5, 0.45}, render_layer = "floor"}
    end
    return
  end
  if b.parked_ghost and b.parked_ghost.valid then b.parked_ghost.destroy() end
  b.parked_ghost = nil
  -- Parked once grown (its core laid out: parked from landing, it took ground the camp then built round, and a
  -- regression's fights came out otherwise).
  if here or not b.mature then return end
  if not (b.howitzer_pad and s.can_place_entity{name = name, position = b.howitzer_pad, force = b.force}) then
    local p = s.find_non_colliding_position(name, {b.lander.position.x + 12, b.lander.position.y + 12}, 30, 1)
    if not p then return end
    b.howitzer_pad = {p.x, p.y}
  end
  b.parked = s.create_entity{name = name, position = b.howitzer_pad, force = b.force}
end

function base.fall(lander)
  for _, b in pairs(storage.bases) do
    if b.lander == lander and not b.fallen then
      b.fallen = game.tick
      b.queue, b.rebuild = {}, {}
      prune(b.gens)
      b.cascade = {}
      for _, g in ipairs(b.gens) do table.insert(b.cascade, g) end
      rng.shuffle(b.rng, b.cascade)
      b.next_cascade = game.tick + CASCADE_TICKS
      local evacuated = army.disband(b, trace)
      b.evacuated = evacuated
      -- Its yard bursts (a fallen camp is the player's prize, the user: "a significant landmark"): everything it stole
      -- spills where it was kept.
      local y = b.skim_yard
      if y and y.valid then
        local inv = y.get_inventory(defines.inventory.chest)
        local n, stacks = 0, {}
        for _, it in pairs(inv.get_contents()) do
          stacks[#stacks + 1] = {name = it.name, count = it.count, quality = it.quality}
          n = n + it.count
        end
        -- (In wrecks, mined once each: spilled over the ground until 2026-11-03.)
        if #stacks > 0 then shared.wreck(y.surface, y.position, stacks) end
        y.destroy()
        trace(b, string.format("the yard bursts: %d stolen items spill", n))
      end
      trace(b, string.format("lander destroyed: the settlement falls (%d generators to fail)", #b.cascade))
      shared.event("fell", {base = b.id, corp = b.corp, at = {b.origin.x, b.origin.y}})
      local f = game.forces.player
      if f and #f.players > 0 then
        shared.notice(f, {"lp.fallen", shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y,
          lander.surface.name), names.of(b)})
      end
      for _, t in pairs(b.tags or {}) do
        if t.valid then t.text = names.of(b) .. " (destroyed)" end
      end
      base.claim_map(b)
      if base.on_fall then base.on_fall(b) end
      return b
    end
  end
end

-- The powered hull (docs/reviews/2026-10-14-artillery-consult.md): a lander cannot be destroyed while at least half
-- the most generators its settlement has had still stand. A headquarters' lander answers to its uplink instead.
-- Only the generators within HULL_RADIUS of the lander count (the hull consult): a mature settlement's later hubs
-- lie 90-160 tiles out, and a battery in reach of the lander reached almost none of them (seed 777: 31,714 shells,
-- the hull never down). Fewer than two counted, and the hull is down.
local HULL_RADIUS = shared.HULL_RADIUS
local function hull(b)
  if b.hq then return end
  local n = 0
  local lx, ly = b.lander.position.x, b.lander.position.y
  for _, g in ipairs(b.gens) do
    if g.valid and g.force.name == b.force and (g.position.x - lx) ^ 2 + (g.position.y - ly) ^ 2 <= HULL_RADIUS ^ 2 then
      n = n + 1
    end
  end
  b.gens_max = math.max(b.gens_max or 0, n)
  b.gens_counted = n
  local held = n >= shared.HULL_MIN_GENS and n >= shared.HULL_SHARE * b.gens_max
  -- Held through its lander's dome's break (dome.lua: down BREAK after HOLD of the guns' fire): the guns alone break the
  -- dome and the shells then land, but its hull is read again once the dome is whole, its generators rebuilt under it
  -- meanwhile; troops break a hull. Shelled in its three minutes down, nwa's second camp lost its hull's generators to
  -- three guns and its lander with them, 16 minutes after landing, two seeds of three (the visits at 0.2.364; the dome:
  -- "the guns buy no shortcut, troops do").
  if not held and not b.lander.destructible and b.dome and (b.dome.down_till or 0) > game.tick then return end
  if b.lander.destructible == held then
    b.lander.destructible = not held
    b.hull_down = (b.hull_down or 0) + (held and 0 or 1)
    trace(b, string.format("hull %s: %d of %d generators standing", held and "up" or "down", n, b.gens_max))
  end
end

local function ruin(b)
  local mining = {}
  for _, m in ipairs(b.modules) do
    -- By unit number: entity references are not stable table keys (keyed by them, outposts were ruined too).
    if m.kind == "mining" then for _, e in ipairs(m.entities) do if e.valid then mining[e.unit_number] = true end end end
  end
  local n = 0
  local surface = game.surfaces[b.surface]
  for _, e in pairs(surface.find_entities_filtered{force = force(b), position = {b.origin.x, b.origin.y}, radius = 400}) do
    local own = e.unit_number and storage.owner[e.unit_number]
    if own and own.base == b.id and not mining[e.unit_number] and shared.kind_of(e.name) ~= "lp-mine" then
      storage.owner[e.unit_number] = nil
      e.force = "neutral"
      n = n + 1
    end
  end
  b.ruins = n
  trace(b, string.format("%d buildings are ruins now", n))
end

local function collapse(b)
  if not b.cascade or game.tick < b.next_cascade then return end
  local g = table.remove(b.cascade)
  while g and not g.valid do g = table.remove(b.cascade) end
  if g then
    g.die()
    b.next_cascade = game.tick + CASCADE_TICKS
  else
    b.cascade = nil
    ruin(b)
  end
end

function base.tick(tick)
  -- Wrecks no one came for crumble (shared.wreck); an emptied one at once.
  if tick % 3600 == 1234 and storage.wrecks then
    local keep = {}
    for _, w in ipairs(storage.wrecks) do
      if w.e.valid then
        local inv = w.e.get_inventory(defines.inventory.chest)
        if tick - w.at > shared.WRECK_TICKS or inv.is_empty() then w.e.destroy() else table.insert(keep, w) end
      end
    end
    storage.wrecks = keep
  end
  for _, b in pairs(storage.bases) do
    if b.fallen then
      collapse(b)
      if tick % 600 == 300 then capture(b) end
    elseif b.lander.valid then
      if tick % 60 == 0 then hull(b); pack_camp(b) end
      if tick % 120 == 53 then park(b) end
      -- A damaged lander mends slowly, 1% a minute, smoking while it is below 90% (Fable's engagement consult: damage
      -- that a strike leaves stays long enough to be built on).
      if tick % 3600 == (b.id * 17) % 3600 and b.lander.health < b.lander.max_health then
        b.lander.health = math.min(b.lander.max_health, b.lander.health + 0.01 * b.lander.max_health)
      end
      -- Its state read from afar: smoke below 90%, thick and with fire's smoke below 60%.
      local hp = b.lander.health / b.lander.max_health
      if hp < 0.9 and tick % (hp < 0.6 and 20 or 120) == 0 then
        b.lander.surface.create_trivial_smoke{name = hp < 0.6 and "fire-smoke" or "smoke-fast",
          position = {b.lander.position.x + (tick % 7) - 3, b.lander.position.y - 2}}
      end
      if tick % 7200 == (b.id * 61) % 7200 then base.claim_map(b) end
      site.scan_step(game.surfaces[b.surface], b)
      if tick % ECONOMY_TICKS == 0 then economy(b) end
      -- A withdrawing corporation builds nothing more (its headquarters fell).
      local withdrawing = storage.corps and storage.corps[b.corp] and storage.corps[b.corp].withdrawing
      -- A compound being laid out (layout.wfc_step): one stage a second.
      if b.wfc_job and tick % 60 == 17 then layout.wfc_step(b) end
      if tick % BUILD_TICKS == 0 and not withdrawing then
        build(b)
        -- The fortress's own jobs go faster; everything else at the usual pace (a burst for all once
        -- grew the uplink's settlement to 12 blocks in 11 minutes).
        for _ = 2, b.burst or 1 do
          local job = b.queue[1]
          if not (job and job.module and job.module.kind == "fortress") then break end
          build(b)
        end
      end
      army.tick(b, tick, trace)
      if tick % EXPORT_TICKS == 0 and not withdrawing then export(b) end
      if tick % 600 == 300 then capture(b) end
      if tick % PLAN_TICKS == 0 then
        local pending = false
        for _, job in ipairs(b.rebuild) do
          if not job.occupied and game.tick >= job.due then pending = true end
        end
        if #b.queue == 0 and not pending and not withdrawing then plan(b)
        -- Power while the queue is busy: the line's jobs kept it full while what was queued before them came up, and
        -- demand ran past supply (cordon: 6.6 of 6.0 MW, the planner idle from minute 11).
        elseif not withdrawing then
          plan(b, "power")
          -- And its arc flamers where the biters hit it: under their waves its rebuilds are always due (planner arcguard).
          plan(b, "arcguard")
          -- And its first fabricator (queued first, planner.fill): a camp whose queue waited on parts it could not make
          -- planned nothing more and never made a part (parked, 2026-10-24).
          if #b.fabs == 0 then plan(b, "fabricate") end
          -- And the drill that feeds it (the fabricate rule wants ore coming in): its walls lost before its first plan,
          -- their rebuilds waiting on parts it could not make, both of Kessler-Hayashi's camps on nwa planned nothing in
          -- two hours, 0 fabricators, 0 mined (the visits at 0.2.359 to 0.2.361).
          -- (Only while its rebuilds are due, the deadlock: on any busy queue it changed every camp's first minutes, and
          -- eleven scenarios with them, the regression at 0.2.362.)
          if pending and #b.fabs == 0 and #b.drills == 0 then plan(b, "mine") end
          -- And its mining while what is queued would take it QUEUE_LONG minutes or more at what it makes: a young camp
          -- with four drills and the line's first arc queued (60 jobs) worked through them at 60 ore a minute for 34
          -- minutes, its planner idle all that while (cordon broken: the arc stood at minute 36). Not while a drill is
          -- queued already.
          local bill, drill_queued = 0, false
          for _, j in ipairs(b.queue) do
            bill = bill + (shared.cost[j.name or ""] or 0)
            if shared.kind_of(j.name or "") == "lp-drill" then drill_queued = true end
          end
          if not drill_queued and bill > QUEUE_LONG * math.max(1, b.rate_parts or 0) then plan(b, "mine") end
          -- Its generators first (queued behind the line's posts, a starved camp counted them as supply and never built
          -- them: demand past supply, cordon broken), as its lost generators are rebuilt first.
          local gens, rest = {}, {}
          for _, j in ipairs(b.queue) do table.insert(shared.kind_of(j.name or "") == "lp-generator" and gens or rest, j) end
          if #gens > 0 and b.queue[1] ~= gens[1] then
            b.queue = gens
            for _, j in ipairs(rest) do table.insert(b.queue, j) end
          end
        end
        label(b)
      end
    end
  end
end

-- Tests only: the mining modules near a point and what capture sees there.
function base.debug_modules(b, pos, r)
  local out = {}
  local surface = game.surfaces[b.surface]
  for _, m in ipairs(b.modules) do
    if m.kind == "mining" and (m.center[1] - pos[1]) ^ 2 + (m.center[2] - pos[2]) ^ 2 <= r * r then
      local left = 0
      for _, e in ipairs(m.entities) do if e.valid and e.force.name == b.force then left = left + 1 end end
      local by = holder(b, surface, m.center)
      local def = defender(b, surface, m.center)
      local c = def and def.commandable and def.commandable.command
      local cname = c and tostring(c.type)
      for k, v in pairs(defines.command) do if c and v == c.type then cname = k end end
      local own = def and def.unit_number and storage.unit_owner and storage.unit_owner[def.unit_number]
      cname = (cname or "-") .. " owner " .. tostring(own)
      local order = c and string.format(" (order %s%s)", cname,
        c.destination and string.format(" to %.0f,%.0f", c.destination.x, c.destination.y) or "") or ""
      table.insert(out, string.format("%.0f,%.0f built=%s captured=%s left=%d held=%s holder=%s defended=%s", m.center[1],
        m.center[2], tostring(m.built), tostring(m.captured), left,
        m.held_since and tostring(game.tick - m.held_since) or "-", by and by.name or "-",
        def and (def.name .. "@" .. math.floor(def.position.x) .. "," .. math.floor(def.position.y) .. order) or "-"))
    end
  end
  return out
end

function base.stats(b)
  prune(b.bins); prune(b.fabs); prune(b.pylons); prune(b.walls)
  local supply, demand = power(b)
  -- (Its queue's jobs by module kind and entity, its first ten: what waits behind what.)
  local qk = {}
  for i, j in ipairs(b.queue) do
    if i > 10 then break end
    qk[#qk + 1] = ((j.module and j.module.kind) or "-") .. ":" .. tostring(j.name or "tiles")
  end
  return {id = b.id, tick = game.tick, rule = b.rule, parts = b.parts, queue_head = table.concat(qk, " "), waiting = b.waiting, feedstock = b.feedstock, mined = b.mined,
    made = b.made, rate_in = b.rate_in, rate_parts = b.rate_parts, fabs = #b.fabs, drills = #b.drills,
    gens = #b.gens, turrets = #b.turrets, pylons = #b.pylons, modules = #b.modules, queue = #b.queue,
    lost = b.lost, rebuilt = b.rebuilt, rebuild_pending = #b.rebuild,
    doctrine = b.doctrine, hubs = #b.hubs, blocks = #b.blocks, biter_losses = b.hazard and #b.hazard.log or 0, walls = #b.walls, road_tiles = b.road_tiles,
    radars = #b.radars, depots = #b.depots, garrison = #b.garrison, returning = #(b.returning or {}),
    returning_at = (function() local o = {} for _, u in ipairs(b.returning or {}) do if u.valid then o[#o + 1] = {u.position.x, u.position.y} end end return o end)(),
    roster = table_size(b.roster or {}), units_built = b.units_built,
    units_lost = b.units_lost, howitzer_down = b.howitzer_down, parked = b.parked and b.parked.valid or false,
    parked_ghost = b.parked_ghost and b.parked_ghost.valid or false, razed = b.razed, raids_sent = b.raids_sent, responses = b.responses or 0,
    mature = b.mature ~= nil, exported = b.exported or 0, lamps = #b.lamps, mines = #b.mines,
    labs = (function() local t = {} prune(b.labs or {}) for _, e in ipairs(b.labs or {}) do
      local k = shared.kind_of(e.name) t[k] = (t[k] or 0) + 1 end return t end)(),
    launchpads = #b.launchpads, built_by = b.built_by, uplink = b.uplink and b.uplink.valid or false, hq = b.hq,
    lander_health = b.lander.valid and b.lander.health / b.lander.max_health or 0, hull_up = b.lander.valid and not b.lander.destructible,
    setbacks = b.setbacks or 0, held_home = b.held_home or 0,
    turrets_n = #b.turrets, uranium_refills = b.uranium_refills or 0, dug_early = b.dug_early or 0, site_flamers = b.site_flamers or 0, fortress_planned = b.fortress_planned, captured = b.captured or 0, refused_by = b.refused_by,
    patrol = #(b.patrol or {}), patrol_loops = b.patrol_legs or 0, route = b.route,
    convoys_sent = b.convoys_sent or 0, convoys_delivered = b.convoys_delivered or 0, convoys_stuck = b.convoys_stuck or 0,
    convoys_lost = b.convoys_lost or 0, cargo_lost = b.cargo_lost or 0, intercepts = b.intercepts or 0,
    convoy_spread = army.convoy_spread(b), convoy_spread_moving = army.convoy_spread(b, true), convoy_debug = army.convoy_debug(b),
    -- Its landing pad's box (layout.land) and its idle garrison's yard (army.yard_spot), for scenario idle.
    yard = b.yard, yard_moves = b.yard_moves or 0,
    garrison_ids = (function() local t = {} for _, u in ipairs(b.garrison) do
      if u.valid and u.unit_number then t[#t + 1] = u.unit_number end end return t end)(),
    pad_box = (function() for _, m in ipairs(b.blocks) do
      if m.kind == "pad" then return {m.x0, m.y0, m.x0 + m.w, m.y0 + m.h} end end end)(),
    fortress_box = b.blocks[1] and b.blocks[1].kind == "fortress" and
      {b.blocks[1].x0, b.blocks[1].y0, b.blocks[1].x0 + b.blocks[1].w, b.blocks[1].y0 + b.blocks[1].h} or nil,
    archetypes = (function() local t = {} for _, h in ipairs(b.hubs) do
      table.insert(t, h.archetype) end return table.concat(t, ",") end)(),
    supply = supply, demand = demand, network = base.network(b), lander = b.lander.valid,
    dir_tries = b.dir_tries or 0, dir_launched = b.dir_launched or 0, dir_miss = b.dir_miss,
    fallen = b.fallen, departed = b.departed, expedition = b.expedition ~= nil, exported = b.exported, ruins = b.ruins, evacuated = b.evacuated, origin = b.origin, ops = ops.summary(b), corp = b.corp, force = b.force, claim_radius = b.claim_radius, claims_settled = b.claims_settled, landed = b.landed, gens_max = b.gens_max, hull_down = b.hull_down, perimeter = b.perimeter, perimeter_steps = b.perimeter_steps, warned = b.warned,
    grudge = b.grudge, grudge_till = b.grudge_till, cap = army.cap(b), escort = b.escort, gens_counted = b.gens_counted,
    cleared = b.cleared, under_guns = b.under_guns, reinforced = b.reinforced or 0, on_footing = b.on_footing,
    columns_arrived = b.columns_arrived or 0, quiescent = b.quiescent, stood_down = b.stood_down or 0,
    fail_streak = b.fail_streak or 0, stood_down_streak = b.stood_down_streak or 0,
    war_rung = b.war_rung or 0, posture = b.posture, map_text = b.map_text, name = b.name,
    refused = b.refused, crews_stuck = b.crews_stuck or 0, blasted = b.blasted or 0, landfilled = b.landfilled or 0, piers = b.piers or 0,
    claim_marks = #(b.claim_marks or {}), jumps = b.jumps or 0, hands_back = b.hands_back or 0, gate_opens = b.gate_opens or 0, landfx = b.landfx, taps = b.taps or 0, tap_watts = b.tap_watts or 0, looted = b.looted or 0, reprisals = b.reprisals or 0}
end

return base
