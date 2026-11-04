-- The player's Grubstake devices from its pacifier crystals (the faction loot consult, technologies 2 and 3).
-- Pact breaker: set inside a Grubstake camp's claim, it suspends the pact (pact.apply) for BREAK, then burns out: the
-- biters and Grubstake turn on each other for that long. Set outside every claim it waits, and says so.
-- Claim marker: Grubstake reads the player's buildings within 40 of it as its own claim (ops.marked) and leaves them be.
-- (A real player pacifier is not possible: the engine's cease-fire is per force, and it would end the biters map-wide.)
local shared = require("__landing-party__.shared")
local pact = require("__landing-party__.scripts.pact")

local marker = {}

local BREAK = 3 * 3600

local function in_claim(ent)
  for _, b in pairs(storage.bases or {}) do
    if (shared.CORPS[b.corp].temper or {}).pact and not b.fallen and b.surface == ent.surface.index and b.origin
      and (b.origin.x - ent.position.x) ^ 2 + (b.origin.y - ent.position.y) ^ 2 <= (b.claim_radius or 100) ^ 2 then
      return b
    end
  end
end

function marker.placed(ent)
  if ent.name == "lp-claim-marker" then
    storage.claim_markers = storage.claim_markers or {}
    table.insert(storage.claim_markers, ent)
  else
    storage.breakers = storage.breakers or {}
    table.insert(storage.breakers, {entity = ent})
    if not in_claim(ent) then shared.reply(ent.force, ent.position, {"lp.breaker-outside"}) end
  end
end

-- A bait planted in a Grubstake claim by a force with its bait made (a field study, studies.lua): it breaks the pact as
-- the breaker does, folded in (the rewards consult, G3).
function marker.as_breaker(ent)
  if not in_claim(ent) then return false end
  storage.breakers = storage.breakers or {}
  table.insert(storage.breakers, {entity = ent})
  return true
end

function marker.tick(tick)
  if tick % 60 ~= 47 then return end
  for i = #(storage.claim_markers or {}), 1, -1 do
    if not storage.claim_markers[i].valid then table.remove(storage.claim_markers, i) end
  end
  for i = #(storage.breakers or {}), 1, -1 do
    local br = storage.breakers[i]
    if not br.entity.valid or (br.lit and tick - br.lit >= BREAK) then
      if br.lit then
        storage.pact_suspended_till = nil
        pact.apply()
      end
      if br.entity.valid then
        br.entity.surface.create_entity{name = "explosion", position = br.entity.position}
        br.entity.destroy()
      end
      table.remove(storage.breakers, i)
    elseif not br.lit and in_claim(br.entity) then
      br.lit = tick
      storage.pact_suspended_till = tick + BREAK
      storage.pact_breaks = (storage.pact_breaks or 0) + 1
      pact.apply()
      shared.reply(br.entity.force, br.entity.position, {"lp.breaker-lit", string.format("[gps=%d,%d,%s]", br.entity.position.x, br.entity.position.y,
        br.entity.surface.name)})
    end
  end
end

return marker
