-- The trade post (the rivals consult, slice 5: pay the thief). A player sets a trade post (a chest) and fills it; when it
-- holds enough, the nearest Grubstake camp sends a truck to empty it. What the truck carries (valued as loot is,
-- ops.LOOT_VALUE) buys a truce: a minute for each VALUE_PER_MINUTE, MIN_TRUCE to MAX_TRUCE. Under a truce Grubstake
-- launches no raid, flare or heist against that player (it still prospects and taps: it takes what you are not using).
-- The truck can be ambushed, by Serenity too if its road crosses Serenity's ground: then no truce, the goods spilled.
local shared = require("__landing-party__.shared")
local ops = require("__landing-party__.scripts.ops")
local standing = require("__landing-party__.scripts.standing")
local base = require("__landing-party__.scripts.base")

local trade = {}

local REACH = 700
local MIN_VALUE = 50
local VALUE_PER_MINUTE = 10
local MIN_TRUCE, MAX_TRUCE = 5, 120
local STUCK = 5 * 3600

local function value(contents)
  local v = 0
  for _, it in pairs(contents) do v = v + it.count * ((ops.LOOT_VALUE or {})[it.name] or 0.1) end
  return v
end

local function camp_near(pos, surface)
  local best, bd
  for _, b in pairs(storage.bases or {}) do
    if (shared.CORPS[b.corp].temper or {}).prospects and not b.fallen and b.lander and b.lander.valid
      and b.surface == surface and b.origin then
      local d = (b.origin.x - pos.x) ^ 2 + (b.origin.y - pos.y) ^ 2
      if d <= REACH * REACH and (not bd or d < bd) then best, bd = b, d end
    end
  end
  return best
end

local function home(b)
  for _, d in ipairs(b.depots or {}) do if d.valid then return d end end
  return b.lander
end

function trade.placed(ent)
  storage.posts = storage.posts or {}
  table.insert(storage.posts, {entity = ent, owner = ent.force.name})
end

function trade.truce(b, owner)
  local t = storage.truces and storage.truces[b.corp .. "|" .. owner]
  return t and game.tick < t
end
ops.truce = trade.truce
standing.truce = function(corp, owner)
  local t = storage.truces and storage.truces[corp .. "|" .. owner]
  return t and game.tick < t
end

local function step(post)
  local r = post.run
  local tick = game.tick
  if not r then
    local inv = post.entity.get_inventory(defines.inventory.chest)
    if value(inv.get_contents()) < MIN_VALUE then return end
    local b = camp_near(post.entity.position, post.entity.surface.index)
    if not b then return end
    local s = post.entity.surface
    local h = home(b)
    local name = shared.variant(b.corp, "lp-hauler")
    local p = s.find_non_colliding_position(name, {h.position.x, h.position.y + 12}, 20, 1)
    local u = p and s.create_entity{name = name, position = p, force = h.force}
    if not u then return end
    u.commandable.set_command{type = defines.command.go_to_location, destination = post.entity.position, radius = 4,
      distraction = defines.distraction.none}
    post.run = {unit = u, base = b.id, phase = "out", started = tick}
    base.trace(b, string.format("trade: a truck goes for the tribute at %.0f,%.0f", post.entity.position.x, post.entity.position.y))
    return
  end
  local b = storage.bases[r.base]
  if not r.unit.valid then
    if r.goods and #r.goods > 0 then
      for _, it in ipairs(r.goods) do
        post.entity.surface.spill_item_stack{position = r.last or post.entity.position, stack = {name = it.name, count = math.min(it.count, 200)},
          enable_looted = true}
      end
    end
    if b then standing.incident(b.corp, "tribute lost", r.last and {r.last[1], r.last[2]} or post.entity.position) end
    post.run = nil
    return
  end
  local p = r.unit.position
  r.last = {p.x, p.y}
  if tick - r.started > STUCK then r.unit.destroy(); post.run = nil; return end
  if r.phase == "out" and (p.x - post.entity.position.x) ^ 2 + (p.y - post.entity.position.y) ^ 2 < 8 * 8 then
    local inv = post.entity.get_inventory(defines.inventory.chest)
    local goods = {}
    for _, it in pairs(inv.get_contents()) do table.insert(goods, {name = it.name, count = it.count}) end
    local v = value(inv.get_contents())
    inv.clear()
    r.goods, r.value, r.phase = goods, v, "home"
    -- The truce, bought on collection.
    local minutes = math.max(MIN_TRUCE, math.min(MAX_TRUCE, math.floor(v / VALUE_PER_MINUTE)))
    storage.truces = storage.truces or {}
    local k = b.corp .. "|" .. post.owner
    storage.truces[k] = math.max(storage.truces[k] or 0, tick) + minutes * 3600
    storage.tributes = (storage.tributes or 0) + 1
    standing.incident(b.corp, "tribute", post.entity.position, string.format("%d minutes of truce", minutes))
    game.forces[post.owner].print({"lp.tribute", shared.corp_label(b.corp), tostring(minutes)})
    local h = home(b)
    r.unit.commandable.set_command{type = defines.command.go_to_location, destination = h.position, radius = 10,
      distraction = defines.distraction.none}
  elseif r.phase == "home" and b then
    local h = home(b)
    if h and h.valid and (p.x - h.position.x) ^ 2 + (p.y - h.position.y) ^ 2 < 18 * 18 then
      b.parts = b.parts + math.floor(r.value or 0)
      r.unit.destroy()
      post.run = nil
    end
  end
end

function trade.tick(tick)
  if tick % 60 ~= 53 or not storage.posts then return end
  for i = #storage.posts, 1, -1 do
    local post = storage.posts[i]
    if not post.entity.valid then
      if post.run and post.run.unit.valid then post.run.unit.destroy() end
      table.remove(storage.posts, i)
    else
      step(post)
    end
  end
end

function trade.stats()
  local truces = {}
  for k, t in pairs(storage.truces or {}) do truces[k] = math.max(0, math.floor((t - game.tick) / 60)) end
  return {tributes = storage.tributes or 0, truces = truces}
end

return trade
