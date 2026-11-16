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
arena.PLAYER_UNITS = {"lp-trooper", "lp-breacher", "lp-rocket-trooper", "lp-flame-trooper", "lp-battle-tank", "lp-gun-buggy"}
arena.LINES = {guns = "gun turrets (piercing rounds)", lasers = "laser turrets", flamers = "flamethrower turrets",
  walls = "a wall line", teslas = "tesla turrets"}
arena.BITERS = {"small-biter", "medium-biter", "big-biter", "behemoth-biter", "small-spitter", "medium-spitter",
  "big-spitter", "behemoth-spitter"}

-- Play mode (arena.play, set by control.lua): a surface of real ground (the user, 2026-11-09: "the arena (make it concrete
-- and not editor blank space)"): Nauvis's own generation without ore, biters, cliffs or water, the pen paved in concrete
-- inside a hazard border (arena.ground). The batch keeps its lab tiles: its numbers are set against them.
local PAVE = {52, 32}             -- the pen's paving, half its width and height: the sides start 30 either side of it
function arena.surface()
  local s = game.surfaces[arena.SURFACE]
  if not s and arena.play then
    local mgs = game.surfaces.nauvis.map_gen_settings
    mgs.seed = 4242
    for name, c in pairs(mgs.autoplace_controls or {}) do
      local proto = prototypes.autoplace_control[name]
      if (proto and proto.category == "resource") or name == "enemy-base" or name == "water" then c.size = 0 end
    end
    mgs.cliff_settings = mgs.cliff_settings or {}
    mgs.cliff_settings.richness = 0
    s = game.create_surface(arena.SURFACE, mgs)
    s.always_day = true
    remote.call("landing-party", "debug_tune", {arena_surface = arena.SURFACE, biotech_off = true})
  elseif not s then
    s = game.create_surface(arena.SURFACE, {width = 0, height = 0, peaceful_mode = false})
    s.generate_with_lab_tiles = true
    s.always_day = true
    -- The Scorcher's flame runs only where a camp stands, or on a surface named arena (landing-party control.lua).
    remote.call("landing-party", "debug_tune", {arena_surface = arena.SURFACE, biotech_off = true})
  end
  return s
end

-- Ground for a pen centred on c (lab tiles, generated now; in play mode real ground, the pen paved once and cleared of
-- trees and rocks round it).
function arena.ground(c, radius_chunks)
  local s = arena.surface()
  s.request_to_generate_chunks(c, radius_chunks or 3)
  s.force_generate_chunk_requests()
  storage.paved = storage.paved or {}
  local key = c[1] .. "," .. c[2]
  if arena.play and not storage.paved[key] then
    storage.paved[key] = true
    for _, e in pairs(s.find_entities_filtered{area = {{c[1] - 90, c[2] - 90}, {c[1] + 90, c[2] + 90}}, type = {"tree", "simple-entity"}}) do
      e.destroy()
    end
    local tiles = {}
    for x = -PAVE[1], PAVE[1] - 1 do
      for y = -PAVE[2], PAVE[2] - 1 do
        local edge = x == -PAVE[1] or x == PAVE[1] - 1 or y == -PAVE[2] or y == PAVE[2] - 1
        tiles[#tiles + 1] = {name = edge and "hazard-concrete-left" or "concrete", position = {c[1] + x, c[2] + y}}
      end
    end
    s.set_tiles(tiles)
    -- (Grass tufts stayed on the concrete: a tile change keeps the decoratives.)
    s.destroy_decoratives{area = {{c[1] - PAVE[1], c[2] - PAVE[2]}, {c[1] + PAVE[1], c[2] + PAVE[2]}}}
  end
  return s
end

-- What a unit of the corporations costs in parts (shared.unit_cost: a Grubstake variant at Grubstake's price); nil for
-- anything else.
-- The player's units cost no parts; what limits an army of them is command bandwidth. In the matrix one slot of it is
-- priced as a Serenity rifleman (10 parts), so a trooper is worth one and a battle tank its shared.POPULATION (8 since
-- 0.2.438). A convention, not measured: it sets every player row against the corporations' (among the player's own units
-- it cancels); a whole game with an army is what would check it.
arena.PER_BANDWIDTH = 10

function arena.cost(kind, name)
  -- The biotech's breeds at their provisional price (shared.BREEDS).
  if name and shared.BREEDS[name] then return shared.BREEDS[name].cost end
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

-- What a corporation really fields (as scripts/arena_report.py reads it): the kinds in its landing mixes and the units its
-- tree unlocks, in shared.CORPS. The panel offers these; the batch fights every kind on both forces (the counter matrix).
function arena.fielded(corp)
  local seen, out = {}, {}
  local function walk(t)
    for k, v in pairs(t) do
      if k == "mix" and type(v) == "table" then
        for kind in pairs(v) do seen[kind] = true end
      elseif k == "unit" and type(v) == "table" and v.kind then
        seen[v.kind] = true
      elseif type(v) == "table" then
        walk(v)
      end
    end
  end
  walk(shared.CORPS[corp] or {})
  for kind in pairs(seen) do
    if prototypes.entity[shared.variant(corp, kind)] then table.insert(out, kind) end
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
local function line(s, kind, n, x, y, out, thick)
  local f = game.forces.player
  local half = (n - 1) / 2
  if kind == "walls" then
    -- thick: rows of wall (a player's wall is often two deep).
    for row = 0, (thick or 1) - 1 do
      for dy = -n, n do table.insert(out, s.create_entity{name = "stone-wall", position = {x - 4 - row, y + dy}, force = f}) end
    end
    return
  end
  local name = kind == "guns" and "gun-turret" or kind == "lasers" and "laser-turret" or kind == "teslas" and "tesla-turret"
    or "flamethrower-turret"
  for i = 0, n - 1 do
    local p = {x, y + (i - half) * 3}
    local t = s.create_entity{name = name, position = p, force = f, direction = defines.direction.west}
    if t then
      if kind == "guns" then t.insert{name = "piercing-rounds-magazine", count = 100}
      elseif kind == "flamers" then t.insert_fluid{name = "light-oil", amount = 1000} end
      table.insert(out, t)
    end
  end
  if kind == "lasers" or kind == "teslas" then
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
      line(s, kind, n, x + facing * -8, y, out, en[4])
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
    side.max, side.cost, side.type, side.n0 = {}, {}, {}, alive(side.units)
    for i, e in ipairs(side.units) do
      side.max[i], side.type[i] = e.max_health, e.type
      -- Units and walkers (spider-units: their deaths went uncounted until 2026-10-21).
      side.cost[i] = (e.type == "unit" or e.type == "spider-unit") and arena.cost(shared.kind_of(e.name), e.name) or nil
    end
  end
  command(f.a, f.b.at); command(f.b, f.a.at)
  return f
end

-- What a side lost by type (the breach: walls and turrets apart).
local function lost_by_type(side)
  local out = {}
  for i, e in ipairs(side.units) do
    if not e.valid then out[side.type[i]] = (out[side.type[i]] or 0) + 1 end
  end
  return out
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
    f.result.a.lost, f.result.b.lost = lost_by_type(f.a), lost_by_type(f.b)
    return true
  end
  return false
end

return arena
