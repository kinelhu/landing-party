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

script.on_event(defines.events.on_tick, function(e)
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
