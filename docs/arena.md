# The arena: who counters whom (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (4536 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

![Counter heatmap](arena/counters.png)

Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, from -100 (wiped out, took nothing) to +100. Rows are grouped by class (below), strongest first within each.

## Classes

A class is a body and a weapon: **small arms** (many light bodies, small shots), **splash** (one weapon that hits several at once: a blast, an arc, a split beam), **armour** (a heavy hull whose flat resistance eats small shots), **air** (fliers: only weapons that can shoot up touch them; `docs/units.md` says which). The class against class score is the mean of its kinds' cells.

| Row against column | small arms | splash | armour | air | anti-air | bred | bred on creep |
|---|---|---|---|---|---|---|---|
| small arms | +0 | -65 | -27 | +66 | +29 | -28 | -51 |
| splash | +65 | +0 | -52 | -81 | +79 | +34 | +60 |
| armour | +27 | +52 | +0 | -24 | +82 | +9 | -14 |
| air | -66 | +81 | +24 | +0 | -75 | +55 | +56 |
| anti-air | -29 | -79 | -82 | +75 | +0 | -46 | -48 |
| bred | +28 | -34 | -9 | -55 | +46 | +0 | -6 |
| bred on creep | +51 | -60 | +14 | -56 | +48 | +6 | +0 |

## Each kind's counters

| Kind (price) | Beats most (its score) | Beaten most by (their score) |
|---|---|---|
| shotgun hand (8) | scrap drone (98), railgunner (98), bred small (97) | bred big (100), bred big (creep) (100), bred behemoth (100) |
| rocket trooper (20) | bomb drone (96), scrap drone (95), laser drone (94) | bred small (83), breacher (78), battle tank (76) |
| slug (30) | bomb drone (95), railgunner (94), scrap drone (93) | bred big (creep) (84), laser tank (83), heavy tank (80) |
| trooper (10) | scrap drone (98), bred small (97), railgunner (94) | bred big (100), bred big (creep) (100), bred behemoth (100) |
| laser trooper (10) | scrap drone (98), railgunner (95), laser drone (89) | lightning tank (96), shock (89), breacher (89) |
| heavy laser trooper (16) | scrap drone (96), railgunner (90), laser drone (86) | bred stomper (94), battle tank (86), bred big (creep) (85) |
| buggy (15) | scrap drone (96), railgunner (92), bred small (79) | laser tank (100), lightning tank (100), bred big (100) |
| railgunner (22) | bred small (100), bred spitter (creep) (100), bred spore (99) | laser tank (100), lightning tank (100), scrap drone (100) |
| laser tank (100) | railgunner (100), shock (100), buggy (100) | scrap drone (100), laser drone (100), heavy tank (100) |
| flame trooper (20) | bred small (98), bred medium (95), bred medium (creep) (95) | scrap drone (100), laser drone (100), scorcher (100) |
| sapper (30) | bred small (95), bred spore (95), buggy (93) | lightning tank (100), scrap drone (100), laser drone (100) |
| lightning tank (100) | railgunner (100), sapper (100), shock (100) | scrap drone (100), laser drone (100), heavy tank (100) |
| breacher (10) | bred small (100), bred medium (97), railgunner (97) | scrap drone (100), laser drone (100), heavy tank (100) |
| shock (30) | bred stomper (100), railgunner (93), buggy (93) | laser tank (100), lightning tank (100), scrap drone (100) |
| battle tank (60) | railgunner (100), laser tank (100), lightning tank (100) | scrap drone (100), laser drone (100), dozer (43) |
| heavy tank (95) | railgunner (100), buggy (100), laser tank (100) | scrap drone (100), laser drone (100), flame trooper (63) |
| tank (60) | flak buggy (100), railgunner (95), buggy (95) | scrap drone (100), laser drone (100), battle tank (86) |
| dozer (100) | railgunner (100), shock (100), buggy (100) | scrap drone (100), laser drone (100), bred stomper (100) |
| walker (100) | railgunner (100), sapper (100), breacher (100) | bred behemoth (100), bred big (creep) (93), bred big (90) |
| scorcher (70) | flame trooper (100), flak buggy (100), railgunner (97) | scrap drone (100), bred big (100), bred big (creep) (100) |
| laser drone (70) | railgunner (100), sapper (100), shock (100) | flak buggy (100), anti-air trooper (99), rocket trooper (94) |
| scrap drone (15) | railgunner (100), sapper (100), shock (100) | anti-air trooper (100), flak buggy (100), walker (100) |
| bomb drone (35) | railgunner (62), sapper (62), bred burster (60) | flak buggy (100), bred behemoth (100), anti-air trooper (97) |
| anti-air trooper (18) | scrap drone (100), laser drone (99), bomb drone (97) | bred stomper (100), battle tank (94), bred big (creep) (93) |
| flak buggy (20) | bomb drone (100), scrap drone (100), laser drone (100) | laser tank (100), lightning tank (100), tank (100) |
| bred spore (10) | laser drone (70), scrap drone (50), rocket trooper (6) | laser tank (100), bred stomper (100), bred behemoth (100) |
| bred behemoth (200) | shotgun hand (100), bomb drone (100), railgunner (100) | laser drone (100), laser trooper (82), battle tank (77) |
| bred stomper (150) | railgunner (100), anti-air trooper (100), laser tank (100) | shock (100), scrap drone (100), laser drone (100) |
| bred big (28) | shotgun hand (100), buggy (100), trooper (100) | laser tank (100), lightning tank (100), laser drone (100) |
| bred burster (40) | flak buggy (62), bred spore (53), bred big (53) | scrap drone (100), laser drone (100), sapper (90) |
| bred spitter (9) | dozer (96), bred small (89), bred medium (62) | scrap drone (100), laser drone (100), bred stomper (100) |
| bred medium (7) | buggy (98), bred small (95), bred spore (93) | scrap drone (100), laser drone (100), bred stomper (100) |
| bred small (2) | rocket trooper (83), slug (72), walker (51) | railgunner (100), laser tank (100), breacher (100) |
| bred big (creep) (28) | shotgun hand (100), buggy (100), trooper (100) | laser tank (100), laser drone (100), lightning tank (96) |
| bred medium (creep) (7) | buggy (98), bred small (98), flak buggy (97) | laser tank (100), laser drone (100), bred stomper (100) |
| bred spitter (creep) (9) | bred small (95), dozer (94), laser trooper (70) | railgunner (100), scrap drone (100), laser drone (100) |

## Groups found from the fights alone

Each kind is its row of scores (against every kind and every fixed opponent); kinds are joined by average linkage on the distance between rows, so two kinds land together when they beat and lose to the same things (`scripts/arena_report.py`, scipy). Cut into 7 groups, as many as the hand-made classes:

![Clusters](arena/clusters.png)

| Group | Kinds (hand-made class) |
|---|---|
| 1 | laser tank (splash), flame trooper (splash), sapper (splash), lightning tank (splash), breacher (splash), shock (splash), bred stomper (bred), bred big (bred), bred burster (bred), bred spitter (bred), bred medium (bred), bred big (creep) (bred on creep), bred medium (creep) (bred on creep), bred spitter (creep) (bred on creep) |
| 2 | shotgun hand (small arms), rocket trooper (small arms), slug (small arms), trooper (small arms), laser trooper (small arms), heavy laser trooper (small arms), buggy (small arms), anti-air trooper (anti-air), flak buggy (anti-air), bred spore (anti-air), bred small (bred) |
| 3 | battle tank (armour), heavy tank (armour), tank (armour), dozer (armour), bred behemoth (bred) |
| 4 | railgunner (small arms), bomb drone (air) |
| 5 | laser drone (air), scrap drone (air) |
| 6 | walker (armour) |
| 7 | scorcher (armour) |

## Faction against faction

From the unit matrix, each faction's roster (the kinds it fields from landing or its tree; a kind both corporations field counts for both; Synthexis's breeds on creep too). **Answer**: for each of the other side's kinds, the row's best score against it, averaged: can it answer whatever the other fields? **Coverage**: the share of the other side's kinds it has a counter scoring +50 or more for. **Exposure**: the share of its own kinds the other side has such a counter for. **Breadth**: how many of the groups found from the fights alone (above) its roster spans.

![Factions](arena/factions.png)

| Row against column | Answer | Coverage | Exposure | Their answer | Edge |
|---|---|---|---|---|---|
| Kessler-Hayashi against Grubstake | +92 | 100% | 100% | +93 | -1 |
| Kessler-Hayashi against Synthexis | +100 | 100% | 82% | +82 | +18 |
| Kessler-Hayashi against You | +90 | 100% | 100% | +87 | +3 |
| Grubstake against Kessler-Hayashi | +93 | 100% | 100% | +92 | +1 |
| Grubstake against Synthexis | +82 | 82% | 100% | +93 | -11 |
| Grubstake against You | +91 | 100% | 89% | +87 | +4 |
| Synthexis against Kessler-Hayashi | +82 | 82% | 100% | +100 | -18 |
| Synthexis against Grubstake | +93 | 100% | 82% | +82 | +11 |
| Synthexis against You | +62 | 60% | 100% | +88 | -26 |
| You against Kessler-Hayashi | +87 | 100% | 100% | +90 | -3 |
| You against Grubstake | +87 | 89% | 100% | +91 | -4 |
| You against Synthexis | +88 | 100% | 60% | +62 | +26 |

| Faction | Kinds | Breadth (groups of 7) | Roster |
|---|---|---|---|
| Kessler-Hayashi | 11 | 6 | laser trooper, heavy laser trooper, railgunner, laser tank, lightning tank, shock, heavy tank, tank, walker, laser drone, anti-air trooper |
| Grubstake | 9 | 6 | shotgun hand, slug, buggy, sapper, dozer, scorcher, scrap drone, bomb drone, flak buggy |
| Synthexis | 11 | 3 | bred spore, bred behemoth, bred stomper, bred big, bred burster, bred spitter, bred medium, bred small, bred big (creep), bred medium (creep), bred spitter (creep) |
| You | 5 | 3 | rocket trooper, trooper, flame trooper, breacher, battle tank |

## Mixed arms: does a flier soak a ground army's fire?

A ground army against the same spend with part of it in fliers, both ways round. Ground-only weapons cannot hurt a flier; a unit whose shot is aimed at one is turned to a ground target it can hurt (`landing-party/scripts/aim.lua`). The score is the all-ground army's.

| Mix | All-ground army's score | Fights |
|---|---|---|
| tanks and rifles / with harriers | +55 | 6 |
| prisms / prisms + harriers | -23 | 6 |
| tanks / tanks + harriers | +1 | 6 |
| dozers / dozers + harriers | +46 | 6 |

## The breach: bursters among other biters at a wall

The same spend sent at gun turrets behind a wall two deep (`tests/lp-arena/batch.lua`, BREACH), as plain biters and with part of it in bursters. A burster bursts where it dies: alone it is shot short of the wall; among others it reaches it. Ranges over the rounds.

| Wave | Spend | Won | Turrets broken | Wall pieces broken | Units lost |
|---|---|---|---|---|---|
| 40 medium | 280 | 0 of 3 | 0 | 0 to 1 | 40 of 40 |
| 34 medium + 1 burster | 278 | 0 of 3 | 0 to 1 | 8 to 10 | 35 of 35 |
| 29 medium + 2 bursters | 283 | 0 of 3 | 1 to 4 | 9 to 15 | 31 of 31 |
| 23 medium + 3 bursters | 281 | 0 of 3 | 3 to 5 | 15 to 18 | 26 of 26 |
| 17 medium + 4 bursters | 279 | 0 of 3 | 0 to 4 | 10 to 21 | 21 of 21 |
| 7 bursters | 280 | 0 of 3 | 0 to 1 | 15 to 16 | 7 of 7 |
| 10 big | 280 | 3 of 3 | 10 | 0 to 17 | 1 to 2 of 10 |
| 6 big + 3 bursters | 288 | 3 of 3 | 10 | 0 to 24 | 4 to 5 of 9 |
