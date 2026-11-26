#!/usr/bin/env bash
# The spike guard (the user, 2026-11-27: "any such spike is inacceptable even if rare. That's a noticeable stutter for
# the player in an otherwise very well optimized game"). A COPY of a save, headless, in a profile of its own (never the
# real profile or the original file), with Landing Party as linked here and a helper mod that turns on its per-module
# timing (storage.spike_prof: control.lua's TICKERS). The engine's script time for each tick (--benchmark-verbose) is
# the measure; a tick past the budget fails the run, and the report names the modules that took its time.
#   scripts/spikes.sh <save.zip> [ticks] [budget_ms]      e.g. scripts/spikes.sh ~/lp-saves/nw.zip 36000 5
#   LP_SPIKES_OUT=dir: where the report goes (default docs/sim/spikes-<save>/).
# Exit 0: no tick of script time past the budget; 1: some were (listed); 2: the run itself failed.
set -euo pipefail
source "$(dirname "$0")/env.sh"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SAVE="$1"; TICKS="${2:-36000}"; BUDGET="${3:-5}"
[ -f "$SAVE" ] || { echo "no save: $SAVE"; exit 2; }
NAME="$(basename "$SAVE" .zip)"
OUT="${LP_SPIKES_OUT:-$REPO/docs/sim/spikes-$NAME}"
P="$HOME/Library/Application Support/factorio-lp-spikes/$NAME"
rm -rf "$P"; mkdir -p "$P/config" "$P/mods/lp-spikes" "$P/saves" "$OUT"
cp "$SAVE" "$P/saves/s.zip"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$P" > "$P/config/config.ini"
ln -sfn "$REPO/landing-party" "$P/mods/landing-party"
cat > "$P/mods/mod-list.json" <<'JSON'
{"mods":[{"name":"base","enabled":true},{"name":"elevated-rails","enabled":true},{"name":"quality","enabled":true},
{"name":"recycler","enabled":true},{"name":"space-age","enabled":true},{"name":"landing-party","enabled":true},
{"name":"lp-spikes","enabled":true}]}
JSON
echo '{"name": "lp-spikes", "version": "0.0.1", "title": "LP spikes", "author": "dev", "factorio_version": "2.1", "dependencies": ["landing-party"]}' > "$P/mods/lp-spikes/info.json"
cat > "$P/mods/lp-spikes/control.lua" <<'LUA'
script.on_event(defines.events.on_tick, function()
  if storage.on then return end
  storage.on = true
  remote.call("landing-party", "debug_tune", {spike_prof = true})
end)
LUA
"$FACTORIO" --config "$P/config/config.ini" --benchmark "$P/saves/s.zip" --benchmark-ticks "$TICKS" --benchmark-runs 1 \
  --benchmark-verbose all > "$P/bench.out" 2>&1 || true
grep -q "Performed" "$P/bench.out" || { echo "SPIKES FAILED: the run did not finish"; grep -nE -A6 "Error" "$P/bench.out" | head -20; exit 2; }
cp "$P/bench.out" "$OUT/bench.out"
cp "$P/script-output/spikes.txt" "$OUT/spikes.txt" 2>/dev/null || true
uv run --no-project python3 "$REPO/scripts/spikes_report.py" "$OUT/bench.out" "$OUT/spikes.txt" "$BUDGET" | tee "$OUT/report.txt"
grep -q "^OK" "$OUT/report.txt"
