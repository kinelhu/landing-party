# A third corporation, outside the box (Fable), 2026-10-21

The user, 2026-10-21, thinking out loud: "Perhaps we need to think outside the box a little, playing with systems we
haven't touched yet? water? trees? a new resource? a parasite infecting camps from the other two factions? a recycling
themed swarm? (not necessarily air themed, but think paperclip optimizer trope) (just thinking out loud)".

Read-only consult. Read first: `docs/third-corporation.md` (the six criteria, five candidates), `docs/campaign.md`
(pillars, arc, section 4 profiles, section 7 interactions), `docs/corporations.md` (the identity kit), `docs/arena.md`
(the unit web), the status table of `DESIGN.md`, and the code where it mattered (`shared.lua`, `corps.lua`, `base.lua`,
`crew.lua`, `tests/lp-sim`, `tests/lp-arena/batch.lua`). Engine claims checked against the 2.0.77 `runtime-api.json`,
`prototype-api.json` and the data of `base`, `space-age` and `quality`. Everything here is framed identity first: what the
player sees, what they must do, the corporation's temper, weak point and want, and only then the mechanics.

## 1. What the mod has and has not touched

From the status table and the code, as of today.

| System | Touched | How |
|---|---|---|
| Ore and drills | yes | claims, strip mining, prospects, the claim jumper |
| Belts, pipes | yes | cut at Serenity's line, skimmed by Grubstake, carried in its districts |
| Power | yes | the camp's graph, the power tap, the blackout strike |
| Walls, gates, turrets | yes | the cordon, compounds, pillboxes, gate posts across rails |
| Biters | yes | the pact, the flare, clearances, the ledger, evolution refund |
| Pollution | deliberately not | `drill_pollution` is 0; corporations are clean; the player's cloud is the only one |
| Radars, jamming, charting | yes | intel, the jammer mast, territory on the map |
| Rails and trains | the player's only | interceptors, gate posts, the muster point; no corporation owns a rail |
| Robots | a little | Serenity's constructor drone (a harrier airframe), the jammer downs the player's robots |
| Research | yes | corporate trees, Serenity's labs in the world |
| Air | yes | harriers, scavengers, drones |
| Trees and rocks | cleared only | a block or drill destroys trees and rocks in its footprint |
| Water | avoided only | sites, routes and staging points refuse water |
| Cliffs | avoided only | cells that fail the terrain drop out of a hub |
| Tiles | as livery | floors, trims, Serenity's plating |
| Fluids | barely | flamethrowers are filled by script; pipes are cut |
| Space Age | some | pods, tesla arcs, plating, cargo pads, the threat scanner |
| Day and night | a little | Grubstake raids by night |
| Quality | pass-through | spilled stacks keep their quality |

Untouched: water as a thing (floods, landfill, shallow water), fluids as an economy, trees as living things (growth,
fire, the pollution sink), rocks as material, cliffs made and broken, a new resource, recycling and scrap, spoilage,
agriculture, trains of a corporation's own, lightning and weather, pollution as a resource, the player's logistics
network, items on the ground as something fought over (loot exists, nobody competes for it), corpses and remnants,
fish, day length, the player's own machines as something another force can hold.

Engine facts the concepts below rely on, verified in 2.0.77 (anything marked spike is to be settled with a throwaway mod):

- Trees absorb pollution natively: `emissions_per_second = {pollution = -0.001}` per live tree in base (dead ones a
  tenth), `healing_per_tick` on trees; `EntityPrototype.emissions_per_second` negative is documented as "used just
  for trees and fires". Pollution damages trees above `min_pollution_to_damage_trees = 60` a chunk and each damaged
  tree removes `pollution_restored_per_tree_damage = 10`.
- Tiles absorb: `TilePrototype.absorptions_per_second`; water tiles do in base. A mod tile can absorb at any rate.
- `PlantPrototype` (a tree that grows over `growth_ticks`) and `AgriculturalTowerPrototype` are engine types, usable in
  the base game; only Space Age defines plants and the tower. `create_entity{name = <plant>, tick_grown = ...}` works.
- Fire spreads tree to tree natively (`fire-flame`: `spread_delay` 300 ticks, deviation 180, `maximum_spread_count`
  100, `tree_dying_factor` 0.8). Units path through destroyable entities and chew them when blocked (the pathfinder's
  "collision penalty for successors of positions that require destroy to reach" is 3).
- `LuaSurface.set_tiles` lays water or landfill anywhere; `remove_colliding_entities` defaults to true (so a flood must
  pass false, or it deletes buildings). `create_entity{name = "cliff", cliff_orientation = ...}` makes cliffs;
  `DestroyCliffsTriggerEffectItem` and `SetTileTriggerEffectItem` exist as trigger effects for weapons.
- `create_entity{name = <resource>, amount = ...}` makes ore; `LuaEntity.amount` is writable; `deplete()` ends a tile.
- `LuaSurface.pollute(amount, source, prototype)` adds pollution; `get_pollution(position)` reads a chunk. The docs
  say "how much pollution to add" and nothing about negative amounts: spike. Absorption by tiles is the certain route.
- Lightning: `LightningPrototype`, `LightningAttractorPrototype` are engine types; `LuaSurface.execute_lightning(name,
  position)` strikes and "if other entities which can be lightning targets are nearby, the final position will be
  adjusted" (attractors work for scripted strikes). Space Age's `lightning` does 100 damage, carries 1000 MJ; its
  `lightning-rod` has efficiency 0.2 and `range_elongation` 15. The base game defines no lightning prototype or
  graphics: a base fallback is a scripted strike (an `electric-beam` from a sky offset, an explosion, script damage).
- Spoilage is engine level (`spoil_ticks`, `spoil_result`, `spoil_to_trigger_result`); only Space Age's items spoil.
- The recycler belongs to the Quality mod (`quality/prototypes/entity/entity.lua`), scrap to Space Age. Both optional.
- `LuaControl.force` is writable on any entity (a building changes hands in one assignment; the mod's capture by
  holding already relies on it), `LuaEntity.operable` and `is_military_target` too (the latter when the prototype
  allows). `LuaEntity.mine{inventory}` takes a building as items (Grubstake's dismantling uses it).
- Spawners carry `time_to_capture` in base (20 s and 30 s); Space Age adds `captured_spawner_entity` and the
  `capture-robot`. Left to the biotech consult.
- `LuaTrain.schedule` and `manual_mode` are writable; `on_train_changed_state` fires. Whether a train of one force
  paths over another force's rails and stops: spike.
- `display-panel` (base 2.0) shows text and an icon on the ground and on the chart: a world channel for a corporation's
  words that is not a chat notice.
- `LuaSurface.daytime`, `ticks_per_day`, `min_brightness`, `wind_speed` are writable (surface wide, so a corporation
  cannot darken one place).

## 2. Six concepts

Each: name and motto in the house style (a polite word for the ugly thing), identity in two sentences, what the player
sees, what they must do, what it does to Grubstake and Serenity, the system and its engine fit, the hardest problem.

### F. Goodwill Shared Services (the tenant): the parasite

Motto: "Your success is our success."

**Identity.** It owns nothing and manages everything: it moves into other corporations' camps as a service provider,
makes them richer for a while, and holds a lien on every block it touches until the camp is its own. It never fires
first; it inherits. Temper: courteous, patient, litigious. Weak point: it cannot build or fight on its own, so a dead
host is dead for it too, and its liaisons are unarmed and fly. Wants: rich hosts at peace.

**The player sees.** Mint-green service modules (a beacon's body with a slow ring light) standing beside the fabricators,
depots and labs of Serenity's and Grubstake's camps, each with a thin drawn cable to the block it serves; the ring goes
green, then amber, then red over twenty minutes, and the block changes colour. On the map a hosted camp is two-toned,
then Goodwill's. Unarmed liaisons (a logistic robot's silhouette, scaled up) fly in from a small white office that
landed beside the host. Hosted camps grow faster, so Serenity gets fatter while it is being hollowed. One day a pod lands
near the player's own base and a liaison plants a complimentary module beside the player's assemblers; it works (a real
speed bonus), and the ring starts to turn.

**The player must do.** Triage. Kill liaisons in the air (anti-air matters for a reason that is not
Grubstake). Burn modules inside hostile camps before the ring turns red, which means sneaking into Serenity's compound
to save Serenity from a worse owner, or deciding to let it happen and then face Serenity's lasers under new management.
Refuse the gift (a gun turret eats a module) or accept twenty minutes of free speed and pay later. Keep its hosts at war
with each other, because peace is what it feeds on.

**To Grubstake and Serenity.** The strongest of any candidate. While it holds modules in both camps it brokers a
truce between them (the standing system has truce already), so the two stop raiding each other and both grow; the
player's rival-against-rival leverage dies unless the player breaks the peace. A fully hosted camp becomes Goodwill's with
the host's units, research and walls: the campaign's "alliances against a third" happens by necessity, as the two
surviving halves turn on it. Its fall returns the hosted camps to their owners or to ruin.

**System and fit.** The player's buildings and the corporations' buildings as material, ownership as a resource.
`force` assignment per block (the capture path does it); `corps.lua` already makes a copy of every unit kind per
corporation, so Goodwill's managed army costs no new units; hosting plugs into the base economy (a module adds a share
to the host's parts rate, visible as more units). Headless testable: block ownership, parts rates and standing are all
in `storage`. Cheap in prototypes: one module, one liaison, one office pad.

**Hardest problem.** Readability of ownership during a takeover (who shoots whom, which block is whose), and the base
code's assumptions that a camp's entities are its own force (`b.turrets`, `b.fabs`): a hosted block must be handed over
in the base tables, not just on the entity.

### G. Optima Reclamation Services (the optimiser): the recycler

Motto: "Nothing goes to waste."

**Identity.** It converts the world into one product and the product into more of itself: trees, rocks, cliffs,
wrecks, corpses, ruins, items on the ground, then anything that does not move or shoot. Every fight near it feeds it.
Temper: tidy, silent, inexorable; it has no grudges and no notices. Weak point: it starves without matter to eat, it is
slow, and its crushers are the whole economy. Wants: mass, and the wars that make it.

**The player sees.** The opposite of Grubstake's rust: a widening zone of pale, bare, flattened ground (a grey tile
laid where it has eaten, decoratives gone, no stumps, no remnants) spreading from a white plant of crushers (a tinted
electric furnace a size up; the Quality mod's recycler where present). Collectors (a hauler hull with a claw) follow every
battle and the fall of every camp, and the loot the player expected is gone. Shredders (a dozer's hull, white) chew walls
and belts at the zone's edge. Nothing in its zone is dead for long. Its plant grows in exact rows.

**The player must do.** Fight it from range and never in its zone, because every wreck becomes its parts. Manage bodies:
robots pick the loot up first, clear the dead, keep fights away from it. Starve it: it needs forests, rocks and ruins,
so a cleared band round the base is a defence. Feed it a rival: lure it to Serenity's walls or Grubstake's yard. Artillery
and railguns outrange it; shotguns and buggies die to it and become it.

**To Grubstake and Serenity.** It eats what they drop. Serenity's clearances leave nest corpses, so it follows Serenity's
line and Serenity cannot clear without feeding it; Grubstake's yard of stolen goods is a buffet, so Grubstake must guard
what it never guarded. Their wars make it bigger, which gives both a reason to stop, or to fight far away. It eats ruins
and corpses, so a fallen camp vanishes rather than remaining as the map's memory.

**System and fit.** Corpses, remnants, trees, rocks, cliffs, items on the ground, tiles: all native and cheap to find
(`find_entities_filtered` by type, `destroy`, `set_tiles`, `spill_item_stack` for what it drops). Growth is parts from
mass eaten, a number in `storage`. Space Age's scrap and the recycler give it a look where present; base needs none of
them. Headless testable: the zone's area, the parts eaten, what it ate.

**Hardest problem.** Scrap is Grubstake's look (scrap arms, scrap plating, salvage rights, the scrapyard). Optima must
be the tidy opposite in every pixel, or it reads as a white Grubstake. And growth by eating balances on a knife: too
fast is a doom clock, too slow a joke.

### H. Fairweather Land Improvement (the engineer): water and terrain

Motto: "Shaping better ground."

**Identity.** A civil-engineering corporation that reshapes the map to its advantage: dams and canals, flooded ore,
cliff walls where it wants no road, causeways where it wants one. It fights with the ground, and its armies are
plant. Temper: methodical, proud of its works, slow to anger. Weak point: works take time and show their intent a step
ahead, and its own camps sit on dykes and islands that one breach undoes. Wants: lowland, lakes, chokepoints.

**The player sees.** Survey stakes in a line, then dredgers (a tank hull with a blade) cutting a canal across the
player's expansion route, tile by tile; water creeping over an outpost's ore field (the drills stop; the ore is still
under the water); cliff walls (`create_entity cliff`) rising round a field it wants; a causeway of landfill carrying
Grubstake's trucks and Serenity's line across a lake that used to protect the player. A dam with a sluice (a pump on
hazard concrete) at the head of each flood; its camps on raised ground with water on three sides.

**The player must do.** Think about terrain as the engine does: landfill to take the ore back (reversible, a chore the
player can see), cliff explosives to open its walls, walls of their own as dykes (a flood never covers an entity, so a
wall line holds water), and a strike on the dam before the flood reaches the base's edge. A causeway is a road for
everyone, biters included.

**To Grubstake and Serenity.** It sells ground: a causeway for Grubstake's convoys, a cliff line for Serenity's cordon,
a moat for whoever pays. It can drown Grubstake's outposts and wall Serenity's line, so both court it and both fear it.

**System and fit.** `set_tiles` (water, landfill, with `remove_colliding_entities = false`), cliffs by script, the
builder crews already in the mod for the stakes and the dredgers. Headless testable: tile counts, drills stopped, paths
that no longer exist. Risk: every corporation's routing (`ops.route`, staging points, the cordon's arcs) treats water and
cliffs as fixed; terrain that changes under them needs their caches invalidated.

**Hardest problem.** Fairness of a flood. It must creep, show its front, stop at entities and never enter the base's
perimeter; and all three AIs must survive a map whose walkability changes.

### I. Greenbelt Stewardship Trust (the forester): trees as living walls

Motto: "Growing together."

**Identity.** It plants: rings of fast-growing forest round its claims and across the player's expansion, a wall that
heals, regrows, blocks trucks, absorbs the player's pollution and sells the quiet that follows. Temper: serene,
patronising, flammable. Weak point: fire, which it fears and which spreads toward the player too. Wants: open ground to
plant, the player's smoke to feed on.

**The player sees.** Rows of saplings laid by planter drones, growing into forest in ten minutes (a plant prototype with
`growth_ticks`); forests where the player meant to put rails; the biter attacks easing as the forest eats the cloud (and
the map's pollution overlay shrinking); a sawmill camp of wood and burners inside a grove. When it is hurt, it stops
absorbing and the waves come back. A flamethrower answer turns into a fire line walking toward whoever is downwind.

**The player must do.** Burn or cut, knowing fire spreads tree to tree and that Greenbelt's forest touches the player's
own; clear bands before planting reaches them; use artillery (trees are cheap to kill, but many); keep robots with
deconstruction planners for forests (they chew through quickly). Decide whether its quiet is worth the ground.

**To Grubstake and Serenity.** A forest is a Grubstake-proof wall (cars take tree impacts; trucks and buggies cannot
pass); Serenity's walkers step over trees (spike) and its drones fly, so the forest hurts Grubstake far more than
Serenity, which changes the balance between the two. Serenity's flamethrowers at its gates set the forest alight: a
Serenity siege near a Greenbelt grove burns the grove. Its wood is fuel: a burner corporation smokes, and Serenity bills
smoke.

**System and fit.** Trees, plants, fire, pollution absorption: all native, all cheap, all in the base game (a mod plant
with base tree sprites). Headless testable: tree counts in a ring, chunk pollution under a grove versus a control, a fire
started at the edge and what it reached.

**Hardest problem.** Fire fairness (a fire that reaches the player's base from a fight they did not start), and the
pathfinder cost of thousands of trees in the way of three armies.

### J. Clearsky Atmospheric Services (the weatherman): the sky and the smoke

Motto: "Breathe easy."

**Identity.** It owns the air: it harvests the player's pollution with scrubber pavements and masts at the edge of the
cloud, stores it in tanks, sells the quiet that follows, and seeds storms with what it stored: lightning over whoever it
chooses, armies in the open first. Temper: meteorological, never angry, always billing. Weak point: its tanks are its
magazine and its fuel is the player's smoke; a clean player starves it and a breached tank vents onto its own camp.
Wants: the cloud's edge, downwind of everyone.

**The player sees.** A pale blue-grey yard of scrubber pavement with tall masts (Space Age's lightning rod; base: a
tinted radar mast) and storage tanks that fill with something dark; the cloud on the map pulling back from its yard; the
attacks easing. Then a storm: a dark crackling patch forty tiles across, ground marks three seconds before each strike,
twenty strikes in a minute, fliers first, then armour, then anything tall; scorch marks after. A storm wagon (a hauler
with a mast) driving to the player's perimeter and calling the storm down round itself, safe under its own rod.

**The player must do.** Build rods (an attractor within fifteen tiles takes the strike; in Space Age it yields 200 MJ a
strike, which makes a rodded base richer for being bombarded); march armies with a rod bearer or under cover of rods;
kill the wagon before it anchors; and think about pollution as a currency: pollute less and it starves, pollute toward
Serenity's camp and the storms go there.

**To Grubstake and Serenity.** Storms in the open are a convoy's end, so Grubstake hates it and raids its tanks (a tank
vents, biters come, and Grubstake's pact keeps Grubstake safe among them). Serenity's ledger has nothing to bill once
the cloud is captured: its grievance with the player disappears, and its line turns toward Clearsky's yards (pollution
rights). It sells storms: a storm over the player's outpost before a Grubstake heist, a storm on a fortress before a
Serenity siege. The web gains the anti-air and the long-range fire on units it lacks.

**System and fit.** Pollution as a resource (tiles absorb; chunk pollution is readable), lightning (engine types;
Space Age data; base fallback scripted), weather as a look. Headless testable: chunk pollution deltas, tank levels,
strike counts and targets, damage dealt, energy delivered to rods.

**Hardest problem.** Fairness of a strike (warning, no strike on the character without a mark, nothing random), and
the base-game look of a storm without Space Age's lightning.

### K. Meridian Transit Authority (the railroad): a line through everything

Motto: "Right of way, guaranteed."

**Identity.** It lays a railway across the map, through the player's base if that is the straight line, connects every
camp to it, runs armoured trains, and charges tolls. Temper: imperial, punctual, indifferent to whose land it crosses.
Weak point: a railway is a line, and a line is cut anywhere; its trains are predictable. Wants: right of way.

**The player sees.** Survey stakes, then a rail line arriving across their territory (gate posts across the player's
rails exist; this is the reverse), elevated where Elevated Rails is present; stations in Grubstake's and Serenity's
camps; armoured trains (a locomotive and artillery wagon in its colours) running a schedule the player can learn.

**The player must do.** Learn the timetable, cut the line (and face the repair crew and the next train), toll it back by
holding a station, use its line as the player's own transport when at good standing.

**To Grubstake and Serenity.** Grubstake's convoys and Serenity's reliefs ride its rails: cut the line and both suffer;
hold a station and both pay the player. It makes the other two depend on a third, which is the campaign's "steer rival
fights" with a railway timetable.

**System and fit.** Trains, rails, stations: all native; trains of another force on the player's rails, and station
lookup across forces, are spikes. The cost is the builder: a rail planner by script across arbitrary terrain is the
hardest construction problem the mod has faced, and the mod's crews build straight things.

**Hardest problem.** Building a railway that reaches anywhere, and keeping it from being a railway to nowhere once cut.

## 3. Side by side

The five candidates on the paper, then the six above, on the paper's six criteria.

| | What the player sees | Must do differently | Adds to the web | Overlap with the two | Changes the two | Engine fit and cost |
|---|---|---|---|---|---|---|
| A Lumen (the eye) | pickets, violet lamps | blind it | nothing | high (fliers, jamming) | low | medium; hidden info is weak |
| B Concord (the dealer) | garages, armour in rows | fight armour; buy | a market | medium (armour) | high (sells to them) | units low, trade high |
| C Swarm | roboports, drones | cut network, anti-air | repair, more air | high (fliers, jammer) | low | poor (bots not armies) |
| D Biotech | fenced spawner farms | fight regeneration, pay | regen, swarm, acid | low | high (sells the waves) | good |
| E Orbital | drops, a platform | bring it down | fire from far | medium | low | poor (SA, late) |
| F Goodwill (parasite) | modules in rivals' camps, two-toned camps, a gift | triage inside hostile camps; refuse gifts; break the peace | subversion, hidden until it turns | low (no units of its own) | very high (truces, takeovers) | good; ownership per block |
| G Optima (recycler) | bare pale zone, crushers, collectors | fight from range, manage bodies, starve it | field economy damage, an eater class | medium (scrap is Grubstake's) | medium-high (feeds on their wars, eats clearances) | good; balance delicate |
| H Fairweather (terrain) | canals, floods, cliff walls, causeways | landfill, dykes, explosives | none | low | high (sells ground, drowns outposts) | medium; routing caches |
| I Greenbelt (forest) | rings of growing forest, fire | burn or cut with care | a wall that heals; fire | low (Grubstake clears nothing green) | medium (walls Grubstake, feeds Serenity's bills) | good; pathfinder load |
| J Clearsky (sky) | scrubber yards, tanks, storms, rods | rods, rod bearers, pollution as currency | anti-air, fire on units with warning, a support unit | medium (Serenity's ledger, the orbital strike) | high (storms on convoys, the ledger starves) | SA good; base fallback medium |
| K Meridian (rail) | a railway through everything, trains | cut, hold a station, ride it | none | low | high (both ride its rails) | poor (a rail planner by script) |

Read down the "changes the two" column: F, then B, J, H, D. Down "what the player must do differently": J, F, H,
G, I. Down cost: F, G, I, D are cheap; H and J medium; K and C poor.

## 4. The two best, developed

F (Goodwill) wins on the criterion the paper weighs most, what it does to the other two, and is the cheapest to field.
J (Clearsky) adds what the web lacks (anti-air, fire on units with warning, a support role) and gives the player's
pollution a second meaning. G (Optima) is third: its play is strong, but it must be built as Grubstake's opposite or it is
a repaint, and its balance is a knife.

### 4a. Goodwill Shared Services

**Identity kit.**
1. Palette: white and mint green, gold accent. Lamps green. Managed units keep their host's silhouette in Goodwill's
   green, so a Serenity tank under management reads as both.
2. Logo and motto: `signal-check` on white; "Your success is our success."
3. Floor: none of its own inside hosts (it sits on their floor; that is the point). Its office: white refined concrete,
   a thin green trim.
4. Walls: none. Ever.
5. Turrets: none of its own. Managed turrets are the host's, recoloured.
6. Units: one of its own, the liaison; everything else is the host's kind under its colour (`corps.lua` already makes
   `lp-goodwill-<kind>` for every kind).
7. Layout: an office (lander, two pads, a lamp) within 80 tiles of a host's camp; inside hosts, modules at fabricators
   first (the economy), depots next (the army), labs (the research), the lander last (the camp).
8. Voice: on display panels at its office and on each module ("Service level: standard", then "Account in arrears",
   then "Under management"), never in chat.

**Signature mechanics, first numbers.**
- Liaison: a flying builder like Serenity's drone (a logistic robot's sprite at 1.6 scale), 150 health, 10 tiles/s,
  unarmed, fire 100% like all fliers, 40 parts. It carries one module. Only anti-air touches it.
- Service module: a beacon's body in green, 3x3, 250 health, 60 parts, planted within 3 tiles of a host block. It
  adds 25% to the host camp's parts rate per module, up to four (so a fully served camp fields twice the units). Its ring
  light turns green for 10 minutes, amber for 7, red for 3; at 20 minutes the block's force becomes Goodwill's
  (`force` assignment on every entity of the block and a transfer in the base tables), and the module stays as the sign.
  A module killed before red returns nothing; the host loses the bonus and nothing else.
- A camp with its lander converted is Goodwill's: its depots field `lp-goodwill-*` of the host's mix, its labs keep
  climbing the host's branches for Goodwill, and its territory on the map changes colour. Its own research is the
  union of its hosts'.
- The truce: while it holds a module in both Grubstake's and Serenity's camps, their standing becomes truce (both see
  it as the mod shows standing today); the truce ends 10 minutes after the last module in either camp dies.
- The gift: at the player's era 2 and neutral standing, a pod lands 60 to 100 tiles from the player's base edge; a
  liaison plants a complimentary module beside the densest cluster of player assemblers it can see. The module is a
  real beacon (speed +25% within 6 tiles; whether beacons affect another force's machines is a spike; if not, the bonus
  is scripted). Its ring runs the same 20 minutes. At red, every machine that ran in its range becomes Goodwill's
  (`force`, `operable = false`, a drawn lien cable from the module to each); killing the module returns them at once,
  and the player's standing with Goodwill drops. At hostile standing it stops gifting and sends collections: managed
  units of its hosts' kinds against the liened cluster, a raid with a reason the player can read on the cable.
- Its fall (the office's lander, or its last converted lander): converted blocks return to the host if the host still
  stands, else to ruins. Its prize: the service module as a player building (a beacon with a parts bonus to barracks).

**Where it sits in the web.** It adds no class. It adds the first hidden piece: a module is harmless for 10 minutes
and a camp is a friend until it is not. Its own body, the liaison, is pure air and pure target; the anti-air that the
arena says beats fliers (troopers, slugs, walkers) becomes worth more, and Serenity's rifles have a second job.

**Prototype and test headless.** In `tests/lp-sim`: `goodwill` (a Serenity camp at 300; Goodwill lands within 80 of
it; a module stands at a fabricator block within 10 minutes; the camp's `rate_parts` rises by a quarter; at 20 minutes
the block's entities are `lp-goodwill` and the base tables agree). `goodwill|LP_MIX=cured` (a player turret kills the
module at minute 15: no conversion, the bonus gone, a second liaison after the cool-down). `goodwill|LP_MIX=gift` (a
player assembler cluster; the pod; the module; at 20 minutes the assemblers are Goodwill's and not operable; the
module destroyed returns them, standing falls). `goodwill|LP_MIX=truce` (both camps hosted: standing between them is
truce within 5 minutes of the second module; all modules in one camp killed, the truce ends within 10).
`goodwill|LP_MIX=takeover` (60 minutes unhindered: the lander converts, depots field green units, the map colour
changes, the labs still climb). Spikes first: a turret whose force changed keeps its targeting and the host's turrets
shoot it; the base's rebuild and economy tolerate a foreign block (the capture path is the model); beacon effect
across forces; inserters of the player's force feeding a machine of another force (if they refuse, the liened machine
starves visibly, which also works).

### 4b. Clearsky Atmospheric Services

**Identity kit.**
1. Palette: pale blue-grey and white, a storm-violet accent. Lamps white-blue. Its storms are the only violet in the
   world (Lumen's violet is free since Lumen was shelved).
2. Logo and motto: `signal-cloud`-like (the base has no cloud signal; use `signal-info` on grey, or a mod signal of a
   tinted cloud icon); "Breathe easy."
3. Floor: scrubber pavement, a copy of refined concrete in its grey-blue with `absorptions_per_second` set so a
   20x20 yard absorbs about what two steel furnaces emit (4 a minute each; tune in the spike). Yards sit at the cloud's
   edge, never inside the base's perimeter.
4. Walls: none; a ring of masts instead. Its camp is immune to its own weather and shows it.
5. Turrets: few lasers at tanks only. Its defence is the storm.
6. Units: a thin ground force (infantry of the shared kind in its colour) and its signature storm wagon. No armour, no
   fliers of its own.
7. Layout: a weather station: a central mast cluster, tanks in a row, scrubber yards spreading toward the cloud as
   hubs of their own, a storm wagon on a pad.
8. Voice: a display panel at each yard with the day's figures ("Captured today: 12,400", "Storm risk: elevated").

**Signature mechanics, first numbers.**
- Mast: a lightning attractor (Space Age: a copy of `lightning-rod`, range 15, efficiency 0.2; base: a tinted radar mast,
  the attraction done by the storm script), 400 health, 30 parts. Every yard has one every 25 tiles.
- Capture: chunk pollution under its yards falls through the tiles (certain) and is credited to its tanks each minute
  from the chunk delta (a storage tank of a dark fluid, `captured effluent`, so the level shows). 25,000 units is one
  storm's charge. A tank destroyed vents its contents as pollution at its position (`pollute`), which draws biters to
  Clearsky, not to the player.
- The lull: pollution captured never reaches a nest, so the player's attack waves fall while Clearsky's yards stand.
  Serenity's ledger bills nothing it cannot see.
- Storm: one charge, 40 tiles across, 20 strikes over 60 seconds. Each strike: a ground mark and a crackle 3 seconds
  ahead, then 100 electric damage over 2 tiles (Space Age: `execute_lightning` with a copy of `lightning`; base: an
  `electric-beam` from 20 tiles above, a small explosion, `damage` by script). Targets: fliers first, then the tallest
  (walkers, tanks, masts, turrets, poles), then units, then buildings; an attractor within 15 tiles takes the strike
  instead and, in Space Age, 200 MJ with it. No strike lands on a character without its mark having stood 3 seconds.
- Storm wagon: a hauler hull with a mast, 1,500 health, 3.9 tiles/s, unarmed, 120 parts. It leaves with a full tank's
  charge, drives to within 30 tiles of its target and anchors the storm round itself. Killed on the way, the charge
  vents where it dies. It is the siege Serenity cannot buy from its own labs.
- Sales: at good standing the player buys a storm over a named place (items at its post, like the trade post) or rods.
  Grubstake buys storms over the player's outposts before heists; Serenity buys them before sieges; both pay in parts.
- Its fall: the prize is the mast as a player technology (rods in the base game; in Space Age the vanilla rod on
  Nauvis), and the storm wagon's hull for the barracks at good standing before the fall.

**Where it sits in the web.** The arena's air row scores +47 against small arms, +67 against armour and +100
against splash because only some weapons shoot up; a storm is the first thing that hits fliers before anything else,
and it hits armour and walkers because they are tall. It is fire from far with warning, which the web lacks (the paper
gave that role to Orbital). The rod bearer (a mast on a walker or a hauler, 80 parts) is the first support unit: it
protects a squad and does nothing else, so a squad spends part of its budget on not dying.

**Prototype and test headless.** `clearsky` (lands 300 out; a yard within the player's cloud edge; at 20 minutes the
chunks under the yard hold 30% less than a control run's; the tank level rises). `clearsky|LP_MIX=storm` (a charge
spent on a player outpost: 20 marks drawn, each 3 seconds before its strike; damage dealt; a rodded building within 15
of a mast takes none). `clearsky|LP_MIX=rods` (the outpost rodded by the player: no damage, 200 MJ a strike into the
rod's buffer in Space Age). `clearsky|LP_MIX=vent` (a tank killed: the chunk's pollution jumps by the charge; with the
`biters` harness, an attack group targets Clearsky within 10 minutes). `clearsky|LP_MIX=wagon` (the wagon killed en
route: no storm, a vent where it died). `clearsky|LP_MIX=base` (no Space Age, no Quality: the scripted strike, the same
checks; it joins `tips_check`'s base-only run). In the arena: one charge against each kind at 420 parts, expecting air
wiped, walkers and armour hurt, infantry scattered; a mixed squad with a rod bearer against the same storm. Spikes
first: `execute_lightning` with Space Age's prototype on Nauvis and attraction by a rod copy; whether `pollute` takes
a negative amount (if not, tiles only, which is enough); the absorption number per tile; fliers as lightning targets
(the script picks targets anyway, so this only decides whether the engine's own strike can be used).

## 5. What I would not do, and why

- **A new ore (a deep-drilling corporation that drains patches from a distance and salts new ones).** It is Grubstake's
  want (ore volume) with the theft made invisible, and the player's answer is the same turret margin. A new resource
  that only the corporation can mine gives the player nothing to do until its fall.
- **The recycler eating living buildings of the player.** That is Grubstake's dismantling. Optima eats what is dead,
  natural or abandoned, and only at its zone's edge does it chew what stands still.
- **A flood that reaches the base.** Water stops at entities, creeps visibly, and never enters the perimeter. A flood
  that deletes a base is a chat notice with extra steps.
- **A forest fire the player did not light.** Greenbelt never starts fires; fire is the player's and Serenity's weapon,
  and the forest is what makes it a decision.
- **A lien without a gift used.** Goodwill takes only what ran under its module, and the ring turned for twenty
  minutes in plain sight. A takeover without a visible countdown would be unfair, and the mod's rule is that the world
  tells.
- **Storms without marks, or a storm as a random weather event.** Every strike has a mark 3 seconds ahead and a
  reason (a charge spent by a corporation on a target); weather for its own sake is noise.
- **The railway now.** Meridian is the one I would most like to see and the one I would build last: a rail planner by
  script across arbitrary terrain is a larger builder than the whole cordon, and the campaign's remaining slices
  (claims, phases, the agent) are worth more.
- **Spoilage or agriculture as a corporation's core.** The engine has them in base, the look does not (Gleba's sprites
  are Space Age's), and the biotech consult covers eggs. Spoilage is a fine weak point (biotech's) and a poor identity.
- **Giving the third an army that matches both.** Goodwill has one unarmed flier; Clearsky has a wagon and the sky.
  Each loses to something simple (anti-air; rods and a clean factory) and that is what makes the counters strong.
- **Deciding today.** The paper is right that the next step is a consult per shortlisted candidate and its signature
  pieces in the arena. For F the arena has nothing to fight (its army is the hosts'), so its test is the `goodwill`
  scenarios above; for J the arena fight is a one-afternoon spike and tells most of the story.

## 6. Recommendation

Shortlist F (Goodwill) and J (Clearsky) beside D (biotech) and B (Concord) from the paper. They are not exclusive and
they are not alike: Goodwill changes who fights whom; Clearsky changes where and under what. If one must come first, F,
because it costs almost no new prototypes, it makes the two existing corporations deal with each other (a campaign pillar
that nothing built so far delivers), and its scenarios can be written against the base tables that exist. G (Optima)
stays on the list as the tidy opposite of Grubstake if its look can be made unmistakable; H and I are strong mechanics
looking for an owner, and either could be a fourth corporation's signature rather than a whole corporation.
