# Defence weighting, heists, siege tiers: design consult (Fable), 2026-10-14

The user's ideas, after hearing how raids and sieges work: turrets should weigh by type and tech, units should count;
heists on valuable contents ("a chest full of circuits, nuclear fuel cells, a Kovarex line, a cargo bay"); sieges
that come for destruction, several mortars late.

## 1. Defence estimate: weight, yes; units at the staging look only
Today `defence()` = turrets seen + resist + markers/3, all turrets 1, and `needed(d) = 5d + 4`. Replace the count in
`sense()` with a weighted sum: gun 1, laser 1.5, flamethrower 2.5 (flamers killed most of every campaign squad),
artillery 0 (6-tile minimum, blind up close). Tech: once a minute per enemy force cache
`get_ammo_damage_modifier("bullet")`, `get_turret_attack_modifier("laser-turret")`,
`get_ammo_damage_modifier("flamethrower")` and scale each type's weight by (1 + modifier); `needed(d) = ceil(5d) + 4`.
Units: never in the 2-minute scan (they move), only in the staging look: `t.units` = characters 0.5, cars/tanks 1.5,
spidertrons 3, player-force `unit` 0.5, within 40 tiles, decaying over 5 minutes; the turn-back test uses
`defence + units`. Conflict: Grubstake's `soft_only` tests `defence > 0`; keep that on turret weight alone or a player
standing at a relay makes it "guarded". Check (`weigh`): three gun turrets vs three flamers: raid of 19 vs 42; bullet
damage 3 researched (+0.7): 19 becomes 30; a parked spidertron at an undefended relay: the raid turns back at staging
unhurt. Cost: one `find_entities_filtered` by type per staging look, three force reads a minute.

## 2. Heists: Grubstake only; items, never machines
Value: during `sense()`, per cell holding `container`/`logistic-container`/`cargo-landing-pad`, read at most 2
containers per cell and 8 per settlement per scan (a round-robin cursor over cells), one `get_contents()` each, scored
by a 15-entry loot table: uranium-235 20, uranium-fuel-cell 10, modules 10/20/40, processing-unit 8,
low-density-structure 4, rocket-fuel 3, advanced-circuit 3, steel 0.3; else 0. Cell value = min(score, 2000)/100 (so up
to 20, above a relay). A cargo landing pad scores 15 flat plus contents. Centrifuges count: their output inventory is
read like a chest. Whole machines are a raze with a new name; do not take them.
Mechanics: a new `op.kind = "heist"`, hauler plus 4 buggies, staged via `outside()`, then "Loading" 10 s per container
(label), `inventory.remove` of the highest-scoring items first up to 400 items, hauler home by the staging line. Loot
is `op.cargo` as `{name = count}`. Player: alert `lp.alert-heist` at the container; a killed hauler leaves an
`lp-crate` (container) with its cargo, so a chase recovers the goods. Gain: at the depot, loot score becomes parts at
1:1; 50+ processing units or 10+ U-235 add 500 to the corporation's export counter ("has recovered restricted
components"), the tech boost. Temper: heist allows weighted defence ≤ 2 (a buggy run pays for itself), breaking
`soft_only` deliberately; say so in the notice. Budget: counts as a player operation; cell cools 20 minutes and is
not heisted again until its contents re-score. Serenity never steals; nothing in its place.
Check (`heist`): a chest of 200 processing units behind one laser: a heist launches, 200 removed, hauler home, parts
+1600, exports +500; same with a tank scripted to kill the hauler: a crate holds 200 and the depot gains 0.
Cost: 8 `get_contents()` per 2 minutes per settlement.

## 3. Siege tiers (by `min(corp level, player era + 1)`, grudge = tier up)
- T1 (now): 1 mortar, 30 shells, 6 guards, 100 parts.
- T2: 2 mortars, 40 shells each, 10 guards, 220 parts; a **resupply convoy** (one hauler, 40 shells) sets out when the
  first mortar is spent and in_reach > 0; a dead convoy ends resupply.
- T3: 3 mortars, 16 guards with tanks, 400 parts; when in_reach == 0 for 30 s, an **assault phase**: the guards plus a
  force sized to the target's remaining weighted defence attack from the site (same `b.op`, a phase, so it stays one
  operation); or the mortars **move up** once, 20 tiles, if shells remain.
- T4: 4 mortars, two convoys, 24 guards, 600 parts.
Answerable because: shells per siege capped at 160; mortar health 1200, no resistances (a tank sally kills it in
seconds); 30 s deploy stays as the sally window; pack-up on halved guards stays; at most one siege per player force at
once across corporations; the parts cost drains the economy that would otherwise build units.
Checks: `siege2` (level override 2): two mortars, ≥ 60 shells, walls within 36 of the site fewer after; `siege3`:
assault launches after in_reach == 0 and razes ≥ 1 structure; `sally`: a scripted tank at 20 tiles kills a mortar
within 20 s and the siege aborts; `convoy`: killed convoy, no second volley.

## Conflicts
The assault must be a phase, not a second op (one op per settlement, budget 1 + era). Tier gating by player era
prevents a level-3 corporation siege on an era-0 player. Heist overrides `soft_only` at ≤ 2 only.

## Build order
(1) weighted defence with units at staging (everything sizes from it; re-run `defend`, `abort`, `ops`, `contact`);
(2) siege tiers (a parameter table plus two phases on `siege_step`); (3) heists (new op, loot scan, crate, gain).
