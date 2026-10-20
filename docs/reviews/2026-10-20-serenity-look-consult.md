# Serenity's look (Fable consult, 2026-10-20)

Asked after the user's first deathworld look: "Their base looks nothing like a smart opponent would build it: no outer
walls except for their advancing frontier wall, they deconstruct turrets once the wall has advanced, which is
debatable, no road going along with the wall, only 1 type of turret (might be locked behind tech?), no defense towards
their back." With the user's pointers: space platform flooring on the ground for an alien look, the cargo buildings.
Ranked by impact per effort.

1. **One floor and a painted line.** A tile `lp-deck` (a copy of `space-platform-foundation`, not minable, charcoal on
   the map, ground collision) under every pad, post pad, compound yard and picket; refined concrete for roads only.
   A 1-tile black stripe laid post to post along each standing arc, a cold-white lamp on every post: at night a dotted
   line of lamps with a dark stripe between, the motto drawn on the ground. Risk: the tile has health; check mortar
   shells on it on Nauvis. Measure: deck under every pad; lamps equal standing posts.
2. **The camp's back: a ring of posts.** Eight cordon posts at radius ~40 round the lander, facing out, queued first;
   the first arc starts from it; bastion doctrine joins them with wall at maturity, a gate pair on each road. About 280
   parts. Measure: every 45-degree sector covered at 20 minutes; raids still leave.
3. **A supply lane along the line, and lasers that follow it.** A 2-wide road from the camp to each arc and along it
   behind the posts, a mast every 30 tiles; a post a powered mast reaches swaps a gun turret for a laser (both at
   Optics 2); a flamer at contact-wall openings; a mortar every third post at rung 3. The player can cut the lane.
   Measure: road connects lander to leading arc; turret mix by kind in `cordon_stats`.
4. **Old arcs as depth, not litter.** Recovery keeps pad, walls, stripe and lamp, and takes the turrets except at every
   third post (a strongpoint). Measure: old arcs keep 1 turret per 3 posts; recovered parts within 10%.
5. **Gates where units pass.** The contact wall's opening becomes two gates (army.gates opens them). Measure: a raid
   passes, none stuck.
6. **Cargo assets as graphics only.** The cargo landing pad is one per force and surface with logistics behaviour: the
   lander keeps its own type and borrows the pad's graphics; depots borrow the cargo bay's.

Signature: the lit line, and survey stakes on the next arc a step ahead.
Not recommended: a continuous ring wall before maturity; keeping every recovered turret.
