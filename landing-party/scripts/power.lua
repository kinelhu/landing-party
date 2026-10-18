-- The power strike (Fable's fortress consult, docs/reviews/2026-10-18-fortress-consult.md: "Transmission. Find the
-- network behind the turrets facing the line, walk it outward, take the first stretch of poles beyond turret reach with
-- no second feed"). Serenity's: a plan against a system, not a building. The cut is a pole whose loss leaves the
-- turrets with no source of power on their side (an articulation point of the pole graph, by its copper wires), standing
-- where no turret reaches it. Its counter is the player's: a second feed, accumulators by the turrets, walls round the
-- line. A dark turret (no energy) weighs nothing (ops.weigh): the Line goes through the dark stretch.
-- A leaf: it reads the surface only.
local power = {}

local SOURCES = {"generator", "solar-panel", "accumulator", "burner-generator", "electric-energy-interface", "reactor",
  "fusion-generator", "lightning-attractor"}
local TURRETS = {"ammo-turret", "electric-turret", "fluid-turret"}
local REACH = 30                 -- a pole this far from every turret stands beyond their reach (laser 24, and a margin)
local ATTACH = 12                -- a source or a turret hangs on the nearest pole within this

-- Whether an electric turret has no power to fire: its network gives it none (by its buffer, a laser just built read
-- as dark before it charged, a raid was sized against nothing and turned back at its staging point, sneak).
function power.dark(e)
  return e.type == "electric-turret" and e.status == defines.entity_status.no_power
end

local function key(e) return e.unit_number end

-- The cut behind `turrets` (electric turrets of `force`): the exposed pole whose loss darkens the most of them, within
-- `radius` of their middle. Returns {pole = entity, dark = turrets cut off, poles = graph size} or nil and why.
function power.cut(surface, force, turrets, radius)
  local nets, cx, cy, n = {}, 0, 0, 0
  for _, t in ipairs(turrets) do
    if t.valid and t.electric_network_id then
      nets[t.electric_network_id] = true
      cx, cy, n = cx + t.position.x, cy + t.position.y, n + 1
    end
  end
  if n == 0 then return nil, "no powered turret" end
  cx, cy = cx / n, cy / n
  local area = {{cx - radius, cy - radius}, {cx + radius, cy + radius}}
  local poles, index = {}, {}
  for _, p in pairs(surface.find_entities_filtered{area = area, force = force, type = "electric-pole"}) do
    if p.electric_network_id and nets[p.electric_network_id] then
      poles[#poles + 1] = p
      index[key(p)] = #poles
    end
  end
  if #poles == 0 then return nil, "no poles" end
  -- Edges: copper wires between poles of the graph. A wire to a pole of the network beyond the area counts as a source
  -- (power from outside it: a remote plant is not "no source").
  local adj, src = {}, {}
  for i, p in ipairs(poles) do
    adj[i] = {}
    local c = p.get_wire_connector(defines.wire_connector_id.pole_copper, false)
    for _, w in ipairs(c and c.connections or {}) do
      local o = w.target and w.target.owner
      local j = o and o.valid and o.unit_number and index[o.unit_number]
      if j then adj[i][#adj[i] + 1] = j
      elseif o and o.valid and o.type == "electric-pole" then src[i] = (src[i] or 0) + 1 end
    end
  end
  -- What hangs on each pole: sources and turrets, each on the nearest pole within ATTACH. Poles on a grid of ATTACH
  -- cells: a search per source cost one engine query each, and a megabase has thousands of solar panels.
  local tur, grid = {}, {}
  for i, p in ipairs(poles) do
    local k = math.floor(p.position.x / ATTACH) .. "," .. math.floor(p.position.y / ATTACH)
    grid[k] = grid[k] or {}
    table.insert(grid[k], i)
  end
  local function hang(list, ents)
    for _, e in pairs(ents) do
      if e.electric_network_id and nets[e.electric_network_id] then
        local gx, gy = math.floor(e.position.x / ATTACH), math.floor(e.position.y / ATTACH)
        local best, bd
        for dx = -1, 1 do for dy = -1, 1 do
          for _, j in ipairs(grid[(gx + dx) .. "," .. (gy + dy)] or {}) do
            local p = poles[j]
            local d = (p.position.x - e.position.x) ^ 2 + (p.position.y - e.position.y) ^ 2
            if d <= ATTACH * ATTACH and (not bd or d < bd) then best, bd = j, d end
          end
        end end
        if best then list[best] = (list[best] or 0) + 1 end
      end
    end
  end
  hang(src, surface.find_entities_filtered{area = area, force = force, type = SOURCES})
  hang(tur, turrets)
  -- Exposed: no turret within REACH (the force's turrets on a grid, one query in all: a query a pole cost 300 ms on a
  -- megabase's 949 poles, visit nw).
  local tgrid = {}
  for _, t in pairs(surface.find_entities_filtered{area = {{cx - radius - REACH, cy - radius - REACH},
    {cx + radius + REACH, cy + radius + REACH}}, force = force, type = TURRETS}) do
    local k = math.floor(t.position.x / REACH) .. "," .. math.floor(t.position.y / REACH)
    tgrid[k] = tgrid[k] or {}
    table.insert(tgrid[k], t.position)
  end
  local function exposed(p)
    local gx, gy = math.floor(p.position.x / REACH), math.floor(p.position.y / REACH)
    for dx = -1, 1 do for dy = -1, 1 do
      for _, q in ipairs(tgrid[(gx + dx) .. "," .. (gy + dy)] or {}) do
        if (q.x - p.position.x) ^ 2 + (q.y - p.position.y) ^ 2 <= REACH * REACH then return false end
      end
    end end
    return true
  end
  -- One depth-first pass (Tarjan's articulation points): for each pole, the subtrees its loss cuts off, with their
  -- turrets and sources; the rest of its component is the other side. A side with turrets and no source is dark.
  -- (A search from every candidate was 700 searches of 949 poles.)
  local disc, low, parent, tsub, ssub = {}, {}, {}, {}, {}
  local timer, best, bdark, cands = 0, nil, 0, 0
  local function consider(v, T, S)
    if T > bdark and S == 0 and exposed(poles[v]) then best, bdark = poles[v], T end
  end
  for root = 1, #poles do
    if not disc[root] then
      -- Iterative DFS: a stack of {vertex, next neighbour index}.
      local order, stack = {}, {{root, 1}}
      timer = timer + 1
      disc[root], low[root] = timer, timer
      while #stack > 0 do
        local top = stack[#stack]
        local v, i = top[1], top[2]
        local w = adj[v][i]
        if w then
          top[2] = i + 1
          if not disc[w] then
            parent[w] = v
            timer = timer + 1
            disc[w], low[w] = timer, timer
            stack[#stack + 1] = {w, 1}
          elseif w ~= parent[v] then
            low[v] = math.min(low[v], disc[w])
          end
        else
          table.remove(stack)
          order[#order + 1] = v
          local pv = parent[v]
          if pv then low[pv] = math.min(low[pv], low[v]) end
        end
      end
      -- Subtree sums in post-order, then each pole's cut sides.
      for _, v in ipairs(order) do tsub[v], ssub[v] = tur[v] or 0, src[v] or 0 end
      for _, v in ipairs(order) do
        local pv = parent[v]
        if pv then tsub[pv], ssub[pv] = tsub[pv] + tsub[v], ssub[pv] + ssub[v] end
      end
      local TT, ST = tsub[root], ssub[root]
      for _, v in ipairs(order) do
        if #adj[v] >= 2 then
          cands = cands + 1
          local cutT, cutS, kids = 0, 0, 0
          for _, w in ipairs(adj[v]) do
            if parent[w] == v then
              kids = kids + 1
              if v ~= root and low[w] >= disc[v] then
                consider(v, tsub[w], ssub[w])
                cutT, cutS = cutT + tsub[w], cutS + ssub[w]
              end
            end
          end
          if v == root and kids >= 2 then
            for _, w in ipairs(adj[v]) do if parent[w] == v then consider(v, tsub[w], ssub[w]) end end
          elseif v ~= root and cutT + cutS > 0 then
            -- The rest of the component, above v.
            consider(v, TT - tsub[v], ST - ssub[v])
          end
        end
      end
    end
  end
  if not best then return nil, string.format("no single cut (%d poles, %d with two wires or more)", #poles, cands) end
  return {pole = best, dark = bdark, poles = #poles}
end

return power
