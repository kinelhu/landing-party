-- The player's shield projector (the user, 2026-11-04: "hemisphere dome projectors you can rotate that block enemy fire
-- against your defenses (and drain power while doing so, with break and recharge mechanisms, could work on regular arms
-- but also spitters and worms)"; its arc 45 degrees, turned in 8 steps as Space Age's railgun turret is, eight a ring).
-- A hit on a player's turret, wall or gate within its RADIUS, from an attacker standing in its arc, is given back: the
-- health returned, its charge (its own power buffer, filled from the network) paying J_PER_HP a point. Empty, it breaks:
-- down until its buffer is back to REARM of full. The orbital strike passes (it falls from above, as through the
-- corporations' domes). Its arc on the ground while it holds; each catch plays the dome's wave over it (dome.wave).
local shared = require("__landing-party__.shared")
local dome = require("__landing-party__.scripts.dome")

local shield = {}
local S = shared.SHIELD
local HALF = math.rad(S.arc) / 2
local WAVE_EVERY = 30            -- ticks between its waves (a hail of bullets is one shimmer, not sixty)

local function list()
  storage.shields = storage.shields or {}
  return storage.shields
end

-- Its facing in radians, east 0, clockwise (screen y down): the entity's direction, 16 steps a turn in 2.x.
local function facing(e) return (e.direction / 16) * 2 * math.pi - math.pi / 2 end

local function draw_arc(r)
  if r.arc and r.arc.valid then r.arc.destroy() end
  local e = r.entity
  r.arc = rendering.draw_arc{color = {r = 0.25, g = 0.55, b = 0.8, a = 0.25}, min_radius = S.radius - 0.6, max_radius = S.radius,
    start_angle = facing(e) - HALF, angle = 2 * HALF, target = e, surface = e.surface, draw_on_ground = true}
end

function shield.on_built(e)
  local ent = e.entity
  if not (ent and ent.valid and ent.name == "lp-shield-projector") then return end
  local r = {entity = ent, down_till = 0, caught = 0}
  list()[ent.unit_number] = r
  draw_arc(r)
end

function shield.on_rotated(e)
  local r = e.entity and e.entity.valid and list()[e.entity.unit_number]
  if r then draw_arc(r) end
end

-- Whether a hit on `e` is the shield's to take: by an attacker within a projector's arc. Returns the record that takes it.
local function covering(e, from)
  local best
  for n, r in pairs(list()) do
    local p = r.entity
    if not p.valid then
      list()[n] = nil
    elseif p.surface == e.surface and game.tick >= r.down_till then
      local px, py = p.position.x, p.position.y
      if (e.position.x - px) ^ 2 + (e.position.y - py) ^ 2 <= S.radius ^ 2 then
        local a = math.atan2(from.y - py, from.x - px) - facing(p)
        a = (a + math.pi) % (2 * math.pi) - math.pi
        if math.abs(a) <= HALF and p.energy > 0 then best = r; break end
      end
    end
  end
  return best
end

-- The damage event, for the player's defences (control.lua's filter): true if a shield took it.
function shield.on_damaged(ev)
  local e = ev.entity
  if not (e and e.valid) or not next(list()) then return false end
  local by = (ev.cause and ev.cause.valid and ev.cause) or (ev.source and ev.source.valid and ev.source)
  if not by or by.force == e.force then return false end
  if by.name == "lp-orbital-projectile" then return false end
  local r = covering(e, by.position)
  if not r then return false end
  local p = r.entity
  local hp = ev.final_damage_amount
  local cost = hp * S.j_per_hp
  if p.energy < cost then
    -- Broken: its last charge spent, down till its buffer is back to REARM.
    p.energy = 0
    r.down_till = math.huge
    r.breaks = (r.breaks or 0) + 1
    if r.arc and r.arc.valid then r.arc.color = {r = 0.6, g = 0.2, b = 0.2, a = 0.25} end
    return false
  end
  p.energy = p.energy - cost
  e.health = e.health + hp
  r.caught = r.caught + 1
  r.absorbed = (r.absorbed or 0) + hp
  if game.tick - (r.waved or 0) >= WAVE_EVERY then
    r.waved = game.tick
    dome.wave({anchor = p, radius = S.radius}, by.position)
  end
  return true
end

-- Its rearming: a broken shield is back once its buffer holds REARM of full (every second).
function shield.tick(tick)
  if tick % 60 ~= 17 or not storage.shields then return end
  for n, r in pairs(storage.shields) do
    local p = r.entity
    if not p.valid then
      if r.arc and r.arc.valid then r.arc.destroy() end
      storage.shields[n] = nil
    elseif r.down_till == math.huge and p.energy >= S.buffer * S.rearm then
      r.down_till = 0
      draw_arc(r)
    end
  end
end

-- Tests: each projector's record, by its unit number.
function shield.stats()
  local out = {}
  for n, r in pairs(storage.shields or {}) do
    if r.entity.valid then
      out[n] = {caught = r.caught, absorbed = r.absorbed or 0, breaks = r.breaks or 0, energy = r.entity.energy,
        down = r.down_till > game.tick, direction = r.entity.direction}
    end
  end
  return out
end

return shield
