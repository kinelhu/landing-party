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
--   dev = {{tick =, args = {...}, at = {x, y} | {toward = tiles} | {wall = true}}}   /lp tools at a tick.
--   fx = {{tick =, kind = "wave" | "rise", at = {x, y}, radius =}}   the dome's looks on the gallery's first building.
--   ripples = {{tick =, pos = {x, y}, name = "lp-dome-ripple"}}      the dome's catch played there.
--   trace = true          keeps the settlements' trace labels (off otherwise: a lander's "depot | parts 28 | ..." was in
--                         the trailer's rough cut, 2026-11-04).
local P = {}

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
      lp("dev", d.args, at)
      log("lp-film-hooks: /lp " .. table.concat(d.args, " ") .. " at " .. at[1] .. "," .. at[2] .. ", tick " .. t)
    end
  end
  for _, r in ipairs(P.ripples or {}) do
    if t == r.tick then game.surfaces[1].create_entity{name = r.name or "lp-dome-ripple", position = r.pos} end
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
