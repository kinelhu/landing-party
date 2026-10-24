-- Numbers shared by the data and control stages: one source for every value both read.
local shared = {}

-- Corporations (docs/campaign.md, docs/corporations.md): each its own force, at war with every other force
-- (biters included) unless a cease-fire says otherwise. A settlement belongs to one.
-- tint: the colour their buildings and units are drawn in (docs/corporations.md); lamp: their lamps' light.
-- tints: a colour per kind where it differs from tint. road, pad: the vanilla tiles their floors are made of
-- (and a tint); trim: the border of its paved yards and pads (its floor livery). icon: the virtual signal that
-- stands for it on map tags and in notices, with its motto. (Logos on the ground were dropped: scaled icons
-- looked pasted on, concrete pixel art merged into blobs; user 2026-10-13.)
-- What kills from the air, as the research ledger names a killer (rd.lua): the corporations' fliers, the player's
-- combat robots. Their losses to these buy each corporation its anti-air.
local shared_fliers = {"lp-harrier", "lp-scavenger", "lp-laser-drone", "destroyer", "defender", "distractor"}
shared.FLIERS = shared_fliers
-- The player's infantry, as the research ledger names a killer: what the corporations' anti-infantry answers.
local shared_infantry = {"lp-trooper", "lp-breacher", "lp-rocket-trooper", "lp-flame-trooper", "character"}
shared.INFANTRY = shared_infantry
shared.CORPS = {
  grubstake = {name = "Grubstake Inc.", force = "lp-grubstake", color = {r = 0.8, g = 0.55, b = 0.2},
    tint = {r = 1, g = 0.72, b = 0.38, a = 1}, lamp = {r = 1, g = 0.75, b = 0.4},
    -- Its depot (a cargo landing pad's art, dark already) washed lighter: the full tint read sad and deflated (the user).
    tints = {["lp-depot"] = {r = 1, g = 0.9, b = 0.78, a = 1}},
    road = {tile = "stone-path", tint = {r = 0.95, g = 0.78, b = 0.5}}, pad = {tile = "brown-refined-concrete"},
    trim = {tile = "refined-hazard-concrete-left"},
    -- Under its machines, and round what matters (the user, 2026-10-21: "flooring variation within clusters").
    apron = {tile = "concrete"}, hazard = {tile = "hazard-concrete-left"},
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
        trigger = {killer = shared_infantry, min = 10}},
      -- Wheels: over the walls (bomb drones, against artillery and mortars), and through them.
      {id = "scavenger", branch = "wheels", era = 2, cost = 1800, unit = {kind = "lp-scavenger", weight = 1},
        trigger = {damage = "explosion", min = 5}},
      {id = "dozer", branch = "wheels", era = 3, requires = "slug", cost = 2500, unit = {kind = "lp-dozer", weight = 1},
        trigger = {walls_met = 2}},
      -- Against fliers (the player's robots, a rival's harriers): flak buggies.
      {id = "flak-buggy", branch = "wheels", era = 1, cost = 900, unit = {kind = "lp-flak-buggy", weight = 2},
        trigger = {killer = shared_fliers, min = 6}},
      -- Against a turret line: the Scorcher, a machine gun and three bursts of flame for walls, turrets and packs.
      {id = "scorcher", branch = "scrap-arms", era = 2, cost = 2000, unit = {kind = "lp-scorcher", weight = 1},
        trigger = {killer = {"gun-turret", "laser-turret", "flamethrower-turret"}, min = 8}},
    },
    -- Its sky is scrap drones, cheap and many (the user, 2026-10-23: "a more scrappy opponent").
    mix = {["lp-infantry"] = 3, ["lp-buggy"] = 4, ["lp-harrier"] = 2}, arch = {pad = "drop"},
    -- Development (docs/campaign.md section 6): the level at which each capability comes; absent, never.
    caps = {["lp-harrier"] = 1, pickets_see = 2, headquarters = 3},
    -- Temper (docs/corporations.md): it never raids the player's guarded ground (player targets with known
    -- defence only), and it strips the player's ore instead.
    -- A pact with the biters (pact): a cease-fire both ways; it never fights bugs and they never fight it.
    -- When it comes (phases.lua): early, on the player's first oil; Kessler-Hayashi late, on the first rocket.
    arrives = "early",
    -- Its mind (the faction AI's personality; docs/reviews/2026-10-23-faction-ai-audit.md): the odds it wants before it
    -- commits (a raid's force against what the defence needs, ops.odds), how hard it discounts a risky target, and how
    -- much it minds what a defence will cost it whatever the odds (loss_aversion: value / (1 + defence)^loss_aversion).
    -- prefer: what each kind of operation is worth to it beside a raid (a thief strips first).
    -- counter: how hard it tilts what it builds toward what answers its killers (army.composition).
    -- max_exposure: the most defence it goes up against (a thief keeps off guarded ground; none for a corporation that
    -- goes anywhere).
    mind = {min_odds = 0.6, caution = 2, loss_aversion = 1.5, prefer = {raid = 1, siege = 0.5, strip = 10}, counter = 0.5,
      max_exposure = 1.0},
    temper = {soft_only = true, strips = true, loots = true, sneaks = true, pact = true, jumps = true, taps = true, skims = true, night = true, prospects = true,
      -- How it answers a provocation (ops.answer), by kind: a loss (its unit, drone or building) or trespass (a turret
      -- covering its camp). The thief never fights fair: a snatch raid only where no turret covers it, else nothing (Fable,
      -- docs/reviews/2026-10-18-answers-consult.md; its pheromone flare on the culprit was retired with the biotech's
      -- arrival, 2026-10-22: biter waves are the biotech's alone).
      answers = {loss = "snatch", trespass = "snatch"}},
    -- Its drills pollute, half again an electric drill's 10 a minute (the user, 2026-10-17). Under the pact the biters'
    -- waves skip its camp and come at the player's polluters near its cloud (spike: a 200-biter wave on two player
    -- drills that drew none alone).
    drill_pollution = 15,
    -- Every flak-th turret it builds is a scrap cannon (dirty flak).
    flak = 2,
    -- Crews build beyond the yards (scripts/crew.lua; the builders consult): a truck.
    crews = "truck"},
  serenity = {name = "Kessler-Hayashi", force = "lp-serenity", color = {r = 0.55, g = 0.8, b = 0.85},
    tint = {r = 0.62, g = 0.8, b = 1, a = 1}, lamp = {r = 0.85, g = 0.95, b = 1},
    -- Two colours (user, 2026-10-13): charcoal walls, turrets, poles, lamps and mines on pale concrete (untinted
    -- they read as vanilla; all slate-teal felt uniform); slate-teal for machines, vehicles and units.
    tints = {["lp-depot"] = {r = 0.88, g = 0.95, b = 1, a = 1}, ["lp-wall"] = {r = 0.32, g = 0.35, b = 0.38, a = 1}, ["lp-turret"] = {r = 0.32, g = 0.35, b = 0.38, a = 1},
      ["lp-pylon"] = {r = 0.32, g = 0.35, b = 0.38, a = 1}, ["lp-lamp"] = {r = 0.32, g = 0.35, b = 0.38, a = 1},
      ["lp-mine"] = {r = 0.32, g = 0.35, b = 0.38, a = 1}},
    -- Its deck: the space platform's plating on the ground (the user, 2026-10-20: "space station flooring ... for
    -- Serenity, giving a real alien look"; Fable's look consult, item 1). Refined concrete without Space Age.
    -- Its roads too: a young camp's floor is its roads (the pads are laid whole only at maturity), and in concrete
    -- they read as any base's (the first screenshots).
    road = {tile = "space-platform-foundation", fallback = "refined-concrete", map_color = {r = 0.3, g = 0.32, b = 0.34}},
    pad = {tile = "space-platform-foundation", fallback = "refined-concrete", map_color = {r = 0.27, g = 0.29, b = 0.31}},
    trim = {tile = "black-refined-concrete"},
    -- Its districts' floor varied (the user, 2026-10-21): refined concrete under its machines, hazard stripes round its
    -- labs, depots and launch pad (layout.lua).
    apron = {tile = "refined-concrete"}, hazard = {tile = "refined-hazard-concrete-left"},
    -- The line's painted stripe (cordon.lua): its own tile, not a floor (shared.FLOORS), so a camp grown out to its
    -- old arcs builds over it.
    stripe = {tile = "black-refined-concrete"},
    icon = "signal-heart", motto = "Please remain behind the line.",
    -- Architecture: walled bastions and picket lines; gates in every opening, a baffle wall behind each so entry
    -- zigzags, corner turrets in walled pillboxes; infantry, tanks and walkers, and from its second level a few laser
    -- drones (the user, 2026-10-23: "give Kessler the actual high tech fliers").
    doctrines = {bastion = 2, picket = 1}, mix = {["lp-infantry"] = 4, ["lp-tank"] = 3, ["lp-walker"] = 1, ["lp-railgunner"] = 2,
      ["lp-laser-drone"] = 1},
    names = {["lp-infantry"] = "lp-line-trooper"},
    -- Its tech tree (scripts/rd.lua): energy weapons, range, discipline.
    tree = {
      {id = "optics", branch = "optics", track = {"laser", "electric"}, levels = 5, cost = 400},
      -- Siege: its mortars dig in (against sallies and the player's artillery).
      {id = "hardened", branch = "siege", era = 2, cost = 1200, ability = true, trigger = {damage = "explosion", min = 5}},
      -- The jammer (scripts/jammer.lua): a mast in the emplacement whose arcs down the player's robots, once a siege's
      -- hits were mended by them.
      {id = "jammer", branch = "siege", era = 2, cost = 1500, ability = true, trigger = {mended = 1}},
      {id = "counter", branch = "siege", era = 3, requires = "hardened", cost = 1000, ability = true,
        trigger = {killer = {"artillery-turret", "artillery-wagon"}, min = 3}},
      {id = "warden", branch = "line", era = 1, cost = 1500, plates = {["lp-infantry"] = "physical"},
        trigger = {damage = "physical", min = 10}},
      -- Against fliers (the player's robots, a rival's harriers): the Skyguard.
      {id = "skyguard", branch = "line", era = 1, cost = 900, unit = {kind = "lp-skyguard", weight = 2},
        trigger = {killer = shared_fliers, min = 6}},
      -- Against massed troopers: reach.
      {id = "lance", branch = "optics", era = 1, cost = 900, unit = {kind = "lp-lance", weight = 2},
        trigger = {killer = shared_infantry, min = 6}},
      -- Against blobs: lightning that arcs from one trooper to the next.
      {id = "shock", branch = "optics", era = 3, requires = "lance", cost = 2500, unit = {kind = "lp-shock", weight = 2},
        trigger = {killer = shared_infantry, min = 12}},
      -- Against the player's tanks: a rail cannon on an armoured hull (was a laser: the Laser tank's twin).
      {id = "aegis", branch = "line", era = 2, requires = "warden", cost = 2000, unit = {kind = "lp-aegis", weight = 1},
        trigger = {killer = {"vehicle", "lp-battle-tank"}, min = 5}},
      -- Against massed troopers, heavier: the Prism, a laser that splits to the targets round the first.
      {id = "prism", branch = "optics", era = 2, requires = "lance", cost = 1800, unit = {kind = "lp-prism", weight = 1},
        trigger = {killer = shared_infantry, min = 9}},
      -- Against a turret line: the Tesla, lightning that jumps along it and drains what it strikes of its charge.
      {id = "tesla", branch = "siege", era = 3, cost = 2500, unit = {kind = "lp-tesla", weight = 1},
        trigger = {killer = {"laser-turret", "gun-turret", "flamethrower-turret"}, min = 10}},
    },
    -- lobed (the user, 2026-10-20: "organic looking bases ... like metastases", "it's all squares everywhere"): its
    -- blocks on lobed plates, one wall round each hub (layout.wall_cluster), no square per block, no pickets.
    arch = {gates = true, baffles = true, pillboxes = true, flamers = true, pad = "ring", lobed = true}, clears_nests = true,
    caps = {siege = 1, ["lp-walker"] = 2, ["lp-laser-drone"] = 2, pickets_see = 2, headquarters = 3},
    -- Temper: it never strikes a player first; once provoked (its buildings or units hurt by that player), it
    -- does not forget.
    -- Answers: trespass only (its ground, its border, a turret by its camp) gets the siege, its masonry, what never
    -- forgives. Being at war, its losses are fair war and go unanswered (ops.request_answer; the user, 2026-10-19), so
    -- the loss entry below is kept for a temper without `hostile`.
    -- Cuts: it surveys the power behind the turrets facing it and strikes the line (scripts/power.lua).
    mind = {min_odds = 0.5, caution = 1, loss_aversion = 1.5, prefer = {raid = 1, siege = 0.5, strip = 0}, counter = 1},
    arrives = "late",
    temper = {provoked_only = true, hostile = true, cuts = true, bills = true, answers = {loss = "raid", trespass = "siege"}},
    -- Clean: its drills emit nothing (Grubstake's pollute).
    drill_pollution = 0,
    -- Crews (scripts/crew.lua): a constructor drone, flying over its walls, building with its beam.
    crews = "drone",
    -- Its moving line is a cordon of posts (scripts/cordon.lua).
    cordon = true,
    -- Its research in the world (the user, 2026-10-21: "base gen moved ahead from the rest of it ... tying it to its
    -- mechanics? And its tech"): a lab per branch of its tree, each in a district of its own (rd.lua). A branch's nodes
    -- are bought, and its units, plates and abilities fielded, only while its lab stands; the icon over a lab says which.
    labs = {optics = "lp-optics-lab", line = "lp-line-lab", siege = "lp-siege-lab"}},
}
-- Floors: "lp-road" and "lp-pad" are the default corporation's tiles; shared.variant names the others'.
shared.FLOORS = {"lp-road", "lp-pad", "lp-trim", "lp-apron", "lp-hazard"}
shared.DEFAULT_CORP = "serenity"

-- The faction's kinds of building and unit. The default corporation's prototypes carry the plain names
-- ("lp-turret"); another's are "lp-<corp>-turret". Logic speaks in kinds; creation and queries translate.
shared.KINDS = {"lp-lander", "lp-generator", "lp-pylon", "lp-drill", "lp-bin", "lp-fabricator", "lp-turret", "lp-wall", "lp-belt",
  "lp-radar", "lp-pacifier", "lp-depot", "lp-launchpad", "lp-lamp", "lp-post-lamp", "lp-mine", "lp-uplink", "lp-mortar", "lp-infantry", "lp-tank",
  "lp-walker", "lp-harrier", "lp-hauler", "lp-buggy", "lp-gate", "lp-flamer", "lp-lance", "lp-slug", "lp-shock",
  "lp-sapper", "lp-aegis", "lp-dozer", "lp-scavenger", "lp-laser-drone", "lp-railgunner", "lp-prism", "lp-tesla", "lp-scorcher", "lp-howitzer", "lp-scrap-cannon",
  "lp-optics-lab", "lp-line-lab", "lp-siege-lab", "lp-parked-howitzer", "lp-howitzer-truck", "lp-skyguard", "lp-flak-buggy"}
-- A howitzer destroyed in the field leaves its camp without one this long (sieges go with mortars only).
shared.HOWITZER_DOWN = 30 * 3600
-- The sign over each research lab: what its branch fields.
shared.LAB_ICON = {["lp-optics-lab"] = "item/laser-turret", ["lp-line-lab"] = "item/heavy-armor",
  ["lp-siege-lab"] = "item/artillery-shell"}
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
-- The threat scanner's signals (player.lua, scripts/scanner.lua; the user, 2026-10-18): the corporations' unit kinds by
-- role, one virtual signal each, and its icon.
shared.SCAN_GROUPS = {
  {signal = "lp-scan-infantry", icon = "__base__/graphics/icons/heavy-armor.png",
    kinds = {"lp-infantry", "lp-lance", "lp-shock", "lp-sapper", "lp-slug"}},
  {signal = "lp-scan-armour", icon = "__base__/graphics/icons/tank.png", kinds = {"lp-tank", "lp-aegis", "lp-dozer", "lp-prism", "lp-tesla", "lp-scorcher"}},
  {signal = "lp-scan-walker", icon = "__base__/graphics/icons/spidertron.png", kinds = {"lp-walker"}},
  {signal = "lp-scan-air", icon = "__base__/graphics/icons/destroyer.png", kinds = {"lp-harrier", "lp-scavenger", "lp-laser-drone"}},
  {signal = "lp-scan-railgunner", icon = "__base__/graphics/icons/rocket-launcher.png", kinds = {"lp-railgunner"}},
  {signal = "lp-scan-hauler", icon = "__base__/graphics/icons/car.png", kinds = {"lp-hauler"}},
  {signal = "lp-scan-buggy", icon = "__base__/graphics/icons/car.png", kinds = {"lp-buggy"}},
}
shared.SCAN_RADIUS = 64
shared.JAM_RADIUS = 50       -- a jammer mast downs robots and blinds threat scanners within this

-- The strength and aggression presets (settings.lua, scripts/tune.lua): a multiplier each.
shared.TUNE = {["very-low"] = 0.5, low = 0.75, normal = 1, high = 1.5, ["very-high"] = 2}
-- The biotech (docs/biotech.md; the third corporation, its first slice): bred biters on their own force, at peace with
-- the wild ones. Not one of CORPS yet (no settlements, ladder or tree): its pens and herds are scripts/herd.lua's.
shared.BIOTECH = {name = "Synthexis", force = "lp-biotech", color = {r = 0.45, g = 0.85, b = 0.2}, icon = "item/biter-egg",
  -- Its breeds' mask layers (units.lua's tints are by kind; these are the biters'): green body, yellow bands.
  tint1 = {r = 0.30, g = 0.85, b = 0.15, a = 1}, tint2 = {r = 0.95, g = 0.90, b = 0.20, a = 1},
  -- Its mind (the faction AI's personality; docs/reviews/2026-10-23-faction-ai-audit.md): a wave is a trial of its
  -- breeds against a defence (farm.target_from). per_turret: a turret's worth in its biters (a wave of n against d:
  -- odds from n / (1 + per_turret d)); per_wall: walls to a turret's worth; fade: how long a place tested stays
  -- tested; reach: how far it looks; far: how fast distance discounts.
  mind = {per_turret = 6, per_wall = 20, fade = 40 * 3600, reach = 1600, far = 800}}
-- The pen's stock that sends a wave, and the most it holds (the pen's unit cap, data and control).
shared.PEN_CAP = 40
shared.WAVE_MIN = 24
-- Its breeds: what each costs, in parts in the arena (weighed against the corporations' units, a rifleman's 10;
-- docs/arena.md) and in biomass in the game (an incubator breeds only while its culture can pay: farm.lua).
-- None of them shoots up (air.lua): its class is many, healing and soft.
shared.BREEDS = {["lp-bred-small-biter"] = {cost = 2}, ["lp-bred-medium-biter"] = {cost = 7},
  ["lp-bred-big-biter"] = {cost = 28}, ["lp-bred-behemoth-biter"] = {cost = 200}, ["lp-bred-medium-spitter"] = {cost = 9},
  ["lp-runt"] = {cost = 2}, ["lp-bred-cinder"] = {cost = 70},
  -- air: it shoots up (air.lua leaves it whole).
  ["lp-bred-spore"] = {cost = 10, air = true},
  -- A spider-unit (Space Age's small stomper): tier 4, over the wall.
  ["lp-bred-stomper"] = {cost = 150}}
-- Biomass (docs/biotech.md "Biomass"): the breeds' costs are paid in it, earned from the pollution its creep drinks (each
-- creep tile absorbs CREEP_ABSORB a second, the engine's own absorption; a unit of pollution drunk is a unit of biomass).
shared.CREEP_ABSORB = 0.0005
-- Whose nests and worms count as nests (Kessler-Hayashi clears them, routes go round them): the wild biters' and
-- Synthexis's (its incubators and worms are nests to everyone else). Not its pollution billing: that is the wild waves'.
shared.NEST_FORCES = {"enemy", "lp-biotech"}

local corp_forces = {}
for _, c in pairs(shared.CORPS) do corp_forces[c.force] = true end
-- A corporation's force, by name. (Was any "lp-" force, which the biotech's force is and must not count as.)
function shared.is_corp(force_name) return force_name ~= nil and corp_forces[force_name] == true end
-- Biters, wild ("enemy") or bred (the biotech's): never a player's force and never a corporation's.
function shared.is_biters(force_name) return force_name == "enemy" or force_name == shared.BIOTECH.force end
-- A player's force: one with players, or the default "player" force (saves where nobody is connected), never a
-- corporation's, the biters' or neutral. One definition (docs/ai.md 2.4: seven copies, two of which disagreed on neutral).
function shared.is_player_force(f)
  local n = f.name
  if shared.is_corp(n) or shared.is_biters(n) or n == "neutral" then return false end
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
  ["lp-post-lamp"] = 1,
  ["lp-belt"] = 1,
  ["lp-mine"] = 2,
  ["lp-mortar"] = 60,            -- a siege emplacement (scripts/ops.lua), carried by a hauler
  ["lp-howitzer"] = 120,         -- a clearance's long gun, where worms outrange the mortar
  ["lp-gate"] = 3,
  ["lp-flamer"] = 8,
  ["lp-gun-turret"] = 15,        -- a cordon post's (cordon.lua), fed by the camp
  ["lp-optics-lab"] = 60,        -- research labs (rd.lua: a branch climbs only while its lab stands)
  ["lp-line-lab"] = 60,
  ["lp-siege-lab"] = 60,
}

-- Units: health and cost in parts. The depot builds them; doctrines weigh the mix. ground_only: its weapons cannot touch
-- air (air.lua); the rest shoot up.
shared.units = {
  -- Grubstake's are its Shotgun hands, at 8 (the RTS pass, 2026-10-21: at 10 a squad of them lost to every rifle squad,
  -- only its front rank in reach at 9; at 6, a trial of the first price pass, they beat nearly everything).
  ["lp-infantry"] = {health = 120, cost = 10, by = {grubstake = 8}},
  ["lp-tank"] = {health = 900, cost = 60, ground_only = true},
  ["lp-walker"] = {health = 1600, cost = 100},
  -- The fliers (units.lua): Grubstake's scrap drone (id lp-harrier) and bomb drone (lp-scavenger), Kessler-Hayashi's
  -- laser drone.
  ["lp-harrier"] = {health = 80, cost = 15},
  ["lp-laser-drone"] = {health = 400, cost = 70},
  ["lp-hauler"] = {health = 1500, cost = 30},
  ["lp-buggy"] = {health = 220, cost = 15},      -- Grubstake's raider and escort (docs/corporations.md)
  -- Tree units (scripts/rd.lua): bought into a corporation's mix.
  ["lp-lance"] = {health = 110, cost = 16},
  ["lp-slug"] = {health = 240, cost = 30},
  ["lp-shock"] = {health = 160, cost = 30, ground_only = true},
  ["lp-railgunner"] = {health = 140, cost = 22, ground_only = true},
  ["lp-sapper"] = {health = 120, cost = 30, ground_only = true},
  ["lp-aegis"] = {health = 1100, cost = 95, ground_only = true},
  ["lp-dozer"] = {health = 1800, cost = 100, ground_only = true},
  ["lp-scavenger"] = {health = 60, cost = 35},
  -- The design sheet's picks (the user, 2026-10-21; tests/lp-shots/data.lua).
  ["lp-prism"] = {health = 700, cost = 100, ground_only = true},
  ["lp-tesla"] = {health = 800, cost = 100, ground_only = true},
  ["lp-scorcher"] = {health = 1100, cost = 70, ground_only = true},
  -- Anti-air, one per side (units.lua): hard on fliers, light on the ground.
  ["lp-skyguard"] = {health = 110, cost = 18},
  ["lp-flak-buggy"] = {health = 220, cost = 20},
}

-- What a corporation pays for a unit kind: its own price where the kind has one (`by = {corp = parts}`), else the kind's.
function shared.unit_cost(corp, kind)
  local u = shared.units[kind]
  if not u then return 10 end
  return (u.by and corp and u.by[corp]) or u.cost
end

-- The player's command bandwidth: what each unit takes, what a relay carries, how many relays count by
-- research level (0: before any; then levels 1-3; level 4 and beyond add RELAYS_PER_EXTRA_LEVEL each).
shared.POPULATION = {["lp-trooper"] = 1, ["lp-breacher"] = 1, ["lp-rocket-trooper"] = 2, ["lp-flame-trooper"] = 2,
  ["lp-battle-tank"] = 6}
-- What a barracks trains: each order item becomes its unit.
shared.ORDERS = {["lp-trooper-order"] = "lp-trooper", ["lp-breacher-order"] = "lp-breacher",
  ["lp-battle-tank-order"] = "lp-battle-tank", ["lp-rocket-trooper-order"] = "lp-rocket-trooper",
  ["lp-flame-trooper-order"] = "lp-flame-trooper"}
shared.RELAY_CAPACITY = 10
shared.RELAYS_BY_LEVEL = {[0] = 2, 4, 8, 15}
shared.RELAYS_PER_EXTRA_LEVEL = 2

-- Faction tier needed to build each unit (the tier rises with parts exported, scripts/faction.lua).
shared.UNLOCK = {["lp-infantry"] = 0, ["lp-tank"] = 0, ["lp-buggy"] = 0, ["lp-harrier"] = 1, ["lp-walker"] = 2, ["lp-laser-drone"] = 2}

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

-- What the corporations' dead leave (the user, 2026-10-21: items spilled on the ground are a hassle to pick up): a wreck,
-- the crash site's wreck chest (data.lua: lp-wreck), neutral, holding it; mined by hand or marked for the robots, it gives
-- it all at once. stacks: {{name =, count =, quality =}...}. What does not fit spills. Gone after WRECK_TICKS (base.lua).
shared.WRECK_TICKS = 60 * 60 * 60
function shared.wreck(surface, pos, stacks)
  local x, y = pos.x or pos[1], pos.y or pos[2]
  local at = surface.find_non_colliding_position("lp-wreck", {x, y}, 6, 0.5) or {x = x, y = y}
  local w = surface.create_entity{name = "lp-wreck", position = at, force = "neutral"}
  local inv = w and w.get_inventory(defines.inventory.chest)
  for _, st in ipairs(stacks) do
    if st.count > 0 then
      local stack = {name = st.name, count = st.count, quality = st.quality}
      local n = inv and inv.insert(stack) or 0
      if n < st.count then
        stack.count = st.count - n
        surface.spill_item_stack{position = at, stack = stack, enable_looted = true}
      end
    end
  end
  if w and inv.is_empty() then w.destroy(); return nil end
  if w then
    storage.wrecks = storage.wrecks or {}
    table.insert(storage.wrecks, {e = w, at = game.tick})
  end
  return w
end

return shared
