-- Synthexis's sweepers (0.2.189: set off on their clusters' near edge) clearing the mines before its first siege wave's
-- breach, farm siege 12345 (its breach at 241,44, its sweep from tick 131166 to 131700 filmed; 131031 headless), from its
-- fork at minute 35 (LP_MIX=siege scripts/fork.sh farm 12345 41) with its harness:
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh farm-film fork.zip docs/trailer/stills-sweep.lua
local shots = {}
local B = {241, 44}
for t = 131450, 131946, 8 do
  shots[#shots + 1] = {name = string.format("v-%06d", t), tick = t, pos = {B[1] + 14, B[2]}, zoom = 0.9, daytime = 0.1}
end
for k, t in ipairs({131500, 131620, 131700, 131780, 131860, 132000}) do
  shots[#shots + 1] = {name = string.format("w-%d", k), tick = t + 3, pos = {B[1] + 20, B[2] - 10}, zoom = 0.45, daytime = 0.1}
end
return {name = "sweep", fast_until = 131350, speed = 8, resolution = {1280, 720}, anti_alias = false, shots = shots}
