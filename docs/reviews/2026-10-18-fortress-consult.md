# Serenity against a fortress (Fable, 2026-10-18)

The user, after a visit where Serenity razed nothing in three hours against a laser wall kept by robots (nw), and my
"against a base like that, pressure costs materials rather than buildings": "that's hardly better than a biter mod. Why
shouldn't Serenity be able to do more than that?" I proposed four capabilities (power strike, sieges sized to win, a
robot jammer, strangling) and asked Fable for the reading, the tells, the counters and the order.

## Fable's review (verbatim)

**(1) Reads, tells, counters**

- **Power strike.** Serenity, yes: a plan against a system, not a building. Unfair only if the cut is scripted (power
  vanishes); it must be done by shells and railguns, from the outside, on things the player placed outside. Tell: a
  picket walks the pole line a few minutes before (Serenity's reconnaissance signature), then shells on the chain, then
  the engine's own: the red no-power icon on the turrets, beams gone, the dark stretch on the map. Counter: a second
  feed, accumulators beside the turrets, walls round the chain.
- **Sieges sized to win.** Serenity: it already arrives by hauler and builds an emplacement. Keep escalation physical
  and countable (more mortars in the same emplacement, each one trucked in), never a bigger number on the same mortar,
  or it reads as spawning. Tell: the hauler column, walls going up at range, shells on the roboports. Counter: the
  player's artillery outranges mortars (counter-battery is the fair reply), or a sortie.
- **Robot jammer.** Most at risk of reading as a bug: robots falling from a field with no source looks like a crash.
  Make it an entity in the emplacement (an Aegis emitter: a tall mast, a lamp ring, Fulgora-style arcs that strike
  robots entering the radius, visibly). Finite radius, killable, needs power from the siege. Counter: destroy the mast
  (artillery, a sortie), or roboports placed beyond its reach.
- **Strangling.** The most Serenity of the four and already half built (cordon, gate posts, claims). Tell: the arcs,
  the claim disc, trains stopping at gate posts (the engine alerts). Counter: break the wall, the decoy, or a border
  stake.

**(2) Order**

Change it. Build 2 first: it is the fix for the observed failure (one mortar, 30 shells, nothing razed), and the other
three hang off the emplacement. Then 3, then 1, then 4. Reason: without the jammer, a dark stretch and a razed field
are rebuilt in minutes, and the strike is materials again. The jammer is what turns a robot base from infinite into
finite; it changes the fortress fight most. Strangling changes the game most for everyone else, and it costs least.

**(3) The power strike**

Transmission. A substation chain is a handful of entities feeding hundreds of turrets; a solar field is hundreds of
entities (materials, Grubstake's territory); local poles stand inside laser reach. Find the network behind the turrets
facing the line (`electric_network_id`), walk it outward, take the first stretch of poles beyond turret reach with no
second feed, and shell it from the emplacement. What makes it Serenity: it cuts and then uses the dark minutes (the
Line goes through the dark stretch, the jammer holding the breach), it takes nothing, and it was seen surveying first.
Grubstake sneaks a cable in and sips.

## The calls

Taken as Fable orders it: sieges sized to win (more mortars, each trucked in, aimed at what keeps the wall up), then
the jammer as a mast in the emplacement, then the power strike on transmission, then strangling.
