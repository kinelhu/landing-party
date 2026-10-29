-- The wall pen (scripts/wall-lab.sh): a stretch of nw's north wall rebuilt as built (nwwall_data.lua: 48 lasers, 16
-- flamethrowers, 768 wall pieces over 200 tiles), boxed in behind so the only way in is through it, and a wave of the
-- biotech's breeds sent at its middle as a herd breaks in (landing-party/scripts/herd.lua breach): in one group, with
-- no distraction, at the wall pieces in its way and on 20 tiles inside; big bursters each at a turret of their own,
-- nearest first, 6 tiles apart (send_big_bursters); cinders at the wall where the wave hits it. Tactic "silence": the
-- group takes the turrets covering where it hits first, nearest first (what it does when firemap.affords says it can).
-- What each wave costs and what it breaks is the answer: the user's question (2026-10-28) is whether a big burster
-- opens a line like nw's at all, measured here rather than in a three-hour visit.
local arena = require("arena")
local params = require("params")
local DATA = require("nwwall_data")

local wall = {}

local SPACING = 400
local LIMIT = 240 * 60
local SPAWN = -75                -- the wave starts this far north of the wall's middle (lasers reach 24, flamers 30)
local HIT = -16                  -- where it meets the wall (the outer row)
local INSIDE = 30                -- and where it goes once through
local THROUGH = 10               -- a unit this far south of the middle is through
local BIG_BURST_R = 6
local FORCE = "lp-serenity"

-- {label, tactic, {{prototype, n}...}}: spends at shared.BREEDS (medium 7, big 28, cinder 40, big burster 300).
local WAVES = {
  {"300 medium (2100)", "rush", {{"lp-bred-medium-biter", 300}}},
  {"600 medium (4200)", "rush", {{"lp-bred-medium-biter", 600}}},
  {"300 medium + 7 big bursters (4200)", "rush", {{"lp-bred-medium-biter", 300}, {"lp-bred-big-burster", 7}}},
  {"171 medium + 3 big bursters (2100)", "rush", {{"lp-bred-medium-biter", 171}, {"lp-bred-big-burster", 3}}},
  {"263 medium + 7 cinders (2100)", "rush", {{"lp-bred-medium-biter", 263}, {"lp-bred-cinder", 7}}},
  {"75 big (2100)", "rush", {{"lp-bred-big-biter", 75}}},
  {"300 medium (2100)", "silence", {{"lp-bred-medium-biter", 300}}},
  {"300 medium + 7 big bursters (4200)", "silence", {{"lp-bred-medium-biter", 300}, {"lp-bred-big-burster", 7}}},
  {"75 big (2100)", "silence", {{"lp-bred-big-biter", 75}}},
  {"14 big bursters (4200)", "rush", {{"lp-bred-big-burster", 14}}},
  {"7 big bursters, 300 medium 20 s behind (4200)", "rush", {{"lp-bred-medium-biter", 300}, {"lp-bred-big-burster", 7}}, 20},
  {"7 big bursters, 75 big 20 s behind (4200)", "rush", {{"lp-bred-big-biter", 75}, {"lp-bred-big-burster", 7}}, 20},
  {"21 behemoth (4200)", "rush", {{"lp-bred-behemoth-biter", 21}}},
  {"7 big bursters, 10 behemoth 20 s behind (4100)", "rush", {{"lp-bred-behemoth-biter", 10}, {"lp-bred-big-burster", 7}}, 20},
  -- At what nw's cultures already gather (waves of up to 778 mediums, some 5,400).
  {"20 big bursters (6000)", "rush", {{"lp-bred-big-burster", 20}}},
  {"14 big bursters, 10 behemoth 20 s behind (6200)", "rush", {{"lp-bred-behemoth-biter", 10}, {"lp-bred-big-burster", 14}}, 20},
  {"14 big bursters, 300 medium 20 s behind (6300)", "rush", {{"lp-bred-medium-biter", 300}, {"lp-bred-big-burster", 14}}, 20},
  {"14 big bursters, 75 big 20 s behind (6300)", "rush", {{"lp-bred-big-biter", 75}, {"lp-bred-big-burster", 14}}, 20},
}

local function d2(a, b) return (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 end

local function build(s, c)
  local f = game.forces.player
  local out = {walls = {}, lasers = {}, flamers = {}}
  for _, e in ipairs(DATA) do
    local ent = s.create_entity{name = e[1], position = {c[1] + e[2], c[2] + e[3]}, direction = e[4], force = f}
    if ent then
      if e[1] == "laser-turret" then table.insert(out.lasers, ent)
      elseif e[1] == "flamethrower-turret" then ent.insert_fluid{name = "light-oil", amount = 1000}; table.insert(out.flamers, ent)
      else table.insert(out.walls, ent) end
    end
  end
  -- The box behind: indestructible, so the way in is through the stretch.
  local function block(x, y)
    local b = s.create_entity{name = "stone-wall", position = {x, y}, force = f}
    if b then b.destructible = false end
  end
  -- (Its rows run x -99.5 to 99.5: the sides close them at 100.5.)
  for y = -28, 60 do block(c[1] - 100.5, c[2] + y + 0.5); block(c[1] + 100.5, c[2] + y + 0.5) end
  for x = -100, 100 do block(c[1] + x + 0.5, c[2] + 60.5) end
  -- Power as a megabase has it: plenty, on poles nothing can hit.
  local e = s.create_entity{name = "electric-energy-interface", position = {c[1], c[2] + 40}, force = f}
  e.power_production = 1e9 / 60
  e.electric_buffer_size = 1e9
  e.destructible = false
  for x = -99, 99, 16 do
    local p = s.find_non_colliding_position("substation", {c[1] + x, c[2] + 4}, 4, 1)
    local sub = p and s.create_entity{name = "substation", position = p, force = f}
    if sub then sub.destructible = false end
  end
  for y = 12, 36, 16 do
    local sub = s.create_entity{name = "substation", position = {c[1], c[2] + y}, force = f}
    if sub then sub.destructible = false end
  end
  return out
end

local function start(i, w, round)
  local s = arena.surface()
  local c = {(i - 1) * SPACING + (round - 1) * 3, (round - 1) * 2}
  s.request_to_generate_chunks(c, 5)
  s.force_generate_chunk_requests()
  for _, e in pairs(s.find_entities_filtered{area = {{c[1] - 180, c[2] - 180}, {c[1] + 180, c[2] + 180}}}) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
  local f = {c = c, label = w[1], tactic = w[2], round = round, started = game.tick, units = {}, names = {}, max_in = 0}
  f.def = build(s, c)
  f.n_def = {walls = #f.def.walls, lasers = #f.def.lasers, flamers = #f.def.flamers}
  local at = {c[1], c[2] + SPAWN}
  local group = s.create_unit_group{position = at, force = FORCE}
  local big, cinders = {}, {}
  for _, e in ipairs(w[3]) do
    for _ = 1, e[2] do
      local p = s.find_non_colliding_position(e[1], at, 40, 0.5)
      local u = p and s.create_entity{name = e[1], position = p, force = FORCE}
      if u then
        table.insert(f.units, u); table.insert(f.names, e[1])
        if e[1] == "lp-bred-big-burster" then table.insert(big, u)
        elseif e[1] == "lp-bred-cinder" then table.insert(cinders, u)
        else group.add_member(u) end
      end
    end
  end
  f.n_units = #f.units
  local hit = {x = c[1], y = c[2] + HIT}
  local cmds = {}
  if w[2] == "silence" then
    -- The turrets covering the hit, nearest first (firemap.cover: those whose reach holds it).
    local cover = {}
    for _, t in ipairs(f.def.lasers) do if d2(t.position, hit) <= 24 * 24 then table.insert(cover, t) end end
    for _, t in ipairs(f.def.flamers) do if d2(t.position, hit) <= 30 * 30 then table.insert(cover, t) end end
    table.sort(cover, function(a, b) return d2(a.position, hit) < d2(b.position, hit) end)
    for _, t in ipairs(cover) do table.insert(cmds, {type = defines.command.attack, target = t, distraction = defines.distraction.none}) end
  end
  local ws = s.find_entities_filtered{position = hit, radius = 3, type = "wall", force = "player"}
  table.sort(ws, function(a, b) return d2(a.position, hit) < d2(b.position, hit) end)
  for k = 1, math.min(2, #ws) do table.insert(cmds, {type = defines.command.attack, target = ws[k], distraction = defines.distraction.none}) end
  table.insert(cmds, {type = defines.command.go_to_location, destination = {c[1], c[2] + INSIDE}, radius = 4,
    distraction = defines.distraction.none})
  -- w[4]: the group held back that many seconds after the bursters go.
  f.group, f.cmd, f.delay = group, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
    commands = cmds}, (w[4] or 0) * 60
  if f.delay == 0 then group.set_command(f.cmd) end
  -- Big bursters: each at a turret of its own, nearest the wave first, none within 6 of another's.
  local guns = {}
  for _, t in ipairs(f.def.lasers) do table.insert(guns, t) end
  for _, t in ipairs(f.def.flamers) do table.insert(guns, t) end
  local from = {x = at[1], y = at[2]}
  table.sort(guns, function(a, b) return d2(a.position, from) < d2(b.position, from) end)
  local aimed, k = {}, 0
  for _, t in ipairs(guns) do
    if k >= #big then break end
    local near = false
    for _, h in ipairs(aimed) do if d2(h, t.position) < BIG_BURST_R ^ 2 then near = true; break end end
    if not near then
      k = k + 1
      aimed[#aimed + 1] = t.position
      big[k].commandable.set_command{type = defines.command.attack, target = t, distraction = defines.distraction.none}
    end
  end
  -- Cinders: at the wall where the wave meets it.
  for j, u in ipairs(cinders) do
    local t = ws[(j - 1) % math.max(1, #ws) + 1]
    if t then u.commandable.set_command{type = defines.command.attack, target = t, distraction = defines.distraction.none} end
  end
  return f
end

local function count(list)
  local n = 0
  for _, e in ipairs(list) do if e.valid then n = n + 1 end end
  return n
end

local function step(f)
  local t = game.tick - f.started
  if f.delay > 0 and t >= f.delay and not f.sent then
    f.sent = true
    -- What it was aimed at may be gone (the bursters' work): the rest, and the wall left where it hits.
    local cmds = {}
    for _, cmd in ipairs(f.cmd.commands) do
      if not cmd.target or cmd.target.valid then table.insert(cmds, cmd) end
    end
    if #cmds == 1 then
      local hit = {f.c[1], f.c[2] + HIT}
      local ws = f.group.surface.find_entities_filtered{position = hit, radius = 3, type = "wall", force = "player", limit = 2}
      for k = #ws, 1, -1 do table.insert(cmds, 1, {type = defines.command.attack, target = ws[k], distraction = defines.distraction.none}) end
    end
    f.cmd.commands = cmds
    if f.group.valid then f.group.set_command(f.cmd) end
  end
  for _, fl in ipairs(f.def.flamers) do
    if fl.valid then fl.insert_fluid{name = "light-oil", amount = 100} end
  end
  local alive, inside = 0, 0
  for _, u in ipairs(f.units) do
    if u.valid then
      alive = alive + 1
      -- Inside the box (round its sides is not through).
      if u.position.y > f.c[2] + THROUGH and u.position.y < f.c[2] + 60 and math.abs(u.position.x - f.c[1]) < 100 then
        inside = inside + 1
        if not f.seen_in then f.seen_in = {math.floor(u.position.x - f.c[1]), math.floor(u.position.y - f.c[2]), t / 60} end
      end
    end
  end
  f.max_in = math.max(f.max_in, inside)
  if alive == 0 or t >= LIMIT then
    local lost = {}
    for i, u in ipairs(f.units) do if not u.valid then lost[f.names[i]] = (lost[f.names[i]] or 0) + 1 end end
    f.result = {label = f.label, tactic = f.tactic, round = f.round, seconds = t / 60, sent = f.n_units, left = alive,
      inside = inside, max_inside = f.max_in, lost = lost,
      lasers_lost = f.n_def.lasers - count(f.def.lasers), flamers_lost = f.n_def.flamers - count(f.def.flamers),
      walls_lost = f.n_def.walls - count(f.def.walls), walls = f.n_def.walls, seen_in = f.seen_in, lasers = f.n_def.lasers, flamers = f.n_def.flamers}
    return true
  end
  return false
end

-- nw's player force's weapon research (LP_MIX=walldump, wall_research.json): lasers at four times their damage and
-- 3.2 times their rate, flamethrowers at 2.6 times by ammo and 2.6 by turret.
local RESEARCH = {ammo = {laser = 3, flamethrower = 1.6, beam = 0.7, bullet = 1.4, landmine = 1},
  speed = {laser = 2.2, bullet = 1.5}, turret = {["flamethrower-turret"] = 1.6, ["gun-turret"] = 1.4}}

function wall.start()
  local pf = game.forces.player
  if not params.fresh then
    for k, v in pairs(RESEARCH.ammo) do pf.set_ammo_damage_modifier(k, v) end
    for k, v in pairs(RESEARCH.speed) do pf.set_gun_speed_modifier(k, v) end
    for k, v in pairs(RESEARCH.turret) do pf.set_turret_attack_modifier(k, v) end
  end
  storage.wall = {round = 0}
  wall.next_round()
end

function wall.next_round()
  local W = storage.wall
  W.round = W.round + 1
  W.live = {}
  for i, w in ipairs(WAVES) do
    if not params.only or params.only == "" or (w[1] .. " " .. w[2]):find(params.only, 1, true) then
      table.insert(W.live, start(i, w, W.round))
    end
  end
end

function wall.tick()
  local W = storage.wall
  if not W or W.done or game.tick % 60 ~= 0 then return end
  local open = 0
  for _, f in ipairs(W.live) do
    if not f.written then
      if step(f) then
        helpers.write_file("lp-arena/wall.jsonl", helpers.table_to_json(f.result) .. "\n", true)
        f.written = true
      else open = open + 1 end
    end
  end
  if open == 0 then
    if W.round < (params.rounds or 3) then wall.next_round()
    else
      W.done = true
      helpers.write_file("lp-arena/done.txt", string.format("%d wall fights in %d rounds, tick %d", #W.live * W.round, W.round, game.tick))
    end
  end
end

return wall
