-- LP_AIR=pass (a measurement, 2026-11-08: the user, of the fliers, "the fact they don't collide with each other was
-- bothering me"): the fliers as they were to 0.2.239, passing through each other (not_colliding_with_itself), for
-- scenario airspace to set against the shipped mask (they collide). The run's params.lua is the test mod's own file, so
-- the data stage reads it.
local ok, params = pcall(require, "params")
if ok and params.air == "pass" then
  local n = 0
  for _, u in pairs(data.raw.unit) do
    local m = u.collision_mask
    if m and m.layers and m.layers["lp-air"] then
      m.not_colliding_with_itself = true
      n = n + 1
    end
  end
  log("lp-sim: LP_AIR=pass, " .. n .. " fliers pass through each other")
end
-- LP_AIR=nosep: colliding, without the engine's separation (it nudges units apart; colliding fliers fired less).
if ok and params.air == "nosep" then
  for _, u in pairs(data.raw.unit) do
    local m = u.collision_mask
    if m and m.layers and m.layers["lp-air"] and u.ai_settings then u.ai_settings.do_separation = false end
  end
  log("lp-sim: LP_AIR=nosep")
end
