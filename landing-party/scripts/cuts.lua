-- The power survey (split from ops.lua, 2026-10-18, along the AI graph's seams: docs/ai-graph.md): Serenity's (temper
-- "cuts"), every few minutes at war, finds the pole behind the lasers facing it whose loss darkens them (power.lua) and
-- makes it a target. The code is as it was in ops; install runs it with ops' helpers bound (K) and returns what ops calls.
local shared = require("__landing-party__.shared")

local cuts = {}

function cuts.install(ops, K)
local home = K.home
local power = K.power
local stance = K.stance
-- The power survey (Serenity's temper "cuts"; Fable's fortress consult): every CUT_TICKS while at war with a player,
-- the lasers of that player nearest its home (CUT_LASERS within CUT_RANGE) and the network behind them; the pole whose
-- loss darkens the most of them becomes a target worth CUT_VALUE (a relay is 10), sized as any other.
local CUT_TICKS, CUT_RANGE, CUT_LASERS, CUT_VALUE, CUT_AREA = 5 * 3600, 450, 40, 14, 350
local function survey_power(b, trace)
  if not (shared.CORPS[b.corp].temper or {}).cuts or storage.cuts_off then return end
  local h = home(b)
  if not h then return end
  local s = game.surfaces[b.surface]
  for _, f in ipairs(shared.player_forces()) do
    if stance.may(b.corp, f.name, "war") then
      local lasers = s.find_entities_filtered{position = h.position, radius = CUT_RANGE, force = f, type = "electric-turret"}
      table.sort(lasers, function(x, y)
        return (x.position.x - h.position.x) ^ 2 + (x.position.y - h.position.y) ^ 2
          < (y.position.x - h.position.x) ^ 2 + (y.position.y - h.position.y) ^ 2
      end)
      for k = #lasers, CUT_LASERS + 1, -1 do lasers[k] = nil end
      local cut, why = power.cut(s, f, lasers, CUT_AREA)
      if cut then
        local p = cut.pole
        local key = "cut:" .. p.unit_number
        local t = b.intel.targets[key] or {tried = 0, cool = 0}
        t.pos, t.kind, t.value, t.seen, t.owner = {p.position.x, p.position.y}, p.name, CUT_VALUE, game.tick, f.name
        t.defence, t.dmg = ops.weigh(s, t.pos, f)
        t.exposure = ops.exposure(s, t.pos, f)
        t.cut = cut.dark
        b.intel.targets[key] = t
        if b.cut_said ~= key then
          b.cut_said = key
          b.cuts_found = (b.cuts_found or 0) + 1
          trace(b, string.format("power survey: the %s at %.0f,%.0f feeds %d of %s's lasers alone (%d poles); a target",
            p.name, p.position.x, p.position.y, cut.dark, f.name, cut.poles))
        end
      elseif #lasers > 0 and game.tick >= (b.cut_quiet or 0) then
        b.cut_quiet = game.tick + 30 * 3600
        trace(b, "power survey: " .. why)
      end
    end
  end
end

return {CUT_TICKS = CUT_TICKS, survey_power = survey_power}
end

return cuts
