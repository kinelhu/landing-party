# Pressure on a megabase (Fable), 2026-10-14

After the fourth visit to the user's late save (corporations survive, never touch the player, provoked or not). The user:
"Do you think that is an acceptable situation?" (no) and "even if they don't punch through, they should at least destroy
some buildings, or else it makes no sense."

The corporations are built to win fights, and a megabase offers none. The fix is not bigger raids: each corporation
needs a way to hurt a player it cannot beat, in character, and a floor that makes it happen on a clock.

## 1. What each corporation does to a player it cannot raid
**Grubstake, "Resources in the right hands."** The player sees its drills on a patch they were about to mine, its buggies
on their rails, a wagon emptied at an outpost station, a notice thanking them. It never comes through the lasers; it goes
where they are not. "Soft" no longer means defence 0 at the target cell but "reachable by a sneak route with at most 1.0
weighted defence over the exposed last 16 tiles". A megabase's interior is covered; its rails, big poles, far substations,
radars and pumpjacks mostly are not. Two operations: **Cut** (3 sappers + 4 buggies: six rail pieces, a signal, a pole;
90 s, then home) and **Wagon heist** (looting extended to cargo wagons within 16 tiles). Drills stay off its list. Rate:
one landing operation per 10 minutes per settlement.

**Serenity, "Please remain behind the line."** The player sees a line on the map that keeps coming, a named warning, then
shells on whatever is past it: walls, turrets, artillery, rails. It does not level factories; it resolves the perimeter.
Instruments: the line, sieges at enclosed structures, late artillery (3). Rate once provoked: a shell landing on a player
structure every 15 minutes while a battery stands; a siege per 20 minutes per settlement where a site exists.

**The guarantee.** The 20-minute floor becomes a ladder per player force, counted from the last player building razed:
20 min, soft threshold relaxed (Grubstake 1.0 -> 3.0; Serenity's player targets weigh triple); 40 min, operations push
through biter country (2); 60 min, cost no object: the cheapest reachable player structure by value/(defence+1) gets what
the garrison has, reserve included, and Serenity fires its battery at it. Resets on any raze. Target: at least one player
building razed per 10 minutes per corporation standing from hour one; no 30-minute window with zero. Measured on the
visit by `razed` per 10-minute timeline row and by kind, plus minutes since the last raze.

## 2. Biter country: push through, escorted
Count the corridor's crossings (spawners within 30 tiles of the straight route, worms within 50). Go round when a route
exists. Otherwise push through if effective value >= 6 and crossings <= 3; above 3, send a Clearing at the nearest nest
first (Serenity's nest raid allowed off its own territory; Grubstake too at the floor; the evolution refund stands).
Escort: 4 units per spawner crossed + 2 per worm, times (1 + evolution), rounded up, from the reserve, research-matched
kind. The escort engages biters; the payload does not. Losses accepted: the whole escort; abort only if the payload drops
below half. The player sees corporation columns burning a corridor through the nests beside their base.

## 3. Serenity's late artillery
Node **Howitzer** (Siege tree, era 4, after Counter-battery, 4,000 parts): inside the settlement's walls, the artillery
turret body at full scale in Serenity's colours, marked on the map, 3,000 health, no hull. Range mirrored from the player
force's artillery_range_modifier each minute, never more: a duel, not a bombardment. One per settlement at level 3, two at
HQ. Salvo of 20 shells, one every 10 s, then a convoy reload (10 minutes, interceptable). Targets in order: player
artillery in reach (a player shell landing within 100 tiles redirects the next salvo), then turrets and walls past the
line, then rails and poles; never production or power. Tame: the line's stop rule bounds where it may shoot; the salvo
cadence; the player's turrets reach it (equal range); a killed howitzer returns after 20 minutes and a convoy. Grubstake
never has artillery.

## 4. Territory
Grubstake claims ahead of the player: every 30 minutes per settlement, the richest unmined patch within 400 tiles of the
factory's 95th-percentile edge, nearest to the player first; a recovery site (strip drills, fence, two fed gun turrets,
a Dozer at era 3) with its map disc and "Claim #17 registered at [gps]. Prior survey data was not found." Ore goes home
by hauler. Serenity contests by denial: a patch inside its line is announced; a player drill placed there is encroachment
and draws a siege or a salvo. Clearing a claim is a fight at the patch, then a Retake.

## 5. Test plan
`visit.sh nwa 180` with an expansion player: every 20 minutes an outpost at the nearest unmined patch beyond its edge (8
drills, 2 lasers at the save's research, a radar, big poles home). Checks: razed >= 18 and no 30-minute window at zero
after hour one; >= 1 line cut an hour; >= 1 Grubstake claim on a patch the expansion later wanted; >= 1 howitzer salvo
hitting >= 5 structures and >= 1 counter-battery exchange; >= 3 escorted crossings, >= half arriving; every razed building
beyond 30 tiles of a laser or hit by a shell (impregnability holds); script <= 3.5 ms a tick. Plain and provoked must
differ.

## 6. Build order
1. The ladder and the per-window raze metric. 2. Escorted crossings and the Clearing. 3. Grubstake's Cut and wagon heist.
4. Claims ahead of the player; the expansion visit. 5. The Howitzer. 6. Notices and map marks.
