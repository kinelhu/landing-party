"""Summary of the per-tier arena runs: each (unit, round, power) its mean score, matchups won, and a few key matchups.

Usage: python3 tiers_summary.py <dir>   (files lp-arena-<kind>-<tier>.jsonl at power 1, lp-arena-<kind>-<tier>@<exp>.jsonl)
"""
import glob, json, os, re, sys
from collections import defaultdict

d = sys.argv[1]
SHORT = {"none": "base", "piercing-rounds-magazine": "red", "uranium-rounds-magazine": "green",
         "uranium-cannon-shell": "uranium shell"}
KEY = ["tank", "battle tank", "aegis", "bred behemoth", "bred big", "shock", "biters 0.95", "rocket trooper", "lance"]


def score(r):
    a, b = r["a"], r["b"]
    lost_a = a["parts_lost"] / a["parts"] if a["parts"] else 0
    if r["kind"] in ("pair", "mix"):
        took = b["parts_lost"] / b["parts"] if b["parts"] else 0
    else:
        took = (b["start"] - b["left"]) / b["start"] if b["start"] else 0
    return 100 * (took - lost_a)


rows = []
for p in sorted(glob.glob(os.path.join(d, "lp-arena-*.jsonl"))):
    m = re.match(r"lp-arena-(trooper|gun-buggy|battle-tank)-([a-z-]+?)(?:@([0-9.]+))?\.jsonl$", os.path.basename(p))
    if not m:
        continue
    kind, tier, exp = m.group(1), m.group(2), m.group(3) or "1"
    if tier == "none":
        exp = "-"
    squad = kind.replace("-", " ")
    by = defaultdict(list)
    for line in open(p):
        if line.startswith("{"):
            r = json.loads(line)
            if r.get("squad") == squad:
                by[r["against"]].append(score(r))
    if not by:
        continue
    cell = {k: sum(v) / len(v) for k, v in by.items()}
    vals = list(cell.values())
    rows.append((squad, SHORT.get(tier, tier), exp, sum(vals) / len(vals), sum(1 for v in vals if v > 0), len(vals),
                 [cell.get(k) for k in KEY]))

print("| unit | round | power | mean | won | " + " | ".join(KEY) + " |")
print("|---|---|---|---|---|" + "---|" * len(KEY))
for squad, tier, exp, mean, won, n, keys in sorted(rows, key=lambda r: (r[0], r[1] != "base", r[1], r[2])):
    print(f"| {squad} | {tier} | {exp} | {mean:+.0f} | {won}/{n} | " +
          " | ".join("" if v is None else f"{v:+.0f}" for v in keys) + " |")
