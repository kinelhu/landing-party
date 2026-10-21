# The arena: what the corporations' units buy (generated)

Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` (516 fights, 3 rounds; `scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.

Each squad is bought with 420 parts at the corporation's own prices (`shared.units`), in whole units, so a Tesla squad is 4 (340 parts) and an infantry squad 42. A cell: the squad's wins out of the rounds, then the share of its parts it lost (over all rounds). Nobody has research: no damage or speed bonuses on either side. The squads attack; a line of yours or a biter wave waits or meets them.

## Against a biter wave

Twenty biters and spitters, the spawners' own mix at that evolution (half from each kind of spawner).

| Squad | evolution 0.20 | evolution 0.50 | evolution 0.80 | evolution 0.95 |
|---|---|---|---|---|
| serenity infantry | 3/3, lost 0% | 3/3, lost 6% | 2/3, lost 65% | 0/3, lost 100% |
| serenity lance | 3/3, lost 0% | 3/3, lost 6% | 0/3, lost 100% | 0/3, lost 100% |
| serenity railgunner | 3/3, lost 0% | 3/3, lost 0% | 3/3, lost 0% | 3/3, lost 5% |
| serenity prism | 3/3, lost 0% | 3/3, lost 0% | 1/3, lost 83% | 0/3, lost 100% |
| serenity tesla | 3/3, lost 0% | 3/3, lost 0% | 0/3, lost 100% | 0/3, lost 100% |
| grubstake infantry | 3/3, lost 0% | 3/3, lost 33% | 0/3, lost 100% | 0/3, lost 100% |
| grubstake slug | 3/3, lost 0% | 3/3, lost 40% | 0/3, lost 100% | 0/3, lost 100% |
| grubstake sapper | 3/3, lost 0% | 3/3, lost 0% | 3/3, lost 8% | 0/3, lost 100% |
| serenity tank+infantry | 3/3, lost 0% | 3/3, lost 6% | 0/3, lost 100% | 0/3, lost 100% |
| serenity tesla+infantry | 3/3, lost 0% | 3/3, lost 4% | 2/3, lost 87% | 0/3, lost 100% |
| serenity prism+lance | 3/3, lost 0% | 3/3, lost 4% | 0/3, lost 100% | 0/3, lost 100% |
| serenity walker | 3/3, lost 0% | 3/3, lost 0% | 0/3, lost 100% | 0/3, lost 100% |
| grubstake scorcher | 3/3, lost 0% | 0/3, lost 100% | 0/3, lost 100% | 0/3, lost 100% |
| grubstake scorcher+infantry | 3/3, lost 0% | 3/3, lost 23% | 0/3, lost 100% | 0/3, lost 100% |
| serenity tank | 3/3, lost 0% | 3/3, lost 38% | 0/3, lost 100% | 0/3, lost 100% |
| grubstake tank | 3/3, lost 0% | 3/3, lost 38% | 0/3, lost 100% | 0/3, lost 100% |

## Against a line of yours

Each line behind a wall of 29 stone walls, no research. A cell: wins out of the rounds (the line destroyed), parts lost, and the mean time to break the line where it was broken.

| Squad | 6 gun turrets, piercing rounds | 4 laser turrets | 3 flamethrower turrets and 2 gun turrets |
|---|---|---|---|
| grubstake slug | 0/3, lost 100% | 3/3, lost 21%, 17 s | 0/3, lost 100% |
| serenity infantry | 3/3, lost 39%, 13 s | 3/3, lost 14%, 15 s | 0/3, lost 100% |
| serenity walker | 3/3, lost 56%, 35 s | 3/3, lost 33%, 44 s | 0/3, lost 100% |
| grubstake infantry | 0/3, lost 100% | 3/3, lost 47%, 31 s | 0/3, lost 100% |
| grubstake sapper | 3/3, lost 22%, 9 s | 3/3, lost 15%, 10 s | 0/3, lost 100% |
| serenity lance | 3/3, lost 72%, 17 s | 3/3, lost 30%, 18 s | 0/3, lost 100% |
| serenity tank+infantry | 3/3, lost 62%, 24 s | 3/3, lost 13%, 19 s | 0/3, lost 100% |
| serenity tesla+infantry | 3/3, lost 57%, 21 s | 3/3, lost 16%, 18 s | 0/3, lost 100% |
| serenity prism | 3/3, lost 22%, 17 s | 3/3, lost 17%, 22 s | 0/3, lost 100% |
| serenity tesla | 3/3, lost 67%, 30 s | 3/3, lost 33%, 38 s | 0/3, lost 100% |
| serenity prism+lance | 3/3, lost 31%, 17 s | 3/3, lost 17%, 19 s | 0/3, lost 100% |
| serenity tank | 3/3, lost 57%, 29 s | 3/3, lost 19%, 33 s | 0/3, lost 100% |
| grubstake tank | 3/3, lost 48%, 29 s | 3/3, lost 19%, 35 s | 0/3, lost 100% |
| grubstake scorcher | 3/3, lost 33%, 24 s | 3/3, lost 17%, 32 s | 3/3, lost 6%, 36 s |
| grubstake scorcher+infantry | 2/3, lost 83%, 34 s | 3/3, lost 50%, 42 s | 3/3, lost 72%, 77 s |
| serenity railgunner | 3/3, lost 33%, 146 s | 1/3, lost 28%, 158 s | 0/3, lost 82% |

## Serenity against Grubstake

Both squads at 420 parts, charging each other. A cell: Serenity's wins out of the rounds, then the exchange: the parts Grubstake lost for each part Serenity lost (above 1, Serenity came out ahead).

| Serenity \ Grubstake | sapper | slug | infantry | scorcher+infantry | scorcher | tank |
|---|---|---|---|---|---|---|
| lance | 0/3, 0.0 | 0/3, 0.6 | 3/3, 2.3 | 3/3, 5.3 | 3/3, 3.5 | 3/3, 1.4 |
| infantry | 0/3, 0.1 | 3/3, 2.9 | 3/3, 5.7 | 3/3, 11.5 | 3/3, 7.9 | 3/3, 3.0 |
| railgunner | 0/3, 0.1 | 0/3, 0.3 | 3/3, 3.0 | 0/3, 0.5 | 0/3, 0.3 | 0/3, 0.2 |
| tesla | 0/3, 0.3 | 0/3, 0.3 | 1/3, 1.0 | 3/3, 7.4 | 3/3, 7.4 | 3/3, 4.9 |
| tank | 0/3, 0.2 | 0/3, 0.3 | 0/3, 0.6 | 2/3, 1.0 | 3/3, 4.2 | 3/3, 1.9 |
| walker | 0/3, 0.2 | 0/3, 0.1 | 0/3, 0.3 | 0/3, 0.3 | 0/3, 0.6 | 0/3, 0.5 |
| tank+infantry | 0/3, 0.2 | 2/3, 1.0 | 3/3, 3.1 | 3/3, 7.4 | 3/3, 3.8 | 3/3, 2.9 |
| prism+lance | 0/3, 0.4 | 3/3, 1.7 | 3/3, 5.0 | 3/3, 6.4 | 3/3, 5.6 | 3/3, 3.5 |
| tesla+infantry | 0/3, 0.1 | 3/3, 3.4 | 3/3, 6.6 | 3/3, 9.7 | 3/3, 7.0 | 3/3, 3.0 |
| prism | 1/3, 0.8 | 3/3, 2.9 | 3/3, 6.0 | 3/3, 9.0 | 3/3, all | 3/3, 6.0 |
