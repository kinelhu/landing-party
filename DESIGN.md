# Landing Party: design

Living document, organised for design reviews: what is decided, what is built and how it was tested, what
is open. Prototype stage, Factorio 2.0 (2.1 is experimental only). Prefix `lp-`, mod folder `landing-party/`.
Numbers quoted here are the code's at the time of writing; the code is the authority.

**The campaign frame (proposed 2026-10-13): `docs/campaign.md`.** Rival corporations across a world, revealed
mid-game, scaling to the endgame, with biters in a three-way war and a player agent measuring the loop. This
document describes the parts as built; the campaign document describes the game they serve.

## Status at a glance
| Area | State | Tested by (headless scenario) |
|---|---|---|
| Arrival on first launch, repeated landings, sites apart | built | `faction` |
| Opening: signs (radar), survey party (oil), arrival (launch or blue science) | built | `phases` (two) |
| Territory on the map (corporation colour, grows, grey after a fall) | built | `rivals` |
| Development per corporation (capabilities by level), threat budget with a floor | built | `budget`, `develop` |
| Biters: clean, evolution refund for corporations' kills, landings off nests, Serenity clears its nests | built | `evolution`, `nests` |
| Tempers: Serenity strikes only once provoked; Grubstake raids soft targets and strip-mines the player's ore | built | `temper`, `strip` |
| Serenity's line moves: its perimeter grows towards the player, a named warning a step ahead | built | `line` (two) |
| Settlement architecture: hubs, blocks, roads, walls, pickets, doctrines | built | `grow`, variety sheet |
| Economy: drills on real ore, fabricators, parts, power as the graph | built | `grow`, `cut` |
| Rebuild unless occupied | built | `raid`, `occupy` |
| Maturity, launch pad, exports, faction tier | built (first pass) | `faction` |
| Army: roster, depots, garrison, raids | built (first pass) | `assault` (with replay) |
| Operations: intel, raids by value, sizing, staging, abort | built (first pass) | `ops`, `abort` |
| Siege: a hauler carries a mortar beyond the player's turrets; deploy, shell, pack up | built (first pass) | `bombard`, `mortar` |
| Response forces | built (first pass) | `defend` |
| Air units ignoring walls, mines, flamethrowers | built | `air` |
| Headquarters per corporation (fortress and uplink): consolidation, fall, withdrawal, prize | built | `hq`, `uplink` |
| Player army: barracks, troopers, rally beacons (hold, advance, occupy, retreat) | built (first pass) | `army` |
| Beacon as a combinator: own or wired signals, X/Y move the rally point, reach drawn | built | `orders` |
| Beacon report on the circuit network: S squad, E enemy units, T turrets in reach | built | `circuit` |
| Field repair: 2% health a second within 30 tiles of a powered barracks | built | `circuit` |
| Command tool: box-select, move, attack, attack-move, release to beacons | built, tried in game | `control` |
| Player units: trooper, breacher (charges for walls), battle tank (4 bandwidth); barracks picks its recipe | built | `siege` (`LP_MIX`) |
| Fought capture against live defences | in progress: no squad wins yet | `siege`, `duel` |
| Corporations as forces (Grubstake, Serenity): own force, colour, intel; they raid each other | built (first step) | `rivals` |
| Capture of mining outposts by holding | built | `army` |
| The fall: a destroyed lander collapses its settlement (cascade, evacuation, ruins, salvage) | built | `fall` |
| Command bandwidth: unit cap from relays and research, cores from the faction's wreckage | built | `caps` |
| Patrols through settlements | built | `lively` (life animation) |
| Convoys carrying exports to the uplink | built | `convoy` (life animation) |
| Interceptors against player trains | built | `train` |
| Grudge: a lander the player kills provokes its corporation; the next landing comes angry | built | `grudge` |
| Drop escort: a landing brings units and four corner turrets (20 minutes) | built | `grudge`, `rivals` |
| Dev tools: `/lp` forces operations, perimeter steps, landings, grudges | built | `dev` |
| Weighted defence: turrets by kind and research, units at the staging look | built | `weigh` |
| Siege tiers: mortars, resupply convoys, moving up, assault | built | `siegetier` (four) |
| Corporate research: a fund from exports, weapons levels capped by the player's era, plates against what kills it | built | `techup` (two), `plate` |
| Identity: Line troopers (beams) and Shotgun hands (pellets); each corporation's own tree (Serenity: Optics, Warden, Lance, Shock troops, Aegis, Hardened siege, Counter-battery; Grubstake: Hand-loads, Scrap plating, Asbestos, Slug buggy, Dynamite sappers, Scavenger harriers, Dozer, Salvage rights, Prospector's eye); Grubstake loots | built (slices 1-6) | `arms`, `arc`, `plate` (two), `techup` (two), `unitnode` (eight), `ability` (three) |
| Shields, jammers, gates, anti-air turret | open | |
| Depletion and relocation | open | |
| Art beyond tinted vanilla; seen in game | first session 2026-10-13 | `scripts/showcase.sh` save |

## Premise
A rival machine faction answers the player's first rocket launch. It lands, mines the player's own ore and
builds settlements that read as engineering. Its army is the output of its economy, so the war is economy
against economy, fought along supply lines. Biters punish pollution; the Landing Party punishes
predictability.

## Principles
- **Same rules as the player.** Strength comes from what they mine, power and build, never from a timer.
  Scouting their economy tells you how strong they are; striking it changes the next fight.
- **They arrive because of you.** The first launch is heard; later launches bring the next landing sooner.
  A landing starts small at a visible distance. (Space Age has no satellite, and the first launch is when
  the player leaves Nauvis: a strong faction waking then would be a base loss with no answer.)
- **A constant, growing threat, not one base.** A single base is steamrolled by a fast player. Clearing a
  settlement is a win, not the end; the faction keeps landing and its tier keeps rising.
- **A readable base.** Settlements are graphs: nodes joined by power and roads. Cutting an edge darkens what
  lies downstream. The player should be able to read a settlement and find its weak point.
- **Architecture, not Biters+.** Planned like engineering: block grids, roads left open for vehicles,
  walled hard points, open outposts, and at the end a fortress core.
- **Few, visible planner rules.** Every planner bug reads as a stupid enemy. The planner applies a short
  list of priorities and logs which one acted. Layouts are hand-made templates, never free-form.
- **Killing is cheap, holding is hard.** Artillery and nukes will always kill a node. A destroyed node is
  rebuilt unless the player's forces occupy the ground.
- **Ore is contested, not stripped.** They sit on real patches and skim them; the player cannot use a patch
  while they hold it. What they take is justified: mature settlements export it off-world.
- **Orders through entities** for the player's future army (rally beacons with circuit stance), the
  selection tool as override.
- **Art is tinted vanilla** (cold blue-white) until the mechanics are proven.

- **A corporation at war with the player destroys something** (the user, 2026-10-14: "even if they don't punch
  through, they should at least destroy some buildings, or else it makes no sense"). A megabase stays impregnable to
  frontal raids (else it is tower defence again), but a provoked corporation, and Grubstake unprovoked, must take
  player buildings regularly, through what a megabase cares about: ore it will need, exposed rails and lines,
  remote outposts, long-range artillery. Measured on real saves (`scripts/visit.sh`).

## The faction over a game
Built in `scripts/faction.lua`.
- **Landings.** The first answers the first rocket launch on a surface, 350 tiles from the silo. Then one
  every 90 minutes; each later launch brings the next one 15 minutes sooner; at most 4 settlements stand at
  once. A landing keeps 200 tiles from every standing lander, turns its search direction with the landing
  count, and tries rings at 350, 470 and 590 tiles. A site is the richest chunk of ore within 120 tiles of
  the ring, the lander set a third of the way back towards the ring.
- **Doctrine per settlement**, drawn from its seed: bastion, sprawl or picket (see Architecture).
- **Tier.** Parts exported by mature settlements, counted faction-wide, raise the tier at 3,000, 8,000,
  20,000 and 45,000 parts. Each tier adds 15% damage to the faction's weapons and 5 garrison places per
  depot, and unlocks units: harriers at tier 1, walkers at tier 2.
- **The uplink.** The third landing is different: the uplink, under the fortress doctrine. It lands with
  3,000 extra parts and builds its fortress at once (six entities per build step for the fortress's own
  jobs; one at a time, its fortress of about 650 entities took 16 minutes). Destroying the uplink (a radar
  dish at twice the size, 6,000 health) stops all further landings and freezes the tier; the settlements
  already down remain, and so does the uplink's own settlement around its lander. Taking it is optional.
  Defaults chosen without the user, to review: the third landing; "upper hand", not full neutralisation.
- **The fortress.** Three hub cells by three (62 tiles) as one block: three concentric wall rings, each
  opened on a different side (north, east, south) so there is no straight path in; a belt of turrets two
  tiles inside each ring, every six tiles (52 turrets, 528 walls); six generators between the outer rings;
  16 pylons; the lander and the uplink in the inner yard. The rest of the settlement grows around it as a
  fortress-doctrine settlement (everything walled, turreted outposts, two pickets a hub, an army mix rich in
  walkers).

## A settlement's life
1. **Camp.** The lander (crash-site spaceship, its own power), a pad, the first drills and fabricators.
   Nothing walled yet. The window for a cheap early strike.
2. **Settlement.** Hubs grow block by block; walls come once the economy runs (fortify rule); pickets face
   the threat; a depot opens once a hub has three blocks and starts a garrison.
3. **Mature.** At the doctrine's size (bastion 10 blocks, sprawl and picket 8) or after 12 plans in a row
   where growth wanted ore and found none. It stops claiming new ore (mining only replaces lost income),
   opens a launch block, and dresses its hard points: lamps, paved yards, mines on the roads outside each
   opening.
4. **Export.** Once a minute a mature settlement sends its parts above a reserve of 300 (at most 1,000)
   off-world from the launch pad (a visible beam), raising the faction's tier. The pad is an objective
   worth raiding.

Proposed, not built: a second ring of staggered walls before hard points; relocation when a patch runs dry.

## Settlement architecture
Built in `scripts/layout.lua`, `scripts/blocks.lua`, `scripts/rng.lua`.
- **Hubs on a grid.** A hub is a grid of 18-tile blocks with 4-tile roads (`lp-road`, tinted concrete).
  One pylon powers a block. The first hub starts with the landing pad (two cells, walled, the lander at its
  centre); later hubs with a walled compound holding its own generators (cut its lines and its turrets
  still fire).
- **Blocks by role, filled on demand.** Fabricator, generator, depot and launch blocks open when the planner
  needs a slot and none is free; slots fill one machine at a time. Each role has 1-3 hand-made variants,
  mirrored and transposed by the seed.
- **Growth order by archetype**, drawn per hub: grid (compact), street (two rows along an axis), cross (four
  arms). Cells that fail the terrain (water, cliffs, ore, roads, buildings) drop out, so outlines follow the
  ground. A full or boxed-in hub founds the next hub near the outpost furthest from every hub.
- **Doctrines.**
  | | blocks a hub | walled | outposts | pickets | mature at | army mix |
  |---|---|---|---|---|---|---|
  | bastion | 7 | every block, corner turrets | turreted | 0 | 10 blocks | infantry, tanks |
  | sprawl | 4 | pad and compounds | open | 0 | 8 | harriers |
  | picket | 5 | pad and compounds | turreted | 2 a hub | 8 | balanced |
- **Roads** round every block, along long pylon lines (supply routes), and as spines through mining
  outposts (every fourth lattice column is left empty). Walls have an opening in the middle of each side,
  on the roads (gates later).
- **Mining outposts** tile a lattice anchored on the lander, two drills facing a shared bin, over ore only;
  reach widens in steps (40, 90, 160 tiles) when nothing nearer fits, which is how a settlement sprawls.
- **Variety is measured**: `scripts/sheet.py` draws many settlements at one scale with shape metrics. Twelve
  seeds at 60 minutes: all doctrines and archetypes; 1-2 hubs, 1-11 blocks, aspect 1.0-5.9, fill 0.13-0.75.
  Techniques are simple and standard: a seeded Lehmer generator, frontier growth on a grid scored by
  archetype, rejection sampling against the terrain, templates with symmetry transforms, ring searches.

## Economy and the planner
Built in `scripts/base.lua`, `scripts/site.lua`.
- **Economy.** Real drills deplete real ore into bins. A bin counts only while its pylon shares the lander's
  network: cut the line, lose the income. Fabricators (real assemblers, so the engine handles power and
  speed) turn feedstock into parts. Parts pay for building, units and exports. Power is real engine
  electricity on the faction's force.
- **Building.** A queue places one entity every 1.5 s, paid in parts. Pylons are wired explicitly to every
  network in reach.
- **Losses.** A destroyed entity is rebuilt at its spot after a delay (1 minute plus 1 s per tile from the
  lander), before any new growth, unless a hostile turret, unit, vehicle or character stands within 12
  tiles (walls do not count). The planner counts what it owes as still there and builds nothing on held or
  reserved ground.
- **Planner.** Every 5 s, when the queue is empty, the first rule that applies and finds a place acts:
  1. power: demand (and what is owed) above 90% of supply: a generator;
  2. fabricate: ore flowing in faster than fabricators use it: a fabricator (the flow, never the stock);
  3. mine: fabricators starving (young) or income below half of capacity (mature): a mining module;
  4. fortify: parts to spare and a fabricator running: walls and corner turrets for the next block that
     should have them;
  5. defend: an outpost without turrets, where the doctrine wants them;
  6. picket: a hub short of its pickets;
  7. depot: a hub of three blocks without one;
  8. launch, embellish: mature settlements only;
  9. grow: young settlements with parts to spare: more mining.
  Ore near the lander is scanned once, a chunk per tick, into cached lattice cells; a plan tests at most
  12 sites.

## The army
Built in `units.lua`, `scripts/army.lua`.
- **Roster** on vanilla bones, tinted:
  | Unit | Bones | Health | Cost | Tier | Role |
  |---|---|---|---|---|---|
  | infantry | the engineer's body | 120 | 10 | 0 | holds ground, breaches walls |
  | tank | the tank's hull as a unit | 900 | 60 | 0 | armour, explosive shells |
  | harrier | the destroyer robot, air layer | 150 | 40 | 1 | ignores walls, mines, flamethrowers |
  | walker | a spider-unit on the spidertron | 1600 | 120 | 2 | steps over walls, rockets |
  Ranges are 15 tiles at most (see Balance).
- **Air.** Harriers fly on their own collision layer (`lp-air`) with their own target type (`lp-air-unit`):
  walls do not block them, mines never see them, flamethrowers ignore them (artillery is set to, untested);
  gun turrets hit them (laser turrets should, untested). A dedicated anti-air turret is open.
- **Production.** Depots build one unit per 10 s from parts, up to 10 per depot (plus 5 a tier), in the
  doctrine's mix restricted to unlocked units.
- **Raids.** With the garrison 70% full (at least 6), a raid leaves for the nearest player structure within
  400 tiles; 2 units stay home; survivors come home when the group finishes or after five minutes. At most
  one raid per 5 minutes.
- **Patrols.** A few units leave the garrison (bastion 2, sprawl 4, picket and fortress 3) and loop a route of
  up to five stops (outposts, pickets, compounds, the pad), fighting what they meet; the route is redrawn as
  the settlement grows. The settlement looks alive and its soft outposts are visited.
- **Convoys (exports travel).** While the uplink stands, a mature settlement's exports go to it as a hauler
  (the car's hull, 1,500 health, 0.065 tiles a tick, slower than any escort, lightly armed) with up to two
  escorts from the units at home. Convoy discipline is kept by the script: the hauler forms up 25-45 tiles
  out from the depot towards the uplink, waits until its escorts are within 8 tiles, escorts keep station on
  its flanks (3 tiles aside, 3 ahead), it halts while any is more than 12 behind, and an escort stuck behind
  for a minute is released. Measured (convoy, seeds 12345, 777, 4242): escorts at most 7-13 tiles from the
  hauler, 4.6-6.6 on average. It travels in legs of about 100 tiles,
  docking 6 tiles outside the fortress on the side they come from (sent into the inner yard, haulers circled
  the outer ring). Delivered cargo raises the tier; a destroyed hauler loses it. Convoys cross the map,
  likely the player's ground: intercepting them is counterplay against the tier, as their raids are against
  the player's supply. Without an uplink, exports leave from the settlement's own pad.
- **Interceptors.** A hostile train within 150 tiles of a settlement draws up to 4 garrison units (harriers
  first) at its nearest carriage, at most every 2 minutes; they come home as a raid does.
- **Responses.** A faction building damaged or destroyed calls garrison units from the nearest depot within
  300 tiles, at most once a minute per settlement, sized to the threat: six for each hostile turret, unit,
  vehicle or character within 30 tiles, at least six, as many as the garrison can spare above its home
  guard. Against two upgraded gun turrets (defend, seeds 12345, 777, 4242) a response of 8 destroys them
  and loses about half.
- **Military targets** (what player turrets and units fire on by themselves): turrets, depots, radars, the
  lander, the uplink, the launch pad. Production (drills, bins, pylons, fabricators, generators) and walls
  are not, so an outpost can be captured intact or destroyed on purpose. Revised: everything was military
  for a while so turret creep would hit drills, but a squad sent to capture would then shoot what it came
  to take. Turret creep now works against an outpost's turrets, which draws the response.

## What the player can do
- **Cut lines** (built): the supply graph loses income downstream until rebuilt.
- **Raid** (built): destroyed nodes are rebuilt after a delay; the planner does not duplicate them.
- **Occupy** (built): military presence within 12 tiles stops rebuilding.
- **Turret creep** (built): trades with an outpost's turrets and draws a response sized to it (defend:
  three upgraded gun turrets lose to a response of 8, which loses 5-8 units).
- **Hit the launch pad** (built as a target): exports stop, tier growth slows.
- **Intercept convoys** (built): a destroyed hauler's cargo never reaches the uplink.
- **Protect rail lines** near their ground (built as a threat): interceptors go for trains.
- **Field an army** (built, first pass): barracks and rally beacons; **capture** an outpost by holding it.
- Open: capturing power; the uplink assault with an army.

## The player's army
Built (first pass) in `player.lua`, `scripts/command.lua`; the rest of this section is still a proposal.
- **Built:** a barracks (recipe: 5 magazines, 10 iron plates, 2 circuits a trooper, 8 s) turns orders into
  troopers (the engineer's body in warm colours); each follows the nearest rally beacon.
- **Rally beacon (built):** a constant combinator. Its own signals give orders when unwired; wired, it reads
  its networks (which carry its own signals too). **A** advance: the nearest faction turret within 50 tiles
  of the rally point, then any other military building there, then occupy an outpost in that reach, else
  hold. **O** occupy: the nearest outpost within 200, stay, fight back only when hit; locked until the order
  or the rally point changes. **R** retreat to the barracks. Nothing: hold at the rally point. **X** and **Y**
  move the rally point that many tiles from the beacon (at most 300): a clock wired to a beacon walks a
  patrol, a decider sends an attack. The force sees a ring of the reach at the rally point, coloured by
  stance, and a dashed line from the beacon.
- **Combined arms (built; user 2026-10-13: "rebuilding the RTS formula a la Factorio"):** the barracks has
  no fixed recipe (a new one starts on troopers). **Trooper** (5 magazines, 10 iron, 2 circuits, 30 s;
  population 1): rifles, fights units. **Breacher** (5 grenades, 10 iron, 2 circuits, 30 s; population 1):
  a charge thrown 8 tiles every 3 s bursts over 2.5 tiles (enemies only) for 100 explosive damage: 63 to a
  wall, 100 to a turret; bullets do 2.4 to a wall. **Battle tank** (40 steel, 10 engines, 10 circuits, 120 s;
  population 4): the faction tank's hull and stats in the player's colours. Infantry alone should not take a
  walled position; a mixed force should. **Equipment as ingredients (user 2026-10-13):** personal equipment is
  made by hand in small numbers and rarely automated, so unit recipes take it, a fresh logistics chain:
  trooper = heavy armor, submachine gun, 10 magazines; breacher = heavy armor, 10 grenades, 5 circuits;
  battle tank = a tank, 20 cannon shells, 2 battery equipment (built). Later, veterans on modular armor with
  energy shields and exoskeletons. Bandwidth 1 now also needs heavy armor; bandwidth 2 battery equipment.
  Unlocks: troopers and breachers with command bandwidth 1 (after
  military 2, which brings grenades), battle tanks with bandwidth 2 (after the vanilla tank research).
- **Leash and cover (built):** a squad fights units only inside its beacon's reach; under A it skips a
  military building that a faction turret covers (turrets in reach fall first, so the cover is outside).
  Tried and reverted: not fighting units under turret cover (two tanks parked at a compound's cover edge
  shot a holding squad unanswered).
- **Units before buildings (built):** a trooper (not retreating) with a faction unit within 18 tiles fights
  the nearest one. Ordered at a depot, a squad of 20 kept shooting it while the garrison killed every
  trooper and lost none.
- **Capture (built):** a mining outpost with player military within 12 tiles of its centre and none of the
  faction's (units, turrets) within 20 for a minute becomes the player's: drills, bin and pylon change
  force, the faction stops counting and rebuilding them. Army scenario (seeds 777, 12345, 4242): 10 troopers
  trained, all reach the outpost, 1-2 outposts captured, none lost, with the faction's defences around the
  target removed and its responses off (the mechanism alone; a fought capture is next).
- Lessons: an advance at the nearest military target walked ten troopers into a hub's lasers (hence a
  separate occupy order); occupy re-chosen each time took outpost after outpost down to the lander (hence
  the lock); idle units attack whatever enemy they see (hence arrive, then wander in place, fighting back
  only when hit).

- **Command bandwidth (built; decided with the user).** Item costs cannot limit an army in Factorio: a
  mid-game factory makes magazines by the thousand. So units are limited by what production cannot buy.
  Lore: troopers are remotely commanded rigs, each needing a share of a limited command link, as the
  faction's strength runs through its uplink.
  - **Capacity**: each powered command relay (a radar's body, 2 MW) carries 10 units of bandwidth (a trooper
    takes 1; tanks 4 and walkers 8 when they come). Research sets how many relays count: 2 before any, then
    4, 8 and 15 at command bandwidth 1-3, and 2 more for each level of the endless fourth. Relays are
    buildings, so they can be raided: units beyond capacity go offline (newest first; they stop and only
    fight back) until it returns. Orders beyond capacity wait in the barracks.
  - **Barracks** each need a **command core**, which cannot be crafted: a destroyed depot drops one, a
    captured outpost one, a destroyed lander three; the first bandwidth research grants one. The army
    grows with the war.
  - **Pace**: a trooper takes 30 s to train.
  - Caps scenario: 20 trained against capacity 20 with orders waiting; a relay destroyed puts 10 offline;
    level 2 and three relays bring them back and allow 40; a destroyed depot drops a core.

The aim: the player answers the faction with factory output, not clicks.
- **Barracks**: an assembler-like building that turns ammunition, armour plates and parts the player makes
  into the player's own units (the same bones as the faction's, the player's colours): infantry first,
  then tanks and walkers. Units cost real items, so an army is a production line like any other.
- **Rally beacon**: a placeable beacon (circuit-connected) that gathers the units a barracks makes. Its
  signals set the stance: hold (guard the beacon, the default), advance (go to a second beacon or a map
  ping, fight on the way), retreat (back to the barracks). A beacon placed beside a faction node and set to
  hold is how a player occupies ground; capture follows from holding.
- **Supply**: units out of range of a powered beacon (or a forward depot fed by logistics) stop healing and
  slowly lose effectiveness; holding ground far from home needs a supply line, as the faction's does.
  **Built, first step: field repair.** The player's units within 30 tiles of a powered barracks recover 2%
  of their health a second (a trooper from 30 to 102 in 30 s); nowhere else. Retreating (R) mends a squad,
  and a circuit can do it (S or losses low -> R; whole again -> A). A forward barracks is a forward base.
- **Selection tool** as the override (user 2026-10-13: "intuitive RTS unit selection and ordering ... for
  players who are not heavy tinkerers"; circuits stay). Proposed, our own: a command tool (shortcut and key)
  drags a box over the player's units, also in map view; a right-drag or click on ground moves them there,
  shift attack-moves, a click on a faction building attacks it. Selected units obey the direct order over
  their beacon until released back, re-attaching to the nearest beacon. Bandwidth and leashes still apply.
  **Built:** the command tool (shortcut with the vanilla RTS icon, unlocked with bandwidth 1; ALT+C). Drag:
  select (green rings, seen by that player only); shift-drag: release; right-click or right-drag: move (go
  there ignoring fire, then hold), or attack a faction entity clicked (then hold where it stood); shift-right:
  attack-move. A marker flashes where the order went. `control`: six picked, moved where clicked while the
  beacon said A with a turret in reach (ignored), destroyed the turret clicked, returned to the beacon when
  released (both key checks seen failing with hand orders off). Tried in game by the user (2026-10-13):
  "everything seems in order".
- **Capture by holding**: a faction mining or power node with player units on its ground and none of the
  faction's for a minute becomes the player's (its drills mine for the player, its generators feed the
  player's grid). No capture by damage threshold (that is Proliferation's).
- **Circuits as the player's command language (direction, user 2026-10-13):** automate patrols and
  attacks with the circuit network rather than a selection tool. Built: stance and rally point by signal.
  **Built: the beacon reports** on its own output, in a section it writes every 2 s (the first section
  holding only report signals; made when missing): **S** its squad, **E** faction units and **T** faction
  turrets within reach of the rally point. One decider wired to a beacon (S >= 8 -> A) holds a squad until
  it has eight, then attacks (`circuit`: no shot before, A at 8, the turret falls). The barracks needs
  nothing: an assembler already reports its contents and takes its recipe from the circuit network.
  Next candidates: a squad's losses (D), ammunition or health; beacons that report the rally point's
  ground (captured, contested).
- Next: tanks and walkers for the player; supply (healing near a powered beacon); capture of generator
  blocks; a fought capture that a sensible army wins.

## Balance
Measured in the `assault` scenario (fast mode: a depot and parts granted at the start; replay GIF and
stills per run) and `defend`.
- **Calibrate against the player at arrival time**: piercing rounds, +80% bullet damage, +60% shooting
  speed. Against yellow ammo and no research every raid was a walkover.
- **No armour that makes a tier immune**: a flat 10 physical reduction made gun turrets useless. Now 3 and
  20%.
- **Unit range at most turret range less the wall's depth** (15 against a gun turret's 18): longer, tanks
  shelled walls from outside turret reach.
- Current curve (seed 12345, three doctrines): raids of 5 and 8 die on the approach; the third (12) takes a
  four-turret outpost, walkers stepping over the wall and harriers flying in.
- Responses: a fixed 8 died to the last unit against two turrets; sized to the threat they win at a cost.
- Confirmed on seeds 777, 4242, 101 (assault, defend, faction, uplink: 12 of 12).
- Open: tier thresholds and export rates are untuned (the `faction` test runs them at a tenth); garrison
  caps limit responses (10 a depot at tier 0).

### Fought capture (in progress)
`siege`: a sprawl settlement at 15 minutes (depot, garrison 16 of infantry and tanks, raids off, responses
and patrols on); troopers by the dozen from a barracks beyond it; the beacon at the first point out of laser
reach on the line to the nearest outpost, set to A; once that ground is clear, the test moves the beacon
onto the outpost and sets O.
- `duel` (open ground, three seeds): 10 troopers against 10 drone infantry trade evenly (either side wins
  with 1-5 left); 10 troopers kill one of two tanks. A tank is worth about seven troopers, near its cost.
- Seed 12345, troopers lost / faction units killed: 20 -> 20/3; 40 -> 40/10; 60 -> 60/14. With 60 the
  staging ground (two turrets, a depot, the garrison's sally) falls in a minute with 25 left; those die on
  the way to the outpost, which lies beside a walled four-turret compound with mines (31 killed by turrets,
  6 by mines).
- Reading: bullets barely scratch walls (2.4 of 6 damage), so troopers alone cannot breach a walled laser
  position. Decided (user): add breachers and battle tanks, combined arms.
- With mixes (troopers, breachers, tanks; seeds 12345 and 777): 60/0/0, 40/20/0 and 30/10/5 all lose
  everything, 28-60 of them in the first minute. One early 30/10/5 run captured the outpost before the
  leash and cover rules. Death logs and frame stills show why: the test's beacon stands 30 tiles out of
  turret range, so its 50-tile ring overlaps a compound's laser cover by about 20 tiles, and every fight in
  the ring is partly under those lasers. The test places beacons as a careless player would.
- **A careful player (now the test):** a forward base 15 tiles behind a staging point out of turret reach;
  the squad gathers there, then X/Y steer the rally point onto the defending turret nearest our side, on
  A, one at a time; with no turret within 60 of the outpost, onto the outpost on O. Damage logs showed
  the battle tank was mostly armour (5 tanks, 2,100 to turrets in a whole assault) and breachers crossed 16
  tiles of laser fire: the battle tank now fires 100 at 18 tiles (the faction's keeps 35 at 15), the
  breacher throws from 12.
- **The curve (fork at minute 15, seeds 12345 / 777 / 4242):** 60 troopers lose everywhere; 30/10/5
  (troopers/breachers/tanks) wins once (777, lander destroyed); 20/10/10 wins twice (12345: three outposts
  captured; 777: lander); 4242's outpost (7 turrets near it) falls to 30/20/20 (130 bandwidth, research
  level 3), 16 of 70 left, lander destroyed. Infantry alone never takes a defended position; tanks decide.
- **The fall (built):** a destroyed lander collapses its settlement. Its generators fail one by one (one
  every 1.5 s, in random order), so its turrets go dark. Its units (garrison, patrols, raids, convoys)
  evacuate to the nearest standing settlement with a depot within 1,500 tiles and join its garrison; with
  none, they stay among the ruins and fight. When the last generator is gone, what stood becomes ruins:
  neutral, minable by hand or robots for salvage (half the building's cost in parts; a fabricator gives
  12); salvage reclaims in an assembler to 4 iron, 2 copper and 1 circuit. The mining outposts stay the
  faction's, unpowered and unguarded, to be taken by holding them; the mines stay live. Nothing is rebuilt.
  The player is told ("A settlement has fallen at ...").
  `fall` (seeds 12345, 777): 7 generators fail, no live turret within 150, 187 ruins, 22 units evacuate (the
  other garrison 18 -> 40), a fabricator mines into 12 salvage, a held outpost is captured (4 modules).
  A bug it found: entity references are not stable Lua table keys (keyed by them, outposts were ruined
  too); unit numbers are.
- Also open: whether the reach should be smaller, or the ring should show turret cover.

## Where Landing Party differs from Proliferation
Proliferation (MIT, no public source, 2026) is a machine faction in the mould of Stargate's Replicators:
bases placed at map generation on their own matter nodes, four fixed build stages, one unit (the walker)
sent in waves, waves that eat items to grow, capture below 30% health, fragments that grow into bases,
later ships and a planet. Its character is an infection. Ours is a rival economy:
- they arrive because of the player's launches, repeatedly;
- they sit on the player's real ore and export it;
- planned, readable settlements with a supply graph to cut;
- combined arms (infantry, tanks, harriers, walkers);
- an economy war with an RTS layer (the player's own army, to come);
- an arc with an end (tiers, the uplink).
Avoid its signatures: no capture at a damage threshold, no units grown from eaten items, no fragments.

Prior art for units: ERM RedArmy (LGPL) builds infantry on the engineer's body; Robot Army and Commander
(MIT) for squad AI and HQ-driven orders; ERM Unit Control (LGPL) as an optional selection-tool dependency.
Never ERM's StarCraft or Metal Slug art (ripped).

## Operations: the faction's military with intent (decided 2026-10-13, to build)
The user agreed with the review and widened it: the faction gets a **repertoire of operations**, capabilities
and plans rather than unit types alone ("a siege could play like Rimworld's: stop to regroup, build a small
mortar position, harass from afar to draw you out of your walls"). Every operation has an objective,
preconditions (what the faction must know and have), phases, and an abort rule. They rest on **intel** (what
radars, pickets, patrols and its own losses have shown it: nothing unseen can be targeted) and **target
values** (relay 10, barracks 8, power cut point 6, rail 5, drill 4, assembler 3, turret 1, lamps and pipes 0;
divided by known defence).
- **Raid**: hit-and-run on a valuable, lightly defended target; force sized to known defence; staged out of
  range; abort at half strength or after 90 s without a kill; remembered.
- **Siege**: a force stages out of range and builds a **mortar emplacement** (walls, a few guards) that
  shells the player's walls from about 36 tiles, beyond gun (18) and laser (24) turrets: the player sallies or
  answers with artillery. The first capability the faction builds in the field.
- **Sabotage**: harriers at power cut points and the player's relay chain.
- **Probe**: scouts test a sector and report.
- **Retake**: counter-attack an outpost the player captured.
- **Feint** (later): a loud attack on one side to draw the player's army, the main blow on the other.
- **Bombardment** (later; user 2026-10-13): long-range threats, an artillery or missile position that
  outranges everything but the player's artillery, built and guarded far out. The player's counter-build:
  anti-missile interceptors that need radar coverage (radars earn their keep, a mirror of the faction's
  jammers), or a strike on the position. The late, expensive end of the same framework, after raid and siege.
**Built (first pass), `scripts/ops.lua`: intel and the Raid.** Sensors: the lander (200 tiles), depots (150),
radars (250), units in the field (40); a scan every 2 minutes forgets what is gone. Intel is kept per 32-tile
cell (the most valuable structure, turrets within 30); faction deaths leave markers (a turret's worth per
three). A raid needs 3 units a known turret plus 4 and leaves from what is above a reserve of 30% of the
garrison cap; it stages 34 tiles short of the target on the line from home, attacks the target's cell
(radius 12), and aborts below half strength with a turret still there, after 90 s without a kill, or, looking
from the staging point, when it sees more turrets than it can take (it turns back unhurt). An abort cools the
position (48 tiles) for 10 minutes and is remembered. Replaced: the nearest-entity raid and its 28-type list.
`ops` (seed 12345): with a defended cluster 110 tiles out and a valuable undefended one 170 out, the first
raid (4 units) went for the command relays and destroyed all three buildings; a later one at the defended
cluster came with 16, sized to its four turrets. `abort`: the target armed with six turrets after the raid
left; it saw them from staging and came home 4 of 4, and did not come back within the cooldown. Lessons: the
cooldown on a cell missed the cell next door (now an area); attacking blind lost every raider (now a look
from staging, and what it sees there replaces what it believed).
**Alarms feed the intel; static threats get a raid, not a response.** A building under fire records what is
around it (40 tiles); responses see as patrols do. A threat with no mobile part (turret creep) draws no
piecemeal response: fed squads of 18 one at a time into three upgraded gun turrets, a garrison bled out and
never mustered a raid (`defend`, after the nearest-entity raid that used to clear creep by accident was
removed). Instead the spot is a priority for 10 minutes (+10 value) and a raid sized to it goes when the force
exists: one raid of 19 against three turrets, 11 lost, creep destroyed, the outpost rebuilt. Force sizing is
now 5 a turret plus 4 (3 lost to upgraded ammunition). After a raid, the faction records what it saw at the
target: destroyed targets are forgotten (one raid set out again for creep it had destroyed).
**Built (first pass): the Siege.** When no raid is affordable and the settlement has 100 parts and 6 units
to spare, it picks a fortified target (2 or more known turrets) and a site: from the target towards home, or
at angles off that line, the first point beyond 31 tiles of every player turret (a flamethrower's 30) with
one within 35, on dry land. A hauler carries the **mortar** (the artillery turret's body at 60%, tinted; its
own gun: 36 tiles, minimum 6, a shell every 4 s; the shell bursts over 2.5 tiles for 90 explosive and 30
physical, hitting the player only; it fires at military targets by itself) with 30 shells, escorted by the
guards. At the site: 30 s of deploying (a label counts up), then it shells until the shells are spent,
nothing is left in reach for a minute, or the guards are halved; it packs up in 10 s and the column goes
home, where the hauler stands down. A destroyed mortar leaves 15 salvage; a destroyed hauler on the way
ends the siege. Guards fight only what hits them (engaging what they saw, they walked into turret range).
Sieges cool for 15 minutes. `bombard` (seed 12345): eight armed gun turrets behind walls (a raid would need
44): a mortar deployed 32 tiles from the nearest turret, hit all eight, packed up when nothing was left in
reach; a raid of 34 then took the softened position. Nobody scripted that sequence. Staging is now measured
from the outermost turret (staged from the target's centre, a raid lost 15 of 34 before attacking).
Next for sieges: moving the mortar up when its reach is cleared, resupply convoys.
Order: intel and the operation framework with Raid (and abort) first, then Siege; the rest after a first-hour
playthrough baseline. Also adopted from the review: garrison roles and escalating alarms; tier as capability
(the +15% damage goes); relay and barracks control radius with R always obeyed; jamming instead of satellites
as targets; the landing as an event; the settlement readable in game. Parked: the uplink fight, rival
corporations, more convoy and interceptor work.

## Corporations (building, from docs/campaign.md and docs/corporations.md)
**Step 1, built: corporations as forces.** `shared.CORPS` names them (Grubstake Mineral Recovery `lp-grubstake`,
Serenity Perimeter Group `lp-serenity`, the default); each settlement belongs to one (`b.corp`, `b.force`) and
every force check asks the settlement's force or "any corporation". Only the player's forces capture outposts
(a rival's raid passing through does not). The tier damage bonus is gone (tiers will buy capabilities).
Corporations are at war with each other and with biters. A landing is heard by every other corporation (its
site enters their intel); their buildings have target values (uplink 10, lander 8, depot 6, generator 5,
launch pad 5). `rivals` (seed 12345, 40 minutes): Serenity raided Grubstake twice and besieged it once, losing
every time to Grubstake's 11 turrets (0 of 4, then 5 of 24 came back; the siege's hauler was destroyed);
Grubstake never struck back (Serenity too well defended for what it could field). Before the landing was
heard, two settlements 249 tiles apart never knew of each other and never fought.

**Step 2, built: each corporation's own prototypes.** `corps.lua` copies the faction's kinds (`shared.KINDS`:
buildings and units) for every corporation but the default, renamed `lp-<corp>-<kind>` and re-tinted
(Grubstake ochre, lamps amber; the walker's legs copied with it). The logic speaks in kinds; creation
(`place`, units, haulers, mortars, landers) uses `shared.variant(corp, kind)`, queries and event filters
`shared.variants(kind)`, recognition `shared.kind_of(name)`. The default corporation keeps the plain names,
so every existing test stands. `rivals`: Grubstake built 383 entities, all its own.

**Step 3, built: look beyond colour** (three looks by the user, 2026-10-13). Grubstake ochre ("feels dirty",
kept); Serenity two-coloured: charcoal walls, turrets, poles, lamps and mines on pale concrete, slate-teal
machines and units (all slate-teal "felt strange", untinted walls read as vanilla). Floors per corporation:
roads (Grubstake gravel, Serenity plain refined concrete), pads, and a trim: depot blocks and mature walled
blocks are paved edge to edge in the corporation's pad floor with a trim one tile inside (Serenity black
concrete, Grubstake hazard stripes). Logos are not on the ground: scaled icons looked pasted on, painted icons
blurry, concrete pixel art merged into blobs (Factorio bevels every tile edge); they appear where icons render
at their size: map tags at each settlement (corporation icon and name, "(fallen)" after a fall) and the
landing and fall notices (icon, name, motto). Every corporation's buildings and units are labelled with its
name. Tint can only darken a sprite: "whiter than vanilla" walls would need other source art.

**Step 4, built: architecture.** Corporations carry doctrine weights, a unit mix and architecture flags. Serenity:
bastion and picket; gates in every opening, a baffle wall two tiles inside each opening (entry zigzags: the
staggered double wall), corner lasers walled into pillboxes; infantry, tanks, walkers, no air. Grubstake: sprawl;
gun turrets (its own `lp-grubstake-turret` is a gun turret) kept in piercing rounds by the economy, fences at half
a wall's health; infantry, buggies (the car's hull, fast and light) and harriers. `rivals`: 144 Serenity gates,
10 Grubstake gun turrets all fed, 49 buggies built; five operations between them, 33 and 66 units lost.
Accepted by the user in game ("nothing glaring"). Since built: flamethrowers at Serenity's gated blocks, one
outside each opening beside it on the road (inside, every tile is taken), kept in light oil by the economy step
(`rivals`: 4 of 4 fuelled). On hard points only (compounds, pads), 8 parts each: four on every walled block
starved a bastion of parts, and the regression caught it (occupy rebuilt 0 of 9, defend left the creep standing).
A rebuild found blocked (often by a unit standing on the spot) is tried again every 30 s, five times; dropped at
once, an outpost turret was never rebuilt.

**Built: territory and the opening** (docs/campaign.md section 3). Each settlement's territory is drawn in map
view only: a translucent disc in its corporation's colour over everything it has built (plus 24 tiles),
re-measured every two minutes, grey after a fall. The opening, `scripts/phases.lua`, checked once a minute:
**signs** (a player force owns a radar: an unknown craft's wreck 180 tiles from it, 30 salvage inside, a notice);
**survey** (oil processing researched: a survey party of the first corporation, chosen from the map seed, lands
about 450 tiles out on ore: a radar mast, two drills, a lamp, four guards, a map tag; destroyed, it drops a
command core and the arrival waits 20 minutes after its trigger; left alone, it departs after an hour and the
corporation arrives 30 minutes later, trigger or not); **arrival** (Space Age: the first rocket launch, through
the phases now; base game: the first chemical science pack). `phases` (radar, oil, survey destroyed, chemical
pack: wreck with 30 salvage, 8 survey entities, the core dropped, no settlement 12 minutes after the trigger,
one at 24) and `phases` with LP_MIX=left (the party departs, the corporation comes with no trigger).

**Built: development and the threat budget** (docs/campaign.md section 6). Each corporation has a level from
its own exports (3,000, 8,000, 20,000, 45,000 parts; `storage.corps`), and each level brings capabilities, never
a hidden bonus, announced to the player ("... has expanded its capabilities: siege operations"). Grubstake:
harriers at 1, pickets that see at 2, a headquarters at 3; never sieges. Serenity: sieges at 1, walkers and
pickets that see at 2, a headquarters at 3. Garrison caps grow with the corporation's level. The faction-wide
tier remains for the uplink and exports. The threat budget: operations against a player force at once,
across every corporation, at most 1 + its era (era 0-4 from research done: 25, 60, 100, 150 technologies);
operations between corporations are not counted. The floor: after 20 minutes with no operation against a
player, player targets weigh triple. `budget` (both corporations, era 0, an hour, sampled every second): at most
one at once, the budget holding a target back 4 times; lifted (era 10), two ran at once (the check seen
failing). `develop`: exports past 3,000 raise Serenity to level 1.

**Built: corporations and biters.** Clean by default (settlements emit no pollution). Measured first: a
corporation destroying a spawner raised the biters' spawner-kill evolution exactly as a player's kill does (a
flat +0.002, destroy_factor, per spawner, at evolution 0 and at 0.5). So `scripts/biters.lua` gives it back a tick
later for every spawner a corporation destroys (a first refund inverting destroy_factor * (1 - e) left a residue
at 0.5; the component is flat). Landings avoid sites within 60 tiles of a spawner. An alarm raised by biters alone
draws 3 units, not a squad sized to every biter. Serenity clears nests on its own territory (spawners in its
claim are targets of value 3, worms their defence; raids on them announced, not counted in the threat budget);
Grubstake never does. `evolution` (a corporation's kill leaves evolution where it was, from 0 and from 0.5; a
player's raises it) and `nests` (three spawners on Serenity's territory raided and destroyed, evolution unchanged,
five biters at a building drew 3 units).

**Built: headquarters per corporation** (consulted with Fable, `docs/reviews/2026-10-13-headquarters-consult.md`).
The faction-wide uplink is gone. A corporation consolidates (announced) at level 3, or after 5 hours standing with
two or more settlements (an announced floor, so starving its exports cannot freeze the arc), and lands its
headquarters 10 minutes later, off the landing clock, about 250 tiles from its richest settlement: the fortress
with its uplink. The HQ's lander cannot be destroyed while the uplink stands. The uplink's fall brings the HQ down;
the corporation withdraws (no building, rebuilding, exports, unit production or operations; its weakest
settlement falls every 15 minutes, each with a notice in its voice); the rival's next landing comes 30 minutes
sooner and starts from the vacancy; the player gains the corporation's prize, a recipe unlocked by a hidden
technology: Serenity's mortar (20 salvage, 10 steel) and its shells (2 salvage, 1 explosives), Grubstake's strip
drill (an electric drill at twice the speed and half the ore drain; 15 salvage, 10 steel, 5 circuits). Convoys go
to their own corporation's headquarters only. One landing clock (90 minutes, launches hasten it) lands the
corporation with fewer settlements standing; the second corporation enters at the third landing; at most 3 per
corporation (HQ counted) and 6 in all. Not built: a new corporation after both are gone (post-MVP), a migration
for old saves (no saves to migrate yet). `hq` (fast clocks): Serenity at level 3 landed its HQ, the lander held
while the uplink stood, the uplink's fall brought it down, Serenity withdrew, the player's mortar recipe was
enabled, its first settlement fell on the withdrawal clock.

**Built: tempers** (the corporations' profiles in their operations). Serenity never strikes a player first: it
targets a player force only once provoked (that force damaged or destroyed its buildings or units), and the
provocation is permanent ("never forgets"). Grubstake raids only unguarded player targets (known defence 0), never
breaks the player's drills (they show it where the ore is), and strips first: a hauler and four guards set up a
camp on ore beside the player's drills, out of turret reach and clear of the player's buildings (a generator, a
pylon, three drills over bins), mine the real patch for 10 minutes, pack up, and the hauler carries the ore home as
feedstock (lost if it dies on the way). `temper` (unprovoked, no operation against undefended relays in 15
minutes; one shot at a pylon, then one came) and `strip` (two camps, 440 ore taken from the patch, 408 delivered).
Two lessons: the thief first raided the drills and had nothing to strip (drills are now off its raid list);
strips came after raids in the choice and never happened (a thief now strips first). Tests of operations'
mechanics run with every corporation provoked from the start; `temper` and `strip` without. A region whose first
corporation is Serenity would stay quiet until the player struck it, so encroachment provokes too ("Please remain
behind the line"): a player building inside its territory counts as an attack. The first-contact timelines, with
no provocation scripted, still see Serenity come (the player's outpost lies inside its growing territory): 12, 11
and 9 operations for the passive, robots and walled players in 2 hours, production 16, 93 and 94 of 94 standing.
`temper` checks that no operation against the player starts before the provocation, whatever caused it.

## First contact: the baseline (2026-10-13)
`contact` (seed 12345, 3 hours, real clocks; `docs/sim/contact-12345/timeline.png` and `timeline.md`): a
player base at spawn as of the first launch (64 assemblers, 20 furnaces, 10 labs, substations, 2 roboports,
a radar; 16 laser turrets in four corner clusters, laser research) and a mining outpost 130 tiles towards
the faction (8 drills, 2 lasers, big poles home). The scripted player is passive: it neither rebuilds nor
answers. The faction lands 339 tiles out and on its own clock after that.
- The first raid comes at minute 38 (the garrison full enough and the outpost in sight). The outpost falls
  at once.
- Then a raid a minute: 4 units each, at substations the faction has just seen (value 6, defence 0). Each
  raid's sight and each alarm reveal the next substation, so it eats through the power grid; the lasers,
  unpowered, fall with it. By minute 75 nothing of the base stands: 26 raids, 1 siege, few faction losses.
- The faction's income is 200 parts a minute from minute 20, 300 with the second landing at 90.
Reading: the operations work as written and are too relentless: no pause between successful raids, so
four units at a time strip an undefended interior. A real player rebuilds with robots and walls a
perimeter, so the passive player overstates the damage, but a raid every minute is biter pacing, not a
rival's. Questions for the next pass: a cadence (a settlement launches at most one operation every few
minutes, longer after losses); a reserve that grows with the settlement rather than a fixed share; a
scripted player that rebuilds with robots and answers with turrets, and one with a walled perimeter.

### With the cadence and a careful player
A settlement now waits after an operation: 5 minutes after a success, 10 after an abort, a minute more for
every 5 units lost. `contact` again, three players (seed 12345, 3 hours):
| player | operations | production standing at 3 h | turrets standing |
|---|---|---|---|
| passive | 21 (26 in 35 minutes before the cadence) | 8 of 94 | 8 of 18 |
| robots (losses leave ghosts, nine roboports rebuild from spares) | 17, 4 turned back | 64 of 94 | 12 of 18 |
| walled (robots and a wall and laser perimeter) | 12, 8 turned back on sight, 1 siege | 94 of 94 | 35 of 62 |
The outpost falls in all three (no robot coverage there). Raids come about every 8 to 10 minutes. A careful
player holds; the faction reads walls and turns back or besieges; turret attrition grows with each landing,
so a player who only defends bleeds slowly, which is where the army (destroying landers) has to come in.
Cost: the robots run took nearly 8 minutes alone (hundreds of construction robots). Now `scripts/contact.sh`:
the three players, 2 hours each, from one shared fork (the player's base goes down at minute 20, before the
faction can see it), about 5 minutes a round. At 2 hours: passive 10 operations, production 20 of 94; robots
12, all production standing, turrets 15 of 18; walled 8 (4 turned back), turrets 53 of 62.

### Era bases (the review's instrument, first pass)
`scripts/contact.sh [seed] [minutes] [variants]`: besides passive, robots and walled (first contact), "spread"
(era 2: three outposts, robots) and "late" (era 4: walled, robots, upgraded lasers, an artillery turret). At 2
hours, seed 12345: spread 12 operations (4 turned back), 12 of its 24 outpost drills lost, production whole; late
2 operations, both turned back, nothing lost. Findings for review:
- **The late base is untouchable.** The review's warning holds: pressure on a late player must come from transit
  and expansion denial (stripping, far pole and rail lines, claims round it), not walls; today nothing reaches it.
- **Tempers can leave a careful player alone.** Serenity strikes only once provoked; a player who never encroaches
  on its territory sees no raid from it, and Grubstake enters only at the third landing (hours in). The threat
  floor weighs player targets but cannot override a temper. Options: the first corporation is always the active
  one (Grubstake), or the floor provokes, or Serenity's territory grows towards the player.
- Corporations now land outside the player's artillery (300 tiles), so a late player is ringed, not shelled at.
**Built: alerts.** An operation going in against a player (a raid attacking, a siege's mortar up, a strip camp
mining) puts a custom alert with the corporation's icon on the nearest of that player's buildings, for every
player of the force, on any surface (absence is not a truce). Needs a game session to see (no players headless).

### Late pressure and the moving line (Fable's consult, `docs/reviews/2026-10-13-late-pressure-consult.md`)
**Built.**
- **Strips of guarded outposts.** `choose_strip` required the target drill to be undefended though `strip_site`
  already keeps the camp out of turret reach: a careful player's outposts (two lasers each) were never stripped.
  Now any outpost with a camp site beyond turret reach can be stripped.
- **Transit is a target.** Rails (value 3) and signals (2) are sensed. A line cell (a pole or rail with no player
  turret within 60 tiles) scores double, ignores past attempts and cools in half the time (5 minutes): cutting a
  far line is cheap and repeated.
- **Serenity's line moves.** From 30 minutes after landing, a Serenity settlement's perimeter grows 30 tiles every
  10 minutes (at once when 20 minutes passed with no operation against a player), announced every third step,
  with a named warning ("will extend its perimeter past your Roboport at [gps] within ten minutes") one step
  before it encloses a player structure. It stops at the nearest player structure + 40, at 450 tiles from its
  origin and short of another corporation's claim. Enclosing a structure is encroachment, so it provokes.
  `line` (relays at 185 tiles; a step a minute in the test): grows, names a relay, provoked only after the
  warning, no operation before; `line` with `LP_MIX=back` (the relays removed on the warning): never provoked.
- **Claims.** A strip camp that mines its full time unanswered (every drill standing, every guard back) registers a
  claim on the patch (a notice); the second unanswered camp on the same patch (64-tile squares) stays: a mining
  module of the settlement, rebuilt and capturable like any outpost, its ore hauled (no line home), marked on the
  map with its own small disc ("a permanent recovery site", a notice). A held patch is not stripped again.
  `strip` with `LP_MIX=claim` (40 minutes, in `--full`; Serenity and the biters at peace with Grubstake, whose
  guards they had killed): one settled, three drills standing.
- **Measured, the late base (contact, seed 12345, 2 hours):** 8 operations (was 2), 3 of them landing: raids on
  far substations (line cells) and a siege at 117 minutes; nothing behind the walls lost. Spread: 13 operations, 5
  turned back. Fable's bar (at least 4 operations, at least 2 landing) is met. The settlement was Serenity, unprovoked at
  the fork: its line grew 4 steps (to 285 tiles) and its first raid went out at 36.5 minutes, so the moving line is
  what brought a careful late player into its war (Fable's bar: provoked within 90 minutes of landing).

### Next slice (Fable, `docs/reviews/2026-10-14-next-slice-consult.md`)
The campaign instrument first: a reactive scripted player (answer, strike, era) over hours at real clocks, measuring
cost to each side, not launches; the loop must close (a lander falls to the player) before it widens. Two bugs
fixed on the way:
- **Resistance.** A raid that attacked and razed nothing raises the target's known defence by one (`t.resist`,
  kept apart from turrets seen, which the staging look overwrites): robots out-repairing four infantry read as a
  turret, so the next raid comes bigger or not at all (five identical raids on one substation came home untouched).
- **Staging outside the walls.** A raid stages on the line home at the first point beyond every turret's reach with
  no player wall between it and home (a point at a fixed offset fell inside a walled base and timed out there).

### The campaign instrument (built 2026-10-14)
`scripts/campaign.sh [seed] [minutes]`: contact's spread base (era 2, three outposts, robots) and a reactive player,
6 hours at real clocks, unprovoked, from contact's fork. Its rules, every 5 minutes, through what a player has:
**answer** (two lasers where it lost something, at most 6 + 4 per era), **strike** (every 45 minutes from minute 80:
troopers, breachers and battle tanks by era at the nearest settlement's lander when what stands round it is weaker
than the squad, else at the corporation drill with the fewest turrets near), **era** (up every 90 minutes), and from
era 3 a **forward battery** (an artillery turret 200 tiles from the target lander, four lasers, kept at 20 shells,
aimed at the lander with a flare as the artillery remote does). The timeline gains cost columns (corporation units
lost, player buildings razed, settlements fallen, landers the player killed, strikes, corporations standing).
Findings (seed 12345):
- **Squads never win.** Seven strikes of 27 to 53 units (four battle tanks at most) all died within 10 minutes, at
  an outpost with four turrets as at a lander: flamethrowers and lasers kill most, tanks the rest. The 5-hour
  contact runs say the same from the other side: the corporations bleed the player slowly and nothing the player
  fields with the mod's units takes a settlement. **For the user: is that intended (artillery is the answer, units
  are for outposts and defence), or should squads be able to take a camp-stage settlement?**
- **Artillery closes the loop, aimed.** Left to itself a battery shelled the nearer defences (rebuilt as fast:
  563 shells in four hours, the lander untouched). Aimed with a flare, it killed the lander within 5 minutes, twice
  in a 3-hour run. The corporations do not answer a battery yet (no operation went against it).
- Fixed on the way: a substation inside the base counted as an isolated line cell (66 tiles from the corner turrets)
  and four raiders died on the way to it every ten minutes: line cells must now be isolated, and a raid that lost
  raiders and razed nothing also raises the target's resistance. A headquarters whose fortress found no free square
  near its site failed 25 times running: a landing whose pad does not fit now moves to the next ring.
- Grubstake enters at the third landing (about 3 hours); a corporation consolidated by hour 6.
- **Counter-battery (built).** A corporation building or unit killed by artillery tells every settlement of that
  corporation where the battery stands (seen, a threat zone) and provokes. A known battery comes first in the
  decision: a corporation that ever besieges sends a siege at it whatever its level (counter-battery is not an
  operation of choice); one that never besieges raids it, with its reserve, past its temper and the threat budget.
  Measured: Serenity's settlement 2 besieged the battery that killed settlement 1, twice (18 and 30 mortar shells,
  two of its four lasers).
- **Then the opposite extreme.** With batteries aimed, both seeds (12345, 777) lose a lander 35 minutes after every
  landing, four in six hours; no corporation lives to consolidate. A lander has 3000 health and no resistances: two
  artillery shells. Counter-battery comes after the lander is dead. Taken to Fable (the next section).

### Artillery, landers and squads (Fable, `docs/reviews/2026-10-14-artillery-consult.md`)
Roles: artillery ends a settlement, squads take camps and hold ground; a lander kill is the campaign's milestone
(once or twice in six hours), costing a forward position that is usually lost. **Built:**
- **Armour.** Lander 12000 health, 50% physical and explosion resistance (about 12 shells, was 2).
- **The powered hull.** A lander cannot be destroyed while at least half the most generators its settlement has
  had still stand (`base.lua` hull, checked every second; a headquarters answers to its uplink instead).
  Generators are not military targets (never auto-targeted) and come back 90 s after they fall.
- **Seen when built.** The lander's sensor reaches 300 tiles (the player's artillery reach), and counter-battery
  runs on any battery in intel, not only after it fires.
- **Landings avoid the player's army** (units or turrets within 100 tiles), as they avoid its artillery. (Built on
  a misreading: three landings on seed 777 fell within four minutes, which were the campaign player's own camp
  strikes, not a squad left on the ruins. Kept as a rule; not shown to matter.)
- The campaign's player now places its battery at a clear site in reach (no corporation turret within 50; at a
  fixed 200 tiles it stood inside Serenity's outer works), with 2 guns at era 3 and 4 at era 4, flares every
  generator in reach then the lander, and its squad guards the battery; it strikes each new settlement once,
  3 to 20 minutes after landing, from 60 tiles out.
**Measured (6 hours, seeds 12345 and 777).** 12345: three batteries placed, all three lost (tanks, and a mortar:
six counter-battery sieges); camp strikes won 2 of 4 (both Grubstake camps; Serenity's held); no lander killed by
artillery; a corporation consolidated by hour 6. 777: the battery stood all game (31,714 shells) and the hull never
went down: most of a mature settlement's generators are beyond one battery's reach, so its lander cannot be
reached; every new settlement (three) fell to a camp strike 3 to 4 minutes after it landed, Serenity's as well as
Grubstake's, so no corporation grew past its first. **Open (for the user and Fable):** the hull makes a mature lander proof against a
battery from one side; Fable's target of one or two artillery kills in six hours is not met. Options: count only
the generators within 300 tiles of the lander, or a smaller share, or let the player bring more guns.

### Hull, drop escort and grudge (Fable, `docs/reviews/2026-10-14-hull-consult.md`; built 2026-10-14)
- **The hull counts the core.** Only generators within 80 tiles of the lander count (`HULL_RADIUS`), half of the most
  ever counted must stand, and fewer than two counted is a hull down. Later hubs lie 90-160 tiles out, so a battery in
  reach of the lander reached almost none of a mature settlement's generators (777: 31,714 shells, never down).
- **The drop escort.** A landing (not a headquarters) brings 6 + 4 a level units of its corporation's mix, free, and
  four gun turrets at its pad's corners, both placed once the pad is laid (spawned at landing, the escort stood where
  the pad's pylon goes and the first mine never powered). The turrets are the drop's: never rebuilt, packed up 20
  minutes after landing. A camp had no depot (cap 0) and no walls for its first twenty minutes, and every one fell
  to the first squad (777). Side effects, tests adjusted: one-depot rivals no longer fight in 40 minutes (the only
  fighting was a minute-1 raid on a bare camp; `rivals` now grants three depots each), and in `budget` Serenity, with
  its escort, raids Grubstake first and Grubstake razed both relay groups before Serenity turned to the player
  (the groups are now rebuilt every 5 minutes, as robots would).
- **The grudge.** A lander a player force destroys provokes its own corporation for good; the other corporations take
  note without provocation (`ops.alarmed`: they see where the killer stood, mark a threat there, and count the
  defences round it one turret stronger), so a player fighting the thief does not make the wall-builder an enemy.
  The player is told (`lp.grudge`). The fallen settlement's corporation lands its next settlement angry (`b.grudge`,
  told: `lp.grudge-landed`): it besieges whatever its level or temper (Grubstake, which never besieges, does), its
  drop escort is doubled, and its garrison cap is doubled for 30 minutes from its first depot (from the landing,
  the window ran out as the depot opened). Only the next landing carries it. Scenario `grudge`.
- **Measured (campaign 777, 6 h, before weighted defence).** Two artillery lander kills, at hours 2.1 and 5.1
  (target: 1 to 2, two hours apart: met), each preceded by the hull going down, but each within one to three
  minutes of the battery being placed: the battery site now reaches every counted generator (3 of 3, 7 of 7), two
  guns break three 400-health generators before any rebuild, and the corporation never gets a turn (target: the
  battery attacked within 10 minutes, before its first shell; batteries lost 0 of 2; 44,964 shells supplied). The
  scripted player places a battery charted, flared and firing in one tick, which a player cannot. Camp strikes won
  2 of 3 against the escort (target at most 1): 27 units took Serenity's second camp (losing 14), 40 took
  Grubstake's (losing 14); 53 died at Serenity's fourth (a level-2 escort). No corporation consolidated (three of four
  landings fell). Open: the battery's setup time in the instrument (a build delay before it fires), and whether the
  hull should need its generators down longer than their 90-second rebuild.

### Operations in depth (the user's ideas, Fable: `docs/reviews/2026-10-14-operations-depth-consult.md`)
The user (2026-10-14), on hearing how raids are sized: turrets should weigh by type and tech, and units should count;
corporations could steal what is valuable (a chest of circuits, fuel cells, a Kovarex line, a cargo bay); sieges
should come for destruction, several mortars late. Fable's build order: weighted defence, siege tiers, heists.
- **Weighted defence (built).** A target's defence is the sum of its turrets' weights within 30 tiles (`ops.weigh`):
  gun 1, laser 1.5, flamethrower 2.5, artillery 0, each times (1 + its force's ammo damage modifier for bullets,
  lasers or flamethrowers); `needed(d) = ceil(3.5d) + 4`. Units count at the staging look only (they move): characters
  and units 0.5, cars and tanks 1.5, spidertrons 3, within 40 tiles, remembered 5 minutes; the turn-back test and the
  next sizing include them. Grubstake's soft-only temper still reads turrets alone. Scenario `weigh`: three guns need
  19, three flamethrowers 42, guns with bullet damage +0.7 need 30; a spidertron parked at an undefended relay turns
  a forced raid back unhurt ("defence 0.0 and units 3.0, needs 19, has 4").
  Calibration: the force per unit of defence went back from 5 to 3. Five had been set against three creeping gun
  turrets with bullet damage +0.8 (`defend`): with research now in the weight (x1.8) it counted twice, and the
  raid needed 31. At 3 it needs 21, and self-defence (a battery, or a static threat on the settlement's ground:
  turret creep) now takes the reserve too (a garrison of 28 kept 9 home and fielded 19). Measured: 21 sent, the
  three turrets destroyed, 7 back, the losses that set the old calibration. `weigh` expected 13, 27 and 20; at 3.5 (below) 15, 31 and 22.
- **Siege tiers (built).** A siege's tier is the corporation's level, held to the target player's era + 1, one up for
  a grudge, then down to what its parts and field afford (`SIEGE_TIERS`): 1 mortar, 30 shells, 6 guards, 100
  parts; 2 mortars x 40, 10 guards, 220, a convoy; 3 x 40, 16 guards, 400, a convoy, an assault; 4 x 30, 24 guards,
  600, a convoy. At most 160 shells a siege and one siege against a player force at a time across corporations (a
  battery excepted). **Resupply:** when the first mortar is spent and a turret is still in reach, a hauler sets out
  with 40 shells for the spent mortars; a dead convoy ends resupply. **Moving up** (two mortars and more, once):
  nothing in reach for 30 s with shells left, the mortars pack and the hauler carries them to a new site in reach of
  what still stands (two mortars had spent 12 of 80 shells on the near side of a square and packed up).
  **Assault** (tier 3 and up): after that, nothing in reach for 30 s, the guards and what the garrison can add,
  sized to the target's remaining defence, attack from the site (a phase of the same operation, so it counts once
  against the budget); it ends when nothing is left within 16 tiles, after 90 s without a kill, or at half strength.
  A tank sally still kills a mortar in seconds. Scenario `siegetier` (four variants, quick regression), on bombard's
  walled square of 8 gun turrets, forced with `/lp siege` (weighted, those 8 turrets now need a raid of 28, which a
  grown garrison affords, so it raids instead): tier 2 two mortars, the player rebuilding turrets, a convoy
  resupplies; tier 3 three mortars, then the assault razes; a sally of two battle tanks kills a tier-1 mortar and
  the siege aborts; a killed convoy, nothing more loaded (80).
- **Open, found while calibrating (`defend`).** Three gun turrets with bullet damage +0.8 and shooting speed +0.6:
  at 3 a unit of defence the raid of 21 won once and lost once, at 3.5 the raid of 23 lost (seven back) and the
  outpost's own turrets finished the creep. With shooting speed in the weight (x2.88, true firepower) they need 35,
  more than the garrison, and the siege that follows sends its hauler to a site inside the settlement's own walls,
  where it never deploys. Weight kept on damage alone, 3.5 a unit, until corporation research (the user's idea, next)
  lets the corporation's units answer the player's research instead of raids growing without bound.
- **Placement makes way.** A building the settlement plans packs up a drop turret standing where it goes and moves
  its own units aside (the corner turrets had made the pad's walls, turrets and flamer be skipped for good). Three pad
  walls are still skipped on seed 12345, blocked by the settlement's own pylons: a layout overlap, older than this.
- **Heists**: next (see the consult).

### Corporate research (the user's idea; Fable: `docs/reviews/2026-10-14-corporate-rd-consult.md`)
The user (2026-10-14): "Corporations should probably also be able to invest in their own tech trees to better answer
the threats they face. A sort of 'smart' parallel to biter evolution. This makes it so we don't need 100x sized raids
if their units are upgraded also." `scripts/rd.lua`.
- **Fund and ledger (built).** 30% of each corporation's exports go to a research fund (capped at 10,000), apart from
  the level the exports raise. The ledger: its units lost in the last 30 minutes by the damage the killer deals
  (gun turrets, characters, cars and troopers physical; lasers laser; flamethrowers fire; artillery, breachers and
  battle tanks explosion; biters not counted), and raids turned back for want of force.
- **Weapons (built).** Every 10 minutes a corporation buys at most one level of damage (+20% each, 400 x k parts for
  level k, at most 5) for the ammunition its units fire, its main category first (Serenity: small arms, then cannons,
  then rockets; Grubstake: small arms), on its force (units and turrets alike), never beyond the player's era + 1;
  a withdrawing corporation buys nothing. Announced (`lp.rd-weapons`). Scenario `techup` (two): a fund of 20,000 and
  choices every minute: small arms to level 5 in six minutes, the raid against three upgraded guns from 23 to 14; an
  era-0 player holds it to level 1.
- **Sizing.** The defence it reads is divided by its strength, 1 + its damage modifier for its main category: a
  researched army sends a raid a garrison can field.
- **Weight now includes shooting speed** (true firepower: damage x rate). In `defend` three gun turrets with bullet
  damage +0.8 and speed +0.6 kill about 15 units whatever the raid (21, 23 and 26 sent, each lost); weighted 8.6 they
  need 34, beyond a garrison of 28, until research. Measured: with the fund from exports, small arms level 2 at
  minute 40, then a raid of 26 (defence read 6.2): it lost, 18 dead in ten seconds. Damage does not keep infantry
  alive: the plate (next) is the answer, and `defend` fails until it is built and the force per unit recalibrated
  from measured losses (Fable's step 4). `defend` and `assault` now declare era 2 (their player's upgrades are set
  directly and count no research).
- **Measured against `defend`'s three gun turrets (bullet damage +0.8, speed +0.6, weighted 8.6).** From nothing the
  loop answered slowly: small arms 1 at minute 30, 2 at minute 40, a raid of 26 that lost (18 dead in ten seconds),
  the physical plate at minute 70 (its fund is 30% of exports). Given a history to match its opponent (small arms 2,
  armoured infantry, as `defend` now sets), it read the defence as 4.4 and sent 20: it lost 14 and turned back, about
  what every unresearched raid of 21 to 26 lost there. The strength credit overstates research: these turrets kill
  about fifteen infantry before they fall, plated or not, and a raid must keep half to finish (the abort rule), so it
  needs about 30 whatever its research, beyond a garrison of 28. `defend` passes because the outpost's own turrets
  finish the creep. Next: composition (tanks, not infantry, at turret clusters), then the force per unit and the
  strength credit recalibrated from campaign losses (Fable's step 4).
- **Plates (built).** A plated prototype for every corporation, unit kind (infantry, tank, walker, harrier, buggy) and
  plate (`plates.lua`, 30 prototypes, named "<unit>-<plate>"; `shared.kind_of` strips it): +15% health and its
  resistance, armoured (physical +25% and 2), fireproofed (fire +70%), reflective (laser +40%). No explosion plate:
  artillery and battle tanks stay the player's trump. Bought (1,500 parts, 1,000 to switch one, from the player's
  era 1) when ten or more of its units died in the window and one damage type killed half of them, for the kind
  that died most; unless two raids turned back for want of force, which buys weapons. The depots and the drop escort
  build the plated kind from then on (`rd.unit`); units already out keep what they have. Announced (`lp.rd-plate`:
  "now fields reflective infantry"). A plate answering what a target's turrets mostly deal (`ops.weigh` returns it)
  makes the corporation read that defence 1.4 times weaker, any plate 1.15. Scenario `plate`: fifteen infantry die
  to a laser turret; the laser plate for infantry is bought; 8 reflective infantry built; the 4 plain ones kept.

### Identity trees (the user; Fable: `docs/reviews/2026-10-14-identity-trees-consult.md`)
The user, on the generic research: "Do we have interesting research? With actual faction identity? Do the troopers
differentiate between factions? I was thinking range, rate of fire, even main weapon (Grubstake could use shotguns,
Serenity could have some special 'laser troopers'... and climb their tech tree up to tesla shock troops..)". The
generic weapons and plates become each corporation's own named nodes (the fund, ledger, era cap and sizing stay).
Serenity, "the line": Line troopers (beams); Optics (Lance, then Shock troops: chain lightning), Line (Warden, Aegis
tank), Siege (Hardened siege, Counter-battery). Grubstake, "resources in the right hands": Shotgun hands; Scrap arms
(Slug buggy, then **dynamite sappers**: the user chose them over Fable's flamethrower Burner, which borrowed
Serenity's flame), Wheels (Scavenger harriers, the Dozer), Loot (Salvage rights, Prospector's eye). The ledger picks
the node that answers what has been killing it. Raids to differ on arrival too (Serenity destroys military targets
and withdraws in order; Grubstake empties chests first: the user's heists, folded into its identity).
- **Slice 1, starting infantry (built).** Serenity's **Line trooper** (`lp-infantry`): a laser beam (the laser turret's,
  scaled to about 7 a shot), every 25 ticks, range 15, ammunition category laser (its research covers its laser
  turrets too), laser 20% resisted. Grubstake's **Shotgun hand** (`lp-grubstake-infantry`, built from `lp-shotgun-hand`
  through its CORPS.bases): four pellets of 4 (`lp-pellet`), every 30 ticks, range 9, speed 0.13. Pellets pass
  through their own side (`force_condition = "not-same"`: by default they hit everything, and six Shotgun hands lost
  555 of 720 health to each other). Research follows the weapons (`rd.CORP_CATEGORY`: Serenity's main category is now
  laser, Grubstake's shotgun shells). Scenario `arms`: six of each against four radars, 780 and 630 ticks (within 20%:
  eight pellets took 420, five 540), no wounds to their own side.

- **Slice 2, the tree engine (built).** Each corporation's tree is a table in `shared.CORPS[corp].tree`: track nodes
  (damage for its ammunition categories, a level at a time, 400 x k parts, +20% each, at most the player's era + 1)
  and plate nodes (plates on unit kinds, from an era), each with a trigger on the ledger (`{damage = d, min = n}`:
  n of its units killed by damage d in 30 minutes; `{turned_back = n}`). The node whose trigger fires hardest wins,
  tree order breaking ties; with none, its first track climbs; a winner it cannot afford is saved for (nothing else
  bought meanwhile). Announced per node in its voice (`lp.node-<id>`). First nodes, the generic system renamed and
  divided: Serenity **Optics** (lasers and electric) and **Warden armour** (physical, Line troopers); Grubstake
  **Hand-loads** (shotgun shells and bullets), **Scrap plating** (physical) and **Asbestos suits** (fire), both on
  Shotgun hands and buggies. Each answers only with its own: Serenity has no fire or laser plate. Scenario `plate`
  (two): fifteen Line troopers killed by a gun turret, Warden armour, 8 armoured troopers built, the 4 standing kept;
  fifteen Shotgun hands and buggies killed by a flamethrower, asbestos suits, 12 fireproofed built, 15 standing kept.

- **Slice 3, the first tree units (built).** A unit node adds a unit to its corporation's mix (`army` mix reads
  `rd.mix`), its trigger on the killers in the ledger (now kept per loss: a character, a vehicle, else the killer's
  kind). Serenity's **Lance** (Optics, era 1, 900 parts): a heavier, slower beam, 12 laser every 45 ticks, range 17
  (beyond the player's troopers, inside a gun turret), 110 health; bought on six losses to troopers, breachers or
  the character. Grubstake's **Slug buggy** (Scrap arms, era 1, 900): three slugs of 14 every 40 ticks, range 12, 240
  health, shotgun shells (its Hand-loads cover it); bought on five losses to vehicles or battle tanks. Both are unit
  kinds, so each corporation also gets an unused copy of the other's (harmless). Scenario `unitnode` (two): eight
  Line troopers killed by a trooper, Lances bought and built; six buggies killed by a tank, Slug buggies built.
- **Chain lightning works in the base game** (spike, 2026-10-14, deleted after): a `chain-active-trigger` on the
  destroyer's electric beam (no Space Age), started by a nested `chain` delivery placed before the unit's own beam (as
  Space Age's tesla turret does), jumped from one player car to the next through all five (3 tiles apart, 4 jumps
  allowed, 20 damage each) and left the shooter's own car beside them untouched. Shock troops can be built.
  Dynamite sappers need no spike: the player's breacher already throws enemies-only charges.

- **Slice 4, area weapons (built).** Serenity's **Shock trooper** (Optics, era 3, after Lances, 2,500 parts): an
  electric beam that arcs on to the next target (`lp-arc-chain`, 4 jumps of up to 6 tiles, the destroyer's beam), a
  brief stun on the one it hits (`electric-mini-stun`), 12 electric every 45 ticks, range 12, 160 health, electric
  50% resisted; bought on twelve losses to troopers, breachers or the character. Grubstake's **Dynamite sapper**
  (Scrap arms, era 2, 1,500): a Shotgun hand's body throwing dynamite, 80 explosion over 3 tiles, enemies only (the
  breacher's charge), from 11 tiles every 3 seconds; bought on ten losses to troopers. Nodes may require another
  (`requires`). Scenario `arc`: one Shock trooper hit all five player cars and spared its own car beside them; one
  sapper hurt all four walls of a block and spared its own fence. `unitnode` (four variants): each unit node bought
  on its killers and built by the depots. Found on the way: a node set outright for a test must take effect as bought
  (Lances marked researched but absent from the mix were bought again, and Shock troopers were saved for).

- **Slice 5, abilities and looting (built).** Ability nodes change how a corporation operates (`rd.has`):
  Grubstake's **Salvage rights** (Loot, era 1, 800; on two raids turned back): each player building its units raze
  pays 10 + 5 x its value into its fund. **Prospector's eye** (Loot, era 2, after Salvage, 1,000; three turned back):
  its raids leave at 70% strength, not half (cowardice as doctrine), and its strip camps look for ore 68 tiles from
  the player's drill, not 45. Serenity's **Hardened siege** (Siege, era 2, 1,200; on five explosion losses): the
  mortar site digs in, a ring of wall open towards home and two gun pillboxes, cleared when the siege ends. The damage
  tracks now only climb (no trigger), so the abilities take "turned back". **Looting** (Grubstake's temper, the
  user's heists folded into its identity): a raid at its target first empties the player's chests within 16 tiles
  that one of its units stands by, valuable items first (processing units 8, modules 10 to 40, U-235 20...), up to
  400 items; survivors carry it home as parts, none and it is lost; a custom alert (`lp.alert-loot`). Scenario
  `ability` (three): a raid on an assembler beside a chest of 100 processing units took all 100 home, razed both,
  and paid 35 into the fund; a hardened siege dug in with 32 pieces and cleared them after; ore 55 tiles out was out
  of reach without the eye and stripped with it.

- **Slice 6, the trees complete (built).** Serenity's **Aegis tank** (Line, after Warden, era 2, 2,000): the tank hull
  with a laser cannon, 45 laser every 60 ticks, 1,100 health, physical 30% and 5, explosion 40%; on five losses to
  vehicles or battle tanks. **Counter-battery** (Siege, after Hardened siege, era 3, 1,000): a siege at the player's
  artillery takes up to six Shock troopers as its first guards; on three losses to artillery. Grubstake's **Scavenger
  harrier** (Wheels, era 2, 1,800): a harrier with rockets, 18 explosion every 40 ticks, range 14, 180 health; on
  five explosion losses. **Dozer** (Wheels, after Slug buggies, era 3, 2,500): the hauler's hull, 1,800 health,
  physical 40% and 5, a ram of 60 at 2 tiles; on two raids that met walls (a raid that attacked, razed nothing and
  had walls within 20 tiles of its target: the ledger's new `walls_met`). Scenario `unitnode` is now a table, one
  row a node (eight); each node bought on its trigger and its unit built.

| Threat | Serenity answers | Grubstake answers |
|---|---|---|
| Gun turrets (physical) | Warden armour | Scrap plating, or strips elsewhere |
| Flamethrowers (fire) | (nothing of its own: it holds its line) | Asbestos suits |
| Massed troopers | Lances, then Shock troopers | Dynamite sappers |
| Vehicles and battle tanks | Aegis tanks | Slug buggies |
| Artillery | Hardened siege, then Counter-battery | Scavenger harriers |
| Walls | sieges (mortars, tiers) | Dozers, harriers over them |
| Raids turned back | its Optics climb | Salvage rights, then Prospector's eye |

- **Sneaking and breaching (built; the user: "do they try to avoid turrets? And perhaps make holes in undefended
  sections of the wall?").** Grubstake's temper (`sneaks`): a raid marches to its staging point and then to the target
  along a route planned on a 6-tile grid (A*) round every cell within a known turret's reach (gun 18, laser 24,
  flamethrower 30, plus 3) and water, exposed only in the last 16 tiles; it fights only what hits it on the way (it
  had engaged on sight, walked into five lasers on the march and lost 25 of 31 before attacking). Walls within 30
  tiles of the target: it breaches the wall piece the fewest turrets reach, with its neighbour, then goes through.
  Serenity keeps its straight approach. Scenario `sneak`: an assembler in a 40-tile wall square, five powered lasers
  on the near side and flanks: the raid took 6 waypoints round them, breached the far wall (no laser reaches it),
  razed the target, 15 of 31 lost; `sneak direct` (sneaking off), 25 lost. Shotgun hands barely scratch stone walls:
  the breach was given up after 3 minutes and the raid went in anyway; breaching is the sappers' and the Dozer's work.
  `scripts/play-visit.sh` opens a copy of a visited save in a window with the mod, to watch (and drive with `/lp`).

### Cost with six settlements (2026-10-14)
`six` lands the corporations' caps (three each, 900 tiles apart, parts granted) and `scripts/profile.sh six 12345 40`
benchmarks it: mean script 0.07 ms a tick over 40 minutes (campaign.md's budget: 1 ms), 158 ticks over 5 ms,
8 over 16 ms. The stutters were the landings: 0.4 to 1.4 s each, from generating the site search's area round
up to eight ring points. The search now reads ore from the map generator's noise (`calculate_tile_properties`,
every 8 tiles: about 2 ms, and in a spike it matched the generated ore point for point), generates only each
candidate's ground (5x5 chunks, for nests and the ore count) and the settlement's reach (15x15, as before: queued
instead of forced, the planner laid out other outposts and three scenarios failed). Same six sites; landings
0.28 to 0.56 s. A landing comes once an hour or so; making it asynchronous (land when the chunks are ready) is the
remaining fix if it shows in play. Ore the player mined out is checked in generated chunks.

## Design review 2026-10-13
Fable's review on the user's agenda, in full: `docs/reviews/2026-10-13-design-review.md`. Headlines, not yet
decided: the faction's military is the biter attack-group loop with a cooldown (nearest target, no sizing,
no abort, no memory); it needs intel, objectives by value, sizing, staging and abort rules. Garrisons need
roles (reserve, reaction, field); alarms need escalation; pickets should see. Control radius on relays and
barracks (cores stay the barracks key), a satellite lifting the radius, faction jammers as the ground answer;
satellites as targets judged scope creep. Tier as capability, not +15% damage. The landing as a contestable
event. The loop needs the settlement readable in game. Park the uplink fight and rival corporations.
Decisions: see "Operations" above.

## Open questions and next
- **Rival corporations (idea, user 2026-10-13, for later):** several landing parties at once, each a
  corporation with a humorous dystopian name, at war with each other as well as the player, for the same
  resources (in the spirit of Borderlands or Cyberpunk, but not childish). Each its own architecture,
  units, defences and strategy: the doctrines and archetypes are the start of that. Questions: do they
  fight each other on sight or only over ore; can the player play them off; one uplink each or a shared
  one.
- The uplink: whether the third landing is right, whether its fall should also wind the settlements down,
  shields on its rings, and a fortress that varies (it is one fixed template now).
- The player's army and rally beacons; capture by holding a node.
- Shields (`destructible = false` while powered), jammers, gates in wall openings, an anti-air turret.
- Depletion and relocation; the second wall ring.
- Response sizing; tier and export tuning at real clocks.
- Biter interplay: settlements emit no pollution, so biters ignore them unless they do.
- In game, 2026-10-13 (showcase save): patrols "extremely cool"; troopers made biter noises (fixed:
  machine units carry weapon sounds and no growls); the beacon with a separate combinator did not read as
  an order (A reached nothing near a beacon at spawn; moving the beacon dropped the wire): now the beacon is
  the combinator and its reach is drawn. Architecture not yet seen properly (Editor Extensions added to the
  play profile).

## Testing: headless first
The user's time in game is the scarce resource; a headless run costs none. Every mechanic gets a scripted
scenario with assertions first; the window is for art, feel and GUI.
- `scripts/sim.sh <scenario> [seed] [minutes] [every] [strike]`: one run in its own profile, base game
  only, no biters; plots, the planner's `decisions.txt`, results, and for some scenarios a replay GIF or an
  overview map, in `docs/sim/<scenario>-<seed>/`. `LP_FAST`, `LP_DOCTRINE`, `LP_TAG` adjust a run.
- `scripts/batch.sh`: several runs, one table of metrics; 3 at a time by default (eight at once took six
  times as long each). Batches confirm what works; single short runs find what does not.
- `scripts/profile.sh`: per-tick engine timings; profile before blaming code.
- **Run time.** A siege run took 2.5 minutes: 15 s of game, the rest rendering its animation. The life
  GIF is now on request (`LP_GIF=1`; positions are always kept). `scripts/fork.sh <scenario> <seed>
  <strike>` grows a scenario to its strike once (headless server, fast, saved a second before the strike;
  saved a tick before, the loaded game never ran the strike) and `LP_FORK=1 scripts/sim.sh ...` runs only
  what follows: 19 s a siege run. A fork holds the settlement as the code grew it then: iterate on forks,
  confirm with full runs.
- Scenarios added: `fall` (a lander destroyed with a second settlement standing); `contact` (first contact
  at real clocks, a timeline: `scripts/timeline.py` writes timeline.png and timeline.md).
- **Quick regression** (user 2026-10-13: "regressions are super long; do we need to run them this often?"):
  `scripts/regress.sh` runs 13 scenarios in about 3 minutes, those that strike from forks saved 6 minutes
  before the strike (raid measures the minutes before it) and keyed by the code that runs before a strike;
  `--full` adds the long growth scenarios for milestones. The full batch took about 10 minutes for 8.
- `scripts/showcase.sh [seed] [minute]`: a save to look at in game, built with no clicks: the `showcase`
  scenario on a headless server (fast, back to normal speed before `server_save`), copied to the play
  profile (base, Landing Party, Editor Extensions and flib copied from the real profile).
  `scripts/play-showcase.sh` opens it (from a folder with `steam_appid.txt`, so Steam does not relaunch).
- **Dev tools** (user 2026-10-14: "dev tools to force raids and sieges instead of preparing saves that rely on
  randomness"): `/lp` in game (admins; `scripts/dev.lua`). `list` shows every settlement (id, where, garrison,
  parts, operation, perimeter, hull); `raid`, `siege`, `strip [id]` launch that operation now at your structure
  nearest you (`ops.force`: temper, threat budget, cadence and stock waived; a depot, parts and the infantry it
  lacks are given; otherwise the operation runs as a real one); `perimeter [id]` steps Serenity's line;
  `land <corp> [tiles]` is the real arrival at that distance; `parts`, `fast` (short clocks for perimeter,
  strip camps, phases and HQ), `provoke`, `era`, `trace`. The remote `dev(args, pos)` is the same for a player
  that need not exist; scenario `dev` (quick regression) drives each.
  `LP_MIX=tour scripts/showcase.sh 12345 20` then `scripts/play-showcase.sh tour`: both corporations grown, your
  army, an outpost with a turret by Serenity, drills on iron by Grubstake, an empty artillery turret within reach
  of Serenity's lander with shells beside it; raids on from the save.
- **Real factories** (the user, 2026-10-14: "a save game ... to test a real player factory against our rival
  factions"): `scripts/visit.sh <save.zip> [minutes]` copies the save into its own profile (`factorio-lp-visit/<name>`,
  never a real profile; it refuses one), benchmarks it as it is (base, Space Age, Quality, Elevated Rails), then
  adds Landing Party and the test mod (scenario `visit`) and runs it at real clocks: Serenity lands past the
  factory's 95th-percentile building plus 150, Grubstake 20 minutes later, the faction's own cadence (and the save's
  rocket launches) bring more; a timeline every 10 minutes and each settlement's story at the end, in
  `docs/sim/visit-<name>/`. No live player: the factory's turrets and robots are all that answer. Mods the save used
  beyond those four are left out (their state drops from the copy). The test mod counts ticks from the tick it was
  added (`storage.t0`): scheduled by absolute tick, nothing ran in a save hours old.
  First save (the user's own `nwa`, April 2026): 210 technologies, 2,302 laser turrets, 278 flamethrowers, 59
  artillery turrets, 17,744 walls, 1,379 roboports, 95% of its buildings within 1,600 tiles. Ten minutes: 2.07 ms a
  tick alone, 2.23 with the mod; its own rocket launches brought a second Serenity landing.
  First three-hour visit (nwa): the faction's own landings (brought forward by the save's rocket launches) used their
  default 350 tiles from spawn and came down inside the 1,600-tile factory; the site rules only refused turrets and
  units within 100 tiles and artillery within 300, so the open ground between its lasers counted as clear, and
  artillery range research (210 technologies) outranged 300. Eleven Grubstake landings died within 25 seconds;
  Serenity's first settlement lived (garrison 169, Optics maxed), its five sieges at the player's artillery all
  intercepted (defence read 687 at one battery). Fixed: no landing within 150 tiles of the player's buildings, the
  artillery margin times the force's range research, and rings tried out to 1,800 tiles. In game the user found the
  rest: "a single biter will even clear out turrets and 10 units with vehicles", at maximum evolution. The
  corporations are built for an early or middle world (next).
- **Late worlds (the user, in game on nwa: "a single biter will even clear out turrets and 10 units with vehicles";
  "evolution is maxed out. It's a late game factory").** The corporations were built for an early or middle world:
  infantry of 120 health doing 4 to 7 a hit, against big biters (375, 8 flat armour) and behemoths (3,000, 12 flat);
  a pellet of 4 did about 0.45 to a medium biter. Built: biters count in the research ledger (jaws physical, spitters
  and worms acid; killer "biter"); a corporation's first landing arrives with history (a fund of 1,500 a player era
  and 4,000 at full evolution, spent at once on its track to the era cap and, past half evolution, its physical
  armour: `rd.history`); the drop escort grows by up to 10 with evolution; landings keep 60 + 140 x evolution tiles
  from spawners; Grubstake's pellets are three of 9 every 55 ticks (parity with the beam held, 660 to 780 ticks);
  a camp's escort answers from the lander; an outpost attacked earns a turret pair whatever the doctrine (Grubstake's
  sprawl never built any); losses are traced with their killer's force. Scenarios `biters` (two: an attacked outpost
  rebuilt with its turret pair; a camp kills two medium biters) and `maxevo` (evolution 1, era 4: with history,
  Hand-loads 5, Scrap plating and 16 escorts, the camp killed two big biters and a behemoth; without, `bare`, they
  destroyed its lander). The second visit (site fix only, before these): every landing outside the factory now, and
  every one fell in maximum-evolution biter country.
- **Biter country (the user: "raids and sieges will also need to cross biter country to reach us sometimes").** Every
  corporation's marches route round spawners (30 tiles) and worms (50) on the route planner (Grubstake also round
  turret reach): the march to staging, the attack leg and the way home; staging points keep 50 tiles from nests; a
  siege or strip camp that finds no way round is not sent (its parts given back), nor a raid (the target cools). A
  nest as the target (Serenity clearing its ground) is excepted. Scenario `country`: three spawners and a worm on the
  line to an undefended assembler: the raid's route kept 65 tiles from them, it razed the target, and lost nothing
  (before: 4 of 4 dead, first through the nests to the target, then on the straight way home).
  Third visit (nwa, everything in): Serenity's first settlement lived the three hours (arrived with Optics 5 and Warden
  at era 4, evolution 0.99; mined 160,697, made 32,035 parts), at war with the biters throughout (4,558 of its
  buildings destroyed by them, rebuilt; its raids on nests in its claim aborted); a second Serenity landing fell;
  Grubstake found no site (200 tiles from every spawner at full evolution, 150 from the factory, out of artillery
  reach: nowhere on rings to 1,800 tiles). No operation went against the player (Serenity unprovoked).
- **Fourth visit (nwa; clearing landings, research history, biter routing): plain and provoked identical.** Both
  corporations now land and live (Grubstake: 3 of 4 settlements standing at the end, Hand-loads 5, Salvage rights,
  Scrap plating; Serenity: 5 of 8), at war with the biters (5,227 of their buildings destroyed) and each other, never
  with the player: no building of its was destroyed in three hours, provoked at the hour or not. Grubstake's temper
  finds nothing soft at a factory whose every edge is under upgraded lasers; Serenity, provoked, can afford no raid
  against them; most operations were "no way round biter country". Script 2.98 -> 3.10 ms a tick (a loaded machine).
  Not acceptable (the user): the principle above; a consult with Fable on pressure against a megabase (next).
- **Landings burn a clearing (the user: "a landing could significantly damage/destroy nests and biters in a radius").**
  Spawners, worms and biters within 80 tiles of a new lander are destroyed, the corporation's kills (their evolution
  refunded), with explosions, and the player told (`lp.landing-cleared`). Sites keep 60 + 40 x evolution tiles from
  spawners; when no ring has one, a second pass allows nests (the lander clears them). Scenario `clearing`: spawners
  every 70 tiles at evolution 1, one ring allowed: Grubstake landed on the second pass, cleared 4, none left within 80,
  evolution unmoved. The visit forces Grubstake again at 30 minutes if none stands, and `LP_MIX=provoked` provokes both
  corporations at the hour.
- **Pads in each corporation's shape (the user: "the landing sites could perhaps vary a little more between factions.
  Right now it's rectangles for everyone").** Laid at landing (a camp's pad had been bare ground until maturity):
  Serenity's landing ring, an octagon of its floor inside a ring of its trim, the rectangle's corners bare; Grubstake's
  drop site, ragged patches of its floor broken by a tile hash, scraps of hazard stripe. The block stays a rectangle
  for the planner. Scenario `pads` draws both as text.
- **Recoloured sprites (the user: "more refined recolored sprites. Like we did in empirical science ... instead of just
  tinting the full thing"; "the lander should also get a nicer recolor"; "you threw out the bicolor idea for
  Serenity?").** `scripts/make_sprites.py --write` writes each corporation's own files (216, about 37 MB) and
  `graphics/manifest.lua`; `corps.lua` points each corporation's buildings at them and drops their whole-sprite tint.
  The user chose a mixed treatment: Serenity's steel colourised at its own luminance (highlights and shadows kept),
  slate-teal machines and charcoal defences (walls, turrets, poles, lamps, gates darkened to 55%); Grubstake's rusty
  body under a warm wash with its blue paint repainted amber; the lander (the crash site's spaceship) has its yellow
  paint repainted, slate-teal or a deeper amber. Units keep their art: only the engine's colour masks (the character's,
  tank's and car's player-colour layers) take the corporation's colour; a sprite without masks (the harrier) is tinted
  whole. Review sheets go to the user before anything is wired.
- Also: a container its raiders destroy is looted from the wreck (the raid razed the chest before its looting step came
  round); a breach is chosen by turret reach plus 6 tiles of crowd room (sneak: target razed, 17 of 31 lost: marginal).
- **The ladder (built; the megabase consult, `docs/reviews/2026-10-14-megabase-pressure-consult.md`).** Minutes since a
  corporation last razed a building of a player force (`storage.last_raze`, any cause), from first sight: at 20 soft
  relaxes (Grubstake goes for weighted defence up to 3) and Serenity's targets on that player weigh triple; at 40
  operations push through biter country; at 60 cost no object (the target with the best value for its defence gets the
  whole garrison, reserve included, and does not turn back). Razes are tallied by type (remote `pressure`, the visit's
  timeline). Scenario `ladder` (two, ten times fast): a provoked Serenity facing six lasers it could not afford sent
  what it had at the top rung and razed 14 (six lasers among them); Grubstake held off a turreted assembler and razed
  it at the top rung (relaxing soft alone did not bring it there).
- **Pushing through biter country (built, not yet effective).** With no way round (the whole way: the attack leg as
  well as the march), a raid goes anyway when its target is worth 6 (line and ladder counted) or the ladder is on its
  second rung, through at most 6 nests, with an escort of 4 a spawner and 2 a worm times (1 + evolution); hauled
  operations likewise. More nests: a clearing raid on the nearest spawner first. At the top rung: through whatever is
  there, with all it has. A raid not sent cools 2 minutes, not 10 (it was never tried again). Scenario `push` (not in
  the regression): a wall of 22 spawners and 22 worms across the way (unevolved biters): not sent, then a clearing
  that the young garrison could not field (the nest's worms need 18), then at the top rung 27 units pushed through
  and 26 died in the wall. Corporation units do not get through dense nests; a Serenity raid on one spawner lost all
  18. Open: what a corporation fields against nests (the identity trees have nothing against biters as such).
- **Grubstake against a megabase (built: exposure, the Cut, the wagon heist).** Its soft is exposure: the weighted
  turrets whose own reach covers the target (gun 20, laser 26, flamethrower 32), up to 1.0, 3.0 once the ladder relaxes
  it, anything at the top rung; a megabase's rails, big poles and far substations sit just beyond its turrets and had all
  counted as defended (any turret within 30 tiles). Rails and signals are line targets (worth double), so a raid on them
  is the Cut; looting takes cargo wagons within 16 tiles, and their wrecks. Scenario `heist`: an outpost station with a
  laser 40 tiles off: four raiders took the station, emptied the wagon (400 copper plate home) and cut the line (25 rail
  pieces to 3). Once the ladder reaches its second rung against a player force, that player's targets come before rivals
  and nests (weight 0.2 on the others): on the user's save a rival lander, worth 8, was always chosen first, and the top
  rung now overrides Grubstake's soft as well (every exposed spot at the megabase was over 3).
- `scripts/sheet.py`, `scripts/replay.py`, `scripts/overview.py`: variety sheet, raid replay, faction map.
- Scenarios (`tests/lp-sim/control.lua`): grow, cut, raid, occupy, assault, defend, faction, uplink, army,
  caps, lively, convoy, train, orders, siege, duel, showcase, and the spikes air, path, cost, probe. Each
  needs its own length: a regression at 30 minutes with the strike at 10 failed raid, occupy, defend and
  faction for lack of time (all pass at 60/30). A run that ends before its scenario's checks fails, and each scenario
  states how long it needs after its strike.

## Engine notes
- Pathfinding is the engine's (the biters' pathfinder): units route around whatever their collision mask
  hits; with no way round, ground units shoot through; groups arrive as blobs; spider-units step over;
  air units fly straight. Long trips go in ~100-tile legs.
- An idle unit attacks any enemy in sight: give units a lasting order (arrive, then wander in place).
- Commands: `wander` takes no destination and lasts forever by default (`ticks_to_wait`).
- Player turrets fire only at military targets (`is_military_target`): ordinary enemy buildings are ignored.
- `auto_connect` on a scripted pylon does not reliably rejoin a cut line: wire explicitly
  (`get_wire_connector(pole_copper).connect_to`).
- Air: a custom collision layer and trigger target type; `ignore_target_mask` on turrets that cannot shoot
  up (turrets attack all masks by default); mines trigger on building layers only.
- Ground units shoot through what blocks their path: walls delay them, never stop them.
- Flamethrowers fire only within their arc.
- A unit group arrives as a blob 10-30 tiles across and reports finished.
- Units are cheap: 1,000 wandering add 0.17 ms a tick.
- Assumed, not tested: spider-units cannot join unit groups (the army gives them the group's orders
  separately).
- `LuaEntity.disabled_by_script` replaces writing `active`; roboports ignore it (jammer fallback: kill
  construction robots in the field). `destructible = false` is the cheap shield.
- Biters attack polluters only. Entities cannot be placed in ungenerated chunks.
- Park-Miller's first draws from nearby seeds are nearly linear: scramble seeds, discard the first draws.

## Findings log
Bugs and surprises the headless runs caught, each kept as a check:
- Instant rebuilds made cutting a line meaningless (rebuild delay).
- The planner built new fabricators while old ones were owed, on spots the player held, and doubled them
  after a raid's stockpile (counts what it owes; follows flow, not stock; avoids held ground).
- Rebuilt line pylons joined nothing (explicit wiring).
- One landing site per direction found no ore at 300 tiles (band search, further rings, best-seen
  fallback); walls bought before the first fabricator starved a settlement.
- Tanks immune to yellow ammo; tanks outranging turrets over walls (armour and range rules).
- Player turrets ignored faction buildings (military targets), then a blanket fix made production a target
  too, which capture cannot live with: only what fights or commands is military now.
- Planning ticks of 5.5 ms (cached ore cells): worst now 1.5 ms.
- Settlements matured at two blocks (idle plans counted waiting for parts).
- The third landing failed silently every 10 s: two settlements blocked their neighbouring directions and
  the rest were barren at 350 tiles (further rings, failures logged).
- The fortress template put a turret twice on every ring corner and two generators among turrets (a check
  now requires every planned fortress entity built); a construction burst meant for the fortress sped up the
  whole settlement (12 blocks in 11 minutes; now fortress jobs only).
- Test mistakes, now guarded: radii too tight for a blob or a drifting harrier; a flamethrower facing away;
  runs too short for their checks; a defend test that passed without damage.
- Measurement mistakes: parallel load read as mod cost (profile alone); smoothed rates aliasing against
  crafting cycles (count over a window).
- Haulers sent to the uplink in the fortress's inner yard circled the outer ring (dock at the gate).
- Convoy escorts strayed (seen by the user in the animation). Same waypoints as the hauler: they ran ahead.
  One engine unit group: stuck escorts were dropped and the hauler went on alone (486 tiles apart); escorts
  drafted from the last convoy were still at the uplink. Now script-kept discipline (formation, flank
  stations, halts, release), a hauler slower than its escorts, and a check on the spread.
- The army test "regressed" after a planner fix: the settlement grew differently, the test's base landed in
  a lake and its flattening made an island no path left. Base placement now avoids water. Found with six
  full 3-minute probes in a row; a fork made each 15-40 s (fork first when a probe repeats).
- A regression "hung": the simulations had finished, the animation renderer redrew a whole settlement for
  each of ~1,750 frames (now drawn once, at most 240 frames: 83 s for a 60-minute run).
- Tests that read too little: a train check blind to a wagon at 49 of 600 health; a barracks destroyed by
  the faction's raids crashing the army test (now guarded, the mechanism test runs with the army off).
- Player army: an advance at the nearest military target walked troopers into a hub's lasers (occupy
  order); occupy re-chosen each time rolled outpost after outpost to the lander (lock); idle troopers
  attacked what they saw (arrive, then wander in place, fight back only).
