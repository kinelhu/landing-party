# Landing Party: design

Living document, organised for design reviews: what is decided, what is built and how it was tested, what
is open. Prototype stage, Factorio 2.0 (2.1 is experimental only). Prefix `lp-`, mod folder `landing-party/`.
Numbers quoted here are the code's at the time of writing; the code is the authority.

**The campaign frame (proposed 2026-10-13): `docs/campaign.md`.** Rival corporations across a world, revealed
mid-game, scaling to the endgame, with biters in a three-way war and a player agent measuring the loop. This
document describes the parts as built; the campaign document describes the game they serve.


**Names (the user, 2026-10-21):** the corporations are shown as **Kessler-Hayashi** (internally `serenity`) and
**Grubstake Inc.** (`grubstake`). Code, forces, prototypes, saves and older documents keep the internal ids, and this
document still says Serenity where it records history.

## Status at a glance
| Area | State | Tested by (headless scenario) |
|---|---|---|
| Arrival on first launch, repeated landings, sites apart | built | `faction` |
| Opening: signs (radar), survey party (oil), arrival (launch or blue science) | built | `phases` (two) |
| Territory on the map (corporation colour, grows, grey after a fall) | built | `rivals` |
| Levers: strength and aggression per corporation (settings) | built, uncalibrated | `levers` |
| Answers by corporation: Grubstake a snatch raid where no turret covers (its flare retired 2026-10-22); Serenity, at war, answers trespass only (a siege), its losses fair war | built (trespass only 2026-10-20) | `snatch` (two), `line turret`, `crew answered`, `remembered` |
| Development per corporation (capabilities by level), threat budget with a floor | built | `budget`, `develop` |
| Biters: clean, evolution refund for corporations' kills, landings off nests, Serenity clears its nests | built | `evolution`, `nests` |
| Tempers: Serenity at war from landing (a truce bought at its invoice post the only quiet); Grubstake raids soft targets and strip-mines the player's ore, escalating when hurt | built (Serenity hostile 2026-10-19) | `temper`, `strip` |
| Serenity's line moves: its perimeter grows towards the player, a named warning a step ahead; it cuts belts on its edge where its guns stand | built (cuts by its guns 2026-10-20) | `line` (two), `strangle sever` |
| Settlement architecture: hubs, blocks, roads, walls, pickets, doctrines | built | `grow`, variety sheet |
| Economy: drills on real ore, fabricators, parts, power as the graph | built | `grow`, `cut` |
| Rebuild unless occupied | built | `raid`, `occupy` |
| Maturity, launch pad, exports, faction tier | built (first pass) | `faction` |
| Army: roster, depots, garrison, raids | built (first pass) | `assault` (with replay) |
| Operations: intel, raids by value, sizing, staging, abort | built (first pass) | `ops`, `abort` |
| Siege: a hauler carries a mortar beyond the player's turrets; deploy, shell, pack up | built (first pass) | `bombard`, `mortar` |
| Response forces | built (first pass) | `defend` |
| Air units ignoring walls, mines, flamethrowers | built | `air` |
| Ground-only weapons (no anti-air) and armour classes (flat laser and electric on hulls): the RTS pass | built 0.1.48 | arena |
| Anti-air, one per side: Kessler-Hayashi's Skyguard and Grubstake's flak buggy (bought on losses to fliers or the player's combat robots), Synthexis's spore spitter (bred from its arrival) | built 0.1.63 | `unitnode` (`skyguard`, `flak-buggy`), arena |
| A third corporation, Synthexis (id biotech): pens and breeds, its force (at peace with wild biters and Grubstake), a wave as a pack (scout loop and mark, trail, march, breach, what feeds the guns, home); its arrival on a nest field 600 to 1,500 tiles out at evolution 0.25, worms, a raid on a pen recalls its wave; creep (tumors, nest to nest, quicker and mending on it, withdrawn when its tumors die, incubators off it go wild); biomass (breeds paid at the arena's prices from what its creep drinks of the pollution, a trickle, and its pod's 200): `docs/biotech.md` | built 0.1.51 to 0.1.65 (the spore spitter, its anti-air; the stomper, tier 4; the spitter, tier 1, priced 9 by the arena, holding the breach; the runt and the probe; the cinder, tier 3, priced 70; its two levers; Kessler-Hayashi clears its incubators as nests; the break with Grubstake over its creep) | `herd` (eleven), `farm` (four), `creep` (seven), `cinder`, `clear culture` |
| Headquarters per corporation (fortress and uplink): consolidation, fall, withdrawal, prize | built | `hq`, `uplink` |
| Player army: barracks, troopers, rally beacons (hold, advance, occupy, retreat) | built (first pass) | `army` |
| Beacon as a combinator: own or wired signals, X/Y move the rally point, reach drawn | built | `orders` |
| Beacon report on the circuit network: S squad, E enemy units, T turrets in reach | built | `circuit` |
| Field repair: 2% health a second within 30 tiles of a powered barracks | built | `circuit` |
| Command tool: box-select, move, attack, attack-move, release to beacons | built, tried in game | `control` |
| Player units: trooper, breacher (charges for walls), rocket trooper (anti-armour, 2 bandwidth), battle tank (6 bandwidth); barracks picks its recipe | built | `siege` (`LP_MIX`), arena |
| Fought capture against live defences | in progress: no squad wins yet | `siege`, `duel` |
| Corporations as forces (Grubstake, Serenity): own force, colour, intel; they raid each other | built (first step) | `rivals` |
| Capture of mining outposts by holding | built | `army` |
| The fall: a destroyed lander collapses its settlement (cascade, evacuation, ruins that mine to their loot) | built; capture by holding there fails since before 5281d15 (open) | `fall` |
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
| Staggered arrival: Grubstake at chemical science, Serenity at the first rocket (base: utility science) | built | `phases` |
| Landing by approach (at most 6 spawners on the way), Grubstake 60 tiles from turrets | built | `country` |
| Each corporation's own ladder (rungs at 10/20/30 min without a raze); rung 2 raises the unit cap by half, rung 3 a siege tier | built | `ladder` (two) |
| War footing and the war chest: units before rebuilds at war; reliefs (Grubstake's pods, Serenity's columns or drops) | built | `reinforce` (three) |
| Standing down: an hour at war razing nothing, a camp goes quiet and a new landing comes | built | `quiet` |
| Grubstake's pact with the biters through pacifier antennas (cease-fire both ways; break it by destroying them) | built | `pact` (two) |
| Serenity against nests: railgunners, the howitzer with cluster shells, clearances that hold their site, the orbital barrage on landing | built | `rail` (two), `clear` (two), `clearing` |
| Convoys leave walled camps (formed past the outermost wall, escorts ride out, stuck ones called off) | built | `convoy` (two, full list) |
| Grubstake's scrap cannon (dirty flak), every second turret | built | `flak` |
| Grubstake's pheromone flare (biters pulled onto a canister out of turret reach) | retired 2026-10-22 (biter waves are Synthexis's; its biter call lives on in the player's bait) | `snatch` |
| Grubstake's claim jumper (a rig outside the wall, hands up through a mound, a heist) | built | `jumper` (three) |
| Grubstake's power tap: a buggy lays a pylon line along the heist's route to an exposed pole and clamps a tap; the camp runs on the stolen power; grids never wired together | built | `tap` (three) |
| Loot instead of salvage: buildings and units drop what they are made of | built | `loot`, `fall` |
| Faction components (six) and the first faction technology, Cluster shells | built | `fuze` (two) |
| Faction technologies: Pheromone bait, Pact breaker, Claim marker, Cluster shells, Rail rifle, Orbital strike | built | `bait`, `crystal` (two), `fuze` (two), `rifle`, `strike` |
| `/lp rig`, `/lp tap` on demand (`/lp flare` retired) | built | `jumper`, `tap` (`cmd`) |
| Builders: yards build what they reach, crews the rest (Grubstake's truck, Serenity's drone), rebuilds too | built | `crew` (five), `pace` |
| Serenity's cordon: arcs of posts built by drones (on plating, lit, painted post to post), a ring round a grown camp that does not spread, the claim behind them; old arcs recovered; mended when breached; a contact wall near the player; gate posts across the player's rails; ore it crosses claimed | built | `cordon` (six) |
| Rivals: standing (rival, enemy, truce), incidents, map labels | built | `standing` |
| Grubstake prospects the player's frontier; its road (claim trucks, lapse) | built | `prospect` (two), `road` (two) |
| Serenity's border stake; Grubstake's trade post (truce); bending the line with a decoy | built | `border` (two), `tribute`, `bend` |
| The gate (decision 3): a scripted player that engages against one that turtles | instrument built, measuring | `gate` (LP_MIX=turtle, engage) |
| Serenity against a fortress: fire plans, the howitzer against robot-kept walls, escalation; the jammer mast (downs robots, blinds threat scanners) | built | `fortress` (four), `scanner` |
| Serenity's power strike: the cut pole behind the player's lasers, scouts first; dark turrets weigh nothing | built | `blackout` (two) |
| Strangling: the line goes for outposts, then the next ore; at war it cuts belts and pipes on its edge | built | `strangle` (five) |
| Hazard removal (a camp losing to biters clears their nest) and the ledger (Serenity bills the waves the player's cloud draws; paid off, a truce) | built; the ledger's price a guess; disputed by killing the billed nest | `hazard` (eight) |
| Grubstake's skim (a truck parks at an exposed belt and fills its trunk, home to its yard) and dismantling (raids take machines apart, ghosts left, loot kept as items) | built | `skim` (three), `dismantle` (two) |
| Space Age: landings and reliefs by cargo pod, tesla arcs, armour; the threat scanner, the muster point | built; armour and pods not seen in game | `podland` (two), `scanner`, `scanresponse`, `muster` |
| Raid leaders (an icon over one raider; Grubstake breaks when it falls and its foreman drops the haul, Serenity regroups) | built | `leader` (three) |
| Shields, gates for the player, anti-air turret | open | |
| Depletion and relocation | open | |
| Serenity spreads: lobed, walled clusters out toward its line (metastases), up to 30 blocks; its line around a rival's claim | built 2026-10-20, seen on maps, not measured | `factory` maps, `gates`, `cordon ring` |
| Serenity's compounds by wave function collapse (rooms, the curtain round the camp); districts by the keep (the default) | built 2026-10-20, seen on maps and in game; districts measured about even | `factory` maps (`turtlecore` for districts) |
| Serenity's research in the world: a lab per branch in its own district; a branch climbs and fields only while its lab stands | built 2026-10-21; artillery takes one; tanks now take its guns, its garrison then kills the squad | `labs`, `breach arty`, `factory` maps |
| The user's remarks of 2026-10-21: tank shells, labs a size up and at work, cargo-pad depots, the launch pad, cleared ground, crews building from beside, fabricators at rest running, drops in wrecks, the harrier flying, rival intel and reprisals, map labels, district floors | built 0.1.42 | `reprisal`, `loot`, `labs`, `crew`, shots |
| Belts in Serenity's districts (fabricator to depot), Grubstake's sushi belt of stolen goods | built 0.1.43; districts' fabricators back to 0.1.42's share 0.1.45 | `belts`, `skim`, `convoy grown`, shots |
| The unit roster (`docs/units.md`, written from the prototypes by `scripts/roster.py`) | built 2026-10-21 | - |
| New units from the design sheet: Prism, Tesla (Serenity), Scorcher (Grubstake); every tank with its turret | built 0.1.44 | `heavies`, `unitnode` (three) |
| The arena: a counter heatmap of every unit kind at equal spend, against biters by evolution and the player's lines; to watch, with a panel | built 0.1.46 | `scripts/arena.sh` (`docs/arena.md`), `scripts/play-arena.sh` |
| Legibility: every mechanic told in the world (audit below) | audited 2026-10-20; gaps open | |
| Art beyond tinted vanilla; seen in game | first session 2026-10-13; Serenity's clearances watched 2026-10-15; today's Grubstake pieces not yet played | `scripts/showcase.sh` save, `docs/playtest.md` |

## Legibility audit (2026-10-20)
The user: "There is starting to be a big gap between mechanics and what's communicated to the players." The mod grew
mechanic first, and much of its state lives in `storage` only. The rule from here: a mechanic that changes what the
player should do has a sign in the world (an entity, a ghost, smoke, a light, an icon, a map mark), seen before or as
it acts; chat notices stay a last resort. Read from the code (every `rendering.draw_*`, smoke, explosion, chart tag and
notice), not from memory.

**Told well** (keep as the model): raid leaders (an icon over the raider); the skim (a truck with headlights at the
belt, the yard's icon); the pheromone flare (orange smoke on a canister); the claim jumper (rig, dust, mound); the power
tap (a buggy, a drawn cable); the prospect (stake with an amber lamp, a map tag); the trade post (a lamp); the jammer
(mast, lights, arcs); the pact (pacifier antennas to destroy); the siege's hauler and "Deploying N%"; the ledger post
(what is owed, lit) and its billed nests (an icon; not yet seen in game); Grubstake's hurt lander (smoke under 90%, fire
smoke under 60%); territory and standing on the map; constructors drawing a build line.

**Gaps**, by what the player loses by not seeing them:

| Mechanic | Seen today | Gap | Proposed sign | Step |
| --- | --- | --- | --- | --- |
| Howitzer down 30 minutes when killed | parked by the lander, gone while out, a faded mark while down (2026-10-21) | a kill's reward invisible; no warning before a siege | a howitzer parked on a pad in the camp, towed out behind the hauler; the pad empty while out; killed, a ghost on the pad that fills in | 2 |
| Rebuild delay (60 s plus travel from the lander) | nothing until the constructor arrives | where and when it comes back | a corporation ghost on the spot from the moment it dies | 2 |
| Occupation (no rebuild with the player's military within 12) | nothing | why it does not come back | the ghost stays, dimmed or crossed | 2 |
| Grubstake's loot and parts | one yard chest, the icon of what it holds most; parts a number | stolen goods do not become anything | a scrapyard that spreads with what it holds (chests, piles, wrecks); building from it | 3 |
| Serenity reads as a fortified, intelligent foe | walls, pickets, posts | reads as a few buildings | gated or gapped walls (its units path through), bastions, layered depth, lamps; Fable consult on each camp's look; base-game assets unused today (the user: "space station flooring that could be used on the ground for Serenity, giving a real alien look"; the cargo landing pad and bays as its lander and depots), tiles laid by script (`space-platform-foundation` has the ground collision mask: units and buildings stand on it; but it is minable for its item, a free Space Age material, so a copy that yields nothing or scrap, and it has health: to check under explosions on Nauvis; and what a fall leaves) | 4 |
| The economy (drills, fabricators, parts, power) | drills on real ore, fabricators, a power graph | production is abstract; nothing to cut | one real line a camp (drills, belt, furnace, the fabricator's input) the fabricators eat from; the player can cut or tap it | 5 |
| Army reserve, unit cap, bandwidth | depots | how many it has waiting | crates in the depots (a sign first; units as items for the player's army) | 6 |
| Serenity's line, the warning a step ahead | posts built by drones, the claim on the map; the warning a chat notice | the warning is a notice, against the rule | survey stakes on the next arc, a step ahead, in the world | later |
| Belt cuts only where its guns stand | an explosion at the cut | which belts are at risk | none needed: its guns are visible | - |
| Its ladder (rungs at 10/20/30 minutes without a raze), escalation (answer sieges heavier within 30 minutes) | nothing | that leaving it alone grows it | something added to the camp each rung (a depot, a flag, a gun) | later |
| Corporate research, plates | unit names and resistances | what it learned against the player | a plated unit looks plated (tint, armour) | later |
| Grudge, standing down | a later landing; a camp gone quiet | why the next one came angry, why one went quiet | a quiet camp's lights out and guns lowered; an angry landing's escort | later |
| Grubstake's setbacks (a hurt or bled camp holds its raids) | the lander's smoke | that the raids paused | smoke covers it | - |

### Serenity's look (the user, 2026-10-20; Fable: `docs/reviews/2026-10-20-serenity-look-consult.md`)
The user, first deathworld look: "Their base looks nothing like a smart opponent would build it: no outer walls except
for their advancing frontier wall, they deconstruct turrets once the wall has advanced, which is debatable, no road
going along with the wall, only 1 type of turret (might be locked behind tech?), no defense towards their back." The
consult's order: (1) a deck and the lit line, (2) a ring of posts round the camp, (3) a supply lane along the line with
masts, lasers on powered posts, flamers at openings, (4) old arcs kept as depth (pads, walls, stripe, lamps, every third
post's turrets), (5) gates in the contact wall's opening, (6) the cargo pad's and bay's graphics for the lander and depots.
- **(1) built 2026-10-20.** Its pads in `lp-pad`, now a copy of `space-platform-foundation` (the user: "space station
  flooring ... giving a real alien look"): not minable (it would give Space Age's foundation for free), charcoal on the
  map, refined concrete without Space Age (the sims). Each post carries a lamp between its guns (`lp-post-lamp`: no
  grid out there, it burns on nothing, cold white), and a dark stripe (its trim) runs post to post, laid with the posts
  and left by their recovery. `cordon`: 25 lamps on 25 standing posts, 2,543 stripe tiles over 5 arcs. Seen in a game
  window (`scripts/watch.sh cordon`, screenshots by day and night): the camp showed only concrete (a young camp's floor
  is its roads; pads are laid whole at maturity), so its roads are plating too; the lamps' white light read orange on
  desert sand, now blue; a post's eight wall pieces set on a diagonal touched at their corners only and read as loose
  blocks, now a side-joined line; the stripe painted over half the post's pad, now it stops at the pad. Second look:
  plated roads with the platform's pipes, a plated post, a continuous front, and at night concentric arcs of cold lamps,
  the old arcs left as dark lines with their pads (depth). The stripe comes out two tiles wide where the arc runs
  diagonal: it reads as a service lane along the line. The tile's health under shells on Nauvis not yet checked.
- The first run of it failed "power covers demand" (6.6 of 6.0 MW; 5.9 of 6.0 before it): the planner runs only on an
  empty queue, the line's jobs kept the queue full from minute 11, and what was queued before them kept adding demand.
  Now the power rule runs alone while the queue is busy (`plan(b, "power")`; generators queued already count): 6.6 of
  8.0.
- **(2) built 2026-10-20, at maturity.** At landing (the consult's choice) a ring at 40 would stand inside the camp's
  later blocks: a block needs its road ring clear of anything built and its area clear of floor tiles
  (`layout.area_free`), so the ring would have shaped its growth. A grown camp builds no more blocks: it closes a ring
  then, just inside its claim (claim less 4), one post every 60 tiles (8 to 12), the line's own post facing out, no
  stripe; never recovered, rebuilt when lost (`cordon.ring`, through the planner's `matured`). `cordon ring` (grown at
  two blocks): a ring at 56, 16 guns, all eight 45-degree sectors covered. Without the line the camp in `cordon` does
  not mature in 20 minutes (its planner busy behind the line's jobs), so the base scenario has no ring.
- **Spread: the metastasis camp (the user, 2026-10-20: "Shouldn't the camp grow up to the Wall and when the wall is
  pushed back again, continue growing?", then "We need organic looking bases that look menacing, like metastases on the
  map", "it's all squares everywhere").** Built in steps, each looked at on one run's maps (`scripts/campmap.py`, a map
  every 15 minutes from the factory instrument), not measured first:
  - *Growth gated by the line (withdrawn).* Sites only inside its line, maturity at no site left or 30 blocks, each
    step reopening growth. The factory A/B (16 runs, seeds 11-18, three hours): no bigger camps (5 to 11 blocks in
    both arms: a camp's blocks follow ore, not ground), and the player's income 9% lower (134,988 against 148,870; 4
    seeds lower, 2 the same, 2 higher), through its line: matured early under the 90-tile limit, its parts went to
    the line, which stepped to 230 where the old one never stepped, and cut 1,020 belts and pipes against 551. One run
    with maps would have shown it (the user: "1 test with snapshots is much smarter"); recorded in the harness notes.
  - *The launch loop (a bug since the launch rule).* Grown, a camp asked for its launch pad; its newest hub was full, so
    a new hub was founded as a compound, the pad never built, and the rule asked again: eight compound hubs on 12345 by
    minute 60, and no exports. The launch pad now founds its own hub (`layout.open_role`).
  - *Spread (planner rule "spread", `layout.spread`).* Grown and its pad open, with parts to spare (250), Serenity
    founds clusters: a compound (its own generators, a hard point), then a depot and a compound by it (three blocks a
    cluster), tied home by road and pylons; up to 30 blocks. Before its line: no further than 160 from the lander,
    never within 60 of the player's buildings or inside a rival's claim (unbounded, a cluster stood 50 tiles from the
    player's wall, and its claim outran every target its line had); with its line: within 100 degrees of its bearing,
    30 short of it.
  - *Lobed (Serenity's `arch.lobed`).* Every block of its hubs on a plate of its deck: the block and its road ring with
    its corners cut back 6 (`lobe`); side by side they merge into lobes. One wall round each hub
    (`layout.wall_cluster`): the edge of that plate, joined side to side (8-neighbour: no corner gaps), left open where
    the road home crosses it and at its four extremes (open, two turrets inside each: gated, a raid stood behind the
    far gates, `gates`), a turret every 14 tiles inside (8 at most). The core is walled when the camp is grown, a
    cluster when the next is founded or the spread ends; a block opened in a walled hub extends the wall round itself
    and the old wall between comes down. No pickets (its walls carry its guns), no square per block. Lobed for its
    spread clusters only (2026-10-20): the core lobed too turned 23 of 190 scenarios (power past supply with lasers on
    every hub's wall, the gates scenario's gaps, a player army that could not reach a walled outpost, the hazard
    scenarios' camp losing nothing to biters); the core is to be laid out by wave function collapse instead. Its wall
    turrets are gun turrets (fed, not powered). The ledger's scenarios run without spread (its clusters held the waves
    off before the losses that bill them came), and `hazard unpaid` asks two bills, not three (its line now steps, and
    the third losses fell by nests the player's cloud does not reach, rightly not billed).
  - *No ring for a camp that spreads:* its clusters each have their wall; a ring round them all ran 279 out, through
    the player's base. A camp that does not spread keeps it (`cordon ring`, with spread off).
  - *Its line, held by a rival.* A rival's claim caps the line only within the arc it builds (Grubstake's camp to one
    side held it still in every direction); held so on its target, the line takes the player's nearest building in a
    free direction, one a 30-degree sector ("perimeter: a rival's claim in the way; the line goes for ... instead").
    A line that holds says why ("perimeter: holds at 228 (cap 181: a rival's claim, target 445 out)"). On 12345 its
    line had never stepped (three hours, every version): its targets all lay past Grubstake's claim; now it steps at
    minute 80, toward the player's base.
  - Seen on 12345 (`core7`, two hours): a lobed core and five walled clusters strung west on plated roads, 27 blocks,
    its line at 258 pressing on the player's west wall. Next: composition and research by what it has built (a heavy
    factory, a research block).
- **Wave function collapse for its compounds (the user: "Would WFC be a cool algorithm to implement for Serenity?",
  then "Why not WFC for the whole base?"; in progress, not hooked into the game yet).** Hand-made 6x6 tiles in
  `scripts/wfc/serenity.tiles` (ASCII: wall, gate, lane, floor, outside, and buildings by their top-left letter at
  their real footprints); two tiles stand side by side where their touching edges agree character by character, a wall
  or gate may face outside, and a full wall edge never faces another; every tile also turned and mirrored.
  `scripts/wfc/wfc.py` solves and checks with previews (`sheet`); `scripts/wfc/to_lua.py` makes the mod's table
  (`landing-party/scripts/wfc_serenity.lua`); `landing-party/scripts/wfc.lua` is the same solver in game (seeded by the
  caller). A result is checked: a gate opening outside, no floor open to outside, no wall stub or spur, lanes between two
  gates, every floor reachable, every building beside reachable ground. What the sheets taught, in order: a building on
  a tile's edge fits nothing (the validator's first catch); turning tiles by their characters merged two generators
  (buildings are now turned as rectangles); restarting on a contradiction threw away 1,018 of 1,074 tries (depth-first
  backtracking now), and nearly every lobed mask contradicted at once (its edge is soft: a cell beside the outside may be
  outside); a lone wall corner tile ended wall lines in the floor (spurs) and back-to-back walls made thick spurs; with
  those gone every cell walled itself into a sealed pod, so walls are allowed only at the mask's edge and the inside is
  tiles whose edges are floor or lane: one compound a cluster, 6 of 6 samples in 11 tries. In LuaJIT, 30 clusters of 11
  by 11 cells in 46 tries, 8 ms a try (Factorio's Lua slower; measured in game when hooked). Plan: spread founds a
  cluster laid out whole by it (the planner asks what it must hold, generators, a depot; the solver places them; jobs as
  now); then the whole camp, growing by collapsing new ground against what stands (fixed cells).
  - *Rooms (the user: "we need layers of walls too, closed clusters within the base etc. A huge blob with just an
    outside wall is boring").* Partition tiles inside the WFC never held: a partition must cross the compound wall to
    wall, and the solver, which sees only neighbours, never finished one (160 of 190 tries rejected as stubs). So rooms
    are carved after the collapse (`rooms`, binary space partition): straight partitions through floor and lanes only,
    closed at both ends by the outer wall or another partition (a room split, not the compound: T-junctions, rooms of
    many sizes), the longest of the three longest, no partition within 9 tiles either side, not along a lane; a door
    where a lane crosses and at its middle; a partition that cuts a floor, a lane or a building off is taken back (one
    fewer room instead of a rejected compound: 164 tries for 30 compounds became 43). Lanes pass through doors.
  - *In game (0.1.39).* Spread founds a compound laid out whole (`layout.wfc_plan`, `wfc_step`, `lay_out`): planned in
    one tick, solved the next second, its rooms carved and checked the second after; laid out, its floor (walls and
    partitions on it: left bare, sand showed under every wall, the user in game), then what makes parts and power, then
    its walls, turrets and lamps as jobs; a pylon chained home; one block record counting three towards the cap; the
    next spread five minutes on. Timings in game (a profiler, Factorio's own Lua): done at once a try took 94 ms; numbered
    cells and a trail of changes undone on backtrack, then each cell's options as bit words, then the check by numbers,
    not strings: about 16 ms the solve, 16 ms the rooms and check, each in its own tick. Its drones build a compound in
    batches they can pay for (40 jobs at most): one crew took a whole compound's bill and held the queue's head for two
    hours, and once taken, every job of the module had gone off the queue, the later batches lost. Seen on maps and in
    game (the user: "Looks pretty cool. Serenity bases are going to feel like dungeons").
  - *The curtain (`layout.curtain`).* Its spread done, one wall round the whole camp: star-shaped round the lander, in
    each of 72 bearings out to its furthest block and a killing ground of 14, each bearing raised towards its
    neighbours (blocks grown and joined where they touched gave a ring round each compound, curtain1); its edge walled,
    open where a road leaves and at its four extremes, a gun turret every 18 tiles inside; built in 16 segments by
    bearing, each a site for the drones. On 12345: 1,653 walls, 68 turrets, 106 ms once.
  - *Districts (`layout.district`, behind `wfc_core` while tried; factory mixes ending "core").* Where its blocks would
    open a generator, fabricator or depot block, a compound by its keep instead (at least two of what was asked, or a
    depot), on the nearest free ground ring after ring; no pickets. On 12345: districts from minute one, nine walled
    compounds round the keep by minute 89, the curtain going up; no square blocks but the launch pad. Each district its
    own walled ward: keep, wards, curtain, three layers. The factory (turtle, seeds 11 to 18, three hours): the player's
    income about even (139,082 with them, 131,899 without, one seed's chaos; without seed 12, 136,800 against 138,900),
    Serenity's razes 2,978 against 2,654, belts cut 416 against 623, its entities and the milliseconds a tick the same
    (about 5.0 both). The default since (`wfc_core_off` turns them off; factory mixes ending "blocks").
  - *What the regression found with them.* A landing camp's first fabricator came in a district, built by a crew in
    batches: its floor and generators first spent its 90 parts, it never had a fabricator and never made a part (seven
    scenarios; the factory, which gives its camps 3,000 parts, never saw it). Its first fabricator is a block by the
    lander again, and a district's fabricators come before its generators. Compounds and the curtain spent a camp down
    to 23 parts, and a raid that took every fabricator left 175 to rebuild with nothing to make them: a compound's or
    the curtain's walls, turrets and lamps never take the camp's last 200 parts (what makes parts and power exempt). The
    raid and occupy scenarios' "not duplicated" counted every fabricator; a camp that spreads founds compounds with
    fabricators after a raid, so it is asked per spot: at most one stands where one was lost. Scenarios of other
    mechanics run with districts off (`wfc_core_off`): hazard and bait (a district camp loses too little to biters for
    their nest clearances and invoices to come: a real effect, the ledger will bill less often in play), blackout,
    plate, cordon (its plated floors counted as litter). Army runs with districts and the line on, from its fork: its
    squad never set off because the test had put the barracks on an island. It checked each site for water before the
    ground there was generated (no tiles read as dry), and when no site passed it kept the last one tried. Path probes
    found no path even three tiles from the barracks. The ground is generated first now, the search goes all the way
    round, and no dry site is a failed check. Nothing routes the player's squads clear of turrets: an order is a plain
    go-to for the engine's pathfinder (an earlier note here said otherwise, unchecked).

### Its research in the world: labs (the user, 2026-10-21: "Feels like base gen moved ahead from the rest of it, and we should look at tying it to its mechanics? And its tech..")
The camp had come to look like a fortress, and nothing in it did anything a player could read or hit: research was a
fund, its tree's nodes announcements and unit stats. The rule from here: every capability Serenity has is a building in
a room, so what you see is what it can field, and what you destroy is what it loses. Slice 1, built 2026-10-21:
- **A lab per branch of its tree** (`shared.CORPS.serenity.labs`): the Optics lab (`lp-optics-lab`: its lasers, the
  Lance, Shock troops), the Line armoury (`lp-line-lab`: Warden armour, the Aegis) and the Siege works (`lp-siege-lab`:
  hardened siege, the jammer, counter-battery). A vanilla lab lit as if always researching, 600 health, a military
  target (the player's turrets and squads go for it), its branch's sign over it (an item icon: laser turret, heavy
  armour, artillery shell). 60 parts.
- **The gate** (`rd.lab`, `rd.gated`): a branch's nodes are bought only while a lab of that branch stands in one of the
  corporation's camps; what the branch gave is fielded only while it stands: its units leave the depots' mix
  (`rd.mix`), its plates are no longer built (`rd.unit`), its abilities are off (`rd.has`). Levels already bought are
  kept (knowledge, not hardware): a dead Optics lab stops the climb, it does not take the lasers' damage back. The fund
  keeps filling meanwhile. A history brought at landing (`rd.history`) needs no lab.
- **What it wants** (`rd.wanted_lab`): the branch of the node its ledger calls for hardest, when that branch has no
  lab; with no lab at all, its first track's (Optics). **The research rule** (planner, before spread): its launch pad
  open (exports fund research), 150 parts in hand, that lab nowhere in its camps (standing, queued, carried, awaiting
  rebuild or planned): a district planned for it (`layout.district(b, "lab", kind)`), the lab's tile pinned at the
  middle cell (`serenity.tiles` "lab", weight 0.001: never chosen otherwise), so the lab sits at the heart of its own
  walled district. A lost lab is rebuilt like any building.
- **Off** for a corporation without labs (Grubstake, for now), for camps laid out by blocks (`wfc_core_off`) and in
  scenarios of other mechanics (`labs_off`, the harness's default except `labs`, `breach`, `factory`, `visit`: they
  test the tree's choices, not where it stands).
- **Seen** (`factory` seed 12345, 100 minutes, `turtle`): the Optics lab district planned at minute 17, optics level 1
  at 30, a Line armoury district at minute 42 when its losses called for Warden armour, optics 2 at 70; both labs at the
  heart of their districts inside the curtain. Scenario `labs`: funded and choosing every minute, nothing bought while
  no lab stood; the Optics lab at minute 12.8; lasers to level 2, the lab killed: level 2 without it and no Lance in the
  mix, the lab back at minute 16.2, the climb on to 5.
- **Taking a lab (scenario `breach`, seed 12345; the lab district by the keep, 6 guns and 245 walls within 45).** A
  careful player's squad (gathered out of reach, the rally point steered onto the district's turret nearest its side,
  one at a time, then the lab) against a Serenity at era 2 with nothing researched: 20 troopers, 10 breachers and 5
  tanks killed four turrets in 45 seconds and died to the last unit; 10 breachers and 10 tanks the same (9 tanks burnt
  by the flamers at its gates, range 30 against a battle tank's 18). With the fund given to reach a lab fast (9,000,
  era 4: lasers +100%), the same. A player's artillery took it: a flare on the lab killed it in 12 seconds, an artillery
  turret left to choose its own targets in 36 (`breach arty`, in the regression). So the lab is artillery's target, as
  the lander is; storming a district with infantry is not an answer yet (`breach` with a squad stays out of the
  regression, a measurement). Open: one shell takes a 600-health lab (too cheap?); the flamers at the gates against the
  player's tanks.
  *With the tank's cannon round (0.1.43, a district of 4 guns and 114 walls within 45, a garrison of 77):* the squad's
  aim moved from one gun to the next every 5 to 10 seconds, all four in 30 to 35 (45 for four before, against six);
  then the garrison came out and killed it: 35 (20, 10, 5) lost 10 to its turrets and the rest to its Line troopers,
  20 (0, 10, 10) lost 5 to turrets and 14 to troopers, and took 21 of its units with them. The district's guns are no
  longer the wall; its garrison is. A lab wants an army the garrison's size, the garrison drawn away first, or artillery.
  (Its first runs funded the camp until its lab stood and it bought a garrison of 100: the test now tops it up to 200
  parts only.)
- **The howitzer at home (the legibility audit's step 1, first half; built 2026-10-21).** Serenity's howitzer stands
  parked by its lander once its camp is grown (`base.park`), gone while a siege or clearance has it out; killed in the
  field or parked, its camp goes 30 minutes without one (as before) and a faded howitzer marks the empty spot
  (its prototype can have no engine ghost: hidden, unplaceable). Scenario `parked`. The parked one is a prop
  (`lp-parked-howitzer`, a simple entity with the howitzer's look, not a military target): as a real artillery turret
  it was the rivals' first raid target (an artillery turret is worth 12 to their intel) and was counted as a howitzer out
  on a siege, and 13 regression runs failed. Parked from landing, it took ground the camp then built round and four
  more fights came out otherwise: it is parked once the camp is mature. Not yet: towed behind the hauler,
  and parked at the Siege works rather than the lander.
- **Next:** the Siege works holding the howitzer (parked on a pad in its district, towed out for a siege; the legibility
  audit's step 1); units from their own buildings (Lances from a foundry, Aegis from a heavy factory); Grubstake's
  equivalent (its scrapyard).

### The user's visit to the labs save (2026-10-21): what it asked, what changed (0.1.42)
The user played the factory save (seed 12345, minute 56) for a quarter of an hour and sent thirteen remarks. Each, and
what was done:
- **Tanks** ("tank sounds but look like they fire SMGs. Should have more oomph ... a unit that should be good against
  bases"): a tank fires the tank cannon's own round (its flash, its shell in flight, its scorch), 40 explosion to what it
  hits and a blast of 80 over 1.5 tiles to buildings only (`entity_flags = {"placeable-neutral"}`: every building, the
  corporations' and the player's, and the player's vehicles; no unit, character or nest carries the flag). Against a
  squad it hits as before (35 had been one instant hit); against a wall line or a turret cluster three times as hard.
  The player's battle tank the same, heavier (70 and 120).
- **Labs** ("should be animated ... increasing their sprite size"): 4x4 now (the WFC lab tile's `B` 4x4, the vanilla art
  at 4/3), always at work: a lab animates only while researching and the corporation's research is scripted, so its
  body is drawn by script (`lp-lab-busy`, base.lab_look) over the entity's floor plate and shadow. Labs built by 0.1.40
  and 0.1.41 get the look on the update (base.heal_labs).
- **The launch pad** ("a little unceremonious"): the silo whole and shut (its hole, doors and front, not the base ring
  alone), its block cleared of trees, paved, the silo in a ring of hazard stripes two tiles wide, a cold lamp at each
  corner of the ring (layout.launch_floor).
- **Depots** ("still roboports? I thought we were going space age"): the cargo landing pad at half size (4x4), a pad pods
  come down on. A cargo bay alone was tried first and read as a small hatch box: it is drawn to sit in a row of bays.
- **Deforestation**: a block or district clears its ground when founded (trees, rocks, scrub: trees had stood inside the
  landing pad's walls, over the lander), and a drill clears the trees within 6 and the scrub within 4.
- **Belts inside the districts** ("WFC can handle this ... Grubstake could even have a sushi belt"): not in 0.1.42; next
  (below).
- **Drones building from a screen away**: a crew goes to each job before building it (within 8 tiles; one it cannot get
  near in 15 s it builds from where it stands, counted as `far`). The cost: a district's crew of 40 jobs took 103 to 128 s,
  not 21 (labs). The yard's beam (within 40 of the lander or a depot) is unchanged.
- **Fabricators at rest**: a starved fabricator runs now and then (a batch from nothing about once in 12 s, its part
  thrown away: b.idle_runs), so a camp's machines are seen working when its ore is short.
- **Drops** ("not convinced with the resource drop mechanics ... from regular units, not things that were stolen from
  us"): what a corporation's building or unit leaves (the engine's loot), a crew's parts, command cores and the pacifier
  crystal go into a wreck (the crash site's wreck chest, `lp-wreck`, neutral), mined by hand or marked for robots to
  everything it holds; gone after an hour, or when emptied. Stolen goods spilled by a beaten raid stay on the ground.
- **The harrier's selection box above its sprite**: a unit is drawn where it stands (a combat robot is lifted by the
  engine): its body is drawn a tile up, over the destroyer's own shadow on the ground, so it reads as flying and sits in
  its box.
- **Grubstake raiding Serenity for nothing; no punitive raid seen.** factory-12345-labs1: Grubstake raided Serenity's
  depot, launch pad and generators seven times in 93 minutes, each target new to it read "defence 0.0", and 1 to 6 of
  4 to 21 raiders came back; Serenity's responses (up to 70 units) killed them, and it never went for Grubstake, pressed
  on the player. Two changes. *What a rival's camp has shown it holds*: a raid on a rival corporation that razed nothing
  adds 2 to every target of that rival (halved every 30 minutes: ops.held_by), so the next one is sized for it or not
  sent. *Reprisal*: a rival that kills 4 of a camp's buildings or units within 20 minutes has its own targets weighed 5x
  for 20 minutes, not held back by the war on the player, and the camp's next operation comes within 2 minutes
  (ops.wronged; scenario reprisal).
- **Territory markers overlapping**: two "Mineral rights reassigned" labels written over each other: a second patch within
  80 of a labelled one is tagged with the icon only.
- **Floor variation in the districts**: refined concrete under each machine and a tile round it (the apron), a ring of
  hazard stripes round a lab or a depot, the deck elsewhere; never sand (floors `lp-apron`, `lp-hazard`, both
  corporations').

**Belts (0.1.43).** Why none at first: a WFC tile set matches edges character by character and uses every tile turned and
mirrored, so a belt's direction cannot live in the tile; and a belt moves what stands on it. The plan: a conveyor
character `c` that connects like a lane, laid by tiles that only run straight or turn (no junctions), each run traced
after the solve and given its direction from a fabricator (source) to the depot (sink); items put on at the source and
taken off at the sink by script, only while a player is near. Grubstake: a loop of belt round its yard carrying what it
stole (its sushi belt). Bigger districts if the tiles need room.
Built: tiles `belt` (straight), `belt_turn`, `fab_out` (a fabricator, a belt leaving from under it) and `depot_in` (a
depot, a belt ending at it); belt tiles allowed deep inside a district (the solver kept tiles with anything but floor or
lane on their edges to the mask's edge, and had never placed one); layout.belts traces each run and queues its belts with
their direction, after the rest; belts.lua puts parts (the corporation's own, of no use to a player) on each run's first
tile and takes them off its last, every second, only while a player is within 160 of the district. Grubstake's sushi belt:
a loop of 14 belts beside its yard, filled from the yard with two of what it stole a tile; killing the yard spills the
loop's goods with the chest's. In the offline sheet (`scripts/wfc/wfc.py sheet`), runs are short (two to eight tiles),
from a fabricator to a depot or between two fabricators. Scenario belts; the skim's sushi check.

### The arena: unit balance measured (the user, 2026-10-21)
Asked after the `lp-units` save ("the sheer mass of units was kind of insane ... extremely good against biters but no
idea if that's an artifact of unevolved biters"): it was. That map has no nests and evolution 0, so every biter was a
small one (15 health), which a Tesla's jump or two of a Prism's forks kill outright; and the save gives Serenity 30,000
parts for its convoys, which its depots spent on units. A faction at era 3 follows about 100 of the player's
technologies, when big biters and behemoths come.
- **How:** `tests/lp-arena` (a development mod, never shipped), two modes. `scripts/arena.sh` fights every matchup of
  `tests/lp-arena/batch.lua` headless, each in its own pen on a surface of lab tiles, three rounds a little apart, and
  `scripts/arena_report.py` writes `docs/arena.md` (every number computed, none typed). A squad is 420 parts of one kind
  (or a mix) at the corporations' own prices; opponents: a wave of 20 biters at evolutions 0.2 to 0.95 (the spawners' own
  mix), three lines of the player's with no research (guns, lasers, flamers with guns), and every squad of the other
  corporation. Units fight on their real forces, so the Scorcher's bursts and the Tesla's drain run (`debug_tune
  arena_surface`: the Scorcher's flame loop also scans the arena's surface; 0.1.46). Seeded map: two runs give the same
  table. `scripts/play-arena.sh` opens the same arena to watch, with a panel to set up both sides by hand.
- **The counter matrix (the user: "a heatmap of counters ... a fixed number of parts-value worth of each unit"):** 17
  kinds (both infantries: Grubstake's carry shotguns; every other Grubstake variant has its Serenity kind's stats), each
  pair at equal spend as near as whole units allow (about 420 parts a side), fought both ways round so side and force
  cancel; a cell is the share of the other side destroyed minus the share of its own value lost. Beside it, a 420-part
  squad of each against biter waves at 0.5, 0.8, 0.95 and the three lines. `docs/arena/counters.png`, `docs/arena.md`.
- **What it shows:** the sapper (16 parts: 80 explosion over 3 tiles every 3 s; equal spend buys 26) beats every kind,
  the Prism alone holding it near even: underpriced. Then the Prism and Serenity's rifle infantry (10 parts) beat most
  kinds; tanks (60) and the walker (120) lose to nearly everything for their price. The harrier and the scavenger
  win or lose all (only some weapons reach them). The railgunner is the biter-killer it was built as (the one squad
  that beats 0.95); flamer lines stop all but the Scorcher and the two that fly (harrier, scavenger).
- **The price pass (0.1.47; the user: "go ahead with the price changes ... it's expected that some unit types counter
  others. I don't want you to make everything equal").** The rule, from that: every kind clearly beats some kinds and
  is clearly beaten by some (a score of 40 either way; `scripts/arena_strength.py` counts them), never an even matrix.
  At the old prices the sapper and the Prism had no clear loss, and the tank and walker few clear wins. Prices are the
  lever (a row is what its spend buys; damage would change who counters whom): sapper 16 -> 30, Prism 70 -> 100, Tesla
  85 -> 100, tank 60 -> 52, walker 120 -> 100, the rest unchanged. Price moves a row more than in proportion (a squad
  focuses fire: Grubstake's infantry at 6 instead of 10 went from the bottom to the top in a trial round), so it took
  three rounds. After: every kind has clear wins and losses; Serenity's riflemen have one hard counter, Grubstake's
  sapper, kept (at 10 parts they anchor both economies, and dynamite against rifle lines is a counter worth having).
  Prices are read through `shared.unit_cost(corp, kind)`, which takes a corporation's own price where a kind has one.
- **Classes (the user, 2026-10-21: "not 100% clear on which units are where").** There was never a designed triangle;
  the arena report now groups kinds by body and weapon (`CLASSES` in `scripts/arena_report.py`): small arms (Serenity
  and Grubstake infantry, lance, buggy, slug, railgunner), splash (sapper, shock, Prism, Tesla), armour (tank, aegis,
  dozer, walker, Scorcher), air (harrier, scavenger). What the grouped matrix shows (`docs/arena.md`): splash beats the
  other ground classes on average and air loses to every ground class, so there is no cycle between classes; the cycles
  are inside them. Within splash, the roles written for Prism and shock ("against massed troopers") do not hold against
  Serenity's riflemen, who beat both, and of the splash kinds only the sapper does that job. Air has no arena role:
  it is for turrets that cannot shoot up, and the arena only has its fixed lines for that.
- **The RTS pass (0.1.48; the user: "do all of that ... abide by RTS gold standards design wise. We want fun and
  competitive").** The aim: a cycle between classes, each unit a clear job inside its class, and counters a player can
  read from what a unit is. Four rules, all from the genre's standard toolkit:
  - *Who shoots up.* Cannons, rams, thrown charges, ground arcs and flame cannot touch a flier: tank, aegis, dozer,
    Scorcher, sapper, shock, Prism, Tesla, railgunner (`ground_only` in `shared.units`, applied by `air.lua`), and the
    player's battle tank and breacher. Rifles, lances, machine guns, slugs, the walker's rockets and the fliers' own guns
    can. The engine has no target mask for units (an ammo's `target_filter` is not read by unit AI; a mask on a direct
    hit is ignored), so each single hit of those weapons becomes a hit on a 0.3-tile circle that skips the
    `lp-air-unit` trigger target, and their blasts, lines and chains skip it too (spiked in the arena: a tank's shell
    stopped hurting harriers, and still killed infantry).
  - *Ground-only units look for a target they can hurt* (the user: "This will be very problematic in mixed arms
    encounters?"). The engine still lets a unit aim at a flier, so one harrier over a tank column soaked all its fire.
    Each ground-only weapon also carries a script trigger that fires when its shot is aimed at a flier
    (`scripts/aim.lua`); the shooter gets a distraction command (run before its own, which it then resumes): attack
    the nearest enemy it can hurt within 40 tiles, units and turrets first, as an attack-move would; with none, stand
    down 90 ticks without engaging. Measured with the arena's mixed fights (`docs/arena.md`, a ground army against the
    same spend with part of it in harriers, both ways round, three rounds): without the redirect, Prisms killed nothing
    of the other side in all six fights and tanks 0 to 60 of 420 parts, and a tank and rifle army lost four of six to
    its copy with harriers; with it, the ground army destroyed the other's ground units in 17 of 18 fights and then
    lost to the fliers it cannot touch, and the army with rifles won all six. A search within range + 8 tiles was not
    enough: harriers that outran their own ground army left it standing down while they shot it.
  - *Light and armoured.* Every armoured hull (tank, aegis, dozer, walker, Scorcher, Prism, Tesla, the player's battle
    tank) takes 5 off each laser and each electric hit, beside its physical and explosion armour. A rifle's 7 then does
    2: small arms do about a third of their damage to armour (C&C's armour classes). Prism and Tesla were made glassier
    (700 and 800 health, explosion 10%) so that armour beats splash.
  - *Anti-armour light units.* Each corporation has one: Serenity's **lance** (24 laser a shot every 60 ticks, range
    17, 16 parts; it had been a weaker rifle at 12 a shot) and Grubstake's **slug buggy** (one slug of 55 every 50
    ticks, range 15, explosion 40% resisted, 30 parts; three scattered pellets of 14 at range 12 landed a quarter of
    their damage and lost to every hull). Shock's range went from 12 to 14: rifles at 15 outranged the unit meant to
    punish them.
  - *Prices after:* tank back to 60 (52 was set when tanks lost to everything; flat armour made them tough), aegis 95.
  The class table (`docs/arena.md`) now runs as a loop: small arms beat air, air beats armour and splash, splash beats
  small arms, armour edges splash and beats small arms but loses to the lance and the slug among them. Air is all or
  nothing (a squad with no anti-air loses every flier fight; one with it wins), which is the genre's way: build fliers
  when the other side has none. Every kind keeps clear wins and losses.
- **Groups from the fights alone (the user, 2026-10-21: "should we run some kind of clusterization on each unit
  unsupervised?").** `scripts/arena_report.py` clusters kinds by their rows of scores (average linkage, scipy;
  `docs/arena/clusters.png`); the heatmap's names are coloured by corporation, read from `shared.lua`. Cut into four,
  the groups are not the hand-made classes: the first split is who can shoot up (air; the ground units that hit air:
  slug, lance, Serenity's rifles, buggy, walker; the ground-only fighters, splash and armour together; the weak
  ground-only specialists: Grubstake's shotguns, railgunner, Scorcher). With the air columns left out, splash and armour
  still merge: both beat light units, and neither clearly beats the other (class against class, 8). So the ground game
  is light against heavy, with the lance and slug as light units that beat heavy; splash and armour are two answers to
  light units more than two classes. To make them a real choice, one of them needs a clear edge over the other.
- **Splash against armour, your units, the rocket trooper (0.1.49; the user: "go ahead with all three").**
  - *Armour beats splash.* Splash damage moved into more, smaller hits, which a hull's flat 5 shrugs off: Prism 14 and
    five jumps of 10 (was 22 and three of 12), Tesla 20 and seven of 12 (was 30 and five of 18), shock 10 a hit and six
    jumps (was 12 and four); aegis and dozer took the flat 5 on explosion the other hulls had. Armour against splash
    went from +8 to about +60; splash still beats small arms. Dozer 90 -> 100 parts after.
  - *Your units in the matrix.* They cost no parts, so they are priced by command bandwidth, the supply cap of your
    army: one slot as a Serenity rifleman, 10 parts (`arena.PER_BANDWIDTH`). At first the breacher (1 slot) beat 18 of
    20 kinds and the trooper 3: you would never build troopers. The fixes keep army sizes (raising the breacher's
    bandwidth would have shrunk every army): the breacher's charge does 15 to units and the full 100 to buildings (a
    demolition specialist is a poor fighter); the battle tank's shell 50 to what it hits (was 70; its 120 siege blast
    kept) at 6 bandwidth (was 4; the siege scenario now places six relays for its 20 troopers, 10 breachers, 5 tanks);
    the trooper's rifle 8 a round (was 6).
  - *The rocket trooper* (`lp-rocket-trooper`, barracks order with command bandwidth 2, which now also needs rocketry;
    heavy armour, a rocket launcher and 10 rockets, 40 s; 2 bandwidth): a rocket of 110 explosion every 2.5 s from 18,
    flying to its target only; it hits fliers. Tuned so its job shows: at 100 every 2 s it also beat light infantry
    as well as a trooper; at 80 it lost to tanks; at 3 bandwidth it dropped from +40 to -26 (Lanchester again). Now it
    beats dozer, walker, Scorcher, Prism, Tesla and the fliers, edges tank and aegis, and loses to riflemen and troopers.
  - *Grubstake's infantry* (the user: "Grubstake infantry seems a little underwhelming?"): it was, second from the bottom
    (beat 2 kinds, lost to every light infantry), dying on the way in from rifles' 15 to its 9 and then missing with a
    wide spread. Now a swarm that wins once it closes: quicker (0.13 -> 0.17), a tighter spread (0.3 -> 0.15), and 8
    parts for Grubstake (`by = {grubstake = 8}`; at 10 only its front rank was in reach of a rifle blob, at 6 in the
    first price pass it beat nearly everything). It beats ten kinds by numbers, is near even with rifles, and splash
    (shock, sapper, breacher) and fliers crush it. Since then the railgunner has no clear win among units (its one was
    Grubstake's infantry): it stays, judged by its job, the one squad that beats biters at evolution 0.95.
    The `arms` scenario held each corporation's infantry to DPS parity against buildings (within 20%); the 0.1.49
    regression found the Shotgun hands at 600 ticks to the Line troopers' 810, from the tighter spread, so it now asks
    no slower and at most 40% faster.
  - After (three rounds, `docs/arena.md`): every kind but the railgunner clearly beats some, and all are clearly beaten by at least two. Class
    table: small arms beat air, air beats armour and splash, splash beats small arms, armour beats splash and small arms
    but loses to the anti-armour small arms (lance, slug, rocket trooper). The clustering still puts splash and armour
    together (both beat light units; it does not separate who beats whom within the pair), and the anti-air ground units
    apart from the ground-only ones.
- **Limits:** no research on either side (a camp's tree levels and the player's damage upgrades both matter); open
  ground (no walls for the squads, no terrain); the wave arrives in one clump. Next, if the numbers call for it: tune
  costs or caps, not damage, since a squad's spend is the comparison.

### What the full regression found, 0.1.42 to 0.1.45 (2026-10-21)
- **0.1.42 was merged with 177 of 188 passing, not "188 of 190"** as its commit says: the count was read from the last 40
  lines of the report. Eleven failed. The causes, each found by bisecting with snapshots:
  - *Crews walking to every job* (defend, both line runs, bait): building ran about five times slower. Now a crew builds
    whatever is within 12 tiles of it first, nearest first, and walks only for what is out of reach.
  - *Wrecks on rebuild spots* (defend): a wreck where a turret died blocked its rebuild. Wrecks collide with nothing.
  - *Reprisals chaining into conquest* (rivals: Serenity took Grubstake's camp in 37 minutes): a reprisal is now one
    punitive raid, spent when it launches.
  - Test fixes: breach arty given 60 shells, tribute's player rebuilds before the truce ends, dismantle counts the sushi
    belt's goods as the yard's.
- **Belts made camps that never matured (0.1.44, found on seeds 777 and 4242).** A belt run must end at a fabricator and
  a depot, so the belt tiles brought fabricators of their own: a power district averaged 7.5 fabricators to 8.7
  generators (0.1.42: 5.8 to 8.7; 40 game-sized districts sampled offline). Power demand chased supply, the camp planned
  power district after power district (8 against 2 in 45 minutes), never ran out of growth, never matured, and sent no
  convoys. The plain fabricator tile's weight went from 3 to 1.5 (0.1.45): 5.0 fabricators to 8.6 generators, 13 belt
  tiles a district. Lowering the belt tiles' weights did not help (the ends still brought their fabricators).
- **Tests changed, and why.** `convoy grown` judged escorts' distance while a hauler stood still waiting for them: on
  seed 12345 it waits at one stop while its escorts walk round a wall (30 tiles); under way they keep within 12. The
  check now judges the travelling spread and reports the parked one. `hazard` (plain) sent waves of 24 biters, every
  other mix 40: since the tank shells and the belted districts, Serenity beat waves of 24 nearly unhurt and its first
  clearance came after minute 57; now 40.
- **Seed-specific, not regressions:** `hazard` fails on seeds 777 and 4242 in 0.1.42 as now (on 4242 the waves cost
  Serenity nothing; on 777 its losses cross the threshold at minute 60): it is calibrated on 12345. `fortress old` lost 2
  of 10 lasers on 12345 in 0.1.44, none on 777 or 4242. `bombard` on 12345: the new shell turned a won assault into an
  abort; over three seeds, the new shell won 1 and the old weapon 2.

### New units and shields (the user, 2026-10-21; units built 0.1.44, shields proposed)
**Built (0.1.44):** every tank carries its own cannon turret now (units.lua, `crowned`: a turning head's layers on a
hull's, held to its frames and pace). The Prism (Serenity, Optics, era 2 after Lances, 1,800 fund, when troopers, breachers
or you have killed 9 of its units in 30 minutes): a tank with a small laser head on its turret, 22 laser to its target
and a forking chain of 12 to the ones round it (three jumps, 6 tiles each); four of a pack of eight hurt by its first
shot (scenario heavies; a chain passes over entities frozen with active = false, the first run's mistake). The Tesla
(Serenity, Siege, era 3, 2,500, when turrets have killed 10): the tesla turret's head on a tank's hull, 30 electric and
a chain of five jumps of 18, 8 tiles each; what it strikes that holds a charge loses 60% of it (on_entity_damaged,
electric: 42 drains on four lasers in a minute). The Scorcher (Grubstake, Scrap arms, era 2, 2,000, when turrets have
killed 8): the flamethrower turret's head on a tank's hull, a machine gun, and three bursts of the flamethrower's stream
at a wall, gate or turret within 15 or a pack of three of yours within 9, one every 2 s, refilled one each 20 s, never
within 30 of a nest while Grubstake's pact holds (scripts/scorcher.lua: five bursts in the minute at a wall line). Each
bought by its node (`unitnode` prism, tesla, scorcher).

- **Picked from the design sheet** (in-game mockups, `tests/lp-shots/data.lua`, scene 1c): Scorcher B (Grubstake: a tank
  hull with a flamethrower head; a machine gun, three flame bursts spent only on walls, turrets or packed units within
  about 12, refilled slowly or at a depot, no fire near nests while its pact holds), Prism B (Serenity, Optics: a tank
  with its turret and a small laser head; a beam that splits to three to five targets: against infantry, weak on walls),
  Tesla A (Serenity, Siege: the tesla head on a tank hull; chain lightning that drains the power buffer of what it hits),
  the shield truck (Serenity, Line: a truck with a radar dish, a dome round it). And the tank's own cannon turret on every
  tank (they have had the hull only).
- **The shield's look**: our own (the user: Earendel's Shield Projector was the one remembered; not borrowed),
  `scripts/make_shield.py`: a hexagon dome, faint inside and bright at the rim, a sweep of light and a shimmer; a hit
  ripples outward from where it struck.
- **Static shield generators** (the user: "bubbles which can tank some artillery shells"): Serenity's answer to the
  question its labs left open (one shell kills a lab). A generator in a district holds a dome; damage to what stands
  inside is taken off the dome's charge instead (on_entity_damaged: the health restored, the charge drained, a ripple
  where it struck) until it breaks and flickers out, then recharges. Powered: cutting its line, which Serenity's own
  cuts and the strangle already teach, drops the dome. Its counters, then: sustained fire, a power cut, the Tesla's drain
  on the other side. A component from a generator's wreck could give the player the same, by a teardown, as Serenity's
  other components do.

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
- **Threat scanner (built 2026-10-18; `scripts/scanner.lua`):** a constant combinator the mod writes once a second
  (its window does not open), a radar's icon, unlocked with the army (command bandwidth 1). Within 64 tiles it counts
  the corporations' units by role, one virtual signal each (infantry, armour, walkers, aircraft, railgunners, haulers: a
  siege or a strip camp coming, buggies), the building crews apart, a total a corporation, and the biters. Scenario
  `scanner`: five troopers and a hauler, three buggies, two biters within, four troopers beyond: counted exactly; two
  troopers killed, the count follows within 2 s.
  **Jammed (2026-10-19):** a hostile jammer mast within 50 tiles (the reach of its robot arcs) blinds it: it outputs
  `lp-scan-jammed` = 1 and nothing else. The call: Serenity's eyes against the player's (a siege under its jammer comes
  unseen), but a blinded scanner still says so, so a circuit can answer "jammed" as a threat of its own, and the player
  learns a mast stands near (the counter is the same as for the arcs: destroy the mast, or a second scanner further
  out). `scanner`: under a mast 36 tiles off, `{lp-scan-jammed = 1}`; the mast down, the count is back within 2 s.
  Scenario `scanresponse`, the loop end to end: a scanner at an outpost 60 tiles out, a decider by it (three Serenity
  units or more: X = 60), its output carried home on a red wire over medium poles to a rally beacon with six troopers.
  The squad stays home until four Line troopers come to the outpost; then it marches, kills all four (losing two) and
  goes home when the scanner reads clear.
- **Roads (built 2026-10-18; `scripts/roads.lua`; the user: "player constructed concrete surfaces that speed up army
  traversal"):** units walk at one speed on any floor (a spike: 33.8 tiles in 5 s on refined concrete, 33.9 on grass),
  so the floor's bonus for the engineer (stone path 1.3, concrete 1.4, refined concrete 1.5) is lent to the player's
  army by an invisible sticker, renewed twice a second while it walks on it. Scenario `roads`: 47.2 tiles on refined
  concrete against 30.8 on grass in 5 s. The player's army only: the roads are the player's.
- **Packing and the muster point (built 2026-10-18; the user: "Trains could even play into the mix"):** the army is
  cargo. A barracks wired with P > 0 keeps its finished orders (trooper, breacher, battle tank) as items in its output;
  inserters take them, and the player's own logistics (trains, belts, robots) carry them. A muster point (a steel
  chest's body, tinted; steel chest, radar, 10 circuits; with the army's research) turns orders put in it into units
  beside it, sent to its nearest rally beacon, within the force's bandwidth. Scenario `muster`: packing, none deploy
  and an inserter takes them out; carried, five troopers stand at the muster point 150 tiles off within 3 s.
- **Threat scanner (the idea; the user, 2026-10-18: "a building that scans for enemy units in a radius and gives signals
  for each unit type with a number depending on units present in the radius of the scanner would probably be super
  useful for circuit engineering").** The beacon's missing input half: the army takes orders from circuits, nothing
  gives circuits eyes. A building (a radar's body, a combinator's output) that every second or so counts the
  corporations' units within its radius and outputs one signal per unit kind (Line troopers, Shotgun hands, buggies,
  railgunners, haulers...), the count as its value; perhaps a total per corporation, and the biters apart. Wired to a
  rally beacon through deciders: "ten troopers or more by the east gate: advance the squad there", gates shut, lamps
  lit, trains held. Open: its radius and cost (64 tiles, steel and circuits as built). Settled: the jammer blinds it;
  haulers have their own signal. With the response army and its transport (trains, concrete roads for
  speed: the user, same day) as one thread, after the fortress work.
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

### A sealed fortress: nw (the user, 2026-10-18: "Pretty sure lasers + robots negating them completely is not good")
Plotted (a `dumpmap` visit: walls, turrets, water and nests round the camps), nw is a walled rectangle lined with
lasers on three sides and closed by lakes north and east. What kept the corporations out was mostly ours, not the lasers:
- **Staging across a lake.** Grubstake's second camp sits north of the big lake; every substation it chose lies across
  the water, so the line from target to home ended in it: "no staging point on dry land", every 2 minutes for three
  hours. Now the staging point is sought on lines turned up to 90 degrees either side (`outside`, `TURNS`): its 26-unit
  raid got in and razed 275 solar panels and accumulators.
- **Marches that broke off.** Raids marched engaging any enemy in sight, and Serenity's crossed nest country: every
  passing biter pulled them away. Every march now answers only what hits it.
- **Serenity never breaches.** Its raids on substations behind the wall walked its length looking for a way in and gave
  up 270 to 360 tiles off. Now a raid that does not sneak goes straight at the first wall piece on its line
  (`wall_on_line`) and through; through the gap it takes the nearest building (told to attack the area, inside the
  wall it ate the wall from within). A breach walled up again by robots before any raider got in is broken again.
  Scenario `mended serenity` (a wall rebuilt 5 s after it falls): the assembler razed in 40 s; on the old code the raid
  gave up.
- **The answer's siege before its level.** An answer is self-defence: Serenity may siege as one before level 1 brings
  sieges (it sent nothing at the laser wall for three hours). But a tier-1 siege, one mortar, fired 30 shells at a
  laser wall its robots repaired and razed nothing: open (the answer's siege sized to the wall).
- **Guarded behind a wall.** A target it cannot get round turrets to is guarded, whatever stands by it, so Grubstake's
  flares see it. On nw none flew: no nest within 600 nor idle biter within 400 of the north shore (the factory had
  cleared it): right.
- **Serenity walled its own army in.** Its camps put a gate in every opening of every walled block, and no gate
  opens for a unit: on nw its raiders stood at the lander behind 29 to 107 pieces of its own wall, raid after raid.
  Now a camp holds its gates open for its units nearby while it has units out or leaving (an operation, units on their
  way back, a departure in the last two minutes; `army.gates`), and opens them all as units leave (`pool.take`): a
  unit plans its path when it is ordered, so a gate opened only once a unit stood by it stayed in its way. An idle
  camp's gates stay shut (its garrison by a gate had held it open 3,460 times in six minutes). Scenario `gates`: the
  garrison in a gated pad's yard, a raid 140 tiles off razes its target; `gates shut` (`gates_off`, the old code): the
  raid never leaves the yard.
- **Raids sent in from afar.** Past its staging time a raid went in wherever its raiders were (181 tiles off). Now it
  waits while they are still closing in (up to three times its time) and is called off if they stall far off.
After these (deathworld10x, provoked, x1): about 380 razed (650 before the day's answers), turrets lost 78 (54 to the
corporations, 24 to biters; 69 before). Grubstake answers with flares now, not squads: fewer belts chewed by its own
raids, more turrets under biters. Mean tick 0.49 ms against the save's 0.30 (alone), script 0.04 ms. The worst ticks,
100 to 150 ms once a second for three seconds, are a sixth landing's site search ("2 waits for ground"): existing,
not the day's; open.
  Measured (a visit queueing a landing as the faction does, `LP_MIX=async`; engine profilers): each try of an
  asynchronous landing, waiting for its ground, ran the whole site search again: 22 to 25 ms a try even with no
  candidate, all of it the ore noise sampled round 8 ring points (about 2 ms each; the approach count and the build
  were 0 and 1 ms). The noise is the map's: cached per ring point, a try costs 3 to 6 ms after the first (22 ms, once a
  landing). The cache changes no result, so it is no state to keep in step.
Robots rebuilt all that was razed (666 entities, 378 of them land mines, no ghost left): against a robot base, pressure
is materials, not ruins. What would hurt is the robots' own network (roboports, power), which the siege went for.

### Fliers and anti-air (the user, 2026-10-23: "Not super comfortable about the flier units currently")
The arena (2,673 fights) had air beating splash by 100, armour by 67 and every breed by 93 to 100, losing only to small
arms (-47): nine of the corporations' kinds and every breed cannot shoot up, so in most armies air was a hole, not a
counter. Plan (the user: "Go with your plan"): one anti-air answer per side, then the fliers retuned if still needed,
then the player's side read.
- **The answers (0.1.63).** Each hits a flier hard and the ground lightly, through masked areas at the target (an area
  honours `trigger_target_mask`, a direct hit does not), and outranges the fliers' 15:
  - **Skyguard**, shown as Anti-air trooper since 0.1.64 (Kessler-Hayashi's Line, 18 parts, 110 health): a Line trooper's body, a tracking laser, 30 to a flier
    and 3 to the ground every 30 ticks, range 22.
  - **Flak buggy** (Grubstake's Wheels, 20 parts, 220 health): the buggy's hull with the car's turret, scrap flak over 2
    tiles, 22 to fliers and 3 to the ground every 30 ticks, range 22.
  - **Spore spitter** (Synthexis, 10 biomass): a violet bred spitter whose spit bursts where it lands, aloft too, 30 acid
    to a flier within 1.5 and 3 to the ground, no burning pool, range 20; bred from evolution 0.25 (a twentieth of births
    from 0.4). Not ground-only (`shared.BREEDS` `air`). 45 changed nothing: it wins every fight with harriers and loses
    half its value doing it (+48), a soft body under fire.
- **How the corporations get theirs:** tree nodes bought when fliers kill 6 of their units: the corporations' harriers
  and scavengers or the player's destroyers, defenders and distractors (`shared.FLIERS`). The research ledger never
  recorded either before (a unit's or a robot's kill had no damage type in `rd.tally`): now harriers deal physical,
  scavengers explosion, combat robots physical.
- **The arena after (3,264 fights):** anti-air beats air by 88 and loses to every ground class by 89 to 100: a counter,
  not a better rifle. Skyguard and flak buggy beat harriers and scavengers by 99 to 100; the spore spitter scavengers by 80,
  harriers by 48. Air's own rows are unchanged (still +100 on splash and the breeds, +67 on armour): an army now answers it
  by buying or breeding the counter, which keeps the counter shape (`balance keeps counters`). Step 2 (fliers as
  harassers) is held until play shows air still runs over armies that have their answer.
- **Ground fire and plain names (0.1.64; the user: "Do anti air units also fire on ground? ... they should be able to
  kinda attack ground units also. For instance flak could be a sort of weak ground splash"; and "Not a fan of the names
  you give Kessler units ... calling a heavy tank a heavy tank is good").** Ground hits raised from 3: the anti-air
  trooper 8 on one target; the flak buggy 3 over 1.5 tiles (6 over 2 beat every infantry by 75 to 95, a better
  anti-infantry unit than the dedicated ones); the spore spitter 18 within 1 (6 and 12 left it at -80 to -100 on the
  ground; at 18 it costs a hull 38 to 57, acid going through armour, and still loses to infantry by about 90). Trials
  (two rounds each): the anti-air trooper loses to the ground by 53 to 94 and is even with buggies; the flak buggy loses
  to most of it by 30 to 100 and beats buggies, heavy laser troopers and railgunners by 52 to 73. Kessler-Hayashi's
  units shown plainly (locale and the arena's labels; ids unchanged): Line trooper -> Laser trooper, Lance -> Heavy
  laser trooper, Skyguard -> Anti-air trooper, Aegis tank -> Heavy tank, Prism tank -> Laser tank, Tesla tank ->
  Lightning tank. The burster shows as such in the arena too.
- **Faction metrics (the user: "a good complement to the heatmap could be some faction metrics, computed by clustering
  unit counter metrics per faction matchup").** `scripts/arena_report.py` now writes a faction-against-faction table
  and `docs/arena/factions.png` from the unit matrix: per pair, the row's best answer to each of the column's kinds
  averaged (answer), the share of them it has a +50 counter for (coverage), the share of its own the other has one for
  (exposure), and per faction how many of the fight-made groups its roster spans (breadth). On 0.1.64's arena (3,240
  fights): the corporations even with each other (+92 and +90) and both above the player in coverage; the player's
  answer to Kessler-Hayashi +84 against its +65. Synthexis against Grubstake +84 (+40 before the spore spitter), but
  against Kessler-Hayashi +36 with 40% coverage while Kessler-Hayashi answers every breed (+100): the railgunner beats
  every breed by 100 and no breed beats it, nor the heavy hulls. A breed for that gap (the stomper, tier 4, an armoured
  answer to railgunners and hulls) is the next lever; Kessler-Hayashi as the exterminator is meant to win, by how much
  is the question. Built 0.1.65 (`docs/biotech.md` "The stomper"): Synthexis against Kessler-Hayashi +71, coverage
  70%, the edge -29; Kessler-Hayashi still ahead, as the exterminator.
- **The player's side:** troopers beat harriers by 98 and rocket troopers by 95; turrets shoot fliers (flamethrowers do
  not). Not yet measured: player turret lines against a wave of fliers.

### The mortar truck (the user, 2026-10-22: the howitzer as artillery on a tank; engine spike, deleted)

Idea: one unit, a tank body with the artillery barrel, in place of the hauler, the emplacement and the parked prop.
Spike (a `unit` copied from a biter, the tank's animation, range 98, min range 20, cooldown 240):
- **A unit with the artillery wagon's gun parameters crashes the engine** on its first shot (an assertion in the unit's
  shoot). With the tank cannon's parameters it does not.
- **The shot as a script trigger works:** the unit's ammo is an instant delivery with a `script` effect; the handler
  creates a real `artillery-projectile` from the truck to the target (`source` the truck: kills and damage are its).
  At 90 tiles it fired without moving and the shell landed 92 ticks later (1,000 damage); behind a wall of lasers it
  hit them from 90 (8 hits, one shell's splash); an uncharted target is no obstacle; at 150 it drove to 99.6 and fired.
- **Inside its minimum range it never fires and does not back off** (10 tiles: it edged to 16 and was shot dead): the
  script must site it, as sieges already do.
- **Only an explicit `attack` on an entity works.** `attack_area` walked it to 17 tiles of the target without a shot
  (killed); idle with a vision of 100 it wandered in and fired from 23. The siege picks each target and orders the next
  when a command completes, where the emplacement chose its own.
- A grenade-style lobbed projectile also works (35 per hit, 12 hits to kill a turret) but flies flat: the script
  shell is the artillery's real arc and crater.
- **Its rules (the user: a deployment delay, and a limit, "otherwise that's just OP"):** it deploys 30 s at every
  site before its first shot ("Deploying N%" over it, as the hauler's site now) and packs up 15 s before it moves; it
  never fires on the move (it fires only when the script orders an attack). One per camp, as the howitzer: killed, the
  camp goes `HOWITZER_DOWN` without one. The deploy is the counterplay: alone 90 tiles out with its escort. If the
  player ever fields one: 10 bandwidth (a battle tank is 6) and at most one per bandwidth research level.
- **Built (0.1.61), option 1** (the user: "Sure. That is probably the cheapest solution"). Any siege that takes the
  howitzer (a clearance whose worms outrange the mortars, or a siege on a wall kept by robots) goes behind
  `lp-howitzer-truck` as its hauler: the tank's hull crowned with the artillery cannon (`units.lua`, the cannon at the
  turret's own size and height, in the faction's colour), the hauler's pace, gun and armour, the howitzer's 1,200 health.
  Deployed (the siege's 30 s), the truck gives way to `lp-howitzer` where it stood (`ops.truck_down`), facing as it faced
  (the turret's base is now the tank's hull, four ways) and with its health as a share; packing up, the turret gives
  way to the truck (`ops.truck_up`), 15 s (`TRUCK_PACK`) during which it and the mortars are inactive: before a clearance
  moves on (`op.pack_site`, the next site kept while it packs) and before it drives home (`ops.finish` folds it and
  sends it home as the hauler). At home the parked prop is the truck's look (hull and cannon), hidden while the truck
  is still on its way back. The truck killed, on the way out or home, is the howitzer killed (`HOWITZER_DOWN`). A siege
  with a howitzer and mortars now moves the howitzer when it moves up (it stayed behind before). Aiming, shells,
  resupply and the fire plan are the turret's, unchanged. Tested by `clear worms` (the truck's checks: out on its truck,
  deployed facing and health kept, never truck and turret at once, never beside its parked self, silent packing up,
  home and parked again) with the howitzer scenarios unchanged.
  Screenshots (2026-10-23): first the barrel did not turn with the hull. A layer with more directions than the
  animation's first layer is read by the first layer's direction index: the cannon's art has 256 directions and the
  tank hull 64, so a truck facing south-east had its barrel pointing north-north-east. Fixed (0.1.62): the cannon read
  as 64 directions of four frames, holding frame 0, so each direction lands on every fourth of its 256 frames.
- **The plan it came from (2026-10-23).** The howitzer today runs through siege.lua in six places:
  the piece made at the site on deploy (`op.howitzer`, or `op.piece == "lp-howitzer"` for a clearance), its shells
  (an artillery turret's inventory, resupply convoys), its aiming (an `artillery-flare` on `op.focus` each step), its
  loss (`HOWITZER_DOWN`), its parked prop at home (`base.park`, `lp-parked-howitzer`), and packing up. Two ways:
  1. *The truck drives, the turret fires* (smaller): `lp-howitzer-truck`, a unarmed unit (the tank's body with the
     howitzer's barrel, `crowned` as the tanks are), drives out with the hauler and replaces the parked prop at home;
     at the site, once deployed, it gives way to the `lp-howitzer` turret as now (aiming, shells, resupply unchanged);
     packing up, the turret gives way to the truck again. Loses: the turret's look stays an emplacement.
  2. *The truck fires* (the spike's way): the unit fires by a script trigger that launches `artillery-projectile` at
     the target the siege orders (`attack` on `op.focus`; each completed command orders the next); its shells a count
     in `op`, not an inventory; deploy 30 s and pack-up 15 s by script; no turret at all. Simpler in the end, but every
     howitzer scenario changes: `fortress howitzer`, `clear` (two), `clearing`, `parked`, `rail` (two), `breach arty`.
  Recommendation: 1 first (it keeps every tested behaviour and gives the look and the drive), 2 only if the turret's
  look at the site matters. To build with the user about, not overnight.

### Serenity against a fortress (the user, 2026-10-18; Fable: `docs/reviews/2026-10-18-fortress-consult.md`)
The user: "that's hardly better than a biter mod. Why shouldn't Serenity be able to do more than that?", then "The
idea of treating factions as intelligent adversaries is key. A wall of lasers should not be an impregnable fortress by
itself with this mod, no?" Four capabilities, in Fable's order: sieges sized to win, a robot jammer (a mast in the
emplacement), the power strike (transmission: the first stretch of poles beyond turret reach with no second feed),
strangling (the line walls off outposts and ore).
- **Sieges that win** (built). Scenario `fortress`: 40 tiles of wall, ten lasers, infinite power, two roboports with
  30 construction robots and 100 repair packs each, spares in storage, ghosts on death; Serenity at level 3, a siege
  forced on it. As it was (`fortress old`): three mortars fired 117 shells along the wall and the robots mended every
  hit, 32 repair packs, nothing destroyed. Now:
  - **A fire plan.** Every piece on one point at a time, roboports first, then the weakest turret in reach. A mortar is
    told by an artillery flare on the point (a turret's shooting target cannot be set from script: a spike, flare 144
    damage to a roboport, set target an error).
  - **A howitzer for a wall kept by robots** (roboports within 60 of the target, tier 2 or level 2 up): the mortars'
    35 tiles reached the lasers, not the roboports 13 behind them; the howitzer's 98 does.
  - **A howitzer killed stays lost** (2026-10-20; Fable's consult: a fresh one came with every siege, so killing it
    cost Serenity nothing): one destroyed in the field leaves its camp without one for 30 minutes
    (`shared.HOWITZER_DOWN`). Sieges in that window come with mortars only (traced "no howitzer (lost; N minutes
    yet)"); a clearance that needs it waits. `fortress howitzer`: killed as it stood, the second siege on the same wall
    came without one; with the window set to zero, both its checks failed.
  - **Escalation**: an answer siege within 30 minutes of the last comes a tier heavier, as far as parts and field reach.
  `fortress`: every laser and roboport destroyed (and four spare roboports the robots put back), 30 of 41 wall pieces,
  the 200 repair packs spent; the assault of 16 came home whole. Counters left to the player: artillery outranges the
  howitzer (counter-battery), a sortie, roboports deeper than 98 tiles.
- **The jammer** (built; `scripts/jammer.lua`, a leaf the siege raises and lowers). A Serenity research (`jammer`,
  era 2, its trigger a siege whose hits the player's robots mended: roboports still standing by its target at its end,
  `rd.mended`). With it, a siege on a wall kept by robots raises a mast in the emplacement: a big pole's mast in
  Serenity's colour, a blinking lamp ring and a glow, 1,500 health, a military target. Every half second its arcs
  (drawn lines) strike up to three of the player's construction or logistic robots within 50 tiles. `fortress jammer`:
  the mast up with the guns, 60 robots downed (all of them), nothing rebuilt, the wall down sooner on fewer shells
  (64 against 78). Counters: destroy the mast, keep roboports beyond its reach.
- nw after these (provoked, x1): Serenity never faced the player. Its camp landed inside a nest field and spent the
  three hours at war with biters: 369 turrets, 340 wall pieces and 227 units lost to them, 115 responses, 539 rebuild
  drones. Where Serenity lands on a biter-heavy map is its own problem: open.
- **The power strike** (built; `scripts/power.lua`, a leaf; Serenity's temper `cuts`). Every 5 minutes at war, the
  survey takes the player's 40 lasers nearest its home, the network behind them, and its poles within 350 tiles as a
  graph by their copper wires (a wire to a pole beyond that counts as a source). The cut is a pole no turret reaches
  whose loss leaves turrets with no source on their side; the one darkening the most becomes a target worth 14 (a
  relay is 10). A dark turret (no energy) weighs nothing in the defence a raid is sized to (`ops.weigh`,
  `ops.exposure`): the Line goes through the dark stretch. Scenario `blackout`: ten lasers fed by a chain of big poles
  from a source 120 tiles off, a decoy line to a radar nearer the camp: the survey names the chain's end, the next raid
  cuts it, the lasers go dark 500 s after the base stood, seven of ten are taken. `blackout fed` (a second source
  inside the wall): no cut, the lasers stay lit. Without the survey the camp found the feed too, by luck (its first
  raid took the decoy's substation and cooled the decoy's poles): Serenity already raids exposed lines; the survey is
  what picks the one that matters among many. The reconnaissance tell (built, same night): when the survey first names
  a cut, two units walk out to the pole and back, and the target waits 2 minutes before a raid may go for it: Serenity
  seen surveying first, the player's warning (`blackout`: "scouts walked the line first").
  Cost: on nw (949 poles in the area, a meshed network: "no single cut", rightly) a search from every candidate pole
  took 270 to 320 ms every 5 minutes; one depth-first pass (articulation points, the turrets and sources on each side
  summed on the way) with turret reach from a grid: no spike left at the survey (worst tick 124 ms, elsewhere; mean
  0.61 ms against the save's 0.52). A turret is dark when its status is no power, not when its buffer is empty: a
  laser just built read as dark and a raid was sized against nothing (`sneak`, whose raid now comes a second after
  its base stands).
- **Strangling** (built, first slice). At war, the line's step goes not for the player's nearest building but for the
  outpost easiest to cut off: the player's drills within reach grouped by 48-tile cells, the most drills to the least
  turret weight, then the nearest (`ops.perimeter`, `outpost`). Inside its claim, a player's building is worth double
  to its raids and sieges while at war (`choose`). Scenario `strangle`: the main position (a relay, two gun turrets)
  200 out toward spawn, a guarded outpost (six drills, two gun turrets) 230 out at 90 degrees: every arc at 92 degrees
  (the outpost at 91); `strangle off`: the first arcs at the main position. This camp was strong enough to raid both
  either way: what strangling changes here is where the wall goes.
  **The next ore (2026-10-19).** At war with none of the player's buildings in reach, the line goes for the field the player will want
  next, so that growing means trespass: the ores the player mines (its drills' targets; iron and copper before any),
  in 48-tile cells beyond the claim with 150 tiles or more and none of the player's drills, the richest (counted to
  600), the nearest. Kept until the claim covers it or a drill stands on it; the cordon builds its arcs toward it, with no named
  warning (a field is not the player's yet). Only with none of the player's buildings in reach: a first version
  (fields on Serenity's side of the player's front) turned the cordon away from the player's buildings and failed
  `cordon` (four mixes) and `bend` in the full regression. So: an enemy out of reach, the line claims the ore it will
  need before it comes; within reach, it goes for its buildings. `strangle ore` (no main position): the arcs at 101
  degrees against the placed field's 96 (seed 12345), at -22 against -17 (777); `strangle oreoff`: no ore target.
  **The line cuts what crosses it (2026-10-19).** At war, every 30 s, the player's belts, pipes and loaders standing on
  the claim's edge (within 1.5 tiles) are blown, eight a pass at most, an explosion each (the tell). A supply line
  through Serenity's ground stops at its line. The counter is under it: an underground belt or pipe with both ends off
  the line passes, as the span between holds no entity; or around it. Rails are left alone (the trains are the
  player's army transport). `strangle sever`: at war, R 90, a belt and a pipe across the edge: the 6 tiles on the line
  cut, the 16 off it standing, an underground pair under it standing.
- **Hazard removal (built 2026-10-19; Fable's buffer consult, docs/reviews/2026-10-19-buffer-consult.md).** On nw
  Serenity stood between the factory and the nests its pollution draws, and spent three hours absorbing the waves
  (116 responses, 1,236 buildings lost, 7 razed). Fable: "a bug in outcome, a feature in physics": keep the waves,
  change the answer. A camp that lost 20 buildings or units to biters within 30 minutes clears the nest nearest those
  losses (within 300): the clearance siege it already had for nests in a raid's way (railgunners, mortars or a
  howitzer), chosen after counter-battery and before raids; tried again every 5 minutes while the losses stand. Its
  strength gates it (a clearance waits for its railgunners and parts), so a camp barely holding does not go hunting.
  Its tell: a siege going out away from the player, and the lane going quiet. Scenario `hazard`: four spawners 250
  out on its far side, a scripted wave of 24 every 3 minutes while one stands: 24 lost, one clearance, the four dead,
  the waves stop; `hazard off`: 13 waves, 48 lost, the nests standing.
  On nw (3 hours provoked, run beside a regression so its ms are void) it never cleared: from minute 35 it lost 20 to
  77 to biters each half hour, but the nest nearest the losses had worms beyond even the howitzer, and it was chosen
  again every 5 minutes for two hours (now a nest resting from a failed clearance is passed over for the next), then
  "waits for railgunners (0 of 8)". Responses 116 -> 33, its losses 1,236 -> 236, razed by it 7 -> 39, and the
  player's robots and land mines lost 1,211 and 2,232 (its jammer and its units on the minefield): one run each, other
  changes between them (staggered beats since withdrawn, the cut, the next ore), so read as a direction, not a measure.
  Why it never fired there (2026-10-19, second day): the howitzer's site was sought only 53 tiles from the nest, and a
  behemoth worm's 48 plus the guards' ring (14) leaves nothing at 53: every nest by the camp "outranged even the
  howitzer". Now it is sought out to its reach less 10 (53, 65, 77) on nine bearings. And a clearance waiting for its
  railgunners has them made over the garrison's cap (production stopped at the cap, and a full garrison of other kinds
  made none: "waits for railgunners (0 of 8)" for two hours), up to the eight it waits for. The hazard trace now says why
  it waits (parts, railgunners, out of reach, resting). Scenarios (40 a wave): `hazard worm` (a behemoth worm by each
  nest): a howitzer siege from 78 tiles, the four nests cleared (the old code: "outranges even the howitzer", none);
  `hazard norails` (no railgunners given, the garrison kept over its cap with Line troopers, ten more every 2 minutes):
  the first clearance by minute 20 (the old code: 35, once the waves had worn the garrison under its cap). Both run on
  the old code to see them fail. Whether the cap is what held nw is not shown: it may have been parts; the next nw visit
  says (its trace now names the reason).
  The next nw visit (provoked at an hour, 3 hours, run alone, 0.1.21): the reasons were parts first ("parts 24 of 220"),
  then railgunners, then sites. Four clearances went (three by howitzer from sites the old search had not found): the
  first found its nest already gone, the second lost its eight railgunners to behemoth spitters at the site after nine
  shells, the third fired 80 shells. Losses against the run with no hazard removal: buildings 1,236 -> 720, units 328 ->
  171, responses 116 -> 72 (one run each). It built 138 railgunners and lost most of them: holding a site in nw's nest
  field is costly. Script cost: mean tick 0.601 ms against the save's 0.521, script 0.043 ms; 44 ticks over 50 ms, two
  causes found: Serenity's power survey on the meshed network (65 ms every 5 minutes at war, "no single cut" each time:
  now not searched again while the player's pole count is unchanged, every 30 minutes regardless) and Grubstake's
  sneaking raids staging inside the ring (95 to 125 ms a failed search, nine times: a failed staging point now stands
  for 90 minutes and 128 tiles, from 30 and 64). Both not yet measured on a visit.
- **The ledger (built 2026-10-19; the consult's second part; `scripts/ledger.lua`, Serenity's temper `bills`).**
  Every 5 minutes a camp that has tried to remove the hazard itself bills its losses to biters since the last bill (8 a
  building, 3 a unit, in worth: a circuit is 1), when the nest nearest those losses sat in a cloud (pollution on its
  chunk or absorbed by it) and a polluting building of the player's (drill, furnace, assembler, boiler) stands within
  1,000 tiles of it. The bill goes up on an invoice post at its line on the bearing to the player's spawn: a chest of
  the player's force, so it opens, in Serenity's colour, not minable or destructible, the sum written over it. What is
  put in it is taken by its worth (circuits, modules, steel and the like; the rest stays) and becomes parts.
  First built for a provoked-only Serenity: unpaid 20 minutes after the third open bill, the player became an enemy. On
  nw unprovoked (3 hours) it billed five times, 355 to 614 a bill, 2,170 owed within half an hour, and turned enemy 20
  minutes after the third; losses whose nest had no cloud on it went unbilled. Since Serenity is at war from landing
  (below), paying off buys a truce instead, the only quiet it gives: a minute for every 10 paid since the last truce, 10
  to 60; no raid, siege or cut and its line holds while it lasts (stance "truce"); the post says how long is left and
  shows an amber light by night. Unpaid, nothing changes. Counters: pay, clear the nests yourself, keep the cloud off
  its ground.
  Scenarios (the `hazard` waves, 40 a wave, the clearance held, a furnace by spawn the test keeps standing): `hazard pay`
  (the test puts what is owed in the post each minute): 5 bills, 440 paid, 5 truces, a truce seen; `hazard unpaid`: 6
  bills, 407 owed, no truce, at war; `hazard clean` (no cloud on the nests): no bill. The price is a guess.
  Disputed (2026-10-20; Fable's engagement consult: "invoices disputed in the field"): each bill names the nest whose
  waves it was; the billed player who kills that nest while the bill is open strikes it (its sum off what is owed;
  nothing left owed and no truce running, the post comes down). A nest killed by Serenity or anything else strikes
  nothing. Billing comes after the losses, so the consult's "before the wave lands" became "while the bill is open".
  While a bill is open, the nest it names carries Serenity's icon (in its colour, in game and on the map, for the billed
  player only): the world says which nest, no notice. `hazard disputed`: a billed nest Serenity killed, 120 still owed;
  another, marked, the player killed, its 145 struck. The mark has not been seen in a screenshot yet (`scripts/shots.sh`
  wants the display awake).

### Serenity at war from landing (the user, 2026-10-19)
The user: "I'm left to wonder what's the point of serenity being non hostile sometimes… feels like a typical
player-like smart adversary that would make gameplay more fun with constant hostility?", then, offered a grace period
after landing: "No grace". Serenity had been provoked only (a rival until its buildings or units were hurt, its ground
built on, a turret set in reach of it, or, last, a bill left unpaid). In the visits that rival phase was either dead
time or ended by accident. Now its temper is `hostile`: the stance (`stance.standing`, `standing.get`) reads enemy from
landing, so its campaign runs from the start: the line steps toward the player, strangles, cuts belts on its edge,
surveys power, besieges. Provocations still drive the answers, the grudge and the ladder. The only quiet is a truce
bought at its invoice post (the ledger, above), and under a truce its line holds (`ops.perimeter`). Grubstake stays a
thief that escalates when hurt: the contrast is part of both identities. The `provoked_only` flag stays as Serenity's
marker for its line (border, perimeter, cut).
- **The border stake** treats only under a truce now (it had needed a rival Serenity, and "does not treat with
  enemies" would have left it dead): a stake set during a truce bought at the invoice post draws the border, and the
  border holds after the truce ends, until something of the player's stands on Serenity's side. Refused at war, it says
  a truce opens talks. `border`: a 5-minute truce, the stake accepted, the line held short of it, at war after.
- **The tests that assumed a rival Serenity** (the full regression, 162 of 172 at first): `temper` now checks that it
  strikes first, unprovoked, at relays outside its territory; `line` holds raids (they razed the relays before the line
  reached them) to watch the line grow, warn, enclose, and be provoked by a build inside (the turret mix lets raids go
  once the turret stands, for the siege that answers it); `crew dronekill` checks the kill is recorded as a provocation;
  `strip claim` and `crystal marker`, Grubstake's, give Serenity a truce (it raided the drill and the outpost they
  watch).

### Grubstake against a fortress: the skim (Fable: `docs/reviews/2026-10-19-grubstake-fortress-consult.md`; built 2026-10-19)
On nw Grubstake did almost nothing a player would notice against the sealed ring: nine of ten operations aborted (no
way round 117 turrets to any substation), flares never flew (no nests left near the walls), nothing looted. Fable: a
burglar does not breach a bank, but nothing showing reads as a bug; aim for "I am being skimmed", never "I am
besieged". A fortress cannot wall in what feeds it.
- **The skim** (`scripts/skim.lua`, Grubstake's temper `skims`, a theft in the stance: a rival thief steals, a truce
  stops it). A camp finds a player's belt within 150, then 300, then 500 tiles (250 alone found none on nw) that carries
  something and that no turret reaches (30), whose straight line from the camp passes no turret's reach, and sends a
  truck by a route clear of every turret's reach (the heist's). The truck parks by the belt and lifts half of what passes
  (the tile's fill times a full belt's rate) into its trunk, for 5 minutes or 120 items, then drives home: the goods go
  into the camp's yard (a steel chest in its colour, the goods' icon over it) as items, their worth into parts. It comes
  back after 5 minutes. Kill the truck and its load spills where it stopped; destroy the yard and what it holds spills.
  The tell is the truck parked at the belt and the gaps downstream. Counters: an underground across the exposed
  stretch, a turret by the belt, hunting the truck, raiding the yard.
  First built as a siphon shack dropped by a buggy, an amber arm to the belt, and trucks to empty it; the user: "I
  think you're getting too cute with it. Why not a truck simply going to the belt, hovering part of the items, filling
  its own trunk, then leaving?", and "No amber line". Scenarios: `skim` (a belt of iron ore 150 tiles from the camp,
  fed and emptied by the test): three runs in 27 minutes, 67 items a run, 254 home in the yard, 5% of the belt's flow;
  `skim guarded` (an armed gun turret by the belt): no truck; `skim raid` (the yard destroyed at minute 24): 134 held,
  134 spilled.
  On a reference factory (the user: "Did you not test the skim on a ref save?"): their outposts now belt their ore home
  through the wall to a loader into a voiding chest (`tests/lp-ref`, 344 belt tiles on the laser base; they had filled
  chests, and no belt outside the wall carried anything). One hour on the laser base: three runs from minute 29 (one
  truck stuck on the way), 16 items a run: that outpost's belt carries under an item a second, so a 2-minute stop takes
  little. The truck is the tell more than the loss (open: a longer stop or a bigger share).
  The user: "Take should be at least 50%". Now half of what passes, until the trunk holds 120 or 5 minutes pass: `skim`,
  four runs in 27 minutes, each full in about a minute, 480 items home.
- **Dismantling** (the user, 2026-10-19: "Stealing items and buildings is genius for a more early game rival"; Fable's
  "carry it off instead" of the ladder top razing 247 panels). A Grubstake raid with machines at its target walks in
  answering only what hits it (a thief takes rather than shoots: raiding as an army, it razed three of four assemblers
  before its first step could take one). Each step, every raider within 8 of a machine takes one apart (assemblers,
  furnaces, drills, labs, solar panels, accumulators, beacons, radars, boilers, generators, inserters, poles, pumps,
  tanks, roboports; machines first; not walls, turrets, belts, pipes or rails), its contents with it, and leaves its ghost
  where it stood: the outline of what was stolen (robots rebuild it at the player's cost; early on, with none, the hole
  stays). Twelve a raid at most. With nothing left to take it attacks as any raid. A raid's loot now stays items: home
  in the yard (the skim's), its worth in parts as before; all raiders killed, it spills where they fell. Scenarios:
  `dismantle` (an unguarded outpost of four assemblers holding plates, two solar panels, a pole, a chest): 7 ghosts, the
  four assemblers and 160 plates in the yard; `dismantle ambush` (the raiders killed once two machines are gone): 178
  items on the ground, none home.
- **First visits (0.1.22, provoked at an hour, 3 hours).** deathworld: Serenity razed 520 of the player's buildings,
  Grubstake 253 (one camp 173) and looted 829 items; its raids dismantled long-handed inserters and medium poles (what
  stood by its targets), a few a raid. Script 0.046 ms a tick (the save 0.31 ms, the visit 0.51), four ticks over 50 ms
  (worst 89; 128 on 0.1.20). The skim never fired there or on nw: "0 exposed belts carrying in reach" (the trace now
  says how many belts it looked at and how many carried). nw crashed at the claim jumper's heist: it loots through
  ops.loot, and dismantling read raid members it does not have (raids only now; `jumper` has an assembler by its chest,
  and the old code crashes on it).
- **nw on 0.1.23** (3 hours, provoked at an hour, alone): 20 ticks over 50 ms (44 on 0.1.21), the power survey every 30
  minutes on the unchanged mesh. Grubstake's raids dismantled 72 buildings (accumulators by its targets, as Fable
  asked of the ladder top), looted 72 items, razed 221. The skim looked at no belt at all: its camps stood more than 250
  tiles from every one (now rings of 150, 300, 500). Serenity's camp fell at the end, to biters (277 of its losses were
  to them): at war from landing, in nw's nest field, it held less well than when it sat out the first hour (open).
- **The skim on real saves (0.1.24, 90 minutes each, provoked at an hour).** With rings out to 500 it saw 225 to 258
  exposed belts carrying on nw, but the three nearest lay inside the laser ring ("no route"). Now only belts whose
  straight line from the camp passes no turret's reach (sampled every 25 tiles, 40 looked at) are routed. On nw that
  left none for one camp and only belts across the big lake for the other ("no route"): nw is sealed by lakes and
  lasers, and the skim rightly finds nothing. On deathworld it went once, at minute 50 (the shack then). One in 90 minutes is under Fable's bar (three an hour); both saves
  are fortresses. On probation: a save with outposts wired by belts, or a mid-game base, is its real test (open).
- **From Fulgora Replicators** (the user, 2026-10-19: "It has similar mechanics and is quite well done"; a Space Age mod
  whose replicator nests raid on a night schedule, take from belts most valuable first, drop what a killed raider
  carried, and grow a mineable scrap patch at their core with what they stole). Taken: the skim's truck lifts the most
  valuable items first; a raider killed with loot drops its share where it falls (it had spilled only when the whole
  raid died; `dismantle ambush` now finds the loot at two spots or more). Not taken: a grudge raid on turrets (Landing
  Party's answers and ladder do that work).
- **Thieves' hours** (Fulgora Replicators' raid nights; the user: "that seems great"). Grubstake's thefts set out only
  after dark (darkness 0.3 or more): its raids on the player (`temper_allows`), its skims and its claim jumps; a skimming
  truck leaves at dawn. Its answers to the player's attacks, flares included, come any time. A surface with no night
  (always day, or day frozen in daylight) has no hours. Its trucks show headlights by night, turning with them. Serenity
  keeps its campaign round the clock: the two read apart. The scenarios run with the hours off (`night_off`) but
  `skim night` (a 6-minute day from noon: three trucks set out at darkness 0.38, 0.74, 0.46, one left at dawn) and
  visits.
- **Raid leaders** (Jungle Raiders' Alpha, from the research the user asked for: "Any other cool things to draw
  inspiration from?"; `docs/reviews/2026-10-19-inspiration-research.md`). A raid of three or more has a leader (an infantry
  where it has one), its corporation's icon over it, so the player can pick it out. Killed: Grubstake's raid breaks and
  runs home with what it carries ("fled"); Serenity's falls back to its staging point in order, a new leader takes the
  icon, and it goes in again with what it has (the staging look that turns a short raid back is skipped then: it turned
  back with 3 of the 4 it wanted). Scenarios `leader` (Grubstake: fled, 3 of 4 home) and `leader serenity`
  (regrouped, then done with 3). Grubstake's foreman carries the haul (2026-10-20, Fable's engagement consult: "kill
  the leader and the party drops its load"): killed, it drops all the raid's loot, and the raid runs home empty
  (`ops.raider_died`; another raider drops its share). `leader haul` (chests of plates at the outpost): 404 carried,
  all dropped by the foreman, none home; with the foreman dropping a share only, 103 dropped and 303 reached home. Next from the research: the yard as a pile that grows with what was stolen, an
  itemised invoice with a gauge on Serenity's post.
- Next in the consult: mine sweeping, a bird net for robots, the brood run.

### Space Age (the user, 2026-10-18: "I think it's okay to rely on space age. We might get some great use of some of its
parts")
Space Age is a dependency now (`info.json`), and the simulations load it with Quality and Elevated Rails (they had run
the base game alone). What it brings so far:
- **Landings by cargo pod** (`scripts/pods.lua`). A pod made by script descends to a spot exactly (a spike: 399 ticks,
  6.65 s, leaving its remnants). A landing queued as the faction's own are (the asynchronous landing jobs) finds its
  site first (`faction.arrive` site only, `layout.find_pad`: where the lander would stand, nothing placed), sends a pod
  there and two escorts beside it, and lands where they touch down (`opts.at`); a pod lost or later than 20 s, it
  lands all the same. The remnants are cleared 3 s after each touchdown. Scenario `podland`: three pods, the landing
  420 ticks after them, no remnants; `podland off` (`pods_off`): at once, as before. Direct landings (the tests',
  `/lp land`) stay immediate.
- **Relief by cargo pod**: a relief with no sister settlement to march from (the drop behind the camp) comes down in
  pods, four units a pod; its units come out where each touches down (`pods.handlers.relief`). `pods_off`: dropped at
  once, as before.
- **The jammer's arcs are tesla beams** (`chain-tesla-turret-beam-start`, whose own damage fires only from a turret's
  chain: light alone), to where each robot was. `fortress jammer`: 60 of 60 arcs beams.
- **The railgunner sounds like a railgun** (its gunshot). Its beam drawn along the shot's line was tried and withdrawn:
  with it a siege's assault failed (`bombard`, seed 12345: 10 of 22 back and aborted, against 17 of 22 and done;
  reverting that line alone restored it).
- **Retuned for Space Age**: the Shotgun hand fires every 64 ticks, not 60 (`arms`: 630 against the Line troopers'
  810 with Space Age, out of parity; 690 with 64, as in the base game). Serenity's gate opens at the first rocket
  launch with Space Age (`phases` opens it so: `debug_late_gate`). `crystal marker` starts unprovoked (provoked,
  Serenity, whom claim markers do not hold, raided the outpost it watches).
- **Armour you can read**: Serenity's Line troopers, lance and shock troopers and railgunners wear the mech armour;
  Grubstake's Shotgun hands and sappers, and the player's troopers and breachers (whose recipe takes a heavy armour),
  heavy armour.
`rail`'s "half stood" became "one stood at least": survivors on three seeds were 2, 0, 3 on main and 1, 2, 2 with the
railgun, so the old line failed one seed or another by chance.

### Reference factories (2026-10-18; the user: "Can you look online for better control saves?")
Online, the 2.0 saves are benchmark megabases (factoriobench.com): no biters, no defence, built for speed. So the
controls are built: `scripts/make_reference.sh <kind>` (`tests/lp-ref`, without Landing Party) on seed 1234 with
default biters, one working core for all (126 assemblers making gears from infinity chests, so they pollute; labs,
belts, solar, accumulators, substations; two mining outposts outside the wall wired home by big poles), and its
defence by kind. First visits (provoked at an hour, three hours, x1):

| Kind | Defence | Razed by the corporations | What stuck |
|---|---|---|---|
| belt | 88 gun turrets, no robots | 17 turrets, 29 walls, a few others | 70 turrets of 88 left; biters took both outposts' drills |
| laser | 116 lasers, 25 roboports | 15 roboports, 5 lasers, 20 walls (Serenity's 5 sieges) | robots rebuilt 41, 32 ghosts unbuilt at the end |
| artillery | the same and 6 artillery turrets | an outpost (8 drills, 17 poles), 2 lasers, 12 walls | Serenity's 10 sieges razed nothing: the artillery outranges them; Grubstake looted 800 |

At x1 the defence holds everywhere; the laser base is the one where the fortress work shows (roboports shelled, and
the robots fall behind). The artillery base answers Serenity's sieges as the consult said it should (counter-battery).

### Landing in nest country (2026-10-18; the user: "On some maps you will only get dense fields of nests you know")
On nw Serenity landed with no spawner within 100 tiles and 132 nests and worms within 250, and spent three hours at war
with biters (369 turrets, 227 units lost). A site's density now counts: more than 30 nests and worms within 150 (the
ground generated round a candidate) is a nest field. The near rings (to 480 tiles out) are searched refusing fields
first, then searched again taking the least dense site of a ring; only then further out (avoiding fields everywhere,
the landing went 900 tiles further out, away from the player). On nw: the same site, the least dense near, its landing
barrage 8 spawners and 12 worms. A clearance's site is out of every worm's reach by its guards' ring (12) and more:
six railgunners guarding 24 tiles round a site just out of reach died to big worms 5 to 10 tiles from it.
Found: Serenity's losses to biters on nw all came from the side facing the player's factory (W 140, NW 152, SW 108,
N 42, none east, nests all round): the waves the player's pollution draws, or fights its turrets start with them, in a
corporation that landed between the nests and the player. The buffer stays (a neighbour in the lane takes the waves;
Grubstake's pact spares it).
Tried and withdrawn (same day): the lane. Its losses to biters in 10 minutes, 10 or more, gave a bearing; its decider
went first for a clearance of the nest nearest home on that side, and when none could go (no railgunners left, 0 of 8;
worms beyond the howitzer) bought an orbital strike there (12 parts a shell). Three hours on nw, losses to biters a
10 minutes: with it 0 0 0 39 123 98 64 122 143 164 186 171 65 22 69 16 6 19 (about 1,300); without (`laneoff`) 0 0 0
39 49 45 49 78 82 104 72 109 33 62 75 38 2 3 (about 840). It lost more: the strikes spent 60 to 432 parts it then
lacked for rebuilding, and shelling the field seemed to stir it; both quiet down in the last hour. The clearance itself
never launched. Open: how Serenity holds a lane of nests between it and a polluting player (its railgunners, its
economy under attrition), or whether it should.

### The levers: strength and aggression (the user, 2026-10-18)
The user: "once we are [confident in the mechanics], I think we could simply implement scaling variables for strength
and agression sort of like what biters have at world gen, and balance through those". Four runtime-global settings,
two a corporation (`lp-<corp>-strength`, `lp-<corp>-aggression`), each a preset (very low 0.5, low 0.75, normal 1, high
1.5, very high 2; `shared.TUNE`), read by `scripts/tune.lua`. Each drives a set, so a preset reads as one thing:
- **Strength**, how much it fields: a camp's unit cap (`army.cap`, before the ladder's and the grudge's multipliers),
  and the biters a Grubstake flare calls. The economy is not scaled: a strong camp at a poor site fills its cap slowly.
- **Aggression**, how soon it acts: its ladder's clock runs faster (`stance.rung`); the gaps after an operation, between
  answers and between heists (flare, claim rig, tap) are shorter (`tune.sooner`); and it keeps at a front where it razes
  nothing longer before standing down (`war.quiet`: the hour times aggression).
Runtime-global so an admin can change them in a running game (only the owning mod may write a setting from script:
`debug_setting`). Scenario `levers`: Grubstake's settings to very high at 2 minutes: its cap 10 to 20, an hour-long span
30 minutes, its ladder at rung 1 at 8 minutes where Serenity's, normal, is at 0. Sweeps: `LP_MIX=...-S2-A0.5` sets every
corporation's levers in any scenario or visit (`debug_tune levers`).

The first sweep (2026-10-18; deathworld10x, provoked at an hour, 3 hours, no robots in that save, both levers moved
together on both corporations):

| Levers | The player's buildings razed by the corporations | Gun turrets left (205 at the start) | Lost to biters |
|---|---|---|---|
| x0.5 | about 90 | 189 | 0 |
| x1 | about 650 | 136 | 26 |
| x2 | about 1,650 (Grubstake's first camp 1,056) | 66 | 75 |

The response is monotone and steep at the low end: very low reads as a quiet neighbour, very high takes two thirds of the
turrets in three hours. Mean tick at x2 0.46 ms against the save's 0.28 (alone on the machine). Outcomes do not
depend on load (three visits run together gave identical results). Each lever alone (x2, the other at x1): strength about 1,100
razed and 77 turrets left (it takes turrets); aggression about 1,350 and 102 left (it spreads: more assemblers, chests and
loot). Both carry their weight.
The factory that fights back: nw (lasers, 671; 577 roboports; land mines; no artillery), provoked, at x1: the
corporations razed 30 things in three hours, its robots rebuilt every one (and 329 mines), no ghost left; Serenity lost
85 units in six operations, all aborted. Against a robot-kept laser base the default is no threat. Not yet: the presets
calibrated (whether normal should scratch nw, and very low stay this quiet on deathworld).
Two harness faults the sweep found: a visit's levers were set after `on_init`'s early return (all three runs came out
identical), and in a single-player save the absent player's character, killed by a Grubstake raid at minute 108, ended
the game: the benchmark ran its last 72 minutes as empty updates and wrote no results. The character is now
indestructible on visits, and a scheduled step that errors is a failed check with the results written.

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

**Built: corporations and biters.** Serenity is clean (its drills emit nothing); Grubstake's drills pollute (its own
section). Measured first: a
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

### The third corporation: biotech (the user, 2026-10-21; brief `docs/biotech.md`; engine tests 2026-10-22; first slice 0.1.51)
Chosen from five candidates (`docs/third-corporation.md`, three consults): a corporation that breeds biters, lives in
nests, is at peace with the wild biters and sends waves with intent; Grubstake's flares are retired for it. Engine tests
(throwaway spikes, details in the brief):
- Engine: a force at cease-fire both ways with `enemy` never fights the wild biters, its herds included, marching
  through a wild nest; a third force at peace with `enemy` (Grubstake) is attacked by its herds with no wild biter
  joining in.
- Engine: a `unit-spawner` on a script force spawns for that force, choosing by that force's own evolution factor. A
  wild spawner whose force is changed breeds for its new owner but keeps the wild look and the wild breeds: holding a
  nest means a pen in its place.
- Engine: Space Age's captive-spawner graphics on a unit-spawner copy work (the pen); retinting a biter's mask layers
  (`tint` in its run and attack animations) makes bred biters read apart from wild ones.
- Trial: the same 40 biters against identical ringed bases (heavy side facing them, lasers on one power source). A plain
  wave died for 3 turrets; a coordinated one (a scout's loop outside turret range, then round to the side it saw least
  of, a two-segment breach, straight to the power with no distraction) killed the power in 36 seconds for 4 losses.
  Intelligence is cheap to script and worth an army, so its tell and its counters are the design problem.
- Fairness trial (intel by sight only; a dead scout means a blind wave): spreading turrets evenly did not stop it; power
  under the guns, a second power source, or killing the scout (two outer turrets on its loop) each did. Table in the brief.
- Direction from the consult (`docs/reviews/2026-10-22-wave-intelligence-consult.md`): a pack, not the others' moves (the
  trial's breach-to-power was Grubstake's sneak plus Kessler-Hayashi's blackout). **First slice built 0.1.51**
  (`biotech.lua`, `scripts/herd.lua`): the scout's loop round the turrets' box and its mark at the face it saw fewest,
  the trail (mud and a map line, 20 minutes), the herd's march and withdrawal fighting nothing, a two-piece breach, what
  feeds the guns (power, gun turrets' inserters, flamethrowers' pipes) passing over any target under three turrets, home
  after. A loop not whole is a blind wave and a wider loop next time; turrets cannot catch the scout (it loops round them),
  troopers outside the wall can. `shared.is_corp` is now exact (the two corporations' forces) and `shared.is_biters`
  covers wild and bred. Scenario `herd`, eight variants; results in the brief.
- Engine: a unit standing in a chunk not yet generated cannot path; every move it is given fails at once.
- In the arena (0.1.52): bred medium 6 parts, bred big 28 (`shared.BREEDS`, provisional), ground-only like the corporations'
  ground units. Class scores: against small arms +40, splash -60, armour +45, air -100. The railgunner wins against both.
- The breeds consult (`docs/reviews/2026-10-22-biotech-breeds-consult.md`; 0.1.53): the stock was Grubstake's swarm with
  an armour-killing bite. A bite damage type (`lp-bite`) that hulls resist 60% (walker, spidertron 40%); bred medium 7.
  Class now: small arms +48, splash -69, armour -5, air -100. The roster by tier, the scout as a bred strafer (spikes
  first), home defence and what is not built (no lightning breed: electric is Kessler-Hayashi's) are in the brief.
- Its arrival (0.1.54, `scripts/farm.lua`): at the wild biters' evolution 0.25, by cargo pod, on the nearest nest field
  600 to 1,000 tiles from the player's factory (1,500 if none); four pens, two worms each, a map tag; waves of 24 to 60
  every 20 minutes at most, by waypoints; a pen hit recalls its wave; every pen dead, it lands elsewhere an hour later.
  `/lp biotech`, `/lp wave`. Scenario `farm`: a wave walked 750 tiles of the map's own ground and killed the power.

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
- **Every tier pushes in (2026-10-17).** The user, after `/lp siege`: "a group comes in, deploys a howitzer,
  successfully destroys turrets, then nothing happens. The whole group ends up packing up and leaving home. I would
  think once the barrage ends (be it because no target or no ammo) they try to push in?" Tiers 1 and 2 had no assault.
  Now the barrage is over when nothing is in reach for 30 s after the mortars had targets, or when the shells are spent
  with no convoy coming; tier 3 and up assault as before, and below that the guards go in when they and the garrison's
  spare units make the force a raid there would need (`needed(defence)`); short, "siege: no assault (N needed, ...)" and
  it waits or packs up. Not for a clearance. `bombard` (tier 1, 8 turrets): no assault at first (22 needed, 6 guards
  and 15 spare), 10 s later 22 went in and razed the position (16 back); the new check failed on the old code (0
  assaults). `siegetier` 2, 3, sally and convoy and `clear` pass unchanged.
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

### Pressure that ramps: war footing and the war chest (the user; Fable: `docs/reviews/2026-10-15-pressure-ramp-consult.md`; built 2026-10-15)
The user, on the visits: "it's not good that only the first raid does anything; ... raids should be able to ramp up with
the logic you built, supposedly?" They should not, as built: a settlement's units came only from its drop escort and its
own parts, and the ladder raised its willingness, never its capacity. On nwa's expansion visit the camps that reached the
player razed in their first 30 to 40 minutes and then sat at a garrison of nought (their parts went on rebuilding what
the artillery broke, their drills kept dying); four of seven fell; the far ones survived and could not reach.
- **War footing** (`scripts/war.lua`): a settlement at war (it knows a player force's buildings and its temper lets it go
  for them: Grubstake always, Serenity once provoked) and short of its unit cap holds every rebuild but its generators and
  depots (`base.footing`, asked by `rebuild`): its parts go to units first.
- **The war chest**: 20% of each corporation's exports (the research fund keeps its 30%), capped at 6,000, and every
  player building a Grubstake unit razes pays it (10 + 5 x its value, as salvage rights pay research). Every 10 minutes a
  corporation sends one settlement at war on rung 1 or more (the highest rung, then the most short of its cap) 8 units a
  rung, at 1.5 times their cost, fewer if the chest is short (at least 4). They count above the cap.
  - Grubstake: a pod, 40 tiles behind the lander (away from the player's buildings it knows), the units walking in.
  - Serenity: a relief column from its nearest other settlement, along a route clear of turrets and nests
    (`ops.route`); no route, no relief. It joins on arrival (or after 10 minutes, wherever it is); killed on the way, it
    is lost. With no other settlement, a drop at the lander at half strength (my addition to the consult: a lone camp
    under the guns would otherwise get nothing; to review).
  - Notices: `lp.relief-pod`, `lp.relief-column`, `lp.relief-drop`, with the settlement's map position.
- **The ladder buys capacity** (built 2026-10-16): a settlement's rung against the player it is at war with
  (`b.war_rung`, set each minute in `war.lua`) raises its unit cap by half from rung 2 (`army.cap`; the consult said
  double, half is the first step) and adds a siege tier from rung 3, past the budget (`ops.siege_tier`). Scenario
  `ladder desperate`: the cap went from 20 to 30 at the second rung.
- Not built yet from the consult: entities written off after two artillery kills. (The write-off and relanding became
  standing down, below.)
- Parked: moving Serenity's flamers off its gate roads. It would not stop them burning their own units: the burning
  ground lands where the enemies are, and vanilla fire cannot be told to spare a force.
- Scenario `reinforce` (the ladder's desperate setup, a chest of 3,000, a relief every 2 minutes): drops of 4 then 12, the
  garrison 15 past its cap, the chest down to 2,610, the lasers razed. `starved` (chest empty): nothing comes. `column`
  (a sister settlement): columns of 8 and 24 from the sister along 13 waypoints, arrived in 50 s; 32 reinforced in all.
- Two bugs from the visits, fixed with it: a clearance site 33 tiles from a big worm (range 38) or a behemoth (48) sat
  inside its reach, and Serenity paid for a siege and lost its hauler every two minutes all night (the site now keeps out
  of each worm's prototype range plus 2; a nest that outranges the mortars, or whose clearance lost its hauler, rests 15
  minutes; `ops.clearance` never read the target's rest before). And a raid of nought was launched when the units
  `field` counted were haulers or dead.
- Visits: `LP_MIX=noart` removes the player's artillery (turrets and wagons) at the start (the user: artillery's area
  denial at a megabase is expected; without it, what the corporations do against the rest). Saves besides nwa: `b -
  rocket` (174 technologies, 5,638 buildings, 790 lasers, 28 artillery: about a first rocket), `nw` (190, 5,433, 671
  lasers, no artillery), `deathworld10x` (34 technologies, 1,574 buildings, 205 gun turrets: early, a deathworld).

### Biter country: Grubstake's pact (Fable: `docs/reviews/2026-10-15-biter-country-consult.md`; built 2026-10-15)
Baseline visits (three hours, before the war chest; razing is the player's buildings, a 10-minute row):
- `deathworld10x` (the early save, the one landings are meant for): 32 razed, a zero stretch of 50 minutes. Grubstake
  landed 110 tiles from a nest field and fed 3-unit biter responses into it for three hours: 266 units lost, nothing of
  the player's razed, though it knew 7 targets. Serenity (not provoked) hit one spawner six times with four units: the
  raid's end forgot the nest with what it learned (resistance, tries), since `sense` sees no spawners. Fixed: a nest
  still standing is kept.
- `nw`, `b - rocket` with its artillery removed (670-790 lasers): nothing razed in three hours. Pass 1 of the landing
  search refuses any site with a spawner within 60 + 40 x evolution, over every ring to 1,800 before nests are allowed, so
  camps landed 1,000-2,100 tiles out with 130 nests between them and the player; raids died within 12 s of leaving.
- `nwa` with its artillery removed (the ground it cleared still clear): camps in the cleared band, 770 razed, a curve that
  ramps (0, 93, 0, 1, 30, 20, 30, 74, 72, 76 ...). Where the approach is clean, the machinery ramps.
Fable: razing depends on the approach, never on the site. Built first, its item 1:
- **The pact** (`temper.pact`, Grubstake; `pacts()` in control.lua): a cease-fire both ways with the enemy force. Spike
  first (a throwaway mod, Factorio 2.0.77): five worms held fire on its gun turret 12 tiles away, eight behemoths sent at
  its radar by `attack_area` left it, its turret did not fire, a biter on its force walked through the nest; the same
  group sent at a player radar destroyed it. Its marches no longer route round nests (`ops.pact` in `sneak_route`), it
  lands among nests (no refusal, no clearing burned), and biters become a shield against Serenity and none against it.
  `debug_tune{pact_off}`.
- **The pacifier antenna** (the user: the pact needs a lore reason, "a biter pacifier antenna in their outposts";
  `scripts/pact.lua`, `lp-pacifier`, a self-powered radar dish, 1,500 health, a military target worth 8): each Grubstake
  landing puts one beside its lander. The engine's cease-fire is per force, so the pact is the corporation's: it holds
  while any of its pacifiers stands; the last one destroyed breaks it (notice `lp.pact-broken`), and a pacifier is rebuilt 5 minutes after its loss while its lander stands (`lp.pact-restored`).
  The player's counter. Seen: biters that loitered at peace by a camp turned on it the moment the pact broke (eight
  behemoths took the lander).
- Scenario `pact`: eight behemoths sent at its lander, a wall of 17 spawners and worms between it and an assembler: 0
  units lost, the lander untouched, the assembler razed, every spawner standing; at 8 minutes the pacifier destroyed:
  the pact breaks, the camp and three big biters fight; rebuilt 5 minutes later, the pact holds again. `nopact` (the control): 43 lost, the
  lander destroyed.
- **Landing by approach** (pass 0 of `faction.arrive`, for a corporation without the pact): near rings first, a site
  refused only when more than `APPROACH_MAX` (6) spawners lie within 40 tiles of the straight way to the player (less those
  its landing burns within 80); nests beside it allowed, a nest-free site in the same ring preferred. The landing's trace
  says how many lay on the way. The older passes follow when none qualifies.
- **No squads into biters where turrets reach**: a biter-only alarm within 20 tiles of two of its turrets gets no response
  (the turrets answer); outposts out of their reach still get three.
- **Each corporation's own ladder clock** (`ladder(owner, corp)`, `storage.last_raze[owner|corp]`): Serenity's razes had
  reset Grubstake's clock, and Grubstake, knowing only a power line with 5.5 turrets on each pole, stayed at rung 1.
- **The ladder at 10, 20 and 30 minutes** (was 20, 40, 60): Grubstake's first hour on deathworld was empty.
- **Marches round water**: a sneak route that the 120-tile box cannot find is tried once over a box three times as wide; a
  target it still cannot reach rests 15 minutes (the same unreachable substation behind a lake was chosen every two
  minutes for half an hour). A raid waits for its column at the staging point by the march's length (`MARCH_SPEED`), not
  a fixed 90 s. Left to the engine (an empty route), raiders 240 tiles from a target round a lake never moved.
- Diagnostics: a raid that razes nothing says how near its nearest raider got; `ops.summary` lists what a settlement knows
  of the players (`player_targets`: kind, exposure, defence, resting, held by its temper) and its rung; the visit logs
  Grubstake's every 10 minutes and the first water round its lander.
- deathworld10x, 2 hours, with all of it: 37 razed (0 0 0 0 0 2 0 0 5 19 11), Grubstake raiding every 10 to 20 minutes
  from 30 minutes after it landed with 18 units (pods of 8 to 24 between), breaching the wall, 18 razed, 53 units lost
  (266 in three hours before, nothing razed). nw (a lake and 671 lasers): its known targets all behind both; nothing.
- **Parts for what makes parts** (`base.reserve`, from the regression's `occupy`): with its fabricators destroyed and
  their ground held, a settlement spent its last 646 parts on new blocks, units and turrets and never made a part again.
  The cost of every pending rebuild of a generator, fabricator, drill or pylon is now held back from new building, unit
  production and other rebuilds (which step aside in the queue); war footing keeps those rebuilds too.
- Still to build: Serenity's nests as clearances toward a known player target, write-off and relanding.
- Seen, not mine: `overflight` fails on the last commit too (a ground way round appears two minutes after the first
  refusal, no spawner having died); to look at.

### Serenity against nests: railgunners, the howitzer, clearances that work (the user; built 2026-10-15)
The user: "take the easy way out and give Serenity a biter clearing unit like a hand mounted railgun". Then, watching
the scenario in game (`scripts/watch-sim.sh`), the howitzer's balance and its cluster shells.
- **Railgunner** (`lp-railgunner`, Serenity's mix 2 of 10, cost 22, 140 health): a slug down a 30-tile line, 250 to
  what carries the `lp-biter` trigger target (enemy units, spawners and worms, tagged in data-final-fixes.lua), 10 to
  anything else, every 90 ticks; a harmless copy of the laser beam as its tracer (the borrowed beam did its own damage).
  Scenario `rail`: four (88 parts) kill sixteen big biters and two stand; nine Line troopers (90) kill one and all die.
- **Howitzer** (`lp-howitzer`, the artillery turret at full size): range 100, 8x the mortar shell's damage (the user:
  twenty shells a nest at 1x, three at 5x, "one too many"), the mortar's shells. A clearance takes it when the nest's
  worms outrange the mortar, standing 53 tiles out (a behemoth worm reaches 48).
- **Cluster munitions** (the user: Serenity's signature): every mortar and howitzer shell throws six bomblets round the
  blast (12 explosion over 1.5 tiles each, its enemies only), as the base cluster grenade does.
- **Clearances that work**, each found by a trace or by the user watching:
  - The hauler was made beside a depot inside a gated block (gates open for no unit) and drove at its own wall for 15
    minutes: it now starts past the outermost wall on the way to the site; the guards ride out with it.
  - A hauler no nearer its site for a minute is stuck: a clearance deploys there if the nest is in reach, else stops.
  - Railgunners only as guards, eight waited for (`CLEAR_RAILS`); the settlement builds them first while one waits.
  - Guard duty: every siege step, the guards attack biters within 24 tiles of the site (12 at a howitzer's) and walk
    back; the step runs every 300 ticks, and a `tick % 60` test had kept it from ever running.
  - A code review (agent) found the rest: the march and moving-up orders engaged on sight (railgunners walked up to the
    worms they saw), the hauler's route ignored worms, and nothing held the guards between steps. Marches now answer only
    what hits them and route round worms; a siege leash calls guards back every second.
- **The garrison leash**: a garrison unit beyond its settlement's claim plus 15 is called home (idle, units attack what
  they see, and followed biters into worms; leashed at 35 tiles from a depot instead, a settlement's far side went
  undefended and biters took 497 buildings).
- **Flamer friendly fire**: the base stream's splash hit every force (8 to 11 of Serenity's units a run); its own stream's
  splash spares its side. The burning ground stays (without it biters took a settlement apart); it still burns anyone.
- **The orbital barrage** (the user: "shells from above, before landing ... a very dramatic entrance"; `war.barrage`):
  Serenity landing with spawners within 120 has every spawner and worm there shelled from the sky, nearest first, a
  shell every 15 ticks, as many as each one's health takes (a spawner has 3,500: one shell each left all five standing),
  each the howitzer's blow with ten bomblets (`lp-orbital-projectile`); eight railgunners join its garrison; notice
  `lp.orbital`. Its kills (no evolution). A howitzer by the lander (the first try) fired 10 of its 60 shells: the nests
  were out of its line and reach. Scenario `clearing`: 25 shells, the five spawners within 120 gone in six seconds;
  `LP_MIX=watch` lands 30 s in, to watch it (`scripts/watch-sim.sh clearing`).
- Engine: a script-made artillery projectile works with `target` an entity and `force`; spawners have 3,500 health
  (the howitzer's "three shells a nest" is that).
- Scenario `clear` (a wall of 49 spawners 90 tiles out, evolution 0.6, the assembler beyond): a way cleared and the
  assembler razed, 27 to 38 units lost (67 before); `worms` (behemoth worms): the howitzer cleared 14 spawners in one
  siege with 33 shells, 64 lost (about 100 before).
- **Known limit**: on `b - rocket` (evolution 0.9, 790 lasers), landed among nests by approach, Serenity is worn down at
  home (1,300 to 2,600 buildings lost in two hours, mostly turrets and walls, rebuilt) and razes nothing of the player's;
  each clearance draws the nests' waves. Parked: the user, landings are for earlier games.
- **Looks**: the railgunner in Serenity's charcoal (not the Line trooper's slate-teal), 15% larger; the pacifier's dish 40%
  larger than a radar's, so the player's target is told apart. Not yet seen in game.
- **Grubstake squats nearer**: its landing keeps 60 tiles from the player's turrets and units (100 for the others), the
  biter-country consult. On deathworld its first site was the same (the nearer ground was refused for other reasons):
  its effect is unmeasured.
- deathworld10x provoked, 3 hours, by value (a belt tile 1, a turret 20; `razed_by_type`): 783 (349 before the pact,
  863 the pact batch unprovoked); rows from minute 80: 23, 226, 101, 4, 130, 149, 51; Grubstake 128 entities, Serenity
  42; three orbital barrages on landing (9, 15 and 43 shells).
- With the ladder buying capacity (2026-10-16, same visit): 1,537; rows from minute 50: 123, 56, 180, 1, 229, 89, 2,
  220, 521, 55, 3, 58; 354 entities (61 gun turrets, 194 belts, 83 walls); Grubstake 371 (three camps), Serenity 103.
  The longest quiet stretch is still the first 50 minutes (Grubstake lands at 20 on visits).
- Convoys that never delivered (fixed 2026-10-16): on every deathworld visit since before the pact, Serenity's first
  settlement sent some 65 export convoys and delivered none (nwa delivered 87 of 89). The hauler formed 25 to 45 tiles
  toward the uplink and, when every spot there was walled, took the last one anyway: inside a walled fab compound of a
  nine-block bastion (gates open for no unit). Its escorts, outside, never closed up; let go after a minute, the hauler
  "moved" alone and stayed; one a minute piled up. Now, as a siege's hauler: it forms past the settlement's own
  outermost wall on that line (the near half only: walked the whole way, the uplink's walls, the same force, set it down
  beside the uplink, delivered in 0 s), its escorts are teleported beside it, it is delivered at its dock or within 30
  tiles of the uplink (a young headquarters walls its dock in), and a hauler that has not moved for two minutes is
  called off with its cargo back in stock (`convoys_stuck`). Visit: 17 of 18 delivered in about 42 s, none stuck.
  Scenario `convoy LP_MIX=grown` (a bastion grown to full size before the uplink lands; in the full regression).
- The bursts in the raze curve are not a problem (the user): the 80 at deathworld's minute 170 were 52 belts, 12 poles,
  10 walls; a raid is an event. Count by cost, not entities, in later reports.
- **Railgunners stay off the player's buildings (2026-10-20).** The user, first deathworld look: railgunners "seem to
  far outrange the gun turrets (intended??)" and "turn black only when they fire". Range 30 against a gun turret's 18:
  they joined raids and assaults and shot from beyond reach (10 damage a shot to anything but biters, slow but free).
  Tried: open fire at 17, the slug's line still 30 (one rule for every unit: what shoots a turret stands in its
  reach). Against biters it lost: `rail` on 12345 every railgunner dead, 3 big biters killed (at 30 it passes); two
  seeds, five clearance scenarios, 4 failures at 17 against 2 at 30. Range 30 kept; railgunners no longer go on raids,
  assaults or a siege's guard (`ops.fights`), and count towards the floor kept home, not towards what a raid can send
  (`field`). `leader rails`: six railgunners at home, a raid of four, none of them railgunners; letting them go, one
  went. The black: their firing pose was the Line trooper's tinted a second time, and a second tint finds no mask left
  and darkens the whole body; it is their own pose now (the mech armour's under Space Age), tinted once.

### Next design topics (the user, 2026-10-15; status 2026-10-16)
- **Grubstake's flavour pass** (Fable: `docs/reviews/2026-10-15-grubstake-flavour-consult.md`): "felt before it is seen".
  Scrap cannon, "a sort of dirty flak" (the user): an airburst of many soft hits, Grubstake's signature against the
  railgun; pheromone flares (biters pulled onto a canister past turret reach, no pacifier no flares); claim jumpers (a rig
  digs in outside the wall, a mound inside, Shotgun hands emerge a minute later; replaces the sappers); grapple as
  looting's animation. Not: boobytrapped claims (the user), scrap to pick up (the user).
  Built 2026-10-16: the scrap cannon, the pheromone flare, the claim jumper, and the user's power tap (sections below).
  Left: grapple as looting's animation; dynamite in the jumper's squad and the sappers folded into it; the ladder's
  rung 2 and 3 combinations (two nests a flare; flare and rig together).
- **Loot instead of salvage; faction tech for the player** (the user: "regular Factorio loot ... faction-specific loot
  which could be used to research faction-specific tech"; Fable: `docs/reviews/2026-10-15-faction-loot-consult.md`):
  ordinary items on death by cost (nothing from walls and cheap pieces), rare components per corporation (Grubstake:
  pheromone gland, pacifier crystal, drill head; Serenity: rail coil, cluster fuze, orbital beacon), six player
  technologies (bait, pact breaker, claim marker; cluster shells, rail rifle, orbital strike). Command cores stay apart.
  Built 2026-10-16: ordinary loot (salvage gone), the six components and their drops, Cluster shells. Left: bait, pact
  breaker, claim marker, orbital strike (all built since).

- **Builders instead of the blue beam** (the user, 2026-10-16: "landers build things around them using a weird blue
  laser, which feels weirdly decorporealized ... have a builder unit leave the base with parts to build a set of
  buildings?"; Fable: `docs/reviews/2026-10-16-builders-consult.md`). A yard builds what it can reach (within 40 of the
  lander or a depot, as now: Serenity's beam short and from its nearest depot, Grubstake a crane's sparks and dust);
  crews build the rest: a unit leaves carrying a module's whole bill of parts, builds each entity at the site at the
  same 1.5 s, goes home. Serenity: a flying constructor drone; Grubstake: a builder truck with a crew. One codepath
  (`crew.lua`, the tap's runner lifted out), two bodies. A killed crew drops its remaining bill as items; the module is
  requeued; a crew whose site is occupied turns back. Pace held: `grow`'s counts within 15%. Real construction robots
  for Serenity kept as a later form (the planner's synchronous guarantees go through `place()`). Slice 1 built
  2026-10-16 (Grubstake's truck), below.

### Next design topic: Serenity's walled advance (the user, 2026-10-16; not built)
"Should serenity camps grow into ever larger fortified areas? feels like it would fit the theme of progressive
asphyxiation by a high tech opponent, although large walled areas also need to survive biters." Today the moving line is
a claim radius (30 tiles every 10 minutes toward the player, a named warning a step before it encloses a structure), not
a wall. First thoughts: a physical line in an arc facing the player (a full ring at 450 tiles is some 2,800 walls),
laser towers along it, gates where its roads cross, built and repaired by its drones; nests on the way cleared first
(clearances, the barrage), so it clears then walls; the player's counter a breach and the drones sent to mend it.
Fable (`docs/reviews/2026-10-16-walled-advance-consult.md`): physical, not a ring (a ring at 450 is some 2,800 walls and
470 lasers, 10,000 parts facing biters): a cordon of posts (a pad, a short wall, two lasers, a lamp, a pylon) every 60
tiles on an arc of ±60 degrees facing the player, a step of 30 tiles every 10 minutes built by drones; the claim may not
run ahead of the posts (80% standing); a long wall only at contact, two steps from a player structure; the leading arc and
one behind kept, older posts recovered (parts back). Ore the arc crosses unclaimed becomes a recovery site; a player
route it crosses gets a gate post. No post within 100 of a living spawner (a clearance first); a bearing that loses a
post to biters three times stops. Counters: breach, outflank (the bearing follows the nearest structure), starve (posts
cost parts), overextend. First slice: posts on the arc (`cordon`), then breach and mend, biters, contact wall and
recovery, routes and ore.

### Rivals, slice 1: Grubstake prospects (the user took the plan; Fable: `docs/reviews/2026-10-16-rivals-consult.md`; built 2026-10-16)
The frame (`docs/arc.md`): the corporations are rivals who become enemies; each takes one thing turrets do not stand on,
and its economy is one thing the player can reach. Grubstake takes what you are not using. `scripts/prospect.lua`: a
mature camp picks the nearest charted ore patch within 300 tiles (chunk by chunk, a capped count of 20 ore tiles) that no
player drill works within 40, no claim marker stakes, and no other corporation claims or holds; it tags it on the
player's map ("Mineral rights reassigned") with a notice; ten minutes later, unless the player has drilled or staked it,
its truck builds a claim there (a generator, a pylon, three drills with bins: a mining module of the camp, rebuilt and
capturable, its disc on the map). One patch at a time, nearest first, ten minutes between; a claim not built in ten
minutes is abandoned (its truck turned back each time). Headless runs chart nothing, so tests waive the charting
(`debug_tune prospect_uncharted`).
- Scenario `prospect` (three iron patches 150 to 250 out, the nearest with a player drill; windows of 2 minutes): the
  drilled patch left alone; the two others tagged and claimed, nearest first, each built by a truck (72 s); `stake` (a
  claim marker by the second): it is never tagged, the third is claimed.
- On deathworld10x it prospected nothing in 3 hours, and rightly: within 500 tiles of its camp lie 2,380 ore tiles, 9
  charted chunks with ore, all its own patch (its first exclusion, "beyond its own claim", hid even those: a sprawl's
  claim covered 123 of 278 chunks; now only ground within 40 of one of its modules is its own). The map is ore-poor
  where it landed. Open (to the user): prospect the unworked patches nearest the player's base, within a long reach of
  the camp, the player's expansion frontier, rather than those nearest the camp.
- Not yet: answering inside the window tested (a drill placed after the tag), the claim lapsing when its road is cut,
  strip drills draining faster, the "expansion delayed" notice.

### Rivals, slices 5 and 6, and the corporate map (built 2026-10-16, overnight)
**The trade post** (`scripts/trade.lua`; pay the thief). A steel chest in Grubstake's colour, from the start. Filled
(worth 50 or more, valued as loot is: `ops.LOOT_VALUE`), the nearest Grubstake camp sends a truck to empty it; the
goods buy a truce, a minute for each 10 of value (5 to 120 minutes): no raid (`temper_allows`), flare or heist on that
player while it lasts; prospecting and the tap go on (it still takes what you are not using). Standing reads "truce".
The truck can be ambushed (by Serenity too, crossing its ground): no truce, the goods spilled. Scenario `tribute` (an
enemy camp, three undefended assemblers 100 out, 500 iron in a post at 4 minutes): emptied, a 5-minute truce; raids on
the player at 9,000 and 34,200 ticks, none within the truce (15,600 to 33,300); an enemy again after.

**Bending the line** (slice 6): the cordon already bears on the player's nearest building, so a decoy relay swings it.
Scenario `bend` (a relay 300 out, at 6 minutes a second 90 degrees off at 200): bearings 0, 0, 0, then 90 and 90.

**The corporate map** (`scripts/map.lua`; Fable: without it none of the rest reads). In map view each camp carries its
corporation and its standing toward the player ("Grubstake Mineral Recovery: rival"), kept current; Serenity's next arc
(the posts being built) is marked, with an arrow on its bearing. Claims, prospects, borders draw their own marks.
`standing` checks the label follows (rival, then enemy).

**A call against the consult's pruning:** the claim jumper and the tap stay separate. Standing gives them distinct
places: the tap takes idle power (a rival's theft), the rig breaks into chests (an enemy's heist, from the ladder's
second rung). Both rarely fired on deathworld because that base offered no target, not because they overlap.

### Rivals, slices 3 and 4: the border stake and the road (built 2026-10-16, overnight)
**The border stake** (`scripts/border.lua`; Serenity takes a direction, the player may concede it). A separate item from
the claim marker (the call: two names read better than one entity with two meanings, and conceding must be possible
early: 10 stone bricks and 5 iron, from the start). Set toward a Serenity camp that holds the player a rival, outside its
claim: the camp acknowledges a border at the stake's distance, drawn on the map, and its line (`ops.perimeter`, the
cordon) holds short of it. Anything of the player's built on Serenity's side breaks the treaty: provoked, an enemy, the
border void. An enemy does not treat; a stake inside the claim is encroachment, not a border. Scenario `border`
(the line a step a minute, a relay 300 out, the stake at 200): the line held at 180, still a rival; `breach` (an
assembler at 160 at minute 10): an enemy, the treaty void (the line itself goes no further: it stops 40 past the
player's nearest building, the intruder already inside; the enemy raids instead).

**The road** (`scripts/road.lua`; Grubstake's economy is the road). A Grubstake claim has no line home: every 5 minutes
its camp sends a truck to empty the claim's bins and bring the ore home as feedstock (the economy step no longer counts
a claim's bins at once where the corporation has a road). A truck killed on its way back spills its ore and the player
is told "expansion delayed N minutes" (the cargo against the camp's intake a minute); a claim with no ore home for 20
minutes lapses (its mark gone, no rebuilds: its drills there to take). Scenario `road` (hauls every 2 minutes, lapse
after 6): 933 ore home from the claims in 25 minutes; `cut` (trucks killed leaving the claims loaded): four lost with
106 to 346 ore, each told, two claims lapsed.
- Found on the way: the claim's drills stood 14 tiles out, beyond its pylon's supply (unpowered); now within 8, the
  pylon at the centre. The bins were emptied at once by the economy step (an abstract haul), so the trucks carried 2 ore.
- Prospecting now goes for the player's frontier (the call, the user leaving the calls to me): within 700 of the camp,
  the unworked patch nearest the player's spawn first. On deathworld10x (3 hours, unprovoked): three claims, one standing
  (an iron patch), the other two the same coal patch by the player's base, abandoned by one camp and retried by
  another (abandoned patches are now remembered by every camp). Its value razed there fell from 1,043 to 342: a rival
  Grubstake (standing) steals and does not escalate. A large drop in pressure on a player who never provokes it: to judge.

### Rivals, slice 2: standing and incidents (built 2026-10-16)
`scripts/standing.lua`. Toward each player force a corporation is a rival or an enemy (a truce comes with the trade
post): an enemy once provoked (`ops.provoke`, as Serenity always was: its buildings or units hurt, its claim encroached)
and, the user: "even a tolerant rival should not accept turrets in firing range. That's an aggression": a player turret
within 26 tiles of a camp's lander or one of its modules provokes it (checked once a minute). A rival Grubstake steals
(soft raids, prospects, taps) but its ladder stays at the foot (`ops.ladder` via `ops.rival_holds`): no flares, rigs,
reliefs or larger army until provoked; standing down after a quiet hour makes it a rival again (Serenity never forgets).
A change of standing is a notice (`lp.standing-enemy`, `lp.standing-rival`). Incidents: the last 20 things the
corporations did to the player (razes, merged per raid; turrets on their ground; prospects and claims; standing
changes), `/lp incidents`. The sim provokes every corporation at start except in the temper scenarios and visits, so
visits now meet Grubstake as a rival, as a real game does.
- Scenario `standing`: a rival with its ladder at 0 although ten times fast; a turret by its lander: an enemy within
  the minute, a turret incident and a standing change listed; it stands down (4 minutes quiet, nothing razed): a rival.

### The cordon, slice 1: posts on the arc (the user; Fable: `docs/reviews/2026-10-16-walled-advance-consult.md`; built 2026-10-16)
`scripts/cordon.lua`. Serenity's moving line made physical. Each step of its perimeter (`ops.perimeter`, unchanged in
its timing and caps) is an arc of posts at the new radius, within 60 degrees either side of the bearing to the player's
nearest structure, one every 60 tiles: a 5 x 5 concrete pad, a wall of eight facing the player, two gun turrets (fed by
the camp; lasers 60 tiles apart would want power lines). They go first in the build queue and stand beyond every yard,
so its drones build them. The claim steps out to the arc (`ops.perimeter_advance`: the map, the notices, the named
warning) only once 80% of its posts stand; until then the line waits. With no player structure in reach the line holds
(stepping out on its own, the claim ran to 450 once the relay it faced was razed).
- Scenario `cordon` (the line a step a minute, an indestructible player relay 300 out; 20 minutes): six arcs, 90 to 275
  tiles, 38 posts and 80 gun turrets, none off the arc facing the relay, all built by drones (64 runs, none stuck); the
  claim never beyond its last standing arc.
- Recovery (built overnight): when an arc stands, the arc two behind comes down, half its parts back (Fable: keep the
  leading arc and one behind). `cordon`: 210 pieces recovered in 20 minutes; 38 post turrets standing at the end
  where 80 stood before.
- Breach and mend (tested overnight): posts are buildings like any other; a lost one is rebuilt by a drone (crew.lua).
  `cordon breach`: three turrets of the leading arc killed by the player, mended within 3 minutes, Serenity an enemy.
  (The first try broke posts of the oldest arc, which its recovery then took down as designed.)
- The contact wall (built overnight; Fable: "the asphyxiation moment"): an arc queued within 60 tiles of the player's
  nearest building closes its middle, the posts within 25 degrees of the bearing joined by wall, side-joined tiles only
  (a diagonal leaves corner gaps), an opening of 3 left mid-span for its own ground units; recovered with the arc.
  `cordon contact` (the relay 200 out): contact on four arcs, 233 walls standing on the line near the bearing. The line
  stops 40 past the player's nearest building, so it encloses the relay and is provoked by it (encroachment).
- Gate posts (built overnight): where an arc crosses a player's straight rail (east-west or north-south; a diagonal
  takes no gate), two of its gates across the track and two gun turrets beside, up to three a step. A gate of another
  force stops the player's trains (Engine notes). `cordon rail` (a player rail along the bearing 100 to 260 out, a train
  driven toward the camp at 14 minutes): gates on the rail at two arcs, the train stopped at the line (here at a post's
  wall across the track, 7 tiles before the gate). Its line severs the player's rail; the player breaches or goes round.
- Ore the arc crosses (built overnight; Fable: the line pays for the line): at most one patch a step, an ore patch
  within 10 of the arc (sampled every 5 degrees: beside the posts only, it missed a patch between posts 60 apart) that
  no player drill works becomes a claim of the camp (prospecting's builder: a generator, a pylon, three drills), built
  by its drones; Serenity has no road, so its claims count their ore at once. `cordon ore` (a patch 150 out, 20 degrees
  off the bearing): claimed with three drills (the arc at 120 had first crossed and claimed the map's own coal).
- Not yet (the consult's next slices): nests (no post within 100 of a living spawner; a bearing that keeps losing posts to biters
  stops), the wall at contact, gate posts on the player's routes, ore the arc crosses.

### Builders, slice 1: Grubstake's truck (the user; Fable: `docs/reviews/2026-10-16-builders-consult.md`; built 2026-10-16)
`scripts/crew.lua`. A yard builds what it can reach; crews build the rest. `base.build` offers each next job to
`crew.take`: a module whose centre is beyond 40 tiles of the lander and of every depot goes to a crew. The crew takes all
the module's jobs off the queue and pays its whole bill at once (or waits for the parts, holding the queue as the yard
does). A truck (the hauler's hull for now) forms past the camp's outermost wall on its line, drives to the site, builds
one job each 90 ticks (the camp's own pace; `place` told the parts are paid, an orange spark from the truck), marks the
module built and goes home, where it is parked (taken off the map). At most two crews out. Killed, it spills the parts
it still carried as plates and circuits (iron half, copper a quarter, circuits a tenth) and its jobs wait 60 s before
another crew; not nearer its site for a minute, or its site occupied, it turns home with its parts. Grubstake's yard
builds with sparks, no beam; Serenity keeps its beam until the drone.
- Serenity's constructor drone (slice 4): the same codepath with a flying body (`shared.CORPS.serenity.crews = "drone"`,
  the harrier's airframe for now): it lifts off from home, flies straight over its walls, builds with Serenity's beam
  drawn from itself. Serenity's yard keeps the beam, now from its nearest depot or the lander. Scenario `crew drone`: the
  outpost 90 out built 15 s after queuing (the truck: 34 s); the camp sent drones to two pickets on its own.
- A builder grown in a walled camp (slice 3, `crew grown`): Grubstake landed as a bastion, 196 walls after 20 minutes;
  the truck formed past them and built an outpost 150 tiles out in 53 s; none stuck.
- Rebuilds by crew: a due rebuild beyond the yards goes out with every other due rebuild within 30 tiles of it on one
  crew, paid at once; the invisible constructor's second a tile is dropped there (the crew travels instead). Lost, its
  jobs go back on the rebuild list, due a minute later. Scenario `crew rebuild`: two of the outpost's five destroyed, a
  truck took both when due and the outpost stood whole 82 s after the damage.
- Giving up (2026-10-17, the deathworld10x visit): three crews lost on one module (or one rebuild) and the camp gives it
  up. Serenity's cordon had reached the player's factory: 168 drones flew to two posts under its turrets in two hours,
  one a minute, and Grubstake sent 42 trucks to a claim inside it. Posts and modules go to the front of the queue, so a
  doomed one also held up everything behind it (`crew doomed` with no limit: the camp's own crews finished nothing in 10
  minutes). An abandoned post never stands, so its arc never reaches HOLD: the player's guns hold the line there. Visit:
  crews lost 181 -> 41, four modules given up, three crews each; the value razed rose 568 -> 738 (parts no longer burnt
  on doomed sites). Scenario `crew doomed`: every truck killed on the road; three lost, the outpost given up, the camp's
  other crews came home. The player is told (`lp.line-held` for a post: "Serenity's line is held at ..."; `lp.crew-gave-up`
  otherwise) and it is an incident (`/lp incidents`). `cordon held`: from 6 minutes every drone beyond the claim shot
  down; 25 lost, 7 posts and rebuilds given up, the claim held at 120 (it steps a minute otherwise).
  A crew stuck on its way (no nearer its site for a minute) counts the same: a camp sent 24 trucks to two sites it could
  not reach (visit deathworld10x). No notice for that one: the player did nothing. `crew island` (the site ringed by
  deep water): three stuck, the outpost given up, the camp's other crews came home.
- What the builders broke, found by the regression (Serenity's camps now send drones, so most scenarios changed):
  - The planner budgets power by the jobs still queued; a crew takes its module's off the queue, and they were planned
    again (demand 2.9 MW on 2.0, `loot`). A crew's unbuilt jobs now count as owed.
  - Rebuilds go in list order, a piece every 90 ticks: behind 20 walls, a camp's two generators were still waiting at
    the end, its hull down (`loot`; the old timing hid it). What makes parts and power now goes to the front.
  - Rebuild crews were held behind building crews (two at most for both): an outpost's turrets came 50 s late. Each has
    its own two now.
  - `defend` met capture: the player's creeping turrets killed the outpost's turrets and held it a minute before its
    rebuild came (war footing holds the rebuild while the camp is short of units, as before), and four pieces were
    captured, then razed by the camp's own raid. Capture is the player's win, tested in `fall`; `defend` tests the
    response and turns capture off (`debug_tune capture_off`).
  - `reinforce` read the war chest's closing balance (under 3,000 after paying): a camp growing faster refills it from
    its exports (363 paid, 3,037 left). It reads what was spent now (`war.summary` spent).
- Not yet: the truck's own body with its crew, the drone's own body.
- Scenario `crew`: an outpost of five 90 tiles out queued first: the truck builds all five there 34 s after queuing and
  comes home; the camp sent two more on its own (its launch pad and a depot beyond 40: built in 10 and 15 s); none stuck.
  `killed` (the truck killed at mid-road): 17 iron spilled where it died (its 34 parts' half), the outpost waited a minute,
  a second truck built it 94 s after the loss. Four gun turrets beside the road did not stop the truck: the hauler's hull
  (1,500 health, armour 4 and 30%) took about 2.8 a piercing round and crossed their reach in about 9 s. Too tough for a
  builder; to be settled with its own body.
- Pace (scenario `pace`, a Grubstake camp 30 minutes on its own, before and after, four seeds): parts made 9,109 ->
  8,757 (-4%), drills 68 -> 64 (-6%); seed 1 alone drills 22 -> 18 (-18%: its outposts lie far, and wait for a truck);
  seeds 777 and 12345 as before or better.
- A camp that never made a part (Grubstake, seed 4242, in every version before): its own drop generators, pacifier,
  first outpost and cliffs took the four cells its street hub allows, so its first fabricator block went to a new hub at
  the doctrine's reach (120 tiles), as a walled compound first; the walls spent its 90 parts and the fabricator (25)
  never came, and nothing makes parts without one. Now, with no fabricator yet: the hub's cap does not hold it, a new
  hub goes near (two cells) and opens as the block asked for, and the first fabricator goes first in the queue. Seed
  4242: mature at 30 minutes, 3 fabricators, 1,708 parts made (none before); seed 1 unchanged. Serenity had it too:
  its camps 30 minutes on their own (`pace serenity`, with its drones), parts made 3,761 -> 6,717 over four seeds (777:
  652 -> 2,033; 4242: 0 -> 1,577; 1 and 12345 unchanged).
- Routed round the player's guns (the user, deathworld10x, 2026-10-17: "the hauler gets stuck on the wall and the turrets
  shred it", and "it gets multiple haulers destroyed and doesn't turn hostile"). A truck drives `ops.route` (turrets and
  nests avoided) as go_to waypoints, planned once a module (`m.crew_route`); a drone flies straight. With no route (the
  site in a pocket the player's guns close: the router's pocket probe), the module is given up before a truck is sent
  ("crew: no way to the ... out of the player's guns: given up", `crews_unrouted`), and so are rebuilds there. Stuck means
  standing still on a routed drive (4 tiles of movement resets it). A crew truck killed by a player provokes Grubstake
  (`storage.crew_owner`, `ops.provoke`): it turns enemy. Scenarios `crew walled` (a ring of 30 turrets round the site:
  given up, none lost) and `crew around` (3 armed turrets mid-road: built, none lost, routed round them)); `crew island` (the site ringed by water) is now given up before a truck leaves, where three trucks were stuck first.
- Pylon spots remember their module (`layout.connect`; `site.nearest_pylon` skips one given up or failed). Before, a
  copper mine chained to the planned pylon of coal mines given up by the player's wall: its line ran toward them and
  ended in nothing, its drills unpowered (the user's screenshot). `base.heal_lines` (on a version change) drops old
  untagged spots with no pylon or pylon job at them and wires each mining module stranded off the lander's network to
  its nearest pylon on it; on a copy of the user's save the copper mine was on the camp's network 157 s later (88 drills
  on it, from 72).

### Staggered arrival: Grubstake early, Serenity late (the user; built 2026-10-15)
The user: "Grubstake coming earlier with its sneaky raids, and Serenity coming in later with much more firepower";
Serenity has become the high-tech faction (railgunners, cluster shells, the orbital barrage), Grubstake the cheap swarm.
- Grubstake is always the first corporation (`phases.EARLY_CORP`): its survey party at oil processing, its arrival at the
  first chemical science pack, Space Age or not (the gun-turret era: soft outposts, rails and poles, young biters).
- Serenity (`phases.LATE_CORP`) lands only once its gate opens (`phases.gate_open`, asked by `next_corp`): the first
  rocket launch (Space Age) or the first utility science pack (base game, where a launch ends the game). Its first
  landing is then due within 5 minutes (notice `lp.late-gate`), whatever the landing count (the second-corporation rule
  sent the second landing to Grubstake again). `debug_tune{gates_off}` for scenarios not about the opening.
- Scenario `phases` (44 minutes): Grubstake came first; no Serenity before the gate; a utility science pack, and
  Serenity's first settlement about 5 minutes later.

### Grubstake's scrap cannon: dirty flak (the user; Fable: `docs/reviews/2026-10-15-grubstake-flavour-consult.md`; built 2026-10-16)
The first piece of Grubstake's flavour pass. A gun turret's body a size up (`lp-scrap-cannon`, 500 health, cost 15),
lobbing a shell that bursts over its target: 12 physical over 2.5 tiles and six fragments of 6 over 1.2, its enemies
only, every 40 ticks, range 16. Many soft hits over an area, against Serenity's railgun (one hard hit along a line):
deadly to a blob, next to nothing against walls. Grubstake builds every second turret it places as one
(`shared.CORPS.grubstake.flak`); a lost one is rebuilt as one; fed with `lp-scrap-shell` by the loop that feeds its gun
turrets.
- Departures from the consult: range 16, not 14 (Serenity's Line trooper reaches 15 and shot a cannon of 14 unanswered;
  still inside a gun turret's 18, so the player outranges it). No scrap on the ground for haulers to bring home (the user
  rejected scrap to gather). Placed in the camp's hard points, not at strip camps and claim rigs (neither builds turrets
  yet).
- Scenario `flak` (LP_MIX=gun: Grubstake's gun turret instead, for comparison): a cannon against 20 small biters, and
  apart a second, made to last, against 10 Line troopers held in a blob before a player wall. Cannon: 20 biters dead in
  20 s, standing at 374 of 500 (the gun turret: 20, at 8 of 500, or 11 before it fell); the troopers lost 1,125 of 1,200
  in 20 s (gun turret 998; at 8 a burst and 50 ticks the cannon dealt 760 and was raised); the wall lost 1.9% to it.
- Measuring it: a lone turret before ten troopers dies in 3 s (about 170 a second) whatever it is, and troopers with
  nothing they can hurt walk off; the trial holds them and makes the turret last, to measure what it deals.

### Grubstake's pheromone flare (the user; Fable: `docs/reviews/2026-10-15-grubstake-flavour-consult.md`; built 2026-10-16)
**Retired 2026-10-22 (0.1.55)** with Synthexis's arrival (the user: biter waves become the biotech's alone).
`scripts/flare.lua` and the canister are gone; the biters' call lives on in the player's bait (`bait.lua`); the gland
drops from Synthexis incubators; Grubstake answers a loss with a snatch raid only where no turret covers it. Kept below
as history.

Grubstake is felt before it is seen (the consult's frame): things go wrong near the player's stuff and the cause is found
a minute later, outside the wall. `scripts/flare.lua`. A settlement whose pact holds and whose ladder against the player
is on rung 1 or more, mature, not standing down, picks the guarded player target it knows nearest home (turrets reach
it: exposure or defence above 0), and sends a buggy from its garrison to drop a canister (`lp-flare`, 200 health, a
military target) on the line from the target home, 20 to 40 tiles out, at the first spot no player turret reaches within
19 (a gun turret's 18). The buggy leaves without stopping to fight (free to engage on its way home, it drove at the
outpost's turrets and died). The canister calls a wave of 20 + 40 x evolution: the idle biters within 400 tiles that are
in no group first, nearest first, then the three nearest nests within 600 spawn the rest in equal shares (what each
would spawn at that evolution, `result_units`), each share its own group; every group is told to attack whatever it
meets within 30 tiles of the canister. It is fired only where something would answer (of the five nearest guarded
targets, the first whose drop has a nest or an idle biter in reach; else "nothing would answer ... not sent" and a
minute's wait). Each group gathers at the canister, then attacks the target it was dropped for (told only to attack within 30 of the canister, a wave waited outside the wall). Tell, in the world only: an orange smoke puffed while it burns, then the wave (no alert, map tag or
notice: the user, 2026-10-17, "nothing is communicated through notices in factorio"). It burns 3 minutes; shot, it
ends, and every group is told to wander (idle); burned out, the wave goes on (stood down then, a wave from nests 250 to
400 tiles off arrived after the burn and wandered by the user's wall: their autosave, four groups of 39 wandering). One a settlement per 10 minutes; a buggy that does not arrive in 2
minutes turns back.
- Played (deathworld10x, 2026-10-17): "Flares don't seem to do anything? Watching one dropped in front of my walls, no
  biter ever comes." Every flare had lit with 0 biters called: the player had cleared 150 tiles round the base (the
  nearest nests 250 to 400 out). Then: "Calling idle biters has as much chance of generating a big attack as a trickle
  ... Perhaps the flare should generate a combined attack from multiple nests, with cheaty biter spawning to make sure
  the resulting wave is significant." Hence the wave. The player's bait (`flare.call`) still calls idle biters only.
- The choice is "guarded", not "what its raids would not take" (`ops.temper_allows`): at its top rung Grubstake raids
  anything, and the consult's ladder fires the flare first there; the first version found no target at rung 3.
- Not yet: rung 2's two nests a flare, rung 3's flare with a claim rig. Razing by the called biters does not count as
  Grubstake's (it is the biters' kill: the ladder's clock and the tally miss it). The smoke is a cloud, not a column.
- Scenario `flare`: a player outpost with two gun turrets 150 tiles from a Grubstake camp, 40 idle biters 60 tiles to
  its side; `debug_flare` (the drop point and launch the camp's own choice uses). The canister lands 27 tiles from the
  outpost, out of the turrets' reach; 12 biters called (7 of them dead to the turrets within 30 s: count every biter ever
  called); the turrets emptied their 400 rounds; shot at 60 s, the group wanders; no Grubstake unit killed by biters.
  `nopact`: no flare. `natural` (no debug_flare, the ladder ten times fast, 25 minutes): the camp flares the outpost
  itself at 5.7 minutes, the same results, and the biters raze it. With the wave (2026-10-17): 20 called of the 40.
  `nests` (no idle biters placed; three nests about 270 tiles from the canister): 21 called (9 idle the nests had
  spawned, 4 from each nest), 17 reached the canister before it was shot at 60 s.
  `walled` (a wall ring at 10 round the outpost, its two turrets behind it, the canister 26 out): the wave went on into
  the wall (20 pieces hit); the old order (attack within 30 of the canister) hit it as well (18), so walls in reach were
  not the user's case. `burnout` (walled, a 1-second burn, never shot): 24 wall pieces hit; with the stand-down at the
  burn, 0 (the check seen failing).

### Grubstake's claim jumper (the user; Fable: `docs/reviews/2026-10-15-grubstake-flavour-consult.md`; built 2026-10-16)
A heist, never an assault. `scripts/jumper.lua`. A settlement on its ladder's second rung against the player, mature and
not standing down, picks the guarded player target nearest home that has chests within 16 tiles. A drill rig
(`lp-claim-rig`: an electric drill's body 1.3 times, Grubstake's colour, 1,200 health, a military target) digs in on the
line from the target home, 40 to 60 tiles out, past every turret's reach (19); a mound grows by the chests for a minute
(sand rocks, then a dune, dust; a tell, not a target); the alert and notice (`lp.rig`) name the rig. Rig alive at the
minute: four to six Shotgun hands come up at the mound, loot the chests within 16 as a raid does (`ops.loot`, the same
values and cap), break what is near for 30 s, and go back down; what the ones who reach the mound carry becomes parts.
Rig killed before: nothing comes up (`lp.rig-down`). Killed after: the tunnel caves in and the hands stay to fight. One
rig a settlement at a time, 15 minutes between.
- Not yet: the rig is set down where it digs (no hauler brings it); the consult's dynamite in the squad and the sappers
  folding into it; rung 3's flare and rig together.
- The target it suits is a big walled base whose turrets stand on the perimeter: hands coming up among turrets that
  cover the chests die in seconds (four gun turrets: about a hand a second), which is the player's answer.
- Scenario `jumper`: a walled square 60 tiles across, 150 from a Grubstake camp, a gun turret at each wall's middle (27
  from the centre), a chest of 200 plates and 50 circuits in the middle; `debug_jumper`. The rig at 42 out of reach; 6
  hands up at 60 s; the chest emptied (then razed); 250 items home with 1 hand of 6. `rigkill` (the rig killed at 30 s):
  nothing comes up, the chest untouched.

### Loot: Factorio's own items, salvage gone (the user; Fable: `docs/reviews/2026-10-15-faction-loot-consult.md`; built 2026-10-16)
The user dropped the salvage currency: the corporations' buildings and units drop ordinary items, and (later) rare
faction components the player researches faction technology with. This is the consult's first slice, ordinary loot.
- A faction building is made of what its cost says (`data.lua` `made_of`): iron cost/2, copper cost/4, circuits cost/10,
  and its kind's own (turrets 2 to 5 magazines, a generator an engine, a drill 2 gears, a depot 10 steel, a lander 20,
  an uplink 40). Under 8 parts (walls, gates, pylons, bins, lamps, mines, flamers) nothing, or every wall is a mine.
  Killed, it drops each at 80%, half to all (the engine's `loot`); its ruins and what the player captures mine to all of
  it (`minable.results`).
- Units drop a little of their own kit half the time (`units.lua` `UNIT_LOOT`): a Line trooper a circuit, a Shotgun hand
  1 to 3 shells, a buggy an engine, a tank 4 steel and an engine, a hauler 8 steel, a railgunner 2 steel and an advanced
  circuit, and so on. The player's own units drop nothing.
- `lp-salvage` is gone (a migration turns any left in a save into gears): the crash-site wreck of the signs holds 20 circuits
  and 20 gears (it has two slots); a mortar's wreck drops its loot; the prizes cost ordinary items until components
  exist (the mortar 20 steel, 10 explosives, 10 circuits; its shell 1 steel and 2 explosives; the strip drill an electric
  drill, 10 steel, 5 circuits).
- Scenario `loot`: twenty buildings, twenty walls and ten units of a settlement killed by the player leave 79 iron, 23
  copper, 17 circuits, 26 magazines, 10 gears, 3 engines, 8 steel and an advanced circuit on the ground; no salvage item
  exists. `fall`: a ruined fabricator mines to 12 iron and 2 circuits.
- Wrecks' loot lies where they stood and blocked their rebuild (occupy, defend: nothing rebuilt): a rebuild now clears
  items on the ground from its footprint (the corporation reclaims what the player left).
- The loot rolls move the game's random numbers, and `clear` (30 minutes) went from 5 of 5 seeds razing the target to
  4 of 6 (12345 and 777 short); given 40 minutes seed 12345 razes it after 5 clearances. Its window was a knife edge: the
  regression runs it 40 minutes.
- The survey party's drills stand on the ore its site was chosen for (the user, in game: at fixed offsets they stood on
  grass beside the coal): the two nearest ore tiles within 20, at least 5 apart. `phases` checks it (1 of 2 on ore before).
- `fall`'s "an outpost is taken by holding it" failed back to 5281d15 at least: the fall is the player's kill, so the
  grudge and the evacuation march past the player's holding turret, and Serenity's infantry destroyed it before the hold
  completed. Capture itself works: the holder made to last, three outpost modules are captured.
- Components and the first technology: built (below).

### Faction components and Cluster shells (Fable: the faction loot consult, parts B and C; built 2026-10-16)
Six components, items of stack 10 with no recipe, taken only from the corporations' wrecks (`components.lua`, loaded
after `corps.lua` so each corporation's own prototypes carry its own): Grubstake's pheromone gland (a pacifier 3 to 5, a
flare canister 1), pacifier crystal (scripted in `pact.lua`: the landing's own pacifier always, a rebuilt one a quarter
of the time, so rebuilds are no farm), drill head (a claim rig 2); Serenity's rail coil (a railgunner, 20%), cluster
fuze (a mortar 1, a howitzer 6), orbital beacon (a lander 1, an uplink 2). What the player keeps is paid once: a
technology takes components only through a teardown ("Cluster fuze, disassembled", a recipe from the start whose
product is what the technology's research trigger asks for, craft-item); consumables take one each.
- **Cluster shells** (Serenity, three fuzes; after Artillery): the artillery shell plus a fuze makes a cluster artillery
  shell, bursting into ten bomblets of its own round the impact (25 explosion over 2 tiles each, the firing force's
  enemies only). Serenity's own bomblets (12 over 1.5, six) killed none of a ring of small biters 7 tiles out (15
  health); these kill 8 of 12. An ordinary shell (its blast 4 tiles) kills none.
- Scenario `fuze`: a Serenity mortar destroyed drops a fuze; three in an assembler research Cluster shells and unlock the
  shell; one fired at a point ringed by 12 small biters 7 tiles out leaves 4 (`plain`: an ordinary shell leaves 12).
  Fired by an artillery turret at a spawner ringed by worms the comparison said nothing: the turret aims at the worms
  themselves, one a shell either way.
- **Pheromone bait** (Grubstake, three glands; after Military): a canister the player places (one gland and 5 iron a
  bait), calling the idle biters round it as Grubstake's flare does (`flare.call`, shared; `scripts/bait.lua`): it burns
  3 minutes, then they wander. The pact keeps the biters off Grubstake: it is how the player sets them on Serenity, or on
  Grubstake once its antennas are down. Not a military target (the corporations' turrets do not shoot it on sight).
  Scenario `bait`: the teardown researches it; placed 25 tiles out from a Serenity camp, 30 idle small biters 70 out: 12
  called, 2 of Serenity's buildings lost to them. A research trigger counts only once its prerequisites are researched.
- **Rail rifle** (Serenity, two coils; after Military 3): the railgunner's weapon for the engineer, a slug piercing a
  30-tile line for 150 physical every 90 ticks, its enemies only (a `line` action aimed by direction, as Space Age's
  railgun). Paid once in coils; the rifle (10 steel, 5 advanced circuits, 20 cable) and its slugs (a steel plate and 3
  cable) are ordinary crafts: a coil a slug would starve it, coils come from 1 railgunner in 5. Scenario `rifle`: a
  character with no player, set shooting along six held medium biters 8 to 23 tiles out: 3 slugs, none left standing.
- **Orbital strike** (Serenity, one beacon; after the rocket silo): a strike beacon the player places on power (an
  orbital beacon, 10 processing units, 20 steel each), charging 50 MJ at up to 5 MW; charged, it queues Serenity's own
  orbital shells (`storage.orbitals`, war.lua's barrage; as many a target as its health takes) on every nest, worm and
  corporation building within 60, walls, gates and pylons spared, and burns out (`scripts/strike.lua`; notice
  `lp.strike`). Striking a corporation provokes it. Scenario `strike`: 45 tiles out from a Serenity camp, 12 targets,
  43 of its buildings lost (the bomblets' splash counts). Its entity count within 60 rose meanwhile (it builds): its
  own count of losses is the measure.
- **Pact breaker** (Grubstake, one crystal; after Pheromone bait) and **Claim marker** (two crystals), both from one
  teardown, "Pacifier crystal, disassembled" (`scripts/marker.lua`). The breaker, set inside a Grubstake camp's claim,
  jams the pact for 3 minutes (`storage.pact_suspended_till`, read by `pact.apply`), then burns out; outside every
  claim it waits and says so. The marker: Grubstake reads the player's buildings within 40 of it as its own claim and
  leaves them alone (`ops.marked`: raids through `temper_allows`, strips, flares, rigs, taps). A real player pacifier
  is not possible (the cease-fire is per force: it would end the biters map-wide). Scenario `crystal`: both researched;
  the cease-fire true, false with the breaker, true when it burns out. `marker`: a soft outpost 120 tiles from the camp,
  marked, known and held and standing; unmarked, Grubstake razed it.
- All six faction technologies of the consult are built.

### Chat notices off by default (the user, 2026-10-17; Fable: `docs/reviews/2026-10-17-notices-consult.md`)
The user: "Your reliance on notices in general is something I feel is not 'Factorio'. I'm OK with notices for
debugging, or as an ultimate resort (like pointing the first landing of a faction), but in general nothing is
communicated through notices in factorio." Every chat notice goes through `shared.notice`, told only when the map
setting "Chat notices" (`lp-chat-notices`, runtime, off) is on; the mod's custom alerts (raid, siege, strip, loot, rig)
too (the engine's own alerts fire when they hit). Always told: a corporation's first landing (later landings as any
notice), a lost settlement, and until the world shows them the three warnings that are the only fair notice before an
unseen loss (the prospect's ten minutes, the perimeter's ten, the claim rig's one). Replies to the player's own act (a
border stake, the pact breaker, the strike beacon, a tribute collected) are floating text at the spot
(`shared.reply`), as Factorio says "cannot build here". Guards: `scripts/lint_notices.sh` (in `check.sh` and
`regress.sh`) fails on a print or custom alert outside the gate, the dev commands and lines marked `notice-ok` (seen
failing on a planted print); `prospect` checks the gate itself (a headless run has no players, so the corporations'
notices never reach it: `debug_notice`): held by default, a fall told, all told when on (seen failing with the gate
forced open).
- Next, from the consult: a stake entity (Grubstake's claim stake on a prospected patch, its lamp red in the last
  minutes; Serenity's survey stakes on the next arc), a lamp on the trade post while a truce holds, the rig's dig
  lengthened to 2 to 3 minutes with a dust line toward the chests. The consult's fairness point on the perimeter:
  enclosing a structure that stood before the arc should not provoke Serenity (the line moving onto the player is the
  corporation's act), or the warning stays a notice; a design call for the user.

### World tells for the last warnings (Fable: `docs/reviews/2026-10-17-notices-consult.md`; 2026-10-17)
With chat notices off, three warnings stayed always on as the only fair notice before an unseen loss. Each now has a
tell in the world, and none stays on but a lost settlement's:
- **The claim rig:** its dig is 2.5 minutes, not one (the rig is charted in Grubstake's colour), and dust puffs creep
  from the rig toward the mound at the dig's pace. Its hands now get an order the moment they come up (idle, they
  charged the wall's turrets), and break what is near the mound answering only what hits them (told to engage
  anything, all six fell to turrets out of reach). Scenario `jumper`: none up at 62 s, up at 152 s, the loot home.
  The five of six that fell: each 10 tiles from the turret that killed it, 15 to 21 from the mound. Told to attack the
  area round the mound, they took targets beyond it. Now each hand is set on a building within 10 of the mound that no
  turret reaches, the nearest, told again when it falls: 4 of 6 home (a check, "most hands back"). The end's log said "every hand fell" with hands home: fixed.
  The last two (2026-10-18): not shot, not distracted by damage. A hand whose order was done (its target fell) stood
  idle until the next step a second later, and idle, a unit attacks whatever it sees: it went for a turret 27 tiles
  off, unhurt, and died to it. The leave order, a walk to the mound they already stood on, was done at once, and all
  six went. Now every order is a compound that ends with standing still (`order`), and the leave phase takes home at
  once those already at the mound. Seeds 12345, 777, 4242: no hand falls, 4 to 6 home (a check, "no hand fell to a
  turret").
- **The trade post's lamp:** an amber pip on the post (seen by day) and a glow (by night) while a truce it bought holds;
  dark after. `tribute`: lit in 60 of 60 samples during the truce, none after.
- **Grubstake's claim stake** (`lp-claim-stake`): planted with a puff in the middle of a prospected patch, a lamp
  amber, then red and blinking in the window's last two minutes; pulled down, the claim is off (an incident); it gives
  way to the claim's works. Its description says what it means. `prospect`: a stake on every tagged patch, red near
  the end; `prospect pulled`: the first stake pulled, that patch left alone, the camp on to the next. The stake truck (2026-10-18): a buggy from
  the camp drives the stake to the patch (18 to 32 s in `prospect`) and comes home; the window runs from the
  planting. Destroyed on its way, the claim is off and the camp moves on (`prospect truck`; the loss is Grubstake's to
  answer). With no buggy at home it is planted at once, as before.

### The map redrawn, and camp names (the user, 2026-10-17)
The user: "I'm not a huge fan of how we represent territory on the map. The big circles and lines feel childish and
improvised. Could we achieve something more sleek looking?", then "Think we could have actual names for the camps too.
More flavor." No dependency: `scripts/chart.lua` draws in the game's own idiom.
- Territory is the 32-tile chunks whose centres lie within the claim, as radar coverage: a faint wash in the
  corporation's colour (rows merged into one rectangle each) and a hairline on the outer edge only (runs merged), redrawn
  only when the claim changes. The claim stays a radius for the game.
- Claims (a kept strip camp, a prospect) are their chunks dashed: held, not settled. A border is a dashed arc of its
  circle either side of the stake. Serenity's next arc is a dashed hairline through its posts.
- Names (`scripts/names.lua`, drawn from the map seed and the settlement's id, none twice): Grubstake's a prospector's
  claim ("Tin Cup Strike", "Last Chance Diggings"), Serenity's a calm designation and a number ("Halcyon Post 7"), a
  headquarters "Regional Office: Haven". On the map label (the name over its standing, which reads "fallen" after),
  the chart tag, `/lp list` and the fall's notice. Scenario `chart`.

### The unit pool (2026-10-17; `docs/ai.md`)
A settlement counted only its units at home against its cap, so the ones out on a raid, a heist or a response were made
again, and units were put back into the garrison while still in the field, to be drafted again from where they stood.
Now its roster holds every unit it owns (`scripts/pool.lua`) and the cap counts them all; units done with a job wait on
`b.returning` until they are home. Scenario `pool` (a full camp: no unit made while 4 are out; old code: 3).
`bombard` then failed: its tier-1 siege's guards (out, now counted) and the spare at home came to 21 of the 22 its
assault needed, where the garrison had grown past the cap before. A siege whose barrage won now commits its reserve
too (guards plus everything at home): 22 went in at once and razed the position.

### One floor for what stays home; one "player" (2026-10-18; `docs/ai.md` 2.3, 2.4)
Every taker from a garrison had its own floor: 2 for responses, patrols, escorts and intercepts, 30% of the cap for
operations, none for a committed operation, a siege's guards or a strip's. Now `pool.take(b, n, floor, fit)` is the
only way units leave, with two floors (`pool.floor`): the guard (`pool.GUARD`, 2), kept by defence, the camp's own
details and an operation that commits its reserve; the reserve (`pool.RESERVE` of the cap, 30%, at least the guard),
kept by an operation of choice. Haulers do not count; Grubstake's buggies do (20 of a camp's 27 units: counting them
out left a full camp unable to raid). A heist's single buggy goes without a floor. Scenario `pool`: a reserve take
leaves 9 of a cap of 30, a guard take 2. A committed operation now keeps 2 home where it kept none.
"Is this a player's force" was written seven ways, two disagreeing on neutral: `shared.is_player_force` and
`shared.player_forces` now. The claim rig's owner was "player" by name: it is the target's owner.

### Each corporation answers its own way (2026-10-18; Fable: `docs/reviews/2026-10-18-answers-consult.md`)
Both answered every provocation with the same raid. Each provocation now has a kind, a loss (its unit, drone or
building) or trespass (its ground, its border, a turret covering its camp), and each corporation a reaction table
(`temper.answers`, `ops.answer`):
- **Grubstake** never fights fair: biters on the culprit (a buggy drives a flare there, `flare.answer`); a raid only
  where no turret covers it. Scenario `flare answer`: an outpost turret kills one of its units; 2 s later a buggy goes,
  16 s after that 20 biters are on the turret, no squad sent (old code: a squad).
- **Serenity**: a loss gets a raid it can win; one it would lose, nothing the first time (remembered), a siege on a
  second provocation within 30 minutes (Fable: a drone shot down unseen is not worth mortars). Trespass gets the siege
  on the turret there, the raid where it cannot siege (none before level 1). Scenario `line turret`: a turret built
  inside its line, at level 1: a siege (old code: a raid); `crew answered` still a raid of 8 that razes the three
  turrets that shot its drone.
- A call against Fable: a turret covering Grubstake's camp still provokes it (an act on the camp, not an unseen
  border), answered by a flare on that turret. Not built: the line stepping over the offending building before the
  mortar; Grubstake's snatch raid at the nearest lootable thing (its raid takes the nearest building, soft there).
Scenario `remembered` (2026-10-18): eight gun turrets kill a Serenity unit (level 1, operations of choice off with
`choice_off`, unprovoked at the start): remembered (32 needed, 10 to send), no raid; a second kill 7 minutes later: a
siege, whose assault razes the block. Provoked from the start, it had besieged them on its own before any answer.

### Stance and the answer (the user, 2026-10-17; `docs/ai.md`)
The user, on Serenity turning enemy and doing nothing visible: "we need to be quite flexible with our coding. It turns
out we've started a real RTS AI system here, with none of the storyboarding upfront". `docs/ai.md` maps every decision
point and proposes three seams (stance, reactions, a unit pool). Built: the stance (`scripts/stance.lua`; one answer
to "how does this corporation treat that player", where `temper_allows`, `at_war` and `choose_siege` disagreed) and the
answer (a provoked corporation's nearest settlement sends a squad at the culprit within a minute or two). Calls taken
for the user: a truce stops taps and strips; an unprovoked rival is not at war (no war footing); the answer is what
the player sees first. Scenario `crew answered` (old code: no answer).

### Crews: floors wait for them; killing one provokes, tested unprovoked (the user, 2026-10-17)
The user, watching Serenity's line with `/lp perimeter`: "concrete pads appear before the drone flies in to build the
turrets and walls" and "destroying the drones doesn't appear to anger the faction?". The pads: `base.build` paved every
floor job at the head of the queue before asking whether a crew takes its module; now a module's floor goes to
`crew.take` like its entities (a cordon post's pad, a mining module's road). The drones: `crew dronekill` (Serenity,
unprovoked; the player kills the drone at mid-road): a rival before, an enemy after. The harness had provoked every
corporation from the start, so `crew doomed`'s check that the trucks' killer is Grubstake's enemy proved nothing; it and
`dronekill` now start unprovoked (doomed passes so). The pad check (`debug_crew` queues a pad first): the pad not laid
before a crew is at the site; on the old build step the pad came 5.5 s before the drone (seen failing), and in game
much earlier (the yard's turn comes long before a far crew arrives).

### Encroachment judged when the player builds (the user, 2026-10-17, on Fable's notices consult)
Serenity was provoked for good by any player building inside its claim, the line's own advance included: an outpost
beyond radar cover was enclosed unseen, and with chat notices off nothing warned of it. Now what a player builds inside
its territory provokes it, judged at the build (`ops.encroached`, from control.lua's `on_built` on the encroachment
types: built by hand, by robot or raised by a script); what stood there before the line moved onto it does not. The
perimeter's warning then guards no loss and is an ordinary notice. Scenario `line`: the relays enclosed, Serenity not
provoked (old: provoked at enclosure, minute 12, and its raids razed the relays); `line built`: an assembler raised
beside the enclosed relays, provoked that tick (old: provoked before); `line back` as before.
- The visit's report adds the player's buildings razed by biters and the corporations' share of the pollution put out
  over the run (from the run's start: the save's history is subtracted). Deathworld, an hour, unprovoked: no building
  razed by biters, the corporations 21% of 81,939.

### Raids that finish, and a provoked Grubstake's size (the user, 2026-10-17)
The user: "Grubstake destroyed my whole base on game speed 20 but I had to launch the sieges and raids myself (as even
provoked, it took no hostile action)". On their save (20 minutes run on, decisions traced) it was an enemy and did raid,
four units at a time at big poles behind the wall, and every raid aborted unhurt. Three causes:
- The breach: a wall piece brought down was put back by the player's robots within 5 s; the order to attack it was then
  done, the raiders wandered by it (wandering is an order, and only units with none were told again) for 3 minutes, and
  the raid went in on its give-up. Now a piece that fell is the breach even if it stands again when the step looks, a
  rebuilt piece is breached again, and a raider idle, wandering or with its target gone is told again (`busy`).
- The aim: a target's record follows the newest building seen in its cell, and the raid's point moved 16 tiles off the
  pole it had hit; told to attack the area there, the raiders found nothing they would attack and stood idle until the
  90 s without a kill ended it. Now the point is fixed as it goes in (`op.pos`) and each free raider is set on the
  nearest building within 16 of it (`attack`, not `attack_area`).
- The size: a raid is sized to the defence the camp knows at the target, 0 at an unguarded pole, so 4 went from camps of
  31 to 54. A provoked Grubstake (an enemy of that player) now raids with half what it can field at least
  (`ENEMY_SHARE`). The ladder's clock still resets on every raze, the user's forced operations included.
On the save, the same 20 minutes: 8 raids of 11 to 28 done (razing their poles), where all had aborted. Scenario
`mended` (the player's assembler and poles in a wall square, a fallen piece rebuilt 5 s later, unprovoked: a temper
scenario, no provocation from the start): 4 raiders breach, keep breaking the rebuilt pieces and raze it (old code:
aborted, the assembler standing). `mended provoked`: 15 of a garrison of 48 (old code: 4). Every other Grubstake
scenario is provoked from the start (the harness: operations' mechanics, not tempers), so its raids grew with this.

### Grubstake's pollution (the user, 2026-10-17)
The docs said settlements were clean; Grubstake's drill was a copy of the electric drill with its 10 a minute kept. On
the user's deathworld save its 90 drills put out 7,200 in 10 minutes, as much as the player's 236 drills (7,115), more
than their boilers (2,282). The user: "they probably generate a lot of pollution. That in itself could be a motivator
for the player to silence them", then "verify that grubstake pollution triggers attacks on the player ... we might need
to bump up said pollution a little". Pollution is the surface's, not a force's: it feeds the same evolution and the same
attack waves as the player's. A spike (own profile, deleted after; 16 drills at 400 a minute, four nests 130 tiles off,
the player's walls and chests 45 tiles from the camp, 40 minutes): with no cease-fire a 200-biter wave razed the camp
and spilled onto the walls; under the cease-fire no wave was ever sent (228 biters waited at the nests); under the
cease-fire with two ordinary player drills by the walls, the wave came at the player's drills and razed the walls and
chests, and with the camp's drills off nothing came (the player's two drills alone never reached the nests). So under
the pact the camp's pollution is sent at the player's polluters near its cloud, and the camp is never the target. Its
drills now emit 15 a minute (`drill_pollution`), Serenity's 0. It reads in the player's pollution statistics by name
("lp-grubstake-drill"); nothing announces it.
- Not yet: whether to show it more (the player sees it only in statistics and in the waves); a camp's share of the
  cloud as a measure.

### Grubstake's power tap (the user, 2026-10-16; built 2026-10-16)
The user: "steal power from unprotected lines? Unassumingly, with a progressively increasing draw", then "Don't think it
should be hidden. It should be connected to their camp through pylons, no?", and "Does grubstake detect exposed poles?
is it able to sneak path to them? the idea is that this is a discreet operation, kind of like the heist". `scripts/tap.lua`.
A Grubstake settlement at war with the player, mature, not standing down, taps only a pole its own sensors have seen
exposed (intel's line cells: no player turret within 60), within 160 of one of its pylons and still with no turret
within 30, nearest first. It lays a line of its own pylons to 12 tiles short of it along the heist's route, out of every
turret's reach (`ops.route`; no route, no tap), a pylon every 20 tiles. It is an operation (the user: "strange that
the tap is built directly from the lander ... a hauler buggy building the pylon line"): the camp pays for the line and a
buggy from its garrison drives the route planting each pylon, sets the tap at the end and goes home; killed on the way,
the operation is over and the half-laid line stands. A cut line is mended by a buggy driven to the missing pylons
(another after 2 minutes if it is killed); the line's pylons are the operation's, never the camp's rebuilding (a module of its own,
`tapline`: built through the queue, paid in parts, rebuilt when lost, never captured). Once the line's end is on the
camp's network it clamps a tap by the pole (`lp-power-tap`: a small lamp's body in its colour, 150 health, not a military
target, so turrets pass it by), and a cable is drawn from it to the line's end. The tap draws from the player's network
(power crosses forces: Engine notes), and nothing is announced: the player finds it in the power statistics, in
brownouts, or by its line. What it gets arrives at the line's end on the camp's network (`lp-power-receiver`,
unseen and indestructible) and counts as supply in the camp's planning, so the camp grows on the player's power. Its
draw starts at 100 kW and rises by half every 5 minutes to 4 MW. Cut the line anywhere and the theft stops (the end is
off the camp's network) until the camp rebuilds the gap; break the tap and it is over (copper cable drops; the notice
says how many MJ it took, `lp.tap-cut`), and 20 minutes later it may try again.
- Scenario `tap` (a player power source and a line of big poles toward a Grubstake camp; `tap_step` 30 s; an unarmed,
  indestructible gun turret on the straight way, 35 tiles from the pole: armed, it fought the camp's units and the pole
  went down in the fight): a line of 4 pylons round the turret (none within 20 of it), the tap clamped; 4 MW by minute 9,
  416 MJ taken; the pylon next to the line's end cut, the draw falls to 0; rebuilt, it draws again; the tap broken, it is
  over. `natural` (no turret: one within 60 of the pole marks it guarded): the camp taps the pole its intel saw, at 5.6
  minutes, the same results. As an operation: the buggy laid 4 pylons and clamped the tap 26 s after leaving; cut, a
  buggy mended the gap in 9 s; 1,156 MJ taken before the tap was broken.
- The grids stay apart (the user, in game: the camp's drills and fabricators showed in the player's network): a pylon
  placed with auto_connect was wired by the engine to a player pole within reach, and the two grids became one, the
  camp running on the player's power outright. `base.unwire` cuts any copper wire between a corporation's pylon and
  another force's pole as it is placed, and the player's own poles as they are built. Scenario `tap`: the camp's grid and
  the player's apart, and a player pole built by the line not wired to it (both seen failing before the fix).
- `/lp flare`, `/lp rig`, `/lp tap` (dev.lua): the three on demand from the nearest Grubstake camp, at where the player
  stands; `LP_MIX=cmd` runs each scenario through the command.
- On deathworld10x (3 hours provoked; 205 gun turrets, a compact base) no tap was laid: the camps knew 0 to 5 exposed
  poles (no turret reaching them; intel's stricter line cells, no turret within 60, gave 0 to 2), none within 160 of their
  pylons and 30 from every turret. Nor a claim jump: 9 guarded targets known, none with chests within 16, and the ladder
  at rung 0 (Grubstake razes often enough that it never climbs). Flares did fire on their own: 5, calling 0 to 11 biters.
  The camps trace why they pass (once in 30 minutes each).
- The line's end: the walk along the route once added a goal pylon 2 tiles past the last spaced one; cutting the next
  pylon left the end within wire reach of the one beyond. The last pylon now moves onto the goal when it falls short by
  under half a span.
- Not yet: the pole's choice ignores how much the player's network has to spare; a tap on a starved network takes
  little. Its stealing is not yet in the corporation's ladder (it razes nothing).

### Standing down (the user: a hopeless camp goes quiet instead of lifting off; built 2026-10-15)
Fable had proposed write-off and relanding. The user asked why not keep the camp and land elsewhere; quiet is better:
the camp keeps mining and exporting (its parts fund the war chest and research for the camps that can reach), it stays
a target for the player (salvage, command cores), and it is simpler. Lift-off may come back as Grubstake's flavour when a
camp is being shelled apart.
- A settlement at war that has razed nothing of the player's for an hour (`QUIET_TICKS`; failed or not tried: a camp
  facing ten lasers launched one raid in 30 minutes) stands down (`war.lua`): no operation against the player but
  self-defence, no relief; it leaves its place in the settlement limit (`faction.alive`), the next landing comes within
  5 minutes and keeps away from its site (`storage.failed_sites`). After an hour it tries again. Notice `lp.stood-down`.
- Scenario `quiet` (provoked Serenity, an assembler ringed by twelve indestructible gun turrets, the hour at 6 minutes):
  stood down after 6 quiet minutes, nothing launched while down, a new settlement 5 minutes later, then it woke and tried
  again.

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
- Biter interplay: Serenity emits no pollution; Grubstake's drills do, and under its pact the waves fall on the player.
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
- **Corporations against biter country (Fable, `docs/reviews/2026-10-14-biter-country-consult.md`; built: corridors and
  Serenity's Clearance).** Units of 7 to 12 a hit cannot clear a nest at any evolution; mortars can (about 109 to a
  spawner a shell, 36 tiles against a medium worm's 30). **Corridors:** every spawner's death (any force) is cleared
  ground for 30 minutes, and within 30 tiles of one nests do not block the route planner (Grubstake follows Serenity's
  crews). **Clearance** (Serenity, any corporation that ever besieges): a raid with nests in its way, worth sending (6,
  or the ladder's second rung), gets a clearance siege instead of a push: tier 2 (two mortars, a convoy), from a site 33
  tiles off the nest nearest home within 40 tiles of the way (out of every worm's 31), always dug in (wall ring and
  pillboxes); its mortars fire on the nests themselves; when nothing is left in reach it moves on to the next nest on
  the way while shells last (up to 8 steps), and the next operation follows a minute after. A corporation that besieges
  never pushes through nests; one that does not (Grubstake), at the ladder's top rung, goes with all it has. Scenario
  `push` (22 spawners and 22 worms across the way, unevolved): clearances moved nest to nest, the nests in the way fell
  from 11 to 2, and a raid of four routed through the corridor and razed the target, about 37 minutes after the first
  refusal (before: 26 of 27 died pushing through).
- **Night of 2026-10-14/15 on the user's save (visits), what kept the player untouched, in order found:**
  1. Settlements knew none of the player's buildings: landings kept outside the player's researched artillery reach stand
     hundreds of tiles beyond its factory, past every sensor. **The survey** (built): every 10 minutes a settlement
     senses the first stretch of each rival player's factory on the line to its spawn (33 to 42 targets each, 10 minutes
     in).
  2. A rival's lander (worth 8) won every choice over the player's buildings even at the top rung, and Grubstake's soft
     held at the top rung: once the ladder presses (second rung), only that player's targets; the top rung overrides soft.
  3. With the player's buildings known and chosen, every way to them crossed 18 to 101 nests (maximum evolution);
     Serenity's clearance hauler died deploying, every two minutes, to the nests' defenders; Grubstake's six harriers
     flying over were bitten out of the air (spawners' defenders; a trigger target mask on the biters' bite did not stop
     it, reverted): overflight only at the top rung. A raid not sent now also holds its settlement 2 minutes (one
     refusal every 30 s re-planned routes).
  4. **Under the guns (built, for review):** against a late player (era 3 and up) a landing's second pass is inside its
     artillery's reach, still 150 tiles from its buildings and clear of nests: the player's artillery keeps its own range
     clear of nests, so on a megabase that band is the one approach. There the corporation's turrets are shelled by the
     player's artillery (on its own), its lander holds on its hull (artillery does not fire on its own at generators or
     units), and counter-battery has the player's artillery in reach. Third pass: nests allowed.
  5. Landed under the guns, every camp's lander died within 25 seconds (no generators yet, so no hull): **the drop's
     power** (built): two generators beside the lander from the moment it lands (the planner's own come later; these
     give way to what it builds). Scenario `guns`: Serenity called 200 tiles from a loaded artillery turret at era 3
     landed 146 out on the second pass, its hull held under the shells, and it destroyed the turret within 5 minutes.
     On the save all six settlements lived the first hour. An outpost occupied now calls for help as one under fire
     does (an undefended one was taken by holding, and its corporation never knew: siege).
  6. Under the guns, camps never keep a depot (the player's artillery fires on them by itself) and operations left only
     from depots: their escorts stood idle at the player's edge. Operations now leave from the lander when there is
     no depot, and a siege or strip not sent also holds its settlement 2 minutes.
  7. Under the guns, camps' depots are shelled, units were built only at depots, and the cap came from depots: camps had
     no units at all. With no depot standing, the lander builds units and counts as one depot (every young camp now
     builds from its first minutes, not only under guns); a raid's affordable size is at least the units at home. A
     raid's log keeps its target's owner as at launch.
     **Visit with all of it (first hour, plain and provoked identical again): 473 of the player's buildings razed**
     (rails, signals and poles first, then 150 lasers, 110 walls, 4 artillery turrets, 4 flamethrowers), two settlements
     doing nearly all of it, from one long raid each (Grubstake under the guns 166, Serenity 307). The player's census at
     the hour: lasers 2,302 to 2,182, artillery 59 to 55. Far past the consult's target (one a 10 minutes a corporation):
     a rate to tune, with the user.
  8. Over the whole three hours: 506 razed (rails 120-odd, signals, poles, 150 lasers, 4 artillery turrets, walls),
     nearly all in the first hour, then quiet as the camps' garrisons bled. Plain and provoked identical again: landed
     under the guns, the player's buildings stand inside Serenity's claim, which provokes it at once (encroachment). The
     raze tally now counts a corporation's kill whether or not its killer survived the exchange (lasers kept falling
     with the tally still). Script cost unclear: 5.65 ms a tick alone against 7.46 with the mod, both on a machine running
     three games at once; to be measured on its own.
- The visit's **expansion** variant (`LP_MIX=expansion`, or `provoked-expansion`): every 20 minutes the scripted player
  places an outpost on the nearest unmined ore beyond its edge (8 drills, 2 powered lasers at its research, a radar); the
  timeline counts the outposts standing.
- **Expansion visit (nwa, three hours, an outpost beyond the edge every 20 minutes, found by the map generator's
  noise).** 8 outposts placed, 6 standing at the end; 343 of the player's buildings razed, almost all in the first 50
  minutes, then one more in two hours while the ladder climbed to its top rung: the pressure is a burst, then the camps'
  garrisons bleed and nothing replaces them. Script: 1.42 ms a tick alone, 2.09 with the mod (+0.66 ms; the evening's
  first visits measured +0.1): to profile (the survey, route planning, clearances' re-tries are the suspects).
- **Profiled (2026-10-15, `LP_PROFILE=1 scripts/visit.sh`, the engine's per-tick timings, run alone).** The route
  planner was the cost: each grid cell tested every turret in its box (a megabase: 2,300 lasers), and the A* open set
  was scanned whole each step. Now turrets and nests sit in 32-tile buckets (a cell tests those near it), the open set
  is a heap, corridors are read once a route. Mean script on nwa's hour: 0.71 -> 0.10 ms a tick; the hour's razing
  unchanged (473, settlements 5 and 7 as before). The profile's units are nanoseconds: the "worst ticks" read as
  seconds were 7-8 ms. What remains is the landings, one tick each: 1.1 s, 0.86 s, 2.6 s (the forced Grubstake
  landing at 20 minutes, which ended at -16,3042), 0.4 s. The trace now counts each landing's candidate sites and those
  on new ground (5x5 chunks generated each): 1/2, 3/6, 1/7, 0/8, 0/8, 10/16, against stalls of 1.1, 0.9, 0.4, 0.4,
  0.4 and 2.6 s. Most of it is the landing, not the search: `base.land` forces the settlement's reach (15x15 chunks;
  queued instead, the planner laid out on missing ground and three scenarios failed), about 0.4 s on ground the
  player's game already made and a second on new; each new candidate adds about 0.15 s.
- **Asynchronous landings (the user, 2026-10-15).** The faction's own landings (the first, the cadence, a headquarters)
  are queued (`faction.request`, `storage.landing_jobs`); every second the queued landing runs its search dry: a
  candidate or the chosen site's reach (15x15 chunks) not yet made is requested from the engine, not forced, and the
  search stops there. Once everything it reads exists it lands as before, on the site the synchronous search would
  have chosen (the same search over the same ground). Past five minutes it lands the old way. What follows a landing
  (the cadence's origin, a headquarters' notice, the phases' arrival) runs by the job's kind. The remote `arrive` and
  `/lp land` stay synchronous (the scenarios and the developer want the settlement at once); `arrive_async` is the
  queued one. Scenario `async`: a landing 900 tiles out on a fresh map waited twice for its ground and landed 3 s
  after it was called, unforced.
  Campaigns on both seeds (6 hours, all of today's work): much as the evening's: three landers killed, two of three
  camp strikes won, no consolidation, batteries never lost, 9 and 11 operations.
- **Profiled again (2026-10-17, deathworld10x, 3 hours, run alone).** Mean tick 0.25 ms without the mod, 0.48 with it;
  the mod's script 0.04 ms of that (the rest is the engine running the camps). But one tick every two minutes from the
  49th minute took 300 to 415 ms: Serenity chose the same raid on a Grubstake generator through biter country, the
  route failed (12,000 cells searched, twice), and the target cooled two minutes. Two fixes, the visit's decisions and
  razing unchanged (value 568 before and after):
  - A raid whose route nests alone blocked is not planned again from the same home until a spawner dies somewhere
    (`ops.cleared_since`: any spawner's death opens a corridor). A turret in the way (Grubstake's sneaking leg) is not
    remembered: it can fall without a corridor.
  - The route planner marks each turret's and nest's reach on its grid once, and a cell looks itself up (was: each cell
    probed 16 buckets by string key). A failed route: 345 -> 100 ms. Water tests were 5% of it.
  Worst tick after both: 118 ms (was 415); two failed routes in three hours (the first, and one after a corridor opened).
  The other two saves (3 hours each, alone): nw 0.52 -> 0.63 ms a tick (script 0.04), nwa 1.50 -> 1.70 (script 0.09).
  On nw, two more repeated searches ran dry, each 100 to 200 ms: Grubstake's sneaking raids staged inside the factory's
  turrets (one substation after another in the same enclosure), and its power tap trying three unreachable poles every
  five minutes. Now a staging point within 64 tiles of one that failed for turrets in the last 30 minutes, from the same
  home, is taken to fail; a pole with no route waits 30 minutes (`b.tap_no_route`). nw: about 45 such searches in three
  hours -> 15, the tap's series gone, its razing unchanged (112). nwa's 350 ms every ten minutes is the test harness's
  census of its factory, not the mod.
- **nw again (2026-10-17, later, 3 hours, alone).** The ticks left over 100 ms, one every two minutes from the 20th
  minute, were Grubstake's raids on substations on a solar pier out in a lake: the staging point fell back to a point in
  deep water (`outside` had found no dry one and returned the stand-off anyway), and each search flooded the land round
  it, 21,000 cells and 80 ms, before failing. Serenity's nest-blocked raid was planned again on every spawner death
  anywhere (the factory's artillery kills them all the time). Three fixes:
  - The route planner floods from the target first (up to 3,000 cells, the same cells and moves as the search, on
    each box's own grid): a pocket sealed all round fails at once (80 -> 1.5 ms). A pocket that reaches the box's edge
    is not sealed (the wide box may get round).
  - No staging point in water: a candidate with water within 8 tiles is passed over, and a stand-off fallback in water
    means the raid is not sent ("no staging point on dry land", the target cooled 15 minutes).
  - A raid remembered as blocked by nests is planned again only when a spawner dies inside the box its searches covered.
  nw, the mod's own ticks (the harness's apart): over 50 ms 71 -> 25, over 100 ms 48 -> 1 (205 ms, once). Mean script
  0.042 ms a tick. `scripts/visit.sh` (LP_PROFILE) now reports the harness's ticks (setup, the census every 10 minutes,
  the end) apart from the mod's.
- **With Space Age (2026-10-19, 0.1.17, 3 hours provoked).** deathworld10x (profiled, run beside nw): mean tick 0.38
  ms without the mod, 0.75 with it, the mod's script 0.050 ms; 549 ticks over 5 ms, 2 over 50 (104 and 57 ms). 394
  buildings razed in 14 raids, 144 corporation units lost. The worst ticks fell on the planners' shared beat: four
  bases choosing a rule (site searches that found nothing), exporting and deciding raids (one route search of 11,600
  cells) on the same tick, every base on `tick % N == 0`. Each base on its own beat (`b.id` offsets) was tried and
  withdrawn: the full regression failed army, tap, unitnode and ability (their timings ride the shared beat; planning
  and export staggered alone still failed three). Open: stagger with those scenarios' timings made robust. nw: 0.75 -> 0.96 ms a tick, razed 7, corporation buildings lost 1,236 (989 rebuilt), 116
  responses: Serenity still stands in the lane of the waves the factory's pollution draws (the "buffer", open).
- **deathworld10x on 0.1.20 (2026-10-19, 3 hours provoked, profiled, alone).** Mean tick 0.32 ms without the mod,
  0.51 with it; script 0.044 ms; 483 ticks over 5 ms, 2 over 50 (128 and 61 ms). The player's buildings razed, all
  corporations: 878 (transport belts 381, walls 188, poles 99, inserters 73, gun turrets 64, assemblers 19). Five
  settlements, none fallen; hazard removal cleared three nests (five hazards traced) and the pressure stood. The belts
  are mostly the line's cut and the raids: unmeasured apart (the cut keeps no trace line); a playtest question whether
  the cut bites too hard on a belt base.
- `scripts/sheet.py`, `scripts/replay.py`, `scripts/overview.py`: variety sheet, raid replay, faction map.
- Scenarios (`tests/lp-sim/control.lua`): grow, cut, raid, occupy, assault, defend, faction, uplink, army,
  caps, lively, convoy, train, orders, siege, duel, showcase, and the spikes air, path, cost, probe. Each
  needs its own length: a regression at 30 minutes with the strike at 10 failed raid, occupy, defend and
  faction for lack of time (all pass at 60/30). A run that ends before its scenario's checks fails, and each scenario
  states how long it needs after its strike.

### The factory instrument (2026-10-19; the user: "I don't have time for playtesting"; scenario `factory`)
A scripted mid-game player in place of one: a factory at the spawn that pollutes (30 assemblers on infinity chests), a
ring of gun turrets kept in ammunition, an outpost every 15 minutes on a new iron patch 150 to 300 tiles out with
eight drills on a belt home (its end emptied and counted: the income), ghosts rebuilt once no corporation unit stands
near, two gun turrets added by an outpost that lost something (six at most). A Grubstake camp (a rival) and the usual
Serenity camp from the start; Grubstake's thieves' hours on. Mixes: `control` (the corporations harmless: a test knob,
`harmless`), `turtle` (as above), `engage` (also: a skimming truck killed after it parks, one leader a raid killed as
it attacks, Serenity's invoice paid at 300 or less). Two hours, two seeds:

| Seed | control | turtle | engage |
|---|---|---|---|
| 12345 | 84,803 ore | 70,092 (-17%); lost 926; Grubstake razed 114, dismantled 41, skimmed 724; Serenity razed 111 | 70,648 (-17%); lost 797; trucks 3, leaders 29 |
| 777 | 105,700 | 68,297 (-35%); lost 986; Grubstake razed 247; Serenity razed 451, 4 sieges | 73,355 (-31%); lost 1,628; Serenity razed 750 |

Read: the corporations cost a sixth to a third of the factory's income; the engaged player's answers (trucks, leaders)
buy 1 to 7% back: decision 3 ("engaging must pay better than turtling") is not met by these answers; the instrument's
engaged player does not yet strike a camp, the yard or the line, where the design puts the payoff (next). No bill
came: biters did not hit Serenity on these maps. Found on the way: Serenity's raid regrouped every time a new leader
fell (an engaged player killing each as it rose: 63 regroups, a raid that never broke): now once a raid, a second
leader lost and it falls back home.
Strikes (the engaged player, next): every 30 minutes from minute 20, 12 troopers, 4 breachers and 4 battle tanks at
Grubstake's yard (else its lander); what lies on the ground there 8 minutes later is picked up. Seed 777: the first
strike took its lander, the camp fell, 143 stolen items back; income 77,234 against the turtle's 68,297 (+13%). Seed
12345: four strikes, the lander standing, 10 items back; a rival hit becomes an enemy and Grubstake razed 213 (114
turtling); income as the turtle's. A strike that wins pays; one that fails makes the thief worse. Whether engaging pays
turns on whether the player's army can take a camp (fought capture, open).
What fires (the turtle, two hours, two seeds; every mechanic counted, `factory ... mechanics`): Grubstake's raids,
dismantling, skims, prospect claims (2 to 3) and taps (4 to 5); never flares (no nest within 600 on these maps), the
claim jumper (it waits for the ladder's second rung, 20 minutes without a raze: while its raids work it never gets
there: heists are what a thief turns to when raiding fails, which reads right), or strip-mining (its intel had seen
none of the player's drills: they lay beyond its camp's sight; it strips what it has seen). Serenity: raids, two to
four sieges, the line's cut. Nothing is cut on this evidence: what stays silent here is waiting for the map or the
base that calls for it. Two instrument fixes on the way, each a player's habit: the map charted (prospecting reads
charted chunks: headless charting never lands, so `prospect_uncharted` as its tests do), a buffer chest and a radar at
each outpost; a belt cut on Serenity's line is crossed underground when rebuilt (rebuilt as it was, it was cut again:
635 cuts in two hours; 121 with undergrounds, and the player's losses on seed 12345 from 757 to 351). Serenity's line
built no post on seed 12345: its claim (228 from a camp 339 from the spawn) already took in the player's first
outposts, so the line had nowhere to step; its cut is what the player meets there. `strip` now says why it chose none.
Engagement (Fable: `docs/reviews/2026-10-19-engagement-consult.md`: "big win, costly failure is the right peak but the
wrong floor": small kills should stay paid). Built from it, for Grubstake: a damaged lander mends slowly (1% a minute,
smoking below 90%), and while it is below 60% or fewer than half its generators stand its raids are held home
(`ops.camp_hurt`); each skimming truck lost or raid broken by its foreman's death holds its next operation back 10
minutes (`ops.setback`). The engaged player's strikes now go for the generators by the lander while its hull holds.
First runs (one seed each): setbacks fire (9 to 16 in two hours) but no strike of 20 got through Grubstake's garrison
to its generators (the lander at 100%, its hull up, on both seeds): the player's army taking a camp is the open
question again (fought capture). Runs are deterministic (a seed and the code give the same numbers; the turtle on 777
made 62k to 80k only because the code changed between runs), so the spread worth reading is across seeds:
`scripts/factory.sh` runs each mix on four seeds in parallel and reports means and spread. Two hours, seeds 12345, 777,
4242, 1: control 100,476 (sd 10,448); turtle 61,924 (sd 5,664; lost 462); engage 62,266 (sd 7,036; lost 468). The
corporations take 38% of the factory's income; engaging (trucks, leaders, invoices, four strikes) buys nothing on the
mean. The strikes are where it should pay, and they do not take a camp. Each strike, recorded: all 20 dead within 8 minutes, Grubstake 31 to 48
units down, both generators by its lander standing, the lander at 100%. So a camp whose garrison bled (under half its
strength of the last hour) holds its raids home too (`ops.camp_hurt`); four seeds again: engage 63,062 (sd 8,470)
against the turtle's 61,924: no change, and no raid was held (its garrison never fell under half: what the strikes
killed was a part of it). Left there: tuning the corporation against a crude scripted strike would fit the game to the
test. The question is the design's: what force should it take to break a Grubstake camp, the thief that "does not
build to last" (fought capture, open since 2026-10-13).
How a strike moves (scenario `blob`; the user: "does the blob move at the speed of its slowest unit? Or does it
trickle in?"): the 20 in one engine unit group marched 290 tiles over open ground at about 5 tiles a second, front to
rear 12 to 19 tiles all the way (troopers ahead, the tanks 7 tiles behind them); go_to_location and attack_area alike.
A blob, not a trickle, until it fights (each member then answers on its own). Two traps on the way: an attack_area with
nothing at its destination finishes at once with the group unmoved, and units do not path into ungenerated chunks.
Engine groups drop a stuck member and go on (the convoys' finding, `army.lua`: discipline kept by script instead).
A player who learns (the user: "Yeah" to a smarter strike): 20 strong, 15 more for each strike that left the lander
standing (65 at most); the nearest Grubstake turret by the target first, then the generators by the lander, then the
lander, re-aimed every 30 s; 4 troopers joining every 2 minutes for 8 minutes. Four seeds: Grubstake's lander taken on
every one, by the third strike (50 strong) or the fourth (65); earlier strikes left it at 64% or 54%, which the next
built on. Engage 67,034 (sd 7,785) against the turtle's 61,924: +8%, and 282 buildings lost against 462 (-39%), though
the camps fall in the last half hour of two. Engaging pays, modestly, once the player mounts a real assault: a
Grubstake camp takes 50 to 65 units on the third or fourth try (the user's call whether that is the right price for a
camp that "does not build to last"). Then, to make a camp a landmark one wears down (the user: "A camp seems like a
significant landmark"): the lander smokes as it is hurt (thick below 60%), and a fallen camp's yard bursts, everything
it stole spilled. Tried and withdrawn: what a player destroyed of a Grubstake camp's defence put back slowly (generators
in 10 minutes, turrets 5 later). One lander of four fell against four of four: the parts it did not spend rebuilding
went into units, a bigger garrison. In a parts economy, delay is not damage; what wears a camp is what it loses.
Also withdrawn: a camp counted hurt when under half its generators stood (it never fired in these runs; with slow
rebuilds it would have kept the raiders home to guard the camp). Reverted, four seeds: the four landers fall again (strikes 3 and 4);
engage 66,762 (sd 7,573), lost 301, against the turtle's 61,924 and 462.
Four hours, four seeds: control 296,662; turtle 156,158 (-47%, lost 1,726); engage 169,820 (-43%, lost 1,461; Grubstake's
camp down on every seed). The corporations' cost grows with time (38% at two hours, 47% at four), and the late growth
is Serenity's: its raids (6 to 9 an hour throughout) take more each (its garrison grows, its ladder climbs), and on seed
777 its line cut 3, then 97, then 201 belt tiles an hour (the instrument's undergrounds cover a tile, not the band, and
the edge moves on). The engaged player had no answer to Serenity.
The line broken (the user: hunting the line "needs to be workable"): over half the posts of the arc its claim stands on
lost their turrets, the claim falls back to where it stood before that arc, the arc's pieces still standing are pulled
down (half their parts back), its rebuilds and the arc being built beyond dropped, and the line waits 15 minutes before
it steps out again (`cordon.check`, once a minute). Scenario `cordon broken`: two arcs stood, the leading arc's eight
turrets destroyed: the claim from 120 to 90 within three minutes, still 90 thirteen minutes on. Then the engaged player
hunted it (from minute 40, every 20 minutes, 30 units at the leading arc's turrets): two seeds, four hours: 142,853 and
161,392 against 155,659 and 188,045 without (-8%, -14%); the line broken one or two times; Serenity's answers 12 to 14 a
run. Each post hit is a provocation, and its answer cost more than the broken line saved. The user took fair war: a
cordon post's pieces hit raise its alarm (its units come to defend it) but provoke no answer. Two seeds again: 4242 the
same to the ore (one line strike there), 777 123,861 (-20% on the run before): the answers (12 to 15 a run against the
turtle's 5) came from losses, Serenity's units killed wherever the strikes met them, not from its posts. Open: whether
Serenity, at war from landing, should answer every loss (built for a corporation that started at peace) or only
trespass.
Watched (`scripts/watch.sh`, the user wary of the harness): the factory scenario in a game window at speed 10, a
screenshot of the factory, Serenity's line and Grubstake's camp every 10 minutes and of each strike group: seed
12345, engaged, the strikes march to Grubstake's camp, fight at its walls, the lander falls on the third (the run's
numbers as headless: 69,528). On that seed Serenity's line never stepped out (nothing for the line strikes). And the
harness's limit, shown by these runs: deterministic but chaotic, a small rule change re-rolls a seed's game (777 gave
155,659, 142,853 and 123,861 under three line rules); at two seeds a 10% effect is not distinguishable from that.
Decisions of that size want eight seeds or more.
Trespass only (the user agreed, 2026-10-20): Serenity, at war from landing, no longer answers a loss; its units killed
in the field are fair war, and only trespass (its ground, its border, a turret by its camp) gets the siege
(`ops.request_answer`). Scenario `remembered` turned round: two of its units killed by turrets, neither answered.
Eight seeds, four hours, turtle against engaged (four engaged runs crashed, below, and were run again fixed): income
173,450 against 184,363, engaged ahead on six of eight, the pairs' difference +7.7% (spread 19.7%, standard error 7%):
a lean, within the noise (one seed alone varies some 13% run to run). What the corporations did is sharper than
income, summed over seven of the pairs (seed 8 engaged ran later):

| | turtle | engaged | engaged lower on |
|---|---|---|---|
| Grubstake's skim (items) | 5,863 | 22 | 7 of 7 |
| Grubstake raids | 168 | 84 | 5 |
| Serenity razed | 3,067 | 1,860 | 5 |
| buildings lost | 13,378 | 11,385 | 6 |
| Serenity raids | 218 | 212 | 4 |
| belt tiles its line severed | 2,784 | 2,924 | 3 |

Fighting Grubstake breaks it (its trucks killed, its camp down, its raids halved); Serenity's tempo does not answer
anything the player does: as many raids, as many belt tiles cut. That is the next problem (Fable's "escalate against
what the player did, set back by what it kills").
The runs found two crashes and a blind spot: a claim jumper's hand ordered to attack a ghost (four seeds; targets now
need health), a line crew sent home after its lander fell (seed 8; every `home` helper now returns nil once nothing
stands, and its callers wait); and intel named each 32-tile cell for its most valuable structure, so the substation
feeding an outpost hid its drills and strip-mining knew none on a factory of drill outposts (it now counts drills per
cell). With the count, it knows one to three; the instrument guards every patch it mines, so strip finds no camp site
out of turret reach, a fair no. Also seen: the flare never fires in the instrument, whose maps have no nests
(`scripts/map-gen.json`); the claim jumper waits for its ladder's second rung, and Grubstake's raids keep razing, so
it never climbs (tricks come when force fails; left as it is).
Why the line kept cutting: it cut every belt on its claim's edge, all the way round, posts or none; broken, the
claim fell back and its new edge cut again. Now it cuts only where its guns are (a turret of its within 30 tiles,
half a post's spacing, `ops.sever`): a standing arc covers its span, a broken sector is open. Scenario `strangle
sever`: a belt by its turret cut, a pipe on the edge with no gun by it left (where its arcs bear the pipe was cut: a
real post stood there), an underground by its guns passing. Eight seeds, four hours (`scripts/factory.sh` now sums
what the corporations did as well):

| | turtle before | engaged before | turtle | engaged |
|---|---|---|---|---|
| income (mean) | 173,450 | 184,363 | 188,965 | 201,385 |
| belt tiles severed | 3,584 | (as the turtle) | 712 | 427 |
| Serenity razed | 3,389 | | 4,209 | 3,524 |
| Serenity raids | | | 250 | 238 |
| Grubstake raids / skim items | | | 179 / 4,845 | 84 / 19 |

Engaged against turtle, paired: +6.9% (spread 12.1%, standard error 4.3%), ahead on six of eight; the engaged player
now cuts the line's cutting by 40%. Serenity's pressure moved from belts cut out of sight to raids (razed up a quarter
on the turtle). Its raids still come at the same pace engaged or not: blunted, not slowed. Left so: Serenity is the
relentless one; what the player wins is the bite.
Away (Fable's worry: Serenity at war while the player is on another planet): mix `away`, the turtle with its player
gone from minute 60 to 180 (no rebuilds, no ammunition, no undergrounds, no turrets; its outposts still come on
schedule: a first run without them lost income to growth that never came). Eight seeds against the turtle's runs (seed
5 crashed, below, and ran again fixed), income by hour summed: turtle 183k, 443k, 477k, 406k; away 183k, 253k, 168k,
339k: 57% and 35% of the turtle's while away, 83% the hour after it came back. On two seeds (1 and 8) the factory made
nothing in its second hour away; on return 19 to 136 ghosts were waiting, and no turret had run dry (the raids break belts and
drills, not the guns). Two hours away cost about one hour of income and the factory came back within the hour: it
survives. No nests on these maps, so there is no vanilla baseline to set it against.
A third crash, found there: a Grubstake raid dismantled one of its own drills (a camp the player captured) and left
its ghost, which a corporation's building cannot have (no item places it); a ghost is now left only where an item
places the building.

### Screenshots (2026-10-19; `scripts/shots.sh`, `tests/lp-shots`)
What headless runs cannot judge, seen: a game window on its own profile stages scenes through the mod's remotes (the
units side by side; a skim by night with headlights; the yard; a raid's leader icon and the ghosts it leaves; the
invoice post by day and under a truce by night; a jammer among robots; both camps from above) and frames each in a
surface screenshot to `script-output/lp-shots/` (`shots.txt` says what to look for in each). The tips bubble's Tab
is sent through System Events with the game brought to the front. First runs, unattended: the first shot (54 units)
taken, then the game stopped ticking at tick 600: the display was asleep (a screen capture came back black) and
nothing renders then. It needs the screen awake: run it when the user is at the computer. The units shot needs a
tighter layout (54 at 13 tiles apart overflow the frame).

## Engine notes
- Pathfinding is the engine's (the biters' pathfinder): units route around whatever their collision mask
  hits; with no way round, ground units shoot through; groups arrive as blobs; spider-units step over;
  air units fly straight. Long trips go in ~100-tile legs.
- An idle unit attacks any enemy in sight: give units a lasting order (arrive, then wander in place).
- Commands: `wander` takes no destination and lasts forever by default (`ticks_to_wait`).
- Pollution attacks pick polluters the biters may attack (spike, 2026-10-17): a polluter under cease-fire with the biters
  is never a target, and its pollution sends waves at other forces' polluters instead; with no other polluter, none is
  sent at all.
- Player turrets fire only at military targets (`is_military_target`): ordinary enemy buildings are ignored.
- A gate of another force across a player's straight rail blocks the player's trains (spike, 2026-10-17): two gates
  placed by script on an east-west rail (direction north), a player locomotive at speed 0.5 stopped at 37.6, the gate at
  40.5. Serenity's cordon uses it (gate posts).
- Power crosses forces (spike, 2026-10-16): an entity of any force inside a player pole's supply area is powered by the
  player's network (a radar of a new force ran on a player pole, same network id). A corporation building standing in
  the player's supply areas draws the player's power; the power tap (below) is built on it.
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
- A cease-fire both ways with the enemy force holds: worms hold fire, attack groups ignore the force's buildings, its
  turrets hold fire on biters (spike, 2026-10-15).
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
- A unit's order ends when its target falls, and the unit stands idle until script orders it again: idle, it attacks
  what it sees. The claim rig's hands walked into turrets that way, and a walk to where a unit already stands ends at
  once (end every order with a stop; "no hand fell to a turret").
- Three `--full` scenarios had failed unseen for a day or two (the full set not run since; bisected 2026-10-18):
  `fall` from 36c8f09: an evacuee of the fallen camp, now its neighbour's, wandered by the ruins and counted as the
  outposts' defence (only a settlement's own units and its turrets defend now; the evacuation takes its whole roster,
  an operation's units and those on their way home were left behind). `faction` and `uplink` from 3a5a8c4: the first
  landing was the late corporation, its gate shut, and the other waited for a second landing that could never come
  (a corporation not gated comes then); and Serenity's constructor drones fly on a harrier's body, counted as harriers
  before their tier (crews excluded). Run `--full` before a batch that touches growth, landings or the fall.
