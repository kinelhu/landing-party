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
--   keep_peace   the share of its army's shortfall (units short of its cap, at their mean price) its planner leaves
--   keep_war     in hand for the army before building what it can do without (walls, growth, lamps, labs): at peace,
--                and on a war footing (the budget by posture; the planner's thresholds stood alone before)
-- The threat term is off (threat_arm 0, threat_war above 1), measured both ways. Counted gross, at 0.5 and 0.5, it was a
-- runaway: Kessler-Hayashi, hit by Grubstake's first raids, armed half as much again, went on a war footing and took
-- Grubstake's camp down to two buildings (rivals, 2026-10-24), the stronger hit and made stronger. Counted net
-- (strategy.threat: only the side losing an exchange arms), it erased the corporations' shapes instead: Grubstake, losing,
-- armed to a garrison of 70 to Kessler-Hayashi's 38 by the second hour (system 12345; the shapes target wants
-- Kessler-Hayashi the stronger late). The army's budget (keep) holds: with it alone all five targets held on 12345.
local POSTURE = {rung_arm = 1.5, grudge_arm = 2, threat_arm = 0, threat_scale = 200, threat_war = 2,
  keep_peace = 0.25, keep_war = 0.5}
local THREAT_WINDOW = 10 * 3600

local function weights(corp)
  local m = shared.CORPS[corp] and shared.CORPS[corp].mind
  return m and m.posture or POSTURE
end

-- What it is losing lately (value, parts): to each foe, what it lost to it less what it made it lose, the worst foe
-- counted. Net, so that the side losing an exchange arms and the side winning it does not: counted gross, the stronger
-- of two rivals armed on its first losses and took the other's camp (the runaway below). A player's losses are not
-- recorded (know.lua keeps the factions'), so against a player it is what it lost. The wild do not count.
function strategy.threat(corp)
  local lost = {}
  for _, l in ipairs(know.losses(corp, THREAT_WINDOW)) do
    if l.force ~= "enemy" and l.force ~= "none" and l.force ~= "neutral" then
      lost[l.force] = (lost[l.force] or 0) + (l.value or 0)
    end
  end
  local mine = shared.CORPS[corp] and shared.CORPS[corp].force or (corp == "biotech" and shared.BIOTECH.force)
  local worst = 0
  for force, v in pairs(lost) do
    local other = know.faction_of(force)
    local took = 0
    if other and mine then
      for _, l in ipairs(know.losses(other, THREAT_WINDOW)) do
        if l.force == mine then took = took + (l.value or 0) end
      end
    end
    worst = math.max(worst, v - took)
  end
  return worst
end

-- in: {corp, rung (its rung against the player it is at war with, 0 if none), at_war (bool), grudge (bool),
-- threat (strategy.threat), short (units short of its cap), unit_cost (their mean price)}. out: {arm (the cap's
-- multiple), war (the footing's condition, before its cap), threat, pressed (0..1), keep (parts the planner leaves for
-- the army)}.
function strategy.posture(i)
  local w = weights(i.corp)
  local d = POSTURE
  local pressed = math.min(1, (i.threat or 0) / w.threat_scale)
  local arm = (i.rung >= 2 and w.rung_arm or 1) * (i.grudge and w.grudge_arm or 1) * (1 + w.threat_arm * pressed)
  local war = i.at_war or pressed >= w.threat_war
  local share = war and (w.keep_war or d.keep_war) or (w.keep_peace or d.keep_peace)
  return {arm = arm, war = war, threat = i.threat or 0, pressed = pressed,
    keep = math.floor((i.short or 0) * (i.unit_cost or 0) * share)}
end

return strategy
