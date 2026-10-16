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

local cordon = {}

local ARC = math.pi / 3           -- either side of the bearing
local SPACING = 60
local HOLD = 0.8
local WALL = 8                    -- wall pieces in a post's front

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
    -- The arc stands: the claim steps out to it.
    b.cordon = nil
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
  for i = #jobs, 1, -1 do table.insert(b.queue, 1, jobs[i]) end
  b.cordon = c
  base.trace(b, string.format("cordon: an arc of %d posts at %.0f, bearing %.0f degrees", n, new, math.deg(a0)))
  return true
end

function cordon.stats(b)
  local c = b.cordon
  local built = 0
  for _, m in ipairs(c and c.posts or {}) do if m.built then built = built + 1 end end
  return {arcs = b.cordon_arcs or 0, posts = b.cordon_posts or 0, pending = c and #c.posts or 0, pending_built = built,
    radius = c and c.radius, perimeter = b.perimeter}
end

ops.cordon_step = cordon.step
return cordon
