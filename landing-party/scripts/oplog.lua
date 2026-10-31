-- Operation records (the user, 2026-10-25: "a monitoring tool for raids/sieges ... the source camp, the waypoints used,
-- the targets, the destruction associated with that precise offensive action, and the unit outcomes"). With the trace
-- on, every corporation operation (raid, siege, strip camp) and every Synthexis wave is followed from launch to end,
-- read from outside (nothing of the AI changes): where it set out from, its target, its staging point or mark, the way
-- it planned, where its units stood every SAMPLE ticks, where each died and to what, what each destroyed, and how it
-- ended. One line of JSON an operation, written to ops.jsonl when it ends (scripts/ops_review.py draws them).
local attempt = require("__landing-party__.scripts.attempt")
local valuemap = require("__landing-party__.scripts.valuemap")

local oplog = {}
local RECENT = 20   -- records kept after they close (oplog.recent: the tests and the siege lab)

local SAMPLE = 180

local function st()
  storage.oplog = storage.oplog or {live = {}, member = {}}
  return storage.oplog
end

local function xy(p)
  if not p then return nil end
  return {math.floor((p.x or p[1]) + 0.5), math.floor((p.y or p[2]) + 0.5)}
end

local function points(list)
  local out = {}
  for _, p in ipairs(list or {}) do out[#out + 1] = xy(p) end
  return out
end

local function minute() return math.floor(game.tick / 360) / 10 end

-- What the operation is now: its live members and what it planned.
local function corp_view(id, b)
  local op = b.op
  local t = b.intel and b.intel.targets and b.intel.targets[op.target]
  -- (Its mortars among its members: what their shells break is its own, attempt.lua.)
  local members = op.members or {}
  if (op.mortars and #op.mortars > 0) or op.howitzer then
    members = {}
    for _, m in ipairs(op.members or {}) do members[#members + 1] = m end
    for _, m in ipairs(op.mortars or {}) do members[#members + 1] = m end
    if op.howitzer then members[#members + 1] = op.howitzer end
  end
  return {key = "b" .. id .. ":" .. op.started, faction = b.corp, force = b.force, kind = op.kind, camp = xy(b.origin),
    target = t and xy(t.pos) or nil, target_kind = t and t.kind or nil, owner = t and t.owner or op.owner,
    staging = xy(op.staging or op.site), route = points(op.route or b.op_route), members = members,
    start = op.started}
end

local function wave_view(w)
  local p = storage.herd and storage.herd.pens and storage.herd.pens[w.pen]
  local method = w.cut and "cut" or w.wait_cut and "strike" or ((w.big_sent or 0) > 0 or w.fodder_set) and "siege"
    or w.trust == "probe" and "probe" or "raid"
  return {key = "w" .. w.id, faction = "biotech", force = "lp-biotech", kind = "wave", method = method,
    camp = p and p.pen.valid and xy(p.pen.position) or nil,
    target = xy(w.goal or w.center), staging = xy(w.mark), breach = xy(w.breach), route = points(w.trail),
    members = w.members or {}, start = w.t0}
end

local function close(s, key, rec)
  -- Its outcome from the operation's own record.
  if rec.faction == "biotech" then
    for _, l in ipairs((storage.herd and storage.herd.log) or {}) do
      if "w" .. l.id == key then rec.outcome, rec.back = l.outcome, l.left; rec.breach = rec.breach or xy(l.breach) end
    end
  else
    local b = storage.bases and storage.bases[rec.base]
    for _, l in ipairs(b and b.ops_log or {}) do
      if l.started == rec.start then rec.outcome, rec.back = l.outcome, l.back end
    end
  end
  rec["end"] = minute()
  for _, un in ipairs(rec.units or {}) do if s.member[un] == key then s.member[un] = nil end end
  rec.units = nil
  rec.attempt.inside = rec.attempt.inside or false
  helpers.write_file("landing-party/ops.jsonl", helpers.table_to_json(rec) .. "\n", true)
  s.recent = s.recent or {}
  s.recent[#s.recent + 1] = rec
  while #s.recent > RECENT do table.remove(s.recent, 1) end
  s.live[key] = nil
end

local function follow(s, view, base_id, seen)
  local rec = s.live[view.key]
  if not rec then
    rec = {key = view.key, faction = view.faction, kind = view.kind, base = base_id, camp = view.camp,
      target = view.target, target_kind = view.target_kind, owner = view.owner, start = view.start,
      t0 = minute(), samples = {}, deaths = {}, kills = {}, units = {}, size = 0, force = view.force,
      -- What it did, as every attacker's is read (attempt.lua): sent, lost and got in mediums and worth, whether it got
      -- in seen from outside, the defence it met.
      attempt = {method = view.method or view.kind, sent = 0, lost = 0, got = 0, inside = false}}
    s.live[view.key] = rec
  end
  local surface
  for _, u in ipairs(view.members) do if u.valid then surface = u.surface; break end end
  seen[view.key] = true
  -- What it planned can come after it set out (a wave's mark after its scout's loop).
  rec.staging = view.staging or rec.staging
  rec.breach = view.breach or rec.breach
  if view.route and #view.route > 0 then rec.route = view.route end
  local pts = {}
  for _, u in ipairs(view.members) do
    if u.valid and u.unit_number then
      pts[#pts + 1] = xy(u.position)
      if not s.member[u.unit_number] then
        s.member[u.unit_number] = view.key
        rec.units[#rec.units + 1] = u.unit_number
        -- (Its units alone in its size and what it sent: its mortars set up again after each move had new numbers, counted
        -- anew; the code review, 2026-10-31.)
        if u.type == "unit" then
          rec.size = rec.size + 1
          rec.attempt.sent = rec.attempt.sent + attempt.worth(u.name)
        end
      end
    end
  end
  rec.samples[#rec.samples + 1] = {t = minute(), p = pts}
  local a, from = rec.attempt, rec.staging or rec.camp
  a.method = view.method or a.method
  if surface and rec.target and not a.sig then a.sig = attempt.sig(surface, rec.owner or "player", rec.target) end
  if surface and not a.inside and #pts > 0 then
    a.inside = attempt.inside(surface, rec.force, from, rec.target, pts)
    if a.inside then a.t_inside, a.tick_inside = minute(), game.tick end
  end
end

-- Whether a live operation is in, more often than its samples (INSIDE_EVERY): the contract's timing, attempt.inside.
local INSIDE_EVERY = 30
local function look_inside(s, view)
  local rec = s.live[view.key]
  if not rec or rec.attempt.inside or not rec.target then return end
  local pts, surface = {}, nil
  for _, u in ipairs(view.members) do
    if u.valid then pts[#pts + 1] = u.position; surface = surface or u.surface end
  end
  if surface and #pts > 0 and attempt.inside(surface, rec.force, rec.staging or rec.camp, rec.target, pts) then
    rec.attempt.inside, rec.attempt.t_inside, rec.attempt.tick_inside = true, minute(), game.tick
  end
end

function oplog.tick(tick)
  if not storage.trace then return end
  if tick % INSIDE_EVERY == 17 and tick % SAMPLE ~= 17 and storage.oplog then
    for id, b in pairs(storage.bases or {}) do if b.op and b.op.started then look_inside(storage.oplog, corp_view(id, b)) end end
    for _, w in pairs((storage.herd and storage.herd.waves) or {}) do look_inside(storage.oplog, wave_view(w)) end
  end
  if tick % SAMPLE ~= 17 then return end
  local s = st()
  local seen = {}
  for id, b in pairs(storage.bases or {}) do
    if b.op and b.op.started then follow(s, corp_view(id, b), id, seen) end
  end
  for _, w in pairs((storage.herd and storage.herd.waves) or {}) do
    if w.stage ~= "scout" or w.mark then follow(s, wave_view(w), nil, seen) end
  end
  for key, rec in pairs(s.live) do
    if not seen[key] then close(s, key, rec) end
  end
end

-- A member's death, and what a member destroyed (control.lua, on_entity_died).
function oplog.on_died(e)
  if not storage.trace or not storage.oplog then return end
  local s = storage.oplog
  local ent = e.entity
  local key = ent.unit_number and s.member[ent.unit_number]
  if key and s.live[key] then
    local c = e.cause and e.cause.valid and e.cause or nil
    table.insert(s.live[key].deaths, {t = minute(), at = xy(ent.position), name = ent.name,
      killer = c and c.name or (e.force and e.force.name) or "?"})
    s.live[key].attempt.lost = s.live[key].attempt.lost + attempt.worth(ent.name)
  end
  local c = e.cause and e.cause.valid and e.cause or nil
  local by = c and c.unit_number and s.member[c.unit_number]
  if by and s.live[by] and ent.type ~= "tree" and ent.type ~= "simple-entity" then
    table.insert(s.live[by].kills, {t = minute(), at = xy(ent.position), name = ent.name, force = ent.force.name})
    s.live[by].attempt.got = s.live[by].attempt.got + valuemap.razed_of(ent)
  end
end

-- The last RECENT records closed, oldest first (the tests and the siege lab).
function oplog.recent() return (storage.oplog and storage.oplog.recent) or {} end

return oplog
