-- A corporation's landing as a clip (landfx.lua; the user, 2026-11-04, on shot 2: "the lack of animation is a little
-- jarring. Perhaps we could add some falling cargo pods dropping with the crashed lander?"): Grubstake forced down on the
-- trailer visit's save at minute 19 (/lp land grubstake 654, as shot 2), by pod as its own landings come: the pod, the
-- hull's shadow and fall, the crash, then its six pods. A frame every 2 ticks from the call.
--   LP_FILM_SIM=<the profile's dir> scripts/film.sh original-rich-trailer-seed3-saveat9-saveat16-saveat19-saveat38 t19.zip \
--     docs/trailer/clip-landing.lua      then scripts/clip.sh docs/sim/film-clip-landing media/trailer/landing-fx.mp4
local T0 = 12044000
local shots = {}
-- (Re-made at 0.2.320: a second Kessler-Hayashi fortress landed at -11,-647 at minute 7, and Grubstake, settlement 3 now,
-- comes down at 536,-613, 291 ticks after the call; framed on it as before, a tile east and six south of its lander.)
local AT, FROM, TO, EVERY = {537, -607}, 60, 900, 2
for dt = FROM, TO, EVERY do
  shots[#shots + 1] = {name = string.format("f-%05d", dt), tick = T0 + dt, pos = AT, zoom = 0.4, daytime = 0.15}
end
return {name = "clip-landing", base = 3, resolution = {1280, 720}, anti_alias = false, speed = 8, fast_until = T0 - 200,
  dev = {{tick = T0, args = {"land", "grubstake", "654"}, at = {0, 0}}}, shots = shots}
