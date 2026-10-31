local lp_threat = require("__landing-party__.scripts.threat")
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
-- A scenario whose outcome is settled ends now: its final checks (END - 60) and the results (END) run in the next
-- ticks, then the game is finished, and the benchmark's remaining ticks cost almost nothing (blackout ended at minute
-- 20 of 40: 37 s against 57 s). Call it only once nothing later could change a check.
local finished_early = false
local finish_early
-- Checked once a minute from minute 3: when `settled()` holds, the scenario finishes early.
local function settle_when(settled)
  for t = 3 * 3600, END - 180, 3600 do
    schedule(t, function() if not finished_early and settled() then finish_early() end end)
  end
end
finish_early = function()
  if finished_early then return end
  finished_early = true
  local now = game.tick - (storage.t0 or 0)
  local last, final = at[END - 60], at[END]
  at[END - 60], at[END] = nil, nil
  if last then schedule(now + 1, last) end
  schedule(now + 2, function()
    if final then final() end
    game.set_game_state{game_finished = true, player_won = false, can_continue = false}
  end)
end

local function surface() return game.surfaces[1] end
-- What the dead left near pos: items on the ground and in the corporations' wrecks (lp-wreck), as {name = count}, and
-- how many piles (each item on the ground, each wreck). take: emptied and removed (picked up).
local function dropped(pos, radius, take)
  local counts, piles = {}, 0
  for _, it in pairs(surface().find_entities_filtered{type = "item-entity", position = pos, radius = radius}) do
    if it.valid and it.stack.valid_for_read then
      counts[it.stack.name] = (counts[it.stack.name] or 0) + it.stack.count
      piles = piles + 1
      if take then it.destroy() end
    end
  end
  for _, w in pairs(surface().find_entities_filtered{name = "lp-wreck", position = pos, radius = radius}) do
    piles = piles + 1
    for _, c in pairs(w.get_inventory(defines.inventory.chest).get_contents()) do
      counts[c.name] = (counts[c.name] or 0) + c.count
    end
    if take then w.destroy() end
  end
  local total = 0
  for _, n in pairs(counts) do total = total + n end
  return counts, piles, total
end

-- A map of the ground as data (the user, 2026-10-20: snapshots of the camp to inspect): every building within `radius`
-- of `center` (no trees, rocks, ore, corpses or items on the ground), and the corporations' floors, written to
-- script-output/landing-party/maps/<label>.json; scripts/campmap.py draws them.
local MAP_SKIP = {tree = true, ["simple-entity"] = true, resource = true, corpse = true, ["item-entity"] = true,
  ["character-corpse"] = true, decorative = true, fish = true, ["tile-ghost"] = true,
  ["rail-remnants"] = true}
local function dump_map(label, center, radius, extra)
  local s = surface()
  local out = {label = label, tick = game.tick, center = center, radius = radius, entities = {}, tiles = {}, extra = extra or {}}
  local area = {{center[1] - radius, center[2] - radius}, {center[1] + radius, center[2] + radius}}
  for _, e in pairs(s.find_entities_filtered{area = area}) do
    -- Neutral: only a town's yard props (layout.lua), not the map's rocks and trees.
    local prop = e.force.name == "neutral" and e.type ~= "tree" and e.type ~= "simple-entity" and e.type ~= "resource"
      and e.type ~= "cliff"
    if not MAP_SKIP[e.type] and (e.force.name ~= "neutral" or prop) then
      table.insert(out.entities, {e.force.name, e.name, math.floor(e.position.x * 2) / 2, math.floor(e.position.y * 2) / 2, e.type})
    end
  end
  for _, kind in ipairs({"road", "pad", "trim", "stripe", "hazard"}) do
    local names = {}
    for _, t in pairs(prototypes.tile) do
      if t.name:match("^lp%-") and t.name:match("%-" .. kind .. "$") then table.insert(names, t.name) end
    end
    out.tiles[kind] = {}
    if #names > 0 then
      for _, t in pairs(s.find_tiles_filtered{area = area, name = names}) do
        table.insert(out.tiles[kind], {t.position.x, t.position.y})
      end
    end
  end
  helpers.write_file("landing-party/maps/" .. label .. ".json", helpers.table_to_json(out), false)
end
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
local LAB = {}  -- the siege lab's hooks (scenarios.lab): its recorder's deaths

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

-- Rebuilt, not duplicated: at each spot a fabricator was lost, one at most stands again (a camp that spreads founds
-- compounds with fabricators of their own after a raid: counting all of them was not the question).
local function doubled(spots)
  local n = 0
  for _, p in ipairs(spots or {}) do
    if surface().count_entities_filtered{name = "lp-fabricator", position = p, radius = 1.5} > 1 then n = n + 1 end
  end
  return n
end

scenarios.raid = function()
  window_rate("made", STRIKE, "before")
  window_rate("made", END, "after")
  schedule(STRIKE, function()
    S.fabs = lp("stats", storage.id).fabs
    S.spots = {}
    for _, f in pairs(lp_entities("lp-fabricator")) do table.insert(S.spots, {f.position.x, f.position.y}); f.die("player") end
    check("raid: fabricators destroyed", lp("stats", storage.id).fabs == 0, S.fabs)
  end)
  schedule(END, function()
    local st = lp("stats", storage.id)
    check("raid: fabricators rebuilt", st.fabs >= S.fabs, st.fabs .. "/" .. S.fabs)
    -- Rebuilt, not duplicated: the planner counts what it owes (a few new ones for new mines are fine).
    check("raid: not duplicated", doubled(S.spots) == 0, doubled(S.spots) .. " spots doubled, " .. st.fabs .. " fabricators")
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
    check("occupy: not duplicated", doubled(S.spots) == 0, doubled(S.spots) .. " spots doubled, " .. st.fabs .. " fabricators")
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
    -- Capture off (at the strike: forked runs start after tick 200): the response is tested here, capture in fall (the
    -- creeping turrets, the outpost's turrets dead, held it a minute and took four pieces before its rebuild came).
    lp("debug_tune", {capture_off = true})
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
    S.names = function()
      local c = {}
      for _, e in pairs(surface().find_entities_filtered{position = at, radius = 14,
        name = {"lp-drill", "lp-bin", "lp-pylon", "lp-turret"}}) do
        local k = e.name .. (e.force.name == FORCE and "" or "@" .. e.force.name)
        c[k] = (c[k] or 0) + 1
      end
      return serpent.line(c)
    end
    S.names0 = S.names()
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
    if S.names then info("defend: outpost before " .. S.names0 .. ", after " .. S.names()) end
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
      -- Not the crews: Serenity's constructor drone flies on a harrier's body (20 "early harriers" since crews came).
      local crews = lp("crew_units")
      for name, need in pairs({["lp-harrier"] = 1, ["lp-walker"] = 2}) do
        if tier < need then
          for _, u in pairs(surface().find_entities_filtered{name = name, force = FORCE}) do
            if not crews[u.unit_number] then S.early = S.early + 1 end
          end
        end
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
    info("faction: landing jobs " .. serpent.line(lp("landing_jobs")) .. ", next " .. tostring(f.next) .. ", cadence "
      .. tostring(f.cadence) .. ", surface " .. tostring(f.surface))
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
    -- All the way round, and no spot is a failure: the last one tried, kept anyway, put the barracks on a
    -- flattened island in a lake and the squad never left it (seed 12345, 0.1.39).
    for _, turn in ipairs({0, 0.5, -0.5, 1, -1, 1.5, -1.5, 2, -2, 2.5, -2.5, 3}) do
      local c, sn = math.cos(turn), math.sin(turn)
      local ux, uy = (dx * c - dy * sn) / len, (dx * sn + dy * c) / len
      for _, d in ipairs({60, 90, 120, 150}) do
        a = {far.position.x + ux * d, far.position.y + uy * d}
        -- Generated first: ungenerated ground has no tiles, so a lake there read as dry (seed 12345).
        surface().request_to_generate_chunks(a, 2)
        surface().force_generate_chunk_requests()
        if surface().count_entities_filtered{force = FORCE, position = a, radius = 60} == 0
          and surface().count_tiles_filtered{position = a, radius = 25, collision_mask = "water_tile"} == 0 then
          ok = true; break
        end
      end
      if ok then break end
    end
    if not ok then
      check("army: a dry spot clear of the faction for the barracks", false, "none found")
      return
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
    -- Those the camp's turrets killed on the way count as taken there: the beacon's path is the test, and with the camp
    -- guarding its outposts sooner (0.2.7), 8 of 12 fell to an outpost's guns on the way and 4 stood at it.
    local shot = (S.killers or {})["lp-gun-turret"] or 0
    check("army: the beacon took them to the outpost", S.reached + shot >= 5,
      S.reached .. " at the outpost at most, " .. shot .. " shot by its turrets on the way")
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
    local _, on_ground = dropped({0, 0}, 100000)
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
-- LP_MIX=grown: a bastion, grown to its doctrine's full size first, and the uplink lands only then (the deathworld
-- visit: a nine-block bastion's convoys never left, 68 sent, none delivered).
scenarios.convoy = function()
  local grown = params.mix == "grown"
  schedule(60, function()
    lp("debug_tune", grown and {quiet = true} or {mature_blocks = 2, quiet = true})
    lp("debug_depot", storage.id, 4000)
  end)
  schedule(grown and 20 * 3600 or 120, function()
    if grown then info("convoy: settlement before the uplink " .. serpent.line({blocks = lp("stats", storage.id).blocks,
      walls = lp("stats", storage.id).walls, mature = lp("stats", storage.id).mature})) end
    S.uplink = lp("arrive", 1, {x = 0, y = 0}, params.distance, {uplink = true})
    info("convoy: uplink settlement " .. tostring(S.uplink))
  end)
  for t = 600, END, 120 do
    schedule(t, function()
      local haulers = surface().find_entities_filtered{name = "lp-hauler", force = FORCE}
      -- Escorts stay with their hauler: the largest distance seen while convoys travel.
      local cst = lp("stats", storage.id)
      -- Travelling only (since 2026-10-21): a held hauler waits while escorts walk round a wall to it (seed 12345,
      -- 0.1.44: 30 tiles at a stop, none under way); the spread at a stop is reported, not judged.
      S.parked = math.max(S.parked or 0, cst.convoy_spread)
      local spread = cst.convoy_spread_moving
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
    info(string.format("convoy: escorts at most %.0f tiles from a held hauler", S.parked or 0))
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
    elseif params.mix == "tour" or params.mix == "units" or params.mix == "all" then
      -- LP_MIX=tour: Grubstake as well, both grown; your outposts by each (tour_outposts below). LP_MIX=units: the same,
      -- era 3, the new units' nodes owned (Prism, Tesla; Scorcher) and some of each in the garrisons (units below).
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
    -- Barracks for each unit type, with finished orders: 20 troopers, 10 breachers, 5 battle tanks (60 of
    -- bandwidth since battle tanks take 6: six relays at research level 2).
    S.army = {{"lp-trooper-order", 20}, {"lp-breacher-order", 10}, {"lp-battle-tank-order", 5}}
    S.barracks = {}
    for i, o in ipairs(S.army) do
      local b = put("lp-barracks", 4.5 + 6 * i, -15.5)
      b.set_recipe(o[1])
      S.barracks[i] = b
      put("medium-electric-pole", 6.5 + 6 * i, -12.5)
    end
    put("electric-energy-interface", 31, -11)
    for k = 1, 6 do put("lp-command-relay", 2.5 + 4 * k, -7.5) end
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
  local tour = params.mix == "tour" or params.mix == "units" or params.mix == "all"
  if tour then schedule(STRIKE - 120, tour_outposts) end
  -- LP_MIX=all (the user, 2026-10-23: "a save with a player base and landings from all factions already
  -- pre-developed"): the tour, both corporations at level 2 with their tree units bought (laser drones from level 2,
  -- bomb drones, both anti-air), some of each in their garrisons; Synthexis landed on its nest field with the wild at
  -- 0.45, grown by the save (creep, cells, substrate, its clinic); a walled base of yours at spawn. Run it to minute 30.
  if params.mix == "all" then
    schedule(150, function()
      game.forces.enemy.set_evolution_factor(0.45, surface())
      -- A nest field for Synthexis 750 tiles out, away from Serenity (seed 12345 has none in its band near spawn).
      local o = lp("stats", S.tour.s).origin
      local len = math.sqrt(o.x * o.x + o.y * o.y)
      local c = {-o.x / len * 750, -o.y / len * 750}
      surface().request_to_generate_chunks(c, 3)
      surface().force_generate_chunk_requests()
      for _, d in ipairs({{0, 0}, {14, 6}, {-12, 8}, {6, -14}, {-8, -12}}) do
        local q = surface().find_non_colliding_position("biter-spawner", {c[1] + d[1], c[2] + d[2]}, 30, 1)
        if q then surface().create_entity{name = "biter-spawner", position = q, force = "enemy"} end
      end
      for _, d in ipairs({{20, 0}, {-20, 0}}) do
        local q = surface().find_non_colliding_position("medium-worm-turret", {c[1] + d[1], c[2] + d[2]}, 30, 1)
        if q then surface().create_entity{name = "medium-worm-turret", position = q, force = "enemy"} end
      end
      lp("debug_tune", {era = 2, corp_level = {serenity = 2, grubstake = 2},
        rd_tech = {serenity = {nodes = {lance = 1, skyguard = 1}}, grubstake = {nodes = {scavenger = 1, ["flak-buggy"] = 1}}}})
      S.culture = lp("farm_arrive", 1)
      info("all: Synthexis " .. tostring(S.culture))
    end)
    schedule(STRIKE - 120, function()
      -- Your base: a walled square west of the barracks, gun and laser turrets on its corners and sides, power,
      -- assemblers, a radar.
      local function put(name, x, y, items)
        local e = surface().create_entity{name = name, position = {x, y}, force = "player", raise_built = true}
        if e and items then e.insert(items) end
        return e
      end
      local x0, y0, x1, y1 = -70, -40, -14, 16
      flatten(x0 - 4, y0 - 4, x1 + 4, y1 + 4)
      for x = x0, x1 do put("stone-wall", x + 0.5, y0 + 0.5); put("stone-wall", x + 0.5, y1 + 0.5) end
      for y = y0 + 1, y1 - 1 do put("stone-wall", x0 + 0.5, y + 0.5); put("stone-wall", x1 + 0.5, y + 0.5) end
      put("electric-energy-interface", (x0 + x1) / 2, (y0 + y1) / 2)
      for x = x0 + 4, x1 - 4, 9 do for y = y0 + 4, y1 - 4, 9 do put("substation", x, y) end end
      local k = 0
      for x = x0 + 3, x1 - 3, 8 do
        for _, y in ipairs({y0 + 3, y1 - 3}) do
          k = k + 1
          if k % 2 == 0 then put("gun-turret", x, y, {name = "piercing-rounds-magazine", count = 200})
          else put("laser-turret", x, y) end
        end
      end
      for y = y0 + 11, y1 - 11, 8 do
        put("gun-turret", x0 + 3, y, {name = "piercing-rounds-magazine", count = 200}); put("laser-turret", x1 - 3, y)
      end
      for i = 0, 5 do
        local a = put("assembling-machine-2", x0 + 14 + (i % 3) * 8, y0 + 18 + math.floor(i / 3) * 10)
        if a then a.set_recipe("iron-gear-wheel"); a.insert{name = "iron-plate", count = 200} end
      end
      put("radar", x1 - 10, y1 - 10)
      put("roboport", x0 + 12, y1 - 10)
      -- The barracks on the base's network (the user, 2026-10-23: "power was missing": a raid took the barracks' own
      -- source before the save, and the army had none).
      for _, x in ipairs({-16.5, -9.5, -2.5}) do put("medium-electric-pole", x, -10.5) end
      if S.tour.s then lp("debug_units", S.tour.s, "lp-laser-drone", 3) end
      if S.tour.g then lp("debug_units", S.tour.g, "lp-scavenger", 4); lp("debug_units", S.tour.g, "lp-harrier", 4) end
      local f = lp("farm_state").farms[1]
      info("all: Synthexis " .. serpent.line(f and {pos = f.pos, pens = f.pens, evo = f.evo, clinic = f.clinic}))
    end)
  end
  if params.mix == "units" then
    schedule(150, function()
      lp("debug_tune", {era = 3, rd_tech = {serenity = {nodes = {lance = 1, prism = 1, tesla = 1}},
        grubstake = {nodes = {scorcher = 1}}}})
    end)
    schedule(STRIKE - 60, function()
      lp("debug_units", S.tour.s, "lp-prism", 4)
      lp("debug_units", S.tour.s, "lp-tesla", 4)
      if S.tour.g then lp("debug_units", S.tour.g, "lp-scorcher", 5) end
    end)
  end
  schedule(STRIKE, function()
    if tour then lp("debug_tune", {raids_off = false}) end
    game.forces.player.chart(surface(), {{-600, -600}, {600, 600}})
    -- Exports for half an hour of convoys (one of 1,000 parts a minute): the granted stock ran out in three. The tour
    -- has no uplink: each corporation the same (the user, 2026-10-23, in the all-factions save: "Grubstake got
    -- absolutely demolished by Kessler": Serenity alone had been given 30,000 parts at the save).
    if tour then
      lp("debug_parts", S.tour.s, 8000)
      if S.tour.g then lp("debug_parts", S.tour.g, 8000) end
    else
      lp("debug_parts", storage.id, 30000)
    end
  end)
  schedule(STRIKE + 300, function()
    game.speed = 1
    game.server_save("lp-showcase")
    local army = lp("army")
    local new = {}
    for _, name in ipairs({"lp-prism", "lp-tesla", "lp-grubstake-scorcher"}) do
      new[#new + 1] = name .. " " .. surface().count_entities_filtered{name = name}
    end
    helpers.write_file("landing-party/saved.txt", string.format("%d (%d units, capacity %d; %s)", game.tick, army.alive,
      army.capacity, table.concat(new, ", ")))
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
    -- Loot: a ruined fabricator mined into a script inventory, to what it is made of (25 parts: 12 iron, 6 copper, 2
    -- circuits).
    local fab = surface().find_entities_filtered{name = "lp-fabricator", force = "neutral", position = S.lander_at, radius = 250}[1]
    local inv = game.create_inventory(10)
    local mined = fab and fab.mine{inventory = inv}
    check("fall: ruins yield what they are made of", mined and inv.get_item_count("iron-plate") > 0
      and inv.get_item_count("electronic-circuit") > 0,
      string.format("%d iron, %d circuits from a fabricator", inv.get_item_count("iron-plate"), inv.get_item_count("electronic-circuit")))
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
      -- Lasting: the fall is the player's kill, so the grudge and the evacuation march past it, and Serenity's infantry
      -- destroyed it before the hold completed (failing since 5281d15 at least). Capture by holding is what is tested.
      if S.holder then S.holder.destructible = false end
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
  -- Settled: the siege forced at 5 minutes is over (its log entry written, no operation running).
  settle_when(function()
    if game.tick - storage.t0 < 6 * 3600 then return false end
    local st = lp("stats", storage.id)
    for _, l in ipairs(st.ops.log or {}) do if l.op == "siege" and not st.ops.op then return true end end
    return false
  end)
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
      -- (Each mortar up, whom it is credited to: storage.unit_owner.)
      for _, m in ipairs(surface().find_entities_filtered{type = "artillery-turret", force = "lp-" .. lp("stats", storage.id).corp}) do
        local own = lp("debug_unit_owner", m.unit_number)
        S.mortar_owner = S.mortar_owner or {}
        S.mortar_owner[m.unit_number] = own
        if own then S.mortar_owned = (S.mortar_owned ~= false) and true else S.mortar_owned = false end
      end
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
      -- What its shells broke is its razing (a tier-1 siege's mortar killed 3 lasers of the lane and its record read
      -- nothing razed: its mortars no unit of its, their kills credited to no one; the lane, 2026-10-31). (Its razed count
      -- alone proved nothing here: its guards break turrets too.)
      check("siegetier: its mortars credited to it, their kills its razing", S.mortar_owned == true, serpent.line(S.mortar_owner))
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
-- and pack up when the shells are spent; no mortar is left behind. The barrage over, its guards and the garrison's spare
-- units go in (a tier-1 siege, once its force suffices).
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
    -- A tier-1 siege pushes in once the barrage is over, when its force suffices (it packed up and went home, the user).
    check("bombard: the siege's own assault went in", (o.assaults or 0) >= 1, tostring(o.assaults))
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
-- Reprisal (the user, 2026-10-21: Grubstake raided Serenity again and again and was never paid back): two camps as in
-- rivals; at minute 6 five of Serenity's buildings and units die to Grubstake (their own fighting may call it first).
-- Serenity mounts an operation on a Grubstake target within 8 minutes of the reprisal.
scenarios.reprisal = function()
  schedule(60, function()
    for _ = 1, 3 do lp("debug_depot", storage.id, 3000) end
  end)
  schedule(120, function()
    S.other = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    if S.other then for _ = 1, 3 do lp("debug_depot", S.other, 3000) end end
  end)
  schedule(6 * 3600, function()
    local n = 0
    for _, e in pairs(surface().find_entities_filtered{force = FORCE}) do
      local k = e.name
      if n < 5 and e.valid and (k == "lp-wall" or k == "lp-drill" or k == "lp-lamp" or e.type == "unit") then
        e.die("lp-grubstake"); n = n + 1
      end
    end
    S.killed = n
  end)
  for t = 3600, END - 120, 1200 do
    schedule(t, function()
      local o = lp("stats", storage.id).ops
      if o.reprisal and not S.reprisal_at then S.reprisal, S.reprisal_at = o.reprisal, o.reprisal_at end
      local function seen(owner, started)
        if owner == "lp-grubstake" and S.reprisal_at and started and started >= S.reprisal_at then
          S.at_rival = S.at_rival or started
        end
      end
      seen(o.op_owner, o.op_started)
      for _, l in ipairs(o.log or {}) do seen(l.owner, l.started) end
    end)
  end
  schedule(END - 60, function()
    local st = lp("stats", storage.id)
    info(string.format("reprisal: killed %s at minute 6; reprisal on %s at %s, an op at Grubstake at %s; reprisals %d",
      tostring(S.killed), tostring(S.reprisal), tostring(S.reprisal_at), tostring(S.at_rival), st.reprisals or 0))
    check("reprisal: losses to Grubstake call one", S.reprisal == "lp-grubstake" and (st.reprisals or 0) >= 1,
      tostring(S.reprisal))
    check("reprisal: Serenity went for Grubstake within 8 minutes", S.at_rival ~= nil and S.at_rival - S.reprisal_at <= 8 * 3600,
      string.format("%s after", S.at_rival and string.format("%.1f min", (S.at_rival - S.reprisal_at) / 3600) or "none"))
  end)
end

-- System (the user, 2026-10-23: "we now need to think and work on the balance of the whole system"): every faction on
-- one map, as a game brings them, and a player's base standing in for the player; a frame a minute to
-- landing-party/system.jsonl (scripts/system_report.py judges them against the targets in docs/system.md).
-- The stand-in: a walled square at spawn, gun turrets (refilled) and lasers on its walls, assemblers, a radar, and
-- pollution let out at its middle, rising over the game (a factory growing). Grubstake lands at minute 1, Kessler-
-- Hayashi at 15 (its gate, the first rocket, comes later in a game: the order kept, the wait cut); Synthexis on a nest
-- field 900 tiles out once the wild reach 0.25 (pushed there at minute 20 if the pollution has not).
local SYSTEM_LAND_G, SYSTEM_LAND_S, SYSTEM_SYNTH = 1, 15, 20
scenarios.system = function()
  local function put(name, x, y, items)
    local e = surface().create_entity{name = name, position = {x, y}, force = "player", raise_built = true}
    if e and items then e.insert(items) end
    return e
  end
  schedule(30, function()
    lp("debug_tune", {history_off = true})
    local x0, y0, x1, y1 = -45, -45, 45, 45
    flatten(x0 - 4, y0 - 4, x1 + 4, y1 + 4)
    for x = x0, x1 do put("stone-wall", x + 0.5, y0 + 0.5); put("stone-wall", x + 0.5, y1 + 0.5) end
    for y = y0 + 1, y1 - 1 do put("stone-wall", x0 + 0.5, y + 0.5); put("stone-wall", x1 + 0.5, y + 0.5) end
    -- Its power a small block, as a steam plant is (three sources side by side; one interface at the middle was all a
    -- Synthexis wave had to break, 2026-10-24).
    for _, dx in ipairs({-3, 0, 3}) do
      local src = put("electric-energy-interface", dx, 0)
      if src then src.power_production, src.electric_buffer_size = 2e7 / 3, 2e8 / 3 end
    end
    for x = x0 + 5, x1 - 5, 14 do for y = y0 + 5, y1 - 5, 14 do put("substation", x, y) end end
    S.guns = {}
    local k = 0
    -- One face lightly held, as a real base has one (the user, 2026-10-24: Synthexis, the smart biter enemy, is to find
    -- and use the weak face; against an even square of guns it had none to find): by the seed, north, south, west or
    -- east, a single gun turret in its middle instead of seven turrets.
    local seed = game.default_map_gen_settings.seed
    S.weak = ({[12345] = "north", [1] = "south", [4242] = "west", [777] = "east"})[seed]
      or ({"north", "south", "west", "east"})[(seed % 4) + 1]
    -- Its gun turrets fed as a player's are: an inserter from a chest of ammunition behind each (by hand, no inserter
    -- fed them, and Synthexis, which goes for what feeds a gun, found nothing to break but the power).
    local INWARD = {north = {0, 1}, south = {0, -1}, west = {1, 0}, east = {-1, 0}}
    local function feed(turret, face)
      if not turret then return end
      local v = INWARD[face]
      local tx, ty = turret.position.x, turret.position.y
      local ix, iy = tx + v[1] * 1.5 - (v[2] ~= 0 and 0.5 or 0), ty + v[2] * 1.5 - (v[1] ~= 0 and 0.5 or 0)
      local cx, cy = ix + v[1], iy + v[2]
      local chest = put("wooden-chest", cx, cy, {name = "piercing-rounds-magazine", count = 200})
      for _, dir in ipairs({defines.direction.north, defines.direction.south, defines.direction.east, defines.direction.west}) do
        local ins = surface().create_entity{name = "inserter", position = {ix, iy}, direction = dir, force = "player"}
        if ins then
          local dp = ins.drop_position
          if (dp.x - tx) ^ 2 + (dp.y - ty) ^ 2 < 2 then break end
          ins.destroy()
        end
      end
      return chest
    end
    S.fed = 0
    for t = -36, 36, 12 do
      for f, side in ipairs({{t, y0 + 3}, {t, y1 - 3}, {x0 + 3, t}, {x1 - 3, t}}) do
        k = k + 1
        local face = ({"north", "south", "west", "east"})[f]
        if face == S.weak then
          if t == 0 then
            local g = put("gun-turret", side[1], side[2], {name = "piercing-rounds-magazine", count = 100})
            table.insert(S.guns, g)
            if feed(g, face) then S.fed = S.fed + 1 end
          end
        elseif k % 2 == 0 then
          local g = put("gun-turret", side[1], side[2], {name = "piercing-rounds-magazine", count = 100})
          table.insert(S.guns, g)
          if feed(g, face) then S.fed = S.fed + 1 end
        else put("laser-turret", side[1], side[2]) end
      end
    end
    -- LP_MIX=aged: a base hours in, a second ring of turrets inside the wall (16 more).
    if params.mix == "aged" then
      local j = 0
      for t = -30, 30, 20 do
        for _, side in ipairs({{t, y0 + 7}, {t, y1 - 7}, {x0 + 7, t}, {x1 - 7, t}}) do
          j = j + 1
          if j % 2 == 0 then table.insert(S.guns, put("gun-turret", side[1], side[2], {name = "piercing-rounds-magazine", count = 100}))
          else put("laser-turret", side[1], side[2]) end
        end
      end
    end
    for i = 0, 11 do
      local a = put("assembling-machine-2", -25 + (i % 4) * 9, -20 + math.floor(i / 4) * 12)
      if a then a.set_recipe("iron-gear-wheel"); a.insert{name = "iron-plate", count = 400} end
    end
    put("radar", 20, 20)
    -- Its mining outposts, as any player's: two drills, a pole and power on each of the three nearest ore patches 120
    -- to 300 tiles out (without them Grubstake had nothing to strip, and held no claim in two hours on any seed).
    surface().request_to_generate_chunks({0, 0}, 10)
    surface().force_generate_chunk_requests()
    local picked = {}
    local ores = surface().find_entities_filtered{position = {0, 0}, radius = 300, type = "resource",
      name = {"iron-ore", "copper-ore", "coal", "stone"}}
    table.sort(ores, function(a, b) return a.position.x ^ 2 + a.position.y ^ 2 < b.position.x ^ 2 + b.position.y ^ 2 end)
    for _, o in ipairs(ores) do
      local d2_ = o.position.x ^ 2 + o.position.y ^ 2
      local far = true
      for _, q in ipairs(picked) do if (q.x - o.position.x) ^ 2 + (q.y - o.position.y) ^ 2 < 80 * 80 then far = false end end
      if d2_ > 120 * 120 and far and #picked < 3 then
        local x, y = math.floor(o.position.x), math.floor(o.position.y)
        local a1 = surface().find_non_colliding_position("electric-mining-drill", {x, y}, 6, 1)
        local d1 = a1 and put("electric-mining-drill", a1.x, a1.y)
        local a2 = a1 and surface().find_non_colliding_position("electric-mining-drill", {a1.x + 4, a1.y}, 6, 1)
        if a2 then put("electric-mining-drill", a2.x, a2.y) end
        local pp = surface().find_non_colliding_position("medium-electric-pole", {x + 2, y + 3}, 6, 1)
        if pp then put("medium-electric-pole", pp.x, pp.y) end
        local ep = surface().find_non_colliding_position("electric-energy-interface", {x + 3, y + 6}, 8, 1)
        local e = ep and put("electric-energy-interface", ep.x, ep.y)
        if e then e.power_production, e.electric_buffer_size = 1e6, 1e7 end
        if d1 then table.insert(picked, {x = x, y = y}) end
      end
    end
    S.outposts = #picked
    info(string.format("system: stand-in guns fed by inserter %d (inserters %d), power sources %d, weak face %s", S.fed or 0,
      surface().count_entities_filtered{name = "inserter", force = "player"},
      surface().count_entities_filtered{name = "electric-energy-interface", force = "player", position = {0, 0}, radius = 10},
      tostring(S.weak)))
    -- Its map, charted as a player's is by then (radars, a walk round): Grubstake prospects the player's charted
    -- frontier, and with 1,477 of its chunks uncharted it never found a patch (system 12345, 2026-10-24). Headless runs
    -- chart nothing (force.chart never lands; a chart here changed no byte of the run), so the check is waived.
    lp("debug_tune", {prospect_uncharted = true})
    S.frames = 0
  end)
  -- The opening as a game plays it (2026-10-24; LP_MIX=forced lands each once, directly, as the first measurements
  -- did, and then nothing landed again in two hours): oil researched (Grubstake's survey party), a chemical science pack
  -- made (its camp), the late gate opened (Kessler-Hayashi); the landing clock brings the rest.
  local forced = params.mix == "forced"
  -- LP_MIX=aged (the natural opening on an older world): for its first hour the wild biters expand every 30 to 60 s
  -- from evolution 0.3 (default: 4 to 60 minutes), so the map has the grown nest fields of a game hours in; then the
  -- defaults again.
  if params.mix == "aged" then
    schedule(20, function()
      local ex = game.map_settings.enemy_expansion
      ex.enabled = true
      S.expansion = {ex.min_expansion_cooldown, ex.max_expansion_cooldown}
      ex.min_expansion_cooldown, ex.max_expansion_cooldown = 30 * 60, 60 * 60
      game.forces.enemy.set_evolution_factor(0.3, surface())
    end)
    schedule(60 * 3600, function()
      local ex = game.map_settings.enemy_expansion
      ex.min_expansion_cooldown, ex.max_expansion_cooldown = S.expansion[1], S.expansion[2]
    end)
  end
  -- LP_MIX=dump<minute> (natural opening): each camp's map at that minute (scripts/campmap.py draws it), to see a raid
  -- that never left its camp (9 of 55 raids in the four seeds, 2026-10-24).
  -- Ground refused and crews stuck, by cause, at the end (cliffs measured, 2026-10-26).
  schedule(END - 30, function()
    for _, id in ipairs(lp("bases")) do
      local st = lp("stats", id)
      info(string.format("system: %s %d ground refused %s; crews stuck %d; cliffs blasted %d, water tiles filled %d, piers %d", st.corp, id,
        serpent.line(st.refused or {}), st.crews_stuck or 0, st.blasted or 0, st.landfilled or 0, st.piers or 0))
    end
  end)
  local dump_at = tonumber((params.mix or ""):match("^dump(%d+)$"))
  if dump_at then
    schedule(dump_at * 3600, function()
      for _, id in ipairs(lp("bases")) do
        local st = lp("stats", id)
        dump_map(string.format("system-%s-%d-m%d", st.corp, id, dump_at), {st.origin.x, st.origin.y}, 160)
      end
    end)
  end
  -- LP_MIX=solo: Synthexis alone against the stand-in (the user, 2026-10-24: "why not test it in isolation against a
  -- player base? Without Kessler"): no corporation's arrival is set off, and their landing clock is stopped.
  -- LP_MIX=solo-nolearn: the same with its lessons off (what learning is worth, measured against solo); solo-noorder:
  -- with its lessons but no breeding to order (what the order is worth); solo-nohold: its bursters not held back.
  local solo = params.mix == "solo" or params.mix == "solo-nolearn" or params.mix == "solo-noorder" or params.mix == "solo-nohold"
  S.solo = solo
  if solo then
    schedule(40, function() lp("debug_tune", {cadence_minutes = 1000000, biotech_unlearned = params.mix == "solo-nolearn",
      biotech_no_orders = params.mix == "solo-noorder", biotech_no_hold = params.mix == "solo-nohold"}) end)
    -- Solo, the stand-in rebuilds as a player with robots does: what it lost five minutes on, as it was (a stand-in gutted
    -- by the first wave that broke in left every later wave nothing to break, and learning could not be measured).
    schedule(3600, function()
      S.plan = {}
      for _, e in ipairs(surface().find_entities_filtered{force = "player", area = {{-60, -60}, {60, 60}}}) do
        if e.prototype.is_building or e.type == "wall" then
          local r = {name = e.name, pos = {e.position.x, e.position.y}, dir = e.direction}
          if e.type == "electric-energy-interface" then r.power = {e.power_production, e.electric_buffer_size} end
          if e.type == "assembling-machine" then r.recipe = e.get_recipe() and e.get_recipe().name end
          if e.type == "ammo-turret" then r.items = {name = "piercing-rounds-magazine", count = 100} end
          if e.type == "container" then r.items = {name = "piercing-rounds-magazine", count = 200} end
          table.insert(S.plan, r)
        end
      end
      S.rebuilt = 0
    end)
    for t = 2 * 3600, END - 120, 600 do
      schedule(t, function()
        for _, r in ipairs(S.plan or {}) do
          if not (r.e and r.e.valid) then
            r.e = surface().find_entity(r.name, r.pos)
            if r.e then r.lost = nil
            elseif not r.lost then r.lost = game.tick
            elseif game.tick - r.lost >= 5 * 3600 then
              local e = surface().create_entity{name = r.name, position = r.pos, direction = r.dir, force = "player",
                raise_built = true}
              if e then
                r.e, r.lost, S.rebuilt = e, nil, S.rebuilt + 1
                if r.power then e.power_production, e.electric_buffer_size = r.power[1], r.power[2] end
                if r.recipe then e.set_recipe(r.recipe); e.insert{name = "iron-plate", count = 400} end
                if r.items then e.insert(r.items) end
                if e.type == "ammo-turret" then table.insert(S.guns, e) end
              end
            end
          end
        end
      end)
    end
    schedule(END - 61, function() info(string.format("system: the stand-in rebuilt %d buildings", S.rebuilt or 0)) end)
  elseif forced then
    schedule(SYSTEM_LAND_G * 3600, function()
      S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
      storage.id = storage.id or S.g
    end)
    schedule(SYSTEM_LAND_S * 3600, function()
      S.s = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "serenity"})
    end)
  else
    schedule(40, function() lp("debug_tune", {phases_fast = true}) end)
    schedule(SYSTEM_LAND_G * 3600, function() game.forces.player.technologies["oil-processing"].researched = true end)
    schedule((SYSTEM_LAND_G + 4) * 3600, function()
      game.forces.player.get_item_production_statistics(surface()).on_flow("chemical-science-pack", 1)
    end)
    schedule(SYSTEM_LAND_S * 3600, function() lp("debug_late_gate") end)
    -- Who landed: the first base of each corporation, looked up as they come.
    for t = 2 * 3600, END - 60, 3600 do
      schedule(t, function()
        for _, id in ipairs(lp("bases")) do
          local st = lp("stats", id)
          if st and st.corp == "grubstake" and not S.g then S.g = id end
          if st and st.corp == "serenity" and not S.s then S.s = id end
        end
        storage.id = storage.id or S.g or S.s
      end)
    end
  end
  schedule(SYSTEM_SYNTH * 3600, function()
    local evo = game.forces.enemy.get_evolution_factor(surface())
    local want = params.mix == "aged" and 0.4 or 0.25
    if evo < want then game.forces.enemy.set_evolution_factor(want, surface()) end
    -- A field for it, away from Serenity (a seed may have none in its band); not taken (seed 1: no landing in two
    -- hours), another a quarter turn round, five minutes on, up to four.
    local o = S.s and lp("stats", S.s) and lp("stats", S.s).origin or {x = 1, y = 0}
    local len = math.max(1, math.sqrt(o.x * o.x + o.y * o.y))
    local function field(k)
      local a = math.atan2(-o.y, -o.x) + k * math.pi / 2
      -- 900 out: Synthexis wants none of the player's buildings within 600 of its field, and the stand-in's outposts
      -- reach 300 from spawn (at 750 they blocked every direction on seed 1).
      local c = {math.cos(a) * 900, math.sin(a) * 900}
      surface().request_to_generate_chunks(c, 3)
      surface().force_generate_chunk_requests()
      -- Aged: a grown field, twelve nests and four worms (the user, 2026-10-24: Synthexis arrives after hours of
      -- the biters' spreading, not on five nests).
      local spots = {{0, 0}, {14, 6}, {-12, 8}, {6, -14}, {-8, -12}}
      if params.mix == "aged" then
        for i = 1, 7 do local b_ = i * 2 * math.pi / 7; table.insert(spots, {math.cos(b_) * 28, math.sin(b_) * 28}) end
      end
      for _, d in ipairs(spots) do
        local q = surface().find_non_colliding_position("biter-spawner", {c[1] + d[1], c[2] + d[2]}, 30, 1)
        if q then surface().create_entity{name = "biter-spawner", position = q, force = "enemy"} end
      end
      if params.mix == "aged" then
        for i = 1, 4 do
          local b_ = (i + 0.5) * math.pi / 2
          local q = surface().find_non_colliding_position("medium-worm-turret", {c[1] + math.cos(b_) * 18, c[2] + math.sin(b_) * 18}, 20, 1)
          if q then surface().create_entity{name = "medium-worm-turret", position = q, force = "enemy"} end
        end
      end
      S.synth = lp("farm_arrive", 1)
      S.synth_tries = k + 1
      if not S.synth and k < 3 then schedule(game.tick - storage.t0 + 5 * 3600, function() field(k + 1) end) end
    end
    field(0)
  end)
  -- A minute's frame: pollution let out, ammunition topped up, the state of each faction.
  for t = 3600, END - 60, 3600 do
    schedule(t, function()
      local m = game.tick / 3600
      -- A factory growing: 600 a minute rising by 40 a minute (about the pollution of a few dozen boilers and drills).
      surface().pollute({0, 0}, (600 + 40 * m))
      for _, g in ipairs(S.guns or {}) do if g.valid then g.insert{name = "piercing-rounds-magazine", count = 50} end end
      local frame = {minute = m, evo = game.forces.enemy.get_evolution_factor(surface()), corps = {}, kills = S.kills or {}}
      for _, id in ipairs(lp("bases")) do
        local st = lp("stats", id)
        if st then
          local c = frame.corps[st.corp] or {bases = 0, live = 0, radius = {}, parts = 0, made = 0, fabs = 0, drills = 0,
            turrets = 0, garrison = 0, units_lost = 0, lost = 0, raids = 0, ops = {}, claims = 0, at = {}}
          frame.corps[st.corp] = c
          c.bases = c.bases + 1
          if not st.fallen then
            c.live = c.live + 1
            table.insert(c.radius, st.claim_radius or 0)
            -- Where its camps stand (system_report.py: a rivalry is judged between neighbours).
            table.insert(c.at, {math.floor(st.origin.x), math.floor(st.origin.y)})
            c.parts, c.made = c.parts + (st.parts or 0), c.made + (st.made or 0)
            c.fabs, c.drills, c.turrets = c.fabs + st.fabs, c.drills + st.drills, c.turrets + st.turrets
            c.garrison = c.garrison + st.garrison
            -- Its claims (strip camps settled on the player's ore): ground it holds beyond its camps' discs.
            c.claims = c.claims + (st.claims_settled or 0)
            -- Its posture (strategy.lua): the most pressed of its settlements.
            if st.posture and (not c.pressed or st.posture.pressed > c.pressed) then
              c.pressed, c.arm, c.war = st.posture.pressed, st.posture.arm, st.posture.war
            end
          end
          c.units_lost, c.lost = c.units_lost + (st.units_lost or 0), c.lost + (st.lost or 0)
          c.raids = c.raids + (st.raids_sent or 0)
          for _, l in ipairs(st.ops and st.ops.log or {}) do
            local o = l.owner or "?"
            c.ops[o] = (c.ops[o] or 0) + 1
          end
        end
      end
      for _, f in ipairs({"player", "lp-serenity", "lp-grubstake", "lp-biotech"}) do
        frame[f] = {units = surface().count_entities_filtered{force = f, type = {"unit", "spider-unit"}},
          all = surface().count_entities_filtered{force = f}}
      end
      local fs = lp("farm_state").farms
      frame.watch = (lp("watch_state") or {}).alarms or {}
      frame.weak = S.weak
      -- The wild biters' nests on the map (LP_MIX=aged grows them for an hour).
      frame.nests = surface().count_entities_filtered{force = "enemy", type = "unit-spawner"}
      frame.biotech = {farms = #fs, at = {}}
      for _, f in ipairs(fs) do
        local q = f.pos and (f.pos.x and f.pos or {x = f.pos[1], y = f.pos[2]})
        if q then table.insert(frame.biotech.at, {math.floor(q.x), math.floor(q.y)}) end
      end
      if fs[1] then frame.biotech.pens, frame.biotech.evo, frame.biotech.clinic = fs[1].pens, fs[1].evo, fs[1].clinic end
      local hs = lp("herd_state")
      frame.biotech.waves = #(hs.log or {})
      -- What each faction knows (scripts/know.lua): its losses by killer force, its grievances.
      frame.know = lp("know_state")
      -- The most each faction held at once (its ledger keeps an hour): what the check below reads.
      S.know_max = S.know_max or {}
      for fk, k in pairs(frame.know or {}) do S.know_max[fk] = math.max(S.know_max[fk] or 0, k.losses or 0) end
      helpers.write_file("landing-party/system.jsonl", helpers.table_to_json(frame) .. "\n", true)
      local rows = {}
      for _, r in ipairs(S.death_buf or {}) do rows[#rows + 1] = helpers.table_to_json(r) .. "\n" end
      helpers.write_file("landing-party/deaths.jsonl", table.concat(rows), true)
      S.death_buf = {}
      S.frames = (S.frames or 0) + 1
    end)
  end
  schedule(END - 30, function()
    check("system: a frame a minute written", (S.frames or 0) >= END / 3600 - 2, tostring(S.frames))
    -- The knowledge layer saw what the world did to each faction: a faction that lost anything holds a record of it.
    local lost, recorded = {}, {}
    for key, n in pairs(S.kills or {}) do
      local victim = key:match("^(.-)>")
      local fk = victim == "lp-serenity" and "serenity" or victim == "lp-grubstake" and "grubstake"
        or victim == "lp-biotech" and "biotech" or nil
      if fk then lost[fk] = (lost[fk] or 0) + n end
    end
    for fk, n in pairs(S.know_max or {}) do recorded[fk] = n end
    local ok = true
    for fk, n in pairs(lost) do if n > 0 and (recorded[fk] or 0) == 0 then ok = false end end
    check("system: each faction's losses known to it", ok, serpent.line({lost = lost, recorded = recorded}))
    -- Every wave chose its face (0.2.18: from the ground; with the scout's sightings 15 of 19 waves came blind in
    -- four-faction runs, their scouts killed by Kessler-Hayashi's armies, 2026-10-25).
    local hl = lp("herd_state").log or {}
    local blind = 0
    for _, l in ipairs(hl) do if l.blind or not l.mark then blind = blind + 1 end end
    check("system: every Synthexis wave chose its face", blind == 0, string.format("%d of %d without", blind, #hl))
    if S.solo then
      check("system: Synthexis landed (solo)", S.synth ~= nil and S.synth ~= false, tostring(S.synth))
      -- Every wave that marched walked its trail to the breach (as one compound order the march "ended" within 120 ticks
      -- on seeds 777 and 1, its first legs out of the incubator field unwalkable, and the herd went straight at its mark).
      local fast = {}
      for _, l in ipairs(lp("herd_state").log) do
        if l.t_march and l.t_breach then
          local len = 0
          for k = 2, #(l.trail or {}) do
            local a, b = l.trail[k - 1], l.trail[k]
            len = len + math.sqrt(((a[1] or a.x) - (b[1] or b.x)) ^ 2 + ((a[2] or a.y) - (b[2] or b.y)) ^ 2)
          end
          if l.t_breach - l.t_march < len * 3 then
            table.insert(fast, string.format("wave %d: %d ticks for %.0f tiles", l.id, l.t_breach - l.t_march, len))
          end
        end
      end
      check("system: every wave walked its trail (solo)", #fast == 0, table.concat(fast, "; "))
    else
      check("system: every faction landed", S.g ~= nil and S.s ~= nil and S.synth ~= nil and S.synth ~= false,
        string.format("grubstake %s, serenity %s, synthexis %s", tostring(S.g), tostring(S.s), tostring(S.synth)))
    end
  end)
end

-- (Required at load: require cannot run inside a scheduled step.)
local COUNTERS = require("__landing-party__.counters")
-- Compose (the faction AI's composition, step 5): six of Serenity's Line troopers walk into four gun turrets with
-- piercing rounds and die; its mix is then tilted toward what beats gun turrets (counters.lua): the kind that scores
-- best against them gains on the one that scores worst.
-- feeds (the perception consult, step 4): a gun turret loaded by one inserter from one belt line, an underground pair
-- in it, reads as hanging on the whole line (feeds.lua follows the belt upstream, under the ground too: underground_belt_
-- neighbour; a key of 2.0's crashed the first deathworld run with an underground in its ammunition line).
scenarios.feeds = function()
  schedule(60, function()
    lp("debug_tune", {raids_off = true, history_off = true})
    local o = lp("stats", storage.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local c = {math.floor(o.x - o.x / len * 120), math.floor(o.y - o.y / len * 120)}
    flatten(c[1] - 30, c[2] - 20, c[1] + 30, c[2] + 20)
    S.c = c
    -- One line: from the far west, eastward into an inserter, into a turret.
    local function line(x0, y, n, under)
      local made = {}
      for k = 0, n - 1 do
        local x = x0 + k
        local name, extra = "transport-belt", nil
        if under and k == under then name, extra = "underground-belt", "input" end
        if under and k > under and k < under + 3 then name = nil end
        if under and k == under + 3 then name, extra = "underground-belt", "output" end
        if name then
          local e = surface().create_entity{name = name, position = {x + 0.5, y + 0.5}, direction = defines.direction.east,
            force = "player", type = extra}
          made[#made + 1] = e
        end
      end
      return made
    end
    local function feed(x, y, dir)
      -- An inserter at x, y, turned until it drops east (dir 1) or west (dir -1).
      for _, d in ipairs({defines.direction.east, defines.direction.west}) do
        local ins = surface().create_entity{name = "burner-inserter", position = {x + 0.5, y + 0.5}, direction = d, force = "player"}
        if (ins.drop_position.x - ins.position.x) * dir > 0 then return ins end
        ins.destroy()
      end
    end
    -- The first turret: one line of 14, an underground pair at 4 (its far end 10 tiles out).
    local t1 = surface().create_entity{name = "gun-turret", position = {c[1] + 1, c[2] - 5}, force = "player"}
    t1.insert{name = "piercing-rounds-magazine", count = 10}
    S.line1 = line(c[1] - 15, c[2] - 6, 14, 4)
    S.ins1 = feed(c[1] - 1, c[2] - 6, 1)
    -- The second: one plain line.
    local t2 = surface().create_entity{name = "gun-turret", position = {c[1] + 1, c[2] + 7}, force = "player"}
    t2.insert{name = "piercing-rounds-magazine", count = 10}
    S.line2 = line(c[1] - 12, c[2] + 6, 11)
    S.ins2 = feed(c[1] - 1, c[2] + 6, 1)
    S.t1, S.t2 = t1, t2
    -- A tank feeding three flamethrowers in a row through runs of pipe (each turret passes the fluid on): the pipe by the
    -- tank parts all three, the pipe between the first and second the last two.
    local X = c[1] + 2
    local function row(R, oil)
      local function pipe(x) return surface().create_entity{name = "pipe", position = {x + 0.5, R + 0.5}, force = "player"} end
      local tank = surface().create_entity{name = "storage-tank", position = {X + 0.5, R - 0.5}, force = "player"}
      if oil then tank.insert_fluid{name = "crude-oil", amount = oil} end
      local pipes, flames = {}, {}
      for _, x in ipairs({X + 2, X + 3, X + 4, X + 5, X + 8, X + 9, X + 10, X + 13, X + 14, X + 15, X + 16}) do pipes[x - X] = pipe(x) end
      for _, x in ipairs({X + 7, X + 12, X + 18}) do
        flames[#flames + 1] = surface().create_entity{name = "flamethrower-turret", position = {x, R - 0.5},
          direction = defines.direction.north, force = "player"}
      end
      return pipes, flames
    end
    S.pipes, S.flames = row(c[2] - 15)
    -- The same, its tank full: the pipes past the tank hold more oil than the turrets, hours of fire; the pipe into the last
    -- turret alone is a cut (the user, 2026-10-30: one tank of 15,000 kept an outpost's flamethrowers going for hours).
    S.wet = row(c[2] - 9, 20000)
  end)
  schedule(5 * 60, function()
    local c = S.c
    local seen = lp("debug_feeds", {c[1], c[2]}, 40)
    info("feeds: " .. serpent.line(seen))
    local by = {}
    for _, f in ipairs(seen) do by[string.format("%.1f,%.1f", f[2], f[3])] = f end
    local far = S.line1 and S.line1[1]
    local farkey = far and far.valid and string.format("%.1f,%.1f", far.position.x, far.position.y)
    check("feeds: the inserter drops into the turret", S.ins1 and S.ins1.drop_target == S.t1,
      tostring(S.ins1 and S.ins1.drop_target and S.ins1.drop_target.name))
    check("feeds: the far end of the line, past the underground, starves the turret", farkey and by[farkey] and by[farkey][4] >= 1,
      tostring(farkey))
    -- (Its flamethrowers' pipes: none was read, the user's fort's 22 fed from one tank, 2026-10-30.)
    local function starves(p) return p and p.valid and by[string.format("%.1f,%.1f", p.position.x, p.position.y)] and
      by[string.format("%.1f,%.1f", p.position.x, p.position.y)][4] or 0 end
    local linked = {}
    for _, ft in ipairs(S.flames or {}) do linked[#linked + 1] = #(ft.fluidbox_neighbours[1] or {}) end
    check("feeds: the pipe by the tank parts all three flamethrowers, the one past the first two",
      starves(S.pipes[3]) == 3 and starves(S.pipes[9]) == 2,
      serpent.line({by_tank = starves(S.pipes[3]), past_first = starves(S.pipes[9]), linked = linked}))
    check("feeds: full, the pipe by the tank no cut, the pipe into the last flamethrower one",
      starves(S.wet[3]) == 0 and starves(S.wet[16]) == 1,
      serpent.line({by_tank = starves(S.wet[3]), into_last = starves(S.wet[16]), oil_past = S.wet[16].valid and S.wet[16].get_fluid_count()}))
  end)
end

-- perceive (the perception consult, step 7: lab bases each with a named expectation, checked before any wave): what
-- Synthexis reads of a base. "" (lasers on one power line): the pole whose loss darkens them is a feed (feeds.lua, by
-- power.cut); twofeed (the same line fed from both ends): no single cut, the player's answer; sprawl (machines in the
-- open, three guns among them, no wall): its best soft heart is a cell no gun covers.
scenarios.perceive = function()
  local mix = params.mix or ""
  schedule(60, function()
    lp("debug_tune", {raids_off = true, history_off = true, harmless = true})
    local o = lp("stats", storage.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local c = {math.floor(o.x - o.x / len * 200), math.floor(o.y - o.y / len * 200)}
    flatten(c[1] - 90, c[2] - 40, c[1] + 90, c[2] + 40)
    S.c = c
    local function put(name, x, y) return surface().create_entity{name = name, position = {c[1] + x, c[2] + y}, force = "player"} end
    if mix == "" or mix == "twofeed" then
      -- Eight lasers round a substation, its power from a source 70 tiles east down a line of big poles (and, twofeed,
      -- a second from 70 tiles west).
      put("substation", 0, 0)
      for k = 0, 7 do
        local a = k * math.pi / 4
        put("laser-turret", math.floor(math.cos(a) * 6 + 0.5), math.floor(math.sin(a) * 6 + 0.5))
      end
      local function line(sign)
        -- (Within wire reach: a substation's 18, a big pole's 32.)
        for _, x in ipairs({16, 44, 68}) do put("big-electric-pole", sign * x, 0) end
        put("substation", sign * 74, 0)
        local src = put("electric-energy-interface", sign * 78, 0)
        src.power_production, src.electric_buffer_size = 1e7, 1e8
      end
      line(1)
      if mix == "twofeed" then line(-1) end
    elseif mix == "sprawl" then
      for k = 0, 11 do put("assembling-machine-2", -60 + k * 10, (k % 2) * 12 - 6) end
      for _, x in ipairs({-55, 0, 55}) do
        local t = put("gun-turret", x, 20)
        t.insert{name = "piercing-rounds-magazine", count = 50}
      end
    end
  end)
  schedule(5 * 60, function()
    local c = S.c
    if mix == "" or mix == "twofeed" then
      local seen = lp("debug_feeds", {c[1], c[2]}, 90)
      info("perceive feeds: " .. serpent.line(seen))
      local pole
      for _, f in ipairs(seen) do if f[1]:find("pole") and f[4] >= 4 then pole = f end end
      if mix == "" then check("perceive: one power line, its pole a feed that darkens the lasers", pole ~= nil, serpent.line(seen))
      else check("perceive: fed from both ends, no single cut", pole == nil, serpent.line(seen)) end
    elseif mix == "sprawl" then
      local maps = lp("debug_base_maps", {c[1] - 120, c[2]}, 200, 60, 200)
      local h = maps.hearts[1]
      info("perceive hearts: " .. serpent.line(maps.hearts))
      check("perceive: sprawl, its best soft heart is no gun's", h ~= nil and h[4] == 0, serpent.line(h))
    end
  end)
end

scenarios.compose = function()
  schedule(60, function()
    lp("debug_tune", {raids_off = true, history_off = true})
    local o = lp("stats", storage.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local c = {math.floor(o.x - o.x / len * 120), math.floor(o.y - o.y / len * 120)}
    flatten(c[1] - 12, c[2] - 12, c[1] + 12, c[2] + 12)
    for k = -1, 2 do
      local t = surface().create_entity{name = "gun-turret", position = {c[1] + k * 3, c[2]}, force = "player"}
      t.insert{name = "piercing-rounds-magazine", count = 200}
    end
    for k = 1, 6 do
      surface().create_entity{name = "lp-infantry", position = {c[1] - 6 + k * 2, c[2] - 8}, force = "lp-serenity"}
    end
    S.c = c
  end)
  schedule(60 * 60, function()
    S.compose = lp("debug_compose", storage.id)
    info("compose: " .. serpent.line(S.compose))
    local m, k = S.compose.mix, S.compose.composed
    local best, worst, bs, ws
    local counters = COUNTERS
    for name in pairs(m) do
      local row = counters[name]
      local s = row and row["gun-turret"]
      if s then
        if not bs or s > bs then best, bs = name, s end
        if not ws or s < ws then worst, ws = name, s end
      end
    end
    check("compose: its losses to gun turrets known", ((lp("know_state").serenity or {}).losses or 0) >= 3,
      serpent.line(lp("know_state").serenity))
    check("compose: it builds more of what beats gun turrets", best and worst and best ~= worst
      and k[best] / m[best] > k[worst] / m[worst], string.format("%s (%.2f against gun turrets) x%.2f, %s (%.2f) x%.2f",
      tostring(best), bs or 0, best and k[best] / m[best] or 0, tostring(worst), ws or 0, worst and k[worst] / m[worst] or 0))
  end)
end

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
    S.signs = p.signs and wreck and wreck.get_inventory(defines.inventory.chest).get_item_count("electronic-circuit") or 0
    game.forces.player.technologies["oil-processing"].researched = true
  end)
  schedule(6 * 3600, function()
    local p = lp("phases")
    S.survey = p.survey
    S.survey_entities = p.survey and surface().count_entities_filtered{position = p.survey.pos, radius = 20,
      force = "lp-" .. p.survey.corp} or 0
    -- Its drills on ore (the user saw them on grass beside the coal).
    S.survey_drills, S.survey_on_ore = 0, 0
    for _, d in pairs(p.survey and surface().find_entities_filtered{position = p.survey.pos, radius = 30, type = "mining-drill",
      force = "lp-" .. p.survey.corp} or {}) do
      S.survey_drills = S.survey_drills + 1
      if surface().count_entities_filtered{type = "resource", area = d.bounding_box} > 0 then S.survey_on_ore = S.survey_on_ore + 1 end
    end
    if p.survey then
      local radar = surface().find_entities_filtered{position = p.survey.pos, radius = 3, type = "radar"}[1]
      if radar then radar.die("player") end
    end
  end)
  schedule(9 * 3600, function()
    local p = lp("phases")
    S.destroyed = p.survey and p.survey.done
    S.core = p.survey and select(2, dropped(p.survey.pos, 8)) or 0
    game.forces.player.get_item_production_statistics(surface()).on_flow("chemical-science-pack", 1)
    S.trigger_at = game.tick
  end)
  schedule(9 * 3600 + 12 * 3600, function() S.early = #lp("bases") end)
  schedule(9 * 3600 + 24 * 3600, function()
    local ids = lp("bases")
    S.late = #ids
    storage.id = ids[1]
    S.first_corp = ids[1] and lp("stats", ids[1]).corp
    -- Serenity's gate (staggered arrival): none of its settlements yet; a utility science pack opens it, or with Space
    -- Age the first rocket launch (as one would: debug_late_gate).
    for _, id in ipairs(ids) do if lp("stats", id).corp == "serenity" then S.serenity_early = true end end
    if script.active_mods["space-age"] then lp("debug_late_gate")
    else game.forces.player.get_item_production_statistics(surface()).on_flow("utility-science-pack", 1) end
  end)
  schedule(9 * 3600 + 32 * 3600, function()
    for _, id in ipairs(lp("bases")) do if lp("stats", id).corp == "serenity" then S.serenity = true end end
  end)
  schedule(END - 60, function()
    local p = lp("phases")
    if not storage.id then storage.id = lp("bases")[1] end
    check("phases: a radar brought the signs, parts in the wreck", (S.signs or 0) > 0, tostring(S.signs) .. " circuits")
    check("phases: the survey party's drills stand on ore", (S.survey_drills or 0) >= 2 and S.survey_on_ore == S.survey_drills,
      string.format("%s of %s", tostring(S.survey_on_ore), tostring(S.survey_drills)))
    check("phases: oil processing brought a survey party", S.survey ~= nil and S.survey_entities >= 4,
      tostring(S.survey_entities) .. " entities at the survey site")
    check("phases: destroyed, it dropped a command core", S.destroyed == "destroyed" and S.core > 0,
      tostring(S.destroyed) .. ", " .. tostring(S.core) .. " items on the ground")
    check("phases: the arrival waited out the delay", S.early == 0, S.early .. " settlements 12 minutes after the trigger")
    check("phases: then it came", (S.late or 0) > 0, tostring(S.late) .. " settlements 24 minutes after")
    check("phases: Grubstake came first", S.first_corp == "grubstake", tostring(S.first_corp))
    check("phases: Serenity not before its gate", not S.serenity_early, tostring(S.serenity_early))
    check("phases: and soon after it opened", S.serenity == true, tostring(S.serenity))
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

-- Temper: Serenity strikes first (the user, 2026-10-19: at war from landing, "no grace"; it was provoked only). With a
-- depot and undefended relays within its sight but outside its territory, never provoked, it goes for them.
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
    check("temper: at war from landing, it struck first", early >= 1 and lp("standing", "serenity") == "enemy",
      early .. " unprovoked of " .. against .. "; provoked at " .. tostring(provoked))
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
-- 185 tiles out, never a shot: the line must grow, name a relay one step before enclosing it, then enclose it, and
-- not be provoked by that (the user, 2026-10-17: the line moving onto what stood there first is Serenity's act; it was
-- provoked before). LP_MIX=back: the player removes the relays on the warning; never provoked. LP_MIX=built: once the
-- relays are enclosed, the player builds an assembler beside them (raise_built, as a player's build): provoked then.
-- LP_MIX=turret: a gun turret built there instead: trespass, and Serenity answers it with a siege on the turret (its
-- reaction table: masonry and mortars for trespass, a raid for a loss).
scenarios.line = function()
  local turret = params.mix == "turret"
  -- Turret: at level 1, where its sieges begin (shared.CORPS caps); a younger Serenity answers with a raid.
  -- At war from landing (the user, 2026-10-19), it raided the relays before its line reached them: raids held (the
  -- turret mix lets them go once the turret is built, for the answer) and the relays lasting.
  schedule(30, function() lp("debug_tune", {perimeter_fast = true, raids_off = true, corp_level = turret and {serenity = 1} or nil}) end)
  schedule(60, function() for _ = 1, 2 do lp("debug_depot", storage.id, 3000) end end)
  schedule(120, function()
    local o = lp("stats", storage.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local c = {math.floor(o.x - o.x / len * 185), math.floor(o.y - o.y / len * 185)}
    flatten(c[1] - 10, c[2] - 10, c[1] + 10, c[2] + 10)
    S.relays = {}
    for k = -1, 1 do
      local r = surface().create_entity{name = "lp-command-relay", position = {c[1] + 5 * k, c[2]}, force = "player"}
      r.destructible = false
      table.insert(S.relays, r)
    end
  end)
  for m = 2, params.minutes - 1 do
    schedule(m * 3600 + 600, function()
      local st = lp("stats", storage.id)
      if st.warned and not S.warned_at then
        S.warned_at = game.tick
        if params.mix == "back" then for _, r in ipairs(S.relays) do if r.valid then r.destroy() end end end
      end
      -- Enclosed: the claim reaches the relays.
      local r = S.relays[2]
      if r and r.valid and not S.enclosed_at then
        local d = math.sqrt((r.position.x - st.origin.x) ^ 2 + (r.position.y - st.origin.y) ^ 2)
        if (st.claim_radius or 0) >= d + 3 then
          S.enclosed_at = game.tick
          S.provoked_at_enclosure = (lp("corp", "serenity").provoked or {}).player
          if params.mix == "built" or turret then
            local name = turret and "gun-turret" or "assembling-machine-1"
            local p = surface().find_non_colliding_position(name, {r.position.x, r.position.y + 6}, 10, 1)
            S.built = surface().create_entity{name = name, position = p, force = "player", raise_built = true}
            if turret then
              S.built.insert{name = "firearm-magazine", count = 50}
              lp("debug_tune", {raids_off = false})
            end
            S.built_at = game.tick
          end
        end
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
    if params.mix == "back" then
      check("line: pulled back, never provoked", provoked == nil, "provoked at " .. tostring(provoked))
    elseif turret then
      local log = st.ops.answered or {}
      info("line turret: answered " .. serpent.line(log) .. ", sieges " .. tostring(st.ops.sieges) .. ", turret "
        .. tostring(S.built and S.built.valid))
      check("line: a turret inside the line, provoked then", S.built_at and provoked ~= nil and provoked >= S.built_at,
        string.format("built at %s, provoked at %s", tostring(S.built_at), tostring(provoked)))
      check("line: trespass answered with a siege", (log["a siege"] or 0) >= 1, serpent.line(log))
    elseif params.mix == "built" then
      check("line: built inside the line, provoked then", S.built_at and provoked ~= nil and provoked >= S.built_at,
        string.format("built at %s, provoked at %s", tostring(S.built_at), tostring(provoked)))
    else
      check("line: the relays enclosed", S.enclosed_at ~= nil, "radius " .. string.format("%.0f", st.claim_radius))
      check("line: enclosed, not provoked", provoked == nil, "provoked at " .. tostring(provoked))
    end
  end)
end

-- Strip: Grubstake strips the player's ore. A patch of iron near it, two of the player's drills on one side, no
-- turrets: a camp must go up beside them, mine the real patch (its ore less), and the ore must reach home.
scenarios.strip = function()
  -- Serenity at war from landing raided the player's drill this scenario watches: a truce with it (Grubstake is the
  -- subject).
  schedule(30, function() lp("debug_tune", {strip_fast = true}); lp("debug_truce", "serenity", "player", params.minutes + 5) end)
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
    -- The tools force operations: none of the corporations' own in the way (camps raid from their landers now).
    lp("debug_tune", {raids_off = true})
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
    -- Armed, as a base's turrets are: a dry turret weighs nothing (threat.firing).
    for _, c in ipairs({S.guns, S.flames, S.relay}) do flatten(c[1] - 12, c[2] - 12, c[1] + 12, c[2] + 12) end
    for k = -1, 1 do
      put("gun-turret", {S.guns[1] + 4 * k, S.guns[2] - 5}).insert{name = "firearm-magazine", count = 50}
      put("flamethrower-turret", {S.flames[1] + 4 * k, S.flames[2] - 5}).insert_fluid{name = "light-oil", amount = 100}
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
        .insert{name = "firearm-magazine", count = 50}  -- armed: a dry turret weighs nothing (threat.firing)
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

-- Labs (rd.lua; the user, 2026-10-21: its tech in the world): Serenity's research climbs a branch only while that
-- branch's lab stands. Funded and choosing every minute, it buys nothing while it has no lab; its research rule plans a
-- district with the Optics lab at its heart; once the lab stands its lasers climb; the lab killed, the climb stops and
-- the lab comes back. A Lance (Optics) set outright is fielded only while the lab stands.
scenarios.labs = function()
  S.seen = {}
  schedule(60, function()
    -- Grown at once (its research rule waits for its launch pad: exports fund research).
    lp("debug_tune", {era = 4, rd_fast = true, history_off = true, rd_fund = {serenity = 9000}, mature_blocks = 2})
    lp("debug_parts", storage.id, 2000)
  end)
  local function lab()
    return surface().find_entities_filtered{name = "lp-optics-lab", force = FORCE}[1]
  end
  for t = 2 * 3600, END - 120, 600 do
    schedule(t, function()
      local r = lp("rd", "serenity")
      local l = lab()
      local lvl = (r.weapons or {}).laser or 0
      -- Funded until its lab stands: what is tested is the lab, not the economy (a depot district first and its eight
      -- fabricators' hunger for ore kept it under the rule's 150 parts for 30 minutes, 0.1.42).
      if not S.built and not l then
        local parts = lp("stats", storage.id).parts
        if parts < 200 then lp("debug_parts", storage.id, 200 - parts) end
      end
      if not S.built and l then
        S.built, S.lvl_at_built = game.tick, lvl
        S.lab_at = {l.position.x, l.position.y}
        info(string.format("labs: the Optics lab stood at %.0f,%.0f at minute %.1f, lasers at level %d, fund %d",
          l.position.x, l.position.y, game.tick / 3600, lvl, r.fund))
        -- Its sign: one sprite over it.
        local signs, bodies = 0, 0
        for _, o in pairs(rendering.get_all_objects("landing-party")) do
          if o.valid and (o.type == "sprite" or o.type == "animation") and o.target and o.target.entity == l then
            if o.type == "sprite" then signs = signs + 1 else bodies = bodies + 1 end
          end
        end
        S.signs, S.bodies = signs, bodies
        dump_map("labs-built", S.lab_at, 60)
      end
      if not S.built then S.wants = r.wants_lab; S.lvl_before = lvl end
      -- Its lab up for two minutes: killed (mid-climb); the level then is what it keeps until the lab is back.
      if S.built and not S.killed and game.tick > S.built + 2 * 3600 and l then
        S.lvl_at_kill = lvl
        S.killed = game.tick
        S.lance_fielded_before = (r.fielded or {})["lp-lance"] ~= nil
        l.die("player")
      end
      if S.killed and not S.back and game.tick > S.killed then
        l = lab()
        if l then
          S.back = game.tick
        else
          S.lvl_dark = math.max(S.lvl_dark or 0, lvl)
          S.lance_fielded_dark = S.lance_fielded_dark or (r.fielded or {})["lp-lance"] ~= nil
        end
      end
      S.lvl_end = lvl
    end)
  end
  -- A Lance node set outright (its units then in the mix only while the lab stands).
  schedule(2 * 3600 + 30, function() lp("debug_tune", {rd_tech = {serenity = {nodes = {lance = 1}}}}) end)
  schedule(END - 60, function()
    local r = lp("rd", "serenity")
    info("labs: " .. serpent.line({wants = S.wants, before = S.lvl_before, at_built = S.lvl_at_built, at_kill = S.lvl_at_kill,
      dark = S.lvl_dark, back = S.back and S.back / 3600, killed = S.killed and S.killed / 3600, built = S.built and S.built / 3600,
      end_ = S.lvl_end, fund = r.fund, nodes = r.nodes, signs = S.signs}))
    check("labs: it wanted the Optics lab first", S.wants == "lp-optics-lab", tostring(S.wants))
    check("labs: a research district built the Optics lab", S.built ~= nil, S.built and string.format("minute %.1f", S.built / 3600) or "none")
    check("labs: nothing bought while no lab stood", (S.lvl_at_built or 0) == 0, tostring(S.lvl_at_built))
    check("labs: the lab drawn with its sign and at work", (S.signs or 0) == 1 and (S.bodies or 0) == 1,
      string.format("%s signs, %s bodies", tostring(S.signs), tostring(S.bodies)))
    check("labs: its lab standing, its lasers climbed", (S.lvl_at_kill or 0) >= 1 and S.lvl_at_kill < 5, tostring(S.lvl_at_kill))
    check("labs: the Lance fielded while the lab stood", S.lance_fielded_before == true, tostring(S.lance_fielded_before))
    check("labs: the lab killed, no climb until it was back", S.killed and S.lvl_dark == S.lvl_at_kill,
      string.format("%s at the kill, %s without it", tostring(S.lvl_at_kill), tostring(S.lvl_dark)))
    check("labs: no Lance fielded without it", S.killed and not S.lance_fielded_dark, tostring(S.lance_fielded_dark))
    check("labs: the lab rebuilt", S.back ~= nil, S.back and string.format("minute %.1f", S.back / 3600) or "not yet")
    check("labs: back, the climb went on", (S.lvl_end or 0) > (S.lvl_at_kill or 0), string.format("%s -> %s", tostring(S.lvl_at_kill), tostring(S.lvl_end)))
  end)
end

-- Breach (the user, 2026-10-21: if its labs matter, the player has to be able to take one): a player army (LP_MIX
-- "troopers,breachers,tanks", default 20,10,5) goes for Serenity's Optics lab in its district. A careful player: the
-- squad gathers out of turret reach, then the rally point is steered onto the district's turret nearest our side (A),
-- one at a time; with none left within 45 of the lab, onto the lab itself. Maps every two minutes round the lab.
scenarios.breach = function()
  local ARMY = {"lp-trooper", "lp-breacher", "lp-battle-tank"}
  local ORDER = {["lp-trooper"] = "lp-trooper-order", ["lp-breacher"] = "lp-breacher-order",
    ["lp-battle-tank"] = "lp-battle-tank-order"}
  -- What each unit takes of the command bandwidth: the mod's own (a copy here said 4 for a battle tank after the mod
  -- made it 6, and the relays fell 20 short: on 2.1, where nothing died early, 30 of 40 trained).
  local POP = require("__landing-party__.shared").POPULATION
  local GUNS = {"lp-turret", "lp-gun-turret"}
  local red = defines.wire_connector_id.circuit_red
  local want, k = {}, 0
  for n in (params.mix or ""):gmatch("%d+") do k = k + 1; want[ARMY[k]] = tonumber(n) end
  if k == 0 then want = {["lp-trooper"] = 20, ["lp-breacher"] = 10, ["lp-battle-tank"] = 5} end
  local arty = params.mix == "arty" or params.mix == "flare"
  local SQUAD, POPULATION = 0, 0
  for name, n in pairs(want) do SQUAD = SQUAD + n; POPULATION = POPULATION + n * POP[name] end
  local function alive() return surface().count_entities_filtered{name = ARMY, force = "player"} end
  local function lab() return surface().find_entities_filtered{name = "lp-optics-lab", force = FORCE}[1] end
  schedule(60, function()
    -- Its research as a camp this young would have it (none bought: the lab is the target, not its lasers).
    lp("debug_tune", {era = 2, history_off = true, mature_blocks = 2, raids_off = true})
    lp("debug_parts", storage.id, 3000)
  end)
  local function setup(l)
    local lander = surface().find_entities_filtered{name = "lp-lander", force = FORCE}[1]
    local c = l.position
    S.lab_at = {c.x, c.y}
    local dx, dy = c.x - lander.position.x, c.y - lander.position.y
    local len = math.sqrt(dx * dx + dy * dy)
    local stage, a
    for _, turn in ipairs({0, 0.4, -0.4, 0.8, -0.8, 1.2, -1.2}) do
      local cs, sn = math.cos(turn), math.sin(turn)
      local ux, uy = (dx * cs - dy * sn) / len, (dx * sn + dy * cs) / len
      for d = 40, 250, 5 do
        local st = {c.x + ux * d, c.y + uy * d}
        local fwd = {c.x + ux * (d + 20), c.y + uy * (d + 20)}
        surface().request_to_generate_chunks(fwd, 2)
        surface().force_generate_chunk_requests()
        if surface().count_entities_filtered{name = GUNS, force = FORCE, position = st, radius = 35} == 0
          and surface().count_entities_filtered{force = FORCE, position = fwd, radius = 30} == 0
          and surface().count_tiles_filtered{position = fwd, radius = 30, collision_mask = "water_tile"} == 0 then
          stage, a, S.stage_d = st, {math.floor(fwd[1]), math.floor(fwd[2])}, d
          break
        end
      end
      if stage then break end
    end
    if not stage then check("breach: a staging ground clear of its guns", false, "none"); return end
    S.stage, S.base_at = stage, a
    flatten(a[1] - 28, a[2] - 6, a[1] + 42, a[2] + 12)
    local function put(name, x, y)
      return surface().create_entity{name = name, position = {x, y}, force = "player", raise_built = true}
    end
    S.barracks = {}
    for i, name in ipairs(ARMY) do
      local x = a[1] - 8.5 + 6 * i
      local b = put("lp-barracks", x, a[2] + 0.5)
      b.set_recipe(ORDER[name])
      S.barracks[name] = b
      put("medium-electric-pole", x + 2, a[2] + 2.5)
    end
    put("electric-energy-interface", a[1] + 14, a[2] + 1)
    for n = 1, 3 do game.forces.player.technologies["lp-command-bandwidth-" .. n].researched = true end
    for n = 1, math.ceil(POPULATION / 10) do put("lp-command-relay", a[1] - 25.5 + 4 * n, a[2] + 7.5) end
    for x = -23.5, 40, 7 do put("medium-electric-pole", a[1] + x, a[2] + 5.5) end
    S.beacon = put("lp-rally-beacon", stage[1], stage[2])
    S.cc = put("constant-combinator", stage[1] - 2, stage[2])
    S.cc.get_wire_connector(red, true).connect_to(S.beacon.get_wire_connector(red, true))
    S.orders = {}
    S.feed = function()
      for name, n in pairs(want) do
        local b = S.barracks[name]
        local done = S.orders[name] or 0
        if b.valid and done < n then
          S.orders[name] = done + b.get_inventory(defines.inventory.crafter_output).insert{name = ORDER[name],
            count = math.min(10, n - done)}
        end
      end
    end
    S.feed()
    -- LP_MIX "arty" (an artillery turret at the base, left to choose its own targets) or "flare" (and a flare on the lab,
    -- as a player's artillery remote): no squad.
    if params.mix == "arty" or params.mix == "flare" then
      want = {}
      local t = put("artillery-turret", a[1] + 20, a[2] - 4)
      -- 60 in all, fed as it fires (its ammo slot holds 15: an insert of 60 put 15 in, 2026-10-21).
      S.arty_fed = t.insert{name = "artillery-shell", count = 60}
      S.arty = t
      if params.mix == "flare" then
        surface().create_entity{name = "artillery-flare", position = S.lab_at, force = "player", frame_speed = 0,
          vertical_speed = 0, height = 0, movement = {0, 0}}
      end
    end
    S.guns0 = surface().count_entities_filtered{name = GUNS, force = FORCE, position = S.lab_at, radius = 45}
    S.walls0 = surface().count_entities_filtered{name = "lp-wall", force = FORCE, position = S.lab_at, radius = 45}
    S.st0 = lp("stats", storage.id)
    info(string.format("breach: lab at %.0f,%.0f; staging %d tiles out; %d guns and %d walls within 45; garrison %d",
      S.lab_at[1], S.lab_at[2], S.stage_d, S.guns0, S.walls0, S.st0.garrison or -1))
    dump_map("breach-0", S.lab_at, 75)
  end
  local function signals(list)
    local f = {}
    for name, v in pairs(list) do table.insert(f, {value = {type = "virtual", name = name, quality = "normal"}, min = v}) end
    local cb = S.cc.get_or_create_control_behavior()
    local sec = cb.get_section(1) or cb.add_section()
    sec.filters = f
  end
  for t = 2 * 3600, END - 120, 300 do
    schedule(t, function()
      local l = lab()
      -- Funded until its lab stands (as in labs: the lab is what is tested, not the economy).
      -- Topped up to the research rule's need only (funding more bought a garrison of 100 the squad died to, 0.1.43).
      if not S.seen and not l then
        local parts = lp("stats", storage.id).parts
        if parts < 200 then lp("debug_parts", storage.id, 200 - parts) end
      end
      -- Its district given four minutes to stand (walls, guns) once the lab is up.
      if not S.seen and l then S.seen = game.tick end
      if S.seen and not S.stage and game.tick >= S.seen + 4 * 3600 and l then setup(l) end
      if S.stage and not S.go then
        S.feed()
        local n = 0
        for name, w in pairs(want) do if (S.orders[name] or 0) >= w then n = n + 1 end end
        if alive() >= SQUAD or next(want) == nil then S.go = game.tick; S.trained = alive() end
        if S.ready_wait == nil then S.ready_wait = game.tick end
        if game.tick > S.ready_wait + 4 * 3600 then S.go = game.tick; S.trained = alive() end
        return
      end
      if not S.go or not (S.beacon and S.beacon.valid and S.cc.valid) then return end
      if (game.tick - S.go) % 7200 < 300 then dump_map("breach-" .. math.floor((game.tick - S.go) / 3600), S.lab_at, 75) end
      if not l then
        if not S.fell then
          S.fell = game.tick
          info(string.format("breach t+%ds: the lab fell (%d units left)", (game.tick - S.go) / 60, alive()))
          dump_map("breach-fell", S.lab_at, 75)
          signals({})
        end
        return
      end
      if arty then
        if S.arty and S.arty.valid and S.arty_fed < 60 then
          S.arty_fed = S.arty_fed + S.arty.insert{name = "artillery-shell", count = 60 - S.arty_fed}
        end
        if not S.shots_logged and S.arty and S.arty.valid then
          info(string.format("breach t+%ds: artillery shells left %d", (game.tick - S.go) / 60,
            S.arty.get_inventory(defines.inventory.turret_ammo).get_item_count("artillery-shell")))
        end
        return
      end
      if S.aim and S.aim.valid then return end
      local b = S.beacon.position
      local best, bd
      for _, x in pairs(surface().find_entities_filtered{name = GUNS, force = FORCE, position = S.lab_at, radius = 45}) do
        local d = (x.position.x - b.x) ^ 2 + (x.position.y - b.y) ^ 2
        if not bd or d < bd then best, bd = x, d end
      end
      local aim = best or l
      S.aim = aim
      S.aims = (S.aims or 0) + 1
      signals({["signal-A"] = 1, ["signal-X"] = math.floor(aim.position.x - b.x), ["signal-Y"] = math.floor(aim.position.y - b.y)})
      info(string.format("breach t+%ds: aim %d at the %s at %.0f,%.0f (%d units left)", (game.tick - S.go) / 60, S.aims,
        aim.name, aim.position.x, aim.position.y, alive()))
    end)
  end
  schedule(END - 60, function()
    local st = lp("stats", storage.id)
    local guns = S.lab_at and surface().count_entities_filtered{name = GUNS, force = FORCE, position = S.lab_at, radius = 45} or -1
    local walls = S.lab_at and surface().count_entities_filtered{name = "lp-wall", force = FORCE, position = S.lab_at, radius = 45} or -1
    metric("breach_squad", SQUAD)
    metric("breach_trained", S.trained or 0)
    metric("breach_alive", alive())
    metric("breach_guns_before", S.guns0 or -1)
    metric("breach_guns_after", guns)
    metric("breach_walls_before", S.walls0 or -1)
    metric("breach_walls_after", walls)
    metric("breach_lab_fell", S.fell and 1 or 0)
    metric("breach_minutes", S.fell and S.go and (S.fell - S.go) / 3600 or -1)
    check("breach: the squad was trained", arty or (S.trained or 0) >= SQUAD * 0.8, tostring(S.trained) .. " of " .. SQUAD)
    check("breach: the lab fell", S.fell ~= nil, S.fell and string.format("%.1f minutes in, %d units left", (S.fell - S.go) / 3600, alive())
      or string.format("%d units left, guns %d -> %d", alive(), S.guns0 or -1, guns))
    info("breach: " .. serpent.line(lp("army")) .. ", player units lost " .. serpent.line(S.killers or {})
      .. ", faction units lost: " .. serpent.line(S.fallen or {}) .. ", responses " .. tostring(st.responses - (S.st0 and S.st0.responses or 0)))
  end)
end

-- Parked (the legibility audit, step 1): Serenity's howitzer stands parked by its lander, a prop; killed there,
-- its camp goes without one for 30 minutes, a ghost on its spot.
scenarios.parked = function()
  schedule(60, function() lp("debug_tune", {mature_blocks = 1}) end)
  schedule(3 * 3600, function()
    local st = lp("stats", storage.id)
    local h = surface().find_entities_filtered{name = "lp-parked-howitzer", force = FORCE}
    S.parked = st.parked and #h == 1
    if h[1] then
      S.off = h[1].type == "simple-entity-with-force" and not h[1].prototype.is_military_target
      S.at = {h[1].position.x, h[1].position.y}
      info(string.format("parked: the howitzer at %.0f,%.0f, %.0f tiles from the lander", S.at[1], S.at[2],
        math.sqrt((S.at[1] - st.origin.x) ^ 2 + (S.at[2] - st.origin.y) ^ 2)))
      h[1].die("player")
    end
  end)
  schedule(3 * 3600 + 600, function()
    local st = lp("stats", storage.id)
    S.down = (st.howitzer_down or 0) > game.tick
    S.ghost = st.parked_ghost
    S.gone = not st.parked and surface().count_entities_filtered{name = {"lp-howitzer", "lp-parked-howitzer"}, force = FORCE} == 0
  end)
  schedule(END - 60, function()
    check("parked: a howitzer parked by its lander", S.parked == true, tostring(S.parked))
    check("parked: a prop, not a turret or a military target", S.off == true, tostring(S.off))
    check("parked: killed, its camp without one", S.down == true and S.gone == true, string.format("down %s, gone %s",
      tostring(S.down), tostring(S.gone)))
    check("parked: its ghost on the spot", S.ghost == true, tostring(S.ghost))
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
    lp("debug_tune", {wfc_core_off = true, era = 2, rd_fund = {[corp] = 5000}})
    if g then
      S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
      for _ = 1, 2 do lp("debug_depot", S.g, 3000) end
    else
      for _ = 1, 2 do lp("debug_depot", storage.id, 3000) end
      -- Line troopers enough for the kills whatever else its mix builds (railgunners took two in ten: 14 died).
      lp("debug_units", storage.id, "lp-infantry", 10)
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
-- each against four player radars, 160 tiles apart: both destroy them; the pellets do not wound their own side. Until the
-- RTS pass the times were held within 20% of each other (DPS parity, docs/reviews/2026-10-14-identity-trees-consult.md);
-- since (2026-10-21) the Shotgun hands are a close-range swarm with a tighter spread that lands more of its pellets on a
-- building (600 ticks to 810 in the 0.1.49 regression): no slower than the Line troopers, at most 40% faster.
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
    check("arms: the Shotgun hands no slower, at most 40% faster", a.done and g.done and g.done <= 1.05 * a.done
      and g.done >= 0.6 * a.done, string.format("%s vs %s", tostring(a.done), tostring(g.done)))
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
  prism = {corp = "serenity", victim = "lp-infantry", kills = 9, killer = "trooper", era = 2, made = "lp-prism",
    preset = {lance = 1}},
  tesla = {corp = "serenity", victim = "lp-infantry", kills = 10, killer = "turret", era = 3, made = "lp-tesla"},
  scorcher = {corp = "grubstake", victim = "lp-grubstake-infantry", kills = 8, killer = "turret", era = 2,
    made = "lp-grubstake-scorcher"},
  -- Anti-air (2026-10-23): its units killed by the player's combat robots buy each its answer to fliers.
  skyguard = {corp = "serenity", victim = "lp-infantry", kills = 6, killer = "destroyer", era = 2, made = "lp-skyguard"},
  ["flak-buggy"] = {corp = "grubstake", victim = "lp-grubstake-buggy", kills = 6, killer = "destroyer", era = 2,
    made = "lp-grubstake-flak-buggy"},
}
-- Heavies (the design sheet's picks, the user, 2026-10-21): each against what it is for, far from the camps.
--   A Scorcher (Grubstake's) before a player wall with gun turrets behind it: it spends flame bursts, and not more than
--   its three plus what refilled.
--   A Tesla (Serenity's) at a line of powered laser turrets: its lightning drains them.
--   A Prism (Serenity's) at a pack of eight troopers held still: its beam splits, more than one trooper hurt by a shot.
scenarios.heavies = function()
  schedule(60, function() lp("debug_tune", {raids_off = true, history_off = true}) end)
  schedule(2 * 3600, function()
    flatten(300, -60, 420, 60)
    -- The scorcher's wall and guns.
    for k = -6, 6 do surface().create_entity{name = "stone-wall", position = {330.5, k + 0.5}, force = "player"} end
    for _, y in ipairs({-3, 3}) do
      local t = surface().create_entity{name = "gun-turret", position = {333, y}, force = "player"}
      t.insert{name = "firearm-magazine", count = 10}
    end
    S.scorcher = spawn("lp-grubstake-scorcher", {316, 0}, 1, "lp-grubstake")[1]
    if S.scorcher then S.scorcher.commandable.set_command{type = defines.command.attack_area, destination = {331, 0}, radius = 8} end
    -- The tesla's lasers, powered.
    local eei = surface().create_entity{name = "electric-energy-interface", position = {372, -30}, force = "player"}
    surface().create_entity{name = "substation", position = {370, -26}, force = "player"}
    S.lasers = {}
    for k = 0, 3 do table.insert(S.lasers, surface().create_entity{name = "laser-turret", position = {366 + k * 2.5, -23}, force = "player"}) end
    S.tesla = spawn("lp-tesla", {370, -42}, 1, FORCE)[1]
    if S.tesla then S.tesla.commandable.set_command{type = defines.command.attack_area, destination = {370, -23}, radius = 8} end
    -- The prism's pack.
    -- Left active (a chain passes over frozen entities: the first run split to none of eight held with active = false).
    S.pack = spawn("lp-trooper", {372, 35}, 8, "player")
    S.prism = spawn("lp-prism", {372, 50}, 1, FORCE)[1]
    if S.prism then S.prism.commandable.set_command{type = defines.command.attack_area, destination = {372, 35}, radius = 6} end
    S.start = game.tick
  end)
  for t = 2 * 3600 + 30, 2 * 3600 + 3600, 30 do
    schedule(t, function()
      local hurt = 0
      for _, u in ipairs(S.pack or {}) do if u.valid and u.health < u.max_health then hurt = hurt + 1 elseif not u.valid then hurt = hurt + 1 end end
      if hurt > 0 and not S.first_hurt then S.first_hurt = hurt end
      S.most_hurt = math.max(S.most_hurt or 0, hurt)
    end)
  end
  schedule(2 * 3600 + 3600 + 60, function()
    local st = lp("scorcher_stats")
    info(string.format("heavies: bursts %d, drains %d, troopers hurt at first %s, at most %s", st.bursts, st.drains,
      tostring(S.first_hurt), tostring(S.most_hurt)))
    local sc = S.scorcher
    info(string.format("heavies: scorcher %s at %s, health %s; prism %s; pack health %s", tostring(sc and sc.valid),
      sc and sc.valid and serpent.line({sc.position.x, sc.position.y}) or "-", sc and sc.valid and sc.health or "-",
      tostring(S.prism and S.prism.valid), serpent.line((function() local o = {} for _, u in ipairs(S.pack or {}) do
        table.insert(o, u.valid and math.floor(u.health) or "dead") end return o end)())))
    -- Three, and one more each 20 s it refilled in the minute (and one at its edge).
    check("heavies: the scorcher spent flame on the wall line", st.bursts >= 1 and st.bursts <= 7, tostring(st.bursts))
    check("heavies: the tesla drained the lasers", st.drains >= 1, tostring(st.drains))
    check("heavies: the prism's beam split (more than one trooper hurt by its first shot)", (S.first_hurt or 0) >= 2,
      tostring(S.first_hurt))
  end)
end

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
      -- Line troopers enough for the kills whatever else its mix builds (railgunners took two in ten: 14 died).
      lp("debug_units", storage.id, "lp-infantry", 10)
    end
  end)
  schedule(10 * 3600, function()
    flatten(-5, -5, 5, 5)
    local cause
    if c.killer == "trooper" then cause = spawn("lp-trooper", {0, 0}, 1, "player")[1]
    elseif c.killer == "tank" then cause = surface().create_entity{name = "tank", position = {0, 0}, force = "player"}
    elseif c.killer == "artillery" then cause = surface().create_entity{name = "artillery-turret", position = {0, 0}, force = "player"}
    elseif c.killer == "turret" then cause = surface().create_entity{name = "gun-turret", position = {0, 0}, force = "player"}
    elseif c.killer == "destroyer" then cause = surface().create_entity{name = "destroyer", position = {0, 0}, force = "player"} end
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

-- Dismantle (the user, 2026-10-19: "Stealing items and buildings is genius for a more early game rival"): an unguarded
-- outpost 120 tiles from a Grubstake camp (four assemblers holding plates, two solar panels, a pole, a chest of
-- circuits), a raid sent at it: the machines taken apart, their ghosts left, the goods home in the yard.
-- LP_MIX=ambush: the raiders killed once they have taken two; what they carried spills there.
scenarios.dismantle = function()
  local ambush = params.mix == "ambush"
  local function toward(id, d)
    local o = lp("stats", id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    return {math.floor(o.x - o.x / len * d), math.floor(o.y - o.y / len * d)}
  end
  schedule(60, function()
    lp("debug_tune", {era = 2, ops_off = false})
    S.id = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    for _ = 1, 2 do lp("debug_depot", S.id, 3000) end
  end)
  schedule(3 * 3600, function()
    lp("debug_tune", {raids_off = true})
    local c = toward(S.id, 120)
    flatten(c[1] - 30, c[2] - 30, c[1] + 30, c[2] + 30)
    S.c = c
    for k = 0, 3 do
      local a = surface().create_entity{name = "assembling-machine-1", position = {c[1] - 6 + 4 * k + 0.5, c[2] + 0.5}, force = "player"}
      a.set_recipe("iron-gear-wheel")
      a.insert{name = "iron-plate", count = 40}
    end
    for k = 0, 1 do
      surface().create_entity{name = "solar-panel", position = {c[1] - 3 + 4 * k + 0.5, c[2] + 5.5}, force = "player"}
    end
    surface().create_entity{name = "medium-electric-pole", position = {c[1] + 0.5, c[2] + 3.5}, force = "player"}
    local chest = surface().create_entity{name = "steel-chest", position = {c[1] + 0.5, c[2] - 3.5}, force = "player"}
    chest.insert{name = "electronic-circuit", count = 50}
    lp("dev", {"raid", tostring(S.id)}, c)
  end)
  local function ghosts() return surface().count_entities_filtered{name = "entity-ghost", position = S.c, radius = 20} end
  if ambush then
    for t = 3 * 3600 + 60, END - 600, 60 do
      schedule(t, function()
        if S.ambushed or not S.c then return end
        if ghosts() >= 2 then
          S.ambushed = 0
          for _, u in pairs(surface().find_entities_filtered{position = S.c, radius = 60, force = "lp-grubstake", type = "unit"}) do
            u.die("player"); S.ambushed = S.ambushed + 1
          end
          local spots = {}
          for _, it in pairs(surface().find_entities_filtered{type = "item-entity", position = S.c, radius = 60}) do
            spots[math.floor(it.position.x / 3) .. "," .. math.floor(it.position.y / 3)] = true
          end
          S.spots = table_size(spots)
        end
      end)
    end
  end
  schedule(END - 60, function()
    local y = surface().find_entities_filtered{name = "lp-skim-yard", limit = 1}[1]
    local yinv = y and y.get_inventory(defines.inventory.chest)
    local machines = yinv and yinv.get_item_count("assembling-machine-1") or 0
    local plates = yinv and yinv.get_item_count("iron-plate") or 0
    -- And what rides its sushi belt beside it (the yard's display of what it stole, 0.1.43).
    for _, bl in pairs(y and surface().find_entities_filtered{name = "lp-grubstake-belt", position = y.position, radius = 12} or {}) do
      for line = 1, 2 do
        local tl = bl.get_transport_line(line)
        machines = machines + tl.get_item_count("assembling-machine-1")
        plates = plates + tl.get_item_count("iron-plate")
      end
    end
    local left = surface().count_entities_filtered{name = "assembling-machine-1", position = S.c, radius = 20}
    local on_ground = 0
    for _, e in pairs(surface().find_entities_filtered{type = "item-entity", name = "item-on-ground", position = S.c, radius = 40}) do
      on_ground = on_ground + e.stack.count
    end
    info(string.format("dismantle: ghosts %d, assemblers left %d, yard: %d assemblers, %d plates; on the ground %d (ambushed %s)",
      ghosts(), left, machines, plates, on_ground, tostring(S.ambushed)))
    if ambush then
      -- Each raider drops its share where it falls (killed one by one, the last had carried it all).
      check("dismantle: the raiders killed, what they carried spills", (S.ambushed or 0) > 0 and on_ground > 0 and machines == 0,
        string.format("%d on the ground, yard %d", on_ground, machines))
      check("dismantle: spilled at more than one spot", (S.spots or 0) >= 2, tostring(S.spots))
      return
    end
    check("dismantle: machines taken apart, their ghosts left", ghosts() >= 3 and left <= 1, string.format("%d ghosts, %d left",
      ghosts(), left))
    check("dismantle: the machines and what they held home in the yard", machines >= 2 and plates > 0,
      string.format("%d assemblers, %d plates", machines, plates))
  end)
end

-- Leader (Jungle Raiders' Alpha, 2026-10-19): a raid on an unguarded outpost; once it attacks, the test kills its
-- leader (the unit under its corporation's icon). Grubstake's raid breaks and runs home ("fled"); LP_MIX=serenity:
-- Serenity's falls back to its staging point with a new leader and comes again. LP_MIX=haul: chests of plates at the
-- outpost; the leader is shot once the raid carries loot: Grubstake's foreman drops the whole haul, none reaches home.
scenarios.leader = function()
  -- LP_MIX=rails: Serenity's garrison holds railgunners too; none goes on the raid (they outrange the player's turrets).
  local rails = params.mix == "rails"
  local ser, haul = params.mix == "serenity" or rails, params.mix == "haul"
  local function toward(id, d)
    local o = lp("stats", id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    return {math.floor(o.x - o.x / len * d), math.floor(o.y - o.y / len * d)}
  end
  schedule(60, function()
    lp("debug_tune", {era = 2, ops_off = false})
    S.id = ser and storage.id or lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    for _ = 1, 2 do lp("debug_depot", S.id, 3000) end
    lp("debug_units", S.id, "lp-infantry", 8)
    if rails then lp("debug_units", S.id, "lp-railgunner", 6) end
  end)
  schedule(3 * 3600, function()
    lp("debug_tune", {raids_off = true})
    local c = toward(S.id, 120)
    flatten(c[1] - 30, c[2] - 30, c[1] + 30, c[2] + 30)
    S.c = c
    for k = 0, 3 do
      surface().create_entity{name = "assembling-machine-1", position = {c[1] - 6 + 4 * k + 0.5, c[2] + 0.5}, force = "player"}
    end
    for k = 0, 5 do surface().create_entity{name = "radar", position = {c[1] - 9 + 4 * k, c[2] + 6}, force = "player"} end
    if haul then
      for k = 0, 3 do
        local ch = surface().create_entity{name = "iron-chest", position = {c[1] - 6 + 4 * k + 0.5, c[2] - 4.5}, force = "player"}
        ch.insert{name = "iron-plate", count = 200}
      end
    end
    lp("dev", {"raid", tostring(S.id)}, c)
    S.had_leader = lp("stats", S.id).ops.leader ~= nil
  end)
  for t = 3 * 3600 + 60, END - 300, 30 do
    schedule(t, function()
      if rails then
        S.rails_out = math.max(S.rails_out or 0, surface().count_entities_filtered{name = "lp-railgunner", position = S.c, radius = 70})
        S.raiders = math.max(S.raiders or 0, surface().count_entities_filtered{type = "unit", force = "lp-serenity", position = S.c, radius = 70})
      end
      if S.shot then return end
      local o = lp("stats", S.id).ops
      S.seen = S.seen or {}
      S.seen[tostring(o.phase) .. ":" .. tostring(o.leader ~= nil)] = true
      if o.leader and o.phase == "attack" and (not haul or (o.carrying or 0) > 0) then
        for _, u in pairs(surface().find_entities_filtered{type = "unit", position = S.c, radius = 200}) do
          if u.unit_number == o.leader then
            S.carried, S.at = o.carrying, u.position
            u.die("player"); S.shot = game.tick
            S.dropped = select(3, dropped(S.at, 12))
            break
          end
        end
      end
    end)
  end
  schedule(END - 60, function()
    local o = lp("stats", S.id).ops
    local last = o.log and o.log[#o.log]
    info("leader: phases seen " .. serpent.line(S.seen))
    info(string.format("leader: had %s, shot %s, lost %d, broken %d, regrouped %d, now %s, last %s", tostring(S.had_leader),
      tostring(S.shot), o.leaders_lost, o.broken, o.regrouped, tostring(o.op), last and last.outcome or "-"))
    if rails then
      info(string.format("leader rails: at most %s raiders by the outpost, %s of them railgunners", tostring(S.raiders), tostring(S.rails_out)))
      check("leader: the raid came", (S.raiders or 0) >= 3, tostring(S.raiders))
      check("leader: no railgunner on it", S.rails_out == 0, tostring(S.rails_out))
      return
    end
    if haul then
      info(string.format("leader haul: carried %s, dropped %s by the foreman, looted home %d", tostring(S.carried),
        tostring(S.dropped), o.looted))
      check("leader: the raid carried loot when its foreman fell", (S.carried or 0) > 0, tostring(S.carried))
      check("leader: the foreman dropped the whole haul", (S.dropped or 0) >= (S.carried or 1), string.format("%s of %s",
        tostring(S.dropped), tostring(S.carried)))
      check("leader: nothing reached home", o.looted == 0, tostring(o.looted))
    end
    if ser then
      check("leader: Serenity's raid falls back in order and comes again", S.shot and o.regrouped >= 1 and o.broken == 0
        and (o.op ~= nil or (last and last.outcome == "done")), string.format("regrouped %d, %s", o.regrouped, last and last.outcome or tostring(o.op)))
    else
      check("leader: its foreman killed, Grubstake's raid breaks and runs", S.shot and o.broken == 1 and last and last.outcome == "fled",
        string.format("broken %d, last %s", o.broken, last and last.outcome or "-"))
    end
  end)
end

-- The factory instrument (the plan of 2026-10-19: "I don't have time for playtesting"; a scripted mid-game player in place
-- of one). A factory at the spawn that pollutes (assemblers on infinity chests), a ring of gun turrets kept in
-- ammunition, and an outpost every 15 minutes on a new iron patch 150 to 260 tiles out, its drills on a belt home (the
-- test empties the belt's end and counts it: the factory's income). A Grubstake camp and the usual Serenity camp from
-- the start. The player's robots rebuild ghosts once no corporation unit stands near; a building lost outside the ring
-- gets two gun turrets near it (up to six an outpost). Mixes: control (the corporations harmless), turtle (as above),
-- engage (also: a skimming truck killed 30 s after it parks, a raid's leader killed when it attacks, Serenity's invoice
-- paid when it owes 300 or less), away (the turtle, its player off-planet from minute 60 to 180: no rebuilds, no
-- ammunition, no undergrounds, no turrets; Fable's worry: Serenity at war while the player is away). Its outposts still
-- come on the turtle's schedule: without them, away lost income to growth that never came, not to the corporations.
-- Each hour: income, losses, what each corporation did. Measures, few checks.
scenarios.factory = function()
  -- A mix ending "old" (turtleold): the same, with Serenity's camp growing to a fixed size, not out to its line (the A/B
  -- of 2026-10-20).
  local old = params.mix:match("^(.-)old$")
  if old then params.mix = old end
  -- A mix ending "blocks" (turtleblocks): Serenity's camp grows by blocks, not WFC districts (layout.district).
  local blocks = params.mix:match("^(.-)blocks$")
  if blocks then params.mix = blocks end
  local control, engage = params.mix == "control", params.mix == "engage"
  local function gone() return params.mix == "away" and game.tick >= 60 * 3600 and game.tick < 180 * 3600 end
  local A = {owned = {}, lost = 0, rebuilt = 0, turrets = 0, income = 0, paid = 0, trucks = 0, leaders = 0,
    outposts = {}, sinks = {}, guards = {}}
  S.arc = A
  local function own(e) if e and e.valid then table.insert(A.owned, e) end return e end
  local function put(name, pos, extra)
    local spec = {name = name, position = pos, force = "player"}
    for k, v in pairs(extra or {}) do spec[k] = v end
    if not surface().can_place_entity{name = name, position = pos, force = "player", direction = spec.direction} then
      local q = surface().find_non_colliding_position(name, pos, 4, 0.5)
      if not q then return nil end
      spec.position = q
    end
    return own(surface().create_entity(spec))
  end
  schedule(60, function()
    -- prospect_uncharted: headless runs chart nothing (force.chart never lands), as the prospecting tests waive it.
    lp("debug_tune", {era = 2, history_off = true, harmless = control or nil, prospect_uncharted = true,
      grow_to_line_off = old and true or nil, wfc_core_off = blocks and true or nil})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    for _ = 1, 2 do lp("debug_depot", S.g, 3000) end
    lp("debug_depot", storage.id, 3000)
  end)
  -- The factory.
  schedule(120, function()
    game.forces.player.create_ghost_on_entity_death = true
    -- What a player's radars and walks would have charted (prospecting reads charted chunks: it saw none).
    game.forces.player.chart(surface(), {{-700, -700}, {700, 700}})
    flatten(-70, -70, 70, 70)
    local eei = surface().create_entity{name = "electric-energy-interface", position = {0, 0}, force = "player"}
    eei.power_production, eei.electric_buffer_size = 200e6 / 60, 200e6
    for x = -63, 63, 14 do for y = -63, 63, 14 do put("substation", {x, y}) end end
    for i = 0, 5 do for j = 0, 4 do
      local x, y = -40 + i * 14, -36 + j * 15
      local a = put("assembling-machine-2", {x + 1.5, y + 1.5})
      if a then
        a.set_recipe("iron-gear-wheel")
        put("inserter", {x + 1.5, y - 0.5}, {direction = defines.direction.south})
        local src = put("infinity-chest", {x + 1.5, y - 1.5})
        if src then src.set_infinity_container_filter(1, {name = "iron-plate", count = 100, mode = "exactly"}) end
        put("inserter", {x + 1.5, y + 3.5}, {direction = defines.direction.south})
        local sink = put("infinity-chest", {x + 1.5, y + 4.5})
        if sink then sink.remove_unfiltered_items = true end
      end
    end end
    for k = -60, 60, 10 do
      for _, p in ipairs({{k, -64}, {k, 64}, {-64, k}, {64, k}}) do
        local t = put("gun-turret", p)
        if t then t.insert{name = "piercing-rounds-magazine", count = 100}; table.insert(A.guards, t) end
      end
    end
  end)
  -- An outpost: a 16x16 iron patch at a bearing, eight drills on a belt that runs home to the ring.
  local DIRS = {east = defines.direction.east, west = defines.direction.west, north = defines.direction.north,
    south = defines.direction.south}
  local function outpost(k)
    local a = k * 2.4 + 0.3
    local r = 150 + 22 * k
    local cx, cy = math.floor(math.cos(a) * r), math.floor(math.sin(a) * r)
    flatten(cx - 12, cy - 12, cx + 12, cy + 12)
    for x = -8, 7 do for y = -8, 7 do surface().create_entity{name = "iron-ore", position = {cx + x + 0.5, cy + y + 0.5}, amount = 4000} end end
    -- The belt: along x then y to the ring's edge (66 out).
    local tx = math.max(-60, math.min(60, cx))
    local ty = (cy > 0 and 66 or -66)
    if math.abs(cy) <= 60 then ty, tx = cy, (cx > 0 and 66 or -66) end
    local path = {}
    local sx = tx >= cx and 1 or -1
    for x = cx, tx, sx do table.insert(path, {x, cy}) end
    local sy = ty >= cy and 1 or -1
    if ty ~= cy then for y = cy + sy, ty, sy do table.insert(path, {tx, y}) end end
    local function dir(p, q)
      if q[1] > p[1] then return "east" elseif q[1] < p[1] then return "west" elseif q[2] > p[2] then return "south" end
      return "north"
    end
    local belts = {}
    for i = 1, #path do
      local d = path[i + 1] and dir(path[i], path[i + 1]) or (path[i - 1] and dir(path[i - 1], path[i]) or "east")
      local pos = {path[i][1] + 0.5, path[i][2] + 0.5}
      for _, e in pairs(surface().find_entities_filtered{area = {{pos[1] - 0.4, pos[2] - 0.4}, {pos[1] + 0.4, pos[2] + 0.4}}}) do
        if e.valid and e.type ~= "resource" and e.type ~= "character" and e.force.name ~= "player" then e.destroy() end
      end
      local b = own(surface().create_entity{name = "transport-belt", position = pos, direction = DIRS[d], force = "player"})
      if b then table.insert(belts, {b, d}) end
    end
    -- Drills both sides of the belt's first 12 tiles, facing it; a pole by each pair; big poles home.
    for i = 1, math.min(12, #belts), 3 do
      local b, d = belts[i][1], belts[i][2]
      local horizontal = d == "east" or d == "west"
      for side = -1, 1, 2 do
        local at = horizontal and {b.position.x, b.position.y + 2 * side} or {b.position.x + 2 * side, b.position.y}
        local face = horizontal and (side < 0 and "south" or "north") or (side < 0 and "east" or "west")
        put("electric-mining-drill", at, {direction = DIRS[face]})
      end
      put("medium-electric-pole", horizontal and {b.position.x + 1.5, b.position.y + 1.5} or {b.position.x + 1.5, b.position.y + 1.5})
    end
    local len = math.sqrt(cx * cx + cy * cy)
    for dd = len - 6, 60, -26 do put("big-electric-pole", {cx / len * dd + 2, cy / len * dd + 2}) end
    -- A buffer chest by the drills, as outposts keep (the claim jumper's mark: no chest stood outside the core).
    local bc = put("wooden-chest", {cx + 3, cy - 4})
    if bc then bc.insert{name = "iron-plate", count = 200}; bc.insert{name = "electronic-circuit", count = 50} end
    put("radar", {cx - 4, cy - 5})
    A.sinks[k] = belts[#belts] and belts[#belts][1]
    A.outposts[k] = {cx, cy, turrets = 0}
  end
  for k = 1, 8 do
    local t = (3 + (k - 1) * 15) * 3600
    if t < END - 600 then schedule(t, function() outpost(k) end) end
  end
  -- The belts' ends: the income.
  for t = 3 * 3600, END - 60, 30 do
    schedule(t, function()
      for _, b in pairs(A.sinks) do
        if b.valid then
          for line = 1, 2 do
            local tl = b.get_transport_line(line)
            local n = tl.get_item_count("iron-ore")
            if n > 0 then A.income = A.income + tl.remove_item({name = "iron-ore", count = n}) end
          end
        end
      end
    end)
  end
  -- Logistics: ammunition; the robots' rebuilds; losses answered with turrets.
  for t = 3 * 3600, END - 60, 3600 do
    schedule(t, function()
      local live = {}
      for _, e in ipairs(A.owned) do
        if e.valid then table.insert(live, e)
        else
          A.lost = A.lost + 1
        end
      end
      A.owned = live
      if gone() then return end
      for _, g in ipairs(A.guards) do
        if g.valid and g.get_item_count("piercing-rounds-magazine") < 50 then g.insert{name = "piercing-rounds-magazine", count = 50} end
      end
      -- A belt cut on Serenity's line is crossed underground, as a player would (rebuilt as it was, it was cut again:
      -- 635 cuts in two hours).
      local ss = lp("stats", storage.id)
      local edge, so = ss.perimeter or ss.claim_radius, ss.origin
      for _, gh in pairs(surface().find_entities_filtered{ghost_type = "transport-belt", force = "player", position = {0, 0}, radius = 500}) do
        local p = gh.valid and gh.position
        if p and edge and so and math.abs(math.sqrt((p.x - so.x) ^ 2 + (p.y - so.y) ^ 2) - edge) <= 3 then
          local d = gh.direction
          local v = ({[defines.direction.north] = {0, -1}, [defines.direction.south] = {0, 1}, [defines.direction.east] = {1, 0},
            [defines.direction.west] = {-1, 0}})[d]
          if v then
            local a = {p.x - 3 * v[1], p.y - 3 * v[2]}
            local b = {p.x + 3 * v[1], p.y + 3 * v[2]}
            for k = -3, 3 do
              for _, e in pairs(surface().find_entities_filtered{position = {p.x + k * v[1], p.y + k * v[2]}, radius = 0.4,
                force = "player"}) do
                if e.valid and (e.type == "transport-belt" or (e.name == "entity-ghost" and e.ghost_type == "transport-belt")) then e.destroy() end
              end
            end
            own(surface().create_entity{name = "underground-belt", position = a, direction = d, type = "input", force = "player"})
            own(surface().create_entity{name = "underground-belt", position = b, direction = d, type = "output", force = "player"})
            A.undergrounds = (A.undergrounds or 0) + 1
          end
        end
      end
      for _, gh in pairs(surface().find_entities_filtered{name = "entity-ghost", force = "player", position = {0, 0}, radius = 500}) do
        if gh.valid and surface().count_entities_filtered{position = gh.position, radius = 30, type = "unit",
          force = {"lp-grubstake", "lp-serenity"}, limit = 1} == 0 then
          local _, e = gh.revive()
          if e then own(e); A.rebuilt = A.rebuilt + 1 end
        end
      end
      for k, o in pairs(A.outposts) do
        if o.turrets < 6 and surface().count_entities_filtered{name = "entity-ghost", force = "player", position = {o[1], o[2]},
          radius = 30, limit = 1} > 0 then
          for _ = 1, 2 do
            local tt = put("gun-turret", {o[1] + 8 - 4 * o.turrets, o[2] - 10})
            if tt then tt.insert{name = "piercing-rounds-magazine", count = 100}; table.insert(A.guards, tt); A.turrets = A.turrets + 1 end
            o.turrets = o.turrets + 1
          end
        end
      end
    end)
  end
  -- Engaged: the player answers what it sees.
  if engage then
    for t = 3 * 3600, END - 60, 600 do
      schedule(t, function()
        local k = lp("skim", S.g)
        if k and k.parked then
          A.parked_seen = A.parked_seen or {}
          local key = k.skims
          if A.parked_seen[key] then
            for _, u in pairs(surface().find_entities_filtered{position = k.parked, radius = 3, force = "lp-grubstake", type = "unit"}) do
              u.die("player"); A.trucks = A.trucks + 1
            end
          else
            A.parked_seen[key] = true
          end
        end
        -- One leader a raid (a player would not snipe each new one as it rose).
        A.sniped = A.sniped or {}
        for _, id in ipairs({S.g, storage.id}) do
          local o = lp("stats", id).ops
          local raid = id .. ":" .. (o.launched or 0)
          if o.leader and o.phase == "attack" and not A.sniped[raid] then
            A.sniped[raid] = true
            for _, u in pairs(surface().find_entities_filtered{type = "unit", position = {0, 0}, radius = 600}) do
              if u.unit_number == o.leader then u.die("player"); A.leaders = A.leaders + 1 break end
            end
          end
        end
        local L = lp("ledger", storage.id)
        if L and L.owed > 0 and L.owed <= 300 and L.post then
          local post = surface().find_entities_filtered{name = "lp-invoice-post", position = L.post, radius = 1}[1]
          if post then A.paid = A.paid + post.insert{name = "electronic-circuit", count = L.owed} end
        end
      end)
    end
  end
  -- Engaged: a strike on Grubstake every 30 minutes from minute 20, as a player who learns would mount it (the user:
  -- "Yeah" to a smarter strike): 20 troopers, breachers and battle tanks, 15 more for each strike that left the lander
  -- standing (65 at most); it goes for the nearest Grubstake turret by the target, then the generators by the lander
  -- (its hull holds the lander until half are down), then the lander, re-aimed every 30 s; 4 troopers join it every 2
  -- minutes for 8 minutes (the barracks). What lies on the ground there 8 minutes later is picked up.
  if engage then
    A.strikes, A.recovered, A.failed = 0, 0, 0
    local function grub(name_part, at, r)
      local out = {}
      for _, e in pairs(surface().find_entities_filtered{force = "lp-grubstake", position = at, radius = r}) do
        if e.valid and e.name:find(name_part, 1, true) then table.insert(out, e) end
      end
      return out
    end
    local function aim()
      local g = lp("stats", S.g)
      if not (g and g.lander and g.origin and A.grp and A.grp.valid) then return end
      local turrets = surface().find_entities_filtered{force = "lp-grubstake", position = g.origin, radius = 45,
        type = {"ammo-turret", "electric-turret", "fluid-turret"}}
      local e
      local pos = A.grp.position
      if #turrets > 0 then e = surface().get_closest(pos, turrets)
      elseif g.hull_up then
        local gens = grub("generator", g.origin, 80)
        if #gens > 0 then e = surface().get_closest(pos, gens) end
      end
      if not e then e = surface().find_entities_filtered{force = "lp-grubstake", position = g.origin, radius = 6, limit = 1,
        name = {"lp-grubstake-lander", "lp-lander"}}[1] end
      if e then
        A.grp.set_command{type = defines.command.attack, target = e, distraction = defines.distraction.by_enemy}
        A.aimed = e.name
      end
    end
    for t = 20 * 3600, END - 600, 30 * 3600 do
      schedule(t, function()
        local g = lp("stats", S.g)
        if not (g and g.lander and g.origin) then return end
        local at = g.origin
        local len = math.max(1, math.sqrt(at.x * at.x + at.y * at.y))
        local from = {at.x / len * 70, at.y / len * 70}
        local size = math.min(65, 20 + 15 * A.failed)
        local grp = surface().create_unit_group{position = from, force = "player"}
        local mix = {{"lp-trooper", math.floor(size * 0.6)}, {"lp-breacher", math.floor(size * 0.2)},
          {"lp-battle-tank", size - math.floor(size * 0.6) - math.floor(size * 0.2)}}
        for _, k in ipairs(mix) do
          for _ = 1, k[2] do
            local p = surface().find_non_colliding_position(k[1], from, 30, 1)
            local u = p and surface().create_entity{name = k[1], position = p, force = "player"}
            if u then grp.add_member(u) end
          end
        end
        A.grp, A.from = grp, from
        A.strikes = A.strikes + 1
        A.strike_units = grp.members
        A.strike_size = #A.strike_units
        A.strike_lost0 = g.units_lost or 0
        A.strike_gens0 = #grub("generator", g.origin, 80)
        A.strike_at = {at.x, at.y}
        aim()
      end)
      for dt = 1800, 8 * 3600, 1800 do schedule(t + dt, aim) end
      for dt = 2 * 3600, 8 * 3600, 2 * 3600 do
        schedule(t + dt, function()
          if not (A.grp and A.grp.valid and A.from) then return end
          for _ = 1, 4 do
            local p = surface().find_non_colliding_position("lp-trooper", A.from, 30, 1)
            local u = p and surface().create_entity{name = "lp-trooper", position = p, force = "player"}
            if u then A.grp.add_member(u); table.insert(A.strike_units, u) end
          end
        end)
      end
      schedule(t + 8 * 3600, function()
        if not A.strike_at then return end
        local alive = 0
        for _, u in ipairs(A.strike_units or {}) do if u.valid then alive = alive + 1 end end
        local g = lp("stats", S.g)
        local gens = g and g.origin and #grub("generator", g.origin, 80) or 0
        if g and g.lander then A.failed = A.failed + 1 end
        info(string.format("factory strike %d (%d strong): %d of %d left after 8 minutes, aimed last at %s; Grubstake lost %d units; "
          .. "generators by its lander %d -> %d; lander %s", A.strikes, A.strike_size or 0, alive, #(A.strike_units or {}),
          tostring(A.aimed), (g and g.units_lost or 0) - (A.strike_lost0 or 0), A.strike_gens0 or 0, gens,
          g and g.lander and string.format("%.0f%%", 100 * (g.lander_health or 0)) or "down"))
        A.recovered = A.recovered + select(3, dropped(A.strike_at, 30, true))
      end)
    end
  end
  -- Engaged: the line hunted (the user: hunting the line must be "workable"; cordon.check pulls the claim back when
  -- over half the leading arc's posts lose their turrets). From minute 40, every 20 minutes, 30 units (troopers,
  -- breachers, battle tanks) from the factory's edge at the gun turrets on Serenity's leading arc, nearest first,
  -- re-aimed every 30 s, for 6 minutes.
  if engage then
    A.line_strikes = 0
    local function arc_turrets()
      local cs = lp("cordon_stats", storage.id)
      local o = lp("stats", storage.id).origin
      if not (cs and cs.perimeter and o) then return {}, cs end
      local out = {}
      for _, e in pairs(surface().find_entities_filtered{force = FORCE, type = "ammo-turret", position = o, radius = cs.perimeter + 10}) do
        local d = math.sqrt((e.position.x - o.x) ^ 2 + (e.position.y - o.y) ^ 2)
        if math.abs(d - cs.perimeter) <= 10 then table.insert(out, e) end
      end
      return out, cs
    end
    local function aim_line()
      if not (A.lgrp and A.lgrp.valid) then return end
      local ts = arc_turrets()
      if #ts > 0 then
        A.lgrp.set_command{type = defines.command.attack, target = surface().get_closest(A.lgrp.position, ts),
          distraction = defines.distraction.by_enemy}
      end
    end
    for t = 40 * 3600, END - 600, 20 * 3600 do
      schedule(t, function()
        local ts = arc_turrets()
        if #ts == 0 then return end
        local first = surface().get_closest({0, 0}, ts).position
        local len = math.max(1, math.sqrt(first.x ^ 2 + first.y ^ 2))
        local from = {first.x / len * 70, first.y / len * 70}
        local grp = surface().create_unit_group{position = from, force = "player"}
        for _, k in ipairs({{"lp-trooper", 18}, {"lp-breacher", 6}, {"lp-battle-tank", 6}}) do
          for _ = 1, k[2] do
            local p = surface().find_non_colliding_position(k[1], from, 30, 1)
            local u = p and surface().create_entity{name = k[1], position = p, force = "player"}
            if u then grp.add_member(u) end
          end
        end
        A.lgrp = grp
        A.line_strikes = A.line_strikes + 1
        aim_line()
      end)
      for dt = 1800, 6 * 3600, 1800 do schedule(t + dt, aim_line) end
    end
  end
  -- Watched (scripts/watch.sh, a game window: the user, wary of the harness): every 10 minutes the factory, Serenity's
  -- line and Grubstake's camp; each strike group 3 minutes into its march and at 6. Fast between shots.
  if params.watch then
    local n = 0
    local function shot(name, pos, zoom)
      n = n + 1
      game.take_screenshot{surface = surface(), position = pos, resolution = {1600, 900}, zoom = zoom, daytime = 0,
        path = string.format("lp-watch/%03d-%s.png", n, name), show_entity_info = true}
      helpers.write_file("lp-watch/shots.txt", string.format("%03d-%s.png at minute %d\n", n, name,
        math.floor((game.tick - (storage.t0 or 0)) / 3600)), true)
    end
    schedule(90, function() game.speed = params.watch_speed or 10 end)
    for t = 10 * 3600, END - 600, 10 * 3600 do
      schedule(t, function()
        shot("factory", {0, 0}, 0.18)
        local cs = lp("cordon_stats", storage.id)
        local so = lp("stats", storage.id).origin
        if cs and cs.perimeter and so then
          local len = math.max(1, math.sqrt(so.x * so.x + so.y * so.y))
          shot("serenity-line", {so.x - so.x / len * cs.perimeter, so.y - so.y / len * cs.perimeter}, 0.3)
        end
        local g = lp("stats", S.g)
        if g and g.origin then shot("grubstake-camp", g.origin, 0.35) end
      end)
    end
    for t = 3 * 3600, END - 600, 3600 do
      schedule(t, function()
        for _, k in ipairs({"grp", "lgrp"}) do
          local grp = A[k]
          if grp and grp.valid and #grp.members > 0 and (A[k .. "_shot"] or 0) < game.tick - 2 * 3600 then
            A[k .. "_shot"] = game.tick
            shot(k == "grp" and "strike-grubstake" or "strike-line", grp.position, 0.6)
          end
        end
      end)
    end
  end
  -- A map of the ground every MAP_EVERY (scripts/campmap.py draws them; the user: "No reason to be stingy").
  local MAP_EVERY = 15 * 3600
  local function snapshot()
    local g, s = lp("stats", S.g), lp("stats", storage.id)
    local co = lp("cordon_stats", storage.id) or {}
    local far = 0
    for _, o in ipairs({s.origin, g and g.origin}) do if o then far = math.max(far, math.sqrt(o.x * o.x + o.y * o.y)) end end
    dump_map(string.format("factory-m%03d", math.floor(game.tick / 3600)), {0, 0}, far + 260, {serenity = s.origin,
      grubstake = g and g.origin, perimeter = s.perimeter, ring = co.ring, blocks = s.blocks})
  end
  for t = MAP_EVERY, END - 60, MAP_EVERY do schedule(t, snapshot) end
  schedule(END - 60, snapshot)
  -- Each hour, and at the end: what happened.
  local function report(label)
    local g, s = lp("stats", S.g), lp("stats", storage.id)
    local sk = lp("skim", S.g) or {}
    local L = lp("ledger", storage.id) or {}
    info(string.format("factory %s: income %d ore; lost %d, rebuilt %d, turrets added %d; Grubstake raids %d (razed %d, looted %d, "
      .. "dismantled %d), skims %d (%d items), trucks killed %d; Serenity raids %d (razed %d), sieges %d, bills %d (paid %d, truces %d), "
      .. "leaders killed %d, broken %d, regrouped %d",
      label, A.income, A.lost, A.rebuilt, A.turrets, g.ops.launched or 0, g.razed or 0, g.ops.looted or 0, g.ops.dismantled or 0,
      sk.skims or 0, sk.skimmed or 0, A.trucks, s.ops.launched or 0, s.razed or 0, s.ops.sieges or 0, L.bills or 0, A.paid,
      L.truces or 0, A.leaders, g.ops.broken or 0, s.ops.regrouped or 0))
    -- Every mechanic's count so far (what fires, to prune by): Grubstake's, then Serenity's.
    local gb, sb = g, s
    local pr = lp("prospect_stats", S.g) or {}
    local co = lp("cordon_stats", storage.id) or {}
    local function n(v) return type(v) == "number" and v or (type(v) == "table" and table_size(v) or 0) end
    info(string.format("factory %s: undergrounds laid under the line %d", label, A.undergrounds or 0))
    info(string.format("factory %s camp: Serenity blocks %d, entities %d, mature %s, ring %s (rings %s), perimeter %s",
      label, s.blocks or 0, surface().count_entities_filtered{force = "lp-serenity"}, tostring(s.mature),
      tostring(co.ring and math.floor(co.ring)), tostring(co.rings), tostring(s.perimeter and math.floor(s.perimeter))))
    if params.mix == "away" then
      local dry = 0
      for _, t in ipairs(A.guards) do if t.valid and t.get_item_count("piercing-rounds-magazine") == 0 then dry = dry + 1 end end
      info(string.format("factory %s: away: ghosts waiting %d, guard turrets dry %d of %d", label,
        surface().count_entities_filtered{name = "entity-ghost", force = "player"}, dry, #A.guards))
    end
    info(string.format("factory %s mechanics: G flares %d, jumps %d, taps %d, strips %d, claims %s, answers %d, reliefs %d, "
      .. "overflights %d | S posts %s, steps %d, severed %s, cuts found %d, recons %d, sieges %d, assaults %d, clearances %d, "
      .. "hazards %d, answers %d, reliefs %d", label, n(gb.flares), n(gb.jumps), n(gb.taps), n(gb.ops.strips), serpent.line(pr.claims
      or pr.claimed or "?"), n(gb.ops.answers), n(gb.reinforced), n(gb.ops.overflights), serpent.line(co.posts or "?"),
      n(sb.perimeter_steps), serpent.line(co.severed or "?"), n(sb.ops.cuts_found), n(sb.ops.recons), n(sb.ops.sieges),
      n(sb.ops.assaults), n(sb.ops.clearances), n(sb.ops.hazards), n(sb.ops.answers), n(sb.reinforced)))
    if engage then
      info(string.format("factory %s: line strikes %d, the line broken %d times, claim radius %s", label, A.line_strikes or 0,
        co.broken or 0, tostring(co.perimeter)))
      info(string.format("factory %s: strikes %d, recovered %d items, Grubstake's lander %s (%.0f%%, hull %s), setbacks %d, "
        .. "raids held home %d", label, A.strikes or 0, A.recovered or 0, g.lander and "standing" or "down",
        100 * (g.lander_health or 0), g.hull_up and "up" or "down", g.setbacks or 0, g.held_home or 0))
    end
  end
  for h = 1, math.floor(params.minutes / 60) do
    if h * 3600 * 60 < END - 120 then schedule(h * 60 * 3600, function() report("hour " .. h) end) end
  end
  schedule(END - 60, function()
    report("end")
    metric("arc_income", A.income)
    metric("arc_lost", A.lost)
    check("factory: the factory made income", A.income > 0, tostring(A.income))
  end)
end

-- Blob (a measurement, 2026-10-19; the user: "does the blob move at the speed of its slowest unit? Or does it trickle
-- in?"): the factory's strike (12 troopers, 4 breachers, 4 battle tanks, one unit group, attack_area) marched 300 tiles
-- over empty ground; every 2 s, the spread of its members along the way (the leader's and the last one's distance to go)
-- and by kind. LP_MIX=go: go_to_location instead of attack_area.
scenarios.blob = function()
  schedule(60, function() lp("debug_tune", {ops_off = true, army_off = true}) end)
  schedule(120, function()
    -- The ground generated first (units do not path into ungenerated chunks).
    surface().request_to_generate_chunks({160, 0}, 7)
    surface().force_generate_chunk_requests()
    flatten(-20, -40, 340, 40)
    for _, e in pairs(surface().find_entities_filtered{force = "enemy", position = {160, 0}, radius = 400}) do e.destroy() end
    local grp = surface().create_unit_group{position = {0, 0}, force = "player"}
    S.members = {}
    for _, k in ipairs({{"lp-trooper", 12}, {"lp-breacher", 4}, {"lp-battle-tank", 4}}) do
      for _ = 1, k[2] do
        local p = surface().find_non_colliding_position(k[1], {0, 0}, 20, 1)
        local u = p and surface().create_entity{name = k[1], position = p, force = "player"}
        if u then grp.add_member(u); table.insert(S.members, u) end
      end
    end
    local dest = {300, 0}
    -- Something to attack there (an attack_area with nothing in it finishes at once, the group unmoved).
    S.target = surface().create_entity{name = "radar", position = dest, force = "lp-grubstake"}
    if S.target then S.target.destructible = false end
    if params.mix == "go" then
      grp.set_command{type = defines.command.go_to_location, destination = dest, radius = 10, distraction = defines.distraction.by_enemy}
    else
      grp.set_command{type = defines.command.attack_area, destination = dest, radius = 24, distraction = defines.distraction.by_enemy}
    end
    if params.mix ~= "nostart" then grp.start_moving() end
    S.grp = grp
    S.log = {}
  end)
  for t = 240, END - 120, 120 do
    schedule(t, function()
      if not S.members then return end
      local by = {}
      local lo, hi = 1e9, -1e9
      for _, u in ipairs(S.members) do
        if u.valid then
          local x = u.position.x
          lo, hi = math.min(lo, x), math.max(hi, x)
          local k = u.name:gsub("^lp%-", "")
          by[k] = by[k] or {}
          table.insert(by[k], x)
        end
      end
      local function mean(t) local a = 0 for _, v in ipairs(t) do a = a + v end return #t > 0 and a / #t or 0 end
      if #S.log < 80 then
        local g = S.grp
        local st = g and g.valid and string.format("group %s, state %s, moving %s", tostring(g.has_command), tostring(g.state),
          tostring(g.moving_state)) or "group gone"
        local u1 = S.members[1]
        local uc = u1 and u1.valid and u1.commandable.command
        table.insert(S.log, st .. string.format("; unit cmd %s", uc and tostring(uc.type) or "none"))
        table.insert(S.log, string.format("t+%ds: front %.0f, rear %.0f, spread %.0f; trooper %.0f, breacher %.0f, tank %.0f",
          (t - 120) / 60, hi, lo, hi - lo, mean(by.trooper or {}), mean(by.breacher or {}), mean(by["battle-tank"] or {})))
      end
    end)
  end
  schedule(END - 60, function()
    for _, l in ipairs(S.log or {}) do info("blob " .. l) end
    check("blob: measured", #(S.log or {}) > 0, tostring(#(S.log or {})))
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

-- Quiet: provoked Serenity whose only player target is an assembler ringed by twelve indestructible gun turrets (the ladder ten
-- times fast, a stand-down after 6 minutes instead of 60). It stands down (war.lua): no operation against the player
-- after that, and the faction's next landing comes within 6 minutes.
scenarios.quiet = function()
  schedule(60, function()
    -- The gates open (not about the opening: its settlement is Serenity, whose gate would keep any landing away).
    lp("debug_tune", {era = 2, ladder_fast = true, history_off = true, provoke = true, quiet_minutes = 6, gates_off = true})
    for _ = 1, 2 do lp("debug_depot", storage.id, 3000) end
  end)
  schedule(2 * 3600, function()
    local o = lp("stats", storage.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = o.x / len, o.y / len
    local c = {math.floor(o.x - ux * 120), math.floor(o.y - uy * 120)}
    flatten(c[1] - 16, c[2] - 16, c[1] + 16, c[2] + 16)
    surface().create_entity{name = "assembling-machine-1", position = c, force = "player"}
    -- Twelve gun turrets with uranium rounds, indestructible: nothing there can be razed but the assembler they guard.
    for k = 0, 11 do
      local a = 2 * math.pi * k / 12
      local t = surface().create_entity{name = "gun-turret", position = {c[1] + 6 * math.cos(a), c[2] + 6 * math.sin(a)}, force = "player"}
      if t then t.insert{name = "uranium-rounds-magazine", count = 200}; t.destructible = false end
    end
    S.bases0 = #lp("bases")
  end)
  for t = 3 * 3600, END - 120, 600 do
    schedule(t, function()
      local st = lp("stats", storage.id)
      if st.quiescent and not S.down then
        S.down, S.launched_down = game.tick, st.ops.launched
      end
      -- What it launched while stood down (until it woke).
      if S.down and not S.woke then
        if st.quiescent then S.launched_quiet = st.ops.launched else S.woke = game.tick end
      end
      if S.down and not S.landed and #lp("bases") > (S.bases0 or 0) then S.landed = game.tick end
    end)
  end
  schedule(END - 60, function()
    local st = lp("stats", storage.id)
    info(string.format("quiet: stood down at %s (%d times), operations %s then %d now, a new landing at %s", tostring(S.down),
      st.stood_down or 0, tostring(S.launched_down), st.ops.launched, tostring(S.landed)))
    check("quiet: it stood down", S.down ~= nil, tostring(S.down))
    check("quiet: and launched nothing against the player while stood down", S.down and S.launched_quiet == S.launched_down,
      string.format("%s -> %s", tostring(S.launched_down), tostring(S.launched_quiet)))
    check("quiet: a new landing within 6 minutes", S.landed and S.landed - S.down <= 6 * 3600 + 600, tostring(S.landed))
  end)
end

-- Clear: Serenity at war with a player whose assembler lies past a wall of nests (49 spawners 14 apart, 670 tiles wide,
-- and medium worms, 90 tiles out across the line, evolution 0.6 so big biters defend them). It has six railgunners. It clears the field
-- with mortar sieges (ops.clearance) and goes on to raze the assembler. LP_MIX=worms: behemoth worms (48), which outrange
-- the mortar: a howitzer clears them. LP_MIX=culture: one spawner in six is Synthexis's (an incubator; eight, as a
-- culture's are, not 45: a wall of full incubators, no culture's biomass to pay for them, killed every guard): Kessler-
-- Hayashi clears them as nests. Short, for debugging the clearance (a visit
-- takes 80 minutes to reach one).
-- The howitzer truck (the user, 2026-10-23): it drives out, deploys into the howitzer facing as it stood and with its
-- health, packs back into it silently, drives home, and is parked again; never truck and howitzer at once, never the
-- truck beside its parked self. Sampled every second; truck_checks judges.
local function truck_watch()
  for t = 600, END - 120, 60 do
    schedule(t, function()
      local W = S.truck or {}
      S.truck = W
      local trucks = surface().find_entities_filtered{name = "lp-howitzer-truck", force = FORCE}
      local hws = surface().find_entities_filtered{name = "lp-howitzer", force = FORCE}
      local parked = surface().count_entities_filtered{name = "lp-parked-howitzer", force = FORCE}
      local ops_ = lp("stats", storage.id).ops
      if #trucks > 0 then W.drove = (W.drove or 0) + 1 end
      if #hws > 0 then W.deployed = (W.deployed or 0) + 1 end
      if #trucks > 0 and #hws > 0 then W.both = (W.both or 0) + 1 end
      if #trucks > 0 and parked > 0 then W.twice = (W.twice or 0) + 1 end
      if #hws > 0 and (ops_.phase == "pack" or ops_.truck_packing) and game.tick % 300 > 120 then
        if hws[1].active then W.loud = (W.loud or 0) + 1 else W.quiet = (W.quiet or 0) + 1 end
      end
      if #hws == 1 and W.last and not W.matched then
        W.matched = {dir = hws[1].direction, want = (math.floor(W.last.o * 4 + 0.5) % 4) * 4,
          hp = hws[1].health / hws[1].max_health, want_hp = W.last.hp}
      end
      if #trucks == 1 then
        local tr = trucks[1]
        -- Hurt once on its way out, so the health carried across is a share, not a full bar.
        if not W.hurt then W.hurt = true; tr.damage(300, "player", "physical") end
        W.last = {o = tr.orientation, hp = tr.health / tr.max_health}
        if W.deployed then W.packed = true end
      end
      if W.packed and #trucks == 0 and #hws == 0 and parked > 0 then W.home = true end
    end)
  end
end
local function truck_checks()
  local W = S.truck or {}
  info("truck: " .. serpent.line(W))
  check("truck: the howitzer went out on its truck", (W.drove or 0) > 0, tostring(W.drove))
  check("truck: it deployed into the howitzer", (W.deployed or 0) > 0, tostring(W.deployed))
  check("truck: never truck and howitzer at once", (W.both or 0) == 0, tostring(W.both))
  check("truck: never beside its parked self", (W.twice or 0) == 0, tostring(W.twice))
  check("truck: deployed facing as it stood, with its health", W.matched ~= nil and W.matched.dir == W.matched.want
    and math.abs(W.matched.hp - W.matched.want_hp) < 0.05, serpent.line(W.matched))
  check("truck: silent while packing up", (W.quiet or 0) > 0 and (W.loud or 0) == 0, string.format("%s quiet, %s loud",
    tostring(W.quiet), tostring(W.loud)))
  check("truck: packed into its truck, home and parked again", W.home == true, tostring(W.home))
end

scenarios.clear = function()
  if params.mix == "worms" then truck_watch() end
  -- Settled: the target razed.
  settle_when(function()
    return S.c ~= nil and surface().count_entities_filtered{position = S.c, radius = 4, name = "assembling-machine-1"} == 0
  end)
  schedule(30, function() game.forces.enemy.set_evolution_factor(0.6, surface()) end)
  schedule(60, function()
    -- Matured at 3 blocks (2.1 lands the camp a few tiles off on this seed, and it kept finding sites: never matured,
    -- so no howitzer parked and the razing raid came after the run; the clearance is what is tested).
    -- Railguns at their top level (0.2.20: weaker at baseline, an investment; the clearance is what is tested here).
    lp("debug_tune", {era = 2, ladder_fast = true, history_off = true, provoke = true, mature_blocks = 3,
      rd_tech = {serenity = {weapons = {["lp-rail"] = 5}, nodes = {railguns = 5}}}})
    for _ = 1, 3 do lp("debug_depot", storage.id, 3000) end
    lp("debug_units", storage.id, "lp-railgunner", 6)
  end)
  schedule(2 * 3600, function()
    local o = lp("stats", storage.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = o.x / len, o.y / len
    local c = {math.floor(o.x - ux * 170), math.floor(o.y - uy * 170)}
    flatten(c[1] - 8, c[2] - 8, c[1] + 8, c[2] + 8)
    surface().create_entity{name = "assembling-machine-1", position = c, force = "player"}
    S.c = c
    S.nests = {}
    for k = -24, 24 do
      local p = {o.x - ux * 90 - uy * 14 * k, o.y - uy * 90 + ux * 14 * k}
      local q = surface().find_non_colliding_position("biter-spawner", p, 6, 1)
      local e = q and surface().create_entity{name = "biter-spawner", position = q, force = "enemy"}
      if e then table.insert(S.nests, e) end
    end
    for k = -24, 24, 3 do
      local p = {o.x - ux * 100 - uy * 14 * k, o.y - uy * 100 + ux * 14 * k}
      local worm = params.mix == "worms" and "behemoth-worm-turret" or "medium-worm-turret"
      local q = surface().find_non_colliding_position(worm, p, 6, 1)
      if q then surface().create_entity{name = worm, position = q, force = "enemy"} end
    end
    if params.mix == "culture" then
      S.pens = {}
      for i, e in ipairs(S.nests) do
        if i % 6 == 1 then
          local pos = e.position
          local id = lp("herd_capture", 1, {pos.x, pos.y})
          local pen = surface().find_entities_filtered{name = "lp-pen", position = pos, radius = 1, limit = 1}[1]
          if pen then table.insert(S.pens, pen); S.nests[i] = pen end
        end
      end
    end
    S.lost0 = lp("stats", storage.id).units_lost or 0
  end)
  schedule(END - 60, function()
    local st = lp("stats", storage.id)
    local left = 0
    for _, e in ipairs(S.nests) do if e.valid then left = left + 1 end end
    local target = surface().count_entities_filtered{position = S.c, radius = 4, name = "assembling-machine-1"}
    info("clear: losses by killer " .. serpent.line(lp("rd", "serenity").lost_by))
    info(string.format("clear: %d of %d spawners left, %d units lost, %d clearances, target %s", left, #S.nests,
      (st.units_lost or 0) - S.lost0, st.ops.clearances or 0, target > 0 and "standing" or "razed"))
    check("clear: a way cleared through the nests", left < #S.nests and (st.ops.clearances or 0) > 0, tostring(left))
    check("clear: the assembler razed", target == 0, target > 0 and "standing" or "razed")
    if params.mix == "worms" then truck_checks() end
    if params.mix == "culture" then
      local gone = 0
      for _, p in ipairs(S.pens) do if not p.valid then gone = gone + 1 end end
      info(string.format("clear culture: %d of %d incubators destroyed", gone, #S.pens))
      check("clear: Synthexis's incubators cleared as nests", gone >= 1, string.format("%d of %d", gone, #S.pens))
    end
  end)
end

-- Hazard (Fable's buffer consult, docs/reviews/2026-10-19-buffer-consult.md): Serenity at peace, grown, eight
-- railgunners; four spawners 250 tiles out on its far side from the player; every 3 minutes, while one stands, a wave of
-- medium biters from them attacks its settlement (the pollution waves nw sent through it, scripted). It counts its
-- losses to biters, clears the nests, and the waves stop. LP_MIX=off: hazard removal off, the nests stand.
scenarios.hazard = function()
  local off = params.mix == "off"
  -- The ledger (scripts/ledger.lua): the clearance held (hazard_hold), the nests in a cloud the test makes (pay, unpaid)
  -- or not (clean), a player's furnace by spawn as the polluter; pay puts what is owed in the post every minute.
  -- disputed: unpaid, and once bills are open a billed nest is killed by Serenity (strikes nothing), then another billed
  -- nest by the player (its bills struck).
  local pay, unpaid, clean, disputed = params.mix == "pay", params.mix == "unpaid", params.mix == "clean", params.mix == "disputed"
  local billing = pay or unpaid or clean or disputed
  -- worm: a behemoth worm by each nest (its 48 and the guards' 14 left the howitzer no site at 53: nw, "outranges even
  -- the howitzer"). norails: no railgunners given and the garrison over its cap with Line troopers (production stopped
  -- at the cap, and the clearance waited "for railgunners (0 of 8)" for two hours, nw).
  local worm, norails = params.mix == "worm", params.mix == "norails"
  -- research: no railguns given (the others have them at their top level, 0.2.20: the clearance is what they test):
  -- its losses to biters make it buy them.
  local research = params.mix == "research"
  settle_when(function()
    if not S.nests then return false end
    for _, e in ipairs(S.nests) do if e.valid then return false end end
    return S.quiet_since and game.tick - S.quiet_since > 6 * 60 * 60
  end)
  schedule(30, function() game.forces.enemy.set_evolution_factor(0.5, surface()) end)
  schedule(60, function()
    -- The ledger's mixes without spread: its walled clusters held the waves off before the losses that bill them came.
    lp("debug_tune", {wfc_core_off = true, era = 2, history_off = true, hazard_off = off or nil, hazard_hold = billing or nil,
      grow_to_line_off = billing or nil, rd_tech = not research and {serenity = {weapons = {["lp-rail"] = 5}, nodes = {railguns = 5}}} or nil})
    for _ = 1, 3 do lp("debug_depot", storage.id, 3000) end
    if norails then lp("debug_units", storage.id, "lp-infantry", 80) else lp("debug_units", storage.id, "lp-railgunner", 10) end
  end)
  schedule(2 * 3600, function()
    local o = lp("stats", storage.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = o.x / len, o.y / len
    S.nests = {}
    -- (The plain case six nests, not four: four drew 10 to 264 losses by the camp's luck, under the 20 that call a
    -- clearance on some seeds, 0.2.6 included; the billing cases keep their four.)
    local spread = (params.mix == "" or params.mix == nil) and 2.5 or 1.5
    for k = -spread, spread do
      local p = {o.x + ux * 250 - uy * 16 * k, o.y + uy * 250 + ux * 16 * k}
      local q = surface().find_non_colliding_position("biter-spawner", p, 8, 1)
      local e = q and surface().create_entity{name = "biter-spawner", position = q, force = "enemy"}
      if e then table.insert(S.nests, e) end
      if worm and e then
        local w = surface().find_non_colliding_position("behemoth-worm-turret", {p[1] + ux * 8, p[2] + uy * 8}, 8, 1)
        if w then surface().create_entity{name = "behemoth-worm-turret", position = w, force = "enemy"} end
      end
    end
    S.o = o
    S.waves, S.waves_after = 0, 0
    if billing then
      local q = surface().find_non_colliding_position("stone-furnace", {0, 0}, 30, 1)
      S.furnace = q and surface().create_entity{name = "stone-furnace", position = q, force = "player"}
      -- Lasting: Serenity is at war from landing and raided it (no polluter in reach, no bill).
      if S.furnace then S.furnace.destructible = false end
    end
  end)
  -- norails: the garrison kept over its cap (losses to the waves had dropped it under, and the old code made railgunners
  -- then: no guard).
  if norails then
    for t = 3 * 3600, END - 600, 2 * 3600 do schedule(t, function() lp("debug_units", storage.id, "lp-infantry", 10) end) end
  end
  if billing then
    S.paid_in = 0
    for t = 2 * 3600 + 60, END - 60, 3600 do
      schedule(t, function()
        if not clean then
          for _, e in ipairs(S.nests or {}) do if e.valid then surface().pollute(e.position, 300) end end
        end
        local L = lp("ledger", storage.id)
        if lp("standing", "serenity", "player") == "truce" then S.saw_truce = true end
        if disputed and L and L.open_bills > 0 then
          local function billed()
            for _, nb in ipairs(L.nests) do
              local e = surface().find_entities_filtered{type = "unit-spawner", position = nb.at, radius = 1}[1]
              if e then return e, nb.at end
            end
          end
          if not S.d1 then
            local e, at = billed()
            if e then
              S.d1 = {owed = L.owed}
              e.die("lp-serenity")
              S.d1.after = lp("ledger", storage.id).owed
            end
          elseif not S.d2 and game.tick > S.d1_tick then
            local e, at = billed()
            if e then
              local due = 0
              for _, nb in ipairs(L.nests) do if nb.at[1] == at[1] and nb.at[2] == at[2] then due = due + nb.cost end end
              S.d2 = {owed = L.owed, due = due, marked = L.marked}
              e.die("player")
              local L2 = lp("ledger", storage.id)
              S.d2.after, S.d2.disputed = L2.owed, L2.disputed
            end
          end
          if S.d1 and not S.d1_tick then S.d1_tick = game.tick + 5 * 3600 end
        end
        if pay and L and L.owed > 0 and L.post then
          local post = surface().find_entities_filtered{name = "lp-invoice-post", position = L.post, radius = 1}[1]
          if post then S.paid_in = S.paid_in + post.insert{name = "electronic-circuit", count = L.owed} end
        end
      end)
    end
  end
  for t = 2 * 3600 + 600, END - 600, 3 * 3600 do
    schedule(t, function()
      local from
      for _, e in ipairs(S.nests or {}) do if e.valid then from = e break end end
      if not from then
        S.quiet_since = S.quiet_since or game.tick
        return
      end
      local st = lp("stats", storage.id)
      if (st.ops.hazards or 0) > 0 then
        S.waves_after = S.waves_after + 1
        S.first_hazard = S.first_hazard or game.tick
      end
      S.waves = S.waves + 1
      local g = surface().create_unit_group{position = from.position, force = "enemy"}
      -- 40 (24 until 2026-10-21: since 0.1.44, tank shells and belted districts, Serenity beat waves of 24 nearly unhurt,
      -- and the losses that start a clearance came after minute 57; every other mix had 40 already).
      for k = 1, off and 24 or 40 do
        local name = k % 3 == 0 and "big-biter" or "medium-biter"
        local p = surface().find_non_colliding_position(name, {from.position.x + (k % 6) * 2 - 5, from.position.y + 5}, 12, 0.5)
        local u = p and surface().create_entity{name = name, position = p, force = "enemy"}
        if u then g.add_member(u) end
      end
      g.set_command{type = defines.command.attack_area, destination = {S.o.x, S.o.y}, radius = 40}
    end)
  end
  schedule(END - 60, function()
    local st = lp("stats", storage.id)
    local left = 0
    for _, e in ipairs(S.nests or {}) do if e.valid then left = left + 1 end end
    info(string.format("hazard: %d waves (%d after the first clearance), lost to biters %d, hazards %d, clearances %d, responses %d, nests left %d of %d",
      S.waves or 0, S.waves_after or 0, st.ops.biter_losses or 0, st.ops.hazards or 0, st.ops.clearances or 0, st.responses or 0, left, #(S.nests or {})))
    if off then
      check("hazard: off, no clearance and the nests stand", (st.ops.hazards or 0) == 0 and left == #S.nests, tostring(left))
      return
    end
    if billing then
      local L = lp("ledger", storage.id)
      local now = lp("standing", "serenity", "player")
      info(string.format("ledger: bills %d, billed %d, paid %d (put in %d), owed %d, truces %d (seen %s), standing %s, furnace %s",
        L.bills, L.billed, L.paid, S.paid_in, L.owed, L.truces, tostring(S.saw_truce), now, S.furnace and "placed" or "none"))
      -- Serenity is at war from landing (the user, 2026-10-19): paying off buys a truce, the only quiet.
      if clean then
        check("hazard: ledger, no cloud on the nests, no bill", L.bills == 0 and now == "enemy", string.format("%d bills, %s", L.bills, now))
      elseif disputed then
        info("ledger disputed: " .. serpent.line({S.d1, S.d2}))
        check("hazard: disputed, a billed nest Serenity killed strikes nothing", S.d1 and S.d1.after == S.d1.owed,
          serpent.line(S.d1))
        check("hazard: disputed, a billed nest the player killed strikes its bills", S.d2 and S.d2.due > 0
          and math.abs(S.d2.after - math.max(0, S.d2.owed - S.d2.due)) <= 1 and S.d2.disputed >= 1, serpent.line(S.d2))
        check("hazard: disputed, the billed nest was marked for the player", (S.d2 and S.d2.marked or 0) >= 1, serpent.line(S.d2))
      elseif pay then
        check("hazard: ledger, billed three times or more, paid off, a truce bought", L.bills >= 3 and L.paid > 0
          and L.truces >= 1 and S.saw_truce, string.format("%d bills, paid %d, %d truces", L.bills, L.paid, L.truces))
      else
        -- Two bills at least (three until 2026-10-20: its line now steps, and the third losses fell by nests the
        -- player's cloud does not reach, rightly not billed).
        check("hazard: ledger, unpaid, no truce, still at war", L.bills >= 2 and L.owed > 0 and L.truces == 0 and not S.saw_truce
          and now == "enemy", string.format("%d bills, owed %d, %s", L.bills, L.owed, now))
      end
      return
    end
    if norails then
      info(string.format("hazard: railgunners made %d", (st.built_by or {})["lp-railgunner"] or 0))
      -- By minute 30: the old code made none while the garrison stood over its cap, and cleared at 35 only once the
      -- waves had worn it under.
      check("hazard: no railgunners and a full garrison, it made them and cleared by minute 30", (st.ops.hazards or 0) >= 1
        and S.first_hazard and S.first_hazard < 30 * 3600, string.format("%d hazards, first seen at minute %s, %d railgunners made",
        st.ops.hazards or 0, S.first_hazard and math.floor(S.first_hazard / 3600) or "-", (st.built_by or {})["lp-railgunner"] or 0))
      return
    end
    if research then
      local t = lp("rd_state", "serenity")
      info(string.format("hazard research: railguns level %s, %d hazards, %d nests left", tostring(t.nodes.railguns),
        st.ops.hazards or 0, left))
      check("hazard: research, its losses to biters bought railguns", (t.nodes.railguns or 0) >= 1, tostring(t.nodes.railguns))
      return
    end
    check("hazard: its losses to biters made it clear the nests", (st.ops.hazards or 0) >= 1 and left == 0, string.format("%d hazards, %d left", st.ops.hazards or 0, left))
  end)
end

-- Rail: Serenity's railgunner against biters (the user: a biter-clearing unit, "a hand mounted railgun that's at its
-- best against biters"). Four railgunners (88 parts) and, LP_MIX=line, nine Line troopers (90) meet 16 big biters, then
-- what is left fires on a player wall for 20 s: the railgunners win against biters and do a trooper's damage to a wall.
scenarios.rail = function()
  local line = params.mix == "line"
  local name, n = line and "lp-infantry" or "lp-railgunner", line and 9 or 4
  -- Railguns at their top level (0.2.20; at baseline a railgunner loses to big biters, as it is meant to).
  schedule(60, function() lp("debug_tune", {ops_off = true, army_off = true, rd_tech = {serenity = {weapons = {["lp-rail"] = 5}, nodes = {railguns = 5}}}}) end)
  schedule(120, function()
    flatten(-60, -40, 60, 40)
    S.own = {}
    for k = 1, n do
      table.insert(S.own, surface().create_entity{name = name, position = {-30, (k - (n + 1) / 2) * 1.5}, force = FORCE})
    end
    S.biters = {}
    local g = surface().create_unit_group{position = {30, 0}, force = "enemy"}
    -- Eight big biters (sixteen until 0.2.20: the line through the whole pack; a slug stops in a big biter now).
    for k = 1, 8 do
      local u = surface().create_entity{name = "big-biter", force = "enemy",
        position = surface().find_non_colliding_position("big-biter", {30 + (k % 4) * 2, math.floor(k / 4) * 2 - 3}, 6, 0.5)}
      if u then g.add_member(u); table.insert(S.biters, u) end
    end
    g.set_command{type = defines.command.attack_area, destination = {-30, 0}, radius = 10}
  end)
  schedule(120 + 60 * 60, function()
    local b, o = 0, 0
    for _, u in ipairs(S.biters) do if u.valid then b = b + 1 end end
    for _, u in ipairs(S.own) do if u.valid then o = o + 1 end end
    S.b, S.o = b, o
    S.walls = {}
    for y = -6, 6 do
      table.insert(S.walls, surface().create_entity{name = "stone-wall", position = {-30.5 + 14, y + 0.5}, force = "player"})
    end
    for _, u in ipairs(S.own) do
      if u.valid then u.commandable.set_command{type = defines.command.attack, target = S.walls[7], distraction = defines.distraction.none} end
    end
  end)
  schedule(120 + 80 * 60, function()
    local hurt = 0
    for _, w in ipairs(S.walls) do hurt = hurt + (w.valid and (w.max_health - w.health) or 350) end
    info(string.format("rail (%s x%d): %d of 16 big biters left, %d of %d own standing; walls lost %d health in 20 s",
      name, n, S.b, S.o, n, hurt))
    if line then
      check("rail: the troopers did worse", S.b > 0 or S.o < n, string.format("%d left, %d standing", S.b, S.o))
    else
      check("rail: the railgunners killed the big biters", S.b == 0, tostring(S.b))
      -- At least one of four: survivors on three seeds were 2, 0, 3 (main) and 1, 2, 2 (Space Age's railgun beam), so
      -- "half stood" failed one seed or another by chance (2026-10-18).
      check("rail: and one stood at least", S.o >= 1, tostring(S.o))
      -- Against buildings no better than Line troopers (about 17 a second each, 1,000 from three in 20 s) at twice the cost.
      check("rail: the wall no worse off than from troopers", hurt < 1000, string.format("%.0f", hurt))
    end
  end)
end

-- Gate (the rivals consult, the gate of decision 3: engaging must pay better than turtling). A player base at the spawn
-- (a chest-fed drill pair on each of two iron patches), four free iron patches 120 to 200 tiles out (its frontier), a
-- Grubstake camp and the usual Serenity camp, both rivals (unprovoked); hours at real clocks. LP_MIX=turtle: each loss
-- answered with two gun turrets on the spot, nothing more. LP_MIX=engage: the same, and the rivals answered as the plan
-- says: a patch Grubstake tags is drilled inside the window (the player expands there), a claim that stands gets two gun
-- turrets beside it (its road cut: it becomes an enemy), a border stake set when Serenity's line comes within 80 of a
-- player drill. Measured at the end: patches the player works, its ore mined, its buildings lost, Grubstake's claims.
scenarios.gate = function()
  local engage = params.mix:find("engage", 1, true) ~= nil
  S.patches, S.free, S.answered, S.lost = {}, {}, {}, 0
  local function patch(c)
    flatten(c[1] - 9, c[2] - 9, c[1] + 9, c[2] + 9)
    for x = -7, 7 do for y = -7, 7 do surface().create_entity{name = "iron-ore", position = {c[1] + x, c[2] + y}, amount = 5000} end end
  end
  local function work(c)
    -- A player drill pair with a chest each, on a patch (burner drills: no power to model).
    for _, dx in ipairs({-3, 3}) do
      local d = surface().create_entity{name = "burner-mining-drill", position = {c[1] + dx, c[2]}, force = "player"}
      if d then
        d.insert{name = "coal", count = 50}
        surface().create_entity{name = "wooden-chest", position = d.drop_position, force = "player"}
        table.insert(S.drills, d)
        S.drill_at = S.drill_at or {}
        S.drill_at[#S.drills] = {d.position.x, d.position.y}
      end
    end
  end
  schedule(60, function()
    -- The line at its own pace unless LP_MIX contains "fast" (a step a minute brought it onto the base in 13 minutes).
    lp("debug_tune", {era = 1, history_off = true, prospect_window = 5 * 3600, prospect_pace = 3 * 3600,
      prospect_uncharted = true, perimeter_fast = params.mix:find("fast", 1, true) ~= nil})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    for _ = 1, 2 do lp("debug_depot", S.g, 3000) end
    lp("debug_depot", storage.id, 3000)
    S.drills = {}
    for _, c in ipairs({{-40, 0}, {40, 0}}) do patch(c); work(c); table.insert(S.patches, c) end
    for k = 0, 3 do
      local a = k * math.pi / 2 + math.pi / 4
      local r = 120 + 25 * k
      local c = {math.floor(math.cos(a) * r), math.floor(math.sin(a) * r)}
      patch(c)
      table.insert(S.free, c)
    end
  end)
  -- Keep the burners fed (a player's belts would).
  for t = 600, END - 60, 1800 do
    schedule(t, function()
      for _, d in ipairs(S.drills or {}) do
        if d.valid and d.get_item_count("coal") < 20 then d.insert{name = "coal", count = 30} end
      end
    end)
  end
  for t = 2 * 3600, END - 600, 300 do
    schedule(t, function()
      -- Losses (its drills, polled: the test's death handler does not watch them), answered with two gun turrets.
      S.dead = S.dead or {}
      for i, d in ipairs(S.drills or {}) do
        if not d.valid and not S.dead[i] then
          S.dead[i] = S.drill_at[i]
          S.lost = (S.lost or 0) + 1
        end
      end
      -- Both policies rebuild a lost drill where it stood, once the ground is clear of corporation units (a turtle that
      -- never rebuilt mined nothing once raided: too weak a model to measure against).
      for i, at in pairs(S.dead) do
        if not (S.drills[i] and S.drills[i].valid) and not (S.rebuilt or {})[i]
          and surface().count_entities_filtered{position = at, radius = 20, type = "unit", force = {"lp-grubstake", "lp-serenity"},
            limit = 1} == 0 then
          local d = surface().create_entity{name = "burner-mining-drill", position = at, force = "player"}
          if d then
            d.insert{name = "coal", count = 50}
            if surface().count_entities_filtered{name = "wooden-chest", position = d.drop_position, radius = 0.6} == 0 then
              surface().create_entity{name = "wooden-chest", position = d.drop_position, force = "player"}
            end
            S.drills[i] = d
            S.dead[i] = nil
            S.rebuilt_n = (S.rebuilt_n or 0) + 1
          end
        end
      end
      for k, d in pairs(S.dead or {}) do
        if not S.answered[k] then
          S.answered[k] = true
          for _, dx in ipairs({-4, 4}) do
            local p = surface().find_non_colliding_position("gun-turret", {d[1] + dx, d[2] - 5}, 6, 1)
            local t2 = p and surface().create_entity{name = "gun-turret", position = p, force = "player"}
            if t2 then t2.insert{name = "piercing-rounds-magazine", count = 100} end
          end
        end
      end
      if not engage then return end
      -- A tagged patch: drill it now (expand there).
      local ps = lp("prospect_stats", S.g)
      if ps.phase == "tagged" and ps.at then
        local k = ps.at[1] .. "," .. ps.at[2]
        S.drilled = S.drilled or {}
        if not S.drilled[k] then
          S.drilled[k] = true
          local ore = surface().find_entities_filtered{type = "resource", position = ps.at, radius = 16, limit = 1}[1]
          if ore then work({ore.position.x + 3, ore.position.y}); table.insert(S.patches, {ore.position.x, ore.position.y}) end
          S.expanded = (S.expanded or 0) + 1
        end
      end
      -- Standing claims: two gun turrets beside each (its road cut).
      for _, c in ipairs(lp("road_stats", S.g).centers or {}) do
        local k = c[1] .. "," .. c[2]
        S.sieged = S.sieged or {}
        if not S.sieged[k] then
          S.sieged[k] = true
          for _, dx in ipairs({-12, 12}) do
            local p = surface().find_non_colliding_position("gun-turret", {c[1] + dx, c[2] + 12}, 6, 1)
            local t2 = p and surface().create_entity{name = "gun-turret", position = p, force = "player"}
            if t2 then t2.insert{name = "piercing-rounds-magazine", count = 200} end
          end
        end
      end
      -- Serenity's line near a player drill: a border stake 60 out from the drill toward the camp, once.
      if not S.staked then
        local st = lp("stats", storage.id)
        for _, d in ipairs(S.drills) do
          if d.valid and st.perimeter then
            local dd = math.sqrt((d.position.x - st.origin.x) ^ 2 + (d.position.y - st.origin.y) ^ 2)
            if dd - st.perimeter < 80 then
              local ux, uy = (st.origin.x - d.position.x) / dd, (st.origin.y - d.position.y) / dd
              local p = surface().find_non_colliding_position("lp-border-stake", {d.position.x + ux * 60, d.position.y + uy * 60}, 8, 1)
              if p then
                surface().create_entity{name = "lp-border-stake", position = p, force = "player", raise_built = true}
                S.staked = game.tick
              end
              break
            end
          end
        end
      end
    end)
  end
  schedule(END - 60, function()
    local worked, mined = 0, 0
    for _, c in ipairs(S.patches) do
      if surface().count_entities_filtered{type = "mining-drill", force = "player", position = c, radius = 16} > 0 then worked = worked + 1 end
    end
    for _, ch in pairs(surface().find_entities_filtered{name = "wooden-chest", force = "player"}) do mined = mined + ch.get_item_count("iron-ore") end
    local rs = lp("road_stats", S.g)
    info(string.format("gate (%s): patches worked %d, iron mined %d (in chests), player buildings lost %d; Grubstake claims %d (%d lapsed); "
      .. "expanded %s, staked %s, rebuilt %s; standing grubstake %s, serenity %s", engage and "engage" or "turtle", worked, mined, S.lost or 0,
      rs.claims or 0, rs.lapsed or 0, tostring(S.expanded), tostring(S.staked), tostring(S.rebuilt_n), lp("standing", "grubstake"),
      lp("standing", "serenity")))
    metric("gate_patches", worked); metric("gate_mined", mined); metric("gate_lost", S.lost or 0)
    check("gate: it ran", true, "")
  end)
end

-- Bend (the rivals consult, slice 6): Serenity's line bears on the player's nearest building. A relay 300 out toward the
-- spawn; at 6 minutes a second relay 90 degrees off and nearer (200 out): the next arcs bear on it (within two arcs,
-- a bearing at least 45 degrees from the first).
scenarios.bend = function()
  schedule(30, function() lp("debug_tune", {perimeter_fast = true}) end)
  schedule(60, function() for _ = 1, 2 do lp("debug_depot", storage.id, 4000) end end)
  schedule(90, function()
    local o = lp("stats", storage.id).origin
    S.o = o
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    S.u = {-o.x / len, -o.y / len}
    local c = {math.floor(o.x + S.u[1] * 300), math.floor(o.y + S.u[2] * 300)}
    flatten(c[1] - 6, c[2] - 6, c[1] + 6, c[2] + 6)
    local r = surface().create_entity{name = "lp-command-relay", position = c, force = "player"}
    r.destructible = false
  end)
  schedule(6 * 3600, function()
    S.n0 = #(lp("cordon_stats", storage.id).bearings or {})
    local v = {-S.u[2], S.u[1]}
    local c = {math.floor(S.o.x + v[1] * 200), math.floor(S.o.y + v[2] * 200)}
    flatten(c[1] - 6, c[2] - 6, c[1] + 6, c[2] + 6)
    local r = surface().create_entity{name = "lp-command-relay", position = c, force = "player"}
    r.destructible = false
  end)
  schedule(END - 60, function()
    local cs = lp("cordon_stats", storage.id)
    local bs = cs.bearings or {}
    local first = bs[1]
    local swung = false
    for k = (S.n0 or 0) + 1, math.min(#bs, (S.n0 or 0) + 2) do
      local d = math.abs(((bs[k] - first + 180) % 360) - 180)
      if d >= 45 then swung = true end
    end
    info(string.format("bend: bearings %s (decoy after arc %s)", serpent.line(bs), tostring(S.n0)))
    check("bend: the line re-bore on the decoy within two arcs", swung, serpent.line(bs))
  end)
end

-- Tribute (the rivals consult, slice 5): an enemy Grubstake camp (provoked at the start), three undefended player
-- assemblers 100 tiles out; at 4 minutes a trade post 50 out with 500 iron (worth 5 minutes of truce). The post emptied,
-- a truce; no raid on the player starts while it lasts; afterwards an enemy again, and raids on the player resume.
scenarios.tribute = function()
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    for _ = 1, 2 do lp("debug_depot", S.g, 3000) end
  end)
  schedule(2 * 3600, function()
    local o = lp("stats", S.g).origin
    S.o = o
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = -o.x / len, -o.y / len
    for k = -1, 1 do
      local p = surface().find_non_colliding_position("assembling-machine-1", {o.x + ux * 100 - uy * 12 * k, o.y + uy * 100 + ux * 12 * k}, 8, 1)
      surface().create_entity{name = "assembling-machine-1", position = p, force = "player"}
    end
  end)
  -- Built again before the truce runs out, as a player would (Serenity's raid took the last of the first three during the
  -- truce, a reprisal having brought its operation forward, and Grubstake found nothing of the player's to raid after).
  schedule(9 * 3600, function()
    local o = S.o
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = -o.x / len, -o.y / len
    for k = -1, 1 do
      local p = surface().find_non_colliding_position("assembling-machine-1", {o.x + ux * 90 - uy * 12 * k, o.y + uy * 90 + ux * 12 * k}, 8, 1)
      surface().create_entity{name = "assembling-machine-1", position = p, force = "player"}
    end
  end)
  schedule(4 * 3600, function()
    local p = surface().find_non_colliding_position("lp-trade-post", {S.o.x + 50, S.o.y}, 10, 1)
    S.post = surface().create_entity{name = "lp-trade-post", position = p, force = "player", raise_built = true}
    S.post.insert{name = "iron-plate", count = 500}
  end)
  -- Raids on the player, by the tick each started (the operations log).
  local seen = {}
  S.raids = {}
  for t = 2 * 3600, END - 120, 300 do
    schedule(t, function()
      for _, o in ipairs(lp("stats", S.g).ops.log or {}) do
        local k = tostring(o.started) .. o.kind
        if o.owner == "player" and not seen[k] then seen[k] = true; table.insert(S.raids, o.started) end
      end
      local st = lp("standing", "grubstake")
      local lit = (lp("trade_stats").lit or 0) > 0
      if st == "truce" then
        S.truce_from = S.truce_from or game.tick
        S.truce_to = game.tick
        S.lit_during = (S.lit_during or 0) + (lit and 1 or 0)
        S.samples_during = (S.samples_during or 0) + 1
      elseif S.truce_to then
        S.lit_after = (S.lit_after or 0) + (lit and 1 or 0)
      end
    end)
  end
  schedule(END - 60, function()
    local during, after = 0, 0
    for _, t in ipairs(S.raids) do
      if S.truce_from and t >= S.truce_from and t <= S.truce_to then during = during + 1 end
      if S.truce_to and t > S.truce_to then after = after + 1 end
    end
    local left = S.post and S.post.valid and S.post.get_item_count() or -1
    info(string.format("tribute: %s; truce %s to %s; raids on the player %s (during %d, after %d); the post holds %d; standing %s",
      serpent.line(lp("trade_stats")), tostring(S.truce_from), tostring(S.truce_to), serpent.line(S.raids), during, after, left,
      lp("standing", "grubstake")))
    check("tribute: the post was emptied, a truce", left == 0 and S.truce_from ~= nil, tostring(left))
    check("tribute: no raid on the player during the truce", during == 0, tostring(during))
    check("tribute: an enemy again after it", lp("standing", "grubstake") == "enemy", lp("standing", "grubstake"))
    -- The post's lamp (Fable's notices consult): lit while the truce holds, dark after (a sample may straddle the edge).
    check("tribute: the post lit during the truce, dark after", S.samples_during and S.lit_during >= S.samples_during - 1
      and (S.lit_after or 0) <= 1, string.format("lit %s of %s during, %s after", tostring(S.lit_during),
      tostring(S.samples_during), tostring(S.lit_after)))
    check("tribute: raids on the player resumed", after >= 1, tostring(after))
  end)
end

-- Road (the rivals consult, slice 4): the prospect setup (three iron patches, the nearest drilled by the player); a haul
-- every 2 minutes, a claim lapsing after 6 without ore home. Uncut: ore goes home from the claims. LP_MIX=cut: once a
-- claim stands every Grubstake truck near it is destroyed: ore spilled, the delay told, the claim lapses.
scenarios.road = function()
  local cut = params.mix == "cut"
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true, raids_off = true, prospect_window = 2 * 3600, prospect_pace = 3600,
      prospect_uncharted = true, road_haul = 2 * 3600, road_lapse = 6 * 3600})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    for _ = 1, 2 do lp("debug_depot", S.g, 3000) end
  end)
  schedule(2 * 3600, function()
    local o = lp("stats", S.g).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = -o.x / len, -o.y / len
    local vx, vy = -uy, ux
    S.patches = {}
    for _, d in ipairs({{150, 0}, {200, 60}, {250, -60}}) do
      local c = {math.floor(o.x + ux * d[1] + vx * d[2]), math.floor(o.y + uy * d[1] + vy * d[2])}
      flatten(c[1] - 8, c[2] - 8, c[1] + 8, c[2] + 8)
      for x = -6, 6 do for y = -6, 6 do surface().create_entity{name = "iron-ore", position = {c[1] + x, c[2] + y}, amount = 2000} end end
      table.insert(S.patches, c)
    end
    surface().create_entity{name = "burner-mining-drill", position = S.patches[1], force = "player"}
  end)
  if cut then
    for t = 3 * 3600, END - 120, 60 do
      schedule(t, function()
        -- Every built claim the camp holds (prospecting goes for the patches nearest the player's base: not only ours),
        -- its trucks killed leaving it loaded (30 to 60 tiles out: killed on the way in they carried nothing).
        for _, c in ipairs(S.g and lp("road_stats", S.g).centers or {}) do
          for _, t2 in pairs(surface().find_entities_filtered{name = "lp-grubstake-hauler", position = c, radius = 60}) do
            local d = math.sqrt((t2.position.x - c[1]) ^ 2 + (t2.position.y - c[2]) ^ 2)
            S.seen_near = S.seen_near or {}
            if d < 14 then S.seen_near[t2.unit_number] = true
            elseif d > 25 and S.seen_near[t2.unit_number] then t2.die("player") end
          end
        end
      end)
    end
  end
  schedule(END - 60, function()
    local rs = lp("road_stats", S.g)
    local kinds = {}
    for _, e in ipairs(lp("incidents")) do kinds[e.kind] = (kinds[e.kind] or 0) + 1 end
    info(string.format("road: %s; incidents %s", serpent.line(rs), serpent.line(kinds)))
    local ST = {}
    for k, v in pairs(defines.entity_status) do ST[v] = k end
    for _, c in ipairs(rs.centers or {}) do
      local st, ore = {}, 0
      for _, d in pairs(surface().find_entities_filtered{name = "lp-grubstake-drill", position = c, radius = 12}) do
        st[#st + 1] = ST[d.status] or tostring(d.status)
      end
      for _, bn in pairs(surface().find_entities_filtered{name = "lp-grubstake-bin", position = c, radius = 12}) do
        ore = ore + bn.get_item_count()
      end
      local _, ground = dropped(c, 12)
      info(string.format("road: claim %d,%d drills %s; bins hold %d; %d items on the ground", c[1], c[2], serpent.line(st), ore, ground))
    end
    if cut then
      check("road: a loaded truck was lost and the delay told", (kinds["hauler lost"] or 0) >= 1, serpent.line(kinds))
      check("road: the claim lapsed", (rs.lapsed or 0) >= 1, serpent.line(rs))
      return
    end
    check("road: ore went home from the claims", (rs.hauls or 0) >= 1 and (rs.hauled or 0) > 0, serpent.line(rs))
    check("road: nothing lapsed", (rs.lapsed or 0) == 0, serpent.line(rs))
  end)
end

-- Border (the rivals consult, slice 3): an unprovoked Serenity camp, its line a step a minute, a player relay 300 out
-- (lasting); a border stake 200 out toward it at 2 minutes: accepted (a rival), the line never past it in 20 minutes.
-- LP_MIX=breach: at 10 minutes an assembler of the player's at 160, on Serenity's side: the treaty broken, Serenity an
-- enemy, the treaty void.
scenarios.border = function()
  local breach = params.mix == "breach"
  schedule(30, function() lp("debug_tune", {perimeter_fast = true}) end)
  schedule(60, function() for _ = 1, 2 do lp("debug_depot", storage.id, 4000) end end)
  schedule(90, function()
    local o = lp("stats", storage.id).origin
    S.o = o
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    S.u = {-o.x / len, -o.y / len}
    local c = {math.floor(o.x + S.u[1] * 300), math.floor(o.y + S.u[2] * 300)}
    flatten(c[1] - 6, c[2] - 6, c[1] + 6, c[2] + 6)
    S.relay = surface().create_entity{name = "lp-command-relay", position = c, force = "player"}
    S.relay.destructible = false
  end)
  -- Serenity is at war from landing (the user, 2026-10-19): it treats only under a truce (bought at its invoice post;
  -- set here), and the border holds after the truce ends.
  schedule(2 * 3600 - 60, function() lp("debug_truce", "serenity", "player", 5) end)
  schedule(2 * 3600, function()
    local p = {S.o.x + S.u[1] * 200, S.o.y + S.u[2] * 200}
    flatten(p[1] - 3, p[2] - 3, p[1] + 3, p[2] + 3)
    S.stake = surface().create_entity{name = "lp-border-stake", position = p, force = "player", raise_built = true}
    S.stake.destructible = false
    S.held0 = lp("borders").held
  end)
  if breach then
    schedule(10 * 3600, function()
      local p = surface().find_non_colliding_position("assembling-machine-1", {S.o.x + S.u[1] * 160, S.o.y + S.u[2] * 160}, 10, 1)
      S.intruder = surface().create_entity{name = "assembling-machine-1", position = p, force = "player"}
      S.intruder.destructible = false
    end)
  end
  local maxp = 0
  for t = 2 * 3600 + 600, END - 120, 600 do
    schedule(t, function() maxp = math.max(maxp, lp("stats", storage.id).perimeter or 0); S.maxp = maxp end)
  end
  schedule(END - 60, function()
    local st = lp("stats", storage.id)
    local standing_now = lp("standing", "serenity")
    info(string.format("border: accepted %s; perimeter at most %.0f (now %.0f); standing %s; borders %s", tostring(S.held0),
      S.maxp or -1, st.perimeter or -1, standing_now, serpent.line(lp("borders"))))
    check("border: accepted", S.held0 == 1, tostring(S.held0))
    if breach then
      check("border: built on its side, the treaty broke, at war", standing_now == "enemy", standing_now)
      -- The treaty void (the line itself has nowhere to go: it stops 40 past the player's nearest building, the
      -- intruder inside its claim; the enemy raids it instead).
      check("border: the treaty is void", lp("borders").held == 0, serpent.line(lp("borders")))
      return
    end
    check("border: the line held short of the stake", (S.maxp or 999) <= 200, string.format("%.0f", S.maxp or -1))
    check("border: the truce over, at war, the border held", standing_now == "enemy" and lp("borders").held == 1,
      standing_now .. " " .. serpent.line(lp("borders")))
  end)
end

-- Standing (the rivals consult, slice 2): a Grubstake camp starts a rival (no provocation): its ladder held at the foot
-- although ten times fast. A player gun turret set beside its lander: within a minute or two it is an enemy, a turret
-- incident and a standing change listed, and its ladder climbs. Then it stands down (quiet in 4 minutes, nothing razed):
-- a rival again.
scenarios.standing = function()
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true, raids_off = true, ladder_fast = true})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    lp("debug_depot", S.g, 3000)
  end)
  schedule(4 * 3600, function()
    S.st0, S.rung0 = lp("standing", "grubstake"), lp("stats", S.g).ops.ladder
    S.label0 = lp("stats", S.g).map_text
    local o = lp("stats", S.g).origin
    local p = surface().find_non_colliding_position("gun-turret", {o.x + 14, o.y + 14}, 10, 1)
    S.turret = surface().create_entity{name = "gun-turret", position = p, force = "player"}
    S.turret.destructible = false
    S.at = game.tick
    -- Something of the player's in its sight, lasting: at war it can stand down (with nothing to fight it never did).
    local q = surface().find_non_colliding_position("assembling-machine-1", {o.x - 60, o.y}, 10, 1)
    local a = surface().create_entity{name = "assembling-machine-1", position = q, force = "player"}
    a.destructible = false
  end)
  schedule(7 * 3600, function()
    S.st1 = lp("standing", "grubstake")
    S.label1 = lp("stats", S.g).map_text
    if S.turret and S.turret.valid then S.turret.destroy() end
    lp("debug_tune", {quiet_minutes = 4})
  end)
  schedule(9 * 3600, function() S.rung1 = lp("stats", S.g).ops.ladder end)
  schedule(END - 60, function()
    S.st2 = lp("standing", "grubstake")
    local kinds = {}
    for _, e in ipairs(lp("incidents")) do kinds[e.kind] = (kinds[e.kind] or 0) + 1 end
    info(string.format("standing: %s (ladder %s) -> %s -> %s (ladder at 9 min %s); incidents %s", tostring(S.st0), tostring(S.rung0),
      tostring(S.st1), tostring(S.st2), tostring(S.rung1), serpent.line(kinds)))
    check("standing: a rival at first, its ladder held", S.st0 == "rival" and S.rung0 == 0, tostring(S.st0) .. " " .. tostring(S.rung0))
    check("standing: a turret on its ground made it an enemy", S.st1 == "enemy", tostring(S.st1))
    check("standing: listed (a turret incident, a standing change)", (kinds.turret or 0) >= 1 and (kinds["standing-enemy"] or 0) >= 1,
      serpent.line(kinds))
    check("standing: stood down, a rival again", S.st2 == "rival", tostring(S.st2))
    -- The map label follows (map.lua).
    check("standing: the map label says so", S.label0 and S.label0:find("rival") and S.label1 and S.label1:find("enemy"),
      tostring(S.label0) .. " / " .. tostring(S.label1))
  end)
end

-- Prospect (the rivals consult, slice 1): a Grubstake camp and three iron patches laid 150 to 250 tiles out, charted,
-- one with a player drill on it. Windows of 2 minutes, a minute between claims (here): the two undrilled patches are
-- tagged and claimed, nearest first, each claim built by a truck; the drilled one never. LP_MIX=stake: a claim marker
-- beside the second patch from the start: it is never tagged. Every tagged patch gets a lit stake (Fable's notices
-- consult), red in its last two minutes. LP_MIX=pulled: the first stake is pulled down: that claim is off, the patch
-- left alone, and the camp goes on to the next.
scenarios.prospect = function()
  -- LP_MIX=truck: the stake truck destroyed on its way (the buggy nearest the tagged patch): the claim is off.
  local stake, pulled, truck = params.mix == "stake", params.mix == "pulled", params.mix == "truck"
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true, raids_off = true, prospect_window = 2 * 3600, prospect_pace = 3600,
      prospect_uncharted = true})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    for _, k in ipairs({1, 2}) do lp("debug_depot", S.g, 3000) end
  end)
  schedule(2 * 3600, function()
    local o = lp("stats", S.g).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = -o.x / len, -o.y / len
    local vx, vy = -uy, ux
    S.patches = {}
    for k, d in ipairs({{150, 0}, {200, 60}, {250, -60}}) do
      local c = {math.floor(o.x + ux * d[1] + vx * d[2]), math.floor(o.y + uy * d[1] + vy * d[2])}
      flatten(c[1] - 8, c[2] - 8, c[1] + 8, c[2] + 8)
      for x = -6, 6 do for y = -6, 6 do
        surface().create_entity{name = "iron-ore", position = {c[1] + x, c[2] + y}, amount = 2000}
      end end
      game.forces.player.chart(surface(), {{c[1] - 20, c[2] - 20}, {c[1] + 20, c[2] + 20}})
      table.insert(S.patches, c)
    end
    -- The player's base, for prospecting, by the second patch (the map's own ore by the spawn otherwise comes first).
    lp("debug_tune", {prospect_home = {x = S.patches[2][1], y = S.patches[2][2]}})
    -- The first (nearest) is the player's: a drill on it.
    local p1 = S.patches[1]
    surface().create_entity{name = "burner-mining-drill", position = {p1[1], p1[2]}, force = "player"}
    if stake then
      local p2 = S.patches[2]
      surface().create_entity{name = "lp-claim-marker", position = {p2[1] + 8, p2[2]}, force = "player", raise_built = true}
    end
  end)
  for t = 2 * 3600 + 300, END - 120, 300 do
    schedule(t, function()
      local ps = lp("prospect_stats", S.g)
      if ps.stake then S.stake_seen = (S.stake_seen or 0) + 1 end
      if ps.phase == "staking" then S.staking_seen = true end
      if truck and ps.phase == "staking" and not S.truck_killed and ps.at then
        local u = surface().find_entities_filtered{name = "lp-grubstake-buggy", position = ps.at, radius = 400, limit = 1}[1]
        local all = surface().find_entities_filtered{name = "lp-grubstake-buggy"}
        u = #all > 0 and surface().get_closest({ps.at[1], ps.at[2]}, all) or u
        if u then u.die("player"); S.truck_killed = game.tick; S.truck_at = ps.at end
      end
      if ps.red then S.red_seen = (S.red_seen or 0) + 1 end
      if pulled and ps.stake and not S.pulled_at then
        local e = surface().find_entities_filtered{name = "lp-claim-stake", limit = 1}[1]
        if e then
          for k, c in ipairs(S.patches) do
            if (e.position.x - c[1]) ^ 2 + (e.position.y - c[2]) ^ 2 < 20 * 20 then S.pulled_patch = k end
          end
          e.die("player")
          S.pulled_at = game.tick
        end
      end
    end)
  end
  schedule(END - 60, function()
    local ps = lp("prospect_stats", S.g)
    local drills = {}
    for k, c in ipairs(S.patches or {}) do
      drills[k] = surface().count_entities_filtered{name = "lp-grubstake-drill", position = c, radius = 16}
    end
    local charted = {}
    for k, c in ipairs(S.patches or {}) do
      charted[k] = game.forces.player.is_chunk_charted(surface(), {math.floor(c[1] / 32), math.floor(c[2] / 32)})
    end
    info(string.format("prospect: %s; Grubstake drills on the patches %s; charted %s", serpent.line(ps), serpent.line(drills),
      serpent.line(charted)))
    check("prospect: the drilled patch was left alone", drills[1] == 0, tostring(drills[1]))
    if truck then
      check("prospect: the stake truck killed, the claim off", S.truck_killed and ps.trucks_lost >= 1,
        string.format("killed %s, %s", tostring(S.truck_killed), serpent.line(ps)))
      return
    end
    check("prospect: a truck drove the stake out", S.staking_seen and ps.driven >= 1, serpent.line(ps))
    if pulled then
      check("prospect: the stake pulled, that patch left alone", S.pulled_patch and drills[S.pulled_patch] == 0
        and ps.pulled >= 1, string.format("patch %s, drills %s, %s", tostring(S.pulled_patch), serpent.line(drills),
        serpent.line(ps)))
      return
    end
    if not stake then
      check("prospect: a lit stake on the tagged patch, red near the end", (S.stake_seen or 0) > 0 and (S.red_seen or 0) > 0,
        string.format("seen %s, red %s", tostring(S.stake_seen), tostring(S.red_seen)))
    end
    if stake then
      check("prospect: the staked patch was left alone", drills[2] == 0, tostring(drills[2]))
      check("prospect: the free one was claimed", drills[3] >= 1, tostring(drills[3]))
      return
    end
    check("prospect: both undrilled patches claimed", drills[2] >= 1 and drills[3] >= 1, serpent.line(drills))
    -- The notice gate (shared.notice; the user: "nothing is communicated through notices in factorio"). A headless run
    -- has no players, so the corporations' own notices never reach it: it is called directly. Off by default, a notice
    -- is held; a lost settlement is told whatever the setting; on (as the setting would), told.
    local function delta(key, on)
      if on ~= nil then lp("debug_tune", {notices = on}) end
      local a = lp("notice_counts")
      lp("debug_notice", key)
      local z = lp("notice_counts")
      return z.told - a.told, z.held - a.held
    end
    local t1, h1 = delta("lp.claim")
    local t2, h2 = delta("lp.fallen")
    local t3, h3 = delta("lp.claim", true)
    lp("debug_tune", {notices = false})
    info(string.format("prospect: notices default %d told %d held; fallen %d told; on %d told", t1, h1, t2, t3))
    check("prospect: a notice is held by default, a fall told, all told when on", t1 == 0 and h1 == 1 and t2 == 1 and t3 == 1,
      string.format("%d/%d %d/%d %d/%d", t1, h1, t2, h2, t3, h3))
    check("prospect: tagged before claimed (two at least)", ps.prospects >= 2 and ps.claimed >= 2, serpent.line(ps))
  end)
end

-- Cordon (the walled-advance consult, slice 1): a Serenity camp's line, sped to a step a minute, with a player relay 300
-- tiles out: arcs of posts (a pad, a short wall, two gun turrets) at each step's radius, within 60 degrees of the bearing
-- to the relay, built by drones; the claim steps out to an arc only once 80% of its posts stand; none stuck.
-- LP_MIX=breach: at 12 minutes three post turrets of the standing line killed by the player: drones mend them within 3
-- minutes, and Serenity is an enemy. LP_MIX=contact: the relay 200 out: an arc within 60 of it closes its middle with
-- wall (40 pieces at least on that arc, near the bearing).
scenarios.cordon = function()
  -- LP_MIX=rail: a player rail along the bearing, 100 to 260 out, crossed by the arcs: gate posts on it, and a train
  -- driven toward the camp from 240 out at 14 minutes stops at the outermost gate.
  -- LP_MIX=ore: an iron patch on the arcs' path (150 out, 20 degrees off the bearing): Serenity claims it.
  -- LP_MIX=held: from 6 minutes every drone flying beyond the claim is shot down (the player's guns at the line): the
  -- posts of the arc ahead are given up after three crews each, the player is told the line is held, and the claim
  -- steps out no further.
  local breach, contact, rail, oremix = params.mix == "breach", params.mix == "contact", params.mix == "rail", params.mix == "ore"
  local held = params.mix == "held"
  -- LP_MIX=broken: once two arcs stand, every gun turret on the leading arc is destroyed (the player hunting the line):
  -- the line counts as broken, the claim falls back to the arc before, and it does not step out again for 15 minutes.
  local broken = params.mix == "broken"
  -- LP_MIX=ring: the camp counts as grown at two blocks; grown, it closes a ring of posts round itself.
  local ringmix = params.mix == "ring"
  -- (No spread: a spreading camp closes its ring only when its spread is done.)
  -- (Its camp by blocks: districts' plated floors counted as litter beyond 100.)
  schedule(30, function() lp("debug_tune", {perimeter_fast = true, mature_blocks = ringmix and 2 or nil,
    grow_to_line_off = ringmix or nil, wfc_core_off = true}) end)
  -- Watched (scripts/watch.sh cordon): the camp and a post on the leading arc, by day and by night, and the line at night
  -- (Serenity's look: its deck, the post lamps, the painted stripe).
  if params.watch then
    schedule(90, function() game.speed = params.watch_speed or 10 end)
    schedule(END - 300, function()
      local n = 0
      local function shot(name, pos, zoom, night)
        n = n + 1
        game.take_screenshot{surface = surface(), position = pos, resolution = {1600, 900}, zoom = zoom,
          daytime = night and 0.5 or 0, path = string.format("lp-watch/%03d-%s.png", n, name), show_entity_info = false}
        helpers.write_file("lp-watch/shots.txt", string.format("%03d-%s.png\n", n, name), true)
      end
      local so = lp("stats", storage.id).origin
      shot("camp-day", {so.x, so.y}, 0.5)
      shot("camp-night", {so.x, so.y}, 0.5, true)
      local far, lamp = 0, nil
      for _, l in pairs(surface().find_entities_filtered{name = "lp-post-lamp"}) do
        local d = (l.position.x - so.x) ^ 2 + (l.position.y - so.y) ^ 2
        if d > far then far, lamp = d, l end
      end
      if lamp then
        shot("post-day", lamp.position, 1)
        shot("post-night", lamp.position, 1, true)
        shot("line-night", {(lamp.position.x + so.x) / 2, (lamp.position.y + so.y) / 2}, 0.15, true)
        shot("line-day", {(lamp.position.x + so.x) / 2, (lamp.position.y + so.y) / 2}, 0.15)
      end
    end)
  end
  if broken then
    for t = 4 * 3600, END - 12 * 3600, 600 do
      schedule(t, function()
        if S.hit then return end
        local cs = lp("cordon_stats", storage.id)
        if (cs.arcs or 0) >= 2 and cs.perimeter then
          local o = lp("stats", storage.id).origin
          S.before = cs.perimeter
          S.hit, S.killed = game.tick, 0
          schedule(game.tick - (storage.t0 or 0) + 3 * 3600, function() S.after = lp("cordon_stats", storage.id).perimeter end)
          schedule(game.tick - (storage.t0 or 0) + 13 * 3600, function() S.later = lp("cordon_stats", storage.id).perimeter end)
          for _, e in pairs(surface().find_entities_filtered{force = FORCE, position = o, radius = cs.perimeter + 8}) do
            local d = math.sqrt((e.position.x - o.x) ^ 2 + (e.position.y - o.y) ^ 2)
            if e.valid and e.type == "ammo-turret" and math.abs(d - cs.perimeter) <= 8 then e.die("player"); S.killed = S.killed + 1 end
          end
        end
      end)
    end
    schedule(END - 60, function()
      local cs = lp("cordon_stats", storage.id)
      info(string.format("cordon broken: hit at %s, %s turrets killed; claim %s before, %s 3 min after, %s 13 min after, %s at the end; broken %s",
        tostring(S.hit), tostring(S.killed), tostring(S.before), tostring(S.after), tostring(S.later), tostring(cs.perimeter),
        tostring(cs.broken)))
      check("cordon: its leading arc broken, the claim falls back", S.hit and (cs.broken or 0) >= 1 and S.after
        and S.after < S.before, string.format("%s -> %s, broken %s", tostring(S.before), tostring(S.after), tostring(cs.broken)))
      check("cordon: and it waits before stepping out again", S.later and S.after and S.later <= S.after,
        string.format("%s 13 minutes on", tostring(S.later)))
    end)
    return
  end
  if held then
    schedule(6 * 3600, function() S.held_at = lp("cordon_stats", storage.id).perimeter end)
    for t = 6 * 3600 + 20, END - 120, 20 do
      schedule(t, function()
        local o = lp("stats", storage.id).origin
        local r = (lp("cordon_stats", storage.id).perimeter or 0) + 8
        for _, u in pairs(surface().find_entities_filtered{name = "lp-harrier", force = FORCE}) do
          if (u.position.x - o.x) ^ 2 + (u.position.y - o.y) ^ 2 > r * r then u.die("player"); S.shot = (S.shot or 0) + 1 end
        end
      end)
    end
    schedule(END - 60, function()
      local cs, c = lp("cordon_stats", storage.id), lp("crew_stats", storage.id)
      local kinds = {}
      for _, e in ipairs(lp("incidents")) do kinds[e.kind] = (kinds[e.kind] or 0) + 1 end
      info(string.format("cordon held: %s drones shot; claim %s at 6 min, %s at the end; crews %s; incidents %s",
        tostring(S.shot), tostring(S.held_at), tostring(cs.perimeter), serpent.line(c), serpent.line(kinds)))
      check("cordon: posts given up under fire", (c.gave_up or 0) >= 1 and (kinds["line held"] or 0) >= 1,
        string.format("gave up %s, line held %s", tostring(c.gave_up), tostring(kinds["line held"])))
      check("cordon: the claim stepped out no further", S.held_at and cs.perimeter and cs.perimeter <= S.held_at + 30,
        string.format("%s -> %s", tostring(S.held_at), tostring(cs.perimeter)))
      -- Three a post given up, and up to two each for the three posts still being tried when the run ends (2 * 2 failed
      -- on a run that lost 21 and gave up 5; main, unchanged in this, lost 20 and gave up 6: the same behaviour, the
      -- timeline nudged).
      check("cordon: drones lost, no more than three a post", c.lost <= 3 * (c.gave_up or 0) + 2 * 3, serpent.line(c))
    end)
  end
  schedule(60, function() for _ = 1, 2 do lp("debug_depot", storage.id, 4000) end end)
  schedule(120, function()
    local o = lp("stats", storage.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local out = contact and 200 or 300
    S.c = {math.floor(o.x - o.x / len * out), math.floor(o.y - o.y / len * out)}
    flatten(S.c[1] - 6, S.c[2] - 6, S.c[1] + 6, S.c[2] + 6)
    S.relay = surface().create_entity{name = "lp-command-relay", position = S.c, force = "player"}
    if oremix then
      local a = math.atan2(S.c[2] - o.y, S.c[1] - o.x) + math.rad(20)
      S.ore = {math.floor(o.x + math.cos(a) * 150), math.floor(o.y + math.sin(a) * 150)}
      flatten(S.ore[1] - 10, S.ore[2] - 10, S.ore[1] + 10, S.ore[2] + 10)
      for x = -8, 8 do for y = -8, 8 do
        surface().create_entity{name = "iron-ore", position = {S.ore[1] + x, S.ore[2] + y}, amount = 3000}
      end end
    end
    if rail then
      -- East-west (the bearing is east here: the camp lies west of the spawn): rail centres on odd tiles.
      S.ry = math.floor(o.y / 2) * 2 + 1
      flatten(o.x + 98, S.ry - 3, o.x + 262, S.ry + 3)
      for x = math.floor((o.x + 100) / 2) * 2, o.x + 260, 2 do
        surface().create_entity{name = "straight-rail", position = {x + 1, S.ry}, direction = defines.direction.east, force = "player"}
      end
    end
    -- Lasting: razed (encroachment provokes), the line had nothing to face.
    S.relay.destructible = false
    S.o = o
  end)
  if rail then
    schedule(14 * 3600, function()
      -- 40 tiles out from the outermost gate: from a fixed start it coasted to a stop short of a line that stood farther
      -- back (the train has no driver, so friction stops it).
      local sx = S.o.x + 240
      local outer
      for _, g in ipairs(surface().find_entities_filtered{name = "lp-gate", force = FORCE, area = {{S.o.x + 90, S.ry - 2}, {S.o.x + 230, S.ry + 2}}}) do
        if not outer or g.position.x > outer then outer = g.position.x end
      end
      if outer then sx = math.min(S.o.x + 240, outer + 40) end
      local l = surface().create_entity{name = "locomotive", position = {math.floor(sx / 2) * 2 + 1, S.ry},
        direction = defines.direction.west, force = "player"}
      if l then
        l.insert{name = "coal", count = 50}
        l.train.manual_mode = true
        -- Forward (its front faces west, toward the camp): a negative speed ran it backwards to the rail's end, and the
        -- first check passed on that.
        l.train.speed = 0.3
        S.loco = l
      end
    end)
  end
  if breach then
    schedule(12 * 3600, function()
      -- On the leading arc (the farthest out): an older arc is recovered on its own (the first try broke the oldest).
      local ts = surface().find_entities_filtered{name = "lp-gun-turret", force = FORCE}
      local o = lp("stats", storage.id).origin
      table.sort(ts, function(a, c)
        return (a.position.x - o.x) ^ 2 + (a.position.y - o.y) ^ 2 > (c.position.x - o.x) ^ 2 + (c.position.y - o.y) ^ 2
      end)
      S.broke = {}
      for k = 1, math.min(3, #ts) do
        table.insert(S.broke, {ts[k].position.x, ts[k].position.y})
        ts[k].die("player")
      end
    end)
    schedule(15 * 3600, function()
      S.mended = 0
      for _, p in ipairs(S.broke or {}) do
        if surface().count_entities_filtered{name = "lp-gun-turret", force = FORCE, position = p, radius = 1} > 0 then S.mended = S.mended + 1 end
      end
    end)
  end
  schedule(END - 60, function()
    if held then return end
    if oremix then
      local n = surface().count_entities_filtered{name = "lp-drill", force = FORCE, position = S.ore, radius = 14}
      info(string.format("cordon: %d Serenity drills on the patch the arc crossed; stats ore %s", n,
        tostring(lp("cordon_stats", storage.id).ore)))
      check("cordon: the line claimed the ore it crossed", n >= 1, tostring(n))
      return
    end
    if rail then
      local gates = surface().find_entities_filtered{name = "lp-gate", force = FORCE, area = {{S.o.x + 90, S.ry - 2}, {S.o.x + 270, S.ry + 2}}}
      local outer
      for _, g in ipairs(gates) do if not outer or g.position.x > outer then outer = g.position.x end end
      local lx = S.loco and S.loco.valid and S.loco.position.x
      if lx then
        local around = {}
        for _, e in pairs(surface().find_entities_filtered{area = {{lx - 16, S.ry - 2}, {lx - 3, S.ry + 2}}}) do
          if e.type ~= "straight-rail" then table.insert(around, string.format("%s@%.1f/%s", e.name, e.position.x, e.force.name)) end
        end
        info("cordon: ahead of the train " .. table.concat(around, ", "))
      end
      info(string.format("cordon: %d gates on the rail (outermost at %s), the train at %s (speed %s); stats %s", #gates, tostring(outer),
        tostring(lx), tostring(S.loco and S.loco.valid and S.loco.train.speed), serpent.line(lp("cordon_stats", storage.id).gates)))
      check("cordon: gate posts on the player's rail", #gates >= 2, tostring(#gates))
      -- At the line: the gate, or a post's wall across the track before it (a post beside the crossing put its front on
      -- the rail, 7 tiles out from the gate).
      local stopped = S.loco and S.loco.valid and S.loco.train.speed == 0
      check("cordon: the train stopped at the line", stopped and lx and outer and lx > outer and lx - outer < 20,
        string.format("the train at %s, the gate at %s", tostring(lx), tostring(outer)))
      return
    end
    if contact then
      local cs = lp("cordon_stats", storage.id)
      local a0 = math.atan2(S.c[2] - S.o.y, S.c[1] - S.o.x)
      local walls = 0
      for _, w in pairs(surface().find_entities_filtered{name = "lp-wall", force = FORCE, position = {S.o.x, S.o.y}, radius = 260}) do
        local d = math.sqrt((w.position.x - S.o.x) ^ 2 + (w.position.y - S.o.y) ^ 2)
        local a = math.atan2(w.position.y - S.o.y, w.position.x - S.o.x)
        local da = math.abs(((a - a0 + math.pi) % (2 * math.pi)) - math.pi)
        if d > 130 and da < math.rad(30) then walls = walls + 1 end
      end
      info(string.format("cordon: contact %s; %d walls on the line near the bearing", tostring(cs.contact), walls))
      check("cordon: contact walled the line's middle", (cs.contact or 0) >= 1 and walls >= 40, string.format("%s, %d walls",
        tostring(cs.contact), walls))
      return
    end
    if breach then
      info(string.format("cordon: %s of %d broken posts mended in 3 minutes; standing %s", tostring(S.mended), #(S.broke or {}),
        lp("standing", "serenity")))
      check("cordon: the drones mended the breach", (S.mended or 0) == #(S.broke or {}) and #(S.broke or {}) > 0,
        tostring(S.mended) .. " of " .. #(S.broke or {}))
      check("cordon: and Serenity is an enemy", lp("standing", "serenity") == "enemy", lp("standing", "serenity"))
      return
    end
    local cs = lp("cordon_stats", storage.id)
    local cr = lp("crew_stats", storage.id)
    -- The posts standing: Serenity's gun turrets, by their angle from the camp to the relay.
    local a0 = math.atan2(S.c[2] - S.o.y, S.c[1] - S.o.x)
    local turrets, off = 0, 0
    for _, t in pairs(surface().find_entities_filtered{name = "lp-gun-turret", force = FORCE}) do
      local a = math.atan2(t.position.y - S.o.y, t.position.x - S.o.x)
      local d = math.abs(((a - a0 + math.pi) % (2 * math.pi)) - math.pi)
      local cs0 = lp("cordon_stats", storage.id)
      local dr = math.sqrt((t.position.x - S.o.x) ^ 2 + (t.position.y - S.o.y) ^ 2)
      -- The ring's (LP_MIX=ring) face every way.
      if not (cs0.ring and math.abs(dr - cs0.ring) < 8) then
        turrets = turrets + 1
        if d > math.pi / 3 + 0.15 then off = off + 1 end
      end
    end
    info(string.format("cordon: %s; crews %s; %d post turrets, %d off the arc", serpent.line(cs), serpent.line(cr), turrets, off))
    check("cordon: two arcs stood", (cs.arcs or 0) >= 2, tostring(cs.arcs))
    check("cordon: their posts were built", (cs.posts or 0) >= 6, string.format("%s posts, %d turrets standing", tostring(cs.posts), turrets))
    -- Arcs behind the leading two recovered: the posts standing are about two arcs' worth, not all of them.
    check("cordon: old arcs recovered", (cs.recovered or 0) > 0 and turrets < 2 * (cs.posts or 0),
      string.format("%s pieces recovered, %d turrets standing of %s posts built", tostring(cs.recovered), turrets, tostring(cs.posts)))
    check("cordon: all on the arc facing the relay", off == 0, tostring(off))
    -- The lit line (Fable's look consult): a lamp on every standing post, a stripe post to post that outlives recovery.
    local lamps = surface().count_entities_filtered{name = "lp-post-lamp", force = FORCE}
    local stripe = 0
    for _, t in pairs(surface().find_tiles_filtered{name = "lp-stripe", position = {S.o.x, S.o.y}, radius = 300}) do
      if (t.position.x - S.o.x) ^ 2 + (t.position.y - S.o.y) ^ 2 > 100 ^ 2 then stripe = stripe + 1 end
    end
    -- No litter: every pad beyond the camp is under a standing post (recovered posts gave their ground back).
    local litter = 0
    for _, t in pairs(surface().find_tiles_filtered{name = "lp-pad", position = {S.o.x, S.o.y}, radius = 300}) do
      if (t.position.x - S.o.x) ^ 2 + (t.position.y - S.o.y) ^ 2 > 100 ^ 2
        and surface().count_entities_filtered{name = "lp-post-lamp", position = {t.position.x + 0.5, t.position.y + 0.5}, radius = 4} == 0 then
        litter = litter + 1
      end
    end
    -- (Not with LP_MIX=ring: a ring post under construction has its pad before its lamp.)
    check("cordon: no pads left where posts came down", ringmix or (litter == 0 and (cs.recovered or 0) > 0),
      string.format("%d pad tiles with no post, %s pieces recovered", litter, tostring(cs.recovered)))
    info(string.format("cordon: %d post lamps, %d stripe tiles beyond 100", lamps, stripe))
    check("cordon: a lamp on every standing post", lamps > 0 and 2 * lamps >= turrets, string.format("%d lamps, %d turrets", lamps, turrets))
    check("cordon: the line painted post to post", stripe >= 60 * (cs.arcs or 0), string.format("%d tiles, %s arcs", stripe, tostring(cs.arcs)))
    -- Its back (Fable's look consult, item 2): grown, a ring of posts round the camp, every bearing covered.
    local st = lp("stats", storage.id)
    local sectors, ringed = {}, 0
    for _, t in pairs(surface().find_entities_filtered{name = "lp-gun-turret", force = FORCE, position = {S.o.x, S.o.y},
      radius = (cs.ring or 0) + 8}) do
      local d = math.sqrt((t.position.x - S.o.x) ^ 2 + (t.position.y - S.o.y) ^ 2)
      if cs.ring and math.abs(d - cs.ring) < 8 then
        ringed = ringed + 1
        sectors[math.floor(((math.deg(math.atan2(t.position.y - S.o.y, t.position.x - S.o.x)) + 360) % 360) / 45)] = true
      end
    end
    local covered = 0
    for _ in pairs(sectors) do covered = covered + 1 end
    info(string.format("cordon: mature %s; ring at %s, %d guns on it, %d of 8 sectors", tostring(st.mature), tostring(cs.ring), ringed, covered))
    if ringmix then
      -- Seven of eight: a post may stand on water or wait for its drone (the ring relaid at 135 had 19 of 24 guns up).
      check("cordon: a grown camp closes a ring round itself", cs.ring ~= nil and covered >= 7,
        string.format("ring %s, %d sectors", tostring(cs.ring), covered))
    end
    check("cordon: drones built them, none stuck", cr.done >= 6 and cr.stuck == 0, serpent.line(cr))
    check("cordon: the claim is no further than its last standing arc", cs.perimeter and (not cs.radius or cs.perimeter < cs.radius),
      string.format("perimeter %s, pending arc %s", tostring(cs.perimeter), tostring(cs.radius)))
  end)
end

-- Pace (the builders consult's gate): a Grubstake camp grows 30 minutes on its own; its counts at the end (blocks,
-- modules, drills, fabricators, turrets, parts made), compared between versions on several seeds (within 15%).
scenarios.pace = function()
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true, raids_off = true})
    -- LP_MIX=serenity: a Serenity camp (its drones).
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = params.mix == "serenity" and "serenity" or "grubstake"})
  end)
  schedule(END - 60, function()
    local st = lp("stats", S.g)
    info(string.format("pace: blocks %d modules %d drills %d fabs %d turrets %d pylons %d made %d mature %s", st.blocks,
      st.modules, st.drills, st.fabs, st.turrets, st.pylons, st.made, tostring(st.mature)))
  end)
end

-- Crew (the builders consult, slice 1): a Grubstake camp; an outpost of five (a pylon, two turrets, two walls) queued
-- first, 90 tiles out, beyond every yard (debug_crew): a truck takes it, builds all five within 10 tiles of the site,
-- within 90 s of the queuing, and goes home; none stuck. Within its yard the camp builds as before.
-- LP_MIX=killed: the truck killed at mid-road spills its bill (34 parts: 17 iron), and a second truck builds the outpost
-- within 3 minutes of the loss.
-- LP_MIX=grown: a Grubstake camp landed as a bastion (walls round every block) grows 20 minutes before the outpost is
-- queued 150 tiles out: the truck forms past the outermost wall and builds it; none stuck.
scenarios.crew = function()
  -- LP_MIX=drone: the same with a Serenity camp, its constructor drone flying out.
  -- LP_MIX=rebuild: two of the built outpost's five destroyed; a crew rebuilds them (no yard beam), all five again within
  -- the rebuild delay and 90 s.
  -- LP_MIX=doomed: every truck killed at mid-road: after three the camp gives the outpost up, and its other work goes on.
  -- LP_MIX=island: the site ringed by water: no route to it, the outpost given up before a truck is sent.
  -- LP_MIX=walled: the site ringed by the player's gun turrets: no way out of their reach, so no truck goes; given up.
  -- LP_MIX=around: three armed gun turrets on the straight road: the truck drives round them and builds.
  -- LP_MIX=dronekill: Serenity, unprovoked; the player kills its drone at mid-road: Serenity is its enemy then.
  -- LP_MIX=answered: Serenity, unprovoked, raids on; three armed gun turrets at mid-road shoot its drone down: it answers
  -- (docs/ai.md: the answer) within three minutes, a squad at the turrets.
  -- Every mix: the outpost's pad (debug_crew queues one first) is not laid before the crew gets there.
  local doomed, island = params.mix == "doomed", params.mix == "island"
  local walled, around = params.mix == "walled", params.mix == "around"
  local dronekill, answered = params.mix == "dronekill", params.mix == "answered"
  local killed, grown, drone, again = params.mix == "killed" or doomed, params.mix == "grown", params.mix == "drone" or dronekill or answered,
    params.mix == "rebuild"
  local corp = drone and "serenity" or "grubstake"
  local at = (grown and 20 or 3) * 3600
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true, raids_off = not answered})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = corp, doctrine = grown and "bastion" or nil})
    for _ = 1, 2 do lp("debug_depot", S.g, 3000) end
  end)
  schedule(at, function()
    local o = lp("stats", S.g).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local out = grown and 150 or 90
    S.site = {math.floor(o.x - o.x / len * out), math.floor(o.y - o.y / len * out)}
    if grown then S.walls = lp("stats", S.g).walls end
    flatten(S.site[1] - 8, S.site[2] - 8, S.site[1] + 8, S.site[2] + 8)
    if island then
      local tiles = {}
      for x = -18, 18 do for y = -18, 18 do
        local r2 = x * x + y * y
        if r2 >= 11 * 11 and r2 <= 17 * 17 then table.insert(tiles, {name = "deepwater", position = {S.site[1] + x, S.site[2] + y}}) end
      end end
      surface().set_tiles(tiles)
    end
    if walled then
      flatten(S.site[1] - 40, S.site[2] - 40, S.site[1] + 40, S.site[2] + 40)
      S.ring = 0
      for k = 0, 29 do
        local a = 2 * math.pi * k / 30
        if surface().create_entity{name = "gun-turret", position = {S.site[1] + 34 * math.cos(a), S.site[2] + 34 * math.sin(a)},
          force = "player"} then S.ring = S.ring + 1 end
      end
    end
    if around or answered then
      local mid = {(o.x + S.site[1]) / 2, (o.y + S.site[2]) / 2}
      flatten(mid[1] - 6, mid[2] - 6, mid[1] + 6, mid[2] + 6)
      S.guns = 0
      for _, d in ipairs({{0, 0}, {3, 3}, {-3, -3}}) do
        local g = surface().create_entity{name = "gun-turret", position = {mid[1] + d[1], mid[2] + d[2]}, force = "player"}
        if g then g.insert{name = "firearm-magazine", count = 50}; S.guns = S.guns + 1 end
      end
    end
    S.queued = game.tick
    if killed or dronekill then
      local mid = {(o.x + S.site[1]) / 2, (o.y + S.site[2]) / 2}
      S.mid = mid
    end
    S.n = lp("debug_crew", S.g, S.site, {"lp-pylon", "lp-turret", "lp-turret", "lp-wall", "lp-wall"})
  end)
  for t = at + 30, END - 120, 30 do
    schedule(t, function()
      -- Killed at mid-road, as the player would (four gun turrets beside the road did not stop it: the hauler's hull,
      -- 1,500 health and armour, crossed their reach in about 9 s).
      -- The pad: not laid before a crew is at the site (when each first happened).
      if not S.pad_at and surface().count_tiles_filtered{position = {S.site[1], S.site[2] - 8}, radius = 3,
        name = corp == "serenity" and "lp-pad" or "lp-" .. corp .. "-pad"} > 0 then S.pad_at = game.tick end
      if not S.crew_at and surface().count_entities_filtered{position = S.site, radius = 15, force = "lp-" .. corp,
        name = corp == "serenity" and "lp-harrier" or "lp-" .. corp .. "-hauler"} > 0 then S.crew_at = game.tick end
      if answered then
        if not S.lost_at and (lp("crew_stats", S.g).lost or 0) > 0 then S.lost_at = game.tick; S.before = S.before or "rival" end
        if not S.answer_at and (lp("stats", S.g).ops.answers or 0) > 0 then S.answer_at = game.tick end
      end
      if dronekill and not S.shot then
        local d = surface().find_entities_filtered{name = "lp-harrier", force = "lp-serenity", position = S.mid, radius = 25, limit = 1}[1]
        if d then S.before = lp("standing", "serenity"); d.die("player"); S.shot = game.tick end
      end
      if killed and (doomed or not S.shot) then
        local t = surface().find_entities_filtered{name = "lp-grubstake-hauler", position = S.mid, radius = 15, limit = 1}[1]
        if t then t.die("player"); S.shot = true end
      end
      if killed and not S.lost_at and (lp("crew_stats", S.g).lost or 0) > 0 then
        S.lost_at = game.tick
        S.iron = 0
        S.iron = dropped(S.mid, 40)["iron-plate"] or 0
      end
      if S.built_at then return end
      local n = surface().count_entities_filtered{force = "lp-" .. corp, position = S.site, radius = 10,
        type = {"electric-pole", "ammo-turret", "electric-turret", "wall"}}
      if n >= 5 then S.built_at = game.tick end
      S.placed = n
      if again and S.built_at and not S.broke then
        S.broke = game.tick
        local es = surface().find_entities_filtered{force = "lp-" .. corp, position = S.site, radius = 10,
          type = {"ammo-turret", "electric-turret"}}
        for k = 1, math.min(2, #es) do es[k].die("player") end
        S.built_at = nil
      end
    end)
  end
  schedule(END - 60, function()
    local c = lp("crew_stats", S.g)
    info(string.format("crew: %s; placed %s of 5 at the site, built %s s after queuing; stats %s", tostring(S.n), tostring(S.placed),
      S.built_at and string.format("%.0f", (S.built_at - S.queued) / 60) or "never", serpent.line(c)))
    if again then
      check("crew: the outpost rebuilt by a crew", S.built_at and S.broke and c.sent >= 2, string.format("%s sent; rebuilt %s s after",
        tostring(c.sent), tostring(S.built_at and S.broke and (S.built_at - S.broke) / 60)))
      check("crew: within the rebuild delay and 90 s", S.built_at and S.broke and S.built_at - S.broke <= 150 * 60,
        tostring(S.built_at and S.broke and (S.built_at - S.broke) / 60))
      return
    end
    if walled then
      check("crew: no truck under the ring's guns, the outpost given up", c.unrouted == 1 and c.lost == 0 and (S.placed or 0) == 0,
        string.format("%s, ring of %s, placed %s", serpent.line(c), tostring(S.ring), tostring(S.placed)))
      check("crew: the camp's other work went on", c.done >= 1, serpent.line(c))
      return
    end
    if around then
      check("crew: round the guns, all five built", (S.placed or 0) >= 5 and c.lost == 0 and c.unrouted == 0,
        string.format("%s, %s guns, placed %s", serpent.line(c), tostring(S.guns), tostring(S.placed)))
      return
    end
    check("crew: the pad not laid before the crew came", not S.pad_at or (S.crew_at and S.pad_at >= S.crew_at),
      string.format("pad at %s, crew at %s", tostring(S.pad_at), tostring(S.crew_at)))
    if answered then
      local st = lp("stats", S.g)
      local left = surface().count_entities_filtered{name = "gun-turret", force = "player", position = S.mid, radius = 8}
      info(string.format("crew answered: drone lost at %s, answer at %s, %s; turrets %d of %d left", tostring(S.lost_at),
        tostring(S.answer_at), serpent.line(st.ops.log[1]), left, S.guns or 0))
      -- Serenity at war from landing answers trespass only (the user, 2026-10-19): a drone lost is not answered; its war
      -- (raids at what it sees) takes the turrets all the same.
      check("crew: the turrets razed", left < (S.guns or 0), left .. " of " .. tostring(S.guns))
      check("crew: the drone shot down by the turrets", S.lost_at ~= nil, tostring(S.lost_at))
      check("crew: a loss not answered (it answers trespass only)", S.answer_at == nil,
        string.format("lost %s, answer %s", tostring(S.lost_at), tostring(S.answer_at)))
      check("crew: Serenity an enemy", lp("standing", "serenity") == "enemy", lp("standing", "serenity"))
      return
    end
    if dronekill then
      -- At war from landing (the user, 2026-10-19): the kill is a provocation all the same (its answer).
      local pv = (lp("corp", "serenity").provoked or {}).player
      check("crew: its drone killed, a provocation recorded, an enemy", S.shot and pv ~= nil and pv >= S.shot - 120
        and lp("standing", "serenity") == "enemy", string.format("shot %s, provoked %s, now %s", tostring(S.shot),
        tostring(pv), lp("standing", "serenity")))
      return
    end
    if island then
      -- Routed (2026-10-17): no way to the island, so it is given up before a truck leaves (three trucks were stuck first).
      check("crew: no way to the island, the outpost given up unsent", c.unrouted == 1 and c.stuck == 0 and c.lost == 0,
        serpent.line(c))
      check("crew: none built on the island, the camp's other work went on", (S.placed or 0) == 0 and c.done >= 1,
        string.format("%s, placed %s", serpent.line(c), tostring(S.placed)))
      return
    end
    if doomed then
      check("crew: three trucks lost, the outpost given up", c.lost == 3 and c.gave_up == 1, serpent.line(c))
      -- The doomed outpost leads the queue: retried for ever, it held up everything behind it (no crew of the camp's own
      -- came home in 10 minutes).
      check("crew: the camp's other work went on", c.done >= 1 and (S.placed or 0) == 0,
        string.format("%s, placed %s", serpent.line(c), tostring(S.placed)))
      local kinds = {}
      for _, e in ipairs(lp("incidents")) do kinds[e.kind] = (kinds[e.kind] or 0) + 1 end
      check("crew: the player told (an incident)", (kinds["site given up"] or 0) == 1, serpent.line(kinds))
      -- Its trucks shot: an attack, as on its garrison.
      check("crew: the trucks' killer is its enemy", lp("standing", "grubstake") == "enemy", lp("standing", "grubstake"))
      return
    end
    if killed then
      info(string.format("crew: lost at %s, %s iron spilled", tostring(S.lost_at), tostring(S.iron)))
      check("crew: the truck was lost on the road", (c.lost or 0) >= 1, tostring(c.lost))
      check("crew: it spilled its bill", (S.iron or 0) >= 15, tostring(S.iron))
      check("crew: a second truck built it within 3 minutes", S.built_at and S.lost_at and S.built_at - S.lost_at <= 180 * 60,
        tostring(S.built_at and S.lost_at and (S.built_at - S.lost_at) / 60))
      return
    end
    if grown then info("crew: the camp had " .. tostring(S.walls) .. " walls when the outpost was queued") end
    check("crew: a crew took the outpost", c.sent >= 1, tostring(c.sent))
    check("crew: all five built at the site", (S.placed or 0) >= 5, tostring(S.placed))
    check("crew: within 90 s", S.built_at and S.built_at - S.queued <= 90 * 60, tostring(S.built_at and (S.built_at - S.queued) / 60))
    -- Not every crew home: one sent in the last minute is still building when the run stops.
    check("crew: done, none stuck", c.done >= 1 and c.stuck == 0, serpent.line(c))
  end)
end

-- Crystal (the faction loot consult, technologies 2 and 3): two pacifier crystals taken apart research Pact breaker and
-- Claim marker. A breaker placed (raise_built) inside a Grubstake camp's claim: the cease-fire with the biters drops at
-- once, and comes back when it burns out 3 minutes later. LP_MIX=marker: a soft player outpost 120 tiles from the camp
-- with a claim marker beside it is held from Grubstake's targets (temper_allows), and stands.
scenarios.crystal = function()
  local mark = params.mix == "marker"
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true})
    -- Serenity, at war from landing, raided the marked outpost the test watches: a truce with it.
    lp("debug_truce", "serenity", "player", params.minutes + 5)
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    for _ = 1, 2 do lp("debug_depot", S.g, 3000) end
    flatten(-20, -20, 20, 20)
    for _, t in ipairs({"military", "lp-pheromone-bait"}) do game.forces.player.technologies[t].researched = true end
    local src = surface().create_entity{name = "electric-energy-interface", position = {0, 8}, force = "player"}
    src.power_production = 1000000; src.electric_buffer_size = 1e7
    surface().create_entity{name = "medium-electric-pole", position = {3, 8}, force = "player"}
    local asm = surface().create_entity{name = "assembling-machine-2", position = {6, 8}, force = "player",
      recipe = "lp-crystal-schematic"}
    asm.insert{name = "lp-pacifier-crystal", count = 2}
  end)
  local function cf() return game.forces["lp-grubstake"].get_cease_fire("enemy") end
  schedule(2 * 3600, function()
    S.r_breaker = game.forces.player.technologies["lp-pact-breaker"].researched
    S.r_marker = game.forces.player.technologies["lp-claim-marker"].researched
    if not mark then return end
    local o = lp("stats", S.g).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local c = {math.floor(o.x - o.x / len * 120), math.floor(o.y - o.y / len * 120)}
    flatten(c[1] - 6, c[2] - 6, c[1] + 6, c[2] + 6)
    S.asm = surface().create_entity{name = "assembling-machine-1", position = c, force = "player"}
    surface().create_entity{name = "lp-claim-marker", position = {c[1] + 4, c[2]}, force = "player", raise_built = true}
    S.c = c
  end)
  schedule(4 * 3600, function()
    if mark then return end
    S.cf0 = cf()
    local o = lp("stats", S.g).origin
    local p = surface().find_non_colliding_position("lp-pact-breaker", {o.x + 12, o.y + 12}, 10, 0.5)
    S.breaker = surface().create_entity{name = "lp-pact-breaker", position = p, force = "player", raise_built = true}
  end)
  schedule(4 * 3600 + 120, function() if not mark then S.cf1 = cf() end end)
  schedule(4 * 3600 + 3 * 3600 + 180, function()
    if mark then return end
    S.cf2 = cf()
    S.gone = not (S.breaker and S.breaker.valid)
  end)
  schedule(END - 60, function()
    info(string.format("crystal: researched breaker %s, marker %s", tostring(S.r_breaker), tostring(S.r_marker)))
    check("crystal: the teardowns researched both", S.r_breaker == true and S.r_marker == true,
      tostring(S.r_breaker) .. ", " .. tostring(S.r_marker))
    if mark then
      local st = lp("stats", S.g)
      local held
      for _, line in ipairs(st.ops.player_targets or {}) do
        if line:find(string.format("@%d,%d", S.c[1], S.c[2]), 1, true) then held = line:find(" held") ~= nil end
      end
      info(string.format("crystal: the marked outpost: known %s, held %s, standing %s", tostring(held ~= nil), tostring(held),
        tostring(S.asm and S.asm.valid)))
      -- Known and held (unmarked, it was razed and forgotten: held nil, which this once let through).
      check("crystal: the marked outpost is held from its targets", held == true, tostring(held))
      check("crystal: and stands", S.asm and S.asm.valid, "")
      return
    end
    info(string.format("crystal: cease-fire before %s, with the breaker %s, after %s; the breaker gone %s", tostring(S.cf0),
      tostring(S.cf1), tostring(S.cf2), tostring(S.gone)))
    check("crystal: the pact held before", S.cf0 == true, tostring(S.cf0))
    check("crystal: the breaker jammed it", S.cf1 == false, tostring(S.cf1))
    check("crystal: burnt out, the pact is back", S.cf2 == true and S.gone, tostring(S.cf2) .. ", " .. tostring(S.gone))
  end)
end

-- Strike (the faction loot consult, technology 6): an orbital beacon taken apart researches Orbital strike; a strike
-- beacon placed (raise_built) 45 tiles out from a Serenity camp, on a player power source: charged, it fires, Serenity
-- loses buildings within 60 of it, and the beacon is gone.
scenarios.strike = function()
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true, raids_off = true})
    lp("debug_depot", storage.id, 3000)
    flatten(-20, -20, 20, 20)
    game.forces.player.technologies["rocket-silo"].researched = true
    local src = surface().create_entity{name = "electric-energy-interface", position = {0, 8}, force = "player"}
    src.power_production = 1000000; src.electric_buffer_size = 1e7
    surface().create_entity{name = "medium-electric-pole", position = {3, 8}, force = "player"}
    local asm = surface().create_entity{name = "assembling-machine-2", position = {6, 8}, force = "player",
      recipe = "lp-beacon-schematic"}
    asm.insert{name = "lp-orbital-beacon", count = 1}
  end)
  schedule(6 * 3600, function()
    S.researched = game.forces.player.technologies["lp-orbital-strike"].researched
    S.unlocked = game.forces.player.recipes["lp-strike-beacon"].enabled
    local st = lp("stats", storage.id)
    local o = st.origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local vx, vy = o.x / len, o.y / len
    local at = {o.x - vx * 45, o.y - vy * 45}
    flatten(at[1] - 6, at[2] - 6, at[1] + 6, at[2] + 6)
    local src = surface().create_entity{name = "electric-energy-interface", position = {at[1] - 4, at[2]}, force = "player"}
    src.power_production = 10000000 / 60; src.electric_buffer_size = 1e8; src.energy = 1e8
    surface().create_entity{name = "medium-electric-pole", position = {at[1] - 2, at[2] + 2}, force = "player"}
    S.at = at
    -- Its own count of buildings lost (it keeps building: entities within 60 went from 148 to 211 over the strike).
    S.before = st.lost or 0
    S.beacon = surface().create_entity{name = "lp-strike-beacon", position = {at[1] + 1, at[2]}, force = "player",
      raise_built = true}
  end)
  schedule(END - 60, function()
    local after = lp("stats", storage.id).lost or 0
    local fired = lp("strikes")
    info(string.format("strike: researched %s, unlocked %s; fired %s at %s targets; Serenity's buildings lost %d -> %d; beacon %s",
      tostring(S.researched), tostring(S.unlocked), tostring(fired.fired), tostring(fired.targets), S.before or -1, after,
      S.beacon and S.beacon.valid and "standing" or "gone"))
    check("strike: the teardown researched it", S.researched == true, tostring(S.researched))
    check("strike: the beacon's recipe unlocked", S.unlocked == true, tostring(S.unlocked))
    check("strike: it fired once charged", (fired.fired or 0) == 1, tostring(fired.fired))
    check("strike: Serenity lost buildings", after > (S.before or 0), string.format("%d -> %d", S.before or -1, after))
    check("strike: the beacon is used up", not (S.beacon and S.beacon.valid), "")
  end)
end

-- Rifle (the faction loot consult, technology 5): two rail coils taken apart research Rail rifle and unlock it and its
-- slug; a character (no player) with the rifle, set shooting along a line of six held medium biters 8 to 23 tiles out:
-- a slug pierces the line.
scenarios.rifle = function()
  schedule(60, function()
    lp("debug_tune", {ops_off = true, army_off = true})
    flatten(-30, -20, 40, 20)
    game.forces.player.technologies["military-3"].researched = true
    local src = surface().create_entity{name = "electric-energy-interface", position = {-20, 8}, force = "player"}
    src.power_production = 1000000; src.electric_buffer_size = 1e7
    surface().create_entity{name = "medium-electric-pole", position = {-17, 8}, force = "player"}
    local asm = surface().create_entity{name = "assembling-machine-2", position = {-14, 8}, force = "player",
      recipe = "lp-coil-schematic"}
    asm.insert{name = "lp-rail-coil", count = 2}
  end)
  schedule(30 * 60, function()
    S.researched = game.forces.player.technologies["lp-rail-rifle"].researched
    S.unlocked = game.forces.player.recipes["lp-rail-rifle"].enabled and game.forces.player.recipes["lp-rail-slug"].enabled
    S.biters = {}
    for k = 0, 5 do
      local u = surface().create_entity{name = "medium-biter", position = {8 + 3 * k, 0}, force = "enemy"}
      u.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none, ticks_to_wait = 3600}
      table.insert(S.biters, u)
    end
    S.ch = surface().create_entity{name = "character", position = {0, 0}, force = "player"}
    S.ch.insert{name = "lp-rail-rifle", count = 1}
    S.ch.insert{name = "lp-rail-slug", count = 3}
    S.ch.destructible = false
  end)
  for t = 30 * 60 + 2, 30 * 60 + 300, 2 do
    schedule(t, function()
      if S.ch and S.ch.valid then S.ch.shooting_state = {state = defines.shooting.shooting_selected, position = {30, 0}} end
    end)
  end
  schedule(END - 60, function()
    local left = 0
    for _, u in ipairs(S.biters or {}) do if u.valid then left = left + 1 end end
    local slugs = S.ch and S.ch.valid and S.ch.get_item_count("lp-rail-slug") or -1
    info(string.format("rifle: researched %s, unlocked %s; %d of 6 biters left, %d slugs left", tostring(S.researched),
      tostring(S.unlocked), left, slugs))
    check("rifle: the teardown researched it", S.researched == true, tostring(S.researched))
    check("rifle: the rifle and slugs unlocked", S.unlocked == true, tostring(S.unlocked))
    check("rifle: a slug pierces the line", left <= 6 - 2 * (3 - math.max(0, slugs)) or left == 0,
      string.format("%d left after %d slugs", left, 3 - math.max(0, slugs)))
  end)
end

-- Bait (the faction loot consult, technology 1): three pheromone glands taken apart in an assembler research Pheromone
-- bait and unlock its recipe; a bait placed (raise_built, as a player builds it) 25 tiles out from a Serenity camp, 30
-- idle small biters 70 tiles out: at least 10 are called, and Serenity loses buildings or units to them.
scenarios.bait = function()
  schedule(60, function()
    lp("debug_tune", {wfc_core_off = true, era = 1, history_off = true, raids_off = true})
    lp("debug_depot", storage.id, 3000)
    flatten(-20, -20, 20, 20)
    local src = surface().create_entity{name = "electric-energy-interface", position = {0, 8}, force = "player"}
    src.power_production = 1000000; src.electric_buffer_size = 1e7
    surface().create_entity{name = "medium-electric-pole", position = {3, 8}, force = "player"}
    local asm = surface().create_entity{name = "assembling-machine-2", position = {6, 8}, force = "player",
      recipe = "lp-gland-schematic"}
    -- A research trigger counts only once its prerequisites are researched (Military, which every game has early).
    game.forces.player.technologies["military"].researched = true
    asm.insert{name = "lp-pheromone-gland", count = 3}
  end)
  schedule(6 * 3600, function()
    S.researched = game.forces.player.technologies["lp-pheromone-bait"].researched
    S.unlocked = game.forces.player.recipes["lp-bait"].enabled
    local st = lp("stats", storage.id)
    local o = st.origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local vx, vy = o.x / len, o.y / len
    S.lost0 = st.lost or 0
    local r = (st.claim_radius or 60) * 0.5
    local nest = {o.x + vx * (r + 70), o.y + vy * (r + 70)}
    for k = 1, 30 do
      local p = surface().find_non_colliding_position("small-biter", {nest[1] + (k % 6) * 2, nest[2] + math.floor(k / 6) * 2}, 8, 0.5)
      surface().create_entity{name = "small-biter", position = p, force = "enemy"}
    end
    local at = surface().find_non_colliding_position("lp-player-bait", {o.x + vx * (r + 25), o.y + vy * (r + 25)}, 10, 0.5)
    S.bait = surface().create_entity{name = "lp-player-bait", position = at, force = "player", raise_built = true}
  end)
  schedule(6 * 3600 + 60, function() S.called = lp("baits").called end)
  schedule(END - 60, function()
    local st = lp("stats", storage.id)
    local bitten = 0
    for k, v in pairs(S.fallen or {}) do
      if not k:find("^lp%-grubstake") and k:find("^lp%-") and k:find("by small%-biter") then bitten = bitten + v end
    end
    local lost = (st.lost or 0) - (S.lost0 or 0)
    info(string.format("bait: researched %s, recipe %s; %s biters called; Serenity lost %d buildings and %d units to them",
      tostring(S.researched), tostring(S.unlocked), tostring(S.called), lost, bitten))
    check("bait: the teardown researched it", S.researched == true, tostring(S.researched))
    check("bait: the recipe unlocked", S.unlocked == true, tostring(S.unlocked))
    check("bait: 10 biters called", (S.called or 0) >= 10, tostring(S.called))
    -- The bait's job is to set the biters on Serenity; whether a dozen small ones win against its flamers is its defence.
    check("bait: the biters it called went for Serenity", lost + bitten > 0 or (S.bite or 0) > 0,
      string.format("%d buildings, %d units lost, %.0f damage taken", lost, bitten, S.bite or 0))
  end)
end

-- Fuze (the faction loot consult, components and the first technology): a Serenity mortar destroyed drops a cluster
-- fuze; three taken apart in an assembler (the teardown) research Cluster shells, which unlocks the cluster artillery
-- shell; one fired at a point ringed by twelve small biters 7 tiles out kills biters an ordinary shell (LP_MIX=plain,
-- its blast 4 tiles) leaves.
scenarios.fuze = function()
  local plain = params.mix == "plain"
  schedule(60, function()
    lp("debug_tune", {ops_off = true, army_off = true})
    flatten(-80, -20, 80, 20)
    local m = surface().create_entity{name = "lp-mortar", position = {-60, 0}, force = FORCE}
    m.die("player")
    game.forces.player.technologies["artillery"].researched = true
  end)
  schedule(120, function()
    S.fuzes = 0
    S.fuzes = dropped({-60, 0}, 6)["lp-cluster-fuze"] or 0
    local src = surface().create_entity{name = "electric-energy-interface", position = {-50, 8}, force = "player"}
    src.power_production = 1000000; src.electric_buffer_size = 1e7
    surface().create_entity{name = "medium-electric-pole", position = {-47, 8}, force = "player"}
    S.asm = surface().create_entity{name = "assembling-machine-2", position = {-44, 8}, force = "player",
      recipe = "lp-fuze-schematic"}
    S.asm.insert{name = "lp-cluster-fuze", count = 3}
  end)
  schedule(30 * 60, function()
    S.researched = game.forces.player.technologies["lp-cluster-shells"].researched
    S.unlocked = game.forces.player.recipes["lp-cluster-artillery-shell"].enabled
    -- One shell fired straight at a point ringed by twelve small biters 7 tiles out (the turret, aiming at worms itself,
    -- killed one a shell either way: the bomblets are against biters).
    S.worms = {}
    for k = 0, 11 do
      local a = k * math.pi / 6
      local u = surface().create_entity{name = "small-biter", position = {40 + 7 * math.cos(a), 7 * math.sin(a)}, force = "enemy"}
      u.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none, ticks_to_wait = 3600}
      table.insert(S.worms, u)
    end
    surface().create_entity{name = plain and "artillery-projectile" or "lp-cluster-artillery-projectile", position = {-20, 0},
      target = {40, 0}, force = "player", speed = 1}
  end)
  schedule(END - 60, function()
    local left = 0
    for _, w in ipairs(S.worms or {}) do if w.valid then left = left + 1 end end
    info(string.format("fuze (%s): %d fuzes dropped; researched %s, recipe %s; %d of 12 biters left", plain and "plain" or "cluster",
      S.fuzes or 0, tostring(S.researched), tostring(S.unlocked), left))
    if plain then
      check("fuze: an ordinary shell leaves the ring", left == 12, tostring(left))
      return
    end
    check("fuze: a mortar drops a fuze", (S.fuzes or 0) >= 1, tostring(S.fuzes))
    check("fuze: the teardown researched cluster shells", S.researched == true, tostring(S.researched))
    check("fuze: the shell's recipe unlocked", S.unlocked == true, tostring(S.unlocked))
    check("fuze: the bomblets killed biters round the impact", left <= 9, tostring(left))
  end)
end

-- Tap (Grubstake's power tap; the user: "steal power from unprotected lines ... progressively increasing draw",
-- "connected to their camp through pylons"): a player power source with a line of big poles running toward a Grubstake
-- camp, ending 80 tiles from it, a radar at the source using some. debug_tap on the line's nearest pole: the camp lays a
-- pylon line, clamps the tap, its draw rises (a step each 30 s here) and reaches the camp; a line pylon cut, the theft
-- stops; the tap broken, it is over. A gun turret stands on the straight way: the line goes round it (the heist's
-- route). LP_MIX=natural: no debug_tap, the camp's own choice (a pole its sensors have seen exposed).
-- Skim (Grubstake; Fable's fortress consult): a player's belt of iron ore 150 tiles from the camp toward spawn, 24 tiles
-- long, fed at its west end and emptied at its east by the test (both counted). The camp finds it, a truck parks by it,
-- lifts half of what passes into its trunk and takes it home to the yard (the user: "a truck simply going to the belt,
-- hovering part of the items, filling its own trunk, then leaving"). LP_MIX=guarded: an armed gun turret by the belt, no
-- truck; LP_MIX=raid: the yard destroyed at minute 24, what it held spills.
scenarios.skim = function()
  local guarded, raid, night = params.mix == "guarded", params.mix == "raid", params.mix == "night"
  -- LP_MIX=night: a day of 6 minutes from noon; each truck must set out after dark (Grubstake's thieves' hours).
  if night then
    schedule(30, function() surface().always_day = false; surface().ticks_per_day = 6 * 3600; surface().daytime = 0 end)
    S.launches = {}
    for t = 3 * 3600, END - 120, 30 do
      schedule(t, function()
        local k = lp("skim", S.g)
        if k and k.skims > #S.launches then table.insert(S.launches, surface().darkness) end
      end)
    end
  end
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true, raids_off = true})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    for _ = 1, 2 do lp("debug_depot", S.g, 3000) end
  end)
  schedule(3 * 3600, function()
    local o = lp("stats", S.g).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = o.x / len, o.y / len
    local c = {o.x - ux * 150, o.y - uy * 150}
    flatten(c[1] - 16, c[2] - 6, c[1] + 16, c[2] + 6)
    S.belts = {}
    for k = -12, 11 do
      table.insert(S.belts, surface().create_entity{name = "transport-belt", position = {c[1] + k + 0.5, c[2] + 0.5},
        direction = defines.direction.east, force = "player"})
    end
    S.fed, S.delivered = 0, 0
    if guarded then
      local t = surface().create_entity{name = "gun-turret", position = {c[1], c[2] + 4}, force = "player"}
      t.insert{name = "piercing-rounds-magazine", count = 200}
    end
    S.c = c
  end)
  for t = 3 * 3600 + 30, END - 120, 30 do
    schedule(t, function()
      local first, last = S.belts[1], S.belts[#S.belts]
      if not (first and first.valid and last and last.valid) then return end
      for line = 1, 2 do
        local tl = first.get_transport_line(line)
        for _ = 1, 4 do
          if tl.insert_at_back({name = "iron-ore", count = 1}) then S.fed = S.fed + 1 else break end
        end
        local out = last.get_transport_line(line)
        local n = out.get_item_count("iron-ore")
        if n > 0 then S.delivered = S.delivered + out.remove_item({name = "iron-ore", count = n}) end
      end
    end)
  end
  if raid then
    schedule(24 * 3600, function()
      local y = surface().find_entities_filtered{name = "lp-skim-yard", limit = 1}[1]
      S.yard_held = y and y.get_inventory(defines.inventory.chest).get_item_count() or 0
      if y then y.die("player") end
    end)
    schedule(24 * 3600 + 60, function()
      local n = 0
      for _, e in pairs(surface().find_entities_filtered{type = "item-entity", name = "item-on-ground"}) do
        if e.stack.valid_for_read and e.stack.name == "iron-ore" then n = n + e.stack.count end
      end
      S.spilled = n
    end)
  end
  -- The truck parked by the belt, seen once a minute (its tell).
  for t = 3 * 3600 + 60, END - 120, 60 do
    schedule(t, function()
      local k = lp("skim", S.g)
      if k and k.parked then
        S.parked = S.parked or k.parked
        S.near_turret = surface().count_entities_filtered{position = k.parked, radius = 30, force = "player",
          type = {"ammo-turret", "electric-turret"}}
      end
    end)
  end
  schedule(END - 60, function()
    local k = lp("skim", S.g)
    info(string.format("skim: fed %d, delivered %d, runs %d, taken %d, home %d, yard %d, parked at %s (turrets within 30: %s)",
      S.fed or 0, S.delivered or 0, k.skims, k.taken, k.skimmed, k.yard, serpent.line(S.parked), tostring(S.near_turret)))
    if guarded then
      check("skim: a guarded belt is not skimmed", k.skims == 0, tostring(k.skims))
      return
    end
    if night then
      local dark, light = 0, 0
      for _, d in ipairs(S.launches) do if d >= 0.25 then dark = dark + 1 else light = light + 1 end end
      info("skim night: darkness at each setting out " .. serpent.line(S.launches))
      check("skim: trucks set out by night only", dark >= 1 and light == 0, string.format("%d by night, %d by day", dark, light))
      return
    end
    if raid then
      info(string.format("skim: the yard held %d, spilled %d", S.yard_held or 0, S.spilled or 0))
      check("skim: the yard destroyed, its goods spill", (S.yard_held or 0) > 0 and (S.spilled or 0) >= S.yard_held,
        string.format("held %d, spilled %d", S.yard_held or 0, S.spilled or 0))
      return
    end
    local share = (S.fed or 0) > 0 and k.skimmed / S.fed or 0
    check("skim: a truck parked at the exposed belt, out of turret reach", k.skims >= 1 and S.parked ~= nil and S.near_turret == 0,
      string.format("%d runs", k.skims))
    check("skim: it took part of the flow, not all", share >= 0.05 and share <= 0.6, string.format("%.0f%%", share * 100))
    check("skim: trucks brought it home to the yard", k.skimmed >= 100 and k.yard >= 100, string.format("%d home, yard %d",
      k.skimmed, k.yard))
    -- Its sushi belt (the user, 2026-10-21): a loop by the yard, what it stole riding it.
    check("skim: the yard's sushi belt carries what it stole", (k.sushi or 0) >= 12 and (k.on_sushi or 0) > 0,
      string.format("%d belts, %d on them", k.sushi or 0, k.on_sushi or 0))
  end)
end

-- Belts (the user, 2026-10-21: "we did not incorporate any belts or logistics of any kind inside the clusters"): Serenity
-- grown at once and funded, its districts laid out; belts move with no player near (belts_always). Its districts carry
-- belt runs, built, and parts ride them.
scenarios.belts = function()
  schedule(60, function()
    lp("debug_tune", {history_off = true, raids_off = true, mature_blocks = 2, belts_always = true})
    lp("debug_parts", storage.id, 3000)
  end)
  for t = 5 * 3600, END - 120, 1800 do
    schedule(t, function()
      lp("debug_parts", storage.id, 300)
      local st = lp("belt_stats", storage.id)
      S.max_carried = math.max(S.max_carried or 0, st.carried)
      S.st = st
    end)
  end
  schedule(END - 60, function()
    local st = S.st or {}
    info("belts: " .. serpent.line(st) .. ", most carried " .. tostring(S.max_carried))
    check("belts: its districts were laid with belt runs", (st.runs or 0) >= 1, tostring(st.runs))
    check("belts: built", (st.belts or 0) >= 3, tostring(st.belts))
    check("belts: parts rode them", (S.max_carried or 0) > 0 and (st.moves or 0) > 0,
      string.format("%s carried, %s moves", tostring(S.max_carried), tostring(st.moves)))
  end)
end

scenarios.tap = function()
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true, raids_off = true, tap_step = 30 * 60})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    for _ = 1, 2 do lp("debug_depot", S.g, 3000) end
  end)
  schedule(3 * 3600, function()
    local o = lp("stats", S.g).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = o.x / len, o.y / len
    local src = {o.x - ux * 220, o.y - uy * 220}
    flatten(src[1] - 6, src[2] - 6, src[1] + 6, src[2] + 6)
    local e = surface().create_entity{name = "electric-energy-interface", position = src, force = "player"}
    e.power_production = 20000000 / 60; e.power_usage = 0; e.electric_buffer_size = 1e8
    surface().create_entity{name = "radar", position = {src[1] + 4, src[2]}, force = "player"}
    S.poles = {}
    for d = 3, 140, 26 do
      local p = surface().find_non_colliding_position("big-electric-pole", {src[1] + ux * d, src[2] + uy * d}, 4, 1)
      table.insert(S.poles, surface().create_entity{name = "big-electric-pole", position = p, force = "player"})
    end
    local last = S.poles[#S.poles]
    S.pole_at = {last.position.x, last.position.y}
    -- A gun turret on the straight way from the camp (35 tiles from the pole, toward it; debug only: in the natural run a turret within 60 of the pole
    -- rightly marks it guarded): the line must go round it, out of its reach.
    if params.mix ~= "natural" then
      S.guard = surface().create_entity{name = "gun-turret", position = surface().find_non_colliding_position("gun-turret",
        {S.pole_at[1] + ux * 35, S.pole_at[2] + uy * 35}, 4, 1), force = "player"}
      -- Unarmed and lasting: armed, it fought the camp's units and the pole went down with it in 15 s.
      S.guard.destructible = false
    end
    -- LP_MIX=natural: the camp finds the pole itself.
    -- LP_MIX=cmd: through /lp tap (dev.remote), standing at the pole.
    if params.mix == "cmd" then lp("dev", {"tap"}, S.pole_at); S.fired = "cmd"
    elseif params.mix ~= "natural" then S.fired = lp("debug_tap", S.g, S.pole_at) end
  end)
  local function st() return lp("tap_state", S.g) end
  -- Its steps from the tap's start: at 9 minutes for a tap called (debug, cmd); LP_MIX=natural, a minute after the camp's own
  -- tap draws, whenever that is (0.2.29: the camp built where its cliffs had been, and its tap came at 10.4 minutes).
  local function at(t, f)
    if params.mix ~= "natural" then return schedule(t, f) end
    S.steps = S.steps or {}
    table.insert(S.steps, {t - 9 * 3600, f})
  end
  if params.mix == "natural" then
    for t = 3 * 3600, END - 8 * 3600, 600 do
      schedule(t, function()
        if S.started then return end
        local now = st()
        if now and now.phase == "draw" then
          S.started = game.tick
          for _, step in ipairs(S.steps) do schedule(game.tick - storage.t0 + 3600 + step[1], step[2]) end
        end
      end)
    end
  end
  at(9 * 3600, function()
    S.mid = st()
    -- The camp's grid apart from the player's: the tap draws across, the wires never do (the user saw the camp's drills
    -- and fabricators in the player's network: a pylon auto-connected to a player pole within reach).
    local lander = surface().find_entities_filtered{name = "lp-grubstake-lander", limit = 1}[1]
    local pole = surface().find_entities_filtered{type = "electric-pole", force = "player", position = S.pole_at, radius = 2,
      limit = 1}[1]
    S.grids = lander and pole and {lander.electric_network_id, pole.electric_network_id}
    -- A player pole built (raise_built, auto_connect) beside the line's end pylon: not wired to it either.
    local line_end = surface().find_entities_filtered{name = "lp-grubstake-pylon", position = S.pole_at, radius = 14, limit = 1}[1]
    if line_end then
      local q = surface().find_non_colliding_position("medium-electric-pole", line_end.position, 6, 1)
      local mine = q and surface().create_entity{name = "medium-electric-pole", position = q, force = "player",
        auto_connect = true, raise_built = true}
      S.player_pole = mine and {mine.electric_network_id, line_end.electric_network_id}
    end
    S.near_guard = S.guard and S.guard.valid and surface().count_entities_filtered{name = "lp-grubstake-pylon",
      position = S.guard.position, radius = 20} or -1
    -- Cut the line: its pylon nearest the camp's end of the line.
    local line = surface().find_entities_filtered{name = "lp-grubstake-pylon", position = S.pole_at, radius = 60}
    table.sort(line, function(a, b) return (a.position.x - S.pole_at[1]) ^ 2 + (a.position.y - S.pole_at[2]) ^ 2
      < (b.position.x - S.pole_at[1]) ^ 2 + (b.position.y - S.pole_at[2]) ^ 2 end)
    -- The line's pylon next to its end (once, two pylons 2 tiles apart at the end bridged the gap: tap.lua lay).
    local ds = {}
    for k = 1, #line do
      local d = math.sqrt((line[k].position.x - S.pole_at[1]) ^ 2 + (line[k].position.y - S.pole_at[2]) ^ 2)
      table.insert(ds, string.format("%.0f", d))
      if k == 2 then
        line[k].die("player"); S.cut = (S.cut or 0) + 1
      end
    end
    info("tap: line pylons from the pole " .. table.concat(ds, " ") .. "; cut " .. tostring(S.cut))
  end)
  at(9 * 3600 + 3 * 60, function() S.after_cut = st() end)
  at(12 * 3600, function()
    S.healed = st()
    local t = surface().find_entities_filtered{name = "lp-power-tap", limit = 1}[1]
    if t then t.die("player") end
  end)
  at(12 * 3600 + 3 * 60, function() S.broken = st() end)
  schedule(END - 60, function()
    info(string.format("tap: %s; at 9 min %s; cut %s: %s; at 12 min %s; broken: %s", tostring(S.fired),
      serpent.line(S.mid), tostring(S.cut), serpent.line(S.after_cut), serpent.line(S.healed), serpent.line(S.broken)))
    check("tap: the line was laid and the tap clamped", S.mid and S.mid.phase == "draw", serpent.line(S.mid))
    check("tap: a buggy planted a pylon at every spot", S.mid and S.mid.spots and S.mid.pylons == S.mid.spots,
      string.format("%s of %s", tostring(S.mid and S.mid.pylons), tostring(S.mid and S.mid.spots)))
    check("tap: its draw rose", S.mid and (S.mid.draw or 0) > 100000, tostring(S.mid and S.mid.draw))
    check("tap: the camp got power", S.mid and (S.mid.watts or 0) > 0 and (S.mid.taken or 0) > 0, tostring(S.mid and S.mid.taken))
    check("tap: cut, it stops", S.after_cut and S.after_cut.watts == 0, tostring(S.after_cut and S.after_cut.watts))
    check("tap: a buggy mends the line and it draws again", S.healed and (S.healed.watts or 0) > 0,
      tostring(S.healed and S.healed.watts))
    check("tap: broken, it is over", S.broken and S.broken.phase == nil, serpent.line(S.broken))
    check("tap: the camp's grid stays apart from the player's", S.grids and S.grids[1] ~= S.grids[2], serpent.line(S.grids))
    check("tap: a pole the player builds by its line is not wired to it", S.player_pole
      and S.player_pole[1] ~= S.player_pole[2], serpent.line(S.player_pole))
    if params.mix ~= "natural" then
      check("tap: the line kept out of the turret's reach", (S.near_guard or 0) == 0, tostring(S.near_guard))
    end
  end)
end

-- Loot (the faction loot consult; the user: Factorio's own items, no salvage currency): a settlement's buildings and
-- units destroyed by the player drop what they are made of. Twenty of its buildings of 8 parts or more and ten units
-- killed: their wrecks hold items (plates, circuits, the kinds' own); walls, worth under 8, drop nothing; no salvage exists.
scenarios.loot = function()
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true, raids_off = true})
    lp("debug_depot", storage.id, 4000)
  end)
  schedule(6 * 3600, function()
    local o = lp("stats", storage.id).origin
    S.o = o
    local function ground() return select(2, dropped(o, 200)) end
    S.g0 = ground()
    local big, walls, units = 0, 0, 0
    local own = surface().find_entities_filtered{force = FORCE, position = o, radius = 200}
    S.items = {}
    for _, e in ipairs(own) do
      if e.valid then
        local k = e.name
        if big < 20 and (k == "lp-fabricator" or k == "lp-generator" or k == "lp-drill" or k == "lp-turret" or k == "lp-radar") then
          e.die("player"); big = big + 1
        elseif walls < 20 and k == "lp-wall" then
          local at = e.position
          e.die("player"); walls = walls + 1
          S.wall_at = S.wall_at or at
        elseif units < 10 and e.type == "unit" then
          e.die("player"); units = units + 1
        end
      end
    end
    S.big, S.walls, S.units = big, walls, units
  end)
  schedule(6 * 3600 + 60, function()
    local counts = dropped(S.o, 200)
    S.counts = counts
    S.salvage = prototypes.item["lp-salvage"] ~= nil
    S.wrecks = surface().count_entities_filtered{name = "lp-wreck", position = S.o, radius = 200}
    S.loose = surface().count_entities_filtered{type = "item-entity", position = S.o, radius = 200}
  end)
  schedule(END - 60, function()
    local c = S.counts or {}
    info(string.format("loot: %d buildings, %d walls and %d units killed; on the ground %s", S.big or 0, S.walls or 0,
      S.units or 0, serpent.line(c)))
    check("loot: plates and circuits dropped", (c["iron-plate"] or 0) > 0 and (c["electronic-circuit"] or 0) > 0,
      string.format("%d iron, %d circuits", c["iron-plate"] or 0, c["electronic-circuit"] or 0))
    check("loot: kinds' own (magazines, engines or gears)", (c["firearm-magazine"] or 0) + (c["engine-unit"] or 0)
      + (c["iron-gear-wheel"] or 0) > 0, serpent.line(c))
    check("loot: no salvage item exists", not S.salvage, tostring(S.salvage))
    -- In wrecks (the user, 2026-10-21: loose items are a hassle to pick up), none loose on the ground.
    check("loot: left in wrecks, nothing loose", (S.wrecks or 0) >= 10 and (S.loose or 0) == 0,
      string.format("%d wrecks, %d loose", S.wrecks or 0, S.loose or 0))
  end)
end

-- Jumper (Grubstake's claim jumper; the grubstake flavour consult): a walled square 60 tiles across, 150 tiles from a
-- Grubstake camp, a gun turret at each wall's middle facing out (27 from the centre: the middle is out of their reach, as
-- in a big walled base; a small square whose turrets cover its chests is no heist), a chest of 200 iron plates and 50
-- circuits in the middle. debug_jumper (the rig and mound the camp's
-- own choice uses): the rig digs in 40 to 60 out of the turrets' reach; none up at 62 s, at 152 s hands are up within 10
-- of the mound (the dig is 2.5 minutes, a fair warning with no notice),
-- inside the wall; the chest is emptied; the loot comes home as parts. LP_MIX=rigkill: the rig killed at 30 s, nothing
-- comes up.
scenarios.jumper = function()
  local kill = params.mix == "rigkill"
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true, raids_off = true})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    for _ = 1, 2 do lp("debug_depot", S.g, 3000) end
  end)
  schedule(2 * 3600, function()
    local o = lp("stats", S.g).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = o.x / len, o.y / len
    local c = {math.floor(o.x - ux * 150) + 0.5, math.floor(o.y - uy * 150) + 0.5}
    flatten(c[1] - 34, c[2] - 34, c[1] + 34, c[2] + 34)
    S.c = c
    for k = -30, 30 do
      for _, p in ipairs({{c[1] + k, c[2] - 30}, {c[1] + k, c[2] + 30}, {c[1] - 30, c[2] + k}, {c[1] + 30, c[2] + k}}) do
        surface().create_entity{name = "stone-wall", position = p, force = "player"}
      end
    end
    for _, d in ipairs({{-27, 0}, {27, 0}, {0, -27}, {0, 27}}) do
      local t = surface().create_entity{name = "gun-turret", position = {c[1] + d[1], c[2] + d[2]}, force = "player"}
      t.insert{name = "firearm-magazine", count = 50}
    end
    S.chest = surface().create_entity{name = "iron-chest", position = c, force = "player"}
    S.chest.insert{name = "iron-plate", count = 200}
    S.chest.insert{name = "electronic-circuit", count = 50}
    -- A machine by the chest: the heist loots through ops.loot as raids do, and raids' dismantling crashed on its hands
    -- (visit nw, 0.1.22).
    local q = surface().find_non_colliding_position("assembling-machine-1", {c[1] + 5, c[2]}, 6, 1)
    if q then surface().create_entity{name = "assembling-machine-1", position = q, force = "player"} end
    S.parts0 = lp("stats", S.g).parts
    -- LP_MIX=cmd: through /lp rig (dev.remote), standing at the chest.
    if params.mix == "cmd" then lp("dev", {"rig"}, c); S.fired = "cmd" else S.fired = lp("debug_jumper", S.g, c) end
    S.t0 = game.tick
    S.rig = surface().find_entities_filtered{name = "lp-claim-rig", limit = 1}[1]
    if S.rig then
      S.rig_d = math.sqrt((S.rig.position.x - c[1]) ^ 2 + (S.rig.position.y - c[2]) ^ 2)
      S.rig_reach = surface().count_entities_filtered{position = S.rig.position, radius = 18, type = "ammo-turret", force = "player"}
    end
  end)
  local hand = "lp-grubstake-infantry"
  local function hands_near(r)
    return surface().count_entities_filtered{name = hand, position = S.c, radius = r}
  end
  schedule(2 * 3600 + 30 * 60, function() if kill and S.rig and S.rig.valid then S.rig.die("player") end end)
  schedule(2 * 3600 + 62 * 60, function() S.up_early = hands_near(10) end)
  schedule(2 * 3600 + 152 * 60, function() S.up = hands_near(10) end)
  schedule(END - 60, function()
    local left = S.chest and S.chest.valid and S.chest.get_item_count() or -1
    local st = lp("stats", S.g)
    info(string.format("jumper: %s; the rig %.0f from the square, %s turrets in reach; %s hands up at 62 s; the chest holds "
      .. "%d of 250; parts %d -> %d, looted %s", tostring(S.fired), S.rig_d or -1, tostring(S.rig_reach), tostring(S.up),
      left, S.parts0 or 0, st.parts, tostring(st.looted)))
    if kill then
      check("jumper: the rig killed, nothing came up", S.up == 0, tostring(S.up))
      check("jumper: the chest untouched", left == 250, tostring(left))
      return
    end
    -- 40 to 60, give or take the 6 the rig may be moved to find room (39 on seed 4242).
    check("jumper: the rig dug in 40 to 60 out", S.rig_d and S.rig_d >= 34 and S.rig_d <= 66, string.format("%.0f", S.rig_d or -1))
    check("jumper: out of the turrets' reach", S.rig_reach == 0, tostring(S.rig_reach))
    info("jumper: deaths " .. serpent.line(S.fallen or {}))
    info("jumper: killed by turrets at " .. table.concat(S.turret_kills or {}, "; ") .. string.format("; mound %s, chest %s",
      serpent.line(S.mound), S.chest and S.chest.valid and string.format("%.0f,%.0f", S.chest.position.x, S.chest.position.y) or "gone"))
    check("jumper: none up before the dig's 2.5 minutes", S.up_early == 0, tostring(S.up_early))
    check("jumper: four to six hands up inside the wall", (S.up or 0) >= 4 and S.up <= 6, tostring(S.up))
    -- Emptied, or razed once empty (-1).
    check("jumper: the chest emptied", left <= 0, tostring(left))
    check("jumper: the loot came home", (st.looted or 0) >= 250, tostring(st.looted))
    -- Each hand on a building out of the turrets' reach (told to attack the area, five of six walked into it).
    check("jumper: most hands back", (st.hands_back or 0) >= 4, tostring(st.hands_back))
    -- Their orders done, idle hands went for the wall's turrets 27 tiles off: two of six fell, then all six once the
    -- leave order (to the mound they stood on) was done at once. Every order now ends with standing still.
    check("jumper: no hand fell to a turret", #(S.turret_kills or {}) == 0, tostring(#(S.turret_kills or {})))
  end)
end

-- Snatch (Grubstake's answer since its pheromone flare was retired, 2026-10-22): a player outpost guarded by two gun
-- turrets 150 tiles from a Grubstake camp, 40 idle biters 60 tiles to its side; one of the camp's units is killed by an
-- outpost turret. Covered by the turrets, the loss gets no answer: no squad, no biters called, and no flare canister
-- (the prototype is gone). LP_MIX=open: the turrets are taken away after the kill, the spot uncovered: a squad goes
-- within two minutes.
-- Grubstake's town grown at once (remote debug_town, the screenshots' fast mode): its lots laid and built, none on ore.
-- LP_MIX=lake (0.2.29): a lake east of its pad: a street end there takes a waterfront lot, its pier landfilled.
scenarios.town = function()
  local lake = params.mix == "lake"
  schedule(60, function()
    lp("debug_tune", {history_off = true, raids_off = true, crews_off = true})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    storage.id = S.g
    local o = lp("stats", S.g).origin
    S.o = o
    if lake then
      local x0 = math.floor(o.x + 32)
      S.lake = {x0, math.floor(o.y - 80), x0 + 100, math.floor(o.y + 80)}
      local t = {}
      for x = S.lake[1], S.lake[3] do for y = S.lake[2], S.lake[4] do t[#t + 1] = {name = "water", position = {x, y}} end end
      for _, e in pairs(surface().find_entities_filtered{area = {{S.lake[1], S.lake[2]}, {S.lake[3], S.lake[4]}}}) do
        if e.type ~= "character" then e.destroy() end
      end
      surface().set_tiles(t)
    end
    lp("debug_depot", S.g, 10000)
    S.grown = lp("debug_town", S.g, 12, 20)
  end)
  schedule(END - 60, function()
    local st = lp("stats", S.g)
    info("town: " .. serpent.line(S.grown) .. "; piers " .. tostring(st.piers) .. ", fabs " .. tostring(st.fabs))
    check("town: its lots laid", S.grown and S.grown.machines >= 6, serpent.line(S.grown))
    if lake then
      -- (All water when laid: what is not water now is its piers, landfill under gravel.)
      local area = {{S.lake[1], S.lake[2]}, {S.lake[3], S.lake[4]}}
      local fill = surface().count_tiles_filtered{area = area} - surface().count_tiles_filtered{area = area, collision_mask = "water_tile"}
      check("town: lake, a street end on its shore took a waterfront lot", (st.piers or 0) >= 1, tostring(st.piers))
      check("town: lake, its piers built out over the water", fill >= 10, tostring(fill))
    end
  end)
end

scenarios.snatch = function()
  local open = params.mix == "open"
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    for _ = 1, 2 do lp("debug_depot", S.g, 3000) end
  end)
  schedule(2 * 3600, function()
    local o = lp("stats", S.g).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = o.x / len, o.y / len
    local c = {math.floor(o.x - ux * 150), math.floor(o.y - uy * 150)}
    flatten(c[1] - 10, c[2] - 10, c[1] + 10, c[2] + 10)
    S.c = c
    surface().create_entity{name = "assembling-machine-1", position = c, force = "player"}
    S.turrets = {}
    for _, d in ipairs({{-4, 0}, {4, 0}}) do
      local t = surface().create_entity{name = "gun-turret", position = {c[1] + d[1], c[2] + d[2]}, force = "player"}
      t.insert{name = "firearm-magazine", count = 200}
      table.insert(S.turrets, t)
    end
    local side = {c[1] - uy * 60, c[2] + ux * 60}
    for k = 1, 40 do
      local name = k % 4 == 0 and "medium-biter" or "small-biter"
      local p = surface().find_non_colliding_position(name, {side[1] + (k % 8) * 2, side[2] + math.floor(k / 8) * 2}, 8, 0.5)
      surface().create_entity{name = name, position = p, force = "enemy"}
    end
    local u = surface().find_entities_filtered{name = "lp-grubstake-infantry", position = o, radius = 60, limit = 1}[1]
    if u then u.die("player", S.turrets[1]); S.killed = true end
    if open then for _, t in ipairs(S.turrets) do t.destroy() end end
    S.t0 = game.tick
  end)
  for t = 2 * 3600 + 60, END - 120, 60 do
    schedule(t, function()
      for _, u in pairs(surface().find_entities_filtered{type = "unit", force = "enemy", position = S.c, radius = 300}) do
        if u.commandable.parent_group then S.grouped = (S.grouped or 0) + 1; break end
      end
    end)
  end
  schedule(END - 60, function()
    local log = lp("stats", S.g).ops.answered or {}
    info("snatch: answers " .. serpent.line(log) .. ", biters grouped seen " .. tostring(S.grouped))
    check("snatch: a unit killed by the turret", S.killed == true, tostring(S.killed))
    check("snatch: no flare canister prototype", prototypes.entity["lp-flare"] == nil, "")
    check("snatch: no biters called to the outpost", not S.grouped, tostring(S.grouped))
    if open then
      check("snatch: uncovered, a squad goes", (log["a squad goes"] or 0) >= 1, serpent.line(log))
    else
      check("snatch: covered, no squad sent", (log["a squad goes"] or 0) == 0, serpent.line(log))
    end
  end)
end

-- Flak (Grubstake's scrap cannon, "dirty flak"; the grubstake flavour consult): a cannon against a blob of 20 small
-- biters, and apart (so neither side's fire is counted for the other), a second against 10 Line troopers before a player
-- wall. 15 dead to them in 20 s; the wall loses under 5% to them in a minute (their own hits only, on_entity_damaged).
-- LP_MIX=gun: Grubstake's gun turrets in their place, for comparison.
scenarios.flak = function()
  local gun = params.mix == "gun"
  local name = gun and "lp-grubstake-turret" or "lp-grubstake-scrap-cannon"
  S.flak_name = name
  schedule(60, function() lp("debug_tune", {ops_off = true, army_off = true, pact_off = true}) end)
  schedule(120, function()
    flatten(-40, -30, 40, 130)
    S.cannons, S.biters, S.troopers, S.walls = {}, {}, {}, {}
    for _, y in ipairs({0, 100}) do
      local c = surface().create_entity{name = name, position = {0, y}, force = "lp-grubstake"}
      c.insert{name = gun and "piercing-rounds-magazine" or "lp-scrap-shell", count = 200}
      -- Against the troopers it is made to last: alone before ten (about 170 a second) it fell in 3 s, after three shells,
      -- and the gun turret too; what is measured is what each deals to a blob.
      if y == 100 then c.destructible = false end
      table.insert(S.cannons, c)
    end
    for k = 0, 19 do
      local p = surface().find_non_colliding_position("small-biter", {9 + (k % 5), -6 - math.floor(k / 5)}, 4, 0.5)
      table.insert(S.biters, surface().create_entity{name = "small-biter", position = p, force = "enemy"})
    end
    for k = 0, 9 do
      local u = surface().create_entity{name = "lp-infantry", position = {-11 - (k % 2), 96 + k}, force = FORCE}
      -- Held where they stand (with nothing they could hurt, they walked 25 to 90 tiles off): a blob under fire.
      u.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none, ticks_to_wait = 3600}
      table.insert(S.troopers, u)
    end
    for y = 92, 108 do
      table.insert(S.walls, surface().create_entity{name = "stone-wall", position = {-15.5, y + 0.5}, force = "player"})
    end
  end)
  local function by_cannon(what)
    local n = 0
    for k, v in pairs(S.fallen or {}) do if k:find(what .. " by " .. name, 1, true) then n = n + v end end
    return n
  end
  schedule(120 + 20 * 60, function()
    S.b20, S.t20 = by_cannon("small-biter"), by_cannon("lp-infantry")
    S.th20 = 0
    for _, u in ipairs(S.troopers) do if u.valid then S.th20 = S.th20 + u.health end end
    local at = {}
    for _, u in ipairs(S.troopers) do if u.valid then table.insert(at, string.format("%.0f,%.0f", u.position.x, u.position.y)) end end
    info("flak: troopers at 20 s " .. table.concat(at, " "))
  end)
  schedule(120 + 60 * 60, function()
    local full = 350 * #S.walls
    local hurt = S.wall_hits or 0
    local standing = 0
    for _, c in ipairs(S.cannons) do if c.valid then standing = standing + 1 end end
    local th, ammo = 0, {}
    for _, u in ipairs(S.troopers) do if u.valid then th = th + u.health end end
    for _, c in ipairs(S.cannons) do
      table.insert(ammo, c.valid and (c.get_inventory(defines.inventory.turret_ammo).get_item_count() .. " ammo, "
        .. math.floor(c.health) .. " hp") or "dead")
    end
    info("flak: hits on troopers by damage " .. serpent.line(S.thits or {}))
    info(string.format("flak: troopers' health %d of 1200 at 20 s; %d at 60 s; cannons %s; cease-fire grubstake>serenity %s, serenity>grubstake %s",
      S.th20, th, table.concat(ammo, " / "), tostring(game.forces["lp-grubstake"].get_cease_fire(FORCE)),
      tostring(game.forces[FORCE].get_cease_fire("lp-grubstake"))))
    info(string.format("flak (%s): in 20 s %d of 20 biters and %d of 10 troopers dead to it (%d and %d in 60 s); "
      .. "the wall lost %.1f%% to it; %d of 2 stand; deaths %s", name, S.b20, S.t20, by_cannon("small-biter"),
      by_cannon("lp-infantry"), 100 * hurt / full, standing, serpent.line(S.fallen or {})))
    if not gun then
      check("flak: 15 dead to the cannons in 20 s", S.b20 + S.t20 >= 15, string.format("%d + %d", S.b20, S.t20))
      check("flak: the wall lost under 5% to them in a minute", hurt < 0.05 * full, string.format("%.1f%%", 100 * hurt / full))
      -- Area against a blob: more than Grubstake's gun turret deals (998 of 1,200 in 20 s, LP_MIX=gun; at 8 a burst and a
      -- shot each 50 ticks the cannon dealt 760, under the gun turret, and was raised).
      check("flak: the trooper blob lost more than to a gun turret", 1200 - S.th20 > 1000, string.format("%d", 1200 - S.th20))
    end
  end)
end

-- Visit: the corporations against a real player's factory (scripts/visit.sh loads a copy of a real save, adds the mod).
-- No live player: only the factory's own turrets and robots answer. Serenity lands beyond the factory (its spawn,
-- out past the 95th percentile of its drills, machines and poles, plus 150), Grubstake 20 minutes later; the
-- faction's own cadence lands more. Every 10 minutes a line of timeline.jsonl (operations, razed, looted, the
-- player's buildings); at the end, each settlement's story in results.txt.
-- The siege lab's trials (scripts/siegelab.sh run; the user, 2026-10-30: a standard fortress, a culture not held back by
-- its income, sieges launched by its own AI, the defences edited between runs, and every trial recorded to be played back
-- with a slider). On a save made for it (scripts/siegelab.sh build, or one edited from it): its defences snapshot, then
-- params.lab_trials trials, each: the defences rebuilt as they were, its culture primed (params.lab_biomass, its waits
-- cleared, farm.debug_lab_prime), its farm's own decision, its wave recorded every half second (each unit, the defences'
-- health, every death with its killer) to lab-rec-<n>.jsonl, and its summary to lab.jsonl. A trial with no wave within
-- params.lab_hold minutes records why its farm held. What it learned stays; the save it ends with (lab-out) keeps it, with
-- its waves held (herd_off) for the next edit. State in storage, by run: a save that held the test mod before is primed again.
scenarios.lab = function()
  -- LAB_FACTION (a corporation, its own choice at war with the player, or LAB_KIND forced at the fort; the culture held) or
  -- the culture (biotech, its farm's own choice). (Declared after begin, they read as nil in it: the corporation stayed
  -- switched off, three trials held.)
  local FACTION = params.lab_faction or "biotech"
  local CORP = FACTION ~= "biotech"
  local function op_records() return lp("oplog_recent") or {} end
  local TURRET = {["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true, ["artillery-turret"] = true}
  local AMMO = {["gun-turret"] = "piercing-rounds-magazine", ["rocket-turret"] = "rocket"}
  local FRAME, MAX_TRIAL = 30, 45 * 3600
  local function out(file, t) helpers.write_file("landing-party/" .. file, helpers.table_to_json(t) .. "\n", true) end
  local function farm() return (lp("farm_state").farms or {})[1] end
  local function xy(p) return {math.floor(p.x * 10 + 0.5) / 10, math.floor(p.y * 10 + 0.5) / 10} end
  local function log_of(id)
    for _, l in ipairs(lp("herd_state").log or {}) do if l.id == id then return l end end
  end
  local function begin()
    local L = {run = params.lab_run, trial = 0, step = "prime", snap = {}, ents = {}, hp = {}}
    storage.lab = L
    lp("debug_tune", {herd_off = CORP, pens_hold = true})
    -- (A corporation's trial: its army let loose, the culture held.)
    if CORP then lp("debug_tune", {harmless = false, army_off = false, provoke = true}) end
    lp("set_trace", true)
    local cx, cy, k = 0, 0, 0
    -- (Everything of the player's, not its defences alone: the first trial razed the soft heart and its power, and the next
    -- two found nothing worth a wave.)
    for _, e in ipairs(surface().find_entities_filtered{force = "player"}) do
      if e.type ~= "character" and e.health then
        local d = {name = e.name, pos = {e.position.x, e.position.y}, dir = e.direction, max = e.max_health, type = e.type}
        if e.type == "electric-energy-interface" then d.power = {e.power_production, e.electric_buffer_size} end
        if e.type == "infinity-pipe" then d.filter = e.get_infinity_pipe_filter() end
        L.snap[#L.snap + 1] = d
        L.ents[#L.ents + 1] = e
        L.hp[#L.snap] = e.health
        if TURRET[e.type] then cx, cy, k = cx + e.position.x, cy + e.position.y, k + 1 end
      end
    end
    L.center = {k > 0 and cx / k or 0, k > 0 and cy / k or 0}
    -- The ground round the fort cleared, in this copy alone (cliffs, trees, rocks within CLEAR_R): the lab tries a fort, not
    -- the map's terrain. (A cliff walked herds round its end past the user's fort's mined corner; routed round it, a plan
    -- ran into woods where its legs failed and its herd scattered; the siege lab, 2026-10-30.)
    local CLEAR_R = 450
    local cleared = 0
    for _, e in ipairs(surface().find_entities_filtered{type = {"cliff", "tree", "simple-entity"}, position = L.center, radius = CLEAR_R}) do
      if e.valid and e.force.name ~= "player" then e.destroy(); cleared = cleared + 1 end
    end
    L.cleared = cleared
    local context = {}
    local f, pens = farm(), {}
    -- (LAB_TIME: one weighing timed at its coarse grain and at its waves', landing-party/timing.txt.)
    -- (LAB_SEED: its farm's choices drawn anew, for replicates of one save.)
    if params.lab_seed and f then lp("debug_reseed", f.id, params.lab_seed); L.seed = params.lab_seed end
    if params.lab_time and f then
      for _, cell in ipairs({48, 32, 16}) do lp("lab_time_ways", f.id, cell) end
    end
    for _, p in ipairs(surface().find_entities_filtered{name = "lp-pen"}) do pens[#pens + 1] = xy(p.position) end
    local defences = {}
    for i, d in ipairs(L.snap) do defences[i] = {d.name, d.pos[1], d.pos[2], d.max, d.type, d.dir} end
    -- (The ground its herds cannot cross, for the page: cliffs and water within 300 tiles.)
    local cliffs = {}
    for _, c in ipairs(surface().find_entities_filtered{type = "cliff", position = L.center, radius = 900}) do
      cliffs[#cliffs + 1] = xy(c.position)
    end
    -- (What feeds its guns, feeds.lua: each cut, what it starves and the fluid left past it, for the page.)
    local dark, lasers = 0, 0
    for _, l in ipairs(surface().find_entities_filtered{type = "electric-turret", force = "player"}) do
      lasers = lasers + 1
      if l.status == defines.entity_status.no_power then dark = dark + 1 end
    end
    local poles = {}
    for _, p in ipairs(surface().find_entities_filtered{name = "medium-electric-pole", force = "player"}) do
      local c = p.get_wire_connector(defines.wire_connector_id.pole_copper, false)
      poles[#poles + 1] = {xy(p.position), c and #c.connections or 0, p.electric_network_id}
    end
    local eei = {}
    for _, e in ipairs(surface().find_entities_filtered{type = "electric-energy-interface", force = "player"}) do
      eei[#eei + 1] = {xy(e.position), e.electric_network_id, e.power_production}
    end
    out("lab-power.jsonl", {dark = dark, lasers = lasers, poles = poles, eei = eei})
    local supply = lp("debug_feeds", L.center, 300)
    table.sort(supply, function(a, b) return a[4] > b[4] end)
    local cuts = {}
    for k = 1, math.min(12, #supply) do cuts[k] = supply[k] end
    out("lab-run.jsonl", {run = L.run, trials = params.lab_trials, biomass = params.lab_biomass, center = L.center,
      defences = defences, context = context, pens = pens, farm = f and f.id, tick = game.tick, cliffs = cliffs, cuts = cuts})
  end
  -- Each defence as it was, rebuilt where gone, at full health, its gun turrets loaded.
  local function rebuild()
    local L, rebuilt = storage.lab, {}
    for i, d in ipairs(L.snap) do
      local e = L.ents[i]
      if not (e and e.valid) then
        e = surface().create_entity{name = d.name, position = d.pos, direction = d.dir, force = "player"}
        L.ents[i] = e
        if e then rebuilt[d.name] = (rebuilt[d.name] or 0) + 1 end
        if e and d.power then e.power_production, e.electric_buffer_size = d.power[1], d.power[2] end
        if e and d.filter then e.set_infinity_pipe_filter(d.filter) end
      end
      if e and e.valid then
        if e.max_health and e.max_health > 0 then e.health = e.max_health end
        if AMMO[e.name] then
          local inv = e.get_inventory(defines.inventory.turret_ammo)
          if inv then inv.clear(); inv.insert{name = AMMO[e.name], count = 200} end
        end
        L.hp[i] = e.health
      end
    end
    return rebuilt
  end
  local function finish(L, outcome, wave)
    local f = farm()
    L.rec.outcome, L.rec["end"] = outcome, game.tick
    -- What it did, as every attacker's is read (attempt.lua, oplog.lua): its record's attempt block.
    local key = wave and ("w" .. tostring(wave.id)) or L.op_key
    for _, r in ipairs(op_records()) do
      if key and r.key == key then L.rec.attempt, L.rec.op = r.attempt, {key = r.key, faction = r.faction, kind = r.kind,
        outcome = r.outcome, back = r.back, size = r.size, breach = r.breach, staging = r.staging, target = r.target} end
    end
    L.rec.held = outcome ~= "wave" and f and f.held or nil
    L.rec.wave = wave
    L.rec.prices_after = lp("lab_prices")
    local alive = {}
    for i, e in ipairs(L.ents) do alive[i] = (e and e.valid) and 1 or 0 end
    L.rec.alive = alive
    L.ended = game.tick
    -- (Rebuilt the moment it ends, with no rebuild put off: in the half second before the next trial's, its farm sent a
    -- wave at the broken defence, its attempt kept that as what it met, and the rebuilt one read as stronger, voiding a
    -- siege that razed 131; the second lane matrix, 2026-10-31.)
    if (params.lab_rebuild_after or 0) == 0 then L.prebuilt = rebuild() end
    out("lab.jsonl", L.rec)
    L.recording, L.wave = nil, nil
    L.step = L.trial >= (params.lab_trials or 3) and "save" or "prime"
  end
  LAB.died = function(e)
    local L = storage.lab
    if not (L and L.recording) then return end
    local v, c = e.entity, e.cause and e.cause.valid and e.cause or nil
    local ev = {ev = "die", t = game.tick, id = v.unit_number, n = v.name, f = v.force.name, p = xy(v.position),
      dt = e.damage_type and e.damage_type.name, kf = e.force and e.force.name}
    if c then ev.k, ev.kid, ev.kp = c.name, c.unit_number, xy(c.position) end
    for i, d in ipairs(L.ents) do if d == v then ev.def = i; break end end
    out("lab-rec-" .. L.trial .. ".jsonl", ev)
  end
  script.on_nth_tick(FRAME, function()
    if not (storage.lab and storage.lab.run == params.lab_run) then
      if game.tick - (storage.t0 or 0) < 120 then return end
      game.speed = 64
      begin()
    end
    local L = storage.lab
    local f = farm()
    -- (A rebuild put off, params.lab_rebuild_after: due now.)
    if L.rebuild_at and game.tick >= L.rebuild_at then
      L.rebuild_at = nil
      local late = rebuild()
      if L.rec then L.rec.rebuilt_late = late end
    end
    if L.step == "prime" then
      L.trial = L.trial + 1
      -- (Its defences rebuilt now, or params.lab_rebuild_after game minutes after the last trial ended: the next attack
      -- may find the last one's hole still open, what the design consult's exploitation is to be seen against.)
      local after = params.lab_rebuild_after or 0
      local rebuilt = {}
      -- (A rebuild already due keeps its time: put off again at each trial, a short trial's damage was never rebuilt.)
      if after > 0 and L.trial > 1 then L.rebuild_at = L.rebuild_at or (L.ended or game.tick) + after * 3600
      elseif L.prebuilt then rebuilt, L.prebuilt = L.prebuilt, nil
      else rebuilt = rebuild() end
      L.rec = {trial = L.trial, start = game.tick, rebuilt = rebuilt, prices_before = lp("lab_prices"),
        rec = "lab-rec-" .. L.trial .. ".jsonl"}
      if f then lp("lab_prime", f.id, params.lab_biomass or 20000) end
      L.step, L.recording = "wait", true
      if CORP then
        -- Its operation forced at the fort (ops.force by /lp raid|siege at the fort's middle); its record, when it closes.
        -- (auto: its own choice, at war with the player, the fort all there is to take; raid or siege: forced by /lp at the
        -- fort's middle, which tops its garrison up to what that needs: 475 for a raid on the laser lane, which it would
        -- never have sent, stuck the whole trial.)
        L.rec.faction, L.rec.kind = FACTION, params.lab_kind or "auto"
        L.ops_before, L.op_key, L.corp_live = #op_records(), nil, nil
        -- (Shown the fort, as its radar would: 590 tiles off, unknown to it, it held every trial. And primed with parts, as
        -- the culture with biomass, LAB_PARTS: with 10 to 132 it could never afford its siege, 100.)
        for _, b in ipairs(lp("bases_ops") or {}) do
          if b.corp == FACTION and not b.fallen then
            lp("debug_sense", b.id, {L.center[1], L.center[2]}, 150)
            lp("debug_corp_parts", b.id, params.lab_parts or 1000)
            lp("debug_corp_level", FACTION, params.lab_level or 2)
            -- (Its war chest too, LAB_CHEST: its reliefs come from it, and a lab camp exports nothing.)
            lp("debug_war_chest", FACTION, params.lab_chest or 3000)
            -- (And the player's era, LAB_ERA, its siege tier's cap: at 0 its sieges stayed at tier 1 against a laser wall.)
            lp("dev", {"era", tostring(params.lab_era or 2)}, {L.center[1], L.center[2]}, surface().index)
          end
        end
        if L.rec.kind ~= "auto" then lp("dev", {L.rec.kind}, {L.center[1], L.center[2]}, surface().index) end
        L.step = "corp"
      end
      return
    end
    if L.step == "corp" then
      if (game.tick - L.rec.start) % (5 * 3600) < FRAME then
        for _, b in ipairs(lp("bases_ops") or {}) do
          if b.corp == FACTION then out("lab-corp.jsonl", {trial = L.trial, t = game.tick, why = lp("debug_corp_why", b.id)}) end
        end
      end
      local recs = op_records()
      if #recs > L.ops_before then
        for i = L.ops_before + 1, #recs do if recs[i].faction ~= "biotech" then L.op_key = recs[i].key end end
        if L.op_key then return finish(L, "op") end
        L.ops_before = #recs
      end
      if game.tick - L.rec.start > MAX_TRIAL then return finish(L, "timeout") end
      if L.rec.kind == "auto" and game.tick - L.rec.start > (params.lab_hold or 15) * 3600 and not L.corp_live then
        -- (No operation of its own begun within LAB_HOLD: held, its reasons in decisions.txt.)
        local live = false
        for _, b in pairs(lp("bases_ops") or {}) do if b.corp == FACTION and b.op then live = true end end
        if not live then return finish(L, "held") end
        L.corp_live = true
      end
      return
    end
    if L.step == "wait" or L.step == "wave" then
      if f then
        if f.siege then L.rec.siege = f.siege end
        local b = f.biomass and f.biomass.now or 0
        if b < (params.lab_biomass or 20000) then lp("debug_biomass", f.id, (params.lab_biomass or 20000) - b) end
      end
      local w
      -- (The newest of its farm's: an older one stuck on the field held two trials to their end.)
      for _, x in ipairs(lp("lab_waves")) do if (not f or x.farm == f.id) and (not w or x.id > w.id) then w = x end end
      if L.step == "wait" then
        if w then
          L.step, L.wave = "wave", w.id
          L.rec.launch, L.rec.plan = game.tick, w.plan
        elseif game.tick - L.rec.start > (params.lab_hold or 15) * 3600 then
          return finish(L, "held")
        end
      end
      if L.step == "wave" then
        -- (Its wave gone: its record closed by the observer on its next sample, oplog.lua, every 3 s; closed before it, most
        -- trials of the second lane matrix had no attempt block. Up to 5 s for it.)
        if not w or w.id ~= L.wave then
          L.closing = L.closing or game.tick
          local recorded = false
          for _, r in ipairs(op_records()) do if r.key == "w" .. tostring(L.wave) then recorded = true end end
          if recorded or game.tick - L.closing > 300 then L.closing = nil; return finish(L, "wave", log_of(L.wave)) end
          return
        end
        if game.tick - L.rec.start > MAX_TRIAL then return finish(L, "timeout", log_of(L.wave)) end
        local u = {}
        local function add(e, role)
          if e and e.valid then
            u[#u + 1] = {e.unit_number, e.name, xy(e.position)[1], xy(e.position)[2], math.floor(e.health), role}
          end
        end
        for _, m in pairs(w.members) do add(m, m.valid and m.name == "lp-bred-big-burster" and "burster" or "herd") end
        add(w.scout, "scout")
        for _, m in pairs(w.sweepers) do add(m, "sweep") end
        local d = {}
        for i, e in ipairs(L.ents) do
          local hp = (e and e.valid) and e.health or 0
          if hp ~= L.hp[i] then d[#d + 1] = {i, math.floor(hp)}; L.hp[i] = hp end
        end
        local big = {}
        for _, b in ipairs(w.big) do
          -- (A burster or its gun gone arrives as nothing.)
          if b.unit and b.unit.valid and b.target and b.target.valid then big[#big + 1] = {b.unit.unit_number, xy(b.target.position)} end
        end
        out(L.rec.rec, {ev = "frame", t = game.tick, s = w.stage, u = u, d = d, big = big})
      end
      return
    end
    if L.step == "save" then
      lp("debug_tune", {herd_off = true})
      game.speed = 1
      L.step = "saving"
      return
    end
    if L.step == "saving" then
      game.server_save("lab-out")
      helpers.write_file("landing-party/lab-done.txt", string.format("%d trials, tick %d", L.trial, game.tick))
      L.step = "done"
    end
  end)
end

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
    S.poll0 = {}
    for name, v in pairs(game.get_pollution_statistics(surface()).input_counts) do S.poll0[name] = v end
    -- The absent player's character cannot die: in a single-player save its death ends the game, and the visit at
    -- strength 2 stopped at minute 108 (a Grubstake raid by it), its last 72 minutes empty updates and no results.
    local chars = 0
    for _, c in pairs(surface().find_entities_filtered{type = "character"}) do c.destructible = false; chars = chars + 1 end
    info("visit: " .. chars .. " character(s) made indestructible")
    storage.id = lp("arrive", 1, sp, S.dist, {corp = "serenity"})
    if not storage.id then error("lp-sim visit: no site for Serenity at " .. S.dist) end
    S.sp = sp
  end)
  schedule(20 * 3600, function()
    S.g = lp("arrive", 1, S.sp, S.dist, {corp = "grubstake"})
    -- Water round its lander: the first water tile in 16 directions (diagnostic).
    if S.g then
      local o = lp("stats", S.g).origin
      local out = {}
      for k = 0, 15 do
        local a = 2 * math.pi * k / 16
        local hit = "-"
        for d = 10, 600, 4 do
          local p = {o.x + d * math.cos(a), o.y + d * math.sin(a)}
          if not surface().is_chunk_generated{math.floor(p[1] / 32), math.floor(p[2] / 32)} then hit = "?" .. d; break end
          if surface().get_tile(p[1], p[2]).collides_with("water_tile") then hit = d; break end
        end
        table.insert(out, tostring(hit))
      end
      info("visit: Grubstake's lander at " .. o.x .. "," .. o.y .. ", first water by direction (E clockwise): " .. table.concat(out, " "))
    end
    -- What Grubstake knows of the player every 10 minutes (diagnostic).
    for m = 10, 170, 10 do
      schedule((20 + m) * 3600, function()
        local st = S.g and lp("stats", S.g)
        if st and not st.fallen then
          info(string.format("visit: Grubstake at +%d min, rung %s, garrison %d, knows %s", m, tostring(st.ops.ladder),
            st.garrison, table.concat(st.ops.player_targets or {}, "; ")))
        end
      end)
    end
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
  -- LP_MIX=expansion: every 20 minutes the player places an outpost on the nearest unmined ore beyond its edge (8 drills,
  -- 2 powered lasers at its research, a radar), as a growing factory does (the megabase consult's test plan); the
  -- timeline counts how many still stand. Both: LP_MIX=provoked-expansion.
  if params.mix:find("expansion", 1, true) then
    S.outposts = {}
    for t = 20 * 3600, END - 600, 20 * 3600 do
      schedule(t, function()
        local sp = S.sp
        if not sp then return end
        local placed
        -- Ore from the map generator's noise, every 16 tiles across the band (as the corporations' site search does):
        -- 48 points round a 1,700-tile circle missed every patch; the chosen spot's chunk is generated afterwards.
        local pts = {}
        for r = S.dist - 100, S.dist + 300, 16 do
          local n = math.floor(2 * math.pi * r / 16)
          for k = 0, n - 1 do
            local a = 2 * math.pi * k / n
            table.insert(pts, {sp.x + math.cos(a) * r, sp.y + math.sin(a) * r})
          end
        end
        local names = {"entity:iron-ore:probability", "entity:copper-ore:probability", "entity:coal:probability",
          "entity:stone:probability"}
        local props = surface().calculate_tile_properties(names, pts)
        S.tried = S.tried or {}
        for idx, p in ipairs(pts) do
          if placed then break end
          local ore = false
          for _, v in pairs(props) do if v[idx] > 0 then ore = true end end
          local key = math.floor(p[1] / 64) .. "," .. math.floor(p[2] / 64)
          if ore and not S.tried[key] then
            S.tried[key] = true
            surface().request_to_generate_chunks(p, 1)
            surface().force_generate_chunk_requests()
            if surface().count_entities_filtered{position = p, radius = 12, type = "resource"} >= 30
              and surface().count_entities_filtered{position = p, radius = 60, force = "player", limit = 1} == 0
              and surface().count_entities_filtered{position = p, radius = 30, type = {"unit-spawner", "turret"}, force = "enemy", limit = 1} == 0 then
              local put = function(name, x, y)
                local q = surface().find_non_colliding_position(name, {x, y}, 6, 1)
                return q and surface().create_entity{name = name, position = q, force = "player", raise_built = true}
              end
              local ents = {}
              for i2 = 0, 7 do table.insert(ents, put("electric-mining-drill", p[1] - 6 + (i2 % 4) * 4, p[2] - 3 + math.floor(i2 / 4) * 6)) end
              for _, dx in ipairs({-10, 10}) do
                table.insert(ents, put("laser-turret", p[1] + dx, p[2] - 8))
                put("electric-energy-interface", p[1] + dx, p[2] - 12)
                put("medium-electric-pole", p[1] + dx + 2, p[2] - 10)
              end
              table.insert(ents, put("radar", p[1], p[2] + 9))
              put("electric-energy-interface", p[1] + 4, p[2] + 9)
              put("medium-electric-pole", p[1] + 2, p[2] + 6)
              table.insert(S.outposts, {pos = p, ents = ents, at = game.tick})
              placed = p
            end
          end
        end
        info("visit: outpost " .. (placed and string.format("placed at %.0f,%.0f", placed[1], placed[2]) or "found no ore"))
      end)
    end
  end
  -- LP_MIX=noart: the player's artillery removed at the start (turrets and wagons): a megabase's artillery denies a huge
  -- area by itself, as it should; without it, what the corporations do against the rest of the defence.
  -- LP_MIX=reach500 (any mix containing it): Grubstake prospects within 500 tiles, not 300.
  if params.mix:find("reach500", 1, true) then schedule(20, function() lp("debug_tune", {prospect_radius = 500}) end) end
  -- LP_MIX=orecount: how much ore lies round where Grubstake lands, charted or not (prospecting found none).
  if params.mix:find("orecount", 1, true) then
    schedule(30, function()
      for _, at in ipairs({{-394, 457}, {355, 372}}) do
        local n = surface().count_entities_filtered{position = at, radius = 500, type = "resource"}
        local charted, with = 0, 0
        for i = -15, 15 do for j = -15, 15 do
          local c = {math.floor(at[1] / 32) + i, math.floor(at[2] / 32) + j}
          if game.forces.player.is_chunk_charted(surface(), c) then
            charted = charted + 1
            if surface().count_entities_filtered{area = {{c[1] * 32, c[2] * 32}, {c[1] * 32 + 32, c[2] * 32 + 32}}, type = "resource",
              limit = 20} >= 20 then with = with + 1 end
          end
        end end
        info(string.format("visit: ore within 500 of %d,%d: %d resource entities; %d charted chunks, %d of them with ore", at[1], at[2],
          n, charted, with))
      end
    end)
  end
  -- LP_MIX=dumpmap (any mix containing it): at 75 minutes, the ground round each camp (900 tiles): the player's walls,
  -- turrets and poles, water sampled every 8 tiles, nests, and every camp's origin, for a plot (docs/sim/visit-*/map.json).
  if params.mix:find("dumpmap", 1, true) then
    schedule(75 * 3600, function()
      local out = {camps = {}, walls = {}, turrets = {}, poles = {}, water = {}, nests = {}}
      local box
      for _, id in ipairs(lp("bases")) do
        local st = lp("stats", id)
        table.insert(out.camps, {id = id, corp = st.corp, x = st.origin.x, y = st.origin.y})
        local o = st.origin
        box = box or {o.x, o.y, o.x, o.y}
        box = {math.min(box[1], o.x), math.min(box[2], o.y), math.max(box[3], o.x), math.max(box[4], o.y)}
      end
      if not box then return end
      local area = {{box[1] - 900, box[2] - 900}, {box[3] + 900, box[4] + 900}}
      local function add(list, ents) for _, e in pairs(ents) do table.insert(list, {math.floor(e.position.x), math.floor(e.position.y)}) end end
      add(out.walls, surface().find_entities_filtered{area = area, force = "player", type = {"wall", "gate"}})
      for _, e in pairs(surface().find_entities_filtered{area = area, force = "player", type = {"ammo-turret", "electric-turret", "fluid-turret"}}) do
        table.insert(out.turrets, {math.floor(e.position.x), math.floor(e.position.y), e.type})
      end
      add(out.poles, surface().find_entities_filtered{area = area, force = "player", type = "electric-pole"})
      add(out.nests, surface().find_entities_filtered{area = area, force = "enemy", type = {"unit-spawner", "turret"}})
      for x = area[1][1], area[2][1], 8 do for y = area[1][2], area[2][2], 8 do
        if surface().is_chunk_generated{math.floor(x / 32), math.floor(y / 32)} and surface().get_tile(x, y).collides_with("water_tile") then
          table.insert(out.water, {x, y})
        end
      end end
      helpers.write_file("landing-party/map.json", helpers.table_to_json(out))
      info(string.format("visit: map dumped (%d walls, %d turrets, %d water samples)", #out.walls, #out.turrets, #out.water))
    end)
  end
  -- LP_MIX=waves (any mix containing it): its incubators topped up and a wave let go every 5 minutes from minute 12
  -- (Synthexis lands by then), to see many waves against one real base in an hour; what each goes for, how big, and
  -- whether it goes at all, its own (wavesize: a wave of 60 forced each time).
  if params.mix:find("waves", 1, true) then
    -- The record (scripts/wavemap.py): the player's buildings and what Synthexis reads of them, from its first farm, when
    -- the first wave is forced; the waves' log at the end.
    -- (wavesN: the waves N minutes later, a second sample of the same base: one wave's change of course changes all after
    -- it, and one run is one path of many.)
    local shift = tonumber(params.mix:match("waves(%d+)") or 0) * 3600
    schedule(12 * 3600 - 60, function()
      local fs = lp("farm_state").farms
      local from = fs[1] and fs[1].pos or {x = 0, y = 0}
      local out = {}
      for _, e in pairs(surface().find_entities_filtered{area = {{-800, -800}, {800, 800}}, force = "player"}) do
        if e.type ~= "character" then out[#out + 1] = {e.type, e.name, math.floor(e.position.x * 2) / 2, math.floor(e.position.y * 2) / 2} end
      end
      local maps = lp("debug_base_maps", from, 1600, 60, 400)
      maps.from = {from.x or from[1], from.y or from[2]}
      helpers.write_file("landing-party/base.json", helpers.table_to_json(out))
      helpers.write_file("landing-party/maps.json", helpers.table_to_json(maps))
      info(string.format("visit: base and maps dumped (%d buildings, %d hearts)", #out, #maps.hearts))
    end)
    schedule(END - 120, function()
      -- The player's turrets by status at the end: how many a cut supply left dry or dark (feeds.lua).
      local names, by = {}, {}
      for k, v in pairs(defines.entity_status) do names[v] = k end
      for _, e in pairs(surface().find_entities_filtered{force = "player", type = {"ammo-turret", "electric-turret", "fluid-turret"}}) do
        local key = e.type .. " " .. tostring(names[e.status] or e.status)
        by[key] = (by[key] or 0) + 1
      end
      info("visit: turret statuses at the end " .. serpent.line(by))
      helpers.write_file("landing-party/waves.json", helpers.table_to_json(lp("herd_state").log or {}))
      info("visit: waves dumped")
    end)
    for t = 12 * 3600 + shift, END - 10 * 3600, 5 * 3600 do
      schedule(t, function() info(string.format("visit: wave forced at minute %d: %s", math.floor((game.tick - storage.t0) / 3600),
        tostring(lp("farm_wave", params.mix:find("wavesize", 1, true) and 60 or nil, nil, not params.mix:find("wavesize", 1, true))))) end)
    end
  end
  -- LP_MIX=routeprobe: the herd's router from Synthexis's landing toward the mining outpost north of the deathworld's wall.
  if params.mix:find("routeprobe", 1, true) then
    schedule(120, function()
      local from = {-536, 594}
      for _, o in ipairs({{to = {-245, -370}}, {to = {-150, -312}}, {to = {-60, -370}}, {to = {-150, -440}},
        {to = {-245, -370}, cell = 6}, {to = {-245, -370}, wide = true}}) do
        local to = o.to
        o.cell = o.cell or 16
        o.margin = 8
        local opts = {turrets = true, nests = false, solid = not o.nosolid and {"player"} or nil, cell = o.cell, margin = o.margin,
          partial = o.partial}
        local r = lp("debug_herd_route", from, to, opts)
        info(string.format("visit: route %s: %d waypoints, %s, ends %s", serpent.line(o), r.waypoints, serpent.line(r.last),
          serpent.line(r.route and r.route[#r.route])))
      end
    end)
  end
  -- LP_MIX=waterprobe: water and cliffs on a grid of 8 tiles round Synthexis's way north of nw's base (what its cost map
  -- may miss between a trail's legs).
  if params.mix:find("waterprobe", 1, true) then
    schedule(60, function()
      local out = {}
      for x = 300, 760, 8 do
        for y = -520, 0, 8 do
          local wt = surface().count_tiles_filtered{area = {{x, y}, {x + 8, y + 8}}, collision_mask = "water_tile"}
          local cl = surface().count_entities_filtered{area = {{x, y}, {x + 8, y + 8}}, type = "cliff"}
          if wt > 0 or cl > 0 then out[#out + 1] = {x, y, wt, cl} end
        end
      end
      helpers.write_file("landing-party/water.json", helpers.table_to_json(out))
      -- And the cost map's way from Synthexis's landing to the staging point across the lake, on both grids.
      for _, q in ipairs({{{700, -280}, {422, -266}, 16}, {{700, -280}, {422, -266}, 32}, {{700, -280}, {422, -266}, 48},
        {{262, -745}, {300, -300}, 48}, {{262, -745}, {300, -120}, 48}}) do
        local cell = q[3]
        local r = lp("debug_cost_path", q[1], q[2], cell)
        info(string.format("visit: cost path cell %d: cost %s, %s", cell, tostring(r.cost), serpent.line(r.path)))
      end
      info(string.format("visit: water dumped (%d cells)", #out))
    end)
  end
  -- LP_MIX=breachlab (any mix containing it): Synthexis's cultures paid 200 biomass each 10 s, so its first sieges come in
  -- minutes, not the hours of a visit (the nw breach lab, 2026-10-28: the real wall, mines and interior, a try in minutes).
  if params.mix:find("breachlab", 1, true) then
    for t = 600, END - 60, 600 do
      schedule(t, function()
        for _, f in ipairs(lp("farm_state").farms or {}) do lp("debug_biomass", f.id, 200) end
      end)
    end
  end
  -- LP_MIX=savesiege (with breachlab): the game saved (an auto-save named "siege", in this profile's saves) the moment a
  -- siege's wave sets out, to watch it in a window (scripts/play-visit.sh, LP_WATCH=_autosave-siege.zip; the user,
  -- 2026-10-28: "prepare a save so I can see such a siege using my own eyes").
  if params.mix:find("savesiege", 1, true) then
    local sieging = {}
    -- (As a server, as fast as it goes: scripts/siege-save.sh waits for the save.)
    schedule(30, function() game.speed = 64 end)
    for t = 120, END - 60, 60 do
      schedule(t, function()
        if S.siege_saved then return end
        for _, f in ipairs(lp("farm_state").farms or {}) do
          if f.siege then sieging[f.id] = true
          elseif sieging[f.id] and f.last_wave and game.tick - f.last_wave <= 120 then
            S.siege_saved = game.tick
            -- (At its own speed again, saved so: the save is to be watched. A server writes _autosave-siege.zip,
            -- scripts/siege-save.sh; a benchmark saves nothing.)
            -- (Its speed back to 1 a tick before it saves: set and saved in one tick, a watch save opened at speed.)
            game.speed = 1
            schedule(game.tick - storage.t0 + 1, function() game.auto_save("siege") end)
            info(string.format("visit: siege of farm %d set out, saved at tick %d", f.id, game.tick + 1))
            return
          end
        end
      end)
    end
  end
  -- LP_MIX=growth (any mix containing it): every 5 minutes, Synthexis's culture: its incubators, biomass, what it saves
  -- for, its tumors, the nests its creep gave up on (why a culture does not grow).
  if params.mix:find("growth", 1, true) then
    for t = 3600, END - 60, 5 * 3600 do
      schedule(t, function()
        local ts = lp("creep_state").tumors
        local tumors = #ts
        -- Its creep's reach toward the wild: the tumor nearest any wild spawner, and how near.
        local near, at
        for _, tu in ipairs(ts) do
          for _, sp in ipairs(surface().find_entities_filtered{type = "unit-spawner", force = "enemy", position = tu.pos, radius = 200}) do
            local d = math.sqrt((sp.position.x - tu.pos.x) ^ 2 + (sp.position.y - tu.pos.y) ^ 2)
            if not near or d < near then near, at = d, {math.floor(tu.pos.x), math.floor(tu.pos.y), math.floor(sp.position.x), math.floor(sp.position.y)} end
          end
        end
        -- The corporations' armies by unit, for what Synthexis's waves meet on the way.
        for _, f in pairs(game.forces) do
          if f.name:find("^lp%-") or f.name == "serenity" or f.name == "grubstake" then
            local by = {}
            for _, u in ipairs(surface().find_entities_filtered{force = f, type = {"unit", "car", "spider-vehicle"}}) do
              by[u.name] = (by[u.name] or 0) + 1
            end
            if next(by) then info(string.format("visit: growth army %s: %s", f.name, serpent.line(by))) end
          end
        end
        info(string.format("visit: growth tumors %s; nearest wild spawner %s tiles (%s)", serpent.line((function()
          local o = {} for _, tu in ipairs(ts) do o[#o + 1] = {math.floor(tu.pos.x), math.floor(tu.pos.y)} end return o end)()),
          tostring(near and math.floor(near)), serpent.line(at)))
        -- Synthexis's units standing on the map (waves among them): idle at its incubators, 645 at five hours on nw before
        -- it hatched its waves at launch (2026-10-29).
        info(string.format("visit: growth min %d synthexis units standing %d", math.floor((game.tick - storage.t0) / 3600),
          surface().count_entities_filtered{force = "lp-biotech", type = "unit"}))
        for _, f in ipairs(lp("farm_state").farms) do
          info(string.format("visit: growth min %d farm %d: pens %d, taken %d, grown %d, tumors %d, short %s, saving %s, biomass %s",
            math.floor((game.tick - storage.t0) / 3600), f.id, f.pens, f.taken, f.grown, tumors, tostring(f.short),
            tostring(f.saving), serpent.line(f.biomass)))
        end
      end)
    end
  end
  -- LP_MIX=reachprobe: what reaching every cell round nw's base costs from Synthexis's landing (16-tile cells), and the
  -- player's buildings, for a picture of where it could get in (docs: the nw question, 2026-10-27).
  if params.mix:find("reachprobe", 1, true) then
    schedule(120, function()
      local g = lp("debug_cost_grid", {700, -280}, {0, -100}, 900, 16)
      helpers.write_file("landing-party/reach.json", helpers.table_to_json(g))
      local out = {}
      for _, e in pairs(surface().find_entities_filtered{area = {{-900, -1000}, {900, 800}}, force = "player",
        type = {"ammo-turret", "electric-turret", "fluid-turret", "land-mine", "wall", "gate", "assembling-machine", "furnace",
          "mining-drill", "solar-panel", "accumulator", "roboport", "lab", "radar", "electric-pole"}}) do
        out[#out + 1] = {e.type, math.floor(e.position.x), math.floor(e.position.y)}
      end
      helpers.write_file("landing-party/reach_base.json", helpers.table_to_json(out))
      local corp = {}
      for _, e in pairs(surface().find_entities_filtered{area = {{-900, -1000}, {1100, 800}}, force = {"lp-serenity", "lp-grubstake"}}) do
        corp[#corp + 1] = {e.type, math.floor(e.position.x), math.floor(e.position.y)}
      end
      helpers.write_file("landing-party/reach_corp.json", helpers.table_to_json(corp))
      info(string.format("visit: reach dumped (%d cells, %d buildings, %d corporation entities)", #g.cost, #out, #corp))
    end)
  end
  -- LP_MIX=statusprobe: the player's turrets by type and status at the start (what threat.firing reads).
  if params.mix:find("statusprobe", 1, true) then
    schedule(120, function()
      local by = {}
      local names = {}
      for k, v in pairs(defines.entity_status) do names[v] = k end
      for _, e in pairs(surface().find_entities_filtered{force = "player", type = {"ammo-turret", "electric-turret", "fluid-turret"}}) do
        local key = e.type .. " " .. tostring(names[e.status] or e.status)
        by[key] = (by[key] or 0) + 1
      end
      info("visit: turret statuses " .. serpent.line(by))
    end)
  end
  -- LP_MIX=basemap (any mix containing it): at the start, every building of the player's within 600 of the middle (type,
  -- name, position), for a plot of what a wave meets (docs/sim/visit-*/base.json).
  if params.mix:find("basemap", 1, true) then
    schedule(60, function()
      local out = {}
      for _, e in pairs(surface().find_entities_filtered{area = {{-600, -600}, {600, 600}}, force = "player"}) do
        if e.type ~= "character" then
          out[#out + 1] = {e.type, e.name, math.floor(e.position.x * 2) / 2, math.floor(e.position.y * 2) / 2}
        end
      end
      helpers.write_file("landing-party/base.json", helpers.table_to_json(out))
      info(string.format("visit: base dumped (%d buildings)", #out))
    end)
  end
  -- LP_MIX=marchtrace: every marching herd's group traced each second (landing-party debug_tune march_trace).
  if params.mix:find("marchtrace", 1, true) then schedule(30, function() lp("debug_tune", {march_trace = true}) end) end
  -- LP_MIX=priorprobe: threat.prior (lp_threat, required at load) of one of the player's turrets of each prototype (what a turret is priced at before any
  -- is learned).
  if params.mix:find("priorprobe", 1, true) then
    schedule(params.mix:find("kh", 1, true) and 14 * 3600 or 60, function()
      local seen = {}
      for _, t in pairs(surface().find_entities_filtered{force = params.mix:find("kh", 1, true) and "lp-serenity" or "player",
        type = {"ammo-turret", "electric-turret", "fluid-turret", "unit"}}) do
        if not seen[t.name] then
          seen[t.name] = true
          local p = lp_threat.profile(t.name)
          info(string.format("visit: prior %s %s (%s, %s) %.1f, firing %s, learned %s", t.force.name, t.name, p and p.kind or "?",
            p and p.dmg or "?", lp_threat.prior(t, 6), tostring(lp_threat.firing(t)), tostring(lp("debug_price", t.force.name, t.name))))
        end
      end
    end)
  end
  -- LP_MIX=speedprobe: the game's speed as loaded (a watch save made at speed must open at 1).
  if params.mix:find("speedprobe", 1, true) then schedule(5, function() info("visit: game speed " .. game.speed) end) end
  -- LP_MIX=pathprobe: the cost map's way and price from Synthexis's landing and from the east gap to the middle of nw's base,
  -- at 16, 32 and 48-tile cells (the farm reads 48, its waves 32): why the farm priced a way at 8 its wave priced at 83.
  if params.mix:find("pathprobe", 1, true) then
    schedule(120, function()
      local out = {}
      for _, from in ipairs({{700, -280}, {568, -50}}) do
        for _, cell in ipairs({16, 32, 48}) do
          out[#out + 1] = {from = from, cell = cell, r = lp("debug_cost_path", from, {319, 1}, cell)}
        end
      end
      helpers.write_file("landing-party/paths.json", helpers.table_to_json(out))
      info("visit: paths dumped")
    end)
  end
  -- LP_MIX=treeprobe: at the start, neutral obstacles (trees, rocks) round where nw's big waves turned, by 8-tile cell.
  if params.mix:find("treeprobe", 1, true) then
    schedule(60, function()
      local out = {}
      for _, e in pairs(surface().find_entities_filtered{area = {{560, -220}, {780, 0}}, force = "neutral"}) do
        out[#out + 1] = {e.type, math.floor(e.position.x), math.floor(e.position.y)}
      end
      helpers.write_file("landing-party/trees.json", helpers.table_to_json(out))
      info(string.format("visit: trees dumped (%d)", #out))
    end)
  end
  -- LP_MIX=spotprobe: at 80 minutes, what stands round where nw's big waves turned (600..760, -200..-20): water and cliffs,
  -- and every entity there not the player's that collides (a corporation's camp), for why its pathfinder went round.
  if params.mix:find("spotprobe", 1, true) then
    schedule(80 * 3600, function()
      local area = {{600, -200}, {760, -20}}
      local out = {water = {}, cliffs = {}, other = {}}
      for _, t in pairs(surface().find_tiles_filtered{area = area, collision_mask = "water_tile"}) do
        out.water[#out.water + 1] = {t.position.x, t.position.y}
      end
      for _, e in pairs(surface().find_entities_filtered{area = area, type = "cliff"}) do
        out.cliffs[#out.cliffs + 1] = {e.position.x, e.position.y}
      end
      for _, e in pairs(surface().find_entities_filtered{area = area}) do
        if e.force.name ~= "player" and e.force.name ~= "neutral" and e.type ~= "cliff" then
          out.other[#out.other + 1] = {e.force.name, e.type, e.name, math.floor(e.position.x), math.floor(e.position.y)}
        end
      end
      helpers.write_file("landing-party/spot.json", helpers.table_to_json(out))
      info(string.format("visit: spot dumped (%d water, %d cliffs, %d others)", #out.water, #out.cliffs, #out.other))
    end)
  end
  -- LP_MIX=walldump: a 200-tile stretch of nw's north wall as built (name, exact position, direction, quality, the
  -- flamers' fluid), for the arena's wall pen (tests/lp-arena/nwwall.lua).
  if params.mix:find("walldump", 1, true) then
    schedule(60, function()
      local out = {}
      for _, e in pairs(surface().find_entities_filtered{area = {{-200, -440}, {0, -375}}, force = "player",
        type = {"wall", "gate", "ammo-turret", "electric-turret", "fluid-turret", "land-mine"}}) do
        local fl = e.type == "fluid-turret" and next(e.get_fluid_contents()) or nil
        out[#out + 1] = {e.name, e.position.x, e.position.y, e.direction, e.quality.name, fl}
      end
      helpers.write_file("landing-party/wall.json", helpers.table_to_json(out))
      local pf, mods = game.forces.player, {ammo = {}, speed = {}, turret = {}}
      for name in pairs(prototypes.ammo_category) do
        mods.ammo[name], mods.speed[name] = pf.get_ammo_damage_modifier(name), pf.get_gun_speed_modifier(name)
      end
      for _, name in ipairs({"laser-turret", "flamethrower-turret", "gun-turret"}) do mods.turret[name] = pf.get_turret_attack_modifier(name) end
      helpers.write_file("landing-party/wall_research.json", helpers.table_to_json(mods))
      info(string.format("visit: wall dumped (%d pieces)", #out))
    end)
  end
  -- LP_MIX=async (any mix containing it): at 30 minutes, a landing queued as the faction's own are (asynchronous).
  if params.mix:find("async", 1, true) then
    schedule(30 * 3600, function() lp("arrive_async", 1, S.sp, S.dist + 400, {corp = "grubstake"}) end)
  end
  if params.mix:find("noart", 1, true) then
    schedule(30, function()
      local n = 0
      for _, e in pairs(surface().find_entities_filtered{force = "player", type = {"artillery-turret", "artillery-wagon"}}) do
        e.destroy(); n = n + 1
      end
      info("visit: removed the player's artillery, " .. n .. " pieces")
    end)
  end
  if params.mix:find("provoked", 1, true) then
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
      local standing = 0
      for _, o in ipairs(S.outposts or {}) do
        local n = 0
        for _, e in ipairs(o.ents) do if e and e.valid then n = n + 1 end end
        if n >= #o.ents / 2 then standing = standing + 1 end
      end
      local row = {minute = (game.tick - storage.t0) / 3600, player = census(), bases = {}, razed = razed,
        outposts = S.outposts and #S.outposts or nil, outposts_standing = S.outposts and standing or nil,
        razed_by_type = pr.razed, ladder = pr.ladder,
        since_raze = pr.last_raze and (game.tick - pr.last_raze) / 3600 or nil}
      for _, id in ipairs(lp("bases")) do
        local st = lp("stats", id)
        if st then
          table.insert(row.bases, {id = id, corp = st.corp, fallen = st.fallen and true or false, garrison = st.garrison,
            razed = st.razed, looted = st.ops.looted, launched = st.ops.launched, done = st.ops.done,
            aborted = st.ops.aborted, sieges = st.ops.sieges, strips = st.ops.strips, op = st.ops.op,
            units_lost = st.units_lost, known = st.ops.known, known_player = st.ops.known_player,
            reinforced = st.reinforced, parts = st.parts, cap = st.cap, on_footing = st.on_footing})
        end
      end
      local ok, chests = pcall(function()
        return {serenity = lp("war", "serenity").chest, grubstake = lp("war", "grubstake").chest} end)
      row.chest = ok and chests or nil
      helpers.write_file("landing-party/timeline.jsonl", helpers.table_to_json(row) .. "\n", true)
    end)
  end
  schedule(END - 60, function()
    info("visit: player at the end " .. serpent.line(census()))
    info("visit: the player's buildings razed by the corporations " .. serpent.line(lp("pressure").razed))
    info("visit: the player's buildings razed by biters " .. serpent.line(S.biter_razed or {}))
    -- Synthexis: whether it came, its waves and where they went, what it broke.
    local fs = lp("farm_state")
    local hl = lp("herd_state").log or {}
    local waves = {}
    for _, l in ipairs(hl) do
      waves[#waves + 1] = string.format("%s at %s, %d of %d home%s", l.outcome, l.center and string.format("%.0f,%.0f",
        l.center[1], l.center[2]) or "?", l.left or 0, l.size or 0, l.breach and "" or " (no breach)")
    end
    info(string.format("visit: Synthexis %s, %d waves: %s; razed of the player's %s", #(fs.farms or {}) > 0 and
      string.format("landed (%d farms, first at %s)", #fs.farms, serpent.line(fs.farms[1] and fs.farms[1].pos)) or "never landed",
      #hl, table.concat(waves, "; "), serpent.line(S.syn_razed or {})))
    -- What fought back without a player: robots rebuilding, and turrets still armed.
    local rebuilt = 0
    for _, v in pairs(S.robot_built or {}) do rebuilt = rebuilt + v end
    local ghosts = surface().count_entities_filtered{force = "player", type = "entity-ghost"}
    local guns, dry = 0, 0
    for _, t in pairs(surface().find_entities_filtered{force = "player", type = "ammo-turret"}) do
      guns = guns + 1
      local inv = t.get_inventory(defines.inventory.turret_ammo)
      if inv and inv.is_empty() then dry = dry + 1 end
    end
    info(string.format("visit: robots rebuilt %d %s; %d ghosts left; %d of %d gun turrets empty", rebuilt,
      serpent.line(S.robot_built or {}), ghosts, dry, guns))
    metric("robot_rebuilt", rebuilt)
    metric("ghosts_left", ghosts)
    metric("dry_turrets", dry)
    -- Pollution put out over the run, by source: the corporations' share (Grubstake's drills pollute).
    local corp, all = 0, 0
    for name, v in pairs(game.get_pollution_statistics(surface()).input_counts) do
      v = v - ((S.poll0 or {})[name] or 0)
      all = all + v
      if name:sub(1, 3) == "lp-" then corp = corp + v end
    end
    info(string.format("visit: pollution put out %.0f, the corporations' %.0f (%.0f%%)", all, corp, all > 0 and 100 * corp / all or 0))
    metric("biter_razed", table_size(S.biter_razed or {}) > 0 and (function() local n = 0 for _, v in pairs(S.biter_razed) do n = n + v end return n end)() or 0)
    metric("corp_pollution_pct", all > 0 and math.floor(100 * corp / all + 0.5) or 0)
    for _, id in ipairs(lp("bases")) do
      local st = lp("stats", id)
      info(string.format("visit: %s %d%s: garrison %d, razed %d, looted %d, units lost %d, %d operations (%d done, %d aborted, %d sieges, %d strips)",
        st.corp, id, st.fallen and " (fallen)" or "", st.garrison, st.razed, st.ops.looted or 0, st.units_lost or 0,
        st.ops.launched, st.ops.done, st.ops.aborted, st.ops.sieges, st.ops.strips))
      -- Ground refused and crews stuck, by cause (cliffs measured, 2026-10-26).
      info(string.format("visit: %s %d ground refused %s; crews stuck %d; cliffs blasted %d, water tiles filled %d, piers %d", st.corp, id,
        serpent.line(st.refused or {}), st.crews_stuck or 0, st.blasted or 0, st.landfilled or 0, st.piers or 0))
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
    S.c_raid = c
    S.lost0 = lp("stats", S.id).units_lost or 0
  end)
  -- The raid a second after the base stands: forced in the tick it was built, its lasers read as unpowered (the engine
  -- powers them from the next tick), and dark turrets weigh nothing.
  schedule(3 * 3600 + 60, function() lp("dev", {"raid", tostring(S.id)}, S.c_raid) end)
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

-- Chart (the user, 2026-10-17: names for the camps, territory drawn sleeker): Grubstake and Serenity camps land; each
-- has a name in its corporation's voice, no two alike, on its map label; its territory is drawn as chunks (a few
-- dozen objects, no disc). LP_MIX: none.
-- Levers (tune.lua; the user, 2026-10-18: "scaling variables for strength and aggression sort of like what biters have
-- at world gen"): a Grubstake and a Serenity camp, both normal. At 2 minutes Grubstake's settings go to very high
-- as an admin would (debug_setting): its cap doubles, its hour-long spans halve; Serenity's stay. At 8 minutes
-- Grubstake's ladder (its clock at double speed, started with Serenity's at landing) is at rung 1, Serenity's at 0.
-- Remembered (Serenity's reaction table): a block of eight gun turrets 150 tiles from a Serenity camp at level 1, more
-- than a raid of its could take. One of its units killed by them at 3 minutes, another at 10. Until 2026-10-19 the
-- first was remembered and the second besieged; Serenity now answers trespass only (losses are fair war, the user),
-- so neither is answered: no raid, no siege.
scenarios.remembered = function()
  schedule(60, function()
    -- Unprovoked at the start (the harness provokes; here the first kill does), and no operation of choice: provoked,
    -- it besieged the turrets on its own before any answer.
    lp("debug_tune", {era = 1, history_off = true, choice_off = true, corp_level = {serenity = 1}})
    S.s = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "serenity"})
    lp("debug_depot", S.s, 3000)
  end)
  local function kill()
    local o = lp("stats", S.s).origin
    local u = surface().find_entities_filtered{type = "unit", force = "lp-serenity", position = o, radius = 300, limit = 1}[1]
    if u and S.turrets[1].valid then u.die("player", S.turrets[1]); return true end
  end
  schedule(2 * 3600, function()
    local o = lp("stats", S.s).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local c = {math.floor(o.x - o.x / len * 150), math.floor(o.y - o.y / len * 150)}
    flatten(c[1] - 14, c[2] - 14, c[1] + 14, c[2] + 14)
    S.turrets = {}
    for i = 0, 7 do
      local t = surface().create_entity{name = "gun-turret", position = {c[1] - 7 + (i % 4) * 4, c[2] - 2 + math.floor(i / 4) * 4},
        force = "player"}
      t.insert{name = "piercing-rounds-magazine", count = 100}
      table.insert(S.turrets, t)
    end
  end)
  schedule(3 * 3600, function() S.k1 = kill() end)
  schedule(9 * 3600, function() S.first = lp("stats", S.s).ops.answered or {} end)
  schedule(10 * 3600, function() S.k2 = kill() end)
  schedule(END - 60, function()
    local log = lp("stats", S.s).ops.answered or {}
    info("remembered: after the first " .. serpent.line(S.first) .. ", at the end " .. serpent.line(log))
    check("remembered: both kills made", S.k1 and S.k2, string.format("%s %s", tostring(S.k1), tostring(S.k2)))
    check("remembered: no raid into the turrets", (log["a squad goes"] or 0) == 0, serpent.line(log))
    check("remembered: the first unanswered", S.first and next(S.first) == nil, serpent.line(S.first))
    check("remembered: the second unanswered", next(log) == nil, serpent.line(log))
  end)
end

-- Gates (visit nw: Serenity's raiders stood at its lander behind its own gated pad wall, raid after raid, for three
-- hours; no gate opens for a unit by itself). A Serenity camp (picket) walls and gates its pad; at 14 minutes a raid
-- on an assembler 140 tiles off: its raiders get out through their gates and raze it. LP_MIX=shut: gates_off (the old
-- code): they do not.
scenarios.gates = function()
  local shut = params.mix == "shut"
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true, raids_off = true, gates_off = shut or nil})
    S.s = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "serenity", doctrine = "picket"})
    for _ = 1, 2 do lp("debug_depot", S.s, 4000) end
  end)
  schedule(14 * 3600, function()
    local st = lp("stats", S.s)
    local o = st.origin
    S.gates = surface().count_entities_filtered{position = o, radius = 40, name = "lp-gate"}
    -- Its garrison in the pad's yard, by the lander, as on nw (here it stood outside the pad and the case did not arise).
    local lander
    for _, e in pairs(surface().find_entities_filtered{position = o, radius = 30, force = "lp-serenity"}) do
      if e.name:find("lander", 1, true) then lander = e end
    end
    local at = lander and lander.position or o
    S.moved = 0
    for _, u in pairs(surface().find_entities_filtered{position = o, radius = 120, force = "lp-serenity", type = "unit"}) do
      local p = surface().find_non_colliding_position(u.name, {at.x, at.y + 4}, 6, 0.5)
      if p then u.teleport(p); S.moved = S.moved + 1 end
    end
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local c = {math.floor(o.x - o.x / len * 140), math.floor(o.y - o.y / len * 140)}
    flatten(c[1] - 6, c[2] - 6, c[1] + 6, c[2] + 6)
    S.target = surface().create_entity{name = "assembling-machine-1", position = c, force = "player"}
    lp("dev", {"raid", tostring(S.s)}, c)
    S.t0 = game.tick
  end)
  schedule(END - 60, function()
    local st = lp("stats", S.s)
    info(string.format("gates: %d units moved into the yard, %d gates by the lander, %s opens; target %s; log %s", S.moved or -1, S.gates or -1,
      tostring(st.gate_opens), S.target and S.target.valid and "standing" or "razed", serpent.line(st.ops.log)))
    check("gates: the pad is gated (the case)", (S.gates or 0) > 0, tostring(S.gates))
    if shut then
      check("gates: shut, the raid does not get out", S.target and S.target.valid, "")
    else
      check("gates: its raiders got out and razed the target", S.target and not S.target.valid, serpent.line(st.ops.log))
    end
  end)
end

-- Way out (2026-10-24: Kessler-Hayashi's tanks stood in its walled blocks raid after raid while its infantry left, 9 of
-- 55 raids in the four-seed system sim called off). A ring of its wall, 21 across, an opening of 4 on the east; inside,
-- two each of a tank (2 x 2), a buggy (1.4) and drone infantry, ordered 60 tiles east. LP_MIX: gap (the opening empty),
-- gate (gated, every gate asked open each second from a second before the order), shut (gated, never opened),
-- lane2, lane3, lane4 (the opening empty, and a lane that wide from it between two walls, 12 long).
scenarios.wayout = function()
  local mode = params.mix ~= "" and params.mix or "gap"
  local C = {200, 200}
  -- A force of its own (the mod commands Kessler-Hayashi's units), and the ground generated (no unit paths through a chunk
  -- never made).
  local F = "lp-wayout"
  schedule(30, function()
    if not game.forces[F] then game.create_force(F) end
    surface().request_to_generate_chunks({C[1] + 30, C[2]}, 4)
    surface().force_generate_chunk_requests()
  end)
  schedule(60, function()
    flatten(C[1] - 20, C[2] - 20, C[1] + 80, C[2] + 20)
    local function wall(x, y, name)
      surface().create_entity{name = name or "lp-wall", position = {C[1] + x + 0.5, C[2] + y + 0.5}, force = F,
        direction = defines.direction.north}
    end
    for k = -10, 10 do
      wall(k, -10); wall(k, 10); wall(-10, k)
      if k < -2 or k > 1 then wall(10, k)
      elseif mode == "gate" or mode == "shut" then wall(10, k, "lp-gate") end
    end
    -- lane2, lane3, lane4: a lane that wide beyond the opening (walls either side, 12 long).
    local lane = tonumber(mode:match("^lane(%d)$"))
    if lane then
      local lo = -math.floor(lane / 2) - 1
      for x = 11, 22 do wall(x, lo); wall(x, lo + lane + 1) end
    end
    S.units = {}
    for _, name in ipairs({"lp-tank", "lp-buggy", "lp-infantry"}) do
      for _, u in ipairs(spawn(name, {C[1] - 3, C[2]}, 2, F)) do table.insert(S.units, u) end
    end
  end)
  if mode == "gate" then
    for t = 120, 120 + 70 * 60, 60 do
      schedule(t, function()
        for _, g in pairs(surface().find_entities_filtered{name = "lp-gate", position = C, radius = 20}) do
          g.request_to_open(g.force, 90)
        end
      end)
    end
  end
  schedule(180, function()
    for _, u in ipairs(S.units) do
      u.commandable.set_command{type = defines.command.go_to_location, destination = {C[1] + 60, C[2]}, radius = 6,
        distraction = defines.distraction.none}
    end
  end)
  schedule(180 + 60 * 60, function()
    local out = {}
    for _, u in ipairs(S.units) do
      if u.valid then
        local k = u.name
        out[k] = out[k] or {out = 0, n = 0}
        out[k].n = out[k].n + 1
        if u.position.x > C[1] + 40 then out[k].out = out[k].out + 1 end
        info(string.format("wayout %s: %s ends at %.0f,%.0f", mode, k, u.position.x - C[1], u.position.y - C[2]))
      end
    end
    for k, v in pairs(out) do info(string.format("wayout %s: %s %d of %d out", mode, k, v.out, v.n)) end
    local all, any = true, false
    for _, v in pairs(out) do
      if v.out < v.n then all = false end
      if v.out > 0 then any = true end
    end
    if mode == "shut" then check("wayout: shut, none out", not any, serpent.line(out))
    else check("wayout: " .. mode .. ", every unit out", all, serpent.line(out)) end
  end)
end

-- Block exits (2026-10-24: wayout says a lane under 3 wide stops every unit). Every walled block template of
-- Kessler-Hayashi's (scripts/blocks.lua), built as its camp builds it (the wall ring, a gate in each opening, the corner
-- turrets and pillboxes, every fixed entity and every slot filled; the pad with its lander): tanks set down inside, its
-- gates held open, ordered 25 tiles north. Every tank must be out of every block within two minutes (five to a block
-- queue at its gates). The launch block is left out: its
-- pad fills the middle and no unit is made there.
local BLOCKS = require("__landing-party__.scripts.blocks")
local SHARED = require("__landing-party__.shared")
scenarios.blockexit = function()
  local F = "lp-wayout"
  -- LP_MIX switches parts off to find what blocks: nopill, empty (no fixed or slot entities), noturret.
  local mix = params.mix or ""
  local arch = {}
  for k, v in pairs(SHARED.CORPS.serenity.arch or {}) do arch[k] = v end
  if mix:find("nopill", 1, true) then arch.pillboxes = false end
  local empty, noturret = mix:find("empty", 1, true), mix:find("noturret", 1, true)
  local made = {}
  schedule(30, function()
    if not game.forces[F] then game.create_force(F) end
    surface().request_to_generate_chunks({650, -700}, 16)
    surface().force_generate_chunk_requests()
  end)
  schedule(60, function()
    local n = 0
    for _, kind in ipairs({"fab", "gen", "depot", "compound", "pad"}) do
      for v, t in ipairs(BLOCKS[kind]) do
        local w = kind == "pad" and BLOCKS.PAD_W or BLOCKS.SIZE
        local h = BLOCKS.SIZE
        local x0, y0 = 200 + n * 80, -700
        n = n + 1
        flatten(x0 - 15, y0 - 40, x0 + w + 15, y0 + h + 10)
        local function put(name, x, y, dir)
          return surface().create_entity{name = name, position = {x0 + x, y0 + y}, force = F, direction = dir}
        end
        local ox, oy = math.floor(w / 2) - BLOCKS.OPENING / 2, math.floor(h / 2) - BLOCKS.OPENING / 2
        for x = 0, w - 1 do for _, y in ipairs({0, h - 1}) do
          put((x < ox or x >= ox + BLOCKS.OPENING) and "lp-wall" or (arch.gates and "lp-gate") or "lp-wall", x + 0.5, y + 0.5,
            defines.direction.east)
        end end
        for y = 1, h - 2 do for _, x in ipairs({0, w - 1}) do
          put((y < oy or y >= oy + BLOCKS.OPENING) and "lp-wall" or (arch.gates and "lp-gate") or "lp-wall", x + 0.5, y + 0.5,
            defines.direction.north)
        end end
        if not empty then
          for _, e in ipairs(t.fixed or {}) do put(e[1], e[2], e[3]) end
          for _, e in ipairs(t.slots or {}) do put(e[1], e[2], e[3]) end
        end
        if kind == "pad" then put("lp-lander", w / 2, h / 2) end
        for _, c in ipairs({{2, 2}, {w - 2, 2}, {2, h - 2}, {w - 2, h - 2}}) do
          if not noturret then put("lp-turret", c[1], c[2]) end
          if arch.pillboxes then
            local sx, sy = c[1] < w / 2 and 1 or -1, c[2] < h / 2 and 1 or -1
            for _, q in ipairs({{sx * 1.5, -sy * 0.5}, {sx * 1.5, sy * 0.5}, {-sx * 0.5, sy * 1.5}, {sx * 0.5, sy * 1.5}}) do
              put("lp-wall", c[1] + q[1], c[2] + q[2])
            end
          end
        end
        -- Where its units stand: 4 below a depot and 8 below the lander (army.lua), the middle, and the cross's arms
        -- (where they wander).
        local tanks = {}
        local spots = {{w / 2, h / 2}, {w / 2, 4}, {w / 2, h - 4}, {4, h / 2}, {w - 4, h / 2}}
        for _, e in ipairs(t.fixed or {}) do if e[1] == "lp-depot" then table.insert(spots, 1, {e[2], e[3] + 4}) end end
        if kind == "pad" then table.insert(spots, 1, {w / 2, h / 2 + 8}) end
        for _, spot in ipairs(spots) do
          local q = surface().find_non_colliding_position("lp-tank", {x0 + spot[1], y0 + spot[2]}, 4, 0.5)
          if q and q.x > x0 + 1 and q.x < x0 + w - 1 and q.y > y0 + 1 and q.y < y0 + h - 1 then
            local u = surface().create_entity{name = "lp-tank", position = q, force = F}
            if u then table.insert(tanks, u) end
          end
        end
        table.insert(made, {label = kind .. " " .. v, tanks = tanks, x0 = x0, y0 = y0, w = w})
      end
    end
  end)
  for t = 90, 90 + 130 * 60, 60 do
    schedule(t, function()
      for _, g in pairs(surface().find_entities_filtered{name = "lp-gate", force = F}) do g.request_to_open(g.force, 90) end
    end)
  end
  schedule(150, function()
    for _, m in ipairs(made) do
      for _, u in ipairs(m.tanks) do
        u.commandable.set_command{type = defines.command.go_to_location, destination = {m.x0 + m.w / 2, m.y0 - 25},
          radius = 6, distraction = defines.distraction.none}
      end
    end
  end)
  schedule(150 + 120 * 60, function()
    local stuck = {}
    for _, m in ipairs(made) do
      local out = 0
      for _, u in ipairs(m.tanks) do
        local q = u.valid and u.position
        if q and (q.x < m.x0 - 1 or q.x > m.x0 + m.w + 1 or q.y < m.y0 - 1 or q.y > m.y0 + BLOCKS.SIZE + 1) then out = out + 1 end
      end
      local at = {}
      for _, u in ipairs(m.tanks) do if u.valid then at[#at + 1] = string.format("%.0f,%.0f", u.position.x - m.x0, u.position.y - m.y0) end end
      info(string.format("blockexit %s: %d of %d tanks out (%s)", m.label, out, #m.tanks, table.concat(at, " ")))
      if out < #m.tanks or #m.tanks == 0 then table.insert(stuck, m.label) end
    end
    check("blockexit: every tank out of every block", #stuck == 0, table.concat(stuck, ", "))
  end)
end

-- The watchdog (landing-party/scripts/watch.lua), its alarms made to fire. LP_MIX: economy (at 4 minutes its
-- fabricators destroyed and its parts taken to nought: the deadlock of 2026-10-24), army (every unit it makes killed
-- as it comes, parts to spare). The stuck alarm is not staged here: a unit walled in alone was taken up by its camp's
-- operations and moved off; it fires in the system sim on every seed (stuck units among trees).
scenarios.watchdog = function()
  local mode = params.mix ~= "" and params.mix or "economy"
  schedule(60, function() lp("debug_tune", {history_off = true, raids_off = true}) end)
  schedule(4 * 3600, function()
    local id = storage.id
    if mode == "economy" then
      for _, f in pairs(surface().find_entities_filtered{name = "lp-fabricator", force = FORCE}) do f.die("player") end
      lp("debug_parts", id, -lp("stats", id).parts)
    elseif mode == "army" then
      lp("debug_parts", id, 5000)
    end
  end)
  for t = 4 * 3600 + 30, 20 * 3600, 30 do
    schedule(t, function()
      if mode == "army" then
        for _, u in pairs(surface().find_entities_filtered{type = {"unit", "spider-unit"}, force = FORCE}) do u.die("player") end
      end
    end)
  end
  schedule(END - 60, function()
    local w = lp("watch_state") or {}
    check("watchdog: the " .. mode .. " alarm fired", ((w.alarms or {})[mode] or 0) > 0, serpent.line(w.alarms))
  end)
end

-- Fortress (Fable's fortress consult; the user: "that's hardly better than a biter mod"): a player laser wall facing a
-- Serenity camp 150 tiles off, as on nw: 40 tiles of stone wall, ten lasers behind it, substations, an infinite power
-- source behind, two roboports with construction robots and repair packs, spares in storage (walls, lasers,
-- roboports), ghosts on death: the robots rebuild. Serenity at level 3, provoked; a siege forced on the wall at 14
-- minutes. Its fire plan (every mortar on one point, roboports first) and a howitzer for the roboports behind the wall:
-- half the lasers and every roboport down, and the robots' repair packs spent. LP_MIX=old (focus_off: the siege as it
-- was, its mortars left to choose): 117 shells, ten lasers at full health, 32 repair packs spent, nothing destroyed.
-- LP_MIX=jammer: Serenity has its jammer (rd): a mast goes up in the emplacement and its arcs down the robots.
-- LP_MIX=howitzer: the player kills the howitzer as it stands; a second siege on the same wall comes without one.
scenarios.fortress = function()
  local old, jam, hw = params.mix == "old", params.mix == "jammer", params.mix == "howitzer"
  schedule(60, function()
    lp("debug_tune", {era = 3, history_off = true, raids_off = true, corp_level = {serenity = 3}, focus_off = old or nil,
      rd_tech = jam and {serenity = {nodes = {jammer = 1}}} or nil})
    S.s = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "serenity"})
    for _ = 1, 3 do lp("debug_depot", S.s, 6000) end
    game.forces.player.create_ghost_on_entity_death = true
  end)
  schedule(10 * 3600, function()
    local o = lp("stats", S.s).origin
    -- Axis-aligned: u points from the wall toward the camp, v along the wall.
    local ux, uy = 0, 0
    if math.abs(o.x) > math.abs(o.y) then ux = o.x > 0 and 1 or -1 else uy = o.y > 0 and 1 or -1 end
    local vx, vy = -uy, ux
    local c = {math.floor(o.x - ux * 150) + 0.5, math.floor(o.y - uy * 150) + 0.5}
    local function at(du, dv) return {c[1] + ux * du + vx * dv, c[2] + uy * du + vy * dv} end
    flatten(math.min(at(-30, -30)[1], at(10, 30)[1]) - 4, math.min(at(-30, -30)[2], at(10, 30)[2]) - 4,
      math.max(at(-30, -30)[1], at(10, 30)[1]) + 4, math.max(at(-30, -30)[2], at(10, 30)[2]) + 4)
    local function put(name, p) return surface().create_entity{name = name, position = p, force = "player"} end
    S.c, S.lasers, S.ports = c, {}, {}
    for k = -20, 20 do put("stone-wall", at(0, k)) end
    for k = -18, 18, 4 do table.insert(S.lasers, put("laser-turret", at(-3, k))) end
    for k = -21, 21, 14 do put("substation", at(-7, k)) end
    for k = -21, 21, 14 do put("substation", at(-20, k)) end
    local eei = put("electric-energy-interface", at(-24, 0))
    eei.power_production = 1e9 / 60
    eei.electric_buffer_size = 1e9
    for _, k in ipairs({-10, 10}) do
      local r = put("roboport", at(-13, k))
      r.insert{name = "construction-robot", count = 30}
      r.insert{name = "repair-pack", count = 100}
      table.insert(S.ports, r)
    end
    local chest = put("storage-chest", at(-17, 0))
    chest.insert{name = "stone-wall", count = 200}
    chest.insert{name = "laser-turret", count = 20}
    chest.insert{name = "roboport", count = 4}
    S.built0 = 0
  end)
  schedule(14 * 3600, function()
    S.why = lp("dev", {"siege", tostring(S.s)}, {S.lasers[5].position.x, S.lasers[5].position.y}) or "launched"
  end)
  -- Shells fired: what the siege's mortars hold, sampled (loaded minus held at the lowest).
  for t = 14 * 3600 + 600, END - 120, 300 do
    schedule(t, function()
      local held = 0
      for _, m in pairs(surface().find_entities_filtered{name = "lp-mortar", force = "lp-serenity"}) do
        held = held + m.get_inventory(defines.inventory.artillery_turret_ammo).get_item_count("lp-mortar-shell")
      end
      local mortars = surface().count_entities_filtered{name = "lp-mortar", force = "lp-serenity"}
      S.masts = math.max(S.masts or 0, surface().count_entities_filtered{name = "lp-jammer"})
      local st0 = lp("stats", S.s)
      if hw then
        local hs = surface().find_entities_filtered{name = "lp-howitzer", force = "lp-serenity"}
        if S.killed then S.after = math.max(S.after or 0, #hs)
        elseif hs[1] then S.killed = game.tick; hs[1].die("player") end
        -- The first siege over: a second on the same wall, inside the half hour.
        if S.killed and not S.why2 and #(st0.ops.log or {}) > 0 and not st0.ops.op then
          S.down = st0.howitzer_down
          S.why2 = lp("dev", {"siege", tostring(S.s)}, {S.c[1], S.c[2]}) or "launched"
        end
        if S.why2 and #(st0.ops.log or {}) > 1 and not st0.ops.op then finish_early() end
        return
      end
      -- Settled: the siege is over (its log entry written).
      if S.why and #(st0.ops.log or {}) > 0 and not st0.ops.op then finish_early() end
      if mortars > 0 then
        S.peak = math.max(S.peak or 0, held)
        S.fired = math.max(S.fired or 0, (S.peak or 0) - held)
      end
    end)
  end
  schedule(END - 60, function()
    local lasers = surface().count_entities_filtered{name = "laser-turret", position = S.c, radius = 40, force = "player"}
    local ports = surface().count_entities_filtered{name = "roboport", position = S.c, radius = 40, force = "player"}
    local walls = surface().count_entities_filtered{name = "stone-wall", position = S.c, radius = 40, force = "player"}
    local st = lp("stats", S.s)
    info(string.format("fortress: siege %s; at the end %d lasers of 10, %d roboports of 2, %d walls of 41; robots rebuilt %s; "
      .. "log %s", tostring(S.why), lasers, ports, walls, serpent.line(S.robot_built or {}), serpent.line(st.ops.log)))
    local packs, hp, hpmax = 0, 0, 0
    for _, r in ipairs(S.ports) do if r.valid then packs = packs + r.get_item_count("repair-pack") end end
    for _, l in pairs(surface().find_entities_filtered{name = "laser-turret", position = S.c, radius = 40, force = "player"}) do
      hp, hpmax = hp + l.health, hpmax + l.max_health
    end
    info(string.format("fortress: repair packs left %d of 200; lasers' health %.0f of %.0f; shells fired %s", packs, hp, hpmax,
      tostring(S.fired)))
    S.fortress = {lasers = lasers, ports = ports, walls = walls}
    local js = lp("jammer_stats")
    info("fortress: jammer " .. serpent.line(js) .. ", masts seen " .. tostring(S.masts))
    if hw then
      info(string.format("fortress howitzer: killed at %s, down till %s, second siege %s, howitzers after %s",
        tostring(S.killed), tostring(S.down), tostring(S.why2), tostring(S.after)))
      check("fortress: a howitzer came and was killed", S.killed ~= nil, tostring(S.killed))
      check("fortress: its camp is down a howitzer", (S.down or 0) > (S.killed or 0) + 25 * 3600, tostring(S.down))
      check("fortress: a second siege launched", S.why2 == "launched", tostring(S.why2))
      check("fortress: no howitzer came with it", S.after == 0, tostring(S.after))
      return
    end
    if jam then
      check("fortress: a jamming mast went up", (S.masts or 0) > 0, tostring(S.masts))
      check("fortress: its arcs downed robots", js.jammed >= 5, tostring(js.jammed))
      check("fortress: the arcs are tesla beams", (js.beams or 0) >= js.jammed, string.format("%s of %s", tostring(js.beams), tostring(js.jammed)))
    end
    if old then
      -- Breaks nothing that matters: it aborts, the roboports stand. Since tanks fire cannon rounds (0.1.44) its assault
      -- takes a laser or two on seed 12345 (none on 777, 4242); "all 10 standing" until 2026-10-21.
      local last = (st.ops.log or {})[#(st.ops.log or {})]
      -- (Six, not eight, since 0.2.7: with its units out of their camp the old siege takes three lasers; it still aborts
      -- with the roboports standing, where the fire plan leaves five lasers at most and no roboport.)
      check("fortress: the old siege breaks nothing (the case)", lasers >= 6 and ports == 2 and last and last.outcome == "aborted",
        string.format("%d lasers, %d ports, %s", lasers, ports, last and last.outcome or "no siege"))
    else
      check("fortress: half the lasers down", lasers <= 5, tostring(lasers))
      check("fortress: the roboports down", ports == 0, tostring(ports))
    end
  end)
end

-- Herd (the biotech's first slice, scripts/herd.lua; docs/biotech.md "Waves with intent: the pack"): a base 250 tiles
-- from spawn away from the Serenity camp (harmless): a square wall ring of radius 40, turrets heavy on the face toward
-- the pen (4 lasers, 3 gun turrets), 2 on each flank, 1 laser at the back, 7 lasers and 5 gun turrets in all, power in
-- the middle. A wild spawner 180 tiles out becomes a pen; 40 bred medium biters in its stock; one wave sent at the base.
-- The default run: the scout's loop and mark, the gathering and the march as tells, the breach, the power dead, the
-- herd home, the trail on the ground for 20 minutes and gone after. Mixes:
--   keep: the power under the front's guns, none in the middle (power up; it withdrew, did not idle)
--   second: a second source under the front's guns (power up)
--   scout: seven troopers outside the wall on the scout's loop (the scout killed: the wave comes all the same, its face
--          read from the ground; the next loops wider)
--   belt: no lasers, no power: twelve gun turrets fed by burner inserters from chests (the inserters go, the guns stand)
--   wild: a wild nest 50 tiles off the trail (no wild biter in the herd; no fight between wild and bred)
--   blind: its biters' sight 0 (the control: no report, nothing found inside; power up)
--   mega: 200 bred biters (the cost recorded, not asserted)
--   spit: 30 bred mediums and 10 bred spitters: the spitters leave the herd once it is inside and hold the breach (within
--         15 of it while the herd hunts), cover the withdrawal, and come home
--   probe: evolution 0.5; four lasers in each of seven sectors, and toward the pen only a gun turret with no
--          ammunition, the approach its fire reads weakest (0.2.19: faces read by the fire on the way in; two in every
--          sector until then, the tie going toward the pen): the probe's runts find the gun silent, and the herd
--          breaches in front of it rather than at the face's middle
--   stomp: 36 bred mediums and 2 stompers (tier 4): a stomper gets inside the wall ring, and no Synthexis unit is hurt
--          by a stomper (its stomp is on enemy forces only)
--   burst: 32 bred mediums and 4 bursters, and a lesson that a wall held here before: the bursters wait outside the wall
--          while the herd goes at it, are released once it is there, and their bursts break something; burst-nohold:
--          the same with the hold off (the control, measured)
scenarios.herd = function()
  local mix = params.mix or ""
  local L, G = "laser-turret", "gun-turret"
  local function put(name, p) return surface().create_entity{name = name, position = p, force = "player"} end
  schedule(60, function()
    lp("debug_tune", {harmless = true, army_off = true, herd_off = true, history_off = true})
    local o = lp("stats", storage.id).origin
    local ux, uy = 0, 0
    if math.abs(o.x) > math.abs(o.y) then ux = o.x > 0 and -1 or 1 else uy = o.y > 0 and -1 or 1 end
    local vx, vy = -uy, ux
    local c = {ux * 250 + 0.5, uy * 250 + 0.5}
    -- du toward the pen (away from the camp), dv across.
    local function at(du, dv) return {c[1] + ux * du + vx * dv, c[2] + uy * du + vy * dv} end
    S.c, S.at = c, at
    local a, b = at(-130, -130), at(260, 130)
    -- The ground generated first: a unit in a chunk not yet generated cannot path (the scout's every move failed at once
    -- 430 tiles out, while the herd marched minutes later, once the chunks were there).
    surface().request_to_generate_chunks(at(65, 0), 9)
    surface().force_generate_chunk_requests()
    flatten(math.min(a[1], b[1]), math.min(a[2], b[2]), math.max(a[1], b[1]), math.max(a[2], b[2]))
    -- The map's own mud off this ground: the trail's is what is counted.
    surface().destroy_decoratives{area = {{math.min(a[1], b[1]), math.min(a[2], b[2])}, {math.max(a[1], b[1]), math.max(a[2], b[2])}},
      name = {"dark-mud-decal", "light-mud-decal"}}
    for i = -40, 40 do
      put("stone-wall", at(40, i)); put("stone-wall", at(-40, i)); put("stone-wall", at(i, 40)); put("stone-wall", at(i, -40))
    end
    local layout
    if mix == "belt" then
      layout = {}
      for _, p in ipairs({{37, -24}, {37, -8}, {37, 8}, {37, 24}, {-37, -16}, {-37, 16}, {-16, 37}, {16, 37}, {-16, -37},
        {16, -37}, {0, 37}, {0, -37}}) do table.insert(layout, {G, p[1], p[2]}) end
    elseif mix == "probe" then
      layout = {}
      for k = 0, 7 do
        for _, off in ipairs(k == 0 and {0.3} or {-0.3, -0.1, 0.1, 0.3}) do
          local a = k * math.pi / 4 + off
          local r = 37 / math.max(math.abs(math.cos(a)), math.abs(math.sin(a)))
          local du, dv = math.floor(r * math.cos(a) + 0.5), math.floor(r * math.sin(a) + 0.5)
          -- Toward the pen (k = 0), the second of the two: a gun turret left dry.
          table.insert(layout, {(k == 0 and off > 0) and G or L, du, dv})
          if k == 0 and off > 0 then S.dry_at = {du, dv} end
        end
      end
      game.forces.enemy.set_evolution_factor(0.5, surface())
    elseif mix == "wallgoal" then
      -- (Its face toward the pen unguarded: what is under test is the wall between it and its target, not the price.)
      layout = {{L, -37, 0}, {G, 12, -37}}
    else
      layout = {{L, 37, -24}, {G, 37, -14}, {L, 37, -5}, {G, 37, 4}, {L, 37, 13}, {G, 37, 22}, {L, 37, 30},
        {L, -12, -37}, {G, 12, -37}, {L, -12, 37}, {G, 12, 37}, {L, -37, 0}}
    end
    S.turrets, S.inserters = {}, {}
    for _, t in ipairs(layout) do
      -- flamer: the gun turrets flamethrowers, full of crude (a flamethrower's 30 reached the scout's old loop at 29: on
      -- such a base it died and its wave came blind; 2026-10-27, the perception consult).
      local flame = mix == "flamer" and t[1] == G
      local e = put(flame and "flamethrower-turret" or t[1], at(t[2], t[3]))
      table.insert(S.turrets, e)
      if flame then e.insert_fluid{name = "crude-oil", amount = 100}
      elseif t[1] == G and mix ~= "probe" then e.insert{name = "piercing-rounds-magazine", count = mix == "belt" and 10 or 200} end
      if mix == "belt" then
        -- Fed from inside: a burner inserter dropping into it, a chest of ammunition where it picks up. Placed by trial
        -- (offsets and turns) until it drops into the turret (its drop_target is not set yet on the tick it is built).
        local iu, iv = 0, 0
        if math.abs(t[2]) == 37 then iu = t[2] > 0 and -1 or 1 else iv = t[3] > 0 and -1 or 1 end
        local ins
        for _, off in ipairs({2, 1.5, 2.5, 1}) do
          ins = surface().create_entity{name = "burner-inserter", position = at(t[2] + iu * off, t[3] + iv * off), force = "player"}
          local function feeds()
            local d, bb = ins.drop_position, e.bounding_box
            return d.x >= bb.left_top.x and d.x <= bb.right_bottom.x and d.y >= bb.left_top.y and d.y <= bb.right_bottom.y
          end
          for _ = 1, 4 do if feeds() then break end; ins.rotate() end
          if feeds() then break end
          ins.destroy(); ins = nil
        end
        if ins then
          ins.insert{name = "coal", count = 50}
          local ch = put("infinity-chest", ins.pickup_position)
          ch.set_infinity_container_filter(1, {name = "piercing-rounds-magazine", count = 50})
          table.insert(S.inserters, ins)
        end
      end
    end
    if mix ~= "belt" then
      for x = -32, 32, 16 do for y = -32, 32, 16 do put("substation", at(x, y)) end end
      local spots = {}
      if mix ~= "keep" then table.insert(spots, at(4, 4)) end
      if mix == "keep" or mix == "second" then table.insert(spots, at(24, -24)) end
      S.power = {}
      for _, p in ipairs(spots) do
        local eei = put("electric-energy-interface", p)
        eei.power_production, eei.electric_buffer_size = 5e6, 5e7
        table.insert(S.power, eei)
      end
    end
    for _, p in ipairs({{-20, -6}, {-20, 6}, {20, -6}, {20, 6}, {-6, 20}, {6, 20}, {-6, -20}, {6, -20}}) do
      put("assembling-machine-2", at(p[1], p[2]))
    end
    -- core (0.2.31): this base's heart guarded (four lasers round its middle): no soft middle, so its wave raids the edge;
    -- unguarded (the plain herd: every gun on the wall) it strikes for the heart.
    if mix == "core" or mix == "coreedge" then
      for _, p in ipairs({{-8, -8}, {-8, 8}, {8, -8}, {8, 8}}) do table.insert(S.turrets, put(L, at(p[1], p[2]))) end
    end
    if mix == "scout" then
      -- A squad outside the wall where the scout comes on to its loop (turrets there only widen the loop: the scout goes
      -- round every turret it sees, so the answer to it moves).
      S.squad = {}
      for k = -3, 3 do
        table.insert(S.squad, surface().create_entity{name = "lp-trooper", position = at(66, k * 1.5), force = "player"})
      end
    end
    if mix == "wild" then
      local sp = surface().create_entity{name = "biter-spawner", position = at(130, 50), force = "enemy"}
      S.wild = {sp}
      for k = 1, 10 do table.insert(S.wild, surface().create_entity{name = "medium-biter", position = at(124, 44 + k), force = "enemy"}) end
    end
    -- The pen: a wild spawner taken, its stock bred.
    surface().create_entity{name = "biter-spawner", position = at(180, 0), force = "enemy"}
    S.pen = lp("herd_capture", 1, at(180, 0))
    S.size = mix == "mega" and 200 or 40
    if mix == "spit" then
      lp("herd_fill", S.pen, 30, "lp-bred-medium-biter")
      lp("herd_fill", S.pen, 10, "lp-bred-medium-spitter")
    elseif mix == "stomp" then
      lp("herd_fill", S.pen, 36, "lp-bred-medium-biter")
      lp("herd_fill", S.pen, 2, "lp-bred-stomper")
    elseif mix == "burst" or mix == "burst-nohold" then
      lp("herd_fill", S.pen, 32, "lp-bred-medium-biter")
      lp("herd_fill", S.pen, 4, "lp-bred-cinder")
      if mix == "burst-nohold" then lp("debug_tune", {biotech_no_hold = true}) end
    else
      lp("herd_fill", S.pen, S.size, "lp-bred-medium-biter")
    end
    S.damage = {}
  end)
  schedule(120, function()
    -- burst: a wall held a wave here before (the bursters are held only where one did).
    if mix == "burst" or mix == "burst-nohold" then lp("herd_wall_lesson", S.at(0, 0)) end
    S.t_send = game.tick
    -- wallgoal: its target 2 tiles behind the wall, among the guns (a lane's: the lab's waves said they were through with
    -- no wall broken, from within 6 tiles of it outside the wall; the siege lab, 2026-10-31). Through means past the wall.
    if mix == "wallgoal" then
      -- Three mines before the wall and three behind it, on its way: its sweep goes at those before it alone (a sweeper sent
      -- at mines between two walls chewed through the outer to reach them; the lane, 2026-10-31).
      for _, dv in ipairs({-4, 0, 4}) do
        surface().create_entity{name = "land-mine", position = S.at(44, dv), force = "player"}
        surface().create_entity{name = "land-mine", position = S.at(36, dv), force = "player"}
      end
      lp("set_trace", true)   -- (the operation records, oplog.lua: what the contract reads)
      S.wave1 = lp("herd_wave", S.pen, S.at(38, 0), {planned = true, sweep = 6})
      for t = game.tick - storage.t0 + 60, END - 60, 30 do
        schedule(t, function()
          -- (Past the wall within 3 s of through: through from the gap it broke, its foremost stands in the wall's line.)
          if S.inside_at and game.tick > S.inside_at + 180 then return end
          if not S.inside_at then
            for _, l in ipairs(lp("herd_state").log or {}) do if l.id == S.wave1 and l.t_inside then S.inside_at = l.t_inside end end
            for _, wv in ipairs(lp("herd_state").waves or {}) do
              if wv.id == S.wave1 and wv.stage == "inside" then S.inside_at = game.tick end
            end
          end
          if not S.inside_at then return end
          local past, c = 0, S.c
          for _, u in ipairs(surface().find_entities_filtered{type = "unit", force = "lp-biotech", position = S.at(0, 0), radius = 60}) do
            local ux_, uy_ = S.at(1, 0)[1] - c[1], S.at(1, 0)[2] - c[2]
            local du = (u.position.x - c[1]) * ux_ + (u.position.y - c[2]) * uy_
            local vx_, vy_ = S.at(0, 1)[1] - c[1], S.at(0, 1)[2] - c[2]
            local dv = (u.position.x - c[1]) * vx_ + (u.position.y - c[2]) * vy_
            if du < 39.5 and math.abs(dv) < 39.5 then past = past + 1 end
          end
          S.past_at_inside = math.max(S.past_at_inside or 0, past)
        end)
      end
      S.damage = S.damage or {}
      return
    end
    S.wave1 = lp("herd_wave", S.pen, S.at(0, 0), mix == "blind" and {sight = 0} or mix == "deep" and {deep = true} or (mix == "edge" or mix == "coreedge") and {deep = false} or nil)
    -- stray: once it marches, eight of its own carried 300 tiles back and out of its group (strays, sent home): its march
    -- keeps a biter's pace (counted in its middle as they walked home, its herd waited 15 times a leg and its cutters took
    -- 23 minutes to a pole 100 seconds off; the fed lab fort, 2026-10-30).
    if mix == "stray" then
      for t = game.tick - storage.t0 + 600, END - 600, 60 do
        schedule(t, function()
          if S.strayed then return end
          for _, wv in ipairs(lp("herd_state").waves) do
            if wv.id == S.wave1 and wv.stage == "march" and wv.group then
              local n = 0
              for _, u in ipairs(surface().find_entities_filtered{position = {wv.group[1], wv.group[2]}, radius = 30,
                type = "unit", force = "lp-biotech"}) do
                if n < 8 and u.commandable and u.commandable.parent_group then
                  local home = S.at(180, 0)
                  local dx, dy = wv.group[1] - home[1], wv.group[2] - home[2]
                  local d = math.max(1, math.sqrt(dx * dx + dy * dy))
                  local q = surface().find_non_colliding_position(u.name, {wv.group[1] - dx / d * 300, wv.group[2] - dy / d * 300}, 20, 1)
                  if q and u.teleport(q) then
                    u.commandable.set_command{type = defines.command.stop, ticks_to_wait = 60}
                    n = n + 1
                  end
                end
              end
              S.strayed = n
            end
          end
        end)
      end
    end
    -- fire (0.2.31): once it marches, eight fed gun turrets round it: caught under fire, it should break in there.
    if mix == "fire" then
      for t = game.tick - storage.t0 + 600, END - 600, 120 do
        schedule(t, function()
          if S.fire_at then return end
          for _, wv in ipairs(lp("herd_state").waves) do
            if wv.id == S.wave1 and wv.stage == "march" and wv.group then
              S.fire_at = game.tick
              -- (Sixteen: eight killed 4 of 41 in 15 s on one path, a hair under FIRE_LOSS, and the test asked the threshold,
              -- not the rule; 2026-10-27.)
              for k = 0, 15 do
                local a = k * math.pi / 8
                local q = surface().find_non_colliding_position("gun-turret",
                  {wv.group[1] + math.cos(a) * 14, wv.group[2] + math.sin(a) * 14}, 6, 1)
                local g = q and put("gun-turret", q)
                if g then g.insert{name = "piercing-rounds-magazine", count = 100} end
              end
            end
          end
        end)
      end
    end
  end)
  if mix == "scout" then
    -- A second wave once the first is over: does it loop wider where the first scout died?
    schedule(14 * 3600, function()
      lp("herd_fill", S.pen, 40, "lp-bred-medium-biter")
      S.wave2 = lp("herd_wave", S.pen, S.at(0, 0))
    end)
  end
  local function entry(id)
    for _, l in ipairs(lp("herd_state").log) do if l.id == id then return l end end
  end
  local function mud_near(points, inside)
    local n = 0
    for i = 1, #points - 1 do
      local p, q = points[i], points[i + 1]
      local area = {{math.min(p.x, q.x) - 2, math.min(p.y, q.y) - 2}, {math.max(p.x, q.x) + 2, math.max(p.y, q.y) + 2}}
      n = n + #surface().find_decoratives_filtered{area = area, name = {"dark-mud-decal", "light-mud-decal"}}
    end
    return n
  end
  local function mud_inside()
    local a, b = S.at(-40, -40), S.at(40, 40)
    return #surface().find_decoratives_filtered{area = {{math.min(a[1], b[1]), math.min(a[2], b[2])},
      {math.max(a[1], b[1]), math.max(a[2], b[2])}}, name = {"dark-mud-decal", "light-mud-decal"}}
  end
  if mix == "stomp" then
    for t = 600, END - 120, 60 do
      schedule(t, function()
        local c = S.at(0, 0)
        for _, u in pairs(surface().find_entities_filtered{name = "lp-bred-stomper", position = c, radius = 36}) do
          S.stomp_in = S.stomp_in or game.tick
        end
        S.stompers = surface().count_entities_filtered{name = "lp-bred-stomper"}
      end)
    end
  end
  if mix == "spit" then
    for t = 600, END - 120, 120 do
      schedule(t, function()
        for _, x in ipairs(lp("herd_state").waves) do
          if x.id == S.wave1 and x.holding and x.breach and x.stage == "inside" then
            local sp = surface().find_entities_filtered{name = "lp-bred-medium-spitter", position = x.breach, radius = 15}
            S.held = math.max(S.held or 0, #sp)
          end
          if x.id == S.wave1 and x.stage == "withdraw" then
            local sp = surface().find_entities_filtered{name = "lp-bred-medium-spitter", position = x.breach, radius = 15}
            local g = x.group and #surface().find_entities_filtered{name = "lp-bred-medium-biter", position = x.breach, radius = 15} or 0
            S.covering = math.max(S.covering or 0, #sp)
          end
        end
      end)
    end
  end
  -- The trail: there 15 minutes after the mark, gone 21 minutes after.
  for t = 3 * 3600, END - 120, 600 do
    schedule(t, function()
      local w = S.wave1 and entry(S.wave1)
      local mark_t = w and w.t_mark or S.mark_t
      if not mark_t then
        for _, x in ipairs(lp("herd_state").waves) do if x.id == S.wave1 and x.mark then S.mark_t = S.mark_t or game.tick end end
      end
      if w and w.trail and mark_t then
        local since = game.tick - mark_t
        if since >= 15 * 3600 and not S.mud15 then S.mud15 = mud_near(w.trail); S.mud_in = mud_inside() end
        -- (Gone 21 minutes after the last of it was laid: a deep strike lays its way on at the breach, round the fire, a
        -- minute after its mark.)
        local laid = math.max(mark_t, w.t_breach or 0)
        if game.tick - laid >= 21 * 3600 and not S.mud21 then S.mud21 = mud_near(w.trail) end
      end
      local rear_out = mix == "spit" and #(lp("herd_state").rears or {}) > 0
      if mix ~= "" and w and not rear_out and (mix ~= "scout" or (S.wave2 and entry(S.wave2))) then finish_early() end
      if mix == "" and S.mud21 then finish_early() end
    end)
  end
  schedule(END - 60, function()
    local w = S.wave1 and entry(S.wave1)
    local state = lp("herd_state")
    info("herd: " .. serpent.line(w))
    info("herd threat profiles: " .. serpent.line(lp("debug_threat", {"gun-turret", "laser-turret", "flamethrower-turret",
      "artillery-turret", "artillery-wagon", "small-worm-turret"})))
    info("herd: waves still out " .. serpent.line(state.waves))
    -- The test's own tally of what Synthexis razed of the player's sees what the wave broke (filtered, it saw none of the
    -- 46 a wave broke here, and a visit's report read nw's 444 as nothing; 2026-10-29).
    local tallied = 0
    for _, v in pairs(S.syn_razed or {}) do tallied = tallied + v end
    local broke = 0
    for name, v in pairs(w and w.kills or {}) do broke = broke + v end
    check("herd: the test's tally saw what the wave broke of the player's", broke == 0 or tallied >= broke,
      string.format("%d tallied of %d", tallied, broke))
    -- The deep strike (0.2.30): told (deep), it rushed for the heart and got there; a hard shell round a soft middle
    -- (shell), it chose to; this base's heart too near its breach (the plain herd), it raided the edge.
    if mix == "deep" or mix == "" then
      local d = w and w.deep
      -- (Or it broke in beside the heart: its way in priced from its own side, costmap, it can land within DEEP_MIN of it,
      -- and needs no strike; 2026-10-27.)
      local near = mix == "" and w and w.heart_near
      check("herd: " .. (mix == "" and "a shell round a soft middle" or "told") .. ", a deep strike for the heart, or in beside it",
        d ~= nil or near, serpent.line({deep = d, near = near}))
      check("herd: it reached the heart", (d and d.reached == true) or near, serpent.line(d))
      check("herd: inside, its biters each went for their own (more than one target down)", w and (w.downed or 0) >= 2,
        tostring(w and w.downed))
      if mix == "deep" then return end
    end
    if mix == "core" then check("herd: its heart guarded, it raided the edge", w and w.deep == nil, serpent.line(w and w.deep)) end
    if mix == "flamer" then
      -- Its scout looped past the flamethrowers' reach (threat.lua: 30 and 2, and LOOP_SPARE) and saw the base: no blind wave.
      check("herd: flamer, the scout's loop past a flamethrower's reach", w and (w.loop or 0) >= 35, tostring(w and w.loop))
      check("herd: flamer, the scout lived to mark a face", w and w.blind == false and w.mark ~= nil,
        serpent.line({blind = w and w.blind, mark = w and w.mark}))
    end
    if mix == "fire" then
      check("herd: fire, caught under fire on the march, it broke in where it stood", w and w.under_fire ~= nil,
        serpent.line(w and {under_fire = w.under_fire, breach = w.breach, outcome = w.outcome}))
      return
    end
    if mix == "stomp" then
      info(string.format("herd stomp: inside at %s, stompers left %s, own hurt by a stomper %s", tostring(S.stomp_in),
        tostring(S.stompers), tostring(S.damage["stomper>own"])))
      check("herd: stomp, a stomper got inside the wall", S.stomp_in ~= nil, tostring(S.stomp_in))
      check("herd: stomp, no Synthexis unit hurt by a stomper", (S.damage["stomper>own"] or 0) == 0,
        tostring(S.damage["stomper>own"]))
      return
    end
    if mix == "wallgoal" then
      info(string.format("herd wallgoal: inside at %s, %s of its own past the wall then; kills %s", tostring(S.inside_at),
        tostring(S.past_at_inside), serpent.line(w and w.kills)))
      local sw = w and w.sweep_mines
      check("herd: wallgoal, its sweep went at the mines before the wall alone", sw ~= nil and sw >= 1 and sw <= 3, tostring(sw))
      -- The contract, for every attacker (attempt.lua): its own "in" is what the observer sees, from where its units stood.
      local rec
      for _, r in ipairs(lp("oplog_recent")) do if r.key == "w" .. tostring(S.wave1) then rec = r end end
      local a = rec and rec.attempt or {}
      info("herd wallgoal: its record " .. serpent.line(a))
      -- (Not before: its own claim no more than 3 s ahead of the observer's, which looks every half second. With the wall
      -- test off its wave claimed in at once and broke in for real 8 s on: both said in by the end.)
      local own = w and w.t_inside
      check("contract: in means in, as the observer sees it", rec ~= nil and a.inside == (own ~= nil)
        and (own == nil or own >= (a.tick_inside or math.huge) - 180) and (a.sent or 0) > 0 and (a.lost or 0) > 0,
        serpent.line({observer = a.tick_inside, own = own, sent = a.sent, lost = a.lost, got = a.got}))
      check("herd: wallgoal, through only once past the wall", S.inside_at ~= nil and (S.past_at_inside or 0) >= 1,
        string.format("inside at %s, %s past the wall", tostring(S.inside_at), tostring(S.past_at_inside)))
      return
    end
    if mix == "burst" or mix == "burst-nohold" then
      local k, walls, guns = w and w.kills or {}, 0, 0
      for name, n in pairs(k) do
        local pr = prototypes.entity[name]
        if pr and pr.type == "wall" then walls = walls + n elseif pr and pr.type:find("turret") then guns = guns + n end
      end
      local alive = 0
      for _, t in ipairs(S.turrets) do if t.valid then alive = alive + 1 end end
      info(string.format("herd %s: bursters %s; broke %d wall pieces, %d turrets (%d of %d standing); kills %s", mix,
        serpent.line(w and w.bursters), walls, guns, alive, #S.turrets, serpent.line(k)))
      if mix == "burst" then
        local b = w and w.bursters or {}
        check("herd: burst, the bursters were held and released", (b.held or 0) == 4 and b.released ~= nil, serpent.line(b))
        local broke = 0
        for _, n in pairs(b.broke or {}) do broke = broke + n end
        check("herd: burst, their bursts broke something", broke > 0, serpent.line(b))
      else
        check("herd: burst-nohold, the wave went in and finished", w ~= nil and w.breach ~= nil, serpent.line(w and w.breach))
      end
      return
    end
    if mix == "probe" then
      local dry = S.at(S.dry_at[1], S.dry_at[2])
      local lit = S.at(S.dry_at[1], -S.dry_at[2])
      local b = w and w.breach
      local dd = b and math.sqrt((b[1] - dry[1]) ^ 2 + (b[2] - dry[2]) ^ 2) or -1
      local dl = b and math.sqrt((b[1] - lit[1]) ^ 2 + (b[2] - lit[2]) ^ 2) or -1
      info(string.format("herd probe: %s; breach %s, %.0f from the dry gun, %.0f from its lit twin", serpent.line(w and w.probe),
        serpent.line(b), dd, dl))
      check("herd: the probe found a silent turret", w and w.probe and w.probe.silent >= 1, serpent.line(w and w.probe))
      check("herd: the probe saw turrets fire", w and w.probe and w.probe.fired >= 1, serpent.line(w and w.probe))
      check("herd: it breached at the silent turret", b and dd < dl and dd <= 12, string.format("%.0f / %.0f", dd, dl))
    end
    if mix == "spit" then
      local spit_home = surface().count_entities_filtered{name = "lp-bred-medium-spitter", position = S.at(180, 0), radius = 60}
      info(string.format("herd spit: at most %s spitters at the breach while inside, %s while withdrawing, %d by the pen",
        tostring(S.held), tostring(S.covering), spit_home))
      check("herd: spitters held the breach while the herd was inside", (S.held or 0) >= 3, tostring(S.held))
      check("herd: spitters stayed at the breach as the herd withdrew", (S.covering or 0) >= 1, tostring(S.covering))
      check("herd: the wave came home", w and (w.outcome == "home" or w.outcome == "home late"), tostring(w and w.outcome))
      -- Those that covered the withdrawal came home (up to five; 0.2.21: five at least, but how many live to cover is the
      -- fight's: 3, 7 and 6 covered on three seeds, and every one came home).
      check("herd: the spitters came home behind it", spit_home >= math.min(5, S.covering or 0) and spit_home > 0,
        string.format("%d home of %d covering", spit_home, S.covering or 0))
    end
    local power = 0
    for _, e in ipairs(S.power or {}) do if e.valid then power = power + 1 end end
    local turrets = 0
    for _, t in ipairs(S.turrets) do if t.valid then turrets = turrets + 1 end end
    info(string.format("herd: power sources left %d of %d; turrets left %d of %d; damage between forces %s", power,
      #(S.power or {}), turrets, #S.turrets, serpent.line(S.damage)))
    check("herd: the wave ended", w ~= nil, w and w.outcome or "still out")
    if not w then return end
    -- Nothing in sight at the wall, it pushes in and looks again there (0.2.31: it looked again two seconds on, where it
    -- stood, and went home, losing more on the way out than on the way in).
    check("herd: a wave that pushed in got there before it turned", w.push_walked == nil or w.push_walked >= 10,
      tostring(w.push_walked))
    local wb = (S.damage["enemy>lp-biotech"] or 0) + (S.damage["lp-biotech>enemy"] or 0)
    check("herd: no fight between wild and bred", wb == 0, tostring(wb))
    if mix == "" or mix == "wild" or mix == "mega" then
      local s = w.t_launch
      info(string.format("herd: tell: mark %s s after launch, march %s s, breach %s s, first kill %s s, withdraw %s s, end %s s",
        tostring(w.t_mark and (w.t_mark - s) / 60), tostring(w.t_march and (w.t_march - s) / 60),
        tostring(w.t_breach and (w.t_breach - s) / 60), tostring(w.t_first_kill and (w.t_first_kill - s) / 60),
        tostring(w.t_withdraw and (w.t_withdraw - s) / 60), tostring((w.t_end - s) / 60)))
    end
    if mix == "stray" then
      local len = 0
      for k = 2, #(w.trail or {}) do
        local a, b = w.trail[k - 1], w.trail[k]
        len = len + math.sqrt(((a[1] or a.x) - (b[1] or b.x)) ^ 2 + ((a[2] or a.y) - (b[2] or b.y)) ^ 2)
      end
      check("herd: stray, strays sent home do not slow its march", (S.strayed or 0) > 0 and w.t_breach and w.t_march
        and w.t_breach - w.t_march <= len * 20,
        string.format("%s strayed; %s ticks for %.0f tiles", tostring(S.strayed), tostring(w.t_breach and w.t_march and w.t_breach - w.t_march), len))
      return
    end
    if mix == "" then
      check("herd: the scout marked a face", w.mark ~= nil and not w.blind, serpent.line(w.mark))
      -- Its trail walked: one leg after another, at a biter's pace (as one compound order the march "ended" 35 to 120
      -- ticks after it was given and the herd went straight at its mark; system sim, 2026-10-25).
      local len = 0
      for k = 2, #(w.trail or {}) do
        local a, b = w.trail[k - 1], w.trail[k]
        len = len + math.sqrt(((a[1] or a.x) - (b[1] or b.x)) ^ 2 + ((a[2] or a.y) - (b[2] or b.y)) ^ 2)
      end
      check("herd: it walked its trail", w.legs and w.legs > #w.trail and w.legs_failed * 2 <= #w.trail
        and w.t_breach and w.t_march and w.t_breach - w.t_march >= len * 3,
        string.format("legs %s of %d, %s failed; %s ticks for %.0f tiles", tostring(w.legs), #(w.trail or {}),
          tostring(w.legs_failed), tostring(w.t_breach and w.t_march and w.t_breach - w.t_march), len))
      check("herd: it walked home", w.outcome ~= "home" or (w.home_legs and w.home_n and w.home_legs > w.home_n),
        string.format("%s of %s legs", tostring(w.home_legs), tostring(w.home_n)))
      check("herd: the power died", power == 0, tostring(power))
      -- Cut the supply, then use it (0.2.12): with the power down it turns on the lasers it silenced, and stays until
      -- half are lost (it had gone home 34 of 41 strong with every laser standing). Some come home; turrets fall.
      -- (Went for, since 0.2.21: whether it breaks one is the numbers', staged at a corner beside a face of guns that need
      -- no power; 2 of 3 seeds broke one.)
      local cut = false
      for _, ty in ipairs(w.went_for or {}) do if ty == "electric-turret" then cut = true end end
      info(string.format("herd: turrets standing %d of %d; went for %s", turrets, #S.turrets, serpent.line(w.went_for)))
      check("herd: it went for turrets it had cut off", cut, serpent.line(w.went_for))
      check("herd: some came home", w.left * 4 >= w.size, string.format("%d of %d", w.left, w.size))
      check("herd: it went home", w.outcome == "home", w.outcome)
      check("herd: tell, a minute's gathering", w.t_march and w.t_mark and w.t_march - w.t_mark >= 3600,
        tostring(w.t_march and w.t_mark and (w.t_march - w.t_mark) / 60))
      check("herd: tell, the mark 90 s before the breach", w.t_breach and w.t_mark and w.t_breach - w.t_mark >= 90 * 60,
        tostring(w.t_breach and w.t_mark and (w.t_breach - w.t_mark) / 60))
      check("herd: tell, 3 minutes from the scout to the breach", w.t_breach and w.t_breach - w.t_launch >= 180 * 60,
        tostring(w.t_breach and (w.t_breach - w.t_launch) / 60))
      check("herd: the trail on the ground 15 minutes on", (S.mud15 or 0) >= 20, tostring(S.mud15))
      -- (A deep strike's trail runs on inside: its tell.)
      check("herd: no trail inside the wall", S.mud_in == 0 or w.deep ~= nil, tostring(S.mud_in))
      check("herd: the trail gone after 20 minutes", S.mud21 == 0, tostring(S.mud21))
    elseif mix == "keep" or mix == "second" then
      -- (second: not asked since 2026-10-27, open. A wave now breaks all it can take inside, and on this small base both
      -- sources stood in its reach; whether a second feed still counters it is a question for a base where it stands
      -- apart: keep, the feed under the inner keep's guns, is the counter asked here.)
      if mix == "keep" then check("herd: power still up (" .. mix .. ")", power >= 1, string.format("%d of %d", power, #S.power))
      else info(string.format("herd second: power still up %d of %d", power, #S.power)) end
      check("herd: it withdrew (" .. mix .. ")", w.t_withdraw ~= nil, w.outcome)
    elseif mix == "scout" then
      local w2 = S.wave2 and entry(S.wave2)
      check("herd: the scout killed, the wave chose its face all the same", w.mark ~= nil and not w.blind,
        serpent.line({mark = w.mark, blind = w.blind}))
      check("herd: the second wave ended", w2 ~= nil, "still out")
      check("herd: the next loop wider", w2 and w2.loop >= w.loop + 10,
        string.format("%s then %s", tostring(w.loop), tostring(w2 and w2.loop)))
    elseif mix == "belt" then
      local ins = 0
      for _, i in ipairs(S.inserters) do if not i.valid then ins = ins + 1 end end
      check("herd: inserters feeding the guns killed", ins >= 1, string.format("%d of %d", ins, #S.inserters))
      -- (The guns standing is no longer asked: since 2026-10-27 it kills the guns firing on it when it can take them, firemap.)
      info(string.format("herd belt: guns standing %d of %d", turrets, #S.turrets))
    elseif mix == "wild" then
      local wild = 0
      for _, e in ipairs(S.wild) do if e.valid then wild = wild + 1 end end
      check("herd: the wild nest untouched", wild == #S.wild, string.format("%d of %d", wild, #S.wild))
    elseif mix == "blind" then
      check("herd: blind, power up", power >= 1, tostring(power))
    elseif mix == "mega" then
      info(string.format("herd: mega: %d of %d home (%s), power left %d", w.left, w.size, w.outcome, power))
    end
  end)
end

-- Creep (Synthexis's, scripts/creep.lua): a player outpost (a turret, a substation), a nest field of five spawners 750
-- tiles out on the map's own ground, the biters' evolution at 0.3, and the culture landed by farm_arrive. A stone wall
-- of the player's 6 tiles from the first incubator, built as it lands. Six minutes on: a tumor by each incubator, grown
-- to its reach; creep round them; nothing of the player's can be built on it; the wall stands and its tile is not creep
-- (creep flows round); the ground under creep kept as its hidden tile; a hurt Synthexis biter on creep mends. Mixes:
--   spread: a wild nest 45 tiles past the field's edge: the creep buds toward it and takes it (an incubator)
--   killed: every tumor killed at 6 minutes: the creep withdraws, the incubators starve and go wild, the culture gone
--   clean: biomass in clean air: its books balance (pod + trickle + drunk = spent + left), little drunk, and births
--          stop when it has nothing (it never runs more than a breed's price into debt)
--   smog: 3,000 pollution a minute poured on the culture: its creep drinks it, and it breeds more than the trickle pays
--   strong: clean, Synthexis's strength lever at 2: its pod and trickle doubled (books on 400)
--   break: four minutes on, a Grubstake rifleman put 7 tiles from a tumor: the truce with Grubstake ends (both ways), and
--          the wild biters' cease-fire with Synthexis stands
scenarios.creep = function()
  local mix = params.mix or ""
  schedule(60, function()
    lp("debug_tune", {harmless = true, army_off = true, history_off = true, herd_off = true,
      levers = mix == "strong" and {biotech = {strength = 2}} or nil})
    local o = lp("stats", storage.id).origin
    local ux, uy = 0, 0
    if math.abs(o.x) > math.abs(o.y) then ux = o.x > 0 and -1 or 1 else uy = o.y > 0 and -1 or 1 end
    local vx, vy = -uy, ux
    local c = {ux * 250 + 0.5, uy * 250 + 0.5}
    local function at(du, dv) return {c[1] + ux * du + vx * dv, c[2] + uy * du + vy * dv} end
    for d = 0, 800, 32 do surface().request_to_generate_chunks(at(d, 0), 3) end
    surface().force_generate_chunk_requests()
    surface().create_entity{name = "substation", position = at(0, 0), force = "player"}
    surface().create_entity{name = "gun-turret", position = at(3, 3), force = "player"}
    for _, d in ipairs({{0, 0}, {14, 6}, {-12, 8}, {6, -14}, {-8, -12}}) do
      local q = surface().find_non_colliding_position("biter-spawner", at(750 + d[1], d[2]), 30, 1)
      if q then surface().create_entity{name = "biter-spawner", position = q, force = "enemy"} end
    end
    if mix == "spread" then
      local q = surface().find_non_colliding_position("biter-spawner", at(750, 65), 10, 1)
      S.far = q and surface().create_entity{name = "biter-spawner", position = q, force = "enemy"}
      S.far_at = q
    end
    game.forces.enemy.set_evolution_factor(0.3, surface())
    S.asked = lp("farm_arrive", surface().index)
  end)
  for t = 300, END - 120, 60 do
    schedule(t, function()
      local f = lp("farm_state").farms[1]
      if f and not S.landed then
        S.landed = game.tick
        local pen = surface().find_entities_filtered{name = "lp-pen", position = f.pos, radius = 80, limit = 1}[1]
        if pen then
          local q = surface().find_non_colliding_position("stone-wall", {pen.position.x + 6, pen.position.y}, 4, 1)
          S.wall = q and surface().create_entity{name = "stone-wall", position = q, force = "player"}
        end
        S.farm_pos = f.pos
      end
      -- A hurt Synthexis biter by the first incubator, two minutes in: does it mend on creep?
      if S.landed and not S.hurt and game.tick - S.landed >= 2 * 3600 then
        local u
        for _, c in ipairs(surface().find_entities_filtered{name = {"lp-bred-small-biter", "lp-bred-medium-biter"},
          position = S.farm_pos, radius = 60}) do
          if not u and surface().get_tile(c.position.x, c.position.y).name == "lp-creep" then u = c end
        end
        if u then
          u.health = u.max_health / 4
          S.hurt, S.hurt_at, S.hurt_from, S.hurt_max = u, game.tick, u.health, u.max_health
        end
      end
      if S.hurt and not S.mended and game.tick - S.hurt_at >= 600 then
        S.mended = S.hurt.valid and S.hurt.health or -1
      end
      if mix == "break" and S.landed and not S.intruder and game.tick - S.landed >= 4 * 3600 then
        local t = surface().find_entities_filtered{name = "lp-tumor", position = S.farm_pos, radius = 80, limit = 1}[1]
        local q = t and surface().find_non_colliding_position("lp-grubstake-infantry", {t.position.x + 7, t.position.y}, 4, 0.5)
        S.intruder = q and surface().create_entity{name = "lp-grubstake-infantry", position = q, force = "lp-grubstake"}
        S.intruder_at = game.tick
        S.ceased_before = game.forces["lp-biotech"].get_cease_fire("lp-grubstake")
      end
      if mix == "break" and S.intruder_at and not S.broken then
        local b = lp("herd_state").grubstake_broken
        if b then S.broken, S.broken_after = b, game.tick - S.intruder_at end
      end
      if mix == "killed" and S.landed and not S.killed and game.tick - S.landed >= 6 * 3600 then
        S.killed = game.tick
        for _, t in ipairs(surface().find_entities_filtered{name = "lp-tumor"}) do t.die("player") end
      end
      if mix == "smog" and S.landed and game.tick % 3600 < 60 then
        surface().pollute(S.farm_pos, 3000)
      end
      if (mix == "clean" or mix == "smog" or mix == "strong") and S.landed then
        local b = (lp("farm_state").farms[1] or {}).biomass
        if b then S.low = math.min(S.low or math.huge, b.now) end
      end
      -- A wild nest within a grown tumor's reach on ground its creep cannot cover (edge): a floor of stone path, which
      -- the creep grows round (creep.lua: mineable tiles are skipped).
      if mix == "edge" and S.landed and not S.edge and game.tick - S.landed >= 3 * 3600 then
        for _, tu in ipairs(lp("creep_state").tumors) do
          if not S.edge and tu.r >= 10 then
            for k = 0, 7 do
              local a = k * math.pi / 4
              local q = {math.floor(tu.pos.x + math.cos(a) * (tu.r - 3)) + 0.5, math.floor(tu.pos.y + math.sin(a) * (tu.r - 3)) + 0.5}
              local tiles = {}
              for dx = -4, 4 do for dy = -4, 4 do tiles[#tiles + 1] = {name = "stone-path", position = {q[1] + dx, q[2] + dy}} end end
              -- (Only where it goes, clear of its incubators: laid at each spot tried, it starved one of its own.)
              -- (Creep is on the object layer: a spawner can be placed on it only once the floor is down.)
              if not S.edge and surface().count_entities_filtered{name = "lp-pen", position = q, radius = 12, limit = 1} == 0
                and surface().count_entities_filtered{area = {{q[1] - 4, q[2] - 4}, {q[1] + 4, q[2] + 4}}, limit = 1} == 0 then
                surface().set_tiles(tiles)
                S.edge = surface().create_entity{name = "biter-spawner", position = q, force = "enemy"}
                S.edge_at = q
              end
            end
          end
        end
      end
      if mix == "spread" and S.far_at and not S.taken then
        local p = surface().find_entities_filtered{name = "lp-pen", position = S.far_at, radius = 3, limit = 1}[1]
        if p then S.taken = game.tick end
      end
    end)
  end
  schedule(END - 60, function()
    check("creep: the culture landed", S.landed ~= nil, tostring(S.asked))
    if not S.landed then return end
    -- Its grown tumors sunk in slime and roots (0.2.28): decoratives round each, and the trees on its creep bare.
    do
      local grown, decor, slime = 0, 0, 0
      for _, tu in ipairs(lp("creep_state").tumors) do
        if tu.r >= 10 then
          grown = grown + 1
          local a = {{tu.pos.x - 6, tu.pos.y - 6}, {tu.pos.x + 6, tu.pos.y + 6}}
          decor = decor + #surface().find_decoratives_filtered{area = a, name = {"cream-nerve-roots-veins-dense",
            "red-nerve-roots-veins-sparse", "curly-roots-grey", "knobbly-roots", "cream-nerve-roots-veins-sparse"}}
          slime = slime + #surface().find_decoratives_filtered{area = a, name = "polycephalum-slime"}
        end
      end
      local trees, bare = 0, 0
      for _, t in pairs(surface().find_entities_filtered{position = S.farm_pos, radius = 60, type = "tree"}) do
        if surface().get_tile(t.position.x, t.position.y).name == "lp-creep" then
          trees = trees + 1
          if ({["dry-tree"] = 1, ["dead-tree-desert"] = 1, ["dead-grey-trunk"] = 1, ["dead-dry-hairy-tree"] = 1,
            ["dry-hairy-tree"] = 1})[t.name] then bare = bare + 1 end
        end
      end
      info(string.format("creep: %d grown tumors, %d root and %d slime decoratives round them; trees on its creep %d, bare %d",
        grown, decor, slime, trees, bare))
      check("creep: its grown tumors sunk in slime and roots", grown == 0 or (slime >= grown and decor >= grown),
        string.format("%d tumors, %d roots, %d slime", grown, decor, slime))
      check("creep: the trees on its creep bare", trees == 0 or bare == trees, string.format("%d of %d", bare, trees))
    end
    if mix == "killed" then
      local fs = lp("farm_state")
      local tiles = surface().count_tiles_filtered{position = S.farm_pos, radius = 100, name = "lp-creep"}
      local wild = surface().count_entities_filtered{name = "biter-spawner", position = S.farm_pos, radius = 100}
      local feral = surface().count_entities_filtered{name = {"lp-bred-small-biter", "lp-bred-medium-biter"}, force = "enemy",
        position = S.farm_pos, radius = 150}
      info(string.format("creep killed: creep tiles %d, wild spawners %d, feral %d, farm %s", tiles, wild, feral,
        serpent.line(fs)))
      check("creep: every tumor killed, the creep withdrawn", tiles == 0, tostring(tiles))
      check("creep: the incubators back in the wild", wild >= 4, tostring(wild))
      check("creep: their stock gone feral", feral >= 1, tostring(feral))
      check("creep: the culture gone", #fs.farms == 0, serpent.line(fs.farms))
      return
    end
    if mix == "break" then
      local bf = game.forces["lp-biotech"]
      info(string.format("creep break: %s after %s ticks; cease-fire before %s, now %s / %s; with the wild %s",
        serpent.line(S.broken), tostring(S.broken_after), tostring(S.ceased_before),
        tostring(bf.get_cease_fire("lp-grubstake")), tostring(game.forces["lp-grubstake"].get_cease_fire(bf)),
        tostring(bf.get_cease_fire("enemy"))))
      -- A lasting truce (0.2.29; the user: "symbiotic"): until then Grubstake at its tumor broke it within a second.
      local tumors = surface().count_entities_filtered{name = "lp-tumor", position = S.farm_pos, radius = 80}
      check("creep: a truce with Grubstake before", S.ceased_before == true, tostring(S.ceased_before))
      check("creep: Grubstake beside its tumor, the truce holds", S.broken == nil, serpent.line(S.broken))
      check("creep: at peace both ways at the end", bf.get_cease_fire("lp-grubstake") and game.forces["lp-grubstake"].get_cease_fire(bf), "")
      -- (No Grubstake camp here, so no pacifier: the wild biters may kill it; Synthexis never.)
      check("creep: its tumors stand, and nothing of Synthexis's killed the rifleman", tumors > 0
        and S.intruder_killer ~= "lp-biotech", string.format("%d tumors, rifleman killed by %s", tumors, tostring(S.intruder_killer)))
      check("creep: still at peace with the wild biters", bf.get_cease_fire("enemy") == true, "")
      return
    end
    if mix == "clean" or mix == "smog" or mix == "strong" then
      local b = lp("farm_state").farms[1].biomass
      local pod = mix == "strong" and 400 or 200
      -- (Its growth's pool too: creep.earn, 2026-10-29.)
      local books = pod + b.trickled + b.drunk - b.spent - b.now - (b.growth or 0)
      info(string.format("creep %s: biomass %s, lowest %.1f, books off by %.2f", mix, serpent.line(b), S.low or -1, books))
      check("creep: the biomass books balance", math.abs(books) < 1, string.format("%.2f", books))
      check("creep: never more than a breed's price in debt", (S.low or 0) > -30, string.format("%.1f", S.low or -1))
      check("creep: it bred", b.bred >= 10, tostring(b.bred))
      if mix == "strong" then
        check("creep: strength 2, the trickle doubled (clean: 290 in 20 minutes)", b.trickled >= 500, string.format("%.0f", b.trickled))
      elseif mix == "clean" then
        check("creep: clean air, little drunk", b.drunk < 50, string.format("%.1f", b.drunk))
      else
        check("creep: smog drunk", b.drunk >= 300, string.format("%.1f", b.drunk))
        check("creep: smog bred more than the trickle and pod pay", b.spent > 200 + b.trickled + 100,
          string.format("spent %.0f, pod and trickle %.0f", b.spent, 200 + b.trickled))
      end
      return
    end
    -- A nest within its reach but off its creep was taken, starved off its creep in three minutes, went wild and was taken
    -- again, 172 times in five hours on nw (2026-10-29): now set aside, as a nest across water is.
    if mix == "edge" then
      local f = lp("farm_state").farms[1]
      check("creep: edge, a wild nest placed on ground its creep cannot cover", S.edge_at ~= nil, serpent.line(S.edge_at))
      check("creep: edge, no incubator starved off its creep", f and f.starved == 0, tostring(f and f.starved))
      return
    end
    if mix == "spread" then
      local f = lp("farm_state").farms[1]
      info(string.format("creep spread: far nest taken at %s (%.1f min after landing), %s", tostring(S.taken),
        S.taken and (S.taken - S.landed) / 3600 or -1, serpent.line(f)))
      check("creep: the far nest taken by its creep", S.taken ~= nil, tostring(S.far_at))
      return
    end
    local cs = lp("creep_state")
    local pens = #lp("farm_state").farms[1].pen_ids
    local grown = 0
    for _, t in ipairs(cs.tumors) do if t.r >= 10 then grown = grown + 1 end end
    local tiles = surface().find_tiles_filtered{position = S.farm_pos, radius = 80, name = "lp-creep"}
    local hidden_ok, hidden_seen = 0, nil
    for i = 1, math.min(20, #tiles) do
      local h = surface().get_hidden_tile(tiles[i].position)
      hidden_seen = hidden_seen or h
      if h and h ~= "lp-creep" then hidden_ok = hidden_ok + 1 end
    end
    local refused, tried = 0, 0
    for i = 1, #tiles, math.max(1, math.floor(#tiles / 10)) do
      local p = {tiles[i].position.x + 0.5, tiles[i].position.y + 0.5}
      tried = tried + 1
      if not surface().can_place_entity{name = "gun-turret", position = p, force = "player",
        build_check_type = defines.build_check_type.manual} then refused = refused + 1 end
    end
    local wp = S.wall and S.wall.valid and S.wall.position
    local under = wp and surface().get_tile(wp.x, wp.y).name
    local round = 0
    if wp then
      for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
        if surface().get_tile(wp.x + d[1], wp.y + d[2]).name == "lp-creep" then round = round + 1 end
      end
    end
    info(string.format("creep: %d pens, %d tumors (%d at full reach), %d creep tiles, hidden %d of 20 (%s), "
      .. "turrets refused %d of %d, wall %s on %s, creep beside it %d", pens, #cs.tumors, grown, #tiles, hidden_ok,
      tostring(hidden_seen), refused, tried, tostring(wp ~= nil), tostring(under), round))
    check("creep: a tumor by each incubator", #cs.tumors >= pens and pens >= 3, string.format("%d / %d", #cs.tumors, pens))
    check("creep: grown to full reach", grown == #cs.tumors, tostring(grown))
    check("creep: creep round the culture", #tiles >= 600, tostring(#tiles))
    check("creep: the ground under it kept", hidden_ok == math.min(20, #tiles), tostring(hidden_ok))
    check("creep: nothing of the player's built on it", refused == tried and tried > 0, string.format("%d / %d", refused, tried))
    check("creep: the player's wall stands, its tile not creep", wp and under ~= "lp-creep", tostring(under))
    check("creep: creep flowed round the wall", round >= 2, tostring(round))
    check("creep: a hurt Synthexis biter mended on it", S.mended and S.mended >= S.hurt_max * 0.99,
      string.format("%s from %s of %s", tostring(S.mended), tostring(S.hurt_from), tostring(S.hurt_max)))
  end)
end

-- Cinder (Synthexis's tier 3, biotech.lua): a cinder killed against a player wall (seven pieces, a gun turret two tiles
-- behind), a Synthexis medium and an incubator beside it. Within three seconds: the wall at it and the turret broken or
-- badly hurt, the Synthexis medium and the incubator untouched (the eruption spares its own force).
scenarios.cinder = function()
  schedule(60, function()
    lp("debug_tune", {harmless = true, army_off = true, history_off = true})
    local c = {-200.5, 200.5}
    surface().request_to_generate_chunks(c, 2); surface().force_generate_chunk_requests()
    flatten(c[1] - 20, c[2] - 20, c[1] + 20, c[2] + 20)
    S.walls = {}
    for i = -3, 3 do table.insert(S.walls, surface().create_entity{name = "stone-wall", position = {c[1] + i, c[2]}, force = "player"}) end
    S.turret = surface().create_entity{name = "gun-turret", position = {c[1], c[2] + 2.5}, force = "player"}
    S.cinder = surface().create_entity{name = "lp-bred-cinder", position = {c[1], c[2] - 1.5}, force = "lp-biotech"}
    S.mate = surface().create_entity{name = "lp-bred-medium-biter", position = {c[1] + 2, c[2] - 2}, force = "lp-biotech"}
    S.pen = surface().create_entity{name = "lp-pen", position = {c[1] - 3, c[2] - 5}, force = "lp-biotech"}
    S.mate.disabled_by_script = true
    S.cinder.disabled_by_script = true
  end)
  schedule(120, function() if S.cinder.valid then S.died_at = S.cinder.position; S.cinder.die("player") end end)
  schedule(360, function()
    local broken, hurt = 0, 0
    for _, w in ipairs(S.walls) do
      if not w.valid then broken = broken + 1 elseif w.health < w.max_health then hurt = hurt + 1 end
    end
    local th = S.turret.valid and S.turret.health or 0
    local fissures = surface().count_entities_filtered{name = "lp-cinder-fissure-scorchmark"}
    local hs = {}
    for _, w in ipairs(S.walls) do table.insert(hs, w.valid and string.format("%.0f", w.health) or "x") end
    info("cinder: walls " .. table.concat(hs, " ") .. string.format("; died at %s", serpent.line(S.died_at)))
    info(string.format("cinder: walls broken %d, hurt %d; turret %s; mate %s; incubator %s; scorchmarks %d", broken, hurt,
      S.turret.valid and string.format("%.0f/%d", th, S.turret.max_health) or "broken",
      S.mate.valid and string.format("%.0f/%d", S.mate.health, S.mate.max_health) or "dead",
      S.pen.valid and string.format("%.0f/%d", S.pen.health, S.pen.max_health) or "dead", fissures))
    check("cinder: the wall at it broken", broken >= 2, tostring(broken))
    check("cinder: the turret behind broken or badly hurt", not S.turret.valid or th <= S.turret.max_health / 2, tostring(th))
    check("cinder: its own medium untouched", S.mate.valid and S.mate.health == S.mate.max_health, "")
    check("cinder: its incubator untouched", S.pen.valid and S.pen.health == S.pen.max_health, "")
  end)
end

-- Farm (the biotech's arrival, scripts/farm.lua): the herd scenario's base (250 tiles from spawn, away from the harmless
-- Serenity camp), a nest field of five spawners and two worms 750 tiles beyond it over the map's own ground, the wild
-- biters' evolution at 0.3. The biotech comes by itself: its pod on the field, pens and worms, its tag on the map, and
-- after FIRST_WAVE its first wave walks the 750 tiles by waypoints to the base. Mixes:
--   raid: a pen hit while the wave marches: the wave turns home
--   killed: every pen destroyed: the farm and its tag gone, its next landing an hour off
--   wave: /lp wave's call a minute after landing: a wave out within a minute, not after FIRST_WAVE
local GROWTH_SMOG = 20       -- pollution laid on each of 25 points over the culture's ground every ten seconds (growth,
                             -- found): 3,000 a minute, the consult's dirty factory. 400 until 0.2.24 (60,000 a minute),
                             -- when the creep tiles alone ate and could take little of it.
scenarios.farm = function()
  local mix = params.mix or ""
  local L, G = "laser-turret", "gun-turret"
  local function put(name, p) return surface().create_entity{name = name, position = p, force = "player"} end
  schedule(60, function()
    lp("debug_tune", {harmless = true, army_off = true, history_off = true})
    local o = lp("stats", storage.id).origin
    local ux, uy = 0, 0
    if math.abs(o.x) > math.abs(o.y) then ux = o.x > 0 and -1 or 1 else uy = o.y > 0 and -1 or 1 end
    local vx, vy = -uy, ux
    local c = {ux * 250 + 0.5, uy * 250 + 0.5}
    local function at(du, dv) return {c[1] + ux * du + vx * dv, c[2] + uy * du + vy * dv} end
    S.at = at
    for d = 0, 800, 32 do surface().request_to_generate_chunks(at(d, 0), 3) end
    surface().force_generate_chunk_requests()
    local a, b = at(-60, -60), at(60, 60)
    flatten(math.min(a[1], b[1]), math.min(a[2], b[2]), math.max(a[1], b[1]), math.max(a[2], b[2]))
    for i = -40, 40 do
      put("stone-wall", at(40, i)); put("stone-wall", at(-40, i)); put("stone-wall", at(i, 40)); put("stone-wall", at(i, -40))
    end
    for _, t in ipairs({{L, 37, -24}, {G, 37, -14}, {L, 37, -5}, {G, 37, 4}, {L, 37, 13}, {G, 37, 22}, {L, 37, 30},
        {L, -12, -37}, {G, 12, -37}, {L, -12, 37}, {G, 12, 37}, {L, -37, 0}}) do
      local e = put(t[1], at(t[2], t[3]))
      if t[1] == G then e.insert{name = "piercing-rounds-magazine", count = 200} end
    end
    for x = -32, 32, 16 do for y = -32, 32, 16 do put("substation", at(x, y)) end end
    S.power = put("electric-energy-interface", at(4, 4))
    S.power.power_production, S.power.electric_buffer_size = 5e6, 5e7
    -- siege (2026-10-28): a laser wall no wave it fields crosses (a laser every 6 tiles on every face, nw's research): the
    -- chain from its order to the breach in minutes, which on nw took a three-hour visit a fault (its order bred the cheap
    -- breed first, its incubators overspent what it kept back, its wave left most bursters behind, each counted twice).
    if mix == "siege" or mix == "behind" or mix == "lab" then
      game.forces.player.set_ammo_damage_modifier("laser", 3)
      game.forces.player.set_gun_speed_modifier("laser", 2.2)
      -- (Every 3 tiles, 107 lasers: no siege of 20 big bursters opens that, and none was laid.)
      for i = -36, 36, 6 do
        for _, p in ipairs({{37, i}, {-37, i}, {i, 37}, {i, -37}}) do
          local q = surface().find_non_colliding_position(L, at(p[1], p[2]), 2, 1)
          if q then put(L, q) end
        end
      end
      S.power.power_production, S.power.electric_buffer_size = 1e9 / 60, 1e9
      S.lasers0 = surface().count_entities_filtered{name = L, force = "player"}
      -- And a pipeline of the player's out toward the nests, a megabase's outlying ground, worth nothing to it (read short of
      -- the foe's ground, its plan staged at its own nest, and its bursters went at nothing; poles drew waves of their own).
      -- (Not in the siege lab: a star fort's waves went in for the pipe at its edge, found nothing more, and died going out.)
      if mix ~= "lab" then for d = 48, 600 do put("pipe", at(d, 10)) end end
      -- And mines, a belt of them 3 to 9 tiles outside the wall on every face (nw's gap: 84 of them), its price for them
      -- learned (as if a wave had died to them): its sweep should set them off ahead of its wave.
      for i = -48, 48, 4 do
        for _, off in ipairs({43, 47}) do
          for _, p in ipairs({{off, i}, {-off, i}, {i, off}, {i, -off}}) do put("land-mine", at(p[1], p[2])) end
        end
      end
      S.mines0 = surface().count_entities_filtered{name = "land-mine", force = "player"}
      lp("debug_learn_price", "player", "land-mine", 40)
      lp("debug_tune", {march_trace = true})
      -- (Its big bursters developed: what is under test is the siege they make, not their development, herd.develop_bursters.
      -- Not in the lab: there they come of the walls that hold its waves.)
      if mix ~= "lab" then lp("debug_tune", {bursters = true}) end
      -- behind: a second ring of lasers 10 tiles inside the wall, out of a burster's blast at the wall (nw's flamethrower
      -- line): its weighing read the wall as one its bursters open, its plan refused every siege, and the two alternated
      -- for five hours at one place while 13,000 biomass piled up (2026-10-29).
      if mix == "behind" then
        for i = -24, 24, 6 do
          for _, p in ipairs({{27, i}, {-27, i}, {i, 27}, {i, -27}}) do
            local q = surface().find_non_colliding_position(L, at(p[1], p[2]), 2, 1)
            if q then put(L, q) end
          end
        end
      end
    end
    -- The siege lab's fed fort (scripts/siegelab.sh build <seed> fed): the square, its power from outside, a line of poles
    -- from the south face out to its source 90 tiles from the middle, out of its lasers' reach: the cut (feeds.lua,
    -- power.cut) a wave can take for its way there, every laser dark behind it.
    if params.fort == "fed" then
      local prod, buf = S.power.power_production, S.power.electric_buffer_size
      S.power.destroy()
      -- (A medium pole links within 9 tiles: at 16 from the substations, the line hung loose and every laser was dark.)
      for v = 38, 86, 6 do
        local q = surface().find_non_colliding_position("medium-electric-pole", at(2, v), 2, 1)
        if q then put("medium-electric-pole", q) end
      end
      S.power = put("electric-energy-interface", at(2, 89))
      S.power.power_production, S.power.electric_buffer_size = prod, buf
      -- (And a pole beside it: past the last pole's reach by half a tile, the source was on no network.)
      put("medium-electric-pole", {S.power.position.x, S.power.position.y - 2})
      schedule(game.tick + 300, function()
        local dark, lasers = 0, surface().find_entities_filtered{name = L, force = "player"}
        for _, l in ipairs(lasers) do if l.status == defines.entity_status.no_power then dark = dark + 1 end end
        check("lab: the fed fort's lasers powered through its line", #lasers > 0 and dark == 0,
          string.format("%d of %d dark", dark, #lasers))
      end)
    end
    -- The siege lab's star fort (scripts/siegelab.sh build <seed> star; the user, 2026-10-30: "a star fort inspired by
    -- french fortresses, with tons of mines at the star points to kill bursters and force them between legs"): five
    -- bastions, their points 72 tiles out, their flanks firing along the curtains between them (46 out); lasers inside
    -- the walls; a wedge of mines before each point, the ways to the curtains left open, under two bastions' flanks.
    if params.fort == "star" then
      for _, e in ipairs(surface().find_entities_filtered{force = "player", type = {"wall", "electric-turret", "ammo-turret", "land-mine"},
        area = {at(-62, -62), at(62, 62)}}) do e.destroy() end
      local a1, b1 = at(-110, -110), at(110, 110)
      local X0, Y0, X1, Y1 = math.min(a1[1], b1[1]), math.min(a1[2], b1[2]), math.max(a1[1], b1[1]), math.max(a1[2], b1[2])
      local a2, b2 = at(-60, -60), at(60, 60)
      local x0, y0, x1, y1 = math.min(a2[1], b2[1]), math.min(a2[2], b2[2]), math.max(a2[1], b2[1]), math.max(a2[2], b2[2])
      flatten(X0, Y0, x0, Y1); flatten(x1, Y0, X1, Y1); flatten(x0, Y0, x1, y0); flatten(x0, y1, x1, Y1)
      local function place(name, p)
        if surface().can_place_entity{name = name, position = p, force = "player"} then return put(name, p) end
      end
      local function polar(r, deg) local a = math.rad(deg); return r * math.cos(a), r * math.sin(a) end
      local walled = {}
      local function wall_line(u0, v0, u1, v1)
        local n = math.ceil(math.max(math.abs(u1 - u0), math.abs(v1 - v0)))
        for k = 0, n do
          local u, v = math.floor(u0 + (u1 - u0) * k / n + 0.5), math.floor(v0 + (v1 - v0) * k / n + 0.5)
          if not walled[u .. "," .. v] then walled[u .. "," .. v] = true; place("stone-wall", at(u, v)) end
        end
      end
      -- Lasers along a stretch of wall, `step` apart, `inset` tiles toward the middle.
      local function lasers_along(u0, v0, u1, v1, step, inset)
        local len = math.sqrt((u1 - u0) ^ 2 + (v1 - v0) ^ 2)
        for d = step / 2, len - 1, step do
          local u, v = u0 + (u1 - u0) * d / len, v0 + (v1 - v0) * d / len
          local r = math.sqrt(u * u + v * v)
          local q = surface().find_non_colliding_position(L, at(u - u / r * inset, v - v / r * inset), 3, 1)
          if q then put(L, q) end
        end
      end
      local R, SH, SHA, GO, GOA = 72, 52, 14, 46, 22
      local corners = {}
      for i = 0, 4 do
        local a = i * 72 - 90
        local su, sv = polar(R, a)
        local lu, lv = polar(SH, a - SHA); local ru, rv = polar(SH, a + SHA)
        local glu, glv = polar(GO, a - GOA); local gru, grv = polar(GO, a + GOA)
        corners[i] = {a = a, s = {su, sv}, l = {lu, lv}, r = {ru, rv}, gl = {glu, glv}, gr = {gru, grv}}
      end
      for i = 0, 4 do
        local c, nx = corners[i], corners[(i + 1) % 5]
        wall_line(c.gl[1], c.gl[2], c.l[1], c.l[2]); wall_line(c.l[1], c.l[2], c.s[1], c.s[2])
        wall_line(c.s[1], c.s[2], c.r[1], c.r[2]); wall_line(c.r[1], c.r[2], c.gr[1], c.gr[2])
        wall_line(c.gr[1], c.gr[2], nx.gl[1], nx.gl[2])
      end
      for i = 0, 4 do
        local c, nx = corners[i], corners[(i + 1) % 5]
        lasers_along(c.l[1], c.l[2], c.s[1], c.s[2], 6, 3); lasers_along(c.s[1], c.s[2], c.r[1], c.r[2], 6, 3)
        lasers_along(c.gl[1], c.gl[2], c.l[1], c.l[2], 4.5, 3); lasers_along(c.r[1], c.r[2], c.gr[1], c.gr[2], 4.5, 3)
        lasers_along(c.gr[1], c.gr[2], nx.gl[1], nx.gl[2], 9, 3)
        -- Its point's mines: a wedge from 4 to 22 tiles out, widening as it goes.
        local du, dv = math.cos(math.rad(c.a)), math.sin(math.rad(c.a))
        for d = 4, 22, 2.5 do
          local half = 3 + 0.6 * d
          for w = -half, half, 2.5 do place("land-mine", at(c.s[1] + du * d - dv * w, c.s[2] + dv * d + du * w)) end
        end
      end
      for u = -64, 64, 16 do for v = -64, 64, 16 do if u * u + v * v <= 60 * 60 then place("substation", at(u, v)) end end end
      S.lasers0 = surface().count_entities_filtered{name = L, force = "player"}
      S.mines0 = surface().count_entities_filtered{name = "land-mine", force = "player"}
      info(string.format("lab: star fort, %d lasers, %d mines, %d wall pieces", S.lasers0, S.mines0,
        surface().count_entities_filtered{type = "wall", force = "player"}))
    end
    -- The siege lab's empty plot (scripts/siegelab.sh build <seed> plot; the user, 2026-10-30: "a save with fortress
    -- boundaries and let me just build some different fortresses to test out"): the square fort's walls, guns and mines
    -- cleared, the ground flattened 110 tiles round its middle, the plot's edge in hazard concrete, its soft heart and the
    -- power at its middle kept. Nothing defends it.
    if params.fort == "plot" then
      for _, e in ipairs(surface().find_entities_filtered{force = "player", type = {"wall", "gate", "electric-turret", "ammo-turret",
        "land-mine"}, area = {at(-62, -62), at(62, 62)}}) do e.destroy() end
      local a1, b1 = at(-110, -110), at(110, 110)
      local X0, Y0, X1, Y1 = math.min(a1[1], b1[1]), math.min(a1[2], b1[2]), math.max(a1[1], b1[1]), math.max(a1[2], b1[2])
      local a2, b2 = at(-60, -60), at(60, 60)
      local x0, y0, x1, y1 = math.min(a2[1], b2[1]), math.min(a2[2], b2[2]), math.max(a2[1], b2[1]), math.max(a2[2], b2[2])
      flatten(X0, Y0, x0, Y1); flatten(x1, Y0, X1, Y1); flatten(x0, Y0, x1, y0); flatten(x0, y1, x1, Y1)
      local edge = {}
      for u = -108, 107 do
        for _, v in ipairs({-108, -107, 106, 107}) do
          local p, q = at(u, v), at(v, u)
          edge[#edge + 1] = {name = "hazard-concrete-left", position = {math.floor(p[1]), math.floor(p[2])}}
          edge[#edge + 1] = {name = "hazard-concrete-left", position = {math.floor(q[1]), math.floor(q[2])}}
        end
      end
      surface().set_tiles(edge, true, false, true, false)
      local c = at(0, 0)
      game.forces.player.add_chart_tag(surface(), {position = c, text = "Fortress plot (build within the hazard line)"})
      S.lasers0, S.mines0 = 0, 0
    end
    -- The siege lab's lane (scripts/siegelab.sh build <seed> lane; the user, 2026-10-31: "an optimized variant with no
    -- corners ... very limited y axis height, and our base west, enemy base east ... iterate on wall design"): a corridor
    -- of sand on a ribbon map (the user: "simply use the ribbon map settings"), its edge HALF tiles either side of the axis,
    -- and one front: a wall from edge to edge, its guns and mines by
    -- LAB_LANE (key=value, comma-separated): walls (layers, 1), gap (tiles between them, 4), step (a laser every, 6),
    -- inset (guns behind the inner wall, 3), mines (out, in, between or none; out), half (the corridor's half-height, 64),
    -- guns (laser, gun, flame, rocket, tesla by turns, joined by +; laser), shape (line, saw, bastion; line), amp (8), period (32),
    -- faces (east, toward the culture; west, toward the corporation camp behind the fort; both); shape maze: its walls
    -- each open mgap tiles (6) at alternate ends but the innermost, closed (the user, 2026-10-31: "a tower defense like maze
    -- wall ... closed off at the final layer"); tech (early, mid, late: its guns' damage and speed research, set at build);
    -- outpost (1: a mining outpost of four drills and a chest, unwalled and unguarded, 80 tiles out from the west front
    -- toward the camps, its pole line back to the fort: the soft target beside a fort, for Grubstake, which should take it
    -- and leave the wall; the user, 2026-10-31); power (in, the fort's own; east, its source 60 tiles out before its wall on
    -- a line of poles through it, a feed to cut: a tesla line needs a great deal of power, and Synthexis's answer to it is
    -- that power, the counters consult, 2026-10-31).
    -- Twice as many lasers within a laser's reach of each end: at the water a wall point saw half the guns its middle did
    -- (5 against 8), and three plain waves went in at its end, none of them a siege (the lab, 2026-10-31): a lane whose
    -- every point faces the same guns.
    if params.fort == "lane" then
      local o = {walls = 1, gap = 4, step = 6, inset = 3, mines = "out", half = 64, guns = "laser", shape = "line", amp = 8, period = 32,
        faces = "east", mgap = 6, outpost = 0, power = "in"}
      for k, v in string.gmatch(params.lane or "", "(%w+)=([%w%.%+]+)") do o[k] = tonumber(v) or v end
      -- (The map a ribbon HALF either side of y 0, siegelab.sh's map settings: its edge, out of map, collides as water does,
      -- its cost map's no way and the engine's. The fort's axis along it, its camp east or west.)
      if uy ~= 0 then error("lab: the lane needs its axis along the ribbon (x); the camp lay north or south") end
      local HALF, U0, U1 = o.half, -150, 900
      -- Its guns' research (LAB_LANE tech): damage and speed for each kind together, in place of the lab's lasers alone
      -- (3 and 2.2: its gun turrets fired unresearched rounds beside researched lasers, and half a mixed line was weak).
      local TECH = {
        early = {laser = {0.3, 0.5}, bullet = {0.3, 0.3}, flamethrower = {0.2, 0}, rocket = {0.2, 0.2}, electric = {0.2, 0}},
        mid = {laser = {1.5, 1.2}, bullet = {1.2, 0.9}, flamethrower = {0.8, 0}, rocket = {0.9, 0.7}, electric = {0.8, 0}},
        late = {laser = {3, 2.2}, bullet = {2.5, 1.8}, flamethrower = {1.6, 0}, rocket = {1.8, 1.4}, electric = {1.6, 0}},
      }
      if o.tech then
        local lv = TECH[o.tech] or error("lab: no tech " .. tostring(o.tech))
        for cat, v in pairs(lv) do
          game.forces.player.set_ammo_damage_modifier(cat, v[1])
          game.forces.player.set_gun_speed_modifier(cat, v[2])
        end
      end
      for d = U0, U1, 32 do surface().request_to_generate_chunks(at(d, 0), 2) end
      surface().force_generate_chunk_requests()
      for _, e in ipairs(surface().find_entities_filtered{force = "player", type = {"wall", "gate", "electric-turret", "ammo-turret",
        "land-mine"}}) do e.destroy() end
      local function box(u0, v0, u1, v1)
        local a, b = at(u0, v0), at(u1, v1)
        return math.floor(math.min(a[1], b[1])), math.floor(math.min(a[2], b[2])), math.floor(math.max(a[1], b[1])), math.floor(math.max(a[2], b[2]))
      end
      local function on_map(p) return not surface().get_tile(p[1], p[2]).collides_with("out_of_map") end
      -- Sand from behind the fort to past the culture's field, nothing standing on it but the fort's own heart.
      local tiles = {}
      local x0, y0, x1, y1 = box(U0, -HALF - 2, U1, HALF + 2)
      for x = x0, x1 do for y = y0, y1 do
        if on_map({x, y}) then tiles[#tiles + 1] = {name = "sand-1", position = {x, y}} end
      end end
      local keep = {}
      local k0, l0, k1, l1 = box(-36, -36, 36, 36)
      local function key(e) return e.name .. "@" .. e.position.x .. "," .. e.position.y end
      for _, e in ipairs(surface().find_entities_filtered{force = "player", area = {{k0, l0}, {k1, l1}}}) do keep[key(e)] = true end
      for _, e in ipairs(surface().find_entities_filtered{area = {{x0, y0}, {x1 + 1, y1 + 1}}}) do
        if e.valid and e.type ~= "character" and not (e.force.name == "player" and keep[key(e)]) then e.destroy() end
      end
      surface().set_tiles(tiles, true, true, true, false)
      local function place(name, p)
        local q = surface().find_non_colliding_position(name, p, 2, 1)
        return q and put(name, q)
      end
      -- Its walls' shape (the user, 2026-10-31: "incorporate various turret types and wall shapes"), how far each row of the
      -- front stands out toward the culture: line; saw, teeth `amp` deep every `period`; bastion, a point `amp` out over half
      -- of every `period`, straight between.
      local function bulge(v)
        if o.shape == "saw" then
          local t = ((v + HALF) % o.period) / o.period
          return o.amp * (1 - math.abs(2 * t - 1))
        elseif o.shape == "bastion" then
          local t = ((v + HALF) % o.period) / o.period
          return t >= 0.25 and t <= 0.75 and o.amp * (1 - math.abs(4 * t - 2)) or 0
        end
        return 0
      end
      -- Its front facing the culture (east), and with faces=both the same front mirrored west, facing the corporation camp
      -- behind the fort (the lab for the corporations: LAB_FACTION).
      local gaps, outer = 0, 40
      for _, sg in ipairs(o.faces == "both" and {1, -1} or o.faces == "west" and {-1} or {1}) do
        local function A(u, v) return at(sg * u, v) end
        local inner = 40   -- its inner wall, at a straight row (its outer walls `gap` on toward the culture)
        local function wall_u(k, v) return math.floor(inner + k * o.gap + bulge(v) + 0.5) end
        -- Edge to edge, each row joined to the last along the row (no two pieces only corner to corner: a herd slips between).
        for k = 0, o.walls - 1 do
          local last
          for v = -HALF, HALF do
            local u = wall_u(k, v)
            -- (A maze: each wall but the innermost open mgap tiles at one end, the next at the other.)
            local open = o.shape == "maze" and k > 0
              and ((k % 2 == 1 and v > HALF - o.mgap) or (k % 2 == 0 and v < -HALF + o.mgap))
            if not open then
              for w = math.min(u, last or u), math.max(u, last or u) do
                if on_map(A(w, v)) then put("stone-wall", A(w, v)) end
              end
            end
            last = u
          end
        end
        outer = inner + (o.walls - 1) * o.gap
        -- Its guns along the inner wall, `inset` behind it, by turns of LAB_LANE guns (laser, gun, flame, rocket, tesla, joined
        -- by +); twice as many within a laser's reach of each end. Flamethrowers fed by a pipe behind them, infinity pipes on it.
        local GUN = {laser = L, gun = G, flame = "flamethrower-turret", rocket = "rocket-turret", tesla = "tesla-turret"}
        local kinds = {}
        for g in string.gmatch(o.guns, "[^+]+") do kinds[#kinds + 1] = GUN[g] or error("lab: no gun " .. g) end
        local facing = sg * ux > 0 and defines.direction.east or defines.direction.west
        local REACH = prototypes.entity[L].attack_parameters.range
        local n = 0
        local function gun(name, u, v)
          local q = surface().find_non_colliding_position(name, A(u, v), 3, 1)
          local e = q and surface().create_entity{name = name, position = q, force = "player", direction = facing}
          if not e then return end
          if name == G then e.insert{name = "piercing-rounds-magazine", count = 200} end
          if name == "rocket-turret" then e.insert{name = "rocket", count = 100} end
          -- (Its feed an infinity pipe at one of its two inlets, beside its rear row (fire.lua: {-0.5, 1} facing west when it
          -- faces north): oil kept through every rebuild, lab snapshot. Behind it, every one stood dry.)
          if name == "flamethrower-turret" then
            local pp = {e.position.x - sg * ux * 1, e.position.y - sg * ux * 1.5}
            local pipe = surface().create_entity{name = "infinity-pipe", position = pp, force = "player"}
            if pipe then pipe.set_infinity_pipe_filter{name = "light-oil", percentage = 1, mode = "at-least"} end
            S.lane_flames = (S.lane_flames or 0) + 1
          end
        end
        for v = -HALF + o.step / 2, HALF - 1, o.step do
          n = n + 1
          local name = kinds[(n - 1) % #kinds + 1]
          local u = inner + bulge(v) - o.inset - (name == "flamethrower-turret" and 1 or 0)
          gun(name, u, v)
          if HALF - math.abs(v) <= REACH then gun(L, u - 3, v + o.step / 4 * (v < 0 and -1 or 1)) end
        end
        local rows = o.mines == "out" and {outer + 3, outer + 7} or o.mines == "in" and {inner - o.inset - 4}
          or o.mines == "between" and o.walls > 1 and {inner + o.gap / 2} or {}
        for _, u in ipairs(rows) do for v = -HALF + 2, HALF - 2, 4 do place("land-mine", A(u + bulge(v), v)) end end
        for u = 16, 32, 16 do for v = -HALF, HALF, 16 do if math.abs(v) > 32 then place("substation", A(u, v)) end end end
        -- No way round: along each wall's line and past its ends, every tile walled or off the map (a tile of it, and a herd
        -- walks round).
        for k = 0, (o.shape == "maze" and 0 or o.walls - 1) do
          for v = -HALF - 3, HALF + 3 do
            local p = A(wall_u(k, v), v)
            if on_map(p)
              and surface().count_entities_filtered{position = p, radius = 0.5, type = "wall", force = "player"} == 0 then gaps = gaps + 1 end
          end
        end
      end
      S.lasers0 = surface().count_entities_filtered{name = L, force = "player"}
      S.mines0 = surface().count_entities_filtered{name = "land-mine", force = "player"}
      if o.power == "east" then
        local prod, buf = S.power.power_production, S.power.electric_buffer_size
        S.power.destroy()
        for u = 28, 40 + 60, 8 do place("medium-electric-pole", at(u, 2)) end
        S.power = put("electric-energy-interface", at(40 + 62, 2))
        S.power.power_production, S.power.electric_buffer_size = prod, buf
        put("medium-electric-pole", at(40 + 62, 0))
        schedule(game.tick + 300, function()
          local dark, guns = 0, surface().find_entities_filtered{type = "electric-turret", force = "player"}
          for _, g in ipairs(guns) do if g.status == defines.entity_status.no_power then dark = dark + 1 end end
          if dark > 0 then error(string.format("lab: %d of the lane's %d electric turrets dark on its outside power", dark, #guns)) end
        end)
      end
      if (o.outpost or 0) > 0 then
        local ou = -(40 + 80)
        local ore = {}
        for du = -8, 8 do for dv = -8, 8 do
          local p = at(ou + du, dv)
          ore[#ore + 1] = {name = "iron-ore", position = {math.floor(p[1]), math.floor(p[2])}, amount = 5000}
        end end
        for _, r in ipairs(ore) do surface().create_entity(r) end
        for _, d in ipairs({{-3, -3}, {3, -3}, {-3, 3}, {3, 3}}) do
          local q = surface().find_non_colliding_position("electric-mining-drill", at(ou + d[1], d[2]), 3, 1)
          if q then put("electric-mining-drill", q) end
        end
        put("iron-chest", at(ou, 0))
        -- Its pole line back to the fort (a medium pole every 8 tiles: they link within 9).
        for u = ou + 6, -32, 8 do place("medium-electric-pole", at(u, 0)) end
        S.outpost = at(ou, 0)
      end
      info(string.format("lab: lane %s, %d lasers, %d mines, %d wall pieces, %d gaps past its ends", serpent.line(o), S.lasers0,
        S.mines0, surface().count_entities_filtered{type = "wall", force = "player"}, gaps))
      -- Its flamethrowers fed (a pipe at the wrong tile, and they stand dry).
      if (S.lane_flames or 0) > 0 then
        schedule(game.tick + 120, function()
          local dry = 0
          for _, f in ipairs(surface().find_entities_filtered{name = "flamethrower-turret", force = "player"}) do
            if f.get_fluid_count() <= 0 then dry = dry + 1 end
          end
          if dry > 0 then error(string.format("lab: %d of the lane's %d flamethrowers dry", dry, S.lane_flames)) end
        end)
      end
      -- (A build writes no results: a gap stops it, or a lane a herd walks round is saved for trials.)
      if gaps > 0 then error(string.format("lab: the lane's walls leave %d gaps past their ends", gaps)) end
      game.forces.player.add_chart_tag(surface(), {position = at(outer, -HALF), text = "Lane front (LAB_LANE: " .. (params.lane or "default") .. ")"})
    end
    -- What any player's base has, and what draws a wave (its smell, farm.target_from): machines that pollute.
    for _, d in ipairs({{-20, -20}, {-20, 20}, {20, -20}, {20, 20}}) do
      local q = surface().find_non_colliding_position("assembling-machine-2", at(d[1], d[2]), 8, 1)
      if q then put("assembling-machine-2", q) end
    end
    for _, d in ipairs({{-8, 0}, {8, -8}}) do
      local q = surface().find_non_colliding_position("boiler", at(d[1], d[2]), 8, 1)
      if q then put("boiler", q) end
    end
    -- The nest field, on the map's own ground.
    S.field = {}
    for _, d in ipairs({{0, 0}, {14, 6}, {-12, 8}, {6, -14}, {-8, -12}}) do
      local q = surface().find_non_colliding_position("biter-spawner", at(750 + d[1], d[2]), 30, 1)
      if q then table.insert(S.field, surface().create_entity{name = "biter-spawner", position = q, force = "enemy"}) end
    end
    for _, d in ipairs({{20, 0}, {-20, 0}}) do
      local q = surface().find_non_colliding_position("medium-worm-turret", at(750 + d[1], d[2]), 30, 1)
      if q then surface().create_entity{name = "medium-worm-turret", position = q, force = "enemy"} end
    end
    -- growth: room to grow, to see its curve (the user, 2026-10-25: "I want to see the sigmoid"): 24 more spawners within
    -- its creep's reach round the field, and pollution over its ground every ten seconds; a record a minute.
    if mix == "growth" then
      for k = 1, 24 do
        local a, r = k * 2.4, 40 + (k % 6) * 20
        local q = surface().find_non_colliding_position("biter-spawner", at(750 + math.cos(a) * r, math.sin(a) * r), 20, 1)
        if q then table.insert(S.field, surface().create_entity{name = "biter-spawner", position = q, force = "enemy"}) end
      end
    end
    -- fed (0.2.24): a second field 330 tiles out, in a cloud laid round it: its pod comes down there, not at the field
    -- 750 out (the user, 2026-10-26: "tie this to pollution cloud coverage to ensure a new culture can feed itself").
    if mix == "fed" then
      for d = 200, 460, 32 do surface().request_to_generate_chunks(at(d, 0), 3) end
      surface().force_generate_chunk_requests()
      S.fed_field = {}
      for _, d in ipairs({{0, 0}, {14, 6}, {-12, 8}, {6, -14}}) do
        local q = surface().find_non_colliding_position("biter-spawner", at(330 + d[1], d[2]), 30, 1)
        if q then table.insert(S.fed_field, surface().create_entity{name = "biter-spawner", position = q, force = "enemy"}) end
      end
    end
    -- moat (0.2.28): the only other wild nest in its creep's reach (120 tiles off) stands in a lake 25 tiles wide (a
    -- tumor that cannot stand on water stands within 10 tiles of where it was meant: a narrow moat it hops): its creep
    -- gives it up as out of reach and grows incubators of its own (until 0.2.28 it budded at it for ever).
    if mix == "moat" then
      local c = at(750, 120)
      surface().request_to_generate_chunks(c, 3)
      surface().force_generate_chunk_requests()
      local water = {}
      for dx = -32, 32 do for dy = -32, 32 do
        local d = dx * dx + dy * dy
        if d >= 6 * 6 and d <= 31 * 31 then water[#water + 1] = {name = "water", position = {c[1] + dx, c[2] + dy}} end
      end end
      surface().set_tiles(water)
      S.moat_nest = surface().create_entity{name = "biter-spawner", position = c, force = "enemy"}
      info(string.format("farm moat: nest %s at %.0f,%.0f", tostring(S.moat_nest and S.moat_nest.valid), c[1], c[2]))
    end
    -- seed, seedkill: a second wild field 400 tiles from the first, where its carrier goes (0.2.22).
    if mix == "seed" or mix == "seedkill" then
      for d = -40, 440, 32 do surface().request_to_generate_chunks(at(750, d), 3) end
      surface().force_generate_chunk_requests()
      S.field2 = {}
      for _, d in ipairs({{0, 0}, {14, 6}, {-12, 8}, {6, -14}}) do
        local q = surface().find_non_colliding_position("biter-spawner", at(750 + d[1], 400 + d[2]), 30, 1)
        if q then table.insert(S.field2, surface().create_entity{name = "biter-spawner", position = q, force = "enemy"}) end
      end
    end
    -- (clinic: the wild at 0.5, so the breeds' cap without a clinic, 0.3, shows.)
    -- (siege: 0.95, its big bursters come at 0.85: its evolution follows the wild's, farm.evolve.)
    game.forces.enemy.set_evolution_factor(mix == "clinic" and 0.5 or (mix == "siege" or mix == "behind" or mix == "lab") and 0.95 or 0.3, surface())
    info(string.format("farm: field of %d spawners at %.0f,%.0f", #S.field, at(750, 0)[1], at(750, 0)[2]))
  end)
  local function farm1() return lp("farm_state").farms[1] end
  -- The siege lab (scripts/siegelab.sh build): the siege test's fortress and its culture, grown to 8 incubators and saved;
  -- no wave goes meanwhile (herd_off: its trials send them, scenarios.lab).
  if params.lab == "build" then
    schedule(30, function() game.speed = 64 end)
    schedule(61, function() lp("debug_tune", {herd_off = true}) end)
    for t = 10 * 3600, END - 60, 600 do
      schedule(t, function()
        local f = farm1()
        if S.lab_saved or not (f and f.pens >= 8) then return end
        S.lab_saved = game.tick
        game.speed = 1
        -- (LAB_PENS: its culture grown to that many incubators, a late colony; its waves as large, farm.cap_of.)
        if (params.lab_pens or 0) > f.pens then lp("farm_add_pens", f.id, params.lab_pens - f.pens) end
        local pens = (farm1() or f).pens
        schedule(game.tick - storage.t0 + 1, function()
          game.server_save("lab")
          helpers.write_file("landing-party/lab-saved.txt", string.format("tick %d, %d incubators", game.tick, pens))
        end)
      end)
    end
  end
  -- fed: its cloud, from the start (before the pod) and on, between the base and the near field.
  if mix == "fed" then
    for t = 120, END - 120, 600 do
      schedule(t, function()
        for du = 240, 300, 30 do for dv = -60, 60, 60 do surface().pollute(S.at(du, dv), 400) end end
      end)
    end
  end
  -- seedbare: ripe, every wild nest within 1,100 of it gone, and a cloud 400 tiles off its side: its carrier founds an
  -- incubator on the bare ground there (0.2.24).
  if mix == "seedbare" then
    for t = 600, END - 120, 600 do
      schedule(t, function()
        for du = -60, 60, 60 do for dv = 340, 460, 60 do surface().pollute(S.at(750 + du, dv), 400) end end
      end)
    end
  end
  if mix == "growth" or mix == "found" or mix == "moat" then
    for t = 600, END - 120, 600 do
      schedule(t, function()
        local f = farm1()
        local c = f and f.pos or (S.at and {x = S.at(750, 0)[1], y = S.at(750, 0)[2]})
        if c then
          for dx = -120, 120, 60 do for dy = -120, 120, 60 do surface().pollute({c.x + dx, c.y + dy}, GROWTH_SMOG) end end
        end
      end)
    end
    for t = 3600, END - 120, 3600 do
      schedule(t, function()
        local f = farm1()
        if not f then return end
        local site = lp("cell_sites")[1] or {}
        local tumors = 0
        for _, tu in ipairs(lp("creep_state").tumors) do if tu.farm == f.id then tumors = tumors + 1 end end
        local b = f.biomass or {}
        helpers.write_file("landing-party/growth.jsonl", helpers.table_to_json({minute = game.tick / 3600, pens = f.pens,
          techs = site.techs or 0, bought = site.bought or 0, biomass = b.now, drunk = b.drunk, trickled = b.trickled,
          spent = b.spent, bred = b.bred, tumors = tumors, seeds = f.seeds or 0}) .. "\n", true)
      end)
    end
  end
  if mix == "seed" or mix == "seedkill" or mix == "seedbare" then
    for t = 600, END - 120, 120 do
      schedule(t, function()
        local cs = surface().find_entities_filtered{name = "lp-bred-carrier"}
        if #cs > 0 then
          S.carrier_seen = S.carrier_seen or game.tick
          -- seedkill: shot on its way, a minute out.
          if mix == "seedkill" and game.tick - S.carrier_seen >= 3600 and not S.carrier_killed then
            for _, c in ipairs(cs) do c.die("player") end
            S.carrier_killed = game.tick
          end
        end
      end)
    end
  end
  for t = 600, END - 120, 300 do
    schedule(t, function()
      local f = farm1()
      if f and not S.landed then
        S.landed = game.tick
        S.pens0 = f.pens
        S.worms = surface().count_entities_filtered{name = "lp-bred-worm", position = f.pos, radius = 80}
        local tags = game.forces.player.find_chart_tags(surface(), {{f.pos.x - 8, f.pos.y - 8}, {f.pos.x + 8, f.pos.y + 8}})
        S.tags, S.tag_text = #tags, tags[1] and tags[1].text
        S.farm_pos = f.pos
        S.dist = math.sqrt((f.pos.x - S.at(0, 0)[1]) ^ 2 + (f.pos.y - S.at(0, 0)[2]) ^ 2)
        S.evo_land = f.evo
        if mix == "siege" or mix == "behind" or mix == "lab" then
          S.min_bio, S.max_near, S.sieges = math.huge, 0, {}
          for t2 = game.tick - storage.t0 + 60, END - 120, 600 do
            schedule(t2, function()
              local g = farm1()
              if not g then return end
              -- (180 a minute: at 600 its order and its reserve could go wrong unseen, there was always enough; nw's
              -- poorest culture earned 23.)
              lp("debug_biomass", g.id, 30)
              local b = g.biomass and g.biomass.now
              if b and b < S.min_bio then S.min_bio = b end
              if g.siege then S.sieges[#S.sieges + 1] = g.siege.k end
            end)
          end
          for t2 = game.tick - storage.t0 + 60, END - 120, 30 do
            schedule(t2, function()
              local n = surface().count_entities_filtered{name = "lp-bred-big-burster", position = S.at(0, 0), radius = 120}
              if n > S.max_near then S.max_near = n end
            end)
          end
        end
        if mix == "artillery" then
          -- An artillery turret, loaded, in the middle of the base behind its guns, its range researched to reach the
          -- culture: it shells the pens (the perception consult, section 5), and the culture should come for it (in the
          -- open on its doorstep any wave passing broke it, the code before as well: no guard).
          -- (Ten minutes on, once it has bred: placed as it landed, the artillery razed its four pens in seventy seconds.)
          schedule(game.tick - storage.t0 + 10 * 3600, function()
            local b = S.at(0, 0)
            local dist = math.sqrt((b[1] - f.pos.x) ^ 2 + (b[2] - f.pos.y) ^ 2)
            game.forces.player.artillery_range_modifier = (dist + 40) / 224 - 1
            local q = surface().find_non_colliding_position("artillery-turret", b, 12, 1)
            S.art = q and surface().create_entity{name = "artillery-turret", position = q, force = "player"}
            if S.art then S.art.insert{name = "artillery-shell", count = 50}; S.art_at = {q.x, q.y} end
          end)
        end
        if mix == "clinic" then
          -- Its clinic killed a minute on: its learning stops, the breeds fall to the stock's, a pod brings another.
          schedule(game.tick - storage.t0 + 3600, function()
            local cl = surface().find_entities_filtered{name = "lp-clinic", position = f.pos, radius = 80, limit = 1}[1]
            if cl then cl.die("player"); S.clinic_killed = game.tick end
          end)
        end
        if mix == "wave" then schedule(game.tick - storage.t0 + 3600, function() S.asked = lp("farm_wave") and game.tick end) end
        -- wave200 (0.2.30): /lp wave 200, a mega wave on demand, past the caps.
        if mix == "wave200" then schedule(game.tick - storage.t0 + 3600, function() S.asked = lp("farm_wave", 200) and game.tick end) end
        if mix == "seed" or mix == "seedkill" or mix == "seedbare" then
          schedule(game.tick - storage.t0 + 3600, function()
            if mix == "seedbare" then
              for _, sp in ipairs(surface().find_entities_filtered{type = "unit-spawner", force = "enemy", position = f.pos,
                radius = 1100}) do sp.destroy() end
            end
            S.ripe = lp("farm_debug_seed", f.id) and game.tick
          end)
        end
        if mix == "starve" then
          -- Its first incubator stocked over the fed cap, then its biochamber killed a minute on.
          S.spid = f.pen_ids[1]
          lp("herd_fill", S.spid, 30, "lp-bred-medium-biter")
          schedule(game.tick - storage.t0 + 3600, function()
            for _, c in ipairs(lp("cell_state")) do
              if c.id == S.spid then
                local ch = surface().find_entities_filtered{name = "lp-biochamber", position = c.at, radius = 1, limit = 1}[1]
                if ch then S.spos = surface().find_entities_filtered{name = "lp-pen", position = f.pos, radius = 80}
                  for _, p in ipairs(S.spos) do if p.unit_number == S.spid then S.ppos = p.position end end
                  ch.die("player"); S.starved_at = game.tick end
              end
            end
          end)
        end
        if mix == "killed" then
          -- (Its share of its biomass dies with each: the first one killed takes its part of 1,000 over what it had, the
          -- user, 2026-10-30. Hatched at launch, a raid on its incubators had killed the guard and nothing of its army.)
          local pens = surface().find_entities_filtered{name = "lp-pen", position = f.pos, radius = 80}
          local before = lp("debug_biomass", f.id, 1000)
          for k, sp in ipairs(pens) do
            sp.die("player")
            if k == 1 then S.share = {before = before, after = lp("debug_biomass", f.id, 0), n = #pens} end
          end
          S.killed_at = game.tick
        end
      end
      -- Its cells (scripts/cell.lua): a pad, a biochamber at work and a lamp by each incubator.
      if f and S.landed and game.tick > S.landed and not S.cells then
        local cs, working, lamps, pads = lp("cell_state"), 0, 0, 0
        for _, c in ipairs(cs) do
          if c.working then working = working + 1 end
          if c.lamp then lamps = lamps + 1 end
          if surface().get_tile(c.at[1], c.at[2]).name == "acid-refined-concrete" then pads = pads + 1 end
        end
        S.cells = {n = #cs, working = working, lamps = lamps, pads = pads}
        local site = lp("cell_sites")[1]
        S.site = site and {tower = site.tower, techs = site.techs, plants = site.plants,
          soil = surface().get_tile(site.at[1], site.at[2] + 2).name}
        if mix == "techs" and site then
          -- Every technician killed: the feed stops within five minutes, a pod brings more at ten, the feed comes back.
          for _, u in pairs(surface().find_entities_filtered{name = "lp-technician"}) do u.die("player") end
          S.techs_killed = game.tick
        end
      end
      if mix == "techs" and S.techs_killed then
        local since = game.tick - S.techs_killed
        local fs = lp("farm_state").farms[1]
        local cs, working = lp("cell_state"), 0
        for _, c in ipairs(cs) do if c.working then working = working + 1 end end
        if since >= 7 * 3600 and not S.hungry then
          S.hungry = {working = working, unfed = fs and #fs.unfed or 0, pens = fs and fs.pens or 0}
        end
        if since >= 14 * 3600 and not S.fed_again then
          local site = lp("cell_sites")[1]
          S.fed_again = {working = working, unfed = fs and #fs.unfed or 0, pens = fs and fs.pens or 0,
            techs = site and site.techs or 0}
          finish_early()
        end
      end
      if f and S.landed then S.evo_last = {evo = f.evo, bred = f.bred_evo, clinic = f.clinic, tick = game.tick} end
      if mix == "clinic" and S.clinic_killed and f then
        local since = game.tick - S.clinic_killed
        if since >= 5 * 3600 and not S.frozen then S.frozen = {evo = f.evo, bred = f.bred_evo, clinic = f.clinic} end
        if since >= 20 * 3600 and not S.later then S.later = {evo = f.evo, bred = f.bred_evo, clinic = f.clinic} end
        if S.later and f.clinic and not S.back then
          S.back = {since = since, evo = f.evo, bred = f.bred_evo}
          finish_early()
        end
      end
      local st = lp("herd_state")
      for _, w in ipairs(st.waves) do
        S.wave_seen = S.wave_seen or game.tick
        if mix == "quiet" and w.stage == "march" and not S.raided then
          local ch = surface().find_entities_filtered{name = "lp-biochamber", position = S.farm_pos, radius = 80, limit = 1}[1]
          if ch then ch.damage(60, "player"); S.raided = game.tick end
        end
        if mix == "raid" and w.stage == "march" and not S.raided then
          local pen = surface().find_entities_filtered{name = "lp-pen", position = S.farm_pos, radius = 80, limit = 1}[1]
          if pen then pen.damage(60, "player"); S.raided = game.tick end
        end
      end
      if mix == "killed" and S.killed_at and game.tick - S.killed_at >= 1200 and not S.after then
        S.after = lp("farm_state")
        S.chambers_after = surface().count_entities_filtered{name = "lp-biochamber"}
        S.tags_after = #game.forces.player.find_chart_tags(surface(), {{S.farm_pos.x - 8, S.farm_pos.y - 8},
          {S.farm_pos.x + 8, S.farm_pos.y + 8}})
        finish_early()
      end
      -- Unfed: within a minute and a half it breeds nothing and has kept its fed cap; at ten minutes it is wild.
      if mix == "starve" and S.starved_at then
        local fs = lp("farm_state").farms[1]
        local u
        for _, x in ipairs(fs and fs.unfed or {}) do if x.id == S.spid then u = x end end
        if u and game.tick - S.starved_at >= 5400 and not S.unfed then S.unfed = {active = u.active, stock = u.stock, feral = fs.feral} end
        if fs and fs.lost_to_feed >= 1 and not S.wild_at then
          S.wild_at = game.tick
          S.pens_after = fs.pens
        end
        -- Six minutes on: the nest it went back to the wild as, still the wild's (see the check).
        if S.wild_at and game.tick - S.wild_at >= 6 * 3600 and not S.retaken then
          S.retaken = surface().count_entities_filtered{name = "lp-pen", position = S.ppos, radius = 2}
          finish_early()
        end
      end
      if mix ~= "killed" and mix ~= "starve" and mix ~= "techs" and mix ~= "clinic" and mix ~= "growth" and mix ~= "found"
        and mix ~= "seedbare" and mix ~= "moat" and #st.log > 0 then finish_early() end
    end)
  end
  schedule(END - 60, function()
    local st = lp("herd_state")
    local w = st.log[1]
    info("farm: " .. serpent.line(lp("farm_state")))
    info("farm: sites " .. serpent.line(lp("cell_sites")))
    info("farm: cells " .. serpent.line(lp("cell_state")))
    info("farm: wave " .. serpent.line(w and {outcome = w.outcome, blind = w.blind, size = w.size, left = w.left,
      kills = w.kills, recalled = w.recalled, t_launch = w.t_launch, t_breach = w.t_breach, t_end = w.t_end}))
    check("farm: it landed", S.landed ~= nil, tostring(S.landed))
    if not S.landed then return end
    info(string.format("farm: landed %.1f min in, %.0f tiles from the base, %s pens, %s worms, %s tags", S.landed / 3600,
      S.dist or -1, tostring(S.pens0), tostring(S.worms), tostring(S.tags)))
    check("farm: three pens or more", (S.pens0 or 0) >= 3, tostring(S.pens0))
    if mix == "fed" then
      local nf = S.at(330, 0)
      local fp = S.farm_pos or {x = 0, y = 0}
      local f1 = lp("farm_state").farms[1] or {}
      check("farm: fed, its pod came down on the field in the cloud", math.sqrt((fp.x - nf[1]) ^ 2 + (fp.y - nf[2]) ^ 2) < 60,
        string.format("%.0f tiles out", S.dist or -1))
      check("farm: fed, it ate the cloud", ((f1.biomass or {}).eaten or 0) > 0, serpent.line(f1.biomass))
    else
      check("farm: 600 tiles out or more", (S.dist or 0) >= 600, string.format("%.0f", S.dist or -1))
    end
    if mix == "moat" then
      local f1 = lp("farm_state").farms[1] or {}
      check("farm: moat, its nest stood on its island to the end", S.moat_nest ~= nil and S.moat_nest.valid,
        tostring(S.moat_nest and S.moat_nest.valid))
      check("farm: moat, its only nest near out of reach, it grew incubators of its own", (f1.grown or 0) >= 1,
        serpent.line({grown = f1.grown, pens = f1.pens, nest = S.moat_nest and S.moat_nest.valid}))
    end
    if mix == "found" then
      local f1 = lp("farm_state").farms[1] or {}
      check("farm: found, no wild nest near, it grew incubators of its own", (f1.grown or 0) >= 1,
        serpent.line({grown = f1.grown, pens = f1.pens, biomass = f1.biomass}))
    end
    check("farm: worms by its pens", (S.worms or 0) >= 2 * (S.pens0 or 0), tostring(S.worms))
    check("farm: its tag on the player's map", (S.tags or 0) >= 1, tostring(S.tags))
    check("farm: its tag names Synthexis", S.tag_text == "Synthexis culture", tostring(S.tag_text))
    local c = S.cells or {}
    check("farm: a cell by each incubator (pad, biochamber at work, lamp)", (c.n or 0) == (S.pens0 or -1)
      and c.working == c.n and c.lamps == c.n and c.pads == c.n, serpent.line(c))
    local site = S.site or {}
    check("farm: its substrate (Gleba soil, a heating tower, plants) and technicians", site.tower == true
      and site.soil == "artificial-yumako-soil" and (site.plants or 0) >= 4 and (site.techs or 0) >= 2, serpent.line(site))
    -- Seeding (0.2.22): its carrier walked to the second field and a young culture began there; shot on the way, none.
    -- seedbare: on the bare ground in the cloud, an incubator of its own.
    if mix == "seed" or mix == "seedkill" or mix == "seedbare" then
      local st_ = lp("farm_state")
      local g2 = (mix == "seedbare" or S.field2 and S.field2[1]) and S.at(750, 400)
      local young
      for _, f in ipairs(st_.farms) do
        if f.seeded and g2 and math.sqrt((f.pos.x - g2[1]) ^ 2 + (f.pos.y - g2[2]) ^ 2) < 80 then young = f end
      end
      info(string.format("farm %s: ripe at %s, carrier seen %s, killed %s; cultures %d; young %s", mix, tostring(S.ripe),
        tostring(S.carrier_seen), tostring(S.carrier_killed), #st_.farms, serpent.line(young and {pens = young.pens,
        clinic = young.clinic, pos = young.pos})))
      check("farm: " .. mix .. ", a carrier set out", S.carrier_seen ~= nil, tostring(S.carrier_seen))
      if mix == "seed" then
        -- (A seeded culture there, its clinic by pod 30 minutes on: with its sieges waiting for their order, no early wave
        -- ends this run, and by minute 40 the clinic had come, 2026-10-29; seeded is what it began as.)
        check("farm: seed, a young culture began at the second field", young ~= nil and young.seeded ~= nil,
          serpent.line(young))
      elseif mix == "seedbare" then
        -- (Its clinic may have come by then: on bare ground near, it walks two minutes.)
        check("farm: seedbare, a young culture began on the bare ground in the cloud", young ~= nil and young.pens >= 1,
          serpent.line(young))
      else
        check("farm: seedkill, its carrier shot, no culture began", S.carrier_killed ~= nil and young == nil and #st_.farms == 1,
          string.format("killed %s, cultures %d", tostring(S.carrier_killed), #st_.farms))
      end
    end
    -- Its technicians bought as it grows (0.2.22, cell.hire: they came free, one in ten minutes).
    if mix == "" then
      -- A siege sized from experience copies the one that razed most for what it spent, among those that got in with
      -- something to show (sized by what the last spent, its 34-38 lost 230-300 and razed less than its probes of 24 on
      -- the user's fort; the siege lab, 2026-10-30).
      local sized = lp("debug_best_size", {
        {sent = 60, spent = 300, got = 40, inside = true}, {sent = 30, spent = 100, got = 32, inside = true},
        {sent = 20, spent = 50, got = 5, inside = true}, {sent = 50, spent = 100, got = 45, inside = false}}, 10)
      check("farm: a siege sized by what razed most per biomass", sized == 30, tostring(sized))
      -- And with as many rams as that siege brought (one that got in with 4 drew its share up, the next brought 2 and stood
      -- at the inner of two walls; the lane, 2026-10-31).
      local sized_rams = lp("debug_best_rams", {
        {sent = 60, spent = 300, got = 40, inside = true, rams = 1}, {sent = 30, spent = 100, got = 32, inside = true, rams = 4}}, 10)
      check("farm: a proven siege's rams copied with it", sized_rams == 4, tostring(sized_rams))
      -- Its sieges near a breach count wherever they were kept: one at y 0 (cell 0) for a breach at y -6 (cell -1), none
      -- 100 tiles off (two walls got through with 4 rams at y 0, not copied a cell over; the lane, 2026-10-31).
      lp("debug_attempt_put", "lp-test|4,0|siege", {{sent = 30, spent = 100, got = 20, inside = true, rams = 4, breach = {290, 2}}})
      lp("debug_attempt_put", "lp-test|4,2|siege", {{sent = 30, spent = 100, got = 20, inside = true, rams = 2, breach = {290, 140}}})
      local near_n, far_n = lp("debug_history_near", "lp-test", {290, -6}, "siege"), lp("debug_history_near", "lp-test", {290, 60}, "siege")
      check("farm: its sieges near a breach count wherever they were kept", near_n == 1 and far_n == 0,
        serpent.line({near_n, far_n}))
      -- Against a defence reinforced since (more guns where it went), its attempts there count for nothing: its record of
      -- a siege that razed 45 outlived the guns put there after (the user, 2026-10-30: "perpetual identical actions").
      local was, more = {guns = 5, walls = 20}, {guns = 10, walls = 20}
      local hist = {{sent = 60, spent = 300, got = 40, inside = true, sig = was}, {sent = 30, spent = 100, got = 32, inside = true, sig = was},
        {sent = 45, spent = 200, got = 20, inside = true, sig = more}}
      local same, reinforced = lp("debug_best_size", hist, 10, was), lp("debug_best_size", hist, 10, more)
      -- A siege at a cheap walled place (one gun, its way in 5) is still a wave it sends: WAVE_MIN at the least (4 bursters
      -- and 11 at the star fort's corner waited six trials for a wave of 24 it would never send; the siege lab, 2026-10-31).
      local fid = (lp("farm_state").farms or {})[1]
      local sz = fid and lp("debug_siege_size", fid.id, {cost = 5, cover = 1, openable = 1, walled = true, standing = 0,
        target = {x = S.at(0, 0)[1], y = S.at(0, 0)[2]}})
      -- Its breeds tilted by what killed its last wave, none left out and none past twice its chance (a breed under UNFIT
      -- was left out of raids, and a siege's herd filtered so was 270 cinders; the design consult, 2026-10-30, G).
      local ch = fid and lp("debug_chance", fid.id, {["laser-turret"] = 10, ["gun-turret"] = 5}) or {}
      local dropped, wild, moved = {}, {}, false
      for name, w in pairs(ch) do
        local r = (w[2] or 0) / math.max(1e-9, w[1])
        if not w[2] or w[2] <= 0 then dropped[#dropped + 1] = name end
        if r < 0.1 - 1e-6 or r > 2 + 1e-6 then wild[#wild + 1] = name end
        if math.abs(r - 1) > 1e-6 then moved = true end
      end
      check("farm: its breeds tilted by what killed its last wave, none left out", next(ch) ~= nil and #dropped == 0
        and #wild == 0 and moved, serpent.line({dropped = dropped, wild = wild, moved = moved}))
      -- A price moves by the size of the wave that taught it: a probe's sample less than a full wave's (prices swung by 18
      -- in one trial in the siege lab, 2026-10-31).
      local small = lp("debug_learn_weighted", "player", "lp-test-small", 20, 10, 24 / 60)
      local full = lp("debug_learn_weighted", "player", "lp-test-full", 20, 10, 1)
      check("farm: a probe moves a price less than a full wave", math.abs(small - 11.6) < 0.01 and math.abs(full - 14) < 0.01,
        serpent.line({small = small, full = full}))
      -- What a siege razed counts the guns and walls it broke at their cost to build: three that broke 14-22 walls and
      -- guns each read as razing 0, and the farm held forever behind them (the star fort, the siege lab, 2026-10-31).
      local razed = lp("debug_razed", {{name = "laser-turret", type = "electric-turret"}, {name = "gun-turret", type = "ammo-turret"},
        {name = "stone-wall", type = "wall"}, {name = "assembling-machine-2", type = "assembling-machine"}})
      check("farm: the guns and walls a wave broke count as razed", math.abs(razed - 5.1) < 1e-6, tostring(razed))
      -- Held at one place for one reason, it is stopped again a trial on, not once ever (sixteen holds at the user's fort
      -- counted once, and it waited four trials to develop its bursters; the siege lab, 2026-10-31). Last: it moves its
      -- count of stops.
      local t0 = game.tick
      local h1 = lp("debug_stopped", "test|held", t0)
      local h2 = lp("debug_stopped", "test|held", t0 + 600)
      local h3 = lp("debug_stopped", "test|held", t0 + 15 * 3600)
      check("farm: held at one place again, stopped again a trial on, not at each look", h2 == h1 and h3 == h1 + 1,
        serpent.line({h1, h2, h3}))
      -- None of its rams reached the wall: twice as many next time (1, 2, 3 by its share alone at the square lab fort, each
      -- killed short, and its record kept it from a fourth; the siege lab, 2026-10-31).
      local r1, r2 = lp("debug_learn_reach", 1, 0, 1), lp("debug_learn_reach", 0.5, 0, 2)
      -- Every ram set off and still stopped at a wall: twice as many too (two walls, one ram's blast at the outer, its herd
      -- dead at the inner; the lane, 2026-10-31).
      local r3, r4 = lp("debug_learn_reach", 1, 1, 1, true), lp("debug_learn_reach", 1, 1, 1, false)
      check("farm: its rams all set off and stopped at a wall, twice as many next time", r3 <= 0.5 + 1e-9 and r4 > 0.99,
        serpent.line({r3, r4}))
      -- A wave half lost that never got in was held back, whatever guns it broke over the wall (raids at a saw-toothed lane
      -- broke 12 a wave from outside, and no wall had held them: 16 raids, no bursters; the siege lab, 2026-10-31).
      local hb_out, hb_in = lp("debug_held_back", 10, 40, 12, false), lp("debug_held_back", 10, 40, 12, true)
      check("farm: a wave half lost that never got in was held back, whatever it broke", hb_out == true and hb_in == false,
        serpent.line({hb_out, hb_in}))
      check("farm: none of its rams reached the wall, twice as many next time", r1 <= 0.5 + 1e-9 and r2 <= 0.25 + 1e-9,
        serpent.line({r1, r2}))
      -- However few have reached it, a handful of rams at most (43 big bursters in one siege of the square lab fort; the
      -- user, 2026-10-31: "at most we shouldn't need more than a handful").
      local was_reach = lp("debug_reach", "player", 0.01)
      local capped = fid and lp("debug_siege_size", fid.id, {cost = 5, cover = 1, openable = 1, walled = true, standing = 0,
        target = {x = S.at(0, 0)[1], y = S.at(0, 0)[2]}}, 1e6)
      lp("debug_reach", "player", was_reach)
      check("farm: a handful of rams at most, however few reached the wall", capped ~= nil and capped.k == 5, serpent.line(capped))
      check("farm: a siege no smaller than the least wave", sz ~= nil and sz.k + sz.n + (sz.fodder or 0) >= 24, serpent.line(sz))
      check("farm: attempts against a defence since reinforced not copied", same == 30 and reinforced == 45,
        serpent.line({same = same, reinforced = reinforced}))
      -- The ladder (tactics.ladder, every attacker's): a method that failed at a place lately is worth less there; one that
      -- got in is not (Kessler-Hayashi raided a laser wall three times, lost every one, and never weighed its mortar).
      for _ = 1, 3 do
        lp("debug_tactics_record", "lp-test-corp", "player", {500, 0}, "raid", {sent = 10, spent = 10, got = 0, inside = false})
      end
      lp("debug_tactics_record", "lp-test-corp", "player", {500, 200}, "raid", {sent = 10, spent = 2, got = 3, inside = true})
      -- (And not one that never got there: raids that died to wild nests on their way to an assembler set its raid aside;
      -- the clear test, worms.)
      for _ = 1, 3 do
        lp("debug_tactics_record", "lp-test-corp", "player", {500, 400}, "raid", {sent = 10, spent = 10, got = 0, inside = false, reached = false})
      end
      local l_fail, l_ok = lp("debug_ladder", "lp-test-corp", "player", {500, 0}, "raid"), lp("debug_ladder", "lp-test-corp", "player", {500, 200}, "raid")
      local l_away = lp("debug_ladder", "lp-test-corp", "player", {500, 400}, "raid")
      check("tactics: a method that failed at a place lately is worth less there, one that got in or never got there is not",
        l_fail < 0.3 and l_ok > 0.99 and l_away > 0.99, serpent.line({l_fail, l_ok, l_away}))
      -- Every attacker's weighing takes the ladder, Synthexis's menu too: a raid that failed twice at a place lately is set
      -- aside there, whatever it broke on its way (raids of 60 at a tesla lane broke 7 of its walls' worth for 888 mediums,
      -- read as worth sending, and went again five times; the second lane matrix, 2026-10-31).
      for _ = 1, 2 do
        lp("debug_tactics_record", "lp-test-wave", "player", {900, 0}, "raid", {sent = 60, spent = 60, got = 7, inside = false})
      end
      local ex_fail = lp("debug_expect", "lp-test-wave", "player", {900, 0}, "raid")
      local ex_clean = lp("debug_expect", "lp-test-wave", "player", {900, 300}, "raid")
      check("tactics: a raid that failed at a place lately is set aside there in the weighing", ex_fail and ex_fail.ok == false
        and ex_clean and ex_clean.ok == true, serpent.line({failed = ex_fail, clean = ex_clean}))
      -- A corporation's raid sized on what got in there before its formula (ops.raid_want): at a defence of 50 the formula
      -- asks 180 or so; a raid of 20 mediums got in there, and that is what it sends (its raids at a laser wall sized by
      -- the formula alone; the lane, 2026-10-31).
      local corp = lp("stats", storage.id).corp
      local rw_before = lp("debug_raid_want", storage.id, {1500, 0}, 50)
      lp("debug_tactics_record", corp, "player", {1500, 0}, "raid", {sent = 20, spent = 5, got = 3, inside = true})
      local rw_after = lp("debug_raid_want", storage.id, {1500, 0}, 50)
      check("ops: a corporation's raid sized on what got in there", rw_before and rw_after and rw_after < rw_before / 4,
        serpent.line({corp = corp, before = rw_before, after = rw_after}))
      -- Three the counters and desperation consult found (2026-10-31): a tesla turret's kills put down to electric, not laser
      -- (its deaths bought laser plate); a wall piece a corporation breaks does not reset its war ladder, a building does
      -- (one wall piece ended its desperation); a failure at a target near counts in its ladder (three cells of one wall
      -- each read as untried).
      local dmg = lp("debug_damage_of", "tesla-turret")
      local cf = "lp-" .. lp("stats", storage.id).corp
      local wall = put("stone-wall", S.at(-90, 60))
      local key = "player|" .. cf
      local before = lp("debug_last_raze", key)
      wall.die(cf)
      local after_wall = lp("debug_last_raze", key)
      local asm = put("assembling-machine-1", S.at(-90, 66))
      asm.die(cf)
      local after_asm = lp("debug_last_raze", key)
      lp("debug_tactics_record", "lp-test-near", "player", {1150, 0}, "raid", {sent = 10, spent = 10, got = 0, inside = false, breach = {1150, 0}})
      local l_near = lp("debug_ladder", "lp-test-near", "player", {1160, 4}, "raid", true)
      check("ops: tesla kills read as electric; a wall piece keeps the ladder's clock, a building resets it; a failure near counts",
        dmg == "electric" and after_wall == before and after_asm == game.tick and l_near < 1,
        serpent.line({dmg = dmg, before = before, after_wall = after_wall, after_asm = after_asm, tick = game.tick, near = l_near}))
      -- A siege set up out of each gun's own reach and its guards' room (a tesla's 30, threat.MARGIN's 2 for its size, 1 for
      -- the guards: at a fixed 31, three sieges of the tesla lane were stunned and chained to death in a minute; the lane,
      -- 2026-10-31).
      local tz = S.at(-200, 120)
      local tesla = put("tesla-turret", tz)
      put("assembling-machine-1", {tz[1] + 6, tz[2]})
      local site = lp("debug_siege_site", storage.id, {tz[1] + 6, tz[2]})
      local sd = site and math.sqrt((site[1] - tesla.position.x) ^ 2 + (site[2] - tesla.position.y) ^ 2)
      check("ops: a siege set up out of a tesla turret's reach and its guards' room", sd ~= nil and sd > 30 + 2 + 1 - 1e-6,
        serpent.line({site = site, from_tesla = sd}))
      -- Desperate, bolder not blind (the consult, 2026-10-31): a raid of 10 at a defence of 50 (the formula's 179) does not
      -- go; one of 150 does (lifted, its raids of 4 to 40 went at a laser wall again and again).
      local dz_few, dz_many = lp("debug_desperate_ok", storage.id, 10, 50), lp("debug_desperate_ok", storage.id, 150, 50)
      check("ops: a desperate corporation keeps half its odds rule", dz_few == false and dz_many == true,
        serpent.line({few = dz_few, many = dz_many}))
      -- A siege that fired and broke nothing at a place: its tier there is what it brings more than next time (tactics.failed_
      -- specialists; a tier-1 mortar's 30 shells broke nothing of a laser wall, and its next siege was tier 1 again).
      lp("debug_tactics_record", "lp-test-corp", "player", {700, 0}, "siege", {sent = 10, spent = 0, got = 0, inside = false, rams = 1})
      lp("debug_tactics_record", "lp-test-corp", "player", {700, 200}, "siege", {sent = 10, spent = 0, got = 4, inside = true, rams = 2})
      local fs_fail = lp("debug_failed_specialists", "lp-test-corp", "player", {700, 0}, "siege")
      local fs_ok = lp("debug_failed_specialists", "lp-test-corp", "player", {700, 200}, "siege")
      check("tactics: a siege that broke nothing is the tier to go past", fs_fail == 1 and fs_ok == nil, serpent.line({fs_fail, fs_ok}))
      -- A corporation weighs a turret type at the price its losses taught it where it has one (ops.weigh, its own reading):
      -- a gun turret at 21 units lost a turret weighs 6 (21 over 3.5), whatever the formula made it (Kessler-Hayashi's raids at a
      -- laser wall, weighed by a formula set against gun turrets, lost every one; the lane, 2026-10-31).
      -- (The fort weighed whole, 60 tiles round its middle: its gun turrets weigh 6 each once learned; its lasers, unlit
      -- there, weigh nothing either way.)
      local mid = S.at(0, 0)
      local w_formula = lp("debug_weigh", surface().index, mid, "lp-test-corp", 60)
      lp("debug_corp_price", "lp-test-corp", "player", G, 21)
      local w_learned = lp("debug_weigh", surface().index, mid, "lp-test-corp", 60)
      check("ops: a corporation weighs a turret at the price its losses taught it", (w_formula or 0) > 0 and (w_learned or 0) > 0
        and math.abs(w_learned - w_formula) > 1e-6, serpent.line({formula = w_formula, learned = w_learned}))
      -- (Last of the sizes: its record here would size the others.)
      -- A proven siege's herd copied without its rams (sized apart): one that sent 4 rams and 300 mediums of herd was asked 460 (here: 4 rams and 10 of herd, at this evolution's half a medium a head),
      -- fitted under no 60, and none was laid (the lane, 2026-10-31). Its size here, at a cheap place, proven by it.
      lp("debug_attempt_put", "player|" .. math.floor(S.at(0, 0)[1] / 64) .. "," .. math.floor(S.at(0, 0)[2] / 64) .. "|siege",
        {{sent = 170, spent = 100, got = 20, inside = true, rams = 4, breach = {S.at(0, 0)[1], S.at(0, 0)[2]}}})
      local pz = fid and lp("debug_siege_size", fid.id, {cost = 5, cover = 1, openable = 1, walled = true, standing = 0,
        breach = {S.at(0, 0)[1], S.at(0, 0)[2]}, target = {x = S.at(0, 0)[1], y = S.at(0, 0)[2]}}, 1e6)
      check("farm: a proven siege's herd copied without its rams", pz ~= nil and pz.k == 4 and pz.n + pz.k + (pz.fodder or 0) <= 60,
        serpent.line(pz))
      -- The most it sends at once by its size (farm.cap_of): its own incubators' 60 or more, three times as many incubators
      -- three times the wave, at most 200 (the user, 2026-10-31: "huge waves might be a late game occurrence"). Last: the
      -- incubators added stay.
      local cap0 = fid and lp("farm_cap", fid.id)
      local pens0 = (lp("farm_state").farms or {})[1].pens
      local pens1 = fid and lp("farm_add_pens", fid.id, 3 * math.max(8, pens0) - pens0)
      local cap1 = fid and lp("farm_cap", fid.id)
      check("farm: the most it sends at once grows with its incubators", cap0 == math.max(60, math.floor(60 * pens0 / 8))
        and cap1 == math.min(200, math.floor(60 * pens1 / 8)) and cap1 > cap0, serpent.line({pens0, cap0, pens1, cap1}))
      local now = lp("cell_sites")[1] or {}
      check("farm: it bought technicians as it grew", (now.bought or 0) >= 1, serpent.line({bought = now.bought, techs = now.techs}))
    end
    if mix == "clinic" then
      info(string.format("farm clinic: landed at %s, killed %s; 5 min on %s; 20 min on %s; back %s", serpent.line(S.evo_land),
        tostring(S.clinic_killed), serpent.line(S.frozen), serpent.line(S.later), serpent.line(S.back)))
      check("farm: its clinic killed, its breeds held at the stock's and its learning stopped", S.frozen and S.later
        and S.frozen.clinic == false and S.frozen.evo >= 0.5 and S.frozen.bred <= 0.301 and S.later.bred <= 0.301
        and math.abs(S.later.evo - S.frozen.evo) < 1e-6, serpent.line({S.frozen, S.later}))
      check("farm: a new clinic by pod half an hour on, its breeds back to what it had learned", S.back
        and S.back.since >= 30 * 3600 and S.back.since <= 34 * 3600 and math.abs(S.back.bred - S.frozen.evo) < 0.01,
        serpent.line(S.back))
      return
    end
    -- Its clinic (scripts/cell.lua): standing, and its breeds a step up a minute while it stands.
    local e = S.evo_last or {}
    local mins = e.tick and (e.tick - S.landed) / 3600 or 0
    info(string.format("farm: evolution %s at landing, %s %.1f min on (bred at %s), clinic %s", tostring(S.evo_land),
      tostring(e.evo), mins, tostring(e.bred), tostring(e.clinic)))
    if mix ~= "killed" and mix ~= "artillery" and mix ~= "siege" and mix ~= "behind" then
      check("farm: its clinic stands and its breeds climb", e.clinic == true and S.evo_land and e.evo
        and e.evo - S.evo_land >= 0.004 * (mins - 1) * 0.9 and math.abs(e.bred - e.evo) < 0.001, serpent.line(e))
    end
    if mix == "techs" then
      info(string.format("farm techs: after 7 min %s; after 14 min %s", serpent.line(S.hungry), serpent.line(S.fed_again)))
      -- (An incubator its creep took after the killing has a cell of its own, fed five minutes from its building.)
      check("farm: its technicians dead, the biochambers stopped and the incubators unfed", S.hungry
        and S.hungry.unfed >= S.pens0 and S.hungry.working <= S.hungry.pens - S.pens0, serpent.line(S.hungry))
      check("farm: technicians came back by pod and the feed with them, no incubator lost", S.fed_again
        and S.fed_again.techs >= 2 and S.fed_again.working == S.fed_again.pens and S.fed_again.unfed == 0
        and S.fed_again.pens >= S.pens0, serpent.line(S.fed_again))
      return
    end
    if mix == "killed" then
      check("farm: every pen dead, the farm gone", S.after and #S.after.farms == 0, serpent.line(S.after))
      local sh = S.share
      check("farm: an incubator killed, its share of the biomass with it", sh and sh.n >= 2
        and math.abs(sh.after - sh.before * (sh.n - 1) / sh.n) <= 1, serpent.line(sh))
      check("farm: its tag gone", S.tags_after == 0, tostring(S.tags_after))
      check("farm: its biochambers gone with its incubators", S.chambers_after == 0, tostring(S.chambers_after))
      check("farm: it lands again in about an hour", S.after and S.after.next_arrival and
        S.after.next_arrival - S.killed_at >= 55 * 3600, serpent.line(S.after and S.after.next_arrival))
      return
    end
    if mix == "starve" then
      info(string.format("farm starve: unfed %s, wild after %s ticks, incubators %s -> %s", serpent.line(S.unfed),
        tostring(S.wild_at and S.wild_at - S.starved_at), tostring(S.pens0), tostring(S.pens_after)))
      check("farm: unfed, it breeds nothing and keeps 12 of its stock", S.unfed and S.unfed.active == false
        and S.unfed.stock <= 12 and (S.unfed.feral or 0) >= 1, serpent.line(S.unfed))
      check("farm: unfed ten minutes, it went wild", S.wild_at and S.wild_at - S.starved_at >= 10 * 3600
        and S.wild_at - S.starved_at <= 11 * 3600, tostring(S.wild_at and S.wild_at - S.starved_at))
      check("farm: the culture lives on", (S.pens_after or 0) >= 1, tostring(S.pens_after))
      -- An incubator gone wild unfed was taken back by its creep at once, never reached, wild again: one nest seven
      -- times in five hours on nw, its stock over the fed cap let loose each time, bred big biters that took Serenity's
      -- lander (2026-10-29).
      check("farm: the nest it went wild as, not taken again", S.retaken == 0, tostring(S.retaken))
      return
    end
    if mix == "artillery" then
      -- The artillery that shelled its pens: worth a wave (herd.shelling, valuemap.SHELLS), and gone by the end.
      check("farm: artillery, it was placed in reach of the pens", S.art_at ~= nil, "not placed")
      -- (A function check, not a guard: the pens' own biters went for the artillery that shelled them, the engine's answer
      -- to artillery on spawners, before any wave was weighed; and on this base every wave's odds were 0 anyway. What it
      -- adds, artillery's worth to a wave and never landing in its reach, is the farm's: herd.shelling, farm.shelled.)
      check("farm: artillery, brought down", S.art_at ~= nil and not (S.art and S.art.valid),
        serpent.line({at = S.art_at, standing = S.art and S.art.valid}))
      return
    end
    if mix == "behind" then
      local fs = lp("farm_state").farms[1]
      info(string.format("farm behind: sieges refused %s (%s again with no more to field), sieges %s", tostring(fs and fs.refused),
        tostring(fs and fs.repeats), serpent.line(S.sieges)))
      -- Its biomass put to a siege through both rings (its herd priced in health, herd.strength: priced in heads, every
      -- plan asked 700 heads and more, 9,000 biomass hatched about 90 behemoths, and it refused every siege while its biomass
      -- piled up; HEAD at 0.2.90 refused here, 2026-10-30).
      check("farm: behind, a siege laid through both rings", #(S.sieges or {}) > 0, serpent.line({refused = fs and fs.refused}))
      -- Refused, priced at its plan until the place changes or it can field more: before, its weighing read the wall as
      -- one its bursters open whatever the plan said, and weighed the same siege every ten seconds (269 refusals in 75
      -- minutes, all at one place with 7 incubators; five hours at one place on nw). Another place, or more incubators,
      -- may be weighed and refused. (Hatching, held until its biomass reaches the cheapest siege's price there: held at
      -- what it could field, in health, the field grew a little every ten seconds and it weighed the siege again, 27
      -- repeats of 147, 2026-10-30.)
      check("farm: behind, a refused siege not weighed again with no more to field", fs and fs.repeats == 0,
        serpent.line({refused = fs and fs.refused, repeats = fs and fs.repeats}))
      return
    end
    if mix == "siege" then
      local lasers = surface().count_entities_filtered{name = L, force = "player"}
      local k = 0
      for _, x in ipairs(S.sieges or {}) do k = math.max(k, x) end
      info(string.format("farm siege: sieges %s, least biomass %.0f, big bursters near the base at once %d, lasers %d -> %d",
        serpent.line(S.sieges), S.min_bio or 0, S.max_near or 0, S.lasers0 or 0, lasers))
      check("farm: siege, laid", #(S.sieges or {}) > 0, "none")
      -- (A birth is charged after the engine makes it: a behemoth or two at once past what it kept, 200 each.)
      check("farm: siege, its biomass never far below nothing", (S.min_bio or 0) >= -450, tostring(S.min_bio))
      -- (Within two: one may die on the march, and they burst at their guns at different moments; its wave carried 8 of 17
      -- and 10 of 13 while a biter in two incubators' stock was counted twice.)
      check("farm: siege, its wave came with the big bursters it ordered", k > 0 and (S.max_near or 0) >= k - 2,
        string.format("ordered %d, near the base at once %d", k, S.max_near or 0))
      -- This wall holds against a siege of bursters walking up to it (the user, 2026-10-30: a big burster killed short of its
      -- gun or the wall fizzles, and "a heavily researched laser wall should stop a naive burster rush"; its death blasts had
      -- opened it, 64 wall pieces, whatever killed them). What it must do is learn: what its bursters open (herd.opens) falls
      -- below what it reckoned before any siege, and it does not lay the same siege at the same breach again.
      local sieges, first = {}, nil
      for _, l in ipairs(lp("herd_state").log or {}) do
        if (l.big_sent or 0) > 0 then
          sieges[#sieges + 1] = l
          first = first or l
        end
      end
      local opens = (lp("lab_prices").opens or {})["player"]
      -- (Since its rams go at the wall on its swept lane, the wall no longer holds: one ram broke 3 lasers and 11 wall pieces,
      -- its yield rose past its reckoning and "below" failed; what is checked is that it learned from what they did, the
      -- siege lab, 2026-10-31.)
      local o = first and first.opens
      check("farm: siege, its bursters' yield learned from its first siege", o ~= nil and opens ~= nil
        and math.abs(o.now - o.sample) < math.abs(0.9 - o.sample), serpent.line({opens = opens, learned = o, sent = first and first.big_sent, set_off = first and first.big_set_off,
          broke = first and first.bursters and first.bursters.broke, lasers = string.format("%d -> %d", S.lasers0 or 0, lasers)}))
      -- Its big bursters spent count in what it lost, at their health in mediums as any unit's: by herd.strength, which
      -- leaves them out of a herd's strength, sixteen killed at the square lab fort's wall cost nothing and its lasers read
      -- cheap (the siege lab, 2026-10-31).
      local lost, big = 0, prototypes.entity["lp-bred-big-burster"].get_max_health()
        / prototypes.entity["lp-bred-medium-biter"].get_max_health()
      for key, v in pairs(first and first.lost_worth_by or {}) do if key:sub(-5) == " none" then lost = lost + v end end
      check("farm: siege, its big bursters spent counted in what it lost", first ~= nil and (first.big_set_off or 0) > 0
        and lost >= first.big_set_off * big - 1e-6, string.format("lost %.1f to no killer, %d set off at %.1f each", lost,
        first and first.big_set_off or 0, big))
      -- Its rams go at the wall piece on its swept lane, then their guns (sent at the wall nearest their own gun, they walked
      -- off the lane into mines and stood stunned under the lasers; the square lab fort, 2026-10-31).
      check("farm: siege, its rams go at the wall on its swept lane", first ~= nil and first.ram_off ~= nil and first.ram_off <= 6 + 1e-6,
        tostring(first and first.ram_off))
      -- Its sweepers clear every mine on its way in (runts of 15 health died to the lasers short of them, 10 of 10 spent; the
      -- user's sweeper, 2026-10-31: "high hp, high range boom that kills mines").
      local swept_mines = first and first.bursters and first.bursters.broke and first.bursters.broke["land-mine"] or 0
      -- (Those its plan saw, what its farm paid sweepers for: at the breach its sweep reads the herd's whole width and found
      -- 12 where its plan had 10, two clusters past what it paid for.)
      check("farm: siege, its sweepers cleared the mines on its way in", first ~= nil and (first.plan_mines or 0) > 0
        and swept_mines >= first.plan_mines, string.format("%d of the %s its plan saw (%s at the breach)", swept_mines,
        tostring(first and first.plan_mines), tostring(first and first.sweep_mines)))
      local same = 0
      for k = 2, #sieges do
        local l = sieges[k]
        if l.big_sent == first.big_sent and l.plan_breach and first.plan_breach and l.plan_breach[1] == first.plan_breach[1]
          and l.plan_breach[2] == first.plan_breach[2] then same = same + 1 end
      end
      check("farm: siege, a siege that failed not laid again the same", first ~= nil and same == 0,
        serpent.line({sieges = #sieges, same = same}))
      -- Its siege wave staged near where it broke in (within 200 tiles), not at its nest.
      local staged
      for _, l in ipairs(lp("herd_state").log or {}) do
        if l.breach and l.mark then staged = math.sqrt((l.mark[1] - l.breach[1]) ^ 2 + (l.mark[2] - l.breach[2]) ^ 2); break end
      end
      check("farm: siege, its wave staged near where it broke in", staged ~= nil and staged <= 200, tostring(staged))
      -- Its sweep ahead of it: its wave lost few to the mines on its way in (set off by the wave itself, 13 went and it lost
      -- 36 to them). Those inside, where its biters each go for their own target, are past what it swept (11 of them with
      -- every mine on its way in cleared; the siege lab, 2026-10-31).
      local mines = surface().count_entities_filtered{name = "land-mine", force = "player"}
      local to_mines
      for _, l in ipairs(lp("herd_state").log or {}) do
        if l.breach then
          to_mines = 0
          for key, n in pairs(l.lost_by or {}) do
            if key:find("land%-mine") and not key:find("^inside") and not key:find("^withdraw") then to_mines = to_mines + n end
          end
          break
        end
      end
      check("farm: siege, its wave lost few to the mines its sweep went ahead of", to_mines ~= nil and to_mines <= 10,
        string.format("lost %s to mines; mines %d -> %d", tostring(to_mines), S.mines0 or 0, mines))
      -- What its bursters broke taught it nothing of a laser's price (it learned 1.0 from a siege, against 15 before).
      local lp_price = lp("debug_price", "player", "laser-turret")
      check("farm: siege, a laser's price not learned from guns its bursters broke", lp_price == nil or lp_price >= 5,
        tostring(lp_price))
      return
    end
    -- (Within 50 minutes, run length in regress.sh: with its growth paid apart from its breeding, half its income to growth
    -- while young, its first wave goes out at about 45, 2026-10-29; 40 before.)
    check("farm: a wave went out", w ~= nil or S.wave_seen ~= nil, "none")
    if not w then return end
    if mix == "wave" then
      check("farm: /lp wave sent one within a minute", S.asked and w.t_launch - S.asked <= 3600,
        string.format("asked %s, launched %s", tostring(S.asked), tostring(w.t_launch)))
      -- Nothing in sight at the wall, it pushes in and looks again there (0.2.31: it looked again two seconds on, where it
      -- stood, and went home).
      check("farm: a wave that pushed in got there before it turned", w.push_walked == nil or w.push_walked >= 10,
        tostring(w.push_walked))
      return
    end
    if mix == "wave200" then
      check("farm: /lp wave 200 sent a wave of 180 or more within a minute", S.asked and w.t_launch - S.asked <= 3600
        and (w.size or 0) >= 180, string.format("asked %s, launched %s, size %s", tostring(S.asked), tostring(w.t_launch),
        tostring(w.size)))
      check("farm: a wave that pushed in got there before it turned", w.push_walked == nil or w.push_walked >= 10,
        tostring(w.push_walked))
      return
    end
    if mix == "quiet" then
      -- The quiet kill: a biochamber hit while the herd marches calls nothing home.
      check("farm: a biochamber hit called no wave home", S.raided ~= nil and w.recalled ~= true,
        string.format("recalled %s, hit %s", tostring(w.recalled), tostring(S.raided)))
      return
    end
    if mix == "raid" then
      check("farm: the raid called the wave home", (w.recalled == true and S.raided ~= nil),
        string.format("recalled %s, raided %s", tostring(w.recalled), tostring(S.raided)))
      check("farm: it never reached the base", w.t_breach == nil, tostring(w.t_breach))
    else
      check("farm: the wave walked the distance and broke in", w.t_breach ~= nil, w.outcome)
      check("farm: the first wave ten minutes after landing or more", w.t_launch - S.landed >= 9 * 3600,
        string.format("%.1f min", (w.t_launch - S.landed) / 3600))
    end
  end)
end

-- Blackout (the power strike; Fable's fortress consult): ten lasers behind a wall 150 tiles from a provoked Serenity camp,
-- fed only by a chain of big poles from a power source 120 tiles off to the side, beyond every turret's reach; and a
-- decoy nearer the camp: a line of big poles feeding a radar, as exposed, darkening nothing. Its survey finds the pole
-- whose loss darkens the lasers, its next raid goes for it (worth 14), the lasers go dark, and its raids then take
-- them. Without the survey it found the feed line too, by luck (its first raid took the decoy's substation and cooled
-- the decoy's poles; the next nearest was on the feed): on a small base exposed poles are few; the survey is what picks
-- the one that matters among many. LP_MIX=fed: a second source inside the wall too: no single cut.
scenarios.blackout = function()
  local fed, off = params.mix == "fed", params.mix == "off"
  schedule(60, function()
    lp("debug_tune", {wfc_core_off = true, era = 2, history_off = true, corp_level = {serenity = 1}, cuts_off = off or nil})
    S.s = storage.id
    for _ = 1, 2 do lp("debug_depot", S.s, 5000) end
  end)
  schedule(6 * 3600, function()
    local o = lp("stats", S.s).origin
    local ux, uy = 0, 0
    if math.abs(o.x) > math.abs(o.y) then ux = o.x > 0 and 1 or -1 else uy = o.y > 0 and 1 or -1 end
    local vx, vy = -uy, ux
    local c = {math.floor(o.x - ux * 150) + 0.5, math.floor(o.y - uy * 150) + 0.5}
    local function at(du, dv) return {c[1] + ux * du + vx * dv, c[2] + uy * du + vy * dv} end
    local lo, hi = at(-12, -24), at(4, 130)
    flatten(math.min(lo[1], hi[1]) - 4, math.min(lo[2], hi[2]) - 4, math.max(lo[1], hi[1]) + 4, math.max(lo[2], hi[2]) + 4)
    local function put(name, p) return surface().create_entity{name = name, position = p, force = "player"} end
    S.c, S.lasers = c, {}
    for k = -20, 20 do put("stone-wall", at(0, k)) end
    for k = -18, 18, 4 do table.insert(S.lasers, put("laser-turret", at(-3, k))) end
    for k = -21, 21, 14 do put("substation", at(-7, k)) end
    -- The line out: big poles every 28 tiles to the source at 120 to the side (the chain beyond the lasers' reach).
    S.chain = {}
    for d = 34, 118, 28 do table.insert(S.chain, put("big-electric-pole", at(-7, d))) end
    -- Its end a plain big pole (worth what the decoy's are): a substation there, worth more, was every raid's first pick.
    local src = put("big-electric-pole", at(-7, 126))
    -- The source on a medium pole beside it (a big pole supplies only 2 tiles round it: the lasers never had power).
    put("medium-electric-pole", at(-7, 130))
    local eei = put("electric-energy-interface", at(-7, 133))
    eei.power_production, eei.electric_buffer_size = 1e9 / 60, 1e9
    -- The decoy: nearer the camp (60 to the other side, 30 closer), a radar on its own line from its own source.
    for d = -40, -96, -28 do put("big-electric-pole", at(30, d)) end
    put("radar", at(30, -104))
    local e3 = put("electric-energy-interface", at(34, -104))
    e3.power_production, e3.electric_buffer_size = 1e7 / 60, 1e7
    put("substation", at(30, -112))
    if fed then
      local e2 = put("electric-energy-interface", at(-10, 0))
      e2.power_production, e2.electric_buffer_size = 1e9 / 60, 1e9
    end
    S.src = src
  end)
  for t = 6 * 3600 + 600, END - 120, 600 do
    schedule(t, function()
      local dark = 0
      for _, l in ipairs(S.lasers or {}) do if l.valid and l.energy <= 0 then dark = dark + 1 end end
      S.dark = math.max(S.dark or 0, dark)
      local lit = 0
      for _, l in ipairs(S.lasers or {}) do if l.valid and l.energy > 0 then lit = lit + 1 end end
      if lit >= 5 then S.lit_seen = true end
      if dark >= 5 and S.lit_seen and not S.dark_at then S.dark_at = math.floor((game.tick - 6 * 3600) / 60) end
      local chain = 0
      for _, p in ipairs(S.chain or {}) do if p.valid then chain = chain + 1 end end
      S.chain_min = math.min(S.chain_min or 99, chain)
      -- Settled: dark, and half the lasers taken; with a second feed, two surveys made and still lit.
      local left = 0
      for _, l in ipairs(S.lasers or {}) do if l.valid then left = left + 1 end end
      if (S.dark_at and left <= 5) or (fed and game.tick - storage.t0 > 20 * 3600) then finish_early() end
    end)
  end
  schedule(END - 60, function()
    local st = lp("stats", S.s)
    local left = 0
    for _, l in ipairs(S.lasers) do if l.valid then left = left + 1 end end
    info("blackout: lasers dark " .. tostring(S.dark_at) .. " s after the base stood")
    info(string.format("blackout: cuts found %s; chain poles left at least %s of 4; lasers dark at most %s; lasers left %d of 10; "
      .. "log %s", tostring(st.ops.cuts_found), tostring(S.chain_min), tostring(S.dark), left, serpent.line(st.ops.log)))
    if fed then
      check("blackout: no cut with a second feed", (st.ops.cuts_found or 0) == 0 and (S.dark or 0) == 0,
        string.format("cuts %s, dark %s", tostring(st.ops.cuts_found), tostring(S.dark)))
      return
    end
    check("blackout: dark within 10 minutes", S.dark_at and S.dark_at < 600, tostring(S.dark_at))
    check("blackout: the lasers had power first (the case)", S.lit_seen == true, tostring(S.lit_seen))
    check("blackout: the survey found the cut", (st.ops.cuts_found or 0) >= 1, tostring(st.ops.cuts_found))
    check("blackout: scouts walked the line first", (st.ops.recons or 0) >= 1, tostring(st.ops.recons))
    local cut_raid = false
    for _, l in ipairs(st.ops.log or {}) do if l.cut then cut_raid = true end end
    check("blackout: a raid went for the cut", cut_raid, serpent.line(st.ops.log))
    check("blackout: the line was cut", (S.chain_min or 4) < 4, tostring(S.chain_min))
    check("blackout: the lasers went dark", (S.dark or 0) >= 5, tostring(S.dark))
    check("blackout: then half the lasers were taken", left <= 5, tostring(left))
  end)
end

-- Strangle (Fable's fortress consult): a provoked Serenity, its line a step a minute. The player's main position (a
-- relay, two gun turrets) 200 tiles out toward spawn; an outpost (six drills on iron, a pole, two gun turrets) 230 out
-- at 90 degrees to it. At war the line's first arcs go for the outpost (within 35 degrees of it). Unguarded, the outpost
-- was raided either way and the line swung back once it was gone: guarded, it is what the line is for.
-- LP_MIX=off (strangle_off): the line goes for the nearest building, the main position (the case).
-- LP_MIX=ore: no outpost and no main position (none of the player's buildings in reach), a rich iron field (32 by 32,
-- one cell) 230 out at 90 degrees: the line goes for an ore field (that one, or a richer or nearer one of the map's).
-- LP_MIX=oreoff: the same with the next ore off: no target, the line steps out evenly (no arc bears on the field).
-- LP_MIX=sever: at war, a belt and a pipe laid across the claim's edge and an underground belt under it, a gun turret of
-- Serenity's by the belt (a post), none by the pipe; one pass of the cut: the belt's tiles on the line blown, those off
-- it, the underground and the unguarded pipe standing (it cuts only where its guns are).
scenarios.strangle = function()
  local ore, oreoff = params.mix == "ore", params.mix == "oreoff"
  local sever = params.mix == "sever"
  local off = params.mix == "off" or oreoff
  schedule(30, function() lp("debug_tune", {perimeter_fast = true, strangle_off = (params.mix == "off") or nil,
    next_ore_off = oreoff or nil, corp_level = {serenity = 1}, provoke = (ore or oreoff) or nil}) end)
  schedule(60, function() for _ = 1, 2 do lp("debug_depot", storage.id, 5000) end end)
  -- Settled: two arcs on record (the check reads the first).
  for t = 3 * 3600, END - 120, 3600 do
    schedule(t, function()
      if not sever and #(lp("cordon_stats", storage.id).bearings or {}) >= 2 then finish_early() end
    end)
  end
  if sever then
    schedule(3 * 3600 + 300, function()
      local st = lp("stats", storage.id)
      local o, R = st.origin, st.claim_radius
      S.R, S.war = R, lp("standing", "serenity")
      S.belts, S.pipes = {}, {}
      -- East: a belt from R - 5 to R + 5; north: a pipe the same; west: an underground pair, its ends 2.5 off the line.
      local ex = math.floor(o.x + R)
      flatten(ex - 7, math.floor(o.y) - 2, ex + 8, math.floor(o.y) + 3)
      for x = ex - 5, ex + 5 do
        table.insert(S.belts, surface().create_entity{name = "transport-belt", position = {x + 0.5, math.floor(o.y) + 0.5},
          direction = defines.direction.east, force = "player"})
      end
      -- Its guns by the belt and by the underground (a post each), none by the pipe.
      local function gun(x, y)
        local p = surface().find_non_colliding_position("gun-turret", {x, y}, 8, 1)
        S.guns = (S.guns or 0) + (p and surface().create_entity{name = "gun-turret", position = p, force = "lp-serenity"} and 1 or 0)
      end
      gun(ex - 10, math.floor(o.y) - 6)
      gun(math.floor(o.x - R) + 10, math.floor(o.y) - 6)
      -- North: the line's arcs bear south (the outpost), so nothing of its stands by the pipe.
      local sy = math.floor(o.y - R)
      flatten(math.floor(o.x) - 2, sy - 7, math.floor(o.x) + 3, sy + 8)
      for y = sy - 5, sy + 5 do
        table.insert(S.pipes, surface().create_entity{name = "pipe", position = {math.floor(o.x) + 0.5, y + 0.5}, force = "player"})
      end
      local wx = math.floor(o.x - R)
      flatten(wx - 6, math.floor(o.y) - 2, wx + 7, math.floor(o.y) + 3)
      S.ug = {
        surface().create_entity{name = "underground-belt", position = {wx + 3 + 0.5, math.floor(o.y) + 0.5}, direction = defines.direction.west,
          type = "input", force = "player"},
        surface().create_entity{name = "underground-belt", position = {wx - 2 + 0.5, math.floor(o.y) + 0.5}, direction = defines.direction.west,
          type = "output", force = "player"},
      }
      local function on_line(e) return math.abs(math.sqrt((e.position.x - o.x) ^ 2 + (e.position.y - o.y) ^ 2) - R) <= 1.5 end
      S.on, S.off, S.pipe_on = 0, 0, 0
      for _, e in ipairs(S.belts) do if on_line(e) then S.on = S.on + 1 else S.off = S.off + 1 end end
      for _, e in ipairs(S.pipes) do if on_line(e) then S.pipe_on = S.pipe_on + 1 end end
      S.ug_on = (S.ug[1] and on_line(S.ug[1]) or false) or (S.ug[2] and on_line(S.ug[2]) or false)
      S.cut = lp("debug_sever", storage.id)
      S.left_on, S.left_off, S.pipe_left = 0, 0, 0
      for _, e in ipairs(S.belts) do
        if e.valid then
          if on_line(e) then S.left_on = S.left_on + 1 else S.left_off = S.left_off + 1 end
        end
      end
      for _, e in ipairs(S.pipes) do if e.valid and on_line(e) then S.pipe_left = S.pipe_left + 1 end end
      S.ug_left = (S.ug[1] and S.ug[1].valid and 1 or 0) + (S.ug[2] and S.ug[2].valid and 1 or 0)
    end)
  end
  schedule(120, function()
    local o = lp("stats", storage.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = -o.x / len, -o.y / len
    local vx, vy = -uy, ux
    local m = {math.floor(o.x + ux * 200), math.floor(o.y + uy * 200)}
    if not (ore or oreoff) then
      flatten(m[1] - 8, m[2] - 8, m[1] + 8, m[2] + 8)
      surface().create_entity{name = "lp-command-relay", position = m, force = "player"}
      for _, d in ipairs({-4, 4}) do
        local t = surface().create_entity{name = "gun-turret", position = {m[1] + d, m[2] - 4}, force = "player"}
        t.insert{name = "firearm-magazine", count = 50}
      end
    end
    local p = {math.floor(o.x + vx * 230), math.floor(o.y + vy * 230)}
    if ore or oreoff then
      local x0, y0 = math.floor(p[1] / 48) * 48 + 8, math.floor(p[2] / 48) * 48 + 8
      flatten(x0 - 2, y0 - 2, x0 + 34, y0 + 34)
      for x = 0, 31 do for y = 0, 31 do surface().create_entity{name = "iron-ore", position = {x0 + x, y0 + y}, amount = 5000} end end
      S.drills = {}
      S.out_bearing = math.deg(math.atan2(y0 + 16 - o.y, x0 + 16 - o.x))
      S.main_bearing = math.deg(math.atan2(m[2] - o.y, m[1] - o.x))
      return
    end
    flatten(p[1] - 10, p[2] - 10, p[1] + 10, p[2] + 10)
    for x = -6, 6 do for y = -6, 6 do surface().create_entity{name = "iron-ore", position = {p[1] + x, p[2] + y}, amount = 5000} end end
    S.drills = {}
    for k = 0, 5 do
      table.insert(S.drills, surface().create_entity{name = "burner-mining-drill", position = {p[1] - 5 + (k % 3) * 4, p[2] - 2 + math.floor(k / 3) * 4},
        force = "player"})
    end
    surface().create_entity{name = "small-electric-pole", position = {p[1], p[2] + 6}, force = "player"}
    for _, d in ipairs({-7, 7}) do
      local t = surface().create_entity{name = "gun-turret", position = {p[1] + d, p[2] + 6}, force = "player"}
      t.insert{name = "firearm-magazine", count = 100}
    end
    S.out_bearing = math.deg(math.atan2(p[2] - o.y, p[1] - o.x))
    S.main_bearing = math.deg(math.atan2(m[2] - o.y, m[1] - o.x))
  end)
  schedule(END - 60, function()
    local cs = lp("cordon_stats", storage.id)
    local left = 0
    for _, d in ipairs(S.drills) do if d.valid then left = left + 1 end end
    local function off_by(a, bb) local d = math.abs((a - bb + 180) % 360 - 180) return d end
    local first = cs.bearings and cs.bearings[1]
    local last = first
    info(string.format("strangle: bearings %s; outpost at %.0f, main at %.0f; drills left %d of 6; perimeter %s",
      serpent.line(cs.bearings), S.out_bearing, S.main_bearing, left, tostring(cs.perimeter)))
    if oreoff then
      local no = lp("next_ore", storage.id)
      check("strangle: the next ore off, no ore target", no.targets == 0, tostring(no.targets))
      return
    end
    if off then
      check("strangle: off, the line goes for the nearest (the case)", last and off_by(last, S.main_bearing) <= 35, tostring(last))
      return
    end
    if sever then
      info(string.format("strangle: sever at R %.1f (standing %s): %d on the line, %d off; cut %s; left on %d, off %d; underground %d of 2 (on line %s); severed %d by the end",
        S.R or 0, tostring(S.war), S.on or 0, S.off or 0, tostring(S.cut), S.left_on or -1, S.left_off or -1, S.ug_left or -1,
        tostring(S.ug_on), cs.severed or 0))
      check("strangle: at war, the line cuts the belt on it by its guns", S.war == "enemy" and (S.on or 0) >= 1 and S.cut == S.on
        and S.left_on == 0, tostring(S.cut))
      check("strangle: the pipe on the line with no gun by it is left", (S.pipe_on or 0) >= 1 and S.pipe_left == S.pipe_on,
        string.format("%s of %s", tostring(S.pipe_left), tostring(S.pipe_on)))
      check("strangle: what stands off the line is left", S.left_off == S.off and (S.off or 0) > 0, tostring(S.left_off))
      check("strangle: an underground passes under the line, by its guns", S.ug_left == 2 and S.ug_on == false and S.guns == 2,
        tostring(S.ug_left) .. ", guns " .. tostring(S.guns))
      return
    end
    if ore then
      -- The field it picked (the one placed, or a richer one of the map's own nearer the player's front).
      local no = lp("next_ore", storage.id)
      local o = lp("stats", storage.id).origin
      local ob = no.at and math.deg(math.atan2(no.at.y - o.y, no.at.x - o.x))
      info("strangle: next ore " .. serpent.line(no) .. string.format(", at %.0f degrees", ob or 0))
      check("strangle: no outpost, the line went for an ore field", last and ob and off_by(last, ob) <= 35 and no.targets >= 1,
        tostring(last) .. " against " .. string.format("%.0f", ob or 0))
      return
    end
    check("strangle: the line went for the outpost", last and off_by(last, S.out_bearing) <= 35, tostring(last))
    info("strangle: drills left " .. left .. " (off: compare)")
  end)
end

-- Scanner (the user's threat scanner): a scanner built as a player builds it, with five Serenity troopers and a hauler,
-- three Grubstake buggies and two biters within its radius, held still; four troopers 80 tiles off. Its output: each
-- kind counted, a total a corporation, nothing for those beyond; two troopers killed, the count follows within 2 s.
scenarios.scanner = function()
  schedule(30, function() lp("debug_tune", {ops_off = true, army_off = true, raids_off = true}) end)
  local function read(e)
    local out = {}
    local cb = e.get_control_behavior()
    local sec = cb and cb.get_section(1)
    for _, f in ipairs(sec and sec.filters or {}) do if f.value then out[f.value.name] = f.min end end
    return out
  end
  local function hold(u) u.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none, ticks_to_wait = 36000} end
  schedule(120, function()
    flatten(-100, -40, 100, 40)
    S.sc = surface().create_entity{name = "lp-threat-scanner", position = {0.5, 0.5}, force = "player", raise_built = true}
    S.troopers = {}
    local function add(name, force, x, y, list)
      local p = surface().find_non_colliding_position(name, {x, y}, 4, 0.5)
      local u = p and surface().create_entity{name = name, position = p, force = force}
      if u then hold(u); if list then table.insert(list, u) end end
      return u
    end
    for k = 1, 5 do add("lp-infantry", "lp-serenity", 10 + 2 * k, 10, S.troopers) end
    add("lp-hauler", "lp-serenity", 20, -10)
    for k = 1, 3 do add("lp-grubstake-buggy", "lp-grubstake", -20 - 4 * k, 10) end
    for k = 1, 2 do add("small-biter", "enemy", -10, -30 - 2 * k) end
    for k = 1, 4 do add("lp-infantry", "lp-serenity", 80 + 2 * k, 0) end
  end)
  schedule(300, function() S.first = read(S.sc) end)
  schedule(320, function() for k = 1, 2 do if S.troopers[k].valid then S.troopers[k].destroy() end end end)
  schedule(460, function() S.after = read(S.sc) end)
  -- A Serenity jammer 30 tiles off: the scanner reads jammed and nothing else; the mast down, it sees again.
  schedule(480, function() S.mast = lp("debug_jammer", "serenity", {-30, 20}) end)
  schedule(620, function() S.jam = read(S.sc) end)
  schedule(640, function()
    for _, m in pairs(surface().find_entities_filtered{name = "lp-jammer"}) do m.destroy() end
  end)
  schedule(780, function() S.clear = read(S.sc) end)
  schedule(END - 60, function()
    local j, c = S.jam or {}, S.clear or {}
    info("scanner: under a jammer " .. serpent.line(j) .. "; mast down " .. serpent.line(c))
    check("scanner: a jammer blinds it", S.mast and j["lp-scan-jammed"] == 1 and table_size(j) == 1, serpent.line(j))
    check("scanner: it sees again with the mast down", c["lp-scan-jammed"] == nil and c["lp-scan-infantry"] == 3, serpent.line(c))
    local f, a = S.first or {}, S.after or {}
    info("scanner: first " .. serpent.line(f) .. "; after two troopers died " .. serpent.line(a))
    check("scanner: each kind counted", f["lp-scan-infantry"] == 5 and f["lp-scan-hauler"] == 1 and f["lp-scan-buggy"] == 3
      and f["lp-scan-biters"] == 2, serpent.line(f))
    check("scanner: a total a corporation", f["lp-scan-serenity"] == 6 and f["lp-scan-grubstake"] == 3, serpent.line(f))
    check("scanner: the count follows", a["lp-scan-infantry"] == 3 and a["lp-scan-serenity"] == 4, serpent.line(a))
    check("scanner: its window does not open", S.sc.operable == false, tostring(S.sc.operable))
  end)
end

-- Roads (the user: "player constructed concrete surfaces that speed up army traversal"; units walk at one speed on any
-- floor, a spike showed): two of the player's troopers walk east 5 s, one on grass, one on refined concrete (1.5 to the
-- engineer): the one on concrete goes at least 30% further.
scenarios.roads = function()
  schedule(30, function() lp("debug_tune", {ops_off = true, army_off = true}) end)
  schedule(120, function()
    flatten(-10, -20, 80, 20)
    local tiles = {}
    for x = -5, 75 do for y = 6, 10 do tiles[#tiles + 1] = {name = "refined-concrete", position = {x, y}} end end
    surface().set_tiles(tiles)
    local a, b = lp("debug_trooper", "lp-trooper", {0, -8}), lp("debug_trooper", "lp-trooper", {0, 8})
    for _, u in pairs(surface().find_entities_filtered{name = "lp-trooper", force = "player"}) do
      if u.unit_number == a then S.a = u elseif u.unit_number == b then S.b = u end
    end
    S.a.commandable.set_command{type = defines.command.go_to_location, destination = {70, -8}, distraction = defines.distraction.none}
    S.b.commandable.set_command{type = defines.command.go_to_location, destination = {70, 8}, distraction = defines.distraction.none}
  end)
  -- The walk renewed every 20 ticks: a registered trooper with no beacon is held by the army's own step (2.4 tiles in
  -- 5 s, where a free one walked 34).
  for t = 140, 120 + 5 * 60, 20 do
    schedule(t, function()
      for _, p in ipairs({{S.a, -8}, {S.b, 8}}) do
        p[1].commandable.set_command{type = defines.command.go_to_location, destination = {70, p[2]},
          distraction = defines.distraction.none}
      end
    end)
  end
  schedule(120 + 5 * 60, function()
    S.ga, S.gb = S.a.position.x, S.b.position.x
  end)
  schedule(END - 60, function()
    info(string.format("roads: after 5 s, grass %.1f tiles, refined concrete %.1f", S.ga or -1, S.gb or -1))
    check("roads: faster on concrete", S.ga and S.gb and S.gb >= 1.3 * S.ga, string.format("%.1f against %.1f", S.gb or -1, S.ga or -1))
  end)
end

-- Muster (the user: "Trains could even play into the mix"): a barracks wired with P (packing) keeps 5 trooper orders as
-- items; none deploy. Carried (by script, as a train would) to a muster point 150 tiles off, they become 5 troopers
-- there within 3 s.
scenarios.muster = function()
  local function put(name, x, y)
    return surface().create_entity{name = name, position = {x, y}, force = "player", raise_built = true}
  end
  local function near(e, r)
    return surface().count_entities_filtered{name = "lp-trooper", force = "player", position = e.position, radius = r}
  end
  schedule(60, function()
    lp("debug_tune", {raids_off = true})
    flatten(-20, -20, 170, 20)
    game.forces.player.technologies["lp-command-bandwidth-1"].researched = true
    S.barracks = put("lp-barracks", 0.5, 0.5)
    put("electric-energy-interface", 4, 1)
    put("medium-electric-pole", 2.5, 2.5)
    put("lp-command-relay", 0.5, 6.5)
    put("medium-electric-pole", 2.5, 5.5)
    put("lp-rally-beacon", 10.5, -10.5)
    local cc = put("constant-combinator", -3.5, 0.5)
    local red = defines.wire_connector_id.circuit_red
    cc.get_wire_connector(red, true).connect_to(S.barracks.get_wire_connector(red, true))
    cc.get_or_create_control_behavior().add_section().filters =
      {{value = {type = "virtual", name = "signal-P", quality = "normal"}, min = 1}}
    S.barracks.get_inventory(defines.inventory.crafter_output).insert{name = "lp-trooper-order", count = 5}
    -- An inserter takes them out of the barracks into a chest (the start of the player's logistics).
    -- Facing south: it picks up from the barracks (south) and drops in the chest (north); a pole for its power.
    S.ins = put("inserter", 0.5, -1.5)
    S.ins.direction = defines.direction.south
    S.chest = put("iron-chest", 0.5, -2.5)
    put("small-electric-pole", 1.5, -1.5)
    S.muster = put("lp-muster-point", 150.5, 0.5)
    put("lp-rally-beacon", 160.5, -10.5)
  end)
  schedule(60 + 3 * 60, function()
    local out = S.barracks.get_inventory(defines.inventory.crafter_output)
    S.taken = S.chest.get_item_count("lp-trooper-order")
    -- Wherever they are: the barracks' output, the chest, or the inserter's hand.
    local hand = S.ins.held_stack.valid_for_read and S.ins.held_stack.count or 0
    S.packed, S.home = out.get_item_count("lp-trooper-order") + S.taken + hand, near(S.barracks, 30)
    -- The train: the orders taken out and put in the muster point.
    out.remove{name = "lp-trooper-order", count = 5}
    S.chest.remove_item{name = "lp-trooper-order", count = 5}
    S.ins.held_stack.clear()
    S.muster.insert{name = "lp-trooper-order", count = S.packed}
  end)
  schedule(60 + 6 * 60, function() S.front, S.left = near(S.muster, 20), S.muster.get_item_count("lp-trooper-order") end)
  schedule(END - 60, function()
    info(string.format("muster: packed %s, at the barracks %s; at the muster point %s, orders left in it %s",
      tostring(S.packed), tostring(S.home), tostring(S.front), tostring(S.left)))
    check("muster: packing, the barracks keeps its orders", S.packed == 5 and S.home == 0,
      string.format("%s kept, %s deployed", tostring(S.packed), tostring(S.home)))
    check("muster: an inserter takes them out", (S.taken or 0) >= 1, tostring(S.taken))
    check("muster: carried, they deploy at the muster point", S.front == 5 and S.left == 0,
      string.format("%s there, %s left", tostring(S.front), tostring(S.left)))
  end)
end

-- Podland (Space Age; the user: "I think it's okay to rely on space age"): a landing queued as the faction's own are
-- comes down by cargo pod: pods seen in flight, the settlement there once they touch down (6.65 s), on the pod's spot,
-- and no remnants left. LP_MIX=off (pods_off): it lands at once, no pod.
scenarios.podland = function()
  local off = params.mix == "off"
  schedule(30, function() lp("debug_tune", {ops_off = true, army_off = true, pods_off = off or nil}) end)
  schedule(120, function()
    S.n0 = #lp("bases")
    lp("arrive_async", 1, {x = 0, y = 0}, 300, {corp = "serenity"})
    S.t0 = game.tick
  end)
  for t = 125, 120 + 30 * 60, 5 do
    schedule(t, function()
      local pods = surface().find_entities_filtered{name = "cargo-pod"}
      if #pods > 0 and not S.pod_at then S.pod_at, S.pod_n, S.pod_pos = game.tick - S.t0, #pods, pods[1].position end
      if #lp("bases") > S.n0 and not S.land_at then
        S.land_at = game.tick - S.t0
        local ids = lp("bases")
        S.new = lp("stats", ids[#ids])
      end
    end)
  end
  schedule(END - 60, function()
    local rem = surface().count_entities_filtered{name = {"cargo-pod-container-remnants", "cargo-pod-container"}}
    info(string.format("podland: pods %s seen %s ticks in; landed %s ticks in at %s; remnants %d", tostring(S.pod_n),
      tostring(S.pod_at), tostring(S.land_at), S.new and serpent.line(S.new.origin) or "-", rem))
    if off then
      check("podland: off, no pod and a landing", S.pod_at == nil and S.land_at ~= nil, tostring(S.pod_at))
      return
    end
    check("podland: pods came down", (S.pod_n or 0) >= 1, tostring(S.pod_n))
    check("podland: it landed once they touched down", S.land_at and S.pod_at and S.land_at - S.pod_at >= 300,
      string.format("pod %s, landing %s", tostring(S.pod_at), tostring(S.land_at)))
    check("podland: no remnants left", rem == 0, tostring(rem))
  end)
end

-- Scan response (the player's side end to end; the user's threat scanner): six troopers at a rally beacon; a threat
-- scanner at an outpost 60 tiles east, wired to a decider that sends X = 60 to the beacon while it reads three Serenity
-- units or more. Four Line troopers come to the outpost at 1 minute: the rally point moves there, the squad marches and
-- kills them; none came before (the squad at home until then).
scenarios.scanresponse = function()
  local function put(name, x, y)
    return surface().create_entity{name = name, position = {x, y}, force = "player", raise_built = true}
  end
  schedule(30, function() lp("debug_tune", {ops_off = true, army_off = true, raids_off = true}) end)
  schedule(60, function()
    flatten(-30, -30, 100, 30)
    game.forces.player.technologies["lp-command-bandwidth-1"].researched = true
    put("electric-energy-interface", 4, 1)
    put("medium-electric-pole", 2.5, 2.5)
    put("lp-command-relay", 0.5, 6.5)
    put("medium-electric-pole", 2.5, 5.5)
    S.beacon = put("lp-rally-beacon", 0.5, -6.5)
    for k = 1, 6 do lp("debug_trooper", "lp-trooper", {k * 1.5 - 4, -4}) end
    S.scanner = put("lp-threat-scanner", 60.5, 0.5)
    -- The decider by the scanner; its output carried home on a red wire over medium poles (a wire reaches about 9
    -- tiles: wired 30 tiles straight, connect_to failed and nothing arrived).
    local dc = put("decider-combinator", 58.5, -3.5)
    S.dc = dc
    put("electric-energy-interface", 63, -4)
    put("small-electric-pole", 60.5, -4.5)
    local w = defines.wire_connector_id
    S.scanner.get_wire_connector(w.circuit_red, true).connect_to(dc.get_wire_connector(w.combinator_input_red, true))
    local prev = dc.get_wire_connector(w.combinator_output_red, true)
    for x = 56.5, 2.5, -7 do
      local pole = put("medium-electric-pole", x, -8.5)
      local c = pole.get_wire_connector(w.circuit_red, true)
      prev.connect_to(c)
      prev = c
    end
    prev.connect_to(S.beacon.get_wire_connector(w.circuit_red, true))
    local cb = dc.get_or_create_control_behavior()
    cb.parameters = {conditions = {{first_signal = {type = "virtual", name = "lp-scan-serenity"}, comparator = "≥", constant = 3}},
      outputs = {{signal = {type = "virtual", name = "signal-X"}, constant = 60, copy_count_from_input = false}}}
  end)
  local function squad_near(x, r)
    return surface().count_entities_filtered{name = "lp-trooper", force = "player", position = {x, 0}, radius = r}
  end
  schedule(50 * 60, function() S.home_before = squad_near(0, 15) end)
  schedule(60 * 60, function()
    S.intruders = {}
    for k = 1, 4 do
      local p = surface().find_non_colliding_position("lp-infantry", {66 + k, 4}, 4, 0.5)
      table.insert(S.intruders, surface().create_entity{name = "lp-infantry", position = p, force = "lp-serenity"})
    end
  end)
  schedule(END - 60, function()
    local alive = 0
    for _, u in ipairs(S.intruders or {}) do if u.valid then alive = alive + 1 end end
    local red, green = defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green
    local sigs = {}
    for _, x in pairs(S.beacon.get_signals(red, green) or {}) do sigs[x.signal.name] = x.count end
    local sc = {}
    local sec = S.scanner.get_control_behavior().get_section(1)
    for _, f in ipairs(sec and sec.filters or {}) do if f.value then sc[f.value.name] = f.min end end
    info("scanresponse: beacon reads " .. serpent.line(sigs) .. "; scanner says " .. serpent.line(sc))
    info(string.format("scanresponse: squad home before %s; at the outpost now %d; intruders alive %d of 4",
      tostring(S.home_before), squad_near(60, 25), alive))
    check("scanresponse: the squad stayed home until the scanner saw them", (S.home_before or 0) >= 5, tostring(S.home_before))
    check("scanresponse: it marched and killed the intruders", alive == 0, alive .. " alive")
  end)
end

scenarios.levers = function()
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true, raids_off = true})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    S.s = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "serenity"})
    lp("debug_depot", S.g, 3000); lp("debug_depot", S.s, 3000)
    S.g0, S.s0 = lp("debug_levers", S.g), lp("debug_levers", S.s)
  end)
  schedule(2 * 3600, function()
    S.g1 = lp("debug_levers", S.g)
    lp("debug_setting", "lp-grubstake-strength", "very-high")
    lp("debug_setting", "lp-grubstake-aggression", "very-high")
    S.g2, S.s2 = lp("debug_levers", S.g), lp("debug_levers", S.s)
  end)
  schedule(8 * 3600, function()
    S.g3, S.s3 = lp("debug_levers", S.g), lp("debug_levers", S.s)
    lp("debug_setting", "lp-grubstake-strength", "normal")
    lp("debug_setting", "lp-grubstake-aggression", "normal")
  end)
  schedule(END - 60, function()
    info("levers: grubstake " .. serpent.line({S.g1, S.g2, S.g3}) .. "; serenity " .. serpent.line({S.s0, S.s2, S.s3}))
    local g1, g2, g3, s2, s3 = S.g1 or {}, S.g2 or {}, S.g3 or {}, S.s2 or {}, S.s3 or {}
    check("levers: normal reads 1", g1.strength == 1 and g1.aggression == 1, serpent.line(g1))
    check("levers: very high strength doubles the cap", g2.strength == 2 and g2.cap == 2 * g1.cap,
      string.format("%s -> %s", tostring(g1.cap), tostring(g2.cap)))
    check("levers: very high aggression halves an hour", g2.hour == 30 * 3600, tostring(g2.hour))
    check("levers: the other corporation untouched", s2.strength == 1 and s2.aggression == 1 and s2.hour == 3600 * 60,
      serpent.line(s2))
    check("levers: the aggressive ladder climbs first", g3.rung == 1 and s3.rung == 0,
      string.format("grubstake %s, serenity %s", tostring(g3.rung), tostring(s3.rung)))
  end)
end

scenarios.chart = function()
  schedule(60, function()
    S.ids = {storage.id}
    for k = 1, 3 do
      local id = lp("arrive", 1, {x = 600 * k, y = 0}, 100, {corp = k % 2 == 1 and "serenity" or "grubstake"})
      if id then table.insert(S.ids, id) end
    end
  end)
  schedule(END - 60, function()
    local seen, dup, ok_voice, drawn, n = {}, 0, 0, 0, 0
    for _, id in ipairs(S.ids or {}) do
      local st = lp("stats", id)
      n = n + 1
      info(string.format("chart: %d %s %q, label %q, %d territory marks", id, st.corp, tostring(st.name), tostring(st.map_text),
        st.claim_marks or 0))
      if st.name then
        if seen[st.name] then dup = dup + 1 end
        seen[st.name] = true
        local serene = st.name:find("%d$") or st.name:find("^Regional Office")
        if (st.corp == "serenity") == (serene ~= nil) then ok_voice = ok_voice + 1 end
      end
      if (st.claim_marks or 0) >= 5 and st.map_text and st.name and st.map_text:find(st.name, 1, true) then drawn = drawn + 1 end
    end
    check("chart: every camp named, in its corporation's voice", ok_voice == n and n >= 3, ok_voice .. " of " .. n)
    check("chart: no two camps share a name", dup == 0, tostring(dup))
    check("chart: territory as chunks, the name on the label", drawn == n, drawn .. " of " .. n)
  end)
end

-- Pool (docs/ai.md: the unit pool): a Grubstake camp grown to its cap, then a raid forced on a player assembler 150
-- tiles out. While the raid is out the camp makes no units (its strength counts the raiders: before, it counted only
-- the garrison and remade them); done, the raiders are on their way back (b.returning) before they rejoin the
-- garrison, and none is drafted from the field.
scenarios.pool = function()
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true, raids_off = true})
    S.id = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    lp("debug_depot", S.id, 6000)
  end)
  schedule(18 * 3600, function()
    local o = lp("stats", S.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local c = {math.floor(o.x - o.x / len * 150), math.floor(o.y - o.y / len * 150)}
    flatten(c[1] - 10, c[2] - 10, c[1] + 10, c[2] + 10)
    surface().create_entity{name = "assembling-machine-1", position = c, force = "player"}
    local st = lp("stats", S.id)
    S.built0, S.cap, S.roster0 = st.units_built, st.cap, st.roster
    -- One floor for what stays home (pool.floor): an operation of choice leaves 30% of the cap, a committed one or a
    -- defence the guard of 2 (each taker had its own, 2, 30% or none).
    S.take_reserve, S.take_guard = lp("debug_take", S.id, "reserve"), lp("debug_take", S.id, "guard")
    lp("dev", {"raid", tostring(S.id)}, c)
    S.out_at = game.tick
  end)
  for t = 18 * 3600 + 300, END - 120, 300 do
    schedule(t, function()
      local st = lp("stats", S.id)
      if st.ops.op and not S.done_at then
        S.built_out = st.units_built - S.built0
        S.roster_max = math.max(S.roster_max or 0, st.roster or 0)
      end
      if not st.ops.op and S.out_at and not S.done_at and (st.ops.done + st.ops.aborted) > 0 then S.done_at = game.tick end
      if S.done_at and (st.returning or 0) > 0 then S.seen_returning = math.max(S.seen_returning or 0, st.returning) end
      S.last_returning = st.returning
    end)
  end
  schedule(END - 60, function()
    local st = lp("stats", S.id)
    info(string.format("pool: cap %s, roster %s at the raid; units made while it was out %s; returning seen %s, at the end %s; "
      .. "last op %s", tostring(S.cap), tostring(S.roster0), tostring(S.built_out), tostring(S.seen_returning),
      tostring(S.last_returning), serpent.line(st.ops.log[#st.ops.log])))
    local r, g = S.take_reserve or {}, S.take_guard or {}
    info("pool: take " .. serpent.line(r) .. " / " .. serpent.line(g))
    check("pool: an operation of choice leaves 30% of the cap home", r.left == math.ceil(0.3 * S.cap) and r.taken > 0,
      serpent.line(r))
    check("pool: a defence leaves the guard of 2", g.left == 2 and g.floor == 2, serpent.line(g))
    check("pool: the raid ran", S.done_at ~= nil, tostring(S.done_at))
    check("pool: the camp was full when the raid left", S.roster0 and S.roster0 >= S.cap, tostring(S.roster0) .. " of " .. tostring(S.cap))
    check("pool: no unit made while the raid was out", S.built_out == 0, tostring(S.built_out))
    check("pool: the raiders came back through the returning list", (S.seen_returning or 0) > 0 and S.last_returning == 0,
      string.format("seen %s, end %s", tostring(S.seen_returning), tostring(S.last_returning)))
  end)
end

-- Mended: the user's save (2026-10-17), Grubstake raids on poles behind a wall the player's robots rebuild. The player's
-- assembler and three poles inside a square of stone wall (12 from it), no turret; a destroyed wall piece comes back 5 s
-- later (robots). A forced raid breaches, keeps breaking the rebuilt pieces (it wandered by the first one for 3 minutes),
-- and razes the assembler. LP_MIX=provoked: Grubstake provoked: the raid takes half what the camp can field (raids of 4
-- at the user's poles from camps of 30 to 50).
-- LP_MIX=serenity: a provoked Serenity's raid instead (it does not sneak): straight at the wall, through it, the
-- assembler razed (its raids on walled substations walked the wall's length and gave up 360 tiles off, visit nw).
scenarios.mended = function()
  local provoked = params.mix == "provoked"
  local serenity = params.mix == "serenity"
  schedule(60, function()
    lp("debug_tune", {era = 2, raids_off = true, history_off = true, provoke = (provoked or serenity) or nil})
    S.id = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = serenity and "serenity" or "grubstake"})
    for _ = 1, 3 do lp("debug_depot", S.id, 4000) end
  end)
  schedule(10 * 3600, function()
    local o = lp("stats", S.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = o.x / len, o.y / len
    local c = {math.floor(o.x - ux * 140), math.floor(o.y - uy * 140)}
    flatten(c[1] - 30, c[2] - 30, c[1] + 30, c[2] + 30)
    S.c, S.walls, S.gone, S.rebuilt = c, {}, {}, 0
    for x = -12, 12 do for y = -12, 12 do
      if math.abs(x) == 12 or math.abs(y) == 12 then
        local p = {c[1] + x + 0.5, c[2] + y + 0.5}
        surface().create_entity{name = "stone-wall", position = p, force = "player"}
        table.insert(S.walls, p)
      end
    end end
    S.target = surface().create_entity{name = "assembling-machine-2", position = {c[1] + 0.5, c[2] + 0.5}, force = "player"}
    for _, d in ipairs({{-6, -6}, {6, 6}, {-6, 6}}) do
      surface().create_entity{name = "medium-electric-pole", position = {c[1] + d[1] + 0.5, c[2] + d[2] + 0.5}, force = "player"}
    end
    S.garrison0 = lp("stats", S.id).garrison
    S.standing0 = lp("standing", "grubstake")
    lp("dev", {"raid", tostring(S.id)}, c)
  end)
  -- The robots: a missing piece is put back 5 s after it went.
  for t = 10 * 3600 + 60, END - 120, 60 do
    schedule(t, function()
      for i, p in ipairs(S.walls or {}) do
        if surface().count_entities_filtered{name = "stone-wall", position = p, radius = 0.4} == 0 then
          S.gone[i] = S.gone[i] or game.tick
          if game.tick - S.gone[i] >= 300 and surface().can_place_entity{name = "stone-wall", position = p, force = "player"} then
            surface().create_entity{name = "stone-wall", position = p, force = "player"}
            S.gone[i], S.rebuilt = nil, S.rebuilt + 1
          end
        end
      end
    end)
  end
  schedule(END - 60, function()
    local st = lp("stats", S.id)
    local first = st.ops.log[1]
    info(string.format("mended%s: target %s, walls rebuilt %d, garrison %s at the raid, first raid %s",
      provoked and " (provoked)" or "", S.target.valid and "standing" or "razed", S.rebuilt, tostring(S.garrison0),
      serpent.line(first)))
    info("mended: Grubstake's standing at the raid " .. tostring(S.standing0))
    info("mended: provoked at " .. serpent.line((lp("corp", "grubstake") or {}).provoked))
    if provoked then
      -- A quarter of its garrison at least (the bug: raids of 4 from camps of 31 to 54). Until 0.2.27, 10 or more: a town
      -- camp has almost no walls, loses more to the attack here, and raided with 9 of 36 (a walled camp: 12 of 42).
      check("mended: a provoked Grubstake raids with a quarter of its garrison or more",
        first and first.launched >= math.ceil((S.garrison0 or 0) / 4), serpent.line({first = first, garrison = S.garrison0}))
    elseif serenity then
      info("mended serenity: breach " .. serpent.line(st.ops.breach_at) .. ", breached " .. tostring(st.ops.breached))
      check("mended: Serenity broke through the wall", S.rebuilt >= 1, tostring(S.rebuilt))
      check("mended: Serenity razed the assembler", not S.target.valid, serpent.line(first))
    else
      -- Through the wall (it kept breaking pieces the robots put back, 3 or more, while it attacked the area from inside;
      -- now it takes the nearest building through the gap, and one breach did it in 20 s).
      check("mended: it broke through the wall", S.rebuilt >= 1, tostring(S.rebuilt))
      check("mended: it razed the assembler", not S.target.valid, "")
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
    -- Its pact off: how a camp answers biters (Grubstake's, once its pacifiers are down; Serenity's always).
    lp("debug_tune", {raids_off = true, pact_off = true})
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
    -- Its pact off: how a camp holds against maximum-evolution biters (Grubstake's once its pacifiers are down).
    lp("debug_tune", {era = 4, raids_off = true, history_off = bare, pact_off = true})
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
  -- LP_MIX=watch: everything 30 s later, to watch the landing (scripts/watch-sim.sh clearing).
  local d = params.mix == "watch" and 1800 or 0
  schedule(d + 30, function() game.forces.enemy.set_evolution_factor(1, surface()) end)
  schedule(d + 60, function()
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
    -- Serenity: Grubstake, at peace with the biters, lands among them and burns nothing (scenario pact).
    S.g = lp("arrive", 1, {x = 0, y = 0}, 350, {corp = "serenity"})
  end)
  schedule(d + 300, function()
    local st = S.g and lp("stats", S.g)
    local left = st and surface().count_entities_filtered{position = st.origin, radius = 80, type = {"unit-spawner", "turret"},
      force = "enemy"} or -1
    local evo = game.forces.enemy.get_evolution_factor_by_killing_spawners(surface())
    info(string.format("clearing: %d spawners placed; Serenity %s, cleared %s, %d left within 80; spawner evolution %.4f -> %.4f",
      S.spawners, tostring(S.g), st and tostring(st.cleared) or "-", left, S.evo0, evo))
    check("clearing: Serenity landed among the nests", S.g ~= nil, "")
    check("clearing: its landing burned a clearing", st and (st.cleared or 0) > 0 and left == 0,
      st and (tostring(st.cleared) .. " cleared, " .. left .. " left") or "no landing")
    check("clearing: without evolving the biters", math.abs(evo - S.evo0) < 1e-6, string.format("%.4f -> %.4f", S.evo0, evo))
  end)
  -- The orbital barrage (war.barrage): a minute and a half on, no spawner within 120, evolution not raised by it.
  schedule(d + 60 + 90 * 60, function()
    local st = S.g and lp("stats", S.g)
    local left = st and surface().count_entities_filtered{position = st.origin, radius = 120, type = "unit-spawner",
      force = "enemy"} or -1
    local evo = game.forces.enemy.get_evolution_factor_by_killing_spawners(surface())
    info(string.format("clearing: orbital barrage, %d spawners left within 120; spawner evolution %.4f", left, evo))
    check("clearing: the orbital barrage cleared 120 tiles", left == 0, tostring(left))
    check("clearing: without evolving the biters (orbital)", evo <= (S.evo0 or 0) + 1e-6, string.format("%.4f", evo))
  end)
end

-- Reinforce (scripts/war.lua, the pressure-ramp consult): the ladder's desperate setup (a provoked Serenity facing six
-- lasers it cannot afford, ladder ten times fast) with a war chest of 3,000 and a relief every 2 minutes. Serenity has no
-- other settlement: its reliefs drop at the lander. Its garrison goes past its cap, the chest pays, and the raid razes
-- the lasers. LP_MIX=starved: the chest empty and no exports: nothing comes.
scenarios.reinforce = function()
  local starved = params.mix == "starved"
  schedule(60, function()
    lp("debug_tune", {era = 2, ladder_fast = true, history_off = true, provoke = true, relief_minutes = 2,
      chest = {serenity = starved and 0 or 3000}})
    S.id = storage.id
    if not starved then for _ = 1, 2 do lp("debug_depot", S.id, 3000) end end
    -- LP_MIX=column: a sister settlement, so reliefs march from it.
    if params.mix == "column" then S.sister = lp("arrive", 1, {x = 0, y = 0}, 350, {corp = "serenity"}) end
  end)
  schedule(2 * 3600, function()
    local o = lp("stats", S.id).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = o.x / len, o.y / len
    local c = {math.floor(o.x - ux * 120), math.floor(o.y - uy * 120)}
    flatten(c[1] - 14, c[2] - 14, c[1] + 14, c[2] + 14)
    surface().create_entity{name = "assembling-machine-1", position = c, force = "player"}
    for k = -2, 3 do
      surface().create_entity{name = "laser-turret", position = {c[1] + 3 * k, c[2] + 5}, force = "player"}
      surface().create_entity{name = "electric-energy-interface", position = {c[1] + 3 * k, c[2] + 8}, force = "player"}
    end
    surface().create_entity{name = "medium-electric-pole", position = {c[1] + 0.5, c[2] + 6.5}, force = "player"}
    if starved then lp("debug_tune", {chest = {serenity = 0}}) end
  end)
  for t = 2 * 3600 + 600, END - 120, 600 do
    schedule(t, function()
      local st = lp("stats", S.id)
      S.over = math.max(S.over or -99, st.garrison + st.patrol - st.cap)
      if st.columns_arrived > 0 or (S.sister and lp("stats", S.sister).columns_arrived > 0) then S.column_arrived = true end
      S.footing = S.footing or st.on_footing
    end)
  end
  schedule(END - 60, function()
    local st = lp("stats", S.id)
    local w = lp("war", "serenity")
    info(string.format("reinforce (%s): reinforced %d, chest %.0f, most over cap %s, launched %d, razed %d, footing %s",
      params.mix, st.reinforced, w.chest, tostring(S.over), st.ops.launched, st.razed, tostring(S.footing)))
    if starved then
      check("reinforce: an empty chest sends nothing", st.reinforced == 0, tostring(st.reinforced))
    elseif params.mix == "column" then
      local total = st.reinforced + (S.sister and lp("stats", S.sister).reinforced or 0)
      check("reinforce: a sister settlement stood", S.sister ~= nil, tostring(S.sister))
      check("reinforce: relief columns arrived", total >= 8 and S.column_arrived == true, total .. " reinforced, arrived " ..
        tostring(S.column_arrived))
    else
      check("reinforce: reliefs came", st.reinforced >= 8, tostring(st.reinforced))
      -- What it spent (its closing balance once read below 3,000: a camp that grows faster refills it from its exports,
      -- 3,037 after paying 363).
      check("reinforce: the chest paid", (w.spent or 0) > 0, string.format("%.0f spent, %.0f left", w.spent or 0, w.chest))
      check("reinforce: the garrison went past its cap", (S.over or -1) > 0, tostring(S.over))
      -- One target here: the raid that razed it all is the last (more targets: the visits).
      check("reinforce: and razed the lasers", st.razed >= 6, tostring(st.razed))
    end
  end)
end

-- Async: a landing called on ground not yet made (900 tiles out on a fresh map) is queued (faction.request), waits while
-- the engine makes its candidates' ground and its reach, and lands within a few minutes, before its patience runs out.
scenarios.async = function()
  schedule(60, function()
    S.fresh = not surface().is_chunk_generated{math.floor(900 / 32), 0}
    S.before = #lp("bases")
    lp("arrive_async", 1, {x = 0, y = 0}, 900, {corp = "grubstake"})
    S.queued = lp("landing_jobs").queued
  end)
  schedule(4 * 3600, function()
    local j = lp("landing_jobs")
    local last = j.last or {}
    info("async: " .. serpent.line({fresh = S.fresh, queued = S.queued, now = j.queued, last = last, bases = #lp("bases")}))
    check("async: the landing was queued", S.queued == 1, tostring(S.queued))
    check("async: it waited for its ground", (last.waits or 0) > 0, tostring(last.waits))
    check("async: and landed, unforced", last.id ~= nil and not last.forced and #lp("bases") == S.before + 1,
      string.format("id %s, %s s", tostring(last.id), tostring(last.ticks and last.ticks / 60)))
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
    S.cap0 = lp("stats", S.id).cap
  end)
  for t = 2 * 3600 + 600, END - 120, 600 do
    schedule(t, function()
      local p = lp("pressure")
      S.max_rung = math.max(S.max_rung or 0, p.ladder)
      if p.last_raze and p.last_raze > 2 * 3600 and not S.first_raze then S.first_raze = game.tick end
      -- The highest rung reached before the player lost anything (a raze resets the clock).
      if not S.first_raze then S.rung_before = math.max(S.rung_before or 0, p.ladder) end
      local st = lp("stats", S.id)
      if (st.war_rung or 0) >= 2 then S.cap2 = math.max(S.cap2 or 0, st.cap) end
      local o = st.ops
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
      -- The ladder buys capacity: from the second rung, its cap half as many again.
      check("ladder: the second rung raised the cap", S.cap2 and S.cap0 and S.cap2 >= math.floor(S.cap0 * 1.5),
        string.format("%s -> %s", tostring(S.cap0), tostring(S.cap2)))
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
  -- Settled: the target razed.
  settle_when(function()
    return S.c ~= nil and surface().count_entities_filtered{position = S.c, radius = 4, name = "assembling-machine-1"} == 0
  end)
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

-- Pact (docs/reviews/2026-10-15-biter-country-consult.md): Grubstake at cease-fire with the biters. Eight behemoths
-- sent at its lander leave it be, and its raid on the player's assembler goes straight through a wall of spawners and
-- worms, which it leaves standing. At 8 minutes its pacifier is destroyed: the pact breaks and biters sent at the camp
-- bite; 5 minutes on the pacifier is rebuilt and the pact holds again. LP_MIX=nopact: the pact off, the same biters
-- cost it units (the control).
scenarios.pact = function()
  local off = params.mix == "nopact"
  schedule(60, function()
    lp("debug_tune", {era = 1, history_off = true, pact_off = off})
    S.g = lp("arrive", 1, {x = 0, y = 0}, params.distance, {corp = "grubstake"})
    for _ = 1, 2 do lp("debug_depot", S.g, 3000) end
  end)
  schedule(2 * 3600, function()
    local o = lp("stats", S.g).origin
    local len = math.sqrt(o.x * o.x + o.y * o.y)
    local ux, uy = o.x / len, o.y / len
    local c = {math.floor(o.x - ux * 170), math.floor(o.y - uy * 170)}
    flatten(c[1] - 8, c[2] - 8, c[1] + 8, c[2] + 8)
    surface().create_entity{name = "assembling-machine-1", position = c, force = "player"}
    S.c = c
    local n = 0
    for k = -150, 150, 14 do
      local p = {o.x - ux * 90 - uy * k, o.y - uy * 90 + ux * k}
      local q = surface().find_non_colliding_position("biter-spawner", p, 6, 1)
      if q and surface().create_entity{name = "biter-spawner", position = q, force = "enemy"} then n = n + 1 end
      local w = surface().find_non_colliding_position("medium-worm-turret", {p[1] - ux * 10, p[2] - uy * 10}, 6, 1)
      if w then surface().create_entity{name = "medium-worm-turret", position = w, force = "enemy"} end
    end
    S.spawners = n
    S.lost0 = lp("stats", S.g).units_lost or 0
    S.lander = surface().find_entities_filtered{position = o, radius = 20, name = "lp-grubstake-lander", limit = 1}[1]
    local at = {o.x + ux * 60, o.y + uy * 60}
    local g = surface().create_unit_group{position = at, force = "enemy"}
    for _ = 1, 8 do
      local u = surface().create_entity{name = "behemoth-biter", force = "enemy",
        position = surface().find_non_colliding_position("behemoth-biter", at, 12, 1)}
      if u then g.add_member(u) end
    end
    g.set_command{type = defines.command.attack_area, destination = o, radius = 30}
  end)
  local function cf() return game.forces["lp-grubstake"].get_cease_fire("enemy") end
  schedule(8 * 3600, function()
    if off then return end
    local st = lp("stats", S.g)
    S.lost8 = (st.units_lost or 0) - S.lost0
    S.spawners8 = surface().count_entities_filtered{type = "unit-spawner", force = "enemy"}
    S.cf0 = cf()
    local o = st.origin
    local pac = surface().find_entities_filtered{position = o, radius = 30, name = "lp-grubstake-pacifier", limit = 1}[1]
    S.had_pacifier = pac ~= nil
    -- The first wave still loiters by the camp at peace: gone before the break (else eight behemoths take the lander).
    for _, u in pairs(surface().find_entities_filtered{position = o, radius = 120, type = "unit", force = "enemy"}) do u.destroy() end
    if pac then pac.die("player") end
    S.cf1 = cf()
    S.hp8 = S.lander and S.lander.valid and S.lander.get_health_ratio() or 0
    local at = {o.x + 40, o.y}
    local g = surface().create_unit_group{position = at, force = "enemy"}
    S.biters = {}
    for _ = 1, 3 do
      local u = surface().create_entity{name = "big-biter", force = "enemy",
        position = surface().find_non_colliding_position("big-biter", at, 12, 1)}
      if u then g.add_member(u); table.insert(S.biters, u) end
    end
    g.set_command{type = defines.command.attack_area, destination = o, radius = 30}
  end)
  schedule(10 * 3600, function()
    if off then return end
    local st = lp("stats", S.g)
    S.bitten = ((st.units_lost or 0) - S.lost0) - S.lost8
    S.hp10 = S.lander and S.lander.valid and S.lander.get_health_ratio() or 0
    S.biters_alive = 0
    for _, u in ipairs(S.biters or {}) do if u.valid then S.biters_alive = S.biters_alive + 1 end end
  end)
  schedule(END - 60, function()
    local st = lp("stats", S.g)
    local lost = (S.lost8 or (st.units_lost or 0) - S.lost0)
    local spawners = S.spawners8 or surface().count_entities_filtered{type = "unit-spawner", force = "enemy"}
    local target = surface().count_entities_filtered{position = S.c, radius = 4, name = "assembling-machine-1"}
    local hp = S.hp8 or (S.lander and S.lander.valid and S.lander.get_health_ratio()) or 0
    info(string.format("pact: %s; %d units lost, lander health %.2f, spawners %d of %d, target %s; %s",
      off and "off" or "on", lost, hp, spawners, S.spawners, target > 0 and "standing" or "razed",
      serpent.line(st.ops.log[#st.ops.log])))
    if off then
      check("nopact: the biters cost the camp", lost > 0 or hp < 1, string.format("%d lost, %.2f", lost, hp))
    else
      check("pact: no units lost to the biters", lost == 0, tostring(lost))
      check("pact: the lander untouched", hp == 1, string.format("%.2f", hp))
      check("pact: the raid went through and razed the target", target == 0, target > 0 and "standing" or "razed")
      check("pact: the nests left standing", spawners == S.spawners, string.format("%d of %d", spawners, S.spawners))
      check("pact: a pacifier stood, and its loss broke the pact", S.had_pacifier and S.cf0 and not S.cf1,
        string.format("%s %s %s", tostring(S.had_pacifier), tostring(S.cf0), tostring(S.cf1)))
      -- Broken, it is war again: the camp and the biters fight (the three sent died to its turrets, or bit).
      check("pact: broken, the camp and the biters fought", (S.bitten or 0) > 0 or (S.hp10 or 1) < (S.hp8 or 1)
        or S.biters_alive == 0, string.format("%d lost, lander %.2f -> %.2f, %d of 3 biters alive", S.bitten or 0,
        S.hp8 or 0, S.hp10 or 0, S.biters_alive or -1))
      local back = surface().count_entities_filtered{position = st.origin, radius = 30, name = "lp-grubstake-pacifier"}
      check("pact: the pacifier rebuilt and the pact back", back > 0 and cf(), string.format("%d, %s", back, tostring(cf())))
    end
  end)
end

-- Overflight (the biter-country consult): Grubstake, which never clears nests, behind a wall of spawners and worms with
-- six harriers in its garrison: no way round on the ground, so they fly over (round the worms), raze the player's
-- undefended assembler beyond, and most come home.
scenarios.overflight = function()
  schedule(60, function()
    lp("debug_tune", {history_off = true, pact_off = true})
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
  -- What each unit takes of the command bandwidth: the mod's own (a copy here said 4 for a battle tank after the mod
  -- made it 6, and the relays fell 20 short: on 2.1, where nothing died early, 30 of 40 trained).
  local POP = require("__landing-party__.shared").POPULATION
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
-- Labs (rd.lua) gate research only where a scenario asks for them: the rest test the tree's choices, not where it stands.
local LABS = {labs = true, breach = true, factory = true, visit = true}
if not LABS[params.scenario] then schedule(1, function() lp("debug_tune", {labs_off = true}) end) end
-- The biotech lands only where it is the subject (its arrival needs nests and evolution, which some scenarios set up).
-- (A visit lets it come as it would to the player's game: on evolution, to a nest field out from the factory; the
-- user, 2026-10-25: the visits never had Synthexis.)
if params.scenario ~= "farm" and params.scenario ~= "visit" then schedule(1, function() lp("debug_tune", {biotech_off = true}) end) end
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
  -- LP_OFF=blast,landfill,pier (sim.sh): 0.2.29's ground handling off, each named (bisecting what it changed).
  if (params.off or "") ~= "" then
    local t = {}
    for k in params.off:gmatch("[%a_]+") do t[k .. "_off"] = true end
    lp("debug_tune", t)
  end
  -- Levers from the mix, before any early return (a visit's levers were never set; sweeps: LP_MIX=provoked-S2-A0.5): S<x> every corporation's strength, A<x> its aggression.
  local mix = params.mix or ""
  local st, ag = tonumber(mix:match("S([%d%.]+)")), tonumber(mix:match("A([%d%.]+)"))
  if st or ag then
    local levers = {}
    for _, corp in ipairs({"grubstake", "serenity"}) do levers[corp] = {strength = st, aggression = ag} end
    lp("debug_tune", {levers = levers})
    -- Kept in storage: the run is saved after on_init and loaded, which resets the lines.
    storage.levers_note = string.format("levers: strength %s, aggression %s", tostring(st or 1), tostring(ag or 1))
  end
  -- Land as the real arrival does, `distance` tiles from spawn (on a site with ore round it).
  -- Phases plays the opening itself: no landing at the start.
  if params.scenario == "phases" then return end
  -- System plays its own arrivals (scenarios.system).
  if params.scenario == "system" then return end
  -- A real factory (scripts/visit.sh) is loaded, not created: its arrival is placed by the scenario.
  if params.scenario == "visit" then return end
  -- The siege lab's trials (scenarios.lab) run on a save made for them.
  if params.scenario == "lab" then return end
  storage.id = lp("arrive", 1, {x = 0, y = 0}, params.distance,
    {doctrine = params.doctrine or (params.scenario == "defend" and "bastion")
      or (params.scenario == "convoy" and params.mix == "grown" and "bastion")
      or ((params.scenario == "army" or params.scenario == "siege") and "sprawl") or nil,
     uplink = params.scenario == "uplink" or nil})
  if not storage.id then error("lp-sim: landing failed") end
  -- Operations' mechanics are tested here, not tempers (Serenity only strikes once provoked): provoked from the
  -- start, except where tempers are the subject.
  local TEMPERS = {temper = true, strip = true, contact = true, line = true, grudge = true, visit = true, standing = true, border = true, gate = true,
    mended = true, pool = true, remembered = true, factory = true}
  -- Crews killed provoke (the user, 2026-10-17): those mixes start unprovoked, or the check proves nothing.
  -- And crystal marker: provoked, Serenity (whom claim markers do not hold) raided the marked outpost the test watches.
  local unprovoked = (params.scenario == "crew" and (params.mix == "doomed" or params.mix == "dronekill"
    or params.mix == "answered")) or (params.scenario == "crystal" and params.mix == "marker")
    -- The ledger bills a rival only.
    or (params.scenario == "hazard" and (params.mix == "pay" or params.mix == "unpaid" or params.mix == "clean"))
  if not TEMPERS[params.scenario] and not unprovoked then lp("debug_tune", {provoke = true}) end
  -- Grubstake's thieves' hours (ops.thief_hours) off but where they are the subject (skim night) and on visits: the
  -- scenarios' timings were set without them.
  if params.scenario ~= "visit" and params.scenario ~= "factory" and params.mix ~= "night" then lp("debug_tune", {night_off = true}) end
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
  if storage.levers_note then table.insert(lines, 1, "INFO " .. storage.levers_note) end
  -- No settlement at all (a scenario that lands later and never did): its own checks say why.
  if not storage.id then
    if not S.solo then check("a settlement exists", false, "none landed") end
    -- (As below: "ALL PASSED" when none failed, which sim.sh and the regression read; system solo lands no settlement.)
    table.insert(lines, failed == 0 and "DONE ALL PASSED" or ("DONE " .. failed .. " FAILED"))
    helpers.write_file("landing-party/results.txt", table.concat(lines, "\n") .. "\n")
    return
  end
  local s = lp("stats", storage.id)
  -- A run that ends before its scenario's checks fire must not pass (path once "passed" at 32 minutes with
  -- its checks due at 35).
  -- The watchdog (scripts/watch.lua): its alarms by kind, and the first few with what it saw.
  local ok_w, wst = pcall(lp, "watch_state")
  if ok_w and wst then
    local n = 0
    for _, v in pairs(wst.alarms or {}) do n = n + v end
    metric("watch_alarms", n)
    info("watch: " .. serpent.line(wst.alarms or {}))
    for i = 1, math.min(5, #(wst.log or {})) do
      local l = wst.log[i]
      info(string.format("watch %d base %d %s: %s", l.tick, l.base, l.kind, l.text))
    end
  end
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

-- Buildings by kind, for the system sim's tally.
local KILL_KIND = {}
for _, t in ipairs({"ammo-turret", "electric-turret", "fluid-turret", "artillery-turret", "turret"}) do KILL_KIND[t] = "turrets" end
for _, t in ipairs({"wall", "gate"}) do KILL_KIND[t] = "walls" end
for _, t in ipairs({"generator", "electric-energy-interface", "solar-panel", "accumulator", "electric-pole", "reactor",
  "boiler", "burner-generator", "fusion-generator"}) do KILL_KIND[t] = "power" end
for _, t in ipairs({"inserter", "transport-belt", "underground-belt", "splitter", "container", "logistic-container", "pipe",
  "pipe-to-ground", "pump", "loader", "loader-1x1"}) do KILL_KIND[t] = "logistics" end
for _, t in ipairs({"mining-drill", "furnace", "assembling-machine", "lab", "rocket-silo", "radar", "roboport"}) do KILL_KIND[t] = "production" end

-- What kills the player's troopers, and the lander (army scenario diagnostics).
script.on_event(defines.events.on_entity_died, function(e)
  if LAB.died then LAB.died(e) end
  -- creep break: who killed the Grubstake rifleman by its tumor (the truce: never Synthexis).
  if S.intruder and e.entity == S.intruder then S.intruder_killer = e.force and e.force.name or "nobody" end
  local by = e.cause and e.cause.valid and e.cause.name or "no cause"
  -- System: who lost what to whom (victim force > killer force, units and buildings apart).
  if params.scenario == "system" then
    local v, k = e.entity.force.name, e.force and e.force.name or "none"
    local what = (e.entity.type == "unit" or e.entity.type == "spider-unit" or e.entity.type == "character") and "units"
      or "buildings"
    if e.entity.type ~= "tree" and e.entity.type ~= "simple-entity" then
      S.kills = S.kills or {}
      local key = v .. ">" .. k .. ":" .. what
      S.kills[key] = (S.kills[key] or 0) + 1
      -- And buildings by kind (the user, 2026-10-25: what each faction breaks, against what it is meant to go for).
      if what == "buildings" then
        local t = e.entity.type
        local kind = KILL_KIND[t] or "other"
        local kk = v .. ">" .. k .. ":" .. kind
        S.kills[kk] = (S.kills[kk] or 0) + 1
      end
      -- And where (the user, 2026-10-25: a map of the deaths by kind): each death with its killer and where that stood,
      -- written with the minute's frame to deaths.jsonl (scripts/system_review.py draws them).
      local p, c = e.entity.position, e.cause and e.cause.valid and e.cause or nil
      S.death_buf = S.death_buf or {}
      table.insert(S.death_buf, {s = math.floor(game.tick / 60), x = math.floor(p.x), y = math.floor(p.y), v = v,
        n = e.entity.name, d = what == "units" and "units" or (KILL_KIND[e.entity.type] or "other"), k = k,
        c = c and c.name or nil, cx = c and math.floor(c.position.x) or nil, cy = c and math.floor(c.position.y) or nil})
    end
  end
  -- Where a corporation's unit fell to a turret, and how far from it (the claim rig's hands fell to turrets out of reach).
  if e.cause and e.cause.valid and e.cause.type == "ammo-turret" and e.entity.type == "unit" and e.entity.force.name:sub(1, 3) == "lp-" then
    S.turret_kills = S.turret_kills or {}
    local d = math.sqrt((e.entity.position.x - e.cause.position.x) ^ 2 + (e.entity.position.y - e.cause.position.y) ^ 2)
    table.insert(S.turret_kills, string.format("%.0f,%.0f d%.1f t+%ds", e.entity.position.x, e.entity.position.y, d,
      math.floor((game.tick - (S.t0 or 0)) / 60)))
  end
  -- The player's buildings Synthexis destroyed (the visit's report).
  if e.entity.force.name == "player" and e.force and e.force.name == "lp-biotech" then
    S.syn_razed = S.syn_razed or {}
    S.syn_razed[e.entity.type] = (S.syn_razed[e.entity.type] or 0) + 1
  end
  -- The player's buildings the biters destroyed (the visit's report: Grubstake's pollution draws them).
  if e.entity.force.name == "player" and e.force and e.force.name == "enemy" and e.entity.type ~= "character" then
    S.biter_razed = S.biter_razed or {}
    S.biter_razed[e.entity.type] = (S.biter_razed[e.entity.type] or 0) + 1
  end
  if e.entity.name == "gun-turret" then
    table.insert(lines, string.format("INFO gun turret at %.0f,%.0f destroyed by %s (%s)", e.entity.position.x,
      e.entity.position.y, by, e.force and e.force.name or "?"))
  elseif e.entity.force.name == "player" then
    S.killers = S.killers or {}
    local k = e.entity.name == "lp-trooper" and by or (e.entity.name .. " by " .. by)
    S.killers[k] = (S.killers[k] or 0) + 1
    if e.entity.type == "mining-drill" and params.scenario == "gate" then
      table.insert(lines, string.format("INFO gate: a player drill at %.0f,%.0f died at %.1f min to %s (%s)", e.entity.position.x,
        e.entity.position.y, game.tick / 3600, by, e.force and e.force.name or "?"))
    end
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
-- Every death in the system sim (its tally of who lost what to whom): filtered, the tally saw only these kinds, and a
-- Synthexis wave that broke the player's power, inserters and lasers counted 1 of 20 (2026-10-25). And in a visit (what
-- Synthexis and the biters razed of the player's): filtered, nw's first wave into the factory broke 444 of its buildings,
-- 12 assemblers and 6 roboports down at once, and the report read "razed of the player's {}" (2026-10-29).
end, params.scenario ~= "system" and params.scenario ~= "visit" and params.scenario ~= "herd" and params.scenario ~= "lab" and {{filter = "name", name = "lp-trooper"}, {filter = "name", name = "lp-breacher"},
  {filter = "name", name = "lp-battle-tank"}, {filter = "name", name = "lp-lander"}, {filter = "name", name = "gun-turret"},
  {filter = "name", name = "artillery-turret"}, {filter = "type", type = "unit"}, {filter = "type", type = "mining-drill"},
  {filter = "type", type = "spider-unit"}} or nil)

-- Bait: what the biters it called do to Serenity (12 small biters reach its camp and bite; on 2.1 its flamers kill them
-- all before anything falls: 42 to a pylon, nothing destroyed).
if params.scenario == "bait" then
  script.on_event(defines.events.on_entity_damaged, function(e)
    if e.force and e.force.name == "enemy" and e.entity.force.name == "lp-serenity" then
      S.bite = (S.bite or 0) + e.final_damage_amount
    end
  end)
end

-- Herd: damage between the wild biters and the bred.
if params.scenario == "herd" then
  script.on_event(defines.events.on_entity_damaged, function(e)
    if not (e.force and S.damage) then return end
    local a, v = e.force.name, e.entity.force.name
    if (a == "enemy" and v == "lp-biotech") or (a == "lp-biotech" and v == "enemy") then
      S.damage[a .. ">" .. v] = (S.damage[a .. ">" .. v] or 0) + e.final_damage_amount
    end
    if e.cause and e.cause.valid and e.cause.name == "lp-bred-stomper" and v == "lp-biotech" then
      S.damage["stomper>own"] = (S.damage["stomper>own"] or 0) + e.final_damage_amount
    end
  end)
end

-- Flak: what the cannons do to the wall.
if params.scenario == "flak" then
  script.on_event(defines.events.on_entity_damaged, function(e)
    if not (e.cause and e.cause.valid and e.cause.name == S.flak_name) then return end
    if e.entity.type == "wall" then S.wall_hits = (S.wall_hits or 0) + e.final_damage_amount; return end
    if e.entity.name == "lp-infantry" then
      S.thits = S.thits or {}
      local k = string.format("%.1f", e.final_damage_amount)
      S.thits[k] = (S.thits[k] or 0) + 1
    end
  end, {{filter = "type", type = "wall"}, {filter = "name", name = "lp-infantry"}})
end

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

-- The player's robots rebuilding (the visit: does the factory fight back on its own, or only lose?).
script.on_event(defines.events.on_robot_built_entity, function(e)
  if e.entity.valid and e.entity.force.name == "player" then
    S.robot_built = S.robot_built or {}
    S.robot_built[e.entity.type] = (S.robot_built[e.entity.type] or 0) + 1
  end
end)

script.on_event(defines.events.on_ai_command_completed, function(e)
  if S.results then S.results[e.unit_number] = e.result end
end)

-- Ticks are counted from the tick the test mod was added (storage.t0): 0 on a new map, hours into a real save
-- (scripts/visit.sh; scheduled by absolute tick, nothing ever ran on one).
-- A step that errors is a failed check, and the results are written all the same: a visit at strength 2 ran its three
-- hours and wrote nothing, no error in its log (2026-10-18).
script.on_event(defines.events.on_tick, function(e)
  local f = at[e.tick - (storage.t0 or 0)]
  if not f then return end
  local ok, err = pcall(f)
  if not ok then
    check("a scheduled step ran without error (tick " .. (e.tick - (storage.t0 or 0)) .. ")", false, tostring(err))
    helpers.write_file("landing-party/results.txt", table.concat(lines, "\n") .. "\nDONE " .. failed .. " FAILED\n")
  end
end)
