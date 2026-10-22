# The arena: who counters whom (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (2001 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

![Counter heatmap](arena/counters.png)

Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, from -100 (wiped out, took nothing) to +100. Rows are grouped by class (below), strongest first within each.

## Classes

A class is a body and a weapon: **small arms** (many light bodies, small shots), **splash** (one weapon that hits several at once: a blast, an arc, a split beam), **armour** (a heavy hull whose flat resistance eats small shots), **air** (fliers: only weapons that can shoot up touch them; `docs/units.md` says which). The class against class score is the mean of its kinds' cells.

| Row against column | small arms | splash | armour | air | bred |
|---|---|---|---|---|---|
| small arms | +0 | -49 | -21 | +47 | -40 |
| splash | +49 | +0 | -61 | -100 | +60 |
| armour | +21 | +61 | +0 | -67 | -45 |
| air | -47 | +100 | +67 | +0 | +100 |
| bred | +40 | -60 | +45 | -100 | +0 |

## Each kind's counters

| Kind (price) | Beats most (its score) | Beaten most by (their score) |
|---|---|---|
| rocket trooper (20) | scavenger (96), harrier (96), dozer (88) | breacher (74), battle tank (62), slug (58) |
| slug (30) | scavenger (98), harrier (96), railgunner (86) | aegis (80), prism (72), dozer (67) |
| infantry (Grubstake) (8) | walker (78), scorcher (75), buggy (74) | scavenger (100), harrier (100), bred big (100) |
| trooper (10) | scavenger (98), harrier (98), walker (71) | bred big (96), breacher (84), sapper (81) |
| infantry (Kessler-Hayashi) (10) | scavenger (97), harrier (97), lance (66) | breacher (86), tank (86), battle tank (86) |
| lance (16) | scavenger (96), harrier (94), dozer (66) | battle tank (83), rocket trooper (80), shock (77) |
| buggy (15) | scavenger (97), harrier (96), railgunner (65) | tesla (100), bred big (100), aegis (100) |
| railgunner (22) | bred medium (100), bred big (100), lance (34) | prism (100), scavenger (100), harrier (100) |
| prism (100) | railgunner (100), shock (100), buggy (92) | scavenger (100), harrier (100), aegis (100) |
| breacher (10) | infantry (Grubstake) (94), buggy (93), bred medium (91) | scavenger (100), harrier (100), aegis (100) |
| shock (30) | buggy (93), infantry (Grubstake) (85), bred medium (85) | prism (100), scavenger (100), harrier (100) |
| sapper (30) | infantry (Grubstake) (93), buggy (93), bred medium (87) | scavenger (100), harrier (100), tesla (100) |
| tesla (100) | railgunner (100), shock (100), sapper (100) | scavenger (100), harrier (100), aegis (100) |
| aegis (95) | railgunner (100), prism (100), breacher (100) | scavenger (100), harrier (100), lance (60) |
| battle tank (60) | railgunner (100), prism (100), tesla (100) | scavenger (100), harrier (100), infantry (Grubstake) (48) |
| dozer (100) | railgunner (100), shock (100), prism (100) | scavenger (100), harrier (100), rocket trooper (88) |
| walker (100) | railgunner (100), sapper (100), breacher (100) | bred big (92), bred medium (85), slug (82) |
| tank (60) | buggy (88), prism (87), infantry (Kessler-Hayashi) (86) | scavenger (100), harrier (100), battle tank (81) |
| scorcher (70) | buggy (86), infantry (Kessler-Hayashi) (81), railgunner (78) | scavenger (100), harrier (100), bred big (100) |
| harrier (40) | railgunner (100), infantry (Grubstake) (100), shock (100) | walker (100), trooper (98), infantry (Kessler-Hayashi) (97) |
| scavenger (50) | railgunner (100), infantry (Grubstake) (100), shock (100) | walker (100), slug (98), trooper (98) |
| bred medium (6) | buggy (98), scorcher (94), walker (85) | railgunner (100), scavenger (100), harrier (100) |
| bred big (28) | infantry (Grubstake) (100), buggy (100), scorcher (100) | railgunner (100), scavenger (100), harrier (100) |

## Groups found from the fights alone

Each kind is its row of scores (against every kind and every fixed opponent); kinds are joined by average linkage on the distance between rows, so two kinds land together when they beat and lose to the same things (`scripts/arena_report.py`, scipy). Cut into 5 groups, as many as the hand-made classes:

![Clusters](arena/clusters.png)

| Group | Kinds (hand-made class) |
|---|---|
| 1 | infantry (Grubstake) (small arms), prism (splash), breacher (splash), shock (splash), sapper (splash), tesla (splash), aegis (armour), battle tank (armour), dozer (armour), tank (armour), bred medium (bred), bred big (bred) |
| 2 | rocket trooper (small arms), slug (small arms), trooper (small arms), infantry (Kessler-Hayashi) (small arms), lance (small arms), buggy (small arms), walker (armour) |
| 3 | harrier (air), scavenger (air) |
| 4 | railgunner (small arms) |
| 5 | scorcher (armour) |

## Mixed arms: does a flier soak a ground army's fire?

A ground army against the same spend with part of it in fliers, both ways round. Ground-only weapons cannot hurt a flier; a unit whose shot is aimed at one is turned to a ground target it can hurt (`landing-party/scripts/aim.lua`). The score is the all-ground army's.

| Mix | All-ground army's score | Fights |
|---|---|---|
| prisms / prisms + harriers | -29 | 6 |
| tanks / tanks + harriers | -36 | 6 |
| tanks and rifles / with harriers | +62 | 6 |
| dozers / dozers + harriers | -24 | 6 |
