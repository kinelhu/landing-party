-- The manual's Synthexis stills at the user's own wall (nwa's north wall; a wave of 200 with 30 big bursters and 30
-- cinders sent at minute 12; its beats in docs/trailer/reel-nwwall.lua): by full day and close on the breach, from the
-- breach order (wave:breach) to the flood past the gap, and on the first burster's wind-up (burst:first).
--   scripts/film.sh nwa-nwwallheavy-saveat13 t13.zip docs/manual/shots/m-nwwall.lua docs/sim/film-m-nwwall
local shots = {}
local D = 0.02
for dt = 0, 1050, 30 do
  shots[#shots + 1] = {name = string.format("breach-z10-%04d", dt), after = "wave:breach", dt = dt, pos = "breach", zoom = 1.0,
    daytime = D, hide_clouds = true, freeze = "b"}
end
for dt = 0, 1050, 90 do
  shots[#shots + 1] = {name = string.format("breach-z06-%04d", dt), after = "wave:breach", dt = dt + 1, pos = "breach", off = {0, 6},
    zoom = 0.6, daytime = D, hide_clouds = true, freeze = "b"}
end
for dt = 0, 72, 6 do
  shots[#shots + 1] = {name = string.format("burst-%03d", dt), after = "burst:first", dt = dt, pos = "burst", zoom = 1.8,
    daytime = D, hide_clouds = true, freeze = "u"}
end
-- (The settlements' trace labels, made in the save: hidden.)
local function each()
  if storage.labels_hidden then return end
  for _, o in pairs(rendering.get_all_objects("landing-party")) do
    if o.valid and o.type == "text" and tostring(o.text):find("|", 1, true) then o.visible = false end
  end
  storage.labels_hidden = true
end
return {name = "m-nwwall", base = 1, waves = true, bursts = true, resolution = {2560, 1440}, anti_alias = true, speed = 8,
  fast_until = "wave:march", each = each, shots = shots}
