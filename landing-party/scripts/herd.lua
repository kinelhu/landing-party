-- The biotech's waves: a pack (docs/biotech.md, "Waves with intent: the pack"; Fable:
-- docs/reviews/2026-10-22-wave-intelligence-consult.md). The first slice: a pen on a held nest breeds to its stock, then
-- sends one wave the player can watch and read.
--   1. The tracker: one bred biter walks a loop outside the turrets' reach (LOOP_OUT past the outermost turret), stopping
--      at four faces, noting the turrets it sees; its icon over it and on the map. Then it sits at the face where it saw
--      fewest: the mark. Killed or stopped before its loop is whole, the wave comes blind (a plain wave) and the next
--      loop there is wider.
--   2. The trail: mud on the ground and a dashed line on the map, from the pen's gate round the loop to the mark.
--   3. The herd gathers at the gate for 90 seconds, then walks the trail to the mark, a leader's icon over it, fighting
--      nothing on the way.
--   4. The breach: the two wall pieces nearest where the line to the middle meets the wall, then INSIDE tiles in.
--   5. What feeds the guns, the first it sees: power, the inserters loading gun turrets, the pipes at flamethrowers; not
--      what stands under three or more turrets (an inner keep is the counter); pushing on to the middle if it sees none.
--   6. Home: when nothing in sight feeds a gun (once it has pushed on to the middle), after INSIDE_TICKS inside, or at
--      half lost, back out the breach and up its trail, fighting nothing; never holding ground.
-- The engine tests (2026-10-22): a force at cease-fire with "enemy" never fights the wild biters; a herd walks a
-- 360-tile route of waypoints whole; a stop in a compound command holds the scout; turrets are the `cause` of their
-- hits, lasers included.
local ground = require("__landing-party__.scripts.ground")
local know = require("__landing-party__.scripts.know")
local shared = require("shared")
local herd = {}

local B = shared.BIOTECH
local SIGHT = 40            -- what a biter of the pack sees, scout or herd (tiles)
local LOOP_OUT = 29         -- the loop past the outermost turret: beyond a laser (24); a flamethrower (30) reaches it
local LOOP_POINTS = 16
local STOP_EVERY = 4        -- a pause at every fourth loop point: four faces
local LOOP_CLEAR = 30       -- a loop point this far from every foe turret (a gun turret's 18, a laser's 24, a margin)
local RESUMES = 3
local REGROUPS = 3         -- a wave's group formed again from its living members, at most this often          -- a failed loop taken up again from the next point, at most this often
local STOP_TICKS = 600
local SIT_TICKS = 30 * 3600
local GATHER_TICKS = 90 * 60
local INSIDE = 15
local INSIDE_TICKS = 90 * 60
local TRAIL_TICKS = 20 * 3600
local BASE_REACH = 120      -- the turrets that make one base, round what drew the wave
local SCOUT_EXTRA = 10      -- a dead scout's lesson: the next loop round that base this much wider
local SCOUT_TIMEOUT = 5 * 3600
local GEN_WAIT = 2 * 3600      -- at most, for its corridor's chunks before the scout sets out
-- It does not bite under the guns: a target with this many of the player's turrets within a laser's reach of it is
-- passed over (forty bred took a power source under four lasers and three guns for eleven of them: the inner keep has
-- to be a counter the player can build, docs/biotech.md).
local GUARDED, GUARD_RANGE = 3, 24
local TURRETS = {"ammo-turret", "electric-turret", "fluid-turret"}
local WALLS = {"wall", "gate"}
local POWER = {"generator", "solar-panel", "accumulator", "burner-generator", "electric-energy-interface", "reactor",
  "fusion-generator", "lightning-attractor"}
local PIPES = {"pipe", "pipe-to-ground", "pump"}
-- What draws a wave: the player's machines and guns (pollution is what feeds it; these make it).
herd.DRAW = {"ammo-turret", "electric-turret", "fluid-turret", "assembling-machine", "furnace", "mining-drill", "boiler",
  "generator", "lab"}

local function st()
  storage.herd = storage.herd or {pens = {}, waves = {}, next = 1, log = {}, trails = {}}
  return storage.herd
end

local function force() return game.forces[B.force] end

-- Its force: at peace with the wild biters both ways; neutral with Grubstake (it grows on its pollution) until a break,
-- which a later slice gives triggers; at war with everyone else.
function herd.init()
  local f = game.forces[B.force] or game.create_force(B.force)
  f.custom_color = B.color
  local enemy = game.forces.enemy
  if enemy then f.set_cease_fire(enemy, true); enemy.set_cease_fire(f, true) end
  local g = game.forces[shared.CORPS.grubstake.force]
  if g and not st().grubstake_broken then f.set_cease_fire(g, true); g.set_cease_fire(f, true) end
  st()
end

-- The break with Grubstake (the brief: "neutral with Grubstake at first ... with its own bred herds only, never the wild
-- ones"; farm.lua says when): the cease-fire between the two goes, for good. The wild biters' pact with Grubstake stands.
function herd.break_grubstake(why)
  if st().grubstake_broken then return false end
  st().grubstake_broken = {why = why, tick = game.tick}
  local f, g = force(), game.forces[shared.CORPS.grubstake.force]
  if f and g then f.set_cease_fire(g, false); g.set_cease_fire(f, false) end
  if storage.trace then
    helpers.write_file("landing-party/decisions.txt", string.format("%8d %s  at war with Grubstake: %s\n", game.tick,
      "biotech", why), true)
  end
  return true
end

function herd.grubstake_broken() return st().grubstake_broken end

local function d2(a, b)
  local ax, ay = a.x or a[1], a.y or a[2]
  local bx, by = b.x or b[1], b.y or b[2]
  return (ax - bx) ^ 2 + (ay - by) ^ 2
end
local function xy(p) return {x = p.x or p[1], y = p.y or p[2]} end
local function add(p, dx, dy) return {x = p.x + dx, y = p.y + dy} end

local function players() return shared.player_forces() end
-- Whom a wave is sent against: the player's forces, or the rival it was sent at (farm.lua, every third wave).
local function foes(w) return (w and w.foes) or players() end
-- What its waves learnt at a defence (the user, 2026-10-24: Synthexis, the smart biter enemy; learning that shows): by
-- the defence's middle on a 64-tile grid, each face tried (of eight) with what came of it, and what killed its units
-- there, by kind. Read by the scout (a face that held weighs as if better gunned) and by farm.lua (a wave's make-up
-- tilts toward the breeds that beat those killers, counters.lua). Kept in its knowledge (know.lua).
local HELD_PENALTY = 3      -- a face that held: this many turrets more in the scout's eyes, each time
local function lesson_key(c) return string.format("%d,%d", math.floor(c.x / 64), math.floor(c.y / 64)) end
local function lessons()
  local k = know.of("biotech")
  k.lessons = k.lessons or {}
  return k.lessons
end
function herd.lesson_near(pos, reach)
  local best, bd
  for key, l in pairs(lessons()) do
    local cx, cy = key:match("^(-?%d+),(-?%d+)$")
    local d = (tonumber(cx) * 64 + 32 - (pos.x or pos[1])) ^ 2 + (tonumber(cy) * 64 + 32 - (pos.y or pos[2])) ^ 2
    if d <= (reach or 128) ^ 2 and (not bd or d < bd) then best, bd = l, d end
  end
  return best
end

-- Everyone whose turrets shoot its units: the player's forces and every corporation's (a wave's foes are its target's).
local function hostiles()
  local out = {}
  for _, f in ipairs(players()) do out[#out + 1] = f end
  for _, c in pairs(shared.CORPS) do if game.forces[c.force] then out[#out + 1] = c.force end end
  return out
end

local function log(w, text)
  if storage.trace then
    helpers.write_file("landing-party/decisions.txt", string.format("%8d %s  wave %d: %s\n", game.tick, "biotech", w.id,
      text), true)
  end
end

-- Pens -------------------------------------------------------------------------------------------------------------

function herd.add_pen(pen)
  st().pens[pen.unit_number] = {pen = pen, stock = {}, memory = {}}
  return pen.unit_number
end

function herd.pen(id) return st().pens[id] end

-- A wild nest taken: the spawner gives way to a pen on the same spot (its wild biters stay wild).
function herd.capture(spawner)
  local s, pos = spawner.surface, spawner.position
  spawner.destroy()
  local pen = s.create_entity{name = "lp-pen", position = pos, force = B.force}
  return pen and herd.add_pen(pen)
end

-- What a pen has to send: what it bred and still owns, and what came home from its last wave. Never a unit out with a
-- live wave: an incubator takes back the units it released while they wait for the scout, and counted as its stock
-- they went feral with it when it went unfed (87 of a wave of 120 walked home as the wild's; system sim, 2026-10-25).
local function stock(p)
  local out, seen = {}, {}
  for _, w in pairs(st().waves) do
    for _, u in ipairs(w.members) do if u.valid then seen[u.unit_number] = true end end
  end
  local function take(u)
    if u.valid and u.force.name == B.force and not seen[u.unit_number] then seen[u.unit_number] = true; table.insert(out, u) end
  end
  if p.pen.valid then for _, u in pairs(p.pen.units) do take(u) end end
  for _, u in pairs(p.stock) do take(u) end
  p.stock = {}
  for _, u in ipairs(out) do table.insert(p.stock, u) end
  return out
end
herd.stock = stock

-- A pen given back to the wild (starved off its creep, farm.lua): a wild spawner in its place, and its stock gone feral
-- (the wild force's now: they keep their colours).
function herd.release(id)
  local p = st().pens[id]
  if not p then return nil end
  local out = stock(p)
  st().pens[id] = nil
  if not p.pen.valid then return nil end
  local s, pos = p.pen.surface, p.pen.position
  p.pen.destroy()
  for _, u in ipairs(out) do if u.valid then u.force = "enemy" end end
  return s.create_entity{name = "biter-spawner", position = pos, force = "enemy"}
end

-- The base: the box round the player's turrets near what drew it, its middle and half sizes. (A circle round their
-- average missed a lopsided base's heavy face: the loop sized by the far back turret ran 55 to 67 tiles off the front,
-- beyond its sight; seen in the first herd run.)
local function base_box(s, pos, forces)
  local ts = s.find_entities_filtered{position = pos, radius = BASE_REACH, force = forces, type = TURRETS}
  if #ts == 0 then return xy(pos), 8, 8 end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, t in ipairs(ts) do
    x0, y0 = math.min(x0, t.position.x), math.min(y0, t.position.y)
    x1, y1 = math.max(x1, t.position.x), math.max(y1, t.position.y)
  end
  return {x = (x0 + x1) / 2, y = (y0 + y1) / 2}, math.max(8, (x1 - x0) / 2), math.max(8, (y1 - y0) / 2)
end

-- From the middle along angle a, out to a box of half sizes hx, hy.
local function to_box(c, hx, hy, a)
  local cs, sn = math.cos(a), math.sin(a)
  local t = math.min(math.abs(cs) > 1e-6 and hx / math.abs(cs) or math.huge, math.abs(sn) > 1e-6 and hy / math.abs(sn) or math.huge)
  return {x = c.x + t * cs, y = c.y + t * sn}
end

-- Map and world tells ---------------------------------------------------------------------------------------------

local function mark_unit(w, u, on_map)
  if not (u and u.valid) then return end
  table.insert(w.marks, rendering.draw_sprite{sprite = B.icon, surface = u.surface, target = {entity = u, offset = {0, -2.2}},
    x_scale = 0.9, y_scale = 0.9})
  if on_map then
    table.insert(w.marks, rendering.draw_sprite{sprite = B.icon, surface = u.surface, target = {entity = u},
      x_scale = 1.5, y_scale = 1.5, render_mode = "chart"})
  end
end

local function clear_marks(w)
  for _, m in ipairs(w.marks or {}) do if m.valid then m.destroy() end end
  w.marks = {}
end

-- The trail: mud every two tiles (not on anyone's floor, not in water) for TRAIL_TICKS (herd.tick takes the mud up),
-- the whole way home; on the map only its last MAP_TRAIL tiles, thin and faint: where a wave came in from, not a line to
-- the culture (the user, 2026-10-23: "Not a fan of the big green line on the map pointing to Synthexis"). Finding home
-- is following the mud.
local MAP_TRAIL = 120
local function lay_trail(s, points)
  local decs, mud = {}, {}
  -- Each segment's distance from the trail's end, so the map line keeps the last MAP_TRAIL tiles only.
  local to_end, run = {}, 0
  for i = #points - 1, 1, -1 do
    to_end[i] = run
    run = run + math.sqrt(d2(points[i], points[i + 1]))
  end
  for i = 1, #points - 1 do
    local a, b = points[i], points[i + 1]
    local len = math.sqrt(d2(a, b))
    if to_end[i] < MAP_TRAIL then
      local from = a
      if to_end[i] + len > MAP_TRAIL then
        local f = 1 - (MAP_TRAIL - to_end[i]) / len
        from = {x = a.x + (b.x - a.x) * f, y = a.y + (b.y - a.y) * f}
      end
      rendering.draw_line{surface = s, from = from, to = b, color = {r = B.color.r, g = B.color.g, b = B.color.b, a = 0.45},
        width = 1, dash_length = 2, gap_length = 2, render_mode = "chart", time_to_live = TRAIL_TICKS}
    end
    for k = 0, math.floor(len / 2) do
      local f = k * 2 / math.max(len, 1)
      local side = (k % 2 == 0) and 0.6 or -0.6
      local p = {x = a.x + (b.x - a.x) * f + side * (b.y - a.y) / math.max(len, 1),
        y = a.y + (b.y - a.y) * f - side * (b.x - a.x) / math.max(len, 1)}
      local tile = s.get_tile(p.x, p.y)
      if tile.valid and not tile.prototype.mineable_properties.minable and not tile.collides_with("water_tile") then
        table.insert(decs, {name = k % 3 == 0 and "dark-mud-decal" or "light-mud-decal", position = p, amount = 1})
        table.insert(mud, {p.x, p.y})
      end
    end
  end
  if #decs > 0 then s.create_decoratives{check_collision = false, decoratives = decs} end
  table.insert(st().trails, {surface = s.index, mud = mud, expires = game.tick + TRAIL_TICKS})
end

local function lift_trails(tick)
  local keep = {}
  for _, t in ipairs(st().trails) do
    if tick >= t.expires then
      local s = game.surfaces[t.surface]
      if s then
        for _, p in ipairs(t.mud) do
          s.destroy_decoratives{area = {{p[1] - 0.5, p[2] - 0.5}, {p[1] + 0.5, p[2] + 0.5}},
            name = {"dark-mud-decal", "light-mud-decal"}}
        end
      end
    else
      table.insert(keep, t)
    end
  end
  st().trails = keep
end

-- The wave ---------------------------------------------------------------------------------------------------------

-- The loop: a box LOOP_OUT (and what dead scouts taught) outside the turrets' box, sixteen points round it, each moved
-- to the nearest ground a biter can stand on (kept once its chunk is generated). On the box itself a point fell in a
-- lake, on a cliff or on a building, its leg failed, and the scout's whole loop with it: 14 of 19 waves came blind
-- (the system sim, 0.2.9).
-- `scouting`: the scout's own loop, moved to walkable ground clear of every turret. Without it, the point as laid out:
-- the mark and the herd's approach (its probe tests the turrets by the mark: moved 60 tiles off, it tested none).
local function loop_point(w, j, scouting)
  local k = j % LOOP_POINTS
  local a = k * 2 * math.pi / LOOP_POINTS
  local p = to_box(w.center, w.hx + w.loop, w.hy + w.loop, a)
  if not scouting then return p end
  w.snap = w.snap or {}
  if w.snap[k] then return w.snap[k] end
  local s = game.surfaces[w.surface]
  if s and s.is_chunk_generated({math.floor(p.x / 32), math.floor(p.y / 32)}) then
    -- Out of every foe turret's reach too, pushed outward up to 60 tiles: on a ring laid out from its target's turrets
    -- alone, the corporations' outposts and pickets beside it shot 7 of 12 blind waves' scouts (2026-10-24).
    local ux, uy = p.x - w.center.x, p.y - w.center.y
    local ul = math.max(1, math.sqrt(ux * ux + uy * uy))
    for out = 0, 60, 10 do
      local q0 = {x = p.x + ux / ul * out, y = p.y + uy / ul * out}
      if s.count_entities_filtered{position = q0, radius = LOOP_CLEAR, type = TURRETS, force = hostiles(), limit = 1} == 0 then
        p = q0
        break
      end
    end
    local q = s.find_non_colliding_position(w.scout and w.scout.valid and w.scout.name or "small-biter", p, 12, 1)
    if q then w.snap[k] = {x = q.x, y = q.y}; return w.snap[k] end
  end
  return p
end
-- The base's edge (its turrets' box) toward pos.
local function face_toward(w, pos)
  return to_box(w.center, w.hx, w.hy, math.atan2(pos.y - w.center.y, pos.x - w.center.x))
end

local function go(dest, distraction, radius)
  return {type = defines.command.go_to_location, destination = dest, radius = radius or 3,
    distraction = distraction or defines.distraction.none}
end

local function compound(cmds)
  return {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = cmds}
end

local function alive(w)
  local n = 0
  for _, u in ipairs(w.members) do if u.valid then n = n + 1 end end
  return n
end

-- Where the herd is: the middle of its living members (a group's position is not where they stand: a push 15 tiles on
-- from it completed in 20 ticks).
local function where(w)
  local x, y, n = 0, 0, 0
  for _, u in ipairs(w.members) do
    if u.valid and u ~= w.scout then x, y, n = x + u.position.x, y + u.position.y, n + 1 end
  end
  if n == 0 then return w.group and w.group.valid and w.group.position or w.center end
  return {x = x / n, y = y / n}
end

-- Its eyes inside: the member deepest in, nearest the middle (the middle of forty still filing through a two-piece gap
-- stood outside the wall, and saw nothing 28 tiles from the power: third herd run).
local function front(w)
  local best, bd
  for _, u in ipairs(w.members) do
    if u.valid and u ~= w.scout then
      local d = d2(u.position, w.center)
      if not bd or d < bd then best, bd = u, d end
    end
  end
  return best and best.position or where(w)
end

local function memory_key(c) return string.format("%d,%d", math.floor(c.x / 32), math.floor(c.y / 32)) end

-- The ground between incubator and target: ground.lua (a unit cannot path through chunks never generated).
local function corridor(s, a, b) return ground.corridor(s, a, b) end
local function generated(s, chunks) return ground.missing(s, chunks) == 0 end

-- A wave from pen p at what drew it (target: a position). opts.units: the units it takes (a farm's, scripts/farm.lua);
-- the pen's stock if none; opts.sight: its biters' sight (0, the blind control).
function herd.launch(p, target, opts)
  opts = opts or {}
  local s = p.pen.surface
  local units = opts.units or stock(p)
  if #units < 2 then return end
  local forces = opts.forces or players()
  local c, hx, hy = base_box(s, target, forces)
  local h = st()
  local mem = p.memory[memory_key(c)] or {extra = 0}
  p.memory[memory_key(c)] = mem
  local w = {id = h.next, pen = p.pen.unit_number, surface = s.index, center = c, hx = hx, hy = hy, foes = opts.forces,
    no_probe = opts.no_probe,
    loop = LOOP_OUT + mem.extra, stage = "scout", t = game.tick, t0 = game.tick, members = {}, seen = {},
    marks = {}, kills = {}, tried = {}, sight = opts.sight or SIGHT, size = #units}
  h.next = h.next + 1
  for _, u in ipairs(units) do
    if u.valid then
      if u.commandable and u.commandable.spawner then u.commandable.release_from_spawner() end
      table.insert(w.members, u)
    end
  end
  if not opts.units then p.stock = {} end
  -- The scout: one of its own breed, made at the pen (biotech.lua: fast, frail, pale bands, lit at night), the wave's
  -- strength untouched; where none can stand there, the herd's one nearest the base.
  local sq = s.find_non_colliding_position("lp-bred-scout", p.pen.position, 12, 0.5)
  local scout = sq and s.create_entity{name = "lp-bred-scout", position = sq, force = B.force}
  if scout then
    rendering.draw_light{sprite = "utility/light_small", surface = s, target = scout, color = {0.45, 0.95, 1},
      scale = 1.4, intensity = 0.9, minimum_darkness = 0.3}
    w.scout = scout
  else
    local best, bd
    for _, u in ipairs(w.members) do
      local d = d2(u.position, c)
      if not bd or d < bd then best, bd = u, d end
    end
    w.scout = best
  end
  -- The loop: entered at the point nearest the pen, walked whole, a pause at every fourth point.
  local entry, ed
  for j = 0, LOOP_POINTS - 1 do
    local d = d2(loop_point(w, j), p.pen.position)
    if not ed or d < ed then entry, ed = j, d end
  end
  w.entry = entry
  w.farm = opts.farm
  w.gen = corridor(s, p.pen.position, c)
  -- By the engine's route, not straight legs (a leg's waypoint across a lake had no path); its track becomes the
  -- approach the herd marches (w.crumbs, step).
  w.approach, w.crumbs = {}, {xy(w.scout.position)}
  -- To its loop round every foe's turrets, not only its target's (the corporations' route, ops.route, wired by
  -- control.lua): on the engine's way its scouts were shot passing the corporations' camps and outposts, 100 to 300
  -- tiles from what they scouted, and 14 of 19 waves came blind (the system sim, 0.2.9).
  local cmds = {}
  if herd.route then
    local e = loop_point(w, entry, true)
    local way = herd.route({surface = s.index, force = B.force}, {w.scout.position.x, w.scout.position.y}, {e.x, e.y},
      {turrets = true, nests = false})
    for _, q in ipairs(way or {}) do table.insert(cmds, go({x = q[1], y = q[2]}, defines.distraction.none, 6)) end
  end
  table.insert(cmds, go(loop_point(w, entry, true), defines.distraction.none, 6))
  for k = 0, LOOP_POINTS do
    table.insert(cmds, go(loop_point(w, entry + k, true)))
    if k % STOP_EVERY == 0 and k < LOOP_POINTS then
      table.insert(cmds, {type = defines.command.stop, ticks_to_wait = STOP_TICKS, distraction = defines.distraction.none})
    end
  end
  -- Sent once its corridor is generated (step), at most GEN_WAIT on.
  w.scout_cmds = cmds
  mark_unit(w, w.scout, true)
  h.waves[w.id] = w
  local by = {}
  for _, u in ipairs(w.members) do if u.valid then local n = u.name:gsub("^lp%-bred%-", ""); by[n] = (by[n] or 0) + 1 end end
  local parts = {}
  for n, k in pairs(by) do parts[#parts + 1] = k .. " " .. n end
  table.sort(parts)
  log(w, string.format("%d bred from pen %d (%s); scout loops %.0f outside the turrets' box round %.0f,%.0f (%.0f by %.0f)",
    #w.members, w.pen, table.concat(parts, ", "), w.loop, c.x, c.y, 2 * hx, 2 * hy))
  return w.id
end

local function herd_units(w)
  local out = {}
  -- Its own only: an unfed incubator's stock goes feral (farm.lua), and a feral biter in a wave's list is the wild's
  -- (add_member to its group raised an error).
  -- One its incubator took back while it waited (11 to 19 of every wave stayed behind in the pen, never in the group):
  -- released again.
  for _, u in ipairs(w.members) do
    if u.valid and u ~= w.scout and u.force.name == B.force then
      if u.commandable and u.commandable.spawner then u.commandable.release_from_spawner() end
      table.insert(out, u)
    end
  end
  return out
end

local function gate(w)
  local p = st().pens[w.pen]
  local pp = p and p.pen.valid and p.pen.position or w.trail and w.trail[1] or w.center
  local e = w.approach and w.approach[1] or loop_point(w, w.entry)
  local len = math.sqrt(d2(pp, e))
  return {x = pp.x + (e.x - pp.x) * 8 / math.max(len, 1), y = pp.y + (e.y - pp.y) * 8 / math.max(len, 1)}
end

local function gather(w, next_stage)
  local s = game.surfaces[w.surface]
  local g = s.create_unit_group{position = gate(w), force = B.force}
  for _, u in ipairs(herd_units(w)) do g.add_member(u) end
  w.group = g
  w.stage = "gather"
  w.after_gather = next_stage
  w.t = game.tick
end

-- The scout's report: the face it saw fewest turrets at (of eight), nearest the pen on a tie; of the faces it saw. A face
-- it never had in sight counted none and read weakest: on seed 1 it went for an east face of seven turrets it had not
-- seen, over the south face's one (system sim, 2026-10-24).
local function choose_mark(w)
  local count = {}
  for k = 0, 7 do count[k] = 0 end
  for _, sector in pairs(w.seen) do count[sector] = count[sector] + 1 end
  -- A face that held before weighs as better gunned than it looks.
  local l = lessons()[lesson_key(w.center)]
  w.held_seen = {}
  for k = 0, 7 do
    local f = l and l.faces[k]
    if f and f.tried > f.broke then
      count[k] = count[k] + HELD_PENALTY * (f.tried - f.broke)
      w.held_seen[#w.held_seen + 1] = k
    end
  end
  local any = w.watched and next(w.watched) ~= nil
  local best, bc, bsteps
  for k = 0, 7 do
    if any and not w.watched[k] then goto continue end
    local j = k * LOOP_POINTS / 8
    local steps = math.min((j - w.entry) % LOOP_POINTS, (w.entry - j) % LOOP_POINTS)
    if not bc or count[k] < bc or (count[k] == bc and steps < bsteps) then best, bc, bsteps = k, count[k], steps end
    ::continue::
  end
  return best * LOOP_POINTS / 8, count
end

-- The loop's points from the entry to j, the shorter way round.
local function arc(w, j)
  local fwd = (j - w.entry) % LOOP_POINTS
  local back = (w.entry - j) % LOOP_POINTS
  local out = {}
  if fwd <= back then
    for k = 0, fwd do table.insert(out, loop_point(w, w.entry + k)) end
  else
    for k = 0, back do table.insert(out, loop_point(w, w.entry - k)) end
  end
  return out
end

-- The probe (the waves consult; the runt, tier 2 of the breeds consult): from evolution PROBE_EVO, once the mark is
-- chosen, PROBE_N runts walk the trail ahead of the herd and throw themselves at the marked face. The herd reads only
-- whether each turret there shot at them (on_entity_damaged, the turret the cause): a turret that had a runt in its
-- reach and stayed silent is dry, dark or broken, and the herd goes in in front of it. Kept for this wave only.
local PROBE_EVO, PROBE_N, PROBE_WAIT = 0.45, 8, 3 * 3600
herd.PROBE_EVO, herd.PROBE_N = PROBE_EVO, PROBE_N

local function probe_point(w)
  local m, c = w.mark, w.center
  local len = math.sqrt(d2(m, c))
  local k = math.max(0, w.loop - 4) / math.max(len, 1)
  return {x = m.x + (c.x - m.x) * k, y = m.y + (c.y - m.y) * k}
end

local function probe(w)
  if w.no_probe then return end
  local s = game.surfaces[w.surface]
  local f = force()
  if not f or f.get_evolution_factor(s) < PROBE_EVO then return end
  local at = gate(w)
  local g = s.create_unit_group{position = at, force = B.force}
  local units = {}
  for _ = 1, PROBE_N do
    local q = s.find_non_colliding_position("lp-runt", at, 12, 0.5)
    local u = q and s.create_entity{name = "lp-runt", position = q, force = B.force}
    if u then g.add_member(u); table.insert(units, u) end
  end
  if #units == 0 then g.destroy(); return end
  local face = probe_point(w)
  local cmds = {}
  for k = 2, #w.trail do table.insert(cmds, go(w.trail[k], defines.distraction.none, 6)) end
  table.insert(cmds, {type = defines.command.attack_area, destination = face, radius = 14,
    distraction = defines.distraction.by_enemy})
  g.set_command(compound(cmds))
  local turrets = {}
  for _, t in ipairs(s.find_entities_filtered{position = face, radius = 40, type = TURRETS, force = foes(w)}) do
    local ap = t.prototype.attack_parameters
    turrets[t.unit_number] = {entity = t, range = ap and ap.range or 18, reach = false, fired = false}
  end
  w.probe = {group = g, units = units, turrets = turrets, face = face, t = game.tick}
  log(w, string.format("probe: %d runts at the face %.0f,%.0f (%d turrets near)", #units, face.x, face.y,
    table_size(turrets)))
end

-- Which turrets had a runt in reach, a second at a time while the probe lives.
local function probe_watch(w)
  local p = w.probe
  if not p or p.done then return end
  local live = 0
  for _, u in ipairs(p.units) do
    if u.valid then
      live = live + 1
      for _, t in pairs(p.turrets) do
        if not t.reach and t.entity.valid and d2(u.position, t.entity.position) <= (t.range - 1) ^ 2 then t.reach = true end
      end
    end
  end
  p.live = live
end

-- The probe's answer: the silent turret nearest the mark, if any, becomes where the herd goes in.
local function probe_read(w)
  local p = w.probe
  if not p or p.done then return end
  probe_watch(w)
  p.done = true
  local fired, silent, best, bd = 0, 0, nil, nil
  for _, t in pairs(p.turrets) do
    if t.fired then fired = fired + 1
    elseif t.reach and t.entity.valid then
      silent = silent + 1
      local d = d2(t.entity.position, w.mark)
      if not bd or d < bd then best, bd = t.entity, d end
    end
  end
  p.result = {fired = fired, silent = silent}
  if best then
    local a = math.atan2(best.position.y - w.center.y, best.position.x - w.center.x)
    w.mark = to_box(w.center, w.hx + w.loop, w.hy + w.loop, a)
    p.result.moved_to = {best.position.x, best.position.y}
    log(w, string.format("probe: %d fired, %d silent: the herd goes in at the silent %s at %.0f,%.0f", fired, silent,
      best.name, best.position.x, best.position.y))
  else
    log(w, string.format("probe: %d fired, none silent: the mark stands", fired))
  end
end

function herd.on_probe_hit(e)
  local c = e.cause
  if not (c and c.valid and c.unit_number) then return end
  for _, w in pairs(st().waves) do
    local p = w.probe
    if p and not p.done then
      local t = p.turrets[c.unit_number]
      if t then t.fired = true; return end
    end
  end
end

local function mark(w)
  local j, count = choose_mark(w)
  w.mark = loop_point(w, j)
  w.mark_index = j
  w.mark_sector = math.floor(j * 8 / LOOP_POINTS + 0.5) % 8
  local parts = {}
  for k = 0, 7 do table.insert(parts, count[k]) end
  local p = st().pens[w.pen]
  local trail = {p and p.pen.valid and xy(p.pen.position) or w.mark}
  for _, q in ipairs(w.approach or {}) do table.insert(trail, q) end
  for _, q in ipairs(arc(w, j)) do table.insert(trail, q) end
  w.trail = trail
  lay_trail(game.surfaces[w.surface], trail)
  -- It walks to the mark the same way and sits there, facing the wall.
  if w.scout and w.scout.valid then
    local cmds = {}
    for _, q in ipairs(arc(w, j)) do table.insert(cmds, go(q)) end
    table.insert(cmds, {type = defines.command.stop, ticks_to_wait = SIT_TICKS, distraction = defines.distraction.none})
    -- From where it stands (the loop's end is the entry).
    w.scout.commandable.set_command(compound(cmds))
  end
  w.t_mark = game.tick
  local seen_faces = {}
  for k = 0, 7 do seen_faces[#seen_faces + 1] = (w.watched and w.watched[k]) and "y" or "-" end
  log(w, string.format("scout's turrets by face (E, SE, S, SW, W, NW, N, NE from the middle) %s (faces seen %s); mark at %.0f,%.0f",
    table.concat(parts, " "), table.concat(seen_faces), w.mark.x, w.mark.y))
  probe(w)
  gather(w, "march")
end

local function blind(w)
  w.blind = true
  log(w, "no whole loop from its scout: the wave comes blind" .. (w.scout_died_at and string.format(" (its scout killed by %s at %.0f,%.0f, %.0f from the turrets' middle)",
    w.scout_killer or "?", w.scout_died_at.x, w.scout_died_at.y, math.sqrt(d2(w.scout_died_at, w.center)))
    or (w.scout and w.scout.valid and " (its scout alive)") or " (its scout gone without dying: taken off the map)"))
  local p = st().pens[w.pen]
  if p then
    local m = p.memory[memory_key(w.center)] or {extra = 0}
    m.extra = m.extra + SCOUT_EXTRA
    p.memory[memory_key(w.center)] = m
  end
  if w.scout_died_at then
    rendering.draw_sprite{sprite = "virtual-signal/signal-skull", surface = w.surface, target = w.scout_died_at,
      x_scale = 1.2, y_scale = 1.2, render_mode = "chart", tint = B.color, time_to_live = TRAIL_TICKS}
  end
  gather(w, "blind")
end

-- On the move it fights nothing: a herd forty wide spills into turret reach along the loop, and fighting back there
-- (distraction by damage) drew it on to the faces it was going round (the first herd run: ten turrets taken on the way,
-- the herd dead before its mark).
local function march(w)
  -- Every one of its own in the group (at the gather a quarter of a wave of 120 was not, and stayed at the gate).
  local strays = 0
  for _, u in ipairs(herd_units(w)) do
    if u.commandable.parent_group ~= w.group then w.group.add_member(u); strays = strays + 1 end
  end
  if strays > 0 then log(w, string.format("%d strays called into the herd", strays)) end
  -- Leg by leg along its trail (step goes on at each leg's end; a group formed again goes on from the leg it was on):
  -- its whole trail as one compound order failed 40 ticks after it was given on most waves of the system sim, and the
  -- herd went straight at its mark from 900 tiles off, its trail unwalked (2026-10-25).
  w.leg = w.leg or 2
  w.stage = "march"
  w.t = game.tick
  w.group.set_command(go(w.trail[math.min(w.leg, #w.trail)], defines.distraction.none, 6))
  if not w.marched then
    w.marched = true
    mark_unit(w, herd_units(w)[1], true)
    log(w, string.format("herd of %d marches", #herd_units(w)))
  end
end

local function blind_attack(w)
  local p = st().pens[w.pen]
  local from = p and p.pen.valid and p.pen.position or w.center
  local face = face_toward(w, from)
  -- Along the scout's track as far as it got (one long attack_area across unreached ground failed at once).
  local cmds = {}
  for _, q in ipairs(w.approach or {}) do table.insert(cmds, go(q, defines.distraction.none, 6)) end
  table.insert(cmds, {type = defines.command.attack_area, destination = face, radius = 16})
  table.insert(cmds, {type = defines.command.attack_area, destination = w.center, radius = math.max(w.hx, w.hy) + 10})
  w.group.set_command(compound(cmds))
  w.stage = "blind"
  w.t = game.tick
  w.trail = {from, face}
  mark_unit(w, herd_units(w)[1], true)
end

-- Where the line from the mark to the middle meets the wall: the two pieces there, then INSIDE tiles in.
local function breach(w)
  local s = game.surfaces[w.surface]
  local forces = foes(w)
  local m, c = w.mark, w.center
  local len = math.sqrt(d2(m, c))
  local ux, uy = (c.x - m.x) / math.max(len, 1), (c.y - m.y) / math.max(len, 1)
  local hit
  for k = 0, math.floor(len) do
    local q = {x = m.x + ux * k, y = m.y + uy * k}
    if s.count_entities_filtered{position = q, radius = 1.5, type = WALLS, force = forces, limit = 1} > 0 then hit = q; break end
  end
  local cmds = {}
  local h = hit or face_toward(w, m)
  if hit then
    local ws = s.find_entities_filtered{position = hit, radius = 3, type = WALLS, force = forces}
    table.sort(ws, function(a, b) return d2(a.position, hit) < d2(b.position, hit) end)
    for i = 1, math.min(2, #ws) do
      table.insert(cmds, {type = defines.command.attack, target = ws[i], distraction = defines.distraction.none})
    end
  end
  local depth = math.min(INSIDE, math.sqrt(d2(h, c)))
  w.breach = h
  w.walled = hit and #cmds or 0
  w.inside = {x = h.x + ux * depth, y = h.y + uy * depth}
  table.insert(cmds, go(w.inside, defines.distraction.none, 4))
  w.group.set_command(compound(cmds))
  w.stage = "breach"
  w.t = game.tick
  w.t_breach = game.tick
  log(w, string.format("breach at %.0f,%.0f (%s)", h.x, h.y, hit and (#cmds - 1) .. " wall pieces" or "no wall"))
end

-- What feeds the guns, the first in sight of the herd.
local function supply_target(w)
  local s = game.surfaces[w.surface]
  local forces = foes(w)
  local at = front(w)
  local best, bd
  local function consider(e)
    if e.valid and not w.tried[e.unit_number or 0]
      and s.count_entities_filtered{position = e.position, radius = GUARD_RANGE, type = TURRETS, force = forces,
        limit = GUARDED} < GUARDED then
      local d = d2(e.position, at)
      if not bd or d < bd then best, bd = e, d end
    end
  end
  for _, e in pairs(s.find_entities_filtered{position = at, radius = w.sight, type = POWER, force = forces}) do consider(e) end
  for _, e in pairs(s.find_entities_filtered{position = at, radius = w.sight, type = "inserter", force = forces}) do
    if s.count_entities_filtered{position = e.drop_position, type = "ammo-turret", force = forces, limit = 1} > 0 then
      consider(e)
    end
  end
  for _, ft in pairs(s.find_entities_filtered{position = at, radius = w.sight, type = "fluid-turret", force = forces}) do
    for _, e in pairs(s.find_entities_filtered{position = ft.position, radius = 3, type = PIPES, force = forces}) do consider(e) end
  end
  if best then return best end
  -- The supply cut, the guns it silenced: laser turrets on a network with no power source left, the nearest (cut off,
  -- such a turret shoots only what its own charge holds, and goes dark). It cut a base's power and went home with 55 of
  -- 59 while the lasers it had cut off stood (system 4242, 2026-10-24): cut the supply, then use it.
  local fed = {}
  for _, p in pairs(s.find_entities_filtered{position = at, radius = 4 * w.sight, type = POWER, force = forces}) do
    if p.valid and p.electric_network_id then fed[p.electric_network_id] = true end
  end
  -- (Across the base, not its sight: from the middle, where the power stood, the lasers on the wall were out of it.)
  for _, e in pairs(s.find_entities_filtered{position = at, radius = math.max(w.sight, w.hx + w.hy), type = "electric-turret",
    force = forces}) do
    if e.valid and not w.tried[e.unit_number or 0] and not (e.electric_network_id and fed[e.electric_network_id]) then
      local d = d2(e.position, at)
      if not bd or d < bd then best, bd = e, d end
    end
  end
  return best
end

local withdraw, home_leg

-- Its spitters (the breeds consult, tier 1): once the herd is inside they leave it and hold the breach, spitting at
-- whatever comes at the gap (a sally into the herd's back walks into puddles); when it withdraws they stay COVER_TICKS,
-- then follow it home down the trail.
local COVER_TICKS = 20 * 60
local function is_spitter(u) return u.valid and u.name:find("spitter", 1, true) ~= nil end

local function hold_breach(w)
  if not w.breach or w.holding then return end
  w.holding = true
  local n = 0
  for _, u in ipairs(w.members) do
    if is_spitter(u) then
      -- A command of its own takes a unit out of its group (there is no release in 2.0's commandable).
      u.commandable.set_command{type = defines.command.attack_area, destination = w.breach, radius = 10,
        distraction = defines.distraction.by_enemy}
      n = n + 1
      if u.commandable.parent_group then w.still_grouped = (w.still_grouped or 0) + 1 end
    end
  end
  if n > 0 then log(w, string.format("%d spitters hold the breach (%d still in the group)", n, w.still_grouped or 0)) end
end

-- A rearguard of its own (a group: the spitters sent home one by one lined up 40 tiles out and stood there).
local function cover(w)
  if not w.holding or not w.breach then return end
  local s = game.surfaces[w.surface]
  local rear
  local n = 0
  for _, u in ipairs(w.members) do
    if u.valid and u.force.name == B.force and is_spitter(u) and not u.commandable.parent_group then
      rear = rear or s.create_unit_group{position = u.position, force = B.force}
      rear.add_member(u)
      n = n + 1
    end
  end
  if not rear then return end
  local cmds = {{type = defines.command.stop, ticks_to_wait = COVER_TICKS, distraction = defines.distraction.by_enemy}}
  for k = #w.trail, 1, -1 do table.insert(cmds, go(w.trail[k], defines.distraction.none, 6)) end
  rear.set_command(compound(cmds))
  st().rears = st().rears or {}
  st().rears[rear.unique_id] = rear
  log(w, string.format("%d spitters cover the withdrawal", n))
end

local function hunt(w)
  if not (w.group and w.group.valid) then return end
  -- What became of its last target (a run counted none of the player's buildings lost to its waves).
  if w.target_name then
    log(w, string.format("its %s %s", w.target_name, (w.target and w.target.valid) and "still stands" or "is down"))
    w.target_name = nil
  end
  hold_breach(w)
  local t = supply_target(w)
  if not t and not w.pushed then
    -- Nothing in sight: on to the middle, once (in at a corner of a 74-tile base, its lead saw the power in the middle at
    -- 43, then at 40.5, past its sight of 40: herd runs 2 to 4).
    w.pushed = true
    w.group.set_command(go(w.center, defines.distraction.none, 6))
    log(w, "nothing in sight: pushes in")
    return
  end
  if not t then
    withdraw(w, "nothing in sight feeds a gun")
    return
  end
  w.target, w.target_name = t, t.name
  w.tried[t.unit_number or 0] = true
  w.group.set_command{type = defines.command.attack, target = t, distraction = defines.distraction.none}
  log(w, string.format("goes for %s at %.0f,%.0f", t.name, t.position.x, t.position.y))
end

home_leg = function(w)
  w.group.set_command(go(w.home[math.min(w.home_leg, #w.home)], defines.distraction.none, 6))
end

withdraw = function(w, why)
  if w.stage == "withdraw" or w.stage == "done" then return end
  local g = w.group
  if not (g and g.valid) then return end
  -- (Its own only: a scout from an unfed incubator goes feral, the wild's, and add_member raised an error.)
  if w.scout and w.scout.valid and w.scout.force.name == B.force then g.add_member(w.scout) end
  -- Out as it came, fighting nothing (fighting back on the way home drew it on to the faces it passed: second run), leg by
  -- leg as it marched (as one compound order it failed at once, and the herd stood at the wall it had broken, counted
  -- home: the next wave's strays, 2026-10-25).
  w.home = {}
  if w.breach then table.insert(w.home, w.breach) end
  for k = #w.trail, 1, -1 do table.insert(w.home, w.trail[k]) end
  w.home_leg = 1
  cover(w)
  w.stage = "withdraw"
  w.t_withdraw = game.tick
  w.t = game.tick
  w.why = why
  home_leg(w)
  log(w, string.format("withdraws (%s); %d of %d left", why, alive(w), w.size))
end

local function finish(w, outcome)
  clear_marks(w)
  local h = st()
  local p = h.pens[w.pen]
  if p then for _, u in ipairs(w.members) do if u.valid then table.insert(p.stock, u) end end end
  if w.group and w.group.valid then w.group.destroy() end
  w.stage = "done"
  table.insert(h.log, {id = w.id, outcome = outcome, blind = w.blind or false, size = w.size, left = alive(w),
    kills = w.kills, loop = w.loop, mark = w.mark and {w.mark.x, w.mark.y}, scout_seen = w.scout_seen,
    t_launch = w.t0, t_mark = w.t_mark, t_march = w.t_march, t_breach = w.t_breach, t_inside = w.t_inside,
    t_first_kill = w.t_first_kill, t_withdraw = w.t_withdraw, t_end = game.tick, center = {w.center.x, w.center.y},
    trail = w.trail, farm = w.farm, recalled = w.recalled, probe = w.probe and w.probe.result,
    breach = w.breach and {w.breach.x, w.breach.y}, legs = w.leg, legs_failed = w.legs_failed or 0,
    home_legs = w.home_leg, home_n = w.home and #w.home})
  h.waves[w.id] = nil
  log(w, string.format("%s; %d of %d home", outcome, alive(w), w.size))
  -- Its lesson: the face it tried and whether it broke anything past the wall there; what killed its units round it.
  -- (Its personality: B.mind.learns; off, it keeps none, which is how the system sim measures what learning is worth.)
  if w.mark_sector and not w.blind and B.mind.learns ~= false and not storage.biotech_unlearned then
    local key = lesson_key(w.center)
    local l = lessons()[key] or {faces = {}, killers = {}, waves = 0}
    lessons()[key] = l
    l.waves = l.waves + 1
    local f = l.faces[w.mark_sector] or {tried = 0, broke = 0}
    l.faces[w.mark_sector] = f
    f.tried = f.tried + 1
    local broke = 0
    for name, n in pairs(w.kills or {}) do
      local proto = prototypes.entity[name]
      if not (proto and (proto.type == "wall" or proto.type == "gate")) then broke = broke + n end
    end
    if broke > 0 then f.broke = f.broke + 1 end
    -- A wall in its way at the breach, and nothing broken past it: what its incubators breed for the next wave there
    -- (farm.lua's order: bursters).
    if (w.walled or 0) > 0 then l.walled = (l.walled or 0) + 1 end
    if (w.walled or 0) > 0 and broke == 0 and w.why ~= "nothing in sight feeds a gun" then l.walled_held = (l.walled_held or 0) + 1 end
    -- Nothing there to break (in, and nothing in sight fed a gun) is not a defence that held: not a trial of the face (a
    -- turret left of a base drew waves of 120 that each walked in and home, counted held, and escalated: 2026-10-25).
    if broke == 0 and w.why == "nothing in sight feeds a gun" then f.tried = f.tried - 1; l.waves = l.waves - 1 end
    local r = w.hx + w.hy + 60
    local killed = 0
    for _, loss in ipairs(know.losses("biotech", game.tick - (w.t0 or game.tick) + 60, function(x)
      return x.unit and x.killer and (x.pos[1] - w.center.x) ^ 2 + (x.pos[2] - w.center.y) ^ 2 <= r * r end)) do
      l.killers[loss.killer] = (l.killers[loss.killer] or 0) + 1
      killed = killed + 1
    end
    log(w, string.format("lesson: face %d %s (%d of %d broke there); %d of its own killed by %s", w.mark_sector,
      broke > 0 and "gave" or (w.why == "nothing in sight feeds a gun" and "had nothing to break") or "held", f.broke, f.tried,
      killed, serpent.line(l.killers)))
  end
end

local function step(w, tick)
  local s = game.surfaces[w.surface]
  if not s then return finish(w, "lost") end
  if w.stage == "scout" then
    local sc = w.scout
    if not (sc and sc.valid) then return blind(w) end
    if tick % 30 == 0 then
      -- The faces it has seen: the sector it stands in, while on its loop's ring (within the loop's distance and 15 of
      -- the turrets' box). Judged by a face's middle point, a loop 39 out passed the east face of seed 777 between two
      -- looks, and its single gun was never weighed (2026-10-25).
      w.watched = w.watched or {}
      local dx, dy = sc.position.x - w.center.x, sc.position.y - w.center.y
      if math.abs(dx) <= w.hx + w.loop + 15 and math.abs(dy) <= w.hy + w.loop + 15 then
        local k = math.floor(math.atan2(dy, dx) / (math.pi / 4) + 0.5) % 8
        w.watched[k] = true
      end
      for _, t in pairs(s.find_entities_filtered{position = sc.position, radius = w.sight, force = foes(w), type = TURRETS}) do
        if not w.seen[t.unit_number] then
          local a = math.atan2(t.position.y - w.center.y, t.position.x - w.center.x)
          w.seen[t.unit_number] = math.floor(a / (math.pi / 4) + 0.5) % 8
        end
      end
    end
    if w.scout_cmds then
      -- Waiting for its corridor: the scout's clock starts when it sets out.
      if generated(s, w.gen) or tick - w.t > GEN_WAIT then
        sc.commandable.set_command(compound(w.scout_cmds))
        w.scout_cmds, w.t = nil, tick
      end
      return
    end
    -- Its track, every 60 tiles, until it reaches the loop: the herd's approach.
    if tick % 60 == 0 and not w.at_loop then
      local last = w.crumbs[#w.crumbs]
      if d2(sc.position, loop_point(w, w.entry, true)) < 15 * 15 then
        w.at_loop = true
      elseif d2(sc.position, last) >= 60 * 60 then
        table.insert(w.crumbs, xy(sc.position))
        w.approach = {}
        for k = 2, #w.crumbs do w.approach[#w.approach + 1] = w.crumbs[k] end
      end
    end
    if tick - w.t > SCOUT_TIMEOUT then mark(w) end
    return
  end
  if w.probe and not w.probe.done then
    probe_watch(w)
    if w.probe.live == 0 or tick - w.probe.t > PROBE_WAIT then probe_read(w) end
  end
  if alive(w) == 0 then return finish(w, "lost") end
  if w.stage == "gather" then
    if tick - w.t >= GATHER_TICKS then
      if w.after_gather == "blind" then blind_attack(w) else w.t_march = tick; march(w) end
    end
    return
  end
  if not (w.group and w.group.valid) then
    -- Its group gone with its members alive (a failed order disbands a group on 2.1): formed again where they stand and
    -- on with what it was doing, up to REGROUPS times; only then scattered.
    local live = herd_units(w)
    if #live >= 2 and (w.regroups or 0) < REGROUPS and (w.stage == "inside" or w.stage == "breach" or w.stage == "march"
      or w.stage == "blind" or (w.stage == "withdraw" and w.home)) then
      w.regroups = (w.regroups or 0) + 1
      w.group = s.create_unit_group{position = where(w), force = B.force}
      for _, u in ipairs(live) do if not u.commandable.parent_group then w.group.add_member(u) end end
      log(w, string.format("its group broke up with %d alive: formed again (%d of %d)", #live, w.regroups, REGROUPS))
      if w.stage == "march" then march(w) elseif w.stage == "blind" then blind_attack(w)
      elseif w.stage == "withdraw" then home_leg(w) else hunt(w) end
      return
    end
    return finish(w, "scattered")
  end
  if w.stage == "inside" or w.stage == "breach" or w.stage == "blind" then
    if alive(w) * 2 < w.size then return withdraw(w, "half lost") end
    if w.t_inside and tick - w.t_inside > INSIDE_TICKS then return withdraw(w, "time inside") end
  end
  -- A command that never completes (stuck): move on after a while.
  if w.stage == "withdraw" and tick - w.t > 10 * 3600 then return finish(w, "home late") end
end

function herd.tick(tick)
  local h = storage.herd
  if not h then return end
  for _, w in pairs(h.waves) do
    if w.stage == "scout" or tick % 60 == 0 then step(w, tick) end
  end
  if tick % 600 == 0 then
    lift_trails(tick)
    for id, p in pairs(h.pens) do if not p.pen.valid then h.pens[id] = nil end end
  end
  if tick % 3600 == 7 then
    -- Its breeds by the wild biters' evolution on each surface it holds pens on, where no culture holds them: a culture's
    -- evolution is its clinic's (farm.lua; this overwrote it every minute, the faction AI audit, 2026-10-23).
    local f, enemy = force(), game.forces.enemy
    if f and enemy then
      local cultured = {}
      for _, p in pairs(h.pens) do if p.pen.valid and p.farm then cultured[p.pen.surface.index] = true end end
      for _, p in pairs(h.pens) do
        if p.pen.valid and not cultured[p.pen.surface.index] then
          f.set_evolution_factor(enemy.get_evolution_factor(p.pen.surface), p.pen.surface)
        end
      end
    end
  end
end

function herd.on_command_completed(e)
  local h = storage.herd
  if not h then return end
  local rear = h.rears and h.rears[e.unit_number]
  if rear then
    h.rears[e.unit_number] = nil
    if rear.valid then rear.destroy() end
    return
  end
  for _, w in pairs(h.waves) do
    if w.stage == "scout" and w.scout and w.scout.valid and e.unit_number == w.scout.unit_number then
      w.scout_seen = 0
      for _ in pairs(w.seen) do w.scout_seen = w.scout_seen + 1 end
      log(w, string.format("scout's loop done (%s, result %d%s) at %.0f,%.0f, %d turrets seen",
        e.result == defines.behavior_result.success and "whole" or "cut short", e.result,
        e.was_distracted and ", distracted" or "", w.scout.position.x, w.scout.position.y, w.scout_seen))
      -- A leg it could not walk: the rest of the loop from the point after its nearest, the unwalkable one skipped, up to
      -- RESUMES times (one unreachable point failed the whole compound).
      if e.result ~= defines.behavior_result.success and (w.resumes or 0) < RESUMES and w.scout.valid then
        local near, nd = 0, nil
        for k = 0, LOOP_POINTS do
          local d = d2(w.scout.position, loop_point(w, w.entry + k, true))
          if not nd or d < nd then near, nd = k, d end
        end
        local cmds = {}
        for k = near + 2, LOOP_POINTS do table.insert(cmds, go(loop_point(w, w.entry + k, true))) end
        if #cmds == 0 then return mark(w) end
        w.resumes = (w.resumes or 0) + 1
        log(w, string.format("scout resumes its loop from point %d of %d (a leg it could not walk)", near + 2, LOOP_POINTS))
        w.scout.commandable.set_command(compound(cmds))
        return
      end
      -- Half a loop is not a report: faces it never saw would read as empty (a squad in its way cut one short, and the
      -- herd went for a face it had not seen). It comes blind, and the next loop there goes wider.
      if e.result ~= defines.behavior_result.success then return blind(w) end
      return mark(w)
    end
    if w.group and w.group.valid and e.unit_number == w.group.unique_id then
      if w.stage == "march" then
        if e.result ~= defines.behavior_result.success then
          w.legs_failed = (w.legs_failed or 0) + 1
          log(w, string.format("leg %d of %d of its trail failed (%s)", w.leg, #w.trail, tostring(e.result)))
        end
        w.leg = (w.leg or #w.trail) + 1
        if w.leg <= #w.trail then
          -- (A failed order disbands a group on 2.1: step forms it again and goes on from this leg.)
          if w.group.valid then march(w) end
          return
        end
        probe_read(w); return breach(w)
      end
      if w.stage == "breach" then
        w.stage = "inside"; w.t_inside = game.tick
        return hunt(w)
      end
      if w.stage == "inside" then return hunt(w) end
      if w.stage == "blind" then return withdraw(w, "blind wave spent") end
      if w.stage == "withdraw" then
        -- (A wave of an older save withdraws by one order: home at its end.)
        w.home_leg = (w.home_leg or 0) + 1
        if w.home and w.home_leg <= #w.home then
          if w.group.valid then home_leg(w) end
          return
        end
        return finish(w, "home")
      end
    end
  end
end

-- What its waves break: counted for the log (and the tests); the first kill (not a wall piece) timed.
function herd.on_died(e)
  local h = storage.herd
  if not h or not next(h.waves) then return end
  local ent = e.entity
  if e.force and e.force.name == B.force and shared.is_player_force(ent.force) then
    for _, w in pairs(h.waves) do
      if w.stage ~= "scout" then
        w.kills[ent.name] = (w.kills[ent.name] or 0) + 1
        if not w.t_first_kill and ent.type ~= "wall" and ent.type ~= "gate" then w.t_first_kill = game.tick end
      end
    end
  end
  for _, w in pairs(h.waves) do
    if w.scout == ent and w.stage == "scout" then
      w.scout_died_at = {x = ent.position.x, y = ent.position.y}
      w.scout_killer = (e.cause and e.cause.valid and e.cause.name) or (e.force and e.force.name) or "?"
    end
  end
end

-- A farm attacked calls its wave home (Fable's breeds consult: the raid on the farm is the counter to a wave on its way,
-- and the fight is on the trail, in the open).
function herd.recall(farm_id, why)
  for _, w in pairs(st().waves) do
    if w.farm == farm_id and w.stage ~= "withdraw" and w.stage ~= "done" then
      if w.stage == "scout" or w.stage == "gather" then
        if not (w.group and w.group.valid) then
          local s = game.surfaces[w.surface]
          w.group = s.create_unit_group{position = where(w), force = B.force}
          for _, u in ipairs(herd_units(w)) do w.group.add_member(u) end
        end
        w.trail = w.trail or {xy(st().pens[w.pen] and st().pens[w.pen].pen.valid and st().pens[w.pen].pen.position or w.center)}
      end
      w.recalled = true
      withdraw(w, why)
    end
  end
end

function herd.out(farm_id)
  for _, w in pairs(st().waves) do if w.farm == farm_id then return true end end
  return false
end

function herd.state()
  local h = st()
  local pens, waves = {}, {}
  for id, p in pairs(h.pens) do
    pens[#pens + 1] = {id = id, valid = p.pen.valid, owned = p.pen.valid and #p.pen.units or 0, stock = #p.stock,
      memory = p.memory}
  end
  for id, w in pairs(h.waves) do
    waves[#waves + 1] = {id = id, stage = w.stage, alive = alive(w), size = w.size, loop = w.loop,
      scout = w.scout and w.scout.valid and {w.scout.position.x, w.scout.position.y} or nil,
      group = w.group and w.group.valid and {w.group.position.x, w.group.position.y} or nil,
      mark = w.mark and {w.mark.x, w.mark.y}, trail = w.trail, breach = w.breach and {w.breach.x, w.breach.y},
      holding = w.holding or false}
  end
  local rears = {}
  for id, g in pairs(h.rears or {}) do
    if g.valid then
      table.insert(rears, {id = id, state = g.state, members = #g.members, pos = {g.position.x, g.position.y},
        cmd = g.command and g.command.type, sub = g.command and g.command.commands and #g.command.commands})
    else
      table.insert(rears, {id = id, valid = false})
    end
  end
  return {pens = pens, waves = waves, log = h.log, trails = #h.trails, rears = rears, grubstake_broken = h.grubstake_broken}
end

return herd
