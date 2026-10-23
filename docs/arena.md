# The arena: who counters whom (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (4080 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

![Counter heatmap](arena/counters.png)

Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, from -100 (wiped out, took nothing) to +100. Rows are grouped by class (below), strongest first within each.

## Classes

A class is a body and a weapon: **small arms** (many light bodies, small shots), **splash** (one weapon that hits several at once: a blast, an arc, a split beam), **armour** (a heavy hull whose flat resistance eats small shots), **air** (fliers: only weapons that can shoot up touch them; `docs/units.md` says which). The class against class score is the mean of its kinds' cells.

| Row against column | small arms | splash | armour | air | anti-air | bred | bred on creep |
|---|---|---|---|---|---|---|---|
| small arms | +0 | -51 | -21 | +47 | +48 | -35 | -41 |
| splash | +51 | +0 | -55 | -100 | +86 | +19 | +49 |
| armour | +21 | +55 | +0 | -67 | +81 | -16 | -14 |
| air | -47 | +100 | +67 | +0 | -88 | +87 | +93 |
| anti-air | -48 | -86 | -81 | +88 | +0 | -59 | -68 |
| bred | +35 | -19 | +16 | -87 | +59 | +0 | +6 |
| bred on creep | +41 | -49 | +14 | -93 | +68 | -6 | +0 |

## Each kind's counters

| Kind (price) | Beats most (its score) | Beaten most by (their score) |
|---|---|---|
| rocket trooper (20) | scavenger (95), harrier (95), dozer (86) | bred behemoth (86), bred small (81), breacher (70) |
| slug (30) | scavenger (99), harrier (94), walker (87) | bred behemoth (100), laser tank (83), bred big (creep) (83) |
| shotgun hand (8) | bred small (98), bred spore (87), flak buggy (82) | scavenger (100), harrier (100), bred behemoth (100) |
| trooper (10) | scavenger (98), harrier (98), bred small (94) | bred behemoth (100), bred big (100), bred big (creep) (100) |
| railgunner (22) | bred medium (100), bred medium (creep) (100), bred small (100) | scavenger (100), laser tank (100), lightning tank (100) |
| laser trooper (10) | scavenger (97), harrier (95), bred spore (78) | tank (86), bred behemoth (86), battle tank (86) |
| heavy laser trooper (16) | scavenger (96), harrier (96), dozer (65) | bred stomper (89), bred behemoth (88), battle tank (86) |
| buggy (15) | scavenger (97), harrier (96), bred spore (69) | laser tank (100), lightning tank (100), bred behemoth (100) |
| laser tank (100) | railgunner (100), shock (100), bred medium (100) | scavenger (100), harrier (100), tank (100) |
| shock (30) | buggy (93), bred small (93), bred stomper (90) | scavenger (100), laser tank (100), lightning tank (100) |
| breacher (10) | bred small (100), shotgun hand (95), bred medium (94) | scavenger (100), harrier (100), bred behemoth (100) |
| lightning tank (100) | railgunner (100), shock (100), sapper (100) | scavenger (100), harrier (100), bred behemoth (100) |
| sapper (30) | bred spore (98), shotgun hand (93), buggy (93) | scavenger (100), lightning tank (100), harrier (100) |
| battle tank (60) | railgunner (100), laser tank (100), lightning tank (100) | scavenger (100), harrier (100), bred behemoth (100) |
| heavy tank (95) | railgunner (100), laser tank (100), lightning tank (100) | scavenger (100), harrier (100), bred behemoth (96) |
| dozer (100) | railgunner (100), shock (100), laser tank (100) | scavenger (100), harrier (100), bred behemoth (100) |
| tank (60) | laser tank (100), flak buggy (100), bred stomper (100) | scavenger (100), harrier (100), bred behemoth (100) |
| walker (100) | railgunner (100), sapper (100), scavenger (100) | bred behemoth (100), bred big (93), bred big (creep) (92) |
| scorcher (70) | flak buggy (100), buggy (83), railgunner (81) | scavenger (100), harrier (100), bred behemoth (100) |
| harrier (40) | railgunner (100), shotgun hand (100), shock (100) | flak buggy (100), walker (100), anti-air trooper (99) |
| scavenger (50) | railgunner (100), shotgun hand (100), shock (100) | flak buggy (100), walker (100), slug (99) |
| anti-air trooper (18) | harrier (99), scavenger (99), bred spore (85) | bred behemoth (100), bred stomper (100), bred big (creep) (94) |
| flak buggy (20) | scavenger (100), harrier (100), bred spore (90) | laser tank (100), tank (100), bred behemoth (100) |
| bred spore (10) | scavenger (81), harrier (50), rocket trooper (-27) | railgunner (100), bred behemoth (100), bred stomper (100) |
| bred behemoth (60) | slug (100), shotgun hand (100), anti-air trooper (100) | railgunner (92), scavenger (20), harrier (0) |
| bred stomper (150) | railgunner (100), anti-air trooper (100), laser tank (100) | scavenger (100), harrier (100), tank (100) |
| bred burster (70) | buggy (100), scorcher (100), shotgun hand (83) | railgunner (100), scavenger (100), harrier (100) |
| bred big (28) | shotgun hand (100), trooper (100), buggy (100) | railgunner (100), scavenger (100), lightning tank (100) |
| bred medium (7) | buggy (98), bred small (95), bred spore (93) | railgunner (100), scavenger (100), laser tank (100) |
| bred spitter (9) | dozer (91), bred small (84), bred medium (50) | railgunner (100), scavenger (100), harrier (100) |
| bred small (2) | rocket trooper (81), slug (66), bred spore (52) | railgunner (100), scavenger (100), harrier (100) |
| bred big (creep) (28) | shotgun hand (100), trooper (100), buggy (100) | railgunner (100), scavenger (100), lightning tank (100) |
| bred medium (creep) (7) | buggy (98), bred small (97), flak buggy (96) | railgunner (100), scavenger (100), harrier (100) |
| bred spitter (creep) (9) | dozer (93), bred small (86), scorcher (67) | railgunner (100), scavenger (100), harrier (100) |

## Groups found from the fights alone

Each kind is its row of scores (against every kind and every fixed opponent); kinds are joined by average linkage on the distance between rows, so two kinds land together when they beat and lose to the same things (`scripts/arena_report.py`, scipy). Cut into 7 groups, as many as the hand-made classes:

![Clusters](arena/clusters.png)

| Group | Kinds (hand-made class) |
|---|---|
| 1 | laser tank (splash), shock (splash), breacher (splash), lightning tank (splash), sapper (splash), battle tank (armour), heavy tank (armour), dozer (armour), tank (armour), bred stomper (bred), bred burster (bred), bred big (bred), bred medium (bred), bred big (creep) (bred on creep), bred medium (creep) (bred on creep) |
| 2 | rocket trooper (small arms), slug (small arms), trooper (small arms), laser trooper (small arms), heavy laser trooper (small arms), buggy (small arms), scorcher (armour), anti-air trooper (anti-air), flak buggy (anti-air), bred spore (anti-air) |
| 3 | shotgun hand (small arms), bred spitter (bred), bred small (bred), bred spitter (creep) (bred on creep) |
| 4 | harrier (air), scavenger (air) |
| 5 | railgunner (small arms) |
| 6 | walker (armour) |
| 7 | bred behemoth (bred) |

## Faction against faction

From the unit matrix, each faction's roster (the kinds it fields from landing or its tree; a kind both corporations field counts for both; Synthexis's breeds on creep too). **Answer**: for each of the other side's kinds, the row's best score against it, averaged: can it answer whatever the other fields? **Coverage**: the share of the other side's kinds it has a counter scoring +50 or more for. **Exposure**: the share of its own kinds the other side has such a counter for. **Breadth**: how many of the groups found from the fights alone (above) its roster spans.

![Factions](arena/factions.png)

| Row against column | Answer | Coverage | Exposure | Their answer | Edge |
|---|---|---|---|---|---|
| Kessler-Hayashi against Grubstake | +92 | 100% | 100% | +92 | +0 |
| Kessler-Hayashi against Synthexis | +99 | 100% | 100% | +97 | +2 |
| Kessler-Hayashi against You | +67 | 75% | 90% | +80 | -13 |
| Grubstake against Kessler-Hayashi | +92 | 100% | 100% | +92 | +0 |
| Grubstake against Synthexis | +93 | 91% | 89% | +92 | +0 |
| Grubstake against You | +85 | 100% | 89% | +87 | -1 |
| Synthexis against Kessler-Hayashi | +97 | 100% | 100% | +99 | -2 |
| Synthexis against Grubstake | +92 | 89% | 91% | +93 | +0 |
| Synthexis against You | +96 | 100% | 82% | +64 | +32 |
| You against Kessler-Hayashi | +80 | 90% | 75% | +67 | +13 |
| You against Grubstake | +87 | 89% | 100% | +85 | +1 |
| You against Synthexis | +64 | 82% | 100% | +96 | -32 |

| Faction | Kinds | Breadth (groups of 7) | Roster |
|---|---|---|---|
| Kessler-Hayashi | 10 | 4 | railgunner, laser trooper, heavy laser trooper, laser tank, shock, lightning tank, heavy tank, tank, walker, anti-air trooper |
| Grubstake | 9 | 4 | slug, shotgun hand, buggy, sapper, dozer, scorcher, harrier, scavenger, flak buggy |
| Synthexis | 11 | 4 | bred spore, bred behemoth, bred stomper, bred burster, bred big, bred medium, bred spitter, bred small, bred big (creep), bred medium (creep), bred spitter (creep) |
| You | 4 | 2 | rocket trooper, trooper, breacher, battle tank |

## Mixed arms: does a flier soak a ground army's fire?

A ground army against the same spend with part of it in fliers, both ways round. Ground-only weapons cannot hurt a flier; a unit whose shot is aimed at one is turned to a ground target it can hurt (`landing-party/scripts/aim.lua`). The score is the all-ground army's.

| Mix | All-ground army's score | Fights |
|---|---|---|
| prisms / prisms + harriers | -40 | 6 |
| tanks and rifles / with harriers | +57 | 6 |
| tanks / tanks + harriers | -43 | 6 |
| dozers / dozers + harriers | -38 | 6 |
