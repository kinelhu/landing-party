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
local FORCE = "lp-serenity"     -- the default corporation (shared.DEFAULT_CORP)

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
      -- Buildings only: a faction unit walking past once counted as a rebuild.
      -- (`invert` would invert the whole filter, position and force included.)
      rebuilt = rebuilt + surface().count_entities_filtered{position = p, radius = 1, force = FORCE,
        name = {"lp-turret", "lp-fabricator", "lp-generator", "lp-pylon", "lp-drill", "lp-bin", "lp-radar", "lp-depot"}}
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
  -- Raids are sized to known defence now (5 a turret, plus 4): four turrets need 24, more than two depots'
  -- garrison can spare. Three more depots: the test is whether a raid sized to the outpost takes it.
  schedule(300, function() for _ = 1, 3 do lp("debug_depot", storage.id, 1000) end end)
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

-- Defend: turret creep against an outpost's turrets (a bastion settlement, so outposts are turreted).
-- Three player gun turrets, armed as at arrival, set up 16 tiles from the turret pair of the outpost
-- farthest from the lander, inside both sides' range. Only military targets draw fire (production does
-- not), so the creep trades with the outpost's turrets. It must do damage, the depot must answer and
-- destroy it, and the outpost must stand again. A depot and parts are granted at the start.
scenarios.defend = function()
  if params.mix == "noops" then schedule(STRIKE - 30, function() lp("debug_tune", {ops_off = true}) end) end
  schedule(200, function() lp("debug_depot", storage.id, 3000) end)
  schedule(STRIKE, function()
    local lander = surface().find_entities_filtered{name = "lp-lander", force = FORCE}[1]
    local far, fd
    for _, t in pairs(lp_entities("lp-turret")) do
      local near_bin = surface().count_entities_filtered{name = "lp-bin", force = FORCE, position = t.position, radius = 14}
      local d = (t.position.x - lander.position.x) ^ 2 + (t.position.y - lander.position.y) ^ 2
      if near_bin > 0 and (not fd or d > fd) then far, fd = t, d end
    end
    if not far then info("defend: no turreted outpost"); return end
    local at = {far.position.x, far.position.y}
    S.near = function() return surface().count_entities_filtered{force = FORCE, position = at, radius = 14,
      name = {"lp-drill", "lp-bin", "lp-pylon", "lp-turret"}} end
    S.health = function()
      local h = 0
      for _, t in pairs(surface().find_entities_filtered{name = "lp-turret", force = FORCE, position = at, radius = 8}) do
        h = h + t.health end
      return h
    end
    S.before, S.hp0 = S.near(), S.health()
    S.garrison = lp("stats", storage.id).garrison
    local pf = game.forces.player
    pf.set_ammo_damage_modifier("bullet", 0.8)
    pf.set_gun_speed_modifier("bullet", 0.6)
    local dx, dy = lander.position.x - at[1], lander.position.y - at[2]
    local len = math.sqrt(dx * dx + dy * dy)
    S.creep = {}
    for k = -1, 1 do
      local p = {at[1] - dx / len * 16 + k * 3 * dy / len, at[2] - dy / len * 16 - k * 3 * dx / len}
      p = surface().find_non_colliding_position("gun-turret", p, 6, 1)
      local t = p and surface().create_entity{name = "gun-turret", position = p, force = "player"}
      if t then t.insert{name = "piercing-rounds-magazine", count = 200}; table.insert(S.creep, t) end
    end
    info(string.format("defend: %d turrets 16 tiles from the outpost turrets at %.0f,%.0f; garrison %d",
      #S.creep, at[1], at[2], S.garrison))
  end)
  schedule(STRIKE + 60, function() S.mid, S.hp_mid = S.near(), S.health() end)
  schedule(STRIKE + 6 * 3600, function()
    local st = lp("stats", storage.id)
    local alive = 0
    for _, t in ipairs(S.creep or {}) do if t.valid then alive = alive + 1 end end
    check("defend: there was a garrison to send", (S.garrison or 0) > 2, S.garrison)
    check("defend: the creep did damage", S.mid and (S.mid < S.before or S.hp_mid < S.hp0),
      string.format("%s -> %s entities, turret health %.0f -> %.0f", S.before, S.mid, S.hp0 or 0, S.hp_mid or 0))
    -- A response to units, a raid sized to turret creep (static threats get no piecemeal answer).
    check("defend: the faction answered", st.responses + st.ops.launched > 0,
      st.responses .. " responses, " .. st.ops.launched .. " raids")
    check("defend: the creeping turrets were destroyed", S.creep and alive == 0, alive .. " standing")
    check("defend: the outpost stands again", S.near and S.near() >= S.before,
      (S.near and S.near() or 0) .. "/" .. tostring(S.before) .. " outpost entities, rebuilt " .. st.rebuilt)
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

-- Uplink: the fortress lands first (with the parts it brings) and builds its rings; landings continue while
-- it stands (clock shortened to 3 minutes); at minute 12 it is destroyed: no landing may follow, and
-- exports may no longer raise the tier.
scenarios.uplink = function()
  schedule(60, function() lp("debug_tune", {cadence_minutes = 3, quiet = true}) end)
  schedule(11 * 3600, function()
    local st = lp("stats", storage.id)
    local plan = st.fortress_planned or {}
    local box = st.fortress_box
    local function inside(name)
      return box and surface().count_entities_filtered{name = name, force = FORCE,
        area = {{box[1], box[2]}, {box[3], box[4]}}} or 0
    end
    st.walls, st.turrets_n = inside("lp-wall"), inside("lp-turret")
    check("uplink: the fortress stands", st.uplink and st.doctrine == "fortress", st.doctrine)
    -- Against what the layout plans: a few may be blocked by terrain.
    check("uplink: its rings are built", st.walls >= 0.95 * (plan["lp-wall"] or 1),
      st.walls .. " of " .. tostring(plan["lp-wall"]) .. " walls")
    check("uplink: its turret belts are built", st.turrets_n >= 0.95 * (plan["lp-turret"] or 1),
      st.turrets_n .. " of " .. tostring(plan["lp-turret"]) .. " turrets")
    check("uplink: its generators are built", inside("lp-generator") >= (plan["lp-generator"] or 1),
      inside("lp-generator") .. " of " .. tostring(plan["lp-generator"]))
    info(string.format("uplink: fortress of %d walls, %d turrets, %d blocks; garrison %d", st.walls, st.turrets_n,
      st.blocks, st.garrison))
  end)
  schedule(12 * 3600, function()
    S.landings = lp("faction").landings
    S.tier = lp("faction").tier
    local u = surface().find_entities_filtered{name = "lp-uplink", force = FORCE}[1]
    if u then u.die("player") end
  end)
  schedule(18 * 3600, function()
    local f = lp("faction")
    check("uplink: landings came while it stood", S.landings >= 3, S.landings .. " landings")
    check("uplink: its fall is registered", f.uplink_down ~= nil, tostring(f.uplink_down))
    check("uplink: no landing after its fall", f.landings == S.landings, S.landings .. " -> " .. f.landings)
    lp("debug_export", storage.id, 100000)
    check("uplink: the tier is frozen", lp("faction").tier == S.tier, "tier " .. S.tier .. " -> " .. lp("faction").tier)
    lp("snapshot", storage.id, "landing-party/faction.jsonl", 200)
    for id = 2, f.landings do lp("snapshot", id, "landing-party/faction.jsonl", 200) end
  end)
end

-- Army: the player's side, the mechanism alone. A powered barracks fed for 12 troopers, a rally beacon and a
-- constant combinator wired to it, beyond a faction outpost. At minute 8 the combinator sends O (occupy);
-- turrets near the target are removed and the faction's responses and raids are off, so this tests
-- training, orders, holding and capture, not a fight.
scenarios.army = function()
  local red = defines.wire_connector_id.circuit_red
  schedule(STRIKE, function()
    local lander = surface().find_entities_filtered{name = "lp-lander", force = FORCE}[1]
    -- The outpost farthest from any faction turret (one 29 tiles from a hub drew the squad onto its lasers).
    local far, fd
    for _, bin in pairs(lp_entities("lp-bin")) do
      local t = surface().find_entities_filtered{name = "lp-turret", force = FORCE, position = bin.position, radius = 200}
      local d = 200
      for _, x in pairs(t) do
        d = math.min(d, math.sqrt((x.position.x - bin.position.x) ^ 2 + (x.position.y - bin.position.y) ^ 2))
      end
      if not fd or d > fd then far, fd = bin, d end
    end
    S.target = {far.position.x, far.position.y}
    S.clearance = fd
    -- Beyond the outpost, away from the lander: placed towards spawn it once sat beside the landing pad,
    -- inside its turrets' range, and every trooper died before the advance.
    local dx, dy = far.position.x - lander.position.x, far.position.y - lander.position.y
    local len = math.sqrt(dx * dx + dy * dy)
    local a
    -- With room to spare: turrets built later beside it killed the waiting squad (seed 777). On dry land: the
    -- flattening once made an island in a lake and no path left it (seed 12345, strike 30). Other angles
    -- when straight beyond fails.
    local ok
    for _, turn in ipairs({0, 0.5, -0.5, 1, -1}) do
      local c, sn = math.cos(turn), math.sin(turn)
      local ux, uy = (dx * c - dy * sn) / len, (dx * sn + dy * c) / len
      for _, d in ipairs({60, 90, 120, 150}) do
        a = {far.position.x + ux * d, far.position.y + uy * d}
        if surface().count_entities_filtered{force = FORCE, position = a, radius = 60} == 0
          and surface().count_tiles_filtered{position = a, radius = 25, collision_mask = "water_tile"} == 0 then
          ok = true; break
        end
      end
      if ok then break end
    end
    S.base_at = a
    flatten(math.floor(a[1]) - 10, math.floor(a[2]) - 10, math.floor(a[1]) + 10, math.floor(a[2]) + 10)
    local function put(name, dx, dy)
      return surface().create_entity{name = name, position = {a[1] + dx, a[2] + dy}, force = "player", raise_built = true}
    end
    S.barracks = put("lp-barracks", 0.5, 0.5)
    put("electric-energy-interface", 4, 1)
    put("medium-electric-pole", 2.5, 2.5)
    S.beacon = put("lp-rally-beacon", -3.5, 0.5)
    -- The mechanism alone, from the start: at a 30-minute strike the faction's raids destroyed the barracks.
    lp("debug_tune", {army_off = true})
    -- Bandwidth: research level 1 (four relays count) and two powered relays: room for 20.
    game.forces.player.technologies["lp-command-bandwidth-1"].researched = true
    put("lp-command-relay", 0.5, 6.5)
    put("lp-command-relay", 4.5, 6.5)
    put("medium-electric-pole", 2.5, 5.5)
    S.cc = put("constant-combinator", -5.5, 0.5)
    S.cc.get_wire_connector(red, true).connect_to(S.beacon.get_wire_connector(red, true))
    -- Finished orders handed to the barracks (30 s a trooper would take most of the run): this tests the
    -- army, not the recipe (the caps scenario checks the recipe in the prototypes).
    S.orders = 0
    S.feed = function()
      if not S.barracks.valid then return end
      local out = S.barracks.get_inventory(defines.inventory.crafter_output)
      if S.orders < 12 then S.orders = S.orders + out.insert{name = "lp-trooper-order", count = math.min(10, 12 - S.orders)} end
    end
    S.feed()
    info(string.format("army: barracks at %.0f,%.0f, outpost at %.0f,%.0f, %.0f tiles from the nearest faction turret",
      a[1], a[2], S.target[1], S.target[2], S.clearance))
  end)
  schedule(STRIKE + 4 * 3600, function()
    S.trained = lp("army").trained
    -- The mechanism alone, as occupy tests it: turrets near the target are removed (as if an earlier assault
    -- had won) and the faction's responses and raids are off. Compact settlements cover every outpost with
    -- a hub's turrets (seeds 12345 and 777), so a target "out of range" was a property of the map.
    -- Lasers reach 24 tiles: clear 45 round the target (30 left turrets covering the approach). The idle
    -- garrison fights what comes near: remove units within 80 (they killed the squad on seed 12345).
    -- Along the whole approach, not only round the target.
    for k = 0, 10 do
      local p = {S.target[1] + (S.base_at[1] - S.target[1]) * k / 10, S.target[2] + (S.base_at[2] - S.target[2]) * k / 10}
      for _, x in pairs(surface().find_entities_filtered{name = "lp-turret", force = FORCE, position = p,
        radius = 45}) do x.destroy() end
    end
    for _, x in pairs(surface().find_entities_filtered{type = {"unit", "spider-unit"}, force = FORCE,
      position = S.target, radius = 80}) do x.destroy() end
    lp("debug_tune", {army_off = true})
    local sec = S.cc.get_or_create_control_behavior().get_section(1) or S.cc.get_or_create_control_behavior().add_section()
    sec.filters = {{value = {type = "virtual", name = "signal-O", quality = "normal"}, min = 1}}
  end)
  for t = STRIKE + 600, STRIKE + 4 * 3600, 600 do schedule(t, function() if S.feed then S.feed() end end) end
  S.reached = 0
  for t = STRIKE + 4 * 3600, STRIKE + 10 * 3600, 600 do
    schedule(t, function()
      if not S.target then return end
      -- Troopers standing at any outpost (the beacon picks its own, seed 777).
      local n = 0
      for _, u in pairs(surface().find_entities_filtered{name = "lp-trooper", force = "player"}) do
        if surface().count_entities_filtered{name = "lp-bin", position = u.position, radius = 10, limit = 1} > 0 then
          n = n + 1
        end
      end
      S.reached = math.max(S.reached, n)
    end)
  end
  schedule(STRIKE + 10 * 3600, function()
    local st = lp("stats", storage.id)
    -- Any outpost: the beacon picks the one nearest to itself, not necessarily the test's (seed 777).
    local mine = surface().count_entities_filtered{name = "lp-drill", force = "player"}
    check("army: troopers were trained", (S.trained or 0) >= 10, tostring(S.trained) .. " by the advance")
    check("army: the beacon took them to the outpost", S.reached >= 5, S.reached .. " at the outpost at most")
    check("army: holding it captured it", mine > 0 and st.captured > 0, mine .. " drills now the player's, " ..
      st.captured .. " outposts captured")
    info("army: " .. serpent.line(lp("army")) .. ", killed by " .. serpent.line(S.killers or {}))
  end)
end

-- Caps: command bandwidth. Level 1 and two powered relays give room for 20; orders beyond wait in the
-- barracks. A relay lost puts 10 units offline. Level 2 and three more relays bring them back and make room
-- for more. A destroyed depot drops a command core.
scenarios.caps = function()
  schedule(60, function()
    flatten(-150, -150, -90, -90)
    local function put(name, x, y)
      return surface().create_entity{name = name, position = {x, y}, force = "player", raise_built = true}
    end
    game.forces.player.technologies["lp-command-bandwidth-1"].researched = true
    S.barracks = put("lp-barracks", -120.5, -120.5)
    put("electric-energy-interface", -116, -120)
    S.relays = {put("lp-command-relay", -125.5, -114.5), put("lp-command-relay", -121.5, -114.5)}
    for _, p in ipairs({{-118.5, -117.5}, {-123.5, -117.5}, {-113.5, -117.5}}) do put("medium-electric-pole", p[1], p[2]) end
    put("lp-rally-beacon", -110.5, -125.5)
    S.put = put
    S.orders = 0
  end)
  -- Orders handed in 10 at a time (the output holds one stack), 40 in all.
  for t = 120, 9 * 3600, 300 do
    schedule(t, function()
      if not S.barracks then return end
      local out = S.barracks.get_inventory(defines.inventory.crafter_output)
      if S.orders < 40 then S.orders = S.orders + out.insert{name = "lp-trooper-order", count = math.min(10, 40 - S.orders)} end
    end)
  end
  schedule(4 * 3600, function()
    local a = lp("army")
    check("caps: training stops at the cap", a.alive == 20 and a.capacity == 20, a.alive .. " troopers, capacity " .. a.capacity)
    local waiting = S.barracks.get_inventory(defines.inventory.crafter_output).get_item_count("lp-trooper-order")
    check("caps: orders wait in the barracks", waiting > 0, waiting .. " waiting")
    S.relays[1].destroy()
  end)
  schedule(4 * 3600 + 300, function()
    local a = lp("army")
    check("caps: a relay lost puts units offline", a.capacity == 10 and a.offline == 10,
      "capacity " .. a.capacity .. ", " .. a.offline .. " offline")
    game.forces.player.technologies["lp-command-bandwidth-2"].researched = true
    for _, x in ipairs({-125.5, -129.5, -133.5}) do S.put("lp-command-relay", x, -110.5) end
    S.put("medium-electric-pole", -127.5, -113.5)
    S.put("medium-electric-pole", -131.5, -113.5)
  end)
  schedule(7 * 3600, function()
    local a = lp("army")
    check("caps: research and relays bring them back", a.offline == 0 and a.capacity == 40,
      "capacity " .. a.capacity .. ", " .. a.offline .. " offline, level " .. a.level)
    check("caps: and make room for more", a.alive > 20, a.alive .. " troopers")
    lp("debug_depot", storage.id, 0)
    local d = surface().find_entities_filtered{name = "lp-depot", force = FORCE}[1]
    if d then d.die("player") end
  end)
  schedule(7 * 3600 + 60, function()
    local a = lp("army")
    local on_ground = surface().count_entities_filtered{name = "item-on-ground"}
    check("caps: a destroyed depot drops a command core", a.cores_dropped >= 1, a.cores_dropped .. " dropped, "
      .. on_ground .. " items on the ground")
    local r = prototypes.recipe["lp-trooper-order"]
    local core = false
    for _, i in pairs(prototypes.recipe["lp-barracks"].ingredients) do if i.name == "lp-command-core" then core = true end end
    check("caps: a trooper takes 30 s, a barracks a core", r.energy == 30 and core, r.energy .. " s, core " .. tostring(core))
    local kit = {}
    for _, i in pairs(r.ingredients) do kit[i.name] = true end
    check("caps: a trooper is made of the engineer's kit", kit["heavy-armor"] and kit["submachine-gun"],
      serpent.line(kit))
    local rec = game.forces.player.recipes
    check("caps: troopers and breachers at level 1, battle tanks at 2", S.gate1 == "true true false"
      and rec["lp-battle-tank-order"].enabled, (S.gate1 or "?") .. " at level 1; tanks now " .. tostring(rec["lp-battle-tank-order"].enabled))
  end)
  schedule(90, function()
    local rec = game.forces.player.recipes
    S.gate1 = string.format("%s %s %s", tostring(rec["lp-trooper-order"].enabled), tostring(rec["lp-breacher-order"].enabled),
      tostring(rec["lp-battle-tank-order"].enabled))
  end)
end

-- Lively: a settlement with a depot from the start; its patrols must walk their routes. Unit positions are
-- recorded every 2 s for the life animation (scripts/life.py).
scenarios.lively = function()
  schedule(200, function() lp("debug_depot", storage.id, 2000) end)
  S.visited = {}
  for t = 600, END, 120 do
    schedule(t, function()
      local st = lp("stats", storage.id)
      local lander = surface().find_entities_filtered{name = "lp-lander", force = FORCE}[1]
      if not lander then return end
      local units = surface().find_entities_filtered{position = lander.position, radius = 220, type = {"unit", "spider-unit"}}
      local frame = {tick = game.tick, units = {}}
      for _, u in pairs(units) do
        table.insert(frame.units, {u.name, u.position.x, u.position.y, u.force.name})
        for k, p in ipairs(st.route or {}) do
          if (u.position.x - p[1]) ^ 2 + (u.position.y - p[2]) ^ 2 < 100 then S.visited[k] = true end
        end
      end
      helpers.write_file("landing-party/life.jsonl", helpers.table_to_json(frame) .. "\n", true)
    end)
  end
  schedule(END, function()
    local st = lp("stats", storage.id)
    local v = 0
    for _ in pairs(S.visited) do v = v + 1 end
    check("lively: patrols are out", st.patrol > 0, st.patrol .. " patrolling")
    check("lively: they walk their route", st.route and v >= math.min(3, #st.route), v .. " of " .. (st.route and #st.route or 0)
      .. " stops visited")
  end)
end

-- Convoy: an ordinary settlement (matured at once, a depot and parts granted) and an uplink landed beside
-- it. While the uplink stands the settlement's exports travel to it by convoy. The first hauler is
-- destroyed on the way: its cargo must be lost, later convoys must arrive, and the faction's exports must
-- equal what arrived. All units on the map are recorded for the life animation.
scenarios.convoy = function()
  schedule(60, function()
    lp("debug_tune", {mature_blocks = 2, quiet = true})
    lp("debug_depot", storage.id, 4000)
  end)
  schedule(120, function()
    S.uplink = lp("arrive", 1, {x = 0, y = 0}, params.distance, {uplink = true})
    info("convoy: uplink settlement " .. tostring(S.uplink))
  end)
  for t = 600, END, 120 do
    schedule(t, function()
      local haulers = surface().find_entities_filtered{name = "lp-hauler", force = FORCE}
      -- Escorts stay with their hauler: the largest distance seen while convoys travel.
      local cst = lp("stats", storage.id)
      local spread = cst.convoy_spread
      S.spread = math.max(S.spread or 0, spread)
      if spread > 0 then S.spread_sum, S.spread_n = (S.spread_sum or 0) + spread, (S.spread_n or 0) + 1 end
      if spread > 15 and (S.logged or 0) < 40 and game.tick % 600 == 0 then
        S.logged = (S.logged or 0) + 1
        local names = {}
        for k, v in pairs(defines.group_state) do names[v] = k end
        local dbg = cst.convoy_debug:gsub("state=(%d+)", function(d) return "state=" .. tostring(names[tonumber(d)]) end)
        table.insert(lines, string.format("INFO spread %.0f at %.1f min: %s", spread, game.tick / 3600, dbg))
      end
      if not S.killed then
        for _, h in pairs(haulers) do
          S.seen = S.seen or {}
          if S.seen[h.unit_number] then h.die("player"); S.killed = true; break end
          S.seen[h.unit_number] = true
        end
      end
      local frame = {tick = game.tick, units = {}}
      for _, u in pairs(surface().find_entities_filtered{type = {"unit", "spider-unit"}}) do
        table.insert(frame.units, {u.name, u.position.x, u.position.y, u.force.name})
      end
      helpers.write_file("landing-party/life.jsonl", helpers.table_to_json(frame) .. "\n", true)
    end)
  end
  schedule(END, function()
    local a, f = lp("stats", storage.id), lp("faction")
    local u = S.uplink and lp("stats", S.uplink)
    check("convoy: the uplink landed", u ~= nil and u.uplink, tostring(S.uplink))
    check("convoy: convoys left", a.convoys_sent >= 2, a.convoys_sent .. " sent")
    check("convoy: the destroyed one lost its cargo", a.convoys_lost >= 1 and a.cargo_lost > 0,
      a.convoys_lost .. " lost, " .. a.cargo_lost .. " parts")
    check("convoy: later ones arrived", a.convoys_delivered >= 1, a.convoys_delivered .. " delivered")
    -- The hauler halts at 12 tiles of slack and moves up to a second before the next look: 18 at worst.
    local mean = S.spread_n and S.spread_sum / S.spread_n or 0
    check("convoy: escorts stay with the hauler", (S.spread or 0) <= 18 and mean <= 8,
      string.format("at most %.0f tiles apart, %.1f on average", S.spread or 0, mean))
    check("convoy: exports count only what arrived", f.exported == a.exported + (u and u.exported or 0),
      string.format("faction %d = settlement %d + uplink %d", f.exported, a.exported, u and u.exported or 0))
    lp("snapshot", storage.id, "landing-party/faction.jsonl", 200)
    if S.uplink then lp("snapshot", S.uplink, "landing-party/faction.jsonl", 200) end
  end)
end

-- Train: a player rail line with a locomotive and a wagon 110 tiles from the lander; the settlement (a depot
-- and parts granted) must send interceptors that damage or destroy the train.
scenarios.train = function()
  schedule(200, function() lp("debug_depot", storage.id, 3000) end)
  schedule(STRIKE, function()
    local lander = surface().find_entities_filtered{name = "lp-lander", force = FORCE}[1]
    local dx, dy = -lander.position.x, -lander.position.y
    local len = math.sqrt(dx * dx + dy * dy)
    local c = {math.floor(lander.position.x + dx / len * 110), math.floor(lander.position.y + dy / len * 110)}
    flatten(c[1] - 40, c[2] - 6, c[1] + 40, c[2] + 6)
    c[1], c[2] = c[1] - c[1] % 2, c[2] - c[2] % 2
    for x = c[1] - 36, c[1] + 36, 2 do
      surface().create_entity{name = "straight-rail", position = {x + 1, c[2] + 1}, direction = defines.direction.east,
        force = "player"}
    end
    S.loco = surface().create_entity{name = "locomotive", position = {c[1] + 1, c[2] + 1}, direction = defines.direction.east,
      force = "player"}
    S.wagon = surface().create_entity{name = "cargo-wagon", position = {c[1] - 6, c[2] + 1}, direction = defines.direction.east,
      force = "player"}
    S.hp = S.loco and S.loco.health or 0
    info(string.format("train: locomotive %s, wagon %s at %d,%d", tostring(S.loco ~= nil), tostring(S.wagon ~= nil), c[1], c[2]))
  end)
  S.closest = math.huge
  for t = STRIKE + 60, STRIKE + 5 * 3600, 60 do
    schedule(t, function()
      if not (S.wagon and S.wagon.valid) then return end
      for _, u in pairs(surface().find_entities_filtered{force = FORCE, type = {"unit", "spider-unit"},
        position = S.wagon.position, radius = 200}) do
        S.closest = math.min(S.closest, math.sqrt((u.position.x - S.wagon.position.x) ^ 2 + (u.position.y - S.wagon.position.y) ^ 2))
      end
    end)
  end
  schedule(STRIKE + 5 * 3600, function()
    info(string.format("train: closest faction unit came within %.0f tiles of the wagon (%.0f health left)", S.closest,
      S.wagon and S.wagon.valid and S.wagon.health or 0))
    local st = lp("stats", storage.id)
    -- Damage to any carriage counts (a wagon at 49 of 600 health once read as "not hit").
    local hurt = not (S.loco and S.loco.valid) or S.loco.health < S.hp or not (S.wagon and S.wagon.valid)
      or S.wagon.health < S.wagon.max_health
    check("train: there was a train", S.loco ~= nil, tostring(S.loco ~= nil))
    check("train: interceptors were sent", st.intercepts > 0, st.intercepts)
    check("train: they hit it", hurt, string.format("locomotive %s, wagon %s",
      (S.loco and S.loco.valid) and string.format("%.0f/%.0f", S.loco.health, S.hp) or "destroyed",
      (S.wagon and S.wagon.valid) and string.format("%.0f/%.0f", S.wagon.health, S.wagon.max_health) or "destroyed"))
  end)
end

-- Showcase: a save to look at in game (scripts/showcase.sh runs it on a headless server, which saves at the
-- strike). A settlement matured at once with a garrison, an uplink landed beside it (convoys), raids off;
-- by spawn the player's barracks with 20 troopers' orders, relays, power and a rally beacon (no signal: hold;
-- A advance, O occupy, R retreat; X and Y move the rally point).
scenarios.showcase = function()
  -- A server runs in real time: fast until the save, normal speed in it.
  schedule(30, function() game.speed = 64 end)
  schedule(60, function()
    lp("debug_tune", {mature_blocks = 2, quiet = true, raids_off = true})
    lp("debug_depot", storage.id, 4000)
  end)
  schedule(120, function()
    lp("arrive", 1, {x = 0, y = 0}, params.distance, {uplink = true})
    flatten(-6, -34, 36, 0)
    local function put(name, x, y)
      return surface().create_entity{name = name, position = {x, y}, force = "player", raise_built = true}
    end
    for k = 1, 2 do game.forces.player.technologies["lp-command-bandwidth-" .. k].researched = true end
    -- Barracks for each unit type, with finished orders: 20 troopers, 10 breachers, 5 battle tanks (50 of
    -- bandwidth: five relays at research level 2).
    S.army = {{"lp-trooper-order", 20}, {"lp-breacher-order", 10}, {"lp-battle-tank-order", 5}}
    S.barracks = {}
    for i, o in ipairs(S.army) do
      local b = put("lp-barracks", 4.5 + 6 * i, -15.5)
      b.set_recipe(o[1])
      S.barracks[i] = b
      put("medium-electric-pole", 6.5 + 6 * i, -12.5)
    end
    put("electric-energy-interface", 31, -11)
    for k = 1, 5 do put("lp-command-relay", 2.5 + 4 * k, -7.5) end
    for x = 4.5, 28.5, 6 do put("medium-electric-pole", x, -10.5) end
    put("lp-rally-beacon", 20.5, -26.5)
    S.feed = function()
      for i, o in ipairs(S.army) do
        local b = S.barracks[i]
        local out = b.valid and b.get_inventory(defines.inventory.crafter_output)
        local have = (S.fed or {})[i] or 0
        if out and have < o[2] then
          S.fed = S.fed or {}
          S.fed[i] = have + out.insert{name = o[1], count = math.min(10, o[2] - have)}
        end
      end
    end
    S.feed()
  end)
  for t = 1200, 6000, 600 do schedule(t, function() if S.feed then S.feed() end end) end
  schedule(STRIKE, function()
    game.forces.player.chart(surface(), {{-600, -600}, {600, 600}})
    -- Exports for half an hour of convoys (one of 1,000 parts a minute): the granted stock ran out in three.
    lp("debug_parts", storage.id, 30000)
  end)
  schedule(STRIKE + 300, function()
    game.speed = 1
    game.server_save("lp-showcase")
    local army = lp("army")
    helpers.write_file("landing-party/saved.txt", string.format("%d (%d units, capacity %d)", game.tick, army.alive,
      army.capacity))
  end)
end

-- Orders: the beacon's own signals, unwired, and its network's when wired. Ten troopers by spawn; the beacon
-- sets X = 40 itself: they hold 40 tiles east of it. A combinator wired to it adds Y = -30: they move there.
scenarios.orders = function()
  local function put(name, x, y)
    return surface().create_entity{name = name, position = {x, y}, force = "player", raise_built = true}
  end
  local function at(dx, dy)
    local n = 0
    for _, u in pairs(surface().find_entities_filtered{name = "lp-trooper", force = "player"}) do
      if (u.position.x - (S.b.position.x + dx)) ^ 2 + (u.position.y - (S.b.position.y + dy)) ^ 2 < 15 * 15 then n = n + 1 end
    end
    return n
  end
  schedule(60, function()
    lp("debug_tune", {raids_off = true})
    flatten(-20, -80, 80, 20)
    game.forces.player.technologies["lp-command-bandwidth-1"].researched = true
    S.barracks = put("lp-barracks", 0.5, 0.5)
    put("electric-energy-interface", 4, 1)
    put("medium-electric-pole", 2.5, 2.5)
    put("lp-command-relay", 0.5, 6.5)
    put("medium-electric-pole", 2.5, 5.5)
    S.b = put("lp-rally-beacon", 10.5, -10.5)
    S.b.get_or_create_control_behavior().add_section().filters =
      {{value = {type = "virtual", name = "signal-X", quality = "normal"}, min = 40}}
    S.barracks.get_inventory(defines.inventory.crafter_output).insert{name = "lp-trooper-order", count = 10}
  end)
  schedule(60 + 40 * 60, function()
    S.first = at(40, 0)
    local cc = put("constant-combinator", 8.5, -10.5)
    local red = defines.wire_connector_id.circuit_red
    cc.get_wire_connector(red, true).connect_to(S.b.get_wire_connector(red, true))
    cc.get_or_create_control_behavior().add_section().filters =
      {{value = {type = "virtual", name = "signal-Y", quality = "normal"}, min = -30}}
  end)
  schedule(60 + 80 * 60, function()
    check("orders: the beacon's own X moved the rally point", S.first >= 8, S.first .. " of 10 at +40,0")
    check("orders: a wired Y added to it", at(40, -30) >= 8, at(40, -30) .. " of 10 at +40,-30")
    -- Research levels: the endless fourth counts only levels done (it once counted 3 before any).
    local tech = game.forces.player.technologies
    for k = 1, 3 do tech["lp-command-bandwidth-" .. k].researched = true end
    local l3 = lp("army").level
    tech["lp-command-bandwidth-4"].level = 6
    local l5 = lp("army").level
    check("orders: research levels count what is done", l3 == 3 and l5 == 5, l3 .. " after three, " .. l5 .. " after two endless")
  end)
end

-- Fall: two settlements with garrisons; at the strike the first one's lander is destroyed. Its generators
-- must fail, its turrets go dark (none of the faction's left there), its units evacuate to the second, its
-- ruins yield salvage, an outpost be taken by holding it, and nothing be rebuilt.
scenarios.fall = function()
  schedule(60, function()
    lp("debug_tune", {raids_off = true})
    lp("debug_depot", storage.id, 2000)
  end)
  schedule(120, function()
    S.other = lp("arrive", 1, {x = 0, y = 0}, params.distance, {})
    if S.other then lp("debug_depot", S.other, 2000) end
  end)
  schedule(STRIKE, function()
    local st = lp("stats", storage.id)
    S.before = st
    S.other_before = S.other and lp("stats", S.other).garrison or 0
    S.origin = {st.origin and st.origin.x or 0, st.origin and st.origin.y or 0}
    local lander = surface().find_entities_filtered{name = "lp-lander", force = FORCE, position = S.origin, radius = 30}[1]
    S.lander_at = {lander.position.x, lander.position.y}
    info(string.format("fall: settlement %d at %.0f,%.0f, %d generators, %d turrets, garrison %d, patrol %d; settlement %s garrison %d",
      storage.id, lander.position.x, lander.position.y, st.gens, st.turrets, st.garrison, st.patrol, tostring(S.other),
      S.other_before))
    lander.die("player")
  end)
  schedule(STRIKE + 90 * 60, function()
    local st = lp("stats", storage.id)
    local live = surface().count_entities_filtered{name = "lp-turret", force = FORCE, position = S.lander_at, radius = 150}
    local ruins = surface().count_entities_filtered{force = "neutral", position = S.lander_at, radius = 250,
      name = {"lp-turret", "lp-fabricator", "lp-pylon", "lp-wall"}}
    check("fall: the settlement fell", st.fallen ~= nil, tostring(st.fallen))
    check("fall: its generators failed", st.gens == 0, st.gens .. " of " .. S.before.gens .. " left")
    check("fall: no live turret is left there", live == 0, live .. " of the faction's within 150")
    check("fall: what stood is ruins", ruins > 0 and (st.ruins or 0) > 0, ruins .. " neutral, " .. tostring(st.ruins) .. " ruined")
    local other = S.other and lp("stats", S.other)
    check("fall: its units evacuated", (st.evacuated or 0) > 0 and other and other.garrison > S.other_before,
      string.format("%s evacuated; the other garrison %d -> %d", tostring(st.evacuated), S.other_before, other and other.garrison or -1))
    -- Salvage: a ruined fabricator mined into a script inventory.
    local fab = surface().find_entities_filtered{name = "lp-fabricator", force = "neutral", position = S.lander_at, radius = 250}[1]
    local inv = game.create_inventory(10)
    local mined = fab and fab.mine{inventory = inv}
    check("fall: ruins yield salvage", mined and inv.get_item_count("lp-salvage") > 0,
      inv.get_item_count("lp-salvage") .. " salvage from a fabricator")
    inv.destroy()
    -- Holding an outpost: a player turret on the fallen settlement's nearest bin (the farthest within 250 was
    -- the other settlement's, whose turrets destroyed the holder).
    local far, fd
    for _, bin in pairs(surface().find_entities_filtered{name = "lp-bin", force = FORCE, position = S.lander_at, radius = 250}) do
      local d = (bin.position.x - S.lander_at[1]) ^ 2 + (bin.position.y - S.lander_at[2]) ^ 2
      if not fd or d < fd then far, fd = bin, d end
    end
    if far then
      local p = surface().find_non_colliding_position("gun-turret", far.position, 8, 1)
      S.holder = p and surface().create_entity{name = "gun-turret", position = p, force = "player"}
    end
    S.captured0 = st.captured
    S.lost0 = st.lost
  end)
  schedule(STRIKE + 4 * 3600, function()
    local st = lp("stats", storage.id)
    if S.holder and S.holder.valid then
      for _, l in ipairs(lp("debug_modules", storage.id, {S.holder.position.x, S.holder.position.y}, 15)) do info("fall: module " .. l) end
    end
    check("fall: an outpost is taken by holding it", st.captured > (S.captured0 or 0),
      string.format("%d captured (a holder %s)", st.captured - (S.captured0 or 0), S.holder and "placed" or "not placed"))
    check("fall: nothing is rebuilt", st.rebuild_pending == 0 and st.queue == 0,
      st.rebuild_pending .. " rebuilds pending, " .. st.queue .. " queued")
  end)
end

-- Circuit: an attack automated by one decider. Troopers come two at a time; a faction laser turret stands 40
-- tiles from the beacon; a decider wired to the beacon sends A while S (the squad, on the beacon's report) is
-- at least 8. The turret must be untouched while the squad is smaller, A appear only at 8, and the turret fall.
scenarios.circuit = function()
  local red = defines.wire_connector_id.circuit_red
  local function sig(name) return {type = "virtual", name = name} end
  local function put(name, x, y, force)
    return surface().create_entity{name = name, position = {x, y}, force = force or "player", raise_built = true}
  end
  schedule(60, function()
    lp("debug_tune", {raids_off = true})
    flatten(-30, -60, 90, 30)
    game.forces.player.technologies["lp-command-bandwidth-1"].researched = true
    S.barracks = put("lp-barracks", 0.5, 0.5)
    put("electric-energy-interface", 4, 1)
    put("medium-electric-pole", 2.5, 2.5)
    put("lp-command-relay", 0.5, 6.5)
    put("medium-electric-pole", 2.5, 5.5)
    S.beacon = put("lp-rally-beacon", 10.5, -15.5)
    -- A decider needs power: poles out to it.
    put("medium-electric-pole", 6.5, -5.5); put("medium-electric-pole", 9.5, -12.5); put("medium-electric-pole", 12.5, -19.5)
    S.decider = put("decider-combinator", 10.5, -19)
    S.decider.get_wire_connector(defines.wire_connector_id.combinator_input_red, true).connect_to(
      S.beacon.get_wire_connector(red, true))
    S.decider.get_wire_connector(defines.wire_connector_id.combinator_output_red, true).connect_to(
      S.beacon.get_wire_connector(red, true))
    S.decider.get_or_create_control_behavior().parameters = {
      conditions = {{first_signal = sig("signal-S"), constant = 8, comparator = "≥"}},
      outputs = {{signal = sig("signal-A"), constant = 1, copy_count_from_input = false}}}
    -- The faction's turret, powered on its own.
    S.turret = put("lp-turret", 50.5, -15.5, FORCE)
    put("electric-energy-interface", 54, -15, FORCE)
    put("medium-electric-pole", 52.5, -13.5, FORCE)
    S.orders = 0
    S.log = {}
  end)
  for t = 120, 120 + 150 * 60, 20 * 60 do
    schedule(t, function()
      if S.orders < 10 then
        S.orders = S.orders + S.barracks.get_inventory(defines.inventory.crafter_output).insert{name = "lp-trooper-order", count = 2}
      end
    end)
  end
  for t = 300, 120 + 240 * 60, 60 do
    schedule(t, function()
      local function net(name) return S.beacon.get_signal(sig(name), red) or 0 end
      local s, a, tt = net("signal-S"), net("signal-A"), net("signal-T")
      local hurt = S.turret.valid and S.turret.health < S.turret.max_health
      if a > 0 and not S.attack_at then S.attack_at = s end
      -- Before the first A only: losses in the fight take S below 8 again.
      if not S.attack_at and (hurt or not S.turret.valid) then S.early = true end
      if tt > 0 then S.saw_turret = true end
      if game.tick % 1200 == 300 then table.insert(S.log, string.format("t%d S=%d A=%d T=%d", game.tick / 60, s, a, tt)) end
    end)
  end
  -- Field repair: a trooper hurt by the barracks is whole again 30 s later (2% a second).
  schedule(120 + 30 * 60, function()
    S.patient = surface().find_entities_filtered{name = "lp-trooper", force = "player", position = {0.5, 0.5}, radius = 30}[1]
    if S.patient then S.patient.health = 30 end
  end)
  schedule(120 + 60 * 60, function()
    S.healed = S.patient and S.patient.valid and S.patient.health
  end)
  schedule(120 + 240 * 60, function()
    check("circuit: a hurt trooper by the barracks was mended", S.healed and S.healed >= 100, tostring(S.healed) .. " of 120")
    info("circuit: " .. table.concat(S.log, ", "))
    check("circuit: the report showed the turret in reach", S.saw_turret == true, tostring(S.saw_turret))
    check("circuit: nothing attacked before the squad was 8", not S.early, tostring(S.early))
    check("circuit: the decider sent A at 8", S.attack_at ~= nil and S.attack_at >= 8, tostring(S.attack_at))
    check("circuit: the turret fell", not S.turret.valid, S.turret.valid and "standing" or "destroyed")
  end)
end

-- Ops: the faction raids by value, not by distance. Near the settlement, on the player's side: a defended
-- cluster (4 armed gun turrets, 2 assemblers) 110 tiles out and a valuable undefended one (2 command relays,
-- a barracks) 170 out. The first raid must go for the valuable one and destroy it; a raid on the defended one
-- (once the garrison can afford it) must be sized to its four turrets (16).
-- Abort: the valuable cluster only; once the raid is under way, 6 armed gun turrets go up round it: the raid
-- must abort, bring survivors home and remember the target as defended.
local function ops_setup(with_defended)
  schedule(60, function()
    lp("debug_depot", storage.id, 4000)
    lp("debug_depot", storage.id, 0)
  end)
  schedule(120, function()
    local lander = surface().find_entities_filtered{name = "lp-lander", force = FORCE}[1]
    local L = lander.position
    local len = math.sqrt(L.x * L.x + L.y * L.y)
    local ux, uy = -L.x / len, -L.y / len
    local px, py = -uy, ux
    local function cluster(d, side)
      local c = {math.floor(L.x + ux * d + px * side), math.floor(L.y + uy * d + py * side)}
      flatten(c[1] - 14, c[2] - 14, c[1] + 14, c[2] + 14)
      return c
    end
    local function put(name, c, x, y, ammo)
      local e = surface().create_entity{name = name, position = {c[1] + x, c[2] + y}, force = "player"}
      if e and ammo then e.insert{name = "piercing-rounds-magazine", count = 200} end
      return e
    end
    S.A = cluster(170, 40)
    S.valuable = {put("lp-command-relay", S.A, -3.5, 0.5), put("lp-command-relay", S.A, 3.5, 0.5),
      put("lp-barracks", S.A, 0.5, 6.5)}
    if with_defended then
      S.B = cluster(110, -40)
      S.defended = {}
      for _, p in ipairs({{-6, -6}, {6, -6}, {-6, 6}, {6, 6}}) do put("gun-turret", S.B, p[1], p[2], true) end
      for _, p in ipairs({{-2, 0}, {2, 0}}) do table.insert(S.defended, put("assembling-machine-1", S.B, p[1] + 0.5, p[2] + 0.5)) end
    end
    info(string.format("ops: valuable cluster at %d,%d%s", S.A[1], S.A[2],
      S.B and string.format(", defended cluster at %d,%d", S.B[1], S.B[2]) or ""))
  end)
end

scenarios.ops = function()
  ops_setup(true)
  schedule(END - 60, function()
    local o = lp("stats", storage.id).ops
    local left = 0
    for _, e in ipairs(S.valuable) do if e.valid then left = left + 1 end end
    local spared = 0
    for _, e in ipairs(S.defended) do if e.valid and e.health == e.max_health then spared = spared + 1 end end
    local kinds = {}
    for _, l in ipairs(o.log) do table.insert(kinds, l.kind .. " " .. l.outcome .. " " .. l.back .. "/" .. l.launched) end
    info("ops: " .. table.concat(kinds, "; ") .. "; known " .. o.known)
    check("ops: a raid was launched", o.launched > 0, o.launched)
    check("ops: it went for the valuable target", o.log[1] and (o.log[1].kind == "lp-command-relay" or o.log[1].kind == "lp-barracks"),
      o.log[1] and o.log[1].kind or "none finished")
    check("ops: it destroyed it", left <= 1, (3 - left) .. " of 3 destroyed")
    local raids = {}
    for _, l in ipairs(o.log) do if l.op == "raid" then table.insert(raids, l) end end
    local second = raids[2]
    check("ops: a raid on the defended cluster was sized to it", not second or second.launched >= 16,
      second and (second.kind .. " with " .. second.launched) or "none")
  end)
end

scenarios.abort = function()
  ops_setup(false)
  for t = 600, END - 3600, 60 do
    schedule(t, function()
      if S.armed then return end
      local o = lp("stats", storage.id).ops
      if o.op then
        S.armed = game.tick
        S.garrison_at = lp("stats", storage.id).garrison
        for _, p in ipairs({{-9, -9}, {9, -9}, {-9, 9}, {9, 9}, {0, -11}, {0, 11}}) do
          local e = surface().create_entity{name = "gun-turret", position = {S.A[1] + p[1], S.A[2] + p[2]}, force = "player"}
          if e then e.insert{name = "piercing-rounds-magazine", count = 200} end
        end
        info(string.format("abort: raid under way (%s), six turrets up at tick %d", o.op, game.tick))
      end
    end)
  end
  schedule(END - 60, function()
    local o = lp("stats", storage.id).ops
    local l = o.log[1]
    check("abort: a raid was launched", o.launched > 0, o.launched)
    check("abort: it aborted", o.aborted > 0, o.aborted .. " aborted, " .. o.done .. " done")
    check("abort: it turned back unhurt", l and l.back == l.launched, l and (l.back .. " of " .. l.launched) or "none")
    -- A siege may follow (too strong to raid is what sieges are for); another raid may not.
    check("abort: it did not raid again within the cooldown", o.launched - o.sieges == 1,
      (o.launched - o.sieges) .. " raids, " .. o.sieges .. " sieges")
  end)
end

-- Mortar (spike): does a faction mortar with shells find and shell a player turret 30 tiles away on its own?
scenarios.mortar = function()
  schedule(60, function()
    flatten(150, -40, 230, 40)
    S.m = surface().create_entity{name = "lp-mortar", position = {160, 0}, force = FORCE}
    S.m.insert{name = "lp-mortar-shell", count = 20}
    S.t = surface().create_entity{name = "gun-turret", position = {190, 0}, force = "player"}
    S.far = surface().create_entity{name = "gun-turret", position = {205, 0}, force = "player"}
    S.wall = surface().create_entity{name = "stone-wall", position = {188, 4}, force = "player"}
  end)
  schedule(60 + 60 * 60, function()
    local shells = S.m.valid and S.m.get_inventory(defines.inventory.artillery_turret_ammo).get_item_count("lp-mortar-shell") or -1
    info(string.format("mortar: %d shells left; turret at 30: %s; turret at 45: %s; wall: %s", shells,
      S.t.valid and string.format("%.0f/%.0f", S.t.health, S.t.max_health) or "destroyed",
      S.far.valid and string.format("%.0f/%.0f", S.far.health, S.far.max_health) or "destroyed",
      S.wall.valid and string.format("%.0f/%.0f", S.wall.health, S.wall.max_health) or "destroyed"))
    check("mortar: it fired on its own", shells < 20, shells .. " of 20 left")
    check("mortar: the turret in range was hit", not S.t.valid or S.t.health < S.t.max_health, "")
    check("mortar: the one out of range was not", S.far.valid and S.far.health == S.far.max_health, "")
  end)
end

-- Bombard: a fortified player position the faction cannot raid (8 armed gun turrets need 44 units) draws a
-- siege. A hauler must carry a mortar out, deploy it beyond every player turret's reach, shell the position,
-- and pack up when the shells are spent; no mortar is left behind.
scenarios.bombard = function()
  schedule(60, function()
    lp("debug_depot", storage.id, 4000)
    lp("debug_depot", storage.id, 0)
  end)
  schedule(120, function()
    local lander = surface().find_entities_filtered{name = "lp-lander", force = FORCE}[1]
    local L = lander.position
    local len = math.sqrt(L.x * L.x + L.y * L.y)
    local c = {math.floor(L.x - L.x / len * 150), math.floor(L.y - L.y / len * 150)}
    flatten(c[1] - 20, c[2] - 20, c[1] + 20, c[2] + 20)
    S.c = c
    S.turrets = {}
    for x = -12, 12 do for y = -12, 12 do
      if math.abs(x) == 12 or math.abs(y) == 12 then
        surface().create_entity{name = "stone-wall", position = {c[1] + x, c[2] + y}, force = "player"}
      end
    end end
    for _, p in ipairs({{-9, -9}, {9, -9}, {-9, 9}, {9, 9}, {0, -9}, {0, 9}, {-9, 0}, {9, 0}}) do
      local t = surface().create_entity{name = "gun-turret", position = {c[1] + p[1], c[2] + p[2]}, force = "player"}
      t.insert{name = "piercing-rounds-magazine", count = 200}
      table.insert(S.turrets, t)
    end
    for _, p in ipairs({{-3, -3}, {3, 3}}) do
      surface().create_entity{name = "assembling-machine-1", position = {c[1] + p[1] + 0.5, c[2] + p[2] + 0.5}, force = "player"}
    end
    info(string.format("bombard: walled position with 8 turrets at %d,%d", c[1], c[2]))
  end)
  for t = 600, END, 300 do
    schedule(t, function()
      local o = lp("stats", storage.id).ops
      if o.mortar then
        S.mortar_at = o.mortar
        local nearest = math.huge
        for _, tt in pairs(surface().find_entities_filtered{force = "player", type = "ammo-turret",
          position = o.mortar, radius = 80}) do
          nearest = math.min(nearest, math.sqrt((tt.position.x - o.mortar[1]) ^ 2 + (tt.position.y - o.mortar[2]) ^ 2))
        end
        S.mortar_gap = math.min(S.mortar_gap or math.huge, nearest)
      end
    end)
  end
  schedule(END - 60, function()
    local o = lp("stats", storage.id).ops
    local hurt = 0
    for _, t in ipairs(S.turrets) do if not t.valid or t.health < t.max_health then hurt = hurt + 1 end end
    local siege
    for _, l in ipairs(o.log) do if l.op == "siege" then siege = l end end
    info("bombard: " .. serpent.line(o.log))
    check("bombard: a siege was mounted", o.sieges > 0, o.sieges .. " sieges, " .. o.launched .. " operations")
    check("bombard: the mortar stood beyond the turrets' reach", S.mortar_gap and S.mortar_gap > 18,
      S.mortar_gap and string.format("%.1f tiles from the nearest turret", S.mortar_gap) or "never deployed")
    check("bombard: it hit the position", hurt > 0, hurt .. " of 8 turrets hurt or destroyed")
    check("bombard: it packed up when spent or done", siege and (siege.outcome == "spent" or siege.outcome == "done")
      and surface().count_entities_filtered{name = "lp-mortar"} == 0,
      siege and (siege.outcome .. ", " .. tostring(siege.shells) .. " shells") or "not finished")
  end)
end

-- Control: the command tool's orders, without a mouse. Six troopers hold at their beacon. Picked by hand and
-- ordered 60 tiles east they go there, and the beacon's A (with a faction turret in its reach) does not pull
-- them; clicked on that turret they destroy it; released, they return to the beacon's command.
scenarios.control = function()
  local function put(name, x, y, force)
    return surface().create_entity{name = name, position = {x, y}, force = force or "player", raise_built = true}
  end
  local function near(x, y, r)
    return surface().count_entities_filtered{name = "lp-trooper", force = "player", position = {x, y}, radius = r}
  end
  schedule(60, function()
    lp("debug_tune", {raids_off = true})
    flatten(-30, -60, 110, 30)
    game.forces.player.technologies["lp-command-bandwidth-1"].researched = true
    S.barracks = put("lp-barracks", 0.5, 0.5)
    put("electric-energy-interface", 4, 1)
    put("medium-electric-pole", 2.5, 2.5)
    put("lp-command-relay", 0.5, 6.5)
    put("medium-electric-pole", 2.5, 5.5)
    S.beacon = put("lp-rally-beacon", 10.5, -15.5)
    S.barracks.get_inventory(defines.inventory.crafter_output).insert{name = "lp-trooper-order", count = 6}
    -- A faction turret 45 tiles from the beacon, powered on its own: in the beacon's reach.
    S.turret = put("lp-turret", 55.5, -15.5, FORCE)
    S.turret_max = S.turret.max_health
    put("electric-energy-interface", 59, -15, FORCE)
    put("medium-electric-pole", 57.5, -13.5, FORCE)
  end)
  schedule(60 + 30 * 60, function()
    S.picked = lp("debug_select", {{-10, -30}, {30, 10}})
    lp("debug_order", {{10, 14}, {12, 16}}, false)      -- move: to 11,15, south, away from the turret
    -- The beacon says A meanwhile: hand-picked units must not answer it.
    S.beacon.get_or_create_control_behavior().get_section(1).filters =
      {{value = {type = "virtual", name = "signal-A", quality = "normal"}, min = 1}}
  end)
  schedule(60 + 60 * 60, function()
    S.moved = near(11, 15, 8)
    S.turret_hp = S.turret.valid and S.turret.health or 0
    lp("debug_order", {{55, -16}, {56, -15}}, false)    -- a click on the turret: attack it
  end)
  schedule(60 + 120 * 60, function()
    S.destroyed = not S.turret.valid
    S.released = lp("debug_release", {{-50, -60}, {120, 40}})
    S.beacon.get_or_create_control_behavior().get_section(1).filters = {}
  end)
  schedule(60 + 160 * 60, function()
    check("control: six picked", S.picked == 6, tostring(S.picked))
    check("control: they moved where clicked", S.moved >= 5, S.moved .. " of 6 there")
    check("control: the beacon's A did not pull them", S.turret_hp == S.turret_max,
      string.format("turret at %.0f before the attack order", S.turret_hp))
    check("control: a click on the turret destroyed it", S.destroyed, tostring(S.destroyed))
    check("control: released, they returned to the beacon", S.released == near(10.5, -15.5, 14) and S.released > 0,
      S.released .. " released, " .. near(10.5, -15.5, 14) .. " at the beacon")
  end)
end

-- Contact: first contact at real clocks, a timeline to read rather than a verdict. A player base as of the
-- first launch at spawn (production, power, labs, 16 laser turrets in four corner clusters, laser research)
-- and a mining outpost 130 tiles towards the faction with a power line home. The faction lands as it does in
-- a game and lands again on its own clock. Every 5 minutes one line of timeline.jsonl (scripts/timeline.py).
-- Variants (LP_MIX): "" a passive player; "robots" a careful one: losses leave ghosts that construction robots
-- rebuild from a storage of spares (nine roboports cover the base, not the outpost); "walled" the same with a
-- wall and laser perimeter round the base.
scenarios.contact = function()
  local careful = params.mix == "robots" or params.mix == "walled"
  -- The player's base goes down at the strike (minute 20 by default), before the faction can have seen it
  -- (the first raid came at minute 38): every variant then shares one fork of the faction's growth.
  local AT = params.strike > 0 and STRIKE or 30
  local CATEGORY = {["assembling-machine"] = "production", furnace = "production", lab = "production",
    ["mining-drill"] = "outpost", ["electric-pole"] = "power", roboport = "logistics", radar = "logistics",
    ["electric-turret"] = "turrets", ["ammo-turret"] = "turrets", wall = "walls"}
  local function put(name, x, y)
    local p = surface().find_non_colliding_position(name, {x, y}, 4, 0.5)
    return p and surface().create_entity{name = name, position = p, force = "player"}
  end
  local function census()
    local out = {}
    for _, e in pairs(surface().find_entities_filtered{force = "player"}) do
      local c = CATEGORY[e.type]
      if c then out[c] = (out[c] or 0) + 1 end
    end
    return out
  end
  schedule(AT, function()
    flatten(-78, -78, 78, 78)
    local pf = game.forces.player
    pf.set_ammo_damage_modifier("laser", 0.4)
    pf.set_gun_speed_modifier("laser", 0.4)
    put("electric-energy-interface", 0, 0); put("electric-energy-interface", 4, 0)
    for gx = 0, 7 do for gy = 0, 7 do put("assembling-machine-2", -40 + gx * 5, -40 + gy * 5) end end
    for k = 0, 19 do put("electric-furnace", -40 + k * 4, 5) end
    for k = 0, 9 do put("lab", 5 + k * 4, -40) end
    for x = -40, 40, 18 do for y = -40, 40, 18 do put("substation", x, y) end end
    put("roboport", 20, 20); put("roboport", 30, 20); put("radar", 20, 30)
    for _, c in ipairs({{-60, -60}, {60, -60}, {-60, 60}, {60, 60}}) do
      put("substation", c[1], c[2])
      for _, d in ipairs({{-3, -3}, {3, -3}, {-3, 3}, {3, 3}}) do put("laser-turret", c[1] + d[1], c[2] + d[2]) end
    end
    for x = -60, 60, 18 do put("substation", x, -60); put("substation", x, 60); put("substation", -60, x); put("substation", 60, x) end
    if careful then
      pf.create_ghost_on_entity_death = true
      for _, x in ipairs({-45, 0, 45}) do for _, y in ipairs({-45, 0, 45}) do
        local r = put("roboport", x, y)
        if r then
          r.insert{name = "construction-robot", count = 30}
          r.insert{name = "repair-pack", count = 100}
        end
      end end
      local store = put("storage-chest", 6, 6)
      for name, n in pairs({["substation"] = 60, ["assembling-machine-2"] = 40, ["electric-furnace"] = 20, ["lab"] = 10,
        ["laser-turret"] = 40, ["stone-wall"] = 400, ["big-electric-pole"] = 10, ["roboport"] = 5, ["radar"] = 2}) do
        store.insert{name = name, count = n}
      end
    end
    if params.mix == "walled" then
      for k = -70, 70 do
        for _, p in ipairs({{k, -70}, {k, 70}, {-70, k}, {70, k}}) do
          surface().create_entity{name = "stone-wall", position = p, force = "player"}
        end
      end
      for k = -60, 60, 12 do
        for _, p in ipairs({{k, -66}, {k, 66}, {-66, k}, {66, k}}) do put("laser-turret", p[1], p[2]) end
      end
    end
  end)
  schedule(AT + 120, function()
    local lander = surface().find_entities_filtered{name = "lp-lander", force = FORCE}[1]
    local L = lander.position
    local len = math.sqrt(L.x * L.x + L.y * L.y)
    local ux, uy = L.x / len, L.y / len
    local o = {ux * 130, uy * 130}
    flatten(math.floor(o[1]) - 16, math.floor(o[2]) - 16, math.floor(o[1]) + 16, math.floor(o[2]) + 16)
    for k = 0, 7 do put("electric-mining-drill", o[1] - 9 + (k % 4) * 5, o[2] - 4 + math.floor(k / 4) * 6) end
    put("substation", o[1], o[2] + 1); put("substation", o[1] - 9, o[2] + 1); put("substation", o[1] + 9, o[2] + 1)
    put("laser-turret", o[1] - 12, o[2] - 10); put("laser-turret", o[1] + 12, o[2] - 10)
    for d = 66, 124, 28 do put("big-electric-pole", ux * d, uy * d) end
    S.outpost = o
    S.start = census()
    info(string.format("contact: base at spawn, outpost at %.0f,%.0f, faction lander at %.0f,%.0f (%.0f tiles out)",
      o[1], o[2], L.x, L.y, len))
    info("contact: player at start " .. serpent.line(S.start))
  end)
  for t = 300 * 60, END, 300 * 60 do
    schedule(t, function()
      local f = lp("faction")
      local row = {minute = game.tick / 3600, landings = f.landings, tier = f.tier, exported = f.exported,
        settlements = 0, garrison = 0, turrets = 0, parts_rate = 0, raids = 0, sieges = 0, done = 0, aborted = 0,
        known = 0, player = census()}
      for _, id in ipairs(lp("bases")) do
        local st = lp("stats", id)
        if st and st.lander then
          row.settlements = row.settlements + 1
          row.garrison = row.garrison + st.garrison + (st.patrol or 0)
          row.turrets = row.turrets + st.turrets
          row.parts_rate = row.parts_rate + (st.rate_parts or 0)
        end
        if st and st.ops then
          row.raids = row.raids + st.ops.launched - st.ops.sieges
          row.sieges = row.sieges + st.ops.sieges
          row.done = row.done + st.ops.done
          row.aborted = row.aborted + st.ops.aborted
          row.known = row.known + st.ops.known
        end
      end
      helpers.write_file("landing-party/timeline.jsonl", helpers.table_to_json(row) .. "\n", true)
    end)
  end
  schedule(END - 60, function()
    local now = census()
    info("contact: player at the end " .. serpent.line(now))
    check("contact: a timeline was written", true, "")
  end)
end

-- Rivals: two corporations side by side. Serenity lands as usual; Grubstake lands as the next settlement
-- (its own force). Both get a depot; nothing else is scripted. They must be different forces, and at least one
-- of them must mount an operation against the other's buildings and do damage.
scenarios.rivals = function()
  schedule(60, function() lp("debug_depot", storage.id, 3000) end)
  schedule(120, function()
    S.other = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    if S.other then lp("debug_depot", S.other, 3000) end
  end)
  schedule(END - 60, function()
    local a, b = lp("stats", storage.id), S.other and lp("stats", S.other)
    local against = 0
    local lines_ = {}
    for _, st in ipairs({a, b}) do
      for _, l in ipairs(st and st.ops.log or {}) do
        table.insert(lines_, string.format("%s: %s %s on %s of %s, %d/%d back", st.corp, l.op, l.outcome, l.kind,
          tostring(l.owner), l.back, l.launched))
        if l.owner and l.owner ~= st.force and l.owner:sub(1, 3) == "lp-" then against = against + 1 end
      end
    end
    info("rivals: " .. table.concat(lines_, "; "))
    check("rivals: two corporations, two forces", b ~= nil and a.force ~= b.force,
      a.force .. " and " .. (b and b.force or "none"))
    check("rivals: they raided each other", against > 0, against .. " operations against a rival")
    -- Blood on either side: units lost or buildings razed (a fortified rival can win every fight).
    local lost = a.units_lost + (b and b.units_lost or 0) + a.lost + (b and b.lost or 0)
    check("rivals: they fought", lost > 0, string.format("%d and %d units lost, %d and %d buildings",
      a.units_lost, b and b.units_lost or 0, a.lost, b and b.lost or 0))
  end)
end

-- Duel: raw exchange rates in open ground, away from the settlement. Ten troopers against ten drone
-- infantry, and ten troopers against two tanks, each pair 30 tiles apart and ordered at each other.
scenarios.duel = function()
  S.duels = {}
  local function spawn(name, force, n, at)
    local out = {}
    for k = 1, n do
      local p = surface().find_non_colliding_position(name, {at[1] + (k % 5) * 2, at[2] + math.floor(k / 5) * 2}, 10, 0.5)
      table.insert(out, surface().create_entity{name = name, position = p, force = force})
    end
    return out
  end
  local function fight(us, them, at)
    for _, u in ipairs(us) do
      u.commandable.set_command{type = defines.command.attack_area, destination = at, radius = 30,
        distraction = defines.distraction.by_anything}
    end
  end
  schedule(120, function()
    for i, foe in ipairs({{"lp-infantry", 10}, {"lp-tank", 2}}) do
      local x, y = 200, -200 + i * 120
      flatten(x - 30, y - 30, x + 60, y + 30)
      local a = spawn("lp-trooper", "player", 10, {x, y})
      local b = spawn(foe[1], FORCE, foe[2], {x + 30, y})
      fight(a, b, {x + 30, y}); fight(b, a, {x, y})
      S.duels[i] = {foe = foe[1], a = a, b = b}
    end
  end)
  schedule(120 + 90 * 60, function()
    for _, d in ipairs(S.duels) do
      local la, lb, hb = 0, 0, 0
      for _, u in ipairs(d.a) do if u.valid then la = la + 1 end end
      for _, u in ipairs(d.b) do if u.valid then lb = lb + 1; hb = hb + u.health / u.max_health end end
      info(string.format("duel: 10 troopers vs %d %s: %d troopers and %d %s left (%.0f%% of their health)", #d.b,
        d.foe, la, lb, d.foe, 100 * hb / #d.b))
    end
    check("duel: ran", #S.duels == 2, #S.duels)
  end)
end

-- Siege: a fought capture. The settlement grows with its whole army, except raids (the test's base has no
-- defences); responses, patrols and interceptors stay on. At the strike a barracks beyond the settlement
-- trains params.units troopers (default 20) at once. A beacon at a staging point out of laser reach of the
-- outpost nearest the barracks is set to A a minute later: the squad clears what fights within the
-- beacon's reach, then stands on the nearest outpost. Measures what a squad of that size achieves.
scenarios.siege = function()
  local ARMY = {"lp-trooper", "lp-breacher", "lp-battle-tank"}
  local ORDER = {["lp-trooper"] = "lp-trooper-order", ["lp-breacher"] = "lp-breacher-order",
    ["lp-battle-tank"] = "lp-battle-tank-order"}
  local POP = {["lp-trooper"] = 1, ["lp-breacher"] = 1, ["lp-battle-tank"] = 4}
  local function alive_troopers() return surface().count_entities_filtered{name = ARMY, force = "player"} end
  local red = defines.wire_connector_id.circuit_red
  -- The squad: LP_MIX "troopers,breachers,tanks" (default: LP_UNITS troopers, else 20).
  local want = {}
  local k = 0
  for n in (params.mix or ""):gmatch("%d+") do k = k + 1; want[ARMY[k]] = tonumber(n) end
  if k == 0 then want["lp-trooper"] = params.units > 0 and params.units or 20 end
  local SQUAD, POPULATION = 0, 0
  for name, n in pairs(want) do SQUAD = SQUAD + n; POPULATION = POPULATION + n * POP[name] end
  local MIX = string.format("%d troopers, %d breachers, %d tanks", want["lp-trooper"] or 0, want["lp-breacher"] or 0,
    want["lp-battle-tank"] or 0)
  schedule(60, function() lp("debug_tune", {raids_off = true}) end)
  -- A depot and parts from the start, as in lively: a garrison stands by the strike.
  schedule(200, function() lp("debug_depot", storage.id, 2000) end)
  schedule(STRIKE, function()
    local lander = surface().find_entities_filtered{name = "lp-lander", force = FORCE}[1]
    -- The base: away from the settlement, on the side of spawn (the player's side).
    local away = {-lander.position.x, -lander.position.y}
    local len0 = math.sqrt(away[1] ^ 2 + away[2] ^ 2)
    local a
    for d = 120, 400, 20 do
      a = {lander.position.x + away[1] / len0 * d, lander.position.y + away[2] / len0 * d}
      if surface().count_entities_filtered{force = FORCE, position = a, radius = 80} == 0 then break end
    end
    -- The target: the outpost nearest the base, defended or not (the player's first move).
    local target, td
    for _, bin in pairs(lp_entities("lp-bin")) do
      local d = (bin.position.x - a[1]) ^ 2 + (bin.position.y - a[2]) ^ 2
      if not td or d < td then target, td = bin, d end
    end
    S.target = {target.position.x, target.position.y}
    -- Staging: on the line from the outpost towards the player's side, the first point no faction turret
    -- reaches; a forward base 15 tiles behind it, on ground the faction has not built. (With the barracks far
    -- off, a squad walking to a staging point inside the settlement lost 33 of 40 before the assault, 4242.)
    local dx, dy = a[1] - S.target[1], a[2] - S.target[2]
    local len = math.sqrt(dx * dx + dy * dy)
    local stage
    for d = 30, 200, 5 do
      stage = {S.target[1] + dx / len * d, S.target[2] + dy / len * d}
      local fwd = {S.target[1] + dx / len * (d + 15), S.target[2] + dy / len * (d + 15)}
      if surface().count_entities_filtered{name = "lp-turret", force = FORCE, position = stage, radius = 40} == 0
        and surface().count_entities_filtered{force = FORCE, position = fwd, radius = 30} == 0
        and surface().count_tiles_filtered{position = fwd, radius = 30, collision_mask = "water_tile"} == 0 then
        S.stage_d = d
        a = {math.floor(fwd[1]), math.floor(fwd[2])}
        break
      end
    end
    S.base_at = a
    S.stage = stage
    flatten(math.floor(a[1]) - 28, math.floor(a[2]) - 6, math.floor(a[1]) + 42, math.floor(a[2]) + 12)
    local function put(name, x, y)
      return surface().create_entity{name = name, position = {x, y}, force = "player", raise_built = true}
    end
    -- One barracks a unit type, side by side; relays for the whole squad below them.
    S.barracks = {}
    for i, name in ipairs(ARMY) do
      local x = a[1] - 8.5 + 6 * i
      local b = put("lp-barracks", x, a[2] + 0.5)
      b.set_recipe(ORDER[name])
      S.barracks[name] = b
      put("medium-electric-pole", x + 2, a[2] + 2.5)
    end
    put("electric-energy-interface", a[1] + 14, a[2] + 1)
    for k = 1, 3 do game.forces.player.technologies["lp-command-bandwidth-" .. k].researched = true end
    for k = 1, math.ceil(POPULATION / 10) do
      put("lp-command-relay", a[1] - 25.5 + 4 * k, a[2] + 7.5)
    end
    for x = -23.5, 40, 7 do put("medium-electric-pole", a[1] + x, a[2] + 5.5) end
    S.beacon = put("lp-rally-beacon", stage[1], stage[2])
    S.cc = put("constant-combinator", stage[1] - 2, stage[2])
    S.cc.get_wire_connector(red, true).connect_to(S.beacon.get_wire_connector(red, true))
    -- Finished orders, ten at a time (a stack): this tests the fight, not the recipe.
    S.orders = {}
    S.feed = function()
      for name, n in pairs(want) do
        local b = S.barracks[name]
        local done = S.orders[name] or 0
        if b.valid and done < n then
          local out = b.get_inventory(defines.inventory.crafter_output)
          S.orders[name] = done + out.insert{name = ORDER[name], count = math.min(10, n - done)}
        end
      end
    end
    S.feed()
    S.turrets0 = surface().count_entities_filtered{name = "lp-turret", force = FORCE, position = stage, radius = 60}
    S.st0 = lp("stats", storage.id)
    info(string.format("siege: %s; outpost at %.0f,%.0f; staging %d tiles out; %d faction turrets within 60; garrison %d",
      MIX, S.target[1], S.target[2], S.stage_d or -1, S.turrets0, S.st0.garrison or -1))
  end)
  -- A careful player: the squad gathers at the staging point (holding), then the rally point is steered by X
  -- and Y onto the defending turret nearest our side, on A, one turret at a time; with no turret left within
  -- 60 of the outpost, onto the outpost, on O. (Moving the beacon itself with a 50-tile ring that overlapped
  -- a compound's laser cover lost every squad.)
  local function signals(list)
    local f = {}
    for name, v in pairs(list) do
      table.insert(f, {value = {type = "virtual", name = name, quality = "normal"}, min = v})
    end
    local cb = S.cc.get_or_create_control_behavior()
    local sec = cb.get_section(1) or cb.add_section()
    sec.filters = f
  end
  schedule(STRIKE + 2 * 3600, function()
    S.trained = lp("army").trained
    S.go = game.tick
  end)
  for t = STRIKE + 2 * 3600, END, 300 do
    schedule(t, function()
      if not S.go or not S.beacon.valid or not S.cc.valid then return end
      local b = S.beacon.position
      if S.aim and S.aim.valid then return end
      local best, bd
      for _, x in pairs(surface().find_entities_filtered{name = "lp-turret", force = FORCE, position = S.target, radius = 60}) do
        local d = (x.position.x - b.x) ^ 2 + (x.position.y - b.y) ^ 2
        if not bd or d < bd then best, bd = x, d end
      end
      if best then
        S.aim = best
        S.aims = (S.aims or 0) + 1
        signals({["signal-A"] = 1, ["signal-X"] = math.floor(best.position.x - b.x), ["signal-Y"] = math.floor(best.position.y - b.y)})
        info(string.format("siege t+%ds: aim %d at the turret at %.0f,%.0f (%d units left)", (game.tick - S.go) / 60,
          S.aims, best.position.x, best.position.y, alive_troopers()))
      elseif not S.moved then
        S.moved = game.tick
        S.target_turrets0 = 0
        signals({["signal-O"] = 1, ["signal-X"] = math.floor(S.target[1] - b.x), ["signal-Y"] = math.floor(S.target[2] - b.y)})
        info(string.format("siege t+%ds: no turret within 60 of the outpost; occupy (%d units left)",
          (game.tick - S.go) / 60, alive_troopers()))
      end
    end)
  end
  for t = STRIKE + 300, STRIKE + 2 * 3600, 300 do schedule(t, function() if S.feed then S.feed() end end) end
  -- Every 2 s: the troopers and the faction's units near the fight, for the animation.
  for t = STRIKE + 60, END, 120 do
    schedule(t, function()
      if not S.target then return end
      local c = S.target
      local units = surface().find_entities_filtered{position = c, radius = 200, type = {"unit", "spider-unit"}}
      local frame = {tick = game.tick, units = {}}
      for _, u in pairs(units) do table.insert(frame.units, {u.name, u.position.x, u.position.y, u.force.name}) end
      if S.go and game.tick % 600 < 120 and alive_troopers() > 0 then
        info(string.format("siege t+%ds orders %s", (game.tick - S.go) / 60, serpent.line(lp("army").orders)))
      end
      helpers.write_file("landing-party/life.jsonl", helpers.table_to_json(frame) .. "\n", true)
    end)
  end
  schedule(STRIKE + 12 * 3600, function()
    local st = lp("stats", storage.id)
    local alive = alive_troopers()
    local turrets = surface().count_entities_filtered{name = "lp-turret", force = FORCE, position = S.stage, radius = 60}
    if S.moved then
      metric("siege_target_turrets_before", S.target_turrets0)
      metric("siege_target_turrets_after", surface().count_entities_filtered{name = "lp-turret", force = FORCE,
        position = S.target, radius = 50})
    end
    local there = {}
    for _, e in pairs(surface().find_entities_filtered{position = S.target, radius = 20}) do
      if e.force.name ~= "neutral" then
        local k = e.force.name:sub(1, 4) .. ":" .. e.name
        there[k] = (there[k] or 0) + 1
      end
    end
    info("siege: at the outpost at the end " .. serpent.line(there))
    for _, l in ipairs(lp("debug_modules", storage.id, S.target, 30)) do info("siege: module " .. l) end
    metric("siege_squad", SQUAD)
    metric("siege_trained", S.trained)
    metric("siege_alive", alive)
    metric("siege_turrets_before", S.turrets0)
    metric("siege_turrets_after", turrets)
    metric("siege_responses", st.responses - S.st0.responses)
    metric("siege_units_lost", st.units_lost - S.st0.units_lost)
    metric("siege_captured", (st.captured or 0) - (S.st0.captured or 0))
    metric("siege_lander_killed", st.lander and 0 or 1)
    check("siege: the squad was trained", S.trained >= SQUAD, S.trained .. " of " .. SQUAD)
    check("siege: the faction answered", st.responses > S.st0.responses, (st.responses - S.st0.responses) .. " responses")
    info("siege: " .. MIX .. "; " .. serpent.line(lp("army")) .. ", player units lost " .. serpent.line(S.killers or {})
      .. ", faction units lost: " .. serpent.line(S.fallen or {}) .. ", damage dealt " .. serpent.line(S.dealt or {}))
  end)
end

local scenario = scenarios[params.scenario]
if not scenario then error("lp-sim: unknown scenario " .. tostring(params.scenario)) end
-- Scenarios that strike need the run to outlast the strike (occupy at 3 minutes once crashed reading
-- state its strike at 30 never made).
-- Minutes each needs after its strike (occupy holds 10, then needs time to rebuild: a 40-minute run with
-- the strike at 30 failed for lack of time, not of mechanics).
local AFTER = {cut = 6, raid = 6, path = 6, defend = 7, occupy = 18, army = 11, train = 6, siege = 13, fall = 5}
if params.scenario == "uplink" and END < 18 * 3600 then error("lp-sim: uplink needs at least 18 minutes") end
if params.scenario == "convoy" and END < 10 * 3600 then error("lp-sim: convoy needs at least 10 minutes") end
if params.scenario == "caps" and END < 8 * 3600 then error("lp-sim: caps needs at least 8 minutes") end
if AFTER[params.scenario] and not params.save_at and END < STRIKE + AFTER[params.scenario] * 3600 then
  error(string.format("lp-sim: %s strikes at minute %d; run at least %d minutes", params.scenario, STRIKE / 3600,
    STRIKE / 3600 + AFTER[params.scenario]))
end

script.on_init(function()
  helpers.remove_path("landing-party")
  lp("set_trace", true)
  -- Land as the real arrival does, `distance` tiles from spawn (on a site with ore round it).
  storage.id = lp("arrive", 1, {x = 0, y = 0}, params.distance,
    {doctrine = params.doctrine or (params.scenario == "defend" and "bastion")
      or ((params.scenario == "army" or params.scenario == "siege") and "sprawl") or nil,
     uplink = params.scenario == "uplink" or nil})
  if not storage.id then error("lp-sim: landing failed") end
end)

scenario()
-- Forks (scripts/fork.sh): run fast on a headless server up to the strike and save there; scripts/sim.sh
-- with LP_FORK=1 then runs only what follows the strike, from that save.
if params.save_at then
  schedule(30, function() game.speed = 64 end)
  -- A second before the strike: saved one tick before, the loaded game never ran the strike.
  schedule(params.save_at * 3600 - 60, function()
    game.speed = 1
    game.server_save("fork")
    helpers.write_file("landing-party/saved.txt", tostring(game.tick))
  end)
end
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
  local CHECKLESS = {grow = true, probe = true, cost = true, showcase = true}
  if not CHECKLESS[params.scenario] then
    local ran = 0
    for _, l in ipairs(lines) do
      local is_check = l:sub(1, 5) == "PASS " or l:sub(1, 5) == "FAIL "
      if is_check and l:find(params.scenario .. ":", 1, true) then ran = ran + 1 end
    end
    check("the scenario's checks ran", ran > 0, ran .. " checks; is the run long enough?")
  end
  -- A siege may win outright by destroying the lander.
  if params.scenario ~= "siege" and params.scenario ~= "fall" then check("lander alive", s.lander) end
  check("mined", s.mined > 0, s.mined)
  check("made parts", s.made > 0, s.made)
  metric("doctrine", s.doctrine); metric("hubs", s.hubs); metric("archetypes", s.archetypes)
  metric("blocks", s.blocks); metric("walls", s.walls); metric("roads", s.road_tiles)
  -- A fallen settlement has no power left to cover anything.
  if not s.fallen then check("power covers demand", s.demand <= s.supply, string.format("%.1f/%.1f MW", s.demand / 1e6, s.supply / 1e6)) end
  metric("parts", s.parts); metric("drills", s.drills); metric("fabs", s.fabs); metric("pylons", s.pylons)
  metric("lost", s.lost); metric("rebuilt", s.rebuilt)
  metric("units", s.units_built); metric("units_lost", s.units_lost); metric("raids", s.raids_sent)
  metric("razed", s.razed); metric("responses", s.responses)
  table.insert(lines, "INFO " .. helpers.table_to_json(s))
  table.insert(lines, failed == 0 and "DONE ALL PASSED" or ("DONE " .. failed .. " FAILED"))
  helpers.write_file("landing-party/results.txt", table.concat(lines, "\n") .. "\n")
end)

-- What kills the player's troopers, and the lander (army scenario diagnostics).
script.on_event(defines.events.on_entity_died, function(e)
  local by = e.cause and e.cause.valid and e.cause.name or "no cause"
  if e.entity.name == "gun-turret" then
    table.insert(lines, string.format("INFO gun turret at %.0f,%.0f destroyed by %s (%s)", e.entity.position.x,
      e.entity.position.y, by, e.force and e.force.name or "?"))
  elseif e.entity.force.name == "player" then
    S.killers = S.killers or {}
    local k = e.entity.name == "lp-trooper" and by or (e.entity.name .. " by " .. by)
    S.killers[k] = (S.killers[k] or 0) + 1
    if S.go and (S.deaths or 0) < 80 then
      S.deaths = (S.deaths or 0) + 1
      local c = e.cause and e.cause.valid and e.cause.position
      table.insert(lines, string.format("INFO death t+%ds %s at %.0f,%.0f by %s %s", (e.tick - S.go) / 60, e.entity.name,
        e.entity.position.x, e.entity.position.y, by,
        c and string.format("from %.0f tiles", math.sqrt((c.x - e.entity.position.x) ^ 2 + (c.y - e.entity.position.y) ^ 2)) or ""))
    end
  elseif e.entity.name ~= "lp-lander" then
    S.fallen = S.fallen or {}
    local k = e.entity.name .. " by " .. by
    S.fallen[k] = (S.fallen[k] or 0) + 1
  else
    table.insert(lines, string.format("INFO lander killed at tick %d by %s (%s)", e.tick, by,
      e.force and e.force.name or "?"))
  end
end, {{filter = "name", name = "lp-trooper"}, {filter = "name", name = "lp-breacher"},
  {filter = "name", name = "lp-battle-tank"}, {filter = "name", name = "lp-lander"}, {filter = "name", name = "gun-turret"}, {filter = "type", type = "unit"},
  {filter = "type", type = "spider-unit"}})

-- Siege diagnostics: damage the player's units deal, by unit and target.
if params.scenario == "siege" then
  script.on_event(defines.events.on_entity_damaged, function(e)
    local c = e.cause
    if not (c and c.valid and c.force.name == "player") then return end
    S.dealt = S.dealt or {}
    local k = c.name:sub(4) .. ">" .. e.entity.name:sub(4)
    S.dealt[k] = (S.dealt[k] or 0) + math.floor(e.final_damage_amount)
  end, {{filter = "type", type = "electric-turret"}, {filter = "type", type = "wall"}, {filter = "type", type = "unit"},
    {filter = "type", type = "land-mine"}, {filter = "type", type = "container"}})
end

script.on_event(defines.events.on_ai_command_completed, function(e)
  if S.results then S.results[e.unit_number] = e.result end
end)

script.on_event(defines.events.on_tick, function(e)
  local f = at[e.tick]
  if f then f() end
end)
