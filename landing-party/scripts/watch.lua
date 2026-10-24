-- The watchdog (development; the user, 2026-10-24: "just making sure we know what we are doing when we find a bug").
-- Today's faults were all silent: three camps whose economy stopped for good, tanks standing in their camps with orders,
-- a crew waiting behind an ore bin; each was found from a missed target hours later. Every 10 seconds, while tracing,
-- each settlement is held to four invariants, and a broken one is traced once (WATCH ...) with what it saw:
--   economy  no part made for ECONOMY_TICKS while short of a fabricator's price, or with no fabricator standing
--   queue    the same job at the head of its build queue for QUEUE_TICKS (what it waits for, the parts, the reserve)
--   stuck    its units under orders that have not moved STUCK_MOVE tiles in STUCK_TICKS (where, which, what is round them)
--   army     under a quarter of its cap for ARMY_TICKS while it has a unit's price in hand
-- Counted by kind (watch.state, remote watch_state); the sims report them (tests/lp-sim, scripts/system_report.py).
local shared = require("__landing-party__.shared")

local watch = {}

local EVERY = 600
local ECONOMY_TICKS = 10 * 3600
local QUEUE_TICKS = 5 * 3600
local STUCK_TICKS, STUCK_MOVE = 3 * 3600, 3
local ARMY_TICKS = 10 * 3600

local function st()
  storage.watch = storage.watch or {alarms = {}, units = {}, log = {}}
  return storage.watch
end

local function alarm(b, kind, text, trace)
  local w = st()
  w.alarms[kind] = (w.alarms[kind] or 0) + 1
  b.watch = b.watch or {}
  b.watch[kind] = (b.watch[kind] or 0) + 1
  table.insert(w.log, {tick = game.tick, base = b.id, kind = kind, text = text})
  if #w.log > 200 then table.remove(w.log, 1) end
  trace(b, "WATCH " .. kind .. ": " .. text)
end

local MOVING = {[defines.command.go_to_location] = true, [defines.command.compound] = true,
  [defines.command.attack_area] = true}

local function economy(b, tick, trace)
  local e = b.watch_economy
  if not e or (b.made or 0) > e.made then b.watch_economy = {made = b.made or 0, t = tick, told = false}; return end
  local fab = shared.cost["lp-fabricator"] or 0
  local valid = 0
  for _, f in ipairs(b.fabs or {}) do if f.valid then valid = valid + 1 end end
  if not e.told and tick - e.t > ECONOMY_TICKS and (valid == 0 or b.parts < fab) then
    e.told = true
    alarm(b, "economy", string.format("no part made in %d minutes: %d fabricators, %d parts (a fabricator %d), queue %d, " ..
      "waiting on %s", (tick - e.t) / 3600, valid, b.parts, fab, #(b.queue or {}), tostring(b.waiting)), trace)
  end
end

local function queue(b, tick, trace, reserve)
  local head = b.queue and b.queue[1]
  local q = b.watch_queue
  if not head then b.watch_queue = nil; return end
  if not q or q.job ~= head then b.watch_queue = {job = head, t = tick, told = false}; return end
  if not q.told and tick - q.t > QUEUE_TICKS then
    q.told = true
    alarm(b, "queue", string.format("%s at the head for %d minutes (waiting on %s; %d parts, reserve %d, %d jobs behind)",
      head.name or (head.tiles and "paving") or "?", (tick - q.t) / 3600, tostring(b.waiting), b.parts, reserve or 0,
      #b.queue - 1), trace)
  end
end

local function stuck(b, tick, trace, units)
  local w = st()
  local caught, kinds, cx, cy = 0, {}, 0, 0
  for _, u in pairs(units) do
    if u.valid and u.unit_number then
      local c = u.commandable
      local cmd = c and c.command
      local rec = w.units[u.unit_number]
      local p = u.position
      if not rec or (p.x - rec.x) ^ 2 + (p.y - rec.y) ^ 2 > STUCK_MOVE * STUCK_MOVE or not (cmd and MOVING[cmd.type]) then
        w.units[u.unit_number] = {x = p.x, y = p.y, t = tick}
      elseif tick - rec.t > STUCK_TICKS and not rec.told then
        rec.told = true
        caught = caught + 1
        kinds[u.name] = (kinds[u.name] or 0) + 1
        cx, cy = cx + p.x, cy + p.y
      end
    end
  end
  if caught > 0 then
    cx, cy = cx / caught, cy / caught
    local s = game.surfaces[b.surface]
    local parts = {}
    for k, n in pairs(kinds) do parts[#parts + 1] = n .. " " .. k end
    table.sort(parts)
    alarm(b, "stuck", string.format("%d units under orders unmoved %d minutes about %.0f,%.0f: %s; within 12: %d walls, %d " ..
      "buildings, %d trees", caught, STUCK_TICKS / 3600, cx, cy, table.concat(parts, ", "),
      s.count_entities_filtered{position = {cx, cy}, radius = 12, type = {"wall", "gate"}},
      s.count_entities_filtered{position = {cx, cy}, radius = 12, force = b.force} -
        s.count_entities_filtered{position = {cx, cy}, radius = 12, force = b.force, type = {"unit", "spider-unit"}},
      s.count_entities_filtered{position = {cx, cy}, radius = 12, type = "tree"}), trace)
  end
end

local function army_(b, tick, trace, strength, cap, price, reserve)
  local a = b.watch_army
  local low = cap > 0 and strength < cap / 4 and b.parts >= price + (reserve or 0)
  if not low then b.watch_army = nil; return end
  if not a then b.watch_army = {t = tick, told = false}; return end
  if not a.told and tick - a.t > ARMY_TICKS then
    a.told = true
    alarm(b, "army", string.format("%d of a cap of %d for %d minutes with %d parts in hand (a unit about %d, reserve %d; " ..
      "built %d, lost %d)", strength, cap, (tick - a.t) / 3600, b.parts, price, reserve or 0, b.units_built or 0,
      b.units_lost or 0), trace)
  end
end

-- deps: {trace, units(b) (its roster's units), strength(b), cap(b), price(b), reserve(b)}.
function watch.tick(tick, deps)
  if tick % EVERY ~= 0 or not storage.trace then return end
  local w = st()
  for _, b in pairs(storage.bases or {}) do
    if not b.fallen and b.lander and b.lander.valid then
      local reserve = deps.reserve(b)
      economy(b, tick, deps.trace)
      queue(b, tick, deps.trace, reserve)
      stuck(b, tick, deps.trace, deps.units(b))
      army_(b, tick, deps.trace, deps.strength(b), deps.cap(b), deps.price(b), reserve)
    end
  end
  -- Units gone: forgotten.
  if tick % (EVERY * 30) == 0 then
    local keep = {}
    for _, b in pairs(storage.bases or {}) do
      for _, u in pairs(deps.units(b)) do if u.valid and u.unit_number and w.units[u.unit_number] then keep[u.unit_number] = w.units[u.unit_number] end end
    end
    w.units = keep
  end
end

function watch.state()
  local w = st()
  local per = {}
  for _, b in pairs(storage.bases or {}) do if b.watch then per[b.id] = {corp = b.corp, alarms = b.watch} end end
  return {alarms = w.alarms, bases = per, log = w.log}
end

return watch
