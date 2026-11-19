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
-- LP_SHOTS=town (scripts/shots.sh): Grubstake's town only, grown at once (remote debug_town), in a minute and a half.
local ok_mode, mode = pcall(require, "mode")
local MODE = ok_mode and mode or "all"
local only = schedule
if MODE == "town" or MODE == "culture" or MODE == "army" then schedule = function(t, f) if t <= 60 then only(t, f) end end end

-- Setup: no biters near, the day frozen at noon, two camps.
schedule(60, function()
  game.speed = 4
  game.map_settings.enemy_expansion.enabled = false
  game.map_settings.pollution.enabled = false
  for _, e in pairs(surface().find_entities_filtered{force = "enemy", position = {0, 0}, radius = 900}) do e.destroy() end
  surface().always_day = false
  surface().daytime = 0
  surface().freeze_daytime = true
  lp("debug_tune", {history_off = true, raids_off = true, mature_blocks = 1, belts_always = true})
  S.ser = lp("arrive", 1, {x = 0, y = 0}, 300, {corp = "serenity"})
  S.gru = lp("arrive", 1, {x = 0, y = 0}, 300, {corp = "grubstake"})
  for _ = 1, 2 do lp("debug_depot", S.ser, 3000); lp("debug_depot", S.gru, 3000) end
  note("setup: serenity " .. tostring(S.ser) .. ", grubstake " .. tostring(S.gru))
end)

-- 1. Every Landing Party unit, side by side.
schedule(240, function()
  local names = {}
  for name, p in pairs(prototypes.get_entity_filtered{{filter = "type", type = {"unit", "car", "spider-vehicle"}}}) do
    -- Plate variants (research: -fire, -laser, -physical...) look the same: the base kinds only.
    if name:sub(1, 3) == "lp-" and not name:find("%-fire$") and not name:find("%-laser$") and not name:find("%-physical$")
      and not name:find("%-explosion$") and not name:find("%-electric$") then table.insert(names, name) end
  end
  table.sort(names)
  flatten(-560, -40, -400, 40)
  for i, name in ipairs(names) do
    local x, y = -540 + ((i - 1) % 8) * 9, -24 + math.floor((i - 1) / 8) * 9
    local ok, e = pcall(function()
      return surface().create_entity{name = name, position = {x, y}, force = name:find("grubstake") and "lp-grubstake" or "lp-serenity"}
    end)
    if ok and e then
      e.disabled_by_script = true
      rendering.draw_text{text = name:gsub("^lp%-", ""), surface = surface(), target = {x, y + 3}, color = {1, 1, 1},
        scale = 1.2, alignment = "center"}
    end
  end
  S.units = #names
end)
schedule(300, function()
  shot("01-units", {-509, -10}, 0.9, false, S.units .. " units: tints, armour, sizes; Serenity's and Grubstake's apart")
end)

-- 1b. Portraits for the unit roster (scripts/roster_page.py): every unit alone, from close, by day; the labs too.
schedule(400, function()
  flatten(-560, 60, -380, 240)
  S.portraits = {}
  local names = {}
  for name in pairs(prototypes.get_entity_filtered{{filter = "type", type = {"unit", "spider-unit"}}}) do
    if name:sub(1, 3) == "lp-" and not name:find("%-fire$") and not name:find("%-laser$") and not name:find("%-physical$")
      and not name:find("%-explosion$") and not name:find("%-electric$") then table.insert(names, name) end
  end
  for _, l in ipairs({"lp-optics-lab", "lp-line-lab", "lp-siege-lab", "lp-depot",
    -- Synthexis's buildings (the field guide, 2026-10-24).
    "lp-clinic", "lp-pen", "lp-biochamber", "lp-heating-tower", "lp-tumor", "lp-bred-worm"}) do
    if prototypes.entity[l] then table.insert(names, l) end
  end
  table.sort(names)
  for i, name in ipairs(names) do
    local pos = {-550 + ((i - 1) % 12) * 14, 70 + math.floor((i - 1) / 12) * 14}
    local ok, e = pcall(function()
      local synth = name:find("^lp%-bred") or name == "lp-clinic" or name == "lp-pen" or name == "lp-biochamber"
        or name == "lp-heating-tower" or name == "lp-tumor" or name == "lp-technician" or name == "lp-runt"
      return surface().create_entity{name = name, position = pos,
        force = synth and "lp-biotech" or name:find("grubstake") and "lp-grubstake" or "lp-serenity"}
    end)
    if ok and e then
      -- Held still; not a lab (on 2.1 a disabled lab draws only its shadow, the field guide's run, 2026-10-24).
      if e.type ~= "lab" then e.disabled_by_script = true end
      -- A lab's body is the mod's busy animation, drawn on it by script when a camp places it (data.lua lp-lab-busy).
      if e.type == "lab" then rendering.draw_animation{animation = "lp-lab-busy", target = e, surface = e.surface, render_layer = "object"} end
      table.insert(S.portraits, {name = name, pos = pos})
    end
  end
end)
schedule(460, function()
  for _, p in ipairs(S.portraits or {}) do
    local big = p.name:find("lab") or p.name:find("depot") or p.name:find("walker") or p.name:find("stomper")
      or p.name:find("behemoth") or p.name == "lp-clinic" or p.name == "lp-pen" or p.name == "lp-heating-tower"
      or p.name == "lp-biochamber" or p.name:find("truck")
    game.take_screenshot{surface = surface(), position = {p.pos[1], p.pos[2] - 0.6}, resolution = {320, 320},
      zoom = big and 1.4 or (p.name:find("harrier") or p.name:find("scavenger") or p.name:find("drone")) and 4 or 2.2, daytime = 0, path = DIR .. "roster/" .. p.name .. ".png", show_entity_info = false,
      anti_alias = true}
  end
  note(string.format("roster/: %d portraits", #(S.portraits or {})))
end)

-- 1c. The design sheet (tests/lp-shots/data.lua): candidate looks for units not yet built, each alone, from close and
-- at play zoom, facing four ways; the shield truck's bubble drawn round it.
schedule(500, function()
  flatten(-560, 260, -380, 420)
  S.mocks = {}
  local names = {}
  for name in pairs(prototypes.get_entity_filtered{{filter = "type", type = "unit"}}) do
    if name:sub(1, 5) == "mock-" then table.insert(names, name) end
  end
  table.sort(names)
  for i, name in ipairs(names) do
    local y = 275 + (i - 1) * 16
    local row = {}
    for k, dir in ipairs({defines.direction.south, defines.direction.southeast, defines.direction.east, defines.direction.north}) do
      local e = surface().create_entity{name = name, position = {-540 + (k - 1) * 9, y}, force = "lp-serenity"}
      if e then
        -- Turned to face `dir` (a unit faces where it last moved): told to walk a step that way, then held.
        local v = ({[defines.direction.south] = {0, 1}, [defines.direction.southeast] = {1, 1}, [defines.direction.east] = {1, 0},
          [defines.direction.north] = {0, -1}})[dir]
        e.commandable.set_command{type = defines.command.go_to_location, destination = {e.position.x + v[1] * 3, e.position.y + v[2] * 3},
          distraction = defines.distraction.none}
        table.insert(row, e)
        if name:find("shield") then
          rendering.draw_animation{animation = "mock-shield-dome", target = e, surface = surface(), render_layer = "air-object"}
          -- The two on the right as if struck: the dome's flash and a ripple where the shot hit its rim (held still).
          if k >= 3 then
            rendering.draw_animation{animation = "mock-shield-flash", target = e, surface = surface(), render_layer = "air-object",
              animation_speed = 0, animation_offset = k == 3 and 0 or 2}
            rendering.draw_animation{animation = "mock-shield-hit", target = {entity = e, offset = {2.6, -2.2}}, surface = surface(),
              render_layer = "air-object", animation_speed = 0, animation_offset = k == 3 and 2 or 5}
          end
        end
      end
    end
    rendering.draw_text{text = prototypes.entity[name].localised_name, surface = surface(), target = {-545, y - 4.5},
      color = {1, 1, 1}, scale = 1.4}
    table.insert(S.mocks, {name = name, y = y, row = row})
  end
end)
schedule(530, function()
  for _, m in ipairs(S.mocks or {}) do for _, e in ipairs(m.row) do if e.valid then e.disabled_by_script = true end end end
end)
schedule(540, function()
  for _, m in ipairs(S.mocks or {}) do
    game.take_screenshot{surface = surface(), position = {-527, m.y - 1}, resolution = {1600, 440}, zoom = 1.4, daytime = 0,
      path = DIR .. "mockups/" .. m.name .. ".png", show_entity_info = false, anti_alias = true}
  end
  local first, last = S.mocks[1], S.mocks[#S.mocks]
  if first then
    game.take_screenshot{surface = surface(), position = {-527, (first.y + last.y) / 2}, resolution = {1400, 1400}, zoom = 0.8,
      daytime = 0, path = DIR .. "mockups/00-sheet.png", show_entity_info = false, anti_alias = true}
  end
  note(string.format("mockups/: %d candidates", #(S.mocks or {})))
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
  if not S.leader_shot and o.phase == "attack" and o.leader and surface().count_entities_filtered{position = S.raid_at,
    radius = 10, force = "lp-grubstake", type = "unit", limit = 1} > 0 then
    S.leader_shot = true
    shot("05-raid-leader", S.raid_at, 1.5, false, "Grubstake raiders walking in, one under the mining-pick icon (its leader)")
  end
  if S.leader_shot and not S.ghost_shot and surface().count_entities_filtered{name = "entity-ghost", position = S.raid_at, radius = 16} >= 3 then
    S.ghost_shot = true
    shot("06-dismantled", S.raid_at, 1.5, false, "ghosts where the assemblers, panels and pole stood (taken apart and carried off)")
  end
end)

-- 4. Serenity's invoice post, by day and, overdue (a collection on its way), by night.
schedule(5 * 3600, function()
  S.post = lp("debug_bill", S.ser, "player", 240)
  if S.post then shot("07-invoice", S.post, 1.8, false, "the invoice post at Serenity's line: a chest in its colour, the sum owed over it") end
end)
schedule(5 * 3600 + 120, function()
  lp("debug_overdue", S.ser)
end)
schedule(5 * 3600 + 800, function()
  if S.post then shot("08-invoice-overdue-night", S.post, 1.8, true, "by night, overdue: the amber light, a collection on its way") end
end)

-- 4b. Close up (the user's feedback, 2026-10-21): a lab at work (animated, a size up), a depot (Space Age's cargo bay),
-- the silo shut, a fabricator; a Serenity tank shelling a player wall (its cannon round); a wreck where a unit fell.
schedule(5 * 3600, function()
  local c = toward(S.ser, 170)
  flatten(c[1] - 30, c[2] - 20, c[1] + 30, c[2] + 20)
  for k, name in ipairs({"lp-optics-lab", "lp-depot", "lp-fabricator", "lp-launchpad"}) do
    lp("debug_place", S.ser, name, {c[1] - 20 + (k - 1) * 9 + (name == "lp-launchpad" and 4 or 0), c[2] - 6})
  end
  for k = 0, 7 do surface().create_entity{name = "stone-wall", position = {c[1] - 4 + k, c[2] + 12}, force = "player"} end
  S.tank = surface().create_entity{name = "lp-tank", position = {c[1], c[2] + 2}, force = "lp-serenity"}
  if S.tank then
    S.tank.commandable.set_command{type = defines.command.attack_area, destination = {c[1], c[2] + 12}, radius = 6}
  end
  local u = surface().create_entity{name = "lp-infantry", position = {c[1] + 12, c[2] + 8}, force = "lp-serenity"}
  if u then u.die("player") end
  S.close = c
end)
poll(5 * 3600 + 60, 5 * 3600 + 200, 7, function()
  if S.close and not S.fired then
    local n = surface().count_entities_filtered{name = "lp-tank-shell", position = S.close, radius = 30}
    if n > 0 then S.fired = true; shot("08b-tank-shell", {S.close[1], S.close[2] + 7}, 2, false, "a Serenity tank's cannon round in flight at a wall") end
  end
end)
schedule(5 * 3600 + 210, function()
  if S.close then
    shot("08c-props", {S.close[1] - 2, S.close[2] - 2}, 0.9, false,
      "left to right: the lab (animated: compare 08d), the depot (cargo bay), a fabricator, the silo shut; a wreck lower right")
  end
end)
schedule(5 * 3600 + 217, function()
  if S.close then shot("08d-lab-frame", {S.close[1] - 20, S.close[2] - 6}, 2.5, false, "the lab a few frames on (it animates)") end
end)

-- 5. A jammer mast among the player's robots.
schedule(6 * 3600, function()
  local c = toward(S.ser, 140)
  flatten(c[1] - 30, c[2] - 30, c[1] + 30, c[2] + 30)
  local rp = surface().create_entity{name = "roboport", position = {c[1] + 10, c[2]}, force = "player"}
  local eei = surface().create_entity{name = "electric-energy-interface", position = {c[1] + 16, c[2]}, force = "player"}
  eei.power_production, eei.electric_buffer_size = 20e6 / 60, 20e6
  surface().create_entity{name = "substation", position = {c[1] + 14, c[2] + 4}, force = "player"}
  rp.insert{name = "construction-robot", count = 20}
  local store = surface().create_entity{name = "storage-chest", position = {c[1] + 12, c[2] + 4}, force = "player"}
  store.insert{name = "stone-wall", count = 50}
  for k = 0, 9 do surface().create_entity{name = "entity-ghost", inner_name = "stone-wall", position = {c[1] - 10 + 2 * k, c[2] + 12}, force = "player"} end
  S.jam = lp("debug_jammer", "serenity", {c[1] - 6, c[2]})
  S.jam_at = c
end)
schedule(6 * 3600 + 240, function()
  if S.jam_at then shot("09-jammer", S.jam_at, 1.0, false, "Serenity's jammer mast, its arcs on the player's robots") end
end)

-- 6. Serenity's camp from above (late enough for its launch pad: mature_blocks 1).
schedule(12 * 3600, function()
  local o = lp("stats", S.ser).origin
  shot("10-serenity-camp", {o.x, o.y}, 0.35, false, "Serenity's camp: walls, gates, concrete, its silhouette")
  local g = lp("stats", S.gru).origin
  shot("11-grubstake-camp", {g.x, g.y}, 0.35, false, "Grubstake's camp: sprawl, gravel, its yard")
  -- Its launch pad grown (mature_blocks 1): the silo in its paved block, a ring of hazard stripes, a lamp at each corner.
  local pads = surface().find_entities_filtered{name = "lp-launchpad", force = "lp-serenity"}
  local closest
  for _, p in ipairs(pads) do
    if not S.close or (p.position.x - S.close[1]) ^ 2 + (p.position.y - S.close[2]) ^ 2 > 400 then closest = p end
  end
  if closest then shot("12-launch-pad", closest.position, 1.0, false, "Serenity's launch pad: paved, hazard ring, four lamps")
  else note("12-launch-pad: none built yet") end
  -- A district's belts (parts riding from a fabricator to a depot) and its floor (aprons, hazard rings).
  local belt = surface().find_entities_filtered{name = "lp-belt", force = "lp-serenity", limit = 1}[1]
  if belt then shot("13-district-belts", belt.position, 1.2, false, "a Serenity district: belts carrying parts, concrete aprons, hazard rings")
  else note("13-district-belts: no belt built yet") end
  local yard = surface().find_entities_filtered{name = "lp-skim-yard", limit = 1}[1]
  if yard then shot("14-sushi", yard.position, 1.8, false, "Grubstake's yard and its sushi belt of stolen goods") end
end)

-- 7. Grubstake's town grown (layout.lua towns: lots along a tree of gravel streets, yards of junk, no walls but its
-- pad's fence): fed parts so it grows, seen wide and close at 30 and 45 minutes.
poll(13 * 3600, 44 * 3600, 3600, function() lp("debug_depot", S.gru, 3000) end)
local function town_shots(tag)
  local g = lp("stats", S.gru).origin
  shot("15-grubstake-town-" .. tag, {g.x, g.y}, 0.25, false, "Grubstake's town, wide: streets branching from its pad")
  local f = surface().find_entities_filtered{name = "lp-grubstake-fabricator", limit = 1}[1]
  if f then shot("16-grubstake-street-" .. tag, f.position, 0.7, false, "a Grubstake street: machines either side, gravel") end
  local w = surface().find_entities_filtered{name = "wooden-chest", force = "neutral", position = {g.x, g.y}, radius = 200, limit = 1}[1]
    or surface().find_entities_filtered{name = "crash-site-spaceship-wreck-small-4", force = "neutral", position = {g.x, g.y}, radius = 200, limit = 1}[1]
  if w then shot("17-grubstake-yard-" .. tag, w.position, 0.8, false, "a Grubstake junk yard beside a lot") end
end
schedule(30 * 3600, function() town_shots("m30") end)
schedule(45 * 3600, function() town_shots("m45") end)

schedule(45 * 3600 + 120, function()
  helpers.write_file(DIR .. "shots.txt", table.concat(lines, "\n") .. "\n")
  helpers.write_file(DIR .. "done.txt", "done\n")
end)

if MODE == "town" then
  only(300, function()
    lp("debug_tune", {crews_off = true})
    lp("debug_depot", S.gru, 10000)
    note("town: " .. serpent.line(lp("debug_town", S.gru, 12, 20)))
  end)
  only(300 + 5 * 3600, function()
    local g = lp("stats", S.gru).origin
    shot("15-grubstake-town-fast", {g.x, g.y}, 0.2, false, "Grubstake's town grown at once: streets, lots, yards")
    shot("15-grubstake-town-fast-near", {g.x, g.y}, 0.4, false, "the same, nearer")
    local f = surface().find_entities_filtered{name = "lp-grubstake-fabricator", position = {g.x, g.y}, radius = 200}
    if f[#f] then shot("16-grubstake-street-fast", f[#f].position, 0.8, false, "a Grubstake street") end
    local w = surface().find_entities_filtered{name = "wooden-chest", force = "neutral", position = {g.x, g.y}, radius = 250, limit = 1}[1]
    if w then shot("17-grubstake-yard-fast", w.position, 0.9, false, "a Grubstake yard") end
    shot("18-grubstake-town-fast-night", {g.x, g.y}, 0.4, true, "the town by night: its lamps")
    local t = surface().find_entities_filtered{name = "lp-grubstake-turret", position = {g.x, g.y}, radius = 250}
    if t[#t] then shot("19-grubstake-turret-pit", t[#t].position, 1.2, false, "a Grubstake turret in its pit of fence") end
  end)
  only(300 + 5 * 3600 + 120, function()
    helpers.write_file(DIR .. "shots.txt", table.concat(lines, "\n") .. "\n")
    helpers.write_file(DIR .. "done.txt", "done\n")
  end)
end

-- LP_SHOTS=culture: a Synthexis culture on a nest field 450 tiles east, fed smog, eight minutes on: its creep, its
-- buried tumors and their roots, its wandering buds.
if MODE == "culture" then
  only(300, function()
    local s = surface()
    for x = -6, 6, 3 do surface().create_entity{name = "assembling-machine-1", position = {x, -20}, force = "player"} end
    S.field = {450, 0}
    s.request_to_generate_chunks(S.field, 5)
    s.force_generate_chunk_requests()
    for k = 1, 30 do
      local a, r = k * 2.4, (k <= 5) and 8 or 30 + (k % 6) * 15
      local q = s.find_non_colliding_position("biter-spawner", {450 + math.cos(a) * r, math.sin(a) * r}, 20, 1)
      if q then s.create_entity{name = "biter-spawner", position = q, force = "enemy"} end
    end
    game.forces.enemy.set_evolution_factor(0.3, s)
    note("culture: " .. tostring(lp("farm_arrive", 1)))
  end)
  poll(600, 8 * 3600, 600, function()
    local f = (lp("farm_state").farms or {})[1]
    local c = f and {f.pos.x, f.pos.y} or S.field
    for dx = -90, 90, 45 do for dy = -90, 90, 45 do surface().pollute({c[1] + dx, c[2] + dy}, 300) end end
  end)
  only(8 * 3600, function()
    -- Where it came down (its pod picks the field: likely ours, maybe the map's own).
    local f = (lp("farm_state").farms or {})[1]
    if f then S.field = {f.pos.x, f.pos.y} end
    note(string.format("culture at %.0f,%.0f", S.field[1], S.field[2]))
    shot("20-culture-wide", S.field, 0.3, false, "a Synthexis culture: creep, incubators, tumors budding out")
    shot("21-culture-near", S.field, 0.8, false, "its tumors sunk in the creep, slime and nerve roots round them")
    local t = surface().find_entities_filtered{name = "lp-tumor", position = S.field, radius = 150}
    if t[#t] then shot("22-culture-tumor", t[#t].position, 1.6, false, "a tumor close up") end
    shot("23-culture-night", S.field, 0.5, true, "the culture by night")
  end)
  only(8 * 3600 + 120, function()
    helpers.write_file(DIR .. "shots.txt", table.concat(lines, "\n") .. "\n")
    helpers.write_file(DIR .. "done.txt", "done\n")
  end)
end

-- LP_SHOTS=army (0.2.465 to 0.2.467, what headless runs cannot see: they have no player): the hover rings round a powered
-- barracks, an unpowered one and a supply depot; the cards' ammunition bars and the squad panel's line beside the
-- rounds the units really hold; a dry unit's alert, raised and cleared on rearming; a stranded one's, kept. Each reading
-- goes in shots.txt as "CHECK ok|BAD name: detail", read back by the caller.
if MODE == "army" then
  local function put(name, x, y)
    return surface().create_entity{name = name, position = {x, y}, force = "player", raise_built = true}
  end
  local function apoll(from, to, every, f) for t = from, to, every do only(t, f) end end
  local function check(name, ok, detail) note(string.format("CHECK %s %s: %s", ok and "ok" or "BAD", name, detail or "")) end
  local function P() return game.get_player(1) end
  local function gshot(name, pos, zoom, what)
    game.take_screenshot{player = P(), by_player = P(), surface = surface(), position = pos, resolution = {1600, 900},
      zoom = zoom, show_gui = true, show_entity_info = true, path = DIR .. name .. ".png", force_render = true}
    note(string.format("%s.png: %s", name, what))
  end
  -- The rings drawn for player 1: {total, by colour key, filled}.
  local function rings()
    local n, filled, col = 0, 0, {}
    for _, o in pairs(rendering.get_all_objects("landing-party")) do
      if o.valid and o.type == "circle" then
        local mine = false
        for _, pl in pairs(o.players or {}) do if pl.index == 1 then mine = true end end
        if mine then
          n = n + 1
          if o.filled then filled = filled + 1 end
          local c = o.color
          local k = string.format("%.1f/%.1f/%.1f", c.r, c.g, c.b)
          col[k] = (col[k] or 0) + 1
        end
      end
    end
    return n, filled, col
  end
  local function alerts_of(u)
    local n = 0
    for _, by_type in pairs(P().get_alerts{entity = u, type = defines.alert_type.custom}) do
      for _, list in pairs(by_type) do n = n + #list end
    end
    return n
  end
  only(120, function()
    game.speed = 1
    flatten(-60, -80, 60, 30)
    game.forces.player.technologies["lp-command-bandwidth-1"].researched = true
    game.forces.player.technologies["logistic-system"].researched = true
    put("electric-energy-interface", 4, 1)
    put("medium-electric-pole", 2.5, 2.5)
    put("lp-command-relay", 0.5, 6.5)
    put("lp-command-relay", 4.5, 6.5)
    put("medium-electric-pole", 2.5, 5.5)
    S.bk = put("lp-barracks", 0.5, 0.5)
    S.bk.set_recipe("lp-trooper-order")
    S.bk.get_inventory(defines.inventory.crafter_input).insert{name = "firearm-magazine", count = 30}
    -- An unpowered barracks 40 east, a depot 40 west with magazines in it (off the way north: the trooper rearms at the
    -- barracks).
    S.cold = put("lp-barracks", 40.5, 0.5)
    S.depot = put("lp-supply-depot", -40.5, 0.5)
    S.depot.get_inventory(defines.inventory.chest).insert{name = "firearm-magazine", count = 20}
    S.B = put("lp-rally-beacon", 0.5, -45.5)
    S.T = surface().create_entity{name = "lp-trooper", position = {-1, -47}, force = "player"}
    S.R = surface().create_entity{name = "lp-rocket-trooper", position = {2, -47}, force = "player"}
    lp("debug_enlist", {{-3, -49}, {4, -45}})
    S.foe = surface().create_entity{name = "biter-spawner", position = {0.5, -59}, force = "enemy"}
    P().teleport({0, -20})
    note("army: set up")
  end)
  -- (A spawner healed each second: they do not fire on one that cannot be hurt.)
  apoll(180, 150 * 60, 60, function() if S.foe and S.foe.valid then S.foe.health = S.foe.max_health end end)
  -- Hover rings: a powered barracks, then the depot, then nothing.
  -- (Whether the engine raises on_selected_entity_changed for a script's selected is noted; if not, the handler is
  -- called through debug_hover, as the event would.)
  local function hover(e)
    P().selected = e
    S.sel = P().selected and P().selected.name or "nil"
  end
  local function hover_fallback()
    if rings() == 0 and P().selected then
      note("hover: no rings 5 ticks after a script's selected (" .. S.sel .. "): the handler called through debug_hover")
      lp("debug_hover", 1)
    end
  end
  only(300, function() hover(S.bk) end)
  only(305, hover_fallback)
  only(310, function()
    local n, f, col = rings()
    S.ring_bk = n
    check("rings on hovering the barracks: one each for 3 sources, the hovered filled", n >= 3 and f >= 1,
      string.format("%d rings, %d filled, %s", n, f, serpent.line(col)))
    gshot("army-01-rings-barracks", {0, 0}, 0.3, "hover over the powered barracks: green ring filled, grey round the unpowered one east, amber round the depot west")
  end)
  only(400, function() hover(S.depot) end)
  only(405, hover_fallback)
  only(410, function()
    local n, f, col = rings()
    check("rings on hovering the depot", n >= 3 and f >= 1, string.format("%d rings, %d filled, %s", n, f, serpent.line(col)))
    gshot("army-02-rings-depot", {0, 0}, 0.3, "hover over the depot: its amber ring filled")
  end)
  only(500, function() hover(nil) end)
  only(505, function() if rings() > 0 then lp("debug_hover", 1) end end)
  only(510, function()
    local n = rings()
    check("rings gone when nothing is hovered", n == 0, n .. " rings")
  end)
  -- Cards: the army selected; each card's ammunition bar against the unit's rounds.
  local function cards_check(tag, shotname, what)
    local fr = P().gui.screen.lp_cards
    local bars = {}
    local function walk(el)
      if el.name == "lp_card_ammo" then bars[#bars + 1] = string.format("%.2f%s", el.value, el.visible and "" or "(hidden)") end
      for _, c in pairs(el.children) do walk(c) end
    end
    if fr then walk(fr) end
    local a, r = lp("debug_ammo", S.T), lp("debug_ammo", S.R)
    check("cards " .. tag, fr ~= nil and #bars >= 1, string.format("frame %s, bars %s; trooper %s/%s, rocket %s/%s",
      tostring(fr ~= nil), table.concat(bars, " "), tostring(a and a.ammo), tostring(a and a.full), tostring(r and r.ammo),
      tostring(r and r.full)))
    gshot(shotname, S.T.position, 0.8, what)
  end
  only(570, function() lp("debug_select_army", false) end)
  only(600, function() cards_check("at the start", "army-03-cards-full", "the cards: amber bars full under the health bars") end)
  -- The squad panel, opened on the beacon.
  local function panel_check(tag, shotname)
    local f = P().gui.relative.lp_squad
    local cap = f and f.ammo and f.ammo.caption
    local v = lp("debug_beacon_ammo", S.B)
    check("squad panel " .. tag, f ~= nil and f.ammo.visible, string.format("caption %s; view %s", serpent.line(cap), serpent.line(v)))
    gshot(shotname, S.B.position, 0.8, "the beacon's window and the squad panel beside it: its ammunition line")
  end
  only(640, function() P().opened = S.B end)
  only(730, function() panel_check("at the start", "army-04-panel-full") end)
  only(760, function() P().opened = nil end)
  -- The dry trooper: its alert while dry, none once it is back; the rocket trooper's, kept.
  apoll(780, 150 * 60, 30, function()
    local a, r = lp("debug_ammo", S.T), lp("debug_ammo", S.R)
    if not (a and r) then return end
    if r.dry and not S.r_seen then
      S.r_seen = game.tick
      S.r_alert0 = alerts_of(S.R)
    end
    if a.dry and not S.dry_at then
      S.dry_at = game.tick
      S.alert_dry = alerts_of(S.T)
      gshot("army-05-alert", {0, -30}, 0.5, "the trooper dry: its alert in the alert bar, its card's bar empty, the rocket trooper's alert")
      lp("debug_select_army", false)
      P().opened = S.B
      S.dry_read = game.tick + 90
    end
    if S.dry_read and game.tick >= S.dry_read then
      S.dry_read = nil
      cards_check("one dry", "army-06-cards-dry", "the cards with one dry: its bar empty, its order line 'dry' or 'rearm'")
      panel_check("one dry", "army-07-panel-dry")
      P().opened = nil
    end
    if S.dry_at and not a.dry and not S.back_at then
      S.back_at = game.tick
      S.alert_back = alerts_of(S.T)
    end
  end)
  only(150 * 60 + 30, function()
    check("rocket trooper dry and stranded, alerted, still alerted at the end", S.r_seen and S.r_alert0 >= 1 and alerts_of(S.R) >= 1,
      string.format("dry at %s, alerts then %s, now %d", tostring(S.r_seen), tostring(S.r_alert0), alerts_of(S.R)))
    check("trooper's alert while dry", S.dry_at and S.alert_dry >= 1, string.format("dry at %s, %s alerts",
      tostring(S.dry_at), tostring(S.alert_dry)))
    check("trooper's alert cleared once rearmed", S.back_at and S.alert_back == 0, string.format("back at %s, %s alerts",
      tostring(S.back_at), tostring(S.alert_back)))
    gshot("army-08-end", {0, -30}, 0.5, "the end: the rocket trooper's alert still up")
    helpers.write_file(DIR .. "shots.txt", table.concat(lines, "\n") .. "\n")
    helpers.write_file(DIR .. "done.txt", "done\n")
  end)
end

script.on_event(defines.events.on_tick, function(e)
  if e.tick % 300 == 0 then helpers.write_file(DIR .. "tick.txt", e.tick .. " speed " .. game.speed .. " paused " .. tostring(game.tick_paused) .. "\n") end
  local f = at[e.tick]
  if f then
    local ok, err = pcall(f)
    if not ok then note("ERROR at " .. e.tick .. ": " .. tostring(err)) end
  end
end)
