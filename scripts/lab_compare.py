"""The siege lab's comparison page: lane variants side by side, from their runs' records.

    uv run python3 -I scripts/lab_compare.py out.html docs/sim/lab-lab-lane-*-s*

Each run folder (scripts/siegelab.sh run, LAB_RUN_TAG=s<seed>) holds lab.jsonl (a trial a line) and lab-run.jsonl (the
fort as it stood). Runs are grouped by variant, the folder's name less its seed. Per variant: how often a wave got in, the
rams it brought, the guns and walls it broke, what it lost in mediums, guns broken per 100 lost, and how long the wall
held a wave that got in (breach to inside); each trial in order by seed; and its front drawn from the fort's own
defences, every breach point and the units' deaths on it. Self-contained HTML, no libraries.
"""
import html
import json
import math
import re
import statistics
import sys
from pathlib import Path

GUN_KINDS = [("laser", "laser-turret"), ("flame", "flamethrower-turret"), ("gun", "gun-turret"), ("rocket", "rocket-turret"),
             ("tesla", "tesla-turret")]


def load(d):
    d = Path(d)
    replay = d / "report.html"
    trials = [json.loads(l) for l in open(d / "lab.jsonl") if l.strip()]
    run = json.loads(open(d / "lab-run.jsonl").readline())
    m = re.match(r"lab-lab-lane-(.+)-s(\d+)$", d.name) or re.match(r"lab-(.+)-s(\d+)$", d.name)
    variant, seed = (m.group(1), m.group(2)) if m else (d.name, "1")
    return {"variant": variant, "seed": seed, "trials": trials, "run": run, "replay": replay if replay.exists() else None}


def trial_stats(t):
    w = t.get("wave") or {}
    sg = t.get("siege") or {}
    kills = w.get("kills") or {}
    bursts = (w.get("bursters") or {}).get("broke") or {}
    guns = sum(n for k, n in kills.items() if "turret" in k) + sum(n for k, n in bursts.items() if k.endswith("turret"))
    walls = sum(n for k, n in kills.items() if "wall" in k or "gate" in k) + bursts.get("wall", 0) + bursts.get("gate", 0)
    lost = sum((w.get("lost_worth_by") or {}).values())
    inside = w.get("t_inside") is not None
    held = (w["t_inside"] - w["t_breach"]) / 60 if inside and w.get("t_breach") else None
    return {"wave": t.get("outcome") == "wave", "inside": inside, "rams": sg.get("k", 0) if sg else 0, "guns": guns,
            "walls": walls, "lost": lost, "held": held, "size": w.get("size", 0), "breach": w.get("breach"),
            "dead": w.get("dead_at") or []}


def summary(runs):
    ts = [trial_stats(t) for r in runs for t in r["trials"]]
    waves = [s for s in ts if s["wave"]]
    n = len(ts)
    inside = [s for s in waves if s["inside"]]
    lost = sum(s["lost"] for s in waves)
    guns = sum(s["guns"] for s in waves)
    helds = [s["held"] for s in inside if s["held"] is not None]
    sieges = [s for s in waves if s["rams"] > 0]
    return {"n": n, "waves": len(waves), "held": n - len(waves), "in": len(inside), "in_rate": len(inside) / n if n else 0,
            "rams": statistics.mean(s["rams"] for s in sieges) if sieges else 0, "sieges": len(sieges),
            "guns": guns / len(waves) if waves else 0, "walls": sum(s["walls"] for s in waves) / len(waves) if waves else 0,
            "lost": lost / len(waves) if waves else 0, "exchange": 100 * guns / lost if lost else 0,
            "wall_s": statistics.median(helds) if helds else None}


def front_svg(runs):
    """The variant's front: y along, x up (the culture beyond the top), from the first run's fort."""
    defs = runs[0]["run"]["defences"]
    front = [d for d in defs if d[4] in ("wall", "gate", "land-mine", "electric-turret", "ammo-turret", "fluid-turret")]
    if not front:
        return ""
    xs = [d[1] for d in front]
    ys = [d[2] for d in defs if d[4] == "wall"] or [d[2] for d in front]
    x0, x1 = min(xs) - 4, max(xs) + 14
    y0, y1 = min(ys) - 1, max(ys) + 1
    S = 4
    W, H = (y1 - y0) * S, (x1 - x0) * S

    def px(x, y):
        return (y - y0) * S, (x1 - x) * S

    out = [f'<svg viewBox="0 0 {W:.0f} {H:.0f}" role="img" aria-label="The front, the culture beyond the top edge">',
           f'<rect width="{W:.0f}" height="{H:.0f}" class="sand"/>']
    for d in front:
        cx, cy = px(d[1], d[2])
        if d[4] in ("wall", "gate"):
            out.append(f'<rect x="{cx - S / 2:.1f}" y="{cy - S / 2:.1f}" width="{S}" height="{S}" class="wall"/>')
        elif d[4] == "land-mine":
            out.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="1.3" class="mine"/>')
    for r in runs:
        for t in r["trials"]:
            for p in trial_stats(t)["dead"]:
                cx, cy = px(p[0], p[1])
                if 0 <= cx <= W and 0 <= cy <= H:
                    out.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="1.6" class="dead"/>')
    for d in front:
        if d[4].endswith("turret"):
            kind = next((k for k, name in GUN_KINDS if name == d[0]), "laser")
            cx, cy = px(d[1], d[2])
            out.append(f'<rect x="{cx - 4:.1f}" y="{cy - 4:.1f}" width="8" height="8" rx="1.5" class="gun g-{kind}"/>')
    for r in runs:
        for t in r["trials"]:
            s = trial_stats(t)
            if s["breach"]:
                cx, cy = px(s["breach"][0], s["breach"][1])
                cy = max(7, min(H - 7, cy))
                cls = "star in" if s["inside"] else "star out"
                pts = " ".join(f"{cx + rr * math.cos(a):.1f},{cy + rr * math.sin(a):.1f}"
                               for i in range(10) for a, rr in [(-math.pi / 2 + i * math.pi / 5, 6.5 if i % 2 == 0 else 2.8)])
                out.append(f'<polygon points="{pts}" class="{cls}"><title>trial {t["trial"]}, seed {r["seed"]}: '
                           f'{"got in" if s["inside"] else "stopped"}</title></polygon>')
    out.append("</svg>")
    return "\n".join(out)


def chips(runs):
    rows = []
    for r in sorted(runs, key=lambda r: int(r["seed"])):
        cells = []
        for t in r["trials"]:
            s = trial_stats(t)
            if not s["wave"]:
                cells.append(f'<span class="chip held" title="trial {t["trial"]}: held, no wave">&ndash;</span>')
            else:
                label = f'{s["rams"]}' if s["rams"] else "r"
                tip = (f'trial {t["trial"]}: {"got in" if s["inside"] else "stopped"}, '
                       f'{s["rams"]} bursters, {s["size"]} units, broke {s["guns"]} guns and {s["walls"]} walls, lost {s["lost"]:.0f}')
                cells.append(f'<span class="chip {"in" if s["inside"] else "out"}" title="{html.escape(tip)}">{label}</span>')
        watch = (f'<a class="watch" href="replays/{html.escape(r["variant"])}-s{r["seed"]}.html">watch</a>'
                 if r.get("replay") else "")
        rows.append(f'<div class="chiprow"><span class="seed">seed {r["seed"]}</span>{"".join(cells)}{watch}</div>')
    return "\n".join(rows)


def bar(v, vmax, cls):
    w = 0 if vmax <= 0 else 100 * v / vmax
    return f'<span class="bar {cls}"><i style="width:{w:.1f}%"></i></span>'


def page(groups, src):
    sums = {v: summary(rs) for v, rs in groups.items()}
    order = sorted(groups, key=lambda v: (sums[v]["in_rate"], -sums[v]["guns"]))
    xmax = max((s["exchange"] for s in sums.values()), default=1)
    rows = []
    for v in order:
        s = sums[v]
        wall_s = "&ndash;" if s["wall_s"] is None else f'{s["wall_s"]:.0f} s'
        rows.append(
            f'<tr><th scope="row"><a href="#v-{html.escape(v)}">{html.escape(v)}</a></th>'
            f'<td class="num">{s["in"]}/{s["n"]}</td><td>{bar(s["in_rate"], 1, "b-in")}</td>'
            f'<td class="num">{s["held"]}</td><td class="num">{s["rams"]:.1f}</td>'
            f'<td class="num">{s["guns"]:.1f}</td><td class="num">{s["walls"]:.1f}</td><td class="num">{s["lost"]:.0f}</td>'
            f'<td class="num">{s["exchange"]:.1f}</td><td>{bar(s["exchange"], xmax, "b-x")}</td>'
            f'<td class="num">{wall_s}</td></tr>')
    cards = []
    for v in order:
        s = sums[v]
        lane = groups[v][0]["run"]
        guns = {}
        for d in lane["defences"]:
            if d[4].endswith("turret"):
                guns[d[0]] = guns.get(d[0], 0) + 1
        walls = sum(1 for d in lane["defences"] if d[4] == "wall")
        mines = sum(1 for d in lane["defences"] if d[4] == "land-mine")
        gl = ", ".join(f"{n} {k.replace('-turret', '')}" for k, n in sorted(guns.items(), key=lambda kv: -kv[1]))
        cards.append(f'''<section class="variant" id="v-{html.escape(v)}">
  <header><h3>{html.escape(v)}</h3><p class="fort">{gl}; {walls} wall pieces; {mines} mines</p></header>
  <div class="map">{front_svg(groups[v])}</div>
  <div class="facts">
    <div><span class="k">got in</span><span class="v">{s["in"]} of {s["n"]}</span></div>
    <div><span class="k">bursters a siege</span><span class="v">{s["rams"]:.1f}</span></div>
    <div><span class="k">guns broken a wave</span><span class="v">{s["guns"]:.1f}</span></div>
    <div><span class="k">lost a wave</span><span class="v">{s["lost"]:.0f}</span></div>
  </div>
  <div class="chips">{chips(groups[v])}</div>
</section>''')
    n_trials = sum(len(r["trials"]) for rs in groups.values() for r in rs)
    seeds = sorted({r["seed"] for rs in groups.values() for r in rs}, key=int)
    legend = "".join(f'<span><i class="sw g-{k}"></i>{k}</span>' for k, _ in GUN_KINDS)
    return f'''<title>Lane Trials</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;700&family=Source+Sans+3:wght@400;600&family=JetBrains+Mono:wght@400;600&display=swap">
<style>
/* Layout: a lab notebook; the summary table first, then one card a variant: its front drawn to scale, its trials in order. */
:root {{
  --bg: #eef0ec; --panel: #f8f9f6; --ink: #1d2320; --muted: #5b655f; --rule: #cfd5cf;
  --accent: #b5770f; --sand: #e6dcc3; --wall: #6f7772; --mine: #7a5a3a; --dead: rgba(29,35,32,.28);
  --in: #1d2320; --out: #b5770f;
  --g-laser: #c8372d; --g-flame: #7a4fc4; --g-gun: #c06d12; --g-rocket: #1f9a6a; --g-tesla: #2f6fd0;
  --display: "Barlow Condensed", "Arial Narrow", sans-serif; --body: "Source Sans 3", "Segoe UI", sans-serif;
  --data: "JetBrains Mono", ui-monospace, Menlo, monospace;
}}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{
  --bg: #161a18; --panel: #1e2321; --ink: #e5e9e6; --muted: #9aa49e; --rule: #333b37;
  --accent: #e0a23c; --sand: #2c2a22; --wall: #a0a8a3; --mine: #b89270; --dead: rgba(229,233,230,.30);
  --in: #e5e9e6; --out: #e0a23c;
  --g-laser: #e0574b; --g-flame: #9a78e6; --g-gun: #c97a22; --g-rocket: #27a070; --g-tesla: #5b8be0; color-scheme: dark }} }}
:root[data-theme="dark"] {{
  --bg: #161a18; --panel: #1e2321; --ink: #e5e9e6; --muted: #9aa49e; --rule: #333b37;
  --accent: #e0a23c; --sand: #2c2a22; --wall: #a0a8a3; --mine: #b89270; --dead: rgba(229,233,230,.30);
  --in: #e5e9e6; --out: #e0a23c;
  --g-laser: #e0574b; --g-flame: #9a78e6; --g-gun: #c97a22; --g-rocket: #27a070; --g-tesla: #5b8be0; color-scheme: dark }}
body {{ background: var(--bg); color: var(--ink); font: 15px/1.5 var(--body); }}
main {{ max-width: 1100px; margin: 0 auto; padding-block: 28px 48px;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px));
  display: grid; gap: 28px; }}
h1, h2, h3 {{ font-family: var(--display); font-weight: 700; letter-spacing: .01em; text-wrap: balance; margin: 0; }}
h1 {{ font-size: 2.4rem; line-height: 1.05; }}
h2 {{ font-size: 1.35rem; text-transform: uppercase; letter-spacing: .06em; color: var(--muted); }}
h3 {{ font-size: 1.6rem; }}
.lede {{ max-width: 68ch; color: var(--muted); margin: 6px 0 0; }}
.tablewrap {{ overflow-x: auto; background: var(--panel); border: 1px solid var(--rule); border-radius: 6px; }}
table {{ border-collapse: collapse; width: 100%; min-width: 820px; font-size: .92rem; }}
th, td {{ padding: 8px 10px; border-bottom: 1px solid var(--rule); text-align: left; white-space: nowrap; }}
thead th {{ font-family: var(--display); font-weight: 500; text-transform: uppercase; letter-spacing: .05em; color: var(--muted); font-size: .85rem; }}
tbody tr:last-child th, tbody tr:last-child td {{ border-bottom: 0; }}
tbody th a {{ color: var(--ink); font-family: var(--data); font-weight: 600; text-decoration: none; }}
tbody th a:hover, tbody th a:focus-visible {{ color: var(--accent); text-decoration: underline; }}
.num {{ font-family: var(--data); font-variant-numeric: tabular-nums; text-align: right; }}
.bar {{ display: block; width: 90px; height: 8px; background: var(--rule); border-radius: 2px; overflow: hidden; }}
.bar i {{ display: block; height: 100%; }}
.b-in i {{ background: var(--ink); }} .b-x i {{ background: var(--accent); }}
.legend {{ display: flex; flex-wrap: wrap; gap: 14px; font-size: .85rem; color: var(--muted); align-items: center; }}
.legend span {{ display: inline-flex; gap: 6px; align-items: center; }}
.sw {{ width: 10px; height: 10px; border-radius: 2px; display: inline-block; }}
.variants {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 480px), 1fr)); gap: 18px; }}
.variant {{ background: var(--panel); border: 1px solid var(--rule); border-radius: 6px; padding: 16px; display: grid; gap: 12px; min-width: 0; }}
.variant header {{ display: grid; gap: 2px; }}
.fort {{ margin: 0; color: var(--muted); font-size: .88rem; }}
.map svg {{ width: 100%; height: auto; display: block; border-radius: 3px; }}
.sand {{ fill: var(--sand); }} .wall {{ fill: var(--wall); }} .mine {{ fill: var(--mine); }} .dead {{ fill: var(--dead); }}
.gun {{ stroke: var(--panel); stroke-width: 1; }}
.g-laser {{ fill: var(--g-laser); background: var(--g-laser); }} .g-flame {{ fill: var(--g-flame); background: var(--g-flame); }}
.g-gun {{ fill: var(--g-gun); background: var(--g-gun); }} .g-rocket {{ fill: var(--g-rocket); background: var(--g-rocket); }}
.g-tesla {{ fill: var(--g-tesla); background: var(--g-tesla); }}
.star {{ stroke-width: 1.2; }} .star.in {{ fill: var(--in); stroke: var(--panel); }} .star.out {{ fill: var(--panel); stroke: var(--out); stroke-width: 1.6; }}
.facts {{ display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 8px; }}
.facts div {{ display: grid; gap: 2px; }}
.k {{ font-size: .74rem; text-transform: uppercase; letter-spacing: .06em; color: var(--muted); }}
.v {{ font-family: var(--data); font-size: 1.05rem; font-variant-numeric: tabular-nums; }}
.chips {{ display: grid; gap: 6px; }}
.chiprow {{ display: flex; flex-wrap: wrap; gap: 4px; align-items: center; }}
.seed {{ font-family: var(--data); font-size: .78rem; color: var(--muted); width: 58px; }}
.chip {{ width: 24px; height: 24px; display: inline-grid; place-items: center; border-radius: 50%; font: 600 .75rem var(--data); }}
.chip.in {{ background: var(--in); color: var(--bg); }}
.chip.out {{ background: transparent; color: var(--out); box-shadow: inset 0 0 0 2px var(--out); }}
.chip.held {{ color: var(--muted); }}
.watch {{ margin-left: 8px; font: 600 .8rem var(--data); color: var(--accent); text-decoration: none; padding: 3px 8px;
  border: 1px solid var(--accent); border-radius: 3px; }}
.watch:hover, .watch:focus-visible {{ background: var(--accent); color: var(--bg); }}
.key {{ font-size: .85rem; color: var(--muted); display: flex; flex-wrap: wrap; gap: 16px; }}
.key span {{ display: inline-flex; gap: 6px; align-items: center; }}
footer {{ color: var(--muted); font-size: .82rem; }}
code {{ font-family: var(--data); font-size: .85em; }}
@media (max-width: 560px) {{ .facts {{ grid-template-columns: repeat(2, minmax(0, 1fr)); }} h1 {{ font-size: 2rem; }} }}
</style>
<main>
  <header>
    <h1>Lane trials</h1>
    <p class="lede">Synthexis against one walled front on a ribbon map, from a culture of 8 incubators 600 tiles east.
    {len(groups)} wall variants, {len(seeds)} seeds each ({", ".join(seeds)}), {n_trials} trials in all. Each trial starts with
    the defences rebuilt and 20,000 biomass; what Synthexis learned carries over to the next trial.</p>
  </header>
  <section>
    <h2>Summary</h2>
    <div class="tablewrap"><table>
      <thead><tr><th>variant</th><th class="num">got in</th><th></th><th class="num">held</th><th class="num">bursters</th>
      <th class="num">guns broken</th><th class="num">walls broken</th><th class="num">lost</th>
      <th class="num">guns / 100 lost</th><th></th><th class="num">wall held</th></tr></thead>
      <tbody>{"".join(rows)}</tbody>
    </table></div>
    <p class="lede">Hardest first. <b>Held</b>: trials with no wave. <b>Bursters</b>: the mean a siege brought.
    <b>Guns broken</b>, <b>walls broken</b> and <b>lost</b> (in mediums, a medium biter's health a unit) are means a wave.
    <b>Guns / 100 lost</b>: the exchange, guns broken for every 100 mediums lost. <b>Wall held</b>: the median from the
    breach to the first unit inside, for waves that got in.</p>
  </section>
  <section>
    <h2>Variants</h2>
    <div class="key">
      <span><svg width="14" height="14" viewBox="0 0 14 14"><polygon class="star in" points="7,0.5 8.6,5 13.2,5 9.5,7.9 10.9,12.5 7,9.6 3.1,12.5 4.5,7.9 0.8,5 5.4,5"/></svg>breach, got in</span>
      <span><svg width="14" height="14" viewBox="0 0 14 14"><polygon class="star out" points="7,1.5 8.4,5.4 12.5,5.4 9.2,7.9 10.4,12 7,9.5 3.6,12 4.8,7.9 1.5,5.4 5.6,5.4"/></svg>breach, stopped</span>
      <span><i class="sw" style="background:var(--dead);border-radius:50%"></i>a unit died</span>
      <span><i class="sw" style="background:var(--wall)"></i>wall</span>
      <span><i class="sw" style="background:var(--mine);border-radius:50%"></i>mine</span>
      <span class="legend">{legend}</span>
    </div>
    <p class="lede">Each map: the front along, the culture beyond the top edge. Below it each trial in order by seed: a filled
    disc got in, a ring was stopped, the number is the bursters it brought (r: a raid, none). Hover a disc for its numbers;
    <b>watch</b> opens that run's replay, every wave on a time slider.</p>
    <div class="variants">{"".join(cards)}</div>
  </section>
  <footer>From <code>{html.escape(src)}</code> by <code>scripts/lab_compare.py</code>.</footer>
</main>'''


def main(out, dirs):
    groups = {}
    for d in dirs:
        if (Path(d) / "lab.jsonl").exists() and (Path(d) / "lab-run.jsonl").exists():
            r = load(d)
            groups.setdefault(r["variant"], []).append(r)
    Path(out).write_text(page(groups, " ".join(sorted({str(Path(d).parent) for d in dirs}))))
    # Each run's replay beside the page (replays/<variant>-s<seed>.html), for its watch links.
    rd = Path(out).parent / "replays"
    rd.mkdir(exist_ok=True)
    for v, rs in groups.items():
        for r in rs:
            if r.get("replay"):
                # (A page of its own beside this one: its own doctype and metas; named by its variant and seed; a way back.)
                t = r["replay"].read_text()
                name = f"Lane {v}, seed {r['seed']}"
                t = re.sub(r"<title>.*?</title>", f"<title>{html.escape(name)}</title>", t, count=1)
                t = re.sub(r"<h1>.*?</h1>", f'<h1>{html.escape(name)}</h1><p><a href="../">All lane variants</a></p>', t, count=1)
                head = ('<!doctype html><html lang="en"><meta charset="utf-8">'
                        '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">')
                (rd / f"{v}-s{r['seed']}.html").write_text(head + t)
    for v, rs in sorted(groups.items()):
        s = summary(rs)
        print(f"{v:10} in {s['in']:2}/{s['n']:2}  held {s['held']}  bursters {s['rams']:.1f}  guns {s['guns']:5.1f}  "
              f"walls {s['walls']:5.1f}  lost {s['lost']:5.0f}  guns/100 lost {s['exchange']:5.1f}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
