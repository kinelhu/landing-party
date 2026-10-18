-- Answers (split from ops.lua, 2026-10-18, along the AI graph's seams: docs/ai-graph.md): how a provoked corporation
-- answers, by its reaction table (temper.answers) and the kind of provocation: Grubstake's flare on the culprit (a raid
-- only where no turret covers it), Serenity's raid it can win, its siege for trespass or a second provocation, each
-- answer siege soon after the last a tier heavier. The code is as it was in ops; install runs it with ops' helpers
-- bound (K) and returns what ops calls.
local shared = require("__landing-party__.shared")

local answers = {}

function answers.install(ops, K)
local ANSWER_COOLDOWN = K.ANSWER_COOLDOWN
local SIEGE_TIERS = K.SIEGE_TIERS
local defence = K.defence
local field = K.field
local launch = K.launch
local launch_siege = K.launch_siege
local needed = K.needed
local sense = K.sense
local siege_site = K.siege_site
local siege_tier = K.siege_tier
local stance = K.stance
local tune = K.tune
-- Turrets of the owner's that cover a spot (a gun turret's 18, and a margin).
local ANSWER_COVER = 24
local function covered(s, owner, pos)
  return s.count_entities_filtered{position = pos, radius = ANSWER_COVER, force = owner,
    type = {"ammo-turret", "electric-turret", "fluid-turret"}, limit = 1} > 0
end
-- A second provocation this soon after an answer: Serenity's raid it would lose becomes a siege.
local ANSWER_AGAIN = 30 * 3600

-- The answer, by the corporation's reaction table (temper.answers) and the kind of provocation:
--   flare   Grubstake: biters on the culprit (flare.answer); where no turret covers it, a snatch raid instead
--   raid    a raid on the player's building nearest the spot; one it would lose: a siege if provoked again within
--           ANSWER_AGAIN, else nothing yet
--   siege   mortars on the nearest of the player's turrets there (or what is there); none possible: the raid
local function answer(b, trace, army)
  local a = b.answer
  b.answer = nil
  if not stance.may(b.corp, a.owner, "answer") then return end
  local how = ((shared.CORPS[b.corp].temper or {}).answers or {})[a.kind or "loss"] or "raid"
  local s = game.surfaces[b.surface]
  sense(b, s, {x = a.pos[1], y = a.pos[2]}, 30)
  local key, bd
  for k, t in pairs(b.intel.targets) do
    if t.owner == a.owner then
      local d = (t.pos[1] - a.pos[1]) ^ 2 + (t.pos[2] - a.pos[2]) ^ 2
      if d <= 40 * 40 and (not bd or d < bd) then key, bd = k, d end
    end
  end
  b.next_answer = game.tick + tune.sooner(b.corp, ANSWER_COOLDOWN)
  if not key then
    trace(b, string.format("answer: nothing of %s's to hit near %.0f,%.0f", a.owner, a.pos[1], a.pos[2]))
    return
  end
  local t = b.intel.targets[key]
  t.cool = 0
  local said = string.format("answer (%s, %s): provoked by %s at %.0f,%.0f, %ds ago: ", a.kind or "loss", how, a.owner,
    a.pos[1], a.pos[2], math.floor((game.tick - a.tick) / 60))
  local function done(what)
    b.answers = (b.answers or 0) + 1
    b.answered = b.answered or {}
    b.answered[what] = (b.answered[what] or 0) + 1
    b.last_answer = game.tick
    trace(b, said .. what)
    return true
  end
  local function siege()
    -- An answer is self-defence, as the counter-battery is: a corporation that sieges at all may answer with one before
    -- its level brings them (Serenity at level 0 sent nothing at a laser wall for three hours, visit nw).
    if not (shared.capable(b.corp, "siege", 99) or b.grudge) or not stance.may(b.corp, a.owner, "siege") then
      trace(b, said .. string.format("no siege (capable %s, may %s)", tostring(shared.capable(b.corp, "siege", army.level(b))),
        tostring(stance.may(b.corp, a.owner, "siege"))))
      return false
    end
    -- At the turret nearest the spot: the siege's target is a turret of its (siege_site).
    local tkey, td
    for k, x in pairs(b.intel.targets) do
      if x.owner == a.owner and prototypes.entity[x.kind] and prototypes.entity[x.kind].type:find("turret") then
        local d = (x.pos[1] - a.pos[1]) ^ 2 + (x.pos[2] - a.pos[2]) ^ 2
        if d <= 40 * 40 and (not td or d < td) then tkey, td = k, d end
      end
    end
    local site = tkey and siege_site(b, b.intel.targets[tkey])
    if not site then
      trace(b, said .. (tkey and "no siege (no mortar site)" or "no siege (no turret of theirs known there)"))
      return false
    end
    -- Each answer siege soon after the last comes a tier heavier (one mortar more, trucked in with the rest; Fable's
    -- fortress consult: escalation physical and countable), as far as its parts and field reach.
    local again = b.last_siege_answer and game.tick - b.last_siege_answer < ANSWER_AGAIN
    b.siege_step = again and math.min((b.siege_step or 0) + 1, #SIEGE_TIERS) or 0
    local tier = siege_tier(b, b.intel.targets[tkey], army)
    local up = tier
    for k = tier + 1, math.min(#SIEGE_TIERS, tier + b.siege_step) do
      local n, reserve = field(b, army)
      if (b.parts or 0) >= SIEGE_TIERS[k].cost and n + reserve >= SIEGE_TIERS[k].guards then up = k end
    end
    if launch_siege(b, tkey, site, trace, army, up) then
      b.last_siege_answer = game.tick
      return done(up > tier and string.format("a siege, a tier heavier (%d)", up) or "a siege")
    end
    trace(b, said .. "no siege (could not launch)")
    return false
  end
  local function raid() return launch(b, key, trace, army, {answer = true}) and done("a squad goes") or false end
  if how == "flare" then
    if not covered(s, a.owner, t.pos) and raid() then return end
    local why = ops.answer_flare and ops.answer_flare(b, t.pos, a.owner) or "no flares"
    if why == "launched" then return done("a flare on it") end
    trace(b, said .. "no flare (" .. why .. ")")
    return
  end
  if how == "siege" and siege() then return end
  -- A raid it can win (the defence there, against all it could send), else a siege when provoked again soon.
  local n, reserve = field(b, army)
  if needed(defence(b, t)) <= n + reserve then
    if raid() then return end
  elseif how ~= "siege" and b.last_answer and game.tick - b.last_answer < ANSWER_AGAIN and siege() then
    return
  elseif how ~= "siege" then
    b.last_answer = game.tick
    trace(b, said .. string.format("too strong for a raid (%d needed, %d to send); remembered", needed(defence(b, t)),
      n + reserve))
    return
  end
  trace(b, said .. "nothing to send")
end
return {answer = answer}
end

return answers
