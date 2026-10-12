"""All of the faction's settlements on one map (faction.jsonl: one snapshot per settlement).

    overview.py faction.jsonl out.png
"""
import json
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

sys.path.insert(0, str(Path(__file__).parent))
from plot import draw  # noqa: E402


def main(src, out):
    snaps = [json.loads(line) for line in open(src) if line.strip()]
    fig, ax = plt.subplots(figsize=(13, 13))
    xs, ys = [0], [0]
    for s in snaps:
        draw(ax, s, title=False)
        xs += [e[1] for e in s["entities"]]
        ys += [e[2] for e in s["entities"]]
        ax.annotate(f"{s['id']}: {s.get('doctrine')}{' (mature)' if s.get('mature') else ''}",
                    (s["origin"]["x"], s["origin"]["y"] - 30), fontsize=10, ha="center", color="#1f4e79")
    ax.plot([0], [0], marker="*", markersize=14, color="#c0392b")
    ax.annotate("player spawn", (0, 12), ha="center", fontsize=9, color="#c0392b")
    pad = 40
    ax.set_xlim(min(xs) - pad, max(xs) + pad)
    ax.set_ylim(max(ys) + pad, min(ys) - pad)
    ax.set_aspect("equal")
    ax.set_title(f"{len(snaps)} settlements at {snaps[0]['tick'] / 3600:.0f} min")
    fig.tight_layout()
    fig.savefig(out, dpi=90)
    print(f"{len(snaps)} settlements -> {out}")


if __name__ == "__main__":
    main(*sys.argv[1:3])
