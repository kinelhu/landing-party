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
    {tick = T + 30, args = {"dozers", "2"}, at = {80, 0}},
    {tick = T + 2430, args = {"bombers", "8"}, at = {60, 60}},
    {tick = T + 3330, args = {"prism", "2"}, at = {60, 120}},
    {tick = T + 4530, args = {"flak", "4"}, at = {60, 180}},
  },
  moves = {
    -- (The first takes, zoom 0.7 to 1.1, showed the units too small; every unit appeared in frame: now the defenders stand
    -- on the stage before the shot and the attackers drive in from off-screen.)
    -- The Killdozers come in over 11 s, ram through, the buggies follow the breach in: a slow push-in on the wall, 40 s.
    {name = "sc1-dozers", tick = T, frames = 2400, every = 1, from = {pos = {94, 0}, zoom = 1.4, daytime = 0.2}, to = {pos = {80, 0}, zoom = 1.7, daytime = 0.2}},
    -- The squad marches south (7 tiles a second, 40 tiles) by the stream, the camera with it; the bomb drones dive in from
    -- all round, one after another, over the water and the trees; then a hold where it stops.
    {name = "sc2-bombers", tick = T + 2400, frames = 380, every = 1, from = {pos = {70, 62}, zoom = 1.3, daytime = 0.2}, to = {pos = {68, 97}, zoom = 1.4, daytime = 0.2}},
    {name = "sc2-bombers-hold", tick = T + 2780, frames = 520, every = 1, from = {pos = {68, 97}, zoom = 1.4, daytime = 0.2}, to = {pos = {67, 99}, zoom = 1.5, daytime = 0.2}},
    -- Two Prisms with two tanks and a Tesla come at the squad, two battle tanks and rocket troopers with it; the frame
    -- between the two sides (the second takes' was on the squad, the Prisms at its edge).
    {name = "sc3-prism", tick = T + 3300, frames = 1200, every = 1, from = {pos = {84, 120}, zoom = 1.3, daytime = 0.2}, to = {pos = {78, 120}, zoom = 1.45, daytime = 0.2}},
    -- Two waves of scout drones come in over the four flak buggies, black puffs round the bursts, and fall.
    {name = "sc4-flak", tick = T + 4500, frames = 720, every = 1, from = {pos = {82, 180}, zoom = 1.3, daytime = 0.2}, to = {pos = {74, 180}, zoom = 1.5, daytime = 0.2}},
  }}
