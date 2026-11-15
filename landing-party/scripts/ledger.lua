-- The ledger (Fable's buffer consult, part 2, docs/reviews/2026-10-19-buffer-consult.md: "a patient corporation does not
-- absorb a hazard for three hours: it removes it, then invoices the party that caused it"). Serenity is at war with the
-- player from landing; a camp standing between the factory and the nests its pollution draws takes the waves, and what
-- they cost it is billed. Every BEAT, a camp that has tried to remove the hazard itself (ops.hazard_clear) bills its
-- losses to biters since the last bill, when the nest nearest them sat in a cloud (pollution on its chunk, or absorbed
-- by it) and a player's polluting building stands within POLLUTER_REACH of it. The bill goes up on an invoice post at
-- its line on the bearing to that player: a chest of the player's force (so it opens), in Serenity's colour, the sum
-- owed written over it. What is put in it is taken by its worth (ops.LOOT_VALUE: circuits, modules, steel; the rest is
-- left) and becomes parts. Paid off, the bills are closed, and nothing more: no truce (the user, 2026-11-11: "maybe we
-- just drop the idea of a truce? ... the hostility is the most fun part"; until 0.2.325 paying bought 10 to 60 minutes of
-- quiet). A bill unpaid OVERDUE after it went up is collected by force: one raid, its next operation within COLLECT_SOON,
-- weighing the billed player's buildings within COLLECT_REACH of the polluter that bill named COLLECT_WEIGHT times
-- (ops.collect); when that raid goes, the open bills are closed as collected, the post comes down.
-- Counters: pay, clear the nests yourself, keep the cloud off its ground, or defend what it will come for. Disputed (Fable's engagement consult:
-- "invoices disputed in the field"): each bill names the nest whose waves it was; the billed player who kills that nest
-- while the bill is open strikes it (its sum off what is owed; nothing left owed, the post comes down). A nest Serenity
-- or anything else kills strikes nothing.
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
-- Priors (no prototype says how patient a creditor is): a bill's grace (shared: the post's description reads it), the
-- collection's pace, reach and weight.
local OVERDUE = shared.INVOICE_GRACE * 3600
local COLLECT_SOON = 2 * 3600
local COLLECT_TICKS = 20 * 3600
local COLLECT_REACH, COLLECT_WEIGHT = 150, 10
local ITEM = "electronic-circuit"  -- what the sum is written in (worth 1)
local AMBER = {r = 1, g = 0.62, b = 0.15}

local function owed_text(b, L)
  local due = L.due and math.ceil((L.due - game.tick) / 3600)
  if due and due > 0 then return {"lp.invoice-due", shared.corp_label(b.corp), ITEM, tostring(math.ceil(L.owed)), tostring(due)} end
  return {"lp.invoice", shared.corp_label(b.corp), ITEM, tostring(math.ceil(L.owed))}
end

-- The billed nest marked for the billed player, in game and on the map (the world tells which nest a bill names; no
-- notice): its corporation's icon over it while a bill of it is open.
local function key(at) return string.format("%.1f,%.1f", at[1], at[2]) end
local function mark(b, L, o)
  L.marks = L.marks or {}
  local k = key(o.at)
  if L.marks[k] then return end
  local sprite = "virtual-signal/" .. shared.CORPS[b.corp].icon
  L.marks[k] = {}
  for _, mode in ipairs({"game", "chart"}) do
    table.insert(L.marks[k], rendering.draw_sprite{sprite = sprite, surface = o.nest.surface, target = {entity = o.nest,
      offset = {0, -2.5}}, x_scale = 1.5, y_scale = 1.5, tint = shared.CORPS[b.corp].color, forces = {L.owner},
      render_mode = mode})
  end
end
local function unmark(L, at)
  for k, list in pairs(L.marks or {}) do
    if not at or k == key(at) then
      for _, o in ipairs(list) do if o.valid then o.destroy() end end
      L.marks[k] = nil
    end
  end
end

local function close(b, why)
  local L = b.ledger
  if not L then return end
  unmark(L)
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
  -- Overdue, a collection on its way: an amber light by night.
  local lit = b.collect ~= nil and b.collect.owner == L.owner and game.tick < b.collect.till
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
  local L = b.ledger or {owner = owner, owed = 0, billed = 0, paid = 0, bills = 0, total_bills = 0, round = 0, paid_off = 0,
    collections = 0}
  b.ledger = L
  local from = select(2, polluter(b, near))
  L.due = L.due or game.tick + OVERDUE
  L.owed, L.billed = L.owed + u.cost, L.billed + u.cost
  L.bills, L.total_bills = L.bills + 1, L.total_bills + 1
  L.open = L.open or {}
  table.insert(L.open, {nest = near, at = {near.position.x, near.position.y}, cost = u.cost, from = from and {from.x, from.y}})
  mark(b, L, L.open[#L.open])
  raise_post(b, L)
  draw(b, L)
  local at = L.post and L.post.valid and L.post.position or {x = mx, y = my}
  standing.incident(b.corp, "invoice", at, string.format("%d owed", math.ceil(L.owed)))
  base.trace(b, string.format("ledger: billed %s %d for %d lost to the waves from %.0f,%.0f (owed %d, open bills %d)", owner,
    u.cost, u.n, near.position.x, near.position.y, math.ceil(L.owed), L.bills))
end

local function pay(b, L)
  local e = L.post
  if not (e and e.valid) then
    if L.owed <= 0 then return end
    return raise_post(b, L) and draw(b, L)
  end
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
    -- Paid off: the bills closed, no collection; nothing more (no truce since 0.2.325).
    L.owed, L.bills, L.round, L.paid_off, L.open, L.due = 0, 0, 0, L.paid_off + 1, {}, nil
    unmark(L)
    if b.collect and b.collect.owner == L.owner then b.collect = nil end
    shared.reply(game.forces[L.owner], e.position, {"lp.invoice-paid", shared.corp_label(b.corp)})
    standing.incident(b.corp, "invoice paid", e.position, string.format("%d paid", math.floor(L.paid)))
    base.trace(b, "ledger: paid off; no collection")
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
        if b.ledger and L.owed > 0 and L.due and tick >= L.due and not b.collect then ledger.collect(b, L) end
        if b.ledger and tick % 600 == 41 then draw(b, L) end
      end
      if beat and not b.fallen and b.lander and b.lander.valid then bill(b) end
    end
  end
end

-- A nest died (control.lua): killed by the player a bill of its is open to, that bill is struck.
function ledger.nest_died(nest, force)
  if not (force and storage.bases) then return end
  for _, b in pairs(storage.bases) do
    local L = b.ledger
    if L and L.owner == force.name and L.open then
      local struck = 0
      for i = #L.open, 1, -1 do
        local o = L.open[i]
        if o.nest == nest or (not (o.nest and o.nest.valid) and o.at[1] == nest.position.x and o.at[2] == nest.position.y) then
          struck = struck + o.cost
          table.remove(L.open, i)
        end
      end
      if struck > 0 then
        unmark(L, {nest.position.x, nest.position.y})
        local before = L.owed
        L.owed = math.max(0, L.owed - struck)
        L.disputed = (L.disputed or 0) + (before - L.owed)
        L.bills = #L.open
        b.disputed = (b.disputed or 0) + 1
        standing.incident(b.corp, "invoice disputed", nest.position, string.format("%d struck", math.ceil(before - L.owed)))
        base.trace(b, string.format("ledger: %s killed the nest at %.0f,%.0f its bill named; %d struck (owed %d)", force.name,
          nest.position.x, nest.position.y, math.ceil(before - L.owed), math.ceil(L.owed)))
        if L.owed <= 0 then close(b, "disputed: nothing owed") else draw(b, L) end
      end
    end
  end
end

-- Overdue: a collection, by force. Its raid weighs the billed player's buildings by the polluter the oldest open bill
-- named (ops.collect_weight), comes within COLLECT_SOON, and closes the bills when it goes (ops.on_collect).
function ledger.collect(b, L)
  local at
  for _, o in ipairs(L.open or {}) do if o.from then at = o.from break end end
  if not at then
    local sp = game.forces[L.owner].get_spawn_position(game.surfaces[b.surface])
    at = {sp.x, sp.y}
  end
  b.collect = {owner = L.owner, at = at, since = game.tick, till = game.tick + COLLECT_TICKS}
  b.next_op = math.min(b.next_op or 0, game.tick + COLLECT_SOON)
  -- (Or nought: a ledger opened before 0.2.325 has none; the multiplayer check's save of 2026-11-06 stopped here.)
  L.collections = (L.collections or 0) + 1
  b.collections = (b.collections or 0) + 1
  local f = game.forces[L.owner]
  if f then shared.notice(f, {"lp.invoice-overdue", shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", at[1], at[2],
    game.surfaces[b.surface].name)}) end
  standing.incident(b.corp, "invoice overdue", {x = at[1], y = at[2]}, string.format("%d owed: a collection", math.ceil(L.owed)))
  base.trace(b, string.format("ledger: overdue (%d owed); a collection on %s round %.0f,%.0f", math.ceil(L.owed), L.owner, at[1], at[2]))
  draw(b, L)
end

-- The target weight a collection gives (ops.relevance): the billed player's, within reach of the polluter.
function ops.collect_weight(b, t)
  local c = b.collect
  if not (c and game.tick < c.till and t.owner == c.owner and t.pos) then return 1 end
  local x, y = t.pos[1] or t.pos.x, t.pos[2] or t.pos.y
  if (x - c.at[1]) ^ 2 + (y - c.at[2]) ^ 2 > COLLECT_REACH * COLLECT_REACH then return 1 end
  return COLLECT_WEIGHT
end

-- The collection's raid went (ops.launch): the bills are collected.
function ops.on_collect(b)
  local L = b.ledger
  b.collect = nil
  b.collected = (b.collected or 0) + 1
  if not L then return end
  base.trace(b, string.format("ledger: the collection raid goes; %d owed collected", math.ceil(L.owed)))
  L.owed, L.bills, L.open, L.due = 0, 0, {}, nil
  unmark(L)
  if L.post and L.post.valid then L.post.destroy() end
  for _, o in ipairs(L.draw or {}) do if o.valid then o.destroy() end end
  L.post, L.draw = nil, nil
end

-- Tests and screenshots: a bill of `cost` to `owner` now, the post raised.
function ledger.debug(b, owner, cost)
  local L = b.ledger or {owner = owner, owed = 0, billed = 0, paid = 0, bills = 0, total_bills = 0, round = 0, paid_off = 0,
    collections = 0}
  b.ledger = L
  L.due = L.due or game.tick + OVERDUE
  L.owed, L.billed, L.bills, L.total_bills = L.owed + cost, L.billed + cost, L.bills + 1, L.total_bills + 1
  raise_post(b, L)
  draw(b, L)
  return L.post and L.post.valid and {L.post.position.x, L.post.position.y} or nil
end

function ledger.stats(b)
  local L = b.ledger
  return {owed = L and math.ceil(L.owed) or 0, billed = L and L.billed or 0, paid = L and L.paid or 0,
    bills = L and L.total_bills or 0, open = L and L.bills or 0, paid_off = L and L.paid_off or 0,
    collections = b.collections or 0, collecting = b.collect ~= nil and game.tick < b.collect.till,
    collected = b.collected or 0,
    post = L and L.post and L.post.valid and L.post.position or nil, owner = L and L.owner,
    open_bills = L and L.open and table_size(L.open) or 0, disputed = b.disputed or 0,
    marked = (function() local n = 0 for _, list in pairs(L and L.marks or {}) do if list[1] and list[1].valid then n = n + 1 end end return n end)(),
    nests = L and L.open and (function() local out = {} for _, o in ipairs(L.open) do out[#out + 1] = {at = o.at, cost = o.cost} end return out end)() or {}}
end

return ledger
