"""The arena's counter heatmap (docs/arena.md, docs/arena/counters.png) from its results (docs/arena/results.jsonl).

    uv run --with matplotlib python3 -I scripts/arena_report.py docs/arena/results.jsonl docs/arena.md

A fight's score for the row's side: the share of the other side's value it destroyed minus the share of its own value it
lost, from -1 (wiped out, nothing taken) to +1 (wiped them out, lost nothing). Value is parts for the corporations'
units (both sides spend about the same) and fighters for a line of turrets or a biter wave. A pair's cell is the mean of
its fights both ways round (row from the west on Serenity's force, then the column there), so the matrix is
antisymmetric and the side and force cancel. Every number in docs/arena.md is computed here; none is typed.
"""
import json, os, sys
from collections import defaultdict

def score(r):
    a, b = r["a"], r["b"]
    lost_a = a["parts_lost"] / a["parts"] if a["parts"] else 0
    if r["kind"] == "pair":
        took = b["parts_lost"] / b["parts"] if b["parts"] else 0
    else:
        took = (b["start"] - b["left"]) / b["start"] if b["start"] else 0
    return took - lost_a

def main():
    src, out = sys.argv[1], sys.argv[2]
    rows = [json.loads(l) for l in open(src) if l.strip()]
    kinds, cost = [], {}
    for r in rows:
        if r["squad"] not in kinds: kinds.append(r["squad"])
        if r["a"]["start"]: cost[r["squad"]] = round(r["a"]["parts"] / r["a"]["start"])
    pair = defaultdict(list)
    fixed = defaultdict(list)
    fixed_cols = []
    for r in rows:
        s = score(r)
        if r["kind"] == "pair":
            pair[(r["squad"], r["against"])].append(s)
            pair[(r["against"], r["squad"])].append(-s)
        else:
            fixed[(r["squad"], r["against"])].append(s)
            if r["against"] not in fixed_cols: fixed_cols.append(r["against"])
    order_fixed = [c for c in ["biters 0.50", "biters 0.80", "biters 0.95", "guns", "lasers", "flamers"] if c in fixed_cols]
    M = {(a, b): sum(v) / len(v) for (a, b), v in pair.items()}
    F = {(a, c): sum(v) / len(v) for (a, c), v in fixed.items()}
    strength = {k: sum(M.get((k, o), 0) for o in kinds) / len(kinds) for k in kinds}
    order = sorted(kinds, key=lambda k: -strength[k])
    rounds = max(r["round"] for r in rows)

    import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
    from matplotlib.colors import TwoSlopeNorm
    counter_scale = plt.get_cmap("RdBu")   # blue: the row's unit wins; red: it loses
    names = {"biters 0.50": "biters\nevo 0.5", "biters 0.80": "biters\nevo 0.8", "biters 0.95": "biters\nevo 0.95",
             "guns": "6 gun\nturrets", "lasers": "4 laser\nturrets", "flamers": "3 flamers\n+ 2 guns"}
    n, m = len(order), len(order_fixed)
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(0.62 * (n + m) + 4, 0.5 * n + 2.6), dpi=130,
                                   gridspec_kw={"width_ratios": [n, m]})
    norm = TwoSlopeNorm(vmin=-1, vcenter=0, vmax=1)
    for ax, cols, get, title in ((ax1, order, lambda a, b: M.get((a, b)), "against each other (equal spend)"),
                                 (ax2, order_fixed, lambda a, c: F.get((a, c)), "against biters and your lines")):
        grid = [[get(a, c) if get(a, c) is not None else float("nan") for c in cols] for a in order]
        ax.imshow(grid, cmap=counter_scale, norm=norm, aspect="auto")
        for i, a in enumerate(order):
            for j, c in enumerate(cols):
                v = grid[i][j]
                if v == v:
                    ax.text(j, i, f"{round(100 * v)}", ha="center", va="center", fontsize=6.5,
                            color="white" if abs(v) > 0.6 else "black")
        ax.set_xticks(range(len(cols)))
        ax.set_xticklabels([names.get(c, c) for c in cols], rotation=90 if ax is ax1 else 0, fontsize=7.5)
        ax.xaxis.tick_top()
        ax.set_yticks(range(n))
        ax.set_yticklabels([f"{a} ({cost.get(a, '?')})" for a in order] if ax is ax1 else [], fontsize=8)
        ax.set_xlabel(title, fontsize=9, labelpad=8)
        ax.xaxis.set_label_position("bottom")
    fig.suptitle("Landing Party: who counters whom (row against column; blue, the row wins; red, it loses)", fontsize=10, y=0.995)
    fig.text(0.01, 0.005, f"Score: share of the other side destroyed minus share of its own lost (x100). Price in parts in "
             f"brackets. {len(rows)} fights, {rounds} rounds, no research. scripts/arena.sh", fontsize=7)
    fig.tight_layout(rect=(0, 0.02, 1, 0.97))
    img = os.path.join(os.path.dirname(out), "arena", "counters.png")
    fig.savefig(img)

    L = ["# The arena: who counters whom (generated)", "",
         f"Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` ({len(rows)} fights, {rounds} rounds; "
         "`scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.", "",
         "![Counter heatmap](arena/counters.png)", "",
         "Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both "
         "ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). "
         "A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, "
         "from -100 (wiped out, took nothing) to +100. Rows run from the strongest against the others on average.", "",
         "## Each kind's counters", "",
         "| Kind (price) | Beats most (its score) | Beaten most by (their score) |", "|---|---|---|"]
    for a in order:
        others = [(b, M[(a, b)]) for b in kinds if b != a and (a, b) in M]
        best = sorted(others, key=lambda x: -x[1])[:3]
        worst = sorted(others, key=lambda x: x[1])[:3]
        fmt = lambda xs, sign: ", ".join(f"{b} ({round(100 * sign * v)})" for b, v in xs)
        L.append(f"| {a} ({cost.get(a, '?')}) | {fmt(best, 1)} | {fmt(worst, -1)} |")
    L.append("")
    open(out, "w").write("\n".join(L))
    print(f"wrote {out} and {img}: {len(rows)} fights")

if __name__ == "__main__":
    main()
