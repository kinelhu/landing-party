"""Draw Landing Party sim snapshots: one panel per snapshot, the base over the ore it mines.

    plot.py sim.jsonl outdir
Writes outdir/growth.png (all snapshots) and outdir/final.png (the last one, larger).
"""
import json
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

ORE = {"iron-ore": "#8fa3b8", "copper-ore": "#d08a5c", "coal": "#555555", "stone": "#c9b98f"}
# name -> (size in tiles, colour)
ENT = {"lp-lander": ((15.6, 7.8), "#1f4e79"), "lp-generator": ((2, 2), "#e6b800"),
       "lp-fabricator": ((3, 3), "#2e8b57"), "lp-drill": ((3, 3), "#4a90d9"), "lp-bin": ((1, 1), "#222222"),
       "lp-turret": ((2, 2), "#c0392b"), "lp-pylon": ((0.6, 0.6), "#7f3fbf"), "lp-wall": ((1, 1), "#333333"),
       "lp-radar": ((3, 3), "#16a085"), "lp-depot": ((4, 4), "#8e44ad"), "lp-launchpad": ((9, 9), "#ff7f0e"),
       "lp-lamp": ((1, 1), "#ffe680"), "lp-mine": ((0.8, 0.8), "#b03060")}
ROAD = "#d9d4c7"
UNITS = {"lp-infantry": ("o", 6, "#1f77b4"), "lp-tank": ("s", 14, "#0b3d91"), "lp-walker": ("^", 20, "#6a3d9a"),
         "lp-harrier": ("D", 8, "#17becf")}


def draw(ax, s, title=True):
    ox, oy = s["origin"]["x"], s["origin"]["y"]
    for name, x, y, amount in s["ore"]:
        ax.add_patch(Rectangle((x - 0.5, y - 0.5), 1, 1, color=ORE.get(name, "#999"),
                               alpha=min(1.0, 0.25 + amount / 4000), lw=0))
    for x, y in s.get("roads", []):
        ax.add_patch(Rectangle((x, y), 1, 1, color=ROAD, lw=0))
    main = s.get("network")
    pylons = [(x, y) for n, x, y, *_ in s["entities"] if n == "lp-pylon"]
    for n, x, y, net, status in s["entities"]:
        if n in UNITS:
            m, size, c = UNITS[n]
            ax.scatter([x], [y], marker=m, s=size, color=c, edgecolors="white", linewidths=0.3, zorder=3)
            continue
        (w, h), c = ENT.get(n, ((1, 1), "#999"))
        if n == "lp-lander":
            ax.add_patch(Rectangle((x - 8.7, y - 3.3), w, h, color=c, lw=0))
            continue
        off = n not in ("lp-bin", "lp-pylon", "lp-wall", "lp-depot", "lp-launchpad", "lp-mine") and net != main
        ax.add_patch(Rectangle((x - w / 2, y - h / 2), w, h, facecolor="#bbbbbb" if off else c,
                               edgecolor="red" if off else "none", lw=0.8))
    # wires are not exported: draw each pylon to its nearest neighbour within reach as a hint of the graph
    for i, (x, y) in enumerate(pylons):
        best = min(((x - a) ** 2 + (y - b) ** 2, a, b) for j, (a, b) in enumerate(pylons) if j != i) if len(pylons) > 1 else None
        if best and best[0] <= 24 ** 2:
            ax.plot([x, best[1]], [y, best[2]], color="#7f3fbf", lw=0.4, alpha=0.6)
    xs = [e[1] for e in s["entities"]] + [ox]
    ys = [e[2] for e in s["entities"]] + [oy]
    pad = 25
    ax.set_xlim(min(xs) - pad, max(xs) + pad)
    ax.set_ylim(max(ys) + pad, min(ys) - pad)
    ax.set_aspect("equal")
    ax.tick_params(labelsize=6)
    if title:
        ax.set_title(f"{s['tick'] / 3600:.0f} min  {s.get('doctrine', '')} [{s.get('archetypes', '')}]  {s['rule']}  fabs {s['fabs']} drills {s['drills']}\n"
                     f"parts {s['parts']:.0f}  in {s['rate_in']:.0f}/min  {s['demand'] / 1e6:.1f}/{s['supply'] / 1e6:.1f} MW",
                     fontsize=7)


def main(path, outdir):
    snaps = [json.loads(line) for line in Path(path).read_text().splitlines() if line.strip()]
    if not snaps:
        sys.exit("no snapshots")
    out = Path(outdir)
    n = len(snaps)
    cols = min(4, n)
    rows = (n + cols - 1) // cols
    fig, axes = plt.subplots(rows, cols, figsize=(4.2 * cols, 4.2 * rows), squeeze=False)
    for ax in axes.flat:
        ax.axis("off")
    for ax, s in zip(axes.flat, snaps):
        ax.axis("on")
        draw(ax, s)
    fig.tight_layout()
    fig.savefig(out / "growth.png", dpi=110)
    fig, ax = plt.subplots(figsize=(11, 11))
    draw(ax, snaps[-1])
    fig.tight_layout()
    fig.savefig(out / "final.png", dpi=110)
    print(f"plotted {n} snapshots -> {out}/growth.png, final.png")


if __name__ == "__main__":
    main(*sys.argv[1:3])
