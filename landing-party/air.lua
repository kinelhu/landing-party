-- Who can shoot up (the RTS pass, the user, 2026-10-21: "abide by RTS gold standards ... fun and competitive"). A unit
-- kind with `ground_only` in shared.units fires weapons that cannot touch air: every hit it lands on a single target
-- becomes a hit on a small circle that skips the lp-air-unit trigger target, and every blast, line or chain it makes
-- skips it too. The engine has no target mask for units (an ammo's target_filter is not read by unit AI; a mask on a
-- direct hit is ignored, one on an area is honoured: spiked in the arena, 2026-10-21), so the unit still aims at a
-- flier in range and wastes its shot: air draws a ground-only army's fire, which is its edge against one.
-- Runs in data-final-fixes, after the corporations' copies and plates exist, so they are covered as well.
local shared = require("shared")

local MASK = {"common"}
local SUFFIX = "-lp-ground"
local made = {}

local copy

local function wrap(e)
  return {type = "nested-result", action = {type = "area", radius = 0.3, force = "not-same", trigger_target_mask = MASK,
    action_delivery = {type = "instant", target_effects = {e}}}}
end

local action

local function effects(list, direct)
  if list.type then
    if list.type == "damage" and direct then return wrap(list) end
    if list.type == "nested-result" then action(list.action) end
    return list
  end
  for i, e in ipairs(list) do list[i] = effects(e, direct) end
  return list
end

local function delivery(d, direct)
  if d.target_effects then d.target_effects = effects(d.target_effects, direct) end
  if d.type == "beam" then d.beam = copy("beam", d.beam)
  elseif d.type == "projectile" then d.projectile = copy("projectile", d.projectile)
  elseif d.type == "chain" then d.chain = copy("chain-active-trigger", d.chain)
  -- A spitter's acid (the biotech's bred spitter, 2026-10-23: it reached harriers until streams were covered).
  elseif d.type == "stream" then d.stream = copy("stream", d.stream) end
end

-- Transforms an action (a TriggerItem or an array of them) in place.
function action(a)
  if a.type == nil then
    for _, x in ipairs(a) do action(x) end
    return
  end
  if a.type ~= "direct" then a.trigger_target_mask = a.trigger_target_mask or MASK end
  local d = a.action_delivery
  if d then
    if d.type then delivery(d, a.type == "direct") else for _, x in ipairs(d) do delivery(x, a.type == "direct") end end
  end
end

-- A ground-only copy of a beam, projectile or chain, made once.
function copy(type, name)
  local src = data.raw[type] and data.raw[type][name]
  if not src then return name end
  local key = type .. "/" .. name
  if made[key] then return made[key] end
  local p = table.deepcopy(src)
  p.name = name .. SUFFIX
  made[key] = p.name
  if p.action then action(p.action) end
  if p.final_action then action(p.final_action) end
  if p.initial_action then action(p.initial_action) end
  data:extend({p})
  return p.name
end

-- The player's own: the battle tank's cannon and the breacher's charges do not shoot up either (one rule for every side);
-- nor do the biotech's breeds (shared.BREEDS).
local PLAYER = {["lp-battle-tank"] = true, ["lp-breacher"] = true}

-- A shot aimed at a flier tells the script (scripts/aim.lua), which turns the shooter to a target it can hurt: without
-- it a flier over a ground-only army soaks all its fire.
local TELL = {type = "direct", action_delivery = {type = "instant", target_effects = {
  {type = "nested-result", action = {type = "area", radius = 0.3, force = "not-same", trigger_target_mask = {"lp-air-unit"},
    action_delivery = {type = "instant", target_effects = {{type = "script", effect_id = "lp-ground-at-air"}}}}}}}}

local count = 0
for _, type in ipairs({"unit", "spider-unit"}) do
  for name, u in pairs(data.raw[type] or {}) do
    local spec = name:sub(1, 3) == "lp-" and shared.units[shared.kind_of(name)]
    -- The biotech's breeds bite nothing in the air (docs/biotech.md: its class cannot shoot up).
    if (PLAYER[name] or (shared.BREEDS[name] and not shared.BREEDS[name].air) or spec and spec.ground_only) and u.attack_parameters
      and u.attack_parameters.ammo_type then
      local at = u.attack_parameters.ammo_type
      action(at.action)
      if at.action.type then at.action = {at.action} end
      table.insert(at.action, table.deepcopy(TELL))
      count = count + 1
    end
  end
end
log("air.lua: " .. count .. " ground-only unit prototypes")
