-- A landing's look (scripts/landfx.lua; the user, 2026-11-04, on the trailer's Grubstake landing: "the lack of animation is
-- a little jarring. Perhaps we could add some falling cargo pods dropping with the crashed lander?"). All of it is drawn by
-- script (rendering), never an entity: explosions and projectiles are entities the planner's free-ground test sees
-- (layout.area_free refuses whatever it cannot clear), and a landing's look must not move a hub.
--   each lander's hull falling on retro flames (its own picture and colours; its shadow left to the ground shadow),
--   that ground shadow (the crash-site ship's own),
--   a cargo pod on its thruster flame (Space Age's pod body),
--   the base game's big and massive explosions as animations, and their sound,
--   its scorch marks as sprites and the artillery smoke as an animation (dust).
local shared = require("shared")
local util = require("util")
local FX = shared.LANDFX
local POD = "__base__/graphics/entity/cargo-pod/"
local FRAMES = 10   -- the thruster loop's frames (pod-thruster-loop.png, 5 x 2)

local function flame(scale, shift)
  return {filename = POD .. "pod-thruster-loop.png", width = 172, height = 256, line_length = 5, frame_count = FRAMES,
    scale = scale, shift = shift, draw_as_glow = true, blend_mode = "additive"}
end

data:extend({{type = "animation", name = FX.pod, layers = {
  {filename = POD .. "pod-static-detached.png", width = 78, height = 172, shift = util.by_pixel(1, 3), scale = 0.5,
    frame_count = 1, repeat_count = FRAMES},
  flame(0.45, {0, 2.6})}}})

for _, name in ipairs(shared.variants("lp-lander")) do
  local lander = data.raw["electric-energy-interface"][name]
  local layers = {}
  for _, l in ipairs((lander and lander.picture and lander.picture.layers) or {}) do
    if not l.draw_as_shadow then
      local c = table.deepcopy(l)
      c.frame_count, c.repeat_count = 1, FRAMES
      layers[#layers + 1] = c
    end
  end
  for _, x in ipairs({-5, 0, 5}) do layers[#layers + 1] = flame(1.1, {x, 6.5}) end
  data:extend({{type = "animation", name = name .. FX.fall, layers = layers}})
end

data:extend({{type = "sprite", name = FX.shadow, filename = "__base__/graphics/entity/crash-site-spaceship/spaceship-shadow.png",
  width = 1340, height = 842, shift = util.by_pixel(-23, 50), scale = 0.5, flags = {"no-crop"}}})

-- The explosions' animations, copied from the base game's explosions (each its first variation).
local function first(a) return a and (a[1] or a) end
for key, ex in pairs({blast = "big-explosion", crash = "massive-explosion"}) do
  local a = table.deepcopy(first(data.raw.explosion[ex].animations))
  a.type, a.name = "animation", FX[key]
  a.usage = nil
  assert(a.frame_count == FX.frames[key] and a.animation_speed == FX.speed, ex .. ": its frames are not shared.LANDFX's")
  data:extend({a})
end
-- (One variation: nothing here draws on the game's dice.)
data:extend({{type = "sound", name = FX.sound, filename = "__base__/sound/fight/large-explosion-1.ogg", volume = 0.8,
  aggregation = {max_count = 3, remove = true, count_already_playing = true}}})
-- Scorch marks as sprites (the base game's, first variation): a scorch corpse is an entity, and making one shifted
-- fights elsewhere on the map (rail, herd: their outcomes turned with the look on, as they do with any change to the
-- game's dice). Dust as the artillery smoke's animation, for the same reason (trivial smoke and particles are made by
-- the engine).
local SCORCH = "__base__/graphics/entity/scorchmark/"
data:extend({
  {type = "sprite", name = FX.scorch_big, filename = SCORCH .. "big-scorchmark.png", width = 960, height = 704, scale = 0.5},
  {type = "sprite", name = FX.scorch, filename = SCORCH .. "medium-scorchmark.png", width = 510, height = 352, scale = 0.5}})
local dust = table.deepcopy(data.raw["trivial-smoke"]["artillery-smoke"].animation)
dust.type, dust.name = "animation", FX.dust
assert(dust.frame_count == FX.frames.dust, "artillery-smoke: its frames are not shared.LANDFX's")
data:extend({dust})
