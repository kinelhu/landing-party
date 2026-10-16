# Builders: construction as a physical act (Fable), 2026-10-16

Read-only consult. The user: landers build with "a weird blue laser", decorporealized next to a mod where everything else is a unit doing a thing. The power tap just took the step (a buggy drives the route and plants each pylon). Should construction follow, and how?

## Frame
Yes, but not by making every brick walk. Today `base.lua` already pays an invisible constructor for rebuilds (60 s plus 1 s a tile from the lander) and nothing for growth: the travel exists in the numbers and not on the map. The fix is to give that constructor a body, keep the per-entity build clock, and keep the first minutes and the inside of a compound as they are. One rule the player can learn: **a yard builds what it can reach; crews build the rest.**

- **Yard**: everything within 40 tiles of the lander or of a depot is built as now, from that building, with its own effect. Serenity keeps the beam, now short and from the nearest depot or the lander (a warp-in, on brand for the Protoss). Grubstake gets a crane arm, sparks and dust, no beam.
- **Crew**: a module beyond every yard (a mining outpost, a far block, a picket) is built by a unit that leaves carrying the module's whole bill of parts, drives or flies to the site, builds each entity at the same 1.5 s with the effect drawn from itself, and goes home.

## What each corporation shows
**Serenity**: a constructor drone per depot plus one at the lander, flying (harriers already ignore walls), fast, lit, projecting the beam at the site. Precise and few: one drone per module, the beam the player already knows, now with a source they can shoot. Real engine construction robots (ghosts, roboports) are the tempting version and I advise against it for the first slice: the planner's synchronous guarantees (a failed key entity abandons its module, `slot.filled`, rebuild ordering, parts debited at placement) all go through `place()`, and the engine would own the order, the charging and the item plumbing (every lp-* prototype needs a placeable item). Keep real robots as a possible mature form for Serenity once the drone shows the shape; the jammer fallback already assumes robots in the field.

**Grubstake**: a builder truck (the hauler's hull with a crew on the bed), ground-bound, on its gravel roads, slow, with Shotgun hands riding along at war. Felt before seen: the player finds a truck parked at a new outpost with men welding. It is the richest soft target on the map and should be.

**One codepath, two bodies.** `scripts/crew.lua`, one unit kind `lp-crew` with per-corporation variants through `shared.variant` (collision mask, speed, effect). Identity lives in the body and the effect; mechanics are shared, as tap.lua's run (`drive`, `run_step`, stuck timer) already is. Lift that runner out of tap.lua rather than writing a third one.

## Counter-play and cost
- A killed crew drops its remaining bill as Factorio items (the loot rule: things drop what they are made of). The player who ambushes trucks on the outpost road starves growth and gets steel and circuits for it. Bound it: a crew carries one module's bill, never more; at most two crews out per settlement.
- The settlement loses the parts, requeues the module after the rebuild delay with `tries` as rebuilds have, and builds a new crew at a depot (20 parts, 30 s). At war footing units come before crews as they do before rebuilds.
- A crew whose site becomes `occupied` turns back and its parts go back to stock (the `convoys_stuck` pattern); it never builds under a player's turret.
- Serenity's drone is fast and fragile: gun turrets reach it, walls do not stop it. Grubstake's truck is slow and tough and takes roads: it can be blocked, and an escort follows at war.

## Pace
Growth is timed by `BUILD_TICKS` per entity and the planner's 5 s cadence; crews add only travel per module. A module of 10-30 entities takes 15-45 s to build; a truck at 8 tiles/s reaches an outpost at 90 tiles in 11 s, a drone sooner. Keep the pace comparable by:
1. the yard rule: everything in the first minutes and the hubs' interiors is unchanged;
2. building at the site at the same 1.5 s per entity;
3. a second crew per settlement from the first depot, so the next far module is loaded while one is away;
4. dropping the 1 s per tile term from rebuilds a crew actually travels (otherwise travel is paid twice; a rebuild with a crew gets faster, not slower).
Measure, then set crew speed so the `grow` sheet's 12 seeds hold their block and outpost counts at 60 minutes within 15%; that is the number the 95 scenarios lean on.

## Edge cases
- **Inside its own walls** (gates open for no unit): the yard rule covers it, a walled compound holds its depot or the lander. A crew forms past the outermost wall on its line, as the fixed convoy does; one not nearer its site for 60 s turns home with its parts and is counted (`crews_stuck`, asserted zero).
- **The landing**: the pad, the first drills, the escort ring are all within the lander's yard; the escort timing in `grudge`/`phases` must not move.
- **Far outposts** (reach 160): crews, the case this is for. A truck lost there is the player's doing.
- **Under fire**: the occupied check stops the crew before it arrives; a dead crew is a dropped bill and a requeue, never a stuck module.

## First slice, ranked, with tests
1. `crew.lua` and the yard rule, Grubstake truck first (ground is the hard case). Scenario `crew`: a camp with an outpost queued 90 tiles out; a crew leaves the lander, every entity placed within 10 tiles of it, the module built within 1.3x today's time, the crew home, parts debited once; `crews_stuck == 0`.
2. Loss and requeue. `crew LP_MIX=killed`: an armed turret on the road; the crew dies, items on the ground equal the remaining bill, the module built by a second crew within 3 minutes, stock debited no more than the bill plus one crew.
3. Walls and interiors. `crew LP_MIX=grown` (the convoy's nine-block fork): a block inside the compound destroyed and rebuilt by the yard with no crew; an outpost built by a crew formed past the outermost wall; none stuck.
4. Serenity's drone: the same three with the flying body; the drone crosses a wall line and builds; a gun turret kills it in flight.
5. Pace gate: `scripts/regress.sh` passes; `grow` on the sheet's 12 seeds within 15% of the committed counts; `grudge` escort tick unchanged.

What the player tells a friend: "Serenity's drones beam outposts in from the air; Grubstake sends a truck with four men and a welder, and if you catch it on the road you keep the steel."
