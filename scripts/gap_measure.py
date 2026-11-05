#!/usr/bin/env python3
"""A breach as the nwwall visits' measure mix writes it (LP_MIX=...nwwallsiege-measure: nwmeasure.jsonl).

  python3 -I scripts/gap_measure.py <nwmeasure.jsonl> <nwwall-map.json> [from_tick] [every] [box x0,x1,y0,y1]

Prints, for each frame from `from_tick` (default: the first) every `every` ticks (default 120): the player's wall
pieces (#) and turrets (L laser, F flamethrower) with the pieces gone since the wave was sent (o), the wave's units
there (digits: how many in the tile, + for ten or more; a for one out of its group); then the gap's width at each wall
row it crossed (the longest run of pieces gone in that row); then its deaths by killer and by 8x4 cell.
"""
import json
import sys
from collections import Counter

rec = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
m = json.load(open(sys.argv[2]))
frames = [r for r in rec if "u" in r]
deaths = [r for r in rec if "died" in r]
start = int(sys.argv[3]) if len(sys.argv) > 3 else frames[0]["t"]
every = int(sys.argv[4]) if len(sys.argv) > 4 else 120
x0, x1, y0, y1 = map(int, sys.argv[5].split(",")) if len(sys.argv) > 5 else (-60, 30, -440, -395)
walls = {(x, y) for x, y in m["walls"]}
turrets = {(x, y): {"electric-turret": "L", "fluid-turret": "F"}.get(t, "G") for x, y, t in m["turrets"]}


def draw(f):
    gone = {(int(x // 1), int(y // 1)) for x, y in f["gone"]}
    n, out_g = Counter(), Counter()
    for x, y, g, _ in f["u"]:
        n[(int(x // 1), int(y // 1))] += 1
        if not g: out_g[(int(x // 1), int(y // 1))] += 1
    print(f"tick {f['t']}: {len(f['u'])} units, {sum(1 for _, _, g, _ in f['u'] if g)} in a group, {len(gone)} wall pieces gone;"
          f" groups {f.get('g')}")
    for y in range(y0, y1 + 1):
        row = []
        for x in range(x0, x1 + 1):
            c = n.get((x, y), 0)
            if c: row.append("+" if c >= 10 else ("a" if out_g.get((x, y)) == c and c == 1 else str(c)))
            elif (x, y) in turrets: row.append(turrets[(x, y)])
            elif (x, y) in gone: row.append("o")
            elif (x, y) in walls: row.append("#")
            else: row.append(".")
        print(f"{y:5d} " + "".join(row))


last = None
for f in frames:
    if f["t"] < start: continue
    if last is None or f["t"] - last >= every:
        draw(f)
        last = f["t"]

# The gap's width at each wall row: the longest run of adjacent pieces gone, its x span.
f = [f for f in frames if f["t"] >= start][0]
gone = sorted({(int(x // 1), int(y // 1)) for x, y in f["gone"]})
print(f"\nat tick {f['t']}: pieces gone by row (runs: x from..to, width)")
for y in sorted({y for _, y in gone}):
    xs = sorted(x for x, yy in gone if yy == y)
    runs, a = [], xs[0]
    for i in range(1, len(xs) + 1):
        if i == len(xs) or xs[i] != xs[i - 1] + 1:
            runs.append((a, xs[i - 1], xs[i - 1] - a + 1))
            if i < len(xs): a = xs[i]
    print(f"  row {y}: " + ", ".join(f"{a}..{b} ({w})" for a, b, w in runs))

ds = [d for d in deaths if d["t"] >= start]
print(f"\ndeaths from tick {start}: {len(ds)}")
print("  by killer and damage:", dict(Counter(f"{d['by']}/{d['dmg']}" for d in ds).most_common()))
print("  by killer's place:", dict(Counter(f"{d['by']}@{d['bx']:.0f},{d['by_y']:.0f}" for d in ds if d.get("bx") is not None).most_common(12)))
print("  by 8x4 cell:", dict(Counter(f"{int(d['x'] // 8 * 8)},{int(d['y'] // 4 * 4)}" for d in ds).most_common(16)))
print("  by breed:", dict(Counter(d["died"] for d in ds).most_common()))
