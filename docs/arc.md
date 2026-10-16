# The player's arc: vision against what is built (draft for discussion, 2026-10-16)

Written after the user asked: "do we have a vision, or just a set of features? Put yourself in the shoes of an
experienced Factorio player who wants a new experience." The frame is `docs/campaign.md` (pillars, phases, four
corporations) and `docs/corporations.md` (identities). This page walks a game hour by hour as a veteran would play it,
marks which features carry each beat, and names the beats nothing carries yet.

## What a veteran comes for
They have solved biters: turret walls, artillery, done. They want an opponent that changes their decisions: where to
expand, what to protect, when to strike, what to give up. The test of the mod: **does the factory look different after
six hours because of them?** A feature earns its place by changing a decision the player makes. One the player never
meets, or meets once and cannot read, is weight.

One line to hold every feature against: *Rival corporations compete with you for the planet. Each has a personality you
learn to read, an economy you can strike, and a way of taking things from you that changes how you build.*

## The arc, beat by beat

| Hour (rough) | What the player sees and feels | The decision it asks | Carried by (built) | Missing |
|---|---|---|---|---|
| 0 to 2: signs | Wreckage 180 tiles from their first radar, parts inside; a radio silence | none yet: curiosity | signs (`phases`) | the signal itself: a radar contact, a scout drone over their mining (campaign phase 0) |
| 2 to 4: survey | A Grubstake survey party on ore far out, a map tag | leave it (they come sooner) or destroy it (a command core, a delay) | survey (`phases`), on ore now | the choice is invisible: nothing tells the player what destroying it buys |
| 4 to 8: Grubstake arrives (chemical science) | A camp on a rich field 300 to 500 out; poles go dark at the edge, an outpost loses its chests, biters come at a guarded spot without having been provoked, a strip camp skims the player's ore | where to put turrets; how far out to build; whether to go and burn the camp | soft raids, strips, the pact, flares, claim jumpers, the power tap, trucks building its outposts | **readability**: the player cannot yet tell why things happen or what Grubstake is after (notices exist, a "who did this" view does not); on a turret-dense base most tricks never fire |
| 6 to 10: learning the thief | The player finds the antenna, breaks the pact, ambushes the trucks, takes components, researches bait and the claim marker | strike its economy or wall the edge | pacifier, crew loot, components, six technologies | **a reason to go out**: the offensive tools are tanks and artillery, as against biters; the player's own army cannot yet take a camp (fought capture) |
| 10 and on: Serenity arrives (first rocket) | An orbital barrage among the nests far out; a clean concrete camp; a line of posts walking toward the base, 30 tiles every 10 minutes; a named warning before it swallows an outpost | give ground, provoke it, or break the line | cordon (slice 1), perimeter warnings, clearances, railgunners, drones | the long wall at contact, gate posts across the player's routes, ore the line takes; **what breaking the line wins** |
| 12 and on: two rivals | Grubstake and Serenity fight each other over the same field; the player profits or gets caught in it | play them off: point one at the other | corporations raid each other (`rivals`) | **leverage** (campaign pillar 4): standing, contracts, a cease-fire bought, an operation hired against the other; the player cannot yet steer the rivalry |
| late: escalation | headquarters, sieges with howitzers, reliefs, the ladder buying capacity | how much of the map to cede; when to end a corporation | headquarters and prizes, the war chest, the ladder | the third and fourth corporations (Lumen, the eye; Concord, the dealer); endless mode |

## Where we are, honestly
- **Strong:** two personalities that read differently (the thief at the edges, the wall that walks); an economy you can
  strike (supply lines, convoys, crews, the war chest); loot that rewards going out; the pressure ladder.
- **Drifted:** the last two days added Grubstake tricks and player technologies faster than anyone has played them. On a
  real deathworld save only the flare fired in three hours. Six tricks and six technologies may be more than a player
  learns.
- **Unbuilt pillars:** leverage (standing, contracts), a world of rivals (four corporations, abstract claims across the
  map), the player's army winning a fight it starts.
- **Not felt:** almost nothing of the last two days has been played.

## What I propose
1. **Play one vertical slice**: two hours on a normal map from chemical science, with the user, the notices and the map
   view as the only aids. Note every moment the player did not understand what happened or why.
2. **Readability before more mechanics**: a corporation's intent shown where the player looks (the map: what it claims,
   what it is after; one notice style; a "last incidents" list naming who did what).
3. **Prune by the slice**: fold Grubstake's tricks that never fire into fewer, more frequent ones; keep the technologies
   that answer a corporation the player has met.
4. **Then the missing pillar that changes most decisions**: leverage (standing and one contract: a bought cease-fire),
   or the player's army taking a camp. Lumen and Concord after, once two rivals play well.

## The essential questions (in order: each constrains the next)
1. **What are the corporations to the player: enemies, rivals, or neighbours?** Enemies make the mod a smarter biter (the
   answer is always more turrets); rivals for the same planet give a strategic layer (they want things, you deny them,
   trade with them, set them on each other). The campaign said rivals ("leverage, not just firepower"); most of what is
   built since treats them as enemies.
2. **What does the player do about each corporation, other than turrets?** At least one non-defensive answer each, and a
   different one: Grubstake perhaps by its supply lines and components, Serenity by breaking or outflanking its line.
3. **Does engaging pay better than turtling?** If walling up is optimal the corporations are a tax on the factory. On
   deathworld10x the best play was probably to sit behind 205 turrets.
4. **Can the player read what is happening and why?** Half the raids turn back unseen; the tap is silent by design; the
   reasons live in our trace logs.
5. **Does it hold across games** (a compact deathworld, a sprawling megabase, an early base)? Grubstake's thieving never
   fired on deathworld: a failure of identity, not of balance.
Less urgent: how many corporations (two that play well beat four that do not), the end state (it follows from 1).

## Decisions (the user, 2026-10-16)
1. **Rivals**, who can become enemies and often do. We lost sight of this; the tactical depth built meanwhile stays.
   There must be incentives not to solve everything with stacked turrets, and the enemy side must stay compelling and
   force varied defences, at least until very late.
2. **The non-turret answer per corporation: open** (no answer yet; to be argued).
3. **Engaging must pay better than turtling.** The faction technologies were the user's first, partial answer.
4. **Readability matters**, as stated.
5. **Not built for megabases.** At megabase production every enemy is insignificant; the target is the mid game (from
   chemical science to the first rockets and the planets after). Megabase saves (nwa, nw) stay as a check that nothing
   breaks there, not as a design target.

## The plan (the user took it, 2026-10-16; Fable: `docs/reviews/2026-10-16-rivals-consult.md`)
Each corporation takes one thing turrets do not stand on, and its economy is one thing the player can reach. Grubstake
takes what you are not using (prospecting: undrilled patches near its camp, tagged, then claimed; answers: stake it, rob
its road, pay it at a trade post); its economy is the road. Serenity takes a direction (the cordon's sector; answers:
concede a border, bend the line with a relay, break its posts and convoys); its economy is the line. New systems, the
fewest: standing as three labels (rival, enemy, truce), one stake entity (mineral rights to Grubstake, a border to
Serenity), Grubstake's trade post, and the corporate map with a last-incidents list. The claim jumper and the tap fold
into one heist. Slices: prospecting, standing and incidents, border stake, lapse and the road, trade post, bend, and the
gate: a scripted player that engages ends with more patches and production than one that turtles. Prospecting paced:
one patch at a time, the nearest to the camp first (tagging everything undrilled at chemical science would be harsh).
- Standing (the user, 2026-10-16): even a tolerant rival does not accept the player's turrets within firing range of its
  ground: that is aggression, and makes it an enemy. (Grubstake enclaves can end up inside the player's walls, where the
  player left ore undrilled; a rival tolerated there becomes an enemy the moment a turret covers it.)
