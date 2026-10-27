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
local firemap = require("__landing-party__.scripts.firemap")
local valuemap = require("__landing-party__.scripts.valuemap")
local costmap = require("__landing-party__.scripts.costmap")
local shared = require("shared")
local herd = {}

local B = shared.BIOTECH
local SIGHT = 40            -- what a biter of the pack sees, scout or herd (tiles)
local LOOP_OUT = 29         -- the loop past the outermost turret: beyond a laser (24); a flamethrower (30) reaches it
local LOOP_POINTS = 16
local STOP_EVERY = 4        -- a pause at every fourth loop point: four faces
local LOOP_CLEAR = 30       -- a loop point this far from every foe turret (a gun turret's 18, a laser's 24, a margin)
local RESUMES = 3          -- a failed loop taken up again from the next point, at most this often
local REGROUPS = 3         -- a wave's group formed again from its living members, at most this often a leg (a wave of
                           -- the player's deathworld used its three on one long trail and scattered)
local STRAY_FAR = 60       -- a member this far from the herd is left behind, not called in
local STOP_TICKS = 600
local SIT_TICKS = 30 * 3600
local GATHER_TICKS = 90 * 60
local INSIDE = 15
local INSIDE_TICKS = 90 * 60     -- inside with nothing of its brought down this long, it goes home
local INSIDE_MAX = 4 * 3600      -- and inside this long at most, however it fares
-- Inside, each of its biters after its own target (the user, 2026-10-26: "smart biters would simply pour in and target
-- defenses/power"; then, the squads of 0.2.30 seen: "it could do better by turning biters into individuals once they
-- are past the breach. The squads gang up on a single target"): the nearest on the list with fewer than PER_TARGET on it
-- (BIG_TARGET for what is big), the list read once a look, every LOOK ticks.
local PER_TARGET, BIG_TARGET = 3, 8
local BIG = {reactor = true, ["fusion-generator"] = true, roboport = true, ["assembling-machine"] = false,
  ["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true}
local LOOK = 120
local PUSH_MAX = 60 * 60   -- a push in, at most, before it looks again
local CLEAR_MAX = 12        -- attack orders, at most, clearing the turrets off its way out
local DEAD_AT = 300         -- where its own died, at most this many kept (its record)
local HEART_REACH = 300     -- how far it reads the base round it for its hearts (valuemap), from its breach or inside
local WAY_REACH = 400       -- how far round its target it prices its way in at the least (costmap)
local WAY_MARGIN = 150      -- and past where it stands and its target, the box it prices them in
-- On the march, under fire (the user, 2026-10-26: a wave of 200 "walk alongside a wall while getting pummeled by turrets,
-- ignoring them because they weren't at the final staging point yet", pushed there by forests and cliffs): FIRE_LOSS of it
-- lost within FIRE_WINDOW with turrets within FIRE_NEAR, it breaks in where it stands.
local FIRE_LOSS, FIRE_WINDOW, FIRE_NEAR = 0.1, 15 * 60, 30
                                   -- that ran on through the guns cost it 19 on the march where it would have broken in)
-- What runs its defences besides their power and ammunition: what sees for them and mends them (the user: "radars and
-- roboports as targets"), after the supply, before the guns it silenced.
local CONTROL = {"radar", "roboport"}
-- The deep strike (the user, 2026-10-26: "some waves could, once a breach is made, simply rush in past the first line of
-- defenses towards the heart of the base"): at the breach it weighs its two plans, the edge (what it can break near the
-- breach, against the fire there) and the heart (what stands round the base's heart, against the fire there and on the
-- way), and goes for the heart when it is worth DEEP_MARGIN times the edge: a hard shell round a soft middle. A deep
-- strike that cost it half its number there halves the next one's worth (its lesson). Tells: its trail runs on into the
-- base, its leader marked.
local DEEP_MIN = 40           -- the heart this far past the breach at least, or there is no difference
local DEEP_MARGIN = 1.5        -- the heart worth this many times the edge, both priced by the cost map (2 when the heart
                               -- was priced by its guns and the edge by fire: 1.25 then, nearly every wave struck for it)
local DEEP_AGAIN = 0.5         -- the heart's worth, at a base where its last wave struck for it (so the strike surprises)
local TRAIL_TICKS = 20 * 3600
local BASE_REACH = 48       -- the turrets that make the defence a wave meets, round what drew it: those that can bear
                           -- on where it breaks in. At 120 a player's sprawling factory was one box of every turret in
                           -- 240 tiles, its scout's loop and the herd's trail ran through the factory, and a face could
                           -- be one no wave could reach (the user's deathworld, 2026-10-25: "treating bases as big
                           -- squares")
local OPEN_R, OPEN_MAX = 12, 2   -- a face's approach is in the open with at most this many foe buildings this near
local SCOUT_EXTRA = 10      -- a dead scout's lesson: the next loop round that base this much wider
local SCOUT_TIMEOUT = 5 * 3600
local GEN_WAIT = 2 * 3600      -- at most, for its corridor's chunks before the scout sets out
-- It does not bite under the guns: a target with this many of the player's turrets within a laser's reach of it is
-- passed over (forty bred took a power source under four lasers and three guns for eleven of them: the inner keep has
-- to be a counter the player can build, docs/biotech.md).
local TURRETS = {"ammo-turret", "electric-turret", "fluid-turret"}
local WALLS = {"wall", "gate"}
local POWER = {"generator", "solar-panel", "accumulator", "burner-generator", "electric-energy-interface", "reactor",
  "fusion-generator", "lightning-attractor"}
local PIPES = {"pipe", "pipe-to-ground", "pump"}
-- What it breaks inside when nothing in sight feeds a gun: what the factory runs on, the worthiest first (valuemap: it
-- chewed belts nearest first, 1,500 in sight at a factory's heart, and the assemblers stood; 2026-10-27).
local SOFT = {"mining-drill", "assembling-machine", "furnace", "lab", "boiler", "generator", "electric-pole", "inserter",
  "transport-belt", "underground-belt", "splitter", "pump", "offshore-pump", "storage-tank", "radar", "beacon", "roboport"}
-- What draws a wave: the player's machines and guns (pollution is what feeds it; these make it).
-- (With what it is worth from afar, valuemap, short of the many small ones, solar fields and poles, too many to read
-- 1,600 tiles round: a power plant, a silo, a roboport left at the edge is a soft heart too.)
herd.DRAW = {"ammo-turret", "electric-turret", "fluid-turret", "assembling-machine", "furnace", "mining-drill", "boiler",
  "generator", "lab", "reactor", "fusion-generator", "rocket-silo", "roboport", "radar", "beacon", "burner-generator",
  "electric-energy-interface"}

local function st()
  storage.herd = storage.herd or {pens = {}, waves = {}, next = 1, log = {}, trails = {}}
  return storage.herd
end

local function force() return game.forces[B.force] end

-- Its force: at peace with the wild biters both ways, and with Grubstake for good (the user, 2026-10-26: "a lasting truce
-- with Grubstake as they have a sort of symbiotic relationship, and are both going to come in at similar times": it grows
-- on the smoke Grubstake's mines and fabricators put out, and both live by the wild biters' leave); at war with everyone
-- else. Until 0.2.29 Grubstake by its creep or at its incubators broke the truce for good: a save where it had broken
-- gets it back here.
function herd.init()
  local f = game.forces[B.force] or game.create_force(B.force)
  f.custom_color = B.color
  local enemy = game.forces.enemy
  if enemy then f.set_cease_fire(enemy, true); enemy.set_cease_fire(f, true) end
  local g = game.forces[shared.CORPS.grubstake.force]
  if g then f.set_cease_fire(g, true); g.set_cease_fire(f, true) end
  st().grubstake_broken = nil
end

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
-- What a turret costs it, in its own, against a foe (firemap.affords, valuemap.keeps): learned from what its breaches
-- cost (its own lost breaking in, over the turrets covering the breach), PRICE_LEARN of each new one, from its mind's
-- per_turret before any (a guess of 6 let waves of 60 at a ring of guns whose gaps cost them half their number, and they
-- came home with nothing; 2026-10-27).
local PRICE_LEARN, PRICE_MIN, PRICE_MAX = 0.4, 1, 40
function herd.price(force_name)
  local k = know.of("biotech")
  local p = k.price and k.price[force_name or "player"]
  return p and p.per or B.mind.per_turret or firemap.AFFORD
end
local function price_of(w)
  local f = foes(w)[1]
  return herd.price(f and (type(f) == "string" and f or f.name) or "player")
end
local function learn_price(w)
  if not (w.breach_cover and w.breach_cover > 0) then return end
  local lost = 0
  for key, n in pairs(w.lost_by or {}) do if key:find("^breach ") then lost = lost + n end end
  local f = foes(w)[1]
  local name = f and (type(f) == "string" and f or f.name) or "player"
  local k = know.of("biotech")
  k.price = k.price or {}
  local p = k.price[name] or {per = B.mind.per_turret or firemap.AFFORD, n = 0}
  local sample = math.min(PRICE_MAX, math.max(PRICE_MIN, lost / w.breach_cover))
  p.per = p.per + (sample - p.per) * (p.n == 0 and 1 or PRICE_LEARN)
  p.n = p.n + 1
  k.price[name] = p
  w.price_learned = {sample = sample, per = p.per}
end

-- Dev and tests: a lesson that a wall held a wave at the base round pos.
function herd.debug_wall_lesson(pos)
  local key = lesson_key({x = pos.x or pos[1], y = pos.y or pos[2]})
  local l = lessons()[key] or {faces = {}, killers = {}, waves = 0}
  lessons()[key] = l
  l.walled_held = (l.walled_held or 0) + 1
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
  -- Nor a carrier or its escort (farm.lua: an incubator took a carrier back while it waited, and a wave set out with it).
  local carrying = storage.carrying or {}
  local function take(u)
    -- (Nor one in a group: a spitter of a rear guard still on its way home went back to the stock with its wave, and the
    -- next wave's group took it in mid-walk.)
    if u.valid and u.force.name == B.force and not seen[u.unit_number] and not carrying[u.unit_number]
      and u.name ~= "lp-bred-carrier" and not (u.commandable and u.commandable.parent_group) then
      seen[u.unit_number] = true
      table.insert(out, u)
    end
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
-- A spitter holding the breach: left out of the herd's group, to cover its withdrawal (inside, its biters on their own,
-- the group was made again at the withdrawal and took them in: 1 of 5 came home behind it).
local function holds(w, u) return w.holders ~= nil and w.holders[u.unit_number] == true end

-- (Not those holding the breach: their middle and the herd's at the heart lay 177 tiles back toward the wall, and it saw
-- nothing there, 2026-10-27.)
local function where(w)
  local x, y, n = 0, 0, 0
  for _, u in ipairs(w.members) do
    if u.valid and u ~= w.scout and not holds(w, u) then x, y, n = x + u.position.x, y + u.position.y, n + 1 end
  end
  if n == 0 then return w.group and w.group.valid and w.group.position or w.center end
  return {x = x / n, y = y / n}
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
  -- What its scouts learnt round this base: the nearest memory within two cells (a wave that broke half a base moved the
  -- next one's middle 25 tiles, into another cell, and its scout looped no wider where the last was killed).
  local mem = p.memory[memory_key(c)]
  if not mem then
    local bd
    for key, m in pairs(p.memory) do
      local mx, my = key:match("^(-?%d+),(-?%d+)$")
      local d = (tonumber(mx) * 32 + 16 - c.x) ^ 2 + (tonumber(my) * 32 + 16 - c.y) ^ 2
      if d <= 64 * 64 and (not bd or d < bd) then mem, bd = m, d end
    end
  end
  mem = mem or {extra = 0}
  p.memory[memory_key(c)] = mem
  local w = {id = h.next, pen = p.pen.unit_number, surface = s.index, center = c, hx = hx, hy = hy, foes = opts.forces,
    no_probe = opts.no_probe, force_deep = opts.deep, choice = opts.choice,
    loop = LOOP_OUT + mem.extra, stage = "scout", t = game.tick, t0 = game.tick, members = {}, seen = {},
    marks = {}, kills = {}, tried = {}, sight = opts.sight or SIGHT, size = #units, goal = xy(target)}
  h.next = h.next + 1
  -- Each once (a biter in two incubators' stock came twice: a wave of 41 counted 48, and a death of one of those took two
  -- off its number, so it turned back half lost with a third of it killed; a visit, 2026-10-27).
  local once = {}
  for _, u in ipairs(units) do
    if u.valid and not once[u.unit_number] then
      once[u.unit_number] = true
      if u.commandable and u.commandable.spawner then u.commandable.release_from_spawner() end
      table.insert(w.members, u)
    end
  end
  w.size = #w.members
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
    if u.valid and u ~= w.scout and u.force.name == B.force and not (w.sappers and w.sappers.set[u.unit_number])
      and not (w.left_behind and w.left_behind[u.unit_number]) then
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
  -- Where its cheapest way in breaks in (costmap), when it has one: the turrets there are the ones that matter.
  if w.way_in and w.way_in.breach then return {x = w.way_in.breach[1], y = w.way_in.breach[2]} end
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
  local turrets, near = {}, {}
  for _, t in ipairs(s.find_entities_filtered{position = face, radius = 40, type = TURRETS, force = foes(w)}) do
    local ap = t.prototype.attack_parameters
    turrets[t.unit_number] = {entity = t, range = ap and ap.range or 18, reach = false, fired = false}
    near[#near + 1] = t
  end
  -- Each runt at one of the turrets nearest the face, round them in turn: thrown at the face together they fought the
  -- first lasers that shot them, died there, and never came in reach of the dry gun beside them (herd probe, 2026-10-27).
  table.sort(near, function(a, b) return d2(a.position, face) < d2(b.position, face) end)
  g.destroy()
  for k, u in ipairs(units) do
    local cmds = {}
    for j = 2, #w.trail do table.insert(cmds, go(w.trail[j], defines.distraction.none, 6)) end
    local t = near[(k - 1) % math.max(1, math.min(#near, PROBE_N)) + 1]
    if t then table.insert(cmds, {type = defines.command.attack, target = t, distraction = defines.distraction.none})
    else table.insert(cmds, {type = defines.command.attack_area, destination = face, radius = 14,
      distraction = defines.distraction.by_enemy}) end
    u.commandable.set_command(compound(cmds))
  end
  g = nil
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
    -- Staged (its way in priced, costmap), it keeps its staging point and breaks in at the silent turret; else the mark
    -- moves to face it, out on the box (the box was its target's, deep inside a ring of guns, and the mark it moved to lay
    -- inside the ring: it "broke in" with no wall to break and lost 28 there; 2026-10-27).
    if w.staged then
      w.breach_at = {x = best.position.x, y = best.position.y}
    else
      local a = math.atan2(best.position.y - w.center.y, best.position.x - w.center.x)
      w.mark = to_box(w.center, w.hx + w.loop, w.hy + w.loop, a)
    end
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

-- What it knows of the base it goes at: every turret round it, by face (the user, 2026-10-25: "ground truth only + scout as
-- a non essential complement"). Its faces were the scout's sightings, and in four-faction runs 15 of 19 waves came blind:
-- their scouts killed by Kessler-Hayashi's tanks and outposts. The scout still loops the base before the wave, the tell
-- and the wave's clock; killed, the wave comes all the same.
-- Whether a point is open ground, not inside the foe's buildings (a face on a sprawling base can be in the factory).
local function open_ground(w, p)
  local s = game.surfaces[w.surface]
  return s.count_entities_filtered{position = p, radius = OPEN_R, force = foes(w), limit = OPEN_MAX + 1,
    type = {"wall", "gate", "assembling-machine", "furnace", "mining-drill", "inserter", "transport-belt", "electric-pole",
      "container", "logistic-container", "pipe", "lab", "roboport", "solar-panel", "accumulator", "boiler", "generator",
      "radar", "ammo-turret", "electric-turret", "fluid-turret", "rocket-silo", "beacon", "storage-tank"}} <= OPEN_MAX
end

local function read_ground(w)
  local s = game.surfaces[w.surface]
  local r = w.loop
  w.seen, w.watched = {}, {}
  -- The faces a wave can come at: those whose approach is open ground (all of them if none is).
  for k = 0, 7 do
    if open_ground(w, loop_point(w, k * LOOP_POINTS / 8)) then w.watched[k] = true end
  end
  if not next(w.watched) then for k = 0, 7 do w.watched[k] = true end end
  for _, t in pairs(s.find_entities_filtered{area = {{w.center.x - w.hx - r, w.center.y - w.hy - r},
    {w.center.x + w.hx + r, w.center.y + w.hy + r}}, force = foes(w), type = TURRETS}) do
    local a = math.atan2(t.position.y - w.center.y, t.position.x - w.center.x)
    w.seen[t.unit_number] = math.floor(a / (math.pi / 4) + 0.5) % 8
  end
end

-- Its scout killed: a skull where it fell, and the next scout round that base loops wider (flavour; the wave comes).
local function scout_lost(w)
  if w.scout_lost then return end
  w.scout_lost = true
  log(w, w.scout_died_at and string.format("its scout killed by %s at %.0f,%.0f, %.0f from the turrets' middle; the wave comes all the same",
    w.scout_killer or "?", w.scout_died_at.x, w.scout_died_at.y, math.sqrt(d2(w.scout_died_at, w.center)))
    or "its scout gone; the wave comes all the same")
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
end

-- Its approach, as the corporations' raids stage (the user, 2026-10-25: "the other factions already have some code that
-- could be reused"): for each of eight directions out from its target a staging point beyond every turret's reach,
-- outside the player's walls and off water (routing.outside), the approach weighed by the fire on the line from it in
-- (ops.exposure, every STAGE_STEP tiles: the hottest point), what its lessons say of that face, and the walk from its
-- incubator. The weakest it can reach is its mark; the herd is routed there round turrets (ops.route), and breaks in
-- straight from it. A sprawling factory read as one box round every turret in 240 tiles had sent its herd round half
-- the factory to a face no wave could reach (the user's deathworld).
local STAGE_OFF, STAGE_LEN, STAGE_STEP = 34, 200, 8
-- A herd's half-width (the user, 2026-10-26: staging "a little further from turrets, to account for the waist of the wave
-- when it has a lot of biters"): its units packed a tile and a fifth apart, the radius of their disc. Its staging point and
-- its route keep that much more from the turrets: 4 tiles for 40, 10 for 200.
local function waist(w) return math.ceil(1.2 * math.sqrt((w.size or 0) / math.pi)) end
local HELD_FIRE = 3          -- a face that held weighs this much more fire, each time
local LEG = 60               -- at most, tiles a leg of the herd's trail
local ROUTE_TRIES = 8        -- staging points tried in order for a route (every face: at 4, a mining outpost on a
                             -- lake was "no way" on its four best faces, the four on the water's side, 2026-10-27)
local EDGE_RETARGET = 100    -- its target this far within the edge of its reach: it goes for what is at the edge,
local EDGE_SEARCH = 400      -- the foe's building nearest the edge within this (a deathworld's turrets reached 450
                             -- tiles round its targets, nothing within 100 of the edge, and its herds marched 400 to 590
                             -- tiles under its guns to the wall: 6 buildings broken in eight waves)
local WALK_FIRE = 1 / 60     -- and the walk to its staging point this much a tile (at 1/200 a staging point on the far
                             -- side of the player's deathworld factory won, and its herd walked round the whole walled
                             -- factory to reach it, 1,500 tiles, and came scattered)
-- What it goes for at the edge of its reach (EDGE_RETARGET): what the foe makes and runs on, never a turret.
local EDGE_GOALS = {"assembling-machine", "furnace", "mining-drill", "boiler", "generator", "lab"}
local function foe_names(w)
  local out = {}
  for _, f in ipairs(foes(w)) do out[#out + 1] = type(f) == "string" and f or f.name end
  return out
end

local function stage_choice(w, last)
  if not (herd.outside and herd.exposure) then return nil end
  local s = game.surfaces[w.surface]
  local c = w.goal or w.center
  local p = st().pens[w.pen]
  local from = p and p.pen.valid and p.pen.position or w.center
  local l = lessons()[lesson_key(w.center)]
  local forces = {}
  for _, f in ipairs(foes(w)) do forces[#forces + 1] = type(f) == "string" and f or f.name end
  local cands, why = {}, {}
  -- A staging point weighed: the fire on its way in, what its lessons say of that face, the walk there.
  local function weigh(k, stage, way)
    -- The fire on its way in: from the staging point toward the target, to where it first meets the foe's wall or
    -- buildings (the breach). Read out from the target, every face met the overlapping fire of the base's middle,
    -- and the walk decided.
    local sx, sy = c.x - stage[1], c.y - stage[2]
    local len = math.max(1, math.sqrt(sx * sx + sy * sy))
    -- And on through the breach as far as the herd goes in (INSIDE): at a corner beside a heavy face the guns
    -- reached where it fought, and it lost more getting out (herd test, three seeds, 9 to 13 of 41 home).
    local fire, met = 0, nil
    for d = 0, len, STAGE_STEP / 2 do
      local q = {stage[1] + sx / len * d, stage[2] + sy / len * d}
      fire = math.max(fire, herd.exposure(s, q, forces))
      if met and d - met >= INSIDE then break end
      if not met and s.count_entities_filtered{position = q, radius = 3, force = forces, limit = 1,
        type = {"wall", "gate", "ammo-turret", "electric-turret", "fluid-turret", "assembling-machine", "furnace",
          "mining-drill", "container", "electric-pole", "inserter", "transport-belt"}} > 0 then met = d end
    end
    local f = l and l.faces[k]
    local held = f and math.max(0, f.tried - f.broke) or 0
    local walk = math.sqrt((stage[1] - from.x) ^ 2 + (stage[2] - from.y) ^ 2)
    local score = fire + HELD_FIRE * held + WALK_FIRE * walk
    why[#why + 1] = string.format(way and "way in %d (the cost map's)" or "%d:%.1f", k, score)
    cands[#cands + 1] = {k = k, at = {x = stage[1], y = stage[2]}, score = score, fire = fire, way = way}
  end
  for k = 0, 7 do
    local a = k * math.pi / 4
    local ux, uy = math.cos(a), math.sin(a)
    local stage = herd.outside({surface = w.surface, force = B.force}, {pos = {c.x, c.y}, owner = "enemy",
      margin = waist(w)}, ux, uy, STAGE_OFF, STAGE_LEN)
    if stage then weigh(k, stage) end
  end
  -- Its cheapest way in (costmap.way_in), from where it is (`last`, the end of its scout's way out of fire): the walk round
  -- the base and the fire along it count (priced from every side alike, the cheapest way in lay on the far side of a ring
  -- from its pens, and its herd walked 600 tiles along the ring to it, strayed under its guns and broke in there, 55 lost;
  -- 2026-10-27). First of all, the faces after it.
  local mid = last and {x = (last.x + c.x) / 2, y = (last.y + c.y) / 2} or c
  local half = last and math.sqrt(d2(last, c)) / 2 + WAY_MARGIN or WAY_REACH
  local radius = math.max(WAY_REACH, half)
  local fmap = firemap.read(s, mid, radius, forces)
  local cm = costmap.read(s, mid, radius, forces, {fire = fmap, price = price_of(w), n = #herd_units(w), from = last,
    cell = radius > WAY_REACH and costmap.CELL * 2 or nil})
  local way = costmap.way_in(cm, c)
  if way then
    weigh(math.floor(math.atan2(way.start.y - c.y, way.start.x - c.x) / (math.pi / 4) + 0.5) % 8, {way.start.x, way.start.y}, true)
    local top = cands[#cands]
    top.score, top.lost = -1, way.cost
    w.way_in = {start = {way.start.x, way.start.y}, breach = {way.breach.x, way.breach.y}, lost = way.cost}
  end
  -- (Ties by face, then a face before the way in: table.sort is not stable, and a tie went either way from run to run.)
  table.sort(cands, function(a, b)
    if a.score ~= b.score then return a.score < b.score end
    if a.k ~= b.k then return a.k < b.k end
    return not a.way and b.way
  end)
  return cands, table.concat(why, " ")
end

local function mark(w)
  read_ground(w)
  local j, count = choose_mark(w)
  w.mark = loop_point(w, j)
  w.mark_index = j
  w.mark_sector = math.floor(j * 8 / LOOP_POINTS + 0.5) % 8
  local p = st().pens[w.pen]
  local trail = {p and p.pen.valid and xy(p.pen.position) or w.mark}
  for _, q in ipairs(w.approach or {}) do table.insert(trail, q) end
  -- From the last of its scout's way that no gun reaches (its scout walked to the corner of a ring of guns and died there,
  -- and from there every route ran into their reach at its first step: "no way" on all eight faces of an outpost in the
  -- open, and its herd broke in at that corner; 2026-10-27).
  if herd.exposure then
    local s = game.surfaces[w.surface]
    while #trail > 1 and herd.exposure(s, {trail[#trail].x, trail[#trail].y}, foes(w)) > 0 do table.remove(trail) end
  end
  local last = trail[#trail]
  local cands, why = stage_choice(w, last)
  -- The approaches in order, the first its herd can be routed to round the turrets known to it (wide, as a long raid's,
  -- when the plain search runs dry; a coarser grid for a long way): on the player's deathworld the best-scored staging
  -- points lay in pockets ringed by turret reach, beyond every turret but with no way in, and every wave walked straight.
  local way, staged, tried = nil, nil, {}
  local b = {surface = w.surface, force = B.force}
  for i = 1, math.min(ROUTE_TRIES, #(cands or {})) do
    local c = cands[i]
    local far = math.sqrt(d2(last, c.at))
    local o = {turrets = true, nests = false, solid = foe_names(w), cell = far > 400 and 16 or far > 200 and 10 or nil,
      margin = waist(w)}
    if herd.route then
      way = herd.route(b, {last.x, last.y}, {c.at.x, c.at.y}, o) or herd.route(b, {last.x, last.y}, {c.at.x, c.at.y}, o, true)
    end
    if way or not herd.route then staged = c; break end
    local r = herd.route_why and herd.route_why() or {}
    tried[#tried + 1] = string.format("face %d %s at %.0f,%.0f", c.k, r.enclosed and "enclosed" or "no way", c.at.x, c.at.y)
  end
  -- None reachable (its target inside a perimeter of turrets, every staging point found in a pocket within it): it
  -- stages at the nearest point to its target it can reach out of every turret's reach, the edge of the defence, and
  -- breaks in from there.
  if not staged and herd.route then
    local g = w.goal or w.center
    local far = math.sqrt(d2(last, g))
    local o = {turrets = true, nests = false, solid = foe_names(w), partial = true, cell = far > 400 and 16 or far > 200 and 10 or nil,
      margin = waist(w)}
    -- (Wide at once: on the plain search's 4,000 steps the "nearest reached" was where it ran dry, near its own side,
    -- and its herds staged 500 to 770 tiles from the wall they went for, on the player's deathworld.)
    local part = herd.route(b, {last.x, last.y}, {g.x, g.y}, o, true)
    local r = herd.route_why and herd.route_why() or {}
    if part and r.partial then
      way = part
      local e = {x = r.partial[1], y = r.partial[2]}
      local a = math.atan2(e.y - g.y, e.x - g.x)
      staged = {k = math.floor(a / (math.pi / 4) + 0.5) % 8, at = e, score = 0, fire = herd.exposure(game.surfaces[w.surface],
        {e.x, e.y}, foes(w))}
      tried[#tried + 1] = "so at the edge of its reach"
      -- Its target far within (more than EDGE_RETARGET): it goes for the foe's building nearest that edge instead, what
      -- it can reach (staged 450 tiles out on the player's deathworld, its breach would have crossed the factory).
      if math.sqrt(d2(e, g)) > EDGE_RETARGET then
        local s = game.surfaces[w.surface]
        -- (Not a turret: its goal a turret, it staged by it and "broke in" walking at its guns, no wall between.)
        local near = s.find_entities_filtered{position = {e.x, e.y}, radius = EDGE_SEARCH, force = foes(w), type = EDGE_GOALS}
        local best, bd
        for _, x in ipairs(near) do
          local d = d2(x.position, e)
          if not bd or d < bd then best, bd = x, d end
        end
        if best then
          w.goal = {x = best.position.x, y = best.position.y}
          tried[#tried + 1] = string.format("its target far within: goes for the %s at %.0f,%.0f", best.name,
            best.position.x, best.position.y)
        end
      end
    end
  end
  -- None at all: the best, straight, and said so.
  if not staged and cands and cands[1] then staged = cands[1] end
  if staged then
    w.mark, w.mark_sector, w.staged = staged.at, staged.k, true
    log(w, string.format("stages at %.0f,%.0f (face %d, fire %.1f; by face %s)%s; %s", staged.at.x, staged.at.y, staged.k,
      staged.fire, why, #tried > 0 and (" (not reachable: " .. table.concat(tried, ", ") .. ")") or "",
      way and string.format("its trail routed round turrets (%d points)", #way) or "no route found: its trail straight"))
  end
  local parts = {}
  for k = 0, 7 do table.insert(parts, count[k]) end
  if w.staged then
    -- The scout's way out (its track every 60 tiles), then its route; no leg longer than LEG (one leg of 994 tiles
    -- failed at once: seed 777).
    local pts = {}
    for _, q in ipairs(way or {}) do pts[#pts + 1] = {x = q[1], y = q[2]} end
    pts[#pts + 1] = {x = w.mark.x, y = w.mark.y}
    for _, q in ipairs(pts) do
      local a = trail[#trail]
      local d = math.sqrt(d2(a, q))
      for k = 1, math.floor(d / LEG) do
        table.insert(trail, {x = a.x + (q.x - a.x) * k * LEG / d, y = a.y + (q.y - a.y) * k * LEG / d})
      end
      table.insert(trail, q)
    end
  else
    for _, q in ipairs(arc(w, j)) do table.insert(trail, q) end
  end
  w.trail = trail
  lay_trail(game.surfaces[w.surface], trail)
  -- It walks to the mark the same way and sits there, facing the wall.
  if w.scout and w.scout.valid then
    local cmds = {}
    if w.staged then table.insert(cmds, go(w.mark)) else
      for _, q in ipairs(arc(w, j)) do table.insert(cmds, go(q)) end
    end
    table.insert(cmds, {type = defines.command.stop, ticks_to_wait = SIT_TICKS, distraction = defines.distraction.none})
    -- From where it stands (the loop's end is the entry).
    w.scout.commandable.set_command(compound(cmds))
  end
  w.t_mark = game.tick
  log(w, string.format("turrets by face (E, SE, S, SW, W, NW, N, NE from the middle) %s; mark at %.0f,%.0f",
    table.concat(parts, " "), w.mark.x, w.mark.y))
  probe(w)
  gather(w, "march")
end

-- On the move it fights nothing: a herd forty wide spills into turret reach along the loop, and fighting back there
-- (distraction by damage) drew it on to the faces it was going round (the first herd run: ten turrets taken on the way,
-- the herd dead before its mark).
-- Its group, formed again from its units when the engine disbanded it (an incubator takes back its idle units, and a
-- group left empty goes: an order to it crashed two deathworld visits, 0.2.29).

local function ensure_group(w)
  if w.group and w.group.valid then return end
  local s = game.surfaces[w.surface]
  w.group = s.create_unit_group{position = where(w), force = B.force}
  for _, u in ipairs(herd_units(w)) do if not u.commandable.parent_group and not holds(w, u) then w.group.add_member(u) end end
end

local function march(w)
  ensure_group(w)
  -- Every one of its own in the group (at the gather a quarter of a wave of 120 was not, and stayed at the gate).
  -- A stray far behind (STRAY_FAR) is not called in: the same ten to thirteen were called in at every leg on the player's
  -- deathworld and the herd broke up; it goes home, and the herd marches on without it.
  local strays, far, why = 0, 0, {}
  local at = w.group.valid and w.group.position or where(w)
  for _, u in ipairs(herd_units(w)) do
    if u.commandable.parent_group ~= w.group then
      if d2(u.position, at) > STRAY_FAR * STRAY_FAR then
        far = far + 1
        w.left_behind = w.left_behind or {}
        if not w.left_behind[u.unit_number] then
          w.left_behind[u.unit_number] = true
          local p = st().pens[w.pen]
          local home = p and p.pen.valid and p.pen.position or w.trail[1]
          u.commandable.set_command{type = defines.command.go_to_location, destination = home, radius = 8,
            distraction = defines.distraction.by_enemy}
          why[#why + 1] = string.format("%.0f,%.0f", u.position.x, u.position.y)
        end
      elseif w.group.valid then
        -- (A group disbanded meanwhile is formed again by step: adding to it was a crash, deathworld10x visit, 0.2.29.)
        w.group.add_member(u); strays = strays + 1
      end
    end
  end
  if strays > 0 then log(w, string.format("%d strays called into the herd", strays)) end
  if #why > 0 then log(w, string.format("%d left behind, sent home (at %s)", #why, table.concat(why, " ", 1, math.min(#why, 6)))) end
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

-- A wave that came blind (waves of older saves: since 0.2.18 none does).
local function blind_attack(w)
  ensure_group(w)
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
local hold_bursters     -- below, with the breach's spitters
-- The base round a point as a wave reads it: what it is worth (valuemap) and the fire on it (firemap), HEART_REACH round.
local function read_base(w, at)
  local s = game.surfaces[w.surface]
  local forces = foes(w)
  return valuemap.read(s, at, HEART_REACH, forces, valuemap.CORE), firemap.read(s, at, HEART_REACH, forces)
end

-- The soft hearts of the base from where it stands (valuemap.hearts; the way there priced from here, costmap), none
-- nearer than min; with the maps it read. Its box was the turrets round what it was sent at, and on a deathworld visit, 2026-10-27, that
-- was a stretch of a wall round a factory with no turret in it: the heart it saw was "1 thing, under fire", and the
-- factory 150 tiles in went untouched.
local function hearts_from(w, at, min)
  local vmap, fmap = read_base(w, at)
  local n, price = #herd_units(w), price_of(w)
  local cm = costmap.read(game.surfaces[w.surface], at, HEART_REACH, foes(w), {fire = fmap, price = price, n = n, from = at})
  local hearts = valuemap.hearts(vmap, fmap, n, at, HEART_REACH,
    {min = min, price = price, lost = function(mid) return costmap.cost(cm, mid) end})
  return hearts, vmap, fmap, cm
end

-- The heart of the base it broke into: its best soft heart from the breach (hearts_from). Its worth there and at the edge:
-- what stands within SIGHT (valuemap), each over 1 plus the guns on it (and on the way in, for the heart). Returns {at,
-- worth, edge, far, why} or nil.
local function deep_plan(w, h, forced)
  local hearts, vmap, fmap, cm = hearts_from(w, h)
  local best = hearts[1]
  if not (best and best.at) then
    log(w, string.format("no heart it can take within %d of the breach (a gun %.1f of its own)", HEART_REACH, price_of(w)))
    return nil
  end
  local at = {x = best.at.position.x, y = best.at.position.y}
  local far = math.sqrt(d2(at, h))
  if far < DEEP_MIN and not forced then
    w.heart_near = true
    log(w, string.format("the heart is by its breach (%.0f tiles)", far))
    return nil
  end
  local function here(p) return valuemap.worth_near(vmap, p, SIGHT) end
  -- The edge priced as the heart is (costmap, from the breach): two units, and a shell round a soft middle read as not
  -- worth the strike (herd test).
  local n, price = #herd_units(w), price_of(w)
  local edge = here(w.inside) * valuemap.keeps_lost(n, costmap.cost(cm, w.inside) or 0)
  -- (The fire on the way counted whole: at half, a ring of turrets between a mining outpost it had broken into and the
  -- factory behind it read cheap, and it left 95 drills for the factory, and lost half its number in the ring; 2026-10-27.)
  local heart = here(at) * best.keeps
  local l = lessons()[lesson_key(w.center)]
  if l and (l.deep_lost or 0) > 0 then heart = heart * 0.5 ^ l.deep_lost end
  if l and l.last_deep then heart = heart * DEEP_AGAIN end
  return {at = at, worth = heart, edge = edge, far = far,
    why = string.format("the heart %.1f (worth %.0f, the way there %.1f of its own, a gun %.1f) against the edge %.1f",
      heart, here(at), best.lost or 0, price, edge)}
end

-- Its plan at the breach: the heart when worth it, or when told (/lp wave deep). Its tells: the trail runs on to the
-- heart, its leader marked.
local function choose_plan(w)
  local p = deep_plan(w, w.breach, w.force_deep)
  if not p then return end
  local deep = w.force_deep or p.worth > DEEP_MARGIN * p.edge
  log(w, string.format("%s: %s", deep and "strikes for the heart" or "raids the edge", p.why))
  if not deep then return end
  w.deep = {at = p.at, t = game.tick}
  lay_trail(game.surfaces[w.surface], {w.breach, p.at})
  local lead = herd_units(w)[1]
  if lead and lead.valid then
    table.insert(w.marks, rendering.draw_sprite{sprite = "utility/warning_icon", surface = lead.surface,
      target = {entity = lead, offset = {0, -3.4}}, x_scale = 0.6, y_scale = 0.6})
    table.insert(w.marks, rendering.draw_sprite{sprite = "utility/warning_icon", surface = lead.surface,
      target = {entity = lead}, x_scale = 1.2, y_scale = 1.2, render_mode = "chart"})
  end
end

local function breach(w)
  ensure_group(w)
  local s = game.surfaces[w.surface]
  local forces = foes(w)
  local m, c = w.mark, w.staged and w.goal or w.center
  -- Toward a silent turret its probe found (probe_read), and on past it.
  if w.breach_at then
    local dx, dy = w.breach_at.x - m.x, w.breach_at.y - m.y
    local l = math.max(1, math.sqrt(dx * dx + dy * dy))
    c = {x = w.breach_at.x + dx / l * INSIDE, y = w.breach_at.y + dy / l * INSIDE}
  end
  local len = math.sqrt(d2(m, c))
  local ux, uy = (c.x - m.x) / math.max(len, 1), (c.y - m.y) / math.max(len, 1)
  local hit
  for k = 0, math.floor(len) do
    local q = {x = m.x + ux * k, y = m.y + uy * k}
    if s.count_entities_filtered{position = q, radius = 1.5, type = WALLS, force = forces, limit = 1} > 0 then hit = q; break end
  end
  local cmds = {}
  -- No wall on its way: in at the box's face toward its mark, or, staged, straight at what it came for (the box was its
  -- first target's: retargeted at the edge of its reach, its "breach" lay 500 tiles past the drill it went for).
  local h = hit or (w.staged and w.goal) or face_toward(w, m)
  -- The turrets that cover where it breaks in, first, nearest first, when it can take them (firemap.affords): then the
  -- wall, and the gap is quiet going in and coming out (it broke two wall pieces and ran the gap, not fighting back: half
  -- of a wave of 60 lost there in and out, against a ring of gun turrets 8 tiles apart; a deathworld visit, 2026-10-27).
  local silenced = 0
  if hit then
    local map = firemap.read(s, hit, 0, forces)
    local cover = firemap.cover(map, hit)
    w.breach_cover = #cover
    if #cover > 0 and firemap.affords(map, hit, #herd_units(w), price_of(w)) then
      table.sort(cover, function(a, b) return d2(a.position, hit) < d2(b.position, hit) end)
      for _, t in ipairs(cover) do
        table.insert(cmds, {type = defines.command.attack, target = t, distraction = defines.distraction.none})
      end
      silenced = #cover
    end
  end
  if hit then
    local ws = s.find_entities_filtered{position = hit, radius = 3, type = WALLS, force = forces}
    table.sort(ws, function(a, b) return d2(a.position, hit) < d2(b.position, hit) end)
    for i = 1, math.min(2, #ws) do
      table.insert(cmds, {type = defines.command.attack, target = ws[i], distraction = defines.distraction.none})
    end
  end
  local depth = math.min(INSIDE, math.sqrt(d2(h, c)))
  w.breach = h
  w.walled = hit and (#cmds - silenced) or 0
  w.silenced = silenced
  hold_bursters(w, hit)
  w.inside = {x = h.x + ux * depth, y = h.y + uy * depth}
  table.insert(cmds, go(w.inside, defines.distraction.none, 4))
  w.group.set_command(compound(cmds))
  w.stage = "breach"
  w.t = game.tick
  w.t_breach = game.tick
  log(w, string.format("breach at %.0f,%.0f (%s%s)", h.x, h.y, hit and (#cmds - 1 - silenced) .. " wall pieces" or "no wall",
    silenced > 0 and string.format(", the %d turrets covering it first", silenced) or ""))
  choose_plan(w)
end


local withdraw, home_leg

-- Its spitters (the breeds consult, tier 1): once the herd is inside they leave it and hold the breach, spitting at
-- whatever comes at the gap (a sally into the herd's back walks into puddles); when it withdraws they stay COVER_TICKS,
-- then follow it home down the trail.
local COVER_TICKS = 20 * 60
-- Bursters held back (the user, 2026-10-25: wall breakers "provided there are some meat shields to absorb turrets"; the
-- arena's breach: a burster bursts where it dies, and alone it is shot short of the wall). At the breach order its
-- bursters leave the herd and wait HOLD_BACK tiles outside the wall where it breaks in (past a gun turret's 18 and a
-- laser's 24 from turrets a few tiles behind the wall), until RELEASE_N of the herd are within RELEASE_R of that wall
-- (the turrets busy with them) or RELEASE_TICKS have passed; then they run at the wall, or, the wall already open, at the
-- turret nearest the breach. A wave with no wall where it breaks in keeps its bursters with the herd. Its personality: B.mind.holds (the test lever biotech_no_hold).
local HOLD_BACK = 25
local RELEASE_N, RELEASE_R = 5, 8
local RELEASE_TICKS = 40 * 60

hold_bursters = function(w, hit)
  if not hit or B.mind.holds == false or storage.biotech_no_hold then return end
  -- Only where a wall held a wave of its before: elsewhere its biters open the wall themselves, and its bursters do more
  -- going in with them (held everywhere, in four 3-hour runs it broke 401 against 451: the held ones widened holes
  -- already open, where unheld ones burst on the power behind the wall).
  local l = herd.lesson_near(w.center, 128)
  if not (l and (l.walled_held or 0) > 0) then return end
  local dx, dy = w.mark.x - hit.x, w.mark.y - hit.y
  local len = math.max(1, math.sqrt(dx * dx + dy * dy))
  local at = {x = hit.x + dx / len * HOLD_BACK, y = hit.y + dy / len * HOLD_BACK}
  local set, n = {}, 0
  for _, u in ipairs(w.members) do
    if u.valid and u.name == "lp-bred-cinder" and u.commandable then
      -- (A command of its own takes a unit out of its group.)
      u.commandable.set_command{type = defines.command.go_to_location, destination = at, radius = 4,
        distraction = defines.distraction.none}
      set[u.unit_number] = true
      n = n + 1
    end
  end
  if n == 0 then return end
  w.sappers = {set = set, n = n, hold = at, wall = {x = hit.x, y = hit.y}, t = game.tick}
  log(w, string.format("%d bursters wait %d tiles outside the wall at %.0f,%.0f", n, HOLD_BACK, hit.x, hit.y))
end

local function release_bursters(w, tick)
  local sp = w.sappers
  if not sp or sp.released then return end
  local front = 0
  for _, u in ipairs(w.members) do
    if u.valid and not sp.set[u.unit_number] and d2(u.position, sp.wall) <= RELEASE_R * RELEASE_R then front = front + 1 end
  end
  if front < RELEASE_N and tick - sp.t < RELEASE_TICKS then return end
  sp.released = tick
  local s = game.surfaces[w.surface]
  local target
  -- The wall where the herd breaks in while it stands; once open (the herd broke its two pieces before the bursters were
  -- let go, and they ran inside at whatever they met), the turret nearest the breach: the guns are what kill the herd.
  local ws = s.find_entities_filtered{position = sp.wall, radius = 3, type = WALLS, force = foes(w)}
  local ts = #ws == 0 and s.find_entities_filtered{position = sp.wall, radius = 30, type = TURRETS, force = foes(w)} or {}
  local bd
  for _, e in ipairs(#ws > 0 and ws or ts) do
    local d = d2(e.position, sp.wall)
    if not bd or d < bd then target, bd = e, d end
  end
  local n = 0
  for _, u in ipairs(w.members) do
    if u.valid and sp.set[u.unit_number] then
      if target then
        u.commandable.set_command{type = defines.command.attack, target = target, distraction = defines.distraction.none}
      else
        u.commandable.set_command{type = defines.command.go_to_location, destination = w.inside or sp.wall, radius = 2,
          distraction = defines.distraction.by_enemy}
      end
      n = n + 1
    end
  end

  log(w, string.format("%d bursters released at the %s, %d of the herd at the wall, %.0f s on", n,
    target and target.name or "breach", front, (tick - sp.t) / 60))
end
local function is_spitter(u) return u.valid and u.name:find("spitter", 1, true) ~= nil end

local function hold_breach(w)
  if not w.breach or w.holding then return end
  w.holding = true
  local n = 0
  for _, u in ipairs(w.members) do
    if is_spitter(u) then
      w.holders = w.holders or {}
      w.holders[u.unit_number] = true
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

-- What it goes for inside, from where it stands: the guns firing on it there (0), what feeds the guns (power, the inserters loading gun turrets, the pipes
-- at flamethrowers: tier 1), what sees for them and mends them (radars, roboports: 2), the lasers it silenced (3), and
-- what is there (4, havoc), the guns it can take (5); never what it cannot take (firemap.affords: the inner keep, for a
-- wave its size). Each {e, tier}.
local function targets(w, at)
  local s = game.surfaces[w.surface]
  local forces = foes(w)
  local out, seen = {}, {}
  -- What it can take (firemap.affords): the fire round here read once for the look.
  local map = firemap.read(s, at, math.max(w.sight, w.hx + w.hy), forces)
  local n, price = #herd_units(w), price_of(w)
  local function add(e, tier)
    if e.valid and not seen[e.unit_number or 0] and firemap.affords(map, e.position, n, price) then
      seen[e.unit_number or 0] = true
      out[#out + 1] = {e = e, tier = tier}
    end
  end
  local r = w.sight
  -- First, the guns firing on it where it stands, when it can take them (it ate an outpost's drills under its four guns
  -- and lost half its number there, and more leaving past them; 2026-10-27).
  for _, t in ipairs(firemap.cover(map, at)) do add(t, 0) end
  for _, e in pairs(s.find_entities_filtered{position = at, radius = r, type = POWER, force = forces}) do add(e, 1) end
  for _, e in pairs(s.find_entities_filtered{position = at, radius = r, type = "inserter", force = forces}) do
    if s.count_entities_filtered{position = e.drop_position, type = "ammo-turret", force = forces, limit = 1} > 0 then add(e, 1) end
  end
  for _, ft in pairs(s.find_entities_filtered{position = at, radius = r, type = "fluid-turret", force = forces}) do
    for _, e in pairs(s.find_entities_filtered{position = ft.position, radius = 3, type = PIPES, force = forces}) do add(e, 1) end
  end
  for _, e in pairs(s.find_entities_filtered{position = at, radius = r, type = CONTROL, force = forces}) do add(e, 2) end
  local fed = {}
  for _, p in pairs(s.find_entities_filtered{position = at, radius = 4 * r, type = POWER, force = forces}) do
    if p.valid and p.electric_network_id then fed[p.electric_network_id] = true end
  end
  for _, e in pairs(s.find_entities_filtered{position = at, radius = math.max(r, w.hx + w.hy), type = "electric-turret",
    force = forces}) do
    if not (e.electric_network_id and fed[e.electric_network_id]) then add(e, 3) end
  end
  if B.mind.havoc ~= false then
    for _, e in pairs(s.find_entities_filtered{position = at, radius = r, type = SOFT, force = forces}) do
      add(e, 4 + 1 / (1 + valuemap.worth_of(e)))
    end
  end
  -- Last, the guns it can take (5): from inside, where no wall shields them (a wave of 200 broke all else in a small base
  -- and went home with 188, the guns standing: herd test). Those it cannot take are the keep.
  for _, t in ipairs(map.list) do
    if t.e.valid and (t.x - at.x) ^ 2 + (t.y - at.y) ^ 2 <= r * r then add(t.e, 5) end
  end
  return out
end

-- Its biters inside, each after its own target (LOOK ticks apart, and when its group's order ends): who has one keeps it;
-- the idle each take the best they can reach, by tier then distance, at most PER_TARGET (BIG_TARGET) on one. Nothing
-- left in sight: the wave on to the middle once (its goal, staged), then home.
local function hunt(w)
  -- (Its rush for the heart broken off: it hunts from where it stands.)
  if w.deep and w.deep.going then w.deep.going, w.deep.broken = false, game.tick end
  if not w.individual then
    ensure_group(w)
    if not (w.group and w.group.valid) then return end
    hold_breach(w)
  end
  w.aim = w.aim or {}
  w.holders = w.holders or {}
  local units = herd_units(w)
  if #units == 0 then return end
  -- Targets fallen since the last look; claims on the standing ones.
  local claims, busy = {}, 0
  for _, u in ipairs(units) do
    local a = w.aim[u.unit_number]
    if a and not (a.e and a.e.valid) then
      if not (w.down or {})[a.id] then
        w.down = w.down or {}
        w.down[a.id] = true
        w.t_progress, w.downed = game.tick, (w.downed or 0) + 1
        log(w, string.format("its %s is down", a.name))
      end
      w.aim[u.unit_number], a = nil, nil
    end
    if a then claims[a.id] = (claims[a.id] or 0) + 1; busy = busy + 1 end
  end
  local at = where(w)
  local list = targets(w, at)
  -- What it pushed in for stays on its list (a wave of 200 got there, its middle still 40 tiles behind it, and saw nothing).
  if w.push_to and w.push_to.valid then list[#list + 1] = {e = w.push_to, tier = 4} end
  table.sort(list, function(x, y) return x.tier < y.tier end)
  local given = 0
  for _, u in ipairs(units) do
    if not w.aim[u.unit_number] and not w.holders[u.unit_number] and u.valid then
      local best, bs
      for _, c in ipairs(list) do
        local id = c.e.unit_number or 0
        local cap = BIG[c.e.type] and BIG_TARGET or PER_TARGET
        if c.e.valid and (claims[id] or 0) < cap and not (w.unreachable and w.unreachable[id]) then
          local sc = c.tier * 10000 + d2(c.e.position, u.position)
          if not bs or sc < bs then best, bs = c, sc end
        end
      end
      if best then
        local id = best.e.unit_number or 0
        claims[id] = (claims[id] or 0) + 1
        w.aim[u.unit_number] = {e = best.e, id = id, name = best.e.name}
        if not w.tried[id] then
          w.tried[id] = true
          w.went_for = w.went_for or {}
          table.insert(w.went_for, best.e.type)
          if math.floor(best.tier) == 4 and not w.havoc then w.havoc = true; log(w, "nothing feeds a gun: breaks what is there") end
        end
        -- Its own order takes it out of its group: from here each of its biters is on its own.
        u.commandable.set_command{type = defines.command.attack, target = best.e, distraction = defines.distraction.none}
        given, busy = given + 1, busy + 1
        w.individual = true
      end
    end
  end
  if given > 0 then log(w, string.format("%d of its biters each go for their own target (%d targets in sight)", given, #list)) end
  if busy > 0 then return end
  -- Nothing in sight: on into the base once, as a group, to look again there (towards its goal, it walked 6 tiles, the goal
  -- by the wall, looked again, found nothing and went home; 2026-10-27); then home.
  if not w.pushed then
    w.pushed = true
    w.individual = nil
    ensure_group(w)
    for _, u in ipairs(units) do if u.valid and not u.commandable.parent_group and not holds(w, u) then w.group.add_member(u) end end
    local at = where(w)
    local s = game.surfaces[w.surface]
    -- The soft heart past its sight (hearts_from); none it can take within HEART_REACH: home.
    local hearts = hearts_from(w, at, w.sight)
    local near = hearts[1] and hearts[1].at
    if not near then
      log(w, string.format("nothing in sight, and no heart within %d it can take", HEART_REACH))
      return withdraw(w, "nothing in sight feeds a gun")
    end
    w.group.set_command(go(near.position, defines.distraction.none, 6))
    w.push_to = near
    w.pushing = game.tick
    -- (Measured by its group, where the order went: the middle of 186 strung out lagged 40 tiles behind it.)
    w.push_from = w.group.position
    log(w, string.format("nothing in sight: pushes in, to its %s at %.0f,%.0f (%.0f tiles)", near.name, near.position.x,
      near.position.y, math.sqrt(d2(near.position, at))))
    return
  end
  if w.push_from then w.push_walked = math.sqrt(d2(w.group and w.group.valid and w.group.position or where(w), w.push_from)) end
  withdraw(w, "nothing in sight feeds a gun")
end

home_leg = function(w)
  ensure_group(w)
  -- On its way out, the turrets covering the gap first, from inside, while it can take them, one at a time, the next when
  -- one is down (it went back through the gap it had paid for and lost as many again: 14 to 28 of 60 on a deathworld's
  -- ring, 2026-10-27). At most CLEAR_MAX orders.
  if w.home_leg == 1 and w.breach and not w.out_clear then
    local s = game.surfaces[w.surface]
    local map = firemap.read(s, w.breach, 0, foes(w))
    local cover = firemap.cover(map, w.breach)
    if #cover > 0 and (w.clearing or 0) < CLEAR_MAX and firemap.affords(map, w.breach, #herd_units(w), price_of(w)) then
      local at = w.group.position
      table.sort(cover, function(a, b) return d2(a.position, at) < d2(b.position, at) end)
      if (w.clearing or 0) == 0 then log(w, string.format("clears its way out: the %d turrets covering the gap", #cover)) end
      w.clearing = (w.clearing or 0) + 1
      w.group.set_command{type = defines.command.attack, target = cover[1], distraction = defines.distraction.none}
      return
    end
    w.out_clear = true
  end
  w.group.set_command(go(w.home[math.min(w.home_leg, #w.home)], defines.distraction.none, 6))
end

withdraw = function(w, why)
  if w.stage == "withdraw" or w.stage == "done" then return end
  -- Its biters back into one group, to go home as it came (inside, each was on its own).
  w.individual = nil
  ensure_group(w)
  local g = w.group
  if not (g and g.valid) then return end
  -- (Not the spitters holding the breach: they cover the withdrawal, below.)
  for _, u in ipairs(herd_units(w)) do if u.valid and not u.commandable.parent_group and not holds(w, u) then g.add_member(u) end end
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
  learn_price(w)
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
    home_legs = w.home_leg, home_n = w.home and #w.home, went_for = w.went_for,
    deep = w.deep and {at = {w.deep.at.x, w.deep.at.y}, reached = w.deep.reached and true or false},
    under_fire = w.under_fire, downed = w.downed or 0, push_walked = w.push_walked,
    choice = w.choice, goal = w.goal and {w.goal.x, w.goal.y}, heart_near = w.heart_near, razed_worth = w.razed_worth or 0, dead_at = w.dead_at,
    lost_by = w.lost_by, silenced = w.silenced, clearing = w.clearing, staged = w.staged and true or false,
    breach_cover = w.breach_cover, price = w.price_learned,
    bursters = (w.sappers or w.bursts) and {held = w.sappers and w.sappers.n or 0, burst = w.bursts and w.bursts.n or 0,
      broke = w.bursts and w.bursts.broke or {}, released = w.sappers and w.sappers.released and (w.sappers.released - w.sappers.t) / 60}})
  if w.sappers or w.bursts then
    log(w, string.format("bursters: %d held, %d burst, their bursts broke %s", w.sappers and w.sappers.n or 0,
      w.bursts and w.bursts.n or 0, serpent.line(w.bursts and w.bursts.broke or {})))
  end
  h.waves[w.id] = nil
  -- Where its number went (a visit, 2026-10-27: waves turned back half lost at the breach with 3 of their own killed by
  -- the count near the base): every death of its own by stage and killer, and those gone without one.
  local died = 0
  for _, n in pairs(w.lost_by or {}) do died = died + n end
  log(w, string.format("%s; %d of %d home; died %s; gone without a death %d", outcome, alive(w), w.size,
    serpent.line(w.lost_by or {}), w.size - alive(w) - died))
  if w.price_learned then
    log(w, string.format("a gun cost it %.1f of its own at the breach (%d covering it): its price now %.1f",
      w.price_learned.sample, w.breach_cover, w.price_learned.per))
  end
  -- Its lesson: the face it tried and whether it broke anything past the wall there; what killed its units round it.
  -- (Its personality: B.mind.learns; off, it keeps none, which is how the system sim measures what learning is worth.)
  if w.mark_sector and not w.blind and B.mind.learns ~= false and not storage.biotech_unlearned then
    local key = lesson_key(w.center)
    local l = lessons()[key] or {faces = {}, killers = {}, waves = 0}
    lessons()[key] = l
    l.waves = l.waves + 1
    -- What it cost: how many it sent there and how many came home (farm.lua weighs the place by it).
    l.sent, l.home = (l.sent or 0) + (w.size or 0), (l.home or 0) + alive(w)
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
    -- A deep strike that cost it half its number: the next one there is worth half (deep_plan).
    l.last_deep = w.deep ~= nil
    if w.deep then
      l.deep = (l.deep or 0) + 1
      if alive(w) * 2 < (w.size or 0) then l.deep_lost = (l.deep_lost or 0) + 1 end
    end
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
    if not (sc and sc.valid) then scout_lost(w); return mark(w) end
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
  if not (w.group and w.group.valid) and not (w.stage == "inside" and w.individual) then
    -- Its group gone with its members alive (a failed order disbands a group on 2.1): formed again where they stand and
    -- on with what it was doing, up to REGROUPS times; only then scattered.
    local live = herd_units(w)
    if #live >= 2 and (w.regroups or 0) < REGROUPS and (w.stage == "inside" or w.stage == "breach" or w.stage == "march"
      or w.stage == "blind" or (w.stage == "withdraw" and w.home)) then
      w.regroups = (w.regroups or 0) + 1
      w.group = s.create_unit_group{position = where(w), force = B.force}
      for _, u in ipairs(live) do if not u.commandable.parent_group and not holds(w, u) then w.group.add_member(u) end end
      log(w, string.format("its group broke up with %d alive: formed again (%d of %d)", #live, w.regroups, REGROUPS))
      if w.stage == "march" then march(w) elseif w.stage == "blind" then blind_attack(w)
      elseif w.stage == "withdraw" then home_leg(w) else hunt(w) end
      return
    end
    return finish(w, "scattered")
  end
  if w.stage == "inside" or w.stage == "breach" then release_bursters(w, tick) end
  if w.stage == "inside" or w.stage == "breach" or w.stage == "blind" then
    -- Half lost, and still losing (any of its own in FIRE_WINDOW): out. Half lost past the guns and losing none, it stays: the
    -- way out is through the fire it paid to cross (a deathworld visit, 2026-10-27: waves lost half in the gap of a turret
    -- ring, turned at the heart where nothing fired on them, and lost as many again going back through it).
    local now = alive(w)
    w.loss_log = w.loss_log or {}
    table.insert(w.loss_log, {tick, now})
    while #w.loss_log > 1 and tick - w.loss_log[1][1] > FIRE_WINDOW do table.remove(w.loss_log, 1) end
    if now * 2 < w.size and w.loss_log[1][2] > now then return withdraw(w, "half lost") end
    -- Inside while it brings things down (INSIDE_TICKS since the last fell), INSIDE_MAX at most.
    if w.t_inside and tick - math.max(w.t_inside, w.t_progress or 0) > INSIDE_TICKS then return withdraw(w, "time inside") end
    if w.t_inside and tick - w.t_inside > INSIDE_MAX then return withdraw(w, "time inside, the most") end
    -- Its biters' next targets, every LOOK ticks (one's attack ends when its target falls).
    -- (Not while it pushes in: the next look, two seconds on, found nothing where it still stood and sent it home; on a
    -- deathworld visit, 2026-10-27, four waves of 60 turned at the wall with 2 of their own killed and lost 12 to 17 on
    -- the way out. Its look comes when it gets there, or after PUSH_MAX.)
    if w.pushing and tick - w.pushing >= PUSH_MAX then w.pushing = nil end
    if w.stage == "inside" and tick % LOOK == 0 and not (w.deep and w.deep.going) and not w.pushing then hunt(w) end
  end
  -- Under fire on the march (FIRE_LOSS within FIRE_WINDOW, turrets within FIRE_NEAR): it breaks in where it stands.
  if w.stage == "march" then
    w.fire_log = w.fire_log or {}
    local now = alive(w)
    table.insert(w.fire_log, {tick, now})
    while #w.fire_log > 1 and tick - w.fire_log[1][1] > FIRE_WINDOW do table.remove(w.fire_log, 1) end
    if w.fire_log[1][2] - now > FIRE_LOSS * (w.size or now) then
      local at = where(w)
      if s.count_entities_filtered{position = at, radius = FIRE_NEAR, type = TURRETS, force = foes(w), limit = 1} > 0 then
        log(w, string.format("under fire on the march (%d lost in %d s): breaks in where it stands, at %.0f,%.0f",
          w.fire_log[1][2] - now, math.floor((tick - w.fire_log[1][1]) / 60), at.x, at.y))
        w.under_fire = tick
        w.mark = {x = at.x, y = at.y}
        -- Its way home is the trail it walked, not the rest of it on to its old mark (home ran along the wall first).
        local walked = {}
        for k = 1, math.min((w.leg or 1) - 1, #w.trail) do walked[#walked + 1] = w.trail[k] end
        walked[#walked + 1] = {x = at.x, y = at.y}
        w.trail = walked
        w.fire_log = nil
        return breach(w)
      end
    end
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
    -- One of its biters on its own done with its target: its claim freed; failed (no way to it), that target struck off
    -- for this wave (it stood idle holding its claim, and kept others off it, until the wave's time inside ran out).
    local a = w.aim and w.aim[e.unit_number]
    if a then
      w.aim[e.unit_number] = nil
      if e.result ~= defines.behavior_result.success and a.e and a.e.valid then
        w.unreachable = w.unreachable or {}
        w.unreachable[a.id] = true
      end
      return
    end
    if w.stage == "scout" and w.scout and w.scout.valid and e.unit_number == w.scout.unit_number then
      log(w, string.format("scout's loop done (%s, result %d%s) at %.0f,%.0f",
        e.result == defines.behavior_result.success and "whole" or "cut short", e.result,
        e.was_distracted and ", distracted" or "", w.scout.position.x, w.scout.position.y))
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
      -- (Its loop cut short, the wave comes all the same: the faces are read from the ground, read_ground.)
      return mark(w)
    end
    if w.group and w.group.valid and e.unit_number == w.group.unique_id then
      if w.stage == "march" then
        if e.result ~= defines.behavior_result.success then
          w.legs_failed = (w.legs_failed or 0) + 1
          log(w, string.format("leg %d of %d of its trail failed (%s)", w.leg, #w.trail, tostring(e.result)))
        end
        -- A leg walked: its regroups start again (REGROUPS a leg).
        if e.result == defines.behavior_result.success then w.regroups = 0 end
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
        -- A deep strike: past what is near, on to the heart, fighting nothing; there it hunts.
        if w.deep and not w.deep.reached then
          w.deep.going = true
          -- Its spitters stay at the breach (sent back from the heart they crossed the base again, late and few).
          hold_breach(w)
          w.group.set_command(go(w.deep.at, defines.distraction.none, 8))
          log(w, string.format("rushes for the heart at %.0f,%.0f", w.deep.at.x, w.deep.at.y))
          return
        end
        return hunt(w)
      end
      if w.stage == "inside" and w.deep and w.deep.going then
        w.deep.going, w.deep.reached = false, game.tick
        w.t_progress = game.tick
        log(w, string.format("at the heart (%s)", e.result == defines.behavior_result.success and "reached" or "as far as it got"))
        return hunt(w)
      end
      if w.stage == "inside" then w.pushing = nil; return hunt(w) end
      if w.stage == "blind" then return withdraw(w, "blind wave spent") end
      if w.stage == "withdraw" then
        -- (Clearing its way out: the next turret, or on.)
        if w.home_leg == 1 and w.breach and not w.out_clear then return home_leg(w) end
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
  if ent.force.name == B.force and ent.type == "unit" then
    for _, w in pairs(h.waves) do
      for _, u in ipairs(w.members) do
        if u == ent then
          local c = e.cause and e.cause.valid and e.cause
          local key = w.stage .. " " .. (c and (c.force.name == "enemy" and "wild " or "") .. c.name or "none")
          w.lost_by = w.lost_by or {}
          w.lost_by[key] = (w.lost_by[key] or 0) + 1
          -- Where (its record: scripts/wavemap.py), at most DEAD_AT.
          w.dead_at = w.dead_at or {}
          if #w.dead_at < DEAD_AT then w.dead_at[#w.dead_at + 1] = {math.floor(ent.position.x), math.floor(ent.position.y), w.stage} end
          break
        end
      end
    end
  end
  if e.force and e.force.name == B.force and shared.is_player_force(ent.force) then
    for _, w in pairs(h.waves) do
      if w.stage ~= "scout" then
        w.kills[ent.name] = (w.kills[ent.name] or 0) + 1
        w.razed_worth = (w.razed_worth or 0) + valuemap.worth_of(ent)
        if not w.t_first_kill and ent.type ~= "wall" and ent.type ~= "gate" then w.t_first_kill = game.tick end
      end
    end
  end
  -- What its bursters' bursts broke (a death to its force with no cause left standing: the burster died of it), and how
  -- many burst at all once the herd was in (for the log and the herd test; the arena's breach is the measure of worth).
  if e.force and e.force.name == B.force and not (e.cause and e.cause.valid) and shared.is_player_force(ent.force) then
    for _, w in pairs(h.waves) do
      if w.breach then
        w.bursts = w.bursts or {n = 0, broke = {}}
        w.bursts.broke[ent.type] = (w.bursts.broke[ent.type] or 0) + 1
      end
    end
  end
  if ent.name == "lp-bred-cinder" then
    for _, w in pairs(h.waves) do
      if w.breach then
        for _, u in ipairs(w.members) do
          if u == ent then w.bursts = w.bursts or {n = 0, broke = {}}; w.bursts.n = w.bursts.n + 1; break end
        end
      end
    end
  end
  for _, w in pairs(h.waves) do
    -- Its scout killed, at any stage (cut short under fire, its wave marked before it fell): the skull, the next loop wider.
    if w.scout == ent and not w.scout_lost then
      w.scout_died_at = {x = ent.position.x, y = ent.position.y}
      w.scout_killer = (e.cause and e.cause.valid and e.cause.name) or (e.force and e.force.name) or "?"
      scout_lost(w)
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
  return {pens = pens, waves = waves, log = h.log, trails = #h.trails, rears = rears}
end

return herd
