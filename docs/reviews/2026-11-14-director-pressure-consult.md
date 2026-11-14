<!-- Fable consult, 2026-11-14, read-only: what limits the director's pressure. Asked after the calibration of
0.2.385 (docs/director.md 9c, DESIGN). Its claim 2 (the proven-size bug) checked against tactics.best_size, ops.raid_want
and the smoke run's ops.jsonl: the first raid recorded sent 44, got 2, inside, and became the size asked for after. -->

# Director consult, part three: what limits the pressure (read-only, 2026-11-14)

Read: docs/director.md, the 11-13 consult, director.lua, ops.lua (tick's decider, choose, launch, budget, era, committed, raid_want, mended_floor), siege.lua (siege_tier, the assault), tactics.lua (best_size, history_near), war.reinforce, army.cap, pool, the contact scenario, and the smoke run on disk (`docs/sim/contact-12345-gap`: decisions.txt, ops.jsonl, timeline.md), which is the evidence the numbers alone hide.

## 1. Diagnosis, ranked

**1. Reach, not pace.** The player the director is calibrated on is beyond the one camp's reach, and no dial changes reach. Walled 12345: the base's cheapest edge target reads defence 9.7 (raid needs `needed()` = 3.5×9.7+4 = 38), the corners 19.5 (72); the camp's cap is 30 (2 depots × (10 + 5 × tier 1), `army.cap`), its field 21. Its sieges go at tier 1 because `siege_tier` caps the tier at `budget(owner)` = 1 + era = 1: 30 shells against 45 and 90 needed (`t.shells_need`), then "no assault (39 needed, 6 guards and 25 at home)". Both sieges in the smoke run: `spent`, razed 0, counted as operations launched. That is why walled reads 225/225 and 163/164: on or off, every launch against the base is impotent. Even the passive base (16 lasers in corner clusters) only loses its outpost and ring substations.

**2. A sizing bug made "units short".** `ops.raid_want` takes `tactics.best_size` as proven, and `best_size` admits any attempt with `inside and got >= 1`. The smoke run's first raid (minute 30, rung 3, 8 sent at defence 2.9, 1 came back, razed 2 lasers) was recorded `sent 44, lost 32, got 2, inside true` and became the proven size (~26 units) for the same outpost now reading defence 0.0 (`history_near` discards attempts only where the defence is *stronger* since, `tactics.stronger`, never weaker). 28 of 30 "units short" on 12345 walled, and 23 pod units, bought a raid of 24 against zero guns, which `needed(0)` = 4 would have taken. 9d's "the measured limit was units short, not nerve" rests on this artefact.

**3. The spree and its lull cancel.** A spree halves gaps (`tune.sooner`: 5 → 2.5 min done, 10 → 5 aborted, siege cool 15 → 7.5) for 20 minutes; the cycle is dominated by the march and the operation (busy 38% of tempo samples), so a spree buys about one extra operation; the 15-minute truce takes one back. Sum of opsOn − opsOff over the ten runs: +5. On ≈ off is the design's own fairness target (section 8, "within 30% of off"), achieved.

**4. The threat budget holds every second camp at era 0.** `choose`: `held = in_flight >= budget(owner)`; the same cap in `choose_siege`. With budget 1, a drop wave's three camps or a second landing queue behind the one operation in flight. The design's "intensity has nothing to turn until two camps" is backwards: it is the binding cap on both the siege tier and the second camp from the first camp on, and a surge (the only thing that raises it) needs two camps at war.

**5. The pay reaches the wrong thing.** `pay_gap` fires only from `launch` (raids). The siege's assault, the one thing that razes a walled base, asks `raid_want` too and is never paid; the surge's `committed` lowers the odds bar but not the size.

Where your reading is off: (1) b.op single is real but third-order: idle "units short" (54 samples) plus the lull cost more than busy did, and a second op is held by the budget anyway. (2) half the cap was 15 units, enough to close 38 against 21+15 on the edge substation; it was spent on an inflated want. (3) Supply parts are idle *now* (the smoke camp parked on 300, queue `post:lp-wall`), but `siege_tier`'s purse is `b.parts + b.siege_fund` (tier 2 costs 220, tier 3 400): once the tier cap lifts, parts are the lever that buys shells.

## 2. What to measure

Not operations launched (a 6-guard siege razing nothing = a 24-raid razing 11) and not buildings left (robots rebuild lasers and walls from 40/400 spares; the census counts them back). From what is logged already:
- **Razed worth per hour of the player's**, from the director's own `s.losses` ring (`valuemap.razed_of`) or `storage.player_razed` weighed; on against off, by variant.
- **Inside share**: attempts with `inside = true` over attempts, from `ops.jsonl`'s `attempt`; and razed per operation from its `kills`. Reach is the number that must move first.
- **Longest valley**: minutes between razes, from `kills[].t`.
- Keep the tempo measure's "units short", now expected near 0.

## 3. Changes, ranked by effect per work

1. **Proven size must have come home.** `tactics.best_size`: admit an attempt only if `spent <= PROVEN_LOSS × sent` (prior 0.5); and in `raid_want`, drop `proven` when the target's sig now has fewer guns than the attempt's (`t.defence` read vs `h.sig.guns`). Check: smoke run's "units short" 27 → under 5; first paid raid ≤ 8 units; `attempt.sent` of the outpost raid ≈ 4. Breaks: raids that the ledger legitimately sized up after a cheap success; scenario `country` reads the raid's size.
2. **Intensity from the first camp.** Give the spree `spree_add` 1 on `budget(owner)` for its corporation (today `s.intensity` is the surge's only); drop 9b's "surge only with two camps". Effect: tier 2 (80 shells) against 45 needed, and a second camp's operation allowed. Check: walled 12345's mid-side siege razes ≥ 1 under a spree; walled bldgLeftOn < Off; `budget_holds` falls. Breaks: `siege_goal`/`siege_garrison` read `top_tier` through `budget` (time-bound by `till`, but check the armed camp's fund does not chase it); scenario `budget` asserts the cap.
3. **Pay the assault.** In siege.lua's assault branch, before "no assault", call `ops.pay_gap(b, owner, want − (n + home_n), cap)` under the same `gap_share`. Check: the smoke's "no assault (39 needed...)" assaults; razed > 0 at the base. Breaks: losses to lasers over the wall (the fairness check); pods per beat.
4. **Lull only when earned.** `lull_if_razed` true: the lull after a spree only if the player lost something in it, else straight to fill. Check: opsOn − opsOff ≥ +2 a run on passive. Breaks: the curve's valley on a quiet spree (by design, there was nothing to breathe from).
5. **Supply drop into the siege fund** for an armed camp (`b.siege_fund`, read by `siege_tier`'s purse), not `b.parts` the planner spends on walls. Check: the next siege's tier after a collected drop is a tier up. Breaks: nothing visible; the player's 150 plates stay.

## 4. Not next

- A second concurrent operation per camp: held by the budget at era 0 anyway, unstaffable from a field of 21, and every system assumes `b.op`.
- The drop wave weighted higher at era 0: three tier-1 camps, one operation at a time, withdrawn at 45 minutes.
- Tying a supply drop to a spree: parts do not raise the cap; change 5 instead.
- The siege push, probe, bounty, rivals, more personalities, more readings: nothing measured asks for them.

## 5. Design against the measurements

- Section 8's "reshapes, does not add; total razed within 30% of off" is now the wrong target; the user wants pressure moved. Replace with a razed-worth curve by era and variant.
- Section 5.1 (intensity idle until two camps) and 9b (surge needs two camps): wrong, as above.
- 9d's premise (units short) was the sizing bug; the "commitment" (desperate odds) addresses nerve, which was not the limit.
- The supply drop is listed as a threat beat; as built it is parts to a planner. Either change 5 or call it the player's reward.
- Adaptation climbs 0.1 an hour (1.09 after two): invisible in any calibration; make it per beat or drop it.
- Fill "(1 + era/2) a landing interval" is a fiction at era 0; `beat_minutes` 35 is the real rate. Say so.
