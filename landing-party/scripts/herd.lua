-- The biotech's waves: a pack (docs/biotech.md, "Waves with intent: the pack"; Fable:
-- docs/reviews/2026-10-22-wave-intelligence-consult.md). The first slice: a pen on a held nest breeds to its stock, then
-- sends one wave the player can watch and read.
--   1. The tracker: one bred biter walks a loop outside the turrets' reach (LOOP_SPARE past their reach), stopping
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
local threat = require("__landing-party__.scripts.threat")
local attempt = require("__landing-party__.scripts.attempt")
local tactics = require("__landing-party__.scripts.tactics")
local valuemap = require("__landing-party__.scripts.valuemap")
local costmap = require("__landing-party__.scripts.costmap")
local feeds = require("__landing-party__.scripts.feeds")
local burstfx = require("__landing-party__.scripts.burstfx")
local shared = require("shared")
local herd = {}

local B = shared.BIOTECH
local SIGHT = 40            -- what a biter of the pack sees, scout or herd (tiles)
local LOOP_SPARE = 3        -- the loop this far past its turrets' reach (threat.reach, from their prototypes: a flat 29
                           -- stood inside a flamethrower's 30, and on a flamer base the scout and its tell died)
local LOOP_POINTS = 16
local STOP_EVERY = 4        -- a pause at every fourth loop point: four faces
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
local OVER_SPREAD = 400   -- past the caps, a claim on a target counts as this much more distance squared (20 tiles)
local BIG = {reactor = true, ["fusion-generator"] = true, roboport = true, ["assembling-machine"] = false,
  ["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true}
local LOOK = 120
local PUSH_MAX = 60 * 60   -- a push in, at most, before it looks again
local HOME_NEAR = 30        -- a survivor farther than this from its incubator when its wave ends is sent home
local DEEP_GO_MAX = 90 * 60  -- a rush for the heart, at most, before it hunts where it stands
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
local ARTILLERY = {"artillery-turret", "artillery-wagon"}
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
  "electric-energy-interface", "artillery-turret", "artillery-wagon"}
-- And all the value map weighs from CORE up (solar fields, accumulators, substations): on a megabase its soft hearts were
-- power fields north of its walls, no gun near, worth 274 a cell, and its farm never weighed them, choosing among what
-- DRAW listed, all behind the guns (2026-10-27).
do
  local seen = {}
  for _, t in ipairs(herd.DRAW) do seen[t] = true end
  for _, t in ipairs(valuemap.CORE) do if not seen[t] then seen[t] = true; herd.DRAW[#herd.DRAW + 1] = t end end
end

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
  -- (0.2.91: its prices learned in heads read as mediums, herd.strength: learned again, from its priors.)
  if not storage.biotech_priced_in_health then
    storage.biotech_priced_in_health = true
    local k = know.of("biotech")
    k.price, k.scale, k.dear = nil, nil, nil
    for _, f in pairs(storage.farms and storage.farms.list or {}) do f.refused_at = nil end
  end
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
-- What a turret costs it, in its own (firemap.affords, valuemap.keeps_lost, costmap): learned per foe and per prototype
-- (know.price) from what its breaches cost, its own each prototype covering the breach killed over how many of them
-- covered it; before any, its mind's per_turret scaled by the turret's research (threat.prior). One price for every
-- turret could not learn that a laser line is dearer than a gun line (the perception consult, 2026-10-27); a guess of 6
-- for all let waves of 60 at a ring of guns whose gaps cost them half their number.
-- (A learned price is a fresh unit's, its losses learned at their killer's rank, below: read at this one's, 0.2.355.)
function herd.price_of(t)
  local p = know.price("biotech", t.force.name, t.name)
  return p and p * shared.rank_scale(t) or threat.prior(t, B.mind.per_turret or firemap.AFFORD)
end
-- Where its own died lately to what the fire map cannot show (a killer no turret profile names: mines, burning ground,
-- units, nothing), each weighing less as it ages (DEATHS_FOR): the cost map's memory of the ground (costmap.DEATH).
local DEATHS_FOR = 60 * 3600
function herd.deaths()
  local out = {}
  for _, l in ipairs(know.losses("biotech", DEATHS_FOR, function(l)
    local p = l.unit and l.killer and threat.profile(l.killer)
    return l.unit and not (p and (p.kind == "ammo" or p.kind == "power" or p.kind == "fluid"))
  end)) do
    out[#out + 1] = {l.pos[1], l.pos[2], 1 - (game.tick - l.tick) / DEATHS_FOR}
  end
  return out
end

-- Ground its herds found no way through (a leg the pathfinder went round: DETOUR), lately (BLOCKED_FOR): {x, y} each, for
-- its cost maps to price as water. Terrain does not move, but a player's walls and buildings do.
local BLOCKED_FOR = 4 * 60 * 3600
function herd.blocked()
  local k = know.of("biotech")
  local out, kept = {}, {}
  for _, b in ipairs(k.blocked or {}) do
    if game.tick - b[3] < BLOCKED_FOR then kept[#kept + 1] = b; out[#out + 1] = {b[1], b[2]} end
  end
  k.blocked = kept
  return out
end

-- How many of its incubators an artillery piece reaches (threat.reach: its range with its force's research).
function herd.shelling(art)
  local r = threat.reach(art)
  local n = 0
  for _, p in pairs(st().pens) do
    if p.pen.valid and p.pen.surface == art.surface and d2(p.pen.position, art.position) <= r * r then n = n + 1 end
  end
  return n
end

-- The farm's cell a wave's target stood in (farm.lua target_from: 64 tiles, by force), for what the wave learned of it.
function herd.dear_key(force, pos)
  local name = force and (type(force) == "string" and force or force.name) or "player"
  return string.format("%s|%d,%d", name, math.floor(pos.x / 64), math.floor(pos.y / 64))
end

-- The name of the foe a wave goes at.
local function foe_name(w)
  local f = foes(w)[1]
  return f and (type(f) == "string" and f or f.name) or "player"
end

-- What breaking into a foe's walls costs it besides the guns it can see: its own killed at the breach by what no turret
-- profile names (mines, burning ground, units), learned per killer as a price per breach (n = 0 in the record): a base that
-- mines its walls makes every wall it has dear (one minefield at a time, each wave paid for the next one on a megabase's
-- mined wall; 2026-10-27).
function herd.hidden_cost(foe)
  local p = know.of("biotech").price
  local total = 0
  for proto, r in pairs(p and p[foe] or {}) do
    local prof = threat.profile(proto)
    -- (Not its mines: it sees them now, each priced where it lies, costmap.MINE.)
    local mine = prototypes.entity[proto] and prototypes.entity[proto].type == "land-mine"
    if not (mine or (prof and (prof.kind == "ammo" or prof.kind == "power" or prof.kind == "fluid"))) then total = total + r.per end
  end
  return total
end

-- What crossing cost it against what it expected (costmap.way_in there and back), for know.scale: its march, its breach
-- and its way out, not what it fought inside.
-- What it learns from a wave (herd_learn.lua: the scale of its reading, its killers' prices, its attempts, its rams' reach,
-- the stops that develop its big bursters).
local learned = require("__landing-party__.scripts.herd_learn").install(herd, {B = B, FIRE_NEAR = FIRE_NEAR,
  foe_name = foe_name, foes = foes, lessons = lessons, st = st})
local learn_march, learn_price, record_attempt = learned.learn_march, learned.learn_price, learned.record_attempt

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
herd.hostiles = hostiles

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
-- (And the longest reach among them, threat.reach; none known, the longest there is, threat.far.)
local function base_box(s, pos, forces)
  local ts = s.find_entities_filtered{position = pos, radius = BASE_REACH, force = forces, type = TURRETS}
  if #ts == 0 then return xy(pos), 8, 8, threat.far() end
  local x0, y0, x1, y1, reach = math.huge, math.huge, -math.huge, -math.huge, 0
  for _, t in ipairs(ts) do
    x0, y0 = math.min(x0, t.position.x), math.min(y0, t.position.y)
    x1, y1 = math.max(x1, t.position.x), math.max(y1, t.position.y)
    reach = math.max(reach, threat.reach(t))
  end
  return {x = (x0 + x1) / 2, y = (y0 + y1) / 2}, math.max(8, (x1 - x0) / 2), math.max(8, (y1 - y0) / 2), reach
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

-- No trail: its waves leave nothing on the ground or the map. (Mud along its whole planned way when it set out, with the
-- way's last 120 tiles on the map, until 0.2.442: the user, 2026-11-17, playtest: "Not sure I'm a fan of the acid spit
-- appearing when they plan their raid (+ the big green line on the map...)", "vanilla biters don't put mud anywhere";
-- 2026-10-23: "Not a fan of the big green line on the map pointing to Synthexis".) Its tells are its scout's loop, its
-- gathering and its leader's mark. The mud saves still hold is taken up when it expires (lift_trails).
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

-- The loop: a box its turrets' reach and LOOP_SPARE (and what dead scouts taught) outside the turrets' box, sixteen points round it, each moved
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
      if threat.covering(s, q0, hostiles(), 1, LOOP_SPARE) == 0 then
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
-- The first of its foe's wall pieces on the line from `a` to `b` (nil: none), a tile at a time.
local WALL_TRIES = 6   -- walls it goes at between it and its target before it counts itself through all the same
local function wall_between(w, a, b)
  local s = game.surfaces[w.surface]
  local n = math.ceil(math.sqrt(d2(a, b)))
  for i = 0, n do
    local p = {a.x + (b.x - a.x) * i / math.max(1, n), a.y + (b.y - a.y) * i / math.max(1, n)}
    local e = s.find_entities_filtered{position = p, radius = 0.8, type = WALLS, force = foes(w), limit = 1}[1]
    if e then return e end
  end
end
-- Its unit nearest its goal (through when that one is: from its middle, a wave that had broken a gap had wall pieces
-- beside the gap on its line, and went at them; the herd test, spit).
local function foremost(w)
  local best, bd
  for _, u in ipairs(w.members) do
    if u.valid and u ~= w.scout then
      local d = d2(u.position, w.goal)
      if not bd or d < bd then best, bd = u.position, d end
    end
  end
  return best or w.center
end
-- Through its gap, not the wall beside it (the user, 2026-11-04, the trailer's wave of 200: "breach the wall, bugging
-- out, then refocusing on one piece of wall at a time"). Its gap open (w.gap: of the wall pieces it broke, the one
-- nearest its breach, still no wall there), a biter or its group with a wall between it and where it goes walks to the gap first: sent straight at a
-- target past the wall, the engine's path ran through the wall in front of it and it chewed that, a piece at a time, a
-- few tiles from the open gap (herd test, mega: 50 wall pieces broken after the gap opened, 64% of its bite on walls).
local function gap_open(w)
  if not w.gap then return false end
  return game.surfaces[w.surface].count_entities_filtered{position = w.gap, radius = 0.9, type = WALLS, force = foes(w),
    limit = 1} == 0
end
-- The leg through the gap from `from` toward `dest`, or nil (no gap open, or no wall between).
local function gap_way(w, from, dest)
  if not gap_open(w) or not wall_between(w, from, dest) then return nil end
  return go(w.gap, defines.distraction.none, 1.5)
end
-- A way of legs (a cost map's, round the fire) inside the base: a leg that would cross a wall of the foe's dropped, so its
-- herd walks its way inside and not out through the wall and back (pushing in along such a way, a herd of 200 broke 25
-- wall pieces; herd test, mega). The first leg through its gap when a wall stands between.
-- And once in (no wall between it and where it goes), a leg that would put a wall between them again dropped: the cost
-- map's way, priced from its breach outside before the gap opened, ran back out through the gap and round the walls to
-- the far side, to break in there (the user, 2026-11-05, on the trailer's film: "it broke the wall but we only show a
-- handful of biters rushing through? Plus it seemed to break the wall from the inside to escape?": 15 s after its gap
-- opened 0 of 194 were inside, the dozen that had been walking out again, and it took 27 s to a heart 50 tiles in).
local function inside_legs(w, from, pts, radius)
  local cmds, prev = {}, from
  local dest = pts[#pts]
  local first = dest and gap_way(w, from, dest)
  if first then cmds[1] = first; prev = w.gap end
  for i, q in ipairs(pts) do
    if i == #pts or not (wall_between(w, prev, q) or (not wall_between(w, prev, dest) and wall_between(w, q, dest))) then
      cmds[#cmds + 1] = go(q, defines.distraction.none, radius or 6)
      prev = q
    end
  end
  return cmds
end
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
  local c, hx, hy, reach = base_box(s, target, forces)
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
    no_probe = opts.no_probe, force_deep = opts.deep, choice = opts.choice, plan = opts.plan, sweep = opts.sweep, trust = opts.trust,
    cut = opts.cut, sig = opts.sig, wait_cut = opts.wait_cut, spread = opts.spread,
    loop = reach + LOOP_SPARE + mem.extra, stage = "scout", t = game.tick, t0 = game.tick, members = {}, seen = {},
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
  w.sent = w.size
  -- Its screen (a siege's: farm.lua siege_size), the first of its members of that breed.
  if opts.fodder then
    w.fodder_set = {}
    local n = 0
    for _, u in ipairs(w.members) do
      if n < opts.fodder.n and u.valid and u.name == opts.fodder.name then w.fodder_set[u.unit_number] = true; n = n + 1 end
    end
    w.fodder_n = n
    if n == 0 then w.fodder_set = nil end
  end
  w.worth = herd.strength(w.members)
  w.made_of = {}
  for _, u in ipairs(w.members) do w.made_of[u.name] = (w.made_of[u.name] or 0) + 1 end
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
local DETOUR = 64             -- tiles off the line of its leg: the pathfinder went round, no way through there
local DETOUR_PER = 2         -- and this many more for each square root of its number (a big herd strings out)
local DETOUR_BACK = 3        -- the legs before the one it is on that still count as its way
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

-- Debugging (debug_tune march_trace): a wave's cost map to script-output/landing-party/costmaps/wave<id>-<tag>.json, each
-- cell reached its price to cross and what reaching it cost (-1: no way), with `extra` (its way, its trail);
-- scripts/raidmap.py draws them.
local function dump_costmap(w, cm, tag, extra)
  if not storage.march_trace then return end
  local cells = {}
  for k, c in pairs(cm.cost) do
    local p = cm.cell_cost[k]
    cells[#cells + 1] = {math.floor(k / cm.h), k % cm.h, c >= math.huge and -1 or c, p and (p >= math.huge and -1 or p) or 0}
  end
  for k, p in pairs(cm.cell_cost) do
    if not cm.cost[k] then cells[#cells + 1] = {math.floor(k / cm.h), k % cm.h, -1, p >= math.huge and -1 or p} end
  end
  local out = {wave = w.id, tag = tag, tick = game.tick, x0 = cm.x0, y0 = cm.y0, size = cm.size, w = cm.w, cells = cells}
  for k, v in pairs(extra or {}) do out[k] = v end
  helpers.write_file(string.format("landing-party/costmaps/wave%d-%s.json", w.id, tag), helpers.table_to_json(out))
end

local function xy_list(list)
  local out = {}
  for _, q in ipairs(list or {}) do out[#out + 1] = {q.x or q[1], q.y or q[2]} end
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
  -- (Its way priced by everyone who shoots it, the corporations' camps and their armed units too, not its target's turrets
  -- alone.)
  local fmap = firemap.read(s, mid, radius * firemap.BOX, hostiles(), herd.price_of, threat.ARMED)
  local cm = costmap.read(s, mid, radius, forces, {fire = fmap, n = #herd_units(w), from = last, deaths = herd.deaths(), blocked = herd.blocked(), hidden = herd.hidden_cost(foe_name(w)), scale = B.mind.calibrate and know.scale("biotech", foe_name(w)) or 1,
    cell = radius > WAY_REACH and costmap.CELL * 2 or nil})
  local way = costmap.way_in(cm, c)
  if way then
    weigh(math.floor(math.atan2(way.start.y - c.y, way.start.x - c.x) / (math.pi / 4) + 0.5) % 8, {way.start.x, way.start.y}, true)
    local top = cands[#cands]
    top.score, top.lost = -1, way.cost
    w.way_in = {start = {way.start.x, way.start.y}, breach = {way.breach.x, way.breach.y}, lost = way.cost,
      cover = #firemap.cover(fmap, way.breach)}
    -- (And its way there, for when the router finds none: cells' middles round fire and the deaths it met.)
    w.way_path = costmap.path(cm, way.start)
  end
  dump_costmap(w, cm, "stage", {from = last and {last.x, last.y}, target = {c.x, c.y},
    way = way and {start = {way.start.x, way.start.y}, breach = {way.breach.x, way.breach.y}, cost = way.cost} or nil,
    path = xy_list(w.way_path)})
  -- (Ties by face, then a face before the way in: table.sort is not stable, and a tie went either way from run to run.)
  table.sort(cands, function(a, b)
    if a.score ~= b.score then return a.score < b.score end
    if a.k ~= b.k then return a.k < b.k end
    return not a.way and b.way
  end)
  return cands, table.concat(why, " ")
end

local finish     -- below: a wave over, its biters back in their pens' stock
local DEAR = 1    -- a way in costing it, there and back, this many times its number: it does not come

-- Its big bursters sent at the guns covering where it breaks in (send_big_bursters) each take about BURST_OPENS of one:
-- its way in costs that share less, and the bursters themselves (the wall lab, 2026-10-28: 14 at a stretch of nw's north
-- wall broke 12 to 20 of its lasers). (Its walls and mines are left: what they cost stays.)
herd.BURST_OPENS = 0.9
-- The share of the guns covering a breach its bursters open.
-- openable: of those guns, the ones its bursters can reach (within their blast of the wall they stop at, herd.plan): a
-- flamethrower line behind a wall of lasers it cannot (its bursters, sent at the flamethrowers first, stuck biting the
-- wall under the lasers and burst there; the flamethrowers stood, and burned 114 of 120; 2026-10-28). Nil: all of them.
-- What its bursters open against a foe, learned (know: opens) from what each siege's bursts broke over the bursters it
-- sent, BURST_OPENS before any: against the siege lab's laser wall 2 of 17 reached their gun and their 2 blasts broke 9,
-- half a gun a burster sent where it reckoned 0.9, and it laid the same siege four times (2026-10-30).
herd.OPENS_MIN = 0.05
function herd.opens(foe)
  local o = foe and know.of("biotech").opens
  return o and o[type(foe) == "string" and foe or foe.name] or herd.BURST_OPENS
end
-- What share of the big bursters it sends set off (at their gun or the wall: herd.lua detonate), learned per foe from each
-- siege; all of them before any. (Killed short, a burster fizzles: the siege test's laser wall killed 12 of 12.)
function herd.reach(foe)
  local r = foe and know.of("biotech").reach
  return r and r[type(foe) == "string" and foe or foe.name] or 1
end
-- What share of them reach a wall alive at all (set off where they were sent), learned as reach is but not halved when
-- every one set off and its wave still stood at a wall: the size of a rank (sequence: its rams in ranks, the first at the
-- wall, the next through the gap at the wall behind it). (The adaptive tactics consult, 2026-11-05: its doubled rams all
-- went at the outer of nwa's four lines at once.)
function herd.reach_alive(foe)
  local r = foe and know.of("biotech").reach_alive
  return r and r[type(foe) == "string" and foe or foe.name] or 1
end
function herd.opened(cover, bursters, openable, foe)
  if (bursters or 0) <= 0 or not cover or cover <= 0 then return 0 end
  return math.min(openable or cover, bursters * herd.opens(foe)) / cover
end
-- (Its bursters are spent at the wall, not lost crossing it: they are no part of the way's price, nor of the strength that
-- pays it, herd.strength. Counted as lost at a big burster's health, each asked 40 mediums more of the herd.)
function herd.way_cost(lost, cover, bursters, openable, foe)
  bursters = bursters or 0
  if bursters <= 0 or not cover or cover <= 0 then return lost end
  return lost * (1 - herd.opened(cover, bursters, openable, foe))
end

-- Its strength and its losses in health, in mediums (a medium biter's health to the unit: the breed its priors were set
-- by), not in heads (the user, 2026-10-30): a way priced at 700 heads asked 700 of anything, 9,000 biomass hatched about 90
-- of its dearest breeds, each with the health of 40 mediums, and every siege on nw's walls was refused (2026-10-29).
-- Health alone: what a breed resists is left to the prices it learns (know.price, learned in mediums too).
herd.worth = attempt.worth   -- (one measure for every attacker: attempt.lua)
-- Of a list of units (entities or names to hatch), its big bursters left out (spent at the wall: herd.way_cost).
function herd.strength(units)
  local total = 0
  for _, u in ipairs(units) do
    local name = type(u) == "string" and u or (u.valid and u.name)
    if name and name ~= "lp-bred-big-burster" then total = total + herd.worth(name) end
  end
  return total
end

-- Whether a wave of strength n (herd.strength) goes at a way in costing it `lost` (there and back, DEAR times its strength
-- or more: it does not).
-- One test, asked by the farm before it sends and by the wave when it stages: the farm sent waves its own odds gave
-- nothing, and each turned home at the wave's (18 of 18 on a megabase; a context-free review, 2026-10-28).
function herd.affords(n, lost) return 2 * lost < DEAR * n end

-- Its plan for a wave from `from` to `target` (the user, 2026-10-28: "plan once and follow it"; it sees the whole map from
-- the start): one cost map (its fire, walls, deaths, blocked ground, hidden price, calibration), the cheapest way, where it
-- starts (out of all fire) and breaks in, what it costs and how many guns cover the breach. Made by the farm before it
-- sends, followed by the wave (mark): the farm read a way in at 8 its wave read at 83 from where its scout ended, and 12
-- of 16 waves turned home at the gate (2026-10-28). nil: no way. forces: whom it goes at (names or forces).
-- How far a marching herd of n strings out round its middle, as its way keeps from fire (a wave of 91 spread 30 tiles).
-- (Half that, the root of its number: at twice it, every way on a deathworld read dearer and its razing fell from 662 to
-- 307 over three timings; 2026-10-28.)
function herd.spread(n) return math.ceil(math.sqrt(n or 0)) end
herd.PLAN_CELL = costmap.CELL   -- at the grain its waves read near their target (at 32, a deathworld's razing halved)
-- (Its farm's reading this tick, when it was read from here and reaches the target: the same map, farm.lua ways_from.
-- Kept for the tick alone, so every game reads the same: a map kept longer would decide differently after a load.)
herd.shared = nil
herd.SHARED_FOR = 5 * 3600   -- a reading's map is its plans' while this young (farm.lua's WAYS_FOR)
local SHARE_NEAR = 128          -- a sliced reading serves a wave leaving this near where it was read from (its pens 70 off, nw)
function herd.plan(surface, from, target, forces, n)
  from, target = xy(from), xy(target)
  local fmap, cm
  local sm = herd.shared
  -- (The reading for as long as it holds, SHARED_FOR, not its tick alone: its sieges and cuts are planned on it a step
  -- after it, farm.ways_step.)
  -- (A reading read in slices, over a big base, serves a wave leaving within SHARE_NEAR of where it was read from: its
  -- incubators are not its farm's middle, and each wave read the whole way afresh, 215 ms in a tick, the user's nw save.)
  local near = sm and sm.sliced and (sm.from[1] - from.x) ^ 2 + (sm.from[2] - from.y) ^ 2 <= SHARE_NEAR * SHARE_NEAR
  if sm and game.tick - sm.tick < herd.SHARED_FOR and (near or sm.from[1] == from.x and sm.from[2] == from.y) and costmap.cost(sm.cm, target) then
    fmap, cm = sm.fmap, sm.cm
  else
    local mid = {x = (from.x + target.x) / 2, y = (from.y + target.y) / 2}
    local radius = math.max(WAY_REACH, math.sqrt(d2(from, target)) / 2 + WAY_MARGIN)
    fmap = firemap.read(surface, mid, radius * firemap.BOX, hostiles(), herd.price_of, threat.ARMED)
    local name = forces[1] and (type(forces[1]) == "string" and forces[1] or forces[1].name) or "player"
    cm = costmap.read(surface, mid, radius, forces, {fire = fmap, n = n, from = from, deaths = herd.deaths(),
      blocked = herd.blocked(), hidden = herd.hidden_cost(name), scale = B.mind.calibrate and know.scale("biotech", name) or 1,
      cell = herd.PLAN_CELL, margin = herd.spread(n), ground_cost = costmap.GROUND_COST, wall_forces = hostiles()})
  end
  local way = costmap.staging(cm, target)
  local path = costmap.path(cm, target)
  -- (Its maps, for a spread's points read on them the same tick, herd.spread_points: not kept.)
  herd.last_maps = {cm = cm, fmap = fmap, tick = game.tick}
  -- (Traced: its plan's own map, for the siege lab's page: every cell's price and what reaching it costs.)
  if storage.march_trace then
    local cells = {}
    for k, c in pairs(cm.cell_cost) do
      local r = cm.cost[k]
      cells[#cells + 1] = {math.floor(k / cm.h), k % cm.h, r and (r >= math.huge and -1 or r) or -1, c >= math.huge and -1 or c}
    end
    helpers.write_file(string.format("landing-party/costmaps/plan-%d.json", game.tick), helpers.table_to_json({tick = game.tick,
      x0 = cm.x0, y0 = cm.y0, size = cm.size, w = cm.w, cells = cells, target = {target.x, target.y},
      breach = way and {way.breach.x, way.breach.y}, cost = way and way.cost}))
  end
  if not (way and path) or way.cost >= math.huge then return nil end
  local pts, upto = {}, #path
  for i, q in ipairs(path) do
    pts[#pts + 1] = {q.x, q.y}
    if q.x == way.start.x and q.y == way.start.y then upto = i end
  end
  -- (And its foe's mines from where it starts on: what its sweep will go at, herd.sweep.)
  local rest = {}
  for i = upto, #path do rest[#rest + 1] = path[i] end
  if #rest < 2 then rest[#rest + 1] = target end
  local mines = herd.mines_along(surface, forces, rest, herd.spread(n) + 3, rest[1])
  -- The guns covering its breach its bursters can reach: within their blast of a wall piece by the breach (where they stop
  -- and burst), or all of them where no wall stands in the way.
  local cover = firemap.cover(fmap, way.breach)
  local walls = surface.find_entities_filtered{position = way.breach, radius = threat.far(), type = WALLS, force = forces}
  local openable = 0
  for _, t in ipairs(cover) do
    local reach = #walls == 0
    for _, wl in ipairs(walls) do
      if d2(wl.position, t.position) <= shared.BIG_BURST.r * shared.BIG_BURST.r then reach = true; break end
    end
    if reach then openable = openable + 1 end
  end
  -- (And whether a wall stands at its breach, what its big bursters are rams for: farm.lua siege_size. The walls round
  -- its breach its guns' openable reads: within a burster's blast of its breach point alone, the middle of a 16-tile cell,
  -- the user's fort read as unwalled, and a siege of 45 behemoths went with no ram.)
  local walled = #walls > 0
  -- (What the guns covering its breach cost to cross: a siege's screen pays it, farm.lua siege_size.)
  local cover_price = 0
  for _, t in ipairs(cover) do cover_price = cover_price + herd.price_of(t) end
  -- (What of its way is standing at the wall: not paid by a herd that waits for its rams, farm.lua siege_size.)
  local standing = math.min(costmap.wall_along(cm, target), way.cost)
  -- (Its sweep paid for as many as the fire on each spot's way takes, herd.sweepers_at, not one a cluster: 0.2.352.)
  local spots = herd.sapper_spots(mines, rest[1])
  local sappers = 0
  for _, k in ipairs(herd.sweepers_at(surface, forces, spots, rest[1])) do sappers = sappers + k end
  return {path = pts, upto = upto, start = {way.start.x, way.start.y}, breach = {way.breach.x, way.breach.y},
    cost = way.cost, cover = #cover, openable = openable, target = {target.x, target.y}, mines = #mines, walled = walled,
    sappers = sappers,
    standing = standing, cover_price = cover_price}
end

-- The spread assault's points (the adaptive tactics consult, 2026-11-05, R2; the user: "many rams at many points, one
-- herd for the first hole"): along its foe's wall within a leg (LEG) either side of a plan's breach, the outermost piece
-- every BIN tiles across its way in, the plan's own breach first, then the cheapest by the fire covering it
-- (firemap.cost), each taken where no burning turret (a flamethrower: e.burn) covers it and a point already taken, and a
-- ram's blast (BIG_BURST_R) or more from each; refused where its way from the farm costs more over the breach's than the
-- plan's way in does (its herd's rush there crosses more fire than the plan priced). Lasers may cover two: one fires on
-- one target whichever point it is. At most `most`. Read on the plan's own maps (herd.plan, the same tick). Returns its
-- points ({x, y, cover: the guns covering it, cost}), nil with fewer than two.
herd.SPREAD_BIN = 2
function herd.spread_points(surface, pl, forces, most)
  local lm = herd.last_maps
  if not (pl and lm and lm.tick == game.tick) or most < 2 then return nil end
  local fmap, cm = lm.fmap, lm.cm
  local b, st0 = xy(pl.breach), xy(pl.start)
  local dx, dy = b.x - st0.x, b.y - st0.y
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1 then return nil end
  dx, dy = dx / len, dy / len
  local px, py = -dy, dx
  local bins = {}
  for _, e in ipairs(surface.find_entities_filtered{position = b, radius = LEG + 2 * shared.BIG_BURST.r, type = WALLS, force = forces}) do
    local q = e.position
    local t = (q.x - b.x) * px + (q.y - b.y) * py
    if math.abs(t) <= LEG then
      local k = math.floor(t / herd.SPREAD_BIN + 0.5)
      local depth = (q.x - b.x) * dx + (q.y - b.y) * dy
      local c = bins[k]
      if not c or depth < c.depth then bins[k] = {x = q.x, y = q.y, depth = depth, t = t} end
    end
  end
  local here = costmap.cost(cm, b)
  local cands = {}
  for _, c in pairs(bins) do
    local reach = costmap.cost(cm, c)
    if reach and reach < math.huge and (not here or reach - here <= pl.cost) then
      local burn, cover = {}, 0
      for _, t in ipairs(firemap.entries(fmap, c)) do
        cover = cover + 1
        if t.burn and t.e.valid then burn[t.e.unit_number] = true end
      end
      c.cost, c.cover, c.burn = firemap.cost(fmap, c), cover, burn
      cands[#cands + 1] = c
    end
  end
  if #cands < 2 then return nil end
  table.sort(cands, function(a1, a2)
    if math.abs(a1.t) < herd.SPREAD_BIN / 2 + 1e-6 and math.abs(a2.t) >= herd.SPREAD_BIN / 2 + 1e-6 then return true end
    if math.abs(a2.t) < herd.SPREAD_BIN / 2 + 1e-6 and math.abs(a1.t) >= herd.SPREAD_BIN / 2 + 1e-6 then return false end
    if math.abs(a1.cost - a2.cost) > 1e-6 then return a1.cost < a2.cost end
    if math.abs(a1.t) ~= math.abs(a2.t) then return math.abs(a1.t) < math.abs(a2.t) end
    return a1.t < a2.t
  end)
  local out = {}
  for _, c in ipairs(cands) do
    if #out >= most then break end
    local ok = true
    for _, o in ipairs(out) do
      if d2(o, c) < shared.BIG_BURST.r * shared.BIG_BURST.r then ok = false; break end
      for id in pairs(c.burn) do if o.burn[id] then ok = false; break end end
      if not ok then break end
    end
    if ok then out[#out + 1] = c end
  end
  if #out < 2 then return nil end
  local pts = {}
  for _, c in ipairs(out) do pts[#pts + 1] = {x = c.x, y = c.y, cover = c.cover, cost = c.cost} end
  return pts
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
  -- open, and its herd broke in at that corner; 2026-10-27). (Not from its pens: read from there, 780 tiles off on a
  -- deathworld, its ways ran along the ring, and its razing fell from 1,147 to 82 and 418; 2026-10-27.)
  if herd.exposure then
    local s = game.surfaces[w.surface]
    while #trail > 1 and herd.exposure(s, {trail[#trail].x, trail[#trail].y}, foes(w)) > 0 do table.remove(trail) end
  end
  local last = trail[#trail]
  local way
  if w.plan then
    -- Its farm's plan (herd.plan): from its pen along the planned way to where it starts, breaking in where it breaks in.
    local pl = w.plan
    trail = {trail[1]}
    way = {}
    for i = 1, pl.upto do way[#way + 1] = pl.path[i] end
    w.mark, w.staged = xy(pl.start), true
    w.mark_sector = math.floor(math.atan2(pl.start[2] - pl.target[2], pl.start[1] - pl.target[1]) / (math.pi / 4) + 0.5) % 8
    w.breach_at = xy(pl.breach)
    w.way_in = {start = pl.start, breach = pl.breach, lost = pl.cost, cover = pl.cover, openable = pl.openable}
    log(w, string.format("follows its farm's plan: in at %.0f,%.0f from %.0f,%.0f, costing %.0f (%d guns cover where it breaks in), %d points",
      pl.breach[1], pl.breach[2], pl.start[1], pl.start[2], pl.cost, pl.cover, #way))
  else
  local cands, why = stage_choice(w, last)
  -- The approaches in order, the first its herd can be routed to round the turrets known to it (wide, as a long raid's,
  -- when the plain search runs dry; a coarser grid for a long way): on the player's deathworld the best-scored staging
  -- points lay in pockets ringed by turret reach, beyond every turret but with no way in, and every wave walked straight.
  local staged, tried = nil, {}
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
    -- The cost map's own way in, unrouted: it goes all the same, its trail straight from where the route ran dry. The router
    -- holds the foe's buildings solid and its turrets' reach closed; the cost map prices them, breaking a wall or a field of
    -- solar panels for what they cost, and on a megabase every soft heart lay behind walls no gun covered: "enclosed", and
    -- its waves retargeted to a minefield (2026-10-27).
    if c.way then
      way = {}
      for _, q in ipairs(w.way_path or {}) do way[#way + 1] = {q.x, q.y} end
      staged = c
      tried[#tried + 1] = "the cost map's way in, unrouted: it goes straight"
      break
    end
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
        -- The cheapest to reach by its cost map from that edge (its fire, the deaths it met, its hidden price), not the
        -- nearest: the nearest was an assembler in a minefield on a megabase, and five waves died there, 2026-10-27.
        local fmap = firemap.read(s, e, EDGE_SEARCH * firemap.BOX, hostiles(), herd.price_of, threat.ARMED)
        local cm = costmap.read(s, e, EDGE_SEARCH, foes(w), {fire = fmap, n = #herd_units(w), from = e, deaths = herd.deaths(), blocked = herd.blocked(),
          hidden = herd.hidden_cost(foe_name(w)), scale = B.mind.calibrate and know.scale("biotech", foe_name(w)) or 1,
          cell = costmap.CELL * 2})
        local best, bd
        for _, x in ipairs(near) do
          local d = costmap.cost(cm, x.position)
          if d and (not bd or d < bd) then best, bd = x, d end
        end
        -- Its way in now that cost (the refusal below reads it).
        if best then w.way_in = {start = {e.x, e.y}, breach = {best.position.x, best.position.y}, lost = bd}; w.aimed = {x = g.x, y = g.y} end
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
    -- Staged on its cheapest way in (costmap), it breaks in where that way does (breach_at, as a probe's silent turret):
    -- aimed straight from there at its target, it walked back into the minefield the way had gone round, and lost 18 of
    -- 28 there to mines the wave before had found (2026-10-27).
    if staged.way and w.way_in and w.way_in.breach then w.breach_at = {x = w.way_in.breach[1], y = w.way_in.breach[2]} end
    log(w, string.format("stages at %.0f,%.0f (face %d, fire %.1f; by face %s)%s; %s", staged.at.x, staged.at.y, staged.k,
      staged.fire, why, #tried > 0 and (" (not reachable: " .. table.concat(tried, ", ") .. ")") or "",
      way and string.format("its trail routed round turrets (%d points)", #way) or "no route found: its trail straight"))
  end
  -- Its cheapest way in dearer than it can pay (there and back, DEAR times its number or more): it does not come (at half
  -- its number it turned back from raids that lost about half and did their work, the herd belt and probe tests), and its farm weighs that place at what the wave found (know: dear), not at its rays (sent all the same, waves
  -- of 25 went at 14 to 22 lasers on a megabase whose way in the farm's rays had read as free, and 107 of 108 died;
  -- 2026-10-27, the farm and the wave two models of the way in until the farm reads the cost map too).
  local big = 0
  for _, u in ipairs(w.members) do if u.valid and u.name == "lp-bred-big-burster" then big = big + 1 end end
  local lost = w.way_in and herd.way_cost(w.way_in.lost, w.way_in.cover, big, w.way_in.openable, foe_name(w))
  if w.way_in and big > 0 then
    log(w, string.format("its way in costs %.0f, %.0f with its %d big bursters at the %d guns covering where it breaks in",
      w.way_in.lost, lost, big, w.way_in.cover or 0))
  end
  local strength = herd.strength(herd_units(w))
  -- (Not a probe, nor a siege its attempts proved: what it learns or knows there, not its prices, sends it, w.trust.)
  if w.way_in and not w.trust and not herd.affords(strength, lost) then
    local k = know.of("biotech")
    k.dear = k.dear or {}
    k.dear[herd.dear_key(foes(w)[1], w.goal or w.center)] = {lost = w.way_in.lost, tick = game.tick}
    -- (And the farm's target, when it went for another at the edge: the farm weighs the target it chose.)
    if w.aimed then k.dear[herd.dear_key(foes(w)[1], w.aimed)] = {lost = w.way_in.lost, tick = game.tick} end
    log(w, string.format("its way in would cost %.0f of its own (in mediums), there and back as much as its %d (%.0f): it does not come",
      lost, #herd_units(w), strength))
    if w.scout and w.scout.valid then w.scout.commandable.set_command(go(gate(w), defines.distraction.none, 6)) end
    return finish(w, "too dear")
  end
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
  if storage.march_trace then
    helpers.write_file(string.format("landing-party/costmaps/wave%d-trail.json", w.id),
      helpers.table_to_json({wave = w.id, trail = xy_list(trail), mark = {w.mark.x, w.mark.y}, size = #herd_units(w)}))
  end
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

-- A siege's screen: its cheapest breed, sent at the wall ahead of its rams (farm.lua siege_size, sequence).
herd.FODDER = "lp-bred-small-biter"
local WAIT_TICKS, WAITS = 120, 15   -- a leg's wait for its stragglers, and how many at most before it goes on regardless
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
  -- Its herd together before each leg: its members' middle within twice its spread and a cell of its group, else the group
  -- stops WAIT_TICKS for them. (Its group ran on ahead of its slow breeds, its members' middle 100 to 130 tiles behind, and
  -- they made their own way to it, round the user's fort and over its mines: 30 lost on the march; the siege lab.)
  -- (The middle of those in its group: counted with the strays it had sent home, its middle stayed behind it as they
  -- walked back, and every leg it waited its 15 waits; its cutters took 23 minutes to a pole 100 seconds off, the fed lab
  -- fort, 2026-10-30.)
  if w.group.valid and w.leg > 2 and (w.waits or 0) < WAITS then
    local sx, sy, n = 0, 0, 0
    for _, u in ipairs(w.group.members) do
      if u.valid then sx, sy, n = sx + u.position.x, sy + u.position.y, n + 1 end
    end
    local mid = n > 0 and {x = sx / n, y = sy / n} or w.group.position
    local r = 2 * herd.spread(n) + costmap.CELL
    if d2(mid, w.group.position) > r * r then
      w.waiting, w.waits = true, (w.waits or 0) + 1
      w.group.set_command{type = defines.command.stop, ticks_to_wait = WAIT_TICKS, distraction = defines.distraction.none}
      return
    end
  end
  w.waits = 0
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
-- (Not what feeds its guns: worth STARVED a turret it would starve in its value map, the ammunition belt behind a ring of
-- guns drew whole waves from the factory and they razed two thirds as much, three timings on a deathworld, 2026-10-27;
-- inside it cuts the best feeds it passes, targets.)
local function read_base(w, at)
  local s = game.surfaces[w.surface]
  local forces = foes(w)
  local vmap = valuemap.read(s, at, HEART_REACH, forces, valuemap.CORE)
  -- (And the artillery that shells its incubators: SHELLS for each it reaches.)
  for _, a in ipairs(s.find_entities_filtered{position = at, radius = HEART_REACH, type = ARTILLERY, force = forces}) do
    local n = herd.shelling(a)
    if n > 0 then valuemap.add(vmap, a, valuemap.SHELLS * n) end
  end
  return vmap, firemap.read(s, at, HEART_REACH * firemap.BOX, forces, herd.price_of)
end

-- The soft hearts of the base from where it stands (valuemap.hearts; the way there priced from here, costmap), none
-- nearer than min; with the maps it read. Its box was the turrets round what it was sent at, and on a deathworld visit, 2026-10-27, that
-- was a stretch of a wall round a factory with no turret in it: the heart it saw was "1 thing, under fire", and the
-- factory 150 tiles in went untouched.
local function hearts_from(w, at, min)
  local vmap, fmap = read_base(w, at)
  local n = #herd_units(w)
  local cm = costmap.read(game.surfaces[w.surface], at, HEART_REACH, foes(w), {fire = fmap, n = n, from = at, deaths = herd.deaths(), blocked = herd.blocked(), hidden = herd.hidden_cost(foe_name(w)), scale = B.mind.calibrate and know.scale("biotech", foe_name(w)) or 1})
  -- (Inside, one way: what reaching it costs from here, and it goes if it gets there with any of its own (keeps_lost asks a
  -- way there and back keeping half, so a quarter of it). Asked that from its breach, where the wall's guns still covered
  -- every way off it, no heart was ever within reach and every wave that broke in turned home; 2026-10-28. Whether it
  -- leaves after is its stay rule's.)
  -- (One way, valuemap.keeps_one_way: it is on its way in, and whether it leaves after is its stay rule's. By the way there
  -- and back keeping half, no heart past a wall of lasers was ever worth it once the wall was down; 2026-10-28.)
  local hearts = valuemap.hearts(vmap, fmap, herd.strength(herd_units(w)), at, HEART_REACH, {min = min, keeps = valuemap.keeps_one_way,
    lost = function(mid) return costmap.cost(cm, mid) end})
  return hearts, vmap, fmap, cm
end

-- What share of what stands within SIGHT of `at` a herd arriving there `arrive` strong breaks before its stay rule takes
-- it out (half its size lost: valuemap.HOLD). Its bite (threat.bite, each unit's attack a second) wears down what is worth
-- something there (valuemap.each_near) while the guns covering `at` take its number down: each turret's price is what
-- a crossing of its reach costs (firemap), so standing in it costs that price each time the herd could have crossed it,
-- 2r at its pace. Its bite falls as it loses: broken by t, bite * (arrive * t - loss * t^2 / 2), until arrive - loss * t is
-- half its size. (Priced on the way there alone, a heart four lasers guarded read cheap; the wave reached it, stayed,
-- lost 17 to them and broke little: herd test, core, 2026-10-29.)
-- What share of its prototype bite a herd inside deals: the rest of its time it walks between targets. Measured
-- (stay_end, herd test, 2026-10-29): 7.3 to 11.7 health a unit-second, guns and walls with what is worth something, on
-- both bases, heart and edge, against 25.4 read; its losses there read within a fifth where it stayed long.
local BITE_SHARE = 0.4

local function stay_share(w, at, arrive, fmap, vmap)
  local units = herd_units(w)
  if #units == 0 or arrive <= 0 then return 0 end
  local bite, pace = 0, 0
  for _, u in ipairs(units) do
    bite = bite + threat.bite(u.name)
    pace = pace + (u.prototype.speed or 0) * 60
  end
  bite, pace = BITE_SHARE * bite / #units, pace / #units
  -- Its biters spread over what is there (each its own target), so the fire it stands in is the fire on each thing it
  -- breaks, for as long as that takes: weighted by its health. (Read at the heart alone, the building there with the least
  -- fire on it, the guns round it read as nothing: herd test, 2026-10-29.)
  local need, loss = 0, 0
  valuemap.each_near(vmap, at, SIGHT, function(e)
    local h = e.health or 0
    need = need + h
    for _, t in ipairs(firemap.entries(fmap, e.position)) do loss = loss + h * t.p * pace / (2 * t.r) end
  end)
  if need <= 0 then return 1 end
  if bite <= 0 then return 0 end
  loss = loss / need
  -- (What it read, for the measure of its stay: stay_measure.)
  local read = {bite = bite, loss = loss, need = need, arrive = arrive}
  -- The guns standing among what it came for take its bite first: they fire on it, it turns on them. (At a heart four
  -- lasers guarded, a wave broke 4700 health in its stay and 350 of it was worth something: herd test, core, 2026-10-29.)
  -- (The guns whose reach covers it, not all within its sight: those read the plain base's heart 0% broken, where a wave
  -- forced to it broke 48%.)
  local guns = 0
  for _, t in ipairs(firemap.entries(fmap, at)) do guns = guns + (t.e.valid and t.e.max_health or 0) end
  read.guns = guns
  local room = arrive - (w.size or #units) * valuemap.HOLD
  if room <= 0 then return 0, read end
  local t = loss > 0 and room / loss or math.huge
  read.t = t
  local broken = loss > 0 and bite * (arrive * t - loss * t * t / 2) or math.huge
  return math.min(1, math.max(0, broken - guns) / need), read
end

-- A stay measured against its price (stay_share): from its start (at the heart, or inside at the edge) to its end, the
-- health of what it broke a unit-second against the bite it read, and its losses a second against the fire's. For the
-- herd test (2026-10-29: priced, a heart four lasers guarded would be 81% to 100% broken; the waves broke half or less).
local function stay_begin(w)
  if w.stay_m then return end
  w.stay_m = {t = game.tick, last = game.tick, n = alive(w), hp = 0, us = 0, broke = 0}
end

local function stay_end(w)
  local m = w.stay_m
  if not m or m.done then return end
  m.done = true
  local secs = math.max(1, game.tick - m.t) / 60
  local r = w.stay_read
  if not r then
    -- (Not priced: a siege's or a plan's own target, not a choice of heart or edge.)
    log(w, string.format("its stay measured: %.0f s, %d to %d alive, broke %d (%.0f health, %.0f with guns and walls): "
      .. "%.2f health a unit-second with guns and walls, lost %.3f a second, unpriced", secs, m.n, alive(w), m.broke, m.hp,
      m.all or 0, (m.all or 0) / math.max(1, m.us / 60), (m.n - alive(w)) / secs))
    return
  end
  log(w, string.format("its stay measured: %.0f s, %d to %d alive, broke %d (%.0f health, %.0f with guns and walls): "
    .. "%.2f health a unit-second, %.2f with guns and walls (read %.2f), lost %.3f a second (read %.3f, over %.0f s), %.0f%% of the %.0f there (read %.0f%%, guns on it %.0f)",
    secs, m.n, alive(w), m.broke, m.hp, m.all or 0, m.hp / math.max(1, m.us / 60), (m.all or 0) / math.max(1, m.us / 60),
    r.bite or 0, (m.n - alive(w)) / secs,
    r.loss or 0, r.t or 0, 100 * m.hp / math.max(1, r.need or 0), r.need or 0, 100 * (r.share or 0), r.guns or 0))
end

-- The heart of the base it broke into: its best soft heart from the breach (hearts_from). Its worth there and at the edge:
-- what stands within SIGHT (valuemap), each over 1 plus the guns on it (and on the way in, for the heart). Returns {at,
-- worth, edge, far, why} or nil.
local function deep_plan(w, h, forced)
  local hearts, vmap, fmap, cm = hearts_from(w, h)
  local best = hearts[1]
  if not (best and best.at) then
    log(w, string.format("no heart it can take within %d of the breach", HEART_REACH))
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
  local n = #herd_units(w)
  local edge_keeps = valuemap.keeps_lost(herd.strength(herd_units(w)), costmap.cost(cm, w.inside) or 0)
  local edge_stay, edge_read = stay_share(w, w.inside, n * edge_keeps, fmap, vmap)
  local edge = here(w.inside) * edge_keeps * edge_stay
  -- (The fire on the way counted whole: at half, a ring of turrets between a mining outpost it had broken into and the
  -- factory behind it read cheap, and it left 95 drills for the factory, and lost half its number in the ring; 2026-10-27.)
  -- (And what it breaks there before the stay rule takes it out: stay_share.)
  local stay, heart_read = stay_share(w, at, n * best.keeps, fmap, vmap)
  if edge_read then edge_read.share = edge_stay end
  if heart_read then heart_read.share = stay end
  local heart = here(at) * best.keeps * stay
  local l = lessons()[lesson_key(w.center)]
  if l and (l.deep_lost or 0) > 0 then heart = heart * 0.5 ^ l.deep_lost end
  if l and l.last_deep then heart = heart * DEEP_AGAIN end
  -- (And the way there it priced: the cost map's, round the fire, cell by cell.)
  local way = {}
  for _, q in ipairs(costmap.path(cm, at) or {}) do way[#way + 1] = {x = q.x, y = q.y} end
  return {at = at, worth = heart, edge = edge, far = far, way = way, heart_read = heart_read, edge_read = edge_read,
    why = string.format("the heart %.1f (worth %.0f, the way there %.1f of its own, %.0f%% broken before it must leave) against the edge %.1f (%.0f%%)",
      heart, here(at), best.lost or 0, 100 * stay, edge, 100 * edge_stay)}
end

-- Its plan at the breach: the heart when worth it, or when told (/lp wave deep). Its tells: the trail runs on to the
-- heart, its leader marked.
local function choose_plan(w)
  -- From where its herd stands, on the guns still standing once its bursters and sweep have gone ahead (sequence;
  -- read at the breach before they had, every way off it was under every gun, and no heart was ever within reach;
  -- 2026-10-28).
  local at = w.group and w.group.valid and w.group.position or where(w)
  local p = deep_plan(w, at, w.force_deep)
  if not p then return end
  -- (force_deep false, tests: the edge whatever it is worth, to compare.)
  local deep = w.force_deep or (w.force_deep ~= false and p.worth > DEEP_MARGIN * p.edge)
  log(w, string.format("%s: %s", deep and "strikes for the heart" or "raids the edge", p.why))
  w.stay_read = deep and p.heart_read or p.edge_read
  if not deep then return end
  w.deep = {at = p.at, t = game.tick, way = p.way}
  local trail = {w.breach}
  for _, q in ipairs(p.way or {}) do trail[#trail + 1] = q end
  trail[#trail + 1] = p.at
  local lead = herd_units(w)[1]
  if lead and lead.valid then
    table.insert(w.marks, rendering.draw_sprite{sprite = "utility/warning_icon", surface = lead.surface,
      target = {entity = lead, offset = {0, -3.4}}, x_scale = 0.6, y_scale = 0.6})
    table.insert(w.marks, rendering.draw_sprite{sprite = "utility/warning_icon", surface = lead.surface,
      target = {entity = lead}, x_scale = 1.2, y_scale = 1.2, render_mode = "chart"})
  end
end

-- Its big bursters at the turrets ahead (between its mark and its target, nearest first), one each, each at the next
-- turret out of the blast of those already sent (BIG_BURST_R apart): they break the line, the herd crosses the hole.
local BIG_BURST_R = shared.BIG_BURST.r
local BIG_AHEAD = 120
-- The herd holds back, out of reach where it marked, till they are spent (sequence), so it crosses a hole and not a line
-- still firing: at a stretch of nw's north wall rebuilt in the arena (scripts/wall-lab.sh, 2026-10-28), 7 big bursters
-- sent with 300 mediums broke 6 lasers and none got in; 14 ahead of 75 big biters behind them broke 20, and 14 got in.
-- They in turn hold till its sweep is done, on ground it has cleared: sent with it, they crossed the mines first, and 11
-- broke 23 mines, 52 wall pieces and 5 lasers (the siege test, 2026-10-28).
-- (guns: the turrets to go at, given: a camp it turns on, every gun of it; else those ahead of it, below.)
-- A ram's order at its gun: the wall piece on its way there first (where it sets off, detonate: WALL_TOUCH), then the gun.
-- (Sent at the gun alone, behind the square lab fort's wall 3 tiles in, its path failed and it stood 9 tiles out under the
-- lasers till it died, 30 rams of 30 short, where at the user's fort, its guns 6 to 16 tiles in, they reached the wall;
-- 2026-10-31.)
-- At its breach, where its sweep cleared the mines (sweep): sent at the wall nearest its own gun, its rams crossed the
-- mines the sweep had left there, stood stunned 9 tiles out and were lasered (the user, 2026-10-31: "they get stunned by
-- the mines ... our mine sweep is not working"). Of the wall at its breach (RAM_LANE), the piece nearest its gun.
local RAM_WALL, RAM_LANE = 12, 6
local function ram_order(u, t, lane)
  local best, bd
  local near = lane and u.surface.find_entities_filtered{position = lane, radius = RAM_LANE, type = WALLS, force = t.force} or {}
  if #near == 0 then near = u.surface.find_entities_filtered{position = t.position, radius = RAM_WALL, type = WALLS, force = t.force} end
  for _, wl in ipairs(near) do
    local d = lane and math.sqrt(d2(wl.position, t.position)) or math.sqrt(d2(u.position, wl.position)) + math.sqrt(d2(wl.position, t.position))
    if not bd or d < bd then best, bd = wl, d end
  end
  local at_gun = {type = defines.command.attack, target = t, distraction = defines.distraction.none}
  if not best then return at_gun end
  return compound({{type = defines.command.attack, target = best, distraction = defines.distraction.none}, at_gun}), best
end
-- Its ram's order at `w`'s swept lane, and how far off that lane the wall piece it goes at stands (the tests).
-- Its rams in ranks and a spread's rams (below: herd.rk's on, way_open, busy, through, next, spread_rams; a table on herd, its
-- main chunk at Lua's 200 locals).
herd.rk = {}
local function ram_go(w, u, t, lane)
  lane = lane or w.breach_wall
  local cmd, wall = ram_order(u, t, lane)
  if wall and lane then w.ram_off = math.max(w.ram_off or 0, math.sqrt(d2(wall.position, lane))) end
  return cmd, wall
end
-- A spread's rams (the adaptive tactics consult, 2026-11-05, R2): at each of its points (w.spread) in turn, one at a time,
-- each at the dearest gun covering its point not yet gone at there, or at the wall piece at its point where none covers
-- it; held where they stand till its screen draws the fire (sequence), as a siege's.
function herd.rk.spread_rams(w, s, forces)
  local big = {}
  for _, u in ipairs(w.members) do
    if u.valid and u.name == "lp-bred-big-burster" and u.commandable and not (w.big_busy or {})[u.unit_number] then big[#big + 1] = u end
  end
  local pts = w.spread.points
  if #big == 0 or #pts == 0 then return 0 end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, p in ipairs(pts) do x0, y0, x1, y1 = math.min(x0, p.x), math.min(y0, p.y), math.max(x1, p.x), math.max(y1, p.y) end
  local mid = {x = (x0 + x1) / 2, y = (y0 + y1) / 2}
  local map = firemap.read(s, mid, math.sqrt(d2({x = x0, y = y0}, mid)), forces, herd.price_of)
  local lanes = {}
  for i, p in ipairs(pts) do
    local guns = {}
    for _, t in ipairs(firemap.cover(map, p)) do if threat.firing(t) then guns[#guns + 1] = t end end
    table.sort(guns, function(a, b)
      local pa, pb = herd.price_of(a), herd.price_of(b)
      if math.abs(pa - pb) > 1e-6 then return pa > pb end
      return d2(a.position, p) < d2(b.position, p)
    end)
    local wall = s.find_entities_filtered{position = p, radius = 2, type = WALLS, force = forces}
    table.sort(wall, function(a, b) return d2(a.position, p) < d2(b.position, p) end)
    lanes[i] = {p = p, guns = guns, wall = wall[1], n = 0}
  end
  local k = 0
  w.big_targets, w.big_busy = w.big_targets or {}, w.big_busy or {}
  for j, u in ipairs(big) do
    local ln = lanes[(j - 1) % #lanes + 1]
    ln.n = ln.n + 1
    local t = ln.guns[ln.n] or ln.wall or ln.guns[1]
    if t then
      k = k + 1
      table.insert(w.big_targets, {unit = u, target = t, lane_at = {x = ln.p.x, y = ln.p.y}, held = true})
      w.big_busy[u.unit_number] = true
      u.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none}
    end
  end
  if k > 0 then log(w, string.format("its spread: %d big bursters at %d points of the wall (%s), held behind its screen", k, #lanes,
    table.concat((function() local o = {} for _, l in ipairs(lanes) do o[#o + 1] = string.format("%.0f,%.0f", l.p.x, l.p.y) end return o end)(), " "))) end
  w.big_sent = (w.big_sent or 0) + k
  return k
end
local function send_big_bursters(w, s, forces, m, c, now, given)
  local big = {}
  for _, u in ipairs(w.members) do
    if u.valid and u.name == "lp-bred-big-burster" and u.commandable and not (w.big_busy or {})[u.unit_number] then big[#big + 1] = u end
  end
  if #big == 0 then return 0 end
  local len = math.max(1, math.sqrt(d2(m, c)))
  local ux, uy = (c.x - m.x) / len, (c.y - m.y) / len
  local seen, guns = {}, given or {}
  for d = 0, given and -1 or math.min(len, BIG_AHEAD), 8 do
    local q = {m.x + ux * d, m.y + uy * d}
    for _, t in ipairs(s.find_entities_filtered{position = q, radius = threat.far(), type = threat.FIRE, force = forces}) do
      if not seen[t.unit_number] and threat.firing(t) then seen[t.unit_number] = true; guns[#guns + 1] = t end
    end
  end
  -- The dearest first (herd.price_of: what each costs it to cross), nearest of those alike: where a burster takes most off
  -- its way in. Nearest first, they broke the laser line and left the flamethrowers behind it, which burned 109 of the
  -- herd that came after (a megabase's north wall, 2026-10-28).
  local price = {}
  for _, t in ipairs(guns) do price[t.unit_number] = herd.price_of(t) end
  table.sort(guns, function(a, b)
    local pa, pb = price[a.unit_number], price[b.unit_number]
    if math.abs(pa - pb) > 1e-6 then return pa > pb end
    return d2(a.position, m) < d2(b.position, m)
  end)
  local hit, k = {}, 0
  for _, t in ipairs(guns) do
    if k >= #big then break end
    local near = false
    for _, h in ipairs(hit) do if d2(h, t.position) < BIG_BURST_R * BIG_BURST_R then near = true; break end end
    if not near then
      k = k + 1
      hit[#hit + 1] = t.position
      local hit = ram_go(w, big[k], t)
      w.big_targets = w.big_targets or {}
      table.insert(w.big_targets, {unit = big[k], target = t})
      w.big_busy = w.big_busy or {}
      w.big_busy[big[k].unit_number] = true
      -- (It holds where it stands till its herd is at the wall, sequence: behind the herd, not ahead of it.)
      if not now then
        w.big_targets[#w.big_targets].held = true
        big[k].commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none}
      else
        big[k].commandable.set_command(hit)
      end
    end
  end
  -- (A siege's rams beyond the guns they were sent at, held as well, behind its screen: the ranks for the walls behind,
  -- herd.rk. Left in its herd, a siege of two rams at two rings sent one, and its herd chewed the inner ring.)
  local reserve = 0
  if not now and k > 0 and w.fodder_set and herd.rk.on() then
    local first = w.big_targets[#w.big_targets - k + 1].target
    for j = k + 1, #big do
      local u = big[j]
      table.insert(w.big_targets, {unit = u, target = first, held = true})
      w.big_busy[u.unit_number] = true
      u.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none}
      reserve = reserve + 1
    end
  end
  if k > 0 then log(w, string.format("%d big bursters sent at %d turrets ahead%s", k + reserve, k,
    reserve > 0 and string.format(", %d more held behind them", reserve) or "")) end
  w.big_sent = (w.big_sent or 0) + k + reserve
  return k + reserve
end

-- The sweep (the user, 2026-10-28: "couldn't the solution be to devise an answer to minefields?", then "let it see the
-- mines"): a runt at each of its foe's mines on the last of its way and through its breach, ahead of it; its big bursters
-- go once it is done, the herd once they are (sequence). SWEEP_MAX runts at most. (Two waves on a megabase lost 55 and 40
-- to the mines of a breach their bursters had opened; a line of runts swept blind cleared a dense field's first row.)
local SWEEP_GAP, SWEEP_MAX = 3, 60
herd.SWEEP_MAX = SWEEP_MAX
-- The mines within `reach` of the way from `a` through `b` to `c` (its sweep's: the last of its way and its breach), nearest
-- `a` first.
-- Whether a wall piece of `forces` stands on the line from `a` to `b`, a tile at a time.
local function wall_on_line(s, forces, a, b)
  local n = math.ceil(math.sqrt(d2(a, b)))
  for i = 1, n - 1 do
    local p = {a.x + (b.x - a.x) * i / n, a.y + (b.y - a.y) * i / n}
    if s.count_entities_filtered{position = p, radius = 0.8, type = WALLS, force = forces, limit = 1} > 0 then return true end
  end
  return false
end
-- Its foe's mines within `reach` of its way (pts), those it can walk to from `from` without crossing a wall: a sweeper
-- sent at mines between two walls chewed through the outer to reach them, a ram's work for a sweeper's 60 biomass, and
-- mines laid between layers were worse than none (the lane, 2026-10-31; the user: "yes", sweep what lies before the
-- wall). Those past a wall its rams' blasts and its herd meet.
local function mines_along(s, forces, pts, reach, from)
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, p in ipairs(pts) do
    x0, y0, x1, y1 = math.min(x0, p.x), math.min(y0, p.y), math.max(x1, p.x), math.max(y1, p.y)
  end
  local out = {}
  for _, m in ipairs(s.find_entities_filtered{area = {{x0 - reach, y0 - reach}, {x1 + reach, y1 + reach}}, type = "land-mine",
    force = forces}) do
    local q = m.position
    for i = 2, #pts do
      local a, b = pts[i - 1], pts[i]
      local ex, ey = b.x - a.x, b.y - a.y
      local f = math.max(0, math.min(1, ((q.x - a.x) * ex + (q.y - a.y) * ey) / math.max(1, ex * ex + ey * ey)))
      if d2(q, {x = a.x + ex * f, y = a.y + ey * f}) <= reach * reach then
        if not (from and wall_on_line(s, forces, from, q)) then out[#out + 1] = m end
        break
      end
    end
  end
  table.sort(out, function(m1, m2) return d2(m1.position, pts[1]) < d2(m2.position, pts[1]) end)
  return out
end
herd.mines_along = mines_along
-- Where its sappers set off: a mine, and every mine within its blast of it covered, the next one not, along the way in.
-- (Within its blast less how short of its spot it may set off, SAPPER_AT, and half a tile: at 0.85 of the blast, with
-- sweepers set off 2.5 short, a mine at a cluster's edge stood 8.45 from a blast of 7, 7 of 8 cleared; `farm` siege.)
-- Each spot on its cluster's near edge: pulled back from its first mine towards where its sweepers come from as far as
-- every mine it covered on the mine still stays within reach (the user, 2026-11-04: on the mine itself, the fort's lasers
-- killed them about 7 short, and 2 of 6 mines stood; farm siege 12345. Pulled back a whole reach, each covered its first
-- mine alone: 8 sweepers for 8 mines where 4 had done).
local SAPPER_AT = 1.5
local SAPPER_REACH = shared.SAPPER.r - SAPPER_AT - 0.5
local SPOT_STEP = 0.5
function herd.sapper_spots(mines, from)
  local spots, r2 = {}, SAPPER_REACH * SAPPER_REACH
  local covered = {}
  for i, m in ipairs(mines) do
    if not covered[i] then
      local q = m.position
      local members = {}
      for j = i, #mines do
        if not covered[j] and d2(mines[j].position, q) <= r2 then members[#members + 1] = j end
      end
      local spot = {x = q.x, y = q.y}
      if from then
        local fx, fy = (from.x or from[1]) - q.x, (from.y or from[2]) - q.y
        local d = math.sqrt(fx * fx + fy * fy)
        local back = math.min(SAPPER_REACH - SPOT_STEP, d)
        while d > 0 and back > 0 do
          local c, fits = {x = q.x + fx / d * back, y = q.y + fy / d * back}, true
          for _, j in ipairs(members) do if d2(mines[j].position, c) > r2 then fits = false; break end end
          if fits then spot = c; break end
          back = back - SPOT_STEP
        end
      end
      for _, j in ipairs(members) do covered[j] = true end
      spots[#spots + 1] = spot
    end
  end
  return spots
end

-- How many sweepers each spot takes (0.2.352; the user, 2026-11-12, of farm siege's sweepers lasered 7 short: "I would
-- steer clear of hard coding. Can we not scale the number of sweepers to something?"): the fire a lone sweeper walks
-- through from `from` to its spot (each step's covering turrets, their dps on a sweeper: threat.turret_dps) over its
-- health, one for each sweeper that fire would take, and one to arrive.
function herd.sweepers_at(s, forces, spots, from)
  local out = {}
  if #spots == 0 or not from then return out end
  local proto = prototypes.entity["lp-sweeper"]
  local hp, speed = proto.get_max_health(), math.max(0.01, proto.speed or 0.1)
  local fx, fy = from.x or from[1], from.y or from[2]
  local far = 0
  for _, p in ipairs(spots) do far = math.max(far, math.sqrt(d2(p, {x = fx, y = fy}))) end
  local map = firemap.read(s, {x = fx, y = fy}, far, forces)
  local dps = {}
  local STEP = 2
  for i, p in ipairs(spots) do
    local dx, dy = p.x - fx, p.y - fy
    local d = math.sqrt(dx * dx + dy * dy)
    local taken = 0
    for k = 0, math.floor(d / STEP) do
      local q = {x = fx + dx * (k * STEP / math.max(d, 1e-6)), y = fy + dy * (k * STEP / math.max(d, 1e-6))}
      for _, t in ipairs(firemap.cover(map, q)) do
        local u = t.unit_number
        if dps[u] == nil then dps[u] = threat.turret_dps(t, "lp-sweeper") end
        taken = taken + dps[u] * STEP / speed
      end
    end
    out[i] = 1 + math.floor(taken / hp)
  end
  return out
end

-- Its sweep: a runt at each of its foe's mines on the last of its way and through the breach (w.sweep of them, paid by its
-- farm from its plan, herd.plan: mines), nearest first; each walks on to its mine and sets it off.
local function sweep(w, s, from, to, inside)
  local n = w.sweep or 0
  if n <= 0 then return 0 end
  local mines = mines_along(s, foes(w), {from, to, inside}, herd.spread(#herd_units(w)) + SWEEP_GAP, from)
  local spots = herd.sapper_spots(mines, from)
  w.sweep_mines = #mines
  -- (Each spot as many as the fire on its way takes, herd.sweepers_at: one each first, nearest first, then the rest.)
  local want = herd.sweepers_at(s, foes(w), spots, from)
  local order = {}
  for i = 1, #spots do order[#order + 1] = i end
  for extra = 2, 64 do
    local any = false
    for i = 1, #spots do if (want[i] or 1) >= extra then order[#order + 1] = i; any = true end end
    if not any then break end
  end
  w.sweep_want = 0
  for i = 1, #spots do w.sweep_want = w.sweep_want + (want[i] or 1) end
  local made = 0
  for k = 1, math.min(n, #order) do
    local i = order[k]
    local q = s.find_non_colliding_position("lp-sweeper", {from.x, from.y}, 12, 0.5)
    local u = q and s.create_entity{name = "lp-sweeper", position = q, force = B.force}
    if u then
      made = made + 1
      u.commandable.set_command(go(spots[i], defines.distraction.none, 1))
      w.sweepers = w.sweepers or {}
      table.insert(w.sweepers, u)
      w.sapper_at = w.sapper_at or {}
      w.sapper_at[u.unit_number] = spots[i]
    end
  end
  w.swept = made
  -- (What it swept for, to count what still stands once its sweep is done: a mine a sweeper walked onto went off by
  -- itself, cleared all the same, and counting its bursts' kills read 4 of 6 cleared; farm siege 12345, 0.2.186.)
  w.sweep_set = made > 0 and mines or nil
  if #spots > made or w.sweep_want > #spots then
    log(w, string.format("its sweep: %d mines in %d clusters, %d sweepers (the fire on their way asked %d)", #mines, #spots,
      made, w.sweep_want))
  end
  return made
end

-- Its big bursters set off at their guns: within BIG_DETONATE of the gun each was sent at, it dies, and its death is its
-- blast (biotech.lua); its gun gone, it goes at the nearest firing one within BIG_RETARGET, else it is spent where it is.
-- (Set off once its gun is within its blast, shared.BIG_BURST.r.)
-- Its gun gone, it goes at the nearest that can still reach it (threat.far: the longest reach of any gun).
local BIG_DETONATE = shared.BIG_BURST.r
local WALL_TOUCH = 2.5   -- a big burster this near the foe's wall has reached it (its own reach, a behemoth's bite)
-- Its blast, once wound up (burstfx.lua: set off, it stops, swells and is past harm for its wind-up, then this): its death
-- (its core, biotech.lua: what a killed one fizzles to), and the rest of it here, to all not its force within its reach.
-- (A blast entity made by script took no force: it killed the burster before it died, and every siege after errored; the
-- siege lab, 2026-10-30.)
local function big_blast(u)
  local surf, pos, force = u.surface, u.position, u.force
  burstfx.mark_whole(u)
  u.die(force)
  surf.create_entity{name = "lp-big-burst-explosion", position = pos}
  for _, e in ipairs(surf.find_entities_filtered{position = pos, radius = shared.BIG_BURST.r}) do
    if e.valid and e.force ~= force and e.health and e.destructible then e.damage(shared.BIG_BURST.amount, force, "explosion") end
  end
end
burstfx.on_blast.big = big_blast
-- A big burster set off (its wind-up, then big_blast). Also the dev tools' and tests'.
function herd.set_off(u) return burstfx.windup(u, "big") end
-- Whether a firing gun of `forces` covers pos as it fires: within its reach, past its least reach and inside its arc (the
-- fire map, as its muster reads it, herd.rk.muster_point). (threat.covering is arc-blind: on the ranks-mend fork its held
-- herd stood behind the backs of the spread wall's flamethrowers, facing out, and read 31 of 31 in reach every look, none
-- of them able to turn on it and nothing shooting; its rams sent past them read in reach from their first step.)
function herd.rk.in_fire(s, pos, forces)
  return #firemap.entries(firemap.read(s, pos, 0, forces), pos) > 0
end
local function detonate(w)
  if not w.big_targets then return end
  herd.rk.release_muster(w)
  local s = game.surfaces[w.surface]
  local kept = {}
  for _, b in ipairs(w.big_targets) do
    local u, t = b.unit, b.target
    -- (When a released ram of a rank first stands in a gun's reach, and where: its rank's reading, herd.rk.size_next.)
    if u.valid and b.sent and not b.held and not b.reserve and not b.in_reach and herd.rk.in_fire(s, u.position, foes(w)) then
      b.in_reach, b.in_at = game.tick, {x = u.position.x, y = u.position.y}
    end
    if u.valid and b.mustering then kept[#kept + 1] = b
    elseif u.valid then
      -- (Not one held, nor one of a later rank sent at its wall: its gun gone, a held ram was let go at another, ranks.)
      if not (t and t.valid) and not b.retargeted and not b.held and not b.through then
        b.retargeted = true
        t = nil
        for _, g in ipairs(s.find_entities_filtered{position = u.position, radius = threat.far(), type = threat.FIRE, force = foes(w)}) do
          if threat.firing(g) and (not t or d2(g.position, u.position) < d2(t.position, u.position)) then t = g end
        end
        b.target = t
        if t then u.commandable.set_command{type = defines.command.attack, target = t, distraction = defines.distraction.none} end
      end
      -- At its gun, or at the foe's wall it reached on its way (its blast opens a wall wherever it stands; its guns
      -- behind the wall it would never reach alive, and killed it fizzles: the siege test, 2026-10-30).
      local at_wall = not b.held and not b.at_guns and s.count_entities_filtered{position = u.position, radius = WALL_TOUCH, type = {"wall", "gate"},
        force = foes(w), limit = 1} > 0
      -- (A ram of a later rank, sent through its gap at the wall behind it: at that wall, not at the gap's sides it walks
      -- between; its piece gone, at the next on its way to its herd's target. Set off by any wall, it went off in the gap.)
      -- (Or at any wall deeper in than its gap, or stood at a wall with its order gone: sent at one zigzag piece of nwa's
      -- wall, ram after ram stood short of it with its order failed and none went off; the nwwallsiege visit, 2026-11-05.)
      if b.through and not b.held then
        local wl = b.through.valid and b.through or (w.goal and wall_between(w, u.position, w.goal))
        at_wall = wl ~= nil and d2(u.position, wl.position) <= WALL_TOUCH * WALL_TOUCH
        if not at_wall and s.count_entities_filtered{position = u.position, radius = WALL_TOUCH, type = {"wall", "gate"},
          force = foes(w), limit = 1} > 0 then
          local idle = not (u.commandable and u.commandable.has_command)
          local deeper = w.gap and w.goal and d2(u.position, w.goal) < (math.sqrt(d2(w.gap, w.goal)) - 2) ^ 2
          at_wall = idle or deeper or false
        end
      end
      if (t and t.valid and not b.held and d2(u.position, t.position) <= BIG_DETONATE * BIG_DETONATE) or at_wall then
        w.big_set_off = (w.big_set_off or 0) + 1
        if at_wall and not (t and t.valid and d2(u.position, t.position) <= BIG_DETONATE * BIG_DETONATE) then
          w.big_at_wall = (w.big_at_wall or 0) + 1
          log(w, string.format("a big burster set off at the wall at %.0f,%.0f (%d of them)", u.position.x, u.position.y, w.big_set_off))
        else
          log(w, string.format("a big burster set off at the %s at %.0f,%.0f (%d of them)", t.name, t.position.x, t.position.y, w.big_set_off))
        end
        -- Its wind-up, then its blast (big_blast). (Kept till it lands: its next rank waits on it, ranks.)
        w.winding = w.winding or {}
        table.insert(w.winding, u)
        herd.set_off(u)
      elseif t or not b.spent then kept[#kept + 1] = b end
    end
  end
  w.big_targets = #kept > 0 and kept or nil
end

local function breach(w)
  ensure_group(w)
  local s = game.surfaces[w.surface]
  local forces = foes(w)
  local m, c = w.mark, w.staged and w.goal or w.center
  -- (At the guns covering where its plan breaks in, w.breach_at: toward its target, 400 tiles along the wall from where it
  -- broke in, they found no gun within reach of their line and were never sent, and 113 of 120 burned; 2026-10-28.)
  local led = w.spread and herd.rk.spread_rams(w, s, forces) or send_big_bursters(w, s, forces, m, w.breach_at or c)
  -- Its plan's way on past its breach to what it came for (the user, 2026-10-28: "once you get passage, just try and rush
  -- through past the defenses"): one move along the way it priced, round the fire, no stop to fight a gun or break a wall
  -- (blocked, its biters break what blocks them), committed till it gets there (no half-lost turn while it crosses).
  -- Stopping in the fire to break named wall pieces and walk a step in, a herd of 120 burned to 6 at a flamethrower line.
  if w.plan then
    local pl = w.plan
    local rest, after = {}, nil
    for i = pl.upto + 1, #pl.path do
      local q = {x = pl.path[i][1], y = pl.path[i][2]}
      rest[#rest + 1] = q
      if not after and pl.path[i - 1] and pl.path[i - 1][1] == pl.breach[1] and pl.path[i - 1][2] == pl.breach[2] then after = q end
    end
    rest[#rest + 1] = {x = pl.target[1], y = pl.target[2]}
    local h = w.breach_at or rest[1]
    w.breach, w.inside, w.walled, w.silenced = h, after or rest[#rest], 0, 0
    -- (Its rams' way to the wall, swept with its own: ram_order, released once its sweep is done.) The wall piece nearest its
    -- breach: a plan's breach is a point of its cost map's coarse cells, and 8 tiles inside the wall no piece stood within
    -- RAM_LANE of it; its ram went at the wall by its gun, 10 off its lane, and died short (the playtest's slower climb,
    -- 0.2.127; farm siege).
    local lane = s.find_entities_filtered{position = h, radius = 2 * RAM_WALL, type = WALLS, force = forces}
    table.sort(lane, function(a, b) return d2(a.position, h) < d2(b.position, h) end)
    w.breach_wall = lane[1] and {x = lane[1].position.x, y = lane[1].position.y} or h
    w.punch, w.committed = true, true
    local cmds = {}
    for _, q in ipairs(rest) do cmds[#cmds + 1] = go(q, defines.distraction.none, 6) end
    local swept = sweep(w, s, m, h, w.inside)
    if swept > 0 then log(w, string.format("%d sweepers sweep the way in ahead of it, one at each cluster of mines", swept)) end
    if led > 0 or swept > 0 then
      w.held_cmds = cmds
      w.group.set_command{type = defines.command.stop, distraction = defines.distraction.none}
    else
      w.group.set_command(compound(cmds))
    end
    w.stage, w.t, w.t_breach = "breach", game.tick, game.tick
    log(w, string.format("breach at %.0f,%.0f: punches through to its target at %.0f,%.0f, %d legs round the fire%s", h.x, h.y,
      pl.target[1], pl.target[2], #cmds, (led > 0 or swept > 0) and string.format(", behind its %s",
      led > 0 and swept > 0 and "sweep and its big bursters" or led > 0 and "big bursters" or "sweep") or ""))
    return
  end
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
    local map = firemap.read(s, hit, 0, forces, herd.price_of)
    local cover = firemap.cover(map, hit)
    -- (By prototype, for what each costs it: learn_price.)
    w.breach_cover, w.breach_by = #cover, {}
    for _, t in ipairs(cover) do w.breach_by[t.name] = (w.breach_by[t.name] or 0) + 1 end
    if #cover > 0 and firemap.affords(map, hit, herd.strength(herd_units(w))) then
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
  w.breach_wall = hit or h
  hold_bursters(w, hit)
  w.inside = {x = h.x + ux * depth, y = h.y + uy * depth}
  table.insert(cmds, go(w.inside, defines.distraction.none, 4))
  local swept = sweep(w, s, m, h, w.inside)
  if swept > 0 then log(w, string.format("%d sweepers sweep the way in ahead of it, one at each cluster of mines", swept)) end
  -- Its sweep and its bursters ahead of it: it holds, fighting nothing, till they are spent (sequence); then in. (By
  -- by_enemy, its string's end in reach of the lasers drew the herd after them into the mines its sweep had only begun on,
  -- 49 lost in five seconds; the siege test, 2026-10-28.)
  if led > 0 or swept > 0 then
    w.held_cmds = cmds
    w.group.set_command{type = defines.command.stop, distraction = defines.distraction.none}
  else
    w.group.set_command(compound(cmds))
  end
  w.stage = "breach"
  w.t = game.tick
  w.t_breach = game.tick

  log(w, string.format("breach at %.0f,%.0f (%s%s%s)", h.x, h.y, hit and (#cmds - 1 - silenced - ((led > 0 or swept > 0) and 1 or 0)) .. " wall pieces" or "no wall",
    silenced > 0 and string.format(", the %d turrets covering it first", silenced) or "",
    (led > 0 or swept > 0) and string.format(", behind its %s", led > 0 and swept > 0 and "sweep and its big bursters"
      or led > 0 and "big bursters" or "sweep") or ""))
  if not w.held_cmds then choose_plan(w) end
end

-- Its breach in order, each when the one before is done (the user, 2026-10-28: "event-driven sequencing, no more clocks"):
-- its sweep (every runt dead on its mine or at it), then its big bursters (each set off, dead, or with no gun left it can
-- go at), then its herd, in; and then its heart is chosen, from where its herd stands, on the guns still standing.
local withdraw, home_leg   -- below
local STUCK_LOOKS = 10
-- Its rams in ranks (the adaptive tactics consult, 2026-11-05, R1; the user at 0.2.105: let it learn and walk the layers,
-- never count them): a siege's rams go at the wall as many at once as it takes for one to reach it alive (a rank,
-- herd.reach_alive), the rest held; once a rank's blasts have landed and a wall still stands between its gap and its
-- target, the next rank goes through the gap at the first wall piece on that line (or at the same wall, every ram of the
-- last killed short), its herd held out of reach until no wall stands between its gap and its target, or its rams are
-- spent. No layer is counted: the rams walk them. (Sent all at once, its doubled rams went at the outer of nwa's four lines
-- together, and its herd stood at the inner lines in two flamethrowers' arcs: 160 of 200 burned.) Its personality:
-- B.mind.ranks; the test lever biotech_no_ranks.
function herd.rk.on() return B.mind.ranks ~= false and not storage.biotech_no_ranks end
-- Whether its way in is open: its gap open and no wall between it and its target.
function herd.rk.way_open(w)
  return gap_open(w) and not (w.goal and wall_between(w, w.gap, w.goal))
end
-- Its rams still going (released, with an order, not stood still STUCK_LOOKS) or winding up.
function herd.rk.busy(w)
  for _, u in ipairs(w.winding or {}) do if u.valid then return true end end
  for _, b in ipairs(w.big_targets or {}) do
    if b.mustering and b.unit.valid then return true end
  end
  for _, b in ipairs(w.big_targets or {}) do
    if b.unit.valid and not b.held and b.unit.commandable and b.unit.commandable.has_command and (b.still or 0) < STUCK_LOOKS then
      return true
    end
  end
  return false
end
-- Its herd may go: no rank held back, or its way open, or its rams spent.
function herd.rk.through(w)
  if not w.ranked then return true end
  -- (Its way open with rams still held: once its last rank at the guns covering its way in is tried and spent,
  -- herd.rk.gun_rank. Its way opened under the wind-up of a rank's last ram, its herd went before it was tried.)
  if herd.rk.way_open(w) then
    if (w.reserve or 0) > 0 and not w.gun_rank and not storage.biotech_no_gun_rank then return false end
    return not (w.gun_rank and herd.rk.busy(w))
  end
  return (w.reserve or 0) == 0 and not herd.rk.busy(w)
end
-- A rank's rams go together (the nwwallsiege visit, 2026-11-05: sent from where each was held, 70 tiles back, a rank's rams
-- came into 15 to 18 guns' reach strung out, each killed in about a second alone, whatever its rank's size): first to
-- its muster, the first point on the line from its gap back through its staging out of every firing gun's reach (its fire map),
-- then through the gap together once every one of it stands there (within twice its touch of it, or its order failed where it
-- stood), held there by a stop: its order done, a ram stood idle at its muster went at the wall in its sight by itself, alone,
-- and died in the gap (the nwwallsiege visit, 2026-11-05).
herd.rk.MUSTER_R = WALL_TOUCH
function herd.rk.muster_point(w, from)
  local back = w.mark
  if not (from and back) then return nil end
  local s = game.surfaces[w.surface]
  local len = math.sqrt(d2(from, back))
  -- (On past its staging by the longest reach of any gun, where its staging is itself under fire. Read on a fire map: a
  -- flamethrower's arc and its least reach honoured, firemap.)
  local most = len + threat.far()
  local map = firemap.read(s, from, most, foes(w))
  for d = 0, most, herd.rk.MUSTER_R do
    local p = {x = from.x + (back.x - from.x) * d / math.max(1, len), y = from.y + (back.y - from.y) * d / math.max(1, len)}
    if #firemap.entries_box(map, p, herd.rk.MUSTER_R) == 0 then return p end
  end
  return nil
end
function herd.rk.go_through(w, b, through, wall)
  b.sent, b.in_reach, b.in_at, b.mustering = game.tick, nil, nil, nil
  b.through, b.to = wall, {x = wall.position.x, y = wall.position.y}
  local cmds = {}
  if through then cmds[#cmds + 1] = go(through, defines.distraction.none, 1.5) end
  cmds[#cmds + 1] = {type = defines.command.attack, target = wall, distraction = defines.distraction.none}
  b.unit.commandable.set_command(#cmds > 1 and compound(cmds) or cmds[1])
end
-- A ram of its last rank at a gun covering its way in, through its gap (its way open): set off at its gun alone, not at a
-- wall it touches (going off at the gap's sides it walked between, 10 of 21 blew the outer wall again; the nwwallsiege
-- visit, 2026-11-05).
function herd.rk.go_at_gun(w, b, through)
  b.sent, b.in_reach, b.in_at, b.mustering, b.through = game.tick, nil, nil, nil, nil
  local t = b.at_gun
  b.at_gun = nil
  if not t.valid then return end
  b.target, b.to, b.at_guns = t, {x = t.position.x, y = t.position.y}, true
  local cmds = {}
  if through then cmds[#cmds + 1] = go(through, defines.distraction.none, 1.5) end
  cmds[#cmds + 1] = {type = defines.command.attack, target = t, distraction = defines.distraction.none}
  b.unit.commandable.set_command(#cmds > 1 and compound(cmds) or cmds[1])
end
-- Its way open (no wall between its gap and its target) and rams still held: its last rank at the firing guns covering its
-- way from the gap to its target, the dearest first (herd.price_of: what each costs its herd to cross), each a blast
-- (BIG_BURST_R) from those already chosen, mustered and through together, its herd going once they are spent (through);
-- when it holds a ram for each of those guns. Fewer, it leaves guns on its way whatever it breaks and only holds its herd
-- while the foe's robots mend its gap: its herd goes now. (Rushed through its open gap with 20 rams held, a herd lost 2,413
-- mediums to the flamethrowers covering its way in; with its last rank at them, 26 at 10, it broke 10 lasers and 3
-- flamethrowers, lost 99 crossing and got in with 162 (the nwwallsiege visit). With 2 rams at 9, the lab's nwa lane went
-- from 6 of 16 in to 3.)
function herd.rk.gun_rank(w)
  if w.gun_rank or storage.biotech_no_gun_rank or not (w.gap and w.goal) then return end
  w.gun_rank = true
  local s = game.surfaces[w.surface]
  local forces = foes(w)
  local guns, seen = {}, {}
  local len = math.sqrt(d2(w.gap, w.goal))
  for d = 0, len, shared.BIG_BURST.r do
    local q = {x = w.gap.x + (w.goal.x - w.gap.x) * d / math.max(1, len), y = w.gap.y + (w.goal.y - w.gap.y) * d / math.max(1, len)}
    for _, t in ipairs(s.find_entities_filtered{position = q, radius = threat.far(), type = threat.FIRE, force = forces}) do
      local r = threat.reach(t)
      if not seen[t.unit_number] and threat.firing(t) and d2(t.position, q) <= r * r then seen[t.unit_number] = true; guns[#guns + 1] = t end
    end
  end
  if #guns == 0 then return end
  local price = {}
  for _, t in ipairs(guns) do price[t.unit_number] = herd.price_of(t) end
  table.sort(guns, function(a, b)
    if math.abs(price[a.unit_number] - price[b.unit_number]) > 1e-6 then return price[a.unit_number] > price[b.unit_number] end
    return d2(a.position, w.gap) < d2(b.position, w.gap)
  end)
  local picked = {}
  for _, t in ipairs(guns) do
    local apart = true
    for _, q in ipairs(picked) do if d2(q.position, t.position) < shared.BIG_BURST.r ^ 2 then apart = false; break end end
    if apart then picked[#picked + 1] = t end
  end
  if (w.reserve or 0) < #picked then
    log(w, string.format("its way open: %d rams held for the %d guns covering its way in, too few: its herd goes", w.reserve or 0, #picked))
    return
  end
  local muster = not storage.biotech_no_muster and herd.rk.muster_point(w, w.gap)
  local m = 0
  for _, b in ipairs(w.big_targets or {}) do
    if b.reserve and b.unit.valid then
      b.reserve, b.held, b.still, b.rank = nil, nil, 0, (w.rank_n or 1) + 1
      b.at_gun = picked[m % #picked + 1]
      if muster then
        b.mustering = muster
        b.unit.commandable.set_command(compound({go(muster, defines.distraction.none, herd.rk.MUSTER_R),
          {type = defines.command.stop, distraction = defines.distraction.none}}))
      else
        herd.rk.go_at_gun(w, b, w.gap)
      end
      m = m + 1
    end
  end
  if m == 0 then return end
  w.reserve = 0
  w.rank_n = (w.rank_n or 1) + 1
  w.rams_done = nil
  w.rank_log = w.rank_log or {}
  table.insert(w.rank_log, {rank = w.rank_n, n = m, guns = #picked, tick = game.tick})
  log(w, string.format("its way open: its last rank of %d big bursters goes at the %d guns covering its way in (of %d), the dearest first; its herd holds",
    m, #picked, #guns))
end
-- Its mustered rank, every one of it at its muster: through together, at the wall that stands between its gap and its
-- target then (its gap may have moved while it gathered).
function herd.rk.release_muster(w)
  local any = false
  for _, b in ipairs(w.big_targets or {}) do
    if b.mustering and b.unit.valid then
      any = true
      local near = d2(b.unit.position, b.mustering) <= (2 * herd.rk.MUSTER_R) ^ 2
      local busy = b.unit.commandable and b.unit.commandable.has_command
      -- (Idle at its muster: free to go at what it sees, the test's count.)
      if near and not busy and w.rank_log and w.rank_log[#w.rank_log] then
        local l = w.rank_log[#w.rank_log]
        l.idle = (l.idle or 0) + 1
      end
      if not near and busy then return end
    end
  end
  if not any then return end
  local through = gap_open(w) and w.gap or nil
  local from = through or w.breach_wall
  local wall = from and w.goal and wall_between(w, from, w.goal)
  local n = 0
  for _, b in ipairs(w.big_targets or {}) do
    if b.mustering and b.unit.valid then
      if b.at_gun then herd.rk.go_at_gun(w, b, through)
      elseif wall then herd.rk.go_through(w, b, through, wall) else b.mustering = nil end
      n = n + 1
    end
  end
  log(w, string.format("its rank %d mustered: %d go through together%s", w.rank_n or 1, n, wall and "" or " (its way open: none needed)"))
end
-- Its rush keeps to its gap's line. A piece its rams broke standing again between its herd's front and its gap (the foe's
-- robots mend what its rams broke while its herd walks there from out of reach), its herd goes at that piece, on its line,
-- and then on through its gap along the rest of its way. Left to the engine, the group's path went round: at the user's north
-- wall (nwwallsiege from its minute-11 save, 0.2.214) the outer wall's gap of 11 pieces open when its herd went was mended to
-- none in the 8 s its herd took to get there, and the engine walked it round the outer wall's end and along the 7-tile
-- corridor behind it to the inner lines, wide open, under a flamethrower covering that end: 2,333 mediums to fire, 15 got
-- in. Only a piece it broke (w.broke): a line from its front past the edge of an open gap touches pieces never broken, and
-- going at those is chewing a wall beside its gap. At most WALL_TRIES pieces.
function herd.rk.tile_key(p) return string.format("%d,%d", math.floor(p.x), math.floor(p.y)) end
-- The mended piece it broke on the line from `from` to its gap, where that line's opening is narrower than its herd's own
-- front (herd.spread), or nil.
-- (Its front wide enough: a piece mended in the middle of an outer gap of 29 open, it went at that one piece under the
-- lasers while the rest stood open, and lost the wave; the full visit. Through an opening of three or one, the engine
-- walked it round.)
function herd.rk.mended_on(w, from)
  local wall = wall_between(w, from, w.gap)
  if not (wall and w.broke[herd.rk.tile_key(wall.position)]) then return nil end
  local open, s, q = 0, game.surfaces[w.surface], wall.position
  local reach = herd.spread(alive(w))
  for _, dir in ipairs({{1, 0}, {0, 1}}) do
    local n = 0
    for k = -reach, reach do
      local t = {x = q.x + dir[1] * k, y = q.y + dir[2] * k}
      if w.broke[herd.rk.tile_key(t)] and s.count_entities_filtered{position = t, radius = 0.3, type = WALLS, force = foes(w), limit = 1} == 0 then
        n = n + 1
      end
    end
    open = math.max(open, n)
  end
  if open >= reach then return nil end
  return wall, open, reach
end
-- Its rush's order from where it stands: at `wall` first (a mended piece on its line, distraction none: by_enemy, it was
-- drawn off its piece to the guns within its sight and fought there; herd test, ranks-mend), through its gap, and on along
-- its rush's legs past it (the leg nearest its gap and those after it).
-- Its group point past its gap toward its target (`past`): on from there (after its wall), its legs past it only.
-- (Sent back through its gap each time its order was done while it held its rush, its group point swung between its gap
-- and its legs' ends, and drew those coming through west along the corridor under the flamethrowers; from the save.)
function herd.rk.rush_on(w, wall, past)
  local cmds, from = {}, nil
  if wall then cmds[1] = {type = defines.command.attack, target = wall, distraction = defines.distraction.none} end
  local legs = w.rush_legs or {}
  local at = past and w.group.position
  if at and d2(at, w.goal) >= d2(w.gap, w.goal) then at = nil end
  for i, c in ipairs(legs) do
    if c.destination and (not from or d2(c.destination, w.gap) < d2(legs[from].destination, w.gap)) then from = i end
  end
  if at then
    from = nil
    for i, c in ipairs(legs) do
      if c.destination and not from and d2(c.destination, w.goal) < d2(at, w.goal) then from = i end
    end
  end
  if gap_open(w) and not at then cmds[#cmds + 1] = go(w.gap, defines.distraction.none, 1.5) end
  -- (Nothing after its wall, or nothing at all: on to its target.)
  local n = wall and 1 or 0
  for i = from or (#legs + 1), #legs do
    local c = legs[i]
    if not c.target or c.target.valid then cmds[#cmds + 1] = c end
  end
  if #cmds == n then cmds[#cmds + 1] = go(w.goal, defines.distraction.none, 6) end
  w.group.set_command(#cmds > 1 and compound(cmds) or cmds[1])
end
function herd.rk.keep_line(w)
  if storage.biotech_no_keep_line or not (w.rushed and w.gap and w.broke and w.goal and w.group and w.group.valid) then return end
  if (w.mend_at and w.mend_at.valid) or (w.mends or 0) >= WALL_TRIES then return end
  local front = foremost(w)
  -- (Its front past its gap toward its target: its gap behind it. Read from there, the line back to its gap ran along the inner
  -- line, and it went at pieces beside its way; the full nwwallsiege visit, 0.2.215.)
  if d2(front, w.goal) <= d2(w.gap, w.goal) then return end
  local wall, open, reach = herd.rk.mended_on(w, front)
  if not wall then return end
  w.mend_at, w.mends = wall, (w.mends or 0) + 1
  herd.rk.rush_on(w, wall)
  log(w, string.format("a piece of its gap mended at %.0f,%.0f between its herd's front at %.0f,%.0f and its gap at %.0f,%.0f, %d open beside it for a front of %d: it goes at it, on its line (%d)",
    wall.position.x, wall.position.y, front.x, front.y, w.gap.x, w.gap.y, open, reach, w.mends))
end
-- Its herd through, read by its herd and not by its front or its group (the user's north wall from the minute-11 save,
-- 0.2.215: its group's order ended when the engine's group point was a few tiles past the outer wall, ahead of its members,
-- its front a tile past it and 133 of 168 still outside; it read itself through and hunted, and those outside went at their
-- targets one by one through the narrow gap, 64 of them burning in the corridor west of it). Of its group's members, those
-- with a wall of its foe's standing on their line to its target and on their line to its gap (as its front is read,
-- wall_between): outside. (On the line to its target alone, those in front of the opening, their line crossing the wall
-- beside it, read as outside while they poured through.) And those farther from its target than its gap is by more than a
-- rank's depth (herd.spread), a wall on their line or not: sent at a mended piece on their line, they broke it, the gap
-- was open, no wall stood between them and it, and 11 of 38 still 30 tiles out read as none outside; it read itself
-- through and they came on alone (herd ranks-mend, failing since 0.2.258, 2026-11-11). (Those at the opening are within
-- the rank's depth of it.)
function herd.rk.outside(w)
  local list, x, y = {}, 0, 0
  -- (Not its rams: those held or going have orders of their own.)
  local rams = {}
  for _, b in ipairs(w.big_targets or {}) do if b.unit.valid then rams[b.unit.unit_number] = true end end
  local far = w.gap and w.goal and (math.sqrt(d2(w.gap, w.goal)) + herd.spread(alive(w))) ^ 2
  for _, u in ipairs(herd_units(w)) do
    if not holds(w, u) and not rams[u.unit_number] and ((wall_between(w, u.position, w.goal) and wall_between(w, u.position, w.gap))
      or (far and d2(u.position, w.goal) > far)) then
      list[#list + 1] = u
      x, y = x + u.position.x, y + u.position.y
    end
  end
  return #list, #list > 0 and {x = x / #list, y = y / #list} or nil, list
end
-- Those outside on their own orders (out of its group): at a mended piece it broke on their line to its gap first
-- (herd.rk.mended_on), then to its group, distraction none; its group on along its legs past its gap. (Sent through its gap
-- first, at the user's wall the inner gap west of the outer wall's opening, they walked the corridor to it under the
-- flamethrower at its west end; from the save.)
-- (Its whole group sent at the mended piece, its group point went back out to the wall and drew those inside out with it:
-- the herd test's crowd, 15 outside to 23 in a look; ranks-crowd.)
function herd.rk.push_rush(w, mid, list)
  local wall = mid and w.broke and (w.mends or 0) < WALL_TRIES and herd.rk.mended_on(w, mid) or nil
  if wall then w.mend_at, w.mends = wall, (w.mends or 0) + 1 end
  herd.rk.rush_on(w, nil, true)
  local to = w.group.position
  if d2(to, w.goal) >= d2(w.gap, w.goal) then to = w.goal end
  local cmds = {}
  if wall then cmds[1] = {type = defines.command.attack, target = wall, distraction = defines.distraction.none} end
  cmds[#cmds + 1] = go(to, defines.distraction.none, 6)
  w.straggling = w.straggling or {}
  for _, u in ipairs(list or {}) do
    if u.valid and not (w.straggling[u.unit_number] and u.commandable.has_command) then
      u.commandable.set_command(#cmds > 1 and compound(cmds) or cmds[1])
      w.straggling[u.unit_number] = true
    end
  end
  return wall
end
-- Those of it no longer outside and out of its group: back in it.
function herd.rk.regather(w)
  if not (w.straggling and w.group and w.group.valid) then return end
  local out = {}
  for _, u in ipairs(select(3, herd.rk.outside(w))) do out[u.unit_number] = true end
  for _, u in ipairs(herd_units(w)) do
    if w.straggling[u.unit_number] and not out[u.unit_number] and not u.commandable.parent_group then
      w.group.add_member(u)
      w.straggling[u.unit_number] = nil
    end
  end
end
-- Its rush's order done with more of it outside than one rank of its own front (herd.spread: the prior, its own shape, not a
-- share typed here): not through. Its rush goes on (herd.rk.push_rush), and is looked at every LOOK (herd.rk.watch_rush):
-- through once no more than a rank is outside, or all the same once a look sees none the fewer outside. (Judged at each
-- order done, it read none the fewer after 7 ticks: its group point at its legs' ends at once, its order done three times
-- in 12 ticks; from the save.) True while it holds its rush.
function herd.rk.hold_rush(w)
  if storage.biotech_no_herd_through or not (w.rushed and w.gap and w.goal and w.group and w.group.valid) then return false end
  if w.rush_held then
    -- (Its order done again within a few ticks of its giving: it had nowhere to go, and given again it was done again, every
    -- 2 ticks for its look's whole length, 145 times in a hold; the rush trace, herd ranks-mend 4242, 0.2.353. It waits
    -- there for them till its next look, answering what hits it.)
    if w.rush_given and game.tick - w.rush_given <= 10 then
      w.group.set_command{type = defines.command.wander, radius = 4,
        ticks_to_wait = math.max(30, LOOK - (game.tick - w.rush_held)), distraction = defines.distraction.by_damage}
      w.rush_given = nil
      return true
    end
    -- (Its order done again while held: on along its legs from where its group point is. Told to wait there for them, its
    -- group stood under the flamethrowers past the zigzag for four looks: 1,393 mediums at the breach to 321; from the save.)
    herd.rk.rush_on(w, nil, true)
    w.rush_given = game.tick
    return true
  end
  if w.rush_more then return false end
  local out, mid, list = herd.rk.outside(w)
  local rank = herd.spread(alive(w))
  -- (By whether those outside are coming, not by a rank's count (0.2.354, the rush trace: at a mended gap the rank's count
  -- read it through with 9, 6 and 3 of its own pressed at the wall on 12345, 777 and 4242; by whether they come, 2, 1 and
  -- 2, the crowd's the same): held while any are outside; herd.rk.watch_rush reads their way to its gap each look. The
  -- rank's count kept behind storage.biotech_through_rank, the control.)
  if herd.rk.by_coming() then
    if out == 0 then return false end
    w.out_d = herd.rk.out_way(w, list)
  elseif out <= rank then return false end
  w.rush_held, w.out_last, w.rush_more = game.tick, out, 1
  local wall = herd.rk.push_rush(w, mid, list)
  log(w, string.format("its rush's order done with %d of its %d outside, their middle at %.0f,%.0f, more than a rank of %d: not through, they come on to it%s",
    out, alive(w), mid.x, mid.y, rank, wall and string.format(", at a mended piece at %.0f,%.0f first", wall.position.x,
    wall.position.y) or ""))
  return true
end
-- The mean way to its gap of those outside (`list`), and the least of their paces a tick (for herd.rk.watch_rush's reading
-- of whether they are coming: their way shorter by a quarter of what the slowest walks in a look).
function herd.rk.by_coming() return not storage.biotech_through_rank end
function herd.rk.out_way(w, list)
  local d, pace = 0, nil
  for _, u in ipairs(list) do
    d = d + math.sqrt(d2(u.position, w.gap))
    local sp = prototypes.entity[u.name] and prototypes.entity[u.name].speed or 0.1
    pace = pace and math.min(pace, sp) or sp
  end
  return #list > 0 and d / #list or 0, pace or 0.1
end
function herd.rk.watch_rush(w)
  if not (w.rush_held and w.group and w.group.valid) or game.tick - w.rush_held < LOOK then return end
  herd.rk.regather(w)
  local out, mid, list = herd.rk.outside(w)
  local rank = herd.spread(alive(w))
  -- (Or none the fewer while it is at a mended piece on its way: opening its way, not stuck.)
  local chewing = w.mend_at and w.mend_at.valid and w.rush_more < WALL_TRIES
  -- (Held while those outside are coming, their way to its gap shorter by a quarter of what the slowest of them walks in a
  -- look; through once none is outside, or all the same once they are not. Its control the rank's count, below.)
  local coming
  if herd.rk.by_coming() then
    local d, pace = herd.rk.out_way(w, list)
    coming = out > 0 and w.out_d and (w.out_d - d) >= 0.25 * pace * LOOK
    w.out_d = d
  end
  if (herd.rk.by_coming() and out > 0 and (coming or chewing))
    or (not herd.rk.by_coming() and out > rank and (out < w.out_last or chewing)) then
    w.rush_held, w.out_last, w.rush_more = game.tick, math.min(out, w.out_last), w.rush_more + 1
    local wall = herd.rk.push_rush(w, mid, list)
    if storage.trace then
      log(w, string.format("its rush held: %d outside, their middle at %.0f,%.0f%s", out, mid.x, mid.y, wall and
        string.format(", at a mended piece at %.0f,%.0f", wall.position.x, wall.position.y) or ""))
    end
    return
  end
  log(w, string.format("its rush held %d looks: %d of it outside (%d at the least), a rank of %d: %s", w.rush_more, out,
    w.out_last, rank, out <= rank and "through" or "through all the same"))
  w.rush_held = nil
  -- (Those still on their own orders back in its group.)
  for _, u in ipairs(herd_units(w)) do
    if w.straggling and w.straggling[u.unit_number] and not u.commandable.parent_group and not holds(w, u) then w.group.add_member(u) end
  end
  w.straggling = nil
  return herd.rk.through_now(w)
end
-- A ram of a rank dead (killed short, never set off: those set off leave big_targets first, detonate): its rank's
-- reading, for the next rank's size. How long the guns took a ram (its rank's first in reach to its last dead, over its
-- dead), and for each ram, how long it would have needed in reach to touch its wall (its way from where it entered
-- their reach to its wall's touch, at its pace in reach).
function herd.rk.read_death(w, ent)
  for _, b in ipairs(w.big_targets or {}) do
    if b.unit == ent then
      if not (b.rank and b.in_reach and b.in_at and b.to) then return end
      w.rank_read = w.rank_read or {}
      local r = w.rank_read[b.rank] or {dead = 0, first = b.in_reach}
      w.rank_read[b.rank] = r
      r.dead, r.first, r.last = r.dead + 1, math.min(r.first, b.in_reach), game.tick
      local t_in = math.max(1, game.tick - b.in_reach) / 60
      local d_in = math.max(0, math.sqrt(d2(b.in_at, b.to)) - WALL_TOUCH)
      local d_at = math.max(0, math.sqrt(d2(ent.position, b.to)) - WALL_TOUCH)
      local went = d_in - d_at
      -- (No way made toward its wall: no pace to read, its need unknown.)
      if went > 0 then
        local need = t_in * d_in / went
        if not r.need or need < r.need then r.need = need end
      end
      return
    end
  end
end
-- The size of its next rank, its last killed short: as many as the guns that killed its last rank would kill while the
-- one with the least way to go walks it, and one (the guns' pace on its last rank, its rams dead over the time from its first
-- in their reach to its last dead), never fewer than its last and one; without a reading, twice its last. (Doubled,
-- ranks of 1, 2, 4 and 8 were each killed short at the user's north wall, a ram each half second in 15 to 18 guns' reach,
-- and only the fifth, 15, went off; the nwwallsiege visit, 2026-11-05.)
function herd.rk.size_next(w)
  local n = w.rank_size or 1
  local r = w.rank_read and w.rank_read[w.rank_n or 1]
  if storage.biotech_rank_doubles or not (r and r.need and r.dead > 0) then return 2 * n end
  local per = math.max(herd.rk.look_every(), r.last - r.first) / 60 / r.dead
  local size = math.max(n + 1, math.floor(r.need / per) + 1)
  w.rank_why = string.format("its last rank's %d dead a ram each %.1f s, its nearest needed %.1f s in reach: %d", r.dead, per,
    r.need, size)
  return size
end
-- Its next rank, once the last one's blasts have landed (or it was killed short) and its way is still shut.
function herd.rk.next(w)
  if not (w.ranked and (w.reserve or 0) > 0 and w.held_cmds and w.rams_go) then return end
  for _, u in ipairs(w.winding or {}) do if u.valid then return end end
  local landed = w.big_set_off or 0
  if landed <= (w.rank_landed or 0) and herd.rk.busy(w) then return end
  -- (Its last rank spent with no blast, killed short or stood: the next sized by what killed it, herd.rk.size_next, or twice
  -- as big without a reading. One at a time, thirty of a siege went one by one at nwa's wall, none went off.)
  if w.rank_sent_at and landed <= w.rank_sent_at then w.rank_size = herd.rk.size_next(w) end
  w.rank_landed = landed
  if herd.rk.way_open(w) then return herd.rk.gun_rank(w) end
  local s = game.surfaces[w.surface]
  local through = gap_open(w) and w.gap or nil
  local from = through or w.breach_wall
  local wall = from and w.goal and wall_between(w, from, w.goal)
  if not wall then return end
  local m = 0
  -- (Mustered first, out of every gun's reach, and through together: herd.rk.muster.)
  local muster = not storage.biotech_no_muster and herd.rk.muster_point(w, from)
  if not muster and not storage.biotech_no_muster and from and w.mark then
    log(w, string.format("its rank finds no muster out of reach between %.0f,%.0f and its staging at %.0f,%.0f (%d guns cover it)",
      from.x, from.y, w.mark.x, w.mark.y, #firemap.entries_box(firemap.read(s, w.mark, herd.rk.MUSTER_R, foes(w)), w.mark, herd.rk.MUSTER_R)))
  end
  for _, b in ipairs(w.big_targets or {}) do
    if m >= w.rank_size then break end
    if b.reserve and b.unit.valid then
      b.reserve, b.held, b.through, b.still = nil, nil, wall, 0
      b.rank, b.to = (w.rank_n or 1) + 1, {x = wall.position.x, y = wall.position.y}
      if muster then
        if m == 0 then
          log(w, string.format("its rank musters at %.0f,%.0f (from %.0f,%.0f), its first ram at %.0f,%.0f", muster.x, muster.y,
            from.x, from.y, b.unit.position.x, b.unit.position.y))
        end
        b.mustering = muster
        b.unit.commandable.set_command(compound({go(muster, defines.distraction.none, herd.rk.MUSTER_R),
          {type = defines.command.stop, distraction = defines.distraction.none}}))
      else
        herd.rk.go_through(w, b, through, wall)
      end
      m = m + 1
    end
  end
  local left = 0
  for _, b in ipairs(w.big_targets or {}) do if b.reserve and b.unit.valid then left = left + 1 end end
  w.reserve = left
  if m == 0 then return end
  w.rank_sent_at = landed
  w.rank_n = (w.rank_n or 1) + 1
  w.rams_done = nil
  w.rank_log = w.rank_log or {}
  table.insert(w.rank_log, {rank = w.rank_n, n = m, wall = {wall.position.x, wall.position.y}, through = through ~= nil,
    tick = game.tick, why = w.rank_why, muster = muster and {muster.x, muster.y} or nil,
    muster_cover = muster and #firemap.entries(firemap.read(s, muster, 0, foes(w)), muster) or nil, idle = 0})
  log(w, string.format("its rank %d of %d big burster%s goes %s at the wall at %.0f,%.0f; %d held; its herd holds", w.rank_n, m,
    m == 1 and "" or "s", through and string.format("through its gap at %.0f,%.0f", through.x, through.y) or "at the same wall",
    wall.position.x, wall.position.y, left))
  if w.rank_why then log(w, "its rank sized: " .. w.rank_why); w.rank_why = nil end
end   -- a big burster that has not moved in this many of its wave's looks (a second each) is spent
local RELEASE_N, RELEASE_R, RELEASE_TICKS   -- below, with its cinders' hold-back: its herd at the wall lets them go
local function sequence(w)
  if w.sweepers then
    local spent = 0
    for _, u in ipairs(w.sweepers) do
      if not u.valid then spent = spent + 1
      elseif u.commandable and u.commandable.has_command then return end
    end
    local left, stood = 0, {}
    for _, m in ipairs(w.sweep_set or {}) do
      if m.valid then
        left = left + 1
        local near = math.huge
        for _, at in pairs(w.sapper_at or {}) do near = math.min(near, math.sqrt(d2(m.position, at))) end
        stood[#stood + 1] = string.format("%.0f,%.0f %.1f from a spot", m.position.x, m.position.y, near)
      end
    end
    if left > 0 then log(w, "its sweep left mines at " .. table.concat(stood, "; ")) end
    w.sweep_left, w.sweep_set = left, nil
    log(w, string.format("its sweep is done (%d of %d sweepers spent, %d of its mines left)", spent, #w.sweepers, left))
    if left > 0 then
      local why = {}
      for k, at in pairs(w.sapper_at or {}) do
        local last = w.sapper_last and w.sapper_last[k]
        why[#why + 1] = string.format("spot %.0f,%.0f last seen %s", at.x, at.y, last and string.format("%.1f off", math.sqrt(d2(last, at))) or "never")
      end
      log(w, "its sweep: " .. table.concat(why, "; "))
    end
    w.sweepers = nil
  end
  -- Its herd goes at the wall first, and its big bursters behind it once RELEASE_N of it are within RELEASE_R of where it
  -- breaks in (or RELEASE_TICKS on), its cinders' rule: the guns fire on the herd at the wall while its rams close in (the
  -- user, 2026-10-30: "what happened to your idea of other biters soaking fire for bursters?"). Sent ahead alone, its rams
  -- took every gun's fire: 12 of 12 killed short of the siege test's wall, and the one of a siege at the user's fort.
  -- With a screen (farm.lua siege_size): the screen goes at the wall, its rams behind it, and its herd holds out of reach
  -- until a ram has blown the wall, then rushes the gap (below).
  if w.held_cmds and not w.screened and w.fodder_set then
    w.screened = game.tick
    local n = 0
    for _, u in ipairs(w.members) do
      if u.valid and w.fodder_set[u.unit_number] and w.breach_at then
        -- (A spread's: at its points in turn.)
        local at = w.spread and w.spread.points[n % #w.spread.points + 1] or w.breach_at
        u.commandable.set_command{type = defines.command.attack_area, destination = at, radius = 12,
          distraction = defines.distraction.by_anything}
        n = n + 1
      end
    end
    log(w, string.format("its screen of %d goes at the wall%s, its big bursters behind it; its herd holds", n,
      w.spread and string.format(" at %d points", #w.spread.points) or ""))
  end
  -- (Every ram spent short of the wall: no gap to rush. Rushed all the same, a siege's herd walked into the closed wall and
  -- the mines inside it, 16 lost to them; the siege test, 2026-10-30. It goes home.)
  herd.rk.next(w)
  if w.held_cmds and w.fodder_set and w.rams_done and (w.big_set_off or 0) == 0 and (w.reserve or 0) == 0 then
    w.held_cmds = nil
    -- (Straight home: it never crossed the wall, there is no way out to clear. Clearing it, it went at the guns covering
    -- the breach it never made and lost 36 of 53; the siege test.)
    w.out_clear = true
    log(w, "its big bursters all spent short of the wall: no gap to rush, it goes home")
    return withdraw(w, "its rams failed")
  end
  -- (A spread's herd waits for a gap at one of its points, not the first ram's wind-up: going then, it went at the plan's
  -- breach while the gap opened at another point.)
  if w.held_cmds and w.fodder_set and w.rams_go and (w.big_set_off or 0) > 0 and herd.rk.through(w)
    and (not w.spread or w.spread.opened or not herd.rk.busy(w)) then
    local cmds = {}
    for _, cmd in ipairs(w.held_cmds) do if not cmd.target or cmd.target.valid then cmds[#cmds + 1] = cmd end end
    w.held_cmds = nil
    ensure_group(w)
    if w.group and w.group.valid then
      for _, u in ipairs(herd_units(w)) do
        if u.valid and not w.fodder_set[u.unit_number] and u.name ~= "lp-bred-big-burster" and u.commandable.parent_group ~= w.group then
          w.group.add_member(u)
        end
      end
      w.group.set_command(compound(cmds))
    end
    log(w, string.format("its herd rushes the gap (%d of its big bursters set off%s)", w.big_set_off or 0,
      w.ranked and string.format(", %d ranks, its way %s", w.rank_n or 1, herd.rk.way_open(w) and "open" or "still shut, its rams spent") or ""))
    if storage.trace then
      local legs = {}
      for _, c in ipairs(cmds) do if c.destination then legs[#legs + 1] = string.format("%.0f,%.0f", c.destination.x, c.destination.y) end end
      log(w, "its rush's legs " .. table.concat(legs, " ") .. (w.gap and string.format(" (its gap %.0f,%.0f)", w.gap.x, w.gap.y) or ""))
    end
    -- (Whether its way was open when it went: the ranks test.)
    w.rushed, w.rush_open = game.tick, herd.rk.way_open(w)
    -- (Its legs past its gap, for its way kept through a mended piece: herd.rk.keep_line.)
    w.rush_legs = cmds
    if not w.punch then choose_plan(w) end
  end
  if w.held_cmds and not w.screened then
    w.screened = game.tick
    local cmds = {}
    for _, cmd in ipairs(w.held_cmds) do if not cmd.target or cmd.target.valid then cmds[#cmds + 1] = cmd end end
    w.held_cmds = nil
    ensure_group(w)
    if w.group and w.group.valid then w.group.set_command(compound(cmds)) end
    local n = 0
    for _, b in ipairs(w.big_targets or {}) do if b.unit.valid then n = n + 1 end end
    log(w, string.format("its herd goes at the wall%s", n > 0 and string.format(", its %d big bursters behind it", n) or ""))
    if not w.punch then choose_plan(w) end
  end
  if w.screened and not w.rams_go then
    -- (At the wall: a wall piece of its foe's within RELEASE_R. Measured from its plan's breach point, the middle of a
    -- 16-tile cell, no herd ever read as there, and its rams went at the timeout; the siege test, 2026-10-30.)
    local front, s = 0, game.surfaces[w.surface]
    for _, u in ipairs(w.members) do
      if front >= RELEASE_N then break end
      if u.valid and u.name ~= "lp-bred-big-burster" and (not w.fodder_set or w.fodder_set[u.unit_number])
        and s.count_entities_filtered{position = u.position, radius = RELEASE_R,
        type = WALLS, force = foes(w), limit = 1} > 0 then front = front + 1 end
    end
    -- (Or once its screen draws fire, its first of them lost: waiting for it at the wall, its rams waited out the 40 s while
    -- its screen of 14 died 24 tiles short in 5; the siege lab, 2026-10-30.)
    local drawn = false
    if w.fodder_set then
      local left = 0
      for _, u in ipairs(w.members) do if u.valid and w.fodder_set[u.unit_number] then left = left + 1 end end
      drawn = left < (w.fodder_n or 0)
    end
    if front < RELEASE_N and not drawn and game.tick - w.screened < RELEASE_TICKS then return end
    w.rams_go = game.tick
    -- (In ranks where its herd holds for them (its screen's siege): the first as many as it takes for one to reach the
    -- wall, the rest held, ranks.)
    local ranked = w.fodder_set and herd.rk.on() and not w.spread
    local held, live = 0, nil
    for _, b in ipairs(w.big_targets or {}) do
      if b.held and b.unit.valid then
        -- (Ranked, a ram whose gun fell while it waited goes at another's, or at its breach's wall: counted out, a siege of
        -- two whose screen had broken one gun went as one rank, its herd at its first ram's wind-up.)
        if ranked or (b.target and b.target.valid) then held = held + 1 end
        if b.target and b.target.valid then live = live or b.target end
      end
    end
    local size = held
    if ranked then
      size = math.max(1, math.ceil(1 / math.max(herd.OPENS_MIN, herd.reach_alive(foe_name(w)))))
      if held > size then w.ranked, w.rank_size, w.rank_n, w.rank_sent_at = true, size, 1, w.big_set_off or 0 end
    end
    local n = 0
    for _, b in ipairs(w.big_targets or {}) do
      if b.held then
        if n >= size then
          b.reserve = true
        else
          b.held = nil
          local t = b.target and b.target.valid and b.target or (ranked and live)
          b.rank, b.sent = 1, game.tick
          if b.unit.valid and t then
            b.target = t
            local cmd, wl = ram_go(w, b.unit, t, b.lane_at)
            b.to = wl and {x = wl.position.x, y = wl.position.y} or {x = t.position.x, y = t.position.y}
            b.unit.commandable.set_command(cmd)
            n = n + 1
          elseif b.unit.valid and ranked and w.breach_wall then
            b.through = game.surfaces[w.surface].find_entities_filtered{position = w.breach_wall, radius = 2, type = WALLS,
              force = foes(w), limit = 1}[1]
            if b.through then
              b.to = {x = b.through.position.x, y = b.through.position.y}
              b.unit.commandable.set_command{type = defines.command.attack, target = b.through, distraction = defines.distraction.none}
              n = n + 1
            end
          end
        end
      end
    end
    w.reserve = w.ranked and held - n or nil
    if n > 0 then log(w, string.format("its big bursters go: %d of its herd at the wall, %.0f s on%s", front, (game.tick - w.screened) / 60,
      w.ranked and string.format("; in ranks of %d, %d held for the walls behind", size, held - n) or "")) end
  end
  if w.rams_go and not w.rams_done then
    -- (A burster standing still STUCK_LOOKS looks running, short of its gun, is spent: two of a siege's stood, one 400
    -- tiles short on its march, one with no gun left, their orders kept, and its herd waited for them for good; the siege
    -- lab's star fort, 2026-10-30.)
    for _, b in ipairs(w.big_targets or {}) do
      if b.unit.valid and not b.reserve and b.unit.commandable and b.unit.commandable.has_command then
        local p = b.unit.position
        if b.at and (p.x - b.at.x) ^ 2 + (p.y - b.at.y) ^ 2 < 0.25 then b.still = (b.still or 0) + 1 else b.still = 0 end
        b.at = {x = p.x, y = p.y}
        if b.still < STUCK_LOOKS then return end
      end
    end
    w.rams_done = game.tick
    -- (The guns still covering its breach: what its herd crosses, and what its prices are learned from, learn_price.)
    if w.breach_at then
      local s = game.surfaces[w.surface]
      local map = firemap.read(s, w.breach_at, 0, foes(w), herd.price_of)
      w.breach_after = {}
      for _, t in ipairs(firemap.cover(map, w.breach_at)) do w.breach_after[t.name] = (w.breach_after[t.name] or 0) + 1 end
    end
    log(w, string.format("its big bursters spent (%d set off, %d at the wall)", w.big_set_off or 0, w.big_at_wall or 0))
  end
end




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
RELEASE_N, RELEASE_R = 5, 8
RELEASE_TICKS = 40 * 60

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
  -- At the breach, answering what hits them, not what they see: told by_enemy, they went from the gap for a gun 28 tiles
  -- in that a deep strike had left standing, and all 8 died to it in 5 seconds (herd test, spit, 2026-10-29; raiding the
  -- edge, the herd had broken it). From a deep strike, as long again as its herd takes to walk back from the heart.
  local wait = COVER_TICKS
  if w.deep and w.deep.reached then
    local units = herd_units(w)
    local pace = 0
    for _, u in ipairs(units) do pace = pace + (u.prototype.speed or 0) end
    pace = #units > 0 and pace / #units or 0
    if pace > 0 then wait = wait + math.floor(math.sqrt(d2(w.deep.at, w.breach)) / pace) end
  end
  -- Deaf while it waits (distraction none), its own hits read by script instead (herd.cover_tick): told by_damage, it
  -- answered the herd's calls for help (a bred unit calls those within its call_for_help_radius, 50), and a gun turret
  -- 32 tiles along the wall that shot a medium withdrawing inside drew all ten to its reach, where they died, none of
  -- them hit first (herd test, spit, seed 12345, 0.2.375). Told to attack what stood within their reach of the gap, they
  -- chewed the wall beside it.
  local reach = 0
  for _, u in ipairs(rear.members) do
    local ap = u.valid and u.prototype.attack_parameters
    if ap and ap.range > reach then reach = ap.range end
  end
  local back = {}
  for k = #w.trail, 1, -1 do back[#back + 1] = {w.trail[k].x or w.trail[k][1], w.trail[k].y or w.trail[k][2]} end
  local c = {group = rear, breach = {w.breach[1] or w.breach.x, w.breach[2] or w.breach.y}, till = game.tick + wait,
    back = back, reach = reach, hp = {}}
  for _, u in ipairs(rear.members) do if u.valid then c.hp[u.unit_number] = u.health end end
  rear.set_command(herd.cover_cmd(c, nil))
  st().rears = st().rears or {}
  st().rears[rear.unique_id] = rear
  st().covers = st().covers or {}
  st().covers[rear.unique_id] = c
  log(w, string.format("%d spitters cover the withdrawal (%.0f s)", n, wait / 60))
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
  local map = firemap.read(s, at, math.max(w.sight, w.hx + w.hy), forces, herd.price_of)
  local n = herd.strength(herd_units(w))
  local function add(e, tier, any)
    if e.valid and not seen[e.unit_number or 0] and (any or firemap.affords(map, e.position, n)) then
      seen[e.unit_number or 0] = true
      out[#out + 1] = {e = e, tier = tier}
    end
  end
  local r = w.sight
  -- First, the guns firing on it where it stands, when it can take them (it ate an outpost's drills under its four guns
  -- and lost half its number there, and more leaving past them; 2026-10-27).
  -- (Whatever they cost to take: it is under their fire either way. Taken only when the fire on each was less than its
  -- strength, inside the user's fort, whose guns cover each other, it went for buildings and died under the guns, none
  -- broken in five sieges that each got in; the siege lab, 2026-10-30.)
  for _, t in ipairs(firemap.cover(map, at)) do add(t, 0, true) end
  -- A cut's feed before all (farm.lua menu: what it came for), wherever it stands.
  if w.cut and w.cut.e and w.cut.e.valid then add(w.cut.e, -1, true) end
  -- Then the artillery shelling its incubators (herd.shelling): what it came for, when it came for one.
  for _, a in pairs(s.find_entities_filtered{position = at, radius = r, type = ARTILLERY, force = forces}) do
    if herd.shelling(a) > 0 then add(a, 0.5) end
  end
  -- What rebuilds and mends what it breaks: the roboports (on a megabase of 543, its biters gnawed solar panels the
  -- construction robots put back, the roboports in reach left for after the power; 2026-10-27).
  for _, e in pairs(s.find_entities_filtered{position = at, radius = r, type = "roboport", force = forces}) do add(e, 0.75) end
  for _, e in pairs(s.find_entities_filtered{position = at, radius = r, type = POWER, force = forces}) do add(e, 1) end
  -- What feeds the guns: the inserters loading them. Cutting further back (feeds.lua: the belt behind, the pole that
  -- powers the lasers) is its mind's (cuts: how many of the best cuts in sight it goes for), none by default: its biters
  -- spread along an ammunition belt under a ring of guns, the guns ran dry, and within the hour it razed two thirds as
  -- much (three timings on a deathworld, each way of it, 2026-10-27; a longer game may pay it back).
  for _, e in pairs(s.find_entities_filtered{position = at, radius = r, type = "inserter", force = forces}) do
    local d = e.drop_target
    if d and d.valid and d.type == "ammo-turret" then add(e, 1) end
  end
  if (B.mind.cuts or 0) > 0 then
    local supply = {}
    for _, f in pairs(feeds.read(s, at, r, forces, herd.price_of)) do
      if f.e.valid and d2(f.e.position, at) <= r * r then supply[#supply + 1] = f end
    end
    table.sort(supply, function(a, b) return a.starves > b.starves end)
    for k = 1, math.min(#supply, B.mind.cuts) do add(supply[k].e, 1 + k / (B.mind.cuts + 1)) end
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
-- The nearest of the foe's buildings no gun covers, within QUIET_REACH of where it stands, deeper than its breach: where it
-- goes rather than back out through the fire (nil: none).
local QUIET_REACH = 160
local function quiet_spot(w)
  local s = game.surfaces[w.surface]
  local at = where(w)
  local fmap = firemap.read(s, at, QUIET_REACH, foes(w), herd.price_of)
  local back = w.breach or w.mark
  local best, bd
  for _, e in ipairs(s.find_entities_filtered{position = at, radius = QUIET_REACH, type = SOFT, force = foes(w)}) do
    local p = e.position
    if firemap.count(fmap, p, 1) == 0 and (not back or d2(p, back) > d2(at, back)) then
      local d = d2(p, at)
      if not bd or d < bd then best, bd = p, d end
    end
  end
  return best and {x = best.x, y = best.y}
end

local hunt
-- At the heart, or as far as its rush got: it hunts from there.
local function rush_end(w, how)
  w.deep.going, w.deep.reached = false, game.tick
  w.t_progress = game.tick
  log(w, string.format("at the heart (%s)", how))
  stay_begin(w)
  return hunt(w)
end

function hunt(w)
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
    -- (Its order lost while its target stands, by the engine or a distraction: its claim freed, it takes another.)
    if a and a.e and a.e.valid and u.valid and not u.commandable.has_command then w.aim[u.unit_number], a = nil, nil end
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
  -- Two passes: each its own target within the caps first; then those left over (more of it than its targets hold) each at
  -- the best of them all the same, spread by the claims on them, so none of its biters stands idle in a group with no
  -- order (the engine's own distraction drew such a group of 107 on to the wall round it; herd test, mega).
  for pass = 1, 2 do
  for _, u in ipairs(units) do
    if not w.aim[u.unit_number] and not w.holders[u.unit_number] and u.valid then
      local best, bs
      for _, c in ipairs(list) do
        local id = c.e.unit_number or 0
        local cap = BIG[c.e.type] and BIG_TARGET or PER_TARGET
        if c.e.valid and (pass == 2 or (claims[id] or 0) < cap) and not (w.unreachable and w.unreachable[id]) then
          local sc = c.tier * 10000 + d2(c.e.position, u.position) + (pass == 2 and OVER_SPREAD * (claims[id] or 0) or 0)
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
        -- Its own order takes it out of its group: from here each of its biters is on its own. Through its gap first when a
        -- wall stands between it and its target (gap_way).
        local hit = {type = defines.command.attack, target = best.e, distraction = defines.distraction.none}
        local via = gap_way(w, u.position, best.e.position)
        u.commandable.set_command(via and compound({via, hit}) or hit)
        given, busy = given + 1, busy + 1
        w.individual = true
      end
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
    local hearts, _, _, cm = hearts_from(w, at, w.sight)
    local near = hearts[1] and hearts[1].at
    if not near then
      log(w, string.format("nothing in sight, and no heart within %d it can take", HEART_REACH))
      return withdraw(w, "nothing in sight feeds a gun")
    end
    -- (Along the way it priced, round the fire, as its rush for the heart.)
    local pts = {}
    for _, q in ipairs(costmap.path(cm, near.position) or {}) do pts[#pts + 1] = q end
    pts[#pts + 1] = near.position
    w.group.set_command(compound(inside_legs(w, w.group.position, pts)))
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
    local map = firemap.read(s, w.breach, 0, foes(w), herd.price_of)
    local cover = firemap.cover(map, w.breach)
    if #cover > 0 and (w.clearing or 0) < CLEAR_MAX and firemap.affords(map, w.breach, herd.strength(herd_units(w))) then
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
  stay_end(w)
  -- Its biters back into one group, to go home as it came (inside, each was on its own).
  w.individual = nil
  -- A new group to go home in. (The group it hunted from stays in the engine's own fight, its state attacking_distraction,
  -- under a new order with no distraction and none it reports (distraction_command nil): told home, a wave of 17 walked
  -- on to the guns that had been shooting it and died there, none home; herd test, its hunt's leftovers no longer idle.)
  if w.group and w.group.valid then
    w.group.destroy()
    w.group = nil
  end
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
  -- (Out through its gap, not through the wall beside it: gap_way. The gap first, then its breach outside it: the other
  -- way round, from inside it walked out to the breach, back to the gap and out again.)
  if gap_open(w) and w.breach and d2(w.gap, w.breach) > 4 then table.insert(w.home, w.gap) end
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

finish = function(w, outcome)
  stay_end(w)
  clear_marks(w)
  -- Stopped at a wall: never through, a wall still between it and its target (its own the last to see it, or its walls
  -- gone at to no end, WALL_TRIES): what its rams learn from, learn_price.
  -- (Its rams held for ranks it never needed are not rams it sent: their share reaching the wall is learned from those
  -- that went, learn_price.)
  local unused = 0
  for _, b in ipairs(w.big_targets or {}) do if b.reserve and b.unit.valid then unused = unused + 1 end end
  w.rams_unused = unused > 0 and unused or nil
  if (w.big_sent or 0) > 0 and not w.t_inside and w.goal then
    -- (Or its gap open with a wall still standing behind it, however many came back to see it: at nwa's four lines in the
    -- lab every siege's ram opened the outer line and its herd died at the next, none left to read the wall, and its rams'
    -- share never halved; one ram a siege, four sieges; the adaptive tactics lab, 2026-11-05.)
    w.wall_stuck = (w.wall_tries or 0) > 0 or (alive(w) > 0 and wall_between(w, foremost(w), w.goal) ~= nil)
      or ((w.big_set_off or 0) > 0 and gap_open(w) and wall_between(w, w.gap, w.goal) ~= nil)
  end
  learn_price(w)
  local h = st()
  local p = h.pens[w.pen]
  if p then for _, u in ipairs(w.members) do if u.valid then table.insert(p.stock, u) end end end
  if w.group and w.group.valid then w.group.destroy() end
  -- Its living walk home: counted back into its incubator's stock where they stood, a wave scattered deep in a base stood
  -- among the player's assemblers with no order (the user's playtest, 2026-10-31; herd test, deepdrop).
  if p and p.pen.valid then
    local home = p.pen.position
    for _, u in ipairs(w.members) do
      if u.valid and u.commandable and not u.commandable.parent_group and d2(u.position, home) > HOME_NEAR * HOME_NEAR then
        u.commandable.set_command{type = defines.command.go_to_location, destination = home, radius = 8,
          distraction = defines.distraction.by_enemy}
      end
    end
  end
  w.stage = "done"
  -- (size: what it had last counted, reset to those through once inside; sent: what went out, the farm wave200 check's.)
  table.insert(h.log, {id = w.id, outcome = outcome, blind = w.blind or false, size = w.size, sent = w.sent, left = alive(w),
    kills = w.kills, loop = w.loop, mark = w.mark and {w.mark.x, w.mark.y}, scout_seen = w.scout_seen,
    t_launch = w.t0, t_mark = w.t_mark, t_march = w.t_march, t_breach = w.t_breach, t_inside = w.t_inside,
    t_first_kill = w.t_first_kill, t_withdraw = w.t_withdraw, t_end = game.tick, center = {w.center.x, w.center.y},
    trail = w.trail, farm = w.farm, recalled = w.recalled, probe = w.probe and w.probe.result,
    breach = w.breach and {w.breach.x, w.breach.y}, legs = w.leg, legs_failed = w.legs_failed or 0, walked = w.walked, off_leg = w.off_leg,
    home_legs = w.home_leg, home_n = w.home and #w.home, went_for = w.went_for,
    deep = w.deep and {at = {w.deep.at.x, w.deep.at.y}, reached = w.deep.reached and true or false},
    under_fire = w.under_fire, downed = w.downed or 0, push_walked = w.push_walked,
    choice = w.choice, goal = w.goal and {w.goal.x, w.goal.y}, heart_near = w.heart_near, razed_worth = w.razed_worth or 0, dead_at = w.dead_at,
    lost_by = w.lost_by, lost_worth_by = w.lost_worth_by, lost_dmg = w.lost_dmg, area = herd.area_of(w), worth = w.worth, big_sent = w.big_sent, big_set_off = w.big_set_off,
    vanished = w.vanished or 0,
    plan_breach = w.plan and w.plan.breach, made_of = w.made_of, opens = w.opens_learned, ram_off = w.ram_off,
    sweep_mines = w.sweep_mines, sweep_left = w.sweep_left, plan_mines = w.plan and w.plan.mines,
    breach_after = w.breach_after, ranks = w.ranked and {n = w.rank_n, size = w.rank_size, unused = w.rams_unused, log = w.rank_log,
      rushed = w.rushed} or nil, rush_open = w.rush_open, mends = w.mends,
    hold = w.hold_probe and {looks = w.hold_probe.looks, sum = w.hold_probe.sum, most = w.hold_probe.most, n = w.hold_probe.n} or nil, spread = w.spread and {points = #w.spread.points,
      opened = w.spread.opened} or nil,
    plan = w.plan and {path = w.plan.path, start = w.plan.start, breach = w.plan.breach, cost = w.plan.cost, cover = w.plan.cover}, silenced = w.silenced, clearing = w.clearing, staged = w.staged and true or false,
    breach_cover = w.breach_cover, breach_by = w.breach_by, price = w.price_learned,
    -- What it expected its way in to cost, there and back (costmap.way_in), against what it lost: its calibration.
    predicted = w.way_in and 2 * w.way_in.lost or nil, crossed = w.crossed, scale = w.scale_learned,
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
  local worth = {}
  for key, v in pairs(w.lost_worth_by or {}) do worth[key] = math.floor(v + 0.5) end
  log(w, string.format("in mediums, of its %.0f: %s", w.worth or 0, serpent.line(worth)))
  if w.part_lost then
    local pw = {}
    for key, v in pairs(w.part_lost) do pw[key] = math.floor(v + 0.5) end
    log(w, string.format("at the breach, in mediums, by its part: %s", serpent.line(pw)))
    if w.rush_at then log(w, "its rush's dead by 8x4 cell: " .. serpent.line(w.rush_at)) end
  end
  if w.hold_probe then
    local hp = w.hold_probe
    log(w, string.format("its herd held %d looks: in a gun's reach %.1f of %.1f a look, at most %d (its middle then %s), its middle last at %.0f,%.0f",
      hp.looks, hp.sum / hp.looks, hp.n / hp.looks, hp.most, hp.at and string.format("%.0f,%.0f", hp.at[1], hp.at[2]) or "-",
      hp.last[1], hp.last[2]))
  end
  for proto, p in pairs(w.price_learned or {}) do
    log(w, string.format("a %s cost it %.1f of its own at the breach (%d covering it): its price now %.1f", proto, p.sample,
      p.n, p.per))
  end
  -- Its lesson: the face it tried and whether it broke anything past the wall there; what killed its units round it.
  -- (Its personality: B.mind.learns; off, it keeps none, which is how the system sim measures what learning is worth.)
  -- (And its learning lever, lp-biotech-learning: off, as the system sim's unlearned.)
  if w.mark_sector and not w.blind and B.mind.learns ~= false and not storage.biotech_unlearned
    and shared.setting("lp-biotech-learning", true) then
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
    if (w.walled or 0) > 0 and broke == 0 and w.why ~= "nothing in sight feeds a gun" then
      l.walled_held = (l.walled_held or 0) + 1
      herd.develop_bursters()
    end
    -- (Stopped as well: half of it or more lost and not one gun of the foe's broken, whatever walls fell. The user's fort
    -- took its first wave's 709 of 750 for 4 wall pieces, and that wave counted as no wall held; the siege lab.)
    local guns_broke = 0
    for name, n in pairs(w.kills or {}) do
      local t = prototypes.entity[name] and prototypes.entity[name].type
      if t == "ammo-turret" or t == "electric-turret" or t == "fluid-turret" then guns_broke = guns_broke + n end
    end
    if herd.held_back(alive(w), w.sent or w.size or 0, guns_broke, w.t_inside ~= nil) then herd.stopped("lost|" .. key) end
    record_attempt(w)
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

-- A way from `at` to its mark by its cost map (blocked ground priced as water, its fire and its deaths): the cells'
-- middles and what it costs; nil when there is none, or it costs DEAR times its number or more (there and back).
local REPLANS, REPLAN_STRIDE = 2, 3
local function replan(w, at)
  local s = game.surfaces[w.surface]
  local m = w.mark
  local mid = {x = (at.x + m.x) / 2, y = (at.y + m.y) / 2}
  local radius = math.max(WAY_REACH, math.sqrt(d2(at, m)) / 2 + WAY_MARGIN)
  local fmap = firemap.read(s, mid, radius * firemap.BOX, hostiles(), herd.price_of, threat.ARMED)
  local n = #herd_units(w)
  local cm = costmap.read(s, mid, radius, foes(w), {fire = fmap, n = n, from = at, deaths = herd.deaths(),
    blocked = herd.blocked(), hidden = herd.hidden_cost(foe_name(w)),
    scale = B.mind.calibrate and know.scale("biotech", foe_name(w)) or 1, cell = radius > WAY_REACH and costmap.CELL * 2 or nil})
  local cost = costmap.cost(cm, m)
  local path = costmap.path(cm, m)
  dump_costmap(w, cm, "replan" .. ((w.replans or 0) + 1), {from = {at.x, at.y}, target = {m.x, m.y}, path = xy_list(path), cost = cost})
  if not cost or cost >= math.huge or not herd.affords(herd.strength(herd_units(w)), cost) then return nil end
  return path and #path > 0 and path or nil, cost
end

-- Whether what is left of it pays its way in (herd.affords on its plan's price, its big bursters left counted).
local function plan_pays(w)
  if not w.way_in then return true end
  local big = 0
  for _, u in ipairs(w.members) do if u.valid and u.name == "lp-bred-big-burster" then big = big + 1 end end
  if w.trust then return true end
  return herd.affords(herd.strength(w.members), herd.way_cost(w.way_in.lost, w.way_in.cover, big, w.way_in.openable, foe_name(w)))
end

-- A strike's wait at its mark (farm.lua menu): its cutters' feed fallen, in; its cutters gone home or dead with the feed
-- standing, or CUT_HOLD past, home: the guns it was to come in under are firing.
local CUT_HOLD = 3 * 3600
local function cut_wait(w)
  local c = w.wait_cut
  if not (c.e and c.e.valid) then
    w.cut_hold = nil
    log(w, "its cutters' feed is down: in")
    probe_read(w)
    return breach(w)
  end
  if not st().waves[c.wave] or game.tick - w.cut_hold > CUT_HOLD then
    w.cut_hold = nil
    return withdraw(w, "its cut failed")
  end
end
-- Its sappers set off at their spots (sweep), or stopped short (a mine's stun, a wall), there.
local function sappers(w)
  for _, u in ipairs(w.sweepers or {}) do
    local at = u.valid and w.sapper_at and w.sapper_at[u.unit_number]
    if u.valid then w.sapper_last = w.sapper_last or {}; w.sapper_last[u.unit_number] = {x = u.position.x, y = u.position.y} end
    if at and (d2(u.position, at) <= SAPPER_AT * SAPPER_AT or not (u.commandable and u.commandable.has_command)) then
      local off = math.sqrt(d2(u.position, at))
      if off > SAPPER_AT then
        log(w, string.format("a sweeper stopped %.1f short of its spot at %.0f,%.0f: set off there", off, at.x, at.y))
      end
      u.die()
    end
  end
end
-- Its units gone from the map with no death raised, out on its way (not home, where an incubator may take its own back):
-- the engine destroyed vanilla biters whose commands kept failing, and a big burster stuck among its incubators went 6 s
-- into the march at full health, uncounted (biotech.lua: destroy_when_commands_fail off; farm siege, 2026-11-05).
local OUT = {scout = true, gather = true, march = true, blind = true, breach = true, inside = true}
local function vanished(w)
  w.known = w.known or {}
  for _, u in ipairs(w.members) do
    if u.valid and u.unit_number and not w.known[u.unit_number] then w.known[u.unit_number] = {u = u, name = u.name} end
  end
  for n, k in pairs(w.known) do
    if not k.u.valid then
      w.known[n] = nil
      if OUT[w.stage] and not (w.died and w.died[n]) then
        w.vanished = (w.vanished or 0) + 1
        log(w, string.format("its %s %d gone from the map with no death (%s)", k.name, n, w.stage))
      end
    end
  end
end
-- (Traced: where its held herd waits against the guns' reach, each look while it holds at the breach: how many of it
-- stand in a firing gun's fire (herd.rk.in_fire: its arc and least reach honoured), and its middle.)
function herd.rk.hold_probe(w)
  local s = game.surfaces[w.surface]
  local n, inr, cx, cy = 0, 0, 0, 0
  for _, u in ipairs(w.members) do
    if u.valid and u.name ~= "lp-bred-big-burster" and not (w.fodder_set and w.fodder_set[u.unit_number]) then
      n, cx, cy = n + 1, cx + u.position.x, cy + u.position.y
      if herd.rk.in_fire(s, u.position, foes(w)) then inr = inr + 1 end
    end
  end
  if n == 0 then return end
  local hp = w.hold_probe or {looks = 0, most = 0, sum = 0, n = 0}
  hp.looks, hp.sum, hp.n = hp.looks + 1, hp.sum + inr, hp.n + n
  if inr > hp.most then hp.most, hp.at = inr, {cx / n, cy / n} end
  hp.last = {cx / n, cy / n}
  w.hold_probe = hp
end
local function step(w, tick)
  if tick % 60 == 0 then vanished(w) end
  if storage.trace and tick % 60 == 0 and w.stage == "breach" and w.held_cmds then herd.rk.hold_probe(w) end
  detonate(w)
  if w.sweepers then sappers(w) end
  if w.cut_hold and w.stage == "march" then return cut_wait(w) end
  -- (And its rams held behind its herd until it is at the wall, whatever stage the herd has gone on to: looked at in the
  -- breach alone, they were never let go once the herd went in; the siege lab, 2026-10-30.)
  if w.stage == "breach" or (w.screened and (not w.rams_done or w.held_cmds)) then sequence(w) end
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
    -- (A group the engine disbanded for a leg it could not path is not counted: its next try is the next leg, so the
    -- trail bounds it. Counted, three blocked legs by its own gate scattered a siege wave 26 of 28 home before it left,
    -- farm siege on seed 12345 from 0.2.146.)
    local leg_fail = w.stage == "march" and w.leg_failed_at and tick - w.leg_failed_at <= 120
    if #live >= 2 and (leg_fail or (w.regroups or 0) < REGROUPS) and (w.stage == "inside" or w.stage == "breach"
      or w.stage == "march" or w.stage == "blind" or (w.stage == "withdraw" and w.home)) then
      if not leg_fail then w.regroups = (w.regroups or 0) + 1 end
      w.leg_failed_at = nil
      w.group = s.create_unit_group{position = where(w), force = B.force}
      for _, u in ipairs(live) do if not u.commandable.parent_group and not holds(w, u) then w.group.add_member(u) end end
      -- (Its count nil till a counted regroup: a first regroup after a failed leg crashed here, the nwa visit at 0.2.361.)
      log(w, string.format("its group broke up with %d alive: formed again (%d of %d)", #live, w.regroups or 0, REGROUPS))
      if w.stage == "march" then march(w) elseif w.stage == "blind" then blind_attack(w)
      elseif w.stage == "withdraw" then home_leg(w) else hunt(w) end
      return
    end
    return finish(w, "scattered")
  end
  if w.stage == "inside" or w.stage == "breach" then release_bursters(w, tick) end
  if w.stage == "breach" then herd.rk.keep_line(w) end
  if w.stage == "breach" and tick % LOOK == 0 then herd.rk.watch_rush(w) end
  if w.stage == "inside" or w.stage == "breach" or w.stage == "blind" then
    -- Half lost, and still losing (any of its own in FIRE_WINDOW): out. Half lost past the guns and losing none, it stays: the
    -- way out is through the fire it paid to cross (a deathworld visit, 2026-10-27: waves lost half in the gap of a turret
    -- ring, turned at the heart where nothing fired on them, and lost as many again going back through it).
    local now = alive(w)
    if w.stay_m and not w.stay_m.done then
      w.stay_m.us = w.stay_m.us + now * (tick - w.stay_m.last)
      w.stay_m.last = tick
    end
    w.loss_log = w.loss_log or {}
    table.insert(w.loss_log, {tick, now})
    while #w.loss_log > 1 and tick - w.loss_log[1][1] > FIRE_WINDOW do table.remove(w.loss_log, 1) end
    if not w.committed and now * 2 < w.size and w.loss_log[1][2] > now then
      -- Unless going out costs more than staying: its way out what its way in cost, what it lost getting here or what its cost
      -- map said (the more), and that half or more of what is left. Then it moves off the fire, deeper, to the nearest of the foe's buildings no gun covers, and
      -- razes there until worn down (time inside). A wave of 262 crossed a megabase's laser wall into a factory no gun
      -- covered, turned at half lost, and lost 106 more going back out through the lasers, razing nothing; 2026-10-27.
      -- (In mediums, as its way in is priced: herd.strength.)
      local left = herd.strength(w.members)
      local out = math.max(w.way_in and w.way_in.lost or 0, (w.worth or left) - left)
      local quiet = (out >= left * valuemap.HOLD) and not w.stayed and quiet_spot(w)
      if not quiet then return withdraw(w, "half lost") end
      w.stayed = tick
      w.pushing = tick
      w.loss_log = nil
      w.individual = nil
      ensure_group(w)
      if w.group and w.group.valid then
        for _, u in ipairs(herd_units(w)) do if u.valid and not u.commandable.parent_group and not holds(w, u) then w.group.add_member(u) end end
        w.group.set_command(go(quiet, defines.distraction.none, 8))
      end
      log(w, string.format("half lost, but its way out would cost %.0f of its %d (%.0f): stays, deeper, off the fire, at %.0f,%.0f",
        out, now, left, quiet.x, quiet.y))
      return
    end
    -- Inside while it brings things down (INSIDE_TICKS since the last fell), INSIDE_MAX at most.
    if w.t_inside and tick - math.max(w.t_inside, w.t_progress or 0) > INSIDE_TICKS then return withdraw(w, "time inside") end
    if w.t_inside and tick - w.t_inside > INSIDE_MAX then return withdraw(w, "time inside, the most") end
    -- Its biters' next targets, every LOOK ticks (one's attack ends when its target falls).
    -- (Not while it pushes in: the next look, two seconds on, found nothing where it still stood and sent it home; on a
    -- deathworld visit, 2026-10-27, four waves of 60 turned at the wall with 2 of their own killed and lost 12 to 17 on
    -- the way out. Its look comes when it gets there, or after PUSH_MAX.)
    if w.pushing and tick - w.pushing >= PUSH_MAX then w.pushing = nil end
    -- A rush for the heart whose order is gone ends where it stands: the engine disbanded its group on the way, the group
    -- formed again had no order and no end came, and its biters stood among the player's assemblers, hunting nothing,
    -- until their time inside ran out (the user's playtest, 2026-10-31; herd test, deepdrop).
    if w.stage == "inside" and tick % LOOK == 0 and w.deep and w.deep.going then
      local g = w.group
      if not (g and g.valid and g.has_command) or tick - (w.deep.t_go or tick) > DEEP_GO_MAX then
        rush_end(w, "its order lost on the way")
      end
    end
    if w.stage == "inside" and tick % LOOK == 0 and not (w.deep and w.deep.going) and not w.pushing then hunt(w) end
  end
  -- Off its leg (DETOUR from the line it was sent along): the engine's pathfinder found the leg's ground unwalkable and went
  -- round, the long way. It remembers that ground as no way (herd.blocked, priced as water by its cost maps) and turns
  -- home along what it walked: on a megabase its cost map read a lake's strait as open, and the pathfinder took the herd
  -- round the lake's far side, through the turret line, into the mined gap; 82 lost of 82 (2026-10-27).
  if storage.march_trace and (w.stage == "march" or w.stage == "breach") and tick % 60 == 0 and w.group and w.group.valid then
    local g = w.group
    local names = {}
    for k, v in pairs(defines.group_state) do names[v] = k end
    local cmd, dc = g.command, g.distraction_command
    local mid = where(w)
    log(w, string.format("TRACE leg %d to %s: group at %.0f,%.0f (%s, %d in it), members' middle %.0f,%.0f; command %s; distraction %s",
      w.leg, w.trail[w.leg] and string.format("%.0f,%.0f", w.trail[w.leg].x, w.trail[w.leg].y) or "-", g.position.x, g.position.y,
      tostring(names[g.state] or g.state), #g.members, mid.x, mid.y, cmd and serpent.line({cmd.type, cmd.destination}) or "none",
      dc and serpent.line({dc.type, dc.target and dc.target.valid and dc.target.name}) or "none"))
  end
  -- A fight on the march (it turned on a camp that shot it): on till nothing of theirs within reach of it fires, its
  -- detour check and its march held meanwhile (fighting took it off its way, and it read that as no way through and
  -- went home mid-fight, 66 lost; 2026-10-28); then on along its trail.
  if w.stage == "march" and w.fighting then
    -- (Its bursters spent: set off, dead, or with no gun left they can go at; then its herd goes in.)
    if w.fighting.stage == "bursters" then
      for _, b in ipairs(w.big_targets or {}) do
        if b.unit.valid and b.unit.commandable and b.unit.commandable.has_command then return end
      end
      w.fighting.stage = "assault"
      ensure_group(w)
      if w.group and w.group.valid then
        w.group.set_command{type = defines.command.attack_area, destination = w.fighting.at, radius = w.fighting.reach,
          distraction = defines.distraction.by_anything}
      end
      log(w, string.format("its big bursters spent at %s's guns (%d set off): it goes in", w.fighting.force, w.big_set_off or 0))
      return
    end
    local g = w.group and w.group.valid and w.group.position or where(w)
    local live = false
    for _, e in ipairs(s.find_entities_filtered{position = g, radius = w.fighting.reach, type = threat.ARMED,
      force = w.fighting.force}) do
      if threat.firing(e) then live = true; break end
    end
    if live then return end
    -- Its guns silent: what is left of it pays its way in to its target, and it marches on; or it does not, and what it
    -- fought is what it razes (the user, 2026-10-28: "why doesn't it destroy the lander?"): their buildings its targets, as
    -- inside a base (hunt), then home.
    local force = w.fighting.force
    w.fighting = nil
    if plan_pays(w) then
      log(w, string.format("nothing of %s's fires on it now: marches on (%d of %d left)", force, alive(w), w.size))
      return march(w)
    end
    -- What their camp would cost it to raze: every gun and armed unit of theirs within its reach of their lander (their
    -- farthest building from it, and the leash their idle garrison keeps, shared.LEASH): a raid on it lost 19 to railgunners
    -- and 10 to flamers it had not counted, and withdrew half lost (2026-10-28). Too dear: home.
    local g = w.group and w.group.valid and w.group.position or where(w)
    local lander = s.find_entities_filtered{position = g, radius = 2 * FIRE_NEAR + herd.spread(alive(w)),
      name = shared.variants({"lp-lander"}), force = force, limit = 1}[1]
    if lander then
      local extent = 0
      for _, e in ipairs(s.find_entities_filtered{position = lander.position, radius = 150, force = force, type = WALLS}) do
        extent = math.max(extent, math.sqrt(d2(e.position, lander.position)))
      end
      local cost = 0
      for _, e in ipairs(s.find_entities_filtered{position = lander.position, radius = extent + shared.LEASH, type = threat.ARMED,
        force = force}) do
        if threat.firing(e) then cost = cost + herd.price_of(e) end
      end
      -- (One way, as a heart is weighed: the garrison beaten, its way home is not through it; valuemap.keeps_one_way.)
      if valuemap.keeps_one_way(alive(w), cost) <= 0 then
        log(w, string.format("nothing of %s's fires on it now, but their camp (%.0f tiles across) holds %.0f of guns and garrison, as many as its %d: home",
          force, 2 * (extent + shared.LEASH), cost, alive(w)))
        return withdraw(w, "their camp too strong")
      end
    end
    log(w, string.format("nothing of %s's fires on it now, and what is left of it (%d) cannot pay its way in: it razes their camp",
      force, alive(w)))
    w.foes = {force}
    w.stage, w.t_inside, w.t = "inside", tick, tick
    -- (Its new task's losses from here: by the half it set out with, half spent on the march, it withdrew a breath into it.)
    w.size, w.loss_log = alive(w), nil
    w.breach = w.group and w.group.valid and w.group.position or where(w)
    return hunt(w)
  end
  if w.stage == "march" and w.leg and w.leg >= 2 and w.trail[w.leg] and w.trail[w.leg - 1] then
    local a, b = w.trail[w.leg - 1], w.trail[w.leg]
    -- Where its group is (the engine's own place for it), not the middle of its members: those not marching with it
    -- count in that middle (2026-10-28).
    local mid = where(w)
    local at = w.group and w.group.valid and w.group.position or mid
    local dx, dy = b.x - a.x, b.y - a.y
    -- Off its way: farther than DETOUR, and more for a bigger herd, from its leg and the legs it walked before it (a herd of
    -- 262 strung out, its middle 65 tiles back along the leg before, read as taken off its way, and it turned home intact;
    -- 2026-10-27).
    local function off_from(pt)
      local off = math.huge
      for i = math.max(2, w.leg - DETOUR_BACK), w.leg do
        local p, q = w.trail[i - 1], w.trail[i]
        local ex, ey = q.x - p.x, q.y - p.y
        local f = math.max(0, math.min(1, ((pt.x - p.x) * ex + (pt.y - p.y) * ey) / math.max(1, ex * ex + ey * ey)))
        off = math.min(off, d2(pt, {x = p.x + ex * f, y = p.y + ey * f}))
      end
      return off
    end
    local off = off_from(at)
    local slack = DETOUR + DETOUR_PER * math.sqrt(#herd_units(w))
    if off > slack * slack then
      local k = know.of("biotech")
      k.blocked = k.blocked or {}
      for _, q in ipairs({0.25, 0.5, 0.75}) do
        table.insert(k.blocked, {a.x + dx * q, a.y + dy * q, game.tick})
      end
      -- A new way from where it stands to its mark, round what it now knows (REPLANS a wave): a wave of 485 that had lost
      -- none turned home at a forest its way had run through (2026-10-28). Home only when there is none, or it is dear.
      if (w.replans or 0) < REPLANS and w.mark then
        local path, cost = replan(w, at)
        if path then
          w.replans = (w.replans or 0) + 1
          local trail = {}
          for i = 1, w.leg - 1 do trail[#trail + 1] = w.trail[i] end
          trail[#trail + 1] = {x = at.x, y = at.y}
          local from = #trail
          for i = REPLAN_STRIDE, #path, REPLAN_STRIDE do trail[#trail + 1] = path[i] end
          trail[#trail + 1] = {x = w.mark.x, y = w.mark.y}
          w.trail, w.leg = trail, from + 1
          log(w, string.format("off its leg %d (%.0f,%.0f to %.0f,%.0f) at %.0f,%.0f: no way through there, remembered; a new way to its mark from here (%d legs, costing %.0f), %d of %d",
            w.leg - 1, a.x, a.y, b.x, b.y, at.x, at.y, #trail - from, cost, w.replans, REPLANS))
          return march(w)
        end
      end
      log(w, string.format("off its leg %d (%.0f,%.0f to %.0f,%.0f) at %.0f,%.0f: no way through there, remembered; it turns home",
        w.leg, a.x, a.y, b.x, b.y, at.x, at.y))
      local walked = {}
      for i = 1, math.min(w.leg - 1, #w.trail) do walked[#walked + 1] = w.trail[i] end
      walked[#walked + 1] = {x = at.x, y = at.y}
      w.trail = walked
      w.off_leg = {a.x, a.y, b.x, b.y}
      return withdraw(w, "no way through")
    end
  end
  -- Under fire on the march (FIRE_LOSS within FIRE_WINDOW, turrets within FIRE_NEAR): it breaks in where it stands.
  if w.stage == "march" then
    -- (Its losses to guns and armed units alone, w.gun_lost: a herd strung out past a mined corner lost 10 to the mines, the
    -- rule read that as fire, and it broke in at the corner, into the minefield, 518 mediums lost; the user's fort.)
    w.fire_log = w.fire_log or {}
    local now = alive(w)
    table.insert(w.fire_log, {tick, w.gun_lost or 0})
    while #w.fire_log > 1 and tick - w.fire_log[1][1] > FIRE_WINDOW do table.remove(w.fire_log, 1) end
    local bled = (w.rival_lost or 0) >= FIRE_LOSS * (w.size or now)
    if bled or (w.gun_lost or 0) - w.fire_log[1][2] > FIRE_LOSS * (w.size or now) then
      -- (Bled by another: looked for where its killers stand.)
      local at = bled and w.rival_at or where(w)
      w.rival_lost = 0
      -- (Anyone's guns or armed units: walking on through a corporation's camp under orders to ignore it, a wave of 265
      -- lost 240 and killed nothing; 2026-10-27.)
      -- (Round its middle, wider for a bigger herd: a column of 381 lost 271 to railgunners firing from 30 tiles off its
      -- flank, none within FIRE_NEAR of its middle, and walked on.)
      local near = s.find_entities_filtered{position = at, radius = FIRE_NEAR + DETOUR_PER * math.sqrt(now), type = threat.ARMED,
        force = hostiles()}
      -- Who shoots it: its target's own (it breaks in where it stands, below), or another (a corporation's camp it passes):
      -- it turns on them, every one of its own fighting what it meets there, and then marches on. (Breaking in where it
      -- stood at Kessler-Hayashi's flamers, 100 tiles from the player's wall, its siege sent its bursters from there and its
      -- herd came to the breach late and scattered, and went home; a megabase, 2026-10-28.)
      local mine, other = nil, nil
      local targets = {}
      for _, f in ipairs(foes(w)) do targets[type(f) == "string" and f or f.name] = true end
      for _, e in ipairs(near) do
        if targets[e.force.name] then mine = mine or e else other = other or e end
      end
      if other and not mine then
        -- What shoots it there, priced as it now knows it (learn_march), its big bursters' work counted (herd.way_cost):
        -- what it can take it takes (the user, 2026-10-28: a wave "full of bursters and a lot of big biters ... in contact
        -- with the KH camp ... it makes no sense that they don't just turn on KH and annihilate them"), its bursters at the
        -- guns; what it cannot, it goes round, a new way to its mark.
        learn_march(w)
        local reach = FIRE_NEAR + herd.spread(now)
        local guns, cost, turrets, units_cost = 0, 0, {}, 0
        for _, e in ipairs(s.find_entities_filtered{position = other.position, radius = reach, type = threat.ARMED,
          force = other.force}) do
          if threat.firing(e) then
            cost = cost + herd.price_of(e)
            if e.type ~= "unit" then guns = guns + 1; turrets[#turrets + 1] = e else units_cost = units_cost + herd.price_of(e) end
          end
        end
        local big = 0
        for _, u in ipairs(w.members) do if u.valid and u.name == "lp-bred-big-burster" then big = big + 1 end end
        -- (Its bursters take guns, not the units round them: they are paid whole. Its bursters counted against the whole of
        -- a camp, railgunners and all, a wave of 120 turned on one priced at 17 and lost 90 to its railgunners; 2026-10-29.)
        local lost = herd.way_cost(cost - units_cost, guns, big) + units_cost
        if herd.affords(herd.strength(w.members), lost) then
          log(w, string.format("under fire on the march (%d lost in %d s) from %s: its guns and units there cost %.0f, %.0f with its %d big bursters: it turns on them",
            (w.gun_lost or 0) - w.fire_log[1][2], math.floor((tick - w.fire_log[1][1]) / 60), other.force.name, cost, lost, big))
          w.fire_log = nil
          w.fought = (w.fought or 0) + 1
          local sent = send_big_bursters(w, s, {other.force}, at, {x = other.position.x, y = other.position.y}, true, turrets)
          -- As at a wall: its bursters at their guns first, its herd back out of their fire on its trail till they are
          -- spent, then in (charging in with them, it stood in the flamers' fire and lost 79 of 120; 2026-10-28). Its fight
          -- on till nothing of theirs within reach of it fires (step).
          w.fighting = {force = other.force.name, at = {x = other.position.x, y = other.position.y}, reach = reach,
            stage = sent > 0 and "bursters" or "assault"}
          ensure_group(w)
          if w.group and w.group.valid then
            if sent > 0 then
              w.group.set_command(compound({go(w.trail[math.max(1, w.leg - 1)], defines.distraction.none, 6),
                {type = defines.command.stop, distraction = defines.distraction.none}}))
            else
              w.group.set_command{type = defines.command.attack_area, destination = other.position, radius = reach,
                distraction = defines.distraction.by_anything}
            end
          end
          return
        end
        local path, cost2 = replan(w, at)
        log(w, string.format("under fire on the march (%d lost in %d s) from %s: %s", (w.gun_lost or 0) - w.fire_log[1][2],
          math.floor((tick - w.fire_log[1][1]) / 60), other.force.name,
          path and string.format("not theirs to take (%.0f, %.0f with its %d big bursters): a new way round them to its mark (costing %.0f)",
            cost, lost, big, cost2) or "not theirs to take, and no way round them it can pay: home"))
        w.fire_log = nil
        if not path then return withdraw(w, "under fire on the march") end
        local trail = {}
        for k = 1, w.leg - 1 do trail[#trail + 1] = w.trail[k] end
        trail[#trail + 1] = {x = at.x, y = at.y}
        local from = #trail
        for k = REPLAN_STRIDE, #path, REPLAN_STRIDE do trail[#trail + 1] = path[k] end
        trail[#trail + 1] = {x = w.mark.x, y = w.mark.y}
        w.trail, w.leg = trail, from + 1
        return march(w)
      end
      if mine then
        log(w, string.format("under fire on the march (%d lost in %d s): breaks in where it stands, at %.0f,%.0f",
          (w.gun_lost or 0) - w.fire_log[1][2], math.floor((tick - w.fire_log[1][1]) / 60), at.x, at.y))
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

-- Its rams looked at as often as one crosses its touch of a wall (WALL_TOUCH over its prototype's speed), not with its
-- wave's look once a second: at the user's north wall (the nwwallsiege visit, 2026-11-05) its rams lived 1 to 2 s in the
-- reach of 15 to 18 guns, and of 22 killed short, 12 died within a tile or two of a wall between two looks, none gone off.
function herd.rk.look_every()
  local p = prototypes.entity["lp-bred-big-burster"]
  return math.max(1, math.floor(WALL_TOUCH / math.max(0.01, p and p.speed or 0.01)))
end
-- A rear's orders (cover): to the gap, the rest of its wait there, home down the trail; an attack on what hit it first.
function herd.cover_cmd(c, target)
  local cmds = {}
  if target then cmds[1] = {type = defines.command.attack, target = target, distraction = defines.distraction.none} end
  cmds[#cmds + 1] = go(c.breach, defines.distraction.none, 4)
  local left = c.till - game.tick
  if left > 0 then cmds[#cmds + 1] = {type = defines.command.stop, ticks_to_wait = left, distraction = defines.distraction.none} end
  for _, p in ipairs(c.back) do cmds[#cmds + 1] = go(p, defines.distraction.none, 6) end
  return compound(cmds)
end

-- Each second while a rear waits: one of it hurt, it answers the nearest foe that fights (a turret, a unit, a
-- character, a vehicle; never a wall) within its reach of the gap. Beyond that reach, it stands.
herd.COVER_FOES = {"ammo-turret", "electric-turret", "fluid-turret", "turret", "artillery-turret", "unit", "character",
  "car", "spider-vehicle"}
function herd.cover_tick(h, tick)
  for id, c in pairs(h.covers or {}) do
    local g = c.group
    if not (g and g.valid) or tick >= c.till then
      h.covers[id] = nil
    else
      local hurt = false
      for _, u in ipairs(g.members) do
        if u.valid then
          if u.health < (c.hp[u.unit_number] or u.health) then hurt = true end
          c.hp[u.unit_number] = u.health
        end
      end
      if hurt and c.reach > 0 then
        local best, bd
        for _, e in pairs(g.surface.find_entities_filtered{position = c.breach, radius = c.reach, type = herd.COVER_FOES}) do
          if e.force ~= g.force and g.force.is_enemy(e.force) then
            local d = d2({e.position.x, e.position.y}, c.breach)
            if not bd or d < bd then best, bd = e, d end
          end
        end
        if best and best ~= c.answering then
          c.answering = best
          c.reissued = tick
          g.set_command(herd.cover_cmd(c, best))
        end
      end
    end
  end
end

function herd.tick(tick)
  local h = storage.herd
  if not h then return end
  if tick % 60 == 31 and h.covers then herd.cover_tick(h, tick) end
  local every
  for _, w in pairs(h.waves) do
    if w.stage == "scout" or tick % 60 == 0 then step(w, tick)
    elseif w.big_targets and not storage.biotech_slow_rams then
      every = every or herd.rk.look_every()
      if tick % every == 0 then detonate(w) end
    end
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

-- Tests: the engine disbanding a wave's group, as it does on the way (herd test, deepdrop).
-- Tests only: n units of a breed made at an incubator and put in its stock (farm siegepoor: a stock rich past its biomass).
function herd.debug_add_stock(id, name, n)
  local rec = herd.pen(id)
  if not (rec and rec.pen.valid) then return 0 end
  local s, k = rec.pen.surface, 0
  for _ = 1, n do
    local p = s.find_non_colliding_position(name, rec.pen.position, 32, 0.5)
    local e = p and s.create_entity{name = name, position = p, force = B.force}
    if e then table.insert(rec.stock, e); k = k + 1 end
  end
  return k
end
function herd.debug_drop_group(id)
  local w = storage.herd and storage.herd.waves[id]
  if not (w and w.group and w.group.valid) then return false end
  w.group.destroy()
  return true
end

-- Through: inside from here (its rush's order done, and its herd past the wall, herd.rk.hold_rush).
function herd.rk.through_now(w)
  w.stage = "inside"; w.t_inside = game.tick
  -- (Through: its stay rule's again from here, its losses counted from what got there.)
  if w.committed then
    w.committed = nil
    w.size, w.loss_log = alive(w), nil
    log(w, string.format("through to its target with %d", w.size))
  end
  -- A deep strike: past what is near, on to the heart, fighting nothing; there it hunts.
  if w.deep and not w.deep.reached then
    w.deep.going, w.deep.t_go = true, game.tick
    -- Its spitters stay at the breach (sent back from the heart they crossed the base again, late and few).
    hold_breach(w)
    -- Along the way it priced, round the fire (the user, 2026-10-28: "why don't we simply avoid going in a straight
    -- line?"): told to go straight to it, the engine's shortest way crossed a second laser line and a line of
    -- flamethrowers it had priced its way round, and it lost 54 there.
    local pts = {}
    for _, q in ipairs(w.deep.way or {}) do pts[#pts + 1] = q end
    pts[#pts + 1] = w.deep.at
    local cmds = inside_legs(w, foremost(w), pts)
    cmds[#cmds] = go(w.deep.at, defines.distraction.none, 8)
    w.group.set_command(compound(cmds))
    -- (Its legs in the log: those of the trailer's wave of 200 had run out and round the walls, inside_legs.)
    local legs = {}
    for _, c in ipairs(cmds) do legs[#legs + 1] = string.format("%.0f,%.0f", c.destination.x, c.destination.y) end
    log(w, string.format("rushes for the heart at %.0f,%.0f, %d legs round the fire (%s, of %d on its way)", w.deep.at.x,
      w.deep.at.y, #cmds, table.concat(legs, " "), #pts))
    return
  end
  stay_begin(w)
  return hunt(w)
end

function herd.on_command_completed(e)
  local h = storage.herd
  if not h then return end
  local rear = h.rears and h.rears[e.unit_number]
  -- (Not the order it was just given in place of the last, herd.cover_tick.)
  local c = h.covers and h.covers[e.unit_number]
  if rear and c and c.reissued == game.tick then return end
  if rear then
    h.rears[e.unit_number] = nil
    if h.covers then h.covers[e.unit_number] = nil end
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
      -- (A wait for its stragglers ended, march: the same leg again, not the next.)
      -- (A strike's wait at its mark ended by the clock: waits on, cut_wait decides.)
      if w.stage == "march" and w.cut_hold then
        if w.group.valid then
          w.group.set_command{type = defines.command.stop, ticks_to_wait = CUT_HOLD, distraction = defines.distraction.by_damage}
        end
        return
      end
      if w.stage == "march" and w.waiting then
        w.waiting = nil
        if w.group.valid then march(w) end
        return
      end
      if w.stage == "march" then
        if e.result ~= defines.behavior_result.success then
          w.legs_failed = (w.legs_failed or 0) + 1
          w.leg_failed_at = game.tick
          local q, at = w.trail[w.leg], where(w)
          log(w, string.format("leg %d of %d of its trail failed (%s): to %s from %.0f,%.0f", w.leg, #w.trail, tostring(e.result),
            q and string.format("%.0f,%.0f", q.x, q.y) or "?", at.x, at.y))
        end
        -- A leg walked: its regroups start again (REGROUPS a leg).
        if e.result == defines.behavior_result.success then w.regroups = 0 end
        -- Where the herd stood at each leg's end, against the trail it was given (the visit's wave map draws both).
        local at = where(w)
        w.walked = w.walked or {}
        w.walked[#w.walked + 1] = {math.floor(at.x), math.floor(at.y), w.leg, e.result == defines.behavior_result.success}
        w.leg = (w.leg or #w.trail) + 1
        if w.leg <= #w.trail then
          -- (A failed order disbands a group on 2.1: step forms it again and goes on from this leg.)
          if w.group.valid then march(w) end
          return
        end
        -- (Having fought on the way: what is left of it pays its way in, or it goes home.)
        if w.fought and not plan_pays(w) then
          log(w, string.format("what is left of it after its fight (%d) cannot pay its way in: home", alive(w)))
          return withdraw(w, "spent on the way")
        end
        -- A strike: at its mark till its cutters' feed falls (cut_hold, step).
        if w.wait_cut and w.wait_cut.e and w.wait_cut.e.valid then
          if not w.cut_hold then
            w.cut_hold = game.tick
            log(w, "at its mark: waits for its cutters")
          end
          w.group.set_command{type = defines.command.stop, ticks_to_wait = CUT_HOLD, distraction = defines.distraction.by_damage}
          return
        end
        probe_read(w); return breach(w)
      end
      if w.stage == "breach" then
        if storage.trace and w.rushed then
          local f = foremost(w)
          log(w, string.format("its rush's order done (%s), its front at %.0f,%.0f", e.result == defines.behavior_result.success
            and "reached" or "failed", f.x, f.y))
        end
        -- Through only past the wall: a wall still standing between it and its target, it goes at that wall first. (Its
        -- orders done within 6 tiles of a target 2 tiles behind the wall, its waves were through with no wall broken, from
        -- outside it, and their attempts read as got in; the lane, the siege lab, 2026-10-31.)
        local wall = (w.wall_tries or 0) < WALL_TRIES and w.goal and wall_between(w, foremost(w), w.goal)
        if wall and w.group.valid then
          w.wall_tries = (w.wall_tries or 0) + 1
          -- (Its gap open: through it, not at the wall beside it, gap_way.)
          if gap_open(w) then
            log(w, string.format("a wall between it and its target at %.0f,%.0f: through its gap at %.0f,%.0f", wall.position.x,
              wall.position.y, w.gap.x, w.gap.y))
            w.group.set_command(compound({go(w.gap, defines.distraction.none, 3), go(w.goal, defines.distraction.none, 6)}))
            return
          end
          log(w, string.format("a wall between it and its target at %.0f,%.0f: it goes at it", wall.position.x, wall.position.y))
          w.group.set_command{type = defines.command.attack, target = wall, distraction = defines.distraction.by_enemy}
          return
        end
        -- (Through by its herd, not its front: herd.rk.hold_rush.)
        if herd.rk.hold_rush(w) then return end
        return herd.rk.through_now(w)
      end
      if w.stage == "inside" and w.deep and w.deep.going then
        return rush_end(w, e.result == defines.behavior_result.success and "reached" or "as far as it got")
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
  -- (Its stompers are spider-units: read as units only, their deaths went unrecorded and a siege's check counted two as
  -- gone from the map with no death, farm siege, 0.3.0.)
  if ent.force.name == B.force and (ent.type == "unit" or ent.type == "spider-unit") then
    for _, w in pairs(h.waves) do
      for _, u in ipairs(w.members) do
        if u == ent then
          w.died = w.died or {}
          w.died[ent.unit_number] = true
          local c = e.cause and e.cause.valid and e.cause
          local key = w.stage .. " " .. (c and (c.force.name == "enemy" and "wild " or "") .. c.name or "none")
          w.lost_by = w.lost_by or {}
          w.lost_by[key] = (w.lost_by[key] or 0) + 1
          -- (And in mediums, what its prices are learned in: herd.strength.)
          w.lost_worth_by = w.lost_worth_by or {}
          -- (Its rams at their worth as any unit's: by herd.strength, which leaves them out of a herd's strength, sixteen big
          -- bursters killed at the square lab fort's wall cost it nothing, its lasers read cheap; 2026-10-31.)
          -- (At its killer's rank: what a fresh one of its kind costs it, its price read at each one's rank, herd.price_of.)
          w.lost_worth_by[key] = (w.lost_worth_by[key] or 0) + herd.worth(ent.name) / shared.rank_scale(c or nil)
          -- A ram of a rank killed short: its rank's reading (herd.rk.size_next).
          if ent.name == "lp-bred-big-burster" then herd.rk.read_death(w, ent) end
          -- (Traced: by its part at the breach, a ram, its screen, its herd held or its herd rushing; and each ram's death.)
          if storage.trace and w.stage == "breach" then
            local part = ent.name == "lp-bred-big-burster" and "ram" or (w.fodder_set and w.fodder_set[ent.unit_number]) and "screen"
              or w.held_cmds and "held" or "rush"
            local pk = part .. " " .. (c and c.name or "none")
            w.part_lost = w.part_lost or {}
            w.part_lost[pk] = (w.part_lost[pk] or 0) + herd.worth(ent.name)
            if part == "rush" then
              local bk = string.format("%d,%d", math.floor(ent.position.x / 8) * 8, math.floor(ent.position.y / 4) * 4)
              w.rush_at = w.rush_at or {}
              w.rush_at[bk] = (w.rush_at[bk] or 0) + 1
            end
            if part == "ram" then
              for _, b in ipairs(w.big_targets or {}) do
                if b.unit == ent then
                  local to = b.through and b.through.valid and b.through.position or b.target and b.target.valid and b.target.position
                  log(w, string.format("its ram of rank %s killed short by %s #%s (%s) at %.0f,%.0f, %s guns covering it, in reach %s s, %.0f s after it went, %s from its wall, %s from its gap%s",
                    tostring(b.rank or "-"), c and c.name or "none", tostring(c and c.unit_number), e.damage_type and e.damage_type.name or "?",
                    ent.position.x, ent.position.y, #firemap.entries(firemap.read(ent.surface, ent.position, 0, foes(w)), ent.position),
                    b.in_reach and string.format("%.1f", (game.tick - b.in_reach) / 60) or "-", b.sent and (game.tick - b.sent) / 60 or -1, to and string.format("%.1f", math.sqrt(d2(ent.position, to))) or "-",
                    w.gap and string.format("%.1f", math.sqrt(d2(ent.position, w.gap))) or "-", b.held and ", held" or b.reserve and ", in reserve" or ""))
                  break
                end
              end
            end
          end
          -- And by what it died of (the event's damage type), at its foes' hands: its share lost to area damage, what it
          -- reads to spread out (tactics.area_share; the adaptive tactics consult, 2026-11-05).
          if e.damage_type and e.force and e.force.name ~= B.force then
            w.lost_dmg = w.lost_dmg or {}
            local dt = e.damage_type.name
            w.lost_dmg[dt] = (w.lost_dmg[dt] or 0) + herd.worth(ent.name)
          end
          -- Where (its record: scripts/wavemap.py), at most DEAD_AT.
          w.dead_at = w.dead_at or {}
          if #w.dead_at < DEAD_AT then w.dead_at[#w.dead_at + 1] = {math.floor(ent.position.x), math.floor(ent.position.y), w.stage} end
          -- (Its killers on the march, by name, where they stood: their price learned, learn_price.)
          -- (Its killers inside and on its way out as well, each stage apart: their price learned as the march's, learn_march.
          -- Learned at the breach alone, a star fort's waves lost 1,446 of 1,748 mediums to its mines and lasers on the way out
          -- and its laser price fell; the siege lab, 2026-10-30.)
          if (w.stage == "inside" or w.stage == "withdraw") and c and c.force.name ~= B.force then
            w.march_killers = w.march_killers or {}
            local key = w.stage .. " " .. c.name
            local mk = w.march_killers[key] or {name = c.name, force = c.force.name, n = 0, worth = 0, x = 0, y = 0}
            mk.n, mk.x, mk.y = mk.n + 1, mk.x + c.position.x, mk.y + c.position.y
            mk.worth = mk.worth + herd.worth(ent.name)
            mk.ids = mk.ids or {}
            mk.ids[c.unit_number or 0] = true
            w.march_killers[key] = mk
          end
          if w.stage == "march" and c and c.force.name ~= B.force and c.type ~= "land-mine" then w.gun_lost = (w.gun_lost or 0) + 1 end
          if w.stage == "march" and c and c.force.name ~= B.force then
            -- (Killed by other than its target's: counted to the end of its march, no window: a slow bleed at a camp's walls,
            -- 66 over two minutes, never made a tenth in any 15 s, and it was never answered; 2026-10-28.)
            local theirs = false
            for _, f in ipairs(foes(w)) do if (type(f) == "string" and f or f.name) == c.force.name then theirs = true end end
            if not theirs then
              w.rival_lost = (w.rival_lost or 0) + 1
              w.rival_at = {x = c.position.x, y = c.position.y}
            end
            w.march_killers = w.march_killers or {}
            local mk = w.march_killers[c.name] or {force = c.force.name, n = 0, worth = 0, x = 0, y = 0}
            mk.n, mk.x, mk.y = mk.n + 1, mk.x + c.position.x, mk.y + c.position.y
            mk.worth = (mk.worth or mk.n - 1) + herd.worth(ent.name)
            w.march_killers[c.name] = mk
          end
          break
        end
      end
    end
  end
  if e.force and e.force.name == B.force and shared.is_player_force(ent.force) then
    for _, w in pairs(h.waves) do
      if w.stage ~= "scout" then
        w.kills[ent.name] = (w.kills[ent.name] or 0) + 1
        w.razed_worth = (w.razed_worth or 0) + valuemap.razed_of(ent)
        local m = w.stay_m
        if m and not m.done then
          m.all = (m.all or 0) + (ent.max_health or 0)
          if valuemap.worth_of(ent) > 0 then m.broke, m.hp = m.broke + 1, m.hp + (ent.max_health or 0) end
        end
        if not w.t_first_kill and ent.type ~= "wall" and ent.type ~= "gate" then w.t_first_kill = game.tick end
        -- Its gap: of the wall pieces of the foe's it broke from its breach on, the one nearest where it breaks in (gap_way:
        -- its biters through it). (The first broken can be a stray piece 10 tiles along the wall, chewed by biters strung
        -- out beside the breach before its own pieces fell; herd test.)
        -- A spread's first gap at any of its points (within two blasts of one) calls its herd there: its breach that point,
        -- its held way in through that gap (the adaptive tactics consult, 2026-11-05: the first gap at any lane).
        local lane, ld
        if w.spread and not w.spread.opened and (ent.type == "wall" or ent.type == "gate") and w.breach then
          for i, q in ipairs(w.spread.points) do
            local d = d2(ent.position, q)
            if d <= (2 * shared.BIG_BURST.r) ^ 2 and (not ld or d < ld) then lane, ld = i, d end
          end
        end
        if lane then
          local q = w.spread.points[lane]
          w.spread.opened = lane
          w.breach_wall, w.breach, w.gap = {x = q.x, y = q.y}, {x = q.x, y = q.y}, {x = ent.position.x, y = ent.position.y}
          if lane > 1 and w.held_cmds and w.goal then
            w.held_cmds = {go(w.gap, defines.distraction.none, 1.5), go(w.goal, defines.distraction.none, 6)}
          end
          log(w, string.format("its gap opens at its point %d of %d, %.0f,%.0f: its herd's way in", lane, #w.spread.points,
            ent.position.x, ent.position.y))
        elseif (ent.type == "wall" or ent.type == "gate") and w.breach then
          local at = w.breach_wall or w.breach
          local p = ent.position
          -- (Every piece it broke, by its tile: one standing there again was mended, herd.rk.keep_line.)
          w.broke = w.broke or {}
          w.broke[herd.rk.tile_key(p)] = true
          if not w.gap or d2(p, at) < d2(w.gap, at) then
            if not w.gap then log(w, string.format("its gap is open at %.0f,%.0f", p.x, p.y)) end
            w.gap = {x = p.x, y = p.y}
          end
        end
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

-- The siege lab's recorder (tests/lp-sim, mix lab): each wave on its way, its units by role, live.
function herd.lab_waves()
  local out = {}
  for id, w in pairs(st().waves) do
    if w.stage ~= "done" then
      -- (Only the living: a dead one crosses the interface as nothing, and leaves a hole in a list.)
      local function live(list)
        local l = {}
        for _, u in ipairs(list or {}) do if u.valid then l[#l + 1] = u end end
        return l
      end
      local big = {}
      for _, b in ipairs(w.big_targets or {}) do
        if b.unit.valid and b.target and b.target.valid then big[#big + 1] = {unit = b.unit, target = b.target} end
      end
      out[#out + 1] = {id = id, farm = w.farm, stage = w.stage, members = live(w.members),
        scout = w.scout and w.scout.valid and w.scout or nil, sweepers = live(w.sweepers), big = big, plan = w.plan and {path = w.plan.path, start = w.plan.start,
        breach = w.plan.breach, cost = w.plan.cost, cover = w.plan.cover}}
    end
  end
  return out
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
      holding = w.holding or false, deep = w.deep and {going = w.deep.going or nil} or nil,
      gap = w.gap and {w.gap.x, w.gap.y}, gap_open = gap_open(w), rushed = w.rushed, mends = w.mends,
      pushed = w.pushed or nil}
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
