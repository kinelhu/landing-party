# The arena: who counters whom (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (4536 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

![Counter heatmap](arena/counters.png)

Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, from -100 (wiped out, took nothing) to +100. Rows are grouped by class (below), strongest first within each.

## Classes

A class is a body and a weapon: **small arms** (many light bodies, small shots), **splash** (one weapon that hits several at once: a blast, an arc, a split beam), **armour** (a heavy hull whose flat resistance eats small shots), **air** (fliers: only weapons that can shoot up touch them; `docs/units.md` says which). The class against class score is the mean of its kinds' cells.

| Row against column | small arms | splash | armour | air | anti-air | bred | bred on creep |
|---|---|---|---|---|---|---|---|
| small arms | +0 | -60 | -24 | +65 | +37 | -21 | -44 |
| splash | +60 | +0 | -49 | -81 | +82 | +35 | +61 |
| armour | +24 | +49 | +0 | -23 | +84 | +10 | -7 |
| air | -65 | +81 | +23 | +0 | -75 | +54 | +55 |
| anti-air | -37 | -82 | -84 | +75 | +0 | -44 | -46 |
| bred | +21 | -35 | -10 | -54 | +44 | +0 | -1 |
| bred on creep | +44 | -61 | +7 | -55 | +46 | +1 | +0 |

## Each kind's counters

| Kind (price) | Beats most (its score) | Beaten most by (their score) |
|---|---|---|
| shotgun hand (8) | scrap drone (98), bred small (96), bred spore (93) | bred big (100), bred big (creep) (100), bred behemoth (100) |
| rocket trooper (20) | bomb drone (97), scrap drone (95), laser drone (95) | bred small (83), breacher (74), battle tank (71) |
| slug (30) | scrap drone (93), laser drone (89), bred spore (85) | bred big (creep) (86), bred big (81), shock (73) |
| railgunner (22) | bred small (100), bred medium (100), bred medium (creep) (100) | laser tank (100), scrap drone (100), lightning tank (100) |
| trooper (10) | scrap drone (98), bred small (97), bomb drone (87) | bred big (100), bred big (creep) (100), bred behemoth (100) |
| laser trooper (10) | scrap drone (98), laser drone (89), bred behemoth (83) | lightning tank (96), breacher (90), laser tank (88) |
| heavy laser trooper (16) | scrap drone (96), laser drone (86), bomb drone (71) | bred stomper (89), shock (86), battle tank (86) |
| buggy (15) | scrap drone (96), bomb drone (87), bred small (74) | laser tank (100), lightning tank (100), bred big (100) |
| laser tank (100) | railgunner (100), shock (100), buggy (100) | scrap drone (100), laser drone (100), heavy tank (100) |
| flame trooper (20) | bred small (98), buggy (95), bred medium (95) | scrap drone (100), laser drone (100), scorcher (100) |
| sapper (30) | bred small (98), bred spore (95), bred burster (93) | scrap drone (100), lightning tank (100), laser drone (100) |
| breacher (10) | bred small (100), bred medium (97), buggy (96) | scrap drone (100), laser drone (100), battle tank (100) |
| shock (30) | bred stomper (100), buggy (93), bred small (93) | laser tank (100), scrap drone (100), lightning tank (100) |
| lightning tank (100) | railgunner (100), sapper (100), shock (100) | scrap drone (100), laser drone (100), heavy tank (100) |
| battle tank (60) | railgunner (100), breacher (100), laser tank (100) | scrap drone (100), laser drone (100), shotgun hand (22) |
| heavy tank (95) | railgunner (100), buggy (100), laser tank (100) | scrap drone (100), laser drone (100), flame trooper (66) |
| tank (60) | flak buggy (100), laser tank (93), lightning tank (93) | scrap drone (100), laser drone (100), battle tank (83) |
| dozer (100) | railgunner (100), buggy (100), laser tank (100) | scrap drone (100), laser drone (100), bred stomper (100) |
| walker (100) | railgunner (100), sapper (100), breacher (100) | bred behemoth (100), bred big (creep) (93), bred big (89) |
| scorcher (70) | flame trooper (100), bred small (100), flak buggy (100) | scrap drone (100), bred big (100), bred big (creep) (100) |
| laser drone (70) | railgunner (100), sapper (100), shock (100) | flak buggy (100), anti-air trooper (99), rocket trooper (95) |
| scrap drone (15) | railgunner (100), sapper (100), shock (100) | anti-air trooper (100), flak buggy (100), walker (100) |
| bomb drone (35) | railgunner (65), sapper (64), bred burster (58) | anti-air trooper (100), bred behemoth (100), flak buggy (99) |
| anti-air trooper (18) | bomb drone (100), scrap drone (100), laser drone (99) | bred stomper (100), battle tank (94), bred big (creep) (93) |
| flak buggy (20) | scrap drone (100), laser drone (100), bomb drone (99) | laser tank (100), lightning tank (100), tank (100) |
| bred spore (10) | laser drone (63), scrap drone (52), rocket trooper (11) | laser tank (100), bred behemoth (100), bred stomper (100) |
| bred stomper (150) | railgunner (100), breacher (100), laser tank (100) | shock (100), scrap drone (100), laser drone (100) |
| bred behemoth (200) | shotgun hand (100), bomb drone (100), sapper (100) | laser drone (100), railgunner (95), laser trooper (83) |
| bred big (28) | shotgun hand (100), buggy (100), trooper (100) | railgunner (100), laser tank (100), lightning tank (100) |
| bred burster (40) | flak buggy (60), bred spore (52), laser tank (50) | scrap drone (100), laser drone (100), railgunner (98) |
| bred spitter (9) | dozer (95), bred small (94), buggy (61) | railgunner (100), scrap drone (100), laser drone (100) |
| bred medium (7) | buggy (98), bred small (95), bred spore (85) | railgunner (100), scrap drone (100), laser drone (100) |
| bred small (2) | rocket trooper (83), slug (71), walker (54) | railgunner (100), breacher (100), laser tank (100) |
| bred big (creep) (28) | shotgun hand (100), buggy (100), trooper (100) | railgunner (100), laser tank (100), laser drone (100) |
| bred medium (creep) (7) | buggy (98), bred small (98), flak buggy (96) | railgunner (100), laser drone (100), bred stomper (100) |
| bred spitter (creep) (9) | dozer (92), bred small (86), buggy (68) | railgunner (100), scrap drone (100), laser drone (100) |

## Groups found from the fights alone

Each kind is its row of scores (against every kind and every fixed opponent); kinds are joined by average linkage on the distance between rows, so two kinds land together when they beat and lose to the same things (`scripts/arena_report.py`, scipy). Cut into 7 groups, as many as the hand-made classes:

![Clusters](arena/clusters.png)

| Group | Kinds (hand-made class) |
|---|---|
| 1 | laser tank (splash), flame trooper (splash), sapper (splash), breacher (splash), shock (splash), lightning tank (splash), battle tank (armour), heavy tank (armour), tank (armour), dozer (armour), bred stomper (bred), bred behemoth (bred), bred big (bred), bred burster (bred), bred spitter (bred), bred medium (bred), bred big (creep) (bred on creep), bred medium (creep) (bred on creep), bred spitter (creep) (bred on creep) |
| 2 | shotgun hand (small arms), rocket trooper (small arms), slug (small arms), trooper (small arms), laser trooper (small arms), heavy laser trooper (small arms), buggy (small arms), anti-air trooper (anti-air), flak buggy (anti-air), bred spore (anti-air) |
| 3 | walker (armour), bomb drone (air) |
| 4 | laser drone (air), scrap drone (air) |
| 5 | railgunner (small arms) |
| 6 | scorcher (armour) |
| 7 | bred small (bred) |

## Faction against faction

From the unit matrix, each faction's roster (the kinds it fields from landing or its tree; a kind both corporations field counts for both; Synthexis's breeds on creep too). **Answer**: for each of the other side's kinds, the row's best score against it, averaged: can it answer whatever the other fields? **Coverage**: the share of the other side's kinds it has a counter scoring +50 or more for. **Exposure**: the share of its own kinds the other side has such a counter for. **Breadth**: how many of the groups found from the fights alone (above) its roster spans.

![Factions](arena/factions.png)

| Row against column | Answer | Coverage | Exposure | Their answer | Edge |
|---|---|---|---|---|---|
| Kessler-Hayashi against Grubstake | +90 | 89% | 100% | +93 | -2 |
| Kessler-Hayashi against Synthexis | +100 | 100% | 82% | +78 | +22 |
| Kessler-Hayashi against You | +86 | 80% | 100% | +87 | -1 |
| Grubstake against Kessler-Hayashi | +93 | 100% | 89% | +90 | +2 |
| Grubstake against Synthexis | +86 | 82% | 100% | +93 | -7 |
| Grubstake against You | +90 | 100% | 89% | +86 | +4 |
| Synthexis against Kessler-Hayashi | +78 | 82% | 100% | +100 | -22 |
| Synthexis against Grubstake | +93 | 100% | 82% | +86 | +7 |
| Synthexis against You | +61 | 60% | 100% | +86 | -26 |
| You against Kessler-Hayashi | +87 | 100% | 80% | +86 | +1 |
| You against Grubstake | +86 | 89% | 100% | +90 | -4 |
| You against Synthexis | +86 | 100% | 60% | +61 | +26 |

| Faction | Kinds | Breadth (groups of 7) | Roster |
|---|---|---|---|
| Kessler-Hayashi | 11 | 5 | railgunner, laser trooper, heavy laser trooper, laser tank, shock, lightning tank, heavy tank, tank, walker, laser drone, anti-air trooper |
| Grubstake | 9 | 5 | shotgun hand, slug, buggy, sapper, dozer, scorcher, scrap drone, bomb drone, flak buggy |
| Synthexis | 11 | 3 | bred spore, bred stomper, bred behemoth, bred big, bred burster, bred spitter, bred medium, bred small, bred big (creep), bred medium (creep), bred spitter (creep) |
| You | 5 | 2 | rocket trooper, trooper, flame trooper, breacher, battle tank |

## Mixed arms: does a flier soak a ground army's fire?

A ground army against the same spend with part of it in fliers, both ways round. Ground-only weapons cannot hurt a flier; a unit whose shot is aimed at one is turned to a ground target it can hurt (`landing-party/scripts/aim.lua`). The score is the all-ground army's.

| Mix | All-ground army's score | Fights |
|---|---|---|
| prisms / prisms + harriers | -23 | 6 |
| tanks and rifles / with harriers | +60 | 6 |
| tanks / tanks + harriers | -1 | 6 |
| dozers / dozers + harriers | +53 | 6 |
