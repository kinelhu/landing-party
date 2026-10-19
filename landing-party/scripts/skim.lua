-- The skim (Grubstake; Fable's fortress consult, docs/reviews/2026-10-19-grubstake-fortress-consult.md: "aim for 'I
-- am being skimmed', never 'I am besieged': the fortress holds, and still the sums do not add up"). A sealed fortress
-- cannot wall in what feeds it. A camp sends a buggy to a player's belt that no turret reaches and that carries
-- something, by a route clear of every turret's reach (ops.route, the heist's), and the buggy drops a siphon shack
-- beside it (lp-skim-shack, a chest in Grubstake's colour, an arm drawn to the belt). Each second the shack lifts
-- FRACTION of what passes off the belt, into itself. When it holds HAUL, a truck drives out,
-- empties it and takes the goods home to the camp's yard (lp-skim-yard, a chest with the goods' icon over it): there they
-- stay, as real items, and add their worth to the camp's parts. Destroy the yard and they spill on the ground; kill the
-- truck and its load spills where it fell.
-- Counters: an underground across the exposed stretch (only a belt tile is skimmed), a turret by the belt (the shack is
-- an enemy building), raiding the yard. A theft (stance: a rival thief steals; a truce stops it).
local shared = require("__landing-party__.shared")
local tune = require("__landing-party__.scripts.tune")
local base = require("__landing-party__.scripts.base")
local stance = require("__landing-party__.scripts.stance")
local ops = require("__landing-party__.scripts.ops")
local pool = require("__landing-party__.scripts.pool")

local skim = {}

local RANGE = 250                 -- a belt this near the camp's home
local SAFE = 30                   -- no player turret this near the belt
local FRACTION = 0.15             -- of a full belt's flow
local HAUL = 40                   -- items in the shack before a truck goes
local COST = 10                   -- parts: the shack
local COOLDOWN = 20 * 3600        -- after a shack is lost
local NONE = 5 * 3600             -- after finding nothing
local DRIVE = 60 * 60             -- a vehicle no nearer for this long is stuck
local CANDIDATES = 400            -- belts looked at a search
local AMBER = {0.85, 0.5, 0.2, 0.9}

local function home_of(b)
  for _, d in ipairs(b.depots or {}) do if d.valid then return d end end
  return b.lander
end

local function buggy(b)
  for i = #b.garrison, 1, -1 do
    local u = b.garrison[i]
    if u.valid and shared.kind_of(u.name) == "lp-buggy" then return table.remove(b.garrison, i) end
  end
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

-- A belt the camp could skim: the player's, carrying something, no turret within SAFE, within RANGE of home; the
-- nearest it can reach unseen.
local function candidates(b, owner)
  local h = home_of(b)
  local s = h.surface
  local out = {}
  for _, e in pairs(s.find_entities_filtered{type = "transport-belt", force = owner, position = h.position, radius = RANGE,
    limit = CANDIDATES}) do
    local n = e.get_transport_line(1).get_item_count() + e.get_transport_line(2).get_item_count()
    if n > 0 and s.count_entities_filtered{position = e.position, radius = SAFE, force = owner,
      type = {"ammo-turret", "electric-turret", "fluid-turret"}, limit = 1} == 0 and not ops.marked(b, {e.position.x, e.position.y}) then
      local d = (e.position.x - h.position.x) ^ 2 + (e.position.y - h.position.y) ^ 2
      table.insert(out, {e, d})
    end
  end
  table.sort(out, function(x, y) return x[2] < y[2] end)
  return out
end

local function over(b, why, cool)
  local k = b.skim
  if k then
    if k.buggy and k.buggy.valid then
      pool.give_one(b, k.buggy)
      local h = home_of(b)
      if h and h.valid then go(k.buggy, h.position, 8) end
    end
    if k.arm and k.arm.valid then k.arm.destroy() end
    if k.truck and k.truck.valid then k.truck.destroy() end
    base.trace(b, string.format("skim over: %s (%d items taken)", why, k.taken or 0))
  end
  b.skim = nil
  b.next_skim = game.tick + (cool or (storage.skim_cooldown or tune.sooner(b.corp, COOLDOWN)))
end

function skim.launch(b, belt)
  local h = home_of(b)
  if not (h and h.valid and belt and belt.valid) then return "no belt" end
  if b.parts < COST then return "short of parts" end
  local route = ops.route(b, {h.position.x, h.position.y}, {belt.position.x, belt.position.y}, {turrets = true})
  if not route then return "no route" end
  local u = buggy(b)
  if not u then return "no buggy" end
  b.parts = b.parts - COST
  b.skim = {phase = "out", belt = belt, owner = belt.force.name, buggy = u, best = math.huge, best_at = game.tick, taken = 0,
    acc = 0, started = game.tick}
  go(u, belt.position, 3)
  b.skims = (b.skims or 0) + 1
  base.trace(b, string.format("skim %d: a buggy goes for a belt at %.0f,%.0f", b.skims, belt.position.x, belt.position.y))
  return "launched"
end

local function arrived(k, u, pos, r)
  local p = u.position
  local d = (p.x - pos.x) ^ 2 + (p.y - pos.y) ^ 2
  if d < k.best - 1 then k.best, k.best_at = d, game.tick end
  return d <= r * r
end

local function drop(b, k)
  local s = k.belt.surface
  local p = s.find_non_colliding_position("lp-skim-shack", k.belt.position, 3, 0.5)
  local e = p and s.create_entity{name = "lp-skim-shack", position = p, force = b.lander.force}
  if not e then return over(b, "no room by the belt", NONE) end
  k.shack, k.phase = e, "skim"
  k.arm = rendering.draw_line{from = e, to = k.belt, surface = s, color = AMBER, width = 3}
  pool.give_one(b, k.buggy)
  go(k.buggy, home_of(b).position, 8)
  k.buggy = nil
  base.trace(b, string.format("skim: a shack by the belt at %.0f,%.0f", k.belt.position.x, k.belt.position.y))
end

-- What a full belt of this tier carries a second (items, both lanes).
local function full_rate(belt)
  return belt.prototype.belt_speed * 60 * 4 * 2
end

-- FRACTION of what passes: the flow is the tile's fill (8 items when full) times a full belt's rate (15% of a full
-- belt's rate whatever the belt carried took 51% of a thin flow, scenario).
local function siphon(k)
  local inv = k.shack.get_inventory(defines.inventory.chest)
  local n = k.belt.get_transport_line(1).get_item_count() + k.belt.get_transport_line(2).get_item_count()
  k.acc = k.acc + FRACTION * math.min(1, n / 8) * full_rate(k.belt)
  local want = math.floor(k.acc)
  if want <= 0 then return end
  k.acc = k.acc - want
  for line = 1, 2 do
    local tl = k.belt.get_transport_line(line)
    for _, it in pairs(tl.get_contents()) do
      if want <= 0 then break end
      local stack = {name = it.name, count = math.min(want, it.count), quality = it.quality}
      local room = inv.get_insertable_count(stack)
      stack.count = math.min(stack.count, room)
      if stack.count > 0 then
        local took = tl.remove_item(stack)
        if took > 0 then
          inv.insert{name = it.name, count = took, quality = it.quality}
          want, k.taken = want - took, k.taken + took
        end
      end
    end
  end
end

local function send_truck(b, k)
  local h = home_of(b)
  local s = h.surface
  local name = shared.variant(b.corp, "lp-hauler")
  local p = s.find_non_colliding_position(name, {h.position.x, h.position.y + 12}, 20, 1)
  local u = p and s.create_entity{name = name, position = p, force = h.force}
  if not u then return end
  k.truck, k.truck_phase, k.best, k.best_at = u, "out", math.huge, game.tick
  go(u, k.shack.position, 4)
end

local function truck_step(b, k)
  local u = k.truck
  if not u.valid then
    spill(game.surfaces[b.surface], k.truck_last or k.shack.position, k.load)
    if k.load then base.trace(b, "skim: the truck was lost; its load spilled") end
    k.truck, k.load = nil, nil
    return
  end
  local p = u.position
  k.truck_last = {x = p.x, y = p.y}
  if game.tick - k.best_at > DRIVE then u.destroy(); k.truck = nil; return end
  if k.truck_phase == "out" then
    if not (k.shack and k.shack.valid) then k.truck_phase = "home"; go(u, home_of(b).position, 10); return end
    if arrived(k, u, k.shack.position, 6) then
      local inv = k.shack.get_inventory(defines.inventory.chest)
      local load = {}
      for _, it in pairs(inv.get_contents()) do table.insert(load, {name = it.name, count = it.count, quality = it.quality}) end
      inv.clear()
      k.load, k.truck_phase, k.best, k.best_at = load, "home", math.huge, game.tick
      go(u, home_of(b).position, 10)
    end
  elseif arrived(k, u, home_of(b).position, 18) then
    local y = yard(b)
    local v = goods_value(k.load or {})
    if y then
      local inv = y.get_inventory(defines.inventory.chest)
      for _, it in ipairs(k.load or {}) do
        local put = inv.insert(it)
        if put < it.count then spill(y.surface, y.position, {{name = it.name, count = it.count - put, quality = it.quality}}) end
      end
      yard_icon(b)
    end
    b.parts = b.parts + math.floor(v)
    local n = 0
    for _, it in ipairs(k.load or {}) do n = n + it.count end
    b.skimmed = (b.skimmed or 0) + n
    base.trace(b, string.format("skim: a truck home with %d items (worth %d)", n, math.floor(v)))
    u.destroy()
    k.truck, k.load = nil, nil
  end
end

local function step(b, k)
  if k.phase == "out" then
    if not k.buggy.valid then return over(b, "the buggy was lost on the way") end
    if not k.belt.valid then return over(b, "the belt is gone", NONE) end
    if arrived(k, k.buggy, k.belt.position, 4) then return drop(b, k) end
    if game.tick - k.best_at > DRIVE then return over(b, "the buggy got stuck", NONE) end
    return
  end
  if not k.shack.valid then
    -- Its tell is the wreck; no notice (the user: the world tells).
    return over(b, "the shack was destroyed")
  end
  if not k.belt.valid then
    if k.shack.get_inventory(defines.inventory.chest).is_empty() then k.shack.destroy() end
    return over(b, "the belt is gone", NONE)
  end
  siphon(k)
  if k.truck then truck_step(b, k)
  elseif k.shack.get_inventory(defines.inventory.chest).get_item_count() >= HAUL then send_truck(b, k) end
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
  for i = 1, math.min(3, #cands) do
    why = skim.launch(b, cands[i][1])
    if why == "launched" then return end
  end
  if game.tick >= (b.skim_said or 0) then
    b.skim_said = game.tick + 30 * 3600
    base.trace(b, string.format("skim: none (%d exposed belts carrying in reach%s)", #cands, why and (", the last: " .. why) or ""))
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
  if ent.name ~= "lp-skim-yard" and ent.name ~= "lp-skim-shack" then return end
  local inv = ent.get_inventory(defines.inventory.chest)
  if not inv then return end
  local goods = {}
  for _, it in pairs(inv.get_contents()) do table.insert(goods, {name = it.name, count = it.count, quality = it.quality}) end
  spill(ent.surface, ent.position, goods)
end

function skim.debug(b, pos)
  local belt = game.surfaces[b.surface].find_entities_filtered{type = "transport-belt", force = shared.player_forces(),
    position = pos, radius = 4, limit = 1}[1]
  local has
  for _, u in ipairs(b.garrison) do if u.valid and shared.kind_of(u.name) == "lp-buggy" then has = true end end
  if not has and b.lander.valid then
    local s = b.lander.surface
    local name = shared.variant(b.corp, "lp-buggy")
    local q = s.find_non_colliding_position(name, b.lander.position, 20, 1)
    local u = q and s.create_entity{name = name, position = q, force = b.lander.force}
    if u then table.insert(b.garrison, u) end
  end
  return skim.launch(b, belt)
end

function skim.state(b)
  local k = b.skim
  local y = b.skim_yard
  return {phase = k and k.phase, taken = k and k.taken or 0, skims = b.skims or 0, skimmed = b.skimmed or 0,
    shack = k and k.shack and k.shack.valid and {k.shack.position.x, k.shack.position.y} or nil,
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
