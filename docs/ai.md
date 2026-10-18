# The corporations' AI: map and plan

The user (2026-10-17): "we need to be quite flexible with our coding. It turns out we've started a real RTS AI system
here, with none of the storyboarding upfront." This page maps what exists (from a read-only survey of every decision
point, checked against the code where it matters), names where the pieces disagree, and proposes the layer new
behaviour plugs into. DESIGN.md keeps the history of each mechanic; this page is the shape.

**At a glance:** `docs/ai-graph.md` (generated from the code by `scripts/ai_graph.py`, checked by `check.sh`): the layers
and every module with their requires and plug-ins, each corporation's answers and what each standing allows, which
module reads which rung of the ladder, and what each lever drives.

## 1. What exists

Every tick `control.lua` runs about twenty systems in a fixed order, each on its own cadence. Per settlement, `base.tick`
runs `army.tick`, which runs `ops.tick`. Decisions fall into five families.

| Family | Who decides | Cadence | What it can do |
|---|---|---|---|
| **Economy** | `base.plan` (a rule list: power, fabricate, mine, fortify, defend, picket, depot, launch, embellish, grow); `base.build` and `base.rebuild`; `crew.take` / `crew.rebuild`; `cordon.step` (Serenity's line); `prospect` and `road` (Grubstake's claims); `export` | 90 to 3600 ticks | Queue and place buildings, send crews, claim ore, pay parts |
| **Army** | `army.produce` (to the cap), `army.alarm` (response squads), `patrol`, `intercept` (trains), `leash`, `convoy`, `escort` | 300 to 600 ticks, or on damage | Make units, send squads, keep units home |
| **Operations** | `ops.tick` decider (siege for a battery → raid → strip → siege → strip), one `b.op` at a time; `choose` / `choose_siege` / `choose_strip`; raid, siege, strip, clearance, overflight, push; `ops.perimeter` | 1800 ticks; steps every 300 | Pick a target, take units, run the operation |
| **Heists** (Grubstake) | `flare`, `jumper` (claim rig), `tap`, `prospect` | 600 to 3600 ticks, each its own cooldown | Their own small operations, outside `b.op` |
| **Corporation level** | `faction` (landings, grudge, headquarters, withdrawal, development), `war` (at war, rung, war footing, stand-down, relief), `standing`, `pact`, `trade`, `border`, `rd` (research), `phases` | 600 to 36000 ticks, or on events | Land, escalate, reinforce, research, change standing |

How the corporations react to the player today is spread over `control.lua`'s event handlers:
- damage to 13 building kinds → provoke and alarm;
- a unit or crew killed → provoke;
- a building killed → alarm and rebuild;
- artillery → counter-battery;
- a lander killed → grudge;
- a turret near a camp, or a build inside Serenity's territory → provoke;
- a raze → the ladder clock resets.

## 2. Where the pieces disagree

1. **"Is this corporation hostile to that player?" is answered three ways.**
   - `ops.temper_allows` + `ladder` + `rival_holds` decides raids.
   - `war.at_war` decides flares, rigs, taps, relief, war footing and stand-down. It ignores Grubstake's soft temper, truces and claim markers, so an unprovoked Grubstake rival is "at war" at rung 0: it taps under a truce and holds its rebuilds on a war footing.
   - `choose_siege` skips `temper_allows` altogether.
2. **Six systems send units at a position, each with its own clock:** responses, operations, intercepts, flare buggies, tap buggies and patrols. Responses are not counted in the threat budget and are not stopped by a running operation.
3. **One pool, many takers, no ledger.**
   - Units are taken from `b.garrison` by about a dozen systems, each with its own floor (`HOME_GUARD` 2, or ops' 30% reserve, or none).
   - A camp's strength counts only units at home, so units out on an operation are replaced and the cap is not one.
   - Units are put back into the garrison while still far away, and can be drafted again at once.
4. **At least nine target pickers**, each with its own rule. "Nearest player" means a different thing to the perimeter, the pickets and the prospector, and the claim rig's owner is hard-coded to "player".
5. **The ladder is read in a dozen places, each with its own thresholds.** `b.war_rung` is refreshed every 600 ticks and can lag the ladder.
6. **Reactions to the player are scattered and mostly silent.** A provocation sets a flag and nothing visibly answers it: the user's turrets killed Serenity's drones and it did nothing for the rest of the session. Damage to 13 building kinds provokes; damage to units, gates, mortars, the pacifier, the tap or the rig does not until something dies.
7. **Three comments disagree with the code:**
   - a lander's death "answered by every corporation" (only its own corporation is provoked);
   - "enclosing provokes" (stale since `ops.encroached`);
   - the trade truce "not given when ambushed" (it is given at pickup).

## 3. Storyboard (to settle with the user)

What each corporation should feel like, by stance, is the design the code should serve.

| Stance | Grubstake (the thief) | Serenity (the wall) |
|---|---|---|
| **Rival** (default) | Steals where you are not: soft raids, strips, taps, prospects, flares at rung 1 | Expands its line, clears nests, ignores you |
| **Truce** (tribute, border) | No raids, flares or rigs; does it still tap, strip and prospect? (today: yes) | Line capped at the border |
| **Provoked** (you hurt it) | Answers at once, then raids in force (half its field), heists escalate | Answers at once, then raids and sieges; never forgets |
| **Escalating** (no raze in 10/20/30 min) | Rungs relax the soft temper, then cost no object | Same ladder: player targets weigh more, then sieges up a tier |
| **Standing down** (nothing razed in 60 min) | Quiet, forgives, a new landing elsewhere | Quiet; does not forgive |

### Payments (the user, 2026-10-17: "Keeping such corp on good terms late game will have to be a resource sink")

Every payment happens in the world: goods left at a place the player chose, collected by something visible that can be
followed or ambushed, and something lit while what was bought holds. No payment through a menu or a notice.

| Payment | Paid at | Collected by | Buys | Tell |
|---|---|---|---|---|
| Tribute (built) | the trade post | a Grubstake truck | a truce with Grubstake: no raids, flares, rigs, taps or strips | the truck; a lamp on the post while it holds (to do) |
| Levy (to build) | the player's border stake, made a small chest (the line moves; the stake does not) | a Serenity drone | as a rival: the line holds still for a while. As an enemy: a cease-fire for a while, never forgiveness | the drone; the stake's lamp |
| Contract (to build, late) | a rocket to a corporation's headquarters | its uplink | something large: a long truce with all its camps, or its withdrawal from a region | the launch; its camps going quiet |

Balance is the hard part. A flat price that hurts at the start is nothing at a megabase, and good terms late in the game
are meant to cost. So:
- **The price scales with the player.** It is measured against the player's own production, from the production statistics (as a share of an hour's output of what is asked), not as a fixed count. The era sets which goods are asked: plates early, intermediates later, modules or science late.
- **It rises with use.** Each payment in a row costs more than the last, so peace bought forever costs ever more; skipping a payment resets the rise only slowly.
- **Losses cost more than payments.** Paying must cost less than what the corporation would raze in the time bought, or no one pays. Tested the way the ladder was: visits with and without payments.
- **What is paid feeds the corporation:** parts and its war chest. A paid corporation grows, and the bill keeps rising. Turtling behind payments is then a sink that never ends, which is the point.

Open questions for the storyboard:
- Should a truce stop Grubstake's taps and strips?
- Does war footing apply to an unprovoked rival?
- Should a provoked Grubstake ever siege?
- What does the player see first when a corporation turns hostile?

## 4. The proposed layer

The aim is not a rewrite. It is three small seams that new behaviour plugs into and that old code moves onto when it
is next touched.

1. **Stance.** One function, `stance(corp, force)`, returns:
   - the standing (rival, truce, enemy);
   - the rung;
   - a permission set derived from the temper: `soft_raid`, `guarded_raid`, `siege`, `heist`, `strip`, `prospect`, `tap`.

   Every system asks it. It replaces the three answers in 2.1.

2. **Reactions.** One entry point, `react(b, event)`. Events: `provoked`, `crew_killed`, `unit_killed`, `building_hit`, `building_lost`, `encroached`, `shelled`, `lander_killed`. The handlers in `control.lua` call it instead of each doing its own thing. Each corporation's temper maps an event to responses: sense the spot, mark a threat, provoke, and the new **answer**.

   **Answer** is the first new client: provoked by a force, a settlement sends a squad within a minute or two at what provoked it (the killer's position, or the turret), sized to what is there. It counts as an operation against the player for the threat budget, so it cannot stack into a flood.

3. **Unit pool.** `pool.take(b, n, role, filter)` and `pool.give(b, units)`:
   - one floor for what stays home;
   - strength counted over units out as well;
   - units given back only once they are home.

   Responses, operations, heists, convoys and patrols take through it. It is the fix for 2.3, and it lets the answer draw units without starving defence.

Built (2026-10-17):
- **Stance:** `scripts/stance.lua`, a leaf that reads storage only. It answers `standing`, `rung` (the ladder, moved from ops) and `may(corp, owner, act)`. `ops.temper_allows`, `choose_siege`, `choose_strip` and `war.at_war(b, act)` (flares, rigs, taps; "war" for the footing, relief and stand-down) ask it.
- **The storyboard calls taken** (the user: "I trust you on the calls"):
  - a truce stops taps and strips too, but not prospecting;
  - an unprovoked rival is not at war, so no war footing and no stand-down clock;
  - Grubstake does not siege unless it holds a grudge, as before;
  - when a corporation turns hostile, the player sees the answer first.
- **Reactions:** `ops.provoke(corp_force, by, at)` is the one entry for a provoking act. `at` is the culprit: the killer of a unit, crew or building, a turret by a camp, a build on Serenity's ground, a broken border, a battery. With a culprit, it asks for an answer.
- **The answer** (`ops.request_answer`, then the decider's `answer`, every 300 ticks, ahead of its clock): the corporation's settlement nearest the culprit (within 500 of its home) raids the player's building nearest the spot, its reserve with it, at least 6.
  - At most one every 5 minutes per settlement.
  - It waits while an operation runs.
  - A truce stops it.
  - Scenario `crew answered`: three turrets shoot Serenity's drone down; 2 s later a squad of 8 goes, razes them and comes home whole. On the old code no answer came.
- **The unit pool** (`scripts/pool.lua`):
  - a settlement's roster is every unit it owns, out or home (`pool.enlist` at every place one is made or handed over), and its strength, what the cap holds, is the roster's live count;
  - units done with a job go through `pool.give`: into the garrison when within 40 of the lander or a depot, else onto `b.returning` until they get home (at most 5 minutes);
  - old saves rebuild the roster once from `storage.unit_owner`.

  Scenario `pool`: a full camp (30 of 30) makes no unit while 4 raiders are out, and they come back through the returning list. On the old code it made 3 while they were out.
- **Built 2026-10-18:**
  - a reaction table per corporation (`temper.answers`, by the provocation's kind, loss or trespass): Grubstake answers with a flare on the culprit, a raid only where no turret covers it; Serenity raids a loss it can win, sieges trespass (`docs/reviews/2026-10-18-answers-consult.md`);
  - one floor for what stays home (`pool.take`, `pool.floor`: the guard of 2, or the 30% reserve);
  - one definition of a player's force (`shared.is_player_force`), and the claim rig's owner from its target.
- **Not yet:** one target picker (2.4: the pickers still score in their own ways); the ladder's thresholds (2.5).
- **Split (2026-10-18), along the graph's seams:** `ops.lua` (2,961 lines) into routing, intel, perimeter, siege, strip,
  answers and cuts (ops keeps the decider, raids and the shared helpers: 1,341). Each module's code moved verbatim inside
  `install(ops, K)`, which binds the helpers it reads from ops and returns what ops calls; `scripts/lint_globals.sh`
  (in `check.sh`) fails on any global a script reads that is not the engine's, where a lost local would show.

Order (as planned):
1. `stance` and `react`, with the answer as their first user (tested: a turret kills a drone, a squad comes at that turret within two minutes, a rival before and an enemy after).
2. The pool, when the answer needs it.
3. The remaining systems move onto the seams as they are touched.

Targeting (2.4) and the ladder's thresholds (2.5) are left until the storyboard settles what they should be.
