# Review of `docs/campaign.md` (Landing Party, campaign v2), 2026-10-13

Advisory review by Fable, read-only over the proposal, DESIGN.md, the earlier review, the code and the 2.0.77
runtime API. Kept as written; decisions taken from it are recorded in `docs/campaign.md` and DESIGN.md.
"Checked" means the reviewer read the code or the API; "speculating" means untested.

## 1. Does the arc work in Factorio terms?

The shape (signs, survey, arrival, competition, escalation, headquarters, endless) is the right shape. It is
the Rimworld/X4 shape: foreshadow, first contact, a world that keeps moving, a conquerable centre, no hard end.
Three things are wrong with it as written.

**The Space Age absence problem is not addressed, and it is the biggest pacing hole.** In Space Age the player
leaves Nauvis for hours at a time after the first rocket, which is exactly phase 2's trigger. A corporation
that lands and raids an unattended Nauvis base is the "base loss with no answer" DESIGN already names as the
reason the faction wakes gently. A corporation that politely waits is a corporation the player forgets. The
right rule is that absence costs territory, never the base: while no player character is on Nauvis,
operations against the player are capped at probes and claims, and corporations spend the quiet taking ore
fields. The player comes back to a corporate map that has grown around them, which is a Factorio-shaped
punishment (your expansion is blocked) rather than an RTS one (your base is gone). Say this explicitly in
section 3; it also answers open question 1 (corporations stay on Nauvis; each planet has its own enemy design,
and the platform-combat trap from the previous review still applies).

**Phase 3's trigger ("some hours after arrival, sooner with each launch") is a wall clock in disguise.** The
campaign's own pillar is "two clocks, so the threat follows the player". Make every phase transition an event
the player caused or could have prevented: the second corporation arrives when the first reaches development
1 (the market notices a profitable region), or when the player destroys a settlement (a vacancy), or at the
second planet visited. "Destroying a settlement invites a newcomer" is the single best trigger because it
turns the player's main verb into a strategic cost, and it is what makes contracts and truces worth having
later.

**Endless needs a ceiling on standing corporations.** Readability (section 7's own complication) and the force
count both argue for at most three or four alive at once. New arrivals replace the fallen; they do not stack.
Pacing at 30 to 100 hours is then fine: signs and survey in hours 2 to 6, arrival at 8 to 15, competition
from 15, headquarters fights from 25 on, endless beyond.

Keep phases 0 and 1 exactly as proposed; they are cheap and carry most of the early feel. One addition: the
survey party's beacon should drop a command core, so a careful player has their first barracks before the
first lander. That is the signs phase paying off in a mechanic rather than a message.

## 2. Corporations

"A named bundle of doctrine, architecture, signature and temper" is the right frame and, as filled in,
produces recoloured variants. Doctrine and architecture (checked: `layout.DOCTRINES`, `army.MIX`) change what
the settlement looks like and which units it mixes; the player still fights all four with the same tools and
finds the same weak point (the pylon line to the lander). What makes factions feel different in every RTS that
has done it well is asymmetry on four axes: a signature offence that needs a distinct counter, a signature
defence that needs a distinct breach, a distinct economic weak point, and a distinct way of scoring what
ground it wants. The fourth is the cheapest and the one the proposal misses entirely: give each corporation
its own claim-scoring function and the territory map becomes legible on its own.

Concretely:

- **Halvorsen Extraction (sprawl, the thief).** Offence: strip-mining, literally. It lands drills on the
  player's own patches at the edge of their coverage and convoys the ore out; it never raids the base.
  Defence: none worth the name, but redundancy: many small outposts, rebuilt fast and cheaply. Weak point:
  everything is in transit; intercepting convoys and killing depots is the whole fight. Wants ore volume,
  nothing else. Biters: avoids them, routes around nests, never clears one. Temper: buys the player off
  (standing rises fastest from trade), offers the first contract. The player's answer is patrols and area
  denial, not siege.
- **Aegis Perimeter Solutions (fortress, the wall).** Offence: sieges, then bombardment; never the first to
  raid, retaliates proportionally and never forgets. Defence: walls, mines, gates, shields on walkers. Weak
  point: static and power-hungry; cut points matter more than anywhere else, and it expands slowly. Wants
  defensible ground: cliffs, lakeshores, chokepoints. Biters: clears them (the evolution driver, by design).
  The answer is the artillery duel and the power cut.
- **Kessler Orbital (picket, the eye).** Offence: harriers, jammers (control-radius denial from the previous
  review), relays and rails as targets, orbital marks late (a ground-visible warning then a strike; never
  platform combat). Defence: it sees everything and leaves early: aborts fast, evacuates. Weak point: blind
  it. Kill its pickets and it cannot operate at all, because its ops need intel (checked: `ops.choose` only
  targets what is in `b.intel.targets`). Wants coverage, so it spreads pickets thinly across the map. Biters:
  uses them. It jams the player's radars so biter attacks arrive unseen. Temper: opportunist, truces freely
  and breaks them.
- **Marrow & Vane Arms (bastion, the dealer).** Offence: tanks, walkers, large garrisons, raids often, picks
  the weakest neighbour including corporations. Defence: garrison, not walls. Weak point: it burns parts; its
  depots are its economy. Systemic role: it sells units to the others (and to the player at high standing), so
  its development level gates the walkers everyone else fields. Killing M&V starves the region. Wants
  customers, which means conflict: it claims next to whoever is fighting.

Four is right because M&V's dealer role gives the set a system, not just a roster. Add one thing to section 4:
each headquarters that falls leaves a prize specific to that corporation (Aegis mortars, Kessler jamming,
Halvorsen strip drills, M&V unit designs for the barracks). Four different prizes make four conquests feel
like four conquests; this is the 4X lesson and the cheapest endgame motivation in the document.

## 3. Two-level simulation

Feasible and the standard approach. The pitfalls are concrete.

**The planner cannot "run fast" as it stands (checked, `base.lua`).** `plan()` runs every 5 s and acts on
measured flow: `rate_in` is an EMA (0.1 per second) of real bin contents from real drills; `fabricate` fires
only when ore is flowing; `mine` fires when it is not; `build()` places one entity per 1.5 s and
`site.scan_step` scans one chunk per tick (radius 200 is about 170 chunks). The uplink's burst
(`UPLINK_BURST`) accelerates fortress-template jobs only, not the planner. Looping plan and build in one tick
would produce a settlement of mining modules stalled on parts. Materialization needs a dry-run mode: a
synthetic economy that feeds `plan()` the claim's income and bank instead of measured rates, a full ore scan
up front, and a build loop placing tens of entities per tick. That is a real adaptation, not a flag. It also
means materialization takes seconds to tens of seconds of game time, so it must trigger well before the
player can see the ground: charting by radar or artillery wagon, or a character within 600 tiles, not 200.
Chunk generation (`request_to_generate_chunks` plus `force_generate_chunk_requests`, checked in `base.land`) is
a visible hitch on a cold area; charted ground is generated already, which is one more reason to key on
charting.

**Artillery sets the materialization radius, not the character.** Vanilla artillery reaches 200 to 300 tiles
with research and auto-fires on military targets in charted chunks. A claim that materializes inside that
umbrella dies before it is seen. Turn that into a rule the abstract layer knows: corporations do not claim
ground under the player's artillery coverage; they claim just outside it. That is the megabase experience in
one sentence: they ring you.

**Operations between real and abstract.** A materialized settlement's operation against an abstract claim
should resolve abstractly, with a real departure and a real return (the column leaves the depot, the garrison
is deducted, the outcome is numbers, survivors reappear). Materializing the target instead would cascade
materialization across the map as corporate wars spread. Fights between two abstract claims by numbers are
fine; make the result visible on the map immediately (owner colour, a "ruins" tag), not only on later
approach.

**Nests on an abstract claim.** Abstract claims cannot fight biters (good), but biters expand physically into
active chunks, so a claim can materialize onto nests. The planner cannot place there. Materialization needs a
nest check: shrink the claim or open with a static-threat operation.

**Dematerialization (open question 4).** Never for living settlements; always for fallen ones. Ruins should
decay to an abstract record plus a few landmark entities, otherwise the endgame map accumulates thousands of
neutral entities (checked: `ruin()` flips every building to neutral and leaves it).

**Capture falls out for free, and absurdly (checked, `holder()` and `occupied()` in `base.lua`).** Any force
not on the cease-fire list counts as an occupier. With corporations as forces, a passing raid of corporation B
standing in A's outpost for a minute with no defender captures it. Decide whether that is a feature; I would
keep capture to an explicit occupy operation.

**Determinism and save size** are fine as proposed: seeded `rng.lua`, no `math.random`, 30 claims of small
tables. The 1 ms budget is plausible given the measured 1.5 ms worst plan tick; the risk is `base.tick`
iterating every base every tick (checked), which the claims layer must not copy.

## 4. Scaling

Development as capability rather than damage is right (checked: `faction.apply_tier` sets ammo damage
modifiers; cut it). The threat budget is right. Two gaps.

**What a megabase player fears** is not losing an outpost; it is things artillery cannot solve and things that
break automation silently: a rail cut in a far corner, a power pole on a long line, a train stuck, harriers
over the wall, jamming that blinds a sector, and above all time spent on a problem that does not pay.
Corporations can deliver the first three (interceptors and the ops value table already exist; Kessler's
jamming is the fourth). At era 4+ the pressure should shift explicitly from "beat the perimeter" to "deny
expansion and hit transit". Say so in section 6; otherwise development level 4 reads as "more units", which a
megabase does not notice.

**The real risk is trivial, not unwinnable.** The budget prevents the flood; nothing prevents irrelevance. The
only thing that keeps a megabase player engaging voluntarily is a need. Command cores are already unique loot.
Add one endgame input corporations hold and the player's late tools require (veteran units, the orbital
relay) and the endgame becomes a territory game with a reason. Without that, phase 6 is a notification feed.

## 5. Interactions

**Standing and contracts.** Hostile by default is right; "ignores the player unless the player encroaches" is
where it dies, because a corporation that can be ignored will be. Keep territorial conflict inevitable (they
claim ore the player needs) and make standing three visible states (war, truce, trade) rather than a hidden
number. A truce is bought, time-bound, and announced. Checked: `set_cease_fire` is one-directional ("forces on
the cease fire list won't be targeted"), so every truce sets both forces, and the player's turrets stop
firing at that corporation only when the player force's list includes it. Never use `set_friend` for
corporations: it also grants building access.

**Corporation and corporation.** The ops code already enumerates targets over every non-cease-fire force
(checked: `ops.enemies`), so raids between corporations are mostly a refactor. Two things to adapt: the mortar
shell "hits the player only" (DESIGN) must hit any enemy force, and `threat(b)` falls back to the player
force's spawn (checked), which a corporation at war with another corporation should not do.

**Biters and evolution (checked, API).** Evolution in 2.0 is per force and per surface, with a separately
readable and writable spawner-kill component (`get/set_evolution_factor_by_killing_spawners(surface)`).
`destroy_factor` is documented "for every destroyed spawner" with no killer qualifier; I believe any death
with a cause counts (speculating; a ten-minute spike with a corporation unit killing a spawner settles it).
The proposed refund is feasible because the component is separate: on `on_entity_died` of a spawner whose
cause is a corporation force, subtract the increment (the engine scales increments by (1 minus evolution), so
measure the delta rather than assuming 0.002). Per-surface evolution also means a Nauvis-only corporation
cannot touch Gleba's.

**Pollution.** Alarms fire for any non-corporation force (checked, `control.lua` filters on
`e.force.name ~= shared.FORCE`), so a polluting settlement beside a nest cluster will respond, clear spawners
and bleed garrison on a loop. The table's answers are right but the default should be clean (no pollution),
with pollution as an opt-in, because the worst emergent failure in the whole document is this one: a
corporation 400 tiles out, beside nests the player has never seen, raises evolution for an hour, and
behemoths arrive at the player's wall for something invisible. Announce nest clearing ("Aegis is clearing
nests at X") regardless.

**Missing from the table:**
- Columns in transit fight biters on the way (`distraction.by_enemy` throughout `ops.lua` and `army.lua`,
  checked), arrive depleted, and the abort reads as randomness. Route around nest cells (intel markers exist)
  and narrate the ambush.
- A corporate claim between the player and the nests absorbs biter attacks aimed at the player's polluters.
  Emergent, exploitable, and good; name it so the player is told about it.
- Multiplayer standing per player force is listed; truces between player forces and corporations are then
  n-by-m cease-fire pairs. Fine, but write it down.
- Modded biters (Rampant) will attack settlements on sight regardless of pollution; test one early, not later.

**The player ignored** is the failure I would watch hardest. "Corporations spend most of their aggression on
each other when the budget is used" plus neutral standing produces a spectator game. Floor the budget: at
least one corporation always has the player as an active target at a pressure proportional to era.

## 6. The player agent as the instrument

A rules-based agent is a good regression and pacing instrument and a poor fun instrument. It will
systematically get four things wrong: it builds regular, dense, fully defended bases with no forgotten
corners; it reacts instantly and uniformly, with no attention bottleneck, which is the human constraint that
raids and feints exist to exploit; its "abstract factory" has no topology, so the ops value table (cut points,
rails, roboports) is untested against it; and its choices are its rules, so "agency" measures the developer's
assumptions. The earlier review said it: a scripted player plays the loop the developer imagined. The
`contact` player (checked) is a static entity dump; the proposal is a large step up from that and still not a
player.

Three fixes make the signal trustworthy:
1. **Model attention, not skill.** One cursor; a reaction delay that grows with distance and with the number
   of simultaneous events. This is the single parameter that makes raids matter and feints meaningful.
2. **Real templates, not abstract growth.** A real rail outpost with real poles, a real main bus block, real
   roboports. Let the engine rebuild from ghosts (roboports, provider chests, repair packs) instead of writing
   rebuild logic. That is free, deterministic, and exactly how a mid-game player rebuilds.
3. **Eras as fixtures, not one 30-hour run.** Three prepared bases (the contact base; a rail base with three
   outposts and robots; a late base with artillery and lasers everywhere), each with a small reactive policy
   and scripted research, each run 3 to 5 game hours. A 30-hour run on a growing base is slow (the engine is
   bounded by entity count, not `game.speed`), and a late-era fixture tests the endgame on day one instead of
   in hour 25.

Measures: pressure, longest quiet and longest siege, reasons, rivals' share and script cost are meaningful
and cheap. The scaling ratio is meaningful once "strength" is defined (garrison plus turrets plus income on
their side; turrets, troopers, bandwidth, artillery on ours). "Agency" is vanity unless done as
counterfactuals: same seed, fork at a decision, flip it, compare. The fork tooling exists (`scripts/fork.sh`),
so this is cheaper here than anywhere, but it is a study, not a metric. Add three: **recovery time** (minutes
from a raid to production back at its prior level), **legibility** (share of operations launched from a
settlement the player had charted, against a target inside the player's radar coverage), and **territory
share** over time.

What still needs a human: whether three colours and biters in one fight say who is fighting whom; whether the
territory map reads; whether a siege feels like a siege; the tone of the notices; whether four architectures
are distinguishable at a glance; whether the contract GUI earns its clicks. Ten-minute looks at prepared
saves, as proposed, with the human asked one question per look.

## 7. Scope and order

Section 11's order is right in spirit (instrument first) and wrong in size: the agent as specified is the
largest item in the plan. Reorder:
1. The cadence fix and a careful-player `contact` run (DESIGN's baseline already asks for both). Nothing else
   can be judged until a raid every minute stops.
2. **Corporations as forces** with two names. Checked: `shared.FORCE` and `game.forces.player` are hardwired
   in about 22 places (`base.lua` 7, `command.lua` 6, `control.lua` 7, `faction.lua`, `ops.lua`),
   `storage.faction` is one table, `army.cap` reads the global tier. A per-corporation state table and a
   force lookup by base is a day's refactor and unblocks everything.
3. Claims on the map (legibility), signs and survey. Cheap, high feel.
4. Phases and triggers, development as capability, the budget.
5. Headquarters: the existing uplink and fortress per corporation.
6. Biters minimal: clean by default, evolution refund, nest check on materialization.
7. Abstract claims and materialization, only once measurement shows the cost of real settlements is the
   limit. Six real settlements may be enough for a long time.
8. Standing and contracts last, and only if the user still wants the UI.

**MVP of the campaign:** two corporations (Halvorsen and Aegis: the thief and the wall are the most different
pair), signs and survey, arrival on the first launch, claims drawn on the map, raids between corporations, a
headquarters each with the fall, biters clean with the evolution refund, three era fixtures as the
regression. That is already a better mod than the first frame.

**Cut:** contracts (a single bought truce at the headquarters is the whole feature for now), orbital strikes,
the third and fourth corporation at launch, dematerialization of living settlements, the +15% damage, further
convoy tuning.

## 8. Top 8 recommendations

1. **Absence costs territory, never the base.** Cap operations against the player while no one is on Nauvis;
   this is the Space Age pacing hole and it is unaddressed.
2. **Every phase transition is an event the player caused.** Destroying a settlement invites the next
   corporation; wall-clock triggers go.
3. **Corporations differ by what they want and what breaks them, not by colour.** A claim-scoring function and
   a weak point per corporation; the four sketches above.
4. **Fix the planner before promising materialization.** It is flow-driven and chunk-paced (checked); it needs
   a dry-run economy and a build loop, and materialization must key on charting, not proximity.
5. **Corporations do not claim under artillery coverage.** One rule that makes megabase scaling legible and
   gives the abstract layer a reason.
6. **Era fixtures with attention modelling instead of a 30-hour growing agent.** Faster, deterministic, tests
   the endgame now, and the engine rebuilds from ghosts for free.
7. **Biters clean by default; refund corporate spawner kills through the per-force spawner-kill component.**
   The invisible-evolution failure is the worst in the document and the API supports the fix.
8. **Floor the threat budget and give the endgame a need.** One corporation always targets the player; one
   endgame input only corporations hold. Without both, phase 6 is a notification feed.
