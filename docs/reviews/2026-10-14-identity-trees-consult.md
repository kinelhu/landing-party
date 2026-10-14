# Corporate tech trees: identity first (Fable), 2026-10-14

The user, on the generic research: "Do we have interesting research? With actual faction identity? Do the troopers
differentiate between factions? I was thinking range, rate of fire, even main weapon (Grubstake could use shotguns,
Serenity could have some special 'laser troopers'... and climb their tech tree up to tesla shock troops..)" and "I'm
surprised your previous consults did not find this obvious direction." (The earlier briefs asked narrow mechanical
questions; this one was framed identity first.)

Premise: the player should know who is attacking with their eyes shut. Serenity sounds like a laser turret and holds a
line; Grubstake sounds like a shotgun and runs. The generic system (fund, ledger, era cap, sizing) stays as the engine;
what it buys becomes named units in each voice. Numbers are first calibrations: DPS parity with today's infantry
(6 dmg / 20 ticks = 0.30 a tick) is the anchor.

## 1. Trees

**Serenity Perimeter Group: "the line".** Energy weapons, range, discipline. Lasers carry no physical falloff against
the player's tanks (vanilla tank: no laser or electric resistance), and stone walls resist lasers heavily (verify 70% in
the dump), so Serenity answers walls with mortars and walkers, never by shooting them.
Starting infantry **Line trooper**: beam attack (`laser-beam`), 7 laser, range 15, cooldown 25, 120 hp, laser 20%
resist, 10 parts, category `laser`.

| Node (branch) | Prereq / era | Unit or ability | Cost |
|---|---|---|---|
| Lance (Optics) | era 1 | infantry, beam 12 laser, range 17, cooldown 45, 110 hp. Outranges troopers (15); still inside gun turrets' 18. Answer: massed troopers, buggies | 900 |
| Warden (Line) | era 1 | heavy infantry, 240 hp, physical 40%/4, laser 30%, speed 0.10, short beam 6/range 10/cd 20, 20 parts. Front rank: answer to gun-turret clusters | 1,500 |
| Aegis tank (Line) | Warden, era 2 | tank hull, beam cannon 45 laser, range 15, cd 60, 1,100 hp, physical 30%/5, explosion 40%. Answer: battle tanks | 2,000 |
| Hardened siege (Siege) | siege cap, era 2 | ability: the mortar site gets a wall ring and two laser pillboxes; resupply convoy +1 escort. Answer: sallies and artillery | 1,200 |
| Shock troops (Optics) | Lance, era 3 | tesla: own `chain-active-trigger` (4 jumps, 6 tiles) on `electric-beam`, 12 electric, `electric-mini-stun` sticker, range 12, cd 45, 160 hp, 30 parts, category `electric`. Answer: blobs of troopers | 2,500 |
| Counter-battery (Siege) | Hardened siege, era 3 | ability: a siege's first targets are artillery turrets and wagons in reach; a Shock squad strikes them | 1,000 |

**Grubstake Mineral Recovery: "resources in the right hands".** Close range, cheap, fast, improvised; never a fair
fight. Starting infantry **Shotgun hand**: `shotgun-shell` category, 8 pellets x 4 physical (`shotgun-pellet`, deviation
0.3), range 9, cooldown 30, 120 hp, speed 0.13, 8 parts. Devastating at the fence, useless against a turret line, which
it never attacks anyway.

| Node (branch) | Prereq / era | Unit or ability | Cost |
|---|---|---|---|
| Slug buggy (Scrap arms) | era 1 | buggy, 3 slugs x 14 physical, range 12, cd 40, 240 hp. Answer: tanks, vehicles | 900 |
| Salvage rights (Loot) | era 1 | ability: each player building a raid destroys pays its cost x 0.3 to the fund; a dead player vehicle pays 50. The thief funds itself from the victim | 800 |
| Burner (Scrap arms) | Slug, era 2 | buggy, stream (`flamethrower-fire-stream`), 8 fire a tick plus ground fire, range 10, 220 hp, fire 100%. Answer: massed troopers | 1,500 |
| Scavenger harrier (Wheels) | harrier cap, era 2 | harrier, rockets 18 explosion, range 14, cd 40, 180 hp, 50 parts. Flies over walls to artillery, mortars, radars | 1,800 |
| Prospector's eye (Loot) | pickets_see, era 2 | ability: strips range 1.5x further out; raids pick the softest of three targets and abort at 70% strength (cowardice as doctrine) | 1,000 |
| Dozer (Wheels) | Slug, era 3 | hauler hull, 1,800 hp, physical 40%/5, melee 60 physical at range 2, cd 60, speed 0.07. Its one heavy: pushes a fence or wall open for the shotguns | 2,500 |

Same threat, different answer: turret cluster (Wardens + mortars / not there, strips elsewhere); trooper blob (Shock
troops / Burners); walls (walkers and siege / Dozer, harriers over them); artillery (Counter-battery / Scavengers);
tanks (Aegis lasers / Slugs).

Lumen and Concord fit the same shape: a tree is a table of nodes with triggers, so Lumen's branches would be Sight
(jammers), Air (rocket harriers against tanks, strafers against troopers), Evacuation; Concord's Armour tiers, tank
variants, and a "catalogue" node another corporation buys from it at standing.

## 2. Choice rule
Every 10 minutes, per corporation: candidates are nodes affordable, prerequisites met, era within cap, whose trigger
fires on the ledger. Triggers read losses by damage type and killer kind (`rd.tally` has both), raids turned back and
the dominant turret type at the targets it wanted (`ops.weigh` returns it), and a new `walls_met` count (raids that
spent 20 s on walls). Scores: Warden fires on physical losses of 10 or more; Lance and Shock on killer kind
trooper/character (Shock needs 3 or more per death event: blobs); Aegis and Slug on killer kind battle-tank/car;
Hardened siege and Scavenger on explosion losses; Counter-battery on an artillery killer; Dozer on `walls_met` 2 or
more; Salvage and Prospector on raids turned back. Highest score wins, tree order breaks ties; no trigger and fund
above 60% of cap buys the cheapest node of the branch with most losses, so a tree still climbs. Damage levels are the
fallback when nothing fires. A gun-turret-and-wall player meets Wardens then mortars behind walls; a trooper-blob
player meets Lance at era 1 and Shock troops at 3.

## 3. From the generic system
Keep: fund (cap 15,000), ledger and window, era cap (per node), `S` in sizing with a per-kind strength factor, one
purchase per cycle, withdrawal buys nothing. Damage levels become per-corporation named tracks (Serenity "Optics" on
laser and electric; Grubstake "Hand-loads" on shotgun-shell and bullet) and only the fallback purchase. The three
plates fold into nodes: Warden is the physical+laser plate with a name; Grubstake's "scrap plating" (physical) and
"asbestos" (fire) remain cheap era-1 nodes on buggies and infantry using `plates.lua` as built. No explosion plate.

## 4. Engine notes (spike first, base game)
- Units take `type = "beam"` (the laser turret's beam in base `turrets.lua` is the model) and `type = "stream"`
  (spitters): both in the 2.0 `AttackParameters` union.
- Chain: `ChainTriggerDelivery` and `chain-active-trigger` are engine types; base ships none (base `beams.lua`
  chain-lightning is commented out), Space Age defines `chain-tesla-*`. Define `lp-arc-chain` on `electric-beam`
  (10 electric). Spike: does it jump between player units only; must the chain come first in `target_effects`.
- Shotgun: `repeat_count = 8`, projectile delivery, `shotgun-pellet`. Spike: pellets stop on walls;
  `set_ammo_damage_modifier("shotgun-shell")` applies through the unit's `ammo_category`.
- Burner: spike that ground `fire-flame` burns Grubstake's own infantry (fire ignores force); if so, `fire_penalty` on
  the shotguns or no ground fire.
- Every unit node is `lp-<corp>-<unit>-<tier>`, `shared.kind_of` strips tier as it strips plates. Abilities are runtime
  (`storage.corps[c].tech.nodes`). About 12 new prototypes.
- `rd.CATEGORY` per corporation, not per kind.

## 5. Where they still feel the same, and the cheap fixes
Raid mechanics are one code path: same `needed()`, same blob, same abort at half, same response of six per threat,
same convoy hauler, same death explosion. Two cheap fixes: (a) temper constants in `ops`: Serenity responds in
proportion and aborts at 50%, Grubstake does not respond at depots it can rebuild and aborts at 70%; (b) what a raid
does on arrival: Serenity destroys military targets then withdraws in order ("resolved"), Grubstake empties chests and
bins first and leaves with the loot (feeds Salvage rights).

## 6. Build order
1. Starting infantry: Line trooper (beam) and Shotgun hand (projectile x8); `rd.CATEGORY` per corporation; a headless
   check that each kills a test target within 20% of the other's time; `rivals` and `defend` still pass.
2. Tree engine: nodes table in `shared.CORPS[c].tree`, triggers, notices in voice, era per node; first nodes are the
   existing plates and damage tracks renamed.
3. Lance and Slug buggy with scenario checks on their triggers.
4. Spikes: chain, stream friendly fire. Then Shock troops and Burners.
5. Abilities: Hardened siege, Salvage rights, Prospector's eye, temper constants.
6. Aegis, Dozer, Scavengers, Counter-battery; campaign rerun and the force-per-unit recalibration.
