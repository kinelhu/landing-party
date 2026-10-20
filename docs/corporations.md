# Corporations: identity design (proposed 2026-10-13)

A design pass before building the corporations (user: "factions should have architectural identity beyond
just color ... you need a design pass before building them"). Each corporation must be recognisable at a
glance from the ground and from the map, and must fight differently (`docs/campaign.md` section 4 has their
roles: what they attack with, how they defend, where they break, what they want).

Everything is made from vanilla sprites and entities: tinted, scaled, layered, recombined. Base game first;
Space Age entities are used only where marked **SA**, with a base-game fallback.

## 1. The identity kit

Each corporation is defined by the same eight things:

1. **Palette**: a primary and an accent colour (unit tint, lamp light, map colour, logo).
2. **Logo**: two or three vanilla icons layered on a backing disc, tinted; stamped on the ground (section 2).
3. **Floor**: the tiles of its roads, pads and plazas (coloured refined concrete exists in vanilla 2.0, in
   eleven colours, plus hazard concrete).
4. **Walls**: none, single, double, or pillboxes; gates or none.
5. **Turrets**: which types, how many, and how they are set (open, walled, in reinforced positions).
6. **Units**: its signature mix, and one signature vehicle.
7. **Layout**: settlement archetype and silhouette (sprawl, compound, grid of pickets, dense hubs).
8. **Voice**: the tone of its notices (one line each, deadpan corporate).

## 2. Logos

**Revised after three looks (2026-10-13): no logos on the ground.** Built instead: map tags and notices with
the corporation's icon (a vanilla signal at its own size: Grubstake the mining pick, Serenity the heart), and
floor livery (pad floor and trim) carrying identity on the ground. The section below is the original
proposal, kept for the record.

A logo is a decorative ground entity (no collision, drawn on the floor layer, under everything), one per
corporation, built in the data stage from layered icon sprites at about 4x4 tiles. Stamped:
- at the centre of each hub's plaza, on its concrete;
- on depot and launch pads;
- at the gates of compounds (Serenity), beside each picket (Lumen), on convoy depots (Grubstake), on the
  garage floor of each depot (Concord).
It is destroyed with the block it belongs to and comes back when the block is rebuilt. When a settlement falls,
its logos stay as part of the ruins (a scorch tint), so the map remembers who held it.

| Corporation | Layers (bottom to top) | Colours |
|---|---|---|
| **Grubstake Mineral Recovery** | backing disc; iron ore icon; mining-signal pick over it | ochre on dark brown |
| **Serenity Perimeter Group** | backing disc; energy-shield icon; a heart signal inside the shield | pale teal and white on slate |
| **Lumen Transparency** | backing disc; sun signal; info signal ("i") at its centre | white and violet on black |
| **Concord Munitions** | backing disc; white-flag signal; weapon signal across it | brass and red on olive |

Mottos (chosen by the user, 2026-10-13: deadpan corporate copy, the menace implied): Grubstake "Resources in
the right hands."; Serenity "Please remain behind the line."; Lumen "Total illumination."; Concord "Trusted
by all parties."

## 3. The four corporations

### Grubstake Mineral Recovery (the thief)
- **Palette**: ochre, rust brown. Lamps warm amber.
- **Floor**: stone path (gravel, cheap) on roads; brown refined concrete only on convoy depots, with the logo.
- **Walls**: none around production; a single low fence (a weak wall variant, half health) round convoy depots.
  It does not build to last.
- **Turrets**: few. Open gun turrets (script-fed ammunition) at depots only; outposts are unguarded and
  rebuilt fast instead.
- **Units**: infantry, haulers in numbers, and its signature **buggy** (the car's hull as a fast, light raider
  that escorts convoys and runs down lone engineers). No tanks.
- **Layout**: sprawl: thin, spread, many small mining outposts strung on long gravel roads, few hubs; convoys
  everywhere. Silhouette: a web of roads with drills on it.
- **Notice**: "Grubstake Mineral Recovery has recovered 4,000 iron ore from an unattended deposit. Thank you for
  your cooperation."
- **As built (2026-10-19)**: a rival thief that escalates when hurt; it steals by night: soft raids that take machines
  apart and carry them off (ghosts left), skimming trucks parked at exposed belts, chest heists by claim jumper, power
  taps, ore claims; a pact with the biters, pheromone flares. Its loot is kept as items in its yard. Its raids break
  when their foreman falls, and the foreman drops the whole haul.

### Serenity Perimeter Group (the wall)
- **Palette**: slate grey, pale teal. Lamps cold white.
- **Floor**: refined concrete everywhere inside its walls; refined hazard concrete at gates and on the mortar
  pads; logos at each gate.
- **Walls**: **double walls** with a 2-tile gap (the second ring staggered so its openings never line up with
  the first); **gates** on every road opening; mines in the gap.
- **Turrets**: lasers in **reinforced positions** (a turret inside a 4x4 walled pillbox, entered from the
  inner side only); flamethrower turrets covering the gates; mortars permanently emplaced at mature compounds.
  **SA**: tesla turrets at gates (fallback: a second flamethrower).
- **Units**: infantry and tanks, mortar crews (the siege operation); no air.
- **Layout**: fortress and bastion: compact walled compounds, short roads, everything inside a perimeter.
  Silhouette: concentric grey rectangles.
- **Notice**: "Serenity Perimeter Group has secured the area at [map]. Unauthorised presence will be resolved."
- **As built (2026-10-19)**: at war from landing. A line of cordon posts that steps toward the player, strangles
  outposts, claims the next ore, cuts belts on its edge where its guns stand; sieges sized to win (mortars, the
  howitzer, a robot jammer), the power strike, clearances of the nests that hit it, and an invoice for the waves the
  player's pollution draws, paid off for a truce or disputed by killing the nest it names. A howitzer killed leaves it
  without one for 30 minutes. Its raids regroup when their leader falls. Being at war, it answers
  trespass only (a siege); its losses in the field are fair war.

### Lumen Transparency (the eye)
- **Palette**: black, violet, white. Lamps violet; many of them (it is lit at night, visible from far).
- **Floor**: black refined concrete; violet-tinted pads under radars; a logo at every picket.
- **Walls**: thin single walls round pickets only; hubs open.
- **Turrets**: few lasers; its strength is sight: radars at every picket and hub (with the jammer field
  later). **SA**: rocket turrets at hubs against air (fallback: lasers).
- **Units**: harriers (air) and infantry; aborts early, evacuates.
- **Layout**: picket grid: small hubs, a lattice of pickets far out, each a radar, a lamp mast, two lasers and
  a wall. Silhouette: dots of violet light across the map.
- **Notice**: "Lumen Transparency has updated its records of your activities. No action is required."

### Concord Munitions (the dealer)
- **Palette**: olive drab, brass, signal red. Lamps orange.
- **Floor**: concrete (plain) on roads; orange refined concrete with hazard edges on depot and garage floors.
- **Walls**: sandbag lines (single stone walls, short, in front of turrets only), no full rings.
- **Turrets**: gun turrets with heavy ammunition in pairs, flamethrowers at depots. **SA**: rocket turrets
  (fallback: more gun turrets).
- **Units**: tanks and walkers in numbers; large garrisons; its depots are **garages** (more of them, each a
  bigger pad). It sells units to the others (campaign).
- **Layout**: bastion: dense hubs with many depots, open ground between them for vehicles. Silhouette: big
  orange pads full of armour.
- **Notice**: "Concord Munitions thanks you for your continued interest in its products."

## 4. What this asks of the code

- **Per-corporation prototypes.** Tint is baked into prototypes in the data stage (`data.lua` `copy()` tints
  with `shared.TINT`). So each corporation needs its own copies of the entities it uses: `lp-<corp>-turret`,
  `lp-<corp>-wall`, `lp-<corp>-infantry` ... The roster of kinds stays shared; a table maps (corporation, kind)
  to a prototype name, and the code asks it instead of naming prototypes (`lp-turret` appears in many places).
  Four corporations times about twenty kinds is about eighty prototypes: fine for the engine.
- **New kinds**: buggy (car hull unit), weak fence (wall at half health), pillbox (a layout, not a prototype),
  gate (vanilla gate copy), flamethrower turret (vanilla copy; its fluid filled by script), gun turret copy
  (ammunition inserted by script), decorative logo (simple entity on the floor layer), per-corporation road
  tiles (copies of stone path, concrete, refined concrete variants, hazard concrete).
- **Layout**: doctrines already shape layouts (`layout.DOCTRINES`); the identity adds wall styles (none,
  fence, double with gates, sandbag lines, pillbox), turret styles and pad floors to the block templates.
- **Corporations as forces** first (`lp-grubstake`, `lp-serenity`, ...), each with its state (development,
  intel, standing): the refactor everything else builds on.

## 5. Build order

1. Corporations as forces (no visual change): two corporations, Grubstake and Serenity, landing and fighting.
2. Per-corporation prototypes and the (corporation, kind) table: palettes and units recoloured.
3. Floors and logos.
4. Walls, gates, pillboxes and turret styles in the templates.
5. Buggy for Grubstake; flamethrowers for Serenity's gates.
6. Lumen and Concord after the MVP.

Each step checked in the dump and headless; a showcase save at steps 3 and 4 for a ten-minute look (one
question per look: "can you tell the two corporations apart at a glance, on the ground and on the map?").
