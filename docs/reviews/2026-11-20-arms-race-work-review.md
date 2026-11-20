# Review of the arms race work, 0.2.474 to b5cc1880 (Fable, read-only, 2026-11-20)

Commits reviewed: c621bdda (0.2.474, the arms race and labs as income), b2d47fbd (0.2.475, the research preset and
the science-tier cap), 0000e2e8 and 86af8e21 (the charts taken out of the manual), 3658758a (0.2.476, lasers reined
in), b5cc1880 (the first-lab fix). Nothing run: no game, no sim, no arena, no regression.

## The user's words, in order

- "Arms race is attractive. This will make successful sieges a real risk of whole base destruction though?"
- "Should we decouple tech budget from the current 'parts' corps use? I feel like we are balancing too much on a
  single point of consumption"
- "Arms race + labs now"
- "We should think about how to factor in the arms race into the difficulty settings"
- "Agreed on difficulty. Do all viz and we judge doc in hand", then the correction: they wanted to choose one
  visualization before anything went into the manual.
- "At the top of their research, the anti air trooper wins against everything? Am I reading that correctly?"
- "Yes" (to taking research off the anti-air trooper's attack and giving lasers damage research only)
- "maybe we present a couple power ladders on select units and call it a day?"
- "What is plate? And could we make it a little nicer?"

## What I read

CLAUDE.md; the brief `docs/reviews/2026-11-20-arms-race-consult.md`; `git diff 1200e1ee..HEAD` whole (48 files) and
each commit's message. Code: `landing-party/scripts/rd.lua` (whole, at HEAD), `tune.lua`, `shared.lua` (the trees,
RESEARCH_AHEAD, Grubstake's labs, kind_of), `settings.lua`, `ops.lua` (defence 533 to 541, the learned price 1070 to
1077, gun_prior 1747 to 1751, era 289 to 305), `intel.lua` 36 to 56, `know.lua` learn_price, `planner.lua` (the
research rule 303 to 325, lab_coming), `base.lua` (the busy-queue rules 826 to 850, lab_look, heal_labs),
`layout.lua`, `lots_grubstake.lua`, `units.lua` (the anti-air trooper, the sapper, the bomb drone), `control.lua`
(on_configuration_changed, the debug interface), `faction.lua` (rd.fund, rd.history call sites), `counters.lua` and
its three readers (`army.lua` 119 to 160, `director.lua` 1738 to 1761, `farm.lua` 31 and 683), `veterancy.lua` 74,
the locale, the changelog. Tests: the diff of `tests/lp-sim/control.lua` (techup, workshop, research, director
armylate, the LABS table), scenario compose (5925 to 5956), `scripts/regress.sh` (RUNS, QUICK, area_of_scenario,
areas_of_file). Scripts: `arms_race.py`, `power_ladder.py`, `research_timeline.py`, `manual_qmd.py`,
`settings_locale.py`, `arena_report.py` (score, export_counters), `arena.sh` 40 to 60. Manual: arrivals.qmd,
kessler-hayashi.qmd, grubstake.qmd, the generated eras, settings and units pages, `_variables.yml`. DESIGN.md: the
status row, the backlog (206 to 250), the corporate research section (2644 to 2770). Data: the vanilla and Space Age
technology prototypes (every finite technology naming laser, bullet, shotgun-shell, grenade, rocket, cannon-shell,
electric, flamethrower: its level, its kinds of pack, its effects), the prototype and runtime API docs for
`TechnologyPrototype.level`. The arena rows `docs/arena/results.jsonl` (4,932) and `late-results.jsonl` (612),
summed again with the report's own score. The chart draft `ladder-pairs-draft2.png` and `ladder_pairs2.py`.

## Verdict

**Not ready to ship as HEAD stands. One committed file is broken and nothing in the quick regression would see it:
`landing-party/counters.lua` was regenerated in 0.2.476 and now holds six rows with one column each (the player's
units against biters). The corporations' counter composition (army.lua), the director's strike tilt (director.lua)
and Synthexis's breed choice (farm.lua) read it and now find nothing; they degrade silently to untilted mixes.
Restore it from 1200e1ee before anything else.** The arms race itself is built the way the brief asked, with its
numbers read from the prototypes and its one typed number a named prior, and the tests that exist were seen failing
where the commits say so. The science-tier cap has a real hole for mixed tracks (electric weapons leak a seven-pack
technology at the player's era 3) and a slower one (categories held back by their tier catch up only at the next
purchase). The design question the user has to decide is that 0.2.476 overshot: the late arena is now more lopsided
in the player's favour than the early one (rocket trooper 20 of 20 at +71; the brief's acceptance band was +10 to +55
and none at 20 of 20), which is the state the brief rejected, in the other direction. Two design decisions were
taken without asking (Kessler-Hayashi's cannon shells put on vanilla's full ladder, and the science-tier cap that
moves Kessler-Hayashi's lasers from the player's era 1 to era 3); both are defensible and both are theirs.

## Findings, by severity

### 1. High: `landing-party/counters.lua` is gutted at HEAD (3658758a)

At 1200e1ee the file had 38 rows of about 40 columns each. At HEAD it reads, whole:

```
["lp-battle-tank"] = {["biter"] = 1.00}, ["lp-breacher"] = {["biter"] = 0.70}, ["lp-flame-trooper"] = ...
```

Six rows, the "biter" column only. Readers: `army.lua:155` (`counter_composition`: `COUNTERS[variant] or
COUNTERS[name]`, nil for every corporate kind, so `sc` stays 0 and every mix is untilted), `director.lua:1755`
(`strike_mix`, the same), `farm.lua:683` (`COUNTERS[name] or ... or {}`, so Synthexis's breed scores read 0). None
crash; all three stop doing what the faction AI audit built (composition, step 5). Scenario `compose` (control.lua
5943 to 5955) reads `COUNTERS[name]["gun-turret"]` for Kessler-Hayashi's kinds and would fail at HEAD (`best` stays
nil). It is in neither the quick set nor the biotech area, and `areas_of_file` maps `counters.lua` to biotech alone
(regress.sh:84), so `--changed` after touching it runs the biters' scenarios, not compose. No regression ran after
0.2.476 (b5cc1880 names the 0.2.475 run; the commits after name single scenarios).

Why it happened: `arena_report.py export_counters` maps the rows' labels back to prototypes through a regex over
`tests/lp-arena/batch.lua` whose keys are now display labels (`'battle tank'`, `'infantry (Serenity)'`, 38 of them;
I ran the regex). A regenerate from today's rows kept only the labels that still matched (the player's six) and the
one fixed column that is keyed by name. `docs/arena/results.jsonl` itself is unchanged since 1200e1ee, so the export
path, not the data, broke; and 0.2.476's `late-results.jsonl` rows were what ran through it.

Fix: `git checkout 1200e1ee -- landing-party/counters.lua` now; repair `export_counters`'s label mapping before the
next arena run, with a guard that refuses to write a table smaller than the one it replaces (the rule: a guard seen
failing, in both states); add `compose` to QUICK or map `counters.lua` to perception as well; run `compose`.

### 2. High (design, the user's call): 0.2.476 overshot the brief's acceptance band

From the rows, by the report's score, against the twenty corporate kinds:

| | no research | 0.2.474 late (DESIGN) | 0.2.476 late (rows) |
|---|---|---|---|
| Trooper | +10, 12 of 20 | +37, 16 | +54, 18 |
| Gun buggy | +17, 13 | +44, 16 | +62, 18 |
| Rocket trooper | +47, 17 | +59, 18 | +71, 20 of 20 |
| Battle tank | +8, 9 | +42, 13 | +53, 15 |
| Breacher | +0, 11 | +2, 10 | +23, 14 |
| Flame trooper | -23, 8 | -49, 4 | -44, 5 |

The brief's bound (section 6): the four main units between +10 and +55, none at 20 of 20, each within 15 points of
its parity row. 0.2.474 met it. 0.2.476 fixed two units (the anti-air trooper, now in its own category, and the
heavy laser trooper) by taking shooting speed off the whole optics track, and the late matrix is now more
one-sided than the early one; the rocket trooper has no counter left. DESIGN records this honestly ("the player
leads late more than early") but does not say it breaks the brief's band, and the user's "Yes" was to the two
changes, not to this result. Options to put to them: (a) keep speed on lasers and answer the two units themselves
(the skyguard already has its own category; the lance's edge is range 17 against 15, so its range or its ladder,
not every laser's); (b) laser speed at half vanilla's steps (a reading, not a typed number: speed ladder scaled by
the damage ladder's share); (c) accept the late lead as the power fantasy and say so in the manual. Measure
against the band either way; it is the gate the brief set and it was not applied as one.

Related: Kessler-Hayashi's tanks were put on vanilla's cannon-shell ladder in 0.2.474 (`shared.lua:185`, ordnance,
damage and speed), which at the top is the same ×10.6 that lasers were pulled off. The arena says the tank beats at
most 3 of 6 late, so the number is not the problem; the inconsistency is in the story ("its lasers take damage
alone" while its shells take both) and in the fact that nobody asked for ordnance.

### 3. Medium (bug): the science-tier cap leaks through the cumulative ladder for electric weapons

`rd.lua:255 to 261` builds `l[k]` as prefix sums over levels; `set_level` (312 to 325) then walks `j` down from `k`
while `l.tier[j] > tiers` and sets `l[j]`. A level with no technology has tier 0 and stops the walk, so whatever
higher-tier technology sits below it is granted. The electric ladder is `at[3]` from `electric-weapons-damage-3`
(seven kinds of pack, finite) and `at[6]` from `laser-weapons-damage-6` (five); levels 4 and 5 are empty.

Concrete failure: the player at era 3, research normal (tiers 4), Kessler-Hayashi buys optics 4 (allowed: laser's
tier is 4). `set_level(f, optics, "electric", 4, 4)`: `j = 4`, `l.tier[4] = 0`, stop, `r = l[4] = {0.7, 0}`. Its
shock troopers and tesla tanks get +70% from a technology the player reaches four tiers later; at optics 3 the same
call gives 0 (tier 7 at j = 3 walks down to 2), so electric goes 0, 0, 0, 0.7, 0.7, 1.4 by level and the cap is
non-monotone. Fix: sum at set time over `k' <= k` with `tier[k'] <= tiers` (and `tier[k'] > 0`), not a prefix sum
truncated at the top. Check: `debug_rd_track` has no tiers argument; add one and assert electric 0 at tiers 4 for
every level up to 6, seen failing at level 4 today. The rocket and cannon-shell ladders happen not to have the gap
(every level from their first names a technology), which is why workshop and techup pass.

### 4. Medium (bug): a category held back by its tier catches up only at the next purchase

`apply` (rd.lua:394 to 407) computes `tiers` once, when a level is bought, and re-sets every track then. Nothing
re-sets on an era change: `rd.reapply` runs only from `on_configuration_changed` (control.lua:125).

Concrete failure: Grubstake at the player's era 0, normal (tiers 1), buys hand-loads 1 (`tier_of` is the minimum
across categories, bullets' 1). Bullets and shells get level 1; grenades' first technology takes two kinds, so the
sapper's dynamite stays at 0 (correct). The player passes era 1. The sapper's grenades stay at 0 until Grubstake
buys hand-loads 2, which with 60 a minute and units at 900 to 2,500 competing can be an hour; if it is saving for
a unit, longer. The notice said "weapons 1: ... stronger explosives" when it bought nothing for them. Same for
rockets (level 3 and up at tiers 4 while 4 and 5 wait for 5). Fix: call the per-corporation body of `rd.reapply`
when `ops.era` changes (command.sync_tiers already hooks research finished), or each LAB_TICKS in `rd.tick`; it is
a few `set_*_modifier` calls. Check: era raised in a scenario with no fund, the held category rising within a
minute, seen failing today.

### 5. Medium (migration, "don't break working systems"): an existing save's Grubstake goes dark on update

`rd.gated("grubstake")` becomes true on any save loaded under 0.2.474 or later (labs defined, `town_off` unset).
From that tick: `rd.fund` returns before adding (rd.lua:48), so its research income is nothing until a workshop
stands; `rd.mix` (168 to 181) drops every unit its tree gave it (slug, sapper, scorcher, flak buggy, scavenger,
dozer); `rd.unit` drops its plates; `rd.has("salvage")` is false. The workshop comes only through the research rule
(launch pad open, a free street end, 150 parts over keep), minutes to never depending on the town. Kessler-Hayashi
had labs already, so only Grubstake regresses. `rd.reapply` sets the force's modifiers and nothing else; there is
no migration that plants a workshop, grants a grace, or at least keeps the fielded units until one stands. The
beta's players start fresh; the user's own saves (the visit saves) do not. Also on old saves `t.weapons` has no
grenade or rocket entry (reapply sets them 0) while `t.nodes.handloads` says k, until the next purchase (finding 4
again).

### 6. Medium (tests): what runs, what is checked, what is not

- **Scenario `research` runs in no regression.** regress.sh RUNS has `workshop`, `workshop fast`, `labs`, `breach
  arty`; neither `research` nor `research quick` (I grepped the RUNS line). DESIGN 0.2.475 lists it under
  "Checks". It is 160 minutes (quick: shorter) and it holds the only check of the busy-queue research rule. Either
  add `research|LP_MIX=quick` to RUNS or say in DESIGN that it is a design instrument.
- **New scenarios not in `area_of_scenario`.** `workshop` and `research` fall to the default `ops`; `techup` is
  growth. CLAUDE.md: a new scenario goes in the table.
- **techup's bound sits on its edge.** "At lasers 5 the raid it needs is one a garrison fields: at most 10"; the
  commit says the reading is 10. The bound was the brief's for lasers with speed; with damage alone the margin is
  zero and the next change to PER_TURRET or the plate will flip it with no information in the failure. State the
  present value and a band, or derive the bound from `rd.strength`.
- **A check whose label no longer says what it checks.** techup's "its level is the base game's, damage and
  shooting speed" now asserts `want[2] == 0` (control.lua, the 0.2.476 line). Rename it, or it will mislead the
  next reader of a failure.
- **"never past its cap" is self-referential.** `research`'s last check compares `tracks.optics.level` to
  `tracks.optics.cap`, both from `rd.summary`, which uses the same `tier_of`; it cannot catch finding 3 or 4. A
  cap check reads the force's modifiers against the prototypes, as techup's `cap_for` does.
- **Unchecked, from the brief's own list:** the learned-price normalisation (section 4, the one-line fix at
  ops.lua:1076 with "seen failing with the sample unnormalised": no scenario); `reapply` on an old save (a fork
  from before 0.2.474 loaded under HEAD: lasers at vanilla 5, electric capped); the tier hold-back catching up
  (finding 4); the electric cap (finding 3); forks before and after with research off identical (dormancy; the
  memory rule); fortress and siegetier against a researched camp (in the backlog, fine, but the siege is the thing
  the user feared and nothing late measures it); the reference-factory visits at full research.
- **Seen failing, as claimed and plausible:** techup speed (0.2.473 gave 0), workshop's fund (300 before),
  armylate (4% before ordnance), techup's needed (12 with speed left out). The workshop checks are the best of the
  set: income exactly banded, the kill and the rebuild both observed.

### 7. Low (documents and wording)

- `arrivals.qmd`: "Each lab standing adds 20 parts ... for each branch of research it serves" promises that two
  Optics labs pay twice. `branches_served` (rd.lua:124 to 134) counts branches with any lab, so they do not, and a
  player who razes one of two labs sees no change. Say "for each branch of research that has a lab standing".
- The setting labels say "a level ahead / behind"; the manual and the code say tier. One word.
- `lp-difficulty`'s description (locale 503) still says "strength, aggression and income"; `tune.research`
  multiplies by it too.
- The backlog has no item for the pending choice of chart, which is the one decision the user reserved; the
  scripts "stay for the choice" but nothing says a choice is owed.
- `levels_of(optics)` is 7 (laser-shooting-speed-7 is finite) so `rd.summary` and research.jsonl report `top = 7`
  while `gains` stops at 6 and the manual says 6. Cosmetic; it will confuse a reader of the timeline rows.
- `shared.RESEARCH_AHEAD.high = 1`, the same as normal: "High" buys pace only. Deliberate per the locale, but the
  user may want to know that two of five presets share a ceiling.
- The DESIGN 0.2.474 paragraph says "capped as before at the player's era + 1" and the next paragraph replaces
  it. Fine as history; the backlog and status row are current, which is what the rule asks.
- No em dashes in anything touched; the prose uses they/them; the manual's numbers come from `manual_qmd.py`
  (LAB_RATE, the levels from the dump, the preset's values from shared.lua), none typed.

### 8. Low (process and scope)

- Two design decisions were taken, not asked: the ordnance track (0.2.474, cannon shells on vanilla's full
  ladder, damage and speed) and the science-tier cap (0.2.475: Kessler-Hayashi's lasers now wait for the player's
  era 3 instead of 1, a large change in when the arms race starts; the user asked for the arms race in the
  difficulty settings, which the preset answers on its own). Both are reasoned in DESIGN and both are sound; they
  are still the user's to confirm, and the second changes the early game for every player.
- Grubstake's workshop makes its research raidable; `grubstake.qmd` before this work said "with no lab you can
  raid" as part of its identity (the 2026-10-14 trees consult). "Arms race + labs now" can be read either way. Worth
  one sentence to the user.
- "Do all viz and we judge doc in hand" was read as "put them all in the manual"; two commits undid it. The lesson
  is already applied (the draft lives in the scratchpad).
- A generated file (`counters.lua`) was committed without being looked at, after a run whose rows were not the
  file's stated source. The header says "from docs/arena/results.jsonl".
- The regression discipline slipped at the end: the last whole run is 0.2.475's; 0.2.476 touched units.lua,
  shared.lua, rd.lua and counters.lua and ran four scenarios.

### What is fine

The ladder is read from the prototypes exactly as the brief asked (`rd.ladder`: finite technologies, level from
the name as the engine parses it, kinds of pack per level), the only typed number is `LAB_RATE`, named and sourced
in the comment; `rd.strength` is now symmetric with intel's turret weight; the learned price is normalised in the
right direction and the prior (`PER_TURRET × weigh`) is already research-free, so the units match; lab income
stops for a withdrawing corporation and where labs are off; `tune.ahead` handles 0 and -1 (Lua truthiness) and
tests override it per corporation; the module-level ladder cache is derived data with at most one addend per
slot, so it is the same on every client; the first-lab override does what the b5cc1880 message says and the trace
through `pick` at era 2 gives Optics first and the siege works second; the busy-queue rule is guarded by
`lab_coming` and is dormant where labs are off; `settings_locale.py` fails loudly on a value it has no words
for; the eras table is generated from RESEARCH_AHEAD; the arena numbers in the commit messages reproduce from the
rows to the point; DESIGN's "Open" lines say what is assumed and what is not measured.

## 9. The chart draft (`ladder-pairs-draft2.png`)

What it does well: two lines per panel at one log scale, the ends labelled, the portraits say who without a
legend, the fourth step named on the point ("uranium rounds", "armor"), Okabe-Ito pair, no clutter.

What a player will misread or miss:

- **It says nothing about when.** The arms race is a race in time: who is ahead at era 2, at era 4, at the top.
  This shows only the top of both ladders, and a player reads "Kessler-Hayashi ends at ×21, I end at ×39" as the
  whole story, when for the first three eras the corporation is ahead (the brief's point, and arms_race.py's). One
  line of caption fixes most of it: "At the top of both sides' research. Earlier, the corporation is often ahead:
  its levels are yours, up to one tier past your era."
- **"Speed" is a flat step for the laser trooper with no reason given**, and "Round or armor" is doing two jobs. A
  player sees the orange line stall and wonders. Label the stall as the fourth step is labelled ("damage only") and
  split the x label: "Round" under the blue point, "Armor" under the orange one, or name the step "Best round /
  armor" once in the caption.
- **The pairs.** Trooper against laser trooper and tank against tank are the fights that happen. Breacher against
  shotgunner is not an obvious pair (grenades against an early infantry), and it is the panel where the corporation
  ends higher, which a reader will take as the message. If the third panel is meant to show Grubstake, gun buggy
  against buggy is the matchup the arena and the arms-race chart already use.
- **The scale of the portraits.** They take a third of the figure's height at A5 width; the data gets 55%. Smaller
  medallions in the panel's corner, or names only, give the lines room and let the fourth-step labels grow from
  5.2 pt (below the manual's smallest size on the page) to 6.
- **Honesty of the rank step.** Corporate units do rank (veterancy.lua:74), so the ×4.6 is fair on both sides, but
  the player's step bundles "best round" while the corporation's bundles "armor", and the trooper's step from
  Speed to Round is the uranium round the manual elsewhere calls a late item. Fine as long as the caption says the
  steps are "all of it", not a timeline.
- Small things: "×" ticks at 1, 3, 10, 30 but the top ends sit above the last tick with no gridline; the x labels
  are 7 pt against 5.2 pt annotations; the breacher panel's labels collide at the fourth step; the y label is a
  sentence that needs the definition (damage a second times health) somewhere.

Recommended: keep draft 2's form (the user asked for a couple of ladders on select units), add the one-line
caption on timing, label the flat step, consider the third pair, shrink the medallions, and show the user two
versions (with and without the medallions) rather than a third draft.

## Recommended next actions, in order

1. Restore `landing-party/counters.lua` from 1200e1ee; run `compose`; fix `arena_report.py export_counters` and
   give it a size guard seen failing; map `counters.lua` to perception in `areas_of_file`.
2. Put finding 2 to the user with the table above and the three options; whatever they choose, measure it against
   the brief's band and write the band into the arena's own check.
3. Fix the tier cap's prefix-sum leak (finding 3) and re-set on era change (finding 4), each with a check seen
   failing; add `research|LP_MIX=quick` to RUNS and the two scenarios to `area_of_scenario`.
4. Decide the migration for Grubstake on existing saves (finding 5), at least "fielded units stay until the first
   workshop stands", with a fork from before 0.2.474 as the check.
5. The wording fixes of finding 7 (the per-lab income sentence first), and the backlog item for the chart choice.
6. Then `scripts/regress.sh 12345 --changed` on the Studio before the beta, with growth, ops, perception and player.
