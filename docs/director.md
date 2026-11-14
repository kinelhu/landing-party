# The director (proposed 2026-11-13; built in steps, 0.2.372 to 0.2.393)

The user, 2026-11-13: "The site search seems to open up the possibilities for more varied landings too. Could even
envision some freak events with 3 landings at once for instance, or coordinated raids (think rimworld storyteller)." And,
of the first draft: "it seems we are mostly talking about landings. Shouldn't the director cover the possible operations
stemming from all camps in play?"

Step 1 (section 10) is built (0.2.372, scripts/director.lua; scenario director); the rest is not. The user's decisions are in section 9. A Fable design consult on the first draft, the
landings (part one), and on the operations (part two), is in `docs/reviews/2026-11-13-director-consult.md`; its
corrections are folded in here.

## 1. What paces the game today

Each camp decides for itself, with one crude cap above them all.

- **Operations:** each camp picks its next operation and its target (`choose`, `ops.lua`): a raid, a siege, a strip, a
  tap, a skim, a prowl, a prospect, an answer to a provocation. After one it waits a gap (`b.next_op`, set when the
  operation ends, shortened by reprisals and the ledger; a dozen places write it, with three meanings: a pace, a hold,
a pull). At most `1 + era` operations against a
  player run at once, across every camp of every corporation (`budget`, `ops.lua`).
- **Pressure:** each camp's ladder (`stance.rung`) rises 10, 20 and 30 minutes after it last razed something of a
  player's. Reliefs every 10 minutes from the war chest (`war.lua`), grudges for a destroyed lander (`faction.grudge`),
  and a posture that weighs all of it (`strategy.lua`).
- **Kessler-Hayashi:** orbital strikes and barrages (`orbital.lua`, `war.barrage`).
- **Synthexis:** its waves, on its own cadence and learning (`farm.lua`).
- **Landings:** every `lp-landing-interval` minutes (90 by default), one corporation at a time, up to `lp-<corp>-camps`
  camps each (3 by default). The opening is staged (`phases.lua`).

The result is a drizzle. No build-up before a peak, no breather after one, nothing bigger than one camp's operation, and
camps of one corporation that never act together.

## 2. What the director is

One layer above all camps in play decides when the pressure on the player rises and falls, where it points, and what
kind it is. It never decides how. It turns dials that already exist (section 5); the camps go on choosing their targets,
sizing their forces and finding their ways as they do now. A coordinated raid is several camps' ordinary choices made in
the same window toward the same focus. A Kessler-Hayashi siege push still looks like Kessler-Hayashi, a Grubstake looting
spree like Grubstake.

Landings are one of its levers (section 6, drop wave), not the centre of it.

## 3. What it reads

- **The player's strength:** their era (`ops.era`) and their factory's size, read cheaply (`LuaForce.get_entity_count`
  for a few prototypes, not a `valuemap.read`), and their defences' trend: whether their guns grow or shrink.
- **The player's recent losses:** a ring of what was razed in the last 30 minutes, by whom and where. A player just hit
  hard gets a breather.
- **The camps in play:** how many, of which corporations, at war or not; their garrisons, operations under way, war
  chests, grudges.
- **Pacing:** where it stands on its curve, minutes since its last beat, Synthexis's next wave.

## 4. Budget and pacing

A pressure budget fills over time and the director spends it on beats. The consult measured landings by the landing
interval; here every beat has a price on one scale: a surge, a focus, a siege push, a drop wave. It fills at
`(1 + era / 2) × difficulty × personality` a landing interval and holds at most four beats' worth, so it can neither
hoard an avalanche nor stay trivial against a grown factory. After a beat comes its cooldown, then a breather. Over an
hour: rising, a peak, a valley.

The guards against snowballing: nothing in the recent-loss window, and the player's defences' trend (a player losing
guns faster than they build them gets a longer valley).

Personalities (a map setting):

- **Steady:** a rising curve with regular peaks (Cassandra).
- **Chaotic:** the same budget at seeded random moments, longer gaps and bigger spikes (Randy).
- **Gentle:** half the budget, long breathers.
- **Off:** today's game.

Randomness from `rng.lua`, state in `storage`: a save, a load or a player joining mid-game sees the same director.

## 5. The dials it turns

Each is a number the camps already read. The director sets a multiplier or a weight for a while, then lets it go.

1. **Intensity:** the cap on operations against a player at once, `1 + era` today (`budget`, `ops.lua`; it also caps a
   siege's tier, `siege_tier`). In a valley it lowers it, at a peak raises it. It has nothing to turn until two camps
   can field at once, about the third hour at the default cadence (the consult): the first hours' curve is tempo and
   lull.
2. **Tempo:** the gap a camp waits before its next operation, scaled per corporation inside `tune.sooner`, which the
   pace writers already call (operations, answers, skims, taps, jumps); not `tune.aggression`, which also runs the
   ladder. A surge pulls paces in, never a hold. A shortened gap for one corporation for twenty minutes is its spree.
3. **Focus:** one more weight in each camp's target choice (`relevance`, `ops.lua`) for a while: a sector, an outpost,
   the player's power, their rails. It reaches raids and armed sieges; the unarmed siege chooser and the strip chooser
   take a line each. The camps' force sizing and aborts are untouched, so a focus never sends a camp at what it cannot
   win. Several camps converging on one focus is a coordinated raid, without a single new order.
4. **Mix:** a tilt in which kinds of operation the chooser picks. Skims, taps and jumps are outside the chooser and the
   budget: tempo reaches them, mix does not.
5. **Lull:** the truce standing that already exists (`storage.truces`, `stance.standing`), one entry a corporation. A
   lull would otherwise buy the camps ladder rungs (a rung every ten minutes without a raze), so during and after one
   the director owns the ladder's clock.
6. **Rivals:** deferred and capped (the consult): turned on Grubstake, Kessler-Hayashi's camps took it down to two
   buildings once (rivals, 2026-10-24), the runaway the posture's threat term was tuned out for.

The camps stay sovereign over how: what force a target needs, which way to go, when to abort. A dial only changes what
they want and how often.

## 6. Beats

Each beat is dials turned together for a while, or a landing, or both. Each is announced (section 7).

- **Surge:** intensity up and every camp's gap cut at once, for one corporation or all. Sibling camps launch within the
  same minute or two. (The consult: their marches differ by at most about 100 seconds, so no timed launch stagger.)
- **Focus strike:** a surge with a focus. Camps converge on one part of the base from their own directions, which is
  also the pincer, for free.
- **Siege push:** Kessler-Hayashi's mix tilted to sieges with barrages and orbital support, on a focus. Needs one
  change first: a player force can be besieged by one camp at a time (`besieged`, `siege.lua`), so several camps'
  sieges need it to take a count.
- **Spree:** one corporation's tempo up and mix tilted to its kind: Grubstake's thefts (night-bound: its beats go at
  dusk), Serenity's line moving faster.
- **Rivals' war:** deferred (section 5).
- **Lull:** a breather, sometimes with a reward: a crashed rival shuttle with salvage, like the signs wreckage in
  `phases.lua`; a corporation pulling a camp out.
- **Drop wave:** two or three landings at once, spread round the player or as a beachhead in one sector. Built on the
  landing queue, not a multi-site search (the consult): three queued jobs land 10 to 30 seconds apart, each seeing the
  last lander, `APART` for free, their ground generated one at a time. Kessler-Hayashi's share one sliced route map.
  Wave camps are an expedition (section 9): flagged so they neither reset the landing clock nor count against the camp
  cap, get no reliefs, and leave by a quiet withdrawal, not a lander's death (which drops three command cores and runs
  the fall).
- **Alliance strike (deferred):** a shared grudge's answer only (section 9).

### Off-map beats

The user, 2026-11-13: "think about 'off-map' events too. For instance a corporation dropping a resource bolus to one camp
or things like that." Each corporation has a world beyond the map: its war chest, its exports, its research tree, its
headquarters. Off-map beats change those numbers instead of sending anything across the map, so they are the cheapest:
no search, no landing, no route. Some raise the threat, some open a window for the player.

- **Supply drop:** a cargo pod of parts to one camp (`pods.lua` already brings reliefs). It comes down at a marked
  spot: destroyed as it lands, nothing reaches the camp; taken, its crate is salvage.
- **Reinforcements:** a relief drop scaled up, timed before a surge.
- **Breakthrough:** a corporation jumps a node of its tree (`rd.lua`), plated troopers for instance, and the notice says
  which ("Kessler-Hayashi has researched X.").
- **Export contract:** its headquarters wants a quota, and its camps put everything into mining for a while: fewer
  operations, more growth. Quieter, but a camp left alone through a contract comes out stronger.
- **Embargo or recall:** its income cut, or a camp's garrison rotated out for a quarter of an hour. A window the player
  can use, and announced as one.
- **Bounty:** its headquarters prices one of the player's buildings, which becomes the camps' focus for a while.
- **Intercepted transmission:** the player learns the next beat early, where a drop wave will come from for instance.
  A lull's reward.

The rule for all of them: each shows on the map (a pod coming down, a flare, a tag, an alert), not only as a number, and
most give the player something to do about it. A supply drop nobody can stop is a hidden buff.

Synthexis's waves stay its own (section 9); the director reads the next one and never stacks a beat on it.

## 7. Fairness and telegraphing

- Every threat beat is announced before it starts. Chat notices are off by default (`lp-chat-notices`), so the
  warning is a map tag where it will come from, an alert in the player's alert bar (`LuaPlayer.add_custom_alert`) and a
  sound.
- Every notice is factual, in the form the locale's notices already have ("__1__ has landed at __2__."): who, what,
  where (a map link), when. "Kessler-Hayashi: 3 landings in 60 seconds, north-east of [gps]." "Kessler-Hayashi's camp
  at [gps] has departed." No flavour text.
- Nothing in the recent-loss window. A cap on beats at once, read from the player's defences.
- The director's choices go into the decision log, as the planner's do.
- "Hold a landing" is a gate before the landing fires (`faction.tick`), never a write to `f.next`, which four other
  mechanics already write.

## 8. How it would be tested

- A director scenario over three simulated hours on a reference factory, personality steady against off: the beats and
  the budget plotted on a timeline. Its reading (the consult): launches and razed worth per ten minutes, from
  `oplog.jsonl` and the contact timeline, and the valleys' lengths; not operations at once, which is capped, coarse and
  blind to thefts. Checks: every beat announced first, none in a loss window, peaks and valleys where the curve put
  them, and the total razed within 30% of the off run (the director reshapes the pressure, it does not add to it).
- One scenario a dial: a focus forced (`/lp focus`) draws two camps' next targets into it; a lull forced holds every
  new operation; a surge cuts the gaps.
- A drop wave forced (`/lp wave`): three landed apart, the cadence untouched, the cap untouched, the expedition's
  withdrawal quiet.
- Visits on the user's saves with the replay page; a profile at nine camps.

The director gates on the opening (`phases.arrived`) or a test's switch, so no existing scenario changes.

## 9. Decisions (the user, 2026-11-13)

1. **Wave camps are an expedition that can settle**, not counted against the cap on landing. How it settles: the rule
   below (the user, 2026-11-14: "Ok on your suggestion for the camps").
2. **Synthexis keeps its own wave cadence; the director reads it** and never stacks a beat on a large wave.
3. **The personality is a map setting, steady by default, with "off".**
4. **No alliance strike in the first version;** a shared grudge triggers it if it comes.
5. **The director waits for the opening, then about 30 minutes** after the first landing.
6. **It covers every camp in play, not only landings:** it paces operations through the dials of section 5.

Decided (2026-11-14): an expedition camp still standing at about 45 minutes settles if its corporation has
room under the cap. Without room, it takes the place of the corporation's weakest standing camp only if it has
out-exported that camp and the player has not fought that camp in the last half hour; the camp displaced leaves
quietly ("Kessler-Hayashi's camp at [gps] has departed."; no command cores, no fall). Else the expedition withdraws. At
default settings a corporation usually stands at 2 or 3 of its 3 camps, so "settles if there is room" alone would
rarely fire; the guard keeps a camp the player has been grinding down from leaving under them and taking their work
with it.

## 9b. Decided overnight, for review (2026-11-14)

The user agreed to steps 2 to 4 overnight, each call a named prior in `shared.DIRECTOR`, listed here to be overturned.

Step 2 (0.2.377):
- **Which beat:** drawn as the director starts filling, from its rng in storage (seeded by the map): spree 0.5, surge
  0.3, focus strike 0.2 (`beat_weights`). A surge or a focus only with two camps at war or more (one camp's surge is a
  spree); it waits for the beat's cost. After any of them, a lull, as after a spree.
- **Surge:** every corporation at war with the player, Synthexis apart: tempo `surge_factor` 2, the cap on operations
  against the player at once `surge_add` 1 higher (ops' budget, which also caps a siege's tier), `surge_minutes` 15,
  `surge_cost` 2 (a spree is 1). Its camps' paced next operations pulled in, as a spree's.
- **Focus strike:** a surge with a focus, `focus_cost` 3: targets within `focus_radius` 64 of one point weigh
  `focus_weight` 4 times in every camp's choice (ops' relevance), so their next operations go there; the camps still
  size their own force and abort as ever. The point: the place the camps know best, their targets against the player
  by cell of `focus_radius`, each target's value summed over the camps that know it.
- **Notices:** at the beat's start, factual: "__1__ are stepping up their attacks for the next __2__ minutes." and "...
  on [gps] for the next __3__ minutes." Not before it starts: a surge's first operation is minutes off (its march),
  so the notice comes first in effect; a warning phase is an open question.
- **At war:** stance "enemy" only, as the spree's pick: Grubstake while only a rival is not in a surge.

Step 3 (0.2.378):
- **Drop wave:** `wave_size` 3 landings of one corporation, the one the spree's pick would take (at war, a camp
  standing, longest without a beat), queued at once on the landing queue as `faction.request` jobs of kind "wave":
  they land one after another, 10 to 30 s apart, each seeing the last. `wave_cost` 3, weighted 0.15 in the draw (also
  with one camp at war: it is how a second and third camp come). Told first: "__1__ is landing __2__ camps."; each
  landing tells itself as any does.
- **Off the clock:** a wave landing neither sets the next landing's time nor counts in the faction's landings (which
  gate the second corporation's entry), as a headquarters' landing does not.
- **Expedition:** each wave camp flagged; not counted by `faction.alive` (the cap, the cadence's choice, the director's
  own camp count), no reliefs (`war.lua`). Resolved at `expedition_minutes` 45 by the user's rule: room under the cap,
  it settles; else it takes the place of its corporation's weakest standing camp (fewest parts exported, never the
  headquarters) if it has exported more and the player has not hurt that camp in `fought_minutes` 30, that camp
  departing; else it withdraws. Told: "__1__'s camp at [gps] is staying." / "... has departed."
- **Departure:** `base.depart`: its whole roster, crews and operation, every building of its modules and lists, and its
  lander destroyed, not killed: no fall, no cascade, no ruins, no command cores. Marked fallen and departed.
- Not tested yet: the branch where an expedition takes another camp's place (the scenario's camps export nothing in
  its 16 minutes), and the settle-or-withdraw split was not seen failing. Expeditions are resolved only while the
  director is on: turned off with expeditions standing, they stand uncounted.

Step 4 (0.2.379), part of it:
- **Personalities:** gentle, half the fill (`personality.gentle` 0.5), its lulls twice as long (`lull_scale`), its beats
  only sprees and surges (`weights_of.gentle`: 0.6, 0.4); chaotic, the steady fill, its beats weighed evenly (spree,
  surge, focus, wave, 0.25 each; supply not among them) and each held a random while up to `chaos_minutes` 30 past its
  cost. Both in the setting.
- **Mix:** a spree tilts its corporation's choice of operation (ops' prefer) to its kind for the spree, `spree_mix`:
  Grubstake's strips 2x and raids 1.5x, Kessler-Hayashi's sieges 2x. Grubstake's spree waits for dusk (darkness
  `dusk` 0.25, as its skims). Other corporations' sprees untilted.
- **Reinforcements:** a surge first sends `surge_reinforce` 4 units by pod to each camp at war, from its headquarters
  (not its chest: `war.reinforce`); none to an expedition.
- **Supply drop:** an off-map beat, `supply_cost` 1, weighed 0.15 (steady): a crate by pod to the camp at war with the
  fewest parts, `supply_out` 40 tiles from it toward the player, tagged on the player's map ("Supply drop"); after
  `supply_wait` 3 minutes, if it stands, its `supply_parts` 300 reach the camp; destroyed or mined first, nothing does.
  It holds 150 iron plates, the player's to take. Told: "__1__ is dropping supplies at [gps]." and the outcome.
- **Not built:** the siege push (it needs `besieged`, one siege of a player at a time, made a count first), quiet events
  with rewards, the bounty and the intercepted transmission.
- Open: a drop wave or a supply drop now come in any long game the director runs in (30 minutes after the opening's
  arrival); the regression is the first look at what they do to scenarios that never expected them.

## 9c. Calibration (2026-11-14, overnight)

Scenario contact, 2 hours, seeds 12345 777 4242 101 31337, the walled and passive players, `LP_DIRECTOR=steady` against
off. The director came on at minute 35 in every run and fired no beat: the budget reached 0.84 at minute 115 (a fill of
about 0.011 a minute at era 0), and "hurt" was read in nearly every reading (losses of 8 to 146 worth in half an hour
against a factory read as about 370 worth; the line is 2%). On and off were identical. Questions for the user: the
fill's scale; the hurt line (a share of worth that a routine raid passes; perhaps losses past the player's own recent
rate instead); whether the worth reading (26 prototypes) sees enough of a factory. Nothing was tuned overnight.

## 9d. Over the camps' judgement (the user, 2026-11-14)

The user: "The director should probably be able to start doomed ops btw (going over the faction's decision making) no?
(If we give bonus income of course)". Agreed: past their judgement, not into hopeless fights. A doomed raid is kills,
veterancy and loot for the player and teaches nothing; the measured limit was units short of a raid the camp had chosen
(the smoke test's first spree: 8 of 11 decisions), not a want of nerve. Next step, together:
- **Commitment:** during a surge or a focus strike, the camps at war take the ladder's desperate odds bar (a lower
  min_odds, above a floor), named priors, announced with the beat.
- **Headquarters pays the gap:** a beat's camp short of units for a raid it chose gets them by pod from a subsidy (the
  income boost, aimed at the measured shortfall).
- **Probe (optional, later):** a small announced raid sent to learn the player's defences, its tactics ledger the gain.
Built once the calibration shows the shortfall across seeds.

## 9e. Threat points, and joint operations later (the user, 2026-11-14)

"It should add pressure depending on its settings. We've been getting inspo from rimworld." Each spree and surge now
brings a strike force from headquarters (RimWorld's threat points): the player's worth times `points_per_worth` (0.02),
the difficulty, the personality and the adaptation, `points_max` (40) at most, all to one lead camp (a camp with no
operation out, nearest the focus or the player), so a beat's points are its own, not a camp's. Then "this more or less
needs support for multi camp ops": not built. What exists: camps act alone (one operation each, its own units, staging
and ledger) and converge through a surge (their launches within a minute or two) and a focus (one area preferred),
unsynchronised. Joint operations, a later step: first a muster and a launch time across camps (the air raid's muster is
the nearest piece, within one camp), then one operation drawing several camps' units, with its ownership (whose ledger,
whose units home where, a camp fallen mid-way) and its sizing against the combined force.

## 9f. The breakthrough operation (proposed, the user, 2026-11-14)

From the visits: a Synthexis wave through an uncovered gap broke up to 6,154 buildings, a corporation's raid or siege
327 at most: a raid razes within 16 tiles of its target and goes home ("nothing left within 16"), a wave's biters each
take their own target and push in up to 260 tiles for 240 s. The user: "Maybe that could be another type of operation,
with its own triggers and possibly linked to director pressure." Proposed:
- **Trigger:** a breach the camp knows, its own raid or siege in there with few losses and no gun covering it (the
  tactics ledger's record); the breach a target till the player closes it.
- **What it does:** in through the breach and out sweeping, target after target while the resistance stays low; out at
  its time, past a loss share, or when the guns met grow. Kessler-Hayashi an armed sweep that razes; Grubstake a looting
  spree that carries off.
- **The director:** rare on a camp's own (risky and dear); in a surge or a focus strike a known breach the preferred
  target and the strike force into the sweep; gentle never; chaotic any time.
- **Fair warning:** a known breach marked on the player's map, so it can be closed first.
Order: the defender answering within 1 to 2 minutes on the wave itself first (the harness), then this, checked on
railbase_end and deathworld10x with Synthexis out.

## 9g. A fun director (built 0.2.393, the user, 2026-11-15)

The user: "please do your best to create a fun director." Fable's consult (docs/reviews/2026-11-15-fun-director-consult.md)
found section 7 unbuilt: at default settings only the spree was told, a strike team landed in the tick of its notice,
went for belts and poles, and vanished; recovery was not promised; the beats were alike on a metronome. Built:
- **Told.** Every beat and lull told by default (shared KEEP). Steady and gentle forecast the next beat and who brings
  it as the lull begins, at least forecast_minutes (10) before it; chaotic stays silent.
- **Warned.** A strike force told warn_minutes (2) before its pods: a chart tag at its target, an alert on the
  player's nearest building, a notice with its size and place. A focus strike's area tagged while it lasts.
- **Answerable, finishable.** A team goes for buildings that matter and the guns, fights what shoots it, then walks
  back to its landing point to be lifted out: the player can catch it and finish it.
- **Recovery.** A lull after every beat, lull_floor (5) to lull_max (30) by what the beat cost; hurt reachable on a
  late base (0.01 of worth, three times the usual).
- **A cycle.** Steady's every fourth beat the climax: a focus strike costing the whole budget, twice the strike force,
  told five minutes ahead, then the longest lull.
Measures (visits' metrics, section 3 of the consult): beats, lulls, forecasts, climaxes, notices told and held,
strikes finished by the player, the warning's lead to the first hit.

## 10. Build order

(The user, 2026-11-14: "once we're happy with the director on paper, a set of visits with various director settings on
a visualization document with time slider and annotations would be helpful.") The milestone after its calibration:
visits on copies of the user's saves (scripts/visit.sh) with the director off, gentle, steady and chaotic, a few hours
each; one page with a time slider, the director's beats and notices annotated on its timeline, the razed-worth curve,
the operations and their outcomes, and the map at each point; the settings side by side.

1. The director's state, budget and readings; personality steady and off; tempo and lull, the two dials that act from
   the first camp on; the curve checked headless.
2. Intensity and focus; the surge and focus strike beats; the announcements.
3. The drop wave on the landing queue, the expedition flags and the quiet withdrawal.
4. Mix; the siege push (with `besieged` counting); sprees; quiet events with rewards; the off-map beats (supply drop
   and reinforcements first: pods exist); chaotic and gentle.
5. The rivals' war, capped; the alliance strike, once there is a shared grudge to trigger it.
