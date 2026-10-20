"""Draw the maps the sims dump (tests/lp-sim: dump_map) as top-down schematics.

    uv run --with matplotlib scripts/campmap.py <maps dir or json files...> [--out DIR] [--zoom serenity|grubstake|all]

Each building is a dot coloured by owner (Serenity charcoal blue, Grubstake amber, the player green, biters red,
ghosts pale), its kind by marker (turrets and walls stand out); the corporations' floors underneath (Serenity's plated
roads and pads grey, the line's stripe black); Serenity's claim (dashed) and ring (dotted) drawn round its origin.
"""
import json, math, os, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OWNER = {"lp-serenity": "#3b5b7a", "lp-grubstake": "#d08a1c", "player": "#2e8b3a", "enemy": "#c0392b"}
FOOT = {"depot": 4, "launchpad": 9, "radar": 3, "fabricator": 3, "generator": 2, "turret": 2, "flamer": 2,
        "uplink": 6, "lander": 8, "drill": 3, "-lab": 3}
TILE = {"road": "#9aa3ab", "pad": "#b8bfc6", "trim": "#5c6268", "stripe": "#111111"}

def style(name, typ):
    if typ in ("ammo-turret", "electric-turret", "fluid-turret", "artillery-turret"): return "^", 16
    if typ in ("wall", "gate"): return "s", 2
    if typ in ("unit", "spider-unit", "car", "character"): return ".", 3
    if typ in ("transport-belt", "underground-belt", "splitter", "pipe", "pipe-to-ground"): return "s", 1
    if typ in ("electric-pole",): return "+", 4
    if typ == "lamp": return "*", 10
    return "s", 6

def draw(path, out_dir, zoom):
    d = json.load(open(path))
    ex = d.get("extra") or {}
    cx, cy, r = d["center"][0], d["center"][1], d["radius"]
    focus = ex.get(zoom) if zoom in ("serenity", "grubstake") else None
    if zoom.count(",") == 2:
        # --zoom x,y,r: a square of half-side r round (x, y).
        zx, zy, zr = (float(v) for v in zoom.split(","))
        focus = {"x": zx, "y": zy}
    if not focus and d["entities"]:
        # The whole map cropped to what stands on it.
        xs = [e[2] for e in d["entities"]]; ys = [e[3] for e in d["entities"]]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        r = max(max(xs) - min(xs), max(ys) - min(ys)) / 2 + 20
    if focus:
        cx, cy, r = focus["x"], focus["y"], max(120, (ex.get("perimeter") or 150) + 40) if zoom == "serenity" else 120
        if zoom.count(",") == 2: r = zr
    fig, ax = plt.subplots(figsize=(12, 12), dpi=110)
    ax.set_facecolor("#e9e2d0")
    for kind, pts in (d.get("tiles") or {}).items():
        if pts:
            xs, ys = zip(*pts)
            ax.scatter(xs, ys, s=1.2 * max(1.0, 200.0 / r) ** 2, marker="s", c=TILE.get(kind, "#888"), linewidths=0, zorder=1)
    groups = {}
    for force, name, x, y, typ in d["entities"]:
        if abs(x - cx) > r or abs(y - cy) > r: continue
        ghost = typ == "entity-ghost"
        m, s = style(name, typ)
        col = "#bbbbbb" if ghost else OWNER.get(force, "#777777")
        if name.endswith("-lab"): m, s, col = "P", 30, "#a05bd0"
        groups.setdefault((m, s, col), ([], []))
        groups[(m, s, col)][0].append(x); groups[(m, s, col)][1].append(y)
    k = max(1.0, 200.0 / r) ** 2 / 4
    if r <= 80:
        # Close up: each building at its footprint (the corporations' kinds by name; others a tile).
        import matplotlib.patches as mp
        for force, name, x, y, typ in d["entities"]:
            if abs(x - cx) > r or abs(y - cy) > r or typ in ("unit", "spider-unit", "car", "character"): continue
            base = name.split("-", 2)[-1] if name.startswith("lp-") else name
            n = next((v for key, v in FOOT.items() if name.endswith(key)), 1)
            col = "#bbbbbb" if typ == "entity-ghost" else OWNER.get(force, "#777777")
            if typ in ("wall", "gate"): col = "#1b2733" if force == "lp-serenity" else col
            if typ == "lamp": col = "#e8d870"
            if name.endswith("-lab"):
                col = "#a05bd0"
                ax.annotate(name.split("-")[-2], (x, y - 2.5), ha="center", fontsize=7, color="#5a2a80", zorder=5)
            ax.add_patch(mp.Rectangle((x - n / 2, y - n / 2), n, n, color=col, lw=0, zorder=3))
    else:
        for (m, s, col), (xs, ys) in groups.items():
            ax.scatter(xs, ys, s=s * k, marker=m, c=col, linewidths=0, zorder=3 if m == "^" else 2)
    so = ex.get("serenity")
    if so:
        for rad, ls in ((ex.get("perimeter"), "--"), (ex.get("ring"), ":")):
            if rad:
                ax.add_patch(plt.Circle((so["x"], so["y"]), rad, fill=False, ls=ls, lw=1, color=OWNER["lp-serenity"], zorder=4))
    ax.set_xlim(cx - r, cx + r); ax.set_ylim(cy + r, cy - r)  # y down, as in game
    ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([])
    ax.set_title(f"{d['label']}  (minute {d['tick'] // 3600}; Serenity blocks {ex.get('blocks')}, ring {ex.get('ring') and round(ex['ring'])}, "
                 f"line {ex.get('perimeter') and round(ex['perimeter'])})", fontsize=10)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, os.path.basename(path).replace(".json", "-" + zoom.replace(",", "_") + ".png"))
    fig.savefig(out, bbox_inches="tight"); plt.close(fig)
    print(out)

if __name__ == "__main__":
    args, out_dir, zoom, files = sys.argv[1:], "campmaps", "all", []
    i = 0
    while i < len(args):
        if args[i] == "--out": out_dir = args[i + 1]; i += 2; continue
        if args[i] == "--zoom": zoom = args[i + 1]; i += 2; continue
        p = args[i]
        files += sorted(os.path.join(p, f) for f in os.listdir(p) if f.endswith(".json")) if os.path.isdir(p) else [p]
        i += 1
    for f in files: draw(f, out_dir, zoom)
