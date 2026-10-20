-- The planner (split from base.lua, 2026-10-18, along the AI graph's seams: docs/ai-graph.md): a settlement's rule
-- list (power, fabricate, mine, fortify, defend, picket, depot, launch, embellish, grow) and the queueing of what each
-- rule builds. The code is as it was in base; install runs it with base's helpers bound (K) and returns what base calls.
local shared = require("__landing-party__.shared")

local planner = {}

local GROW_CAP = 30            -- blocks: Serenity's spread stops here (UPS)
local SPREAD_PARTS = 250       -- parts in hand before it spreads (what it needs for units and its line first)
local SPREAD_WAIT = 5 * 3600   -- after a spread that found no ground
local SPREAD_GAP = 5 * 3600    -- after a compound laid out whole
local function spreads(b) return shared.CORPS[b.corp].cordon and not storage.grow_to_line_off end
-- Its size against GROW_CAP: a compound laid out whole (layout.wfc_compound) counts as several blocks.
local function size(b) local n = 0 for _, k in ipairs(b.blocks) do n = n + (k.weight or 1) end return n end
function planner.install(ops, K)
local DEFENCE_RADIUS = K.DEFENCE_RADIUS
local FAB_FEED_PER_MIN = K.FAB_FEED_PER_MIN
local REACHES = K.REACHES
local SITE_BUDGET = K.SITE_BUDGET
local force = K.force
local layout = K.layout
local modules = K.modules
local prune = K.prune
local site = K.site
local trace = K.trace

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
  -- What its power tap steals from a player's line counts as supply (scripts/tap.lua): it grows on the player's power.
  supply = supply + (b.tap_watts or 0)
  demand = #b.drills * shared.power["lp-drill"] + #b.fabs * shared.power["lp-fabricator"]
    + #b.turrets * shared.power["lp-turret"] + #b.radars * shared.power["lp-radar"]
  return supply, demand
end

-- A node (lander, generator, fabricator, mining) with no turret near it.
local function undefended(b, attacked_only)
  local surface = game.surfaces[b.surface]
  for _, m in ipairs(b.modules) do
    if m.built and m.kind == "mining" and not m.defended and (not attacked_only or m.attacked) then
      if surface.count_entities_filtered{name = shared.variants("lp-turret"), position = m.center, radius = DEFENCE_RADIUS} > 0 then
        m.defended = true
      else
        return m
      end
    end
  end
end

-- Queue a slot's entity (a fabricator or generator in a block), or open a block for it.
local function fill(b, role, entity)
  -- Districts (layout.district): its free slots first, then a district planned, not a block opened. Not for its first
  -- fabricator: by the lander, in its yard and first in the queue, as before (a district's crew spent a landing camp's
  -- parts on its floor and generators first, it never had a fabricator and never made a part: seven scenarios).
  local fab_owed = false
  for _, q in ipairs(b.queue) do if q.name == "lp-fabricator" then fab_owed = true break end end
  if layout.districts(b) and (#b.fabs > 0 or fab_owed) then
    for _, blk in ipairs(b.blocks) do
      if blk.kind == role then
        for _, s in ipairs(blk.slots) do if not s.queued and s.name == entity then goto blocks end end
      end
    end
    do
      local d = layout.district(b, role)
      return d and string.format("district planned at %.0f,%.0f for %s", d.center[1], d.center[2], role)
    end
  end
  ::blocks::
  local slot, block = layout.slot(b, role, entity)
  if slot then
    slot.queued = true
    -- A settlement's first fabricator goes first: nothing makes parts without one (seed 4242's camp spent its last on
    -- other jobs and never had one).
    local first = entity == "lp-fabricator" and #b.fabs == 0
    table.insert(b.queue, first and 1 or #b.queue + 1, {name = entity, pos = slot.pos, slot = slot, module = block})
    return string.format("%s in %s block at %.0f,%.0f", entity, role, block.center[1], block.center[2])
  end
  if block then return string.format("opened %s block at %.0f,%.0f", block.kind, block.center[1], block.center[2]) end
end

-- Where the threat comes from: the nearest player-force building, else the player force's spawn.
local function threat(b)
  local surface = game.surfaces[b.surface]
  local p = game.forces.player
  local e = surface.find_nearest_enemy{position = b.lander.position, max_distance = 400, force = force(b)}
  if e then return {e.position.x, e.position.y} end
  local s = p.get_spawn_position(surface)
  return {s.x, s.y}
end

-- The planner's rules, in priority order. The first that applies and finds a place acts.
-- `only`: that rule alone (base.lua: the power rule while the queue is busy).
local function plan(b, only)
  local surface = game.surfaces[b.surface]
  local doc = layout.DOCTRINES[b.doctrine]
  local supply, demand = power(b)
  -- What awaits a rebuild still counts: the base knows what it lost and will replace it.
  local owed = {}
  for _, job in ipairs(b.rebuild) do owed[job.name] = (owed[job.name] or 0) + 1 end
  for _, job in ipairs(b.queue) do if job.name then owed[job.name] = (owed[job.name] or 0) + 1 end end
  -- And what its crews carry, not yet built (taken off the queue, they were planned again: demand 2.8 MW on 2.0, loot).
  for _, c in ipairs(b.crews or {}) do
    for i = c.k, #c.jobs do
      local job = c.jobs[i]
      if job.name and not c.rebuild then owed[job.name] = (owed[job.name] or 0) + 1 end
    end
  end
  local fab_cap = (#b.fabs + (owed["lp-fabricator"] or 0)) * FAB_FEED_PER_MIN
  supply = supply - (owed["lp-generator"] or 0) * shared.power["lp-generator"]
  local function mining()
    local budget = {n = SITE_BUDGET}
    for _, reach in ipairs(REACHES) do
      local o, _, cx, cy = site.mining(surface, b, reach, budget)
      if o then
        enqueue(b, modules.mining, o, cx, cy)
        return string.format("mining at %d,%d", o[1], o[2])
      end
    end
  end
  -- Maturity: enough blocks for the doctrine, or two minutes with nothing left to claim. A mature
  -- settlement stops expanding; its surplus is exported from a launch pad.
  if not b.mature then
    local mb = storage.mature_blocks or doc.mature
    -- Only plans where growth wanted ore and found no site count: counting every idle plan (waiting for
    -- parts included) matured settlements of two blocks after five minutes.
    if #b.blocks >= mb or ((b.grow_failed or 0) >= 12 and #b.fabs > 0) then
      b.mature = game.tick
      trace(b, string.format("mature: %d blocks, %d hubs", #b.blocks, #b.hubs))
      -- Grown, it closes its back (cordon.ring); a camp that spreads closes it once its spread is done (below).
      if not spreads(b) then K.matured(b) end
    end
  end
  local function hub_needing(pred)
    for _, h in ipairs(b.hubs) do if pred(h) then return h end end
  end
  -- Spread to its cap (however it got there, pickets too): its last cluster walled, its ring closed, once.
  if spreads(b) and b.mature and size(b) >= GROW_CAP and not b.spread_done then
    b.spread_done = true
    layout.wall_cluster(b, b.spread_hub and b.hubs[b.spread_hub])
    K.matured(b)
    layout.curtain(b)
  end
  local rules = {
    {"power", function() return demand + 200000 > 0.9 * supply end, function() return fill(b, "gen", "lp-generator") end},
    -- Fabrication follows the flow of ore, never the stock: a backlog left by a raid is worked off by the
    -- fabricators the base has, not answered with more (a raid once doubled them).
    {"fabricate", function() return b.rate_in > fab_cap * 1.1 and b.rate_in > 0 end,
      function() return fill(b, "fab", "lp-fabricator") end},
    -- Mature, it only replaces lost income; young, it keeps the fabricators fed.
    {"mine", function()
      local floor = b.mature and 0.5 or 0.8
      return b.rate_in < fab_cap * floor or #b.drills + (owed["lp-drill"] or 0) == 0 end, mining},
    -- Walls wait for a working economy: spent first, they starved a settlement that had no fabricator yet.
    {"fortify", function() return b.parts > 80 and #b.fabs > 0 end, function()
      local block = layout.fortify(b)
      return block and string.format("walls round %s at %.0f,%.0f", block.kind, block.center[1], block.center[2]) end},
    {"defend", function()
      b.target = (doc.outpost_turrets and undefended(b)) or undefended(b, true)
      return b.target ~= nil and b.target ~= false end,
      function()
        local o = site.near(surface, b, modules.turrets, b.target.center[1], b.target.center[2], 3, 12)
        if not o then b.target.defended = "no site"; return end
        b.target.defended = true
        enqueue(b, modules.turrets, o)
        return string.format("turrets at %d,%d", o[1], o[2])
      end},
    -- (Not lobed: its hubs' walls carry their turrets.)
    {"picket", function()
      -- (Not with districts: their walls carry their guns.)
      if layout.districts(b) then return false end
      b.target = hub_needing(function(h) return not h.spread and h.pickets < doc.pickets end); return b.target ~= nil end,
      function()
        local block = layout.picket(b, b.target, threat(b))
        return block and string.format("picket at %.0f,%.0f", block.center[1], block.center[2]) end},
    {"depot", function()
      b.target = hub_needing(function(h) return h.count >= 3 and not h.depot end); return b.target ~= nil end,
      function()
        b.target.depot = true
        -- Districts: a depot comes in one (at least one in it).
        if layout.districts(b) then
          local d = layout.district(b, "depot")
          return d and string.format("district planned at %.0f,%.0f for a depot", d.center[1], d.center[2])
        end
        local block = layout.open_role(b, "depot")
        return block and string.format("opened %s block at %.0f,%.0f", block.kind, block.center[1], block.center[2]) end},
    -- Serenity spreads out to its line (the user, 2026-10-20: "We need organic looking bases that look menacing, like
    -- metastases on the map"): with parts to spare, clusters of blocks founded towards its line, each tied home by
    -- road and pylons, up to GROW_CAP blocks; once grown and its launch pad open (its mines are ore-bound, this is
    -- ground-bound); towards its line once it has one.
    {"spread", function()
      return spreads(b) and b.launch_opened and size(b) < GROW_CAP and not b.wfc_job
        and b.parts > SPREAD_PARTS and (b.spread_wait or 0) <= game.tick end,
      function()
        local block = layout.spread(b)
        -- Done (no ground left, or at its cap): it closes its ring round all of it (relaid three times while it spread,
        -- each ring torn down, spread2).
        if not block then
          b.spread_wait = game.tick + SPREAD_WAIT
          layout.wall_cluster(b, b.spread_hub and b.hubs[b.spread_hub])
          K.matured(b)
          layout.curtain(b)
          return
        end
        if size(b) >= GROW_CAP then K.matured(b) end
        -- A compound laid out whole: the next waits (three in ten seconds spent its parts at once, wfc1).
        if block.wfc then b.spread_wait = game.tick + SPREAD_GAP end
        return string.format("spread: %s at %.0f,%.0f (%d blocks)", block.kind, block.center[1], block.center[2], #b.blocks)
      end},
    {"launch", function() return b.mature and not b.launch_opened end, function()
      local block = layout.open_role(b, "launch")
      if block and block.kind == "launch" then b.launch_opened = true end
      return block and string.format("opened %s block at %.0f,%.0f", block.kind, block.center[1], block.center[2]) end},
    {"embellish", function() return b.mature and b.parts > 60 end, function()
      local block = layout.embellish(b)
      return block and string.format("lamps, paving and mines at %s %.0f,%.0f", block.kind, block.center[1],
        block.center[2]) end},
    {"grow", function() return not b.mature and b.parts > 100 end, mining},
  }
  for _, r in ipairs(rules) do
    if (not only or r[1] == only) and r[2]() then
      local did = r[3]()
      if did then
        b.rule = r[1]
        if r[1] == "grow" then b.grow_failed = 0 end
        trace(b, string.format("rule %s -> %s (parts %d, feed %d, in %.0f/min, fab cap %.0f, power %.1f/%.1f MW)",
          r[1], did, b.parts, b.feedstock, b.rate_in, fab_cap, demand / 1e6, supply / 1e6))
        return
      end
      if r[1] ~= "fortify" then trace(b, "rule " .. r[1] .. " applies but no site fits") end
      if r[1] == "grow" then b.grow_failed = (b.grow_failed or 0) + 1 end
    end
  end
  if not only then b.rule = "idle" end
end
return {plan = plan, power = power}
end

return planner
