# The player's army: what is it for? (brief, 2026-11-01)

The user, 2026-11-01: "I'm not entirely sure this mod survives on faction novelty alone if the answer is only ever
going to be 'build artillery' or 'build teslas'. Shouldn't we think hard about player army?" And: "I don't think we
should nerf arty. But for instance synthexis currently lands its cultures outside artillery range AFAIK, and having
corporation defenses require an army to destroy might be enough to encourage army building? Armies need to give
vision on the move also."

## Where it stands
Built (DESIGN, "The player's army"): barracks, command bandwidth (relays, command cores), rally beacons driven by
circuits, the threat scanner, the command tool, muster points, roads, field repair, capture of corporation outposts by
holding. Units: trooper, laser and heavy laser trooper, rocket, flame and anti-air trooper, breacher, battle and heavy
tank.

Tested: the arena (`docs/arena.md`) and small scenarios (`army`, `caps`, `control`, `circuit`, `scanresponse`,
`muster`, `roads`). Never: a player army in a visit, or anyone playing a game with one. The arena has the trooper
losing outright to bred big biters, creep big biters and behemoths.

## The problem
Everything the army fights comes to the wall in the end, where lasers and robots kill it for less. Artillery does
the attacking too. In the fed five-hour visits:
- nw (800 turrets, no artillery, 1,858 robots) fell. It lost 25,776 buildings, its robots ran out (647 left) and its
  logistic networks split.
- nwa (2,647 turrets, 59 artillery, 11,230 robots) held. It lost 5,983 buildings and rebuilt most of them; 6
  Synthexis raids turned back under artillery.

So the deciding numbers were turrets, artillery and robots. An army was never needed.

## The rule
Artillery stays as it is. The army gets jobs that turrets and artillery cannot do, and makes artillery better where
they meet.

## Jobs to weigh
1. **Eyes (the user).** Artillery fires only at what it sees. Turrets don't move; radars see a fixed disc. A squad
   on the march, or a scout, that charts the ground as it goes makes artillery reach further: the army spots, the
   artillery hits. It also feeds the threat scanner idea: a squad that reports what it sees on its beacon's
   circuit.
   *To test first, not assume:* whether the engine's units reveal anything themselves (characters and radars do);
   whether automatic artillery needs the target charted; how to measure charting headless (DESIGN: "headless runs
   chart nothing"; a `force.chart` left a run byte for byte the same).
2. **Corporation defences only an army can take (the user).** Artillery would still destroy what it hits, but a
   camp's core holds against shells: Serenity's static shield generators, already proposed ("bubbles which can
   tank some artillery shells"), with a power line an army can cut. Capture by holding needs units on the ground
   anyway, and it pays (drills, generators, command cores).
3. **Synthexis out of reach (the user).** It never lands or seeds within its foes' artillery reach, but that is
   checked once: nwa's artillery, built or researched later, found its cultures (8 artillery turrets lost to it).
   Two ways to make a culture an army's job: it moves away when shelled (out of reach, so it has to be followed),
   or it keeps away from charted ground (no eyes, no shells; see job 1). Either way an army out front turns it back
   into artillery's job.
4. **Things that move.** Sieges on the march, carriers, convoys and Grubstake's truck are caught before the wall or
   not at all. nw's lesson: robots are what a defence runs out of, and every wave stopped in the field saves them.
5. **What only holding gives.** Rewards that come only from units standing somewhere: capture as now; samples from a
   culture's site held while it is taken apart.

## The instrument first
Before designing more: a visit with a scripted player army (barracks fed, beacons and scanner circuits set up the way
a player would) on nw and nwa, against the same run without it. That shows what an army does now, so a change can be
measured against it.

## Questions for the consult
- Which two of the five jobs make the army something a player wants, not something the mod forces?
- Eyes: what should see (every unit, scouts only, a vehicle), how far, and what does Synthexis or a corporation do
  about being seen?
- Shields against artillery: how much should a dome hold, and what takes it down besides an army?
- How does the army's cost (bandwidth, cores) stay a choice and not a tax once a base makes thousands of everything?
