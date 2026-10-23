# The arena: who counters whom (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (3240 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

![Counter heatmap](arena/counters.png)

Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, from -100 (wiped out, took nothing) to +100. Rows are grouped by class (below), strongest first within each.

## Classes

A class is a body and a weapon: **small arms** (many light bodies, small shots), **splash** (one weapon that hits several at once: a blast, an arc, a split beam), **armour** (a heavy hull whose flat resistance eats small shots), **air** (fliers: only weapons that can shoot up touch them; `docs/units.md` says which). The class against class score is the mean of its kinds' cells.

| Row against column | small arms | splash | armour | air | anti-air | bred | bred on creep |
|---|---|---|---|---|---|---|---|
| small arms | +0 | -51 | -21 | +47 | +47 | -27 | -56 |
| splash | +51 | +0 | -57 | -100 | +85 | +46 | +48 |
| armour | +21 | +57 | +0 | -67 | +81 | -2 | -5 |
| air | -47 | +100 | +67 | +0 | -89 | +100 | +90 |
| anti-air | -47 | -85 | -81 | +89 | +0 | -58 | -91 |
| bred | +27 | -46 | +2 | -100 | +58 | +0 | -5 |
| bred on creep | +56 | -48 | +5 | -90 | +91 | +5 | +0 |

## Each kind's counters

| Kind (price) | Beats most (its score) | Beaten most by (their score) |
|---|---|---|
| rocket trooper (20) | scavenger (95), harrier (95), dozer (88) | battle tank (76), breacher (72), slug (56) |
| slug (30) | scavenger (100), harrier (94), bred spore (89) | bred big (creep) (84), laser tank (83), heavy tank (80) |
| shotgun hand (8) | bred spore (89), flak buggy (85), walker (77) | scavenger (100), harrier (100), bred big (100) |
| trooper (10) | harrier (98), scavenger (97), bred spore (81) | bred big (100), bred big (creep) (100), bred medium (creep) (88) |
| laser trooper (10) | scavenger (97), harrier (95), anti-air trooper (73) | shock (89), laser tank (88), tank (86) |
| heavy laser trooper (16) | scavenger (96), harrier (95), dozer (67) | battle tank (86), bred big (creep) (79), rocket trooper (78) |
| railgunner (22) | bred medium (100), bred big (100), bred medium (creep) (100) | scavenger (100), harrier (100), laser tank (100) |
| buggy (15) | scavenger (97), harrier (96), bred spore (82) | laser tank (100), lightning tank (100), bred big (100) |
| laser tank (100) | railgunner (100), shock (100), bred medium (100) | scavenger (100), harrier (100), heavy tank (100) |
| breacher (10) | shotgun hand (96), buggy (95), bred medium (94) | scavenger (100), harrier (100), heavy tank (100) |
| shock (30) | buggy (93), laser trooper (89), bred spore (89) | scavenger (100), harrier (100), laser tank (100) |
| lightning tank (100) | railgunner (100), shock (100), sapper (100) | scavenger (100), harrier (100), heavy tank (100) |
| sapper (30) | bred spore (94), buggy (93), shotgun hand (92) | scavenger (100), harrier (100), lightning tank (100) |
| battle tank (60) | railgunner (100), laser tank (100), lightning tank (100) | scavenger (100), harrier (100), dozer (50) |
| heavy tank (95) | railgunner (100), laser tank (100), lightning tank (100) | scavenger (100), harrier (100), heavy laser trooper (56) |
| dozer (100) | railgunner (100), shock (100), laser tank (100) | scavenger (100), harrier (100), bred spitter (95) |
| tank (60) | flak buggy (100), laser tank (93), laser trooper (86) | scavenger (100), harrier (100), battle tank (86) |
| walker (100) | railgunner (100), sapper (100), scavenger (100) | bred big (93), bred big (creep) (92), bred medium (creep) (82) |
| scorcher (70) | flak buggy (100), buggy (86), laser trooper (81) | scavenger (100), harrier (100), bred big (100) |
| harrier (40) | railgunner (100), shotgun hand (100), shock (100) | anti-air trooper (100), flak buggy (100), trooper (98) |
| scavenger (50) | railgunner (100), shotgun hand (100), shock (100) | slug (100), flak buggy (100), walker (100) |
| anti-air trooper (18) | harrier (100), scavenger (98), bred spore (92) | bred big (creep) (94), battle tank (89), walker (88) |
| flak buggy (20) | scavenger (100), harrier (100), bred spore (82) | laser tank (100), tank (100), scorcher (100) |
| bred spore (10) | scavenger (82), harrier (55), tank (-28) | railgunner (100), walker (100), laser tank (96) |
| bred burster (70) | scorcher (100), buggy (97), shotgun hand (83) | railgunner (100), scavenger (100), harrier (100) |
| bred big (28) | shotgun hand (100), trooper (100), buggy (100) | railgunner (100), scavenger (100), harrier (100) |
| bred medium (7) | buggy (98), bred spore (94), scorcher (86) | railgunner (100), scavenger (100), harrier (100) |
| bred spitter (9) | dozer (95), bred medium (54), scorcher (52) | railgunner (100), scavenger (100), harrier (100) |
| bred big (creep) (28) | shotgun hand (100), trooper (100), buggy (100) | railgunner (100), scavenger (100), laser tank (96) |
| bred medium (creep) (7) | buggy (98), flak buggy (96), scorcher (94) | railgunner (100), scavenger (100), harrier (100) |

## Groups found from the fights alone

Each kind is its row of scores (against every kind and every fixed opponent); kinds are joined by average linkage on the distance between rows, so two kinds land together when they beat and lose to the same things (`scripts/arena_report.py`, scipy). Cut into 7 groups, as many as the hand-made classes:

![Clusters](arena/clusters.png)

| Group | Kinds (hand-made class) |
|---|---|
| 1 | laser tank (splash), breacher (splash), shock (splash), lightning tank (splash), sapper (splash), battle tank (armour), heavy tank (armour), dozer (armour), tank (armour), bred burster (bred), bred big (bred), bred medium (bred), bred big (creep) (bred on creep), bred medium (creep) (bred on creep) |
| 2 | rocket trooper (small arms), slug (small arms), trooper (small arms), laser trooper (small arms), heavy laser trooper (small arms), buggy (small arms), anti-air trooper (anti-air), flak buggy (anti-air), bred spore (anti-air) |
| 3 | shotgun hand (small arms), bred spitter (bred) |
| 4 | harrier (air), scavenger (air) |
| 5 | railgunner (small arms) |
| 6 | walker (armour) |
| 7 | scorcher (armour) |

## Faction against faction

From the unit matrix, each faction's roster (the kinds it fields from landing or its tree; a kind both corporations field counts for both; Synthexis's breeds on creep too). **Answer**: for each of the other side's kinds, the row's best score against it, averaged: can it answer whatever the other fields? **Coverage**: the share of the other side's kinds it has a counter scoring +50 or more for. **Exposure**: the share of its own kinds the other side has such a counter for. **Breadth**: how many of the groups found from the fights alone (above) its roster spans.

![Factions](arena/factions.png)

| Row against column | Answer | Coverage | Exposure | Their answer | Edge |
|---|---|---|---|---|---|
| Kessler-Hayashi against Grubstake | +92 | 100% | 100% | +90 | +2 |
| Kessler-Hayashi against Synthexis | +100 | 100% | 40% | +36 | +64 |
| Kessler-Hayashi against You | +65 | 50% | 90% | +84 | -19 |
| Grubstake against Kessler-Hayashi | +90 | 100% | 100% | +92 | -2 |
| Grubstake against Synthexis | +99 | 100% | 89% | +84 | +16 |
| Grubstake against You | +85 | 100% | 89% | +85 | +0 |
| Synthexis against Kessler-Hayashi | +36 | 40% | 100% | +100 | -64 |
| Synthexis against Grubstake | +84 | 89% | 100% | +99 | -16 |
| Synthexis against You | +55 | 25% | 86% | +77 | -22 |
| You against Kessler-Hayashi | +84 | 90% | 50% | +65 | +19 |
| You against Grubstake | +85 | 89% | 100% | +85 | +0 |
| You against Synthexis | +77 | 86% | 25% | +55 | +22 |

| Faction | Kinds | Breadth (groups of 7) | Roster |
|---|---|---|---|
| Kessler-Hayashi | 10 | 4 | laser trooper, heavy laser trooper, railgunner, laser tank, shock, lightning tank, heavy tank, tank, walker, anti-air trooper |
| Grubstake | 9 | 5 | slug, shotgun hand, buggy, sapper, dozer, scorcher, harrier, scavenger, flak buggy |
| Synthexis | 7 | 3 | bred spore, bred burster, bred big, bred medium, bred spitter, bred big (creep), bred medium (creep) |
| You | 4 | 2 | rocket trooper, trooper, breacher, battle tank |

## Mixed arms: does a flier soak a ground army's fire?

A ground army against the same spend with part of it in fliers, both ways round. Ground-only weapons cannot hurt a flier; a unit whose shot is aimed at one is turned to a ground target it can hurt (`landing-party/scripts/aim.lua`). The score is the all-ground army's.

| Mix | All-ground army's score | Fights |
|---|---|---|
| prisms / prisms + harriers | -33 | 6 |
| tanks and rifles / with harriers | +61 | 6 |
| tanks / tanks + harriers | -43 | 6 |
| dozers / dozers + harriers | -45 | 6 |
