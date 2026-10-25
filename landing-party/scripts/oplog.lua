-- Operation records (the user, 2026-10-25: "a monitoring tool for raids/sieges ... the source camp, the waypoints used,
-- the targets, the destruction associated with that precise offensive action, and the unit outcomes"). With the trace
-- on, every corporation operation (raid, siege, strip camp) and every Synthexis wave is followed from launch to end,
-- read from outside (nothing of the AI changes): where it set out from, its target, its staging point or mark, the way
-- it planned, where its units stood every SAMPLE ticks, where each died and to what, what each destroyed, and how it
-- ended. One line of JSON an operation, written to ops.jsonl when it ends (scripts/ops_review.py draws them).
local oplog = {}

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
  return {key = "b" .. id .. ":" .. op.started, faction = b.corp, kind = op.kind, camp = xy(b.origin),
    target = t and xy(t.pos) or nil, target_kind = t and t.kind or nil, owner = t and t.owner or op.owner,
    staging = xy(op.staging or op.site), route = points(op.route or b.op_route), members = op.members or {},
    start = op.started}
end

local function wave_view(w)
  local p = storage.herd and storage.herd.pens and storage.herd.pens[w.pen]
  return {key = "w" .. w.id, faction = "biotech", kind = "wave", camp = p and p.pen.valid and xy(p.pen.position) or nil,
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
  helpers.write_file("landing-party/ops.jsonl", helpers.table_to_json(rec) .. "\n", true)
  s.live[key] = nil
end

local function follow(s, view, base_id, seen)
  local rec = s.live[view.key]
  if not rec then
    rec = {key = view.key, faction = view.faction, kind = view.kind, base = base_id, camp = view.camp,
      target = view.target, target_kind = view.target_kind, owner = view.owner, start = view.start,
      t0 = minute(), samples = {}, deaths = {}, kills = {}, units = {}, size = 0}
    s.live[view.key] = rec
  end
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
        rec.size = rec.size + 1
      end
    end
  end
  rec.samples[#rec.samples + 1] = {t = minute(), p = pts}
end

function oplog.tick(tick)
  if not storage.trace or tick % SAMPLE ~= 17 then return end
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
  end
  local c = e.cause and e.cause.valid and e.cause or nil
  local by = c and c.unit_number and s.member[c.unit_number]
  if by and s.live[by] and ent.type ~= "tree" and ent.type ~= "simple-entity" then
    table.insert(s.live[by].kills, {t = minute(), at = xy(ent.position), name = ent.name, force = ent.force.name})
  end
end

return oplog
