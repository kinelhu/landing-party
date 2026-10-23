# The arena: who counters whom (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (2673 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

![Counter heatmap](arena/counters.png)

Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, from -100 (wiped out, took nothing) to +100. Rows are grouped by class (below), strongest first within each.

## Classes

A class is a body and a weapon: **small arms** (many light bodies, small shots), **splash** (one weapon that hits several at once: a blast, an arc, a split beam), **armour** (a heavy hull whose flat resistance eats small shots), **air** (fliers: only weapons that can shoot up touch them; `docs/units.md` says which). The class against class score is the mean of its kinds' cells.

| Row against column | small arms | splash | armour | air | bred | bred on creep |
|---|---|---|---|---|---|---|
| small arms | +0 | -52 | -20 | +47 | -28 | -56 |
| splash | +52 | +0 | -60 | -100 | +47 | +49 |
| armour | +20 | +60 | +0 | -67 | -4 | -6 |
| air | -47 | +100 | +67 | +0 | +100 | +95 |
| bred | +28 | -47 | +4 | -100 | +0 | -7 |
| bred on creep | +56 | -49 | +6 | -95 | +7 | +0 |

## Each kind's counters

| Kind (price) | Beats most (its score) | Beaten most by (their score) |
|---|---|---|
| rocket trooper (20) | scavenger (95), harrier (95), tesla (92) | battle tank (74), breacher (71), slug (52) |
| slug (30) | scavenger (99), harrier (97), railgunner (80) | bred big (creep) (84), tesla (83), prism (78) |
| infantry (Grubstake) (8) | walker (80), scorcher (78), buggy (77) | scavenger (100), harrier (100), bred big (100) |
| trooper (10) | scavenger (98), harrier (96), scorcher (70) | bred big (100), bred big (creep) (100), bred medium (creep) (89) |
| infantry (Kessler-Hayashi) (10) | scavenger (97), harrier (97), lance (69) | tank (86), battle tank (86), breacher (85) |
| lance (16) | scavenger (96), harrier (95), dozer (66) | battle tank (83), bred big (creep) (81), bred big (77) |
| railgunner (22) | bred medium (100), bred medium (creep) (100), bred big (100) | scavenger (100), harrier (100), aegis (100) |
| buggy (15) | scavenger (97), harrier (96), railgunner (59) | aegis (100), tesla (100), bred big (100) |
| prism (100) | railgunner (100), shock (100), bred medium (creep) (100) | scavenger (100), harrier (100), aegis (100) |
| sapper (30) | infantry (Grubstake) (93), buggy (93), bred spitter (81) | scavenger (100), harrier (100), tesla (100) |
| tesla (100) | railgunner (100), shock (100), sapper (100) | scavenger (100), harrier (100), aegis (100) |
| breacher (10) | infantry (Grubstake) (94), buggy (91), bred medium (88) | scavenger (100), harrier (100), aegis (100) |
| shock (30) | buggy (93), infantry (Grubstake) (88), bred medium (86) | scavenger (100), harrier (100), prism (100) |
| battle tank (60) | railgunner (100), sapper (100), prism (100) | scavenger (100), harrier (100), infantry (Grubstake) (47) |
| aegis (95) | railgunner (100), breacher (100), buggy (100) | scavenger (100), harrier (100), lance (51) |
| dozer (100) | railgunner (100), shock (100), buggy (100) | scavenger (100), harrier (100), bred spitter (95) |
| tank (60) | prism (100), tesla (90), infantry (Kessler-Hayashi) (86) | scavenger (100), harrier (100), aegis (83) |
| walker (100) | railgunner (100), sapper (100), breacher (100) | bred big (creep) (93), bred big (90), bred medium (creep) (83) |
| scorcher (70) | railgunner (83), buggy (83), infantry (Kessler-Hayashi) (81) | scavenger (100), harrier (100), aegis (100) |
| harrier (40) | railgunner (100), shock (100), sapper (100) | walker (100), slug (97), infantry (Kessler-Hayashi) (97) |
| scavenger (50) | railgunner (100), shock (100), sapper (100) | walker (100), slug (99), trooper (98) |
| bred cinder (70) | buggy (100), scorcher (100), infantry (Grubstake) (83) | railgunner (100), scavenger (100), harrier (100) |
| bred big (28) | infantry (Grubstake) (100), buggy (100), trooper (100) | railgunner (100), scavenger (100), harrier (100) |
| bred spitter (9) | dozer (95), scorcher (52), aegis (51) | railgunner (100), scavenger (100), harrier (100) |
| bred medium (7) | buggy (98), scorcher (89), walker (81) | railgunner (100), scavenger (100), harrier (100) |
| bred big (creep) (28) | infantry (Grubstake) (100), buggy (100), trooper (100) | railgunner (100), scavenger (100), tesla (100) |
| bred medium (creep) (7) | buggy (98), scorcher (95), trooper (89) | railgunner (100), scavenger (100), harrier (100) |

## Groups found from the fights alone

Each kind is its row of scores (against every kind and every fixed opponent); kinds are joined by average linkage on the distance between rows, so two kinds land together when they beat and lose to the same things (`scripts/arena_report.py`, scipy). Cut into 6 groups, as many as the hand-made classes:

![Clusters](arena/clusters.png)

| Group | Kinds (hand-made class) |
|---|---|
| 1 | infantry (Grubstake) (small arms), sapper (splash), breacher (splash), shock (splash), bred cinder (bred), bred big (bred), bred spitter (bred), bred medium (bred), bred big (creep) (bred on creep), bred medium (creep) (bred on creep) |
| 2 | rocket trooper (small arms), slug (small arms), trooper (small arms), infantry (Kessler-Hayashi) (small arms), lance (small arms), buggy (small arms), walker (armour) |
| 3 | prism (splash), tesla (splash), battle tank (armour), aegis (armour), dozer (armour), tank (armour) |
| 4 | harrier (air), scavenger (air) |
| 5 | railgunner (small arms) |
| 6 | scorcher (armour) |

## Mixed arms: does a flier soak a ground army's fire?

A ground army against the same spend with part of it in fliers, both ways round. Ground-only weapons cannot hurt a flier; a unit whose shot is aimed at one is turned to a ground target it can hurt (`landing-party/scripts/aim.lua`). The score is the all-ground army's.

| Mix | All-ground army's score | Fights |
|---|---|---|
| prisms / prisms + harriers | -33 | 6 |
| tanks and rifles / with harriers | +23 | 6 |
| dozers / dozers + harriers | -45 | 6 |
| tanks / tanks + harriers | -31 | 6 |
