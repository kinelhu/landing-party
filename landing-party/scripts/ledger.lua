-- The ledger (Fable's buffer consult, part 2, docs/reviews/2026-10-19-buffer-consult.md: "a patient corporation does not
-- absorb a hazard for three hours: it removes it, then invoices the party that caused it"). Serenity is at war with the
-- player from landing; a camp standing between the factory and the nests its pollution draws takes the waves, and what
-- they cost it is billed. Every BEAT, a camp that has tried to remove the hazard itself (ops.hazard_clear) bills its
-- losses to biters since the last bill, when the nest nearest them sat in a cloud (pollution on its chunk, or absorbed
-- by it) and a player's polluting building stands within POLLUTER_REACH of it. The bill goes up on an invoice post at
-- its line on the bearing to that player: a chest of the player's force (so it opens), in Serenity's colour, the sum
-- owed written over it. What is put in it is taken by its worth (ops.LOOT_VALUE: circuits, modules, steel; the rest is
-- left) and becomes parts. Paid off, the bill buys a truce, the only quiet Serenity gives: a minute for every
-- VALUE_PER_MINUTE paid since the last one, MIN_TRUCE to MAX_TRUCE; no raid, siege or cut while it lasts, and its line
-- holds (stance: "truce"). Unpaid, nothing changes: it is at war already.
-- Counters: pay, clear the nests yourself, or keep the cloud off its ground.
local shared = require("__landing-party__.shared")
local ops = require("__landing-party__.scripts.ops")
local base = require("__landing-party__.scripts.base")
local standing = require("__landing-party__.scripts.standing")

local ledger = {}

local BEAT = 5 * 3600
local BILL_MIN = 5                 -- losses before a bill
local NEST_REACH = 300             -- the losses' middle to the nest whose waves they were
local POLLUTER_REACH = 1000        -- a player's polluting building this near that nest: its cloud
local POLLUTERS = {"mining-drill", "furnace", "assembling-machine", "boiler"}
local VALUE_PER_MINUTE, MIN_TRUCE, MAX_TRUCE = 10, 10, 60
local ITEM = "electronic-circuit"  -- what the sum is written in (worth 1)
local AMBER = {r = 1, g = 0.62, b = 0.15}

local function truce_left(b, L)
  local t = storage.truces and storage.truces[b.corp .. "|" .. L.owner]
  return t and t > game.tick and math.ceil((t - game.tick) / 3600) or nil
end

local function owed_text(b, L)
  local left = truce_left(b, L)
  if left and L.owed <= 0 then return {"lp.invoice-truce", shared.corp_label(b.corp), tostring(left)} end
  return {"lp.invoice", shared.corp_label(b.corp), ITEM, tostring(math.ceil(L.owed))}
end

local function close(b, why)
  local L = b.ledger
  if not L then return end
  if L.post and L.post.valid then L.post.destroy() end
  for _, o in ipairs(L.draw or {}) do if o.valid then o.destroy() end end
  base.trace(b, "ledger: closed (" .. why .. ")")
  b.ledger = nil
end

local function draw(b, L)
  local e = L.post
  if not (e and e.valid) then return end
  if not (L.draw and L.draw[1] and L.draw[1].valid) then
    for _, o in ipairs(L.draw or {}) do if o.valid then o.destroy() end end
    L.draw = {rendering.draw_text{text = "", surface = e.surface, target = {entity = e, offset = {0, -1.4}},
      color = shared.CORPS[b.corp].color, scale = 1.1, alignment = "center", use_rich_text = true, forces = {L.owner}}}
  end
  L.draw[1].text = owed_text(b, L)
  -- A truce it bought: an amber light by night, as the trade post's.
  local lit = truce_left(b, L) ~= nil
  local on = L.draw[2] and L.draw[2].valid
  if lit and not on then
    L.draw[2] = rendering.draw_light{surface = e.surface, target = e, sprite = "utility/light_small", scale = 1, intensity = 0.8,
      color = AMBER, forces = {L.owner}}
  elseif not lit and on then
    L.draw[2].destroy()
    L.draw[2] = nil
  end
end

local function raise_post(b, L)
  if L.post and L.post.valid then return true end
  local s = game.surfaces[b.surface]
  local f = game.forces[L.owner]
  local sp = f.get_spawn_position(s)
  local dx, dy = sp.x - b.origin.x, sp.y - b.origin.y
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1 then dx, dy, len = 0, 1, 1 end
  local r = math.min(b.perimeter or b.claim_radius or 100, len - 10)
  local p = {b.origin.x + dx / len * r, b.origin.y + dy / len * r}
  local q = s.find_non_colliding_position("lp-invoice-post", p, 12, 1)
  local e = q and s.create_entity{name = "lp-invoice-post", position = q, force = f}
  if not e then return false end
  e.destructible = false
  e.minable_flag = false
  L.post = e
  return true
end

-- The player force whose cloud sat on this nest: polluted, and one of its polluting buildings within reach.
local function polluter(b, nest)
  local s = nest.surface
  if s.get_pollution(nest.position) <= 0 and (nest.absorbed_pollution or 0) <= 0 then return nil, "no cloud on the nest" end
  for _, f in ipairs(shared.player_forces()) do
    local e = s.find_entities_filtered{position = nest.position, radius = POLLUTER_REACH, force = f, type = POLLUTERS, limit = 1}[1]
    if e then return f.name, e.position end
  end
  return nil, "no polluter in reach"
end

local function bill(b)
  local u = b.unbilled
  if not u or u.n < BILL_MIN or not b.hazard_tried then return end
  b.unbilled = nil
  local s = game.surfaces[b.surface]
  local mx, my = u.x / u.n, u.y / u.n
  local nest = s.find_entities_filtered{position = {mx, my}, radius = NEST_REACH, force = "enemy", type = "unit-spawner"}
  local near, nd
  for _, e in pairs(nest) do
    local d = (e.position.x - mx) ^ 2 + (e.position.y - my) ^ 2
    if not nd or d < nd then near, nd = e, d end
  end
  local owner, why
  if near then owner, why = polluter(b, near) else why = "no nest near" end
  if owner then why = nil end
  if not owner then
    base.trace(b, string.format("ledger: %d lost to biters round %.0f,%.0f not billed (%s)", u.n, mx, my, why))
    return
  end
  local L = b.ledger or {owner = owner, owed = 0, billed = 0, paid = 0, bills = 0, total_bills = 0, round = 0, truces = 0}
  b.ledger = L
  L.owed, L.billed = L.owed + u.cost, L.billed + u.cost
  L.bills, L.total_bills = L.bills + 1, L.total_bills + 1
  raise_post(b, L)
  draw(b, L)
  local at = L.post and L.post.valid and L.post.position or {x = mx, y = my}
  standing.incident(b.corp, "invoice", at, string.format("%d owed", math.ceil(L.owed)))
  base.trace(b, string.format("ledger: billed %s %d for %d lost to the waves from %.0f,%.0f (owed %d, open bills %d)", owner,
    u.cost, u.n, near.position.x, near.position.y, math.ceil(L.owed), L.bills))
end

local function pay(b, L)
  local e = L.post
  if not (e and e.valid) then return raise_post(b, L) and draw(b, L) end
  local inv = e.get_inventory(defines.inventory.chest)
  local took = 0
  for _, it in pairs(inv.get_contents()) do
    local v = ops.LOOT_VALUE[it.name]
    if v and L.owed > 0 then
      local n = math.min(it.count, math.ceil(L.owed / v))
      n = inv.remove{name = it.name, count = n, quality = it.quality}
      L.owed, took = L.owed - n * v, took + n * v
    end
  end
  if took <= 0 then return end
  L.paid, L.round = L.paid + took, L.round + took
  b.parts = (b.parts or 0) + math.floor(took)
  if L.owed <= 0 then
    -- Paid off: a truce, by what this round paid.
    local minutes = math.max(MIN_TRUCE, math.min(MAX_TRUCE, math.floor(L.round / VALUE_PER_MINUTE)))
    storage.truces = storage.truces or {}
    local k = b.corp .. "|" .. L.owner
    storage.truces[k] = math.max(storage.truces[k] or 0, game.tick) + minutes * 3600
    L.owed, L.bills, L.round, L.truces = 0, 0, 0, L.truces + 1
    shared.reply(game.forces[L.owner], e.position, {"lp.invoice-paid", shared.corp_label(b.corp), tostring(minutes)})
    standing.incident(b.corp, "invoice paid", e.position, string.format("%d minutes of truce", minutes))
    base.trace(b, string.format("ledger: paid off; a truce of %d minutes", minutes))
  end
  base.trace(b, string.format("ledger: %s paid %d (owed %d)", L.owner, math.floor(took), math.ceil(L.owed)))
  draw(b, L)
end

function ledger.tick(tick)
  if storage.ledger_off or not storage.bases then return end
  local beat = tick % BEAT == 4100
  if tick % 60 ~= 41 and not beat then return end
  for _, b in pairs(storage.bases) do
    if (shared.CORPS[b.corp].temper or {}).bills then
      local L = b.ledger
      if L and (b.fallen or not (b.lander and b.lander.valid)) then
        close(b, "the camp is gone")
      elseif L then
        pay(b, L)
        if tick % 600 == 41 then draw(b, L) end
      end
      if beat and not b.fallen and b.lander and b.lander.valid then bill(b) end
    end
  end
end

function ledger.stats(b)
  local L = b.ledger
  return {owed = L and math.ceil(L.owed) or 0, billed = L and L.billed or 0, paid = L and L.paid or 0,
    bills = L and L.total_bills or 0, open = L and L.bills or 0, truces = L and L.truces or 0,
    post = L and L.post and L.post.valid and L.post.position or nil, owner = L and L.owner}
end

return ledger
