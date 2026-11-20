-- Numbers shared by the data and control stages: one source for every value both read.
local shared = {}

-- Corporations (docs/campaign.md, docs/corporations.md): each its own force, at war with every other force
-- (biters included) unless a cease-fire says otherwise. A settlement belongs to one.
-- tint: the colour their buildings and units are drawn in (docs/corporations.md); lamp: their lamps' light.
-- tints: a colour per kind where it differs from tint. road, pad: the vanilla tiles their floors are made of
-- (and a tint); trim: the border of its paved yards and pads (its floor livery). icon: the virtual signal that
-- stands for it on map tags and in notices. motto: no longer shown in game (docs/wip/flavour.md). (Logos on the ground were dropped: scaled icons
-- looked pasted on, concrete pixel art merged into blobs; user 2026-10-13.)
-- What kills from the air, as the research ledger names a killer (rd.lua): the corporations' fliers, the player's
-- combat robots. Their losses to these buy each corporation its anti-air.
local shared_fliers = {"lp-harrier", "lp-scavenger", "lp-laser-drone", "destroyer", "defender", "distractor"}
shared.FLIERS = shared_fliers
-- A flier's long way in legs of AIR_LEG tiles at most: the engine's pathfinder found no path for the lp-air layer from a
-- camp to a site 130 tiles off (cordon: a constructor 16 tiles from its lander, every order of it dropped to wander) while
-- it found both halves, 63 and 62 waypoints (probed with request_path, 0.2.373). Over open ground (scenario airpath,
-- 0.2.377, a scavenger, eight bearings) every way was found to 100 tiles, 7 of 8 at 120, none from 140; but legs of 100
-- broke Kessler-Hayashi's drone crews by its camp (a way round walls and buildings runs past the straight line):
-- clear worms, farm siegepoor and siegestall failed with them, bisected to this alone (0.2.381). 48 holds; the cost,
-- a new path at each leg, Grubstake's air raid in 3 s where 1.5 uncut.
shared.AIR_LEG = 48
function shared.air_legs(from, to)
  local fx, fy = from.x or from[1], from.y or from[2]
  local tx, ty = to.x or to[1], to.y or to[2]
  local d = math.sqrt((tx - fx) ^ 2 + (ty - fy) ^ 2)
  local n = math.max(0, math.ceil(d / shared.AIR_LEG) - 1)
  local out = {}
  for k = 1, n do
    local t = k / (n + 1)
    out[#out + 1] = {fx + (tx - fx) * t, fy + (ty - fy) * t}
  end
  return out
end
-- The player's infantry, as the research ledger names a killer: what the corporations' anti-infantry answers.
local shared_infantry = {"lp-trooper", "lp-breacher", "lp-rocket-trooper", "lp-flame-trooper", "character"}
shared.INFANTRY = shared_infantry
shared.CORPS = {
  grubstake = {name = "Grubstake", force = "lp-grubstake", color = {r = 0.8, g = 0.55, b = 0.2},
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
    doctrines = {sprawl = 1}, bases = {["lp-turret"] = "lp-gun-turret", ["lp-infantry"] = "lp-shotgun-hand", ["lp-flamer"] = "lp-flamer-oil"},
    props = {["lp-wall"] = {max_health = 225}},
    -- Its own names for kinds (entity-name.<name>): the Shotgun hand.
    names = {["lp-infantry"] = "lp-shotgun-hand", ["lp-turret"] = "lp-gun-turret", ["lp-harrier"] = "lp-scrap-copter",
      ["lp-siege-lab"] = "lp-workshop"},
    -- Its tech tree (scripts/rd.lua; docs/reviews/2026-10-14-identity-trees-consult.md): never a fair fight.
    tree = {
      {id = "handloads", branch = "scrap-arms", track = {"shotgun-shell", "bullet", "grenade", "rocket"}, cost = 400},
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
    mix = {["lp-infantry"] = 3, ["lp-buggy"] = 4, ["lp-harrier"] = 2}, arch = {pad = "drop", town = true},
    -- Its research in the world (rd.lua; 0.2.474, the user: "decouple tech budget from the current parts"): one workshop
    -- for all its branches, a lot in its town (layout.lua, grubstake.tiles workshop); every branch stops while none stands.
    labs = {["scrap-arms"] = "lp-siege-lab", loot = "lp-siege-lab", wheels = "lp-siege-lab"},
    -- A buggy round the player's base for soft ground (scripts/prowl.lua, behind debug_tune prowl).
    prowls = true,
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
      loot = 3,   -- a cell's carry-off worth multiplies its score up to 1 + loot (ops choose, with the prowl)
      way_in = true,   -- its raids weigh the turrets on their way in (ops.way_in): a thief goes round a wall
      max_exposure = 1.0,
      -- Where it lands (faction.site): by ore first and away from its rivals; the way to the player matters less.
      site = {ore = 1.5, approach = 0.5, density = 0.3, rival = 1},
      -- A thief does not keep a vendetta: a grudge at most half as much again (Kessler-Hayashi's five times), or each
      -- loss to Kessler-Hayashi's raids sent a punitive raid into a fortress, its defenders' losses a reprisal back,
      -- until Grubstake's camp was gone (rivals, 2026-10-24).
      weights = {grudge_max = 1.5}, reprisals = false},
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
    -- A shield over its lander that catches its foes' artillery shells (scripts/dome.lua).
    dome = true,
    -- From this era of the player's it lands armed: its headquarters' fortress, not a camp, its level at least
    -- armed_level (faction.arrive).
    armed_era = 3, armed_level = 2,
    -- An armed camp's siege calls an orbital strike on the wall (scripts/orbital.lua).
    orbital_strike = true,
    -- What it sees from orbit (siege.lua: a siege target's defence read when it decides, its tier from the shells the
    -- guns there take); Grubstake learns by scouting and raiding.
    orbital_intel = true,
    -- Its sieges' pieces come down in cargo pods on their site once its guards hold it, no truck (siege.lua drop_march).
    orbital_drop = true,
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
    icon = "signal-heart", motto = "A quieter system for everyone.",
    -- Architecture: walled bastions and picket lines; gates in every opening, a baffle wall behind each so entry
    -- zigzags, corner turrets in walled pillboxes; infantry and tanks, and from its second level a few laser
    -- drones (the user, 2026-10-23: "give Kessler the actual high tech fliers"). No walkers until a walker of its own
    -- (the user, 2026-11-03: "Spidertron are such late game units in vanilla that there is a mismatch that's too much").
    doctrines = {bastion = 2, picket = 1}, mix = {["lp-infantry"] = 4, ["lp-tank"] = 3, ["lp-railgunner"] = 2,
      ["lp-laser-drone"] = 1},
    -- Its tech tree (scripts/rd.lua): energy weapons, range, discipline.
    tree = {
      -- (Damage alone, speed = false, 0.2.476: laser damage and laser shooting speed together are the base game's steepest
      -- ladder, x10.6 at its top, and its anti-air and heavy laser troopers beat all six of the player's units there.)
      {id = "optics", branch = "optics", track = {"laser", "electric"}, speed = false, cost = 400},
      -- Siege: its mortars dig in (against sallies and the player's artillery).
      {id = "hardened", branch = "siege", era = 2, cost = 1200, ability = true, trigger = {damage = "explosion", min = 5}},
      -- Railguns: its railgunners' slugs heavier, against biters and their nests, when biters are what kill its units
      -- (the user, 2026-10-25: weaker at baseline, an investment when it needs clearance and biter defence).
      -- +60% a level: weak at baseline (40 to a biter on its feet), 160 at the fifth (units.lua).
      {id = "railguns", branch = "siege", track = {"lp-rail"}, levels = 5, step = 0.6, cost = 600,
        trigger = {killer = {"biter"}, min = 8}},
      -- The jammer (scripts/jammer.lua): a mast in the emplacement whose arcs down the player's robots, once a siege's
      -- hits were mended by them.
      {id = "jammer", branch = "siege", era = 2, cost = 1500, ability = true, trigger = {mended = 1}},
      -- Ordnance (0.2.474, the arms race): its tanks' shells, at the base game's levels (cannon shells gain from its
      -- fifth). Before, no track raised them: a third of its strike force was untouched by any research.
      {id = "ordnance", branch = "line", track = {"cannon-shell"}, cost = 400},
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
    arch = {gates = true, pillboxes = true, flamers = true, pad = "ring", lobed = true}, clears_nests = true,
    landfill = true,
    caps = {siege = 1, ["lp-walker"] = 2, ["lp-laser-drone"] = 2, pickets_see = 2, headquarters = 3},
    -- Temper: it never strikes a player first; once provoked (its buildings or units hurt by that player), it
    -- does not forget.
    -- Answers: trespass only (its ground, its border, a turret by its camp) gets the siege, its masonry, what never
    -- forgives. Being at war, its losses are fair war and go unanswered (ops.request_answer; the user, 2026-10-19), so
    -- the loss entry below is kept for a temper without `hostile`.
    -- Cuts: it surveys the power behind the turrets facing it and strikes the line (scripts/power.lua).
    mind = {min_odds = 0.5, caution = 1, loss_aversion = 1.5, prefer = {raid = 1, siege = 0.5, strip = 0}, counter = 1,
      -- Its raids weigh their way in too: a walled target is then a siege's, not four units' (artillery base, era 3,
      -- 0.2.134: 9 operations for 13, 20 lost for 31, 13 razed for 10).
      way_in = true,
      -- Armed (faction.arrive), the share of what it makes kept for its sieges on a player (base.lua's siege fund; ops
      -- siege_goal its whole). A trait, as min_odds: at 0.3 its sieges on fed nw reached tiers 2 and 3, at none every one
      -- went at tier 1 (2026-11-02).
      siege_save = 0.3,
      -- Armed, its preferences (ops.tick): its siege at a raid's weight (0.5 unarmed; the Kessler-Hayashi consult: its
      -- standing siege is what an armed camp is for).
      armed_prefer = {raid = 1, siege = 1, strip = 0},
      -- Armed, the ground it grows into, round its lander: its landing barrage and sweeps take every spawner there (war.lua;
      -- a prior, as Synthexis's per_turret: no prototype says how far a spawner's waves come). At 200 its camp stood on fed
      -- nw and nwa; spawners by their biters' sight alone, nwa's fell nine minutes after landing (2026-11-02).
      ground = 200,
      -- Where it lands (faction.site): a clear way to the player first; rivals do not move it.
      site = {ore = 1, approach = 1.5, density = 0.5, rival = 0}},
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
-- A lander stands while this share of its counted generators stands, and at least HULL_MIN_GENS (base.lua hull; the
-- manual: "more than half").
shared.HULL_SHARE = 0.5
shared.HULL_MIN_GENS = 2
-- Only the generators within this of its lander count for its hull (base.lua hull), and its lander's dome reaches the
-- farthest of them (dome.lua).
shared.HULL_RADIUS = 80
-- A player's building its line has enclosed is worth this many times as much to its raids and sieges (ops.choose).
shared.LINE_WORTH = 2
-- A landing that comes angry (a lander of its corporation destroyed) brings this many times its escort (faction.lua).
shared.GRUDGE_ESCORT = 2
-- A line post's gun turrets, along its front from its middle, in tiles (cordon.lua; the manual counts them).
shared.POST_GUNS = {-2, 2}
-- A howitzer destroyed in the field leaves its camp without one this long (sieges go with mortars only).
shared.HOWITZER_DOWN = 30 * 3600
-- The sign over each research lab: what its branch fields.
shared.LAB_ICON = {["lp-optics-lab"] = "item/laser-turret", ["lp-line-lab"] = "item/heavy-armor",
  ["lp-siege-lab"] = "item/artillery-shell", ["lp-grubstake-siege-lab"] = "item/shotgun"}
-- A landing's look (descent.lua, scripts/landfx.lua), all drawn: the cargo pod's animation, the suffix of each lander's
-- falling hull ("lp-lander-fall", "lp-grubstake-lander-fall"), its ground shadow, the explosions' animations (copied from
-- the base game's big and massive explosions: their frames, at half a frame a tick, checked in descent.lua) and sound.
shared.LANDFX = {pod = "lp-landfx-pod", fall = "-fall", shadow = "lp-landfx-lander-shadow", blast = "lp-landfx-blast",
  crash = "lp-landfx-crash", sound = "lp-landfx-boom", scorch = "lp-landfx-scorch", scorch_big = "lp-landfx-scorch-big",
  dust = "lp-landfx-dust", frames = {blast = 47, crash = 57, dust = 16}, speed = 0.5}
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
-- Fliers shot down fall (scripts/fall.lua; the user, 2026-11-09: "could we make fliers spin out and fall to the ground
-- instead of disappearing where they stand upon death?"): by the wreck a death leaves, the flier's own still (its sheet's
-- body, glow and rotor at one heading, sprite) spinning down over TICKS with its shadow closing under it, then CRASH where it
-- lands and its wreck there.
shared.FALL = {TICKS = 40, crash = "lp-crash", kinds = {
  ["lp-harrier-wreck"] = {sheet = "grubstake/harrier", rotor = "rotor", sprite = "lp-fall-harrier"},
  ["lp-kh-drone-wreck"] = {sheet = "serenity/drone-scout", rotor = "fans", sprite = "lp-fall-kh-drone"},
  ["lp-laser-drone-wreck"] = {sheet = "serenity/drone-laser", rotor = "fans", sprite = "lp-fall-laser-drone"},
  -- Grubstake's bomb drone shot down: its bomb goes off where it lands (crash), not where it was hit; bursting on its
  -- target (its attack kills it) it does not fall (fall.skip).
  ["lp-scavenger-wreck"] = {sheet = "grubstake/scavenger", rotor = "rotor", sprite = "lp-fall-scavenger", crash = "lp-scavenger-bomb"},
}}
-- Hulls kept apart (scripts/separate.lua; the user, 2026-11-09: "having 2 columns of huge tanks just standing on each
-- other looks terrible"): a unit of ours wider than WIDTH either side, not a flier, nudged off another closer than GAP
-- times their widths, at most STEP a look, every EVERY ticks, onto free ground only. Colliding outright (a layer of our
-- own, 0.2.258) they wedged in crowds: a unit plans no way round another (blockexit, four of five in one block).
-- And a hull turns at TURN of a turn a tick (data-final-fixes.lua), not a unit's 0.025: a unit turns its whole body to
-- shoot (one heading: no turret of its own), and at 0.025 a tank snapped round in a third of a second (the user,
-- 2026-11-09: "all our units rotate completely when firing"; a drawn turret deferred, the slower turn tried first).
shared.HULL = {WIDTH = 0.6, GAP = 0.9, STEP = 0.2, EVERY = 20, TURN = 0.008}
-- The lightning's stun on units (scripts/stun.lua; the user, 2026-11-09: "a stun effect with Tesla weapons ... also
-- affecting units? Would have to not be 100% to be fair"): each electric hit charges its target by one, less its electric
-- resistance; the charge halves every HALF ticks; a hit stuns with chance (charge - 1) / SPAN, at most MAX; stunned for
-- TICKS, it cannot be stunned again for IMMUNE after. Both sides' tesla weapons alike. A hull (a unit wider than HULL_WIDTH)
-- takes HULL of the charge on top: its electric resistance alone left a tank with none stunned on a quarter of its hits.
-- Its look: the sticker's glow, and ARCS arcs of current (arc, a beam that does nothing) jumping between points on the
-- unit every ARC_EVERY ticks while it lasts.
-- A flier (on the lp-air layer) is held FLIER times as long: electric fire, the shock trooper's chain above all, the
-- answer to drones (2026-11-09).
shared.STUN = {HALF = 240, SPAN = 6, MAX = 0.6, TICKS = 60, IMMUNE = 240, HULL = 0.25, HULL_WIDTH = 0.6, FLIER = 2,
  fx = "lp-stun-fx", fx_big = "lp-stun-fx-big", arc = "lp-stun-arc", ARCS = 2, ARC_EVERY = 5}
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
-- (Each signal the icon of a unit of its role, tools/icons/units.py: the user, 2026-11-10, of the units' icons: "Those are
-- going to show up in the threat scanner, no?"); the railgunner the railgun's, its unit wearing the infantry's body.)
local U = "__landing-party__/graphics/icons/units/"
shared.SCAN_GROUPS = {
  {signal = "lp-scan-infantry", icon = U .. "lp-infantry.png",
    kinds = {"lp-infantry", "lp-lance", "lp-shock", "lp-sapper", "lp-slug"}},
  {signal = "lp-scan-armour", icon = U .. "lp-tank.png", kinds = {"lp-tank", "lp-aegis", "lp-dozer", "lp-prism", "lp-tesla", "lp-scorcher"}},
  {signal = "lp-scan-walker", icon = U .. "lp-walker.png", kinds = {"lp-walker"}},
  {signal = "lp-scan-air", icon = U .. "lp-harrier.png", kinds = {"lp-harrier", "lp-scavenger", "lp-laser-drone"}},
  {signal = "lp-scan-railgunner", icon = "__space-age__/graphics/icons/railgun.png", kinds = {"lp-railgunner"}},
  {signal = "lp-scan-hauler", icon = U .. "lp-hauler.png", kinds = {"lp-hauler"}},
  {signal = "lp-scan-buggy", icon = U .. "lp-buggy.png", kinds = {"lp-buggy"}},
}
shared.SCAN_RADIUS = 64
-- What a turret costs to cross before any is learned, in medium biters lost (ops.lua's force needed; threat.prior_of's
-- base): also what killing one earns its killer (veterancy.lua).
shared.PER_TURRET = 3.5
-- The player's orbital strike beacon's reach (scripts/strike.lua) and the defoliant's (scripts/studies.lua): their
-- descriptions take them as __1__ (components.lua, studies.lua), so the text says what the code does.
shared.STRIKE_RADIUS = 60
-- Orbital cannons (orbital_cannon.lua, scripts/cannon.lua; DESIGN.md, decided 2026-11-10): a cannon's store of charges, a
-- charge's cycle in seconds (a recipe's time) and its thruster fuel, a strike's radius, the shells each charge spent drops,
-- and the remote's cooldown in ticks.
-- (REACH: its barrel past the deck's edge, tiles; POWER: its draw while it charges; MUZZLE: its muzzle from its middle. The
-- big cannon, 2026-11-10: 12 by 18, four times the first's cost, SHELLS 10 for 6; the logistics made a load (the user: "How
-- did you end up setting that up for it to be a challenge?"): 4 MW a cannon, a platform's solar field, and FUEL 500 for
-- 200, firing against flying. First numbers, to tune in play.)
-- (0.2.346, the user: "more cannons could increase both levers to avoid insane overkill ... radius could increase up to a
-- point and density no cap", "allow multiple platforms: ... this one fires from a single platform", the shells "made in
-- foundries or EM plants" on the ground, "some logistics above would be good"): a strike fires ONE platform (the ready one
-- with the most charged cannons), every charged cannon on it one charge; its radius R0 * sqrt(cannons) up to R_MAX (its
-- density the same till the cap, then rising, uncapped); COOLDOWN is a platform's; each charge burns FUEL thruster fuel and
-- OXIDIZER thruster oxidizer, the thrusters' own pair (with the basic recipes about 10 asteroid chunks a charge: 4
-- carbonic, 2 metallic, 4 oxide); the shell, cast in a foundry on the ground round an EM plant's fuse, weighs SHELL_KG
-- (four a rocket). Was: every cannon over Nauvis pooled, a radius of 20, 500 fuel, a 40 kg shell made aloft. First numbers.
shared.CANNON = {STORE = 2, CYCLE = 180, FUEL = 1500, OXIDIZER = 1500, R0 = 16, R_MAX = 48, SHELLS = 10, COOLDOWN = 30 * 60,
  SHELL_KG = 250, REACH = 16, POWER = "4MW", MUZZLE = 25}
-- A unit's rank as a scale on what it is worth in a fight (0.2.355; the user, 2026-11-12: "Does the AI take veterancy into
-- account in its decisions? Meaning both its units and the enemy's?"; it read it in two places only, a hole): its quality
-- level l raises its health RANK.health and its damage RANK.damage a level (scenario vetprobe measured the engine's: 30%
-- and about 48%), so (1 + 0.3 l)(1 + 0.48 l), Lanchester's health times damage. 1 for anything not a unit (a turret's
-- quality not measured).
shared.RANK = {health = 0.3, damage = 0.48}
function shared.rank_scale(e)
  if not (e and e.valid and (e.type == "unit" or e.type == "spider-unit") and e.quality) then return 1 end
  local l = e.quality.level or 0
  return (1 + shared.RANK.health * l) * (1 + shared.RANK.damage * l)
end
-- A strike's radius from the cannons it fires.
function shared.cannon_radius(n)
  return math.min(shared.CANNON.R_MAX, shared.CANNON.R0 * math.sqrt(math.max(n, 1)))
end
shared.DEFOLIATE_RADIUS = 6
-- And the player's other devices and weapons, likewise read by their descriptions (__1__, __2__; 2026-11-06: the
-- numbers had been typed in the locale): the claim marker's reach (ops.marked), the pact breaker's minutes
-- (marker.lua), the invoice post's grace before a collection in minutes (ledger.lua), the rail rifle's line (components.lua) and
-- the cluster shell's bomblets.
shared.CLAIM_MARK_RADIUS = 40
shared.BREAKER_MINUTES = 3
shared.INVOICE_GRACE = 10
shared.RAIL_RANGE = 30
shared.CLUSTER_BOMBLETS = 10
shared.JAM_RADIUS = 50       -- a jammer mast downs robots and blinds threat scanners within this

-- The strength and aggression presets (settings.lua, scripts/tune.lua): a multiplier each.
shared.TUNE = {["very-low"] = 0.5, low = 0.75, normal = 1, high = 1.5, ["very-high"] = 2}
-- The research preset's other half (settings.lua lp-<corp>-research, 0.2.475; the user: "factor in the arms race into
-- the difficulty settings"): how many levels past the player's era a corporation's weapons may go (rd.lua's cap). Its
-- pace is the preset's multiplier (shared.TUNE) on its labs' rate, times the difficulty.
shared.RESEARCH_AHEAD = {["very-low"] = -1, low = 0, normal = 1, high = 1, ["very-high"] = 2}
-- The difficulty preset (setting lp-difficulty, the user, 2026-11-08: presets and the levers under them, as vanilla's
-- biters): a multiplier on every faction's strength, aggression and income (tune.lua), its own levers on top.
shared.DIFFICULTY = {easy = 0.5, normal = 1, hard = 1.5, ["very-hard"] = 2}
shared.DIFFICULTY_LEVELS = {"easy", "normal", "hard", "very-hard"}
-- The levers' defaults and ranges (settings.lua makes the settings from them; the code reads the settings):
shared.LANDING_MINUTES = {default = 90, min = 15, max = 600}
-- The director's priors (director.lua; Fable's consult, part two): its budget in landings, at most cap; a spree costs
-- spree_cost, makes the corporation's operations spree_factor times as often for spree_minutes, then a lull of
-- lull_minutes holds every corporation's; no threat while the half hour's losses pass loss_share of the factory's worth;
-- on grace minutes after the opening's arrival. Personalities multiply the fill. All to calibrate.
shared.DIRECTOR = {cap = 4, spree_cost = 1, spree_factor = 2, spree_minutes = 20, lull_minutes = 15, loss_share = 0.02,
  -- Step 4's personalities (decided overnight 2026-11-14, for review): gentle, half the fill, its lulls twice as long,
  -- no focus strike and no drop wave; chaotic, the same fill, its beats weighed evenly and each held a random while
  -- up to chaos_minutes past its cost (RimWorld's Randy: longer gaps, bigger beats when they come).
  -- (Gentle's lulls the others' length since 0.2.388: doubled, it razed less than no director at all, 470 against 609;
  -- the user: gentle between off and steady.)
  -- (Gentle's lulls 1.5 times again since 0.2.394: their truce capped at truce_max, the longer quiet is the director's
  -- alone and no longer holds the camps below off; with the truce capped, gentle's beats came as often as steady's.)
  grace = 30, personality = {steady = 1, gentle = 0.5, chaotic = 1}, lull_scale = {gentle = 1.5},
  weights_of = {gentle = {spree = 0.6, surge = 0.4}, chaotic = {spree = 0.25, surge = 0.25, focus = 0.25, wave = 0.25,
    climax = 0.1}},
  chaos_minutes = 30,
  -- Adaptation: the fill's multiple grows adapt_climb an hour the player goes unhurt, to adapt_max; hurt, back to 1.
  adapt_climb = 0.1, adapt_max = 2,
  -- Step 2 (decided overnight 2026-11-14, for review): a surge (every corporation at war: tempo surge_factor, the cap on
  -- operations at once surge_add more, surge_minutes) and a focus strike (a surge with a focus: targets within
  -- focus_radius of one point focus_weight times as relevant to every camp); a beat drawn at each fill by these weights,
  -- a surge or a focus only with two camps at war or more.
  surge_cost = 2, surge_factor = 2, surge_add = 1, surge_minutes = 15, focus_cost = 3, focus_weight = 4, focus_radius = 64,
  -- (supply back in steady's draw at 0.1, 0.2.393: the one beat the player can win outright, its pod tagged.)
  beat_weights = {spree = 0.5, surge = 0.3, focus = 0.2, wave = 0.15, supply = 0.1, jammer = 0.15, blackout = 0.15, bounty = 0.15, research = 0.1,
    joint = 0.1, contract = 0.1, rotation = 0.1},
  -- The launch jammer (the user, 2026-11-15: "a camp building a massive jammer blocking rocket exports intermittently"):
  -- a Kessler-Hayashi camp at war within jam_radius of the player's rocket silo raises a mast; while it stands the
  -- silos within jam_radius of it are held jam_on seconds in every jam_on + jam_off, for jam_minutes; jam_cost. Drawn
  -- only with such a silo. Named priors.
  jam_radius = 500, jam_on = 30, jam_off = 60, jam_minutes = 20, jam_cost = 2,
  -- The blackout mast: a Grubstake camp at war raises one, and the player's radars within blackout_radius of it are dark
  -- for blackout_minutes (its strike forces then land unseen); drawn only with a radar of the player's in its reach.
  blackout_radius = 300, blackout_minutes = 15, blackout_cost = 2,
  -- The bounty (docs/director.md, off-map beats): the player's building of most value the camps at war know, priced by
  -- headquarters, bounty_weight times as relevant to every camp for bounty_minutes or till it falls; tagged on the map
  -- with its price, bounty_parts an era, paid to the camp that destroys it; a strike force sent at it; a focus strike's
  -- cost (1 until 0.2.416, when it sent nothing).
  bounty_weight = 8, bounty_minutes = 15, bounty_cost = 3, bounty_parts = 150,
  -- Lull salvage (docs/director.md, a lull's reward): salvage_chance over the player's era of the lulls, a rival shuttle
  -- crashed salvage_distance from the player's spawn, its cargo by the era; tagged, an alert on it. None while one lies
  -- uncollected, none unless a player is on the surface in person (the user, 2026-11-15: "rare, especially later game
  -- when the player is generally playing from map view or another planet"; 0.5 a lull until 0.2.413). Named priors.
  salvage_chance = 0.2, salvage_distance = 150,
  -- Its loot box (the user, 2026-11-15: "a piece of gear with chance for quality"): one piece from its era's pool, its
  -- quality rolled by these shares, beside the bulk. Named priors.
  salvage_gear = {
    {"submachine-gun", "heavy-armor", "light-armor", "solar-panel-equipment", "night-vision-equipment"},
    {"modular-armor", "energy-shield-equipment", "exoskeleton-equipment", "personal-roboport-equipment", "battery-equipment",
      "personal-laser-defense-equipment", "speed-module-2", "productivity-module-2", "efficiency-module-2"},
    {"power-armor", "power-armor-mk2", "fission-reactor-equipment", "energy-shield-mk2-equipment", "battery-mk2-equipment",
      "personal-roboport-mk2-equipment", "speed-module-3", "productivity-module-3", "quality-module-3"},
  },
  salvage_quality = {{"normal", 0.5}, {"uncommon", 0.3}, {"rare", 0.14}, {"epic", 0.05}, {"legendary", 0.01}},
  -- Claimed by its corporation (the user, 2026-11-15: "corporations could also target salvage drops? And get a part
  -- infusion ... a self cleaning loop"): uncollected salvage_claim minutes with a guard standing, the wreck is theirs,
  -- salvage_parts an era to their nearest camp, the guards home; unguarded and uncollected salvage_expire, it is gone.
  salvage_claim = 10, salvage_parts = 300, salvage_expire = 60,
  -- The research breakthrough (docs/director.md, off-map beats): a corporation at war buys its next node of research at
  -- once, its fund untouched; research_cost of the budget. Its new units are the tell.
  research_cost = 1,
  -- The rest of the off-map beats (0.2.421, the user, 2026-11-15: "nothing is postponed until after playtest"):
  -- A joint strike (docs/director.md 9e, the director's part of joint operations): two corporations at war each send a
  -- strike force of joint_share of its points at one target, landing together; a focus strike's cost.
  joint_share = 0.6, joint_cost = 3,
  -- An export contract: a corporation's camps hold every operation against the player contract_minutes and export;
  -- each camp the player has not hit in that time is paid contract_parts an era at its end (a camp left alone through a
  -- contract comes out stronger). Tagged at each camp.
  contract_minutes = 20, contract_parts = 400, contract_cost = 1,
  -- A garrison rotation: one camp's garrison, all but pool.GUARD, ships out on its rocket and comes back by pod
  -- rotation_minutes later, as many in its corporation's current mix: a window, tagged at the camp.
  rotation_minutes = 15, rotation_cost = 1,
  -- (At most rotation_max out, a strike force's size: on railbase_end 71 to 194 left and came back by up to 49 pods.)
  rotation_max = 40,
  -- The intercepted transmission (a lull's reward; a forecast only if earned, the user having removed told pacing in
  -- 0.2.405): a salvage wreck carries a data core datacore_chance of the time; emptied, the next strike force's target
  -- is tagged on the map as it is chosen.
  datacore_chance = 0.5,
  -- Strike targets by motive (the user, 2026-11-15, the targets re-inventoried; by worth until 0.2.418, a big pole and
  -- poles' neighbours chosen): retaliation first, the player's gun that killed grudge_kills of the corporation's units
  -- within grudge_minutes; else a kind drawn, the corporation's own (strike_motive) strike_motive_weight times another's,
  -- its densest cluster among the strike_candidates nearest the lead camp. Belts, poles, pipes and walls never.
  -- Power and water (the boilers' pumps) told ahead, target named, and every operation against that player held while
  -- the force is out and power_hold minutes after (the blackout is the strike's, not the next raid's); only with a
  -- player there in person (a custom alert's reach from another surface not probed). Named priors.
  strike_kinds = {
    research = {"lab"},
    power = {"generator", "burner-generator", "reactor", "fusion-reactor", "fusion-generator", "solar-panel", "accumulator"},
    water = {"offshore-pump"},
    export = {"rocket-silo", "cargo-landing-pad"},
    station = {"train-stop"},
    -- (0.2.420, the user, 2026-11-15, "nothing is postponed": roboports (a rebuild blocked, the hub to defend), the
    -- player's army's barracks, oil by name below; the engineer, a strike hunting the player in person.)
    logistics = {"roboport"},
  },
  -- Kinds read by name, not type (a refinery and a chemical plant are assembling machines).
  strike_kind_names = {oil = {"oil-refinery", "chemical-plant"}, army = {"lp-barracks"}},
  strike_kind_order = {"research", "power", "water", "export", "station", "logistics", "oil", "army", "engineer"},
  -- The engineer (RimWorld's manhunters by dropship): its weight in the draw, only with a player there in person, the
  -- force re-aimed at their character every minute. Rare: the likeliest to feel unfair.
  strike_engineer_weight = 0.3,
  -- Retaliation by cluster (0.2.420): a gun's kills summed with those of the player's guns within grudge_cluster of it
  -- (railbase_end's 135 flamers spread their kills and no one gun reached grudge_kills; the belt is the grudge).
  grudge_cluster = 30,
  -- (Synthexis sends no strike force, not one of shared.CORPS: labs Kessler-Hayashi's, beside its silos.)
  strike_motive = {grubstake = {"power", "water"}, serenity = {"export", "research"}},
  strike_motive_weight = 3, strike_candidates = 12, strike_cluster = 24,
  grudge_kills = 20, grudge_minutes = 30,
  -- Its pods within strike_land of its target, where the fewest of the player's turrets reach (RimWorld's drop pods:
  -- the user agreed, 2026-11-15; behind its camp until 0.2.418, the force marched 250 tiles into railbase_end's 135
  -- flamers and broke before its first hit, every time). The player's army, not more turrets, its answer.
  strike_land = 40,
  -- Its units (0.2.421; the user: "unit counters play a big role in balance"): its camp's composition (army.composition:
  -- countering what killed its corporation's units, fliers over weak anti-air), then tilted against what guards its
  -- target, the player's guns and units within strike_guard of it, by the arena's counter table at strike_counter of
  -- its corporation's own counter weight (mind.counter). The raw mix until now: the one army that never adapted.
  strike_guard = 60, strike_counter = 1,
  power_hold = 10,
  -- Step 3 (decided overnight 2026-11-14, for review): a drop wave, wave_size landings of one corporation at once (the
  -- landing queue, each seeing the last), wave_cost; its camps an expedition (not counted against the camp cap, no
  -- reliefs, the landing clock untouched) until expedition_minutes, then the user's settle rule (2026-11-14): settles
  -- with room under the cap; else takes the place of its corporation's weakest camp if it has exported more and the
  -- player has not hurt that camp in fought_minutes; else withdraws. Departures quiet: no fall, no cores.
  wave_cost = 3, wave_size = 3, expedition_minutes = 45, fought_minutes = 30,
  -- Step 4 (overnight, for review): a spree tilts its corporation's choice of operation (ops' prefer) to its kind,
  -- spree_mix, and Grubstake's waits for dusk (darkness dusk, as its skims'); a surge sends surge_reinforce units by pod
  -- to each camp at war first; a supply drop (supply_cost, weighed in the draw) lands a crate of supply_parts
  -- supply_out tiles from its camp toward the player, collected supply_wait minutes on if it still stands.
  spree_mix = {grubstake = {strip = 2, raid = 1.5}, serenity = {siege = 2}}, dusk = 0.25, surge_reinforce = 4,
  supply_cost = 1, supply_parts = 300, supply_out = 40, supply_wait = 3,
  -- Its readings (the user, 2026-11-14, after the calibration and readings of the user's saves): hurt is the last half
  -- hour's losses past hurt_factor times the player's usual half hour (over hurt_hours) and past hurt_floor of the
  -- factory's worth; depth (infinite levels by packs) raises its pace by min(depth_max, 1 + log10(1 + depth /
  -- depth_scale)): on the user's saves b 1.06, nw 1.33, nwaoo 1.77, nwa 2; its first beat first_minutes after it comes on.
  hurt_factor = 3, hurt_hours = 2, hurt_floor = 0.03, depth_scale = 30, depth_max = 2, first_minutes = 15,
  -- Over the camps' judgement (the user, 2026-11-14: "able to start doomed ops ... if we give bonus income"; agreed
  -- past their judgement, not into hopeless fights): its fill at least a spree's cost every beat_minutes (one beat in
  -- 85 minutes in the calibration); during a surge or a focus strike the camps at war take the ladder's desperate odds
  -- bar (ops' desperate); under any tempo a camp that chose a raid it could not field is sent the units it lacks by pod
  -- from headquarters, gap_share of its own garrison cap at most a beat (41 of 62 decisions under the tempo were short of
  -- units; a flat 12 left a raid on the walled player 13 short of its 25).
  -- (beat_minutes 20 since 0.2.388: at 35, one or two beats in a calibration's 85 minutes; the user agreed.)
  beat_minutes = 20, gap_share = 0.5,
  -- Fable's consult part three (2026-11-14; reach, not pace): a spree raises the cap on operations against the player
  -- (ops' budget, which caps a siege's tier too) by spree_add, as a surge does; a lull follows a beat only if the player
  -- lost something in it (lull_if_razed); an armed camp's supply drop goes to its siege fund (siege_tier's purse).
  spree_add = 1, lull_if_razed = true,
  -- Threat points (RimWorld's; the user, 2026-11-14: "It should add pressure depending on its settings"): a spree's or a
  -- surge's strike force from headquarters, by pod to the camps at war before it, points_per_worth units a point of the
  -- player's worth, times the difficulty, the personality and the adaptation, points_max a camp at most (on the user's
  -- saves at steady: start about 11, nwa the cap). Its first beat a spree; supply drops out of steady's draw.
  points_per_worth = 0.02, points_max = 40,
  -- (A point's price, since 0.2.457: point_scale of the lead camp's infantrymen in parts, its units as many as its mix's
  -- average price buys; 0, a unit a point as before. Measured on the director save against a player's army of 50 at
  -- Kessler-Hayashi's landing, DESIGN 2026-11-18.)
  point_scale = 1.5,
  -- A strike force's time in the field before it walks home to its camp (director.strikes), and the most it takes to get
  -- there before what is left is its camp's where it stands (lift_minutes, 3, to its landing point until 0.2.419).
  strike_minutes = 8, home_minutes = 5,
  -- Its way home round the player's guns (0.2.428): a cell within a turret's reach home_gun_cost times as dear, so it
  -- leaves a ring of guns by its gap where there is one, else by the shortest way through. A named prior.
  home_gun_cost = 8,
  -- And not passive under fire (0.2.428): a unit hit on its way home turns on what is hitting it (the nearest of the
  -- player's guns whose reach covers it, else units within answer_reach) for answer_seconds, then walks on; at most once
  -- each answer_gap seconds. Never in a lull's truce. (Distraction by_damage instead fought each gun to its end: a broken
  -- force took a ring of eight guns and razed eight buildings besides, scenario director repelgap.) Named priors.
  answer_seconds = 3, answer_gap = 10, answer_reach = 20,
  -- (Kills by a broken force within break_grace seconds of its break are not counted against it: shells already fired.)
  break_grace = 3,
  -- Its morale (RimWorld's raiders flee when hurt; the user, 2026-11-15, strike forces the player can beat): it breaks
  -- and walks back to be lifted once this share of those landed is lost. A named prior, not measured.
  strike_break = 0.5,
  -- A fun director (Fable's consult, docs/reviews/2026-11-15-fun-director-consult.md; the user: "please do your best to
  -- create a fun director"). Telegraphed: a strike force told warn_minutes before its pods (the orbital cannon's paint
  -- the precedent), a climax's climax_warn; steady and gentle tell each beat as they draw it, forecast_minutes at least
  -- before it comes (chaotic says nothing: Randy). Recovery: a lull after every beat, lull_floor minutes at least, an
  -- earned one lull_minutes times the beat's losses over the player's usual, lull_max at most; hurt a late base can
  -- reach (hurt_floor of worth: 0.05 was 3,750 on nwa, never reached on railbase_end in three hours). A cycle: steady's
  -- every climax_every-th beat the climax, a focus strike costing the cap, its strike force climax_points times, then
  -- lull_max; chaotic draws it at weights_of.chaotic.climax.
  -- warn_edge: a strike force seen by a radar at the edge of its reach is told this share of the warning ahead (0.2.437;
  -- a named prior).
  -- (truce_max: a lull's truce on the camps at most, the rest of it the director's own quiet; hurt_floor 0.03, at 0.01
  -- a campaign's first 17 of 460 worth held it, 0.2.394.)
  truce_max = 15, warn_minutes = 2, warn_edge = 0.25, climax_warn = 5, forecast_minutes = 10, lull_floor = 5, lull_max = 30, climax_every = 4,
  climax_points = 2}
-- A landing matched to what it lands against (the user, 2026-11-14: "Is it an artifact of landing our camps naked on a
-- late base? Should we land with a bigger budget?"): on top of its fixed escort and START_PARTS, by the strongest player
-- force's guns and worth (valuemap.force_worth): escort_per_gun more units (escort_max at most), parts_per_worth more parts
-- (parts_max), and an armed camp fund_per_gun into its siege fund (fund_max: a tier 2 siege 220, tier 3 400). A
-- headquarters' landing apart. (On the user's saves: start 19 guns and 555 worth, +1 unit and +111 parts; nwa 2,774 and
-- 75,156, +30 and +3,000.)
shared.MATCH = {escort_per_gun = 0.1, escort_max = 30, parts_per_worth = 0.2, parts_max = 3000, fund_per_gun = 4, fund_max = 800}
shared.DIRECTOR_PERSONALITIES = {"steady", "gentle", "chaotic", "off"}  -- between a corporation's landings (faction.lua's cadence)
shared.MAX_CAMPS = {default = 3, min = 1, max = 10}           -- a corporation's standing camps, its headquarters counted
shared.ARRIVE_EVO = {default = 0.25, min = 0, max = 0.95}     -- the wild evolution Synthexis comes at (farm.lua)
shared.MAX_CULTURES = {default = 5, min = 1, max = 10}        -- Synthexis's cultures at once, its seeding's (farm.lua)
-- What each corporation's first landing answers (phases.lua): a technology researched, a science pack made, or the first
-- rocket launched. Grubstake's at oil processing comes without its survey party.
shared.ARRIVALS = {
  grubstake = {default = "chemical-science-pack",
    allowed = {"oil-processing", "chemical-science-pack", "production-science-pack", "utility-science-pack"}},
  serenity = {default = "rocket",
    allowed = {"chemical-science-pack", "production-science-pack", "utility-science-pack", "rocket"}}}
-- The biotech (docs/biotech.md; the third corporation, its first slice): bred biters on their own force, at peace with
-- the wild ones. Not one of CORPS yet (no settlements, ladder or tree): its pens and herds are scripts/herd.lua's.
shared.BIOTECH = {name = "Synthexis", force = "lp-biotech", color = {r = 0.45, g = 0.85, b = 0.2}, icon = "item/biter-egg",
  -- Its cells' and clinics' floor (scripts/cell.lua; biotech.lua's tile; 0.2.345, acid-green refined concrete until then).
  floor = "lp-cell-floor",
  -- Its breeds' mask layers (units.lua's tints are by kind; these are the biters'): green body, yellow bands.
  tint1 = {r = 0.30, g = 0.85, b = 0.15, a = 1}, tint2 = {r = 0.95, g = 0.90, b = 0.20, a = 1},
  -- Its mind (the faction AI's personality; docs/reviews/2026-10-23-faction-ai-audit.md): a wave is a trial of its
  -- breeds against a defence (farm.target_from). per_turret: a turret's worth in its biters (a wave of n against d:
  -- odds from n / (1 + per_turret d)); per_wall: walls to a turret's worth; fade: how long a place tested stays
  -- tested; reach: how far it looks; far: how fast distance discounts.
  mind = {per_turret = 6, per_wall = 20, fade = 40 * 3600, reach = 1600, far = 800, learns = true, orders = true, holds = true, havoc = true,
    min_gain = 2, cuts = 0,
    -- Its probe (herd.lua: runts thrown at the face to find its silent guns) or none: it reads each gun's state (threat.firing),
    -- and the probe's runts ran far ahead of its herd, alone, past what they met (the user, 2026-10-28: "the runts seem to
    -- run far in front of the wave, it's weird"). Off.
    probe = false,
    -- Its reading of the way in scaled by what crossing has really cost (know.scale), or not: calibrated, it read a ring of
    -- guns truly (expected against lost 1.45, 0.90, 1.19, from 2.2) and waited more, and razed 1,246 an hour against 1,498
    -- (three timings on a deathworld, 2026-10-27). Synthexis is the bolder: off. Learned and logged either way.
    calibrate = false}}
-- The pen's stock that sends a wave, and the most it holds (the pen's unit cap, data and control).
shared.PEN_CAP = 40
shared.WAVE_MIN = 24
shared.WAVE_MAX = 60   -- the most a culture sends at once (farm.lua), a full wave (herd.lua: what a price is learned from)
-- The largest wave a culture sends (farm.cap_of; a lever, setting lp-biotech-wave-max): at least a wave's least stock.
shared.WAVE_HUGE = {default = 200, min = shared.WAVE_MIN, max = 400}
-- Its breeds: what each costs, in parts in the arena (weighed against the corporations' units, a rifleman's 10;
-- docs/arena.md) and in biomass in the game (an incubator breeds only while its culture can pay: farm.lua).
-- None of them shoots up (air.lua): its class is many, healing and soft.
shared.BREEDS = {["lp-bred-small-biter"] = {cost = 2}, ["lp-bred-medium-biter"] = {cost = 7},
  ["lp-bred-big-biter"] = {cost = 28}, ["lp-bred-behemoth-biter"] = {cost = 200}, ["lp-bred-medium-spitter"] = {cost = 9},
  ["lp-runt"] = {cost = 2}, ["lp-sweeper"] = {cost = 60}, ["lp-bred-cinder"] = {cost = 40}, ["lp-bred-big-burster"] = {cost = 300},
  -- air: it shoots up (air.lua leaves it whole).
  ["lp-bred-spore"] = {cost = 10, air = true},
  -- A spider-unit (Space Age's small stomper): tier 4, over the wall.
  ["lp-bred-stomper"] = {cost = 150}}
-- Biomass (docs/biotech.md "Biomass"): the breeds' costs are paid in it, earned from the pollution it eats. The script eats
-- for it (creep.drink), so each culture's share is known: an incubator as a wild spawner absorbs (PEN_ABSORB a second and
-- PEN_SHARE of its chunk's pollution a second, measured 2026-10-26), a creep tile CREEP_ABSORB a second, and a unit
-- eaten is YIELD of biomass (a wild nest spends 20 on a medium biter's attack, an incubator 7 on its birth: smoke
-- becomes units at the wild's rate, aimed). The engine's own absorption on both is off. Until 0.2.24 the creep tiles
-- alone were counted, at a tenth of this, and the incubators' absorption went to no one: two cultures on deathworld10x
-- at the cloud's edge ate nothing on the count.
shared.CREEP_ABSORB = 0.005
shared.PEN_ABSORB, shared.PEN_SHARE = 20, 0.01
shared.YIELD = 0.35
-- Whose nests and worms count as nests (Kessler-Hayashi clears them, routes go round them): the wild biters' and
-- Synthexis's (its incubators and worms are nests to everyone else). Not its pollution billing: that is the wild waves'.
shared.NEST_FORCES = {"enemy", "lp-biotech"}
-- Why ground was refused for a building (the user, 2026-10-26: cliffs "a pain for every faction"; measured before the
-- corporations blast them): a tally per settlement by reason, read by the visits and the system sims.
-- Cliffs in its way blown up (the user, 2026-10-26: "I think we should do it now"; measured first: cliffs turned away 15
-- to 50% of the ground the corporations considered, 40% of Kessler-Hayashi's on three maps of four): every cliff touching
-- `area`, an explosion where it stood, BLAST_COST parts each, the cliffs round it corrected by the engine.
shared.BLAST_COST = 2
function shared.blast(surface, area, b)
  if storage.blast_off then return 0 end
  local n = 0
  for _, c in pairs(surface.find_entities_filtered{area = area, type = "cliff"}) do
    if c.valid then
      local p = c.position
      surface.create_entity{name = "big-explosion", position = p}
      c.destroy{do_cliff_correction = true}
      n = n + 1
    end
  end
  if n > 0 and b then
    b.parts = b.parts - n * shared.BLAST_COST
    b.blasted = (b.blasted or 0) + n
  end
  return n
end

-- Water under what it builds filled (Kessler-Hayashi: shared.CORPS[corp].landfill; the user, 2026-10-26, water next to
-- cliffs: 7,278 refusals at its deathworld uplink): water tiles among `tiles` ({x, y} lists) become landfill,
-- LANDFILL_COST parts each, unless there are more than LANDFILL_MAX of them (a lake, not a pond: left).
shared.LANDFILL_COST, shared.LANDFILL_MAX = 0.5, 120
function shared.fills(b) return b and (shared.CORPS[b.corp] or {}).landfill and not storage.landfill_off end
-- Whether a cliff is ground it may build on (it blows it up), or in its way (blast_off).
function shared.cliff_clears() return not storage.blast_off end
function shared.landfill(surface, tiles, b)
  if not shared.fills(b) then return 0 end
  local wet = {}
  for _, t in ipairs(tiles) do
    local tile = surface.get_tile(t[1], t[2])
    if tile.valid and tile.collides_with("water_tile") then wet[#wet + 1] = {name = "landfill", position = {t[1], t[2]}} end
    if #wet > shared.LANDFILL_MAX then return 0 end
  end
  if #wet == 0 then return 0 end
  surface.set_tiles(wet, true, false, true, false)
  b.parts = b.parts - math.ceil(#wet * shared.LANDFILL_COST)
  b.landfilled = (b.landfilled or 0) + #wet
  return #wet
end

-- A town's junk (layout.lua: wrecks, crates, tanks, pipes, rocks, parked cars, poles, pumps; neutral): cleared where a
-- building of its goes (a wreck's sprite stood over a turret's footprint, and the nest's gun was never placed).
shared.DECOR_PROPS = {["wooden-chest"] = true, ["storage-tank"] = true, pipe = true, ["big-rock"] = true, car = true,
  ["offshore-pump"] = true, ["small-electric-pole"] = true}
for k = 1, 6 do shared.DECOR_PROPS["crash-site-spaceship-wreck-small-" .. k] = true end
for k = 1, 3 do shared.DECOR_PROPS["crash-site-spaceship-wreck-medium-" .. k] = true end

-- A settlement's own unit sent to its yard (army.yard): site checks pass over it, and construction moves it
-- (construction.make_way). Standing there, they refused the ground the camp grew on (occupy). Only those: passing over
-- every unit of its own changed how a dozen scenarios' camps grew (pool, plate grubstake, crew island).
function shared.own_unit(b, e)
  return b ~= nil and b.yard_dest ~= nil and (e.type == "unit" or e.type == "spider-unit") and e.force.name == b.force
    and b.yard_dest[e.unit_number] ~= nil
end

function shared.refused(b, why)
  if not b then return end
  b.refused = b.refused or {}
  b.refused[why] = (b.refused[why] or 0) + 1
end

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

-- What the player's army fights (scripts/command.lua): the corporations' forces and the biotech's, once it exists (bred
-- biters were outside the army's threat, its beacon's E count and the command tool's attack; the army consult,
-- 2026-11-16). Wild biters are the game's own and the units' own targeting answers them.
function shared.hostile_forces()
  local out = shared.corp_forces()
  if game and game.forces[shared.BIOTECH.force] then table.insert(out, shared.BIOTECH.force) end
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
  -- Costs tuned by the arena's counter matrix (equal spend, 2026-11-09, the user: "cost tuning was the whole point of the
  -- arena"): the hulls had won 61 to 71% of their fights, the lance 30% (docs/arena.md). Aegis 95 to 120, Tesla 100 to
  -- 125, Scorcher 70 to 90, dozer 100 to 120, Prism 100 to 115, tank 60 to 70, lance 16 to 12; then, the second
  -- matrix, the tank and Tesla overshot to 42%, the lance to 69%: tank 65, Tesla 115, Scorcher 100, lance 14.
  ["lp-infantry"] = {health = 120, cost = 11, by = {grubstake = 8}},
  ["lp-tank"] = {health = 900, cost = 65, ground_only = true},
  ["lp-walker"] = {health = 1600, cost = 100},
  -- The fliers (units.lua): Grubstake's scrap drone (id lp-harrier) and bomb drone (lp-scavenger), Kessler-Hayashi's
  -- laser drone.
  ["lp-harrier"] = {health = 80, cost = 15},
  ["lp-laser-drone"] = {health = 400, cost = 70},
  ["lp-hauler"] = {health = 1500, cost = 30},
  ["lp-buggy"] = {health = 220, cost = 15},      -- Grubstake's raider and escort (docs/corporations.md)
  -- Tree units (scripts/rd.lua): bought into a corporation's mix.
  ["lp-lance"] = {health = 110, cost = 14},
  ["lp-slug"] = {health = 240, cost = 30},
  ["lp-shock"] = {health = 160, cost = 30, ground_only = true},
  ["lp-railgunner"] = {health = 140, cost = 22, ground_only = true},
  ["lp-sapper"] = {health = 120, cost = 30, ground_only = true},
  ["lp-aegis"] = {health = 1100, cost = 120, ground_only = true},
  ["lp-dozer"] = {health = 1800, cost = 120, ground_only = true},
  ["lp-scavenger"] = {health = 60, cost = 28},
  -- The design sheet's picks (the user, 2026-10-21; tests/lp-shots/data.lua).
  ["lp-prism"] = {health = 700, cost = 115, ground_only = true},
  ["lp-tesla"] = {health = 800, cost = 115, ground_only = true},
  -- (700, not 1100, since 0.2.261: flaming any foe on a 6 s cooldown it beat Kessler-Hayashi's tanks by far in the
  -- arena; fragile for its fuel, the user: "why not just make it more fragile?". A first guess, tuned in the arena.)
  ["lp-scorcher"] = {health = 700, cost = 100, ground_only = true},
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
  ["lp-battle-tank"] = 8, ["lp-gun-buggy"] = 4}
-- What a barracks trains: each order item becomes its unit.
shared.ORDERS = {["lp-trooper-order"] = "lp-trooper", ["lp-breacher-order"] = "lp-breacher",
  ["lp-battle-tank-order"] = "lp-battle-tank", ["lp-rocket-trooper-order"] = "lp-rocket-trooper",
  ["lp-flame-trooper-order"] = "lp-flame-trooper", ["lp-gun-buggy-order"] = "lp-gun-buggy"}
-- Ammunition tiers (0.2.470; the user, 2026-11-20: "a missed opportunity wrt ammo tiers?", the Fable consult,
-- docs/reviews/2026-11-20-ammo-tiers-consult.md): an order of the same unit issued with a better round (a recipe of its
-- own at the barracks, the user: "I think that is okay yes"). The unit is the base order's; the round is what it fires.
-- A tier recipe is enabled once its base order's and its round's recipes are (command.sync_tiers).
shared.ORDER_TIERS = {
  ["lp-trooper-order-piercing"] = {base = "lp-trooper-order", round = "piercing-rounds-magazine"},
  ["lp-trooper-order-uranium"] = {base = "lp-trooper-order", round = "uranium-rounds-magazine"},
  ["lp-gun-buggy-order-uranium"] = {base = "lp-gun-buggy-order", round = "uranium-rounds-magazine"},
  -- (Stage 2, 0.2.471: the battle tank on uranium shells, twice a plain shell's direct damage in vanilla.)
  ["lp-battle-tank-order-uranium"] = {base = "lp-battle-tank-order", round = "uranium-cannon-shell"},
  -- (Stage 2b, 0.2.472, the user: explosive rounds "as second option but giving higher base damage, not just blast"):
  -- rungs on the same ladder, not a role, so a source still hands out the best it holds.
  ["lp-battle-tank-order-explosive"] = {base = "lp-battle-tank-order", round = "explosive-cannon-shell"},
  ["lp-battle-tank-order-explosive-uranium"] = {base = "lp-battle-tank-order", round = "explosive-uranium-cannon-shell"},
  ["lp-rocket-trooper-order-explosive"] = {base = "lp-rocket-trooper-order", round = "explosive-rocket"},
  -- (0.2.473, the user: "1 and 2 is fun also": the breacher's charges on cluster grenades, vanilla's own grenade upgrade;
  -- a capsule, not ammunition, so the grenade it replaces is named.)
  ["lp-breacher-order-cluster"] = {base = "lp-breacher-order", round = "cluster-grenade", replaces = "grenade"},
}
-- The units whose round's tier raises their damage (bullets, stage 1 of the consult; shells and rockets wait for named
-- priors: vanilla's explosive variants trade direct damage for area, no ratio to read). The bonus is the round's direct
-- damage over the base round's (read from the prototypes), raised to TIER_EXP: a named prior. At 1, vanilla's ratio, the
-- arena (LP_ARENA_TIER, 2026-11-20) found a uranium trooper won 40 of 44 matchups at equal spend (24 on yellow), a
-- uranium gun buggy 40 (23): the counters gone. The power keeps vanilla's order of the rounds and squeezes the gaps. At
-- 0.5 a uranium trooper won 37, at 0.33 33 (a piercing one 27), still losing to big biters, Shock troopers and the 0.95
-- waves; a uranium gun buggy 32. 0.33: a trooper's piercing round about 1.17 times its yellow, uranium about 1.68.
shared.TIERED = {["lp-trooper"] = true, ["lp-gun-buggy"] = true, ["lp-battle-tank"] = true, ["lp-rocket-trooper"] = true,
  ["lp-breacher"] = true}
-- The explosive rounds' rungs (0.2.472): vanilla's explosive variants deal less direct damage than their plain kin (an
-- explosive shell 180 against 1,100), so no ratio can be read and each is a named prior, its factor over the base round
-- before TIER_EXP, placed in vanilla's research order: plain, explosive, uranium (read: 2), explosive uranium. The rocket
-- trooper's only rung, its explosive rocket, is mostly its blast: its direct hit stays under the corporations' infantry's
-- 120 health (110 a rocket, 1.25 to the power 0.33 is 118). At 2 or 3 one rocket killed a rifleman where two had
-- (Serenity's infantry -32 to +86 whatever the rung or the blast, the arena, 2026-11-20); at 1.25, +76 by the blast.
shared.TIER_RAW = {["explosive-cannon-shell"] = 1.5, ["explosive-uranium-cannon-shell"] = 2.5, ["explosive-rocket"] = 1.25,
  ["cluster-grenade"] = 2}
-- A capsule's rung names the capsule it stands on (no ammunition category to read; the breacher's charges, 0.2.473).
shared.TIER_KIN = {["cluster-grenade"] = "grenade"}
-- The rungs whose round bursts round its target (the breacher's charge is a burst already: a blast from each entity it
-- hits would compound).
shared.TIER_BLASTS = {["explosive-cannon-shell"] = true, ["explosive-uranium-cannon-shell"] = true, ["explosive-rocket"] = true}
-- And their blast, so the name tells the truth: from the round's main hit, the enemies within `radius` of its target
-- (the target aside) take `share` of that hit's damage, explosion (command.on_hit). Named priors.
shared.TIER_BLAST = {radius = 2, share = 0.35}
shared.TIER_EXP = 0.33
-- The unit an order item makes, a tier's too.
function shared.order_unit(item)
  local t = shared.ORDER_TIERS[item]
  return shared.ORDERS[item] or (t and shared.ORDERS[t.base])
end
-- A rally beacon's squad sizes (scripts/command.lua): a virtual signal a unit, its count the most of that unit the
-- beacon's squad keeps.
shared.SQUAD_SIGNALS = {}
for _, name in pairs(shared.ORDERS) do shared.SQUAD_SIGNALS[name] = "lp-squad-" .. name:gsub("^lp%-", "") end
-- Kessler-Hayashi's arc flamer's arcs (data.lua): a bolt a second at 30 tiles, two jumps of 6, its damage fire (an
-- electric hit stuns units, stun.lua), its look twice the tesla's, violet-blue, a flash of light a strike.
shared.ARC_FLAMER = {cooldown = 60, range = 30, bolt_ticks = 20, bolt_damage = 40, jump_damage = 20, jumps = 2,
  jump_range = 6, scale = 2.0, tint = {0.55, 0.45, 1.0}, flash_intensity = 0.8, flash_size = 14,
  spark_ticks = 50}   -- (a burning target's sparks: one each spark_ticks, 0.2.350)
shared.RELAY_CAPACITY = 10
-- A powered barracks heals and rearms the player's units within this many tiles, a supply depot rearms them (command.lua;
-- the hover rings, the descriptions).
shared.SUPPLY_RANGE = 30
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
-- (Always told: the army's two stuck-player hints, once each a force, command.lua; a tutorial's, not chatter.)
local KEEP = {["lp.fallen"] = true, ["lp.starved-out"] = true, ["lp.hint-no-beacon"] = true, ["lp.hint-no-relay"] = true,
  -- (A threat the director starts is told as it arrives, RimWorld's way, the user, 2026-11-15: its strike force as it
  -- lands, or seen coming by radar; its drop wave and supply drop. Its own pacing, sprees, surges, lulls and forecasts,
  -- is never told since 0.2.405; 0.2.393 to 0.2.404 read them all out.)
  ["lp.director-wave"] = true, ["lp.director-supply"] = true, ["lp.director-supply-in"] = true,
  ["lp.director-supply-lost"] = true, ["lp.director-strike-seen"] = true, ["lp.director-strike-landed"] = true,
  ["lp.director-strike-target"] = true}
-- Whether a faction may land (its setting lp-<id>-enabled, runtime-global, on by default): off, it never lands again
-- (phases, faction.next_corp, farm's arrival); camps already standing stay. (The user, 2026-11-08: "We do need an on/off
-- switch".)
function shared.enabled(corp)
  local s = settings.global["lp-" .. corp .. "-enabled"]
  return s == nil or s.value ~= false
end
-- A lever's value (settings.lua): its runtime-global setting, or the default given when it is absent.
function shared.setting(name, default)
  local s = settings.global[name]
  if s == nil then return default end
  return s.value
end
function shared.notices_on()
  if storage.notices ~= nil then return storage.notices end
  local s = settings.global["lp-chat-notices"]
  return s and s.value or false
end
-- The event stream (the user, 2026-11-14: "We need to monitor everything that happens meaningfully"): one line of JSON an
-- event to script-output/landing-party/events.jsonl, only while tracing (sims and visits; never a real game's unless
-- /lp-trace): the director's beats and its state a minute, notices, landings, falls, departures, stand-downs, losses.
function shared.event(kind, fields)
  if not storage.trace then return end
  local e = fields or {}
  e.k, e.t = kind, game.tick
  helpers.write_file("landing-party/events.jsonl", helpers.table_to_json(e) .. "\n", true)
end

-- The breakthrough sweep (docs/director.md 9f; the user, 2026-11-14: "another type of operation ... linked to director
-- pressure"): a raid of a corporation the director has committed (a surge or a focus strike, not gentle) that razed its
-- target having lost at most `loss` of its strength, no gun covering it, sweeps on to the player's nearest building
-- within `reach` that no gun covers, `max` times at most. Named priors.
shared.SWEEP = {loss = 0.25, reach = 48, max = 6}
-- A starving camp (scripts/lifeline.lua; the night of 2026-11-16: on nwa seed 1 the biters killed Kessler-Hayashi's
-- first crews at both mining sites and its camp made nothing for 90 minutes; the user: "Ok with your takes"). A camp
-- grace minutes past its landing that made no part for minutes and holds fewer than poor parts is starving: its
-- corporation drops it a crate of parts by pod, out tiles from its lander toward the player, marked; wait minutes on,
-- if the crate stands, its parts reach the camp. Having made nothing since, leave minutes after the drop a camp departs
-- (base.depart); a headquarters never does, its next drop hq_gap minutes after the last if it is starving still.
-- Starving, a camp looks for ore out to search tiles (its usual reach ends at 160 from its network, its scan at 200);
-- none there, its drop's arrival lifts its given-up ground's marks to try it again, Kessler-Hayashi shelling the nests and
-- worms within sweep tiles of that ground from orbit first (as its sweeps do, war.barrage).
shared.LIFELINE = {grace = 20, minutes = 10, poor = 150, parts = 300, out = 16, wait = 3, leave = 20, hq_gap = 30,
  search = 400, sweep = 60}
-- Where crews were killed until a mine was given up (crew.lua), the next mine keeps danger tiles away (site.mining).
shared.MINE_DANGER = 48

-- A director's lull holding `corp` against some force now (storage.truces, "corp|owner" to the tick it ends): its units
-- then walk home without answering fire (ops.walk_home, the leash).
function shared.truce_held(corp)
  for key, till in pairs(storage.truces or {}) do
    if type(till) == "number" and game.tick < till and key:sub(1, #corp + 1) == corp .. "|" then return true end
  end
  return false
end

-- A faction cue (sounds_units.lua's slot cue, round four): its sound at a place, counted by name for tests.
function shared.cue(surface, id, position)
  storage.sound_cues = storage.sound_cues or {}
  storage.sound_cues[id] = (storage.sound_cues[id] or 0) + 1
  if surface and surface.valid then surface.play_sound{path = "lp-cue-" .. id, position = position} end
end

function shared.notice(target, msg)
  storage.notice_counts = storage.notice_counts or {told = 0, held = 0}
  local told = (type(msg) == "table" and KEEP[msg[1]]) or shared.notices_on()
  if told then
    target.print(msg)
    storage.notice_counts.told = storage.notice_counts.told + 1
  else
    storage.notice_counts.held = storage.notice_counts.held + 1
  end
  -- (Its key and arguments as the player would read them, told or held.)
  if storage.trace and type(msg) == "table" then
    local args = {}
    for i = 2, #msg do args[#args + 1] = type(msg[i]) == "table" and tostring(msg[i][1]) or tostring(msg[i]) end
    shared.event("notice", {key = msg[1], args = args, told = told and true or false})
  end
  return told
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

-- How far past its claim an idle unit of a settlement's garrison may stand before it is sent home (army.lua): what a
-- camp's garrison holds, read by the biotech before it razes a camp (herd.lua).
shared.LEASH = 15

-- The berth a corporation's camp and a Synthexis farm keep from each other (the user, 2026-11-12, "Ok on 1 and 2", after
-- the nwa visit at 0.2.355: Kessler-Hayashi landed a minute after a farm 200 tiles from it, its fortress grew into the
-- farm, and the farm fell to it without ever choosing that fight): BERTH_K times the longest reach of the corporations'
-- turrets, their artillery aside, read from the prototypes. Neither grows its guns or its incubators within reach of
-- the other's; they meet where one chooses to go, or where the player draws them.
shared.BERTH_K = 2
local berth
function shared.berth()
  if storage and storage.berth_off then return 0 end
  return shared.berth_reach()
end
-- (Its reading, off or not: the tests' measure.)
function shared.berth_reach()
  if berth then return berth end
  local r = 0
  for name, p in pairs(prototypes.get_entity_filtered{{filter = "type", type = {"electric-turret", "ammo-turret", "fluid-turret"}}}) do
    local ap = name:sub(1, 3) == "lp-" and p.attack_parameters
    if ap and ap.range and ap.range > r then r = ap.range end
  end
  berth = r * shared.BERTH_K
  return berth
end

-- The biotech's big burster (biotech.lua builds it from these; herd.lua sends and sets it off by them): its health, its
-- blast's radius, the blast's damage, and the core's (half the radius) on top.
shared.BIG_BURST = {health = 3000, r = 6, amount = 1500, core = 800}
-- The damage types that land on a crowd (the adaptive tactics consult, 2026-11-05): a flamethrower's stream, sticker and
-- ground fire, a mine's or a shell's blast. What an attacker lost to them, as a share of what it lost, is what it reads to
-- spread out (tactics.area_share). A named prior: the types could be read from the prototypes (a type whose dealers have a
-- radius), not done yet.
shared.AREA_DAMAGE = {fire = true, explosion = true}
-- The burster's (lp-bred-cinder) eruption: `amount` within `r`, `core` more within `core_r` (biotech.lua), its look's
-- reach (scripts/burstfx.lua).
shared.CINDER_BURST = {r = 4, amount = 350, core_r = 2, core = 200}
-- A burst's look (burstlook.lua, scripts/burstfx.lua; the user, 2026-11-05: "the burster is underwhelming graphically
-- compared to its usefulness"), all drawn: its wind-up's glow and hiss, its blast's shockwave puffs (the nuke's), thrown
-- gibs (the biters' guts), acid splashes and the pools they leave (a spitter's acid splash, its last frame), and the
-- sizzle. `windup` is the script trigger a cinder's attack raises. Frame counts checked in burstlook.lua.
shared.BURSTFX = {windup = "lp-burst-windup", wave = "lp-burstfx-wave", gib = "lp-burstfx-gib", splash = "lp-burstfx-splash-",
  pool = "lp-burstfx-pool-", splashes = 4, glow = "lp-burstfx-glow", hiss = "lp-burstfx-hiss", sizzle = "lp-burstfx-sizzle",
  frames = {wave = 32, gib = 12, splash = {26, 29, 29, 24}}}
-- Its sapper (the user, 2026-10-31: "small bursters dedicated to mines (high hp, high range boom that kills mines)"): the
-- sweep's, sent at the mines on its way in ahead of its herd and set off among them; its death a wide blast that kills a
-- land mine (15 of health) and little else. The runts it replaced (15 of health) died to the square lab fort's lasers
-- before they reached a mine, "10 of 10 runts spent" and its rams stunned on the mines they left.
-- The dome taking a hit (data.lua, dome.lua; tools/blender/dome_wave.py): a unit dome `ref` tiles in radius rendered at
-- `px` a tile, `frames` frames played at `speed`, from `dirs` directions of the impact (from the south, counter-clockwise seen
-- from above; mirrored at a negative x_scale, the game flipped them about another point, a radius aside). The dome going up: the ripple's sheet (its last frame `rise_r` tiles in radius) scaled to its dome.
shared.DOME_WAVE = {ref = 16, px = 12, frames = 24, speed = 0.5, dirs = 8, rise_r = 4.5, rise_frames = 16, rise_speed = 0.25}
-- The player's dome (dome.lua): its radius in tiles (Kessler-Hayashi's 30 or more) and what its projector draws (W). Its
-- charge is theirs: HOLD of the guns' fire that reaches it, then down BREAK (dome.lua).
shared.PLAYER_DOME = {radius = 20, draw = 1e6}
shared.SAPPER = {health = 2000, speed = 0.3, r = 7, pop = 60}

return shared
