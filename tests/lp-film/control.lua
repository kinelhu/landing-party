-- The film helper (docs/trailer/storyboard.md): screenshots on a schedule, written by scripts/film.sh to params.lua.
-- A still: {name =, pos = {x, y}, zoom =, daytime =, and its time: tick = (absolute), or after = "paint" | "falling" and
-- dt = ticks after that event of settlement P.base's siege (read from Landing Party's stats, every 10 ticks till seen)}.
-- The game runs at P.speed until P.fast_until, then at 1. When every still is taken it writes done.txt (film.sh waits).
local P = require("params")

local function shot(s)
  game.take_screenshot{surface = game.surfaces[1], position = s.pos, resolution = P.resolution or {1920, 1080},
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
  s.destroy_decoratives{area = {{x0, y0}, {x1, y1}}}
  for _, b in ipairs(P.build) do
    if not game.forces[b.force] then game.create_force(b.force) end
  end
  for _, f in pairs(game.forces) do for _, g in pairs(game.forces) do
    if f ~= g then f.set_cease_fire(g, true); f.set_friend(g, true) end
  end end
  storage.built = {}
  for _, b in ipairs(P.build) do
    local ok, ent = pcall(s.create_entity, {name = b.name, position = b.pos, force = b.force, direction = b.dir,
      raise_built = false})
    if ok and ent then
      storage.built[#storage.built + 1] = ent
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

script.on_event(defines.events.on_tick, function(e)
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
  for _, r in ipairs(P.ripples or {}) do
    if e.tick == r.tick then game.surfaces[1].create_entity{name = r.name or "lp-dome-ripple", position = r.pos} end
  end
  storage.seen = storage.seen or {}
  storage.taken = storage.taken or 0
  if P.fast_until then
    local want = e.tick < P.fast_until and (P.speed or 8) or 1
    if game.speed ~= want then game.speed = want end
  end
  if e.tick % 10 == 0 and P.base and not (storage.seen.paint and storage.seen.falling) then
    local st = remote.call("landing-party", "stats", P.base)
    local o = st and st.ops or {}
    storage.seen.paint = storage.seen.paint or o.strike_paint
    storage.seen.falling = storage.seen.falling or o.strike_falling
  end
  for i, s in ipairs(P.shots) do
    local at = s.tick or (storage.seen[s.after] and storage.seen[s.after] + (s.dt or 0))
    if at and e.tick == at then
      shot(s); storage.taken = storage.taken + 1
      if storage.taken == #P.shots then
        helpers.write_file("lp-film/" .. P.name .. "/done.txt", "done\n")
      end
    end
  end
end)
