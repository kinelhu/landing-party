# Landing Party: mod portal page (draft)

Drafted 2026-11-10 for the user to edit, brought up to 0.2.339 on 2026-11-12 and to 0.2.433 (released as 0.3.0) on
2026-11-16; the manual's link works once the v0.3.0 GitHub release carries the PDF; nothing here is published. Paste the part below the line into the portal's
"Information" field. Placeholders in [square brackets].

Portal fields:
- **Title:** Landing Party
- **Summary (one line):** Three rival factions land on Nauvis and build settlements, armies and biter farms of their own.
- **Category:** Enemies
- **Tags:** Combat, Enemies, Planets (if offered), Big mod
- **License:** MIT
- **Source:** https://github.com/kinelhu/landing-party
- **Version:** 0.3.0, a public beta
- **Gallery:** docs/release/gallery/*.jpg, in order (captions below, under "Gallery captions")
- **Loops in the text:** media/release/gifs/, each an MP4 (a few hundred kB; the portal plays mp4 and webm inline with
  the image syntax) and a GIF fallback (3 to 8 MB). Placeholders [gif: name] mark where each goes, once hosted.
- **Thumbnail:** landing-party/thumbnail.png (in the mod; 144 by 144)

---

**Factorio, but you are not alone anymore.** Three rival factions come to Nauvis, each with its own reasons. They land,
mine real ore, build walled settlements with power, roads and defences, and field armies that are the output of their
own economies. They fight you, each other and the biters.

[Trailer: link]

## The factions

**Grubstake** arrives once you make chemical science. A prospecting outfit that follows every rush in the system, it
raids what you leave unguarded, skims your belts, strips your ore and drives Killdozers through your walls. It steals
more than it destroys, and what it takes sits in its yard until you come for it.

[gif: flak]

**Kessler-Hayashi** arrives after your first rocket. An armed contractor that lives in orbit, it pushes a line of posts
toward you, cuts your outposts off, besieges your walls with mortars dropped from orbit and calls orbital strikes on
them. Its laser lines, shield domes, lightning tanks and blue arc flamers are the hardest defences on the planet, and
it clears the biter nests round its camps with railgunners, more of them as the biters evolve.

[gif: arcflamer] [gif: tesla]

**Synthexis** takes over the biter nests. It breeds its own strains in farms of captured spawners and sends waves with
intent: it scouts your walls, finds the weak face, and learns from what kills its waves.

Each faction researches, fields its own units with their own look and sound, and answers what you do to it. They choose
between raids, sieges, thefts and air strikes by what your defences can and cannot stop.

[gif: prism] [gif: bombers]

## Headquarters

Above the camps, Grubstake's and Kessler-Hayashi's headquarters run the war. They announce nothing: their attacks come
in waves with lulls between them, and you feel the pace rather than read it.

- **Strike forces:** headquarters drops a force by pod beside something it wants, at the point your turrets reach
  least. Grubstake goes for your power and the pumps that feed your boilers; Kessler-Hayashi for your rocket silos,
  landing pads and labs; anyone for a train station, your roboports or your oil. A gun that keeps killing their units
  becomes a target itself, and so do your army's barracks. The force fights until it has lost too many, then walks home
  to its camp, round your turrets where it can and firing back at what shoots it, and its survivors join the garrison or
  leave on the camp's rocket. Those you catch on the way never reach it.
- **Warning:** a strike force is told when it lands. Your radar sees its pods coming before that, where it covers the
  ground they come down on. A strike at your power is always told ahead, its target marked on the map, and the
  corporations hold their other attacks on you while it is out.
- **Units chosen for the target:** a strike force brings what counters the guns and troops guarding what it came for.
  Your army, waiting where its pods come down, is the answer to it.
- **And more:** a launch jammer mast that keeps pausing your rocket silo; a blackout mast that shuts down your radars; a
  bounty on one of your buildings, every camp's first target for a while; a crashed shuttle with salvage and a piece of
  gear inside, guarded by its crew, claimed by its corporation if you leave it; export contracts, garrison rotations,
  joint strikes by two corporations, and research jumps that bring new units to the field.

[gif: pods] [gif: strike-fight] [gif: walk-home]

The Director setting picks its temper: Steady, Gentle, Chaotic, or Off for the factions acting alone.

## Your side

- **An army of your own:** barracks train troopers, breachers, rocket troopers, flamethrower troopers and battle tanks.
  Command them with a selection tool (ALT + C) or with rally beacons driven by the circuit network. A panel at the top of
  the screen shows your units against your command cap; retire units you no longer need (ALT + R).
- **Selection cards and control groups:** the units you select wear health bars, and a panel above the quickbar shows a
  card for each, with its health and rank. Click a card to narrow the selection, SHIFT + click to drop it, right-click
  to follow it. CONTROL + 1 to 9 keeps a selection as a group, ALT + 1 to 9 calls it back.
- **Veterancy:** units that kill earn ranks (Veteran, Elite, Heroic), promoted on the spot in the middle of a fight,
  with more health and harder hits and gold chevrons to show for it. The rivals' units rank too, and a raid pulls back
  sooner to save its elites. Synthexis never ranks: the hive learns as a whole.
- **Eyes and roads:** a threat scanner reports enemy units by type to the circuit network; concrete roads speed your
  army; a muster point deploys troops carried by train.
- **Orbital cannons:** after artillery, space platforms, the foundry and the electromagnetic plant, build cannons on a
  platform over Nauvis. Ship them shells cast on the ground, feed them thruster fuel and oxidizer made from asteroids,
  and call strikes with a remote (ALT + O). Each strike fires one platform: the more cannons on it, the wider and denser
  it falls; the more platforms, the more strikes in a row. Their targeting array is built round a beacon salvaged from
  Kessler-Hayashi.
- **Spoils:** each faction's technology can be taken from its wreckage: cluster shells, rail rifles, pheromone bait and
  more.

[gif: cannon-strike]

## Sound

The corporations' units have their own weapons, engines, footsteps and deaths: Grubstake heavy and rough,
Kessler-Hayashi tight and electric. Their events are heard too: a klaxon as a strike force's pods come down, the roar
of a camp landing, a siege horn, a mast's clamps locking, a shield dome catching a shell, the rising charge of an
orbital strike into its first impact.

## Settings

The Director (above), a difficulty preset, and under it each faction on or off, when it arrives, its most bases,
strength, aggression and income; the time between landings; revenge landings; Kessler-Hayashi's orbital strikes;
Grubstake's theft; Synthexis's most cultures, largest attack and learning.

## Requirements and notes

- Factorio 2.1 with Space Age.
- Works on a new game or an existing one: the factions arrive by their own triggers (chemical science, the first rocket,
  the biters).
- Multiplayer: tested headless and with a client, the factions and headquarters in play (sieges, strikes, a joint
  strike of both corporations), without a desync; two clients using the army and the faction panels together are not
  yet covered.
- No known incompatible mods. Report clashes on the discussion page.
- A player manual (PDF): [the manual](https://github.com/kinelhu/landing-party/releases/download/v0.3.0/Landing-Party-manual.pdf).
- Source and issues: [github.com/kinelhu/landing-party](https://github.com/kinelhu/landing-party).

## Gallery captions

1. An armed Kessler-Hayashi fortress inside its rings of wall, its lander at the centre and its mine beside it.
2. Your army attacking a Grubstake camp.
3. A Synthexis swarm against a flamethrower wall.
4. A Kessler-Hayashi orbital strike opening a wall.
5. A Kessler-Hayashi shield dome over its siege.
6. A Synthexis culture: captured nests bred for war.
7. Grubstake bomb drones diving on a squad of troopers.
8. A Grubstake Killdozer charging through a wall.
9. Your orbital cannons on a platform over Nauvis.
10. An orbital strike from your cannons on a Synthexis culture.
11. A Kessler-Hayashi strike force's pods coming down beside a factory's labs.

Loops (media/release/gifs, docs/release/gifs.sh; manifest.json has each one's caption, length and sizes): pods,
strike-fight and walk-home (the director's film set, docs/release/strike-film.lua, 2026-11-16); tesla, bombers, prism,
flak (the showcase film, 2026-11-12); arcflamer (0.2.350); cannon-strike (the trailer's culture reel, 2026-11-12).
The 2026-11-12 sources stay in media/release/loops.
