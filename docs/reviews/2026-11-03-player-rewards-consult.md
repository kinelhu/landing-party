# What the player earns from the war: passive unlocks (Fable, read-only, 2026-11-03)

Read: `CLAUDE.md`; `DESIGN.md` (status table, the player's army, Corporations, the loot and components sections, the
headquarters prize, open questions, findings 0.2.169 to 0.2.172); `docs/corporations.md`, `docs/corporations-brief.md`,
`docs/army-brief.md`, `docs/units.md`; `landing-party/player.lua`, `components.lua`, `shared.lua` (KINDS, VALUE),
`biotech.lua` (the pen), `data.lua` (the mortar), `scripts/faction.lua` (the prize), `command.lua` (cores), `pact.lua`
(the crystal), `rd.lua`, `dome.lua`, `orbital.lua`; the faction loot and identity trees consults; the version-matched
`prototype-api.json` and `runtime-api.json` for technology triggers, achievements and `LuaTechnology`. Nothing run,
nothing edited but this file.

The question (the user, 2026-11-03): what carrots does fighting the corporations earn? "The orbital strike being
researchable tech at the edge of the KH related tree seems like one"; "I'm not convinced by item drops"; "perhaps
passive unlocks through killing enemy units or buildings?"; and, mid-consult: "you should still need to invest research
flasks. Not faction specific items."

## 1. Verdict

Both halves of the user's instinct hold. Items were the wrong currency: six component items, six teardown recipes and
six schematics exist today to turn a kill into a research trigger (`components.lua`), a currency layer the player never
asked for. Research paid in ordinary packs is the right one, and the engine already has the exact idiom: Space Age gates
branches behind trigger technologies that cost nothing ("Capture a biter spawner", "Craft 1 ...") and puts pack-paid
technologies behind them. The 2.1 prototype API has a `scripted` trigger type for mods (`ScriptedTechnologyTrigger`,
fired by `LuaForce.script_trigger_research`), with its own icon and description in the tree. So each node is a pair: a
field-study technology whose trigger is "destroy N of X" counted by the mod, and the real technology behind it, paid in
packs, with vanilla prerequisites that keep it in its era. The mod's own prize technologies (`lp-prize-<corp>`, hidden,
set researched when an uplink falls, `faction.lua:876`) are half of this already.

The proposal on the table is right in shape (one short tree a corporation, each node derived from what it fields,
ending in its signature) and wrong in four places: a player dome would make Kessler-Hayashi's siege pointless, smoke
that blinds turrets has no honest engine mechanism and would hit every defence in the game, mercenaries would buy with
iron the army that command bandwidth exists to ration, and a tamed brood is a second army outside bandwidth. The
details are in section 3.

## 2. The mechanism (question 1)

Four options, weighed:

- **Research made cheaper by kills.** `LuaTechnology.research_unit_count` is read-only; the price multiplier is per
  difficulty, not per technology or force. It would take level-swapping tricks. Cut.
- **A study bar per corporation, a lab-like building, faction science packs.** Packs are faction items under another
  name (the user's rule). A study building needs a GUI the mod has avoided, and a progress bar on a corporation is not a
  thing Factorio shows anywhere. Cut.
- **A technology `enabled = false` that the script enables** (`LuaTechnology.enabled` is writable at runtime,
  `visible_when_disabled` shows it greyed). Works, but a greyed node explains nothing: the player sees a locked
  technology and has to guess what unlocks it. Weak.
- **A scripted-trigger technology as the prerequisite of a pack technology.** Native (the Space Age idiom), the
  condition printed in the tree (`trigger_description`), the game's own research-complete sound and queue when the
  trigger fires, and the pack technology then researches like any other. Recommended.

How it works, concretely:

- **Counting.** `on_entity_died` with `event.force` (the force that dealt the killing blow). Count only when that force
  is a player force (not biters, not a corporation; `shared.is_corp`, `shared.is_biters`), by kind
  (`shared.kind_of`), per corporation: `storage.study[force.index][corp][kind]`. Turrets', artillery's and the army's
  kills all count, as Factorio's own kill statistics do. Where a reward is meant to pull the player out from behind the
  wall, the node's *kind* does the pulling: mortars, labs, projectors, tumors, pacifiers and uplinks never come to the
  player's wall. The trigger fires with `force.script_trigger_research(name)` when the count is met.
- **A threshold, not a currency.** Once a trigger fires, more kills of that kind buy nothing; a farm cannot overshoot.
  The pack cost is the price, and it is paid in the ordinary economy. The exploit left is provoking a corporation into
  sending what the node asks for, which is the game working as designed. Rebuilt pacifiers (every 5 minutes) and
  re-sent mortars are therefore harmless: the first one is the one that counts.
- **Legibility.** `trigger_description` carries the condition ("Destroy 3 Kessler-Hayashi mortars or howitzers"). It
  is a prototype string, so live progress cannot show in the tree; a notice at the half-way point and at completion,
  under the notice setting as every alert, carries it ("Field study: Kessler-Hayashi siege guns, 2 of 3"). *Assumed,
  not seen:* that a scripted-trigger technology displays before it is researched as Space Age's capture-spawner
  technology does. Verify in a window once.
- **Pacing.** Kessler-Hayashi's triggers cannot fire before it lands (the first rocket launch), and its pack
  technologies carry `rocket-silo` or `space-platform-thruster` as prerequisites, so a dev landing or a `/lp` visit
  cannot bring its tree early. Synthexis is present from evolution 0.25, so its first node costs red, green and
  military and its later ones chemical and utility; its edge takes a Space Age gate. Grubstake's run red, green,
  military and blue, in its own window.
- **Multiplayer and determinism.** Per force: two player forces study separately and a kill belongs to the force that
  dealt the blow. Counters live in `storage`, nothing is random. One standing violation to clear while here: the
  crystal's drop rolls `math.random()` (`pact.lua:75`), against the mod's own rule; it goes with the crystal
  (section 5).
- **Where a native trigger fits, use it instead of a scripted one.** `mine-entity` on a captured Grubstake drill (hold
  an outpost until it is yours, then mine one of its drills: the strip drill's node, below) and `capture-spawner` on
  `lp-pen` (Synthexis's edge, below; today `captured_spawner_entity = nil` at `biotech.lua:399`, so a capture robot does
  nothing to a pen).
- **Migration.** The six component technologies change their `research_trigger` from `craft-item` to `scripted` or
  move behind a study node; the six components, six schematics and their recipes go with a migration (any left in a
  save become nothing: they were never craftable). The two prize technologies become the HQ fall's own trigger for the
  edge nodes that want it.

## 3. The trees (question 2)

Pack counts are priors to tune on the phase visits (the reference factories at their eras); the kinds and counts are the
design. "Study" is the scripted trigger; "Pack" the technology behind it.

### Kessler-Hayashi (late; the siege that outranges a wall, the dome that holds against shells, the strike)

Judgement of the proposal: **its mortar, keep** (moved from the HQ fall to a node a siege can earn). **An interceptor
tower, change**: a tower that catches shells is a player dome, and a dome answers Kessler-Hayashi's siege with a
building, so the army is not needed, which is the one thing the army brief says a late reward must not do; what the
player needs against a gun firing from beyond the wall is to know where it is. **An orbital uplink overlay of the guns
covering any spot, cut**: that is the planner's fire map, a debugging instrument; a map overlay of coverage is not a
reward anyone in Factorio has asked for, and the "charted camps" half folds into the tracking node. **The orbital
cannon on a platform at the edge, keep** (the user's own; it is the right edge).

| Node | Study (the trigger) | Pack | Gives |
|---|---|---|---|
| K1 Counter-battery tracking | 1 Kessler-Hayashi building of any kind and 10 of its units destroyed | military, chemical, utility; 150; prereq `radar`, `military-3` | A mortar or howitzer shell landing inside a player's radar coverage charts and pings its gun for a minute (a chart tag and an alert), and the threat scanner gains a signal, shelled-from. Not a kill: the remote or the army does that. A siege's mortar is made no military target on deployment so that auto-artillery does not pick it (`data.lua:147`); tracking is what makes the remote aimable. |
| K2 Mortar | 3 of its mortars or howitzers destroyed (they come only with sieges and clearances: out from the wall) | military, chemical, utility; 200; prereq `military-3` | `lp-player-mortar` and its shell, the existing prize (range 36, minimum 6, against vanilla artillery's 224). It outranges every turret and small and medium worms, not big or behemoth ones. A short, cheap artillery before Artillery; it does not trivialise anything a full artillery turret does not already do, and it arrives late. |
| K3 Rail rifle; Cluster shells | 10 railgunners (the rifle); 2 howitzers (the shells) | utility 200; military, chemical, utility 200, prereq `artillery` | Both exist (`components.lua`); only their trigger changes. Space Age already has the railgun; the rifle's slug (150 physical along 30 tiles, every 1.5 s) stays an engineer's weapon, not a turret. |
| K4 Orbital cannon (the edge) | its uplink destroyed (the HQ fall, today's prize), or 3 strikes called off by killing the spotter during the paint (the army's eyes; `orbital.lua`) | space science and utility; 500; prereq `space-platform-thruster`, `artillery` | A platform-only building loading ordinary artillery shells; fires only while its platform is stopped over this planet (`LuaSpacePlatform.space_location`); aimed by a remote (a selection tool, as the command tool is) at a point; telegraphed with Kessler-Hayashi's own paint and lances; the barrage is `war.lua`'s; one firing, then 20 to 30 minutes to recharge (an array fires more shells, not more often); striking a corporation provokes it; a dome catches it (the projector must fall first: the army again). Replaces the burn-out beacon of `strike.lua`. |

Four nodes. A player dome, if the standing-siege design later wants a "buy three minutes" tool, should copy
Kessler-Hayashi's rule exactly (HOLD seconds of the guns' fire, then down for BREAK) and never hold for good; I would
not build it until a visit shows the standing siege is unanswerable without one.

### Grubstake (early to late; the thief that raids where no gun covers)

Judgement: **the strip drill, keep** (a native `mine-entity` trigger fits it exactly). **Smoke canisters that blind
turrets and worms, cut**: no prototype blinds a turret; a script would have to switch them off or clear their target,
which reads as a cheat and hits every corporation's and nest's defence alike, and Grubstake's own fights are not about
blinding guns but avoiding them. **Trading under truce as an economy, not here**: it is a cost of peace, not a carrot
of war; it stays in the truce design, with one bridge (G3). **Mercenaries, cut**: an army bought with iron is what
command bandwidth exists to forbid (DESIGN, "Item costs cannot limit an army in Factorio"); if wanted later, a hired
unit takes bandwidth and a barracks' core like any other, and then it is just a skin.

| Node | Study | Pack | Gives |
|---|---|---|---|
| G1 Claims register | 10 of its raiders (shotgun hands, buggies, harriers) or 1 hauler destroyed | red, green, military; 100; prereq `military-2` | Grubstake's prospecting becomes the player's chart: every patch it has staked (`prospect.lua`'s claim stakes) is charted with its ore kind, and its strip camps are tagged where they stand. It knows where the ore is (DESIGN: it reads the player's drills for that); now the player reads its register. |
| G2 Strip drill | native `mine-entity`: mine a drill of a captured Grubstake outpost (capture by holding, then mine) | red, green, blue; 150; prereq `steel-processing`, `chemical-science-pack` | The existing `lp-strip-drill`: an electric drill at twice the speed and half the drain, between the electric and the big mining drill (2.5x, 50% drain) in power. No productivity bonus. |
| G3 Pheromone bait | 1 pacifier antenna destroyed (the pact broken once) | red, green, military; 100; prereq `military-2` | The existing bait, recipe without the gland (5 iron, 1 poison capsule, say). The pact breaker folds in: a bait set inside a Grubstake claim also suspends its pact 3 minutes. The claim marker stops being a craftable device: a trade post that has paid a truce in the last hour *is* the marker for 60 tiles round it (the paid claim is in Grubstake's register; a free marker made its soft raids pointless anywhere the player put one). |
| G4 Flak gun | 1 scrap cannon or 5 fliers of its (harriers, scavengers) destroyed | red, green, military; 150; prereq `gun-turret`, `military-2` | Grubstake's dirty flak in the player's hands: a gun-turret variant firing airburst at fliers (harriers, laser drones, scavengers), weak against ground. The player's anti-air today is the anti-air trooper alone; the rocket turret is a planet away. |

Grubstake's HQ fall gives no further recipe: its withdrawal is the reward (the raids stop), and an achievement marks
it (section 6). Four nodes; G4 is the one to drop if the tree feels long.

### Synthexis (all game; the waves that learn the guns, the creep, the scout)

Judgement: **acid plating, cut**: its breeds bite with `lp-bite`, not acid; unit and wall resistances cannot be
researched (no such modifier exists), so this would be a wall variant, and walls are not what its mediums break (its
rams are), so the plate would blunt the breed that matters least. **Biomass from creep for spore grenades, change**: no
new item; if a biological recipe is wanted it takes Gleba's items and sits at the edge. **A tamed brood, change**: a
captured farm breeding for the player is a second army outside bandwidth, the thing the barracks design forbids; the
native half of the idea (Space Age's capture robot on an incubator) is the edge, and what it yields is the game's own.

| Node | Study | Pack | Gives |
|---|---|---|---|
| S1 Bred-biter telemetry | 1 incubator destroyed or 3 tumors, or its scout killed 3 times (it loops outside the turrets: only troopers outside the wall catch it) | red, green, military; 100; prereq `military-2` | The threat scanner tells Synthexis's biters from the wild (`lp-scan-synthexis`) and reports its scout (`lp-scan-scout`: the warning before a wave, DESIGN 0.2.19), so a circuit can muster a squad on the scout alone. Today `lp-scan-biters` covers wild and bred together (`scanner.lua:54`). |
| S2 Defoliant charge | 5 tumors destroyed | red, green, military, chemical; 150; prereq `military-3`, `explosives` | A thrown charge (a cliff-explosives-like capsule) that reverts creep within 6 tiles to the ground recorded under it and does 200 to tumors. Creep blocks every building (`biotech.md`); this is how the player reclaims ground at capsule range instead of walking a squad through it. Creep recedes on its own when tumors die, so the charge hastens, it does not replace, killing the culture. |
| S3 Decoy turret | its scout killed 3 times (if not spent on S1: then 3 waves turned back at a wall, read from `herd`'s records) | red, green, military, chemical; 200 | An unarmed turret-shaped building (a gun turret's body, no gun, 150 kW) that Synthexis's scout and plan count as a gun, bending where its wave breaks in. Its learning undoes it: a decoy kills nothing, so after one wave its price there falls to nothing (`know.learn_price`), and the decoy works once a place. The player feeds its intelligence a lie; the intelligence catches on. See the interaction warning in section 4. |
| S4 Incubator capture (the edge) | native `capture-spawner` on `lp-pen` | agricultural, military, chemical; 300; prereq `captivity` (Space Age: agricultural pack, `military-3`, `rocketry`) | Set `captured_spawner_entity = "captive-biter-spawner"` on the pen. A captured incubator is Space Age's own captive spawner: biter eggs on Nauvis from the culture that fought you, without the trip to a wild nest field. Modest and native; the ambition of a brood that fights for the player is parked (section 6). |

## 4. How the rewards interact (question 3)

Does beating one corporation equip the player against the next? Partly, and the right amount:

- Kessler-Hayashi's mortar (36) reaches Synthexis's incubators behind small and medium worms, and razes a Grubstake
  town from outside its gun turrets (18). Both are things full artillery already does, and the mortar is gated behind
  Kessler-Hayashi's sieges, so it arrives when Grubstake is already outclassed and Synthexis's cultures are guarded by
  big worms (38) and behemoths (48). No trivialisation.
- The rail rifle's slug (150 physical along a 30-tile line) is a burster answer in the engineer's hands; the orbital
  cannon razes cultures and camps within 60 of its point once every 20 to 30 minutes and provokes; "every pen dead, it
  lands elsewhere an hour later" bounds what one strike costs Synthexis.
- Bait against Kessler-Hayashi works (it clears nests, wild biters hurt it); against Synthexis it does nothing, honestly
  (Synthexis is at cease-fire with the wild biters, `biotech.md`), and the notice should say so once.
- Tracking (K1), telemetry (S1) and the register (G1) are all eyes, and eyes compound: the threat scanner becomes the
  circuit instrument the user asked for in 2026-10-18 with a signal for each corporation's tell.

Does any reward make a corporation's pressure pointless?

- **A player dome against Kessler-Hayashi's mortars: yes.** Cut above. Its siege exists to force the army out; a
  building that answers it removes the reason.
- **The claim marker against Grubstake: yes, locally and for steel.** Bound to a paid trade post above, so the
  pointlessness is bought, which is the truce design.
- **The decoy against Grubstake: yes, and this is the warning.** Grubstake raids only where known defence is 0
  (`ops.temper_allows`) and its intel counts turrets by type (`intel.lua`, `ops.weigh`); a decoy of turret type would read
  as a gun and repel every soft raid for free, forever, since Grubstake learns a turret's price from its losses and
  never attacks the decoy'd outpost to learn it costs nothing. Two honest fixes: the decoy is a `simple-entity-with-owner`
  that only Synthexis's scout counts (sight: a special case, but a true one, since the scout reads what it sees and
  Grubstake reads intel), or Grubstake's intel prices a turret it has never lost a unit to at nothing until it has.
  The second is the better corporation. Decide before building S3.
- **The orbital cannon against everything within 60:** bounded by its recharge, its platform in orbit, the paint that
  telegraphs it, the provocation, and the dome that catches it. Keep all five.

## 5. The command core and the pacifier crystal (question 4)

**The crystal: cut.** Its two uses (breaker, marker) fold into G3; its drop is the mod's one `math.random()` in a
mechanic; and it is exactly the kind of item the user does not want.

**The command core: keep, as the one item.** It is a key, not loot: it gates the army's size by the war ("a destroyed
depot drops one, a captured outpost one, a destroyed lander three; the first research grants one"), it arrives in a
wreck mined once (`shared.wreck`, since 0.2.170), never spilled, and the user's complaint was materials on the ground.
One rare item that opens a barracks reads as a trophy. The alternative, if the user wants no items at all: a
"Command authority" technology with levels, each level's trigger a depot destroyed, an outpost captured or a lander
destroyed, each paid in packs, and the barracks recipe without the core; the barracks count would then have to be
capped by script (refusing the next placement), which is not native and is the reason to keep the core.

## 6. Risks and open questions

1. **The trigger technology's display** before it fires (assumed from Space Age's capture-spawner technology; not
   seen). One look in a window, then the design stands or falls on it.
2. **Kills by turret and artillery count.** A player can earn K2 by shelling three siege mortars with the remote
   from inside the wall. Acceptable: the remote is an act, and the nodes that want troops (the spotter, the scout,
   the captured drill) ask for them by kind.
3. **Grubstake and the decoy** (section 4): pick the fix before S3 exists, and check in the lab (a lane with decoys,
   two waves: the second should ignore them).
4. **Capture of a pen.** Verify in a spike what Space Age's capture robot requires of its target (health, force) and
   that a `captive-biter-spawner` on a script force's pen changes force correctly; and whether Synthexis treats a captured
   incubator as "a pen killed" (its culture's biomass share, `farm.lua`).
5. **The orbital cannon's prototype.** Which type a platform building can be (a container with a script, an
   electric-energy-interface as the beacon is today), the remote (a selection tool, cross-surface, reading the platform's
   `space_location` against the surface's planet), and whether the dome catches the player's shells (it destroys artillery
   projectiles by area, `dome.lua`; the orbital shell is `war.lua`'s own projectile: check its type).
6. **Migration of the six component technologies** and saves that hold components or schematics.
7. **Pack counts** are priors; tune on the three phase visits, so a tree's first node lands within its corporation's
   first hour of pressure and its edge after the HQ or the platform.
8. **Achievements**, since the user asked: mod achievements show in the game's own achievements screen (listed as
   modded, not Steam's). `KillAchievementPrototype` takes a `to_kill` list and a `damage_dealer` (a corporation's own
   mortar in the player's hands against its uplink, say); `ResearchAchievementPrototype` for each edge; a fall granted by
   script only for plain `achievement` type (`LuaPlayer.unlock_achievement`). Zero balance cost, native, six to eight of
   them: one a corporation's fall, one an edge researched, one for a strike called off at the spotter, one for a wave
   turned back by a decoy. Build them last.
9. **What is still missing from every tree**: a reward that is purely a look. The corporations' floors, lamps and
   liveries are theirs; a player who beats one might be allowed its concrete (a tile recipe: Kessler-Hayashi's plating,
   Grubstake's gravel, Synthexis's creep as a decorative tile that absorbs no pollution). Cheap, native, no balance,
   and the kind of carrot Factorio players actually put down. Worth a node each at the HQ fall, where the prize used to
   be.
