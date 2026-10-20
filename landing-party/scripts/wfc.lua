-- Wave function collapse (the user, 2026-10-20: "Would WFC be a cool algorithm to implement for Serenity?"): a camp's
-- ground laid out from hand-made 6x6 tiles (scripts/wfc/*.tiles, made into scripts/wfc_<corp>.lua by
-- scripts/wfc/to_lua.py; scripts/wfc/wfc.py is the same solver with previews). Two tiles stand side by side where their
-- touching edges agree (the table lists, per variant and side, what may stand there). Cells outside the mask are the
-- void tile; cells at the mask's edge may be too (its edge is soft). Depth-first, the most constrained cell first, its
-- options in weighted random order, within a step budget; a result is checked (wfc.check) and rolled again if it fails.
local wfc = {}

local STEP = {n = {0, -1}, s = {0, 1}, e = {1, 0}, w = {-1, 0}}
local WALLS = {["#"] = true, g = true}
local WALK = {["."] = true, ["="] = true, g = true, h = true}
wfc.BUILD = {T = {2, 2}, G = {2, 2}, D = {4, 4}, F = {3, 3}, R = {3, 3}, B = {3, 3}, P = {1, 1}, L = {1, 1}}

local function count(s) local n = 0 for _ in pairs(s) do n = n + 1 end return n end

-- Bit operations: Factorio's bit32, or LuaJIT's bit (the tests run it); 30 bits a word keeps clear of the sign.
local B = bit32 or bit
local band, bor, bxor = B.band, B.bor, B.bxor
local BITS = 30
local POP = {}
for i = 0, 255 do local n, v = 0, i while v > 0 do n = n + v % 2; v = math.floor(v / 2) end POP[i] = n end
local function pop(w) return POP[w % 256] + POP[math.floor(w / 256) % 256] + POP[math.floor(w / 65536) % 256] + POP[math.floor(w / 16777216) % 256] end
local LOW = {}
for i = 0, BITS - 1 do LOW[2 ^ i] = i end

-- Each tile set's masks, made once: per variant and side, the variants that may stand there, as words.
local function masks(tiles)
  if tiles.masks then return tiles.masks end
  local V = tiles.variants
  local NW = math.ceil(#V / BITS)
  local fit = {}
  for i, v in ipairs(V) do
    fit[i] = {}
    for _, side in ipairs({"n", "s", "e", "w"}) do
      local m = {}
      for k = 1, NW do m[k] = 0 end
      for _, j in ipairs(v.fit[side]) do
        local k, bitpos = math.floor((j - 1) / BITS) + 1, (j - 1) % BITS
        m[k] = bor(m[k], 2 ^ bitpos)
      end
      fit[i][side] = m
    end
  end
  tiles.masks = {NW = NW, fit = fit}
  return tiles.masks
end

-- Collapse a w x h grid. mask(x, y): inside; fixed[x .. "," .. y] = variant index (cells already built); rand(): [0, 1).
-- Returns {[x .. "," .. y] = variant index} or nil. Each cell's options as bit words, a trail of changed words undone on
-- backtrack (string keys and a copy of every domain at each choice took 94 ms a try in game).
function wfc.solve(tiles, w, h, mask, rand, fixed, budget)
  local V = tiles.variants
  local NV = #V
  local M = masks(tiles)
  local NW, FIT = M.NW, M.fit
  local SIDES = {"n", "s", "e", "w"}
  local void, inner = {}, {}
  for i, v in ipairs(V) do
    if v.name == "void" then void[i] = true end
    -- Deep inside, a tile's edges are floor or lane: walls only at the mask's edge (else every cell walled into its
    -- own pod, a honeycomb of sealed octagons).
    local ok = true
    for _, row in ipairs({v.rows[1], v.rows[#v.rows]}) do if row:find("[^.=]") then ok = false end end
    for _, row in ipairs(v.rows) do
      if not row:sub(1, 1):find("[.=]") or not row:sub(-1):find("[.=]") then ok = false end
    end
    inner[i] = ok
  end
  local N = w * h
  local dom, cnt, nb = {}, {}, {}
  local function set(d, i) local k = math.floor((i - 1) / BITS) + 1 d[k] = bor(d[k], 2 ^ ((i - 1) % BITS)) end
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local c = y * w + x + 1
      local edge = false
      for dx = -1, 1 do for dy = -1, 1 do if not mask(x + dx, y + dy) then edge = true end end end
      local d = {}
      for k = 1, NW do d[k] = 0 end
      for i = 1, NV do
        local on
        if not mask(x, y) then on = void[i] else on = edge or inner[i] end
        if on then set(d, i) end
      end
      dom[c] = d
      local n = 0
      for k = 1, NW do n = n + pop(d[k]) end
      cnt[c] = n
      nb[c] = {n = y > 0 and c - w or nil, s = y < h - 1 and c + w or nil, w = x > 0 and c - 1 or nil,
        e = x < w - 1 and c + 1 or nil}
    end
  end
  for key, i in pairs(fixed or {}) do
    local x, y = key:match("(-?%d+),(-?%d+)")
    local c = tonumber(y) * w + tonumber(x) + 1
    local d = {}
    for k = 1, NW do d[k] = 0 end
    set(d, i)
    dom[c], cnt[c] = d, 1
  end
  local trail = {}   -- {cell, word, old word, old count}
  local function put(c, k, v)
    local d = dom[c]
    trail[#trail + 1] = {c, k, d[k], cnt[c]}
    cnt[c] = cnt[c] - pop(d[k]) + pop(v)
    d[k] = v
  end
  local function undo(mark)
    for t = #trail, mark + 1, -1 do
      local e = trail[t]
      dom[e[1]][e[2]] = e[3]
      cnt[e[1]] = e[4]
      trail[t] = nil
    end
  end
  local u = {}
  local function propagate(stack)
    while #stack > 0 do
      local p = stack[#stack]
      stack[#stack] = nil
      local dp = dom[p]
      for _, side in ipairs(SIDES) do
        local q = nb[p][side]
        if q then
          for k = 1, NW do u[k] = 0 end
          for k = 1, NW do
            local wd = dp[k]
            while wd ~= 0 do
              local lb = band(wd, -wd)
              local i = (k - 1) * BITS + LOW[lb] + 1
              local f = FIT[i][side]
              for kk = 1, NW do u[kk] = bor(u[kk], f[kk]) end
              wd = bxor(wd, lb)
            end
          end
          local dq, changed = dom[q], false
          for k = 1, NW do
            local nv = band(dq[k], u[k])
            if nv ~= dq[k] then put(q, k, nv); changed = true end
          end
          if changed then
            if cnt[q] == 0 then return false end
            stack[#stack + 1] = q
          end
        end
      end
    end
    return true
  end
  local all = {}
  for c = 1, N do all[c] = c end
  if not propagate(all) then return nil end
  local steps = 0
  budget = budget or 3000
  local function search()
    local bn, ties = math.huge, {}
    for c = 1, N do
      local n = cnt[c]
      if n > 1 then
        if n < bn then bn, ties = n, {c} elseif n == bn then ties[#ties + 1] = c end
      end
    end
    if bn == math.huge then return true end
    local c = ties[math.floor(rand() * #ties) + 1]
    local order = {}
    for k = 1, NW do
      local wd = dom[c][k]
      while wd ~= 0 do
        local lb = band(wd, -wd)
        local i = (k - 1) * BITS + LOW[lb] + 1
        order[#order + 1] = {i, -rand() ^ (1 / V[i].weight)}
        wd = bxor(wd, lb)
      end
    end
    table.sort(order, function(a, b) if a[2] ~= b[2] then return a[2] < b[2] end return a[1] < b[1] end)
    for _, o in ipairs(order) do
      steps = steps + 1
      if steps > budget then return false end
      local mark = #trail
      local ko, bo = math.floor((o[1] - 1) / BITS) + 1, 2 ^ ((o[1] - 1) % BITS)
      for k = 1, NW do
        local v = (k == ko) and bo or 0
        if dom[c][k] ~= v then put(c, k, v) end
      end
      if propagate({c}) and search() then return true end
      undo(mark)
    end
    return false
  end
  if not search() then return nil end
  local out = {}
  for c = 1, N do
    for k = 1, NW do
      local wd = dom[c][k]
      if wd ~= 0 then
        out[((c - 1) % w) .. "," .. math.floor((c - 1) / w)] = (k - 1) * BITS + LOW[band(wd, -wd)] + 1
        break
      end
    end
  end
  return out
end

-- The solution as a grid of characters: g[y][x], 0-based tile coordinates.
function wfc.render(tiles, sol, w, h)
  local S, V = tiles.size, tiles.variants
  local g = {}
  for y = 0, h * S - 1 do g[y] = {} for x = 0, w * S - 1 do g[y][x] = " " end end
  for k, i in pairs(sol) do
    local cx, cy = k:match("(-?%d+),(-?%d+)")
    cx, cy = tonumber(cx), tonumber(cy)
    for r, row in ipairs(V[i].rows) do
      for c = 1, S do g[cy * S + r - 1][cx * S + c - 1] = row:sub(c, c) end
    end
  end
  return g
end

-- Nil when the ground works: a gate opening outside, no floor open to outside, walls closed (no stub, no spur), lanes
-- between two gates, every floor reachable from a gate, every building beside reachable ground. Else why not.
-- quick: lanes and reach only (rooms.lua checks after each partition; the outline cannot change then).
function wfc.check(g, W, H, quick)
  local function at(x, y) return (g[y] and g[y][x]) or " " end
  local exits, reach, stack = 0, {}, {}
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local c = at(x, y)
      local outside = false
      if c == "g" or (not quick and (WALK[c] or c == "#")) then
        for _, st in pairs(STEP) do if at(x + st[1], y + st[2]) == " " then outside = true end end
      end
      if c == "g" and outside then exits = exits + 1; reach[y * W + x] = true; table.insert(stack, {x, y}) end
      if not quick and WALK[c] and c ~= "g" and outside then return "floor open to outside" end
      if not quick and c == "#" then
        local n = 0
        for _, st in pairs(STEP) do if WALLS[at(x + st[1], y + st[2])] then n = n + 1 end end
        if n < 2 then return "wall stub" end
        local fl = {}
        for side, st in pairs(STEP) do if WALK[at(x + st[1], y + st[2])] then fl[side] = true end end
        if (fl.n or fl.s) and (fl.e or fl.w) then
          local near = false
          for dx = -1, 1 do for dy = -1, 1 do if at(x + dx, y + dy) == " " then near = true end end end
          if not near then return "wall spur" end
        end
      end
    end
  end
  if exits == 0 then return "no gate opens outside" end
  local lanes = {}
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      if at(x, y) == "=" and not lanes[y * W + x] then
        local comp, st2, gates = {[y * W + x] = true}, {{x, y}}, {}
        lanes[y * W + x] = true
        while #st2 > 0 do
          local p = table.remove(st2)
          for _, st in pairs(STEP) do
            local qx, qy = p[1] + st[1], p[2] + st[2]
            local q = qy * W + qx
            local cq = at(qx, qy)
            if (cq == "=" or cq == "h") and not comp[q] then comp[q] = true; lanes[q] = true; table.insert(st2, {qx, qy})
            elseif at(qx, qy) == "g" then gates[q] = true end
          end
        end
        if count(gates) < 2 then return "dead-end lane" end
      end
    end
  end
  while #stack > 0 do
    local p = table.remove(stack)
    for _, st in pairs(STEP) do
      local qx, qy = p[1] + st[1], p[2] + st[2]
      local q = qy * W + qx
      if not reach[q] and WALK[at(qx, qy)] then reach[q] = true; table.insert(stack, {qx, qy}) end
    end
  end
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local c = at(x, y)
      if WALK[c] and not reach[y * W + x] then return "floor cut off" end
      local b = wfc.BUILD[c]
      if b then
        local ok = false
        for dx = -1, b[1] do
          for dy = -1, b[2] do
            if (dx == -1 or dx == b[1] or dy == -1 or dy == b[2]) and not ((dx == -1 or dx == b[1]) and (dy == -1 or dy == b[2]))
              and reach[(y + dy) * W + x + dx] then ok = true end
          end
        end
        if not ok then return "building unreachable" end
      end
    end
  end
  return nil
end

-- Rooms carved after the collapse (WFC sees only neighbours: partition tiles never made a line wall to wall): straight
-- partitions ("w") through floor and lanes only, closed at both ends by the outer wall or another partition (so one room
-- is split, BSP), the longest first among the three longest, no other partition within min_room either side, not along
-- a lane; a door ("h") where a lane crosses and at its middle. In place.
function wfc.rooms(g, W, H, rand, splits, min_room)
  splits, min_room = splits or 4, min_room or 9
  local function at(x, y) return (g[y] and g[y][x]) or " " end
  local function runs(horizontal)
    local out = {}
    -- Every second line is plenty for a partition (scanning all of them took most of a try's time).
    for a = 2, (horizontal and H or W) - 3, 2 do
      local run = {}
      for c = 0, (horizontal and W or H) - 1 do
        local x, y = c, a
        if not horizontal then x, y = a, c end
        local ch = at(x, y)
        if ch == "." or ch == "=" then
          table.insert(run, {x, y})
        else
          if (ch == "#" or ch == "w") and #run >= 2 * min_room then
            local px, py = run[1][1] - (horizontal and 1 or 0), run[1][2] - (horizontal and 0 or 1)
            local before = at(px, py)
            if before == "#" or before == "w" then table.insert(out, run) end
          end
          run = {}
        end
      end
    end
    return out
  end
  local lines = {[true] = {}, [false] = {}}   -- lines holding a partition, by orientation
  for _ = 1, splits do
    local cands = {}
    for _, horizontal in ipairs({true, false}) do
      for _, run in ipairs(runs(horizontal)) do
        local px, py = 0, 1
        if not horizontal then px, py = 1, 0 end
        local near, beside = 0, 0
        -- Partitions parallel to it, within min_room: looked up by line (a partition fills its line's run).
        local a0 = horizontal and run[1][2] or run[1][1]
        for k = 1, min_room - 1 do
          for _, sg in ipairs({-1, 1}) do if lines[horizontal][a0 + sg * k] then near = near + 1 end end
        end
        for _, p in ipairs(run) do
          for _, sg in ipairs({-1, 1}) do if at(p[1] + sg * px, p[2] + sg * py) == "=" then beside = beside + 1 end end
        end
        if near == 0 and beside <= math.floor(#run / 4) then table.insert(cands, {#run, run, horizontal}) end
      end
    end
    if #cands == 0 then break end
    table.sort(cands, function(a, b) if a[1] ~= b[1] then return a[1] > b[1] end return a[2][1][1] * 1000 + a[2][1][2] < b[2][1][1] * 1000 + b[2][1][2] end)
    local chosen = cands[math.min(#cands, math.floor(rand() * math.min(3, #cands)) + 1)]
    local pick = chosen[2]
    local mid = math.floor(#pick / 2)
    local before = {}
    for i, p in ipairs(pick) do
      local x, y = p[1], p[2]
      before[i] = g[y][x]
      g[y][x] = (g[y][x] == "=" or math.abs(i - 1 - mid) <= 1) and "h" or "w"
    end
    -- One that cuts a floor or a lane off is taken back (rejected whole, they cost five tries a compound).
    local why = wfc.check(g, W, H, true)
    if why == "floor cut off" or why == "dead-end lane" or why == "building unreachable" then
      for i, p in ipairs(pick) do g[p[2]][p[1]] = before[i] end
    else
      lines[chosen[3]][chosen[3] and pick[1][2] or pick[1][1]] = true
    end
  end
  return g
end

-- The buildings of a checked ground: {letter, x, y, w, h} in tile coordinates (top-left).
function wfc.buildings(g, W, H)
  local out = {}
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local b = wfc.BUILD[g[y][x]]
      if b then table.insert(out, {g[y][x], x, y, b[1], b[2]}) end
    end
  end
  return out
end

return wfc
