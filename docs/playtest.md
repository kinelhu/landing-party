# Playtest kit (2026-10-15)

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

## Tell me
What you saw for each, and what you'd change. Screenshots welcome.
