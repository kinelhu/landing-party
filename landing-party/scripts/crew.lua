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
local ops = require("__landing-party__.scripts.ops")

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
local REACH = 12                  -- how far a crew builds from
local REACH_WAIT = 15 * 60
-- Crews lost on one module (or one rebuild) before the camp gives it up: a cordon's posts under a factory's turrets took
-- 168 drones in two hours, one a minute (visit deathworld10x). An abandoned post never stands, so its arc holds: the
-- player's guns held the line.
local GIVE_UP = 3

local CREW_BATCH = 40          -- jobs a crew takes at most (crew.take)
local KEEP = 200               -- parts a compound's or the curtain's crews leave the camp (for rebuilds and sieges)
local ECONOMY = {["lp-fabricator"] = true, ["lp-generator"] = true, ["lp-pylon"] = true, ["lp-drill"] = true}
local function corp_crews(b) return shared.CORPS[b.corp].crews end
-- (The drone its own prototype, lp-constructor: the scout drone passing through other fliers, units.lua.)
local function body(b) return corp_crews(b) == "drone" and "lp-constructor" or shared.variant(b.corp, "lp-hauler") end

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
  -- Nil once nothing stands: a crew sent home after its lander fell crashed on it (factory engage, seed 8).
  return b.lander and b.lander.valid and b.lander or nil
end

-- Past the settlement's own outermost wall or gate on the line from home to the site (the convoy's rule).
local function formation(b, site)
  local s = game.surfaces[b.surface]
  local h = home(b)
  if not h then return nil end
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

-- A truck's way (the user, 2026-10-17: "keeps sending slow haulers to my walls ... the turrets shred it"): planned as
-- a sneaking raid's is (ops.route: out of every known turret's reach, round nests and water), followed as waypoints.
-- No way: nil, and nothing is sent. A drone flies straight: {}.
local function way(b, from, to)
  if corp_crews(b) == "drone" then return {} end
  return ops.route(b, from, to, {turrets = true, nests = true})
end

local function order(u, route, dest)
  local cmds = {}
  for _, w in ipairs(route) do
    table.insert(cmds, {type = defines.command.go_to_location, destination = w, radius = 4, distraction = defines.distraction.none})
  end
  table.insert(cmds, {type = defines.command.go_to_location, destination = dest, radius = 4, distraction = defines.distraction.none})
  u.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
    commands = cmds}
end

-- base.build asks with its next job: true when a crew takes (or waits for) the job's module.
function crew.take(b, job)
  if not corp_crews(b) or storage.crews_off or not job.module or job.module.crew_ok then return false end
  local m = job.module
  if not m.center or in_yard(b, m.center) then m.crew_ok = true; return false end
  if game.tick < (m.crew_retry or 0) then return true end
  if out(b, false) >= MAX_OUT then return true end
  -- Its jobs, in order, off the queue; the bill paid at once.
  -- In batches it can pay for (at least one job, at most CREW_BATCH): a compound's whole bill held the queue's head for two
  -- hours while the camp exported its parts (wfc2).
  local jobs, bill = {}, 0
  -- A compound's or the curtain's never the camp's last KEEP parts: building them down to 23 left nothing to rebuild its
  -- fabricators with once a raid took them all, and it never made a part again (raid, occupy).
  -- What makes parts and power exempt: a district's fabricators held back too, a camp landing with 90 parts never built
  -- one and never made a part.
  local keep = 0
  local spare = b.parts - base.reserve(b)
  for _, q in ipairs(b.queue) do
    if q.module == m then
      local c = q.name and shared.cost[q.name] or 0
      local k = ((m.kind == "curtain" or m.wfc) and not ECONOMY[shared.kind_of(q.name or "")]) and KEEP or 0
      if #jobs > 0 and (bill + c > spare - math.max(keep, k) or #jobs >= CREW_BATCH) then break end
      table.insert(jobs, q)
      bill, keep = bill + c, math.max(keep, k)
    end
  end
  -- A batch of nothing but what makes parts and power is not held for the reserve (the reserve is for it).
  local economy = true
  for _, q in ipairs(jobs) do if q.name and not ECONOMY[shared.kind_of(q.name)] then economy = false end end
  if b.parts < bill + (economy and 0 or base.reserve(b)) + keep then
    -- Short for that, its jobs that make parts and power go alone (a new camp's mining waited behind its ore bin, held
    -- for the reserve, and Kessler-Hayashi's camp never made a part on seed 4242, 2026-10-24).
    local ejobs, ebill = {}, 0
    for _, q in ipairs(b.queue) do
      if q.module == m and q.name and ECONOMY[shared.kind_of(q.name)] and #ejobs < CREW_BATCH then
        local c = shared.cost[q.name] or 0
        if ebill + c > b.parts then break end
        table.insert(ejobs, q)
        ebill = ebill + c
      end
    end
    if #ejobs == 0 then b.waiting = "crew"; return true end
    jobs, bill, keep = ejobs, ebill, 0
  end
  -- A drone lifts off from home (walls do not stop it); a truck forms past the outermost wall.
  local p
  if corp_crews(b) == "drone" then
    local h = home(b)
    if not h then return true end
    p = game.surfaces[b.surface].find_non_colliding_position(body(b), {h.position.x, h.position.y - 4}, 10, 0.5)
  else
    p = formation(b, m.center)
  end
  if not p then return true end
  -- Planned once a module (the crews after the first take the same way).
  local route = m.crew_route
  if not route then
    route = way(b, {p.x, p.y}, m.center)
    if not route then
      -- Under the player's guns all the way: given up before a truck is lost to it.
      m.abandoned = true
      local j = 1
      while b.queue[j] do if b.queue[j].module == m then table.remove(b.queue, j) else j = j + 1 end end
      b.crews_unrouted = (b.crews_unrouted or 0) + 1
      base.trace(b, string.format("crew: no way to the %s at %.0f,%.0f out of the player's guns: given up (%s)", m.kind,
        m.center[1], m.center[2], serpent.line(ops.last_route)))
      return true
    end
    m.crew_route = route
  end
  local u = game.surfaces[b.surface].create_entity{name = body(b), position = p, force = b.lander.force}
  if not u then return true end
  storage.crew_owner = storage.crew_owner or {}
  storage.crew_owner[u.unit_number] = b.id
  -- The jobs it took off the queue, those only (all of the module's went, and a compound's later batches were lost).
  local taken = {}
  for _, q in ipairs(jobs) do taken[q] = true end
  local j = 1
  while b.queue[j] do if taken[b.queue[j]] then table.remove(b.queue, j) else j = j + 1 end end
  b.parts = b.parts - bill
  b.crews = b.crews or {}
  local c = {unit = u, module = m, site = m.center, jobs = jobs, k = 1, bill = bill, spent = 0, phase = "drive",
    started = game.tick, best = math.huge, best_at = game.tick, routed = #route > 0}
  table.insert(b.crews, c)
  order(u, route, m.center)
  b.crews_sent = (b.crews_sent or 0) + 1
  base.trace(b, string.format("crew %d: a %s takes %d jobs (%d parts) to the %s at %.0f,%.0f", b.crews_sent, corp_crews(b), #jobs, bill,
    m.kind, m.center[1], m.center[2]))
  return true
end

-- Where a crew fell its parts are lost, nothing left (the user, 2026-11-03: no materials dropped; a wreck of iron, copper
-- and circuits until then).
local function spill(s, pos, parts) end

-- failed: the crew was killed or stuck (counts toward GIVE_UP: a camp sent 24 crews to two sites they could not reach,
-- visit deathworld10x); returns what was given up, if anything.
local function requeue(b, c, failed)
  if c.rebuild then
    -- Back on the rebuild list, due again after REQUEUE.
    local dropped = 0
    for i = c.k, #c.jobs do
      local r = c.jobs[i]
      r.crew_fails = (r.crew_fails or 0) + (failed and 1 or 0)
      if r.crew_fails >= GIVE_UP then
        dropped = dropped + 1
      else
        r.due = game.tick + (storage.crew_requeue or REQUEUE)
        table.insert(b.rebuild, r)
      end
    end
    return dropped > 0 and string.format("%d rebuilds", dropped) or nil
  end
  local m = c.module
  m.crew_fails = (m.crew_fails or 0) + (failed and 1 or 0)
  if m.crew_fails >= GIVE_UP then
    m.abandoned = true
    return "the " .. m.kind
  end
  for i = #c.jobs, c.k, -1 do table.insert(b.queue, 1, c.jobs[i]) end
  m.crew_retry = game.tick + (storage.crew_requeue or REQUEUE)
end

local function done(b, i, why)
  local c = b.crews[i]
  local h = home(b)
  if c.unit.valid and h then
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
          shared.notice(f, post and {"lp.line-held", shared.corp_label(b.corp), where, tostring(GIVE_UP)}
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
    -- On a planned way, a detour may lead away from the site a while: stuck is standing still.
    if c.routed then
      local a = c.anchor
      if not a or (p.x - a[1]) ^ 2 + (p.y - a[2]) ^ 2 > 16 then c.anchor, c.best_at = {p.x, p.y}, game.tick end
    end
    if game.tick - c.best_at > STUCK then
      b.parts = b.parts + (c.bill - c.spent)
      local given = requeue(b, c, true)
      b.crews_stuck = (b.crews_stuck or 0) + 1
      if given then b.crews_gave_up = (b.crews_gave_up or 0) + 1 end
      -- What it stood among (cliffs measured before the corporations blast them, 2026-10-26).
      local cl = s.count_entities_filtered{position = p, radius = 12, type = "cliff"}
      local wa = s.count_tiles_filtered{position = p, radius = 12, collision_mask = "water_tile"}
      local tr = s.count_entities_filtered{position = p, radius = 12, type = "tree"}
      shared.refused(b, cl > 0 and "crew stuck by cliffs" or wa > 0 and "crew stuck by water" or "crew stuck, neither")
      return done(b, i, string.format("stuck on the way to %.0f,%.0f, home with its parts%s; within 12: %d cliffs, %d water tiles, %d trees",
        c.site[1], c.site[2], given and string.format("; %d crews failed there, %s given up", GIVE_UP, given) or "", cl, wa, tr))
    end
    if base.occupied(b, s, c.site) then
      b.parts = b.parts + (c.bill - c.spent)
      -- New work: a failure, as a crew stuck on the way is (GIVE_UP of them and the site is given up). Not counted, a
      -- site beside the player's mining outpost was tried for ever (226 times in 90 minutes, system 12345), and as the
      -- planner plans only with its queue empty, Grubstake's camp sat on 6,600 parts and built nothing more. A rebuild
      -- waits instead: its ground held, what was lost there comes back once it is free (scenario occupy).
      local given = requeue(b, c, not c.rebuild)
      if given then b.crews_gave_up = (b.crews_gave_up or 0) + 1 end
      return done(b, i, "the site is occupied: turned back with its parts" .. (given and ("; " .. given .. " given up") or ""))
    end
    if d <= ARRIVE * ARRIVE then
      c.phase, c.next_at = "build", game.tick
      c.unit.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none}
    end
    return
  end
  if game.tick < c.next_at then return end
  -- The nearest work first: of the jobs left, one already within REACH is built before the crew moves on (walking to each
  -- in queue order made a district's crew five times slower, and Serenity's line fell behind its schedule: line, bait).
  local here = c.jobs[c.k]
  if here and here.pos and not here.tiles and (p.x - here.pos[1]) ^ 2 + (p.y - here.pos[2]) ^ 2 > REACH * REACH then
    for i = c.k + 1, #c.jobs do
      local q = c.jobs[i]
      if q.tiles or (q.pos and (p.x - q.pos[1]) ^ 2 + (p.y - q.pos[2]) ^ 2 <= REACH * REACH) then
        c.jobs[c.k], c.jobs[i] = q, here
        c.going = nil
        break
      end
    end
  end
  local job = c.jobs[c.k]
  -- Built from beside it (the user, 2026-10-21: a beam laying a turret by the player's base from a screen away read as
  -- unfair): a job farther than REACH, it goes there first; one it cannot get near in REACH_WAIT (a truck walled out by
  -- the module's own walls) it builds from where it is.
  if job and job.pos and not job.tiles then
    local d = (p.x - job.pos[1]) ^ 2 + (p.y - job.pos[2]) ^ 2
    if d > REACH * REACH then
      if c.going ~= c.k then
        c.going, c.going_at = c.k, game.tick
        c.unit.commandable.set_command{type = defines.command.go_to_location, destination = job.pos, radius = REACH - 3,
          distraction = defines.distraction.none}
        return
      elseif game.tick - c.going_at < REACH_WAIT then
        return
      end
      b.crews_far = (b.crews_far or 0) + 1
    end
  end
  c.next_at = game.tick + BUILD_TICKS
  if not job then
    local left = false
    for _, q in ipairs(b.queue) do if q.module == c.module then left = true break end end
    if c.module and not left then c.module.built = true end
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
    -- A truck its own building now overlaps steps clear: on 2.1 a unit inside an entity fails its next order at once,
    -- and the crew stood "stuck on the way" (scenario crew, a compound's pylon set beside where its truck parked,
    -- 2026-10-24). Drones fly; trucks do not.
    local u = c.unit
    if u and u.valid and u.type == "unit" and e.valid then
      local a, q = e.bounding_box, u.bounding_box
      if a.left_top.x < q.right_bottom.x and q.left_top.x < a.right_bottom.x and a.left_top.y < q.right_bottom.y
        and q.left_top.y < a.right_bottom.y then
        local to = s.find_non_colliding_position(u.name, u.position, 8, 0.5)
        if to then u.teleport(to) end
      end
    end
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
        if storage.crew_owner then storage.crew_owner[u.unit_number] = nil end
        u.destroy(); table.remove(b.crews_home, i)
      end
    end
  end
end

-- debug_crew: a module of `names` queued first at pos for settlement b (a far outpost for the crew scenario).
function crew.debug_module(b, pos, names)
  local m = {kind = "outpost", center = {pos[1], pos[2]}, entities = {}}
  table.insert(b.modules, m)
  -- A pad under it first, as a cordon post has (its floor must wait for the crew).
  local tiles = {}
  for i = -1, 1 do for j = -1, 1 do table.insert(tiles, {math.floor(pos[1]) + i, math.floor(pos[2]) + j - 8}) end end
  table.insert(b.queue, 1, {tiles = tiles, floor = "pad", module = m})
  for k, name in ipairs(names) do
    table.insert(b.queue, k + 1, {name = name, pos = {pos[1] + ((k - 1) % 3) * 3 - 3, pos[2] + math.floor((k - 1) / 3) * 3},
      module = m})
  end
  return #names
end

function crew.stats(b)
  return {sent = b.crews_sent or 0, done = b.crews_done or 0, lost = b.crews_lost or 0, stuck = b.crews_stuck or 0,
    gave_up = b.crews_gave_up or 0, unrouted = b.crews_unrouted or 0, far = b.crews_far or 0,
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
    if not h then return true end
    p = s.find_non_colliding_position(body(b), {h.position.x, h.position.y - 4}, 10, 0.5)
  else
    p = formation(b, job.pos)
  end
  if not p then return true end
  local route = way(b, {p.x, p.y}, job.pos)
  if not route then
    local taken = {}
    for _, r in ipairs(jobs) do taken[r] = true end
    local j = 1
    while b.rebuild[j] do if taken[b.rebuild[j]] then table.remove(b.rebuild, j) else j = j + 1 end end
    b.crews_unrouted = (b.crews_unrouted or 0) + 1
    base.trace(b, string.format("crew: no way to %.0f,%.0f out of the player's guns: %d rebuilds given up", job.pos[1],
      job.pos[2], #jobs))
    return true
  end
  local u = s.create_entity{name = body(b), position = p, force = b.lander.force}
  if not u then return true end
  storage.crew_owner = storage.crew_owner or {}
  storage.crew_owner[u.unit_number] = b.id
  local taken = {}
  for _, r in ipairs(jobs) do taken[r] = true; r.crew_wait = nil end
  local j = 1
  while b.rebuild[j] do if taken[b.rebuild[j]] then table.remove(b.rebuild, j) else j = j + 1 end end
  b.parts = b.parts - bill
  b.crews = b.crews or {}
  table.insert(b.crews, {unit = u, rebuild = true, site = {job.pos[1], job.pos[2]}, jobs = jobs, k = 1, bill = bill, spent = 0,
    phase = "drive", started = game.tick, best = math.huge, best_at = game.tick, routed = #route > 0})
  order(u, route, job.pos)
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
