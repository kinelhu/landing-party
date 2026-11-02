# Grubstake's late role: a design consult (Fable, read-only, 2026-11-02)

Read: `DESIGN.md` (the fortress skim, the megabase exposure pass, the 0.2.147 and 0.2.148 re-measures),
`docs/corporations-brief.md`, `docs/corporations.md`, `shared.lua` (CORPS.grubstake), `ops.lua`, `intel.lua`, `faction.lua`,
`prowl.lua`, `prospect.lua`, `pact.lua`, `jumper.lua`, `tap.lua`, `skim.lua`, `strip.lua`, `trade.lua`, `rd.lua`, and the traces
of the fed visits `docs/sim/visit-nwa-rich-offore60`, `visit-nwa-rich-m147`, `visit-nw-rich-ore1`. Nothing run, nothing edited.

## 1. What Grubstake can and cannot do against a megabase

**It is rich, armed and blind, and nothing it knows how to steal is within its reach.** On nwa its camp ended with 46 in
the garrison and 5,315 parts in its research fund, saving for a fifth level of hand-loads, having done 2 operations, both
aborted, and lost 19 units, 18 to lasers (`visit-nwa-rich-offore60/results.txt`). On m147, five camps held 26 to 55 units
each, lost 124, razed 4 buildings. The money and the men are there. Four things keep them at home, in order of weight:

- *Where it lands.* A landing keeps past the player's artillery reach plus 20 (`faction.lua:199`; nwa's reach is 560), 150
  clear of any factory building (`faction.lua:223`), 200 from other landers. The thief's squat at 60 from turrets
  (`faction.lua:209`) never decides anything once artillery does. Its lander came down at 75,-1121 and the nearest thing it
  knew of stood at 160,-448: 675 tiles.
- *How far each heist reaches.* Every theft is measured from the camp's depot or lander (`skim.lua:32`, `home_of`). The tap
  wants a pole within 160 of its nearest pylon (`tap.lua:27`): "24 exposed poles known, 0 in reach". The skim looks out
  to 500 (`skim.lua:20`) and wants a straight line that passes no firing turret by 30 (`skim.lua:183-193`): on nw, "300
  exposed belts carrying in reach ... every line to them crosses a turret's reach"; on nwa, "0 belts looked at". A strip
  needs a player's drill in its intel and a site 31 clear of turrets (`strip.lua:43,82`): "0 of the player's drills
  known". The claim jumper wants a chest target 40 to 60 tiles out (`jumper.lua:24`) and waits for rung 2. Only
  prospecting reaches 700 (`prospect.lua:17`), and it worked: the coal claim at -304,-560 stood.
- *What it sees.* Its intel is the lander's 300 and depots' 150 (`ops.lua:29`), the survey along the line to spawn
  (`intel.lua:249`) and what its units see in the field. It knew twelve targets on a base of 2,302 lasers, all big poles and
  substations on the one edge facing it. The prowl, built as its eye (`prowl.lua:1-9`), sent a buggy twice and lost it at
  point 2 of 10 both times, "42 cells known, 42 before": the eye died before it saw anything new.
- *What soft means at research.* Exposure sums every firing turret whose reach covers the target, each laser worth 1.5
  times (1 + damage research) times (1 + speed research) (`intel.lua:93-96`). Poles on nwa read 458 to 566; the cap is 1.0,
  3.0 from the first rung (`ops.lua:345,438`). Only rung 3 lifts it, and then the raid looks: "needs 189, has 5: turns
  back" (`ops.lua:1530-1534`), or the router finds the target enclosed, "no way round" (`ops.lua:1287`). Both are right.
  Wrecking a laser wall is not its job.

**Nothing in it reads another faction's war.** `ops.loot_wreck` (`ops.lua:1059`) loots containers its own raid broke;
`rd.salvage` (`rd.lua:124`) pays for buildings its own raid destroyed. When Synthexis broke nw at minute 190 and left
thousands of wrecks, 5,500 ghosts and dark roboports, Grubstake had no verb for it. Its truce with Synthexis and its pact
with the biters make it the one force that can walk into a breach while the biters are still in it. That is the asset the
late game leaves unused.

## 2. A late role that fits: the salvage company at the fringe

The identity holds as built: a thief does not breach a bank. Its late growth should be in sight and reach, never in
force; a Grubstake that fields something a laser wall respects is a second Kessler-Hayashi. Weighing the candidates:

- **Scavenging wrecks and breaches (first).** Synthexis makes windows: a power cut darkens lasers, and a dark laser
  already weighs nothing (`threat.firing`, `intel.lua:92`); a wave leaves wrecks, ghosts and chests with no turret left
  firing. The mechanic: a wreck ledger per 32-tile cell of the player's buildings killed by another force, fading over an
  hour; a salvage run (a truck and four hands, the jumper's crew) to the richest cell with no firing turret within 30, by
  the heist's route. There it empties what chests stand, picks items off the ground, and pulls ghosts: a ghost taken is a
  rebuild stolen (robots will not come; the player places it again), worth the building's `WORTH` into parts and an item
  into the yard. The tell is honest: a Grubstake truck in the breach while the robots burn, ghosts vanishing where no
  robot has been. Counter: robots there first, kill the truck, keep a turret alive. Reads as cheating if it takes anything
  under a firing turret or from a chest nothing broke.
- **Taps and outpost theft at the fringe (second, and the enabler of the first).** The code exists and is sound; the
  reach is wrong. A camp sited beyond artillery cannot reach 160 or 500. A *forward yard* fixes every heist at once: an
  idle camp with a fund sends a truck to found a yard (the skim yard, a pylon, a pacifier; no turret) at the fringe, where
  the prowl or survey saw exposed poles or belts, 30 clear of firing turrets. Nothing in it is a military target
  (`data.lua:66-70`), so artillery leaves it alone; the pact keeps biters off it. Skim, tap, strip and salvage then take the
  yard as `home_of`. Its loot is at the yard, where the player can take it back, as the fortress consult asked.
- **Stirring biters through the pact.** The flare was retired for a stated reason that still holds (two factions
  steering waves). But the yard stirs without steering: its drills pollute at 15 (`shared.lua:100`) and under the pact
  waves skip its ground for the player's nearest polluters (the DESIGN spike: a 200-biter wave on two drills). A yard
  at the fringe is itself the stir. Measure it as a side effect; build no mechanic.
- **Selling stolen goods.** `trade.lua` already sells peace to the player. Fencing loot to Kessler-Hayashi is play the
  player never sees unless it lands as a line in Kessler-Hayashi's siege fund. Cheap, flavourful, last.
- **Fewer, richer camps.** Yes, as section 3; 5,315 idle parts should buy a yard, not a sixth camp.

## 3. Landing cap and cadence

Now: one landing every 90 minutes (`faction.lua:21`), 6 standing at once, 3 a corporation (`faction.lua:23-24`), the
clock going to the corporation with fewer camps standing (`faction.lua:524-548`). Nothing reads whether a camp does
anything. Five idle Grubstake camps are five launches of the same nothing, and each is a target that teaches the player
Grubstake is harmless. Change the reading, not the numbers: a Grubstake camp is *idle* when, over the last third of the
cadence, its ops record shows no operation done, no item home, no claim stood. While one of its camps is idle, the clock
skips Grubstake (`next_corp` passes it over; the slot goes to the other corporation or waits), and the idle camp's fund is
what founds the yard. Early game is untouched: a camp that strips and raids is never idle. Do not lower `MAX_PER_CORP`
by hand; the gate derives it.

## 4. Ranked, buildable changes

1. **The forward yard** (`yard.lua`, behind `debug_tune` or `LP_MIX=yard`): an idle camp with parts over a yard's price
   founds one at the fringe; `home_of` in skim, tap, strip and jumper returns the yard when it stands. *Test:* fed nw and
   nwa, 90 minutes: the per-camp visit line (`grubstake N: ... looted ...`), now `looted 0` everywhere, goes above 0; in
   `decisions.txt` "tap: none (N exposed poles known, 0 in reach" becomes a clamp; skim runs from 0 to 3 or more on nw.
   Scenario `yard`: a belt and an exposed pole 700 tiles from the camp, lasers between; assert a yard stands within 20
   minutes and two skim runs come home in 40. Withdraw if the yard's median life is under 10 minutes on the fed visits.
2. **The salvage run** (`salvage.lua`, the wreck ledger fed from `on_entity_died`): after any breach by another force.
   *Test:* fed nw, 180 minutes (Synthexis broke it at 190 in the five-hour run; confirm the minute first): ghosts
   removed, items home and `rd.salvage` paid, all 0 now, go above 0 within 15 minutes of the breach, with 0 salvage deaths
   to biters (the pact) and 0 under a firing turret (the contract's `SOFT_ONLY` check extended to salvage). Scenario
   `salvage` from the siege lab's lane: a wave breaches the wall, Grubstake's truck follows; count ghosts before and
   after.
3. **The idle gate on landings** (`faction.lua`, `next_corp`): *Test:* fed nwa, 90 minutes with launches: Grubstake camps
   from 5 to 2 or fewer, `units lost` from 124 down, operations done not lower, fund unspent at the end below 5,315. Add
   "idle minutes" and "fund unspent" to the visit's per-corporation line so this is read, not inferred. Scenario
   `launches` keeps its Kessler-Hayashi assertion; add one that Grubstake does not land while its camp is idle.

Also, small and first: the prowl should learn from a death. Its buggy died at the same point twice with nothing gained;
record the killer's position as a turret cell (as `ops.lua:1287` marks an unreachable target exposed) so the next ring
bends round it rather than repeating.

**Risks.** A yard under no gun is a free scouting post; keep it one a camp and let the player's kill of it cost the camp
the yard's price and a 20-minute cooldown. Ghost pulling must never touch a ghost the player placed by hand (read
`ghost.time_to_live` or the death ledger; only ghosts of buildings the ledger saw die). Salvage with Synthexis in the
breach must not pull aggro onto Synthexis's wave or break the truce. None of this touches what works: pact, truce, the
heists' rules, the thieves' hours.
