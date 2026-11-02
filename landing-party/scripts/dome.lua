-- The dome (Kessler-Hayashi; the user, 2026-11-01: "making KH camps artillery proof through shield domes? Would force
-- army encounters", then, on artillery set to auto-target firing into it for good: "maybe that's not a bug and rather a
-- feature"). Round its lander, RADIUS tiles, while its hull is up (its generators powered: base.lua makes the lander
-- indestructible then): every artillery shell that comes into it is destroyed in the air, a burst where it was caught,
-- a share of its charge spent (HOLD). At none the dome breaks, and stays down BREAK; then it is whole again. Units pass under it: it stops
-- shells, not bodies, so Synthexis's waves fight the camp as before and the player's troops can walk in. Shells crossing
-- it to something behind are caught as well (its ground shelters what lies beyond it until it breaks). The player's
-- artillery on auto-target keeps firing into it: the price of not sending troops; the first catch in ALERT_TICKS raises
-- an alert where alerts are on. Engine (scenario domeprobe, 2026-11-01): an artillery projectile is an entity a script finds by area and
-- destroys; one at a tile a tick is seen about 15 times inside 30 tiles at a look every 2 ticks, none got through.
-- On for corporations with shared.CORPS dome (Kessler-Hayashi); debug_tune domes = false turns it off.
local shared = require("__landing-party__.shared")
local base = require("__landing-party__.scripts.base")
local threat = require("__landing-party__.scripts.threat")

local dome = {}
local RADIUS = 30
-- What a dome takes before it breaks: HOLD of the fire of every foe's artillery that reaches it (its prototype's rate,
-- its force's research), at least one gun's; it mends a sixtieth of that a minute while up. A flat 300 before, tuned on
-- one battery of six (about 1.8 shells a second, broken in about three minutes); 20 bought a minute against them and the
-- camp was flattened as without it (forward artillery, artillery base, 2026-11-01). Measured in time, a battery of 6 and
-- one of 60 each take HOLD to break it: the guns buy no shortcut, troops do. (debug_tune dome_charge fixes it, tests.)
local HOLD = 3 * 60                -- seconds of the guns' fire
local MEND = 1 / 60                -- of its whole, a minute
local LOOK_GUNS = 60 * 60          -- ticks between counts of the guns that reach it
local ART = {"artillery-turret", "artillery-wagon"}
local BREAK = 3 * 60 * 60       -- down this long, then whole
local LOOK = 2                  -- ticks between looks for shells
local ALERT_TICKS = 10 * 60 * 60
local COLOR = {r = 0.55, g = 0.8, b = 0.85}

local function trace(b, msg) if base.trace then base.trace(b, "dome: " .. msg) end end

local function powered(b) return b.lander and b.lander.valid and not b.lander.destructible end

-- Shells a second from the foes' artillery that reaches its lander (each gun at its prototype's cooldown, its force's
-- gun speed research), at least one gun's.
local function fire_rate(b)
  local s, c, own = b.lander.surface, b.lander.position, game.forces[b.force]
  local rate, one = 0, 0
  for name in pairs(prototypes.get_entity_filtered{{filter = "type", type = ART}}) do
    local p = threat.profile(name)
    if p then one = math.max(one, 60 / p.cooldown) end
  end
  local far = 0
  for _, f in pairs(game.forces) do if f ~= own then far = math.max(far, threat.artillery_reach(f)) end end
  for _, g in ipairs(s.find_entities_filtered{position = c, radius = far + RADIUS, type = ART}) do
    local f = g.force
    if f ~= own and not f.get_cease_fire(own) and f.name ~= "neutral" then
      local p = threat.profile(g.name)
      local r = threat.reach(g) + RADIUS
      if p and (g.position.x - c.x) ^ 2 + (g.position.y - c.y) ^ 2 <= r * r then
        local cat = prototypes.ammo_category["artillery-shell"] and "artillery-shell"
        rate = rate + 60 / p.cooldown * (1 + (cat and f.get_gun_speed_modifier(cat) or 0))
      end
    end
  end
  return math.max(rate, one)
end
-- Its whole, in shells: debug_tune's, or HOLD of the guns' fire (counted every LOOK_GUNS).
local function full(b, d)
  if storage.dome_charge then return storage.dome_charge end
  if not d.whole or game.tick >= (d.counted or 0) + LOOK_GUNS then
    d.whole, d.counted = math.max(1, math.floor(HOLD * fire_rate(b) + 0.5)), game.tick
  end
  return d.whole
end
-- (Its charge is kept as a share of its whole: more guns brought, more shells it takes, and the same time.)
local function state(b)
  b.dome = b.dome or {left = 1, down_till = 0, caught = 0, breaks = 0}
  if b.dome.charge and not b.dome.left then b.dome.left, b.dome.charge = math.min(1, b.dome.charge / 300), nil end
  return b.dome
end
local function charge(b, d) return d.left * full(b, d) end

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
  d.left, d.caught = math.max(0, d.left - 1 / full(b, d)), d.caught + 1
  alert(b, pos)
  if d.left <= 1e-9 then
    d.left = 0
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
        d.left, d.down_till = 1, 0
        trace(b, "whole again")
      end
      local up = d.down_till == 0 and powered(b)
      if tick % 60 == 0 then show(b, d, up) end
      if up and tick % 3600 == 0 then d.left = math.min(1, d.left + MEND) end
      if up then
        -- Its foes' shells only: its own mortars' and orbital barrage's shells are artillery projectiles too, fired from
        -- inside the dome or falling on its landing ground.
        local own = game.forces[b.force]
        for _, pr in pairs(b.lander.surface.find_entities_filtered{type = "artillery-projectile", position = b.lander.position,
          radius = RADIUS}) do
          if pr.valid and pr.force ~= own and not pr.force.get_cease_fire(own) then catch(b, d, pr) end
          if d.left <= 0 then break end
        end
      end
    end
  end
end

-- Tests: a camp's dome (charge, caught, breaks, up).
function dome.state(b)
  local d = state(b)
  return {charge = math.floor(charge(b, d) + 0.5), whole = full(b, d), caught = d.caught, breaks = d.breaks,
    up = d.down_till == 0 and powered(b)}
end

return dome
