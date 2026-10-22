# The arena: who counters whom (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (2001 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

![Counter heatmap](arena/counters.png)

Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, from -100 (wiped out, took nothing) to +100. Rows are grouped by class (below), strongest first within each.

## Classes

A class is a body and a weapon: **small arms** (many light bodies, small shots), **splash** (one weapon that hits several at once: a blast, an arc, a split beam), **armour** (a heavy hull whose flat resistance eats small shots), **air** (fliers: only weapons that can shoot up touch them; `docs/units.md` says which). The class against class score is the mean of its kinds' cells.

| Row against column | small arms | splash | armour | air | bred |
|---|---|---|---|---|---|
| small arms | +0 | -50 | -20 | +47 | -48 |
| splash | +50 | +0 | -54 | -100 | +69 |
| armour | +20 | +54 | +0 | -67 | +5 |
| air | -47 | +100 | +67 | +0 | +100 |
| bred | +48 | -69 | -5 | -100 | +0 |

## Each kind's counters

| Kind (price) | Beats most (its score) | Beaten most by (their score) |
|---|---|---|
| rocket trooper (20) | scavenger (95), harrier (95), dozer (84) | battle tank (76), breacher (71), slug (55) |
| slug (30) | scavenger (99), harrier (96), railgunner (89) | prism (78), bred big (76), shock (73) |
| infantry (Grubstake) (8) | scorcher (78), walker (78), buggy (72) | scavenger (100), harrier (100), bred big (100) |
| trooper (10) | scavenger (98), harrier (98), walker (71) | bred big (100), breacher (88), sapper (81) |
| lance (16) | scavenger (96), harrier (95), dozer (68) | battle tank (83), bred big (81), rocket trooper (79) |
| infantry (Kessler-Hayashi) (10) | scavenger (98), harrier (95), lance (62) | prism (88), battle tank (86), tank (86) |
| buggy (15) | scavenger (97), harrier (96), railgunner (63) | prism (100), bred big (100), tesla (100) |
| railgunner (22) | bred medium (100), bred big (100), lance (20) | scavenger (100), harrier (100), prism (100) |
| prism (100) | railgunner (100), shock (100), buggy (100) | scavenger (100), harrier (100), aegis (100) |
| breacher (10) | infantry (Grubstake) (95), buggy (94), bred medium (93) | scavenger (100), harrier (100), walker (100) |
| shock (30) | buggy (93), infantry (Grubstake) (87), infantry (Kessler-Hayashi) (81) | scavenger (100), harrier (100), prism (100) |
| tesla (100) | railgunner (100), sapper (100), shock (100) | scavenger (100), harrier (100), aegis (100) |
| sapper (30) | buggy (93), infantry (Grubstake) (89), trooper (81) | scavenger (100), harrier (100), tesla (100) |
| battle tank (60) | railgunner (100), prism (100), tesla (100) | scavenger (100), harrier (100), infantry (Grubstake) (51) |
| aegis (95) | railgunner (100), buggy (100), prism (100) | scavenger (100), harrier (100), lance (60) |
| dozer (100) | railgunner (100), buggy (100), prism (100) | scavenger (100), harrier (100), rocket trooper (84) |
| tank (60) | prism (97), buggy (88), infantry (Kessler-Hayashi) (86) | scavenger (100), harrier (100), battle tank (86) |
| walker (100) | railgunner (100), sapper (100), scavenger (100) | bred big (92), slug (82), bred medium (80) |
| scorcher (70) | buggy (86), infantry (Kessler-Hayashi) (81), railgunner (72) | scavenger (100), harrier (100), bred big (100) |
| harrier (40) | railgunner (100), sapper (100), infantry (Grubstake) (100) | walker (100), trooper (98), slug (96) |
| scavenger (50) | railgunner (100), sapper (100), infantry (Grubstake) (100) | walker (100), slug (99), infantry (Kessler-Hayashi) (98) |
| bred big (28) | infantry (Grubstake) (100), buggy (100), trooper (100) | railgunner (100), scavenger (100), harrier (100) |
| bred medium (7) | buggy (98), scorcher (81), walker (80) | railgunner (100), scavenger (100), harrier (100) |

## Groups found from the fights alone

Each kind is its row of scores (against every kind and every fixed opponent); kinds are joined by average linkage on the distance between rows, so two kinds land together when they beat and lose to the same things (`scripts/arena_report.py`, scipy). Cut into 5 groups, as many as the hand-made classes:

![Clusters](arena/clusters.png)

| Group | Kinds (hand-made class) |
|---|---|
| 1 | infantry (Grubstake) (small arms), prism (splash), breacher (splash), shock (splash), tesla (splash), sapper (splash), battle tank (armour), aegis (armour), dozer (armour), tank (armour), bred big (bred), bred medium (bred) |
| 2 | rocket trooper (small arms), slug (small arms), trooper (small arms), lance (small arms), infantry (Kessler-Hayashi) (small arms), buggy (small arms), walker (armour) |
| 3 | harrier (air), scavenger (air) |
| 4 | railgunner (small arms) |
| 5 | scorcher (armour) |

## Mixed arms: does a flier soak a ground army's fire?

A ground army against the same spend with part of it in fliers, both ways round. Ground-only weapons cannot hurt a flier; a unit whose shot is aimed at one is turned to a ground target it can hurt (`landing-party/scripts/aim.lua`). The score is the all-ground army's.

| Mix | All-ground army's score | Fights |
|---|---|---|
| prisms / prisms + harriers | -29 | 6 |
| dozers / dozers + harriers | -48 | 6 |
| tanks and rifles / with harriers | +64 | 6 |
| tanks / tanks + harriers | -36 | 6 |
