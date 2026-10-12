#!/usr/bin/env bash
# Landing Party headless simulation in its own profile: one base lands near spawn on a map without
# biters (base game only), grows, and meets a scripted player action (tests/lp-sim/control.lua).
# Writes snapshots, decisions and results, then plots them into docs/sim/<scenario>-<seed>/.
#   scripts/sim.sh [scenario] [seed] [minutes] [snapshot every N minutes] [strike minute]
# Each scenario-seed pair has its own profile, so runs can go in parallel (scripts/batch.sh).
set -euo pipefail
source "$(dirname "$0")/env.sh"
SCENARIO="${1:-grow}"; SEED="${2:-12345}"; MINUTES="${3:-60}"; EVERY="${4:-10}"; STRIKE="${5:-30}"
# The real arrival lands ~350 tiles from the silo on a site with ore: the sim arrives the same way, from
# spawn, so threat-facing choices (pickets) face something at a realistic distance.
DISTANCE="${LP_DISTANCE:-300}"; RADIUS="${LP_RADIUS:-220}"
RUN="$SCENARIO-$SEED${LP_TAG:+-$LP_TAG}"
SIM="$HOME/Library/Application Support/factorio-lp-sim/$RUN"

mkdir -p "$SIM/config" "$SIM/mods" "$SIM/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$SIM" > "$SIM/config/config.ini"
ln -sfn "$REPO/landing-party" "$SIM/mods/landing-party"
# The test mod is copied, not linked: each run writes its own params.lua into it.
rm -rf "$SIM/mods/lp-sim"; cp -R "$REPO/tests/lp-sim" "$SIM/mods/lp-sim"
DOCTRINE="nil"; [ -n "${LP_DOCTRINE:-}" ] && DOCTRINE="\"$LP_DOCTRINE\""
printf 'return {scenario = "%s", minutes = %s, every = %s, strike = %s, distance = %s, radius = %s, doctrine = %s, units = %s, move = %s}\n' \
  "$SCENARIO" "$MINUTES" "$EVERY" "$STRIKE" "$DISTANCE" "$RADIUS" "$DOCTRINE" "${LP_UNITS:-0}" "${LP_MOVE:-false}" \
  > "$SIM/mods/lp-sim/params.lua"
cat > "$SIM/mods/mod-list.json" <<JSON
{"mods": [{"name": "base", "enabled": true}, {"name": "landing-party", "enabled": true},
  {"name": "lp-sim", "enabled": true}, {"name": "space-age", "enabled": false},
  {"name": "quality", "enabled": false}, {"name": "elevated-rails", "enabled": false}]}
JSON
out="$SIM/script-output/landing-party"
rm -rf "$out" "$SIM/saves/sim.zip"

run() { "$FACTORIO" --config "$SIM/config/config.ini" "$@" > "$SIM/sim.out" 2>&1 || {
  echo "SIM FAILED ($RUN): factorio exited non-zero"; grep -hnE -A8 "Error" "$SIM/factorio-current.log" "$SIM/sim.out" | head -40; exit 1; }; }
run --create "$SIM/saves/sim.zip" --map-gen-seed "$SEED" --map-gen-settings "$REPO/scripts/map-gen.json"
run --benchmark "$SIM/saves/sim.zip" --benchmark-ticks $((MINUTES * 3600 + 60)) --benchmark-runs 1

[ -f "$out/results.txt" ] || { echo "SIM FAILED ($RUN): no results written"; tail -20 "$SIM/sim.out"; exit 1; }
avg=$(grep -oE "avg: [0-9.]+ ms" "$SIM/sim.out" | head -1 | grep -oE "[0-9.]+" || echo "?")
echo "METRIC ms_per_tick $avg" >> "$out/results.txt"
dest="$REPO/docs/sim/$RUN"
mkdir -p "$dest"
cp "$out/decisions.txt" "$out/sim.jsonl" "$out/results.txt" "$dest/"
uv run --quiet --with matplotlib python3 "$REPO/scripts/plot.py" "$dest/sim.jsonl" "$dest" > /dev/null
grep -E "^(PASS|FAIL|DONE)" "$out/results.txt" | sed "s/^/[$RUN] /"
grep -q "^DONE ALL PASSED" "$out/results.txt"
