# Landing Party: mod portal page (draft)

Drafted 2026-11-10 for the user to edit, brought up to 0.2.339 on 2026-11-12, to 0.2.433 and to 0.2.438 on 2026-11-16,
and to 0.2.464 (released as 0.3.0, a public beta) on 2026-11-19; the manual's link works once the v0.3.0 GitHub release carries the PDF; nothing here is published. Paste the part below the line into the portal's
"Information" field. Placeholders in [square brackets].

Portal fields:
- **Title:** Landing Party
- **Summary (one line):** Three rival factions land on Nauvis and build settlements, armies and biter farms of their own.
- **Category:** Content (the portal's categories: content, overhaul, tweaks, utilities...; scripts/portal.py sets it)
- **Tags:** Combat, Enemies (the portal's own tag list has no planets or size tags)
- **License:** MIT
- **Source:** https://github.com/kinelhu/landing-party
- **Version:** 0.3.0, a public beta
- **Gallery:** docs/release/gallery/*.jpg, in order (captions below, under "Gallery captions")
- **Loops in the text:** media/release/gifs/, each an MP4 (a few hundred kB; the portal plays mp4 and webm inline with
  the image syntax) and a GIF fallback (3 to 8 MB). Placeholders [gif: name] mark where each goes, once hosted.
- **Thumbnail:** landing-party/thumbnail.png (in the mod; 144 by 144)

---

Three rival factions come to Nauvis. They land, mine real ore, and build walled settlements with their own power, roads
and defences. Their armies are made in their own factories. They fight you, each other and the biters.

[Trailer: link]

**Public beta.** The mechanics are tested by scripted runs and a few played sessions; the difficulty is not tuned yet.
Tell us on the discussion page or in a GitHub issue what felt unfair, dull or broken, which version, and if you can, a
save.

## The factions

**Grubstake** arrives once you make chemical science. A prospecting outfit, it raids what you leave unguarded, skims
your belts, strips your ore and drives Dozers through your walls. It would rather steal than destroy, and it keeps what
it takes in its scrapyard until you destroy the yard.

[gif: flak]

**Kessler-Hayashi** arrives after your first rocket. An armed contractor run from orbit, it pushes a line of posts
toward you, cuts off your outposts, besieges your walls with mortars and calls down orbital strikes. Its camps are the
best defended, with laser turret lines, shield domes and arc flamers. Its railgunners clear the biter nests around its
camps, and it sends more of them as the biters evolve.

[gif: arcflamer] [gif: tesla]

**Synthexis** takes over the biter nests and breeds its own strains in them. Its scouts circle your walls before an
attack, and it remembers where an attack failed and tries something else there next time.

Each faction researches its own units, with their own models and sounds, and picks raids, sieges, thefts or air strikes
by what your defences are weakest against.

[gif: prism] [gif: bombers]

## Headquarters

Grubstake and Kessler-Hayashi each have a headquarters that paces their attacks: busy spells, then quiet ones, with
no warning of either.

- **Strike forces:** a headquarters drops a force by pod next to something it wants, where your turrets reach least.
  Grubstake goes for your power and the pumps feeding your boilers; Kessler-Hayashi for your rocket silos, landing pads
  and labs; either for your train stations, roboports or oil. A turret that keeps killing their units becomes a target,
  and so do your barracks. Once it has lost too many, the force walks back to its camp, around your turrets where it
  can.
- **Warning:** you are told when a strike force lands. If your radar covers the landing spot, you see the pods coming
  first: up to two minutes ahead with a radar right over the spot, less from further away. A strike on your power is
  always told in advance, with its target marked, and no other attack starts while it is out.
- **Units chosen for the job:** a strike force brings what beats the guns and troops guarding its target. Your army can
  meet it where the pods land, and goes on its own if you set it to defend.
- **Other events:** a jammer mast that keeps pausing your rocket silo; a blackout mast that switches off your radars; a
  bounty on one of your buildings; a crashed shuttle with salvage inside, guarded by its crew; export contracts,
  garrison rotations, joint strikes by both corporations, and research jumps that bring new units.

[gif: pods] [gif: strike-fight] [gif: walk-home]

The Director setting sets the pace: Steady, Gentle or Chaotic, or Off, which leaves each faction to act alone.

## Your side

- **An army of your own:** barracks train troopers, breachers, rocket troopers, gun buggies, flamethrower troopers and
  battle tanks from your own equipment: heavy armor and guns, a car, a tank with an exoskeleton. Order them with the
  command tool (ALT + C) or with rally beacons on the circuit network. A panel at the top of the screen shows your units
  against your cap; retire the ones you no longer need (ALT + R).
- **Rally beacons:** signals on a beacon set its squad's stance: hold, advance, retreat or defend. A defending squad goes
  out to a strike force your radar sees coming, to enemies at your buildings or to a gun shelling your walls, and comes
  back when it is over. A holding squad clears the biter nests near it. A panel beside the beacon shows its squad and
  sets how many of each unit it keeps; lower one beacon's number and raise another's, and the units move over.
  Right-click a beacon with units selected and they join its squad. Hover over a beacon to see its squad.
- **Circuit control:** a beacon reads its stance, its rally point and its reach from signals, and reports its squad,
  how many have arrived, the enemies, turrets and spawners within reach, an alarm and its ammunition. Patrols, outposts
  that call for help and squads on a clock are built from combinators.
- **Ammunition:** units carry the rounds their order was made with and spend them as they fire. A unit that runs dry
  walks to the nearest powered barracks holding its ammunition and rearms there. With the logistic system, supply depots
  your robots fill rearm the squads at the front. A startup setting turns it off.
- **Repair:** units heal near a powered barracks, and construction robots repair them with repair packs, as they do
  your turrets.
- **Selection cards and control groups:** selected units show health bars, and a panel above the quickbar shows a card
  for each with its health and rank. Click a card to narrow the selection, SHIFT + click to drop it, right-click to
  follow it. CONTROL + 1 to 9 saves a group, ALT + 1 to 9 recalls it.
- **Veterancy:** units that kill earn ranks (Veteran, Elite, Heroic), each adding health and damage, shown as gold
  chevrons. The corporations' units rank too, and a raid retreats sooner to save its elites.
- **Scanners, roads and outposts:** a threat scanner reports enemy units by type to the circuit network; concrete roads
  speed up your army, and squads take them; a far outpost's barracks, fed by train, is its reserve.
- **Orbital cannons:** later in the game, build cannons on a space platform over Nauvis, keep them supplied with shells
  made on the ground and fuel made from asteroids, and call strikes with a remote (ALT + O). More cannons on a platform
  make a wider, denser strike; more platforms let you strike again sooner.
- **Spoils:** each faction's technology can be recovered from its wreckage: cluster shells, rail rifles, pheromone bait
  and more.

[gif: cannon-strike]

## Sound

The corporations' units have their own weapons, engines, footsteps and deaths: Grubstake's heavy and rough,
Kessler-Hayashi's tight and electric. Their events have sounds too: a klaxon as a strike force's pods come down, the
roar of a camp landing, a siege horn, a shield dome stopping a shell, the build-up of an orbital strike.

## Settings

The Director, a difficulty preset, and for each faction: on or off, when it arrives, how many bases it can have, its
strength, aggression and income. Also the time between landings, revenge landings, Kessler-Hayashi's orbital strikes,
Grubstake's theft, Synthexis's number of cultures, largest attack and learning, and your army's ammunition.

## Requirements and notes

- Factorio 2.1 with Space Age.
- Works on a new game or an existing one: each faction arrives on its own trigger (chemical science, the first rocket,
  the biters). Saves made on an earlier version load on a later one.
- Multiplayer: tested with a second player joining, through sieges and strike forces, without desyncs. Two players
  using the army and the faction panels at the same time has not been tested yet.
- No known incompatible mods. Please report clashes on the discussion page.
- Player manual (PDF): [the manual](https://github.com/kinelhu/landing-party/releases/download/v0.3.0/Landing-Party-manual.pdf).
- Source and issues: [github.com/kinelhu/landing-party](https://github.com/kinelhu/landing-party).

## Gallery captions

1. A Kessler-Hayashi fortress inside its rings of wall, its lander at the centre and its mine beside it.
2. Your army attacking a Grubstake camp.
3. A Synthexis swarm against a flamethrower wall.
4. A Kessler-Hayashi orbital strike opening a wall.
5. A Kessler-Hayashi shield dome over its camp, catching your artillery's shells.
6. A Synthexis culture: captured spawners breeding its biters.
7. Grubstake bomb drones diving on a squad of troopers.
8. A Grubstake Dozer charging through a wall.
9. Two of your orbital cannons on a space platform, firing down on Nauvis.
10. An orbital strike from your cannons on a Synthexis culture.
11. A Kessler-Hayashi strike force's pods coming down beside your furnaces.

Loops (media/release/gifs, docs/release/gifs.sh; manifest.json has each one's caption, length and sizes): pods,
strike-fight and walk-home (the director's film set, docs/release/strike-film.lua, 2026-11-16); tesla, bombers, prism,
flak (the showcase film, 2026-11-12); arcflamer (0.2.350); cannon-strike (the trailer's culture reel, 2026-11-12).
The 2026-11-12 sources stay in media/release/loops.
