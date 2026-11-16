-- The player's orbital cannons answering back (cut 28; the user, 2026-11-16: "can we get a shot of an orbital cannon
-- battery firing in the trailer?"): on nw at minute 15 (reel-khwall.lua's save), a platform of five cannons over Nauvis
-- (/lp cannon 5, the dev deck, as scene-cannon.lua's first look of 0.2.275, never cut in) fired on Kessler-Hayashi's
-- siege outside the user's south wall once its guns stand: the battery's shot on the platform, then its strike on the
-- siege, the wall across the top of the frame. Its beats on 0.2.431 from a rehearsal (one still each): march 12097800,
-- deploy 12099400 (guns and its jamming mast under their shield round -133,371), bombard and paint 12101200. A cannon
-- strike falls about 510 ticks after its shot (scene-cannon on 0.2.431: telegraph ring, the platform's shadow, then the
-- shells).
--   scripts/film.sh nw-khwall-saveat15 t15.zip docs/trailer/reel-cannon.lua
local FIRE = 12100700
return {name = "reel-cannon", base = 1, resolution = {1920, 1080}, anti_alias = true, speed = 8, fast_until = FIRE - 100,
  stop_after = 90000,
  dev = {{tick = 12099000, args = {"cannon", "5"}, at = {0, 0}}, {tick = FIRE, args = {"cannon", "fire"}, at = {-134, 373}}},
  moves = {
    -- (platform-3: nw has two platforms of its own, platform-1 and 2; the first take filmed the user's.)
    -- The battery firing: five barrels over the void, Nauvis's edge beside, the flash and recoil, the deck shaken.
    {name = "fire", tick = FIRE - 40, frames = 240, every = 1, surface = "platform-3",
      from = {pos = {-4, 38}, zoom = 0.42}, to = {pos = {-4, 40}, zoom = 0.45}},
    -- Its strike on the siege: the ring, the platform's shadow, the shells, the bastion above. (Centred at 352 the
    -- siege sat on the frame's bottom edge.)
    {name = "strike", tick = FIRE + 210, frames = 600, every = 1,
      from = {pos = {-136, 360}, zoom = 0.55, daytime = 0.3}, to = {pos = {-136, 362}, zoom = 0.6, daytime = 0.3}},
  }}
