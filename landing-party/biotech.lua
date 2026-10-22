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

local BREEDS = {"small-biter", "medium-biter", "big-biter", "behemoth-biter"}
local out = {}
for _, src in ipairs(BREEDS) do
  local u = table.deepcopy(data.raw.unit[src])
  u.name = "lp-bred-" .. src
  u.localised_name = {"entity-name.lp-bred", {"entity-name." .. src}}
  u.localised_description = {"entity-description.lp-bred"}
  retint(u.run_animation, 0)
  retint(u.attack_parameters.animation, 0)
  u.map_color = B.color
  u.enemy_map_color = B.color
  u.hidden_in_factoriopedia = true
  table.insert(out, u)
end

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
table.insert(out, pen)
data:extend(out)
