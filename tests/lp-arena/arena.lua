-- The arena: fights between two sides in a pen on a surface of lab tiles, judged when one side has nothing left that
-- fights, or at the time limit. A side is a list of entries: corporation units ({corp, kind, n}), the player's units and
-- defence lines ({"player", kind, n}), or biters ({"biters", name or "wave", n, evo}). Used headless (batch.lua: the
-- balance table) and in game (gui.lua: fights set up by hand).
local shared = require("__landing-party__.shared")

local arena = {}

arena.SURFACE = "lp-arena"
arena.LIMIT = 180 * 60           -- a fight undecided after three minutes is a draw
local GAP = 60                   -- the sides start this far apart
local RECOMMAND = 5 * 60         -- idle units are sent at the other side again this often

arena.FORCES = {serenity = "lp-serenity", grubstake = "lp-grubstake", player = "player", biters = "enemy"}
arena.PLAYER_UNITS = {"lp-trooper", "lp-breacher", "lp-rocket-trooper", "lp-battle-tank"}
arena.LINES = {guns = "gun turrets (piercing rounds)", lasers = "laser turrets", flamers = "flamethrower turrets",
  walls = "a wall line"}
arena.BITERS = {"small-biter", "medium-biter", "big-biter", "behemoth-biter", "small-spitter", "medium-spitter",
  "big-spitter", "behemoth-spitter"}

function arena.surface()
  local s = game.surfaces[arena.SURFACE]
  if not s then
    s = game.create_surface(arena.SURFACE, {width = 0, height = 0, peaceful_mode = false})
    s.generate_with_lab_tiles = true
    s.always_day = true
    -- The Scorcher's flame runs only where a camp stands, or on a surface named arena (landing-party control.lua).
    remote.call("landing-party", "debug_tune", {arena_surface = arena.SURFACE})
  end
  return s
end

-- Ground for a pen centred on c (lab tiles, generated now).
function arena.ground(c, radius_chunks)
  local s = arena.surface()
  s.request_to_generate_chunks(c, radius_chunks or 3)
  s.force_generate_chunk_requests()
  return s
end

-- What a unit of the corporations costs in parts (shared.unit_cost: a Grubstake variant at Grubstake's price); nil for
-- anything else.
-- The player's units cost no parts; what limits an army of them is command bandwidth. In the matrix one slot of it is
-- priced as a Serenity rifleman (10 parts), so a trooper is worth one and a battle tank four.
arena.PER_BANDWIDTH = 10

function arena.cost(kind, name)
  if shared.POPULATION[kind] then return arena.PER_BANDWIDTH * shared.POPULATION[kind] end
  if not shared.units[kind] then return nil end
  return shared.unit_cost(name and name:find("^lp%-grubstake%-") and "grubstake" or "serenity", kind)
end

-- The corporations' own unit kinds whose prototype exists for that corporation.
function arena.corp_kinds(corp)
  local out = {}
  for kind in pairs(shared.units) do
    if kind ~= "lp-hauler" and prototypes.entity[shared.variant(corp, kind)] then table.insert(out, kind) end
  end
  table.sort(out)
  return out
end

-- A biter wave of n at evolution evo: each spawner's weights read at evo (linear between its points), half from the
-- biter spawner and half from the spitter spawner, counts by largest remainder (deterministic).
function arena.wave(n, evo)
  local weights = {}
  for _, sp in ipairs({"biter-spawner", "spitter-spawner"}) do
    local total, w = 0, {}
    for _, def in ipairs(prototypes.entity[sp].result_units) do
      local pts, v = def.spawn_points, 0
      for i, p in ipairs(pts) do
        local q = pts[i + 1]
        if evo <= p.evolution_factor then v = (i == 1) and p.weight or v; break end
        if not q then v = p.weight; break end
        if evo < q.evolution_factor then
          v = p.weight + (q.weight - p.weight) * (evo - p.evolution_factor) / (q.evolution_factor - p.evolution_factor)
          break
        end
      end
      if v > 0 then w[def.unit] = v; total = total + v end
    end
    for name, v in pairs(w) do weights[name] = (weights[name] or 0) + v / total / 2 end
  end
  local out, given, rest = {}, 0, {}
  for name, v in pairs(weights) do
    local k = math.floor(n * v)
    out[name] = k; given = given + k
    table.insert(rest, {name, n * v - k})
  end
  table.sort(rest, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
  for i = 1, n - given do out[rest[i][1]] = out[rest[i][1]] + 1 end
  return out
end

local function place(s, name, at, force, spread)
  local p = s.find_non_colliding_position(name, at, spread or 12, 0.5)
  return p and s.create_entity{name = name, position = p, force = force}
end

-- A defence line of the player's facing west at x, n turrets along y, a wall line 4 tiles in front.
local function line(s, kind, n, x, y, out)
  local f = game.forces.player
  local half = (n - 1) / 2
  if kind == "walls" then
    for dy = -n, n do table.insert(out, s.create_entity{name = "stone-wall", position = {x - 4, y + dy}, force = f}) end
    return
  end
  local name = kind == "guns" and "gun-turret" or kind == "lasers" and "laser-turret" or "flamethrower-turret"
  for i = 0, n - 1 do
    local p = {x, y + (i - half) * 3}
    local t = s.create_entity{name = name, position = p, force = f, direction = defines.direction.west}
    if t then
      if kind == "guns" then t.insert{name = "piercing-rounds-magazine", count = 100}
      elseif kind == "flamers" then t.insert_fluid{name = "light-oil", amount = 1000} end
      table.insert(out, t)
    end
  end
  if kind == "lasers" then
    local e = s.create_entity{name = "electric-energy-interface", position = {x + 6, y}, force = f}
    e.power_production = 50e6 / 60
    e.electric_buffer_size = 50e6
    e.destructible = false
    for i = -1, math.ceil(n * 3 / 14) do
      local sub = s.create_entity{name = "substation", position = {x + 3, y + i * 14 - (n * 3) / 2 + 7}, force = f}
      if sub then sub.destructible = false end
    end
  end
end

-- Spawn one side's entries round (x, y); returns its fighters and its parts spent.
local function spawn(s, entries, x, y, facing)
  local out, parts = {}, 0
  for _, en in ipairs(entries) do
    local who, kind, n = en[1], en[2], en[3]
    if who == "biters" then
      local list = kind == "wave" and arena.wave(n, en[4] or 0.5) or {[kind] = n}
      local names = {}
      for name in pairs(list) do table.insert(names, name) end
      table.sort(names)
      for _, name in ipairs(names) do
        for _ = 1, list[name] do
          local u = place(s, name, {x, y}, "enemy", 20)
          if u then table.insert(out, u) end
        end
      end
    elseif who == "player" and arena.LINES[kind] then
      line(s, kind, n, x + facing * -8, y, out)
    else
      -- "raw": a prototype by name on a force by name (the counter matrix: any kind on either corporation's force).
      local name = who == "raw" and kind or who == "player" and kind or shared.variant(who, kind)
      local force = who == "raw" and en[4] or arena.FORCES[who]
      for _ = 1, n do
        local u = place(s, name, {x, y}, force, 20)
        if u then table.insert(out, u) end
      end
      parts = parts + (arena.cost(shared.kind_of(name), name) or 0) * n
    end
  end
  return out, parts
end

local function fights(e)
  return e.valid and e.type ~= "wall" and e.type ~= "gate"
end

local function alive(list)
  local n = 0
  for _, e in ipairs(list) do if fights(e) then n = n + 1 end end
  return n
end

-- Health lost by a side: what died at its full health, what stands at what it lost.
local function hurt(side)
  local lost = 0
  for i, e in ipairs(side.units) do
    if e.valid then lost = lost + (e.max_health - e.health)
    else lost = lost + side.max[i] end
  end
  return lost
end

-- Parts lost by a side (corporation units only).
local function parts_lost(side)
  local lost = 0
  for i, e in ipairs(side.units) do
    if not e.valid and side.cost[i] then lost = lost + side.cost[i] end
  end
  return lost
end

local function command(side, other_at)
  for _, u in ipairs(side.units) do
    if u.valid and u.commandable and not u.commandable.has_command then
      u.commandable.set_command{type = defines.command.attack_area, destination = other_at, radius = 40,
        distraction = defines.distraction.by_anything}
    end
  end
end

-- Clear a pen: everything on it but the ground.
function arena.clear(c, r)
  local s = arena.surface()
  for _, e in pairs(s.find_entities_filtered{area = {{c[1] - r, c[2] - r}, {c[1] + r, c[2] + r}}}) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

-- Start a fight at pen centre c: side a from the west, side b from the east. Returns the fight's state.
function arena.start(c, a, b, label)
  local s = arena.ground(c)
  arena.clear(c, 90)
  local f = {c = c, label = label, started = game.tick, a = {at = {c[1] - GAP / 2, c[2]}}, b = {at = {c[1] + GAP / 2, c[2]}}}
  f.a.units, f.a.parts = spawn(s, a, f.a.at[1], f.a.at[2], -1)
  f.b.units, f.b.parts = spawn(s, b, f.b.at[1], f.b.at[2], 1)
  for _, side in ipairs({f.a, f.b}) do
    side.max, side.cost, side.n0 = {}, {}, alive(side.units)
    for i, e in ipairs(side.units) do
      side.max[i] = e.max_health
      -- Units and walkers (spider-units: their deaths went uncounted until 2026-10-21).
      side.cost[i] = (e.type == "unit" or e.type == "spider-unit") and arena.cost(shared.kind_of(e.name), e.name) or nil
    end
  end
  command(f.a, f.b.at); command(f.b, f.a.at)
  return f
end

-- One step of a fight; returns true once it is decided (f.result set).
function arena.step(f)
  if f.result then return true end
  local na, nb = alive(f.a.units), alive(f.b.units)
  local t = game.tick - f.started
  if t % RECOMMAND == 0 then
    local function centre(side)
      local x, y, n = 0, 0, 0
      for _, e in ipairs(side.units) do if fights(e) then x, y, n = x + e.position.x, y + e.position.y, n + 1 end end
      return n > 0 and {x / n, y / n} or side.at
    end
    command(f.a, centre(f.b)); command(f.b, centre(f.a))
  end
  if na == 0 or nb == 0 or t >= arena.LIMIT then
    f.result = {
      label = f.label, seconds = t / 60,
      winner = (na > 0 and nb == 0) and "a" or (nb > 0 and na == 0) and "b" or "draw",
      a = {start = f.a.n0, left = na, parts = f.a.parts, parts_lost = parts_lost(f.a), hurt = hurt(f.a)},
      b = {start = f.b.n0, left = nb, parts = f.b.parts, parts_lost = parts_lost(f.b), hurt = hurt(f.b)},
    }
    return true
  end
  return false
end

return arena
