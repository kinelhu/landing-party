-- The manual's Kessler-Hayashi camp plan: the armed camp at -99,566 on nw-khwall's save at minute 15 (docs/manual/shots/
-- m-khwall.lua filmed it with its lander's trace label showing: the label is hidden here first), by full day, whole and
-- by quarters. What stands in it is logged to script-output/factorio-film/probe-camp.txt (m-khwall's pass).
--   scripts/film.sh nw-khwall-saveat15 t15.zip docs/manual/shots/m-khcamp.lua docs/sim/film-m-khcamp
local CAMP = {-99, 566}
local shots = {}
local function s(name, at, pos, zoom)
  shots[#shots + 1] = {name = name, at_load = at, pos = pos, zoom = zoom, daytime = 0.02, hide_clouds = true}
end
s("camp-z06", 180, CAMP, 0.6)
s("camp-z08", 182, {CAMP[1], CAMP[2] + 2}, 0.8)
s("camp-z12", 184, CAMP, 1.2)
s("camp-z12-se", 186, {CAMP[1] + 30, CAMP[2] + 18}, 1.2)
local function each()
  if storage.labels_hidden then return end
  for _, o in pairs(rendering.get_all_objects("landing-party")) do
    if o.valid and o.type == "text" and tostring(o.text):find("|", 1, true) then o.visible = false end
  end
  storage.labels_hidden = true
end
return {name = "m-khcamp", base = 1, resolution = {2560, 1440}, anti_alias = true, speed = 1, stop_after = 400, each = each,
  shots = shots}
