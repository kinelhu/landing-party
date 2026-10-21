"""Wave function collapse for Serenity's camps: tiles from a .tiles file, a validator, and a preview sheet.

    uv run --with matplotlib scripts/wfc/wfc.py check  scripts/wfc/serenity.tiles
    uv run --with matplotlib scripts/wfc/wfc.py sheet  scripts/wfc/serenity.tiles OUT.png [--n 9] [--size 9] [--seed 1]

Tiles are 6x6 characters (see the .tiles file). Two tiles fit where their touching edges agree character by character,
or where a wall or gate faces outside. Every tile is also used in its four turns and their mirrors. The grid is masked:
cells outside the lobe are forced to the void tile; `fixed` cells (incremental growth) are given. A result passes when
every floor and lane tile is reachable from a gate that opens outside, and every building touches walkable ground; a
failed result (contradiction or check) is rolled again.
"""
import random, sys, os

SIZE = 6
WALLS = set("#g")
INNER = set("w")
WALK = set(".=ghc")
BUILD = {"T": (2, 2), "G": (2, 2), "D": (4, 4), "F": (3, 3), "R": (3, 3), "B": (4, 4), "P": (1, 1), "L": (1, 1)}

def parse(path):
    tiles, cur = [], None
    for line in open(path):
        line = line.rstrip("\n")
        if not line or line.startswith("#"): continue
        if line.startswith("tile "):
            _, name, w = line.split(); cur = {"name": name, "w": float(w), "rows": []}; tiles.append(cur); continue
        cur["rows"].append(line.strip()[1:-1])
    return tiles

def check_tile(t):
    errs = []
    rows = t["rows"]
    if len(rows) != SIZE or any(len(r) != SIZE for r in rows): return [f"{t['name']}: not {SIZE}x{SIZE} ({[len(r) for r in rows]})"]
    cover = [[None] * SIZE for _ in range(SIZE)]
    for y in range(SIZE):
        for x in range(SIZE):
            c = rows[y][x]
            if c in BUILD:
                w, h = BUILD[c]
                for dy in range(h):
                    for dx in range(w):
                        X, Y = x + dx, y + dy
                        if X >= SIZE or Y >= SIZE: errs.append(f"{t['name']}: {c} at {x},{y} runs off the tile"); continue
                        want = c if (dx, dy) == (0, 0) else "+"
                        if rows[Y][X] != want: errs.append(f"{t['name']}: {c} at {x},{y} expects '{want}' at {X},{Y}, found '{rows[Y][X]}'")
                        cover[Y][X] = c
    for y in range(SIZE):
        for x in range(SIZE):
            if rows[y][x] == "+" and cover[y][x] is None: errs.append(f"{t['name']}: stray '+' at {x},{y}")
    return errs

def buildings(rows):
    """A tile's buildings as (letter, x, y, w, h), its floor with them taken out."""
    out, floor = [], [list(r) for r in rows]
    for y in range(SIZE):
        for x in range(SIZE):
            c = rows[y][x]
            if c in BUILD:
                w, h = BUILD[c]
                out.append((c, x, y, w, h))
                for dy in range(h):
                    for dx in range(w): floor[y + dy][x + dx] = "."
    return out, ["".join(r) for r in floor]

def transform(floor, blds, k, mirror):
    """Turned k quarter turns, then mirrored: the floor's characters and the buildings' rectangles move together."""
    g, bs = floor, list(blds)
    for _ in range(k):
        g = ["".join(g[SIZE - 1 - x][y] for x in range(SIZE)) for y in range(SIZE)]
        # new(x, y) = old(y, SIZE-1-x): an old rect at (ox, oy, w, h) lands at (SIZE-oy-h, ox) as (h, w)
        bs = [(c, SIZE - oy - h, ox, h, w) for c, ox, oy, w, h in bs]
    if mirror:
        g = [row[::-1] for row in g]
        bs = [(c, SIZE - ox - w, oy, w, h) for c, ox, oy, w, h in bs]
    out = [list(r) for r in g]
    for c, x, y, w, h in bs:
        for dy in range(h):
            for dx in range(w): out[y + dy][x + dx] = "+"
        out[y][x] = c
    return ["".join(r) for r in out]

def variants(tiles):
    vs, seen = [], set()
    for t in tiles:
        blds, floor = buildings(t["rows"])
        for k in range(4):
            for mirror in (False, True):
                r = transform(floor, blds, k, mirror)
                key = "".join(r)
                if key in seen: continue
                seen.add(key)
                vs.append({"name": t["name"], "w": t["w"], "rows": r})
    for v in vs:
        r = v["rows"]
        v["edge"] = {"n": r[0], "s": r[SIZE - 1], "w": "".join(row[0] for row in r), "e": "".join(row[SIZE - 1] for row in r)}
    return vs

def fits(a, b):
    # A full wall edge never faces another: walls back to back made spurs into the floor.
    if all(x in WALLS for x in a) and all(y in WALLS for y in b): return False
    return all(x == y or (x in WALLS and y == " ") or (y in WALLS and x == " ") for x, y in zip(a, b))

OPP = {"n": "s", "s": "n", "e": "w", "w": "e"}
STEP = {"n": (0, -1), "s": (0, 1), "e": (1, 0), "w": (-1, 0)}

def compat(vs):
    c = {}
    for i, a in enumerate(vs):
        for d in "nsew":
            c[(i, d)] = {j for j, b in enumerate(vs) if fits(a["edge"][d], b["edge"][OPP[d]])}
    return c

def solve(vs, cm, w, h, mask, rng, fixed=None, budget=3000):
    """Collapse with backtracking: on a contradiction, undo the last choice and rule that option out (restarting threw
    away 1,018 of 1,074 tries)."""
    void = [i for i, v in enumerate(vs) if v["name"] == "void"]
    allv = set(range(len(vs)))
    inner = {i for i, v in enumerate(vs) if all(c in ".=whc" for e in v["edge"].values() for c in e)}
    dom = {}
    for y in range(h):
        for x in range(w):
            # The mask's edge is soft: a cell inside it beside the outside may be outside too (a one-cell neck or a
            # diagonal touch needs a wall no tile has: nearly every mask contradicted at once).
            edge = any(not mask(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1))
            # Walls only at the mask's edge: deep inside, a tile's edges are floor or lane (else the solver walled every
            # cell into its own pod, a honeycomb of sealed octagons).
            dom[(x, y)] = set(void) if not mask(x, y) else (allv if edge else inner)
    for k, i in (fixed or {}).items(): dom[k] = {i}
    def propagate(dom, stack):
        while stack:
            p = stack.pop()
            for d, (dx, dy) in STEP.items():
                q = (p[0] + dx, p[1] + dy)
                if q not in dom: continue
                ok = set().union(*(cm[(i, d)] for i in dom[p])) if dom[p] else set()
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
        opts = sorted(dom[k])
        # Weighted order without replacement.
        order = sorted(opts, key=lambda i: -rng.random() ** (1.0 / vs[i]["w"]))
        for pick in order:
            steps[0] += 1
            if steps[0] > budget: return None
            d2 = {c: set(s) for c, s in dom.items()}
            d2[k] = {pick}
            if propagate(d2, [k]):
                r = search(d2)
                if r: return r
        return None
    return search(dom)

def render(vs, sol, w, h):
    g = [[" "] * (w * SIZE) for _ in range(h * SIZE)]
    for (x, y), i in sol.items():
        for r, row in enumerate(vs[i]["rows"]):
            for c, ch in enumerate(row): g[y * SIZE + r][x * SIZE + c] = ch
    return g

def validate(g):
    H, W = len(g), len(g[0])
    def at(x, y): return g[y][x] if 0 <= x < W and 0 <= y < H else " "
    # Exits: gates with outside beside them.
    exits = [(x, y) for y in range(H) for x in range(W) if g[y][x] == "g" and any(at(x + dx, y + dy) == " " for dx, dy in STEP.values())]
    if not exits: return "no gate opens outside"
    # Walls and gates on the outside edge only: no floor touching outside.
    for y in range(H):
        for x in range(W):
            if g[y][x] in WALK - {"g"} and any(at(x + dx, y + dy) == " " for dx, dy in STEP.values()): return f"floor open to outside at {x},{y}"
    # Walls close: every wall piece joins two others (or a gate); a line ending in the open is a stub.
    for y in range(H):
        for x in range(W):
            if g[y][x] == "#":
                n = sum(1 for dx, dy in STEP.values() if at(x + dx, y + dy) in WALLS)
                if n < 2: return f"wall stub at {x},{y}"
                # The end of a thick spur: floor on two sides at a corner, nothing outside near (a chamfer's step has).
                fl = {d for d, (dx, dy) in STEP.items() if at(x + dx, y + dy) in WALK}
                if (("n" in fl or "s" in fl) and ("e" in fl or "w" in fl)) and not any(
                        at(x + dx, y + dy) == " " for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                    return f"wall spur at {x},{y}"
    # Partitions close too: every piece joins two (partition, gap, or the outer wall).
    for y in range(H):
        for x in range(W):
            if g[y][x] == "w":
                n = sum(1 for dx, dy in STEP.values() if at(x + dx, y + dy) in ("w", "h", "#", "g"))
                if n < 2: return f"partition stub at {x},{y}"
    # Lanes run between gates: each lane's ground touches two gates at least.
    lane_seen = set()
    for y in range(H):
        for x in range(W):
            if g[y][x] == "=" and (x, y) not in lane_seen:
                comp, st, gates = {(x, y)}, [(x, y)], set()
                while st:
                    cx, cy = st.pop()
                    for dx, dy in STEP.values():
                        q = (cx + dx, cy + dy)
                        if at(*q) in "=h" and q not in comp: comp.add(q); st.append(q)
                        elif at(*q) == "g": gates.add(q)
                lane_seen |= comp
                if len(gates) < 2: return f"dead-end lane at {x},{y}"
    seen, stack = set(exits), list(exits)
    while stack:
        x, y = stack.pop()
        for dx, dy in STEP.values():
            q = (x + dx, y + dy)
            if q not in seen and at(*q) in WALK: seen.add(q); stack.append(q)
    for y in range(H):
        for x in range(W):
            if g[y][x] in WALK and (x, y) not in seen: return f"floor cut off at {x},{y}"
            if g[y][x] in BUILD:
                bw, bh = BUILD[g[y][x]]
                ring = [(x + dx, y - 1) for dx in range(bw)] + [(x + dx, y + bh) for dx in range(bw)] + \
                       [(x - 1, y + dy) for dy in range(bh)] + [(x + bw, y + dy) for dy in range(bh)]
                if not any(q in seen for q in ring): return f"{g[y][x]} at {x},{y} unreachable"
    return None

def rooms(g, rng, splits=4, min_room=9):
    """Rooms carved after the collapse (WFC sees only neighbours: a partition crossing the compound wall to wall never
    survived): straight partitions ('w') from outer wall to outer wall through floor and lanes only, the biggest room
    first, near its middle; a door ('h') where a lane crosses and in the middle of each. In place."""
    H, W = len(g), len(g[0])
    def runs(horizontal):
        out = []
        for a in range(2, (H if horizontal else W) - 2):
            line, run = [], []
            for b_ in range(W if horizontal else H):
                x, y = (b_, a) if horizontal else (a, b_)
                c = g[y][x]
                if c in ".=":
                    run.append((x, y))
                else:
                    if c in "#w" and run and len(run) >= 2 * min_room:
                        # A run closed at both ends by the outer wall or a partition: it splits one room (BSP).
                        px, py = run[0][0] - (1 if horizontal else 0), run[0][1] - (0 if horizontal else 1)
                        if g[py][px] in "#w": out.append(list(run))
                    run = []
        return out
    for _ in range(splits):
        cands = []
        for horizontal in (True, False):
            for run in runs(horizontal):
                # Rooms at least min_room across: no other partition within that, either side of the line; and not
                # along a lane (a partition beside a lane made a thick double band).
                px, py = (0, 1) if horizontal else (1, 0)
                near = beside = 0
                for x, y in run:
                    for k in range(1, min_room):
                        for sgn in (-1, 1):
                            X, Y = x + sgn * k * px, y + sgn * k * py
                            if 0 <= X < W and 0 <= Y < H and g[Y][X] in "wh": near += 1
                    for sgn in (-1, 1):
                        X, Y = x + sgn * px, y + sgn * py
                        if 0 <= X < W and 0 <= Y < H and g[Y][X] == "=": beside += 1
                if near or beside > len(run) // 4: continue
                cands.append((len(run), horizontal, run))
        if not cands: break
        cands.sort(key=lambda c: -c[0])
        _, horizontal, run = cands[min(len(cands) - 1, int(rng.random() * min(3, len(cands))))]
        mid = len(run) // 2
        before = [(x, y, g[y][x]) for x, y in run]
        for i, (x, y) in enumerate(run):
            g[y][x] = "h" if g[y][x] == "=" or abs(i - mid) <= 1 else "w"
        # One that cuts a floor or a lane off is taken back (rejected whole, they cost five tries a compound).
        why = validate(g)
        if why and (why.startswith("floor cut off") or why.startswith("dead-end lane") or "unreachable" in why):
            for x, y, c in before: g[y][x] = c
    return g

def lobe_mask(w, h, rng):
    """A random lobed blob: a few overlapping discs, like a cluster's plate."""
    discs = [(w / 2, h / 2, min(w, h) / 3)]
    for _ in range(rng.randint(2, 4)):
        cx, cy, r = rng.choice(discs)
        a = rng.random() * 6.283
        discs.append((cx + r * 0.9 * __import__("math").cos(a), cy + r * 0.9 * __import__("math").sin(a), r * rng.uniform(0.6, 0.9)))
    def m(x, y):
        if x in (0, w - 1) or y in (0, h - 1): return False
        return any((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r for cx, cy, r in discs)
    return m

COL = {" ": "#e9e2d0", ".": "#b8bfc6", "=": "#8f979e", "#": "#2c3e50", "g": "#e0a020", "w": "#56687a", "h": "#d9c38a", "c": "#d04020", "+": None,
       "T": "#3b5b7a", "G": "#6b8e23", "D": "#7a3b5b", "F": "#5b7a3b", "R": "#3b7a7a", "B": "#a05bd0", "P": "#222222", "L": "#f4f1a0"}

def draw(ax, g, title):
    import matplotlib.patches as mp
    H, W = len(g), len(g[0])
    for y in range(H):
        for x in range(W):
            ch = g[y][x]
            base = COL[" "] if ch == " " else COL["."]
            if ch in ("=", "#", "g", "w", "h", "c"): base = COL[ch]
            ax.add_patch(mp.Rectangle((x, y), 1, 1, color=base, lw=0))
    for y in range(H):
        for x in range(W):
            ch = g[y][x]
            if ch in BUILD and ch not in ("P", "L"):
                bw, bh = BUILD[ch]
                ax.add_patch(mp.Rectangle((x + 0.1, y + 0.1), bw - 0.2, bh - 0.2, color=COL[ch], lw=0))
                ax.text(x + bw / 2, y + bh / 2, ch, ha="center", va="center", fontsize=5, color="white")
            elif ch in ("P", "L"):
                ax.add_patch(mp.Circle((x + 0.5, y + 0.5), 0.35, color=COL[ch], lw=0))
    ax.set_xlim(0, W); ax.set_ylim(H, 0); ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([]); ax.set_title(title, fontsize=8)

def main():
    cmd, path = sys.argv[1], sys.argv[2]
    tiles = parse(path)
    errs = [e for t in tiles for e in check_tile(t)]
    if errs:
        print("\n".join(errs)); sys.exit(1)
    vs = variants(tiles)
    cm = compat(vs)
    lonely = [v["name"] for i, v in enumerate(vs) if any(not cm[(i, d)] for d in "nsew")]
    print(f"{len(tiles)} tiles, {len(vs)} variants" + (f"; with an edge nothing fits: {sorted(set(lonely))}" if lonely else ""))
    if cmd == "check": sys.exit(1 if lonely else 0)
    out = sys.argv[3]
    args = sys.argv[4:]
    n = int(args[args.index("--n") + 1]) if "--n" in args else 9
    size = int(args[args.index("--size") + 1]) if "--size" in args else 9
    seed = int(args[args.index("--seed") + 1]) if "--seed" in args else 1
    import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
    cols = 3; rows_ = (n + cols - 1) // cols
    fig, axes = plt.subplots(rows_, cols, figsize=(4 * cols, 4 * rows_), dpi=120)
    rng = random.Random(seed)
    stats = {"tries": 0, "contradiction": 0, "rejected": {}}
    for k in range(n):
        ax = axes.flat[k]
        for attempt in range(200):
            stats["tries"] += 1
            mask = lobe_mask(size, size, rng)
            sol = solve(vs, cm, size, size, mask, rng)
            if sol is None: stats["contradiction"] += 1; continue
            g = render(vs, sol, size, size)
            rooms(g, rng)
            why = validate(g)
            if why: stats["rejected"][why.split(" at ")[0]] = stats["rejected"].get(why.split(" at ")[0], 0) + 1; continue
            draw(ax, g, f"sample {k + 1} (try {attempt + 1})"); break
        else:
            ax.set_title(f"sample {k + 1}: none in 200 tries", fontsize=8); ax.axis("off")
    for ax in axes.flat[n:]: ax.axis("off")
    fig.tight_layout(); fig.savefig(out); print(out, stats)

if __name__ == "__main__":
    main()
