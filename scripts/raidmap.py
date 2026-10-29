"""Each Synthexis raid on its cost map (a visit run with LP_MIX holding "marchtrace"): the price of crossing each cell
(fire, walls, deaths), no-way cells (water, forest, ground it found no way through) in black, its planned trail, the
cost map's way, where its group walked (TRACE lines of decisions.txt) and any new way it planned when taken off its own.
    uv run --with matplotlib python3 -I scripts/raidmap.py <script-output/landing-party> <out dir>
"""
import glob
import json
import math
import os
import re
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
dec = open(os.path.join(src, "decisions.txt")).read().splitlines()

walked, outcome, story = {}, {}, {}
for line in dec:
    m = re.search(r"biotech  wave (\d+): (.*)", line)
    if not m:
        continue
    n, rest = int(m[1]), m[2]
    g = re.search(r"TRACE leg \d+ to \S+: group at (-?\d+),(-?\d+)", rest)
    if g:
        walked.setdefault(n, []).append((int(g[1]), int(g[2])))
        continue
    if re.match(r"(home|lost|scattered);", rest):
        outcome[n] = re.sub(r"; gone without.*", "", rest)[:160]
    if re.match(r"(off its leg|withdraws|breach at|stages at|its way in would cost)", rest):
        story.setdefault(n, []).append(rest[:110])


def load(path):
    try:
        return json.load(open(path))
    except (OSError, ValueError):
        return None


made = []
for stage in sorted(glob.glob(os.path.join(src, "costmaps", "wave*-stage.json")), key=lambda p: int(re.search(r"wave(\d+)", p)[1])):
    st = load(stage)
    n = st["wave"]
    trail = load(os.path.join(src, "costmaps", f"wave{n}-trail.json")) or {}
    replans = [load(p) for p in sorted(glob.glob(os.path.join(src, "costmaps", f"wave{n}-replan*.json")))]
    size, x0, y0, w = st["size"], st["x0"], st["y0"], st["w"]
    grid = [[math.nan] * w for _ in range(w)]
    block = [[(0, 0, 0, 0)] * w for _ in range(w)]
    for i, j, cost, price in st["cells"]:
        if not (0 <= i < w and 0 <= j < w):
            continue
        if price < 0:
            block[j][i] = (0.1, 0.1, 0.1, 1)
        else:
            grid[j][i] = max(price, 1e-3)
    fig, ax = plt.subplots(figsize=(11, 10))
    im = ax.imshow(grid, extent=(x0, x0 + w * size, y0 + w * size, y0), cmap="YlOrRd", norm=LogNorm(vmin=0.01, vmax=100),
                   interpolation="nearest")
    fig.colorbar(im, ax=ax, shrink=0.7, label="price of crossing the cell, in its own lost (log)")
    ax.imshow(block, extent=(x0, x0 + w * size, y0 + w * size, y0), interpolation="nearest")
    ax.plot([], [], "s", color=(0.1, 0.1, 0.1), label="no way (water, forest, blocked)")
    ax.plot([], [], "s", color="white", markeredgecolor="#999", label="not reached by its search")
    tr = trail.get("trail") or []
    if tr:
        ax.plot([p[0] for p in tr], [p[1] for p in tr], "w-o", lw=2, ms=4, label="planned trail")
    if st.get("path"):
        ax.plot([p[0] for p in st["path"]], [p[1] for p in st["path"]], "c--", lw=1.5, label="cost map's way")
    for r in replans:
        if r and r.get("path"):
            ax.plot([p[0] for p in r["path"]], [p[1] for p in r["path"]], color="orange", lw=2, label=f"new way ({r['tag']})")
    if n in walked:
        ax.plot([p[0] for p in walked[n]], [p[1] for p in walked[n]], "r.", ms=5, label="its group, each second")
    if st.get("from"):
        ax.plot(*st["from"], "go", ms=10, label="where it planned from")
    if st.get("way"):
        ax.plot(*st["way"]["breach"], "kX", ms=12, label=f"where its way breaks in (costing {st['way']['cost']:.0f})")
    if st.get("target"):
        ax.plot(*st["target"], "b*", ms=16, label="its target")
    if trail.get("mark"):
        ax.plot(*trail["mark"], "m^", ms=12, label="its mark (where it breaks in)")
    ax.set_aspect("equal")
    ax.legend(loc="lower left", fontsize=8)
    ax.set_title(f"wave {n} ({trail.get('size', '?')} biters): {outcome.get(n, 'no end logged')}", fontsize=9, wrap=True)
    fig.text(0.01, 0.01, "\n".join(story.get(n, [])[:6]), fontsize=7, va="bottom", family="monospace")
    path = os.path.join(out, f"raid{n:02d}.png")
    fig.savefig(path, dpi=80, bbox_inches="tight")
    plt.close(fig)
    made.append(path)
print("\n".join(made))
