-- Achievements (the user, 2026-11-03: "Achievements are a def yes"; docs/reviews/2026-11-03-player-rewards-consult.md):
-- plain achievements, granted by script (scripts/achievements.lua) when the deed is done by a player's force. Vanilla
-- achievement art stands in until each has its own. Field work, Egg farmer and Your own orbit wait for what they mark.
local G = "__base__/graphics/achievement/"
local function a(name, icon, order)
  return {type = "achievement", name = name, icon = G .. icon, icon_size = 128, order = "lp-" .. order}
end
data:extend({
  a("lp-claim-jumped", "steamrolled.png", "a"),
  a("lp-culture-shock", "pest-control.png", "b"),
  a("lp-uplink-down", "so-long-and-thanks-for-all-the-fish.png", "c"),
  a("lp-eyes-first", "watch-your-step.png", "d"),
  a("lp-siege-broken", "art-of-siege.png", "e"),
})
