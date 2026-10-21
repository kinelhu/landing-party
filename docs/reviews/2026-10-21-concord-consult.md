# Concord Munitions: identity first (Fable), 2026-10-21

Read-only consult. The user: "The user is weighing a THIRD corporation and asked for an identity consult on: CONCORD
MUNITIONS (the dealer), designed on 2026-10-13 but never built. As designed: tanks and walkers in numbers, garages, big
garrisons, sandbag lines, raids the weakest neighbour (corporations included), claims beside whoever is fighting, sells
units to the other corporations (its level gating what they field) and to the player at good standing. Since then,
walkers and tanks went to Serenity; the player got a barracks with command bandwidth. The options paper rated it: little
new in its own fights, a strong effect on the other two (a market), cheap units, an expensive trading layer. [...] The
sharp question: as designed, Concord's own fights are armour in numbers, which the web already has. Find what makes
fighting it, and dealing with it, new: is the dealer the identity (and how do its sales show in the WORLD, without chat
notices or a big UI), or does it need a combat signature of its own?"

Read: `docs/third-corporation.md`, `docs/campaign.md` (4, 7, 12), `docs/corporations.md`, `docs/arena.md`,
`docs/units.md`, DESIGN's status table and the passages on standing, the pact, the trade post, the ledger and corporate
research; `scripts/trade.lua`, `standing.lua`, `pact.lua`, `ledger.lua`, `rd.lua`, `army.lua` (convoys), `shared.lua`
(CORPS, units, POPULATION); `tests/lp-arena/batch.lua`, `tests/lp-sim/control.lua` (`tribute`, `rivals`).
Engine claims checked in `runtime-api.json` and `prototype-api.json` for 2.0.77.

## 1. Does Concord as designed still earn its place?

Half of it does. The half that does not is the half the 2026-10-13 kit spends most words on.

- **Armour in numbers, garages, big garrisons, sandbag lines**: no. Tanks are Serenity's from landing, walkers at its
  level 2, the Aegis in its Line branch; the player has battle tanks and rocket troopers to answer them. The arena's
  armour row is full. A third corporation that fights with olive tanks is Serenity without the line, and the line is
  what the player remembers. "Garrison, not walls" is a layout choice, not something the player feels.
- **The dealer**: yes, and it is the only candidate on the paper that changes how the other two play. The paper is
  right that its fights alone are not new. The mistake in the original kit is to give the dealer a soldier's signature
  and leave the dealing as a line of campaign text. Turn it round: everything Concord does in the world, including how
  it fights, should be a dealer's act. Then it earns its place with a small army, because the army the player meets
  more often is the one it sold to someone else.

The one cost the paper names, "an expensive trading layer", goes away once the sales are things on the road and on the
ground rather than contracts in a window. Section 4 keeps the layer to one chest, one convoy and one badge, all three
built from code that exists (the trade post, `army.convoy`, the ledger's rendered marks).

So: keep Concord, drop armour as its identity, make it the corporation whose business is other people's wars. It
should field the smallest army of the three.

## 2. The identity

**Name: keep Concord Munitions.** "Concord" is the euphemism (it is at peace with everyone because it sells to
everyone); "Munitions" says what ships. Motto, kept: "Trusted by all parties." If a softer name is wanted for the
house style, "Concord Mutual Supply" works, but it loses the joke that the goods are guns.

**What the player sees.** On the map: an olive region that appears beside a front, between two who are fighting
(Serenity's line and Grubstake's road, or beside the player's contested outpost), marked with a white flag. Olive dots
leave it on a schedule for the other corporations' camps, and the same lot ships to both sides of the same fight. On
the ground: an open lot, not a fortress. Orange pads in hazard-striped bays with hulls parked in rows, the stock on
display; sodium-orange lamps; a garage; paired gun turrets behind short sandbag lines; no wall and no gate, because
customers drive in. In fights: enemy raids with olive hulls among the ochre or the teal, each with a brass badge, and
at the back of the enemy line an olive truck with a working light, repairing what the player is shooting.

**What the player must do differently.** Four things, none of them a turret:
1. Shoot the trucks first. Focus fire is a new verb for the command tool; until now the order of targets never mattered.
2. Ambush the road. A delivery convoy is someone else's army in transit, lightly escorted, and the player already knows
   how to rob a road (Grubstake's). Killing a delivery weakens the buyer and provokes the dealer.
3. Decide whether to buy. One product, through a chest, no window (section 4).
4. Read who is spending. A badge on a Grubstake raid says Grubstake is at war somewhere and paying for it; a Serenity
   siege with trucks says the siege will not bleed out on its own.

**Temper.** Affable and mercenary. A rival to everyone from landing, an enemy only to whoever touches its stock or its
deliveries, and it stands down after an hour like Grubstake (a dealer holds no grudge against a customer). It never
climbs a ladder. Its own offence is the demonstration: a small combined-arms squad against the weakest neighbour's
exposed asset, withdrawn in order before half is lost. It never sieges.

**Weak point.** Its stock and its road. The hulls on the lot are inactive (stock, not garrison): burning them is parts
lost and sales that will not happen. Its deliveries are on open ground between camps. Its garrison guards the lot and
nothing else.

**The identity kit, eight points.**
1. Palette: olive drab primary, brass accent, a little signal red on the badge; lamps sodium orange.
2. Logo: none on the ground (as revised). Map icon and badge: `signal-white-flag` (vanilla), tinted brass. One mark,
   learned once, on its tag and on everything it sold.
3. Floor: plain concrete roads; orange refined concrete on the lot; hazard concrete as bay lines (a car park).
4. Walls: sandbags only (short single walls in front of turret pairs); no ring, no gate.
5. Turrets: gun turrets in pairs, script-fed, piercing rounds by level; flamethrowers at the garage. SA: a rocket turret
   pair on the lot (fallback: more guns).
6. Units: the catalogue (it fields one of each thing it stocks) and its signature vehicle, the **service truck**.
   Signature on the ground: trucks in every squad, and the stock parked in rows.
7. Layout: the lot. One dense hub, open ground, bays in rows on orange pads, a garage, the lander behind. Silhouette:
   big orange pads full of armour, and now the pads mean something: they are inventory.
8. Voice: "Concord Munitions thanks you for your continued interest in its products." On a delivery: "Your order has
   shipped. Concord Munitions accepts no liability for its use."

**Profile row for `docs/campaign.md` section 4:**

| Corporation | Role | Offence | Defence | Weak point | Wants | Biters | Temper |
|---|---|---|---|---|---|---|---|
| **Concord Munitions** | the dealer (lot) | demonstrations: a small combined-arms squad with service trucks against the weakest neighbour's exposed asset, corporations included; withdraws early; never sieges | garrison and service, not walls: field repair, sandbags at its guns, a big open lot | its stock: parked hulls on the lot, and its deliveries on the road | customers: lands beside a front, between two who are fighting | indifferent; sells nothing to them | affable, mercenary; sells to all parties, repossesses from defaulters; an enemy only to whoever hits its stock or its road, and it stands down |

One line for a friend: "Serenity shells you from orbit, Grubstake tunnels under your wall, and Concord sold them both
the gear and sends a truck to fix it while you shoot."

## 3. Signature units and systems

Four, in the order to build them. Numbers are first calibrations for the arena; the fights decide.

**3.1 The service truck (support: the column the web lacks).** The hauler's hull in olive with a brass working light
(a rendered light that blinks while it repairs). 600 health (soft on purpose: the hauler's 1,500 would make it a wall),
5.4 tiles/s so it keeps with tanks, 45 parts. A unit prototype must carry a weapon (`UnitPrototype.attack_parameters`
is not optional), so it has the hauler's token pistol (4 physical, range 10, hits air). Every second it repairs up to 6
allied units within 10 tiles by 1.5% of their maximum health, at least 2 a second; a unit is served by one truck at a
time (no stacking); it does not repair itself or other trucks; it never repairs buildings (that would make it a
mobile roboport, and Serenity's drones own repair of structures). Script, as the player's field repair is (2% a second
within 30 of a barracks; `health` is writable).
- Place in the web: wins long trades (small arms, lasers, turret lines that chip), loses to burst (rocket troopers at
  110 explosion, battle tanks, breacher charges), and to anyone who shoots it first. A tank under service shrugs off
  about half of one enemy tank's fire (13.5 a second against about 16 after resistance), so two trucks do not make
  five tanks beat seven; they make five tanks beat seven *infantry squads' worth of chip*. Counter-units already exist:
  the Lance outranges it (17 against 10), rockets kill it in six hits, harriers reach it over the front.
- Sold to everyone (3.4), and the one thing the player can buy (section 4): mobile repair for an army on campaign is
  new for the player, whose repair is anchored to a barracks.

**3.2 The lot: stock on the ground.** Concord's depot builds its catalogue ahead of demand and parks it in bays (12 a
lot, 24 at maturity), inactive (`active = false`: hulls without crews). A sale, a demonstration or a garrison refill
takes from the lot; the depot refills a bay every 10 s as any depot builds. DESIGN already planned "crates in the depots"
as the sign of a reserve; here the reserve is the units themselves, which is a sign nobody mistakes. A hull destroyed in
its bay is parts gone and does not fight back; the garrison (5 a depot, as today) answers the alarm. Engine cost: 12
to 24 idle entities a lot. The player's reading: rows full means a buyer's raid is coming soon; rows empty means it
just sold.

**3.3 The demonstration (its offence).** A raid that is a sales call. One of each kind it stocks plus two trucks (about
250 parts at level 0), sent at the weakest neighbour's exposed asset by the existing target weighing, with the abort
rule tightened to withdraw at a third lost rather than half, and never a siege. Against the player only while enemy.
Nothing new in code beyond a mix and an abort threshold; what is new is the shape the player sees: small, mixed,
serviced, gone before it is beaten. It also feeds the market: a camp that met a demonstration has losses in its ledger,
and losses are what make it order (3.4).

**3.4 Sales and repossession (the system).** Section 4 has the mechanism. The design rule here: Concord's development
level is its catalogue. Level 0: service truck, tank (olive, Serenity's stats). Level 1: walker. Level 2: the Aegis
hull. Level 3: headquarters and the prize (its designs in the player's barracks). A buyer below its own cap fields what
it bought: Grubstake with tanks is the readable change the campaign promised ("its level gates what they field"), and
Grubstake with tanks is a different raid to defend against than shotguns and buggies. Its exports are its sales, so a
war between the other two levels it up, and a long peace starves it into demonstrations.

Not proposed as a signature: long-range fire against units (the web's other gap). It is a siege weapon by temperament
and Serenity owns siege; giving Concord a field mortar would blur the two corporations the player can already tell
apart.

## 4. How the selling works in the world

The smallest layer that changes all three players. Three parts, each built from something that exists.

**4.1 A corporation buys with its research fund.** Every 10 minutes, a camp of Grubstake or Serenity that has losses in
its ledger in the last 30 minutes, a Concord lot within 700 tiles (the trade post's reach), and a fund above the price
places one order: the catalogue kind that answers what killed it (the tree already triggers on `{killer = ...}` and
`{damage = ...}`; the order uses the same lookup, so Grubstake killed by battle tanks orders tanks and Serenity bled at
an emplacement orders trucks). At most 4 units an order, at most half the fund, price 1.5 times the unit's cost (a
tank 90). The fund is debited at order; Concord's exports are credited on delivery. The decision inside the AI is the
one the player can read: a corporation that buys researches less, and a corporation that researches buys less. A
mature camp's fund grows about 9 parts a minute, so a buyer at war affords roughly three tanks an hour: visible, not a
flood.

**4.2 The delivery is a convoy.** `army.convoy` with a service truck as the hauler and the sold units as escorts that
stay. On arrival each unit's force becomes the buyer's (`LuaControl.force` is writable, by name or by force), it joins
the buyer's garrison and counts against its cap, and a brass white flag is drawn over it (`rendering.draw_sprite`
with `target = {entity = u}` and an offset, in both `game` and `chart` render modes, as the ledger marks a billed nest).
The hull stays olive because tint is baked into the prototype (`LuaEntity.color` is writable only on characters,
vehicles, rolling stock, lamps and a few others, never on a unit); the chart draws it in the buyer's colour. Olive hull,
buyer's dot, brass badge: the player learns in one fight that olive means Concord-built and the badge means sold. Hover
gives the name, "Concord Munitions tank", and the description "Sold to whoever fields it." No per-buyer prototypes
needed.
A convoy ambushed on the road spills no items: its units fight for Concord where they stand and go home, the order
is void and the fund is not refunded (the dealer was paid at the gate). Serenity's posts shoot it when the road crosses
their reach, as they shoot Grubstake's tribute truck, which makes a lot sited badly its own problem.

**4.3 Repossession.** A buyer that exported nothing for 20 minutes (its road robbed, its line cut, its lander fallen)
has defaulted. The nearest lot sends a recovery crew, a truck with two escorts, to the buyer's camp; every badged unit
within 40 tiles of the crew changes force back to Concord and drives to the lot's bays. On the map a part of the
buyer's garrison turns olive and leaves. The player can cause this: cut the buyer's economy and Concord takes its army
away, which is leverage the campaign asked for (pillar 4) without a contract. Never from the player (section 6).

**4.4 The player buys through a chest.** Concord's order post: a steel chest in olive, from the start (as the trade
post is), placed by the player. Filled with goods worth 60 or more (valued as loot is, `ops.LOOT_VALUE`), the nearest
lot sends a truck that empties it and leaves one **delivery crate** per 60 of value (an item, "Concord Munitions
delivery: one service truck, assembly required"). A crate is the sole ingredient of a new barracks order, the service
truck at 3 bandwidth; the barracks picks its recipe as it does now. The post's lamp is lit while a truck is on its way.
A player at enemy standing fills the chest and nothing comes. That is the whole player-side UI: a chest, an item, a
lamp, a recipe. No window, no price list, no standing number. Later, the headquarters prize puts the rest of the
catalogue in the barracks without a crate.

**What it changes.** Grubstake at war against the player gets armour it never builds, so its ladder's upper rungs stop
being more shotguns. Serenity's sieges get trucks, so a siege the player cannot reach no longer bleeds out by itself and
the player must sortie at the trucks. Both research less while they buy. The player gets a third economy to reach (the
road between lot and camps, and the lot), a new verb (focus fire), one purchase, and a way to make a corporation's army
walk away. And one thing to watch on the map: which of the two rivals is being supplied, which tells who is losing.

## 5. The hardest design problem, and the headless test

**The loop must close and be seen at the rate a game runs.** Grubstake's tricks were built faster than they fired (arc:
one flare in three hours on deathworld). A market that orders twice a game is a market the player never meets, and a
badge the player sees once teaches nothing. The second half of the problem is the snowball: a market rewards whoever is
already winning, and the buyer with the most exports could buy itself the region by hour three.

**The arena, first (`scripts/arena.sh`, `tests/lp-arena/batch.lua`).** The truck is a new kind in `KINDS` and three
mixes in `MIXES`, each both ways round at 420 parts:
- `tanks / tanks + trucks` (7 tanks against 5 tanks and 2 trucks): the serviced side wins by a margin, 20 or more.
- `infantry / infantry + truck` (42 Line troopers against 37 and a truck): a smaller margin; trucks matter less to
  bodies that die in one burst.
- `rocket troopers / tanks + trucks` (21 against 5 and 2): the rockets win; burst beats service.
Plus a fixed-opponent row for the truck alone (it should lose to everything: a unit with no fight in it) and one new
arena feature, cheap: an entry flag `target = "lp-concord-truck"` that gives the side's units the trucks as their
first command. `tanks (focused) / tanks + trucks` must flip the first result. If it does not, the truck is a wall, not a
support unit, and the repair rate comes down before anything else is built. Report in `docs/arena.md`: a fifth class,
support, with its own row.

**The sim (`scripts/sim.sh dealer 12345 40`, `tests/lp-sim`), one scenario with mixes, in the `tribute` and `rivals`
style:**
- `dealer`: Serenity's camp at the usual distance, Grubstake's beside it, a Concord lot between them within 700 of both,
  all three with three depots, Serenity and Grubstake provoked against each other at start (clocks ten times fast as
  `standing` runs). Checks: each buyer places at least one order in 40 minutes; each delivery arrives within 5 minutes
  of leaving (the convoy diagnostics exist); badged units stand in the buyer's garrison with the buyer's force and
  Concord's prototype name; Grubstake's operations log shows a raid launched with `lp-concord-tank` in it; each
  buyer's fund fell by the orders' sum and Concord's exports rose by it; the lot holds at least 8 parked hulls at
  minute 20 and fewer right after a sale.
- `dealer ambush` (`LP_MIX=ambush`): a player gun line across the road between the lot and Grubstake. Checks: a delivery
  lost, no badge in Grubstake's garrison from it, the sold units fighting on Concord's force, Concord's standing to the
  player reading enemy within the minute, rival again an hour later with nothing more hit.
- `dealer repo`: Grubstake's road cut by the test at minute 15 (its trucks killed as `cut` does). Checks: a recovery crew
  leaves the lot within the 20-minute default window's end plus 2, badged units change force and arrive in bays.
- `dealer order`: the player's order post with 300 of circuits at minute 4 (worth 300: five crates). Checks: emptied
  within 5 minutes, five crates in the post, a barracks given one turns out a service truck that repairs a damaged
  trooper beside it (health rising over 10 s), the post's lamp lit while the truck was out and dark after.
- `dealer quiet`: nobody at war. Checks: no orders, and Concord launches a demonstration at the weakest neighbour
  within 20 minutes that withdraws with at least two thirds of its force.

**The snowball, measured where it would show.** The three-hour `factory` runs with Concord added, both policies:
report each buyer's fund spent on orders against research, Concord's level at the end, and whether either rival's
garrison doubled on purchases. First caps if it runs away: one order per 10 minutes a buyer, four units, half the fund.
The threat budget counts operations in flight, not what rides in them, so the player's pressure measure needs one more
line: units by prototype in raids on the player, to see the badge arrive in numbers that can be defended against.

## 6. Risks, and what I would not do

Risks:
- **Readability of a third colour inside a second's raid.** An olive hull under an ochre map dot is a thing to learn.
  The badge carries it; if ten-minute looks say it does not, the fallback is per-buyer prototypes (six copies: two
  buyers times three catalogue kinds), still cheap, at the cost of the olive hull.
- **Deliveries that never arrive.** Convoys have failed before (68 sent, none delivered on one visit). The delivery
  reuses the repaired code and the `dealer` scenario measures arrival; a market whose goods do not arrive is worse than
  none, because the funds are still spent.
- **Siting beside a front.** "Claims beside whoever is fighting" needs a landing rule: within 300 of the midpoint of
  two camps at war, else near the player's frontier as Grubstake prospects. A lot inside Serenity's reach is shot
  before it sells.
- **The truck as a wall.** The arena's focused-fire mix is the guard; run it before the sim.
- **More pressure on the player by the back door.** Buyers get stronger without any raid growing in count. The badge
  count in raids on the player, logged, is the measure; the caps in section 5 the lever.

What I would not do:
- No contracts window, no price list, no standing as a number. The chest, the crate, the lamp and the badge are the
  layer. Campaign.md's open question ("contracts: worth their UI cost?") answers itself: not as UI.
- No repossession from the player. The player paid in goods at the chest; taking the unit back later is a rule the
  player cannot see coming and would read as cheating. The player's risk is the road, which is fair and visible.
- No armour signature. Concord stocks tank hulls in olive because it sells them, and fields one in a demonstration;
  it does not raid with eight. Its army should be the smallest of the three.
- No field mortar or long-range fire for Concord; that gap stays open for a fourth corporation or for nobody.
- No sales to the biters, no pact. Its indifference to them is part of its temper, and the pact is Grubstake's.
- Not before the truck has fought in the arena. Everything in section 4 is the market; the market only matters if the
  thing it sells changes fights, and that is a two-day question the arena answers in an hour.

Build order: 3.1 in the arena; 3.2 the lot; 4.1 and 4.2 with the `dealer` scenario; 4.4 the order post; 4.3; 3.3 last.
