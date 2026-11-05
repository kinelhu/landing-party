-- The manual's Kessler-Hayashi stills at the user's own wall (nw's south wall; the armed camp landed at -99,566; its
-- beats in docs/trailer/reel-khwall.lua): by full day and close. Its camp at load (an armed camp, era 4: the plan), its
-- drop siege's pods and guns (phase:deploy), the siege in place (phase:bombard: the plan), the strike's paint, shadow and
-- fall (paint, falling: the strip and the hero), the assault through the bastion's breach. Positions round the camp and
-- the siege are logged to script-output/factorio-film/probe-<what>.txt for the callouts.
--   scripts/film.sh nw-khwall-saveat15 t15.zip docs/manual/shots/m-khwall.lua docs/sim/film-m-khwall
local shots = {}
local D = 0.02
local function s(name, t, pos, zoom) t.name, t.pos, t.zoom, t.daytime, t.hide_clouds = name, pos, zoom, D, true; shots[#shots + 1] = t end
-- The camp at load.
local CAMP = {-99, 566}
s("camp-z045", {at_load = 60}, CAMP, 0.45)
s("camp-z07", {at_load = 62}, CAMP, 0.7)
for k, o in ipairs({{-30, -20}, {30, -20}, {-30, 20}, {30, 20}}) do
  s("camp-z1-" .. k, {at_load = 62 + k * 2}, {CAMP[1] + o[1], CAMP[2] + o[2]}, 1.0)
end
for dt = 0, 640, 40 do s(string.format("deploy-%03d", dt), {after = "phase:deploy", dt = dt}, {-134, 376}, 1.3) end
for _, dt in ipairs({60, 600, 1200}) do
  s(string.format("siege-z09-%04d", dt), {after = "phase:bombard", dt = dt}, {-136, 368}, 0.9)
  s(string.format("siege-z13-%04d", dt), {after = "phase:bombard", dt = dt + 1}, {-136, 372}, 1.3)
end
for dt = 0, 750, 25 do s(string.format("paint-%03d", dt), {after = "paint", dt = dt}, {-142, 338}, 0.9) end
for dt = 0, 240, 10 do s(string.format("fall-%03d", dt), {after = "falling", dt = dt}, {-142, 335}, 0.9) end
for dt = 60, 700, 80 do s(string.format("assault-%03d", dt), {after = "phase:assault", dt = dt}, {-142, 345}, 1.1) end
local done = {}
local function probe(name, c, r)
  local lines = {}
  for _, e in ipairs(game.surfaces[1].find_entities_filtered{area = {{c[1] - r, c[2] - r}, {c[1] + r, c[2] + r}}}) do
    if e.force.name ~= "neutral" and e.type ~= "transport-belt" and e.type ~= "pipe" then
      lines[#lines + 1] = string.format("%s %s %s %.1f,%.1f", e.force.name, e.type, e.name, e.position.x, e.position.y)
    end
  end
  helpers.write_file("factorio-film/probe-" .. name .. ".txt", table.concat(lines, "\n") .. "\n")
  done[name] = true
end
local function each(tick)
  if not done.camp then probe("camp", CAMP, 110) end
  local seen = storage.seen or {}
  if seen["phase:bombard"] and not done.siege and tick >= seen["phase:bombard"] + 120 then probe("siege", {-136, 370}, 50) end
  if seen["paint"] and not done.paint and tick >= seen["paint"] + 60 then probe("paint", {-142, 338}, 50) end
end
return {name = "m-khwall", base = 1, resolution = {2560, 1440}, anti_alias = true, speed = 8, fast_until = "phase:deploy",
  each = each, shots = shots}
