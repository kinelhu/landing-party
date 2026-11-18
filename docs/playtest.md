# Playtest kit

Mod 0.2.448, rewritten 2026-11-18 for the release playtest (0.3.0). The questions follow a session in the order you meet
things: Synthexis first, then Grubstake, then your own army, and the director's beats once it takes over. Everything
below is checked headless only, apart from what the 2026-11-17 and 2026-11-18 sessions already saw. Chat notices are
off: the world should tell you what happens.

## Start

Close your own game first (Steam allows one copy). Then one of:

    cd ~/Dev/landing-party && scripts/play-visit.sh playtest
    cd ~/Dev/landing-party && LP_WATCH=army.zip scripts/play-visit.sh playtest

    cd ~/Dev/landing-party && LP_WATCH=director.zip scripts/play-visit.sh playtest

The director save (items 5 to 9) is the army save run 13 minutes on headless: Grubstake and Kessler-Hayashi landed 350
and 450 tiles from you (2,000 parts each), the director on from the start, laser turrets and weapon shooting speed 2
researched (chemical science with them), four lasers at the base's edge toward each camp. Its first spree and strike
force come about two minutes after loading: set a beacon to D first. Left alone in the same run, that strike took all 64
labs in under a minute at minute 17, and about 1,250 belts, 290 inserters and 250 poles on its way (Kessler-Hayashi
arriving at a base without chemical science, which it never meets in play: a note for the calibration).

The first opens a fresh copy of deathworld10x (never the real file) with Landing Party as a player would meet it, no
test mod. The second is the same save with an army set up: command bandwidth 1 researched, three barracks fed by
infinity chests, three relays on their own power, a rally beacon and 16 troopers and breachers, about 30 tiles west of
where you stand. Each launch starts from a fresh copy: save under another name to keep progress. The Director setting
is on Steady by default (map settings); Difficulty is Normal.

| When | What arrives | Not to wait |
|---|---|---|
| minutes in (evolution here is past 0.25) | **Synthexis**, at the edge of your pollution; first wave about 10 min later | `/lp biotech`, then `/lp wave [n] [deep]` |
| first chemical science pack (in this save: a minute after loading) | **Grubstake Inc.**: survey party first, lander after | `/lp land grubstake 300` |
| first rocket | **Kessler-Hayashi**, at war from landing | `/lp land serenity 300` |
| 30 minutes after the first landing | **the director** takes over the pacing | `/lp director` opens its panel: any beat on demand |

Useful: `/lp list` (settlements), `/lp fast` (speeds their clocks), `/lp squad [n]` (an army of yours), `/lp cannon`
(your orbital cannons), `/lp help`, `/editor` (watch untouchable).

A plan for two hours: the first hour on your own pacing (Synthexis, Grubstake, your army); Kessler-Hayashi called once
you have radar near your base; then let the director run for an hour without the panel, and use the panel only at the
end to see the beats you missed.

## In the order you meet them

1. **Synthexis's first waves.** A wave goes for what it can reach most cheaply, round cliffs and lakes, and lays no
   trail. Did its targets make sense? An undefended outpost beside a walled base: did it go for the outpost?
2. **Grubstake's survey party and landing.** Its party lands with a map tag; destroy its radar and the tag goes and a
   wreck with a command core lies there at once. Then the lander, its strip camps and its claims, each tagged while it
   stands. Did the tags come and go with what they mark? Did you know what each camp was doing?
3. **Your army.** Barracks, relays and rally beacons (the army save has them). Command bandwidth's research now says how
   many units it allows; the panel at the top says how many you have. Select with the command tool, right-click to
   move, shift + right-click to attack-move; Retire (or ALT + R) twice takes the selection off the field for good.
   Units should fight on an attack-move, not walk past enemies, and the ground around them should stay in sight. Did
   any of it surprise you? Is retiring for good the right cost?
   The squad panel beside a beacon's window, and the hover lines between a beacon and its units: readable? Do the
   buttons move units between beacons as you expect? Lowered with nowhere to go, the surplus holds where it stands.
   The gun buggy: slow heavy shots that burst, the fastest unit you have. Does it read as its own unit beside the tank?
   The battle tank costs an exoskeleton and two energy shields: too dear?
   Roads: lay a concrete road from a beacon toward where attacks come, off the straight line. Does a squad sent out
   take it? Does it look like a choice the squad made, or like it wandered?
4. **A far outpost.** Muster points are gone: an outpost's reserve is its own barracks, fed kit by train. It trains on
   while your bandwidth is full and its finished orders wait inside. When an attack comes there, retire units elsewhere
   and the outpost's waiting units step out. Did that work as a way to reinforce? Was it clear why nothing deployed
   while the bandwidth was full?
5. **A strike force landing** (the director's, from 30 minutes after the first landing). Its pods come down beside its
   target, where your turrets reach least, with a klaxon. With a radar covering where they land, it is told ahead, up
   to 2 minutes with the radar right over the spot and 30 seconds at the edge of its reach. A squad on a beacon set to D
   goes out on the warning, meets the pods and walks back. Did you notice it in time? Did you know what it was after?
   Did the army feel like the answer, or like a formality?
6. **Strike forces built for their target.** They bring what counters your defences there. Did one feel unbeatable?
7. **Power strikes.** A strike at your power or the pumps feeding your boilers is told ahead with its target marked,
   and no other attack on you starts while it is out. Fair, or a gotcha?
8. **The walk home.** A broken or finished force walks back to its camp, through or round your base, and joins its
   garrison (or leaves on its rocket). Could you see it go? Did you chase it?
9. **Lulls and odd beats.** After every beat the factions go quiet for a while; nothing announces it. Did you feel the
   lulls, and use them? Then the odd beats: a mast (a launch jammer by a silo, a blackout mast by your radars), a
   bounty on one of your buildings, a crashed shuttle with guards and a loot box, an export contract, a garrison
   rotation, a supply drop to a camp that has stopped earning (destroy the crate; still earning nothing, the camp
   leaves). Without messages, did you understand each from what you saw (the mast, the map tags, the alert)?
10. **Over the whole session.** The sounds: engines, footsteps, deaths, the pods' klaxon, the landing roar, the siege
    horn, the dome's catch, the orbital strike's build into its first impact; anything too loud, repetitive or out of
    place? The pressure: on railbase_end's visits, steady razed more than no director on four seeds of five; over an
    hour, a rising game with breathing room, or a grind? The manual: anything a chapter says that the game did not do?

## After

Notes into this file under a dated heading, or just tell me. The calibration (difficulty and the levers) comes next,
from what you felt here.

## Notes, 2026-11-17 and 2026-11-18

Sessions on deathworld10x (evolution 0.49 by then), from 0.2.440 to 0.2.453. Items 1 to 3 played; 4 to 10 not reached
(the director takes over 30 minutes after the first landing, and every launch started from a fresh copy).

**1. Synthexis's waves.** Synthexis aimed at the walled cube base, not the undefended mining outpost north of it: the
cost map closed every cell with a cliff piece, and the outpost's one way in passed a cliff's end. Fixed (0.2.441: cliffs
read at 2 tiles, a cell open where one stretch reaches its four sides). The acid spit and the green line laid while a
wave plans its raid "not appropriate ... vanilla biters don't put mud anywhere": removed (0.2.442).

**2. Grubstake.** The survey party's map tag stayed after it was destroyed (0.2.443), and so did a strip camp's, a fallen
camp's supply drop's and a razed claim's (0.2.444). Killing the party showed "no loot" and the tag stayed: both came up to
a minute late; now at once (0.2.445).

**3. Your army.** Played with the army save (`LP_WATCH=army.zip`: three barracks on infinity chests, relays on their own
power, 16 troopers and breachers).
- Bandwidth: "unclear in game how much max pop a level gives". Each level now says its relays and units (0.2.446).
- "Lots of blind fighting interrupting visible fighting": the ground round units went dark in patches; kept in sight now
  (0.2.447, measured in a game window).
- "Units often walk to their doom without firing a shot": an attack-move broke off fights every 10 s; it fights through
  now (0.2.447).
- Muster points let a player stockpile orders and replace a lost army at once; retiring walked units home and handed
  orders back. Muster points removed, retiring loses the units, two presses (0.2.448).
- "My 40 unit army could not clear a 3 nest vanilla biter base": research already scales the army (unsaid; +10% bullet
  damage researched here); infantry now take heavy armour's acid resistance, and each unit names its research (0.2.449).
- Units ignored landers and economic buildings: by design (outposts captured whole; a lander held by its generators).
  Attack-move razes, military then economy then walls; right-click attacks any building; a held lander points to its
  generators on hover (0.2.450). The hull's 160-tile ring "looks weird": removed (0.2.451).
- Capture "feels a little forced": capture and the occupy stance removed; a fallen camp's outposts are ruins (0.2.452).
- Answered: how gates work (your units open your own), how muster points worked, how to deselect (drag over empty
  ground), how to assign idle units to a beacon (automatic within 200 tiles; release hand-ordered ones).

Not yet seen in game: the lander's hover lines (0.2.450). Open: a squad sent from far off plans its path before your
gates near it open and may stop at your own wall; `paved squad` fails on every version.
