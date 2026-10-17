-- Map-view drawing in the game's own idiom (the user, 2026-10-17: "the big circles and lines feel childish and
-- improvised. Could we achieve something more sleek looking?"). Territory snaps to the map's 32-tile chunks, as radar
-- coverage does: a faint wash in the corporation's colour over the chunks it holds and a hairline on the outer edge
-- only. Claims and the lines a corporation means to hold are dashed hairlines. Map view only (render_mode "chart").
-- A leaf: rendering only.
local chart = {}

local C = 32
local WASH, EDGE = 0.07, 0.75

-- Rendering takes premultiplied colours.
local function pm(c, a) return {r = c.r * a, g = c.g * a, b = c.b * a, a = a} end
chart.pm = pm

function chart.clear(list)
  for _, o in ipairs(list or {}) do if o.valid then o.destroy() end end
end

-- Positions as the engine takes them ({x, y}: a point carrying more, as an angle to sort by, is refused).
local function at(p) return {p.x or p[1], p.y or p[2]} end

local function line(out, surface, from, to, colour, opts)
  out[#out + 1] = rendering.draw_line{surface = surface, from = at(from), to = at(to), color = pm(colour, opts.edge or EDGE),
    width = opts.width or 1, dash_length = opts.dashed and 3 or nil, gap_length = opts.dashed and 2 or nil,
    render_mode = "chart"}
end

-- The chunks whose centres lie within r of centre (at least the one holding it), as a wash and an outer hairline.
-- Rows of chunks become one rectangle each, and runs of edge one line each: a few dozen objects for a large camp.
function chart.territory(surface, centre, r, colour, opts)
  opts = opts or {}
  local x, y = centre[1] or centre.x, centre[2] or centre.y
  local cells = {}
  local function key(cx, cy) return cx .. "," .. cy end
  local any = false
  for cx = math.floor((x - r) / C), math.floor((x + r) / C) do
    for cy = math.floor((y - r) / C), math.floor((y + r) / C) do
      if (cx * C + C / 2 - x) ^ 2 + (cy * C + C / 2 - y) ^ 2 <= r * r then cells[key(cx, cy)] = true; any = true end
    end
  end
  if not any then cells[key(math.floor(x / C), math.floor(y / C))] = true end
  local has = function(cx, cy) return cells[key(cx, cy)] end
  local x0, x1 = math.floor((x - r) / C) - 1, math.floor((x + r) / C) + 1
  local y0, y1 = math.floor((y - r) / C) - 1, math.floor((y + r) / C) + 1
  local out = {}
  -- The wash, a rectangle per run of chunks in a row.
  if not opts.no_wash then
    for cy = y0, y1 do
      local run
      for cx = x0, x1 + 1 do
        if has(cx, cy) then
          run = run or cx
        elseif run then
          out[#out + 1] = rendering.draw_rectangle{surface = surface, left_top = {run * C, cy * C},
            right_bottom = {cx * C, (cy + 1) * C}, filled = true, color = pm(colour, opts.wash or WASH), render_mode = "chart"}
          run = nil
        end
      end
    end
  end
  -- Horizontal edges (a chunk's top or bottom with no chunk beyond), merged along the row.
  for cy = y0, y1 do
    for _, side in ipairs({{-1, 0}, {1, 1}}) do
      local run
      for cx = x0, x1 + 1 do
        if has(cx, cy) and not has(cx, cy + side[1]) then
          run = run or cx
        elseif run then
          line(out, surface, {run * C, (cy + side[2]) * C}, {cx * C, (cy + side[2]) * C}, colour, opts)
          run = nil
        end
      end
    end
  end
  -- Vertical edges, merged along the column.
  for cx = x0, x1 do
    for _, side in ipairs({{-1, 0}, {1, 1}}) do
      local run
      for cy = y0, y1 + 1 do
        if has(cx, cy) and not has(cx + side[1], cy) then
          run = run or cy
        elseif run then
          line(out, surface, {(cx + side[2]) * C, run * C}, {(cx + side[2]) * C, cy * C}, colour, opts)
          run = nil
        end
      end
    end
  end
  return out
end

-- A dashed hairline along points in order (an arc of posts, a border).
function chart.path(surface, points, colour, opts)
  opts = opts or {}
  local out = {}
  for i = 2, #points do
    line(out, surface, points[i - 1], points[i], colour, {dashed = opts.dashed ~= false, width = opts.width, edge = opts.edge})
  end
  return out
end

-- Points on a circle's arc from angle a0 to a1 (radians), every ~8 tiles.
function chart.arc_points(centre, r, a0, a1)
  local x, y = centre[1] or centre.x, centre[2] or centre.y
  local n = math.max(2, math.ceil(math.abs(a1 - a0) * r / 8))
  local pts = {}
  for i = 0, n do
    local a = a0 + (a1 - a0) * i / n
    pts[#pts + 1] = {x + math.cos(a) * r, y + math.sin(a) * r}
  end
  return pts
end

return chart
