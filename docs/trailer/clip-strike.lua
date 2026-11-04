-- The orbital strike as a clip: a frame every 2 ticks (30 a second) from its paint to the end of its barrage and its
-- platform's climb,
-- on the orbital scenario's wall (its fork at minute 10), the strike forced by /lp strike.
--   scripts/film.sh orbital-film fork.zip docs/trailer/clip-strike.lua    then ffmpeg (scripts/clip.sh)
local shots = {}
for dt = 0, 720 + 540, 2 do
  local after, d = "paint", dt
  shots[#shots + 1] = {name = string.format("f-%05d", dt), after = after, dt = d, pos = "strike", off = {0, -4}, zoom = 0.55,
    daytime = 0.15}
end
return {name = "clip-strike", base = 1, resolution = {1280, 720}, anti_alias = false,
  dev = {{tick = 35940 + 120, args = {"strike", "1"}, at = {wall = true}}}, shots = shots}
