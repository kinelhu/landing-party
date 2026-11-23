-- Squad colours (0.2.486) for the mod page's gallery: three rally beacons on three channels (D 1, 2, 3), each with its
-- squad of troopers and a vehicle, in alt mode, where each squad's units and beacon wear its channel's colour.
--   scripts/film.sh gallery fresh.zip docs/review/stills-squads.lua docs/sim/film-squads
local build = {}
local SQUADS = {{x = -14, d = 1, extra = "lp-battle-tank"}, {x = 0, d = 2, extra = "lp-gun-buggy"}, {x = 14, d = 3, extra = "lp-rocket-trooper"}}
for _, q in ipairs(SQUADS) do
  build[#build + 1] = {name = "lp-rally-beacon", force = "player", pos = {q.x + 0.5, -5.5}}
  build[#build + 1] = {name = "constant-combinator", force = "player", pos = {q.x - 1.5, -5.5}}
  for i = 0, 5 do
    build[#build + 1] = {name = "lp-trooper", force = "player", pos = {q.x - 3 + (i % 3) * 2.5, -1 + math.floor(i / 3) * 2.5}}
  end
  build[#build + 1] = {name = q.extra, force = "player", pos = {q.x, 5}}
end
-- Command relays and power, out of shot to the north (a unit past the bandwidth is offline and takes no beacon: without
-- them none wore its squad's colour); four relays, the research for eight, 40 slots for the squads' 32.
build[#build + 1] = {name = "electric-energy-interface", force = "player", pos = {0, -30}}
build[#build + 1] = {name = "substation", force = "player", pos = {0, -27}}
for k = 0, 3 do build[#build + 1] = {name = "lp-command-relay", force = "player", pos = {-6 + k * 4, -24}} end
local done = false
local function each(tick)
  if done or tick < 40 then return end
  done = true
  local s = game.surfaces[1]
  for k = 1, 2 do game.forces.player.technologies["lp-command-bandwidth-" .. k].researched = true end
  for _, q in ipairs(SQUADS) do
    local b = s.find_entities_filtered{name = "lp-rally-beacon", position = {q.x + 0.5, -5.5}, radius = 1}[1]
    local cc = s.find_entities_filtered{name = "constant-combinator", position = {q.x - 1.5, -5.5}, radius = 1}[1]
    if b and cc then
      cc.get_wire_connector(defines.wire_connector_id.circuit_red, true).connect_to(
        b.get_wire_connector(defines.wire_connector_id.circuit_red, true))
      cc.get_control_behavior().get_section(1).set_slot(1, {value = {type = "virtual", name = "signal-D", quality = "normal"}, min = q.d})
    end
    remote.call("landing-party", "debug_enlist", {{q.x - 5, -3}, {q.x + 5, 8}})
  end
end
local shots = {}
for k, t in ipairs({900, 1200, 1500}) do   -- (at 200 to 320 none had a squad yet: a unit takes its beacon on the planning pass)
  shots[#shots + 1] = {name = string.format("squads-%d", k), tick = t, pos = {0, 0}, zoom = 1.6, daytime = 0.05, alt = true}
end
shots[#shots + 1] = {name = "squads-plain", tick = 1510, pos = {0, 0}, zoom = 1.6, daytime = 0.05}
return {name = "squads", pad = {-24, -34, 24, 12}, tile = "grass-1", build = build, each = each, shots = shots,
  resolution = {1920, 1080}}
