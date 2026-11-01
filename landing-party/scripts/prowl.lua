-- The prowl (Grubstake; the user, 2026-11-01: "Grubstake might steal buildings instead of destroying them", and its
-- deathworld10x mine "un defended"). A camp knows only what its sensors saw near it and along the line to the player's
-- spawn (intel's survey), so a thief never learned of an outpost round the far side: on the reference laser base it knew
-- only the core's substations, on deathworld10x never the player's undefended mine. Every AGAIN a camp sends one buggy
-- round the player's base on a ring clear of every turret's reach, POINTS points, each pushed out from the base until no
-- turret covers it; what the buggy passes within SIGHT goes into the camp's intel (ops.sense_at), as any unit's sight
-- does. Then it drives home and rejoins the garrison. The tell: a buggy circling at the edge of the guns. Killed, the
-- next goes after COOLDOWN, its ring keeping DANGER off where it died. On for corporations that prowl (shared.CORPS
-- prowls: Grubstake); debug_tune prowl = false turns it off.
local shared = require("__landing-party__.shared")
local base = require("__landing-party__.scripts.base")
local ops = require("__landing-party__.scripts.ops")
local pool = require("__landing-party__.scripts.pool")
local threat = require("__landing-party__.scripts.threat")

local prowl = {}
local POINTS = 12
local SIGHT = 60
local SPARE = 8                -- tiles beyond a turret's reach its ring keeps
local PUSH = 120               -- how far out a point is pushed looking for ground no turret covers
local AGAIN = 15 * 60 * 60     -- after a prowl home
local COOLDOWN = 20 * 60 * 60  -- after a buggy lost
local STEP = 120               -- ticks between looks
local STUCK = 60 * 60          -- no nearer its point for this long: the next point
local ARRIVE = 10
local DANGER = 40              -- tiles round where a buggy died that its ring keeps out of, for DANGER_TICKS
local DANGER_TICKS = 2 * 60 * 60 * 60

local function trace(b, msg) if base.trace then base.trace(b, "prowl: " .. msg) end end
local function is_buggy(u) return u.valid and shared.kind_of(u.name) == "lp-buggy" end

local function foes_of(b)
  local out = {}
  for _, f in pairs(game.forces) do
    if shared.is_player_force(f) and not f.get_cease_fire(b.force) then out[#out + 1] = f end
  end
  return out
end

-- Its ring: round the player's spawn, as far out as the edge its survey found (b.front), each point pushed outward
-- until no turret of the player's covers it.
local function ring(b, s, f)
  local sp = f.get_spawn_position(s)
  local front = b.front and b.front[f.name]
  local r = front and math.sqrt((front[1] - sp.x) ^ 2 + (front[2] - sp.y) ^ 2)
    or 0.6 * math.sqrt((b.origin.x - sp.x) ^ 2 + (b.origin.y - sp.y) ^ 2)
  -- Its first point the one nearest the camp, so it sets out toward the base, not across it.
  local a0 = math.atan2(b.origin.y - sp.y, b.origin.x - sp.x)
  local pts = {}
  for k = 0, POINTS - 1 do
    local a = a0 + k * 2 * math.pi / POINTS
    local p
    for out = 0, PUSH, 10 do
      local q = {x = sp.x + math.cos(a) * (r + out), y = sp.y + math.sin(a) * (r + out)}
      if not s.is_chunk_generated{math.floor(q.x / 32), math.floor(q.y / 32)} then break end
      if threat.covering(s, q, {f}, 1, SPARE) == 0 then p = q; break end
    end
    -- Not where a buggy of its died lately (on deathworld10x one died at its second point ten prowls running).
    for _, dz in ipairs(b.prowl_danger or {}) do
      if p and game.tick < dz.till and (p.x - dz.pos[1]) ^ 2 + (p.y - dz.pos[2]) ^ 2 <= DANGER * DANGER then p = nil end
    end
    if p then
      local q = s.find_non_colliding_position(shared.variant(b.corp, "lp-buggy"), p, 12, 1)
      if q then pts[#pts + 1] = {q.x, q.y} end
    end
  end
  return pts
end

local function go(u, p)
  u.commandable.set_command{type = defines.command.go_to_location, destination = {p[1], p[2]}, radius = 4,
    distraction = defines.distraction.none}
end

local function home_of(b)
  for _, d in ipairs(b.depots or {}) do if d.valid then return d end end
  return b.lander and b.lander.valid and b.lander or nil
end

local function start(b, tick)
  local s = game.surfaces[b.surface]
  local foes = foes_of(b)
  if #foes == 0 then return end
  local pts = ring(b, s, foes[1])
  if #pts < 3 then
    trace(b, string.format("none (%d points of its ring clear of the guns)", #pts))
    b.prowl_next = tick + AGAIN
    return
  end
  local u = pool.take(b, 1, pool.GUARD, is_buggy)[1]
  if not u then b.prowl_next = tick + 5 * 3600; return end
  b.prowl = {unit = u, pts = pts, k = 1, best = math.huge, since = tick, started = tick, seen0 = 0}
  for _ in pairs(b.intel and b.intel.targets or {}) do b.prowl.seen0 = b.prowl.seen0 + 1 end
  b.prowls = (b.prowls or 0) + 1
  go(u, pts[1])
  trace(b, string.format("a buggy sets out round the base, %d points", #pts))
end

local function finish(b, tick, lost)
  local p = b.prowl
  local n = 0
  for _ in pairs(b.intel and b.intel.targets or {}) do n = n + 1 end
  if lost then
    b.prowl_danger = b.prowl_danger or {}
    local at = p.last or p.pts[p.k]
    table.insert(b.prowl_danger, {pos = {at[1], at[2]}, till = tick + DANGER_TICKS})
    trace(b, string.format("the buggy was lost at point %d of %d (%d cells known, %d before)", p.k, #p.pts, n, p.seen0))
    b.prowl_next = tick + COOLDOWN
  else
    trace(b, string.format("the buggy is home (%d cells known, %d before)", n, p.seen0))
    pool.give_one(b, p.unit)
    b.prowl_next = tick + AGAIN
  end
  b.prowl = nil
end

local function step(b, tick)
  local p = b.prowl
  local u = p.unit
  if not u.valid then return finish(b, tick, true) end
  p.last = {u.position.x, u.position.y}
  ops.sense_at(b, u.position, SIGHT)
  local dest = p.home and p.home or p.pts[p.k]
  local d = math.sqrt((u.position.x - dest[1]) ^ 2 + (u.position.y - dest[2]) ^ 2)
  if d < ARRIVE or tick - p.since > STUCK then
    if p.home then return finish(b, tick, false) end
    p.k = p.k + 1
    p.best, p.since = math.huge, tick
    if p.k > #p.pts then
      local h = home_of(b)
      if not h then return finish(b, tick, false) end
      p.home = {h.position.x, h.position.y}
    end
    go(u, p.home or p.pts[p.k])
  elseif d < p.best - 2 then
    p.best, p.since = d, tick
  end
end

function prowl.tick(tick)
  if storage.prowl == false or tick % STEP ~= 0 then return end
  for _, b in pairs(storage.bases or {}) do
    if not b.fallen and b.lander and b.lander.valid and (shared.CORPS[b.corp] or {}).prowls then
      if b.prowl then step(b, tick)
      elseif tick >= (b.prowl_next or 0) and b.intel then start(b, tick) end
    end
  end
end

return prowl
