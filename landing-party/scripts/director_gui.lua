-- The director's debug panel (the user, 2026-11-13: "For the director i would appreciate a debug UI for testing"): /lp
-- director opens it. What it reads (on or off, its personality, its phase and how long left, its budget, its readings,
-- each corporation's tempo, its last beats) refreshed every second; buttons on its hand (director.cmd): on (no grace),
-- off, as the setting says, a spree now for a corporation, a lull now, the budget full or empty, the beat ended.
-- A debugging tool: its words are plain text, not localised.
local shared = require("__landing-party__.shared")
local director = require("__landing-party__.scripts.director")

local gui = {}
local NAME = "lp_director"

local function mmss(ticks)
  if not ticks or ticks <= 0 then return "-" end
  local s = math.floor(ticks / 60)
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function lines(p)
  local s = director.state() or {}
  local tick = game.tick
  local out = {}
  out[#out + 1] = string.format("%s, %s; phase %s%s", s.active and "ON" or "off", director.personality(), s.phase or "-",
    s.phase_till and (" (" .. mmss(s.phase_till - tick) .. " left)") or "")
  out[#out + 1] = string.format("budget %.2f of %d; next beat %s; sprees %d, surges %d, focus strikes %d, lulls %d%s", s.budget or 0,
    director.tune("cap"), tostring(s.next_beat or "-"), s.sprees or 0, s.surges or 0, s.focuses or 0, s.lulls or 0,
    s.held_for and (", held: " .. s.held_for) or "")
  local i, fo = s.intensity, s.focus
  out[#out + 1] = string.format("intensity %s; focus %s",
    (i and tick < i.till) and string.format("+%d, %s left", i.add, mmss(i.till - tick)) or "-",
    (fo and tick < fo.till) and string.format("%.0f,%.0f (x%g within %d), %s left", fo.pos[1], fo.pos[2], fo.weight, fo.radius,
      mmss(fo.till - tick)) or "-")
  local r = s.read
  out[#out + 1] = r and string.format("era %d, factory worth %.0f, guns %d, lost %.0f in 30 min%s%s", r.era or 0, r.worth or 0,
    r.guns or 0, r.lost or 0, r.hurt and ", HURT (threats held)" or "", r.falling and ", guns falling (fill halved)" or "")
    or "no readings yet (it reads once a minute while on)"
  local owner = (shared.player_forces()[1] or {}).name or ""
  for corp, c in pairs(shared.CORPS) do
    local t = s.tempo and s.tempo[corp]
    local truce = storage.truces and storage.truces[corp .. "|" .. owner]
    out[#out + 1] = string.format("%s: tempo %s%s", c.name, (t and tick < t.till) and string.format("x%g, %s left", t.factor,
      mmss(t.till - tick)) or "x1", (truce and tick < truce) and (", held " .. mmss(truce - tick)) or "")
  end
  local log = s.log or {}
  for i = math.max(1, #log - 5), #log do
    out[#out + 1] = string.format("%s  %s", mmss(log[i].tick), log[i].text)
  end
  return out
end

local function build(p)
  local f = p.gui.screen.add{type = "frame", name = NAME, direction = "vertical", caption = "Director (debug)"}
  f.auto_center = true
  local body = f.add{type = "flow", name = "lp_dir_body", direction = "vertical"}
  body.style.vertical_spacing = 2
  local row = f.add{type = "flow", name = "lp_dir_row1", direction = "horizontal"}
  for _, b in ipairs({{"on", "Force on"}, {"off", "Force off"}, {"auto", "As setting"}, {"lull", "Lull now"},
    {"surge", "Surge now"}, {"focus", "Focus strike"}, {"fill", "Fill budget"}, {"empty", "Empty budget"}, {"end", "End beat"}}) do
    row.add{type = "button", name = "lp_dir_" .. b[1], caption = b[2], tags = {lp_dir = b[1]}}
  end
  local row2 = f.add{type = "flow", name = "lp_dir_row2", direction = "horizontal"}
  for corp, c in pairs(shared.CORPS) do
    row2.add{type = "button", name = "lp_dir_spree_" .. corp, caption = "Spree: " .. c.name, tags = {lp_dir = "spree", corp = corp}}
  end
  row2.add{type = "button", name = "lp_dir_close", caption = "Close", tags = {lp_dir = "close"}}
  return f
end

local function fill(p)
  local f = p.gui.screen[NAME]
  if not f then return end
  local body = f.lp_dir_body
  body.clear()
  for i, l in ipairs(lines(p)) do body.add{type = "label", name = "lp_dir_l" .. i, caption = l} end
end

function gui.toggle(p)
  if p.gui.screen[NAME] then p.gui.screen[NAME].destroy(); return false end
  build(p)
  fill(p)
  return true
end

-- Every second, each player's open panel.
function gui.tick(tick)
  if tick % 60 ~= 0 then return end
  for _, p in pairs(game.connected_players) do if p.gui.screen[NAME] then fill(p) end end
end

-- A click on its buttons: true when it was one.
function gui.on_click(e)
  local el = e.element
  if not (el and el.valid and el.tags and el.tags.lp_dir) then return false end
  local p = game.get_player(e.player_index)
  if el.tags.lp_dir == "close" then
    if p.gui.screen[NAME] then p.gui.screen[NAME].destroy() end
    return true
  end
  local said = director.cmd(el.tags.lp_dir, el.tags.corp)
  p.print("director: " .. tostring(said)) -- notice-ok: the debug panel's reply to its own button
  fill(p)
  return true
end

return gui
