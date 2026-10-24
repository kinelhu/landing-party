# Faction AI: audit and the RTS pass (2026-10-23)

The user, after a hard-coded "every third Synthexis wave goes at Kessler-Hayashi" went in to make a balance target pass:
"Is hard coding such a thing really a good idea?" and then: "Globally you need to think modular and with the systems.
We already had a reckoning with bad habits when coding up the unit AI. Faction AI might need the same 'RTS best
practice' pass, be it for spending strategy, army composition, offensive action decisions, expansion decisions, etc."

Five read-only surveys (spending, army, offence and targeting, expansion, knowledge) catalogued every decision point
with its file and line. This page is their synthesis: what exists, what is wrong with it by RTS practice, the bugs found
on the way, the structure proposed, and the order to build it. `docs/ai.md` (2026-10-17) is the earlier map; its three
seams (stance, reactions, the unit pool) are built and stay. Its two open items, one target picker and the ladder's
thresholds, are part of this.

## 1. What exists, in one paragraph per family

**Spending.** Each settlement plans by a fixed priority list (`planner.lua` rules: power, fabricate, mine, fortify,
research, spread, defend, embellish, grow), the first rule that passes and finds a site wins, one at a time, only when
the build queue is empty. The thresholds are absolute part counts (fortify over 80, grow over 100, embellish over 60)
that do not scale with income, era or threat. War footing is all-or-nothing: at war and under its cap, non-essential
rebuilds wait. Exports drain everything above 300 even at war. Heists (strip, tap, skim, jumper) each gate themselves
three different ways and two ignore the reserve. Synthexis breeds whatever the engine spawns while it has biomass, and
can go into debt.

**Army composition.** A random draw from fixed weights per corporation (`army.lua:116`), filtered by level. Nothing
reads what the enemy fields; the arena's counter matrix is not used at runtime. The only adaptation is the tech tree's
trigger counts, after the fact, and a bought unit stays in the mix at a fixed weight for good. Cap: depots times a
constant, times hand-stacked multipliers (x1.5 at rung 2, x2 under a grudge). Special cases are wired into production
(railgunners for clearances) and into task picks (harriers first for intercepts, Shock troopers against artillery).

**Offence and targeting.** One operation at a time per settlement, chosen by a fixed if-chain (answer, battery siege,
hazard clearance, battery raid, strip, raid, siege, strip) rather than by comparing what each would be worth. The raid
score is one formula with seven hand-picked multipliers (x3, x10, x10, x0.2, x5, x2, an exponent 1.5). The siege picker
neither divides by defence nor checks its temper. The ladder is read at about twelve sites, each with its own
thresholds, one of them a lagging copy. No decision estimates its chance of winning: the nearest is a head count against
a defence number, bypassed in four cases. Nine-plus pickers each have their own idea of "nearest". Synthexis waves go at
the nearest target whatever its defence, and the every-third-wave rule is the worst offender in the codebase.

**Expansion.** Arrival order is hard-coded by corporation id (`phases.lua:65`). The next corporation to land is the one
with the fewest settlements. A site is the first one clearing 300 ore after a cascade of filters steered by five
module-level mode flags. Territory is "the farthest module's distance plus 24", so Grubstake's size follows where the
seed's ore lies (236 tiles on one seed, 80 on another) and one stray mine of it holds Kessler-Hayashi's perimeter back.
Growth gates are inline literals. Synthexis lands by distance bands from the player's spawn and ignores the
corporations' ground.

**Knowledge.** Every settlement keeps its own notes and they are not shared: targets per 32-tile cell, death markers,
threats, cooldowns, a rival's "held" score (the only exponential decay in the code), wrongs for reprisals. Defence is
counted three or four times over (seen turrets, markers, resist, held). Losses are recorded in four places under four
keys. Several stores never decay (resist, provoked, the herd's memory, the tree's `mended`), and one is written and
never read (`b.front`). Nobody records an enemy's army, a rival's strength, pollution sources, or who killed whom where.
Synthexis remembers nothing between waves.

## 2. What is wrong with it, by RTS practice

1. **Personality is code, not data.** Corporation ids and temper booleans switch behaviour on and off in about forty
   places (`soft_only`, `strips`, `prospects`, `hostile`, `cordon`, `provoked_only`, `serenity ==`, `"grubstake|"`). An
   RTS AI expresses a faction as weights over the same decisions: an aggressive faction weighs attack higher, a greedy
   one economy, a cautious one demands better odds. A boolean cannot be tuned, only flipped, and every new faction
   multiplies the branches.
2. **Priority lists where there should be comparisons.** The planner, the ops decider and the site search take the first
   option that passes, not the best one. A raid on a weak target always beats a siege on a valuable one; a site with 301
   ore beats one with 3,000. Utility scoring (every option scored on comparable terms, the best taken) is the standard
   answer, and it is what makes behaviour explainable: "it went there because it scored highest, for these reasons".
3. **No shared picture of the world.** Decisions read raw entity searches and per-settlement notes. RTS AIs decide on a
   faction-level blackboard: what it has seen of each other force (buildings, defences, armies), with memory that fades,
   threat or influence maps, and its own losses by cause. Without it, the factions cannot answer the questions the
   balance needs: who is strongest, who hurt me, who is a soft target, what is the enemy fielding.
4. **No estimate of outcome.** Committing a force without estimating whether it wins is how Grubstake fed 78 units into
   Kessler-Hayashi's walls in the system sim. A force-ratio estimate from unit strengths (the arena measured them) against
   known defence is cheap and turns "too strong, skip" into a graded choice.
5. **Composition blind to the enemy.** RTS AIs bias production toward what counters what they see. The counter matrix
   exists; nothing reads it.
6. **Magic constants tuned against one scenario.** Many comments say so ("occupy", "wfc1", "cordon"). They should be few,
   named, per-faction where they express personality, and checked by the system sim rather than one test.
7. **Duplicated and drifting tables.** UNLOCK vs caps, ECONOMY vs ESSENTIAL, TIERS vs LEVELS, two truce clamps, two
   APARTs, two POD_WAITs, the push formula twice, killer lists retyped in seven tree nodes, four truce readers.

## 3. Bugs found on the way (fix regardless)

- `rd.lua:305-307`: the tree's `mended` events are never pruned, so the jammer trigger only grows.
- Synthexis evolution has two writers: the clinic (`farm.lua`, every 10 s) and `herd.lua:810-816` (the wild's, every
  minute). They overwrite each other; the clinic's tests sampled right after its own write.
- `war.lua:50-58`: `at_war` returns the first player force in `pairs` order: with two players, an arbitrary rung.
- `siege.lua:87-116`: `choose_siege` skips `temper_allows` (marked ground, thieves' hours, a hurt camp, the soft rule).
- `farm.lua:276`: the probe's price is taken without checking the balance (biomass in debt).
- `strip.lua:60`, `tap.lua:180, 262`: spend without the reserve; `base.lua:467-471`: exports at war.
- `base.lua:490-501`: territory leaves out Grubstake's claims, its real ground, yet the radius is used as hard ground
  by the perimeter and the border.
- Dead code: `army.MIX` (only reached without a corporation), `army.UNITS`, `faction.apply_tier`, `b.front`.
- The Synthexis scout fails at once on most maps on Factorio 2.1 (being diagnosed separately): its waves come blind and
  turn home with every biter.

## 4. The structure proposed

Four layers, shared by all three factions, each faction a table of parameters. Nothing here is new to RTS AI; the point
is that every decision lives in one layer and reads the one below.

**Knowledge** (`know.lua`, per faction, shared by its settlements). One record of the world as this faction has seen
it, fed by its units' and buildings' sight (fog: it knows only what it saw):
- *Sightings*: enemy buildings by cell (kind, value), one defence estimate per cell (turrets weighted by research,
  replacing the four overlapping counts), enemy units seen by class (infantry, armour, air, splash, anti-air), each with
  a time and decaying.
- *Losses*: one ledger, by killer force, killer class, damage type, position and time (replacing four).
- *Grievance*: per other force, what it took from us lately (units, buildings, by value), fading by half-life.
  Reprisals, grudges and Synthexis's anger read this.
- *Smell* (Synthexis, and useful to all): polluting buildings by force near the faction's ground.
- *Strength*: own and estimated for each foe (garrison and seen army by class, turrets).

**Strategy** (`strategy.lua`, per faction, every few minutes). Scores a small set of goals from knowledge and own state,
times the faction's personality weights: grow economy, expand, arm, research, attack a foe, defend, raid for gain.
Its output is a posture and a budget split (shares of income for economy, army, research, operations), plus a focus
(which foe, which area). The ladder becomes a per-foe pressure value it reads, not twelve thresholds.

**Operations** (one picker for all operation kinds, and for Synthexis waves). Every candidate (raid, siege, strip,
clearance, heist, wave) is scored on the same terms: value of the target, times relevance (the strategy's focus,
grievance), times the estimated chance of winning (own available force by class against known defence, using the
arena's strengths), over cost (distance, time, expected losses). The best above a threshold is launched. Army
composition is chosen here too: the faction's base mix, biased toward the classes that counter what knowledge says the
focus fields (the counter matrix, exported from the arena to a Lua table at build time).

**Tactics** (as now). Raids, sieges, the herd's scout and breach, the unit AI: how an operation is carried out.

**Personality** (`shared.CORPS` and `shared.BIOTECH`): aggression, greed, caution (the odds it demands), patience,
preferred operation kinds, target preferences (soft, guarded, buildings, units), risk to its home. Grubstake's "soft
only" becomes high caution and a preference for unguarded targets; Kessler-Hayashi's "hostile" becomes high aggression
and low caution against the player; Synthexis's smell and grievance weights are its own.

**Explainability.** Every decision logs its best three candidates with their score components to `decisions.txt` (it
already logs choices; the components are what make "why did it do that" answerable, in tests and for the user).

## 5. Order, each step measured by the system sim and the regression

1. **The bugs in section 3**, and the Synthexis scout. Small, independent, and they distort every measurement.
2. **Knowledge**, read-only first: build the faction record beside the old notes, have the old code read through it
   where they agree (defence, losses), delete the duplicates. No behaviour change intended; the regression says so.
3. **The one picker and Synthexis targeting**, replacing the ops decider's chain, the raid formula's multipliers and the
   every-third-wave rule. Grievance and smell decide Synthexis's targets. The chance-of-winning estimate goes in here.
4. **Strategy and the budget**, replacing the planner's absolute thresholds with shares of income by posture, and the
   ladder's scattered thresholds with per-foe pressure.
5. **Composition from the counter matrix**, and the tree's triggers reading the one loss ledger.
6. **Expansion**: site scoring instead of the first-past-300 cascade, territory as held ground (claims included), arrival
   order and the next corporation from parameters.
7. **Personality consolidated**: the temper booleans become weights; each faction one table.

Steps 2 to 7 each end with the four-seed system sim against its targets (`docs/system.md`) and a full regression. The
balance targets are judged after step 3 and again after 5; the constants are tuned last, not first.

## 6. Calls taken (the user's to overrule)

- **Fog, not omniscience.** A faction knows what its units and buildings have seen, and forgets. Cheating AIs are easy
  but their behaviour stops being explainable ("how did it know?").
- **Synthexis on the same layers.** Its waves are operations picked by the same scorer, with its own personality
  (smell and grievance weighted high, caution low); its breeding stays the engine's by evolution for now.
- **No rewrite in one go.** Each step replaces one family of decisions behind the same tactics, so the game stays
  playable and every step is measured.

## Progress

- **Step 1 (done, 0.2.2):** the bugs in section 3 fixed (the territory definition moved to step 6), the Synthexis scout
  fixed (a wide corridor generated before it sets out, the engine's route, the herd marching its track); the targeted
  tests and the system sim on seed 4242 pass (its scout now loops and its waves breach).
- **Step 2 (first form, 0.2.2):** `know.lua`: each faction's losses (by killer force, killer, damage, place, value) and
  grievances; sightings merged from its settlements' intel. The tech tree reads its losses through it (its own ledger
  and `rd.tally` gone). The system sim checks every faction's losses are known to it.
- **Step 3 (done, 0.2.3):** Synthexis's waves are trials (`docs/biotech.md`): the user's call on what it targets,
  replacing smell and grievance. The corporations' raid picker, in three measured pieces:
  - *3a, odds:* `ops.odds` (the force it can send over what the defence needs, r; odds r^2 / (1 + r^2)) replaced the
    hard "needed <= what it can field"; each corporation's mind (`shared.CORPS[corp].mind`) sets the odds it commits at
    (Kessler-Hayashi 0.5, the old gate exactly; Grubstake 0.6) and caution (odds^caution: 1 and 2). Odds alone made
    every target it could win look alike: Kessler-Hayashi sent 41 at a Grubstake generator of defence 10.6 and took 108
    of its buildings in 40 minutes (`rivals` failed). What a defence costs is a term of its own: loss_aversion,
    value / (1 + defence)^1.5, the old discount, now named and per corporation.
  - *3b, relevance:* the seven multipliers are named weights in one function (`relevance`: pressure, battery,
    desperate, distracted, ground, grudge), a mind may set its own. The reprisal's fixed x5 (four losses at one camp in
    20 minutes) became the faction's grievance (know.lua): 1 + grievance / 10, at most 5; buildings lost count too.
  - *3c, comparison:* after the battery siege and the hazard clearance (defence first), a raid, a siege and a strip are
    weighed together, each by the corporation's preference (mind.prefer: Kessler-Hayashi raid 1, siege 0.5, strip 0;
    Grubstake raid 1, siege 0.5, strip 10, its "strips first" as a weight), each choice logged with all three scores.
    It replaced the fixed chain (raid before siege before strip; a thief's strip before all).
  - Measured: the 57 raid-heavy scenarios after each piece (3a 56 of 57 until loss_aversion, then 57; 3b 57; 3c 57)
    and the 44 siege-related ones on 3c (44).
- **Step 4 (first form, 0.2.4):** `strategy.lua`, a leaf: a settlement's posture (the army cap's multiple, the war
  footing's condition, how pressed it is) from its rung, a fresh grudge and its recent losses (know.lua), refreshed
  every 10 seconds by war.lua; army.cap and the footing read it, the planner holds its lamps and paving while at war.
  The threat term (losses arming a faction) ships off: at 0.5 Kessler-Hayashi, hit by Grubstake's first raids, armed
  half again, went on a war footing and took Grubstake's camp to two buildings (`rivals`): a runaway. Restructure
  first; how much losses should arm a faction is tuned last, against the system sim. Budget shares for the planner wait
  for that tuning too.
- **Step 4, second form (0.2.7):** the budget by posture: the posture carries `keep`, the parts the planner leaves in
  hand for the army (its shortfall against its cap, at the mean price of its mix, times keep_peace 0.25 or keep_war 0.5)
  before walls, growth, spreading, labs and lamps. The threat term counted net (each foe: what it lost to it less what it
  made it lose, so only the side losing an exchange arms) and measured apart from the budget (system 12345 and 777):
  the budget alone held every target on 12345; the threat alone armed the losing Grubstake to a garrison of 70 against
  Kessler-Hayashi's 38 and missed shapes. The threat stays off: arming the loser erases the corporations' shapes.
- **Step 5 (0.2.4):** the counter matrix in the game. `scripts/arena_report.py` writes `landing-party/counters.lua` (each
  unit's arena score against each foe kind, each line and the biters); `army.composition` tilts the mix toward what
  answers its killers of the last 20 minutes (know.lua), by its mind's counter (Kessler-Hayashi 1, Grubstake 0.5).
  Scenario `compose`: six Line troopers killed by gun turrets; railgunners x1.70 and tanks x1.43 in what it builds.
  The arena's results predate the drones: rerun it to price them and refresh the table.
- **Step 6 (deliberately small, 0.2.4):** the arrival order is each corporation's (`arrives`, early or late), not two ids
  in phases.lua. Not done, with reasons: site scoring over all eight directions (each candidate generates up to 25
  chunks in a tick; the search stops at the first rich site because evaluating them all stalled landings by over a
  second); territory with Grubstake's claims (section 3 was wrong: a claim has its own map mark by design, and the disc
  is the camp; claims added would also have widened what holds Kessler-Hayashi's line back).
- **Step 6, site scoring (0.2.8):** done the way the stall allowed: an asynchronous landing already waits for its
  candidates' ground (requested, not forced), so every clear and rich candidate of a ring is scored by the corporation's
  `mind.site` (ore, nests on the way to the player, nest density, distance from rivals) and the best taken; a direct
  landing keeps the first. Grubstake and Kessler-Hayashi swapped sites on seed 12345. Measured: shapes 2 of 4 seeds
  (1 before), fights unchanged.
- **Step 7 (first form, 0.2.4):** dispositions as weights, capabilities as flags. Grubstake's soft_only exposure gates
  (rival and player targets) are its mind's `max_exposure` (1.0; none for Kessler-Hayashi). The temper's other flags
  (strips, skims, taps, jumps, pact, night, prospects; cuts, bills) say what a corporation can do at all and stay
  booleans; soft_only's other uses (a raid breaks when its foreman falls, a provoked thief's half answer) are behaviours
  of its kind and stay too.
