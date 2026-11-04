-- A drop siege as two clips (the fortress fork at minute 14, its siege forced at 14 by its harness): its deploy, the
-- pods down and the guns assembled where they land (a frame every 4 ticks, 15 a second of play at 30), and its assault
-- (every 2). The camera held where its escort stood as each began.
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh fortress-film fork.zip docs/trailer/clip-siege.lua
local shots = {}
for dt = 0, 1800, 4 do
  shots[#shots + 1] = {name = string.format("a-%05d", dt), after = "phase:deploy", dt = dt, pos = "escort", freeze = "deploy",
    zoom = 0.75, daytime = 0.1}
end
for dt = 0, 900, 2 do
  shots[#shots + 1] = {name = string.format("b-%05d", dt), after = "phase:assault", dt = dt, pos = "escort", freeze = "assault",
    zoom = 0.6, daytime = 0.1}
end
return {name = "clip-siege", base = "siege", resolution = {1280, 720}, anti_alias = false, stop_after = 20 * 3600, shots = shots}
