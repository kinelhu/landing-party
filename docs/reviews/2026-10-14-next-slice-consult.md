# Next slice for the MVP: design consult (Fable), 2026-10-14

Asked overnight after late pressure, the moving line, claims and the six-settlement profile were built.

**Ranked.** 1. The campaign instrument, smallest form: a reactive scripted player, not an agent. Every multi-hour
mechanic (HQ at level 3, the second corporation at the third landing, withdrawal, vacancy, claims) has only run
on fast clocks or by hand, and the only long run (`contact`) has a player that never fights, so a lander has never
fallen in a campaign. Measure cost to each side, not launches: the late base's "8 operations" included five 4-man
raids on one substation inside the wall that came home untouched. 2. Close the loop before widening it ("fought
capture: no squad wins yet"). 3. Claims and materialisation only when the six-settlement profile stops being
enough. 4. Standing and contracts (GUI-bound; leverage matters once the player can win). 5. The settlement panel
(cannot be verified headless; a session with the user).

**Smallest version.** A `campaign` scenario from `contact`'s spread base, 6 hours at real clocks, unprovoked, three
rules every 5 minutes: answer (two lasers where attacked, capped by era), expand (an outpost every 30 minutes),
strike (every 45 minutes, a squad at the nearest settlement's lander if its garrison and turrets are below a
threshold, else at its nearest outpost); era up every 90 minutes. Through remote calls and harness helpers only.

**Assertions.** An operation against the player every 30 minutes after minute 40, and every landed operation costs
someone something; a lander destroyed by the player before hour 4, the corporation back within 30 minutes; the
second corporation by hour 5, both raided each other; one consolidated by hour 6; script under 1 ms a tick. Seeds
12345 and 777; a milestone run like `contact.sh`, not in `regress.sh`.

**Two bugs.** A tried undefended target is still picked when nothing else is known (five identical raids); a raid
that attacked and razed nothing should raise the target's known defence. Raid staging can fall inside the
player's wall; it should search out of reach, as the siege site does.
