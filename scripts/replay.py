"""Animate a raid from replay.jsonl (written by the assault scenario): units against the outpost.

    replay.py replay.jsonl out.gif
Also writes out-strip.png: twelve stills across the raid, for reading without playing it.
"""
import json
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter
from matplotlib.patches import Rectangle

UNIT = {"lp-infantry": ("o", 18, "#1f77b4"), "lp-tank": ("s", 60, "#0b3d91"), "lp-walker": ("^", 90, "#6a3d9a"),
        "lp-harrier": ("D", 30, "#17becf")}
OUTPOST = {"stone-wall": ((1, 1), "#555555"), "gun-turret": ((2, 2), "#c0392b"),
           "assembling-machine-1": ((3, 3), "#e6b800"), "iron-chest": ((1, 1), "#8c6d46")}


def draw(ax, f, cx, cy):
    ax.clear()
    ax.set_facecolor("#eef2e6")
    for name, x, y, hp in f["outpost"]:
        (w, h), c = OUTPOST.get(name, ((1, 1), "#999"))
        ax.add_patch(Rectangle((x - w / 2, y - h / 2), w, h, color=c, alpha=0.35 + 0.65 * hp, lw=0))
    for name, x, y, hp in f["units"]:
        m, size, c = UNIT.get(name, ("x", 20, "k"))
        ax.scatter([x], [y], marker=m, s=size, color=c, edgecolors="white", linewidths=0.5, alpha=0.4 + 0.6 * hp)
    ax.set_xlim(cx - 60, cx + 60)
    ax.set_ylim(cy + 60, cy - 60)
    ax.set_aspect("equal")
    ax.set_xticks([])
    ax.set_yticks([])
    counts = {}
    for u in f["units"]:
        counts[u[0]] = counts.get(u[0], 0) + 1
    turrets = sum(1 for e in f["outpost"] if e[0] == "gun-turret")
    ax.set_title(f"{f['tick'] / 3600:.1f} min  outpost {len(f['outpost'])} left, {turrets} turrets\n"
                 + "  ".join(f"{n[3:]} {k}" for n, k in counts.items()), fontsize=9)


def main(src, out):
    frames = [json.loads(line) for line in open(src) if line.strip()]
    if not frames:
        sys.exit("no frames")
    cx, cy = frames[0]["center"]
    fig, ax = plt.subplots(figsize=(6.5, 6.5))
    anim = FuncAnimation(fig, lambda i: draw(ax, frames[i], cx, cy), frames=len(frames))
    anim.save(out, writer=PillowWriter(fps=6))
    picks = sorted({round(k * (len(frames) - 1) / 11) for k in range(12)})
    sfig, axes = plt.subplots(2, 6, figsize=(24, 8.5))
    for a in axes.flat:
        a.axis("off")
    for a, k in zip(axes.flat, picks):
        a.axis("on")
        draw(a, frames[k], cx, cy)
    sfig.tight_layout()
    sfig.savefig(out.replace(".gif", "-strip.png"), dpi=70)
    print(f"{len(frames)} frames -> {out}")


if __name__ == "__main__":
    main(*sys.argv[1:3])
