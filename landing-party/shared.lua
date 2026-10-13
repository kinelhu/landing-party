-- Numbers shared by the data and control stages: one source for every value both read.
local shared = {}

-- Corporations (docs/campaign.md, docs/corporations.md): each its own force, at war with every other force
-- (biters included) unless a cease-fire says otherwise. A settlement belongs to one.
-- tint: the colour their buildings and units are drawn in (docs/corporations.md); lamp: their lamps' light.
-- road, pad: the vanilla tiles their floors are made of (and a tint); logo: icons layered on a disc, bottom
-- first, each {sprite file, scale, tint} (docs/corporations.md section 2).
shared.CORPS = {
  grubstake = {name = "Grubstake Mineral Recovery", force = "lp-grubstake", color = {r = 0.8, g = 0.55, b = 0.2},
    tint = {r = 1, g = 0.72, b = 0.38, a = 1}, lamp = {r = 1, g = 0.75, b = 0.4},
    road = {tile = "stone-path", tint = {r = 0.95, g = 0.78, b = 0.5}}, pad = {tile = "brown-refined-concrete"},
    logo = {{"__base__/graphics/icons/shapes/shape-circle.png", 2.2, {r = 0.35, g = 0.2, b = 0.1}},
      {"__base__/graphics/icons/iron-ore.png", 1.3, {r = 1, g = 0.8, b = 0.45}},
      {"__base__/graphics/icons/signal/signal-mining.png", 0.9, {r = 1, g = 0.9, b = 0.6}}}},
  serenity = {name = "Serenity Perimeter Group", force = "lp-serenity", color = {r = 0.55, g = 0.8, b = 0.85},
    tint = {r = 0.62, g = 0.8, b = 1, a = 1}, lamp = {r = 0.85, g = 0.95, b = 1},
    road = {tile = "refined-concrete", tint = {r = 0.62, g = 0.8, b = 1}}, pad = {tile = "refined-concrete"},
    logo = {{"__base__/graphics/icons/shapes/shape-circle.png", 2.2, {r = 0.25, g = 0.3, b = 0.35}},
      {"__base__/graphics/icons/energy-shield-equipment.png", 1.4, {r = 0.6, g = 0.95, b = 1}},
      {"__base__/graphics/icons/signal/signal-heart.png", 0.7, {r = 1, g = 1, b = 1}}}},
}
-- Floors: "lp-road" and "lp-pad" are the default corporation's tiles; shared.variant names the others'.
shared.FLOORS = {"lp-road", "lp-pad"}
shared.DEFAULT_CORP = "serenity"

-- The faction's kinds of building and unit. The default corporation's prototypes carry the plain names
-- ("lp-turret"); another's are "lp-<corp>-turret". Logic speaks in kinds; creation and queries translate.
shared.KINDS = {"lp-lander", "lp-generator", "lp-pylon", "lp-drill", "lp-bin", "lp-fabricator", "lp-turret", "lp-wall",
  "lp-radar", "lp-depot", "lp-launchpad", "lp-lamp", "lp-mine", "lp-uplink", "lp-mortar", "lp-infantry", "lp-tank",
  "lp-walker", "lp-harrier", "lp-hauler"}
function shared.variant(corp, kind)
  if corp == nil or corp == shared.DEFAULT_CORP then return kind end
  return "lp-" .. corp .. "-" .. kind:sub(4)
end
function shared.kind_of(name)
  for corp in pairs(shared.CORPS) do
    local pre = "lp-" .. corp .. "-"
    if name:sub(1, #pre) == pre then return "lp-" .. name:sub(#pre + 1) end
  end
  return name
end
-- Logos: "lp-logo" is the default corporation's; shared.variant names the others'.
-- Every corporation's prototype of a kind (or of each kind in a list), for queries over all of them.
function shared.variants(kinds)
  if type(kinds) == "string" then kinds = {kinds} end
  local out = {}
  for _, kind in ipairs(kinds) do
    for corp in pairs(shared.CORPS) do table.insert(out, shared.variant(corp, kind)) end
  end
  table.sort(out)
  return out
end
function shared.is_corp(force_name) return force_name ~= nil and force_name:sub(1, 3) == "lp-" end
-- The corporations' force names, for queries over all of them.
function shared.corp_forces()
  local out = {}
  for _, c in pairs(shared.CORPS) do table.insert(out, c.force) end
  table.sort(out)
  return out
end

-- Nominal power in watts. Data sets the prototypes from these; the planner budgets with them.
shared.power = {
  ["lp-lander"] = -2000000,      -- negative: produces
  ["lp-generator"] = -1000000,
  ["lp-drill"] = 90000,
  ["lp-fabricator"] = 150000,
  ["lp-turret"] = 60000,         -- idle drain plus a share of firing
  ["lp-radar"] = 300000,
}

-- Construction cost in parts.
shared.cost = {
  ["lp-pylon"] = 2,
  ["lp-bin"] = 2,
  ["lp-drill"] = 10,
  ["lp-generator"] = 20,
  ["lp-fabricator"] = 25,
  ["lp-turret"] = 15,
  ["lp-wall"] = 1,
  ["lp-radar"] = 20,
  ["lp-depot"] = 40,
  ["lp-launchpad"] = 150,
  ["lp-lamp"] = 1,
  ["lp-mine"] = 2,
  ["lp-mortar"] = 60,            -- a siege emplacement (scripts/ops.lua), carried by a hauler
}

-- Units: health and cost in parts. The depot builds them; doctrines weigh the mix.
shared.units = {
  ["lp-infantry"] = {health = 120, cost = 10},
  ["lp-tank"] = {health = 900, cost = 60},
  ["lp-walker"] = {health = 1600, cost = 120},
  ["lp-harrier"] = {health = 150, cost = 40},
  ["lp-hauler"] = {health = 1500, cost = 30},
}

-- The player's command bandwidth: what each unit takes, what a relay carries, how many relays count by
-- research level (0: before any; then levels 1-3; level 4 and beyond add RELAYS_PER_EXTRA_LEVEL each).
shared.POPULATION = {["lp-trooper"] = 1, ["lp-breacher"] = 1, ["lp-battle-tank"] = 4}
-- What a barracks trains: each order item becomes its unit.
shared.ORDERS = {["lp-trooper-order"] = "lp-trooper", ["lp-breacher-order"] = "lp-breacher",
  ["lp-battle-tank-order"] = "lp-battle-tank"}
shared.RELAY_CAPACITY = 10
shared.RELAYS_BY_LEVEL = {[0] = 2, 4, 8, 15}
shared.RELAYS_PER_EXTRA_LEVEL = 2

-- Faction tier needed to build each unit (the tier rises with parts exported, scripts/faction.lua).
shared.UNLOCK = {["lp-infantry"] = 0, ["lp-tank"] = 0, ["lp-harrier"] = 1, ["lp-walker"] = 2}

-- Fabrication: FEEDSTOCK_PER_PART feedstock make one part in PART_SECONDS (before crafting speed).
shared.FEEDSTOCK_PER_PART = 5
shared.PART_SECONDS = 2
shared.FABRICATOR_SPEED = 0.75

shared.PYLON_REACH = 24          -- wire reach
shared.PYLON_SUPPLY = 9          -- supply area half-width: one pylon powers a whole 18-tile block

shared.TINT = {r = 0.62, g = 0.8, b = 1, a = 1}

return shared
