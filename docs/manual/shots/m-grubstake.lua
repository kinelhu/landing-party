-- The manual's Grubstake siege: the fortress scenario's laser wall (LP_MIX=grubstake, its fork at minute 14; the trailer's
-- docs/trailer/act-grubstake-siege.lua), by full day and close, timed on its phases: the column on the march (tracked
-- on its escort), its howitzer truck deploying, the barrage, the assault on the wall.
--   scripts/film_fork.sh fortress 12345 20 grubstake
--   LP_FILM_SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-fortress-grubstake-12345-20" \
--     scripts/film.sh fortress-grubstake-film fork.zip docs/manual/shots/m-grubstake.lua docs/sim/film-m-grubstake
local shots = {}
local function s(name, after, dt, zoom, off)
  shots[#shots + 1] = {name = string.format("%s-%04d", name, dt), after = after, dt = dt, pos = "escort", off = off,
    zoom = zoom, daytime = 0.02, hide_clouds = true}
end
for dt = 120, 1800, 120 do s("march", "phase:march", dt, 1.3) end
for dt = 0, 900, 90 do s("deploy", "phase:deploy", dt, 1.3) end
for dt = 60, 1260, 200 do s("bombard", "phase:bombard", dt, 0.9, {0, -6}) end
for dt = 0, 900, 60 do s("assault", "phase:assault", dt, 1.1, {0, -4}) end
return {name = "m-grubstake", base = "siege", resolution = {2560, 1440}, anti_alias = true, speed = 8,
  fast_until = "phase:march", shots = shots}
