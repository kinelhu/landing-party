-- The selection's cards (the user, 2026-11-12: "How far could we push unit selection? I mean unit cards with HP
-- overlays?", then "Why not try to get a build going for the morning. Be ambitious"): what the command tool has
-- selected (storage.cmd.selected, command.lua), shown three ways.
--   On the map: a health bar over each selected unit's head (its ring is command.lua's), to its player only.
--   A panel at the bottom of the screen: a card a unit (its icon, a health bar, its rank), or, past CARD_MAX units, a
--     card a kind (how many, their health together). A click narrows the selection: to that unit, or that kind; with
--     SHIFT it drops it instead; a right click follows it in remote view.
--   One unit selected: its own card beside them, the unit itself moving in it, its health, rank, merit and order.
-- Control groups: CONTROL + 1 to 9 keeps the selection as a group, ALT + 1 to 9 selects it again (twice quickly:
-- follows it). A group is unit numbers (veterancy.KEYED: cmd.groups.*.*, so a promoted unit stays in its groups).
-- The model (cards.model) is a function of storage alone, so the scenario reads it headless; the GUI and the bars are
-- drawn from it for connected players.
local shared = require("__landing-party__.shared")
local veterancy = require("__landing-party__.scripts.veterancy")

local cards = {}

local CARD_MAX = 24        -- units shown one card each; past it, a card a kind
local COLUMNS = 12
local REFRESH = 10         -- ticks between refreshes of the bars and the panel's numbers
local RECALL_FOLLOW = 30
local QUICKBAR = 104       -- the bottom of the screen vanilla's quickbar and shortcut bar take, at scale 1   -- ticks within which a second recall of a group follows it
cards.CARD_MAX, cards.REFRESH = CARD_MAX, REFRESH

local function cmd() storage.cmd = storage.cmd or {troopers = {}}; return storage.cmd end

-- The selection's live units, dead ones pruned from it (a selection outlived its units: they kept their numbers in it).
local function live(player_index)
  local c = cmd()
  c.selected = c.selected or {}
  local sel = c.selected[player_index]
  local out = {}
  if not sel then return out end
  for un in pairs(sel) do
    local t = c.troopers[un]
    if t and t.unit.valid then out[#out + 1] = t.unit else sel[un] = nil end
  end
  table.sort(out, function(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.unit_number < b.unit_number
  end)
  return out
end
cards.live = live

local function share(u) return u.max_health > 0 and u.health / u.max_health or 0 end
-- A unit's rounds and its loadout's (0.2.465), or nil: command.ammo_of, set by control.lua as cards.ammo_of (cards does
-- not require command).
local function ammo(u)
  local t = cards.ammo_of and cmd().troopers[u.unit_number]
  if not t then return nil end
  return cards.ammo_of(t)
end
-- The round it holds (0.2.470, ammunition tiers): its item, shown by its icon, never named in our text (the user:
-- "uranium spelled out seems like a misstep, we have item icons"). command.round_of and the ladder's factor, set by
-- control.lua as cards.round_of and cards.round_factor.
local function round(u)
  local t = cards.round_of and cmd().troopers[u.unit_number]
  return t and cards.round_of(t)
end

-- A health share's colour: green, yellow at half, red at a quarter (vanilla's own health bars' steps).
local function hp_colour(s)
  if s > 0.5 then return {r = 0.2, g = 0.85, b = 0.2} end
  if s > 0.25 then return {r = 0.95, g = 0.8, b = 0.1} end
  return {r = 0.95, g = 0.2, b = 0.15}
end
cards.hp_colour = hp_colour
local AMMO_COLOUR = {r = 0.95, g = 0.65, b = 0.1}

-- What the panel shows: {n, grouped, cards = {{kind, name, count, units, health, max_health, share, rank}}, single}.
function cards.model(player_index)
  local units = live(player_index)
  local m = {n = #units, grouped = #units > CARD_MAX, cards = {}}
  if m.grouped then
    local by = {}
    for _, u in ipairs(units) do
      local k = by[u.name]
      if not k then
        k = {kind = "group", name = u.name, count = 0, units = {}, health = 0, max_health = 0, rank = 0, rounds = 0, full = 0}
        by[u.name] = k
        m.cards[#m.cards + 1] = k
      end
      k.count = k.count + 1
      k.units[#k.units + 1] = u
      k.health, k.max_health = k.health + u.health, k.max_health + u.max_health
      k.rank = math.max(k.rank, veterancy.rank(u))
      local have, full = ammo(u)
      if have then
        k.rounds, k.full = k.rounds + have, k.full + full
        local r = round(u)
        if r then k.by_round = k.by_round or {}; k.by_round[r] = (k.by_round[r] or 0) + 1 end
      end
    end
    for _, k in ipairs(m.cards) do
      k.share = k.max_health > 0 and k.health / k.max_health or 0
      k.ammo = k.full > 0 and k.rounds / k.full or nil
      -- (A group's icon is its weakest round: what is left to upgrade; the tooltip counts each.)
      for r in pairs(k.by_round or {}) do
        if not k.round or (cards.round_factor(k.name, r) < cards.round_factor(k.name, k.round)) then k.round = r end
      end
    end
  else
    for _, u in ipairs(units) do
      local have, full = ammo(u)
      m.cards[#m.cards + 1] = {kind = "unit", name = u.name, count = 1, units = {u}, unit_number = u.unit_number,
        health = u.health, max_health = u.max_health, share = share(u), rank = veterancy.rank(u),
        rounds = have, full = full, ammo = have and full > 0 and have / full or nil, round = have and round(u)}
    end
  end
  if #units == 1 then
    local u = units[1]
    local t = cmd().troopers[u.unit_number]
    local order = t and t.manual and t.manual.kind or (t and t.key and t.key:gsub(":.*", "")) or "idle"
    local have, full = ammo(u)
    m.single = {unit = u, rank = veterancy.rank(u), merit = (storage.merit or {})[u.unit_number] or 0,
      order = order, offline = t and t.offline or false, rounds = have, full = full, dry = t and t.dry or false,
      round = have and round(u)}
  end
  return m
end

-- Selecting by hand (a card's click, a group's recall): the same table command.select writes, its rings redrawn by
-- the caller's hook (cards.on_select, set by control.lua to command's).
local function set_selection(player_index, units)
  local c = cmd()
  c.selected = c.selected or {}
  local sel = {}
  for _, u in ipairs(units) do if u.valid and c.troopers[u.unit_number] then sel[u.unit_number] = true end end
  c.selected[player_index] = sel
  if cards.on_select then cards.on_select(player_index) end
  return sel
end

-- A card clicked: narrow the selection to it (its unit, or its kind's units), or with drop, take it out.
function cards.pick(player_index, key, drop)
  local units = live(player_index)
  local keep = {}
  for _, u in ipairs(units) do
    local hit = (type(key) == "number" and u.unit_number == key) or (type(key) == "string" and u.name == key)
    if hit ~= (drop or false) then keep[#keep + 1] = u end
  end
  set_selection(player_index, keep)
  return #keep
end

-- The army panel's buttons (command.lua): every unit of the player's force, or the idle ones (no order by hand, no
-- squad: standing about).
function cards.select_army(player_index, idle_only)
  local p = game.get_player(player_index)
  local force = p and p.force or game.forces.player
  local units = {}
  for _, t in pairs(cmd().troopers) do
    if t.unit.valid and t.unit.force == force and not (idle_only and (t.manual or t.key)) then units[#units + 1] = t.unit end
  end
  set_selection(player_index, units)
  return #units
end

-- Control groups.
function cards.keep_group(player_index, n)
  local c = cmd()
  c.groups = c.groups or {}
  c.groups[player_index] = c.groups[player_index] or {}
  local g = {}
  for _, u in ipairs(live(player_index)) do g[u.unit_number] = true end
  c.groups[player_index][n] = g
  local k = 0
  for _ in pairs(g) do k = k + 1 end
  return k
end

function cards.recall_group(player_index, n, tick)
  local c = cmd()
  local g = c.groups and c.groups[player_index] and c.groups[player_index][n]
  if not g then return 0 end
  local units = {}
  for un in pairs(g) do
    local t = c.troopers[un]
    if t and t.unit.valid then units[#units + 1] = t.unit else g[un] = nil end
  end
  set_selection(player_index, units)
  c.recalled = c.recalled or {}
  local last = c.recalled[player_index]
  c.recalled[player_index] = {n = n, tick = tick or game.tick}
  local follow = last and last.n == n and (tick or game.tick) - last.tick <= RECALL_FOLLOW and units[1] ~= nil
  if follow then cards.follow(player_index, units) end
  return #units, follow
end

-- Remote view on a unit (the group's nearest its middle).
function cards.follow(player_index, units)
  local p = game.get_player(player_index)
  if not (p and p.connected and units[1]) then return end
  local x, y = 0, 0
  for _, u in ipairs(units) do x, y = x + u.position.x, y + u.position.y end
  x, y = x / #units, y / #units
  local best, bd
  for _, u in ipairs(units) do
    local d = (u.position.x - x) ^ 2 + (u.position.y - y) ^ 2
    if not bd or d < bd then best, bd = u, d end
  end
  p.centered_on = best
end

-- The bars over the selected units' heads: two rectangles each, kept in storage.cards.bars[player][unit number].
local BAR_W, BAR_H = 1.0, 0.13
local function bar_geometry(u)
  local sb = u.prototype.selection_box
  local top = (sb.left_top.y or sb.left_top[2]) - 0.25
  local w = math.max(BAR_W, ((sb.right_bottom.x or sb.right_bottom[1]) - (sb.left_top.x or sb.left_top[1])) * 0.9)
  return w, top
end

local function bars_for(player_index, units)
  storage.cards = storage.cards or {bars = {}}
  local all = storage.cards.bars
  local mine = all[player_index] or {}
  all[player_index] = mine
  local p = game.get_player(player_index)
  local seen = {}
  for _, u in ipairs(units) do
    local un = u.unit_number
    seen[un] = true
    local b = mine[un]
    local w, top = bar_geometry(u)
    local s = share(u)
    if not (b and b.bg.valid and b.fg.valid and b.unit == u) then
      if b then if b.bg.valid then b.bg.destroy() end; if b.fg.valid then b.fg.destroy() end end
      local players = p and {player_index} or nil
      b = {unit = u,
        bg = rendering.draw_rectangle{color = {0, 0, 0, 0.75}, filled = true, surface = u.surface, players = players,
          left_top = {entity = u, offset = {-w / 2 - 0.04, top - 0.04}}, right_bottom = {entity = u, offset = {w / 2 + 0.04, top + BAR_H + 0.04}}},
        fg = rendering.draw_rectangle{color = hp_colour(s), filled = true, surface = u.surface, players = players,
          left_top = {entity = u, offset = {-w / 2, top}}, right_bottom = {entity = u, offset = {-w / 2 + w * s, top + BAR_H}}}}
      mine[un] = b
    else
      b.fg.right_bottom = {entity = u, offset = {-w / 2 + w * s, top + BAR_H}}
      b.fg.color = hp_colour(s)
    end
    b.share = s
  end
  for un, b in pairs(mine) do
    if not seen[un] then
      if b.bg.valid then b.bg.destroy() end
      if b.fg.valid then b.fg.destroy() end
      mine[un] = nil
    end
  end
  return mine
end
cards.bars_for = bars_for

-- A hit on one of the player's units: its bar now, for each player who has it selected (control.lua's damage handler).
function cards.on_hit(u)
  local c = storage.cmd
  local bars = storage.cards and storage.cards.bars
  if not (c and c.selected and bars) then return end
  local un = u.unit_number
  for pi, sel in pairs(c.selected) do
    local b = sel[un] and bars[pi] and bars[pi][un]
    if b and b.fg.valid and b.unit == u then
      local w, top = bar_geometry(u)
      local s = share(u)
      b.fg.right_bottom = {entity = u, offset = {-w / 2 + w * s, top + BAR_H}}
      b.fg.color = hp_colour(s)
      b.share = s
    end
  end
end

-- The panel.
local function rank_text(r)
  if r < 1 then return "" end
  return "[img=lp-rank-" .. r .. "]"
end

local function signature(m)
  local s = {m.grouped and "g" or "u"}
  for _, c in ipairs(m.cards) do s[#s + 1] = (c.unit_number or c.name) .. ":" .. c.count .. ":" .. c.rank end
  return table.concat(s, ",")
end

local function card_tooltip(c)
  local name = prototypes.entity[c.name].localised_name
  if c.kind == "group" then
    local tip = {"lp.card-group-tooltip", name, c.count, math.floor(c.health + 0.5), math.floor(c.max_health + 0.5)}
    if not c.by_round then return tip end
    local rounds = {""}
    for r, n in pairs(c.by_round) do rounds[#rounds + 1] = string.format("  [item=%s] %d", r, n) end
    return {"", tip, "\n", rounds}
  end
  return {"lp.card-unit-tooltip", name, math.floor(c.health + 0.5), math.floor(c.max_health + 0.5), rank_text(c.rank)}
end

local function build(p, m)
  local old = p.gui.screen.lp_cards
  if old then old.destroy() end
  if m.n == 0 then return end
  local frame = p.gui.screen.add{type = "frame", name = "lp_cards", direction = "horizontal"}
  frame.style.padding = 6
  local left = frame.add{type = "flow", name = "lp_cards_left", direction = "vertical"}
  left.add{type = "label", name = "lp_cards_title", style = "caption_label",
    caption = m.grouped and {"lp.cards-title-grouped", m.n, #m.cards} or {"lp.cards-title", m.n}}
  local grid = left.add{type = "table", name = "lp_cards_grid", column_count = COLUMNS}
  grid.style.horizontal_spacing, grid.style.vertical_spacing = 4, 4
  for i, c in ipairs(m.cards) do
    local f = grid.add{type = "flow", name = "lp_card_" .. i, direction = "vertical"}
    f.style.vertical_spacing = 1
    local b = f.add{type = "sprite-button", name = "lp_card_button", style = "slot_button", sprite = "entity/" .. c.name,
      number = c.kind == "group" and c.count or nil, tooltip = card_tooltip(c),
      tags = {lp_card = c.unit_number or c.name}}
    b.style.size = 40
    local bar = f.add{type = "progressbar", name = "lp_card_hp", style = "lp_card_hp_bar", value = c.share}
    bar.style.color = hp_colour(c.share)
    -- (Its ammunition under its health, 0.2.465: amber, red when out; none for a unit that keeps no rounds.)
    -- (Its round's icon before the bar, 0.2.470.)
    local row = f.add{type = "flow", name = "lp_card_ammo_row", direction = "horizontal"}
    row.style.horizontal_spacing = 1
    row.style.vertical_align = "center"
    local ri = row.add{type = "sprite", name = "lp_card_round", sprite = c.round and ("item/" .. c.round) or nil}
    ri.style.size = 9
    ri.style.stretch_image_to_widget_size = true
    local am = row.add{type = "progressbar", name = "lp_card_ammo", style = "lp_card_hp_bar", value = c.ammo or 0}
    am.style.width = 30
    am.style.color = AMMO_COLOUR
    row.visible = c.ammo ~= nil
    -- (Its rank: the unit's own gold chevrons, inside the button's corner. A label under it with a negative margin
    -- pushed the card out of its row, 2026-11-12.)
    if c.rank > 0 then
      local r = b.add{type = "sprite", name = "lp_card_rank", sprite = "lp-rank-" .. c.rank}
      r.style.size = 16
      r.style.stretch_image_to_widget_size = true
      r.ignored_by_interaction = true
    end
  end
  if m.single then
    local s = m.single
    local pane = frame.add{type = "frame", name = "lp_cards_single", direction = "horizontal", style = "inside_shallow_frame"}
    pane.style.padding = 4
    local prev = pane.add{type = "entity-preview", name = "lp_cards_preview"}
    prev.style.size = 96
    prev.entity = s.unit
    local info = pane.add{type = "flow", name = "lp_cards_info", direction = "vertical"}
    info.style.left_margin = 6
    info.add{type = "label", name = "lp_cards_name", style = "heading_2_label", caption = s.unit.localised_name}
    info.add{type = "label", name = "lp_cards_health"}
    local ar = info.add{type = "flow", name = "lp_cards_ammo_row", direction = "horizontal"}
    ar.style.vertical_align = "center"
    local ri = ar.add{type = "sprite", name = "lp_cards_round"}
    ri.style.size = 16
    ri.style.stretch_image_to_widget_size = true
    ar.add{type = "label", name = "lp_cards_ammo"}
    info.add{type = "label", name = "lp_cards_rank"}
    info.add{type = "label", name = "lp_cards_order"}
  end
  return frame
end

local function grid_of(frame) return frame.lp_cards_left.lp_cards_grid end

local function update(frame, m)
  local grid = grid_of(frame)
  for i, c in ipairs(m.cards) do
    local f = grid["lp_card_" .. i]
    -- (A card built before 0.2.470 has no ammunition row: left as it is until the next selection rebuilds it.)
    if f and f.lp_card_ammo_row then
      f.lp_card_hp.value = c.share
      f.lp_card_hp.style.color = hp_colour(c.share)
      local row = f.lp_card_ammo_row
      row.lp_card_ammo.value = c.ammo or 0
      row.lp_card_round.sprite = c.round and ("item/" .. c.round) or nil
      row.visible = c.ammo ~= nil
      f.lp_card_button.tooltip = card_tooltip(c)
    end
  end
  local pane = frame.lp_cards_single
  if pane and m.single then
    local s, info = m.single, pane.lp_cards_info
    info.lp_cards_health.caption = {"lp.card-health", math.floor(s.unit.health + 0.5), math.floor(s.unit.max_health + 0.5)}
    local ar = info.lp_cards_ammo_row or {lp_cards_ammo = {}, lp_cards_round = {}}
    ar.lp_cards_ammo.caption = s.rounds and (s.dry and {"lp.card-ammo-dry"} or {"lp.card-ammo", s.rounds, s.full}) or ""
    ar.lp_cards_round.sprite = s.round and ("item/" .. s.round) or nil
    ar.lp_cards_round.tooltip = s.round and prototypes.item[s.round].localised_name or nil
    ar.visible = s.rounds ~= nil
    info.lp_cards_rank.caption = s.rank > 0 and {"lp.card-rank", rank_text(s.rank), {"lp.rank-" .. s.rank}, s.merit}
      or {"lp.card-merit", s.merit}
    info.lp_cards_order.caption = s.offline and {"lp.card-offline"} or {"lp.card-order-" .. s.order}
  end
end

local ORDERS_SHOWN = {move = true, attack = true, attackmove = true, idle = true, rearm = true, dry = true}

-- Everything for one player, now.
function cards.refresh(player_index)
  local m = cards.model(player_index)
  if m.single and not ORDERS_SHOWN[m.single.order] then m.single.order = "squad" end
  local units = {}
  for _, c in ipairs(m.cards) do for _, u in ipairs(c.units) do units[#units + 1] = u end end
  bars_for(player_index, units)
  -- (The rings again when the selection's units are not the ones they were drawn on: a promotion's copy has a new number
  -- and stood without its ring, 2026-11-12; a death too.)
  storage.cards = storage.cards or {bars = {}}
  storage.cards.ringed = storage.cards.ringed or {}
  local nums = {}
  for _, u in ipairs(units) do nums[#nums + 1] = u.unit_number end
  table.sort(nums)
  local key = table.concat(nums, ",")
  if storage.cards.ringed[player_index] ~= key then
    storage.cards.ringed[player_index] = key
    if cards.on_select then cards.on_select(player_index) end
  end
  local p = game.get_player(player_index)
  if not (p and p.connected) then return m end
  storage.cards = storage.cards or {bars = {}}
  storage.cards.sig = storage.cards.sig or {}
  local sig = signature(m)
  local frame = p.gui.screen.lp_cards
  if sig ~= storage.cards.sig[player_index] or (m.n > 0) ~= (frame ~= nil) then
    storage.cards.sig[player_index] = sig
    frame = build(p, m)
  end
  if frame and frame.valid then
    update(frame, m)
    local res, scale = p.display_resolution, p.display_scale
    local grid = grid_of(frame)
    local cols = math.min(COLUMNS, math.max(1, #grid.children))
    local rows = math.ceil(#grid.children / COLUMNS)
    local w = (cols * 44 + 20) * scale + (frame.lp_cards_single and 300 * scale or 0)
    local h = (rows * 50 + 40) * scale
    if frame.lp_cards_single then h = math.max(h, 124 * scale) end
    -- (Above vanilla's quickbar and shortcut bar, which take the bottom 100 at scale 1: on them, it hid both.)
    frame.location = {x = math.floor((res.width - w) / 2), y = math.floor(res.height - h - QUICKBAR * scale)}
  end
  return m
end

function cards.tick(tick)
  if tick % REFRESH ~= 3 then return end
  local c = storage.cmd
  if not (c and c.selected) then return end
  for pi in pairs(c.selected) do cards.refresh(pi) end
end

function cards.on_click(e)
  local el = e.element
  if not (el and el.valid and el.tags and el.tags.lp_card) then return false end
  local key = el.tags.lp_card
  if e.button == defines.mouse_button_type.right then
    local units = {}
    for _, u in ipairs(live(e.player_index)) do
      if (type(key) == "number" and u.unit_number == key) or (type(key) == "string" and u.name == key) then units[#units + 1] = u end
    end
    cards.follow(e.player_index, units)
  elseif e.control and type(key) == "number" then
    local t = cmd().troopers[key]
    if t and t.unit.valid then cards.pick(e.player_index, t.unit.name, false) end
  else
    cards.pick(e.player_index, key, e.shift)
  end
  cards.refresh(e.player_index)
  return true
end

function cards.on_display_changed(e) if storage.cards and storage.cards.sig then storage.cards.sig[e.player_index] = nil end; cards.refresh(e.player_index) end

-- The groups' keys (player.lua's custom inputs): lp-group-keep-N and lp-group-N.
cards.GROUPS = 9

return cards
