# The arena: who counters whom (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (3441 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

![Counter heatmap](arena/counters.png)

Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, from -100 (wiped out, took nothing) to +100. Rows are grouped by class (below), strongest first within each.

## Classes

A class is a body and a weapon: **small arms** (many light bodies, small shots), **splash** (one weapon that hits several at once: a blast, an arc, a split beam), **armour** (a heavy hull whose flat resistance eats small shots), **air** (fliers: only weapons that can shoot up touch them; `docs/units.md` says which). The class against class score is the mean of its kinds' cells.

| Row against column | small arms | splash | armour | air | anti-air | bred | bred on creep |
|---|---|---|---|---|---|---|---|
| small arms | +0 | -51 | -20 | +47 | +48 | -37 | -57 |
| splash | +51 | +0 | -59 | -100 | +86 | +32 | +53 |
| armour | +20 | +59 | +0 | -67 | +82 | +3 | -10 |
| air | -47 | +100 | +67 | +0 | -90 | +100 | +88 |
| anti-air | -48 | -86 | -82 | +90 | +0 | -65 | -92 |
| bred | +37 | -32 | -3 | -100 | +65 | +0 | +12 |
| bred on creep | +57 | -53 | +10 | -88 | +92 | -12 | +0 |

## Each kind's counters

| Kind (price) | Beats most (its score) | Beaten most by (their score) |
|---|---|---|
| rocket trooper (20) | scavenger (95), harrier (95), lightning tank (88) | battle tank (74), breacher (71), slug (60) |
| slug (30) | scavenger (100), harrier (93), railgunner (87) | bred big (creep) (84), heavy tank (80), bred big (77) |
| shotgun hand (8) | bred spore (90), flak buggy (81), walker (78) | scavenger (100), harrier (100), bred big (creep) (100) |
| trooper (10) | harrier (98), scavenger (97), bred spore (80) | bred big (creep) (100), bred big (100), bred medium (creep) (89) |
| laser trooper (10) | scavenger (97), harrier (96), bred spore (74) | tank (86), battle tank (86), bred big (creep) (84) |
| heavy laser trooper (16) | scavenger (96), harrier (96), dozer (69) | bred stomper (94), bred big (creep) (85), battle tank (83) |
| railgunner (22) | bred medium (100), bred medium (creep) (100), bred big (creep) (100) | scavenger (100), harrier (100), laser tank (100) |
| buggy (15) | scavenger (97), harrier (96), bred spore (76) | lightning tank (100), bred big (creep) (100), heavy tank (100) |
| laser tank (100) | railgunner (100), shock (100), flak buggy (100) | scavenger (100), harrier (100), heavy tank (100) |
| lightning tank (100) | railgunner (100), shock (100), sapper (100) | scavenger (100), harrier (100), heavy tank (100) |
| shock (30) | bred stomper (94), buggy (92), bred spore (88) | scavenger (100), harrier (100), laser tank (100) |
| breacher (10) | shotgun hand (95), bred medium (93), buggy (93) | scavenger (100), harrier (100), heavy tank (100) |
| sapper (30) | shotgun hand (93), buggy (93), flak buggy (93) | scavenger (100), harrier (100), lightning tank (100) |
| battle tank (60) | railgunner (100), sapper (100), laser tank (100) | scavenger (100), harrier (100), dozer (56) |
| heavy tank (95) | railgunner (100), laser tank (100), lightning tank (100) | scavenger (100), harrier (100), bred stomper (67) |
| dozer (100) | railgunner (100), shock (100), laser tank (100) | scavenger (100), harrier (100), bred stomper (100) |
| tank (60) | laser tank (100), flak buggy (100), bred stomper (97) | scavenger (100), harrier (100), battle tank (79) |
| walker (100) | railgunner (100), sapper (100), scavenger (100) | bred big (creep) (92), bred big (90), bred medium (creep) (80) |
| scorcher (70) | flak buggy (100), laser trooper (83), buggy (83) | scavenger (100), harrier (100), bred big (creep) (100) |
| harrier (40) | railgunner (100), shotgun hand (100), shock (100) | flak buggy (100), walker (100), anti-air trooper (99) |
| scavenger (50) | railgunner (100), shotgun hand (100), shock (100) | slug (100), flak buggy (100), walker (100) |
| anti-air trooper (18) | harrier (99), scavenger (98), bred spore (93) | bred stomper (100), bred big (creep) (94), walker (92) |
| flak buggy (20) | scavenger (100), harrier (100), bred spore (90) | laser tank (100), lightning tank (100), heavy tank (100) |
| bred spore (10) | scavenger (83), harrier (58), heavy tank (-31) | railgunner (100), bred stomper (100), walker (100) |
| bred stomper (150) | railgunner (100), anti-air trooper (100), laser tank (100) | scavenger (100), harrier (100), battle tank (100) |
| bred burster (70) | buggy (100), scorcher (100), shotgun hand (83) | railgunner (100), scavenger (100), harrier (100) |
| bred big (28) | shotgun hand (100), trooper (100), buggy (100) | railgunner (100), scavenger (100), harrier (100) |
| bred medium (7) | buggy (98), bred spore (91), scorcher (86) | railgunner (100), scavenger (100), harrier (100) |
| bred spitter (9) | dozer (93), bred medium (57), heavy tank (55) | railgunner (100), scavenger (100), harrier (100) |
| bred big (creep) (28) | shotgun hand (100), trooper (100), buggy (100) | railgunner (100), scavenger (100), laser tank (96) |
| bred medium (creep) (7) | buggy (98), scorcher (97), flak buggy (96) | railgunner (100), scavenger (100), harrier (100) |

## Groups found from the fights alone

Each kind is its row of scores (against every kind and every fixed opponent); kinds are joined by average linkage on the distance between rows, so two kinds land together when they beat and lose to the same things (`scripts/arena_report.py`, scipy). Cut into 7 groups, as many as the hand-made classes:

![Clusters](arena/clusters.png)

| Group | Kinds (hand-made class) |
|---|---|
| 1 | laser tank (splash), lightning tank (splash), shock (splash), breacher (splash), sapper (splash), battle tank (armour), heavy tank (armour), dozer (armour), tank (armour), bred stomper (bred), bred burster (bred), bred big (bred), bred medium (bred), bred big (creep) (bred on creep), bred medium (creep) (bred on creep) |
| 2 | rocket trooper (small arms), slug (small arms), shotgun hand (small arms), trooper (small arms), laser trooper (small arms), heavy laser trooper (small arms), buggy (small arms), anti-air trooper (anti-air), flak buggy (anti-air), bred spore (anti-air) |
| 3 | harrier (air), scavenger (air) |
| 4 | railgunner (small arms) |
| 5 | walker (armour) |
| 6 | scorcher (armour) |
| 7 | bred spitter (bred) |

## Faction against faction

From the unit matrix, each faction's roster (the kinds it fields from landing or its tree; a kind both corporations field counts for both; Synthexis's breeds on creep too). **Answer**: for each of the other side's kinds, the row's best score against it, averaged: can it answer whatever the other fields? **Coverage**: the share of the other side's kinds it has a counter scoring +50 or more for. **Exposure**: the share of its own kinds the other side has such a counter for. **Breadth**: how many of the groups found from the fights alone (above) its roster spans.

![Factions](arena/factions.png)

| Row against column | Answer | Coverage | Exposure | Their answer | Edge |
|---|---|---|---|---|---|
| Kessler-Hayashi against Grubstake | +92 | 100% | 100% | +91 | +1 |
| Kessler-Hayashi against Synthexis | +100 | 100% | 70% | +71 | +29 |
| Kessler-Hayashi against You | +66 | 50% | 90% | +80 | -14 |
| Grubstake against Kessler-Hayashi | +91 | 100% | 100% | +92 | -1 |
| Grubstake against Synthexis | +99 | 100% | 100% | +87 | +12 |
| Grubstake against You | +83 | 100% | 89% | +86 | -3 |
| Synthexis against Kessler-Hayashi | +71 | 70% | 100% | +100 | -29 |
| Synthexis against Grubstake | +87 | 100% | 100% | +99 | -12 |
| Synthexis against You | +73 | 75% | 88% | +78 | -5 |
| You against Kessler-Hayashi | +80 | 90% | 50% | +66 | +14 |
| You against Grubstake | +86 | 89% | 100% | +83 | +3 |
| You against Synthexis | +78 | 88% | 75% | +73 | +5 |

| Faction | Kinds | Breadth (groups of 7) | Roster |
|---|---|---|---|
| Kessler-Hayashi | 10 | 4 | laser trooper, heavy laser trooper, railgunner, laser tank, lightning tank, shock, heavy tank, tank, walker, anti-air trooper |
| Grubstake | 9 | 4 | slug, shotgun hand, buggy, sapper, dozer, scorcher, harrier, scavenger, flak buggy |
| Synthexis | 8 | 3 | bred spore, bred stomper, bred burster, bred big, bred medium, bred spitter, bred big (creep), bred medium (creep) |
| You | 4 | 2 | rocket trooper, trooper, breacher, battle tank |

## Mixed arms: does a flier soak a ground army's fire?

A ground army against the same spend with part of it in fliers, both ways round. Ground-only weapons cannot hurt a flier; a unit whose shot is aimed at one is turned to a ground target it can hurt (`landing-party/scripts/aim.lua`). The score is the all-ground army's.

| Mix | All-ground army's score | Fights |
|---|---|---|
| prisms / prisms + harriers | -33 | 6 |
| tanks and rifles / with harriers | +62 | 6 |
| tanks / tanks + harriers | -33 | 6 |
| dozers / dozers + harriers | -41 | 6 |
