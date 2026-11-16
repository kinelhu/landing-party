# Playtest kit

Mod 0.2.437 (army items 0.2.436 and 0.2.437), rewritten 2026-11-16 for the release playtest (0.3.0). The last kit was for 0.2.162 (2026-10-31); since,
the director, the sounds and most of the factions' behaviour are new, and none of it has been seen in a game window.
Everything below is checked headless only. Chat notices are off: the world should tell you what happens.

## Start

Close your own game first (Steam allows one copy). Then:

    cd ~/Dev/landing-party && scripts/play-visit.sh playtest

This opens a fresh copy of deathworld10x (never the real file) with Landing Party as a player would meet it, no test
mod. The Director setting is on Steady by default (map settings); Difficulty is Normal.

| When | What arrives | Not to wait |
|---|---|---|
| minutes in (evolution here is past 0.25) | **Synthexis**, at the edge of your pollution; first wave about 10 min later | `/lp biotech`, then `/lp wave [n] [deep]` |
| first chemical science pack | **Grubstake Inc.** (survey party first, lander after) | `/lp land grubstake 300` |
| first rocket | **Kessler-Hayashi**, at war from landing | `/lp land serenity 300` |
| 30 minutes after the first landing | **the director** takes over the pacing | `/lp director` opens its panel: any beat on demand |

Useful: `/lp list` (settlements), `/lp fast` (speeds their clocks), `/lp squad [n]` (an army of yours), `/lp cannon`
(your orbital cannons), `/lp help`, `/editor` (watch untouchable).

A plan for two hours: Synthexis and Grubstake for the first hour on your own pacing; Kessler-Hayashi called once you
have radar near your base; then let the director run for an hour without the panel, and use the panel only at the end
to see the beats you missed.

## The ten

1. **A strike force landing.** Its pods come down beside its target, where your turrets reach least, with a klaxon.
   Did you notice it in time? Did you know what it was after?
2. **Radar's warning and the defend stance.** With a radar covering where the pods land, a strike is told ahead, up to
   2 minutes with the radar right over the spot and 30 seconds at the edge of its reach. Put a squad on a rally beacon
   set to D (`/lp squad 12` beside it): it should go out on the warning, meet the pods and walk back. Did the warning
   give you time? Does the army feel like the answer, or like a formality?
   The squad panel beside the beacon's window and the hover lines between a beacon and its units: readable? Do the
   buttons move units between beacons as you expect?
3. **The walk home.** A broken or finished force walks back to its camp, through or round your base, and joins its
   garrison (or leaves on its rocket). Could you see it go? Did you chase it?
4. **Power strikes.** A strike at your power or the pumps feeding your boilers is told ahead with its target marked,
   and no other attack on you starts while it is out. Fair, or a gotcha?
5. **The lulls.** After every beat the factions go quiet for a while; nothing announces it. Did you feel them? Did you
   use them?
6. **The odd beats.** A mast (a launch jammer by a silo, a blackout mast by your radars), a bounty on one of your
   buildings, a crashed shuttle with guards and a loot box, an export contract, a garrison rotation, a supply drop
   to a camp that has stopped earning (destroy the crate; still earning nothing, the camp leaves). Without messages,
   did you understand each from what you saw (the mast, the map tags, the alert)?
7. **The sounds.** Engines, footsteps, deaths, the pods' klaxon, the landing roar, the siege horn, the dome's catch,
   the orbital strike's build into its first impact. Anything too loud, too repetitive, out of place? Do engines
   stutter? Does the orbital build start from its beginning?
8. **Pressure.** On railbase_end's visits, steady razed more than no director on four seeds of five. Over an hour, did
   it feel like a rising game with breathing room, or a grind?
9. **Strike forces built for their target.** They bring what counters your defences there. Did one feel unbeatable?
10. **The manual.** Anything the Headquarters chapter (or any other) says that the game did not do?

## After

Notes into this file under a dated heading, or just tell me. The calibration (difficulty and the levers) comes next,
from what you felt here.
