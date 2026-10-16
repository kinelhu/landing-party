# Grading the features (draft, 2026-10-16)

The user, instead of a raw playtest: "there is a lot of stuff we can abstract out to think and argue, and playtests are
mostly going to be about bug fixing and general vibe once we have a complete mod." So every feature is graded on paper
and by measurement on real saves, against the arc (`docs/arc.md`) and its test: does it change a decision the player
makes?

The four questions, per feature:
1. **Fires**: how often it happens in a real game (headless visits on the user's saves, counts per 3 hours).
2. **Reads**: can the player tell that it happened, who did it, and why (what they see: notice, alert, map, nothing).
3. **Answer**: what the player can do about it, and what that costs them.
4. **Decision**: which of their decisions it changes (where to build, what to protect, when to strike, what to give up).

## Measured so far
deathworld10x, 3 hours, both corporations provoked (visit before the builders and the cordon; Serenity forced to land
at minute 0 and Grubstake at 20, so the arrival gates are not in it):

| Feature | Fires (3 h) | Reads | Answer | Decision | Verdict so far |
|---|---|---|---|---|---|
| Raids (both) | 52 launched, 26 aborted, 5 done | an alert where it lands; the loss | turrets, walls | turret coverage at the edges | carries the pressure; half turn back unseen: the player never learns why |
| Grubstake strips (its identity) | **0** | notice | kill the camp | protect far ore | **never fired**: why is the first question |
| Grubstake looting | **0** | alert | cover chests | where chests stand | **never fired** |
| Pheromone flare | 5 (0 to 11 biters) | smoke, alert, tag | shoot the canister | turret ring depth | fires; weak on this save (few idle biters near) |
| Claim jumper | 0 (no guarded chests within 16; ladder at rung 0) | dust, alert | kill the rig | chests inside walls | never fires on a compact base |
| Power tap | 0 (no exposed pole in reach) | none until broken (by design) | cut the line | power line routing | never fires on a turret-dense base |
| Pact | 9 pacifier events, 3 pact changes | notices | kill the antennas | whether to fight Grubstake near nests | fires; meaningful only near nests |
| Reliefs | 8 | notice | intercept columns | none yet: the player rarely sees one | reads as a notice only |
| Serenity clearances, barrage | 6 clearances, 4 barrages | dramatic (shells from the sky) | none needed | none: it clears nests the player would clear | spectacle, not a decision (fine for identity) |
| Convoys | 110 delivered | visible haulers | ambush | none yet: nothing tells the player they matter | the economy-war hook, unused by the player |

## To measure next
- The same visit with the builders and the cordon (trucks, drones, the line), and unprovoked (the default).
- The other saves: nwa (megabase, artillery), nw (megabase, lasers), b - rocket (first rocket).
- Why Grubstake never strips or loots on deathworld: its strip targets need a mining drill with a camp site out of turret
  reach; on a compact base every drill may be covered.

## Questions to argue
- Grubstake's identity rests on stripping and stealing; if those never fire on a real base, what does the player meet?
- Half the raids turn back unseen. Should the player see a raid that turned back (it read their defence and left)?
- Convoys and reliefs are the "economy you can strike" pillar, yet nothing points the player at them. What would?

## Measured with the builders and the cordon (2026-10-16 evening; 3 hours each, four visits run at once)
| Save (mode) | Value razed | Raids (aborted) | Strips | Loot | Flares | Rigs | Taps | Crew runs | Cordon arcs (stood) | Reliefs | Convoys |
|---|---|---|---|---|---|---|---|---|---|---|---|
| deathworld10x (unprovoked) | 1,043 | 59 (24) | 0 | 0 | 9 | 0 | 0 | 396 | 5 (4) | 13 | 93 |
| deathworld10x (provoked) | 1,322 | 42 (26) | 0 | 0 | 7 | 0 | 0 | 567 | 5 (4) | 10 | 91 |
| nwa (megabase, artillery) | 1,542 | 248 (26) | 0 | 0 | 8 | 6 | 0 | 424 | 0 | 7 | 118 |
| nw (megabase, lasers) | 74 | 175 (16) | 0 | 1 | 3 | 2 | 0 | 498 | 2 (1) | 9 | 23 |

- Strips still 0 everywhere (before prospecting). The claim jumper fires only on the megabases; the tap nowhere.
- Tick cost: run four at once, even the baselines doubled (deathworld 0.31 -> 0.59 ms), so the numbers are inflated;
  the visit over its baseline went from 1.63 (morning) to 1.72. To measure alone before reading anything into it.
