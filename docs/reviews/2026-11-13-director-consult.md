# The director: a design consult (Fable, read-only, 2026-11-13)

Read: `CLAUDE.md`, `DESIGN.md` (the status table; the findings 0.2.366 to 0.2.370: the hull through the dome's break,
arc flamers, the landing search traced and then on an ore grid, maps built in slices), `docs/director.md`,
`docs/campaign.md`, `docs/corporations.md`, the adaptive tactics consult of 11-05 for the form, and the code the
director would sit on: `faction.lua`, `phases.lua`, `war.lua`, `stance.lua`, `strategy.lua`, `valuemap.lua`,
`costmap.lua`, `ops.lua` (the chooser, the launch, `ops.tick`), `siege.lua` (`choose_siege`, `launch_siege`, the march),
`routing.lua`, `intel.lua` (`heard_landing`, the survey), `farm.lua` (the wave gate), `herd.lua` (`herd.launch`),
`pods.lua`, `rng.lua`, `know.lua`, `tune.lua`, `base.lua` (`land`, `fall`), `dev.lua` (`/lp land`), `control.lua` (the
tick order, the death handler, `debug_tune`, the remote interface), `settings.lua`, `shared.lua`, `tests/lp-sim/control.lua`
(the harness, scenarios `async`, `budget`, `faction`, `phases`), `scripts/regress.sh` (the area table), and
`runtime-api.json` at 2.1.24 for every engine call named below. Nothing run, nothing edited. Line numbers are the
working tree's (faction.lua and costmap.lua carry uncommitted changes; I read what is there now).

The verdict first: the split holds, the budget is the right instrument, and the drop wave is the right first event.
The proposal underestimates how much of it already exists (the threat budget in `ops.lua`, serial landing jobs, the
grudge's revenge landing, the stood-down haste) and overestimates what needs building (the multi-site search, the
shared route map, staggered launches, the pincer). Section 7 is the list; sections 1 to 6 are the reasons.

## 1. The split against the code: where "when and how big" meets five clocks

The director decides when and how big; the corporations decide how. That split is clean on paper. In the code there is
no single "when": five clocks move the next landing and the next operation, and the director has to be wired into each
one by name or it fights them.

**The cadence.** `faction.tick` (`faction.lua:923`) fires a landing when `tick >= f.next`; `f.next` is set at every
landing (`faction.lua:740`, `f.next = game.tick + cadence(f)`), except a headquarters landing (`opts.hq`, line 738).
Four places pull it earlier: a rocket launch (`HASTE`, 15 minutes, `faction.lua:775`), a camp standing down
(`QUIET_HASTE`, 5 minutes, `war.lua:564`), a lost headquarters (`VACANCY_HASTE`, 30 minutes, `faction.lua:1098`) and the
late gate opening (`LATE_HASTE`, 5 minutes, `phases.lua:174`). Two collisions follow. First, a drop wave made of three
`faction.request` calls lands through `faction.arrive`, and each landing resets `f.next` to 90 minutes from then: the
wave silently postpones the normal cadence, three times. The fix is one flag: `opts.expedition` skips lines 738 to 741
as `opts.hq` does, so a wave never touches `f.next`. Second, the director "holding a landing back for a breather" must
not rewrite `f.next` either, or the four hastes above and the director overwrite each other. Make it a gate, not a
clock: `faction.tick` asks `director.holds_landing(f)` beside `tick >= f.next` (line 923), and the hold expires on its
own. The cadence then keeps its arithmetic and the director keeps a veto. That is the whole of "it can hold a landing
back".

**The camp cap.** `alive(corp)` (`faction.lua:781-789`) counts every valid lander not quiescent; `next_corp` (line 813)
and `on_launch` (line 773) land only while `alive(corp) < camps(corp)`. Expedition camps must be left out of `alive`
exactly as `b.quiescent` is, with `b.expedition` set at landing, else three wave camps stop the corporation's own
landings for 45 minutes and the reverse of decision 1 happens. At settle time the rule is `alive(corp) < camps(corp)`
with the expedition still excluded, then `b.expedition = nil`. Note what that means at default settings: a corporation
on the 90-minute cadence usually stands at two or three camps (cap 3) by the time the director runs, so the settle
branch is nearly dead and almost every expedition withdraws. Section 3 proposes a settle rule that keeps the user's
decision and still gives roots.

**The ladder.** `stance.rung` (`stance.lua:48-59`) is one clock per player force and corporation force, keyed
`owner|force` in `storage.last_raze`, started at first query, reset when any camp of that corporation razes a
building (`control.lua:407-409`). A wave camp inherits its corporation's rung the moment it lands: Kessler-Hayashi at
rung 3 (30 minutes without a raze) lands three camps that are "desperate" from their first decision (`ops.lua:618`,
`DESPERATE_ODDS`; `siege_tier` adds a tier at rung 3, `siege.lua:470`). That is not wrong (the corporation is the
temper, not the camp) but it is the one way a wave can be far bigger than its budget said: three desperate sieges at
tier plus one. I would leave the clock alone and have the director read it: a wave landed while `rung >= 2` costs more
budget (section 2), so the storyteller pays for the desperation it is buying. Do not reset the clock at the wave:
that would also calm the standing camps, which the player did nothing to earn.

**Reliefs and the war chest.** `war.tick` (`war.lua:603-620`) sends one relief per corporation every ten minutes to
the camp at war on the highest rung, most short of its cap, paid from the chest (cap 6,000 parts, `war.lua:29`). Three
fresh expedition camps at war and short of their cap would take every relief from the standing camps for 45 minutes.
Decide it: an expedition gets no relief (skip `b.expedition` at `war.lua:609`). It is what it brought, which is also
what makes "clear the wave" a bounded fight the player can read. The chest then stays the standing camps' resource,
and the director can read `d.chest` as one of its corporation readings without spending it.

**The grudge.** A wave camp's lander destroyed by the player goes through `control.lua:340-345` to `faction.grudge`
(`faction.lua:1005-1023`): every corporation provoked, `d.grudge = by`, and the next landing of that corporation comes
angry with a doubled escort (`GRUDGE_ESCORT`, `shared.lua:242`; `faction.lua:726`). So a cleared wave already has a
built-in sequel, a revenge landing on the next cadence tick. The director must read `d.grudge` as "a revenge landing
is owed" and not stack a second wave on top of it; and the revenge landing itself is a director event in all but name
(section 5). Three landers killed set `d.grudge` once and `d.grudges` to three; that counter is the natural input for the
deferred alliance strike (a shared grudge: `d.grudges >= 1` for two corporations within a window).

**Synthexis.** Its wave gate is `tick - f.last_wave >= tune.sooner("biotech", WAVE_GAP)` with no herd out
(`farm.lua:2249`; `WAVE_GAP` 20 minutes, `farm.lua:101`). The director can read the next earliest wave per culture as
`f.last_wave + WAVE_GAP` and a wave in flight as `herd.out(f.id)` (`herd.lua:4446`). Its size is composed at `send`
(`farm.lua:1240`), so "a large wave" is not knowable ahead; the readable rule for decision 2 is: no drop wave while any
herd is out or any culture is within five minutes of its gap. Later, if a Synthexis wave becomes a director event, the
hook is `f.last_wave` (set it back by `WAVE_GAP` to call one now, as `farm.lua:2392` already does for tests).

**Posture and the threat budget.** `strategy.posture` is a pure function `war.quiet` recomputes every ten seconds
(`war.lua:539-541`); the director never touches it. The threat budget is the piece the proposal treats as new and is
not: `ops.budget(owner)` (`ops.lua:296-299`) caps operations in flight against a player force at `1 + era`, read in the
chooser (`ops.lua:599`) and the siege chooser (`siege.lua:400`), with a floor (`FLOOR_TICKS`, 20 minutes without an
operation against a player, `perimeter.lua:39`) that triples player targets' weight. That budget is the director's
hand on the corporations' "how big" for operations, and section 4 builds the coordinated raid on it.

**The opening.** Decision 5 says the director waits for signs, survey and arrival. The code's marker is
`storage.phases.arrived`, set by `after.phases` (`faction.lua:1143-1146`). The sims land directly through the remote
`arrive` and never run phases, so with that gate the director never fires inside an existing scenario: the whole
regression stays as it is by construction. Keep that property on purpose: the gate is `phases.arrived or
storage.director_force`, and the director's own scenarios set the flag through `debug_tune`.

## 2. Budget and pacing

**Read these, concretely.**

- *Era*: `ops.era(force)` (`ops.lua:279-286`), 0 to 4 by technologies researched (25, 60, 100, 150). This is the
  scaling unit the mod already uses for the threat budget, the siege tier and the armed landing; the director should
  use the same one so the levers stay one thing.
- *Wealth*: not `valuemap.read` over the base. That is `find_entities_filtered` over a radius (`valuemap.lua:56`), which
  on a megabase is thousands of entities a read, the cost 0.2.370 went to lengths to avoid. Use
  `LuaForce.get_entity_count(name)`, documented O(1) in the 2.1.24 API, over a fixed list of about twenty prototype names
  (the assemblers, furnaces, drills, roboports, substations, beacons, silos, the turret kinds) weighed by
  `valuemap.WORTH` and `valuemap.DEFENCE` (`valuemap.lua:14-21, 43-46`). Twenty engine calls a minute. Call it W.
- *Guns*: the same call for the turret kinds gives a defence count D; `threat.artillery_reach(pf)` and the artillery
  count the landing search already lists (`faction.lua:354-363`) give the artillery picture.
- *Recent losses*: there is no windowed reading today. `storage.last_raze[force]` is a tick (`control.lua:408`) and
  `storage.player_razed` is a cumulative tally by type (`control.lua:410-412`). Add a ring of `{tick, worth}` in
  `storage.director.losses` fed from the same handler (one line beside `control.lua:412`, worth from
  `valuemap.razed_of(ent)`), and read the sum over the last 30 minutes as L.
- *Corporations*: `faction.alive(corp)`, `camps(corp)`, `d.chest`, `d.grudge`, `d.grudges`, `d.withdrawing`, `d.level`
  (`storage.corps`), `stance.standing(corp, owner)`, `shared.enabled(corp)`; the Synthexis readings above.
- *Pacing*: `storage.director.last_event`, `f.next`, the farms' `last_wave`.

**The model.** Count in landings, not in points, so that every number reads against something the game already has.
The budget B fills by `(1 + era / 2) * difficulty * personality` landings per `lp-landing-interval` (so at era 0, steady,
normal, the director adds nothing to today's pace by itself, which is the right baseline for a setting whose "off" is
today's game). Costs: a wave of two is 2.5, a wave of three 4, a coordinated raid 1.5, a wave landed while the ladder
is at rung 2 or more costs half as much again (the desperation it buys, section 1). Cap B at 4: a wave of three has to
be saved for, which is what gives the rising curve. After an event, a cooldown of the event's cost times 15 minutes
(a wave of three: an hour), then the breather. These are priors to calibrate, marked so, and the one thing to insist on
is that they live in `shared.lua` beside `LANDING_MINUTES` and are read by the scenario's checks, never typed twice.

**Against a losing player.** Two guards, both cheap. The loss window: no threat event while L exceeds a share of W
(2 percent is my prior; the number should come from the contact runs, `scripts/contact.sh`, where a careful player's
losses an hour are already plotted). The other guard the proposal does not have: the defence trend. If D fell over the
last hour (turrets destroyed faster than rebuilt), the fill rate halves. That catches the slow spiral the 30-minute
window misses: a player losing an outpost every twenty minutes never trips a window and still drowns. RimWorld's
"adaptation" (threat scale that falls after losses and recovers slowly) is this guard; it is one of the two things from
RimWorld that transfer cleanly.

**Against a megabase.** Size is bounded (a wave is at most three landings) and the landing search already puts a late
camp under the guns on the one nest-free band (`faction.lua:594-602`), where its dome holds three minutes of shelling
and the hull holds through the break (0.2.366). A wave of three there is three domes for the artillery and the errand
of clearing them. The budget should not try to hurt a megabase; it should make the errand legible and paid (the fallen
camps' salvage and cores already pay it, `control.lua:341`, `base.fall`). What a megabase needs from the director is
reach, not size: at era 4 the Kessler-Hayashi wave is armed fortresses (`base.land`, `base.lua:166-180`, about 650
entities each with a build burst). Two of them, not three (section 6 on cost), and that is the top of the scale.

**What RimWorld gets right and wrong here.** Right: one layer that owns pacing, a wealth-scaled budget, adaptation
after losses, a warning before a threat, and the "quiet" events that make valleys feel authored. Wrong for this game:
its cycle is minutes and its events resolve in minutes, on screen. A Landing Party event resolves over 30 to 90 minutes
(a camp grows, a siege takes fifteen minutes to deploy and shell, an expedition lasts 45) and the player is often on
another surface or at the other end of a base that takes a minute to cross. Three consequences. The director's period
is hours, not minutes: a peak every two to three hours of play, which is also why counting in landings is right. The
warning must survive the player's absence: notices are off by default (`shared.notice`, `shared.lua:706-720`; the
user, 2026-10-17), so a "notice a minute ahead" is never seen unless its key is in `KEEP`. Use a chart tag at the
sector's centre (`LuaForce.add_chart_tag`, which needs charted ground; the player's own base is charted) plus
`LuaPlayer.add_custom_alert(entity, icon, message, show_on_map)` on the player's nearest building to the sector, which
is the alert bar on any surface (inferred from the alert system, not tested here: the first spike). And wealth scaling
must be gentle: RimWorld's wealth curve punishes building, which in a factory game is the whole game. Era carries the
scaling; W enters the fill rate as a slow multiplier (log, or a cap of 1.5), and its main use is the loss share L / W.

**Personalities.** Steady and chaotic are the same budget with a different spend rule: steady spends when B reaches the
event's cost; chaotic draws from `rng` (`scripts/rng.lua`, its state in `storage.director.rng`) a spend tick between
cost reached and cap reached. Gentle halves the fill. That is one function with three parameter sets, not three
storytellers; write it that way and the "off" value is the function never called.

## 3. The drop wave

**The multi-site search is not needed, and three landings in one tick are the stutter 0.2.370 removed.** Landing jobs
are already serial: `landing_jobs` (`faction.lua:851-912`) processes `jobs[1]` only, "one at a time, oldest first:
two searches would not see each other's lander" (line 854). A job searches dry, waits for its ground (`wait_for`,
line 666; `waiting`, lines 416-418 and 500-504), sends its pod, waits for touchdown (6.65 s, `POD_WAIT` 20 s), then lands;
the next job's search sees the new lander in `landers()` (line 64) and keeps `APART` from it by the check at line 379.
Three requests queued in one tick with a shared `wave` id land about ten to thirty seconds apart on ready ground, each
clear of the last: "within a minute" with no new search. A one-pass multi-site search would have to do the opposite:
force three candidates' ground in one tick (the dry search waits per candidate for exactly that reason) and then call
`base.land` three times, each of which requests and forces a 15 by 15 chunk square (`base.lua:151-152`). That is three
times the 0.4 to 2.6 s stall `faction.request` was built against (line 830). Keep the search as it is and give the job
two fields: `wave` (an id, so the director can read when all its jobs are down and `storage.last_landing` per job) and
`turn` (a direction override for `faction.site`'s `count`, line 331: `start = (seed + 3 * count) % 8`). Spread is three
turns apart (sectors 0, 3, 6 of 8); a beachhead is one turn for all three, and `APART` does the rest within the
sector. The ore band is cached per band and turn (`ORE_BANDS`, lines 249-315), so the second and third searches cost
the sort, not the noise.

**The shared route map is a non-issue for two of the three corporations.** The sliced way map is built only for an
armed landing (`armed_for`, `faction.lua:862`, era 3 and up, Kessler-Hayashi only; `armed_era` at `shared.lua:110`). A
Grubstake wave never builds one. For an armed Kessler-Hayashi wave the map is already kept in the job (`job.ways`, in
storage); share it by letting `landing_jobs` copy `job.ways` from the previous job of the same `wave` once it is done
(the box, `ways_radius`, is the same for every job from the same `from`). Five lines. Do not build a wave-level map
store.

**Warning and telegraphing.** The precedent is the cordon's named warning (`perimeter.lua:307-316`), which is a notice
and so off by default. For the wave: at the director's decision, before the requests are queued, a chart tag at the
sector's ring point (`from + DISTANCE * (cos a, sin a)`, the same point `faction.site` steers toward at line 376) with
the corporation's icon and a text like "orbital traffic", the custom alert above, and a sound with no position
(`LuaForce.play_sound`, which plays for the force's players when no location is given). The landings are requested
`WARN` ticks later (my prior: 90 s, enough to send units, not enough to wall). The tag is destroyed at the first
touchdown (`LuaCustomChartTag.destroy`). The telegraph must be honest: the wave goes to that sector, so the warning is
computed from the `turn` the director chose, not guessed. Record the decision and its readings in `decisions.txt`
through `base.trace`'s file (the proposal's section 6 asks for it; the landing's own trace lines are the model,
`faction.lua:742-752`).

**Expedition camps: settle or withdraw.** The withdrawal `faction.lua` has (`faction.lua:985-988`) is
`lander.destructible = true; lander.die()`, which runs the death handler: `command.drop_cores` drops three command
cores (`control.lua:341`), `base.fall` cascades the generators and bursts the yard (`base.lua:672`), and the `lp.fallen`
notice, which is in `KEEP` and always printed, tells the player they won. An expedition that leaves on its own schedule
must not pay out as a kill. Set `b.leaving` before the `die()` and have the handler skip the cores and the notice, and
`faction.grudge` is already skipped (no `e.force`). A lift-off look (the landing effect in reverse, `landfx.lua`) is a
later art pass. On the settle side, the rule as decided is nearly dead at default settings (section 1). A rule that
keeps the decision and gives roots: an expedition settles when `alive(corp) < camps(corp)`, or when it has out-exported
the corporation's weakest standing camp (`b.exported`, the measure `faction.headquarters` already uses to pick the
weakest, line 979), in which case the weakest withdraws through the same path. That is the proposal's quiet event "a
corporation pulling a camp out" with a reason, and it is what a corporation would do: consolidate on its best ground.
The cap is never exceeded after settlement.

**What each corporation's wave should feel like, from its mind.**

- *Kessler-Hayashi*: `temper.hostile` and `provoked_only` (`shared.lua:209`): at war from landing, but it answers
  trespass only and never raids first until its ladder presses it; its site weights `approach` 1.5 and `rival` 0
  (`shared.lua:206`): it wants a clear way to the player. Its wave is a beachhead (one turn) of two camps 200 apart on
  the side with the clearest approach, a front: two cordons stepping toward the player (`cordon.lua`), two domes, a
  landing barrage each (`war.barrage`, `war.lua:391-430`). Armed at era 3 and up: two fortresses, with the build burst,
  the sweeps and the orbital relay (`war.lua:301-323`); their sieges wait for `b.ground_clear` (`ops.lua:2022-2025`),
  which is right. Two, not three: see section 6.
- *Grubstake*: `soft_only`, `pact` (`shared.lua:91`): its ladder stays at 0 (`stance.lua:40-44, 50`), it never raids
  guarded ground, it strips the player's ore, and under the pact it lands `SQUAT_DISTANCE` 60 from the player's turrets
  among nests (`faction.lua:53, 394`). Its wave is a claim rush: three turns apart, each camp on a different outlying
  patch of the player's, each with its strip operation. Against a turtled player it steals and nothing else; that is
  the thief and the warning text should say so ("mineral claims filed on three deposits"). The indirect effect is the
  interesting one: its drills pollute (`drill_pollution` 15, `shared.lua:100`) and the pact sends the biters' waves at
  the player's polluters near its cloud (the comment at `shared.lua:97-99`); three new Grubstake camps in biter
  country is more biter pressure on the player's edge without a shot fired. The scenario must measure that, because it
  is the thing most likely to be too much on a deathworld.
- *Synthexis*: keeps its cadence (decision 2). Its carrier seeding (`farm.lua:1735`) is already a spread of cultures.

**Failure modes, each with the check that catches it** (a scenario `wave`, 40 minutes, the stand-in base of
`system`, forced by `debug_tune {director_force = true}` and a remote `director_event("wave", corp, n, spread)`; mixes
for each corporation and for spread against beachhead):

1. The second or third job finds no site in the band (`SITE_LOOK` 12 candidates a band, refusals by `APART`, army,
   factory, nests) and lands a ring further out or fails. Check: all n landed; each within `SITE_SEARCH` of the band;
   pairwise distance at least `APART`; a beachhead's pairwise distance under 2 `APART` plus `SITE_SEARCH`; the last
   touchdown within 90 s of the first (`storage.last_landing.ticks` per job, kept per wave).
2. The cadence reset. Check: `faction.state().next` identical before and after the wave.
3. Expedition camps counted in `alive`. Check: with `cadence_minutes` 5, a cadence landing comes at its due tick while
   three expedition camps stand.
4. Reliefs drained. Check: `war.summary(corp).spent` unchanged across the wave with `relief_ticks` short.
5. The stutter. Check: the harness's per-tick profiler (`helpers.create_profiler`, which 0.2.370 used) over the wave's
   two minutes: worst tick under a bound the landing-search finding set (its worst step was 7.6 ms; set 20 ms and
   watch it fail first).
6. The warning. Check: a chart tag of the corporation's icon exists at least `WARN` ticks before the first touchdown,
   within 300 tiles of the first lander, and is gone a minute after.
7. Settle and withdraw. Two mixes, the guard broken in both states: `camps` 1 so every expedition withdraws at 45
   minutes (no `lp.fallen` notice counted, no cores dropped, no entry in `storage.failed_sites`, the lander gone), and
   `camps` 10 so every one settles (`b.expedition` nil, `alive(corp)` up by n).
8. The loss window. Check: a scripted raze of worth above the threshold two minutes before the wave is due defers it;
   the same with the threshold off lands it.
9. Off. Check: the scenario's whole results table byte-identical with the personality "off" and with the module absent
   (the baseline), over the five standard seeds; the project's own rule that "off keeps today's game".
10. Grubstake's pollution. Check (deathworld mix, `aged`): the wild biters' attacks on the stand-in in the 30 minutes
    after a Grubstake wave against the 30 before; a bound to set from the first measurement, not now.

## 4. Coordinated raids and pincers

**What launch timing really costs.** A raid's march is planned at launch: the route from home to a staging point
outside the target's guns (`outside`, `routing.lua:12-27`; `sneak_route`, line 113), and `stage_ticks = STAGE_TICKS +
march / MARCH_SPEED` (`ops.lua:1527-1529`, 90 s plus the march at 0.08 tiles a tick, 4.8 tiles a second). The
director cannot know the march before the launch without planning the route itself, and the engine's own detours round
water were the reason the fixed 90 s was replaced (the comment at line 1524). But look at the spread of marches: camps
stand on rings from 350 to about 830 tiles (`DISTANCE` plus the rings to 480), so the worst difference between two
camps' marches is about 480 tiles, 100 seconds. Launch every camp at once and their raids arrive within two minutes of
each other, which to a player at a wall is the same window. Staggering buys a minute at the price of a route planner
the director should not own. Cut the stagger.

**What a coordinated raid needs, then, is three things that already have a place.** The budget: `ops.budget(owner)`
(`ops.lua:296-299`) holds the second and third raids at era 0 and 1 (`in_flight >= budget`, line 599; `siege.lua:400`).
Add a term the director sets for the event's window, `storage.director.surge[owner]`, read in `budget()`: that is the
director's "how big" for operations, in one line, and it decays to zero so the window closes itself. The clock: each
camp decides every 30 s when `tick >= b.next_op` (`ops.lua:2015-2017`); the director sets `b.next_op = now` for the
corporation's camps at war with that player, which brings their next decision to the same half minute. The targets:
each chooser picks its own best (`choose`, `ops.lua:563-660`), so two camps may pick the same heart. The chooser already
skips cooling zones within 48 tiles (`b.intel.cool`, lines 568-577): when the first camp launches, the director puts
its target's position in the siblings' `cool` for the window, and the second camp goes elsewhere. That is "different
soft hearts" without touching `valuemap.hearts` (which only Synthexis and the siege chooser read: `farm.lua`,
`siege.lua:429-436`); the corporations' raids read their intel targets, and a camp only knows what its sensors and
survey have seen (`SENSORS`, `ops.lua:33`; the survey along the line to spawn, `intel.lua:252-290`), which is the right
limit on a coordinated raid: a camp raids what it knows.

**Pincers come free from the spread wave.** A staging point lies on the line from the target toward the raiding camp's
home (`routing.lua:12-27`); a siege site is found from the camp's own home (`siege_site`, `siege.lua:242`). Two camps
on opposite sides of the player that go for the same target stage on opposite sides by construction. A "pincer" is a
spread wave followed by a coordinated raid whose cool zones are turned off, so both camps take the same heart. Building
a split approach for camps on the same side would mean a staging point turned 180 degrees and a route round the
player's base to it, through the wide sneak search that cost 80 ms and 21,000 cells when sealed in (`routing.lua:206`).
It is the costliest item on the menu for the least visible result. Cut it as a separate event; keep the word for the
spread-plus-raid combination in the decision log.

**Is any of it worth it against the drop wave?** The coordinated raid, yes, at about sixty lines: a surge term, a
`next_op` reset, a cool zone, a notice. It is the one event that uses the camps the player already has without adding
entities, and it is the natural peak between waves when the budget is half full. The stagger and the pincer, no.

## 5. The menu: what to add cheaply, what to cut

Add, each from something built:

- *The revenge landing as an event.* It exists (`faction.grudge`, `faction.angry`); today it waits for the cadence.
  The director reading `d.grudge` can bring it as a drop wave of two with the doubled escort when the budget allows,
  announced as a reprisal. It answers something the player did, which campaign.md's pillar 3 asks of every fight.
- *The reinforcement drop as a quiet-threat event.* `war.send` (`war.lua:167-234`) drops a detachment by pod from the
  chest. A director event "the corporation reinforces its camp nearest you" is one call with a bigger `n`, visible
  (pods falling), and costs the corporation its chest: a threat the player can see coming down and go and meet.
- *The salvage drop as the reward event.* `phases.signs` (`phases.lua:37-59`) makes the wreck with cargo; `shared.wreck`
  places a wreck with any stacks. A crashed rival shuttle in a valley is twenty lines and a map tag, and it draws the
  player out of their base, which a storyteller wants.
- *The stand-down as a quiet event.* `war.quiet` (`war.lua:522-580`) already makes a camp go quiet and announces it;
  the director can read `b.quiescent` across camps as "the valley has begun" and extend the breather instead of filling
  it. No code; a reading.
- *The orbital sweep as Kessler-Hayashi's telegraph.* Its sweeps (`war.barrage(b, true)`, `war.lua:587-598`) are
  shells from the sky on nests. A wave of its announces itself better with a barrage on the sector's nests a minute
  before the pods than with text; the landing barrage already runs at landing (`faction.lua:706`). Call it at the
  warning instead, for the beachhead's first site, and the sky tells the player where.

Cut:

- The multi-site search (section 3), the shared route-map store (section 3), the launch stagger and the pincer
  (section 4).
- Three personalities as three storytellers; one spend rule with three parameter sets (section 2).
- "A cap on threat events at once read from the player's defences" as its own rule: the loss window, the defence
  trend and the era-bound size cover it, and a fourth guard is a fourth thing to calibrate.

## 6. Risks

**Performance.** Three risks, in order. First, `base.land` forces a 15 by 15 chunk square at every landing
(`base.lua:151-152`); the serial jobs wait for ground dry (`wait_for`, radius 7), so with serial requests the landings
cost what one costs now, which 0.2.370 measured; a multi-site landing in one tick would not. Second, the planners: a
wave adds three camps to the two corporations' six and the farms, nine settlements against the campaign's cost target
of six materialised (`docs/campaign.md` section 5, 1 ms a tick); `scripts/profile.sh` at nine camps before the wave
ships, and the armed wave at two fortresses because each lands about 650 entities with a build burst
(`UPLINK_BURST`, `base.lua:170-175`). Third, the landing barrages: each queues a shell every 15 ticks
(`ORBITAL_EVERY`, `war.lua:282`) per camp, three queues in parallel; projectiles are cheap, but measure. The director's
own readings are twenty `get_entity_count` calls a minute and a scan of `storage.bases`: nothing.

**Determinism and multiplayer.** Everything the director decides must come from storage and `rng` (`scripts/rng.lua`,
state a plain number). Tick on a fixed offset (`tick % 3600 == k`, as `phases.tick` does at line 220) and read only
storage and O(1) engine state. Two traps the code already shows. `faction.lua` keeps search state in module fields
(`faction.dry`, `faction.pass`, `faction.refused`, lines 613-615) and a landing handed its site after a load crashed
on them at 0.2.370; the director must add none, and its `wave` and `turn` must be job fields in storage. And the
faction's origin is one point, `f.from` (the first silo's position, `faction.lua:739`), with one player force assumed;
the director's state should be keyed by player force from the start (`storage.director[force]`), as campaign.md
section 7 says the budget is, even if v1 only ever has one key.

**Save and load.** A game saved between the warning and the landings must come back with the tag, the alert and the
queued jobs; the jobs are in `storage.landing_jobs` already, the tag's handle must be kept (`LuaCustomChartTag` in
storage is fine) and the alert re-added if the save predates it. A game loaded with the director added (an old save):
`storage.director` nil, initialised on first tick with `last_event = game.tick` so a loaded save does not fire at once.

**Settings.** The personality is a string setting, runtime-global, read through `shared.setting` every tick it
matters, so an admin can switch it mid-game as the other levers allow (`settings.lua:8-10`). Its interplay: `lp-<corp>-
enabled` off must exclude that corporation from waves (`shared.enabled`, `shared.lua:701`), `lp-<corp>-camps` is the
settle rule's cap, `lp-landing-interval` is the fill period, and the difficulty preset and the aggression levers
(`tune.lua`) should enter the fill rate so a preset stays one thing; `lp-revenge-landings` off means no revenge event.
Document the fill and costs in `shared.lua` beside the levers' defaults, where the manual reads them.

**Testability.** The director scenario of the proposal (three simulated hours on a reference factory) is a visit, not
a regression: visits run on real saves and take an hour. The regression wants `wave` (section 3, 40 minutes, forkable
if the strike is late) in the quick set, and `director` (90 minutes, the stand-in base, personality steady, the budget
plotted by a small script beside `growth_plot.py`) in the growth area, run at batch ends. The area table
(`regress.sh:60-100`) needs a line for the module: `director` under `growth ops`, and `wave`, `director` in
`area_of_scenario`. The `/lp wave <corp> [n] [spread|beach]` verb in `dev.lua` beside `land` (`dev.lua:178-196`), and
the `dev` scenario's check that it lands n camps.

**The decision log.** Every director decision written through the same file the planner uses (`decisions.txt`, the
`base.trace` lines are the form) with its readings: era, W, D, L, B, the corporations' states, the event chosen and its
cost, or why nothing was chosen. Reviews read that file; a storyteller without a diary cannot be reviewed.

## 7. Recommendations, in order

1. Build the drop wave on the serial landing jobs: `faction.request` with `wave` and `turn` fields, `opts.expedition`
   skipping the cadence reset and `alive`, no relief for expeditions, the warning as a chart tag plus custom alert plus
   sound (notices are off by default), the withdrawal without the kill's payout. No multi-site search, no route-map
   store. Scenario `wave` with the ten checks of section 3, the settle and withdraw guard broken in both states.
2. Make the hold a gate in `faction.tick`, not a write to `f.next`; the four hastes stay as they are.
3. The budget in landings: fill `(1 + era / 2) * difficulty * personality` per landing interval, cap 4, costs 2.5 / 4 /
   1.5, the ladder surcharge, the cooldown by cost; the readings era, W by `get_entity_count`, D, L from a new 30-minute
   loss ring; two guards, the loss share and the defence trend. Numbers in `shared.lua`, calibrated from the contact
   runs. The gate `phases.arrived or director_force`, so no existing scenario changes.
4. The coordinated raid as a surge term in `ops.budget`, a `next_op` reset and a cool zone for the siblings; no
   stagger; the pincer is the spread wave plus a raid with the cool zone off.
5. Read, do not build: Synthexis's gate (`last_wave`, `herd.out`), the grudge (`d.grudge` as an owed revenge event),
   the stand-down (`b.quiescent` as the valley).
6. Cheap additions in the order of their cost: the revenge landing as an event, the salvage drop, the reinforcement
   drop, the sweep as Kessler-Hayashi's telegraph.
7. Before any of it ships: `profile.sh` at nine camps, the armed wave at two, the alert-on-another-surface spike, and
   `wave` on a deathworld with the biter attacks counted before and after a Grubstake wave.

# Part two: the operations side (the rewrite of 2026-11-13)

The user, of part one: "it seems we are mostly talking about landings. Shouldn't the director cover the possible
operations stemming from all camps in play?" `docs/director.md` was rewritten round dials the camps already read
(section 5) and beats made of dials turned together (section 6). Part one stands as written; this part reads the
rewrite against the code. Read for it, beyond part one's list: every writer of `b.next_op` (twelve, in four files), every
caller of `tune.sooner` and `stance.may`, `ops.finish`, `ops.setback`, `temper_allows`, `defence`, `odds`, `raid_want`,
`relevance`, `tactics.ladder`, `orbital.call` and its two callers, `besieged`, the clocks of `skim`, `strip`, `tap`,
`prowl`, `prospect` and `jumper`, `perimeter.lua`'s step, `pact.apply`, `standing.get`, the contact timeline's row and
`oplog.lua`. Still nothing run, nothing edited but this file.

The verdict first: the dials are the right shape and four of the six are cheap, because each has one reader the code
already funnels through (`budget`, `tune.sooner`, `relevance`, `storage.truces`). Two findings change the plan. A
siege push of several sieges at once is impossible as the code stands: `besieged(owner)` allows one siege against a
player force across every camp of every corporation. And intensity, which the rewrite calls "the single dial that
shapes the curve most", has nothing to turn for the first hour or two: the cap only bites with two or more camps at war
and able to field, which at the 90-minute cadence is the third hour at the earliest. The curve of the first hours is
tempo and lull. Section 11 reorders the build accordingly.

## 8. The dials against the code

**Intensity** is `budget(owner)` (`ops.lua:296-299`), `1 + era`. Four readers: the raid chooser (`ops.lua:599`,
`held`), the siege chooser (`siege.lua:400`), the strip chooser (`strip.lua:72`) and, which the rewrite does not
mention, `siege_tier` (`siege.lua:467`): a siege's tier is capped at the budget, so raising intensity also raises the
tier a camp may mount. Name that side effect and keep it; it is "how big". The dial is an additive term from storage,
`1 + era + surge[owner]`, floored at 1 (at 0 nothing but batteries would ever launch, which is the lull, not a low
intensity). Three lines, and its effect is already measurable: `storage.budget_holds` (`ops.lua:600`) counts every
time the cap held a target back, which the `budget` scenario reads today. What it fights: the floor. After
`FLOOR_TICKS` (20 minutes, `perimeter.lua:39`) without an operation against a player, player targets weigh `pressure`
(3) in every choice (`relevance`, `ops.lua:547`) and the cordon steps at once (`perimeter.lua:142-144`). A valley held
by a low intensity for twenty minutes trips the floor in every camp, and the valley ends in a rebound the director did
not price. The floor is a storyteller rule written before there was a storyteller (anti-stall for a careful player);
with the director on, the floor should be its: `floor = not director.on() and ...` at `ops.lua:580` and
`perimeter.lua:142`, and the director ends its own valleys. Cheap.

**Tempo.** `b.next_op` is written in twelve places, not nine: the gap after an outcome (`ops.lua:901-903`: `GAP_DONE`
5 minutes or `GAP_ABORTED` 10, through `tune.sooner`, plus a minute for every five lost), a clearance's minute
(`904`), a reprisal's pull-forward (`218`, `908`), the ledger's collection (`ledger.lua:258`), a setback's ten-minute
hold (`ops.lua:418`), four holds of two minutes when a launch found no staging point or route (`ops.lua:1349, 1497`,
`strip.lua:119`, `siege.lua:739`), and the dev reset (`ops.lua:2115`). They carry three meanings: a pace after an
outcome, a hold after a failure to launch, and a pull-forward. A tempo dial must scale the first and leave the second
alone: a camp held because it found no route to its staging point, pulled forward, retries the same failure every
thirty seconds (`DECIDE_TICKS`, `ops.lua:37`). The hook is `tune.sooner(corp, ticks)` (`tune.lua:30`), which already
divides a span by the aggression lever and is what the pace writers call: the outcome gap (`ops.lua:901`), the answer
cooldown (`answers.lua:51`), the skim (`skim.lua:203`), the tap (`tap.lua:209`) and the claim jumper
(`jumper.lua:120`). Put the director's factor inside `tune.sooner` and every one of those follows, which is exactly
Grubstake's spree for free, and none of the holds move. Two cautions. `farm.lua` calls `tune.sooner("biotech", ...)`
(`289, 2249, 2392`): the factor must return 1 for `biotech`, or decision 2 is broken by the plumbing. And do not put the
factor into `tune.aggression` itself: `stance.rung` (`stance.lua:57`) runs the ladder's clock by it and `war.quiet`
(`war.lua:553-555`) lengthens the stand-down by it; a spree would then also climb the ladder and postpone the
stand-down, two effects nobody asked for. For a surge that "cuts the gaps at once", the director writes `b.next_op =
math.min(b.next_op, now)`, a thirteenth writer, and only where the current value came from the pace, not from a hold:
`finish` and `setback` should record why (`b.next_op_why`), one field. The perimeter's step (`every`,
`perimeter.lua:136`, ten minutes) is not scaled by aggression today; passing it through `tune.sooner` is one line and
makes "Serenity's line moving faster" part of the tempo dial rather than a mechanism of its own. Cheap, with the two
cautions.

**Focus.** `relevance(b, t, c)` (`ops.lua:543-558`) is the table of named multipliers a choice carries (pressure 3,
battery 10, desperate 10, distracted 0.2, ground 2, grudge up to 5), and a mind may override each. Focus is one more:
`r * (1 + w.focus * near(t.pos))`, with `near` 1 within a radius and falling to 0 at three times it (my prior: 96 and
300 tiles, the cell and `valuemap.FAR`). A clean multiplier where `relevance` is read: the raid chooser's score
(`ops.lua:627-629`) and the armed siege chooser (`siege.lua:412-417`). Two readers it does not reach: the unarmed siege
chooser (the `b.armed` test at `siege.lua:412` keeps relevance to armed camps; a focus should reach any camp's sieges,
two lines) and the strip chooser (`strip.lua:53-88`), which takes the nearest outpost with a site and reads no
relevance at all; a focus on an outpost for Grubstake needs its own line there. The thefts outside the menu (skim, tap,
jumper, prowl, prospect) pick their own ground (the skim's belts by ring nearest the camp, `skim.lua:20`; the tap's
pole within `RANGE`, `tap.lua:27`) and a focus does not reach them without a line each; leave them, they are the thief's
own eye. The one thing a focus cannot do is point a camp at ground it has never seen: targets are intel
(`b.intel.targets`, the sensors within 300 tiles of a lander, `ops.lua:33`, the survey along the line to spawn,
`intel.lua:255`). The director can show it: `ops.sense_at(b, pos, r)` (`intel.lua:244`) is what `heard_landing` already
calls for every camp when one lands. A focus strike then begins with every camp sensing the focus, which is also its
announcement ("the corporations have surveyed your eastern outposts"). Cheap.

**Mix.** `prefer` at `ops.lua:2018` (`armed_prefer` or `prefer` from the mind) multiplies the three options at
`2052-2054`: raid, siege, strip, each times the tactics ladder. A tilt per kind is a clean multiplier on that table.
But the rewrite's "looting run (strips, skims, taps)" overreaches: only the strip is on that menu. Skims, taps, jumps,
prowls and prospects run on their own tick clocks with their own cooldowns (`skim.tick`, `tap.tick`, `jumper.tick`,
`prowl.tick`, `prospect.tick`), outside `choose`, outside the budget (`ops.player_ops` counts `b.op` only), and three of
them on `tune.sooner`. The mix dial does not reach them; the tempo dial does. So Grubstake's spree is tempo, not mix,
and the mix dial is really two things: a raid-or-siege tilt for Kessler-Hayashi and a strip tilt for Grubstake. The
siege push is the finding that matters: `besieged(owner)` (`siege.lua:311-316`) returns true while any camp of any
corporation has a siege on that player force, and the chooser refuses a second (`siege.lua:401`, `not (player and not
battery and besieged(owner))`). One siege against the player at a time, whatever the budget. A siege push of "sieges on
a focus from several camps" needs that rule to take a count the director sets (`besieged(owner) >= sieges_allowed`),
with 1 the default so nothing changes when it is off. And a siege needs more than permission: `SIEGE_COST` 100 parts,
`SIEGE_GUARDS` 6 in the field, the capability (level 1, or a grudge), `next_siege` after `SIEGE_COOL` 15 minutes
(`finish`), and for an armed camp `b.ground_clear` (`ops.lua:2022-2025`). A push can reset `b.next_siege` and
`b.strike_next` (`orbital.call`, `orbital.lua:65`, `COOL` 15 minutes); it cannot conjure parts or guards. Read `d.chest`
and each camp's `b.parts` and field before calling one; a push called on empty camps is one siege and silence. Mix is
cheap; the siege push is a small rule change plus readings.

**Lull.** It exists. `stance.standing` returns "truce" while `storage.truces[corp.."|"..owner]` is in the future
(`stance.lua:30-31`), and `stance.may` then refuses raid, siege, answer, strip, tap, jump, skim and war (`stance.lua:72`),
which `temper_allows` reads for raids (`ops.lua:452`), the siege chooser (`siege.lua:408`), the strip chooser
(`strip.lua:73`), the skim (`skim.lua:329`), the answers (`answers.lua:40, 71`), the cuts (`cuts.lua:24`) and
`war.at_war` (`war.lua:69`), so reliefs stop too (no camp "at war", `war.lua:610-612`), and the perimeter holds
(`perimeter.lua:139-141`). Only `debug_truce` writes it today (`control.lua:1258-1259`), since the bought truce went at
0.2.325; the player never sees the word (`standing.get`, `standing.lua:22-27`, reads provoked and hostile only). A lull
is `storage.truces[corp|owner] = tick + L` for each corporation: no new logic. Three things it does not stop, to name:
counter-battery (`battery(t)` is exempt before the stance, `ops.lua:450`; `choose_siege(b, army, true)` runs first,
`ops.lua:2007`), self-defence against a static threat on its ground, and Synthexis. And one thing it does: the ladder
keeps counting (`storage.last_raze` is only reset by a raze), so a lull of ten minutes buys every corporation a rung
(`stance.lua:58`: 10, 20, 30), and a lull of twenty trips the floor. That is a feature if the director knows it: the
lull is what loads the next peak, and its cost should be priced as a rung bought. Cheap; the rebound is the design.

**Rivals.** The camps are mutual enemies by default (no `set_cease_fire` between corporations anywhere; `pact.apply`,
`pact.lua:37-48`, sets it only with the biters), and they fight already through grievance (`know.grievance`, the
`grudge` weight in `relevance`) and reprisals (`ops.wronged`, `ops.lua:205-222`). What holds them off each other while
the player presses is `pressed` (`ops.lua:591-596`, rung 2 or more against a player: non-player targets held, line 603)
and `distracted` (0.2). A rivals dial is a lull on the player plus the `pressed` hold lifted, which is two lines. But
read the history before building it: Kessler-Hayashi's reprisals took Grubstake's camp in 37 minutes and the runaway
was tuned out twice (`rivals`, 2026-10-23 and 24; Grubstake's `grudge_max` 1.5 and `reprisals = false`,
`shared.lua:90`; `strategy.lua:21-26`, the threat term off). Grubstake will not war on Kessler-Hayashi by design, so
"two corporations turned on each other" is Kessler-Hayashi raiding Grubstake, which is the runaway with a director's
name on it. Not cheap, because the cost is in calibration, not code. Defer to step 4 as the rewrite has it, and give it
a cap (one reprisal raid, not a window) when it comes.

**Reliefs, orbital, the line.** Reliefs are not a dial and should not become one: `war.tick` sends one per
corporation per ten minutes to the camp at war on the highest rung (`war.lua:603-620`), from a chest the exports fill
(`CHEST_SHARE` 0.2, cap 6,000). A surge does not raise them; a lull stops them (above). The chest is the surge's fuel
gauge, read before a surge, never written. Orbital strikes are per siege (`siege.lua:1656, 1705`) behind
`b.strike_next` and the lever `lp-serenity-orbital-strikes` (`orbital.lua:61-64`); the barrage and sweeps
(`war.barrage`) are anti-nest, not pressure on the player, and do not belong in any beat. The line's pace joins tempo
(above); its direction is its own (`strangling`, `perimeter.lua:150-175`) and should stay so.

## 9. Can focus make coordinated raids from ordinary choice?

Yes for the where, with a guard; no for the when, which is the surge's job.

**How a target is weighed today** (`choose`, `ops.lua:563-660`): score = (value, doubled on the line, plus a threat bonus)
times odds to the power of `caution` (odds = r squared over 1 plus r squared, r the force it can field over
`needed(d)`, `ops.lua:522-526`), over (1 + defence) to the power of `loss_aversion`, over (1 + distance / 300), over
(1 + tries), times `relevance`. Before any of that, `temper_allows` (`ops.lua:437-474`) refuses: a truce, a marked
claim, a hurt camp, the thief's day, and exposure above the mind's cap until the ladder relaxes it (`LADDER_SOFT` 3 at
rung 1, nothing at rung 3, lines 456-462). After it, the odds gate (`on_foot`, line 619: `min_odds`, Grubstake 0.6,
Kessler-Hayashi 0.5), then the ladder of methods (`tactics.ladder`, `tactics.lua:159-181`: a method that failed at a
place lately is worth 1 over 1 plus its faded failures, held under `LADDER_HOLD` 0.75, `ops.lua:2041-2049`).

**How a focus of weight F interacts with each.** Against distance it is a straight trade: a focus 600 tiles off is
divided by 3, so F of 3 makes a far focus even with a near target of equal worth. Against defence it is weak: d of 2 at
`loss_aversion` 1.5 is a division by 5.2, d of 4 by 11; a focus of 3 flips choices between comparable targets and loses
to a wall, which is right. Against history it compounds: `tried` halves and the ladder quarters; a focus the camp has
failed at twice is a focus it will not take, which is also right. Against `pressure` (3) and `grudge` (to 5) it adds
one more factor of the same size; the product never exceeds what a desperate choice already multiplies by. The one
interaction to forbid: `desperate` (rung 3) relaxes the odds gate to `DESPERATE_ODDS` and takes the reserve
(`ops.lua:618-622`, `launch`, `1300-1306`); a focus at rung 3 chooses where a cost-no-object raid goes, and the
director should not focus while any corporation stands at rung 3 against that player. It is already throwing
everything.

**What keeps a focus from sending camps where they cannot win.** The same four gates as any raid, untouched by the
dial: temper (exposure), odds (`min_odds`), sizing (`raid_want`, `ops.lua:1218-1234`: `needed(d)` or the proven size
from the attempt history), and the pool's floor (`pool.take` at `launch`, the reserve kept). Then the aborts in `step`:
none left (`ops.lua:1624`), six minutes (`1625`, `MAX_TICKS`), half lost at the breach (`1830`), the share at the attack
(`1875`), ninety seconds without a kill (`1909`, `NO_KILL_TICKS`). An abort cools the target (`t.cool`, 15 minutes) and
counts in `fail_streak` (`ops.lua:896-899`), three of which stand the camp down (`war.lua:553-558`) and hasten a
landing. So a focus on a hard place does not drown the player; it burns the corporation's camps and ends in a
stand-down, which is the system's own verdict and should be the director's reading that the focus was wrong.

**The when.** Focus does nothing to timing: each camp decides on its own half minute when `tick >= b.next_op`
(`ops.lua:2010`). Two camps focused on one outpost launch when their gaps allow, minutes apart. Convergence comes from
the surge's `next_op` pull (section 8) and the budget term; the marches then differ by at most about 100 seconds
(part one, section 4). Focus chooses the where, surge the when, and the cool zone (part one) the "not the same
building"; the rewrite's "focus strike" is all three, and it should say so.

## 10. The beats by corporation

**Kessler-Hayashi, unarmed** (before era 3): `hostile` and `provoked_only` (`shared.lua:209`), so it is at war from
landing and `stance.may` allows its raids; it answers trespass with a siege (`answers`); its line steps toward the
player (`perimeter`, `cordon`); sieges from level 1; its mind prefers raids over sieges 2 to 1 (`prefer`,
`shared.lua:191`) and weighs its way in. A surge on it is raids on the hearts it knows and, if its parts allow, the one
siege. Its siege chooser ignores relevance while unarmed (`siege.lua:412`): a focus reaches its raids, not its siege,
until the two-line change. Its spree is the line: tempo on the perimeter's step plus its cuts (`cuts.lua`, the power
strike). A lull reads as "Kessler-Hayashi holds its line", which is what the notice should say.

**Kessler-Hayashi, armed** (era 3 and up): the fortress, `armed_prefer` siege equal to raid, the siege fund
(`siege_save` 0.3), sweeps, the relay, corridor strikes, and the orbital strike called when its mortars are up
(`siege.lua:1656`) or again on a standing siege after `COOL` (`1705`). The siege push is its beat and the one beat that
needs the `besieged` count: two armed camps on a focus, `next_siege` and `strike_next` reset, is two sieges with two
strikes on one part of the base, which is the picture the user described. Its counter-battery sieges are outside every
dial (self-defence): during a lull it still answers artillery, and the lull's notice should not promise otherwise.

**Grubstake:** `soft_only` keeps its rung at 0 until provoked (`stance.lua:40-44, 50`), so `pressure`, `desperate` and
the ladder's relaxation never apply to an unprovoked thief; its raids are held to exposure 1.0 (`max_exposure`,
`shared.lua:84`) and never at drills (`ops.lua:467`); its menu is strips first (`prefer.strip` 10); its thefts come
after dark (`thief_hours`, `ops.lua:427-433`; `skim.lua:324`, `jumper.lua:267`) and on `tune.sooner` cooldowns; its
skims, taps and jumps are outside the budget. So intensity barely touches it, mix touches its strips, and tempo is its
whole spree: shorter cooldowns on skim, tap and jump, and its strips sooner. Two consequences for the director. Its
beats must be scheduled at dusk (`surface.darkness`, read in `thief_hours`), or a Grubstake surge by day is a surge of
nothing until nightfall; the right feel is a night of thefts, announced at dusk ("Grubstake's trucks are out
tonight"). And a focus for Grubstake is a strip on that outpost (the line in `choose_strip`) plus its skims of the
belts there, which its own ring search finds only within 500 tiles of its camp (`RINGS`, `skim.lua:20`). Provoked, it
raids with half what it can field (`ENEMY_SHARE`, `ops.lua:1317-1321`) and the picture changes; the director reads
`d.provoked`.

**Synthexis** stays outside, and the plumbing must respect it: `tune.sooner("biotech", ...)` untouched (section 8),
`storage.truces` keyed by corporation and never for `biotech`, and its wave read (`f.last_wave + WAVE_GAP`, `herd.out`)
before any surge. Its waves target the player or Kessler-Hayashi by grievance (0.2.20); a rivals' war does not move
them.

## 11. The build order, and what the first scenario should measure

**The order.** Step 1 as written (state, budget, intensity, lull) builds the one dial with the least effect first.
With one camp at war, intensity is a cap of 1 on 1; it begins to matter when a second camp is at war with the player
and can field, which at the default cadence is the second landing of a corporation at war, 90 minutes after its first,
plus its escort's growth. For the first two hours the curve can only be made of tempo and lull. Reorder: step 1 is
state, budget, the readings, lull (the truce) and tempo (the `tune.sooner` factor with the `biotech` exclusion and
the `next_op_why` field), with the floor handed to the director; step 2 is intensity and focus (the surge and the focus
strike, with `sense_at` as the telegraph); step 3 the drop wave; step 4 mix, the siege push (`besieged` as a count),
sprees at dusk, the quiet events; step 5 rivals and the alliance strike. Each step's dial gets its scenario (`/lp lull`,
`/lp tempo`, `/lp focus`, `/lp surge`), the guard broken both ways: the dial on and the same run with it off.

**The reading.** "Operations at once per minute" is `ops.player_ops()` (the remote `threat`), and it is a poor
instrument for a curve: it is capped by the budget (1 to 5), quantised by the number of camps at war (usually 1 to 3),
and blind to thefts, which never set `b.op`. Three readings already exist and say more. `oplog.jsonl` (`oplog.lua`,
with the trace on) records every raid, siege, strip and wave from launch to end with its target, outcome and what it
destroyed; the launches per ten minutes from it are the pressure's rate. The contact timeline (`tests/lp-sim/control.lua:3200-3227`,
`scripts/timeline.py`) writes a row every five minutes with raids, sieges, done, aborted, razed, and the player's
census; it is the shape of a run. And `storage.threat_last` (`ops.lua:1532`) gives the minutes since the last launch
against the player, which is the valley's length. The felt curve is razed worth per ten minutes (the loss ring part one
proposed, which the director reads anyway) beside launches per ten minutes and the valley length. The first scenario's
checks, steady against off on the stand-in base over two to three hours, five seeds: the variance of the launch rate
is higher with the director on (the drizzle has become weather); the longest valley is at least 15 minutes and at most
40; at least one ten-minute window razes three times the median; and the total razed over the run is within 30 percent
of the off run at normal difficulty. The last check is the fairness check and the one most likely to fail first: a
director that reshapes pressure should not also inflate it, and if it does, the budget's fill is wrong, not the dials.
Add a plot (`scripts/ladder.py` and `growth_plot.py` are the models) of the three readings with the beats marked, for
the user to look at before any number is trusted.

## 12. What in the rewrite is wrong or incomplete

1. "Nine places write `b.next_op`": twelve, in `ops.lua` (eight), `strip.lua`, `siege.lua` and `ledger.lua`, with three
   meanings (section 8). The tempo dial must scale the pace writers through `tune.sooner` and leave the holds alone.
2. "Intensity: the single dial that shapes the curve most": not in the first hours, and it raises the siege tier as a
   side effect (`siege_tier`, `siege.lua:467`). Tempo and lull shape the first hours; intensity the third onward.
3. "Siege push: Kessler-Hayashi's mix tilted to sieges" from several camps: `besieged(owner)` (`siege.lua:311-316`)
   allows one siege per player force at a time, across every camp. The push needs that rule to take a count.
4. "Mix: a looting run (strips, skims, taps)": skims, taps, jumps, prowls and prospects are not on the chooser's menu
   nor under the budget; the mix dial cannot reach them, the tempo dial does (three of them call `tune.sooner`). And
   Grubstake's thefts are night-bound: its beats must be timed to dusk or they are announced and nothing happens.
5. "Lull: no new operations against the player": the truce standing does that in one write, but counter-battery and
   self-defence go on, the ladder's clock keeps running (a ten-minute lull buys a rung), and the floor fires at twenty
   minutes unless the director takes the floor over. Price the lull as the rung it buys.
6. "Rivals: two corporations' camps turned on each other": Grubstake will not (`reprisals = false`, `grudge_max` 1.5,
   by the runaway of 2026-10-24); the beat is Kessler-Hayashi on Grubstake, the runaway the project tuned out. Defer,
   and cap it when it comes.
7. Section 4 prices beats "on one scale" but gives no prices for the operations beats. In landings, as part one
   priced the waves: surge 1, focus strike 1.5, siege push 1.5, spree 1 (Grubstake's at dusk), lull 0 (it is what
   fills, and it costs a rung), drop wave 2.5 or 4.
8. Section 7, "a cap on beats at once read from the player's defences": one beat at a time, and its size by era, is
   enough; a second rule here is a second thing to calibrate.
9. Section 8, "intensity followed the curve (operations at once counted each minute)": the reading is capped and
   quantised (section 11). Count launches and razed worth per ten minutes, and the valley length, from what is logged.
10. Section 5's "a weight in each camp's target choice" is right, and it reaches raids and armed sieges only; the
    unarmed siege chooser and the strip chooser need a line each, or a focus on an outpost does nothing for Grubstake
    and nothing for an unarmed Kessler-Hayashi's mortars.

## 13. Recommendations for the operations side, in order

1. Reorder step 1: state, budget, readings, lull and tempo; intensity and focus in step 2. The first scenario measures
   launches and razed worth per ten minutes and the valley length, steady against off, with the total razed within
   30 percent of off as the fairness check.
2. Tempo inside `tune.sooner` with `biotech` excluded and `tune.aggression` untouched; `b.next_op_why` so a surge pulls
   paces and never holds; the perimeter's step through `tune.sooner`.
3. Lull as `storage.truces` per corporation; the floor (`ops.lua:580`, `perimeter.lua:142`) handed to the director
   while it is on; the lull priced as the rung it buys.
4. Intensity as `1 + era + surge`, floored at 1; its tier side effect named; `budget_holds` as its check.
5. Focus as a `relevance` weight (`ops.lua:543`) with `sense_at` as the telegraph; never while any corporation is at
   rung 3; the two missing readers (unarmed sieges, strips) given a line each.
6. `besieged(owner)` as a count the director sets, default 1, before any siege push; the push reads chests, parts and
   fields before it is called.
7. Grubstake's beats at dusk; rivals' war deferred and capped; reliefs and barrages left out of every beat.
