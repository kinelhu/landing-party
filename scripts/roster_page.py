#!/usr/bin/env python3
"""The field roster page (docs/roster/index.html, img/): every unit with its portrait, its numbers and what fields it, and
each corporation's research tree drawn as a diagram. Written from the game's prototypes (scripts/roster.py reads the
dump), landing-party/shared.lua (read with LuaJIT), ops.lua's era thresholds and the locale; the portraits come from
the screenshot run (scripts/shots.sh writes lp-shots/roster/). Never edit the page by hand:

    scripts/check.sh && scripts/shots.sh && python3 -I scripts/roster_page.py
"""
import html, importlib.util, json, os, re, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
MOD = os.path.join(REPO, "landing-party")
OUT = os.path.join(REPO, "docs", "roster")
SHOTS = os.path.expanduser("~/Library/Application Support/factorio-lp-shots/script-output/lp-shots/roster")

spec = importlib.util.spec_from_file_location("roster", os.path.join(HERE, "roster.py"))
roster = importlib.util.module_from_spec(spec)
sys.argv = sys.argv[:1]
spec.loader.exec_module(roster)

DUMP_LUA = r'''
package.path = "./?.lua;" .. package.path
local s = require("shared")
local function dump(v)
  if type(v) == "table" then
    if #v > 0 then local p = {} for _, x in ipairs(v) do p[#p + 1] = dump(x) end return "[" .. table.concat(p, ",") .. "]" end
    local p = {}
    for k, x in pairs(v) do if type(x) ~= "function" then p[#p + 1] = string.format("%q:%s", tostring(k), dump(x)) end end
    return "{" .. table.concat(p, ",") .. "}"
  elseif type(v) == "string" then return string.format("%q", v)
  elseif type(v) == "number" or type(v) == "boolean" then return tostring(v) end
  return "null"
end
local out = {corps = {}, unlock = s.UNLOCK, units = s.units, lab_icon = s.LAB_ICON}
for corp, c in pairs(s.CORPS) do
  out.corps[corp] = {name = c.name, tree = c.tree, mix = c.mix, labs = c.labs, tint = c.tint, bases = c.bases, names = c.names}
end
print(dump(out))
'''
data = json.loads(subprocess.run(["luajit", "-e", DUMP_LUA], cwd=MOD, capture_output=True, text=True, check=True).stdout)
ops_src = open(os.path.join(MOD, "scripts", "ops.lua")).read()
ERA_TECHS = [int(x) for x in re.search(r"ERA_TECHS = \{([^}]*)\}", ops_src).group(1).split(",")]
rd_src = open(os.path.join(MOD, "scripts", "rd.lua")).read()
WINDOW_MIN = int(re.search(r"WINDOW_TICKS = (\d+) \* 3600", rd_src).group(1))

# The locale: entity names and each node's line in the corporation's voice.
locale, section = {}, None
for line in open(os.path.join(MOD, "locale", "en", "locale.cfg")):
    line = line.rstrip("\n")
    m = re.match(r"^\[(.+)\]$", line)
    if m:
        section = m.group(1); continue
    if "=" in line and section:
        k, v = line.split("=", 1)
        locale[(section, k)] = v


def ename(kind):
    return locale.get(("entity-name", kind), kind[3:].replace("-", " ").capitalize())


def voice(node_id):
    v = None
    for (sec, k), text in locale.items():
        if k == "node-" + node_id:
            v = text
    if not v:
        return ""
    return v.replace("__1__", "It").replace(" (level __2__)", "")


# What each node is called on the page (its locale line says what it does; these are names only).
NODE_NAME = {"optics": "Optics", "handloads": "Hand-loads", "warden": "Warden armour", "lance": "Lances",
             "shock": "Shock troopers", "aegis": "Aegis tanks", "hardened": "Dug in", "jammer": "Jammer mast",
             "counter": "Counter-battery", "salvage": "Salvage rights", "prospector": "Prospector's eye",
             "scrap-plating": "Scrap plating", "asbestos": "Asbestos suits", "slug": "Slug buggies",
             "sapper": "Dynamite sappers", "scavenger": "Scavenger harriers", "dozer": "Dozer", "prism": "Prism tanks",
             "tesla": "Tesla tanks", "scorcher": "Scorchers"}
BRANCH_NAME = {"optics": "Optics", "line": "Line", "siege": "Siege", "scrap-arms": "Scrap arms", "loot": "Loot",
               "wheels": "Wheels"}
KILLER = {"gun-turret": "gun turrets", "laser-turret": "laser turrets", "flamethrower-turret": "flamethrower turrets",
          "vehicle": "your vehicles", "lp-battle-tank": "battle tanks", "lp-trooper": "troopers",
          "lp-breacher": "breachers", "lp-rocket-trooper": "rocket troopers", "character": "you", "artillery-turret": "artillery turrets",
          "artillery-wagon": "artillery wagons"}


def trigger_text(t):
    if not t:
        return "climbs while nothing else is called for"
    if "killer" in t:
        who = sorted({KILLER.get(k, k) for k in t["killer"]}, key=lambda x: (x != "you", x))
        return f"{t['min']} of its units killed by {', '.join(who)} within {WINDOW_MIN} minutes"
    if "damage" in t:
        return f"{t['min']} of its units killed by {t['damage']} damage within {WINDOW_MIN} minutes"
    if "turned_back" in t:
        return f"{t['turned_back']} raids turned back for want of force"
    if "walls_met" in t:
        return f"its raids meet walls {t['walls_met']} times"
    if "mended" in t:
        return f"a siege's hits mended by your robots {'once' if t['mended'] == 1 else str(t['mended']) + ' times'}"
    return json.dumps(t)


def kind_of(node):
    if node.get("track"):
        return "track"
    if node.get("unit"):
        return "unit"
    if node.get("ability"):
        return "ability"
    if node.get("plates"):
        return "plate"
    return "node"


def effect_text(node, corp):
    if node.get("track"):
        return f"raises {', '.join(node['track'])} damage, {node.get('levels', 5)} levels"
    if node.get("unit"):
        return "fields " + ename(node["unit"]["kind"])
    if node.get("plates"):
        parts = []
        for k, p in sorted(node["plates"].items()):
            parts.append(f"{ename(corp_kind(corp, k))}: {p}")
        return "armour plates, " + "; ".join(parts)
    return ""


def corp_kind(corp, kind):
    names = data["corps"][corp].get("names") or {}
    return names.get(kind, kind)


# Portraits: the screenshot run's, made smaller, into docs/roster/img.
os.makedirs(os.path.join(OUT, "img"), exist_ok=True)
have = set()
if os.path.isdir(SHOTS):
    for f in sorted(os.listdir(SHOTS)):
        if f.endswith(".png"):
            dst = os.path.join(OUT, "img", f)
            subprocess.run(["sips", "-Z", "240", os.path.join(SHOTS, f), "--out", dst], capture_output=True, check=True)
            have.add(f[:-4])


def portrait(kind, corp=None):
    for name in ([f"lp-{corp}-{kind[3:]}"] if corp and corp != "serenity" else []) + [kind]:
        if name in have:
            return f"img/{name}.png"
    return None


stats = {r[0]: r for r in roster.rows}
esc = html.escape


def unit_card(kind, corp, how):
    r = stats.get(kind)
    if not r:
        return ""
    name, hp, speed, w, rng, rate, res, air, c, who, role = r
    img = portrait(kind, corp)
    pic = f'<img src="{img}" alt="{esc(ename(kind))}" loading="lazy">' if img else '<div class="nopic">no portrait</div>'
    return f'''<article class="unit">
  <figure>{pic}</figure>
  <div class="ubody">
    <h4>{esc(ename(kind))}</h4>
    <p class="role">{esc(role[0].upper() + role[1:] if role else "")}</p>
    <dl>
      <div><dt>Health</dt><dd>{hp:g}</dd></div><div><dt>Speed</dt><dd>{esc(speed)}</dd></div>
      <div><dt>Range</dt><dd>{rng}</dd></div><div><dt>Rate</dt><dd>{esc(rate)}</dd></div>
      <div class="wide"><dt>A shot</dt><dd>{esc(w)}</dd></div>
      <div class="wide"><dt>Resists</dt><dd>{esc(res)}</dd></div>
      <div><dt>Hits air</dt><dd>{air}</dd></div><div><dt>Cost</dt><dd>{c}{" parts" if isinstance(c, int) else ""}</dd></div>
    </dl>
    <p class="how">{esc(how)}</p>
  </div>
</article>'''


def wrap(text, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        if len(cur) + len(w) + 1 > width and cur:
            lines.append(cur); cur = w
        else:
            cur = (cur + " " + w).strip()
    if cur:
        lines.append(cur)
    return lines


def tree_svg(corp):
    c = data["corps"][corp]
    tree = c["tree"]
    branches = []
    for n in tree:
        if n["branch"] not in branches:
            branches.append(n["branch"])
    cells = {}
    for n in tree:
        era = 0 if n.get("track") else n.get("era", 0)
        cells.setdefault((n["branch"], era), []).append(n)
    max_era = max(e for (_, e) in cells)
    NW, NH, GX, GY, HEAD, LEFT = 210, 150, 22, 34, 96, 96
    width_of = {b: max(len(cells.get((b, e), [])) for e in range(max_era + 1)) or 1 for b in branches}
    xs, x = {}, LEFT
    for b in branches:
        xs[b] = x
        x += width_of[b] * (NW + GX) + 24
    W, H = x, HEAD + (max_era + 1) * (NH + GY) + 10
    pos = {}
    out = [f'<svg viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-label="{esc(c["name"])} research tree">']
    out.append('<defs><marker id="arr-' + corp + '" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
               'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" class="edgehead"/></marker></defs>')
    for e in range(max_era + 1):
        y = HEAD + e * (NH + GY)
        out.append(f'<rect x="0" y="{y - GY / 2}" width="{W}" height="{NH + GY}" class="band{e % 2}"/>')
        label = "From landing" if e == 0 else f"Era {e}"
        sub = "" if e == 0 else f"you: {ERA_TECHS[e - 1]} techs"
        out.append(f'<text x="12" y="{y + 22}" class="era">{label}</text>')
        if sub:
            out.append(f'<text x="12" y="{y + 40}" class="erasub">{sub}</text>')
    labs = c.get("labs") or {}
    for b in branches:
        bx = xs[b]
        bw = width_of[b] * (NW + GX) - GX
        out.append(f'<text x="{bx + bw / 2}" y="34" class="branch" text-anchor="middle">{esc(BRANCH_NAME.get(b, b))}</text>')
        if b in labs:
            lab = labs[b]
            img = portrait(lab)
            if img:
                out.append(f'<image href="{img}" x="{bx + bw / 2 - 74}" y="42" width="44" height="44"/>')
            out.append(f'<text x="{bx + bw / 2 - 24}" y="62" class="lab">{esc(ename(lab))}</text>')
            out.append(f'<text x="{bx + bw / 2 - 24}" y="78" class="erasub">climbs while it stands</text>')
    for (b, e), nodes in cells.items():
        for i, n in enumerate(nodes):
            nx, ny = xs[b] + i * (NW + GX), HEAD + e * (NH + GY)
            pos[n["id"]] = (nx, ny)
    for n in tree:
        if n.get("requires") and n["requires"] in pos:
            ax, ay = pos[n["requires"]]
            bx, by = pos[n["id"]]
            x1, y1, x2, y2 = ax + NW / 2, ay + NH, bx + NW / 2, by
            out.append(f'<path d="M{x1},{y1} C{x1},{y1 + 22} {x2},{y2 - 22} {x2},{y2 - 2}" class="edge" '
                       f'marker-end="url(#arr-{corp})"/>')
    for n in tree:
        nx, ny = pos[n["id"]]
        k = kind_of(n)
        out.append(f'<g class="node {k}"><rect x="{nx}" y="{ny}" width="{NW}" height="{NH}" rx="6" class="nbox"/>')
        tx = nx + 12
        if k == "unit":
            img = portrait(n["unit"]["kind"], corp)
            if img:
                out.append(f'<image href="{img}" x="{nx + NW - 66}" y="{ny + 8}" width="58" height="58"/>')
        out.append(f'<text x="{tx}" y="{ny + 22}" class="chip">{k.upper()}</text>')
        out.append(f'<text x="{tx}" y="{ny + 44}" class="ntitle">{esc(NODE_NAME.get(n["id"], n["id"]))}</text>')
        cost = f'{n["cost"]} fund' + (" a level" if n.get("track") else "")
        out.append(f'<text x="{tx}" y="{ny + 62}" class="nmeta">{esc(cost)}</text>')
        eff = effect_text(n, corp)
        yy = ny + 82
        for line in wrap(eff, 30)[:2]:
            out.append(f'<text x="{tx}" y="{yy}" class="neff">{esc(line)}</text>'); yy += 15
        trig = "when: " + trigger_text(n.get("trigger"))
        for line in wrap(trig, 32)[:3]:
            out.append(f'<text x="{tx}" y="{yy + 2}" class="ntrig">{esc(line)}</text>'); yy += 14
        out.append("</g>")
    out.append("</svg>")
    return "\n".join(out)


def fielded_text(kind, corp):
    c = data["corps"][corp]
    if kind in (c.get("mix") or {}):
        era = (data.get("unlock") or {}).get(kind, 0)
        return "From landing" if not era else f"From era {era}"
    for n in c["tree"]:
        if (n.get("unit") or {}).get("kind") == kind:
            req = f", after {NODE_NAME.get(n['requires'], n['requires'])}" if n.get("requires") else ""
            branch = BRANCH_NAME.get(n["branch"], n["branch"])
            return f"Research: {NODE_NAME.get(n['id'], n['id'])} ({branch}, era {n.get('era', 0)}{req})"
    return ""


def corp_section(corp, blurb):
    c = data["corps"][corp]
    kinds = []
    for k in (c.get("mix") or {}):
        kinds.append(corp_kind(corp, k))
    for n in c["tree"]:
        if n.get("unit"):
            kinds.append(n["unit"]["kind"])
    cards = []
    for k in kinds:
        base = k
        how = fielded_text(base if base in (c.get("mix") or {}) else base, corp)
        if not how:
            # Renamed kinds (Grubstake's infantry is the Shotgun hand).
            for orig, new in (c.get("names") or {}).items():
                if new == k:
                    how = fielded_text(orig, corp)
        cards.append(unit_card(k, corp, how))
    t = c["tint"]
    sw = f"rgb({int(t['r'] * 255)},{int(t['g'] * 255)},{int(t['b'] * 255)})"
    return f'''<section class="corp" id="{corp}" style="--corp:{sw}">
  <header class="corphead"><span class="swatch"></span><div><h2>{esc(c["name"])}</h2><p>{esc(blurb)}</p></div></header>
  <h3>Research</h3>
  <div class="tree">{tree_svg(corp)}</div>
  <h3>Units</h3>
  <div class="units">{"".join(cards)}</div>
</section>'''


player = "".join(unit_card(k, None, "Trained at your barracks; orders by beacon") for k in ("lp-trooper", "lp-breacher", "lp-rocket-trooper", "lp-battle-tank"))
shared_units = "".join(unit_card(k, None, h) for k, h in (("lp-hauler", "Both: convoys, Grubstake's building trucks"),
                                                          ("lp-railgunner", "Serenity: clears nests, never raids")))

page = f'''<title>Landing Party Field Roster</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Big+Shoulders+Display:wght@600;800&family=IBM+Plex+Sans:wght@400;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
/* Layout: a field manual. Each corporation a chapter: its research drawn as a chart by era and branch, its units as
   record cards with an in-game portrait. */
:root {{
  --bg: #eef0ee; --panel: #ffffff; --fg: #1d2326; --muted: #5d676b; --line: #c9d0d2; --band: #e4e8e8;
  --accent: #b5651d; --edge: #7d8a90;
  --display: "Big Shoulders Display", "Arial Narrow", sans-serif;
  --body: "IBM Plex Sans", "Helvetica Neue", Arial, sans-serif;
  --mono: "IBM Plex Mono", ui-monospace, Menlo, monospace;
}}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{
  --bg: #15191b; --panel: #1e2427; --fg: #e3e7e8; --muted: #9aa5a9; --line: #333c40; --band: #1a1f21;
  --accent: #e0954f; --edge: #8a989e; color-scheme: dark }} }}
:root[data-theme="dark"] {{
  --bg: #15191b; --panel: #1e2427; --fg: #e3e7e8; --muted: #9aa5a9; --line: #333c40; --band: #1a1f21;
  --accent: #e0954f; --edge: #8a989e; color-scheme: dark }}
body {{ background: var(--bg); color: var(--fg); font-family: var(--body); line-height: 1.5; }}
.wrap {{ max-width: 1180px; margin: 0 auto; padding-inline: 16px; padding-block: 28px 64px; }}
h1, h2, h3, h4 {{ font-family: var(--display); letter-spacing: 0.02em; text-wrap: balance; margin: 0; }}
h1 {{ font-size: clamp(2.2rem, 6vw, 3.6rem); font-weight: 800; text-transform: uppercase; }}
.lede {{ max-width: 68ch; color: var(--muted); margin: 10px 0 0; }}
nav {{ display: flex; flex-wrap: wrap; gap: 8px 18px; margin: 18px 0 8px; font-family: var(--mono); font-size: 0.85rem; }}
nav a {{ color: var(--fg); }}
.rules {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 12px; margin: 22px 0 8px; }}
.rules div {{ background: var(--panel); border: 1px solid var(--line); border-radius: 6px; padding: 12px 14px; font-size: 0.92rem; }}
.rules b {{ font-family: var(--display); font-size: 1.15rem; letter-spacing: 0.03em; display: block; }}
.corp {{ margin-top: 56px; }}
.corphead {{ display: flex; gap: 14px; align-items: center; border-bottom: 3px solid var(--corp); padding-bottom: 10px; }}
.corphead p {{ margin: 2px 0 0; color: var(--muted); max-width: 70ch; }}
.swatch {{ width: 36px; height: 36px; border-radius: 50%; background: var(--corp); flex: none; box-shadow: inset 0 0 0 3px var(--panel); }}
h2 {{ font-size: 2rem; font-weight: 800; }}
h3 {{ font-size: 1.3rem; font-weight: 600; text-transform: uppercase; color: var(--muted); margin: 26px 0 10px; }}
.tree {{ overflow-x: auto; background: var(--panel); border: 1px solid var(--line); border-radius: 6px; }}
.tree svg {{ display: block; font-family: var(--body); }}
.band0 {{ fill: var(--band); }} .band1 {{ fill: var(--panel); }}
.era {{ font-family: var(--display); font-size: 18px; font-weight: 600; fill: var(--fg); }}
.erasub {{ font-family: var(--mono); font-size: 11px; fill: var(--muted); }}
.branch {{ font-family: var(--display); font-size: 22px; font-weight: 800; fill: var(--fg); text-transform: uppercase; letter-spacing: 1px; }}
.lab {{ font-size: 13px; font-weight: 600; fill: var(--fg); }}
.nbox {{ fill: var(--panel); stroke: var(--line); stroke-width: 1.2; }}
.node.unit .nbox {{ stroke: var(--corp); stroke-width: 2; }}
.chip {{ font-family: var(--mono); font-size: 10px; letter-spacing: 1px; fill: var(--muted); }}
.node.unit .chip {{ fill: var(--accent); }}
.ntitle {{ font-family: var(--display); font-size: 19px; font-weight: 600; fill: var(--fg); }}
.nmeta {{ font-family: var(--mono); font-size: 11px; fill: var(--muted); }}
.neff {{ font-size: 12px; fill: var(--fg); }}
.ntrig {{ font-size: 11px; fill: var(--muted); font-style: italic; }}
.edge {{ fill: none; stroke: var(--edge); stroke-width: 1.6; }}
.edgehead {{ fill: var(--edge); }}
.units {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 340px), 1fr)); gap: 14px; }}
.unit {{ display: grid; grid-template-columns: 120px 1fr; gap: 12px; background: var(--panel); border: 1px solid var(--line);
  border-radius: 6px; padding: 12px; min-width: 0; }}
.unit figure {{ margin: 0; background: var(--band); border-radius: 4px; aspect-ratio: 1; overflow: hidden; max-width: 100%; }}
.unit img {{ width: 100%; height: 100%; object-fit: cover; display: block; }}
.nopic {{ font-size: 0.75rem; color: var(--muted); display: grid; place-items: center; height: 100%; }}
.ubody {{ min-width: 0; }}
h4 {{ font-size: 1.4rem; font-weight: 600; }}
.role {{ margin: 2px 0 8px; font-size: 0.88rem; color: var(--muted); }}
dl {{ display: grid; grid-template-columns: 1fr 1fr; gap: 4px 12px; margin: 0; font-size: 0.82rem; }}
dl div {{ min-width: 0; }} dl .wide {{ grid-column: 1 / -1; }}
dt {{ font-family: var(--mono); font-size: 0.68rem; text-transform: uppercase; letter-spacing: 0.06em; color: var(--muted); }}
dd {{ margin: 0; font-variant-numeric: tabular-nums; overflow-wrap: anywhere; }}
.how {{ margin: 10px 0 0; font-size: 0.8rem; font-family: var(--mono); color: var(--accent); }}
@media (max-width: 480px) {{ .unit {{ grid-template-columns: 84px 1fr; }} }}
footer {{ margin-top: 48px; font-size: 0.8rem; color: var(--muted); font-family: var(--mono); }}
</style>
<div class="wrap">
  <h1>Landing Party Field Roster</h1>
  <p class="lede">Every unit the corporations field and the ones you train, with what each one learns and when. Numbers are
  the game's own, one shot before research; the research charts read down by era and across by branch.</p>
  <nav><a href="#serenity">Serenity Perimeter Group</a><a href="#grubstake">Grubstake Mineral Recovery</a><a href="#yours">Your army</a><a href="#both">Shared</a></nav>
  <div class="rules">
    <div><b>Eras follow you</b>A corporation buys nothing above your era: era 1 at {ERA_TECHS[0]} technologies researched, 2 at {ERA_TECHS[1]}, 3 at {ERA_TECHS[2]}, 4 at {ERA_TECHS[3]}.</div>
    <div><b>Losses decide</b>It buys the node your play calls for: the one whose condition your fighting met hardest in the last {WINDOW_MIN} minutes. With none called for, its weapon track climbs.</div>
    <div><b>Serenity's labs</b>Each Serenity branch climbs, and fields what it gave, only while that branch's lab stands in its camp.</div>
  </div>
  {corp_section("serenity", "Precise, walled, at war from landing. Lasers and rails; it clears nests and holds a line.")}
  {corp_section("grubstake", "A thief with a fund. Shotguns, buggies and trucks; it skims, strips and raids where you are soft.")}
  <section class="corp" id="yours" style="--corp: var(--accent)">
    <header class="corphead"><span class="swatch"></span><div><h2>Your army</h2><p>Trained at a barracks, sent by beacon.</p></div></header>
    <h3>Units</h3><div class="units">{player}</div>
  </section>
  <section class="corp" id="both" style="--corp: var(--edge)">
    <header class="corphead"><span class="swatch"></span><div><h2>Shared and special</h2><p>Bodies both corporations use, and Serenity's nest clearer.</p></div></header>
    <h3>Units</h3><div class="units">{shared_units}</div>
  </section>
  <footer>Written by scripts/roster_page.py from the prototypes, shared.lua and the locale. Portraits from the screenshot run.</footer>
</div>
'''
open(os.path.join(OUT, "index.html"), "w").write(page)
print(os.path.join(OUT, "index.html"), f"{len(have)} portraits")
