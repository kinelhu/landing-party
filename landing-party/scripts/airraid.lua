-- Air raids (the user, 2026-11-09: "flyers literally bypass walls, mines, flamethrower and water ... it might be worth it
-- to think about a few situations where launching a flying heavy raid is worth it"; then, on the plan: "you have a pretty
-- good grasp on the goal"). A raid's way by air priced as its way on foot is (intel's defence and way in), from what can
-- shoot up only: the guns and lasers whose reach covers the straight line from its camp to the target, the worms too,
-- and what covers the target itself. Walls, mines, water, flamethrowers and artillery weigh nothing to it (data-final-
-- fixes: fluid and artillery turrets ignore the lp-air-unit layer). ops.choose weighs each target both ways, and sends
-- its fliers alone where the air's score beats the ground's by AIR_EDGE and they clear its odds.
local shared = require("__landing-party__.shared")
local threat = require("__landing-party__.scripts.threat")
local know = require("__landing-party__.scripts.know")
local attempt = require("__landing-party__.scripts.attempt")
local veterancy = require("__landing-party__.scripts.veterancy")
local costmap = require("__landing-party__.scripts.costmap")
local firemap = require("__landing-party__.scripts.firemap")

local airraid = {}

-- Who shoots up, by turret type, at what weight (ops.weigh's for guns and lasers; a worm as a gun).
local UP = {["ammo-turret"] = {1, "bullet"}, ["electric-turret"] = {1.5, "laser"}, turret = {1}}
local TYPES = {"ammo-turret", "electric-turret", "turret"}
local AIR_LEN, AIR_STEP = 400, 8   -- the line's last AIR_LEN tiles, looked at every AIR_STEP
-- Nests on the way (the user, 2026-11-27: "Air raids are getting pwned by flying over vanilla spitters"): the biters'
-- and Synthexis's spawners and worms, whatever force the raid is against. A spawner shoots up through its spitters, at its
-- biters' reach (threat.nest_reach), a gun turret's weight a nest (a named prior: its spitters' fire is not read); a worm
-- as a gun. Before, only the target's own forces were read, and an air route crossed nest fields as open sky.
local NEST_UP = 2   -- (1, a gun's: on 777 its way still crossed a nest's edge, cheaper than going wide)
local NEST_MARGIN = 8   -- tiles past its biters' sight its spitters still reach a flier (their chase and their acid's)
local NEST_TYPES = {"unit-spawner", "turret"}
local function biter_forces()
  local out = {}
  for _, f in pairs(game.forces) do if shared.is_biters(f.name) then out[#out + 1] = f end end
  return out
end
airraid.MIN = 3                    -- fliers at the least for an air raid
airraid.EDGE = 1.5                 -- the air's score over the ground's to go by air
-- What fliers are for, taken from the air (bomb drones on what a ground raid cannot reach: artillery, radars, power).
airraid.SNIPE = {["artillery-turret"] = 2, radar = 2, ["electric-pole"] = 1.5, accumulator = 1.5, generator = 1.5,
  ["solar-panel"] = 1.3, reactor = 2, ["burner-generator"] = 1.5}

local fliers
local function is_flier(name)
  fliers = fliers or {}
  local f = fliers[name]
  if f == nil then
    local k = shared.kind_of(name)
    f = false
    for _, n in ipairs(shared.FLIERS) do if n == k then f = true end end
    fliers[name] = f
  end
  return f
end
airraid.is_flier = is_flier

local function weight(e, corp)
  local k = UP[e.type]
  if not k then return 0 end
  local learned = corp and know.price(corp, e.force.name, e.name)
  if learned then return learned / (airraid.PER_TURRET or 3.5) end
  local f = e.force
  return k[1] * (1 + (k[2] and f.get_ammo_damage_modifier(k[2]) or 0)) * (1 + (k[2] and f.get_gun_speed_modifier(k[2]) or 0))
end

-- What shoots up at a flier on its way from `from` to pos and round pos (DEFENCE radius r): each turret once, whose
-- reach covers a point of the line's last AIR_LEN tiles, or that stands within r of the target.
function airraid.weigh(surface, from, pos, forces, corp, r)
  local seen, w = {}, 0
  local function add(e)
    local id = e.unit_number
    if id and not seen[id] and threat.firing(e) then
      seen[id] = true
      w = w + weight(e, corp)
    end
  end
  for _, e in pairs(surface.find_entities_filtered{position = pos, radius = r, force = forces, type = TYPES}) do add(e) end
  local dx, dy = pos[1] - from[1], pos[2] - from[2]
  local len = math.sqrt(dx * dx + dy * dy)
  -- (The nests along it, by their reach: NEST_UP each, once.)
  if len >= 1 and not storage.air_nests_off then
    local nf, bf = threat.nest_far(), biter_forces()
    for d = 0, math.min(len, AIR_LEN), AIR_STEP * 2 do
      local p = {pos[1] - dx / len * d, pos[2] - dy / len * d}
      for _, e in pairs(surface.find_entities_filtered{position = p, radius = nf, force = bf, type = NEST_TYPES}) do
        local id = e.unit_number
        local rr = threat.nest_reach(e) + NEST_MARGIN
        if id and not seen[id] and (e.position.x - p[1]) ^ 2 + (e.position.y - p[2]) ^ 2 <= rr * rr then
          seen[id] = true
          w = w + NEST_UP
        end
      end
    end
  end
  if len >= 1 then
    local far = threat.far()
    for d = 0, math.min(len, AIR_LEN), AIR_STEP do
      local p = {pos[1] - dx / len * d, pos[2] - dy / len * d}
      for _, e in pairs(surface.find_entities_filtered{position = p, radius = far, force = forces, type = TYPES}) do
        local pr = threat.profile(e.name)
        local reach = pr and pr.reach or 0
        if (e.position.x - p[1]) ^ 2 + (e.position.y - p[2]) ^ 2 <= reach * reach then add(e) end
      end
    end
  end
  return w
end

-- Its way by air (the user, 2026-11-10: "allow for air exclusive raids, when there is a flight path that avoids ground
-- defenses"; "the flight paths seem like an obvious use of our cost map"): the cost map searched by air (costmap opts.air:
-- what shoots up alone, its price a gun's weight here) from `from` to pos. What covers the target (within r) is paid
-- whatever the way; the rest only where the cheapest way crosses it, and a detour costs its walk past the straight line's.
-- Returns its weight and the way's turns ({x, y}..., its start and the target left out). From no more than AIR_FAR back
-- (the far leg flown free, as the straight line's past AIR_LEN was).
local AIR_FAR, AIR_PAD, AIR_MARGIN = 600, 64, 4
function airraid.route(surface, from, pos, forces, corp, r)
  if storage.air_straight then return airraid.weigh(surface, from, pos, forces, corp, r), {} end
  local at, w = {}, 0
  for _, e in pairs(surface.find_entities_filtered{position = pos, radius = r, force = forces, type = TYPES}) do
    if e.unit_number and threat.firing(e) then at[e.unit_number] = true; w = w + weight(e, corp) end
  end
  local dx, dy = pos[1] - from[1], pos[2] - from[2]
  local len = math.sqrt(dx * dx + dy * dy)
  if len < costmap.CELL then return w, {} end
  if len > AIR_FAR then
    from = {pos[1] - dx / len * AIR_FAR, pos[2] - dy / len * AIR_FAR}
    len = AIR_FAR
  end
  local mid = {(from[1] + pos[1]) / 2, (from[2] + pos[2]) / 2}
  local radius = len / 2 + AIR_PAD
  local fm = firemap.read(surface, mid, radius * firemap.BOX, forces, function(e)
    return at[e.unit_number] and 0 or weight(e, corp)
  end, TYPES)
  -- (The nests in its box, priced NEST_UP at their reach: its way round them, or over them at their price.)
  if not storage.air_nests_off then
    local box = radius * firemap.BOX + threat.nest_far()
    for _, e in pairs(surface.find_entities_filtered{position = mid, radius = box, force = biter_forces(), type = NEST_TYPES}) do
      local rr = threat.nest_reach(e)
      if rr > 0 then
        local x = {x = e.position.x, y = e.position.y, r = rr + NEST_MARGIN, p = NEST_UP, e = e}
        fm.list[#fm.list + 1] = x
        local key = math.floor(x.x / fm.size) .. "," .. math.floor(x.y / fm.size)
        fm.cells[key] = fm.cells[key] or {}
        table.insert(fm.cells[key], x)
      end
    end
  end
  local map = costmap.read(surface, mid, radius, forces, {air = true, fire = fm, from = from, margin = AIR_MARGIN})
  local c = costmap.cost(map, pos)
  if not c then return airraid.weigh(surface, from, pos, forces, corp, r), {} end
  local way = costmap.straighten(map, costmap.path(map, pos)) or {}
  local turns = {}
  for i = 2, #way - 1 do turns[#turns + 1] = {way[i].x, way[i].y} end
  return w + math.max(0, c - len * costmap.WALK), turns
end

-- The camp's fliers at home (its garrison), and what they are worth in its infantry (a raid's force is counted in
-- infantry: ops.needed).
function airraid.fliers(b)
  local list, worth = {}, 0
  local inf = attempt.worth(shared.variant(b.corp, "lp-infantry"))
  for _, u in ipairs(b.garrison or {}) do
    if u.valid and is_flier(u.name) then
      list[#list + 1] = u
      worth = worth + attempt.worth(u.name) * veterancy.scale(u) / math.max(0.1, inf)
    end
  end
  return list, worth
end

return airraid
