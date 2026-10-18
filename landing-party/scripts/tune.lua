-- The corporations' levers (the user, 2026-10-18: "scaling variables for strength and aggression sort of like what
-- biters have at world gen, and balance through those"). Two per corporation, from its settings (settings.lua), each a
-- multiplier (shared.TUNE: 0.5 to 2), each driving a set of numbers so a preset reads as one thing:
--   strength     how much it fields: a camp's unit cap (army.cap), the biters a flare calls (flare.wave)
--   aggression   how soon it acts: its ladder's clock runs faster (stance.rung), the gaps after an operation, between
--                answers and between heists (flare, rig, tap) are shorter, and it keeps at a hopeless front longer
--                before standing down (war.quiet)
-- Tests and sweeps set storage.tune_levers[corp][lever] (debug_tune levers) over the settings.
-- A leaf: it reads settings and storage only.
local shared = require("__landing-party__.shared")

local tune = {}

local function lever(corp, name)
  local o = storage.tune_levers and storage.tune_levers[corp]
  if o and o[name] then return o[name] end
  local s = corp and settings.global["lp-" .. corp .. "-" .. name]
  return s and shared.TUNE[s.value] or 1
end

function tune.strength(corp) return lever(corp, "strength") end
function tune.aggression(corp) return lever(corp, "aggression") end

-- A span of ticks shortened by aggression (at least one tick).
function tune.sooner(corp, ticks) return math.max(1, math.floor(ticks / tune.aggression(corp))) end

function tune.corp_of_force(force_name)
  for corp, c in pairs(shared.CORPS) do if c.force == force_name then return corp end end
end

return tune
