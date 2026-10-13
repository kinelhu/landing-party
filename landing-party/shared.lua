-- Numbers shared by the data and control stages: one source for every value both read.
local shared = {}

shared.FORCE = "landing-party"

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
