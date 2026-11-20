-- The multiplayer army check (scripts/mp.sh LP_ARMY=1): two clients on one force, each with its own army GUI at once.
-- Called over RCON (remote "lp-mp"), so every step runs in the game's own state on every peer. Player a (the first to
-- join) selects the army: its cards. Player b opens the rally beacon: the squad panel; hovers the barracks: the rings.
-- Each must see its own and not the other's. Then the trooper runs dry: both players get its alert, cleared when it
-- rearms; the stranded rocket trooper keeps its alert for both. Each reading is "CHECK ok|BAD name: detail".
local lp = function(fn, ...) return remote.call("landing-party", fn, ...) end
local S = {}
local function surface() return game.surfaces[1] end
local function put(name, x, y)
  return surface().create_entity{name = name, position = {x, y}, force = "player", raise_built = true}
end
local function flatten(x0, y0, x1, y1)
  local s = surface()
  s.request_to_generate_chunks({(x0 + x1) / 2, (y0 + y1) / 2}, math.ceil(math.max(x1 - x0, y1 - y0) / 64) + 1)
  s.force_generate_chunk_requests()
  local tiles = {}
  for x = x0, x1 - 1 do for y = y0, y1 - 1 do tiles[#tiles + 1] = {name = "grass-1", position = {x, y}} end end
  s.set_tiles(tiles, true, true, true, false)
  for _, e in pairs(s.find_entities_filtered{area = {{x0, y0}, {x1, y1}}}) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end
local function rings(index)
  local n, filled = 0, 0
  for _, o in pairs(rendering.get_all_objects("landing-party")) do
    -- (The supply rings only, 30 tiles: a selected unit's own ring is a circle too.)
    if o.valid and o.type == "circle" and o.radius and o.radius >= 20 then
      for _, pl in pairs(o.players or {}) do
        if pl.index == index then n = n + 1; if o.filled then filled = filled + 1 end end
      end
    end
  end
  return n, filled
end
local function alerts(p, u)
  local n = 0
  for _, by_type in pairs(p.get_alerts{entity = u, type = defines.alert_type.custom}) do
    for _, list in pairs(by_type) do n = n + #list end
  end
  return n
end
local out = {}
local function check(name, ok, detail) out[#out + 1] = string.format("CHECK %s %s: %s", ok and "ok" or "BAD", name, detail or "") end
local function skip(name, why) out[#out + 1] = string.format("CHECK skip %s: %s", name, why) end
-- (One client, LP_CLIENTS=1: two Steam clients of one account share its name and the server refuses the second, so
-- a single player does both parts and the checks that need two say so.)
local function players()
  local c = game.connected_players
  table.sort(c, function(x, y) return x.index < y.index end)
  return c[1], c[2] or c[1]
end
local function shot(p, name, pos, zoom)
  game.take_screenshot{player = p, by_player = p, surface = surface(), position = pos, resolution = {1600, 900},
    zoom = zoom, show_gui = true, path = "lp-mp/" .. name .. ".png"}
end

local steps = {}
function steps.setup()
  game.speed = 1
  for _, e in pairs(surface().find_entities_filtered{force = "enemy", position = {0, 0}, radius = 300}) do e.destroy() end
  lp("debug_tune", {raids_off = true})
  flatten(-60, -80, 60, 30)
  game.forces.player.technologies["lp-command-bandwidth-1"].researched = true
  put("electric-energy-interface", 4, 1)
  put("medium-electric-pole", 2.5, 2.5)
  put("lp-command-relay", 0.5, 6.5)
  put("lp-command-relay", 4.5, 6.5)
  put("medium-electric-pole", 2.5, 5.5)
  S.bk = put("lp-barracks", 0.5, 0.5)
  S.bk.set_recipe("lp-trooper-order")
  S.bk.get_inventory(defines.inventory.crafter_input).insert{name = "firearm-magazine", count = 30}
  S.depot = put("lp-supply-depot", -41, 1)
  S.pole = put("small-electric-pole", -10.5, -30.5)
  S.B = put("lp-rally-beacon", 0.5, -45.5)
  S.T = surface().create_entity{name = "lp-trooper", position = {-1, -47}, force = "player"}
  S.R = surface().create_entity{name = "lp-rocket-trooper", position = {2, -47}, force = "player"}
  lp("debug_enlist", {{-3, -49}, {4, -45}})
  S.foe = surface().create_entity{name = "biter-spawner", position = {0.5, -59}, force = "enemy"}
  local a, b = players()
  if a then a.teleport({-6, -20}) end
  if b then b.teleport({6, -20}) end
  return string.format("setup: players %s, %s", a and a.name or "-", b and b.name or "-")
end
-- Both GUIs at once: a's cards, b's panel and rings.
function steps.gui()
  local a, b = players()
  if not a then return "CHECK BAD gui: no player" end
  lp("debug_select_army", false, a.index)
  b.teleport({3, -42})
  b.opened = S.B
  S.opened_now = b.opened and b.opened.name or "nil"
  lp("debug_hover", b.index, S.bk)
  return "gui: a selected the army, b opened the beacon and hovers the barracks"
end
function steps.read_gui()
  out = {}
  local a, b = players()
  local fa, fb = a.gui.screen.lp_cards, b.gui.screen.lp_cards
  local two = a ~= b
  check(two and "a has its cards, b none" or "the player's cards", fa ~= nil and (not two or fb == nil or not fb.visible),
    string.format("a %s, b %s", tostring(fa and fa.visible), tostring(two and fb and fb.visible)))
  local pa, pb = a.gui.relative.lp_squad, b.gui.relative.lp_squad
  -- (A script cannot open the beacon's window for a client's player, 2026-11-19: opened reads nil at once, so the panel
  -- is left to a person; the check runs if the engine ever lets it.)
  if S.opened_now == "nil" then
    skip("the squad panel", "a script's opened reads nil for a client's player; the panel is a person's to see")
  else
  check(two and "b's squad panel with its ammunition line, a has none" or "the squad panel with its ammunition line",
    pb ~= nil and pb.ammo and pb.ammo.visible and (not two or pa == nil),
    string.format("opened %s, read back at once %s; %s", tostring(b.opened and b.opened.name), S.opened_now, serpent.line(pb and pb.ammo and pb.ammo.caption)))
  end
  local na, nb = rings(a.index), rings(b.index)
  check(two and "the rings are b's alone" or "the rings drawn for the player", nb >= 2 and (not two or na == 0),
    string.format("a %d, b %d", na, nb))
  shot(a, "mp-a-cards", a.position, 0.6)
  shot(b, "mp-b-panel", b.position, 0.6)
  return table.concat(out, "\n")
end
-- Each poll: the spawner healed, and the alerts noted when the trooper goes dry and comes back.
-- Both units drained through the mod's own shot handler: the trooper walks back to the barracks, the rocket trooper,
-- no rockets anywhere, stays dry.
function steps.drain()
  local t = lp("debug_shots", S.T, 100)
  local r = lp("debug_shots", S.R, 10)
  return string.format("drain: trooper %s, rocket %s", tostring(t), tostring(r))
end
function steps.poll()
  if S.foe and S.foe.valid then S.foe.health = S.foe.max_health end
  local a, b = players()
  local t, r = lp("debug_ammo", S.T), lp("debug_ammo", S.R)
  if not (t and r and a and b) then return "poll: -" end
  if t.dry and not S.dry then S.dry = {alerts(a, S.T), alerts(b, S.T)}; shot(a, "mp-a-alert", a.position, 0.5) end
  if S.dry and not t.dry and not S.back then S.back = {alerts(a, S.T), alerts(b, S.T)} end
  if r.dry then S.rdry = {alerts(a, S.R), alerts(b, S.R)} end
  return string.format("poll %d: trooper %s/%s dry %s, rocket dry %s", game.tick, tostring(t.ammo), tostring(t.full),
    tostring(t.dry), tostring(r.dry))
end
function steps.report()
  out = {}
  check("both alerted when the trooper ran dry", S.dry and S.dry[1] >= 1 and S.dry[2] >= 1, serpent.line(S.dry))
  check("both cleared when it rearmed", S.back and S.back[1] == 0 and S.back[2] == 0, serpent.line(S.back))
  check("the stranded rocket trooper's alert kept for both", S.rdry and S.rdry[1] >= 1 and S.rdry[2] >= 1, serpent.line(S.rdry))
  local a, b = players()
  b.opened = nil
  lp("debug_hover", b.index, S.pole)
  check("b's rings gone when it hovers nothing", rings(b.index) == 0, tostring(rings(b.index)))
  return table.concat(out, "\n")
end
remote.add_interface("lp-mp", {step = function(name) return steps[name]() end})
