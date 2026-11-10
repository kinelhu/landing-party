-- The unit pool (docs/ai.md, section 4): a settlement's units, wherever they are. Before it, a settlement's strength
-- counted only the units at home (its garrison and patrol), so units out on a raid, a heist or a response were made
-- again and the cap was not one; and units were put back into the garrison while still far off, to be drafted again
-- at once from wherever they stood.
--   roster      every unit the settlement owns (storage.unit_owner points the other way), out or home
--   strength    the roster's live count: what the cap holds
--   give        units done with a job: into the garrison when home, else on their way back (b.returning) until they are
--   take        units for a job, from the garrison, never below a floor
-- A leaf: it reads storage and the settlement only, and promotes at the homecoming (veterancy.lua, a leaf too).
local shared = require("__landing-party__.shared")
local veterancy = require("__landing-party__.scripts.veterancy")
local pool = {}

local HOME = 40                    -- a unit within this of the lander or a depot is home

-- What stays home (docs/ai.md 2.3: each taker had its own floor, 2, 30% of the cap or none). One rule now:
--   guard    pool.GUARD units always stay: what defends the camp itself (responses, intercepts) and its own small
--            details (patrols, escorts) take down to it, and so does an operation that commits the reserve (a battery
--            shelling it, a threat, the ladder's top rung, an answer, a siege's assault)
--   reserve  pool.RESERVE of the cap, at least the guard: what an operation of choice leaves home
-- A heist's buggy (flare, tap) is taken without a floor: one, and the heist is its whole job.
pool.GUARD = 2
pool.RESERVE = 0.3

function pool.floor(cap, kind)
  if kind == "reserve" then return math.max(pool.GUARD, math.ceil(pool.RESERVE * cap)) end
  return pool.GUARD
end

-- Haulers are not counted (they carry, they do not fight). Buggies are: most of Grubstake's army (a camp of 27 had 20).
local function counts(u) return u.valid and shared.kind_of(u.name) ~= "lp-hauler" end

-- Units at home that count against a floor.
function pool.home(b)
  local n = 0
  for _, u in ipairs(b.garrison) do if counts(u) then n = n + 1 end end
  return n
end

-- Up to n units from the garrison (the last first, as every taker did) that pass `fit`, leaving at least `floor` units
-- home. Removed from the garrison and returned; the caller gives them their orders.
function pool.take(b, n, floor, fit)
  local home = pool.home(b)
  local taken = {}
  for i = #b.garrison, 1, -1 do
    if #taken >= n or home <= floor then break end
    local u = b.garrison[i]
    if u.valid and (not fit or fit(u)) then
      table.insert(taken, table.remove(b.garrison, i))
      if counts(u) then home = home - 1 end
    end
  end
  -- Out through its own gates: they open as units leave (army.gates holds them open while units on the way pass). A
  -- unit plans its path when it gets its order, and opened only once a unit was by it, a gate stayed in its way: the
  -- raid stood in the yard (gates).
  if #taken > 0 and not storage.gates_off then
    b.gates_until = game.tick + 2 * 3600
    for _, g in ipairs(b.gate_list or {}) do if g.valid then g.request_to_open(g.force, 15 * 60) end end
  end
  return taken
end

-- Every unit the settlement owns joins the roster here (and storage.unit_owner).
function pool.enlist(b, u)
  storage.unit_owner[u.unit_number] = b.id
  b.roster = b.roster or {}
  b.roster[u.unit_number] = u
end

function pool.discharge(b, unit_number)
  if b and b.roster then b.roster[unit_number] = nil end
end

-- Saves from before the roster: rebuilt once from storage.unit_owner.
local function roster(b)
  if not b.roster then
    b.roster = {}
    for n, id in pairs(storage.unit_owner or {}) do
      if id == b.id then
        local u = game.get_entity_by_unit_number(n)
        if u and u.valid then b.roster[n] = u end
      end
    end
  end
  return b.roster
end

pool.roster = roster

function pool.strength(b)
  local n = 0
  local r = roster(b)
  for k, u in pairs(r) do
    if u.valid then n = n + 1 else r[k] = nil end
  end
  return n
end

local function home_near(b, p)
  local hs = {b.lander}
  for _, d in ipairs(b.depots or {}) do hs[#hs + 1] = d end
  for _, h in ipairs(hs) do
    if h and h.valid and (h.position.x - p.x) ^ 2 + (h.position.y - p.y) ^ 2 <= HOME * HOME then return true end
  end
  return false
end

-- Home: a unit its merit has earned a rank is promoted here (veterancy.lua: a rank comes only at home, where no job
-- holds it), its copy enlisted in its place.
local function homecoming(b, u)
  local old = u.unit_number
  local n = veterancy.promote(u)
  if n ~= u then
    storage.unit_owner[old] = nil
    if b.roster then b.roster[old] = nil end
    pool.enlist(b, n)
  end
  return n
end

-- Units done with a job: home already, into the garrison; else on their way back until they are (pool.tick).
function pool.give(b, units)
  b.returning = b.returning or {}
  for _, u in ipairs(units) do
    if u.valid then
      if home_near(b, u.position) then table.insert(b.garrison, homecoming(b, u)) else table.insert(b.returning, u) end
    end
  end
end

function pool.give_one(b, u) pool.give(b, {u}) end

-- Units back home rejoin the garrison; one stuck on its way (a minute without coming nearer is not tracked: the
-- leash and its order home take care of it) rejoins after RETURN_MAX regardless, where it stands.
local RETURN_MAX = 5 * 3600
function pool.tick(b)
  local r = b.returning
  if not r or #r == 0 then return end
  b.returning_since = b.returning_since or {}
  for i = #r, 1, -1 do
    local u = r[i]
    if not u.valid then
      table.remove(r, i)
    else
      local since = b.returning_since[u.unit_number] or game.tick
      b.returning_since[u.unit_number] = since
      if home_near(b, u.position) or game.tick - since > RETURN_MAX then
        table.remove(r, i)
        b.returning_since[u.unit_number] = nil
        table.insert(b.garrison, homecoming(b, u))
      end
    end
  end
end

return pool
