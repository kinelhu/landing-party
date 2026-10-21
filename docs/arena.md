# The arena: who counters whom (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (1701 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

![Counter heatmap](arena/counters.png)

Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, from -100 (wiped out, took nothing) to +100. Rows are grouped by class (below), strongest first within each.

## Classes

A class is a body and a weapon: **small arms** (many light bodies, small shots), **splash** (one weapon that hits several at once: a blast, an arc, a split beam), **armour** (a heavy hull whose flat resistance eats small shots), **air** (fliers: only weapons that can shoot up touch them; `docs/units.md` says which). The class against class score is the mean of its kinds' cells.

| Row against column | small arms | splash | armour | air |
|---|---|---|---|---|
| small arms | +0 | -50 | -21 | +47 |
| splash | +50 | +0 | -58 | -100 |
| armour | +21 | +58 | +0 | -67 |
| air | -47 | +100 | +67 | +0 |

## Each kind's counters

| Kind (price) | Beats most (its score) | Beaten most by (their score) |
|---|---|---|
| rocket trooper (20) | scavenger (96), harrier (96), dozer (85) | battle tank (69), breacher (69), slug (60) |
| slug (30) | scavenger (99), harrier (96), railgunner (85) | prism (83), aegis (80), shock (71) |
| infantry (Grubstake) (8) | walker (78), scorcher (77), buggy (74) | scavenger (100), harrier (100), breacher (96) |
| trooper (10) | harrier (98), scavenger (97), walker (72) | breacher (83), sapper (81), aegis (71) |
| lance (16) | scavenger (96), harrier (94), dozer (66) | battle tank (86), rocket trooper (80), breacher (74) |
| infantry (Kessler-Hayashi) (10) | scavenger (97), harrier (95), lance (65) | tank (86), battle tank (86), breacher (85) |
| buggy (15) | scavenger (97), harrier (96), railgunner (67) | prism (100), tesla (100), aegis (100) |
| railgunner (22) | lance (25), shock (-34), sapper (-37) | scavenger (100), harrier (100), prism (100) |
| prism (100) | railgunner (100), shock (100), buggy (100) | scavenger (100), harrier (100), tank (100) |
| breacher (10) | infantry (Grubstake) (96), buggy (94), railgunner (86) | scavenger (100), harrier (100), aegis (100) |
| sapper (30) | buggy (94), infantry (Grubstake) (89), trooper (81) | scavenger (100), harrier (100), tesla (100) |
| shock (30) | buggy (93), infantry (Grubstake) (82), infantry (Kessler-Hayashi) (81) | scavenger (100), harrier (100), prism (100) |
| tesla (100) | railgunner (100), sapper (100), shock (100) | scavenger (100), harrier (100), aegis (100) |
| aegis (95) | railgunner (100), buggy (100), prism (100) | scavenger (100), harrier (100), lance (49) |
| battle tank (60) | railgunner (100), prism (100), tesla (100) | scavenger (100), harrier (100), walker (50) |
| dozer (100) | railgunner (100), buggy (100), prism (100) | scavenger (100), harrier (100), rocket trooper (85) |
| walker (100) | railgunner (100), sapper (100), scavenger (100) | slug (78), infantry (Grubstake) (78), dozer (75) |
| tank (60) | prism (100), buggy (88), breacher (88) | scavenger (100), harrier (100), battle tank (79) |
| scorcher (70) | buggy (83), railgunner (78), infantry (Kessler-Hayashi) (78) | scavenger (100), harrier (100), aegis (100) |
| harrier (40) | railgunner (100), sapper (100), infantry (Grubstake) (100) | walker (100), trooper (98), slug (96) |
| scavenger (50) | railgunner (100), sapper (100), infantry (Grubstake) (100) | walker (100), slug (99), infantry (Kessler-Hayashi) (97) |

## Groups found from the fights alone

Each kind is its row of scores (against every kind and every fixed opponent); kinds are joined by average linkage on the distance between rows, so two kinds land together when they beat and lose to the same things (`scripts/arena_report.py`, scipy). Cut into 4 groups, as many as the hand-made classes:

![Clusters](arena/clusters.png)

| Group | Kinds (hand-made class) |
|---|---|
| 1 | infantry (Grubstake) (small arms), prism (splash), breacher (splash), sapper (splash), shock (splash), tesla (splash), aegis (armour), battle tank (armour), dozer (armour), tank (armour), scorcher (armour) |
| 2 | rocket trooper (small arms), slug (small arms), trooper (small arms), lance (small arms), infantry (Kessler-Hayashi) (small arms), buggy (small arms), walker (armour) |
| 3 | harrier (air), scavenger (air) |
| 4 | railgunner (small arms) |

## Mixed arms: does a flier soak a ground army's fire?

A ground army against the same spend with part of it in fliers, both ways round. Ground-only weapons cannot hurt a flier; a unit whose shot is aimed at one is turned to a ground target it can hurt (`landing-party/scripts/aim.lua`). The score is the all-ground army's.

| Mix | All-ground army's score | Fights |
|---|---|---|
| prisms / prisms + harriers | -37 | 6 |
| tanks / tanks + harriers | -38 | 6 |
| tanks and rifles / with harriers | +49 | 6 |
| dozers / dozers + harriers | -48 | 6 |
