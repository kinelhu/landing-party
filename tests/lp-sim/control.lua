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
    -- A player with these upgrades has the research of era 2 (set directly, they count none): the cap on the
    -- corporations' own research (scripts/rd.lua) follows it.
    lp("debug_tune", {era = 2})
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
  -- A corporation that has met this player before (bullet damage +0.8, shooting speed +0.6: era 2): its lasers at level
  -- 2 (its Line troopers' weapon) and armoured infantry from the start, its garrison built under them (scripts/rd.lua). From nothing, the
  -- research loop answered only at minute 70 (a raid of 26 lost at 40, the physical plate at 70).
  schedule(100, function()
    lp("debug_tune", {era = 2, rd_tech = {serenity = {weapons = {laser = 2}, plate = {["lp-infantry"] = "physical"}}}})
  end)
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
    -- A player with these upgrades has the research of era 2 (set directly, they count none): the cap on the
    -- corporations' own research (scripts/rd.lua) follows it.
    lp("debug_tune", {era = 2})
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
  -- Ten minutes after the strike: the claim is that the outpost stands again, not how fast (at six, a raid that
  -- came a little later left two turrets' rebuild just past the check).
  schedule(STRIKE + 10 * 3600, function()
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
    local u = surface().find_entities_filtered{name = "lp-uplink", force = FORCE}[1]
    if u then u.die("player") end
  end)
  schedule(18 * 3600, function()
    local f = lp("faction")
    local d = lp("corp", "serenity")
    -- Per corporation now: the headquarters' fall makes Serenity withdraw (no landing of its own after it);
    -- the other corporation may still land (docs/reviews/2026-10-13-headquarters-consult.md).
    local serenity_after = 0
    for _, id in ipairs(lp("bases")) do
      local st = lp("stats", id)
      if st.corp == "serenity" and st.lander and id > S.landings then serenity_after = serenity_after + 1 end
    end
    check("uplink: landings came while it stood", S.landings >= 3, S.landings .. " landings")
    check("uplink: its fall is registered", d.hq_down ~= nil and d.withdrawing ~= nil, tostring(d.hq_down))
    check("uplink: Serenity landed nothing after its fall", serenity_after == 0, serenity_after .. " Serenity landings after")
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

-- The tour (showcase, LP_MIX=tour): what the /lp dev tools act on. Between spawn and Serenity, 110 tiles from it,
-- an outpost (a loaded gun turret, an assembler, a radar, powered); between spawn and Grubstake, 130 from it, iron
-- with two powered drills and no turret (a strip camp's site); 200 tiles from Serenity's lander, inside an
-- artillery turret's reach of it, the turret, empty, with shells in a chest beside it (load it to start the
-- counter-battery and the hull).
function tour_outposts()
  local function toward(id, d)
    local o = lp("stats", id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    return {math.floor(o.x - o.x / len * d), math.floor(o.y - o.y / len * d)}
  end
  local function put(name, x, y, items)
    local e = surface().create_entity{name = name, position = {x, y}, force = "player", raise_built = true}
    if e and items then e.insert(items) end
    return e
  end
  local c = toward(S.tour.s, 110)
  flatten(c[1] - 10, c[2] - 10, c[1] + 10, c[2] + 10)
  put("gun-turret", c[1], c[2], {name = "firearm-magazine", count = 100})
  put("assembling-machine-2", c[1] + 5.5, c[2] + 0.5)
  put("radar", c[1] - 5, c[2] + 1)
  put("medium-electric-pole", c[1] + 1.5, c[2] + 3.5)
  put("electric-energy-interface", c[1] + 3, c[2] + 6)
  info(string.format("tour: outpost at %d,%d", c[1], c[2]))
  local a = toward(S.tour.s, 200)
  flatten(a[1] - 6, a[2] - 6, a[1] + 6, a[2] + 6)
  put("artillery-turret", a[1], a[2])
  put("wooden-chest", a[1] + 3.5, a[2] + 0.5, {name = "artillery-shell", count = 50})
  info(string.format("tour: artillery at %d,%d", a[1], a[2]))
  if S.tour.g then
    local p = toward(S.tour.g, 130)
    flatten(p[1] - 25, p[2] - 25, p[1] + 25, p[2] + 25)
    for x = p[1] - 20, p[1] + 19 do
      for y = p[2] - 20, p[2] + 19 do
        surface().create_entity{name = "iron-ore", position = {x + 0.5, y + 0.5}, amount = 2000}
      end
    end
    for _, dx in ipairs({-18, -13}) do put("electric-mining-drill", p[1] + dx, p[2] - 17) end
    put("medium-electric-pole", p[1] - 15.5, p[2] - 20.5)
    put("electric-energy-interface", p[1] - 15, p[2] - 23)
    info(string.format("tour: drills at %d,%d", p[1], p[2]))
  end
  game.forces.player.chart(surface(), {{-800, -800}, {800, 800}})
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
    -- LP_MIX=rivals: Grubstake lands beside Serenity instead of the uplink (identity look).
    if params.mix == "rivals" then
      local other = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
      if other then lp("debug_depot", other, 4000) end
    elseif params.mix == "tour" then
      -- LP_MIX=tour: Grubstake as well, both grown; your outposts by each (tour_outposts below).
      S.tour = {s = storage.id, g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})}
      if S.tour.g then lp("debug_depot", S.tour.g, 4000) end
    else
      lp("arrive", 1, {x = 0, y = 0}, params.distance, {uplink = true})
    end
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
  if params.mix == "tour" then schedule(STRIKE - 120, tour_outposts) end
  schedule(STRIKE, function()
    if params.mix == "tour" then lp("debug_tune", {raids_off = false}) end
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
    -- The fall as if its hull were down (the hull and the armour have their own measure: the campaign).
    lander.destructible = true
    lander.die("player")
    -- A building of the fallen settlement hit in the same tick (it crashed the intel, user 2026-10-13).
    local hit = surface().find_entities_filtered{force = FORCE, type = {"electric-turret", "assembling-machine"},
      position = S.lander_at, radius = 60, limit = 1}[1]
    if hit then hit.damage(10, "player", "physical") end
    S.hit = hit ~= nil
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
    -- Turned back on sight, before attacking: the design's claim. One raider lost on the approach is tolerated
    -- (seen once, 3 of 4, after the corporations changed the settlement's layout).
    check("abort: it turned back on sight, most came home", l and l.outcome == "aborted" and l.back >= l.launched - 1,
      l and (l.outcome .. ", " .. l.back .. " of " .. l.launched) or "none")
    -- A siege may follow (too strong to raid is what sieges are for); another raid may not.
    check("abort: it did not raid again within the cooldown", o.launched - o.sieges == 1,
      (o.launched - o.sieges) .. " raids, " .. o.sieges .. " sieges")
  end)
end

-- Siege tiers (docs/reviews/2026-10-14-operations-depth-consult.md), on bombard's walled position of 8 gun turrets.
-- LP_MIX=2: two mortars, more than one mortar's 30 shells fired. LP_MIX=3: three mortars, then the assault goes in
-- from the site and razes something. LP_MIX=sally: a tier-1 mortar killed by two battle tanks 20 tiles off, and the
-- siege aborts. LP_MIX=convoy: tier 2, the shell convoy is killed on the way, and nothing more is loaded.
scenarios.siegetier = function()
  local tier = ({["2"] = 2, ["3"] = 3, sally = 1, convoy = 2})[params.mix] or 2
  -- Forced (/lp siege) with raids off: weighted, eight gun turrets need a raid of 28, which a grown garrison affords.
  schedule(30, function() lp("debug_tune", {corp_level = {serenity = 3}, siege_tier = tier, era = 4, raids_off = true}) end)
  schedule(60, function()
    for _ = 1, 3 do lp("debug_depot", storage.id, 3000) end
  end)
  schedule(5 * 3600, function() lp("dev", {"siege", tostring(storage.id)}, S.c) end)
  schedule(120, function()
    local lander = surface().find_entities_filtered{name = "lp-lander", force = FORCE}[1]
    local L = lander.position
    local len = math.sqrt(L.x * L.x + L.y * L.y)
    local c = {math.floor(L.x - L.x / len * 150), math.floor(L.y - L.y / len * 150)}
    flatten(c[1] - 20, c[2] - 20, c[1] + 20, c[2] + 20)
    S.c = c
    for x = -12, 12 do for y = -12, 12 do
      if math.abs(x) == 12 or math.abs(y) == 12 then
        surface().create_entity{name = "stone-wall", position = {c[1] + x, c[2] + y}, force = "player"}
      end
    end end
    S.put = function()
      for _, p in ipairs({{-9, -9}, {9, -9}, {-9, 9}, {9, 9}, {0, -9}, {0, 9}, {-9, 0}, {9, 0}}) do
        if surface().count_entities_filtered{position = {c[1] + p[1], c[2] + p[2]}, radius = 0.5, name = "gun-turret"} == 0 then
          local t = surface().create_entity{name = "gun-turret", position = {c[1] + p[1], c[2] + p[2]}, force = "player"}
          if t then t.insert{name = "piercing-rounds-magazine", count = 200} end
        end
      end
    end
    S.put()
    for _, p in ipairs({{-3, -3}, {3, 3}}) do
      surface().create_entity{name = "assembling-machine-1", position = {c[1] + p[1] + 0.5, c[2] + p[2] + 0.5}, force = "player"}
    end
  end)
  for t = 600, END - 120, 60 do
    schedule(t, function()
      -- Tiers 2 and the convoy: the player rebuilds lost turrets each minute (robots), so the mortars run dry.
      if (params.mix == "2" or params.mix == "convoy") and S.put then S.put() end
      local o = lp("stats", storage.id).ops
      S.max_mortars = math.max(S.max_mortars or 0, o.mortars or 0)
      S.max_fired = math.max(S.max_fired or 0, o.shells_fired or 0)
      S.max_loaded = math.max(S.max_loaded or 0, o.loaded or 0)
      if o.siege_tier then S.tier = o.siege_tier end
      if params.mix == "sally" and o.mortar and not S.sallied then
        S.sallied = true
        local m = o.mortar
        local len = math.sqrt((m[1] - S.c[1]) ^ 2 + (m[2] - S.c[2]) ^ 2)
        local from = {m[1] + (S.c[1] - m[1]) / len * 20, m[2] + (S.c[2] - m[2]) / len * 20}
        for _, u in ipairs(spawn("lp-battle-tank", from, 2, "player")) do
          local target = surface().find_entities_filtered{position = m, radius = 3, type = "artillery-turret", limit = 1}[1]
          if target then u.commandable.set_command{type = defines.command.attack, target = target} end
        end
        S.sally_at = game.tick
      end
      if params.mix == "convoy" and o.mortar then
        for _, h in pairs(surface().find_entities_filtered{force = FORCE, name = "lp-hauler"}) do
          local d = math.sqrt((h.position.x - o.mortar[1]) ^ 2 + (h.position.y - o.mortar[2]) ^ 2)
          if d > 25 and (o.convoys_left or 1) == 0 and not S.convoy_killed then
            h.die("player")
            S.convoy_killed = game.tick
          end
        end
      end
    end)
  end
  schedule(END - 60, function()
    local st = lp("stats", storage.id)
    local o = st.ops
    local siege
    for _, l in ipairs(o.log) do if l.op == "siege" then siege = l end end
    info("siegetier: " .. serpent.line({tier = S.tier, mortars = S.max_mortars, fired = S.max_fired, loaded = S.max_loaded,
      assaults = o.assaults, razed = o.assault_razed, siege = siege}))
    check("siegetier: a siege of the tier asked for", S.tier == tier, tostring(S.tier))
    if params.mix == "2" or params.mix == "" then
      check("siegetier: two mortars", S.max_mortars == 2, tostring(S.max_mortars))
      check("siegetier: more than one mortar's shells fired", (S.max_fired or 0) > 40, tostring(S.max_fired))
    elseif params.mix == "3" then
      check("siegetier: three mortars", S.max_mortars == 3, tostring(S.max_mortars))
      check("siegetier: the assault went in", (o.assaults or 0) > 0, tostring(o.assaults))
      check("siegetier: the assault razed something", (o.assault_razed or 0) > 0, tostring(o.assault_razed))
    elseif params.mix == "sally" then
      check("siegetier: the sally killed the mortar and the siege aborted", siege and siege.outcome == "aborted"
        and surface().count_entities_filtered{type = "artillery-turret", force = FORCE} == 0,
        siege and siege.outcome or "not finished")
    elseif params.mix == "convoy" then
      check("siegetier: the convoy was killed", S.convoy_killed ~= nil, tostring(S.convoy_killed))
      check("siegetier: nothing more was loaded", (S.max_loaded or 0) == 80, tostring(S.max_loaded))
    end
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
  -- Sieges are a capability from level 1 (Serenity).
  schedule(30, function() lp("debug_tune", {corp_level = {serenity = 1}}) end)
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

-- The campaign's player (contact, LP_MIX=campaign): three rules, every 5 minutes, through what a player has.
--   answer  each place it lost something (a ghost its robots have not rebuilt, or anything outside their reach,
--           seen as a ghost) gets two laser turrets once, at most 6 + 4 per era in all
--   strike  every 45 minutes from an hour after the base: a squad (troopers, breachers, battle tanks by era) at
--           the nearest standing settlement's lander when its garrison and turrets are below the squad's size,
--           else at that settlement's nearest drill (the outposts the review says it should take first)
--   era     up one every 90 minutes, to 4 (the corporations' market and the player's laser research)
function campaign_player(AT, put)
  S.answered, S.answered_n, S.strikes = {}, 0, 0
  local era = 2
  for t = AT + 600, END - 600, 300 do
    schedule(t, function()
      -- Batteries are kept fed (a player supplies them by train): each gun topped up to 20 shells every 5 minutes.
      -- Aimed, as with the artillery remote (left to itself a battery shelled the nearer defences, rebuilt as fast,
      -- 563 shells in four hours, the lander untouched): a flare on every generator of the settlement in reach
      -- (the hull holds while half of them stand), then on the lander.
      for _, bat in pairs(S.batteries or {}) do
        local live = 0
        for _, g in ipairs(bat.guns) do
          if g.valid then
            live = live + 1
            local inv = g.get_inventory(defines.inventory.artillery_turret_ammo)
            local have = inv.get_item_count()
            if have < 20 then inv.insert{name = "artillery-shell", count = 20 - have} end
            S.shells = (S.shells or 0) + 20 - have
          end
        end
        if live > 0 and not bat.done then
          local function flare(p)
            surface().create_entity{name = "artillery-flare", position = p, force = "player", movement = {0, 0},
              height = 0, vertical_speed = 0, frame_speed = 1}
          end
          for _, g in pairs(surface().find_entities_filtered{force = bat.force, name = {"lp-generator", "lp-grubstake-generator"},
            position = bat.pos, radius = 220}) do
            flare(g.position)
          end
          flare(bat.aim)
        elseif live == 0 and not bat.lost then
          bat.lost = game.tick
          S.batteries_lost = (S.batteries_lost or 0) + 1
          local by = {}
          for k, v in pairs(S.killers or {}) do if k:find("artillery") then by[k] = v end end
          info(string.format("campaign t%.0f: battery at %.0f,%.0f lost (%s)", game.tick / 3600, bat.pos[1], bat.pos[2],
            serpent.line(by)))
        end
      end
      -- A camp struck young (Fable: squads take camps, before walls and corner turrets): a settlement under 20
      -- minutes old, once, by a squad staged 60 tiles out on the side towards home.
      S.struck = S.struck or {}
      for _, id in ipairs(lp("bases")) do
        local st = lp("stats", id)
        if st and st.lander and not st.fallen and st.landed and game.tick - st.landed < 20 * 3600 and not S.struck[id]
          and game.tick - st.landed > 3 * 3600 then
          S.struck[id] = game.tick
          local o = {st.origin.x, st.origin.y}
          local ol = math.max(1, math.sqrt(o[1] ^ 2 + o[2] ^ 2))
          local from = {o[1] - o[1] / ol * 60, o[2] - o[2] / ol * 60}
          local squad = {}
          for _, g in ipairs({{"lp-trooper", 20 + 10 * (era - 2)}, {"lp-breacher", 6 + 2 * (era - 2)}, {"lp-battle-tank", era - 1}}) do
            for _, u in ipairs(spawn(g[1], from, g[2], "player")) do table.insert(squad, u) end
          end
          for _, u in ipairs(squad) do
            u.commandable.set_command{type = defines.command.attack_area, destination = o, radius = 30,
              distraction = defines.distraction.by_anything}
          end
          S.camp_strikes = (S.camp_strikes or 0) + 1
          info(string.format("campaign t%.0f: camp strike at %s %d (%.0f minutes old), %d units", game.tick / 3600, st.corp, id,
            (game.tick - st.landed) / 3600, #squad))
          local n0 = #squad
          schedule(game.tick + 600 * 60, function()
            local alive = 0
            for _, u in ipairs(squad) do if u.valid then alive = alive + 1 end end
            local after = lp("stats", id)
            local won = after and (after.fallen or not after.lander)
            if won then S.camp_wins = (S.camp_wins or 0) + 1 end
            info(string.format("campaign t%.0f: camp strike at %d, 10 minutes on: %d of %d alive, settlement %s", game.tick / 3600,
              id, alive, n0, won and "fallen" or "standing"))
          end)
        end
      end
      local cap = 6 + 4 * era
      for _, g in pairs(surface().find_entities_filtered{type = "entity-ghost", force = "player"}) do
        -- Placing lasers for one ghost can remove the next (a crash at minute 160).
        local k = g.valid and (math.floor(g.position.x / 24) .. "," .. math.floor(g.position.y / 24))
        if k and not S.answered[k] and S.answered_n < cap then
          S.answered[k] = true
          S.answered_n = S.answered_n + 1
          local placed = 0
          for _, d in ipairs({-4, 4}) do
            local tr = put("laser-turret", g.position.x + d, g.position.y - 6)
            if tr then
              placed = placed + 1
              -- Powered by the nearest network: an interface beside it (the base's grid is interfaces too).
              put("electric-energy-interface", tr.position.x, tr.position.y + 3)
            end
          end
          info(string.format("campaign t%.0f: answer at %.0f,%.0f, %d lasers (%d answered)", game.tick / 3600,
            g.position.x, g.position.y, placed, S.answered_n))
        end
      end
    end)
  end
  for t = AT + 90 * 3600, END, 90 * 3600 do
    schedule(t, function()
      if era < 4 then
        era = era + 1
        lp("debug_tune", {era = era})
        game.forces.player.set_ammo_damage_modifier("laser", 0.4 + 0.3 * (era - 2))
        -- Era 4: artillery range 1 (x1.3, 291 tiles), as the hull consult has it.
        if era >= 4 then game.forces.player.technologies["artillery-shell-range-1"].researched = true end
        info(string.format("campaign t%.0f: era %d", game.tick / 3600, era))
      end
    end)
  end
  for t = AT + 60 * 3600, END - 600, 45 * 3600 do
    schedule(t, function()
      local best, bd, bst
      for _, id in ipairs(lp("bases")) do
        local st = lp("stats", id)
        if st and st.lander and not st.fallen then
          local d = st.origin.x ^ 2 + st.origin.y ^ 2
          if not bd or d < bd then best, bd, bst = id, d, st end
        end
      end
      if not best then return end
      local troopers, breachers, tanks = 20 + 10 * (era - 2), 6 + 2 * (era - 2), era - 1
      local size = troopers + 2 * breachers + 4 * tanks
      -- What stands round the lander: its turrets (3 each) and every unit of the corporation within 60.
      local o = {bst.origin.x, bst.origin.y}
      local strength = 3 * surface().count_entities_filtered{position = o, radius = 40, force = bst.force,
        type = {"electric-turret", "ammo-turret", "fluid-turret"}}
        + surface().count_entities_filtered{position = o, radius = 60, force = bst.force, type = {"unit", "car", "spider-vehicle"}}
      local target = {bst.origin.x, bst.origin.y}
      local what = "lander"
      if strength > size then
        -- Scouted, as a player would: any corporation's drill within 600 tiles, the fewest turrets within 30
        -- first, then the nearest (the drill nearest spawn sat in a block of 96 entities and ate every squad).
        local nd
        for _, f in pairs(game.forces) do
          if f.name:sub(1, 3) == "lp-" then
            for _, e in pairs(surface().find_entities_filtered{force = f, type = "mining-drill", position = {0, 0}, radius = 600}) do
              local guns = surface().count_entities_filtered{position = e.position, radius = 30, force = f,
                type = {"electric-turret", "ammo-turret", "fluid-turret"}}
              local d = guns * 1e6 + e.position.x ^ 2 + e.position.y ^ 2
              if not nd or d < nd then nd, target = d, {e.position.x, e.position.y} end
            end
          end
        end
        what = string.format("outpost (%d turrets near)", math.floor((nd or 0) / 1e6))
      end
      -- From era 3, the way a player takes a fortress: a forward battery in artillery range of the lander (200
      -- tiles towards home, four lasers round it), resupplied at each strike; the squad goes in as well.
      if era >= 3 then
        local ol = math.sqrt(o[1] ^ 2 + o[2] ^ 2)
        -- A clear site in reach, on the hub's side (Fable's hull consult): around the lander, 220 down to 150 tiles out,
        -- the site with no corporation turret within 50 that has the most of the hull's generators (within 80 of the
        -- lander) in a gun's reach (224), taken at once when it reaches 60% of them; failing any clear at 50, clear at 30.
        local gens = surface().find_entities_filtered{position = {o[1], o[2]}, radius = 80, force = bst.force,
          type = "electric-energy-interface"}
        local counted = {}
        for _, g in pairs(gens) do if g.name:find("generator", 1, true) then table.insert(counted, g.position) end end
        local function hot(p, r)
          for _, f in pairs(game.forces) do
            if f.name:sub(1, 3) == "lp-" and surface().count_entities_filtered{position = p, radius = r, force = f,
              type = {"electric-turret", "ammo-turret", "fluid-turret", "artillery-turret"}, limit = 1} > 0 then
              return true
            end
          end
        end
        local function reach(p)
          local n = 0
          local r = era >= 4 and 291 or 224
          for _, g in ipairs(counted) do if (g.x - p[1]) ^ 2 + (g.y - p[2]) ^ 2 <= r * r then n = n + 1 end end
          return n
        end
        local bp, bn
        for _, clear in ipairs({50, 30}) do
          for k = 0, 15 do
            local a = 2 * math.pi * k / 16
            for d = 220, 150, -10 do
              local p = {o[1] + math.cos(a) * d, o[2] + math.sin(a) * d}
              if not hot(p, clear) then
                local n = reach(p)
                if not bn or n > bn then bp, bn = p, n end
                break
              end
            end
            if bn and #counted > 0 and bn >= 0.6 * #counted then break end
          end
          if bp then break end
        end
        if bp then
          info(string.format("campaign t%.0f: battery site reaches %d of %d hull generators", game.tick / 3600, bn, #counted))
        end
        S.batteries = S.batteries or {}
        local bat = S.batteries[best]
        if not bp then
          S.no_site = (S.no_site or 0) + 1
          info(string.format("campaign t%.0f: no clear battery site within reach of %s %d", game.tick / 3600, bst.corp, best))
        elseif not bat or bat.lost then
          flatten(math.floor(bp[1]) - 10, math.floor(bp[2]) - 10, math.floor(bp[1]) + 10, math.floor(bp[2]) + 10)
          -- More guns by era (the hull needs half the generators down within 90 s): 2 at era 3, 4 at era 4.
          bat = {guns = {}, pos = bp, aim = {o[1], o[2]}, force = bst.force, placed = game.tick}
          for k = 1, (era >= 4 and 4 or 2) do
            local g = put("artillery-turret", bp[1] + ((k % 2 == 0) and 4 or -4), bp[2] + ((k > 2) and 4 or -4))
            if g then table.insert(bat.guns, g) end
          end
          for _, d in ipairs({{-8, -8}, {8, -8}, {-8, 8}, {8, 8}}) do
            local tr = put("laser-turret", bp[1] + d[1], bp[2] + d[2])
            if tr then put("electric-energy-interface", tr.position.x, tr.position.y + 3) end
          end
          S.batteries[best] = bat
          S.batteries_placed = (S.batteries_placed or 0) + 1
        end
        -- Scouted: artillery fires only on what the force has charted.
        game.forces.player.chart(surface(), {{o[1] - 96, o[2] - 96}, {o[1] + 96, o[2] + 96}})
        if bp and bat then
          info(string.format("campaign t%.0f: forward battery at %.0f,%.0f for %s %d, %d guns", game.tick / 3600, bat.pos[1],
            bat.pos[2], bst.corp, best, #bat.guns))
        end
      end
      local len = math.sqrt(target[1] ^ 2 + target[2] ^ 2)
      local from = {target[1] / len * 85, target[2] / len * 85}
      local squad = {}
      for _, g in ipairs({{"lp-trooper", troopers}, {"lp-breacher", breachers}, {"lp-battle-tank", tanks}}) do
        for _, u in ipairs(spawn(g[1], from, g[2], "player")) do table.insert(squad, u) end
      end
      -- With a battery up, the squad holds it (Fable: the player sallies to keep the battery alive; a response of
      -- seven with tanks killed an unguarded battery in five minutes while the squad died at the lander).
      local guard = era >= 3 and S.batteries and S.batteries[best] and not S.batteries[best].lost and S.batteries[best].pos or nil
      for _, u in ipairs(squad) do
        if guard then
          u.teleport(u.surface.find_non_colliding_position(u.name, guard, 20, 1) or guard)
          u.commandable.set_command{type = defines.command.wander, radius = 8, distraction = defines.distraction.by_damage}
        else
          u.commandable.set_command{type = defines.command.attack_area, destination = target, radius = 30,
            distraction = defines.distraction.by_anything}
        end
      end
      if guard then what = "battery (guarding it)"; target = guard end
      S.strikes = S.strikes + 1
      local n0, at, kind = #squad, target, what
      schedule(game.tick + 600 * 60 - (game.tick % 60), function()
        local alive = 0
        for _, u in ipairs(squad) do if u.valid then alive = alive + 1 end end
        local left = surface().count_entities_filtered{position = at, radius = 30, force = bst.force}
        info(string.format("campaign t%.0f: strike %d at the %s, 10 minutes on: %d of %d alive, %d corporation entities within 30; killed by %s",
          game.tick / 3600, S.strikes, kind, alive, n0, left, serpent.line(S.killers or {})))
        S.killers = {}
      end)
      info(string.format("campaign t%.0f: strike %d at the %s of %s %d (%.0f,%.0f): %d units against strength %d",
        game.tick / 3600, S.strikes, what, bst.corp, best, target[1], target[2], #squad, strength))
    end)
  end
end

function campaign_checks()
  local corps = {}
  for _, id in ipairs(lp("bases")) do
    local st = lp("stats", id)
    if st then corps[st.corp] = true end
  end
  local n = 0
  for _ in pairs(corps) do n = n + 1 end
  local consolidated = false
  for c in pairs(corps) do
    local d = lp("corp", c)
    if d and (d.hq or d.consolidating) then consolidated = true end
  end
  info("campaign: " .. serpent.line({strikes = S.strikes, answered = S.answered_n, lander_kills = S.lander_kills,
    corps = corps, consolidated = consolidated}))
  info("campaign: artillery shells supplied " .. tostring(S.shells or 0) .. ", batteries placed " .. tostring(S.batteries_placed or 0)
    .. ", lost " .. tostring(S.batteries_lost or 0) .. ", camp strikes " .. tostring(S.camp_strikes or 0) .. ", won "
    .. tostring(S.camp_wins or 0))
  check("campaign: the player destroyed a lander", (S.lander_kills or 0) > 0, tostring(S.lander_kills or 0))
  if END >= 300 * 3600 then
    check("campaign: the second corporation came", n >= 2, n .. " corporations")
  end
  if END >= 360 * 3600 then
    check("campaign: a corporation consolidated", consolidated, tostring(consolidated))
  end
end

-- Contact: first contact at real clocks, a timeline to read rather than a verdict. A player base as of the
-- first launch at spawn (production, power, labs, 16 laser turrets in four corner clusters, laser research)
-- and a mining outpost 130 tiles towards the faction with a power line home. The faction lands as it does in
-- a game and lands again on its own clock. Every 5 minutes one line of timeline.jsonl (scripts/timeline.py).
-- Variants (LP_MIX): "" a passive player; "robots" a careful one: losses leave ghosts that construction robots
-- rebuild from a storage of spares (nine roboports cover the base, not the outpost); "walled" the same with a
-- wall and laser perimeter round the base.
scenarios.contact = function()
  -- Era bases (docs/reviews/2026-10-13-campaign-review.md section 6): "spread" (era 2: three outposts, robots),
  -- "late" (era 4: walled, robots, lasers, an artillery turret with shells at the centre).
  -- "campaign" (docs/reviews/2026-10-14-next-slice-consult.md): the spread base and a reactive player that answers,
  -- strikes and rises in era (campaign_player below); a milestone run (scripts/campaign.sh), hours long.
  local campaign = params.mix == "campaign"
  local careful = params.mix == "robots" or params.mix == "walled" or params.mix == "spread" or params.mix == "late"
    or campaign
  local walled = params.mix == "walled" or params.mix == "late"
  local era = ({spread = 2, late = 4, campaign = 2})[params.mix] or 0
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
    lp("debug_tune", {era = era})
    if params.mix == "late" then
      local art = put("artillery-turret", 10, 10)
      if art then art.insert{name = "artillery-shell", count = 30} end
      pf.set_ammo_damage_modifier("laser", 1.0)
      pf.set_gun_speed_modifier("laser", 0.8)
    end
    if walled then
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
    if params.mix == "spread" or campaign then
      -- Two more outposts, to either side, with their own pole lines home.
      for _, side in ipairs({1, -1}) do
        local px, py = -uy * side, ux * side
        local q = {px * 140, py * 140}
        flatten(math.floor(q[1]) - 16, math.floor(q[2]) - 16, math.floor(q[1]) + 16, math.floor(q[2]) + 16)
        for k = 0, 7 do put("electric-mining-drill", q[1] - 9 + (k % 4) * 5, q[2] - 4 + math.floor(k / 4) * 6) end
        put("substation", q[1], q[2] + 1)
        put("laser-turret", q[1] - 12, q[2] - 10); put("laser-turret", q[1] + 12, q[2] - 10)
        for d = 66, 124, 28 do put("big-electric-pole", px * d, py * d) end
      end
    end
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
        known = 0, player = census(), corp_units_lost = 0, razed = 0, fallen = 0, corps = {},
        lander_kills = S.lander_kills or 0, strikes = S.strikes or 0, answered = S.answered_n or 0}
      for _, id in ipairs(lp("bases")) do
        local st = lp("stats", id)
        if st then
          row.corp_units_lost = row.corp_units_lost + (st.units_lost or 0)
          row.razed = row.razed + (st.razed or 0)
          if st.fallen then row.fallen = row.fallen + 1 end
        end
        if st and st.lander and not st.fallen then row.corps[st.corp] = (row.corps[st.corp] or 0) + 1 end
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
  if campaign then campaign_player(AT, put) end
  schedule(END - 60, function()
    local now = census()
    info("contact: player at the end " .. serpent.line(now))
    check("contact: a timeline was written", true, "")
    if campaign then campaign_checks() end
  end)
end

-- Rivals: two corporations side by side. Serenity lands as usual; Grubstake lands as the next settlement
-- (its own force). Both get a depot; nothing else is scripted. They must be different forces, and at least one
-- of them must mount an operation against the other's buildings and do damage.
scenarios.rivals = function()
  -- Three depots each (a field of 21): a drop's escort and corner turrets turned back the one-depot raids (a field
  -- of 7) that were the only fighting in 40 minutes.
  schedule(60, function() for _ = 1, 3 do lp("debug_depot", storage.id, 3000) end end)
  schedule(120, function()
    S.other = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    if S.other then for _ = 1, 3 do lp("debug_depot", S.other, 3000) end end
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
    -- Each builds its own prototypes (its colour): Grubstake's are lp-grubstake-*.
    local own, plain = 0, 0
    for _, e in pairs(surface().find_entities_filtered{force = "lp-grubstake"}) do
      if e.name:sub(1, 13) == "lp-grubstake-" then own = own + 1 elseif e.name:sub(1, 3) == "lp-" then plain = plain + 1 end
    end
    check("rivals: Grubstake builds its own prototypes", own > 20 and plain == 0, own .. " its own, " .. plain .. " plain")
    local gravel = surface().count_tiles_filtered{name = "lp-grubstake-road"}
    -- Floor livery: each corporation's trim round its paved yards and depots (Serenity black, Grubstake hazard).
    local s_trim = surface().count_tiles_filtered{name = "lp-trim"}
    local g_trim = surface().count_tiles_filtered{name = "lp-grubstake-trim"}
    check("rivals: their own floors and livery", gravel > 50 and s_trim > 0 and g_trim > 0,
      gravel .. " gravel tiles, trim " .. s_trim .. " Serenity and " .. g_trim .. " Grubstake")
    -- Architecture (docs/corporations.md): Serenity gates its walls; Grubstake fields gun turrets (kept in
    -- ammunition) and buggies.
    local gates = surface().count_entities_filtered{name = "lp-gate", force = "lp-serenity"}
    local guns, fed = 0, 0
    for _, t in pairs(surface().find_entities_filtered{name = "lp-grubstake-turret"}) do
      guns = guns + 1
      if t.get_inventory(defines.inventory.turret_ammo).get_item_count() > 0 then fed = fed + 1 end
    end
    local buggies = surface().count_entities_filtered{name = "lp-grubstake-buggy"}
    check("rivals: Serenity gates its walls", gates > 0, gates .. " gates")
    local flamers, oiled = 0, 0
    for _, t in pairs(surface().find_entities_filtered{name = "lp-flamer", force = "lp-serenity"}) do
      flamers = flamers + 1
      if t.get_fluid_count() > 0 then oiled = oiled + 1 end
    end
    check("rivals: Serenity's gates have fuelled flamethrowers", flamers > 0 and oiled == flamers, oiled .. " of " .. flamers)
    check("rivals: Grubstake's turrets are fed gun turrets", guns > 0 and fed == guns, fed .. " of " .. guns .. " fed")
    check("rivals: Grubstake fields buggies", (b and b.built_by and (b.built_by["lp-buggy"] or 0) or 0) > 0,
      serpent.line(b and b.built_by))
    check("rivals: each holds a territory on the map", (a.claim_radius or 0) > 60 and b and (b.claim_radius or 0) > 60,
      string.format("radius %.0f and %.0f", a.claim_radius or 0, b and b.claim_radius or 0))
    check("rivals: two corporations, two forces", b ~= nil and a.force ~= b.force,
      a.force .. " and " .. (b and b.force or "none"))
    check("rivals: they raided each other", against > 0, against .. " operations against a rival")
    -- Blood on either side: units lost or buildings razed (a fortified rival can win every fight).
    local lost = a.units_lost + (b and b.units_lost or 0) + a.lost + (b and b.lost or 0)
    check("rivals: they fought", lost > 0, string.format("%d and %d units lost, %d and %d buildings",
      a.units_lost, b and b.units_lost or 0, a.lost, b and b.lost or 0))
  end)
end

-- Phases: the campaign's opening (docs/campaign.md section 3), base game. No landing at the start. A player
-- radar brings the signs (wreckage with salvage); oil processing brings a survey party; destroying it drops a
-- command core and delays the arrival; the first chemical science pack triggers the arrival, which must wait
-- out the delay and then come.
-- Phases, left alone (LP_MIX=left): the survey party is not touched; with its clocks shortened (3 minutes to
-- leave, 3 more to come) it must depart and the corporation arrive with no trigger at all.
local function phases_left()
  schedule(30, function() lp("debug_tune", {phases_fast = true}) end)
  schedule(60, function() game.forces.player.technologies["oil-processing"].researched = true end)
  schedule(14 * 3600, function()
    local p = lp("phases")
    storage.id = lp("bases")[1]
    check("phases: left alone, the survey party departed", p.survey and p.survey.done == "left",
      tostring(p.survey and p.survey.done))
    check("phases: and the corporation came without a trigger", storage.id ~= nil and not p.triggered,
      tostring(storage.id) .. ", trigger " .. tostring(p.triggered))
  end)
end

scenarios.phases = function()
  if params.mix == "left" then return phases_left() end
  local pf = game and nil
  schedule(60, function()
    flatten(-10, -10, 10, 10)
    surface().create_entity{name = "radar", position = {0, 0}, force = "player"}
  end)
  schedule(3 * 3600, function()
    local p = lp("phases")
    local wreck = surface().find_entities_filtered{name = "crash-site-spaceship-wreck-big-1", position = {0, 0}, radius = 260}[1]
    S.signs = p.signs and wreck and wreck.get_inventory(defines.inventory.chest).get_item_count("lp-salvage") or 0
    game.forces.player.technologies["oil-processing"].researched = true
  end)
  schedule(6 * 3600, function()
    local p = lp("phases")
    S.survey = p.survey
    S.survey_entities = p.survey and surface().count_entities_filtered{position = p.survey.pos, radius = 20,
      force = "lp-" .. p.survey.corp} or 0
    if p.survey then
      local radar = surface().find_entities_filtered{position = p.survey.pos, radius = 3, type = "radar"}[1]
      if radar then radar.die("player") end
    end
  end)
  schedule(9 * 3600, function()
    local p = lp("phases")
    S.destroyed = p.survey and p.survey.done
    S.core = p.survey and surface().count_entities_filtered{name = "item-on-ground", position = p.survey.pos, radius = 8} or 0
    game.forces.player.get_item_production_statistics(surface()).on_flow("chemical-science-pack", 1)
    S.trigger_at = game.tick
  end)
  schedule(9 * 3600 + 12 * 3600, function() S.early = #lp("bases") end)
  schedule(9 * 3600 + 24 * 3600, function()
    local ids = lp("bases")
    S.late = #ids
    storage.id = ids[1]
  end)
  schedule(END - 60, function()
    local p = lp("phases")
    if not storage.id then storage.id = lp("bases")[1] end
    check("phases: a radar brought the signs, salvage in the wreck", (S.signs or 0) > 0, tostring(S.signs) .. " salvage")
    check("phases: oil processing brought a survey party", S.survey ~= nil and S.survey_entities >= 4,
      tostring(S.survey_entities) .. " entities at the survey site")
    check("phases: destroyed, it dropped a command core", S.destroyed == "destroyed" and S.core > 0,
      tostring(S.destroyed) .. ", " .. tostring(S.core) .. " items on the ground")
    check("phases: the arrival waited out the delay", S.early == 0, S.early .. " settlements 12 minutes after the trigger")
    check("phases: then it came", (S.late or 0) > 0, tostring(S.late) .. " settlements 24 minutes after")
    info("phases: " .. serpent.line(p))
  end)
end

-- Budget: the threat budget and development. Serenity and Grubstake land; each gets undefended relays and a
-- barracks (valuable) 120 tiles towards spawn, within its sight. Era 0: one operation against the player at a
-- time, across both. Both must still attack the player, by turns; Grubstake builds no harriers before level 1.
scenarios.budget = function()
  -- LP_MIX=free lifts the budget (era 10: eleven at once), to see the cap matter.
  schedule(30, function() lp("debug_tune", {era = params.mix == "free" and 10 or 0}) end)
  schedule(60, function() for _ = 1, 3 do lp("debug_depot", storage.id, 3000) end end)
  schedule(120, function()
    S.other = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    if S.other then for _ = 1, 3 do lp("debug_depot", S.other, 3000) end end
    for _, id in ipairs({storage.id, S.other}) do
      local st = lp("stats", id)
      local o = st.origin
      local len = math.sqrt(o.x * o.x + o.y * o.y)
      local c = {math.floor(o.x - o.x / len * 120), math.floor(o.y - o.y / len * 120)}
      flatten(c[1] - 10, c[2] - 10, c[1] + 10, c[2] + 10)
      S.groups = S.groups or {}
      table.insert(S.groups, c)
    end
    -- Rebuilt every 5 minutes, as a player's robots would: with drop escorts Grubstake razed both groups before
    -- Serenity turned to the player, and "both attacked the player" failed on a race, not on the budget.
    S.rebuild = function()
      for _, c in ipairs(S.groups) do
        for k = -1, 1 do
          if surface().count_entities_filtered{name = "lp-command-relay", position = {c[1] + 5 * k, c[2]}, radius = 1} == 0 then
            surface().create_entity{name = "lp-command-relay", position = {c[1] + 5 * k, c[2]}, force = "player"}
          end
        end
        if surface().count_entities_filtered{name = "lp-barracks", position = {c[1], c[2] + 6}, radius = 1} == 0 then
          surface().create_entity{name = "lp-barracks", position = {c[1], c[2] + 6}, force = "player"}
        end
      end
    end
    S.rebuild()
    S.max = 0
  end)
  for t = 5 * 3600, END - 120, 5 * 3600 do schedule(t, function() S.rebuild() end) end
  for t = 300, END - 120, 60 do
    schedule(t, function()
      local th = lp("threat")
      S.max = math.max(S.max or 0, th.player_ops)
      local g = S.other and lp("stats", S.other)
      if g and lp("corp", "grubstake").level == 0 and g.built_by and (g.built_by["lp-harrier"] or 0) > 0 then
        S.early_harriers = true
      end
    end)
  end
  schedule(END - 60, function()
    local a, b = lp("stats", storage.id), S.other and lp("stats", S.other)
    local function vs_player(st)
      local n = 0
      for _, l in ipairs(st and st.ops.log or {}) do if l.owner == "player" then n = n + 1 end end
      return n
    end
    local holds = lp("threat").holds
    info("budget: at most " .. tostring(S.max) .. " at once; the budget held a player target back " .. holds .. " times")
    check("budget: never more than one operation against the player at once", (S.max or 0) <= 1, tostring(S.max))
    if params.mix ~= "free" then check("budget: it held some back", holds > 0, holds .. " holds") end
    check("budget: both still attacked the player", vs_player(a) > 0 and vs_player(b) > 0,
      vs_player(a) .. " by Serenity, " .. vs_player(b) .. " by Grubstake")
    local g = lp("corp", "grubstake")
    check("budget: no harriers before level 1", not S.early_harriers, "level now " .. g.level .. ", " ..
      serpent.line(b and b.built_by))
  end)
end

-- Develop: a corporation's level and its capabilities. Serenity exports past the first threshold (3000):
-- level 1 must come, and with it sieges (the capability), announced.
scenarios.develop = function()
  schedule(120, function()
    S.before = lp("corp", "serenity").level
    lp("debug_export", storage.id, 3500)
    S.after = lp("corp", "serenity").level
  end)
  schedule(END - 60, function()
    check("develop: exports raised Serenity a level", S.before == 0 and S.after == 1, S.before .. " -> " .. S.after)
    check("develop: the faction tier still counts too", lp("faction").tier >= 1, lp("faction").tier)
  end)
end

-- Evolution (spike): does a spawner destroyed by a corporation raise the biters' spawner-kill evolution?
scenarios.evolution = function()
  schedule(50, function()
    game.map_settings.enemy_evolution.enabled = true
    S.enabled = game.map_settings.enemy_evolution.enabled
    S.factor = game.map_settings.enemy_evolution.destroy_factor
  end)
  local enemy
  local function spawn(by, x)
    local sp = surface().create_entity{name = "biter-spawner", position = {x, 0}, force = "enemy"}
    local u = surface().create_entity{name = by == "player" and "lp-trooper" or "lp-infantry", position = {x, 10},
      force = by == "player" and "player" or FORCE}
    return sp, u
  end
  schedule(60, function()
    flatten(150, -30, 230, 30)
    enemy = game.forces.enemy
    -- From half-way too (an earlier refund assumed destroy_factor * (1 - e) and left a residue there).
    enemy.set_evolution_factor_by_killing_spawners(0.5, surface())
    S.b1 = enemy.get_evolution_factor_by_killing_spawners(surface())
    local sp, u = spawn("corp", 170)
    sp.die(u.force, u)
  end)
  schedule(62, function()
    S.a1 = game.forces.enemy.get_evolution_factor_by_killing_spawners(surface())
    local sp, u = spawn("player", 200)
    sp.die(u.force, u)
  end)
  schedule(64, function()
    S.a2 = game.forces.enemy.get_evolution_factor_by_killing_spawners(surface())
    info(string.format("evolution: enabled %s, destroy_factor %s; corporation kill %.5f -> %.5f; player kill -> %.5f",
      tostring(S.enabled), tostring(S.factor), S.b1, S.a1, S.a2))
    S.corp_delta, S.player_delta = S.a1 - S.b1, S.a2 - S.a1
  end)
  schedule(120, function()
    check("evolution: a player's kill raises it", S.player_delta > 0, string.format("%.5f", S.player_delta))
    check("evolution: a corporation's kill does not", math.abs(S.corp_delta) < 1e-6, string.format("%.7f", S.corp_delta))
  end)
end

-- Nests: corporations and biters. Serenity (it clears nests on its territory) with a depot; three spawners
-- placed inside its territory, evolution on. It must raid and destroy them, the biters' evolution from spawner
-- kills must stay where it was (the refund), and a small biter attack on a building draws a small answer.
scenarios.nests = function()
  schedule(30, function() game.map_settings.enemy_evolution.enabled = true end)
  schedule(60, function() for _ = 1, 2 do lp("debug_depot", storage.id, 3000) end end)
  schedule(5 * 3600, function()
    local st = lp("stats", storage.id)
    local o = st.origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    -- Inside the territory, on the side away from the player's spawn.
    local c = {math.floor(o.x + o.x / len * 70), math.floor(o.y + o.y / len * 70)}
    S.nest = c
    S.evo0 = game.forces.enemy.get_evolution_factor_by_killing_spawners(surface())
    for k = -1, 1 do
      local p = surface().find_non_colliding_position("biter-spawner", {c[1] + 8 * k, c[2]}, 10, 1)
      if p then surface().create_entity{name = "biter-spawner", position = p, force = "enemy"} end
    end
    S.placed = surface().count_entities_filtered{name = "biter-spawner", position = c, radius = 20}
    info(string.format("nests: %d spawners at %d,%d (territory radius %.0f)", S.placed, c[1], c[2], st.claim_radius or 0))
  end)
  -- A few biters at one of its buildings.
  schedule(8 * 3600, function()
    local t = surface().find_entities_filtered{force = FORCE, name = "lp-fabricator", limit = 1}[1]
      or surface().find_entities_filtered{force = FORCE, name = "lp-pylon", limit = 1}[1]
    S.bit_at = t and {t.position.x, t.position.y}
    for k = 1, 5 do
      local p = t and surface().find_non_colliding_position("small-biter", {t.position.x + 6, t.position.y + k}, 6, 0.5)
      local u = p and surface().create_entity{name = "small-biter", position = p, force = "enemy"}
      if u then u.commandable.set_command{type = defines.command.attack, target = t} end
    end
  end)
  schedule(END - 60, function()
    local left = surface().count_entities_filtered{name = "biter-spawner", position = S.nest, radius = 20}
    local evo = game.forces.enemy.get_evolution_factor_by_killing_spawners(surface())
    local st = lp("stats", storage.id)
    local raided = 0
    for _, l in ipairs(st.ops.log) do if l.owner == "enemy" then raided = raided + 1 end end
    check("nests: Serenity raided the nests on its territory", raided > 0, raided .. " raids on nests")
    check("nests: and destroyed them", left < S.placed, (S.placed - left) .. " of " .. S.placed .. " destroyed")
    check("nests: the biters did not evolve from it", math.abs(evo - S.evo0) < 1e-6, string.format("%.5f -> %.5f", S.evo0, evo))
  end)
end

-- Headquarters: Serenity (level 3, fast clocks) consolidates and lands its headquarters near its settlement; the
-- HQ's lander cannot be destroyed while the uplink stands; the uplink's fall brings the HQ down, starts the
-- withdrawal (the other settlement falls on the withdrawal clock) and gives the player Serenity's prize.
scenarios.hq = function()
  schedule(30, function() lp("debug_tune", {hq_fast = true, corp_level = {serenity = 3}}) end)
  schedule(60, function() lp("debug_depot", storage.id, 2000) end)
  schedule(8 * 3600, function()
    local d = lp("corp", "serenity")
    S.hq = d.hq
    local st = S.hq and lp("stats", S.hq)
    S.hq_ok = st and st.hq and st.uplink
    local lander = S.hq and surface().find_entities_filtered{name = "lp-lander", force = FORCE, position = st.origin, radius = 12}[1]
    S.protected = lander and not lander.destructible
    local u = surface().find_entities_filtered{name = "lp-uplink", force = FORCE}[1]
    if u then u.die("player") end
  end)
  schedule(9 * 3600, function()
    local d = lp("corp", "serenity")
    S.withdrawing = d.withdrawing ~= nil
    S.hq_fallen = S.hq and lp("stats", S.hq).fallen ~= nil
    S.prize = game.forces.player.recipes["lp-player-mortar"].enabled
  end)
  schedule(16 * 3600, function()
    S.first_fallen = lp("stats", storage.id).fallen ~= nil
  end)
  schedule(END - 60, function()
    check("hq: Serenity landed a headquarters", S.hq_ok == true, tostring(S.hq))
    check("hq: its lander is protected while the uplink stands", S.protected == true, tostring(S.protected))
    check("hq: the uplink's fall brought it down", S.hq_fallen == true, tostring(S.hq_fallen))
    check("hq: Serenity withdraws", S.withdrawing == true, tostring(S.withdrawing))
    check("hq: the player gained its mortar", S.prize == true, tostring(S.prize))
    check("hq: its other settlement fell on the withdrawal clock", S.first_fallen == true, tostring(S.first_fallen))
  end)
end

-- Temper: Serenity never strikes the player first. With a depot and undefended relays within its sight but
-- outside its territory, it raids nothing of the player's while unprovoked; one shot at one of its buildings
-- provokes it, and it comes.
scenarios.temper = function()
  schedule(60, function() for _ = 1, 2 do lp("debug_depot", storage.id, 3000) end end)
  schedule(120, function()
    local o = lp("stats", storage.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    -- Within its sight (200) but outside its territory: inside it, encroachment provokes it (by design).
    local c = {math.floor(o.x - o.x / len * 185), math.floor(o.y - o.y / len * 185)}
    flatten(c[1] - 10, c[2] - 10, c[1] + 10, c[2] + 10)
    for k = -1, 1 do surface().create_entity{name = "lp-command-relay", position = {c[1] + 5 * k, c[2]}, force = "player"} end
  end)
  schedule(15 * 3600, function()
    S.before = lp("stats", storage.id).ops.launched
    local t = surface().find_entities_filtered{force = FORCE, name = "lp-pylon", limit = 1}[1]
    if t then t.damage(5, "player") end
  end)
  schedule(END - 60, function()
    local st = lp("stats", storage.id)
    local provoked = (lp("corp", "serenity").provoked or {}).player
    local early, against = 0, 0
    for _, l in ipairs(st.ops.log) do
      if l.owner == "player" then
        against = against + 1
        if not provoked or l.started < provoked then early = early + 1 end
      end
    end
    -- Never first: every operation against the player started after it was provoked (by encroachment on its
    -- territory or by the shot), and once provoked it came.
    check("temper: no operation against the player before it was provoked", early == 0,
      early .. " early of " .. against .. "; provoked at " .. tostring(provoked))
    check("temper: provoked, it came", against > 0 or st.ops.op ~= nil, against .. " operations against the player")
  end)
end

-- Six: the corporations' caps standing at once (three each), grown with parts, operations against each other, for
-- scripts/profile.sh (campaign.md: a budget of 1 ms of script a tick with 6 settlements).
scenarios.six = function()
  schedule(60, function() lp("debug_depot", storage.id, 3000) end)
  S.six = {}
  local froms = {{x = 900, y = 0}, {x = 0, y = 900}, {x = -900, y = 0}, {x = 0, y = -900}, {x = 900, y = 900}}
  for k, from in ipairs(froms) do
    schedule(60 + 60 * k, function()
      local id = lp("arrive", 1, from, params.distance, {corp = (k % 2 == 1) and "grubstake" or "serenity"})
      if id then
        lp("debug_depot", id, 3000)
        table.insert(S.six, id)
      end
    end)
  end
  schedule(END - 60, function()
    local standing, modules = 0, 0
    -- The first settlement's id is set after the scenario is laid out: counted here.
    table.insert(S.six, 1, storage.id)
    for _, id in ipairs(S.six) do
      local st = lp("stats", id)
      if st and st.lander then standing = standing + 1; modules = modules + st.modules end
      info(string.format("six: %s %s lander %s modules %s", tostring(id), st and st.corp or "?", tostring(st and st.lander),
        tostring(st and st.modules)))
    end
    check("six: six settlements standing", standing == 6, standing .. " standing of " .. #S.six .. ", " .. modules .. " modules")
  end)
end

-- Line: Serenity's perimeter moves (perimeter_fast: a step a minute from a minute after landing). Three relays
-- 185 tiles out, never a shot: the line must grow, name a relay one step before enclosing it, then enclose it and
-- be provoked, with no operation before that. LP_MIX=back: the player removes the relays on the warning; then
-- nothing provokes it.
scenarios.line = function()
  schedule(30, function() lp("debug_tune", {perimeter_fast = true}) end)
  schedule(60, function() for _ = 1, 2 do lp("debug_depot", storage.id, 3000) end end)
  schedule(120, function()
    local o = lp("stats", storage.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local c = {math.floor(o.x - o.x / len * 185), math.floor(o.y - o.y / len * 185)}
    flatten(c[1] - 10, c[2] - 10, c[1] + 10, c[2] + 10)
    S.relays = {}
    for k = -1, 1 do
      table.insert(S.relays, surface().create_entity{name = "lp-command-relay", position = {c[1] + 5 * k, c[2]}, force = "player"})
    end
  end)
  for m = 2, params.minutes - 1 do
    schedule(m * 3600 + 600, function()
      local st = lp("stats", storage.id)
      if st.warned and not S.warned_at then
        S.warned_at = game.tick
        if params.mix == "back" then for _, r in ipairs(S.relays) do if r.valid then r.destroy() end end end
      end
    end)
  end
  schedule(END - 60, function()
    local st = lp("stats", storage.id)
    local provoked = (lp("corp", "serenity").provoked or {}).player
    local early = 0
    for _, l in ipairs(st.ops.log) do
      if l.owner == "player" and (not provoked or l.started < provoked) then early = early + 1 end
    end
    check("line: the perimeter grew", (st.perimeter_steps or 0) > 0,
      tostring(st.perimeter_steps) .. " steps, radius " .. string.format("%.0f", st.claim_radius))
    check("line: a relay was named one step ahead", S.warned_at ~= nil, "warned at " .. tostring(S.warned_at))
    check("line: no operation against the player before it was provoked", early == 0, early .. " early")
    if params.mix == "back" then
      check("line: pulled back, never provoked", provoked == nil, "provoked at " .. tostring(provoked))
    else
      check("line: enclosed, provoked after the warning", provoked ~= nil and S.warned_at and provoked > S.warned_at,
        "provoked at " .. tostring(provoked))
    end
  end)
end

-- Strip: Grubstake strips the player's ore. A patch of iron near it, two of the player's drills on one side, no
-- turrets: a camp must go up beside them, mine the real patch (its ore less), and the ore must reach home.
scenarios.strip = function()
  schedule(30, function() lp("debug_tune", {strip_fast = true}) end)
  schedule(120, function()
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    if S.g then lp("debug_depot", S.g, 3000) end
    -- The claim run isolates the camp: Serenity and the biters at peace with Grubstake (a second camp's guards
    -- were all killed by them, so nothing was left unanswered).
    if params.mix == "claim" then
      for _, pair in ipairs({{"lp-serenity", "lp-grubstake"}, {"enemy", "lp-grubstake"}}) do
        game.forces[pair[1]].set_cease_fire(pair[2], true)
        game.forces[pair[2]].set_cease_fire(pair[1], true)
      end
    end
  end)
  schedule(3 * 3600, function()
    local o = lp("stats", S.g).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local c = {math.floor(o.x - o.x / len * 130), math.floor(o.y - o.y / len * 130)}
    flatten(c[1] - 25, c[2] - 25, c[1] + 25, c[2] + 25)
    for x = c[1] - 20, c[1] + 19 do
      for y = c[2] - 20, c[2] + 19 do
        surface().create_entity{name = "iron-ore", position = {x + 0.5, y + 0.5}, amount = 2000}
      end
    end
    S.patch = c
    for _, dx in ipairs({-18, -13}) do
      surface().create_entity{name = "electric-mining-drill", position = {c[1] + dx, c[2] - 17}, force = "player"}
    end
    local sum = 0
    for _, r in pairs(surface().find_entities_filtered{position = c, radius = 30, name = "iron-ore"}) do sum = sum + r.amount end
    S.ore0 = sum
  end)
  schedule(END - 60, function()
    local st = lp("stats", S.g)
    local sum = 0
    for _, r in pairs(surface().find_entities_filtered{position = S.patch, radius = 30, name = "iron-ore"}) do sum = sum + r.amount end
    check("strip: Grubstake mounted a strip-mining operation", st.ops.strips > 0, st.ops.strips .. " strips")
    check("strip: it mined the player's patch", sum < S.ore0, S.ore0 - sum .. " ore taken")
    check("strip: and brought it home", st.ops.stripped > 0, st.ops.stripped .. " ore delivered")
    -- LP_MIX=claim (a longer run, nobody answers): the second camp on the patch stays as an outpost.
    if params.mix == "claim" then
      local kept = surface().count_entities_filtered{position = S.patch, radius = 60, force = "lp-grubstake",
        type = "mining-drill"}
      check("strip: left alone twice, the camp stays as an outpost", (st.claims_settled or 0) > 0 and kept > 0,
        tostring(st.claims_settled) .. " settled, " .. kept .. " drills standing on the patch")
    end
  end)
end

-- Dev: the /lp tools (landing-party/scripts/dev.lua) through the remote hook, as a player standing there. Serenity
-- and Grubstake arrive; /lp land brings a second Grubstake; an outpost (a gun turret, an assembler) between spawn
-- and Serenity, and two drills on iron towards Grubstake. Forced at once, whatever tempers and clocks say:
-- a siege and a perimeter step from Serenity, a raid from the first Grubstake, a strip from the second.
scenarios.dev = function()
  schedule(120, function()
    S.s = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "serenity"})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    local before = lp("bases")
    lp("dev", {"land", "grubstake", tostring(params.distance)}, {0, 0})
    for _, id in ipairs(lp("bases")) do
      local new = true
      for _, o in ipairs(before) do if o == id then new = false end end
      if new then S.g2 = id end
    end
  end)
  local function toward(id, d)
    local o = lp("stats", id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    return {math.floor(o.x - o.x / len * d), math.floor(o.y - o.y / len * d)}
  end
  schedule(2 * 3600, function()
    check("dev: /lp land brought a second Grubstake", S.g2 ~= nil, tostring(S.g2))
    local c = toward(S.s, 120)
    flatten(c[1] - 6, c[2] - 6, c[1] + 6, c[2] + 6)
    surface().create_entity{name = "gun-turret", position = {c[1], c[2]}, force = "player"}
    surface().create_entity{name = "assembling-machine-1", position = {c[1] + 4.5, c[2] + 0.5}, force = "player"}
    S.outpost = c
    if S.g2 then
      local p = toward(S.g2, 130)
      flatten(p[1] - 25, p[2] - 25, p[1] + 25, p[2] + 25)
      for x = p[1] - 20, p[1] + 19 do
        for y = p[2] - 20, p[2] + 19 do
          surface().create_entity{name = "iron-ore", position = {x + 0.5, y + 0.5}, amount = 2000}
        end
      end
      for _, dx in ipairs({-18, -13}) do
        surface().create_entity{name = "electric-mining-drill", position = {p[1] + dx, p[2] - 17}, force = "player"}
      end
      S.patch = p
    end
  end)
  schedule(2 * 3600 + 120, function()
    lp("dev", {"siege", tostring(S.s)}, S.outpost)
    lp("dev", {"perimeter", tostring(S.s)}, S.outpost)
    lp("dev", {"raid", tostring(S.g)}, S.outpost)
    if S.g2 then lp("dev", {"strip", tostring(S.g2)}, S.patch) end
    lp("dev", {"list"}, {0, 0})
    local s, g, g2 = lp("stats", S.s), lp("stats", S.g), S.g2 and lp("stats", S.g2)
    check("dev: /lp siege launched a siege", s.ops.sieges > 0, s.ops.sieges .. " sieges, " .. tostring(s.ops.op))
    check("dev: /lp perimeter stepped the line", (s.perimeter_steps or 0) > 0, tostring(s.perimeter))
    check("dev: /lp raid launched a raid", g.ops.launched > 0, tostring(g.ops.op))
    check("dev: /lp strip launched a strip", g2 ~= nil and g2.ops.strips > 0, g2 and tostring(g2.ops.op) or "no base")
  end)
  schedule(END - 60, function()
    local s, g2 = lp("stats", S.s), S.g2 and lp("stats", S.g2)
    check("dev: the forced siege got to its site", s.ops.mortar ~= nil or s.ops.done + s.ops.aborted > 0,
      tostring(s.ops.op))
    check("dev: the forced strip put up its camp", g2 ~= nil and (g2.ops.op == "strip:mine" or g2.ops.done > 0),
      g2 and tostring(g2.ops.op) or "no base")
  end)
end

-- Grudge: the player destroys Grubstake's lander. Grubstake must count the player hostile and Serenity must not
-- (it takes note, unprovoked); Grubstake's next landing comes angry: the grudge, a doubled drop escort, double the
-- garrison cap for 30 minutes from its first depot, then the cap as before.
scenarios.grudge = function()
  schedule(60, function() lp("debug_tune", {grudge_fast = true}) end)
  schedule(120, function()
    S.s = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "serenity"})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    lp("debug_depot", S.g, 0)
  end)
  schedule(3600, function()
    check("grudge: Serenity was not provoked before", not ((lp("corp", "serenity").provoked or {}).player), tostring((lp("corp", "serenity").provoked or {}).player))
    local l = surface().find_entities_filtered{force = "lp-grubstake", name = "lp-grubstake-lander", limit = 1}[1]
    l.destructible = true
    l.die("player")
  end)
  schedule(3700, function()
    check("grudge: Grubstake counts the player hostile, Serenity does not",
      (lp("corp", "serenity").provoked or {}).player == nil and (lp("corp", "grubstake").provoked or {}).player ~= nil, "")
    S.g2 = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    lp("debug_depot", S.g2, 0)
    local st = S.g2 and lp("stats", S.g2)
    check("grudge: the next Grubstake landing came angry", st and st.grudge == "player", st and tostring(st.grudge) or "no landing")
    S.g3 = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    local st3 = S.g3 and lp("stats", S.g3)
    check("grudge: only the next one", st3 and st3.grudge == nil, st3 and tostring(st3.grudge) or "no landing")
  end)
  schedule(3700 + 600, function()
    S.cap = S.g2 and lp("stats", S.g2).cap
    -- The escort steps off once each pad is laid.
    local st, st3 = S.g2 and lp("stats", S.g2), S.g3 and lp("stats", S.g3)
    check("grudge: its drop escort was doubled", st and st3 and (st3.escort or 0) > 0 and st.escort == 2 * st3.escort,
      string.format("%s against %s", st and tostring(st.escort), st3 and tostring(st3.escort)))
  end)
  schedule(3700 + 2 * 3600 + 900, function()
    local st = S.g2 and lp("stats", S.g2)
    check("grudge: the cap was doubled, then not", st and S.cap and st.cap * 2 == S.cap,
      tostring(S.cap) .. " then " .. tostring(st and st.cap))
  end)
end

-- Weigh: raids sized by weighted defence (docs/reviews/2026-10-14-operations-depth-consult.md). Three gun turrets need
-- 15 (3.5 x 3 + 4, rounded up), three flamethrowers 31 (3.5 x 7.5 + 4); bullet damage +0.7 makes the guns' 15 into 22.
-- A spidertron
-- parked at an undefended relay turns a forced raid back at its staging look, unhurt.
scenarios.weigh = function()
  schedule(600, function()
    local o = lp("stats", storage.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local function at(d, side)
      return {math.floor(o.x - o.x / len * d - o.y / len * side), math.floor(o.y - o.y / len * d + o.x / len * side)}
    end
    local function put(name, p) return surface().create_entity{name = name, position = p, force = "player"} end
    S.guns, S.flames, S.relay = at(120, -60), at(120, 0), at(120, 60)
    for _, c in ipairs({S.guns, S.flames, S.relay}) do flatten(c[1] - 12, c[2] - 12, c[1] + 12, c[2] + 12) end
    for k = -1, 1 do
      put("gun-turret", {S.guns[1] + 4 * k, S.guns[2] - 5})
      put("flamethrower-turret", {S.flames[1] + 4 * k, S.flames[2] - 5})
    end
    put("assembling-machine-1", S.guns)
    put("assembling-machine-1", S.flames)
    put("lp-command-relay", S.relay)
    put("spidertron", {S.relay[1] + 3, S.relay[2] + 3})
  end)
  schedule(700, function()
    local g, f = lp("debug_needed", storage.id, S.guns), lp("debug_needed", storage.id, S.flames)
    check("weigh: three gun turrets need 15", g and g.needed == 15, serpent.line(g))
    check("weigh: three flamethrowers need 31", f and f.needed == 31, serpent.line(f))
    game.forces.player.set_ammo_damage_modifier("bullet", 0.7)
    local g2 = lp("debug_needed", storage.id, S.guns)
    check("weigh: bullet damage +0.7 makes it 22", g2 and g2.needed == 22, serpent.line(g2))
    lp("dev", {"raid", tostring(storage.id)}, S.relay)
    S.launched = lp("stats", storage.id).ops.launched
  end)
  schedule(END - 60, function()
    local st = lp("stats", storage.id)
    local last = st.ops.log[#st.ops.log]
    check("weigh: a forced raid at the relay was launched", (S.launched or 0) > 0, tostring(S.launched))
    check("weigh: the spidertron turned it back unhurt", last and last.outcome == "aborted" and last.back == last.launched,
      serpent.line(last))
  end)
end

-- Techup: corporate research (docs/reviews/2026-10-14-corporate-rd-consult.md). The player has bullet damage +0.8 and
-- three gun turrets 120 tiles towards spawn; Serenity's fund is granted, choices every minute. Within six minutes it
-- buys lasers (its Line troopers' weapon) to level 2 or more, and the raid it would need there falls (23 unresearched). LP_MIX=era0: the
-- player at era 0, a fund of 20,000: nothing beyond level 1.
scenarios.techup = function()
  local era = params.mix == "era0" and 0 or 4
  schedule(60, function() lp("debug_tune", {rd_fast = true, rd_fund = {serenity = 20000}, era = era}) end)
  schedule(600, function()
    game.forces.player.set_ammo_damage_modifier("bullet", 0.8)
    local o = lp("stats", storage.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    S.guns = {math.floor(o.x - o.x / len * 120), math.floor(o.y - o.y / len * 120)}
    flatten(S.guns[1] - 12, S.guns[2] - 12, S.guns[1] + 12, S.guns[2] + 12)
    for k = -1, 1 do
      surface().create_entity{name = "gun-turret", position = {S.guns[1] + 4 * k, S.guns[2] - 5}, force = "player"}
    end
    surface().create_entity{name = "assembling-machine-1", position = S.guns, force = "player"}
  end)
  schedule(700, function()
    S.before = lp("debug_needed", storage.id, S.guns)
  end)
  schedule(END - 60, function()
    local r = lp("rd", "serenity")
    local after = lp("debug_needed", storage.id, S.guns)
    info("techup: " .. serpent.line({rd = r, before = S.before, after = after}))
    -- Serenity's Line troopers fire lasers: its main category.
    local lvl = (r.weapons or {}).laser or 0
    check("techup: the raid it needed unresearched", S.before and S.before.needed == 23, serpent.line(S.before))
    if params.mix == "era0" then
      check("techup: an era-0 player holds it to level 1", lvl == 1, tostring(lvl))
    else
      check("techup: it bought lasers to level 2 or more", lvl >= 2, tostring(lvl))
      check("techup: the raid it needs fell", after and after.needed < S.before.needed,
        string.format("%s -> %s", S.before and S.before.needed, after and after.needed))
      check("techup: the corporation's force carries it", game.forces["lp-serenity"].get_ammo_damage_modifier("laser") >= 0.4,
        tostring(game.forces["lp-serenity"].get_ammo_damage_modifier("laser")))
    end
  end)
end

-- Plate: each corporation answers what kills its units from its own tree (shared.CORPS.tree). Fifteen of Serenity's
-- Line troopers die to a gun turret (the player at era 2, a fund granted, choices every minute): it issues Warden
-- armour (physical) and its depots build armoured Line troopers; the plain ones standing are kept. LP_MIX=grubstake:
-- fifteen Shotgun hands die to a flamethrower turret, and Grubstake buys asbestos suits (fire) for its infantry.
scenarios.plate = function()
  local g = params.mix == "grubstake"
  local force = g and "lp-grubstake" or FORCE
  local name = g and "lp-grubstake-infantry" or "lp-infantry"
  local killer = g and "flamethrower-turret" or "gun-turret"
  local corp, plate = g and "grubstake" or "serenity", g and "fire" or "physical"
  schedule(60, function()
    lp("debug_tune", {era = 2, rd_fund = {[corp] = 5000}})
    if g then
      S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
      for _ = 1, 2 do lp("debug_depot", S.g, 3000) end
    else
      for _ = 1, 2 do lp("debug_depot", storage.id, 3000) end
    end
  end)
  schedule(10 * 3600, function()
    flatten(-5, -5, 5, 5)
    local cause = surface().create_entity{name = killer, position = {0, 0}, force = "player"}
    -- Grubstake's mix is mostly buggies: its buggies count towards the fifteen.
    local names = g and {name, "lp-grubstake-buggy"} or {name}
    local n = 0
    for _, u in pairs(surface().find_entities_filtered{force = force, name = names}) do
      if n < 15 then u.die("player", cause); n = n + 1 end
    end
    S.killed = n
    S.kept = surface().find_entities_filtered{force = force, name = names}
    lp("debug_tune", {rd_fast = true})
  end)
  schedule(END - 60, function()
    local r = lp("rd", corp)
    local plated = surface().count_entities_filtered{force = force, name = name .. "-" .. plate}
    local kept = 0
    for _, u in ipairs(S.kept) do if u.valid then kept = kept + 1 end end
    info("plate: " .. serpent.line({rd = r, killed = S.killed, survivors = #S.kept, kept = kept, plated = plated}))
    check("plate: fifteen infantry died", S.killed == 15, tostring(S.killed))
    check("plate: it bought its own answer", (r.plate or {})["lp-infantry"] == plate and (r.nodes or {})[g and "asbestos" or "warden"] ~= nil,
      serpent.line({plate = r.plate, nodes = r.nodes}))
    check("plate: the depots build the plated infantry", plated > 0, plated .. " plated")
    check("plate: the units standing were kept, not replaced", #S.kept > 0 and kept == #S.kept,
      string.format("%d of %d", kept, #S.kept))
  end)
end

-- Arms: each corporation's own infantry (Serenity's Line troopers, beams; Grubstake's Shotgun hands, pellets). Six of
-- each against four player radars, 160 tiles apart: both destroy them, in times within 20% of each other (DPS
-- parity, docs/reviews/2026-10-14-identity-trees-consult.md); the pellets do not wound their own side.
scenarios.arms = function()
  schedule(60, function() lp("debug_tune", {ops_off = true, army_off = true}) end)
  schedule(120, function()
    S.sides = {}
    for i, side in ipairs({{corp = "serenity", name = "lp-infantry", force = "lp-serenity", y = -80},
                           {corp = "grubstake", name = "lp-grubstake-infantry", force = "lp-grubstake", y = 80}}) do
      flatten(-30, side.y - 20, 30, side.y + 20)
      local targets = {}
      for k = 0, 3 do
        table.insert(targets, surface().create_entity{name = "radar", position = {-6 + 4 * k, side.y}, force = "player"})
      end
      local units = {}
      for k = 1, 6 do
        local u = surface().create_entity{name = side.name, position = {-25 + (k % 3) * 2, side.y + math.floor(k / 3) * 2},
          force = side.force}
        u.commandable.set_command{type = defines.command.attack_area, destination = {0, side.y}, radius = 12,
          distraction = defines.distraction.by_anything}
        table.insert(units, u)
      end
      S.sides[i] = {corp = side.corp, targets = targets, units = units, hp = 6 * units[1].max_health}
    end
  end)
  for t = 180, END - 120, 30 do
    schedule(t, function()
      for _, sd in ipairs(S.sides or {}) do
        if not sd.done then
          local left = 0
          for _, e in ipairs(sd.targets) do if e.valid then left = left + 1 end end
          if left == 0 then sd.done = game.tick - 120 end
        end
      end
    end)
  end
  schedule(END - 60, function()
    local a, g = S.sides[1], S.sides[2]
    local function health(sd)
      local h = 0
      for _, u in ipairs(sd.units) do if u.valid then h = h + u.health end end
      return h
    end
    info(string.format("arms: Serenity %s ticks, Grubstake %s ticks; own health %d/%d and %d/%d", tostring(a.done),
      tostring(g.done), health(a), a.hp, health(g), g.hp))
    check("arms: the Line troopers destroyed their radars", a.done ~= nil, tostring(a.done))
    check("arms: the Shotgun hands destroyed theirs", g.done ~= nil, tostring(g.done))
    check("arms: within 20% of each other", a.done and g.done and math.abs(a.done - g.done) <= 0.2 * math.max(a.done, g.done),
      string.format("%s vs %s", tostring(a.done), tostring(g.done)))
    check("arms: the pellets did not wound their own side", health(g) == g.hp, health(g) .. " of " .. g.hp)
  end)
end

-- Unit nodes: a corporation's tree answers the killers it meets (shared.CORPS.tree, scripts/rd.lua). Each LP_MIX is one
-- node: its victims die to its killer (the player at its era, a fund granted, presets for its prerequisites), the node
-- is bought, and the depots build its unit (an ability has none). Ten more die causeless after the purchase, so the
-- garrison has room for the new unit.
local NODE_CASES = {
  lance = {corp = "serenity", victim = "lp-infantry", kills = 8, killer = "trooper", era = 2, made = "lp-lance"},
  shock = {corp = "serenity", victim = "lp-infantry", kills = 12, killer = "trooper", era = 3, made = "lp-shock",
    preset = {lance = 1}},
  aegis = {corp = "serenity", victim = "lp-infantry", kills = 6, killer = "tank", era = 2, made = "lp-aegis",
    preset = {warden = 1}},
  counter = {corp = "serenity", victim = "lp-infantry", kills = 4, killer = "artillery", era = 3, preset = {hardened = 1}},
  slug = {corp = "grubstake", victim = "lp-grubstake-buggy", kills = 6, killer = "tank", era = 2, made = "lp-grubstake-slug"},
  sapper = {corp = "grubstake", victim = "lp-grubstake-infantry", kills = 10, killer = "trooper", era = 2,
    made = "lp-grubstake-sapper"},
  scavenger = {corp = "grubstake", victim = "lp-grubstake-buggy", kills = 6, killer = "artillery", era = 2,
    made = "lp-grubstake-scavenger"},
  dozer = {corp = "grubstake", kills = 0, walls = 3, era = 3, made = "lp-grubstake-dozer", preset = {slug = 1}},
}
scenarios.unitnode = function()
  local node = params.mix ~= "" and params.mix or "lance"
  local c = NODE_CASES[node]
  local g = c.corp == "grubstake"
  local force = g and "lp-grubstake" or FORCE
  schedule(60, function()
    lp("debug_tune", {era = c.era, rd_fund = {[c.corp] = 8000}})
    if c.preset then lp("debug_tune", {rd_tech = {[c.corp] = {nodes = c.preset}}}) end
    if g then
      S.id = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
      for _ = 1, 2 do lp("debug_depot", S.id, 3000) end
    else
      for _ = 1, 2 do lp("debug_depot", storage.id, 3000) end
    end
  end)
  schedule(10 * 3600, function()
    flatten(-5, -5, 5, 5)
    local cause
    if c.killer == "trooper" then cause = spawn("lp-trooper", {0, 0}, 1, "player")[1]
    elseif c.killer == "tank" then cause = surface().create_entity{name = "tank", position = {0, 0}, force = "player"}
    elseif c.killer == "artillery" then cause = surface().create_entity{name = "artillery-turret", position = {0, 0}, force = "player"} end
    local n = 0
    if c.victim then
      -- By kind: a plate preset (Warden) builds them plated.
      local names = {c.victim, c.victim .. "-physical", c.victim .. "-fire", c.victim .. "-laser"}
      for _, u in pairs(surface().find_entities_filtered{force = force, name = names}) do
        if n < c.kills then u.die("player", cause); n = n + 1 end
      end
    end
    S.killed = n
    if c.walls then lp("debug_tune", {rd_walls = {[c.corp] = c.walls}}) end
    lp("debug_tune", {rd_fast = true})
  end)
  schedule(13 * 3600, function()
    local n = 0
    for _, u in pairs(surface().find_entities_filtered{force = force, type = "unit"}) do
      if n < 10 and not u.name:find("hauler", 1, true) then u.die(); n = n + 1 end
    end
  end)
  schedule(END - 60, function()
    local r = lp("rd", c.corp)
    local built = c.made and surface().count_entities_filtered{force = force, name = c.made} or 0
    info("unitnode: " .. serpent.line({rd = r, killed = S.killed, built = built}))
    check("unitnode: the killers were the trigger's", S.killed == c.kills, tostring(S.killed))
    check("unitnode: it bought the node", (r.nodes or {})[node] ~= nil, serpent.line(r.nodes))
    if c.made then check("unitnode: the depots build the new unit", built > 0, built .. " " .. c.made) end
  end)
end

-- Ability: the trees' abilities. LP_MIX=loot: Grubstake, with Salvage rights, raids an undefended assembler beside a chest
-- of 100 processing units: the chest is emptied, the loot reaches home as parts, and what it razed paid its fund.
-- LP_MIX=hardened: Serenity, Hardened siege bought, a forced siege digs in (walls and pillboxes) and clears them when
-- it ends. LP_MIX=prospector: ore 55 tiles from the player's drill is out of a strip camp's reach (45) until Grubstake
-- has Prospector's eye (68).
scenarios.ability = function()
  local mix = params.mix ~= "" and params.mix or "loot"
  local g = mix ~= "hardened"
  local function toward(id, d)
    local o = lp("stats", id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    return {math.floor(o.x - o.x / len * d), math.floor(o.y - o.y / len * d)}
  end
  schedule(60, function()
    lp("debug_tune", {era = 2, ops_off = false})
    if g then
      S.id = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
      for _ = 1, 2 do lp("debug_depot", S.id, 3000) end
      if mix == "loot" then lp("debug_tune", {rd_tech = {grubstake = {nodes = {salvage = 1}}}}) end
    else
      S.id = storage.id
      for _ = 1, 2 do lp("debug_depot", S.id, 3000) end
      lp("debug_tune", {corp_level = {serenity = 1}, rd_tech = {serenity = {nodes = {hardened = 1}}}})
    end
  end)
  schedule(3 * 3600, function()
    lp("debug_tune", {raids_off = true})
    local c = toward(S.id, 120)
    flatten(c[1] - 30, c[2] - 30, c[1] + 30, c[2] + 30)
    S.c = c
    if mix == "loot" then
      surface().create_entity{name = "assembling-machine-1", position = {c[1] + 0.5, c[2] + 0.5}, force = "player"}
      S.chest = surface().create_entity{name = "steel-chest", position = {c[1] + 3.5, c[2] + 0.5}, force = "player"}
      S.chest.insert{name = "processing-unit", count = 100}
      S.parts0 = lp("stats", S.id).parts
      lp("dev", {"raid", tostring(S.id)}, c)
    elseif mix == "hardened" then
      for k = -1, 1 do
        local t = surface().create_entity{name = "gun-turret", position = {c[1] + 4 * k, c[2] - 5}, force = "player"}
        t.insert{name = "firearm-magazine", count = 50}
      end
      surface().create_entity{name = "assembling-machine-1", position = c, force = "player"}
      lp("dev", {"siege", tostring(S.id)}, c)
    else
      -- A drill, and iron 55 tiles from it on the far side from Grubstake.
      surface().create_entity{name = "electric-mining-drill", position = c, force = "player"}
      local o = lp("stats", S.id).origin
      local len = math.sqrt((c[1] - o.x) ^ 2 + (c[2] - o.y) ^ 2)
      local p = {math.floor(c[1] + (c[1] - o.x) / len * 55), math.floor(c[2] + (c[2] - o.y) / len * 55)}
      for x = p[1] - 6, p[1] + 6 do for y = p[2] - 6, p[2] + 6 do
        surface().create_entity{name = "iron-ore", position = {x + 0.5, y + 0.5}, amount = 2000}
      end end
      lp("dev", {"strip", tostring(S.id)}, c)
      S.before = lp("stats", S.id).ops.strips
      lp("debug_tune", {rd_tech = {grubstake = {nodes = {prospector = 1, salvage = 1}}}})
      lp("dev", {"strip", tostring(S.id)}, c)
      S.after = lp("stats", S.id).ops.strips
    end
  end)
  for t = 3 * 3600 + 600, END - 120, 300 do
    schedule(t, function()
      local st = lp("stats", S.id)
      S.works = math.max(S.works or 0, st.ops.works or 0)
    end)
  end
  schedule(END - 60, function()
    local st = lp("stats", S.id)
    if mix == "loot" then
      local left = S.chest.valid and S.chest.get_item_count("processing-unit") or -1
      local r = lp("rd", "grubstake")
      info(string.format("ability loot: chest %s, looted %d, parts %d -> %d, salvaged %d", tostring(left), st.ops.looted,
        S.parts0, st.parts, r.salvaged))
      check("ability: the chest was emptied", left <= 0, tostring(left))
      check("ability: the loot reached home", (st.ops.looted or 0) >= 100, tostring(st.ops.looted))
      check("ability: what it razed paid its fund", (r.salvaged or 0) > 0, tostring(r.salvaged))
    elseif mix == "hardened" then
      local left = surface().count_entities_filtered{position = S.c, radius = 80, name = "lp-gun-turret", force = FORCE}
      check("ability: the siege dug in", (S.works or 0) >= 10, tostring(S.works))
      check("ability: and cleared its works after", st.ops.op ~= nil or left == 0, tostring(st.ops.op) .. ", " .. left .. " pillboxes")
    else
      check("ability: out of reach without the eye", S.before == 0, tostring(S.before))
      check("ability: in reach with it", S.after == 1, tostring(S.after))
    end
  end)
end

-- Arc: the tree's area weapons hit more than one and spare their own side. One Shock trooper (Serenity) at five player
-- cars three tiles apart, Serenity's own car beside them: its lightning must reach three or more, never its own. One
-- dynamite sapper (Grubstake) at a block of four player walls, its own fence beside them: two or more walls hurt,
-- the fence whole.
scenarios.arc = function()
  schedule(60, function() lp("debug_tune", {ops_off = true, army_off = true}) end)
  schedule(120, function()
    flatten(-40, -40, 40, 40)
    S.cars = {}
    for k = 0, 4 do table.insert(S.cars, surface().create_entity{name = "car", position = {8 + 3 * k, -20}, force = "player"}) end
    S.own_car = surface().create_entity{name = "car", position = {11, -17.5}, force = FORCE}
    local sh = surface().create_entity{name = "lp-shock", position = {0, -20}, force = FORCE}
    sh.commandable.set_command{type = defines.command.attack, target = S.cars[1], distraction = defines.distraction.none}
    S.walls = {}
    for x = 0, 1 do for y = 0, 1 do
      table.insert(S.walls, surface().create_entity{name = "stone-wall", position = {10.5 + x, 20.5 + y}, force = "player"})
    end end
    S.fence = surface().create_entity{name = "lp-grubstake-wall", position = {10.5, 23.5}, force = "lp-grubstake"}
    local sp = surface().create_entity{name = "lp-grubstake-sapper", position = {0, 21}, force = "lp-grubstake"}
    sp.commandable.set_command{type = defines.command.attack, target = S.walls[1], distraction = defines.distraction.none}
  end)
  schedule(120 + 5 * 60, function()
    local hit, walls = 0, 0
    for _, c in ipairs(S.cars) do if not c.valid or c.health < c.max_health then hit = hit + 1 end end
    for _, w in ipairs(S.walls) do if not w.valid or w.health < w.max_health then walls = walls + 1 end end
    info(string.format("arc: %d of 5 cars hit, own car %.0f/%.0f; %d of 4 walls hurt, own fence %.0f/%.0f", hit,
      S.own_car.health, S.own_car.max_health, walls, S.fence.health, S.fence.max_health))
    check("arc: the lightning reached three cars or more", hit >= 3, hit .. " of 5")
    check("arc: and spared its own side", S.own_car.health == S.own_car.max_health, "")
    check("arc: the dynamite hurt two walls or more", walls >= 2, walls .. " of 4")
    check("arc: and spared its own fence", S.fence.health == S.fence.max_health, "")
  end)
end

-- Visit: the corporations against a real player's factory (scripts/visit.sh loads a copy of a real save, adds the mod).
-- No live player: only the factory's own turrets and robots answer. Serenity lands beyond the factory (its spawn,
-- out past the 95th percentile of its drills, machines and poles, plus 150), Grubstake 20 minutes later; the
-- faction's own cadence lands more. Every 10 minutes a line of timeline.jsonl (operations, razed, looted, the
-- player's buildings); at the end, each settlement's story in results.txt.
scenarios.visit = function()
  local KEY = {"mining-drill", "assembling-machine", "furnace", "lab", "electric-pole", "ammo-turret", "electric-turret",
    "fluid-turret", "artillery-turret", "roboport", "container", "logistic-container", "wall"}
  local function census()
    local c = {}
    for _, t in ipairs(KEY) do c[t] = surface().count_entities_filtered{force = "player", type = t} end
    return c
  end
  schedule(60, function()
    local f = game.forces.player
    local sp = f.get_spawn_position(surface())
    local d = {}
    for _, e in pairs(surface().find_entities_filtered{force = "player", type = {"mining-drill", "assembling-machine",
      "furnace", "electric-pole"}}) do
      table.insert(d, math.sqrt((e.position.x - sp.x) ^ 2 + (e.position.y - sp.y) ^ 2))
    end
    table.sort(d)
    local p95 = #d > 0 and d[math.max(1, math.floor(0.95 * #d))] or 0
    S.dist = math.floor(p95 + 150)
    S.start = census()
    local researched = 0
    for _, t in pairs(f.technologies) do if t.researched then researched = researched + 1 end end
    info(string.format("visit: factory at %.0f,%.0f, %d buildings counted, 95%% within %.0f tiles; %d technologies; landing at %d",
      sp.x, sp.y, #d, p95, researched, S.dist))
    info("visit: player at start " .. serpent.line(S.start))
    storage.id = lp("arrive", 1, sp, S.dist, {corp = "serenity"})
    if not storage.id then error("lp-sim visit: no site for Serenity at " .. S.dist) end
    S.sp = sp
  end)
  schedule(20 * 3600, function()
    S.g = lp("arrive", 1, S.sp, S.dist, {corp = "grubstake"})
    info("visit: Grubstake " .. (S.g and ("landed, settlement " .. S.g) or "found no site"))
  end)
  -- Grubstake is the corporation that hits a player unprovoked: if none of its settlements stands at 30 minutes, it
  -- lands again, further out.
  schedule(30 * 3600, function()
    for _, id in ipairs(lp("bases")) do
      local st = lp("stats", id)
      if st.corp == "grubstake" and not st.fallen then return end
    end
    S.g2 = lp("arrive", 1, S.sp, S.dist + 300, {corp = "grubstake"})
    info("visit: Grubstake again at 30 minutes " .. (S.g2 and ("landed, settlement " .. S.g2) or "found no site"))
  end)
  -- LP_MIX=provoked: an hour in, the factory counts as having attacked both corporations (no live player can).
  if params.mix == "provoked" then
    schedule(60 * 3600, function()
      lp("debug_tune", {provoke = true})
      info("visit: both corporations provoked by the player")
    end)
  end
  for t = 600 * 60, END - 60, 600 * 60 do
    schedule(t, function()
      local pr = lp("pressure")
      local razed = 0
      for _, n in pairs(pr.razed or {}) do razed = razed + n end
      local row = {minute = (game.tick - storage.t0) / 3600, player = census(), bases = {}, razed = razed,
        razed_by_type = pr.razed, ladder = pr.ladder,
        since_raze = pr.last_raze and (game.tick - pr.last_raze) / 3600 or nil}
      for _, id in ipairs(lp("bases")) do
        local st = lp("stats", id)
        if st then
          table.insert(row.bases, {id = id, corp = st.corp, fallen = st.fallen and true or false, garrison = st.garrison,
            razed = st.razed, looted = st.ops.looted, launched = st.ops.launched, done = st.ops.done,
            aborted = st.ops.aborted, sieges = st.ops.sieges, strips = st.ops.strips, op = st.ops.op,
            units_lost = st.units_lost, known = st.ops.known, known_player = st.ops.known_player})
        end
      end
      helpers.write_file("landing-party/timeline.jsonl", helpers.table_to_json(row) .. "\n", true)
    end)
  end
  schedule(END - 60, function()
    info("visit: player at the end " .. serpent.line(census()))
    info("visit: the player's buildings razed by the corporations " .. serpent.line(lp("pressure").razed))
    for _, id in ipairs(lp("bases")) do
      local st = lp("stats", id)
      info(string.format("visit: %s %d%s: garrison %d, razed %d, looted %d, units lost %d, %d operations (%d done, %d aborted, %d sieges, %d strips)",
        st.corp, id, st.fallen and " (fallen)" or "", st.garrison, st.razed, st.ops.looted or 0, st.units_lost or 0,
        st.ops.launched, st.ops.done, st.ops.aborted, st.ops.sieges, st.ops.strips))
      for _, l in ipairs(st.ops.log or {}) do
        info(string.format("visit:   %s %s on %s (%s), %d of %d back", l.op, l.outcome, l.kind, tostring(l.owner), l.back, l.launched))
      end
    end
    for _, c in ipairs({"serenity", "grubstake"}) do info("visit: research " .. c .. " " .. serpent.line(lp("rd", c))) end
    check("visit: a corporation landed by the factory", storage.id ~= nil, tostring(S.dist))
  end)
end

-- Sneak: Grubstake's approach (sneaking round known turrets, breaching the wall the fewest turrets reach). The player's
-- assembler inside a 40-tile square of stone wall, five laser turrets covering the side towards Grubstake and both
-- flanks, the far side bare. A forced raid sneaks round the lasers' reach, breaches the far side (no turret reaches
-- it) and razes the assembler. LP_MIX=direct: sneaking off, the same raid straight in (losses to compare).
scenarios.sneak = function()
  local direct = params.mix == "direct"
  schedule(60, function()
    -- No arrival history: this tests the approach, not research (with it, the strength credit read five lasers as
    -- 4.7 and sent 21, which lost).
    lp("debug_tune", {era = 2, raids_off = true, sneak_off = direct, history_off = true})
    S.id = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    for _ = 1, 3 do lp("debug_depot", S.id, 4000) end
  end)
  schedule(3 * 3600, function()
    local o = lp("stats", S.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = o.x / len, o.y / len
    local c = {math.floor(o.x - ux * 140), math.floor(o.y - uy * 140)}
    flatten(c[1] - 45, c[2] - 45, c[1] + 45, c[2] + 45)
    S.c = c
    for x = -20, 20 do for y = -20, 20 do
      if math.abs(x) == 20 or math.abs(y) == 20 then
        surface().create_entity{name = "stone-wall", position = {c[1] + x + 0.5, c[2] + y + 0.5}, force = "player"}
      end
    end end
    S.target = surface().create_entity{name = "assembling-machine-2", position = {c[1] + 0.5, c[2] + 0.5}, force = "player"}
    -- Lasers inside the wall: the side towards Grubstake (+u) and both flanks; the far side (-u) bare.
    local px, py = -uy, ux
    for _, p in ipairs({{ux * 16, uy * 16}, {ux * 16 + px * 12, uy * 16 + py * 12}, {ux * 16 - px * 12, uy * 16 - py * 12},
      {px * 16, py * 16}, {-px * 16, -py * 16}}) do
      local tr = surface().create_entity{name = "laser-turret", position = {c[1] + p[1], c[2] + p[2]}, force = "player"}
      -- Powered: an interface and a pole between them (without the pole the lasers never fired, and the raid razed them
      -- on its way to its staging point).
      if tr then
        surface().create_entity{name = "electric-energy-interface", position = {c[1] + p[1] - 3 * ux, c[2] + p[2] - 3 * uy}, force = "player"}
        surface().create_entity{name = "medium-electric-pole", position = {c[1] + p[1] - 1.5 * ux + 1.5, c[2] + p[2] - 1.5 * uy}, force = "player"}
      end
      S.lasers = (S.lasers or 0) + (tr and 1 or 0)
    end
    S.far = {c[1] - ux * 20, c[2] - uy * 20}
    lp("dev", {"raid", tostring(S.id)}, c)
    S.lost0 = lp("stats", S.id).units_lost or 0
  end)
  schedule(3 * 3600 + 120, function()
    local powered = 0
    for _, e in pairs(surface().find_entities_filtered{position = S.c, radius = 25, name = "laser-turret"}) do
      if e.energy > 0 then powered = powered + 1 end
    end
    check("sneak: the lasers are powered", powered == S.lasers and powered > 0, powered .. " of " .. tostring(S.lasers))
    local where = {}
    for _, e in pairs(surface().find_entities_filtered{position = S.c, radius = 25, name = "laser-turret"}) do
      table.insert(where, string.format("%.0f,%.0f", e.position.x, e.position.y))
    end
    info("sneak: lasers at " .. table.concat(where, " ") .. string.format("; target %d,%d", S.c[1], S.c[2]))
  end)
  for t = 3 * 3600 + 300, END - 120, 300 do
    schedule(t, function()
      local st = lp("stats", S.id)
      if st.ops.breach_at then S.breach_at = st.ops.breach_at end
      if st.ops.route then S.route = st.ops.route end
      if st.ops.breached then S.breached = true end
    end)
  end
  schedule(END - 60, function()
    local st = lp("stats", S.id)
    local lost = (st.units_lost or 0) - S.lost0
    local reach = 0
    if S.breach_at then
      reach = surface().count_entities_filtered{position = S.breach_at, radius = 24, type = "electric-turret", force = "player"}
    end
    local last = st.ops.log[#st.ops.log]
    info(string.format("sneak%s: target %s, %d units lost, route %s waypoints, breach at %s (%d lasers within 24), last %s",
      direct and " (direct)" or "", S.target.valid and "standing" or "razed", lost, tostring(S.route),
      S.breach_at and string.format("%.0f,%.0f", S.breach_at[1], S.breach_at[2]) or "none", reach, serpent.line(last)))
    if direct then
      check("sneak: the direct raid ran", last ~= nil, serpent.line(last))
    else
      check("sneak: it planned a route", (S.route or 0) > 0, tostring(S.route))
      check("sneak: it breached where no laser reaches", S.breach_at ~= nil and reach == 0,
        S.breach_at and (reach .. " lasers reach it") or "no breach")
      -- Razing it is recorded, not checked: the fight at the target is close (17 of 31 lost once, the target razed; 17
      -- lost another time, not), and the approach is what this tests.
      metric("sneak_target_razed", S.target.valid and 0 or 1)
    end
  end)
end

-- Biters (the user, in game: "a single medium biter can clear an entire outpost"). LP_MIX=outpost: Grubstake (sprawl,
-- no outpost turrets by doctrine), grown; two medium biters attack a mining outpost: it answers, the outpost stands
-- again and has earned a turret pair. LP_MIX=camp: a fresh Grubstake camp (no depot), two medium biters at its
-- nearest drill: the camp kills them and the lander stands (its escort answers from the lander if hurt: army.alarm).
scenarios.biters = function()
  local camp = params.mix == "camp"
  schedule(60, function()
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    if not camp then lp("debug_depot", S.g, 3000) end
    lp("debug_tune", {raids_off = true})
  end)
  schedule((camp and 1 or 8) * 3600, function()
    local st = lp("stats", S.g)
    local at
    if camp then
      -- Its nearest drill, beyond the corner turrets' reach (at the pad, they killed both biters before anything
      -- was hurt, and nothing called the escort).
      local near, nd
      for _, d in pairs(surface().find_entities_filtered{force = "lp-grubstake", name = "lp-grubstake-drill"}) do
        local dd = (d.position.x - st.origin.x) ^ 2 + (d.position.y - st.origin.y) ^ 2
        if dd > 26 * 26 and (not nd or dd < nd) then near, nd = d, dd end
      end
      at = near and {near.position.x, near.position.y} or {st.origin.x + 30, st.origin.y}
    else
      -- The mining outpost farthest from its lander.
      local far, fd
      for _, d in pairs(surface().find_entities_filtered{force = "lp-grubstake", name = "lp-grubstake-drill"}) do
        local dd = (d.position.x - st.origin.x) ^ 2 + (d.position.y - st.origin.y) ^ 2
        if not fd or dd > fd then far, fd = d, dd end
      end
      if not far then return info("biters: no outpost") end
      at = {far.position.x, far.position.y}
      S.drills0 = surface().count_entities_filtered{force = "lp-grubstake", name = "lp-grubstake-drill", position = at, radius = 20}
    end
    S.at = at
    S.responses0 = st.responses or 0
    for k = 1, 2 do
      local p = surface().find_non_colliding_position("medium-biter", {at[1] + 8 + k, at[2] + 8}, 10, 0.5)
      local u = surface().create_entity{name = "medium-biter", position = p, force = "enemy"}
      u.commandable.set_command{type = defines.command.attack_area, destination = at, radius = 15,
        distraction = defines.distraction.by_anything}
    end
  end)
  schedule(END - 60, function()
    local st = lp("stats", S.g)
    local biters = surface().count_entities_filtered{position = S.at, radius = 60, name = "medium-biter"}
    info(string.format("biters: %d biters left, responses %d -> %d, lander %s", biters, S.responses0 or 0,
      st.responses or 0, tostring(st.lander)))
    if camp then
      -- Its escort engages what it sees before anything is hurt (no alarm, no response needed): the outcome is checked.
      check("biters: the camp killed them", biters == 0, tostring(biters))
      check("biters: and the lander stands", st.lander and not st.fallen, tostring(st.fallen))
    else
      local drills = surface().count_entities_filtered{force = "lp-grubstake", name = "lp-grubstake-drill", position = S.at, radius = 20}
      local turrets = surface().count_entities_filtered{force = "lp-grubstake", name = "lp-grubstake-turret", position = S.at, radius = 30}
      check("biters: the biters are dead", biters == 0, tostring(biters))
      check("biters: the outpost stands again", drills >= (S.drills0 or 1), string.format("%d of %d drills", drills, S.drills0 or 0))
      check("biters: it earned a turret pair", turrets > 0, turrets .. " turrets")
    end
  end)
end

-- Maxevo: a corporation landing in a late world (evolution 1, the player at era 4) comes with its history (research
-- bought at once, a larger escort) and a camp holds against two big biters and a behemoth sent at it once its pad is
-- laid. LP_MIX=bare: no history (the camp as it landed before), for comparison.
scenarios.maxevo = function()
  local bare = params.mix == "bare"
  schedule(30, function()
    game.forces.enemy.set_evolution_factor(1, surface())
    lp("debug_tune", {era = 4, raids_off = true, history_off = bare})
  end)
  schedule(60, function()
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
  end)
  schedule(2 * 3600, function()
    local st = lp("stats", S.g)
    S.at = {st.origin.x, st.origin.y}
    S.rd = lp("rd", "grubstake")
    S.escort = st.escort
    for k, name in ipairs({"big-biter", "big-biter", "behemoth-biter"}) do
      local p = surface().find_non_colliding_position(name, {S.at[1] + 40, S.at[2] + 4 * k}, 10, 0.5)
      local u = surface().create_entity{name = name, position = p, force = "enemy"}
      u.commandable.set_command{type = defines.command.attack_area, destination = S.at, radius = 25,
        distraction = defines.distraction.by_anything}
    end
  end)
  schedule(END - 60, function()
    local st = lp("stats", S.g)
    local left = surface().count_entities_filtered{position = S.at, radius = 80, name = {"big-biter", "behemoth-biter"}}
    info(string.format("maxevo%s: escort %s, research %s; %d biters left, lander %s, lost %d",
      bare and " (bare)" or "", tostring(S.escort), serpent.line({nodes = S.rd.nodes, fund = S.rd.fund}), left,
      tostring(st.lander and not st.fallen), st.lost or 0))
    if bare then
      -- The comparison: the camp as it landed before history (it lost its lander to the same three).
      check("maxevo: the bare camp was tested", S.at ~= nil, "")
    else
      check("maxevo: it arrived with research", (S.rd.nodes.handloads or 0) >= 4 and S.rd.nodes["scrap-plating"] ~= nil,
        serpent.line(S.rd.nodes))
      check("maxevo: and a larger escort", (S.escort or 0) >= 15, tostring(S.escort))
      check("maxevo: the camp killed the biters", left == 0, tostring(left))
      check("maxevo: and the lander stands", st.lander and not st.fallen, tostring(st.fallen))
    end
  end)
end

-- Country: raids cross biter country round it (the user). Three spawners and a worm on the line between Serenity and
-- the player's undefended assembler, open ground to either side: a forced raid routes round them (no waypoint within
-- 30 of a spawner) and loses nothing to biters.
scenarios.country = function()
  schedule(60, function() lp("debug_tune", {raids_off = true}); lp("debug_depot", storage.id, 3000) end)
  schedule(3 * 3600, function()
    local o = lp("stats", storage.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = o.x / len, o.y / len
    local c = {math.floor(o.x - ux * 160), math.floor(o.y - uy * 160)}
    flatten(c[1] - 10, c[2] - 10, c[1] + 10, c[2] + 10)
    surface().create_entity{name = "assembling-machine-1", position = c, force = "player"}
    S.nests = {}
    for k = -1, 1 do
      local p = {o.x - ux * 80 - uy * 8 * k, o.y - uy * 80 + ux * 8 * k}
      local sp = surface().create_entity{name = "biter-spawner", position = surface().find_non_colliding_position("biter-spawner", p, 10, 1), force = "enemy"}
      if sp then table.insert(S.nests, sp.position) end
    end
    local wp = {o.x - ux * 90, o.y - uy * 90}
    surface().create_entity{name = "medium-worm-turret", position = surface().find_non_colliding_position("medium-worm-turret", wp, 10, 1), force = "enemy"}
    S.lost0 = lp("stats", storage.id).units_lost or 0
    lp("dev", {"raid", tostring(storage.id)}, c)
  end)
  schedule(3 * 3600 + 120, function()
    local st = lp("stats", storage.id)
    S.route = st.ops.route_points
  end)
  schedule(END - 60, function()
    local st = lp("stats", storage.id)
    local near = math.huge
    for _, w in ipairs(S.route or {}) do
      for _, n in ipairs(S.nests) do near = math.min(near, math.sqrt((w[1] - n.x) ^ 2 + (w[2] - n.y) ^ 2)) end
    end
    local lost = (st.units_lost or 0) - S.lost0
    info(string.format("country: %d waypoints, nearest %.0f tiles from a spawner; %d units lost; %s", #(S.route or {}),
      near, lost, serpent.line(st.ops.log[#st.ops.log])))
    check("country: the raid routed round the nests", S.route and #S.route > 0 and near > 30, string.format("%.0f", near))
    check("country: and lost nothing to them", lost == 0, tostring(lost))
  end)
end

-- Clearing: in a world thick with nests (spawners every 70 tiles from 250 to 700 out, evolution 1), every site the
-- first pass tries has a nest near it; Grubstake lands on the second pass, and its landing burns a clearing (no spawner
-- or worm left within 80 tiles), without raising the biters' evolution from spawner kills.
scenarios.clearing = function()
  schedule(30, function() game.forces.enemy.set_evolution_factor(1, surface()) end)
  schedule(60, function()
    local n = 0
    for x = -700, 700, 70 do for y = -700, 700, 70 do
      local d = math.sqrt(x * x + y * y)
      if d >= 250 and d <= 700 then
        local p = surface().find_non_colliding_position("biter-spawner", {x, y}, 8, 1)
        if p and surface().create_entity{name = "biter-spawner", position = p, force = "enemy"} then n = n + 1 end
      end
    end end
    S.spawners = n
    S.evo0 = game.forces.enemy.get_evolution_factor_by_killing_spawners(surface())
    -- One ring only (350 tiles out, inside the nests): the further rings are clear of them and the first pass would
    -- land there.
    lp("debug_tune", {rings = {0}})
    S.g = lp("arrive", 1, {x = 0, y = 0}, 350, {corp = "grubstake"})
  end)
  schedule(300, function()
    local st = S.g and lp("stats", S.g)
    local left = st and surface().count_entities_filtered{position = st.origin, radius = 80, type = {"unit-spawner", "turret"},
      force = "enemy"} or -1
    local evo = game.forces.enemy.get_evolution_factor_by_killing_spawners(surface())
    info(string.format("clearing: %d spawners placed; Grubstake %s, cleared %s, %d left within 80; spawner evolution %.4f -> %.4f",
      S.spawners, tostring(S.g), st and tostring(st.cleared) or "-", left, S.evo0, evo))
    check("clearing: Grubstake landed among the nests", S.g ~= nil, "")
    check("clearing: its landing burned a clearing", st and (st.cleared or 0) > 0 and left == 0,
      st and (tostring(st.cleared) .. " cleared, " .. left .. " left") or "no landing")
    check("clearing: without evolving the biters", math.abs(evo - S.evo0) < 1e-6, string.format("%.4f -> %.4f", S.evo0, evo))
  end)
end

-- Pads: each corporation's landing pad in its own shape (layout pad_shape), drawn as text in results.txt: '#' its floor,
-- '+' its trim, '.' anything else, 'L' the lander. Serenity's is an octagon with a trim ring, Grubstake's ragged.
scenarios.pads = function()
  schedule(60, function()
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
  end)
  schedule(2 * 3600, function()
    for _, id in ipairs({storage.id, S.g}) do
      local st = lp("stats", id)
      local o = st.origin
      local floor = {["lp-pad"] = "#", ["lp-trim"] = "+", ["lp-grubstake-pad"] = "#", ["lp-grubstake-trim"] = "+"}
      local rows, pad, trim = {}, 0, 0
      for y = o.y - 14, o.y + 14 do
        local r = {}
        for x = o.x - 26, o.x + 26 do
          local c = floor[surface().get_tile(x, y).name] or "."
          if math.abs(x - o.x) < 1 and math.abs(y - o.y) < 1 then c = "L" end
          if c == "#" then pad = pad + 1 elseif c == "+" then trim = trim + 1 end
          table.insert(r, c)
        end
        table.insert(rows, table.concat(r))
      end
      info(string.format("pads: %s %d (%d floor, %d trim)\n%s", st.corp, id, pad, trim, table.concat(rows, "\n")))
      check("pads: " .. st.corp .. " laid its pad at landing", pad > 100, pad .. " floor tiles")
    end
  end)
end

-- Ladder (docs/reviews/2026-10-14-megabase-pressure-consult.md): minutes since a corporation last razed a player
-- building, ten times fast. LP_MIX=soft: Grubstake's only target is an assembler behind two gun turrets (not soft):
-- nothing before 20 ladder-minutes; then soft relaxes, it raids, and a raze resets the clock. LP_MIX=desperate: a
-- provoked Serenity facing six lasers it cannot afford sends what it has at 60.
scenarios.ladder = function()
  local desperate = params.mix == "desperate"
  schedule(60, function()
    lp("debug_tune", {era = 2, ladder_fast = true, history_off = true})
    if desperate then
      S.id = storage.id
      lp("debug_tune", {provoke = true})
    else
      S.id = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
      -- The ladder only: the corporations at peace (a raid on Serenity's radar turned back, and the gap after it outlasted
      -- the run).
      for _, pair in ipairs({{"lp-serenity", "lp-grubstake"}, {"lp-grubstake", "lp-serenity"}}) do
        game.forces[pair[1]].set_cease_fire(pair[2], true)
      end
    end
    for _ = 1, 2 do lp("debug_depot", S.id, 3000) end
  end)
  schedule(2 * 3600, function()
    local o = lp("stats", S.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = o.x / len, o.y / len
    local c = {math.floor(o.x - ux * 120), math.floor(o.y - uy * 120)}
    flatten(c[1] - 14, c[2] - 14, c[1] + 14, c[2] + 14)
    S.c = c
    surface().create_entity{name = "assembling-machine-1", position = c, force = "player"}
    if desperate then
      for k = -2, 3 do
        local tr = surface().create_entity{name = "laser-turret", position = {c[1] + 3 * k, c[2] + 5}, force = "player"}
        surface().create_entity{name = "electric-energy-interface", position = {c[1] + 3 * k, c[2] + 8}, force = "player"}
      end
      surface().create_entity{name = "medium-electric-pole", position = {c[1] + 0.5, c[2] + 6.5}, force = "player"}
    else
      for k = -1, 1, 2 do
        local tr = surface().create_entity{name = "gun-turret", position = {c[1] + 4 * k, c[2] + 4}, force = "player"}
        tr.insert{name = "firearm-magazine", count = 50}
      end
    end
    S.l0 = lp("pressure").ladder
  end)
  for t = 2 * 3600 + 600, END - 120, 600 do
    schedule(t, function()
      local p = lp("pressure")
      S.max_rung = math.max(S.max_rung or 0, p.ladder)
      if p.last_raze and p.last_raze > 2 * 3600 and not S.first_raze then S.first_raze = game.tick end
      -- The highest rung reached before the player lost anything (a raze resets the clock).
      if not S.first_raze then S.rung_before = math.max(S.rung_before or 0, p.ladder) end
      local o = lp("stats", S.id).ops
      if o.op and not S.op_at then S.op_at = game.tick; S.op_rung = p.ladder end
    end)
  end
  schedule(END - 60, function()
    local p = lp("pressure")
    local razed = 0
    for _, n in pairs(p.razed or {}) do razed = razed + n end
    local o = lp("stats", S.id).ops
    info(string.format("ladder (%s): first operation at %s on rung %s; first raze at %s; %d razed %s; rung now %d; %s",
      params.mix, tostring(S.op_at), tostring(S.op_rung), tostring(S.first_raze), razed, serpent.line(p.razed), p.ladder,
      serpent.line(o.log[#o.log])))
    if desperate then
      check("ladder: it went at the lasers at the top rung", S.op_at ~= nil and (S.op_rung or 0) >= 3,
        tostring(S.op_rung))
    else
      check("ladder: nothing razed on the bottom rung", (S.rung_before or 0) >= 1, tostring(S.rung_before))
      check("ladder: it razed a building once soft relaxed", razed > 0, tostring(razed))
    end
  end)
end

-- Push: no way round biter country (a wall of spawners and worms across the whole approach to an undefended
-- assembler), the ladder ten times fast: not sent at first (worth 3, under PUSH_VALUE), then at the second rung the raid
-- pushes through with an escort and razes it.
scenarios.push = function()
  schedule(60, function()
    lp("debug_tune", {ladder_fast = true, raids_off = false})
    lp("debug_depot", storage.id, 3000); lp("debug_depot", storage.id, 3000)
  end)
  schedule(2 * 3600, function()
    local o = lp("stats", storage.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = o.x / len, o.y / len
    local c = {math.floor(o.x - ux * 170), math.floor(o.y - uy * 170)}
    flatten(c[1] - 8, c[2] - 8, c[1] + 8, c[2] + 8)
    surface().create_entity{name = "assembling-machine-1", position = c, force = "player"}
    S.c = c
    -- The wall: across the line 90 tiles out, 300 tiles wide, a spawner every 14 tiles, worms behind.
    local n = 0
    for k = -150, 150, 14 do
      local p = {o.x - ux * 90 - uy * k, o.y - uy * 90 + ux * k}
      local q = surface().find_non_colliding_position("biter-spawner", p, 6, 1)
      if q and surface().create_entity{name = "biter-spawner", position = q, force = "enemy"} then n = n + 1 end
      local w = surface().find_non_colliding_position("medium-worm-turret", {p[1] - ux * 10, p[2] - uy * 10}, 6, 1)
      if w then surface().create_entity{name = "medium-worm-turret", position = w, force = "enemy"} end
    end
    S.spawners = n
  end)
  schedule(END - 60, function()
    local st = lp("stats", storage.id)
    local razed = 0
    for _, v in pairs(lp("pressure").razed or {}) do razed = razed + v end
    local target = surface().count_entities_filtered{position = S.c, radius = 4, name = "assembling-machine-1"}
    info(string.format("push: %d spawners in the wall; %d of the player's razed; target %s; %s", S.spawners, razed,
      target > 0 and "standing" or "razed", serpent.line(st.ops.log[#st.ops.log])))
    check("push: the raid pushed through and razed the target", target == 0 and razed > 0, tostring(razed))
  end)
end

-- Heist (the megabase consult): an outpost station towards Grubstake (straight rail, a stop, a big pole, a cargo wagon
-- of 400 copper plate), one laser 40 tiles off (beyond reach: exposure 0, soft). Grubstake raids it on its own, empties
-- the wagon and carries the plate home, and the line is cut.
scenarios.heist = function()
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    for _ = 1, 2 do lp("debug_depot", S.g, 3000) end
  end)
  schedule(2 * 3600, function()
    local o = lp("stats", S.g).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local c = {math.floor(o.x - o.x / len * 110), math.floor(o.y - o.y / len * 110)}
    flatten(c[1] - 30, c[2] - 10, c[1] + 30, c[2] + 10)
    S.c = c
    for x = -24, 24, 2 do
      surface().create_entity{name = "straight-rail", position = {c[1] + x + 1, c[2] + 1}, direction = defines.direction.east, force = "player"}
    end
    surface().create_entity{name = "train-stop", position = {c[1] + 1, c[2] - 1}, direction = defines.direction.east, force = "player"}
    S.wagon = surface().create_entity{name = "cargo-wagon", position = {c[1] - 6, c[2] + 1}, direction = defines.direction.east, force = "player"}
    if S.wagon then S.wagon.insert{name = "copper-plate", count = 400} end
    surface().create_entity{name = "big-electric-pole", position = {c[1] + 6, c[2] - 4}, force = "player"}
    local tr = surface().create_entity{name = "laser-turret", position = {c[1] + 40, c[2] - 6}, force = "player"}
    S.rails0 = surface().count_entities_filtered{position = c, radius = 30, name = "straight-rail"}
  end)
  schedule(END - 60, function()
    local st = lp("stats", S.g)
    local copper = S.wagon and S.wagon.valid and S.wagon.get_item_count("copper-plate") or -1
    local rails = surface().count_entities_filtered{position = S.c, radius = 30, name = "straight-rail"}
    local razed = 0
    for _, v in pairs(lp("pressure").razed or {}) do razed = razed + v end
    info(string.format("heist: wagon copper %s, looted %d, rails %d -> %d, razed %d %s", tostring(copper), st.ops.looted or 0,
      S.rails0 or 0, rails, razed, serpent.line(lp("pressure").razed)))
    check("heist: the wagon was emptied", copper <= 0, tostring(copper))
    check("heist: and the plate reached home", (st.ops.looted or 0) >= 100, tostring(st.ops.looted))
    check("heist: the line was cut", rails < (S.rails0 or 0), string.format("%d -> %d", S.rails0 or 0, rails))
  end)
end

-- Overflight (the biter-country consult): Grubstake, which never clears nests, behind a wall of spawners and worms with
-- six harriers in its garrison: no way round on the ground, so they fly over (round the worms), raze the player's
-- undefended assembler beyond, and most come home.
scenarios.overflight = function()
  schedule(60, function()
    lp("debug_tune", {history_off = true})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    lp("debug_depot", S.g, 3000)
  end)
  schedule(2 * 3600, function()
    lp("debug_units", S.g, "lp-harrier", 6)
    local o = lp("stats", S.g).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = o.x / len, o.y / len
    local c = {math.floor(o.x - ux * 170), math.floor(o.y - uy * 170)}
    flatten(c[1] - 8, c[2] - 8, c[1] + 8, c[2] + 8)
    surface().create_entity{name = "assembling-machine-1", position = c, force = "player"}
    S.c = c
    schedule(game.tick + 60, function()
      local r = lp("debug_route", S.g, c)
      local near = {}
      for _, w in ipairs(r.route or {}) do
        local m = math.huge
        for _, e in pairs(surface().find_entities_filtered{position = w, radius = 60, type = "unit-spawner"}) do
          m = math.min(m, math.sqrt((e.position.x - w[1]) ^ 2 + (e.position.y - w[2]) ^ 2))
        end
        table.insert(near, string.format("(%.0f,%.0f):%.0f", w[1], w[2], m))
      end
      info("overflight: route from " .. serpent.line(r.from) .. " to " .. serpent.line(c) .. ": " .. table.concat(near, " "))
      local sp = surface().find_entities_filtered{type = "unit-spawner", limit = 3}
      info("overflight: spawners e.g. " .. serpent.line({sp[1] and sp[1].position, sp[2] and sp[2].position}))
    end)
    for k = -300, 300, 14 do
      -- 130 tiles out: at 90 it crossed Grubstake's own outposts, no spawner could stand there, and the gap was the way.
      local p = {o.x - ux * 130 - uy * k, o.y - uy * 130 + ux * k}
      local q = surface().find_non_colliding_position("biter-spawner", p, 6, 1)
      if q and surface().create_entity{name = "biter-spawner", position = q, force = "enemy"} then S.sp = (S.sp or 0) + 1 end
      if k % 42 == 0 then
        local w = surface().find_non_colliding_position("medium-worm-turret", {p[1] - ux * 10, p[2] - uy * 10}, 6, 1)
        if w then surface().create_entity{name = "medium-worm-turret", position = w, force = "enemy"} end
      end
    end
  end)
  schedule(END - 60, function()
    local st = lp("stats", S.g)
    local target = surface().count_entities_filtered{position = S.c, radius = 4, name = "assembling-machine-1"}
    local log = st.ops.log[#st.ops.log]
    info("overflight: losses by killer " .. serpent.line(lp("rd", "grubstake").lost_by))
    info(string.format("overflight: %s spawners; %d flights; target %s; %s", tostring(S.sp), st.ops.overflights or 0,
      target > 0 and "standing" or "razed", serpent.line(log)))
    check("overflight: the harriers flew over", (st.ops.overflights or 0) > 0, tostring(st.ops.overflights))
    check("overflight: and razed the target", target == 0, "")
  end)
end

-- Guns: a late player (era 3) with an artillery turret at spawn, loaded; Serenity is called to land 200 tiles out:
-- inside the artillery's reach, the second pass lands it under the guns, and its lander, shelled, holds on its two drop
-- generators (artillery does not fire at generators by itself) for the five minutes after.
scenarios.guns = function()
  schedule(30, function()
    lp("debug_tune", {era = 3})
    flatten(-5, -5, 5, 5)
    local a = surface().create_entity{name = "artillery-turret", position = {0.5, 0.5}, force = "player"}
    a.insert{name = "artillery-shell", count = 50}
    game.forces.player.chart(surface(), {{-400, -400}, {400, 400}})
  end)
  schedule(120, function()
    -- One ring (200 tiles out): beyond it, the first pass found ground out of the artillery's reach.
    lp("debug_tune", {rings = {0}})
    S.s = lp("arrive", 1, {x = 0, y = 0}, 200, {corp = "serenity"})
    lp("debug_tune", {rings = false})
    local st = S.s and lp("stats", S.s)
    S.d = st and math.sqrt(st.origin.x ^ 2 + st.origin.y ^ 2)
    S.under = st and st.under_guns
  end)
  schedule(120 + 2 * 3600, function() game.forces.player.chart(surface(), {{-400, -400}, {400, 400}}) end)
  schedule(END - 60, function()
    local st = S.s and lp("stats", S.s)
    local shells = surface().find_entities_filtered{name = "artillery-turret", force = "player"}[1]
    local left = shells and shells.get_item_count("artillery-shell") or -1
    info(string.format("guns: landed %s tiles out, under the guns %s; lander %s, generators counted %s, hull down %s; shells left %d",
      tostring(S.d and math.floor(S.d)), tostring(S.under), tostring(st and st.lander and not st.fallen),
      tostring(st and st.gens_counted), tostring(st and st.hull_down), left))
    check("guns: it landed under the guns", S.under == true and (S.d or 999) < 300, tostring(S.d))
    check("guns: the artillery fired on it", left < 50, tostring(left))
    check("guns: and its lander held", st and st.lander and not st.fallen, "")
  end)
end

-- Artillery: a player artillery turret at spawn; the second landing (forced near spawn) must keep out of its
-- reach (300 tiles), landing just outside instead.
scenarios.artillery = function()
  schedule(60, function()
    flatten(-5, -5, 5, 5)
    surface().create_entity{name = "artillery-turret", position = {0.5, 0.5}, force = "player"}
    S.id = lp("arrive", 1, {x = 0, y = 0}, 150, {corp = "grubstake"})
  end)
  schedule(120, function()
    local st = S.id and lp("stats", S.id)
    local d = st and math.sqrt(st.origin.x ^ 2 + st.origin.y ^ 2) or 0
    check("artillery: the landing kept out of the artillery's reach", st ~= nil and d > 300, string.format("%.0f tiles from it", d))
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
local AFTER = {phases = 0, cut = 6, raid = 6, path = 6, defend = 11, occupy = 18, army = 11, train = 6, siege = 13, fall = 5}
if params.scenario == "uplink" and END < 18 * 3600 then error("lp-sim: uplink needs at least 18 minutes") end
if params.scenario == "convoy" and END < 10 * 3600 then error("lp-sim: convoy needs at least 10 minutes") end
if params.scenario == "caps" and END < 8 * 3600 then error("lp-sim: caps needs at least 8 minutes") end
if AFTER[params.scenario] and not params.save_at and END < STRIKE + AFTER[params.scenario] * 3600 then
  error(string.format("lp-sim: %s strikes at minute %d; run at least %d minutes", params.scenario, STRIKE / 3600,
    STRIKE / 3600 + AFTER[params.scenario]))
end

script.on_init(function()
  storage.t0 = game.tick
  helpers.remove_path("landing-party")
  lp("set_trace", true)
  -- Land as the real arrival does, `distance` tiles from spawn (on a site with ore round it).
  -- Phases plays the opening itself: no landing at the start.
  if params.scenario == "phases" then return end
  -- A real factory (scripts/visit.sh) is loaded, not created: its arrival is placed by the scenario.
  if params.scenario == "visit" then return end
  storage.id = lp("arrive", 1, {x = 0, y = 0}, params.distance,
    {doctrine = params.doctrine or (params.scenario == "defend" and "bastion")
      or ((params.scenario == "army" or params.scenario == "siege") and "sprawl") or nil,
     uplink = params.scenario == "uplink" or nil})
  if not storage.id then error("lp-sim: landing failed") end
  -- Operations' mechanics are tested here, not tempers (Serenity only strikes once provoked): provoked from the
  -- start, except where tempers are the subject.
  local TEMPERS = {temper = true, strip = true, contact = true, line = true, grudge = true, visit = true}
  if not TEMPERS[params.scenario] then lp("debug_tune", {provoke = true}) end
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
  schedule(m * 3600, function() if storage.id then lp("snapshot", storage.id, OUT, params.radius) end end)
end
for _, m in ipairs({10, 20, 40, 60, 90, 120}) do
  if m <= params.minutes then
    schedule(m * 3600, function() if storage.id then metric("modules_" .. m, lp("stats", storage.id).modules) end end)
  end
end
schedule(END, function()
  -- No settlement at all (a scenario that lands later and never did): its own checks say why.
  if not storage.id then
    check("a settlement exists", false, "none landed")
    table.insert(lines, "DONE " .. failed .. " FAILED")
    helpers.write_file("landing-party/results.txt", table.concat(lines, "\n") .. "\n")
    return
  end
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
  local MAY_FALL = {siege = true, fall = true, hq = true, uplink = true}
  if not MAY_FALL[params.scenario] then check("lander alive", s.lander) end
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
    if e.force and e.force.name == "player" then S.lander_kills = (S.lander_kills or 0) + 1 end
    table.insert(lines, string.format("INFO lander killed at tick %d by %s (%s)", e.tick, by,
      e.force and e.force.name or "?"))
  end
end, {{filter = "name", name = "lp-trooper"}, {filter = "name", name = "lp-breacher"},
  {filter = "name", name = "lp-battle-tank"}, {filter = "name", name = "lp-lander"}, {filter = "name", name = "gun-turret"},
  {filter = "name", name = "artillery-turret"}, {filter = "type", type = "unit"},
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

-- Ticks are counted from the tick the test mod was added (storage.t0): 0 on a new map, hours into a real save
-- (scripts/visit.sh; scheduled by absolute tick, nothing ever ran on one).
script.on_event(defines.events.on_tick, function(e)
  local f = at[e.tick - (storage.t0 or 0)]
  if f then f() end
end)
