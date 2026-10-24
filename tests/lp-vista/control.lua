-- Faction vistas for the field guide (scripts/vistas.sh runs it on a copy of the all-factions save, scripts/showcase.sh
-- LP_MIX=all): each corporation's camp wide and close, Synthexis's culture wide, at night and at its clinic, the player's base.
local lp = function(fn, ...) return remote.call("landing-party", fn, ...) end
local S = {}
local function note(t) helpers.write_file("lp-vista/notes.txt", t .. "\n", true) end
local function shot(name, pos, zoom, night, res)
  game.take_screenshot{surface = game.surfaces[1], position = pos, resolution = res or {1600, 1000}, zoom = zoom,
    daytime = night and 0.5 or 0, path = "lp-vista/" .. name .. ".png", show_entity_info = false, anti_alias = true}
  note(string.format("%s at %.0f,%.0f zoom %.2f%s", name, pos[1] or pos.x, pos[2] or pos.y, zoom, night and " night" or ""))
end
script.on_init(function() S.t0 = game.tick end)
script.on_event(defines.events.on_tick, function(e)
  local t = e.tick - (S.t0 or e.tick)
  if t == 10 then
    lp("set_trace", false)
    -- The developer's readout over each lander (hidden in games now; this save was made with tracing on).
    for _, o in pairs(rendering.get_all_objects("landing-party")) do
      if o.valid and o.type == "text" and tostring(o.text):find("| parts", 1, true) then o.visible = false end
    end
  end
  if t == 60 then
    game.speed = 1
    local plan = {}
    for _, id in ipairs(lp("bases")) do
      local st = lp("stats", id)
      if st and not st.fallen and st.lander then
        local o = st.origin
        plan[#plan + 1] = {st.corp .. "-wide", {o.x, o.y}, 0.35}
        plan[#plan + 1] = {st.corp .. "-close", {o.x, o.y}, 0.9}
      end
    end
    local f = lp("farm_state").farms[1]
    if f then
      plan[#plan + 1] = {"synthexis-wide", {f.pos.x, f.pos.y}, 0.4}
      plan[#plan + 1] = {"synthexis-night", {f.pos.x, f.pos.y + 8}, 0.6, true}
      local site = lp("cell_sites")[1]
      if site then plan[#plan + 1] = {"synthexis-clinic", {site.at[1] + 3, site.at[2]}, 1.2} end
    end
    plan[#plan + 1] = {"player-base", {-42, -12}, 0.5}
    S.plan = plan
  end
  if S.plan and t >= 120 and (t - 120) % 30 == 0 then
    local i = (t - 120) / 30 + 1
    local p = S.plan[i]
    if p then shot(p[1], p[2], p[3], p[4]) else helpers.write_file("lp-vista/done.txt", "ok"); S.plan = nil end
  end
end)
