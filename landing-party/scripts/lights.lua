-- The corporations' rendered buildings at night (the user, 2026-11-04, on the gallery: only the dome projector lit its
-- ground; the rest vanished in the dark). Radars and simple entities have no light of their own: one drawn on each, in its
-- corporation's lamp colour, goes with it. Where its glow is (offset, tiles), how big and how bright.
local shared = require("__landing-party__.shared")
local lights = {}

local KINDS = {
  ["lp-dome-projector"] = {offset = {0, -0.5}, scale = 1.6, intensity = 0.55},
  ["lp-jammer"]         = {offset = {0, -0.5}, scale = 1.0, intensity = 0.45},
  ["lp-orbital-relay"]  = {offset = {0, -0.3}, scale = 1.0, intensity = 0.45},
  ["lp-pacifier"]       = {offset = {0, -0.6}, scale = 1.5, intensity = 0.55},
  ["lp-uplink"]         = {offset = {0, 0}, scale = 2.2, intensity = 0.5},
}
lights.KINDS = KINDS

function lights.attach(ent, corp)
  if not (ent and ent.valid) then return end
  local k = KINDS[shared.kind_of(ent.name)] or KINDS[ent.name]
  if not k then return end
  if not corp then
    for name, cp in pairs(shared.CORPS) do if cp.force == ent.force.name then corp = name end end
  end
  local c = corp and shared.CORPS[corp] and shared.CORPS[corp].lamp or {r = 0.85, g = 0.95, b = 1}
  rendering.draw_light{sprite = "utility/light_medium", target = {entity = ent, offset = k.offset}, surface = ent.surface,
    scale = k.scale, intensity = k.intensity, color = c, minimum_darkness = 0.3}
end

return lights
