# Ammunition tiers in the arena (2026-11-20, 0.2.470)

`LP_ARENA_TIER=<round> LP_ARENA_TIER_EXP=<power> LP_ARENA_ONLY="trooper vs" scripts/arena.sh` (and `"gun buggy vs"`), on
the Studio, 3 rounds, equal spend as the counter matrix (`docs/arena.md`), no research, the rounds' own cost not priced.
Every tiered unit in a fight fires the round (the opponent's troopers and gun buggies too). A score is the share of the
other side destroyed less the share of its own value lost, from -100 to +100; "won" counts the matchups above 0. "base" is each unit's issue
round, unmarked: yellow magazines for the trooper, piercing for the gun buggy, plain shells for the battle tank. Summarised by `scripts/arena_tiers.py`.

The power is shared.TIER_EXP: the bonus is the round's direct damage over the base round's, read from the prototypes,
raised to it. At 1 (vanilla's ratio) a uranium squad wins almost everything and the counters are gone; 0.33 was chosen.
At 0.33 a uranium trooper beat the rocket trooper against 8 hulls of 10; at 0.2, 5 (rows at 0.2 below); kept at 0.33 once
the rocket trooper had its own rung.

The explosive rungs are named priors (shared.TIER_RAW), their blast shared.TIER_BLAST. Explored for the rocket trooper:
its explosive rocket at 3 won 38 of 44 (mean +49), at 2 37 (+48), at 3 with a blast of 0.15 37 (+48): a rocket's 110
under the corporations' infantry's 120 health is what kept it poor against riflemen, and any rung past 1.09 kills one a
rocket (Serenity's infantry -32 to +86). Chosen: 1.25 (118 a rocket) with the blast at 0.35, below. The shells' blast at
0.15 changed little (explosive 32 won, explosive uranium 35); kept at 0.35.



| unit | round | power | mean | won | tank | battle tank | aegis | bred behemoth | bred big | shock | biters 0.95 | rocket trooper | lance |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| battle tank | base | - | +8 | 23/44 | +73 | +7 | +61 | +27 | -29 | +49 | -95 | -23 | -52 |
| battle tank | explosive shell | 0.33 | +46 | 32/44 | +100 | +7 | +83 | +40 | +100 | +72 | -80 | +80 | +80 |
| battle tank | explosive uranium shell | 0.33 | +50 | 33/44 | +87 | -7 | +83 | +33 | +94 | +100 | -70 | +80 | +80 |
| battle tank | uranium shell | 0.33 | +38 | 32/44 | +87 | -7 | +67 | +40 | +34 | +54 | -88 | +73 | +80 |
| gun buggy | base | - | +10 | 23/44 | -88 | -87 | -52 | -100 | -59 | -61 | -78 | -22 | +88 |
| gun buggy | green | 0.33 | +41 | 32/44 | +28 | -67 | +48 | -67 | -6 | +42 | -75 | -5 | +82 |
| gun buggy | green | 0.5 | +55 | 40/44 | +26 | -17 | +78 | +13 | +61 | +63 | -58 | +15 | +91 |
| gun buggy | green | 1 | +67 | 40/44 | +46 | +40 | +81 | +70 | +75 | +44 | -35 | +63 | +91 |
| gun buggy | red | 1 | +8 | 22/44 | -88 | -87 | -52 | -100 | -59 | -69 | -78 | -22 | +88 |
| rocket trooper | base | - | +22 | 29/44 | +30 | +10 | +59 | +65 | +14 | +44 | -67 | -2 | +63 |
| rocket trooper | explosive rocket | 0.33 | +42 | 37/44 | +59 | +53 | +70 | +68 | +54 | +83 | -68 | +8 | +67 |
| trooper | base | - | -6 | 24/44 | +27 | +50 | +40 | -100 | -100 | -60 | -93 | +31 | -28 |
| trooper | green | 0.2 | +21 | 30/44 | +47 | +63 | +78 | +53 | -93 | -50 | -57 | +45 | +48 |
| trooper | green | 0.33 | +35 | 33/44 | +56 | +67 | +78 | +76 | -69 | -48 | -38 | +59 | +60 |
| trooper | green | 0.5 | +53 | 37/44 | +65 | +74 | +81 | +86 | +29 | +47 | -22 | +62 | +71 |
| trooper | green | 1 | +66 | 40/44 | +79 | +78 | +85 | +92 | +63 | +88 | +37 | +74 | +83 |
| trooper | red | 0.2 | +4 | 26/44 | +23 | +56 | +65 | -100 | -93 | -55 | -82 | +40 | -16 |
| trooper | red | 0.33 | +7 | 27/44 | +35 | +63 | +54 | -83 | -93 | -52 | -67 | +39 | +28 |
| trooper | red | 0.5 | +15 | 30/44 | +36 | +65 | +69 | +22 | -93 | -64 | -85 | +40 | +45 |
| trooper | red | 1 | +31 | 33/44 | +47 | +70 | +80 | +73 | -84 | -43 | -70 | +50 | +60 |
