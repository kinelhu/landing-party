-- Each corporation's own prototypes of the faction's kinds (shared.KINDS): copies of the default corporation's,
-- renamed (shared.variant) and drawn in the corporation's colour. Sprites tinted with the faction colour
-- (shared.TINT) take the corporation's; the walker's legs are copied with it. Lamps take its light.
local shared = require("shared")

local function same(a, b)
  return a and b and math.abs((a.r or a[1] or 0) - (b.r or 0)) < 0.01 and math.abs((a.g or a[2] or 0) - (b.g or 0)) < 0.01
    and math.abs((a.b or a[3] or 0) - (b.b or 0)) < 0.01
end
local function retint(t, color, seen)
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if t.tint and same(t.tint, shared.TINT) then t.tint = table.deepcopy(color) end
  for _, v in pairs(t) do retint(v, color, seen) end
end

local function find(name)
  for _, protos in pairs(data.raw) do
    if protos[name] then return protos[name] end
  end
end

local out = {}
for corp, c in pairs(shared.CORPS) do
  if corp ~= shared.DEFAULT_CORP then
    for _, kind in ipairs(shared.KINDS) do
      local base = find((c.bases and c.bases[kind]) or kind)
      if base then
        local p = table.deepcopy(base)
        for k, v in pairs((c.props and c.props[kind]) or {}) do p[k] = v end
        p.name = shared.variant(corp, kind)
        p.localised_name = {"", {"entity-name." .. ((c.names or {})[kind] or kind)}, " (", c.name, ")"}
        -- The kind's description where it has one (the copies showed none: Grubstake's harrier, pacifier, lander).
        -- (Its own name's description first where it has one: Grubstake's scrap copter on the harrier kind, whose own is
        -- Kessler-Hayashi's strike drone, the user, 2026-11-16: "KH is not a scrap copter is it?")
        local own = (c.names or {})[kind]
        p.localised_description = own and {"?", {"entity-description." .. own}, {"entity-description." .. kind}, ""}
          or {"?", {"entity-description." .. kind}, ""}
        retint(p, (c.tints and c.tints[kind]) or c.tint, {})
        if kind == "lp-lamp" and p.light then p.light.color = c.lamp end
        if kind == "lp-drill" and p.energy_source then p.energy_source.emissions_per_minute = {pollution = c.drill_pollution or 0} end
        if p.type == "spider-unit" and p.spider_engine then
          for _, leg in ipairs(p.spider_engine.legs) do
            local lp = table.deepcopy(data.raw["spider-leg"][leg.leg])
            lp.name = "lp-" .. corp .. "-" .. leg.leg:sub(4)
            retint(lp, c.tint, {})
            leg.leg = lp.name
            table.insert(out, lp)
          end
        end
        table.insert(out, p)
      end
    end
  end
end
-- The default corporation's own prototypes take its per-kind colours too (after the copies were made), and its
-- name (only the copies were labelled: Grubstake's units said whose they were, Serenity's did not).
local d = shared.CORPS[shared.DEFAULT_CORP]
for _, kind in ipairs(shared.KINDS) do
  local p = find(kind)
  if p and kind == "lp-drill" and p.energy_source then p.energy_source.emissions_per_minute = {pollution = d.drill_pollution or 0} end
  if p then p.localised_name = {"", {"entity-name." .. ((d.names or {})[kind] or kind)}, " (", d.name, ")"} end
end
for kind, color in pairs(d.tints or {}) do
  local p = find(kind)
  if p then retint(p, color, {}) end
end
data:extend(out)

-- Each corporation's own recoloured art (scripts/make_sprites.py; the user, 2026-10-14: "more refined recolored
-- sprites ... instead of just tinting the full thing"): every layer of its prototypes whose vanilla file has a recolour
-- in graphics/manifest.lua points at it and drops its whole-sprite tint. What has none keeps the tint.
local manifest = require("graphics.manifest")
local SHEETS_ALL = require("graphics.sheets")
local function sheet_key(f) return f:match("^__landing%-party__/graphics/(.+)/[a-z]+%.png$") end
local function repoint(t, files, seen)
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if type(t.filename) == "string" and files[t.filename] then
    -- A modelled sheet takes its own frame size and shift: each corporation's render crops its own (Grubstake's uplink
    -- re-rendered a pixel narrower than Kessler-Hayashi's, 0.2.321, and its frames ran off its sheet: the game held at
    -- a sprite error before loading a save).
    local from, to = SHEETS_ALL[sheet_key(t.filename)], SHEETS_ALL[sheet_key(files[t.filename])]
    if from and to and t.width == from.width and t.height == from.height then
      t.width, t.height = to.width, to.height
      if t.shift then t.shift = {to.shift[1], to.shift[2]} end
    end
    t.filename = files[t.filename]
    t.tint = nil
  end
  if type(t.filenames) == "table" then
    for i, f in ipairs(t.filenames) do
      if files[f] then t.filenames[i] = files[f]; t.tint = nil end
    end
  end
  for _, v in pairs(t) do repoint(v, files, seen) end
end
-- Buildings of the default corporation's alone, not kinds (no copy for another): repointed to its files too (the dome
-- projector, Space Age's tesla turret recoloured; outside the kinds its recolour was never applied).
local OWN = {"lp-dome-projector"}
do
  local files = manifest[shared.DEFAULT_CORP]
  for _, name in ipairs(OWN) do
    local p = files and find(name)
    if p then repoint(p, files, {}) end
  end
end
for corp in pairs(shared.CORPS) do
  local files = manifest[corp]
  if files then
    for _, kind in ipairs(shared.KINDS) do
      local p = find(shared.variant(corp, kind))
      if p and p.type ~= "unit" and p.type ~= "spider-unit" then repoint(p, files, {}) end
      -- A lab's busy animation (data.lua, drawn by base.lab_look): its own copy for each corporation, repointed.
      local busy = data.raw.animation[kind .. "-busy"]
      if busy then
        local name = shared.variant(corp, kind) .. "-busy"
        local a = name == busy.name and busy or table.deepcopy(busy)
        a.name = name
        repoint(a, files, {})
        if a ~= busy then data:extend({a}) end
      end
    end
  end
end

-- Each corporation's own models (tools/blender/faction_works.py; phase 2 of the graphics pass, the user, 2026-11-10: "I
-- still see some gross recolors. Why not use blender again?"; the landers alone keep their repaint): a kind with a sheet
-- under graphics/<corp>/<dir> (sheets.lua) draws it in place of the repainted vanilla art, each corporation its own build.
local SHEETS = require("graphics.sheets")
local function sheet_layer(key, file, extra)
  local S = SHEETS[key]
  local l = {filename = "__landing-party__/graphics/" .. key .. "/" .. file .. ".png", width = S.width, height = S.height,
    frame_count = S.frames, line_length = S.line_length, scale = 0.5, shift = S.shift}
  for k, v in pairs(extra or {}) do l[k] = v end
  return l
end
local MODELLED = {
  -- The fabricator: its working animation, its lights lit while it works.
  ["lp-fabricator"] = {dir = "fabricator", apply = function(p, key, corp)
    local lit = corp == "grubstake" and {r = 1, g = 0.7, b = 0.35} or {r = 0.5, g = 0.85, b = 1}
    p.graphics_set = {
      animation = {layers = {sheet_layer(key, "body", {animation_speed = 0.5}),
        sheet_layer(key, "shadow", {draw_as_shadow = true, animation_speed = 0.5})}},
      working_visualisations = {{fadeout = true, animation = sheet_layer(key, "glow", {draw_as_glow = true, blend_mode = "additive",
        animation_speed = 0.5}), light = {intensity = 0.5, size = 8, shift = {0, 0}, color = lit}}}}
  end},
  -- The generator: always running while the camp stands (an energy interface: one animation, its glow a layer of it).
  ["lp-generator"] = {dir = "generator", apply = function(p, key, corp)
    p.picture, p.pictures, p.animations = nil, nil, nil
    p.animation = {layers = {sheet_layer(key, "body", {animation_speed = 0.4}),
      sheet_layer(key, "glow", {draw_as_glow = true, blend_mode = "additive", animation_speed = 0.4}),
      sheet_layer(key, "shadow", {draw_as_shadow = true, animation_speed = 0.4})}}
    p.continuous_animation = true
    p.light = {intensity = 0.4, size = 6, color = corp == "grubstake" and {r = 1, g = 0.7, b = 0.35} or {r = 0.5, g = 0.85, b = 1}}
  end},
  -- The radar: its head turns, the sprite whole through its directions (a radar's pictures), its shadow with it.
  ["lp-radar"] = {dir = "radar", apply = function(p, key)
    local function turn(file, extra)
      local l = sheet_layer(key, file, extra)
      l.direction_count, l.frame_count = l.frame_count, nil
      return l
    end
    p.pictures = {layers = {turn("body"), turn("glow", {draw_as_glow = true, blend_mode = "additive"}),
      turn("shadow", {draw_as_shadow = true})}}
  end},
}
-- (A turret's state takes 1 / its speed ticks, whatever its animation's frames: its speeds left as vanilla's. From
-- 0.2.324 to 0.2.350 keep_timing divided them by the frames a one-frame head lost, on the guess that a state took frames
-- over speed: the modelled turrets then took five to fifteen times vanilla's time to deploy, Grubstake's gun turret
-- firing its first round 75 ticks after its target where vanilla's took 25; scenario turretmodel, 2026-11-12.)
-- Turrets: the base once, the head in 64 directions for every state (it does not rise out of the ground as vanilla's
-- laser turret does), its lights a glow layer of it.
local function turret(p, key)
  local function head(file, extra)
    local l = sheet_layer(key .. "/head", file, extra)
    l.direction_count, l.frame_count = l.frame_count, nil
    return l
  end
  local h = {layers = {head("body"), head("glow", {draw_as_glow = true, blend_mode = "additive"}),
    head("shadow", {draw_as_shadow = true})}}
  p.folded_animation, p.preparing_animation, p.prepared_animation, p.folding_animation = h, h, h, h
  if p.attacking_animation then p.attacking_animation = h end
  if p.type == "electric-turret" then p.energy_glow_animation = nil end
  local base = function(file, extra)
    local l = sheet_layer(key .. "/base", file, extra); l.frame_count, l.line_length = nil, nil; return l
  end
  p.graphics_set = {base_visualisation = {animation = {layers = {base("body"),
    base("glow", {draw_as_glow = true, blend_mode = "additive"}), base("shadow", {draw_as_shadow = true})}}}}
end
-- Drills: four directions, each its working animation (an Animation4Way). Grubstake's is the strip drill's gantry (the
-- player's strip drill is Grubstake's own, salvaged: tools/blender/turning_buildings.py).
local function drill(prefix)
  return function(p)
    local a = {}
    for _, d in ipairs({"north", "east", "south", "west"}) do
      local key = prefix .. "/" .. d
      a[d] = {layers = {sheet_layer(key, "body", {animation_speed = 0.5}),
        sheet_layer(key, "glow", {draw_as_glow = true, blend_mode = "additive", animation_speed = 0.5}),
        sheet_layer(key, "shadow", {draw_as_shadow = true, animation_speed = 0.5})}}
    end
    p.graphics_set = {animation = a}
    p.wet_mining_graphics_set = nil
  end
end
local DRILL_ART = {grubstake = "player/strip-drill", serenity = "serenity/drill"}
for corp, prefix in pairs(DRILL_ART) do
  local p = SHEETS[prefix .. "/north"] and find(shared.variant(corp, "lp-drill"))
  if p then drill(prefix)(p) end
end
-- The pylon: one direction, its wire points the model's insulator tips (posts.json, projected by faction_works.py).
MODELLED["lp-pylon"] = {dir = "pylon", apply = function(p, key)
  local function pic(file, extra)
    local l = sheet_layer(key, file, extra); l.direction_count, l.frame_count = 1, nil; return l
  end
  p.pictures = {layers = {pic("body"), pic("glow", {draw_as_glow = true, blend_mode = "additive"}), pic("shadow", {draw_as_shadow = true})}}
  p.connection_points = {table.deepcopy(SHEETS[key].posts)}
end}
-- The flamer: its base in four directions, its head in 64 for every base direction and state (an 8-way set of one head:
-- its pivot is the entity's centre).
MODELLED["lp-flamer"] = {dir = "flamer", head = true, apply = function(p, key)
  local function head(file, extra)
    local l = sheet_layer(key .. "/head", file, extra)
    l.direction_count, l.frame_count = l.frame_count, nil
    return l
  end
  local h = {layers = {head("body"), head("glow", {draw_as_glow = true, blend_mode = "additive"}), head("shadow", {draw_as_shadow = true})}}
  -- (Kessler-Hayashi's arc flamer is an electric turret: its animations take one head of 64 directions, not an 8-way
  -- set of it, 2026-11-11.)
  local eight = h
  if p.type == "fluid-turret" then
    eight = {}
    for _, d in ipairs({"north", "north_east", "east", "south_east", "south", "south_west", "west", "north_west"}) do eight[d] = h end
  end
  for _, k in ipairs({"folded_animation", "preparing_animation", "prepared_animation", "attacking_animation",
      "ending_attack_animation", "folding_animation"}) do
    if p[k] then p[k] = eight end
  end
  local four = {}
  for _, d in ipairs({"north", "east", "south", "west"}) do
    local function base(file, extra)
      local l = sheet_layer(key .. "/base-" .. d, file, extra); l.frame_count, l.line_length = nil, nil; return l
    end
    four[d] = {layers = {base("body"), base("glow", {draw_as_glow = true, blend_mode = "additive"}), base("shadow", {draw_as_shadow = true})}}
  end
  -- (A flamer with a forward arc, Grubstake's, turns its base the way it faces; the arc flamer's whole circle takes north's.
  -- Both electric turrets since 2026-11-11: the base's animation is an Animation4Way for any turret.)
  local arc = p.attack_parameters.turn_range and p.attack_parameters.turn_range < 1
  p.graphics_set = {base_visualisation = {animation = arc and four or four.north}}
end}
-- The depot and the launch pad: containers, one picture each (faction_works.py depot and launchpad: KH a sealed
-- landing pad and an electromagnetic launch tube, Grubstake a plated pad on drum stilts and a derrick over a pit).
local function still(p, key)
  local function pic(file, extra)
    local l = sheet_layer(key, file, extra); l.frame_count, l.line_length = nil, nil; return l
  end
  p.picture = {layers = {pic("body"), pic("glow", {draw_as_glow = true, blend_mode = "additive"}), pic("shadow", {draw_as_shadow = true})}}
end
MODELLED["lp-depot"] = {dir = "depot", apply = still}
MODELLED["lp-launchpad"] = {dir = "launchpad", apply = still}
MODELLED["lp-turret"] = {dir = "turret", head = true, apply = turret}
MODELLED["lp-gun-turret"] = {dir = "gun-turret", head = true, apply = turret}
for corp in pairs(shared.CORPS) do
  for kind, m in pairs(MODELLED) do
    local key = corp .. "/" .. m.dir
    local p = SHEETS[key .. (m.head and "/head" or "")] and find(shared.variant(corp, kind))
    if p then m.apply(p, key, corp) end
  end
end
