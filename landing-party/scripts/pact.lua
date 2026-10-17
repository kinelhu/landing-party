-- The pact (docs/reviews/2026-10-15-biter-country-consult.md; the user: a lore reason, "a biter pacifier antenna in
-- their outposts"): a corporation with temper.pact (Grubstake: "We don't fight bugs") lands a pacifier beside each
-- lander. While one of its pacifiers stands, it and the biters hold fire on each other, its turrets and units, their
-- worms and attack groups (a cease-fire both ways; spike: worms held fire 12 tiles away, behemoths sent at its radar left
-- it). The engine's cease-fire is per force, so the pact is the corporation's, not one camp's: destroy every pacifier
-- and the biters turn on all its camps until one is rebuilt (REBUILD_TICKS after its loss, if the lander stands).
local shared = require("__landing-party__.shared")
local base = require("__landing-party__.scripts.base")

local pact = {}

local REBUILD_TICKS = 5 * 60 * 60

local function has_pact(corp) return (shared.CORPS[corp].temper or {}).pact and not storage.pact_off end
pact.has = has_pact

local function standing(corp)
  for _, b in pairs(storage.bases or {}) do
    if b.corp == corp and not b.fallen and b.pacifier and b.pacifier.valid then return true end
  end
  return false
end

local function tell(key, corp, at, surface)
  for _, f in pairs(game.forces) do
    if #f.players > 0 and not shared.is_corp(f.name) then
      shared.notice(f, {key, shared.corp_label(corp), string.format("[gps=%d,%d,%s]", at.x, at.y, surface.name)})
    end
  end
end

-- The cease-fire as it stands: on while the corporation has the pact and a pacifier up.
function pact.apply()
  local enemy = game.forces.enemy
  if not enemy then return end
  for corp, c in pairs(shared.CORPS) do
    local f = game.forces[c.force]
    if f then
      -- Suspended by the player's pact breaker (breaker.lua) while it lasts.
      local on = has_pact(corp) and standing(corp) and not (storage.pact_suspended_till
        and game.tick < storage.pact_suspended_till) or false
      local was = f.get_cease_fire(enemy)
      f.set_cease_fire(enemy, on)
      enemy.set_cease_fire(f, on)
      storage.pact_state = storage.pact_state or {}
      storage.pact_state[corp] = on
      if was and not on then storage.pact_broken = (storage.pact_broken or 0) + 1 end
    end
  end
end

-- Beside the lander, on landing and on rebuild.
function pact.place(b)
  if not has_pact(b.corp) or not (b.lander and b.lander.valid) then return end
  local s = b.lander.surface
  local name = shared.variant(b.corp, "lp-pacifier")
  local x, y = b.lander.position.x, b.lander.position.y
  local p = s.find_non_colliding_position(name, {x + 8, y - 8}, 12, 1)
  b.pacifier = p and s.create_entity{name = name, position = p, force = b.lander.force}
  b.pacifier_due = nil
  if not b.pacifier then b.pacifier_due = game.tick + 600 end
  if b.pacifier then
    local was = storage.pact_state and storage.pact_state[b.corp]
    pact.apply()
    if was == false and storage.pact_state[b.corp] then tell("lp.pact-restored", b.corp, b.pacifier.position, s) end
  end
  base.trace(b, string.format("pacifier %s; the pact %s", b.pacifier and string.format("up at %.0f,%.0f", b.pacifier.position.x,
    b.pacifier.position.y) or "found no room", storage.pact_state and storage.pact_state[b.corp] and "holds" or "is off"))
end

function pact.lost(ent)
  for _, b in pairs(storage.bases or {}) do
    if b.pacifier == ent then
      -- Its crystal (the faction loot consult): the landing's own pacifier always, a rebuilt one a quarter of the time.
      if (b.pacifiers_lost or 0) == 0 or math.random() < 0.25 then
        ent.surface.spill_item_stack{position = ent.position, stack = {name = "lp-pacifier-crystal", count = 1},
          enable_looted = true}
      end
      b.pacifiers_lost = (b.pacifiers_lost or 0) + 1
      b.pacifier = nil
      b.pacifier_due = game.tick + REBUILD_TICKS
      local was = storage.pact_state and storage.pact_state[b.corp]
      -- The entity is still valid while its death is handled: counted as gone.
      local enemy = game.forces.enemy
      local others = false
      for _, o in pairs(storage.bases) do
        if o ~= b and o.corp == b.corp and not o.fallen and o.pacifier and o.pacifier.valid then others = true end
      end
      if was and not others then
        local f = game.forces[shared.CORPS[b.corp].force]
        f.set_cease_fire(enemy, false); enemy.set_cease_fire(f, false)
        storage.pact_state[b.corp] = false
        storage.pact_broken = (storage.pact_broken or 0) + 1
        tell("lp.pact-broken", b.corp, ent.position, ent.surface)
      end
      return b
    end
  end
end

function pact.tick(tick)
  if tick % 600 ~= 120 then return end
  for _, b in pairs(storage.bases or {}) do
    if b.pacifier_due and tick >= b.pacifier_due and not b.fallen and b.lander.valid then pact.place(b) end
  end
end

return pact
