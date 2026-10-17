# Notices consult (Fable, 2026-10-17)

Asked: with chat notices off by default (the user: "nothing is communicated through notices in factorio ... OK for
debugging, or as an ultimate resort (like pointing the first landing of a faction)"), which notices can go, which carry
information the world does not show yet (and the world tell for each), and where a notice is the only fair warning.

Premise taken from the rule: Factorio speaks through the chart, entity colour, status icons, smoke, light, sound and its own alerts. Three facts do most of the work below and cost nothing:
- **The chart draws every enemy-force structure in that force's colour** inside the player's radar cover. A rig 50 tiles from the wall, a pylon line creeping to a pole, a stake on a patch: all appear on the map in Grubstake ochre or Serenity teal the way a biter expansion appears red. Most "where" information is already shown.
- **The engine's own alerts** (under attack, destroyed, turret firing, no power, train no path) fire for everything that actually hits the player.
- **The mod already has map marks** (settlement tag with standing, claim disc, next arc with arrow, border line, prospect tag). The missing pieces are state and time, and those read as light and vehicles, not words.

## 1. Sorting

| Notice | Sort | Why / what the world shows |
|---|---|---|
| signs | (c), optional | The wreck is 180 tiles from a player radar: chart it with a tag (icon only, "?"). If charted, the notice can go. Falls under the first-landing allowance either way. |
| survey, survey-left, survey-destroyed | (a) | It has a map tag and a radar mast; the chart shows it arrive and leave; the core drops as an item on the ground. |
| develop, node-* (15) | (a) | Factorio never announces enemy research. The new unit kinds carry their names and descriptions on hover, and their components drop as loot with descriptions. The player meets a Lance; that is the notice. |
| clearing, landing-cleared, orbital | (a) | Explosions, craters, nests vanishing from the chart. (Orbital becomes the late-gate tell: see below.) |
| perimeter | (a) | The posts stand; the arc is drawn on the map. |
| perimeter-warning | **(b)** | Enclosure provokes Serenity for good. Needs survey stakes (section 2) and a fairness fix (section 3). |
| claim, claim-outpost, prospect-claimed | (a) | Drills and a disc on the map; the truck seen building. |
| prospect | **(b)** | A ten-minute window with nothing in the world marking it. Stake entity (section 2). |
| consolidating, headquarters | (a) | The HQ is a building with a tag when it comes; "will follow" is a promise nobody acts on. |
| hq-down-*, withdrawing-* | (a), fold into fallen | A fall is kept; the HQ's fall is a fall. Withdrawal is units walking away and a tag reading "(fallen)". |
| landed | (c) kept | |
| grudge-landed | (c), fold into landed | Same event, angrier motto. One notice, two texts. |
| grudge | (a) | Consequence lands at the next landing (kept). The camp label already reads "enemy". A lander the player killed is the player's act; biters do not warn about evolution either. |
| relief-pod, relief-column, relief-drop | (a) | A pod is a visible drop (smoke trail, a pod entity); a column crosses charted ground in its colour. |
| pact-broken, pact-restored | (a) | The antenna is gone or back; biters are seen attacking its camps. Give the antenna a spinning dish or a light so "working" is visible from the ground. |
| strike | (a), flying text | The player's own beacon: the shells are seen. "N targets" may be flying text at the beacon as a reply to the player's act. |
| breaker-lit, breaker-outside | (a), flying text + entity state | breaker-outside: refuse placement with flying text ("No Grubstake claim here", as "cannot build"). breaker-lit: the breaker burns like the flare (smoke, light) for its 3 minutes; status icon off when done. |
| rig | **(b)** | One minute, loss inside the wall. Section 3. |
| rig-down | (a) | The mound stops growing; the rig wreck. |
| standing-enemy, standing-rival | (a) | The settlement tag already carries the standing. Factorio does not say when biters get angry. |
| border-accepted / -refused / -inside / -none | (a), flying text + stake light | Refusals: flying text at the stake as "cannot build" (better: refuse placement, stake returned). Accepted: the stake lights in Serenity teal and the border line appears on the map. |
| border-broken | (a), flying text + stake light | Flying text at the offending building; the stake goes dark; the border line leaves the map; the tag reads "enemy". The player did it, possibly by robot far away: the chart tells on the next look. |
| tribute | **(b-lite)** | The truck empties the post (seen); tag reads "truce". The end of the truce is invisible: a light on the post (section 2). |
| road-lost | (a) | The player killed the truck and sees the ore spilled. "Expansion delayed N min" is trivia. |
| claim-lapsed | (a), with entity status | Lapsed claim loses power: generator stops smoking, drills show the engine's "no power" icon, lamp dark, disc off the map. A dark silent camp reads "abandoned". |
| line-held, crew-gave-up | (a) | The player killed the crews and nothing more appears. The next-arc mark leaves the map. |
| tap-cut | (a) | Cable drops; the player did it. The MJ figure belongs in the power statistics, where the tap already shows. |
| stood-down | (a) | Tag reads "rival" again; the camp goes quiet. Optionally dim its lamps while stood down. |
| late-gate | (a), by folding | Make the orbital shelling of nests round the site precede the lander by the five minutes: explosions and nests vanishing on the chart are the warning, then the landing notice (kept). |
| fallen | (c) kept | |
| alert-raid / -siege / -loot / -flare / -rig | gated | Engine alerts cover damage. |
| alert-strip | (a) with smoke | Strip drills are enemy-coloured on the chart, and they pollute: give the strip camp a heavy dark plume and the chart's pollution overlay shows it in a place the player has no machines. Grubstake's identity: dirty. |

Count: three (b), one (b-lite), two kept, two folded into the kept ones, everything else goes or becomes flying text or an entity state.

## 2. World tells for (b): one mechanism, two owners

**The stake.** One small entity kind, a post with a lamp light, tinted per corporation, no collision trouble, destroyable, charted in its force's colour. The player already has one (the border stake); give the corporations the same object. Its name and description are the only text, read by hovering, as any Factorio entity is.

- **prospect (Grubstake).** At the moment it now tags the patch, a truck drives out and plants a claim stake in the middle of the patch (amber light), then drives home. Entity name "Grubstake claim stake", description "Mineral rights reassigned. Unworked ground is claimed when the truck returns." The map shows an ochre dot on a patch where the player has nothing (chart) plus the existing tag. In the last two minutes the lamp switches to red (one `lamp.color` write; blinking by toggling every second in the last minute if wanted). At claim time the second truck leaves the camp with the module; the road is the clock. Destroying the stake abandons the prospect (it already abandons on a drill or marker) and counts as the incident it is.
- **perimeter-warning (Serenity).** One step ahead, drones plant survey stakes on the next arc (teal light, every 60 tiles where posts will stand), one of them beside the enclosed player structure. From the map: a dotted teal line across the ground, the existing arrow on the bearing, and the player's own building on the wrong side of it. Name "Serenity survey stake", description "Please remain behind the line." The posts are then built on the stakes. The player's answer is literally the same object: plant a border stake short of the survey line.
- **tribute (b-lite).** The trade post carries a lamp: lit in Grubstake amber while the truce holds, off when it ends. The tag's "truce" stays. A refill while the lamp is on extends; a dark post means the next raid is coming.
- **rig.** No new mechanism: the rig is already enemy-coloured on the chart, and the mound already grows. Add a line of dust puffs (trivial smoke) advancing from the rig to the chests at the dig rate, so a player who sees the mound can trace it back without being told where the rig is. Section 3 for the time.

Secondary, if light is judged too quiet: the existing map tags can carry a counter ("7 min") updated every 30 s. It is the map, not chat, but it is still a number in words; prefer the light.

## 3. Fair warning before unseen loss

- **The rig (one minute).** Without the alert a player elsewhere loses a chest's contents and some nearby pieces with no chance to react. Two things make it fair: (i) the loss is bounded (a raid's loot cap, 30 s of breaking) and the engine's own "destroyed" alerts fire when the hands break things, as a biter surprise does; (ii) the rig stays findable afterward. So: lengthen the dig to 2 to 3 minutes (the mound and dust line make a tell a player at home will see; on the chart the rig is an ochre structure that was not there), leave the tunnel mouth as a mound until cleared and the rig standing a few minutes after the heist, so the first heist teaches what the next looks like. Gate the alert. The one-minute version with no alert is not fair; the three-minute version with the chart is.
- **The prospect (ten minutes).** The loss is small and reversible (an unworked patch; the claim lapses when its road is cut, which is the designed answer; razing it costs standing). With the stake and the truck seen on the road it is fair with no notice. Outside radar cover the player learns of it when they go there, as with a biter expansion. Consider 15 minutes since no text counts down.
- **The perimeter (ten minutes).** The loss is permanent: enclosure provokes Serenity, which never forgets, for doing nothing. The survey stakes are the fair warning only if the player's radar covers the arc; an outpost beyond radar cover gets enclosed unseen. Two fixes, take one: (i) enclosure of a structure that stood before the arc does not provoke; the cordon builds its contact wall and gate posts round it (the asphyxiation moment, which is the pressure wanted), and only what the player builds on Serenity's side afterward provokes; or (ii) keep the provocation and keep perimeter-warning as the one (c) notice beyond landing and fall, because no in-world tell reaches an uncovered outpost. (i) is the Factorio answer: the line moving onto you is the corporation's act, not yours.
- **Border broken by a robot build.** The player's own act, but far from where they look. The stake going dark and the line leaving the map tell on the next map look; the first raid tells the rest. Acceptable; a flying text at the robot-built entity is the reply, as planned.
- **Truce ending.** Silent today; the lamp on the post closes it.

Files read: DESIGN.md (rig, prospect, standing, cordon, tap, border and road, perimeter, flare, map), docs/arc.md,
docs/corporations.md, landing-party/locale/en/locale.cfg.
