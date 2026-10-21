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
   a captive spawner's look.
2. One coordinated wave in the arena (`scripts/arena.sh`): a probe, then a split attack on the player's power, against
   the player's lines; compared with the same biters as a plain wave.
3. The arena's bred-biter rows: does it cluster as its own group (`docs/arena.md`)?
