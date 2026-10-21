"""Each kind's strength in the arena's counter matrix: its mean score against every kind (docs/arena/results.jsonl),
with its price, for tuning prices (scripts/arena.sh writes the results).

    python3 -I scripts/arena_strength.py docs/arena/results.jsonl
"""
import json, sys
from collections import defaultdict

rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
pair, cost, kinds = defaultdict(list), {}, []
for r in rows:
    if r["squad"] not in kinds: kinds.append(r["squad"])
    if r["a"]["start"]: cost[r["squad"]] = round(r["a"]["parts"] / r["a"]["start"])
    if r["kind"] != "pair": continue
    a, b = r["a"], r["b"]
    s = (b["parts_lost"] / b["parts"] if b["parts"] else 0) - (a["parts_lost"] / a["parts"] if a["parts"] else 0)
    pair[(r["squad"], r["against"])].append(s)
    pair[(r["against"], r["squad"])].append(-s)
M = {k: sum(v) / len(v) for k, v in pair.items()}
# The goal is not an even matrix (counters are the choice of what to buy): every kind should beat some kinds clearly and
# be beaten clearly by some. A kind with no clear loss dominates; one with no clear win is dead weight at its price.
CLEAR = 0.4
for k in sorted(kinds, key=lambda k: -sum(M.get((k, o), 0) for o in kinds)):
    st = sum(M.get((k, o), 0) for o in kinds) / len(kinds)
    wins = sum(1 for o in kinds if o != k and M.get((k, o), 0) >= CLEAR)
    losses = sum(1 for o in kinds if o != k and M.get((k, o), 0) <= -CLEAR)
    flag = "  NO CLEAR LOSS" if losses == 0 else "  NO CLEAR WIN" if wins == 0 else ""
    print(f"{k:22s} {cost.get(k, '?'):>4} parts  mean {round(100 * st):+4d}  beats {wins:2d}  beaten by {losses:2d}{flag}")
