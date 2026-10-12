#!/usr/bin/env bash
# Run Landing Party scenarios over seeds in parallel, then print one table of metrics.
#   scripts/batch.sh ["grow cut raid occupy"] ["12345 777 4242 101 31337"] [minutes] [strike minute]
# Fails if any run fails. Per-run plots and logs: docs/sim/<scenario>-<seed>/.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/.." && pwd)"
SCENARIOS="${1:-grow cut raid occupy}"; SEEDS="${2:-12345 777 4242 101 31337}"
MINUTES="${3:-60}"; STRIKE="${4:-30}"
JOBS="${LP_JOBS:-6}"
logs="$(mktemp -d)"
pids=(); names=()
for sc in $SCENARIOS; do
  for seed in $SEEDS; do
    while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do sleep 1; done
    "$DIR/sim.sh" "$sc" "$seed" "$MINUTES" 10 "$STRIKE" > "$logs/$sc-$seed.log" 2>&1 &
    pids+=($!); names+=("$sc-$seed")
  done
done
fail=0
for i in "${!pids[@]}"; do
  if ! wait "${pids[$i]}"; then fail=1; fi
done
for n in "${names[@]}"; do grep -hE "FAIL|SIM FAILED" "$logs/$n.log" | sed "s/^/  /"; done
python3 - "$REPO/docs/sim" "${names[@]}" <<'PY'
import sys, pathlib
root, names = pathlib.Path(sys.argv[1]), sys.argv[2:]
rows, keys = [], []
for n in names:
    f = root / n / "results.txt"
    m = {"run": n, "ok": "?"}
    if f.exists():
        for line in f.read_text().splitlines():
            if line.startswith("METRIC "):
                _, k, v = line.split(" ", 2); m[k] = v
                if k not in keys: keys.append(k)
            if line.startswith("DONE"): m["ok"] = "pass" if "ALL PASSED" in line else "FAIL"
    rows.append(m)
cols = ["run", "ok"] + keys
w = {c: max(len(c), *(len(str(r.get(c, ""))) for r in rows)) for c in cols}
print("  ".join(c.ljust(w[c]) for c in cols))
for r in rows:
    print("  ".join(str(r.get(c, "")).ljust(w[c]) for c in cols))
PY
rm -rf "$logs"
exit $fail
