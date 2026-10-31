# Hard counters and desperation: a design consult (Fable, read-only, 2026-10-31)

Read: `DESIGN.md` (lane matrix findings 0.2.100 to 0.2.116, the ladder), `tactics.lua`, `attempt.lua`, `farm.lua`,
`herd.lua`, `ops.lua`, `war.lua`, `stance.lua`, `cuts.lua`, `feeds.lua`, `know.lua`, `biotech.lua`, `shared.lua`, the lane
builder in `tests/lp-sim/control.lua`, and Space Age's `turrets.lua` and `beams.lua`. Nothing run, nothing edited.

## 1. Tesla turrets against bursters

**The counter is the stun, not the damage.** The tesla beam does 120 electric a hit and chains, and every hit applies two
stickers: `tesla-turret-stun` (half a second at 5% movement) and `tesla-turret-slow` (two seconds at half speed). A big
burster is a behemoth body, the slowest breed, with 3,000 health and 50% laser and fire resistance (`biotech.lua:330`). Under
two or three teslas it is pinned where it stands and killed at leisure. A flat electric resistance would lengthen that by a
few seconds and change nothing; stickers have no resistance entry, and the only way round them is a trigger mask, which is
all or nothing. So I agree with the lead on "no flat resistance", for a stronger reason than balance: it does not address the
mechanism. A one-minute arena check settles it (test A below).

**The intended answer exists and is the right one.** The tesla is the most power-hungry turret in the game: 1 MW drain each,
7 MW input, a 15 MJ buffer. A line of fifteen idles at 15 MW. Synthexis already reads tesla as an `electric-turret`
(`feeds.lua:201`), so `power.cut` finds the pole whose loss darkens it, and the menu already carries `cut` and `strike`
(`farm.lua:992-1010`). The lab hid this with an interface inside the fort. I agree the lane must be powered from outside
before anything is built. Two more existing levers deserve a look in the same lab session, because they need no new
mechanism:

- *Drain.* With a finite plant, a sustained screen of cheap breeds at the wall empties tesla buffers; the screen already exists
  (`siege_size` fodder, `sequence`). Record each turret's energy beside its health in the lab's half-second samples.
- *Spacing.* The chain beam jumps between nearby targets. Rams sent in the screen's footprint are chained through it. Sending
  rams spaced apart and offset from the screen is a change to `send_big_bursters`, not to a prototype.

**If power is well protected, the developed escalation should change delivery, not armour.** A "grounded ram" with electric
resistance is still a slow body walking into a stun field; the lab's 1, 2, 4, 5 rams with none reaching the wall says more
of the same is not it. The breed that beats a stun field does not walk the last stretch: a lobber, a spitter body whose
projectile is the burst, thrown from outside the tesla's reach at the wall or the gun. It reads clearly (a new silhouette, a
notice: "Synthexis breeds lobbers: your tesla turrets held its rams twice"), it has its own counters (rockets and artillery
outrange it; teslas moved forward), and it slots into what exists: `develop_bursters` and `herd.held` give the two-stop gate,
`tactics.failed_specialists` the escalation, `siege_size` the sizing, `sequence` the staging. To build: the prototype, a gate
that reads which gun held the wave (lessons already record killers by name), and the lobber's place in `sequence`.

**Risks.** The cut is only an answer where a feed exists: a fort whose poles sit behind the wall on a ribbon map has none, and
the lab must not teach us that forts are safe because the lane is. The drain answer depends on the lab's plant being sized
like a player's, a choice the lab should state. A lobber that outranges every turret trivialises walls: its range must sit
inside rocket and artillery reach, and the lane matrix must show rockets holding it.

**Player's view.** Poles going down and teslas going dark, then a wave through, is the most legible thing the mod does. A
lobber appearing after tesla held twice is the second. A ram that shrugs off lightning is the least: the player sees their
Fulgora tech fail with no story.

**Test B (decides it).** `LAB_LANE guns=laser+tesla faces=both`, the plant behind the fort, three rear faces: (a) lasers and
tesla, meshed poles (protected); (b) lasers only; (c) an exposed pole run. Two seeds of eight. Read in `decisions.txt` which
method the menu picked each trial; in the report, teslas dark at the breach, in or not, deaths by killer. Decision rule: if
(b) and (c) get in at half or more while (a) holds, the cut is the answer and the lobber is built for (a) alone; if (b) holds
too, the cut's weighing is at fault before anything is bred. **Test A** first: the wall lab, one burster against two teslas at
the ram's lane, with and without 50% electric resistance, four seeds; if time to the wall differs by under a second, the
resistance question is closed.

## 2. Kessler-Hayashi's top rung

**What the code does now.** At rung 3 `choose` skips the odds test (`ops.lua:547`), `launch` sends whatever it has
(`want = math.min(want, n)`, `ops.lua:1083`), the reserve joins, player targets weigh ten times (`WEIGHTS.desperate`),
the cap rises by half and the siege a tier (`siege_tier`, `army.cap`). The ladder (`tactics.ladder`) is applied in the
raid/siege/strip weighing, but only to a method that failed at the same 64-tile cell, and a lane's wall spans several.

**The lead's take is right in direction and needs one correction.** Without the bypass, the odds rule only gates the target:
`launch` still refuses when `n < want`, the needed force at learned prices. So halving `min_odds` and removing the bypass
yields a corporation that never launches against the lane at all: odds 0.25 means it fields 58% of what the target needs, and
`launch` turns it away. Bolder must mean *finding the force*, not lowering it. The pieces exist: the war chest and relief by
rung (`war.lua`), the reserve, sister columns, the top siege tiers with their assault, the cut targets (`cuts.lua`), the
jammer and counter-battery. RTS AIs that are losing pool and pick the target that hurts; an all-in is committed once the pool
is assembled, never trickled at a wall.

**Proposal.** At rung 3: keep the odds test at half `min_odds`; keep sizing honest (the bypass only for answers and
self-defence, where it belongs); let the chest buy the shortfall for the chosen target (a relief sized to `want - n`,
announced as now, then the raid: the player sees the build-up); weigh cut targets and sieges up over raids (a desperate
corporation goes for supply, as `prefer` already lets a mind say); unlock the assault tier and the signature moves. Keep
the stand-down clock (`quiet`, 60 minutes without a raze) as the floor under "never stalls forever": a corporation that cannot
assemble the force goes quiet and a new landing comes, which is already the design. One check: `stance.rung` resets on any
raze, so a desperate raid that breaks one wall piece drops the rung to 0; confirm walls do not count there, or desperation
ends the moment it starts.

**Risks.** The chest is the corporation's: a desperate camp drains relief from sisters. A target impregnable at any size will
hold the chest for ever, so the ladder's hold must still bite, and raids need `history_near` as sieges have it, or each of the
wall's cells reads as untried. Prices learned from raids that razed nothing go up only (`learn_price` floor), which is right.

**Player's view.** Today: tiny raids dying at the wall every few minutes, vanilla biters in suits. Proposed: a relief column
lands, a siege digs in at the top tier, poles go, then the raid; or silence and a new landing elsewhere. Both are stories.

**Test C (decides it).** `LAB_FACTION=serenity` on the one-wall laser lane, `ladder_fast`, rung 3 forced, two seeds of eight,
three variants: current; the lead's (half odds, honest sizing, chest tops up); the lead's plus cut and siege preference.
Metrics: razed per 100 lost (Synthexis's 2.9 on this lane is the bar), trials with nothing sent, and the contract's five
checks. Decision rule: no variant may fail `changes`; of those that pass, the one with the fewest zero-raze operations wins.

## 3. The principle for future counters

A hard counter stays hard. The attacker answers on another axis: supply (cut, drain), delivery (ram to lobber, ground to
air), timing (strike after a cut), or target (the outpost beside the fort). Tower defence lives by this: Kingdom Rush never
patches a tower's weakness, it sends an enemy the tower cannot touch, so the defence must diversify. Every answer is *gated*
by the player's choice holding twice (`herd.held`), *announced* in one sentence naming the cause, *bounded* to one rung per
counter (`RAMS_MAX`), *priced* so a maintained defence drains the attacker, and *counterable* by a move visible on the map.
Each new counter (flamethrower, artillery, tesla) gets six things in order: a correct perception (`know.DAMAGE` maps
`electric-turret` to laser, so a tesla death would buy Kessler-Hayashi laser plate; `counters.lua` needs a tesla column), a
learned price, a method on the menu, a developed escalation, a lab lane, and a contract check. None is a stat on the hull.
