-- Scouting the army's battle at the Grubstake camp in the trailer fork at 0.2.338 (the user, 2026-11-12: "a kinda
-- underwhelming attack compared to previous versions", "shot a little too low"): wide stills every 100 ticks from the
-- army's march to after its fight, the army's point logged, to time and place m3 and m4.
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh trailer-film fork.zip docs/trailer/scout-battle.lua
local shots = {}
for k = 0, 27 do
  shots[#shots + 1] = {name = string.format("b-%02d", k), tick = 39800 + k * 100, pos = {385, -150}, zoom = 0.35, daytime = 0.22}
  shots[#shots + 1] = {name = string.format("a-%02d", k), tick = 39801 + k * 100, pos = "army", zoom = 0.35, daytime = 0.22}
end
return {name = "scout-battle", base = 1, army = true, waves = true, resolution = {1920, 1080}, speed = 8,
  fast_until = 39700, shots = shots}
