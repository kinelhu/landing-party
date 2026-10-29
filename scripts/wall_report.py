"""The wall lab's table (scripts/wall-lab.sh): each wave's mean over its rounds."""
import json, sys
from collections import defaultdict

rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
by = defaultdict(list)
for r in rows:
    by[(r["tactic"], r["label"])].append(r)
print(f"{'tactic':8} {'wave':38} {'n':>2} {'lost':>6} {'lasers':>7} {'flamers':>8} {'walls':>6} {'through':>8} {'secs':>5}")
for (tac, lab), rs in by.items():
    m = lambda f: sum(f(r) for r in rs) / len(rs)
    print(f"{tac:8} {lab:38} {len(rs):>2} {m(lambda r: r['sent'] - r['left']):6.0f} "
          f"{m(lambda r: r['lasers_lost']):4.1f}/{rs[0]['lasers']:<2} {m(lambda r: r['flamers_lost']):5.1f}/{rs[0]['flamers']:<2} "
          f"{m(lambda r: r['walls_lost']):6.0f} {m(lambda r: r['max_inside']):8.0f} {m(lambda r: r['seconds']):5.0f}")
    for r in rs:
        print("   round", r["round"], "lost", r["lost"], "left", r["left"], "inside at end", r["inside"])
