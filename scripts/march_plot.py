"""A siege's march, second by second (tests/lp-sim standsiege writes march.jsonl): each guard's distance to the breach
(its strike's centre, else its target) over time, its paint and its fall marked; and their tracks on the ground.

    uv run --with matplotlib scripts/march_plot.py <march.jsonl> <out.png>
"""
import json
import math
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


def main(src, out):
    rows = [json.loads(l) for l in open(src) if l.strip()]
    if not rows:
        print("no rows")
        return
    t0 = rows[0]["tick"]
    center = next((r["center"] for r in rows if r.get("center")), None)
    tgt = rows[0].get("target")
    aim = center or tgt
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(16, 7))
    for r in rows:
        t = (r["tick"] - t0) / 60
        for m in r.get("members") or []:
            a1.scatter([t], [math.hypot(m[0] - aim[0], m[1] - aim[1])], s=4,
                       color={"lp-infantry": "tab:blue", "lp-tank": "tab:red", "lp-laser-drone": "tab:green"}.get(m[2], "gray"))
            a2.scatter([m[0]], [m[1]], s=2, color=plt.cm.viridis(min(1, t / max(1, (rows[-1]["tick"] - t0) / 60))))
    for key, label, c in (("paint", "paint", "orange"), ("falling", "fall", "red")):
        v = next((r[key] for r in rows if r.get(key)), None)
        if v:
            a1.axvline((v - t0) / 60, color=c, ls="--", label=label)
    phases = []
    for r in rows:
        if not phases or phases[-1][1] != r["phase"]:
            phases.append(((r["tick"] - t0) / 60, r["phase"]))
    for t, p in phases:
        a1.annotate(p, (t, a1.get_ylim()[1] if a1.get_ylim()[1] > 1 else 100), fontsize=7, rotation=90, va="top")
    a1.set_xlabel("seconds from launch")
    a1.set_ylabel("tiles from the breach" if center else "tiles from the target")
    a1.legend(fontsize=8)
    for key, mk, c in (("site", "s", "black"), ("hold", "o", "lime"), ("jump", "^", "orange")):
        v = next((r[key] for r in rows if r.get(key)), None)
        if v:
            a2.scatter([v[0]], [v[1]], marker=mk, s=80, color=c, edgecolor="black", label=key, zorder=5)
    if center:
        a2.scatter([center[0]], [center[1]], marker="x", s=100, color="red", label="breach", zorder=5)
    if tgt:
        a2.scatter([tgt[0]], [tgt[1]], marker="*", s=120, color="gold", edgecolor="black", label="target", zorder=5)
    a2.set_aspect("equal")
    a2.invert_yaxis()
    a2.legend(fontsize=8)
    a2.set_title("tracks (dark early, light late)")
    fig.savefig(out, dpi=100, bbox_inches="tight")
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
