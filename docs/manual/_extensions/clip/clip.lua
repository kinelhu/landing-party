-- {{< clip media/clips/name.mp4 poster="media/clips/name.jpg" caption="What the clip shows." >}}
--
-- HTML: a short muted looping video with its poster frame, and the caption under it.
-- PDF (and any other format): the poster image with the caption.
-- A file that does not exist yet becomes a visible placeholder box naming the missing file,
-- so a chapter can carry its clip calls before the clips are recorded and still build.
-- Paths are relative to the book's folder (docs/manual).

local function exists(path)
  local base = quarto.project.directory or "."
  local f = io.open(base .. "/" .. path, "rb")
  if f then f:close() return true end
  return false
end

local function esc(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local function tex(s)
  return (s:gsub("\\", "\\textbackslash{}"):gsub("([#$%%&_{}])", "\\%1"))
end

local function str(v)
  return v and pandoc.utils.stringify(v) or nil
end

local function placeholder_html(missing, caption)
  return pandoc.RawBlock("html", string.format(
    '<figure class="clip clip-missing"><div class="clip-box"><span class="clip-tag">Clip to come</span>' ..
    '<code>%s</code></div><figcaption>%s</figcaption></figure>', esc(missing), esc(caption)))
end

local function placeholder_tex(missing, caption)
  return pandoc.RawBlock("latex", string.format(
    "\\par\\medskip\\noindent\\fcolorbox{AccentPrimary}{AccentLight}{\\parbox{\\dimexpr\\linewidth-2\\fboxsep-2\\fboxrule\\relax}{" ..
    "\\centering\\vspace{2.2em}{\\HeaderFont\\color{AccentPrimary}Clip to come}\\\\[0.3em]" ..
    "{\\footnotesize\\ttfamily %s}\\vspace{2.2em}}}\\par\\nopagebreak" ..
    "{\\small\\color{TextSecondary}%s}\\par\\medskip", tex(missing), tex(caption)))
end

return {
  ["clip"] = function(args, kwargs)
    local video = str(args[1]) or ""
    local poster = str(kwargs["poster"])
    if poster == "" then poster = nil end
    local caption = str(kwargs["caption"]) or ""
    if quarto.doc.is_format("html") then
      quarto.doc.add_html_dependency({name = "clip", version = "1.0.0", stylesheets = {"clip.css"}})
      if not exists(video) then return placeholder_html(video, caption) end
      local p = (poster and exists(poster)) and string.format(' poster="%s"', esc(poster)) or ""
      return pandoc.RawBlock("html", string.format(
        '<figure class="clip"><video autoplay muted loop playsinline preload="metadata"%s>' ..
        '<source src="%s" type="video/mp4"></video><figcaption>%s</figcaption></figure>', p, esc(video), esc(caption)))
    end
    -- Print: the poster frame stands for the clip.
    if not (poster and exists(poster)) then
      if quarto.doc.is_format("latex") then return placeholder_tex(poster or video, caption) end
      return pandoc.Para({pandoc.Strong(pandoc.Str("Clip to come: ")), pandoc.Code(poster or video), pandoc.Space(),
        pandoc.Str(caption)})
    end
    local img = pandoc.Image({}, poster, "", pandoc.Attr("", {}, {{"width", "100%"}}))
    return pandoc.Figure({pandoc.Plain({img})}, {pandoc.Plain(pandoc.Inlines(caption))})
  end
}
