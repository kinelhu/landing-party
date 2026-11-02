# Synthexis's swing between runs: a design consult (Fable, read-only, 2026-11-02)

Read: `DESIGN.md` (the fed nw and nwa measurements, 0.2.134 to 0.2.149), `farm.lua`, `herd.lua`, `herd_learn.lua`,
`know.lua`, `tactics.lua`, `attempt.lua`, `valuemap.lua`, `shared.lua`, the visit scenario in `tests/lp-sim/control.lua`,
`scripts/visit.sh`, and the logs of the 0.2.147 nwa run (`docs/sim/visit-nwa-rich-m147/`). Nothing run, nothing edited.

## 1. Why it swings

**A run holds a handful of draws.** A culture sends one wave at a time, `WAVE_GAP` (20 minutes) from the last launch
(`farm.lua:98`, `farm.lua:2081`, `last_wave` set at launch, `farm.lua:1480`). Ninety minutes is four or five launches
for one culture. nw had one culture and sent 2; nwa had five cultures and sent 7. The wave count the user compares across
saves is mostly a count of cultures, which the landing's field search sets (`farm.lua:166`), not a reading of the
defence.

**Each draw is bimodal.** The farm sends what it can field (`farm.lua:1160`: "it saves up for no bigger wave", the
2026-10-30 consult removed the saving timers), and sizes nothing to the place except cuts and raid probes
(`farm.lua:1326-1333`). The wave then runs an all-or-nothing gate twice: before marching, it turns home if its way in
costs half its strength there and back (`herd.affords`, `herd.lua:1088`, `DEAR = 1`; `herd.lua:1304-1316`, outcome
"too dear"); at the wall, it withdraws at half lost unless going out is dearer than staying, in which case it goes
deeper and razes until nothing has fallen for 90 seconds or 4 minutes have passed (`herd.lua:2746-2766`, `INSIDE_TICKS`,
`INSIDE_MAX`, `herd.lua:45-46`). A wave therefore razes about nothing (nwa waves 1, 2, 4, 5: rams failed, farm attacked,
died at the breach) or hundreds (wave 3: 88 in at a place "0 guns cover", 76 biters each at their own target, 247
targets in sight). The sum of five such draws has a standard deviation of the order of its mean. The odds formula makes
the gate sharp: `keeps_lost = 1 - 2 lost / (n HOLD)` with `HOLD 0.5` (`valuemap.lua:148-150`) reaches zero once the
way in costs a quarter of the wave; small differences in the cost map flip a place from "passes" to "cannot go in".

**One wave rewrites the prices.** A laser's price moves `PRICE_LEARN` (0.4) of the way to each sample, weighted by wave
size over 60, and a wiped wave only raises it (`know.lua:69-92`, `herd_learn.lua:107-116`). nwa wave 3 lost 508 mediums
to 5 lasers inside: sample 101.6, the price 29.4 at a stroke (`decisions.txt`, tick 31083002; cap `PRICE_MAX` 40). Every
laser-covered cell within 1,600 tiles is re-weighed on that one number for the next 40 minutes (`mind.fade`,
`shared.lua:290`). The ladder adds a second cliff: one fresh failure puts a method under `LADDER_HOLD` 0.75 for about 44
minutes (`tactics.lua:171-213`), two full gaps, so a culture that fails once at its best place changes target or holds.
Novelty does the same within 192 tiles of any trial (`farm.lua:555-566`). The pick among what is left is by chance in
proportion to score (`tactics.pick`, `tactics.lua:243`; `f.rng` seeded from the farm's id and the tick, `farm.lua:1090`).
Each of these is a sound rule; together they make the second wave's target a function of the first wave's luck.

**The census and the record count different things.** A wave's own figure is `razed_worth`, a sum of `valuemap.WORTH`
plus the defence's build cost (`valuemap.lua:13-47`): a solar panel is 0.5, a pole 0.5, a wall 0.1. The visit's tally is a
count of entities killed by force `lp-biotech`, whatever the wave (`control.lua:13452-13455`), and kills are credited to a
wave only while it is live (`herd.lua:3281-3284`; `finish` drops it, `herd.lua:2549`). The results line lists finished
waves only (`control.lua:8884-8894`). In the nwa run, waves 6 and 7 (198 biters) were launched at minutes 77 and 79 at
places costing 10 to 12 with no gun covering them, were inside a solar field from minute 87 ("670 targets in sight"),
and the run ended at minute 90 with both still out: unlogged, uncredited, and the source of most of the 1,553 (552
accumulators, 606 panels, 121 poles). "129 by its own count" was wave 3's worth, in other units, of another wave. Nothing
is wrong in the mod here; the report is.

**Repeating a visit measures nothing.** Factorio is deterministic and `visit.sh` takes no seed; the farm's rng is seeded
from the tick. Two visits of one save with the same code give one result. The twentyfold swing in `DESIGN.md:3776` was
three different builds (earlier code, armed, unarmed), each one draw of the process above.

## 2. Is it bad?

For a player, mostly no. The design asks for rare dramatic breaches ("the mega wave is an event", `farm.lua:77-85`), and a
wave that finds the undefended solar field and eats 600 panels in four minutes is the best lesson the mod teaches: the
soft heart was real, the costmap found it, and the fix is the player's. Four waves dying at the wall first is legible
pressure. What is bad is at the edges:

- On nw, one culture, 2 waves and 1 razed in 90 minutes is near absence. A faction that shows up every 20 minutes and
  turns home "too dear" without a shot fired is quiet in a way the player cannot read.
- The clock is a design value, not a reading. A culture with twelve incubators and a full stock waits the same 20
  minutes as one with four. Its pressure does not follow its growth.
- The price cliff. One wave inside a laser nest teaching "a laser costs 30" means every laser-walled place reads as
  impossible for 40 minutes, and the player sees the faction give up for no visible reason.

The variance across runs is the shape of the process, not a fault to engineer away. The thing to fix is that the mod's
pressure between events is thin and its reporting hides where the razing came from.

## 3. Options, ranked

1. **Send on stock, not on the clock.** Launch when the culture holds a wave's worth over its guard and no wave is out,
   with `WAVE_GAP` as a floor read from the breeding rate (a wave's price over biomass income a minute), not 20 minutes
   flat. More cultures already multiply waves; this lets one culture do what five do now. Test: visits of nw and nwa,
   plus `make_reference.sh laser`, 120 minutes, five seeds each (see 4). Statistics: waves launched an hour, share of
   waves that got in (`attempt.inside`, from `ops.jsonl`), razed an hour by census, and its coefficient of variation
   across seeds. Pass: more waves, the CV of razed an hour down, the mean not down.
2. **Size the wave to the place.** The cut already caps at the least that pays (`farm.lua:1330-1333`). Do the same for a
   raid at an unguarded place: send what `herd.affords` needs with a margin, keep the rest, and the next wave comes
   sooner under option 1. A place costing 10 gets 30, not 115. Test as above; add razed per biter sent.
3. **Soften the first sample.** Weight a price sample by `n / (n + k)` over the samples so far (a prior of k waves), so
   one wave moves a laser from 15 to 20, not to 29, and keep the floor rule. Test: scenario `siegelab` on the laser lane,
   two seeds of eight trials, read the price trace; pass if no single trial moves a price by more than a third of its
   value and the lane's razed per 100 lost (2.9 is the bar) holds.
4. **Scale the ladder's hold to the gap.** `LADDER_HOLD` sets a method aside for 44 minutes after one failure; with
   option 1 the gap shrinks and the hold should read it (one gap, not a constant). Test: `siegelab` as in 3, count
   trials where "no method worth it" held the farm with stock ready.
5. **Probes on, as information only.** The runt probe (`herd.lua:736-836`) finds silent guns at a face; the user turned it
   off for its look (`shared.lua:292-295`). Steadier pressure does not need it: the probe-siege on the menu
   (`farm.lua:1057-1068`, `1098-1129`) already sends a `WAVE_MIN` wave to learn a place. Rank it last; if tried, keep the
   runts within the herd's trail and measure share-in as in 1.

## 4. Measuring it

- **A seed for visits.** `LP_SEED` in `visit.sh`, written to `params.lua`, folded into `rng.new` for the farm and into the
  landing clock by a minute or two. Without it every visit of a save is one draw and no comparison is valid.
- **Five seeds a save, two saves and one reference factory,** 120 minutes (six gaps at the current clock). Report per run:
  cultures, waves launched, waves in, razed by census (start minus end per type, less `biter_razed` and the
  corporations'), razed by `syn_razed`, and the waves still out at the end. Report across seeds: mean, min, max and CV of
  razed an hour; the share of waves in; razed per wave in.
- **Fix the report first.** List unfinished waves in the results line with their stage and targets in sight, and print
  `razed_worth` beside a per-wave entity count so the two never read as one number again. This is the cheapest change in
  this consult and it removes the question that prompted it.
- **A regression bound.** `batch.sh` on the three saves and five seeds, 90 minutes: fail if the CV of razed an hour
  exceeds 1.0 or the share of waves in falls under a quarter. Both are measured now, not guessed, once the seed exists.
