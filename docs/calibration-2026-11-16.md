# Calibration groundwork (2026-11-16, 0.2.429)

The sweep for after the user's playtest (the user, 2026-11-16: "All of those are due"): the three reference
factories (scripts/make_reference.sh saves of 2026-10-18 and 19: belt, laser, artillery; vanilla bases with default
biters), each visited for 180 game minutes by Kessler-Hayashi and Grubstake (Synthexis off, LP_OFF=biotech) at
difficulty easy, normal and hard (LP_MIX diff_<level>, the map setting, seen applied in every run's results) by
director gentle, steady and chaotic; one seed (seed salt 1). Every number below is copied by script from the runs'
results.txt (METRIC lines) and decisions.txt (strike forces sent and broken): docs/sim/visit-<ref>-record-seed1-
diff_<level>-no-biotech-dir-<director>-v429. No tuning was changed.

Columns: razed_worth and razed_count, the player's buildings the corporations razed (valuemap's worth, and how many);
razed_strike, the worth of those razed by director strike forces; strikes and broke, strike forces sent and broken;
beats, the director's; biter_razed, the player's buildings biters razed; units_lost, the corporations' units lost;
raids, operations launched; parts, the lead camp's parts at the end; errors, Lua errors in the run.

| ref | diff | director | razed_worth | razed_count | razed_strike | strikes | broke | beats | biter_razed | units_lost | raids | parts | errors |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| artillery | easy | chaotic | 64 | 61 | 61 | 3 | 1 | 3 | 1 | 59 | 2 | 91 | 0 |
| artillery | easy | gentle | 2 | 5 | 0 | 2 | 2 | 2 | 25 | 56 | 2 | 2934 | 0 |
| artillery | easy | steady | 4 | 10 | 1 | 3 | 1 | 3 | 1 | 69 | 2 | 2281 | 0 |
| artillery | hard | chaotic | 145 | 123 | 16 | 4 | 3 | 4 | 0 | 569 | 15 | 723 | 0 |
| artillery | hard | gentle | 46 | 46 | 27 | 3 | 2 | 3 | 0 | 316 | 9 | 357 | 0 |
| artillery | hard | steady | 86 | 113 | 57 | 4 | 1 | 4 | 2 | 361 | 9 | 14513 | 0 |
| artillery | normal | chaotic | 335 | 972 | 8 | 3 | 2 | 3 | 0 | 238 | 13 | 3011 | 0 |
| artillery | normal | gentle | 124 | 403 | 57 | 2 | 1 | 2 | 4 | 357 | 6 | 205 | 0 |
| artillery | normal | steady | 375 | 947 | 62 | 4 | 1 | 4 | 246 | 280 | 10 | 3131 | 0 |
| belt | easy | chaotic | 8 | 8 | 7 | 2 | 2 | 2 | 25 | 15 | 5 | 312 | 0 |
| belt | easy | gentle | 36 | 44 | 36 | 2 | 1 | 2 | 25 | 23 | 3 | 246 | 0 |
| belt | easy | steady | 31 | 40 | 22 | 2 | 2 | 2 | 25 | 18 | 5 | 377 | 0 |
| belt | hard | chaotic | 209 | 257 | 157 | 4 | 3 | 4 | 25 | 111 | 17 | 326 | 0 |
| belt | hard | gentle | 232 | 253 | 106 | 3 | 2 | 3 | 25 | 129 | 14 | 370 | 0 |
| belt | hard | steady | 339 | 420 | 244 | 4 | 2 | 4 | 25 | 121 | 16 | 326 | 0 |
| belt | normal | chaotic | 228 | 271 | 180 | 4 | 3 | 4 | 25 | 121 | 11 | 327 | 0 |
| belt | normal | gentle | 138 | 150 | 61 | 3 | 3 | 3 | 25 | 91 | 12 | 184 | 0 |
| belt | normal | steady | 452 | 427 | 215 | 4 | 2 | 4 | 25 | 99 | 12 | 411 | 0 |
| laser | easy | chaotic | 11 | 27 | 9 | 3 | 2 | 3 | 28 | 30 | 3 | 31 | 0 |
| laser | easy | gentle | 2 | 2 | 0 | 2 | 2 | 2 | 37 | 21 | 2 | 17 | 0 |
| laser | easy | steady | 22 | 29 | 20 | 3 | 2 | 3 | 28 | 30 | 5 | 231 | 0 |
| laser | hard | chaotic | 48 | 79 | 28 | 4 | 2 | 4 | 0 | 232 | 6 | 229 | 0 |
| laser | hard | gentle | 42 | 59 | 0 | 2 | 2 | 2 | 0 | 314 | 8 | 95 | 0 |
| laser | hard | steady | 272 | 559 | 35 | 4 | 2 | 4 | 39 | 192 | 6 | 299 | 0 |
| laser | normal | chaotic | 64 | 106 | 60 | 3 | 3 | 3 | 32 | 55 | 3 | 364 | 0 |
| laser | normal | gentle | 222 | 841 | 34 | 3 | 3 | 3 | 31 | 118 | 4 | 341 | 0 |
| laser | normal | steady | 17 | 63 | 9 | 3 | 2 | 3 | 32 | 118 | 6 | 319 | 0 |

## Read before using it

- One seed a cell: on these saves the biters and the camps branch from the first minutes, and the same setting gives
  very different numbers (on the 2026-11-16 visits at director steady, three seeds razed 1,242 to 1,683 on nwa and
  880 to 1,214 on deathworld10x; with the director off, 0 to 306 on nwa). Hard razed less than normal on artillery and on laser here; that is not a reading of the
  difficulty until three seeds a cell agree. Next: the same sweep at seeds 2 and 3 (scripts/night_visits.sh
  calibration, the mix's seed changed), and a director-off row for each factory and difficulty as the baseline.
- razed_count counts construction robots and containers; razed_worth weighs only what valuemap weighs, so the two
  disagree where robots died (artillery normal gentle).
- These factories are small (belt: 340 buildings, 9 technologies), yet their strike forces were 15 to 58 units (belt
  normal steady and laser hard steady), near the user's saves' 40: points_max binds early, so strike size barely
  follows the base. Their razing is the camps' own operations as much as the strikes' (razed_strike against
  razed_worth).
- No Lua error in any run.
