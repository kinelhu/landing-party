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
      local base = find(kind)
      if base then
        local p = table.deepcopy(base)
        p.name = shared.variant(corp, kind)
        p.localised_name = {"", {"entity-name." .. kind}, " (", c.name, ")"}
        retint(p, c.tint, {})
        if kind == "lp-lamp" and p.light then p.light.color = c.lamp end
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
data:extend(out)
