-- The skim (Grubstake; Fable's fortress consult, docs/reviews/2026-10-19-grubstake-fortress-consult.md: "aim for 'I
-- am being skimmed', never 'I am besieged': the fortress holds, and still the sums do not add up"; the user, 2026-10-19:
-- "Why not a truck simply going to the belt, hovering part of the items, filling its own trunk, then leaving?"). A
-- sealed fortress cannot wall in what feeds it. A camp sends a truck to a player's belt that carries something and that
-- no turret reaches, by a route clear of every turret's reach (ops.route, the heist's). The truck parks by the belt and
-- lifts FRACTION of what passes into its trunk (the tell: the truck parked there, the gaps on the belt), until the trunk holds
-- TRUNK or PARK has passed, then drives home: the goods go into the camp's yard (lp-skim-yard, a chest with the goods'
-- icon over it), as real items, and their worth into its parts. Kill the truck and its load spills where it stopped;
-- destroy the yard and what it holds spills. It comes back after AGAIN.
-- Counters: an underground across the exposed stretch (only a belt tile is skimmed), a turret by the belt, hunting the
-- truck, raiding the yard. A theft (stance: a rival thief steals; a truce stops it).
local shared = require("__landing-party__.shared")
local tune = require("__landing-party__.scripts.tune")
local base = require("__landing-party__.scripts.base")
local stance = require("__landing-party__.scripts.stance")
local ops = require("__landing-party__.scripts.ops")

local skim = {}

local RINGS = {150, 300, 500}      -- belts sought this near the camp's home, nearest ring first (250 alone found none on
                                  -- nw: its camps stood further from every belt)
local SAFE = 30                   -- no player turret this near the belt
local FRACTION = 0.5              -- of what passes (the user: "Take should be at least 50%"; 15% took 16 items a stop)
local TRUNK = 120                 -- items, a full trunk
local PARK = 5 * 3600             -- the longest it stays at the belt
local AGAIN = 5 * 3600            -- after a run home
local COOLDOWN = 20 * 3600        -- after a truck lost
local NONE = 5 * 3600             -- after finding nothing
local DRIVE = 60 * 60             -- a truck no nearer for this long is stuck
local CANDIDATES = 300            -- belts looked at a ring

local function home_of(b)
  for _, d in ipairs(b.depots or {}) do if d.valid then return d end end
  return b.lander
end

local function go(u, pos, radius)
  u.commandable.set_command{type = defines.command.go_to_location, destination = pos, radius = radius or 2,
    distraction = defines.distraction.none}
end

local function goods_value(goods)
  local v = 0
  for _, it in pairs(goods) do v = v + it.count * (ops.LOOT_VALUE[it.name] or 0.1) end
  return v
end

local function spill(surface, pos, goods)
  for _, it in pairs(goods or {}) do
    if it.count > 0 then
      surface.spill_item_stack{position = pos, stack = {name = it.name, count = it.count, quality = it.quality}, enable_looted = true}
    end
  end
end

-- The camp's yard: a chest by its home, the icon of what it holds most drawn over it.
local function yard(b)
  if b.skim_yard and b.skim_yard.valid then return b.skim_yard end
  local h = home_of(b)
  if not (h and h.valid) then return nil end
  local s = h.surface
  local p = s.find_non_colliding_position("lp-skim-yard", {h.position.x - 8, h.position.y + 8}, 16, 1)
  local e = p and s.create_entity{name = "lp-skim-yard", position = p, force = h.force}
  b.skim_yard = e
  return e
end

local function yard_icon(b)
  local y = b.skim_yard
  if not (y and y.valid) then return end
  local most, n
  for _, it in pairs(y.get_inventory(defines.inventory.chest).get_contents()) do
    if not n or it.count > n then most, n = it.name, it.count end
  end
  if b.skim_icon and b.skim_icon.valid then b.skim_icon.destroy() end
  b.skim_icon = most and rendering.draw_sprite{sprite = "item/" .. most, surface = y.surface,
    target = {entity = y, offset = {0, -1.2}}, x_scale = 0.8, y_scale = 0.8} or nil
end

-- A belt the camp could skim: the player's, carrying something, no turret within SAFE, within a ring of RINGS; the
-- nearest it can reach unseen.
local function candidates(b, owner)
  local h = home_of(b)
  local s = h.surface
  local out = {}
  local seen, carrying = 0, 0
  for _, r in ipairs(RINGS) do
    for _, e in pairs(s.find_entities_filtered{type = "transport-belt", force = owner, position = h.position, radius = r,
      limit = CANDIDATES}) do
      local n = e.get_transport_line(1).get_item_count() + e.get_transport_line(2).get_item_count()
      seen = seen + 1
      if n > 0 then carrying = carrying + 1 end
      if n > 0 and s.count_entities_filtered{position = e.position, radius = SAFE, force = owner,
        type = {"ammo-turret", "electric-turret", "fluid-turret"}, limit = 1} == 0 and not ops.marked(b, {e.position.x, e.position.y}) then
        local d = (e.position.x - h.position.x) ^ 2 + (e.position.y - h.position.y) ^ 2
        table.insert(out, {e, d})
      end
    end
    if #out > 0 then break end
  end
  table.sort(out, function(x, y) return x[2] < y[2] end)
  b.skim_seen = {seen, carrying}
  return out
end

-- Whether the straight way from the camp to a belt passes no player turret's reach (sampled every 25 tiles): a belt
-- behind the ring has no turret within SAFE of itself but turrets between it and the camp (on nw the three nearest
-- exposed belts all lay inside the laser ring, "no route" each time). Only those with a clear line are routed.
local LINE_STEP, LINE_TRIES = 25, 40
local function clear_line(s, owner, from, to)
  local dx, dy = to.x - from.x, to.y - from.y
  local len = math.sqrt(dx * dx + dy * dy)
  for d = 0, len, LINE_STEP do
    local p = {from.x + dx * d / len, from.y + dy * d / len}
    if s.count_entities_filtered{position = p, radius = SAFE, force = owner,
      type = {"ammo-turret", "electric-turret", "fluid-turret"}, limit = 1} > 0 then return false end
  end
  return true
end

local function over(b, why, cool)
  local k = b.skim
  if k then
    if k.truck and k.truck.valid then k.truck.destroy() end
    base.trace(b, string.format("skim over: %s (%d items taken)", why, k.taken or 0))
  end
  b.skim = nil
  b.next_skim = game.tick + (cool or (storage.skim_cooldown or tune.sooner(b.corp, COOLDOWN)))
end

function skim.launch(b, belt)
  local h = home_of(b)
  if not (h and h.valid and belt and belt.valid) then return "no belt" end
  local route = ops.route(b, {h.position.x, h.position.y}, {belt.position.x, belt.position.y}, {turrets = true})
  if not route then return "no route" end
  local s = h.surface
  local name = shared.variant(b.corp, "lp-hauler")
  local p = s.find_non_colliding_position(name, {h.position.x, h.position.y + 12}, 20, 1)
  local u = p and s.create_entity{name = name, position = p, force = h.force}
  if not u then return "no room for a truck" end
  b.skim = {phase = "out", belt = belt, owner = belt.force.name, truck = u, best = math.huge, best_at = game.tick, taken = 0,
    acc = 0, load = {}}
  go(u, belt.position, 3)
  b.skims = (b.skims or 0) + 1
  base.trace(b, string.format("skim %d: a truck goes for a belt at %.0f,%.0f", b.skims, belt.position.x, belt.position.y))
  return "launched"
end

local function arrived(k, u, pos, r)
  local p = u.position
  local d = (p.x - pos.x) ^ 2 + (p.y - pos.y) ^ 2
  if d < k.best - 1 then k.best, k.best_at = d, game.tick end
  return d <= r * r
end

-- What a full belt of this tier carries a second (items, both lanes).
local function full_rate(belt)
  return belt.prototype.belt_speed * 60 * 4 * 2
end

local function count(load)
  local n = 0
  for _, it in pairs(load) do n = n + it.count end
  return n
end

-- FRACTION of what passes: the flow is the tile's fill (8 items when full) times a full belt's rate (15% of a full
-- belt's rate whatever the belt carried took far more than its share of a thin flow, scenario).
local function siphon(k)
  local room = TRUNK - count(k.load)
  local n = k.belt.get_transport_line(1).get_item_count() + k.belt.get_transport_line(2).get_item_count()
  k.acc = k.acc + FRACTION * math.min(1, n / 8) * full_rate(k.belt)
  local want = math.min(math.floor(k.acc), room)
  if want <= 0 then return end
  k.acc = k.acc - want
  -- The most valuable first (as Fulgora Replicators' raiders take from belts; the user pointed to it, 2026-10-19).
  for line = 1, 2 do
    local tl = k.belt.get_transport_line(line)
    local items = {}
    for _, it in pairs(tl.get_contents()) do table.insert(items, it) end
    table.sort(items, function(x, y) return (ops.LOOT_VALUE[x.name] or 0.1) > (ops.LOOT_VALUE[y.name] or 0.1) end)
    for _, it in ipairs(items) do
      if want <= 0 then break end
      local took = tl.remove_item{name = it.name, count = math.min(want, it.count), quality = it.quality}
      if took > 0 then
        local key = it.name .. "|" .. (it.quality or "normal")
        local g = k.load[key] or {name = it.name, quality = it.quality or "normal", count = 0}
        g.count = g.count + took
        k.load[key] = g
        want, k.taken = want - took, k.taken + took
      end
    end
  end
end

local function home_run(b, k, why)
  k.phase, k.best, k.best_at = "home", math.huge, game.tick
  go(k.truck, home_of(b).position, 10)
  base.trace(b, string.format("skim: the truck leaves the belt with %d items (%s)", count(k.load), why))
end

local function step(b, k)
  local u = k.truck
  if not u.valid then
    spill(game.surfaces[b.surface], k.last or (k.belt.valid and k.belt.position) or b.origin, k.load)
    return over(b, count(k.load) > 0 and "the truck was lost; its load spilled" or "the truck was lost")
  end
  local p = u.position
  k.last = {x = p.x, y = p.y}
  if k.phase == "out" then
    if not k.belt.valid then return over(b, "the belt is gone", NONE) end
    if arrived(k, u, k.belt.position, 4) then
      k.phase, k.parked = "skim", game.tick
      base.trace(b, string.format("skim: the truck parks by the belt at %.0f,%.0f", k.belt.position.x, k.belt.position.y))
    elseif game.tick - k.best_at > DRIVE then
      return over(b, "the truck got stuck", NONE)
    end
  elseif k.phase == "skim" then
    if not k.belt.valid then return home_run(b, k, "the belt is gone") end
    siphon(k)
    if count(k.load) >= TRUNK then home_run(b, k, "full")
    elseif game.tick - k.parked >= PARK then home_run(b, k, "time") end
  elseif arrived(k, u, home_of(b).position, 18) then
    local goods = {}
    for _, g in pairs(k.load) do table.insert(goods, g) end
    local v = goods_value(goods)
    ops.stash(b, goods)
    b.parts = b.parts + math.floor(v)
    b.skimmed = (b.skimmed or 0) + count(k.load)
    base.trace(b, string.format("skim: the truck home with %d items (worth %d)", count(k.load), math.floor(v)))
    u.destroy()
    over(b, "home", storage.skim_cooldown or AGAIN)
  elseif game.tick - k.best_at > DRIVE then
    spill(u.surface, u.position, k.load)
    return over(b, "the truck got stuck on the way home; its load left there", NONE)
  end
end

local function consider(b)
  if storage.skim_off or not (shared.CORPS[b.corp].temper or {}).skims then return end
  if b.fallen or b.quiescent or not b.mature or game.tick < (b.next_skim or 0) then return end
  -- Any player force it may steal from (stance), whether or not its intel knows one of its targets: it finds the belts
  -- itself (war.at_war asked intel, and a young camp knew none: no skim in 30 minutes, scenario).
  local owner
  for _, f in ipairs(shared.player_forces()) do
    if stance.may(b.corp, f.name, "skim") then owner = f.name break end
  end
  if not owner then return end
  local cands = candidates(b, owner)
  local why
  local h = home_of(b)
  local tried, lines = 0, 0
  for i = 1, math.min(LINE_TRIES, #cands) do
    local e = cands[i][1]
    if clear_line(e.surface, owner, h.position, e.position) then
      lines = lines + 1
      why = skim.launch(b, e)
      if why == "launched" then return end
      tried = tried + 1
      if tried >= 3 then break end
    end
  end
  if #cands > 0 and lines == 0 then why = string.format("every line to them crosses a turret's reach (%d looked at)",
    math.min(LINE_TRIES, #cands)) end
  if game.tick >= (b.skim_said or 0) then
    b.skim_said = game.tick + 30 * 3600
    local sn = b.skim_seen or {0, 0}
    base.trace(b, string.format("skim: none (%d exposed belts carrying in reach, of %d belts looked at, %d carrying%s)", #cands,
      sn[1], sn[2], why and (", the last: " .. why) or ""))
  end
  b.next_skim = game.tick + NONE
end

-- A raid's loot home (ops.finish): into the yard, the rest spilled by it.
function ops.stash(b, goods)
  local y = yard(b)
  if not y then return end
  local inv = y.get_inventory(defines.inventory.chest)
  for _, g in pairs(goods) do
    if g.count > 0 then
      local put = inv.insert{name = g.name, count = g.count, quality = g.quality}
      if put < g.count then spill(y.surface, y.position, {{name = g.name, count = g.count - put, quality = g.quality}}) end
    end
  end
  yard_icon(b)
end

-- The yard destroyed: what it held spills (the player takes back what was stolen).
function skim.died(ent)
  if ent.name ~= "lp-skim-yard" then return end
  local inv = ent.get_inventory(defines.inventory.chest)
  if not inv then return end
  local goods = {}
  for _, it in pairs(inv.get_contents()) do table.insert(goods, {name = it.name, count = it.count, quality = it.quality}) end
  spill(ent.surface, ent.position, goods)
end

function skim.debug(b, pos)
  local belt = game.surfaces[b.surface].find_entities_filtered{type = "transport-belt", force = shared.player_forces(),
    position = pos, radius = 4, limit = 1}[1]
  return skim.launch(b, belt)
end

function skim.state(b)
  local k = b.skim
  local y = b.skim_yard
  return {phase = k and k.phase, taken = k and k.taken or 0, skims = b.skims or 0, skimmed = b.skimmed or 0,
    parked = k and k.phase == "skim" and k.truck and k.truck.valid and {k.truck.position.x, k.truck.position.y} or nil,
    yard = y and y.valid and y.get_inventory(defines.inventory.chest).get_item_count() or 0,
    truck = k and k.truck and k.truck.valid or false}
end

function skim.tick(tick)
  if tick % 60 ~= 29 then return end
  for _, b in pairs(storage.bases or {}) do
    if b.skim then
      step(b, b.skim)
    elseif tick % 600 == 29 + 60 * 7 then
      consider(b)
    end
  end
end

return skim
