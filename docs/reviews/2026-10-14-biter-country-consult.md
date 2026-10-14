# Corporations against biter country (Fable), 2026-10-14

After the push scenario (a wall of 22 spawners and 22 worms: 27 units pushed through, 26 died; a raid on one spawner
lost all 18) and the visits to the user's late save (most operations "no way round biter country").

Hard facts: a spawner has 350 hp, fire 60% resisted, explosion only 5 flat; a mortar shell (30 physical + 90 explosion,
2.5 tiles) does about 109 to it, so 4 shells a spawner, one shell every 4 s. The mortar's 36 range beats a medium worm (30)
and loses to big (38) and behemoth (48). Flame is the wrong tool for nests and the right one for what they vomit. Units of
7 to 12 a hit cannot clear a nest at any evolution; more escorts will not change it.

## 1. Each corporation's answer
**Serenity: "The line is being extended."** It does not push through nests; it moves its perimeter through them, one
surveyed step at a time, and the player watches a row of survey stakes advance toward their wall.
- **Clearance** (operation, from era 0; needs the siege cap). Triggered when a raid or siege is refused for "no way round"
  and the ladder is on rung 1, or always for its claim. Reuses the siege code with a nest cluster as target: the site is
  the first point 33 tiles from the nearest spawner on the straight route, tier by cluster size (2 mortars, 40 shells, 10
  guards, 220 parts for up to 5 spawners; tier 3 above). It always digs in (the Hardened siege ring, two flamer
  pillboxes). The shelled spawners' defenders charge the site and burn. When no spawner stands within 36, the site packs
  up and the next one is laid 30 tiles on. Four to five spawners and worms make a 60-tile gap: about 100 s of shelling.
- **Ranging tables** (Siege node, era 2, 1,200 parts; trigger: 8 losses to killer "biter" in 30 min, or 2 clearances
  refused for worms in reach): `lp-mortar-long`, range 52, min range 20, cooldown 360, shells at double cost, beyond every
  worm. Below this node a clearance counts big and behemoth worms as impassable and sites round them.
- **Survey stakes**: each clearance leaves `lp-stake` (1x1, no collision, Serenity trim, map-marked) every 30 tiles along
  the cleared route: the corridor's memory, which the player sees and can pull up.

**Grubstake: "We don't fight bugs. Bugs are a Serenity problem."** It never clears a nest.
- **Borrowed corridor.** The route planner treats cleared ground (any spawner death in the last 30 min, by any force, the
  player's artillery and landings' clearings included, plus 30 tiles) as passable: `storage.corridors`. Grubstake follows
  the survey crew; the player sees its buggies on Serenity's stakes.
- **Overflight** (unlocked by the Scavenger harrier node, era 2). Six Scavenger harriers fly the straight line over biter
  country, distraction none, to the softest edge target beyond laser reach, leave at 70%, home the same way. Spike first:
  does a worm or spitter fire on `lp-air-unit`? If yes, overflight routes 50 tiles round worms only.
- **Tailings** (Loot node, era 1, 600 parts; trigger: 2 operations refused for "no way round"): a hauler drops a polluting
  heap 80 tiles outside the player's outer buildings on the biter side, 10 minutes; "Mine tailings disposed at [gps].
  Environmental compliance: pending." Visible, announced, destroyable; build last.
- At rung 3 it still goes with everything, and dies, but only after the three above.

## 2. The ladder
Rung 2 (40 min): "push through" becomes "open a corridor". Serenity launches Clearance on the first cluster, then the next,
until the planner returns a route; the raid or siege is then sent through it. The corridor stands while no spawner stands
within 30 tiles of a stake; biter expansion refills it, and the next operation re-clears it (maintenance, tier 1, 100
parts). Grubstake at rung 2: Overflight if it has harriers, else it waits for a corridor. First raze by minute 55-60 after
first sight; a raze per 10 min per corporation on the corridor after.

## 3. Side effects on the player
Nests near the player disappear along one line: biter pressure from that side drops (evolution unmoved); the corridor is
a road both ways. Biters re-expand into it: Serenity comes back to clear it. Tailings are a nuisance to a mid-game player
and nothing to a laser wall; they do not satisfy the user's requirement.

## 4. Headless checks
- `push` (unevolved): a Clearance within 10 min of the refusal; >= 4 spawners and >= 4 worms dead by 15 min; a route
  found; target razed; raid losses <= 30%; site losses <= 1 mortar; evolution unchanged.
- `push evo1` (big and behemoth worms, Ranging tables): zero worm hits on the site; target razed within 25 min.
- `push grubstake`: Overflight sends 6, >= 3 return, one target razed; a ground raid routes through Serenity's corridor.
- `corridor`: a spawner placed back in the corridor: re-cleared or routed round, never "not sent".
- Visit nwa, provoked at the hour: razed >= 1 per 10-min row per corporation from minute 70; no 30-min window at zero;
  "no way round" under 20% of operations; >= 3 clearances; script <= 3.5 ms a tick.

## 5. Build order
1. Corridor memory and stakes; the planner routes through cleared ground. 2. Clearance on the siege code, dug in.
3. Ranging tables. 4. Overflight, after the worm-versus-air spike. 5. Tailings.
