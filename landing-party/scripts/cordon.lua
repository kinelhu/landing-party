-- The cordon (the user, 2026-10-16: Serenity camps growing "into ever larger fortified areas ... progressive asphyxiation
-- by a high tech opponent"; Fable: docs/reviews/2026-10-16-walled-advance-consult.md). Serenity's line made physical: each
-- step of its perimeter is an arc of posts at the new radius, within ARC of the bearing to the player's nearest structure,
-- one every SPACING tiles: a concrete pad, a short wall facing the player, two gun turrets (fed by the camp: lasers this
-- far apart would want power lines). Its drones build them (crew.lua: they stand beyond every yard). The claim steps out
-- only once HOLD of the arc's posts stand; until then the line waits. Slice 1: no recovery of old arcs, no wall at
-- contact, no rule for nests yet.
local shared = require("__landing-party__.shared")
local ops = require("__landing-party__.scripts.ops")
local base = require("__landing-party__.scripts.base")
local prospect = require("__landing-party__.scripts.prospect")

local cordon = {}

local ARC = math.pi / 3           -- either side of the bearing
local SPACING = 60
local HOLD = 0.8
local WALL = 8                    -- wall pieces in a post's front
local KEEP = 2                    -- arcs kept standing: the leading one and one behind
local CONTACT = 60                -- an arc this near the player's nearest building closes its middle with wall
local CONTACT_ARC = math.rad(25)  -- the posts within this of the bearing are joined
local OPENING = 3                 -- tiles left open mid-span for its own ground units
local GATES = 3                   -- gate posts a step at most

-- Wall tiles from a to c, side-joined only (a diagonal of walls leaves corner gaps units walk through).
local function wall_line(a, c)
  local x, y = math.floor(a[1]), math.floor(a[2])
  local x1, y1 = math.floor(c[1]), math.floor(c[2])
  local out = {}
  local dx, dy = math.abs(x1 - x), math.abs(y1 - y)
  local sx, sy = x < x1 and 1 or -1, y < y1 and 1 or -1
  local err = dx - dy
  while true do
    table.insert(out, {x + 0.5, y + 0.5})
    if x == x1 and y == y1 then break end
    -- One axis a step: never both (side-joined).
    if 2 * err > -dy and (2 * err >= dx or dy == 0) then err = err - dy; x = x + sx
    else err = err + dx; y = y + sy end
  end
  return out
end

local function bearing(b, near)
  if near and near.valid then
    return math.atan2(near.position.y - b.origin.y, near.position.x - b.origin.x)
  end
end

local function post_jobs(b, m, p, a)
  -- Radial (toward the player) and tangent unit vectors at the post.
  local rx, ry = math.cos(a), math.sin(a)
  local tx, ty = -ry, rx
  local jobs = {}
  local tiles = {}
  for i = -2, 2 do for j = -2, 2 do table.insert(tiles, {math.floor(p[1] + i), math.floor(p[2] + j)}) end end
  table.insert(jobs, {tiles = tiles, floor = "pad", module = m})
  for k = 1, WALL do
    local s = k - (WALL + 1) / 2
    table.insert(jobs, {name = "lp-wall", pos = {p[1] + rx * 4 + tx * s, p[2] + ry * 4 + ty * s}, module = m})
  end
  for _, s in ipairs({-2, 2}) do
    table.insert(jobs, {name = "lp-gun-turret", pos = {p[1] + tx * s, p[2] + ty * s}, module = m})
  end
  return jobs
end

-- ops.perimeter asks with the step it would take: true while its arc is being built (the claim waits), false to step.
function cordon.step(b, new, near)
  if storage.cordon_off or not shared.CORPS[b.corp].cordon then return false end
  local c = b.cordon
  if c then
    local built, n = 0, #c.posts
    for _, m in ipairs(c.posts) do if m.built then built = built + 1 end end
    if built < HOLD * n then return true end
    -- The arc stands: the claim steps out to it, and the arc two behind is recovered (Fable: keep the leading arc and
    -- one behind; older posts come down, half their parts back: 38 posts and 80 turrets by 275 tiles otherwise).
    b.cordon = nil
    b.cordon_history = b.cordon_history or {}
    table.insert(b.cordon_history, c)
    while #b.cordon_history > KEEP do
      local old = table.remove(b.cordon_history, 1)
      local back, gone = 0, 0
      local mods = {}
      for _, m in ipairs(old.posts) do table.insert(mods, m) end
      for _, m in ipairs(old.walls or {}) do table.insert(mods, m) end
      for _, m in ipairs(old.gates or {}) do table.insert(mods, m) end
      for _, m in ipairs(mods) do
        for _, e in ipairs(m.entities or {}) do
          if e.valid then
            back = back + math.floor((shared.cost[shared.kind_of(e.name)] or 0) / 2)
            e.surface.create_entity{name = "explosion-hit", position = e.position}
            storage.owner[e.unit_number] = nil
            e.destroy()
            gone = gone + 1
          end
        end
        m.recovered = true
      end
      b.parts = b.parts + back
      b.cordon_recovered = (b.cordon_recovered or 0) + gone
      base.trace(b, string.format("cordon: the arc at %.0f recovered (%d pieces, %d parts back)", old.radius, gone, back))
    end
    b.cordon_arcs = (b.cordon_arcs or 0) + 1
    b.cordon_posts = (b.cordon_posts or 0) + built
    ops.perimeter_advance(b, c.radius, near, near and near.valid and math.sqrt((near.position.x - b.origin.x) ^ 2
      + (near.position.y - b.origin.y) ^ 2) or nil)
    base.trace(b, string.format("cordon: the arc at %.0f stands (%d of %d posts); the claim steps out", c.radius, built, n))
    return true
  end
  -- Nothing of the player's in reach: a line with no front holds (stepping out on its own, the claim ran to 450 once
  -- its relay was razed).
  local a0 = bearing(b, near)
  if not a0 then return true end
  local len = 2 * ARC * new
  local n = math.max(3, math.floor(len / SPACING) + 1)
  c = {radius = new, bearing = a0, posts = {}, started = game.tick}
  for k = 0, n - 1 do
    local a = a0 - ARC + 2 * ARC * k / (n - 1)
    local p = {b.origin.x + math.cos(a) * new, b.origin.y + math.sin(a) * new}
    local m = {kind = "post", center = p, entities = {}}
    table.insert(c.posts, m)
  end
  -- First in the queue (behind the camp's growth they waited 4.6 minutes for their drones).
  local jobs = {}
  for k, m in ipairs(c.posts) do
    local a = a0 - ARC + 2 * ARC * (k - 1) / (n - 1)
    for _, j in ipairs(post_jobs(b, m, m.center, a)) do table.insert(jobs, j) end
  end
  -- Gate posts (Fable: a route the arc crosses gets a gate): where the arc crosses a player's straight rail, two gates
  -- across it (a gate of another force on a player's rail stops their trains: spike, DESIGN Engine notes) and two gun
  -- turrets beside. Diagonal rails take no gate. At most GATES a step.
  c.gates = {}
  local s = game.surfaces[b.surface]
  local seen = {}
  for _, f in pairs(game.forces) do
    if shared.is_player_force(f) and #c.gates < GATES then
      for _, r in pairs(s.find_entities_filtered{type = "straight-rail", force = f, position = {b.origin.x, b.origin.y},
        radius = new + 3}) do
        local rx, ry = r.position.x, r.position.y
        local d = math.sqrt((rx - b.origin.x) ^ 2 + (ry - b.origin.y) ^ 2)
        local a = math.atan2(ry - b.origin.y, rx - b.origin.x)
        local da = math.abs(((a - a0 + math.pi) % (2 * math.pi)) - math.pi)
        local dir = r.direction
        local horizontal = dir == defines.direction.east or dir == defines.direction.west
        local vertical = dir == defines.direction.north or dir == defines.direction.south
        local near_seen = false
        for _, q in ipairs(seen) do if (q[1] - rx) ^ 2 + (q[2] - ry) ^ 2 < 100 then near_seen = true end end
        if math.abs(d - new) <= 2.5 and da <= ARC and (horizontal or vertical) and not near_seen and #c.gates < GATES then
          table.insert(seen, {rx, ry})
          local m = {kind = "post", center = {rx, ry}, entities = {}, gate = true}
          local g = horizontal and {{rx - 0.5, ry - 0.5}, {rx - 0.5, ry + 0.5}} or {{rx - 0.5, ry - 0.5}, {rx + 0.5, ry - 0.5}}
          local gdir = horizontal and defines.direction.north or defines.direction.east
          for _, p in ipairs(g) do table.insert(jobs, {name = "lp-gate", pos = p, dir = gdir, module = m}) end
          local off = horizontal and {{0, -5}, {0, 5}} or {{-5, 0}, {5, 0}}
          for _, o in ipairs(off) do table.insert(jobs, {name = "lp-gun-turret", pos = {rx + o[1], ry + o[2]}, module = m, loose = true}) end
          table.insert(c.gates, m)
        end
      end
    end
  end
  if #c.gates > 0 then
    b.cordon_gates = (b.cordon_gates or 0) + #c.gates
    base.trace(b, string.format("cordon: %d gate posts across the player's rails at %.0f", #c.gates, new))
  end
  -- Ore the arc crosses (Fable: the line pays for the line): at most one patch a step, within 10 of the arc, that no
  -- player drill works: a claim of the camp (prospect.claim: a generator, a pylon, three drills), built by its drones.
  -- Along the arc every 5 degrees (beside the posts only, it missed a patch between two posts 60 apart).
  for k = -ARC, ARC + 1e-6, math.rad(5) do
    local at = {b.origin.x + math.cos(a0 + k) * new, b.origin.y + math.sin(a0 + k) * new}
    if b.cordon_claimed_at ~= new then
      local ore = s.find_entities_filtered{position = at, radius = 10, type = "resource", limit = 1}[1]
      if ore and ore.prototype.resource_category == "basic-solid"
        and s.count_entities_filtered{position = at, radius = 10, type = "resource", limit = 20} >= 20
        and not prospect.worked(s, at) then
        b.cordon_claimed_at = new
        prospect.claim(b, {x = ore.position.x, y = ore.position.y})
        b.cordon_ore = (b.cordon_ore or 0) + 1
        base.trace(b, string.format("cordon: the arc at %.0f crosses %s at %.0f,%.0f: claimed", new, ore.name, ore.position.x,
          ore.position.y))
      end
    end
  end
  -- Contact (Fable: "the asphyxiation moment"): an arc within CONTACT of the player's nearest building closes its middle,
  -- the posts within CONTACT_ARC of the bearing joined by wall, an opening left mid-span.
  local nd = near and near.valid and math.sqrt((near.position.x - b.origin.x) ^ 2 + (near.position.y - b.origin.y) ^ 2)
  c.walls = {}
  -- Its wall jobs go last (posts first: queued ahead of them the walls slowed the arcs, and the line fell behind).
  local wall_jobs = {}
  if nd and nd - new <= CONTACT then
    for k = 1, n - 1 do
      local a1 = a0 - ARC + 2 * ARC * (k - 1) / (n - 1)
      local a2 = a0 - ARC + 2 * ARC * k / (n - 1)
      local mid = (a1 + a2) / 2
      if math.abs(mid - a0) <= CONTACT_ARC then
        local p1, p2 = c.posts[k].center, c.posts[k + 1].center
        local m = {kind = "post", center = {(p1[1] + p2[1]) / 2, (p1[2] + p2[2]) / 2}, entities = {}}
        local tiles = wall_line(p1, p2)
        local half = #tiles / 2
        for i, t in ipairs(tiles) do
          local far1 = (t[1] - p1[1]) ^ 2 + (t[2] - p1[2]) ^ 2 > 16
          local far2 = (t[1] - p2[1]) ^ 2 + (t[2] - p2[2]) ^ 2 > 16
          if far1 and far2 and math.abs(i - half) > OPENING / 2 then
            table.insert(wall_jobs, {name = "lp-wall", pos = t, module = m})
          end
        end
        table.insert(c.walls, m)
      end
    end
    if #c.walls > 0 then
      b.cordon_contact = (b.cordon_contact or 0) + 1
      base.trace(b, string.format("cordon: contact at %.0f (%.0f from the player): %d spans walled", new, nd, #c.walls))
    end
  end
  for i = #jobs, 1, -1 do table.insert(b.queue, 1, jobs[i]) end
  for _, j in ipairs(wall_jobs) do table.insert(b.queue, j) end
  b.cordon = c
  b.cordon_bearings = b.cordon_bearings or {}
  table.insert(b.cordon_bearings, math.floor(math.deg(a0) + 0.5))
  base.trace(b, string.format("cordon: an arc of %d posts at %.0f, bearing %.0f degrees", n, new, math.deg(a0)))
  return true
end

function cordon.stats(b)
  local c = b.cordon
  local built = 0
  for _, m in ipairs(c and c.posts or {}) do if m.built then built = built + 1 end end
  return {arcs = b.cordon_arcs or 0, posts = b.cordon_posts or 0, pending = c and #c.posts or 0, pending_built = built,
    radius = c and c.radius, perimeter = b.perimeter, bearings = b.cordon_bearings or {}, recovered = b.cordon_recovered or 0,
    contact = b.cordon_contact or 0, gates = b.cordon_gates or 0, ore = b.cordon_ore or 0, severed = b.severed or 0}
end

ops.cordon_step = cordon.step
return cordon
