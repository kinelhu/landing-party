-- The manual's Synthexis culture: farm 12345's young culture from its fork at minute 10 (scripts/film_fork.sh farm 12345
-- 16; scouted by docs/trailer/scout-young.lua: its incubators round 1000,-4, its clinic by 1004,27), by full day: the
-- culture whole and close (the plan), its clinic and heating tower, its creep's edge. What stands round it is logged to
-- script-output/factorio-film/probe-culture.txt for the callouts.
--   LP_FILM_SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-farm-12345-16" \
--     scripts/film.sh farm-film fork.zip docs/manual/shots/m-culture.lua docs/sim/film-m-culture
local C = {1000, 6}
local shots = {}
local function s(name, at, pos, zoom)
  shots[#shots + 1] = {name = name, at_load = at, pos = pos, zoom = zoom, daytime = 0.02, hide_clouds = true}
end
s("culture-z06", 300, C, 0.6)
s("culture-z09", 302, C, 0.9)
s("culture-z12", 304, {1000, -2}, 1.2)
s("clinic-z15", 306, {1004, 27}, 1.5)
s("culture-z12-late", 1800, {1000, -2}, 1.2)
s("culture-z09-late", 1802, C, 0.9)
local done = false
local function each()
  if not storage.labels_hidden then
    for _, o in pairs(rendering.get_all_objects("landing-party")) do
      if o.valid and o.type == "text" and tostring(o.text):find("|", 1, true) then o.visible = false end
    end
    storage.labels_hidden = true
  end
  if done then return end
  local lines = {}
  for _, e in ipairs(game.surfaces[1].find_entities_filtered{area = {{C[1] - 60, C[2] - 60}, {C[1] + 60, C[2] + 60}}}) do
    if e.force.name ~= "neutral" then
      lines[#lines + 1] = string.format("%s %s %s %.1f,%.1f", e.force.name, e.type, e.name, e.position.x, e.position.y)
    end
  end
  -- The creep's tiles: their extent, for its edge.
  local n = game.surfaces[1].count_tiles_filtered{area = {{C[1] - 60, C[2] - 60}, {C[1] + 60, C[2] + 60}}, name = "lp-creep"}
  lines[#lines + 1] = "creep tiles " .. n
  helpers.write_file("factorio-film/probe-culture.txt", table.concat(lines, "\n") .. "\n")
  done = true
end
return {name = "m-culture", resolution = {2560, 1440}, anti_alias = true, speed = 4, lapse = {{from = 0, to = 10000000, speed = 4}},
  each = each, shots = shots}
