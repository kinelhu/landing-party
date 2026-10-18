-- Run by scripts/ai_graph.py under luajit, outside the game: loads the mod's own tables and stance.may and prints
-- what each corporation does, so the behaviour graph is the rules themselves, not a description of them.
-- Prints tab-separated lines: kind, then fields.
local root = arg[1]
table.insert(package.loaders or package.searchers, 2, function(name)
  local p = name:gsub("^__landing%-party__%.", ""):gsub("%.", "/")
  local path = root .. "/" .. p .. ".lua"
  local f = io.open(path)
  if not f then return nil end
  f:close()
  return function() return dofile(path) end
end)
storage = {}
game = {tick = 0}
settings = {global = {}}
local shared = require("__landing-party__.shared")
local stance = require("__landing-party__.scripts.stance")

local corps = {}
for corp in pairs(shared.CORPS) do corps[#corps + 1] = corp end
table.sort(corps)

local ACTS = {"raid", "siege", "answer", "strip", "tap", "flare", "jump", "prospect", "war"}
local function set_standing(corp, st)
  storage.truces, storage.corps = {}, {}
  if st == "truce" then storage.truces[corp .. "|player"] = 1e9 end
  if st == "enemy" then storage.corps[corp] = {provoked = {player = 0}} end
end

for _, corp in ipairs(corps) do
  local c = shared.CORPS[corp]
  local temper = c.temper or {}
  local flags = {}
  for k, v in pairs(temper) do if v == true then flags[#flags + 1] = k end end
  table.sort(flags)
  print(table.concat({"temper", corp, table.concat(flags, " ")}, "\t"))
  local kinds = {}
  for kind in pairs(temper.answers or {}) do kinds[#kinds + 1] = kind end
  table.sort(kinds)
  for _, kind in ipairs(kinds) do print(table.concat({"answer", corp, kind, temper.answers[kind]}, "\t")) end
  for _, st in ipairs({"rival", "enemy", "truce"}) do
    set_standing(corp, st)
    for _, act in ipairs(ACTS) do
      print(table.concat({"may", corp, st, act, tostring(stance.may(corp, "player", act))}, "\t"))
    end
  end
  local caps = {}
  for k, v in pairs(c.caps or {}) do caps[#caps + 1] = k .. "=" .. tostring(v) end
  table.sort(caps)
  print(table.concat({"caps", corp, table.concat(caps, " ")}, "\t"))
end
local presets = {}
for k, v in pairs(shared.TUNE) do presets[#presets + 1] = {k, v} end
table.sort(presets, function(a, b) return a[2] < b[2] end)
for _, p in ipairs(presets) do print(table.concat({"preset", p[1], tostring(p[2])}, "\t")) end
