# The arena: who counters whom (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (4644 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

![Counter heatmap](arena/counters.png)

Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, from -100 (wiped out, took nothing) to +100. Rows are grouped by class (below), strongest first within each.

## Classes

A class is a body and a weapon: **small arms** (many light bodies, small shots), **splash** (one weapon that hits several at once: a blast, an arc, a split beam), **armour** (a heavy hull whose flat resistance eats small shots), **air** (fliers: only weapons that can shoot up touch them; `docs/units.md` says which). The class against class score is the mean of its kinds' cells.

| Row against column | small arms | splash | armour | air | anti-air | bred | bred on creep |
|---|---|---|---|---|---|---|---|
| small arms | +0 | -51 | +0 | +70 | +29 | -18 | -48 |
| splash | +51 | +0 | -58 | -82 | +80 | +35 | +61 |
| armour | +0 | +58 | +0 | -36 | +82 | +4 | +3 |
| air | -70 | +82 | +36 | +0 | -81 | +60 | +61 |
| anti-air | -29 | -80 | -82 | +81 | +0 | -39 | -49 |
| bred | +18 | -35 | -4 | -60 | +39 | +0 | -14 |
| bred on creep | +48 | -61 | -3 | -61 | +49 | +14 | +0 |

## Each kind's counters

| Kind (price) | Beats most (its score) | Beaten most by (their score) |
|---|---|---|
| rocket trooper (20) | scrap drone (100), bomb drone (99), laser drone (95) | bred small (82), breacher (70), shotgun hand (61) |
| shotgun hand (8) | scrap drone (98), bred small (97), railgunner (97) | bred behemoth (100), bred big (100), bred big (creep) (100) |
| heavy laser trooper (14) | bomb drone (100), scrap drone (97), laser drone (96) | shock (87), bred big (creep) (73), breacher (71) |
| slug (30) | scrap drone (100), bomb drone (96), railgunner (95) | bred big (creep) (89), shock (85), lightning tank (79) |
| laser trooper (11) | bomb drone (100), scrap drone (97), railgunner (95) | shock (90), breacher (83), bred big (creep) (81) |
| trooper (10) | scrap drone (98), railgunner (96), bred small (93) | bred behemoth (100), bred big (100), bred big (creep) (100) |
| buggy (15) | scrap drone (98), railgunner (94), bomb drone (88) | laser tank (100), scorcher (100), bred behemoth (100) |
| railgunner (22) | bred burster (100), bred small (100), bred spitter (100) | laser drone (100), scorcher (100), bred stomper (100) |
| shock (30) | bred stomper (100), buggy (94), railgunner (93) | laser drone (100), scorcher (100), bred behemoth (100) |
| sapper (30) | bred small (96), bred burster (94), buggy (93) | laser drone (100), scorcher (100), bred behemoth (100) |
| flame trooper (20) | bred small (98), bred big (95), bred medium (95) | laser drone (100), laser tank (100), scorcher (100) |
| breacher (10) | bred small (100), railgunner (98), bred medium (96) | laser drone (100), scorcher (100), bred behemoth (100) |
| lightning tank (115) | shock (100), buggy (100), railgunner (100) | laser drone (100), scrap drone (100), dozer (100) |
| laser tank (115) | buggy (100), bred big (100), flak buggy (100) | laser drone (100), bred stomper (100), scrap drone (100) |
| battle tank (60) | railgunner (100), laser tank (100), flak buggy (100) | laser drone (100), scrap drone (100), shotgun hand (60) |
| tank (65) | flak buggy (100), breacher (100), flame trooper (100) | laser drone (100), scrap drone (100), battle tank (89) |
| walker (100) | railgunner (100), sapper (100), scorcher (100) | bred behemoth (100), bred big (92), bred big (creep) (92) |
| scorcher (100) | shock (100), buggy (100), railgunner (100) | laser drone (100), bred behemoth (100), bred stomper (100) |
| heavy tank (120) | shock (100), buggy (100), railgunner (100) | laser drone (100), scrap drone (100), battle tank (78) |
| dozer (120) | buggy (100), railgunner (100), laser tank (100) | laser drone (100), bred stomper (100), scrap drone (100) |
| laser drone (70) | shock (100), railgunner (100), sapper (100) | flak buggy (100), anti-air trooper (99), heavy laser trooper (96) |
| scrap drone (15) | shock (100), railgunner (100), sapper (100) | slug (100), anti-air trooper (100), flak buggy (100) |
| bomb drone (28) | bred burster (72), sapper (71), railgunner (69) | heavy laser trooper (100), laser trooper (100), anti-air trooper (100) |
| anti-air trooper (18) | bomb drone (100), scrap drone (100), laser drone (99) | bred stomper (100), walker (96), lightning tank (94) |
| flak buggy (20) | bomb drone (100), laser drone (100), scrap drone (100) | laser tank (100), scorcher (100), bred behemoth (100) |
| bred spore (10) | scrap drone (86), laser drone (79), bred burster (6) | railgunner (100), laser tank (100), bred behemoth (100) |
| bred stomper (150) | railgunner (100), laser tank (100), scorcher (100) | shock (100), laser drone (100), bred behemoth (100) |
| bred behemoth (200) | shock (100), buggy (100), sapper (100) | laser drone (100), battle tank (87), dozer (83) |
| bred big (28) | buggy (100), shotgun hand (100), trooper (100) | laser drone (100), laser tank (100), lightning tank (100) |
| bred medium (7) | buggy (98), bred small (93), bred spore (91) | laser drone (100), bred stomper (100), scrap drone (100) |
| bred spitter (9) | dozer (95), bred small (94), bred medium (67) | railgunner (100), laser drone (100), bred stomper (100) |
| bred burster (40) | lightning tank (13), flak buggy (12), laser tank (8) | railgunner (100), laser drone (100), scrap drone (100) |
| bred small (2) | rocket trooper (82), slug (72), bred burster (64) | railgunner (100), laser drone (100), breacher (100) |
| bred big (creep) (28) | buggy (100), shotgun hand (100), trooper (100) | laser drone (100), lightning tank (96), flame trooper (94) |
| bred medium (creep) (7) | buggy (98), bred small (98), flak buggy (96) | laser drone (100), bred stomper (100), flame trooper (95) |
| bred spitter (creep) (9) | dozer (95), bred small (93), buggy (57) | railgunner (100), laser drone (100), bred stomper (100) |

## Groups found from the fights alone

Each kind is its row of scores (against every kind and every fixed opponent); kinds are joined by average linkage on the distance between rows, so two kinds land together when they beat and lose to the same things (`scripts/arena_report.py`, scipy). Cut into 7 groups, as many as the hand-made classes:

![Clusters](arena/clusters.png)

| Group | Kinds (hand-made class) |
|---|---|
| 1 | rocket trooper (small arms), shotgun hand (small arms), heavy laser trooper (small arms), slug (small arms), laser trooper (small arms), trooper (small arms), buggy (small arms), anti-air trooper (anti-air), flak buggy (anti-air), bred spore (anti-air) |
| 2 | shock (splash), sapper (splash), flame trooper (splash), breacher (splash), bred stomper (bred), bred big (bred), bred medium (bred), bred big (creep) (bred on creep), bred medium (creep) (bred on creep) |
| 3 | lightning tank (splash), laser tank (splash), battle tank (armour), tank (armour), scorcher (armour), heavy tank (armour), dozer (armour), bred behemoth (bred) |
| 4 | bred spitter (bred), bred burster (bred), bred small (bred), bred spitter (creep) (bred on creep) |
| 5 | laser drone (air), scrap drone (air), bomb drone (air) |
| 6 | railgunner (small arms) |
| 7 | walker (armour) |

## Faction against faction

From the unit matrix, each faction's roster (the kinds it fields from landing or its tree; a kind both corporations field counts for both; Synthexis's breeds on creep too). **Answer**: for each of the other side's kinds, the row's best score against it, averaged: can it answer whatever the other fields? **Coverage**: the share of the other side's kinds it has a counter scoring +50 or more for. **Exposure**: the share of its own kinds the other side has such a counter for. **Breadth**: how many of the groups found from the fights alone (above) its roster spans.

![Factions](arena/factions.png)

| Row against column | Answer | Coverage | Exposure | Their answer | Edge |
|---|---|---|---|---|---|
| Kessler-Hayashi against Grubstake | +97 | 100% | 100% | +91 | +6 |
| Kessler-Hayashi against Synthexis | +100 | 100% | 100% | +81 | +19 |
| Kessler-Hayashi against You | +86 | 80% | 100% | +88 | -2 |
| Grubstake against Kessler-Hayashi | +91 | 100% | 100% | +97 | -6 |
| Grubstake against Synthexis | +86 | 82% | 100% | +92 | -6 |
| Grubstake against You | +90 | 100% | 100% | +90 | +0 |
| Synthexis against Kessler-Hayashi | +81 | 100% | 100% | +100 | -19 |
| Synthexis against Grubstake | +92 | 100% | 82% | +86 | +6 |
| Synthexis against You | +63 | 80% | 100% | +88 | -26 |
| You against Kessler-Hayashi | +88 | 100% | 80% | +86 | +2 |
| You against Grubstake | +90 | 100% | 100% | +90 | +0 |
| You against Synthexis | +88 | 100% | 80% | +63 | +26 |

| Faction | Kinds | Breadth (groups of 7) | Roster |
|---|---|---|---|
| Kessler-Hayashi | 10 | 5 | heavy laser trooper, laser trooper, railgunner, shock, lightning tank, laser tank, tank, heavy tank, laser drone, anti-air trooper |
| Grubstake | 9 | 4 | shotgun hand, slug, buggy, sapper, scorcher, dozer, scrap drone, bomb drone, flak buggy |
| Synthexis | 11 | 4 | bred spore, bred stomper, bred behemoth, bred big, bred medium, bred spitter, bred burster, bred small, bred big (creep), bred medium (creep), bred spitter (creep) |
| You | 5 | 3 | rocket trooper, trooper, flame trooper, breacher, battle tank |

## Mixed arms: does a flier soak a ground army's fire?

A ground army against the same spend with part of it in fliers, both ways round. Ground-only weapons cannot hurt a flier; a unit whose shot is aimed at one is turned to a ground target it can hurt (`landing-party/scripts/aim.lua`). The score is the all-ground army's.

| Mix | All-ground army's score | Fights |
|---|---|---|
| tanks / tanks + harriers | -12 | 6 |
| dozers / dozers + harriers | +64 | 6 |
| tanks and rifles / with harriers | +75 | 6 |
| prisms / prisms + harriers | -36 | 6 |

## The breach: bursters among other biters at a wall

The same spend sent at gun turrets behind a wall two deep (`tests/lp-arena/batch.lua`, BREACH), as plain biters and with part of it in bursters. A burster bursts where it dies: alone it is shot short of the wall; among others it reaches it. Ranges over the rounds.

| Wave | Spend | Won | Turrets broken | Wall pieces broken | Units lost |
|---|---|---|---|---|---|
| 40 medium | 280 | 0 of 3 | 0 | 3 | 40 of 40 |
| 34 medium + 1 burster | 278 | 0 of 3 | 0 to 1 | 1 to 9 | 35 of 35 |
| 29 medium + 2 bursters | 283 | 0 of 3 | 1 to 5 | 8 to 16 | 31 of 31 |
| 23 medium + 3 bursters | 281 | 0 of 3 | 3 | 13 to 18 | 26 of 26 |
| 17 medium + 4 bursters | 279 | 0 of 3 | 1 to 4 | 16 to 18 | 21 of 21 |
| 7 bursters | 280 | 0 of 3 | 0 to 2 | 16 | 7 of 7 |
| 10 big | 280 | 3 of 3 | 10 | 5 to 10 | 1 of 10 |
| 6 big + 3 bursters | 288 | 3 of 3 | 10 | 14 to 18 | 3 to 4 of 9 |
