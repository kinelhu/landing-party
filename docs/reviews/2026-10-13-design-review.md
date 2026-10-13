# Landing Party: design review, 2026-10-13

Advisory review by Fable (read-only over DESIGN.md and the code), on the user's agenda: command cores as a
range limit, satellites as targets, AI that reads as disguised biter attacks, settlements that read as
reskinned biter bases. Kept as written; decisions taken from it are in DESIGN.md.

Where the reviewer says "checked" it read the code; "speculating" means untested.

## 1. Command cores as a range limit

What exists (checked, `command.lua`): two independent limiters. Relays give capacity (10 bandwidth each,
research gates how many count); cores gate the number of barracks. Units over capacity go offline
newest-first (`offline_set`), a mechanism that already does exactly what a leash needs.

Recommendation: **layer, do not replace, and do not put the radius on the core.** The core is scarce loot and
already does its job as the barracks key. Put the radius on the two buildings the player already places:

- A powered barracks controls units within 60 tiles (it already repairs within 30: it is a forward base in all
  but name).
- A powered relay controls units within 120 tiles and still carries its 10 bandwidth.
- A unit outside every control radius goes offline exactly as an over-capacity unit does today, with one
  exception: **R (retreat) always works**, otherwise a squad whose relay died is stranded forever. Lore: the
  retreat is pre-programmed.
- The orbital link (a satellite in the base game; see 2 for Space Age) removes the radius constraint and adds
  **no** capacity. Keep every unit of capacity on the ground, where it can be raided.

Why this is the right merge: relays stop being an abstract counter and become the player's supply graph, the
mirror of the faction's pylon lines that the player is told to cut. The arc falls out of the numbers: the
first landing is 350 tiles out; a barracks plus one relay reaches about 180. To attack, the player must build
a relay chain forward over open ground, and that chain is what a rational faction raids (see 3). Early game is
base defence with a short leash; mid game is a contested corridor; late game the satellite lifts the leash
while the capacity fight stays on the ground.

Cost: one distance check per unit against a short relay list every 2 s in `lead()`. Negligible.

One warning: the 50-tile beacon reach and a 120-tile relay radius must be explained by the same drawing. Draw
relay radii on the ground for the player's force as the beacon ring is drawn now, or the first "why did my
squad stop" will read as a bug.

## 2. Satellites as targets

Scope creep, and I would not do it. Three reasons, the first two checked against the engine: Space Age has no
satellite item (your own DESIGN notes this), so the orbital link needs two code paths from day one; space
platforms have no ground, no pathfinding and no unit prototypes, so "faction units attack the platform" means
building a second combat system on a surface that only knows asteroids; and anything you can build cheaply
there (a timer that knocks the link out, a relaunch cost) is a tax, not a fight, which is the "boring 1-tile
platform" the user fears.

What gets the same strategic shape on the ground: **jamming.** Faction radars and pickets (checked: `lp-radar`
currently does nothing but draw 300 kW and count as a military target) project a jamming field of 80 tiles.
Inside it the orbital link does not count; only ground relays do. The satellite then gives map-wide control
everywhere except on the faction's own ground, which is precisely where the player needs relays forward, which
the faction can hit. Pickets become the first thing a careful player kills, and the picket doctrine becomes a
real doctrine. If the uplink stands, let it widen the jammers' reach each tier instead of adding damage (see 5).

If the user still wants an orbital piece later, the one honest version in Space Age is an `lp-orbital-relay`
platform building that the player must keep powered and that asteroid damage can break. That is a maintenance
mini-game, not a war. Park it.

## 3. The AI feels like disguised biter attacks: because it is one

Checked, `army.lua`: a raid leaves when the garrison is 70% full, at the **nearest** player entity of 28 types
within 400 tiles of the lander, lamps, pipes and belts included; it runs `go_to_location` then `attack_area`
radius 24; it ends when the group reports finished or after 5 minutes; there is no sizing against the target,
no scouting, no abort, no memory. A response is the same with a threat count. That is the biter attack-group
loop with a cooldown. The fix is not more units; it is state.

### State (all in `storage`, per settlement)

`b.intel`: a list of known player objects, each `{pos, kind, value, defence, seen, tried, lost}`.
`b.intel.defences`: positions where faction units died, with the killer's kind, decaying over 20 minutes.
`b.op`: the current operation `{target, phase, needed, launched_n, kills_at_launch, staging, started}`. One op
per settlement at a time.

### Knowledge (how `intel` fills)

- Every faction radar and picket scans 100 tiles every 2 minutes (`find_entities_filtered` by type, once per
  radar: cheap at that cadence) and records player structures by category and the turret count within 30 of
  each.
- `on_entity_died` of a faction unit with a `cause`: record the cause's kind and position as a defence marker.
  You already attribute kills through `unit_owner`; this is the reverse.
- When any raid, response or patrol ends (`settle`), count turrets within 50 of its destination and update that
  target's `defence`.
- Nothing outside these is known. A target the faction has never seen cannot be chosen. The player can be
  invisible by killing pickets.

### Objectives (what is worth what)

Value by kind, mirrored on the faction's own vulnerabilities so the enemy teaches the player how to hurt it:
command relay 10, barracks 8, electric pole that is a cut point (one neighbour on each side) 6, train stop or
rail 5, mining drill 4, assembler 3, turret 1, lamp, pipe, belt 0. Score = value / (1 + defence)^1.5, times a
distance falloff, minus a penalty for `tried` without success. The best score wins; ties go nearer.

### Planning (force vs defence, scouting)

Needed force = 6 per known turret + 4, the same arithmetic as your responses. If the target's `seen` is older
than 15 minutes, the op's first phase is a **scout**: two harriers (or one infantry at tier 0) fly to 40 tiles
from the target, wait 10 s, record, return. Then the settlement waits until `strength >= needed` instead of
leaving at 70% of cap. If the garrison cap cannot reach `needed`, pick the next target down the list. A
settlement with no affordable target raids nothing, and its parts go to fortify and export. That silence is
itself a signal to the player.

### Execution

- **Staging**: a point on the line from depot to target, 10 tiles beyond the furthest known turret range (24
  for lasers). Order the group there with `go_to_location`; hold until 80% of members are within 15 tiles (you
  already do this for convoys; reuse `escort_step`'s logic).
- **Approach bearing**: among 8 bearings around the target, take the one whose 30-tile sector holds the fewest
  known defence markers. Stage on that side.
- **Order of march**: two engine groups, tanks and walkers first, infantry and harriers ordered 3 s later. The
  blob is the engine's; two groups give a front. Speculating on how much this reads in play.
- **Attack**: `attack_area` on the objective's position with radius 12, not 24, so the group does not wander
  into the next turret cluster.

### Abort and retreat

Every 5 s while the op runs: alive / launched_n < 0.5 and the target still has a turret within 30: abort. No
kill in 90 s (compare `b.razed` with `kills_at_launch`): abort. Abort sets `defence = max(known, observed)`,
increments `tried`, retreats to the staging point then home, and puts a 10-minute cooldown on that target. A
response uses the same rule and additionally marks the spot as the settlement's threat direction, which the
planner's `picket` and `defend` rules then prefer (`threat(b)` currently uses `find_nearest_enemy`; read the
intel instead).

All of this is `LuaCommandable.set_command`, `find_entities_filtered`, `count_entities_filtered` and tables.
No new prototypes. The expensive calls happen once per op phase, not per tick.

## 4. Settlements as reskinned biter bases

The shape (static light defence, mobile reaction force) is right and is already there (checked: `army.alarm`,
`patrol`). What is missing is everything that makes it look like a decision:

- **The garrison has no roles.** Raids, responses, patrols, convoy escorts and intercepts all draw from one
  pool with a home guard of 2. After one response the base is empty. Split it: reserve 30% (never leaves),
  reaction (responses, intercepts), field (raids, escorts). Raids stop draining defence and the player can
  observe a settlement "under strength" after bleeding its field force.
- **The alarm has one setting.** Any damage to any building, lamps and walls included, by any non-faction force
  (checked: biters trigger it too and count as threats in `threat_count`) draws at least six units once a
  minute. Scale by damage taken in the last 30 s, not by a head count, and make the first answer small (3)
  with escalation (6, then 12) if the alarm repeats at the same spot within 5 minutes. A player chipping a wall
  with a pistol should draw a patrol, not a company.
- **Nothing changes after an attack.** `undefended` marks an outpost defended once and never revisits it. After
  a response fights at an outpost: post 2 units there for 10 minutes, clear `m.defended`, and let the `defend`
  rule add a second turret pair. A sprawl settlement that loses two outposts should start walling: doctrine
  as a starting posture that escalates, not a constant.
- **Pickets are blind.** Make them eyes: a player military entity within 60 of a picket raises a sighting, a
  3-unit sortie before any damage is done. "They saw me coming" is the single cheapest way to read as a rival
  rather than a hive.
- **Patrols** are fine as life; they should also feed intel (anything a patrol sees within 30 goes into
  `b.intel`).

## 5. What still reads as Biters+

- **Tier = +15% damage** (checked, `faction.lua`): that is the evolution factor with a different name. Tiers
  should buy capabilities and posture (harriers, walkers, shields on walkers, jammer reach, a doctrine step
  up), never a flat multiplier the player cannot see or counter.
- **Raid targeting by nearest entity**: covered in 3. The biggest tell.
- **Arrival**: a settlement appears when a timer fires. Make the landing an event: 60 s of warning with the
  zone charted and marked; player military inside the zone at touchdown pushes the site to the next ring. The
  faction's first act becomes a contest, and "they arrive because of you" gains a verb.
- **Rebuild in place** and **expansion by ore reach** are fine; "unless occupied" already separates them from
  biter expansion.
- **Art** is honest about being tinted vanilla; the harrier (destroyer robot) and tank hull already read as
  machines. Leave it until mechanics settle.

The three changes with the most leverage: objectives with abort (3), tier as capability instead of damage, and
the landing as a contestable event.

## 6. The core loop and the playthrough

The minimal loop that must feel good before the uplink, corporations or new units: **they land on your ore,
you read the settlement, you hurt its economy, it reacts visibly, it hurts you back somewhere that makes
sense, you take and hold an outpost, it adapts.** Of those seven beats, three are missing or invisible today:

- "read the settlement": the only state exposed in game is the debug label on the lander (checked,
  `label(b)`). The player cannot see income, maturity, garrison or what the settlement is waiting for. A
  reading tool is a prerequisite for a strategy game, not polish: show the label to players within 100 tiles,
  or expose it through a captured picket.
- "hurts you back somewhere that makes sense": item 3.
- "it adapts": item 4.

The first-contact playthrough is the right next step, with one caution: a scripted player plays the loop the
developer imagined. Make it produce a timeline and let the user read it rather than asserting a verdict.
Measure, every 5 minutes for 3 hours: faction strength (garrison, turrets, parts income) against the player's
(turrets, troopers, bandwidth); time from landing to first wall, first depot, first raid; what each raid hit
and whether that target was worth anything; losses per side; whether the scripted player survives with
turrets alone and never builds a barracks (if yes, the army is optional and the loop is broken); and how many
minutes the "camp window" is open before walls stand. Two numbers I would want first: minutes from landing to
the first raid, and the ratio of faction parts income to the player's iron income at minute 60.

## 7. Priorities (next stretch)

1. **Raid objectives with intel, sizing and abort** (3, minimal version: intel from deaths and settles, value
   table, abort at 50%): the single biggest change in feel.
2. **Garrison roles and post-attack re-fortify** (4): defence that reads as a decision.
3. **First-contact playthrough with the timeline metrics** (6): pacing is unknown and everything else is tuned
   against it.
4. **Settlement state readable in game** (6): a strategy game needs a scouting answer.
5. **Relay control radius, layered on bandwidth** (1): makes relays territory; `offline_set` already does the
   hard part.
6. **Tier as capability and doctrine escalation, not damage** (5): removes the evolution factor.
7. **Landing as a contestable event** (5): gives arrival a verb.
8. **Pickets as eyes, jamming as the ground answer to the satellite** (2, 4): makes a decorative prototype
   matter.

## 8. Cut or simplify

- The tier damage modifier: remove, replace by unlocks.
- The 5-minute raid timeout as the only end condition: replace by the abort rules.
- The 28-entry `TARGET_TYPES` list: replace by the value table; lamps and pipes at value 0 fall out.
- Train interceptors: keep what works, fold trains into the intel as a target kind, invest nothing more.
- Convoy discipline (about 140 lines for an animation): freeze it; stop tuning spread.
- Endless bandwidth research level 4: harmless, but if relays get a radius, research should buy radius or
  capacity, not relay count; reconsider then.
- The uplink as the third landing, and rival corporations: park both until the loop above feels good at real
  clocks. Corporations in particular multiply every problem in 3 and 4 by the number of factions.
- Walkers at tier 2: fine to keep, but note that nothing in the first 2 hours of a real clock reaches tier 1
  (3,000 parts exported), so harriers and walkers are not part of the loop you are about to measure.
