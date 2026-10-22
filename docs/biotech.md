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

Open from here: its arrival (landing on a nest, the pens it grows), the evolution from what it eats, the Grubstake break,
Kessler-Hayashi against its pens, the probe (tier 2), the arena rows for the bred biter, and retiring Grubstake's flares
once the biotech lands in games.
