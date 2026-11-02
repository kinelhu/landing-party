"""Kessler-Hayashi's way reading drawn (siege.lua read_ways, written with debug_tune dump_ways / visit LP_MIX=dumpways).

What reaching each cell costs from its home (its own, through every gun and worm that fires on the way, spawners and
where its own died to biters), the guns it read with their reach, each candidate target with where its way in starts,
and the cheapest way there.

    uv run --with matplotlib scripts/ways_map.py <ways-N.json> <out.png>
"""
import json
import math
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm


def main(src, out):
    d = json.load(open(src))
    size, x0, y0 = d["size"], d["x0"], d["y0"]
    fig, ax = plt.subplots(figsize=(11, 11))
    xs, ys, cs = [], [], []
    for i, j, cost, _ in d["cells"]:
        xs.append(x0 + (i + 0.5) * size)
        ys.append(y0 + (j + 0.5) * size)
        cs.append(max(cost, 0.1))
    sc = ax.scatter(xs, ys, c=cs, s=(size / 6) ** 2, marker="s", cmap="magma_r", norm=LogNorm(), linewidths=0)
    fig.colorbar(sc, ax=ax, shrink=0.7, label="what reaching it costs (its own, log)")
    for gx, gy, r in d["guns"]:
        ax.add_patch(plt.Circle((gx, gy), r, fill=False, lw=0.2, color="tab:blue", alpha=0.25))
    if d["guns"]:
        ax.scatter([g[0] for g in d["guns"]], [g[1] for g in d["guns"]], s=2, color="tab:blue", label="guns and worms read")
    hx, hy = d["home"]
    ax.scatter([hx], [hy], marker="*", s=250, color="lime", edgecolor="black", zorder=5, label="its home")
    for t in d["targets"]:
        px, py = t["pos"]
        ax.scatter([px], [py], marker="x", s=40, color="black", zorder=4)
        if t.get("start"):
            ax.scatter([t["start"][0]], [t["start"][1]], marker="o", s=20, color="cyan", edgecolor="black", zorder=4)
    # The ways to the five dearest-valued targets, and their costs.
    ranked = sorted(d["targets"], key=lambda t: -(t.get("value") or 0))[:5]
    for t in ranked:
        p = t.get("path") or []
        if len(p) > 1:
            ax.plot([q[0] for q in p], [q[1] for q in p], lw=1.2, alpha=0.8)
            ax.annotate(f'{t["kind"]} {t["start_cost"] or 0:.0f}', t["pos"], fontsize=7)
    ax.set_aspect("equal")
    ax.invert_yaxis()
    ax.set_title(f'Kessler-Hayashi\'s way reading, tick {d["tick"]}: {len(d["guns"])} guns and worms, '
                 f'{d["spawners"]} spawners and deaths')
    ax.legend(loc="lower left", fontsize=8)
    fig.savefig(out, dpi=110, bbox_inches="tight")
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
