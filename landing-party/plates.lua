-- Plated units (corporate research, scripts/rd.lua): for every corporation, a copy of each unit kind per plate, more
-- health and the plate's resistance (shared.PLATES). A plate is a prototype because health and resistances cannot
-- change at runtime; the depots build the plated kind once its corporation has bought the plate.
local shared = require("shared")

local out = {}
for corp in pairs(shared.CORPS) do
  for _, kind in ipairs(shared.PLATED) do
    local name = shared.variant(corp, kind)
    local base = data.raw.unit[name] or data.raw["spider-unit"][name]
    if base then
      for plate, r in pairs(shared.PLATES) do
        local p = table.deepcopy(base)
        p.name = shared.plated(corp, kind, plate)
        p.max_health = math.floor(base.max_health * shared.PLATE_HEALTH)
        local res, merged = {}, false
        for _, x in ipairs(base.resistances or {}) do
          if x.type == r.type then
            table.insert(res, {type = x.type, percent = math.min(90, (x.percent or 0) + r.percent),
              decrease = (x.decrease or 0) + (r.decrease or 0)})
            merged = true
          else
            table.insert(res, table.deepcopy(x))
          end
        end
        if not merged then table.insert(res, {type = r.type, percent = r.percent, decrease = r.decrease}) end
        for _, a in ipairs(r.also or {}) do
          local found = false
          for _, x in ipairs(res) do
            if x.type == a.type then
              x.percent, x.decrease = math.min(90, (x.percent or 0) + (a.percent or 0)), (x.decrease or 0) + (a.decrease or 0)
              found = true
            end
          end
          if not found then table.insert(res, {type = a.type, percent = a.percent, decrease = a.decrease}) end
        end
        p.resistances = res
        p.localised_name = {"", base.localised_name or {"entity-name." .. kind}, " [", {"lp.plate-" .. plate}, "]"}
        p.localised_description = base.localised_description or {"?", {"entity-description." .. kind}, ""}
        table.insert(out, p)
      end
    end
  end
end
data:extend(out)
