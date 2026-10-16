# Rivals: what the player does besides turrets (Fable consult), 2026-10-16

Read-only consult on arc.md's question 2, after the user's decisions (rivals who become enemies; engaging must pay; mid game).

## Frame: one verb per corporation, not three families
DEAL/STEER/STARVE is a taxonomy, and a mid-game player holds one idea per opponent. "Pay to be left alone" is turtling with extra steps unless what is bought is a rival's hostility toward the other. The sharper rule: **each corporation takes one thing turrets do not stand on, and its economy is one thing the player can reach.** Grubstake takes what you are not using; its economy is the road. Serenity takes a direction; its economy is the line. Everything below hangs on those two sentences, and most of what is built already serves them.

## 1. Per corporation

**Grubstake, the thief: it takes what you are not using.** Today it waits for soft targets inside turret reach and finds none on a compact base (0 strips, 0 loot, 0 taps in 3 h). Make it prospect instead: every charted patch within 300 of its camp that has no player drill gets a map tag ("Mineral rights reassigned") and, 10 minutes later, a strip outpost under the pact's biters; a strip drill drains at twice the rate, so ignoring it costs half of the next three patches the player meant to expand to. That is a take no turret ring covers, and it changes "where to expand". Non-turret answers, in the order a player learns them:
- **Stake it** (built as the Claim marker, generalised to a patch): two crystals concede a camp's attention on that ground. Costs components the player got by fighting; wins the patch without a fight.
- **Rob the road**: trucks, haulers, tap lines, buggies drop their bills (built). Add the reason: a strip claim with no hauler home in 20 minutes lapses (tag gone, drills capturable by holding, which is built), and its exports are its level. The player who ambushes the gravel road keeps the steel and keeps the patch.
- **Pay the thief**: a trade post (a player chest) that a Grubstake hauler empties; its value buys minutes of truce on soft targets (no raids, flares, heists), never on prospecting. Physical, no GUI, and the hauler drives through Serenity's claim, so the player's tribute is also Serenity's target.
- Rival to enemy: break its pact (antennas) or burn a camp (grudge); enemy means the ladder (guarded targets, flares, heists, pods). Back: standing down after a quiet hour (built), or a paid truce.

**Serenity, the wall: it takes a direction.** Its cordon (built) walks toward the nearest player building, encloses ground where building provokes, and will gate routes and claim patches it crosses. Turrets protect a point; the arc swallows a sector. Answers:
- **Concede the border**: a border stake freezes the line at its current arc for as long as nothing of the player's stands beyond it and no post is hurt. Costs the sector for the rest of the game; wins quiet without a shot. Accepted only while rival.
- **Bend it**: the bearing follows the nearest building (built), so a relay 90 degrees off re-bears the line; a relay beside Grubstake's camp walks Serenity into Grubstake, and they fight (built). Costs one relay and a step of its time; wins both rivals' loot and a quiet front.
- **Break it**: posts cost parts and drones carry the bill (built); kill posts beyond the garrison leash, cut the convoys that pay for steps, and the line stops where it stands. Each post killed provokes.
- Rival to enemy: damage or encroachment (built, permanent today). Back, partial: a border stake after 30 minutes razing none of its posts gives an armistice: no operations, the claim still provokes. "Never forgets" holds; it can still be bargained with.

## 2. What they take that turrets cannot protect
Grubstake: unused patches (prospecting, new), idle power (tap, built), unguarded chests (heist, built), and the biters as its shield (pact). Serenity: the sector on its bearing, the routes its contact wall gates, patches its arc crosses. Both: development. A turtle lets exports run uncontested, and level 3 is the headquarters with sieges and howitzers. Ignored, the player at hour 6 has fewer patches, a gated rail, a sector closed, and an HQ to assault.

## 3. What engaging pays
Beyond the six technologies: **ground** (a lapsed strip claim or a captured strip outpost returns the patch; a stopped line returns the sector), **loot and components** (built), **development denial, shown** ("Grubstake's expansion delayed 14 minutes" on every hauler lost), and **the rival's war** (two corporations set on each other drop loot for whoever walks over it). The measure is the agent: a turtle policy and an engage policy on the same map for 3 h; engage must end with more patches and production, not just fewer losses.

## 4. Smallest set of systems, and what to prune
1. **Standing as three visible labels** (rival, enemy, truce) on each map tag and in notices, derived from built state (Serenity's provoked flag, Grubstake's rung, standing down, a paid truce). No -100..100 number; it makes the campaign's number redundant.
2. **One stake entity**, two meanings: Grubstake honours it as mineral rights (the marker, generalised), Serenity as a border. The marker's recipe stays; the border costs ordinary items (mid-game players must be able to concede early).
3. **The trade post** for Grubstake only. No contracts GUI; a hired operation against the other is redundant with bending the line.
4. **The corporate map**: claims (built), Serenity's bearing arrow and next arc, Grubstake's prospected patches, stakes and their status, convoy routes once a hauler was seen, and a last-incidents list (who, what, where, why). This is arc.md's readability item; without it, none of the above reads.

Pruned: the claim jumper and the tap as separate operations fold into one heist at rung 2 that takes whichever is exposed (chests, a pole); strips beside player drills become the prospecting fallback; the pact breaker stays (cheap); orbital strike is late and fine. Stronger: the cordon, convoys, bait, the marker.

## 5. First slice, ranked, with tests
1. **Prospecting** (`prospect`, Grubstake camp, three charted patches 150 to 300 out, one drilled): tags on the two undrilled within 10 minutes, strip outposts on both by 20, none on the drilled patch; a marker on one lifts its tag. Visit deathworld10x 3 h: strips > 0 (today 0).
2. **Standing labels and incidents** (`standing`): Serenity rival until encroachment, enemy after; Grubstake rival, enemy at the pact's break, rival after standing down; each change one notice; the list holds the last ten with corporation, kind, gps.
3. **Border stake** (`border`, line at 200 a step a minute): stake at 230, the arc never past 230 in 30 minutes; a relay built at 260 voids it (enemy, the line steps); `post` variant: one post killed, same.
4. **Lapse and road** (`lapse`): strip hauler killed twice; the claim lapses at 20 minutes, its drills captured by holding in 2; the development notice names the minutes.
5. **Trade post** (`tribute`, rung 1): 2,000 iron 100 tiles out, emptied within 5 minutes, no soft-target operation for the bought 20, raids resume after; `serenity` variant: the hauler dies crossing a post's reach, no truce.
6. **Bend** (`bend`): a relay 90 degrees off toward Grubstake's camp; the arc re-bears within two steps; a Serenity-Grubstake fight within 20 minutes.
7. **Turtle versus engage** (`campaign`, two policies, 3 h): engage ends with at least one more patch and 20% more production; turret counts logged. This is the gate for decision 3.
