# Landing Party: design notes

Living document: what is decided, what is built, what is deferred, and what the engine allows.
Prototype stage. Prefix `lp-`. Mod folder `landing-party/`.

## Premise
A rival machine faction lands on Nauvis and builds a factory of its own. Its army is the output of its
economy, so the war is economy against economy, fought along supply lines. Biters punish pollution; the
Landing Party punishes predictability.

## Principles (decided)
- **Same rules as the player.** Their strength comes from what they mine, power and build, never from a
  timer. Scouting their economy tells you how strong they are; striking it changes the next fight.
- **Arrival, not awakening.** The player's first rocket launch is heard. A lander comes down at a visible
  distance, small, and grows. Strike early or come back from another planet to a competitor. (Space Age has
  no satellite; the first launch is when the player leaves Nauvis, so a strong faction waking then would
  be a base loss with no answer.)
- **A readable base.** Bases are a graph: nodes (lander, generators, mining, fabricators, turrets, depots)
  joined by power. Cutting an edge darkens what lies downstream. The player should be able to read the
  base and find its weak point.
- **Few, visible planner rules.** Every planner bug reads as a stupid enemy. The planner applies a short
  list of priorities and says which one it chose (debug overlay, log). Layouts are hand-designed modules,
  never procedural.
- **Killing is cheap, holding is hard.** Artillery and nukes will always kill a node. A destroyed node is
  rebuilt from its depot unless the player's forces occupy the ground. Artillery kills, infantry holds.
- **They compete for ore.** Their drills deplete real patches: the pressure is felt before any attack.
- **Capture and an ending.** Captured mining and power nodes work for the player. The faction has a core;
  when it falls, the war ends.
- **Orders through entities.** The player's army is commanded mostly by rally beacons (circuit stance and
  target), the selection tool being the manual override.
- **Art is retinted vanilla** (cold blue-white) until the mechanics are proven.

## The faction over a game (decided with the user, 2026-10-12)
- **Not one base: a constant, growing threat.** A single base is steamrolled by a fast player. The faction
  lands repeatedly: each landing grows into a settlement of its own, and the faction's tier (better turrets,
  shields, units) rises with what all its settlements build. Clearing a settlement is a win, not the end.
- **An optional boss.** One landing is different: the uplink, a fortress core that calls the next landings
  and holds the faction's research. Taking it is optional and hard; it neutralises the faction or at least
  gives a definite upper hand (no more landings, tier frozen). Exact terms open.
- **They gravitate to ore and drain it.** Landings seek rich patches; their drills strip a patch faster than
  the player's would. Waiting costs the player the patches they will need next: an incentive to clear early.
- **Hubs, not a single core.** A settlement is a graph of hubs, each with its own fabricators and depot.
  Losing a hub costs a region, never the faction.
- **Architecture, not Biters+.** Settlements are laid out like engineering, not grown like nests:
  - a block grid with roads left open (vehicles, theirs and the player's, can drive through);
  - hard points are walled: pockets of walled defence at hubs and approaches, with gates on the roads;
  - outposts stay open (soft, covered by the depot's response);
  - the uplink is a fortress core: concentric walls, shields, many turrets.

## Economy over a settlement's life (decided, 2026-10-12)
- **Growth, maturity, export.** A settlement grows to its doctrine's size, then stops claiming patches.
  Mature, it spends first on defences and a garrison (up to a cap), then exports the rest off-world from a
  launch block: a visible pad sending cargo up. Exports raise the faction's tier. This is what justifies
  a steady draw on the patches, and the launch pad is an objective worth raiding.
- **Patches are skimmed, not stripped.** Drills run at a moderate rate: a patch lasts hours. The pressure
  is that the player cannot use a patch while they hold it. Relocation is a rare event, not growth.
- **Maturity shows.** Camp (bare), settlement (roads, walled compounds, pickets), mature (a second ring of
  staggered walls before hard points, minefields on the approach roads, paved blocks, lamps that glow cold
  blue at night, decorations).

## Units (decided, 2026-10-12)
Roster on vanilla bones, own tint and stats: drone infantry (the character, as ERM RedArmy does), walker
(spider-unit from the spidertron), tank (a tank-shaped unit), harrier (air: a custom collision layer and
trigger target type that walls, mines and flamethrowers ignore; scarce and costly). Optional dependency:
ERM Unit Control (LGPL, works with any unit) for selection-tool commands. Learn from ERM RedArmy (LGPL),
Robot Army and Commander (MIT); read Nullius: Hostile Incursion (GPL), do not copy. Never ERM's StarCraft
or Metal Slug art. Target Factorio 2.0 (2.1 is on the experimental branch only). Closest prior art:
Proliferation (MIT, no public source): study it to differentiate.

## Proliferation, and how Landing Party differs (read 2026-10-12, v0.35.0)
Proliferation (Cody T. Newman, MIT, no public source, first release 2026-08-08) is a machine faction in the
mould of Stargate's Replicators. Bases are placed at map generation on custom "matter nodes" and run a real
chain (pumpjack, alloy, components, their own science and research) through four build stages to a walled
compound. Its one unit is the walker: garrisons fill a deployer, then go as a wave to found a base, hit the
nearest player structure or the nearest nest. Waves eat belts and items to grow, buildings below 30% health
are captured, dead walkers leave fragments that grow into new bases. Later: ships boarding platforms, a
planet (Hala) with cities. Hostile to biters too. Its character is a swarm, an infection.

Where Landing Party stands apart, and should stay apart:
- **They arrive because of you.** Landings follow the player's launches, repeatedly, not bases scattered at
  map generation.
- **Real ore, contested.** Settlements sit on the player's own patches, skim them and export the take, rather
  than mining a node of their own.
- **Planned settlements, readable as architecture.** Hubs, roads, walled hard points, doctrines and pickets;
  a supply graph the player can read and cut. Proliferation grows bases through fixed stages.
- **Combined arms.** Infantry, walkers, tanks and aircraft that ignore walls, against one walker type.
- **An economy war with an RTS layer.** Cut lines, raid launch pads, occupy ground so it is not rebuilt, and
  field an army of your own commanded through rally beacons. Proliferation gives the player no army.
- **A strategic arc with an end.** Tier rises with exports; the uplink is an optional boss that stops the
  landings. Proliferation states no end condition.

Avoid converging on its signatures: no capture at a damage threshold (ours, if any, is capture by holding a
node), no units growing from eaten items, no fragments. Both use their own force; with prefixes `lp-` and
`proliferation-` they should coexist, and a three-way war with Replicators would be a compatibility test.

## Release plan
1. **Rival factory**: landing, the node economy on Nauvis, power as the graph, defences (turrets, powered
   shields, jammers), depot response and rebuild-unless-occupied, ore competition, air raiders with one
   anti-air counter, capture of mining and power nodes, a core that ends the war. Rally beacon and one
   infantry type (occupation needs a holder).
2. More player unit types, forward depots and supply.
3. Selection-tool control, biter interplay (robot buildings pollute, biters raid them), adaptation.

## Prototype 0: the base builder (current)
Goal: work out the mechanics of base building, watched headless, before any combat design.
- A force `landing-party`. A lander (`lp-lander`, the crash-site spaceship as a power source) is placed at
  a site with ore within reach.
- Economy: drills (real `mining-drill`, they deplete real ore) drop into bins; the script collects bins on a
  powered network into the base's feedstock; fabricators (real assemblers, so the engine handles power and
  speed) turn feedstock into parts; parts pay for construction.
- Power is real engine electricity on the faction's force: generators and pylons. A node off the network
  stops.
- Construction: a build queue places one entity at a time, paid in parts, from the nearest powered node.
- Planner: every few seconds, per base, pick the first rule that applies and queue a module:
  1. **Power**: demand (with the next module) exceeds supply -> generator module.
  2. **Fabricate**: feedstock piles up beyond what fabricators use -> fabricator module.
  3. **Mine**: fabricators starve -> mining module on the nearest unclaimed ore.
  4. **Defend**: a node lacks turret cover -> turret pair beside it.
  5. **Grow**: parts pile up -> mining module further out (sprawl).
- Losses: a destroyed entity is rebuilt at its spot after a delay (1 min plus 1 s per tile from the
  lander), before any new growth, unless a hostile turret, unit, vehicle or character stands within 12
  tiles (walls do not count). The planner counts what it owes as still there and builds nothing on held
  or reserved ground.

## Architecture (built, 2026-10-12)
`scripts/layout.lua`, `scripts/blocks.lua`, `scripts/rng.lua`.
- **Hubs on a grid.** A hub is a grid of 18-tile blocks with 4-tile roads (`lp-road`, tinted concrete). One
  pylon powers a block (supply 9). The first hub starts with the landing pad (two cells, walled, the
  lander at its centre); later hubs start with a walled compound holding its own generators (cut its
  lines and its turrets still fire).
- **Blocks by role, filled on demand.** Fabricator, generator and depot blocks open when the planner
  needs a slot and none is free; slots fill one machine at a time. Each role has 2-3 hand-made variants,
  mirrored and transposed by the seed.
- **Growth order by archetype**, drawn per hub: grid (compact), street (two rows along an axis), cross (four
  arms). Cells that fail the terrain (water, cliffs, ore, roads, buildings) drop out, so outlines follow the
  ground. A hub that is full (doctrine cap) or boxed in founds the next hub, near the outpost furthest from
  every hub.
- **Doctrine per settlement**, drawn from its seed: bastion (every block walled, corner turrets, outposts
  turreted, 7 blocks a hub), sprawl (only pad and compounds walled, open outposts, 4 blocks a hub, hubs
  founded further out), picket (two walled radar pickets per hub between it and the threat).
- **Walls come with maturity**: the fortify rule walls blocks once the economy runs (a camp first, then a
  walled settlement). Walls have an opening in the middle of each side, on the roads (gates later).
- **Roads**: round every block, along long pylon lines (supply routes), and as spines through mining
  outposts (every fourth lattice column is left empty).
- **Variety is measured, not assumed**: `scripts/sheet.py` draws a contact sheet of many runs at one
  scale and prints shape metrics (hubs, blocks, walls, footprint, aspect, fill) with their spread.

## Testing: headless first
Launching the game costs the user's time; the headless run costs none. Every mechanic gets a scripted
scenario with assertions before anyone plays it; the window is for art, feel and GUI only. Combat runs
headless too, so most of the spikes below can be scenarios.
- `scripts/sim.sh <scenario> [seed] [minutes] [every] [strike]`: one run in its own profile, base game
  only, no biters. Plots (`growth.png`, `final.png`), the planner's `decisions.txt` and results go to
  `docs/sim/<scenario>-<seed>/`.
- `scripts/batch.sh [scenarios] [seeds] [minutes] [strike]`: runs in parallel and prints one table of
  metrics (modules over time, parts, losses, rebuilds, ms per tick). Timings from a parallel batch are
  inflated by contention (0.28 ms alone read 1.6 ms with eight at once): measure performance alone.
- Scenarios (`tests/lp-sim/control.lua`): `grow`; `cut` (every pylon line dies: income falls within a
  minute, lines and income come back); `raid` (every fabricator dies: rebuilt, not duplicated, production
  recovers); `occupy` (fabricators and nearby turrets die, an indestructible player turret holds each spot:
  nothing is rebuilt there until they leave, then everything is).

## Findings from the prototype (2026-10-12)
- The rules give a readable base unaided: a core of fabricators and generators round the lander, a drill
  grid on each patch, one turret pair per node, and long unguarded pylon lines to outposts up to ~200
  tiles away (seed 777: a hub and six outposts).
- Growth was too fast and then stopped: the starting area is claimed in ~20 minutes, after which parts pile
  up unspent (15,000-19,000 by minute 60). Parts need sinks (units, response forces) and growth a slower
  pace; the reach steps (40, 90, 160 tiles) bound the sprawl.
- Bugs the scenarios caught, each now a test: instant rebuilds made cutting a line meaningless; the planner
  built new fabricators while the old were owed, and on the very spots the player held; a stockpile left
  by a raid made it double its fabricators (fabrication now follows the flow of ore, never the stock).
- Engine: `auto_connect` on a scripted pylon does not reliably rejoin a cut line (seed 34: three rebuilt line
  pylons joined nothing and income stayed at zero). Every new pylon is now wired explicitly to each other
  network in reach.
- Cost: 0.29 ms per tick for a 60-minute base (seed 12345, measured alone).
- Variety, 12 seeds at 60 min: all three doctrines and archetypes; 1-2 hubs, 1-11 blocks, aspect
  1.0-5.9, fill 0.13-0.75. Settlements stay small (footprint median ~110 tiles) because growth stops when
  the ore within reach is claimed.
- Bugs found by the sheet: Park-Miller's first draws from nearby seeds are nearly linear (8 of 12 landings
  drew one doctrine, none another): seeds are scrambled and the first draws discarded. The landing site
  tested one point per direction and found no ore at 300 tiles on most maps: it now searches the band for
  the richest chunk, else the best seen. Walls bought before the first fabricator starved a settlement.
- Depletion is not handled yet: drills on an empty patch stay where they are.

## Engine notes
- `LuaSurface.create_entity` takes `auto_connect` for electric poles, but it does not reliably rejoin a cut
  line: wire pylons explicitly (`get_wire_connector(pole_copper).connect_to`).
- `LuaEntity.disabled_by_script` (2.0) replaces writing `active`; roboports ignore it (spike needed for
  jammers; fallback: kill construction robots inside the field).
- `LuaEntity.destructible = false` is the cheap shield.
- Biters only attack polluters: a scripted faction is ignored by them unless its buildings emit.
- Entities cannot be placed in ungenerated chunks: request chunks ahead of expansion.

## Spikes outstanding
- Air units against walls, mines, flamers (`attack_target_mask`, `trigger_target_mask`).
- 20 to 30 unit groups pathing through a dense base.
- Cost of 5,000 inert faction entities; the materialise/dematerialise boundary of a two-level simulation.
- Roboport `disabled_by_script`; spidertron automatic targeting without a driver.
