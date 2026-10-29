# Landing Party, the whole mod: an outside consult (Fable, read-only, 2026-10-29)

Read: CLAUDE.md, DESIGN.md (the status table in full, premise, principles, the faction, settlement, economy, army and
player sections, the legibility audit, balance, fought capture, the factory instrument, engine notes, the findings log),
README.md, docs/arc.md, docs/grading.md, docs/campaign.md, docs/ai.md, docs/ai-graph.md, docs/biotech.md, docs/units.md,
docs/playtest.md, docs/system.md, the two night reports, the faction AI audit (2026-10-23), the perception consult
(2026-10-27) and the faction parity note (2026-10-29); the code: control.lua, shared.lua, settings.lua, info.json, the
locale, herd.lua, farm.lua, creep.lua, ops.lua, know.lua, firemap.lua, costmap.lua and the headers and function lists of
the rest; tests/lp-sim/control.lua, scripts/regress.sh, sim.sh, check.sh and the lints; the uncommitted diff on `muster`;
the local `docs/sim` results (605 runs with a tick cost recorded); the runtime API reference at 2.1.23 for the names the
code leans on. Nothing was run; a regression was in progress. Counts below are from `wc`, `grep` and `awk`, not memory.

## The numbers that frame everything

- Seventeen days, 273 commits, version 0.2.88. The first commit is 2026-10-12. The version ran from 0.2.32 to 0.2.88
  across twelve commits in the last four days, nearly all of them Synthexis's sieges against one megabase save.
- The mod: 27,849 lines of Lua in 93 files. The four biggest: herd.lua 2,975, ops.lua 1,812, layout.lua 1,721, farm.lua
  1,639. The longest functions: siege_step 388 lines, herd's step 345, ops's step 315, farm's send 311, ops's launch 268,
  herd's hunt 233. 686 named constants in scripts/; 60 hard-coded faction ids outside shared.lua, 31 of them in herd and
  farm.
- The tests: one file of 11,664 lines holding 127 scenarios and 135 named mixes, 703 check calls and 882 remote calls into
  the mod. regress.sh lists 249 entries whose minutes sum to about 5,750 scenario-minutes (the seven forked ones run only
  their last minutes). The full list takes about 40 minutes; `--quick` is 31 entries.
- The documents: DESIGN.md is 3,562 lines, and its "status at a glance" is 157 table rows, some over 1,500 characters.
  The section "First contact: the baseline" is 1,193 lines. docs/ holds 10,686 lines, 37 of them consults in reviews/.
  "the user" is quoted 193 times in DESIGN.md.
- What a person has played: the showcase of 10-13, a session on 10-16, the labs save on 10-21, screenshots on 10-22, the
  deathworld playtest of 10-26 and watch saves of sieges since. docs/playtest.md lists 67 numbered things to look at;
  by its own first line, "none of it played". Roughly sixty versions of Synthexis have never had a human in front of them.
- Performance: the sims run at a median 0.97 ms a tick (p90 1.96) on small maps. On the user's nw save, five cultures ran
  5.05 ms a tick against 0.69 for the save alone, which is a frame budget (16.7 ms) spent a third on one mod.

## Verdict in one paragraph

The premise is excellent and unusual: adversaries with an economy you can strike, each with a personality you learn, on
Factorio's own rules. The three factions are distinct on paper and in code, and Synthexis's reasoning (prices learned
per weapon, a cost map, a plan it follows, a siege when nothing pays) is beyond anything the enemy-mod space has shipped.
The engineering discipline is also rare: a scenario per mechanic, forks, lints, a generated AI graph that fails the
check when stale, a findings log that keeps each bug as a guard. But the mod is a research engine, not yet a game. It has
been built almost entirely headless, the player-facing surface (what you see, what you can do, why it happened) lags the
mechanics by weeks, and the last week optimised Synthexis against a megabase the design had decided on 2026-10-16 was
not the target. The project is healthy as a laboratory and at risk as a product: the loop is sim, number, mechanism,
and nothing in it asks whether a player would enjoy or even notice the result. The single most valuable act now is to
stop adding and play two hours on an ordinary map.

## 1. The player's experience

### What a player meets, in order

**Hours 0 to 2.** A chat line when they build a radar: a wreck 180 tiles out with salvage in it. At oil processing a
survey party lands 450 tiles out on ore; destroying it yields a command core and delays what follows. These are the
only chat notices a player gets by default. They are good: they set a tone and ask a small decision.

**Chemical science: Grubstake.** A camp 300 to 500 tiles out, grown as a town of gravel streets and junk yards (0.2.26,
0.2.27), unwalled but for its pad. Then, by night: a truck parks at an exposed belt and skims it; a raid walks in and
dismantles machines one by one, leaving ghosts; chests are emptied; a pylon line creeps to an exposed pole and taps the
power; a rig digs in by a chest and hands come up a mound; a lit stake appears on the undrilled patch nearest the base
and ten minutes later a claim with drills. A radar-sized pacifier antenna by the camp keeps the wild biters off it. The
answers are specific and good: cover belts, underground across exposed stretches, kill the truck and the load spills,
kill the leader and the raid breaks, stake or drill the patch, pay at a trade post for a truce.

**When evolution reaches 0.25: Synthexis.** A pod comes down at the edge of the pollution cloud on a nest field with room
(0.2.24, 0.2.25). Captive-spawner incubators, violet creep with green tumors, white-suited technicians walking from a
Gleba substrate to biochambers, a biolab clinic. A pale cyan scout circles outside turret reach and sits at a face; a
green dashed trail and mud lead back to the farm; the herd walks it and breaks in where the scout sat, going for power,
the inserters feeding guns, radars and roboports. Later: bursters held back then rushed at the wall where one held,
carriers founding new cultures, and against a wall it cannot cross a siege of runts on the mines, big bursters at the
guns, a herd punching through to the heart. On deathworld settings this arrives within minutes; on default settings it
arrives somewhere in the mid game.

**First rocket: Kessler-Hayashi.** An orbital barrage on nests, a camp on space-platform plating, railgunners in
charcoal, at war from landing. Drones build a line of lit posts that walks toward the base, a dark stripe post to post,
a named warning before it encloses a building; near the base it closes with wall and gates the rails. Belts and pipes on
its edge blow up every 30 seconds. Raids by value with leaders; mortar sieges with a howitzer truck that deploys and
packs up; a jammer mast that downs robots; a power strike at the one pole that darkens the lasers; a cordon that
strangles outposts and then the next ore field. An invoice post at the line bills the player for the biter waves their
pollution sent through its ground; paying buys the only quiet. Labs per branch, a size up, that research only while
they stand.

**Late.** Headquarters landings (fortress and uplink), grudges when a lander is killed, reliefs by pod or column, the
ladder (rungs at 10, 20, 30 minutes without a raze), standing down after an hour of fruitless war, convoys of exports to
the uplink. The player's own side: a barracks with five orders (trooper, breacher, rocket trooper, flamethrower
trooper, battle tank), rally beacons as constant combinators, a command relay for bandwidth, a muster point, a threat
scanner, a box-select command tool, and eight technologies researched from rare components that drop from the factions
(cluster shells, pheromone bait, pact breaker, claim marker, rail rifle, orbital strike, border stake, trade post).

### What is memorable

The line that walks and the gate across your rails. Ghosts left where Grubstake took your machines apart. The scout,
the trail and a wall opened by a burster where the last wave failed. The invoice. The howitzer's deploy window. Towns
you can drive through. A carrier crossing the map with an escort. These are the mod's identity and each is a thing the
player sees and can act on. They are also almost all from before 2026-10-23; the week since has deepened what is under
them rather than adding to this list, which is the right instinct if it had been played.

### What is confusing or invisible

- **Half of raids turn back unseen** (grading.md: 26 of 52, 24 of 59). The player never learns that their defence was
  read and declined. Nothing has changed this since 10-16.
- **No chat by rule, and the world does not yet tell the rest.** The legibility audit of 10-20 listed nine gaps; the
  rebuild ghost, occupation sign, howitzer pad, ladder sign, research plates and grudge signs are still open. The rule
  ("the world tells you") is right; the backlog it created is not worked.
- **Two economies the player cannot read.** Parts (the corporations) and biomass (Synthexis) decide everything and
  appear nowhere. A player cannot tell a camp that is rich from one that is starving, a culture saving for a siege from
  one that is idle. The watchdog can; the player cannot.
- **The player's army is an RTS inside Factorio with no onboarding.** A rally beacon that is a constant combinator whose
  signals are orders, bandwidth from relays and research, a muster point, a selection tool with four mouse gestures.
  Capture by holding "fails since before 5281d15 (open)" and fought capture "no squad wins yet" except at 20/10/10 with
  level 3 research. A veteran Factorio player has no mental model for any of this, and the arena, which is where it
  would be learned, is a dev tool.
- **Eight technologies behind rare drops** that the player meets only after killing things they may not know to kill.
  Three stake-like items (border stake, claim marker, claim stake) with three different meanings.
- **Why.** Every reason lives in decisions.txt and ops.jsonl. The faction's intent, which the premise says the player
  should read, is a trace file.
- **Pacing is undefined on a normal map.** Every number in the playtest kit is for deathworld10x or nw. On a default
  map with default evolution, when does Synthexis land relative to chemical science and the first rocket? Nobody knows;
  it has not been measured on that map, and the three arrivals could stack or leave an hour of nothing.

### What is missing

- A player-readable summary of the factions: standing, what each is after, what it claims, its recent incidents. `/lp
  list` and `/lp incidents` exist for admins; the player has map labels.
- An end, or a statement that there is none. The uplink's fall is "optional", the campaign frame proposes four
  corporations and endless mode, and neither is decided.
- A non-turret answer per faction (arc.md decision 2, "open" since 10-16). Engaging pays on the gate instrument only
  when a strike on Grubstake's yard succeeds; failing makes it worse. Against Synthexis the answer is still a wall,
  turrets, mending holes, and a cleaner factory. Against Kessler-Hayashi, paying.
- Compatibility: nothing on other enemy or biter mods, multiplayer, or saves across versions (one migration in 17
  days of changing `storage` shapes; `on_configuration_changed` heals two things).

### Do the factions feel distinct, and how do they interact

On paper, fully: a thief by night at the edges, a wall that walks and bills, an infestation that eats your smoke and
learns your guns. In code, Kessler-Hayashi and Grubstake are one engine with different weights and flags, which is the
right way to do it; Synthexis is a separate engine with a separate perception layer. Whether they *feel* distinct
depends on things that have not been watched: whether a raid that turned back reads differently from one that was
never sent, whether a town reads as Grubstake's before you see its colour, whether the scout is noticed.

The interactions are coherent and pollution is the hidden currency binding them: the player's cloud draws wild waves
that Kessler-Hayashi bills, feeds Synthexis's cultures and lands them closer, and Grubstake's drills add to it while
its pact sends the wild waves on to the player. Grubstake and Synthexis keep a lasting truce; Synthexis attacks
Kessler-Hayashi only when struck, while Kessler-Hayashi clears its incubators as nests, so their war comes for free;
Kessler-Hayashi and Grubstake raid each other with reprisals read from one grievance ledger. This is a real design and
nobody has told the player it exists. Two things to verify by a check rather than a sentence: that Kessler-Hayashi's
ledger never bills a Synthexis wave (biotech.md promises it; I found no scenario asserting it), and that a Synthexis
siege turning on Kessler-Hayashi's camp on the march (0.2.85) does not make the camp fall more often than the system
sim's "survive" target allows, since that was measured only in the nw breach lab.

## 2. Scope and coherence

### The core

Three adversaries with an economy the player can strike, each with one way of taking things that changes how the player
builds, their intent readable in the world. Everything in the premise and principles supports it, and the pieces that
carry it are the ones listed as memorable above.

### What has sprawled

Counted against "a feature earns its place by changing a decision the player makes" (arc.md):

1. **The player's army and command layer** (player.lua, command.lua, five units, beacons, relays, bandwidth, the muster
   point, the arena with its GUI, three scripts). It is the second-largest system in the mod that is not an adversary,
   it does not win fights it starts, and it is the hardest thing in the mod for a Factorio player to learn. It exists
   because the arc needs "the player's army taking a camp" as a non-turret answer. It has not delivered that and has not
   been touched since the flamethrower trooper (0.2.5).
2. **Grubstake's six heists** (skim, dismantle, tap, jumper, prospect and road, trade). On the four real-save visits that
   graded them (10-16), strips, loot and taps fired zero times; prospecting was added after. Nobody has re-graded since.
   A thief whose tricks fire once an hour is a thief the player meets as raids.
3. **Eight player technologies from six components.** Gated behind drops the player has no reason to seek. Fewer, met
   earlier, would teach more.
4. **The campaign frame** (four corporations, Lumen and Concord, endless mode, contracts, leverage) is documented in
   two files and built nowhere. It inflates every design conversation.
5. **Headquarters, uplink, prize, withdrawal** (`hq`, `uplink`, `fall`): built early, "defaults chosen without the
   user, to review", not revisited since, and the fall's capture by holding is broken.
6. **Architecture as a product**: WFC compounds and districts, lobed plates, towns of 33 lots and 239 variants, piers,
   landfill, cliff blasting. Beautiful work, and worth it once the player is looking at camps; it has been looked at in
   screenshots.
7. **Synthexis against nw.** From 0.2.33 to 0.2.85 the version number moved about fifty times on sieges against a late
   megabase with a 50-laser wall, flamethrower lines and minefields. The design decision of 10-16 reads: "Not built for
   megabases. The target is the mid game." The perception stack it produced (threat, firemap, valuemap, costmap, feeds,
   know, unit_prior, about 1,400 lines) is good and reusable; the week spent tuning big bursters, sweeps and
   punch-throughs to reach nw's economy was spent on the one case the design excluded. The parity note now proposes
   bringing the corporations to the same level, which is another month of the same loop.

### What to cut, merge or finish before anything new

- **Cut from the first release, keep in the tree behind a startup setting:** the player's army and command tool, the
  arena. Decide later whether it is a second mod.
- **Merge:** the three stake items into one or two with a clear grammar ("this is mine" and "this is yours"); the six
  heists into the three that fire on a normal base once that is measured (my guess: skim, dismantling raids, prospect
  and road; the tap and the jumper fold into the raid as flavour where the ground allows).
- **Finish:** the legibility backlog of 10-20; a faction summary the player can open; capture by holding or its removal;
  the Synthexis ledger check; pacing on a default map.
- **Stop:** the parity programme until a human has watched the corporations and said they read as dumb. The audit's
  structure (knowledge, strategy, one picker, personality as weights) was the right pass and its first forms are in;
  priced routes are a day's work when wanted, and the regression will say whether they changed anything a player sees.

### Where tuning by numbers substitutes for clear rules

The corporations' rules are mostly legible: a planner priority list, a soft-targets-only thief, a corporation hostile
from landing, a truce for payment, a ladder at 10, 20, 30 minutes. Where they become numbers it is honest about it
(`min_odds` 0.5 and 0.6, `caution` 1 and 2, `loss_aversion` 1.5, `prefer.strip` 10, `PER_TURRET` 3.5 plus 4, `per_turret`
6 and `per_wall` 20) and each number carries a comment naming the one scenario it was set by, which is the tell: a
constant tuned against one scenario is a rule nobody can state.

Synthexis is where numbers have replaced rules. `BITE_SHARE` 0.4, heart worth 1.5 times the edge, `GROWTH_SHARE` a
third and `YOUNG_SHARE` a half, `GROWTH_HOLD` 450, `PER_TARGET` 3 and 8, `LOOP_SPARE` 3, `STRAY_FAR` 60, `REGROUPS` 3,
`FIRE_LOSS` a tenth in 15 seconds, 20 units' benefit of the doubt, a hidden price per breach, a laser's prior from its
owner's research, a flamethrower's 17 "whatever its research", calibration measured and switched off because the bolder
setting razed more. Each was set by three timings on deathworld or one visit of nw. The player will meet none of these
as a rule they can state ("it comes where I am weak", "it waits when my wall is too dear", "it comes back through the
hole") unless the behaviour is coarse enough to survive the numbers. The test of a rule is whether the playtest kit can
write it in one sentence a player could verify; items 64 and 65 do, most of the siege's internals do not.

The same holds for the system sim's five targets: "even" and "fights" and "shapes" are judged by thresholds (500 tiles,
minute 45, buildings lost) chosen to be met by four seeds. They catch regressions; they do not define good.

## 3. Engineering health

### Module sizes and boundaries

The layering described in docs/ai.md and drawn by ai_graph.py is real and checked (the graph fails `check.sh` when
stale). The leaf modules are clean (siege, command, construction, wfc, perimeter, strip, know, pool). The problems:

- **herd.lua** is a 2,975-line state machine (scout, gather, march, breach, inside, withdraw, blind, siege sequencing,
  rivals on the march, learning, logging) with a 345-line `step`, a 233-line `hunt` and a 190-line `mark`. It will take
  the next bug an hour to locate. The seams are visible in the function list: plan (plan, affords, way_cost, spread),
  march (march, ensure_group, replan, home legs), breach (sweep, detonate, send_big_bursters, sequence, release_bursters,
  hold_breach), inside (hunt, targets, stay_begin, stay_end, hearts_from, deep_plan), learning (learn_price, learn_march,
  learn_scale, lesson_near, hidden_cost). Five files of 400 to 700 lines, each testable alone.
- **farm.lua** is the same for the colony (site, land, seed, carry, order, fulfil, send at 311 lines, evolve, recycle).
- **ops.lua** carries both corporations' operations, their decider and the raid, strip and thief mechanics in one 1,812-
  line file with `step` at 315 and `launch` at 268, and 17 requires; it is also the hub 16 modules require. The audit
  proposed one picker and it is in; the file did not shrink.
- **control.lua** calls 34 module tick functions every tick in one handler, in a fixed order, each with its own modulo.
  It works and it is fast enough today; it also means no module can be disabled or profiled from outside without the
  `storage.*_off` flags (there are about 40 of them in `debug_tune`).
- **Synthexis is not a faction in the data model.** `shared.BIOTECH` says "Not one of CORPS yet"; its force, truce,
  target rules and hostility live in 60 string comparisons across 17 files, 31 in herd and farm. The parity note's split
  analysis is right that the realistic shape is a core plus two halves; the first step toward either outcome is a
  `shared.FACTIONS` table with Synthexis in it and `is_corp` replaced by capability flags.

### The test harness

The approach is the project's great strength: a scenario per mechanic with assertions, forks keyed by the code's hash,
`finish_early`, a watchdog with four invariants, a death map, oplog panels, an arena, reference factories, a system sim
with named targets. Few mods have any of this. What will hurt:

- **One 11,664-line file.** 127 scenarios share helpers by position in a file nobody can hold in their head; two
  scenarios were once deleted by an edit to a neighbour (regress.sh guards against that now). Split by area
  (corporations, Synthexis, player, system, shared helpers), loaded by the test mod's control.lua.
- **Time grows with every mechanic.** 249 entries, about 40 minutes full, and the list grew by roughly ten entries a day
  in the last week. There is no budget. Three tiers would hold: a smoke set under 3 minutes for every edit, the area's
  set for the day's work, the full set nightly or before a tag. Long entries (hazard 75, farm siege 90, farm found and
  moat 60) should run from forks or end early; each scenario's wall time should be recorded in the run's results so the
  slow ones are visible.
- **Checks are thresholds set by the seeds that passed.** DESIGN.md names two that "flip with timing" and the siege test
  was rewritten this week to check what a siege is for after a growth change moved its wave. "Seen failing" appears
  eleven times in DESIGN.md and zero times in the test file: the guard-proof is in prose, not next to the check. A
  comment on each check naming the commit that broke it would make the next rewrite safer.
- **The scenario is the only test.** There are no unit tests for the pure modules (costmap, firemap, valuemap, wfc,
  rng, routing's A*), though wfc.lua already falls back to LuaJIT's `bit` to run outside the game. A costmap test on a
  synthetic grid runs in milliseconds and would have caught "32-tile cells fell between a ring of gun turrets" without
  a deathworld visit.

### Determinism

The rule is "never math.random". It is broken in three places: base.lua:389 (a fabricator's idle run), jumper.lua:125
(the number of hands), pact.lua:75 (a crystal drop). Factorio's `math.random` is the map's synced generator, so these
do not desync multiplayer, but they are outside `scripts/rng.lua`'s per-settlement streams and so outside the project's
own reproducibility contract. Fix in ten minutes. Iteration over `pairs(storage.bases)` and `pairs(game.forces)` is
deterministic in Factorio and fine. The `war.at_war` first-player-force bug the audit found was fixed.

### Performance

5.05 ms a tick with five cultures on nw, 0.69 without, is the number to profile before anything else is built, with
`scripts/profile.sh` as CLAUDE.md says. From the code, the suspects in order:

1. **Perception maps read whole in one tick.** `firemap.read` scans `radius + threat.far()` for every turret of every
   hostile force (nw: 2,302 lasers, 278 flamethrowers, 59 artillery); `costmap.read` builds a grid at 16-tile cells over
   the way plus a 150-tile margin and prices every cell against every reach that touches it; `herd.plan`, `farm`'s
   `ways_from` and `target_from` and `valuemap.read` call them. Each call is synchronous. Five cultures each weighing
   targets, planning and re-planning on a 1,600-tile base is the shape of 4 ms. These reads should be chunked across
   ticks (a coroutine-shaped job queue, as landings already are asynchronous) and cached per base box with an age.
2. **Per-biter targeting inside** (`PER_TARGET`, every 2 seconds for each of up to 200 biters): "the list read once a
   look" says the list is cached; each biter's order is still a command a tick.
3. **Event handlers on a megabase.** `on_entity_died` is unfiltered and runs `know.loss`, `herd.on_died`, `oplog`,
   `shared.kind_of` (string work) for every death including each wild biter the player's lasers kill. `on_entity_damaged`
   is filtered to include every `electric-turret`, `accumulator`, `roboport` and `electric-energy-interface` of every
   force for the Tesla drain, so on nw every hit on 2,302 lasers and 1,379 roboports enters Lua. Both are cheap per call
   and numerous exactly when Synthexis is attacking.
4. **Ten modules per tick that could be on `on_nth_tick`.** Small, but it is the pattern.

There is no performance gate. `ms_per_tick` is already a METRIC in every run; a bound on the system sim (say 2 ms) and on
each visit (say 1.5 times the save's baseline) in regress.sh costs nothing and would have caught this week's number.

### Documentation load

DESIGN.md is three documents in one file: a 157-row changelog called a status table, a design (premise, principles,
rules) that is still accurate and short, and a 1,193-line section of dated history. The status table's job (what state
each mechanic is in, where it is tested, whether a human has seen it) is not served by rows of 1,500 characters that
narrate the fix. The findings log is the best part of the file and is 69 lines. Propose: a `CHANGELOG.md` taking the
dated rows verbatim; a status table of one line per mechanic with four columns (built, measured, played, open) and a
link to its changelog row; the rules section kept current; the history sections moved to docs/history/. The
instruction in CLAUDE.md ("keep DESIGN.md current") then becomes possible to follow in under a minute.

docs/biotech.md (856 lines) has the same shape and the same fix. The consults (37) are fine as a record; a one-page
index of their decisions would spare re-reading them.

### What will hurt in three months

Saves. Every `storage` shape change without a migration means a player's save from 0.3.x will break on 0.3.y, and the
first portal comment will say so. One migration exists. Either `on_configuration_changed` grows a versioned healer
now, or the release notes say "new games only" until 1.0. Second: the regression's wall time, which at the current rate
is an hour by December and will stop being run in full. Third: herd.lua, for the reasons above. Fourth: nothing has
been tried with another mod's enemies, with a second player, or on a save loaded from a different version of the mod.

## 4. Path to a playable release

The user's time in game is the scarce resource, so each milestone names the one session it needs.

**M0, this week: freeze and play.** No new mechanics, no parity work. The user plays two hours on an ordinary map at
default settings from chemical science toward the first rocket, with `/lp land` used only to bring Kessler-Hayashi
forward at the end, the field guide open, and notes every moment they did not understand what happened or why. Not
deathworld10x, not nw: the map the mod is for. The output is a list of confusions ranked by how often they occurred.
That list, not a consult, sets the next month. (One session, two hours.)

**M1: legibility.** From M0's list and the audit's open rows: raids that turned back leave a sign; ghosts and occupation
signs; a faction summary a player can open (a small GUI or a shortcut that charts standings, claims, incidents, and
for Synthexis its cultures and trails); pacing on a default map measured (when each faction arrives relative to the
science eras, with `contact.sh` or a new instrument) and set by rule, not by evolution alone if that leaves an hour
empty. Also the three cheap fixes: the ledger check for Synthexis waves, the three `math.random`, the performance
bound in regress.sh. (The user looks at the summary and the signs once: 30 minutes.)

**M2: performance and saves.** Profile nw with five cultures; chunk the map reads; filter the handlers; set the gate.
Decide the save policy and write the healer or the notice. (No session.)

**M3: cut and shape the release.** Startup settings per faction (the parity note's recommendation, which I second);
the player's army off by default; heists re-graded on the M0 map and folded; stake items merged; DESIGN.md split as
above; the test file split; herd.lua split. (No session; one look at the camps in the showcase after the splits to
confirm nothing moved.)

**M4: balance in the mid game.** The system sim and the gate instrument on default maps at chemical science, blue
science and first rocket, with the levers at normal; targets stated as sentences a player would recognise ("Grubstake
costs an unguarded factory a tenth of its income and a guarded one nothing"). Two more two-hour sessions, one with
levers high. (Two sessions.)

**M5: release 0.3 on the portal as experimental**, with the field guide and the playtest kit's ten questions as the
feedback form. Then parity, if players say the corporations read as dumb; the campaign frame, if they ask for more
factions; the army, if they ask to fight back with units.

What the user should look at in game, in order of value per minute: the first hour of Grubstake on a normal map (does
the thief fire, does it read); a Synthexis wave from scout to withdrawal at a base they built themselves (not the
stand-in); Kessler-Hayashi's line arriving at an outpost they care about; one siege, from the watch save. Everything
else can stay headless.

## 5. The ten most valuable next steps, ranked

1. **Play two hours on a default map and write down every confusion.** Nothing else on this list should be scheduled
   before it. Sixty versions of Synthexis and all of the parity thinking rest on a player who has not been in the room.
2. **Freeze mechanics until M0 is read.** Specifically: no parity work, no new breeds, no new heists, no new consults.
   Fixes and legibility only.
3. **Profile and bound performance.** `profile.sh` on nw with five cultures; chunk the perception reads across ticks;
   filter `on_entity_died` and the damage handler; add `ms_per_tick` bounds to regress.sh so the number cannot regress
   unseen again.
4. **A player-readable faction summary and the four open signs** (raid turned back, rebuild ghost, occupation, the
   ladder). The premise says intent is readable; today it is a trace file.
5. **Measure pacing on a default map** and set each arrival by rule relative to the player's science, so three factions
   neither stack in one hour nor leave two empty.
6. **Split herd.lua and farm.lua along their stage seams; put Synthexis in the faction table** and retire the 60
   hard-coded ids. This is the prerequisite for both the staged release and any parity work, and it is a mechanical
   refactor the regression can judge.
7. **Tier the regression and split the test file.** Smoke under 3 minutes, area sets, nightly full; record each
   scenario's wall time; move long scenarios to forks or early finishes. A budget, written in regress.sh.
8. **Re-grade Grubstake on the M0 map** with grading.md's four questions (fires, reads, answer, decision) and fold the
   heists that do not fire into the ones that do. Its identity rests on them.
9. **Decide the player's army for release 1**: behind a setting, with capture by holding fixed or removed. The arena
   becomes a dev tool. Say so in the design.
10. **Split DESIGN.md** into a one-line-per-mechanic status table (built, measured, played, open), a changelog and the
    rules; keep the findings log. Then the "keep it current" rule can be kept.

Two things I would not do yet, for the record: bring the corporations to Synthexis's level of pricing (the parity
note's steps 1 to 5), and split the mod into two. Both are a month each, both are justified only by what a player says,
and no player has said anything since 10-26.
