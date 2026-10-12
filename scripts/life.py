"""Animate the units of a settlement over its last snapshot: patrols, raids, convoys.

    life.py sim.jsonl life.jsonl out.gif
"""
import json
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter

sys.path.insert(0, str(Path(__file__).parent))
from plot import draw  # noqa: E402

MARK = {"lp-infantry": ("o", 14, "#1f77b4"), "lp-tank": ("s", 30, "#0b3d91"), "lp-walker": ("^", 40, "#6a3d9a"),
        "lp-harrier": ("D", 18, "#17becf"), "lp-hauler": ("P", 50, "#d35400"), "lp-trooper": ("o", 14, "#e67e22")}


def main(snaps, life, out):
    lines = [json.loads(l) for l in open(snaps) if l.strip()]
    # A faction file holds one snapshot per settlement (all drawn); a sim file one per time (the last drawn).
    bases = lines if "id" in lines[0] and len({s["id"] for s in lines}) == len(lines) else [lines[-1]]
    frames = [json.loads(l) for l in open(life) if l.strip()]
    fig, ax = plt.subplots(figsize=(8, 8))
    xs = [e[1] for b in bases for e in b["entities"]] + [u[1] for f in frames for u in f["units"]]
    ys = [e[2] for b in bases for e in b["entities"]] + [u[2] for f in frames for u in f["units"]]
    lim = (min(xs) - 20, max(xs) + 20, max(ys) + 20, min(ys) - 20)
    bases = [dict(b, entities=[e for e in b["entities"] if e[0] not in MARK]) for b in bases]

    def frame(i):
        ax.clear()
        for b in bases:
            draw(ax, b, title=False)
        f = frames[i]
        for name, x, y, force in f["units"]:
            m, s, c = MARK.get(name, ("x", 12, "k"))
            ax.scatter([x], [y], marker=m, s=s, color=c, edgecolors="white", linewidths=0.4, zorder=4)
        ax.set_xlim(lim[0], lim[1])
        ax.set_ylim(lim[2], lim[3])
        ax.set_xticks([]); ax.set_yticks([])
        ax.set_title(f"{f['tick'] / 3600:.1f} min, {len(f['units'])} units", fontsize=9)

    anim = FuncAnimation(fig, frame, frames=len(frames))
    anim.save(out, writer=PillowWriter(fps=8))
    print(f"{len(frames)} frames -> {out}")


if __name__ == "__main__":
    main(*sys.argv[1:4])
