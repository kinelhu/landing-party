"""A Synthexis rush traced through a mended wall (the herd scenario's ranks variants write rush.jsonl; the user,
2026-11-12: "is it time to break out more fine grained diagnostic tools ... I'm wary of hard coding and want to keep
this modular and adaptable"). One column a run, side by side (mend on and off, seeds):
  top     the herd by where it stands each frame (outside the outer ring, in the corridor between the rings, inside),
          the mended pieces still standing, and the wave's own decisions (its log in decisions.txt) as lines;
  bottom  the wall's frame (du out from the middle toward its face, dv along it from its gap toward the way round): the
          rings' pieces (mended ones orange), every unit's track coloured by time, the corridor's points ringed red.

    uv run --with matplotlib python3 scripts/herd_trace.py out.png <run dir> [<run dir> ...]
"""
import json
import os
import re
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

out, runs = sys.argv[1], sys.argv[2:]
KEYS = ("rush", "mend", "through", "inside", "gap", "breach", "push", "withdraw")


def frames_of(d):
    p = os.path.join(d, "rush.jsonl")
    if not os.path.exists(p):
        return []
    return [json.loads(line) for line in open(p) if line.strip()]


def events_of(d, t0, t1):
    p = os.path.join(d, "decisions.txt")
    ev = []
    if not os.path.exists(p):
        return ev
    for line in open(p):
        m = re.match(r"\s*(\d+)\s+biotech\s+wave 1: (.*)", line)
        if not m:
            continue
        t, text = int(m.group(1)), m.group(2)
        if t0 - 600 <= t <= t1 and any(k in text for k in KEYS):
            ev.append((t, text[:60]))
    return ev


fig, axes = plt.subplots(2, max(1, len(runs)), figsize=(7 * max(1, len(runs)), 11), squeeze=False)
for j, d in enumerate(runs):
    fr = frames_of(d)
    top, bot = axes[0][j], axes[1][j]
    name = os.path.basename(os.path.normpath(d))
    if not fr:
        top.set_title(f"{name}: no rush.jsonl")
        continue
    t0 = fr[0]["tick"]
    ts = [(f["tick"] - t0) / 60 for f in fr]
    counts = {c: [sum(1 for u in f["units"] if u[2] == c) for f in fr] for c in ("out", "corridor", "in")}
    top.stackplot(ts, counts["out"], counts["corridor"], counts["in"], labels=["outside", "corridor", "inside"],
                  colors=["#9aa7b8", "#d62728", "#2ca02c"], alpha=0.85)
    top.plot(ts, [f.get("mended_up", 0) for f in fr], "k--", lw=1, label="mended pieces standing")
    for t, text in events_of(d, t0, fr[-1]["tick"]):
        x = (t - t0) / 60
        top.axvline(x, color="#444", lw=0.6, alpha=0.6)
        top.text(x, top.get_ylim()[1] * 0.98, " " + text, rotation=90, va="top", ha="left", fontsize=6.5, color="#222")
    top.set_title(f"{name}: the herd by place (s from the mend)", fontsize=10)
    top.set_xlabel("s")
    top.set_ylabel("units")
    top.legend(loc="center right", fontsize=7)
    walls = fr[0].get("walls") or []
    for w in walls:
        bot.scatter(w[1], w[0], s=14, marker="s", c="#e67e22" if w[2] else "#555", zorder=1)
    xs, ys, cs, rx, ry = [], [], [], [], []
    for f in fr:
        for u in f["units"]:
            xs.append(u[1]); ys.append(u[0]); cs.append((f["tick"] - t0) / 60)
            if u[2] == "corridor":
                rx.append(u[1]); ry.append(u[0])
    sc = bot.scatter(xs, ys, s=3, c=cs, cmap="viridis", zorder=2)
    bot.scatter(rx, ry, s=18, facecolors="none", edgecolors="#d62728", lw=0.6, zorder=3)
    for y in (40.5, 46.5):
        bot.axhline(y, color="#d62728", lw=0.5, ls=":")
    bot.set_xlabel("dv: along the wall from its gap, toward the way round (tiles)")
    bot.set_ylabel("du: out from the middle (tiles); the corridor between the dotted lines")
    bot.set_title("tracks, coloured by time; mended pieces orange, the corridor ringed red", fontsize=9)
    fig.colorbar(sc, ax=bot, label="s from the mend")
fig.tight_layout()
fig.savefig(out, dpi=110)
print(out)
