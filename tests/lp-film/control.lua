-- The film helper (docs/trailer/storyboard.md): screenshots on a schedule, written by scripts/film.sh to params.lua.
-- A still: {name =, pos = {x, y}, zoom =, daytime =, and its time: tick = (absolute), or after = "paint" | "falling" and
-- dt = ticks after that event of settlement P.base's siege (read from Landing Party's stats, every 10 ticks till seen)}.
-- The game runs at P.speed until P.fast_until, then at 1. When every still is taken it writes done.txt (film.sh waits).
local P = require("params")
-- Camera moves (docs/trailer/storyboard.md section 2): P.moves = {{name =, tick = | after =, dt =, frames =, every = 2,
-- from = {pos = {x, y} | "escort" | "strike" ..., zoom =, daytime =}, to = {...}}}, each expanded into stills named
-- name-00001 ..., position, zoom and daytime eased between from and to (smoothstep, 3t^2 - 2t^3). A named point ("escort",
-- "strike") is read when the move's first frame is taken and held (freeze); to.off moves from it.
P.shots = P.shots or {}
for _, m in ipairs(P.moves or {}) do
  local n, every = m.frames, m.every or 2
  for i = 0, n - 1 do
    local t = n > 1 and i / (n - 1) or 0
    local e = t * t * (3 - 2 * t)
    local f, g = m.from, m.to or m.from
    local function lerp(a, b) return a + (b - a) * e end
    local shot = {name = string.format("%s-%05d", m.name, i + 1), zoom = lerp(f.zoom, g.zoom or f.zoom),
      daytime = lerp(f.daytime or 0.1, g.daytime or f.daytime or 0.1), hide_clouds = (f.daytime or 0.1) > 0.3}
    if type(f.pos) == "table" and type(g.pos or f.pos) == "table" then
      local gp = g.pos or f.pos
      shot.pos = {lerp(f.pos[1], gp[1]), lerp(f.pos[2], gp[2])}
    else
      shot.pos, shot.freeze = f.pos, m.name
      local o = g.off or {0, 0}
      shot.off = {o[1] * e, o[2] * e}
    end
    if m.at_load then shot.at_load = 120 + i * every
    elseif m.tick then shot.tick = m.tick + i * every else shot.after, shot.dt = m.after, (m.dt or 0) + i * every end
    P.shots[#P.shots + 1] = shot
  end
end
-- This session's first tick (a local: it starts again with each load). With P.reel set and stills left that many ticks
-- into a session, it saves, names the save in reel.txt, and film.sh opens it again in a fresh session. (Written for a stop
-- that was freeplay's intro dialog, no_intro below; kept for films longer than one session should run.)
local session_from, reeled

local function shot(s)
  local pos = s.pos
  -- (s.freeze = a key: the point is read once, at the first still with that key, and kept: a clip's camera stands still.)
  storage.frozen = storage.frozen or {}
  if s.freeze and storage.frozen[s.freeze] then
    local f = storage.frozen[s.freeze]
    pos = {f[1] + (s.off and s.off[1] or 0), f[2] + (s.off and s.off[2] or 0)}
  end
  if pos == "hold" or pos == "jump" or pos == "site" or pos == "escort" then
    local c = (storage.points or {})[pos] or storage.center or {0, 0}
    pos = {c[1] + (s.off and s.off[1] or 0), c[2] + (s.off and s.off[2] or 0)}
  elseif pos == "strike" then
    local c = storage.center or {0, 0}
    pos = {c[1] + (s.off and s.off[1] or 0), c[2] + (s.off and s.off[2] or 0)}
  end
  if s.freeze and not storage.frozen[s.freeze] then
    storage.frozen[s.freeze] = {pos[1] - (s.off and s.off[1] or 0), pos[2] - (s.off and s.off[2] or 0)}
  end
  game.take_screenshot{surface = game.surfaces[1], position = pos, resolution = P.resolution or {1920, 1080},
    zoom = s.zoom or 0.5, path = "lp-film/" .. P.name .. "/" .. s.name .. ".png", show_gui = false,
    show_entity_info = false, anti_alias = P.anti_alias ~= false, daytime = s.daytime, force_render = true,
    hide_health_bars = true, hide_clouds = s.hide_clouds, hide_fog = true}
end

-- A gallery (P.build): on the first tick a pad of concrete (P.pad = {x0, y0, x1, y1}) and each building on it
-- ({name =, force =, pos = {x, y}, dir =}), every force at peace with every other, kept powered by script (their buffers
-- filled each tick: no poles in frame). P.ripples = {{tick =, pos =}}: the dome's catch played there.
local function build()
  local s = game.surfaces[1]
  local x0, y0, x1, y1 = table.unpack(P.pad)
  s.request_to_generate_chunks({(x0 + x1) / 2, (y0 + y1) / 2}, math.ceil(math.max(x1 - x0, y1 - y0) / 64) + 1)
  s.force_generate_chunk_requests()
  for _, e in ipairs(s.find_entities_filtered{area = {{x0 - 8, y0 - 8}, {x1 + 8, y1 + 8}}}) do
    if e.type ~= "character" then e.destroy() end
  end
  local tiles = {}
  for x = x0 - 8, x1 + 8 do for y = y0 - 8, y1 + 8 do
    local inner = x >= x0 and x <= x1 and y >= y0 and y <= y1
    tiles[#tiles + 1] = {name = inner and (P.tile or "refined-concrete") or "grass-1", position = {x, y}}
  end end
  s.set_tiles(tiles)
  -- A building's own ground (b.ground, b.ground_r tiles round it): the same building on concrete, grass, sand and dirt.
  for _, b in ipairs(P.build) do
    if b.ground then
      local r, g = b.ground_r or 6, {}
      for x = b.pos[1] - r, b.pos[1] + r do for y = b.pos[2] - r, b.pos[2] + r do
        g[#g + 1] = {name = b.ground, position = {x, y}}
      end end
      s.set_tiles(g)
    end
  end
  s.destroy_decoratives{area = {{x0, y0}, {x1, y1}}}
  for _, b in ipairs(P.build) do
    if not game.forces[b.force] then game.create_force(b.force) end
  end
  for _, f in pairs(game.forces) do for _, g in pairs(game.forces) do
    if f ~= g then f.set_cease_fire(g, true); f.set_friend(g, true) end
  end end
  storage.built = {}
  for _, b in ipairs(P.build) do
    -- (The player's built as a player's are, raised: the muster point's light is drawn when it is built.)
    local ok, ent = pcall(s.create_entity, {name = b.name, position = b.pos, force = b.force, direction = b.dir,
      raise_built = b.force == "player"})
    if ok and ent then
      storage.built[#storage.built + 1] = ent
      remote.call("landing-party", "debug_light", ent)
      -- A machine at work (its working animation): its recipe's ingredients for many crafts, its output emptied.
      if ent.type == "assembling-machine" then
        local r = ent.get_recipe()
        if not r and b.recipe then ent.set_recipe(b.recipe); r = ent.get_recipe() end
        if r then
          ent.force.recipes[r.name].enabled = true    -- (recipe_not_researched on a fresh map: it stood idle)
          for _, ing in ipairs(r.ingredients) do
            if ing.type == "item" then ent.insert{name = ing.name, count = ing.amount * 50} end
          end
        end
        storage.machines = storage.machines or {}
        storage.machines[#storage.machines + 1] = ent
      end
      -- (A unit stays where it was put: the howitzer truck drove out of its frame.)
      if ent.type == "unit" and ent.commandable then
        ent.commandable.set_command{type = defines.command.stop, ticks_to_wait = 1000000, distraction = defines.distraction.none}
      end
    else log("lp-film: could not place " .. b.name .. ": " .. tostring(ent)) end
  end
  for _, p in pairs(game.players) do if p.character then p.character.teleport({x1 + 40, y1 + 40}) end end
  -- (The dome's ring on the ground, as dome.lua draws it, round the first building.)
  if P.ring and storage.built[1] then
    rendering.draw_circle{color = {r = 0.3, g = 0.75, b = 1, a = 0.5}, radius = P.ring, width = 3, filled = false,
      target = storage.built[1], surface = s, draw_on_ground = true}
  end
end

-- No freeplay intro for the player a windowed load makes (the user, 2026-11-04: "Isn't it just stopping for the tab
-- press?"): its crash-site cutscene, then its welcome message as a dialog, which pauses a single-player game till Tab.
-- Every film stopped about 720 ticks into a fresh session, at one tick a save.
local function no_intro()
  if remote.interfaces.freeplay then
    if remote.interfaces.freeplay.set_skip_intro then remote.call("freeplay", "set_skip_intro", true) end
    if remote.interfaces.freeplay.set_disable_crashsite then remote.call("freeplay", "set_disable_crashsite", true) end
  end
end
script.on_init(no_intro)
script.on_configuration_changed(no_intro)

script.on_event(defines.events.on_tick, function(e)
  -- (P.min_brightness: the night still reads, the storyboard's 0.3 against the game's 0.15.)
  if P.min_brightness and game.surfaces[1].min_brightness ~= P.min_brightness then game.surfaces[1].min_brightness = P.min_brightness end
  if P.build and not storage.built then build() end
  for _, ent in ipairs(storage.built or {}) do
    if ent.valid and ent.electric_buffer_size and ent.electric_buffer_size > 0 then ent.energy = ent.electric_buffer_size end
  end
  -- P.fx = {{tick =, kind = "wave" | "rise", at = {x, y}, radius =}}: Landing Party's own dome looks on the first building.
  for _, f in ipairs(P.fx or {}) do
    if e.tick == f.tick and storage.built and storage.built[1] and storage.built[1].valid then
      remote.call("landing-party", "debug_dome_fx", f.kind, storage.built[1], f.radius, f.at)
    end
  end
  for _, m in ipairs(storage.machines or {}) do
    if m.valid then
      m.get_output_inventory().clear()
      if e.tick % 120 == 0 then
        local r = m.get_recipe()
        local sname = tostring(m.status)
        for k, v in pairs(defines.entity_status) do if v == m.status then sname = k end end
        log(string.format("lp-film: %s status %s recipe %s energy %.0f/%.0f input %s", m.name, sname,
          r and r.name or "none", m.energy, m.electric_buffer_size or 0, serpent.line(m.get_inventory(defines.inventory.crafter_input).get_contents())))
      end
    end
  end
  -- (The settlement a dev call aims from: P.base, or the siege's once found. base_id here was the global, always nil, and
  -- a raid forced from Grubstake's camp aimed at the wall nearest Kessler-Hayashi's, 2026-11-04.)
  local function dev_base() return type(P.base) == "number" and P.base or storage.base_id or 1 end
  -- P.dev = {{tick =, args = {"strike", "1"}, at = {x, y} | {toward = tiles}}}: Landing Party's /lp tools at a tick; toward:
  -- that many tiles from settlement P.base towards spawn (the orbital scenario's wall stands 120 from its camp).
  for _, d in ipairs(P.dev or {}) do
    if e.tick == d.tick then
      local at = d.at
      if at.wall then
        -- The player's wall nearest settlement P.base (its siege's wall in the orbital scenario).
        local o = remote.call("landing-party", "stats", dev_base()).origin
        local best, bd
        for _, w in ipairs(game.surfaces[1].find_entities_filtered{type = "wall", force = "player"}) do
          local dd = (w.position.x - o.x) ^ 2 + (w.position.y - o.y) ^ 2
          if not bd or dd < bd then best, bd = w, dd end
        end
        at = best and {best.position.x, best.position.y} or {o.x, o.y}
        log("lp-film: aimed at the wall at " .. at[1] .. "," .. at[2])
      elseif at.toward then
        local o = remote.call("landing-party", "stats", dev_base()).origin
        local len = math.max(1, math.sqrt(o.x * o.x + o.y * o.y))
        at = {o.x - o.x / len * at.toward, o.y - o.y / len * at.toward}
      end
      storage.center = {at[1], at[2]}
      remote.call("landing-party", "dev", d.args, at)
    end
  end
  for _, r in ipairs(P.ripples or {}) do
    if e.tick == r.tick then game.surfaces[1].create_entity{name = r.name or "lp-dome-ripple", position = r.pos} end
  end
  storage.seen = storage.seen or {}
  storage.taken = storage.taken or 0
  session_from = session_from or e.tick
  -- (A still timed before the save's own tick never comes, and the film waited out its 30 minutes on 47 of them: a
  -- save's tick is when it was written, not minute x 3600, 2026-11-04. Stop at once, naming them.)
  if not storage.first_tick then
    -- (Settlement labels show while tracing, and a visit traces: a lander's "depot | parts 28 | ..." was in the trailer's
    -- rough cut, 2026-11-04. P.trace = true keeps it, for scouting runs that read decisions.txt.)
    if not P.trace then remote.call("landing-party", "set_trace", false) end
    local early = 0
    for _, s in ipairs(P.shots) do if s.tick and s.tick < e.tick then early = early + 1 end end
    if early > 0 then error("lp-film: " .. early .. " stills timed before this save's tick " .. e.tick) end
  end
  storage.first_tick = storage.first_tick or e.tick
  -- P.each = function(tick): a film's own probe, every 60 ticks (scouting what stands where before framing a shot).
  if P.each and e.tick % 60 == 0 then P.each(e.tick) end
  -- P.stop_after: ticks from the film's first; then it ends with what it took (shots on events that never came are left).
  if P.stop_after and e.tick - storage.first_tick >= P.stop_after and not storage.stopped then
    storage.stopped = true
    log("lp-film: stopped after " .. P.stop_after .. " ticks, " .. storage.taken .. " of " .. #P.shots .. " taken")
    helpers.write_file("lp-film/" .. P.name .. "/done.txt", "done\n")
  end
  if P.reel and not reeled and storage.taken < #P.shots and e.tick - session_from >= P.reel then
    reeled = true
    storage.reels = (storage.reels or 0) + 1
    local name = "film-reel-" .. storage.reels
    game.auto_save(name)
    helpers.write_file("lp-film/" .. P.name .. "/reel.txt", "_autosave-" .. name)
    log("lp-film: reel " .. storage.reels .. " saved at tick " .. e.tick)
  end
  -- (Its clock in the log every 10 s: a film that stops taking stills says whether time still runs.)
  if e.tick % (P.log_every or 600) == 0 then
    -- (And its players: what they are and how they stand, the clock having stopped at one tick in a save, every session.)
    local who = {}
    for _, p in pairs(game.players) do
      local c = p.character
      who[#who + 1] = string.format("%s ctl %s char %s hp %s at %.0f,%.0f", p.name, tostring(p.controller_type),
        tostring(c and c.valid), c and c.valid and string.format("%.0f", c.health) or "-", p.position.x, p.position.y)
    end
    log(string.format("lp-film: tick %d, taken %d of %d, seen %s; %s", e.tick, storage.taken, #P.shots,
      serpent.line(storage.seen), table.concat(who, "; ")))
  end
  if P.fast_until then
    -- (Or till the event its stills wait for: P.fast_until = "paint" runs fast until the strike is painted.)
    local fast = type(P.fast_until) == "string" and not storage.seen[P.fast_until]
      or (type(P.fast_until) == "number" and e.tick < P.fast_until)
    local want = fast and (P.speed or 8) or 1
    if game.speed ~= want then game.speed = want end
  end
  -- P.base = "siege": the settlement with a siege out, whichever it is (a scenario's camp is not always id 1).
  if P.base == "siege" and e.tick % 60 == 0 and not storage.base_id then
    for _, id in ipairs(remote.call("landing-party", "bases") or {}) do
      local st = remote.call("landing-party", "stats", id)
      if st and st.ops and st.ops.op_phase then storage.base_id = id; log("lp-film: the siege is base " .. id) end
    end
  end
  local base_id = P.base == "siege" and storage.base_id or (P.base ~= "siege" and P.base or nil)
  if e.tick % 10 == 0 and base_id then
    local st = remote.call("landing-party", "stats", base_id)
    local o = st and st.ops or {}
    -- Its siege's phases as events ("phase:deploy" ...), and the points its stills aim at (pos = "hold" | "jump" | "site").
    if o.op_phase and not storage.seen["phase:" .. o.op_phase] then storage.seen["phase:" .. o.op_phase] = e.tick end
    storage.points = storage.points or {}
    for _, k in ipairs({"hold", "jump", "site"}) do
      local v = o["op_" .. k]
      if v then storage.points[k] = {v.x or v[1], v.y or v[2]} end
    end
    -- Where its escort stands (pos = "escort"): the centre of its units (a hold point read empty, the escort elsewhere).
    if o.op_members and #o.op_members > 0 then
      local sx, sy = 0, 0
      for _, m in ipairs(o.op_members) do sx, sy = sx + m[1], sy + m[2] end
      storage.points.escort = {sx / #o.op_members, sy / #o.op_members}
    end
    storage.seen.paint = storage.seen.paint or o.strike_paint
    storage.seen.falling = storage.seen.falling or o.strike_falling
    -- (Its centre, for stills aimed at the strike: pos = "strike", with off = {dx, dy}.)
    if o.strike_center and not storage.center then storage.center = {o.strike_center[1], o.strike_center[2]} end
  end
  -- (s.at_load: ticks after the film's first, for a save whose tick is not known beforehand.)
  storage.first_tick = storage.first_tick or e.tick
  for i, s in ipairs(P.shots) do
    local at = (s.at_load and storage.first_tick + s.at_load) or s.tick or (storage.seen[s.after] and storage.seen[s.after] + (s.dt or 0))
    if at and e.tick == at then
      shot(s); storage.taken = storage.taken + 1
      if storage.taken == #P.shots then
        helpers.write_file("lp-film/" .. P.name .. "/done.txt", "done\n")
      end
    end
  end
end)
