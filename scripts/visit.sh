#!/usr/bin/env bash
# The corporations against a real factory: a COPY of a save (never the original, never a real profile) in its own
# profile, with Landing Party and the test mod added (scenario visit, tests/lp-sim), run headless at real clocks.
#   scripts/visit.sh <save.zip> [minutes]      e.g. scripts/visit.sh ~/Library/.../factorio/saves/nwa.zip 180
#   LP_MIX=provoked: an hour in, both corporations count the factory as having attacked them.
#   LP_MIX=noart: the player's artillery (turrets and wagons) removed at the start; combines (noart-provoked...).
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
# A game already on this profile (a play-visit.sh window, another visit): touching its mods and saves under it
# unlinked Landing Party from a game being played (2026-10-17).
if pgrep -f -- "--config $V/config/config.ini" > /dev/null; then
  echo "refusing: a game is running on $V (close it, or use another LP_MIX)"; exit 1
fi
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
# The harness's own ticks (tests/lp-sim visit: the setup at 60, a census of the player's buildings every 10 minutes and
# at the end) are told apart: on a large factory they are the biggest ticks, and none of them is the mod's.
n = len(rows)
harness = lambda t: n > 3600 and (t == 60 or t % 36000 == 0 or t == n - 120)
ticks = [int(r[0][1:]) for r in rows]
mod = [(s, t) for s, t in zip(script, ticks) if not harness(t)]
worst = sorted(mod, reverse=True)[:6]
hw = max((s for s, t in zip(script, ticks) if harness(t)), default=0)
print(f"PROFILE {len(rows)} ticks: mean tick {sum(whole)/len(whole):.3f} ms, mean script {sum(script)/len(script):.4f} ms; "
      f"over 5 ms: {sum(1 for s, t in mod if s > 5)}, over 50: {sum(1 for s, t in mod if s > 50)}; worst: "
      + ", ".join(f"{s:.1f}@{t}" for s, t in worst) + f"; harness ticks apart (worst {hw:.1f})")
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
# Each operation followed from launch to end (landing-party/scripts/oplog.lua), drawn by scripts/ops_review.py.
if [ -s "$out/ops.jsonl" ]; then cp "$out/ops.jsonl" "$dest/"; uv run --quiet --with matplotlib python3 -I "$REPO/scripts/ops_review.py" "$dest/ops.jsonl" "$dest/ops" > /dev/null || echo "ops review skipped"; fi
[ -s "$out/timeline.jsonl" ] && cp "$out/timeline.jsonl" "$dest/"
grep -E "INFO visit|PASS|FAIL|METRIC|PROFILE" "$out/results.txt"
