-- Chat notices (scripts: shared.notice): off by default. The user (2026-10-17): "nothing is communicated through notices
-- in factorio"; on, for debugging, the corporations' moves are told in chat and with alerts as before.
data:extend{
  {type = "bool-setting", name = "lp-chat-notices", setting_type = "runtime-global", default_value = false, order = "a"},
}

-- The corporations' strength and aggression (scripts/tune.lua), each set for each corporation, as the biters' settings
-- are: one lever drives many numbers, and balance is made through them. Runtime-global: an admin can change them in a
-- running game. The presets' multipliers live in shared.TUNE.
local levels = {"very-low", "low", "normal", "high", "very-high"}
local order = 0
-- Synthexis (id biotech) too: its strength is its biomass income, its aggression the gap between its waves (farm.lua).
for _, corp in ipairs({"grubstake", "serenity", "biotech"}) do
  for _, lever in ipairs({"strength", "aggression"}) do
    order = order + 1
    data:extend{{type = "string-setting", name = "lp-" .. corp .. "-" .. lever, setting_type = "runtime-global",
      default_value = "normal", allowed_values = levels, order = "b" .. order}}
  end
end
