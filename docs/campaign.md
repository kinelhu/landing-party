# Landing Party: the campaign (design v2, proposed 2026-10-13)

> Renamed 2026-10-21: Serenity Perimeter Group is shown as **Kessler-Hayashi**, Grubstake Mineral Recovery as **Grubstake Inc.** (internal ids unchanged).

> (2026-11-16: a design of 2026-10-13. Built since and not described here: the director above the corporations
> (docs/director.md: tempo, lulls, strike forces from headquarters, off-map beats), no truces since 0.2.325, two
> corporations and Synthexis rather than four. DESIGN.md is the record of what exists.)

The frame above DESIGN.md. DESIGN describes the parts as built; this describes the game they serve. Written
after the user judged the first frame too small ("3 bases, uplink, boss seems extremely small scale") and
asked for a mid-game revealed, endgame-compatible threat with scaling, rival factions and interesting
mechanics, and for as much of the design and its verification as possible to happen without them.

Reviewed by Fable the same day: `docs/reviews/2026-10-13-campaign-review.md` (decisions pending the user).

Status words: **built** (exists and is tested), **adapt** (exists, changes), **new** (to build),
**verify** (an engine question to settle with a spike first).

## 1. Why a second frame

The first frame was a scenario: the faction answers the first launch, lands three times, the third is the
uplink, destroying it ends the threat. Measured against a Factorio playthrough (30 to 100+ hours), that is an
event of an afternoon. It also never meets the player's endgame: a megabase with artillery and infinite
research would sweep three settlements aside in minutes.

What the first frame got right and keeps: a rival with an economy rather than an infection; settlements on
the player's ore; readable architecture; operations with intent; an army the player builds and commands;
capture and salvage; the fall of a settlement. What it lacked: a world, rivals among themselves, a pace that
follows the player's whole campaign, and a way to stay relevant at the endgame.

## 2. Pillars

1. **A world of rivals, not a wave.** Several corporations hold territory across the map and compete for the
   same resources, with each other as much as with the player.
2. **They follow your campaign.** Foreshadowed early, revealed mid-game, escalating with the player's
   progress, still a factor at megabase scale.
3. **Every fight has a reason.** Corporations act on what they know and want (ore, routes, revenge,
   contracts), and the player can read the reason.
4. **The player has leverage, not just firepower.** Rivals can be played off against each other, starved,
   bribed, out-maneuvered; brute force is one answer among several.
5. **Measured without a human.** A scripted player agent plays whole campaigns headless; the human judges
   feel in short looks at milestones.

## 3. The arc

Space Age is the primary target; the base game is supported with different triggers. **Absence is not a
truce** (user, 2026-10-13, rejecting the review's "absence costs territory, never the base"): remote view
lets the player watch, rebuild with robots and command units on Nauvis from anywhere (the command tool works
on the surface being viewed), and vanilla Space Age does not spare an empty base from biters either. What
absence needs instead: alerts that reach the player on any surface, naming the corporation and the place,
and defences that can be automated (a beacon that answers T > 0 by itself). In Space Age the first
rocket is mid-game (it builds the first platform); in the base game the first launch is the end, so the reveal
moves earlier.

| Phase | Player, roughly | Corporations | Trigger (Space Age / base) |
|---|---|---|---|
| **0. Signs** | red and green science, first trains | Wreckage on the map (a crashed probe, salvage); a radar picks up a signal; a scout drone over the player's mining | first radar / first train (both) |
| **1. Survey** | oil, blue science | A **survey party** lands far out (no army, a few drills and a beacon): it maps ore, claims nothing, leaves after a while. Destroying it delays phase 2; leaving it brings it sooner | first oil processing (both) |
| **2. Arrival** | first rocket (SA) / blue science and robots (base) | The **first corporation** lands one claim on a rich field 300 to 500 tiles out, grows, and expands to more fields. This is what is built today | first rocket launch (SA) / first chemical science pack crafted (base) |
| **3. Competition** | planets (SA) / purple and yellow science (base) | A **second corporation** arrives and contests ore with the first and with the player. Corporations raid each other | some hours after arrival, sooner with each launch |
| **4. Escalation** | megabase growth | Corporations develop capabilities (sieges, harriers, jammers, bombardment, orbital presence). New claims on far fields. A third corporation | development levels (section 6) |
| **5. Headquarters** | late game | Each corporation builds a **headquarters** on its richest claim: the fortress and uplink of today, one per corporation. Destroying it ends that corporation in the region; its claims fall | development level 3+ |
| **6. Endless** | infinite research | New corporations keep coming at a slowing rate, each starting from where the market is (section 6). The world never empties unless the player chooses a setting that ends it | settings |

The first frame's three-landing story becomes phases 2 and 5 for one corporation.

## 4. Corporations

A corporation is a faction with an identity, a doctrine, a signature and a temper. Humorous and dystopian in
tone, dry rather than loud (deadpan corporate notices, not jokes): "Mineral rights for this region have been
reassigned. Thank you for your cooperation."

Names (decided by the user, 2026-10-13): **the corporate euphemism**, a polite word for the ugly thing each
one does. Profiles (adopted from the campaign review): each differs by what it attacks with, how it defends,
where it breaks, and what ground it wants; doctrine and colour alone made recoloured variants.

| Corporation | Role | Offence | Defence | Weak point | Wants | Biters | Temper |
|---|---|---|---|---|---|---|---|
| **Grubstake Mineral Recovery** | the thief (sprawl) | strip-mines the player's own patches at the edge of their coverage, convoys the ore out; never raids the base | redundancy: many small outposts, rebuilt fast and cheap | everything is in transit: convoys and depots | ore volume | avoids them, never clears a nest | buys the player off; the first to offer a truce |
| **Serenity Perimeter Group** | the wall (fortress) | sieges with mortars, later bombardment; never raids first, retaliates in proportion and never forgets | walls, mines, gates, shields | static and power-hungry: cut points | defensible ground: cliffs, shores, chokepoints | clears them (announced) | defensive, relentless once provoked |
| **Lumen Transparency** | the eye (picket) | harriers at relays, rails and power; jams the player's radars and control; orbital marks late (a warning on the ground, then a strike) | sees everything, aborts early, evacuates | blind it: without pickets it cannot operate (its operations need intel) | coverage: pickets spread thin | uses them: jammed radars let biter attacks arrive unseen | opportunist; truces freely, breaks them |
| **Concord Munitions** | the dealer (bastion) | tanks and walkers, big garrisons, raids the weakest neighbour, corporations included | garrison, not walls | burns parts; its depots are its economy | customers: it claims beside whoever is fighting | indifferent | aggressive; sells units to the others (its level gates their walkers) and to the player at good standing |

Their look, architecture, units and logos: `docs/corporations.md` (identity design pass).

A fallen headquarters leaves a prize particular to its corporation (Serenity's mortars, Lumen's jamming,
Grubstake's strip drills, Concord's unit designs for the barracks).

- Each corporation is its own Factorio force (`lp-<name>`), with its own colour (the tint today), its own
  research-like development, its own intel.
- Four is a starting set; the framework takes more. Doctrines, archetypes and unit mixes exist today
  (**built**: bastion, sprawl, picket, fortress); a corporation is a named bundle of them plus a temper
  (weights in the operation chooser) and one signature capability.
- Corporations are not all hostile to the player all the time (section 7).

## 5. The world model: territory and two levels of simulation

The scale problem is engine cost: dozens of live settlements with hundreds of units would ruin the update
rate. So corporations run at two levels.

- **Claims.** A corporation holds claims: ore fields with a strength, an economy and a garrison as numbers.
  Claims grow, spend, raid other claims and expand on a slow clock (a minute of game time per step), all in
  Lua tables. No entities. (**new**)
- **Materialized settlements.** A claim becomes real (the settlements built today) when the player charts it,
  comes within some distance of it, or when an operation involves it. It is built at once from its abstract
  state: the planner runs fast with its own seed until the settlement has the modules the claim's strength
  pays for (the burst mode built for the fortress is the start of this). (**adapt**)
- Once real, a settlement stays real. It keeps its abstract record in step (economy, garrison).
- **Fights between two abstract claims** resolve by numbers (strength, doctrine, distance, defence), with a
  visible result if the player later looks: ruins, a changed owner, a new outpost. Fights near the player
  are always real.
- Budget: a target of at most 1 ms per tick of script time with 30 claims and 6 materialized settlements, at
  least 30 claims on a default map by the endgame. (**verify** by measurement)

Territory is legible: each claim is a coloured region on the map (chart tags or a rendered outline), named
("Halvorsen Extraction: claim 4, iron, 2.1M"). The player sees the corporate map before seeing a building.

## 6. Scaling

Two clocks, so the threat follows the player and not the wall clock.

- **The player's era**: a number from the player's progress (science packs researched, rockets launched,
  planets visited in Space Age). It sets which phase can trigger and the **market**: the capabilities a newly
  arriving corporation starts with.
- **A corporation's development**: from its own economy (ore extracted and exported) and its wins and losses.
  Each level buys a capability, never a hidden damage bonus (the +15% damage per tier goes, **adapt**):
  level 1 harriers and sieges; 2 walkers and pickets that see; 3 headquarters, jammers, bombardment;
  (2026-11-16: walkers are out of every mix, cut for 0.3.0; the levels as built are in DESIGN.md.)
  4+ orbital strikes (Space Age), a second headquarters region.
- **A threat budget** caps how much pressure all corporations together put on the player at once (operations
  in flight against the player, scaled by the player's era and a difficulty setting), so four corporations do
  not stack into an unwinnable flood. Corporations spend most of their aggression on each other when the
  budget is used.
- Endless mode: past the last level, development buys more of the same (garrison, claims), slowly.

## 7. Interactions

### Corporation and player
- **Hostile by default, not by nature.** Each corporation has a **standing** with the player (-100 to 100).
  Destroying its buildings lowers it; trading raises it. At low standing it raids; at neutral it ignores the
  player unless the player encroaches on its claims; at high standing it will sell.
- **Contracts** (**new**, small): through a corporation's uplink or depot GUI, the player can pay
  (items) for a cease-fire for a time, hire an operation against another corporation, or buy salvage and
  command cores. Leverage, not just firepower.
- The player's army, capture, salvage and the fall (**built**) apply to every corporation.

### Corporation and corporation
- Corporations contest claims: an ore field claimed by two is a front. They raid each other's outposts,
  convoys and routes by the same operation code (**built** for player targets; **adapt**: the target list takes
  other corporations' entities, values by kind).
- Alliances are short and practical: two corporations may cease fire while both fight a third or the player
  (Factorio force cease-fire, **built** into the API).
- A corporation that loses its headquarters loses its claims to its neighbours (abstractly) or to ruins.
- The player can **steer** rival fights: lure a raid into a rival's ground, sell intel (contracts), take what
  the loser leaves.

### Corporations and biters
The three-way war is the part most likely to surprise, and the one with the most complications.
- **Who fights whom.** Corporations and biters are hostile by default. Biters attack what pollutes: today
  settlements emit no pollution, so biters ignore them except by contact. Proposal: settlements emit a little
  pollution (fabricators), so biters pressure corporations too and the player's pollution cloud is not the
  only one. A setting chooses: corporations at war with biters, ignoring them, or clean (no pollution).
- **What it gives the player.** A corporation clearing nests on its way is a mixed blessing: fewer biters near
  its claims, but evolution rises for every destroyed spawner (the map setting counts spawners destroyed;
  **verify** whether any force's kills count). A corporation besieged by biters is weaker, and the player can
  push pollution towards it or clear a buffer to leave it exposed.
- **Complications and answers:**

| Complication | Why it matters | Answer |
|---|---|---|
| Corporations wipe out biters regionally | A core Factorio pressure disappears | Corporations only clear nests on their claims and routes; abstract claims never fight biters; a setting |
| Evolution races up from corporation kills | Biters overwhelm the player early | **Verify** the counting; if any kill counts, script corporation kills of spawners to give back the evolution (`force.set_evolution_factor`) |
| Biter attacks trigger corporation responses endlessly | Script cost, garrisons bleed on biters | Alarms caused by biters only (no other force) draw a capped, cheap response; patrols handle the rest |
| Biter expansion onto claims | Nests in the middle of a settlement | A settlement treats nests on its claim as a static threat: one sized raid, then a cool-down (the defend logic, **built**) |
| Pathing through biter land | Raids and convoys die on the way, reasons unreadable | Operations route around known nests (intel markers, **built**) or treat them as defence on the target's score |
| Stacked difficulty | Biters at deathworld plus four corporations | The threat budget counts biter attacks on the player; settings for both |
| Peaceful mode or no biters | The three-way war is absent | Everything works without biters; corporations fight each other instead |

### Other complications to design for
- **Force limit**: Factorio allows 64 forces; four to eight corporations plus the player's and biters' are
  fine.
- **Multiplayer**: several player forces; standing per player force; the threat budget per player force.
- **Other mods**: biters from other mods (Rampant, Armoured Biters) behave differently; test with one later.
- **Save size and update cost**: abstract claims keep this flat; materialized settlements are bounded.
- **Readability**: three factions and biters in one fight must still say who is fighting whom (colours,
  map regions, alerts with the corporation's name).

## 8. The player's tools across the campaign

| Phase | Tools (built, adapt, new) |
|---|---|
| Signs, survey | Salvage from wreckage (**built**: salvage); scouting a survey party; a command core from it (**built**: cores) |
| Arrival | Turrets and the first barracks (**built**); capture by holding (**built**); the command tool (**built**) |
| Competition | Contracts (**new**); relays as territory, control radius (**new**, from the review); breachers and battle tanks (**built**) |
| Escalation | Field repair (**built**), forward barracks; anti-air and anti-missile defence with radar coverage (**new**, user idea); jamming answered by relay chains (**new**) |
| Headquarters | Combined-arms assaults; artillery; the fall (**built**) |
| Endless | Orbital relay lifts the control radius (**new**); veteran units on modular armour (**new**, user idea) |

## 9. Verification without the human

The player's time goes to feel, in short looks at milestones. Everything else is measured.

- **The player agent** (**new**): a scripted player that plays a campaign by rules over many game hours:
  - grows a factory abstractly (production blocks placed over time from templates, so there is something to
    defend and its value grows);
  - expands to ore fields with outposts and rail;
  - rebuilds losses after a delay (robots), repairs, adds turrets where attacked;
  - researches military in step with its era;
  - builds an army when threat rises, uses beacons and the command tool's functions to defend and to capture,
    destroys landers when it can;
  - optionally uses contracts.
  Its rules are a model of a competent player, written down and reviewed, not a learned policy.
- **Campaign runs**: the agent and the corporations for 10 to 30 game hours headless, fast. Outputs: the
  timeline (built: `contact`, `timeline.py`), a map of claims over time, an event log in plain words.
- **Measures of the loop** (proxies for fun, judged by the user and by review):
  - pressure: share of time the player is under some threat; longest quiet and longest siege;
  - agency: how often the agent's choices (where to expand, when to strike) change outcomes;
  - reasons: share of operations whose target is valuable to the corporation (no biter-like randomness);
  - scaling: corporation strength over the player's strength across eras, flat or gently rising;
  - rivals: share of corporate operations aimed at each other versus the player;
  - cost: script time per tick across the campaign.
- **Reviews**: Fable reads the logs and plots at each milestone, as it read the design today.
- **The human**: a ten-minute look at a save prepared at an interesting moment of a campaign run (built:
  showcase saves), and the plots.

## 10. What happens to what exists

- **Keep**: settlements, architecture, economy, capture, the fall, salvage, operations (raid, siege),
  the player's army, beacons and circuits, the command tool, bandwidth, repair, forks and the quick
  regression.
- **Adapt**: the faction becomes one corporation of several (force per corporation); tiers become development
  with capabilities; arrival becomes phases with triggers; operations target other corporations and biters;
  the uplink becomes a corporation's headquarters; the planner gains a fast materialization mode.
- **Cut or freeze**: the +15% damage per tier; the fixed three-landing story; further convoy and interceptor
  tuning.

## 11. Implementation order

Each slice is verified by agent runs before the next.

1. **The player agent and campaign runs** with what exists (one corporation). The instrument comes first.
2. **Corporations as forces**: two corporations with names and doctrines, contesting claims; operations
   against each other.
3. **Claims and abstract simulation**: claims across the map, materialization on approach, the update budget.
4. **Phases and scaling**: signs, survey, arrival triggers for Space Age and base; development levels with
   capabilities; the threat budget.
5. **Biters**: the interplay settings, evolution verified and handled, nest clearing on claims.
6. **Standing and contracts.**
7. **Headquarters** per corporation; the fall of a corporation.
8. **Readability across the campaign**: territory on the map, alerts naming the corporation, settlement panel.

## 12. Open questions

- Space Age primary: confirmed or not; and whether corporations ever leave Nauvis.
- How many corporations by default, and whether the player can choose (settings).
- Contracts: worth their UI cost, or a later layer?
- Whether materialized settlements can return to abstract when the player leaves for good (save size).
- Whether standing should exist at all or corporations stay simply hostile (simpler, less leverage).
