# The arena: who counters whom (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (4644 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

![Counter heatmap](arena/counters.png)

Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, from -100 (wiped out, took nothing) to +100. Rows are grouped by class (below), strongest first within each.

## Classes

A class is a body and a weapon: **small arms** (many light bodies, small shots), **splash** (one weapon that hits several at once: a blast, an arc, a split beam), **armour** (a heavy hull whose flat resistance eats small shots), **air** (fliers: only weapons that can shoot up touch them; `docs/units.md` says which). The class against class score is the mean of its kinds' cells.

| Row against column | small arms | splash | armour | air | anti-air | bred | bred on creep |
|---|---|---|---|---|---|---|---|
| small arms | +0 | -60 | -17 | +70 | +13 | -27 | -52 |
| splash | +60 | +0 | -64 | -80 | +75 | +37 | +61 |
| armour | +17 | +64 | +0 | -24 | +78 | +7 | -2 |
| air | -70 | +80 | +24 | +0 | -87 | +54 | +50 |
| anti-air | -13 | -75 | -78 | +87 | +0 | -38 | -51 |
| bred | +27 | -37 | -7 | -54 | +38 | +0 | -13 |
| bred on creep | +52 | -61 | +2 | -50 | +51 | +13 | +0 |

## Each kind's counters

| Kind (price) | Beats most (its score) | Beaten most by (their score) |
|---|---|---|
| rocket trooper (20) | scrap drone (100), bomb drone (99), laser drone (98) | bred small (82), battle tank (76), breacher (72) |
| shotgun hand (8) | scrap drone (100), railgunner (98), bred small (97) | bred big (100), bred big (creep) (100), bred behemoth (100) |
| slug (30) | scrap drone (100), bomb drone (99), laser drone (98) | bred big (creep) (89), shock (88), lightning tank (88) |
| heavy laser trooper (14) | scrap drone (100), laser drone (96), laser trooper (94) | shock (81), bred stomper (78), breacher (77) |
| trooper (10) | scrap drone (99), bred small (96), railgunner (95) | bred big (100), bred big (creep) (100), bred behemoth (100) |
| buggy (15) | scrap drone (100), laser trooper (93), bomb drone (93) | laser tank (100), lightning tank (100), scorcher (100) |
| railgunner (22) | bred spore (99), bred spitter (99), bred small (98) | scorcher (100), scrap drone (100), heavy tank (100) |
| laser trooper (10) | scrap drone (95), laser drone (78), railgunner (74) | laser tank (100), lightning tank (100), scorcher (100) |
| shock (30) | bred stomper (100), buggy (99), laser trooper (93) | lightning tank (100), scorcher (100), scrap drone (100) |
| sapper (30) | bred small (95), bred spore (94), laser trooper (93) | scorcher (100), scrap drone (100), laser drone (100) |
| breacher (10) | bred small (100), laser trooper (98), railgunner (97) | scorcher (100), scrap drone (100), tank (100) |
| lightning tank (115) | laser trooper (100), shock (100), flame trooper (100) | scrap drone (100), heavy tank (100), laser drone (100) |
| laser tank (115) | laser trooper (100), flame trooper (100), buggy (100) | scrap drone (100), heavy tank (100), bred stomper (100) |
| flame trooper (20) | bred small (97), laser trooper (95), bred medium (95) | laser tank (100), lightning tank (100), scorcher (100) |
| battle tank (60) | laser trooper (100), railgunner (100), breacher (100) | scrap drone (100), laser drone (100), shotgun hand (24) |
| walker (100) | laser trooper (100), railgunner (100), sapper (100) | bred behemoth (100), bred big (creep) (93), bred big (92) |
| scorcher (100) | laser trooper (100), railgunner (100), sapper (100) | scrap drone (100), heavy tank (100), bred stomper (100) |
| tank (65) | laser trooper (100), breacher (100), flame trooper (100) | scrap drone (100), laser drone (100), battle tank (87) |
| dozer (120) | laser trooper (100), railgunner (100), shock (100) | scrap drone (100), bred stomper (100), laser drone (100) |
| heavy tank (120) | laser trooper (100), railgunner (100), shock (100) | scrap drone (100), laser drone (100), battle tank (78) |
| laser drone (70) | railgunner (100), sapper (100), breacher (100) | flak buggy (100), anti-air trooper (99), slug (98) |
| scrap drone (15) | railgunner (100), sapper (100), breacher (100) | shotgun hand (100), heavy laser trooper (100), slug (100) |
| bomb drone (35) | sapper (65), bred burster (62), railgunner (58) | bred behemoth (100), rocket trooper (99), slug (99) |
| anti-air trooper (18) | scrap drone (100), laser drone (99), laser trooper (93) | bred stomper (100), battle tank (97), bred big (creep) (94) |
| flak buggy (20) | scrap drone (100), laser drone (100), bomb drone (98) | scorcher (100), heavy tank (100), tank (100) |
| bred spore (10) | laser drone (83), scrap drone (82), laser trooper (80) | bred stomper (100), bred behemoth (100), walker (100) |
| bred stomper (150) | laser trooper (100), railgunner (100), anti-air trooper (100) | shock (100), scrap drone (100), laser drone (100) |
| bred behemoth (200) | shotgun hand (100), railgunner (100), sapper (100) | laser drone (100), dozer (87), battle tank (80) |
| bred big (28) | shotgun hand (100), trooper (100), buggy (100) | lightning tank (100), laser drone (100), flame trooper (95) |
| bred spitter (9) | dozer (95), laser trooper (94), bred small (93) | scrap drone (100), bred stomper (100), laser drone (100) |
| bred medium (7) | buggy (98), bred small (95), laser trooper (94) | scrap drone (100), bred stomper (100), laser drone (100) |
| bred burster (40) | laser tank (21), bred stomper (15), lightning tank (12) | scrap drone (100), laser drone (100), sapper (86) |
| bred small (2) | rocket trooper (82), laser trooper (76), slug (70) | breacher (100), scorcher (100), scrap drone (100) |
| bred big (creep) (28) | shotgun hand (100), trooper (100), buggy (100) | laser drone (100), lightning tank (96), flame trooper (94) |
| bred medium (creep) (7) | buggy (98), laser trooper (98), bred small (97) | laser drone (100), flame trooper (95), bred stomper (94) |
| bred spitter (creep) (9) | laser trooper (98), dozer (91), bred small (85) | scrap drone (100), bred stomper (100), laser drone (100) |

## Groups found from the fights alone

Each kind is its row of scores (against every kind and every fixed opponent); kinds are joined by average linkage on the distance between rows, so two kinds land together when they beat and lose to the same things (`scripts/arena_report.py`, scipy). Cut into 7 groups, as many as the hand-made classes:

![Clusters](arena/clusters.png)

| Group | Kinds (hand-made class) |
|---|---|
| 1 | lightning tank (splash), laser tank (splash), battle tank (armour), scorcher (armour), tank (armour), dozer (armour), heavy tank (armour), bred stomper (bred), bred behemoth (bred) |
| 2 | shock (splash), sapper (splash), breacher (splash), flame trooper (splash), bred big (bred), bred medium (bred), bred big (creep) (bred on creep), bred medium (creep) (bred on creep) |
| 3 | rocket trooper (small arms), shotgun hand (small arms), slug (small arms), heavy laser trooper (small arms), trooper (small arms), walker (armour) |
| 4 | buggy (small arms), laser trooper (small arms), anti-air trooper (anti-air), flak buggy (anti-air), bred spore (anti-air) |
| 5 | bred spitter (bred), bred burster (bred), bred small (bred), bred spitter (creep) (bred on creep) |
| 6 | railgunner (small arms), bomb drone (air) |
| 7 | laser drone (air), scrap drone (air) |

## Faction against faction

From the unit matrix, each faction's roster (the kinds it fields from landing or its tree; a kind both corporations field counts for both; Synthexis's breeds on creep too). **Answer**: for each of the other side's kinds, the row's best score against it, averaged: can it answer whatever the other fields? **Coverage**: the share of the other side's kinds it has a counter scoring +50 or more for. **Exposure**: the share of its own kinds the other side has such a counter for. **Breadth**: how many of the groups found from the fights alone (above) its roster spans.

![Factions](arena/factions.png)

| Row against column | Answer | Coverage | Exposure | Their answer | Edge |
|---|---|---|---|---|---|
| Kessler-Hayashi against Grubstake | +96 | 100% | 100% | +95 | +1 |
| Kessler-Hayashi against Synthexis | +100 | 100% | 100% | +85 | +15 |
| Kessler-Hayashi against You | +76 | 80% | 100% | +92 | -16 |
| Grubstake against Kessler-Hayashi | +95 | 100% | 100% | +96 | -1 |
| Grubstake against Synthexis | +87 | 91% | 100% | +97 | -10 |
| Grubstake against You | +91 | 100% | 89% | +88 | +3 |
| Synthexis against Kessler-Hayashi | +85 | 100% | 100% | +100 | -15 |
| Synthexis against Grubstake | +97 | 100% | 91% | +87 | +10 |
| Synthexis against You | +53 | 60% | 100% | +88 | -35 |
| You against Kessler-Hayashi | +92 | 100% | 80% | +76 | +16 |
| You against Grubstake | +88 | 89% | 100% | +91 | -3 |
| You against Synthexis | +88 | 100% | 60% | +53 | +35 |

| Faction | Kinds | Breadth (groups of 7) | Roster |
|---|---|---|---|
| Kessler-Hayashi | 10 | 6 | heavy laser trooper, railgunner, laser trooper, shock, lightning tank, laser tank, tank, heavy tank, laser drone, anti-air trooper |
| Grubstake | 9 | 6 | shotgun hand, slug, buggy, sapper, scorcher, dozer, scrap drone, bomb drone, flak buggy |
| Synthexis | 11 | 4 | bred spore, bred stomper, bred behemoth, bred big, bred spitter, bred medium, bred burster, bred small, bred big (creep), bred medium (creep), bred spitter (creep) |
| You | 5 | 3 | rocket trooper, trooper, breacher, flame trooper, battle tank |

## Mixed arms: does a flier soak a ground army's fire?

A ground army against the same spend with part of it in fliers, both ways round. Ground-only weapons cannot hurt a flier; a unit whose shot is aimed at one is turned to a ground target it can hurt (`landing-party/scripts/aim.lua`). The score is the all-ground army's.

| Mix | All-ground army's score | Fights |
|---|---|---|
| prisms / prisms + harriers | -36 | 6 |
| tanks and rifles / with harriers | +42 | 6 |
| tanks / tanks + harriers | -5 | 6 |
| dozers / dozers + harriers | +61 | 6 |

## The breach: bursters among other biters at a wall

The same spend sent at gun turrets behind a wall two deep (`tests/lp-arena/batch.lua`, BREACH), as plain biters and with part of it in bursters. A burster bursts where it dies: alone it is shot short of the wall; among others it reaches it. Ranges over the rounds.

| Wave | Spend | Won | Turrets broken | Wall pieces broken | Units lost |
|---|---|---|---|---|---|
| 40 medium | 280 | 0 of 3 | 0 | 0 to 1 | 40 of 40 |
| 34 medium + 1 burster | 278 | 0 of 3 | 0 to 1 | 8 to 10 | 35 of 35 |
| 29 medium + 2 bursters | 283 | 0 of 3 | 0 to 3 | 9 to 14 | 31 of 31 |
| 23 medium + 3 bursters | 281 | 0 of 3 | 1 to 2 | 13 to 17 | 26 of 26 |
| 17 medium + 4 bursters | 279 | 0 of 3 | 0 to 3 | 12 to 17 | 21 of 21 |
| 7 bursters | 280 | 0 of 3 | 0 to 3 | 16 | 7 of 7 |
| 10 big | 280 | 3 of 3 | 10 | 5 to 9 | 1 to 2 of 10 |
| 6 big + 3 bursters | 288 | 3 of 3 | 10 | 17 to 22 | 4 of 9 |
