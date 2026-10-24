# The arena: who counters whom (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (4536 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

![Counter heatmap](arena/counters.png)

Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, from -100 (wiped out, took nothing) to +100. Rows are grouped by class (below), strongest first within each.

## Classes

A class is a body and a weapon: **small arms** (many light bodies, small shots), **splash** (one weapon that hits several at once: a blast, an arc, a split beam), **armour** (a heavy hull whose flat resistance eats small shots), **air** (fliers: only weapons that can shoot up touch them; `docs/units.md` says which). The class against class score is the mean of its kinds' cells.

| Row against column | small arms | splash | armour | air | anti-air | bred | bred on creep |
|---|---|---|---|---|---|---|---|
| small arms | +0 | -60 | -25 | +66 | +33 | -23 | -45 |
| splash | +60 | +0 | -46 | -81 | +81 | +32 | +58 |
| armour | +25 | +46 | +0 | -23 | +84 | +11 | -12 |
| air | -66 | +81 | +23 | +0 | -77 | +54 | +56 |
| anti-air | -33 | -81 | -84 | +77 | +0 | -47 | -49 |
| bred | +23 | -32 | -11 | -54 | +47 | +0 | -2 |
| bred on creep | +45 | -58 | +12 | -56 | +49 | +2 | +0 |

## Each kind's counters

| Kind (price) | Beats most (its score) | Beaten most by (their score) |
|---|---|---|
| shotgun hand (8) | scrap drone (98), bred small (98), bred spore (93) | bred big (creep) (100), bred behemoth (100), bred big (98) |
| rocket trooper (20) | scrap drone (95), laser drone (95), bomb drone (94) | bred small (82), battle tank (79), breacher (75) |
| slug (30) | bomb drone (94), scrap drone (93), railgunner (89) | laser tank (89), bred big (creep) (87), bred big (81) |
| railgunner (22) | bred medium (100), bred medium (creep) (100), bred small (100) | laser tank (100), lightning tank (100), heavy tank (100) |
| trooper (10) | bomb drone (99), scrap drone (98), bred small (97) | bred big (100), bred big (creep) (100), bred behemoth (100) |
| laser trooper (10) | scrap drone (98), laser drone (90), bred behemoth (84) | lightning tank (96), laser tank (92), shock (90) |
| heavy laser trooper (16) | scrap drone (96), laser drone (84), bomb drone (76) | bred big (creep) (89), tank (86), breacher (82) |
| buggy (15) | scrap drone (96), bred small (86), bomb drone (76) | laser tank (100), lightning tank (100), heavy tank (100) |
| laser tank (100) | railgunner (100), shock (100), buggy (100) | heavy tank (100), scrap drone (100), laser drone (100) |
| flame trooper (20) | bred small (97), bred medium (95), bred medium (creep) (95) | scrap drone (100), laser drone (100), scorcher (100) |
| lightning tank (100) | railgunner (100), shock (100), sapper (100) | heavy tank (100), scrap drone (100), laser drone (100) |
| sapper (30) | bred small (96), buggy (93), flak buggy (93) | lightning tank (100), scrap drone (100), laser drone (100) |
| shock (30) | bred stomper (100), buggy (93), bred small (93) | laser tank (100), lightning tank (100), scrap drone (100) |
| breacher (10) | bred small (100), buggy (97), bred medium (96) | heavy tank (100), scrap drone (100), laser drone (100) |
| battle tank (60) | railgunner (100), sapper (100), breacher (100) | scrap drone (100), laser drone (100), dozer (20) |
| heavy tank (95) | railgunner (100), breacher (100), buggy (100) | scrap drone (100), laser drone (100), flame trooper (70) |
| tank (60) | flak buggy (100), bred stomper (97), breacher (90) | scrap drone (100), laser drone (100), battle tank (79) |
| dozer (100) | railgunner (100), shock (100), buggy (100) | scrap drone (100), laser drone (100), bred stomper (100) |
| walker (100) | railgunner (100), sapper (100), breacher (100) | bred behemoth (100), bred big (creep) (93), bred big (92) |
| scorcher (70) | flame trooper (100), bred small (100), flak buggy (100) | heavy tank (100), bred big (100), bred big (creep) (100) |
| laser drone (70) | railgunner (100), shock (100), sapper (100) | flak buggy (100), anti-air trooper (99), rocket trooper (95) |
| scrap drone (15) | railgunner (100), shock (100), sapper (100) | anti-air trooper (100), flak buggy (100), walker (100) |
| bomb drone (35) | railgunner (65), sapper (65), shock (57) | anti-air trooper (100), flak buggy (100), bred behemoth (100) |
| anti-air trooper (18) | bomb drone (100), scrap drone (100), laser drone (99) | bred stomper (100), walker (96), bred big (creep) (94) |
| flak buggy (20) | bomb drone (100), scrap drone (100), laser drone (100) | laser tank (100), lightning tank (100), heavy tank (100) |
| bred spore (10) | laser drone (68), scrap drone (57), rocket trooper (-12) | railgunner (100), laser tank (100), bred stomper (100) |
| bred stomper (150) | railgunner (100), anti-air trooper (100), breacher (100) | shock (100), scrap drone (100), laser drone (100) |
| bred behemoth (200) | shotgun hand (100), bomb drone (100), shock (100) | laser drone (100), railgunner (94), dozer (88) |
| bred burster (70) | buggy (100), scorcher (100), shotgun hand (83) | railgunner (100), scrap drone (100), laser drone (100) |
| bred big (28) | buggy (100), trooper (100), scorcher (100) | railgunner (100), laser tank (100), lightning tank (100) |
| bred spitter (9) | dozer (94), bred small (89), bred medium (66) | railgunner (100), scrap drone (100), laser drone (100) |
| bred medium (7) | buggy (98), bred small (98), bred spore (88) | railgunner (100), laser tank (100), scrap drone (100) |
| bred small (2) | rocket trooper (82), slug (69), walker (54) | railgunner (100), breacher (100), scrap drone (100) |
| bred big (creep) (28) | shotgun hand (100), buggy (100), trooper (100) | railgunner (100), laser tank (100), laser drone (100) |
| bred medium (creep) (7) | buggy (98), bred small (98), flak buggy (96) | railgunner (100), laser tank (100), lightning tank (100) |
| bred spitter (creep) (9) | bred small (94), dozer (94), buggy (72) | railgunner (100), scrap drone (100), laser drone (100) |

## Groups found from the fights alone

Each kind is its row of scores (against every kind and every fixed opponent); kinds are joined by average linkage on the distance between rows, so two kinds land together when they beat and lose to the same things (`scripts/arena_report.py`, scipy). Cut into 7 groups, as many as the hand-made classes:

![Clusters](arena/clusters.png)

| Group | Kinds (hand-made class) |
|---|---|
| 1 | laser tank (splash), flame trooper (splash), lightning tank (splash), sapper (splash), shock (splash), breacher (splash), battle tank (armour), heavy tank (armour), tank (armour), dozer (armour), bred stomper (bred), bred behemoth (bred), bred burster (bred), bred big (bred), bred medium (bred), bred big (creep) (bred on creep), bred medium (creep) (bred on creep) |
| 2 | shotgun hand (small arms), rocket trooper (small arms), slug (small arms), trooper (small arms), laser trooper (small arms), heavy laser trooper (small arms), buggy (small arms), anti-air trooper (anti-air), flak buggy (anti-air), bred spore (anti-air) |
| 3 | bred spitter (bred), bred small (bred), bred spitter (creep) (bred on creep) |
| 4 | walker (armour), bomb drone (air) |
| 5 | laser drone (air), scrap drone (air) |
| 6 | railgunner (small arms) |
| 7 | scorcher (armour) |

## Faction against faction

From the unit matrix, each faction's roster (the kinds it fields from landing or its tree; a kind both corporations field counts for both; Synthexis's breeds on creep too). **Answer**: for each of the other side's kinds, the row's best score against it, averaged: can it answer whatever the other fields? **Coverage**: the share of the other side's kinds it has a counter scoring +50 or more for. **Exposure**: the share of its own kinds the other side has such a counter for. **Breadth**: how many of the groups found from the fights alone (above) its roster spans.

![Factions](arena/factions.png)

| Row against column | Answer | Coverage | Exposure | Their answer | Edge |
|---|---|---|---|---|---|
| Kessler-Hayashi against Grubstake | +93 | 100% | 100% | +93 | +0 |
| Kessler-Hayashi against Synthexis | +100 | 100% | 82% | +81 | +19 |
| Kessler-Hayashi against You | +85 | 80% | 100% | +85 | -1 |
| Grubstake against Kessler-Hayashi | +93 | 100% | 100% | +93 | +0 |
| Grubstake against Synthexis | +85 | 91% | 100% | +94 | -9 |
| Grubstake against You | +91 | 100% | 89% | +88 | +4 |
| Synthexis against Kessler-Hayashi | +81 | 82% | 100% | +100 | -19 |
| Synthexis against Grubstake | +94 | 100% | 91% | +85 | +9 |
| Synthexis against You | +55 | 60% | 91% | +85 | -30 |
| You against Kessler-Hayashi | +85 | 100% | 80% | +85 | +1 |
| You against Grubstake | +88 | 89% | 100% | +91 | -4 |
| You against Synthexis | +85 | 91% | 60% | +55 | +30 |

| Faction | Kinds | Breadth (groups of 7) | Roster |
|---|---|---|---|
| Kessler-Hayashi | 11 | 5 | railgunner, laser trooper, heavy laser trooper, laser tank, lightning tank, shock, heavy tank, tank, walker, laser drone, anti-air trooper |
| Grubstake | 9 | 5 | shotgun hand, slug, buggy, sapper, dozer, scorcher, scrap drone, bomb drone, flak buggy |
| Synthexis | 11 | 3 | bred spore, bred stomper, bred behemoth, bred burster, bred big, bred spitter, bred medium, bred small, bred big (creep), bred medium (creep), bred spitter (creep) |
| You | 5 | 2 | rocket trooper, trooper, flame trooper, breacher, battle tank |

## Mixed arms: does a flier soak a ground army's fire?

A ground army against the same spend with part of it in fliers, both ways round. Ground-only weapons cannot hurt a flier; a unit whose shot is aimed at one is turned to a ground target it can hurt (`landing-party/scripts/aim.lua`). The score is the all-ground army's.

| Mix | All-ground army's score | Fights |
|---|---|---|
| prisms / prisms + harriers | -23 | 6 |
| tanks and rifles / with harriers | +58 | 6 |
| dozers / dozers + harriers | +49 | 6 |
| tanks / tanks + harriers | -15 | 6 |
