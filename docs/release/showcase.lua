-- Attack loops for the mod page (the user, 2026-11-10: "maybe we can even show units attacking? the prism gif is bound to
-- be a draw to players"): the trailer's staged fights (/lp tesla, bombers, prism, flak) on LP_MIX=scenes's stages, each
-- closer than the trailer's, a loop's length; cut to GIFs by docs/release/loops.py. Filmed on the Mac Studio:
--   scripts/film.sh scenes scenes.zip docs/release/showcase.lua <out>
-- Stages (tests/lp-sim/control.lua, showcase LP_MIX=scenes): bombers 60,60 (its squad: the Tesla's too); prism 60,120;
-- flak 60,180. Each call sets its attackers 10 to 45 tiles east of its point.
local T = 11160
local function shot(name, call, frames, z0, z1)
  return {name = name, tick = call + 10, frames = frames, every = 1, track = true,
    from = {pos = "fight", zoom = z0, daytime = 0.2}, to = {zoom = z1, daytime = 0.2}}
end
local function fixed(name, call, frames, pos, z0, z1, pos1)
  return {name = name, tick = call + 10, frames = frames, every = 1,
    from = {pos = pos, zoom = z0, daytime = 0.2}, to = {pos = pos1 or pos, zoom = z1, daytime = 0.2}}
end
return {name = "showcase", resolution = {1920, 1080}, anti_alias = true, speed = 1, fast_until = T - 60, fight = true,
  dev = {
    {tick = T + 30, args = {"tesla", "3"}, at = {60, 60}},
    {tick = T + 560, args = {"clear", "25"}, at = {62, 65}},
    {tick = T + 600, args = {"bombers", "8"}, at = {60, 60}},
    {tick = T + 1260, args = {"clear", "25"}, at = {62, 85}},
    {tick = T + 1300, args = {"prism", "2"}, at = {60, 120}},
    {tick = T + 2040, args = {"clear", "38"}, at = {68, 125}},
    {tick = T + 2080, args = {"flak", "4"}, at = {60, 180}},
  },
  moves = {
    shot("tesla", T + 30, 480, 1.9, 2.0),
    shot("bombers", T + 600, 600, 1.7, 1.8),
    fixed("prism", T + 1300, 700, {79, 117}, 1.8, 1.95, {84, 115.5}),
    fixed("flak", T + 2080, 560, {70, 178}, 1.7, 1.8),
  }}
