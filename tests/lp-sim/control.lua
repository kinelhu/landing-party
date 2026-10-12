-- Headless simulation: lands one base near spawn, lets it grow, plays a scripted player action at
-- params.strike minutes, snapshots the base and checks what should follow.
-- params.lua (written by scripts/sim.sh into this mod's copy in the run's profile) gives
-- scenario, minutes, every (snapshot interval, minutes), strike (minutes), x, y, radius.
--   grow     nothing happens to the base
--   cut      every pylon on a line between modules dies: income falls, then the lines are rebuilt
--   raid     every fabricator dies: they are rebuilt and parts production recovers
--   occupy   the fabricators and the turrets within 40 tiles die, a player turret stands by each spot:
--            nothing is rebuilt there until the turrets are removed (at strike + hold)
local params = require("params")
local END = params.minutes * 3600
local STRIKE = (params.strike or 20) * 3600
local HOLD = 10 * 3600
local OUT = "landing-party/sim.jsonl"
local lp = function(fn, ...) return remote.call("landing-party", fn, ...) end
local FORCE = "landing-party"

local lines, failed = {}, 0
local function check(name, ok, detail)
  if not ok then failed = failed + 1 end
  table.insert(lines, (ok and "PASS " or "FAIL ") .. name .. "  " .. tostring(detail or ""))
end
local function info(text) table.insert(lines, "INFO " .. text) end
local function metric(name, value) table.insert(lines, "METRIC " .. name .. " " .. tostring(value)) end

-- One handler per tick: the scenario's schedule is a table of tick -> function.
local at = {}
local function schedule(tick, f)
  if at[tick] then local g = at[tick]; at[tick] = function() g(); f() end else at[tick] = f end
end

local function surface() return game.surfaces[1] end
local function lp_entities(name, area)
  return surface().find_entities_filtered{name = name, force = FORCE, area = area}
end

-- Pylons with no other faction entity near them: the lines between modules.
local function line_pylons()
  local out = {}
  for _, p in pairs(lp_entities("lp-pylon")) do
    local near = surface().find_entities_filtered{position = p.position, radius = 6, force = FORCE}
    local alone = true
    for _, e in pairs(near) do if e.name ~= "lp-pylon" then alone = false; break end end
    if alone then table.insert(out, p) end
  end
  return out
end

local S = {}  -- scenario state (the run never saves, so plain locals are enough)

-- Rates over a window from the cumulative counters: the smoothed rates in stats alias against crafting
-- cycles (a raid on seed 4242 read 95.7 -> 83.7 parts/min with the same four fabricators all working).
local WINDOW = 5 * 3600
local function counter(name) return lp("stats", storage.id)[name] end
local function window_rate(name, at, into)
  schedule(at - WINDOW, function() S[into .. "_from"] = counter(name) end)
  schedule(at, function() S[into] = (counter(name) - S[into .. "_from"]) / (WINDOW / 3600) end)
end

-- Outpost pylons: those beside an ore bin. A compact settlement has no lines, only these (seed 4242).
local function outpost_pylons()
  local out = {}
  for _, bin in pairs(lp_entities("lp-bin")) do
    for _, p in pairs(surface().find_entities_filtered{name = "lp-pylon", force = FORCE, position = bin.position,
      radius = 4}) do out[p.unit_number] = p end
  end
  local list = {}
  for _, p in pairs(out) do table.insert(list, p) end
  return list
end

local scenarios = {}

scenarios.grow = function() end

-- Engine probe: are chunks forced in on_init complete (resources placed)? Counts the same points later.
scenarios.probe = function()
  schedule(600, function()
    for i = 0, 7 do
      local a = 2 * math.pi * i / 8
      local p = {300 * math.cos(a), 300 * math.sin(a)}
      local n = surface().count_entities_filtered{position = p, radius = 60, type = "resource"}
      local trees = surface().count_entities_filtered{position = p, radius = 60, type = "tree"}
      table.insert(lines, string.format("INFO probe %.0f,%.0f: %d resources, %d trees, chunk %s", p[1], p[2], n, trees,
        tostring(surface().is_chunk_generated({math.floor(p[1] / 32), math.floor(p[2] / 32)}))))
    end
  end)
end

scenarios.cut = function()
  window_rate("mined", STRIKE, "before")
  window_rate("mined", END, "after")
  schedule(STRIKE, function()
    S.mined_at_strike = counter("mined")
    local victims = line_pylons()
    -- No lines (a compact settlement): cut the outposts off instead.
    if #victims == 0 then victims = outpost_pylons() end
    S.killed = #victims
    for _, p in pairs(victims) do p.die("player") end
    check("cut: there was something to cut", S.killed > 0, S.killed .. " pylons")
  end)
  schedule(STRIKE + 3600, function()
    local during = counter("mined") - S.mined_at_strike
    check("cut: income fell", during < 0.9 * S.before, string.format("%.0f -> %.0f/min", S.before, during))
  end)
  schedule(END, function()
    local st = lp("stats", storage.id)
    check("cut: rebuilt", st.rebuilt >= S.killed, st.rebuilt .. "/" .. S.killed)
    check("cut: income recovered", S.after >= 0.9 * S.before, string.format("%.0f -> %.0f/min", S.before, S.after))
  end)
end

scenarios.raid = function()
  window_rate("made", STRIKE, "before")
  window_rate("made", END, "after")
  schedule(STRIKE, function()
    S.fabs = lp("stats", storage.id).fabs
    for _, f in pairs(lp_entities("lp-fabricator")) do f.die("player") end
    check("raid: fabricators destroyed", lp("stats", storage.id).fabs == 0, S.fabs)
  end)
  schedule(END, function()
    local st = lp("stats", storage.id)
    check("raid: fabricators rebuilt", st.fabs >= S.fabs, st.fabs .. "/" .. S.fabs)
    -- Rebuilt, not duplicated: the planner counts what it owes (a few new ones for new mines are fine).
    check("raid: not duplicated", st.fabs <= S.fabs + 3, st.fabs .. " for " .. S.fabs)
    check("raid: parts production recovered", S.after >= 0.9 * S.before,
      string.format("%.1f -> %.1f/min", S.before, S.after))
  end)
end

-- The mechanic alone: holders are made indestructible so the faction's turrets cannot clear them
-- (a fought-over occupation is a combat scenario of its own).
scenarios.occupy = function()
  schedule(STRIKE, function()
    local fabs = lp_entities("lp-fabricator")
    S.fabs = #fabs
    S.spots = {}
    local dead = {}
    for _, f in pairs(fabs) do
      for _, t in pairs(surface().find_entities_filtered{name = "lp-turret", force = FORCE, position = f.position,
        radius = 40}) do
        if not dead[t.unit_number] then dead[t.unit_number] = true; table.insert(S.spots, {t.position.x, t.position.y}); t.die("player") end
      end
      table.insert(S.spots, {f.position.x, f.position.y}); f.die("player")
    end
    -- A player turret beside every lost spot.
    S.holders = {}
    for _, p in ipairs(S.spots) do
      local pos = surface().find_non_colliding_position("gun-turret", {p[1] + 2, p[2] + 2}, 6, 1)
      local t = pos and surface().create_entity{name = "gun-turret", position = pos, force = "player"}
      if t then t.destructible = false; table.insert(S.holders, t) end
    end
    check("occupy: every spot held", #S.holders == #S.spots, #S.holders .. "/" .. #S.spots)
  end)
  schedule(STRIKE + HOLD, function()
    local rebuilt = 0
    for _, p in ipairs(S.spots) do
      rebuilt = rebuilt + surface().count_entities_filtered{position = p, radius = 1, force = FORCE}
    end
    check("occupy: nothing rebuilt on held ground", rebuilt == 0, rebuilt .. " rebuilt")
    for _, t in pairs(S.holders) do if t.valid then t.destroy() end end
  end)
  schedule(END, function()
    local st = lp("stats", storage.id)
    check("occupy: rebuilt once the ground was free", st.fabs >= S.fabs, st.fabs .. "/" .. S.fabs)
    check("occupy: not duplicated", st.fabs <= S.fabs + 3, st.fabs .. " for " .. S.fabs)
  end)
end

-- ---------------------------------------------------------------------------------------------------
-- Unit spikes. A flat test range near spawn: grass, nothing on it, so lanes differ only in what is tested.
local function flatten(x0, y0, x1, y1)
  local tiles = {}
  for x = x0, x1 - 1 do for y = y0, y1 - 1 do table.insert(tiles, {name = "grass-1", position = {x, y}}) end end
  surface().set_tiles(tiles, true, true, true, false)
  for _, e in pairs(surface().find_entities_filtered{area = {{x0, y0}, {x1, y1}}}) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

local function spawn(name, pos, n, force)
  local out = {}
  for k = 1, n do
    local p = surface().find_non_colliding_position(name, {pos[1], pos[2] + (k - (n + 1) / 2) * 1.5}, 6, 0.5)
    local u = p and surface().create_entity{name = name, position = p, force = force or FORCE}
    if u then table.insert(out, u) end
  end
  return out
end

local function go(units, dest)
  for _, u in ipairs(units) do
    u.commandable.set_command{type = defines.command.go_to_location, destination = dest, radius = 2,
      distraction = defines.distraction.none}
  end
end

-- Damage taken by a set of units (the dead count their full health).
local function harm(units, max)
  local d = 0
  for _, u in ipairs(units) do d = d + (u.valid and (max - u.health) or max) end
  return d
end
local function name_of(defs, v)
  for k, x in pairs(defs) do if x == v then return k end end
  return tostring(v)
end
local function inside(units, c, half)
  local n = 0
  for _, u in ipairs(units) do
    if u.valid and math.abs(u.position.x - c[1]) < half and math.abs(u.position.y - c[2]) < half then n = n + 1 end
  end
  return n
end
local function near(units, pos, r)
  local n = 0
  for _, u in ipairs(units) do
    if u.valid and (u.position.x - pos[1]) ^ 2 + (u.position.y - pos[2]) ^ 2 <= r * r then n = n + 1 end
  end
  return n
end

-- Air: harriers against walls, mines, a flamethrower and a gun turret, beside infantry as the control.
scenarios.air = function()
  local L = {}
  local function lane(name, y) L[name] = {y = y, from = {-60, y}, to = {40, y}} end
  lane("wall_h", -60); lane("wall_i", -40); lane("mine_h", -20); lane("mine_i", 0)
  lane("flame_h", 60); lane("flame_i", 120); lane("gun_h", 180); lane("gun_i", 240)
  schedule(60, function()
    flatten(-80, -80, 70, 270)
    for _, k in ipairs({"wall_h", "wall_i"}) do
      local t = L[k].to
      for x = -6, 6 do for y = -6, 6 do
        if math.abs(x) == 6 or math.abs(y) == 6 then
          surface().create_entity{name = "stone-wall", position = {t[1] + x, t[2] + y}, force = "player"}
        end
      end end
    end
    for _, k in ipairs({"mine_h", "mine_i"}) do
      L[k].mines = {}
      for x = -12, -8 do for y = -4, 4 do
        table.insert(L[k].mines, surface().create_entity{name = "land-mine", position = {x, L[k].y + y}, force = "player"})
      end end
    end
    for _, k in ipairs({"flame_h", "flame_i"}) do
      -- Facing the lane: a flamethrower only fires within an arc in front of it.
      local t = surface().create_entity{name = "flamethrower-turret", position = {-10, L[k].y + 8}, force = "player",
        direction = defines.direction.north}
      t.insert_fluid{name = "light-oil", amount = 100}
      L[k].turret = t
    end
    for _, k in ipairs({"gun_h", "gun_i"}) do
      local t = surface().create_entity{name = "gun-turret", position = {-10, L[k].y + 8}, force = "player"}
      t.insert{name = "firearm-magazine", count = 200}
      L[k].turret = t
    end
  end)
  schedule(400, function()  -- mines arm after 120 ticks
    S.results = {}
    for k, l in pairs(L) do
      local unit = k:sub(-1) == "h" and "lp-harrier" or "lp-infantry"
      l.units = spawn(unit, l.from, 3)
      l.max = prototypes.entity[unit].get_max_health()
      go(l.units, l.to)
    end
  end)
  schedule(400 + 1800, function()
    for _, k in ipairs({"flame_h", "flame_i"}) do
      local t = L[k].turret
      info(string.format("%s turret fluid %s", k, t.valid and tostring(t.get_fluid_count()) or "dead"))
    end
    -- Ground units shoot through what blocks their path (the engine's obstacle attack): infantry gets in
    -- only by breaching. Harriers fly over with every wall standing.
    local function walls(t) return surface().count_entities_filtered{name = "stone-wall", force = "player",
      area = {{t[1] - 7, t[2] - 7}, {t[1] + 7, t[2] + 7}}} end
    check("air: harriers cross a closed wall box, walls intact",
      inside(L.wall_h.units, L.wall_h.to, 6) >= 2 and walls(L.wall_h.to) == 48,
      inside(L.wall_h.units, L.wall_h.to, 6) .. "/" .. #L.wall_h.units .. " inside, " .. walls(L.wall_h.to) .. "/48 walls")
    check("air: infantry gets in only through a breach", inside(L.wall_i.units, L.wall_i.to, 6) == 0 or walls(L.wall_i.to) < 48,
      inside(L.wall_i.units, L.wall_i.to, 6) .. " inside, " .. walls(L.wall_i.to) .. "/48 walls")
    local function left(m) local n = 0 for _, e in ipairs(m) do if e.valid then n = n + 1 end end return n end
    check("air: harriers do not set off mines", left(L.mine_h.mines) == #L.mine_h.mines,
      left(L.mine_h.mines) .. "/" .. #L.mine_h.mines .. " mines left; harm " .. harm(L.mine_h.units, L.mine_h.max))
    check("air: infantry does", left(L.mine_i.mines) < #L.mine_i.mines,
      left(L.mine_i.mines) .. "/" .. #L.mine_i.mines .. " mines left; harm " .. harm(L.mine_i.units, L.mine_i.max))
    check("air: the flamethrower ignores harriers", harm(L.flame_h.units, L.flame_h.max) == 0,
      "harm " .. harm(L.flame_h.units, L.flame_h.max))
    check("air: the flamethrower burns infantry", harm(L.flame_i.units, L.flame_i.max) > 0,
      "harm " .. harm(L.flame_i.units, L.flame_i.max))
    check("air: gun turrets hit harriers", harm(L.gun_h.units, L.gun_h.max) > 0, "harm " .. harm(L.gun_h.units, L.gun_h.max))
    check("air: and infantry", harm(L.gun_i.units, L.gun_i.max) > 0, "harm " .. harm(L.gun_i.units, L.gun_i.max))
    local walls = surface().count_entities_filtered{name = "stone-wall", force = "player"}
    info("walls standing: " .. walls .. " of " .. 2 * 48)
    for k, l in pairs(L) do
      local arrived = near(l.units, l.to, 4)
      local xs, res = {}, {}
      for _, u in ipairs(l.units) do
        if u.valid then
          table.insert(xs, string.format("%.0f,%.0f", u.position.x, u.position.y))
          local r = S.results[u.unit_number]
          table.insert(res, r and name_of(defines.behavior_result, r) or "-")
        end
      end
      info(string.format("%s: %d units, %d at the target, harm %d, at %s, results %s", k, #l.units, arrived,
        harm(l.units, l.max), table.concat(xs, " "), table.concat(res, ",")))
    end
  end)
end

-- Path: a group of 25 infantry and 10 single units cross a 30-minute settlement to its farthest outpost.
scenarios.path = function()
  schedule(STRIKE, function()
    local st = lp("stats", storage.id)
    local lander = surface().find_entities_filtered{name = "lp-lander", force = FORCE}[1]
    local far, fd
    for _, bin in pairs(lp_entities("lp-bin")) do
      local d = (bin.position.x - lander.position.x) ^ 2 + (bin.position.y - lander.position.y) ^ 2
      if not fd or d > fd then far, fd = bin, d end
    end
    -- Open ground beyond the outpost: room for 25 to stand (a spot beside the drills held only singles).
    local open = surface().find_non_colliding_position("lp-lander", {far.position.x + 12, far.position.y + 12}, 40, 1)
    S.dest = open and {open.x, open.y} or {far.position.x + 12, far.position.y + 12}
    S.dist = math.sqrt(fd)
    local start = {lander.position.x, lander.position.y + 12}
    S.group_units = spawn("lp-infantry", start, 25)
    S.group = surface().create_unit_group{position = start, force = FORCE}
    for _, u in ipairs(S.group_units) do S.group.add_member(u) end
    S.group.set_command{type = defines.command.go_to_location, destination = S.dest, radius = 8,
      distraction = defines.distraction.none}
    S.singles = spawn("lp-infantry", {start[1] + 6, start[2]}, 10)
    go(S.singles, S.dest)
    S.results = {}
    info(string.format("path: %d in the group, %d single, %.0f tiles to %s (%s, %d blocks)", #S.group_units,
      #S.singles, S.dist, serpent.line(S.dest), st.doctrine, st.blocks))
  end)
  for m = 1, 5 do
    schedule(STRIKE + m * 3600, function()
      local g = S.group.valid and S.group or nil
      info(string.format("path +%d min: group %d/%d arrived, singles %d/%d arrived; group %s, state %s, %d members, at %s",
        m, near(S.group_units, S.dest, 15), #S.group_units, near(S.singles, S.dest, 15), #S.singles,
        g and "valid" or "gone", g and name_of(defines.group_state, g.state) or "-", g and #g.members or 0,
        g and string.format("%.0f,%.0f", g.position.x, g.position.y) or "-"))
      local ds = {}
      for _, u in ipairs(S.group_units) do
        if u.valid then table.insert(ds, math.floor(math.sqrt((u.position.x - S.dest[1]) ^ 2 + (u.position.y - S.dest[2]) ^ 2))) end
      end
      table.sort(ds)
      info("  member distances to the destination: " .. table.concat(ds, " "))
    end)
  end
  schedule(STRIKE + 5 * 3600, function()
    local fails = 0
    for _, r in pairs(S.results) do if r ~= defines.behavior_result.success then fails = fails + 1 end end
    -- A group of 25 stands as a blob 10-30 tiles across round its destination (seed 12345: every member
    -- within 30 a minute in, the group "finished"); a 15-tile radius read that as a stall.
    check("path: the group arrives", near(S.group_units, S.dest, 32) >= 0.8 * #S.group_units,
      near(S.group_units, S.dest, 32) .. "/" .. #S.group_units)
    check("path: single units arrive", near(S.singles, S.dest, 15) >= 0.8 * #S.singles,
      near(S.singles, S.dest, 15) .. "/" .. #S.singles .. ", " .. fails .. " commands failed")
  end)
end

-- Cost: params.units infantry, idle or wandering (params.move), far from everything.
scenarios.cost = function()
  schedule(600, function()
    flatten(-150, -150, -50, -50)
    S.units = {}
    local n = params.units or 0
    local side = math.ceil(math.sqrt(n))
    for k = 0, n - 1 do
      local u = surface().create_entity{name = "lp-infantry", force = FORCE,
        position = {-145 + (k % side) * 90 / side, -145 + math.floor(k / side) * 90 / side}}
      if u then
        table.insert(S.units, u)
        if params.move then
          u.commandable.set_command{type = defines.command.wander, radius = 30, distraction = defines.distraction.none}
        end
      end
    end
    info("cost: " .. #S.units .. " units, " .. (params.move and "wandering" or "idle"))
  end)
end

-- Assault: a walled player outpost 150 tiles from the lander towards spawn, four gun turrets, machines
-- inside. The player is armed as at a first rocket launch, when the faction arrives: piercing rounds and
-- several levels of physical damage and shooting speed research (yellow ammo and no research made any
-- raid a walkover). The settlement must build a depot and a garrison, and raid it.
scenarios.assault = function()
  if params.fast then
    schedule(200, function() lp("debug_depot", storage.id, 3000) end)
  end
  schedule(120, function()
    local lander = surface().find_entities_filtered{name = "lp-lander", force = FORCE}[1]
    local lx, ly = lander.position.x, lander.position.y
    local len = math.sqrt(lx * lx + ly * ly)
    local c = {math.floor(lx - lx / len * 150), math.floor(ly - ly / len * 150)}
    flatten(c[1] - 20, c[2] - 20, c[1] + 20, c[2] + 20)
    local pf = game.forces.player
    pf.set_ammo_damage_modifier("bullet", 0.8)
    pf.set_gun_speed_modifier("bullet", 0.6)
    S.outpost = {}
    local function put(name, x, y, extra)
      local e = surface().create_entity{name = name, position = {c[1] + x, c[2] + y}, force = "player"}
      if e then table.insert(S.outpost, e); if extra then extra(e) end end
      return e
    end
    for x = -12, 12 do for y = -12, 12 do
      if math.abs(x) == 12 or math.abs(y) == 12 then put("stone-wall", x, y) end
    end end
    for _, p in ipairs({{-9, -9}, {9, -9}, {-9, 9}, {9, 9}}) do
      put("gun-turret", p[1], p[2], function(e) e.insert{name = "piercing-rounds-magazine", count = 100} end)
    end
    for _, p in ipairs({{-3, -3}, {3, -3}, {-3, 3}, {3, 3}}) do put("assembling-machine-1", p[1] + 0.5, p[2] + 0.5) end
    for _, p in ipairs({{0, -7}, {0, 7}, {-7, 0}, {7, 0}}) do put("iron-chest", p[1] + 0.5, p[2] + 0.5) end
    S.center = c
    S.count = #S.outpost
    S.frames = 0
    info(string.format("assault: outpost of %d entities at %d,%d", S.count, c[1], c[2]))
  end)
  -- Replay: while any faction unit is within 120 tiles of the outpost, every 2 s, one JSON line of the
  -- units, the outpost and the faction buildings near it (scripts/replay.py draws them).
  for t = 600, END, 120 do
    schedule(t, function()
      if not S.center or S.frames > 600 then return end
      local c = S.center
      local area = {{c[1] - 120, c[2] - 120}, {c[1] + 120, c[2] + 120}}
      local units = surface().find_entities_filtered{area = area, force = FORCE, type = {"unit", "spider-unit"}}
      if #units == 0 then return end
      S.frames = S.frames + 1
      local frame = {tick = game.tick, center = c, units = {}, outpost = {}}
      for _, u in pairs(units) do
        table.insert(frame.units, {u.name, u.position.x, u.position.y, u.health / u.max_health})
      end
      for _, e in ipairs(S.outpost) do
        if e.valid then table.insert(frame.outpost, {e.name, e.position.x, e.position.y, e.health / e.max_health}) end
      end
      helpers.write_file("landing-party/replay.jsonl", helpers.table_to_json(frame) .. "\n", true)
    end)
  end
  schedule(END, function()
    local st = lp("stats", storage.id)
    local left, turrets = 0, 0
    for _, e in ipairs(S.outpost) do
      if e.valid then left = left + 1; if e.type == "ammo-turret" then turrets = turrets + 1 end end
    end
    check("assault: a depot was built", st.depots > 0, st.depots)
    check("assault: units were built", st.units_built > 0, st.units_built .. " built, garrison " .. st.garrison)
    check("assault: a raid was launched", st.raids_sent > 0, st.raids_sent)
    check("assault: the raid hit the outpost", left < S.count, (S.count - left) .. " of " .. S.count .. " destroyed, "
      .. turrets .. "/4 turrets standing, razed " .. st.razed)
    check("assault: the outpost fought back", st.units_lost > 0, st.units_lost .. " units lost")
  end)
end

-- Defend: turret creep against the farthest mining outpost. Its own turrets are knocked out first (as a
-- creeping player would; left standing, they killed the creep before it fired, so nothing was tested),
-- then two player gun turrets (armed as at arrival) shoot it. The creep must do damage, the depot must
-- send a response that destroys it, and what the outpost lost must be rebuilt.
-- A depot and parts are granted at the start so a garrison exists by the strike.
scenarios.defend = function()
  schedule(200, function() lp("debug_depot", storage.id, 3000) end)
  schedule(STRIKE, function()
    local lander = surface().find_entities_filtered{name = "lp-lander", force = FORCE}[1]
    local far, fd
    for _, bin in pairs(lp_entities("lp-bin")) do
      local d = (bin.position.x - lander.position.x) ^ 2 + (bin.position.y - lander.position.y) ^ 2
      if not fd or d > fd then far, fd = bin, d end
    end
    for _, t in pairs(surface().find_entities_filtered{name = "lp-turret", force = FORCE, position = far.position,
      radius = 40}) do t.die("player") end
    local at = {far.position.x, far.position.y}  -- the bin itself may die
    S.near = function() return surface().count_entities_filtered{force = FORCE, position = at, radius = 12,
      name = {"lp-drill", "lp-bin", "lp-pylon"}} end
    S.before = S.near()
    S.lost0 = lp("stats", storage.id).lost
    S.garrison = lp("stats", storage.id).garrison
    local pf = game.forces.player
    pf.set_ammo_damage_modifier("bullet", 0.8)
    pf.set_gun_speed_modifier("bullet", 0.6)
    S.creep = {}
    for _, off in ipairs({{9, -2}, {9, 3}}) do
      local p = surface().find_non_colliding_position("gun-turret", {far.position.x + off[1], far.position.y + off[2]}, 6, 1)
      local t = p and surface().create_entity{name = "gun-turret", position = p, force = "player"}
      if t then t.insert{name = "piercing-rounds-magazine", count = 200}; table.insert(S.creep, t) end
    end
    info(string.format("defend: %d turrets beside the outpost at %.0f,%.0f, %.0f tiles out; garrison %d, drills %d",
      #S.creep, far.position.x, far.position.y, math.sqrt(fd), S.garrison, S.before))
  end)
  schedule(STRIKE + 90, function() S.mid = S.near() end)
  schedule(STRIKE + 6 * 3600, function()
    local st = lp("stats", storage.id)
    local alive = 0
    for _, t in ipairs(S.creep) do if t.valid then alive = alive + 1 end end
    check("defend: there was a garrison to send", S.garrison > 2, S.garrison)
    check("defend: the creep did damage", S.mid < S.before, S.before .. " -> " .. S.mid .. " outpost entities")
    check("defend: a response was sent", st.responses > 0, st.responses)
    check("defend: the creeping turrets were destroyed", alive == 0, alive .. "/" .. #S.creep .. " standing")
    check("defend: the outpost was rebuilt", S.near() >= S.before,
      S.near() .. "/" .. S.before .. " outpost entities, rebuilt " .. st.rebuilt)
  end)
end

-- Faction: several landings, maturity, exports and tiers in one hour, on shortened clocks (a landing every
-- 12 minutes, maturity at 4 blocks, tier thresholds a tenth of the real ones).
scenarios.faction = function()
  schedule(30, function()
    lp("debug_tune", {cadence_minutes = 12, tiers = {300, 800, 2000, 4500}, mature_blocks = 4, quiet = true})
  end)
  -- No unit before its tier: sampled every 10 s across the map.
  S.early = 0
  for t = 600, END, 600 do
    schedule(t, function()
      local tier = lp("faction").tier
      for name, need in pairs({["lp-harrier"] = 1, ["lp-walker"] = 2}) do
        if tier < need then S.early = S.early + surface().count_entities_filtered{name = name, force = FORCE} end
      end
    end)
  end
  schedule(END, function()
    local f = lp("faction")
    local landers = surface().find_entities_filtered{name = "lp-lander", force = FORCE}
    local closest = math.huge
    for i = 1, #landers do for j = i + 1, #landers do
      local a, b = landers[i].position, landers[j].position
      closest = math.min(closest, math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2))
    end end
    local mature, pads, lamps, mines = 0, 0, 0, 0
    for id = 1, f.landings do
      local st = lp("stats", id)
      if st then
        if st.mature then mature = mature + 1 end
        pads, lamps, mines = pads + st.launchpads, lamps + st.lamps, mines + st.mines
        info(string.format("settlement %d: %s, %d hubs %d blocks, mature %s, exported %d, units %d (%s)", id, st.doctrine,
          st.hubs, st.blocks, tostring(st.mature), st.exported, st.units_built, serpent.line(st.built_by or {})))
        lp("snapshot", id, "landing-party/faction.jsonl", 200)
      end
    end
    check("faction: settlements keep landing", f.landings >= 4, f.landings .. " landings")
    check("faction: landings keep apart", closest >= 200, string.format("closest %.0f tiles", closest))
    check("faction: a settlement matured", mature > 0, mature)
    check("faction: a launch pad was built", pads > 0, pads)
    check("faction: mature hard points have lamps and mines", lamps > 0 and mines > 0, lamps .. " lamps, " .. mines .. " mines")
    check("faction: exports raised the tier", f.tier >= 1, "tier " .. f.tier .. ", " .. f.exported .. " exported")
    check("faction: no unit before its tier", S.early == 0, S.early .. " seen early")
  end)
end

local scenario = scenarios[params.scenario]
if not scenario then error("lp-sim: unknown scenario " .. tostring(params.scenario)) end
-- Scenarios that strike need the run to outlast the strike (occupy at 3 minutes once crashed reading
-- state its strike at 30 never made).
-- Minutes each needs after its strike (occupy holds 10, then needs time to rebuild: a 40-minute run with
-- the strike at 30 failed for lack of time, not of mechanics).
local AFTER = {cut = 6, raid = 6, path = 6, defend = 7, occupy = 18}
if AFTER[params.scenario] and END < STRIKE + AFTER[params.scenario] * 3600 then
  error(string.format("lp-sim: %s strikes at minute %d; run at least %d minutes", params.scenario, STRIKE / 3600,
    STRIKE / 3600 + AFTER[params.scenario]))
end

script.on_init(function()
  helpers.remove_path("landing-party")
  lp("set_trace", true)
  -- Land as the real arrival does, `distance` tiles from spawn (on a site with ore round it).
  storage.id = lp("arrive", 1, {x = 0, y = 0}, params.distance, {doctrine = params.doctrine})
  if not storage.id then error("lp-sim: landing failed") end
end)

scenario()
for m = params.every, params.minutes, params.every do
  schedule(m * 3600, function() lp("snapshot", storage.id, OUT, params.radius) end)
end
for _, m in ipairs({10, 20, 40, 60, 90, 120}) do
  if m <= params.minutes then
    schedule(m * 3600, function() metric("modules_" .. m, lp("stats", storage.id).modules) end)
  end
end
schedule(END, function()
  local s = lp("stats", storage.id)
  -- A run that ends before its scenario's checks fire must not pass (path once "passed" at 32 minutes with
  -- its checks due at 35).
  local CHECKLESS = {grow = true, probe = true, cost = true}
  if not CHECKLESS[params.scenario] then
    local ran = 0
    for _, l in ipairs(lines) do
      local is_check = l:sub(1, 5) == "PASS " or l:sub(1, 5) == "FAIL "
      if is_check and l:find(params.scenario .. ":", 1, true) then ran = ran + 1 end
    end
    check("the scenario's checks ran", ran > 0, ran .. " checks; is the run long enough?")
  end
  check("lander alive", s.lander)
  check("mined", s.mined > 0, s.mined)
  check("made parts", s.made > 0, s.made)
  metric("doctrine", s.doctrine); metric("hubs", s.hubs); metric("archetypes", s.archetypes)
  metric("blocks", s.blocks); metric("walls", s.walls); metric("roads", s.road_tiles)
  check("power covers demand", s.demand <= s.supply, string.format("%.1f/%.1f MW", s.demand / 1e6, s.supply / 1e6))
  metric("parts", s.parts); metric("drills", s.drills); metric("fabs", s.fabs); metric("pylons", s.pylons)
  metric("lost", s.lost); metric("rebuilt", s.rebuilt)
  metric("units", s.units_built); metric("units_lost", s.units_lost); metric("raids", s.raids_sent)
  metric("razed", s.razed); metric("responses", s.responses)
  table.insert(lines, "INFO " .. helpers.table_to_json(s))
  table.insert(lines, failed == 0 and "DONE ALL PASSED" or ("DONE " .. failed .. " FAILED"))
  helpers.write_file("landing-party/results.txt", table.concat(lines, "\n") .. "\n")
end)

script.on_event(defines.events.on_ai_command_completed, function(e)
  if S.results then S.results[e.unit_number] = e.result end
end)

script.on_event(defines.events.on_tick, function(e)
  local f = at[e.tick]
  if f then f() end
end)
