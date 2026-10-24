-- The arena in game (scripts/play-arena.sh): a panel to set up a fight by hand and watch it. Each side is a list of
-- entries (who, what, how many); Fight clears the pen and starts it; the status line follows it. Element names carry the
-- lpa_ prefix (a name clashing with a LuaGuiElement member breaks the panel).
local arena = require("arena")

local gui = {}

local PEN = {0, 0}
local shared = require("__landing-party__.shared")
local WHO = {"serenity", "grubstake", "biotech", "player", "biters"}
local WHO_LABEL = {"Kessler-Hayashi", "Grubstake Inc.", "Synthexis", "You", "Biters"}

local function kinds(who)
  if who == "serenity" or who == "grubstake" then return arena.fielded(who) end
  if who == "biotech" then
    -- Its breeds (shared.BREEDS), at their arena prices.
    local out = {}
    for name in pairs(shared.BREEDS) do if prototypes.entity[name] then table.insert(out, name) end end
    table.sort(out, function(x, y) return shared.BREEDS[x].cost < shared.BREEDS[y].cost end)
    return out
  end
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
  -- Units by their names in game.
  local name = (who == "serenity" or who == "grubstake") and shared.variant(who, kind) or kind
  local p = prototypes.entity[name]
  return p and p.localised_name or kind
end

-- Each unit's numbers (scripts/arena_stats.py, from the prototypes) and the matchup worked out from them.
local STATS = require("stats")
local TYPE_LABEL = {["lp-bite"] = "bite", ["lp-rail"] = "rail"}

local function proto_of(who, kind)
  if (who == "player" and arena.LINES[kind]) or kind == "wave" then return nil end
  if who == "serenity" or who == "grubstake" then return shared.variant(who, kind) end
  return kind
end

-- The engine's rule: the flat part first (a hit no bigger than it still does 1 / (2 + flat - hit)), then the percent.
local function after(amount, typ, resist)
  local r = resist[typ]
  if not r then return amount end
  local a = amount > r[1] and amount - r[1] or 1 / (2 + r[1] - amount)
  return a * (1 - r[2] / 100)
end

local function shot_text(st)
  local parts = {}
  for _, h in ipairs(st.hits) do
    parts[#parts + 1] = string.format("%g %s%s%s%s", h.amount, TYPE_LABEL[h.type] or h.type, h.rep > 1 and (" x" .. h.rep) or "",
      h.area > 0 and string.format(" over %g tiles", h.area) or "", h.buildings and " (buildings)" or "")
  end
  return #parts > 0 and table.concat(parts, ", ") or "none"
end

local function resist_text(st)
  local parts = {}
  for typ, r in pairs(st.resist) do
    if r[1] ~= 0 or r[2] ~= 0 then
      parts[#parts + 1] = (TYPE_LABEL[typ] or typ) .. " " .. (r[1] ~= 0 and string.format("%g flat", r[1]) or "")
        .. (r[1] ~= 0 and r[2] ~= 0 and " + " or "") .. (r[2] ~= 0 and string.format("%g%%", r[2]) or "")
    end
  end
  table.sort(parts)
  return #parts > 0 and table.concat(parts, ", ") or "none"
end

-- What one of `a`'s shots does to `b`, what a second of fire does, and how long n of them take to kill one.
local function matchup(a, b, n)
  local per = 0
  for _, h in ipairs(a.hits) do if not h.buildings then per = per + after(h.amount, h.type, b.resist) * h.rep end end
  local dps = per * a.rate
  local t = dps > 0 and b.health / (dps * math.max(1, n)) or nil
  return per, dps, t
end

local function who_label(who)
  if who == "raw" then return "Synthexis" end
  for i, w in ipairs(WHO) do if w == who then return WHO_LABEL[i] end end
  return who
end

local function state(player)
  storage.gui = storage.gui or {}
  local s = storage.gui[player.index]
  if not s then
    s = {sides = {a = {}, b = {}}, pick = {a = {who = 1, kind = 1}, b = {who = 5, kind = 1}}, evo = 0.5}
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
  -- The picked unit's numbers.
  local name = proto_of(WHO[pick.who], ks[pick.kind])
  local st = name and STATS[name]
  if st then
    local box = col.add{type = "frame", direction = "vertical", style = "deep_frame_in_shallow_frame"}
    box.style.padding = 6
    box.add{type = "label", caption = string.format("Health %g   speed %g tiles/s   range %g   %g shots/s", st.health, st.speed,
      st.range, st.rate)}
    box.add{type = "label", caption = "A shot: " .. shot_text(st)}
    box.add{type = "label", caption = "Resists: " .. resist_text(st)}
  end
  for _, en in ipairs(s.sides[key]) do
    local extra = en[1] == "biters" and en[2] == "wave" and string.format(" at %.2f", en[4]) or ""
    col.add{type = "label", caption = {"", en[3], " x ", caption(en[1], en[2]), " (", who_label(en[1]), ")", extra}}
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
  -- The matchup of the two picked units, each way.
  local na = proto_of(WHO[s.pick.a.who], kinds(WHO[s.pick.a.who])[s.pick.a.kind])
  local nb = proto_of(WHO[s.pick.b.who], kinds(WHO[s.pick.b.who])[s.pick.b.kind])
  if na and nb and STATS[na] and STATS[nb] then
    local m = frame.add{type = "frame", direction = "vertical", style = "inside_shallow_frame_with_padding"}
    m.add{type = "label", caption = "Picked against picked (one shot, before research):", style = "caption_label"}
    for _, way in ipairs({{na, nb, s.pick.a.n or 5, "West"}, {nb, na, s.pick.b.n or 5, "East"}}) do
      local per, dps, t = matchup(STATS[way[1]], STATS[way[2]], way[3])
      m.add{type = "label", caption = {"", way[4], "'s ", prototypes.entity[way[1]].localised_name, " on ",
        prototypes.entity[way[2]].localised_name, string.format(": %.2f a shot after its resistances, %.2f a second; ", per, dps),
        not t and "it cannot hurt it" or way[3] <= 1 and string.format("one kills one in %.0f s", t)
          or string.format("%d of them kill one in %.0f s", way[3], t)}}
    end
  end
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
    local n = math.max(1, math.min(500, pick.n or 5))
    -- Synthexis's breeds go in as raw prototypes on its force (arena.lua's spawn).
    table.insert(s.sides[key], who == "biotech" and {"raw", kind, n, shared.BIOTECH.force} or {who, kind, n, s.evo})
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

-- The GUI test (scripts/arena-gui.sh): every side's every pick built against a burster (an error is written, not
-- raised), then ten of your troopers against one burster, the panel's text and a screenshot with the GUI written.
local function captions(el, out)
  if el.type == "label" then out[#out + 1] = type(el.caption) == "table" and serpent.line(el.caption) or tostring(el.caption) end
  for _, c in pairs(el.children) do captions(c, out) end
  return out
end

local function index_of(list, v) for i, x in ipairs(list) do if x == v then return i end end end

function gui.test_tick(tick)
  local p = game.get_player(1)
  if not p or not p.connected then return end
  storage.test = storage.test or {start = tick}
  local t = tick - storage.test.start
  local s = state(p)
  if t == 30 then
    local errors, built = {}, 0
    for w = 1, #WHO do
      for k = 1, #kinds(WHO[w]) do
        s.pick.a = {who = w, kind = k, n = 5}
        s.pick.b = {who = 3, kind = index_of(kinds("biotech"), "lp-bred-cinder") or 1, n = 1}
        local ok, err = pcall(gui.build, p)
        if ok then built = built + 1 else errors[#errors + 1] = WHO[w] .. " " .. tostring(kinds(WHO[w])[k]) .. ": " .. err end
      end
    end
    helpers.write_file("lp-arena/gui.txt", string.format("built %d panels, %d errors\n%s\n", built, #errors,
      table.concat(errors, "\n")))
    s.pick.a = {who = 4, kind = index_of(kinds("player"), "lp-trooper") or 1, n = 10}
    s.pick.b = {who = 3, kind = index_of(kinds("biotech"), "lp-bred-cinder") or 1, n = 1}
    gui.build(p)
  elseif t == 90 then
    helpers.write_file("lp-arena/gui.txt", table.concat(captions(p.gui.screen.lpa_frame, {}), "\n") .. "\n", true)
    game.take_screenshot{player = p, show_gui = true, path = "lp-arena/panel.png", resolution = {1600, 1000}}
  elseif t == 180 then
    helpers.write_file("lp-arena/done.txt", "done\n")
  end
end

return gui
