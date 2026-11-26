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
local achievements = require("__landing-party__.scripts.achievements")

local siege = {}

function siege.install(ops, K)
local ASSAULT_IDLE = K.ASSAULT_IDLE
local CELL = K.CELL
local CLEAR_GUARD = K.CLEAR_GUARD
local COOL_TICKS = K.COOL_TICKS
local DEFENCE_RADIUS = K.DEFENCE_RADIUS
local DEPLOY_TICKS = K.DEPLOY_TICKS
local FOOT = K.FOOT
-- A drop siege's escort: any fighting unit, railgunners too (0.3.1), not a hauler.
local function SIEGE_FIT(u) return (u.type == "unit" or u.type == "spider-unit") and shared.kind_of(u.name) ~= "lp-hauler" end
local SOLDIER = K.SOLDIER
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
-- Where a drop siege's guards wait: its hold (launch_siege, out of every gun's reach), else its guard spot.
local function hold_spot(b, op)
  if op.hold then return {x = op.hold[1], y = op.hold[2]} end
  return guard_spot(b, op)
end
local HOLD_MARGIN = 6          -- tiles round a point that no gun may cover for its guards to wait there
local HOLD_READ = 150          -- tiles round its site whose guns a drop siege reads for its hold
-- A drop siege's guards: this many a piece (its mortars and its howitzer), its escort and its assault both (the user,
-- 2026-11-03: "almost as many cannons as guards?"; agreed: 6 a piece). Its assault goes in behind its strike, with
-- those there: called from its camp, 400 tiles off, reinforcements came minutes after the robots had mended what the
-- strike broke.
local GUARDS_PER_PIECE = 6
-- Its assault's reach past the breach, and when it falls back (the share of its launch left; Factorio RTS's retreat at
-- 40% lost, docs/reviews/2026-11-03-factorio-rts-assessment.md), and how long before an assault of choice again. Through
-- the breach to its target 60 tiles in, 12 of 18 died to the lasers inside (the artillery base, 0.2.168).
local ASSAULT_DEPTH = 30
local ASSAULT_PUSH, PUSHES = 60, 3   -- a cleared breach: on to what stands nearest within this, this many times
local FALL_BACK = 0.6
local ASSAULT_COOL = 3 * 3600
-- Whether a gun of `fire` (firemap.read) covers q or HOLD_MARGIN round it.
local function exposed(fire, q)
  if firemap.count(fire, q, 1) > 0 then return true end
  for k = 0, 7 do
    local a = k * math.pi / 4
    if firemap.count(fire, {x = q.x + math.cos(a) * HOLD_MARGIN, y = q.y + math.sin(a) * HOLD_MARGIN}, 1) > 0 then return true end
  end
  return false
end
local TURRETS = K.TURRETS
local TYPES = K.TYPES
-- The assault's way in (the user, 2026-11-04, the trailer's Kessler-Hayashi assault: "every laser starts attacking a wall
-- when there is very clearly a breach already made... plus the lasers barely tickle the wall"). Told to attack an area,
-- or distracted by anything, its units shot whatever was nearest, the wall pieces beside the breach; a stone wall resists
-- laser 70% (vanilla's, kept: beams are not for walls), so a line trooper's 7 a shot did 2 (fortress 12345: 449 hits on
-- pieces beside a gap, 82% of the assault's damage, against 91 on what stood behind). Now it goes through the way the
-- barrage opened, then at what stands behind by name, distracted only by what fights (walls are no military target).
-- The way: a search over tiles from `from` to `to` round the foes' wall and gate pieces (WAY_MARGIN beyond both, at most
-- WAY_SPAN across); its doorway is the first tile on it beside a piece (none when the way meets none). Nil when walled
-- off: then its attacks go at its targets and the units' own pathing breaks the piece in their way, which is the plan.
local WAY_MARGIN, WAY_SPAN = 20, 160
local function open_way(s, foes, from, to)
  local x0 = math.floor(math.min(from.x, to.x)) - WAY_MARGIN
  local y0 = math.floor(math.min(from.y, to.y)) - WAY_MARGIN
  local w = math.min(WAY_SPAN, math.floor(math.max(from.x, to.x)) + WAY_MARGIN - x0 + 1)
  local h = math.min(WAY_SPAN, math.floor(math.max(from.y, to.y)) + WAY_MARGIN - y0 + 1)
  local function idx(x, y)
    local i, j = math.floor(x) - x0, math.floor(y) - y0
    if i < 0 or j < 0 or i >= w or j >= h then return nil end
    return j * w + i
  end
  local wall = {}
  for _, e in pairs(s.find_entities_filtered{area = {{x0, y0}, {x0 + w, y0 + h}}, type = {"wall", "gate"}, force = foes}) do
    local k = idx(e.position.x, e.position.y)
    if k then wall[k] = true end
  end
  local a, z = idx(from.x, from.y), idx(to.x, to.y)
  if not (a and z) then return nil end
  if not next(wall) then return {} end
  local prev, queue, head = {[a] = -1}, {a}, 1
  while head <= #queue do
    local k = queue[head]
    head = head + 1
    if k == z then break end
    local i, j = k % w, math.floor(k / w)
    for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
      local ni, nj = i + d[1], j + d[2]
      if ni >= 0 and nj >= 0 and ni < w and nj < h then
        local nk = nj * w + ni
        if prev[nk] == nil and not wall[nk] then prev[nk] = k; queue[#queue + 1] = nk end
      end
    end
  end
  if prev[z] == nil then return nil end
  local path = {}
  local k = z
  while k ~= -1 do table.insert(path, 1, k); k = prev[k] end
  local function beside(k2)
    local i, j = k2 % w, math.floor(k2 / w)
    for di = -1, 1 do
      for dj = -1, 1 do
        local ni, nj = i + di, j + dj
        if ni >= 0 and nj >= 0 and ni < w and nj < h and wall[nj * w + ni] then return true end
      end
    end
    return false
  end
  for _, k2 in ipairs(path) do
    if beside(k2) then return {door = {x = x0 + k2 % w + 0.5, y = y0 + math.floor(k2 / w) + 0.5}} end
  end
  return {}
end
-- What its assault attacks, by name: the foes' buildings (TYPES: no walls) within r of c, roboports first when `ports`,
-- then turrets, then the rest, each nearest `from` first.
local function assault_targets(s, foes, c, r, from, ports)
  local list = s.find_entities_filtered{position = c, radius = r, type = TYPES, force = foes}
  local rank = {}
  for _, t in ipairs(TURRETS) do rank[t] = 1 end
  if ports then rank.roboport = 0 end
  local function key(e) return rank[e.type] or 2 end
  table.sort(list, function(p, q)
    local kp, kq = key(p), key(q)
    if kp ~= kq then return kp < kq end
    return (p.position.x - from.x) ^ 2 + (p.position.y - from.y) ^ 2 < (q.position.x - from.x) ^ 2 + (q.position.y - from.y) ^ 2
  end)
  return list
end
-- One upvalue for siege_step (at luajit's limit of 60). ORDERS: targets named in one order (the rest by its idle units'
-- orders, siege_step).
local assault_by = {way = open_way, targets = assault_targets, ORDERS = 8}
local assault = require("__landing-party__.scripts.assault")
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

-- A siege's escort by what is home (the user, 2026-11-26: "I can't believe KH can field 120 railgunners but not a bigger
-- siege than 12 units?"): at least its tier's, up to SIEGE_SHARE of what is home above its floor (railgunners too, since
-- 0.3.1), at most SIEGE_GUARDS_MAX. Its tier's alone (6, 10, 16) sent 12 of 200 at home on the user's nw game.
local SIEGE_SHARE, SIEGE_GUARDS_MAX = 0.5, 80
local function guards_for(b, army, tier_guards)
  local avail = field(b, army) + rails_home(b)
  return math.max(tier_guards, math.min(SIEGE_GUARDS_MAX, math.floor(avail * SIEGE_SHARE)))
end
ops.siege_guards_for = guards_for
-- A siege's way kept at least this share of its escort, or it is not sent (the user's nw game: "its way keeps 0.00, read
-- from orbit", 17 sent 460 tiles through big biters, none came back). Its best target past that is the corridor's to clear.
local KEEP_MIN = 0.3
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
local read_ways_now
-- Its ways read in slices (0.3.1, the user's nw save: "still too much of a spike"): read in one tick at a decision, the
-- fire and cost maps out to its farthest target took 128 to 146 ms, every 30 s while a siege was in reach. Now a job in
-- storage (b.ways_job) reads WAYS_FIRE rows of fire and WAYS_CELLS cells of cost a tick (siege.ways_tick, from
-- ops.tick); a decision reads the last finished map (b.ways), and starts the next once it is WAYS_AGE old. No map yet:
-- none (choose_siege holds its player sieges but a battery's). With storage.dump_ways (tests), read whole as before.
local WAYS_FIRE, WAYS_BLOCKS, WAYS_CELLS, WAYS_AGE = 64, 2, 24, 2 * 3600
firemap.price_of = function(corp, e)
  local p = know.price(corp, e.force.name, e.name)
  return p and p * shared.rank_scale(e) or nil
end
local function ways_start(b, h, targets)
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
  local fire = firemap.start(s, h.position, radius, shooters, ops.PER_TURRET, types)
  fire.corp = b.corp
  return {phase = "fire", fire = fire, surface = s, from = {h.position.x, h.position.y}, radius = radius, foes = foes,
    deaths = deaths, home = h.unit_number}
end
function ops.ways_tick(b)
  local w = b.ways_job
  if not w then return end
  if w.phase == "fire" then
    local m = firemap.step(w.fire, WAYS_FIRE)
    if not m then return end
    w.fmap, w.fire, w.phase = m, nil, "cost"
    w.cm = costmap.start(w.surface, {x = w.from[1], y = w.from[2]}, w.radius, w.foes, {fire = w.fmap,
      n = SIEGE_TIERS[#SIEGE_TIERS].guards, deaths = w.deaths, from = w.from,
      cell = w.radius > 1200 and costmap.CELL * 3 or costmap.CELL * 2, wall_forces = w.foes, sliced = true})
    return
  end
  local m = costmap.step(w.cm, {blocks = WAYS_BLOCKS, cells = WAYS_CELLS})
  if not m then return end
  b.ways, b.ways_job = {map = m, at = game.tick, home = w.home}, nil
end
local function read_ways(b, h, targets)
  if storage.dump_ways then return read_ways_now(b, h, targets) end
  local w = b.ways
  if w and w.home ~= h.unit_number then w = nil end
  if (not w or game.tick - w.at >= WAYS_AGE) and not b.ways_job then b.ways_job = ways_start(b, h, targets) end
  local cm = w and w.map
  siege_read = cm and {tick = game.tick, id = b.id, cm = cm} or siege_read
  return cm
end
read_ways_now = function(b, h, targets)
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
  local function price(e)
    local p = know.price(b.corp, e.force.name, e.name)
    return p and p * shared.rank_scale(e) or threat.prior(e, ops.PER_TURRET)
  end
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
    -- (Not in the battery pass but for a battery: the pass after it weighs them all again, the same tick, and with 321
    -- targets from orbital sight the two cost 520 ms every 30 s, the user's nw game: "huge stutters".)
    if orbital and t.pos and against_player(t.owner) and (not only_battery or battery(t)) then
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
        -- (No map read yet, its ways read in slices: no siege on a player but at a battery, for now.)
        if p and orbital and not cm and against_player(t.owner) and not battery(t) then p = nil end
        if p and cm and against_player(t.owner) then
          local lost = costmap.cost(cm, {x = p[1], y = p[2]})
          local keeps = lost and valuemap.keeps_one_way(guards_for(b, army, SIEGE_TIERS[#SIEGE_TIERS].guards), lost) or 0
          t.way_keeps = keeps
          -- (The best it would take with its way free, for its corridor below.)
          if lost and keeps < 1 and (not blocked_s or s > blocked_s) then blocked, blocked_s, blocked_site = t, s, p end
          -- Synthexis's floor (valuemap.REACH_FLOOR): a dear way makes a target worth less, not nothing. Without it every
          -- target past a few nests read 0.00 (a siege's guards are 10 to 24, its waves hundreds) and on nw it sent no
          -- siege in 90 minutes, three seeds (0.2.156); no way at all is still none.
          -- (Not below KEEP_MIN, 0.3.1: the floor let a way keeping none weigh at REACH_FLOOR, and it marched.)
          s = (lost and keeps >= KEEP_MIN) and s * (valuemap.REACH_FLOOR + keeps) or 0
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
  -- (No railgunners on a siege of a player's, 0.2.157 to 0.2.165: at its site they shot at the wall from beyond its guns'
  -- reach, their damage to its buildings cut, and once hit charged into the lasers and died; the user, 2026-11-03,
  -- watching one: "Not sure railgunners should come with the sieges". Its corridor strikes clear the nests on its way.)
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
ops.siege_garrison = function(b)
  local top = top_tier(b)
  local guards = (shared.CORPS[b.corp] or {}).orbital_drop and math.max(top.guards, 6 * (top.mortars + 1)) or top.guards
  return math.ceil(guards / (1 - pool.RESERVE))
end

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
  -- Its escort's size: its tier's, or a drop siege's GUARDS_PER_PIECE for each piece it brings.
  local want_g = drop and math.max(spec.guards, GUARDS_PER_PIECE * ((piece == "lp-howitzer" and 1 or spec.mortars)
    + (with_howitzer and 1 or 0))) or spec.guards
  -- (And by what is home, guards_for; not a clearance, whose railgunners are its tier's.)
  if not clearance then want_g = guards_for(b, army, want_g) end
  -- Counter-battery (Serenity): against the player's artillery, its Shock troopers go first (up to six).
  local floor = floor_of(b, army, battery(t))
  if battery(t) and rd.has(b.corp, "counter") then
    guards = pool.take(b, 6, floor, function(u) return shared.kind_of(u.name) == "lp-shock" end)
  end
  -- A clearance (nests): its railgunners go first, the biter-clearing unit.
  if clearance or t.owner == "enemy" then
    for _, u in ipairs(pool.take(b, want_g - #guards, floor, function(u) return shared.kind_of(u.name) == "lp-railgunner" end)) do
      table.insert(guards, u)
    end
  end
  -- A clearance takes railgunners only: Line troopers next to them died to the nest's big biters and killed next to
  -- none (nine of them killed one of sixteen, scenario rail).
  if not (clearance or t.owner == "enemy") then
    -- A drop siege's escort in its mix's shares (army.mix), walkers too (no truck to keep up with): taken newest first,
    -- it was what its counter tilt had lately built, against lasers its tanks, and a siege went with 9 tanks of 16
    -- (the user, 2026-11-03: "unit compo was strange with many tanks"). What a kind lacks, the rest make up.
    -- (Railgunners among them since 0.3.1, the user: a siege is where their reach belongs; kept home before, 108 of a
    -- garrison of 200 never left it, nw.)
    if drop then
      local m, sum = army.mix(b), 0
      for _, w in pairs(m) do sum = sum + w end
      local kinds = {}
      for name in pairs(m) do kinds[#kinds + 1] = name end
      table.sort(kinds)
      for _, name in ipairs(kinds) do
        local want = math.floor(want_g * m[name] / math.max(1, sum) + 0.5)
        for _, u in ipairs(pool.take(b, math.min(want, want_g - #guards), floor,
          function(u) return (u.type == "unit" or u.type == "spider-unit") and shared.kind_of(u.name) == name end)) do
          table.insert(guards, u)
        end
      end
    end
    for _, u in ipairs(pool.take(b, want_g - #guards, floor, drop and SIEGE_FIT or FOOT)) do
      table.insert(guards, u)
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
  b.op = {kind = "siege", target = key, target_kind = t and t.kind, phase = "march", members = guards, launched = #guards, hauler = hauler, drop = drop or nil,
    site = site, started = game.tick, phase_at = game.tick, shells_fired = 0, tier = tier,
    convoys_left = spec.convoys or 0,
    -- Whose (oplog reads it once its target is gone from intel: razed before the siege ended, its entry named no owner,
    -- and standsiege nests counted none of its 17 guards back, 0.2.268).
    owner = t and t.owner or nil}
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
  -- (A drop siege's guards round the guns too: a truck went through their reach and on; its guards on foot died there,
  -- 11 of 16 in fortress once its escort was its mix and not its tanks.)
  hroute = hroute or sneak_route(b, {start.x, start.y}, site,
    clearance and {turrets = false, worms = true} or {turrets = drop, nests = (b.intel.targets[key] or {}).owner ~= "enemy"})
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
    b.next_op, b.next_op_why = game.tick + 2 * 3600, "hold"
    return false
  end
  -- A drop siege's guards wait where no gun reaches, as a wave stages (costmap.staging: the last cell of its way before the
  -- first a gun covers; the user, 2026-11-03: "We already had some code to make sure synthexis waves stay far enough
  -- while pathing to their staging grounds"). Its way cut there, and its hold its last point; its guard spot where no gun
  -- covers it or its way. Its site is out of the guns' reach, its way there was not: on the artillery base its guards
  -- walked its last stretch through the lasers' edge, 9 to 27 killed a run, and charged the wall from there.
  if drop and not clearance then
    -- Its foes' guns round its site alone (not its way's worms and biters, which its corridor strikes clear: read with
    -- them, a worm by its own camp cut its way at its start, its hold 537 tiles from its site, the artillery base).
    local fire = firemap.read(s, {site[1], site[2]}, HOLD_READ, enemies(game.forces[b.force]), function() return 1 end,
      {"ammo-turret", "electric-turret", "fluid-turret"})
    -- (Kept for its moving up: its next hold read on the same guns.)
    b.op.fire = fire
    -- Its last stretch under their fire, read back from its site: cut there.
    local cut
    for i = #hroute, 1, -1 do
      if exposed(fire, {x = hroute[i][1], y = hroute[i][2]}) then cut = i else break end
    end
    if cut then
      local keep = {}
      for i = 1, cut - 1 do keep[i] = hroute[i] end
      hroute = keep
    end
    if cut or exposed(fire, guard_spot(b, b.op)) then
      local last = hroute[#hroute]
      b.op.hold = last and {last[1], last[2]} or {start.x, start.y}
      trace(b, string.format("siege: its guards hold at %.0f,%.0f, out of every gun's reach (%.0f from its site)",
        b.op.hold[1], b.op.hold[2], math.sqrt((b.op.hold[1] - site[1]) ^ 2 + (b.op.hold[2] - site[2]) ^ 2)))
    end
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
        distraction = defines.distraction.by_damage}
    end
    -- (Then behind its site, guard_spot: its start point there since 0.2.149, a guard left behind its hauler walked home.)
    -- (A drop siege's answer only what hits them, the march's look keeping none of them near its site: on sight, they
    -- walked on from its site into the lasers' reach and all 10 died before its pods came, standsiege, 0.2.165.)
    gcmds[#gcmds + 1] = {type = defines.command.go_to_location, destination = drop and hold_spot(b, b.op) or guard_spot(b, b.op), radius = 6,
      distraction = drop and defines.distraction.none or clearance and defines.distraction.by_damage
        or defines.distraction.by_enemy}
    -- (And a lasting order at its end: its orders done, the engine set it wandering, its eye on what it saw, and its guards
    -- walked from their hold into the wall's lasers, fortress; a clearance's guard duty knew this, "idle, a unit attacks
    -- whatever it sees".)
    if drop then gcmds[#gcmds + 1] = {type = defines.command.stop, distraction = defines.distraction.none} end
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
  -- Short of parts: it saves for them (base.reserve holds all but its economy and its railgunners; the
  -- hazard at 0.2.324: rebuilding walls and gates as the waves broke them, a camp waited "parts 2 of 220" for an hour).
  if (b.parts or 0) < SIEGE_TIERS[2].cost then
    b.hazard_save = {need = SIEGE_TIERS[2].cost, till = game.tick + 45 * 3600}   -- (past the next retry: its losses' window refills
    -- in 12 to 20 minutes, and a 10-minute saving had lapsed before every one, 0.2.326)
    return false, string.format("parts %d of %d", b.parts or 0, SIEGE_TIERS[2].cost)
  end
  b.hazard_save = nil
  -- Railgunners to hold the site: the nest's defenders came out at the first shells and broke the mortars of eight Line
  -- troopers in 35 s (visit b - rocket). Until it has ops.clear_rails at home, it asks for them (army.produce) and waits.
  local rails = 0
  for _, u in ipairs(b.garrison) do if u.valid and shared.kind_of(u.name) == "lp-railgunner" then rails = rails + 1 end end
  local need = ops.clear_rails(s, piece)   -- (more as the biters evolve, and with a howitzer)
  b.want_rails = rails < need * 2
  b.rails_short = rails < need and need or nil   -- what it waits for (army.produce makes them over the cap)
  if rails < need then
    if not b.rails_traced then
      b.rails_traced = true
      trace(b, string.format("clearance: waits for railgunners (%d of %d)", rails, need))
    end
    return false, string.format("railgunners %d of %d", rails, need)
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
local DROP_GUARD = 20          -- its guards answer its foes' units this near its hold, and come back to it
-- A line (the user, 2026-11-03: "line up at the site spaced by splash"; Factorio RTS's slotting on arrival, docs/reviews/
-- 2026-11-03-factorio-rts-assessment.md): its members in staggered ranks facing `toward`, about sqrt(2n) a rank, spaced
-- by half the widest artillery blast of its foes (threat.foe_splash, within LINE_MIN and LINE_MAX: one shell does not
-- take the escort); each to a slot matched by its place across the line (their paths do not cross), undistracted,
-- then a stop. A clump at its hold had stood where one shell's splash covered it.
local LINE_MIN, LINE_MAX = 1.5, 3
local LINE_AGAIN = 30 * 60      -- ticks between a guard duty's re-forming of its line
local RANK_STAGGER = 60         -- ticks between one rank of its assault and the next
local function form_line(members, center, toward)
  local live = {}
  for _, u in ipairs(members) do if u.valid then live[#live + 1] = u end end
  if #live == 0 then return end
  local a = math.atan2(toward.y - center.y, toward.x - center.x)
  local fx, fy = math.cos(a), math.sin(a)               -- toward the target
  local sx, sy = -fy, fx                                -- across the line
  local gap = math.max(LINE_MIN, math.min(LINE_MAX, threat.foe_splash() / 2))
  local w = math.max(1, math.ceil(math.sqrt(2 * #live)))
  local slots = {}
  for i = 0, #live - 1 do
    local r, c = math.floor(i / w), i % w
    local across = (c - (math.min(w, #live - r * w) - 1) / 2 + (r % 2) * 0.5) * gap
    slots[#slots + 1] = {x = center.x + sx * across - fx * r * gap, y = center.y + sy * across - fy * r * gap, across = across, r = r}
  end
  table.sort(slots, function(p, q) if p.r ~= q.r then return p.r < q.r end return p.across < q.across end)
  table.sort(live, function(p, q)
    local dp = (p.position.x - center.x) * fx + (p.position.y - center.y) * fy
    local dq = (q.position.x - center.x) * fx + (q.position.y - center.y) * fy
    if math.abs(dp - dq) > gap then return dp > dq end
    return (p.position.x - center.x) * sx + (p.position.y - center.y) * sy < (q.position.x - center.x) * sx + (q.position.y - center.y) * sy
  end)
  for i, u in ipairs(live) do
    u.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
      commands = {{type = defines.command.go_to_location, destination = {x = slots[i].x, y = slots[i].y}, radius = 0.8,
        distraction = defines.distraction.none}, {type = defines.command.stop, distraction = defines.distraction.none}}}
  end
end

-- A siege's assault at a closed wall, its barrage over and no strike falling (assault.lua): whether it goes in now (true)
-- or its guns are on the wall first (false: it waits a step). Its way read from its guards' middle to where it goes in
-- (open_way); open, it goes. Closed, its menu once (assault.weigh: walled, or wallfire where its shells beat the
-- robots, assault.race); with wallfire, every gun in reach flared on the wall piece on its line in (assault.wall_on_way),
-- piece after piece, until the way is open, its shells are spent, or a piece stands as whole as it was once the race's own
-- time and a look more have passed (its robots keep it: the race lost after all).
assault_by.closed = function(b, op, s, foes, mortars, left, t, want, trace)
  if not (t and t.pos) or (op.way_method and op.way_method ~= "wallfire") then return true end
  local c = op.drop and op.strike_center
  local at = c and {x = c[1], y = c[2]} or {x = t.pos[1], y = t.pos[2]}
  local cx, cy, cn = 0, 0, 0
  for _, u in ipairs(op.members) do if u.valid then cx, cy, cn = cx + u.position.x, cy + u.position.y, cn + 1 end end
  local from = cn > 0 and {x = cx / cn, y = cy / cn} or (op.site and {x = op.site[1], y = op.site[2]})
  if not from then return true end
  op.way_from = {from.x, from.y}
  if open_way(s, foes, from, at) then
    if op.wall_fire then trace(b, "siege: its guns opened the wall; its assault goes in"); op.wall_fire = nil end
    return true
  end
  local guns = {}
  for _, m in ipairs(mortars) do guns[#guns + 1] = m end
  if op.howitzer and op.howitzer.valid then guns[#guns + 1] = op.howitzer end
  local piece = assault.wall_on_way(s, foes, from, at)
  local function race_line(r)
    return r and string.format("its guns break the piece at %.0f,%.0f in %.0f s with %d of %d shells, its robots %s",
      piece.position.x, piece.position.y, r.ticks / 60, r.shells, left, r.mend and string.format("there in %.0f s", r.mend / 60)
      or "none") or (piece and "none of its guns reaches the wall" or "no piece on its line")
  end
  if not op.way_method then
    local r = piece and assault.race(s, foes, guns, piece)
    local m, why = assault.weigh(b, t, assault.wins(r, left), want,
      s.count_entities_filtered{position = at, radius = 16, type = TYPES, force = foes})
    op.way_method = m
    trace(b, string.format("siege: walled off, no strike; weighs %s (%s): %s", why, race_line(r), m))
    if m ~= "wallfire" then return true end
  end
  if left <= 0 or not piece then
    trace(b, "siege: its shells spent on the wall; its assault breaks the rest")
    op.wall_fire = nil
    return true
  end
  if piece ~= op.wall_piece then
    local r = assault.race(s, foes, guns, piece)
    if not assault.wins(r, left) then
      trace(b, string.format("siege: its guns lose the race at the wall (%s); its assault goes in", race_line(r)))
      op.wall_fire = nil
      return true
    end
    op.wall_piece, op.wall_hp, op.wall_since, op.wall_due = piece, piece.health, game.tick, r.ticks
    op.wall_pieces = (op.wall_pieces or 0) + 1
    trace(b, string.format("siege: its guns on the wall (%s)", race_line(r)))
  elseif game.tick - op.wall_since > op.wall_due + 300 and piece.health >= op.wall_hp then
    trace(b, string.format("siege: the piece at %.0f,%.0f stands whole under its shells (its robots keep it); its assault goes in",
      piece.position.x, piece.position.y))
    op.wall_fire = nil
    return true
  end
  op.wall_fire, op.last_target = true, game.tick
  for _ = 1, #guns do
    s.create_entity{name = "artillery-flare", position = piece.position, force = b.force, movement = {0, 0},
      height = 0, vertical_speed = 0, frame_speed = 0}
  end
  op.flares = (op.flares or 0) + #guns
  return false
end

local function rest_of_way(route, from, to)
  local cmds, first, fd = {}, nil, nil
  for i, w in ipairs(route or {}) do
    local d = (w[1] - from.x) ^ 2 + (w[2] - from.y) ^ 2
    if not fd or d < fd then first, fd = i, d end
  end
  for i = first or 1, first and #route or 0 do
    -- (Its way is cut where the guns' fire begins: on it they answer what hits them. Undistracted, they let biters kill
    -- 10 of 16 on the march, the artillery base, seed 1.)
    cmds[#cmds + 1] = {type = defines.command.go_to_location, destination = route[i], radius = 6,
      distraction = defines.distraction.by_damage}
  end
  cmds[#cmds + 1] = {type = defines.command.go_to_location, destination = to, radius = 6,
    distraction = defines.distraction.none}
  cmds[#cmds + 1] = {type = defines.command.stop, distraction = defines.distraction.none}
  return cmds, first or 0
end
local RESEND_MAX = 3
-- An order that leaves it where it stands: wandering (the engine's, its orders done), or a stop alone or last.
local function idle_order(c)
  if not c then return true end
  if c.type == defines.command.wander or c.type == defines.command.stop then return true end
  return c.type == defines.command.compound and #c.commands == 1 and c.commands[1].type == defines.command.stop
end
local function drop_march(b, op, trace, army, n)
  local hp, d2
  local spot = hold_spot(b, op)
  for _, u in ipairs(op.members) do
    if u.valid then
      local d = (u.position.x - spot.x) ^ 2 + (u.position.y - spot.y) ^ 2
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
  if storage.drop_debug then
    local ps = {}
    for _, u in ipairs(op.members) do
      if u.valid then
        local c = u.commandable.command
        ps[#ps + 1] = string.format("%s@%.0f,%.0f:%s", u.name:sub(4, 8), u.position.x, u.position.y,
          c and (c.type == defines.command.compound and ("c" .. #c.commands) or tostring(c.type)) or "-")
      end
    end
    trace(b, string.format("DROPDBG spot %.0f,%.0f route %d: %s", spot.x, spot.y, #(op.route or {}), table.concat(ps, " ")))
  end
  local held = 0
  for _, u in ipairs(op.members) do
    if u.valid then
      local du = (u.position.x - spot.x) ^ 2 + (u.position.y - spot.y) ^ 2
      if du <= DROP_HOLD ^ 2 then
        held = held + 1
      elseif (op.resent or {})[u.unit_number] ~= RESEND_MAX and (not u.commandable.has_command
        or idle_order(u.commandable.command)) then
        -- (Its way given up, short of its hold: the engine drops a go-to it cannot path and runs the rest, its stop, and
        -- five tanks stood at their start for good, fortress. Sent again, at most RESEND_MAX times.)
        op.resent = op.resent or {}
        op.resent[u.unit_number] = (op.resent[u.unit_number] or 0) + 1
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
  -- Its lead at its hold and no nearer for a minute (the rest held up behind): it drops with those there (called off
  -- 3 and 6 tiles short, the artillery base, seed 1).
  if game.tick - (op.best_at or op.started) > STUCK_TICKS and d2 <= DROP_HOLD ^ 2 and held > 0 then return hp, 0 end
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

-- Guard duty round a siege's hold or a clearance's site (siege_step): its foes' units within the ring are answered, the
-- guards leashed back to it. Run in a drop siege's and a clearance's bombard, and in their deploy too (the user, 2026-11-09, on the trailer:
-- "a buggy starts firing on the waiting infantry which is frozen and does not respond while the mortars land": held at
-- its hold, undistracted, they let a buggy shoot them).
local function guard_duty(b, op)
  local s = game.surfaces[b.surface]
  -- (Round its jump-off once its guards moved up behind its strike: leashed to its hold, they were pulled back.)
  local c = op.drop and not op.clearance and (op.jump and {x = op.jump[1], y = op.jump[2]} or hold_spot(b, op))
    or {x = op.site[1], y = op.site[2]}
  -- Tighter at a howitzer's site: 24 out from it, guards stood in behemoth worms' reach (82 of 111 lost to acid).
  local guard_r = op.drop and not op.clearance and DROP_GUARD or CLEAR_GUARD
  -- A leash: a guard more than LEASH beyond its ring walks back to the site, undistracted. Told to hold the ring,
  -- guards still followed what they fought out of it, and behemoth worms killed eight of ten 15 to 36 tiles from the
  -- site (scenario clear, worms, 2026-10-25).
  for _, u in ipairs(op.members) do
    if u.valid and (u.position.x - c.x) ^ 2 + (u.position.y - c.y) ^ 2 > (guard_r + LEASH) ^ 2 then
      u.commandable.set_command{type = defines.command.go_to_location, destination = c,
        radius = 6, distraction = defines.distraction.none}
    end
  end
  local foes = op.clearance and s.find_entities_filtered{position = op.site, radius = guard_r, type = "unit", force = shared.NEST_FORCES}
    or s.find_entities_filtered{position = c, radius = guard_r, type = {"unit", "character", "car", "spider-vehicle"},
      force = enemies(game.forces[b.force])}
  -- The biters' and Synthexis's units in its ring are foes too (enemies() leaves them out): a drop siege's guards hold
  -- with no distraction, and twelve medium biters killed every one of a siege's 11 units and both its mortars, unfought
  -- (the user's nw game, 2026-11-26; siegetier biters).
  if not op.clearance then
    local wild = s.find_entities_filtered{position = c, radius = guard_r, type = {"unit", "spider-unit"}, force = shared.NEST_FORCES}
    local own = game.forces[b.force]
    for _, u in ipairs(wild) do if not own.get_cease_fire(u.force) then foes[#foes + 1] = u end end
  end
  -- (Back in line when the ground is quiet, every LINE_AGAIN at most: guard duty brought them back to its centre, and
  -- the line its hold had formed was a clump again, standsiege nests.)
  if #foes == 0 and op.drop and not op.clearance and game.tick - (op.lined_at or 0) >= LINE_AGAIN then
    op.lined_at = game.tick
    local tg = b.intel.targets[op.target]
    form_line(op.members, c, tg and tg.pos and {x = tg.pos[1], y = tg.pos[2]} or {x = op.site[1], y = op.site[2]})
  end
  if #foes > 0 and not op.clearance then
    order_all(op.members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
      commands = {{type = defines.command.attack_area, destination = c, radius = guard_r,
        distraction = defines.distraction.none},
        {type = defines.command.go_to_location, destination = c, radius = 6, distraction = defines.distraction.none},
        {type = defines.command.stop, distraction = defines.distraction.none}}})
  elseif #foes > 0 then
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

-- The site dug in: a ring of wall open towards home and gun pillboxes facing the target, cleared when the siege ends
-- (op.works). Hardened sieges (Serenity) once their guns are up; a clearance the moment it arrives (the user, 2026-11-11,
-- "dig in first": hazard worm's railgunners died to medium and big biters while deploying, 10 of 15 in 45 s, before the
-- ring went up with the guns). By the biters' evolution (what it brings, not hidden strength): 2 pillboxes at none, 4 at
-- full, uranium rounds from 0.6 at 5 parts a pillbox (piercing when it cannot pay).
function ops.dig_in(b, op, trace)
  local s, force = game.surfaces[b.surface], game.forces[b.force]
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
  local evo = game.forces.enemy and game.forces.enemy.get_evolution_factor(s) or 0
  local boxes = 2 + math.floor(2 * evo + 0.5)
  local t = b.intel.targets[op.target]
  local toward = t and t.pos and math.atan2(t.pos[2] - op.site[2], t.pos[1] - op.site[1]) or away + math.pi
  for k = 1, boxes do
    local a = toward + (k - (boxes + 1) / 2) * 0.7          -- an arc facing the target
    local p = s.find_non_colliding_position("lp-gun-turret", {op.site[1] + math.cos(a) * 4, op.site[2] + math.sin(a) * 4}, 4, 0.5)
    local g = p and s.create_entity{name = "lp-gun-turret", position = p, force = force}
    if g then
      if evo >= 0.6 and (b.parts or 0) >= 5 then
        b.parts = b.parts - 5
        b.uranium_refills = (b.uranium_refills or 0) + 1
        g.insert{name = "uranium-rounds-magazine", count = 50}
      else
        g.insert{name = "piercing-rounds-magazine", count = 50}
      end
      table.insert(op.works, g)
    end
  end
  -- From 0.4, a flamer in the middle of the site (the user, 2026-11-11: Kessler-Hayashi's arc flamer, its whole circle and
  -- its own side spared, an anti-swarm guard ringed by its own units; Grubstake's variant is its oil flamer, fed here).
  if evo >= 0.4 then
    local name = shared.variant(b.corp, "lp-flamer")
    local p = s.find_non_colliding_position(name, {op.site[1] + math.cos(toward) * 2.5, op.site[2] + math.sin(toward) * 2.5}, 4, 0.5)
    local f = p and s.create_entity{name = name, position = p, force = force}
    if f then
      table.insert(op.works, f)
      op.site_flamer = f
      b.site_flamers = (b.site_flamers or 0) + 1
    end
  end
  op.dug_in = game.tick
  -- (Before its guns: what hazard checks.)
  if not (op.mortars and #op.mortars > 0) and not (op.howitzer and op.howitzer.valid) then b.dug_early = (b.dug_early or 0) + 1 end
  trace(b, string.format("siege: the site dug in (%d pieces, %d pillboxes%s)", #op.works, boxes, op.site_flamer and ", a flamer" or ""))
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
      -- (Dig in first, as a hauled clearance does: a drop's railgunners died while its pods came down, worm.)
      if op.clearance and not op.works then ops.dig_in(b, op, trace) end
      local s = game.surfaces[b.surface]
      local spec = SIEGE_TIERS[op.tier or 1]
      local guns = op.piece == "lp-howitzer" and 1 or (op.carry and #op.carry or spec.mortars)
      op.drops = {}
      for k = 1, guns do op.drops[#op.drops + 1] = pods.send(s, gun_spot(b, op, spec, k), b.force) end
      if op.with_howitzer and not op.howitzer then
        -- (Its pod where it will stand, apart from the mortars out of every gun's reach, as its deploy puts it: it is
        -- assembled there.)
        local hn = shared.variant(b.corp, "lp-howitzer")
        local tg = op.target and b.intel.targets[op.target]
        op.hw_at = {op.site[1], op.site[2] + 6}
        if tg and tg.pos then
          local fire = math.atan2(tg.pos[2] - op.site[2], tg.pos[1] - op.site[1])
          local apart = howitzer_apart(hn, shared.variant(b.corp, op.piece or "lp-mortar"))
          for _, side in ipairs({1, -1}) do
            local q = {op.site[1] + math.cos(fire + side * math.pi / 2) * apart, op.site[2] + math.sin(fire + side * math.pi / 2) * apart}
            if out_of_reach(s, q, enemies(game.forces[b.force])) then op.hw_at = q; break end
          end
        end
        op.drops[#op.drops + 1] = pods.send(s, op.hw_at, b.force)
      end
      -- (Still, at its hold: wandering, answering what hit them, they followed a laser's hit into the wall; guard duty
      -- below sends them at what comes for the guns.)
      -- In line at its hold, facing its target (form_line).
      local tg = b.intel.targets[op.target]
      form_line(op.members, hold_spot(b, op), tg and tg.pos and {x = tg.pos[1], y = tg.pos[2]} or {x = op.site[1], y = op.site[2]})
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
      if op.clearance and not op.works then ops.dig_in(b, op, trace) end   -- (dig in first: before its guns go up)
    end
  elseif op.phase == "deploy" then
    -- (A clearance's too: its guards stood while biters killed its railgunners 8 to 11 tiles from the site and its mortars
    -- as they went up, the last nest never cleared, hazard, once the Line trooper hit as hard as before, 0.2.271.)
    if op.drop or op.clearance then guard_duty(b, op) end
    local share = (game.tick - op.phase_at) / DEPLOY_TICKS
    if op.label and op.label.valid then op.label.text = {"lp.siege-deploying-percent", string.format("%d", math.min(100, share * 100))} end
    -- A drop siege's guns assembled where their pods came down (the user, 2026-11-04: between the drops and the guns "a
    -- big length of time ... where nothing is there. Looks weird"): each gun put up as its pod lands, off till the end of
    -- the deploy, sparks flying while it is assembled.
    if op.drop and op.drops and share < 1 then
      local s = game.surfaces[b.surface]
      local spec = SIEGE_TIERS[op.tier or 1]
      op.kits = op.kits or {}
      for k, n in ipairs(op.drops) do
        local is_hw = op.with_howitzer and k == #op.drops and not op.howitzer and op.hw_at
        if not op.kits[k] and pods.down(s, n) then
          local name = is_hw and shared.variant(b.corp, "lp-howitzer") or shared.variant(b.corp, op.piece or "lp-mortar")
          local at = is_hw and op.hw_at or gun_spot(b, op, spec, k)
          local p = s.find_non_colliding_position(name, at, 8, 0.5)
          local m = p and s.create_entity{name = name, position = p, force = b.force}
          if m then
            m.disabled_by_script = true; op.kits[k] = m
            -- (Its camp's from the moment it stands: what it is credited with, and its loss counted, as its guns'.)
            storage.unit_owner = storage.unit_owner or {}
            if m.unit_number then storage.unit_owner[m.unit_number] = b.id end
          end
        end
        local m = op.kits[k]
        if m and m.valid then
          -- (Where on it: from the tick, not the dice, rng.lua's rule for what changes the game; sparks change nothing.)
          for j = 1, 2 do
            local h = (game.tick * 7 + k * 13 + j * 29) % 17
            s.create_entity{name = "spark-explosion", position = {m.position.x + (h % 5) * 0.4 - 0.8,
              m.position.y + math.floor(h / 5) * 0.5 - 0.8}}
          end
        end
      end
    end
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
        -- (Its gun assembled where its pod came down, switched on: the deploy above.)
        local kit = op.kits and op.kits[k]
        local m
        if kit and kit.valid and kit.name == name then
          kit.disabled_by_script = false
          m, op.kits[k] = kit, nil
        elseif kit and not kit.valid then
          m = nil   -- (destroyed while it was assembled: that gun is lost, not put up fresh)
        else
          local p = here and s.find_non_colliding_position(name, here.pos, 8, 0.5)
            or s.find_non_colliding_position(name, {op.site[1] + math.cos(a) * off, op.site[2] + math.sin(a) * off}, 8, 0.5)
          m = p and s.create_entity{name = name, position = p, force = force, direction = here and here.dir or nil}
        end
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
        local kit = op.kits and op.kits[#(op.drops or {})]
        if kit and kit.valid and kit.name == hn then
          kit.disabled_by_script = false
          op.howitzer, op.kits[#op.drops] = kit, nil
        elseif kit and not kit.valid then
          op.howitzer = nil   -- (destroyed while assembled: none this siege)
        else
          local p = s.find_non_colliding_position(hn, at, 12, 1)
          op.howitzer = p and s.create_entity{name = hn, position = p, force = force, direction = truck and truck.dir or nil}
        end
        if op.howitzer then
          -- (Its settlement's, as its mortars: what it breaks is its razing.)
          storage.unit_owner = storage.unit_owner or {}
          if op.howitzer.unit_number then storage.unit_owner[op.howitzer.unit_number] = b.id end
          if truck then op.howitzer.health = math.max(1, truck.share * op.howitzer.max_health) end
          op.howitzer.insert{name = "lp-mortar-shell", count = op.howitzer_carry or spec.shells}
          op.howitzer_carry = nil
          trace(b, "siege: a howitzer for the roboports")
        end
        -- (A drop siege's always: the wall it brings a howitzer for is kept by robots, and they mended all it broke.)
        if (rd.has(b.corp, "jammer") or op.drop) and not op.jammer then
          op.jammer = jammer.raise(s, {op.site[1], op.site[2]}, force)
          if op.jammer then trace(b, "siege: a jamming mast for their robots") end
        end
      end
      if op.label and op.label.valid then op.label.destroy() end
      op.phase, op.phase_at = "bombard", game.tick
      alert(b, b.intel.targets[op.target], "lp.alert-siege", op.site)
      -- (Its horn where it sets up, the Sound Sheet's round five.)
      shared.cue(s, "siege-horn", {op.site[1], op.site[2]})
      trace(b, string.format("siege: %d mortars up with %d shells", #op.mortars, op.loaded - op.shells_fired))
      -- An armed camp's siege calls its orbital strike on the wall (scripts/orbital.lua).
      if not op.clearance then orbital.call(b, op) end
      if op.standing and ops.site_dome then ops.site_dome(b, op) end
      -- Hardened siege (Serenity): the site digs in, a ring of wall open towards home and two gun pillboxes, cleared
      -- when the siege ends (op.works).
      if (rd.has(b.corp, "hardened") or op.clearance) and not op.works then ops.dig_in(b, op, trace) end
    end
  elseif op.phase == "bombard" or op.phase == "assault" then
    -- Guard duty (a clearance): biters that come for the mortars are shot, and the guards go back to the site. Told to
    -- engage on sight they charged the spawner 32 tiles off and died; told to answer only what hit them, they let the
    -- biters break the mortars (scenario clear, visit b - rocket).
    -- (siege_step runs every 300 ticks.)
    -- A drop siege's too, round its hold (the clearance's rule; the user, 2026-11-03, on its guards: dying to the wall's
    -- lasers while its mortars set up), at what comes for it: its foes' units, biters or the player's.
    -- (Not in its assault: its leash called its assault back to its hold every look, and it razed nothing, siegetier 3.)
    if op.clearance or (op.drop and op.phase == "bombard") then guard_duty(b, op) end
    local live = {}
    for _, m in ipairs(op.mortars or {op.mortar}) do if m.valid then table.insert(live, m) end end
    op.mortars, op.mortar = live, live[1]
    if not op.mortar and op.phase == "bombard" then
      trace(b, "siege: the mortars were destroyed")
      -- (A standing siege's guns all destroyed before it packed up: Siege broken.)
      if op.standing then achievements.siege_broken(game.forces[b.force]) end
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
      -- A drop siege moves up again and again too, as its breaches open (at most 8): after its assault fell back from
      -- the breach it packed up, the inner lasers standing (standsiege nests, 0.2.169).
      if op.pack_site or (spec.mortars > 1 and (op.clearance or (op.drop and (op.steps or 0) < 8) or not op.moved) and left > 0
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
          if op.drop then op.steps = (op.steps or 0) + 1 end
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
            -- Its next hold: its guard spot there, or the first point no gun covers on the line back to its last hold
            -- (kept at its first, its guards walked to the next and were called off as no nearer it, standsiege nests).
            local was = op.hold and {x = op.hold[1], y = op.hold[2]} or (from and {x = from.x, y = from.y})
            op.hold = nil
            local g = guard_spot(b, op)
            if op.fire and was and exposed(op.fire, g) then
              for k = 1, 10 do
                local q = {x = g.x + (was.x - g.x) * k / 10, y = g.y + (was.y - g.y) * k / 10}
                if not exposed(op.fire, q) or k == 10 then op.hold = {q.x, q.y}; break end
              end
            end
            op.route = from and op.clearance and sneak_route(b, {from.x, from.y}, site, {turrets = false, worms = true}) or {}
            op.best_idx = nil
            local cmds = rest_of_way(op.route, from or {x = site[1], y = site[2]}, hold_spot(b, op))
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
      -- A drop siege's guards behind its strike (a walking barrage; the user, 2026-11-03: "guards did not take advantage
      -- of the ongoing shelling, especially the orbital strike which completely razed large parts of the wall"). On its
      -- paint, to a jump-off: the first point no gun reaches on the line from the strike's centre back to its hold. On
      -- its fall, in, at the breach first: its shells fall from the centre outward and hit its enemies only. (Sent after
      -- its last shell from its hold, 20 to 40 tiles back, they came after the barrage and lost half.)
      if op.drop and op.strike_paint and not op.jumped and op.strike_center then
        op.jumped = true
        local h = hold_spot(b, op)
        local c = {x = op.strike_center[1], y = op.strike_center[2]}
        local jump = h
        if op.fire then
          for k = 1, 20 do
            local q = {x = c.x + (h.x - c.x) * k / 20, y = c.y + (h.y - c.y) * k / 20}
            if not exposed(op.fire, q) then jump = q; break end
          end
        end
        op.jump = {jump.x, jump.y}
        form_line(op.members, jump, c)
        trace(b, string.format("siege: its guards move up to %.0f,%.0f behind its strike (%.0f from the breach)",
          jump.x, jump.y, math.sqrt((jump.x - c.x) ^ 2 + (jump.y - c.y) ^ 2)))
      end
      local on_strike = op.drop and op.strike_falling and true or false
      if over and op.drop and game.tick < (op.assault_cool or 0) then over = nil end
      over = over or on_strike
      -- (Its guns on the wall: the barrage's end held while they are, assault_by.closed.)
      if op.wall_fire then over = true end
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
      -- Under a director's tempo, the units the assault lacks sent by pod, once a siege, and it waits a minute for them
      -- (ops.pay_gap; its raids' were paid and its sieges' never, the consult part three).
      if want and not spec.assault and n + home_n < want and not op.gap_asked and ops.pay_gap and t_owner_player(b, op) then
        op.gap_asked = true
        if ops.pay_gap(b, t.owner, want - (n + home_n), army.cap(b)) then
          op.assault_cool = game.tick + 3600
          return
        end
      end
      if want and not spec.assault and n + home_n < want and not op.told_short then
        op.told_short = true
        trace(b, string.format("siege: no assault (%d needed, %d guards and %d at home)", want, n, home_n))
      end
      if want and (spec.assault or on_strike or n + home_n >= want) then
        -- At a closed wall with no strike falling or painted: its menu (assault.lua), and its guns on the wall first when
        -- that is its pick.
        if not on_strike and not op.strike_paint and not op.clearance and t_owner_player(b, op)
          and not assault_by.closed(b, op, s, foes, live, left, t, want, trace) then
          return
        end
        -- (Its living guards: the dead counted, it drew short and its abort at half came early; the review.)
        local live = {}
        for _, u in ipairs(op.members) do if u.valid then live[#live + 1] = u end end
        op.members = live
        -- (A drop siege's from home by what its composition favours against its killers, army.composition: its escort is its
        -- mix's shares, and an assault of its infantry died to the gun turrets, siegetier 3; the user, 2026-11-03: tanks
        -- for the assault.)
        -- (Not on its strike: its own escort goes in behind it; from its camp, 330 tiles off, they came straight through
        -- the worm belt and stalled there, standsiege nests.)
        if on_strike then want = #op.members end
        if op.drop and army.composition then
          local w, sum = army.composition(b, army.mix(b)), 0
          for name, x in pairs(w) do if name ~= "lp-railgunner" then sum = sum + x end end
          local kinds = {}
          for name in pairs(w) do if name ~= "lp-railgunner" then kinds[#kinds + 1] = name end end
          table.sort(kinds, function(a, c) return w[a] > w[c] end)
          local need = want - #op.members
          for _, name in ipairs(kinds) do
            local k = math.floor(need * w[name] / math.max(1e-9, sum) + 0.5)
            for _, u in ipairs(pool.take(b, math.min(k, want - #op.members), pool.GUARD,
              function(u) return FOOT(u) and shared.kind_of(u.name) == name end)) do
              table.insert(op.members, u)
            end
          end
        end
        for _, u in ipairs(pool.take(b, want - #op.members, pool.GUARD, FOOT)) do table.insert(op.members, u) end
        op.launched = #op.members
        op.phase, op.phase_at, op.last_kill, op.kills_at, op.razed_before = "assault", game.tick, game.tick, b.razed, b.razed
        op.pushes = nil
        b.assaults = (b.assaults or 0) + 1
        -- A drop siege's at its roboports first, nearest its site first, then its target (what makes the damage stay: on
        -- the artillery base and nw its robots rebuilt nearly all it broke, 0 lost on nw).
        local acmds = {}
        local depth = op.drop and op.strike_center and {op.strike_center[1], op.strike_center[2]}
        op.assault_at = depth
        local at = depth or t.pos
        local from = op.site and {x = op.site[1], y = op.site[2]}
        local cx, cy, cn = 0, 0, 0
        for _, u in ipairs(op.members) do if u.valid then cx, cy, cn = cx + u.position.x, cy + u.position.y, cn + 1 end end
        if cn > 0 then from = {x = cx / cn, y = cy / cn} end
        -- (Its way read from where its closed-wall step read it, its guards' middle before its reinforcements came: read
        -- from the middle of all, its camp 300 tiles back, the way its guns had opened read walled off, lab w1. Only after
        -- its wall fire: read so always, the flamethrower lane's sieges went by a door its barrage had opened and got in less.)
        if op.way_from and op.wall_pieces then from = {x = op.way_from[1], y = op.way_from[2]} end
        op.door = nil
        if op.drop and op.strike_center then
          -- (To the breach undistracted first: told to engage anything on the way, its escort stood 45 s at its jump-off in
          -- a duel with the lasers round a substation in depth, 33 tiles aside and out of their reach; standsiege nests.)
          acmds[#acmds + 1] = {type = defines.command.go_to_location, destination = {op.strike_center[1], op.strike_center[2]},
            radius = 4, distraction = defines.distraction.none}
        else
          -- Through the way the barrage opened (open_way), not at the wall beside it.
          local way = from and assault_by.way(s, foes, from, {x = at[1], y = at[2]})
          op.door = way and way.door and {way.door.x, way.door.y} or nil
          op.way_open = way ~= nil
          if op.door then
            acmds[#acmds + 1] = {type = defines.command.go_to_location, destination = op.door, radius = 3,
              distraction = defines.distraction.by_enemy}
          end
          trace(b, way and (op.door and string.format("siege: its way in by %.0f,%.0f", op.door[1], op.door[2])
            or "siege: its way in is open") or "siege: walled off; its assault breaks the wall in its way")
        end
        -- Then what stands behind, by name: a drop siege's roboports first, nearest its site (what makes the damage stay:
        -- on the artillery base and nw its robots rebuilt nearly all it broke, 0 lost on nw), then turrets.
        local by = op.door and {x = op.door[1], y = op.door[2]} or (depth and {x = depth[1], y = depth[2]}) or from
          or {x = at[1], y = at[2]}
        local targets = assault_by.targets(s, foes, at, depth and ASSAULT_DEPTH or 16, by, op.drop)
        for i = 1, math.min(assault_by.ORDERS, #targets) do
          acmds[#acmds + 1] = {type = defines.command.attack, target = targets[i], distraction = defines.distraction.by_enemy}
        end
        if #acmds == 0 then
          acmds[1] = {type = defines.command.go_to_location, destination = at, radius = 6, distraction = defines.distraction.by_enemy}
        end
        if op.drop and op.strike_center then
          -- In staggered rows (the user, 2026-11-03: "attack in staggered rows"): its front rank first, each rank behind
          -- RANK_STAGGER later (a stop with ticks to wait opens its orders), ranks of about sqrt(2n) by distance to the
          -- breach: waves at the breach, not one rush.
          local live = {}
          for _, u in ipairs(op.members) do if u.valid then live[#live + 1] = u end end
          local bx, by = op.strike_center[1], op.strike_center[2]
          table.sort(live, function(p, q)
            return (p.position.x - bx) ^ 2 + (p.position.y - by) ^ 2 < (q.position.x - bx) ^ 2 + (q.position.y - by) ^ 2
          end)
          local w = math.max(1, math.ceil(math.sqrt(2 * #live)))
          for i, u in ipairs(live) do
            local r = math.floor((i - 1) / w)
            local cmds = {}
            if r > 0 then cmds[1] = {type = defines.command.stop, ticks_to_wait = r * RANK_STAGGER, distraction = defines.distraction.none} end
            for _, c in ipairs(acmds) do cmds[#cmds + 1] = c end
            u.commandable.set_command(#cmds > 1 and {type = defines.command.compound,
              structure_type = defines.compound_command.return_last, commands = cmds} or cmds[1])
          end
        else
          order_all(op.members, #acmds > 1 and {type = defines.command.compound,
            structure_type = defines.compound_command.return_last, commands = acmds} or acmds[1])
        end
        alert(b, t, "lp.alert-raid")
        trace(b, string.format("siege: the assault goes in with %d units", #op.members))
        return
      end
      local idle = game.tick - (op.last_target or op.phase_at) > 60 * 60
      local waiting = op.convoy ~= nil or op.supply_pod ~= nil
      -- (A drop siege's guns stand while they stand: half its guards lost at the lasers' edge packed up three mortars and
      -- a howitzer with 117 shells left, the user's watch, 2026-11-03.)
      if (left == 0 and not waiting) or idle or (not op.drop and n < 0.5 * op.launched) then
        op.phase, op.phase_at = "pack", game.tick
        op.packing_because = left == 0 and "spent" or (idle and "done" or "aborted")
        quiet_pack(op)
        trace(b, string.format("siege: packing up (%s; %d shells fired, %d of %d guards)", op.packing_because,
          op.shells_fired, n, op.launched))
      end
    else
      if b.razed > op.kills_at then op.kills_at, op.last_kill = b.razed, game.tick end
      local at = op.assault_at or (t and t.pos)
      local remaining = at and s.count_entities_filtered{position = at, radius = op.assault_at and ASSAULT_DEPTH or 16,
        type = TYPES, force = foes} or 0
      -- Its breach cleared (the strike had razed round it): on to what stands nearest past it, ASSAULT_PUSH tiles at most,
      -- PUSHES times (the user's nw game, 2026-11-26: its army walked to the breach "but suddenly changed its mind", and
      -- sat by its mortars while they shelled the roboports behind; nothing within ASSAULT_DEPTH of the breach read done).
      if remaining == 0 and op.drop and op.assault_at and (op.pushes or 0) < PUSHES then
        local near = s.find_entities_filtered{position = op.assault_at, radius = ASSAULT_PUSH, type = TYPES, force = foes}
        local best, bd
        for _, e in ipairs(near) do
          local d = (e.position.x - op.assault_at[1]) ^ 2 + (e.position.y - op.assault_at[2]) ^ 2
          if not bd or d < bd then best, bd = e, d end
        end
        if best then
          op.pushes, op.assault_at, op.last_kill = (op.pushes or 0) + 1, {best.position.x, best.position.y}, game.tick
          b.assault_pushes = (b.assault_pushes or 0) + 1
          at = op.assault_at
          remaining = s.count_entities_filtered{position = at, radius = ASSAULT_DEPTH, type = TYPES, force = foes}
          trace(b, string.format("siege: the breach cleared, the assault pushes on to %s at %.0f,%.0f (%d)", best.name,
            best.position.x, best.position.y, op.pushes))
        end
      end
      local done = remaining == 0 or game.tick - op.last_kill > NO_KILL_TICKS
      -- A drop siege's falls back to its jump-off and shells on, its guns standing: a later strike sends it in again.
      local live_guns = 0
      for _, m in ipairs(op.mortars or {}) do if m.valid then live_guns = live_guns + 1 end end
      if op.drop and live_guns > 0 and (done or n < FALL_BACK * op.launched) then
        b.assault_razed = (b.assault_razed or 0) + b.razed - op.razed_before
        local back = op.jump and {x = op.jump[1], y = op.jump[2]} or hold_spot(b, op)
        order_all(op.members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
          commands = {{type = defines.command.go_to_location, destination = back, radius = 4,
            distraction = defines.distraction.none},
            {type = defines.command.stop, distraction = defines.distraction.none}}})
        trace(b, string.format("siege: the assault falls back (%s; %d of %d left, %d left standing within %d of the breach)",
          done and "done" or "losses", n, op.launched, remaining, ASSAULT_DEPTH))
        op.phase, op.phase_at, op.last_target = "bombard", game.tick, game.tick
        op.launched, op.assault_at, op.assault_cool = n, nil, game.tick + ASSAULT_COOL
        op.strike_paint, op.strike_falling, op.jumped, op.reread = nil, nil, nil, nil
        return
      end
      if done or n < 0.5 * op.launched then
        op.phase, op.phase_at = "pack", game.tick
        op.packing_because = done and "done" or "aborted"
        quiet_pack(op)
        b.assault_razed = (b.assault_razed or 0) + b.razed - op.razed_before
        trace(b, string.format("siege: the assault ends (%s; %d of %d left, %d left standing at the target)",
          op.packing_because, n, op.launched, remaining))
        return
      end
      -- Its idle units each at the nearest thing standing there, by name (an area to attack, they shot the wall beside the
      -- breach: open_way), through the doorway when they are still outside it. Idle: no order, or the wander the engine
      -- gives a unit whose order is done (has_command reads true then: its first named targets down, the assault stood
      -- wandering 90 s by a substation it was never told of, fortress 12345).
      local targets
      for _, u in ipairs(op.members) do
        local c = u.valid and u.commandable.command
        local idle = u.valid and (not c or c.type == defines.command.wander or c.type == defines.command.stop
          or (c.type == defines.command.attack and not (c.target and c.target.valid)))
        if idle and at then
          targets = targets or s.find_entities_filtered{position = at, radius = op.assault_at and ASSAULT_DEPTH or 16,
            type = TYPES, force = foes}
          local e = #targets > 0 and s.get_closest(u.position, targets)
          if e then
            local cmds = {}
            local d = op.door
            if d and (u.position.x - e.position.x) ^ 2 + (u.position.y - e.position.y) ^ 2
              > (d[1] - e.position.x) ^ 2 + (d[2] - e.position.y) ^ 2 + 16 then
              cmds[1] = {type = defines.command.go_to_location, destination = d, radius = 3, distraction = defines.distraction.by_enemy}
            end
            cmds[#cmds + 1] = {type = defines.command.attack, target = e, distraction = defines.distraction.by_enemy}
            u.commandable.set_command(#cmds > 1 and {type = defines.command.compound,
              structure_type = defines.compound_command.return_last, commands = cmds} or cmds[1])
          end
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
