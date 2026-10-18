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
    doctrines = {sprawl = 1}, bases = {["lp-turret"] = "lp-gun-turret", ["lp-infantry"] = "lp-shotgun-hand"},
    props = {["lp-wall"] = {max_health = 225}},
    -- Its own names for kinds (entity-name.<name>): the Shotgun hand.
    names = {["lp-infantry"] = "lp-shotgun-hand"},
    -- Its tech tree (scripts/rd.lua; docs/reviews/2026-10-14-identity-trees-consult.md): never a fair fight.
    tree = {
      {id = "handloads", branch = "scrap-arms", track = {"shotgun-shell", "bullet"}, levels = 5, cost = 400},
      -- Loot: the thief funds itself from its victim, then picks its fights.
      {id = "salvage", branch = "loot", era = 1, cost = 800, ability = true, trigger = {turned_back = 2}},
      {id = "prospector", branch = "loot", era = 2, requires = "salvage", cost = 1000, ability = true,
        trigger = {turned_back = 3}},
      {id = "scrap-plating", branch = "scrap-arms", era = 1, cost = 900,
        plates = {["lp-infantry"] = "physical", ["lp-buggy"] = "physical"}, trigger = {damage = "physical", min = 10}},
      {id = "asbestos", branch = "scrap-arms", era = 1, cost = 900,
        plates = {["lp-infantry"] = "fire", ["lp-buggy"] = "fire"}, trigger = {damage = "fire", min = 10}},
      -- Against the player's vehicles: slugs.
      {id = "slug", branch = "scrap-arms", era = 1, cost = 900, unit = {kind = "lp-slug", weight = 2},
        trigger = {killer = {"vehicle", "lp-battle-tank"}, min = 5}},
      -- Against massed troopers (and the fence in the way): dynamite.
      {id = "sapper", branch = "scrap-arms", era = 2, cost = 1500, unit = {kind = "lp-sapper", weight = 2},
        trigger = {killer = {"lp-trooper", "lp-breacher", "character"}, min = 10}},
      -- Wheels: over the walls (against artillery and mortars), and through them.
      {id = "scavenger", branch = "wheels", era = 2, cost = 1800, unit = {kind = "lp-scavenger", weight = 1},
        trigger = {damage = "explosion", min = 5}},
      {id = "dozer", branch = "wheels", era = 3, requires = "slug", cost = 2500, unit = {kind = "lp-dozer", weight = 1},
        trigger = {walls_met = 2}},
    },
    mix = {["lp-infantry"] = 3, ["lp-buggy"] = 4, ["lp-harrier"] = 1}, arch = {pad = "drop"},
    -- Development (docs/campaign.md section 6): the level at which each capability comes; absent, never.
    caps = {["lp-harrier"] = 1, pickets_see = 2, headquarters = 3},
    -- Temper (docs/corporations.md): it never raids the player's guarded ground (player targets with known
    -- defence only), and it strips the player's ore instead.
    -- A pact with the biters (pact): a cease-fire both ways; it never fights bugs and they never fight it.
    temper = {soft_only = true, strips = true, loots = true, sneaks = true, pact = true, flares = true, jumps = true, taps = true, prospects = true,
      -- How it answers a provocation (ops.answer), by kind: a loss (its unit, drone or building) or trespass (a turret
      -- covering its camp). The thief never fights fair: biters on the culprit, a snatch raid only where no turret covers
      -- it (Fable, docs/reviews/2026-10-18-answers-consult.md).
      answers = {loss = "flare", trespass = "flare"}},
    -- Its drills pollute, half again an electric drill's 10 a minute (the user, 2026-10-17). Under the pact the biters'
    -- waves skip its camp and come at the player's polluters near its cloud (spike: a 200-biter wave on two player
    -- drills that drew none alone).
    drill_pollution = 15,
    -- Every flak-th turret it builds is a scrap cannon (dirty flak).
    flak = 2,
    -- Crews build beyond the yards (scripts/crew.lua; the builders consult): a truck.
    crews = "truck"},
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
    doctrines = {bastion = 2, picket = 1}, mix = {["lp-infantry"] = 4, ["lp-tank"] = 3, ["lp-walker"] = 1, ["lp-railgunner"] = 2},
    names = {["lp-infantry"] = "lp-line-trooper"},
    -- Its tech tree (scripts/rd.lua): energy weapons, range, discipline.
    tree = {
      {id = "optics", branch = "optics", track = {"laser", "electric"}, levels = 5, cost = 400},
      -- Siege: its mortars dig in (against sallies and the player's artillery).
      {id = "hardened", branch = "siege", era = 2, cost = 1200, ability = true, trigger = {damage = "explosion", min = 5}},
      {id = "counter", branch = "siege", era = 3, requires = "hardened", cost = 1000, ability = true,
        trigger = {killer = {"artillery-turret", "artillery-wagon"}, min = 3}},
      {id = "warden", branch = "line", era = 1, cost = 1500, plates = {["lp-infantry"] = "physical"},
        trigger = {damage = "physical", min = 10}},
      -- Against massed troopers: reach.
      {id = "lance", branch = "optics", era = 1, cost = 900, unit = {kind = "lp-lance", weight = 2},
        trigger = {killer = {"lp-trooper", "lp-breacher", "character"}, min = 6}},
      -- Against blobs: lightning that arcs from one trooper to the next.
      {id = "shock", branch = "optics", era = 3, requires = "lance", cost = 2500, unit = {kind = "lp-shock", weight = 2},
        trigger = {killer = {"lp-trooper", "lp-breacher", "character"}, min = 12}},
      -- Against the player's tanks: a laser cannon on an armoured hull.
      {id = "aegis", branch = "line", era = 2, requires = "warden", cost = 2000, unit = {kind = "lp-aegis", weight = 1},
        trigger = {killer = {"vehicle", "lp-battle-tank"}, min = 5}},
    },
    arch = {gates = true, baffles = true, pillboxes = true, flamers = true, pad = "ring"}, clears_nests = true,
    caps = {siege = 1, ["lp-walker"] = 2, pickets_see = 2, headquarters = 3},
    -- Temper: it never strikes a player first; once provoked (its buildings or units hurt by that player), it
    -- does not forget.
    -- Answers: a loss gets a raid in formation; trespass (its ground, its border, a turret by its camp) the siege, its
    -- masonry, what never forgives. A raid it would lose becomes a siege only on a second provocation (a drone shot
    -- down where the player never saw it is not worth mortars).
    temper = {provoked_only = true, answers = {loss = "raid", trespass = "siege"}},
    -- Clean: its drills emit nothing (Grubstake's pollute).
    drill_pollution = 0,
    -- Crews (scripts/crew.lua): a constructor drone, flying over its walls, building with its beam.
    crews = "drone",
    -- Its moving line is a cordon of posts (scripts/cordon.lua).
    cordon = true},
}
-- Floors: "lp-road" and "lp-pad" are the default corporation's tiles; shared.variant names the others'.
shared.FLOORS = {"lp-road", "lp-pad", "lp-trim"}
shared.DEFAULT_CORP = "serenity"

-- The faction's kinds of building and unit. The default corporation's prototypes carry the plain names
-- ("lp-turret"); another's are "lp-<corp>-turret". Logic speaks in kinds; creation and queries translate.
shared.KINDS = {"lp-lander", "lp-generator", "lp-pylon", "lp-drill", "lp-bin", "lp-fabricator", "lp-turret", "lp-wall",
  "lp-radar", "lp-pacifier", "lp-depot", "lp-launchpad", "lp-lamp", "lp-mine", "lp-uplink", "lp-mortar", "lp-infantry", "lp-tank",
  "lp-walker", "lp-harrier", "lp-hauler", "lp-buggy", "lp-gate", "lp-flamer", "lp-lance", "lp-slug", "lp-shock",
  "lp-sapper", "lp-aegis", "lp-dozer", "lp-scavenger", "lp-railgunner", "lp-howitzer", "lp-scrap-cannon"}
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
-- The strength and aggression presets (settings.lua, scripts/tune.lua): a multiplier each.
shared.TUNE = {["very-low"] = 0.5, low = 0.75, normal = 1, high = 1.5, ["very-high"] = 2}
function shared.is_corp(force_name) return force_name ~= nil and force_name:sub(1, 3) == "lp-" end
-- A player's force: one with players, or the default "player" force (saves where nobody is connected), never a
-- corporation's, the biters' or neutral. One definition (docs/ai.md 2.4: seven copies, two of which disagreed on neutral).
function shared.is_player_force(f)
  local n = f.name
  if shared.is_corp(n) or n == "enemy" or n == "neutral" then return false end
  return n == "player" or #f.players > 0
end
function shared.player_forces()
  local out = {}
  for _, f in pairs(game.forces) do if shared.is_player_force(f) then table.insert(out, f) end end
  return out
end
-- The player's force whose building is nearest pos (within 32), for the dev tools and tests that name a spot only.
function shared.owner_at(surface, pos)
  local fs = shared.player_forces()
  if #fs == 0 then return nil end
  local e = surface.find_entities_filtered{position = pos, radius = 32, force = fs, limit = 1}[1]
  return e and e.force.name or fs[1].name
end
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
  ["lp-scrap-cannon"] = 15,      -- Grubstake's flak, every second turret it builds (base.lua)
  ["lp-wall"] = 1,
  ["lp-radar"] = 20,
  ["lp-pacifier"] = 40,
  ["lp-depot"] = 40,
  ["lp-launchpad"] = 150,
  ["lp-lamp"] = 1,
  ["lp-mine"] = 2,
  ["lp-mortar"] = 60,            -- a siege emplacement (scripts/ops.lua), carried by a hauler
  ["lp-howitzer"] = 120,         -- a clearance's long gun, where worms outrange the mortar
  ["lp-gate"] = 3,
  ["lp-flamer"] = 8,
  ["lp-gun-turret"] = 15,        -- a cordon post's (cordon.lua), fed by the camp
}

-- Units: health and cost in parts. The depot builds them; doctrines weigh the mix.
shared.units = {
  ["lp-infantry"] = {health = 120, cost = 10},
  ["lp-tank"] = {health = 900, cost = 60},
  ["lp-walker"] = {health = 1600, cost = 120},
  ["lp-harrier"] = {health = 150, cost = 40},
  ["lp-hauler"] = {health = 1500, cost = 30},
  ["lp-buggy"] = {health = 220, cost = 15},      -- Grubstake's raider and escort (docs/corporations.md)
  -- Tree units (scripts/rd.lua): bought into a corporation's mix.
  ["lp-lance"] = {health = 110, cost = 14},
  ["lp-slug"] = {health = 240, cost = 25},
  ["lp-shock"] = {health = 160, cost = 30},
  ["lp-railgunner"] = {health = 140, cost = 22},
  ["lp-sapper"] = {health = 120, cost = 16},
  ["lp-aegis"] = {health = 1100, cost = 80},
  ["lp-dozer"] = {health = 1800, cost = 90},
  ["lp-scavenger"] = {health = 180, cost = 50},
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

-- Chat notices (the user, 2026-10-17: "nothing is communicated through notices in factorio ... OK for debugging, or as
-- an ultimate resort"): told only when the map setting "lp-chat-notices" is on (or a test's storage.notices), but for
-- KEEP. A corporation's first landing is told by faction.lua whatever the setting.
-- Also kept until the world shows them (docs/reviews/2026-10-17-notices-consult.md): the warnings that are the only fair
-- notice before a loss the player cannot see coming. None left: the perimeter's warning guards none since enclosure no
-- longer provokes (ops.encroached); the rig's dig is 2.5 minutes with a dust line; a prospect plants a lit stake.
local KEEP = {["lp.fallen"] = true}
function shared.notices_on()
  if storage.notices ~= nil then return storage.notices end
  local s = settings.global["lp-chat-notices"]
  return s and s.value or false
end
function shared.notice(target, msg)
  storage.notice_counts = storage.notice_counts or {told = 0, held = 0}
  if (type(msg) == "table" and KEEP[msg[1]]) or shared.notices_on() then
    target.print(msg)
    storage.notice_counts.told = storage.notice_counts.told + 1
  else
    storage.notice_counts.held = storage.notice_counts.held + 1
  end
end
-- A reply to the player's own act (a stake, a breaker, a beacon, a tribute): floating text at the spot, as Factorio says
-- "cannot build here", to each of the force's connected players; in chat too when notices are on.
function shared.reply(force, pos, msg)
  for _, p in pairs(force.connected_players) do
    p.create_local_flying_text{text = msg, position = pos, time_to_live = 300, speed = 0.5}
  end
  if shared.notices_on() then force.print(msg) end
end

return shared
