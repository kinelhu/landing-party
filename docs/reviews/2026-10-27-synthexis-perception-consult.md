# Synthexis's perception and the three factions' knowledge layer: a consult (Fable, read-only, 2026-10-27)

Asked after the user's: "I think you need a consult ... many things you didn't take into account with big implications for
the mod's architecture" and "this base only has gun turrets ... Are they able to learn that certain turrets are more
dangerous? do they take into account the varying range? how do they treat artillery? as a main target? how does all
this affect swarm composition?". Read: `firemap.lua`, `valuemap.lua`, `costmap.lua`, `herd.lua`, `farm.lua`, `intel.lua`,
`power.lua`, `know.lua`, `cuts.lua`, `counters.lua`, `control.lua`, `shared.lua`; DESIGN.md rows 88 to 91; docs/biotech.md;
docs/ai-graph.md; scripts/wavemap.py; the 2.1.23 runtime and prototype API.

## 1. The verdict

Five modules each carry their own table of what a turret is: `firemap.REACH` (20/26/32, by type), `intel` `WEIGHT` and
`EXPOSE` (1/1.5/2.5 and the same reaches), `farm.DEFENCE` (1/1.5/2.5 again), `power.REACH` (30: a pole 30 from a
flamethrower is "exposed" inside its reach), `herd` `LOOP_OUT`/`LOOP_CLEAR` (29/30: the scout's pauses stand inside a
flamethrower's 30, so on a flamer base the tell dies). Only the probe reads `prototype.attack_parameters.range`. The learned
price is one scalar per foe force, so "can they learn that certain turrets are more dangerous" is no, although the
evidence is already recorded twice: `w.lost_by["breach gun-turret"]` keys every death by stage and killer, and `know.loss`
keeps killer kind per death for every faction. Artillery appears nowhere in the maps. Composition (`counters.lua`) reads
the last lesson's killers only; the maps never feed it. The farm prices the way in by rays, the herd by Dijkstra: two
models that can disagree on the same base. The three maps are the right shape (no cube assumed, inside is where cost
jumps, a hole is cheap); they lack a shared source of truth about danger, and learning is below the grain of the evidence.

## 2. Architecture: one perception layer, three readers

- **`threat.lua` (new, leaf).** The one source of what each weapon prototype is: `threat.profile(name)` from
  `attack_parameters` (`range`, `min_range`, `cooldown`, type, ammo categories), `turret_range` for artillery,
  `resistances`; cached in `storage.threat.profiles`, rebuilt in `on_configuration_changed`. Any entity with
  `attack_parameters` gets a profile (modded turrets, cars, spidertrons, Kessler-Hayashi's units as "mobile"). Research and
  state read at use: `get_ammo_damage_modifier`, `get_gun_speed_modifier`, `get_turret_attack_modifier`,
  `artillery_range_modifier`; `entity.status` (`no_ammo`, `no_power`, `low_power`, `no_input_fluid`) replaces `power.dark`
  and makes a dry gun weigh 0 without a probe (the probe stays for what status cannot tell). Lethality prior per (kind,
  damage type) generated from the arena (`scripts/arena_report.py` writes `threat_prior.lua` beside `counters.lua`), then
  learned in play.
- **`firemap.lua`** entries gain `lethal`; a weighted `firemap.heat(map, pos)`; `intel.exposure` and `ops.weigh` become
  thin calls on it (one definition of "exposed" for all factions). The enclosure probe in `routing.lua` retires once the
  corporations read the cost map.
- **`costmap.lua`** reads its layers in one engine call each over the box, bucketed in Lua, not ~7,500 calls per read;
  fire term lethality-weighted; a cheap "blocker" layer (the foe's buildings as a soft wall).
- **`feeds.lua` (new):** section 4, generalising `power.cut`.
- **`valuemap.lua`:** supply entities' worth from `feeds`, not the flat table.
- **`know.lua`** is the learning store for all three factions: per-prototype price, lessons per base cell. Maps computed
  per decision, never stored except as numbers; a per-base coarse read cached in storage, dirtied by the build and death
  hooks, so the farm weighs its candidates from cache.
- **Readers:** farm/herd (Synthexis) and ops (the corporations) read the same maps with their own `mind` (price prior,
  HOLD, DEEP_MARGIN, FUNNEL, min_gain, caution). The farm's rays retire; it reads the cost map too.

## 3. Danger and learning

`storage.know.biotech.price[foe_force][prototype] = {per, n}`, prior scaled by the threat prior (a laser starts dearer than
a gun). At `finish`, per killer prototype: deaths at the breach over turrets of that prototype covering it (keep
`w.breach_cover` by prototype). Per base, lessons gain killers by face. The corporations feed the same store. Mobile
defenders: a garrison term from `intel.mobile`'s profiles, learned the same way. Composition and target together: a
candidate's expected killers are the cover histogram along its cost-map path; `fit_of` from `counters.lua`, with
resistance priors where the arena has no column; odds computed for the stock it would actually send. A small lever.

## 4. Supply and dependency, one graph

`feeds.lua`: for each turret, its feed chain by medium: ammo (`inserter.drop_target`, `pickup_target`, upstream
`belt_neighbours.inputs` to N, containers as sources); power (`electric_network_id`, pole copper wires, as `power.cut`);
fluid (`get_fluid_segment_id`, pumps and tanks as sources). One articulation search (Tarjan, as in `power.cut`) over the
union: an entity's dependency worth is the summed price of turrets whose only feed passes through it, 0 with a second
feed. Kessler-Hayashi's cut becomes `feeds.cut(graph, "power")`; Synthexis's supply tiers become `feeds.worth(e) > 0`.
Starving takes time (10 magazines a gun), so the payoff lands on later waves. Tell: bitten belt segments, no-ammo icons
spreading along the line. Counter: a second feed, buffer chests, undergrounds under the wall line, accumulators.

## 5. Artillery

Artillery auto-targets military structures (spawners, worms, turrets), never units, within `turret_range` times the
force's modifier; needs shells; `artillery_auto_targeting` can be off. No danger to a wave, mortal to the farm. Model:
profile kind "artillery" (lethal 0 to units); the farm lists artillery covering a pen once a minute (and on build); the
piece's worth is proportional to the pens it covers; `deep_plan` forced toward it, DEEP_MIN waived. If no wave can afford
the way, creep withdraws from shelled pens and seeds beyond reach. Tell: shells on the creep, then a trail straight to the
gun, the marked leader. Counter: a walled artillery keep, a second piece, pens pushed out of reach.

## 6. What the player sees

The scout's pauses at each face's true reach; the thing bitten shows the lesson learned (poles after a laser line, the
belt after a gun line); bitten belts and no-ammo icons; artillery as the one weapon Synthexis targets as a heart; all three
factions reading "where cost jumps", so the player's answer (no hole in the fire) holds against each.

## 7. Testing

Add calibration: each wave predicts its loss (`w.way_in.lost`, `best.lost`), `finish` records the actual; `wavemap.md`
reports predicted against actual. A change to threat or price must move calibration toward 1 before it is judged on razed
worth. Five seeds, paired A/B, "won on k of 5", median worth per biter lost. Lab bases in `tests/lp-sim`: a laser line on
one feed, a flamer wall on one pipe, the ring plus walled artillery, an unwalled sprawl, the nw megabase, a base with a
second ammo feed (the counter must hold); each with a named expected heart checked by `debug_base_maps` before any wave.

## 8. The order

1. `threat.lua` from prototypes, replacing the five tables; scout loop from the profile.
2. Per-prototype price in `know`, learned from `lost_by` by prototype; `ops.weigh` reads it.
3. Cost map single-read layers, heat-weighted; the farm on a cached cost map, rays retired.
4. `feeds.lua`; `power.cut` becomes its power medium; supply worth in the value map.
5. Artillery: threat to pens, forced deep target, creep withdrawal.
6. Composition from the path's cover histogram with resistance priors.
7. The lab bases and the calibration column, then five seeds for every later change.

## Found on the way

- `herd` `LOOP_OUT` 29 and `LOOP_CLEAR` 30 against a flamethrower's 30 (plus 2): the scout pauses inside its reach.
- `power.REACH` 30: a pole within a flamer's reach counts as exposed.
- `farm.target_from`: `c.defence = max(c.defence, 2 * c.entry)` mixes a weighted sum with a ray's turret count.
- `targets()` queries the surface per inserter where `drop_target` is one read, and misses chest-fed and laser-fed turrets.
- `firemap.read` weighs only `no_power`; `no_ammo` and `no_input_fluid` are one status read away.
- `LuaEntity.fluidbox` does not exist in 2.1.23; use the fluid methods.
