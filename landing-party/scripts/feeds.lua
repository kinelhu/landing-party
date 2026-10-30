-- What keeps a foe's turrets fighting, and what cutting it would starve: each turret's supply read from the game's own
-- links, no layout assumed and no rule per kind of base (the user: "be wary of hardcoding too much"; the perception
-- consult, docs/reviews/2026-10-27-synthexis-perception-consult.md, section 4: a ring of guns fed by one ammunition belt,
-- and nothing could name the belt). One reader for each medium a turret hangs on:
--   ammunition: the inserters dropping into it (drop_target), what each picks from (pickup_target), and upstream along a
--     belt (belt_neighbours, an underground's other end: underground_belt_neighbour) while the line has one source, BELT_UP belts at most;
--   power: the pole whose loss darkens the most of its lasers (power.cut, Kessler-Hayashi's own reading of a power line);
--   fluid: the pipe, pump or tank whose loss parts the most flamethrowers from every source of their fluid (the network
--     walked by fluidbox_neighbours, FLUID_MAX entities at most; a source is what holds or makes fluid, not a pipe).
-- A feed is worth what every way of feeding a turret passes through: one inserter on one belt, the whole line; two from
-- two lines, only what they share; so a base fed from two ends has no cheap cut, and that is its answer.
-- A leaf but for power and threat: it reads the surface only.
local power = require("__landing-party__.scripts.power")
local threat = require("__landing-party__.scripts.threat")

local feeds = {}

feeds.BELT_UP = 80          -- belts walked upstream from an inserter, at most
local BELTS = {["transport-belt"] = true, ["underground-belt"] = true, splitter = true}
feeds.FLUID_MAX = 3000      -- entities of one fluid network walked, at most
feeds.FLUID_OWN = 100       -- what a flamethrower holds itself (insert_fluid filled one to 100, 2026-10-30)
local CARRY = {pipe = true, ["pipe-to-ground"] = true, pump = true, ["fluid-turret"] = true}

-- Its flamethrowers' network: from each fluid turret along fluidbox_neighbours, then for each pipe, pump or tank in it
-- the turrets that its loss parts from every source (what holds or makes fluid: a tank, a refinery, an offshore pump; a
-- pump with one side open, from a wagon). Each {e, starves = turrets, turrets = the list}.
function feeds.fluid(turrets)
  local adj, ents, todo = {}, {}, {}
  for _, t in ipairs(turrets) do
    if t.valid and t.type == "fluid-turret" and not ents[t.unit_number] then
      ents[t.unit_number] = t
      todo[#todo + 1] = t
    end
  end
  local n = #todo
  while #todo > 0 and n <= feeds.FLUID_MAX do
    local e = table.remove(todo)
    local list = {}
    for _, group in ipairs(e.fluidbox_neighbours or {}) do
      for _, o in ipairs(group) do
        if o.valid and o.unit_number then
          list[#list + 1] = o.unit_number
          if not ents[o.unit_number] then
            ents[o.unit_number] = o
            todo[#todo + 1] = o
            n = n + 1
          end
        end
      end
    end
    adj[e.unit_number] = list
  end
  local sources, fts = {}, {}
  for k, e in pairs(ents) do
    if e.type == "fluid-turret" then fts[#fts + 1] = k
    elseif not CARRY[e.type] or (e.type == "pump" and #(adj[k] or {}) < 2) then sources[#sources + 1] = k end
  end
  if #sources == 0 or #fts == 0 then return {} end
  -- One walk from every source at once (a root joined to each), depth first: an entity whose child's subtree reaches back
  -- no higher than it is the only way to that subtree, and its loss parts the turrets there (Tarjan's articulation points;
  -- walking the network again for each entity was its size squared).
  local ROOT = -1
  adj[ROOT] = sources
  -- (Each source joined back to the root too: one reached first along pipes from another still reaches the root.)
  for _, k in ipairs(sources) do
    local l = {}
    for _, o in ipairs(adj[k] or {}) do l[#l + 1] = o end
    l[#l + 1] = ROOT
    adj[k] = l
  end
  local disc, low, parent, cut_off, t = {[ROOT] = 0}, {[ROOT] = 0}, {}, {}, 0
  local stack = {{ROOT, 1}}
  local held_off
  local turret = {}
  for _, k in ipairs(fts) do turret[k] = true end
  local under, held = {}, {}   -- turrets in each entity's subtree, and the fluid there (what its turrets fire on, cut off)
  while #stack > 0 do
    local top = stack[#stack]
    local k, i = top[1], top[2]
    local nb = adj[k] or {}
    if i <= #nb then
      top[2] = i + 1
      local o = nb[i]
      if not disc[o] then
        t = t + 1
        disc[o], low[o], parent[o], under[o] = t, t, k, turret[o] and 1 or 0
        held[o] = ents[o] and ents[o].valid and ents[o].get_fluid_count() or 0
        stack[#stack + 1] = {o, 1}
      elseif o ~= parent[k] then
        low[k] = math.min(low[k], disc[o])
      end
    else
      stack[#stack] = nil
      local p = parent[k]
      if p then
        low[p] = math.min(low[p], low[k])
        if p ~= ROOT then
          under[p] = (under[p] or 0) + under[k]
          held[p] = (held[p] or 0) + held[k]
          if low[k] >= disc[p] and under[k] > 0 then
            cut_off[p] = (cut_off[p] or 0) + under[k]
            held_off = held_off or {}
            held_off[p] = (held_off[p] or 0) + held[k]
          end
        end
      end
    end
  end
  local out, by = {}, {}
  for k, n in pairs(cut_off) do
    local e = ents[k]
    if e and e.type ~= "fluid-turret" then
      by[k] = {e = e, starves = n, turrets = {}, held = held_off and held_off[k] or 0}
      out[#out + 1] = by[k]
    end
  end
  -- (The turrets each parts, for their price: each turret up its parents once, counted at every one that parts it.)
  for _, tk in ipairs(fts) do
    local x = tk
    while x and x ~= ROOT do
      local p = parent[x]
      if p and by[p] and low[x] >= disc[p] then table.insert(by[p].turrets, ents[tk]) end
      x = p
    end
  end
  -- A cut its flamethrowers would outlast is none: kept only where the pipes past it hold no more than the turrets do
  -- themselves (FLUID_OWN each at least). (The trunk pipe of the user's fort parted all 22 and left 20,000 oil past it,
  -- hours of fire: the user, 2026-10-30, "I used to refill my outposts with a single tank of 15k for a few hours".)
  local kept = {}
  for _, c in ipairs(out) do
    local own = 0
    for _, ft in ipairs(c.turrets) do own = own + math.max(feeds.FLUID_OWN, ft.valid and ft.get_fluid_count() or 0) end
    if c.held - own <= own then kept[#kept + 1] = c end
  end
  out = kept
  return out
end

-- One way a turret is fed: the inserter, then what it picks from and the belt upstream while it has one source.
local function chain_of(ins)
  local out = {ins}
  local src = ins.pickup_target
  if not (src and src.valid) then return out end
  if not BELTS[src.type] then out[#out + 1] = src; return out end
  local b, seen = src, {}
  for _ = 1, feeds.BELT_UP do
    if not (b and b.valid) or seen[b.unit_number] then break end
    seen[b.unit_number] = true
    out[#out + 1] = b
    local inputs = b.belt_neighbours.inputs
    if #inputs == 0 and b.type == "underground-belt" and b.belt_to_ground_type == "output" then
      local other = b.underground_belt_neighbour
      inputs = other and other.valid and {other} or {}
    end
    if #inputs ~= 1 then break end
    b = inputs[1]
  end
  return out
end

-- The feeds of the turrets of `forces` round `at` (radius): {[unit_number] = {e = entity, starves = turrets, price =
-- what they cost its reader, summed (price(turret): know.price; 1 each without)}}.
function feeds.read(surface, at, radius, forces, price)
  local x, y = at.x or at[1], at.y or at[2]
  local area = {{x - radius, y - radius}, {x + radius, y + radius}}
  local out = {}
  local function add(e, n, p, h)
    local k = e.unit_number
    if not k then return end
    local f = out[k] or {e = e, starves = 0, price = 0, held = 0}
    out[k] = f
    f.starves = f.starves + n
    f.price = f.price + p
    f.held = f.held + (h or 0)
  end
  local function price_of(t) return price and price(t) or 1 end
  local turrets = surface.find_entities_filtered{area = area, type = threat.FIRE, force = forces}
  -- Ammunition: the inserters dropping into its turrets, read once over the box.
  local into = {}
  for _, ins in ipairs(surface.find_entities_filtered{area = {{area[1][1] - 4, area[1][2] - 4}, {area[2][1] + 4, area[2][2] + 4}},
    type = "inserter", force = forces}) do
    local d = ins.drop_target
    if d and d.valid and d.type == "ammo-turret" then
      into[d.unit_number] = into[d.unit_number] or {}
      table.insert(into[d.unit_number], ins)
    end
  end
  local lasers = {}
  for _, t in ipairs(turrets) do
    if t.type == "ammo-turret" and into[t.unit_number] then
      -- What every way of feeding it passes through.
      local common
      for _, ins in ipairs(into[t.unit_number]) do
        local set = {}
        for _, e in ipairs(chain_of(ins)) do if e.unit_number then set[e.unit_number] = e end end
        if not common then common = set else
          for k in pairs(common) do if not set[k] then common[k] = nil end end
        end
      end
      for _, e in pairs(common or {}) do add(e, 1, price_of(t)) end
    elseif t.type == "electric-turret" then
      lasers[#lasers + 1] = t
    end
  end
  for _, c in ipairs(feeds.fluid(turrets)) do
    local p = 0
    for _, t in ipairs(c.turrets) do p = p + price_of(t) end
    add(c.e, c.starves, p, c.held)
  end
  -- Power: the pole whose loss darkens the most of its lasers, per force (power.cut reads one force's lines).
  local by_force = {}
  for _, t in ipairs(lasers) do
    by_force[t.force.name] = by_force[t.force.name] or {}
    table.insert(by_force[t.force.name], t)
  end
  for name, ts in pairs(by_force) do
    local cut = power.cut(surface, game.forces[name], ts, radius)
    if cut and cut.pole and cut.pole.valid and (cut.dark or 0) > 0 then
      local p = 0
      for _, t in ipairs(ts) do p = p + price_of(t) end
      add(cut.pole, cut.dark, cut.dark * p / #ts)
    end
  end
  return out
end

return feeds
