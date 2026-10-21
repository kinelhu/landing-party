# A third corporation: options to weigh (2026-10-21, nothing built)

The user, 2026-10-21: "For the third faction we need to go carefully and weigh different ideas before heading in."
This paper lays the options side by side. It decides nothing.

## Where we start

- **Two corporations, built.** Grubstake Mineral Recovery (the thief: strip-mines, convoys, raids; shotguns, buggies,
  fliers, scrap arms) and Serenity Perimeter Group (the wall: a line of posts that advances, sieges, lasers, armour).
- **Two more were designed on 2026-10-13 and never built** (`docs/campaign.md` section 4, `docs/corporations.md`):
  **Lumen Transparency** (the eye: pickets of radars far out, harriers, jamming, orbital marks; aborts early) and
  **Concord Munitions** (the dealer: tanks and walkers in numbers, garages, sells units to the others and to the player).
  Since then their signature pieces were given away: harriers went to Grubstake, the robot jammer and walkers to
  Serenity, an orbital strike to the player's research.
- **The unit web after the RTS pass** (`docs/arena.md`): small arms, splash, armour, air, with anti-armour light units
  and anti-air. What it does not have yet: anything that heals or repairs in the field, anything hidden, long-range
  fire against units (only against buildings), units that make other units better, and a way to hurt an army's economy
  in the field rather than its camp.
- **The campaign wants** (`docs/campaign.md`): a third corporation in the escalation stage, corporations that differ
  by what they attack with, how they defend, where they break and what ground they want, and corporations that deal
  with each other (truces, alliances against a third).

## How to judge

1. **What the player sees.** Recognisable at a glance on the ground and on the map, without chat (`no chat notices`).
2. **What the player must do differently.** A new answer to find, not the same fight in new colours.
3. **What it adds to the unit web.** A role or class the two do not cover, so the arena gains a column, not a copy.
4. **Overlap.** Does it take something that already defines Grubstake or Serenity?
5. **What it does to the other two.** A third side should change how the first two play (who fights whom, who sells
   what), not sit beside them.
6. **Cost and risk.** Engine fit (what Factorio does natively), performance, testability headless.

## The candidates

### A. Lumen Transparency, as designed (the eye)
- **Sees:** a lattice of violet-lit pickets far out, radars everywhere; few guns.
- **Must do:** blind it. Kill pickets and it cannot operate; its strikes need marks.
- **Web:** nothing new. Its units (harriers, infantry) are Grubstake's; its weapon is information.
- **Overlap:** high. Fliers are Grubstake's identity now; jamming is Serenity's.
- **To the others:** sells intel? Undesigned.
- **Cost and risk:** hidden information is weak in Factorio (charting is all or nothing for a force); jamming exists.
- **Verdict:** its pillar was spent on the first two. Kept only if redesigned around something else.

### B. Concord Munitions, as designed (the dealer)
- **Sees:** garages, big orange pads full of armour, sandbag lines. Few walls; garrisons.
- **Must do:** fight armour in numbers (rocket troopers, slugs' equivalent, battle tanks), or buy from it.
- **Web:** no new class (armour heavy), but a new economy: it **sells units** to the others (its level gates what
  they field) and to the player at good standing (barracks orders for its designs).
- **Overlap:** medium. Tanks and walkers are Serenity's today; it would be armour without a wall.
- **To the others:** strong. A war profits it; killing its garages starves the other two's best units; it claims
  beside whoever is fighting. It turns two hostile neighbours into a market.
- **Cost and risk:** low on units (all exist), high on the trading layer (standing, prices, delivery), which the
  campaign left as an open question ("contracts: worth their UI cost?").
- **Verdict:** the cheapest to field, and the one that most changes the other two; its fights alone are not new.

### C. A robot swarm (proposed 2026-10-21 in chat)
- **Sees:** roboports, clouds of drones, buildings that repair themselves; almost no ground units.
- **Must do:** cut its network and its power; anti-air everywhere.
- **Web:** a support role (repair in the field), and a second air faction.
- **Overlap:** high with Grubstake's fliers; the robot jammer is already a Serenity siege tool.
- **To the others:** makes anti-air (Serenity's rifles and walkers) worth more; no trade.
- **Cost and risk:** the engine's robots are not commandable armies (construction bots follow roboports, combat bots
  their owner); its combatants would be units drawn as drones, like the harrier, so "swarm" is mostly a look. Large
  robot counts cost UPS.
- **Verdict:** a strong look with a weak mechanical core; most of it is a repaint of air.

### D. A biotech corporation (new): pest control
- A corporation that breeds and steers biters and Gleba's pentapods, and sells "pest control": it clears the
  player's nests for a fee, or sends them.
- **Sees:** fenced spawner farms, egg crates on belts, its bred biters in its colour (a tint and a collar light,
  so they read apart from wild ones), its camps in the middle of nests that leave it alone.
- **Must do:** fight a regenerating army (biters heal; Gleba's units too) that is cheap and expendable, with fire and
  splash; and decide whether to pay it. Its farms are its weak point: eggs spoil (Space Age's spoilage), so an army
  that cannot be fed in time hatches badly or not at all.
- **Web:** new. Regeneration (a unit that wins long fights and loses burst), swarms beyond anything the two field, and
  acid (a damage type no one deals today, so resistances to it become a choice).
- **Overlap:** low. Both others fight biters; neither uses them.
- **To the others:** strong and odd. Serenity clears nests and bills the player for waves: this one sells the waves.
  Grubstake avoids nests: this one lives in them.
- **Cost and risk:** biters are native (spawners, unit groups, evolution), so its army costs little to build. The
  risk is readability: bred biters must never be mistaken for wild ones, and a wave the player cannot attribute is
  an unfair wave. Its units on its own force (not the enemy force) avoid the vanilla AI pulling them into attacks.
- **Verdict:** the most new play for the least new machinery, with one hard design problem (telling its biters apart).

### E. An orbital corporation (new): it never lands
- Holds a space platform over Nauvis; drops pods (the landing already uses cargo pods), strikes from orbit, owns no
  ground for long. Wants the player's rockets and the sky.
- **Must do:** bring it down: its drops are its supply, its platform its base (Space Age's platform combat).
- **Web:** artillery against units (fire from far that lands with warning), which the web lacks.
- **Overlap:** medium; the player's orbital strike and Lumen's marks.
- **Cost and risk:** high. Platforms, a second surface, Space Age only (the mod runs without it), and the player
  cannot reach it until late.
- **Verdict:** a late-game event more than a neighbour.

## Side by side

| | A Lumen | B Concord | C Swarm | D Biotech | E Orbital |
|---|---|---|---|---|---|
| New play for the player | low | medium (a market) | low | high | medium, late |
| New role in the unit web | none | none | support, more air | regeneration, swarm, acid | long-range fire on units |
| Overlap with the two | high | medium | high | low | medium |
| Changes the other two | low | high (sells to them) | low | high (sells the waves) | low |
| Engine fit and cost | medium | units low, trade high | poor (bots not armies) | good (biters native) | poor (platforms, SA only) |
| Hardest problem | a new pillar | the trading layer | robots as an army | telling its biters apart | reaching it at all |

## A recommendation, to weigh, not a decision

Two are worth a closer look: **D, biotech**, for new play at low engine cost, and **B, Concord**, for what it does to
the other two. They are not exclusive (the campaign planned four): B could come later as the market layer once standing
and trade are settled.

Before choosing, two steps, both cheap and headless:
1. An identity consult per shortlisted candidate (as for the first two, `docs/reviews/`): what the player sees, the
   identity kit's eight points, its temper and its weak point.
2. Its signature units into the arena: a bred-biter squad (regeneration, acid) against the current matrix, or Concord's
   armour in numbers, to see what column it adds before anything else is built.
