-- The army: depots build units from parts up to a garrison cap, in the mix the doctrine prefers. Raids are
-- operations (scripts/ops.lua); this module answers alarms, patrols, escorts convoys and intercepts trains.
local shared = require("__landing-party__.shared")
local know = require("__landing-party__.scripts.know")
local tune = require("__landing-party__.scripts.tune")
local rng = require("__landing-party__.scripts.rng")
local ops = require("__landing-party__.scripts.ops")
local rd = require("__landing-party__.scripts.rd")
local pool = require("__landing-party__.scripts.pool")

local army = {}

local BUILD_TICKS = 600          -- a depot turns out at most one unit per 10 s
local CAP_PER_DEPOT = 10
local HOME_GUARD = pool.GUARD    -- units that stay home (pool.floor)

army.MIX = {
  bastion = {["lp-infantry"] = 5, ["lp-tank"] = 3, ["lp-walker"] = 1, ["lp-harrier"] = 1},
  sprawl = {["lp-infantry"] = 3, ["lp-tank"] = 1, ["lp-walker"] = 1, ["lp-harrier"] = 4},
  picket = {["lp-infantry"] = 4, ["lp-tank"] = 2, ["lp-walker"] = 2, ["lp-harrier"] = 2},
  fortress = {["lp-infantry"] = 3, ["lp-tank"] = 2, ["lp-walker"] = 3, ["lp-harrier"] = 2},
}

local function prune(list)
  local j = 0
  for i = 1, #list do
    if list[i].valid then j = j + 1; list[j] = list[i] end
  end
  for i = #list, j + 1, -1 do list[i] = nil end
end

function army.init(b)
  b.garrison = b.garrison or {}
  b.raids = b.raids or {}
  b.units_built, b.units_lost, b.razed, b.raids_sent = b.units_built or 0, b.units_lost or 0, b.razed or 0,
    b.raids_sent or 0
  b.next_raid = b.next_raid or 0
end

local GARRISON_PER_TIER = 5     -- per depot
-- The corporation's development level (storage.corps, faction.develop).
local function level(b) return storage.corps and b.corp and storage.corps[b.corp] and storage.corps[b.corp].level or 0 end
army.level = level
-- Doubled while a grudge is fresh (faction.grudge): for GRUDGE_TICKS from its first depot (a camp has none for
-- its first twenty minutes or so, and a clock from the landing ran out as the depot opened).
army.GRUDGE_TICKS = 30 * 3600
local function cap(b)
  -- With no depot standing, the lander counts as one (camps under a megabase's guns never kept a depot, and with a cap
  -- of nought made no units at all, visit).
  local depots = 0
  for _, d in ipairs(b.depots) do if d.valid then depots = depots + 1 end end
  local n = math.max(depots, (b.lander and b.lander.valid) and 1 or 0) * (CAP_PER_DEPOT + GARRISON_PER_TIER * level(b))
  -- Its strength lever (tune.lua).
  n = math.max(1, math.floor(n * tune.strength(b.corp) + 0.5))
  -- An armed camp holds its costliest siege (ops.siege_garrison, siege.lua).
  if b.armed and ops.siege_garrison then n = math.max(n, ops.siege_garrison(b)) end
  -- The ladder buys capacity (Fable's pressure-ramp consult, item 4): from its second rung against a player, half as many
  -- again (b.war_rung, war.lua). It had only lowered the price of using what the settlement had.
  -- Its posture (strategy.lua, refreshed every 10 s by war.lua): a rung, a grudge, its recent losses. Before it is
  -- first set, the rung and the grudge as they were read here.
  if b.posture then n = math.floor(n * b.posture.arm)
  else
    if (b.war_rung or 0) >= 2 then n = math.floor(n * 1.5) end
    if b.grudge_till and game.tick < b.grudge_till then n = 2 * n end
  end
  -- Stood down (war.lua), it builds no army past a reserve, enough to hold its own ground, and its parts go back into its
  -- works (the user, 2026-11-04: "stop building past reserve"; strategy.posture leaves the planner nothing for an army
  -- not short of its cap). What it has it keeps.
  if b.quiescent then n = math.max(1, math.floor(n * army.RESERVE)) end
  return n
end
army.RESERVE = 0.5
army.cap = cap
-- Every unit it owns, out or home (pool.strength): the cap holds them all.
local function strength(b) return pool.strength(b) end

-- The doctrine's mix, restricted to what the faction's tier has unlocked.
local function mix(b)
  local out = {}
  -- The corporation's own mix where it has one (docs/corporations.md), else the doctrine's.
  for name, w in pairs((b.corp and shared.CORPS[b.corp].mix) or army.MIX[b.doctrine]) do
    if shared.capable(b.corp, name, level(b)) then out[name] = w end
  end
  -- What its tree has added (scripts/rd.lua): Lances, Slug buggies.
  if b.corp then for name, w in pairs(rd.mix(b.corp)) do out[name] = w end end
  return out
end

army.mix = mix

-- The drop escort (docs/reviews/2026-10-14-hull-consult.md): a landing comes down with units, n of the
-- corporation's mix, at no cost. A camp has no depot (its cap is nought) and no walls for its first twenty
-- minutes: without them, every new settlement fell to the first squad sent at it (campaign, seed 777).
function army.escort(b, n)
  local s = b.lander.surface
  local m = mix(b)
  local made = 0
  for _ = 1, n do
    local proto = rd.unit(b.corp, rng.weighted(b.rng, m))
    local p = s.find_non_colliding_position(proto, {b.lander.position.x, b.lander.position.y + 8}, 20, 0.5)
    local u = p and s.create_entity{name = proto, position = p, force = b.lander.force}
    if u then
      table.insert(b.garrison, u)
      pool.enlist(b, u)
      made = made + 1
    end
  end
  b.escort = (b.escort or 0) + made
  return made
end

-- One unit from the first depot with room, if parts allow; the doctrine weighs which.
local function withdrawing(b) return storage.corps and storage.corps[b.corp] and storage.corps[b.corp].withdrawing end
army.withdrawing = withdrawing
-- What it builds, tilted toward what answers what has been killing it (the faction AI's composition, step 5;
-- docs/reviews/2026-10-23-faction-ai-audit.md): each kind's weight in its mix times 1 + counter x its arena score
-- (counters.lua, -1 to 1) against its killers of the last COMPOSE_WINDOW (know.lua), each killer by its share, at
-- least a tenth. counter is its mind's (how hard it adapts); none, or under three losses, the mix as it is.
local COUNTERS = require("__landing-party__.counters")
local COMPOSE_WINDOW = 20 * 3600
local KILLER_COLUMN = {vehicle = "lp-battle-tank", character = "lp-trooper"}
-- Fliers where the air is open (the user, 2026-11-09, on air raids: "build more fliers against weak-AA defences"): over
-- the player's targets it has sensed (AIR_SEEN at least), what defends them on foot against what shoots up round them
-- (intel's t.air_near, airraid.weigh), (ground + 1) / (air + 1) over airraid.EDGE, at most AIR_TILT, times every flier's
-- weight. Walls of flamethrowers and artillery tilt it; a defence of guns and lasers, which shoot up, leaves it at 1.
local airraid = require("__landing-party__.scripts.airraid")
local AIR_SEEN, AIR_TILT = 3, 3
local function air_tilt(b)
  local g, a, n = 0, 0, 0
  for _, t in pairs((b.intel or {}).targets or {}) do
    local f = t.air_near and t.owner and game.forces[t.owner]
    if f and shared.is_player_force(f) then
      g, a, n = g + (t.defence or 0), a + t.air_near, n + 1
    end
  end
  local tilt = n >= AIR_SEEN and math.max(1, math.min(AIR_TILT, (g + 1) / (a + 1) / airraid.EDGE)) or 1
  b.air_tilt = tilt
  return tilt
end
army.air_tilt = air_tilt

local function counter_composition(b, m)
  local mind = (shared.CORPS[b.corp] or {}).mind or {}
  local k = mind.counter or 0
  if k == 0 then return m end
  local seen, n = {}, 0
  for _, l in ipairs(know.losses(b.corp, COMPOSE_WINDOW, function(l) return l.unit and l.killer ~= nil end)) do
    local key = KILLER_COLUMN[l.killer] or l.killer
    seen[key] = (seen[key] or 0) + 1
    n = n + 1
  end
  if n < 3 then return m end
  local out = {}
  for name, w in pairs(m) do
    local row = COUNTERS[shared.variant(b.corp, name)] or COUNTERS[name]
    local s = 0
    if row then for key, c in pairs(seen) do s = s + (row[key] or 0) * c / n end end
    out[name] = w * math.max(0.1, 1 + k * s)
  end
  b.composed = out
  return out
end
local function composition(b, m)
  local out = counter_composition(b, m)
  local tilt = air_tilt(b)
  if tilt <= 1 then return out end
  local t = {}
  for name, w in pairs(out) do t[name] = airraid.is_flier(shared.variant(b.corp, name)) and w * tilt or w end
  return t
end
army.composition = composition

local function produce(b, trace)
  if storage.army_off or withdrawing(b) then return end
  prune(b.garrison)
  -- A clearance short of railgunners (ops.clearance) has them made over the cap: on nw a full garrison of other kinds
  -- made none, and it waited "for railgunners (0 of 8)" for two hours.
  local over = b.rails_short and shared.units["lp-railgunner"] and (mix(b)["lp-railgunner"] or 0) > 0
  if over then
    -- Only up to what the clearance waits for (the flag stands until its next try: 42 were made, scenario).
    local rails = 0
    for _, u in ipairs(b.garrison) do if u.valid and shared.kind_of(u.name) == "lp-railgunner" then rails = rails + 1 end end
    over = rails < b.rails_short
  end
  local full = strength(b) >= cap(b)
  if full and not over then return end
  -- A rebuild that makes parts is paid first (base.reserve; scenario occupy).
  -- A unit its research has just given comes off the line first, once at each settlement; then the composition decides
  -- (unitnode tesla, 2026-10-24: the tree bought the Tesla against turrets, the counter matrix scored it -0.72 against
  -- gun turrets, the tilt cut it to a quarter, and no depot built one: research that never takes the field).
  local first
  local fresh = {}
  for kind in pairs(rd.mix(b.corp)) do if not (b.built_by and b.built_by[kind]) then fresh[#fresh + 1] = kind end end
  table.sort(fresh)
  first = fresh[1]
  local name = b.next_unit or first or rng.weighted(b.rng, composition(b, mix(b)))
  -- A clearance waiting for railgunners (ops.clearance) gets them first.
  if (b.want_rails and not b.next_unit and shared.units["lp-railgunner"] and (mix(b)["lp-railgunner"] or 0) > 0) or full then
    name = "lp-railgunner"
  end
  b.next_unit = name
  local cost = shared.unit_cost(b.corp, name)
  if b.parts < cost + (army.reserve and army.reserve(b, name) or 0) then return end
  local yards = {}
  for _, d in ipairs(b.depots) do if d.valid then table.insert(yards, d) end end
  if #yards == 0 and b.lander and b.lander.valid then yards = {b.lander} end
  for _, depot in ipairs(yards) do
    if depot.valid then
      local surface = depot.surface
      local proto = rd.unit(b.corp, name)
      -- Out past its own walls, facing the player, where walls stand between (army.muster); else by the depot.
      local spawn = game.forces.player.get_spawn_position(surface)
      local p, out = army.muster(b, depot.position, spawn, proto, 0)
      -- (Railgunners by the depot: no raid takes them, and made past its cordon's walls they stood there, 165 tiles out,
      -- and shot the player's wall from beyond its guns' reach; a deathworld visit, 0.2.128.)
      if out < 5 or name == "lp-railgunner" then p = army.spawn_point(b, proto, {depot.position.x, depot.position.y + 4}, 12)
      elseif p and not army.open_spot(b, p) then p = army.spawn_point(b, proto, p, 12) end
      local u = p and surface.create_entity{name = proto, position = p, force = depot.force}
      if u then
        b.parts = b.parts - cost
        b.next_unit = nil
        b.units_built = b.units_built + 1
        b.built_by = b.built_by or {}
        b.built_by[name] = (b.built_by[name] or 0) + 1
        table.insert(b.garrison, u)
        pool.enlist(b, u)
        return u
      end
    end
  end
end

-- Response: a building hit within reach of a depot calls out a squad from the garrison (the home guard
-- stays), at most once a minute per settlement. It goes as a raid does and comes home the same way.
local RESPONSE_RANGE = 300
-- Sized to the threat: six units for each hostile turret, unit, vehicle or character near the alarm, at
-- least six. A fixed eight died to the last unit against two gun turrets (defend, seed 12345); three per
-- threat still died to the last unit against upgraded turrets.
local RESPONSE_PER_THREAT = 6
local RESPONSE_MIN = 6
local THREAT_RADIUS = 30
local THREATS = {"ammo-turret", "electric-turret", "fluid-turret", "artillery-turret", "unit", "car", "spider-vehicle",
  "character"}

local MOBILE = {"unit", "car", "spider-vehicle", "character"}
local function threat_count(surface, pos, f, types, no_biters)
  local n = 0
  for _, other in pairs(game.forces) do
    if other ~= f and other.name ~= "neutral" and not f.get_cease_fire(other) and not (no_biters and other.name == "enemy") then
      n = n + surface.count_entities_filtered{position = pos, radius = THREAT_RADIUS, force = other, type = types or THREATS}
    end
  end
  return n
end
local RESPONSE_COOLDOWN = 60 * 60
local BITER_RESPONSE = 3
local BITER_GUNS, BITER_COVER = 2, 20

function army.alarm(b, pos, trace)
  if not storage.ops_off then ops.sense_at(b, pos, 40) end
  if storage.army_off or game.tick < (b.next_response or 0) then return end
  -- Static threats (turret creep) get no piecemeal answer: fed one squad at a time into three turrets, the
  -- garrison bled out (defend). They become a priority target for a raid sized to them (scripts/ops.lua).
  local d0 = b.depots[1]
  if d0 and d0.valid and not storage.ops_off and threat_count(d0.surface, pos, d0.force, MOBILE) == 0 then
    ops.threatened(b, pos)
    return
  end
  prune(b.garrison)
  local home, hd
  for _, d in ipairs(b.depots) do
    if d.valid then
      local dist = math.sqrt((d.position.x - pos.x) ^ 2 + (d.position.y - pos.y) ^ 2)
      if dist <= RESPONSE_RANGE and (not hd or dist < hd) then home, hd = d, dist end
    end
  end
  -- A camp has no depot for its first twenty minutes or so: its drop escort answers from the lander (a biter ate
  -- whole camps while the escort stood by, the user in game).
  if not home and b.lander and b.lander.valid then
    local dist = math.sqrt((b.lander.position.x - pos.x) ^ 2 + (b.lander.position.y - pos.y) ^ 2)
    if dist <= RESPONSE_RANGE then home = b.lander end
  end
  if not home or #b.garrison <= HOME_GUARD then return end
  b.next_response = game.tick + RESPONSE_COOLDOWN
  local size = math.max(RESPONSE_MIN, RESPONSE_PER_THREAT * threat_count(home.surface, pos, home.force))
  -- Biters alone get a small answer (sized to every biter, responses bled garrisons on nests nobody chose).
  local biters_only = threat_count(home.surface, pos, home.force, nil, true) == 0
  if biters_only then
    -- None where its turrets reach: three at a time into a nest field's attacks on its wall bled a camp of 266 units
    -- in three hours (visit deathworld). There its turrets answer; an outpost they do not reach still gets a squad.
    local guns = 0
    for _, t in ipairs(b.turrets or {}) do
      if t.valid and (t.position.x - pos.x) ^ 2 + (t.position.y - pos.y) ^ 2 <= BITER_COVER ^ 2 then guns = guns + 1 end
    end
    if guns >= BITER_GUNS then b.next_response = 0; return end
    size = BITER_RESPONSE
  end
  local group = home.surface.create_unit_group{position = home.position, force = home.force}
  local members = {}
  local dest = {pos.x, pos.y}
  local cmd = {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = {
    {type = defines.command.go_to_location, destination = dest, radius = 16, distraction = defines.distraction.by_enemy},
    {type = defines.command.attack_area, destination = dest, radius = 30, distraction = defines.distraction.by_anything},
  }}
  -- Its railgunners stay home for its clearances: a nest clearer since 0.2.20, weak against biters on their feet until
  -- researched, sent first at every wave they died at it (hazard worm: 6 of 10 lost in 12 minutes, the clearance then
  -- waiting for railgunners while the waves bled its economy dry). Against biters they were sent first until then.
  for _, u in ipairs(pool.take(b, size - #members, HOME_GUARD, function(u) return shared.kind_of(u.name) ~= "lp-railgunner" end)) do
    if u.type == "unit" then group.add_member(u) else u.commandable.set_command(cmd) end
    table.insert(members, u)
  end
  group.set_command(cmd)
  table.insert(b.raids, {group = group, members = members, target = dest, started = game.tick, home = home,
    kind = "response"})
  b.responses = (b.responses or 0) + 1
  trace(b, string.format("response %d: %d units (wanted %d) to %.0f,%.0f", b.responses, #members, size, pos.x, pos.y))
end

-- A raid is over when its group has finished or broken up, or after five minutes: survivors go home.
local function settle(b, trace)
  for i = #b.raids, 1, -1 do
    local r = b.raids[i]
    local done = game.tick - r.started > 5 * 3600 or not r.group.valid
      or r.group.state == defines.group_state.finished
    if done then
      local alive = 0
      for _, u in ipairs(r.members) do
        if u.valid then
          alive = alive + 1
          pool.give_one(b, u)
          if r.home.valid then
            u.commandable.set_command{type = defines.command.go_to_location, destination = r.home.position, radius = 8,
              distraction = defines.distraction.by_enemy}
          end
        end
      end
      if r.group.valid then r.group.destroy() end
      trace(b, string.format("%s over after %ds: %d of %d came back", r.kind or "raid", (game.tick - r.started) / 60,
        alive, #r.members))
      table.remove(b.raids, i)
    end
  end
end

-- Patrols: a few units taken from the garrison walk a loop through the settlement (pickets, compounds,
-- outposts), fighting what they meet. The settlement looks alive, and soft outposts are visited.
army.PATROL = {bastion = 2, sprawl = 4, picket = 3, fortress = 3}
local function waypoints(b)
  local pts = {}
  for _, m in ipairs(b.modules) do
    if m.built and not m.captured and (m.kind == "mining" or m.kind == "picket" or m.kind == "compound"
      or m.kind == "pad") then table.insert(pts, m.center) end
  end
  return pts
end

local function patrol(b, trace)
  b.patrol = b.patrol or {}
  prune(b.patrol)
  local want = army.PATROL[b.doctrine] or 2
  -- The garrison pruned first: a dead unit moved to the patrol crashed the order loop (siege, seed 4242).
  prune(b.garrison)
  -- A route of up to five stops, drawn once and redrawn when the settlement changes much. None yet, none taken (units
  -- taken with no route stood in the patrol list unordered, wandering in the landing pad: scenario idle).
  local pts = waypoints(b)
  if #pts < 2 then return end
  for _, u in ipairs(pool.take(b, want - #b.patrol, HOME_GUARD)) do table.insert(b.patrol, u) end
  if #b.patrol == 0 then return end
  if not b.route or b.route_n ~= #pts then
    local route, used = {}, {}
    for _ = 1, math.min(5, #pts) do
      local k
      repeat k = rng.int(b.rng, 1, #pts) until not used[k]
      used[k] = true
      table.insert(route, {pts[k][1], pts[k][2]})
    end
    b.route, b.route_n = route, #pts
    trace(b, string.format("patrol route of %d stops for %d units", #route, #b.patrol))
  end
  for i, u in ipairs(b.patrol) do
    -- Idle or wandering: a unit made by script wanders where it is made, which counts as a command, and the drop escort
    -- drafted to patrol never walked a loop (patrol_loops 0, scenario idle).
    local c = u.commandable
    if not c.has_command or (c.command and c.command.type == defines.command.wander) then
      local cmds = {}
      for k = 0, #b.route - 1 do
        local p = b.route[(i + k - 1) % #b.route + 1]
        table.insert(cmds, {type = defines.command.go_to_location, destination = p, radius = 6,
          distraction = defines.distraction.by_enemy})
      end
      u.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = cmds}
      b.patrol_legs = (b.patrol_legs or 0) + 1
    end
  end
end

-- Convoys: while the uplink stands, a mature settlement's exports travel to it as a hauler with up to two
-- escorts, in legs of about 100 tiles (long single paths are where the pathfinder gives up). Arrival exports
-- the cargo (army.on_deliver, set by base); a destroyed hauler loses it.
local CONVOY_LEG = 100
local CONVOY_ESCORT = 2

-- The corporation's own headquarters (its uplink standing): convoys go there only.
local function uplink_settlement(b)
  local d = storage.corps and storage.corps[b.corp]
  local u = d and d.hq and storage.bases[d.hq]
  if u and u.uplink and u.uplink.valid then return u end
end

-- Its rally point: past its own outermost wall on the line from `from` toward `to` (its own walls only: walked the whole
-- way, the uplink's, the same force, set a hauler down beside it, delivered in 0 s), at least `min` out. Units made inside
-- a walled district or block stood there raid after raid (system 4242, 2026-10-24: tanks in a district walled shut on
-- the side facing the player); a convoy's haulers made inside never left (visit deathworld10x). nil: no free spot.
function army.muster(b, from, to, name, min)
  local surface = b.lander.surface
  local hx, hy = from.x or from[1], from.y or from[2]
  local ux, uy = (to.x or to[1]) - hx, (to.y or to[2]) - hy
  local ul = math.max(1, math.sqrt(ux * ux + uy * uy))
  local out = min or 0
  for d = 0, ul / 2, 2 do
    if surface.count_entities_filtered{position = {hx + ux / ul * d, hy + uy / ul * d}, radius = 2.5, force = b.lander.force,
      type = {"wall", "gate"}, limit = 1} > 0 then out = math.max(out, d + 5) end
  end
  out = math.min(out, ul)
  return surface.find_non_colliding_position(name, {hx + ux / ul * out, hy + uy / ul * out}, 20, 0.5), out
end

function army.convoy(b, cargo, trace)
  local dest = uplink_settlement(b)
  if not dest or dest == b then return false end
  local surface = b.lander.surface
  local home = (b.depots[1] and b.depots[1].valid and b.depots[1]) or b.lander
  -- Form up outside the settlement, on the side facing the uplink: past its outermost wall or gate on that line (gates open
  -- for no unit). Formed 25 to 45 tiles out, a nine-block bastion's haulers were made inside a walled fab compound and
  -- never left: 68 sent, none delivered (visit deathworld10x). Beside a walled depot, escorts stalled (seed 4242).
  local p = army.muster(b, home.position, dest.uplink.position, shared.variant(b.corp, "lp-hauler"), 25)
  local hauler = p and surface.create_entity{name = shared.variant(b.corp, "lp-hauler"), position = p, force = home.force}
  if not hauler then return false end
  local escorts = {}
  prune(b.garrison)
  -- Escorts from units at home only: the last convoy's escorts, back in the garrison but still at the
  -- uplink's gate 210 tiles away, were drafted at once and the group waited for them.
  escorts = pool.take(b, CONVOY_ESCORT, HOME_GUARD, function(u)
    return u.type == "unit" and (u.position.x - home.position.x) ^ 2 + (u.position.y - home.position.y) ^ 2 < 30 * 30
  end)
  -- The escorts ride out on the hauler, as a siege's guards do: drafted inside the walls, they could not reach it past them
  -- and were let go after a minute, the hauler leaving alone.
  for _, u in ipairs(escorts) do
    local q = u.valid and surface.find_non_colliding_position(u.name, hauler.position, 12, 0.5)
    if q then u.teleport(q) end
  end
  -- Dock outside the fortress, on the side the convoy comes from: sent to the uplink in the inner yard,
  -- haulers circled the outer ring (seed 12345), the offset openings being no road for a vehicle.
  local target = {dest.uplink.position.x, dest.uplink.position.y}
  local fort = dest.blocks[1]
  if fort and fort.kind == "fortress" then
    local cx, cy = fort.center[1], fort.center[2]
    local dx, dy = home.position.x - cx, home.position.y - cy
    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
    local r = fort.w / 2 + 6
    target = {cx + dx / len * r, cy + dy / len * r}
  end
  local c = {hauler = hauler, escorts = escorts, cargo = cargo, dest = target, dest_id = dest.id, uplink = dest.uplink,
    started = game.tick,
    last = {hauler.position.x, hauler.position.y}, home = home}
  b.convoys = b.convoys or {}
  table.insert(b.convoys, c)
  army.route_convoy(c)
  b.convoys_sent = (b.convoys_sent or 0) + 1
  trace(b, string.format("convoy %d: %d parts to the uplink at %.0f,%.0f, %d escorts", b.convoys_sent, cargo,
    target[1], target[2], #escorts))
  return true
end

-- Convoy discipline, kept by the script: the hauler waits until its escorts are close (forming), escorts
-- follow it, and it halts while any escort is more than CONVOY_SLACK behind. (One engine unit group was
-- tried: stuck escorts were dropped from it and the hauler went on alone, seeds 4242, 777.)
local CONVOY_CLOSE = 8
local CONVOY_SLACK = 12

local function hauler_route(c)
  local from = c.hauler.position
  local dx, dy = c.dest[1] - from.x, c.dest[2] - from.y
  local len = math.sqrt(dx * dx + dy * dy)
  local legs = math.max(1, math.ceil(len / CONVOY_LEG))
  local cmds = {}
  for k = 1, legs do
    table.insert(cmds, {type = defines.command.go_to_location, destination = {from.x + dx * k / legs, from.y + dy * k / legs},
      radius = k == legs and 6 or 12, distraction = defines.distraction.by_damage})
  end
  c.hauler.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
    commands = cmds}
  c.moving = true
end

local function hold(c)
  c.hauler.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.by_damage}
  c.moving = false
end

function army.route_convoy(c)
  hold(c)
  c.formed = false
end

-- One step of discipline, every few seconds.
local RELEASE_STEPS = 60          -- an escort behind for this many steps (a minute) is let go
local CONVOY_DOCK = 30            -- a hauler this near the uplink has arrived
local CONVOY_STUCK = 120          -- a hauler that has not moved for this many steps (two minutes) is called off

local function escort_step(c, b)
  local hp = c.hauler.position
  local worst = 0
  c.behind = c.behind or {}
  for i = #c.escorts, 1, -1 do
    local e = c.escorts[i]
    if e.valid then
      local d = math.sqrt((e.position.x - hp.x) ^ 2 + (e.position.y - hp.y) ^ 2)
      c.behind[e.unit_number] = d > CONVOY_SLACK and (c.behind[e.unit_number] or 0) + 1 or 0
      if c.behind[e.unit_number] >= RELEASE_STEPS then
        -- Stuck for good: back to the garrison, so one wedged escort does not hold the convoy forever.
        table.remove(c.escorts, i)
        pool.give_one(b, e)
        c.released = (c.released or 0) + 1
        d = 0
      end
      worst = math.max(worst, d)
      -- Keep station on a flank, a little ahead in the direction of travel: chasing where the hauler was a
      -- second ago, escorts trailed 8-10 tiles behind.
      local dx, dy = c.dest[1] - hp.x, c.dest[2] - hp.y
      local len = math.max(1, math.sqrt(dx * dx + dy * dy))
      local side = (i % 2 == 0) and 1 or -1
      local station = {hp.x + dx / len * 3 - dy / len * 3 * side, hp.y + dy / len * 3 + dx / len * 3 * side}
      -- Re-ordered only when off station by 3 tiles: each new order is a fresh path, and units hesitate on one.
      if (e.position.x - station[1]) ^ 2 + (e.position.y - station[2]) ^ 2 > 9 or not e.commandable.has_command then
        e.commandable.set_command{type = defines.command.go_to_location, destination = station, radius = 1.5,
          distraction = defines.distraction.by_damage}
      end
    end
  end
  if not c.formed then
    if worst <= CONVOY_CLOSE then c.formed = true; hauler_route(c) end
  elseif c.moving and worst > CONVOY_SLACK then
    hold(c)
  elseif not c.moving and worst <= CONVOY_CLOSE then
    hauler_route(c)
  end
end

-- Diagnostics for the convoy scenario: each travelling convoy's group and escorts.
function army.convoy_debug(b)
  local out = {}
  for _, c in ipairs(b.convoys or {}) do
    if c.hauler.valid then
      local e = {}
      for _, x in ipairs(c.escorts) do
        if x.valid then
          table.insert(e, string.format("%s@%.0f,%.0f", x.name, x.position.x, x.position.y))
        end
      end
      table.insert(out, string.format("hauler@%.0f,%.0f formed=%s moving=%s [%s]", c.hauler.position.x, c.hauler.position.y,
        tostring(c.formed), tostring(c.moving), table.concat(e, "; ")))
    end
  end
  return table.concat(out, " | ")
end

-- How far the escorts are from their hauler (the largest distance), for the convoy scenario; `moving` counts only
-- haulers under way (a held hauler waits while its escorts walk round a wall to it).
function army.convoy_spread(b, moving)
  local worst = 0
  for _, c in ipairs(b.convoys or {}) do
    -- Once formed (before, escorts are still walking in).
    if c.hauler.valid and c.formed and (c.moving or not moving) then
      for _, e in ipairs(c.escorts) do
        if e.valid then
          worst = math.max(worst, math.sqrt((e.position.x - c.hauler.position.x) ^ 2 + (e.position.y - c.hauler.position.y) ^ 2))
        end
      end
    end
  end
  return worst
end

local function travel(b, trace)
  for i = #(b.convoys or {}), 1, -1 do
    local c = b.convoys[i]
    local done
    if not c.hauler.valid then
      b.convoys_lost = (b.convoys_lost or 0) + 1
      b.cargo_lost = (b.cargo_lost or 0) + c.cargo
      trace(b, string.format("convoy lost with %d parts", c.cargo))
      done = true
    -- At its dock, or near the uplink however it came: a young headquarters walls its dock in, and haulers stopped 10 to 26
    -- tiles from the uplink, 28 from the dock (visit deathworld10x, scenario convoy grown).
    elseif (c.hauler.position.x - c.dest[1]) ^ 2 + (c.hauler.position.y - c.dest[2]) ^ 2 < 20 * 20
      or (c.uplink and c.uplink.valid and (c.hauler.position.x - c.uplink.position.x) ^ 2
        + (c.hauler.position.y - c.uplink.position.y) ^ 2 < CONVOY_DOCK ^ 2) then
      if army.on_deliver then army.on_deliver(b, c.cargo) end
      b.convoys_delivered = (b.convoys_delivered or 0) + 1
      trace(b, string.format("convoy delivered %d parts after %ds", c.cargo, (game.tick - c.started) / 60))
      c.hauler.destroy()
      done = true
    else
      escort_step(c, b)
      -- Stalled while meant to move (no progress since the last look): fresh orders from where it stands.
      local p = c.hauler.position
      local still = (p.x - c.last[1]) ^ 2 + (p.y - c.last[2]) ^ 2 < 1
      c.still = still and (c.still or 0) + 1 or 0
      if c.still >= CONVOY_STUCK then
        -- No progress for two minutes, formed or not: called off, its cargo back in stock. Whatever stops a convoy, the
        -- next one must not pile up behind it.
        local near = {}
        for _, e in pairs(c.hauler.surface.find_entities_filtered{position = p, radius = 4, limit = 8}) do
          if e ~= c.hauler then table.insert(near, e.name) end
        end
        trace(b, string.format("convoy called off, stuck at %.0f,%.0f (formed %s, %d escorts, near %s): %d parts back",
          p.x, p.y, tostring(c.formed), #c.escorts, table.concat(near, ", "), c.cargo))
        b.parts = b.parts + c.cargo
        b.convoys_stuck = (b.convoys_stuck or 0) + 1
        c.hauler.destroy()
        done = true
      else
        if c.moving and still then hauler_route(c) end
        c.last = {p.x, p.y}
      end
    end
    if done then
      for _, e in ipairs(c.escorts) do
        if e.valid then
          pool.give_one(b, e)
          if c.home.valid then
            e.commandable.set_command{type = defines.command.go_to_location, destination = c.home.position, radius = 8,
              distraction = defines.distraction.by_enemy}
          end
        end
      end
      table.remove(b.convoys, i)
    end
  end
end

-- Interceptors: trains of a hostile force passing within INTERCEPT_RANGE of a settlement draw up to
-- INTERCEPT_SIZE units from its garrison, harriers first, at the nearest carriage. They come home as a
-- raid does. Rail lines near their ground become a liability.
local INTERCEPT_RANGE = 150
local INTERCEPT_SIZE = 4
local INTERCEPT_COOLDOWN = 2 * 3600

local function intercept(b, trace)
  if storage.army_off or game.tick < (b.next_intercept or 0) or #b.depots == 0 then return end
  prune(b.garrison)
  if #b.garrison <= HOME_GUARD then return end
  local f = b.lander.force
  local lp = b.lander.position
  local best, bd
  for _, other in pairs(game.forces) do
    if other ~= f and not shared.is_biters(other.name) and other.name ~= "neutral" and not f.get_cease_fire(other) then
      for _, train in pairs(game.train_manager.get_trains{surface = b.lander.surface, force = other}) do
        for _, car in pairs(train.carriages) do
          local d = (car.position.x - lp.x) ^ 2 + (car.position.y - lp.y) ^ 2
          if d < INTERCEPT_RANGE ^ 2 and (not bd or d < bd) then best, bd = car, d end
        end
      end
    end
  end
  if not best then return end
  b.next_intercept = game.tick + INTERCEPT_COOLDOWN
  local members = {}
  table.sort(b.garrison, function(x, y)
    local hx, hy = shared.kind_of(x.name) == "lp-harrier" and 0 or 1, shared.kind_of(y.name) == "lp-harrier" and 0 or 1
    if hx ~= hy then return hx > hy end
    return x.unit_number < y.unit_number
  end)
  for _, u in ipairs(pool.take(b, INTERCEPT_SIZE, HOME_GUARD)) do
    u.commandable.set_command{type = defines.command.attack, target = best, distraction = defines.distraction.by_enemy}
    table.insert(members, u)
  end
  local group = b.lander.surface.create_unit_group{position = b.lander.position, force = f}
  table.insert(b.raids, {group = group, members = members, target = {best.position.x, best.position.y},
    started = game.tick, home = b.depots[1], kind = "intercept"})
  b.intercepts = (b.intercepts or 0) + 1
  trace(b, string.format("intercept %d: %d units at a %s at %.0f,%.0f", b.intercepts, #members, best.name,
    best.position.x, best.position.y))
end

-- The leash: a garrison unit beyond its settlement's claim (and LEASH more) is called back. Idle, it attacks whatever it
-- sees; biters drawn to a clearance pulled infantry and tanks after them into behemoth worms' reach, 28 to 56 tiles
-- beyond the site (scenario clear). Not within the claim: leashed at 35 tiles from its first depot, the far side of a
-- settlement went undefended and biters took 497 of its buildings (visit b - rocket).
-- Its railgunners on a shorter one, RAIL_LEASH from its lander, idle or wandering: its claim grows with its cordon
-- (275 to 350 tiles on deathworld) to the player's wall, and one railgunner, outranging the gun turrets, walked it and
-- broke 205 of the player's buildings (a deathworld visit, 0.2.128). Its clearances take them out of the garrison.
local LEASH = shared.LEASH
local RAIL_LEASH = 48
local function leash(b, trace)
  local h = b.depots[1] and b.depots[1].valid and b.depots[1] or (b.lander.valid and b.lander)
  if not h then return end
  -- In a truce of its corporation's (a director's lull) home without answering fire: called back by_damage from the
  -- player's base, they fought their way out (railbase_end, 0.2.401).
  local d = shared.truce_held(b.corp) and defines.distraction.none or defines.distraction.by_damage
  local hp = h.position
  local r = (b.claim_radius or 60) + LEASH
  local lp = b.lander.valid and b.lander.position
  for _, u in ipairs(b.garrison) do
    local rail = u.valid and shared.kind_of(u.name) == "lp-railgunner"
    local c = u.valid and u.commandable
    local far = rail and lp and (u.position.x - lp.x) ^ 2 + (u.position.y - lp.y) ^ 2 > RAIL_LEASH * RAIL_LEASH
      and (not c.has_command or c.command and c.command.type == defines.command.wander)
    -- Idle ones only: re-ordered straight home, raiders coming back round a nest field walked through it (country).
    if far then
      u.commandable.set_command{type = defines.command.go_to_location, destination = lp, radius = 16, distraction = d}
      trace(b, string.format("leash: railgunner %d at %.0f,%.0f called back to its lander (%s)", u.unit_number, u.position.x,
        u.position.y, c.has_command and "wandering" or "idle"))
    elseif u.valid and not u.commandable.has_command
      and (u.position.x - b.origin.x) ^ 2 + (u.position.y - b.origin.y) ^ 2 > r * r then
      u.commandable.set_command{type = defines.command.go_to_location, destination = hp, radius = 10, distraction = d}
    end
  end
end

-- The yard: where its idle garrison waits, on open ground outside its walled blocks, YARD_RINGS tiles from its first
-- depot (else its lander, as the leash's home), each unit on a slot of its own on a spiral round it so vehicles do not
-- stack. A unit made by script wanders where it is made: the drop escort (made in the landing pad) and the depot's units
-- milled inside the pad, on its corner turrets and in the gap of its south wall, for the whole of a visit (trailer
-- footage, 2026-11-04; scenario idle). Only idle, wandering or standing units are sent, and on its slot a unit stands
-- (a stop order, distracted only by damage: it waits, and what attacks the camp is answered by responses). Operations,
-- responses, patrols and convoys take them as before (pool.take).
local YARD_RINGS = {16, 20, 24, 28}
local YARD_ANGLES = 12
local YARD_AT = 3                -- within this of its slot, it stops there
local YARD_RESEND = 3600         -- a unit sent not again within a minute (a slot it cannot reach)
local YARD_TRIES = 3             -- nor after three sends that never got it there: it stays where it is
local YARD_REFRESH = 3600        -- the spot looked for again (the camp builds over it)
local YARD_CLEAR = 8             -- the spot this far outside any walled block (its slots spread round it)
-- and this far from anything of an enemy's when it is looked for (each minute)
local YARD_QUIET = 40
local YARD_SPAWN = 14            -- and this far from where the camp's trucks come out (12 tiles south of home)
local function walled_boxes(b)
  local out = {}
  for _, m in ipairs(b.blocks or {}) do
    if m.walls or m.kind == "pad" then table.insert(out, {m.x0 - 1, m.y0 - 1, m.x0 + m.w + 1, m.y0 + m.h + 1}) end
  end
  return out
end
local function in_boxes(boxes, x, y, margin)
  local e = margin or 0
  for _, q in ipairs(boxes) do
    if x > q[1] - e and x < q[3] + e and y > q[2] - e and y < q[4] + e then return true end
  end
  return false
end
local function open_ground(s, x, y)
  for _, e in pairs(s.find_entities_filtered{position = {x, y}, radius = 6}) do
    if e.type == "cliff" or e.prototype.is_building then return false end
  end
  return s.count_tiles_filtered{position = {x, y}, radius = 4, collision_mask = "water_tile", limit = 1} == 0
end
-- A gun of a force it is only at cease-fire with (not its friend) within YARD_QUIET: find_nearest_enemy passes over it,
-- but a cease-fire ends (Grubstake's pact with the biters, broken by a pact breaker or its antenna lost), and a yard
-- under that force's guns is shot the moment it does (2026-11-06; scenario idle LP_MIX=truce, a wild worm set by its
-- yard: the yard stayed beside it).
local GUNS = {"turret", "ammo-turret", "electric-turret", "fluid-turret"}
local function truced_gun(s, x, y, force)
  for _, e in pairs(s.find_entities_filtered{position = {x, y}, radius = YARD_QUIET, type = GUNS}) do
    if e.force ~= force and not force.get_friend(e.force) and force.get_cease_fire(e.force) then return true end
  end
  return false
end
-- Its spot: the first open one on rings round home, from the side away from the player's spawn out to either side by
-- turns (a yard 19 tiles from three gun turrets the player set by a crew's road drew their fire, and its units razed
-- them: crew answered). Not by what the camp makes south of home (the drop escort 8 tiles, a skimming truck 12, its loot
-- chest 8 by 8): a truck made among the units standing at a yard there got stuck three runs in four (skim, seed 12345).
function army.yard_spot(b)
  local h = b.depots[1] and b.depots[1].valid and b.depots[1] or (b.lander.valid and b.lander)
  if not h then return nil end
  local key = h.unit_number
  if b.yard and b.yard_key == key and game.tick - (b.yard_at or 0) < YARD_REFRESH then return b.yard end
  local s, hp, boxes = h.surface, h.position, walled_boxes(b)
  local pf = game.forces.player
  local sp = pf and pf.get_spawn_position(s)
  local away = sp and math.atan2(hp.y - sp.y, hp.x - sp.x) or -math.pi / 2
  local spot
  for _, r in ipairs(YARD_RINGS) do
    for k = 0, YARD_ANGLES - 1 do
      local turn = math.ceil(k / 2) * (k % 2 == 1 and 1 or -1)
      local a = away + turn * 2 * math.pi / YARD_ANGLES
      local x, y = hp.x + r * math.cos(a), hp.y + r * math.sin(a)
      if not in_boxes(boxes, x, y, YARD_CLEAR) and (x - hp.x) ^ 2 + (y - hp.y - 12) ^ 2 > YARD_SPAWN * YARD_SPAWN
        and open_ground(s, x, y)
        and not s.find_nearest_enemy{position = {x, y}, max_distance = YARD_QUIET, force = h.force}
        and not truced_gun(s, x, y, h.force) then
        spot = {x, y}; break
      end
    end
    if spot then break end
  end
  -- Moved: its units sent again, to slots round the new spot.
  if not (spot and b.yard and spot[1] == b.yard[1] and spot[2] == b.yard[2]) then b.yard_dest = {} end
  b.yard, b.yard_key, b.yard_at, b.yard_boxes = spot, key, game.tick, boxes
  return spot
end

local function yard(b, trace)
  local spot = army.yard_spot(b)
  if not spot then return end
  local s = b.lander.surface
  local lp = b.lander.valid and b.lander.position
  local rail_ok = lp and (spot[1] - lp.x) ^ 2 + (spot[2] - lp.y) ^ 2 < (RAIL_LEASH - 10) ^ 2
  -- Slots kept per unit (the smallest free one for a newcomer), so a unit keeps its place as others come and go.
  b.yard_slot, b.yard_sent, b.yard_dest, b.yard_tries = b.yard_slot or {}, b.yard_sent or {}, b.yard_dest or {}, b.yard_tries or {}
  local live, used = {}, {}
  for _, u in ipairs(b.garrison) do
    if u.valid and u.unit_number then
      live[u.unit_number] = true
      if b.yard_slot[u.unit_number] then used[b.yard_slot[u.unit_number]] = true end
    end
  end
  for n in pairs(b.yard_slot) do
    if not live[n] then b.yard_slot[n], b.yard_sent[n], b.yard_dest[n], b.yard_tries[n] = nil, nil, nil, nil end
  end
  local sent, walled = 0, false
  for _, u in ipairs(b.garrison) do
    local c = u.valid and u.commandable
    local kind = c and shared.kind_of(u.name)
    if c and (u.type == "unit" or u.type == "spider-unit") and kind ~= "lp-hauler" and (kind ~= "lp-railgunner" or rail_ok)
      and (not c.has_command or (c.command and (c.command.type == defines.command.wander
        or c.command.type == defines.command.stop))) then
      local n = u.unit_number
      local k = b.yard_slot[n]
      if not k then
        k = 0
        while used[k] do k = k + 1 end
        used[k], b.yard_slot[n] = true, k
      end
      local a, r = k * 2.39996, 3 * math.sqrt(k)
      local dx, dy = r * math.cos(a), r * math.sin(a)
      -- A slot in a walled block mirrored to the spot's other side, else the spot itself (one 2 tiles out of the pad,
      -- the first spiral put its outer slots back inside: scenario idle).
      if in_boxes(b.yard_boxes, spot[1] + dx, spot[2] + dy, 2) then
        if in_boxes(b.yard_boxes, spot[1] - dx, spot[2] - dy, 2) then dx, dy = 0, 0 else dx, dy = -dx, -dy end
      end
      local x, y = spot[1] + dx, spot[2] + dy
      -- Where it was sent (its slot, or the free ground nearest it).
      local t = b.yard_dest[n]
      if t then x, y = t[1], t[2] end
      if (u.position.x - x) ^ 2 + (u.position.y - y) ^ 2 <= YARD_AT * YARD_AT then
        -- On its slot: it stands there (arrived idle, it took the default wander, 10 tiles, and buggies drifted back into
        -- the pad: scenario idle, seed 777). Not a compound of the two: the watchdog took units at rest under a compound
        -- for stuck ones.
        b.yard_tries[n] = nil
        if not (c.command and c.command.type == defines.command.stop) then
          c.set_command{type = defines.command.stop, distraction = defines.distraction.by_damage}
        end
      elseif (b.yard_tries[n] or 0) < YARD_TRIES and game.tick - (b.yard_sent[n] or -YARD_RESEND) >= YARD_RESEND
        -- Not out of a fight (an idle unit fights what it sees).
        and not s.find_nearest_enemy{position = u.position, max_distance = 24, force = u.force} then
        local p = s.find_non_colliding_position(u.name, {spot[1] + dx, spot[2] + dy}, 6, 0.5)
        p = p and {p.x, p.y} or {spot[1] + dx, spot[2] + dy}
        c.set_command{type = defines.command.go_to_location, destination = p, radius = 1,
          distraction = defines.distraction.by_damage}
        b.yard_sent[n], b.yard_dest[n], b.yard_tries[n] = game.tick, p, (b.yard_tries[n] or 0) + 1
        sent = sent + 1
        if in_boxes(b.yard_boxes, u.position.x, u.position.y) then walled = true end
      end
    end
  end
  if sent > 0 then
    b.yard_moves = (b.yard_moves or 0) + sent
    -- Out through its own gates, as units leaving on an operation are (pool.take), when one leaves a walled block: only
    -- that block's gates (not a cordon's across a rail, nor every gate each time a depot makes a unit).
    if walled and not storage.gates_off then
      b.gates_until = math.max(b.gates_until or 0, game.tick + 30 * 60)
      for _, g in ipairs(b.gate_list or {}) do
        if g.valid and in_boxes(b.yard_boxes, g.position.x, g.position.y, 1) then g.request_to_open(g.force, 15 * 60) end
      end
    end
    trace(b, string.format("yard: %d units sent to %.0f,%.0f", sent, spot[1], spot[2]))
  end
end

-- Where a unit is made: the free spot nearest `at`, by rings, with none of its own walls within SPAWN_CLEAR. The first
-- free spot by the depot (find_non_colliding_position) was inside the walled scrap cannon emplacement five tiles south
-- of a Grubstake depot, and a forced raid's shotgun hands were made in it and could not leave (trailer visit save,
-- minute 38; scenario idle LP_MIX=pillbox). Nothing clear within radius: the free spot nearest, as before.
local SPAWN_CLEAR = 3.5
function army.open_spot(b, p)
  local s = game.surfaces[b.surface]
  return s.count_entities_filtered{position = p, radius = SPAWN_CLEAR, type = {"wall", "gate"}, force = b.force,
    limit = 1} == 0
end
function army.spawn_point(b, proto, at, radius)
  local s = game.surfaces[b.surface]
  local x0, y0 = at.x or at[1], at.y or at[2]
  for r = 0, radius, 2 do
    local steps = math.max(1, math.floor(2 * math.pi * r / 3))
    for k = 0, steps - 1 do
      local a = math.pi / 2 + 2 * math.pi * k / steps
      local p = s.find_non_colliding_position(proto, {x0 + r * math.cos(a), y0 + r * math.sin(a)}, 1.5, 0.5)
      if p and army.open_spot(b, p) then return p end
    end
  end
  return s.find_non_colliding_position(proto, {x0, y0}, radius, 0.5)
end

-- Its own gates open for its own units (no gate opens for a unit by itself): Serenity's camps put a gate in every
-- opening of every walled block, and on nw its raiders stood at the lander behind 29 to 107 pieces of its own wall, raid
-- after raid, for three hours. Once a second, each gate with one of its units within GATE_REACH is asked open.
local GATE_REACH = 5
local function gates(b, tick)
  if tick % 600 == 31 or not b.gate_list then
    b.gate_list = {}
    if b.lander and b.lander.valid then
      b.gate_list = b.lander.surface.find_entities_filtered{position = b.lander.position, radius = (b.claim_radius or 150) + 60,
        type = "gate", force = b.lander.force}
    end
  end
  -- Only while the camp has units out or leaving (an operation, units on their way back, a departure in the last two
  -- minutes): its idle garrison by a gate held it open 3,460 times in six minutes, and an open gate is open to the
  -- player too. Opened only for units under orders, a raid stayed in: a unit plans its path when ordered, gates shut.
  local busy = b.op or (b.returning and #b.returning > 0) or game.tick < (b.gates_until or 0)
  if not busy then return end
  for _, g in ipairs(b.gate_list) do
    if g.valid and g.surface.count_entities_filtered{position = g.position, radius = GATE_REACH, force = g.force,
      type = {"unit", "spider-unit"}, limit = 1} > 0 then
      g.request_to_open(g.force, 90)
      b.gate_opens = (b.gate_opens or 0) + 1
    end
  end
end

-- Railgunners out of the engine's groups. Shelled, a force's units near the impact are formed by the engine into a group
-- sent at the battery, whatever the planner does (scenario artyreply: all 6 railgunners and 5 troopers sent 225 tiles at
-- the turret; the prototype's ai_settings.join_attacks = false changed nothing). On nwa Kessler-Hayashi's railgunners so
-- went 545 tiles to the battery shelling its camp and broke 232 of the player's buildings from beyond its guns' reach,
-- where its sieges no longer take them (siege_tier, 0.2.165; 2026-11-06). So a railgunner the engine adds to a group (one
-- not script-driven: every group the mod makes is) is taken out of it, and so is any unit on one of its operations,
-- stopped where it is for its operation to order again at its next look. An idle unit keeps the engine's answer: it is
-- the camp's only answer to a battery its planner does not raid (0.2.220 took them all out: farm artillery's battery
-- stood, its camp's 7 units no longer went and razed nothing; dome dark's lander fell to one turret; rivals' Grubstake
-- grew a third less).
local function on_operation(u)
  local n = u.unit_number
  for _, b in pairs(storage.bases or {}) do
    if b.force == u.force.name then
      for _, m in ipairs(b.op and b.op.members or {}) do if m.valid and m.unit_number == n then return true end end
      for _, r in ipairs(b.raids or {}) do
        for _, m in ipairs(r.members or {}) do if m.valid and m.unit_number == n then return true end end
      end
    end
  end
  return false
end

function army.on_unit_added_to_group(e)
  local u, g = e.unit, e.group
  if not (u and u.valid and shared.is_corp(u.force.name)) then return end
  if g and g.valid and g.is_script_driven then return end
  storage.engine_grouped = (storage.engine_grouped or 0) + 1
  local rail = shared.kind_of(u.name) == "lp-railgunner"
  local busy = on_operation(u)
  if not (rail or busy) then return end
  storage.engine_ungrouped = (storage.engine_ungrouped or 0) + 1
  if rail then storage.rails_ungrouped = (storage.rails_ungrouped or 0) + 1 end
  if busy then
    u.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.by_enemy}
    return
  end
  local home, hd
  for _, b in pairs(storage.bases or {}) do
    if b.force == u.force.name and not b.fallen and b.lander and b.lander.valid and b.surface == u.surface.index then
      local d = (b.lander.position.x - u.position.x) ^ 2 + (b.lander.position.y - u.position.y) ^ 2
      if not hd or d < hd then home, hd = b.lander, d end
    end
  end
  if home then
    u.commandable.set_command{type = defines.command.go_to_location, destination = home.position, radius = 16,
      distraction = defines.distraction.by_damage}
  else
    u.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.by_damage}
  end
end

function army.tick(b, tick, trace)
  if tick % 60 == 31 and not storage.gates_off then gates(b, tick) end
  if b.grudge and not b.grudge_till and #b.depots > 0 then
    b.grudge_till = tick + (storage.grudge_fast and 2 * 3600 or army.GRUDGE_TICKS)
  end
  if tick % 600 == 300 then intercept(b, trace) end
  if tick % 60 == 45 then travel(b, trace) end
  if tick % 300 == 0 then settle(b, trace) end
  if tick % 300 == 75 then pool.tick(b) end
  -- Raids are operations now (scripts/ops.lua): chosen from intel, sized, staged, aborted when losing.
  ops.tick(b, tick, trace, army)
  if tick % 300 == 150 and not storage.army_off then patrol(b, trace) end
  if tick % 300 == 250 and not storage.army_off then leash(b, trace) end
  if tick % 300 == 270 and not storage.army_off and not storage.yard_off then yard(b, trace) end
  if tick % BUILD_TICKS == 0 then produce(b, trace) end
end

-- A fallen settlement's units: the garrison, patrols, raids and convoys go to the nearest standing
-- settlement with a depot within EVACUATE_RANGE and join its garrison (cargo is lost); with none, they stay
-- among the ruins and fight what comes.
local EVACUATE_RANGE = 1500
function army.disband(b, trace)
  local units = {}
  for _, u in ipairs(b.garrison or {}) do table.insert(units, u) end
  for _, u in ipairs(b.patrol or {}) do table.insert(units, u) end
  for _, r in ipairs(b.raids or {}) do
    for _, u in ipairs(r.members) do table.insert(units, u) end
    if r.group.valid then r.group.destroy() end
  end
  for _, c in ipairs(b.convoys or {}) do
    for _, u in ipairs(c.escorts) do table.insert(units, u) end
    if c.hauler.valid then table.insert(units, c.hauler) end
  end
  -- And every other unit it owns (its roster, pool.lua): an operation's (a siege's guards wander at their site) and those
  -- on their way home were left behind; one wandering by its outposts held them, and they could never be taken (fall).
  local seen = {}
  for _, u in ipairs(units) do if u.valid and u.unit_number then seen[u.unit_number] = true end end
  for _, u in pairs(b.roster or {}) do
    if u.valid and u.unit_number and not seen[u.unit_number] then seen[u.unit_number] = true; table.insert(units, u) end
  end
  b.garrison, b.patrol, b.raids, b.convoys, b.returning = {}, {}, {}, {}, {}
  local from = b.lander.valid and b.lander.position or (b.origin and {x = b.origin.x, y = b.origin.y})
  local dest, dd
  for _, o in pairs(storage.bases) do
    -- Its own corporation's only (evacuees joined a rival's garrison once, and its next response crashed
    -- putting them in a squad of another force).
    if o ~= b and o.corp == b.corp and o.lander.valid and o.depots[1] and o.depots[1].valid then
      local d = math.sqrt((o.lander.position.x - from.x) ^ 2 + (o.lander.position.y - from.y) ^ 2)
      if d <= EVACUATE_RANGE and (not dd or d < dd) then dest, dd = o, d end
    end
  end
  local n = 0
  for _, u in ipairs(units) do
    if u.valid then
      n = n + 1
      if dest then
        pool.enlist(dest, u)
        table.insert(dest.garrison, u)
        u.commandable.set_command{type = defines.command.go_to_location, destination = dest.depots[1].position,
          radius = 8, distraction = defines.distraction.by_enemy}
      else
        u.commandable.set_command{type = defines.command.wander, radius = 20, distraction = defines.distraction.by_anything}
      end
    end
  end
  trace(b, dest and string.format("%d units evacuate to settlement %d, %.0f tiles", n, dest.id, dd)
    or string.format("%d units stay among the ruins", n))
  return n, dest
end


return army
