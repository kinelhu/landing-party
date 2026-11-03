# Landing Party: trailer storyboard (draft 1, 2026-11-03)

About 90 seconds, for the mod portal page. No narration: Factorio's own sound, captions as title cards, in the game's
register (short, no slogans). Every shot is filmed in game with `game.take_screenshot` from a scripted camera, 30 fps,
1920x1080, interface hidden; `ffmpeg` assembles the cut.

Status: **ready** (the mechanic exists and can be filmed now), **planned** (queued work), **open** (needs a decision).

## Structure

| # | Beat | Shot | Length | Source | Status |
|---|---|---|---|---|---|
| 1 | Cold open | A late-game factory at work: belts, lasers, roboports, artillery. A slow aerial drift over it. Quiet. | 6 s | Artillery reference base | ready |
| 2 | Arrival | A cargo pod streaks down at the edge of the map; a lander unfolds. Title: **Landing Party** | 6 s | Any landing (faction.lua pods) | ready |
| 3 | Not alone | Card: "Three corporations land on your planet." | 2 s | Title card | ready |
| 4 | Grubstake | Its camp: buggies, a strip drill chewing a patch, a truck hauling out. Card: **Grubstake** | 6 s | Tour save (Grubstake camp) | ready |
| 5 | Grubstake raids | Buggies lob smoke canisters onto a laser line; the turrets go blind; the raid crosses the wall. | 8 s | A Grubstake raid scenario | planned (buggy smoke) |
| 6 | Synthexis | Its farm: pens, creep spreading, a herd gathering. Card: **Synthexis** | 6 s | Synthexis siege save (scripts/siege-save.sh) | ready |
| 7 | Synthexis breaks in | The wave reaches the wall; a burster goes off; a spore cloud eats into the wall as robots try to mend it. | 8 s | Same save | planned (spore cloud) |
| 8 | Kessler-Hayashi | Its fortress under its dome, timelapse of it growing. Card: **Kessler-Hayashi** | 6 s | nw or artillery visit, frames every N ticks | ready |
| 9 | The siege marches | Its escort crosses open ground in order toward the base. | 6 s | Artillery base, minute 52 save | ready (formations planned) |
| 10 | Drop from orbit | Cargo pods land on the siege site; mortars and the howitzer unfold. | 6 s | Same | ready |
| 11 | The strike | A platform's shadow passes over the wall; the spotter's beam goes up; lances fall along the lane; the laser line goes dark. | 10 s | Same | planned (orbital visuals) |
| 12 | Answer | The player's artillery fires back; the siege dome catches its shells. | 5 s | Same, or orbital standing scenario | ready |
| 13 | Escalation | Quick cuts: a walker striding, a railgunner clearing a nest, a convoy, a dome flickering under fire. | 6 s | Several scenarios | open (walker art) |
| 14 | End card | **Landing Party**. "Factorio 2.1 + Space Age." Mod portal link. | 5 s | Title card | ready |

About 86 s with cards. Cut to 60 s for a short version by dropping 3, 8 and 13.

## Shots needing work before filming

- **Orbital strike visuals** (11): lances from the sky, the platform's shadow, the uplink beam, impact flashes, scorch
  marks. Next in the queue.
- **Formations** (9): the escort marching in order reads far better than a blob. After the siege work.
- **Buggy smoke** (5) and **spore cloud** (7): the effects pass.
- **The walker** (13): its own four-legged body (the graphics pass). Without it, shot 13 drops the walker.
- **Building sprites** (4, 6, 8): barracks and labs read better once they have their own art (the graphics pass).

## Open questions

- Music: none (game sound only), the vanilla soundtrack, or a licensed track?
- Captions: English only, or none at all and let the shots speak?
- Day or night? Night shows the lances and flashes best; the factory reads best by day. Possibly dusk.
- Which factory: the artillery reference base (clean, ours), or your own nw save (real, but yours to share)?

## How it is filmed

A small helper mod (planned): loads a prepared save, moves a camera along a scripted path (position, zoom, speed per
shot), and screenshots every other tick; one shot per run. Frames to `script-output/trailer/<shot>/`, then
`ffmpeg -framerate 30 -i %05d.png -c:v libx264 -pix_fmt yuv420p <shot>.mp4`. Shots cut together in order with title
cards rendered as stills.
