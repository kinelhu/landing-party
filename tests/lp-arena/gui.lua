-- The arena in game (scripts/play-arena.sh): a panel to set up a fight by hand and watch it. Each side is a list of
-- entries (who, what, how many); Fight clears the pen and starts it; the status line follows it. Element names carry the
-- lpa_ prefix (a name clashing with a LuaGuiElement member breaks the panel).
local arena = require("arena")

local gui = {}

local PEN = {0, 0}
local WHO = {"serenity", "grubstake", "player", "biters"}
local WHO_LABEL = {"Serenity", "Grubstake", "You", "Biters"}

local function kinds(who)
  if who == "serenity" or who == "grubstake" then return arena.corp_kinds(who) end
  if who == "player" then
    local out = {}
    for _, k in ipairs(arena.PLAYER_UNITS) do table.insert(out, k) end
    for _, k in ipairs({"guns", "lasers", "flamers", "walls"}) do table.insert(out, k) end
    return out
  end
  local out = {"wave"}
  for _, k in ipairs(arena.BITERS) do table.insert(out, k) end
  return out
end

local function caption(who, kind)
  if who == "player" and arena.LINES[kind] then return arena.LINES[kind] end
  if who == "biters" and kind == "wave" then return "a wave (spawners' mix at the evolution)" end
  return kind
end

local function state(player)
  storage.gui = storage.gui or {}
  local s = storage.gui[player.index]
  if not s then
    s = {sides = {a = {}, b = {}}, pick = {a = {who = 1, kind = 1}, b = {who = 4, kind = 1}}, evo = 0.5}
    storage.gui[player.index] = s
  end
  return s
end

local function side_flow(parent, s, key, title)
  local col = parent.add{type = "frame", name = "lpa_side_" .. key, direction = "vertical", style = "inside_shallow_frame_with_padding"}
  col.add{type = "label", caption = title, style = "caption_label"}
  local pick = s.pick[key]
  local row = col.add{type = "flow", direction = "horizontal"}
  row.add{type = "drop-down", name = "lpa_who_" .. key, items = WHO_LABEL, selected_index = pick.who}
  local ks = kinds(WHO[pick.who])
  local items = {}
  for _, k in ipairs(ks) do table.insert(items, caption(WHO[pick.who], k)) end
  if pick.kind > #ks then pick.kind = 1 end
  row.add{type = "drop-down", name = "lpa_kind_" .. key, items = items, selected_index = pick.kind}
  local row2 = col.add{type = "flow", direction = "horizontal"}
  row2.add{type = "textfield", name = "lpa_n_" .. key, text = tostring(pick.n or 5), numeric = true, style = "short_number_textfield"}
  row2.add{type = "button", name = "lpa_add_" .. key, caption = "Add"}
  row2.add{type = "button", name = "lpa_empty_" .. key, caption = "Empty"}
  for _, en in ipairs(s.sides[key]) do
    local extra = en[1] == "biters" and en[2] == "wave" and string.format(" at %.2f", en[4]) or ""
    col.add{type = "label", caption = string.format("%d x %s (%s)%s", en[3], caption(en[1], en[2]), en[1], extra)}
  end
end

function gui.build(player)
  local s = state(player)
  if player.gui.screen.lpa_frame then player.gui.screen.lpa_frame.destroy() end
  local frame = player.gui.screen.add{type = "frame", name = "lpa_frame", caption = "Arena", direction = "vertical"}
  frame.location = {20, 80}
  local sides = frame.add{type = "flow", direction = "horizontal"}
  side_flow(sides, s, "a", "West")
  side_flow(sides, s, "b", "East")
  local row = frame.add{type = "flow", direction = "horizontal"}
  row.add{type = "label", caption = "Biters' evolution"}
  row.add{type = "textfield", name = "lpa_evo", text = tostring(s.evo), numeric = true, allow_decimal = true,
    style = "short_number_textfield"}
  row.add{type = "button", name = "lpa_fight", caption = "Fight", style = "confirm_button"}
  row.add{type = "button", name = "lpa_clear", caption = "Clear the pen"}
  frame.add{type = "label", name = "lpa_status", caption = s.status or "Set up both sides, then Fight."}
end

local function read_pick(player, key)
  local s = state(player)
  local f = player.gui.screen.lpa_frame
  local col = f and f.children[1]["lpa_side_" .. key]
  if not col then return end
  local pick = s.pick[key]
  for _, el in pairs(col.children) do
    for _, c in pairs(el.children) do
      if c.name == "lpa_n_" .. key then pick.n = tonumber(c.text) or 5 end
    end
  end
  local evo = f.children[2].lpa_evo
  s.evo = math.max(0, math.min(1, tonumber(evo and evo.text) or s.evo))
end

function gui.on_click(e)
  local el, player = e.element, game.get_player(e.player_index)
  if not (el and el.valid and el.name:sub(1, 4) == "lpa_") then return end
  local s = state(player)
  local key = el.name:sub(-1)
  if el.name:find("^lpa_add_") then
    read_pick(player, key)
    local pick = s.pick[key]
    local who = WHO[pick.who]
    local kind = kinds(who)[pick.kind]
    table.insert(s.sides[key], {who, kind, math.max(1, math.min(500, pick.n or 5)), s.evo})
  elseif el.name:find("^lpa_empty_") then
    s.sides[key] = {}
  elseif el.name == "lpa_fight" then
    read_pick(player, "a"); read_pick(player, "b")
    for _, en in ipairs(s.sides.a) do if en[1] == "biters" then en[4] = en[4] or s.evo end end
    storage.fight = arena.start(PEN, s.sides.a, s.sides.b, "by hand")
    s.status = "Fighting..."
  elseif el.name == "lpa_clear" then
    arena.clear(PEN, 90)
    storage.fight = nil
    s.status = "Pen cleared."
  else
    return
  end
  gui.build(player)
end

function gui.on_selection(e)
  local el, player = e.element, game.get_player(e.player_index)
  if not (el and el.valid and el.name:sub(1, 4) == "lpa_") then return end
  local s = state(player)
  local key = el.name:sub(-1)
  if el.name:find("^lpa_who_") then s.pick[key].who, s.pick[key].kind = el.selected_index, 1
  elseif el.name:find("^lpa_kind_") then s.pick[key].kind = el.selected_index
  else return end
  read_pick(player, key)
  gui.build(player)
end

-- Once a second: the fight's step and the status line.
function gui.tick()
  local f = storage.fight
  if not f or game.tick % 60 ~= 0 then return end
  local done = arena.step(f)
  local text
  if done then
    local r = f.result
    local who = r.winner == "a" and "West wins" or r.winner == "b" and "East wins" or "A draw"
    text = string.format("%s after %.0f s. West: %d of %d left (%d parts lost). East: %d of %d left (%d parts lost).", who,
      r.seconds, r.a.left, r.a.start, r.a.parts_lost, r.b.left, r.b.start, r.b.parts_lost)
    storage.fight = nil
  else
    local function n(side) local k = 0 for _, u in ipairs(side.units) do if u.valid then k = k + 1 end end return k end
    text = string.format("%.0f s: West %d, East %d", (game.tick - f.started) / 60, n(f.a), n(f.b))
  end
  for _, p in pairs(game.players) do
    local s = state(p)
    s.status = text
    local fr = p.gui.screen.lpa_frame
    if fr and fr.lpa_status then fr.lpa_status.caption = text end
  end
end

-- A player arrives in the arena: no body, free to fly over the pen, the panel open.
function gui.welcome(player)
  arena.ground(PEN, 4)
  player.set_controller{type = defines.controllers.god}
  player.teleport({PEN[1], PEN[2] - 10}, arena.SURFACE)
  player.zoom = 0.6
  gui.build(player)
end

return gui
