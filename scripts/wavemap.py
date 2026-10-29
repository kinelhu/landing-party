"""What Synthexis saw of a base, and what its waves did there: one picture and one table per visit run (LP_MIX=waves).

    uv run --with matplotlib python3 scripts/wavemap.py <visit script-output/landing-party dir> <out dir>

Reads base.json (the player's buildings), maps.json (the value map's cells, the fire map's turrets and the soft hearts
from Synthexis's first farm, as the mod computes them: debug_base_maps) and waves.json (each wave's record: herd.lua
finish). Writes wavemap.png (the base, fire and worth as layers, the hearts numbered, each wave's breach, its way in and
where its biters died by stage) and wavemap.md (a row a wave, totals, and the checks of the assumptions the AI rests on).
Every number comes from those files; none is typed here.
"""
import json
import math
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

STAGE_COLOUR = {"march": "#f6b26b", "gather": "#f6b26b", "breach": "#e06666", "inside": "#c27ba0", "withdraw": "#ffd966",
                "blind": "#e06666", "scout": "#999999"}
SMALL = {"transport-belt", "underground-belt", "splitter", "inserter", "electric-pole", "pipe", "pipe-to-ground"}


def load(d, name, default):
    p = Path(d) / name
    return json.loads(p.read_text()) if p.exists() else default


def as_list(x):
    if x is None:
        return []
    if isinstance(x, dict):
        return [x[k] for k in sorted(x, key=lambda k: int(k) if str(k).isdigit() else str(k))]
    return x


def xy(p):
    if p is None:
        return None
    if isinstance(p, dict):
        return (p.get("x", p.get("1")), p.get("y", p.get("2")))
    return (p[0], p[1])


def main(src, out):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    base = load(src, "base.json", [])
    maps = load(src, "maps.json", {})
    waves = as_list(load(src, "waves.json", []))
    turrets = as_list(maps.get("turrets"))
    cells = as_list(maps.get("cells"))
    hearts = as_list(maps.get("hearts"))

    xs = [b[2] for b in base] or [0]
    ys = [b[3] for b in base] or [0]
    x0, x1, y0, y1 = min(xs) - 60, max(xs) + 60, min(ys) - 60, max(ys) + 60

    fig, ax = plt.subplots(figsize=(14, 14), dpi=110)
    ax.set_facecolor("#161616")
    # Fire: turrets covering each point, every 6 tiles.
    step = 6
    nx, ny = int((x1 - x0) / step) + 1, int((y1 - y0) / step) + 1
    grid = [[0] * nx for _ in range(ny)]
    for tx, ty, r in turrets:
        for j in range(max(0, int((ty - r - y0) / step)), min(ny, int((ty + r - y0) / step) + 2)):
            for i in range(max(0, int((tx - r - x0) / step)), min(nx, int((tx + r - x0) / step) + 2)):
                px, py = x0 + i * step, y0 + j * step
                if (px - tx) ** 2 + (py - ty) ** 2 <= r * r:
                    grid[j][i] += 1
    im = ax.imshow(grid, extent=(x0, x0 + nx * step, y0 + ny * step, y0), cmap="Reds", alpha=0.55, vmin=0,
                   vmax=max(4, max(max(r) for r in grid) if grid else 4), interpolation="nearest")
    fig.colorbar(im, ax=ax, fraction=0.03, pad=0.01, label="turrets covering (fire map)")
    # The buildings.
    small = [(b[2], b[3]) for b in base if b[0] in SMALL]
    big = [(b[2], b[3]) for b in base if b[0] not in SMALL and b[0] not in ("wall", "gate", "ammo-turret", "electric-turret", "fluid-turret")]
    walls = [(b[2], b[3]) for b in base if b[0] in ("wall", "gate")]
    if small:
        ax.scatter(*zip(*small), s=0.3, c="#7f7f7f", marker="s", linewidths=0)
    if walls:
        ax.scatter(*zip(*walls), s=0.6, c="#bbbbbb", marker="s", linewidths=0)
    if big:
        ax.scatter(*zip(*big), s=2.5, c="#9fc5e8", marker="s", linewidths=0, label="machines and power")
    if turrets:
        ax.scatter([t[0] for t in turrets], [t[1] for t in turrets], s=8, c="red", marker="^", linewidths=0, label="turrets")
    # Worth: the value map's cells.
    if cells:
        mw = max(c[2] for c in cells)
        ax.scatter([c[0] for c in cells], [c[1] for c in cells], s=[300 * c[2] / mw for c in cells], facecolors="none",
                   edgecolors="#6aa84f", linewidths=0.8, label="worth by cell (value map)")
    # The soft hearts.
    for k, h in enumerate(hearts):
        ax.scatter([h[0]], [h[1]], s=180, marker="*", c="#00e5ff", edgecolors="black", linewidths=0.5, zorder=5)
        ax.text(h[0] + 6, h[1] - 6, f"{k + 1}: worth {h[2]:.0f}, cost {h[3]:.0f}", color="#00e5ff", fontsize=8, zorder=6)
    # The waves.
    for k, w in enumerate(waves):
        wid = w.get("id", k + 1)
        trail = [xy(p) for p in as_list(w.get("trail"))]
        trail = [p for p in trail if p and p[0] is not None]
        if trail:
            ax.plot([p[0] for p in trail], [p[1] for p in trail], color="#cccccc", lw=0.6, alpha=0.6)
        b = xy(w.get("breach"))
        if b:
            ax.scatter([b[0]], [b[1]], s=60, facecolors="none", edgecolors="white", linewidths=1.2, zorder=4)
            ax.text(b[0] + 4, b[1] + 8, f"w{wid}", color="white", fontsize=8, zorder=6)
        d = w.get("deep")
        if d and d.get("at"):
            a = xy(d["at"])
            if b:
                ax.annotate("", xy=a, xytext=b, arrowprops={"arrowstyle": "->", "color": "#00e5ff", "lw": 0.8})
        for p in as_list(w.get("dead_at")):
            ax.scatter([p[0]], [p[1]], s=4, c=STAGE_COLOUR.get(p[2], "white"), linewidths=0, zorder=3)
    for st, c in [("march", STAGE_COLOUR["march"]), ("breach", STAGE_COLOUR["breach"]), ("inside", STAGE_COLOUR["inside"]),
                  ("withdraw", STAGE_COLOUR["withdraw"])]:
        ax.scatter([], [], s=12, c=c, label=f"its own died: {st}")
    ax.set_xlim(x0, x1)
    ax.set_ylim(y1, y0)
    ax.set_aspect("equal")
    ax.legend(loc="lower right", fontsize=8, facecolor="#333333", labelcolor="white")
    ax.set_title("What Synthexis saw of the base (fire, worth, soft hearts *) and what its waves did (o breach, -> rush)")
    fig.savefig(out / "wavemap.png", bbox_inches="tight")

    # The table.
    rows = ["| wave | sent | home | target (worth, way in, odds) | breach | heart | died: march / breach / inside / withdraw | crossing lost: expected / lost | worth razed | per own lost |",
            "|---|---|---|---|---|---|---|---|---|---|"]
    calib = [0.0, 0.0]
    tot = {"sent": 0, "home": 0, "razed": 0.0}
    by_stage = {"march": 0, "breach": 0, "inside": 0, "withdraw": 0}
    for k, w in enumerate(waves):
        lost = {"march": 0, "breach": 0, "inside": 0, "withdraw": 0}
        for key, n in (w.get("lost_by") or {}).items():
            st = key.split(" ")[0]
            st = "march" if st in ("gather", "scout") else st
            if st in lost:
                lost[st] += n
                by_stage[st] += n
        top = as_list(w.get("choice"))
        t = top[0] if top else None
        tgt = f"{t['at'][0]:.0f},{t['at'][1]:.0f} ({t['worth']:.0f}, {t['entry']}, {t['odds']:.2f})" if t else "?"
        sent, home = w.get("size", 0), w.get("left", 0)
        razed = w.get("razed_worth", 0) or 0
        lost_n = sent - home
        pred = w.get("predicted")
        crossed = w.get("crossed")
        b = xy(w.get("breach"))
        rows.append(f"| {w.get('id', k + 1)} | {sent} | {home} | {tgt} | {f'{b[0]:.0f},{b[1]:.0f}' if b else '-'} | "
                    f"{'yes' if w.get('deep') else 'no'} | {lost['march']} / {lost['breach']} / {lost['inside']} / {lost['withdraw']} | "
                    f"{(f'{pred:.0f}' if pred is not None else '-')} / {crossed if crossed is not None else '-'} | "
                    f"{razed:.0f} | {razed / lost_n if lost_n else float('inf'):.1f} |")
        if pred is not None and crossed is not None:
            calib[0] += pred
            calib[1] += crossed
        tot["sent"] += sent
        tot["home"] += home
        tot["razed"] += razed
    lost_all = tot["sent"] - tot["home"]
    checks = []
    if hearts:
        checks.append("Soft hearts (value map, from the first farm): " + "; ".join(
            f"{k + 1} at {h[0]:.0f},{h[1]:.0f} worth {h[2]:.0f} cost {h[3]:.0f}" for k, h in enumerate(hearts[:5])))
    checks.append(f"Waves {len(waves)}: sent {tot['sent']}, home {tot['home']}; worth razed {tot['razed']:.0f}, "
                  f"{tot['razed'] / lost_all if lost_all else float('inf'):.1f} a biter lost.")
    checks.append("Lost by stage: " + ", ".join(f"{k} {v}" for k, v in by_stage.items()) + ".")
    if calib[0] > 0:
        checks.append(f"Calibration of the way in (march, breach, way out; waves that broke in): expected {calib[0]:.0f} lost, "
                      f"lost {calib[1]:.0f}, ratio {calib[1] / calib[0]:.2f} (1 is right; the learned scale corrects it, know.scale).")
    # Prices learned per turret prototype at each breach (herd.lua learn_price: {proto = {sample, per, n}}).
    prices = []
    for w in waves:
        for proto, p in sorted((w.get("price") or {}).items()):
            if isinstance(p, dict) and "per" in p:
                prices.append(f"w{w.get('id')} {proto}: {p.get('sample', 0):.1f} ({p.get('n', 0)} covering) -> {p['per']:.1f}")
    if prices:
        checks.append("Prices learned at each breach, in its own (that breach -> the price now): " + "; ".join(prices) + ".")
    md = ["# Synthexis waves against one base", "", "![wavemap](wavemap.png)", "", *rows, "", *[f"- {c}" for c in checks], ""]
    (out / "wavemap.md").write_text("\n".join(md))
    print("\n".join(checks))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
