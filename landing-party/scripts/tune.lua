-- The corporations' levers (the user, 2026-10-18: "scaling variables for strength and aggression sort of like what
-- biters have at world gen, and balance through those"). Two per corporation, from its settings (settings.lua), each a
-- multiplier (shared.TUNE: 0.5 to 2), each driving a set of numbers so a preset reads as one thing:
--   strength     how much it fields: a camp's unit cap (army.cap)
--   aggression   how soon it acts: its ladder's clock runs faster (stance.rung), the gaps after an operation, between
--                answers and between heists (rig, tap) are shorter, and it keeps at a hopeless front longer
--                before standing down (war.quiet)
--   income       what it makes: its fabricators' parts (base.lua), Synthexis's biomass (creep.lua, farm.lua)
-- Synthexis (corp "biotech", not in shared.CORPS) has aggression (the gap between waves) and income; its strength is the
-- most a wave sends (lp-biotech-wave-max, farm.cap_of). Each is times the difficulty preset (lp-difficulty).
-- Tests and sweeps set storage.tune_levers[corp][lever] (debug_tune levers) over the settings.
-- A leaf: it reads settings and storage only.
local shared = require("__landing-party__.shared")

local tune = {}

local function lever(corp, name)
  local o = storage.tune_levers and storage.tune_levers[corp]
  if o and o[name] then return o[name] end
  local s = corp and settings.global["lp-" .. corp .. "-" .. name]
  local d = shared.DIFFICULTY[shared.setting("lp-difficulty", "normal")] or 1
  return (s and shared.TUNE[s.value] or 1) * d
end

function tune.strength(corp) return lever(corp, "strength") end
function tune.aggression(corp) return lever(corp, "aggression") end
function tune.income(corp) return lever(corp, "income") end
function tune.research(corp) return lever(corp, "research") end
-- How many levels past the player's era its weapons may go (shared.RESEARCH_AHEAD by its research preset; tests set
-- storage.tune_ahead[corp]).
function tune.ahead(corp)
  local o = storage.tune_ahead and storage.tune_ahead[corp]
  if o then return o end
  local s = corp and settings.global["lp-" .. corp .. "-research"]
  return shared.RESEARCH_AHEAD[s and s.value or "normal"] or 1
end

-- A span of ticks shortened by aggression (at least one tick), and by the director's tempo while a spree of this
-- corporation's lasts (director.lua; never Synthexis's, decision 2; never its aggression, which also runs the ladder).
function tune.sooner(corp, ticks)
  local t = corp ~= "biotech" and storage.director and storage.director.active and storage.director.tempo
    and storage.director.tempo[corp]
  local f = (t and game.tick < t.till) and t.factor or 1
  return math.max(1, math.floor(ticks / (tune.aggression(corp) * f)))
end

function tune.corp_of_force(force_name)
  for corp, c in pairs(shared.CORPS) do if c.force == force_name then return corp end end
end

return tune
