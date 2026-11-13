-- Chat notices (scripts: shared.notice): off by default. The user (2026-10-17): "nothing is communicated through notices
-- in factorio"; on, for debugging, the corporations' moves are told in chat and with alerts as before.
local shared = require("shared")
data:extend{
  {type = "bool-setting", name = "lp-chat-notices", setting_type = "runtime-global", default_value = false, order = "a"},
}

-- The levers (the user, 2026-11-08: "expose some levers for the players to customize the difficulty, not just single
-- presets. That's how vanilla does it with biters"). All runtime-global, so an admin can change them in a running game.
-- Defaults and ranges live in shared.lua; the code reads the settings (tune.lua, shared.setting).
local function range(name, r, order, kind)
  return {type = kind or "int-setting", name = name, setting_type = "runtime-global", default_value = r.default,
    minimum_value = r.min, maximum_value = r.max, order = order}
end
local function switch(name, order)
  return {type = "bool-setting", name = name, setting_type = "runtime-global", default_value = true, order = order}
end
local function preset(name, order, allowed, default)
  return {type = "string-setting", name = name, setting_type = "runtime-global", default_value = default or "normal",
    allowed_values = allowed, order = order}
end
local levels = {"very-low", "low", "normal", "high", "very-high"}

-- Every faction: the preset (a multiplier on each one's strength, aggression and income), the time between landings,
-- and a destroyed lander's revenge (the next landing comes angry, twice its escort: faction.grudge).
data:extend{
  preset("lp-difficulty", "b-a", shared.DIFFICULTY_LEVELS),
  range("lp-landing-interval", shared.LANDING_MINUTES, "b-b"),
  switch("lp-revenge-landings", "b-c"),
  -- The director (director.lua; docs/director.md): its personality, steady by default, off for today's game.
  preset("lp-director", "b-d", shared.DIRECTOR_PERSONALITIES, "steady"),
}

-- Each faction: on or off (shared.enabled), when it comes, and the multipliers (shared.TUNE: 0.5 to 2):
--   strength     a camp's unit cap (army.cap)
--   aggression   how soon it escalates and the gaps between its attacks (tune.sooner)
--   income       what it makes: parts from its fabricators (base.lua), Synthexis's biomass (creep, farm)
-- Synthexis's strength is its waves' most (lp-biotech-wave-max), so it has no strength lever.
local corps = {
  {id = "grubstake", order = "c", extra = {switch("lp-grubstake-theft", "c-h")}},
  {id = "serenity", order = "d", extra = {switch("lp-serenity-orbital-strikes", "d-h")}},
  {id = "biotech", order = "e", extra = {range("lp-biotech-cultures", shared.MAX_CULTURES, "e-g"),
    range("lp-biotech-wave-max", shared.WAVE_HUGE, "e-h"),
    switch("lp-biotech-learning", "e-i")}},
}
for _, c in ipairs(corps) do
  local id, o = c.id, c.order
  local list = {switch("lp-" .. id .. "-enabled", o .. "-a")}
  local a = shared.ARRIVALS[id]
  if a then
    list[#list + 1] = preset("lp-" .. id .. "-arrival", o .. "-b", a.allowed, a.default)
    list[#list + 1] = range("lp-" .. id .. "-camps", shared.MAX_CAMPS, o .. "-c")
    list[#list + 1] = preset("lp-" .. id .. "-strength", o .. "-d", levels)
  else
    list[#list + 1] = range("lp-" .. id .. "-arrival-evolution", shared.ARRIVE_EVO, o .. "-b", "double-setting")
  end
  list[#list + 1] = preset("lp-" .. id .. "-aggression", o .. "-e", levels)
  list[#list + 1] = preset("lp-" .. id .. "-income", o .. "-f", levels)
  for _, x in ipairs(c.extra) do list[#list + 1] = x end
  data:extend(list)
end
