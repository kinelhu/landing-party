# The arena: who counters whom (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (2496 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

![Counter heatmap](arena/counters.png)

Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, from -100 (wiped out, took nothing) to +100. Rows are grouped by class (below), strongest first within each.

## Classes

A class is a body and a weapon: **small arms** (many light bodies, small shots), **splash** (one weapon that hits several at once: a blast, an arc, a split beam), **armour** (a heavy hull whose flat resistance eats small shots), **air** (fliers: only weapons that can shoot up touch them; `docs/units.md` says which). The class against class score is the mean of its kinds' cells.

| Row against column | small arms | splash | armour | air | bred | bred on creep |
|---|---|---|---|---|---|---|
| small arms | +0 | -55 | -20 | +47 | -27 | -57 |
| splash | +55 | +0 | -58 | -100 | +62 | +51 |
| armour | +20 | +58 | +0 | -67 | -8 | -3 |
| air | -47 | +100 | +67 | +0 | +100 | +96 |
| bred | +27 | -62 | +8 | -100 | +0 | -30 |
| bred on creep | +57 | -51 | +3 | -96 | +30 | +0 |

## Each kind's counters

| Kind (price) | Beats most (its score) | Beaten most by (their score) |
|---|---|---|
| rocket trooper (20) | scavenger (95), harrier (95), tesla (85) | battle tank (76), breacher (71), slug (54) |
| slug (30) | scavenger (99), harrier (94), railgunner (83) | bred big (creep) (86), aegis (80), shock (73) |
| infantry (Grubstake) (8) | walker (79), scorcher (77), buggy (75) | scavenger (100), harrier (100), bred big (100) |
| trooper (10) | scavenger (98), harrier (98), walker (72) | bred big (100), bred big (creep) (100), bred medium (creep) (89) |
| infantry (Kessler-Hayashi) (10) | scavenger (97), harrier (95), lance (65) | prism (88), tank (86), battle tank (86) |
| lance (16) | scavenger (96), harrier (95), dozer (63) | bred big (creep) (84), battle tank (83), rocket trooper (80) |
| railgunner (22) | bred medium (creep) (100), bred medium (100), bred big (100) | scavenger (100), harrier (100), prism (100) |
| buggy (15) | scavenger (97), harrier (96), lance (64) | prism (100), tesla (100), bred big (100) |
| prism (100) | railgunner (100), shock (100), buggy (100) | scavenger (100), harrier (100), tank (100) |
| shock (30) | buggy (93), infantry (Grubstake) (87), bred medium (85) | scavenger (100), harrier (100), prism (100) |
| breacher (10) | buggy (94), infantry (Grubstake) (93), bred medium (90) | scavenger (100), harrier (100), aegis (100) |
| tesla (100) | railgunner (100), shock (100), sapper (100) | scavenger (100), harrier (100), aegis (100) |
| sapper (30) | infantry (Grubstake) (94), buggy (93), bred spitter (84) | scavenger (100), harrier (100), tesla (100) |
| battle tank (60) | railgunner (100), prism (100), tesla (100) | scavenger (100), harrier (100), infantry (Grubstake) (45) |
| aegis (95) | railgunner (100), buggy (100), prism (100) | scavenger (100), harrier (100), lance (62) |
| dozer (100) | railgunner (100), buggy (100), prism (100) | scavenger (100), harrier (100), bred spitter (93) |
| tank (60) | prism (100), breacher (95), buggy (90) | scavenger (100), harrier (100), battle tank (86) |
| walker (100) | railgunner (100), sapper (100), scavenger (100) | bred big (90), bred big (creep) (90), bred medium (creep) (84) |
| scorcher (70) | railgunner (83), buggy (83), infantry (Kessler-Hayashi) (75) | scavenger (100), harrier (100), bred big (100) |
| harrier (40) | railgunner (100), infantry (Grubstake) (100), shock (100) | trooper (98), buggy (96), walker (96) |
| scavenger (50) | railgunner (100), infantry (Grubstake) (100), shock (100) | walker (100), slug (99), trooper (98) |
| bred big (28) | infantry (Grubstake) (100), buggy (100), trooper (100) | railgunner (100), scavenger (100), harrier (100) |
| bred spitter (9) | dozer (93), aegis (60), scorcher (58) | railgunner (100), scavenger (100), harrier (100) |
| bred medium (7) | buggy (98), scorcher (84), trooper (79) | railgunner (100), scavenger (100), harrier (100) |
| bred big (creep) (28) | infantry (Grubstake) (100), buggy (100), trooper (100) | railgunner (100), scavenger (100), prism (100) |
| bred medium (creep) (7) | buggy (98), scorcher (94), trooper (89) | railgunner (100), scavenger (100), harrier (100) |

## Groups found from the fights alone

Each kind is its row of scores (against every kind and every fixed opponent); kinds are joined by average linkage on the distance between rows, so two kinds land together when they beat and lose to the same things (`scripts/arena_report.py`, scipy). Cut into 6 groups, as many as the hand-made classes:

![Clusters](arena/clusters.png)

| Group | Kinds (hand-made class) |
|---|---|
| 1 | prism (splash), shock (splash), breacher (splash), tesla (splash), sapper (splash), battle tank (armour), aegis (armour), dozer (armour), tank (armour), bred big (bred), bred medium (bred), bred big (creep) (bred on creep), bred medium (creep) (bred on creep) |
| 2 | rocket trooper (small arms), slug (small arms), trooper (small arms), infantry (Kessler-Hayashi) (small arms), lance (small arms), buggy (small arms), walker (armour) |
| 3 | infantry (Grubstake) (small arms), bred spitter (bred) |
| 4 | harrier (air), scavenger (air) |
| 5 | railgunner (small arms) |
| 6 | scorcher (armour) |

## Mixed arms: does a flier soak a ground army's fire?

A ground army against the same spend with part of it in fliers, both ways round. Ground-only weapons cannot hurt a flier; a unit whose shot is aimed at one is turned to a ground target it can hurt (`landing-party/scripts/aim.lua`). The score is the all-ground army's.

| Mix | All-ground army's score | Fights |
|---|---|---|
| prisms / prisms + harriers | -33 | 6 |
| tanks and rifles / with harriers | +47 | 6 |
| tanks / tanks + harriers | -43 | 6 |
| dozers / dozers + harriers | -31 | 6 |
