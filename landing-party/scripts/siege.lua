-- Sieges and clearances (split from ops.lua, 2026-10-18, along the AI graph's seams: docs/ai-graph.md): where the mortars
-- stand, which tier a settlement can mount, the fire plan (one point at a time, roboports first), the howitzer and the
-- jammer for a wall kept by robots, the march, deployment, bombardment, resupply, moving up, the assault and packing up;
-- and clearances, sieges on nests (Serenity's own ground). The code is as it was in ops; install runs it with ops'
-- helpers bound (K) and returns what ops calls.
local shared = require("__landing-party__.shared")
local attempt = require("__landing-party__.scripts.attempt")
local tactics = require("__landing-party__.scripts.tactics")
local threat = require("__landing-party__.scripts.threat")
local firemap = require("__landing-party__.scripts.firemap")
local costmap = require("__landing-party__.scripts.costmap")
local valuemap = require("__landing-party__.scripts.valuemap")
local know = require("__landing-party__.scripts.know")
local pods = require("__landing-party__.scripts.pods")

local siege = {}

function siege.install(ops, K)
local ASSAULT_IDLE = K.ASSAULT_IDLE
local CELL = K.CELL
local CLEAR_GUARD = K.CLEAR_GUARD
local CLEAR_RAILS = K.CLEAR_RAILS
local COOL_TICKS = K.COOL_TICKS
local DEFENCE_RADIUS = K.DEFENCE_RADIUS
local DEPLOY_TICKS = K.DEPLOY_TICKS
local FOOT = K.FOOT
local HOWITZER_REACH = K.HOWITZER_REACH
local HOWITZER_STAND = K.HOWITZER_STAND
local MORTAR_REACH = K.MORTAR_REACH
local NO_KILL_TICKS = K.NO_KILL_TICKS
local PACK_TICKS = K.PACK_TICKS
local PLAYER_REACH = K.PLAYER_REACH
local RESUPPLY = K.RESUPPLY
local SHELLS_CAP = K.SHELLS_CAP
local SIEGE_COST = K.SIEGE_COST
local SIEGE_GUARDS = K.SIEGE_GUARDS
local SIEGE_MAX_TICKS = K.SIEGE_MAX_TICKS
local SIEGE_SHELLS = K.SIEGE_SHELLS
local SIEGE_TIERS = K.SIEGE_TIERS
local STUCK_TICKS = K.STUCK_TICKS
local HOLD = {type = defines.command.stop, distraction = defines.distraction.none}  -- a truck waits at its site (march)
local GUARD_CALM = 40      -- its guards on the march answer only what hits them this near its site
local GUARD_BACK = 8       -- and gather this far behind it, away from its target (march, deploy)
-- Where its guards gather near its site: GUARD_BACK behind it, away from its target. The site is out of the guns' reach
-- by SITE_MARGIN alone (or PLAYER_REACH), and gathered round the truck at it, tanks stood at a laser's edge, were shot
-- and charged it, four of them, the siege called off (fortress 12345).
local function guard_spot(b, op)
  local tg = b.intel.targets[op.target]
  if not (tg and tg.pos) then return {x = op.site[1], y = op.site[2]} end
  local dx, dy = op.site[1] - tg.pos[1], op.site[2] - tg.pos[2]
  local dl = math.max(1, math.sqrt(dx * dx + dy * dy))
  return {x = op.site[1] + dx / dl * GUARD_BACK, y = op.site[2] + dy / dl * GUARD_BACK}
end
local TURRETS = K.TURRETS
local TYPES = K.TYPES
local against_player = K.against_player
local alert = K.alert
local alive = K.alive
local battery = K.battery
local budget = K.budget
local defence = K.defence
local enemies = K.enemies
local field = K.field
local finish = K.finish
local floor_of = K.floor_of
local home = K.home
local jammer = K.jammer
local needed = K.needed
local order_all = K.order_all
local pool = K.pool
local push_escort = K.push_escort
local rd = K.rd
local sneak_route = K.sneak_route
local stance = K.stance
local threat_bonus = K.threat_bonus
local TRUCK_PACK = K.TRUCK_PACK
local truck_down, truck_up, truck_piece = K.truck_down, K.truck_up, K.truck_piece
-- A site for the mortar: from the target towards home (then at angles off that line), the first point beyond
-- every known player turret's reach with one of them within the mortar's, on dry land.
-- Whether a point lies out of every one of foes' guns' own reach (threat.reach, from each gun's prototype, its size in it),
-- and SITE_MARGIN more for the guards by its mortars. (At PLAYER_REACH, 31 for every gun, a siege
-- set up 31 tiles from tesla turrets, which reach 30 from a body three tiles wide, and its guards round it were stunned
-- and chained to death in a minute, its mortar with them, three sieges of three; the lane, 2026-10-31. Synthexis reads
-- them so already: the perception consult's first lesson, correct perception.)
local orbital = require("__landing-party__.scripts.orbital")
local SITE_MARGIN = 1
-- Tiles between a siege's howitzer and its mortars (siege_step): out of a shell's blast aimed at either, its foes' widest
-- (threat.foe_splash) twice and both bodies' widths (a flat 24 before, vanilla's blast of 4 six times over).
-- A standing siege's convoy, after its tier's: RESUPPLY shells at what its cheapest tier pays a shell (SIEGE_TIERS[1]),
-- from its siege fund, then its parts.
local function convoy_price() return math.ceil(RESUPPLY * SIEGE_TIERS[1].cost / SIEGE_TIERS[1].shells) end
local function pay_convoy(b)
  local price = convoy_price()
  if (b.siege_fund or 0) + (b.parts or 0) < price then return false end
  local from_fund = math.min(b.siege_fund or 0, price)
  b.siege_fund = (b.siege_fund or 0) - from_fund
  b.parts = b.parts - (price - from_fund)
  return true
end
-- Its railgunners at home (field leaves them out: kept for clearances).
local function rails_home(b)
  local n = 0
  for _, u in ipairs(b.garrison or {}) do if u.valid and shared.kind_of(u.name) == "lp-railgunner" then n = n + 1 end end
  return n
end
local RAIL = function(u) return shared.kind_of(u.name) == "lp-railgunner" end
-- Whether its railgunners go with a siege: an armed camp's on a player whose way has a price (the cost map: nests and
-- worms on it, or guns), the biter-clearing unit through nest country (the user, 2026-11-02).
local function rails_go(b, t) return b.armed and against_player(t.owner) and t.way_keeps and t.way_keeps < 1 end
local REISSUE_MAX = 3          -- times a hauler that gave its way up is sent on (siege_step)
local ESCORT_NEAR = 24        -- guards this near its hauler are kept behind it; further, they go on along its way
local ESCORT_BACK = 8          -- tiles behind its hauler its guards keep, at its launch and on its march
local CORRIDOR_LOOK = 60 * 60   -- ticks between an armed camp's corridor strikes on a siege's march (war.corridor)
-- (A settlement's trace line, written here as orbital.lua writes its own: base requires ops, which installs this.)
local function base_trace(b, msg)
  local line = string.format("%8d base %d  %s", game.tick, b.id, msg)
  if storage.trace then helpers.write_file("landing-party/decisions.txt", line .. "\n", true) end
  table.insert(b.log, line)
  if #b.log > 30 then table.remove(b.log, 1) end
end
local function howitzer_apart(hn, mn)
  local function width(name)
    local box = prototypes.entity[name] and prototypes.entity[name].collision_box
    return box and math.max(box.right_bottom.x - box.left_top.x, box.right_bottom.y - box.left_top.y) or 3
  end
  return 2 * threat.foe_splash() + width(hn) + width(mn)
end
local function out_of_reach(s, p, foes)
  for _, e in ipairs(s.find_entities_filtered{position = p, radius = threat.far() + SITE_MARGIN + 3, type = TURRETS, force = foes}) do
    -- (And never nearer than PLAYER_REACH: its hauler's way in kept that room; at a laser's own 27 its hauler was killed
    -- on its last leg, every fortress siege intercepted; the regression, 2026-10-31.)
    local r = math.max(threat.reach(e) + SITE_MARGIN, PLAYER_REACH)
    if (e.position.x - p[1]) ^ 2 + (e.position.y - p[2]) ^ 2 <= r * r then return false end
  end
  return true
end

local function siege_site(b, t)
  local s = game.surfaces[b.surface]
  local h = home(b)
  local foes = enemies(game.forces[b.force])
  local base = math.atan2(h.position.y - t.pos[2], h.position.x - t.pos[1])
  for _, turn in ipairs({0, 0.35, -0.35, 0.7, -0.7}) do
    local a = base + turn
    for d = 20, 70, 1 do
      local p = {t.pos[1] + math.cos(a) * d, t.pos[2] + math.sin(a) * d}
      if out_of_reach(s, p, foes) then
        if s.count_entities_filtered{position = p, radius = MORTAR_REACH, type = TURRETS, force = foes} > 0
          and s.count_tiles_filtered{position = p, radius = 4, collision_mask = "water_tile"} == 0 then
          return p
        end
        break
      end
    end
  end
end

-- At most one siege against a player force at a time, across corporations (a battery excepted).
-- A howitzer's site against t: out of every gun's own reach, within HOWITZER_REACH of one (it stands off as far as it
-- needs, no farther), on dry ground.
local function howitzer_site(b, t)
  local s = game.surfaces[b.surface]
  local h = home(b)
  local foes = enemies(game.forces[b.force])
  local base = math.atan2(h.position.y - t.pos[2], h.position.x - t.pos[1])
  for _, turn in ipairs({0, 0.35, -0.35, 0.7, -0.7}) do
    local a = base + turn
    for d = 20, HOWITZER_REACH - 5, 2 do
      local p = {t.pos[1] + math.cos(a) * d, t.pos[2] + math.sin(a) * d}
      if out_of_reach(s, p, foes) then
        if s.count_entities_filtered{position = p, radius = HOWITZER_REACH - 5, type = TURRETS, force = foes} > 0
          and s.count_tiles_filtered{position = p, radius = 4, collision_mask = "water_tile"} == 0 then
          return p
        end
        break
      end
    end
  end
end

-- Its siege against t: its mortars from out of every gun's reach (siege_site); its howitzer where no mortar's site is
-- out of reach (rockets and railguns outrange a mortar's 36), or where its sieges there failed twice lately where they got
-- there (tactics.failures), at its level 2 and up and its howitzer not lost. Its mortars are its bursters: what opens the way;
-- its howitzer the next step up, slow, lost for a while if killed, and outranged by the player's artillery (the user,
-- 2026-10-31: escalate to the howitzer, not a mortar that outranges everything). Returns its site and its piece.
local function siege_plan(b, t, army)
  local site = siege_site(b, t)
  local can = army.level(b) >= 2 and (b.howitzer_down or 0) <= game.tick
  if site and can and t.pos then
    -- (Counted, tactics.failures: at its ladder's third it never came, the ladder's hold having set the siege aside first;
    -- the code review, 2026-10-31.)
    local failed = tactics.failures(b.corp, t.owner or "player", t.pos, "siege",
      attempt.sig(game.surfaces[b.surface], t.owner or "player", t.pos))
    if failed >= 2 then
      local hs = howitzer_site(b, t)
      if hs then return hs, "lp-howitzer" end
    end
  end
  if site then return site, "lp-mortar" end
  if can then
    local hs = howitzer_site(b, t)
    if hs then return hs, "lp-howitzer" end
  end
end
ops.siege_plan = siege_plan

local function besieged(owner)
  for _, o in pairs(storage.bases) do
    local t = o.op and o.op.kind == "siege" and o.intel and o.intel.targets[o.op.target]
    if t and t.owner == owner then return true end
  end
end

-- Orbital intelligence's way there (Synthexis's perception, the same skeleton: firemap.lua, costmap.lua): every gun that
-- would fire on its way, priced by what its own losses taught it (know.price, else the prior), and what reaching any cell
-- costs from its home. Read fresh at each decision, not kept between ticks (a map held in a module and missing after a
-- load would part a game from its peers); its launch the same tick reads it back (siege_read). On nwa its sieges went for
-- the player's artillery 560 tiles off through the base, every hauler killed or stuck on the way (0.2.152).
local siege_read
local function read_ways(b, h, targets)
  local s = game.surfaces[b.surface]
  local foes = enemies(game.forces[b.force])
  local far = 0
  for _, t in pairs(targets) do
    if t.pos and against_player(t.owner) then
      far = math.max(far, math.sqrt((t.pos[1] - h.position.x) ^ 2 + (t.pos[2] - h.position.y) ^ 2))
    end
  end
  if far == 0 then return nil end
  local radius = far + 60
  local function price(e) return know.price(b.corp, e.force.name, e.name) or threat.prior(e, ops.PER_TURRET) end
  -- Biter country too, where it is at war with the biters (Synthexis reads none, the biters its allies): worms are guns
  -- (their prototypes' reach, threat.profile), and the spawners round its way and where its own died to biters lately
  -- (its hazard log) are what no fire map shows (costmap's deaths). On nw its haulers died to worms and spitters.
  local shooters, types, deaths = foes, threat.ARMED, nil
  if not ops.pact(b.force) then
    shooters, types, deaths = {}, {"ammo-turret", "electric-turret", "fluid-turret", "unit", "turret"}, {}
    for _, f in ipairs(foes) do shooters[#shooters + 1] = f end
    for _, n in ipairs(shared.NEST_FORCES) do if game.forces[n] then shooters[#shooters + 1] = game.forces[n] end end
    for _, e in ipairs(s.find_entities_filtered{position = h.position, radius = radius, type = "unit-spawner",
      force = shared.NEST_FORCES}) do
      deaths[#deaths + 1] = {e.position.x, e.position.y, ops.PER_TURRET}
    end
    for _, l in ipairs(b.hazard and b.hazard.log or {}) do deaths[#deaths + 1] = {l[2], l[3], 1} end
  end
  local fmap = firemap.read(s, h.position, radius, shooters, price, types)
  local cm = costmap.read(s, h.position, radius, foes, {fire = fmap, n = SIEGE_TIERS[#SIEGE_TIERS].guards, deaths = deaths,
    from = {h.position.x, h.position.y}, cell = radius > 1200 and costmap.CELL * 3 or costmap.CELL * 2, wall_forces = foes})
  siege_read = {tick = game.tick, id = b.id, cm = cm}
  -- Tests: the reading written out (debug_tune dump_ways: scripts/ways_map.py draws it), its first DUMP_WAYS.
  if storage.dump_ways and (storage.ways_dumped or 0) < 3 then
    storage.ways_dumped = (storage.ways_dumped or 0) + 1
    local cells = {}
    for k, c in pairs(cm.cost) do
      cells[#cells + 1] = {math.floor(k / cm.h), k % cm.h, math.floor(c * 10) / 10, math.floor((cm.cell_cost[k] or 0) * 10) / 10}
    end
    local guns = {}
    for _, g in ipairs(fmap.list or {}) do guns[#guns + 1] = {math.floor(g.x), math.floor(g.y), math.floor(g.r)} end
    local tg = {}
    for key, t in pairs(targets) do
      if t.pos and against_player(t.owner) then
        local way = costmap.way_in(cm, {x = t.pos[1], y = t.pos[2]})
        local path = {}
        for _, q in ipairs(costmap.path(cm, {x = t.pos[1], y = t.pos[2]}) or {}) do path[#path + 1] = {math.floor(q.x), math.floor(q.y)} end
        tg[#tg + 1] = {key = key, kind = t.kind, pos = t.pos, value = t.value, start = way and {way.start.x, way.start.y},
          start_cost = way and costmap.cost(cm, way.start), path = path}
      end
    end
    helpers.write_file("landing-party/ways-" .. storage.ways_dumped .. ".json", helpers.table_to_json({tick = game.tick,
      home = {h.position.x, h.position.y}, x0 = cm.x0, y0 = cm.y0, size = cm.size, w = cm.w, h = cm.h, cells = cells,
      guns = guns, targets = tg, spawners = deaths and #deaths or 0}))
  end
  return cm
end
local function choose_siege(b, army, only_battery)
  if (b.parts or 0) + (b.siege_fund or 0) < SIEGE_COST or game.tick < (b.next_siege or 0) then return end
  -- A capability, not every corporation's (Serenity's from level 1; Grubstake never besieges).
  -- A settlement landed with a grudge besieges whatever its corporation's level or temper (faction.grudge).
  local capable = shared.capable(b.corp, "siege", army.level(b)) or b.grudge ~= nil
  -- Against a battery, a corporation that ever besieges does so now (Grubstake never does: it raids).
  local counter = shared.capable(b.corp, "siege", 99)
  local in_flight = ops.player_ops()
  local n = field(b, army) + (b.armed and rails_home(b) or 0)
  if n < SIEGE_GUARDS then return end
  local h = home(b)
  local best, bs, site, piece
  local orbital = (shared.CORPS[b.corp] or {}).orbital_intel and not storage.ways_off
  local cm = orbital and h and read_ways(b, h, b.intel.targets)
  local blocked, blocked_s, blocked_site
  for key, t in pairs(b.intel.targets) do
    -- Its defence read now, not when its sensors last looked (orbital intelligence: a substation ringed by 32 lasers
    -- placed after its survey read 0 and drew a siege of two mortars, standsiege 0.2.152), and before the test of it
    -- below (read after, the stale 0 had already set the target aside: standsiege nests, 0.2.154).
    if orbital and t.pos and against_player(t.owner) then
      t.defence, t.dmg = ops.weigh(game.surfaces[b.surface], t.pos, t.owner, nil, b.corp)
    end
    if (not only_battery or battery(t)) and (capable or (counter and battery(t))) and ((t.defence or 0) >= 2 or battery(t))
      and not (b.quiescent and against_player(t.owner) and not battery(t))
      and not (against_player(t.owner) and in_flight >= budget(t.owner) and not battery(t))
      and not (against_player(t.owner) and not battery(t) and besieged(t.owner))
      and stance.may(b.corp, t.owner, "siege")
      -- Marked ground and a hurt camp hold a siege as they hold a raid (it skipped them; the faction AI audit,
      -- 2026-10-23). A grudge siege still ignores the soft rule, as designed.
      and not (against_player(t.owner) and not battery(t) and ((t.pos and ops.marked(b, t.pos)) or ops.camp_hurt(b))) then
      local dist = math.sqrt((t.pos[1] - h.position.x) ^ 2 + (t.pos[2] - h.position.y) ^ 2)
      local s = (t.value + threat_bonus(b, t)) / (1 + dist / 300) * (battery(t) and 10 or 1)
      -- An armed camp weighs its siege as its raids are weighed (ops.relevance: the pressure on a player, a grudge): its
      -- raids were, its sieges not, and on nwa every weighing read raid 22.73 against siege 1.36, no siege in 90 minutes
      -- (the Kessler-Hayashi consult, 2026-11-02).
      if b.armed and ops.relevance then
        local player = against_player(t.owner)
        s = s * ops.relevance(b, t, {player = player, rung = player and stance.rung(t.owner, b.force) or 0,
          floor = game.tick - (storage.threat_last or 0) > ops.FLOOR_TICKS})
      end
      if not bs or s > bs then
        local p, pc = siege_plan(b, t, army)
        -- What it keeps of a siege's guards on the way to its site (the cost map, from its home), its score times the
        -- share kept, as Synthexis weighs a place; no way there, none. (Measured first to where its way in starts, the
        -- last cell out of all fire: on nwa, ringed by nests, that was its own doorstep, and every target read 0.98.)
        if p and cm and against_player(t.owner) then
          local lost = costmap.cost(cm, {x = p[1], y = p[2]})
          local keeps = lost and valuemap.keeps_one_way(SIEGE_TIERS[#SIEGE_TIERS].guards, lost) or 0
          t.way_keeps = keeps
          -- (The best it would take with its way free, for its corridor below.)
          if lost and keeps < 1 and (not blocked_s or s > blocked_s) then blocked, blocked_s, blocked_site = t, s, p end
          -- Synthexis's floor (valuemap.REACH_FLOOR): a dear way makes a target worth less, not nothing. Without it every
          -- target past a few nests read 0.00 (a siege's guards are 10 to 24, its waves hundreds) and on nw it sent no
          -- siege in 90 minutes, three seeds (0.2.156); no way at all is still none.
          s = lost and s * (valuemap.REACH_FLOOR + keeps) or 0
        end
        if p and s > 0 and (not bs or s > bs) then best, bs, site, piece = key, s, p, pc end
      end
    end
  end
  -- Its best target out of reach for its way alone (a way there, too dear to keep its guards): it clears that way from
  -- orbit along the cost map's path (war.corridor: the nests by it shelled), once a CORRIDOR_LOOK, and weighs again. Left
  -- to the weighing alone, a camp behind a belt of thirteen spawners and their worms besieged nothing in 30 minutes
  -- (standsiege nests, 0.2.154).
  if not best and blocked and cm and ops.corridor and game.tick >= (b.clear_way_at or 0) then
    local path = costmap.path(cm, {x = blocked_site[1], y = blocked_site[2]})
    if path then
      local route = {}
      for _, q in ipairs(path) do route[#route + 1] = {q.x, q.y} end
      b.clear_way_at = game.tick + CORRIDOR_LOOK
      local shells = ops.corridor(b, {h.position.x, h.position.y}, route, blocked_site)
      if shells > 0 then
        b.ways_cleared = (b.ways_cleared or 0) + 1
        base_trace(b, string.format("clears its way to %s at %.0f,%.0f from orbit (its guards would keep %.2f): %d shells",
          blocked.kind, blocked.pos[1], blocked.pos[2], blocked.way_keeps or 0, shells))
      end
    end
  end
  return best, site, bs, piece
end

-- The tier this settlement can mount against t now: its level, held to a player's era + 1, a grudge one up, then down
-- to what its parts and field afford.
local function siege_tier(b, t, army)
  local k = math.max(1, army.level(b))
  if against_player(t.owner) then k = math.min(k, budget(t.owner)) end
  if b.grudge then k = k + 1 end
  -- The ladder's top rung against that player: a tier more, past the budget (b.war_rung, war.lua).
  if against_player(t.owner) and (b.war_rung or 0) >= 3 then k = k + 1 end
  k = math.min(k, #SIEGE_TIERS)
  -- Its cap: what the player's era allows (budget), a grudge and the ladder's top rung a tier more each.
  local cap_k = #SIEGE_TIERS
  if against_player(t.owner) then
    cap_k = math.min(cap_k, budget(t.owner) + (b.grudge and 1 or 0) + ((b.war_rung or 0) >= 3 and 1 or 0))
  end
  -- Read from what defends it (a corporation with orbital intelligence, shared.CORPS orbital_intel; the user, 2026-11-02:
  -- "Isn't it obvious attack size should vary from read?"): the mortar shells its guards take to break (threat.shells_for,
  -- each gun within DEFENCE_RADIUS of it), the least tier that carries as many, within its cap. Before, the tier was its
  -- army's level whatever stood there: two mortars against nw's walls of 460.
  if against_player(t.owner) and t.pos and (shared.CORPS[b.corp] or {}).orbital_intel and not storage.read_size_off then
    local need = 0
    for _, e in pairs(game.surfaces[b.surface].find_entities_filtered{position = t.pos, radius = DEFENCE_RADIUS,
      type = TURRETS, force = enemies(game.forces[b.force])}) do
      need = need + threat.shells_for("lp-mortar-projectile", e)
    end
    local kr = #SIEGE_TIERS
    for i = 1, #SIEGE_TIERS do
      if SIEGE_TIERS[i].mortars * SIEGE_TIERS[i].shells >= need then kr = i; break end
    end
    k = math.min(cap_k, kr)
    t.shells_need = need
  end
  -- A tier up where its sieges lately broke nothing (tactics.failed_specialists, every attacker's: Synthexis's rams double
  -- where every one set off and its wave still stood at a wall). Within its cap above: what the player's era allows.
  if t.pos then
    local failed = tactics.failed_specialists(b.corp, t.owner or "player", t.pos, "siege",
      attempt.sig(game.surfaces[b.surface], t.owner or "player", t.pos))
    if failed and failed >= k then k = math.min(failed + 1, cap_k) end
  end
  local n, reserve = field(b, army)
  if battery(t) then n = n + reserve end
  -- Its railgunners too, an armed camp's siege on a player whose way has a price (the cost map: nests and worms on it, or
  -- guns): the biter-clearing unit goes with it through nest country (the user, 2026-11-02: "Should the siege move with
  -- railgunners for efficient nest clearing?"). Kept home for clearances, they had been most of its garrison, and on nw
  -- its sieges went at tier 1, 5 or 6 guards in its field against 216 shells read (0.2.157).
  -- Within what it may take from home (its floor): counted on top of its field, it read 24 where 18 could go.
  if rails_go(b, t) then n = math.min(n + rails_home(b), math.max(0, pool.home(b) - floor_of(b, army, battery(t)))) end
  -- (Its siege fund for sieges on a player only: drawing on it, an armed camp sent tier-2 clearances at the nests round it
  -- again and again, lost their guards, and fell to Synthexis, fed nw, 2026-11-02.)
  local purse = (b.parts or 0) + (against_player(t.owner) and (b.siege_fund or 0) or 0)
  while k > 1 and (purse < SIEGE_TIERS[k].cost or n < SIEGE_TIERS[k].guards) do k = k - 1 end
  return k
end
ops.siege_tier = siege_tier
-- What an armed camp saves for (base.lua's siege fund, handed to base by war.lua: requiring base here loops, base being
-- mid-load when ops installs this): the costliest siege it may send a player, by its cap in siege_tier.
local function top_tier(b)
  local best = 1
  for _, f in pairs(game.forces) do
    if shared.is_player_force(f) then
      best = math.max(best, math.min(#SIEGE_TIERS, budget(f.name) + (b.grudge and 1 or 0) + ((b.war_rung or 0) >= 3 and 1 or 0)))
    end
  end
  return SIEGE_TIERS[best]
end
ops.siege_goal = function(b) return top_tier(b).cost end
-- What an armed camp's garrison holds at least (army.cap): the guards of the costliest siege it may send a player, with
-- what an operation of choice leaves home (pool.RESERVE) on top. Its cap was its depots' alone, and they come with its
-- growth: for its first 30 to 50 minutes a cap of 20, its field 14, while parts piled up unspent (7352 on nwa, 5230 on
-- nw), and its sieges went with 3 to 10 guards against walls read at 216 shells (ladder, 0.2.161).
ops.siege_garrison = function(b) return math.ceil(top_tier(b).guards / (1 - pool.RESERVE)) end

-- Whether a siege is against a player (its target's owner).
local function t_owner_player(b, op)
  local t = op.target and b.intel.targets[op.target]
  return t and against_player(t.owner)
end

-- The mortars' point: the one already chosen while it stands and is in reach; else a roboport in reach of any mortar,
-- the nearest; else the turret in reach with the least health.
local function reach_of(m) return m.name:find("howitzer", 1, true) and HOWITZER_REACH or MORTAR_REACH end
local function focus(s, live, foes, current)
  local function reach(e)
    for _, m in ipairs(live) do
      if (m.position.x - e.position.x) ^ 2 + (m.position.y - e.position.y) ^ 2 <= reach_of(m) ^ 2 then return true end
    end
  end
  if current and current.valid and reach(current) then return current end
  local best, bd
  for _, m in ipairs(live) do
    for _, r in pairs(s.find_entities_filtered{position = m.position, radius = reach_of(m), type = "roboport", force = foes}) do
      local d = (r.position.x - m.position.x) ^ 2 + (r.position.y - m.position.y) ^ 2
      if not bd or d < bd then best, bd = r, d end
    end
  end
  if best then return best end
  for _, m in ipairs(live) do
    for _, e in pairs(s.find_entities_filtered{position = m.position, radius = MORTAR_REACH, type = TURRETS, force = foes}) do
      if not bd or e.health < bd then best, bd = e, e.health end
    end
  end
  return best
end

local function launch_siege(b, key, site, trace, army, tier_override, clearance, piece)
  local t = b.intel.targets[key]
  local tier = tier_override or storage.siege_tier or siege_tier(b, t, army)
  local spec = SIEGE_TIERS[tier]
  local h = home(b)
  local s = game.surfaces[b.surface]
  -- Out past its own outermost wall on the way to the site: gates open for no unit, and a hauler made beside a depot in a
  -- gated block drove at its wall, 21 to 31 tiles short of its site, siege after siege (visit b - rocket).
  local hx, hy = h.position.x, h.position.y
  local dist = math.max(1, math.sqrt((site[1] - hx) ^ 2 + (site[2] - hy) ^ 2))
  local out = 0.1 * dist
  for d = 0, dist, 2 do
    local q = {hx + (site[1] - hx) * d / dist, hy + (site[2] - hy) * d / dist}
    if s.count_entities_filtered{position = q, radius = 2.5, force = h.force, type = {"wall", "gate"}, limit = 1} > 0 then
      out = math.min(d + 5, dist)
    end
  end
  -- A wall kept by robots: a howitzer comes too, for the roboports behind it (98 tiles; the mortars' 35 reached the
  -- lasers but not the roboports 13 tiles behind them, and the robots mended or rebuilt all they hit, fortress).
  local with_howitzer = false
  if not clearance and not storage.focus_off and against_player(t.owner) and (tier >= 2 or army.level(b) >= 2)
    and s.count_entities_filtered{position = t.pos, radius = 60, type = "roboport", force = enemies(game.forces[b.force]),
      limit = 1} > 0 then
    if (b.howitzer_down or 0) > game.tick then
      trace(b, string.format("siege: no howitzer (lost; %d minutes yet)", math.ceil((b.howitzer_down - game.tick) / 3600)))
    else
      with_howitzer = true
    end
  end
  -- (A howitzer siege's piece is its howitzer: none besides it for the roboports; two came from one truck, the review.)
  if piece == "lp-howitzer" then with_howitzer = false end
  -- A siege that takes the howitzer goes behind the howitzer truck, its hauler (units.lua).
  -- A corporation that drops its siege from orbit (shared.CORPS orbital_drop; the user, 2026-11-03: "drop their guns from
  -- orbit seems cool if we use the cargo drop visualization") sends no truck: its guards march, and its pieces come
  -- down in cargo pods on its site once they hold it (siege_step). Its truck had been most of its sieges' failures:
  -- stuck at its gate, its escort in its way, its orders given up, its way lost on a re-send.
  local drop = (shared.CORPS[b.corp] or {}).orbital_drop and not storage.drop_off or false
  local truck = not drop and (with_howitzer or piece == "lp-howitzer")
  local hname = shared.variant(b.corp, truck and "lp-howitzer-truck" or "lp-hauler")
  local p = s.find_non_colliding_position(hname, {hx + (site[1] - hx) * out / dist,
    hy + (site[2] - hy) * out / dist}, 20, 0.5)
  -- Not into a fight at its own gate: with its foes' units within a biter's sight (threat.biter_sight; a flat 48 before)
  -- of where its hauler starts it waits (its
  -- next decision). On fed nw five sieges of eight lost their hauler on the way, one 16 s out and 44 tiles from its
  -- lander, to biters attacking its depots (2026-11-02).
  -- (Not a clearance: biters by its camp are what it goes out against.)
  if p and not clearance and s.count_entities_filtered{position = p, radius = threat.biter_sight(), type = "unit",
    force = enemies(game.forces[b.force]), limit = 1} > 0 then
    trace(b, "siege waits: its foes' units at its gate")
    return false
  end
  local hauler = p and not drop and s.create_entity{name = hname, position = p, force = h.force}
  if not (hauler or (drop and p)) then return false end
  -- Where it sets out from: its hauler, or (a drop) where its hauler would have started.
  local start = hauler and hauler.position or p
  -- The howitzer leaves its pad now (base.park would hide it at its next look, two seconds on: truck and pad at once).
  if truck and b.parked and b.parked.valid then b.parked.destroy(); b.parked = nil end
  local guards = {}
  -- Counter-battery (Serenity): against the player's artillery, its Shock troopers go first (up to six).
  local floor = floor_of(b, army, battery(t))
  if battery(t) and rd.has(b.corp, "counter") then
    guards = pool.take(b, 6, floor, function(u) return shared.kind_of(u.name) == "lp-shock" end)
  end
  -- A clearance (nests): its railgunners go first, the biter-clearing unit.
  if clearance or t.owner == "enemy" then
    for _, u in ipairs(pool.take(b, spec.guards - #guards, floor, function(u) return shared.kind_of(u.name) == "lp-railgunner" end)) do
      table.insert(guards, u)
    end
  end
  -- A clearance takes railgunners only: Line troopers next to them died to the nest's big biters and killed next to
  -- none (nine of them killed one of sixteen, scenario rail).
  if not (clearance or t.owner == "enemy") then
    for _, u in ipairs(pool.take(b, spec.guards - #guards, floor, FOOT)) do
      table.insert(guards, u)
    end
    -- Its railgunners after, where its tier counted them (siege_tier, rails_go). FOOT leaves them out (ops.fights): its
    -- tier was read for 24 guards and its truck left with the 1 to 3 that were not railgunners (nw, 0.2.162).
    if rails_go(b, t) then
      for _, u in ipairs(pool.take(b, spec.guards - #guards, floor, RAIL)) do table.insert(guards, u) end
    end
  end
  -- From its siege fund first (an armed camp's, base.lua), then its parts.
  local from_fund = (not clearance and t and against_player(t.owner)) and math.min(b.siege_fund or 0, spec.cost) or 0
  b.siege_fund = (b.siege_fund or 0) - from_fund
  b.parts = math.max(0, b.parts - (spec.cost - from_fund))
  local paid_fund = from_fund
  -- The guards ride out on the hauler: gates open for no unit, and guards walking from home were 33 to 49 tiles off when
  -- the biters broke the mortars (visit b - rocket).
  -- Beside it, ESCORT_BACK off its way to its site: set round it, its tanks stood in its way, and the engine gave its
  -- order up six seconds out, the truck held 17 tiles short of its site (fortress, 0.2.149); set behind it, 5 past its
  -- wall, they stood inside the wall, and the artillery base's siege stood 71 minutes with its 10 guards at home
  -- (0.2.161); the truck started further out instead lost its way at once on that base (0.2.164).
  local hdx, hdy = site[1] - start.x, site[2] - start.y
  local hdl = math.max(1, math.sqrt(hdx * hdx + hdy * hdy))
  local beside = {start.x - hdy / hdl * ESCORT_BACK, start.y + hdx / hdl * ESCORT_BACK}
  for _, u in ipairs(guards) do
    local q = u.valid and s.find_non_colliding_position(u.name, beside, 12, 0.5)
    if q then u.teleport(q) end
  end
  b.op = {kind = "siege", target = key, phase = "march", members = guards, launched = #guards, hauler = hauler, drop = drop or nil,
    site = site, started = game.tick, phase_at = game.tick, shells_fired = 0, tier = tier,
    convoys_left = spec.convoys or 0}
  -- (Its piece, a howitzer where its mortars are outranged or broke nothing there twice: siege_plan.)
  if piece and not clearance then b.op.piece, b.op.reach = piece, piece == "lp-howitzer" and HOWITZER_REACH or MORTAR_REACH end
  b.op.clearance = clearance
  -- A standing siege (an armed camp's, on a player; the Kessler-Hayashi consult, 2026-11-02: "a camp that cannot be
  -- killed and cannot hurt forces no encounter"): no clock while it can pay, paid convoys after its tier's, a strike
  -- again after the camp's cooldown, a dome over its site (dome.lua). It ends when its pieces are gone, half its guards
  -- lost, or its shells and money out.
  b.op.standing = b.armed and not clearance and t and against_player(t.owner) or nil
  b.op.with_howitzer = with_howitzer or nil
  b.op.truck = truck or nil
  -- Round biter country (the hauler is slow and alone: through a nest field it never arrived).
  -- A clearance's march keeps out of its worms' reach (straight on, its guards walked into a behemoth's, review).
  local hroute
  -- An armed camp's siege on a player drives the cheapest way through fire its orbital reading found (read_ways, this
  -- tick), not round nests alone: its haulers drove through the guns' reach on nwa and died there.
  if not clearance and siege_read and siege_read.tick == game.tick and siege_read.id == b.id and against_player(t.owner) then
    local path = costmap.path(siege_read.cm, {x = site[1], y = site[2]})
    if path then
      -- (From the point of it nearest where its hauler starts, past its outer wall: read from its home, inside its
      -- fortress, the way's first points led the hauler back to a gate that opens for no unit, and it stood 469 tiles
      -- short until called off; the artillery base, seed 2, 0.2.160.)
      local hp, first, fd = start, 1, nil
      for i, q in ipairs(path) do
        local d = (q.x - hp.x) ^ 2 + (q.y - hp.y) ^ 2
        if not fd or d < fd then first, fd = i, d end
      end
      hroute = {}
      for i = first + 1, #path do hroute[#hroute + 1] = {path[i].x, path[i].y} end
      b.op.read_route = true
    end
  end
  hroute = hroute or sneak_route(b, {start.x, start.y}, site,
    clearance and {turrets = false, worms = true} or {turrets = false, nests = (b.intel.targets[key] or {}).owner ~= "enemy"})
  if not hroute and clearance then hroute = sneak_route(b, {start.x, start.y}, site, {turrets = false}) end
  if not hroute and b.intel.targets[key] and push_escort(b, b.intel.targets[key], {start.x, start.y}, site) then
    hroute = {}
    b.op.pushed = true
    trace(b, string.format("hauler pushes through biter country to %.0f,%.0f", site[1], site[2]))
  end
  if not hroute then
    for _, u in ipairs(guards) do table.insert(b.garrison, u) end
    b.op = nil
    b.siege_fund = (b.siege_fund or 0) + paid_fund
    b.parts = b.parts + spec.cost - paid_fund
    if hauler then hauler.destroy() end
    local tt = b.intel.targets[key]
    if tt then tt.cool = game.tick + COOL_TICKS end
    trace(b, string.format("%s to %.0f,%.0f: no way round biter country; not sent", "siege", site[1], site[2]))
    -- The settlement waits too (re-planned every 30 s, all night, visit).
    b.next_siege = game.tick + 2 * 3600
    b.next_op = game.tick + 2 * 3600
    return false
  end
  -- An armed camp shells the nests by its way first (war.corridor).
  b.op.route = hroute
  if ops.corridor then ops.corridor(b, {start.x, start.y}, hroute, site) end
  local hcmds = {}
  for _, w in ipairs(hroute) do
    table.insert(hcmds, {type = defines.command.go_to_location, destination = w, radius = 4,
      distraction = defines.distraction.none})
  end
  table.insert(hcmds, {type = defines.command.go_to_location, destination = site, radius = 2,
    distraction = defines.distraction.none})
  -- And it waits there: a unit whose orders are done wanders (the engine's default), and a truck at its site between two
  -- of its march's looks, 300 ticks apart, wandered 20 tiles on into the guns' reach and died (fortress, seed 12345).
  table.insert(hcmds, HOLD)
  if hauler then
    hauler.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
      commands = hcmds}
  end
  -- A clearance's guards answer only what hits them on the march: on sight, railgunners (vision 34, range 30) walked up
  -- to the worms they saw, into a behemoth's 48 (review of scenario clear).
  -- Its guards go its hauler's way (its waypoints, then behind its site): sent straight at a point by it, they crossed
  -- the worm belt its hauler's way went round and all died there, 95 to 119 tiles back (standsiege nests, 0.2.155).
  do
    local gcmds = {}
    for _, w in ipairs(hroute) do
      gcmds[#gcmds + 1] = {type = defines.command.go_to_location, destination = w, radius = 6,
        distraction = drop and defines.distraction.none or defines.distraction.by_damage}
    end
    -- (Then behind its site, guard_spot: its start point there since 0.2.149, a guard left behind its hauler walked home.)
    -- (A drop siege's answer only what hits them, the march's look keeping none of them near its site: on sight, they
    -- walked on from its site into the lasers' reach and all 10 died before its pods came, standsiege, 0.2.165.)
    gcmds[#gcmds + 1] = {type = defines.command.go_to_location, destination = guard_spot(b, b.op), radius = 6,
      distraction = drop and defines.distraction.none or clearance and defines.distraction.by_damage
        or defines.distraction.by_enemy}
    order_all(guards, #gcmds > 1 and {type = defines.command.compound, structure_type = defines.compound_command.return_last,
      commands = gcmds} or gcmds[1])
  end
  b.op.route = b.op.route or hroute
  b.ops_launched = b.ops_launched + 1
  b.sieges = (b.sieges or 0) + 1
  if against_player(t.owner) then storage.threat_last = game.tick end
  trace(b, string.format("siege of %s at %.0f,%.0f (value %d, defence %.1f%s): tier %d, %d mortars to %.0f,%.0f, %d guards",
    t.kind, t.pos[1], t.pos[2], t.value, t.defence or 0, t.shells_need and string.format(", %d shells to break its guns",
    t.shells_need) or "", tier, spec.mortars, site[1], site[2], #guards)
    .. (t.way_keeps and string.format("; its way keeps %.2f", t.way_keeps) or "")
    .. (b.op.read_route and string.format(", read from orbit (%d waypoints)", #hroute) or ""))
  return true
end

-- Clearance (Serenity, the biter-country consult): a siege on the nest nearest its way, from a site 33 tiles off
-- (beyond a medium worm's 30), always dug in, tier 2 (two mortars, a resupply convoy). Its mortars fire on the nests by
-- themselves; it packs up when nothing is left in reach, and the corridor it leaves (ops.cleared) lets marches through.
-- The site 33 tiles from a nest, towards `from` (then at angles off that line), out of every worm's own reach plus 2
-- (its prototype's range: a big worm's 38 and a behemoth's 48 outrange the mortars' 35, and at maximum evolution the
-- hauler died on the way every two minutes all night, visit). None: mortars cannot clear it.
-- Out of every worm's reach, by `margin` more (the guards' ring: the site was out of reach, its railgunners guarding
-- 24 tiles round it were not, and six died to big worms 5 to 10 tiles from it, visit nw).
local LEASH = 6
local function out_of_worms(s, p, margin)
  margin = margin or 2
  for _, w in pairs(s.find_entities_filtered{position = p, radius = 52 + margin, type = "turret", force = shared.NEST_FORCES}) do
    local ap = w.prototype.attack_parameters
    local r = (ap and ap.range or 30) + margin
    if (w.position.x - p[1]) ^ 2 + (w.position.y - p[2]) ^ 2 <= r * r then return false end
  end
  return true
end
-- The howitzer stands further off when it must (`far`: up to its reach less a margin, on more bearings): from its 53
-- alone, a behemoth worm's 48 and the guards' 14 left no site, and on nw every nest by the camp "outranged even the
-- howitzer" while the waves came from it.
local function clearance_site(s, nest, from, stand, far)
  stand = stand or 33
  local base = math.atan2(from[2] - nest.position.y, from[1] - nest.position.x)
  local dists = {stand}
  if far then for d = stand + 12, far, 12 do dists[#dists + 1] = d end end
  local turns = far and {0, 0.35, -0.35, 0.7, -0.7, 1.05, -1.05, 1.4, -1.4} or {0, 0.35, -0.35, 0.7, -0.7}
  for _, d in ipairs(dists) do
    for _, turn in ipairs(turns) do
      local p = {nest.position.x + math.cos(base + turn) * d, nest.position.y + math.sin(base + turn) * d}
      if out_of_worms(s, p, CLEAR_GUARD + 2) and s.count_entities_filtered{position = p, radius = 4, collision_mask = "water_tile", limit = 1} == 0 then
        return p
      end
    end
  end
end
-- The next nest on the way from `from` to `to` (within 40 tiles of the straight line, nearest `from`).
local function nest_on_way(s, from, to)
  local dx, dy = to[1] - from[1], to[2] - from[2]
  local len2 = math.max(1, dx * dx + dy * dy)
  local near, nd
  for _, e in pairs(s.find_entities_filtered{position = from, radius = math.sqrt(len2), type = {"unit-spawner", "turret"},
    force = shared.NEST_FORCES}) do
    local f = math.max(0, math.min(1, ((e.position.x - from[1]) * dx + (e.position.y - from[2]) * dy) / len2))
    local off = (from[1] + dx * f - e.position.x) ^ 2 + (from[2] + dy * f - e.position.y) ^ 2
    local d = (e.position.x - from[1]) ^ 2 + (e.position.y - from[2]) ^ 2
    if off <= 40 * 40 and (not nd or d < nd) then near, nd = e, d end
  end
  return near
end

function ops.clearance(b, near, trace, army, toward)
  if not shared.capable(b.corp, "siege", 99) or b.op then return false end
  local h = home(b)
  if not h then return false end
  local s = game.surfaces[b.surface]
  local key = "nest:" .. math.floor(near.position.x / CELL) .. "," .. math.floor(near.position.y / CELL)
  b.intel.targets[key] = b.intel.targets[key] or {tried = 0, cool = 0}
  local t = b.intel.targets[key]
  t.pos, t.kind, t.value, t.seen, t.owner = {near.position.x, near.position.y}, near.name, 3, game.tick, "enemy"
  t.defence = s.count_entities_filtered{position = near.position, radius = DEFENCE_RADIUS, force = shared.NEST_FORCES, type = "turret"}
  -- A nest whose clearance failed rests (t.cool, siege_step; b.nest_rest outlives the intel, which forgets nests off
  -- its claim: the same refusal was traced every two minutes).
  b.nest_rest = b.nest_rest or {}
  if (t.cool or 0) > game.tick or (b.nest_rest[key] or 0) > game.tick then return false, "resting" end
  local piece, reach = "lp-mortar", MORTAR_REACH
  local site = clearance_site(s, near, {h.position.x, h.position.y})
  if not site then
    -- Worms that outrange the mortar: the howitzer, from beyond a behemoth worm's reach.
    site = clearance_site(s, near, {h.position.x, h.position.y}, HOWITZER_STAND, HOWITZER_REACH - 10)
    piece, reach = "lp-howitzer", HOWITZER_REACH
    if site and (b.howitzer_down or 0) > game.tick then return false, "howitzer lost" end
  end
  if not site then
    t.cool = game.tick + 15 * 3600
    b.nest_rest[key] = t.cool
    trace(b, string.format("clearance: the nest at %.0f,%.0f outranges even the howitzer", near.position.x, near.position.y))
    return false, "out of reach"
  end
  if (b.parts or 0) < SIEGE_TIERS[2].cost then return false, string.format("parts %d of %d", b.parts or 0, SIEGE_TIERS[2].cost) end
  -- Railgunners to hold the site: the nest's defenders came out at the first shells and broke the mortars of eight Line
  -- troopers in 35 s (visit b - rocket). Until it has CLEAR_RAILS at home, it asks for them (army.produce) and waits.
  local rails = 0
  for _, u in ipairs(b.garrison) do if u.valid and shared.kind_of(u.name) == "lp-railgunner" then rails = rails + 1 end end
  b.want_rails = rails < CLEAR_RAILS * 2
  b.rails_short = rails < CLEAR_RAILS and CLEAR_RAILS or nil   -- what it waits for (army.produce makes them over the cap)
  if rails < CLEAR_RAILS then
    if not b.rails_traced then
      b.rails_traced = true
      trace(b, string.format("clearance: waits for railgunners (%d of %d)", rails, CLEAR_RAILS))
    end
    return false, string.format("railgunners %d of %d", rails, CLEAR_RAILS)
  end
  b.rails_traced = nil
  b.rails_short = nil
  local ok = launch_siege(b, key, site, trace, army, 2, true, piece)
  if ok then
    b.op.piece, b.op.reach = piece, reach
    b.op.clear_for = toward
    b.clearances = (b.clearances or 0) + 1
    trace(b, string.format("clearance: a siege on the nest at %.0f,%.0f from %.0f,%.0f%s", near.position.x, near.position.y,
      site[1], site[2], piece == "lp-howitzer" and ", a howitzer (its worms outrange the mortars)" or ""))
  end
  return ok
end

-- Hazard removal (docs/reviews/2026-10-19-buffer-consult.md: "A patient corporation does not absorb a hazard for
-- three hours"). Serenity landed between a factory and the nests its pollution draws, and the waves went through its
-- settlement: 116 responses, 1,236 buildings lost on nw. A camp that lost HAZARD_LOSSES buildings or units to biters
-- within HAZARD_WINDOW clears the nest nearest those losses (a clearance siege: its railgunners and mortars, away from
-- the player), again as nests regrow. Its strength gates it: a clearance waits for its railgunners and parts.
-- Its tell: a siege going out away from the player, the lane going quiet.
local HAZARD_WINDOW = 30 * 3600
local HAZARD_LOSSES = 20
local HAZARD_REACH = 300         -- a nest this far from the losses' middle
local HAZARD_RETRY = 5 * 3600
ops.BILL_BUILDING, ops.BILL_UNIT = 8, 3   -- the ledger's price of a loss, in value (ops.LOOT_VALUE: a circuit is 1)
local function hazard_trim(h)
  local cut = game.tick - HAZARD_WINDOW
  local k = 1
  while h.log[k] and h.log[k][1] < cut do k = k + 1 end
  if k > 1 then
    local keep = {}
    for i = k, #h.log do keep[#keep + 1] = h.log[i] end
    h.log = keep
  end
end
function ops.hazard_note(b, pos, unit)
  b.hazard = b.hazard or {log = {}}
  table.insert(b.hazard.log, {game.tick, pos.x, pos.y})
  b.biter_losses = (b.biter_losses or 0) + 1
  -- What the ledger has not billed yet (scripts/ledger.lua): count, sum of positions, value.
  local u = b.unbilled or {n = 0, x = 0, y = 0, cost = 0}
  u.n, u.x, u.y = u.n + 1, u.x + pos.x, u.y + pos.y
  u.cost = u.cost + (unit and ops.BILL_UNIT or ops.BILL_BUILDING)
  b.unbilled = u
  if #b.hazard.log > 4 * HAZARD_LOSSES then hazard_trim(b.hazard) end
end
function ops.hazard_clear(b, trace, army)
  local h = b.hazard
  if storage.hazard_off or not h or game.tick < (h.next or 0) then return false end
  hazard_trim(h)
  if #h.log < HAZARD_LOSSES then return false end
  h.next = game.tick + HAZARD_RETRY
  local mx, my = 0, 0
  for _, l in ipairs(h.log) do mx, my = mx + l[2], my + l[3] end
  mx, my = mx / #h.log, my / #h.log
  local s = game.surfaces[b.surface]
  -- The nearest not resting from a failed clearance (one beyond even the howitzer was chosen again for two hours, nw).
  local near, nd
  local rest = b.nest_rest or {}
  for _, e in pairs(s.find_entities_filtered{position = {mx, my}, radius = HAZARD_REACH, force = "enemy", type = "unit-spawner"}) do
    local d = (e.position.x - mx) ^ 2 + (e.position.y - my) ^ 2
    local key = "nest:" .. math.floor(e.position.x / CELL) .. "," .. math.floor(e.position.y / CELL)
    if (rest[key] or 0) <= game.tick and (not nd or d < nd) then near, nd = e, d end
  end
  if not near then
    trace(b, string.format("hazard: %d lost to biters round %.0f,%.0f in 30 minutes; no nest within %d", #h.log, mx, my, HAZARD_REACH))
    return false
  end
  -- Tried: from now on the ledger may bill (it never bills a hazard Serenity has not tried to remove itself).
  b.hazard_tried = true
  if storage.hazard_hold then
    trace(b, string.format("hazard: the nest at %.0f,%.0f is held (test)", near.position.x, near.position.y))
    return false
  end
  local ok, why = ops.clearance(b, near, trace, army)
  trace(b, string.format("hazard: %d lost to biters round %.0f,%.0f in 30 minutes; the nest at %.0f,%.0f %s", #h.log, mx, my,
    near.position.x, near.position.y, ok and "gets a clearance" or ("waits (" .. (why or "no launch") .. ")")))
  if ok then
    b.hazards = (b.hazards or 0) + 1
    h.log = {}
  end
  return ok
end

-- The howitzer packing up (into its truck: ops.truck_up): it and the mortars silent from the moment it starts.
local function quiet_pack(op)
  local piece = op.truck and truck_piece(op)
  if not (piece and piece.active) then return piece end
  piece.disabled_by_script = true
  for _, m in ipairs(op.mortars or {}) do if m.valid then m.disabled_by_script = true end end
  if op.label and op.label.valid then op.label.destroy() end
  op.label = rendering.draw_text{text = {"lp.siege-packing"}, surface = piece.surface, target = {entity = piece, offset = {0, -2}},
    color = {1, 0.6, 0.3}, scale = 1.5, alignment = "center"}
  return piece
end

-- A drop siege's march (op.drop, launch_siege): its guards go its way; its lead is the guard nearest its site. Those with
-- no orders left short of its site go on with the rest of its way, from its waypoint nearest each. Its progress: its lead
-- nearer its site, or further along its way (on the cost map's way round the guns it goes away from its site first).
-- Held (half its living guards within DROP_HOLD of its site), its pieces come down (deploy). Returns the lead's
-- position and its squared distance to its site, or nil when it was called off.
local DROP_HOLD = 16
local function rest_of_way(route, from, to)
  local cmds, first, fd = {}, nil, nil
  for i, w in ipairs(route or {}) do
    local d = (w[1] - from.x) ^ 2 + (w[2] - from.y) ^ 2
    if not fd or d < fd then first, fd = i, d end
  end
  for i = first or 1, first and #route or 0 do
    cmds[#cmds + 1] = {type = defines.command.go_to_location, destination = route[i], radius = 6,
      distraction = defines.distraction.none}
  end
  cmds[#cmds + 1] = {type = defines.command.go_to_location, destination = to, radius = 6,
    distraction = defines.distraction.none}
  return cmds, first or 0
end
local function drop_march(b, op, trace, army, n)
  local hp, d2
  for _, u in ipairs(op.members) do
    if u.valid then
      local d = (u.position.x - op.site[1]) ^ 2 + (u.position.y - op.site[2]) ^ 2
      if not d2 or d < d2 then hp, d2 = u.position, d end
    end
  end
  if not hp then
    trace(b, "siege: its guards were lost on the way")
    local t = op.clearance and b.intel.targets[op.target]
    if t then t.cool = game.tick + 15 * 3600 end
    finish(b, "intercepted", trace, army)
    return nil
  end
  local spot = guard_spot(b, op)
  local held = 0
  for _, u in ipairs(op.members) do
    if u.valid then
      local du = (u.position.x - op.site[1]) ^ 2 + (u.position.y - op.site[2]) ^ 2
      if du <= DROP_HOLD ^ 2 then
        held = held + 1
      elseif not u.commandable.has_command then
        local cmds = rest_of_way(op.route, u.position, spot)
        u.commandable.set_command(#cmds > 1 and {type = defines.command.compound,
          structure_type = defines.compound_command.return_last, commands = cmds} or cmds[1])
      end
    end
  end
  if ops.corridor and op.route and game.tick >= (op.corridor_at or op.started) + CORRIDOR_LOOK then
    op.corridor_at = game.tick
    local rest = {}
    for _, w in ipairs(op.route) do
      if (w[1] - op.site[1]) ^ 2 + (w[2] - op.site[2]) ^ 2 < d2 then table.insert(rest, w) end
    end
    ops.corridor(b, {hp.x, hp.y}, rest, op.site)
  end
  local _, idx = rest_of_way(op.route, hp, spot)
  if not op.best_d2 or d2 < op.best_d2 - 4 or idx > (op.best_idx or 0) then
    op.best_d2, op.best_idx, op.best_at = math.min(d2, op.best_d2 or d2), math.max(idx, op.best_idx or 0), game.tick
  end
  if held * 2 >= n then return hp, 0 end
  if game.tick - (op.best_at or op.started) > STUCK_TICKS then
    local t = b.intel.targets[op.target]
    local s = game.surfaces[b.surface]
    if op.clearance and t and (hp.x - t.pos[1]) ^ 2 + (hp.y - t.pos[2]) ^ 2 <= (op.reach or MORTAR_REACH) ^ 2
      and out_of_worms(s, {hp.x, hp.y}) then
      trace(b, string.format("siege: its guards stopped %.0f tiles short; it drops where they stand", math.sqrt(d2)))
      op.site = {hp.x, hp.y}
      return hp, 0
    end
    trace(b, string.format("siege: its guards no nearer its site for a minute, %.0f tiles short; called off", math.sqrt(d2)))
    if t then t.cool = math.max(t.cool or 0, game.tick + 15 * 3600) end
    finish(b, "aborted", trace, army)
    return nil
  end
  return hp, d2
end
-- Its pieces' spots: side by side across its line of fire, 4 apart (deploy places them there).
local function gun_spot(b, op, spec, k)
  local tg = op.target and b.intel.targets[op.target]
  local fire = tg and tg.pos and math.atan2(tg.pos[2] - op.site[2], tg.pos[1] - op.site[1]) or 0
  local a = fire + math.pi / 2
  local off = spec.mortars > 1 and 4 * (k - (spec.mortars + 1) / 2) or 0
  return {op.site[1] + math.cos(a) * off, op.site[2] + math.sin(a) * off}
end

local function siege_step(b, trace, army)
  local op = b.op
  local n = alive(op)
  if game.tick - op.started > SIEGE_MAX_TICKS and not (op.standing and op.phase == "bombard") then
    if op.hauler and op.hauler.valid then
      local hp = op.hauler.position
      trace(b, string.format("siege: out of time in %s, the hauler at %.0f,%.0f, %.0f tiles from the site (%s)", op.phase, hp.x, hp.y,
        math.sqrt((hp.x - op.site[1]) ^ 2 + (hp.y - op.site[2]) ^ 2), op.hauler.commandable.has_command and "moving" or "no order"))
    end
    return finish(b, "aborted", trace, army)
  end
  if (op.phase == "march" or op.phase == "deploy") and not op.drop then
    if not op.hauler.valid then
      trace(b, "siege: the hauler was destroyed on the way")
      -- A clearance's nest rests 15 minutes (retried every two, it lost a hauler each time, visit).
      local t = op.clearance and b.intel.targets[op.target]
      if t then t.cool = game.tick + 15 * 3600 end
      return finish(b, "intercepted", trace, army)
    end
  end
  if op.phase == "march" and op.drop then
    local hp, d2 = drop_march(b, op, trace, army, n)
    if not hp then return end
    if d2 == 0 then
      op.phase, op.phase_at = "deploy", game.tick
      local s = game.surfaces[b.surface]
      local spec = SIEGE_TIERS[op.tier or 1]
      local guns = op.piece == "lp-howitzer" and 1 or (op.carry and #op.carry or spec.mortars)
      op.drops = {}
      for k = 1, guns do op.drops[#op.drops + 1] = pods.send(s, gun_spot(b, op, spec, k), b.force) end
      if op.with_howitzer and not op.howitzer then op.drops[#op.drops + 1] = pods.send(s, {op.site[1], op.site[2] + 6}, b.force) end
      order_all(op.members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = {{type = defines.command.go_to_location, destination = guard_spot(b, op), radius = 4,
          distraction = defines.distraction.by_damage},
          {type = defines.command.wander, radius = 4, distraction = defines.distraction.by_damage}}})
      op.label = rendering.draw_text{text = {"lp.siege-deploying"}, surface = s, target = {op.site[1], op.site[2] - 3},
        color = {1, 0.6, 0.3}, scale = 1.5, alignment = "center"}
      trace(b, string.format("siege: its guards hold its site at %.0f,%.0f; %d pods drop its pieces", op.site[1], op.site[2],
        #op.drops))
    end
  elseif op.phase == "march" then
    local hp = op.hauler.position
    if not op.hauler.commandable.has_command then
      op.hauler.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = {{type = defines.command.go_to_location, destination = op.site, radius = 2,
          distraction = defines.distraction.none}, HOLD}}
    end
    -- (Near its site, only what hits them: its site is just out of the guns' reach, inside their sight, and guards that
    -- engaged what they saw charged the lasers from it and died, four tanks, the siege called off; fortress 12345.)
    local near_site = (hp.x - op.site[1]) ^ 2 + (hp.y - op.site[2]) ^ 2 < GUARD_CALM ^ 2
    -- (And then wait, answering what hits them: arrived before its next look, 300 ticks on, they wandered, the engine's
    -- default, engaging what they saw: its laser drones, first there, flew into the lasers' reach and drew the rest in.)
    local eye = (op.clearance or near_site) and defines.distraction.by_damage or defines.distraction.by_enemy
    -- (Behind it on the march too, ESCORT_BACK from its way to the site.)
    local behind = hp
    if not near_site then
      local dx, dy = op.site[1] - hp.x, op.site[2] - hp.y
      local dl = math.max(1, math.sqrt(dx * dx + dy * dy))
      behind = {x = hp.x - dx / dl * ESCORT_BACK, y = hp.y - dy / dl * ESCORT_BACK}
    end
    -- (Those near its hauler kept behind it; the rest go on along its way, their own orders, ESCORT_NEAR.)
    local close = {}
    for _, u in ipairs(op.members) do
      if u.valid and (near_site or (u.position.x - hp.x) ^ 2 + (u.position.y - hp.y) ^ 2 <= ESCORT_NEAR ^ 2
        or not u.commandable.has_command) then
        close[#close + 1] = u
      end
    end
    order_all(close, {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = {
      {type = defines.command.go_to_location, destination = near_site and guard_spot(b, op) or behind, radius = 6, distraction = eye},
      {type = defines.command.stop, distraction = defines.distraction.by_damage}}})
    -- Stuck (a hauler drove at the same spot 21 tiles short of its site for 15 minutes, visit b - rocket): no nearer for a
    -- minute, a clearance deploys where it stands if the nest is in the mortars' reach and it is out of the worms'; else
    -- the siege is called off now.
    local d2 = (hp.x - op.site[1]) ^ 2 + (hp.y - op.site[2]) ^ 2
    -- Its order given up short of its site (the engine drops a go-to it is stuck on and runs the rest: its HOLD, and the
    -- truck stood there for good with its order live; fortress, 0.2.149): sent on to its site again, at most
    -- REISSUE_MAX times, before the stuck rule below calls it off.
    local c = op.hauler.commandable
    local cmd = c.command
    local held = cmd and cmd.commands and #cmd.commands == 1 and cmd.commands[1].type ~= defines.command.go_to_location
    if d2 >= 5 * 5 and (held or c.moving_state == defines.moving_state.stuck) and (op.reissued or 0) < REISSUE_MAX then
      op.reissued = (op.reissued or 0) + 1
      -- Its own guards out of its way first: sent on into its escort's tanks alone, it stuck again three times
      -- (fortress, the escort set round it).
      local dx, dy = op.site[1] - hp.x, op.site[2] - hp.y
      local dl = math.max(1, math.sqrt(dx * dx + dy * dy))
      local back = {x = hp.x - dx / dl * math.max(ESCORT_BACK, 8), y = hp.y - dy / dl * math.max(ESCORT_BACK, 8)}
      local cleared = {}
      for _, u in ipairs(op.members) do
        if u.valid and (u.position.x - hp.x) ^ 2 + (u.position.y - hp.y) ^ 2 <= 8 * 8 then table.insert(cleared, u) end
      end
      order_all(cleared, {type = defines.command.go_to_location, destination = back, radius = 4,
        distraction = defines.distraction.by_damage})
      -- On the rest of its way, from its waypoint nearest it: sent straight at its site, it drove across the worm belt its
      -- way went round, its guards behind it, 6 of 10 killed by big worms (standsiege nests, 0.2.164).
      local cmds, first, fd = {}, nil, nil
      for i, w in ipairs(op.route or {}) do
        local d = (w[1] - hp.x) ^ 2 + (w[2] - hp.y) ^ 2
        if not fd or d < fd then first, fd = i, d end
      end
      for i = first or 1, first and #op.route or 0 do
        cmds[#cmds + 1] = {type = defines.command.go_to_location, destination = op.route[i], radius = 4,
          distraction = defines.distraction.none}
      end
      cmds[#cmds + 1] = {type = defines.command.go_to_location, destination = op.site, radius = 2,
        distraction = defines.distraction.none}
      cmds[#cmds + 1] = HOLD
      c.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = cmds}
      trace(b, string.format("siege: the hauler %s %.0f tiles short of its site; %d guards out of its way, sent on (%d)",
        held and "gave up its way" or "is stuck", math.sqrt(d2), #cleared, op.reissued))
    end
    -- And the nests by the rest of its way, every CORRIDOR_LOOK (grown, or come since it set out): war.corridor.
    if ops.corridor and op.route and game.tick >= (op.corridor_at or op.started) + CORRIDOR_LOOK then
      op.corridor_at = game.tick
      -- (The rest: its waypoints nearer the site than the hauler.)
      local rest = {}
      for _, w in ipairs(op.route) do
        if (w[1] - op.site[1]) ^ 2 + (w[2] - op.site[2]) ^ 2 < d2 then table.insert(rest, w) end
      end
      ops.corridor(b, {hp.x, hp.y}, rest, op.site)
    end
    if not op.best_d2 or d2 < op.best_d2 - 4 then op.best_d2, op.best_at = d2, game.tick end
    -- (Progress along its way too, a waypoint done: on the cost map's way round the guns its hauler drove 160 tiles away
    -- from its site, and judged by its distance to the site alone it was called off as stuck; the artillery base,
    -- seed 2, 0.2.160.)
    local left = cmd and cmd.commands and #cmd.commands
    if left and (not op.best_left or left < op.best_left) then op.best_left, op.best_at = left, game.tick end
    if game.tick - op.best_at > STUCK_TICKS and d2 >= 5 * 5 then
      local t = b.intel.targets[op.target]
      local s = op.hauler.surface
      if op.clearance and t and (hp.x - t.pos[1]) ^ 2 + (hp.y - t.pos[2]) ^ 2 <= (op.reach or MORTAR_REACH) ^ 2
        and out_of_worms(s, {hp.x, hp.y}) then
        trace(b, string.format("siege: the hauler is stuck %.0f tiles short; it deploys where it stands", math.sqrt(d2)))
        op.site = {hp.x, hp.y}
        d2 = 0
      else
        trace(b, string.format("siege: the hauler is stuck %.0f tiles short of its site; called off", math.sqrt(d2)))
        if t then t.cool = math.max(t.cool or 0, game.tick + 15 * 3600) end
        return finish(b, "aborted", trace, army)
      end
    end
    if d2 < 5 * 5 then
      op.phase, op.phase_at = "deploy", game.tick
      op.hauler.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none}
      -- Guards fight only what hits them: engaging what they saw, they walked from the site into turret range
      -- and four of six died (abort).
      -- A clearance's guards are on guard duty instead (bombard).
      local guard_eye = defines.distraction.by_damage
      order_all(op.members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = {{type = defines.command.go_to_location, destination = guard_spot(b, op), radius = 4,
          distraction = guard_eye},
          {type = defines.command.wander, radius = 4, distraction = guard_eye}}})
      op.label = rendering.draw_text{text = {"lp.siege-deploying"}, surface = op.hauler.surface,
        target = {entity = op.hauler, offset = {0, -2}}, color = {1, 0.6, 0.3}, scale = 1.5, alignment = "center"}
      trace(b, string.format("siege: deploying at %.0f,%.0f", op.site[1], op.site[2]))
    end
  elseif op.phase == "deploy" then
    local share = (game.tick - op.phase_at) / DEPLOY_TICKS
    if op.label and op.label.valid then op.label.text = {"lp.siege-deploying-percent", string.format("%d", math.min(100, share * 100))} end
    if share >= 1 then
      local s, force = game.surfaces[b.surface], game.forces[b.force]
      -- The truck gives way to its howitzer (ops.truck_down).
      local truck = op.truck and truck_down(op)
      local spec = SIEGE_TIERS[op.tier or 1]
      local name = shared.variant(b.corp, op.piece or "lp-mortar")
      local guns = op.piece == "lp-howitzer" and 1 or spec.mortars
      local carry = op.carry
      op.mortars, op.carry = {}, nil
      if not carry then op.loaded = 0 end
      for k = 1, (carry and #carry or guns) do
        -- (Side by side across its line of fire, 4 apart, none nearer its target than its site: in a ring of 4 round it,
        -- one stood 4 tiles nearer, in a tesla's reach where its site was not.)
        local tg = op.target and b.intel.targets[op.target]
        local fire = tg and tg.pos and math.atan2(tg.pos[2] - op.site[2], tg.pos[1] - op.site[1]) or 0
        local a = fire + math.pi / 2
        local off = spec.mortars > 1 and 4 * (k - (spec.mortars + 1) / 2) or 0
        local here = op.piece == "lp-howitzer" and truck
        local p = here and s.find_non_colliding_position(name, here.pos, 8, 0.5)
          or s.find_non_colliding_position(name, {op.site[1] + math.cos(a) * off, op.site[2] + math.sin(a) * off}, 8, 0.5)
        local m = p and s.create_entity{name = name, position = p, force = force, direction = here and here.dir or nil}
        if m and here then m.health = math.max(1, here.share * m.max_health) end
        -- A siege's mortar against a player is no military target: the player's artillery does not pick it by itself
        -- (data.lua). Against nests it stays one (biters go for military targets first: it draws them off its guards).
        if m and m.name ~= shared.variant(b.corp, "lp-howitzer") and tg and tg.owner ~= "enemy" and against_player(tg.owner) then
          m.is_military_target = false
          if k == 1 then trace(b, "siege: its mortars no military target (the player's artillery leaves them alone)") end
        end
        if m then
          local shells = carry and carry[k] or spec.shells * (op.piece == "lp-howitzer" and 2 or 1)
          if shells > 0 then m.insert{name = "lp-mortar-shell", count = shells} end
          if not carry then op.loaded = op.loaded + shells end
          table.insert(op.mortars, m)
          -- (Credited to its settlement as its units are, storage.unit_owner: what its shells break is its razing. Not, a
          -- tier-1 siege's mortar killed 3 lasers of the lane and its record read nothing razed; the lane, 2026-10-31.)
          storage.unit_owner = storage.unit_owner or {}
          if m.unit_number then storage.unit_owner[m.unit_number] = b.id end
        end
      end
      op.mortar = op.mortars[1]
      if not op.mortar then return finish(b, "aborted", trace, army) end
      if op.with_howitzer and not op.howitzer then
        local hn = shared.variant(b.corp, "lp-howitzer")
        -- Apart from its mortars, howitzer_apart across the line of fire, out of every gun's reach: a military target, the
        -- player's artillery shells it by itself, and beside the mortars its splash killed them within 10 s, twice (the
        -- artillery base, era 3, 2026-11-02: the mortars no military target since 0.2.132, undone by their neighbour).
        local at = truck and truck.pos or {op.site[1], op.site[2]}
        local tg = op.target and b.intel.targets[op.target]
        -- (Its truck's spot too: the howitzer comes off its truck where that parked, by the mortars.)
        if tg and tg.pos then
          local fire = math.atan2(tg.pos[2] - op.site[2], tg.pos[1] - op.site[1])
          local apart = howitzer_apart(hn, op.mortar.name)
          for _, side in ipairs({1, -1}) do
            local q = {op.site[1] + math.cos(fire + side * math.pi / 2) * apart,
              op.site[2] + math.sin(fire + side * math.pi / 2) * apart}
            if out_of_reach(s, q, enemies(game.forces[b.force])) then at = q; break end
          end
        end
        local p = s.find_non_colliding_position(hn, at, 12, 1)
        op.howitzer = p and s.create_entity{name = hn, position = p, force = force, direction = truck and truck.dir or nil}
        if op.howitzer then
          -- (Its settlement's, as its mortars: what it breaks is its razing.)
          storage.unit_owner = storage.unit_owner or {}
          if op.howitzer.unit_number then storage.unit_owner[op.howitzer.unit_number] = b.id end
          if truck then op.howitzer.health = math.max(1, truck.share * op.howitzer.max_health) end
          op.howitzer.insert{name = "lp-mortar-shell", count = op.howitzer_carry or spec.shells}
          op.howitzer_carry = nil
          trace(b, "siege: a howitzer for the roboports")
        end
        if rd.has(b.corp, "jammer") and not op.jammer then
          op.jammer = jammer.raise(s, {op.site[1], op.site[2]}, force)
          if op.jammer then trace(b, "siege: a jamming mast for their robots") end
        end
      end
      if op.label and op.label.valid then op.label.destroy() end
      op.phase, op.phase_at = "bombard", game.tick
      alert(b, b.intel.targets[op.target], "lp.alert-siege", op.site)
      trace(b, string.format("siege: %d mortars up with %d shells", #op.mortars, op.loaded - op.shells_fired))
      -- An armed camp's siege calls its orbital strike on the wall (scripts/orbital.lua).
      if not op.clearance then orbital.call(b, op) end
      if op.standing and ops.site_dome then ops.site_dome(b, op) end
      -- Hardened siege (Serenity): the site digs in, a ring of wall open towards home and two gun pillboxes, cleared
      -- when the siege ends (op.works).
      if (rd.has(b.corp, "hardened") or op.clearance) and not op.works then
        op.works = {}
        local h = home(b)
        local away = h and math.atan2(h.position.y - op.site[2], h.position.x - op.site[1]) or 0
        for k = 0, 35 do
          local a = 2 * math.pi * k / 36
          local d = math.abs(((a - away + math.pi) % (2 * math.pi)) - math.pi)
          if d > 0.5 then
            local p = {op.site[1] + math.cos(a) * 7, op.site[2] + math.sin(a) * 7}
            local w = s.can_place_entity{name = shared.variant(b.corp, "lp-wall"), position = p, force = force}
              and s.create_entity{name = shared.variant(b.corp, "lp-wall"), position = p, force = force}
            if w then table.insert(op.works, w) end
          end
        end
        for _, dx in ipairs({-3, 3}) do
          local p = s.find_non_colliding_position("lp-gun-turret", {op.site[1] + dx, op.site[2] + 3}, 4, 0.5)
          local g = p and s.create_entity{name = "lp-gun-turret", position = p, force = force}
          if g then
            g.insert{name = "piercing-rounds-magazine", count = 50}
            table.insert(op.works, g)
          end
        end
        trace(b, string.format("siege: the site dug in (%d pieces)", #op.works))
      end
    end
  elseif op.phase == "bombard" or op.phase == "assault" then
    -- Guard duty (a clearance): biters that come for the mortars are shot, and the guards go back to the site. Told to
    -- engage on sight they charged the spawner 32 tiles off and died; told to answer only what hit them, they let the
    -- biters break the mortars (scenario clear, visit b - rocket).
    -- (siege_step runs every 300 ticks.)
    if op.clearance then
      local s = game.surfaces[b.surface]
      -- Tighter at a howitzer's site: 24 out from it, guards stood in behemoth worms' reach (82 of 111 lost to acid).
      local guard_r = CLEAR_GUARD
      -- A leash: a guard more than LEASH beyond its ring walks back to the site, undistracted. Told to hold the ring,
      -- guards still followed what they fought out of it, and behemoth worms killed eight of ten 15 to 36 tiles from the
      -- site (scenario clear, worms, 2026-10-25).
      for _, u in ipairs(op.members) do
        if u.valid and (u.position.x - op.site[1]) ^ 2 + (u.position.y - op.site[2]) ^ 2 > (guard_r + LEASH) ^ 2 then
          u.commandable.set_command{type = defines.command.go_to_location, destination = {x = op.site[1], y = op.site[2]},
            radius = 6, distraction = defines.distraction.none}
        end
      end
      local foes = s.find_entities_filtered{position = op.site, radius = guard_r, type = "unit", force = shared.NEST_FORCES}
      if #foes > 0 then
        -- Within the ring only, undistracted: chasing biters, they followed them into the worms (scenario clear: railgunners
        -- killed by behemoth worms 26 to 31 tiles out).
        order_all(op.members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
          commands = {{type = defines.command.attack_area, destination = op.site, radius = guard_r,
            distraction = defines.distraction.none},
            {type = defines.command.go_to_location, destination = op.site, radius = 6, distraction = defines.distraction.none},
            -- A lasting order at the end: idle, a unit attacks whatever it sees, and guards walked into the worms.
            {type = defines.command.wander, radius = 5, distraction = defines.distraction.by_damage}}})
      end
    end
    local live = {}
    for _, m in ipairs(op.mortars or {op.mortar}) do if m.valid then table.insert(live, m) end end
    op.mortars, op.mortar = live, live[1]
    if not op.mortar and op.phase == "bombard" then
      trace(b, "siege: the mortars were destroyed")
      return finish(b, "aborted", trace, army)
    end
    local left, empty = 0, {}
    for _, m in ipairs(live) do
      local k = m.get_inventory(defines.inventory.artillery_turret_ammo).get_item_count("lp-mortar-shell")
      left = left + k
      if k == 0 then table.insert(empty, m) end
    end
    op.shells_fired = (op.loaded or SIEGE_SHELLS) - left
    local s = game.surfaces[b.surface]
    local foes = enemies(game.forces[b.force])
    -- Nothing left in reach for a minute: done (with eight shells fired and every turret in reach destroyed,
    -- a mortar sat idle until the siege timed out).
    local in_reach = 0
    for _, m in ipairs(live) do
      -- A clearance's targets are the nests (the player's turrets for any other siege).
      in_reach = in_reach + (op.clearance
        and s.count_entities_filtered{position = m.position, radius = op.reach or MORTAR_REACH, type = {"unit-spawner", "turret"}, force = shared.NEST_FORCES}
        or s.count_entities_filtered{position = m.position, radius = op.reach or MORTAR_REACH, type = TURRETS, force = foes})
    end
    if in_reach > 0 then op.last_target = game.tick end
    -- The fire plan (Fable's fortress consult): against a player, every mortar on one point at a time. Roboports in
    -- reach first (what keeps the wall up), then the weakest turret in reach: left to themselves the mortars spread 117
    -- shells along a laser wall and its robots mended every one, ten lasers at full health and 32 repair packs spent
    -- (fortress). A flare on the point is how a mortar is told (an artillery remote's flare; a turret's shooting
    -- target cannot be set from script).
    -- A standing siege calls its strike again once its camp's cooldown is over (orbital.call reads op.standing).
    if op.standing and op.phase == "bombard" then orbital.call(b, op) end
    if not op.clearance and op.phase == "bombard" and not storage.focus_off and t_owner_player(b, op) then
      local pieces = {}
      for _, m in ipairs(live) do pieces[#pieces + 1] = m end
      if op.howitzer and op.howitzer.valid then pieces[#pieces + 1] = op.howitzer end
      op.focus = focus(s, pieces, foes, op.focus)
      if op.focus then
        for _ = 1, #pieces do
          s.create_entity{name = "artillery-flare", position = op.focus.position, force = b.force, movement = {0, 0},
            height = 0, vertical_speed = 0, frame_speed = 0}
        end
        op.flares = (op.flares or 0) + #pieces
      end
    end
    -- Resupply: a convoy of shells when the mortars are spent and a turret is still in reach (a drop siege's comes down
    -- in a pod on its site).
    if op.supply_pod then
      if pods.down(s, op.supply_pod) and op.mortar then
        local to = #empty > 0 and empty or live
        local each = math.floor(RESUPPLY / math.max(1, #to))
        for _, m in ipairs(to) do m.insert{name = "lp-mortar-shell", count = each} end
        op.loaded = op.loaded + each * #to
        left = left + each * #to
        op.supply_pod = nil
        trace(b, string.format("siege: resupplied from orbit, %d shells", each * #to))
      end
    elseif op.convoy and not op.convoy.valid then
      trace(b, "siege: the shell convoy was destroyed; no more resupply")
      op.convoy, op.convoys_left = nil, 0
    elseif op.convoy then
      local cp = op.convoy.position
      if not op.convoy.commandable.has_command then
        op.convoy.commandable.set_command{type = defines.command.go_to_location, destination = op.site, radius = 2,
          distraction = defines.distraction.none}
      end
      if (cp.x - op.site[1]) ^ 2 + (cp.y - op.site[2]) ^ 2 < 8 * 8 and op.mortar then
        -- To the spent mortars (every one, if none is spent by now).
        local to = #empty > 0 and empty or live
        local each = math.floor(RESUPPLY / #to)
        for _, m in ipairs(to) do m.insert{name = "lp-mortar-shell", count = each} end
        op.loaded = op.loaded + each * #to
        left = left + each * #to
        b.haulers_home = b.haulers_home or {}
        table.insert(b.haulers_home, {unit = op.convoy, till = game.tick + 3 * 3600})
        local h = home(b)
        if h then
          op.convoy.commandable.set_command{type = defines.command.go_to_location, destination = h.position, radius = 12,
            distraction = defines.distraction.none}
        end
        op.convoy = nil
        trace(b, string.format("siege: resupplied, %d shells", each * #to))
      end
    elseif #empty > 0 and in_reach > 0 and (op.loaded or 0) + RESUPPLY <= SHELLS_CAP and op.standing
      and (op.convoys_left or 0) <= 0 and pay_convoy(b) then
      op.convoys_left = 1
      op.convoys_paid = (op.convoys_paid or 0) + 1
      trace(b, string.format("siege: a convoy paid (%d parts)", convoy_price()))
    elseif op.drop and #empty > 0 and in_reach > 0 and (op.convoys_left or 0) > 0 and (op.loaded or 0) + RESUPPLY <= SHELLS_CAP then
      op.supply_pod = pods.send(s, {op.site[1], op.site[2] + 3}, b.force)
      if op.supply_pod then
        op.convoys_left = op.convoys_left - 1
        trace(b, "siege: a pod of shells drops")
      end
    elseif #empty > 0 and in_reach > 0 and (op.convoys_left or 0) > 0 and (op.loaded or 0) + RESUPPLY <= SHELLS_CAP then
      local h = home(b)
      local p = h and s.find_non_colliding_position(shared.variant(b.corp, "lp-hauler"), h.position, 20, 0.5)
      op.convoy = p and s.create_entity{name = shared.variant(b.corp, "lp-hauler"), position = p, force = h.force}
      if op.convoy then
        op.convoys_left = op.convoys_left - 1
        op.convoy.commandable.set_command{type = defines.command.go_to_location, destination = op.site, radius = 2,
          distraction = defines.distraction.none}
        trace(b, "siege: a shell convoy sets out")
      end
    end
    local spec = SIEGE_TIERS[op.tier or 1]
    local t = b.intel.targets[op.target]
    if op.phase == "bombard" then
      -- Moving up (tier 2 and up, once): nothing in reach for ASSAULT_IDLE with shells left, the mortars pack and the
      -- hauler takes them to a site in reach of what still stands (two mortars spent 12 of 80 shells on the near
      -- side of a square and packed up).
      -- A clearance moves on along its way, nest after nest, while its shells last (one clearance per nest, each
      -- home and back, took 40 minutes for seven nests, push); any other siege moves up once.
      if op.pack_site or (spec.mortars > 1 and (op.clearance or not op.moved) and left > 0
        and (op.drop or op.truck or (op.hauler and op.hauler.valid)) and t and game.tick - (op.last_target or op.phase_at) > ASSAULT_IDLE) then
        local site
        if op.pack_site then
          site = op.pack_site
        elseif op.clearance then
          local nxt = op.clear_for and nest_on_way(s, op.site, op.clear_for)
          site = nxt and clearance_site(s, nxt, op.site, op.piece == "lp-howitzer" and HOWITZER_STAND or nil)
          op.steps = (op.steps or 0) + 1
          if op.steps > 8 then site = nil end
        else
          site = siege_site(b, t)
        end
        op.moved = true
        if site and (site[1] - op.site[1]) ^ 2 + (site[2] - op.site[2]) ^ 2 > 8 * 8 then
          -- A standing siege's dome goes with it (up again where it digs in next): left at its first site, its truck
          -- moving up was shelled on the way, three seeds of three on nw (0.2.152).
          if op.site_dome and ops.site_dome_down then ops.site_dome_down(b, op); op.site_dome = nil end
          -- The howitzer packs up before it moves (the user: no firing on the move), silent while it does.
          local piece = op.truck and truck_piece(op)
          if piece and not op.pack_site then
            op.pack_site, op.packing = site, game.tick
            quiet_pack(op)
            trace(b, "siege: the howitzer packs up to move")
            return
          elseif piece and game.tick - op.packing < TRUCK_PACK then
            if op.label and op.label.valid then
              op.label.text = {"lp.siege-packing-percent", string.format("%d", 100 * (game.tick - op.packing) / TRUCK_PACK)}
            end
            return
          end
          op.pack_site, op.packing = nil, nil
          if op.label and op.label.valid then op.label.destroy() end
          if piece then
            if piece == op.howitzer then
              op.howitzer_carry = piece.get_inventory(defines.inventory.artillery_turret_ammo).get_item_count("lp-mortar-shell")
              op.howitzer = nil
            else
              op.carry = {piece.get_inventory(defines.inventory.artillery_turret_ammo).get_item_count("lp-mortar-shell")}
              for i = #live, 1, -1 do if live[i] == piece then table.remove(live, i) end end
            end
            op.hauler = truck_up(b, piece)
            if not op.hauler then return finish(b, "aborted", trace, army) end
          end
          -- Its hauler gone while it stood at its site (shelled there), it cannot move: called off. (Read through as if it
          -- stood, the run died: the artillery base, era 3, 0.2.141.)
          if not op.drop and not (op.hauler and op.hauler.valid) then
            trace(b, "siege: its hauler was destroyed at the site; it cannot move")
            return finish(b, "aborted", trace, army)
          end
          op.carry = op.carry or {}
          for _, m in ipairs(live) do
            table.insert(op.carry, m.get_inventory(defines.inventory.artillery_turret_ammo).get_item_count("lp-mortar-shell"))
            m.destroy()
          end
          op.mortars, op.mortar, op.site = {}, nil, site
          op.phase, op.phase_at, op.last_target = "march", game.tick, nil
          op.best_d2, op.best_at = nil, nil
          -- A drop siege's guards march; its pieces come down again where they hold (drop_march).
          if op.drop then
            local from
            for _, u in ipairs(op.members) do if u.valid then from = u.position; break end end
            op.route = from and op.clearance and sneak_route(b, {from.x, from.y}, site, {turrets = false, worms = true}) or {}
            op.best_idx = nil
            local cmds = rest_of_way(op.route, from or {x = site[1], y = site[2]}, guard_spot(b, op))
            order_all(op.members, #cmds > 1 and {type = defines.command.compound,
              structure_type = defines.compound_command.return_last, commands = cmds} or cmds[1])
            trace(b, string.format("siege: moving up to %.0f,%.0f with %d shells (its pieces lifted)", site[1], site[2], left))
            return
          end
          -- Round the worms too (a bare straight move led the march past them, review).
          local hp = op.hauler.position
          local mroute = op.clearance and sneak_route(b, {hp.x, hp.y}, site, {turrets = false, worms = true}) or {}
          local mcmds = {}
          for _, w in ipairs(mroute) do
            table.insert(mcmds, {type = defines.command.go_to_location, destination = w, radius = 3,
              distraction = defines.distraction.none})
          end
          table.insert(mcmds, {type = defines.command.go_to_location, destination = site, radius = 2,
            distraction = defines.distraction.none})
          op.hauler.commandable.set_command{type = defines.command.compound,
            structure_type = defines.compound_command.return_last, commands = mcmds}
          trace(b, string.format("siege: moving up to %.0f,%.0f with %d shells", site[1], site[2], left))
          return
        end
      end
      -- The assault: the barrage over (nothing in reach for ASSAULT_IDLE after the mortars had targets, or the shells
      -- spent with no convoy coming), the guards go in with what the garrison can add, sized to what is left at the
      -- target. Tier 3 and up always; below, only when the guards and the garrison (its reserve too) make the force a raid
      -- there would need (the user, 2026-10-17: "destroys turrets, then nothing happens. The whole group ends up packing
      -- up and leaving home").
      local over = op.last_target and ((in_reach == 0 and game.tick - op.last_target > ASSAULT_IDLE)
        or (left == 0 and not op.convoy))
      -- (Sized as its raids are, ops.raid_want: what got in near there, else its formula on the prices its losses taught it,
      -- on its target read again after the barrage, the guns its shells broke gone from it. By the formula on its first
      -- reading, a siege whose mortar had broken 3 lasers asked an assault of 207 and went home.)
      if over and t and t.pos and not op.clearance and not op.reread then
        op.reread = true
        ops.sense_at(b, {x = t.pos[1], y = t.pos[2]}, 40)
      end
      local want = over and t and not op.clearance and ops.raid_want(b, t)
      -- Its reserve too: the barrage paid for and won, the camp commits (with the pool counting the guards out against
      -- the cap, a tier-1 siege's guards and spare came to 21 of the 22 needed, and it went home, bombard).
      local home_n = (function() local f, r = field(b, army) return f + r end)()
      if want and not spec.assault and n + home_n < want and not op.told_short then
        op.told_short = true
        trace(b, string.format("siege: no assault (%d needed, %d guards and %d at home)", want, n, home_n))
      end
      if want and (spec.assault or n + home_n >= want) then
        -- (Its living guards: the dead counted, it drew short and its abort at half came early; the review.)
        local live = {}
        for _, u in ipairs(op.members) do if u.valid then live[#live + 1] = u end end
        op.members = live
        for _, u in ipairs(pool.take(b, want - #op.members, pool.GUARD, FOOT)) do table.insert(op.members, u) end
        op.launched = #op.members
        op.phase, op.phase_at, op.last_kill, op.kills_at, op.razed_before = "assault", game.tick, game.tick, b.razed, b.razed
        b.assaults = (b.assaults or 0) + 1
        order_all(op.members, {type = defines.command.attack_area, destination = t.pos, radius = 16,
          distraction = defines.distraction.by_anything})
        alert(b, t, "lp.alert-raid")
        trace(b, string.format("siege: the assault goes in with %d units", #op.members))
        return
      end
      local idle = game.tick - (op.last_target or op.phase_at) > 60 * 60
      local waiting = op.convoy ~= nil
      if (left == 0 and not waiting) or idle or n < 0.5 * op.launched then
        op.phase, op.phase_at = "pack", game.tick
        op.packing_because = left == 0 and "spent" or (idle and "done" or "aborted")
        quiet_pack(op)
        trace(b, string.format("siege: packing up (%s; %d shells fired, %d of %d guards)", op.packing_because,
          op.shells_fired, n, op.launched))
      end
    else
      if b.razed > op.kills_at then op.kills_at, op.last_kill = b.razed, game.tick end
      local remaining = t and s.count_entities_filtered{position = t.pos, radius = 16, type = TYPES, force = foes} or 0
      local done = remaining == 0 or game.tick - op.last_kill > NO_KILL_TICKS
      if done or n < 0.5 * op.launched then
        op.phase, op.phase_at = "pack", game.tick
        op.packing_because = done and "done" or "aborted"
        quiet_pack(op)
        b.assault_razed = (b.assault_razed or 0) + b.razed - op.razed_before
        trace(b, string.format("siege: the assault ends (%s; %d of %d left, %d left standing at the target)",
          op.packing_because, n, op.launched, remaining))
        return
      end
      for _, u in ipairs(op.members) do
        if u.valid and not u.commandable.has_command and t then
          u.commandable.set_command{type = defines.command.attack_area, destination = t.pos, radius = 16,
            distraction = defines.distraction.by_anything}
        end
      end
    end
  elseif op.phase == "pack" then
    -- The howitzer folds into its truck slower than mortars pack, silent while it does (ops.finish drives it home).
    local piece = quiet_pack(op)
    if game.tick - op.phase_at >= (piece and TRUCK_PACK or PACK_TICKS) then return finish(b, op.packing_because, trace, army) end
  end
end
-- Tests and the siege lab: why it lays no siege (each of choose_siege's gates, and for its best target a mortar site).
local function siege_why(b, army)
  local h = home(b)
  local why = {parts = b.parts or 0, cost = SIEGE_COST, next_siege = b.next_siege, tick = game.tick,
    capable = shared.capable(b.corp, "siege", army.level(b)) or b.grudge ~= nil, field = field(b, army), guards = SIEGE_GUARDS,
    in_flight = ops.player_ops(), quiescent = b.quiescent, camp_hurt = ops.camp_hurt(b), targets = {}}
  for key, t in pairs(b.intel.targets) do
    if against_player(t.owner) and #why.targets < 4 then
      why.targets[#why.targets + 1] = {key = key, defence = t.defence, budget = budget(t.owner), besieged = besieged(t.owner),
        may = stance.may(b.corp, t.owner, "siege"), marked = t.pos and ops.marked(b, t.pos), site = h and siege_site(b, t) ~= nil}
    end
  end
  return why
end
return {choose_siege = choose_siege, launch_siege = launch_siege, siege_site = siege_site, siege_step = siege_step, siege_tier = siege_tier,
  siege_why = siege_why}
end

return siege
