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
- What the waves' intelligence is, exactly, and how it stays fair (a focused consult).
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
