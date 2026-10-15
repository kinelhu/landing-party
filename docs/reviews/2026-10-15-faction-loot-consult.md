# Reverse engineering: loot and faction tech (Fable), 2026-10-15

Read-only consult. The user: drop the custom salvage currency and scrap on the ground; corporation buildings and units
drop ordinary Factorio items, plus rare faction components the player uses to research faction tech.

## Frame
What you keep is paid once; what you spend costs a part you took. Durable things consume components only in research;
consumables (shells, bait, a strike) consume them per use, so raiding keeps paying and nothing becomes a factory line.
Grubstake's parts are smelly, cheap, many (glands, crystals, drill heads); Serenity's precise and few (coils, fuzes, a
beacon).

## A. Ordinary loot (the engine's `loot` on death; `minable.results` for ruins and captures)
- Buildings with cost >= 8: iron cost/2, copper cost/4, circuits cost/10, each at 0.8 with count 0.5-1x; kind flavour:
  turrets 2-5 magazines, generators 1 engine, drills 2 gears, depots cost/4 steel, lander 20 steel plus its cores.
- Cost < 8 (walls, gates, pylons, bins, lamps, mines, flamers): nothing (the flood valve).
- Units: cost/4 of their own kind, half the time (Shotgun hand 1-3 shells, Line trooper 1 circuit, buggy 1 engine, tank 4
  steel and 1 engine, hauler 8 steel).
- Ruins and captured buildings mine to the same table at 100%. lp-salvage goes, with a migration.

## B. Components (items, stack 10, no recipe)
Grubstake (from chemical science): pheromone gland (flare canister 1; pacifier 3-5), pacifier crystal (the landing's own
pacifier 1 at 100%, a rebuilt one 25%), drill head (claim rig 2; strip camp drill 1 at 50%).
Serenity (from the first rocket): rail coil (railgunner 20%), cluster fuze (mortar site 3, howitzer 6), orbital beacon
(lander 1, the HQ's 2).

## C. Six technologies, each research_trigger craft-item on a teardown recipe ("X, disassembled")
1. Pheromone bait (G, 3 glands): a placeable canister, 1 gland each; nests within 150 send idle defenders at it.
2. Pact breaker (G, 1 crystal, after bait): while it stands in Grubstake's territory the pact is suspended (3 min max).
3. Claim marker (G, 2 crystals): Grubstake reads the player's buildings within 40 as its claim; raids and strips skip
   them. (No real player pacifier: cease-fire is per force, it would end biters map-wide.)
4. Cluster shells (S, 3 fuzes): artillery shell + 1 fuze.
5. Rail rifle (S, 2 coils, military 3): the railgunner's slug, 150 physical, every 90 ticks; rail slug ammo.
6. Orbital strike (S, 1 beacon): a powered beacon calls the barrage on every nest and enemy building within 60, consumed.
The two prizes take components instead of salvage.

## D. Command cores
Kept apart: cores gate the army's size, components its kit. One bridge: after Rail rifle, the barracks trains a rail
trooper.

## E. First slice, ranked, with tests
1. Loot tables, salvage gone (`loot`). 2. Fuzes and cluster shells (`fuze`). 3. Bait (`bait`). 4. Rail rifle (`rifle`).
5. Claim marker (`marker`). 6. Pact breaker, orbital strike (`breaker`, `strike`).
"Everything they build, I take apart on the bench: their shells, their rifle, and once, their orbit."
