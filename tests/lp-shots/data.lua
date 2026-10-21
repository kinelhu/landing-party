-- Mockups for the unit design sheet (scene 15, the user, 2026-10-21: "think about how we differentiate them visually ...
-- maybe we will need some sprite collage"): candidate looks for units not yet built, each a vanilla hull with another
-- machine's turning head on it, tinted in its corporation's colour. Only in the screenshot profile: never in the mod.
local SER, GRUB = {r = 0.62, g = 0.8, b = 1, a = 1}, {r = 1, g = 0.72, b = 0.38, a = 1}

local function layers_of(a)
  if a.layers then return a.layers end
  return {a}
end

-- A head's layers, scaled and moved, repeated to the hull's two frames, in the colour given (its masks take the colour,
-- the art keeps its own, as the mod's units do).
local function head(src, k, dx, dy, color, base)
  local out = {}
  for _, l in ipairs(layers_of(table.deepcopy(src))) do
    l.scale = (l.scale or 1) * k
    local s = l.shift or {0, 0}
    l.shift = {s[1] * k + dx, s[2] * k + dy}
    l.frame_count, l.repeat_count = 1, 2
    l.line_length = l.line_length or 8
    if l.apply_runtime_tint then l.apply_runtime_tint = false; l.tint = color end
    -- The hull's pace (layers of one animation must advance alike).
    l.animation_speed, l.max_advance = base.animation_speed, base.max_advance
    table.insert(out, l)
  end
  return out
end

local function hull(src, color)
  local out = {}
  for _, l in ipairs(layers_of(table.deepcopy(src))) do
    if l.apply_runtime_tint then l.apply_runtime_tint = false; l.tint = color end
    table.insert(out, l)
  end
  return out
end

local tank, car = data.raw.car.tank, data.raw.car.car
local laser = data.raw["electric-turret"]["laser-turret"].prepared_animation
local flamer = data.raw["fluid-turret"]["flamethrower-turret"].prepared_animation.north
local tesla = data.raw["electric-turret"]["tesla-turret"] and data.raw["electric-turret"]["tesla-turret"].prepared_animation
local radar = data.raw.radar.radar.pictures

local CANDIDATES = {
  {"mock-tank-turret", tank.animation, {{tank.turret_animation, 1, 0, 0}}, SER, "lp-tank",
    "Today's tank with its own cannon turret on (the units have only the hull)"},
  {"mock-scorcher-a", car.animation, {{flamer, 0.75, 0, -0.1}}, GRUB, "lp-hauler",
    "Scorcher A: the truck with a flamethrower head"},
  {"mock-scorcher-b", tank.animation, {{flamer, 0.95, 0, -0.2}}, GRUB, "lp-tank", "Scorcher B: a tank hull, flamethrower head"},
  {"mock-prism-a", tank.animation, {{laser, 0.8, 0, -0.3}}, SER, "lp-tank", "Prism A: tank hull, laser head"},
  {"mock-prism-b", tank.animation, {{tank.turret_animation, 1, 0, 0}, {laser, 0.5, 0, -1.0}}, SER, "lp-tank",
    "Prism B: tank with its turret, a small laser head on top"},
  {"mock-shield-a", car.animation, {{radar, 0.45, 0, -0.4}}, SER, "lp-hauler",
    "Shield truck: the truck with a radar dish (its bubble drawn by script)"},
}
if tesla then
  table.insert(CANDIDATES, {"mock-tesla-a", tank.animation, {{tesla, 0.6, 0, 0.9}}, SER, "lp-tank",
    "Tesla A: tank hull, tesla head"})
  table.insert(CANDIDATES, {"mock-tesla-b", car.animation, {{tesla, 0.45, 0, 0.6}}, SER, "lp-hauler",
    "Tesla B: the truck, tesla head"})
end

local out = {}
for _, c in ipairs(CANDIDATES) do
  local u = table.deepcopy(data.raw.unit[c[5]])
  u.name = c[1]
  u.localised_name = c[6]
  local layers = hull(c[2], c[4])
  for _, h in ipairs(c[3]) do
    for _, l in ipairs(head(h[1], h[2], h[3], h[4], c[4], layers[1])) do table.insert(layers, l) end
  end
  u.run_animation = {layers = layers}
  u.attack_parameters.animation = {layers = table.deepcopy(layers)}
  table.insert(out, u)
end
data:extend(out)

-- The shield's own look (scripts/make_shield.py): its dome and a hit's ripple, drawn additively.
data:extend({
  {type = "animation", name = "mock-shield-dome", filename = "__landing-party__/graphics/shield/shield-dome.png",
    width = 320, height = 320, frame_count = 16, line_length = 4, scale = 0.8, animation_speed = 0.25,
    blend_mode = "additive", draw_as_glow = true},
  {type = "animation", name = "mock-shield-flash", filename = "__landing-party__/graphics/shield/shield-flash.png",
    width = 320, height = 320, frame_count = 8, line_length = 4, scale = 0.8, animation_speed = 0.2,
    blend_mode = "additive", draw_as_glow = true},
  {type = "animation", name = "mock-shield-hit", filename = "__landing-party__/graphics/shield/shield-hit.png",
    width = 256, height = 256, frame_count = 12, line_length = 4, scale = 0.35, animation_speed = 0.5,
    blend_mode = "additive", draw_as_glow = true},
})
