# Playtest kit (2026-10-19)

Nothing since the 16th has been played. Since then: Serenity is at war from landing (no grace), Grubstake steals by
night (skimming trucks, raids that dismantle machines, a yard of stolen goods), raids have leaders, Serenity has a
fortress kit (sieges sized to win, the howitzer, a robot jammer, the power strike, strangling, belts cut on its line),
clears the nests that hit it and bills you for the waves your pollution draws. Space Age: landings by cargo pod,
armour, tesla arcs. The player's side: threat scanner, muster point. All checked headless (about 180 scenarios, visits
of real saves); none of it played. Chat notices are off by default: the world should tell you what happens.

## Start
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
- Grubstake's heists on demand, from the nearest camp: `/lp flare` (a pheromone flare where you stand), `/lp rig` (a claim
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
7. **A pheromone flare**: a buggy drops an orange canister just out of your turrets' reach; idle biters nearby come for
   whatever is near it. Shoot the canister.
8. **A claim jumper**: a rig digs in outside your wall, a mound grows by your chests, Shotgun hands come up, empty them
   and go back down. Kill the rig within the minute and nothing comes up.
9. **A power tap**: a line of its pylons creeps to a pole no turret covers and clamps it. Look for "Power tap" in your
   power statistics. Cut the line or break the clamp.
10. **Prospecting and the road**: it tags the undrilled patch nearest your base and claims it ten minutes later (drill it
   or set a border stake to stop it); a truck carries the ore home; kill it and the claim lapses.
11. **Pay the thief**: a trade post (a steel chest and 5 circuits) by its camp; what it empties buys a truce, a minute for
   each 10 of value; a lamp on the post while it holds.

## Serenity, the wall (from the first rocket)
12. **Arrival**: the orbital barrage on the nests within 120 tiles, a clean concrete camp, railgunners in charcoal.
13. **At war from landing**: raids come at your exposed buildings from the start. A raid's leader wears its heart icon;
   kill it and the raid falls back to its staging point in order, a new leader takes the icon, and it comes again.
14. **The line**: 30 minutes after landing, drones build cordon posts on an arc toward you; its claim follows, its next
   arc drawn on the map, a named warning a step before it encloses a building of yours. Near you it closes with wall;
   across your rails a gate post (your trains stop). Shoot the drones: three lost on a post and the line is held there.
15. **Strangling**: the line goes for your outpost easiest to cut off; with none of your buildings in reach, for the ore
   field you will want next. On its edge, where its guns stand (a turret of its within 30 tiles), it blows your belts,
   pipes and loaders every 30 seconds (an explosion each): undergrounds with both ends off the line pass, and a sector
   whose posts you destroyed is open.
16. **Against a fortress**: a hauler brings mortars (a howitzer when robots keep the wall), a fire plan on one point at a
   time, roboports first; a jammer mast in the emplacement whose tesla arcs down your robots and blinds your threat
   scanners within 50 tiles. Destroy the mast. Kill the howitzer and its camp has none for 30 minutes: the next siege
   comes with mortars only.
17. **The power strike**: two scouts walk out to a pole of yours, and minutes later a raid goes for it: the one pole
   whose loss darkens the lasers behind it. A second feed, or accumulators by the turrets, is the answer.
18. **Hazard removal**: when biters keep hitting it, it sends a clearance siege at their nest, away from you.
19. **The invoice post**: a chest of yours at its line, the sum written over it: what the biter waves your pollution
   drew cost it. Put circuits, modules or steel in it. Paid off, it buys a truce (a minute per 10 paid, 10 to 60): no
   raids, sieges or cuts, its line holds, an amber light by night. Is the price fair? Is it worth paying? Or dispute
   it: kill the nest a bill names (Serenity's icon over it, in game and on the map) and that bill is struck.
20. **A border stake during a truce**: the border holds after the truce ends, until you build on its side.
21. **Bend the line**: a decoy building nearer its camp than the rest swings its next arcs toward it.

## Your side
22. **Loot and components**: what you destroy of theirs drops plates, circuits, magazines, and rare components that
   research six technologies (Cluster shells, Pheromone bait, Pact breaker, Claim marker, Rail rifle, Orbital strike).
23. **Threat scanner**: wired to a combinator, it counts their units within 64 tiles by kind; a jammer in reach blinds
   it ("Scanner jammed").
24. **Barracks, rally beacons, the muster point**: troopers, breachers and tanks on circuit orders.

## Throughout
25. **Space Age looks**: landings by cargo pod, armoured troopers, tesla arcs. Do they read as theirs, not vanilla?
26. **Readability without chat**: could you tell who did what, and why, from the world alone (the map labels, the
   ghosts, the posts, the trucks, the icons)?
27. **Anything that feels wrong**: units stuck, wandering into worms, friendly fire, a theft or a raid that seems unfair.

## Tell me
What you saw for each, and what you'd change. Screenshots welcome.
