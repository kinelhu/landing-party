# Serenity's walled advance (Fable consult), 2026-10-16

Read-only consult. The user: "should Serenity camps grow into ever larger fortified areas?" The moving line today is a disc on the map (`ops.perimeter`: 30 tiles every 10 minutes toward the nearest player structure, stop at structure + 40, 450, another claim). Nothing stands on it.

## Frame
Yes, make it physical, and no, not a ring. A ring is the wrong body for this corporation and the wrong economics: 450 tiles of ring is 2,800 walls and, at the bastion's one turret per six tiles, some 470 lasers, about 10,000 parts standing, mostly facing biters nobody is fighting. Serenity's motto is "Please remain behind the line", and a line has a front. **The line is a cordon of posts on a bearing, walking toward the player; it clears, then posts, then walls only at contact.** The disc stays as the claim (what provokes, where it clears nests, the leash); the cordon is what the claim has actually built, and the claim may not run ahead of it.

## What the player sees
At night, out past their last outpost, a row of lit charcoal posts: a pad of concrete, a short wall, two lasers, a lamp, a pylon, every 60 tiles along an arc that faces them (±60° of the bearing to their nearest structure). Ten minutes later a drone flies out over the dark, a beam, and the next arc is 30 tiles nearer, the old posts left behind as a lane of lights. One step before enclosure the notice names the post and the structure ("has set a line post at [gps]; it will extend its perimeter past your Roboport within ten minutes"). When the leading arc comes within two steps of a player structure the drones fill the gaps between the last posts with wall, 120 tiles of it facing the base: a wall going up 40 tiles from the player's outpost is the asphyxiation moment, and it is the only long wall the corporation ever builds. Grubstake sprawls; Serenity draws a line and holds it.

## What it does to the player
- **Ground**: inside the claim, building provokes (today's encroachment, unchanged). The cordon makes the claim legible: posts are where the line is.
- **Ore**: a patch the leading arc crosses with no player drill on it gets a post and a mining module (the claim mechanic from strips, reused: a permanent recovery site). The line pays for the line. A patch with player drills gets the named warning, then enclosure, then the raids.
- **Routes**: a post where the arc crosses the player's rail, belt or pole line is a gate post: wall across the route, a Serenity gate in it (spike: whether a script-placed gate over a player rail stops their train; if it does, that is the single most Protoss thing in the mod).
- **Counters**: breach (a post is 12 walls and two lasers; artillery or tanks kill it; a drone comes to mend it carrying the bill, and a killed drone drops it); outflank (the bearing follows the nearest structure, so a relay placed 90° off pulls the next arc there: a re-bearing costs Serenity a step and leaves its old posts facing nothing); starve (a step is built from the settlement's parts under the rebuild rules, at war footing units first, so cutting its convoys stops the line where it stands); overextend (beyond claim + 15 the garrison leash leaves a post with its two lasers only: an artillery target).

## Biters
A long wall is biter food; the known limit on `b - rocket` (1,300 to 2,600 buildings lost at home) says so. Rules:
1. No post within 100 (the howitzer's reach) of a living spawner: the step waits for a clearance (`sense_nests` already lists nests in the claim; the barrage covers the landing).
2. A post lost to the enemy force is rebuilt by drone twice an hour; the third loss marks that bearing hostile and the line stops there, parts unspent, until a clearance succeeds; two failed clearances stand the bearing down for good (the standing-down pattern). A post lost to the player is a provocation, not a repair loop.
3. Posts have lamps and lasers, no pollution; they draw only the groups that pass. Walls at contact are built on cleared ground by rule 1.

## Cost, performance, pacing
A post is about 45 parts. Keeping every arc is 120 posts over the walk to 450 (5,500 parts, most of a camp's income); keep the leading arc and one behind, the drones recovering older posts (parts back, a Protoss recall; the lane of lights thins behind the front). Standing cost is then about 30 posts, 1,400 parts, 500 entities; a step nets 200 to 300 parts after recovery, well under a camp's 10-minute income (1,000 to 1,700 parts per 30 minutes measured). The contact wall adds about 370. Pace stays 30 tiles per 10 minutes, with one new rule: the claim radius advances only when 80% of the step's posts stand. The line stops as today (structure + 40, 450, another claim) and now also when it cannot pay or hold a step: starvation and biters are the player's allies by the same code.

## First slice, ranked, with tests
1. **Posts on the arc.** Scenario `cordon` (fast perimeter, a relay 300 out): after each step, posts on that arc within ±60°, 80% standing, claim radius equal to the farthest built arc, every post beyond a yard built by a drone, `crews_stuck == 0`, nothing beyond 450. Pace guard: `pace serenity` within 15% on drills and fabricators (walls excluded).
2. **Breach and mend.** `cordon breach`: three posts killed by player turrets, mended within 3 minutes, the drone's bill dropped when it dies, an operation against the player within 20 fast-minutes.
3. **Biters.** `cordon nests` (deathworld nests 150 out on the bearing): a clearance precedes the step, no post within 100 of a spawner; `LP_MIX=worn` (a post killed three times by script as the enemy force): the bearing stops, parts spent on it zero afterwards.
4. **Contact wall and recovery.** `cordon contact`: the leading arc two steps from the relay, wall between posts, the trailing arc recovered (entities gone, parts credited).
5. **Routes and ore.** `cordon crossing` (a player rail across the arc): a gate post; the train spike first. `cordon ore`: an empty patch on the arc becomes a recovery site.
Then `profile.sh six` under 1 ms with the cordon on.
