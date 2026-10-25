# Synthexis: growth, research, player technologies (Fable, 2026-10-25)

Read: `docs/biotech.md`, DESIGN.md, the three consults of 2026-10-22, `docs/units.md`, the farm, cell, creep, rd and
know modules, `shared.lua`, `components.lua`; the 2.1.23 API for every engine claim.

## Verdict

Synthexis is one organism today: one culture, a linear clock, and a copy of the corporations' plate tree waiting to be
bolted on. The three questions share an answer. Its spread, its research and the player's rewards should be one economy
the player can read on the ground: biomass, which comes from the player's pollution through its creep. A cleaner
factory starves it; a dirty one feeds a bloom. The corporations research weapons with money from ore. Synthexis grows
and learns with food from smoke. Where my earlier proposals (plates by damage type, a coating, a blight capsule) make it
a corporation in green, I say so below and replace them.

## 1. Growth and spread

**What the player sees.** A purple stain in red nest country that grows while their chimneys run and stalls when they
clean up. White figures walking between glass tanks, more of them as the stain grows. Then one day a slow column leaves
the culture on a trail of its own: a carrier (a big biter's body with an egg raft on its back, violet, lit) with a dozen
escorts, walking nest to nest toward a field 300 to 600 tiles away. Where it stops, a tumor goes down and a second
stain begins. On the map: a second tag, "Synthexis culture 2", and a thin trail between the two.

**Recommendation, ranked.**

1. *Logistic growth paid in biomass.* Technicians stop arriving free on a ten-minute clock. A culture buys one with
   biomass (about two bigs' worth) whenever it can pay and its cells are two thirds fed, at most one every two minutes.
   Income is creep tiles times pollution; creep grows with incubators; incubators are taken only while technicians keep
   up (`cell.keeps_up`). That loop is a sigmoid with no sigmoid coded: slow at four cells, fast at eight, saturating at
   the field's size and at `PENS_MAX`. The clinic sets the ceiling: with none standing, technicians stop at the landing
   number, so artillery on the clinic halts growth as well as evolution.
2. *Seeding by a carrier, never a second pod.* A mature culture (eight fed incubators, biomass banked above a threshold,
   income above spending over the last 20 minutes) sends a carrier with an escort to the nearest wild field 300 to 600
   tiles off with no culture within 300. On arrival the carrier dies into a tumor (a `dying_trigger_effect` creating
   `lp-tumor` on its own force, as the burster dies into a fissure); creep takes the first nest; two technicians came
   with it; the clinic comes by pod 30 minutes later, as after a clinic's death today. The cap on live cultures comes
   from food: a player who keeps pollution off creep sees one or two cultures in a game, a megabase four. Keep a hard
   cap of five for script cost.
3. *Orbit only to begin and to return.* The pod lands the first culture as now and relands 60 minutes after the last
   culture dies. While any lives, it never pods. The corporations drop columns from the sky by the player's era;
   Synthexis arrives from the sky once and then comes over the ground. One is an invasion, the other an infestation, and
   the player should feel the difference in how each is fought. A young culture reads as young: no clinic for 30
   minutes, no worms until the second incubator, no wave until three incubators are fed.

**Why.** Free technicians on a clock is a mechanism with no feedback, and spatial spread needs a thing that travels.
Tying both to biomass makes pollution matter the way the user wanted from the start and hands the player a lever the
corporations never offer: starve it.

**Counterplay and windows.** The carrier's walk (an escort of twelve loses to a tank or a flamer squad in the open;
killed, the sending culture pays again and waits 20 minutes). The young culture (three incubators, no worms, no clinic:
a car and twenty rounds). The technicians, now a purchase: each one shot is biomass the culture would have bred with.
Pollution itself: efficiency modules and a cleaner smelter shrink the next bloom.

**Implementation.** `cell.tick`'s technician drop becomes a purchase from `creep.of(id).biomass`; `gone()` schedules
RELAND only when `next(s.list) == nil`; a `seed()` step beside `send()` in `farm.tick`, siting with `site()` from the
culture's own position; the carrier is a group on `herd.lua`'s leg-by-leg march with `distraction = none`, its last leg
ending in `creep.plant` and the landing setup without the pod. One prototype, `lp-bred-carrier` (big biter body, violet,
a light, 600 health), with a dying trigger. Personality numbers in `shared.BIOTECH.mind`: `seed_at`, `seed_bank`,
`culture_cap`; a culture seeds when its utility clears a threshold, as a corporation plans an outpost.

**Measure.** `farm`, three hours, clean air against 3,000 pollution a minute: incubators and technicians per culture
every ten minutes (the curve should bend twice), time to first seeding. `system`, four seeds: cultures alive at 60, 120
and 180 minutes (one to two expected), waves per hour (it must not double), script time at five cultures. Visits to nw
and deathworld10x: whether the carrier paths 300 to 600 tiles on real ground (the scout failed on lakes in 2.1), and
whether the clean player's culture stalls.

## 2. Synthexis's own research

**Where the plates go wrong.** Chitin, reflective scales and ashskin are Warden, Optics and Asbestos in a green coat:
the same trigger (losses by damage type), the same answer (a resistance), the same counter (switch damage type). The
player has learned that lesson twice, and the arena's web already says fire beats biters. A bioengineering firm that
answers a flamethrower with fire resistance is a shield vendor. Drop all three.

**What its research is.** The user's rule says it: its cleverness is in how it attacks. So the clinic buys *protocols*,
changes in when and how a trial is run, each triggered by how its trials failed (`know.lua` holds the losses, the
lesson records the face and the outcome), paid in biomass, fielded only while a clinic stands (as Kessler-Hayashi's
branches need their labs). The breeds stay on evolution. Three protocols, ranked, each with its tell:

1. *Dusk trials* (trigger: waves lost mostly to laser turrets). Waves time their arrival for darkness
   (`LuaSurface.daytime` and `dusk` are readable; the march is a known length). Inside, with nothing feeding a gun in
   sight, the herd goes for accumulators and solar first. Tell: the scout circles at sunset, the trail is laid at dusk.
   Counter: steam or nuclear under the guns, a night reserve. New to the player: no corporation watches the clock.
2. *Waiting for the army* (trigger: waves lost mostly to the player's troopers and tanks). A wave holds at its staging
   point until the player's squads are seen far from the target (the knowledge layer's sightings; the mod commands the
   player's army, so its muster point and squads are entities it can see). Tell: a herd standing at the trail's end for
   minutes, in the open, and the scout loitering near the barracks. Counter: a home squad, or hit the waiting herd (out
   of turret reach, inside artillery reach).
3. *The feint* (trigger: waves held at a wall even with bursters). The probe's runts go at one face while the herd takes
   another; at the top, a second scout from a second culture (the wave consult's tier 4). Tell: two trails. Counter: no
   dry face, and a reserve that does not run to the first alarm.

Flagged and parked: *forward tumors* along the trail's last 100 tiles (the herd mends on the march). A strong image
that contradicts the decided rule that creep grows toward nests, never toward the player.

**How it reads.** Each protocol adds a lit tank to the clinic's pad, and the map tag's tooltip lists them ("Protocols:
dusk"). The purchase is silent; its first use is the announcement.

**Implementation.** `rd.lua`'s node, trigger and choose shape fits (its triggers already read `know.losses`): a
`shared.BIOTECH.tree` of protocol nodes with `trigger = {killer = ..., outcome = "held" | "march" | "inside"}` and a
biomass `cost`, the fund read from `creep.of(id).biomass`. A protocol is a flag read by `herd.lua`'s staging (launch
time, the gather's hold condition, a second group), never a behaviour branch of its own. `cell.clinic_up` gates them.

**Measure.** `system` solo, four seeds, three hours, protocols on against off (a tune lever as `biotech_unlearned`):
buildings broken per 100 units sent (21.8 today), the share of waves arriving in darkness once dusk trials are bought.
A protocol that fails to move the yardstick on three seeds of four is cut. The test profiles freeze daytime: the
scenario must set it.

## 3. Player technologies from Synthexis

**Where the proposals fall short.** Acid-proof coating is a stat; creep blight is a poison capsule with a new target;
scent tracking is information the trail already gives. None changes what a player builds.

**Recommendation, ranked.**

1. *Hatchery: a tame brood.* Dead incubators drop biter eggs (Space Age's, as the identity consult planned; they spoil
   in half an hour into a big biter on the enemy force). A technology from the clinic's component (a culture sample,
   torn down on the bench as the six existing ones are) unlocks a chest-sized hatchery and a recipe: egg plus gland
   makes a tame egg, a copy whose spoilage creates `lp-tame-biter` with `as_enemy` unset, so it hatches on the force of
   the chest it sits in (checked: `CreateEntityTriggerEffectItem.as_enemy`, `spoil_to_trigger_result`). Idle units
   attack what they see, so a hatchery is a den of guards that needs no power and no ammunition, the two things
   Synthexis cuts. It needs eggs, and eggs come from raiding cultures: the hunt feeds the defence. Tame biters are
   animals in the arena's web: they beat infantry and armour and lose to splash, fire and fliers, so a brood line is a
   choice with a cost, and sappers, Scorchers and bursters are its answer. Wild biters fight them. Price it in the
   arena first.
2. *Scent post: the player picks the killing ground.* A gland device placed outside the wall adds a term to the face
   Synthexis reads at that target: the post's face smells weak. The scout runs to it and sits; the herd comes in there,
   into whatever the player built. It fades after one wave that died at that face (the lesson "held" outweighs the
   post), so it buys one ambush per post and the player must move it. Bait draws wild biters; this draws the pack's
   attention, and a player who builds a killing ground instead of a ring is playing a different game. Synthexis's
   counterplay is its own lesson; the player's risk is an ambush that fails where they invited the breach.
3. *Substrate harvest: Gleba on Nauvis.* The dead site already leaves its soil and trees. Give them a use before Gleba:
   the clinic's component also unlocks yumako and jellystem seeds for artificial soil and a nutrient mash from them,
   which keeps a hatchery's brood fed (unfed, a tame biter goes feral after half an hour: the brood is a line the
   player tends, never a wall). Progression risk: it hands a Space Age player a piece of Gleba early. Gate it behind the
   clinic and keep the biochamber out of it.

**How it reads.** Green animals with the player's colour band at the player's gate; a chest with eggs in it and a clock
the player feels; a post outside the wall with the pack's scout sitting by it.

**Implementation.** `components.lua`: `lp-culture-sample` in `lp-clinic`'s loot, a teardown, craft-item technologies
as now. `lp-tame-egg` copies `biter-egg` with its own trigger; `lp-tame-biter` copies the bred medium with a player
tint; the hatchery is a `container` copy. `marker.lua` holds the post as it holds the claim marker; the herd's face
reading takes it as one more term in a sector's score. A brood on the player's force touches every "who is the player"
check behind `shared.is_biters`.

**Measure.** Arena: the tame biter priced so it loses to splash and fliers and beats small arms. A `hatch` scenario:
twenty tame eggs in a hatchery, a wave of 40 at it; the guards engage and no wild biter joins the player's side.
`herd post`: the post on the heavy face; the mark lands there; the next wave after a loss there ignores it.

## Risks

Five cultures of twelve incubators is 60 spawners with stock; measure script time before raising any cap. Seeding that
outruns technicians recreates the nw starvation; the `keeps_up` gate must stand at the new culture too. Protocols are
the one place this consult asks for new behaviour in `herd.lua`; each must be a parameter of the existing stages, or
the faction AI's rule (systems, not rules) is broken by the faction it was written for.
