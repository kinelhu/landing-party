-- The biotech's breeds and its pen (docs/biotech.md; engine tests 2026-10-22). Bred biters are the vanilla biters with
-- their mask layers retinted (green body, yellow bands: they read apart from wild ones at a glance) and their dots on
-- the map in its colour. The pen is a biter spawner drawn as Space Age's captive spawner: a nest that is held. A wild
-- spawner given to another force keeps the wild look and breeds wild biters (tested), so holding a nest means a pen in
-- its place (scripts/herd.lua).
local shared = require("shared")
local B = shared.BIOTECH

local function retint(t, n)
  if type(t) ~= "table" then return n end
  if t.tint then t.tint = (n % 2 == 0) and B.tint1 or B.tint2; n = n + 1 end
  for _, v in pairs(t) do n = retint(v, n) end
  return n
end

-- A bite is not a bullet (Fable's breeds consult, docs/reviews/2026-10-22-biotech-breeds-consult.md): the breeds bite
-- with their own damage type, which armoured hulls resist, so a tank drives through a herd (the stock as first built ate
-- tanks and walkers in the arena: bred against armour +71). Infantry, walls and turrets do not resist it: the breach
-- stays quick. The biotech's answer to armour is to be a breed of its own.
local BITE = "lp-bite"
local function bite(t)
  if type(t) ~= "table" then return end
  if t.type == "damage" and t.damage and t.damage.type == "physical" then t.damage.type = BITE end
  for _, v in pairs(t) do bite(v) end
end
local HULLS = {["lp-tank"] = 60, ["lp-aegis"] = 60, ["lp-dozer"] = 60, ["lp-scorcher"] = 60, ["lp-prism"] = 60,
  ["lp-tesla"] = 60, ["lp-battle-tank"] = 60, ["lp-walker"] = 40, tank = 60, spidertron = 40}

-- The spitter (tier 1, the breeds consult): its acid is its answer to armour (no hull resists acid); outranged by rifles
-- and lances, beaten by fire and air.
local BREEDS = {"small-biter", "medium-biter", "big-biter", "behemoth-biter", "medium-spitter"}
local out = {{type = "damage-type", name = BITE}}
for _, src in ipairs(BREEDS) do
  local u = table.deepcopy(data.raw.unit[src])
  u.name = "lp-bred-" .. src
  u.localised_name = {"entity-name.lp-bred", {"entity-name." .. src}}
  u.localised_description = {"entity-description.lp-bred"}
  retint(u.run_animation, 0)
  retint(u.attack_parameters.animation, 0)
  bite(u.attack_parameters.ammo_type)
  u.map_color = B.color
  u.enemy_map_color = B.color
  u.hidden_in_factoriopedia = true
  table.insert(out, u)
end

-- Its worms: two by each pen (the breeds consult: a farm's home guard; the only thing of its that reaches a flier).
local worm = table.deepcopy(data.raw.turret["medium-worm-turret"])
worm.name = "lp-bred-worm"
worm.localised_name = {"entity-name.lp-bred-worm"}
worm.localised_description = {"entity-description.lp-bred"}
worm.autoplace = nil
worm.hidden_in_factoriopedia = true
worm.map_color = B.color
worm.enemy_map_color = B.color
for _, k in ipairs({"folded_animation", "preparing_animation", "prepared_animation", "prepared_alternative_animation",
  "starting_attack_animation", "attacking_animation", "ending_attack_animation", "folding_animation", "graphics_set"}) do
  retint(worm[k], 0)
end
table.insert(out, worm)

local pen = table.deepcopy(data.raw["unit-spawner"]["biter-spawner"])
pen.name = "lp-pen"
pen.localised_name = {"entity-name.lp-pen"}
pen.localised_description = {"entity-description.lp-pen"}
pen.autoplace = nil
pen.captured_spawner_entity = nil
pen.hidden_in_factoriopedia = true
pen.graphics_set = {animations = {table.deepcopy(data.raw["assembling-machine"]["captive-biter-spawner"].graphics_set.animation)}}
pen.map_color = B.color
pen.enemy_map_color = B.color
-- Its stock is the wave: it breeds up to the cap and keeps them by its gate.
pen.max_count_of_owned_units = shared.PEN_CAP
pen.max_friends_around_to_spawn = shared.PEN_CAP
-- By the biotech force's own evolution (tested): the vanilla spawner's table, bred.
for _, r in ipairs(pen.result_units) do
  local name = r[1] or r.unit
  if r[1] then r[1] = "lp-bred-" .. name else r.unit = "lp-bred-" .. name end
end
-- Its spitters from evolution 0.3, a sixth of what it breeds from 0.5 (the vanilla spitter spawner's medium comes at 0.4).
local first = pen.result_units[1]
if first[1] then
  table.insert(pen.result_units, {"lp-bred-medium-spitter", {{0.3, 0.0}, {0.5, 0.12}, {1.0, 0.15}}})
else
  table.insert(pen.result_units, {unit = "lp-bred-medium-spitter", spawn_points = {
    {evolution_factor = 0.3, weight = 0.0}, {evolution_factor = 0.5, weight = 0.12}, {evolution_factor = 1.0, weight = 0.15}}})
end
-- Killed, its gland (the player's pheromone bait research; it dropped from Grubstake's flare canisters until the flare
-- was retired, 2026-10-22).
pen.loot = {{item = "lp-pheromone-gland", probability = 1, count_min = 1, count_max = 2}}
table.insert(out, pen)

-- Creep (the user, 2026-10-22: "kind of a Zerg creep?"; scripts/creep.lua): Gleba's jellynut soil, not mineable, with
-- the "object" layer so nothing is built on it (turrets, walls, belts, rails, poles, chests, spawners: tested) while
-- everything walks it (biters, the player, cars, tanks, spidertrons). It drinks pollution, nearly thirty times grass: what
-- it drinks is Synthexis's biomass (scripts/creep.lua).
local creep = table.deepcopy(data.raw.tile["artificial-jellynut-soil"])
creep.name = "lp-creep"
creep.localised_name = {"tile-name.lp-creep"}
creep.minable = nil
creep.autoplace = nil
creep.collision_mask = {layers = {ground_tile = true, object = true}}
creep.absorptions_per_second = {pollution = shared.CREEP_ABSORB}
creep.map_color = {150, 50, 170}
-- Violet over the soil: the first look (untinted) read as brown mud beside Nauvis dirt.
creep.tint = {r = 0.8, g = 0.55, b = 1, a = 1}
creep.hidden_in_factoriopedia = true
table.insert(out, creep)

-- The tumor: what grows the creep round it. A small egg raft out of the water, tinted; a military target the player's
-- turrets shoot. It does not collide with creep (no "object" layer), so it can stand on its own creep, but not on water.
local raft = data.raw["unit-spawner"]["gleba-spawner-small"]
local tumor = {type = "simple-entity-with-force", name = "lp-tumor", hidden_in_factoriopedia = true,
  localised_name = {"entity-name.lp-tumor"}, localised_description = {"entity-description.lp-tumor"},
  icon = raft.icon, icon_size = raft.icon_size or 64,
  flags = {"placeable-enemy", "placeable-off-grid", "not-repairable", "not-blueprintable", "not-deconstructable"},
  max_health = 400, is_military_target = true,
  collision_box = {{-0.9, -0.9}, {0.9, 0.9}}, selection_box = {{-1.2, -1.2}, {1.2, 1.2}},
  collision_mask = {layers = {item = true, player = true, water_tile = true, is_object = true, is_lower_object = true}},
  map_color = B.color, enemy_map_color = B.color,
  dying_explosion = raft.dying_explosion, corpse = raft.corpse, damaged_trigger_effect = raft.damaged_trigger_effect,
  resistances = {{type = "fire", percent = -50}, {type = "physical", decrease = 2}},
  animations = table.deepcopy(raft.graphics_set.animations)}
for _, a in ipairs(tumor.animations) do
  for _, l in ipairs(a.layers or {}) do
    l.scale = (l.scale or 1) * 1.6
    if l.shift then l.shift = {l.shift[1] * 1.6, l.shift[2] * 1.6} end
    if not l.draw_as_shadow then l.tint = {r = 0.75, g = 1, b = 0.6, a = 1} end
  end
end
table.insert(out, tumor)

-- On creep, Synthexis's units are quicker and mend (scripts/creep.lua renews these each second; a sticker with a negative
-- damage heals, tested). Its own damage type, so no resistance reduces the mending. No goo drawn.
table.insert(out, {type = "damage-type", name = "lp-mend", hidden = true})
local haste = table.deepcopy(data.raw.sticker["slowdown-sticker"])
haste.name, haste.animation, haste.duration_in_ticks = "lp-creep-haste", nil, 90
haste.target_movement_modifier = 1.3
haste.hidden = true
local mend = table.deepcopy(data.raw.sticker["slowdown-sticker"])
mend.name, mend.animation, mend.duration_in_ticks = "lp-creep-mend", nil, 90
mend.target_movement_modifier = 1
mend.damage_per_tick = {amount = -0.1, type = "lp-mend"}
mend.damage_interval = 1
mend.hidden = true
table.insert(out, haste)
table.insert(out, mend)
data:extend(out)

-- Every corporation's variant of a hull kind, the player's battle tank, and the base game's tank and spidertron.
for _, type in ipairs({"unit", "spider-unit", "car", "spider-vehicle"}) do
  for name, e in pairs(data.raw[type] or {}) do
    local pct = HULLS[name] or HULLS[shared.kind_of(name)]
    if pct then
      e.resistances = e.resistances or {}
      table.insert(e.resistances, {type = BITE, percent = pct})
    end
  end
end
