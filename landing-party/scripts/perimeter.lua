-- Serenity's line (split from ops.lua, 2026-10-18, along the AI graph's seams: docs/ai-graph.md): encroachment judged
-- when the player builds inside its claim, the claim's step outward (to the player's nearest building, or at war to the
-- outpost easiest to cut off: strangling), and the step's map and notices. The code is as it was in ops; install runs
-- it with ops' helpers bound (K) and returns what ops calls.
local shared = require("__landing-party__.shared")

local perimeter = {}

function perimeter.install(ops, K)
local TYPES = K.TYPES
local enemies = K.enemies
local stance = K.stance
-- Encroachment (Serenity's temper, "Please remain behind the line"): a player building put up inside its territory
-- provokes it as an attack does. Judged when it is built (control.lua's on_built): what stood there before the line
-- moved onto it does not (the user, 2026-10-17, on Fable's notices consult: the line moving onto the player is the
-- corporation's act; enclosed unseen beyond radar, an outpost made Serenity an enemy for good).
local ENCROACH = {}
for _, t in ipairs(TYPES) do ENCROACH[t] = true end
ops.ENCROACH_TYPES = TYPES
function ops.encroached(ent)
  if not (ent and ent.valid) or not ENCROACH[ent.type] or ent.name:sub(1, 3) == "lp-" then return end
  local by = ent.force.name
  if shared.is_corp(by) or by == "enemy" or by == "neutral" then return end
  for _, b in pairs(storage.bases or {}) do
    if not b.fallen and b.claim_radius and b.surface == ent.surface.index
      and (shared.CORPS[b.corp].temper or {}).provoked_only
      and (ent.position.x - b.origin.x) ^ 2 + (ent.position.y - b.origin.y) ^ 2 <= b.claim_radius ^ 2 then
      ops.provoke(b.force, by, ent, "trespass")
    end
  end
end

-- Serenity's line moves (docs/reviews/2026-10-13-late-pressure-consult.md): a careful player could leave a
-- provoked-only corporation alone for ever. From PERIMETER_START after landing its perimeter grows PERIMETER_STEP
-- tiles every PERIMETER_TICKS (at once after FLOOR_TICKS with no operation against a player), announced every
-- third step, with a named warning one step before it encloses a player structure; it stops at the nearest
-- player structure + 40, at PERIMETER_MAX from its origin, and short of another corporation's claim. Enclosing
-- a structure provokes it (encroachment).
local FLOOR_TICKS = 20 * 60 * 60
local PERIMETER_START = 30 * 3600
local PERIMETER_TICKS = 10 * 3600
local PERIMETER_STEP = 30
local PERIMETER_MAX = 450
local function nearest_player(b, surface, r)
  local best, bd
  for _, f in ipairs(enemies(game.forces[b.force])) do
    if not shared.is_corp(f.name) then
      for _, e in pairs(surface.find_entities_filtered{position = {b.origin.x, b.origin.y}, radius = r, force = f,
        type = TYPES}) do
        local d = math.sqrt((e.position.x - b.origin.x) ^ 2 + (e.position.y - b.origin.y) ^ 2)
        if not bd or d < bd then best, bd = e, d end
      end
    end
  end
  return best, bd
end

-- Strangling (Fable's fortress consult: "the most Serenity of the four"): at war with a player, its line goes not for
-- the nearest of the player's buildings but for the outpost easiest to cut off: the player's drills within reach,
-- grouped by OUTPOST_CELL, the most drills to the least turret weight (and the nearest). Enclosed, they are worth double
-- to its raids and sieges (choose): what it has surrounded, it takes.
local OUTPOST_CELL = 48
local function outpost(b, surface, r, f)
  local cells = {}
  for _, d in pairs(surface.find_entities_filtered{position = {b.origin.x, b.origin.y}, radius = r, force = f,
    type = "mining-drill"}) do
    local k = math.floor(d.position.x / OUTPOST_CELL) .. "," .. math.floor(d.position.y / OUTPOST_CELL)
    local c = cells[k] or {n = 0, x = 0, y = 0, drill = d}
    c.n, c.x, c.y = c.n + 1, c.x + d.position.x, c.y + d.position.y
    cells[k] = c
  end
  local best, bs, bd
  for _, c in pairs(cells) do
    local cx, cy = c.x / c.n, c.y / c.n
    local w = ops.weigh(surface, {cx, cy}, f)
    local d = math.sqrt((cx - b.origin.x) ^ 2 + (cy - b.origin.y) ^ 2)
    local sc = c.n / (1 + w) ^ 1.5 / (1 + d / 300)
    if not bs or sc > bs then best, bs, bd = c.drill, sc, d end
  end
  return best, bd
end

-- The next ore (strangling's second half): at war with none of the player's buildings in reach, the line goes for the
-- field the player will want next, so that coming means trespass (with one in reach, the line goes for it as before:
-- an ore target then turned the cordon away from the player's buildings, scenarios cordon and bend). The ores the player mines (its drills' targets; iron and copper before it
-- has any), in cells of OUTPOST_CELL beyond the claim with ORE_MIN tiles of them or more and no drill of the player's,
-- the richest (counted to 600), the nearest. Kept (b.next_ore) until the claim covers it or a drill stands on it:
-- the search is a count a cell, some hundreds, once.
local ORE_MIN = 150
local function mined(surface, f)
  local names, any = {}, false
  for _, d in pairs(surface.find_entities_filtered{force = f, type = "mining-drill", limit = 60}) do
    local t = d.mining_target
    if t and t.valid and t.type == "resource" then names[t.name], any = true, true end
  end
  if not any then names = {["iron-ore"] = true, ["copper-ore"] = true} end
  local list = {}
  for n in pairs(names) do list[#list + 1] = n end
  return list
end
local function next_ore(b, surface, r, f)
  local o = b.origin
  local function covered(c)
    return (c.x - o.x) ^ 2 + (c.y - o.y) ^ 2 <= (b.claim_radius + 10) ^ 2
      or surface.count_entities_filtered{position = c, radius = OUTPOST_CELL, force = f, type = "mining-drill", limit = 1} > 0
  end
  local k = b.next_ore
  if k and k.force == f.name and not covered(k) then return k end
  local names = mined(surface, f)
  local best, bs
  local cx0, cy0 = math.floor((o.x - r) / OUTPOST_CELL), math.floor((o.y - r) / OUTPOST_CELL)
  local cx1, cy1 = math.floor((o.x + r) / OUTPOST_CELL), math.floor((o.y + r) / OUTPOST_CELL)
  for cx = cx0, cx1 do for cy = cy0, cy1 do
    local c = {x = (cx + 0.5) * OUTPOST_CELL, y = (cy + 0.5) * OUTPOST_CELL}
    local d = math.sqrt((c.x - o.x) ^ 2 + (c.y - o.y) ^ 2)
    if d <= r and d > b.claim_radius + 10 then
      local n = surface.count_entities_filtered{area = {{cx * OUTPOST_CELL, cy * OUTPOST_CELL},
        {(cx + 1) * OUTPOST_CELL, (cy + 1) * OUTPOST_CELL}}, type = "resource", name = names, limit = 4 * ORE_MIN}
      if n >= ORE_MIN and not covered(c) then
        local sc = n / (1 + d / 150)
        if not bs or sc > bs then best, bs = {x = c.x, y = c.y, n = n, d = d, force = f.name}, sc end
      end
    end
  end end
  b.next_ore = best
  return best
end

function ops.perimeter(b, tick)
  if not (shared.CORPS[b.corp].temper or {}).provoked_only or not b.claim_radius then return end
  if ops.cordon_check then ops.cordon_check(b) end
  -- A broken line waits before it steps out again (cordon.check), even with nothing of the player's threatening it.
  if tick < (b.restep_at or 0) then return end
  b.landed = b.landed or tick
  local fast = storage.perimeter_fast
  local start, every = fast and 3600 or PERIMETER_START, fast and 3600 or PERIMETER_TICKS
  if tick - b.landed < start then return end
  -- A truce bought at the invoice post (ledger.lua): the line holds.
  for _, f in ipairs(shared.player_forces()) do
    if stance.standing(b.corp, f.name) == "truce" then return end
  end
  local quiet = tick - (storage.threat_last or 0) > FLOOR_TICKS and tick - (b.perimeter_floor or 0) > FLOOR_TICKS
  if tick < (b.perimeter_next or 0) and not quiet then return end
  if quiet and tick < (b.perimeter_next or 0) then b.perimeter_floor = tick end
  b.perimeter_next = tick + every
  local surface = game.surfaces[b.surface]
  local cur = b.claim_radius
  local cap = PERIMETER_MAX
  local near, nd = nearest_player(b, surface, PERIMETER_MAX + PERIMETER_STEP)
  -- At war: toward the outpost easiest to cut off (strangling), not the nearest building.
  if not storage.strangle_off then
    for _, f in ipairs(shared.player_forces()) do
      if stance.standing(b.corp, f.name) == "enemy" then
        local o, od = outpost(b, surface, PERIMETER_MAX + PERIMETER_STEP, f)
        if not o and not near and not storage.next_ore_off then
          local ore = next_ore(b, surface, PERIMETER_MAX + PERIMETER_STEP, f)
          if ore then
            -- A resource entity at its middle stands for it (the cordon aims at an entity).
            local e = surface.find_entities_filtered{position = {ore.x, ore.y}, radius = OUTPOST_CELL / 2, type = "resource", limit = 1}[1]
            if e then
              if b.strangling ~= "ore" .. ore.x .. "," .. ore.y then
                b.strangling = "ore" .. ore.x .. "," .. ore.y
                b.ore_targets = (b.ore_targets or 0) + 1
                if ops.trace then ops.trace(b, string.format("perimeter: at war, no outpost in reach: the line goes for the ore at %.0f,%.0f (%d tiles, %.0f out)",
                  ore.x, ore.y, ore.n, ore.d)) end
              end
              o, od = e, ore.d
            end
          end
        end
        if o then
          if o.type ~= "resource" and b.strangling ~= o.unit_number then
            b.strangling = o.unit_number
            if ops.trace then ops.trace(b, string.format("perimeter: at war, the line goes for the outpost at %.0f,%.0f (%.0f out)",
              o.position.x, o.position.y, od)) end
          end
          near, nd = o, od
          break
        end
      end
    end
  end
  if nd then cap = math.min(cap, nd + 40) end
  -- A border the player set and keeps (border.lua): the line holds short of it.
  local bc = ops.border_cap and ops.border_cap(b)
  if bc then cap = math.min(cap, bc) end
  for _, o in pairs(storage.bases) do
    if o ~= b and not o.fallen and o.corp ~= b.corp and o.surface == b.surface and o.claim_radius then
      local d = math.sqrt((o.origin.x - b.origin.x) ^ 2 + (o.origin.y - b.origin.y) ^ 2)
      cap = math.min(cap, d - o.claim_radius)
    end
  end
  local new = math.min(cur + PERIMETER_STEP, cap)
  if new <= cur then return end
  -- The cordon (cordon.lua): the step is an arc of posts its drones build; the claim follows once they stand.
  if ops.cordon_step and ops.cordon_step(b, new, near) then return end
  ops.perimeter_advance(b, new, near, nd)
end

-- The line cuts what crosses it (strangling, the cut half): at war, the player's belts and pipes standing on the claim's
-- edge (within BAND of it) are blown, a few a pass, so a supply line through Serenity's ground stops at its line. The
-- counter is under it: an underground belt or pipe whose two ends stand off the line passes (the span between has no
-- entity to cut), or around it. Each blast is the tell: an explosion where the belt was. Only where its guns are: a stretch
-- of the edge with none of its turrets within SEVER_REACH is not cut. Cutting the whole circle, a broken line fell back
-- and cut again at its new edge: the engaged player who broke it lost as many belt tiles as the turtle (factory, seven
-- seeds, 2,924 against 2,784); now breaking a sector's posts opens that sector.
local SEVER_TYPES = {"transport-belt", "underground-belt", "splitter", "pipe", "pipe-to-ground", "loader", "loader-1x1"}
local BAND = 1.5
local SEVER_MAX = 8
local SEVER_BOX = 7
local SEVER_REACH = 30            -- half a cordon's post spacing: a standing arc covers its whole span
local GUNS = {"ammo-turret", "electric-turret", "fluid-turret"}
function ops.sever(b)
  if storage.sever_off or not (shared.CORPS[b.corp].temper or {}).provoked_only or not b.claim_radius or b.fallen then return 0 end
  local forces = {}
  for _, f in ipairs(shared.player_forces()) do
    if stance.standing(b.corp, f.name) == "enemy" then forces[#forces + 1] = f end
  end
  if #forces == 0 then return 0 end
  local surface = game.surfaces[b.surface]
  local R, o = b.claim_radius, b.origin
  local n = math.ceil(2 * math.pi * R / (2 * SEVER_BOX - 2))
  local seen, cut = {}, 0
  for k = 0, n - 1 do
    local a = 2 * math.pi * k / n
    local x, y = o.x + R * math.cos(a), o.y + R * math.sin(a)
    local guarded
    for _, e in pairs(surface.find_entities_filtered{area = {{x - SEVER_BOX, y - SEVER_BOX}, {x + SEVER_BOX, y + SEVER_BOX}},
      force = forces, type = SEVER_TYPES}) do
      local id = e.unit_number
      if id and not seen[id] then
        seen[id] = true
        local d = math.sqrt((e.position.x - o.x) ^ 2 + (e.position.y - o.y) ^ 2)
        if guarded == nil and math.abs(d - R) <= BAND then
          guarded = surface.count_entities_filtered{position = {x, y}, radius = SEVER_REACH, force = b.force, type = GUNS,
            limit = 1} > 0
        end
        if guarded and math.abs(d - R) <= BAND then
          local at = e.position
          surface.create_entity{name = "explosion", position = at}
          e.die(game.forces[b.force])
          cut = cut + 1
          b.severed = (b.severed or 0) + 1
          if cut >= SEVER_MAX then return cut end
        end
      end
    end
  end
  return cut
end

-- The claim steps out to `new` (at once, or once its cordon's arc stands): the map, the notices, the named warning.
function ops.perimeter_advance(b, new, near, nd)
  local surface = game.surfaces[b.surface]
  b.perimeter = new
  b.perimeter_steps = (b.perimeter_steps or 0) + 1
  if ops.claim_map then ops.claim_map(b) end
  local where = string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y, surface.name)
  -- One step ahead: the structure the next step will enclose, named.
  local warn = near and near.valid and near.type ~= "resource" and nd and nd > new and nd <= new + PERIMETER_STEP and b.warned ~= near.unit_number
  if warn then b.warned = near.unit_number end
  for _, f in ipairs(enemies(game.forces[b.force])) do
    if #f.players > 0 and not shared.is_corp(f.name) then
      if b.perimeter_steps % 3 == 1 then
        shared.notice(f, {"lp.perimeter", shared.corp_label(b.corp), where, math.floor(new)})
      end
      if warn then
        shared.notice(f, {"lp.perimeter-warning", shared.corp_label(b.corp), near.localised_name,
          string.format("[gps=%d,%d,%s]", near.position.x, near.position.y, surface.name)})
      end
    end
  end
end
return {FLOOR_TICKS = FLOOR_TICKS}
end

return perimeter
