-- A burst's look (scripts/burstfx.lua; the user, 2026-11-05, watching the trailer: "I almost feel like the burster is
-- underwhelming graphically compared to its usefulness"). All of it drawn by script (rendering), never an entity nor a
-- particle: those are made by the engine on the game's dice, and with them fights elsewhere turned out otherwise (descent.lua,
-- the landing's look). Copied from the base game:
--   the nuke's shockwave puff (atomic-nuke-shockwave), thrown outward in acid green,
--   the biters' guts (guts-entrails-particle-big's sheet, its first variation), the gibs it throws,
--   a spitter's acid splash (acid-splash-fire-spitter-behemoth's four pictures) and, as the pool it leaves, each one's
--   last frame as a sprite,
--   the light's soft disc as a sprite (its swelling glow), and the acid's burn sounds (its hiss and sizzle).
local shared = require("shared")
local FX = shared.BURSTFX

local function first(a) return a and (a[1] or a) end

local wave = table.deepcopy(first(data.raw.explosion["atomic-nuke-shockwave"].animations))
wave.type, wave.name = "animation", FX.wave
wave.usage, wave.flags = nil, nil
assert(wave.frame_count == FX.frames.wave, "atomic-nuke-shockwave: its frames are not shared.BURSTFX's")
data:extend({wave})

local guts = data.raw["optimized-particle"]["guts-entrails-particle-big"].pictures.sheet
assert(guts.frame_count == FX.frames.gib, "guts-entrails-particle-big: its frames are not shared.BURSTFX's")
data:extend({{type = "animation", name = FX.gib, filename = guts.filename, width = guts.width, height = guts.height,
  frame_count = guts.frame_count, line_length = guts.frame_count, shift = guts.shift, scale = guts.scale}})

local fire = data.raw.fire["acid-splash-fire-spitter-behemoth"]
assert(#fire.pictures >= FX.splashes, "acid-splash-fire-spitter-behemoth: fewer pictures than shared.BURSTFX.splashes")
for i = 1, FX.splashes do
  local l = table.deepcopy(fire.pictures[i].layers[1])
  assert(l.frame_count == FX.frames.splash[i], "acid splash " .. i .. ": its frames are not shared.BURSTFX's")
  l.type, l.name, l.tint = "animation", FX.splash .. i, nil
  data:extend({l})
  local last = l.frame_count - 1
  data:extend({{type = "sprite", name = FX.pool .. i, filename = l.filename, width = l.width, height = l.height,
    x = (last % l.line_length) * l.width, y = math.floor(last / l.line_length) * l.height, shift = l.shift, scale = l.scale,
    draw_as_glow = l.draw_as_glow}})
end

data:extend({
  {type = "sprite", name = FX.glow, filename = "__core__/graphics/light-medium.png", width = 300, height = 300, scale = 0.5,
    blend_mode = "additive"},
  {type = "sound", name = FX.hiss, filename = "__base__/sound/creatures/projectile-acid-burn-long-1.ogg", volume = 0.9,
    aggregation = {max_count = 4, remove = true, count_already_playing = true}},
  -- (One variation each, as the landing's: nothing here draws on the game's dice.)
  {type = "sound", name = FX.sizzle, filename = "__base__/sound/creatures/projectile-acid-burn-long-2.ogg", volume = 0.8,
    aggregation = {max_count = 3, remove = true, count_already_playing = true}},
})
