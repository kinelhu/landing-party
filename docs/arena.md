# The arena: who counters whom (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (1173 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

![Counter heatmap](arena/counters.png)

Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, from -100 (wiped out, took nothing) to +100. Rows run from the strongest against the others on average.

## Each kind's counters

| Kind (price) | Beats most (its score) | Beaten most by (their score) |
|---|---|---|
| infantry (Serenity) (10) | scavenger (98), harrier (97), dozer (86) | sapper (79), slug (-51), buggy (-53) |
| prism (100) | railgunner (100), sapper (100), shock (100) | slug (75), infantry (Serenity) (69), infantry (Grubstake) (10) |
| aegis (80) | railgunner (100), buggy (100), scavenger (100) | infantry (Serenity) (77), prism (67), lance (60) |
| tesla (100) | railgunner (100), sapper (100), shock (100) | infantry (Serenity) (71), prism (71), aegis (70) |
| sapper (30) | shock (100), infantry (Grubstake) (100), scavenger (93) | tesla (100), prism (100), walker (100) |
| dozer (90) | railgunner (100), buggy (100), scavenger (100) | infantry (Serenity) (86), shock (84), lance (54) |
| slug (25) | scorcher (92), prism (75), walker (74) | scavenger (100), harrier (100), sapper (87) |
| tank (52) | scavenger (100), railgunner (96), harrier (93) | aegis (83), tesla (75), prism (75) |
| shock (30) | harrier (92), scavenger (90), infantry (Grubstake) (88) | sapper (100), tesla (100), prism (100) |
| walker (100) | railgunner (100), sapper (100), scavenger (100) | dozer (86), infantry (Serenity) (81), aegis (80) |
| lance (14) | scavenger (94), harrier (92), scorcher (68) | infantry (Serenity) (81), sapper (80), buggy (79) |
| buggy (15) | scavenger (97), harrier (96), lance (79) | aegis (100), dozer (100), sapper (93) |
| infantry (Grubstake) (10) | scorcher (69), walker (54), prism (10) | sapper (100), scavenger (100), harrier (100) |
| harrier (40) | railgunner (100), slug (100), infantry (Grubstake) (100) | tesla (100), prism (100), scorcher (100) |
| scorcher (70) | scavenger (100), harrier (100), railgunner (78) | aegis (100), dozer (100), slug (92) |
| scavenger (50) | railgunner (100), slug (100), infantry (Grubstake) (100) | tesla (100), prism (100), tank (100) |
| railgunner (22) | infantry (Grubstake) (65), lance (38), shock (-22) | scavenger (100), harrier (100), tesla (100) |
