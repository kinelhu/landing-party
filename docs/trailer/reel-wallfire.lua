-- Kessler-Hayashi's wall fire (0.2.216; the user: "Send me the videos when they're ready"): fortress LP_MIX=closed 12345
-- from its fork at minute 13 (scripts/film_fork.sh fortress 12345 19 closed), timed on its rehearsal (FILM_REHEARSE,
-- trace on): march 50460, guns down 50800, bombard 52600 (site -121,-222, its howitzer on the roboports), at 59200
-- "walled off, no strike: wallfire", its guns break the piece at -99,-224, 59500 "its guns opened the wall; its assault
-- goes in" by -100,-222, falling back 60400.
--   LP_FILM_SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-fortress-closed-12345-19" \
--     scripts/film.sh fortress-closed-film fork.zip docs/trailer/reel-wallfire.lua
return {name = "reel-wallfire", base = "siege", resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = 52900, moves = {
  -- The battery shelling the roboports behind the wall: guns at the left, the wall at the right.
  {name = "w1-bombard", tick = 53000, frames = 240, every = 2, from = {pos = {-111, -223}, zoom = 0.75, daytime = 0.1}, to = {pos = {-109, -223}, zoom = 0.8, daytime = 0.1}},
  -- Its guns on the wall piece itself, the wall coming down, and the assault going through.
  {name = "w2-wallfire", tick = 59150, frames = 400, every = 1, from = {pos = {-106, -223}, zoom = 0.95, daytime = 0.1}, to = {pos = {-103, -223}, zoom = 1.0, daytime = 0.1}},
  {name = "w3-assault", tick = 59560, frames = 420, every = 2, from = {pos = {-101, -222}, zoom = 0.9, daytime = 0.1}, to = {pos = {-92, -223}, zoom = 0.85, daytime = 0.1}},
}}
