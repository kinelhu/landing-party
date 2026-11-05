-- The manual's burster strip: the herd scenario's megaburst wave on its walled ring base (docs/trailer/stills-burst.lua
-- says what each tick of a burst shows), by full day and closer: the first wind-up (burst:first) every 3 ticks for
-- 1.5 s at zoom 2, centred on that burster; the breach every 6 ticks for 4 s at zoom 1.3.
--   scripts/film_fork.sh herd 12345 7 megaburst
--   LP_FILM_SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-herd-megaburst-12345-7" \
--     scripts/film.sh herd-megaburst-film fork.zip docs/manual/shots/m-burst.lua docs/sim/film-m-burst
local shots = {}
for dt = 0, 90, 3 do
  shots[#shots + 1] = {name = string.format("burst-%03d", dt), after = "burst:first", dt = dt, pos = "burst", zoom = 2.0,
    daytime = 0.02, hide_clouds = true, freeze = "u"}
end
for dt = 0, 240, 6 do
  shots[#shots + 1] = {name = string.format("breach-%03d", dt), after = "wave:breach", dt = dt + 1, pos = "breach", zoom = 1.3,
    daytime = 0.02, hide_clouds = true, freeze = "b"}
end
return {name = "m-burst", base = 1, waves = true, bursts = true, resolution = {1920, 1080}, anti_alias = true,
  speed = 8, fast_until = "wave:march", stop_after = 40 * 3600, shots = shots}
