# Playtest kit

Mod 0.2.158, branch `muster`, rewritten 2026-10-31. Nothing has been played since 2026-10-16; everything below has
been checked headless only. Chat notices are off: the world should tell you what happens.

## Start

Close your own game first (Steam allows one copy). Then:

    cd ~/Dev/landing-party && scripts/play-visit.sh playtest

(Main has `muster` merged; the worktree runs the same.) This opens a fresh copy of deathworld10x (never
the real file) with Landing Party as a player would meet it, no test mod.

| When | What arrives | Not to wait |
|---|---|---|
| minutes in (evolution here is past 0.25) | **Synthexis**, at the edge of your pollution; first wave about 10 min later | `/lp biotech`, then `/lp wave [n] [deep]` |
| first chemical science pack | **Grubstake Inc.** (survey party first, lander after) | `/lp land grubstake 300` |
| first rocket | **Kessler-Hayashi**, at war from landing | `/lp land serenity 300` |

Useful: `/lp list` (settlements), `/lp fast` (speeds their clocks), `/lp incidents` (last twenty things they did, and
where), `/lp help`, `/editor` (watch untouchable). Grubstake works by night: wait for dusk.

A plan for two hours: Synthexis alone for the first hour (let two or three waves come, then build a second wall and
mines and let it come again), call Grubstake at dusk, Kessler-Hayashi last.

## The ten

1. **Does Synthexis pick its target well?** A pale cyan scout walks round your base out of reach and sits at one
   side; the herd follows a green trail to that face. Does it come where you are weak (an outpost with few guns, a
   power plant at the edge)? Could you tell why afterwards?
2. **Does it learn?** After a wave you stopped, the next one should come back different: elsewhere, with twice the
   rams, as a siege, or as a cut of a power line feeding your turrets. Can you see the difference? Can you read why?
3. **The siege against a wall** (build two walls with mines between). Ochre sweepers blow your mines first, a screen
   goes at the wall, big glowing bursters blow it open while the herd waits out of reach, then the herd rushes the gap.
   Do the steps read? Do mines still feel worth building? Is the burst too strong?
4. **Wave size.** Waves grow with the colony (60 up to 8 incubators, 120 at 16; past evolution 0.5 a culture may grow
   up to 28 incubators and 200). Does a 150-biter wave
   from a big colony feel earned, or unfair? Does killing incubators visibly shrink the next one?
5. **Tesla turrets.** Synthexis answers them by cutting the power line behind them. Does an exposed line feel like the
   weak point it is? Does a second feed or accumulators feel like the fix?
6. **The hunt.** Go to its culture: creep, incubators, biochambers, technicians, the clinic. Is the expedition a fight
   worth making, and is it clear what to shoot first?
7. **Grubstake by night.** Trucks skimming your belts, raids that take machines apart, its leader carrying the haul.
   Fair? Readable? Does night feel like the dangerous time?
8. **Kessler-Hayashi's pressure.** Raids from landing, its line creeping toward you, belts blown on its edge. Against a
   fort it should hold back, save, and come with a siege: mortars set just out of your turrets' reach, then a howitzer
   if the mortars fail twice. Does holding back read as intent or as idleness? Is the howitzer's deploy a fair window?
9. **Readability without chat.** Could you tell who did what, and why, from the world alone (trails, icons, posts,
   ghosts, map tags)?
10. **Anything wrong.** Units stuck, friendly fire, a slow game, a theft or raid that seems unfair.

## Reference: what each faction does

Read when something puzzles you; not a checklist.

### Synthexis (biotech, from evolution 0.25)
- **Landing and food**: lands at the edge of your pollution and eats it through its creep. Incubators breed only on
  that biomass; a clean factory leaves it a trickle. An idle incubator has no animation.
- **Creep**: violet ground with sunk tumors, dead trees on it. No building on creep; its biters are quicker and mend on
  it. Kill the tumors and it withdraws; incubators left off it go wild after three minutes.
- **The culture**: biochambers by each incubator (kill one: that incubator stops), technicians walking from a heating
  tower on Gleba soil (kill them: five minutes without feed), a clinic biolab (kill it: only small and medium biters for
  half an hour). Hitting an incubator calls the wave home; hitting a biochamber does not.
  While the clinic stands its evolution climbs slowly to at most 0.15 past the wild biters'.
- **The scout and the trail**: one pale cyan biter before each wave, a mud trail and a dashed map line from the farm.
- **Choosing**: it reads your base as fire, value and cost, and picks from a menu: raid, siege, probe (eight runts that
  die at a face), cut of a power or fluid feed, strike behind a cut. An attack that failed at a place lately is set
  aside; where rams all went off and the wave still stood at a wall, it sends twice the rams. When your defence is too
  dear it saves up and waits.
- **Inside**: each biter takes its own target (power, inserters loading guns, radars, roboports); spitters hold the
  gap. Sometimes a deep strike runs for the heart. A wave caught under fire on the march breaks in there. The next wave
  comes back through holes earlier ones made.
- **Breeds**: spitters (0.45), bursters (0.6: frail, run at your line and burst), big bursters for sieges, sweepers
  (ochre, clear mines within 7 tiles), stompers (0.8: walk over walls), spore spitters against your fliers. Old stock
  goes back into the vat.
- **Carrier**: a slow violet lit biter with an escort crossing to found a second culture.
- **Others**: it fights Kessler-Hayashi when shot at on the way (or goes round), and leaves it alone otherwise.

### Grubstake Inc. (the thief, from chemical science)
- **Town**: gravel streets, machines both sides, junk yards, piers on lakes, turrets at street ends, no walls. A
  pacifier antenna keeps biters off it (destroy every antenna and they turn on it).
- **By night**: raids, skims and claim jumps leave after dark. Raiders walk in without firing and dismantle up to
  twelve machines, leaving ghosts, and empty chests near. The foreman (pick icon) carries the haul: kill it and all of
  it drops and the raid runs.
- **Skim**: a truck parks by an uncovered belt and takes half of what passes. Undergrounds or a turret stop it.
- **Yard**: a chest by its camp with what it stole; destroy it and it spills.
- **Claim jumper**: a rig digs in by your chests; kill it within the minute. **Power tap**: pylons creep to an
  uncovered pole ("Power tap" in your power stats). **Prospecting**: it claims the undrilled patch nearest you ten
  minutes after tagging it (drill it or stake it).
- **Pay the thief**: a trade post by its camp; what it empties buys a truce, a minute per 10 of value.
- It takes soft targets and leaves walls alone.

### Kessler-Hayashi (the wall, from the first rocket)
- **Arrival**: orbital barrage on nests within 120 tiles, a plated camp, railgunners (charcoal) that clear nests and
  never come at you.
- **Raids** from landing at exposed buildings; the leader wears its heart icon (kill it: they fall back and come again).
- **The line**: drones build lit cordon posts on arcs toward you; compounds spread out like metastases, then a curtain
  wall. A named warning comes a step before it encloses a building of yours. Shoot the drones: three lost and the line
  holds there. A decoy building bends its arcs.
- **Strangling**: on its edge, where its guns reach, it blows your belts, pipes and loaders every 30 s. Undergrounds
  with both ends off the line pass.
- **Memory**: it learns what each of your turrets costs it and keeps a record of its operations. When the odds are
  bad it holds and saves instead of throwing raids it will lose.
- **Sieges**: a hauler brings mortars, placed just out of your turrets' reach, side by side; a howitzer truck where no
  mortar site exists or after two failed sieges (deploys 30 s, packs 15 s: your window; killed, none for 30 min). A
  jammer mast blinds your scanners and arcs down robots. The power strike goes for the one pole that darkens your
  lasers.
- **Hazard clearance**, **the invoice post** (it bills you for biter waves your pollution drew; pay for a truce, or kill
  the nest a bill names), **border stakes**, and **labs** (each branch's units fielded only while its lab stands).
- **Units**: laser, heavy laser and anti-air troopers; heavy, laser and lightning tanks; laser drones.

### Your side
- Wrecks drop plates, circuits and rare components that unlock six technologies.
- Threat scanner (counts their units within 64 tiles on a wire; jammed near a mast).
- Barracks, rally beacons and the muster point: troopers, breachers, rocket and flamethrower troopers, tanks on circuit
  orders. The arena (`scripts/play-arena.sh`) shows any matchup's numbers.

### Looks worth a glance
Space Age touches (cargo pods, armour, tesla arcs); each faction's fliers (Grubstake's scrap and bomb drones,
Kessler-Hayashi's laser drones); cliffs blown and ponds filled where they build. Showcase saves for units and the
arena: `LP_MIX=units scripts/showcase.sh 12345 20`, then `scripts/play-showcase.sh units`. A siege on your own save:
`scripts/siege-save.sh <copy>`, then `LP_WATCH=siege.zip scripts/play-visit.sh <name>-waves0-breachlabsavesiege`.

## Tell me
For each of the ten: what you saw, and what you would change. Screenshots welcome.
