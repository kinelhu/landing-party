# Corporate R&D: design consult (Fable), 2026-10-14

The user: "Corporations should probably also be able to invest in their own tech trees to better answer the threats
they face. A sort of 'smart' parallel to biter evolution. This makes it so we don't need 100x sized raids if their
units are upgraded also."

Correction first: `ops.weigh` scales by damage research only; speed was dropped on purpose (x2.88 made a mature
garrison raid nothing). Keep it that way and let corporate tech, not the weight, absorb the rest.

## 1. Tracks, costs, choice
State per corporation in `storage.corps[corp].tech`: `fund`, `weapons = {bullet, ["cannon-shell"], rocket}` (levels
0-5), `plate = {["lp-infantry"] = "physical" | "fire" | "laser" | nil, ...}`, `lost_by = {physical, fire, laser,
explosion}` (a 30-minute window).
- **Funding:** an R&D account fed by exports, `fund += 0.3 x parts` in `faction.develop`, without touching the level
  counter. Convoy interception then slows level and tech both, the counterplay the player already has.
- **Weapons (runtime, cheap):** per category its mix uses (Grubstake bullet; Serenity bullet, cannon-shell, rocket).
  Level k costs `400 x k` parts and sets `force.set_ammo_damage_modifier(cat, 0.2 x k)`; no speed track (speed makes
  units kill walls faster, which the player cannot read).
- **Plate (prototype, one per unit kind at a time):** one of three answers, `physical` (+25% physical, decrease +2),
  `fire` (+70% fire), `laser` (+40% laser), each also +15% health. First plate 1,500; switching 1,000. No explosion
  plate: artillery and battle tanks stay the player's trump.
- **Breaching, sensors:** not now. Level capabilities already cover growth; two tracks is what a player can follow.
- **Choice**, every 10 minutes per corporation, from what it already logs (`ops.on_unit_killed` has the cause:
  `ammo-turret/character/lp-trooper/car -> physical`, `electric-turret -> laser`, `fluid-turret -> fire`,
  `artillery-turret/lp-battle-tank/breacher -> explosion`; biters ignored):
  1. If two or more raids turned back for lack of force in the window: the next weapons level of its most-used category.
  2. Else if 10+ units died and one damage type is at least half of them: that plate for the kind that died most.
  3. Else weapons. Only what the fund affords; one purchase per cycle.

## 2. Sizing
`needed(d) = ceil(3.5 x d / S) + 4`, with `S = (1 + dmg_main) x A`, where `dmg_main` is the corporation's damage
modifier for its mix's dominant category and `A` = 1.4 when a plate matches the heaviest turret category at the target
(`ops.weigh` also returns the dominant category), 1.15 for any plate, else 1. Defend: d = 8.6, S = 1 needs 35; at
bullet level 3 with physical plate S = 1.6 x 1.4 = 2.24 and it needs 18. Three plain guns (d = 3): 15 at S = 1, 9 at
S = 2.24. Band holds at 10-40 through era 4 if the player's research stays within the era cap below.

## 3. Prototype tiers
One plate tier per damage type, never stacked: `lp-<corp>-<kind>-<plate>` for infantry, tank, buggy, harrier, walker
(5 kinds x 3 plates x 2 corps = 30 prototypes). Extend `shared.variant(corp, kind, plate)` and strip the suffix in
`kind_of`; `corps.lua` copies the base kind and patches `max_health` and `resistances`; `produce` and `escort` pass
`tech.plate[name]`. Existing units are kept until they die. No refit, no migration.

## 4. Readability and the cap
- Notices in the corporation's voice: "Serenity Perimeter Group has upgraded its cannons (level 2)." / "Grubstake
  issues ablative plating to its infantry." Plated units get a darker trim tint and a labelled name.
- A line in the map-tag tooltip: "Arms: bullet 2, cannon 1. Plate: infantry fire."
- **Cap by the player's era:** weapons level at most `era + 1`; plates from era 1. A player who stops researching
  freezes the corporations; a withdrawing corporation never buys.
- The fund stops at 10,000 unspent.

## 5. Headless checks (scenario `techup`, then campaign 777)
1. Player bullet damage +0.8, three gun turrets, fund granted: within 20 minutes bullet weapons reach level 2 or more,
   `ops.debug_needed` falls from 35 to 22 or less, a raid launches with at most 40 units.
2. 15 units killed by lasers, no aborts: the next purchase is the laser plate; new units carry the plate name; no old
   unit is replaced.
3. Era-0 player, fund 20,000: nothing beyond level 1.
4. Campaign 777, 6 hours: 90% of raids between 10 and 40 units.
5. `profile.sh six`: mean script at most 0.1 ms a tick.
6. Withdrawn corporation: fund grows, no purchase.

## Build order
1. Ledger and death tally, trace only. 2. Weapons tracks, `S` in `needed`, notices, era cap, checks 1, 3, 6.
3. Plates: prototypes, `variant`/`kind_of`, production, checks 2, 5. 4. Campaign rerun; recalibrate `PER_TURRET` once.
