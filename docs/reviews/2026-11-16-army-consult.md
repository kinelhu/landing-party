# The player's army: is it underdeveloped? (Fable, read-only, 2026-11-16)

The user: "One thing that is underdeveloped in our mod might be the player army side of things."

Read: CLAUDE.md; DESIGN.md (status table, the backlog, The army, What the player can do, The player's army, Veterancy,
Orbital cannons, Fought capture, the armydrop finding at 0.2.420); `landing-party/player.lua`, `units.lua`,
`shared.lua`, `counters.lua`, `scripts/command.lua`, `cards.lua`, `veterancy.lua`, `roads.lua`, `scanner.lua`,
`army.lua` (the factions'), `director.lua`, `war.lua`, `ops.lua` (VALUE); `docs/arena.md`, `docs/units.md`,
`docs/army-brief.md` (the user's own question of 2026-11-01), `docs/director.md`, `docs/calibration-2026-11-16.md`,
`docs/manual/army.qmd`, `headquarters.qmd`, `docs/release/modpage.md`, the whole-mod consult of 2026-10-29, the
playtest kits; scenarios `army`, `control`, `siege`, `duel`, `director armydrop` and `armyradar` in
`tests/lp-sim/control.lua`. Nothing run.

## Verdict

Half right. As a toolset the army is not underdeveloped; it is one of the most built-out parts of the mod: five units,
a barracks with item recipes, bandwidth from relays and cores, beacons with four stances and squad sizes, a selection
tool with cards and control groups, retire, muster points and trains, roads, charting, field repair, a threat scanner,
veterancy with field promotion. A player who finds all of it has more RTS than any other Factorio mod gives.

What is underdeveloped is its place in the loop, and that is what the user is feeling:

1. **It has never been measured in a whole game.** No contact variant fields one (`scripts/contact.sh`: passive,
   robots, walled, spread, late), no system-sim stand-in has one, no visit has had one. The user's own brief of
   2026-11-01 (`docs/army-brief.md`) asked for exactly that instrument first; it was never built. Everything the mod
   knows about the army comes from the arena and from scenarios that place units by script.
2. **Where it is measured, it loses at parity.** Scenario `director armydrop` (DESIGN 0.2.420): twelve riflemen beside
   a strike force of twelve killed 2 and all died; a mixed squad of twelve broke the force but lost 11 of 12 for 6,
   and the force razed the whole cluster before it broke, 16 against 16 with no army at all. Fought capture (DESIGN
   "Fought capture"): infantry never takes a defended position, 70 units at research level 3 take one outpost with
   16 left, and the trailer's battle lost 76 of 77 against a nine-turret Grubstake camp until the squad was staged as
   veterans (commit 26cd1a68). The one good result, `armyradar` (razed 6 against 16, 8 of 12 kept, none of the force
   home), is the case the manual now advertises, and it needs the player at the screen within two minutes of every
   warning.
3. **The job it was just given demands the player's presence.** The mod page and `headquarters.qmd` say the army is
   the answer to strike forces. In code the army has no stance that answers anything: a holding squad fights only
   what comes within 18 tiles of a unit and 50 of its rally point (`command.lua` ENGAGE, ATTACK_REACH), and nothing
   in `command.lua` reads the director's `strike_warn`, `strike_landed` or a raid's launch. The response the manual
   describes is the player's hand on the command tool, or a scanner, a decider and X/Y signals per cluster.
4. **Three leaks in the code undercut what is built** (section 2, points 3 and 5): a Grubstake blackout mast takes the
   army offline; a retired veteran comes back a recruit; Synthexis sits outside the command grammar.

So: do not add to the toolset. Give the army a stance that does the job the docs promise without the player, size what
it faces to what it can field, close the three leaks, then measure it in a contact variant. All of it is code and
scenarios; none of it is art or sound.

## 1. The army's job in the loop, and whether the toolset does it

**Jobs, as the design and the docs now give them.**
- Answer strike forces (director, 0.2.418 to 0.2.421; `shared.DIRECTOR` strike_land: "The player's army, not more
  turrets, its answer"). The newest job and the advertised one.
- Take ground: outposts by holding (capture), labs (scenario `breach`), camps and headquarters (the arc, "the player's
  army taking a camp as a non-turret answer", whole-mod consult). The oldest job and the one that still fails.
- Hunt what moves: survivors walking home (0.2.419: "Survivors you let go make a camp stronger"), sieges on the march,
  convoys, carriers, Grubstake's trucks (`docs/army-brief.md` job 4).
- Feed the spoils loop: command cores from depots, outposts and landers (`player.lua`), components for the field
  studies, merit for ranks.

**Reach in time.** Troopers walk 7.2 tiles/s, battle tanks 5.4 (`docs/units.md`); on refined concrete 1.5 times that
(`roads.lua`). A strike force warned 2 minutes ahead (warn_minutes) is 650 tiles away for a tank, further than any base
is wide. Warned, the army reaches anything. Unwarned (no radar over the landing spot, or a blackout), the force hits
2 s after touchdown and razes a cluster in 25 s (0.2.418 visit, armydrop): the army then only punishes. The warning is
earned by radar cover of the landing point (`director.lua` 1438: working radars, `get_max_distance_of_nearby_sector_
revealed`). Note that the command relay is a radar prototype with nearby reach 3 (`player.lua` 41), so every powered
relay already gives the warning three chunks round it; nobody has written that down.

**Win the fight.** The counter matrix (`counters.lua`, equal spend, positive = row wins) says the player's five kinds
cover both corporations' rosters completely (`docs/arena.md`: You against Kessler-Hayashi, coverage 100%, exposure
80%; against Grubstake 100% and 100%). But the cover is almost all one unit:
- The **battle tank** beats every ground kind of both corporations: tank 0.89, heavy tank (Aegis) 0.78, Prism 1.00,
  Tesla 1.00, Scorcher 0.97, Dozer 0.69, slug 0.62, shock 0.73, sapper 0.76, railgunner 1.00. Its only counters are
  fliers (laser drone and scrap copter, 1.00 each against it) and the shotgun hand (0.60). The Aegis, whose research
  trigger is "the player's battle tanks" (`shared.lua` 190: killer vehicle or lp-battle-tank, min 5), loses to it 0.78;
  Grubstake's slug, "the answer to the player's vehicles" (`shared.lua` 65), loses 0.62. The AI's designated answers do
  not answer.
- The **trooper** loses to everything Kessler-Hayashi researches against it: shock 0.93, Lance 0.55, slug 0.64, sapper
  0.89, Scorcher 0.38, and to every bred biter past medium (big and behemoth 1.00). It beats fliers (harrier 0.98,
  laser drone 0.77) and small biters.
- The **rocket trooper** beats armour and fliers (Aegis 0.69, laser drone 0.95, scrap copter 1.00, Prism 0.69) and
  loses to infantry and swarms.
- The **breacher** and **flame trooper** lose 1.00 to every hull and every flier; the breacher is for walls, the flamer
  for bred swarms (big biters 0.95, behemoths 0.66, the only infantry that beats them).

So a player who reads the matrix fields battle tanks and rocket troopers and nothing else from command bandwidth 2
on. The strike force's mix is tilted against what guards its target (`director.lua` strike_mix, strike_counter 1,
GUARD_TYPES includes units): a squad standing on the labs draws shock troopers and sappers if it is infantry, fliers
and shotgun hands if it is tanks. That is a good loop in principle. It is invisible to the player: the warning says
"n units", never what kind, while the director has `k.mix` in hand.

**Sustain.** A trooper takes 30 s, a tank 120 s, and every barracks after the first needs a core from a kill. Repair
only within 30 tiles of a powered barracks. Bandwidth 40 at level 1 (4 relays), 80 at level 2, 150 at level 3, 20 more
a level after (`shared.RELAYS_BY_LEVEL`, RELAY_CAPACITY). Against that: strike forces are points_per_worth times the
factory's worth up to points_max 40 (hard 60), climax twice that, and the calibration found them 15 to 58 units on
factories of 340 buildings and 9 technologies (`docs/calibration-2026-11-16.md`: "points_max binds early, so strike
size barely follows the base"). A level-1 player with 40 bandwidth of troopers meets 40 Kessler-Hayashi units of tanks,
Prisms and shock troopers. Lanchester says that army is gone in a minute; the matrix says it kills a couple on the way.

## 2. The weakest points, ranked by how much a player would feel them

**1. Nothing moves unless the player does.** The whole response the docs describe (watch the warning, select, send,
pull back) is manual, and the circuit alternative is a scanner, a decider and X/Y per cluster (`scanresponse`). The
user's own note on the salvage beat (2026-11-15: late game "the player is generally playing from map view or another
planet") applies to every strike force. A player who built an army and was on Vulcanus when the pods came down finds
twelve troopers standing at their beacon beside a razed lab row, and concludes the army is useless. That is the
feeling behind "underdeveloped", and it is a missing stance, not a missing unit.

**2. The strike force is sized to the factory's worth, not to what the player can field.** The one case where the army
wins (armyradar) is a force of 12 against a mixed squad of 12 worth more in parts. Real forces are 15 to 58 units
(calibration) on bases whose player, if they have the army at all, has 40 to 80 bandwidth. A player who brings the
whole level-1 army to the landing spot and loses it to Prisms in a minute learns not to bring it. The calibration
backlog already lists "strike forces sized to the base"; it should be sized to the answer as well.

**3. A blackout mast knocks the army offline.** `director.lua` MASTS.blackout holds every entity of `type = "radar"`
of the player's within blackout_radius 300 of a Grubstake camp at war (line 760: find_entities_filtered by type, no
name filter; disabled_by_script). The command relay is a radar prototype (`player.lua` 35). `command.relays()` counts a
relay only at `status == working` (line 69). So for 15 minutes the player's relays within 300 tiles go dark, the
capacity falls, and units past it stop and only fight back, newest first, with no chat line that says why (the
relay's own GUI reads "radar blacked out"; the army panel shows a count offline). The mast is drawn where "a radar of
the player's" is in reach, so a relay draws it too. The same type match puts relays in STRIKE_TYPES (line 1168) and
in the radar-cover check (line 1438); ops.VALUE already prices the relay highest of the player's buildings on purpose.
Of the three, only the blackout is clearly wrong: it is the one beat meant to blind the player, and it disarms them.
A player who does not know the relay is a radar sees their army freeze during a Grubstake attack and cannot explain it.

**4. The roster collapses to one unit, and the fight the army is meant to win is marginal.** From bandwidth 2 the
battle tank beats every ground kind at equal spend (section 1), so troopers, breachers and flamers are what a player
builds before they can build tanks, plus flamers against Synthexis. Bandwidth prices the tank at 6 troopers; the arena
says it is worth more. On offence the curve in "Fought capture" (30/10/5 wins once in three seeds, 20/10/10 twice,
30/20/20 at 130 bandwidth for a seven-turret outpost) and the trailer's 76 of 77 lost say that taking a camp costs the
whole level-3 army, against a camp that rebuilds, re-arms by counter and now has domes, arc flamers and mortars. A
player who tries once does not try again; artillery takes the camp for shells. `docs/army-brief.md` already stated
the rule (artillery stays; the army gets jobs artillery cannot do), and the director's strike force is the first such
job. Offence against camps should not be the measure of the army until the defensive job works.

**5. Three smaller leaks a player meets early.**
- *A retired veteran is a recruit again.* `command.lua` unit_to_order spills `{name = item, count = 1}` with no quality,
  and deploy creates the unit with no quality (lines 139, 774). DESIGN's Veterancy section marks this "assumed:
  probe before relying on it"; the code answers no. The playstyle the user wanted from veterancy ("preserving highly
  elite units") is punished by the squad-size mechanic, which retires the surplus farthest from the rally point
  (enforce, line 826), rank unregarded.
- *Synthexis is outside the command grammar.* `shared.corp_forces()` lists shared.CORPS, which excludes biotech
  (`shared.lua` 774; DESIGN: "Synthexis sends no strike force, not one of shared.CORPS"). So threat() never names a
  bred biter as a foe, the command tool's attack order cannot target a culture or its units (`command.order` filters
  by corp_forces; the manual says so), the beacon's E signal does not count them, and the scanner lumps them as Biters
  until a field study. The faction the player kills most, and the one that comes in waves of 60 to 200, is the one the
  army can only attack-move onto.
- *The manual contradicts the code on capture.* `army.qmd` 63: "capture does not work yet"; `base.lua` capture() runs
  every 600 ticks and scenario `army` checks "holding it captured it". The open item is capture at a fallen camp
  (status table, row "The fall"). A player who reads the manual will not try the one offensive job that works.

## 3. The smallest change for each

**1. A defend stance, driven by the mod's own events.** The director already emits `strike_warn` (with `land`, the
pods' spot, and `seen`), `strike_landed`, `strike_over`; ops knows every raid's target at launch. Add signal **D** to
the beacon (`command.lua` plan/lead): on a strike_warn seen or a strike landed within DEFEND_REACH (200, the beacon's
ASSIGN_RANGE) of the rally point, the squad attack-moves to the landing point (the existing `manual` attackmove
compound, by_anything then wander by_enemy); on strike_over, or 60 s with no corporation unit within reach, it walks
back to the rally point. Raids and sieges the same way from ops' launch (their target is in the record oplog reads).
Make D the stance the tutorial's beacon tip leads with. Cost: about 80 lines in command.lua, one event hook, a locale
line and a manual paragraph; a scenario: `director armyradar` with the squad placed at a D beacon 150 tiles off
instead of at the landing point, asserting the force breaks and razes less than against none, seen failing with the
stance off. No art, no sound, no balance (it automates what the manual tells the player to do by hand). Not a
commander: the squad goes where the mod says the attack is and comes back; circuits and the tool still override.

**2. Size the force to the answer and name its kind.** In `director.lua` strike (points), cap n so the force's arena
price is at most about 1.5 times the player's `command.capacity` in arena price when the player has the army research,
with the present floor below it (a player with no army still gets the sized force; the calibration's 15 to 58 on small
bases is the case to fix either way). And put `k.mix`'s two largest kinds in the warning text ("40 units, tanks and
shock troopers"): the director has it; the player's choice of what to send depends on it. Cost: ten lines, a locale
line, a check in `director armydrop` with capacity 20 asserting the force is bounded, seen failing; then the
calibration sweep already planned. Balance work, yes, but it is the sweep the backlog lists.

**3. Relays out of the blackout.** In MASTS or mast_tick, skip `lp-command-relay` (by name) for the blackout, and in
mast_site too so a relay alone does not draw a mast. Decide the other two type matches on purpose: I would keep the
relay as radar cover (document it: "a powered relay also warns you three chunks round it", a reason to put relays
forward) and keep it a strike target (ops already prices it highest; a strike at the relays is a legible beat, and
then the force's warning should name it). Cost: three lines; the `director blackout` scenario gains a relay and six
troopers and asserts none go offline, seen failing first.

**4. Price the roster from the arena, and leave offence alone for now.** The mod already re-prices faction units by
the arena's win share (0.2.272: Line trooper 10 to 11, 64% to 49%). Do the same for `shared.POPULATION`: the battle
tank's bandwidth from its win share against the matrix's ground kinds (it will come out above 6; the heavy shell of
0.2.266 was not re-priced). Then re-run the arena once with the Aegis's slug raised until it is even with the tank
(the unit exists to be that answer; today it is not). Cost: one arena run (13 minutes on four jobs), two numbers,
counters.lua regenerated, the manual's reference regenerated. No code. Do not touch fought capture before 1 to 3 are
in and measured.

**5. The leaks.**
- Retire with quality: spill the order at `u.quality` and create the unit with the stack's quality in deploy (probe
  first that an order item takes quality, DESIGN's own note); a check in scenario `retire`: a Veteran retired and put
  in a muster point comes out wearing its chevrons, seen failing. Ten lines.
- Synthexis in the grammar: add the biotech force to the forces threat(), command.order's target filter and the
  beacon's E report read (one helper, `shared.hostile_forces()`, used in the three places); a check in `control`: an
  attack order on an incubator is taken. Five lines. The scanner's field-study gate can stay.
- The manual line at `army.qmd` 63: say what is true ("Holding an outpost for a minute with none of the corporation's
  units or turrets within 20 tiles captures it; an outpost of a fallen camp cannot be captured yet") or fix the fall's
  capture; either way the sentence goes.

**Then the instrument.** A contact variant `army` (`scripts/contact.sh`): the walled base plus a fed barracks, two D
beacons, relays at level 2, against the walled variant without it; `fun_report.py` adds strike forces broken by the
army and razed with and without. That is the measurement the brief asked for on 2026-11-01, and the number that says
whether the army is an answer in a game nobody is scripting. Run it after 1 to 3, not before: before, it measures
clicks nobody is there to make.

## 4. What not to do

- **Do not add units.** Five kinds already cover 100% of both rosters (`docs/arena.md`); the gap is the loop. The
  light walker stays cut; no anti-air unit (the rocket trooper is one: laser drone 0.95, scrap copter 1.00, and the
  flak turret exists).
- **Do not build formations, columns or a commander.** The RTS assessment (`docs/reviews/2026-11-03-factorio-rts-
  assessment.md`) found nobody showed a march column cheap; the formation on arrival (0.2.341) is enough. A defend
  stance is a trigger, not an AI.
- **Do not nerf artillery or wall camps against it** to force the army. The brief's rule stands; the director gave the
  army a job artillery cannot do (a force inside the walls), and that is the job to make work.
- **Do not add an upkeep, a supply line or a new currency** to the army. Bandwidth, cores and training time are
  already three limits; the sustain problem is that what it faces is not sized to them, not that it needs a fourth.
- **Do not hide the army behind a setting** (the 2026-10-29 consult's call). That was right when the army had no job;
  the director gave it one. Finish the job instead.
- **Do not calibrate veterancy thresholds yet.** The two contact runs found 0 to 7 promotions, none the player's,
  because no run fielded the player's army. Calibrate after the `army` variant exists, from its numbers.
- **Do not measure the army by fought capture.** It is the hardest thing in the mod to win and the least needed; the
  arc wants a camp taken, but artillery already does that, and the counter matrix says a camp that re-arms by counter
  will always price the infantry out. Measure by strikes broken, targets saved, survivors denied, cores earned.

## Evidence index

- `landing-party/scripts/command.lua`: ENGAGE 18, ATTACK_REACH 50 (18 to 23); relays() status check (61 to 74);
  deploy without quality (130 to 155); threat() by corp_forces (370 to 381); lead() stances (471 to 574); order's
  target filter (684 to 690); unit_to_order spill without quality (770 to 781); enforce retiring by distance (826).
- `landing-party/scripts/director.lua`: MASTS.blackout type radar (281 to 288), the hold loop by type (758 to 765),
  STRIKE_TYPES with radar (1167), radar cover by type radar (1438 to 1446), strike_mix against GUARD_TYPES (1697 to
  1720), morale strike_break (1593 on).
- `landing-party/shared.lua`: DIRECTOR priors (strike_land, strike_guard, strike_counter, points_per_worth 0.02,
  points_max 40, warn_minutes 2, blackout_radius 300, blackout_minutes 15); POPULATION and RELAYS_BY_LEVEL (866,
  881 to 883); corp_forces (774); research triggers for the Aegis (190) and the slug (65).
- `landing-party/counters.lua`: the rows quoted (battle tank, trooper, rocket trooper, breacher, flame trooper) and
  the columns against them.
- `landing-party/player.lua`: the relay as a radar copy (35 to 42), recipes and research (253 to 351).
- `tests/lp-sim/control.lua`: `director armydrop`/`armyradar` (7759 to 7828), `army` (1111), `control` (2381),
  `siege` (19789), `duel` (19746), `breach` (5832).
- DESIGN.md: The player's army (939 to 1071), Veterancy (1073 to 1196), Fought capture (1809 to 1849), the armydrop
  finding (7602 to 7609), the trailer's knife's edge (6714 to 6725), status rows 115 to 122 and 140.
- `docs/calibration-2026-11-16.md` 55 to 57; `docs/arena.md` factions table; `docs/army-brief.md`;
  `docs/manual/army.qmd` 63, `headquarters.qmd` 78 to 80; `docs/release/modpage.md` 56 to 66.
