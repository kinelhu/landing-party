# The arena: who counters whom (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (1173 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

![Counter heatmap](arena/counters.png)

Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, from -100 (wiped out, took nothing) to +100. Rows run from the strongest against the others on average.

## Each kind's counters

| Kind (price) | Beats most (its score) | Beaten most by (their score) |
|---|---|---|
| sapper (16) | infantry (Grubstake) (100), shock (98), slug (97) | prism (-30), aegis (-68), tesla (-69) |
| prism (70) | railgunner (100), shock (100), scavenger (100) | sapper (30), slug (-61), dozer (-70) |
| infantry (Serenity) (10) | scavenger (97), harrier (96), scorcher (87) | sapper (95), prism (83), shock (-54) |
| tesla (85) | railgunner (100), shock (100), scavenger (100) | prism (83), sapper (69), infantry (Serenity) (62) |
| aegis (80) | railgunner (100), buggy (100), scavenger (100) | prism (88), infantry (Serenity) (76), sapper (68) |
| dozer (90) | railgunner (100), buggy (100), scavenger (100) | sapper (93), infantry (Serenity) (86), shock (84) |
| shock (30) | scavenger (92), infantry (Grubstake) (90), harrier (90) | prism (100), tesla (100), sapper (98) |
| slug (25) | scorcher (90), walker (84), tank (73) | scavenger (100), harrier (100), sapper (97) |
| buggy (15) | scavenger (97), harrier (96), lance (75) | aegis (100), dozer (100), sapper (97) |
| lance (14) | scavenger (95), harrier (94), walker (71) | sapper (93), prism (83), tesla (80) |
| tank (60) | scavenger (100), harrier (94), railgunner (74) | prism (89), sapper (84), aegis (83) |
| walker (120) | railgunner (100), scavenger (100), harrier (100) | dozer (100), infantry (Serenity) (87), prism (86) |
| scorcher (70) | scavenger (100), harrier (100), railgunner (81) | prism (100), aegis (100), dozer (100) |
| harrier (40) | railgunner (100), infantry (Grubstake) (100), slug (100) | prism (100), tesla (100), scorcher (100) |
| infantry (Grubstake) (10) | scorcher (69), walker (69), tank (46) | sapper (100), scavenger (100), harrier (100) |
| scavenger (50) | railgunner (100), infantry (Grubstake) (100), slug (100) | prism (100), tesla (100), scorcher (100) |
| railgunner (22) | infantry (Grubstake) (69), lance (59), shock (-14) | scavenger (100), harrier (100), prism (100) |
