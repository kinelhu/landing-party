--[[ lp-manual.lua: the Landing Party field manual's components, for the lp-manual-pdf format (LuaLaTeX, A5
booklet) and, as a plain filter (`filters: [lp-manual]`), for HTML.

A chapter writes markdown; the numbers come from the data file the generator emits (metadata `lp-data`, a path
relative to the project, default `_generated/lp-data.json`). The components:

  # Synthexis {.opener faction="synthexis" kicker="The corporations"}
  > Engineered to adapt.                 the blockquote right after an opener is its epigraph (or epigraph="...";
                                         with neither, the faction's motto from the data; for HTML, where a
                                         chapter's heading is lifted out, ::: {.epigraph faction="x"} ::: shows it,
                                         with the hero); hero="media/heroes/x.jpg" overrides the faction's hero
                                         (the data's `hero`; its `vista` is the front cover strip's, printed once)
  # Reference {faction="kessler-hayashi"} a chapter without an opener; the faction colours its heads and tab

  ::: {.unit unit="lp-tank"}             a unit card: portrait, stat panel and role from data.units["lp-tank"];
  A two or three line blurb.             any field can be given as an attribute instead (health="900" ...)
  :::

  ::: {.tree tree="kh-units"}            a unit or tech tree from data.trees["kh-units"], laid out here
  Caption, optional.
  :::

  ::: {.lore kicker="Freight Authority, operator file 114" title="The contract" faction="kessler-hayashi"}
  ::: {.dossier}                         the file's header: a definition list (TERM, then ": text"), set as a
  REGISTERED                             two-column field list in the display face on the faction's tint (HTML: a
  : Serenity Ring, nine platforms.       definition list). A lore page runs as a spread, from a verso.
  :::
  Narrator prose; the first letter of the first paragraph after the dossier becomes a drop cap.
  ::: {.pullquote cite="I. Kessler, site report NV-1/3"}
  A line worth lifting, attributed.
  :::
  :::

  ::: {.callouts plan="media/plans/x.json" faction="synthexis"}
  Caption, optional (else the plan's).   an annotated plan: the plan's image (its JSON's `image`, beside it) with a
  :::                                    numbered marker at each callout (x, y in the image's pixels) in the faction's
                                         colour, and the numbered legend under it; HTML: the image, its markers and
                                         the legend as an ordered list

  ::: {.strip faction="kessler-hayashi"} a sequence strip: the images in the div set side by side, each with its own
  ![First frame's caption.](a.jpg)       numbered caption under it; the div's other paragraphs are the strip's caption
  ![Second.](b.jpg)
  ![Third.](c.jpg)
  What the three show together.
  :::

  ::: {.tip title="..."}     ::: {.fieldnote title="..."}

The data file's shape is written out in the report that introduced this extension and in _proof/lp-data.json.
]]

local TEXTWIDTH = 117 -- mm; the style's geometry reads it from \lptextwidthmm, which this filter defines

local function script_dir()
  local p = PANDOC_SCRIPT_FILE or "."
  local d = pandoc.path.directory(p)
  if not pandoc.path.is_absolute(d) then d = pandoc.path.join({pandoc.system.get_working_directory(), d}) end
  return pandoc.path.normalize(d)
end
local EXT = script_dir()

local function is_latex() return quarto.doc.is_format("latex") or quarto.doc.is_format("pdf") end
local function is_html() return quarto.doc.is_format("html") end

local function str(v)
  if v == nil then return nil end
  if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then return tostring(v) end
  return pandoc.utils.stringify(v)
end

local function tex(s)
  s = tostring(s or "")
  s = s:gsub("\\", "\0"):gsub("([#$%%&_{}])", "\\%1"):gsub("~", "\\textasciitilde{}"):gsub("%^", "\\textasciicircum{}")
  return (s:gsub("%z", "\\textbackslash{}"))
end

local function esc(s)
  return (tostring(s or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local function base_dir()
  local d = quarto.project and quarto.project.directory
  if not d or d == "" then d = pandoc.path.directory(quarto.doc.input_file or ".") end
  return d
end

local function resolve(p)
  if not p or p == "" then return nil end
  if pandoc.path.is_absolute(p) then return p end
  return pandoc.path.normalize(pandoc.path.join({base_dir(), p}))
end

local function exists(p)
  local f = p and io.open(p, "rb")
  if f then f:close() return true end
  return false
end

-- ------------------------------------------------------------------ data
local D = {factions = {}, units = {}, trees = {}, portraits = "media/portraits"}
local SCALE = {} -- faction -> stat -> top of the faction's range

local function load_data(meta)
  local rel = str(meta["lp-data"]) or "_generated/lp-data.json"
  local path = resolve(rel)
  local f = io.open(path, "r")
  if not f then
    quarto.log.warning("lp-manual: no data file at " .. path .. "; cards and trees need one")
    return
  end
  local ok, d = pcall(pandoc.json.decode, f:read("a"), false)
  f:close()
  if not ok or type(d) ~= "table" then error("lp-manual: cannot read " .. path) end
  for k, v in pairs(d) do D[k] = v end
  for _, u in pairs(D.units or {}) do
    local s = SCALE[u.faction] or {}
    for _, stat in ipairs({"health", "damage", "range", "speed"}) do
      local n = tonumber(u[stat])
      if n and n > (s[stat] or 0) then s[stat] = n end
    end
    SCALE[u.faction] = s
  end
end

local function portrait_path(id)
  if not id or id == "" then return nil end
  -- a unit's id names its portrait; a path (a lab's tree icon, media/buildings/x.png) is taken as it is
  local p = id:find("/") and resolve(id) or resolve(pandoc.path.join({D.portraits or "media/portraits", id .. ".png"}))
  if exists(p) then return p end
  quarto.log.warning("lp-manual: no portrait " .. p)
  return nil
end

local function luminance(hex)
  local r, g, b = tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
  local function lin(c) return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
end

local function faction_name(id)
  local f = D.factions[id or ""]
  return f and f.name or ""
end

local function preamble(meta)
  local out = {
    "\\def\\lpextdir{" .. EXT .. "}",
    "\\def\\lptextwidthmm{" .. TEXTWIDTH .. "}",
    "\\input{" .. EXT .. "/lp-manual-style.tex}",
  }
  local ids = {}
  for id in pairs(D.factions) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return (tonumber(D.factions[a].tab) or 9) < (tonumber(D.factions[b].tab) or 9) end)
  local strips, backs = {}, {}
  for _, id in ipairs(ids) do
    local f = D.factions[id]
    local hex = tostring(f.color):gsub("#", ""):upper()
    -- Text on the faction's colour: white where it is dark enough, ink where it is pale (contrast 4.5 or better).
    local on = (1.05 / (luminance(hex) + 0.05) >= 4.5) and "white" or "ink"
    out[#out + 1] = string.format("\\lpdefinefaction{%s}{%s}{%s}{%s}{%s}", id, hex, on, string.format("%d", math.floor(tonumber(f.tab) or 0)), tex(f.name))
    -- The vistas are printed once, on the front cover; the back cover sets each faction's emblem unit side by side.
    local vista = resolve(f.vista)
    if f.cover ~= false and vista and exists(vista) then
      strips[#strips + 1] = string.format("\\lpcoverstrip{%s}{%s}{%s}", id, vista, tex(f.motto or ""))
    end
    local emblem = portrait_path(f.emblem)
    if emblem then backs[#backs + 1] = string.format("\\lpbackfaction{%s}{%s}{%s}", id, emblem, tex(f.motto or "")) end
  end
  out[#out + 1] = "\\def\\lpcoverfactions{" .. table.concat(strips, "") .. "}"
  out[#out + 1] = "\\def\\lpbackfactions{\\noindent" .. table.concat(backs, "\\hfill") .. "\\par}"
  return table.concat(out, "\n")
end

-- ------------------------------------------------------------------ numbers
local function thousands(n)
  local s = string.format("%d", n)
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (out:gsub("^,", ""))
end

local function show(v)
  local n = tonumber(v)
  if not n then return tostring(v or "") end
  if n == math.floor(n) and math.abs(n) >= 1000 then return thousands(n) end
  if n == math.floor(n) then return string.format("%d", n) end
  return (string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", ""))
end

local function frac(v, top)
  local n, t = tonumber(v), tonumber(top)
  if not n or not t or t <= 0 then return nil end
  return math.max(0.02, math.min(1, n / t))
end

-- ------------------------------------------------------------------ unit card
local function field(attr, u, key)
  local a = attr[key] or attr[key:gsub("_", "-")]
  if a ~= nil and a ~= "" then return a end
  return u[key]
end

local function unit_fields(div)
  local id = div.attributes.unit or div.identifier
  local u = (D.units or {})[id or ""] or {}
  if id and id ~= "" and not D.units[id] and not div.attributes.name then
    quarto.log.warning("lp-manual: unit " .. id .. " is not in the data file")
  end
  local get = function(k) return field(div.attributes, u, k) end
  local fac = get("faction") or "neutral"
  local F = D.factions[fac] or {}
  return {
    id = id, fac = fac, F = F, name = get("name") or id or "?", portrait = portrait_path(get("portrait") or id),
    air = (get("air") == true or get("air") == "true"),
    role = get("role"), counters = get("counters"), countered_by = get("countered_by"),
    stats = {
      {"Health", get("health"), nil, ""},
      {"Damage", get("damage"), get("damage_text"), ""},
      {"Range", get("range"), nil, " tiles"},
      {"Speed", get("speed"), nil, " tiles/s"},
    },
    cost = get("cost"), era = get("era"), era_level = tonumber(get("era_level")),
    era_label = F.era_label or "Era", era_max = tonumber(F.era_max) or 3, blurb = get("blurb"),
  }
end

local function unit_latex(div)
  local U = unit_fields(div)
  local scale = SCALE[U.fac] or {}
  local tag = faction_name(U.fac) .. (U.air and " \\textperiodcentered\\ Flier" or "")
  local blocks = {pandoc.RawBlock("latex", string.format("\\begin{lpunit}{%s}{%s}{%s}{%s}",
    U.fac, tex(U.name), tag:gsub("[#$%%&_{}]", "\\%0"), U.portrait or ""))}
  local lines = {}
  if U.role then lines[#lines + 1] = "\\lprole{" .. tex(U.role) .. "}" end
  for _, s in ipairs(U.stats) do
    local label, v, text, unit = s[1], s[2], s[3], s[4]
    if v ~= nil or text then
      if tonumber(v) == 1 then unit = unit:gsub("tiles", "tile") end
      local shown = text or (tonumber(v) and (show(v) .. unit) or tostring(v))
      local fr = frac(v, scale[label:lower()])
      if fr then lines[#lines + 1] = string.format("\\lpstat{%s}{%.3f}{%s}", label, fr, tex(shown))
      else lines[#lines + 1] = string.format("\\lpstattext{%s}{%s}", label, tex(shown)) end
    end
  end
  if U.cost then lines[#lines + 1] = string.format("\\lpstattext{Cost}{%s}", tex(U.cost)) end
  if U.era then
    local steps = (U.era_max and U.era_max == math.floor(U.era_max) and U.era_max > 1) and U.era_max or 1
    local level = U.era_level and (steps > 1 and U.era_level or U.era_level / (U.era_max or 1)) or -1
    lines[#lines + 1] = string.format("\\lpera{%s}{%s}{%d}{%s}", tex(U.era_label), tostring(level), steps, tex(U.era))
  end
  lines[#lines + 1] = string.format("\\lpunitlower{%s}{%s}", tex(U.counters or "-"), tex(U.countered_by or "-"))
  blocks[#blocks + 1] = pandoc.RawBlock("latex", table.concat(lines, "\n"))
  local body = div.content
  if #body == 0 and U.blurb then body = {pandoc.Para(pandoc.Str(U.blurb))} end
  for _, b in ipairs(body) do blocks[#blocks + 1] = b end
  blocks[#blocks + 1] = pandoc.RawBlock("latex", "\\end{minipage}\\end{lpunit}")
  return blocks
end

local function unit_html(div)
  local U = unit_fields(div)
  local scale = SCALE[U.fac] or {}
  local F = U.F
  local color = "#" .. tostring(F.color or "8A8E94"):gsub("#", "")
  local rows = {}
  for _, s in ipairs(U.stats) do
    local label, v, text, unit = s[1], s[2], s[3], s[4]
    if v ~= nil or text then
      local shown = text or (tonumber(v) and (show(v) .. unit) or tostring(v))
      local fr = frac(v, scale[label:lower()])
      rows[#rows + 1] = string.format('<tr><th>%s</th><td class="lp-bar">%s</td><td>%s</td></tr>', label,
        fr and string.format('<span style="width:%.1f%%"></span>', fr * 100) or "", esc(shown))
    end
  end
  if U.cost then rows[#rows + 1] = '<tr><th>Cost</th><td></td><td>' .. esc(U.cost) .. '</td></tr>' end
  if U.era then rows[#rows + 1] = '<tr><th>' .. esc(U.era_label) .. '</th><td></td><td>' .. esc(U.era) .. '</td></tr>' end
  local src = U.portrait and pandoc.path.make_relative(U.portrait, pandoc.path.directory(quarto.doc.input_file)) or nil
  local head = string.format(
    '<div class="lp-unit" style="--fac:%s"><div class="lp-unit-head"><span class="lp-unit-name">%s</span>' ..
    '<span class="lp-unit-tag">%s%s</span></div><div class="lp-unit-body">%s<div class="lp-unit-stats">%s' ..
    '<table>%s</table></div></div><div class="lp-unit-vs"><div><b>Counters</b> %s</div><div><b>Countered by</b> %s</div></div>' ..
    '<div class="lp-unit-lore">',
    color, esc(U.name), esc(faction_name(U.fac)), U.air and " · Flier" or "",
    src and ('<img src="' .. esc(src) .. '" alt="' .. esc(U.name) .. '">') or "",
    U.role and ('<p class="lp-unit-role">' .. esc(U.role) .. '</p>') or "", table.concat(rows),
    esc(U.counters or "-"), esc(U.countered_by or "-"))
  local blocks = {pandoc.RawBlock("html", head)}
  for _, b in ipairs(div.content) do blocks[#blocks + 1] = b end
  blocks[#blocks + 1] = pandoc.RawBlock("html", "</div></div>")
  return blocks
end

-- ------------------------------------------------------------------ trees
-- Layout, in mm, origin at the top left, y down. Bands are rows (eras), columns are branches (labs, sources).
local HOW = {teardown = "T", study = "F", science = "S", capture = "C", spoils = "H"}
-- A small node's height from its text: Titillium SemiBold at 6.2pt sets about 1.2 characters a mm, the note's
-- 5.4pt about 1.45 (measured on the proof). The estimate errs long; a node a line too tall is better than text across its frame.
local function lines(text, width, per_mm)
  if not text or text == "" then return 0 end
  local cap = width * per_mm
  local n, line = 1, 0
  for word in tostring(text):gmatch("%S+") do
    local w = utf8.len(word) or #word
    if line > 0 and line + 1 + w > cap then n, line = n + 1, 0 end
    if w > cap then n, line = n + math.ceil(w / cap) - 1, w % cap else line = line + (line > 0 and 1 or 0) + w end
  end
  return n
end
local function node_h(n, w)
  if n.portrait then return 24.5 end
  local strip = (n.kind == "tech") and 1.8 or 1.2
  local lw = w - strip - 2.6
  local note = (n.note or "") .. (n.answers and (", vs " .. n.answers) or "")
  n._ll = lines(((n.how and HOW[n.how]) and "OOO " or "") .. n.label, lw, 1.1) -- the glyph leads the label
  n._nl = lines(note, lw, 1.4)
  return math.max(9.4, 1.3 + n._ll * 2.55 + 0.8 + n._nl * 2.25 + 1.0)
end

local function internal(list)
  local here = {}
  for _, n in ipairs(list) do here[n.id] = true end
  for _, n in ipairs(list) do
    for _, r in ipairs(n.requires or {}) do if here[r] then return true end end
  end
  return false
end

local function layout(T)
  local G = {gutter = 8.5, head = 12.5, pad = 2.6, gap = 2.0}
  local cols, colidx = T.columns or {}, {}
  for i, c in ipairs(cols) do colidx[c.id] = i end
  local bands, bandidx = T.bands or {}, {}
  for i, b in ipairs(bands) do bandidx[b.id] = i end
  local cells = {} -- band -> col -> nodes
  local free = {}  -- band -> nodes
  local byid = {}
  for _, n in ipairs(T.nodes or {}) do
    byid[n.id] = n
    local bi = bandidx[n.band]
    if not bi then error("lp-manual: tree node " .. n.id .. " has no band " .. tostring(n.band)) end
    if bands[bi].free or not n.column then
      free[bi] = free[bi] or {}
      table.insert(free[bi], n)
    else
      local ci = colidx[n.column]
      if not ci then error("lp-manual: tree node " .. n.id .. " has no column " .. tostring(n.column)) end
      cells[bi] = cells[bi] or {}
      cells[bi][ci] = cells[bi][ci] or {}
      table.insert(cells[bi][ci], n)
    end
  end
  -- Column weights. A cell whose nodes need one another stacks them; a crowded cell may put two side by side,
  -- the most crowded columns first, while a slot stays MIN_SLOT wide. A column's `span` in the data decides it.
  local MIN_SLOT = 20
  local usable = TEXTWIDTH - G.gutter
  local weight, total, wants = {}, 0, {}
  for ci, c in ipairs(cols) do
    weight[ci] = tonumber(c.span) or 1
    total = total + weight[ci]
    if not c.span then
      local most = 0
      for bi = 1, #bands do
        local list = cells[bi] and cells[bi][ci]
        if list and #list > 1 and not internal(list) then most = math.max(most, #list) end
      end
      if most > 1 then wants[#wants + 1] = {ci = ci, most = most} end
    end
  end
  table.sort(wants, function(a, b) if a.most ~= b.most then return a.most > b.most end return a.ci < b.ci end)
  for _, w in ipairs(wants) do
    if usable / (total + 1) >= MIN_SLOT then weight[w.ci], total = 2, total + 1 end
  end
  local slot = usable / math.max(total, 1)
  local x = G.gutter
  for ci, c in ipairs(cols) do
    c._x0, c._w = x, slot * weight[ci]
    x = x + c._w
  end
  -- place
  local y = G.head
  for bi, b in ipairs(bands) do
    b._y0 = y
    local bh = 0
    if free[bi] then
      local k = #free[bi]
      local fs = usable / k
      local w = math.min(fs - 3, slot * 1.15)
      for i, n in ipairs(free[bi]) do
        n._w, n._h = w, node_h(n, w)
        n._cx, n._y = G.gutter + fs * (i - 0.5), y + G.pad
        bh = math.max(bh, n._h)
      end
    end
    for ci, c in ipairs(cols) do
      local list = cells[bi] and cells[bi][ci]
      if list then
        local across = internal(list) and 1 or math.min(#list, weight[ci])
        local cy, h = y + G.pad, 0
        local w = slot - 3.2
        for i, n in ipairs(list) do
          local col = (i - 1) % across
          if col == 0 and i > 1 then cy = cy + h + G.gap; h = 0 end
          local inrow = math.min(across, #list - (i - 1 - col))
          n._w, n._h = w, node_h(n, w)
          n._cx = c._x0 + c._w / 2 + (col - (inrow - 1) / 2) * slot
          n._y = cy
          h = math.max(h, n._h)
        end
        bh = math.max(bh, cy + h - (y + G.pad))
      end
    end
    b._h = bh + 2 * G.pad
    y = y + b._h
  end
  return {G = G, cols = cols, bands = bands, byid = byid, height = y}
end

local function f1(v) return string.format("%.2f", v) end

local function blocked(L, me, other, x, y0, y1)
  for _, n in pairs(L.byid) do
    if n ~= me and n ~= other and n._cx then
      if x > n._cx - n._w / 2 - 0.5 and x < n._cx + n._w / 2 + 0.5 and y1 > n._y and y0 < n._y + n._h then
        return true
      end
    end
  end
  return false
end

local function tree_latex(T, caption_blocks)
  local L = layout(T)
  local tfac = T.faction or "neutral"
  -- A tree taller than a page leaves room for (its title, legend and caption: MAX_H mm) is set a little smaller,
  -- whole, rather than run into the folio. The generator should split a tree that needs more than a few percent.
  local MAX_H = tonumber(T.max_height) or 134
  local shrink = (L.height + 1 > MAX_H) and (MAX_H / (L.height + 1)) or 1
  if shrink < 0.9 then
    quarto.log.warning(string.format("lp-manual: tree %s is set at %d%%; split it", T.title or "?", math.floor(shrink * 100)))
  end
  local o = {string.format("%s\\begin{tikzpicture}[x=1mm,y=-1mm]\n\\useasboundingbox (0,0) rectangle (%s,%s);",
    shrink < 1 and string.format("\\makebox[\\linewidth]{\\scalebox{%.3f}{", shrink) or "", TEXTWIDTH, f1(L.height + 1))}
  o._shrink = shrink
  -- bands
  for i, b in ipairs(L.bands) do
    if i % 2 == 1 then
      o[#o + 1] = string.format("\\fill[lpband] (0,%s) rectangle (%s,%s);", f1(b._y0), TEXTWIDTH, f1(b._y0 + b._h))
    end
    o[#o + 1] = string.format("\\draw[FacMid, line width=0.3pt] (0,%s) -- (%s,%s);", f1(b._y0), TEXTWIDTH, f1(b._y0))
    o[#o + 1] = string.format("\\node[lpbandlabel] at (%s,%s) {%s};", f1(L.G.gutter / 2), f1(b._y0 + b._h / 2),
      tex(b.label):upper())
  end
  o[#o + 1] = string.format("\\draw[FacMid, line width=0.3pt] (0,%s) -- (%s,%s);", f1(L.height), TEXTWIDTH, f1(L.height))
  -- columns
  for i, c in ipairs(L.cols) do
    local icon = c.icon and portrait_path(c.icon)
    local cx = c._x0 + c._w / 2
    local cf = c.faction or tfac
    if icon then
      o[#o + 1] = string.format("\\begin{scope}\\clip (%s,%s) circle (3.6);\\node[inner sep=0pt] at (%s,%s) " ..
        "{\\includegraphics[width=7.4mm]{%s}};\\end{scope}\\draw[lp@%s, line width=0.6pt] (%s,%s) circle (3.6);",
        f1(cx), f1(4.2), f1(cx), f1(4.2), icon, tfac, f1(cx), f1(4.2))
      o[#o + 1] = string.format("\\node[lpcolhead, text width=%smm] at (%s,%s) {%s};", f1(c._w - 2), f1(cx), f1(10.4),
        tex(c.label):upper())
    else
      o[#o + 1] = string.format("\\fill[lp@%s] (%s,%s) rectangle (%s,%s);", cf, f1(c._x0 + 1.4), f1(1.2),
        f1(c._x0 + c._w - 1.4), f1(2.2))
      o[#o + 1] = string.format("\\node[lpcolhead, text width=%smm] at (%s,%s) {%s};", f1(c._w - 2), f1(cx), f1(7),
        tex(c.label):upper())
    end
    if i > 1 then
      o[#o + 1] = string.format("\\draw[LPRule, line width=0.3pt, dash pattern=on 0.8pt off 1pt] (%s,%s) -- (%s,%s);",
        f1(c._x0), f1(L.G.head), f1(c._x0), f1(L.height))
    end
  end
  -- edges (drawn first: nodes sit on top of them)
  local edges = {}
  for _, n in pairs(L.byid) do
    for _, r in ipairs(n.requires or {}) do
      local a = L.byid[r]
      if not a then error("lp-manual: tree node " .. n.id .. " requires an unknown node " .. r) end
      local ax, ab, bx, bt = a._cx, a._y + a._h, n._cx, n._y
      if bt > ab then
        local ym = bt - 1.4
        if not blocked(L, a, n, ax, ab, ym) and not blocked(L, a, n, bx, ym, bt) then
          if math.abs(ax - bx) < 0.1 then
            edges[#edges + 1] = string.format("\\draw[lpedge] (%s,%s) -- (%s,%s);", f1(ax), f1(ab), f1(bx), f1(bt))
          else
            edges[#edges + 1] = string.format("\\draw[lpedge] (%s,%s) -- (%s,%s) -- (%s,%s) -- (%s,%s);",
              f1(ax), f1(ab), f1(ax), f1(ym), f1(bx), f1(ym), f1(bx), f1(bt))
          end
        else
          -- round the nodes between: down the column's left gutter, in at the node's side
          local gx = math.min(a._cx - a._w / 2, n._cx - n._w / 2) - 1.3
          local ay, by = a._y + a._h / 2, n._y + n._h / 2
          edges[#edges + 1] = string.format("\\draw[lpedge] (%s,%s) -- (%s,%s) -- (%s,%s) -- (%s,%s);",
            f1(a._cx - a._w / 2), f1(ay), f1(gx), f1(ay), f1(gx), f1(by), f1(n._cx - n._w / 2), f1(by))
        end
      else
        edges[#edges + 1] = string.format("\\draw[lpedge] (%s,%s) -- (%s,%s);", f1(a._cx + a._w / 2),
          f1(a._y + a._h / 2), f1(n._cx - n._w / 2), f1(n._y + n._h / 2))
      end
    end
  end
  table.sort(edges)
  for _, e in ipairs(edges) do o[#o + 1] = e end
  -- nodes
  local colfac = {}
  for _, c in ipairs(L.cols) do colfac[c.id] = c.faction end
  local ids = {}
  for id in pairs(L.byid) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local n = L.byid[id]
    local nf = n.faction or colfac[n.column or ""] or tfac
    local x0, x1, y0, y1 = n._cx - n._w / 2, n._cx + n._w / 2, n._y, n._y + n._h
    local tw = f1(n._w - 2)
    local img = n.portrait and portrait_path(n.portrait)
    if n.portrait then
      o[#o + 1] = string.format("\\fill[white] (%s,%s) rectangle (%s,%s);", f1(x0), f1(y0), f1(x1), f1(y1))
      if img then
        o[#o + 1] = string.format("\\node[inner sep=0pt, anchor=north] at (%s,%s) {\\includegraphics[width=11.6mm,height=11.6mm]{%s}};",
          f1(n._cx), f1(y0 + 1.2), img)
      end
      o[#o + 1] = string.format("\\draw[LPInk, line width=0.35pt] (%s,%s) rectangle (%s,%s);", f1(n._cx - 5.8),
        f1(y0 + 1.2), f1(n._cx + 5.8), f1(y0 + 12.8))
      o[#o + 1] = string.format("\\draw[lp@%s, line width=0.7pt] (%s,%s) rectangle (%s,%s);", nf, f1(x0), f1(y0), f1(x1), f1(y1))
      o[#o + 1] = string.format("\\node[lptlabel, text width=%smm, anchor=north] at (%s,%s) {%s};", tw, f1(n._cx),
        f1(y0 + 14.0), tex(n.label))
      local sub = {}
      if n.note then sub[#sub + 1] = "\\textcolor{LPMuted}{" .. tex(n.note) .. "}" end
      if n.answers then sub[#sub + 1] = "\\textcolor{FacDark}{vs " .. tex(n.answers) .. "}" end
      o[#o + 1] = string.format("\\node[lptnote, text width=%smm, anchor=south] at (%s,%s) {%s};", tw, f1(n._cx),
        f1(y1 - 1.0), table.concat(sub, "\\\\"))
    else
      local strip = (n.kind == "tech") and 1.8 or 1.2
      o[#o + 1] = string.format("\\fill[white] (%s,%s) rectangle (%s,%s);", f1(x0), f1(y0), f1(x1), f1(y1))
      o[#o + 1] = string.format("\\fill[lp@%s] (%s,%s) rectangle (%s,%s);", nf, f1(x0), f1(y0), f1(x0 + strip), f1(y1))
      local dash = (n.kind == "ability" or n.kind == "upgrade") and ", dash pattern=on 1pt off 0.8pt" or ""
      o[#o + 1] = string.format("\\draw[lp@%s@dark, line width=0.4pt%s] (%s,%s) rectangle (%s,%s);", nf, dash,
        f1(x0), f1(y0), f1(x1), f1(y1))
      local tw2 = f1(n._w - strip - 2.6)
      local tx = f1(x0 + strip + 1.1)
      -- the how-glyph leads the label; label and note in one node, so TeX's own line breaks place the note
      local glyph = ""
      if n.how and HOW[n.how] then
        glyph = string.format("\\lpbadge{lp@%s}{lp@%s@on}{%s}\\hspace{0.9mm}", nf, nf, HOW[n.how])
      end
      local sub = {}
      if n.note then sub[#sub + 1] = tex(n.note) end
      if n.answers then sub[#sub + 1] = "\\textcolor{FacDark}{vs " .. tex(n.answers) .. "}" end
      o[#o + 1] = string.format("\\node[lptlabel, align=left, text width=%smm, anchor=north west] at (%s,%s) " ..
        "{\\hyphenpenalty=10000\\exhyphenpenalty=10000 %s%s\\par\\vspace{0.7mm}{\\sffamily\\fontsize{5.4}{6.2}" ..
        "\\selectfont\\addfontfeature{Numbers=Lining}\\color{LPMuted}%s\\par}};", tw2, tx, f1(y0 + 1.2), glyph,
        tex(n.label), table.concat(sub, ", "))
    end
  end
  o[#o + 1] = "\\end{tikzpicture}" .. (o._shrink < 1 and "}}" or "")
  o._shrink = nil
  -- legend
  local legend = {}
  if type(T.legend) == "table" then
    for _, k in ipairs({"teardown", "study", "science", "capture", "spoils"}) do
      if T.legend[k] then
        legend[#legend + 1] = string.format("\\mbox{\\lpbadge{LPInk!75}{white}{%s}\\hspace{1.2mm}%s}", HOW[k],
          tex(T.legend[k]))
      end
    end
  end
  local blocks = {pandoc.RawBlock("latex", string.format("\\begin{lptree}{%s}{%s}{%s}", tfac,
    tex(T.kicker or "Tree"), tex(T.title or "")) .. "\n" .. table.concat(o, "\n"))}
  if #legend > 0 then
    blocks[#blocks + 1] = pandoc.RawBlock("latex", "\\par\\vspace{1.6mm}{\\sffamily\\fontsize{6.2}{8}\\selectfont\\color{LPMuted}" ..
      table.concat(legend, "\\hspace{3.2mm} ") .. "\\par}")
  end
  if caption_blocks and #caption_blocks > 0 then
    blocks[#blocks + 1] = pandoc.RawBlock("latex", "\\lptreecaption{")
    for _, b in ipairs(caption_blocks) do
      if b.t == "Para" or b.t == "Plain" then blocks[#blocks + 1] = pandoc.Plain(b.content) else blocks[#blocks + 1] = b end
    end
    blocks[#blocks + 1] = pandoc.RawBlock("latex", "}")
  end
  blocks[#blocks + 1] = pandoc.RawBlock("latex", "\\end{lptree}")
  return blocks
end

local function tree_html(T, caption_blocks)
  local L = layout(T)
  local cols = #L.cols
  local h = {string.format('<figure class="lp-tree"><div class="lp-tree-title">%s</div><div class="lp-tree-grid" ' ..
    'style="grid-template-columns: 6em repeat(%d, 1fr)"><div></div>', esc(T.title or ""), cols)}
  for _, c in ipairs(L.cols) do h[#h + 1] = '<div class="lp-tree-col">' .. esc(c.label) .. '</div>' end
  for _, b in ipairs(L.bands) do
    h[#h + 1] = '<div class="lp-tree-band">' .. esc(b.label) .. '</div>'
    local function card(n)
      local req = {}
      for _, r in ipairs(n.requires or {}) do req[#req + 1] = esc(L.byid[r] and L.byid[r].label or r) end
      return '<div class="lp-tree-node"><b>' .. esc(n.label) .. '</b>' ..
        (n.note and ('<small>' .. esc(n.note) .. '</small>') or "") ..
        (n.answers and ('<small>vs ' .. esc(n.answers) .. '</small>') or "") ..
        (#req > 0 and ('<small>after ' .. table.concat(req, ", ") .. '</small>') or "") .. '</div>'
    end
    if b.free then
      local inner = {}
      for _, n in ipairs(T.nodes) do if n.band == b.id then inner[#inner + 1] = card(n) end end
      h[#h + 1] = string.format('<div class="lp-tree-cell" style="grid-column: span %d">%s</div>', cols, table.concat(inner))
    else
      for _, c in ipairs(L.cols) do
        local inner = {}
        for _, n in ipairs(T.nodes) do if n.band == b.id and n.column == c.id then inner[#inner + 1] = card(n) end end
        h[#h + 1] = '<div class="lp-tree-cell">' .. table.concat(inner) .. '</div>'
      end
    end
  end
  h[#h + 1] = '</div>'
  local blocks = {pandoc.RawBlock("html", table.concat(h))}
  if caption_blocks and #caption_blocks > 0 then
    blocks[#blocks + 1] = pandoc.RawBlock("html", "<figcaption>")
    for _, b in ipairs(caption_blocks) do blocks[#blocks + 1] = b end
    blocks[#blocks + 1] = pandoc.RawBlock("html", "</figcaption>")
  end
  blocks[#blocks + 1] = pandoc.RawBlock("html", "</figure>")
  return blocks
end

-- ------------------------------------------------------------------ lore, quotes, sidebars
local function dropcap(blocks)
  for i, b in ipairs(blocks) do
    if b.t == "Para" then
      local first = b.content[1]
      if first and first.t == "Str" then
        local s = first.text
        local cap, rest = s:match("^([%z\1-\127\194-\244][\128-\191]*)(.*)$")
        if cap then
          local content = pandoc.List({pandoc.RawInline("latex", "\\lettrine{" .. tex(cap) .. "}{" .. tex(rest) .. "}")})
          for j = 2, #b.content do content:insert(b.content[j]) end
          blocks[i] = pandoc.Para(content)
        end
      end
      return blocks
    end
  end
  return blocks
end

local function wrap_latex(div, begin, finish)
  local out = {pandoc.RawBlock("latex", begin)}
  for _, b in ipairs(div.content) do out[#out + 1] = b end
  out[#out + 1] = pandoc.RawBlock("latex", finish)
  return out
end

-- The dossier: its definition list as \item[TERM] rows of the lpdossier environment. Returned as one Div so the lore's
-- drop cap (dropcap, above: the first Para of the lore) passes over it.
local function dossier_latex(div)
  local out = {pandoc.RawBlock("latex", "\\begin{lpdossier}")}
  local rows = 0
  for _, b in ipairs(div.content) do
    if b.t == "DefinitionList" then
      for _, item in ipairs(b.content) do
        local term = pandoc.write(pandoc.Pandoc({pandoc.Plain(item[1])}), "latex"):gsub("%s+$", "")
        out[#out + 1] = pandoc.RawBlock("latex", "\\item[" .. term .. "]")
        for _, def in ipairs(item[2]) do
          for _, bb in ipairs(def) do out[#out + 1] = bb end
        end
        rows = rows + 1
      end
    else
      out[#out + 1] = b
    end
  end
  if rows == 0 then quarto.log.warning("lp-manual: a dossier with no definition list (TERM, then a line ': text')") end
  out[#out + 1] = pandoc.RawBlock("latex", "\\end{lpdossier}")
  return pandoc.Div(out, {class = "lp-dossier"})
end

-- ------------------------------------------------------------------ figures: annotated plans and strips
local function inl_latex(inl) return (pandoc.write(pandoc.Pandoc({pandoc.Plain(inl)}), "latex"):gsub("%s+$", "")) end
local function inl_html(inl) return (pandoc.write(pandoc.Pandoc({pandoc.Plain(inl)}), "html"):gsub("%s+$", "")) end
local function html_src(p) return pandoc.path.make_relative(p, pandoc.path.directory(quarto.doc.input_file)) end
local function num_s(v) local n = tonumber(v) return n and string.format("%d", math.floor(n)) or tostring(v) end -- JSON 1 reads as 1.0
local function fac_color(fac) return "#" .. tostring((D.factions[fac or ""] or {}).color or "8A8E94"):gsub("#", "") end

-- A caption: the div's own paragraphs, else a fallback string.
local function caption_of(blocks, fallback)
  if blocks and #blocks > 0 then return blocks end
  if fallback and fallback ~= "" then return {pandoc.Para(pandoc.Str(fallback))} end
  return {}
end

local function latex_caption(blocks)
  if #blocks == 0 then return {} end
  local out = {pandoc.RawBlock("latex", "\\lptreecaption{")}
  for _, b in ipairs(blocks) do
    if b.t == "Para" or b.t == "Plain" then out[#out + 1] = pandoc.Plain(b.content) else out[#out + 1] = b end
  end
  out[#out + 1] = pandoc.RawBlock("latex", "}")
  return out
end

local function html_caption(blocks)
  if #blocks == 0 then return {} end
  local out = {pandoc.RawBlock("html", "<figcaption>")}
  for _, b in ipairs(blocks) do out[#out + 1] = b end
  out[#out + 1] = pandoc.RawBlock("html", "</figcaption>")
  return out
end

-- The plan: its JSON (image, width, height, caption, callouts {n, x, y, label}, x and y in the image's pixels), read
-- with the div's options:
--   crop="x0,y0,x1,y1"   print only that box of the image (in its pixels), so a small subject prints larger
--   drop="5"             leave callouts out (a point that does not show what its label says); the rest renumber
--   nudge="1:-4,-3 2:5,0" move a marker that would cover its subject or a neighbour, by mm on the page; a leader
--                         runs from the point (a small dot) to the marker
local function load_plan(a)
  local rel = a.plan
  local path = resolve(rel)
  local f = path and io.open(path, "r")
  if not f then error("lp-manual: no plan " .. tostring(rel)) end
  local ok, P = pcall(pandoc.json.decode, f:read("a"), false)
  f:close()
  if not ok or type(P) ~= "table" or not P.image or not tonumber(P.width) or not tonumber(P.height) then
    error("lp-manual: plan " .. rel .. " needs image, width and height")
  end
  P.width, P.height = tonumber(P.width), tonumber(P.height)
  P.path = pandoc.path.normalize(pandoc.path.join({pandoc.path.directory(path), P.image}))
  if not exists(P.path) then error("lp-manual: plan " .. rel .. " names an image not there: " .. P.path) end
  local box = {0, 0, P.width, P.height}
  if a.crop then
    box = {}
    for v in tostring(a.crop):gmatch("[%d.]+") do box[#box + 1] = tonumber(v) end
    if #box ~= 4 or box[1] >= box[3] or box[2] >= box[4] or box[3] > P.width or box[4] > P.height then
      error("lp-manual: plan " .. rel .. ": crop is x0,y0,x1,y1 inside the image")
    end
  end
  P.box = box
  local dropped = {}
  for v in tostring(a.drop or ""):gmatch("%d+") do dropped[tonumber(v)] = true end
  local nudge = {}
  for n, dx, dy in tostring(a.nudge or ""):gmatch("(%d+):(%-?[%d.]+),(%-?[%d.]+)") do nudge[tonumber(n)] = {tonumber(dx), tonumber(dy)} end
  table.sort(P.callouts or {}, function(p, q) return tonumber(p.n) < tonumber(q.n) end)
  local kept = {}
  for _, c in ipairs(P.callouts or {}) do
    local x, y = tonumber(c.x), tonumber(c.y)
    if not x or not y or x < box[1] or y < box[2] or x > box[3] or y > box[4] then
      error("lp-manual: plan " .. rel .. ": callout " .. num_s(c.n) .. " lies outside its image (or the crop)")
    end
    if not dropped[tonumber(c.n)] then
      kept[#kept + 1] = {x = x, y = y, label = c.label, shown = #kept + 1, nudge = nudge[tonumber(c.n)]}
    end
  end
  P.marks = kept
  return P
end

local function callouts_latex(div)
  local a = div.attributes
  local P = load_plan(a)
  local fac = a.faction or "neutral"
  local b = P.box
  local W = TEXTWIDTH * (tonumber(a.width) or 1)  -- the printed box's width
  local k = W / (b[3] - b[1])                     -- mm per image pixel
  local H = (b[4] - b[2]) * k
  local o = {string.format("\\begin{lpcallouts}{%s}\\makebox[\\linewidth]{\\begin{tikzpicture}[x=1mm,y=-1mm]", fac),
    string.format("\\begin{scope}\\clip (0,0) rectangle (%s,%s);\\node[inner sep=0pt, anchor=north west] at (%s,%s) " ..
      "{\\includegraphics[width=%smm]{%s}};\\end{scope}", f1(W), f1(H), f1(-b[1] * k), f1(-b[2] * k), f1(P.width * k), P.path)}
  for _, c in ipairs(P.marks) do
    local x, y = (c.x - b[1]) * k, (c.y - b[2]) * k
    if c.nudge then
      o[#o + 1] = string.format("\\lpleader{%s}{%s}{%s}{%s}", f1(x), f1(y), f1(x + c.nudge[1]), f1(y + c.nudge[2]))
      x, y = x + c.nudge[1], y + c.nudge[2]
    end
    o[#o + 1] = string.format("\\lpmark{%s}{%s}{%d}", f1(x), f1(y), c.shown)
  end
  o[#o + 1] = "\\end{tikzpicture}}\\par\\vspace{1.8mm}{\\raggedright\\noindent"
  local items = {}
  for _, c in ipairs(P.marks) do -- no space between them: three to a line exactly
    items[#items + 1] = string.format("\\lpcalloutitem{%d}{%s}", c.shown, tex(c.label))
  end
  o[#o + 1] = table.concat(items, "%\n") .. "\\par}"
  local blocks = {pandoc.RawBlock("latex", table.concat(o, "\n"))}
  for _, bb in ipairs(latex_caption(caption_of(div.content, P.caption))) do blocks[#blocks + 1] = bb end
  blocks[#blocks + 1] = pandoc.RawBlock("latex", "\\end{lpcallouts}")
  return blocks
end

-- HTML: the whole image (no crop, no nudges), its markers placed in percent, and the legend as an ordered list.
local function callouts_html(div)
  local a = div.attributes
  local P = load_plan(a)
  local h = {string.format('<figure class="lp-callouts" style="--fac:%s"><div class="lp-callouts-img"><img src="%s" alt="%s">',
    fac_color(a.faction), esc(html_src(P.path)), esc(P.caption or ""))}
  for _, c in ipairs(P.marks) do
    h[#h + 1] = string.format('<span class="lp-mark" style="left:%.2f%%;top:%.2f%%">%d</span>',
      100 * c.x / P.width, 100 * c.y / P.height, c.shown)
  end
  h[#h + 1] = '</div><ol class="lp-callouts-legend">'
  for _, c in ipairs(P.marks) do h[#h + 1] = "<li>" .. esc(c.label) .. "</li>" end
  h[#h + 1] = "</ol>"
  local blocks = {pandoc.RawBlock("html", table.concat(h))}
  for _, bb in ipairs(html_caption(caption_of(div.content, P.caption))) do blocks[#blocks + 1] = bb end
  blocks[#blocks + 1] = pandoc.RawBlock("html", "</figure>")
  return blocks
end

-- A strip's frames: every image in the div, in order, with its caption (the image's alt text, or its figure's
-- caption); the div's blocks that hold no image are the strip's own caption.
local function strip_parts(div)
  local frames, rest = {}, {}
  for _, b in ipairs(div.content) do
    local found = {}
    local figcap = (b.t == "Figure") and pandoc.utils.blocks_to_inlines(b.caption.long or {}) or nil
    b:walk({Image = function(im) found[#found + 1] = im end})
    if #found == 0 then rest[#rest + 1] = b end
    for _, im in ipairs(found) do
      local cap = im.caption
      if (not cap or #cap == 0) and figcap then cap = figcap end
      local p = resolve(im.src)
      if not exists(p) then error("lp-manual: strip frame not there: " .. tostring(im.src)) end
      frames[#frames + 1] = {path = p, cap = cap or pandoc.Inlines({})}
    end
  end
  if #frames < 2 then quarto.log.warning("lp-manual: a strip with fewer than two frames") end
  return frames, rest
end

local function strip_latex(div)
  local frames, rest = strip_parts(div)
  local o = {string.format("\\begin{lpstrip}{%s}{%d}\\noindent", div.attributes.faction or "neutral", #frames)}
  for i, fr in ipairs(frames) do
    o[#o + 1] = string.format("%s\\lpstripframe{%d}{%s}{%s}", i > 1 and "\\hfill" or "", i, fr.path, inl_latex(fr.cap))
  end
  o[#o + 1] = "\\par"
  local blocks = {pandoc.RawBlock("latex", table.concat(o, "\n"))}
  for _, b in ipairs(latex_caption(rest)) do blocks[#blocks + 1] = b end
  blocks[#blocks + 1] = pandoc.RawBlock("latex", "\\end{lpstrip}")
  return blocks
end

local function strip_html(div)
  local frames, rest = strip_parts(div)
  local h = {string.format('<figure class="lp-strip" style="--fac:%s"><div class="lp-strip-row">', fac_color(div.attributes.faction))}
  for i, fr in ipairs(frames) do
    h[#h + 1] = string.format('<figure><img src="%s" alt="%s"><figcaption><b>%d</b> %s</figcaption></figure>',
      esc(html_src(fr.path)), esc(pandoc.utils.stringify(fr.cap)), i, inl_html(fr.cap))
  end
  h[#h + 1] = "</div>"
  local blocks = {pandoc.RawBlock("html", table.concat(h))}
  for _, b in ipairs(html_caption(rest)) do blocks[#blocks + 1] = b end
  blocks[#blocks + 1] = pandoc.RawBlock("html", "</figure>")
  return blocks
end

local function Div(div)
  local cls = div.classes
  if cls:includes("callouts") then return is_latex() and callouts_latex(div) or (is_html() and callouts_html(div) or nil) end
  if cls:includes("strip") then return is_latex() and strip_latex(div) or (is_html() and strip_html(div) or nil) end
  if cls:includes("epigraph") then
    -- The faction's motto under the chapter's title in HTML; in print the opener page carries it already.
    -- In HTML it also shows the faction's hero, the picture the printed opener runs to the trim.
    local F = D.factions[div.attributes.faction or ""] or {}
    if not is_html() then return {} end
    local out = {}
    local hero = resolve(div.attributes.hero or F.hero)
    if hero and exists(hero) then
      out[#out + 1] = pandoc.RawBlock("html", '<img class="lp-hero" src="' .. esc(html_src(hero)) .. '" alt="">')
    end
    if F.motto then out[#out + 1] = pandoc.BlockQuote({pandoc.Para(pandoc.Emph(pandoc.Str(F.motto)))}) end
    return out
  end
  if cls:includes("dossier") then
    if is_latex() then return dossier_latex(div) end
    div.classes:insert("lp-dossier")
    return div
  end
  if is_latex() then
    if cls:includes("unit") then return unit_latex(div) end
    if cls:includes("tree") then
      local T = (D.trees or {})[div.attributes.tree or ""]
      if not T then error("lp-manual: no tree " .. tostring(div.attributes.tree) .. " in the data file") end
      if div.attributes.title then T.title = div.attributes.title end
      if div.attributes.kicker then T.kicker = div.attributes.kicker end
      return tree_latex(T, div.content)
    end
    if cls:includes("lore") then
      local a = div.attributes
      div.content = dropcap(div.content)
      local fac = a.faction and ("\\lpusefaction{" .. a.faction .. "}") or ""
      return wrap_latex(div, string.format("\\begin{lpstory}{%s}{%s}{%s}%s", tex(a.kicker or "From the archive"),
        tex(a.title or ""), tex(a.draft or ""), fac), "\\end{lpstory}")
    end
    if cls:includes("pullquote") then
      return wrap_latex(div, "\\begin{lppullquote}{" .. tex(div.attributes.cite or "") .. "}", "\\end{lppullquote}")
    end
    if cls:includes("tip") then
      return wrap_latex(div, "\\begin{lptip}{" .. tex(div.attributes.title or "") .. "}", "\\end{lptip}")
    end
    if cls:includes("fieldnote") then
      return wrap_latex(div, "\\begin{lpfieldnote}{" .. tex(div.attributes.title or "") .. "}", "\\end{lpfieldnote}")
    end
  elseif is_html() then
    if cls:includes("unit") then return unit_html(div) end
    if cls:includes("tree") then
      local T = (D.trees or {})[div.attributes.tree or ""]
      if not T then error("lp-manual: no tree " .. tostring(div.attributes.tree) .. " in the data file") end
      return tree_html(T, div.content)
    end
    for _, c in ipairs({"lore", "pullquote", "tip", "fieldnote"}) do
      if cls:includes(c) then
        div.classes:insert("lp-" .. c)
        local t = div.attributes.title
        if t and c ~= "lore" then div.content:insert(1, pandoc.Div(pandoc.Plain(pandoc.Str(t)), {class = "lp-box-title"})) end
        if c == "lore" and t then div.content:insert(1, pandoc.Header(2, t, {class = "unnumbered"})) end
        return div
      end
    end
  end
end

-- Chapters: a level-1 heading becomes the chapter (and, with .opener, the faction's opening page).
-- An opener with no epigraph of its own takes its faction's motto from the data. (The HTML book lifts a chapter's
-- heading out before filters run: there `::: {.epigraph faction="x"}` stands for it, below.)
local function chapters(blocks)
  if not is_latex() then return nil end
  local out = pandoc.List()
  local i = 1
  while i <= #blocks do
    local b = blocks[i]
    if b.t == "Header" and b.level == 1 then
      local a = b.attributes
      local fac = a.faction or "neutral"
      local title = pandoc.write(pandoc.Pandoc({pandoc.Plain(b.content)}), "latex"):gsub("%s+$", "")
      if b.classes:includes("opener") then
        local epi = a.epigraph
        if not epi and blocks[i + 1] and blocks[i + 1].t == "BlockQuote" then
          epi = pandoc.write(pandoc.Pandoc(blocks[i + 1].content), "latex"):gsub("%s+$", ""):gsub("\n\n", " ")
          i = i + 1
        elseif epi then epi = tex(epi)
        elseif (D.factions[fac] or {}).motto then epi = tex(D.factions[fac].motto) end -- the faction's motto, from the data
        local F = D.factions[fac] or {}
        local vista = resolve(a.hero or F.hero)
        if not vista or not exists(vista) then error("lp-manual: opener " .. b.identifier .. " has no hero (" .. tostring(vista) .. ")") end
        out:insert(pandoc.RawBlock("latex", string.format("\\lpopener{%s}{%s}{%s}{%s}{%s}{%s}", title, b.identifier,
          fac, vista, epi or "", tex(a.kicker or ""))))
      else
        out:insert(pandoc.RawBlock("latex", string.format("\\lpchapter{%s}{%s}{%s}{%s}", title, b.identifier, fac,
          tex(a.kicker or ""))))
      end
    else
      out:insert(b)
    end
    i = i + 1
  end
  return out
end

-- A metadata field (inlines or paragraphs) as LaTeX; paragraphs keep their breaks.
local function meta_latex(v)
  if v == nil then return "" end
  local t = pandoc.utils.type(v)
  local blocks
  if t == "Blocks" then blocks = v elseif t == "Inlines" then blocks = {pandoc.Plain(v)}
  else blocks = {pandoc.Plain(pandoc.Str(str(v)))} end
  return (pandoc.write(pandoc.Pandoc(blocks), "latex"):gsub("%s+$", ""):gsub("\n\n+", "\\par "))
end

local function add_html_dep()
  quarto.doc.add_html_dependency({name = "lp-manual", version = "0.1.0", stylesheets = {"lp-manual.css"}})
end

return {
  {
    Meta = function(meta)
      load_data(meta)
      if is_latex() then
        quarto.doc.include_text("in-header", preamble(meta))
        local blurb, small, inside = meta_latex(meta["back-blurb"]), meta_latex(meta["back-small"]), meta_latex(meta["inside-cover"])
        local edition = str(meta["edition"]) or (D.edition and tostring(D.edition)) or "" -- the data's when unset
        quarto.doc.include_text("before-body", string.format("\\lpfrontcover{%s}{%s}{%s}\\lpinsidecover{%s}",
          tex(str(meta.title) or ""), tex(str(meta.subtitle) or ""), tex(edition), inside))
        quarto.doc.include_text("after-body", string.format("\\lpbackcover{%s}{%s}", blurb, small))
      elseif is_html() then
        add_html_dep()
      end
      return meta
    end,
  },
  {Blocks = chapters},
  {Div = Div},
}
