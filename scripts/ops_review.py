"""Operation review (the user, 2026-10-25: a tool to reconstruct each raid, siege and wave): one panel per operation from
ops.jsonl (landing-party/scripts/oplog.lua), with where it set out from, its target, its staging point or mark, the way
it planned, where its units went (their middle each sample, coloured by time, and every unit faintly), where each died,
what they destroyed, and how it ended; and a table of them all.

Run: uv run --with matplotlib python3 -I scripts/ops_review.py <ops.jsonl> <out dir>
"""
import html
import json
import os
import sys
from collections import Counter

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

WHO = {"serenity": "Kessler-Hayashi", "grubstake": "Grubstake", "biotech": "Synthexis"}
COLOUR = {"serenity": "#2f6f86", "grubstake": "#b0651a", "biotech": "#8a9e00"}
VICTIM = {"player": "yours", "lp-serenity": "Kessler-Hayashi's", "lp-grubstake": "Grubstake's", "lp-biotech": "Synthexis's",
          "enemy": "biters'", "neutral": "neutral"}


def plain(name):
    return (name[3:] if name.startswith("lp-") else name).replace("-", " ")


def panel(op, path):
    fig, ax = plt.subplots(figsize=(6.4, 6.4), dpi=100)
    xs, ys = [], []
    def add(p):
        if p:
            xs.append(p[0]); ys.append(p[1])
    for k in ("camp", "target", "staging", "breach"):
        add(op.get(k))
    route = op.get("route") or []
    for p in route:
        add(p)
    cmap = plt.get_cmap("viridis")
    samples = [s for s in op.get("samples") or [] if s.get("p")]
    n = max(1, len(samples) - 1)
    mids = []
    for i, s in enumerate(samples):
        pts = s["p"]
        for p in pts:
            add(p)
        ax.scatter([p[0] for p in pts], [p[1] for p in pts], s=2, color=cmap(i / n), alpha=0.25, lw=0)
        mids.append((sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)))
    for i in range(1, len(mids)):
        ax.plot([mids[i - 1][0], mids[i][0]], [mids[i - 1][1], mids[i][1]], color=cmap(i / n), lw=2)
    if route:
        ax.plot([p[0] for p in route], [p[1] for p in route], "--", color="#555", lw=1, label="planned way")
    c = COLOUR.get(op["faction"], "#444")
    if op.get("camp"):
        ax.plot(*op["camp"], "s", color=c, ms=10, label="set out from")
    if op.get("target"):
        ax.plot(*op["target"], "*", color="#c0392b", ms=16, label="target")
    if op.get("staging"):
        ax.plot(*op["staging"], "^", color="#333", ms=9, label="staging / mark")
    if op.get("breach"):
        ax.plot(*op["breach"], "P", color="#333", ms=9, label="breach")
    deaths = op.get("deaths") or []
    for d in deaths:
        add(d["at"])
    if deaths:
        ax.scatter([d["at"][0] for d in deaths], [d["at"][1] for d in deaths], marker="x", color="#c0392b", s=22,
                   label=f"its dead ({len(deaths)})")
    kills = op.get("kills") or []
    for k in kills:
        add(k["at"])
    if kills:
        ax.scatter([k["at"][0] for k in kills], [k["at"][1] for k in kills], marker="o", facecolor="none",
                   edgecolor="#111", s=26, label=f"it destroyed ({len(kills)})")
    if xs:
        pad = 30
        x0, x1, y0, y1 = min(xs) - pad, max(xs) + pad, min(ys) - pad, max(ys) + pad
        span = max(x1 - x0, y1 - y0)
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        ax.set_xlim(cx - span / 2, cx + span / 2)
        ax.set_ylim(cy + span / 2, cy - span / 2)   # north up, as on the game's map
    ax.set_aspect("equal")
    ax.tick_params(labelsize=7)
    ax.legend(fontsize=7, loc="best")
    ax.set_title(f"{WHO.get(op['faction'], op['faction'])} {op['kind']} {op['key']}: {op.get('outcome') or '?'}\n"
                 f"minute {op.get('t0', 0):.0f} to {op.get('end', 0):.0f}; its units' path coloured by time (dark first)",
                 fontsize=8)
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(os.path.join(out, "img"), exist_ok=True)
    ops = [json.loads(l) for l in open(src) if l.strip()]
    rows, sections = [], []
    for op in ops:
        key = op["key"].replace(":", "-")
        panel(op, os.path.join(out, "img", f"op-{key}.png"))
        kills = Counter(f"{VICTIM.get(k['force'], k['force'])} {plain(k['name'])}" for k in op.get("kills") or [])
        killers = Counter(plain(d["killer"]) for d in op.get("deaths") or [])
        broke = ", ".join(f"{n} {k}" for k, n in kills.most_common(6)) or "nothing"
        died = ", ".join(f"{n} to {k}" for k, n in killers.most_common(4)) or "none"
        dur = (op.get("end") or 0) - (op.get("t0") or 0)
        rows.append(f"<tr><td><a href='#{key}'>{html.escape(op['key'])}</a></td><td>{WHO.get(op['faction'], op['faction'])}</td>"
                    f"<td>{op['kind']}</td><td>{op.get('target_kind') or ''}</td><td>{op.get('t0', 0):.0f}</td><td>{dur:.0f}</td>"
                    f"<td>{op.get('size', 0)}</td><td>{len(op.get('deaths') or [])}</td><td>{op.get('back') if op.get('back') is not None else '?'}</td>"
                    f"<td>{len(op.get('kills') or [])}</td><td>{html.escape(op.get('outcome') or '?')}</td></tr>")
        sections.append(f"<section id='{key}'><h3>{html.escape(op['key'])}: {WHO.get(op['faction'], op['faction'])} "
                        f"{op['kind']}, {html.escape(op.get('outcome') or '?')}</h3><p>{op.get('size', 0)} set out, "
                        f"{op.get('back') if op.get('back') is not None else '?'} back. Destroyed: {html.escape(broke)}. Its dead: "
                        f"{html.escape(died)}.</p><img src='img/op-{key}.png' alt='operation {html.escape(op['key'])}'></section>")
    page = f'''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Operation Review</title>
<style>
:root {{ --bg: #f4f5f4; --fg: #1d2326; --muted: #5d676b; --line: #ccd2d4; }}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{ --bg: #16191b; --fg: #e3e7e8; --muted: #9aa5a9; --line: #333c40; }} }}
:root[data-theme="dark"] {{ --bg: #16191b; --fg: #e3e7e8; --muted: #9aa5a9; --line: #333c40; }}
body {{ background: var(--bg); color: var(--fg); font: 15px/1.45 system-ui, sans-serif; margin: 0; }}
main {{ max-width: 1100px; margin: 0 auto; padding: 20px 16px 60px; }}
table {{ border-collapse: collapse; font-size: 13px; font-variant-numeric: tabular-nums; }}
td, th {{ border-bottom: 1px solid var(--line); padding: 3px 8px; text-align: left; }}
.scroll {{ overflow-x: auto; }} img {{ max-width: 100%; background: #fff; border: 1px solid var(--line); border-radius: 4px; }}
section {{ margin-top: 28px; }} p {{ color: var(--muted); }}
</style>
<main><h1>Operation review</h1>
<p>Every raid, siege and strip camp of the corporations and every Synthexis wave, from launch to end
(landing-party/scripts/oplog.lua, drawn by scripts/ops_review.py).</p>
<div class="scroll"><table><tr><th>op</th><th>who</th><th>kind</th><th>target</th><th>min</th><th>for</th><th>set out</th>
<th>dead</th><th>back</th><th>destroyed</th><th>outcome</th></tr>{"".join(rows)}</table></div>
{"".join(sections)}</main>'''
    open(os.path.join(out, "index.html"), "w").write(page)
    print(f"wrote {out}/index.html: {len(ops)} operations")


if __name__ == "__main__":
    main()
