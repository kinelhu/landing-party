# Waves with intent: the biotech's intelligence (Fable), 2026-10-22

Read: `docs/biotech.md` (the brief, the user's decisions, the engine tests and the fairness table of 2026-10-22), my two
consults of 2026-10-21, `docs/third-corporation.md`, `docs/corporations.md`, `docs/ai.md`, the notices consult
(world tells, fair warning), and in DESIGN.md the operations framework, operations in depth, the power strike, raid
leaders, the pact, the flare, the answers, world tells and the engine notes; `scripts/ops.lua` (choose, launch, the
staging look, appoint, step), `intel.lua`, `army.lua`, `aim.lua`; the 2.0.77 `runtime-api.json` and
`prototype-api.json` for every engine claim (section 10 says which are checked and which still need a spike).

Framed player first, as asked: for each piece, what the player sees before, during and after, what they must do that
they do not do against wild biters, Grubstake or Kessler-Hayashi, how they learn the tell, and what a careful base
looks like. Mechanics and numbers after.

## 1. The verdict

The trial proved the right thing and built the wrong identity.

Proved: intent is cheap (a scout's sight read twice a second, compound commands, `distraction = none`) and worth an
army (the same 40 biters, a dead wave against a dead base). Also proved, by the fairness table: the scout is a tell and
a counter in one object, and the counters that work are things a player can see and build.

Wrong: read the coordinated wave as a player would, and it is the two existing corporations' signature moves done by
biters. "March round, out of range, to the side it saw least of, break two wall segments" is Grubstake's sneaking
raid (`sneak_route`, `breach_point`: the wall piece the fewest turrets reach). "Go for the power, every laser goes
dark" is Kessler-Hayashi's power strike (`power.lua`: scouts walk the line, the cut pole, the Line goes through the
dark stretch). The counters coincide too: "a second power source inside the wall" is exactly what beats the blackout
(`blackout fed`). A player who has built against Kessler-Hayashi gets the biotech for free, and a player meeting
the biotech first learns nothing new. Flagged in full in section 3.

What is left after the overlap is removed is still plenty, and it is all things biters are and the other two are
not: numbers that cost nothing, animals that the player can watch behave, a corporation that can afford to spend
stock to learn, and a memory the player can see on the ground. The identity below is built from those four. The
trial's mechanics (scout, side, breach, supply target) stay as the skeleton; what changes is what the player sees
around them, and the one piece that is the biotech's alone and nobody else's: it learns by dying.

## 2. The personality: a pack

Not a swarm (wild biters are the swarm: mass with no mind), and not a herder's dogs (that puts a human in the field;
the biotech's people stay at the farm, and the first consult's drover is withdrawn with the cull framing). A pack:
one animal goes ahead and looks, the others wait, the pack comes in on a line, takes what it came for, and leaves.
The player should be able to say, after two waves, "that is how they hunt", and a pack has three habits an army does
not, each one a thing the player can watch:

1. **It looks first, with one animal.** The tracker. Every wave begins with a scout the player can see and kill.
2. **It spends animals to learn.** A probe: a handful thrown at a face of the wall, to see what fires. Grubstake's
   raid turns back when it sees too many turrets; Kessler-Hayashi counts the weight and brings mortars. Neither can
   afford to lose ten units to find out. The biotech can, and that is the one piece of intelligence that is its own.
3. **It leaves, and it comes back the same way.** A pack holds no ground. It withdraws after the kill along the
   trail it came by, and the trail is its memory, lying on the ground where the player can read it.

Everything in the repertoire is a case of one of those three. Where a candidate piece belongs to none of them, it is
borrowed, and section 3 says from whom.

## 3. The repertoire, player first

The table ranks each piece by identity per unit of complexity. "Borrowed" names the corporation whose move it
repeats; a borrowed piece is kept only as skeleton, never as the thing the player remembers.

| Piece | Habit | Player sees | Identity | Cost | Borrowed |
|---|---|---|---|---|---|
| The tracker (scout loop, pause, mark) | looks first | one tinted biter circling, stopping, then sitting | very high | low (built in the trial) | nobody (K-H's two units walk a pole line; this circles the whole base) |
| The probe (a handful at one face) | spends to learn | a small group dying on purpose at a wall; the turrets that fired | high | low | nobody |
| The trail (ground marks, pen to breach) | leaves and returns | trampled ground on the map and in the world | high | low | nobody |
| Withdrawal after the kill | leaves | the herd turning and going home through its breach | high | low | nobody (K-H holds, Grubstake runs when its foreman dies) |
| Supply target (what feeds the guns) | looks first | the generators, the ammo line or the oil pipe dying, turrets standing | medium | medium | K-H's blackout (power only) |
| Side choice by sight | looks first | the herd coming round to the quiet side | low | low (built) | Grubstake's sneak route |
| Narrow breach | looks first | two wall pieces chewed, the herd through the gap | low | low (built) | Grubstake's sappers and Dozer |
| Split (two herds, two sides) | numbers | two breaches at once | medium | medium | nobody; it is mass used well |
| Feint against the player's army | spends to learn | a loud group one side, the pack the other | medium | high | K-H's undesigned Feint |
| Follow-up wave on the breach | returns | the second herd on the same trail within minutes | high | low | nobody |
| Labs as a target | none | | none | | drop it (section 5) |

Each piece as the player lives it.

**The tracker.** *Before:* a single biter in the biotech's colour, a small icon over it as raid leaders carry
(`ops.appoint`'s sprite) and its own marker on the map, walking a loop outside the turrets' reach. It stops at
each face of the base for a few seconds (a sniff: `stop` with `ticks_to_wait`), then walks on. When it has seen the
whole base it goes to the face it chose and sits there, out of reach, facing the wall: the mark. *During:* the herd
arrives at the sitting scout and goes in where it sits. *After:* the scout leaves with the herd, or dies with it.
*Must do:* decide between shooting it (a turret with reach past the loop, a flamethrower on the perimeter, a sally
with the character or a squad) and reinforcing the face it marked. Against wild biters there is nothing to shoot
before the wave; against Grubstake the first sign is a broken machine; against Kessler-Hayashi it is a survey
stake or a mortar deploying. *Learn the tell:* the first wave teaches it by itself: the biter that would not attack,
then the herd where it sat. *Careful base:* a reach past 29 on each face (one flamethrower a face, range 30, or an
outer pair of gun turrets on the loop as the trial did), or a squad kept to sally. Killing the tracker is the whole
counter for that wave: the herd comes blind, the plain wave, and dies as plain waves die.

**The probe.** *Before:* between the loop and the herd, on waves from the second tier up, six to ten biters walk
straight at one face and die against it. *During:* the player sees which of their turrets fired. So does the
biotech: a turret that did not fire is dark (no power), dry (no ammunition), or out of reach, and the herd goes in
there. *After:* the probe's corpses lie at the face it tested; the herd follows within two minutes. *Must do:* keep
every turret fed and powered, and read a probe as a clock: it says the herd is coming and roughly where. A player who
sees "ten green biters threw themselves at my north wall and died" has been told something, and a careful one goes
and checks the north wall's ammunition. Against Grubstake and Kessler-Hayashi, losses mean a raid turned back; here
losses are the method. *Careful base:* no dry turret, no dark turret, and ammunition delivered by belt or robot,
which the player already wants. The probe also makes the fairness table honest: the biotech never reads a turret's
inventory or its energy, it reads whether it shot (`on_entity_damaged` with the turret as cause, on the probe's
members).

**The trail.** *Before:* from the pen's gate toward the base, a track of trampled ground (dirt tiles by script,
`set_tiles`, never inside the player's wall or on the player's floor) that the scout walks first. On the map a
brown thread from a pale pen to the base's edge. *During:* the herd walks it. *After:* it stays, and the next wave
walks it again, so the player knows where the next one comes from before its scout appears. *Must do:* read the
ground. Fortify where the trail ends. Or go up the trail: it leads to the pen that sent the wave, and the pen is
the thing to kill. *Learn:* the first wave lays it. *Careful base:* turrets at the trail's end, and a trail that
ends at a face with a flamethrower is a trail the biotech gives up on (its scout dies there; section 5). The trail
is also the biotech's memory made visible (section 5): it remembers the breach because the trail ends there.

**Withdrawal.** *During:* the herd kills what it came for and turns, as one, back through its breach and up the
trail, fighting only what hits it (`distraction = by_damage`). *After:* the breach is open and empty; the trail
leads away. *Must do:* repair the breach, and decide whether to chase (a herd going home through its own gap is the
easiest target it will ever be: the player's answer to a wave can be a sally into its back, which is new). Against
wild biters the wave fights until it is dead; against Kessler-Hayashi the assault holds what it razed. The trial's
bleed-out (the herd idle in gun range after the power fell) is the behaviour to delete; a pack that idles is a swarm.

**The supply target.** The user's decision stands: power, ammunition, the defence's supply. Framed so it is not
the blackout: the herd goes for *whatever feeds the guns that it can see from inside the breach*, generators and
substations for lasers, the inserters and belt or chest feeding gun turrets, the pipe feeding flamethrowers, the
first it sees, not a surveyed cut outside the wall. Kessler-Hayashi reasons about the player's pole graph from a
radar (the engineer's cut); the pack breaks in and goes for the warm thing (the animal's). The player's experience
differs where it matters: the blackout happens outside the wall before any raid, the biotech's inside the wall
during one. *Careful base:* what feeds the guns under the guns. That is one principle, and it covers power,
ammunition and oil at once, so a second power source alone (the blackout's counter) does not beat a biotech wave at
a gun-turret wall fed by belt. Keep "a second power source" as a counter for laser walls (the table found it), and
add the belt and the pipe to what the herd can take, so the principle is the lesson and not one building.

**Side choice and the narrow breach** stay as built: they are what makes the scout matter, and nothing the player
remembers. Do not add Grubstake's A* round known turrets to the march: the herd walks the trail, the trail was laid by
the scout's loop, and the loop is the only intel. A straight, visible march is part of the tell.

**Split** is mass used well, for the tier where waves are large: two herds from two pens, one trail each. The player
sees two trails and two scouts. Defer it; it costs nothing in design once one herd works.

**Feint** only matters against something that moves: the player's squads and character, robots, tanks. Turrets do
not move, so a feint against a turret wall is a probe with more biters. Build it when the staging look reads mobile
defence (`mobile()` in intel.lua already counts it), at the tier where the player fields an army, and make the feint
a loud probe: the player sees a group attacking the far face and the pack come in at the marked one. Last in order.

**Labs:** no. Nothing about an animal wants a lab, and a wave that kills the player's research reads as a scripted
punishment with no tell for it. The biotech's targets are the defence's supply, the breach, and (section 6) the
polluters it feeds on. If the user wants the biotech to want something of the player's beyond room, the brief's open
question, make it the pollution: the pens follow the cloud, and that is a want the map shows.

## 4. The tell: how loud, how long, what it says

Three tells in sequence, all in the world, none in chat, each the next one's reason:

1. **The pen fills.** The biotech's pens (captive-spawner art on a held nest) crowd visibly as they reach their
   unit cap: biters milling at the gate, more each minute. From the first consult: a visible clock on the farm. A
   player who scouts the pens sees the wave before it exists.
2. **The tracker.** The loop with pauses, then the mark. Loud enough: tinted, an icon over it as raid leaders have,
   and a chart marker in the biotech's colour (section 10 on the mechanism). Not louder: no sound at the base, no
   text. It should take 60 to 120 seconds (a medium biter walks about 14 tiles a second; a loop of radius 66 is
   about 30 seconds of walking, so the pauses carry the time: four to six stops of 8 to 12 seconds each, the walk at
   the engine's pace). A scout that walks without stopping is a biter passing by; the stops are what reads as looking.
3. **The herd gathers and marches.** At the pen's gate the herd gathers for about a minute (the engine's unit group
   `gathering` state; `on_unit_group_finished_gathering` fires), a dense green mass on the map, then walks the trail
   to the sitting scout. A sound at the pen when it leaves (`play_sound` at the position, heard by players near it;
   the engine plays nothing for an uncharted spot), so a player at the farm hears it go.

Tell to strike: 3 to 6 minutes from the scout's first appearance (loop 1 to 2, gather 1, march 1 to 3 at 150 to
300 tiles). That sits between the rig's 2.5 and the prospect's 10, and the clock is visible the whole way: scout,
then mass at the gate, then mass on the trail. On waves with a probe, the probe lands about two minutes before the
herd, so a player who missed the scout gets a second, louder tell.

Should the player read the target from the tell? The face: yes, the sitting scout is the mark, and the trail (from
the second wave) says it before the scout does. The thing inside: by principle, with no per-wave signal. "It goes for what
feeds the guns" is learned once, from the first wave's result (the generators dead, the turrets standing), and
holds for every wave after. A per-wave signal of the target inside would make the counter "move that one thing",
which is a chore; a principle makes the counter a base shape.

## 5. Fairness: counters, memory, escalation

**The counter set.** The table's three stand, restated as what a player builds:

| Counter | Beats | What it costs the player | Also beats |
|---|---|---|---|
| Reach past the loop on each face (a flamethrower a face, or outer turret pairs) | the scout: a blind wave | a flamethrower and oil per face | nothing else (Grubstake's raids and K-H's mortars stage beyond 30 as well) |
| What feeds the guns under the guns (power, ammunition line, oil, inside turret reach: an inner keep) | the supply target | turrets inside, not only on the perimeter | nothing else; K-H's mortars punish the perimeter, Grubstake punishes outposts |
| A second feed (power source, ammunition route) | the supply target on laser walls | redundancy | K-H's blackout (the overlap to accept; redundancy is one lesson) |
| No dry or dark turret | the probe | logistics the player wants anyway | wild biters |
| Repair the breach, fortify the trail's end | the follow-up | attention to the ground | nothing else |

Two things that must not be counters: more turrets spread evenly (the trial says it is not; good, that is
Kessler-Hayashi's answer and it should not be the biotech's), and clearing every nest in 500 tiles (the pens are
the source; clearing them is the player's strike, and it should be a fight, since a pen is a corporation's building
with worms and its garrison, not a wild nest).

**What it learns.** Animal sight only, and each thing it learns is on the ground:

- The scout's death: a marker at the spot (the intel's death markers exist, `b.intel.markers`). The next scout loops
  wider on that bearing (the loop radius on that arc is the marker's distance from the base plus 5), or comes from
  another bearing. So killing the scout wins this wave and makes the next one harder to shoot on that face, which keeps
  the counter alive without making it the whole game. After three scouts dead in a row from one pen, that pen rests
  on this base for 20 minutes and its wave goes somewhere else (another target, or a Kessler-Hayashi siege column in
  the open, section 8). The player who kills scouts has won that exchange, and should see the pen's crowding spill
  elsewhere.
- The breach and the kill: the trail ends there, for 20 minutes. The next wave's scout walks the trail first and
  checks the breach face; if the face now fires (a probe, or the scout's own sight of turrets within 30 of the
  breach), the loop is walked in full and a new face chosen; if not, the follow-up goes straight in. The player
  sees the scout check the old breach, which is the tell that it remembers.
- The probe's answer: which turrets fired. Kept for one wave only.
- Nothing from radars, nothing from the other corporations' intel. It has no radar and no sensors (it is a farm);
  `intel.sense` from a lander or depot is not for it. Its knowledge of the base is the sum of where its animals
  have been, and the trails show the player exactly that.

**Does killing scouts teach it to send more scouts?** No. Two scouts at once would halve the counter, and the
player would read it as the script cheating. It teaches a wider loop and a different face; at the top tier a
second scout comes from another pen on another bearing, which the player sees as a second trail.

**Escalation without a ceiling.** Four levers, in the order to pull them, each with its own tell: numbers (the
wave is the pens' fill; more pens, more biters; every pen is visible), the probe (tier 2; it costs the biotech
stock and tells the player more), breeds (section 7; each breed is a new silhouette and a new counter), and split
(tier 3; two trails). What never escalates: the scout rule (a dead scout is a blind wave at every tier), the march
being visible, the withdrawal. Cunning beyond this repertoire (hidden intel, instant strikes, targets with no tell)
is where it would stop being fair, and the design should refuse it rather than balance it.

**Mega waves.** The user's phrase, and the trial used 40. A wave of 200 cannot be scouted away by any counter
above; numbers at that scale beat shape. So the mega wave is an event at the top of the ladder, never the default:
it needs several pens full at once (a clock the player can see on three pens, not one), its gathering is longer (a
mass at three gates), and it is the one wave that spends a probe on every face first. Between mega waves, waves of
20 to 60 with the full repertoire. A corporation that sends 200 every ten minutes is a deathworld with a logo, and
the regression bar for that is the campaign instrument's cost columns.

## 6. After the strike

Four options were on the table: withdraw, hold, feed, nest.

- **Withdraw** is the rule, for every wave: the kill, or 90 seconds in the base, or half the herd lost, and the
  herd turns home through its breach. The pack holds nothing. The trial's idle bleed-out is what withdrawal replaces.
- **Hold** is Kessler-Hayashi's (the assault stays, the Line moves up). Never.
- **Feed** is a bounded sweep before withdrawing, for tier 2 and up: the herd attacks the polluters within 25 tiles
  of what it killed (furnaces, boilers, drills: the engine's own notion of what biters attack) for up to 30 seconds,
  then withdraws. It ties the wave to the biotech's want (the cloud is its food) and gives the player a second thing
  to defend inside, which gun turrets (needing no power) can do. It should look like feeding: the herd standing on
  the machines, chewing. Keep it short; a long feed is a hold.
- **Nest** (a pen planted in the breach) is the strongest image and the one to be careful with. Inside the wall it
  is a permanent occupation and a chore; the player's wall gap grows biters. I would not do it inside. Outside, at
  the trail's end, 30 to 40 tiles from the wall, a forward pen at the top tier would shorten the tell and make the
  trail a road, but it is a third "thing built outside your wall out of turret reach" after the mortar site and the
  claim rig, and the player's answer (kill it) is the same. Park it. If it is ever built, it is a nest the player
  sees being dug (a dust line, as the rig), and clearing it is an attack on the biotech, which is the standing cost.

## 7. Scaling over the game

Scale by the biotech's own evolution and its pens, not by the player's research. The engine already breeds by the
pen's force evolution (the test of 2026-10-22), so the biotech's evolution is a number the mod sets from what it has
eaten (pollution absorbed by its pens, `absorbed_pollution` is readable per spawner) and how long it has stood. Its
level (the corporations' ladder) then unlocks the repertoire:

| Tier | Intelligence | Breeds | The player sees new |
|---|---|---|---|
| 0 (landing) | the tracker, side choice, narrow breach, supply target, withdrawal, the trail | tinted small and medium biters | a biter that circles, a herd that leaves |
| 1 | the follow-up on the breach, the scout's wider loop after a death | acid spitters (the tinted medium spitter: puddles that slow; a ranged element that reaches 13, under every turret's reach, so it is for the player's units and for walls, not for turrets) | puddles at the breach; a scout that checks the old hole |
| 2 | the probe, the feed | the lightning breed (a biter whose bite arcs, `lp-arc-chain` as the Shock trooper's beam, built for the base game already): the counter to massed player units and to robots at the breach | a handful dying on purpose; arcs over the squad |
| 3 | split (two pens, two trails), the mega wave as an event | the fire breed drawn with the demolisher's effects (its death leaves burning ground where it fell: a biter that burns the wall it dies at; fire against the player, not against the biotech, so flamethrowers stay the player's counter) | two trails; ground on fire in the breach |
| 4 (late Nauvis) | feints against the player's army; the second scout | the Nauvis-bred stomper (Space Age's small stomper on its force: the wall-breaker and the anti-vehicle piece; rockets and slugs are its counter, from the arena's expectations in the first consult) | a thing that steps over the wall |

Each breed must be a new silhouette, a new counter and a reason the arena puts it in its own group; the first
consult's arena rows apply to every one of them. Two cautions: the lightning breed and Kessler-Hayashi's Shock
trooper share a weapon, so the biotech's must look like an animal (an arc from the bite, no beam weapon), and a
demolisher-fire breed must never burn the biotech's own herd or its breach into a firewall the player did not light
(the base game's fire burns anyone; its spread is the risk, so use the demolisher's visual with a short `fire` that
does not spread).

Intelligence by tier is the right shape for one more reason: the first consult's biggest risk was "a deathworld
with a logo", and tier 0 as written above is a wave of 20 to 40 with a visible scout, which a first-hour base with
four turrets and a flamethrower beats. The cunning arrives one piece at a time, each with its tell, as the player's
base grows the shape that answers it.

## 8. The other two in war

- **Kessler-Hayashi.** At war on sight (it clears nests; the pens are nests). The useful relation is the pack
  preying on the engineers in the open, with no coordination against the player: a siege column (hauler, mortars, guards)
  36 tiles outside the player's wall is exactly what a herd beats (no walls, few turrets, infantry that stock heals
  through). So a pen whose scout finds a Kessler-Hayashi siege site near its target takes the site first. The player
  sees two rivals fight at their doorstep, the mortars die, and the herd then withdraws or, if the pen's wave was
  for the player, carries on to its mark. That is "alliances against a third" with no diplomacy code: the player can
  pull a siege onto a pen's trail. Do not script "strike while Kessler-Hayashi besieges" as a joint operation: the
  threat budget (1 + era operations against a player at once) should keep counting the biotech's waves, and two
  corporations hitting one base at once by design is not fair. Opportunism through the scout's eyes only: a face
  the mortars darkened is a face the scout sees as quiet, with the same tell as any other.
- **Grubstake.** Neutral at first, as decided. The engine test shows the pact does not cover bred biters (a herd
  took a Grubstake-like camp while the wild nest watched), so no code is needed for the break: when a trigger fires
  (its claims or strips reaching a pen, a raid on its stock, a pen starved), the biotech's stance toward Grubstake
  goes to enemy and the same repertoire runs against Grubstake's camps, scout and trail included. The player sees
  a trail from a pen to a Grubstake camp, which says what happened without a notice. Grubstake's counter is its
  fliers (the herd cannot shoot up; harriers and scavengers are the farm's natural raiders, from the first consult),
  which gives Grubstake's Wheels branch a second job. One thing to guard: a Grubstake camp sitting in biter country
  behind its pact used to be shielded by the nests; a pen among those nests is not shielded from the biotech, so
  Grubstake's safest ground becomes the biotech's hunting ground. That is a good reversal and should be measured, not
  assumed (a `rivals`-style run with a pen beside a pacified Grubstake camp).
- **The ledger.** Kessler-Hayashi bills the waves the player's cloud draws. A bred wave must never be billed: the
  ledger's attribution is by nest and by the enemy force's attack groups; the biotech's herds are on its own force,
  so the ledger should not see them, and a check in the first slice's scenario should say so (the bill unchanged
  across a wave).

## 9. First slice, and the trials that prove it

**The slice: the tracker and the herd.** One pen on a captured nest (the engine test's pen), one base, one wave:

1. The pen fills to its cap (visible crowding at the gate).
2. The tracker: one tinted biter with the leader icon and a chart marker, the loop at 29 outside the outermost
   turret the scout has seen shoot (first loop: laser reach plus 5), four to six stops of about ten seconds, then
   the mark: it sits at the face with the fewest turrets seen within 40, facing the wall. Scout killed before the
   mark: a blind wave (the plain wave) from the pen, and a death marker.
3. The trail: dirt tiles from the pen's gate to the mark, laid as the scout walks (never on the player's floor,
   never inside their wall).
4. The herd gathers at the gate for a minute (a unit group, `gathering`), then walks the trail to the scout,
   leader icon over one of them, fighting only what hits it.
5. The breach: the two wall pieces at the mark; through; the supply target: the first of generator, substation,
   turret-feeding inserter or belt, or pipe feeding a flamethrower, within 40 tiles once 15 inside, with
   `distraction = none`.
6. Withdrawal: on the kill, or 90 seconds inside, or half lost: back through the breach and up the trail to the pen;
   the trail stays 20 minutes.
7. Attribution: every member a biotech prototype, the chart marker and the icon, the trail, the ledger untouched.

Nothing else: no probe, no feed, no breeds, no memory beyond the scout's marker and the trail. That is about the
size of the flare (`flare.lua`) plus the trial's spike, and it shows the whole personality: looks first, comes in on
a line, leaves.

**Trials, all headless, in `tests/lp-sim` as a scenario `herd` with `LP_MIX` variants** (the trial's two bases
rebuilt in the harness: lopsided and even, a wall ring of radius 40, 7 lasers and 5 gun turrets, 40 bred biters):

| Variant | Setup | Pass |
|---|---|---|
| `herd` | lopsided, one power source in the middle | the power dead; fewer than half the herd lost; the herd home (no member within any turret's reach 120 s after the kill) |
| `herd tell` | as `herd` | the scout's marker exists at least 90 s before the first wall damage; the herd's gathering lasts at least 60 s; first wall damage at least 180 s after the scout's first position |
| `herd keep` | the source under the heavy side's guns | power up; the herd withdrew at the 90 s limit or at half, and did not idle (losses after the last kill under 25% of those before) |
| `herd second` | a second source | power up (one source lost at most); withdrew |
| `herd scout` | two gun turrets on the loop | the scout dead before the mark; a blind wave; all dead or withdrawn; the death marker set; a second wave 10 minutes later loops wider on that bearing (its loop points there at least 5 farther from the base) |
| `herd belt` | gun turrets fed by belt and inserters from a chest in the middle, no lasers | the belt or inserters within 40 of the breach dead, the turrets standing |
| `herd trail` | as `herd` | dirt tiles from the gate to the mark; none inside the wall; none on the player's concrete; the trail present 15 minutes later and gone at 25 |
| `herd again` | as `herd`, the breach repaired at minute 5 and that face given three lasers | the second wave's scout visits the old mark first, then loops; its new mark is on another face |
| `herd wild` | a wild nest 60 tiles from the trail | no wild biter in the group; no damage between wild and bred; the ledger's bill unchanged |
| `herd blind` | the scout's sight set to 0 (the control) | the plain wave's result: all dead, power up |
| `herd mega` | 200 bred biters, the same lopsided base | ms/tick under the regression's bar; the tell still at least 180 s; the result recorded, not asserted (it is the balance question for `scripts/balance`-style sampling later) |

Then, before any tier-1 work, the first consult's arena rows (equal spend; clustering in its own group; the long
fight against gun turrets on yellow ammunition) for the tinted medium biter as the stock unit, so the herd has a
weight before it has a repertoire. A guard seen failing first: run `herd keep` with the keep's turrets removed and
watch it fail.

## 10. Engine claims

Checked in 2.0.77's `runtime-api.json` and `prototype-api.json`:

- Commands on `LuaCommandable` (units and groups): `attack`, `attack_area`, `go_to_location` (with `radius` and
  `pathfind_flags`), `stop` with `ticks_to_wait` (the scout's pauses), `wander`, `flee` (from an entity: the
  withdrawal under fire can use it), `compound` (`logical_and`, `return_last`); `distraction` `none`, `by_damage`,
  `by_enemy`. `set_distraction_command` for a one-off (aim.lua uses it). Groups: `create_unit_group`, `add_member`,
  `start_moving`, `state` (`gathering`, `moving`, `attacking_target`, `finished`), `is_script_driven`;
  `on_unit_group_finished_gathering`, `on_unit_added_to_group`, `on_unit_removed_from_group`.
- Spawners: `max_count_of_owned_units`, `spawning_cooldown`, `absorptions_per_second`, `captured_spawner_entity`,
  `time_to_capture`, `call_for_help_radius`, `max_darkness_to_spawn` on the prototype; `absorbed_pollution` and
  `spawning_cooldown` readable on the entity; `release_from_spawner` on a unit. The pen's cap is the wave's size
  by construction.
- Units: `vision_distance` (30 for vanilla biters; the prototype doc warns that 50 or above lets units form groups
  on their own), `radar_range` in chunks (a unit charts for its force; the scout can chart the base for the
  biotech's force, if the force's chart is ever wanted), `light` (a leader lit at night), `map_color` on the entity
  prototype (the herd's dots on the map in the biotech's colour, which is the map attribution).
- Sight by script: `find_entities_filtered` by position, radius and type each half second (the trial did it), and
  `on_entity_damaged` carries `cause` (the probe reads which turrets fired).
- `LuaEntity.color` is writable on characters, vehicles, corpses and lamps only, not on units: the tint stays in the
  prototype, as the test did.
- `rendering.draw_sprite` attached to an entity with an offset (raid leaders), `draw_light` (the leader at night,
  `minimum_darkness`), both with `forces` or `players` filters.
- Chart tags: `LuaForce.add_chart_tag` needs the chunk charted by that force (the player's base is, by the player);
  `LuaCustomChartTag` has no position write, so a moving marker is a destroy and re-add each second (cheap).
- `play_sound` at a position is heard only by players for whom the spot is charted.
- Death markers and cells: `b.intel.markers` and `targets` exist; the biotech's intel should not call `intel.sense`
  from static sensors (it has none) but can reuse the marker and the target record.

Not yet spiked, and the slice depends on the first three:

- Whether a unit group of bred biters on a script force, given `go_to_location` with `distraction = by_damage`,
  walks a 300-tile trail without breaking up (the engine moves groups in about 100-tile legs; one run of the test
  never reached its target on an unseeded map).
- Whether a `stop` with `ticks_to_wait` in a compound command with `go_to_location` legs gives the pauses (the
  jumper's hands use compound orders ending in a stand, so it should).
- Whether `set_tiles` under the player's charted chunks redraws the map for the player at once (it should; the
  claim rig's mound uses entities, not tiles).
- Whether `LuaRendering`'s `render_mode` (present on `draw_light`'s parameters) draws a sprite in the chart view,
  which would make the scout's map marker a rendering rather than a tag.
- `on_entity_damaged` firing for a turret's damage to a biter with the turret as `cause` for laser beams (beam
  damage is dealt by the beam entity; the `cause` may be the turret or the beam: check before the probe is built).

## 11. Recommendation

Build the pack. Keep the trial's skeleton (scout, side, breach, supply target) and make the
player's memory of it the three habits: it looks first with one animal, it leaves the way it came and the trail
stays, and from tier 2 it spends animals to learn. Drop labs. Reframe the power target as "what feeds the guns" so
the counter is a base shape (an inner keep, a second feed, nothing dry or dark) and not the blackout's one trick.
Keep the scout rule at every tier and let a dead scout teach a wider loop, never a second scout, so the counter
stays worth building and never becomes the whole game. Make the mega wave an event with three pens' clocks on it.
Treat Kessler-Hayashi's siege columns as prey and let the player steer them onto a trail; never script a joint
strike. First slice: the tracker and the herd, one pen, one wave, the eleven `herd` variants above, then the arena
rows before any breed. What the player tells a friend: "Grubstake robs you at night, Kessler-Hayashi draws a line
and shells you, and the farm sends one green biter to walk round your wall, and if you do not shoot it, forty come
in where it sat, eat your generators, and walk home the same way."
