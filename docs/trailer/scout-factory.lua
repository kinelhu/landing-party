-- Scouting the factory for the cold open (shot 1) and the end card (14): a grid of candidate framings on nw (its visit
-- copy, no corporation yet), by day, a still each. scripts/film.sh nw-rich-l165-seed1 visit.zip docs/trailer/scout-factory.lua
local shots, k = {}, 0
for gy = -300, 300, 150 do
  for gx = -300, 300, 150 do
    k = k + 1
    shots[#shots + 1] = {name = string.format("%02d_%d_%d", k, gx, gy), tick = nil, at_load = 120 + k * 3, pos = {gx, gy},
      zoom = 0.35, daytime = 0.08}
  end
end
return {name = "scout-factory", shots = shots, relative = true, resolution = {1280, 720}}
