-- Synthexis's siege in ranks at the user's real wall (the user, 2026-11-05: "Any way I can get a video of the ranked
-- attack?"), on 0.2.214: visit nwwallsiege on nwa (200 behind a screen of 20 small biters, a siege's shape) from the
-- fix's save at minute 11, the harness along (it sends the wave at minute 12). Ranks muster out of reach, go through
-- together, the next sized by what the guns killed; the last at the guns covering the way in; the herd once it is open.
-- Its breach on 0.2.213 near -17,-418, the herd held about 70 tiles out at 10,-495.
--   LP_FILM_SIM="$HOME/Library/Application Support/factorio-lp-visit/nwa-rk-nwwallsiege-saveat11" \
--     scripts/film.sh nwa-rk-nwwallsiege-saveat11 t11.zip docs/trailer/reel-ranks.lua
return {name = "reel-ranks", base = 1, waves = true, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = "wave:march", moves = {
  -- The march, tracked, leading toward the wall.
  {name = "r1-march", after = "wave:march", dt = 2400, frames = 240, track = true,
    from = {pos = "wave", zoom = 0.5, daytime = 0.3}, to = {off = {0, 30}, daytime = 0.3}},
  -- Wide on the breach and the ground behind it, held: the screen, the musters, each rank going in and blowing, the herd
  -- waiting out of reach at the top of the frame, then its rush. A frame every 3 ticks: 3,600 ticks, a minute of game time.
  {name = "r2-ranks", after = "wave:breach", dt = 0, frames = 1200, every = 3,
    from = {pos = "breach", zoom = 0.45, daytime = 0.3}, to = {off = {0, 8}, zoom = 0.5, daytime = 0.31}},
}}
