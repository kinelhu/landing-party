-- The corporate map (the rivals consult: "without it, none of the above reads"). In map view: each camp labelled with
-- its corporation and its standing toward the player (rival, enemy, truce), kept current; Serenity's next arc (the
-- cordon's posts being built) marked, with an arrow on the bearing it walks. Claims, prospects, borders and stakes
-- draw their own marks (prospect.lua, base.lua, border.lua).
local shared = require("__landing-party__.shared")
local standing = require("__landing-party__.scripts.standing")
local chart = require("__landing-party__.scripts.chart")
local names = require("__landing-party__.scripts.names")

local map = {}

local function label(b)
  return standing.get(b.corp, "player")
end

-- Serenity's next arc: a dashed hairline through its posts, in angle order (scripts/chart.lua), where it was a ring of
-- circles and an arrow.
local function draw_arc(b, c)
  local s = game.surfaces[b.surface]
  local col = shared.CORPS[b.corp].color
  local pts = {}
  for _, m in ipairs(c.posts) do
    if m.center then
      pts[#pts + 1] = {m.center[1], m.center[2], math.atan2(m.center[2] - b.origin.y, m.center[1] - b.origin.x)}
    end
  end
  table.sort(pts, function(p, q) return p[3] < q[3] end)
  c.marks = #pts >= 2 and chart.path(s, pts, col, {width = 2, edge = 0.9}) or {}
end

-- The camp's name over its standing, on the map (names.lua; the user: "actual names for the camps too").
local function draw_label(b, s, col)
  local name = rendering.draw_text{text = names.of(b), surface = s, target = {b.origin.x, b.origin.y - 34},
    color = {r = col.r, g = col.g, b = col.b, a = 1}, scale = 2, alignment = "center", render_mode = "chart"}
  local st = rendering.draw_text{text = {"lp.map-" .. label(b)}, surface = s, target = {b.origin.x, b.origin.y - 22},
    color = {r = 0.75, g = 0.75, b = 0.75, a = 0.9}, scale = 1.2, alignment = "center", render_mode = "chart"}
  b.map_label, b.map_label2, b.map_standing = name.id, st.id, label(b)
  return st
end

function map.tick(tick)
  if tick % 600 ~= 211 then return end
  for _, b in pairs(storage.bases or {}) do
    -- A fallen camp keeps its name on the map, its standing line saying so.
    local o2 = b.fallen and b.map_label2 and rendering.get_object_by_id(b.map_label2)
    if o2 and o2.valid and b.map_standing ~= "fallen" then o2.text, b.map_standing = {"lp.map-fallen"}, "fallen" end
    if not b.fallen and b.lander and b.lander.valid and b.origin then
      local text = label(b)
      local o = b.map_label2 and rendering.get_object_by_id(b.map_label2)
      if not (o and o.valid) then
        local old = b.map_label and rendering.get_object_by_id(b.map_label)
        if old and old.valid then old.destroy() end
        o = draw_label(b, game.surfaces[b.surface], shared.CORPS[b.corp].color)
      elseif b.map_standing ~= text then
        o.text, b.map_standing = {"lp.map-" .. text}, text
      end
      b.map_text = names.of(b) .. " (" .. shared.CORPS[b.corp].name .. "): " .. text
      local c = b.cordon
      if c and not c.marks then draw_arc(b, c) end
    end
  end
  -- Arcs done: their marks go (the claim's disc takes over).
  for _, b in pairs(storage.bases or {}) do
    for _, old in ipairs(b.arcs_drawn or {}) do
      if old ~= b.cordon then for _, r in ipairs(old.marks or {}) do if r.valid then r.destroy() end end end
    end
    b.arcs_drawn = b.cordon and {b.cordon} or {}
  end
end

return map
