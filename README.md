# Landing Party

A Factorio 2.1 + Space Age mod, in beta: three rival factions come to Nauvis. They land, mine, build settlements of
walled hubs, roads and outposts, and fight you with an army that is the output of their economy. Each faction has its
own aims and ways of fighting, which the player learns.

- **Grubstake** (arrives at chemical science) steals what you leave exposed, mostly by night: trucks skim your belts,
  raids take your machines apart and carry them off (their ghosts left), heists empty your chests, taps drain your
  power, claims take your ore. It strikes back when hurt, and its stolen goods sit in its yard until you take them back.
- **Kessler-Hayashi** (arrives at the first rocket launch) is at war with you from its landing. Its line of posts
  advances on you, cuts off your outposts, their belts and power, and besieges what stands in its way. It bills you for
  the biter attacks your pollution draws onto its ground, and raids to collect an unpaid bill.
- **Synthexis** (arrives once the biters have evolved far enough) takes over biter spawners and breeds its
  own biters in them. It scouts your defences before a wave and changes how it attacks where its attacks failed.

Status: every mechanic has a headless scenario (`scripts/regress.sh` runs them), and the factions have been run against
copies of real saves; they are not yet balanced in played games. See `DESIGN.md` (decisions, findings, status table)
and `docs/` (the AI's structure, the arc, reviews).

## Use of AI

Claude (Anthropic) was used to write the mod's code, build its 3D models in Blender and draft its manual. The textures
are CC0 materials from ambientCG and Poly Haven; no image-generation model was used. The author designed the mod,
playtested it and reviewed every change. Behaviour is verified by scripted headless test games before each release.

## Layout
- `landing-party/`: the mod.
- `tests/lp-sim/`: the headless simulation's scenarios; `tests/lp-ref/`: reference factories built for visits.
- `scripts/`: simulation (`sim.sh`), regression (`regress.sh`), visits of real saves (`visit.sh`), checks (`check.sh`),
  the AI graph (`ai_graph.py`), dev profile.
- `DESIGN.md`: decisions, findings, engine notes. `docs/reviews/`: design consults.
