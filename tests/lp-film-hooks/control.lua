-- Landing Party's plugin for the film helper (~/Dev/factorio-film, its README's "Plugins"): what the helper asked of
-- Landing Party itself before it was split out (tests/lp-film, to 2026-11-05), as points, events and actions.
-- The helper finds this interface by its film_tick, gives it the film's params (film_init, each session), each gallery
-- building (film_built), and calls film_tick every tick, taking the points and events it returns.
--
-- Its params (a film's params.lua, unchanged):
--   base = id | "siege"   the settlement whose siege it follows ("siege": whichever has one out, found every 60 ticks).
--                         Events "phase:<name>", "paint", "falling"; points "hold", "jump", "site", "escort", and
--                         "center" = "strike" (the strike's centre, or the last dev call's aim).
--   waves = true          Synthexis's first live wave: point "wave" (its centre, eased), "breach"; events "wave:<stage>".
--   bursts = true         event "burst:first" the tick the film's first burster winds up; point "burst" where it stands.
--   fight = true          point "fight": the eased middle of the units near it with an enemy in reach, from each dev
--                         call's aim. fight_log = true (a rehearsal) writes it to script-output/lp-film-fight.txt.
--   path = {{t0 =, every =, xy = {x, y, ...}}}   point "cam": a smoothed camera path (scripts/film_smooth.py).
--   dev = {{tick =, args = {...}, at = {x, y} | {toward = tiles} | {wall = true}}}   /lp tools at a tick.
--   fx = {{tick =, kind = "wave" | "rise", at = {x, y}, radius =}}   the dome's looks on the gallery's first building.
--   ripples = {{tick =, pos = {x, y}, name = "lp-dome-ripple"}}      the dome's catch played there.
--   director = {{at =, cmd =, arg =}}   the director's hand (remote director_cmd) `at` ticks after the film's first;
--                         cmd "panel" opens its panel for player 1 (remote debug_director_panel). With it, every 30 ticks:
--                         points "dstrike" (the latest strike force's landing spot, then where it landed), "dforce"
--                         (the median of its live units' positions, "dforcemean" their mean; "dstrike<n>", "dforce<n>" each force's), "salvage" (the latest wreck), "mast" (a mast standing);
--                         events "strike<n>:sent", "strike<n>:landed", "strike<n>:broken", "salvage", "mast".
--   trace = true          keeps the settlements' trace labels (off otherwise: a lander's "depot | parts 28 | ..." was in
--                         the trailer's rough cut, 2026-11-04).
local P = {}

-- A force's centre: the median of its live units' x and y (a straggler or a death no longer drags it; the walk-home loop's
-- camera jumped with the mean, 2026-11-16), and the mean as it was ("dforcemean<n>", for a still to be refilmed as before).
local function centres(units)
  local xs, ys, sx, sy = {}, {}, 0, 0
  for _, u in ipairs(units or {}) do
    if u.valid then
      xs[#xs + 1], ys[#ys + 1] = u.position.x, u.position.y
      sx, sy = sx + u.position.x, sy + u.position.y
    end
  end
  local n = #xs
  if n == 0 then return nil end
  table.sort(xs); table.sort(ys)
  local function mid(t) return n % 2 == 1 and t[(n + 1) / 2] or (t[n / 2] + t[n / 2 + 1]) / 2 end
  return {mid(xs), mid(ys)}, {sx / n, sy / n}
end

local function lp(fn, ...) return remote.call("landing-party", fn, ...) end

-- (The settlement a dev call aims from: P.base, or the siege's once found. base_id here was a global, always nil, and a
-- raid forced from Grubstake's camp aimed at the wall nearest Kessler-Hayashi's, 2026-11-04.)
local function dev_base() return type(P.base) == "number" and P.base or storage.base_id or 1 end

local function tick(t)
  local S = storage
  S.points = S.points or {}
  local events = {}
  -- (On the film's first tick, not each session's: a reel's reload keeps what the first set.)
  if not S.started then
    S.started = true
    if not P.trace then lp("set_trace", false) end
  end
  for _, f in ipairs(P.fx or {}) do
    if t == f.tick and S.built and S.built[1] and S.built[1].valid then
      lp("debug_dome_fx", f.kind, S.built[1], f.radius, f.at)
      log("lp-film-hooks: dome fx " .. f.kind .. " at " .. t)
    end
  end
  -- toward: that many tiles from settlement P.base towards spawn (the orbital scenario's wall stands 120 from its camp);
  -- wall: the player's wall nearest it (its siege's wall in the orbital scenario).
  for _, d in ipairs(P.dev or {}) do
    if t == d.tick then
      local at = d.at
      if at.wall then
        local o = lp("stats", dev_base()).origin
        local best, bd
        for _, w in ipairs(game.surfaces[1].find_entities_filtered{type = "wall", force = "player"}) do
          local dd = (w.position.x - o.x) ^ 2 + (w.position.y - o.y) ^ 2
          if not bd or dd < bd then best, bd = w, dd end
        end
        at = best and {best.position.x, best.position.y} or {o.x, o.y}
        log("lp-film-hooks: aimed at the wall at " .. at[1] .. "," .. at[2])
      elseif at.toward then
        local o = lp("stats", dev_base()).origin
        local len = math.max(1, math.sqrt(o.x * o.x + o.y * o.y))
        at = {o.x - o.x / len * at.toward, o.y - o.y / len * at.toward}
      end
      S.center = {at[1], at[2]}
      S.points.fight = {at[1], at[2]}
      lp("dev", d.args, at)
      log("lp-film-hooks: /lp " .. table.concat(d.args, " ") .. " at " .. at[1] .. "," .. at[2] .. ", tick " .. t)
    end
  end
  if P.director then
    S.t0 = S.t0 or t
    for _, d in ipairs(P.director) do
      if t == S.t0 + d.at then
        local said
        if d.cmd == "panel" then said = lp("debug_director_panel", 1)
        else said = lp("director_cmd", d.cmd, d.arg) end
        log("lp-film-hooks: director " .. d.cmd .. " " .. serpent.line(d.arg) .. ": " .. tostring(said) .. ", tick " .. t)
      end
    end
    if t % 30 == 0 then
      local dr = lp("director") or {}
      local k = dr.strikes and dr.strike_n and dr.strikes[dr.strike_n]
      S.devents = S.devents or {}
      local function ev(name) if not S.devents[name] then S.devents[name] = t end end
      for key, kk in pairs(dr.strikes or {}) do
        if kk.at then ev("strike" .. key .. ":sent") end
        if kk.landed_at then ev("strike" .. key .. ":landed") end
        if kk.broken then ev("strike" .. key .. ":broken") end
        -- (Each its own too: "dstrike<n>", "dforce<n>".)
        local p = kk.landed_at or kk.land
        if p then S.points["dstrike" .. key] = {p[1], p[2]} end
        local med, mean = centres(kk.units)
        if med then S.points["dforce" .. key], S.points["dforcemean" .. key] = med, mean end
      end
      if k then
        local p = k.landed_at or k.land
        if p then S.points.dstrike = {p[1], p[2]} end
        local med, mean = centres(k.units)
        if med then S.points.dforce, S.points.dforcemean = med, mean end
      end
      local w = dr.salvage and dr.salvage[#dr.salvage]
      if w and w.wreck and w.wreck.valid then S.points.salvage = {w.wreck.position.x, w.wreck.position.y}; ev("salvage") end
      for _, m in pairs(dr.masts or {}) do
        if m.mast and m.mast.valid then S.points.mast = {m.mast.position.x, m.mast.position.y}; ev("mast") end
      end
    end
    for name, at in pairs(S.devents or {}) do events[name] = at end
  end
  for _, r in ipairs(P.ripples or {}) do
    if t == r.tick then game.surfaces[1].create_entity{name = r.name or "lp-dome-ripple", position = r.pos} end
  end
  -- The fight (P.fight; the user, 2026-11-08, of the staged scenes: "the camera is not centered on the fight", "missing
  -- almost all of the action"; framed by guess, each shot had missed): the middle of the units within 40 of it that have
  -- an enemy within 20 (of every unit within 20 while none has), eased each 6 ticks; set to each dev call's aim when it is
  -- made. A move with `pos = "fight", track = true` follows it.
  if P.fight and S.points.fight and t % 6 == 0 then
    local s, here = game.surfaces[1], S.points.fight
    local ex, ey, en, ax, ay, an = 0, 0, 0, 0, 0, 0
    -- (Every unit within 40 while none fought drew it to the next stage's idle troops, 60 tiles off, in the rehearsal: those
    -- within 20 only.)
    for _, u in ipairs(s.find_entities_filtered{position = here, radius = 40, type = "unit"}) do
      local x, y = u.position.x, u.position.y
      if (x - here[1]) ^ 2 + (y - here[2]) ^ 2 < 400 then ax, ay, an = ax + x, ay + y, an + 1 end
      if s.find_nearest_enemy{position = u.position, max_distance = 20, force = u.force} then ex, ey, en = ex + x, ey + y, en + 1 end
    end
    local g = en > 0 and {ex / en, ey / en} or an > 0 and {ax / an, ay / an}
    if g then S.points.fight = {here[1] + (g[1] - here[1]) * 0.12, here[2] + (g[2] - here[2]) * 0.12} end
    -- (P.fight_log, in a rehearsal: the point each 6 ticks to script-output/lp-film-fight.txt, for scripts/film_smooth.py.)
    if P.fight_log then
      S.fight_lines = S.fight_lines or {}
      S.fight_lines[#S.fight_lines + 1] = string.format("%d %.3f %.3f", t, S.points.fight[1], S.points.fight[2])
      if #S.fight_lines >= 50 then
        helpers.write_file("lp-film-fight.txt", table.concat(S.fight_lines, "\n") .. "\n", S.fight_written)
        S.fight_lines, S.fight_written = {}, true
      end
    end
  end
  -- The camera's path (P.path, written by scripts/film_smooth.py from a rehearsal's fight points, smoothed: the fight
  -- point itself moved in steps and jumped as units joined the fight, and a camera on it shook, the user, fourth takes:
  -- "The camera panning is super abrupt and not smooth at all"): point "cam", read between its samples each tick.
  for _, seg in ipairs(P.path or {}) do
    if t >= seg.t0 and t <= seg.t0 + (#seg.xy / 2 - 1) * seg.every then
      local f = (t - seg.t0) / seg.every
      local i = math.floor(f)
      local a = f - i
      local j = math.min(i + 1, #seg.xy / 2 - 1)
      S.points.cam = {seg.xy[2 * i + 1] + (seg.xy[2 * j + 1] - seg.xy[2 * i + 1]) * a,
        seg.xy[2 * i + 2] + (seg.xy[2 * j + 2] - seg.xy[2 * i + 2]) * a}
    end
  end
  -- The wave, eased each 2 ticks so a tracking move glides rather than jumps.
  if P.waves and t % 2 == 0 then
    for _, w in ipairs(lp("herd_state").waves or {}) do
      if w.group and w.stage ~= "done" then
        local p, g = S.points.wave, w.group
        S.points.wave = p and {p[1] + (g[1] - p[1]) * 0.08, p[2] + (g[2] - p[2]) * 0.08} or {g[1], g[2]}
        if w.breach then S.points.breach = w.breach end
        events["wave:" .. w.stage] = t
        break
      end
    end
  end
  -- (Its wind-up is half a second: read each tick.)
  if P.bursts then
    local fx = lp("burstfx")
    S.bursts_before = S.bursts_before or fx.windups
    if fx.windups > S.bursts_before and not S.burst_seen and fx.last then
      S.burst_seen = t
      S.points.burst = {fx.last.x, fx.last.y}
      log(string.format("lp-film-hooks: burst:first at %d (%s at %.0f,%.0f)", t, fx.last.kind, fx.last.x, fx.last.y))
    end
    if S.burst_seen then events["burst:first"] = S.burst_seen end
  end
  -- (A scenario's camp is not always id 1.)
  if P.base == "siege" and t % 60 == 0 and not S.base_id then
    for _, id in ipairs(lp("bases") or {}) do
      local st = lp("stats", id)
      if st and st.ops and st.ops.op_phase then S.base_id = id; log("lp-film-hooks: the siege is base " .. id) end
    end
  end
  local base_id = P.base == "siege" and S.base_id or (P.base ~= "siege" and P.base or nil)
  if t % 10 == 0 and base_id then
    local st = lp("stats", base_id)
    local o = st and st.ops or {}
    if o.op_phase then events["phase:" .. o.op_phase] = t end
    for _, k in ipairs({"hold", "jump", "site"}) do
      local v = o["op_" .. k]
      if v then S.points[k] = {v.x or v[1], v.y or v[2]} end
    end
    -- (A hold point read empty, the escort elsewhere: the centre of its units.)
    if o.op_members and #o.op_members > 0 then
      local sx, sy = 0, 0
      for _, m in ipairs(o.op_members) do sx, sy = sx + m[1], sy + m[2] end
      S.points.escort = {sx / #o.op_members, sy / #o.op_members}
    end
    if o.strike_paint then events.paint = o.strike_paint end
    if o.strike_falling then events.falling = o.strike_falling end
    if o.strike_center and not S.center then S.center = {o.strike_center[1], o.strike_center[2]} end
  end
  if S.center then S.points.center, S.points.strike = S.center, S.center end
  return {points = S.points, events = events}
end

remote.add_interface("lp-film-hooks", {
  film_init = function(params) P = params end,
  film_built = function(ent)
    storage.built = storage.built or {}
    storage.built[#storage.built + 1] = ent
    lp("debug_light", ent)
  end,
  film_tick = tick,
})
