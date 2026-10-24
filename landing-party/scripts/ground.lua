-- The ground a march crosses, generated before it sets out. A unit in a chunk never generated cannot path (every move
-- fails at once): on seed 4242 a lake sent Synthexis's scout round through such chunks and every wave came blind
-- (2026-10-23); Kessler-Hayashi's raids stood by their lander, 430 tiles from a staging point across ground nobody had
-- visited, and were called off (seed 1, 2026-10-24). Requested, not forced (forcing it held a tick for a second): the
-- chunks it returns are what a march waits on. A leaf: reads nothing but the surface.
local ground = {}

ground.CORRIDOR = 8  -- chunks either side of the line, wide enough for the engine's route round what blocks it

-- Asks for the chunks along a to b (positions {x=,y=} or {x, y}); returns the chunks to wait on.
function ground.corridor(s, a, b, width)
  local ax, ay = a.x or a[1], a.y or a[2]
  local bx, by = b.x or b[1], b.y or b[2]
  local w = width or ground.CORRIDOR
  local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
  local ux, uy = (bx - ax) / math.max(len, 1), (by - ay) / math.max(len, 1)
  local check = {}
  for k = 0, math.ceil(len / 32) do
    local f = k * 32 / math.max(len, 1)
    local q = {ax + (bx - ax) * f, ay + (by - ay) * f}
    s.request_to_generate_chunks(q, w)
    for _, side in ipairs({0, -w * 32, w * 32}) do
      check[#check + 1] = {math.floor((q[1] - uy * side) / 32), math.floor((q[2] + ux * side) / 32)}
    end
  end
  return check
end

-- How many of those chunks are not generated yet (0: the march can go).
function ground.missing(s, chunks)
  local n = 0
  for _, c in ipairs(chunks or {}) do
    if not s.is_chunk_generated({c[1], c[2]}) then n = n + 1 end
  end
  return n
end

return ground
