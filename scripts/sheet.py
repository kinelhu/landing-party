"""Contact sheet and shape metrics of many settlements: is there variety?

    sheet.py out.png run_dir...
Each run_dir holds a sim.jsonl; its last snapshot is drawn at a common scale. Prints per-run shape
metrics (footprint, aspect, fill, hubs, blocks, walls, roads) and their spread across runs.
"""
import json
import statistics
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

sys.path.insert(0, str(Path(__file__).parent))
from plot import draw  # noqa: E402

VIEW = 260  # tiles shown per panel


def shape(s):
    pts = [(e[1], e[2]) for e in s["entities"]] + [tuple(r) for r in s.get("roads", [])]
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    w, h = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
    occupied = {(int(x) // 4, int(y) // 4) for x, y in pts}
    return {"footprint": round((w * h) ** 0.5), "aspect": round(max(w, h) / min(w, h), 2),
            "fill": round(len(occupied) * 16 / (w * h), 2)}


def main(out, runs):
    snaps = []
    for r in runs:
        lines = (Path(r) / "sim.jsonl").read_text().splitlines()
        if lines:
            snaps.append((Path(r).name, json.loads(lines[-1])))
    cols = min(6, len(snaps))
    rows = (len(snaps) + cols - 1) // cols
    fig, axes = plt.subplots(rows, cols, figsize=(4 * cols, 4.3 * rows), squeeze=False)
    for ax in axes.flat:
        ax.axis("off")
    table = []
    for ax, (name, s) in zip(axes.flat, snaps):
        ax.axis("on")
        draw(ax, s, title=False)
        xs = [e[1] for e in s["entities"]]
        ys = [e[2] for e in s["entities"]]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        ax.set_xlim(cx - VIEW / 2, cx + VIEW / 2)
        ax.set_ylim(cy + VIEW / 2, cy - VIEW / 2)
        ax.set_xticks([]); ax.set_yticks([])
        m = shape(s)
        m.update(run=name, doctrine=s.get("doctrine"), arch=s.get("archetypes"), hubs=s.get("hubs"),
                 blocks=s.get("blocks"), walls=s.get("walls"), roads=s.get("road_tiles"))
        table.append(m)
        ax.set_title(f"{name}: {m['doctrine']} [{m['arch']}]\n{m['hubs']} hubs {m['blocks']} blocks {m['walls']} walls",
                     fontsize=8)
    fig.tight_layout()
    fig.savefig(out, dpi=80)
    cols = ["run", "doctrine", "arch", "hubs", "blocks", "walls", "roads", "footprint", "aspect", "fill"]
    w = {c: max(len(c), *(len(str(t[c])) for t in table)) for c in cols}
    print("  ".join(c.ljust(w[c]) for c in cols))
    for t in table:
        print("  ".join(str(t[c]).ljust(w[c]) for c in cols))
    for c in ["hubs", "blocks", "walls", "footprint", "aspect", "fill"]:
        v = [float(t[c]) for t in table if t[c] is not None]
        if len(v) > 1:
            print(f"{c:10s} min {min(v):7.2f}  median {statistics.median(v):7.2f}  max {max(v):7.2f}")
    print(f"doctrines: {sorted({t['doctrine'] for t in table})}  archetypes: {sorted({a for t in table for a in str(t['arch']).split(',')})}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
