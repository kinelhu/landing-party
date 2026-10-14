-- Numbers shared by the data and control stages: one source for every value both read.
local shared = {}

-- Corporations (docs/campaign.md, docs/corporations.md): each its own force, at war with every other force
-- (biters included) unless a cease-fire says otherwise. A settlement belongs to one.
-- tint: the colour their buildings and units are drawn in (docs/corporations.md); lamp: their lamps' light.
-- tints: a colour per kind where it differs from tint. road, pad: the vanilla tiles their floors are made of
-- (and a tint); trim: the border of its paved yards and pads (its floor livery). icon: the virtual signal that
-- stands for it on map tags and in notices, with its motto. (Logos on the ground were dropped: scaled icons
-- looked pasted on, concrete pixel art merged into blobs; user 2026-10-13.)
shared.CORPS = {
  grubstake = {name = "Grubstake Mineral Recovery", force = "lp-grubstake", color = {r = 0.8, g = 0.55, b = 0.2},
    tint = {r = 1, g = 0.72, b = 0.38, a = 1}, lamp = {r = 1, g = 0.75, b = 0.4},
    road = {tile = "stone-path", tint = {r = 0.95, g = 0.78, b = 0.5}}, pad = {tile = "brown-refined-concrete"},
    trim = {tile = "refined-hazard-concrete-left"},
    icon = "signal-mining", motto = "Resources in the right hands.",
    -- Architecture (docs/corporations.md): sprawl, gun turrets fed with ammunition instead of lasers, walls
    -- that are fences (half health); infantry, buggies and harriers, no tanks.
    doctrines = {sprawl = 1}, bases = {["lp-turret"] = "lp-gun-turret"}, props = {["lp-wall"] = {max_health = 225}},
    mix = {["lp-infantry"] = 3, ["lp-buggy"] = 4, ["lp-harrier"] = 1}, arch = {},
    -- Development (docs/campaign.md section 6): the level at which each capability comes; absent, never.
    caps = {["lp-harrier"] = 1, pickets_see = 2, headquarters = 3},
    -- Temper (docs/corporations.md): it never raids the player's guarded ground (player targets with known
    -- defence only), and it strips the player's ore instead.
    temper = {soft_only = true, strips = true}},
  serenity = {name = "Serenity Perimeter Group", force = "lp-serenity", color = {r = 0.55, g = 0.8, b = 0.85},
    tint = {r = 0.62, g = 0.8, b = 1, a = 1}, lamp = {r = 0.85, g = 0.95, b = 1},
    -- Two colours (user, 2026-10-13): charcoal walls, turrets, poles, lamps and mines on pale concrete (untinted
    -- they read as vanilla; all slate-teal felt uniform); slate-teal for machines, vehicles and units.
    tints = {["lp-wall"] = {r = 0.32, g = 0.35, b = 0.38, a = 1}, ["lp-turret"] = {r = 0.32, g = 0.35, b = 0.38, a = 1},
      ["lp-pylon"] = {r = 0.32, g = 0.35, b = 0.38, a = 1}, ["lp-lamp"] = {r = 0.32, g = 0.35, b = 0.38, a = 1},
      ["lp-mine"] = {r = 0.32, g = 0.35, b = 0.38, a = 1}},
    road = {tile = "refined-concrete"}, pad = {tile = "refined-concrete"},
    trim = {tile = "black-refined-concrete"},
    icon = "signal-heart", motto = "Please remain behind the line.",
    -- Architecture: walled bastions and picket lines; gates in every opening, a baffle wall behind each so entry
    -- zigzags, corner turrets in walled pillboxes; infantry, tanks and walkers, no air.
    doctrines = {bastion = 2, picket = 1}, mix = {["lp-infantry"] = 4, ["lp-tank"] = 3, ["lp-walker"] = 1},
    arch = {gates = true, baffles = true, pillboxes = true, flamers = true}, clears_nests = true,
    caps = {siege = 1, ["lp-walker"] = 2, pickets_see = 2, headquarters = 3},
    -- Temper: it never strikes a player first; once provoked (its buildings or units hurt by that player), it
    -- does not forget.
    temper = {provoked_only = true}},
}
-- Floors: "lp-road" and "lp-pad" are the default corporation's tiles; shared.variant names the others'.
shared.FLOORS = {"lp-road", "lp-pad", "lp-trim"}
shared.DEFAULT_CORP = "serenity"

-- The faction's kinds of building and unit. The default corporation's prototypes carry the plain names
-- ("lp-turret"); another's are "lp-<corp>-turret". Logic speaks in kinds; creation and queries translate.
shared.KINDS = {"lp-lander", "lp-generator", "lp-pylon", "lp-drill", "lp-bin", "lp-fabricator", "lp-turret", "lp-wall",
  "lp-radar", "lp-depot", "lp-launchpad", "lp-lamp", "lp-mine", "lp-uplink", "lp-mortar", "lp-infantry", "lp-tank",
  "lp-walker", "lp-harrier", "lp-hauler", "lp-buggy", "lp-gate", "lp-flamer"}
function shared.variant(corp, kind)
  if corp == nil or corp == shared.DEFAULT_CORP then return kind end
  return "lp-" .. corp .. "-" .. kind:sub(4)
end
-- Plates (corporate research, scripts/rd.lua): a plated copy of each unit kind per damage type it answers, more
-- health (PLATE_HEALTH) and that resistance. Named "<variant>-<plate>"; kind_of strips it.
shared.PLATED = {"lp-infantry", "lp-tank", "lp-walker", "lp-harrier", "lp-buggy"}
shared.PLATES = {physical = {type = "physical", percent = 25, decrease = 2}, fire = {type = "fire", percent = 70},
  laser = {type = "laser", percent = 40}}
shared.PLATE_HEALTH = 1.15
function shared.plated(corp, kind, plate)
  local n = shared.variant(corp, kind)
  return plate and (n .. "-" .. plate) or n
end
function shared.kind_of(name)
  for p in pairs(shared.PLATES) do
    local suf = "-" .. p
    if name:sub(1, 3) == "lp-" and name:sub(-#suf) == suf then name = name:sub(1, -#suf - 1); break end
  end
  for corp in pairs(shared.CORPS) do
    local pre = "lp-" .. corp .. "-"
    if name:sub(1, #pre) == pre then return "lp-" .. name:sub(#pre + 1) end
  end
  return name
end
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
-- Development: a corporation's level rises with the parts its settlements export (thresholds), and each level
-- brings capabilities (CORPS caps), never a hidden bonus. Units with no entry in caps come at level 0.
shared.LEVELS = {3000, 8000, 20000, 45000}
function shared.capable(corp, cap, level)
  local c = shared.CORPS[corp]
  local need = c and c.caps and c.caps[cap]
  if need == nil then
    -- A unit kind not listed is there from the start; any other capability not listed, never.
    return cap:sub(1, 3) == "lp-" and (shared.UNLOCK[cap] or 0) == 0 or false
  end
  return (level or 0) >= need
end
-- A corporation's name with its icon, as rich text (notices, map tags).
function shared.corp_label(corp)
  local c = shared.CORPS[corp]
  return string.format("[virtual-signal=%s] %s", c.icon, c.name)
end
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
  ["lp-gate"] = 3,
  ["lp-flamer"] = 8,
}

-- Units: health and cost in parts. The depot builds them; doctrines weigh the mix.
shared.units = {
  ["lp-infantry"] = {health = 120, cost = 10},
  ["lp-tank"] = {health = 900, cost = 60},
  ["lp-walker"] = {health = 1600, cost = 120},
  ["lp-harrier"] = {health = 150, cost = 40},
  ["lp-hauler"] = {health = 1500, cost = 30},
  ["lp-buggy"] = {health = 220, cost = 15},      -- Grubstake's raider and escort (docs/corporations.md)
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
shared.UNLOCK = {["lp-infantry"] = 0, ["lp-tank"] = 0, ["lp-buggy"] = 0, ["lp-harrier"] = 1, ["lp-walker"] = 2}

-- Fabrication: FEEDSTOCK_PER_PART feedstock make one part in PART_SECONDS (before crafting speed).
shared.FEEDSTOCK_PER_PART = 5
shared.PART_SECONDS = 2
shared.FABRICATOR_SPEED = 0.75

shared.PYLON_REACH = 24          -- wire reach
shared.PYLON_SUPPLY = 9          -- supply area half-width: one pylon powers a whole 18-tile block

shared.TINT = {r = 0.62, g = 0.8, b = 1, a = 1}

return shared
