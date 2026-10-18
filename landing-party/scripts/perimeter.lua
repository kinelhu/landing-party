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

function ops.perimeter(b, tick)
  if not (shared.CORPS[b.corp].temper or {}).provoked_only or not b.claim_radius then return end
  b.landed = b.landed or tick
  local fast = storage.perimeter_fast
  local start, every = fast and 3600 or PERIMETER_START, fast and 3600 or PERIMETER_TICKS
  if tick - b.landed < start then return end
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
        if o then
          if b.strangling ~= o.unit_number then
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

-- The claim steps out to `new` (at once, or once its cordon's arc stands): the map, the notices, the named warning.
function ops.perimeter_advance(b, new, near, nd)
  local surface = game.surfaces[b.surface]
  b.perimeter = new
  b.perimeter_steps = (b.perimeter_steps or 0) + 1
  if ops.claim_map then ops.claim_map(b) end
  local where = string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y, surface.name)
  -- One step ahead: the structure the next step will enclose, named.
  local warn = near and near.valid and nd and nd > new and nd <= new + PERIMETER_STEP and b.warned ~= near.unit_number
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
