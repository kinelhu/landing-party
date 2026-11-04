-- A drop siege on the fortress (fortress 12345's fork at minute 14, its siege forced at 14 by its harness): its guns
-- assembled where their pods land (0.2.197), its barrage, its assault in ranks. Aimed at its escort's centre.
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh fortress-film fork.zip docs/trailer/stills-assault.lua
local shots = {}
local function at(name, after, dt, zoom)
  shots[#shots + 1] = {name = name, after = after, dt = dt, pos = "escort", zoom = zoom or 0.7, daytime = 0.1}
end
at("1-deploy-pods", "phase:deploy", 420)
at("2-deploy-assembling", "phase:deploy", 900)
at("3-deploy-late", "phase:deploy", 1650)
at("4-bombard", "phase:bombard", 300, 0.55)
for k, dt in ipairs({0, 60, 120, 180, 240, 300, 420, 600}) do at(string.format("5-assault-%d", k), "phase:assault", dt) end
return {name = "assault", base = "siege", resolution = {1280, 720}, anti_alias = false, stop_after = 20 * 3600, shots = shots}
