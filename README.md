# Landing Party

A Factorio 2.0 + Space Age mod, in development: rival corporations answer your rocket programme. They land, mine,
build settlements of walled hubs, roads and outposts, and fight you with an army that is the output of their economy.
Not a reskin of biters: each corporation is an adversary with intent and a character the player learns.

- **Grubstake Inc.** (arrives at chemical science): a thief. It steals what you leave exposed, mostly by
  night: trucks skim your belts, raids take your machines apart and carry them off (their ghosts left), heists empty
  your chests, taps drain your power, claims take your ore. It answers when hurt, and its stolen goods sit in its yard
  until you take them back.
- **Kessler-Hayashi** (arrives at the first rocket launch): a wall, at war from landing. Its line of posts
  advances on you, strangles your outposts, cuts belts and power, and besieges what stands in its way. It bills you for
  the biter waves your pollution sends through its ground; paying buys the only quiet it gives.

Status: both corporations play headless end to end (about 180 scenarios, visits of real saves); not yet balanced in a
played game. See `DESIGN.md` (decisions, findings, status table) and `docs/` (the AI's structure, the arc, reviews).

## Layout
- `landing-party/`: the mod.
- `tests/lp-sim/`: the headless simulation's scenarios; `tests/lp-ref/`: reference factories built for visits.
- `scripts/`: simulation (`sim.sh`), regression (`regress.sh`), visits of real saves (`visit.sh`), checks (`check.sh`),
  the AI graph (`ai_graph.py`), dev profile.
- `DESIGN.md`: decisions, findings, engine notes. `docs/reviews/`: design consults.
