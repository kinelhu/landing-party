-- The trailer's new scenes (the user, 2026-11-08: "new scenes including a dozer siege and bomber drones diving on a mass of
-- troopers"; and the Prism and the flak buggies in action): the /lp tools staged on LP_MIX=scenes's stages (its save
-- built by `LP_MIX=scenes scripts/showcase.sh 12345 3`, the stages at the save's tick), one shot each, the call a second
-- into its shot. Framings first, at scouting (storyboard section 6); then:
--   scripts/film.sh scenes <the save> docs/trailer/reel-scenes.lua
-- Stages (tests/lp-sim/control.lua, showcase LP_MIX=scenes): dozers 80,0 (the wall at x 80, the outpost behind it at
-- 70); bombers 60,60; prism 60,120; flak 60,180. Each call sets its units 10 to 45 tiles east of its point.
local T = 11160            -- the save's first tick plus a beat (showcase.sh saves at 11100)
return {name = "reel-scenes", resolution = {1920, 1080}, anti_alias = true, speed = 1, fast_until = T - 60,
  dev = {
    {tick = T + 60, args = {"dozers", "2"}, at = {80, 0}},
    {tick = T + 1260, args = {"bombers", "6"}, at = {60, 60}},
    {tick = T + 2460, args = {"prism", "1"}, at = {60, 120}},
    {tick = T + 3660, args = {"flak", "2"}, at = {60, 180}},
  },
  moves = {
    -- The Killdozers ram the wall, the buggies pour through after 10 s: a slow push-in on the wall.
    {name = "sc1-dozers", tick = T, frames = 1200, every = 1, from = {pos = {92, 0}, zoom = 0.7, daytime = 0.25}, to = {pos = {84, 0}, zoom = 0.9, daytime = 0.25}},
    -- The bomb drones dive into the block of troopers: a lock-off a little low, the troopers in the lower third.
    {name = "sc2-bombers", tick = T + 1200, frames = 600, every = 1, from = {pos = {78, 58}, zoom = 0.9, daytime = 0.3}, to = {pos = {76, 58}, zoom = 0.95, daytime = 0.3}},
    -- The Prism's beam splitting into the troopers: close.
    {name = "sc3-prism", tick = T + 2400, frames = 600, every = 1, from = {pos = {80, 120}, zoom = 1.1, daytime = 0.3}, to = {pos = {78, 120}, zoom = 1.2, daytime = 0.3}},
    -- The scout drones come in over the flak buggies and fall: a lock-off wide enough for the drones' run.
    {name = "sc4-flak", tick = T + 3600, frames = 720, every = 1, from = {pos = {85, 180}, zoom = 0.75, daytime = 0.35}, to = {pos = {80, 180}, zoom = 0.8, daytime = 0.35}},
  }}
