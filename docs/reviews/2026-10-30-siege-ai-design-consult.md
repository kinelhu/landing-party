# Synthexis's attack decision: an RTS design consult (Fable, read-only, 2026-10-30)

Read: `DESIGN.md` (Synthexis rows, findings), `farm.lua`, `herd.lua`, `know.lua`, `costmap.lua`, the three lab runs, the
rolled-back `docs/wip/2026-10-30-oneway-strikes.patch`, the 10-23 audit and the 10-29 and 10-30 consults. Nothing run,
nothing edited. Line numbers are the working tree's.

## 1. What RTS practice says, and where this AI stands

Commercial RTS AIs (StarCraft II's built-in, Age of Empires II DE's scripts, Supreme Commander's platoons) and the
academic ones (UAlbertaBot, the StarCraft AI competition entries, Churchill's and Preuss's surveys) share a shape:

| Practice | Here |
|---|---|
| **Layers**: strategy (posture, budget), operations (target, method, force), tactics (execution). | Operations and tactics exist (`farm.lua`, `herd.lua`). Strategy is implicit in `send`'s constants (SAVE_FOR, WORTH_WAIT, SAVE_WAIT, STALL, ESCALATE_WAIT, farm.lua:74-79). The audit's `strategy.lua` serves the corporations only. |
| **Influence maps** shared by every decision. | Built and good: `firemap`, `costmap`, `valuemap`, `threat`. Read twice, though (section 2). |
| **Utility scoring**, components logged. | `target_from` is a textbook scorer, `(gain + learn) * kept / (1 + dist/far)`, with an exploration term (`novelty`, `teach`, farm.lua:548-552). Five vetoes then override it: `passes`, `refused`, `min_gain`, `affords`, `dear`. |
| **HTN / method libraries**: a failed method yields to another. | One method per situation: a plain wave, else *the* siege (`sequence`, herd.lua:2015). No alternative for the same place. |
| **Exploration vs exploitation**: optimistic priors, decaying estimates, a probing budget. | Novelty is skipped for sieges (`sg` by `value/(1+k)/dist`, farm.lua:583-589). `k.dear` holds until `place_sig` changes, with no time decay; `herd.stopped` keys are never cleared; `learn_price` with `floor` only raises a price after a wipe-out (know.lua:68). Three ratchets. |
| **Adaptation to the opponent** in production and tactics. | Prices per prototype (good, rare in mods). `counters.lua` is read for plain waves only (farm.lua:1241) and as a filter, not a weight: hence 270 cinders and all-behemoth herds. No memory of *what was tried where*, only of what it cost. |
| **Multi-pronged attacks**, supply cuts. | None from one culture. `cuts` (`feeds.lua`) exists and is off. The 10-29 consult dropped joint marching between cultures; two groups from one farm was not considered. |
| **Escalation** by tech, cadence and method, not headcount. | Was headcount (farm.lua:1195), now capped at 60: one rung (bursters developed, herd.lua:367), then nothing. |

The stack is ahead of most mod AIs on perception and behind on decision structure: it has the maps and the tactics and
lacks the operations layer that chooses among methods and remembers attempts.

## 2. Why the day's patches fought each other

**Two decision models that disagree.** `target_from` weighs places on a coarse map (`ways_from`: 32 or 48-tile cells, a
`way_in` breach at "the dearest step", no `walled`, `standing` or screen; farm.lua:390-449, 500-560). `herd.plan` plus
`siege_size` price the same place at 16 tiles with walls, standing time, cover price and fodder (herd.lua:1219-1276,
farm.lua:794-853). `send` arbitrates with vetoes and records: a siege ends if "a wave of what it has pays elsewhere by its
plan" (farm.lua:996-1001); the plan's refusal is written back into the coarse weighing as `dear[key]` (farm.lua:1050-1067);
`compose` draws the herd *after* the plan is priced, so the strength checked is not the strength hatched (farm.lua:666-671).
Every loop in the findings log (269 refusals, 147 repeats, three sieges ended for waves then refused, four refusals for a
short draw) is this pair arguing. One-way strikes added a third sizer (`one_way_size`) inside the second and new vetoes in
`send`; marking failed breaches changed the shared cost map and so what the *first* model refused. Patches to one model
move the other.

**Learning only prices.** `know.lua` holds price, opens, reach, scale per foe and prototype; `lessons` hold faces and
killers per 64-tile centre, read by `choose_mark` and `order` only. Nothing records "siege at breach cell X with method Y
razed Z". The only way a failed siege can change the next decision is by inflating prices, and inflated prices speak to
every place at once (every laser on the fort went from 3.6 to 27 in trial 5, from two samples: know.lua:68 `floor` plus
`PRICE_LEARN` 0.4). The AI cannot distinguish "this breach is bad" from "this fort is dear".

**Exploitation with no exploration budget.** Once `learned` is true the farm "holds and grows" (farm.lua:1083-1092) and
`herd.stopped` marks it. A refused siege waits "until its biomass reaches the cheapest siege's price there"; under the 60 cap
that price is unreachable when 21 guns at 27 each cover the breach, so trial 6 holds forever. The cap and the ratchet
together are a deadlock by construction, not a tuning error.

**Saturation read as price.** `PRICE_MAX` 40 is hit by the flamethrower in trial 2. A saturated price is a sign the model is
wrong for that weapon (the 10-30 fire consult: dwell, not a per-gun price), and the planner treats it as a number like any
other.

## 3. The architecture to build toward

One reading, a menu of methods, one memory of attempts, scores instead of vetoes, and an exploration rule that fires on
idle biomass rather than on a clock. Small enough to build in six steps, each checked in the lab.

**A. One reading.** `target_from` stops pricing. It becomes the candidate generator only: the foe's 64-tile cells, their
worth, their guns, their units (farm.lua:470-490 stays). One cost map per farm per weighing, from its pens, 16-tile cells,
a box round all candidates (what `ways_from` already does at coarser grain), cached until a wave ends or a candidate's
`place_sig` changes. `herd.plan(surface, from, target, ...)` gains a form that reads a given map, `herd.plan_on(cm, fmap,
target, n)`, and the wave's plan is the weighing's plan. Delete: the coarse `cell = radius > 600 and CELL*3` branch, the
`c.siege` loop (farm.lua:556-566), `priced`/`k.dear`/`DEAR_FOR` and the `other` check in `send`. Unverified: the UPS of
one 16-tile map over a 1,000-tile box (the 10-29 consult counted about 7,700 cells for `herd.plan`); if it bites, read it
in slices across ticks, since a weighing every ten seconds has 600 ticks to spend.

**B. Methods.** For each candidate place, the operations layer evaluates a fixed menu against the one map and returns
`{method, breach, price, strength, gain, order}` for each:
1. *raid*: the plain wave at an unwalled breach (what `send` does today without a siege);
2. *siege*: rams, screen, rush at a walled breach (`siege_size`, kept whole);
3. *bite*: one way through a burn, sized by what survivors break before the burn finishes them (the rolled-back patch's
   `herd.one_way`, now a method and not a special case in `send`);
4. *cut*: a wave at what feeds the guns (`feeds.lua` is built: the fort's one storage tank feeding 22 flamethrowers through
   190 pipes, its substations). `targets` already rates roboports and power; this makes the cut the mission;
5. *pincer*: two herds from one farm at two breaches whose `firemap.cover` sets are disjoint, each a siege or raid of half.
All five are scored with one function: `gain * keeps(strength, price) * novelty / (1 + dist/far)`. A method whose price
exceeds what the culture can field is not vetoed; it keeps its score and its shortfall, and loses to a method it can pay
for. Keep: `sequence`, `breach`, `send_big_bursters`, `detonate`, `sweep`, `targets`, `learn_*`, the march and stay
rules. Delete: `tough_wanted` and the BURST_SHARE branch of `order` (the method writes the order), `SAVE_FOR`,
`WORTH_WAIT`, `SAVE_WAIT`, `STALL`, `ESCALATE_WAIT`, `f.refused`, `f.refused_at`, `f.repeats`, `herd.stopped`'s permanent
keys (the development of bursters reads the attempt memory instead).

**C. Attempt memory** (`know.lua`, beside prices): per foe, per 16-tile breach cell, per method: `{tries, got_in, razed,
lost, last_tick}`. This is what a planner reads to know that *this* breach with *this* method failed twice. Prices stay the
map's prior; the memory is the posterior at a place. Novelty for a (cell, method) is `1 - exp(-(now - last)/fade)` as it is
for cells today (farm.lua:538); a place never tried has novelty 1 at every method.

**D. Exploration on idle biomass.** The trigger is an event the economy already produces: the culture's breeding pool is
above what its best affordable method asks and no wave is out. Then it sends a *probe*: `WAVE_MIN` of its mix at the
(cell, method) with the highest `expected gain + novelty * teach`, the same two terms `target_from` already computes
(farm.lua:548-552), and no third constant. A probe learns like any wave (prices, attempt memory). A probe that gets in
flips that (cell, method) to exploitation: the next wave goes there at the size the method asks, and the one after, while
the hole stands ("waves come back through holes earlier ones made"). A probe that is stopped makes its (cell, method) cold
and the next probe goes elsewhere by novelty alone. Prices are learned with sample weight by what was sent, so a probe of
24 moves a price less than a siege of 60 does; the wipe-out floor applies to the guns covering the breach only, not to
inside and withdrawal losses (herd.lua:331-358 already separates them).

**E. Decay and saturation.** Every record the planner reads decays: by `place_sig` change (kept) and by time at
`mind.fade` (new for sieges, as it is for cells). A price at `PRICE_MAX` is flagged saturated, and a saturated gun's
reach is read as "no way through its arc" in the cost map, not as 40 (this is the fire consult's R1 by another route and
is what makes the breach move to the fort's corners, where 56 wall pieces lie under lasers alone).

**F. Escalation as a ladder of methods, not of numbers.** Raid stopped twice at a foe: rams developed (exists). Siege
stopped twice at a place: pincer and cut unlock for that foe. Nothing unlocks a bigger herd: the 60 cap is the size; the
ladder goes through method and cadence (`WAVE_GAP` shortens while a place is in exploitation). Each rung is one event in
`decisions.txt` and one notice to the player (herd.lua:375-381 is the pattern).

**G. Composition as weights.** `compose` keeps the chance draw to strength, and `counters.lua` tilts the weights,
`w' = w * (1 + fit)`, with `fit` clamped to `[-0.9, 1]` so no breed is excluded and none can be all of it. Delete `UNFIT`
as a filter. A siege's herd gets the same tilt as a raid's.

### Order, and what the lab shows at each step

0. **Instrument first.** `lab.jsonl` gets `method`, the plan's breach cell, the wave's make-up by breed, `probe = true/false`,
   and the attempt memory after; `lab_report.py` adds two tables: breach cell by trial and method by trial. All three saves.
1. **A, one reading.** `lab-lab-plot-edit`: in `decisions.txt` the "lays siege ... its plan: in at X" breach equals the
   weighing's; lines "ends its siege", "read again" and "no siege it can lay" at most one each per trial. `farm` siege
   regression on the four seeds passes.
2. **C, D, E** with raid and siege only. `plot-edit`, 8 trials: no `held` outcome; at least two distinct breach cells across
   trials; after a siege is stopped the next trial is a probe elsewhere (`probe = true`, another cell); the laser price does
   not jump by 20 in one trial (`prices_after` trial to trial). `lab-lab` (square): still breaks in by trial 2.
3. **G, composition.** In `wave` make-up, no breed above 60% of a siege herd; across 8 trials every breed its evolution
   allows appears; `lab-lab-star` razes at least what it does today (trials 3 and 5 got in).
4. **B3, B4: bite and cut.** `plot-edit`: a trial whose method is `cut` targets the tank, a pipe run or substations
   (`kills` in the wave record); in the following trial, deaths with `k = flamethrower-turret` in `lab-rec-N.jsonl` fall.
5. **B5, pincer.** `lab-lab-star`: a trial with two breaches whose cover sets are disjoint, `got in` where single sieges
   held; `decisions.txt` shows both herds' sequences interleaved. Unverified: two `unit-group`s from one farm pathing
   independently; the `blockexit`/`wayout` scenarios show the engine's pathfinder is touchy.
6. **F, H: ladder and notices.** `contact.sh` on three variants: the event list reads raid, siege, probe, pincer or cut in
   that order with a notice at each rung; scenario `dev` gets `/lp probe` and `/lp pincer`.

The lab cannot show one thing: exploitation of an opened breach before the player rebuilds, because the lab rebuilds
everything between trials. Add a lab flag that delays the rebuild by one trial, and check that a trial after a break-in
goes to the same breach at full size.

## 4. The four questions

**Keeping at a fort it judges too dear.** It never judges a fort; it judges (cell, method) pairs, each cooling with
time and warming with novelty. Idle biomass triggers a probe, so a rich culture at a strong fort probes often and a poor
one rarely, with no clock. Twenty pairs round a fort are twenty probes before anything repeats; on the user's fort that is
the corners first (lasers alone), then the flamethrower straights by cut, then by bite.

**Changing breach, composition and tactic.** Breach: the attempt memory's novelty on the one map. Composition: the
counters' tilt on the draw, from the killers at that place. Tactic: the method menu, a stopped method cold at that cell,
its siblings warm. One mechanism (a posterior per pair) on three keys, which is why they stay consistent where today's
three patches did not.

**Beyond one 60-unit siege.** Not more biters. A pincer puts two 30s at breaches whose guns do not cover each other,
halving the fire on each and doubling the rams at the wall at once; a cut goes for the tank or the substations feeding the
line while the siege draws the guns; cadence shortens while a breach stands open. Pressure is how many things happen and
how soon, not the size of any one, which is what the 60 cap is for.

**Legibility.** Every wave has a method name and every method one visible shape: a raid walks in; a siege shows screen,
rams, rush, always in that order; a probe is small and announced as one; a pincer is two trails; a cut goes for pipes and
poles and leaves the guns. Each ladder rung's notice names method and direction ("Synthexis probes the south-east corner";
"two herds, north and east"). `decisions.txt` logs the best three (cell, method) pairs with their components, as it logs
cells today.

## Unverified

- UPS of one 16-tile map per farm per weighing over a box of 1,000 tiles (A).
- That two groups from one farm path and arrive within a usable window (B5); the 10-29 consult's pathing cautions apply.
- That `WAVE_MIN` probes read as pressure and not as noise to a player; the contact timelines will say.
- That the clamp on `fit` keeps a mixed herd at every evolution; the arena matrix has -1.00 for most breeds against the
  flamethrower, which would push every herd toward the cinder if unclamped.
- Fire priced as dwell (the 10-30 consult's R1) is assumed to land; without it a saturated flamethrower price is the only
  thing that moves the breach to a corner.
