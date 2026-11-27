-- The debug panel (the user, 2026-11-27: "a debug panel ready for me to actually get insights live and test things easily...
-- it could even swallow the usual /lp commands... give metrics for each camp, like a decision stream with varying degrees
-- of density... what exactly a KH camp is thinking about or why it's not doing anything from the outside. Exposing director
-- behaviour would be good too"; "a way to instantly move to a certain camp or siege... in editor mode").
-- For admins, opened by /lp panel or its key (Ctrl + Shift + L) with its per-player setting on. Four tabs:
--   Camps: each camp; its card (what holds it: its next decision's clock and gates, what its last choice saw and held, its
--     army, operation, works and jobs under way); its decisions (b.log) at three densities; go to it or to its operation
--     (editor or god: there; otherwise the map's remote view, the character left where it stands); a snapshot to a file.
--   Synthexis: its farms and waves out, the same.
--   Director: the director panel's readings and buttons (director_gui.lua).
--   Tools: the /lp verbs (dev.lua) as buttons, on the camp chosen, at the player's position.
-- Reads, and acts through the commands /lp uses: nothing of the game's own is decided here. Refreshed once a second, the
-- camp shown alone; a camp shown keeps a longer log (shared.keep_log), nothing else changes for it.
-- A debugging tool: its words are plain text, not localised.
local shared = require("__landing-party__.shared")
local names = require("__landing-party__.scripts.names")
local pool = require("__landing-party__.scripts.pool")
local army = require("__landing-party__.scripts.army")
local creep = require("__landing-party__.scripts.creep")
local farm = require("__landing-party__.scripts.farm")
local director_gui = require("__landing-party__.scripts.director_gui")

local panel = {}
local NAME = "lp_debug"
local TABS = {"Camps", "Synthexis", "Director", "Tools"}
local DENSITY = {"Operations", "Operations and plans", "Everything"}
-- What a line is, by its words: an operation's (density 1), a plan's (2), the rest (3).
local OPS = {"raid", "siege", "strip", "strike", "launch", "done", "abort", "recall", "stood down", "stands down",
  "answer", "truce", "breach", "assault", "withdraw", "wave", "sends", "lays siege", "landed", "lands", "war", "lost"}
local PLANS = {"build", "queue", "plan", "spread", "district", "research", "buys", "bought", "lab", "depot", "weighs",
  "holds", "hub", "cluster", "perimeter", "line", "relay", "prospect", "mine", "fabricator", "income", "reads", "census"}
local dev   -- set by panel.install (dev requires this module's callers)

local function st()
  storage.lp_panel = storage.lp_panel or {}
  return storage.lp_panel
end
local function prefs(p)
  local s = st()
  s[p.index] = s[p.index] or {tab = 1, density = 1}
  return s[p.index]
end

local function mmss(ticks)
  if not ticks then return "-" end
  local neg = ticks < 0
  local s = math.floor(math.abs(ticks) / 60)
  return string.format("%s%d:%02d", neg and "-" or "", math.floor(s / 60), s % 60)
end
local function standing(b) return b and not b.fallen and b.lander and b.lander.valid end
local function alive(list)
  local n = 0
  for _, u in ipairs(list or {}) do if u.valid then n = n + 1 end end
  return n
end
local function first_pos(list)
  for _, u in ipairs(list or {}) do if u.valid then return u.position end end
end
local function xy(p) return p and (p.x and {x = p.x, y = p.y} or {x = p[1], y = p[2]}) end

-- The level of a line, by its words.
local function level(text)
  local t = text:lower()
  for _, w in ipairs(OPS) do if t:find(w, 1, true) then return 1 end end
  for _, w in ipairs(PLANS) do if t:find(w, 1, true) then return 2 end end
  return 3
end

-- Camps standing, by id.
local function camps()
  local out = {}
  for _, b in pairs(storage.bases or {}) do if standing(b) then out[#out + 1] = b end end
  table.sort(out, function(a, c) return a.id < c.id end)
  return out
end
local function farms()
  local out = {}
  for _, f in pairs(storage.farms and storage.farms.list or {}) do out[#out + 1] = f end
  table.sort(out, function(a, c) return a.id < c.id end)
  return out
end
local function waves()
  local out = {}
  for _, w in pairs(storage.herd and storage.herd.waves or {}) do out[#out + 1] = w end
  table.sort(out, function(a, c) return a.id < c.id end)
  return out
end

-- Where a camp's operation is: its first unit standing, else its site, else its target.
local function op_pos(b)
  local op = b.op
  if not op then return nil end
  local p = first_pos(op.members) or (op.mortar and op.mortar.valid and op.mortar.position) or xy(op.site)
  if p then return xy(p) end
  local t = op.target and b.intel and b.intel.targets and b.intel.targets[op.target]
  return t and xy(t.pos)
end

-- There: in the editor (or god, or spectator) the player goes; otherwise the map's remote view looks, the character
-- left where it stands.
local function go(p, pos, surface_index)
  if not pos then return p.print("nowhere to go") end -- notice-ok: the debug panel's reply to its own button
  local s = game.surfaces[surface_index or p.surface.index]
  local c = p.controller_type
  if c == defines.controllers.editor or c == defines.controllers.god or c == defines.controllers.spectator then
    p.teleport(pos, s)
  else
    p.set_controller{type = defines.controllers.remote, position = pos, surface = s}
  end
end

-- A camp's card: what holds it, line by line.
local function card(b)
  local tick, out = game.tick, {}
  local c = shared.CORPS[b.corp] or {}
  local tags = {}
  if b.hq then tags[#tags + 1] = "HQ" end
  if b.expedition then tags[#tags + 1] = "expedition" end
  if b.armed then tags[#tags + 1] = "armed" end
  if b.army_full then tags[#tags + 1] = "ARMY FULL" end
  if b.quiescent then tags[#tags + 1] = "STOOD DOWN " .. mmss(tick - b.quiescent) .. " ago" end
  out[#out + 1] = string.format("[font=default-bold]%d %s[/font], %s%s  at %d,%d", b.id, names.of(b), c.name or b.corp,
    #tags > 0 and ("  [" .. table.concat(tags, ", ") .. "]") or "", b.origin.x, b.origin.y)
  -- Its army.
  local strength = pool.strength(b)
  out[#out + 1] = string.format("army: strength %d of cap %d; garrison %d, returning %d, raids out %d", strength,
    army.cap(b), alive(b.garrison), alive(b.returning), #(b.raids or {}))
  -- Its operation, or its next.
  local op = b.op
  if op then
    local t = op.target and b.intel and b.intel.targets and b.intel.targets[op.target]
    local p = op_pos(b)
    out[#out + 1] = string.format("operation: %s, %s; on %s of %s%s; %d of %d up; %s ago%s", op.kind, op.phase or "-",
      op.target_kind or (t and t.kind) or "?", op.owner or (t and t.owner) or "?",
      t and t.pos and string.format(" at %d,%d", t.pos[1], t.pos[2]) or "", alive(op.members), op.launched or 0,
      mmss(tick - (op.started or tick)), p and string.format("; its units at %d,%d", p.x, p.y) or "")
  else
    local gates = {}
    if storage.ops_off then gates[#gates + 1] = "ops off" end
    if storage.raids_off then gates[#gates + 1] = "raids off" end
    if storage.army_off then gates[#gates + 1] = "army off" end
    if storage.choice_off then gates[#gates + 1] = "choice off" end
    local withdrawing = storage.corps and storage.corps[b.corp] and storage.corps[b.corp].withdrawing
    if withdrawing then gates[#gates + 1] = "its corporation withdrawing" end
    if b.recall then gates[#gates + 1] = "recalled by a truce on " .. tostring(b.recall.owner) end
    local dt = storage.director and storage.director.active and storage.director.tempo and storage.director.tempo[b.corp]
    if dt and tick < dt.till then gates[#gates + 1] = string.format("director's tempo x%g for %s", dt.factor or 1, mmss(dt.till - tick)) end
    for _, f in ipairs(shared.player_forces()) do
      local tr = storage.truces and storage.truces[b.corp .. "|" .. f.name]
      if tr and tick < tr then gates[#gates + 1] = string.format("truce on %s for %s", f.name, mmss(tr - tick)) end
    end
    local wait = (b.next_op or 0) - tick
    out[#out + 1] = string.format("no operation; next decision %s%s", wait > 0 and ("in " .. mmss(wait)) or "due (each 10 s)",
      #gates > 0 and ("; held: " .. table.concat(gates, ", ")) or "")
  end
  -- What its last choice saw.
  local w = b.choose_why
  if w then
    local by = {}
    for k, n in pairs(w.by or {}) do by[#by + 1] = k .. " " .. n end
    table.sort(by)
    out[#out + 1] = string.format("last choice: %d targets weighed, %d held, %d cooling, %d past its odds%s%s",
      w.seen or 0, w.held or 0, w.cool or 0, w.odds or 0, #by > 0 and ("; held by " .. table.concat(by, ", ")) or "",
      b.dir_short and "; its raid short of units" or "")
  end
  local miss = {}
  for k, n in pairs(b.dir_miss or {}) do miss[#miss + 1] = k .. " " .. n end
  table.sort(miss)
  out[#out + 1] = string.format("operations: %d launched, %d done, %d aborted; fail streak %d; ladder rung %d%s%s",
    b.ops_launched or 0, b.ops_done or 0, b.ops_aborted or 0, b.fail_streak or 0, b.war_rung or 0,
    b.grudge_till and tick < b.grudge_till and ("; grudge " .. mmss(b.grudge_till - tick)) or "",
    #miss > 0 and ("; decisions with nothing: " .. table.concat(miss, ", ")) or "")
  -- Its works.
  local head = b.queue and b.queue[1]
  out[#out + 1] = string.format("works: parts %d (%.0f a minute); queue %d%s", b.parts or 0, b.rate_parts or 0,
    b.queue and #b.queue or 0, head and (", next " .. (head.name or (head.tiles and (#head.tiles .. " tiles of floor")) or "?")) or "")
  -- Jobs under way, spread over ticks.
  local jobs = {}
  for _, k in ipairs({"ways_job", "district_job", "found_job", "scan_queue", "prospect_scan", "wfc_job"}) do
    if b[k] then jobs[#jobs + 1] = k end
  end
  if #jobs > 0 then out[#out + 1] = "under way: " .. table.concat(jobs, ", ") end
  return out
end

-- A farm's card.
local function farm_card(f)
  local tick, out = game.tick, {}
  local c = creep.of(f.id) or {}
  local pens = 0
  for _, p in pairs(f.pens or {}) do if p.pen and p.pen.valid then pens = pens + 1 end end
  out[#out + 1] = string.format("[font=default-bold]farm %d[/font] at %d,%d; %d incubators; biomass %d; income %.1f a minute",
    f.id, f.pos.x, f.pos.y, pens, c.biomass or 0, (f.income or 0) * 3600)
  out[#out + 1] = string.format("last wave %s ago%s; wave cap %d", mmss(tick - (f.last_wave or tick)),
    f.first_at and tick < f.first_at and ("; first wave in " .. mmss(f.first_at - tick)) or "", farm.cap_of(f))
  if f.siege then
    out[#out + 1] = string.format("siege laid at %s: %d of %d", f.siege.at and string.format("%d,%d", f.siege.at.x or f.siege.at[1],
      f.siege.at.y or f.siege.at[2]) or "?", f.siege.k or 0, f.siege.n or 0)
  end
  local jobs = {}
  for _, k in ipairs({"ways_job", "census_job", "seed_job"}) do if f[k] then jobs[#jobs + 1] = k end end
  if f.ways then jobs[#jobs + 1] = "reading " .. mmss(tick - (f.ways.tick or tick)) .. " old" end
  if #jobs > 0 then out[#out + 1] = "readings: " .. table.concat(jobs, ", ") end
  return out
end

local function wave_line(w)
  local p = first_pos(w.members)
  return string.format("wave %d: %s, %d of %d%s", w.id, w.stage or "?", alive(w.members), w.size or 0,
    p and string.format(" at %d,%d", p.x, p.y) or "")
end

-- A camp's decisions at a density, the last n.
local function stream(log, density, n, pattern)
  local out = {}
  for i = #log, 1, -1 do
    local l = log[i]
    if (not pattern or l:find(pattern, 1, true)) and level(l) <= density then table.insert(out, 1, l) end
    if #out >= n then break end
  end
  return out
end

-- Its widgets.
local function labels(parent, lines)
  parent.clear()
  for _, l in ipairs(lines) do
    local e = parent.add{type = "label", caption = l}
    e.style.single_line = false
    e.style.maximal_width = 900
  end
end
local function button(parent, caption, tags)
  return parent.add{type = "button", caption = caption, tags = tags, style = "button"}
end

local function build(p)
  local pr = prefs(p)
  local f = p.gui.screen.add{type = "frame", name = NAME, direction = "vertical"}
  local bar = f.add{type = "flow", direction = "horizontal"}
  bar.drag_target = f
  bar.add{type = "label", caption = "Landing Party debug", style = "frame_title"}.drag_target = f
  local grip = bar.add{type = "empty-widget", style = "draggable_space_header"}
  grip.style.horizontally_stretchable = true
  grip.style.height = 24
  grip.drag_target = f
  bar.add{type = "sprite-button", sprite = "utility/close", style = "frame_action_button", tags = {lp_dbg = "close"}}
  f.location = pr.location or {x = 40, y = 80}
  local tp = f.add{type = "tabbed-pane", name = "tabs"}
  for i, name in ipairs(TABS) do
    local tab = tp.add{type = "tab", caption = name}
    local body = tp.add{type = "flow", name = "t" .. i, direction = "vertical"}
    body.style.minimal_width = 960
    tp.add_tab(tab, body)
  end
  tp.selected_tab_index = pr.tab or 1
  -- Camps.
  local cb = tp.t1
  local row = cb.add{type = "flow", name = "row", direction = "horizontal"}
  local lb = row.add{type = "list-box", name = "camps", tags = {lp_dbg = "camp"}}
  lb.style.width = 300
  lb.style.height = 520
  local right = row.add{type = "flow", name = "right", direction = "vertical"}
  local btns = right.add{type = "flow", direction = "horizontal"}
  button(btns, "Go to camp", {lp_dbg = "go_camp"})
  button(btns, "Go to its operation", {lp_dbg = "go_op"})
  button(btns, "Snapshot to file", {lp_dbg = "snapshot"})
  btns.add{type = "drop-down", name = "density", items = DENSITY, selected_index = pr.density or 1, tags = {lp_dbg = "density"}}
  local cardp = right.add{type = "flow", name = "card", direction = "vertical"}
  cardp.style.minimal_height = 150
  local sp = right.add{type = "scroll-pane", name = "stream", direction = "vertical"}
  sp.style.height = 330
  sp.style.width = 640
  sp.add{type = "flow", name = "lines", direction = "vertical"}
  -- Synthexis.
  local sb = tp.t2
  local row2 = sb.add{type = "flow", name = "row", direction = "horizontal"}
  local lb2 = row2.add{type = "list-box", name = "farms", tags = {lp_dbg = "farm"}}
  lb2.style.width = 300
  lb2.style.height = 520
  local right2 = row2.add{type = "flow", name = "right", direction = "vertical"}
  local b2 = right2.add{type = "flow", direction = "horizontal"}
  button(b2, "Go to", {lp_dbg = "go_farm"})
  button(b2, "A wave now", {lp_dev = "wave"})
  button(b2, "A deep wave now", {lp_dev = "wave deep"})
  button(b2, "Land Synthexis near you", {lp_dev = "biotech"})
  right2.add{type = "flow", name = "card", direction = "vertical"}
  local sp2 = right2.add{type = "scroll-pane", name = "stream", direction = "vertical"}
  sp2.style.height = 380
  sp2.style.width = 640
  sp2.add{type = "flow", name = "lines", direction = "vertical"}
  -- Director: its readings and buttons (director_gui.on_click takes the lp_dir buttons).
  local db = tp.t3
  db.add{type = "flow", name = "lines", direction = "vertical"}
  local rows = {{{"on", "Force on"}, {"off", "Force off"}, {"auto", "As setting"}, {"lull", "Lull now"}, {"surge", "Surge now"},
    {"focus", "Focus strike"}, {"climax", "Climax now"}}, {{"fill", "Fill budget"}, {"empty", "Empty budget"}, {"end", "End beat"},
    {"wave", "Drop wave"}, {"supply", "Supply drop"}, {"research", "Research"}, {"joint", "Joint strike"}}}
  for _, r in ipairs(rows) do
    local fl = db.add{type = "flow", direction = "horizontal"}
    for _, b in ipairs(r) do button(fl, b[2], {lp_dir = b[1]}) end
  end
  local fl = db.add{type = "flow", direction = "horizontal"}
  for corp, c in pairs(shared.CORPS) do button(fl, "Spree: " .. c.name, {lp_dir = "spree", corp = corp}) end
  -- Tools: the /lp verbs, on the camp chosen in Camps, at your position.
  local tb = tp.t4
  tb.add{type = "label", caption = "On the camp chosen in Camps; at your position where a place is wanted (go there first)."}
  local tools = {
    {{"raid", "Raid here"}, {"siege", "Siege here"}, {"strip", "Strip here"}, {"airraid", "Air raid here"}, {"strike", "Orbital strike here"}},
    {{"perimeter", "Perimeter step"}, {"parts 2000", "Parts +2000"}, {"grudge", "Grudge"}, {"provoke", "Provoke"}},
    {{"land serenity", "Land Kessler-Hayashi"}, {"land grubstake", "Land Grubstake"}, {"land serenity 200 now", "Land Kessler-Hayashi now"},
      {"land grubstake 200 now", "Land Grubstake now"}},
    {{"spread", "Synthexis: spread next"}, {"ranks", "Synthexis: ranks next"}, {"burst", "Burst"}, {"incidents", "Incidents"}, {"trace", "Trace to file on/off"}},
  }
  for _, r in ipairs(tools) do
    local fr = tb.add{type = "flow", direction = "horizontal"}
    for _, t in ipairs(r) do button(fr, t[2], {lp_dev = t[1], camp = true}) end
  end
  return f
end

-- Its contents, for the tab shown.
local function fill(p)
  local f = p.gui.screen[NAME]
  if not f then return end
  local pr = prefs(p)
  local tp = f.tabs
  local tab = tp.selected_tab_index or 1
  pr.tab = tab
  if tab == 1 then
    local list = camps()
    local lb = tp.t1.row.camps
    local items, sel = {}, nil
    pr.camp_ids = {}
    for i, b in ipairs(list) do
      pr.camp_ids[i] = b.id
      if b.id == pr.camp then sel = i end
      items[i] = string.format("%d %s (%s) %d%s%s", b.id, names.of(b), (shared.CORPS[b.corp] or {}).name or b.corp,
        alive(b.garrison), b.op and (" " .. b.op.kind .. ":" .. (b.op.phase or "")) or "", b.quiescent and " stood down" or "")
    end
    lb.items = items
    if not sel and #list > 0 then sel, pr.camp = 1, list[1].id end
    if sel then lb.selected_index = sel end
    local right = tp.t1.row.right
    local b = pr.camp and storage.bases[pr.camp]
    if standing(b) then
      labels(right.card, card(b))
      labels(right.stream.lines, stream(b.log or {}, pr.density or 1, 120))
      right.stream.scroll_to_bottom()
    else
      labels(right.card, {"no camp"})
      right.stream.lines.clear()
    end
  elseif tab == 2 then
    local lb = tp.t2.row.farms
    local items, ids, sel = {}, {}, nil
    for _, fm in ipairs(farms()) do
      ids[#ids + 1] = {farm = fm.id}
      items[#items + 1] = string.format("farm %d at %d,%d", fm.id, fm.pos.x, fm.pos.y)
    end
    for _, w in ipairs(waves()) do
      ids[#ids + 1] = {wave = w.id}
      items[#items + 1] = wave_line(w)
    end
    for i, x in ipairs(ids) do
      if (x.farm and x.farm == pr.farm) or (x.wave and x.wave == pr.wave) then sel = i end
    end
    pr.farm_ids = ids
    lb.items = items
    if not sel and #ids > 0 then sel = 1; pr.farm, pr.wave = ids[1].farm, ids[1].wave end
    if sel then lb.selected_index = sel end
    local right = tp.t2.row.right
    local fm = pr.farm and storage.farms and storage.farms.list[pr.farm]
    local w = pr.wave and storage.herd and storage.herd.waves[pr.wave]
    if fm then
      labels(right.card, farm_card(fm))
      labels(right.stream.lines, stream(storage.farm_log or {}, 3, 120, "farm " .. fm.id .. " "))
    elseif w then
      labels(right.card, {wave_line(w), string.format("goal %s; out %s", w.goal and string.format("%d,%d", w.goal.x or w.goal[1],
        w.goal.y or w.goal[2]) or "?", mmss(game.tick - (w.t0 or game.tick)))})
      labels(right.stream.lines, stream(storage.farm_log or {}, 3, 120, "wave " .. w.id))
    else
      labels(right.card, {"no farm"})
      right.stream.lines.clear()
    end
    right.stream.scroll_to_bottom()
  elseif tab == 3 then
    labels(tp.t3.lines, director_gui.lines(p))
  end
end

function panel.toggle(p)
  local f = p.gui.screen[NAME]
  if f then
    prefs(p).location = f.location
    f.destroy()
    panel.watch()
    return false
  end
  build(p)
  fill(p)
  panel.watch()
  return true
end

-- The camps shown keep a longer log (shared.keep_log).
function panel.watch()
  local w = {}
  for _, p in pairs(game.connected_players) do
    if p.gui.screen[NAME] then
      local pr = prefs(p)
      if pr.camp then w[pr.camp] = true end
    end
  end
  storage.lp_watch = next(w) and w or nil
end

-- A file of what the panel shows of the camp chosen, its whole log, and Synthexis's and the director's.
local function snapshot(p)
  local pr = prefs(p)
  local b = pr.camp and storage.bases[pr.camp]
  local out = {string.format("snapshot at tick %d (%s)", game.tick, mmss(game.tick))}
  if standing(b) then
    for _, l in ipairs(card(b)) do out[#out + 1] = (l:gsub("%[/?font[^%]]*%]", "")) end
    out[#out + 1] = "-- its log"
    for _, l in ipairs(b.log or {}) do out[#out + 1] = l end
  end
  out[#out + 1] = "-- camps"
  for _, c in ipairs(camps()) do out[#out + 1] = (card(c)[1]:gsub("%[/?font[^%]]*%]", "")) end
  out[#out + 1] = "-- Synthexis"
  for _, fm in ipairs(farms()) do
    for _, l in ipairs(farm_card(fm)) do out[#out + 1] = (l:gsub("%[/?font[^%]]*%]", "")) end
  end
  for _, w in ipairs(waves()) do out[#out + 1] = wave_line(w) end
  for _, l in ipairs(storage.farm_log or {}) do out[#out + 1] = l end
  out[#out + 1] = "-- director"
  for _, l in ipairs(director_gui.lines(p)) do out[#out + 1] = l end
  local name = string.format("landing-party/snapshot-%d.txt", game.tick)
  helpers.write_file(name, table.concat(out, "\n") .. "\n", false, p.index)
  p.print("snapshot: script-output/" .. name) -- notice-ok: the debug panel's reply to its own button
end

function panel.on_click(e)
  local el = e.element
  if not (el and el.valid and el.tags) then return false end
  local p = game.get_player(e.player_index)
  local t = el.tags
  if t.lp_dbg then
    local pr = prefs(p)
    if t.lp_dbg == "close" then panel.toggle(p) return true end
    local b = pr.camp and storage.bases[pr.camp]
    if t.lp_dbg == "go_camp" then if standing(b) then go(p, b.origin, b.surface) end
    elseif t.lp_dbg == "go_op" then
      if standing(b) and b.op then go(p, op_pos(b), b.surface) else p.print("no operation out") end -- notice-ok: the debug panel's reply
    elseif t.lp_dbg == "go_farm" then
      local fm = pr.farm and storage.farms and storage.farms.list[pr.farm]
      local w = pr.wave and storage.herd and storage.herd.waves[pr.wave]
      if fm then go(p, fm.pos, fm.surface) elseif w then go(p, first_pos(w.members) or w.center, w.surface) end
    elseif t.lp_dbg == "snapshot" then snapshot(p)
    else return false end
    return true
  end
  if t.lp_dev and dev then
    local args = {}
    for w in string.gmatch(t.lp_dev, "%S+") do args[#args + 1] = w end
    local pr = prefs(p)
    -- The camp chosen, as /lp's last argument (not for land, which takes a distance, nor the ones about Synthexis).
    if t.camp and pr.camp and args[1] ~= "land" and args[1] ~= "spread" and args[1] ~= "ranks" and args[1] ~= "burst"
      and args[1] ~= "incidents" and args[1] ~= "trace" then
      args[#args + 1] = tostring(pr.camp)
    end
    dev.run(p, args)
    fill(p)
    return true
  end
  return false
end

function panel.on_selection(e)
  local el = e.element
  if not (el and el.valid and el.tags and el.tags.lp_dbg) then return end
  local p = game.get_player(e.player_index)
  local pr = prefs(p)
  if el.tags.lp_dbg == "camp" then
    pr.camp = pr.camp_ids and pr.camp_ids[el.selected_index]
    panel.watch()
  elseif el.tags.lp_dbg == "farm" then
    local x = pr.farm_ids and pr.farm_ids[el.selected_index] or {}
    pr.farm, pr.wave = x.farm, x.wave
  elseif el.tags.lp_dbg == "density" then
    pr.density = el.selected_index
  end
  fill(p)
end

function panel.on_tab(e)
  if e.element and e.element.valid and e.element.name == "tabs" then fill(game.get_player(e.player_index)) end
end

-- Its key: for admins with its setting on.
function panel.on_key(e)
  local p = game.get_player(e.player_index)
  if not (p and p.admin) then return end
  if not settings.get_player_settings(p)["lp-debug-panel"].value then return end
  panel.toggle(p)
end

-- Every second, each open panel.
function panel.tick(tick)
  if tick % 60 ~= 23 then return end
  for _, p in pairs(game.connected_players) do if p.gui.screen[NAME] then fill(p) end end
end

function panel.install(d) dev = d end

-- (Tests: a camp's card and its last decisions, a farm's card, without a player; remote panel_lines.)
function panel.lines(id, density)
  local b = storage.bases[id]
  if not standing(b) then return nil end
  return {card = card(b), stream = stream(b.log or {}, density or 3, 40), op_pos = op_pos(b),
    farms = (function() local o = {} for _, f in ipairs(farms()) do o[#o + 1] = farm_card(f) end return o end)(),
    waves = (function() local o = {} for _, w in ipairs(waves()) do o[#o + 1] = wave_line(w) end return o end)()}
end

return panel
