#!/usr/bin/env python3
"""The spike guard's report (scripts/spikes.sh): each tick's script time from the engine's verbose benchmark, the ticks
past the budget, and for each the modules that took its time (Landing Party's per-module timing, spikes.txt).
  spikes_report.py bench.out spikes.txt budget_ms
Prints OK when no tick's script time is past the budget, else SPIKES and the list."""
import re
import sys

bench, spikes, budget = sys.argv[1], sys.argv[2], float(sys.argv[3])
lines = open(bench).read().splitlines()
hdr = [l for l in lines if l.startswith("tick,")][0].split(",")
rows = [l.split(",") for l in lines if l[:1] == "t" and l[1:2].isdigit()]
script = hdr.index("scriptUpdate")
whole = hdr.index("wholeUpdate")
gc = hdr.index("luaGarbageIncremental") if "luaGarbageIncremental" in hdr else None
data = [(int(r[0][1:]), int(r[script]) / 1e6, int(r[whole]) / 1e6, int(r[gc]) / 1e6 if gc else 0.0) for r in rows]
data.sort()
start_rel = data[0][0] if data else 0

# Per-module times by game tick (spikes.txt lines: "<tick> name=Duration: Xms name=..."), and the first tick written.
mods = {}
try:
    for l in open(spikes):
        parts = l.split(" ", 1)
        if len(parts) < 2 or not parts[0].isdigit():
            continue
        # (A span named twice in a tick, one a camp, summed.)
        got = {}
        for m in re.finditer(r"(\S+)=Duration: ([0-9.]+)ms", parts[1]):
            got[m.group(1)] = got.get(m.group(1), 0.0) + float(m.group(2))
        mods[int(parts[0])] = got
except FileNotFoundError:
    pass
first = min(mods) if mods else None

s = sorted(x[1] for x in data)
def q(p):
    return s[min(len(s) - 1, int(len(s) * p))] if s else 0
over = [d for d in data if d[1] > budget]
print(f"{len(data)} ticks; script time p99 {q(0.99):.2f} ms, p99.9 {q(0.999):.2f} ms, max {s[-1] if s else 0:.2f} ms; "
      f"budget {budget:g} ms: {len(over)} past it")
# The benchmark's tick index is relative: t0 is the save's first tick, before the helper turns the timing on (spikes.txt's first line is t1).
for rel, sc, wh, g in sorted(over, key=lambda d: -d[1])[:40]:
    tick = first + (rel - start_rel - 1) if first is not None else None
    m = mods.get(tick, {})
    top = sorted(m.items(), key=lambda kv: -kv[1])[:7]
    tops = ", ".join(f"{k} {v:.1f}" for k, v in top)
    print(f"  t{rel} (game {tick}): script {sc:.1f} ms (whole {wh:.1f}, gc {g:.1f}): {tops}")
print("OK" if not over else "SPIKES")
