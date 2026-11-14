# The director (proposed 2026-11-13, not built)

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

## 10. Build order

1. The director's state, budget and readings; personality steady and off; tempo and lull, the two dials that act from
   the first camp on; the curve checked headless.
2. Intensity and focus; the surge and focus strike beats; the announcements.
3. The drop wave on the landing queue, the expedition flags and the quiet withdrawal.
4. Mix; the siege push (with `besieged` counting); sprees; quiet events with rewards; the off-map beats (supply drop
   and reinforcements first: pods exist); chaotic and gentle.
5. The rivals' war, capped; the alliance strike, once there is a shared grudge to trigger it.
