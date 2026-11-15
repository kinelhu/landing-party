# The manual's pictures (2026-11-05)

Made for the consult's section 3 (docs/reviews/2026-11-05-manual-voice-consult.md) and the user's note on the current
book: "some screenshots are reused a lot it seems? And not extra clear". Everything here is filmed by full day
(daytime 0.02, clouds hidden), two to three times closer than the trailer's frames, and cut at print size (an A5 page
is about 1750 px wide at 300 dpi). Each file is under 1 MB.

**Refilmed 2026-11-12, at 0.2.339, on the laptop** (the faction buildings remodelled since 0.2.298): the Kessler-Hayashi
camp plan (`m-khcamp.lua`, positions unchanged), the Grubstake hero (`m-strip.lua`, now `strip-z12-13800`, box moved
onto the camp at the patch's north edge), the claim plan (`m-claim.lua`; its drill callout "Drills", the bins under
them), the landing strip and still (`m-landing.lua`; the lander now comes down south-east of the old spot, boxes moved
onto it), the army hero and the Kessler-Hayashi assault (`m-trailer.lua` on a fresh trailer fork; the same ticks hold),
and a new still, `stills/selection-panel.jpg` (`m-cards.lua`, the screen GUI shown). Not refilmed: the Kessler-Hayashi
hero, the siege plan and the orbital strike strip (nw-khwall's siege no longer deploys at current code: 50,000 ticks of
march), the Grubstake column (the fortress fork's column stays bunched at its yard), and the Synthexis pictures (no
change to show). `CUT_ONLY=out1,out2` cuts only those.

**Filmed 2026-11-15, at 0.2.422, on the laptop** (`m-director.lua`, `m-director-panel.lua`, on scenario director's film
set, `scripts/film_fork.sh director 12345 13 film`; the beats driven by the plugin's `director` list): the Headquarters
chapter's six stills, `stills/strike-pods.jpg` (a strike force's pods coming down among the player's assemblers and
labs), `strike-fight.jpg` (Grubstake's force in the labs), `strike-broken.jpg` (a force broken by a ring of gun turrets
on its way home), `blackout-mast.jpg` (a mast in a gap of a Grubstake camp's wall), `salvage.jpg` (a crashed shuttle
and four guards) and `director-panel.jpg` (the `/lp director` panel, at 3840x2160 so it is whole). The set's power
(an electric energy interface beside each cluster) is cropped out. Not made: the map tags (bounty, strike target,
contract, rotation), which show only in map view, and the helper's screenshots render the world view only.

How they are made:

- **Films**: one params file each in `docs/manual/shots/m-*.lua` (its header gives the save, the fork and the
  `scripts/film.sh` command). The frames go to `docs/sim/film-<name>/` (gitignored).
- **Portraits**: `docs/manual/shots/portraits.lua` (film) and `portraits.py` (cut).
- **Everything else**: `docs/manual/shots/cut.json` lists each picture's still and crop box;
  `uv run --with pillow python docs/manual/shots/cut.py docs/sim docs/manual/media [preview dir]` cuts them all and
  writes each plan's callout JSON (and, with a preview dir, a copy with its numbered dots drawn, for checking).

## Unit portraits: `portraits/<prototype>.png` (41)

One for every unit in `_generated/lp-data.json`, named by prototype: 760 x 760 PNG, each unit alone on a flat grey lab
tile, on its own force, faced south-east (the three-quarter view the sprites are drawn in), at noon, its shadow kept,
the ground lifted to a soft vignette (the unit's own pixels untouched). Same angle, light and ground for every unit of
every faction. The cutter picks the closest of three zooms that holds the unit whole and crops round it.

- Source: the gallery profile's fresh map, `scripts/film.sh gallery fresh.zip docs/manual/shots/portraits.lua`, then
  `uv run --with pillow --with numpy python docs/manual/shots/portraits.py docs/sim/film-portraits docs/manual/media/portraits`.
- **New**: the three units that had no portrait: `lp-bred-big-burster.png`, `lp-sweeper.png`, `lp-bred-carrier.png`.
  Also new: `lp-infantry.png`, `lp-grubstake-howitzer-truck.png` and `lp-grubstake-hauler.png` (lp-data names these as
  portraits but `media/units/` had no file for them).
- **Replaces**: `media/units/*.png` (240 px top-down on grass). Point `lp-data.json`'s `portraits` at `media/portraits`.
- Known limits: the drones' sprites are small (a crop of at least 600 px keeps them from showing their pixels, so they
  sit smaller in the square); the Synthexis biter breeds share one silhouette in the game itself, so their portraits
  differ by colour, not shape. The stomper walked off its mark and is cropped from the widest still.

## Faction heroes: `heroes/*.jpg` (4), 1750 x 984

One per faction opener, each an event rather than a yard.

| File | Shows | Source | Goes |
|---|---|---|---|
| `heroes/kessler-hayashi.jpg` | The orbital strike falling on the user's walled laser bastion while Kessler-Hayashi's troopers walk in under it | nw-khwall-saveat15 `t15.zip`, `m-khwall.lua`, still `assault-220` (220 ticks after its assault starts) | Kessler-Hayashi opener |
| `heroes/grubstake.jpg` | A Grubstake strip camp on the player's ore patch, beside the player's own two drills: its drills and bins, generator, pylon, hauler, guard buggies and a shotgun hand | strip 12345 fork at minute 4 (`LP_FORK_MINUTES=25 scripts/film_fork.sh strip 12345 10`), `m-strip.lua`, still `strip-z12-12000` | Grubstake opener |
| `heroes/synthexis.jpg` | The herd at the user's north wall: bursters going off green at the outer wall, flamethrower streams and lasers into the pack | nwa-nwwallheavy-saveat13 `t13.zip`, `m-nwwall.lua`, still `breach-z10-0480` (480 ticks after the breach order) | Synthexis opener |
| `heroes/player-army.jpg` | The player's army (battle tanks, troopers, flamethrowers) fighting through a Grubstake camp | trailer fork (trailer 12345 at minute 8), `m-trailer.lua`, still `army-z12-041820` | Army opener |

**These replace the faction vistas on the openers.** The vistas (`vistas/grubstake-wide.jpg`, `serenity-wide.jpg`,
`synthexis-night.jpg`, `player-base.jpg`) should then appear once only, on the front cover strip; the back cover strip
should stop repeating them (consult 3.3 item 7: either drop it, or set four portraits side by side there, for instance
`lp-infantry`, `lp-shotgun-hand`, `lp-bred-big-biter`, `lp-trooper`).

## Annotated plans: `plans/*.jpg` + `plans/*.json` (4)

Each JSON: `image`, `width`, `height`, `caption` (a suggested one), and `callouts`, a list of `{n, x, y, label}` with
x, y in the image's own pixels (the dot's place; the lead's callout component draws the dots and the numbered list).

| File | Shows | Callouts | Source | Goes | Replaces |
|---|---|---|---|---|---|
| `plans/kessler-hayashi-camp.jpg` (1750 x 984) | An armed Kessler-Hayashi camp inside three rings of wall | lander, orbital relay, generator, laser turret, walls, mine (drills and bins) | nw-khwall-saveat15 `t15.zip`, `m-khcamp.lua`, still `camp-z06` | Kessler-Hayashi, the camp section | `vistas/serenity-close.jpg` (p. 13) and `clips/armed-landing.jpg` (Arrivals) |
| `plans/kessler-hayashi-siege.jpg` (1750 x 984) | A drop siege in place: its dome projector, mast and guns, the spotter painting the strike, its escort | dome projector, jamming mast, mortars, howitzer, spotter, escort tanks, escort troopers, the strike's rings | `m-khwall.lua`, still `siege-z13-0060` (60 ticks into its bombardment) | Kessler-Hayashi, sieges | the siege half of `clips/drop-siege.jpg`'s job (see the still below) |
| `plans/synthexis-culture.jpg` (1750 x 984) | A young culture on its creep, by its lake | incubator, biochamber, tumor, worm, technician, heating tower, clinic, the creep's edge | farm 12345 fork at minute 10, `m-culture.lua`, still `culture-z09` | Synthexis, the culture section | `clips/synthexis-creep.jpg` |
| `plans/grubstake-claim.jpg` (1200 x 800) | A claim Grubstake built on a patch it staked | drill and its ore bin, pylon, generator, the staked patch | prospect 12345 fork at minute 14 (`LP_FORK_MINUTES=30 scripts/film_fork.sh prospect 12345 20`), `m-claim.lua`, still `first-z14` | Grubstake, "Claims and the trade post" | (new: the section had no picture) |

Not shown, and why: the Kessler-Hayashi camp has no labs (none of the camps filmed had called for research yet; the
caption says so); the claim's stake and road (the stake is gone once the claim is built, and no hauler was on the road
when it was filmed).

## Sequence strips: `strips/*.jpg` (3 strips of 3), about 900 px wide each

Three frames set across the page, left to right.

| Files | Shows | Source | Goes | Replaces |
|---|---|---|---|---|
| `strips/orbital-strike-1-paint.jpg`, `-2-shadow.jpg`, `-3-fall.jpg` | The spotter's beam and rings on the bastion; the platform's shadow passing over it; the lances falling on it | `m-khwall.lua`, stills `paint-450`, `paint-650` (after the paint event), `fall-110` (after the fall) | Kessler-Hayashi, the orbital strike | `clips/orbital-strike.jpg` (p. 16) |
| `strips/landing-1-pod.jpg`, `-2-hull.jpg`, `-3-pods.jpg` | Grubstake's landing: its pods coming down on their thrusters; the hull falling on three flames over its own shadow; the hull down, a last pod falling beside it | original-rich-trailer t19 `t19.zip` (`/lp land grubstake 654`), `m-landing.lua`, stills `land-00310`, `land-00430`, `land-00610` | Arrivals, landings | (new; pairs with the landing still below) |
| `strips/burster-1-windup.jpg`, `-2-swell.jpg`, `-3-blast.jpg` | A burster stopped at a wall: its ring closing, its glow swelling, its blast opening the wall | herd megaburst fork (`scripts/film_fork.sh herd 12345 7 megaburst`), `m-burst.lua`, stills `burst-006`, `burst-027`, `burst-039` (after its wind-up starts) | Synthexis, the burster (and its unit card's chapter mention) | `clips/synthexis-breach.jpg` (p. 126 of the qmd: its caption is about a burster in the gap) |

## Chapter stills: `stills/*.jpg` (11)

Close, by day, one subject each.

| File | Shows | Source | Goes | Replaces |
|---|---|---|---|---|
| `stills/landing.jpg` (1500 x 1000) | A Grubstake lander just down, before its pad, its first pylons and guns going up | `m-landing.lua`, `land-00790` | Arrivals | `clips/landing.jpg` (p. 8) |
| `stills/drop-siege.jpg` (1400 x 790) | Kessler-Hayashi's guns coming down in pods ("Deploying") beside its escort in ranks | trailer fork, `m-trailer.lua`, `drop-045100` | Kessler-Hayashi, sieges | `clips/drop-siege.jpg` (p. 15) |
| `stills/kh-assault.jpg` (1700 x 950) | Kessler-Hayashi's tanks and troopers at a Grubstake camp, lasers crossing, the lander at left | trailer fork, `m-trailer.lua`, `assault-049390` | Rivals | `clips/kh-assault.jpg` |
| `stills/grubstake-column.jpg` (1600 x 900) | A Grubstake siege column of buggies leaving its camp along its road | fortress grubstake fork (`scripts/film_fork.sh fortress 12345 20 grubstake`), `m-grubstake.lua`, `march-1320` | Grubstake, sieges | `clips/grubstake-raid.jpg` (p. 31) |
| `stills/synthexis-culture.jpg` (1750 x 986) | Incubators on the creep with the bred biters among them, biochambers on their pads | `m-culture.lua`, `culture-z12` | Synthexis (if the plan is not used there; the two show the same culture) | `clips/synthexis-creep.jpg` |
| `stills/synthexis-clinic.jpg` (1400 x 900) | The clinic on its pad beside the heating tower | `m-culture.lua`, `clinic-z15` | Synthexis, the clinic | `vistas/synthexis-clinic.jpg` (p. 42) |
| `stills/synthexis-breach.jpg` (1750 x 984) | The herd breaking in at the user's wall under flame, a moment after the hero | `m-nwwall.lua`, `breach-z10-0600` | Synthexis, waves, only if the burster strip is not used there (it is close to the hero) | `clips/synthexis-breach.jpg` |
| `stills/orbital-strike.jpg` (1600 x 900) | The lances falling on the bastion, two beams still coming down | `m-khwall.lua`, `fall-170` | Kessler-Hayashi, only if the strike strip is not used | `clips/orbital-strike.jpg` |
| `stills/orbital-cannons.jpg` (1600 x 900) | A battery on a platform over Nauvis: the targeting array and a row of orbital cannons (0.2.276's models) | `docs/release/gallery/09-orbital-cannon-battery.jpg` (the cannon's first film, `docs/trailer/scene-cannon.lua`), cropped 140,150 to 1740,1050 | Your army, orbital cannons | (new, 2026-11-10) |
| `stills/orbital-cannon-strike.jpg` (1400 x 788) | The cannons' lances falling on a spawner field | `docs/release/gallery/10-orbital-cannon-strike.jpg`, cropped 380,0 to 1780,788 | Your army, orbital cannons | (new, 2026-11-10) |
| `stills/dozer-charge.jpg` (1600 x 900) | A dozer through the wall after its charge, a second coming up, buggies behind (0.2.270's charge) | `docs/release/gallery/08-killdozer-charge.jpg`, cropped 250,180 to 1850,1080 | Grubstake, dozers | (new, 2026-11-10) |

## What should no longer repeat

- The faction vistas: once each on the front cover strip, nowhere else (the openers take the heroes; the back cover
  drops its strip or takes four portraits).
- `vistas/serenity-close.jpg`: replaced by the camp plan, so the Kessler-Hayashi chapter no longer shows one camp twice.
- Each picture above is meant for one place only. The heroes, plans, strips and stills are cut from different moments
  (the strike strip's frames and the strike hero are seconds apart on the same bastion; the culture plan and the
  culture still are the same culture: use one in the chapter).
- `media/clips/*` and `media/units/*` are all replaced and can go once the chapters point here.

## Where they went (wired 2026-11-05)

- **Portraits**: every unit card and tree node (lp-data's `portraits` is `media/portraits`); the back cover sets four
  side by side (`lp-trooper`, `lp-shotgun-hand`, `lp-infantry`, `lp-bred-big-biter`), one per faction.
- **Heroes**: the four openers (lp-data's `hero`); in HTML, under each faction chapter's title.
- **Vistas**: the front cover's three strips only (`serenity-wide`, `grubstake-wide`, `synthexis-night`); the other five
  are gone.
- **Plans** (the `.callouts` component: markers drawn from the JSON, the legend under): camp in "The camp and the line",
  siege in "Sieges" (cropped to the siege, its markers moved off their subjects on leaders), claim in "Claims and the
  trade post", culture in "The culture" (cropped; callout 5, the technician, is left out of print: its point lies on a
  tumor, and no technician shows there).
- **Strips** (the `.strip` component): landing in Arrivals; burster in Synthexis, "The wind-up"; the orbital strike in
  Spoils, under the strike beacon (the Kessler-Hayashi opener's hero is the same strike, so it stays out of that chapter).
- **Stills**: `landing` in Grubstake, "The camp" (not in Arrivals beside its own strip); `grubstake-column` in Grubstake,
  the howitzer; `kh-assault` in Rivals; `synthexis-clinic` in Synthexis, "What it breeds".
- **Removed, not printed**: `stills/drop-siege.jpg` (its "Deploying" label sits between the pods, so no crop keeps the
  guns without it, and the siege plan shows the siege), `stills/orbital-strike.jpg` (the hero and the strip),
  `stills/synthexis-breach.jpg` (seconds after the hero), `stills/synthexis-culture.jpg` (the plan shows that culture);
  all of `media/clips` and `media/units`. `cut.json` cuts the stills again if wanted.
- **media/buildings**: the three labs' icons at the head of the corporations' tree columns (the generator copies them
  from docs/guide/img). The Reference's gallery of building squares is gone.
- `python3 -I docs/manual/check_images.py`, after a PDF render, fails on any picture printed twice or never.
