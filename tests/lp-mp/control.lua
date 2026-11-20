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

-- Ammunition tiers (scripts/mp.sh LP_ARMY=1 LP_TIERS=1, 0.2.470): what only a player sees. A uranium trooper, a yellow
-- one and a uranium gun buggy deployed through the barracks (each order under its own recipe), at a beacon with a depot
-- holding uranium. The cards' round icons, the single pane's, the alt-mode icon over each unit; the yellow trooper
-- drained by the depot reloads uranium and its icon turns; the depot emptied, the gun buggy drained is stranded (the
-- barracks' yellow is not its round) and alerted, its alert's icon its round. Screenshots for a person to judge.
local ORDERS = {"lp-trooper-order-uranium", "lp-trooper-order", "lp-gun-buggy-order-uranium"}
function steps.tsetup()
  game.speed = 1
  for _, e in pairs(surface().find_entities_filtered{force = "enemy", position = {0, 0}, radius = 300}) do e.destroy() end
  lp("debug_tune", {raids_off = true})
  flatten(-60, -80, 60, 30)
  local f = game.forces.player
  f.technologies["lp-command-bandwidth-1"].researched = true
  f.technologies["uranium-ammo"].researched = true
  f.technologies["lp-command-bandwidth-2"].researched = true
  put("electric-energy-interface", 4, 1)
  put("medium-electric-pole", 2.5, 2.5)
  for i, x in ipairs({0.5, 4.5, 8.5}) do put("lp-command-relay", x, 6.5) end
  put("medium-electric-pole", 2.5, 5.5)
  put("medium-electric-pole", 6.5, 5.5)
  S.bk = put("lp-barracks", 0.5, 0.5)
  S.B = put("lp-rally-beacon", 0.5, -45.5)
  S.D = put("lp-supply-depot", 6, -45)
  S.D.get_inventory(defines.inventory.chest).insert{name = "uranium-rounds-magazine", count = 20}
  local a = players()
  if a then a.teleport({0, -38}) end
  return string.format("tsetup: player %s (index %s); recipes uranium trooper %s, uranium buggy %s", a and a.name or "-",
    a and a.index or "-", tostring(f.recipes["lp-trooper-order-uranium"].enabled), tostring(f.recipes["lp-gun-buggy-order-uranium"].enabled))
end
for i, n in ipairs(ORDERS) do
  steps["tdeploy" .. i] = function()
    S.bk.set_recipe(n)
    S.bk.get_inventory(defines.inventory.crafter_output).insert{name = n, count = 1}
    if n == "lp-trooper-order" then S.bk.get_inventory(defines.inventory.crafter_input).insert{name = "firearm-magazine", count = 30} end
    return "tdeploy " .. n
  end
end
local function who()
  for _, u in ipairs(surface().find_entities_filtered{force = "player", name = {"lp-trooper", "lp-gun-buggy"}}) do
    local a = lp("debug_ammo", u)
    if a then
      if u.name == "lp-gun-buggy" then S.GB = u elseif a.round == "uranium-rounds-magazine" then S.TU = u else S.TY = u end
    end
  end
end
local function centre()
  local xs, ys, n = 0, 0, 0
  for _, u in ipairs({S.TU, S.TY, S.GB}) do if u and u.valid then xs, ys, n = xs + u.position.x, ys + u.position.y, n + 1 end end
  return n > 0 and {xs / n, ys / n} or {0, -45}
end
function steps.tcards()
  who()
  local a = players()
  a.teleport({centre()[1], centre()[2] + 8})
  lp("debug_select_army", false, a.index)
  return string.format("tcards: units %s %s %s", tostring(S.TU and S.TU.valid), tostring(S.TY and S.TY.valid), tostring(S.GB and S.GB.valid))
end
local function card_rounds(p)
  local f = p.gui.screen.lp_cards
  local grid = f and f.lp_cards_left and f.lp_cards_left.lp_cards_grid
  local out = {}
  for _, c in ipairs(grid and grid.children or {}) do
    local row = c.lp_card_ammo_row
    out[#out + 1] = row and (tostring(row.lp_card_round.sprite) .. (row.visible and "" or "(hidden)")) or "no row"
  end
  return out
end
function steps.tcards_read()
  out = {}
  local a = players()
  local r = card_rounds(a)
  local n = {}
  for _, s in ipairs(r) do n[s] = (n[s] or 0) + 1 end
  check("tiers: each card's round icon before its bar", #r == 3 and n["item/uranium-rounds-magazine"] == 2
    and n["item/firearm-magazine"] == 1, serpent.line(r))
  shot(a, "tiers-cards", a.position, 1)
  return table.concat(out, "\n")
end
function steps.tsingle()
  local a = players()
  lp("debug_select_units", {S.TU}, a.index)
  return "tsingle: the uranium trooper selected"
end
function steps.tsingle_read()
  out = {}
  local a = players()
  local f = a.gui.screen.lp_cards
  local ar = f and f.lp_cards_single and f.lp_cards_single.lp_cards_info.lp_cards_ammo_row
  check("tiers: the single pane's round icon beside its line", ar and ar.visible and ar.lp_cards_round.sprite == "item/uranium-rounds-magazine",
    ar and serpent.line({ar.lp_cards_round.sprite, ar.lp_cards_ammo.caption}) or "no pane")
  shot(a, "tiers-single", a.position, 1)
  return table.concat(out, "\n")
end
local function marks()
  local m = {}
  for _, o in pairs(rendering.get_all_objects("landing-party")) do
    if o.valid and o.type == "sprite" and o.only_in_alt_mode and o.target and o.target.entity then
      local e = o.target.entity
      if e == S.TU then m.tu = o.sprite elseif e == S.TY then m.ty = o.sprite elseif e == S.GB then m.gb = o.sprite end
    end
  end
  return m
end
function steps.talt()
  out = {}
  local a = players()
  lp("debug_select_units", {}, a.index)
  a.game_view_settings.show_entity_info = true
  local m = marks()
  check("tiers: an alt-mode icon over each unit, its round", m.tu == "item/uranium-rounds-magazine" and m.ty == "item/firearm-magazine"
    and m.gb == "item/uranium-rounds-magazine", serpent.line(m))
  local c = centre()
  game.take_screenshot{player = a, by_player = a, surface = surface(), position = c, resolution = {1600, 900}, zoom = 2,
    show_gui = false, show_entity_info = true, path = "lp-mp/tiers-alt.png"}
  game.take_screenshot{player = a, by_player = a, surface = surface(), position = c, resolution = {800, 500}, zoom = 4,
    show_gui = false, show_entity_info = true, path = "lp-mp/tiers-alt-crop.png"}
  return table.concat(out, "\n")
end
-- The yellow trooper drained by the depot (uranium only): it loads uranium; its icon turns on the next lead pass.
function steps.tdrain()
  local a = lp("debug_ammo", S.TY)
  local r = lp("debug_shots", S.TY, a.ammo)
  S.ty_now = lp("debug_ammo", S.TY)
  return "tdrain: " .. serpent.line({r, S.ty_now and S.ty_now.round})
end
function steps.treload_read()
  out = {}
  local a = players()
  local m = marks()
  check("tiers: the yellow trooper reloaded uranium by the depot, its icon turned", S.ty_now and S.ty_now.round == "uranium-rounds-magazine"
    and m.ty == "item/uranium-rounds-magazine", serpent.line({S.ty_now and S.ty_now.round, m.ty}))
  game.take_screenshot{player = a, by_player = a, surface = surface(), position = centre(), resolution = {800, 500}, zoom = 4,
    show_gui = false, show_entity_info = true, path = "lp-mp/tiers-reload-crop.png"}
  return table.concat(out, "\n")
end
-- The depot emptied, the gun buggy drained: no source holds its rounds (the barracks' yellow is not one), it stands dry.
function steps.tstrand()
  S.D.get_inventory(defines.inventory.chest).clear()
  local a = lp("debug_ammo", S.GB)
  lp("debug_shots", S.GB, a.ammo)
  return "tstrand: " .. serpent.line(lp("debug_ammo", S.GB))
end
function steps.tstrand_read()
  out = {}
  local a = players()
  local g = lp("debug_ammo", S.GB)
  local icons = {}
  for _, by_type in pairs(a.get_alerts{entity = S.GB, type = defines.alert_type.custom}) do
    for _, list in pairs(by_type) do for _, al in ipairs(list) do icons[#icons + 1] = al.icon and al.icon.name or "?" end end
  end
  check("tiers: the stranded gun buggy is dry and alerted, the alert's icon its round", g and g.dry and #icons >= 1
    and icons[1] == "uranium-rounds-magazine", serpent.line({g and g.dry, icons}))
  shot(a, "tiers-alert", a.position, 1)
  a.game_view_settings.show_entity_info = false
  return table.concat(out, "\n")
end
remote.add_interface("lp-mp", {step = function(name) return steps[name]() end})
