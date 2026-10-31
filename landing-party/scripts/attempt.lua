-- What an attack did, the same for every attacker (the user, 2026-10-31: "lessons learned from building Synthexis provide
-- insights for balancing the other factions so we don't have to do all this work again from scratch"). Its units' worth
-- in one measure, the defence it met, and whether it got in, read from outside: by where its units stood, not by what
-- the attacker's own code says. Synthexis's waves said they were through from outside the wall for a week (0.2.104);
-- judged here, no attacker's claim stands in for it. oplog.lua fills a record with it for every operation of every
-- faction; the siege lab and its comparison page read those. A leaf but for the perception's gun list (threat.lua).
local threat = require("__landing-party__.scripts.threat")

local attempt = {}

attempt.WALLS = {"wall", "gate"}
attempt.SIG_REACH = 48   -- the guns and walls within this of a place: the defence it met (attempt.sig)
attempt.NEAR = 12        -- an unwalled target reached: a unit this near it

-- A unit's worth in mediums, its health over a medium biter's (the user, 2026-10-30: price and size in health, not heads):
-- a tank's and a truck's as a biter's.
local worth_of = {}
function attempt.worth(name)
  local w = worth_of[name]
  if not w then
    local p, m = prototypes.entity[name], prototypes.entity["lp-bred-medium-biter"]
    w = p and m and p.get_max_health() / m.get_max_health() or 1
    worth_of[name] = w
  end
  return w
end

-- What defends a place: the guns and walls of `forces` within SIG_REACH of it.
function attempt.sig(surface, forces, at)
  local p = {x = at.x or at[1], y = at.y or at[2]}
  return {guns = surface.count_entities_filtered{position = p, radius = attempt.SIG_REACH, type = threat.FIRE, force = forces},
    walls = surface.count_entities_filtered{position = p, radius = attempt.SIG_REACH, type = attempt.WALLS, force = forces}}
end

-- Whether a wall piece not of `own` (the attacker's force) stands on the line from `a` to `b`, a tile at a time.
function attempt.wall_on_line(surface, own, a, b)
  local ax, ay, bx, by = a.x or a[1], a.y or a[2], b.x or b[1], b.y or b[2]
  local n = math.ceil(math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2))
  for i = 1, n - 1 do
    for _, e in ipairs(surface.find_entities_filtered{position = {ax + (bx - ax) * i / n, ay + (by - ay) * i / n}, radius = 0.8,
      type = attempt.WALLS}) do
      if e.force.name ~= own then return true end
    end
  end
  return false
end

-- Whether it is in, seen from outside: its unit nearest its target stands past a wall from where it set out (`from`),
-- or, with no wall between where it set out and its target, within NEAR of the target.
function attempt.inside(surface, own, from, target, positions)
  if not (from and target and positions and #positions > 0) then return false end
  local tx, ty = target.x or target[1], target.y or target[2]
  local best, bd
  for _, p in ipairs(positions) do
    local d = ((p.x or p[1]) - tx) ^ 2 + ((p.y or p[2]) - ty) ^ 2
    if not bd or d < bd then best, bd = p, d end
  end
  if attempt.wall_on_line(surface, own, from, best) then return true end
  return bd <= attempt.NEAR ^ 2 and not attempt.wall_on_line(surface, own, from, target)
end

return attempt
