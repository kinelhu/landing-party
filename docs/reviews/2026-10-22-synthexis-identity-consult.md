# Synthexis: identity consult (Fable, 2026-10-22)

Brief: the user named the biotech **Synthexis** and asked that it read as high-tech bioengineering, not ranchers.
The consult's text follows as returned; decisions taken from it go in `docs/biotech.md`.

Read: `docs/biotech.md` (brief, spikes, the pack, 0.1.51 to 0.1.54), `docs/third-corporation.md`, the breeds consult, `docs/corporations.md`, DESIGN.md (status, corporations, the biotech section). Name given: **Synthexis**. The sketch (a Gleba outpost on Nauvis, feed as weak point, spoilage as clock, a few technicians) is right in substance; I change its shape in three places (section 2) and keep the user's "high tech" line as the test for every piece: if it would look at home on Gleba's lab platform, it is Synthexis; if it would look at home on a ranch, it is not.

## 1. Identity

Synthexis is a bioengineering firm that treats Nauvis as a test range and the player's factory as the control group. Its temper is clinical and patient: it never retaliates in anger, it samples (the tracker), records (the widening loop, the trail), adjusts the breed and sends the next batch. Its pitch to the world is that life is a better material than steel, and it proves it on the player's wall. At a glance it is the corporation with **no wall, no road and no guns**: Kessler-Hayashi is grey plating in straight lines under cold white light, Grubstake is gravel sprawl under amber, Synthexis is a blot of alien ground (Gleba soil, violet-pink, with yumako trees on it) in the middle of red nest country, lit acid green at night, with mud threads leaving it toward the player. Its units are animals in green with yellow bands; its only machines are glass (biochambers, a biolab) on a small acid-green pad. On the map: green egg icons on a purple stain inside the red of nests, a dashed green trail when a batch is out. Nothing of this needs a chat line: the ground says who lives there and the trail says what they sent.

## 2. The outpost: the culture site

Built on the nest field it lands on, round the lander. One "cell" per pen; the substrate and the clinic in the middle. Costs are for Factorio's engine with the mod's existing tools (tinted copies, script-placed entities, machines run as Serenity's fabricators are).

| Piece | What it is | Reads as | Cost |
|---|---|---|---|
| **Pen** (built) | `unit-spawner` copy, captive-spawner art, its green tint | a nest in glass | done |
| **Cell pad** | 5x5 of `acid-refined-concrete` beside each pen (vanilla 2.0 colour, no new tile) | a lab floor on a mound | cheap |
| **Biochamber** | `biochamber` copy on the pad, a recipe set and run by script (as fabricators are), one `inserter` into the pen | the feed line; its animation and light are the tell that the pen is fed | cheap |
| **Lamp** | vanilla lamp, acid-green light colour, one per cell | the site at night: green dots where KH has white and Grubstake amber | cheap |
| **Worms** (built) | two bred medium worms per pen | the only thing that shoots up | done |
| **Substrate** | `artificial-yumako-soil` tiles in an irregular blot (20 tiles at landing, growing to 50), `yumako-tree` and `jellystem` placed by script; two `agricultural-tower` copies at its edge, animated | the purple stain on the map; Gleba on Nauvis | medium (tile painting is cheap; trees need replanting on a timer) |
| **Heating tower** | one `heating-tower` copy at the lander, lit, script-fuelled | the site's heat and light at night; its chimney is the silhouette from far | cheap |
| **The clinic** | a `biolab` copy, Synthexis's research building, landing at stage 2 | glass and a glow; the one building worth artillery | cheap to place, medium to wire (section 3) |
| **Trail** (built) | mud decals and the map line | the batch's memory | done |
| **Technicians** | section 4 | | medium |

What I change from the sketch. **Pens stay on the nests, not beside the greenhouses**: the biochamber goes to the pen (one per cell, inserter-fed), the fruit comes to it on foot (technicians carry; the items are script). Real belts across a 60-tile nest field would be a logistics puzzle for the engine and a ranch for the eye. **No walls, no gate, no fence, ever**: the hedge is the wild nests; a fence is the one thing that would turn a lab into a farm. **Spoilage is not a clock on the site, it is a clock in the player's chest**: the site's own clock is feed (section 3), which the player can see stop.

Growth, unhurt: stage 1 at landing (lander, four cells, 20 tiles of substrate, one tower, the heating tower); stage 2 at 30 minutes (the clinic lands by pod, the substrate reaches 50 tiles, a second tower); stage 3 at 60 (a fifth cell on the nearest wild nest of the hedge, the clinic's tiers open: spitter, big, then runt, cinder, stomper by the breeds consult's ladder); stage 4 is a second culture site on another field, never a sixth cell.

## 3. Weak points, and what the player does differently

Three, in the order a careful player finds them.

1. **The scout and the keep** (built): shoot the tracker, keep the feed under three turrets, no dry or dark face.
2. **The feed.** A biochamber killed starves its pen: the pen's cap falls from 40 to 12 within a minute (stock above it is released and walks off into the hedge as wild, on the enemy force: the player sees the batch *go feral*), waves from a starved cell cannot form (24 minimum), and a cell starved for 10 minutes reverts: the pen becomes a plain wild spawner again, red on the map. Killing the substrate (trees and towers) starves every cell at once. This is the quiet kill: **a pen hit recalls its wave; a biochamber hit does not**. The player who learns the difference raids the feed while the batch is out and the batch comes home to a dead cell.
3. **The clinic.** While it stands the force's evolution climbs and the tiers open; dead, the site breeds stock only until a replacement lands (30 minutes). Artillery's target, under the worms.

How the hunt pays: a dead cell drops bioflux, nutrients and biter eggs (Space Age's: they hatch in the player's chest after 30 minutes unless spoiled or burned, a clock the player carries home) and the pheromone gland that moves the bait research here; the clinic drops a faction component. A dead site **leaves its substrate**: 50 tiles of yumako soil on Nauvis with living trees, the one Gleba asset a player can have before Gleba. The expedition is the rail trip the breeds consult designed; nothing here changes it.

## 4. Its people

Two kinds, neither a soldier. A corporation of bioengineers that fields riflemen is Kessler-Hayashi in a coat, and the brief's unit class is "many, soft, cheap, blind to the sky": its army is its product.

- **Technicians**: the mod's crew kind in white with green trim, unarmed, two per site plus one per stage. They walk fruit from the towers to the biochambers (a life animation like patrols), replant the substrate, and build the next cell. Killing them stops the feed within 5 minutes; the lander drops two more after 10 (a reprieve, not a defence). Worth doing, cheap, and the human face the user asked for: at night, a white figure with a lamp walking between glass tanks on alien soil.
- **The tracker** (the bred strafer, per the breeds consult): its eye, chirping round the wall. Already its signature.

No vehicle. No escort. The worms and the hedge are the site's defence, and Synthexis's answer to being hit is a recalled batch, never a sortie by people.

## 5. The other two, and the wild

- **Wild biters**: peace both ways (built). Synthexis harvests the hedge one nest at a time (stage 3's fifth cell); a starved cell gives its nest back. The field's red never thins on its own.
- **Kessler-Hayashi**: war on sight, unscripted (built). Its clearances read pens as nests; the clinic and the biochambers get the `lp-biter` tag too, so a clearance column at a site is worms against a howitzer. The player can lead a column to a trail and let the exterminator do the quiet kill, and be billed for the hedge it clears.
- **Grubstake**: neutral at landing; the flares retire now. The break is one legible cause: a Grubstake skim truck parks at a cell's biochamber and fills its trunk with bioflux (its built skim, aimed at an exposed machine); the worms fire on it; from then on war, bred herds only. The player sees the truck burning on the pad before any herd turns. No other trigger needed in the first version.

## 6. The outpost's name and tagline

Building set and map tag: **"Synthexis culture"** (numbered per landing as camps are: "Synthexis culture 2"). A culture is what a lab grows in a dish and the only culture in nest country; the pens are **incubators** in the player's mouth and the tag's tooltip, the soil the **substrate**, the lab the **clinic**. Tagline, deadpan corporate: **"Engineered to adapt."** (It is literally what the widening loop does.) Alternatives: "Life, to specification." and "Better organisms."

## 7. Build order, smallest first, each headless

1. **Name and retire the flares.** Locale, the tag text "Synthexis culture N", green map colour, `flare.lua` out. `farm default` asserts the tag; the four `flare` scenarios are deleted.
2. **The cell.** Per pen: pad, biochamber (running), inserter, lamp. `farm default` asserts the counts and that every biochamber reports working.
3. **The feed as weak point.** `farm starve`: kill one biochamber; assert the cap at 12 within 60 s, no wave from that cell, the spawner wild (force `enemy`, vanilla prototype) at 10 minutes, the tag kept while any cell lives. `farm quiet`: a biochamber hit while the batch marches does not recall it (the guard that separates it from a pen hit).
4. **The substrate and technicians.** Soil blot, trees, towers, heating tower; two technicians walking tower to biochamber. `farm feed`: kill every technician; feed stops within 5 minutes (cap falls), resumes after the drop at 10.
5. **The clinic and growth.** Stages at 30/60 minutes; evolution climbs only with the clinic standing; `farm grow` (stage 3: a fifth cell on a hedge nest; a dead clinic freezes the tiers).
6. **Loot and the trophy.** `farm killed`: items dropped per cell, the substrate tiles and trees still there after the last pen.
7. **The Grubstake break.** `farm skim`: a Grubstake truck at a biochamber; worms fire; standing flips to war; no wild biter joins. A `rivals`-style run with a Kessler-Hayashi camp recorded, not asserted.

What the player tells a friend: "Green things, bred in glass on a purple patch out past the nests. They send one on legs to look at your wall first. Hit the tanks that feed the nests and the pack goes feral; take the glass lab and they stop getting cleverer; and when it's all dead you get their soil."
