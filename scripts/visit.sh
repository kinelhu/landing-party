#!/usr/bin/env bash
# The corporations against a real factory: a COPY of a save (never the original, never a real profile) in its own
# profile, with Landing Party and the test mod added (scenario visit, tests/lp-sim), run headless at real clocks.
#   scripts/visit.sh <save.zip> [minutes]      e.g. scripts/visit.sh ~/Library/.../factorio/saves/nwa.zip 180
#   LP_MIX=provoked: an hour in, both corporations count the factory as having attacked them.
#   LP_PROFILE=1: both benchmarks with the engine's per-tick script timings (mean script, the worst ticks).
# First a baseline benchmark of the save as it is (base, Space Age, Quality, Elevated Rails), then the visit; reports
# both ms a tick, the visit's story (results.txt) and its timeline, in docs/sim/visit-<save>/.
# Mods the save used beyond those (quality-of-life, GUI) are left out: their entities and state drop from the copy.
set -euo pipefail
source "$(dirname "$0")/env.sh"
SAVE="${1:?usage: scripts/visit.sh <save.zip> [minutes]}"; MINUTES="${2:-180}"
NAME="$(basename "$SAVE" .zip)"
V="$HOME/Library/Application Support/factorio-lp-visit/$NAME${LP_MIX:+-$LP_MIX}"
case "$V" in *"/factorio/"*) echo "refusing: $V is inside the real profile"; exit 1;; esac
mkdir -p "$V/config" "$V/mods" "$V/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$V" > "$V/config/config.ini"
cp "$SAVE" "$V/saves/original.zip"
base='{"name": "base", "enabled": true}, {"name": "space-age", "enabled": true}, {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}'
run() { "$FACTORIO" --config "$V/config/config.ini" "$@" > "$V/run.out" 2>&1 || {
  echo "VISIT FAILED ($NAME): factorio exited non-zero"; grep -hnE -A8 "Error" "$V/run.out" | head -30; exit 1; }; }

# Baseline: the factory alone.
rm -rf "$V/mods/landing-party" "$V/mods/lp-sim"
echo "{\"mods\": [$base]}" > "$V/mods/mod-list.json"
cp "$V/saves/original.zip" "$V/saves/baseline.zip"
VERB=""; [ -n "${LP_PROFILE:-}" ] && VERB="--benchmark-verbose wholeUpdate,scriptUpdate"
summarise() { python3 - "$1" <<'PY'
import sys
lines = open(sys.argv[1]).read().splitlines()
heads = [k for k, l in enumerate(lines) if l.startswith("tick,")]
if not heads: sys.exit()
hdr = lines[heads[0]].split(",")
rows = [l.split(",") for l in lines[heads[0] + 1:] if l.startswith("t") and l[1:2].isdigit()]
ix = {h: j for j, h in enumerate(hdr)}
script = [float(r[ix["scriptUpdate"]]) / 1e6 for r in rows]
whole = [float(r[ix["wholeUpdate"]]) / 1e6 for r in rows]
worst = sorted(((s, int(r[0][1:])) for s, r in zip(script, rows)), reverse=True)[:6]
print(f"PROFILE {len(rows)} ticks: mean tick {sum(whole)/len(whole):.3f} ms, mean script {sum(script)/len(script):.4f} ms; "
      f"over 5 ms: {sum(1 for s in script if s > 5)}; worst: " + ", ".join(f"{s:.1f}@{t}" for s, t in worst))
PY
}
run --benchmark "$V/saves/baseline.zip" --benchmark-ticks 3600 --benchmark-runs 1 $VERB
b_avg=$(grep -oE "avg: [0-9.]+ ms" "$V/run.out" | head -1 | grep -oE "[0-9.]+" || echo "?")
[ -n "${LP_PROFILE:-}" ] && b_prof=$(summarise "$V/run.out")

# The visit.
ln -sfn "$REPO/landing-party" "$V/mods/landing-party"
rm -rf "$V/mods/lp-sim"; cp -R "$REPO/tests/lp-sim" "$V/mods/lp-sim"
printf 'return {scenario = "visit", minutes = %s, every = %s, strike = 1, distance = 300, radius = 220, doctrine = nil, units = 0, move = false, fast = false, mix = "%s"}\n' \
  "$MINUTES" "$MINUTES" "${LP_MIX:-}" > "$V/mods/lp-sim/params.lua"
echo "{\"mods\": [$base, {\"name\": \"landing-party\", \"enabled\": true}, {\"name\": \"lp-sim\", \"enabled\": true}]}" > "$V/mods/mod-list.json"
out="$V/script-output/landing-party"
rm -rf "$out"
cp "$V/saves/original.zip" "$V/saves/visit.zip"
run --benchmark "$V/saves/visit.zip" --benchmark-ticks $((MINUTES * 3600 + 60)) --benchmark-runs 1 $VERB
v_avg=$(grep -oE "avg: [0-9.]+ ms" "$V/run.out" | head -1 | grep -oE "[0-9.]+" || echo "?")
[ -f "$out/results.txt" ] || { echo "VISIT FAILED ($NAME): no results written"; tail -20 "$V/run.out"; exit 1; }
echo "METRIC ms_per_tick_baseline $b_avg" >> "$out/results.txt"
echo "METRIC ms_per_tick_visit $v_avg" >> "$out/results.txt"
if [ -n "${LP_PROFILE:-}" ]; then
  echo "baseline $b_prof" >> "$out/results.txt"
  echo "visit $(summarise "$V/run.out")" >> "$out/results.txt"
fi
dest="$REPO/docs/sim/visit-$NAME${LP_MIX:+-$LP_MIX}"
mkdir -p "$dest"
cp "$out/results.txt" "$out/decisions.txt" "$dest/" 2>/dev/null || true
[ -s "$out/timeline.jsonl" ] && cp "$out/timeline.jsonl" "$dest/"
grep -E "INFO visit|PASS|FAIL|METRIC|PROFILE" "$out/results.txt"
