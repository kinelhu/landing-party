-- Screenshot scenes (scripts/shots.sh): what headless runs cannot judge, seen. In a game window (screenshots need the
-- renderer), it stages the mod's own mechanics through its remotes and frames each in a surface screenshot to
-- script-output/lp-shots/, then writes done.txt. One scene at a time, on a timeline; each shot names what to look for.
local lp = function(fn, ...) return remote.call("landing-party", fn, ...) end
local DIR = "lp-shots/"
local S = {}
local lines = {}
local function note(text)
  table.insert(lines, text)
  helpers.write_file(DIR .. "shots.txt", table.concat(lines, "\n") .. "\n")
end
local function surface() return game.surfaces[1] end

local function flatten(x0, y0, x1, y1)
  local s = surface()
  s.request_to_generate_chunks({(x0 + x1) / 2, (y0 + y1) / 2}, math.ceil(math.max(x1 - x0, y1 - y0) / 64) + 1)
  s.force_generate_chunk_requests()
  local tiles = {}
  for x = x0, x1 - 1 do for y = y0, y1 - 1 do table.insert(tiles, {name = "grass-1", position = {x, y}}) end end
  s.set_tiles(tiles, true, true, true, false)
  for _, e in pairs(s.find_entities_filtered{area = {{x0, y0}, {x1, y1}}}) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

-- A shot: `what` is what to look for in it.
local function shot(name, pos, zoom, night, what)
  local res = {1600, 900}
  game.take_screenshot{surface = surface(), position = pos, resolution = res, zoom = zoom or 1, daytime = night and 0.5 or 0,
    path = DIR .. name .. ".png", show_entity_info = false, anti_alias = true}
  note(string.format("%s.png: %s", name, what))
end

local function toward(id, d)
  local o = lp("stats", id).origin
  local len = math.max(1, math.sqrt(o.x * o.x + o.y * o.y))
  return {math.floor(o.x - o.x / len * d), math.floor(o.y - o.y / len * d)}
end

local at = {}
local function schedule(t, f) local g = at[t]; at[t] = g and function() g(); f() end or f end
local function poll(from, to, every, f) for t = from, to, every do schedule(t, f) end end

-- Setup: no biters near, the day frozen at noon, two camps.
schedule(60, function()
  game.speed = 4
  game.map_settings.enemy_expansion.enabled = false
  game.map_settings.pollution.enabled = false
  for _, e in pairs(surface().find_entities_filtered{force = "enemy", position = {0, 0}, radius = 900}) do e.destroy() end
  surface().always_day = false
  surface().daytime = 0
  surface().freeze_daytime = true
  lp("debug_tune", {history_off = true, raids_off = true})
  S.ser = lp("arrive", 1, {x = 0, y = 0}, 300, {corp = "serenity"})
  S.gru = lp("arrive", 1, {x = 0, y = 0}, 300, {corp = "grubstake"})
  for _ = 1, 2 do lp("debug_depot", S.ser, 3000); lp("debug_depot", S.gru, 3000) end
  note("setup: serenity " .. tostring(S.ser) .. ", grubstake " .. tostring(S.gru))
end)

-- 1. Every Landing Party unit, side by side.
schedule(240, function()
  local names = {}
  for name, p in pairs(prototypes.get_entity_filtered{{filter = "type", type = {"unit", "car", "spider-vehicle"}}}) do
    if name:sub(1, 3) == "lp-" then table.insert(names, name) end
  end
  table.sort(names)
  flatten(-560, -40, -400, 40)
  for i, name in ipairs(names) do
    local x, y = -550 + ((i - 1) % 12) * 13, -25 + math.floor((i - 1) / 12) * 14
    local ok, e = pcall(function()
      return surface().create_entity{name = name, position = {x, y}, force = name:find("grubstake") and "lp-grubstake" or "lp-serenity"}
    end)
    if ok and e then
      e.active = false
      rendering.draw_text{text = name:gsub("^lp%-", ""), surface = surface(), target = {x, y + 3}, color = {1, 1, 1},
        scale = 1.2, alignment = "center"}
    end
  end
  S.units = #names
end)
schedule(300, function()
  shot("01-units", {-480, -10}, 0.6, false, S.units .. " units: tints, armour, sizes; Serenity's and Grubstake's apart")
end)

-- 2. The skim by night: a belt of copper plate, a Grubstake truck parked by it with headlights; then the yard.
schedule(360, function()
  local c = toward(S.gru, 110)
  flatten(c[1] - 20, c[2] - 8, c[1] + 20, c[2] + 8)
  S.belts = {}
  for k = -12, 11 do
    table.insert(S.belts, surface().create_entity{name = "transport-belt", position = {c[1] + k + 0.5, c[2] + 0.5},
      direction = defines.direction.east, force = "player"})
  end
  S.belt_at = c
  note("skim: " .. tostring(lp("debug_skim", S.gru, c)))
end)
poll(361, 30 * 3600, 20, function()
  local first, last = S.belts and S.belts[1], S.belts and S.belts[#S.belts]
  if first and first.valid then
    for line = 1, 2 do
      local tl = first.get_transport_line(line)
      for _ = 1, 3 do if not tl.insert_at_back({name = "copper-plate", count = 1}) then break end end
      local out = last.get_transport_line(line)
      local n = out.get_item_count("copper-plate")
      if n > 0 then out.remove_item({name = "copper-plate", count = n}) end
    end
  end
end)
local function skim_parked()
  local k = lp("skim", S.gru)
  if not S.parked_shot and k and k.parked then
    S.parked_shot = true
    shot("02-skim-night", k.parked, 1.4, true, "a Grubstake truck parked at the belt, headlights by night; gaps downstream")
    shot("03-skim-day", k.parked, 1.4, false, "the same truck by day")
  end
  if S.parked_shot and not S.yard_shot and k and k.yard > 0 then
    S.yard_shot = true
    local y = surface().find_entities_filtered{name = "lp-skim-yard", limit = 1}[1]
    if y then shot("04-yard", y.position, 1.6, false, "Grubstake's yard: a chest in its colour, the icon of what it holds most") end
  end
end
poll(420, 30 * 3600, 30, skim_parked)

-- 3. A raid that steals: an outpost of assemblers; the leader's icon during the attack; the ghosts after.
schedule(4 * 3600, function()
  local o = lp("stats", S.gru).origin
  local c = {math.floor(o.x + 90), math.floor(o.y + 30)}
  flatten(c[1] - 16, c[2] - 12, c[1] + 16, c[2] + 12)
  for k = 0, 3 do
    local a = surface().create_entity{name = "assembling-machine-2", position = {c[1] - 6 + 4 * k + 0.5, c[2] + 0.5}, force = "player"}
    a.set_recipe("iron-gear-wheel"); a.insert{name = "iron-plate", count = 50}
  end
  for k = 0, 1 do surface().create_entity{name = "solar-panel", position = {c[1] - 3 + 4 * k + 0.5, c[2] + 5.5}, force = "player"} end
  surface().create_entity{name = "medium-electric-pole", position = {c[1] + 0.5, c[2] + 3.5}, force = "player"}
  S.raid_at = c
  lp("debug_units", S.gru, "lp-infantry", 6)
  lp("dev", {"raid", tostring(S.gru)}, c)
end)
poll(4 * 3600 + 30, 20 * 3600, 20, function()
  if not S.raid_at then return end
  local o = lp("stats", S.gru).ops
  if not S.leader_shot and o.phase == "attack" and o.leader then
    S.leader_shot = true
    shot("05-raid-leader", S.raid_at, 1.5, false, "Grubstake raiders walking in, one under the mining-pick icon (its leader)")
  end
  if S.leader_shot and not S.ghost_shot and surface().count_entities_filtered{name = "entity-ghost", position = S.raid_at, radius = 16} >= 3 then
    S.ghost_shot = true
    shot("06-dismantled", S.raid_at, 1.5, false, "ghosts where the assemblers, panels and pole stood (taken apart and carried off)")
  end
end)

-- 4. Serenity's invoice post, by day and, under a truce, by night.
schedule(5 * 3600, function()
  S.post = lp("debug_bill", S.ser, "player", 240)
  if S.post then shot("07-invoice", S.post, 1.8, false, "the invoice post at Serenity's line: a chest in its colour, the sum owed over it") end
end)
schedule(5 * 3600 + 120, function()
  lp("debug_truce", "serenity", "player", 10)
end)
schedule(5 * 3600 + 800, function()
  if S.post then shot("08-invoice-truce-night", S.post, 1.8, true, "by night under a truce: the amber light, the minutes left") end
end)

-- 5. A jammer mast among the player's robots.
schedule(6 * 3600, function()
  local c = toward(S.ser, 140)
  flatten(c[1] - 30, c[2] - 30, c[1] + 30, c[2] + 30)
  local rp = surface().create_entity{name = "roboport", position = {c[1] + 10, c[2]}, force = "player"}
  surface().create_entity{name = "electric-energy-interface", position = {c[1] + 16, c[2]}, force = "player"}
  surface().create_entity{name = "substation", position = {c[1] + 14, c[2] + 4}, force = "player"}
  rp.insert{name = "construction-robot", count = 20}
  for k = 0, 9 do surface().create_entity{name = "entity-ghost", inner_name = "stone-wall", position = {c[1] - 10 + 2 * k, c[2] + 12}, force = "player"} end
  S.jam = lp("debug_jammer", "serenity", {c[1] - 6, c[2]})
  S.jam_at = c
end)
schedule(6 * 3600 + 240, function()
  if S.jam_at then shot("09-jammer", S.jam_at, 1.0, false, "Serenity's jammer mast, its arcs on the player's robots") end
end)

-- 6. Serenity's camp from above.
schedule(6 * 3600 + 300, function()
  local o = lp("stats", S.ser).origin
  shot("10-serenity-camp", {o.x, o.y}, 0.35, false, "Serenity's camp: walls, gates, concrete, its silhouette")
  local g = lp("stats", S.gru).origin
  shot("11-grubstake-camp", {g.x, g.y}, 0.35, false, "Grubstake's camp: sprawl, gravel, its yard")
end)

schedule(6 * 3600 + 420, function()
  helpers.write_file(DIR .. "shots.txt", table.concat(lines, "\n") .. "\n")
  helpers.write_file(DIR .. "done.txt", "done\n")
end)

script.on_event(defines.events.on_tick, function(e)
  if e.tick % 300 == 0 then helpers.write_file(DIR .. "tick.txt", e.tick .. " speed " .. game.speed .. " paused " .. tostring(game.tick_paused) .. "\n") end
  local f = at[e.tick]
  if f then
    local ok, err = pcall(f)
    if not ok then note("ERROR at " .. e.tick .. ": " .. tostring(err)) end
  end
end)
