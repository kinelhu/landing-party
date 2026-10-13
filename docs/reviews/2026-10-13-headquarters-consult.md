# Headquarters: design consult (Fable), 2026-10-13

Asked during the overnight autonomous run for the MVP's headquarters per corporation. Kept as written; what was
adopted is recorded in DESIGN.md.

**1. How a corporation gets its headquarters: a new landing.** Land it, do not upgrade in place. `base.land` with
`opts.uplink` already builds the fortress round a fresh lander on cleared ground; wrapping the template round a
lander that already has blocks, roads and outposts is a new collision and clearing problem. A landing is an event:
"Serenity Perimeter Group has established its regional headquarters at [gps]." When a corporation reaches level 3,
announce "consolidating" and land the HQ 10 minutes later, off the clock and exempt from the standing cap, 250
tiles from the lander of its richest standing settlement (highest exports), on the side away from the player's
silo; same site search, rings 250/370/490. Requires at least one standing settlement. In the HQ the lander is not
destructible while the uplink stands; destroying the uplink kills the lander, which runs the existing fall.

**2. Destroying a headquarters: wind-down, not instant collapse.** The HQ settlement falls at once. The corporation
is marked withdrawing: no new blocks, no rebuilds, no operations, garrisons not refilled, level frozen, no landings.
Every 15 minutes its weakest standing settlement (lowest exports) falls, with a notice. The other corporation
moves in: its next landing comes 30 minutes sooner, its cap rises, and its next site search starts from the fallen
corporation's richest former settlement. Rivals never capture outposts; the survivor lands next to the ruins.

**3. The faction-wide uplink goes; the landing clock stays shared.** One HQ per corporation replaces the
faction-wide uplink; convoys go to their own corporation's HQ only. Drop the faction tier. One shared 90-minute
clock with the launch haste; each tick lands the corporation with fewer standing settlements. Caps: 3 standing
per corporation (HQ counted), 6 overall. HQ landings are off-clock. Keep the `lp-uplink` prototype name; relabel
it "headquarters".

**4. The prize per corporation: one recipe, unlocked by script.** Serenity: the mortar (item and recipe for
`lp-mortar`, 20 salvage and 10 steel; shells 2 salvage and 1 explosives): the player takes the wall's weapon.
Grubstake: the strip drill (placeable copy of its drill: mining speed 1.0, 5x5, resource drain 50%, 15 salvage,
10 steel, 5 circuits). A recipe keeps paying after the fight; loot does not.

**5. After a corporation is gone: nothing comes for the MVP.** The survivor owns the clock. When both are gone, a
final notice, no landings. Post-MVP: a new corporation lands 180 minutes after the last fall, at the market's
level, never the same name twice.

**6. Traps and readability.** Level 3 from exports alone may never come if the player intercepts every convoy:
add an announced floor (the HQ also comes after 5 hours standing with 2 or more settlements). Make the HQ the only
place a corporation's exports leave, so cutting convoys starves it. Storage changes need a migration and an
upgrade test; rewrite the uplink scenario per corporation and add a withdraw scenario. Fall notices in each
corporation's register ("Serenity Perimeter Group regrets the closure of its regional office. Please remain
behind the line." / "Grubstake Mineral Recovery has concluded its recovery operations. Thank you for your
cooperation.").
