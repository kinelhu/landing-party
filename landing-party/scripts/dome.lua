-- The dome (Kessler-Hayashi; the user, 2026-11-01: "making KH camps artillery proof through shield domes? Would force
-- army encounters", then, on artillery set to auto-target firing into it for good: "maybe that's not a bug and rather a
-- feature"). Round its lander, RADIUS tiles, while its hull is up (its generators powered: base.lua makes the lander
-- indestructible then): every artillery shell that comes into it is destroyed in the air, a burst where it was caught,
-- one charge spent. At none the dome breaks, and stays down BREAK; then it is whole again. Units pass under it: it stops
-- shells, not bodies, so Synthexis's waves fight the camp as before and the player's troops can walk in. Shells crossing
-- it to something behind are caught as well (its ground shelters what lies beyond it until it breaks). The player's
-- artillery on auto-target keeps firing into it: the price of not sending troops; the first catch in ALERT_TICKS raises
-- an alert where alerts are on. Engine (scenario domeprobe, 2026-11-01): an artillery projectile is an entity a script finds by area and
-- destroys; one at a tile a tick is seen about 15 times inside 30 tiles at a look every 2 ticks, none got through.
-- On for corporations with shared.CORPS dome (Kessler-Hayashi); debug_tune domes = false turns it off.
local shared = require("__landing-party__.shared")
local base = require("__landing-party__.scripts.base")

local dome = {}
local RADIUS = 30
-- Shells a dome takes before it breaks (debug_tune dome_charge for tests), and what it mends a minute while up: 20 bought
-- a minute against six supplied turrets (about 1.8 shells a second), the camp flattened as without it (forward artillery,
-- artillery base, 2026-11-01). At 300 a battery alone breaks it in about three minutes and a supply train's worth of
-- shells; one turret (0.3 a second) wears it down over more than 20.
local CHARGE = 300
local MEND = 5
local BREAK = 3 * 60 * 60       -- down this long, then whole
local LOOK = 2                  -- ticks between looks for shells
local ALERT_TICKS = 10 * 60 * 60
local COLOR = {r = 0.55, g = 0.8, b = 0.85}

local function trace(b, msg) if base.trace then base.trace(b, "dome: " .. msg) end end

local function powered(b) return b.lander and b.lander.valid and not b.lander.destructible end

local function full() return storage.dome_charge or CHARGE end
local function state(b)
  b.dome = b.dome or {charge = full(), down_till = 0, caught = 0, breaks = 0}
  return b.dome
end

-- Its shell over the camp, faint, drawn while it stands.
local function show(b, d, up)
  if up and not (d.ring and d.ring.valid) then
    d.ring = rendering.draw_circle{color = {r = COLOR.r * 0.25, g = COLOR.g * 0.25, b = COLOR.b * 0.25, a = 0.25},
      radius = RADIUS, width = 3, filled = false, target = b.lander, surface = b.lander.surface, draw_on_ground = true}
  elseif not up and d.ring and d.ring.valid then
    d.ring.destroy()
    d.ring = nil
  end
end

-- (Gated as every alert is, shared.notices_on, off by default: the burst where a shell is caught is the tell.)
local function alert(b, pos)
  if game.tick < (storage.dome_alert or 0) or not shared.notices_on() then return end
  storage.dome_alert = game.tick + ALERT_TICKS
  for _, f in pairs(game.forces) do
    if shared.is_player_force(f) then
      for _, p in pairs(f.connected_players) do -- notice-ok: gated above
        p.add_custom_alert(b.lander, {type = "item", name = "artillery-shell"},
          {"lp.dome-alert", shared.corp_label(b.corp)}, true) -- notice-ok: gated above
      end
    end
  end
end

local function catch(b, d, pr)
  local s, pos = pr.surface, pr.position
  pr.destroy()
  s.create_entity{name = "big-explosion", position = pos}
  rendering.draw_circle{color = {r = COLOR.r, g = COLOR.g, b = COLOR.b, a = 0.6}, radius = 3, width = 4, filled = false,
    target = pos, surface = s, time_to_live = 20}
  d.charge, d.caught = d.charge - 1, d.caught + 1
  alert(b, pos)
  if d.charge <= 0 then
    d.down_till, d.breaks = game.tick + BREAK, d.breaks + 1
    trace(b, string.format("broken after %d shells caught (%d breaks); down for %d s", d.caught, d.breaks, BREAK / 60))
  end
end

function dome.tick(tick)
  if storage.domes == false or tick % LOOK ~= 0 then return end
  for _, b in pairs(storage.bases or {}) do
    if (shared.CORPS[b.corp] or {}).dome and not b.fallen and b.lander and b.lander.valid then
      local d = state(b)
      if d.down_till > 0 and tick >= d.down_till then
        d.charge, d.down_till = full(), 0
        trace(b, "whole again")
      end
      local up = d.down_till == 0 and powered(b)
      if tick % 60 == 0 then show(b, d, up) end
      if up and tick % 3600 == 0 then d.charge = math.min(full(), d.charge + MEND) end
      if up then
        -- Its foes' shells only: its own mortars' and orbital barrage's shells are artillery projectiles too, fired from
        -- inside the dome or falling on its landing ground.
        local own = game.forces[b.force]
        for _, pr in pairs(b.lander.surface.find_entities_filtered{type = "artillery-projectile", position = b.lander.position,
          radius = RADIUS}) do
          if pr.valid and pr.force ~= own and not pr.force.get_cease_fire(own) then catch(b, d, pr) end
          if d.charge <= 0 then break end
        end
      end
    end
  end
end

-- Tests: a camp's dome (charge, caught, breaks, up).
function dome.state(b)
  local d = state(b)
  return {charge = d.charge, caught = d.caught, breaks = d.breaks, up = d.down_till == 0 and powered(b)}
end

return dome
