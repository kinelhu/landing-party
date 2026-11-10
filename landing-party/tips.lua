-- The army's in-game tutorial (the user, 2026-11-10: "Yes to tutorial"): Tips and tricks entries, the game's own help
-- panel, each unlocked (the "new tip" notice) at the moment a player needs it, by research or by the first building of
-- its kind; text only, its locale in [tips-and-tricks-item-name] and [tips-and-tricks-item-description].
local function tip(name, order, trigger, extra)
  local t = {type = "tips-and-tricks-item", name = name, category = "lp-army", order = order, trigger = trigger,
    dependencies = order ~= "a" and {"lp-army"} or nil, indent = order ~= "a" and 1 or nil}
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end
local shared = require("shared")
local function research(t) return {type = "research", technology = t} end
local function built(e, n) return {type = "build-entity", entity = e, count = n} end
data:extend({
  {type = "tips-and-tricks-item-category", name = "lp-army", order = "z-[landing-party]"},
  tip("lp-army", "a", research("lp-command-bandwidth-1"), {is_title = true}),
  tip("lp-army-barracks", "b", research("lp-command-bandwidth-1")),
  -- (Its numbers from shared.lua: a relay's capacity, a trooper's share and a tank's.)
  tip("lp-army-relays", "c", built("lp-command-relay", 1), {localised_description = {"tips-and-tricks-item-description.lp-army-relays",
    tostring(shared.RELAY_CAPACITY), tostring(shared.POPULATION["lp-trooper"]), tostring(shared.POPULATION["lp-battle-tank"])}}),
  tip("lp-army-beacons", "d", built("lp-rally-beacon", 1)),
  tip("lp-army-command-tool", "e", built("lp-barracks", 1)),
  tip("lp-army-squads", "f", built("lp-rally-beacon", 2)),
  tip("lp-army-scanner", "g", built("lp-threat-scanner", 1)),
  tip("lp-army-trains", "h", built("lp-muster-point", 1)),
  tip("lp-army-cannons", "i", research("lp-orbital-cannon")),
})
