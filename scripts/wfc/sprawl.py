"""Grubstake's sprawl (WFC on 12x12 lots, scripts/wfc/grubstake.tiles): a preview sheet, before anything goes in game.

    uv run --with matplotlib python3 -I scripts/wfc/sprawl.py scripts/wfc/grubstake.tiles OUT.png [--n 9] [--size 9] [--lots 16] [--seed 1]

The tiles' parsing, turning and mirroring are wfc.py's (its SIZE and BUILD set here). Two lots fit where their touching
edges agree; outside the camp's mask any edge fits (a track runs off into the wild). A camp passes when its tracks are
one network reaching the middle lot, and every lot with a machine stands on it.
"""
import math, os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wfc as W

SIZE = 12
W.SIZE = SIZE
W.BUILD = {"D": (4, 4), "F": (3, 3), "G": (2, 2), "R": (3, 3), "K": (3, 3), "T": (2, 2), "V": (2, 2), "W": (2, 2),
           "X": (1, 1), "C": (1, 1), "P": (1, 1), "L": (1, 1), "O": (2, 2), "I": (1, 1)}
MACHINES = set("DFGRK")
STEP = {"n": (0, -1), "s": (0, 1), "e": (1, 0), "w": (-1, 0)}
OPP = {"n": "s", "s": "n", "e": "w", "w": "e"}


def compat(vs):
    return {(i, d): {j for j, b in enumerate(vs) if a["edge"][d] == b["edge"][OPP[d]]} for i, a in enumerate(vs) for d in "nsew"}


def solve(vs, cm, w, h, mask, rng, budget=4000):
    """Depth-first, the most constrained cell first; outside the mask a cell is outside (fits anything)."""
    allv = set(range(len(vs)))
    dom = {(x, y): set(allv) for y in range(h) for x in range(w) if mask(x, y)}

    def propagate(dom, stack):
        while stack:
            p = stack.pop()
            for d, (dx, dy) in STEP.items():
                q = (p[0] + dx, p[1] + dy)
                if q not in dom: continue
                ok = set().union(*(cm[(i, d)] for i in dom[p]))
                nd = dom[q] & ok
                if nd != dom[q]:
                    if not nd: return False
                    dom[q] = nd; stack.append(q)
        return True

    if not propagate(dom, list(dom)): return None
    steps = [0]

    def search(dom):
        open_ = [(len(s), k) for k, s in dom.items() if len(s) > 1]
        if not open_: return {k: next(iter(s)) for k, s in dom.items()}
        n = min(o[0] for o in open_)
        k = rng.choice(sorted(o[1] for o in open_ if o[0] == n))
        for pick in sorted(dom[k], key=lambda i: -rng.random() ** (1.0 / vs[i]["w"])):
            steps[0] += 1
            if steps[0] > budget: return None
            d2 = {c: set(s) for c, s in dom.items()}
            d2[k] = {pick}
            if propagate(d2, [k]):
                r = search(d2)
                if r: return r
        return None

    return search(dom)


def validate(vs, sol, w, h):
    mid = (w // 2, h // 2)
    track = {k for k, i in sol.items() if any(":" in e for e in vs[i]["edge"].values())}
    if mid not in track: return "no track at the middle"
    seen, st = {mid}, [mid]
    while st:
        p = st.pop()
        for d, (dx, dy) in STEP.items():
            q = (p[0] + dx, p[1] + dy)
            if q in track and q not in seen and ":" in vs[sol[p]]["edge"][d]: seen.add(q); st.append(q)
    if track - seen: return "tracks in two networks"
    for k, i in sol.items():
        beside = any((k[0] + dx, k[1] + dy) in seen for dx, dy in STEP.values())
        if any(c in MACHINES for r in vs[i]["rows"] for c in r) and k not in seen and not beside:
            return "a machine away from the streets"
    machines = sum(1 for i in sol.values() for r in vs[i]["rows"] for c in r if c in MACHINES)
    if machines < 6: return "too few machines"
    return None


CORE = {"depot", "depot_fab", "depot_pair", "fab_row", "fab", "power", "tankfarm", "stockpile", "radar"}
FRINGE = {"end_nest", "scrap", "orepile", "parking", "straight", "empty"}


def opens(v):
    return frozenset(d for d in "nsew" if ":" in v["edge"][d])


def grow(vs, n, lots, rng):
    """Its streets as a tree (the user wanted a sprawl that never blocks: no enclosed block, no ladder of parallel
    streets): from a crossing at the middle, an open street end is taken (nearer the middle first, by chance) and
    extends one lot: on (a straight), a turn, a branch (a tee), or a stop (the end of the street; at the fringe, a
    turret nest). A new street lot may touch no street but the one it comes from. Then each lot gets a variant with
    exactly its openings, by weight; the lots beside a street get yards (scrap, stores) or stay empty."""
    mid = (n // 2, n // 2)
    street = {mid: set("nsew")}
    ends = [(mid, d) for d in "nsew"]
    def free(q, came):
        if q in street or not (0 <= q[0] < n and 0 <= q[1] < n): return False
        for d, (dx, dy) in STEP.items():
            r = (q[0] + dx, q[1] + dy)
            if r in street and r != came: return False
        return True
    while ends and len(street) < lots:
        ends.sort(key=lambda e: abs(e[0][0] - mid[0]) + abs(e[0][1] - mid[1]) + rng.random() * 3)
        p, d = ends.pop(0)
        dx, dy = STEP[d]
        q = (p[0] + dx, p[1] + dy)
        if not free(q, p):
            street[p].discard(d)
            continue
        back = OPP[d]
        side = [x for x in "nsew" if x not in (d, back)]
        r = rng.random()
        if r < 0.55: out = {d}
        elif r < 0.75: out = {rng.choice(side)}
        elif r < 0.92: out = {d, rng.choice(side)}
        else: out = set()
        street[q] = {back} | out
        ends += [(q, o) for o in out]
    # Unbuilt ends: the street stops in the lot before (its opening closed), unless it runs off the camp's edge.
    for p, d in ends:
        dx, dy = STEP[d]
        q = (p[0] + dx, p[1] + dy)
        if 0 <= q[0] < n and 0 <= q[1] < n: street[p].discard(d)
    by = {}
    for i, v in enumerate(vs): by.setdefault(opens(v), []).append(i)
    # Where a lot stands sets its kind: the working lots by the crossing, the scrap and the guns at the fringe.
    def lean(name, dist):
        near = dist <= 2
        if name in CORE: return 3 if near else 0.5
        if name in FRINGE: return 0.4 if near else 3
        return 1
    def pick(key, dist):
        opts = by.get(frozenset(key), [])
        if not opts: return None
        return rng.choices(opts, [vs[i]["w"] * lean(vs[i]["name"], dist) for i in opts])[0]
    sol = {}
    dist = lambda p: abs(p[0] - mid[0]) + abs(p[1] - mid[1])
    for p, o in street.items():
        i = pick(o, dist(p))
        if i is None: return None
        sol[p] = i
    for p in list(street):
        for d, (dx, dy) in STEP.items():
            q = (p[0] + dx, p[1] + dy)
            if q not in sol and 0 <= q[0] < n and 0 <= q[1] < n:
                sol[q] = pick(set(), dist(q))
    return sol


COL = {"ground": "#d9cfb4", ":": "#9c8f78", ".": "#b7ad97", "%": "#e3b23c",
       "D": "#b0651a", "F": "#8a5a2b", "G": "#6b6b2b", "R": "#4f7a7a", "K": "#7a6a55", "T": "#3a3a3a", "V": "#c9772a",
       "W": "#5e5a55", "X": "#7d6b4f", "C": "#a07a3c", "P": "#4a3520", "L": "#f4e27a", "O": "#8c4a3a", "I": "#6f7a80"}


def draw(ax, vs, sol, w, h, mask, title):
    import matplotlib.patches as mp
    for (x, y) in sol: ax.add_patch(mp.Rectangle((x * SIZE, y * SIZE), SIZE, SIZE, color=COL["ground"], lw=0))
    for (x, y), i in sol.items():
        rows = vs[i]["rows"]
        for r, row in enumerate(rows):
            for c, ch in enumerate(row):
                X, Y = x * SIZE + c, y * SIZE + r
                if ch in ":.%":
                    ax.add_patch(mp.Rectangle((X, Y), 1, 1, color=COL[ch], lw=0))
        for r, row in enumerate(rows):
            for c, ch in enumerate(row):
                X, Y = x * SIZE + c, y * SIZE + r
                if ch in W.BUILD:
                    bw, bh = W.BUILD[ch]
                    if ch in "PL":
                        ax.add_patch(mp.Circle((X + 0.5, Y + 0.5), 0.4, color=COL[ch], lw=0))
                    elif ch in "XCI":
                        ax.add_patch(mp.Rectangle((X + 0.15, Y + 0.15), 0.7, 0.7, color=COL[ch], lw=0))
                    else:
                        ax.add_patch(mp.Rectangle((X + 0.1, Y + 0.1), bw - 0.2, bh - 0.2, color=COL[ch], lw=0))
                        if ch in MACHINES or ch == "T":
                            ax.text(X + bw / 2, Y + bh / 2, ch, ha="center", va="center", fontsize=4, color="white")
    # Tracks running off the camp's edge: drawn a few tiles into the wild.
    for (x, y), i in sol.items():
        for d, (dx, dy) in STEP.items():
            if (x + dx, y + dy) not in sol and ":" in vs[i]["edge"][d]:
                cx, cy = x * SIZE + SIZE / 2, y * SIZE + SIZE / 2
                ax.plot([cx + dx * SIZE / 2, cx + dx * SIZE * 1.3], [cy + dy * SIZE / 2, cy + dy * SIZE * 1.3],
                        color=COL[":"], lw=2.2, solid_capstyle="butt")
    ax.set_xlim(-SIZE, (w + 1) * SIZE); ax.set_ylim((h + 1) * SIZE, -SIZE)
    ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([]); ax.set_title(title, fontsize=8)


def main():
    path, out = sys.argv[1], sys.argv[2]
    args = sys.argv[3:]
    opt = lambda k, d: int(args[args.index(k) + 1]) if k in args else d
    n, size, seed, lots = opt("--n", 9), opt("--size", 9), opt("--seed", 1), opt("--lots", 16)
    tiles = W.parse(path)
    errs = [e for t in tiles for e in W.check_tile(t)]
    if errs: print("\n".join(errs)); sys.exit(1)
    vs = W.variants(tiles)
    cm = compat(vs)
    lonely = sorted({v["name"] for i, v in enumerate(vs) if any(not cm[(i, d)] for d in "nsew")})
    print(f"{len(tiles)} tiles, {len(vs)} variants" + (f"; an edge nothing fits: {lonely}" if lonely else ""))
    import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
    cols = 3; rows_ = (n + cols - 1) // cols
    fig, axes = plt.subplots(rows_, cols, figsize=(4.4 * cols, 4.4 * rows_), dpi=130)
    rng = random.Random(seed)
    stats = {"tries": 0, "contradiction": 0, "rejected": {}}
    for k in range(n):
        ax = axes.flat[k]
        for attempt in range(300):
            stats["tries"] += 1
            sol = grow(vs, size, lots, rng)
            if sol is None: stats["contradiction"] += 1; continue
            why = validate(vs, sol, size, size)
            if why: stats["rejected"][why] = stats["rejected"].get(why, 0) + 1; continue
            draw(ax, vs, sol, size, size, None, f"camp {k + 1}: {sum(1 for i in sol.values() if opens(vs[i]))} street lots"); break
        else:
            ax.set_title(f"camp {k + 1}: none in 300 tries", fontsize=8); ax.axis("off")
    for ax in axes.flat[n:]: ax.axis("off")
    fig.tight_layout(); fig.savefig(out); print(out, stats)


if __name__ == "__main__":
    main()
