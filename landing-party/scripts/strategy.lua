-- A corporation's posture (the faction AI's strategy layer, step 4; docs/reviews/2026-10-23-faction-ai-audit.md). One
-- place that answers "how hard is this settlement pressed, and what does it put first": the army cap's multipliers
-- (a rung against a player, a grudge) and the war footing (at war and short of its cap: units before rebuilds and
-- exports) were each derived where they were used; they are read from here now, and the losses the faction has lived
-- through lately (know.lua) press it too: a camp bled by a rival arms as one shelled by the player does.
-- A leaf: a pure function of what war.lua gathers every 10 seconds (b.posture), weighed by the corporation's mind.
local shared = require("__landing-party__.shared")
local know = require("__landing-party__.scripts.know")

local strategy = {}

-- The defaults a mind may set (shared.CORPS[corp].mind.posture):
--   rung_arm     the army cap's multiple from its second rung against a player (was a fixed 1.5)
--   grudge_arm   while a grudge is fresh (was a fixed 2)
--   threat_arm   at most this much more, as its recent losses reach threat_scale
--   threat_scale the value lost in THREAT_WINDOW that counts as fully pressed (parts)
--   threat_war   pressed this hard (a share of threat_scale), it goes on a war footing even with no player at war
-- Threat off for now (threat_arm 0, threat_war above 1): at 0.5 and 0.5, Kessler-Hayashi, hit by Grubstake's first
-- raids, armed half as much again and went on a war footing, and took Grubstake's camp down to two buildings (rivals,
-- 2026-10-24): a runaway, the stronger hit and made stronger. The layer is a restructure first; how much losses should
-- arm a faction is a balance call for the system sim (docs/system.md), tuned last.
local POSTURE = {rung_arm = 1.5, grudge_arm = 2, threat_arm = 0, threat_scale = 200, threat_war = 2}
local THREAT_WINDOW = 10 * 3600

local function weights(corp)
  local m = shared.CORPS[corp] and shared.CORPS[corp].mind
  return m and m.posture or POSTURE
end

-- What it has lost lately (value, parts) to anyone but the wild: the pressure the knowledge layer sees.
function strategy.threat(corp)
  local v = 0
  for _, l in ipairs(know.losses(corp, THREAT_WINDOW)) do
    if l.force ~= "enemy" and l.force ~= "none" then v = v + (l.value or 0) end
  end
  return v
end

-- in: {corp, rung (its rung against the player it is at war with, 0 if none), at_war (bool), grudge (bool),
-- threat (strategy.threat)}. out: {arm (the cap's multiple), war (the footing's condition, before its cap), threat,
-- pressed (0..1)}.
function strategy.posture(i)
  local w = weights(i.corp)
  local pressed = math.min(1, (i.threat or 0) / w.threat_scale)
  local arm = (i.rung >= 2 and w.rung_arm or 1) * (i.grudge and w.grudge_arm or 1) * (1 + w.threat_arm * pressed)
  return {arm = arm, war = i.at_war or pressed >= w.threat_war, threat = i.threat or 0, pressed = pressed}
end

return strategy
