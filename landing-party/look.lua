-- Each corporation's look beyond colour (docs/corporations.md): its floors (road and pad tiles, vanilla tiles
-- copied and tinted) and the tiles of its logo mosaic (vanilla coloured concrete, unminable copies).
local shared = require("shared")

local out = {}
for corp, c in pairs(shared.CORPS) do
  for _, floor in ipairs({"road", "pad"}) do
    local name = shared.variant(corp, "lp-" .. floor)
    if data.raw.tile[name] then
      data.raw.tile[name].tint = c[floor].tint
    else
      local t = table.deepcopy(data.raw.tile[c[floor].tile])
      t.name = name
      t.minable = nil
      t.placeable_by = nil
      if c[floor].tint then t.tint = c[floor].tint end
      t.localised_name = {"", c.name, " ", floor}
      table.insert(out, t)
    end
  end
end
for letter, tile in pairs(shared.MOSAIC) do
  local t = table.deepcopy(data.raw.tile[tile])
  t.name = "lp-mosaic-" .. letter
  t.minable = nil
  t.placeable_by = nil
  table.insert(out, t)
end
data:extend(out)
