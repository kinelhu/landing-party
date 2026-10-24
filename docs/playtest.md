# Playtest kit (2026-10-19)

> Renamed 2026-10-21: Serenity Perimeter Group is shown as **Kessler-Hayashi**, Grubstake Mineral Recovery as **Grubstake Inc.** (internal ids unchanged).

Nothing since the 16th has been played. Since then: Serenity is at war from landing (no grace), Grubstake steals by
night (skimming trucks, raids that dismantle machines, a yard of stolen goods), raids have leaders, Serenity has a
fortress kit (sieges sized to win, the howitzer, a robot jammer, the power strike, strangling, belts cut on its line),
clears the nests that hit it and bills you for the waves your pollution draws. Space Age: landings by cargo pod,
armour, tesla arcs. The player's side: threat scanner, muster point. All checked headless (about 180 scenarios, visits
of real saves); none of it played. Chat notices are off by default: the world should tell you what happens.

## Start
**Every faction at once (0.2.1, Factorio 2.1):** `LP_MIX=all scripts/showcase.sh 12345 30` builds it (a few minutes,
headless), then `scripts/play-showcase.sh all` opens it, both from `~/Dev/landing-party-wt` until 0.2.1 is merged. At
minute 30: your walled base at spawn (12 gun and 12 laser turrets, power, assemblers, a radar, a roboport), your
barracks' 35 units, an outpost toward each corporation and an artillery turret with its shells in a chest beside it;
Kessler-Hayashi and Grubstake at level 2 with their tree units (laser drones, Anti-air troopers; bomb drones, flak
buggies); Synthexis 750 tiles east (five incubators, creep, cells, substrate, technicians, its clinic, breeds at 0.57).
Raids are on.

Close your own game first (Steam allows one copy). Then, in a terminal:

    cd ~/Dev/landing-party && scripts/play-visit.sh deathworld10x

It opens a fresh copy of the deathworld save the visits used (never the real file), with Landing Party, Editor
Extensions and flib. No test mod: the mod runs as a player would meet it.

- Grubstake comes first. This save has oil processing but has never made a chemical science pack, so only its survey
  party lands at first (a radar, two drills, a lamp, four guards, about 450 tiles out). The lander follows the first
  chemical science pack, or 30 minutes after the survey party leaves. Not to wait: `/lp land grubstake 300` lands it
  now; `/lp fast` shortens the survey and the wait after it to 3 minutes.
- Serenity's gate is the first rocket launch (Space Age): on this save, call it with `/lp land serenity 300`. It is at
  war with you from the moment it lands.
- `/lp list` shows the settlements; `/lp fast` speeds their clocks; `/lp incidents` lists the last twenty things they did
  and where; `/lp trace` writes their decisions to `script-output/landing-party/decisions.txt` in the visit profile.
- `/editor` (Editor Extensions) to watch untouchable. Grubstake's thefts come by night: to see one now, wait for dusk.
- Grubstake's heists on demand, from the nearest camp: `/lp rig` (a claim
  jumper at the chests nearest you), `/lp tap` (a power tap on the pole nearest you, one no turret covers).

## Grubstake, the thief (from chemical science)
1. **Its camp and pacifier antenna**: a radar dish a size larger than a radar by the lander. Biters walk past the camp.
   Destroy every antenna and the biters turn on it; one is rebuilt five minutes later if the lander stands.
2. **By night**: its raids, skims and claim jumps set out only after dark; at dawn a skimming truck leaves. Its trucks
   show headlights. Does the rhythm read? Does night feel like the dangerous time?
3. **A raid that steals**: buggies and Shotgun hands at an exposed spot; they walk in without firing and take your
   machines apart one by one (assemblers, furnaces, drills, solar, poles...), carrying them off with what they held, and
   leave the machines' ghosts where they stood. Up to twelve a raid. Chests near the target are emptied too.
4. **The leader**: one raider wears Grubstake's icon (the mining pick). Kill it and the raid breaks and runs home empty:
   the foreman carries the haul and drops all of it where it falls. Kill any other raider carrying loot and its share
   drops.
5. **The skim**: a truck parks by one of your belts that no turret covers and takes half of what passes, the most
   valuable first, until its trunk holds 120 or five minutes pass, then drives home. Gaps downstream are the tell. Kill
   the truck and its load spills. Undergrounds across an exposed stretch, or a turret by it, stop it.
6. **The yard**: by its camp, a chest in its colour with the icon of what it holds most. What its trucks and raids
   brought home is in there. Destroy it and it spills.
7. **No pheromone flare any more** (retired 2026-10-22: biter waves are Synthexis's). Kill one of Grubstake's units
   from a turret: it does not answer on covered ground; from an open spot, a squad comes.
8. **A claim jumper**: a rig digs in outside your wall, a mound grows by your chests, Shotgun hands come up, empty them
   and go back down. Kill the rig within the minute and nothing comes up.
9. **A power tap**: a line of its pylons creeps to a pole no turret covers and clamps it. Look for "Power tap" in your
   power statistics. Cut the line or break the clamp.
10. **Prospecting and the road**: it tags the undrilled patch nearest your base and claims it ten minutes later (drill it
   or set a border stake to stop it); a truck carries the ore home; kill it and the claim lapses.
11. **Pay the thief**: a trade post (a steel chest and 5 circuits) by its camp; what it empties buys a truce, a minute for
   each 10 of value; a lamp on the post while it holds.

## Serenity, the wall (from the first rocket)
12. **Arrival**: the orbital barrage on the nests within 120 tiles, a camp on space-platform plating, railgunners in
   charcoal (the same colour when they fire). Railgunners clear nests and guard home; they never come at your
   buildings (their reach is 30, a gun turret's 18).
13. **At war from landing**: raids come at your exposed buildings from the start. A raid's leader wears its heart icon;
   kill it and the raid falls back to its staging point in order, a new leader takes the icon, and it comes again.
14. **The line**: 30 minutes after landing, drones build cordon posts on an arc toward you, each on plating with a
   cold-white lamp, a dark stripe painted post to post (at night a lit line across the map). Grown, its camp spreads:
   compounds laid out by wave function collapse: a chamfered wall, rooms behind doors, turrets, generators and
   fabricators inside, lanes out through gaps in the wall, founded out toward its line every few minutes and tied home
   by plated roads, like metastases on the map. Its spread done, a curtain wall goes up round the whole camp with a
   killing ground before the compounds' walls. Its claim follows, its next
   arc drawn on the map, a named warning a step before it encloses a building of yours. Near you it closes with wall;
   across your rails a gate post (your trains stop). Shoot the drones: three lost on a post and the line is held there.
15. **Strangling**: the line goes for your outpost easiest to cut off; with none of your buildings in reach, for the ore
   field you will want next. On its edge, where its guns stand (a turret of its within 30 tiles), it blows your belts,
   pipes and loaders every 30 seconds (an explosion each): undergrounds with both ends off the line pass, and a sector
   whose posts you destroyed is open.
16. **Against a fortress**: a hauler brings mortars (a howitzer when robots keep the wall), a fire plan on one point at a
   time, roboports first; a jammer mast in the emplacement whose tesla arcs down your robots and blinds your threat
   scanners within 50 tiles. Destroy the mast. Kill the howitzer and its camp has none for 30 minutes: the next siege
   comes with mortars only. Since 0.1.61 the howitzer is a truck (a tank's hull, the artillery cannon on it): it
   drives out, deploys for 30 s ("Deploying N%") into the emplacement where it stopped, and packs up for 15 s, silent,
   before it moves or drives home. The deploy and the pack-up are your window. At home it stands parked by the lander
   (gone while out); killed, a faded mark holds its spot until it is back.
17. **The power strike**: two scouts walk out to a pole of yours, and minutes later a raid goes for it: the one pole
   whose loss darkens the lasers behind it. A second feed, or accumulators by the turrets, is the answer.
18. **Hazard removal**: when biters keep hitting it, it sends a clearance siege at their nest, away from you.
19. **The invoice post**: a chest of yours at its line, the sum written over it: what the biter waves your pollution
   drew cost it. Put circuits, modules or steel in it. Paid off, it buys a truce (a minute per 10 paid, 10 to 60): no
   raids, sieges or cuts, its line holds, an amber light by night. Is the price fair? Is it worth paying? Or dispute
   it: kill the nest a bill names (Serenity's icon over it, in game and on the map) and that bill is struck.
20. **A border stake during a truce**: the border holds after the truce ends, until you build on its side.
21. **Bend the line**: a decoy building nearer its camp than the rest swings its next arcs toward it.
21b. **Its labs**: once its launch pad is open, a district goes up with a lab at its heart, an icon over it for its
   branch (a laser turret: the Optics lab; heavy armour: the Line armoury; an artillery shell: the Siege works). Its
   research climbs only in branches whose lab stands, and what a branch gave (heavy laser troopers, armoured troopers, the jammer)
   is fielded only while it stands. Kill one: does its army change? Is the lab worth the assault (artillery takes one
   in a shell; a squad of 35 storming the district died at its flamers)? Labs are a size up and always at work now.
21c. **Your remarks of 2026-10-21, seen again** (0.1.42, 0.1.43): a tank's cannon round against a wall line (does it
   tear through buildings, and not through your troopers?); depots as half-size cargo landing pads; the launch pad
   paved, ringed in hazard stripes, lamps at its corners; trees gone in its blocks and round its drills; drones and
   trucks flying or driving to each spot before building (a beam from beside it, not from a screen away);
   fabricators running now and then; districts floored in refined concrete and hazard rings; belts in its districts
   carrying parts from fabricators to depots, and Grubstake's sushi belt by its yard carrying what it stole; one
   "Mineral rights" label where two patches lie close; a flying harrier in its own selection box; Grubstake no longer
   throwing raids at Serenity's fortress for nothing, and Serenity paying back a rival that hurts it.
21d. **The new units** (0.1.45; save `lp-units`, built by `LP_MIX=units scripts/showcase.sh 12345 20`, opened by
   `scripts/play-showcase.sh units`): both camps grown at era 3, Serenity with laser tanks and lightning tanks and Grubstake with
   Scorchers in their garrisons (7, 7 and 8 at the save), raids on, your outposts by each and an army of yours (20
   troopers, 10 breachers, 5 battle tanks) at spawn. Does each read apart from a tank at a glance (the laser tank's laser head,
   the lightning tank's coil, the Scorcher's flamer)? The laser tank's beam forking into a pack; the lightning tank's arcs jumping, and your
   lasers going dim after its hits; the Scorcher's flame bursts at your walls and turrets. Tanks turning their own
   turrets; a body where each unit dies.
21e. **Who shoots up, and armour** (0.1.48; the arena, `scripts/play-arena.sh`, panel: set two squads and Fight). Tanks,
   heavy tanks, dozers, Scorchers, sappers, shock troopers, laser tanks, lightning tanks, railgunners, your battle tanks and breachers cannot
   hurt a flier; rifles, heavy laser troopers, machine guns, slugs and walkers can. Put harriers against tanks, then against riflemen.
   A ground-only unit that fires at a flier turns to a ground target (or holds fire): do tanks under harriers go for
   the enemy's tanks, and does that read as "it cannot shoot up", not as a bug? Riflemen against tanks barely
   scratch them now; lances and slug buggies are the answer. Does each fight's winner make sense from what you see?

## Synthexis (0.1.54 to 0.1.56: the third corporation, a bioengineering firm)
It lands once the biters' evolution reaches 0.25, on a nest field 600 to 1,000 tiles from your factory, and breeds
biters in green and yellow. Not to wait: `/lp biotech` lands it now (a map tag, "Synthexis culture"), `/lp wave` sends a wave.
28. **The tell**: before a wave, one green biter with an egg icon walks round your base out of turret reach, stops at
    each side, then sits at one. Did you notice it before the herd came, and could you tell where it would hit?
29. **The trail**: mud on the ground and a dashed green line on the map from its farm to the side it chose. Does it read
    as "they came from there", and does it lead you back to the farm?
30. **The strike**: the herd breaks two wall pieces where the scout sat and goes for what feeds your guns (power,
    the inserters loading gun turrets), then leaves the way it came. Fair? What would you build against it?
31. **The hunt**: go to the farm (pens drawn as captive spawners, worms by them). Hitting a pen calls its wave home.
    Kill every pen and it leaves, landing elsewhere an hour later. Is the expedition a fight worth making?
32. **The creep** (0.1.56): violet ground round its incubators, green glowing tumors on it. You cannot build on creep.
    Watch it bud toward the wild nests near (every two minutes or so) and take them. Fight its biters on creep and off:
    on it they are quicker and mend. Kill the tumors: the creep withdraws, and incubators left off it go wild after
    three minutes, their biters with them. Does the creep read from afar, and on the map?
33. **Biomass** (0.1.57): its incubators breed only on biomass, from what its creep drinks of the pollution. A dirty
    factory whose cloud reaches its culture feeds it (bigger, sooner waves); clean air leaves it the trickle. Watch an
    incubator stop (no animation) when it has nothing.
34. **The probe and the spitters** (0.1.59, at evolution 0.45 and up): before a wave, eight small green "runts" walk at
    one face and die there. Leave a turret on that face without ammunition: the herd comes in in front of it. Once it
    is inside, its spitters (long green bodies) stay at the gap and spit at whatever comes; they leave last.
35. **The burster** (0.1.59, recoloured 0.1.61; evolution 0.6 and up): a big biter with violet and acid-green bands,
    lit green at night. Where it dies the ground splits and bursts green: let it reach your wall and the wall and the
    turret behind it go. Kill it at range. Does the green burst read as Synthexis's?
36. **Anti-air** (0.1.63, ground fire 0.1.64): lose units to their fliers, or kill theirs with your combat robots, and
    Kessler-Hayashi fields anti-air troopers (a pale laser trooper with a long thin laser) and Grubstake flak buggies (a
    buggy with a turret, bursts in the air and a weak splash on the ground); Synthexis breeds violet spore spitters. Each
    shreds fliers and fights the ground weakly. Your destroyers and defenders should now meet an answer. Does air still
    feel unanswered? Do the anti-air units feel useless when no flier comes?
37. **Plain names** (0.1.64): Kessler-Hayashi's units are now Laser trooper, Heavy laser trooper, Anti-air trooper,
    Heavy tank, Laser tank and Lightning tank (were Line trooper, Lance, Skyguard, Aegis, Prism, Tesla).
38. **The stomper** (0.1.65, violet plates 0.1.66; evolution 0.8 and up): a five-legged thing three tiles across with
    violet plates walks over your wall with the herd, no breach, and stomps what stands inside. Rifles and lasers barely
    slow it; battle tanks, fliers, flamers and artillery do. Does it read as Synthexis's, and does it feel answerable?
39. **Its cells and their feed** (0.1.66): by each incubator a small acid-green floor, a biochamber at work on it and a
    green lamp: the culture at night is green dots. Kill a biochamber: that incubator stops breeding, most of its stock
    wanders off wild, and ten minutes later it is a plain nest again. Hitting a biochamber does not call the wave home
    (hitting an incubator does): raid the feed while the herd is out. Do the cells read as a lab on the nests?
40. **Its substrate and technicians** (0.1.67): near its middle a patch of Gleba soil with yumako trees and a burning
    heating tower (the site's light at night); white-suited technicians walk from it to each biochamber in turn. Kill
    them: five minutes on its biochambers stop and its incubators starve; a pod brings two more ten minutes later. Is
    the walk between tower and glass readable, and is killing the technicians worth the trip?
41. **Its clinic** (0.2.1): a biolab on the substrate by the heating tower, 1,500 health. While it stands Synthexis's
    breeds grow stronger, faster than the wild biters (spitters, then cinders, then stompers). Destroy it: its incubators
    breed only small and medium biters until a pod brings a new clinic half an hour later. Is it clear that this is the
    building to shell, and is the half hour worth an artillery trip?

42. **Fliers by corporation** (0.2.1): Grubstake's scrap drones come in numbers (weak, a little gun) and its bomb drones
    dive at your artillery, mortars and radars and blow up on them; Kessler-Hayashi fields a few laser drones from its
    second level, armoured, a laser beam. Do the two skies read as the two corporations? Do gun turrets and rockets
    feel like an answer to the laser drones, and is a bomb drone getting through to your artillery fair?

43. **The flamethrower trooper** (0.2.5, command bandwidth 3): a fifth order at the barracks, against swarms. Send a
    few with your troopers at a Synthexis wave or a late biter attack: does the fire read, does it hold the bugs, and does
    it ever burn your own? Kessler-Hayashi's Heavy tank now fires a rail cannon: can you tell its three tanks apart by
    their shots?
44. **Kessler-Hayashi's tanks leave camp** (0.2.7): its walled blocks no longer have baffle walls inside the gates,
    and nothing stands in front of a gate. Its tanks, walkers and research tanks should now come out on raids with its
    infantry (before, the tanks often stood in the yard while the infantry went alone). New camps only: blocks already
    built keep their old layout.
45. **The arena's numbers** (0.2.7, `scripts/play-arena.sh`): pick a unit on each side and the panel shows its health,
    speed, range, shots a second, one shot's damage and its resistances, and the two picked units against each other:
    what one shot does after resistances, per second, and how long your number of them takes to kill one. Does it
    answer the questions you had (the burster against troopers)?
46. **The burster, rebuilt** (0.2.7, evolution 0.6 and up): smaller and faster than the other breeds, frail (120
    health, no armour), and it no longer bites: it runs at your line and bursts there. Your rifles should drop it if
    they see it coming; a pack reaching a clump of troopers or your wall should hurt. Is there time to react, and can
    you pick it out of a wave?

## Your side
22. **Loot and components** (in wrecks since 0.1.42: mine one, or mark it for robots): what you destroy of theirs drops plates, circuits, magazines, and rare components that
   research six technologies (Cluster shells, Pheromone bait, Pact breaker, Claim marker, Rail rifle, Orbital strike).
23. **Threat scanner**: wired to a combinator, it counts their units within 64 tiles by kind; a jammer in reach blinds
   it ("Scanner jammed").
24. **Barracks, rally beacons, the muster point**: troopers, breachers, rocket troopers (command bandwidth 2) and tanks on
   circuit orders. Rocket troopers against their armour, troopers against their infantry: does each order earn its slot?

## Throughout
25. **Space Age looks**: landings by cargo pod, armoured troopers, tesla arcs. Do they read as theirs, not vanilla?
26. **Readability without chat**: could you tell who did what, and why, from the world alone (the map labels, the
   ghosts, the posts, the trucks, the icons)?
27. **Anything that feels wrong**: units stuck, wandering into worms, friendly fire, a theft or a raid that seems unfair.

## Tell me
What you saw for each, and what you'd change. Screenshots welcome.
