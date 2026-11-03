# Factorio RTS (Kealman/factorio-rts 0.1.4): what Kessler-Hayashi's movement can take from it

Read 2026-11-03 (code and docs only, nothing run; repo github.com/Kealman/factorio-rts, MIT). The question (the user):
KH's larger armies move as a blob, as biters do; something more orderly, RTS-like, without heavy CPU?

## Not a dependency
It owns the game: on load (`on_configuration_changed`) `camera.setup` destroys every player's character with its
inventory (`scripts/camera.lua:184-188`), forces remote view, adds a permission group blocking crafting and driving,
turns Freeplay's starting items off; own forces and surfaces (`scripts/match.lua:502-545`), a lobby over Freeplay. No
remote interface; its divisions take only units of its own registry and forces. Never enable it beside Landing Party.

## How its divisions move
One engine unit group per division, one command per order (one path). The order comes on arrival: the group is
destroyed and each member walks to a slot of a grid facing the direction of travel (`orders.formation`,
`scripts/orders.lua:437-505`; ceil(sqrt(n)) columns, slots sorted front to back, then left to right, so walks do not
cross); stopped after 20 s. Lines: `fronts.lua:695-722`, slots along a chord, members matched by projection; drifted
members re-sent. Stragglers re-added every 300 ticks; a vanished group's order re-issued, idle after 3 failures; a
stalled attack (no damage for 5 s within 40 of its target) breaks into per-unit `attack_area`.

Measured and rejected there: leader and followers, twice the CPU (3.2 ms against 1.5 ms a tick), 575 of 768 strung out
(`docs/qa/phase5-divisions-notes.md:15-24`).

## CPU
A queue of path requests (`orders.queue_command`, `scripts/orders.lua:133-275`): at most 100 unit and 4 group commands
a tick, at most 2 groups pathfinding at once. 48 groups of 16: 1.7 ms a tick on average; 48 group orders in one tick
spike to 19-21 ms, capped 6.5-7.8 ms. `docs/research/scale/war-ai-performance.md` is a good benchmark write-up.

## Engine facts (their 2.0.77 probes; recheck on 2.1.23)
- `set_command` on a member takes it out of its group; `add_member` moves a unit from another group.
- `group.destroy()` fires `on_ai_command_completed` (fail) and leaves members wandering: command them at once.
- A group's command succeeds once the group is within its own size of the destination (30 walkers 12.5 short).
- Deaths raise no `on_unit_removed_from_group`; a group whose members all died turns invalid without an event.
- 2.1: `MapSettings.steering` gone, steering per prototype (`data-updates.lua:27-38`); copies of vanilla units inherited
  about 20 times the old separation push. Check what KH's units inherit.

## Taken
- Code (MIT, with attribution): slot assignment (adapted: a line at a siege's site spaced by threat.splash, staggered
  rows for waves), the capped path queue, slotting on arrival.
- Ideas for its decisions: attack at 0.8 of the strongest enemy force seen lately (strength as summed health ratio);
  fall back at 40% of its health at launch; top up an attack under way; recall a phase past its timeout.
- Not taken: a march column (nobody showed it cheap).

Not read: most of `ai/commander.lua` and `ai/planner.lua`, `ai/council.lua` past its header.
