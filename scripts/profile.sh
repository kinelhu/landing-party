#!/usr/bin/env bash
# Profile a sim run's map with the engine's per-tick timings: mean tick and script time, and the worst
# script ticks (stutters). Runs the scenario once to build the map, then benchmarks it verbosely: the scenario again from
# its fresh map (sim.zip is tick 0), so its own landing at tick 60 is in it. (Verbose "all": a list of columns,
# "wholeUpdate,scriptUpdate", crashed the engine on its first row, Benchmark.cpp 190, 2.1.24; the worst tick went unnamed.)
#   scripts/profile.sh [scenario] [seed] [minutes]
set -euo pipefail
source "$(dirname "$0")/env.sh"
SCENARIO="${1:-grow}"; SEED="${2:-12345}"; MINUTES="${3:-30}"
"$REPO/scripts/sim.sh" "$SCENARIO" "$SEED" "$MINUTES" 10 > "$REPO/docs/sim/profile-$SCENARIO.log" 2>&1 || true
SIM="$HOME/Library/Application Support/factorio-lp-sim/$SCENARIO-$SEED"
csv="$SIM/profile.csv"
"$FACTORIO" --config "$SIM/config/config.ini" --benchmark "$SIM/saves/sim.zip" \
  --benchmark-ticks $((${LP_BENCH:-$MINUTES} * 3600)) --benchmark-runs 1 --benchmark-verbose all > "$csv" 2>&1
python3 - "$csv" <<'PY'
import sys
lines = open(sys.argv[1]).read().splitlines()
i = [k for k, l in enumerate(lines) if l.startswith("tick,")][0]
hdr = lines[i].split(",")
rows = [l.split(",") for l in lines[i + 1:] if l.startswith("t") and l[1:2].isdigit()]
ix = {h: j for j, h in enumerate(hdr)}
whole = [float(r[ix["wholeUpdate"]]) / 1e6 for r in rows]
script = [float(r[ix["scriptUpdate"]]) / 1e6 for r in rows]
print(f"{len(rows)} ticks: mean tick {sum(whole) / len(whole):.3f} ms, mean script {sum(script) / len(script):.4f} ms")
worst = sorted(((s, int(r[0][1:])) for s, r in zip(script, rows)), reverse=True)[:8]
print("worst script ticks (ms @ tick):", ", ".join(f"{s:.1f} @ {t}" for s, t in worst))
print(f"script ticks over 5 ms: {sum(1 for s in script if s > 5)}, over 16 ms: {sum(1 for s in script if s > 16)}")
PY
