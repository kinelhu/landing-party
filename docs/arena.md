# The arena: who counters whom (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (3240 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

![Counter heatmap](arena/counters.png)

Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, from -100 (wiped out, took nothing) to +100. Rows are grouped by class (below), strongest first within each.

## Classes

A class is a body and a weapon: **small arms** (many light bodies, small shots), **splash** (one weapon that hits several at once: a blast, an arc, a split beam), **armour** (a heavy hull whose flat resistance eats small shots), **air** (fliers: only weapons that can shoot up touch them; `docs/units.md` says which). The class against class score is the mean of its kinds' cells.

| Row against column | small arms | splash | armour | air | anti-air | bred | bred on creep |
|---|---|---|---|---|---|---|---|
| small arms | +0 | -52 | -22 | +47 | +94 | -26 | -56 |
| splash | +52 | +0 | -57 | -100 | +98 | +46 | +55 |
| armour | +22 | +57 | +0 | -67 | +100 | -1 | -2 |
| air | -47 | +100 | +67 | +0 | -88 | +100 | +93 |
| anti-air | -94 | -98 | -100 | +88 | +0 | -89 | -97 |
| bred | +26 | -46 | +1 | -100 | +89 | +0 | -1 |
| bred on creep | +56 | -55 | +2 | -93 | +97 | +1 | +0 |

## Each kind's counters

| Kind (price) | Beats most (its score) | Beaten most by (their score) |
|---|---|---|
| rocket trooper (20) | bred spore (96), scavenger (95), harrier (95) | battle tank (74), breacher (67), slug (61) |
| slug (30) | scavenger (100), bred spore (100), harrier (96) | bred big (creep) (80), aegis (80), prism (78) |
| infantry (Grubstake) (8) | bred spore (100), flak buggy (97), skyguard (97) | scavenger (100), harrier (100), bred big (creep) (100) |
| trooper (10) | scavenger (98), harrier (98), skyguard (97) | bred big (creep) (100), bred big (100), bred medium (creep) (90) |
| infantry (Kessler-Hayashi) (10) | scavenger (98), skyguard (96), harrier (95) | shock (87), tank (86), battle tank (86) |
| lance (16) | scavenger (96), harrier (95), skyguard (91) | bred big (creep) (83), battle tank (83), rocket trooper (80) |
| railgunner (22) | bred medium (100), bred medium (creep) (100), bred big (creep) (100) | scavenger (100), harrier (100), prism (100) |
| buggy (15) | bred spore (100), scavenger (97), harrier (96) | prism (100), bred big (creep) (100), tesla (100) |
| prism (100) | railgunner (100), shock (100), bred big (creep) (100) | scavenger (100), harrier (100), tank (100) |
| shock (30) | bred spore (100), buggy (93), flak buggy (93) | scavenger (100), harrier (100), prism (100) |
| breacher (10) | bred spore (100), skyguard (97), flak buggy (96) | scavenger (100), harrier (100), aegis (100) |
| tesla (100) | railgunner (100), sapper (100), shock (100) | scavenger (100), harrier (100), prism (100) |
| sapper (30) | bred spore (100), infantry (Grubstake) (94), buggy (93) | scavenger (100), harrier (100), tesla (100) |
| battle tank (60) | railgunner (100), sapper (100), prism (100) | scavenger (100), harrier (100), dozer (50) |
| aegis (95) | railgunner (100), breacher (100), buggy (100) | scavenger (100), harrier (100), lance (61) |
| dozer (100) | railgunner (100), shock (100), prism (100) | scavenger (100), harrier (100), bred spitter (93) |
| tank (60) | prism (100), skyguard (100), flak buggy (100) | scavenger (100), harrier (100), aegis (87) |
| walker (100) | railgunner (100), sapper (100), scavenger (100) | bred big (93), bred big (creep) (92), bred medium (creep) (84) |
| scorcher (70) | skyguard (100), flak buggy (100), bred spore (100) | scavenger (100), harrier (100), bred big (creep) (100) |
| harrier (40) | railgunner (100), infantry (Grubstake) (100), sapper (100) | skyguard (100), flak buggy (100), walker (100) |
| scavenger (50) | railgunner (100), infantry (Grubstake) (100), sapper (100) | slug (100), flak buggy (100), walker (100) |
| skyguard (18) | harrier (100), scavenger (99), bred spore (95) | prism (100), tesla (100), aegis (100) |
| flak buggy (20) | scavenger (100), harrier (100), bred spore (93) | prism (100), tesla (100), aegis (100) |
| bred spore (10) | scavenger (80), harrier (48), bred spitter (-84) | railgunner (100), infantry (Grubstake) (100), sapper (100) |
| bred cinder (70) | buggy (100), scorcher (100), bred spore (100) | railgunner (100), scavenger (100), harrier (100) |
| bred big (28) | infantry (Grubstake) (100), trooper (100), buggy (100) | railgunner (100), scavenger (100), harrier (100) |
| bred spitter (9) | dozer (93), bred spore (84), flak buggy (76) | railgunner (100), scavenger (100), harrier (100) |
| bred medium (7) | buggy (98), skyguard (98), bred spore (98) | railgunner (100), scavenger (100), harrier (100) |
| bred big (creep) (28) | infantry (Grubstake) (100), trooper (100), buggy (100) | railgunner (100), scavenger (100), prism (100) |
| bred medium (creep) (7) | bred spore (99), buggy (98), flak buggy (98) | railgunner (100), scavenger (100), harrier (100) |

## Groups found from the fights alone

Each kind is its row of scores (against every kind and every fixed opponent); kinds are joined by average linkage on the distance between rows, so two kinds land together when they beat and lose to the same things (`scripts/arena_report.py`, scipy). Cut into 7 groups, as many as the hand-made classes:

![Clusters](arena/clusters.png)

| Group | Kinds (hand-made class) |
|---|---|
| 1 | infantry (Grubstake) (small arms), shock (splash), breacher (splash), sapper (splash), bred cinder (bred), bred big (bred), bred spitter (bred), bred medium (bred), bred big (creep) (bred on creep), bred medium (creep) (bred on creep) |
| 2 | rocket trooper (small arms), slug (small arms), trooper (small arms), infantry (Kessler-Hayashi) (small arms), lance (small arms), buggy (small arms), walker (armour) |
| 3 | prism (splash), tesla (splash), battle tank (armour), aegis (armour), dozer (armour), tank (armour) |
| 4 | skyguard (anti-air), flak buggy (anti-air), bred spore (anti-air) |
| 5 | harrier (air), scavenger (air) |
| 6 | railgunner (small arms) |
| 7 | scorcher (armour) |

## Mixed arms: does a flier soak a ground army's fire?

A ground army against the same spend with part of it in fliers, both ways round. Ground-only weapons cannot hurt a flier; a unit whose shot is aimed at one is turned to a ground target it can hurt (`landing-party/scripts/aim.lua`). The score is the all-ground army's.

| Mix | All-ground army's score | Fights |
|---|---|---|
| prisms / prisms + harriers | -37 | 6 |
| tanks and rifles / with harriers | +6 | 6 |
| dozers / dozers + harriers | -28 | 6 |
| tanks / tanks + harriers | -38 | 6 |
