-- Serenity's jammer (Fable's fortress consult, docs/reviews/2026-10-18-fortress-consult.md): a mast its siege raises in
-- the emplacement once its research has it (rd node "jammer", bought after a siege whose hits the player's robots
-- mended). Its arcs strike the player's construction and logistic robots flying within RADIUS, a few a moment, so a
-- breach stays open. Its tell is the mast itself, its lamp ring and the arcs; its counters: destroy the mast (1,500
-- health, a military target), keep roboports beyond its reach. It also blinds the player's threat scanners within its
-- reach (scripts/scanner.lua): they read lp-scan-jammed and nothing else. A leaf: ops raises and lowers it.
local shared = require("__landing-party__.shared")

local jammer = {}

local RADIUS = shared.JAM_RADIUS
local lights = require("__landing-party__.scripts.lights")
local PER_BEAT = 3               -- robots struck each beat
local BEAT = 30                  -- ticks
local CYAN = {r = 0.45, g = 0.85, b = 1, a = 1}

function jammer.raise(surface, pos, force)
  local p = surface.find_non_colliding_position("lp-jammer", pos, 10, 1)
  local m = p and surface.create_entity{name = "lp-jammer", position = p, force = force}
  if not m then return nil end
  lights.attach(m)
  for k = 0, 3 do
    rendering.draw_circle{surface = surface, target = {entity = m, offset = {0, -4 - k * 0.6}}, radius = 0.12, filled = true,
      color = CYAN, blink_interval = 20 + k * 5}
  end
  rendering.draw_light{surface = surface, target = {entity = m, offset = {0, -4}}, sprite = "utility/light_small", scale = 1.2,
    intensity = 0.8, color = CYAN}
  storage.jammers = storage.jammers or {}
  table.insert(storage.jammers, {mast = m, struck = 0})
  -- (Clamps locking, then its hum: the Sound Sheet's round four.)
  shared.cue(surface, "mast-up", m.position)
  return m
end

function jammer.lower(m)
  if m and m.valid then m.destroy() end
end

local function foes_of(force)
  local out = {}
  for _, f in pairs(game.forces) do
    if f ~= force and not shared.is_biters(f.name) and f.name ~= "neutral" and not force.get_cease_fire(f) then out[#out + 1] = f end
  end
  return out
end

function jammer.tick(tick)
  if tick % BEAT ~= 17 or not storage.jammers then return end
  for i = #storage.jammers, 1, -1 do
    local j = storage.jammers[i]
    local m = j.mast
    if not m.valid then
      table.remove(storage.jammers, i)
    else
      local bots = m.surface.find_entities_filtered{position = m.position, radius = RADIUS,
        type = {"construction-robot", "logistic-robot"}, force = foes_of(m.force), limit = PER_BEAT}
      for _, r in ipairs(bots) do
        -- A tesla arc (Space Age's beam: its own damage fires only from a turret's chain, so this one is light alone),
        -- to where the robot was (aimed at the robot, it went with it as it died); a drawn line if that fails.
        local ok = pcall(function()
          m.surface.create_entity{name = "chain-tesla-turret-beam-start", position = m.position, source = m,
            source_offset = {0, -4}, target_position = {r.position.x, r.position.y}, duration = 12}
        end)
        if ok then storage.jam_beams = (storage.jam_beams or 0) + 1 end
        if not ok then
          rendering.draw_line{surface = m.surface, from = {entity = m, offset = {0, -4}}, to = {r.position.x, r.position.y},
            color = CYAN, width = 2, time_to_live = 8}
        end
        r.die(m.force, m)
        j.struck = j.struck + 1
        storage.jammed = (storage.jammed or 0) + 1
      end
    end
  end
end

return jammer
