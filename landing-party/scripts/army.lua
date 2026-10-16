-- The army: depots build units from parts up to a garrison cap, in the mix the doctrine prefers. Raids are
-- operations (scripts/ops.lua); this module answers alarms, patrols, escorts convoys and intercepts trains.
local shared = require("__landing-party__.shared")
local rng = require("__landing-party__.scripts.rng")
local ops = require("__landing-party__.scripts.ops")
local rd = require("__landing-party__.scripts.rd")

local army = {}

local BUILD_TICKS = 600          -- a depot turns out at most one unit per 10 s
local CAP_PER_DEPOT = 10
local HOME_GUARD = 2             -- units that stay home

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
  -- The ladder buys capacity (Fable's pressure-ramp consult, item 4): from its second rung against a player, half as many
  -- again (b.war_rung, war.lua). It had only lowered the price of using what the settlement had.
  if (b.war_rung or 0) >= 2 then n = math.floor(n * 1.5) end
  return (b.grudge_till and game.tick < b.grudge_till) and 2 * n or n
end
army.cap = cap
local function strength(b) return #b.garrison + #(b.patrol or {}) end

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
      storage.unit_owner[u.unit_number] = b.id
      made = made + 1
    end
  end
  b.escort = (b.escort or 0) + made
  return made
end

-- One unit from the first depot with room, if parts allow; the doctrine weighs which.
local function withdrawing(b) return storage.corps and storage.corps[b.corp] and storage.corps[b.corp].withdrawing end
army.withdrawing = withdrawing
local function produce(b, trace)
  if storage.army_off or withdrawing(b) then return end
  prune(b.garrison)
  if strength(b) >= cap(b) then return end
  -- A rebuild that makes parts is paid first (base.reserve; scenario occupy).
  local name = b.next_unit or rng.weighted(b.rng, mix(b))
  -- A clearance waiting for railgunners (ops.clearance) gets them first.
  if b.want_rails and not b.next_unit and shared.units["lp-railgunner"] and (mix(b)["lp-railgunner"] or 0) > 0 then
    name = "lp-railgunner"
  end
  b.next_unit = name
  local cost = shared.units[name].cost
  if b.parts < cost + (army.reserve and army.reserve(b) or 0) then return end
  local yards = {}
  for _, d in ipairs(b.depots) do if d.valid then table.insert(yards, d) end end
  if #yards == 0 and b.lander and b.lander.valid then yards = {b.lander} end
  for _, depot in ipairs(yards) do
    if depot.valid then
      local surface = depot.surface
      local proto = rd.unit(b.corp, name)
      local p = surface.find_non_colliding_position(proto, {depot.position.x, depot.position.y + 4}, 12, 0.5)
      local u = p and surface.create_entity{name = proto, position = p, force = depot.force}
      if u then
        b.parts = b.parts - cost
        b.next_unit = nil
        b.units_built = b.units_built + 1
        b.built_by = b.built_by or {}
        b.built_by[name] = (b.built_by[name] or 0) + 1
        table.insert(b.garrison, u)
        storage.unit_owner[u.unit_number] = b.id
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
  -- Against biters alone, its railgunners first (the biter-clearing unit).
  if biters_only then
    for i = #b.garrison, HOME_GUARD + 1, -1 do
      local u = b.garrison[i]
      if #members < size and u.valid and shared.kind_of(u.name) == "lp-railgunner" then
        table.remove(b.garrison, i)
        group.add_member(u)
        table.insert(members, u)
      end
    end
  end
  for i = #b.garrison, HOME_GUARD + 1, -1 do
    if #members >= size then break end
    local u = table.remove(b.garrison, i)
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
          table.insert(b.garrison, u)
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
  while #b.patrol < want and #b.garrison > HOME_GUARD do table.insert(b.patrol, table.remove(b.garrison)) end
  if #b.patrol == 0 then return end
  -- A route of up to five stops, drawn once and redrawn when the settlement changes much.
  local pts = waypoints(b)
  if #pts < 2 then return end
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
    if not u.commandable.has_command then
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

function army.convoy(b, cargo, trace)
  local dest = uplink_settlement(b)
  if not dest or dest == b then return false end
  local surface = b.lander.surface
  local home = (b.depots[1] and b.depots[1].valid and b.depots[1]) or b.lander
  -- Form up outside the settlement, on the side facing the uplink: past its outermost wall or gate on that line (gates open
  -- for no unit). Formed 25 to 45 tiles out, a nine-block bastion's haulers were made inside a walled fab compound and
  -- never left: 68 sent, none delivered (visit deathworld10x). Beside a walled depot, escorts stalled (seed 4242).
  local hx, hy = home.position.x, home.position.y
  local ux, uy = dest.uplink.position.x - hx, dest.uplink.position.y - hy
  local ul = math.max(1, math.sqrt(ux * ux + uy * uy))
  -- Its own walls only: walked the whole way, the uplink's (the same force) set the hauler down beside it, delivered in 0 s.
  local out = 25
  for d = 0, ul / 2, 2 do
    if surface.count_entities_filtered{position = {hx + ux / ul * d, hy + uy / ul * d}, radius = 2.5, force = home.force,
      type = {"wall", "gate"}, limit = 1} > 0 then out = math.max(out, d + 5) end
  end
  out = math.min(out, ul)
  local p = surface.find_non_colliding_position(shared.variant(b.corp, "lp-hauler"), {hx + ux / ul * out, hy + uy / ul * out},
    20, 0.5)
  local hauler = p and surface.create_entity{name = shared.variant(b.corp, "lp-hauler"), position = p, force = home.force}
  if not hauler then return false end
  local escorts = {}
  prune(b.garrison)
  -- Escorts from units at home only: the last convoy's escorts, back in the garrison but still at the
  -- uplink's gate 210 tiles away, were drafted at once and the group waited for them.
  for i = #b.garrison, HOME_GUARD + 1, -1 do
    if #escorts >= CONVOY_ESCORT then break end
    local u = b.garrison[i]
    if u.type == "unit" and (u.position.x - home.position.x) ^ 2 + (u.position.y - home.position.y) ^ 2 < 30 * 30 then
      table.insert(escorts, table.remove(b.garrison, i))
    end
  end
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
        table.insert(b.garrison, e)
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

-- How far the escorts are from their hauler (the largest distance), for the convoy scenario.
function army.convoy_spread(b)
  local worst = 0
  for _, c in ipairs(b.convoys or {}) do
    -- Once formed (before, escorts are still walking in).
    if c.hauler.valid and c.formed then
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
          table.insert(b.garrison, e)
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
    if other ~= f and other.name ~= "enemy" and other.name ~= "neutral" and not f.get_cease_fire(other) then
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
  for i = #b.garrison, HOME_GUARD + 1, -1 do
    if #members >= INTERCEPT_SIZE then break end
    local u = table.remove(b.garrison, i)
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
local LEASH = 15
local function leash(b)
  local h = b.depots[1] and b.depots[1].valid and b.depots[1] or (b.lander.valid and b.lander)
  if not h then return end
  local hp = h.position
  local r = (b.claim_radius or 60) + LEASH
  for _, u in ipairs(b.garrison) do
    -- Idle ones only: re-ordered straight home, raiders coming back round a nest field walked through it (country).
    if u.valid and not u.commandable.has_command
      and (u.position.x - b.origin.x) ^ 2 + (u.position.y - b.origin.y) ^ 2 > r * r then
      u.commandable.set_command{type = defines.command.go_to_location, destination = hp, radius = 10,
        distraction = defines.distraction.by_damage}
    end
  end
end

function army.tick(b, tick, trace)
  if b.grudge and not b.grudge_till and #b.depots > 0 then
    b.grudge_till = tick + (storage.grudge_fast and 2 * 3600 or army.GRUDGE_TICKS)
  end
  if tick % 600 == 300 then intercept(b, trace) end
  if tick % 60 == 45 then travel(b, trace) end
  if tick % 300 == 0 then settle(b, trace) end
  -- Raids are operations now (scripts/ops.lua): chosen from intel, sized, staged, aborted when losing.
  ops.tick(b, tick, trace, army)
  if tick % 300 == 150 and not storage.army_off then patrol(b, trace) end
  if tick % 300 == 250 and not storage.army_off then leash(b) end
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
  b.garrison, b.patrol, b.raids, b.convoys = {}, {}, {}, {}
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
        storage.unit_owner[u.unit_number] = dest.id
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

army.UNITS = {"lp-infantry", "lp-tank", "lp-walker", "lp-harrier"}

return army
