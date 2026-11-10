-- The modelled combinators' wire posts checked (tools/blender/player_buildings.py projects them): the rally beacon and the
-- threat scanner in their four directions, a row each, red and green wires strung along each row.
--   scripts/film.sh gallery fresh.zip docs/release/wires-film.lua <out>
local DIRS = {defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west}
local build, shots = {}, {}
for r, name in ipairs({"lp-rally-beacon", "lp-threat-scanner"}) do
  for k, d in ipairs(DIRS) do
    build[#build + 1] = {name = name, force = "player", pos = {(k - 1) * 3, (r - 1) * 4}, dir = d, ground = "lab-dark-2", ground_r = 2}
  end
end
shots[#shots + 1] = {name = "wires", tick = 400, pos = {4.5, 2}, zoom = 3.2, daytime = 0, hide_clouds = true}
shots[#shots + 1] = {name = "wires-close", tick = 402, pos = {1.5, 0}, zoom = 6, daytime = 0, hide_clouds = true}
local wired = false
local function wire()
  if wired then return end
  local list = storage.built or {}
  for i = 1, #list - 1 do
    local a, b = list[i], list[i + 1]
    if a.valid and b.valid and a.name == b.name then
      for _, id in ipairs({defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green}) do
        a.get_wire_connector(id, true).connect_to(b.get_wire_connector(id, true))
      end
    end
  end
  wired = true
end
return {name = "wires", pad = {-6, -6, 14, 10}, tile = "lab-dark-2", build = build, shots = shots, resolution = {1600, 1000},
  each = function(tick) wire() end}
