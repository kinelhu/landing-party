# The third corporation: biotech (design brief, 2026-10-21; nothing built)

Chosen over the other candidates (`docs/third-corporation.md`; consults in `docs/reviews/2026-10-21-*-consult.md`) by the
user, who reshaped it: "Biotech could make sense if we remove the flares from Grubstake ... It could send mega biter
waves in a semi-intelligent way, which biters don't actually do." Name open (the consult proposed Verdant Organic
Solutions); internal id to be chosen with it.

## Decided (the user, 2026-10-21)

- **Grubstake's flares are retired.** The pheromone-flare heist (`scripts/flare.lua`) goes; biter waves become the
  biotech's alone. Grubstake keeps everything else, its pact with the wild biters included.
- **Waves with intent.** Its army is bred biters, and what it adds is what biters cannot do: scout, probe, feint, split,
  go for power, ammunition and the defence's supply rather than the nearest wall. Mega waves, but aimed.
- **It lives in nests, not on ore.** It lands on existing biter nests and grows them (Space Age's captive biter spawner
  is the look of a nest it holds). No third claimant on the ore patches; its camps sit where the other two do not.
- **At peace with the wild biters.** They leave it alone and it leaves them alone: no balancing of biters against it.
- **Neutral with Grubstake at first.** It grows on Grubstake's pollution. Grubstake keeps its immunity to wild biters (it
  depends on it: its convoys and claims run through biter country); the biotech can turn on Grubstake in some cases,
  with its own bred herds only, never the wild ones. Triggers to design so the break reads as cause and effect:
  Grubstake's claims or strip mines reaching its pens, a Grubstake raid on its stock, a breed short of food when the
  pollution it lives on dries up.
- **New breeds.** Acid first; lightning breeds; attacks drawn with the demolisher's fire effects; late, stompers bred
  for Nauvis. Space Age is a dependency, so every sprite and effect it has is available.
- **Attribution.** A wave must never be mistaken for a wild one: its tint on every bred biter, a visible herd leader with
  each wave, trails from its pens, map labels naming the farm it came from. Kessler-Hayashi's pollution invoice must not
  bill the player for a wave the biotech sent.

## Follows from it

- Kessler-Hayashi clears nests; the biotech's nests are its farms. Their war comes for free.
- The player's pheromone bait (research from a Grubstake gland today) moves to the biotech's loot.
- Its unit class is new in the arena's web: regeneration, acid, no flat armour, cannot shoot up. Splash, fire and air
  beat it; small arms lose long fights to it.

## Open

- Name, palette, logo, voice (the identity kit, `docs/corporations.md`).
- What the waves' intelligence is: **consulted 2026-10-22** (`docs/reviews/2026-10-22-wave-intelligence-consult.md`),
  direction taken below ("Waves with intent: the pack").
- What it does on a map with few or no nests (bring seed nests?).
- What it wants from the player besides room: a trade with it? Pay to be spared, or nothing?
- Performance of mega waves.

## First steps (engine tests and a trial, before any design commitment)

1. Its own force at peace with the wild biters (cease-fire both ways), spawners it holds producing units on its force,
   a captive spawner's look. **Done 2026-10-22, below.**
2. One coordinated wave against the player's lines, compared with the same biters as a plain wave. **Done 2026-10-22,
   below** (a spike of its own rather than the arena: the arena fights armies, this needed a base).
3. The arena's bred-biter rows: does it cluster as its own group (`docs/arena.md`)? Not yet.

## Engine tests (2026-10-22, throwaway spikes, deleted)

**Peace, pens, capture** (a force `lp-bt` at cease-fire both ways with `enemy`; a wild nest of 2 spawners and 10 biters
30 tiles from a pen; a Grubstake-like force also at peace with `enemy`; 21,000 ticks):
- No damage either way between the wild biters and the biotech's, all run long, including its herd marching past and
  through the wild nest twice.
- Its herd sent at the Grubstake-like camp destroyed it; no wild biter joined in on either side. Grubstake's pact and the
  biotech's herds coexist with plain force relations: nothing to script.
- A pen (a `unit-spawner` copy whose graphics are Space Age's captive spawner) spawns on the biotech's force, choosing
  units by **the biotech force's own evolution**, not the wild biters' (`set_evolution_factor(0.9)` on its force: big
  ones only, while the wild nest at 0.3 bred small and medium). Spawning stops at the spawner's owned-unit cap and
  resumes once a herd is taken from it (`add_member` releases them).
- **A wild spawner given to its force (`entity.force = ...`) breeds for it, but keeps the wild look and breeds wild
  biters** (vanilla colours, its result_units). Holding a nest therefore means replacing the spawner with a pen in place;
  the nests around it can stay wild.
- The look (screenshots sent 2026-10-22): the pen reads at a glance as a nest that is held (the captive spawner's tanks
  and pipes on a biter mound). Bred biters retinted on their mask layers (green body, yellow bands) read apart from wild
  ones even at zoom 1. A first answer to attribution, before leaders, trails and labels.
- One run's herd never reached its target; that map had no fixed seed (terrain differs per run), the cause was not
  confirmed. Reruns with the same setup reached it.

**A coordinated wave against a plain one** (two identical bases side by side: a wall ring of radius 40, turrets heavy on
the side facing the herd (4 lasers, 3 gun turrets), 2 on each flank, 1 laser at the back, every laser on one central
power source; 40 bred medium biters each; flat map, no water or trees):
- **Plain** (the near side, then everything around, as a vanilla attack group does): all 40 dead within 40 seconds of
  arriving, for 2 gun turrets, 1 laser and 5 wall segments. The power was untouched.
- **Coordinated**: one biter of the 40 scouts a loop 29 tiles outside the turrets (beyond laser range), noting the
  turrets it sees within 40 tiles (east 1, north 2, south 2, west 7); the herd then marches round, out of range, to the
  side it saw least of, breaks two wall segments, and goes for the power with no distraction. **The power fell 36 seconds
  after launch, for 4 biters lost** (with 5 substations and 3 assemblers): every laser went dark.
- What it took (two failed tries): breaching with `attack_area` chewed 21 wall segments for 25 seconds and the herd was
  then drawn to the heavy side by damage and died there; the scout's loop at the edge of its sight saw nothing on the
  west and sent the herd into the heavy wall. Narrow breach (attack two named walls) and `distraction = none` to the
  target were what worked.
- After the power, the herd stood idle in the south gun turret's range (guns need no power) and bled out: what a
  wave does after its strike (sweep, withdraw, hold) is design still to do.

So the intelligence is cheap to script (compound commands, a scout's sight read every half second) and is worth an army:
the same 40 biters went from a failed wave to a dead base. That is the fairness problem to design: the tell must come
before the strike (the scout circling at 29 tiles, in the biotech's colour, is the obvious one), and a player with
turrets all round or a second power source must be able to read and beat it.

**Fairness: what beats it** (2026-10-22, same spike; now fair on intel: the herd is not told where the power is, it finds
power by sight (40 tiles) once 15 tiles inside the wall, and a scout that does not finish its loop means a blind attack,
the plain wave's; every base keeps 7 lasers and 5 gun turrets; 40 biters):

| The player's base | Plain wave | Coordinated wave |
|---|---|---|
| Lopsided, one power source in the middle | all dead; power up | power down 38 s after launch; 21 of 40 left |
| Turrets spread evenly, one power source in the middle | all dead; power up | power down; 11 left |
| Lopsided, a second power source under the heavy side's guns | all dead | one source killed, none else in sight; swept, all dead; **power up** |
| Lopsided, the one power source under the heavy side's guns | all dead | none in sight inside; swept, 24 lost; **power up** |
| Lopsided, one gun turret outside the wall on the scout's loop | all dead | the scout got through; power down |
| Lopsided, two gun turrets there (the scout killed) | all dead | **blind attack: all dead**, 4 wall segments |
| Even, second source, one outer turret | all dead | one source killed; all dead; **power up** |

- Spreading turrets evenly does not help: the herd takes any side, and the power in the middle was beyond every
  turret's reach (a ring of turrets at radius 37 with range 24 leaves the middle uncovered).
- What beats it: **power under the guns** (it cannot see it from where it breaks in, or must fight under fire to reach
  it), **a second power source**, or **killing the scout** before its loop is done. All three are things a player can see
  and do, and the scout is the tell that says which to do.
- The numbers that set its strength, as levers: the herd's sight inside (40), how deep it goes before looking (15), the
  scout's loop (29 tiles outside the turrets, beyond laser range) and whether a half loop is enough to act on (here: no).

## Waves with intent: the pack (direction taken 2026-10-22 from the consult)

The trial's wave was, read as a player would, the other two's signature moves done by biters: round to the quiet side
and a narrow breach is Grubstake's sneak raid (`routing.lua`, `breach_point`), going for the power is Kessler-Hayashi's
power strike (`power.lua`, scenario `blackout`), and "a second power source" is already the blackout's counter. The trial
stays as the skeleton; the identity is a pack, three habits the player can watch:
- **It looks first, with one animal.** The tracker: a tinted biter with a leader icon and a map marker walks a loop
  outside turret reach, stopping at each face, then sits at the face it chose: the mark. Killed before the mark, the
  wave comes blind (every tier). A dead scout teaches a wider loop on that bearing, never a second scout.
- **It leaves, and comes back the same way.** Withdraw on the kill, after 90 s inside, or at half lost; never hold. The
  trail (dirt tiles from the pen's gate to the mark, never inside the player's wall) stays 20 minutes, and the next
  wave's scout checks the old breach first: its memory, on the ground.
- **It spends animals to learn** (tier 2): a probe of a handful thrown at one face, to see which turrets fire; the herd
  goes where one did not (dark, dry or out of reach).
- The target inside is "what feeds the guns", the first it sees: generator or substation, the inserter or belt feeding
  gun turrets, the pipe feeding flamethrowers. The counter is a base shape (the feed under the guns, a second feed,
  nothing dry or dark), not the blackout's one answer. Labs are not a target.
- Mega waves are an event at the top tier (several pens full at once, a clock on each), not the default: waves of 20 to
  60 otherwise. Kessler-Hayashi's siege columns in the open are prey; no joint strike with anyone is scripted.
- Tell to strike 3 to 6 minutes: the pen crowding at its gate, the tracker's loop (60 to 120 s), a minute's gathering.

**First slice: built 0.1.51** (2026-10-22), below.

## The first slice, built (0.1.51, 2026-10-22)

Engine spikes first (a throwaway mod, deleted): a group of 40 bred biters walked a 360-tile route of five waypoints
whole (no strays, none lost, 30 s); a `stop` with `ticks_to_wait` inside a compound command holds a unit and the chain
goes on; a turret is the `cause` of its hits, a laser's included (the beam is the `source`); mud decals can be laid by
script. The map side needed no spike: the mod already draws on the map with `render_mode = "chart"` (`chart.lua`,
`map.lua`), so the trail on the map and the scout's marker are chart drawings, not tiles.

What is built (`landing-party/biotech.lua`, `scripts/herd.lua`; force `lp-biotech`, `shared.BIOTECH`):
- **Breeds and the pen.** Bred small, medium, big and behemoth biters (mask layers retinted, map dots in its green); the
  pen, a biter spawner drawn as the captive spawner, breeding them by the biotech force's evolution (set from the wild
  biters' on each surface it holds pens on, for now), up to 40.
- **Its force.** At peace both ways with the wild biters and with Grubstake; at war with the rest. `shared.is_corp` now
  names the two corporations' forces exactly (it was any `lp-` force), and `shared.is_biters` (wild or bred) takes the
  biotech's force out of every place that looked for "the player" as whatever was not biters, a corporation or neutral
  (captures, intel, occupied ground, the Tesla, the jammer, grudges, provocation, the scorecards).
- **A wave** when a pen holds 24 or more, at the nearest of the player's guns and machines within 500 tiles:
  1. The tracker: the bred biter nearest the base walks a box 29 tiles outside the box of the player's turrets near the
     target (sixteen points, pausing 10 s at four), the biotech's egg icon over it and on the map, noting the turrets it
     sees within 40. Then it sits at the face (of eight) where it saw fewest. A loop that is not whole (the scout killed
     or stopped) is no report: the wave comes blind, a plain wave, and the next loop round that base goes 10 wider; a
     dead scout leaves a skull on the map.
  2. The trail: mud decals every two tiles from the pen round the loop to the mark (never on a mineable floor or water),
     and a dashed green line on the map; both gone after 20 minutes.
  3. The herd gathers at the pen's gate for 90 s, then walks the trail fighting nothing, a leader's icon over it.
  4. The breach: the two wall pieces where the line from the mark to the middle meets the wall; through, 15 tiles in.
  5. What feeds the guns, seen from its lead biter (the one deepest in): power sources, inserters dropping into gun
     turrets, pipes at flamethrowers, nearest first, passing over any with three or more turrets within 24 tiles of it;
     seeing none, it pushes on to the middle once and looks again.
  6. Home: when nothing in sight feeds a gun, after 90 s inside, or at half lost, back out of the breach and up its
     trail, fighting nothing. Survivors are the pen's stock for the next wave.
- Tests and tools: remote `herd_capture`, `herd_fill`, `herd_wave`, `herd_state`; `debug_tune{herd_off = true}`.
  The biotech does not land yet: no game makes a pen on its own (the next slice: its arrival on a nest).

What the runs taught (each a fix now in the code, the run named in its comment):
- A circle round the turrets' average missed a lopsided base's heavy face (the loop was sized by the far back turret,
  its front 55 to 67 tiles off, past the scout's sight): the loop is a box round the turrets' box.
- A herd forty wide walking the loop spills into turret reach; fighting back there (distraction by damage) drew it on to
  the faces it was going round, ten turrets taken and the herd dead before its mark; going home the same way did the
  same. It marches and withdraws fighting nothing.
- In at a corner of a 74-tile base, the power in the middle stood 43, then 40.5 tiles from its lead: past its sight. It
  pushes on to the middle once before giving up.
- Forty bred took a second power source under four lasers and three gun turrets for eleven of them: under the guns was
  not a counter. It now passes over a target with three or more turrets within 24 tiles: the inner keep.
- Turrets on the scout's loop only widened the loop (it goes round every turret it sees). The answer to the scout has to
  move: troopers outside the wall stopped it. A half loop read unseen faces as empty and sent the herd to one it had not
  seen; a loop that is not whole is now a blind wave.
- A unit in a chunk not generated yet cannot path: every move fails at once (the test's pen 430 tiles out). A real pen
  stands on a nest, in generated ground; the test generates its ground first.

The `herd` scenario (`tests/lp-sim`, eight variants, seed 12345; a base 250 tiles from spawn: a wall ring of radius 40,
7 lasers and 5 gun turrets heavy toward the pen, power in the middle; a pen 180 tiles out, 40 bred medium biters):

| Variant | What happened |
|---|---|
| default | mark (the SW corner, no turret seen there) 86 s after launch, march 176 s, breach 204 s, power dead 218 s; 31 of 41 home; the trail there 15 minutes on (195 decals), none inside the wall, gone at 21 |
| keep: the power under the front's guns | passed over (guarded); power up; 32 of 41 home |
| second: a second source under the front's guns | the middle one killed, the guarded one spared; lasers lit; 18 of 41 home |
| scout: seven troopers outside the wall on the loop | the scout stopped, a blind wave, all 41 dead; the next wave's loop 39 (10 wider), and it saw 9 turrets of 12 from there |
| belt: twelve gun turrets fed by burner inserters, no power | four inserters killed, 11 of 12 guns standing; 17 of 41 home |
| wild: a wild nest 50 tiles off the trail | no wild biter joined, no damage either way, the nest untouched; power dead, 32 of 41 home |
| blind: its biters' sight 0 (the control) | marched to the nearest face (the heavy one), found nothing; power up; 13 of 41 home |
| mega: 200 bred | power dead; 187 of 200 home. Its cost per tick not measured: the run's average covers 30 minutes and ran beside seven others |

## In the arena (0.1.52, 2026-10-22)

The stock breeds in the matrix (`docs/arena.md`), priced provisionally in `shared.BREEDS` (a pen spends time, not parts):
bred medium 6 parts, bred big 28, against a rifleman's 10. None of them shoots up now (`air.lua`, as the corporations'
ground-only units: a bite aimed at a flier hits nothing and the biter is turned to a ground target, `aim.lua`).
- Bred big at 20 beat nearly everything, splash included; at 40 it lost to nearly everything (Lanchester again); at 28
  it loses to every splash kind (shock -87, prism -79, tesla -75, sapper -64, breacher -40), the railgunner, air, the
  flamers and the rocket trooper, and beats most armour (walker +93, tank +58, dozer +37, battle tank +16).
- As a class: bred against small arms +40, splash -60, armour +45, air -100. A loop with the others: armour beats splash,
  splash beats the breeds, the breeds beat armour (a swarm round slow hulls), and air beats all that cannot shoot up.
  The railgunner, the biter specialist, has its clearest wins here (bred medium and big, -100 both).
- The clustering does not give it a group of its own: the main split stays "can shoot up or not", and the breeds sit
  with the ground-only kinds (with Grubstake's shotgun hands, the other swarm, when cut finer). Air at +100 against it is
  the open question for the breeds consult.

## The breeds consult, and what was taken (2026-10-22, 0.1.53)

Fable's consult (`docs/reviews/2026-10-22-biotech-breeds-consult.md`) read the first arena run (bred big at 20) and found
the stock a copy of Grubstake's swarm with an armour-killing bite (it clustered with the Shotgun hands; bred against
armour +71). Taken:
- **A bite is not a bullet.** The breeds bite with `lp-bite`, which armoured hulls resist 60% (every corporation's tank,
  aegis, dozer, Scorcher, Prism, Tesla; the player's battle tank; the base game's tank), the walker and the spidertron
  40%; infantry, walls and turrets nothing. A tank drives through a herd, and the expedition to a farm has its tool.
- **Regeneration is the pen's**, not the animal's: survivors walk home and the pen refills; vanilla heal rates stay.
- Prices measured again with the bite: bred medium 7 (at 6 it still beat tanks +54 by numbers; at 8 it lost to
  Kessler-Hayashi's riflemen -58), bred big 28. Class row: small arms +48, splash -69, armour -5, air -100. Bred big
  loses to the tank -71, aegis -73, battle tank -86, every splash kind and air; bred medium beats every small-arms kind
  (+10 to +98), is even with the tank (+4) and loses to the aegis, battle tank, dozer, splash, air and the railgunner.
  Still odd, for its own pass: the Scorcher (a flamer hull) loses to both breeds.

The direction, to build in order (the consult's sections 3 to 8):
- **Roster by tier.** 0: the stock (bred medium), the tracker, bred worms by the pens (two a pen; the only thing of its
  that shoots up). 1: the spitter (acid, its answer to armour; puddles cover the withdrawal; outranged by rifles and
  lances) and the big as the front rank. 2: the runt (bred small) as the probe's body. 3: the cinder (a big biter with
  ember bands that dies into the demolisher's fissure, force-filtered: the one to shoot first and at range). 4: the
  stomper over the wall; the behemoth only as the mega wave's weight.
- **Not built:** a lightning breed (electric is Kessler-Hayashi's track: Optics, Shock, Tesla, the jammer; at most a
  death discharge), spreading fire, wrigglers, big spitters.
- **The scout a different animal:** a bred small strafer (unarmed, its strafing AI off, lit at night), after three
  spikes (a compound command with stops on a spider-unit; spider-units in a unit group; a stomper's steps on its own
  herd). Fallback: a bred spitter.
- **Home:** three to five pens on a nest field with worms, the wild nests round them as a hedge, the gate's stock as the
  garrison (it does not withdraw at home); a pen attacked recalls its wave down the trail, so a raid on the farm is a
  counter to a wave on its way and the fight happens in the open; the expedition goes by rail with artillery.
- **Air** is the counter in the field (only Grubstake fields fliers, and only once it breaks with the biotech); at
  home, the worms.

## Its arrival (0.1.54, 2026-10-22)

`scripts/farm.lua`. Decided without the user (it gave the lead): the farm lands far out, so that hunting it along its
trails is the answer to it.
- **When:** once the wild biters' evolution on a surface reaches 0.25 (mediums to breed). Not tied to the corporations'
  clocks.
- **Where:** the nearest nest field (three spawners within 40 tiles) with none of the player's buildings within 600
  tiles and some within 1,000 (then 1,500), not within 200 of a corporation's camp. No field, no biotech (looked at
  again every 10 minutes).
- **What lands:** its cargo pod; up to four of the field's spawners become pens, each with 6 bred and two bred worms; the
  rest of the field stays wild round it. The farm is charted for the player with a map tag ("Biotech farm", the egg
  icon); its first landing is told in chat once, as a corporation's first landing is.
- **Its waves:** one at a time, the first 10 minutes after landing, then 20 minutes apart at the least; from its pens'
  stock but six a pen kept at the gate, 24 at the least and 60 at the most, sent from the pen nearest the player's
  nearest guns or machines (searched in rings to 1,600 tiles). Long legs go by waypoints every 100 tiles, moved off
  water; the chunks along the way are asked for as the wave sets out.
- **Hunting it:** a pen hit by anyone at war with it calls its wave home (the fight moves to the trail). Every pen dead:
  the farm is gone, its tag too, and it lands again on another field an hour later.
- `/lp biotech` lands it now; `/lp wave` makes its farm send one now.

The `farm` scenario (seed 12345; the herd scenario's base, a field of five spawners and two worms 750 tiles beyond it on
the map's own ground, the wild evolution at 0.3):

| Variant | What happened |
|---|---|
| default | landed 20 s in, 750 tiles from the base: 4 pens, 8 worms, its tag; the first wave 10 minutes later. Four full pens sent 135 before the cap (now 60): walked the 750 tiles, scouted, broke in at the corner, killed the power; 40 of 60 home |
| raid: a pen hit while the wave marched | the wave turned home with all 60; 39 got back |
| killed: every pen destroyed | the farm and its tag gone; its next landing an hour later |
| wave: `/lp wave`'s call a minute after landing | a wave out 10 s later |

Open from here: the consult's roster (the spitter, the strafer scout after its spikes, the runt's probe, the cinder,
the stomper), its pens growing (more pens over time, the mega wave as an event), Kessler-Hayashi against its pens,
the Grubstake break, evolution from what it eats, the levers (strength and aggression settings), a name, and retiring
Grubstake's flares now that the biotech lands in games.

Earlier list: its arrival (landing on a nest, the pens it grows), the evolution from what it eats, the Grubstake break,
Kessler-Hayashi against its pens, the probe (tier 2), the arena rows for the bred biter, and retiring Grubstake's flares
once the biotech lands in games.

## Synthexis: name, identity consult, creep (2026-10-22)

- **Name: Synthexis** (the user). High-tech bioengineering, not ranchers: names with a farm or old-world ring were
  rejected (Verdant, Fenwick...). Internal id stays `biotech` (force `lp-biotech`).
- **Identity consult:** `docs/reviews/2026-10-22-synthexis-identity-consult.md` (the culture site: cells, substrate,
  clinic, technicians; the feed as weak point; "Synthexis culture N" on the map; "Engineered to adapt."). Taken as the
  outpost's look; biter eggs as loot wait (they hatch in the player's chests: their own test first).
- **Creep (the user, after the consult: "a Zerg creep?"; direction taken):** tumors grow creep and bud new tumors at
  its edge; creep runs from nest to nest and turns the nests it reaches into incubators; incubators and the clinic stand
  only on creep; bred biters are faster and heal on creep, plain off it; tumors killed, the creep recedes and what
  stood on it withers. It grows toward nests, not toward the player (an advancing front is Kessler-Hayashi's).

Creep engine spike (throwaway mod, own profile, deleted). A tile copied from `artificial-yumako-soil`, not mineable,
collision `{ground_tile, object}`:
- **It blocks every building and nothing that moves.** Refused on creep (placed on grass): gun turret, belt, wall,
  pole, rail, land mine, assembler, pipe, chest, lamp, inserter, furnace, spawner, worm, trees. Allowed: underground
  pipe, character, biters, car, tank, spidertron. `create_entity` ignores it (the script still places incubators and
  tumors), and so the vanilla expansion cannot settle wild nests on creep.
- **`set_tiles` with `remove_colliding_entities = false` paints under a standing wall and turret and leaves them;**
  with true it deletes them.
- **The engine keeps no hidden tile under creep** (`get_hidden_tile` nil; the creep is not a foundation): the ground
  beneath has to be recorded (`set_hidden_tile` takes any tile; to check when built).
- **A tile's `walking_speed_modifier` does nothing to units:** 100 tiles took 440 ticks on grass and on creep at 0.5,
  1 and 2 alike (435–445). **A sticker does:** `target_movement_modifier` 1.5 re-applied each second: 315 ticks.
- **A sticker with negative `damage_per_tick` heals** (a medium biter from 20 to its 75 cap within 120 ticks).
- **Cost:** painting 2,500 tiles 1.9 ms in one call, restoring them 1.6 ms, 100 calls of 25 tiles 2.2 ms; a heal pass
  over 300 units (find, tile check, heal 200) 0.4 ms each second.
- **Creep can eat pollution:** `absorptions_per_second` 0.01 per tile: a creeped chunk fell from 1,000 to 88 in 30 s,
  a grass one to 208.
- So the creep bonus is a pass each second over the force's units on creep, giving each a haste and a regen sticker
  (their goo animation blanked).

### Step 1 built (0.1.55): the name, and the flares retired

- Shown as Synthexis: incubators (`lp-pen`), Synthexis biters and worms, the map tag "Synthexis culture" (numbered from
  the second), its first landing "Synthexis has seeded a culture in the nests at ... Engineered to adapt."
  (notice-ok, as a corporation's first landing).
- Grubstake's pheromone flare retired: `flare.lua`, the canister, `/lp flare` and its eight scenarios gone. Grubstake
  answers a loss with a snatch raid only where no turret covers it (scenario `snatch`, two). The biters' call moved into
  the player's bait; the pheromone gland drops from incubators (1–2) and Grubstake's pacifier antennas.

### The build order with creep (2026-10-22, replaces the consult's section 7 from step 2)

2. **Creep and tumors at the culture.** A creep tile (Gleba soil, recoloured; `{ground_tile, object}`: no building on
   it, everything walks it; pollution absorbed). Each incubator is a tumor's first seat; creep grows round it to a
   radius, the ground beneath recorded. Test: creep laid, a player's building refused there, nothing destroyed under it.
3. **Spread nest to nest.** Tumors bud at the creep's edge toward the nearest wild nest; creep reaching a nest makes it
   an incubator. Creep reaches only so far from a living tumor. Test: a second nest 60 tiles off is taken by creep.
4. **The bonus on creep.** A pass each second over Synthexis's units on creep: a haste and a regen sticker. Test: the
   arena on creep against off it.
5. **Recession.** A tumor killed, its creep withdraws tile by tile to the ground recorded; an incubator off creep
   starves (cap falls, then wild again). Test: kill the tumors, the creep gone and the nest wild within minutes.
6. Then the consult's cell (biochamber, lamp), substrate and technicians, clinic, loot, and the Grubstake break.

### Creep built (0.1.56): steps 2 to 5

`scripts/creep.lua`, the tile `lp-creep`, the tumor `lp-tumor`, stickers `lp-creep-haste` and `lp-creep-mend`.
- **Growth.** A tumor by each incubator at landing (and by each one taken later); a ring every 10 s to radius 10. Creep
  never covers water, a floor someone laid (mineable tiles), or a tile under another force's building (it flows round:
  nothing is destroyed). The ground beneath kept as the tile's hidden tile.
- **Spread.** Every 2 minutes at most, once a culture's tumors are grown, it buds a tumor 9 tiles out toward the nearest
  wild nest within 160 of it; creep reaching a nest takes it (an incubator with its own tumor), up to 12 per culture.
  `creep spread`: a nest 65 tiles out taken 13.8 minutes after landing.
- **On creep** Synthexis's units get a haste sticker (×1.3) and, hurt, a mend sticker (6 health a second), renewed
  each second within 200 of a culture. `creep`: a medium at a quarter health back to full in 10 s.
- **Recession.** A tumor dead, its creep withdraws a ring every 5 s to the ground kept, but where a living tumor
  reaches. An incubator off creep for 3 minutes goes wild (a wild spawner in its place, its stock on the enemy force:
  feral, still in Synthexis colours). `creep killed`: every tumor killed: creep 0, five wild spawners, 188 feral, the
  culture gone.
- **Look** (screenshots 2026-10-22): the untinted Gleba soil read as brown mud; tinted violet it is a clear stain on
  Nauvis ground. Tumors: Gleba's small egg raft, green, 1.6x, with an acid-green light at night.
- Not yet: the bonus measured in the arena; creep feeding on pollution (it absorbs three times grass, no growth link);
  the player's way to clear creep other than killing tumors; Kessler-Hayashi's clearances aimed at tumors.

### Biomass (0.1.57)

The user, 2026-10-22: "How are we pricing the biters considering the parts economy doesn't really apply?" Until now the
breeds' costs (small 2, medium 7, big 28, behemoth 60) priced them in the arena only; in a game an incubator bred free
to its cap. Now they are paid in biomass, so the arena's balance holds in the game:
- **Income.** What its creep drinks of the pollution: each creep tile absorbs `shared.CREEP_ABSORB` (0.0005 a second,
  about 28 times grass; the engine's own absorption), counted to the culture whose tumor laid it, up to what is in the
  chunk (`creep.drink`, each 10 s). Plus 3 an incubator a minute whatever the air, and 200 brought by its pod (its
  first wave at ten minutes).
- **Spending.** Each birth (`on_entity_spawned`) pays its breed's price; at nothing left the culture's incubators are
  made inactive (they stop, animation too) until it earns. Never more than one breed's price in debt (lowest seen -7).
- `creep clean` (20 minutes, clean air): 126 bred, 0 drunk, books balanced to 0.00. `creep smog` (3,000 pollution a
  minute poured on it): 767 drunk, 164 bred (its incubators full), 649 banked. `farm`: a wave of 60, as before.
- What follows: a dirty factory feeds Synthexis when its cloud reaches the culture (the user's "it grows on Grubstake's
  pollution" too); cutting creep cuts income. Banked biomass does nothing yet: for the tiers above the trickle (mega
  waves, bigger breeds), and Synthexis's strength lever as a multiplier on income.

### The creep bonus in the arena (2026-10-23)

Two new kinds, the breeds with the creep's haste (×1.3) and mend (6 a second) stickers renewed each second, fought the
whole matrix (`docs/arena.md`, 2,325 fights). Class row, off creep → on creep: small arms +48 → +58, splash -71 → -47,
armour -1 → +8, air -100 → -88; on creep against off it +24. A home advantage, not a fortress: splash and air still
beat it on its own ground, the railgunner still wins every fight against both. Kept as it is.

### The spitter (0.1.58, tier 1)

`lp-bred-medium-spitter`: the vanilla medium spitter in Synthexis colours (50 health, acid at 14), bred from evolution
0.3 (a sixth of births from 0.5, `lp-pen`'s table). Its acid is its answer to armour: no hull resists acid.
- **Ground-only.** Its first trial beat harriers: `air.lua` rewrote projectiles, beams and chains but not streams, so
  the acid reached fliers. Streams are covered now (it is the only stream weapon among the ground-only kinds).
- **Price, by the arena** (`LP_ARENA_ONLY="bred spitter"`): at 6 it beat everything but splash, the railgunner and the
  fixed lines; at 12 it lost to the tank and nearly everything; at 9, kept: it beats the tank, aegis, dozer and
  Scorcher (+100) and the battle tank (+33), loses to the player's troopers, the slug, every splash kind, both fliers
  and the railgunner (-100), is even with Kessler-Hayashi's riflemen (0) and beats Grubstake's (+33). The consult's
  cycle holds where it matters: spitters beat tanks, tanks beat the stock, the stock beats rifles; rifles only draw
  with the spitter, and the lance (anti-armour) loses to it (+100): a lance is a tank-killer, not a bug-killer.
- **In the pack (0.1.59).** Once the herd is inside, its spitters leave it and hold the breach (`attack_area` 10 round
  it): a sally into the herd's back walks into acid. When it withdraws they stay 20 s, then follow as a rearguard group
  down the same trail. Sent home one by one they were overtaken by the end of the test, not stuck (the test now waits
  for the rearguard); as a group they walk it as the herd does. `herd spit` (30 mediums, 10 spitters): 9 held the
  breach, 9 covered, 8 home.

### Synthexis's levers (0.1.59)

Its two settings, as the corporations have (`lp-biotech-strength`, `lp-biotech-aggression`; "Synthexis: ..."):
strength multiplies its biomass income (pod, trickle and what its creep drinks), aggression shortens the gap between
its waves and to its first. `creep strong` (strength 2, clean air): pod 400, trickle 580 in 20 minutes against 290.

### The runt and the probe (0.1.59, tier 2)

`lp-runt`: a bred small biter of its own name (so its hits can be read), spawned by script, never bred (the pens stop
breeding smalls at 0.5). From evolution 0.45, once the scout's mark is chosen, 8 runts walk the trail ahead of the herd
(they leave while it gathers; the walk is the same) and attack the marked face (`attack_area` 14 at the turrets' line).
The herd reads only whether each turret near the face shot at them (`on_entity_damaged` on `lp-runt`, the turret the
cause) and which had a runt within its range (checked each second): a turret in reach that never shot is dry, dark or
broken, and the mark moves to the face in front of the silent turret nearest it. Read when the runts are dead, after 3
minutes, or when the herd reaches the mark, whichever first; kept for this wave only.
- `herd probe`: two lasers in each of the eight sectors, but toward the pen one of the two a gun turret with no
  ammunition: 8 runts, 3 turrets fired, 1 silent; the herd breached 4 tiles from the dry gun (24 from its lit twin).
- The tell is the consult's: "ten green biters threw themselves at my north wall and died" is a clock (the herd is
  about a minute and a half behind) and a pointer (check that face's ammunition and power).
- Their price, 8 runts at 2, is taken off the culture's biomass when a wave is sent at evolution 0.45 or more. Not yet:
  the probe on the scout's return to an old breach.

### The cinder (0.1.59, tier 3)

`lp-bred-cinder`: the bred big biter with ember bands (orange and gold) and an orange light at night (drawn at its
birth, `farm.on_spawned`), bred from evolution 0.6 (a tenth of births from 0.8). It dies into the demolisher's fissure:
the crack, the eruption and the scorchmark (the small demolisher's, copied as `lp-cinder-fissure*`, the light ember).
- **The damage is the death's own.** The demolisher's chain (crack, then a delayed eruption, then delayed damage) drew
  the crack and never dealt damage from a dying unit; the cinder's `dying_trigger_effect` now deals it at once:
  explosion 350 within 4, 200 more within 2, `force = "not-same"` (its own herd and incubators untouched: a cinder
  killed at home cracks nothing of Synthexis's), ground-only (`trigger_target_mask = {"common"}`: the first arena
  trial had it beating harriers by its death). The one-second telegraph is lost.
- `cinder` (a cinder killed at a seven-piece wall, a gun turret 2.5 behind it, a Synthexis medium and an incubator by
  it): 5 wall pieces broken, 2 hurt, the turret at 8 of 400; the medium and the incubator untouched. (A first run read
  "no damage": the test's cinder had walked 5 tiles before it was killed.)
- **Price, by the arena:** at 40 it beat everything but the railgunner and flamers; at 70, kept: it beats massed light
  infantry and the fixed gun and laser lines (+100: breaking defences is its job), and loses to range and fire (the
  railgunner, rocket troopers, flamer lines), to fliers, and to the battle tank, tank and aegis.
- **A baneling (0.2.7).** The user, in the arena: a single burster held off ten troopers. Its big biter's physical 8 flat
  took a rifle's 8 down to 0.45 a shot, 28 s for ten (the arena's new panel shows it). Asked for "a little more fragile
  ... on a small biter body that goes fast ... giving some time to react before they burst in your face": a medium
  biter's body, 120 health, no resistances, speed 0.32 (the fastest breed); it does not bite: in reach it bursts and
  dies of it, the eruption its death's as before. Priced by the arena (154 fights a price): at 25 it beat 31 of 42
  matchups; at 40, kept, 19 wins and 19 losses: it beats rifle troopers (+0.25), infantry, lances and armour
  (slightly), and loses to turret lines (guns -0.64, lasers -0.55), flamers, fliers, the railgunner, sappers and rocket
  troopers. Alone it no longer breaks a line, which is shot before it arrives; it breaks one inside the herd that
  draws the fire.

### The burster, recoloured (0.1.61)

The user, seeing the cinder: "Reminds me of the banelings from SC. Perhaps we should recolor the eruption to be more in
theme?" Shown as **Synthexis burster** (the id stays `lp-bred-cinder`, the fissure `lp-cinder-fissure*`, "Burster
rupture"): violet and acid-green bands, an acid-green light at night, and the crack, eruption and scorchmark tinted acid
green (a multiply tint on the lava art: its yellow cores read green, its orange edges olive), their lights acid green.
Its damage, reach and price unchanged.

### The spore spitter (0.1.63)

Synthexis's answer to fliers (DESIGN "Fliers and anti-air"): `lp-bred-spore`, a violet bred spitter whose spit
(`lp-spore-stream`) bursts where it lands, aloft as well: 30 acid to a flier within 1.5 tiles, 18 to the ground within 1
(3 in 0.1.63; raised in 0.1.64 so it fights the ground a little), no burning pool, range 20, priced 10. Bred from
evolution 0.25 (a twentieth of births from 0.4). The arena: it beats scavengers by about 80 and harriers by 48 to 57 (it
wins every fight and loses half its value), costs a hull 38 to 57 (acid goes through armour), and loses to infantry
by about 90.

### The stomper (0.1.65, tier 4)

Built for the gap the arena's faction table found (DESIGN "Fliers and anti-air", faction metrics): Kessler-Hayashi
answered every breed at +100 and Synthexis answered it at +36, nothing bred beating the railgunner or the hulls.
`lp-bred-stomper`: Space Age's small stomper (a spider-unit), its plates violet (the creep's colour; 0.1.66: tinted
green whole it read as a plastic toy, the user, and of violet, acid yellow and deep green on the plates alone, with the
body's art left as vanilla draws it, the user chose violet), its legs copied
(`lp-bred-stomper-leg`). Bred from evolution 0.8 (one in fifty from 0.95), priced 150.
- **Spike (2026-10-23, deleted):** a small stomper on its own force joined a unit group with six biters (`add_member`
  on a spider-unit works), marched with it, crossed a wall of 21 pieces leaving all 21, and stomped the gun turret behind
  in 4 seconds; the biters were unhurt (its stomp is an area on enemy forces). A pen breeds spider-units as Gleba's
  spawners do; the herd moves what its pens bred as a group, so no herd code changed.
- **Not tagged lp-biter** (data-final-fixes tags units, spawners and worms, not spider-units): the railgunner, made to
  kill biters, does it 10, not 250.
- **Tuned by the arena:** vanilla's (3,500 health, 7 a second healed, 44 a stomp) beat every ground kind at 150, rocket
  troopers and battle tanks too; at 2,000 and half the stomp it still did (22 rocket troopers dead in 7 seconds, the stomp
  landing on all of them at once). Kept: 2,000 health, no healing (regeneration is the pen's), a fifth of the stomp
  (9 impact within 4 tiles a step), ground-only (masked), physical 50% with no flat, laser 40%, nothing against
  explosions; its shell kept where it falls, the premature wrigglers dropped. The arena (3,441 fights): it beats the
  railgunner, the anti-air trooper and the laser tank by 100, laser troopers and the heavy tank; it loses to the battle
  tank, both fliers (100), tanks, shock troopers, lightning tanks, walkers and flamer lines. Rocket troopers and slugs
  still lose to it (+50, +67 for the stomper), where the consult wanted them to win: the battle tank is the player's answer.
- **The faction table after:** Synthexis against Kessler-Hayashi +71 (was +36), coverage 70% (40%), the edge -29 (-64).
- `herd stomp` (36 mediums and 2 stompers at the walled base): a stomper inside the wall ring; no Synthexis unit hurt by
  a stomper. Creep's haste and mend are for units only (`creep.lua` finds type unit): not for the stomper.

### Kessler-Hayashi against its cultures (0.1.60)

Its nests are nests to everyone else: `shared.NEST_FORCES = {"enemy", "lp-biotech"}` in Kessler-Hayashi's nest intel,
its clearances (siting out of worms' reach, the nest's defence, what is in reach, the guards' foes, the nests on its
way) and the routes that go round biter country. Not its pollution billing (`ledger`, the hazard): a Synthexis wave
is not the player's pollution, and Kessler-Hayashi must not bill for it (the brief's attribution rule).
- `clear culture` (one spawner in six an incubator, eight): two clearances, 2 incubators destroyed, its way cleared and
  the assembler razed. Dearer than wild nests: 102 units lost against 43 (an incubator's stock defends it; its
  spitters killed the guards at the site).
- On Factorio 2.1 (0.2.1, 2026-10-23) it fails "the assembler razed": the map shifted a few tiles; the first clearance
  takes the incubator on its way and loses all ten guards to its stock, the wild worms and big biters (41 shells), the
  second kills it at 3 of 10 guards 18 minutes later, the third starts at minute 38. Known, to look at: how
  Kessler-Hayashi sizes a clearance against a stocked incubator.
- A first try made all 45 spawners incubators: full stock and no culture to pay for it (pens outside a culture breed
  free, as a test's do) killed all ten guards and nothing was cleared. A real culture has at most 12.

### The break with Grubstake (0.1.60)

The consult's trigger (a Grubstake skim truck at a biochamber) waits for biochambers; creep gave a legible one now:
land. The truce ends, for good (`herd.break_grubstake`, `storage.herd.grubstake_broken` with its cause), when a
Grubstake building or unit stands within 12 tiles of a tumor (a claim or strip mine on its creep's edge, a convoy across
it) or Grubstake hurts an incubator or a tumor. Then Synthexis's waves may go for Grubstake's camps as for the
player's factory (`target_from`, the nearest of either). The wild biters' pact with Grubstake stands: the herds that
turn are bred ones only.
- `creep break`: a Grubstake rifleman put 7 tiles from a tumor four minutes in: the truce gone within a second (it shot
  an incubator: "Grubstake hit its lp-pen"), both ways; Synthexis still at peace with the wild biters.
- Not yet: a sign of the break in the world (the consult: the truck burning on the pad); its waves at a Grubstake
  camp, tested.

Screenshots (2026-10-23): the breeds on creep by day and night (the cinder reads apart by its bands and, at night, its
light; the spitter's body is lower and longer), and a cinder's death at a wall (crack, eruption, the middle pieces gone).
The bred worm read close to a wild one (its mask, the only tinted layer, is a thin band): its body layers are now
tinted light green as well (not yet seen in a screenshot).

### The culture site: the cell and the feed (0.1.66; the identity consult's steps 2 and 3)

The user, after the stomper: the base next, its identity beyond "a small sprite on the captured nest".
- **The cell** (`scripts/cell.lua`): beside each incubator, 7 tiles out of the culture's middle, a 5x5 pad of
  acid-green refined concrete (the ground under creep kept as its hidden tile; trees, rocks and remains cleared), a
  biochamber at work on it (`lp-biochamber`: Space Age's, no power, no nutrients, a recipe that makes nothing for
  ever, so its animation and light run) and an always-on lamp in acid green (`lp-cell-lamp`). Built when a culture
  lands, when its creep takes a nest, and for old saves' incubators at the farm's next tick. An incubator gone wild or
  dead takes its biochamber and lamp with it; the pad stays, a floor.
- **The feed as the weak point** (`farm.lua`): an incubator whose biochamber is dead is unfed. It breeds nothing (it
  stays inactive whatever the biomass), keeps 12 of its stock (`FED_CAP`; the rest goes feral: released from it, on the
  wild's force, at peace with Synthexis as all wild biters are), and after 10 minutes (`UNFED_WILD`) goes back to the
  wild, a plain spawner. A biochamber hit calls no wave home; an incubator hit does. The quiet kill: raid the feed while
  the herd is out, and it comes home to a dead cell.
- **Tests:** `farm` (default and `killed`): a cell by each incubator (pad, biochamber at work, lamp: 4 of 4), and the
  biochambers gone with the incubators. `farm starve` (30 stock, its biochamber killed a minute on): inactive, 12 kept,
  36 feral; wild 36,600 ticks after (10 minutes and the farm's 10-second tick); the culture lives on. `farm quiet`: a
  biochamber hit during the march, no recall (`farm raid`, an incubator hit, still recalls).
- **Next (the consult's steps 4 to 6):** the substrate (Gleba soil, yumako trees, farm towers, a heating tower) and
  technicians walking fruit from towers to biochambers (kill them and the feed stops until replacements land); the
  clinic (a biolab: while it stands the breeds climb tiers); loot and the trophy (a dead site leaves its soil).

### The behemoth priced (0.1.66)

Added to the arena with the bred small and the spitter on creep (the user: "Are all units in the arena tester?"): the
incubators breed behemoths from evolution 0.9 (the vanilla spawner's table, bred), and at 60 biomass it beat nearly
every kind, lifting Synthexis's faction answers to +96 and over. At 200 (two a fight) it beats walkers, lightning and
laser tanks, troopers and buggies, and loses to laser troopers, heavy laser troopers, rocket troopers, railgunners and
tanks. The faction table with every breed (4,080 fights): Synthexis against Kessler-Hayashi -13, against Grubstake -8,
against the player -1; the player against Kessler-Hayashi +24.

### The substrate and technicians (0.1.67; the identity consult's step 4)

- **The substrate** (`cell.site`): a blot of Gleba soil (`artificial-yumako-soil`, radius 5) round a heating tower
  (`lp-heating-tower`: Space Age's as a prop, always burning, its fire and light one animation: the site's silhouette
  and its glow at night), eight yumako trees and jellystems on it. Laid clear of nests and worms by its blot and a
  margin, 10 to 40 tiles from the culture's middle (the first run laid it on an incubator: its soil took the creep from
  under it, and the incubator starved and went wild, was retaken by the creep, and starved again, five times in 40
  minutes). It stays when the culture is gone (the trophy, step 6).
- **Technicians** (`lp-technician`: a plain suit in white and green, unarmed, 80 health): two, and one more for every
  four incubators (one walks out of the tower every ten minutes while short). Each walks from the tower to the next
  biochamber in turn, to the pad's edge on the tower's side (the biochamber's middle is inside it: no path ends there),
  waits 12 seconds, and walks back; each visit feeds that biochamber five minutes. Unvisited longer, a biochamber stops
  (its animation and lamp go) and its incubator is unfed as if the biochamber were dead (breeds nothing, keeps 12, wild
  at ten minutes), back at work at the next visit. Every technician dead, a pod brings two more ten minutes on: the
  reprieve. (A unit made by script wanders, which counts as a command: the first rounds were never sent.)
- **A fix found on the way:** an unfed incubator's feral biters were still in a wave's list, and adding them back to
  its group raised an error (a feral biter is the wild's): a wave now takes only its own (`herd.lua`).
- **Tests:** `farm` (default): the substrate (soil, the tower, 8 plants) and two technicians; no incubator unfed in 40
  minutes. `farm techs`: every technician killed at landing; seven minutes on, every original incubator unfed and its
  biochamber stopped; fourteen minutes on, technicians back by pod (3), every biochamber at work, none unfed, none lost.

### The clinic (0.2.1; the identity consult's step 5)

- **The clinic** (`lp-clinic`, `cell.lua`): Space Age's biolab as a prop, always at work, on the substrate by the
  heating tower; 1,500 health, a military target (turrets in reach fire on it), fire 70% and acid 50%. Built with the
  substrate (an older save's site gets one at its next look).
- **Its evolution is the culture's own** (`farm.lua`, `f.evo`): taken from the wild's at landing; while the clinic
  stands it climbs 0.004 a minute, never behind the wild's (0.25 to the stomper's 0.8 in about two and a half hours,
  where the wild take many). Destroyed, the climb stops and the incubators breed at 0.3 at the most: small and medium
  biters, a trace of spore spitters; no spitters, cinders or stompers. A pod brings a new clinic 30 minutes on and the
  breeds are back where they were (what was learned is kept). The farm sets the force's evolution every ten seconds;
  the engine moves it a little between (a few millionths), which does nothing.
- **Tests:** every `farm` run: the clinic stands and the breeds climb (default: 0.301 at landing, 0.385 21 minutes on).
  `farm clinic` (the wild at 0.5): the clinic killed a minute after landing; five and twenty minutes on its learning
  unchanged (0.505) and its breeds at 0.3; a new clinic by pod 30.3 minutes on, the breeds at 0.505 again.
- **Seen in a window (2026-10-23):** the clinic reads beside the heating tower, its lights acid green at night. The
  substrate's plants were seedling mounds (a plant made by script starts ungrown): now made grown (`tick_grown`).
- **Seen in the all-factions save (the user, 2026-10-23):** "Not a fan of the big green line on the map pointing to
  Synthexis": a wave's map trail is now its last 120 tiles only, thin and faint (where it came in from); the mud on the
  ground still runs all the way home. "The Synthexis labs probably could use a green concrete floor": the clinic stands
  on a 7x7 pad of the biochambers' acid-green concrete (`cell.pad`, shared with the cells).
### Its waves are trials (0.2.2; the faction AI's one picker)

- The user (2026-10-23), on a fixed every-third-wave rule at Kessler-Hayashi: "Is hard coding such a thing really a good
  idea?"; and on a smell-and-grievance picker that came next: "It's just that it seems pollution is actively feeding it?
  ... Maybe any defended base as a way to 'test' their bioengineered weapons?" Taken: pollution is its food (creep), not
  its target, and it does not retaliate (the identity consult: "it never retaliates in anger, it samples, records,
  adjusts").
- `farm.target_from`: every force it is at war with (the players, Kessler-Hayashi, Grubstake once broken), their
  defended places in reach (1,600) by 64-tile cell; each scored by its defence (gun 1, laser 1.5, flamer 2.5, a wall a
  twentieth), what the trial would teach (its odds p against that defence, a wave of n against d: r = n / (1 + 6d), p =
  r^2 / (1 + r^2); taught 4p(1 - p), the most when uncertain), novelty (a place tried within its fade, 40 minutes,
  counts less unless its defence changed by a third) and distance. Nothing defended in reach: the nearest of what stands.
  Its last trials are kept in `know.lua`'s record; each wave logs its best three with every term (decisions.txt).
- Seen (system sim, 90 minutes, seeds 12345 and 4242): trials went to three different faces of the player's base in
  turn (novelty), and Kessler-Hayashi's walled camp came second for the third wave on its merits.
- Its personality in `shared.BIOTECH.mind`. The weights replaced, in order: the nearest player building; the every-third
  rule; smell and grievance.

- **Next (the consult's step 6):** loot and the trophy (a dead culture leaves its soil and trees; the clinic goes with
  the culture for now).

### Learning that shows (0.2.12 to 0.2.14)

- The user (2026-10-24): "Really think synthexis as the smart biter enemy has legs"; the features asked for were visible
  scouting, learning that shows, and escalation.
- **The scout a breed of its own** (0.2.14): `lp-bred-scout`, a small biter's body in pale cyan, 30 health, speed 0.34,
  lit, made at launch (not bred). Its loop and its marks are unchanged; it is what the player looks for.
- **Lessons** (`herd.lesson_near`): each wave leaves, at its target, which faces were tried and which broke, and what
  killed it, by killer. The next wave there is made up against those killers from `counters.lua` (the arena's matrix):
  a breed scoring under -0.5 against them stays at the gate. Seen on four seeds (solo, weak face): after a wave lost to
  gun turrets, the next held fewer small biters and more medium biters and spitters.
- **Escalation**: a defence that held draws a wave half as many again per hold (at most twice the cap), and the farm
  waits up to ten minutes for its stock to reach it.
- **Novelty**: a trial counts for the same force's ground within 192 tiles, so corners of one camp no longer read as
  four untried places.
- **Recycling**: a full incubator (90% of its 40) turns, once a minute, one unit its evolution no longer breeds into
  half its price in biomass. Before, incubators filled with first-evolution small biters and bred nothing newer.
- **Watched faces by sector**: the wave picks among the faces its scout saw, never one it did not (an unseen face read
  as the weakest).

### What learning is worth, and the march it uncovered (0.2.15)

- Measured with `system` LP_MIX=solo against LP_MIX=solo-nolearn (its lessons off: `B.mind.learns`, the test lever
  `biotech_unlearned`), four seeds, three game hours each.
- The first run showed two faults, not a verdict. An incubator took back the units it released while they waited for
  the scout, so 11 to 19 of every wave of 60 never left; once an incubator went unfed, 87 of a wave of 120 went feral
  with it. And the herd's whole trail as one compound order failed 35 to 120 ticks after it was given, on most waves: the
  herd went straight at its mark from 900 tiles off, its trail never walked; its way home failed the same way and left
  it standing at the wall it had broken, counted home. Both are fixed: members released again and called into the group,
  a pen's stock never counting a unit out with a wave, and the march and the way home given leg by leg. On seed 777 the
  second wave then broke 17 to 20 buildings where it had broken none or four.
- A wave that went in and found nothing to break leaves no lesson: a turret left of a gutted base drew waves of 120 that
  each walked in and home, counted "held", each escalating the next.
- The stand-in rebuilt nothing, so after the first breakthrough every wave met a gutted base. Solo, it now rebuilds what
  it lost five minutes on, as a player with robots would.
- Against the rebuilding stand-in: with lessons, 273 buildings broken for 1,252 units sent (21.8 per 100); without,
  272 for 1,519 (17.9). The same damage for about a fifth fewer units, won on three seeds of four; on 12345 an escalated
  wave of 90 broke nothing and the learner did less. Learning pays in units, not yet in damage.


### Bursters for a wall, and why not the rest of its make-up (0.2.17)

- Bursters were a third-hour breed (from evolution 0.6): in two-hour system runs none were bred, and in three-hour runs
  a few went out by chance. The arena never tried them as they are meant: its lines lost to nearly every kind, and a
  pack of bursters alone is shot short of a wall.
- The arena's breach (`docs/arena.md`, "The breach"): one spend sent at gun turrets behind a wall two deep, as plain
  biters and with part of it in bursters. Among mediums a few bursters open the wall and break guns behind it, where the
  same spend in mediums alone breaks almost nothing; big biters break that line alone, so the burster's place is the
  middle game. It now comes from evolution 0.45.
- Bred to order: where a wall held its last wave, its incubators make bursters for the next wave there, and the wave
  waits for them a little. It also ordered the breed that best beat what killed its last wave (counters.lua), against
  the same runs without orders (`system` LP_MIX=solo-noorder, the lever `biotech_no_orders`): it broke less where it
  ordered after every wave, and no more where it ordered only after a defence held, its waves fewer for the wait. The
  counters' turret columns came from lines nearly every kind beats, so they told no breed from another; and a wave's
  make-up is the part of its cleverness a player sees least. Its cleverness goes into how it attacks: when, where,
  feints, a breach pressed while open. The burster stays, the one breed a wall calls for, and it glows.

### Bursters held back (0.2.18)

- Its cleverness is in how it attacks (the user, 2026-10-25), and the first piece is its bursters'. Where a wall held one
  of its waves before, at the breach order they leave the herd and wait outside the wall, past a gun turret's and a laser's reach; once the biters are at the
  wall (the guns busy with them) they run at it, or at the turret nearest the breach when the wall there is open. A
  wave without a wall where it breaks in keeps them with it.
- The herd test `burst` (the walled ring, 32 mediums and 4 bursters) against `burst-nohold` on four seeds: held, their
  bursts broke several times the wall pieces, and the wave a hole of 17 to 29 pieces where unheld it opened 2 to 11;
  it broke no more turrets there, the breach being at the weak face with few guns near it. What it gives is the wide
  breach, and the tell: glowing biters waiting out of range, a few seconds to shoot them.
- Held at every wall, in four 3-hour solo runs it broke less than with the hold off: where its biters open the wall
  themselves, unheld bursters go in with them and burst on what stands behind, the power more than once, and held ones
  widen a hole already open. So it holds them only where its lesson says a wall held.

### It knows the ground; the scout is the warning (0.2.19)

- In four-faction runs 15 of 19 waves came blind: their scouts, looping round turrets only, were killed by
  Kessler-Hayashi's tanks, troopers and outposts, and the wave went in without a face, losing half its number. Alone
  against the stand-in, 1 of 24.
- Its faces are now read from the ground, every turret round its target, with what its lessons say of each face. The
  scout still loops the base before the wave: the player's warning, and the wave's clock. Killed, it leaves a skull on
  the map and the next scout there loops wider; the wave comes all the same.
- Its targets are weighed by their moving defenders too: a Kessler-Hayashi camp with a few guns on its edge and a
  hundred units inside had read as soft, and drew wave after wave.
- Two faults in its weighing of targets, found reading the trace: while a wave waited to grow or for its order, it
  weighed again every ten seconds and marked each choice tried, so every place soon read as just tried and where it
  went was close to chance; and nothing told it that every wave sent somewhere had died there. A trial is now recorded
  when a wave leaves, and a place is weighed by the share of its waves there that came home.
- In four-faction runs its waves no longer come blind, and now fight: at Kessler-Hayashi's camps most die, where blind
  waves used to walk up and home whole. How Synthexis should fare against Kessler-Hayashi is a balance question left open.

### The player first; Kessler-Hayashi when struck (0.2.20)

- Kessler-Hayashi is among its targets only while it holds a grievance against it: an incubator, a tumor, a
  biochamber destroyed. Its waves at Kessler-Hayashi's armies died nearly to the last unit; the player is its enemy.
- Kessler-Hayashi's railgunner, the nest clearer, no longer holds a camp against any wave: its slug pierces a few
  biters and stops, and does its full damage to spawners, worms, incubators and tumors, a fraction to biters on their
  feet; its camp keeps it for clearances. Big biters and behemoths beat it, until Kessler-Hayashi, losing units to
  biters, buys heavier railguns (the user: an investment, weaker at baseline).

### On real factories (0.2.21)

- The visits to the player's saves had never had Synthexis: the test mod kept it off. On them it starved (its creep
  took nests faster than its technicians could walk to them, and incubators went wild with their stock), sent one wave
  in three hours on nw (its guard, six an incubator, kept 72 home), and its waves walked straight lines into laser
  walls or round whole factories. Read a sprawling base as one box of every turret in 240 tiles, its scout looped
  through the factory and its faces were ones no wave could reach.
- Now its waves stage as the corporations' raids do, routed round turrets, water, cliffs and buildings to the approach
  with the least fire on the way in and where it fights; a target deep within a perimeter of turrets gives way to the
  building nearest the edge of its reach; inside, with nothing feeding a gun in sight, it breaks what is there. Its
  creep grows only as its technicians keep up.
- On deathworld10x, three hours: 172 of the player's buildings broken, mostly mining outposts (belts, drills,
  poles), where straight trails broke 84 by throwing waves at turret lines. Each fault was found from the operation
  records (scripts/oplog.lua), one map a wave.
