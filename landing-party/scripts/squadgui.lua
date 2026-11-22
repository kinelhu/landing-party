-- Which units are whose (the user, 2026-11-16: "+ a UI layer for what units belong to what beacon?").
--   Hover links: a rally beacon under the cursor draws a line from it to each unit of its squad; a unit of the army
--   under the cursor, one to its beacon. Drawn for that player alone, gone when the cursor moves on.
--   The squad panel: beside a rally beacon's own window, its stance in words and what a defending squad is answering,
--   and its squad by unit, how many against its squad size, with buttons that write the squad size signals into the
--   beacon's own section (so the panel is the circuit's front end, not a second system; wired, the network sets them
--   and the buttons are off). Lowering one beacon's size and raising another's moves units between them
--   (command.lua enforce).
local shared = require("__landing-party__.shared")
local command = require("__landing-party__.scripts.command")

local gui = {}
local NAME = "lp_squad"
local BEACON = "lp-rally-beacon"
local LINK = {hold = {0.8, 0.8, 0.8, 0.5}, advance = {1, 0.3, 0.15, 0.7},
  retreat = {0.3, 0.5, 1, 0.7}, defend = {0.25, 0.85, 0.45, 0.7}}
-- Units in the panel's order (shared.ORDERS is a map).
local UNITS = {}
for _, name in pairs(shared.ORDERS) do UNITS[#UNITS + 1] = name end
table.sort(UNITS, function(a, b) return (shared.POPULATION[a] or 1) < (shared.POPULATION[b] or 1)
  or ((shared.POPULATION[a] or 1) == (shared.POPULATION[b] or 1) and a < b) end)

-- Hover links ----------------------------------------------------------------------------------------------------------

local function clear_links(pi)
  storage.squad_links = storage.squad_links or {}
  for _, r in ipairs(storage.squad_links[pi] or {}) do if r.valid then r.destroy() end end
  storage.squad_links[pi] = nil
end

-- The generators a held lander's hull stands on (none once it can be hurt).
function gui.hull_gens(lander)
  if not (lander.valid and shared.kind_of(lander.name) == "lp-lander" and not lander.destructible) then return {} end
  return lander.surface.find_entities_filtered{position = lander.position, radius = shared.HULL_RADIUS, force = lander.force,
    name = shared.variants("lp-generator")}
end

function gui.on_selected(e)
  local p = game.get_player(e.player_index)
  clear_links(e.player_index)
  local sel = p and p.selected
  if not (sel and sel.valid) then return end
  local out = {}
  local function line(from, to, color, w)
    out[#out + 1] = rendering.draw_line{color = color, width = w or 1.5, from = from, to = to, surface = from.surface,
      players = {e.player_index}, draw_on_ground = true}
  end
  -- A corporation's lander while its hull holds (the user: "Could the lander perhaps point to the generators when
  -- hovered over? like a beacon points to its units?"): a line to each generator within shared.HULL_RADIUS, the ones
  -- its hull stands on (base.lua hull), in blue, and how many over it.
  if sel.force ~= p.force then
    local gens = gui.hull_gens(sel)
    if #gens > 0 then
      for _, g in ipairs(gens) do line(sel, g, {0.45, 0.75, 1, 0.7}, 2) end
      out[#out + 1] = rendering.draw_text{text = {"lp.hull-hover", #gens}, surface = sel.surface, target = {entity = sel,
        offset = {0, -4}}, color = {0.6, 0.85, 1}, scale = 1.2, alignment = "center", players = {e.player_index}}
      storage.squad_links[e.player_index] = out
    end
    return
  end
  if sel.name == BEACON then
    local v = command.beacon_view(sel)
    for _, u in ipairs(v.units) do line(sel, u, LINK[v.stance] or LINK.hold) end
  else
    local b = command.beacon_of(sel)
    if b then
      local v = command.beacon_view(b)
      line(sel, b, LINK[v.stance] or LINK.hold, 2)
      out[#out + 1] = rendering.draw_circle{color = LINK[v.stance] or LINK.hold, radius = 1.2, width = 3, filled = false,
        target = b, surface = b.surface, players = {e.player_index}, draw_on_ground = true}
    end
  end
  if #out > 0 then storage.squad_links[e.player_index] = out end
end

-- The beacon's own signals (command.lua's report section apart) ----------------------------------------------------------

local REPORTED = {["signal-S"] = true, ["signal-H"] = true, ["signal-E"] = true, ["signal-T"] = true,
  ["signal-W"] = true, ["signal-N"] = true, ["signal-M"] = true}
local function wired(b)
  return b.get_circuit_network(defines.wire_connector_id.circuit_red) ~= nil
    or b.get_circuit_network(defines.wire_connector_id.circuit_green) ~= nil
end
local function own_section(cb)
  for _, s in pairs(cb.sections) do
    if s.is_manual and s.group == "" then
      local report = #s.filters > 0
      for _, f in pairs(s.filters) do if not (f.value and REPORTED[f.value.name]) then report = false end end
      if not report then return s end
    end
  end
  return cb.add_section()
end

-- Sets (n) or clears (nil) a unit's squad size on the beacon. Returns false when the beacon is wired.
function gui.set_size(b, unit, n)
  if wired(b) then return false end
  local sig = shared.SQUAD_SIGNALS[unit]
  local cb = b.get_or_create_control_behavior()
  -- (Every slot of that signal in every manual section of its own, cleared first: one value, where the player sees it.)
  local first
  for _, s in pairs(cb.sections) do
    if s.is_manual and s.group == "" then
      for i = 1, s.filters_count do
        local f = s.get_slot(i)
        if f and f.value and f.value.name == sig then
          s.clear_slot(i)
          if not first then first = {s = s, i = i} end
        end
      end
    end
  end
  if n then
    local s, i = first and first.s, first and first.i
    if not s then
      s = own_section(cb)
      if not s then return false end
      i = s.filters_count + 1
    end
    s.set_slot(i, {value = {type = "virtual", name = sig, quality = "normal"}, min = math.max(0, n)})
  end
  return true
end

-- The squad panel -------------------------------------------------------------------------------------------------------

local function anchor()
  return {gui = defines.relative_gui_type.constant_combinator_gui, position = defines.relative_gui_position.right,
    name = BEACON}
end

local function build(p)
  local old = p.gui.relative[NAME]
  if old then old.destroy() end
  local f = p.gui.relative.add{type = "frame", name = NAME, direction = "vertical", caption = {"lp.squad-title"},
    anchor = anchor()}
  f.add{type = "label", name = "stance", style = "bold_label"}
  f.add{type = "label", name = "doing"}
  f.add{type = "label", name = "ammo"}
  -- (The squad's units by the round they hold, 0.2.470: the round's icon and a count, never its name in our text.)
  local rounds = f.add{type = "flow", name = "rounds", direction = "horizontal"}
  rounds.style.vertical_align = "center"
  f.add{type = "line"}
  local t = f.add{type = "table", name = "units", column_count = 5}
  t.style.horizontal_spacing = 6
  t.style.vertical_spacing = 2
  for _, unit in ipairs(UNITS) do
    t.add{type = "sprite", name = "icon:" .. unit, sprite = "entity/" .. unit, tooltip = {"entity-name." .. unit}}
    local n = t.add{type = "label", name = "n:" .. unit}
    n.style.minimal_width = 56
    for _, b in ipairs({{"less", "-", -1}, {"more", "+", 1}, {"clear", "x", 0}}) do
      local el = t.add{type = "button", name = "lp_squad_" .. b[1] .. ":" .. unit, caption = b[2], style = "tool_button",
        tooltip = {"lp.squad-" .. b[1]}, tags = {lp_squad = unit, d = b[3]}}
      el.style.width, el.style.height = 24, 24
    end
  end
  f.add{type = "label", name = "wired", caption = {"lp.squad-wired"}}
  return f
end

local function refresh(p)
  local b = p.opened
  if not (b and type(b) == "userdata" and b.valid and b.object_name == "LuaEntity" and b.name == BEACON) then return end
  local f = p.gui.relative[NAME] or build(p)
  -- (A panel built before 0.2.470 has no rounds row: built again.)
  if not f.rounds then f = build(p) end
  local v = command.beacon_view(b)
  -- (Its squad's colour first, as its units wear it in alt mode; a post says its channel, 0.2.486.)
  local c = v.colour
  local swatch = string.format("[color=%d,%d,%d]■[/color] ", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
  f.stance.caption = {"", swatch, {"lp.squad-stance-" .. v.stance},
    v.channel and {"", " ", {"lp.squad-channel", v.channel}} or "",
    v.post and {"", " ", {"lp.squad-post", v.post}} or ""}
  local a = v.answering
  f.doing.caption = a and {"lp.squad-answering", string.format("[gps=%.0f,%.0f,%s]", a.pos.x, a.pos.y, b.surface.name)}
    or (v.stance == "defend" and {"lp.squad-waiting"} or "")
  f.doing.visible = f.doing.caption ~= ""
  -- (Its ammunition, 0.2.465: the squad's rounds against its loadouts, and how many are dry and walking to rearm.)
  local am = v.ammo
  f.ammo.caption = am and (am.dry > 0 and {"lp.squad-ammo-dry", am.rounds, am.full, am.dry} or {"lp.squad-ammo", am.rounds, am.full}) or ""
  f.ammo.visible = am ~= nil
  local rf = f.rounds
  rf.clear()
  local names = {}
  for r in pairs(am and am.by_round or {}) do names[#names + 1] = r end
  table.sort(names)
  for _, r in ipairs(names) do
    local s = rf.add{type = "sprite", sprite = "item/" .. r, tooltip = prototypes.item[r].localised_name}
    s.style.size = 20
    s.style.stretch_image_to_widget_size = true
    local l = rf.add{type = "label", caption = "× " .. am.by_round[r]}
    l.style.right_margin = 8
  end
  rf.visible = #names > 0
  local w = wired(b)
  f.wired.visible = w
  local t = f.units
  for _, unit in ipairs(UNITS) do
    local n, cap = v.count[unit] or 0, v.caps[unit]
    t["n:" .. unit].caption = cap and string.format("%d / %d", n, cap) or string.format("%d / -", n)
    t["lp_squad_less:" .. unit].enabled = not w and (cap or n) > 0
    t["lp_squad_more:" .. unit].enabled = not w and cap ~= nil
    t["lp_squad_clear:" .. unit].enabled = not w and cap ~= nil
  end
end

function gui.on_opened(e)
  local p = game.get_player(e.player_index)
  if p and e.entity and e.entity.valid and e.entity.name == BEACON then refresh(p) end
end

-- (Each second: the counts move as units come and go.)
function gui.tick()
  for _, p in pairs(game.connected_players) do refresh(p) end
end

function gui.on_click(e)
  local el = e.element
  local unit = el and el.valid and el.tags and el.tags.lp_squad
  if not unit then return false end
  local p = game.get_player(e.player_index)
  local b = p and p.opened
  if not (b and type(b) == "userdata" and b.valid and b.object_name == "LuaEntity" and b.name == BEACON) then return true end
  local v = command.beacon_view(b)
  local cap, n = v.caps[unit], v.count[unit] or 0
  local d = el.tags.d
  -- (Less with no size set starts from the squad as it stands, one fewer.)
  if d == 0 then gui.set_size(b, unit, nil)
  elseif cap then gui.set_size(b, unit, math.max(0, cap + d))
  elseif d < 0 then gui.set_size(b, unit, math.max(0, n - 1)) end
  refresh(p)
  return true
end

return gui
