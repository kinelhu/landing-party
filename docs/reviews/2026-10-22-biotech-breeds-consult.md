# The biotech's breeds and its farm (Fable), 2026-10-22

Read: `docs/biotech.md` (the brief, the engine tests, the fairness table, the pack, the first slice and its eight
`herd` runs), my waves consult of today (section 7, the breeds by tier) and the identity consult of 2026-10-21,
`docs/arena.md` and `docs/units.md` as they stand in the working tree (the uncommitted arena run of today has the two
bred rows in it: 2,001 fights, a fifth class "bred", five clusters), DESIGN.md (the arena, the RTS pass, the army, the
player's army, the biotech section, the engine notes), `landing-party/biotech.lua`, `scripts/herd.lua`, `units.lua`,
`air.lua`, `shared.lua` (with `BREEDS` as added today), `data-final-fixes.lua`, `scripts/army.lua` (how walkers are
ordered), `tests/lp-arena/{arena,batch}.lua`, the `herd` scenario in `tests/lp-sim/control.lua`; Space Age's
`enemies.lua` (strafers, stompers, wrigglers, the demolisher's fissure and ash cloud), the base game's `enemies.lua`,
`enemy-constants.lua` and `enemy-projectiles.lua` (spitters, worms, acid puddles and stickers), and the 2.0.77
`runtime-api.json` and `prototype-api.json` for every engine claim (section 9 says which are checked and which need a
spike).

Framed player first, as asked: for each breed, what the player sees (silhouette, colour, sound, the map), what they
must do that they did not do before, what beats it, and where it would blur with Grubstake's or Kessler-Hayashi's
units. Numbers come second and are provisional until the arena rows in section 8 have run.

## 1. The verdict

Three things, the first of them measured.

**The stock as built is a copy of Grubstake's swarm with an armour-killing bite.** Today's arena run (working tree,
`docs/arena.md`) says so twice. The clustering puts bred big and bred medium in one group with Grubstake's Shotgun
hands and nothing else (group 3), which is the fail condition my first consult wrote for this exact test: a class that
beats and loses to the same things as Grubstake's infantry is a column the web already has. And the class row reads
bred +55 against small arms, +71 against armour, -10 against splash, -100 against air. The brief promised "splash,
fire and air beat it; small arms lose long fights; armour even". Fire and air hold (flamers 3: -100 for both breeds;
every flier -100). Splash does not hold for the big (prism +38, tesla +52, shock +59, breacher +57, sapper +24: it
beats them) and armour is the opposite of even: bred big beats tank +86, aegis +79, battle tank +79, walker +95,
dozer +75, and bred medium beats tank +76 and walker +86. A tank should drive through biters; here it is eaten. The
reason is the bite: a big biter's 30 physical at 1.7 a second goes through a hull's flat 3 and 20% nearly whole,
where the RTS pass made small arms do a third to armour by giving them 7-point shots. Section 2 gives the fix (a bite
damage type that hulls resist), which is one prototype and a resistance line per hull, and separates the stock from the
Shotgun hands by giving it a loss they do not have.

**The user's four ideas sort cleanly into one yes, one yes with a different job, one later, one no.** Acid: yes, and
it is the biotech's anti-armour piece, which is what the stock must stop being. The demolisher's fire effects: yes,
as the death of one breed (a suicide piece that cracks the ground where it falls), never as a weapon fired. Stompers:
yes, last, and they need one engine spike before anything is designed on them. Lightning: no, or at most as a late
death effect. Electric is Kessler-Hayashi's damage track (Optics levels laser and electric; Shock, Tesla, the jammer's
arcs on robots), and a green biter that arcs is Kessler-Hayashi's weapon on the wrong animal. The roster below has
four fighting breeds, a scout and a worm, and nothing in it shoots electricity.

**The scout should be a different animal.** A bred strafer (Space Age's small strafer, re-tinted, with pack numbers
and its strafing AI removed) rather than the biter nearest the base. The reason is the one the user gave: the tell
must read at a glance. Among forty green biters, one green biter with an icon is a label; a five-legged thing a tile
and a half tall stepping round the wall alone is a sentence. It also plants the late stomper's family in the first
hour, so the end of the ladder is "the big one of the kind that watches you" and not a new import. The engine risk
is real and bounded (section 4): three spikes, and a spitter-shaped fallback that costs nothing.

## 2. The class, corrected

Two corrections to the class statement before any breed is added.

**Regeneration is the pen's, not the animal's.** Vanilla biters heal (medium 0.6 a second, big 1.2), which does not
register in a three-minute fight against rifles doing 24 a second to one target, and the arena rows confirm it: the
long fight the stock wins is won by numbers and teeth, not by healing. Making the per-unit heal large enough to matter
(2 to 3% of max a second) would make the class the one the first consult feared, a trickle-proof swarm. The
regeneration the player should see is the one already built: survivors walk home and the pen refills, so the wave
that comes back is the same wave. Say that in the class statement and leave `healing_per_tick` at vanilla. The
class is then: **many, soft, cheap, blind to the sky, and back next time**.

**A bite is not a bullet.** Add a damage type `lp-bite` (a `DamageTypePrototype`; the base game's `make_unit_melee_ammo_type`
takes the damage type as its argument, so the bred biters' bites change in one line each) and give it resistances by
class, which is how the RTS pass separated small arms from armour and the cleanest lever in the genre: armour types
against damage types. Proposed, to be set from the arena:

| What is bitten | Resists `lp-bite` | Why |
|---|---|---|
| armoured hulls (tank, aegis, dozer, Scorcher, Prism, Tesla, the battle tank) | 60% | teeth do not open a hull; the tank drives through |
| the walker | 40% | a spider is a hull on legs; it should still fear a herd that catches it standing |
| infantry, buggies, the character | 0% | soft |
| walls, gates | 0% | the breach is the stock's job; it must stay quick |
| turrets | 0% | the stock kills what it reaches |
| the biotech's own (bred against bred, when it is at war with itself one day) | 0% | |

With that, the expected class row becomes: beats small arms (as now), loses to armour (the lance and the slug already
beat armour; the biotech's answer to armour becomes the spitter, section 3), loses to splash once the big is priced
right, loses to fire and air. Price is the second lever: bred big at 20 buys 21 of them for 420 and that is what ate
the Prism; 35 to 40 is nearer (10 to 12 bigs against 4 Prisms), and the bite type should be tried first because it
changes who the big loses to, while price only changes how badly.

The physical resistances of vanilla biters (medium flat 4, big flat 8, behemoth flat 12) are the other half of the
rifles' problem (a trooper's 8 does 4 to a medium, 0 to a big: that is why "small arms lose long fights" came out at
+82 and +100). Keep them: they are what the brief wants, and they are the reason splash and fire are the answer.

## 3. The roster by tier, player first

The rule for every entry: one job, one silhouette, one colour story (the biotech's green body and yellow bands on every
animal; the one exception glows ember, and it is the one the player must shoot first), one counter the player can read
from the shape. Names are what the player would call them; the prototypes stay `lp-bred-*`.

| Tier | Breed | Body | Job | Beats | Beaten by |
|---|---|---|---|---|---|
| 0 | stock (bred medium) | medium biter | the herd's mass; the breach | small arms, Shotgun hands, unfed turrets | splash, fire, air, armour (after the bite type), the railgunner |
| 0 | the tracker (bred strafer) | small strafer | the scout; fights nothing | nothing | anything that reaches it before its loop ends |
| 0 | the worm (bred medium worm) | medium worm | the pen's guard; the one thing of the biotech's that shoots up | fliers over the farm, infantry on the trail's end | artillery, the battle tank at 18 under acid, a herd's absence |
| 1 | the spitter (bred medium spitter) | medium spitter | anti-armour and area denial: acid through hulls, puddles at the breach | tanks, aegis, battle tanks, the walker, infantry that stands still | rifles and lances (they outrange it: 15 and 17 to 14), fire, air |
| 1 | the big (bred big) | big biter | the front rank: opens the two wall pieces and takes the turret at the gap | walls, turrets, Shotgun hands, troopers | splash (priced right), rockets, flamers, the railgunner |
| 2 | the runt (bred small) | small biter | the probe: six to ten thrown at a face to see what fires | nothing; it is spent | everything; that is the point |
| 3 | the cinder (bred big, ember) | big biter, ember bands, a glow | the suicide piece: dies into a fissure that cracks wall and turret round it | a wall with turrets on it, if it gets there | range: anything that kills it before it arrives (lances, rockets, flamers at 30) |
| 4 | the stomper (bred small stomper) | small stomper | over the wall, no breach; the keep-breaker | small arms, walls (it ignores them), gun lines | rockets, slugs, the battle tank, fliers, artillery |
| 4 | the behemoth (bred behemoth) | behemoth biter | the mega wave's weight; an event, never stock | most ground | the same as the big, in quantity |

Each as the player lives it.

**Stock (tier 0, built).** *Sees:* the medium biter's body with green plates and yellow bands, the vanilla growl
(keep it: the player's ear already knows a biter, and the colour says whose), green dots on the map, a leader's egg
icon over the one in front. *Must do:* what the brief says: shoot the tracker, keep the feed under the guns, no dry or
dark turret, repair the breach. New against this breed and no other: the long fight is lost by rifles (+82 against
troopers), so a trooper squad that meets the herd in the open needs a breacher or two with it (bred medium against the
breacher: -98), and a wall with gun turrets on yellow ammunition is a trough (guns 6: +68 for the stock, +100 for the
big). *Blur:* Grubstake's Shotgun hands, exactly (the cluster). What separates them once the bite type is in: the
hands shoot up and lose to armour less; the stock loses to armour and never looks up. In the world they never
blur: the hands come at night to an unguarded outpost in a buggy's wake; the stock comes up a trail to a mark in
daylight after a scout.

**The tracker (tier 0).** Section 4.

**The worm (tier 0).** *Sees:* a medium worm with green plates (the worm sprites carry mask layers as the biters do),
rising out of the ground beside a pen; an acid stream at 30 tiles, the same yellow-green as the biotech's colour, which
is the one happy accident in this roster: vanilla acid is already the biotech's green, so every puddle on the map reads
as its. On the map: a green dot by the egg icon. *Must do:* bring something that outreaches 30 (artillery; nothing
else the player's army has does) or something that can stand in acid for the 20 seconds it takes to close (the battle
tank; no unit resists acid, the walker's 50% is Kessler-Hayashi's). *Shoots up:* yes, and it is the only thing of the
biotech's that does (section 6). *Blur:* Kessler-Hayashi's howitzer outranges it and its siege mortars dig in at 36;
the worm is a wild thing in a corporation's colour and the player already knows what a worm does. No blur.

**The spitter (tier 1).** *Sees:* the spitter's body (low, long, a tail; a different animal from a biter at any zoom),
green and yellow, the vanilla spit arc and the puddle that glows for 32 seconds (`acid-splash-fire`, lifetime 1,920
ticks), the sticker that slows whoever stands in it (medium: to 50% for 2 seconds, renewed while they stand). Vanilla
acid is the right look; no new art. *Must do:* two things. Move the squad: a trooper in a puddle is a dead trooper, a
trooper who steps out is fine, and that is a thing to learn by losing four. And stop sending tanks at the herd: acid has
no resistance on any hull in the roster (`units.lua`: physical, fire, explosion, laser, electric; nothing for acid), so
a tank that drove through the stock now stops in a puddle with its paint coming off. *Beats:* armour, by design (the
arena row to prove it: spitter against tank, aegis, battle tank at +40 or better), and anything that holds a line
inside a puddle. *Beaten by:* rifles and lances, which outrange it (15 and 17 against the medium spitter's 14) and find
50 health behind no armour; fire; air. So the biotech has its own cycle: stock beats rifles, rifles beat spitters,
spitters beat tanks, tanks beat stock. That is a web, and it is the test of whether the two breeds are two breeds: if
they cluster together the spitter is a stock with a longer arm, and its damage should go up and its health down until
they part. *In the pack:* spitters stand at the breach and cover the withdrawal; a squad that sallies into the herd's
back (the one new counter the waves consult found) now walks into puddles. The march and withdrawal still fight
nothing; the spitters fire only once the herd is inside and on the way out. *Blur:* none in the two corporations
(nobody else spits), one with wild spitters, settled by colour. One rule: the spitter's 14 never outranges a turret
(gun 18, laser 24, flamer 30), so a spitter standing at the wall reaches 11 tiles inside. "What feeds the guns" within
11 tiles of the wall is now reachable without crossing it; the inner keep's depth becomes part of the counter, which
is right (a keep is deep), and the GUARDED rule (three turrets within 24) still passes such targets over.

**The big (tier 1).** *Sees:* the big biter's body, the same colours; the player who knows biters knows what a big
one means. *Job:* the front rank. The breach is two wall pieces; the stock chews them in 20 seconds and the big in
six, and the big takes the turret nearest the gap while the stock files through. *Must do:* splash at the breach
(a breacher squad, a Prism if the player ever captures one, the player's own grenades) and fire on the trail's end.
*Price:* the one row that must change before the big ships (section 1). *Blur:* Grubstake's Dozer (a ram for the
shotguns): the Dozer is a hull with 1,800 health that pushes a wall open at 2 tiles; the big is an animal with 375
that chews it. The player's answer differs (rockets for the Dozer, splash for the big), so the roles differ. Two
sizes of the same animal in one colour are already a lot; do not add the behemoth as stock (below).

**The runt (tier 2).** *Sees:* six to ten small biters, green, walking straight at one face and dying there, two
minutes before the herd. *Must do:* read it as a clock and a pointer (the waves consult, the probe), and check the
ammunition on that face. *Job:* the probe is a behaviour; the runt is its body, and giving the probe its own breed
makes the tell legible: "the little ones are the ones that die on purpose". The runt is never in the herd. *Blur:* none.
Note that the pen breeds by the biotech's evolution, which will stop producing small biters at 0.5 and above (vanilla's
spawner table): the probe's runts should be a fixed `result_units` line of the pen rather than the evolution's choice,
or spawned by script at probe time.

**The cinder (tier 3).** *Sees:* a big biter's body with ember-orange bands instead of yellow and a small orange
`light` under it, so at night it is the one animal in the herd that is lit, and by day the one with the wrong
colour; a faint crackle (the demolisher's fissure sound at low volume as its `working_sound`). When it dies: the
demolisher's crack (`demolisher-crack-effect`, a glowing fissure that grows for a second with an orange light of
radius 20), then the eruption (`fissure-explosion`) and a scorchmark that fades. The mechanism is the demolisher's
own `make_demolisher_fissure_attack` with its damage action rewritten (force `not-same`, explosion to buildings in a
radius of 3, a third of that to units, nothing to the biotech's), as the cinder's `dying_trigger_effect`. *Must do:* kill
it early, at range, before it reaches the wall. This is the one breed where "shoot the biggest one first" is wrong:
shoot the orange one first. Rockets and lances have the reach; flamers at 30 kill it on the trail's end. A player who
lets the herd arrive with cinders in it loses the two wall pieces and the turret behind them in one second, and the
breach that was narrow is a gate. *Beaten by:* range and fire; also by killing it where it does no harm (in the open,
the crack hits grass). *Why the demolisher's effects and not the base game's fire:* fire (`fire-flame`) spreads to
trees and burns anyone standing in it, the biotech's own herd included, and walls are immune to it (stone wall: fire
100%), so a fire breed would not open a wall and would light the player's forest. The fissure is an explosion entity
with a sticker: no spread, a telegraph, a scorchmark, and explosion damage that walls and turrets take. The look is
Vulcanus; retint the crack's light from the demolisher's orange toward the biotech's ember and it reads as "this one
burns inside". *Blur:* Grubstake's sapper (dynamite at 11, splash to walls) and Scorcher (flame bursts at walls and
turrets), the player's breacher. All three are weapons a living unit fires; the cinder is a death, and the counter
inverts (kill the sapper and the wall is safe; kill the cinder at the wall and the wall is gone). The player feels the
difference the first time a trooper finishes one off at the gap. One guard: the cinder never dies at the pen (an
expedition that kills cinders at home would crack the biotech's own pens, which is funny once and a bug after; the
death effect skips the biotech's force).

**The stomper (tier 4).** *Sees:* Space Age's small stomper in green, five legs, a body three tiles across, the
ground shaking (its walking sound), stepping over the wall at the mark without a breach. *Must do:* rockets (the
rocket trooper's 110 explosion: the small stomper has no explosion resistance, 3,500 health, 32 rockets; ten rocket
troopers kill it in eight seconds if it comes to them), the battle tank's 50, slugs; and keep the keep under turrets
that are not gun turrets (its physical resistance is 50% with a flat 2; set the flat to 0 for the class and keep the
percent, and drop the vanilla laser 80% to 40%: lasers should hurt it). *Job:* the keep-breaker, the one piece that
makes "the feed under the guns" cost something again at the top of the ladder: it walks over the wall to the keep
and stomps. The scout's mark still says where; the trail still leads home. *Beaten by:* rockets, slugs, the battle
tank, fliers (it cannot shoot up), artillery. *Blur:* Kessler-Hayashi's walker (a spider on the spidertron that steps
over walls and shoots rockets, and shoots up). The silhouettes are different animals (a machine with four legs and a
turret; a pentapod with a head), the weapons are opposite (rockets at 15; a stomp at 4), and the walker is a line
unit where the stomper is a siege event. Moderate blur in the sentence "a thing that steps over your wall"; none in the
answer (the walker is killed by slugs and rockets too, but it shoots back at fliers, and the stomper is helpless to
them). *Engine:* section 9, the group spike; and the stomper's `dying_trigger_effect` spawns five premature wrigglers
and a shell. Drop the wrigglers (a new silhouette with no job on Nauvis; they die of age in 50 seconds and read as
"they died to nothing"), keep the shell (a corpse the size of a house where it fell is a trophy).

**The behemoth (tier 4, event only).** 3,000 health, a bite of 90, flat 12 physical. As stock it is the deathworld
with a logo. As the weight of the mega wave (three pens full at once, a clock on each, the waves consult's section 5)
it is the thing the player sees at the back of the herd and runs the artillery for. The pen's evolution will breed it
on its own once the biotech has eaten enough; the mega event is where it is allowed out. Between events, cap the
pen's behemoths by script (release them into the stock only when an event is called).

**Not in the roster:** the lightning breed (section 7), wrigglers, bred spitters in big and behemoth sizes (one spitter
silhouette; scale by count), bred small worms (a small worm's 25 is inside a laser's 24 plus a step; the medium's 30
is the point), a drover or any vehicle, a demolisher.

## 4. The scout

**Recommendation:** a bred strafer, from the arrival slice, behind three spikes; a bred medium spitter as the fallback
silhouette if the spikes fail, which costs nothing because the spitter prototype is in the tier 1 roster anyway.

*What the player sees:* a pentapod a tile and a half tall on five thin legs, green body, yellow head mask, walking
round their wall at 29 tiles with the stepping gait of a Gleba animal, stopping at four faces for ten seconds, then
sitting at one, facing in. It chirps (the strafer's `working_sound` and `warcry`), which is nothing like a biter, so a
player with the sound up hears the scout before they see it. At night a faint green `light` under it (a scout the
player cannot see at night is an unfair tell; raid leaders already carry a light). On the map: the egg icon as now, and
a green dot. *What it does differently:* nothing; the loop, the stops, the mark and the sit are built. *What beats it:*
as now, troopers outside the wall, a flamethrower's reach, a sally. Numbers to keep it beatable: 150 health (two
bred mediums), no laser resistance (the vanilla strafer's 50% would make lasers the wrong answer and they are the
reach a first-hour player has), physical flat 0, no `strafe_settings` in its `ai_settings` (the vanilla strafer holds
20 tiles from whatever threatens it, which would make the troopers' counter fail by design), vision 40 as the herd's,
and the vanilla strafer's spit removed (an unarmed scout; `attack_parameters` is mandatory on a spider-unit, so give it
the small spitter's stream at damage 1 and cooldown 600 and `distraction = none` on every leg of its loop as now).
Death: no wrigglers (five larvae at the spot where the player shot the scout would read as a punishment for the right
move); the skull on the map as now, and a strafer corpse.

*Why a strafer and not a tinted biter with an icon:* the icon is a label and a label is read; a silhouette is seen.
The user's own words ("the tell reads at a glance") are the test. A second reason is the ladder: the stomper at tier
4 is then the same family grown up, and the farm's imports from Gleba are visible from the first wave, which is a
story about the corporation with no text. A third is practical: a strafer walks on legs over the player's outer
clutter (pipes, belts, rails outside the wall) that a biter paths round, so its loop is cleaner.

*Engine risk, in order of likelihood to bite:*

1. Does a spider-unit take a compound command of `go_to_location` legs and `stop` with `ticks_to_wait`, and does
   `on_ai_command_completed` fire for it with `result == success` at the end? `LuaCommandable` is documented for
   units and spider-units alike, and `army.lua` already gives walkers the raids' compound command (`go_to_location`
   then `attack_area`) through `commandable.set_command`, so the compound and the go_to leg are known to work on a
   spider-unit. The `stop` leg and the completion event are not. One spike: a bred strafer on the herd's loop in the
   `herd` scenario; pass is the mark chosen with sixteen points walked and four stops of ten seconds.
2. Legs step over the player's wall. The loop is 29 outside the turrets' box and never crosses the wall, but the
   walk from the pen to the loop's entry can cross the player's outer works (a rail, an outpost's fence), and a scout
   that walks through an outpost is a scout that gets shot: fine, and fair. What it must not do is step into the base
   on its way to the mark. The mark is on the loop; no leg crosses in. No spike needed; a check in `herd scout` that
   the scout's path stays outside the turrets' box.
3. A spawner breeding a spider-unit. `gleba-spawner` lists strafers in `result_units`, so the engine does it; the
   pen's table gets a fixed line for the tracker (one per wave; the scout is chosen by name, not by nearness, once it
   exists). No spike needed. What needs care is `release_from_spawner` on a spider-unit's commandable (documented on
   `LuaCommandable`, so it should work).
4. Space Age only. The brief makes Space Age a dependency, so there is no base-game fallback to carry. If that ever
   changes, the fallback is the bred medium spitter as the scout: a different animal from a biter, a `unit`, zero risk,
   and the one cost is that the spitter breed and the scout then share a silhouette, which the icon and the behaviour
   (it walks alone, it never spits) separate well enough.

## 5. Home: the farm, and the hunt

The user and Claude lean to the biotech landing 600 to 1,000 tiles out on a nest field, so that hunting it along its
trails is part of the deal. I agree, with one change of emphasis: the distance is only good if the walk is not the
game. The design below makes the farm a place with a shape, a clock and a prize, and makes the walk a rail line.

**What a farm is.** Three to five pens on captured nests in one nest field, 40 to 80 tiles apart, each with two bred
medium worms within 12 tiles of it, the wild nests of the field left wild all round (at peace with the biotech, at war
with the player: the farm's hedge). No walls, no lamps, no floor but the trails. On the map: a cluster of egg icons
in green in the dark beyond the player's radar, dirt threads running from it toward the player's base, and the red
of wild nests round it. It is found by following a trail, which is the exploration hook the far landing buys. A farm
never has more than five pens; growth is a second farm on another field, not a sixth pen.

**What guards it.**
- *The hedge:* the wild nests. The player who comes overland clears nests to reach the pens, which is work they know,
  and the biotech's peace with the wild biters means the hedge never thins on its own.
- *The worms:* two per pen, range 30, acid, and they shoot up (section 6). They are the reason an expedition is an
  expedition: nothing in the player's army outranges 30 but artillery, so the fight at a pen is either an artillery
  wagon on the rail or a tank that eats acid for twenty seconds while the troopers close.
- *The stock at the gate:* the pen's milling biters are its garrison. They are idle units and attack what they see;
  at home they do not withdraw (a pack defends its den; the `withdraw` rules apply to waves only). A pen that has just
  sent its wave has an empty gate, which is the clock the player reads: a fresh trail means the herd is out, and the
  farm is at its weakest for the ten minutes the wave takes.
- *The call home:* a pen under attack (any damage from a player force) turns every wave out from that farm for home
  at once (the withdraw stage, up the trail), and pulls the stock of the farm's other pens to it. The player sees the
  herd that was at their wall turn and go, and the map line they followed now has the herd coming down it toward
  them. A raid on the farm is therefore the live counter to a wave in progress, and its cost is a field battle on the
  trail, in the open, where the arena's web applies (splash, fire, the rail-borne artillery) and where the herd's
  spitters cover the stock. That is the fight.
- *Memory dies with the pen:* a destroyed pen takes its `memory` (the wider loops it learned from dead scouts) with it.
  The next pen on that field starts naive.

**The prize.** Killing a pen stops the waves from it, drops the loot the brief moves to the biotech (the pheromone
gland for the player's bait; eggs that spoil, so a chest of them is a clock), and leaves the nest it stood on dead.
Killing all the farm's pens ends that farm; the biotech lands again on another field, at the same cadence the other
two use, so there is always a trail to follow and never twenty. A pen killed while its wave is out leaves that wave
with no home: it withdraws to where the pen stood and stands there (the one place a herd may idle), a kill the player
can collect or leave.

**What makes it a fight and not a chore.**
- *The walk is rail.* The player's army is cargo (muster points, packing; DESIGN "the player's army"). A trail from the
  wall 800 tiles out is a survey line for a rail; the expedition is a train with a muster point, a forward barracks
  (field repair within 30) and an artillery wagon, unloaded at the trail's head. Playtest it that way and tell the
  player so in a tip. A player who walks twenty troopers 800 tiles has chosen the chore.
- *The clock:* go when the trail is fresh.
- *The hedge has lanes:* Kessler-Hayashi clears nests (below), so its clearances cut lanes into the field the player
  can use, and its siege columns are prey the pack goes for, so a player can lead a column to a trail.
- *The worms are the boss:* two worms at 30 are a real obstacle to a trooper army and a trivial one to artillery; the
  player's choice of tool is the decision.
- *Scale:* three to five pens. A farm cleared in one trip is a win the player can feel; a farm of twenty pens is a
  job.

**Kessler-Hayashi.** At war on sight, which the code gives for free. Its clearances treat a pen as a nest (its
railgunners one-shot bred biters: `data-final-fixes.lua` tags `lp-bred-*` and `lp-pen` with `lp-biter`, so the first
consult's worry is already handled; the arena confirms railgunner against bred +100 both sizes). A Kessler-Hayashi
clearance column arriving at a farm is the one three-way fight the mod has not had: worms against a howitzer, stock
against railgunners, and the player deciding whether to let the exterminator do the work (and be billed for the nests
it clears round the farm: the ledger's attribution is by nest, so a farm near the player's cloud is a bill) or to get
there first for the loot. Do not script any of it; measure it (`rivals`-style, a farm beside a Kessler-Hayashi camp,
section 8). What must be true: the ledger never bills a bred wave (the brief; the `herd wild` run's bill check should
become a standing assertion).

**Grubstake.** Neutral until the break; after it, Grubstake's harriers and scavengers are the farm's natural raiders
and the worms are what stops that being free. Nothing to add here beyond section 6.

**Distance, two engine facts.** `REACH` is 500 in `herd.lua` and must grow to the landing distance plus the base's
size (1,100). And a unit in an ungenerated chunk cannot path (the 0.1.51 lesson), so the arrival slice must generate
the corridor from the farm toward the player's base before the first wave (a `request_to_generate_chunks` along the
line, as the `herd` scenario does), or the first march fails at once and the player never sees the scout. At 800
tiles a bred medium walks the trail in about a minute (0.24 tiles a tick), so the tell-to-strike window (3 to 6
minutes) is unchanged: the scout leaves early, the loop and the gather carry the time.

## 6. Air

**In the field: the counter we want.** A herd on a trail with no way to shoot up is prey for fliers, and that is the
genre's rule for a faction without anti-air: build fliers against it. It gives Grubstake's Wheels branch its second
job after the break, and it is the one honest reason for the player to want a flier of their own one day. The arena's
-100 against both fliers is the right number. Nothing of the biotech's that walks should shoot up, and no acid on
landing pads (a harrier never lands, and a puddle that hurt a flier would be a lie about what acid is).

**At home: static anti-air only, and it is a worm.** A farm that cannot touch a flier is a farm two scavengers delete
for nothing, and nothing in the identity says the biotech is helpless; it says its animals are. Worms are turrets, and
turrets hit every mask by default in this mod (`data-final-fixes.lua` masks only fluid turrets and artillery), so a
bred worm on the biotech's force fires at a harrier with no code. The first consult said the same. Keep it: the herd
is blind to the sky; the farm is not, and only at the pens. A scavenger pair against two medium worms (range 30 to
the scavenger's 14, acid through 180 health with no resistance) is a fight that costs Grubstake something, which is
what makes the raid a decision for it.

**Who has air today.** Only Grubstake, and it is at peace with the biotech until the break; the player has none
(trooper, breacher, rocket trooper, battle tank; artillery is the player's reach over walls and it is not a flier).
So the hole, if it is one, is open only after the break, and the worm closes it to the size of a fight. If the player
is ever given a flier, the same holds.

## 7. What should not be built

- **The lightning breed as a weapon.** Electric is Kessler-Hayashi's: the Optics track levels laser and electric, the
  Shock arcs, the Tesla arcs and drains, the jammer arcs robots down. A biter whose bite arcs is the Shock trooper in a
  green coat, and the player's answer (electric resistance, spread out) is the one they built for Kessler-Hayashi, so
  the biotech teaches nothing. The engine agrees: `LightningPrototype` is a planet's weather, not a weapon, and a unit's
  "lightning" would be the mod's own `lp-arc-chain`, which is the Shock's. If the user wants a spark in the roster,
  the only place it does not blur is a death effect (a breed that discharges when killed at close range, so the player
  learns to kill it at a distance), and the cinder already owns "kill it at a distance". One such piece is enough.
- **Fire that spreads.** `fire-flame` spreads to trees, burns the biotech's own herd, and does nothing to a stone wall
  (fire 100%). The cinder uses the demolisher's fissure for that reason.
- **The behemoth as stock, and the big at 20 parts.** Section 1.
- **Wrigglers.** No job on Nauvis, a fourth silhouette in one colour, and premature ones die of age, which reads as
  nothing.
- **Big and behemoth spitters, small worms, a bred demolisher.** Section 3.
- **A nest planted in the breach, a drover, a pen with walls or lamps, any pen past five on one field.** The waves
  consult parked the first two; the last keeps the hunt a trip and not a job.
- **A scout with strafing AI, or two scouts.** The scout rule is the fairness of the whole faction: it never escalates.

## 8. Order, and what proves each step

Each step names the arena rows and the `herd` variants that prove it, in the harness as it stands (the arena's `KINDS`
takes any prototype on any force; the `herd` scenario takes a `mix`).

**The arrival slice (tier 0): the farm, the tracker, the worm, the bite type.**
1. The bite type and the hulls' resistance; the big's price. Arena: the two bred rows rerun. Pass: bred medium beats
   small arms (+40 or more against trooper and both infantries), loses to armour (-40 or worse against tank and battle
   tank), loses to splash (-40 against breacher, sapper, shock), loses to flamers 3 and both fliers (-100); bred big
   the same shape at its new price, and no cell above +60 against a splash kind. Clustering: the two breeds in a group
   of their own, Grubstake's infantry back in group 2 with the small arms. A guard seen failing first: run the
   clustering with the bite resistance at 0% and watch the three cluster again.
2. The tracker. `herd` default with the strafer scout: the same outcome as 0.1.51 (mark, breach, power dead, home) and
   the scout's path never inside the turrets' box. `herd scout` (seven troopers outside): the strafer dies before the
   mark, the blind wave, the wider loop next time; the strafer's health is tuned so seven troopers kill it within 20
   seconds of contact (any longer and the counter is a chase).
3. The farm and its defence. New variants: `herd farm` (three pens with worms on a nest field 800 tiles out; the
   corridor generated): the first wave arrives and the tell is still 180 seconds or more; `herd raid` (a player squad
   of twenty troopers and two battle tanks with an artillery wagon at a pen while its wave is out): the wave turns home
   within 10 seconds of the pen's first damage, meets the squad on the trail, and the pen's worms have fired at the
   squad (damage events with a worm as cause); `herd air` (after a scripted Grubstake break: two scavengers at a pen):
   the worms fire at them and at least one scavenger dies, or the pen survives; `herd killed` (the pen destroyed with
   its wave out): the wave withdraws to the pen's spot and idles; the next farm's first loop at that base is the
   default width (the memory died). Ledger: the bill unchanged across every variant (the standing assertion).
4. A `rivals`-style run: a farm beside a Kessler-Hayashi camp with `clears_nests`. Recorded, not asserted: whether the
   clearance reaches the pens, what it costs, whether the pack takes the column.

**Tier 1: the spitter and the big in the herd.**
- Arena rows: `bred spitter` (medium spitter at a provisional 10 parts). Pass: beats tank, aegis, battle tank and
  walker (+40 or more), loses to trooper, lance and both infantries (-40 or worse), loses to flamers and fliers.
  Clustering: the spitter apart from the stock. Fail: spitter and stock in one group, then raise its acid and cut its
  health.
- `herd chase`: as default, with a squad of twelve troopers ordered into the herd's back as it withdraws. Pass: the
  squad loses more than it would against the same herd without spitters (the control: `herd chase` with the spitters
  swapped for stock), and puddles are found at the breach for at least 20 seconds after the herd has gone.
- `herd big`: the breach with four bigs in front. Pass: the two wall pieces fall within 10 seconds of contact; the
  turret nearest the gap dies before the stock is through.

**Tier 2: the runt and the probe.** `herd probe` (one face's gun turrets empty): the probe's runts die at a face, the
turrets that fired are recorded, the herd goes in at the dry face. The variant from the waves consult, with its body.

**Tier 3: the cinder.** Arena: a fixed-line row only (the cinder is not a fighter): against `guns 6` with walls, the
line's wall pieces lost when cinders die at it against when stock dies at it. `herd cinder` (four cinders in the
herd's front): the breach is a gap of four or more wall pieces within 2 seconds of the first cinder's death; the
turret behind it dead; no bred biter hurt by a fissure (the force filter); no fissure at the pen in `herd raid`.
`herd cinder far` (lances on the trail's end): the cinders die in the open and the breach is the usual two pieces.

**Tier 4: the stomper and the mega event.** The group spike first (section 9). Then `herd stomp` (one stomper with
the herd): it crosses the wall at the mark without a breach command, reaches the keep, and dies to ten rocket
troopers in under 15 seconds of contact; the herd's own are not stomped on the march (no bred damage with a stomper
as cause). `herd mega` as now, with behemoths released for the event and never between.

## 9. Engine claims

Checked in 2.0.77's `runtime-api.json` and `prototype-api.json`, and in the mod:

- `LuaCommandable` represents a unit group, a unit or a spider-unit; `set_command` takes any `Command`;
  `add_member` takes a `LuaCommandable` or a `LuaEntity`. `defines.command` has `stop` with `ticks_to_wait`,
  `compound` with `return_last`; `distraction.none`. Walkers already receive compound commands this way (`army.lua`).
- `release_from_spawner` is on `LuaCommandable` (so on a spider-unit's), and `LuaEntity.units` lists a spawner's.
- `EnemySpawnerPrototype.result_units` lists entities with spawn weights by evolution; Space Age's `gleba-spawner`
  breeds strafers and stompers (spider-units) from it, so a pen can breed the tracker and the stomper.
- `SpiderUnitPrototype`: `ai_settings` (with `strafe_settings`, removable), `vision_distance`, `attack_parameters`,
  `absorptions_to_join_attack`, `radar_range`, `height`; the strafer's `dying_trigger_effect` is the wriggler spawn
  and can be dropped. Legs are separate `spider-leg` prototypes referenced by name; copying the unit copies no leg,
  so re-tinted legs are new leg prototypes (the leg graphics carry a `tint`).
- Small strafer: 800 health, physical flat 2 at 10%, laser 50%, range 25, speed 3.75 (initial movement 0.225 a
  tick), vision 40, `size_in_group` 4, strafe ideal distance 20. Small stomper: 3,500 health, physical flat 2 at
  50%, laser 80%, impact 80%, heal 7 a second, spit range 5.9, speed 1.8, `size_in_group` 10, vision 30.
- Base game: medium biter 75 health, bite 15 every 35 ticks, physical flat 4 at 10%, explosion 10%, speed 0.24;
  big 375, 30, flat 8, 0.23; behemoth 3,000, 90, flat 12, explosion flat 12, 0.3; small 15, 7, 0.2. Spitters: small
  10 health range 13, medium 50 range 14, big 200 range 15, behemoth 1,500 range 16, one spit every 100 ticks; the
  puddle (`acid-splash-fire-*`) lives 1,920 ticks; the sticker slows to 60/50/40/30% for 2 seconds. Worms: range
  25/30/38/48, prepare range 8/16/24/36.
- Demolisher: the fissure is an `explosion` entity whose `created_effect` fires three delayed triggers (the eruption
  explosion at 60 ticks, particles at 70, the damage explosion at 75), with a glowing crack animation and an orange
  light of radius 20 times scale; the ash cloud is a `create-sticker` of `demolisher-ash-sticker` (120 ticks, movement
  0.9) with extra damage to `flying-robot` only. Neither is a `fire` prototype: nothing spreads. The damage action's
  force filter is the demolisher's and must be rewritten for the cinder.
- `LightningPrototype` strikes random entities on planets with `lightning_properties`; it is not a weapon.
- The railgunner's `lp-biter` tag is applied to `lp-bred-*` and `lp-pen` (`data-final-fixes.lua`); bred worms named
  `lp-bred-*-worm` would be tagged by the same rule, which is right (they are biters to the exterminator).
- `air.lua` already masks the breeds' bites off fliers (`shared.BREEDS`, working tree); a bred worm is a turret and
  is not masked, which is the behaviour section 6 wants.
- `UnitPrototype.vision_distance` at 50 or above lets units form groups on their own; the herd's 40 is by script and
  the prototype stays at 30.

Needs a spike (a throwaway mod, as before):

1. A spider-unit on a compound of `go_to_location` legs and `stop` with `ticks_to_wait`; `on_ai_command_completed`
   for it with `success`. (The tracker.)
2. A spider-unit as a unit group member through `add_member` (DESIGN's engine note says "assumed, not tested: cannot";
   the 2.0 signature says a `LuaCommandable` is accepted, and Space Age's stompers attack in groups). If it passes,
   `army.lua:227` loses its branch and the stomper marches with the herd; if it fails, the stomper gets the group's
   command separately as walkers do, which the herd code can do since it holds its members.
3. A stomper walking through its own herd: do its steps or its stomp hurt bred biters? (The stomp is its attack and
   should not; the leg effects are the question.)
4. The cinder's rewritten fissure with `force = "not-same"`: wall and turret damaged, bred biters untouched, and
   nothing when it dies at a pen.
5. A bred worm on the biotech's force against a Grubstake harrier after a scripted break: the worm fires, the harrier
   is hit. (Expected from the default mask; one minute to confirm.)
6. A pen's stock defending it: forty idle bred biters at the gate against a trooper squad, with no herd script running.
   (Expected: idle units attack what they see.)

## 10. Recommendation

Fix the class before adding to it: a bite damage type that hulls resist, the big priced so splash beats it, and the
arena rerun until the two bred rows sit in a group of their own and Grubstake's infantry goes back to the small arms.
Then build the arrival slice as the farm: three to five pens on a nest field 600 to 1,000 tiles out with two bred
medium worms each (the only thing of the biotech's that shoots up), the stock at the gate as the garrison, a wave that
turns for home when its pen is hit, a corridor generated before the first march, and the tracker as a bred strafer
behind the three spikes (a bred medium spitter if they fail). Tier 1 is the spitter, the biotech's answer to armour
and the cover for its withdrawal, and the big as the front rank. Tier 2 is the runt as the probe's body. Tier 3 is
the cinder, a big biter that glows ember and dies into the demolisher's fissure: the one unit the player shoots first,
and at range. Tier 4 is the stomper over the wall and the behemoth as the mega event's weight. No lightning, no
spreading fire, no wrigglers, no sixth pen.

What the player tells a friend: "The farm sends a long-legged green thing to walk round your wall. Shoot it. If you
don't, the herd comes in where it sat, the spitters cover their way out, and the orange one blows your gate when it
dies. Then follow the trail: they live eight hundred tiles out behind the nests, and if you hit the pens while the
herd is away, it comes running home down the same path, straight into your tanks."
