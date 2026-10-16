-- The corporate map (the rivals consult: "without it, none of the above reads"). In map view: each camp labelled with
-- its corporation and its standing toward the player (rival, enemy, truce), kept current; Serenity's next arc (the
-- cordon's posts being built) marked, with an arrow on the bearing it walks. Claims, prospects, borders and stakes
-- draw their own marks (prospect.lua, base.lua, border.lua).
local shared = require("__landing-party__.shared")
local standing = require("__landing-party__.scripts.standing")

local map = {}

local function label(b)
  local corp = shared.CORPS[b.corp]
  local st = standing.get(b.corp, "player")
  return corp.name .. ": " .. st
end

local function draw_arc(b, c)
  local s = game.surfaces[b.surface]
  local col = shared.CORPS[b.corp].color
  local marks = {}
  for _, m in ipairs(c.posts) do
    table.insert(marks, rendering.draw_circle{color = {r = col.r, g = col.g, b = col.b, a = 0.9}, radius = 5, width = 2,
      filled = false, target = m.center, surface = s, render_mode = "chart"})
  end
  local a = c.bearing
  local from = {b.origin.x + math.cos(a) * (c.radius - 40), b.origin.y + math.sin(a) * (c.radius - 40)}
  local to = {b.origin.x + math.cos(a) * (c.radius + 20), b.origin.y + math.sin(a) * (c.radius + 20)}
  table.insert(marks, rendering.draw_line{color = {r = col.r, g = col.g, b = col.b, a = 0.9}, width = 4, from = from, to = to,
    surface = s, render_mode = "chart"})
  c.marks = marks
end

function map.tick(tick)
  if tick % 600 ~= 211 then return end
  for _, b in pairs(storage.bases or {}) do
    if not b.fallen and b.lander and b.lander.valid and b.origin then
      local text = label(b)
      local o = b.map_label and rendering.get_object_by_id(b.map_label)
      if not (o and o.valid) then
        local col = shared.CORPS[b.corp].color
        o = rendering.draw_text{text = text, surface = game.surfaces[b.surface], target = {b.origin.x, b.origin.y - 30},
          color = {r = col.r, g = col.g, b = col.b, a = 1}, scale = 3, alignment = "center", render_mode = "chart"}
        b.map_label = o.id
      elseif o.text ~= text then
        o.text = text
      end
      b.map_text = text
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
