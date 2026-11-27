-- Veterancy (DESIGN.md, "Veterancy"; the user, 2026-11-10: "Veterancy system for individual units à la C&C. Rewards the
-- AI mechanics we implemented that aim for attackers to return home"). A unit's rank is its quality: the engine raises a
-- unit's health 30% a level and its damage about 48% (scenario vetprobe). Kills earn merit, and the rank comes in the
-- field, the tick after the kill that earned it (the user: "Weird to promote back at camp. Why not promote during
-- fights?"; every turret-rank mod on the portal promotes on the kill). A unit is not raised a quality in place
-- (order_upgrade refuses units; 2.1 has no other way), so a promotion is a swap: the copy takes the old one's group, its
-- command and every reference storage holds to it (rewire), then the old one goes.
--   merit       storage.merit[unit_number]: points banked, carried across a swap
--   on_died     credits the killer: a unit killed its value over the killer's (kill_merit), a turret its price's,
--               a spawner 1, another building BUILDING; at most to its next rank a kill; a rank earned is queued
--   tick        promotes what was queued: never inside the death event, where the callers still hold the killer
--   promote     the unit, or its promoted copy, rewired in its place
-- A leaf (pool reads it): shared and threat (a leaf) only.
local shared = require("__landing-party__.shared")
local threat = require("__landing-party__.scripts.threat")
local veterancy = {}

-- Raised as a unit is promoted, before the old one goes ({old = the unit, new = its copy, rank}): a mod holding our
-- units (the test harness, a mod of the player's) puts the copy where it held the old one; the rewiring reaches only
-- this mod's storage (scenario rail: the harness's own list of railgunners read the promoted ones as dead). Its id:
-- remote.call("landing-party", "promoted_event").
veterancy.PROMOTED = script.generate_event_name()

veterancy.RANKS = {{quality = "uncommon", merit = 3}, {quality = "rare", merit = 8}, {quality = "epic", merit = 16}}
local LEVEL = {normal = 0, uncommon = 1, rare = 2, epic = 3, legendary = 4}
local SPAWNER, BUILDING = 1, 0.1
-- What is not worth merit: what holds and carries (walls, belts, poles, pipes, rails), a corpse's worth of nothing.
local WORTHLESS = {wall = true, gate = true, ["transport-belt"] = true, ["underground-belt"] = true, splitter = true,
  ["electric-pole"] = true, pipe = true, ["pipe-to-ground"] = true, ["straight-rail"] = true, ["curved-rail-a"] = true,
  ["curved-rail-b"] = true, ["half-diagonal-rail"] = true, ["legacy-straight-rail"] = true, lamp = true}
local TURRETS = {["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true, ["artillery-turret"] = true,
  turret = true}

local function merit() storage.merit = storage.merit or {}; return storage.merit end

-- A unit's fighting value (the user, 2026-11-10: "Merit should earn careful balancing. Seems like a huge wave of small
-- biters should not give 1 point each if the max a behemoth will give is 4?"): its health times its damage a tick
-- (lp-unit-hit, the prototypes' own attack read in data-final-fixes), Lanchester's measure of what it takes to beat it.
-- A unit with no attack read (a spider unit) its health alone, against the killer's health alone.
local hits
local function value(name)
  hits = hits or prototypes.mod_data["lp-unit-hit"].data
  local p = prototypes.entity[name]
  local hp = p and p.get_max_health() or 1
  local h = hits[name]
  local dps = 0
  if h then for _, a in pairs(h.dmg) do dps = dps + a end; dps = dps / h.cooldown end
  return hp, dps
end
-- A turret's (or a worm's) merit (the user, 2026-11-10: "Turrets should earn though!"): what crossing one costs, in medium
-- biters lost (threat.prior_of: by kind, scaled by its owner's research; shared.PER_TURRET for a gun), each worth a
-- medium's kill to this killer. A gun turret to a trooper about two, a researched laser more.
-- A worm has no price by kind (a gun's flat one read a small worm as a behemoth's): its health in mediums, the measure
-- attempt.worth prices units by.
function veterancy.turret_merit(dead_name, dead_force, by_name)
  local p, med = prototypes.entity[dead_name], prototypes.entity["medium-biter"]
  local mediums = (p and p.type == "turret" and med) and p.get_max_health() / med.get_max_health()
    or threat.prior_of(dead_name, dead_force, shared.PER_TURRET)
  return mediums * veterancy.kill_merit("medium-biter", by_name)
end

-- A kill's merit: the victim's value over the killer's (measured, scenario vetprobe; to a trooper: a small biter 0.06, a
-- medium 0.67, a peer 1, a tank 25, a behemoth 113; to a tank, a trooper 0.04).
-- One kill raises a unit one rank at most (on_died): a last shot on what a turret line wore down is not a career.
function veterancy.kill_merit(dead_name, by_name)
  local vh, vd = value(dead_name)
  local kh, kd = value(by_name)
  if vd > 0 and kd > 0 then return (vh * vd) / (kh * kd) end
  return vh / math.max(1, kh)
end

function veterancy.rank(u) return LEVEL[u.quality and u.quality.name or "normal"] or 0 end

-- Whose units rank: the mod's own units (the corporations' and the player's), not the corporations' builders, and not
-- Synthexis's (the user, 2026-11-10: "Doesn't seem so thematic for synthexis no?"; "Yeah exempt"): a hive learns as a
-- whole (its waves adapt to what kills them) and breeds its biters to be spent. Its force's units, and a bred biter
-- whoever owns it (the player's, captured from an incubator), are neither credited nor promoted.
local function ranks(u)
  return u and u.valid and u.unit_number and (u.type == "unit" or u.type == "spider-unit") and u.name:sub(1, 3) == "lp-"
    and u.name:sub(1, 8) ~= "lp-bred-" and u.force.name ~= shared.BIOTECH.force
    and not (storage.crew_owner and storage.crew_owner[u.unit_number])
end

-- The rank its merit has earned: 0 to #RANKS.
local function earned(u)
  local m, r = merit()[u.unit_number] or 0, 0
  for k, rk in ipairs(veterancy.RANKS) do if m >= rk.merit then r = k end end
  return r
end
veterancy.earned = earned

local function queue(u)
  local q = storage.vet_due or {units = {}}
  storage.vet_due = q
  q.at = nil
  q.units[u.unit_number] = q.units[u.unit_number] or {unit = u, tries = 0}
end

-- Queued when its merit has earned a rank it lacks (debug_merit's units too).
function veterancy.check(u) if ranks(u) and earned(u) > veterancy.rank(u) then queue(u) end end

function veterancy.on_died(e)
  local dead, by = e.entity, e.cause
  if dead.unit_number and storage.merit then storage.merit[dead.unit_number] = nil end
  if storage.vet_off or not ranks(by) or dead.force == by.force then return end
  local m
  if dead.type == "unit" or dead.type == "spider-unit" then
    m = veterancy.kill_merit(dead.name, by.name)
  elseif dead.type == "unit-spawner" then
    m = SPAWNER
  elseif TURRETS[dead.type] then
    m = veterancy.turret_merit(dead.name, dead.force, by.name)
  elseif dead.prototype.is_building and not WORTHLESS[dead.type] then
    m = BUILDING
  else
    return
  end
  local t = merit()
  local had = t[by.unit_number] or 0
  -- (At most to the next rank above what it has banked.)
  local next_at
  for _, rk in ipairs(veterancy.RANKS) do if rk.merit > had then next_at = rk.merit; break end end
  t[by.unit_number] = next_at and math.min(had + m, next_at) or had + m
  if earned(by) > veterancy.rank(by) then queue(by) end
end


-- The tables that key units by their number, as paths in storage (a number in a path, any: a settlement's, a wave's, a
-- player's). Only these have a key moved: an integer key elsewhere is something else's (a log's line, a build queue's
-- place, a tile list's), and a unit number in a new map is small (13, a trooper's, in scenario veteran) and matches them:
-- moved by a rule (any integer key past a table's array part), a log line and a queue went to the copy's number, and
-- the player's trooper list, its keys read as its array part, kept the old one and lost the trooper. A new table keyed
-- by unit number goes here; scenario veteran's trace (its paths before a swap and after) shows one missed.
local KEYED = {}
for _, p in ipairs({"merit", "unit_owner", "crew_owner", "carrying", "scorch", "scorch_by", "aim_redirected", "fall_skip",
  "owner", "cmd.troopers", "cmd.selected.*", "cmd.groups.*.*", "oplog.member", "sep.at", "watch.units", "bases.*.roster",
  "bases.*.returning_since", "bases.*.op.resent", "herd.waves.*.units", "herd.waves.*.straggling", "herd.waves.*.holders",
  "herd.waves.*.known", "herd.waves.*.left_behind", "herd.waves.*.big_busy", "herd.waves.*.fodder_set", "herd.waves.*.aim",
  "herd.waves.*.sapper_at", "herd.waves.*.sapper_last", "herd.waves.*.seen", "bases.*.yard_slot", "bases.*.yard_sent",
  "bases.*.yard_dest", "bases.*.yard_tries", "bases.*.stand_of", "bases.*.stand_slot", "bases.*.stand_sent",
  "bases.*.stand_dest", "bases.*.stand_tries", "bases.*.stand_seen"}) do KEYED[p] = true end
veterancy.KEYED = KEYED

-- What the rewiring does not walk: what in storage holds no unit, and grows with a game (the stutter: at two hours of
-- the walled contact timeline a promotion walked 12597 tables, 16 ms, a frame's hitch; the user: "A game six times
-- bigger doesn't seem so far fetched?"). Records: closed and live operations' (unit numbers, not units), a building's
-- owner ({base, module}), a build queue, a cordon's history, ore scans and cells, pylon spots, arcs drawn (11672 of those
-- 12597 tables). And a settlement's buildings: its lists of walls, modules, turrets, pylons and the rest, each a
-- reference the walk had to ask the engine about, three calls each (3700 of them left at two hours, growing with what
-- it builds, its walls most). What is left grows with its units and its plans. The trace (refs) still walks it all: a
-- unit held in one would show in scenario veteran as a reference left behind.
local SKIP = {}
for _, p in ipairs({"oplog.recent", "oplog.live", "owner.*", "bases.*.queue", "bases.*.cordon_history", "bases.*.ore_scan",
  "bases.*.ore_cells", "bases.*.pylon_spots", "bases.*.arcs_drawn", "bases.*.cordon", "bases.*.pylons", "bases.*.bins",
  "bases.*.drills", "bases.*.fabs", "bases.*.gens", "bases.*.turrets", "bases.*.radars", "bases.*.walls", "bases.*.depots",
  "bases.*.launchpads", "bases.*.lamps", "bases.*.mines", "bases.*.flamers", "bases.*.modules", "bases.*.cells",
  "bases.*.rebuild", "bases.*.gate_list", "bases.*.domes", "bases.*.drop_gens", "bases.*.camp_turrets",
  -- (0.3.1's kept maps and readings, numbers and positions, no unit: walked, a promotion took 20 to 23 ms, the spike
  -- guard on the user's nw save.)
  -- (Not the stand tables keyed by unit, KEYED: a promotion moves those.)
  "bases.*.ways", "bases.*.ways_job", "bases.*.stands", "bases.*.scan_queue", "bases.*.orbit", "farms.list.*.ways", "farms.list.*.ways_job", "farms.list.*.census",
  "farms.list.*.census_job", "farms.list.*.seed_job", "creep.cultures.*.land", "creep.cultures.*.land_job", "creep.chunks",
  "sep.chunks", "sep.cq"}) do
  SKIP[p] = true
end

-- Walks all of storage (the trace's: SKIP too), each table with its path, numbers as * (KEYED's form) and as written
-- (`mark`, a unit number, as # where it keys a KEYED table, so a unit's paths and its copy's compare).
local function each_table(fn, mark)
  local seen = {}
  local function walk(t, norm, path)
    if seen[t] then return end
    seen[t] = true
    fn(t, norm, path)
    for k, v in pairs(t) do
      if type(v) == "table" then
        local seg = (k == mark and KEYED[norm]) and "#" or tostring(k)
        walk(v, norm .. "." .. (type(k) == "number" and "*" or tostring(k)), path .. "." .. seg)
      end
    end
  end
  for k, v in pairs(storage) do
    if type(v) == "table" and k ~= "vet_stats" then walk(v, tostring(k), tostring(k)) end
  end
end

local function is_unit(v, un)
  return type(v) == "userdata" and v.object_name == "LuaEntity" and v.valid and v.unit_number == un
end

-- Tests (storage.vet_trace): where storage holds a unit, as paths (its number in a key written #), sorted: every value
-- that is it, and its number as a key of a KEYED table. A promotion compares the old unit's before the swap with the
-- copy's after (scenario veteran: none left behind). Its number as a key elsewhere is counted apart (stray): not a
-- reference, unless a table is missing from KEYED.
local function refs(u)
  local un, out, stray = u.unit_number, {}, 0
  each_table(function(t, norm, path)
    for k, v in pairs(t) do
      if is_unit(v, un) then out[#out + 1] = path .. "." .. ((k == un and KEYED[norm]) and "#" or tostring(k)) end
    end
    if t[un] ~= nil then
      if KEYED[norm] then out[#out + 1] = path .. ".#=key" else stray = stray + 1 end
    end
  end, un)
  table.sort(out)
  return out, stray
end

-- Every reference storage holds to the old units, to their copies (made: each old unit and its copy), in one
-- walk however many swap this tick: any LuaEntity among them (a raid's members, a herd's, a garrison, the player's
-- troopers, a scout, a carrier), and their numbers as keys of the KEYED tables (owners, merit, a selection, a herd's
-- sets, the yard's slots), moved to the copies' numbers. Its own walker, not each_table: one pass a table, a table's
-- pattern made once (CHILD) and no path strings (the cost: a whole roster promoted at once, twelve walks of 3 ms each,
-- 37 ms in one tick, 0.2.311's camp run).
local CHILD = {}   -- a pattern's children's patterns, by key (numbers: one, "*"); not storage: rebuilt on load
local function child(norm, k)
  local c = CHILD[norm]
  if not c then c = {}; CHILD[norm] = c end
  local key = type(k) == "number" and "*" or k
  local cn = c[key]
  if not cn then cn = norm .. "." .. tostring(key); c[key] = cn end
  return cn
end

-- A reference is told to be one of the old units by `==` while they are few (vetprobe: 24 ns, safe on a dead entity, a
-- commandable, a surface, a render object), by its unit number past that (object_name, valid, unit_number: 370 ns).
local EQ_MAX = 12
-- (made: {old, new} pairs.)
local function rewire(made)
  if storage.rewire_off then return 0, {} end   -- (tests only: the trace's check seen failing)
  local seen, nodes, moved = {}, 0, {}
  local swaps = {}   -- an old unit's number: its copy
  for _, m in ipairs(made) do swaps[m.old.unit_number] = m.new end
  local count = #made
  local few = count <= EQ_MAX
  local function copy_of(v)
    if few then
      for i = 1, count do if v == made[i].old then return made[i].new end end
      return nil
    end
    if v.object_name == "LuaEntity" and v.valid then
      local un = v.unit_number
      return un and swaps[un]
    end
  end
  local function walk(t, norm)
    seen[t] = true
    nodes = nodes + 1
    for k, v in pairs(t) do
      local tv = type(v)
      if tv == "table" then
        if not seen[v] then
          local cn = child(norm, k)
          if not SKIP[cn] then walk(v, cn) end
        end
      elseif tv == "userdata" then
        local n = copy_of(v)
        if n then t[k] = n end
      end
    end
    -- (Values first, then the keys: a key is not added while pairs runs.)
    if KEYED[norm] then
      for on, n in pairs(swaps) do
        if t[on] ~= nil then
          t[n.unit_number], t[on] = t[on], nil
          moved[#moved + 1] = norm
        end
      end
    end
  end
  for k, v in pairs(storage) do
    if type(v) == "table" and k ~= "vet_stats" and not SKIP[k] then walk(v, k) end
  end
  return nodes, moved
end

-- What the copy keeps of the old unit's place in a fight: its group (joined before the old one leaves it, so a group of
-- one is not left empty), else its command; and its AI settings (the corporations' units are told not to wander off).
local AI = {"allow_destroy_when_commands_fail", "allow_try_return_to_spawner", "do_separation", "join_attacks",
  "path_resolution_modifier", "size_in_group"}
local function take_place(old, new)
  local oa, na = old.ai_settings, new.ai_settings
  if oa and na then for _, k in ipairs(AI) do pcall(function() na[k] = oa[k] end) end end
  local oc, nc = old.commandable, new.commandable
  if not (oc and nc) then return end
  local g = oc.parent_group
  if g and g.valid then
    g.add_member(nc)
  elseif oc.has_command then
    pcall(nc.set_command, oc.command)
  end
end

-- At its outline's upper right, about a tile across (first drawn at half a tile beside a trooper's shoulder: in the ranks
-- film, 2026-11-11, a third of a tile at a close zoom, lost on a tank's hull and gone at play zoom).
local function badge(n, r)
  local b = n.prototype.collision_box
  local off = {b.right_bottom.x + 0.35, b.left_top.y - 0.55}
  rendering.draw_sprite{sprite = "lp-rank-" .. r, surface = n.surface, target = {entity = n, offset = off},
    x_scale = 0.95, y_scale = 0.95, render_layer = "air-entity-info-icon"}
end

-- Promotes these units together (each at the rank it has earned, the same place, the same share of its health, its
-- merit carried, the old one gone; one walk for all). Returns what became of each: its copy, or the unit itself when it
-- has earned nothing more or its copy could not be placed.
local function promote_all(units)
  local out, made, any = {}, {}, false
  for i, u in ipairs(units) do
    out[i] = u
    if not storage.vet_off and ranks(u) and earned(u) > veterancy.rank(u) then
      local r = earned(u)
      local share = u.health / u.max_health
      local n = u.surface.create_entity{name = u.name, position = u.position, force = u.force, quality = veterancy.RANKS[r].quality}
      if n then
        n.health = n.max_health * share
        if u.orientation then pcall(function() n.orientation = u.orientation end) end
        local m = {old = u, new = n, rank = r, had_group = u.commandable and u.commandable.parent_group ~= nil,
          had_command = u.commandable and u.commandable.has_command}
        if storage.vet_trace then m.before, m.stray = refs(u) end
        take_place(u, n)
        made[#made + 1] = m
        out[i] = n
        any = true
      end
    end
  end
  if not any then return out end
  local clock = helpers.create_profiler()
  local nodes, moved = rewire(made)
  clock.stop()
  -- (Its cost in the log, a walk a line: it grows with storage; read on the contact timelines.)
  log({"", "[lp] promotion: ", #made, " rewired over ", nodes, " tables, ", clock})
  local st = storage.vet_stats or {walk_max = 0, moved = {}}
  storage.vet_stats = st
  st.walk_max = math.max(st.walk_max, nodes)
  for _, p in ipairs(moved) do st.moved[p] = (st.moved[p] or 0) + 1 end
  for _, m in ipairs(made) do
    local n = m.new
    script.raise_event(veterancy.PROMOTED, {old = m.old, new = n, rank = m.rank})
    m.old.destroy()
    storage.promoted = (storage.promoted or 0) + 1
    if m.before then
      local after = refs(n)
      st.traced = (st.traced or 0) + 1
      if table.concat(m.before, " ") ~= table.concat(after, " ") then
        st.lost = st.lost or {}
        st.lost[#st.lost + 1] = {before = m.before, after = after}
      end
      st.where = st.where or {}
      local nc = n.commandable
      st.where[#st.where + 1] = {name = n.name, force = n.force.name, x = n.position.x, y = n.position.y, tick = game.tick,
        had_group = m.had_group, group = nc and nc.parent_group ~= nil, had_command = m.had_command,
        command = nc and nc.has_command, refs = #m.before, stray = m.stray}
    end
    badge(n, m.rank)
    if shared.notices_on() then
      rendering.draw_text{text = {"lp.rank-" .. m.rank}, surface = n.surface, target = {entity = n, offset = {0, -2}},
        color = {1, 0.85, 0.3}, scale = 1.2, alignment = "center", time_to_live = 180}
      n.surface.play_sound{path = "utility/new_objective", position = n.position, volume_modifier = 0.6}
    end
  end
  return out
end

-- Its promoted copy, or the unit itself (promote_all, of one).
function veterancy.promote(u) return promote_all({u})[1] end

-- The queue on_died fills: promoted the next tick, in unit-number order, together. A copy that could not be placed
-- (crowded) tries again a second later, ten times.
local TRIES = 10
function veterancy.tick(tick)
  local q = storage.vet_due
  if not q or not next(q) or (q.at and tick < q.at) then return end
  storage.vet_due = nil
  local keys, units = {}, {}
  for k in pairs(q.units) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    if q.units[k].unit.valid then units[#units + 1] = q.units[k] end
  end
  local list = {}
  for i, e in ipairs(units) do list[i] = e.unit end
  local out = promote_all(list)
  for i, e in ipairs(units) do
    local u = e.unit
    if out[i] == u and u.valid and earned(u) > veterancy.rank(u) and e.tries < TRIES then
      local due = storage.vet_due or {units = {}, at = tick + 60}
      storage.vet_due = due
      due.units[u.unit_number] = {unit = u, tries = e.tries + 1}
    end
  end
end

-- A ranked unit's strength over its rank's normal (health times damage, the probe's: 1.3 and 1.48 a level): what the
-- AI's sums of worth count it as.
function veterancy.scale(u) return shared.rank_scale(u) end

-- The share of a raid's launched units it turns home below (ops: 0.5, a prospector's 0.7): with an Elite or a Hero in
-- it, at least ELITE_SHARE (the user: "preserving highly elite units vs throwing mass prod in the grinder").
veterancy.ELITE_SHARE = {[2] = 0.6, [3] = 0.7}
function veterancy.abort_share(members, share)
  local top = 0
  for _, u in ipairs(members or {}) do if u.valid then top = math.max(top, veterancy.rank(u)) end end
  return math.max(share, veterancy.ELITE_SHARE[math.min(top, 3)] or 0)
end

function veterancy.stats()
  local st = storage.vet_stats or {}
  local out = {promoted = storage.promoted or 0, merit_max = 0, walk_max = st.walk_max or 0, moved = st.moved or {},
    traced = st.traced or 0, lost = st.lost or {}, where = st.where or {}}
  for _, m in pairs(storage.merit or {}) do out.merit_max = math.max(out.merit_max, m) end
  return out
end

return veterancy
