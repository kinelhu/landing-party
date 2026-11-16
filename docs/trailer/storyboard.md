# Landing Party: trailer storyboard (draft 2, 2026-11-03)

About 90 seconds for the mod portal page, filmed on the user's own nw factory (the user, 2026-11-03: "my real base is a
better example (even if we need to nerf it by removing some defenses or editing its walls!)"). Music in the spirit of
FTL's soundtrack: bright, wacky, synth-driven sci-fi (the user). No narration and no captions: music only (the user,
2026-11-04); the footage carries it. The title over shot 2 and the end card stay (the mod's name and link, not captions).

Status of each shot: **ready** (filmable now), **planned** (queued work), **scout** (framing to fix on a scouting
pass), **open** (a decision for the user).

## 1. Capture

Every frame is `game.take_screenshot`, called by a small film helper mod (`tests/lp-film`; since 2026-11-05 the toolkit at `~/Dev/factorio-film` with Landing Party's plugin `tests/lp-film-hooks`) in a game window
(rendering needs one; a headless run cannot). One shot per run, from a prepared save.

| Setting | Value | Why |
|---|---|---|
| Resolution | 1920x1080 | Mod portal and YouTube standard |
| `anti_alias` | true | Renders 3840x2160 and scales down: clean edges on belts and wires |
| Frame rate | 30 fps: a screenshot every 2 ticks | The game runs at 60 ticks/s; 30 fps is smooth for a pixel-art game and halves the frames |
| `force_render` | true | No dropped frames when the game slows under the screenshot load: playback stays smooth |
| `show_gui`, `show_entity_info` | false | No interface, no alt-mode icons |
| `hide_health_bars` | true | Health bars clutter every combat shot |
| `hide_clouds` | false by day, true at night | Cloud shadows give life to wide day shots; at night they only muddy the light |
| `hide_fog` | true | (Space Age fog and dust are for other planets) |
| `daytime` | per shot, see section 3 | The lighting follows the cut, not the game clock |
| Format | `.png` | Lossless; converted shot by shot and deleted |
| Handles | 1 s before and after each shot | Room to cut on the beat |

Frames: `script-output/trailer/<shot>/%05d.png`. Each shot: `ffmpeg -framerate 30 -i %05d.png -c:v libx264 -crf 14
-pix_fmt yuv420p <shot>.mp4`. Disk: a 1080p PNG is about 3 MB, 30 frames a second: about 90 MB a second of footage,
under 10 GB for everything with handles, kept only until its clip is encoded.

The game speed stays 1 while filming: units, pods and shells move at their real pace, and the screenshot cadence (every
2 ticks) gives real-time 30 fps footage. A slow-motion beat (shot 11's impact) films every tick and plays at 30 fps:
half speed, no blur.

## 2. Camera

The camera is the screenshot's `position` and `zoom`, set every frame by the helper from a path:

- **Zoom scale.** At zoom 1 a tile is 32 pixels: 60 tiles across 1080p. Wide: 0.25 (240 tiles). Medium: 0.5 (120
  tiles). Close: 1.0. Detail: 1.5 (40 tiles). Below 0.25 the sprites fall to the game's map-view look: not used.
- **Moves.** Each shot is one of: *lock-off* (still), *drift* (a slow pan), *push-in* (zoom rising), *pull-out*, *track*
  (the camera follows an entity: a pod, the lead guard), or a *push-in with drift* together.
- **Easing.** Every move eases in and out (smoothstep, 3t² - 2t³): no move starts or stops at full speed. Tracks are
  damped (the camera closes a tenth of the gap each frame) so a unit's jitter does not shake the frame.
- **Speed.** At most a third of a screen width a second in a pan; a push-in at most doubling the zoom over a shot. Faster
  reads as a jolt at 30 fps.
- **Cuts.** Hard cuts on the beat. One whip pan (a fast smeared move in the last 6 frames of shot 8 and first 6 of 9) to
  carry from the fortress to the march.

## 3. Light: day to night to dawn

The trailer runs one day's arc. Factorio's day: 0 noon; dusk from 0.25; night (darkest) 0.45 to 0.55; morning 0.55; dawn
0.75. Fixed per frame with the screenshot's `daytime`, eased across a shot where it changes.

| Act | Shots | `daytime` | Look |
|---|---|---|---|
| The factory at work | 1-2 | 0.05 to 0.15 | Full day, cloud shadows drifting over the base |
| Grubstake | 4-5 | 0.2 | Late afternoon: long, warm light; the smoke reads grey against it |
| Synthexis | 6-7 | 0.3 to 0.38 | Dusk: the creep's glow and the spore cloud start to show |
| Kessler-Hayashi | 8-12 | 0.47 to 0.5 | Night: lamps, laser beams, muzzle flashes, the lances and impact flashes at their best |
| Escalation | 13 | 0.5 to 0.7 | Night into early morning across the quick cuts |
| End card | 14 | 0.78 | Dawn, the factory standing (or not) |

At night the surface's `min_brightness` goes from 0.15 to 0.3 while filming (`game.surfaces.nauvis.min_brightness`,
restored after): the base must still read under the effects, not be a black field with lights.
(Filmed 2026-11-04: it does not. A screenshot taken with its own `daytime` ignores the surface's `min_brightness`, 0.3
or 0.5 alike, and shots 9 to 11 at 0.47 to 0.5 came out a black field away from the lights. Kessler-Hayashi is filmed
at late dusk, 0.37 to 0.42, which keeps the beams and flashes and lets the ground read; night proper is left to shots
lit by the base's own lamps.)

## 4. Music and timing

A track in FTL's spirit, with rights to use it: royalty-free or Creative Commons (with credit), commissioned, or the
user's own (open). FTL's own score is copyrighted and not usable.

Cut to the bar. At 120 BPM a bar of 4/4 is 2 s; the shot lengths below are in seconds at 120 BPM and retime once the
track is chosen (lengths in bars stay). Big beats: the title (2) on the first downbeat after the intro; the strike's
first lance (11) on the track's drop; the end card on its last chord.

## 5. Shot list

Places on nw are from the 0.2.165 visits (`docs/sim/visit-nw-rich-l165-seed*`); exact framings are fixed on the scouting
pass (section 6). The factory centre is 0,0; 95% of it within 674 tiles.

| # | Beat | Bars | What we see | Camera | Light | Source and trigger | Status |
|---|---|---|---|---|---|---|---|
| 1 | Cold open | 3 (6 s) | The factory at work: belts, smelter rows, a train passing, robots crossing | Drift over the busiest block, zoom 0.5, west to east, 18 tiles a second | 0.05 | nw at its start (no corporation yet) | scout |
| 2 | Arrival | 3 (6 s) | A cargo pod streaks down beyond the south wall and lands; the lander unfolds; title **Landing Party** over the last bar | Lock-off at zoom 0.4 on the landing spot (KH's lander at -99,566), the factory edge in frame | 0.15 | Visit start: KH's landing (seed giving the -99,566 spot) | ready |
| 3 | ~~Not alone~~ | — | Dropped (no captions, 2026-11-04): its bar goes to shot 2 | — | — | — | cut |
| 4 | Grubstake | 3 (6 s) | Its camp: buggies parked, a strip drill chewing a patch, a truck hauling out | Push-in, zoom 0.4 to 0.6, on its camp (lander about 3,-654) | 0.2 | Visit, minute 20 or later | scout |
| 5 | Grubstake raids | 4 (8 s) | Buggies lob smoke on a laser line; the lasers fall silent; the raid crosses | Track the lead buggy, zoom 0.7, then lock-off on the wall | 0.2 | A forced raid (`/lp raid`) at a chosen wall | planned (buggy smoke) |
| 6 | Synthexis | 3 (6 s) | Its farm: pens, creep spreading, a herd gathering | Drift across the creep's edge, zoom 0.5 | 0.32 | nw: its farm (first at about 700,-280) | scout |
| 7 | Synthexis breaks in | 4 (8 s) | The wave hits the wall; a burster goes off; a spore cloud eats into the wall as robots try to mend it | Lock-off on the breach, zoom 0.8; the burst on a downbeat | 0.37 | Synthexis siege save (`scripts/siege-save.sh`) on nw | planned (spore cloud) |
| 8 | Kessler-Hayashi | 3 (6 s) | Its fortress, domed, growing (timelapse: a frame every 120 ticks over 15 minutes) | Lock-off, zoom 0.35, on the fortress; whip pan out in the last 6 frames | 0.47 | nw visit from the landing | ready |
| 9 | The siege marches | 3 (6 s) | Its escort crossing open ground toward the base, in order | Track the lead guard, zoom 0.6, the base ahead in frame | 0.48 | nw minute-N save before a siege (site -137,374, target the substation at -144,339) | ready (formations planned) |
| 10 | Drop from orbit | 3 (6 s) | Four pods streak down on the siege site; mortars and the howitzer unfold; the dome goes up | Lock-off, zoom 0.7, the site and the wall both in frame | 0.49 | Same | ready |
| 11 | The strike | 5 (10 s) | A platform's shadow slides over the wall; the spotter's beam goes up; lances fall along the lane, the first on the drop; the laser line goes dark. Two bars of it at half speed | Push-in from zoom 0.5 to 0.9 on the lane during the paint; lock-off for the lances | 0.5 | Same | planned (orbital visuals) |
| 12 | Answer | 2 (4 s) | The base's artillery fires back; the siege dome catches its shells | Lock-off on the dome, zoom 0.8 | 0.5 | Same (nw has artillery? scout) or `orbital standing` scenario | scout |
| 13 | Escalation | 3 (6 s) | Quick cuts, a bar each: a walker striding; a convoy of pods; a fortress dome flickering under fire | Each a lock-off or short track | 0.5 to 0.7 | Several | open (walker art) |
| 14 | End card | 3 (6 s) | **Landing Party**. "Factorio 2.1 + Space Age." Mod portal link. Behind it, the base at dawn | Slow pull-out, zoom 0.5 to 0.3 | 0.78 | nw, after the siege | ready |

42 bars, about 84 s at 120 BPM (shot 3 cut). The 60 s cut drops 3, 8 and 13.

### New scenes and the re-shoot (2026-11-08)

Every unit the trailer shows was redrawn in the unit pass (0.2.225 to 0.2.236: Grubstake's buggies, crawlers, hauler,
howitzer truck, harrier, bomb drone; Kessler-Hayashi's tanks, Prism, Tesla, Aegis, drones; cyan lasers), so **every
shot with units is re-filmed**: 4, 5, 7 (its wall), 9, 10, 11, 12, 13. Shots 1, 2, 6, 8 and 14 show buildings and the
base and stand as they are, unless the cut wants them fresher.

New scenes (the user: "a dozer siege and bomber drones diving on a mass of troopers"; and the Prism and Tesla in action,
flak buggies on fliers), each staged by a `/lp` tool on its own stage (`LP_MIX=scenes scripts/showcase.sh 12345 3`; the
film params `docs/trailer/reel-scenes.lua`; each tool checked in scenario `dev`):

| # | Beat | What we see | Tool | Where it could go |
|---|---|---|---|---|
| S1 | The dozers | Two dozers ram the outpost's wall, the buggies hold, then pour through the breach | `/lp dozers 2` | after 5 (Grubstake raids), or in its place |
| S2 | From the sky | A flight of bomb drones dives into a block of troopers | `/lp bombers 6` | Grubstake's beat, after S1 |
| S3 | The Prism | Its beam splits through a squad | `/lp prism 1` | Kessler-Hayashi's beat, beside 11 |
| S4 | Flak | Kessler-Hayashi's scout drones come in over flak buggies and fall | `/lp flak 2` | 13 (escalation), a bar |
| S5 | The Tesla | Its arcs drain a laser line | `/lp tesla 4` (reel-tesla.lua) | 13, a bar |


## 6. Before filming

**The base (nw).** Prepared by script from a copy (never the user's file), so it can be redone:
- The siege lane (the south face toward KH, round -144,339): its lasers thinned so the siege breaks through on camera,
  by script (the user, 2026-11-03): a box and kinds, applied by the film helper on load, so every take starts from the
  same thinned lane.
- Characters out of every frame (moved away or made invisible by the helper).
- Ghosts and deconstruction marks cleared at load: they show as overlays.

**Scouting pass.** A game window, the helper taking one still per candidate framing (position, zoom, daytime), 20 to 40
stills on a contact sheet. We pick from those, then film. Cheap: a few minutes, no footage.

**Features first.** Orbital visuals (11, next), formations (9), buggy smoke (5), spore cloud (7), walker art (13),
building sprites (4, 6, 8; barracks and labs first).

**Deterministic takes.** Each shot starts from its own save, so a retake replays the same events: the same seed and code
give the same siege. A code change between takes means a fresh save.

## 7. Open

- The track (and so the tempo): the user picks it.
- Captions: none, music only (the user, 2026-11-04).
