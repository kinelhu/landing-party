# Pressure that ramps (Fable), 2026-10-15

After the expansion visit (nwa, three hours): the settlements that reached the player razed in their first 30 to 40
minutes and then sat at a garrison of nought; the far ones survived and could not reach. The user: "it's not good that
only the first raid does anything; it's actually quite counter-intuitive, as raids should be able to ramp up with the
logic you built, supposedly?" (and: not to treat that as gospel). Read-only consult.

## Diagnosis
Every unit a camp fields comes from the free drop escort or `produce`, which needs the settlement's own parts. Under the
guns the camp has no income (drills shelled) and `place_next` spends what little it gets on rebuilds before `produce`
sees it. Capacity peaks at landing and falls; the ladder only lowers the price of using it. Rung 3 sends "everything",
the escort's remnant, once. The ladder is a willingness clock bolted to a dying economy: fix capacity, keep the ladder.
(Side note: `produce` places one unit per call per settlement, not per depot as its comment says.)

## What the player should see
Serenity at war: the line keeps advancing and things get built behind it. A relief column (hauler and escorts, the
convoy that exists) reaches the besieged settlement from a sister settlement, with a notice in its voice; the next
siege is a tier higher. The player's counter is the column's route.

Grubstake at war: a scrap pod lands beside the lander with buggies and Shotgun hands ("Contractors arrived at Claim #4.
Hazard pay approved."); every building it razes pays its next pod. A hopeless claim lifts off ("Claim #4 written off.
Equipment recovered.") and 20 minutes later a new camp is down on the player's other flank, angry (grudge). Grubstake
never reinforces by land and never holds a doomed site.

## A. Ramping, bounded
1. **War footing** (a settlement at rung 1 or more against a player, or provoked with that player known): the build
   order becomes hull generators and the depot, then units to cap, then rebuilds. An entity killed twice in 10 minutes
   by artillery is written off.
2. **War chest and reinforcement**: each corporation keeps a chest, 20% of exports (research keeps its 30%), cap 6,000,
   plus Grubstake's salvage. A settlement at war below its cap gets a reinforcement from the chest at most every 10
   minutes a corporation, by rung: 0 nothing, 1 eight units, 2 sixteen, 3 twenty-four, at 1.5x unit cost. They count
   above the cap and leave with the next operation. Serenity's come as a relief column from its nearest settlement
   along a route (none, no relief); Grubstake's as a pod at the lander, 40 tiles out.
3. **Write-off and relanding** (Grubstake first, Serenity at level 2+): no income for 15 minutes and garrison below 3
   under fire: units evacuate, the lander lifts off, the next landing in 20 minutes on grudge terms away from the
   battery that shelled it. One reland a corporation per 30 minutes; written off twice, no reland.
4. **The ladder buys capacity**: rung 2 doubles the cap (the grudge mechanism); rung 3 raises the siege tier; rung 3
   held 30 minutes with no raze triggers the write-off.

Serenity ramps by escalating the same siege, never by numbers alone; Grubstake by more cheap bodies and more sites,
never by sieges. Serenity reads as a front, Grubstake as infestation.

## B. Target curve and levers
Razes per 10-minute row per corporation at war, on a normal map from the first rocket: landing +0-30 min 0-1; +30-90
min 1-2, an operation every 5-8 minutes; from hour 2, 2-3, pulses to 5 at rung 3; never 30 minutes at nought while at
war; never above 6 a row from one corporation. Levers: kill a lander (20 minutes quiet, then one grudge return);
kill convoys or pads (chest and research stall); kill the column or pod (lost, no refund); take a Grubstake claim
(no pods); don't provoke Serenity; shelling a camp into write-off moves the war, it does not end it.

## C. First
The war chest with reinforcement by rung, with war footing beside it. Scenario `reinforce` on the ladder's setup:
a detachment within 10 minutes of rung 1, garrison above cap, a second raid within 15 minutes of the first, a raze in
each of three 20-minute windows, the chest down by the cost. Variants: starved (exports off: no second detachment),
killed (column destroyed on its route: nothing arrives), grubstake (pod lands with nests on every land route). Then
campaigns 12345 and 777 for 6 hours with the raze-per-row metric, and the nwa visit for the ceiling.
