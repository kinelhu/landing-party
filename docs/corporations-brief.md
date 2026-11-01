# The corporations' place in the game (brief, 2026-11-01)

The user, 2026-11-01: "I was thinking about their place in the current factorio gameplay loop. Synthexis was the
easiest to conceptualise for me and might stay relevant for the whole game. Grubstake seemed like a good early enemy
with potential for transition into mid-early late game. I had pictured Kessler as more of a late mid-late game foe with
high tech units and bases that are armed to the teeth, but we had to tone that last part down so Synthexis didn't lose
its waves passing by Kessler bases." And: "Let's be careful not to wreck what works already."

Read with `docs/army-brief.md`: the late corporation and the player's army are one design problem.

## The arc
| Phase | Player's usual answer | Who presses | What should break the usual answer |
|---|---|---|---|
| Early-mid (oil, blue science) | gun turrets, walls | Grubstake (survey at oil processing, lands at the first chemical pack) | it raids outposts, poles and trains, not the wall |
| Mid to late | lasers, robots, flamethrowers | Synthexis (lands at evolution 0.25; all game) | it learns the guns, cuts their feeds, wears repair down |
| Late (rocket and after) | artillery, more robots | Kessler-Hayashi (lands at the first rocket launch) | it outranges the wall and holds against shells: an army cracks it |

## What the fed megabase visits showed (0.2.130, five hours)
- **Kessler-Hayashi** fell in 4 of 5 fed runs: to Synthexis's big biters at about 190 minutes on nw, to wild behemoths
  28 minutes after landing on nwa (one tank built). Its raids were 1 to 4 units, every one called off on nw; it razed
  nothing of the player's in any of them.
- **Grubstake** raided substations, roboports and artillery with 4 to 48 units: on nwa 37 raids, 11 done, 21 fled,
  lasers killing 282 of its 312 dead.
- **Synthexis** wore nw down and was held by nwa (see the DESIGN findings for both).

Megabases are not the target (the whole-mod consult, 2026-10-29), so the phase visits below measure each corporation in
its own phase.

## Kessler-Hayashi: arrive late and already strong
Its trouble is structural. It lands at the rocket launch, when the world is at its most hostile (behemoths, grown
cultures, a player with artillery), and then grows from small, with defences cut back (the railgunner made a nest
clearer and weaker at baseline, 0.2.20: "makes KH bases virtually impregnable to biters"). Proposals:
1. **An armed landing.** The lander brings its fortress down with it (walls, guns, a shield dome), so its strength comes
   from its technology, not from an hour of building.
2. **Synthexis passes it by routing, not by its weakness.** Synthexis already routes round foreign turrets
   (`ops.route`). If its waves still bleed by Kessler-Hayashi's camps, the fix is its route keeping off Kessler-Hayashi's
   ground unless it goes for it. Measure first: Kessler-Hayashi at full strength beside Synthexis, waves' losses on the
   way past counted.
3. **A cleared landing.** At late evolution it lands where it has cleared, or under its dome, not in behemoth country.
4. **Its threat is the one that makes the army needed.** Howitzer and mortar outrange the wall (the army's
   deploy-and-reclaim reserve answers); domes hold against artillery (an army spots, cuts power, takes it); high-tech
   units punish a lazy army.

## Grubstake: early, then the scavenger of Synthexis's war
The pheromone flare was retired with good reason (0.1.55: biter waves are Synthexis's; two factions steering biters
blur who sent a wave), and it would fade late anyway: on nw no flare flew, no nests being left by the walls. A late role
that fits a salvage company instead: Grubstake and Synthexis keep a truce, and a breach leaves a feast (nw at minute
270: thousands of wrecks, about 5,500 ghosts, roboports dark, the logistic networks in five pieces). Grubstake loots
after a breach, snatches outposts a siege cut off, taps a grid while the robots are busy elsewhere (its loot raids and
power tap exist). It scales with Synthexis, not the clock, and the wreck field becomes an army's job. Alternative if the
flare is wanted back: Grubstake provokes nests by the player's outposts instead of steering biters (crude, deniable,
wild; still fades late).

## Synthexis: the constant
Leave it. Its job is to keep turrets and robots from being the whole answer.

## What works and must not break
Kessler-Hayashi: its tactics ladder and attempt records (0.2.111), sieges set up out of each gun's own reach (0.2.122),
clearing incubators as nests, the railgunner's leash (0.2.129), the trucks and guards holding where they are sent
(0.2.130). Grubstake: its pact with the wild biters, its truce with Synthexis, its heists (rig, tap, snatch), the
thieves' hours. Between them: the grievance ledger and reprisals. Synthexis: everything.

How: every change behind a switch first (a `debug_tune` key or a visit mix), measured on the phase visits against the
same run without it, then turned on with the regressions of the areas it touches.

## The instrument: one visit per phase (running 2026-11-01)
The reference factories (`scripts/make_reference.sh`), 180 minutes each, recorded:
1. belt, evolution 0.3: Grubstake alone (`LP_MIX=nosyn-nokh-record`);
2. laser, 0.6: Grubstake and Synthexis (`LP_MIX=nokh-record`);
3. artillery, 0.8: all three (`LP_MIX=record`).
Caveat: the three share one core; only the defence and the evolution differ, not the size or the research.
