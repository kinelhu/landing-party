<!-- Fable consult, 2026-11-15, read-only: what would make the director fun for a Factorio player, not only heavier.
Read: scripts/director.lua (0.2.392, the strike force an operation of its own), shared.DIRECTOR, shared.notice and KEEP,
ops.alert, war.strike_team, pods.lua, stance.rung, docs/director.md, the two earlier director consults (11-13, 11-14),
the notices consult (10-17), DESIGN.md's director entries of 11-14, locale.cfg's director strings, director_page.py. -->

# A fun director (read-only consult, 2026-11-15)

The brief: "please do your best to create a fun director." The earlier consults asked how much pressure the director
adds and what limits it. This one asks what a player at the keyboard would feel, and finds that most of what the
director does today the player cannot see, cannot see coming, and cannot win. Pressure the player cannot read is not
tension; it is attrition.

What the three reference designs agree on, stated as rules the code can be held to:

- RimWorld (Cassandra): threats come in cycles with a rise, a climax and a recovery long enough to rebuild; every raid is
  announced with who and from where before it arrives; the size is read from the colony's wealth so a player knows what
  grew the threat.
- RimWorld (Randy): the same beats at random moments, so the difference between storytellers is felt as rhythm, not as
  damage.
- Left 4 Dead: intensity is tracked from what is actually happening to the player, a peak is followed by a forced relax
  window, and the big set pieces are telegraphed (the horde's music, the tank's roar) so the squad can set up.
- Factorio players: they want a problem they can engineer out of. A spike they can see coming and place turrets against
  is fun; a belt gap or a dead pole two screens away found ten minutes later is a chore. A fight they can finish is fun;
  enemies that vanish are not.

## 1. Diagnosis: what is un-fun or invisible today

Ranked by how much of the director's work it hides.

**1. The director is silent at default settings.** `shared.notice` tells a notice only when `lp-chat-notices` is on or
the key is in `KEEP`, and `KEEP` holds one director key, `lp.director-spree`. The surge (`lp.director-surge`), the
focus strike (`lp.director-focus`, the only one with a map link), the drop wave, the supply drop and all three outcomes,
the expedition's settling and departure, and both lull notices are held. `ops.alert` (the raid, siege, strip and loot
alerts with the corporation's icon) returns early on `not shared.notices_on()`, so the operations a spree speeds up are
not alerted either. docs/director.md section 7 promises "a map tag where it will come from, an alert in the player's
alert bar and a sound" for every threat beat; none is built. The supply drop's chart tag (`crate_at`) is the only
in-world mark the director makes. A default player experiences the director as one chat line per spree and then the
engine's own "destroyed" alerts.

**2. The strike force has zero lead time and no "where".** `director.start_spree` and `start_surge` call `strike()`
and `tell()` in the same tick; the pods take 6.65 s (pods.lua) and the units get `attack_area` the moment they touch
down (`war.on_strike_landed`). The notice says "for the next 20 minutes" and never says where, yet the where is the
one thing the player can act on. The pods come down `behind(b, owner)` a camp, usually outside radar cover, so the march
is unseen too. By RimWorld's standard this is a raid with the letter delivered after the raiders are in the yard.

**3. The strike force's damage is the nuisance kind.** `STRIKE_TYPES` includes `wall`, `transport-belt`, `inserter`
and `electric-pole`, and each minute `director.strikes` sends the team to the nearest of those within 80 with
`distraction = by_anything`. On railbase_end a team broke 138 rails for 16 worth (DESIGN, 0.2.392): a line of small
breaks the player discovers later, one at a time. Then `u.destroy()` "lifts out" the survivors with no pod and no
retreat: the player who runs over with a tank finds nothing, gets no kill, no wreck, no veterancy, and cannot ever
finish a strike force. The encounter has no win condition for the player, only a timer.

**4. Recovery is neither guaranteed nor visible.** A lull follows only a beat that razed past the usual
(`lull_if_razed`), holds only the beat's corporations, lasts a flat `lull_minutes` 15, and its notice is held by
default. Meanwhile two clocks climb while the player is not hurt: `s.adapt` (+0.1 an hour) and the ladder
(`stance.rung`, a rung each 10 minutes without a raze). A player who defends well is answered with a bigger next beat and
no cue. The hurt guard that should give a breather after a disaster reads `hurt_floor` 0.05 of worth lost in 30 minutes:
3,750 worth on nwa, never reached on railbase_end in three hours. On a late base the director never says "you have been
hit, I will wait".

**5. The beats feel alike.** Spree, surge and focus are each "tempo x2, cap +1, a strike team"; the player's only
difference is how many corporation names are in the sentence. The two beats with a different shape, the drop wave
(three camps, told with no place) and the supply drop (a crate to race for), are weighted 0.15 and 0 in steady's draw
(`beat_weights`). Chaotic differs from steady only in `hold_till`. No beat but the supply drop has a counter-play
beyond killing things, and that one is out of the draw.

**6. The curve is a metronome, not a cycle.** The fill `(1 + era/2) × d / interval` is 0.011 a minute at era 0, so the
floor `spree_cost / beat_minutes` (one spree per 20 minutes) is the real rate at every era below 3. A beat fires as soon
as the budget reaches its cost (`s.budget >= cost_of`), so the cap of 4 is never reached and nothing ever costs 4: there
is no climax and no valley longer than a lull. Cassandra's shape (several small, one big, a long breath) is not there.

**7. The focus point is where the fight already is.** `focus_point` takes the camps' own intel targets by cell; the
point the camps know best is the edge they already raid. A focus strike concentrates on the contested edge, which the
player cannot tell from a surge, and its map link is held with chat off.

What is already right and should be kept: the hurt hold (`held_for = "hurt"`), the ladder's clock moved by the lull
(`end_lull`), the lull held only for the beat's corporations, Grubstake's dusk wait (a tell, once the player can see
it), the strike force as its own operation that never swells the garrison, the fairness lines in the decision log, and
the event stream, which makes every proxy in section 3 measurable without new logging.

## 2. Six changes, ranked by fun per hour of work

Each is an hour or two, uses what exists (notices, alerts, tags, pods, beats, the event stream), and has a scripted
check with a number. None touches Synthexis.

### 1. Telegraph the strike force: who, where, when, two minutes ahead

What changes for the player: before a strike team lands, an alert with the corporation's icon on their own building
nearest the strike's target, a chart tag at that target ("Kessler-Hayashi strike force") that stays until the team is
lifted, and a notice with the map link and the minutes. Then the pods come down. The player has the time to walk a tank
over or drop two turrets, which is the whole fun of a telegraphed raid.

How: split `strike()` in director.lua into `strike_warn` (now: picks the lead camp and the target as today, stores
`s.strikes[key]` with `pods_at = tick + warn_minutes × 3600`, tags, alerts, tells `lp.director-strike-warn`) and the
pod launch in `director.strikes` when `tick >= k.pods_at`. `warn_minutes` a named prior, 2 (the orbital cannon's paint
phase is the precedent). Alert through `LuaPlayer.add_custom_alert` ungated (a comment `-- notice-ok: fair warning`,
as the notices consult allows for "the only fair notice before a loss the player cannot see coming"); the notice key
into `KEEP`. The chart tag destroyed in the lift-out branch.

Test: scenario director, `LP_MIX=cmd` or the default spree: in events.jsonl, for every `beat` with `strike > 0`, a
`notice` with key `lp.director-strike-warn` and `told = true` with `storage.notices` false, then a `strike_landed`
event (add it to `war.on_strike_landed`) at least `warn_minutes` later, then the first loss whose killer is a team unit
(add `strike_hit` on the first `lost_strike` increment in `note_loss`). Number: warn-to-first-loss at least 2 minutes
in every run of the quick set; the warning's gps within `focus_radius` of the first strike loss in 100% of strikes.

### 2. Every beat and every lull told by default, with its place

What changes: the player always learns that a surge, a focus strike or a drop wave has begun and when a lull holds and
for how long. The focus strike's area gets a chart tag for its duration ("Attacks on this area, 15 min"), so the player
knows where to stand; a drop wave names its quarter (the landing queue's `f.from`, as a gps). The lull notice turns the
recovery into something the player can plan around: "Kessler-Hayashi is holding its attacks for the next 18 minutes" is
permission to go build the next furnace column.

How: `KEEP` gains `lp.director-surge`, `lp.director-focus`, `lp.director-wave`, `lp.director-lull`,
`lp.director-lull-many`, `lp.director-supply` (the drop's outcomes too). `start_surge` with a focus adds
`owner.add_chart_tag` at `at`, kept in `s.focus.tag`, destroyed when `s.focus.till` passes (a line in `director.tick`).
`start_wave` adds the gps of `f.from` to its notice (a locale change: "__1__ is landing __2__ camps near __3__.").

Test: scenario director with `storage.notices = false`: count of `notice` events with `told = true` over count of
`beat` events equals 1 (today: sprees only). Scenario `LP_MIX=focus`: a chart tag exists at the focus at minute 1 of the
beat and none at `till + 1`. Number: told share 100% at default settings; the first notice of every beat carries a gps
except the spree's (which the strike warning of change 1 carries).

### 3. Stakes the player can answer, and a fight they can finish

What changes: the strike team goes for buildings that matter at a point (assemblers, furnaces, drills, labs, roboports,
radars, power) instead of chewing the nearest belt, fights what shoots it rather than everything, and when its time is
up it walks back to where its pods landed and is lifted from there. The player who meets it gets a real fight at a
place they were told about; the player who chases it gets the wrecks and the kills if they catch it before the lift.

How: `STRIKE_TYPES` loses `wall`, `transport-belt`, `inserter`, `electric-pole` (keep `ammo-turret`, `electric-turret`,
`fluid-turret`: guns are a fair target the player placed to be shot at); `distraction = by_enemy` in both
`set_command` calls. In `director.strikes`, at `k.till` order `go_to_location` to `k.landed_at` (store the first pod's
touchdown in `on_strike_landed`) with `k.lift_at = tick + lift_minutes × 3600` (prior 3); destroy the survivors when
within 16 of it or at `lift_at`. Walls in the way: the engine's `attack_area` already breaks what blocks the path, so
walls still fall where they must, as collateral and not as the goal.

Test: scenario director: of the strike team's kills (events with `strike_hit`, or `lost_strike` by type if `note_loss`
records the type), the share with `valuemap.WORTH >= 1` at least 0.8 (railbase_end tonight: 16 worth over 138
buildings, about 0.1 worth a kill). `strike_lifted` happens only with the team's centroid within 16 of `landed_at` or
at `lift_at`. A forced check with `/lp` or the panel: a laser turret placed by the test beside the retreat point kills
the retreating team, and `strikes_over` records 0 lifted (the player can finish a strike).

### 4. Recovery proportional to the hit, with a floor, and a hurt line a late base can reach

What changes: every beat is followed by a short breather from the beat's corporations, and a beat that hurt is followed
by a long one, longer the more it took. The player learns the rhythm: after the big hit comes the quiet to rebuild in.
On a late base a disaster finally reads as "hurt", and the director waits.

How: in `director.tick`'s beat-end branch, lull minutes = `lull_floor` (prior 5) when not earned, else
`clamp(lull_minutes × lost_in / usual, lull_minutes, lull_max)` with `lull_max` 30 (gentle's `lull_scale` applies on
top). `hurt_floor` from 0.05 to 0.01 of worth and `hurt_factor` from 2 to 3, named priors with the readings they come
from (readings.json on the user's saves: say what 0.01 is in buildings on start, nw, nwa). The `held_for = "hurt"`
trace already exists; its notice (`lp.director-held`, "__1__ have been holding since your losses at __2__") is optional
and factual.

Test: scenario director with a scripted loss inside a beat (destroy 20 of the player's assemblers by script during the
spree, as `LP_MIX=step4` drives the panel): lull minutes read from the `beat` event with `kind = lull` grow with the loss
(5 with none, 15 at usual, 30 at four times usual). Number: truce minutes per hour at steady at least 10 on every quick
seed (today possibly 0 for a well-defended player); no `beat` event while `minute.hurt` is true (0 violations; this
check exists in spirit, make it explicit).

### 5. The forecast: steady and gentle tell the next beat as the fill begins

What changes: the player of a steady or gentle director gets a line as each fill starts ("Kessler-Hayashi is preparing
a larger operation", "Grubstake is preparing to land more camps"), 10 to 20 minutes before it comes; chaotic says
nothing, and that silence is what Randy feels like. This is RimWorld's "intercepted transmission" from director.md's
off-map list, and it is nearly free because `s.next_beat` is drawn at fill start (`director.tick`, the `draw` branch).

How: in that branch, for personalities other than chaotic, `tell(owner, "lp.director-next-" .. kind, name)` where kind
is spree, surge, focus or wave (the corporation named for a spree or wave: run `pick` at draw time and store
`s.next_corp`; the surge names "the corporations at war"). Keys into `KEEP`. Factual strings: "__1__ is preparing a
larger operation against you." / "__1__ is preparing to land more camps." The supply drop stays unannounced (a surprise
the player can still answer when the pod is tagged).

Test: scenario director at steady: every `beat` event (spree, surge, focus, wave) is preceded by a `notice` whose key
matches its kind, median lead at least 10 minutes; at chaotic none. Number: forecast coverage 100% at steady and
gentle, 0% at chaotic; forecast accuracy (kind told equals kind fired) 100% except a focus demoted to a surge for want
of camps, which the test counts and allows.

### 6. The climax cycle: every fourth beat at steady is the big one

What changes: steady gets Cassandra's shape. Three ordinary beats, then one that costs the whole cap: a focus strike
whose strike force is doubled (`points_max × 2`), warned 5 minutes ahead (change 1's `warn_minutes` for this beat only),
and always followed by the longest lull (`lull_max`). The player feels a rhythm they can learn: the big one is coming,
there is time to prepare, and after it a real breath. Chaotic draws the climax at a small weight at any time; gentle
never.

How: `s.cycle = (s.cycle or 0) + 1` per beat; at steady when `s.cycle % climax_every == 0` (prior 4) the next beat is
"climax": cost `cap`, `start_surge(..., focused = true)` with `strike_units` doubled and `warn_minutes` 5, then
`start_lull` with `lull_max` regardless of `lull_if_razed`. `weights_of.chaotic` gains `climax = 0.1`. The budget cap
of 4 is finally reached, which is what it was for. The focus point for a climax: not the camps' centroid but the
player's building of most worth within `STRIKE_REACH` of the lead camp (`valuemap.WORTH`), so the climax is aimed at
something the player cares about, and the tag of change 2 says where.

Test: scenario director at steady with a fill of 0.2 a minute (the test's `director_tune`), 60 minutes: `beat` events
show kinds in the order small, small, small, climax; the climax's `strike` is 2x the others'; its warning leads by 5
minutes; the lull after it is `lull_max`. Number: the peak 5-minute razed worth of a run comes in the climax window in
at least 4 of 5 seeds (if it does not, the climax is not the climax and the doubling is too small).

Not ranked but cheap: put the supply drop back into steady's draw at 0.1 now that it feeds the siege fund (the one beat
with a counter-play the player wins outright), and tag the pod at launch rather than at landing (3 minutes to race
instead of 3 minutes to notice). Not now: joint operations, the siege push, rivals, bounties; nothing in the fun
diagnosis asks for them before the six above.

## 3. Measuring fun headlessly

Fun cannot be measured, but its preconditions can: the player could see it coming, could do something about it, had
time to recover, and the game had a rhythm. All of the following come from events.jsonl (`beat`, `notice`, `minute`
with its per-minute losses, `strike_over`, and the two events added above) and ops.jsonl, so director_page.py can carry
them beside the razed-worth curve. Run each on the three scripted players (passive, walled, campaign) and on
`LP_MIX=defend`, because a proxy's value depends on who is answering.

1. **Warning lead.** For each beat, the time from its first told notice to the first loss to the beat's corporations
   (or to a strike unit). Report median and minimum. Target: median at least 2 minutes for strikes (change 1), 10 for
   forecast beats (change 5); minimum never 0 at steady or gentle.
2. **Seen-coming share.** The share of the player's razed worth in the run that fell within `focus_radius` of a told
   warning's gps during its beat. The director's own damage should be 100% warned. The whole-run share, director on
   against off, is the readability gained; the unwarned remainder is the camps' ordinary operations and Synthexis's
   waves, which are the corporations' own problem to telegraph.
3. **Answerable share.** Razed worth by type: point targets (`WORTH >= 1`) against nuisance (belts, inserters, poles,
   rails, walls). And the strike team's kill mix separately (change 3). Target: the strike's share of point targets at
   least 0.8; the run's nuisance share not higher with the director on than off.
4. **Finishable share.** Strike forces ended by the player (all dead before `till`) over strikes sent, and on the
   defender player the share killed before the lift. Today 0 by construction; any positive number means the player can
   win an encounter.
5. **Intensity curve shape.** Razed worth per 5 minutes over the run: peaks per hour (steady: 2 to 3), peak-to-valley
   ratio (at least 3: a flat curve is a drizzle), the largest 5-minute loss as a share of worth (below the hurt line
   except in a climax), and whether the peak falls in a beat window (if the peaks are Synthexis's, the director is not
   the storyteller of this run; report it as such rather than tune the director to it).
6. **Recovery windows.** After every beat, the quiet stretch before the next loss to the beat's corporations, against
   the lull told: a truce respected is the lull length or more, 100% of lulls. Truce minutes per hour (change 4's
   floor makes it at least 10 at steady). The time from a `hurt` reading to the next beat.
7. **Variety.** The entropy of beat kinds per run and the share of consecutive identical beats; chaotic against steady
   should differ in the inter-beat interval's variance, not in total razed.
8. **Agency used.** On the defender player, the turrets it places inside a told focus or strike area after the
   notice and before the loss (change 2 makes the area known; the defender's answer is a stand-in for the player's);
   supply drops destroyed or mined over supply drops sent.
9. **The fairness invariants, as checks that fail the run:** no beat while hurt; every beat told at default settings;
   every strike warned before its pods; every lull at least its floor.

A one-page reading for the user: the razed-worth curve with the beats and their warnings marked as vertical bands, the
lead time written on each, and the truce windows shaded. A fun director's page shows bands the player could read,
peaks inside them, and shade after every peak.
