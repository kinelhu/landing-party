# Army logistics: should the army strain the factory? (Fable, read-only, 2026-11-19)

The user: "Do you foresee a situation in this mod where army building becomes a logistic strain on the factory? A sort of
continuous fight?" Then, of ammunition upkeep, paid repair and threat that scales: "We might do all but this is a huge
change and probably needs a design consult. Rearming and repairing seems like it could also be a job done by logo bots."

Read: CLAUDE.md; DESIGN.md (status table, the backlog, The army, The player's army including the Supply proposal of
2026-10-13 and the measured defend, Veterancy, the findings 0.2.448 to 0.2.463); `docs/reviews/2026-11-16-army-consult.md`;
`docs/playtest.md`; `docs/army-brief.md`; `docs/arena.md`; `docs/calibration-2026-11-16.md` (55 to 57); `docs/manual/
army.qmd`; `landing-party/player.lua`, `shared.lua` (POPULATION, RELAY*, DIRECTOR, units), `units.lua` (base_unit, gun,
make_infantry, make_tank, the gun buggy), `counters.lua`, `control.lua` (the event hooks), `scripts/command.lua` (relays,
deploy, train, order, lead, repair, tick), `scripts/director.lua` (strike_units, the point pricing), `scripts/veterancy.lua`
(the swap); `tests/lp-sim/control.lua` (the scenario list, the barracks setups, the roboports with repair packs);
`scripts/regress.sh` (the area table); `scripts/contact.sh`. The version-matched API, `$APP/doc-html/prototype-api.json`
and `runtime-api.json` (2.1.24): UnitPrototype, EntityWithHealthPrototype, CarPrototype, VehiclePrototype,
ConstructionRobotPrototype, RoboportPrototype, LogisticContainerPrototype, RepairToolPrototype, StickerPrototype,
EntityPrototypeFlags, ScriptTriggerEffectItem, LuaEntity (health, is_registered_for_repair, get_logistic_point,
commandable), LuaCommandable, on_script_trigger_effect, on_entity_damaged. Vanilla data: the character's flags, the biters'
flags, the gun turret, the repair pack, the kit recipes. Nothing run.

## Verdict

Yes to a continuous fight, no to a strain, and the two are different questions.

**A strain will not come from upkeep.** The numbers say the army's cost to the factory is losses, by a factor of about
thirty. On the director save (DESIGN 0.2.457) the first strike cost 37 of 50 units; a trooper's kit is about 425 plates
(heavy armour 100 copper and 50 steel, the gun, ten magazines: `player.lua` 304), so that beat cost some 15,000 plates and
25 minutes of one barracks. The same fight, with every unit spending ammunition as it fires, would spend about 100
magazines, 400 iron plates, two or three per cent of the bill. Repair packs are cheaper still: one pack mends 600 health
(speed 2, durability 300), a fifth of a pack a trooper. A factory that makes a yellow belt of plates does not feel either.
Nor should it: in vanilla, idle turrets cost nothing and a fight costs what it fires. The one upkeep the army already
pays, and nobody has written down, is power: a command relay draws 2 MW (`player.lua` 43), 0.2 MW a point of bandwidth,
10 MW on the director save, 30 MW at level 3's fifteen relays, 200 MW for the thousand-unit army the user wants to UPS-test.
That is the number that scales with owning.

**So the reason to build ammunition upkeep is not tonnage. It is three other things**, and they are good reasons:
1. The inverted cost closes. A gun turret eats a magazine a second of fire (cooldown 6, ten rounds a magazine) and a
   trooper eats nothing; the design says the army, not more turrets, is the answer to strikes, and today the answer is the
   cheaper of the two to run.
2. The army gets a supply line, which is the thing Factorio players enjoy building and the corporations enjoy raiding. A
   depot of magazines at a forward beacon, fed by robots or a train, is both a factory problem and a soft target.
3. A squad gets a rhythm: fight, run dry, walk back, rearm, return. That is what makes a continuous fight a fight and not
   a wall. It also gives the veteran-preserving play style (DESIGN, Veterancy) its natural exit from a fight.

**The engine's limits shape the design** (section 2): a unit has no inventory, no equipment grid and no logistic point,
so robots can never hand a unit anything. Ammunition is a counter the script keeps, spent per shot by a script trigger on
the unit's own gun, refilled from a container the robots can fill. Repair is different: the player's units carry the
`not-repairable` flag (`units.lua` 79, copied from the biters); dropped for the player's six, construction robots with
repair packs should repair them wherever a roboport reaches, which is the user's wish served by the engine with no
script. That needs one spike before anything rests on it.

**The previous consult (2026-11-16) said "do not add an upkeep, a supply line or a new currency" and it was right then**:
the army had no job that worked. The defend stance, strikes priced by strength, the right-click assign and the wild
biters have since given it one (0.2.436 to 0.2.463). The original design of 2026-10-13 already had supply as the next step
after field repair (DESIGN "The player's army": "units out of range of a powered beacon, or a forward depot fed by
logistics, stop healing and slowly lose effectiveness"). The question is open again, and the answer is a small one first.

**Recommended first stage: the loadout.** Each unit carries the ammunition its order was trained with, ten magazines a
trooper, twenty shells a tank; a shot spends a round; empty, it stops firing and walks to the nearest powered barracks
whose input holds its ammunition, rearms there and comes back; the beacon reports its squad's ammunition share. No new
prototype, no new number (the recipes already say how much a unit carries), a setting to turn it off for the arena and
the comparison runs. Then the depot the robots fill, then repair by the robots, then the threat cap the user has already
agreed to raise. Each stage is measured against the stage before on the same scenarios.

## 1. Is this the right direction? What makes a continuous fight fun

**Where the continuous fight already comes from.** Nothing in the code makes an idle army cost anything but power. The
fight is continuous only where the world supplies it: a holding squad clears every wild and Synthexis nest within its
reach (0.2.462, `command.lua` nest), so on a biter map a squad by a nest field fights until the field is gone or the squad
is; Synthexis's waves of 60 to 200 come as often as its culture can pay; the director sends a beat every `beat_minutes`
(20) at steady, a strike force at most `points_max` 40 points, a climax twice that (`shared.DIRECTOR`); Grubstake raids
and Kessler-Hayashi besieges on their own clocks. On a map with no nests near and the director on gentle, an army stands
at its beacons and costs 2 MW a relay. That is right: a mod whose army demands feeding when nothing is happening is a tax.

**The user's faction arc wants the army all game** (memory: Synthexis all game, Grubstake early to late, Kessler-Hayashi
late and armed; "the player army is needed, no artillery nerf"). The 2026-11-16 consult's finding stands: the army's
jobs are strikes inside the walls, things that move, and nests out of reach; artillery keeps the camps. None of those jobs
needs an upkeep to exist. What the upkeep adds is that doing them costs something proportional to the doing, and that a
player who sends a squad far from home has to think about what feeds it, as they do for an outpost's turrets.

**What would make it fun, from what this project already knows:**
- *Cost follows fighting, never owning.* Vanilla's rule. Idle units spend nothing; a fight spends rounds; a death spends
  the kit. The user rejected the stockpile exploit (0.2.448) and a deploy delay ("Minutes to deploy? Inside a base..?"):
  they want the army present and the costs honest, not slow.
- *Automatic, never a click.* The playtest's refrain is that nothing should need the player at the screen (the user,
  2026-11-15: late game they play "from map view or another planet"). A dry unit must rearm itself, at a place the player
  built, and the beacon's circuit must be able to read the squad's state and pull it back. A rearm the player has to order
  is a chore; one that happens because a depot stands by the beacon is a system.
- *Legible.* The notices rule (memory: who, what, where, when). A unit's card shows its magazine; the beacon reports the
  squad's share; a depot is a chest, so its contents are already on the wire. A squad that stops shooting with nothing
  said would read as a bug.
- *A supply line is something to attack.* Grubstake's snatch raids go where no turret covers (status table: "a snatch
  raid where no turret covers"); a depot of magazines at a forward beacon is exactly that target, and that is good: it
  gives the player a reason to put a turret there and the corporations a thing to take. Kessler-Hayashi's blackout mast
  already attacks the army's other upkeep, power (the relays were taken out of it, 0.2.436).
- *The rhythm must fit the director's.* A lull is at least `lull_floor` 5 minutes; a trooper walks 150 tiles in 21 s and
  a tank in 28 s (DEFEND_REACH's own comment). A squad that fought a beat is rearmed long before the next. A climax
  (double points, `climax_points` 2) is where a depot runs dry, and that is the strain the user is asking about, arriving
  on the big beats and not as a drip.

**What would make it a chore, to avoid by design:** units leaving mid-fight one by one for ammunition (mitigated by
loadouts that outlast a normal fight, section 4, and by the circuit's R on a low share); a dry squad stranded far from
any supply (an empty unit with no barracks or depot within reach holds where it is and says so); a second currency
(ammunition is the player's own magazines, shells and rockets, already made for turrets and the tank); any cost on a
unit that is not fighting.

## 2. Logistic robots: what the engine allows

Looked up in the 2.1.24 API, not remembered.

**A unit cannot be handed anything.** `UnitPrototype` has no `inventory_size`, no `equipment_grid`, no `guns`; those are
`CarPrototype` and `VehiclePrototype` properties (a car with `trash_inventory_size` above 0 gets a logistics tab and
robots serve it, which is how the spidertron works). The player's six units are `unit` prototypes (`units.lua` base_unit
copies the medium biter) because only units and spider-units have a `LuaCommandable`, and everything in `command.lua` is
`commandable.set_command`. A unit has no `LuaLogisticPoint`, so logistic robots have nothing to deliver to. Making the
units cars would lose the command grammar. **Robots rearming units in the field is not possible.** What is possible is
robots stocking the place a unit rearms at.

**Ammunition is a counter the script keeps.** Per unit, in `storage.cmd.troopers[k]` beside `beacon` and `manual`. How
it is spent, two ways, both engine-honest:
- *Per shot, exactly.* A `script` trigger effect (`ScriptTriggerEffectItem`: `effect_id`) added to the player's six
  units' `attack_parameters.ammo_type.action` in data-final-fixes, as `source_effects`; `on_script_trigger_effect` gives
  `source_entity`, the unit that fired. The mod already handles this event for aim, the field studies and the burst effects
  (`control.lua` 90), so the hook exists. Research that raises fire rate (weapon shooting speed applies to units: the
  techprobe of 0.2.449) raises the spend, as it does for a turret. Cost: a trooper fires three rounds a second (cooldown
  20 ticks), 200 troopers in a fight are 600 events a second, ten a tick, each a table decrement. Measure it (section 4);
  the fallback is below. Open: whether the flame trooper's stream delivery fires `source_effects` once a shot or once a
  stream (a spike; the flame trooper can count fight time instead).
- *Per pass, approximately.* `lead()` runs every 120 ticks over every unit; a unit whose `commandable.distraction_command`
  is set or whose key starts with `fight:` spends two seconds of its rate. No event, no data change, less exact (a unit
  "fighting" out of range spends rounds it never fired). Good enough as a fallback if the trigger costs.

**Empty, a unit cannot be made weaker, only silent.** No per-entity damage modifier exists: `StickerPrototype` modifies
movement, vehicle speed and damage taken, not damage dealt; force modifiers are per force; `attack_parameters` are fixed at
data stage. Two ways: (a) an order to the rearm point with `distraction = none`, under which a unit never fires (units
fire only through attack commands and distractions), so an empty unit walks and takes fire without answering; (b) a swap
to a "dry" variant prototype with a sidearm, which `veterancy.lua` already knows how to do (a promotion is a swap that
carries the group, the command and every stored reference, DESIGN Veterancy). (a) first: no prototypes, and the cost
of being dry is the walk. (b) later if dry units dying on the walk reads as unfair.

**Where a unit rearms.** Three candidates, compared:
- *A powered barracks, from its input* (no new prototype). An assembling machine's input holds its recipe's ingredients
  only, so a barracks on troopers holds magazines and no shells: a mixed squad needs a barracks per kind in reach, or
  waits. The far outpost's reserve is already a train-fed barracks (0.2.448), which would rearm its squad with nothing
  new built. Smallest step.
- *A supply depot the robots fill* (one new prototype, `lp-supply-depot`): a `logistic-container` with `logistic_mode =
  "requester"` (the `LogisticMode` union: active-provider, passive-provider, requester, storage, buffer), the requester
  chest's body re-skinned. The player sets its requests (magazines, shells, rockets, grenades, flamethrower ammo, repair
  packs); logistic robots fill it from the network; inserters and trains fill it too, since it is a chest; circuits read it,
  since it is a chest. The script, once a second, for each depot, rearms the player's units within SUPPLY_RANGE (the
  barracks' REPAIR_RANGE 30 is the precedent) from its contents, one `find_entities_filtered` a depot as `repair()` does
  now. This is the user's idea in engine terms: the robots do the logistics, the depot does the handing over. Place one
  by each forward beacon.
- *Robots servicing units in the field.* Not possible for ammunition (above). For repair, see next.

**Repair by construction robots is the engine's own mechanism, if the flag goes.** `EntityPrototypeFlags` has
`not-repairable`: "the entity can not be healed by repair packs or construction robots with repair packs". Vanilla's
character carries it (`entities.lua` 707); vanilla's biters carry it (`enemies.lua` 76); and `units.lua` 79 sets it on
every unit the mod makes, the player's six included. Everything else with health is repaired by robots from a roboport's
`material_slots_count` (7 slots of repair packs, construction radius 55) if it is damaged and in range; `LuaEntity.is_
registered_for_repair` is the queue. Drop the flag for the player's six in data-final-fixes and roboports should mend
them in the field, paid in repair packs, with robots flying out to units in a fight and some dying, as they do for turrets.
**Assumed until a spike:** that a moving `unit` is registered for repair at all and that robots follow it (vanilla has no
player-force unit to prove it on; the flag's own description says the flag is what prevents it). The spike is small: a
damaged trooper, a roboport with packs and a robot, read its health over 30 s and `is_registered_for_repair`; then the same
walking. The barracks' free repair (`repair()`, 2% a second within 30 tiles of a powered barracks) stays as what R
promises ("walks back and heals there") or is made to draw repair packs from the depot too; decide after the spike.

**UPS.** The army script today: `lead()` every 2 s over every unit with `plan()` a beacon and `threat()` a unit (a
`find_entities_filtered` within ENGAGE 18), `routes_tick` every 10 ticks, `chart_army` every second, `repair()` and
`train()` every second (`command.lua` tick, 1447 to 1455). A depot's rearm is one more area search a depot a second, not a
unit. The per-shot trigger is the only new per-unit cost and it is in proportion to fighting, which is when the engine is
already busy with the units' own combat. The user's agreed UPS run at 200, 500 and 1,000 units should run with ammunition
on and off, so the trigger's share is read, not guessed.

## 3. How ammunition upkeep meets what exists

**The loadouts the recipes already state** (checked in `player.lua` 262 to 308 and `units.lua`; base rate, no research;
magazines hold 10 rounds, flamethrower ammo 100):

| Unit | Carries | Rate | Fires for |
|---|---|---|---|
| Trooper | 10 magazines, 100 rounds | cooldown 20, 3 a second | 33 s |
| Breacher | 10 grenades | cooldown 180 | 30 s |
| Rocket trooper | 10 rockets | cooldown 150 | 25 s |
| Flame trooper | 10 ammo, 1,000 | cooldown 4 | 67 s |
| Gun buggy | 20 piercing magazines, 200 rounds | cooldown 30 | 100 s |
| Battle tank | 20 shells | cooldown 180 | 60 s |

Against a gun turret: one magazine a second of fire, ten held (`automated_ammo_count`), 50 damage a magazine with yellow
rounds; a trooper does 80 a magazine (8 a round). The rates are of the same order, so the inverted cost closes without a
new number. The 25 to 33 s of the infantry is the figure to test first: the measured defends (DESIGN "Measured",
armydefend) break a force in 70 to 100 s of fighting, so troopers would run dry mid-fight. Whether that is the design
(a squad that cycles) or a fault (a squad that evaporates) is the first measurement of stage 1. If it is a fault, the
remedy is a named prior (the loadout a multiple of the order's items) or more magazines in the order, which raises the
kit's price; the user's call.

**The arena and the counters.** `counters.lua` is measured at equal spend with no ammunition limit; the director's
strike_mix and Synthexis's breed tilt read it. With the loadout on, a kind with a short loadout (rocket trooper, 25 s)
would lose any arena fight that outlasts it, and the matrix would move for a reason that has nothing to do with the
weapons. Recommendation: the arena fights with ammunition off (a startup setting read by `tests/lp-arena`), so the
counters keep pricing a supplied unit, and `arena_report.py` logs fight durations once, to show how many arena fights
outlast each loadout. The strike's point pricing (0.2.457, `director.lua` 1436 to 1450) prices by the corporation's
parts and is untouched.

**Turrets.** Nothing changes for them. The player now pays the same kind of cost on both answers, and the manual's
army chapter can say so in one line.

**Veterancy.** The best synergy here. A dry veteran withdraws and lives; a circuit that reads the squad's ammunition
share and sends R at 30% is the mechanical form of "preserving highly elite units" (the user, 2026-11-10). The promotion
swap must carry the ammunition counter with the unit (veterancy already moves `storage.cmd.troopers` by unit number; the
counter lives in that record, so it moves for free; check it in scenario `veteran`).

**The far outpost barracks fed by train** (0.2.448). In stage 1 it is also the outpost's rearm point: the train that
brings kit for orders brings the magazines the squad draws. In stage 2 the same train fills a depot beside the beacon.
The outpost's logistics become one problem, which is the point.

**Retire.** A retired unit's remaining rounds go with its kit (0.2.448: "nothing handed back"). Consistent.

**The director's strike sizing.** Unchanged in stage 1 to 3; the force is sized to the base's worth (`strike_units`:
`min(points_max, worth * points_per_worth * personality)` times difficulty and adaptation) and never reads the player's
bandwidth (`director.lua` has no reference to `command.capacity`, checked). What changes is the squad's readiness: a squad
that fought the last beat and stands dry is weaker for the next, and a depot that runs out during a climax is the
legible failure. Both are what the user asked for. Stage 4 is the cap the user agreed to raise with the base's size, and
the previous consult's rule that a force's arena price be at most about 1.5 times the player's capacity in arena price;
with upkeep in, size it to the army the player can field and feed.

**The infinite bandwidth tech.** Level L costs 150 L packs of four kinds (`player.lua` 379) for two relays, 20 points, so
a late base buys population cheaply; the user agreed to UPS-test 200, 500 and 1,000 before settling the curve. Upkeep does
not fix that balance and should not try: ammunition scales with fighting, not owning. What already scales with owning is
power, 0.2 MW a point; the UPS runs should report the relays' draw at each size so the user sees the number before
choosing between a steeper curve and letting power be the late brake.

**Corporations pay no ammunition.** Their camps pay parts for units (the planner's army keep) and their sieges carry
their own shells (siege tiers, resupply convoys). The asymmetry is the one the mod already has: the player pays in items,
the AI in an abstraction. Fine.

## 4. The recommended design, staged

Every stage is dormant where its scenario does not set it up (memory: new fixes dormant until their failure case), is
compared before and after on the scenarios it touches with their metrics and not their pass/fail, and ships with the
quick set. Each has a setting so the regressions and the arena can run it off.

**Stage 1: the loadout** (the smallest valuable step; `command.lua`, data-final-fixes for the trigger, the squad panel,
the cards, a locale line, a manual paragraph).
- Each unit carries its order's ammunition, read from the order's recipe at deploy (`shared.ORDERS`, the recipe's ammo
  ingredients times their magazine size): no number typed. Units already on the map at migration get a full loadout.
- A shot spends a round (the script trigger on the six units' guns; the per-pass fallback if the trigger costs).
- Empty, the unit stops firing (go_to_location, distraction none) to the nearest powered barracks within MAX_OFFSET 300
  whose input holds its ammunition; rearms there (`inventory.remove` from the crafter input; the inserter refills the
  recipe as always); walks back to its beacon. No barracks with its ammunition in reach: it holds where it stands, a
  flying text at the unit once and the hint mechanism's chat line once a force ("no ammunition within reach").
- The beacon reports **M**, its squad's ammunition share, 0 to 100 (REPORTED gains a signal); the squad panel shows it;
  a unit's card gets a magazine bar beside its health. A unit at a quarter or less is marked (the chevrons' way).
- Setting `lp-army-ammo` (startup, default on). The arena runs it off.
- Measure headless before the user plays: scenario `rearm` (name free in `tests/lp-sim/control.lua`; area `player` in
  `regress.sh`): one squad of each kind at a barracks of its kind against a target that cannot die (a wall of neutral
  entities, or `/lp`'s frozen tank as the vetprobe does); the shots to empty equal the loadout within 5%; each unit
  walks back, draws from the barracks input (the input's count falls by the loadout), returns; with no barracks of its
  kind within 300 it holds and the hint fires once; seen failing with the counter off. Then `director armydefend` and
  `armyhold`, `wild`, `nestclear`, `nestclear tech`, `siege` and `scanresponse` on 0.2.463 and on the new code, seed 12345
  and 777: units dry during the fight, the force broken or not, labs razed, losses, time to break. The reading that
  decides the loadout question above: how many troopers ran dry before the force broke in armydefend. If most did, the
  loadout is too small for the design's own fight and the user chooses between a multiple and dearer orders.
- Risks: the fight evaporating (above); the flame trooper's stream and the trigger (spike first, count time if not);
  the trigger's cost at 1,000 units (read it in the UPS run); units walking into fire on the way home (what R already
  does; the arena-honest cost of being dry); the arena matrix if someone runs it with ammunition on (the setting).

**Stage 2: the supply depot** (one prototype in `player.lua`, requester-chest body; `command.lua` rearm from depots too;
the manual's circuit section).
- `lp-supply-depot`: a requester logistic container, unlocked with command bandwidth 1 (or 2, with the robots), requests
  set by the player; the script rearms units within SUPPLY_RANGE from it before any barracks; it also holds repair packs
  for stage 3. Readable on the wire as any chest.
- Measure: scenario `depot`: a depot fed by logistic robots from a passive provider through a roboport (the system
  sim's stand-in already builds roboports with packs, `control.lua` 4674), a squad dry beside it rearmed within 10 s, the
  robots seen carrying (the depot's count rises then falls); a second variant fed by an inserter from a chest; a third
  with the depot empty, the squad walking to the barracks instead. Then `director armydefend` with a depot by the D
  beacon: the fight should now last the loadout plus a rearm cycle, and the metric to read is magazines drawn a beat.
- Risks: a depot inside a camp's reach is a soft target by design, so it dies; say so in the manual rather than
  armour it. Robots carrying to a forward depot under fire die, vanilla's own trade-off.

**Stage 3: repair by the robots** (data-final-fixes; a decision on `repair()`).
- Spike `repairprobe` first (a damaged trooper, a roboport, packs, a robot; still and walking; `is_registered_for_repair`;
  health over time). If the engine repairs units: drop `not-repairable` for the player's six only (the corporations'
  units keep it, or Grubstake's roboport-less camps are unaffected anyway), and decide the barracks' free repair: keep
  it as R's promise at home, or make it draw packs from a depot or its own input. If the engine does not: the script
  spends repair packs from the depot at the barracks' rate, and the user's wish is served through the depot the robots
  fill, not the robots themselves.
- Measure: the probe; then `director armydefend` with roboports and packs, reading packs used and units saved against
  stage 2; `veteran` unchanged.
- Risks: robots swarming a fight (vanilla behaviour; it is the player's choice to put a roboport there); the free repair
  staying as a loophole (a squad parked by a barracks never needs packs; acceptable, that is what home means).

**Stage 4: threat with the factory** (already agreed; `director.lua` strike_units, `shared.DIRECTOR`).
- `points_max` rises with the base's worth rather than capping at 40 for everything past a small base (calibration:
  15 to 58 on 340-building factories, "points_max binds early"); the previous consult's rule bounds a force's arena
  price at about 1.5 times what the player can field. Add the readiness term only if the measurements ask for it: a
  force sized to the capacity should not also be sized to the squad's magazines.
- Measure: the calibration sweep the backlog lists, with ammunition on; the UPS run at 200, 500 and 1,000 units with
  ammunition on and off, relays' draw reported.

**What not to do.**
- No ammunition cost on idle units, on walking, or per minute. Owning stays free beyond power.
- No second currency and no "supply points": the player's magazines, shells, rockets, grenades, flamethrower ammo and
  repair packs are the items, the same ones their turrets and tank take.
- No reduced-damage state yet (the engine has none per unit; the swap exists if the walk home proves unfair).
- Do not make units cars to get a real inventory: it would cost the command grammar.
- Do not regenerate the counters with ammunition on.
- Do not build stage 2 before stage 1's armydefend reading is in: if the loadouts evaporate a defend, the depot only
  moves the problem thirty tiles.

## Corrections to the summary the user was given

- "Relays and barracks use a little power": a relay draws 2 MW (`player.lua` 43), seven times a radar; the director save's
  five relays 10 MW, level 3's fifteen 30 MW. It is the army's one real upkeep and it scales with owning.
- "A battle tank: a tank, 20 shells, two batteries, an exoskeleton, two energy shields": correct (`player.lua` 305 to 307);
  the gun buggy was left out: a car, 20 piercing magazines, a battery, 80 s.
- The hard cap "60" quoted in the 2026-11-16 consult is not in `shared.DIRECTOR` as read today: `points_max` 40,
  `adapt_max` 2, `climax_points` 2, the difficulty multiplier after the cap (`strike_units`). What bounds a force is
  40 times difficulty times adaptation, doubled at a climax.
- "Since 0.2.462 a holding squad clears nests within its reach": correct, and DESIGN marks the big-nest-field case
  "assumed, not measured". A continuous fight on a biter map is a measurement to make, not a fact yet.
- Ammunition upkeep as "a continuous demand": in plates it is two or three per cent of the losses on the one measured
  strike. It is a rhythm and a supply line, not a strain. Losses are the strain, and they are lumpy, which is what the
  director's beats make them.

## Evidence index

- `landing-party/player.lua`: the relay's 2 MW and reach (39 to 46); the order recipes with their ammunition (262 to 308,
  the tank's price comment 303 to 304); the bandwidth technologies and the infinite level's `150*L` (347 to 380).
- `landing-party/shared.lua`: POPULATION (881 to 882), ORDERS (884), RELAY_CAPACITY 10 and RELAYS_BY_LEVEL (896 to 898);
  DIRECTOR adapt_climb and adapt_max (433), points_per_worth and points_max (567), point_scale (571), lull_floor,
  climax_points, beat_minutes (the block ending 608); unit prices (843 to 844).
- `landing-party/units.lua`: base_unit's flags with `not-repairable` (79); gun() with cooldown and category (39 to 49);
  make_infantry (112) with gun(6, 15, 20) (137) and the trooper's 8 a round (156 to 158); the breacher's 180 (204), the
  rocket trooper's 150 (235), the flame trooper's stream at 4 (272); make_tank (372) and the battle tank's 180 (405 to
  411); the gun buggy (537) and its GB table (545).
- `landing-party/scripts/command.lua`: relays() by status (87 to 100), capacity (102), deploy by quality (148 to 190),
  train (201 to 221), order() and REISSUE (414 to 441), lead() (846 to 992), REPAIR_RANGE 30 and REPAIR_SHARE 0.02 with
  repair() (995 to 1010), tick cadence (1447 to 1455), REPORTED signals (554), HERE 12 (559), DEFEND_* (60 to 63),
  MAX_OFFSET 300 (292).
- `landing-party/scripts/director.lua`: strike_units (1166 to 1175), the point pricing by the lead camp's infantry
  (1436 to 1450); no reference to command.capacity (grep).
- `landing-party/control.lua`: on_script_trigger_effect already handled (90); on_entity_damaged with the BUILDINGS filter
  (225 to 262).
- `landing-party/scripts/veterancy.lua`: RANKS (24), the swap that carries references (DESIGN Veterancy).
- `tests/lp-sim/control.lua`: the scenario list (no `rearm`, `depot`, `repairprobe`); barracks setups (1265, 1659 to
  1672); roboports stocked with repair packs (4674 to 4677, 10655, 16285); armydefend (9170 to 9186).
- `scripts/regress.sh`: area_of_scenario, the player area (61 to 72); areas_of_file, command and player.lua as player.
- DESIGN.md: The player's army, the Supply proposal of 2026-10-13 (1195 to 1199: "a forward depot fed by logistics";
  1222: "ammunition or health" as next beacon signals); the measured defend (1066 to 1074); Veterancy (1227 on); the findings
  0.2.448 (retire, the outpost barracks by train), 0.2.449 (research scales the army), 0.2.457 (37 of 50 lost, the point
  pricing), 0.2.462 and 0.2.463 (nests, assumed not measured); the backlog (206 to 252).
- `docs/reviews/2026-11-16-army-consult.md` section 4, "Do not add an upkeep"; `docs/army-brief.md` jobs 4 and 6;
  `docs/calibration-2026-11-16.md` 55 to 57; `docs/arena.md` (prices: trooper 10, rocket trooper 20, gun buggy 40,
  battle tank 80; equal spend about 420 parts).
- API 2.1.24: UnitPrototype (no inventory, equipment grid or guns), CarPrototype (`inventory_size`, `guns`,
  `trash_inventory_size`), VehiclePrototype (`equipment_grid`), EntityWithHealthPrototype (`healing_per_tick`,
  `repair_speed_modifier`), RoboportPrototype (`material_slots_count`, `construction_radius`), RepairToolPrototype
  (`speed`), ToolPrototype (`durability`), LogisticContainerPrototype (`logistic_mode`, the LogisticMode union),
  StickerPrototype (movement and damage taken only), EntityPrototypeFlags `not-repairable` (its description),
  ScriptTriggerEffectItem (`effect_id`), LuaEntity.is_registered_for_repair, LuaEntity.commandable ("Units and
  SpiderUnits are commandable"), LuaCommandable.distraction_command and has_command, on_script_trigger_effect
  (`source_entity`), on_entity_damaged (`cause`).
- Vanilla data: character flags with `not-repairable` (entities.lua 707), biters' flags (enemies.lua 76); gun turret
  cooldown 6, range 18, automated_ammo_count 10 (turrets.lua 476, 552, 566); magazine_size 10 and the flamethrower
  ammo's 100 (item.lua); repair pack speed 2, durability 300 (item.lua 562 to 563); recipes: heavy armor 100 copper and
  50 steel, firearm magazine 4 iron, submachine gun, cannon shell, rocket, repair pack 2 circuits and 2 gears
  (recipe.lua).
