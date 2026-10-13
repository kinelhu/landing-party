# Landing Party: design

Living document, organised for design reviews: what is decided, what is built and how it was tested, what
is open. Prototype stage, Factorio 2.0 (2.1 is experimental only). Prefix `lp-`, mod folder `landing-party/`.
Numbers quoted here are the code's at the time of writing; the code is the authority.

## Status at a glance
| Area | State | Tested by (headless scenario) |
|---|---|---|
| Arrival on first launch, repeated landings, sites apart | built | `faction` |
| Settlement architecture: hubs, blocks, roads, walls, pickets, doctrines | built | `grow`, variety sheet |
| Economy: drills on real ore, fabricators, parts, power as the graph | built | `grow`, `cut` |
| Rebuild unless occupied | built | `raid`, `occupy` |
| Maturity, launch pad, exports, faction tier | built (first pass) | `faction` |
| Army: roster, depots, garrison, raids | built (first pass) | `assault` (with replay) |
| Response forces | built (first pass) | `defend` |
| Air units ignoring walls, mines, flamethrowers | built | `air` |
| Uplink (optional boss): fortress, landings stop and tier freezes when it falls | built (first pass) | `uplink` |
| Player army: barracks, troopers, rally beacons (hold, advance, occupy, retreat) | built (first pass) | `army` |
| Beacon as a combinator: own or wired signals, X/Y move the rally point, reach drawn | built | `orders` |
| Player units: trooper, breacher (charges for walls), battle tank (4 bandwidth); barracks picks its recipe | built | `siege` (`LP_MIX`) |
| Fought capture against live defences | in progress: no squad wins yet | `siege`, `duel` |
| Capture of mining outposts by holding | built | `army` |
| Command bandwidth: unit cap from relays and research, cores from the faction's wreckage | built | `caps` |
| Patrols through settlements | built | `lively` (life animation) |
| Convoys carrying exports to the uplink | built | `convoy` (life animation) |
| Interceptors against player trains | built | `train` |
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
  walled position; a mixed force should.
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
- **Selection tool** as the override, through ERM Unit Control (optional dependency) or our own minimal one.
- **Capture by holding**: a faction mining or power node with player units on its ground and none of the
  faction's for a minute becomes the player's (its drills mine for the player, its generators feed the
  player's grid). No capture by damage threshold (that is Proliferation's).
- **Circuits as the player's command language (direction, user 2026-10-13):** automate patrols and
  attacks with the circuit network rather than a selection tool. Built: stance and rally point by signal.
  Next candidates: the barracks reporting its troopers and orders as signals; a beacon reporting what its
  squad sees (enemies in reach, troopers alive), so a circuit can retreat a beaten squad or launch an
  attack when a squad is full.
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
- **A destroyed lander ends its settlement** (nothing runs on: no capture, no rebuild); what its remains
  become is open (ruins to salvage, capturable, or decay).
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
- `scripts/showcase.sh [seed] [minute]`: a save to look at in game, built with no clicks: the `showcase`
  scenario on a headless server (fast, back to normal speed before `server_save`), copied to the play
  profile (base, Landing Party, Editor Extensions and flib copied from the real profile).
  `scripts/play-showcase.sh` opens it (from a folder with `steam_appid.txt`, so Steam does not relaunch).
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
- A regression "hung": the simulations had finished, the animation renderer redrew a whole settlement for
  each of ~1,750 frames (now drawn once, at most 240 frames: 83 s for a 60-minute run).
- Tests that read too little: a train check blind to a wagon at 49 of 600 health; a barracks destroyed by
  the faction's raids crashing the army test (now guarded, the mechanism test runs with the army off).
- Player army: an advance at the nearest military target walked troopers into a hub's lasers (occupy
  order); occupy re-chosen each time rolled outpost after outpost to the lander (lock); idle troopers
  attacked what they saw (arrive, then wander in place, fight back only).
