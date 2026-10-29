# Synthexis as a faction: an outside consult (Fable, read-only, 2026-10-29)

Read: CLAUDE.md; DESIGN.md (the Synthexis rows of the status table, 0.2.14 to 0.2.88, and the findings log, including the
uncommitted 0.2.88 entries on the `muster` branch); docs/biotech.md whole; the growth consult of 2026-10-25 and the
perception consult of 2026-10-27; the faction parity note of 2026-10-29; `farm.lua`, `herd.lua` (launch, staging, plan,
way_cost and affords, march, breach, stay pricing, finish, hunt), `creep.lua`, `cell.lua`, `costmap.lua`, `valuemap.lua`,
`shared.lua`; the 2.1.23 runtime and prototype API for every engine claim below; and the nw visit
`nw-growthmarchtracesplit3` (decisions.txt, 14,274 lines; results.txt). Nothing was run.

## 1. The faction as a whole

### What it is

Strip the mechanisms away and Synthexis is one sentence: your smoke becomes an army that reads your base and comes in
where it is cheapest. That is a real identity and it is distinct from the other two. Kessler-Hayashi is a front that
advances; Grubstake is a thief at the edge; Synthexis is an infestation that prices you. Nothing in vanilla and nothing
in the rival mods does the third thing. The pieces that carry the identity to a player are few and good: the violet
stain that grows while the chimneys run, the scout in pale cyan looping outside the guns, glowing bursters waiting out of
range, the wall opening in one blast, and a herd that walks past the turrets to the assemblers. Every one of those is a
thing a player can see and act on before it hurts.

### Where it is strong

- The perception stack (threat, firemap, costmap, valuemap, prices learned by prototype) is the best piece of AI in the
  mod and the parity note is right that it is the thing to export. "Inside is where cost jumps" is the correct model of a
  base and it is why the deathworld numbers went from 800 to 1,300 razed a timing.
- The counters are base shapes, and they hold: guns that cover each other, a mended hole, a second feed, a flamethrower
  line a burster cannot reach (the nw north wall is unbroken after three days of visits, which is the game working, not
  failing). The arena keeps the breeds honest.
- The economy's premise (pollution in, biters out, at a wild nest's rate) is the one lever the corporations never give
  the player: a cleaner factory starves it. Nobody else in the Factorio ecosystem makes pollution matter this way.

### Where it is a pile of mechanisms

Read `farm.send` top to bottom. It is 300 lines of a state machine with ten exits, each the scar of a named run: young,
escalate_retry, siege laid, siege ended, siege short, saving for SAVE_FOR, WORTH_WAIT, STALL, ORDER_WAIT, ORDER_WAIT_BIG,
ESCALATE_WAIT, SAVE_WAIT, "learned so it holds and grows", the forced trial. Every exit is defensible on its own and the
sum is a planner nobody can predict, including its author. The symptom is in the nw trace: 102 lines of "holds its
wave" in five hours, 5 lines of "sends". The same is true of the breed roster: nine breeds, and the player's eye tells
apart maybe four (scout, burster, big, the rest). The user already noted that "a wave's make-up is the part of its
cleverness a player sees least" (0.2.17), and that judgement should be applied to the farm's clocks too. A player
cannot see WORTH_WAIT or SAVE_WAIT. They see waves, or no waves.

The second pile is time. The design says "the clock is bad" and the code still ends every successful stay on one: all
three nw sieges that got in left at `INSIDE_MAX` (240 s, "time inside, the most") with every member alive and "lost 0.000
a second" inside, and then lost a third to half of their number to lasers on the way out. Waves 1, 2 and 3 broke 1,658,
1,559 and 479 buildings in four minutes under no fire and were called home into the guns. The stay-pricing of 0.2.86 is
right in principle and is `unpriced` for exactly the waves that matter (a siege's or a plan's own target), so the clock
runs them.

### What a player sees and can counter

Seen: the stain, the technicians, the scout, the bursters, the trail, the hole, the stay. Counterable: kill the scout
(the wave comes anyway now, so this is a warning not a counter), kill the technicians (quiet, strong, and hard to find:
the only counter that attacks the economy), artillery on the clinic or the pens (the pod relocates), shape the base
(the real counter), clean up the air (slow, honest, and the most on-theme). What a player cannot see or counter: why
the farm is holding, what a siege is waiting for, and that five cultures are about to arrive at one wall within eight
minutes of each other. The chat is off by default; the map tags say "Synthexis culture 3". A player on nw would have
experienced 0.2.88 as three hours of nothing and then three waves at the east wall in a quarter of an hour.

### Over-engineered and missing

Over-engineered: the order system (bursters to order, big biters to order, `tough_wanted`, counters' fit, UNFIT, the
dearest-first fulfil) when the siege already sizes its own mix; the probe (off by default); novelty and `teach`
(4p(1-p)) when the trace shows every culture choosing the same cell by worth anyway; three time-outs on saving.
Missing: a sink for biomass that scales with income (section 2); a stay that ends on what happens; a wave sized by what
the culture holds rather than the least that pays; one line to the player when a culture lays a siege (the equivalent of
a corporation's war footing); and a measurement that separates Synthexis's script cost from the corporations' in a visit
(the 5.05 ms figure is the whole mod with the march trace on, see section 3).

## 2. Economy and growth

### The model, in its own terms

Income is linear in creep tiles and incubators and rises with evolution (`creep.drink`, `evo_rate` up to 2.4x). Growth is
a share of income into a pool held at 450 and spent on buds, incubators, technicians and carriers; that pool is capped
by `TUMORS_MAX` (40), `PENS_MAX` (16), the culture cap (5) and the field. Breeding takes the rest and spends it on
whatever the evolution table rolls, stopping when the pens are full. So the only thing that scales with income is units,
and units stop at the pens' cap and at the engine's crowd rule (`max_friends_around_to_spawn` 40 within
`spawning_radius`, prototype-api: incubators standing within one another's radius share one crowd, which is why seven
incubators hold about 60, not 280). Everything else is a fixed ceiling. A culture past its ceilings is a bucket with the
tap on.

### The hoard, diagnosed from the trace

Culture 2 (seeded at 571,-583 at 1h12m) ended with 14,898 biomass, growth 450, 7 incubators, 306 bred. Three faults
stack:

1. **A fictional field.** `siege_size` and `target_from` take `field = #pens * 40` (252 to 280 for culture 2). The crowd
   rule gives it 60. Every siege it considered needed a herd of 473 to 815 (`n = 2 * lost + 1 - k`), so none was ever
   laid. Cultures 1, 3 and 5 laid sieges of 29 to 35 because their walls happened to be cheap enough. The number the
   planner reasons with is four times what the culture can stand up.
2. **A target it cannot open, chosen forever.** Its target at -456,-418 has 10 guns covering the breach and 6 a
   burster can reach (the other four are behind the wall: nw's flamethrower line). `target_from` sizes the siege with
   `herd.way_cost(raw, c.cover, k)` and never passes `openable`, so twelve bursters read as opening all ten guns and the
   coarse estimate says "a siege with 12 big bursters". `herd.plan` then reads six openable, `siege_size` finds no herd
   within the field, and the farm writes a `dear` record and retries in ten minutes. The dear record fades after 30
   minutes and the coarse map (48-tile cells, radius over 600) prices the same way in under 30, so `passes` is true
   again, the wave of 60 is planned at about 500 and refused. The trace shows the two messages alternating for the
   whole run: 26 "no siege it can lay at -456,-418" and 16 "its plan for -456,-418 costs about 500: its 60 cannot pay
   it". It never once weighed a second place, because the siege choice is "the fewest bursters for the worth" and this
   place wins that on a number that is wrong.
3. **No sink that scales.** Even where the planner works, the other four cultures spent their income on chance
   breeding at evolution 0.9: the faction ended with 645 idle units standing on creep, 165 of them behemoths at 200
   biomass each (33,000 biomass of army that never moved), while every wave it sent carried 35 to 42 units, the least
   its plan said would pay. The hoard at culture 2 is the visible form of a faction-wide pattern: income has nowhere to
   go once the pens are full, and the waves are sized by the minimum, not by the stock.

Note that 0.2.88's growth pool solved the fault it was built for (growth no longer starves while a siege saves) and
exposed this one, which was always there. A sated culture is the designed outcome of a bucket economy.

### How I would solve it

The user dislikes numeric limiters, and this one needs none, because the fix is to remove a ceiling, not to add one.

**Biomass is the stock. Hatch at launch.** Today a culture's army is entities standing at the gate, capped by the engine's
crowd rule and by `PEN_CAP`, and biomass is the fuel that refills them. Turn it round: an incubator's stock is a count
("clutch"), paid in biomass as births are now, and the units exist as entities only as the home guard and when a wave
is launched. `send` already creates scouts, runts and ordered units by script (`bred_stock`, `fulfil`, the sweep); make
that the only path, hatching the wave over its 90-second gather at the pens (the player's tell, better than today's
crowd: the incubators pulsing biters out for a minute and a half while the scout is already looping). Consequences:

- The field is `biomass / price of the mix`, bounded by the engine's unit-group size (`max_unit_group_size` applies only
  to automatically created groups per the API, so a script group of 300 is allowed; split into the squads the herd
  already forms past the breach if group behaviour degrades) and by the time the hatch takes. Culture 2's 14,898 is 49
  big bursters and a herd. The flamethrower wall at -456,-418 stays unopenable (right), and the north wall of lasers
  becomes a siege any one culture can lay alone.
- 645 idle units become zero. That is the cheapest UPS win available, and the creep bonus pass each second shrinks with
  it.
- The crowd rule and `PEN_CAP` stop mattering, so `siege_size`'s field becomes true by construction.
- The pen's `result_units` table still decides what the clutch is made of (roll the breed at pay time and keep a count
  per breed), so the arena's prices and the evolution ladder are untouched. Recycling (0.2.14) becomes a subtraction.
- Loss on the counterplay side: a raid on the pens today kills stock; after, it kills the guard and the incubator (the
  clutch dies with the incubator). That is the same counter, cheaper for the player, which I would accept; add that an
  incubator killed loses its culture the clutch it held (biomass in the open, destroyable), so artillery on the pens
  stays the strong counter it is.

**Size the wave by what it holds, not the least that pays.** `siege_size` returns the cheapest mix that passes
`affords`. Once a culture can afford the plan it should send what it has above its guard, up to what the stay can use:
the extra is what razes the economy behind the wall rather than 1,600 buildings in four minutes. A rule, not a number:
the herd's size is the larger of what the plan needs and what the culture holds, and its bursters are the plan's. With
the hatch model this costs nothing in idle units.

**Carry `openable` into the coarse estimate, and record what the plan learned.** `target_from` should call
`herd.way_cost(raw, c.cover, k, openable)`; the coarse map does not know `openable`, so a `dear` record should carry
it (`{lost, openable, cover}`) and `target_from` should read it for the siege estimate, not only for `entry`. A place
whose plan refused a siege should be priced at that plan until something there changes (a gun dies, a wall opens), not
for a fixed 30 minutes. That kills the loop at culture 2 and is a ten-line fix worth doing before anything else.

**Let the stay end on what happens.** Price a siege's stay as 0.2.86 prices a raid's (the stay rule is `unpriced` for
exactly these), and let the wave stay while it is bringing things down and the fire on it is below what it can bear,
walking home when its bite is spent on what is worth nothing or when the way out gets dearer than staying. The trace
shows the opposite today: a wave that is winning is sent home into lasers by a clock.

What I would not do: a "sated culture stops drinking". It is a numeric limiter in disguise (sated at what?), it hands
pollution to the wild nests (which then raid the player and are billed by Kessler-Hayashi's ledger), and it fixes the
symptom while the bucket stays. Nor would I raise `WAVE_MAX`, `PEN_CAP` or the culture cap; those are the walls of the
bucket.

## 3. The proposal: target board, joint operations, backstop

Treated as a hypothesis. The nw trace is the test it should be read against: three cultures chose the same cell (319,1,
worth 339) independently, laid sieges within an hour of one another, and arrived at the east wall within eight minutes
(waves 2 and 1 breached 4 minutes apart, 130 tiles apart; wave 3 twenty-five minutes later). Their bursters opened 56,
53 and 24 lasers in turn, and the second and third herds walked in through the holes the first had made. That is a
joint operation, and it happened without a board, because the faction already shares one knowledge store
(`know.of("biotech").trials`, lessons, prices) and one scoring function. The question is whether to make it deliberate.

### (a) The target board: keep the idea, change the form

Keep: a faction-level view of claims, so that a culture laying a siege is visible to the others before it sends. Today
a trial is recorded at `send`, so during the hour a siege is bred the other cultures weigh the place as untried; that is
why three converged. Record the claim when the siege is laid (a trial with `pending = true`), and let novelty read it.
Then a second culture either goes elsewhere (the pressure in several sizes the user asked for falls out of novelty
alone: its best unclaimed target is smaller) or, if the claimed place is still its best by worth per biomass, joins the
claim by paying into it (below).

Change: "worth per unit spent" as the assignment rule already exists per culture (`c.gain`, `c.score`); do not build a
second scorer at faction level. The board should hold claims and a treasury, not re-rank targets. Pooling the rankings
every few minutes and assigning centrally is the Kessler-Hayashi way (a headquarters), and Synthexis's identity is
cultures that each read the base and act; a visible headquarters would blur it.

On "multiple targets of various sizes": yes, and the way to get them is to stop every culture sizing to the same
minimum against the same heart. With the hatch model a culture's wave is sized by its stock, so a young culture of 300
biomass raids an outpost and a mature one lays a siege, and novelty keeps them off each other's cells. At most one joint
operation at a time is a reasonable rule but I would not code it as a counter; the treasury (below) gives it for free,
because one claim drains the surplus.

### (b) Joint marching to a shared staging point: drop it

This is the part the user was right to be wary of, and I would not build it.

- Pathing. Cultures stand 300 to 600 tiles apart (nw: 571,-583 to 987,-179), each 600 to 1,000 tiles from the wall.
  Each contingent's own plan is a cost map from its own pens; a shared staging point near the leading culture's breach
  is priced for that culture's approach, not the others'. The trace already shows what an unpriced leg does: Kessler-
  Hayashi's camp sat on the march and "bled every siege" until 0.2.85 taught the wave to price and turn on it. Adding
  three more routes through that geometry multiplies the places this can go wrong (rival camps, forests over
  `FOREST`, water the 16-tile cells read as open, mines between the staging point and the wall) and every one of them
  is a failure the player never sees as intent.
- Timing. The contingents arrive minutes apart (nw: 4 and 25 minutes). A group told to `stop` at the staging point
  with `distraction = none` will not answer fire; with `by_enemy` it is drawn off into the guns (the lesson of the
  siege test, 49 lost in five seconds). A staging point "out of all fire" for one plan is within the sweep of a
  mobile defence (tanks killed 3, 2 and 4 of the nw waves at the breach). Waiting is losing. The time limit then
  breaches with what has arrived, which is a sequential wave with extra walking.
- The gain is small. Sequential waves through one hole are the faction's signature ("waves come back through holes
  earlier ones made"), and the nw sieges show it working. The one thing a simultaneous breach buys is more bursters at
  the wall at once, and that is bought cheaper by moving biomass than by moving biters.
- Recall. A pen hit recalls its culture's wave. In a joint operation that pulls one contingent out of a line at the
  breach; either the recall is suppressed (the raid-on-the-farm counter breaks) or the operation falls apart on a
  single raid.

Do instead: **pool the biomass, not the march.** A culture that cannot spend (its best siege refused, or its stock past
what any plan it can reach would use) pays into a claim it would have joined, and the claiming culture breeds the
bursters with it. The faction has one knowledge store already; a treasury beside it is twenty lines. If the user wants
it visible and counterable, the existing carrier walks it: a carrier with an escort leaves the rich culture for the
besieging one carrying the biomass, on the routed legs that already seeded five cultures on nw, killable in the open
(the player cuts the supply line; the biomass is lost). That is pathing between cultures, but one slow unit on code
that is known to work, not a hundred-unit contingent on code that does not exist. Start with the ledger, add the
carrier only if the ledger reads as invisible in play.

### (c) The backstop: drop it

Covered in section 2. It also breaks the one promise the economy makes to the player: your smoke feeds it, always. A
culture that stops drinking makes the pollution map lie.

### Failure modes to watch either way

- UPS. The 5.05 ms figure cannot be charged to Synthexis as it stands: the visit ran all three factions (683 Kessler-
  Hayashi units lost, 174 responses, five Grubstake camps), the march trace was on (2,136 "TRACE leg" lines and 212
  cost-map JSON dumps written by `helpers.write_file`), and 645 idle units stood on creep. Profile one visit with the
  trace off and the corporations off (`biotech_off` has a mirror in the system sim's solo mode) before changing any
  Synthexis code for performance. The likely heavy items, in order: `herd.plan` per farm per hold (16-tile cells over a
  700-tile radius is about 7,700 cells, each four or five engine queries, in one tick), `firemap.read` over
  `WAY_REACH * BOX` per wave stage on a base with hundreds of lasers, `creep.bonus` each second (one radius-200 query
  per culture plus a `get_tile` per unit), and `ways_from` on 48-tile cells every five minutes per farm. The hatch model
  removes the idle units; the rest wants caching by base cell as the perception consult proposed.
- Determinism. Any faction-level step that iterates `pairs(st().list)` and changes who claims first must sort by id;
  `target_from`'s own tie already had to be fixed for this (0.2.28).
- Legibility. If a treasury exists, say so once: a chat line when a culture lays a siege (notice-ok, as a corporation's
  war footing), naming the culture and the direction. The player on nw had no warning that three cultures were coming.

## 4. What I would do next, ranked

1. Kill the culture-2 loop: pass `openable` through `target_from`'s siege estimate and carry it in the `dear` record;
   price a refused place at its plan until the place changes. Check: a `farm` variant with four of ten guns behind a
   wall must weigh a second target within one weighing, not in 30 minutes.
2. Hatch at launch: the clutch as a count, units made at the gather, the guard the only standing stock. Check: the siege
   test's field equals biomass over price; the nw visit's idle army at five hours under 100; culture 2's biomass spent.
3. Size the wave by what the culture holds above its plan's need, and price a siege's stay so it ends on events, not on
   `INSIDE_MAX`. Check: on nw, waves inside under no fire stay until their bite is spent or the fire rises; razed per
   wave up from about 1,600.
4. Claims and a treasury: a siege laid is a pending trial the other cultures read; a culture that cannot spend pays into
   the claim it would have joined. No joint marching. Check: five cultures on nw produce at most one siege and several
   raids in a window, and the system sim's wave sizes spread.
5. Measure Synthexis alone: a visit profile with the march trace off and the corporations off, so the ms per tick has
   an owner. Then cache the farm's coarse reading per base cell as the perception consult laid out.
6. Prune `farm.send`: fold SAVE_FOR, WORTH_WAIT, SAVE_WAIT, STALL and ESCALATE_WAIT into "send what pays, lay siege
   when nothing does, otherwise grow", which with items 2 and 3 is what remains of them.

## Found on the way

- `farm.target_from` line 493: `herd.way_cost(raw, c.cover, opts.bursters)` and line 542 omit `openable`; `siege_size`
  and `send` pass it. The coarse and the fine estimate disagree by construction on any wall with guns behind it.
- `siege_size` line 641 and `send` line 781: `field = #f.pens * max_count_of_owned_units` ignores
  `max_friends_around_to_spawn` (prototype-api: the spawner stops when that many friendly units stand within its
  `spawning_radius`); packed incubators share one crowd.
- `finish` logs "bursters: 0 held, 0 burst, their bursts broke {electric-turret = 56}": `w.bursts.n` counts detonations
  the herd ordered, and bursters shot dead burst all the same; the count under-reads what the player saw.
- `herd.lua` `INSIDE_MAX` ends every nw siege that got in, each with all members alive and no fire on them; the stay
  rule is `unpriced` for a plan's own target (`stay_end`, "unpriced").
- `farm.lua` `holds()` throttles its trace to one line in ten minutes per farm, so the alternation of two different
  refusals at culture 2 reads as a steady state; a change of reason should always log.
- The LuaUnitGroup class is gone in 2.1.23; groups are `LuaCommandable` (the code already treats them so).
  `max_unit_group_size` (default 200) affects automatically created groups only, so a script wave is not bound by it;
  `max_wait_time_for_late_members` (7,200 ticks) governs engine gathering only, not a scripted `stop`.
- The nw visit's first wave left at 3 h 18 min after landing; five cultures stood by 2 h. Whatever else changes, the
  player's first three hours with Synthexis on a megabase are a stain on the map and nothing else; a raid-sized wave
  from a young culture (item 3's sizing by stock, the hatch model's cheap small waves) is what fills them.
