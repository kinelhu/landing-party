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

local airraid = {}

-- Who shoots up, by turret type, at what weight (ops.weigh's for guns and lasers; a worm as a gun).
local UP = {["ammo-turret"] = {1, "bullet"}, ["electric-turret"] = {1.5, "laser"}, turret = {1}}
local TYPES = {"ammo-turret", "electric-turret", "turret"}
local AIR_LEN, AIR_STEP = 400, 8   -- the line's last AIR_LEN tiles, looked at every AIR_STEP
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

-- The camp's fliers at home (its garrison), and what they are worth in its infantry (a raid's force is counted in
-- infantry: ops.needed).
function airraid.fliers(b)
  local list, worth = {}, 0
  local inf = attempt.worth(shared.variant(b.corp, "lp-infantry"))
  for _, u in ipairs(b.garrison or {}) do
    if u.valid and is_flier(u.name) then
      list[#list + 1] = u
      worth = worth + attempt.worth(u.name) / math.max(0.1, inf)
    end
  end
  return list, worth
end

return airraid
