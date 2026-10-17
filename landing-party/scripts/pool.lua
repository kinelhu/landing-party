-- The unit pool (docs/ai.md, section 4): a settlement's units, wherever they are. Before it, a settlement's strength
-- counted only the units at home (its garrison and patrol), so units out on a raid, a heist or a response were made
-- again and the cap was not one; and units were put back into the garrison while still far off, to be drafted again
-- at once from wherever they stood.
--   roster      every unit the settlement owns (storage.unit_owner points the other way), out or home
--   strength    the roster's live count: what the cap holds
--   give        units done with a job: into the garrison when home, else on their way back (b.returning) until they are
-- A leaf: it reads storage and the settlement only.
local pool = {}

local HOME = 40                    -- a unit within this of the lander or a depot is home

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

-- Units done with a job: home already, into the garrison; else on their way back until they are (pool.tick).
function pool.give(b, units)
  b.returning = b.returning or {}
  for _, u in ipairs(units) do
    if u.valid then
      if home_near(b, u.position) then table.insert(b.garrison, u) else table.insert(b.returning, u) end
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
        table.insert(b.garrison, u)
      end
    end
  end
end

return pool
