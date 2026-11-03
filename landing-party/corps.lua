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
        p.localised_description = {"?", {"entity-description." .. kind}, ""}
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
local function repoint(t, files, seen)
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if type(t.filename) == "string" and files[t.filename] then
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
