-- The ledger (Fable's buffer consult, part 2, docs/reviews/2026-10-19-buffer-consult.md: "a patient corporation does not
-- absorb a hazard for three hours: it removes it, then invoices the party that caused it"). Serenity is provoked only:
-- a rival camp standing between the player's factory and the nests its pollution draws took the waves for free. Now
-- what the waves cost it is billed. Every BEAT, a camp that has tried to remove the hazard itself (ops.hazard_clear)
-- bills its losses to biters since the last bill, when the nest nearest them sat in a cloud (pollution on its chunk, or
-- absorbed by it) and a player's polluting building stands within POLLUTER_REACH of it. The bill goes up on an invoice
-- post at its line on the bearing to that player: a chest of the player's force (so it opens), in Serenity's colour,
-- the sum owed written over it. What is put in it is taken by its worth (ops.LOOT_VALUE: circuits, modules, steel; the
-- rest is left) and becomes parts. Unpaid DUE after the BILLS_DUE-th open bill, the player is an enemy (ops.provoke);
-- the post comes down. Paid off, the open bills go back to none. At war already, nothing is billed: it caps at enemy.
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
local BILLS_DUE, DUE = 3, 20 * 3600
local ITEM = "electronic-circuit"  -- what the sum is written in (worth 1)
local RED = {r = 1, g = 0.25, b = 0.2}

local function owed_text(b, L)
  local owed = math.ceil(L.owed)
  if L.due then
    return {"lp.invoice-due", shared.corp_label(b.corp), ITEM, tostring(owed),
      tostring(math.max(0, math.ceil((L.due - game.tick) / 3600)))}
  end
  return {"lp.invoice", shared.corp_label(b.corp), ITEM, tostring(owed)}
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
  -- Overdue soon: a red light by night, as the claim stake's lamp turns red.
  local red = L.due ~= nil
  if red and not L.draw[2] then
    L.draw[2] = rendering.draw_light{surface = e.surface, target = e, sprite = "utility/light_small", scale = 1, intensity = 0.8,
      color = RED, forces = {L.owner}}
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
  local source = owner and why
  if owner then why = nil end
  if owner and standing.get(b.corp, owner) == "enemy" then owner, why = nil, "already an enemy" end
  if not owner then
    base.trace(b, string.format("ledger: %d lost to biters round %.0f,%.0f not billed (%s)", u.n, mx, my, why))
    return
  end
  local L = b.ledger or {owner = owner, owed = 0, billed = 0, paid = 0, bills = 0, total_bills = 0}
  b.ledger = L
  L.owed, L.billed = L.owed + u.cost, L.billed + u.cost
  L.bills, L.total_bills = L.bills + 1, L.total_bills + 1
  L.source = {x = source.x, y = source.y}
  if L.bills >= BILLS_DUE and not L.due then L.due = game.tick + DUE end
  raise_post(b, L)
  draw(b, L)
  local at = L.post and L.post.valid and L.post.position or {x = mx, y = my}
  standing.incident(b.corp, "invoice", at, string.format("%d owed", math.ceil(L.owed)))
  base.trace(b, string.format("ledger: billed %s %d for %d lost to the waves from %.0f,%.0f (owed %d, open bills %d%s)", owner,
    u.cost, u.n, near.position.x, near.position.y, math.ceil(L.owed), L.bills, L.due and ", due" or ""))
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
  L.paid = L.paid + took
  b.parts = (b.parts or 0) + math.floor(took)
  if L.owed <= 0 then
    L.owed, L.bills, L.due = 0, 0, nil
    if L.draw and L.draw[2] and L.draw[2].valid then L.draw[2].destroy() end
    if L.draw then L.draw[2] = nil end
    shared.reply(game.forces[L.owner], e.position, {"lp.invoice-paid", shared.corp_label(b.corp)})
    standing.incident(b.corp, "invoice paid", e.position)
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
      elseif L and standing.get(b.corp, L.owner) == "enemy" then
        close(b, "at war")
      elseif L then
        pay(b, L)
        if L.due and tick >= L.due and L.owed > 0 then
          local at = L.post and L.post.valid and L.post.position or b.origin
          base.trace(b, string.format("ledger: %s did not pay (%d owed): an enemy", L.owner, math.ceil(L.owed)))
          b.unpaid = (b.unpaid or 0) + 1
          standing.incident(b.corp, "invoice unpaid", at, string.format("%d owed", math.ceil(L.owed)))
          -- Its answer goes for the factory whose cloud drew the waves.
          ops.provoke(b.force, L.owner, L.source or at, "ledger")
          close(b, "unpaid")
        elseif tick % 600 == 41 then
          draw(b, L)
        end
      end
      if beat and not b.fallen and b.lander and b.lander.valid then bill(b) end
    end
  end
end

function ledger.stats(b)
  local L = b.ledger
  return {owed = L and math.ceil(L.owed) or 0, billed = L and L.billed or 0, paid = L and L.paid or 0,
    bills = L and L.total_bills or 0, open = L and L.bills or 0, due = L and L.due, post = L and L.post and L.post.valid
    and L.post.position or nil, unpaid = b.unpaid or 0, owner = L and L.owner}
end

return ledger
