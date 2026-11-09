-- The lightning's stun on units (the user, 2026-11-09: "a stun effect with Tesla weapons in the mod also affecting units?
-- Would have to not be 100% to be fair ... increasing with repeating attacks until stunned, with passive decrease"). Every
-- electric hit on a unit (Kessler-Hayashi's Tesla and shock trooper, the player's tesla turret and tesla gun, a destroyer)
-- charges it by one, less its electric resistance (read from its prototype: a tank's 80% makes it hard to stun, infantry
-- easy). The charge halves every STUN.HALF ticks, worked out at the next hit, so nothing runs between hits. A hit stuns
-- with chance (charge - 1) / SPAN, at most MAX: the first never does. Stunned, the unit is switched off (no move, no shot)
-- for STUN.TICKS under a sticker of arcing current, and cannot be stunned again for STUN.IMMUNE after.
-- storage.stun: unit number -> {c = charge, t = tick of the charge, till = stunned until, free = stunnable again from}.
local shared = require("__landing-party__.shared")
local rng = require("__landing-party__.scripts.rng")

local stun = {}
local S = shared.STUN

local function st()
  storage.stun = storage.stun or {}
  storage.stun_rng = storage.stun_rng or rng.new(20261109)
  storage.stunned = storage.stunned or {}
  return storage.stun
end

local resist, hull = {}, {}
local function is_hull(u)
  local name = u.name
  if hull[name] == nil then
    local cb = u.prototype.collision_box
    local rb = cb.right_bottom or cb[2]
    hull[name] = (rb.x or rb[1]) > S.HULL_WIDTH
  end
  return hull[name]
end
-- The charge a hit leaves: one, less its electric resistance, a hull's HULL of that.
local function share_of(u)
  local name = u.name
  if resist[name] == nil then
    local r = u.prototype.resistances
    local e = r and r.electric
    resist[name] = (1 - (e and e.percent or 0)) * (is_hull(u) and S.HULL or 1)
  end
  return resist[name]
end

-- One electric hit (on_entity_damaged, filtered to units and electric damage in control.lua).
function stun.on_hit(e)
  local u = e.entity
  if not (u and u.valid and u.type == "unit" and u.unit_number) then return end
  local all, tick = st(), game.tick
  local by = storage.stun_by or {}
  storage.stun_by = by
  local b = by[u.name] or {hits = 0, stuns = 0}
  by[u.name] = b
  b.hits = b.hits + 1
  if e.final_health <= 0 then return end
  local k = u.unit_number
  local h = all[k]
  if not h then h = {c = 0, t = tick, free = 0, n = 0}; all[k] = h end
  h.c = h.c * 0.5 ^ ((tick - h.t) / S.HALF) + share_of(u)
  h.t, h.n = tick, h.n + 1
  if h.till or tick < h.free then return end
  local p = math.min(S.MAX, (h.c - 1) / S.SPAN)
  if p > (b.pmax or 0) then b.pmax = p end
  if p <= 0 or rng.next(storage.stun_rng) >= p then return end
  h.till, h.free = tick + S.TICKS, tick + S.TICKS + S.IMMUNE
  b.stuns = b.stuns + 1
  if h.n == 1 then storage.stun_first = (storage.stun_first or 0) + 1 end
  if h.last and (not storage.stun_gap or tick - h.last < storage.stun_gap) then storage.stun_gap = tick - h.last end
  h.last = tick
  u.disabled_by_script = true
  u.surface.create_entity{name = is_hull(u) and S.fx_big or S.fx, position = u.position, target = u}
  storage.stunned[k] = {e = u, till = h.till, at = tick}
  storage.stuns = (storage.stuns or 0) + 1
end

function stun.tick(tick)
  local list = storage.stunned
  if not list or next(list) == nil then return end
  for k, s in pairs(list) do
    if not s.e.valid then
      list[k] = nil
    elseif tick >= s.till then
      s.e.disabled_by_script = false
      list[k] = nil
      local h = storage.stun[k]
      if h then h.till = nil end
    end
  end
  -- Forget the charges of the dead, and those long since spent.
  if tick % 3600 == 11 then
    for k, h in pairs(storage.stun or {}) do
      if not h.till and tick - h.t > 8 * S.HALF and tick >= h.free then storage.stun[k] = nil end
    end
  end
end

function stun.stats()
  return {stuns = storage.stuns or 0, stunned = table_size(storage.stunned or {}), charged = table_size(storage.stun or {}),
    by = storage.stun_by or {}, first = storage.stun_first or 0, gap = storage.stun_gap}
end

-- Since when a unit has been stunned (nil if it is not).
function stun.since(k)
  local s = storage.stunned and storage.stunned[k]
  return s and s.at
end

return stun
