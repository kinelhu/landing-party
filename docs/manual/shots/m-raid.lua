-- The manual's Grubstake raid: the trailer's fork (trailer 12345 at minute 8), a raid forced from the Grubstake camp at
-- 533,3 (base 5, /lp raid 5) on the player's structure nearest its barracks (261,-104, where the army musters from
-- 29400), tracked on its escort by full day. (Filmed 2026-11-05: the /lp call went out, but no raid left the camp and the
-- escort point stood still for the whole film; the Grubstake hero came from m-strip.lua instead. Kept as the record.)
--   LP_FILM_SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-trailer-12345-14" \
--     scripts/film.sh trailer-film fork.zip docs/manual/shots/m-raid.lua docs/sim/film-m-raid
local T0 = 29400
local shots = {}
for t = T0 + 300, T0 + 9000, 150 do
  shots[#shots + 1] = {name = string.format("raid-z12-%06d", t), tick = t, pos = "escort", zoom = 1.2, daytime = 0.02, hide_clouds = true}
  shots[#shots + 1] = {name = string.format("raid-z07-%06d", t + 1), tick = t + 1, pos = "escort", zoom = 0.7, daytime = 0.02,
    hide_clouds = true}
end
return {name = "m-raid", base = 5, resolution = {2560, 1440}, anti_alias = true, speed = 8,
  lapse = {{from = 0, to = T0, speed = 16}, {from = T0, to = T0 + 9100, speed = 4}},
  dev = {{tick = T0, args = {"raid", "5"}, at = {261, -104}}}, shots = shots}
