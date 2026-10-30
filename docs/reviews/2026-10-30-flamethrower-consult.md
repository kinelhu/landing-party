# Synthexis against flamethrowers (consult, 2026-10-30)

Read-only. Sources: `docs/sim/lab-lab-plot-edit/`, the Synthexis scripts, the game's `fire.lua`, `enemies.lua` and both API
files at 2.1.23. Figures are recomputed from the recordings.

## 1. What killed the waves

The fortress: 179 lasers 7 tiles behind the wall, 22 flamethrowers 16 tiles behind it and 24 apart along each straight run,
620 mines, 2,002 wall pieces, one storage tank feeding every flamethrower through 190 pipe pieces, all inside the wall.

**Trial 1** (60 units: 16 behemoths, 16 big, 19 mediums, 5 cinders, 2 spitters, 2 spores; 750 mediums). Plan: in at 305,15,
priced 109 under 15 guns. The herd staged out of fire, waited for its runts, walked to the wall and stopped to chew (first flame
death 240094, first wall piece 240104). Two flamethrowers then killed 45 units worth 686 mediums in 14 s at 17 to 40 tiles, the
herd standing at 2.5 tiles/s. Behemoths died 4 to 13 s after first coming within 30 of a flamethrower (median 7.9 s), losing a
median 272 health/s in reach (90th percentile 682). Lasers killed 9 runts and 1 big biter; mines 10. One unit came home.

**Trial 2** (siege: 51 behemoths, 2 big bursters, 7 cinders; 2,051 mediums). Plan: in at 257,79, which is the south
flamethrower line itself (turrets at 252,76.5 and 276,76.5), priced 174 under 17 guns, 0 openable. Both bursters stopped at the
wall, stood 10 s in reach, lost 2,000 health in 5 s and died unburst (their death blasts broke 68 wall pieces). The herd crossed
the line at 5.4 tiles/s and went east for the lasers at x 316, into the east line's reach. 34 behemoths died to fire (1,360
mediums), 12 to 27 s after first exposure (median 20.7), losing 94 health/s in reach and 94 out of it: the sticker alone. The
recording credits them to the south turrets at 60 to 118 tiles: tagged at the breach, dead wherever they were. Lasers killed 13
(520). Razed worth 6. The player's own fire killed 6 of its lasers and 7 mines.

**Trials 3 to 6**: no attack. Prices after trial 2: flamethrower 37, laser 26, mine 30. Every way in reads 1,202 to 1,419 and
every place scores 0.00 while 12 incubators sit on biomass.

## 2. The mechanics (fire.lua, enemies.lua, the API)

- **Turret**: range 30, `min_range` 6, `turn_range` 1/3 (a 120 degree arc about its 8-way `direction`, readable as
  `LuaEntity.direction`), cooldown 4 (15 shots/s), 0.2 fluid a shot, buffer 100 (33 s of fire once the pipe is cut), firing
  again only at 25% refilled. `fire_penalty` 15: a burning target counts 15 tiles farther, so the stream moves on to the next
  unburnt unit. The tank holds 25,000: 22 turrets at 3/s each empty it in 6 minutes of continuous fire. Fuel is no in-fight lever.
- **Stream**: on landing, 3 fire damage and a `fire-sticker` to everything within 2.5 tiles, and a `fire-flame` on the ground.
- **Sticker**: 100 fire/s for 30 s = 3,000: one tag kills a behemoth (3,000, no fire resistance; no vanilla biter has any) and
  everything smaller. 20% slower while burning. A big burster (50% fire) survives one tag at 1,500.
- **Ground fire**: 13/s, times one more for every refuel within 10 ticks up to 6 (78/s a flame), alive 2 s plus 2.5 s a refuel up
  to 30 s. No sticker. A crowd standing under a stream collects overlapping flames at full multiplier: trial 1's 272 to 682
  health/s. A crowd that walks through takes the sticker alone: trial 2's 94/s.
- **Attribution**: `on_entity_died.cause` is the turret for stream, ground fire and sticker deaths alike, type `fire`.
- **The splash hits everything**: 2 spores (`air = true`) burned at the wall in trial 1. DESIGN's "flamethrowers ignore air"
  does not hold for the spore.
- **This fort**: 1,946 of 2,002 wall pieces lie within 30 of 1 to 3 flamethrowers; 56 do not, at the NE, NW and SE corners (the
  turrets stand on the straights), under 11 to 18 lasers and mines. The arc changes nothing at the wall if the turrets face
  outward, and everything inside: behind the line, nothing burns.

In one line: a flamethrower's price is dwell times heads, not a per-gun number. Cross its reach at speed and every head it
reaches is tagged (34 of about 38 behemoths that passed the line) and dead within 30 s; stand in it and the crowd melts in
seconds; stay out of its arc and it costs nothing.

## 3. What the current AI misreads

1. **A flamethrower is a disk priced like a gun.** `threat.profile` reads `range` only; `firemap` makes a disk of 32;
   `FLAME = 17` is added like a gun's price. `know.PRICE_MAX = 40` caps what it can learn: two turrets took 686 and were learned at
   26, 32, 37. Nothing in the model can say "this breach is the whole herd".
2. **The hold points are in the fire.** `costmap.staging` puts the breach where the most guns cover the way; the herd holds for
   its sweep out of reach, then stops at the wall to chew (trial 1) or picks targets on the line itself (trial 2). `punch`
   forbids a stop to fight, not a stop at a wall it must bite through.
3. **Bursters go at the dearest gun** (`send_big_bursters`): the flamethrowers behind the wall, where they stop and burn before
   bursting. `herd.plan` already knew `openable = 0`.
4. **Credit went the wrong way.** After trial 1 the laser price fell to 1.12: the `wiped` guard in `learn_price` compares `left`
   to `w.size`, and `w.size` had been reset to `alive(w)` (3) at the punch-through (herd.lua 2884 to 2893).
5. **Inside, "the guns firing on it first"** sent trial 2's herd from the south breach into the east line's reach, and the
   withdrawal recrossed it (11 behemoths, 440). `targets` and `withdraw` read no fire arcs.
6. **The siege's breed is health per biomass** (`herd_breed`). Fire kills per head: a 200-biomass behemoth and a 7-biomass
   medium die to the same tag.
7. **The give-up is total.** With prices wrong both ways the farm reads "it cannot go in" everywhere and holds for four trials.
   It cannot tell "closed to a standing herd" from "closed".

## 4. Recommendation, ranked

**R1. Price fire from the prototypes as dwell, not as a gun.** Write an `lp-fire` mod-data table in `data-final-fixes.lua` as
`lp-bites` is written: for every fluid turret, follow `attack_parameters.ammo_type` to its stream, its `create-sticker`
(duration times damage: the tag, 3,000) and its `create-fire` (`damage_per_tick` times `maximum_damage_multiplier`: 78/s),
with `turn_range` and `min_range`. No typed number; a modded flamethrower reads the same way. `threat.profile` carries `arc`,
`min_reach`, `tag`, `burn`. `firemap.each` and `entries_box` test the arc (the turret's `direction` plus or minus `turn_range`
times 180 degrees) and the minimum range, not the disk. In `costmap.cell_cost` a fluid turret's cell costs the heads of the
wave whose effective health is at most `tag / (1 - fire resistance)`, in mediums, times the share a crossing exposes (about
0.9 here; learn it as `opens` is learned); a wall cell in its reach costs the whole wave, which is what standing there does.
Expected on this fort, from lab-run's geometry: the cheapest breach moves to a corner (0 flamethrowers, 12 to 18 lasers), a
place the current prices never prefer. Legible: the waves hit the corners the fire does not reach; the answer is a flamethrower
at each corner. Lab check: `scripts/siegelab.sh run <save> 4`; in `decisions.txt` the plan's breach should sit at a corner cell
with lasers alone covering it; in the report, flame deaths should fall from 686 and 1,360 to near zero and lasers carry the loss.

**R2. No ground unit holds inside a live arc; bursters only at guns they can reach.** In `breach`, a `w.breach_at` inside a
live flamethrower's arc with `openable == 0` for those turrets refuses the plan (`finish(w, "fire covers the breach")`, the
place marked `dear`). `send_big_bursters` sends none at a gun with a wall between (the per-gun `openable` test from
`herd.plan` in place of dearest-first). `targets` drops any candidate inside a live arc unless the wave stands behind the
turret; `withdraw` routes home by the cost map with arcs on, not back along the trail. Lab check: `bursters.burst` 0 with
`big_sent` > 0 should not recur; no `dead_at` entry within 30 of a flamethrower in the `inside` or `withdraw` stage.

**R3. Fix the credit.** `learn_price` judges `wiped` against the number that set out, not `w.size` after a reset; a gun's price
is learned from deaths whose `cause.name` is that gun (the handler already keys deaths by killer), not from the breach's whole
loss; `PRICE_MAX` does not apply to the dwell price (derived, not learned). Lab check: after a trial dominated by flame
deaths the laser price must not fall (`prices_after` in lab.jsonl).

**R4. Breed against the killer only where the mechanics say it pays.** The `order` rule "big biters when dying to lasers and
flamethrowers" is right for lasers and wrong for fire. At a fire-covered breach, health per biomass gives way to "heads over
the tag": only the big burster qualifies (1,500 against 3,000), and its job is the wall, not the gun behind it: blast a hole
while the herd waits out of reach, then run. If no breed qualifies, the farm says "closed to its ground breeds" and keeps
weighing other places. I would not add fire resistance to a breed: it is a new number, and the user ruled those out.

Not recommended: fuel denial in the fight (33 s of buffer a turret, 6 minutes of tank), spitters (16 against 30), the stomper
(no fire resistance; unverified whether the splash tags a spider unit).

## 5. Unverified

- Whether a reapplied `fire-sticker` refreshes or stacks (the API has no field for it; the 94/s in trial 2 fits one sticker).
- Whether `fire-flame-on-tree` spawned round a burning unit (sticker `spread_fire_entity`, radius 0.75 every 30 ticks) burns
  units on bare ground in 2.1; if it does, a burning crowd lights itself.
- That the lab's flamethrowers face outward (the recording holds no `direction`); the arc test in R1 reads it at runtime.
- 2.0 fluid segments: how much a cut-off pipe run keeps for its turrets.
