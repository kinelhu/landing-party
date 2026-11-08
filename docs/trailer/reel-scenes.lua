-- The trailer's new scenes (the user, 2026-11-08: "new scenes including a dozer siege and bomber drones diving on a mass of
-- troopers"; and the Prism and the flak buggies in action): the /lp tools staged on LP_MIX=scenes's stages (its save
-- built by `LP_MIX=scenes scripts/showcase.sh 12345 3`, the stages at the save's tick), one shot each, the call a second
-- into its shot. Framings first, at scouting (storyboard section 6); then:
--   scripts/film.sh scenes <the save> docs/trailer/reel-scenes.lua
-- Stages (tests/lp-sim/control.lua, showcase LP_MIX=scenes): dozers 80,0 (the wall at x 80, the outpost behind it at
-- 70); bombers 60,60; prism 60,120; flak 60,180. Each call sets its units 10 to 45 tiles east of its point.
local T = 11160            -- the save's first tick plus a beat (showcase.sh saves at 11100)
-- Each shot follows the plugin's point "fight" (fight = true: the eased middle of the units near it with an enemy in
-- reach, from the call's aim), from 10 ticks after its call (the user, on the third takes: "the camera is not centered
-- on the fight", "missing almost all of the action": framed by guess, each shot had missed).
local function shot(name, call, frames, z0, z1)
  return {name = name, tick = call + 10, frames = frames, every = 1, track = true,
    from = {pos = "fight", zoom = z0, daytime = 0.2}, to = {zoom = z1, daytime = 0.2}}
end
-- A fixed framing, pushed in slowly, for a fight that stays where it is (the Prism's and the flak's: their fight points
-- were drawn south by units at their edges, and a camera on them drifted off the fight, the fifth takes).
local function fixed(name, call, frames, pos, z0, z1)
  return {name = name, tick = call + 10, frames = frames, every = 1,
    from = {pos = pos, zoom = z0, daytime = 0.2}, to = {zoom = z1, daytime = 0.2}}
end
return {name = "reel-scenes", resolution = {1920, 1080}, anti_alias = true, speed = 1, fast_until = T - 60, fight = true,
  dev = {
    -- (Each stage cleared once its shot is done: a scene's survivors walked into the next one's, the fifth takes.)
    {tick = T + 30, args = {"dozers", "1"}, at = {80, 0}},
    {tick = T + 1900, args = {"clear", "45"}, at = {80, 0}},
    {tick = T + 1930, args = {"bombers", "8"}, at = {60, 60}},
    {tick = T + 2600, args = {"clear", "25"}, at = {62, 85}},
    {tick = T + 2630, args = {"prism", "2"}, at = {60, 120}},
    {tick = T + 3370, args = {"clear", "38"}, at = {68, 125}},
    {tick = T + 3930, args = {"flak", "4"}, at = {60, 180}},
  },
  moves = {
    -- One Killdozer (the user: "1 dozer seems enough for these defences") comes in, rams through, widens the gap; the
    -- buggies behind it go in and on into the outpost.
    shot("sc1-dozers", T + 30, 1860, 1.35, 1.6),
    -- The squad marches by the stream; the bomb drones dive in from all round.
    shot("sc2-bombers", T + 1930, 660, 1.4, 1.6),
    -- Two Prisms, two tanks and a Tesla against the squad, its battle tanks and rocket troopers.
    fixed("sc3-prism", T + 2630, 720, {72, 118}, 1.3, 1.42),
    -- Two waves of scout drones over the four flak buggies, black puffs round the bursts.
    fixed("sc4-flak", T + 3930, 600, {70, 178}, 1.3, 1.42),
  }}
