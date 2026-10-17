-- Crews (the user, 2026-10-16: the lander's blue beam "feels weirdly decorporealized ... have a builder unit leave the
-- base with parts"; Fable: docs/reviews/2026-10-16-builders-consult.md). A yard builds what it can reach: within YARD of
-- the lander or a depot, as before. Crews build the rest: a module beyond every yard is handed to a crew, which pays
-- its whole bill at once, drives out (formed past the camp's outermost wall on its line: gates open for no unit), builds
-- each entity at the site at the camp's own pace (one a BUILD_TICKS), and goes home. Killed, it spills what it still
-- carried as ordinary items (what parts are made of) and the module waits REQUEUE before another crew goes. No nearer
-- its site for STUCK, it turns home with its parts. Two bodies, one codepath (shared.CORPS[corp].crews): Grubstake's
-- truck (the hauler's hull for now), on the ground, formed past its walls, building with a welder's sparks; Serenity's
-- constructor drone (the harrier's airframe for now), flying straight over its walls, building with its beam.
local shared = require("__landing-party__.shared")
local base = require("__landing-party__.scripts.base")
local standing = require("__landing-party__.scripts.standing")

local crew = {}

local YARD = 40
local MAX_OUT = 2                 -- crews building modules
local MAX_MEND = 2                -- crews rebuilding, apart: an outpost's turrets waited 50 s behind two building crews
                                  -- and the player's turrets captured it meanwhile (defend)

local function out(b, rebuild)
  local n = 0
  for _, c in ipairs(b.crews or {}) do if (c.rebuild or false) == rebuild then n = n + 1 end end
  return n
end
local BUILD_TICKS = 90
local STUCK = 60 * 60
local REQUEUE = 60 * 60
local ARRIVE = 8
-- Crews lost on one module (or one rebuild) before the camp gives it up: a cordon's posts under a factory's turrets took
-- 168 drones in two hours, one a minute (visit deathworld10x). An abandoned post never stands, so its arc holds: the
-- player's guns held the line.
local GIVE_UP = 3

local function corp_crews(b) return shared.CORPS[b.corp].crews end
local function body(b) return shared.variant(b.corp, corp_crews(b) == "drone" and "lp-harrier" or "lp-hauler") end

local function yards(b)
  local out = {}
  if b.lander and b.lander.valid then table.insert(out, b.lander.position) end
  for _, d in ipairs(b.depots or {}) do if d.valid then table.insert(out, d.position) end end
  return out
end

local function in_yard(b, pos)
  for _, y in ipairs(yards(b)) do
    if (y.x - pos[1]) ^ 2 + (y.y - pos[2]) ^ 2 <= YARD * YARD then return true end
  end
  return false
end

local function home(b)
  for _, d in ipairs(b.depots or {}) do if d.valid then return d end end
  return b.lander
end

-- Past the settlement's own outermost wall or gate on the line from home to the site (the convoy's rule).
local function formation(b, site)
  local s = game.surfaces[b.surface]
  local h = home(b)
  local hx, hy = h.position.x, h.position.y
  local ux, uy = site[1] - hx, site[2] - hy
  local ul = math.max(1, math.sqrt(ux * ux + uy * uy))
  local out = 12
  for d = 0, ul / 2, 2 do
    if s.count_entities_filtered{position = {hx + ux / ul * d, hy + uy / ul * d}, radius = 2.5, force = h.force,
      type = {"wall", "gate"}, limit = 1} > 0 then out = math.max(out, d + 5) end
  end
  out = math.min(out, ul)
  return s.find_non_colliding_position(shared.variant(b.corp, "lp-hauler"), {hx + ux / ul * out, hy + uy / ul * out}, 20, 0.5)
end

-- base.build asks with its next job: true when a crew takes (or waits for) the job's module.
function crew.take(b, job)
  if not corp_crews(b) or storage.crews_off or not job.module or job.module.crew_ok then return false end
  local m = job.module
  if not m.center or in_yard(b, m.center) then m.crew_ok = true; return false end
  if game.tick < (m.crew_retry or 0) then return true end
  if out(b, false) >= MAX_OUT then return true end
  -- Its jobs, in order, off the queue; the bill paid at once.
  local jobs, bill = {}, 0
  for _, q in ipairs(b.queue) do
    if q.module == m then
      table.insert(jobs, q)
      bill = bill + (q.name and shared.cost[q.name] or 0)
    end
  end
  if b.parts < bill + base.reserve(b) then b.waiting = "crew"; return true end
  -- A drone lifts off from home (walls do not stop it); a truck forms past the outermost wall.
  local p
  if corp_crews(b) == "drone" then
    local h = home(b)
    p = game.surfaces[b.surface].find_non_colliding_position(body(b), {h.position.x, h.position.y - 4}, 10, 0.5)
  else
    p = formation(b, m.center)
  end
  local u = p and game.surfaces[b.surface].create_entity{name = body(b), position = p, force = b.lander.force}
  if not u then return true end
  local j = 1
  while b.queue[j] do if b.queue[j].module == m then table.remove(b.queue, j) else j = j + 1 end end
  b.parts = b.parts - bill
  b.crews = b.crews or {}
  local c = {unit = u, module = m, site = m.center, jobs = jobs, k = 1, bill = bill, spent = 0, phase = "drive",
    started = game.tick, best = math.huge, best_at = game.tick}
  table.insert(b.crews, c)
  u.commandable.set_command{type = defines.command.go_to_location, destination = m.center, radius = 4,
    distraction = defines.distraction.none}
  b.crews_sent = (b.crews_sent or 0) + 1
  base.trace(b, string.format("crew %d: a %s takes %d jobs (%d parts) to the %s at %.0f,%.0f", b.crews_sent, corp_crews(b), #jobs, bill,
    m.kind, m.center[1], m.center[2]))
  return true
end

-- What parts are made of, spilled where a crew fell (the loot rule): iron half, copper a quarter, circuits a tenth.
local function spill(s, pos, parts)
  for _, it in ipairs({{"iron-plate", parts / 2}, {"copper-plate", parts / 4}, {"electronic-circuit", parts / 10}}) do
    local n = math.floor(it[2])
    if n > 0 then s.spill_item_stack{position = pos, stack = {name = it[1], count = n}, enable_looted = true} end
  end
end

-- lost: the crew was killed (counts toward GIVE_UP); returns what was given up, if anything.
local function requeue(b, c, lost)
  if c.rebuild then
    -- Back on the rebuild list, due again after REQUEUE.
    local dropped = 0
    for i = c.k, #c.jobs do
      local r = c.jobs[i]
      r.crews_lost = (r.crews_lost or 0) + (lost and 1 or 0)
      if r.crews_lost >= GIVE_UP then
        dropped = dropped + 1
      else
        r.due = game.tick + (storage.crew_requeue or REQUEUE)
        table.insert(b.rebuild, r)
      end
    end
    return dropped > 0 and string.format("%d rebuilds", dropped) or nil
  end
  local m = c.module
  m.crews_lost = (m.crews_lost or 0) + (lost and 1 or 0)
  if m.crews_lost >= GIVE_UP then
    m.abandoned = true
    return "the " .. m.kind
  end
  for i = #c.jobs, c.k, -1 do table.insert(b.queue, 1, c.jobs[i]) end
  m.crew_retry = game.tick + (storage.crew_requeue or REQUEUE)
end

local function done(b, i, why)
  local c = b.crews[i]
  if c.unit.valid then
    local h = home(b)
    c.unit.commandable.set_command{type = defines.command.go_to_location, destination = h.position, radius = 10,
      distraction = defines.distraction.none}
    b.crews_home = b.crews_home or {}
    table.insert(b.crews_home, c.unit)
  end
  table.remove(b.crews, i)
  base.trace(b, "crew: " .. why)
end

local function step(b, i)
  local c = b.crews[i]
  local s = game.surfaces[b.surface]
  if not c.unit.valid then
    local left = c.bill - c.spent
    local at = c.last or c.site
    spill(s, {at[1], at[2]}, left)
    local given = requeue(b, c, true)
    b.crews_lost = (b.crews_lost or 0) + 1
    table.remove(b.crews, i)
    if given then
      b.crews_gave_up = (b.crews_gave_up or 0) + 1
      -- Told: a post given up is the line held (the cordon's arc never stands), anything else a site given up.
      local where = string.format("[gps=%d,%d,%s]", c.site[1], c.site[2], s.name)
      local post = not c.rebuild and c.module.kind == "post"
      for _, f in pairs(game.forces) do
        if #f.players > 0 and not shared.is_corp(f.name) then
          f.print(post and {"lp.line-held", shared.corp_label(b.corp), where, tostring(GIVE_UP)}
            or {"lp.crew-gave-up", shared.corp_label(b.corp), where, tostring(GIVE_UP)})
        end
      end
      standing.incident(b.corp, post and "line held" or "site given up", {c.site[1], c.site[2]},
        string.format("%d crews lost", GIVE_UP))
      base.trace(b, string.format("crew lost with %d parts at %.0f,%.0f: %d crews lost there, %s at %.0f,%.0f given up", left,
        at[1], at[2], GIVE_UP, given, c.site[1], c.site[2]))
    else
      base.trace(b, string.format("crew lost with %d parts: spilled at %.0f,%.0f, its jobs wait", left, at[1], at[2]))
    end
    return
  end
  local p = c.unit.position
  c.last = {p.x, p.y}
  if c.phase == "drive" then
    local d = (p.x - c.site[1]) ^ 2 + (p.y - c.site[2]) ^ 2
    if d < c.best - 1 then c.best, c.best_at = d, game.tick end
    if game.tick - c.best_at > STUCK then
      b.parts = b.parts + (c.bill - c.spent)
      requeue(b, c)
      b.crews_stuck = (b.crews_stuck or 0) + 1
      return done(b, i, string.format("stuck on the way to %.0f,%.0f, home with its parts", c.site[1], c.site[2]))
    end
    if base.occupied(b, s, c.site) then
      b.parts = b.parts + (c.bill - c.spent)
      requeue(b, c)
      return done(b, i, "the site is occupied: turned back with its parts")
    end
    if d <= ARRIVE * ARRIVE then
      c.phase, c.next_at = "build", game.tick
      c.unit.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none}
    end
    return
  end
  if game.tick < c.next_at then return end
  c.next_at = game.tick + BUILD_TICKS
  local job = c.jobs[c.k]
  if not job then
    if c.module then c.module.built = true end
    b.crews_done = (b.crews_done or 0) + 1
    if c.rebuild then b.rebuilt = b.rebuilt + (c.placed or 0) end
    return done(b, i, string.format("%s at %.0f,%.0f in %ds", c.rebuild and "rebuilt what was lost" or ("built the "
      .. c.module.kind), c.site[1], c.site[2], (game.tick - c.started) / 60))
  end
  c.k = c.k + 1
  if job.tiles then
    base.pave_job(b, job)
    c.next_at = game.tick
    return
  end
  c.spent = c.spent + (shared.cost[job.name] or 0)
  local e = base.place_job(b, job, true)
  if e then
    c.placed = (c.placed or 0) + 1
    if corp_crews(b) == "drone" then
      rendering.draw_line{from = c.unit, to = e, surface = s, color = {0.5, 0.8, 1, 0.8}, width = 2, time_to_live = BUILD_TICKS}
    else
      rendering.draw_line{from = c.unit, to = e, surface = s, color = {1, 0.65, 0.25, 0.8}, width = 2, time_to_live = BUILD_TICKS}
      s.create_entity{name = "explosion-hit", position = e.position}
    end
  else
    base.trace(b, string.format("crew: cannot place %s at %.1f,%.1f: skipped", job.name, job.pos[1], job.pos[2]))
  end
end

function crew.tick(tick)
  if tick % 30 ~= 19 then return end
  for _, b in pairs(storage.bases or {}) do
    for i = #(b.crews or {}), 1, -1 do step(b, i) end
    -- Home again: a truck back at its depot is parked (taken off the map; the next crew is a fresh truck).
    for i = #(b.crews_home or {}), 1, -1 do
      local u = b.crews_home[i]
      local h = home(b)
      if not u.valid then table.remove(b.crews_home, i)
      elseif h and h.valid and (u.position.x - h.position.x) ^ 2 + (u.position.y - h.position.y) ^ 2 < 16 * 16 then
        u.destroy(); table.remove(b.crews_home, i)
      end
    end
  end
end

-- debug_crew: a module of `names` queued first at pos for settlement b (a far outpost for the crew scenario).
function crew.debug_module(b, pos, names)
  local m = {kind = "outpost", center = {pos[1], pos[2]}, entities = {}}
  table.insert(b.modules, m)
  for k, name in ipairs(names) do
    table.insert(b.queue, k, {name = name, pos = {pos[1] + ((k - 1) % 3) * 3 - 3, pos[2] + math.floor((k - 1) / 3) * 3},
      module = m})
  end
  return #names
end

function crew.stats(b)
  return {sent = b.crews_sent or 0, done = b.crews_done or 0, lost = b.crews_lost or 0, stuck = b.crews_stuck or 0,
    gave_up = b.crews_gave_up or 0,
    out = #(b.crews or {})}
end

-- Rebuilds beyond the yards (base.rebuild asks with each due job): the due ones within REBUILD_AREA of it go out together
-- on one crew, paid at once. Returns true when a crew took them or one is awaited (job.crew_wait), nil for the yard.
local REBUILD_AREA = 30
function crew.rebuild(b, job)
  if not corp_crews(b) or storage.crews_off or in_yard(b, job.pos) then return nil end
  job.crew_wait = true
  if out(b, true) >= MAX_MEND then return true end
  local jobs, bill = {}, 0
  for _, r in ipairs(b.rebuild) do
    if game.tick >= r.due and not r.occupied and (r.pos[1] - job.pos[1]) ^ 2 + (r.pos[2] - job.pos[2]) ^ 2 <= REBUILD_AREA ^ 2 then
      table.insert(jobs, r)
      bill = bill + (shared.cost[r.name] or 0)
    end
  end
  if b.parts < bill then
    if game.tick >= (b.mend_said or 0) then
      b.mend_said = game.tick + 600
      base.trace(b, string.format("crew: %d rebuilds wait for parts (%d of %d)", #jobs, b.parts, bill))
    end
    return true
  end
  local s = game.surfaces[b.surface]
  local p
  if corp_crews(b) == "drone" then
    local h = home(b)
    p = s.find_non_colliding_position(body(b), {h.position.x, h.position.y - 4}, 10, 0.5)
  else
    p = formation(b, job.pos)
  end
  local u = p and s.create_entity{name = body(b), position = p, force = b.lander.force}
  if not u then return true end
  local taken = {}
  for _, r in ipairs(jobs) do taken[r] = true; r.crew_wait = nil end
  local j = 1
  while b.rebuild[j] do if taken[b.rebuild[j]] then table.remove(b.rebuild, j) else j = j + 1 end end
  b.parts = b.parts - bill
  b.crews = b.crews or {}
  table.insert(b.crews, {unit = u, rebuild = true, site = {job.pos[1], job.pos[2]}, jobs = jobs, k = 1, bill = bill, spent = 0,
    phase = "drive", started = game.tick, best = math.huge, best_at = game.tick})
  u.commandable.set_command{type = defines.command.go_to_location, destination = job.pos, radius = 4,
    distraction = defines.distraction.none}
  b.crews_sent = (b.crews_sent or 0) + 1
  base.trace(b, string.format("crew %d: a %s takes %d rebuilds (%d parts) to %.0f,%.0f", b.crews_sent, corp_crews(b), #jobs,
    bill, job.pos[1], job.pos[2]))
  return true
end

function crew.far(b, pos) return corp_crews(b) and not in_yard(b, pos) end

base.crew_take = crew.take
base.crew_rebuild = crew.rebuild
base.crew_far = crew.far
return crew
