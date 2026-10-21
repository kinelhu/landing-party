# A biotech corporation: identity first (Fable), 2026-10-21

Read-only consult on candidate D of `docs/third-corporation.md`. The user: "A little worried because Grubstake is
already a little biter themed with the flare attacks." The candidate as written: a corporation that "breeds and steers
biters and Gleba's pentapods, sells the player nest clearing or sends the waves; regenerating, cheap, expendable army;
acid damage; spawner farms; eggs that spoil."

Read: the options paper, `docs/campaign.md` section 4, `docs/corporations.md`, `docs/arena.md`, `docs/units.md`,
DESIGN.md (status table, the pact, the clearances, the flare, nest country), `scripts/flare.lua`, `pact.lua`,
`ledger.lua`, `biters.lua`, `data-final-fixes.lua`, `units.lua`, `corps.lua`, `tests/lp-arena/{arena,batch}.lua`, and the
2.0.77 API for every engine claim below (noted where a spike is still needed).

## 1. The verdict on the overlap

The worry is right about the candidate as written, and wrong about biotech as such.

As written, D repeats both neighbours on their own ground. "Sends the waves" is the pheromone flare with different
smoke: wild biters pointed at the player by a corporation. "Sells nest clearing" is Serenity's clearance and its invoice
post. "Steers biters" is what the flare's canister does. Those three verbs are the overlap, and all three are the
candidate's *services*, not its nature.

Strip them and what is left is a relationship to biters that neither corporation has. Grubstake **pays** the biters (a
cease-fire, an antenna) and borrows them for three minutes at a time; they stay wild, on the enemy force, and go idle
when the canister dies. Serenity **exterminates** them (railgunners, cluster shells, the barrage) and bills the player
for the trouble. Nobody **owns** them. A corporation whose army is hatched in its own pens, on its own force, fed from
its own belts, and culled when there are too many, is the third stance, and the one the world's three-way war has been
missing: biters as livestock.

So the verdict: biters are not the problem; the verb is. Every corporation must have a stance on the world's third
party (the options paper already says both fight them). What must not repeat is Grubstake's *calling* and Serenity's
*clearing and billing*. The identity below does neither. Nothing in Grubstake has to change to make room; two of its
pieces gain an edge from the farm (section 4). If the user wants the "sends waves" or "sells clearing" services kept,
then the honest answer is that biotech should not be third: it would be a flare with a hatchery behind it.

## 2. The identity

**Verdant Organic Solutions.** The farm. It fences the nests the player's pollution has drawn, breeds pale stock in
them, and drives the surplus at whatever will kill it cheapest, which is the player's turret line. Nothing it does is
an attack in its own eyes; it is disposal. Motto: **"Nothing goes to waste."** (Alternatives in the same register:
Bloom Organic Solutions; Halcyon Renewable Stock.)

What the player sees first is not a building. It is a nest they had been meaning to clear, now inside a pale fence
with magenta lamps on the posts, its biters bleached white. Then a dirt track leading away from it. Then, a while
later, forty white biters walking in a loose herd behind a slow vehicle toward their wall, and a second nest fenced
nearer than the first.

### The identity kit

1. **Palette.** Bone white primary (stock, fences, worms), magenta accent (lamps, map colour, the tag). White is the
   one colour no wild biter wears (brown, red-brown, blue, green by size), so a bred animal reads as bred at any
   distance and at night; magenta is unused by the two built corporations and the enemy's red. Lamps: magenta
   grow-lights on every fence post, so a pen at night is a ring of pink dots on dark ground (nothing else in the mod
   is lit that way: Grubstake amber, Serenity cold white).
2. **Logo and tag.** The biter egg with Space Age; raw fish without it (the base game's one livestock, and deadpan).
   The tag on the map over each pen and over a drover in the field.
3. **Floor.** Trampled dirt (`dirt-*` tiles set by script) for its tracks, no gravel, no plating; landfill in the pens;
   pink refined concrete only on its hatchery pad and egg dock. Its ground looks farmed, not built: the one
   corporation with no concrete road.
4. **Walls.** Fences only, and they face *inward*: a closed paddock round each captured nest, gated on the track side.
   No perimeter round the camp. The fence is Grubstake's half-health wall kind tinted white, but the shape is the
   opposite of Grubstake's (which fences depots, never production) and of Serenity's rings.
5. **Turrets.** Penned worms: a bleached small worm (type `turret`, on its force) two or three to a pen, acid, range
   25. No guns, no lasers. Worms shoot air (the `turret` type keeps the default, `data-final-fixes.lua`), so the farm
   is not helpless to harriers, but the herd is.
6. **Units.** Cull (a bleached medium biter), spitter stock (a bleached medium spitter), the stomper (Space Age: a
   bleached small stomper; base game: a big biter scaled up), and the signature vehicle, the **drover**: a slow hull
   towing a feed tank, which is the herd's leader, its regeneration and its egg truck. Section 3.
7. **Layout.** Paddocks: a loose chain of fenced pens, each round a captured nest, strung along the edge of the
   player's pollution cloud and linked by dirt tracks to one hatchery hub (the captive spawner's art with Space Age,
   a bleached spawner without; egg crates on a short belt; slurry tanks). Silhouette on the map: pale ovals with
   magenta dots, dirt threads between them, creeping toward the factory as the cloud grows.
8. **Voice.** "Verdant Organic Solutions has released 40 units of surplus stock for humane disposal near [gps]. Nothing
   goes to waste."

### Its row for campaign.md section 4

| Corporation | Role | Offence | Defence | Weak point | Wants | Biters | Temper |
|---|---|---|---|---|---|---|---|
| **Verdant Organic Solutions** | the farm (paddock) | culls: when a pen is full, the surplus is driven at the nearest thing that will kill it, usually the player's turrets; what it breaks on the way is incidental to Verdant and not to the player; never an assault, never past the first line | no walls: fences, penned worms, and a garrison that regrows while a hatchery stands | its feed: drovers and egg tracks; a herd without its drover goes feral, a pen cut from its feed goes wild; fire | nests alive, and the player's pollution cloud to feed them | farms them: fences and captures nests, never clears, never pays | placid; never retaliates, restocks; sells nothing yet |

### What the player must do differently

- **Burst, not trickle.** Stock heals. A gun turret on yellow ammunition is a trough, not a defence: it feeds the
  herd damage slower than the drover feeds health back. Rockets, cannon shells, the railgun and fire are the answers;
  flamethrower turrets come back into the meta.
- **Acid is a new column.** No player unit or turret in the roster resists it; only Serenity's walker does (50%).
  Spitter stock leave puddles that slow and burn: infantry that stands in them dies, infantry that moves does not.
  Vehicles over troopers; and a reason for an acid plate in both corporations' trees.
- **Hit the farm, not the herd.** Killing stock is attrition against a hatchery. Kill the drover and the herd stops
  healing and goes feral (section 3); kill the pen and nothing hatches; cut the egg track and the pen goes wild on
  Verdant's ground, not yours.
- **Decide about every nest near home.** Clear it now and it is gone; leave it and Verdant fences it, which is quiet
  for a while (a captured nest sends no wild waves) and then a cull every time the pen fills. Clearing a fenced nest
  is an attack on Verdant.
- **Pollution is a three-way currency.** Serenity bills it, Grubstake ignores it, Verdant eats it: its pens follow
  the cloud's edge inward. Efficiency modules and trees become a defence against a corporation.
- **Do not shoot the egg truck at your own gate.** A killed drover spills its crate; eggs that spoil hatch wild (the
  base engine's spoilage: `spoil_to_trigger_result` is on `ItemPrototype`; Space Age's biter egg hatches a big biter
  per 25 eggs after 30 minutes). Loot it, and the eggs spoil in your own chest.

## 3. Signature units

First calibrations, priced as the arena prices things (Serenity's rifle: 10 parts, 120 health, 16.8 damage a second
at 15 range). Stock is hatched, not bought, so the price is a *weight* for the threat budget and the arena, not a bill
(section 5).

| Unit | Health | Heal | Shot | Range | Rate | Speed | Resists | Hits air | Weight |
|---|---|---|---|---|---|---|---|---|---|
| **Cull** (bleached medium biter) | 150 | 1.5/s, 4.5/s near a drover | 12 physical, melee | 1 | 1.7/s | 11 tiles/s | physical -2 10%, acid 60%, fire 0% | no | 8 |
| **Spitter stock** (bleached medium spitter) | 120 | 1.5/s, 4.5/s near a drover | 14 acid plus a puddle (6/s for 10 s, slows 40%) | 13 | 0.7/s | 9 tiles/s | physical -2 10%, acid 60% | no | 14 |
| **Stomper** (SA: small stomper, spider-unit; base: big biter at 1.4x) | 1,200 | 6/s, 12/s near a drover | 50 physical over 2.5 tiles, melee stomp | 3 | 0.7/s | 5.4 tiles/s | explosion 20%, acid 80%, no flat physical, fire 0% | no | 90 |
| **Drover** (hauler hull towing a tank) | 600 | 0 | none (a prod: 5 electric, range 3, for show) | 3 | 1/s | 7 tiles/s | physical -3 20%, acid 80% | no | 40 |

- **Heal** is the engine's `healing_per_tick` (base: 0.025 a tick is 1.5/s; vanilla biters run 0.01 to 0.1; the mod
  sets its own units to 0 in `units.lua`, so stock are the first that heal) plus the drover's feed: 2% of max health
  a second within 20 tiles of a living drover, by script, the field-repair pattern already built for the barracks.
- **Feral.** A herd whose drover dies mills for ten seconds and then changes force to the enemy (`LuaControl.force`
  is writable). Feral stock keep their white: forever attributable, and Grubstake's flares can call them like any wild
  biter. They attack whatever is nearest, which near Verdant's ground is Verdant; the player chooses where to kill the
  drover.
- **The railgunner's tag.** `data-final-fixes.lua` gives `lp-biter` to every unit, spawner and turret not named
  `lp-`; stock named `lp-verdant-*` would escape the railgunner's 250. Tag the cull, the spitter stock, the worms and
  the pens deliberately (they are biters), not the stomper or the drover. Serenity's nest clearer becomes the hard
  counter to the herd and nothing else; the stomper is the farm's answer to it.

**Placement in the web.** A fifth class, **stock**: living bodies with no flat armour that heal, fight at melee or
short acid range, and cannot shoot up. By class, expected before the arena says otherwise:

| Stock against | small arms | splash | armour | air |
|---|---|---|---|---|
| expected | wins long fights (heals through the trickle; closes) | loses hard (one weapon hits the whole herd: prism, shock, tesla, sapper, the scorcher's flame, the scrap cannon, flamethrower turrets) | even to winning (a cannon's 1.5 s shot kills a cull in four; the herd arrives first), except the stomper, which rockets and slugs burst down | loses completely (it cannot touch a flier; the farm's worms can) |

The new column it adds: regeneration (a unit that wins the long fight and loses the burst), a damage type nobody deals
(acid), and a class with no anti-air at all, which makes Grubstake's harriers and scavengers worth more than they are
today. The arena's clustering (section 5) is the proof that it is a column and not a copy of Grubstake's infantry.

## 4. What it does to the others, and to the player's choices

**Grubstake.** Nothing has to change in its code. Two of its pieces gain by contrast and one loses by accident:
- The flare calls idle biters and nests of the *enemy* force (`flare.lua`: `force = "enemy"`). A nest Verdant fences
  is no longer enemy force, so a farm beside the player's base quietly takes the flare's ammunition away. That is a
  reason for Grubstake to hate the farm without a line of new temper: its pact-shielded camps find their shield
  bleached and fenced. (A feral herd puts ammunition back.)
- Its harriers and scavengers are the best raiders of a farm (the herd cannot shoot up; the worms can). A later
  heist writes itself: a buggy cuts a fence and the pen goes feral on Verdant's ground.
- Stolen eggs spoil in Grubstake's yard into wild biters, which its pact makes harmless to it. Deadpan, consistent,
  free.

**Serenity.** The natural war, and it needs one rule. Serenity clears nests; a fenced nest is both a nest and a rival's
building. Let it clear the pen as a hazard (its railgunners one-shot the stock; its cluster shells are the counter to
a pen) and let Verdant count that as an attack: the exterminator and the farm at war on sight, which the campaign asked
for (alliances against a third). The ledger: a bill names a wild nest and is disputed by killing it; a captured nest
sends no wild waves, so the bill it names stops growing. Verdant fencing a nest is, in effect, paying Serenity's invoice
for the player, and taking the dispute off the table. That knot is a feature if the world shows it (the billed nest's
icon and the fence on the same spawner) and a bug if it does not.

**The player's choices**, new ones only: whether to clear a nest before the farm fences it; whether to pollute toward
the farm or away from it; fire and splash in the defence again (the first corporation whose answer is a flamethrower
turret, which the two built ones made nearly useless: Serenity's masonry, Grubstake's fliers); where to kill the
drover; whether to loot eggs. And one trade with no UI: a fenced nest beside the base is a quiet neighbour until the
pen fills, which the player can read by the crowding (section 5), so "do I break the fence now or later" is a decision
with a visible clock.

## 5. The hardest problem, and its headless test

Not readability (white against brown is a tint and a lamp) but this: **a herd has no price.** Every army in the mod is
sized by parts it spent; the threat budget, the ladder and the arena all read cost. Stock is hatched by a spawner on a
cooldown (`spawning_cooldown`, `max_count_of_owned_units`) and heals for free. A regenerating melee swarm with no bill
is either a steamroll or a joke, and the engine's own biters show which: at scale, melee swarms beat everything but fire
and splash. The sizing lever has to be invented: a weight per head (the table above) that the budget charges as if it
were parts, a cap per pen, and a hatch rate tied to the camp's economy (its parts buy feed, feed buys hatches) so that
the farm grows like the others and not like a nest field.

Test, in order, all headless:
1. **Arena, equal spend** (`scripts/arena.sh`): add the four to `KINDS` in `tests/lp-arena/batch.lua` on a
   `lp-verdant` force (the "raw" entry already takes any prototype on any named force) with `shared.units` entries so
   `arena.cost` prices them. Pass: the cull row beats both infantries and the trooper, loses to prism, tesla, shock,
   sapper, scorcher and every flier; the stomper loses to rocket trooper, slug and battle tank and beats small arms;
   against the fixed lines, flamers 3 beat a 420-weight herd and guns 6 do not. Fail: any stock row above +60 against
   armour at equal spend (steamroll), or below -60 against small arms (joke); tune weight first, health second.
2. **Arena clustering** (`scripts/arena_report.py`): cut into five groups, the four must land in their own group.
   If the cull clusters with Grubstake's infantry, the column is a copy and the regeneration is not doing its work:
   raise the heal, lower the damage.
3. **The long fight.** The arena judges at three minutes; regeneration matters over minutes. One mode with
   `arena.LIMIT` at ten minutes: a herd of 30 against 4 gun turrets on yellow ammunition should still stand at ten
   minutes with the turrets dead; against 3 flamethrower turrets dead inside two.
4. **Scenario `cull`** (the `flare` scenario's shape): a pen with a captured spawner, a drover, a player outpost 150
   tiles off with two gun turrets. Assert: the herd leaves within a minute of the pen reaching its cap; health under
   fire rises between shots (a cull under one turret at 30 s is above half); the drover killed at 60 s: every cull on
   the enemy force within 10 s, white, and attacking the nearer thing (Verdant's own fence if it is nearer); the pen
   hatches nothing while a player unit stands within 12 of it; a drover killed carrying a crate: eggs on the ground,
   and at their spoil time wild biters at that spot, counted by `on_entity_spawned` not firing (they are trigger
   spawns) and by a count of enemy units in 10 tiles.
5. **Readability in the dump** (no eyes needed): every stock prototype's tint must differ from every wild biter's by
   a luminance margin (0.4 of the range) in `data-raw-dump.json`; the fence lamp's colour by a hue margin from both
   corporations' lamps. A guard seen failing first: run it with the margin at 0.9 and watch it refuse.
6. **Engine spikes before any of it** (a throwaway mod in its own profile): does a `unit-spawner` on a force with
   `ai_controllable = false` spawn at all, and absorb pollution (`absorptions_per_second`), or must the hatch be
   scripted; do the biter mask layers take a near-white tint without washing out the body; does the captured spawner
   (`captured_spawner_entity`, `time_to_capture`) work for a force without the capture robot, or does the base-game
   fallback (replace the spawner with a copy on Verdant's force) have to carry both games; does `force = "enemy"` on
   a unit inside a unit group leave the group cleanly.

## 6. Risks, and what I would not do

Risks:
- **Steamroll by numbers.** The engine's cheapest unit, healing, in a herd. The weight and the pen cap are the whole
  balance; without the arena rows above passing, the farm is a deathworld with a logo.
- **Two art sets.** Space Age gives the captive spawner, the egg, the stomper; the base game gets bleached copies and a
  scaled big biter. Both must read as the same corporation, and `tips_check`-style runs of the base game alone are the
  only guard.
- **Attribution.** The rule "a wave the player cannot attribute is an unfair wave" holds twice here: for culls (white,
  with a drover, from a pen, on the map) and for feral stock (still white). The one place it can fail is spoiled eggs
  hatching wild and brown near the player's outpost; the crate on the ground is the tell, and the hatch should be
  bleached too (its own egg item with its own trigger, not Space Age's).
- **UPS.** Biters are cheap; the heal aura is a periodic find round each drover, as the barracks' repair is. Cap
  stock per camp and the aura to one pass a second.
- **Scope.** `corps.lua` copies the default corporation's prototypes; Verdant's base kinds (spawner, worm, biters,
  drover) are new kinds in `shared.KINDS` with `bases` as Grubstake's shotgun hand is, plus a hatch loop, the feed,
  capture, culls and feral. About the size of Grubstake's flavour pass, not of Serenity's cordon.

What I would not do:
- No cease-fire with the wild biters. The farm fences and culls them; the pact stays Grubstake's alone.
- No calling, steering or pointing of wild biters, and no wave sold or sent as a service. The cull's target is the
  nearest killer, which is the player only because the player's turrets are nearest.
- No nest clearing sold, no invoice. Verdant removes nothing and bills nobody. Its one "offer" is the fence itself.
- No chat. The pen's crowding is the cull's clock, the fence is the claim, the drover is the leader icon, the crate on
  the road is the spoil timer, white is the attribution.
- No air, no lasers, no walls, no artillery for it, ever. Its helplessness against fliers is a counter the user asked
  for, not a gap to fill.
- No contracts UI now. Selling eggs or stock to the player at standing belongs to the market layer (Concord), if
  that layer comes.

What the player tells a friend: "Serenity shells you, Grubstake robs you, and Verdant fences the nest by your wall,
breeds it white, and walks the extras over to your turrets to be put down."
