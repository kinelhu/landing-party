-- Field studies (docs/reviews/2026-11-03-player-rewards-consult.md, part 3; the user, 2026-11-04: "Let's try for all",
-- of Grubstake's and Synthexis's trees): what the player learns of a corporation by fighting it. A study is a technology
-- with a scripted trigger (scripts/studies.lua counts what the player destroys and fires it); behind it the node, a
-- technology paid in science packs that gives the reward. Counts and pack costs are the consult's priors.
local shared = require("shared")

local G = shared.CORPS.grubstake.tint
local GREEN = shared.BIOTECH.tint1
local red, green, blue = {"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}
local mil = {"military-science-pack", 1}

local function study(id, icon, tint)
  return {type = "technology", name = "lp-study-" .. id, icons = {{icon = icon, icon_size = 64, tint = tint}},
    research_trigger = {type = "scripted", trigger_description = {"lp.study-" .. id}}, effects = {}, essential = false}
end
local function node(name, icon, tint, prereqs, packs, count, effects)
  return {type = "technology", name = name, icons = {{icon = icon, icon_size = 64, tint = tint}}, prerequisites = prereqs,
    effects = effects or {}, unit = {count = count, time = 30, ingredients = packs}}
end

data:extend({
  -- G1 Claims register: its claims labelled with their ore, the ground round them charted, its strip camps tagged.
  study("claims", "__base__/graphics/icons/signal/signal_G.png", G),
  node("lp-claims-register", "__base__/graphics/icons/signal/signal_G.png", G, {"lp-study-claims", "military-2"},
    {red, green, mil}, 100),
  -- G2 Strip drill: its drill, twice the electric drill's speed at half the drain (player.lua's lp-strip-drill).
  study("strip", "__base__/graphics/icons/electric-mining-drill.png", G),
  node("lp-strip-drill", "__base__/graphics/icons/electric-mining-drill.png", G, {"lp-study-strip", "steel-processing",
    "chemical-science-pack"}, {red, green, blue}, 150, {{type = "unlock-recipe", recipe = "lp-strip-drill"}}),
  -- G3 Pheromone bait, made: the bait without a gland; planted in a Grubstake claim it suspends its pact (bait.lua).
  study("bait", "__base__/graphics/icons/poison-capsule.png", G),
  node("lp-bait-made", "__base__/graphics/icons/poison-capsule.png", G, {"lp-study-bait", "military-2"},
    {red, green, mil}, 100, {{type = "unlock-recipe", recipe = "lp-bait-made"}}),
  -- G4 Flak turret: Grubstake's dirty flak against fliers (harriers, scavengers, laser drones).
  study("flak", "__base__/graphics/icons/gun-turret.png", G),
  node("lp-flak-turret", "__base__/graphics/icons/gun-turret.png", G, {"lp-study-flak", "gun-turret", "military-2"},
    {red, green, mil}, 150, {{type = "unlock-recipe", recipe = "lp-flak-turret"}}),
  -- S1 Bred-biter telemetry: the threat scanner tells Synthexis's biters from the wild and reports its scout.
  study("telemetry", "__base__/graphics/icons/small-biter.png", GREEN),
  node("lp-bred-telemetry", "__base__/graphics/icons/small-biter.png", GREEN, {"lp-study-telemetry", "military-2"},
    {red, green, mil}, 100),
  -- S2 Defoliant: a thrown charge that strips creep within 6 tiles and burns its tumors.
  study("defoliant", "__base__/graphics/icons/poison-capsule.png", GREEN),
  node("lp-defoliant", "__base__/graphics/icons/poison-capsule.png", GREEN, {"lp-study-defoliant", "military-3", "explosives"},
    {red, green, blue, mil}, 150, {{type = "unlock-recipe", recipe = "lp-defoliant"}}),
})
data.raw.technology["lp-defoliant"].localised_description = {"technology-description.lp-defoliant",
  tostring(shared.DEFOLIATE_RADIUS)}

-- S4 Incubator capture (the edge): Space Age's capture robot takes a Synthexis incubator, and it breeds biter eggs as a
-- captured nest does. A native trigger; the capture itself is the reward.
if data.raw["assembling-machine"]["captive-biter-spawner"] then
  data.raw["unit-spawner"]["lp-pen"].captured_spawner_entity = "captive-biter-spawner"
  data:extend({{type = "technology", name = "lp-incubator-capture", icons = {{icon = "__base__/graphics/icons/biter-spawner.png",
    icon_size = 64, tint = GREEN}}, prerequisites = {"captivity"}, effects = {},
    research_trigger = {type = "capture-spawner", entity = "lp-pen"}}})
end

-- The bait made (G3): five iron and a poison capsule, no gland.
data:extend({{type = "recipe", name = "lp-bait-made", enabled = false, energy_required = 5,
  ingredients = {{type = "item", name = "iron-plate", amount = 5}, {type = "item", name = "poison-capsule", amount = 1}},
  results = {{type = "item", name = "lp-bait", amount = 1}}}})

-- The flak turret (G4): a turret on power that fires only at fliers (the lp-air-unit target, air.lua), its burst
-- Grubstake's flak buggy's (units.lua anti_air): 22 to fliers over 2 tiles, nothing to the ground.
do
  local t = table.deepcopy(data.raw["electric-turret"]["laser-turret"])
  t.name = "lp-flak-turret"
  -- Its own model (tools/blender/turning_buildings.py; the user, 2026-11-10: "I still see some gross recolors"): an
  -- armoured ring for its base, its twin-barrelled flak head in 64 directions for every state (it does not rise out of
  -- the ground as the laser turret does), no laser's energy glow.
  local SHEETS = require("graphics.sheets")
  local function part(p, extra)
    local K = SHEETS["player/flak-turret/" .. p]
    local l = {filename = "__landing-party__/graphics/player/flak-turret/" .. p .. "/body.png", width = K.width, height = K.height,
      scale = 0.5, shift = K.shift}
    if p == "head" then l.direction_count, l.line_length = K.frames, K.line_length end
    for k, v in pairs(extra or {}) do l[k] = v end
    return l
  end
  local function shadow(p)
    local l = part(p, {draw_as_shadow = true})
    l.filename = "__landing-party__/graphics/player/flak-turret/" .. p .. "/shadow.png"
    return l
  end
  local head = {layers = {part("head"), shadow("head")}}
  t.folded_animation, t.preparing_animation, t.prepared_animation, t.folding_animation = head, head, head, head
  t.energy_glow_animation = nil
  t.graphics_set = {base_visualisation = {animation = {layers = {part("base"), shadow("base")}}}}
  t.minable = {mining_time = 0.5, result = "lp-flak-turret"}
  t.attack_target_mask = {"lp-air-unit"}
  t.next_upgrade = nil
  t.fast_replaceable_group = nil
  local burst = {type = "nested-result", action = {type = "area", radius = 2, force = "enemy", trigger_target_mask = {"lp-air-unit"},
    action_delivery = {type = "instant", target_effects = {{type = "damage", damage = {amount = 22, type = "explosion"}}}}}}
  t.attack_parameters = {type = "projectile", ammo_category = "laser", cooldown = 30, range = 26,
    sound = table.deepcopy(data.raw.gun["submachine-gun"].attack_parameters.sound),
    ammo_type = {energy_consumption = "300kJ", action = {type = "direct", action_delivery = {type = "instant",
      target_effects = {{type = "create-entity", entity_name = "explosion"}, burst}}}}}
  local function tint(v, seen)
    if type(v) ~= "table" or seen[v] then return end
    seen[v] = true
    if v.filename or v.filenames then v.tint = G end
    for _, w in pairs(v) do tint(w, seen) end
  end
  tint(t.graphics_set, {})
  data:extend({t,
    {type = "item", name = "lp-flak-turret", icons = {{icon = "__base__/graphics/icons/laser-turret.png", tint = G}},
      subgroup = "turret", order = "z[lp-flak-turret]", place_result = "lp-flak-turret", stack_size = 50},
    {type = "recipe", name = "lp-flak-turret", enabled = false, energy_required = 10,
      ingredients = {{type = "item", name = "steel-plate", amount = 20}, {type = "item", name = "electronic-circuit", amount = 20},
        {type = "item", name = "battery", amount = 6}},
      results = {{type = "item", name = "lp-flak-turret", amount = 1}}}})
end

-- The defoliant (S2): a thrown capsule; where it lands, scripts/studies.lua strips creep within shared.DEFOLIATE_RADIUS and burns tumors.
do
  local c = table.deepcopy(data.raw.capsule["poison-capsule"])
  c.name = "lp-defoliant"
  c.icons = {{icon = "__base__/graphics/icons/poison-capsule.png", tint = GREEN}}
  c.icon = nil
  c.localised_description = {"item-description.lp-defoliant", tostring(shared.DEFOLIATE_RADIUS)}
  local p = table.deepcopy(data.raw.projectile["poison-capsule"])
  p.name = "lp-defoliant-projectile"
  p.action = {type = "direct", action_delivery = {type = "instant", target_effects = {
    {type = "create-entity", entity_name = "medium-explosion"},
    {type = "script", effect_id = "lp-defoliant"}}}}
  p.final_action = nil
  c.capsule_action.attack_parameters.ammo_type.action[1].action_delivery.projectile = "lp-defoliant-projectile"
  data:extend({c, p,
    {type = "recipe", name = "lp-defoliant", enabled = false, energy_required = 8,
      ingredients = {{type = "item", name = "explosives", amount = 2}, {type = "item", name = "sulfuric-acid-barrel", amount = 1}},
      results = {{type = "item", name = "lp-defoliant", amount = 1}}}})
end
