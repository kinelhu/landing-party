-- The manual's landing strip: Grubstake forced down on the trailer visit's save at minute 19 (/lp land grubstake 654, as
-- docs/trailer/clip-landing.lua: its lander at -3,-690, down about 470 ticks after the call), by full day and closer:
-- the pod, the hull's shadow and fall, the crash, its six pods. A still every 10 ticks from the call.
--   LP_FILM_SIM=<the profile's dir> scripts/film.sh original-rich-trailer-seed3-saveat9-saveat16-saveat19-saveat38 t19.zip \
--     docs/manual/shots/m-landing.lua docs/sim/film-m-landing
local T0 = 12044000
local shots = {}
for dt = 40, 1400, 10 do
  shots[#shots + 1] = {name = string.format("land-%05d", dt), tick = T0 + dt, pos = {-2, -686}, zoom = 1.0, daytime = 0.02,
    hide_clouds = true}
end
local function each()
  if storage.labels_hidden then return end
  for _, o in pairs(rendering.get_all_objects("landing-party")) do
    if o.valid and o.type == "text" and tostring(o.text):find("|", 1, true) then o.visible = false end
  end
  storage.labels_hidden = true
end
return {name = "m-landing", base = 2, resolution = {2560, 1440}, anti_alias = true, speed = 8, fast_until = T0 - 200,
  dev = {{tick = T0, args = {"land", "grubstake", "654"}, at = {0, 0}}}, each = each, shots = shots}
