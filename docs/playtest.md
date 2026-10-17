# Playtest kit (2026-10-15, rivals added 2026-10-17)

What changed since the last time the mod was seen in game: Grubstake's pact and pacifier antennas, Serenity's
railgunners, howitzer, cluster shells and orbital barrage, clearances, the staggered arrival, standing down, and the
ladder buying capacity; since then (2026-10-16) Grubstake's scrap cannon, pheromone flare, claim jumper and power tap,
loot in place of salvage, faction components and Cluster shells. All checked headless; none of it played.

## Start
Close your own game first (Steam allows one copy). Then, in a terminal:

    cd ~/Dev/landing-party && scripts/play-visit.sh deathworld10x

It opens a fresh copy of the deathworld save the visits used (never the real file), with Landing Party, Editor
Extensions and flib. No test mod: the mod runs as a player would meet it.

- Grubstake comes first. This save has oil processing but has never made a chemical science pack (checked headless,
  2026-10-16), so only its survey party lands at first (a radar, two drills, a lamp, four guards, about 450 tiles out).
  The lander follows the first chemical science pack, or 30 minutes after the survey party leaves (it stays an hour):
  90 minutes. Not to wait: `/lp land grubstake 300` lands it now; `/lp fast` shortens the survey to 3 minutes and the
  wait after it to 3.
- Serenity's gate is the first rocket launch (Space Age): on this save, call it with `/lp land serenity 300`.
- `/lp list` shows the settlements; `/lp fast` speeds their clocks; `/lp provoke` makes Serenity count you as having
  attacked it; `/lp trace` writes their decisions to `script-output/landing-party/decisions.txt` in the visit profile.
- `/editor` (Editor Extensions) to watch untouchable.
- Grubstake's discreet operations on demand (their own triggers wait on its ladder, the pact and what it has seen), from
  the nearest Grubstake camp: `/lp flare` (a pheromone flare at where you stand, its canister out of your turrets'
  reach), `/lp rig` (a claim jumper at the chests nearest you), `/lp tap` (a power tap on the pole nearest you: stand by
  a pole no turret covers). Add a camp's id to pick one (`/lp list`).

## Look for
1. **Grubstake's camp and its pacifier antenna** beside the lander: a radar dish a size larger than a radar. Biters walk
   past the camp. Destroy every antenna: a notice, and the biters turn on Grubstake; five minutes later one is rebuilt
   (another notice) if the lander stands.
2. **A Grubstake raid**: buggies and Shotgun hands at your soft targets (poles, outposts, rails), roughly every 10 to 20
   minutes once its clock runs, breaching walls where it must. Pods of 8 to 24 come down behind its lander between.
3. **Serenity's arrival** (`/lp land serenity 300`, best near nests): the orbital barrage, shells from the sky with
   cluster bomblets on every nest within 120 tiles, a notice; eight railgunners in charcoal, a size larger than its Line
   troopers.
4. **A Serenity clearance** (provoked, with nests between it and you): a hauler drives out past its wall, mortars (or the
   howitzer, full-size artillery, when worms outrange the mortars) shell a nest, railgunners hold the ring. Three shells
   or so a nest from the howitzer; it moves up to the next.
5. **Grubstake's scrap cannons** (every second turret of its camps, a gun turret's body a size up): bursts of small
   hits over a crowd. Deadly to biters and troopers in a blob, next to nothing to walls.
6. **A pheromone flare** (once its ladder against you is on the first rung, the pact holding): a buggy drops an orange
   canister just out of your turrets' reach by a guarded spot; the nearby idle biters come for whatever is near it.
   Shoot the canister and they lose interest.
7. **A claim jumper** (second rung): a drill rig digs in 40 to 60 tiles outside your wall, dust and an alert; a mound
   grows by your chests inside; a minute later Shotgun hands come up, take what is in the chests and go back down.
   Kill the rig within the minute and nothing comes up. Best seen against chests your turrets do not cover.
8. **A power tap**: a line of Grubstake pylons creeps out of turret reach to a pole of yours that no turret covers (a
   long line to an outpost), and a small orange clamp sits by the pole. No notice: look for a "Power tap" consumer in
   your power statistics, or brownouts. Cut the line and it stops; break the clamp and you are told what it took.
9. **Loot**: what you destroy of theirs drops plates, circuits, magazines, engines; the rare components (pheromone
   gland, pacifier crystal, drill head; rail coil, cluster fuze, orbital beacon). Three cluster fuzes taken apart in an
   assembler ("Cluster fuze, disassembled") research Cluster shells, for your artillery. The other five work the same
   way: glands for Pheromone bait (set it by a Serenity camp), crystals for the Pact breaker (set it inside a Grubstake
   claim) and the Claim marker (Grubstake leaves what is near it alone), coils for the Rail rifle, an orbital beacon for
   the Orbital strike (a beacon on your power that calls Serenity's barrage within 60 tiles).
10. **Notices**: are they readable, too many, too few? (Pacifier down and back, orbital barrage, Serenity's gate, a camp
   standing down, reliefs, flares, rigs, a tap broken.)
11. **Anything that feels wrong**: units stuck, wandering into worms, friendly fire (Serenity's flamers still burn its own
   units at the gates: known), looks that read as vanilla.

## Since the night of 16 to 17 October: rivals (`docs/night-2026-10-17.md`)
Start the same way. Each camp is now labelled on the map with its standing toward you ("Grubstake: rival"); turrets
within 26 tiles of a camp make it an enemy. `/lp incidents` lists the last twenty things they did and where.
12. **Grubstake's crews**: modules beyond 40 tiles of its lander are built by a truck that drives out with the parts
   (orange sparks). Kill one: it spills plates. Kill three on one site and the camp gives it up (a notice).
13. **Prospecting**: within its reach, the undrilled ore patch nearest your base is tagged ("has reassigned the mineral
   rights..."). Ten minutes later a truck builds a claim there, unless you drilled it or set a **border stake** on it
   (crafted from the start: 10 stone bricks, 5 iron plates).
14. **The road**: a truck carries each claim's ore home every few minutes. Kill it on the way back: the ore spills and
   you are told how late its expansion runs. A claim with no ore home for 20 minutes lapses; its drills are yours.
15. **Pay the thief**: a **trade post** (a steel chest and 5 circuits) by its camp; what it empties buys a truce (a minute
   for each 10 of value): no raids, flares or heists while it lasts.
16. **Serenity's cordon** (30 minutes after it lands; `/lp fast` to hurry): drones fly out and build posts (a pad, walls,
   two gun turrets) on an arc toward your nearest building; its claim follows once the arc stands, its next arc drawn
   on the map. Near you it closes the arc with wall; across your straight rails it puts a gate (your trains stop);
   ore it crosses it claims. Shoot the drones at your line: three lost on a post and "its line is held".
17. **A border stake** facing Serenity, outside its claim and while it is a rival: its line holds short of it. Build on its
   side and the treaty breaks for good.
18. **Bend the line**: it bears on your building nearest its camp, so a decoy (any building, set nearer than the rest
   and off to one side) swings its next arcs toward it, toward Grubstake's camp if you place it well.

## Tell me
What you saw for each, and what you'd change. Screenshots welcome.
