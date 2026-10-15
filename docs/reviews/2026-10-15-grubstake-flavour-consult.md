# Grubstake's flavour pass (Fable), 2026-10-15

Read-only consult. The user: Serenity has become the high-tech faction (railgunners, cluster shells, the orbital
barrage), arriving late; Grubstake, arriving early, the cheap swarm, needs a pass of its own. Ideas the user liked:
pheromone flares, claim jumpers, grapple buggies, the scrap cannon ("a sort of dirty flak"), rust and brass looks.
Rejected: boobytrapped claims.

## Frame
Serenity is seen before it is felt (the line, the barrage). Grubstake should be felt before it is seen: things go wrong
near the player's stuff and the cause is found a minute later, outside the wall. Every piece: a tell the player can
find, a timer, a cheap kill that ends it.

## The pieces
1. Pheromone flare. A buggy drops a canister 20-25 tiles out (past gun-turret reach) and leaves. Tell: a tall coloured
   smoke column, a custom alert, a map tag for 3 minutes. Idle nest defenders within ~150 tiles are pulled into a group
   sent at the canister (attack_area); they attack what they meet. Counter: shoot the 200-health canister. No pacifier
   standing, no flares. Pull 12 + 24 x evolution, one flare a settlement per 10 minutes.
2. Claim jumper. A drill rig (lp-claim-rig, 1,200 health, military) digs in 40-60 tiles out: dust plume, tremor, alert.
   Inside the wall a dirt mound grows for 60 s (a tell, not killable), then 4-6 Shotgun hands emerge, loot chests within
   16 tiles, raze what they stand by, leave by the mound. Counter: kill the rig within the minute. One rig a settlement,
   rung 2 up. A heist, never an assault.
3. Grapple buggy. Looting's animation, not a new mechanic: a chest becomes a towed sled (a unit wearing the chest's
   sprite) that follows the buggy home and spills its contents when killed. Wagons stay rail-bound (the heist).
5. Scrap cannon, dirty flak: bursting shot, not a cone (a cone is the Shotgun hand). A lobbed shell airbursts: 2.5-tile
   area of 4 physical plus six scattered bomblets of 3, and a script effect spilling 1-3 lp-scrap. Many soft hits over
   an area against the railgun's one hard hit along a line: deadly to blobs of biters and troopers, nothing to walls and
   turrets. A tripod turret first (range 14, at strip camps and claim rigs), a flak wagon unit later (era 2). Haulers
   collect scrap as parts.

## Fold
Dynamite sappers go: the claim rig takes their era-2 slot and their wall answer; the emerged squad may carry dynamite.
Scavenger harriers stay (rockets are the only answer to artillery). Grapple folds into looting. Crash-landing pods are
art and sound only.

## Ladder
Rung 0: strips and soft raids with the camp's cannon; rung 1: flares; rung 2: claim rigs, two nests a flare; rung 3:
flare and rig together, then the loot raid.

## First pass, ranked, with tests
1. Scrap cannon turret. `flak`: 20 small biters (pact off) and 10 troopers, 15 dead in 20 s; a wall loses under 5% in
   60 s; scrap on the ground, a hauler brings it home as parts within 2 minutes.
2. Pheromone flare. `flare`: an outpost with 2 gun turrets, a nest 120 tiles off: canister within 25 tiles, 10 biters
   commanded within 30 s, ammo spent, canister killed at 60 s and the group idle within 30 s more, no biter attacking
   Grubstake; no pacifier: no flare.
3. Claim jumper. `jumper`: a walled square, 4 turrets facing out, a chest of 200 plates: rig 40-60 out, 6 hands inside
   within 10 tiles of the mound at 60 s, chest emptied; rig killed at 30 s: nothing emerges.

What the player tells a friend: "Serenity shells you from orbit; Grubstake sends the biters in first, tunnels under
your wall, and leaves with your chests."
