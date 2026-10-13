-- Each corporation's look beyond colour (docs/corporations.md): its floors (road and pad tiles, vanilla tiles
-- copied and tinted) and its logo (a decal on the ground: vanilla icons layered on a disc, tinted).
local shared = require("shared")

local out = {}
for corp, c in pairs(shared.CORPS) do
  for _, floor in ipairs({"road", "pad"}) do
    local name = shared.variant(corp, "lp-" .. floor)
    if not data.raw.tile[name] then
      local t = table.deepcopy(data.raw.tile[c[floor].tile])
      t.name = name
      t.minable = nil
      t.placeable_by = nil
      if c[floor].tint then t.tint = c[floor].tint end
      t.localised_name = {"", c.name, " ", floor}
      table.insert(out, t)
    end
  end
  local layers = {}
  for _, l in ipairs(c.logo) do
    table.insert(layers, {filename = l[1], size = 64, scale = l[2], tint = l[3]})
  end
  table.insert(out, {
    type = "simple-entity-with-owner", name = shared.variant(corp, "lp-logo"), hidden = true,
    localised_name = c.name,
    icon = c.logo[2][1], icon_size = 64,
    flags = {"placeable-neutral", "placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable",
      "not-flammable"},
    selectable_in_game = false,
    collision_mask = {layers = {}},
    collision_box = {{-0.4, -0.4}, {0.4, 0.4}},
    max_health = 1000,
    render_layer = "decals",
    picture = {layers = layers},
  })
end
data:extend(out)
