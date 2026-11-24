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
-- A post's site with water within POST_DRY of it is left out of its arc or ring (0.2.499; the user, in the playtest:
-- "they built a big part of the wall on top of water (so turrets in the middle of the water)", then "Agreed" on skipping
-- it): water stops what the post would, and posts that could never stand held the claim at a lake (HOLD counts the
-- posts planned). storage.ring_fill: as before.
local POST_DRY = 4
local function wet(b, p)
  if storage.ring_fill then return false end
  local s = game.surfaces[b.surface]
  return s.count_tiles_filtered{position = p, radius = POST_DRY, collision_mask = "water_tile", limit = 1} > 0
end
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

-- A post taken down: the ground its pad covered put back (construction.pave keeps it in m.under).
local function unpave(b, m)
  if m.under and #m.under > 0 then
    game.surfaces[b.surface].set_tiles(m.under, true, false, true, false)
    m.under = nil
  end
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
  -- Its front a continuous wall (side-joined): WALL pieces set along a diagonal touched only at their corners, and read
  -- as loose blocks (the first screenshots).
  local h = (WALL - 1) / 2
  for _, q in ipairs(wall_line({p[1] + rx * 4 - tx * h, p[2] + ry * 4 - ty * h}, {p[1] + rx * 4 + tx * h, p[2] + ry * 4 + ty * h})) do
    table.insert(jobs, {name = "lp-wall", pos = q, module = m})
  end
  for _, s in ipairs(shared.POST_GUNS) do
    table.insert(jobs, {name = "lp-gun-turret", pos = {p[1] + tx * s, p[2] + ty * s}, module = m})
  end
  -- The lit line (Fable's look consult): a lamp between its guns.
  table.insert(jobs, {name = "lp-post-lamp", pos = {p[1], p[2]}, module = m})
  return jobs
end

-- The camp's back (the user, 2026-10-20: "no defense towards their back"; Fable's look consult, item 2): grown (mature:
-- it builds no more blocks, so nothing of its own is in the way), a ring of posts round the camp beyond its last block,
-- facing out, one every SPACING tiles (RING_MIN to RING_MAX), the line's own post (pad, wall, guns, lamp); no stripe.
-- Never recovered; rebuilt when lost, as any building.
local RING_MIN, RING_MAX = 8, 12
local RING_MARGIN = 20             -- beyond its furthest block or mine
function cordon.ring(b)
  if storage.cordon_off or not shared.CORPS[b.corp].cordon or not b.origin then return end
  -- Not a camp that spreads: its clusters each have their wall and guns, and a ring round them all ran 279 out, through
  -- the player's base (core3).
  if (shared.CORPS[b.corp].arch or {}).lobed and not storage.grow_to_line_off then return end
  -- Round its blocks (the camp proper): the claim follows the line, and a ring at the claim stood on the line itself
  -- (206 of 210, five sectors of eight built); round its mines too, it ran 223 out, 12 posts on 1,400 tiles. Its mines
  -- keep their own turrets.
  local r = 40
  for _, k in ipairs(b.blocks) do
    for _, c in ipairs({{k.x0, k.y0}, {k.x0 + k.w, k.y0}, {k.x0, k.y0 + k.h}, {k.x0 + k.w, k.y0 + k.h}}) do
      r = math.max(r, math.sqrt((c[1] - b.origin.x) ^ 2 + (c[2] - b.origin.y) ^ 2) + RING_MARGIN)
    end
  end
  -- Grown again out to its line (planner.lua): the old ring, now inside the camp, comes down (half its parts back).
  if b.ring then
    if r < b.ring.radius + 20 then return end
    local back, gone = 0, 0
    for _, m in ipairs(b.ring.posts) do
      for _, e in ipairs(m.entities or {}) do
        if e.valid then
          back = back + math.floor((shared.cost[shared.kind_of(e.name)] or 0) / 2)
          storage.owner[e.unit_number] = nil
          e.destroy()
          gone = gone + 1
        end
      end
      m.recovered = true
      unpave(b, m)
    end
    local mods = {}
    for _, m in ipairs(b.ring.posts) do mods[m] = true end
    for _, list in ipairs({b.rebuild, b.queue}) do
      for i = #list, 1, -1 do if list[i].module and mods[list[i].module] then table.remove(list, i) end end
    end
    b.parts = b.parts + back
    base.trace(b, string.format("cordon: the ring at %.0f recovered (%d pieces, %d parts back)", b.ring.radius, gone, back))
  end
  local n = math.min(RING_MAX, math.max(RING_MIN, math.floor(2 * math.pi * r / SPACING)))
  b.ring = {radius = r, posts = {}}
  local jobs = {}
  for k = 0, n - 1 do
    local a = 2 * math.pi * (k + 0.5) / n
    local p = {b.origin.x + math.cos(a) * r, b.origin.y + math.sin(a) * r}
    if wet(b, p) then
      b.posts_wet = (b.posts_wet or 0) + 1
    else
      local m = {kind = "post", center = p, entities = {}, ring = true}
      table.insert(b.ring.posts, m)
      for _, j in ipairs(post_jobs(b, m, p, a)) do table.insert(jobs, j) end
    end
  end
  -- At the back of the queue (first, they held a camp's generators back: demand past supply in seven scenarios).
  for _, j in ipairs(jobs) do table.insert(b.queue, j) end
  b.rings = (b.rings or 0) + 1
  base.trace(b, string.format("cordon: a ring of %d posts round the camp at %.0f", n, r))
end
base.cordon_ring = cordon.ring

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
        unpave(b, m)
      end
      b.parts = b.parts + back
      b.cordon_recovered = (b.cordon_recovered or 0) + gone
      base.trace(b, string.format("cordon: the arc at %.0f recovered (%d pieces, %d parts back)", old.radius, gone, back))
    end
    c.from = b.perimeter or b.claim_radius
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
    if wet(b, p) then
      b.posts_wet = (b.posts_wet or 0) + 1
    else
      -- (Its place on the arc, k, and its angle: a post left out for water leaves a gap, and the stripe, the contact
      -- walls and its facing, counted by list position, crashed or crossed it; the full regression of 0.3.0, five runs.)
      table.insert(c.posts, {kind = "post", center = p, entities = {}, slot = k, angle = a})
    end
  end
  local by_slot = {}
  for _, m in ipairs(c.posts) do by_slot[m.slot] = m end
  -- First in the queue (behind the camp's growth they waited 4.6 minutes for their drones).
  local jobs = {}
  for _, m in ipairs(c.posts) do
    for _, j in ipairs(post_jobs(b, m, m.center, m.angle)) do table.insert(jobs, j) end
  end
  -- The painted line: a dark stripe post to post (its trim), laid with the posts; it outlives their recovery.
  for k = 1, #c.posts - 1 do
    -- (Neighbours on the arc only: none across a gap left by water.)
    if c.posts[k + 1].slot ~= c.posts[k].slot + 1 then goto next_span end
    local stripe = {}
    for _, q in ipairs(wall_line(c.posts[k].center, c.posts[k + 1].center)) do
      -- Off the posts' pads (it painted over half of one).
      local a, z = c.posts[k].center, c.posts[k + 1].center
      if math.max(math.abs(q[1] - a[1]), math.abs(q[2] - a[2])) > 3 and math.max(math.abs(q[1] - z[1]), math.abs(q[2] - z[2])) > 3 then
        table.insert(stripe, {math.floor(q[1]), math.floor(q[2])})
      end
    end
    table.insert(jobs, {tiles = stripe, floor = "stripe", module = c.posts[k]})
    ::next_span::
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
      local s1, s2 = by_slot[k - 1], by_slot[k]
      if math.abs(mid - a0) <= CONTACT_ARC and s1 and s2 then
        local p1, p2 = s1.center, s2.center
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

-- The line broken (the user, 2026-10-19: hunting the line must be "workable"; Fable's engagement consult: "kill a post
-- and the line retreats"): over half the posts of the arc its claim stands on lost their turrets, and the claim falls
-- back to where it stood before that arc; the arc's pieces still standing are pulled down (half their parts back), its
-- rebuilds and any arc being built beyond are dropped, and the line waits RESTEP before it steps out again. Its belts
-- cut and its strangling follow the claim's edge, so they fall back with it. Once a minute (ops.perimeter asks).
local BROKEN, RESTEP = 0.5, 15 * 3600
local function turrets_up(m)
  for _, e in ipairs(m.entities or {}) do
    if e.valid and shared.kind_of(e.name) == "lp-gun-turret" then return true end
  end
  return false
end
function cordon.check(b)
  local hist = b.cordon_history
  local c = hist and hist[#hist]
  if not c or c.broken or not c.from then return end
  local posts, up = 0, 0
  for _, m in ipairs(c.posts) do
    if not m.gate then
      posts = posts + 1
      if turrets_up(m) then up = up + 1 end
    end
  end
  if posts == 0 or up >= BROKEN * posts then return end
  c.broken = true
  table.remove(hist)
  -- What still stands of it comes down; its rebuilds and the arc being built beyond are dropped.
  local mods, back = {}, 0
  for _, m in ipairs(c.posts) do mods[m] = true end
  for _, m in ipairs(c.walls or {}) do mods[m] = true end
  for _, m in ipairs(c.gates or {}) do mods[m] = true end
  if b.cordon then
    for _, m in ipairs(b.cordon.posts) do mods[m] = true end
    for _, m in ipairs(b.cordon.walls or {}) do mods[m] = true end
    for _, m in ipairs(b.cordon.gates or {}) do mods[m] = true end
    b.cordon = nil
  end
  for m in pairs(mods) do
    for _, e in ipairs(m.entities or {}) do
      if e.valid then
        back = back + math.floor((shared.cost[shared.kind_of(e.name)] or 0) / 2)
        e.surface.create_entity{name = "explosion-hit", position = e.position}
        storage.owner[e.unit_number] = nil
        e.destroy()
      end
    end
    m.recovered = true
    unpave(b, m)
  end
  for _, list in ipairs({b.rebuild, b.queue}) do
    for i = #list, 1, -1 do if list[i].module and mods[list[i].module] then table.remove(list, i) end end
  end
  b.parts = b.parts + back
  local from = b.perimeter or b.claim_radius
  b.perimeter = c.from
  b.restep_at = game.tick + RESTEP
  b.line_broken = (b.line_broken or 0) + 1
  if ops.claim_map then ops.claim_map(b) end
  base.trace(b, string.format("cordon: the arc at %.0f broken (%d of %d posts armed); the claim falls back from %.0f to %.0f",
    c.radius, up, posts, from, c.from))
end
ops.cordon_check = cordon.check

function cordon.stats(b)
  local c = b.cordon
  local built, unbuilt = 0, {}
  for _, m in ipairs(c and c.posts or {}) do
    if m.built then built = built + 1 else unbuilt[#unbuilt + 1] = {m.center[1], m.center[2]} end
  end
  return {arcs = b.cordon_arcs or 0, posts = b.cordon_posts or 0, pending = c and #c.posts or 0, pending_built = built,
    pending_at = unbuilt,
    radius = c and c.radius, perimeter = b.perimeter, bearings = b.cordon_bearings or {}, recovered = b.cordon_recovered or 0,
    contact = b.cordon_contact or 0, gates = b.cordon_gates or 0, ore = b.cordon_ore or 0, severed = b.severed or 0,
    broken = b.line_broken or 0, ring = b.ring and b.ring.radius,
    rings = b.rings or 0}
end

ops.cordon_step = cordon.step
return cordon
