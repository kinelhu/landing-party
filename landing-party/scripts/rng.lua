-- A seeded random source whose state is a plain number, so it lives in storage and replays the same on
-- every machine (math.random is not allowed to differ between peers). Park-Miller minimal standard.
local rng = {}

local M, A = 2147483647, 48271

-- Nearby seeds give nearly linear first draws in Park-Miller (12 landings drew 8 of one doctrine and none
-- of another): scramble the seed and discard the first draws.
function rng.new(seed)
  local s = math.floor(math.abs(seed)) % M
  s = (s * 16807 + 1013904223) % M
  s = (s * 69621 + 12345) % M
  if s == 0 then s = 1 end
  local r = {s = s}
  for _ = 1, 8 do rng.next(r) end
  return r
end

-- A float in [0, 1).
function rng.next(r)
  r.s = (r.s * A) % M
  return (r.s - 1) / (M - 1)
end

-- An integer in [lo, hi].
function rng.int(r, lo, hi)
  return lo + math.floor(rng.next(r) * (hi - lo + 1))
end

-- One entry of a list.
function rng.pick(r, list)
  return list[rng.int(r, 1, #list)]
end

-- One key of a {key = weight} table, in sorted key order so the draw does not depend on table order.
function rng.weighted(r, weights)
  local keys, total = {}, 0
  for k, w in pairs(weights) do table.insert(keys, k); total = total + w end
  table.sort(keys)
  local x = rng.next(r) * total
  for _, k in ipairs(keys) do
    x = x - weights[k]
    if x < 0 then return k end
  end
  return keys[#keys]
end

return rng
