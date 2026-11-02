# Kessler-Hayashi, late game: a design consult (Fable, read-only, 2026-11-02)

Read: `DESIGN.md` findings 0.2.133 to 0.2.149, `docs/corporations-brief.md`, `docs/army-brief.md`, `dome.lua`,
`orbital.lua`, `war.lua`, `siege.lua`, `ops.lua`, `army.lua`, `faction.lua`, `base.lua`, `planner.lua`, `intel.lua`,
`valuemap.lua`, `shared.lua`, and the two 0.2.147 visits' `decisions.txt` and `results.txt` (`docs/sim/visit-nw-rich-m147`,
`visit-nwa-rich-m147`). Nothing run, nothing edited.

## 1. Verdict

The direction is right and the sequencing stopped half-way. Seven of the nine entries since 0.2.133 are about the hull:
dome, armed landing, barrage, sweep, relay, corridor strike, hub domes. They were needed (it fell in four of five fed runs)
and they worked: neither 0.2.147 visit lost one of its buildings to the player's artillery. But the offence it carries
into the late game is still the mid-game siege of a camp of Grubstake's size, and the measurements say so: fed nw at
0.2.135 razed 330 in 200 minutes, at 0.2.147 108 in 90; the per-minute rate has not moved through five releases. A camp
that cannot be killed and cannot hurt is a decoration, and it forces no encounter: the player's cheapest answer to
Kessler-Hayashi today is to ignore it.

## 2. The biggest gap: the siege is a one-shot, and nothing in it reads the base it faces

The siege is the only operation on its menu that outranges a wall, and the only caller of the orbital strike
(`siege.lua:813`). Everything built this week hangs off it. Traced on the two visits:

**It rarely gets chosen.** The raid's score carries `relevance` (`ops.lua:570`: pressure x3 at war, grudge up to x5,
`ops.lua:500`); the siege's does not (`siege.lua:202`: value over distance, nothing else), and is then halved by
`prefer.siege = 0.5` (`shared.lua:186`). A factor of 6 to 30 against the siege, applied exactly when it is at war. On nwa:
294 weighings, every one `raid 22.73, siege 1.36`, 0 sieges in 90 minutes, therefore 0 strikes. What won was a
substation among solar panels, because a cell is named for its most valuable building (`intel.lua:160`, `ops.VALUE`
substation 6, `ops.lua:105`) and all twelve known targets read `d0.0`. Seven raids of 13 took 77 solar panels and 56
accumulators: 143 buildings on a base of 11,230 robots.

**When chosen, it is sized by a table, not by the defence.** Tier comes from `army.level` (`siege.lua:215`), 2 for an
armed camp (`armed_level`, `shared.lua:110`), so `SIEGE_TIERS[2]`: 2 mortars, 40 shells, 10 guards (`ops.lua:85-90`).
On nw it went twice at a substation of `defence 460.8` with those 10 guards; both times `0 of 10 came back`, the first
within 25 seconds of the mortars going up. The fund (`siege_save`, `base.lua:435`) saves toward a tier-4 siege the tier
rule will not grant below ladder rung 3 with a grudge (`siege.lua:217-219`), while the camp made 22,810 parts.

**It cannot persist.** `SIEGE_MAX_TICKS` is 15 minutes (`ops.lua:79`), the strike fires once a siege
(`op.strike_called`, `orbital.lua:43`) and once per 15 minutes a camp (`orbital.lua:19`), 18 tiles each way
(`orbital.lua:17`). The emplacement has no dome: projectors go to hubs only (`dome.lua:175-177`), so the howitzer, a
military target, is shelled, and its splash took the mortar twice (0.2.135). On nw the whole offence of 90 minutes was
two strikes (18 and 15 shells) and 92 mortar shells: 108 buildings, 21 roboports, all rebuilt by robots.

**And its army is a growth byproduct.** `army.cap` is depots x (10 + 5 x level) (`army.lua:52`): 40 on nwa (2 depots),
120 on nw (5). A fortress of 111 turrets and 1,041 walls fields 13 units. Income is not the binding constraint: nwa made
6,203 parts in 90 minutes and spent them on 1,041 walls, 8,103 road tiles and 1,384 landfill, with 471 jobs queued.

The single missing piece, then: **a standing siege.** Something out of the turrets' reach that the artillery cannot kill
and the robots cannot out-repair, that grinds until troops come. That is what "an army cracks it" means in the brief,
and nothing on the menu does it.

## 3. Changes, ranked

**1. The standing siege (the piece).** A siege against a player, tier 2 and up, brings a dome projector on its hauler
(the hub projector's prototype, its charge from the guns that reach the site: `dome.lua:52-74` already computes it per
anchor). While the mortars stand and the fund pays: convoys keep coming (`RESUPPLY`, `SHELLS_CAP` exist), the strike is
called again each `COOL` with a fresh paint (drop the once-a-siege flag, keep the 12 s spotter: the army's job), and
`SIEGE_MAX_TICKS` does not apply. It ends when the fund is dry, the projector is destroyed (troops, or three minutes of
every gun that reaches it, aimed by hand: the dome's own rule), or the target is gone. Readings, not numbers: shells per
strike from `threat.shells_for`, the dome's whole from the guns in reach, the fund from what it makes. *Test:* visit nw,
90 minutes: siege length (now at most 15 min), shells fired per siege (92), strikes per siege (1), razed per siege (30
and 78). Visit nwa with `LP_MIX=fwdarty`'s forward battery moved to cover the site: mortars lost to artillery (now every
one with a howitzer). Scenario `fortress`: a siege standing 30 minutes against lasers alone. Decision rule: razed per
hour on nw at least triples and the siege ends by destruction of the projector, never by the clock.

**2. Weigh and size the siege by what it faces.** Multiply `choose_siege`'s score by `relevance` (one line at
`siege.lua:202`); make `prefer.siege` for an armed camp a trait of its mind at or above the raid's (a named prior, as
`siege_save` is). Replace the level-held tier with a reading: guards from `needed` of the guns covering the site
(`threat.covering`), shells from `shells_for` of what the mortars will aim at (`focus`, `siege.lua:264`: roboports
first), the cost summed and paid from the fund; `SIEGE_TIERS` stays as the floor for an unarmed camp. *Test:* visit
nwa, 90 minutes: `weighs` lines where the siege wins, sieges launched (0), razed by kind shifting from solar and
accumulator to roboport, laser and substation. Scenario `siegetier`: the tier or cost reached against the laser lane.

**3. The cap from the war, not the depots.** For an armed camp, `army.cap` is at least what its best player target
needs at its `min_odds` (`needed`, `ops.lua:472`), bounded by what its income replaces an hour at the mean unit price
(`war.lua:527` already computes that price). Depots stay the rule for every unarmed camp. *Test:* the nwa dump's `cap`
(40) and each raid's `launched` (13); `units_built` against `made`; regression `--area=ops`. Smallest change, least
certain payoff: a raid of 60 at a laser wall still dies, which is why it ranks third and the siege first.

## 4. Stop doing

- **Freeze the hull.** No further survival feature without a run in which it fell. Survival is measured solved on both
  megabases; the next entry should move `razed` or "ended by the player's units", not `lost`.
- **One run a save is not a measurement**, and the entries admit it ("within the runs' swing", "one run's Synthexis
  swings twentyfold"). The richness A/B read 118 to 97 and 30 to 47 and concluded nothing. Three seeds or no claim.
- **The working tree has 0.2.149 off**: `base.lua:380` reads `m.richness = 1` with the sum computed and discarded.
  Whatever regression is running now runs without richer ore paying more. If that is the A/B, name it in the commit;
  if not, it is a slip.
- **Three answers to one problem.** Haulers dying in nest country have the corridor strike, the `ground_clear` gate
  (`ops.lua:1811`) and the gate-side wait (`siege.lua:328`). With the corridor strike working, `ground_clear` is the one
  most likely to hold a siege forever on a nest-dense map; retire it once a visit shows the corridor strike alone gets
  haulers through.
- **Do not grow the orbital arsenal before the siege stands.** A bigger strike on its own is the artillery nerf the user
  ruled out, by another name: shells the player cannot answer. Under the standing siege the strike is answerable (kill
  the spotter, take the projector), which is the whole point.
