-- The mod's own icons (tools/icons/cut.py, graphics/icons/<name>.png, 64 px): each set on the item of that name, on the
-- entity it places, on a recipe of that name, and an order's on its unit too (the user, 2026-11-10: every item, recipe
-- and technology reused a vanilla icon; "Do all"). Read last (data-final-fixes), so no file's own icon wins over it.
-- An icon whose prototype is gone is an error: the list and the prototypes kept in step.
local ITEM_TYPES = {"item", "item-with-entity-data", "capsule", "ammo", "gun", "tool", "selection-tool"}
local ORDERS = {["lp-trooper-order"] = "lp-trooper", ["lp-breacher-order"] = "lp-breacher",
  ["lp-rocket-trooper-order"] = "lp-rocket-trooper", ["lp-flame-trooper-order"] = "lp-flame-trooper",
  ["lp-battle-tank-order"] = "lp-battle-tank"}
local NAMES = {"lp-bait", "lp-barracks", "lp-battle-tank-order", "lp-beacon-schematic", "lp-border-stake", "lp-breacher-order",
  "lp-claim-marker", "lp-cluster-artillery-shell", "lp-cluster-fuze", "lp-coil-schematic", "lp-command-core", "lp-command-relay",
  "lp-crystal-schematic", "lp-defoliant", "lp-drill-head", "lp-flak-turret", "lp-flame-trooper-order", "lp-fuze-schematic",
  "lp-gland-schematic", "lp-mortar-shell", "lp-muster-point", "lp-orbital-beacon", "lp-orbital-cannon", "lp-orbital-shell",
  "lp-pacifier-crystal", "lp-pact-breaker", "lp-pheromone-gland", "lp-player-dome", "lp-player-mortar", "lp-rail-coil",
  "lp-rail-rifle", "lp-rail-slug", "lp-rally-beacon", "lp-rocket-trooper-order", "lp-strike-beacon", "lp-strip-drill",
  "lp-targeting-array", "lp-targeting-core", "lp-threat-scanner", "lp-trade-post", "lp-trooper-order"}
local function set(p, file)
  p.icon, p.icon_size, p.icons = file, 64, nil
end
for _, name in ipairs(NAMES) do
  local file = "__landing-party__/graphics/icons/" .. name .. ".png"
  local item
  for _, ty in ipairs(ITEM_TYPES) do item = item or (data.raw[ty] and data.raw[ty][name]) end
  assert(item, "icons.lua: no item " .. name)
  set(item, file)
  if data.raw.recipe[name] then set(data.raw.recipe[name], file) end
  local placed = item.place_result or ORDERS[name]
  if placed then
    for _, protos in pairs(data.raw) do
      if protos[placed] and protos[placed].collision_box then set(protos[placed], file) end
    end
  end
end

-- The technologies' (tools/icons/techs.py, graphics/technology/<name>.png, 256 px).
local TECHS = {"lp-player-dome", "lp-command-bandwidth-1", "lp-command-bandwidth-2", "lp-command-bandwidth-3",
  "lp-command-bandwidth-4", "lp-prize-serenity", "lp-prize-grubstake", "lp-pheromone-bait", "lp-pact-breaker", "lp-claim-marker",
  "lp-rail-rifle", "lp-orbital-strike", "lp-cluster-shells", "lp-orbital-cannon", "lp-study-claims", "lp-claims-register",
  "lp-study-strip", "lp-strip-drill", "lp-study-bait", "lp-bait-made", "lp-study-flak", "lp-flak-turret", "lp-study-telemetry",
  "lp-bred-telemetry", "lp-study-defoliant", "lp-defoliant", "lp-incubator-capture"}
for _, name in ipairs(TECHS) do
  local t = data.raw.technology[name]
  assert(t, "icons.lua: no technology " .. name)
  t.icon, t.icon_size, t.icons = "__landing-party__/graphics/technology/" .. name .. ".png", 256, nil
end
