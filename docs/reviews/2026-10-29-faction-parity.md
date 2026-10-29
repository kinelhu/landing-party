# Bringing the corporations to Synthexis's level, or releasing in stages (2026-10-29)

The user: "we're going to need a deep think about how to bring the other factions to parity with the level of complexity
we introduced to Synthexis... another option is simply splitting off each faction in its own mod, so we can release in
stages". Analysis only; nothing built.

## Where each stands

Kessler-Hayashi and Grubstake run one engine (`scripts/ops.lua` and its installed parts: intel, routing, siege, strip,
cuts, answers, perimeter); they differ by `shared.CORPS[id].mind` and `.temper`. Synthexis (herd, farm, creep, cell) is
its own engine, built since 0.2.32 on a shared perception layer (threat, firemap, costmap, valuemap, know's prices).

| | Kessler-Hayashi and Grubstake (ops) | Synthexis (herd, farm) |
|---|---|---|
| What it knows | scouted: radars, depots, field sight, a survey toward spawn; facts read live once seen | the whole map, its mines too |
| Choosing a target | `value·p^caution/(1+d)^loss_aversion/...`, its defence estimate from turrets by research and power, resistance learned per target | worth and keep from a value map, the way in priced by a cost map, sieges when nothing pays |
| The way there | A* on 6-tile cells, turret reach blocked or open (Grubstake only), nests blocked; no price | one plan: a cost map of fire, walls, mines, deaths, blocked ground; followed leg by leg |
| Sizing | `3.5·defence + 4`, rechecked at its staging point | the cheapest mix that pays its plan, within what it can field |
| Breaching | Kessler-Hayashi: mortar sieges in tiers (bombard, move up, assault on a clock or dry shells); Grubstake: the least covered wall piece | sweep, bursters, herd, each when the one before is done; punch-through to its target |
| Learning | per target (resistance, rivals' hold), unit mix tilted by its losses; no prices, no calibration | prices by prototype from a prior, calibration of expected against lost, lessons by face |
| Contact on the way | fights what hits it; no re-plan | learns, prices the fight, takes it or goes round |

The corporations are not crude: they scout, they read research and power, they siege with artillery and they learn per
target. What they lack is Synthexis's one model of cost: they never price fire, so a route is open or closed, and their
sizing is a fixed multiple of an estimate that is never checked against what crossing cost.

## Parity: what transfers and what does not

Transfers as it stands (the perception layer reads the surface only, its prices and forces as parameters):

1. Routes priced, not blocked: `costmap` in place of `sneak_route`'s yes/no turret reach. The biggest single win, and the
   same fault Synthexis had (a route that walks along a ring of guns because the ring is "open" a tile off its reach).
   Kessler-Hayashi would gain a real way in rather than "the first wall on its line".
2. Prices and calibration: `know.price` and `know.scale` are keyed by faction already; the corporations need the
   recording side (what herd's `learn_price` and `learn_march` do), moved from herd into a shared place.
3. Targets by value map: `valuemap.hearts` in place of the fixed `ops.VALUE` per cell.
4. Plan once: `herd.plan` generalised (its price, deaths, hidden cost and mind passed in), then each corporation's raid
   follows one plan, as Synthexis's waves do.
5. Event-driven sieges: Kessler-Hayashi's assault waits on a clock (ASSAULT_IDLE) or dry shells; it should go when its
   mortars have silenced what covers its way in, read from the same fire map.

Does not transfer: the sweep, bursters, the punch-through and creep are biters' answers. The corporations' answers to
the same problems are their own: sappers or mine-clearing vehicles for mines, mortars and howitzers for walls (they have
those), armour for a punch-through. Parity means the same reasoning with their tools, not the same tools.

Order, by value for effort: 1 (priced routes), then 2 (prices learned), then 5 (sieges on events), then 3 and 4. Each is a
slice the regression and the arena can judge; 1 and 2 touch both corporations at once, since they share the engine.

## Splitting into separate mods

What the code allows:

- Kessler-Hayashi and Grubstake cannot be split from each other: one engine, one `storage.bases`, and rivalry written
  through it (reprisals, `held_by`, grudges, truces and the ladder, war chest, bait and strike, Grubstake's pact).
- Synthexis is separable: its state is its own (`storage.herd`, `farms`, `creep`, `cells`); its ties are `know.lua`,
  three hard-coded corporation ids (its truce with Grubstake, Kessler-Hayashi as a target on grievance, the corporations
  counted as hostiles in its fire map) and two optional hooks into ops (`route`, `outside`), which it already checks for.
- A split would need a core mod (shared, threat, firemap, costmap, valuemap, know, ground, stance, tune, rng; routing once
  its binding to ops is removed), `control.lua`'s mixed handlers untangled (one damage handler feeds both `know.loss` and
  `ops.provoke`), cross-mod remote interfaces for what the factions say to each other, and migrations for saves that
  have all three in one mod.

So the realistic split is two mods on a core: "the corporations" and "Synthexis", not three.

## Recommendation

Release in stages without splitting the mod yet: a startup setting per faction (Kessler-Hayashi, Grubstake, Synthexis),
the unfinished ones off by default. The code already lets Synthexis run alone (`biotech_off` and the system sim's solo
mode do the reverse); the corporations' code runs without Synthexis today. Settings cost a day; a split costs a core
mod, an untangled `control.lua`, cross-mod interfaces and save migrations, and buys only what settings already give
(choosing which faction plays) plus separate portal pages.

Then, in this order:

1. Ship Synthexis first (its own level of reasoning is now the deepest; the corporations on by choice), once nw shows its
   first razes past the wall and deathworld holds.
2. Move the perception layer's recording side (prices, calibration) out of herd into `know` and a small `plan` module,
   so the corporations can use it.
3. Bring the corporations up in the order above, priced routes first, judged by the regression and the arena.
4. Revisit the split once the core has settled: by then the shared layer is the core mod, and the two halves' coupling
   is known.

The one reason to split earlier: if the portal audience for "smart biters" and for "rival factories" turns out to be
different people. That is a product question for the user, not a code one.
