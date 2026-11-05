# Adaptive tactics: a design consult (Fable, read-only, 2026-11-05)

Read: `CLAUDE.md`, `DESIGN.md` (the Synthexis rows, the findings 0.2.103 to 0.2.124, the idea entry "Tactics that adapt
to what kills it", the 2026-11-05 findings on nwa's north wall and the Tesla's drain), the consults of 10-30 (siege AI,
flamethrower) and 10-31 (counters and desperation), `tactics.lua`, `herd.lua`, `herd_learn.lua`, `farm.lua`,
`attempt.lua`, `know.lua`, `threat.lua`, `firemap.lua`, `costmap.lua`, `ops.lua`, `siege.lua`, `orbital.lua`,
`scorcher.lua`, `scripts/siegelab.sh`, `scripts/lab_compare.py`, `scripts/contract.py`, the game's `fire.lua`,
`turrets.lua`, `entities.lua`, `map-settings.lua`, Space Age's `turrets.lua` and `beams.lua`, and `runtime-api.json`
at 2.1.23. Nothing run, nothing edited. Line numbers are the working tree's.

## 0. What the mechanics allow (the game's data, not memory)

The user's question rests on three guesses: that spreading out drains flamethrower fuel, that it blunts the splash,
and that several points raise the odds of one hole. The data settles each.

- **Fuel: no.** A flamethrower turret spends 0.2 fluid a shot at a shot every 4 ticks (`fire.lua:886, 902`): 3 a second.
  Its buffer is 100 and its inlet flows `250 / 60 / 5` a tick, 50 a second (`fire.lua:532-534`). A fed turret refills
  sixteen times faster than it burns; it never runs dry, and it fires at the same rate whether a shot lands on one unit or
  ten. Spreading out changes nothing about fuel. Only a cut pipe does (33 s of buffer), which is the `cut` method already
  on the menu and the 10-30 consult's verdict stands.
- **Splash: partly.** Each stream landing applies 3 fire and a `fire-sticker` to everything within 2.5 tiles and lays a
  `fire-flame` on the ground (`fire.lua:1055-1085`). The sticker alone is 100 fire a second for 30 s (`fire.lua:966-969`):
  one tag kills every breed but the big burster (3,000 at 50% fire). The ground flame is 13 a second, times one more for
  each refuel within 10 ticks up to 6 (`fire.lua:330-345`): 78 a second a flame, and a crowd standing under a stream
  collects overlapping flames. The lab measured both regimes: a standing crowd lost 272 to 682 health a second a head, a
  crowd walking through 94 (the sticker alone; the 10-30 consult, section 1). So a loose stance cuts the damage rate at the
  wall by three to seven times, and does nothing to the sticker: everything tagged still dies within 30 s unless it is
  through and away. Spreading buys seconds at the wall, not survival.
- **Tagging rate is bounded by the turret, not the crowd.** The stream flies at 0.25 tiles a tick (`fire.lua`, the
  stream's `particle_horizontal_speed`): 2 s to 30 tiles. `fire_penalty = 15` (`fire.lua:891`) moves the turret to an
  unburnt target once the sticker lands. Trial 2 of the fed fort tagged 34 of about 38 behemoths with two turrets over a
  crossing of about 10 s: 1 to 2 tags a second a turret. Inferred from the recording, not measured directly. If it holds,
  what kills a wave of 200 is dwell: nwa's 160 flame deaths came from standing at the inner walls, not from the crossing.
- **Mines are area damage in earnest.** A land mine triggers at 2.5 and deals 250 explosion in a radius of 6
  (`entities.lua`, the `land-mine` action). A dense herd loses ten to a mine; a loose one loses one or two.
- **Lasers and teslas do not care about density.** One target a shot, cooldown 40 (`turrets.lua:693`); the tesla's chain
  jumps between targets (Space Age `beams.lua:300-357`, 120 electric a hit), so density helps the tesla and loose formation
  hurts it a little. Neither has a cooldown or refuel worth timing against on a fed network: the laser's buffer is 801 kJ at
  an inlet of 9,600 kW (`turrets.lua:616-617`), a twelfth of a second to refill.
- **Night** changes nothing for a turret. It changes everything for a solar base: lasers on accumulators brown out under
  sustained fire. That is a reading (accumulators' charge round the guns), not a rule, and it belongs to a later pass.
- **Formation in the engine.** A unit group bunches its members within `max_group_radius` 30 and `min_group_radius` 5
  (`map-settings.lua:113-114`), global map settings for every force and the wild biters alike. A loose formation cannot
  come from there. It comes from individual commands (what `hunt` does inside with `w.individual`, `herd.lua:2447-2521`),
  which the breach already uses for rams, screens and sweepers (`herd.lua:1754, 2103, 1862`).

## 1. What "adapting tactics" should mean here, ranked

The menu (`farm.lua:1014-1097`, scored by `tactics.expect`, `tactics.lua:201-240`) holds raid, cut, strike, siege and
probe. A tactic belongs on it if it has a distinct shape on screen, a distinct record in `tactics.record`, and a
mechanical reason to beat a siege somewhere. Four do; three do not.

**1. Rams in ranks, the herd held until the way is open.** The highest payoff on the user's own wall, and the one the
nwa run exposes. `sequence` releases the herd the moment one ram has set off (`herd.lua:2120-2135`, `w.big_set_off > 0`);
on a wall of four lines the blast of radius 6 (`shared.BIG_BURST.r`) opens the outer one or two, and the herd then stands
at the inner lines inside two flamethrowers' arcs, which is the dwell that killed 160 of 200. The learned answer to this
already exists: `herd.learn_reach` halves its reach share when every ram set off and the wave still stood at a wall
(`herd_learn.lua:188-192`, `stuck`), so the next siege brings twice the rams. They all go at the same outer wall at once.
The change is serial release: the first rank goes as now; once a gap is open and a wall still stands between the gap and
the target (the test `wall_between` already makes for the herd, `herd.lua:507-531`, and `WALL_TRIES` counts), the next
rank is ordered through the gap (`gap_way`, `herd.lua:539`) at the first wall piece on the line from the gap to the
target; the herd holds out of reach until no wall stands between the gap and the way in, or the rams are spent. No layer
is counted; the rams walk the layers. Legible: the bursters go through the hole one after another, each blowing the next
wall, while the herd waits. It costs nothing new: one more state in `sequence` and a `ram_order` with the gap as `lane`.

**2. The spread assault: many rams at many points, one herd for the first hole.** This is the user's idea, and the
mechanical case for it is the mines and the ground fire, not the fuel. Design it so that it needs no new unit groups:
the rams and the screen are already individuals (`send_big_bursters`, `herd.lua:1713-1763`; the screen, `herd.lua:2098-2109`),
so K breach points are K lanes for them, while the herd stays one group at one staging and rushes the first gap that
opens, wherever it is. That is exactly the "single hole" payoff the user named: K independent chances that a ram reaches
a wall, and the whole herd through whichever one does. Section 2 gives the geometry.

**3. A loose stance at the wall.** Where the herd must chew (no ram, or the gap closed by robots), its members take
individual `attack` orders at wall pieces spaced along the line rather than a group `attack` at two pieces
(`herd.lua:2021-2025` orders at most 2 pieces, the group bunches on them). The spacing is the stream's splash radius from
the prototype (the `area` radius of the fluid turret's stream, 2.5; `data-final-fixes` can write it into `lp-fire` beside
`arc` and `hits`), or the widest foe splash where mines or artillery killed (`threat.foe_splash`, `threat.lua:165-173`).
Not a method of its own: a stance the siege and the spread take when the area-damage share at that place says so.

**4. The second pulse.** DESIGN's open assumption, "a second wave through the same gap before the robots mend it would
get further". Hold a share of the herd at staging and release it at `t_inside` of the first. A tactic in time rather than
space, cheap, and the lab can test it with `LAB_REBUILD_AFTER`. Lower than 1 and 2 because it helps only where the first
pulse gets in.

**Not this pass.** *Feints* (a screen drawing fire at one point while rams go at another): turrets do not move, and each
fires only on what its own reach holds, so a feint pulls only the turrets whose reach covers both points, which is what the
screen at the ram's own lane already does (`herd.lua:2092-2097`); real against the player's mobile army, flavour against a
wall. *Timing against a cooldown or refuel*: none exists on a fed line (above); the cut-then-strike is already the
`strike` method. *Night attacks*: a real lever against solar power only, and only as a reading of accumulators; do not add
a clock.

## 2. The spread assault, concretely

**Where the points lie.** Candidates are the cost map's cells along the wall within one leg (`LEG = 60`, `herd.lua:952`)
either side of the plan's breach, each priced by `firemap.cost` on the plan's own map (`herd.plan`'s shared reading,
`herd.SHARED_FOR`). Each point's cover is `firemap.cover(map, p)` (`firemap.lua:127-131`), which already honours a
flamethrower's arc and minimum range (`firemap.lua:36-43, 54-60`). The rule for "far enough apart" is not a distance: two
points are distinct when no burning turret (`e.burn`, a fluid turret) covers both. Lasers may overlap; a laser fires on
one target at a time whichever point it is, and the fewer distinct guns the whole assault wakes, the better. The arc does
the arithmetic: a flamethrower 10 tiles behind a wall with `turn_range = 1/3` (`fire.lua:890`) covers about 17 tiles of
wall each way, so on nwa's line the points fall roughly 35 tiles apart, and on a line without flamethrowers the rule
degrades to "the cheapest cells a ram's blast apart" (`BIG_BURST_R`, as `send_big_bursters` already spaces targets,
`herd.lua:1742`).

**How many.** The rams decide it. `siege_size` already asks `k = ceil(1 / herd.reach(foe))` rams for one point
(`farm.lua:859`) and caps at `RAMS_MAX = 5`. A spread takes `K = floor(rams / k)` points, at most the distinct points
found, at least 2 (one point is a siege). With reach learned at 0.5 that is 2 points of 2 rams; at 1.0, up to 5 of 1.
The screen is one of the cheapest breed per gun covering each point, as `fodder = pl.cover` is today (`farm.lua:867`),
summed over points. The herd is sized as the siege's (`need`, `farm.lua:891-903`), not split: it pays the crossing once,
at whichever gap opens.

**Bursters with each group or concentrated.** With each point, by the arithmetic above; the herd concentrated. Giving
every point the full ram count would need `K × k` rams, and the user's cap on rams ("at most a handful") holds.

**Timing.** All lanes release together, by the rule `sequence` has for one (`RELEASE_N` of the herd at the wall, or the
screen drawn, or `RELEASE_TICKS`; `herd.lua:2148-2178`), read once over all points: a screen that draws fire at any point
releases every lane. Staggering would let the guns kill the lanes one at a time.

**The call.** `on_died` already records the first wall piece broken near the breach as `w.gap` (`herd.lua:3457-3464`).
Make it per lane (the nearest lane's point), and let the first gap at any lane fire the rush: the herd's held commands are
rebuilt from `gap_way(w, staging, gap)` plus the plan's legs past that point. Rams still walking at other lanes are not
recalled; they become the next rank (tactic 1) at the opened gap, or open a second hole, either of which the herd can use.
A lane whose rams were all killed short, with no gap anywhere, ends as now ("its rams failed", `herd.lua:2112-2119`).

**What it records.** One attempt, method `spread`, in `tactics.record` with `rams` the total and `breach` the point that
opened (or the plan's), so `history_near` and `best_size` read it as they read a siege's. `tactics.expect` needs no
change: a spread is scored from its own attempts once it has any, and before that from the prior in section 3.

**Unverified.** That rams ordered at K lanes from one staging walk their own ways without the engine's group logic
pulling them together (they are not in the group once commanded, `herd.lua:2234`, so it should hold). That the herd's
rush from the middle staging to a gap one leg away does not cross more fire than the plan priced: the rush should be
re-priced on the map (`costmap.path` from staging to the gap) and refused, lane by lane, where it costs more than the
plan's own breach did.

## 3. The signal, and how it learns without a ratchet

**The signal is the damage type, not the killer.** `know.loss` infers damage from the killer's prototype type
(`know.lua:158-162`): a fluid turret is fire, an artillery turret explosion, and a land mine is nothing (`land-mine` is in
neither table, so `dmg` is nil). The 2.1 event carries `damage_type` on `on_entity_died` (`runtime-api.json`, the event's
data: `cause`, `damage_type`, `entity`, `force`), which is right for the sticker too: a unit that dies of its tag far from
the turret still dies of `fire`. Record `e.damage_type.name` as the loss's `damage`, keep `killer` for the counters'
matrix, and both readers draw on the one record. Area damage is then `fire` and `explosion` by name, with nothing typed:
the set of area types could even be read from the prototypes (a damage type whose dealers in `lp-fire` and `lp-splash`
have a radius), but two names in `shared.lua` as a named prior is honest enough for a first pass.

**Where it is kept.** Beside `sent, spent, got` in each attempt's history entry (`tactics.record`, `tactics.lua:39-52`):
`area`, the share of what it spent (in mediums) that died to area damage, computed at the wave's end from `lost_worth_by`
keyed by damage type (one pass over a table of under twenty keys; the corporations the same from `know.losses` over the
operation's span, which `ops.lua:866` already reads for prices). Read as `tactics.area_share(r, sig)`: the faded mean over
the attempts that still speak (`tactics.history`, voided by reinforcement like the rest).

**How it fits `expect`.** The spread's option is built beside the siege's in `menu` with the same `gain` and `dist`, and
a `lost` of the siege's reckoning times `1 - a`, where `a` is the place's area share across its siege and raid attempts.
That is the prior: a spread is expected to save what area damage took. It is wrong in detail (section 0 says it saves a
part of it), and it does not matter: after one spread attempt at that place `expect` replaces the reckoning with the
record (`op.known`, `tactics.lua:233`), and from then on the spread competes on what it did. A place with `a = 0` gives the
spread the siege's price and no edge, so lasers-only walls keep the siege. The user's second question, "what the
corporations' assaults read", is the same share from the same record.

**No ratchet.** Three guards already in `tactics.lua` apply unchanged: `REPEAT` takes 0.3 off each pick made lately
(`tactics.lua:233`), the ladder sets a method that failed twice aside (`tactics.ladder`, `LADDER_HOLD`), and the pick is by
chance in proportion (`tactics.pick`). The share is bounded at 1 and faded, so it cannot climb; and it is per place, so
nwa's flamethrowers do not make every wall in the world a spread. What a ratchet would look like, and what to check
against: a spread chosen at a laser-only lane (the share there is 0, so its score equals the siege's and `pick` splits
them; acceptable), or a spread picked forever at one flamethrower lane after one success (REPEAT and `changes` in the
contract catch it).

**Cost.** At record time, one pass over the loss table. At weighing, one pass over at most five history entries per
option. At launch, K calls of `firemap.cover` on a map already read (K at most 5). Each second in `sequence`, K lanes'
release tests (`count_entities_filtered` within `RELEASE_R`), the same query the one lane makes now. Nothing per tick.
Against the 113 ms weighing (0.2.115) this is noise.

## 4. Kessler-Hayashi and Grubstake

**Its menu against a closed wall.** The pieces exist and the order is right: the orbital strike opens a lane along the
wall and shells the guns in reach of it (`orbital.lua:58-91, 199-224`; seven shells opened the artillery base), the
assault goes through the way the barrage opened (`open_way`, `siege.lua:95-145`) at targets by name, never walls
(`assault_targets`, `siege.lua:148-160`), with the first rank staggered (`RANK_STAGGER`, `siege.lua:1019`). What the menu
lacks is the case with no strike (cooldown, or a camp without `orbital_strike`): the mortars' fire plan takes roboports
then the weakest turret (`siege.lua:1573-1592`) and leaves the wall alone, so an assault at a closed wall goes at targets
"and the units' own pathing breaks the piece in their way" (`siege.lua:93`), where a line trooper's laser does 2 a shot to
stone (70% laser resistance, `entities.lua:3495-3496`). Add one rung: **the howitzer on the wall** where `open_way` returns
nil. A mortar shell is explosion, which stone resists 10 flat and 30% (`entities.lua:3482-3484`), so `threat.shells_for`
(`threat.lua:257-260`) prices a 350-health piece honestly, and `ops.mended_floor` (`ops.lua:1103-1131`) already reads the
robots' race to a piece: shell the wall only where the shells land faster than the robots return, else wait for the
strike. Legible: the howitzer turns on the wall, the robots race it, the assault goes through.

**Armour first.** A rank order, not a rule: rank by each unit's effective health against the damage types that killed at
that place (its prototype's resistances, which `threat.blow` already reads for the foe's shells), heaviest first. Readings,
no constant.

**The same signal.** Yes. Kessler-Hayashi's infantry against mortars, artillery or flamethrowers takes the area share
from the same record (`tactics.record` at `ops.lua:858-863`), and its answer is the line abreast it already has
(`form_line`, `siege.lua:1526`) spaced by `threat.foe_splash` instead of a column. One formation, one reading.

**Grubstake: nothing.** Its contract is `soft` (`contract.py`, `SOFT_ONLY`): it takes the outpost and leaves the wall.
A spread is a wall tactic.

## 5. The Tesla: disable or drain

The user asked whether Teslas incapacitate lasers while they fire. They do not: the drain takes 60% of the struck
turret's buffer (`scorcher.lua:92-104`), and a laser's 801 kJ refills at 9,600 kW, 1/12 s. The 2026-11-05 finding (five
Teslas never took a line on 20 MW below 82% charge) is that arithmetic. A bigger drain is the same arithmetic with a
bigger number: on a fed network it does nothing, on a starved one the present drain already drops the line.

**A short disable.** The API allows it: `LuaEntity.active = false` stops an updatable entity's operations and
`disabled_by_script` is readable and writable on turrets (`runtime-api.json`, LuaEntity; the exceptions are corpses, fire,
roboports, rolling stock). Assessment:

- *Balance.* The duration decides everything. The Tesla's chain is 7 jumps of 8 tiles (`units.lua:722`); three Teslas
  hold up to 24 turrets at once. A disable of 2 s refreshed each hit at a cooldown of a second or so holds a laser line
  off for as long as the Teslas live, which trivialises the defence the user accepted as legitimate. A disable the length
  of the game's own tesla stun, 30 ticks (`tesla-turret-stun`, Space Age `turrets.lua:779-785`, read from the prototype,
  no new number), with the Tesla's cooldown above it, suppresses a struck laser for a fraction of each second: a line
  under three Teslas fires at half rate or so. That is bounded, needs the Tesla alive in reach, and ends with it.
- *Counters.* Kill the Tesla (rocket and railgun turrets outrange it), space lasers past the chain's 8, mix in gun
  turrets and flamethrowers, which hold no charge. All visible on the map, all diversification, which is the 10-31
  principle for every counter.
- *Legibility.* A laser whose head stops under lightning reads; a drain that refills before the eye catches it does not.
  Set `custom_status` while held so the tooltip says why.
- *Perception.* `threat.firing` reads `disabled_by_script` as silent (`threat.lua:19-24`). A Synthexis wave that reads a
  fire map during a Kessler-Hayashi assault would price held lasers at nothing and learn from it. Mark held turrets in
  storage and have `threat.firing` count them as firing. Small, but it must be done with the disable, not after.
- *The dome.* No interaction by construction: the drain fires only from a corporation's Tesla on charged entities of the
  types in `CHARGED` (`scorcher.lua:93`), and the dome's anchor is not among them.

Recommendation: do not build the disable in this pass. The Tesla's worth hinges on how the drain fares against a real
factory's accumulators at night, which DESIGN marks assumed and the lab can measure (a solar lane). If the lab shows the
drain is a dead letter on every real supply, build the 30-tick disable with the perception guard, not a bigger drain.

## 6. Proof in the lab, and the checks that fail without each change

**Lanes and forts.** Three places answer the question: the lasers-and-flamethrowers lane (8 of 16 in 0.2.113), the
two-walls-mines-and-flamethrowers lane (6 of 16), and the user's own wall. For the last, a lane built as nwa's north wall
reads: `LAB_LANE="walls=4,gap=2,step=6,guns=laser+flame,inset=10,mines=none,tech=late"` (four lines, a laser every 6,
flamethrowers 10 back), so that the fed fort (`lab-plot-edit`) and nwa's own geometry are both in the matrix. Two seeds
of eight for each, as 0.2.113 did, and `lab_compare.py` side by side with the 0.2.113 runs as the control.

**What "worth keeping" means.** For tactic 1 (ranks): the two-wall variants' got-in rises (from 6 and 12 of 16) and the
siege's deaths by killer `flamethrower-turret` in `lost_worth_by` fall at the `inside` stage; the contract's `changes`
still passes. For tactic 2 (spread): on the flamethrower lanes, trials whose method is `spread` get in at least as often
as sieges did and lose fewer mediums to `fire` and `explosion` per trial; on the lasers-only lane the spread is picked no
more than a third of trials (the share there is 0) and the siege's got-in does not fall. For tactic 3 (stance): deaths a
second a head under fire at the wall (the half-second frames in `lab-rec`) fall from the hundreds toward the sticker's
100. For the second pulse: with `LAB_REBUILD_AFTER` one trial, the pulse through the standing gap razes more than the
first did. A result that does not move both got-in and the area share at the flamethrower lanes means the tactic is
flavour and should come out.

**Scenario checks** (each with the change undone once, as the project's rule asks):

- `herd` wallgoal, two walls: "its second rank of rams goes through the gap at the inner wall; the herd holds till the way
  is open" (ram 2's order targets a piece past the gap; `t_inside` set; seen failing with ranks off: the herd at the inner
  wall, not inside).
- `farm` siege: "a spread's points share no flamethrower's arc" (every pair of points, the intersection of their burn
  covers empty) and "a spread's rams sum to the siege's, its herd is not split".
- `farm`: "tactics: a place whose deaths were area damage raises the spread over the siege there" (two recorded attempts
  with `area` 0.8 at a place: the spread's `lost` under the siege's; at `area` 0, equal; seen failing with the prior off).
- `farm`: "tactics: the area share is a faded mean, never a sum" (three attempts, the share at most 1).
- `know`: "a death to a land mine is recorded as explosion, to a sticker as fire" (the event's `damage_type`, seen failing
  with the old inference: nil and fire).
- `herd`: "the first gap at any lane calls the herd there" (two lanes, the gap at the second, the herd's rush legs through
  it).
- `ops` (Kessler-Hayashi): "an assault at a closed wall with no strike shells the wall where the shells beat the robots"
  and "under area damage its assault forms a line spaced by the widest foe splash".
- `dev`: `/lp spread` and `/lp ranks` force each at a wall for looking.

## 7. What not to do

- No fuel denial in the fight, for the reason in section 0: the numbers say it cannot work on a fed line.
- No layer counting, no wall thickness, no "rings crossed": the ranks walk the layers (tactic 1), which the user already
  asked for in those words at 0.2.105.
- No fire resistance on a breed and no electric resistance on a hull; the 10-30 and 10-31 consults closed both.
- No change to `game.map_settings.unit_group`: it is global to every force and the wild biters, and it is a constant.
- No K unit groups from one farm for the spread: the lanes are individuals already, and K groups pathing from one gate is
  the one unverified risk the 10-30 consult flagged. Keep the herd one group.
- No second sizer: the spread is sized by `siege_size` and divides its rams; a `spread_size` would be the third decision
  model the 10-30 consult warned about.
- No night clock. If solar power is to be exploited, read accumulators and make it a `strike` variant later.
- No feints against turrets, and no Tesla disable longer than the game's own stun.
- No typed area-damage share threshold ("spread when over 40% died to fire"): the share scales the expectation and the
  record decides, as every other method's does.
