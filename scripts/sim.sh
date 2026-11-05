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
SIM="$HOME/Library/Application Support/factorio-lp-sim/$RUN$WT"

mkdir -p "$SIM/config" "$SIM/mods" "$SIM/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$SIM" > "$SIM/config/config.ini"
ln -sfn "$REPO/landing-party" "$SIM/mods/landing-party"
# The test mod is copied, not linked: each run writes its own params.lua into it.
rm -rf "$SIM/mods/lp-sim"; cp -R "$REPO/tests/lp-sim" "$SIM/mods/lp-sim"
DOCTRINE="nil"; [ -n "${LP_DOCTRINE:-}" ] && DOCTRINE="\"$LP_DOCTRINE\""
printf 'return {scenario = "%s", minutes = %s, every = %s, strike = %s, distance = %s, radius = %s, doctrine = %s, units = %s, move = %s, fast = %s, mix = "%s", off = "%s"}\n' \
  "$SCENARIO" "$MINUTES" "$EVERY" "$STRIKE" "$DISTANCE" "$RADIUS" "$DOCTRINE" "${LP_UNITS:-0}" "${LP_MOVE:-false}" "${LP_FAST:-false}" "${LP_MIX:-}" "${LP_OFF:-}" \
  > "$SIM/mods/lp-sim/params.lua"
cat > "$SIM/mods/mod-list.json" <<JSON
{"mods": [{"name": "base", "enabled": true}, {"name": "landing-party", "enabled": true},
  {"name": "lp-sim", "enabled": true}, {"name": "space-age", "enabled": true},
  {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}]}
JSON
out="$SIM/script-output/landing-party"
rm -rf "$out" "$SIM/saves/sim.zip"
# The last run's results go first: a run that dies at load left them, and read after it they passed for its own
# (2026-11-04: a runtime require crashed orbital spotter, and its old results read "ALL PASSED").
rm -f "$REPO/docs/sim/$RUN/results.txt"

run() { "$FACTORIO" --config "$SIM/config/config.ini" "$@" > "$SIM/sim.out" 2>&1 || {
  echo "SIM FAILED ($RUN): factorio exited non-zero"; grep -hnE -A8 "Error" "$SIM/factorio-current.log" "$SIM/sim.out" | head -40; exit 1; }; }
if [ -n "${LP_FORK:-}" ]; then
  # From the scenario's fork at its strike (scripts/fork.sh, made once): only what follows the strike runs.
  # (LP_FORK_MIX: a variant's own fork, as fork.sh and film_fork.sh make it. LP_MIX alone runs the variant from the plain
  # scenario's fork, which is not the one its film plays: herd ranks-mend's fork had 52 units at its tick, the plain
  # one's 49, 2026-11-05.)
  fork="$FORKS/$SCENARIO${LP_FORK_MIX:+-$LP_FORK_MIX}-$SEED-$STRIKE-$FORK_HASH.zip"
  # A fork that fails to build says so (its output once went to /dev/null and the run ended silently).
  [ -f "$fork" ] || "$(dirname "$0")/fork.sh" "$SCENARIO" "$SEED" "$STRIKE" || { echo "SIM FAILED ($RUN): fork"; exit 1; }
  cp "$fork" "$SIM/saves/sim.zip"
  run --benchmark "$SIM/saves/sim.zip" --benchmark-ticks $(((MINUTES - STRIKE + FORK_LEAD) * 3600 + 61)) --benchmark-runs 1
else
  run --create "$SIM/saves/sim.zip" --map-gen-seed "$SEED" --map-gen-settings "$REPO/scripts/map-gen.json"
  run --benchmark "$SIM/saves/sim.zip" --benchmark-ticks $((MINUTES * 3600 + 60)) --benchmark-runs 1
fi

[ -f "$out/results.txt" ] || { echo "SIM FAILED ($RUN): no results written"; tail -20 "$SIM/sim.out"; exit 1; }
avg=$(grep -oE "avg: [0-9.]+ ms" "$SIM/sim.out" | head -1 | grep -oE "[0-9.]+" || echo "?")
echo "METRIC ms_per_tick $avg" >> "$out/results.txt"
dest="$REPO/docs/sim/$RUN"
mkdir -p "$dest"
# (A run with no settlement writes no sim.jsonl: system solo, Synthexis alone.)
for f in decisions.txt sim.jsonl results.txt ops.jsonl growth.jsonl march.jsonl trailer-beats.txt; do [ -f "$out/$f" ] && cp "$out/$f" "$dest/"; done
if [ -s "$out/timeline.jsonl" ]; then
  cp "$out/timeline.jsonl" "$dest/"
  uv run --quiet --with matplotlib python3 "$REPO/scripts/timeline.py" "$dest" > /dev/null 2>&1 \
  || echo "plots skipped (uv: $(basename "$dest")); the run is judged by its results"
fi
if [ -f "$dest/sim.jsonl" ]; then
  uv run --quiet --with matplotlib python3 "$REPO/scripts/plot.py" "$dest/sim.jsonl" "$dest" > /dev/null 2>&1 \
  || echo "plots skipped (uv: $(basename "$dest")); the run is judged by its results"
fi
if [ -s "$out/faction.jsonl" ]; then
  cp "$out/faction.jsonl" "$dest/"
  uv run --quiet --with matplotlib python3 "$REPO/scripts/overview.py" "$dest/faction.jsonl" "$dest/overview.png" > /dev/null 2>&1 \
  || echo "plots skipped (uv: $(basename "$dest")); the run is judged by its results"
fi
# The animation took two minutes of a siege run whose game ran 15 s: on request only (the positions are kept).
if [ -s "$out/life.jsonl" ]; then cp "$out/life.jsonl" "$dest/"; fi
if [ -s "$out/life.jsonl" ] && [ -n "${LP_GIF:-}" ]; then
  bg="$dest/sim.jsonl"; [ -s "$out/faction.jsonl" ] && bg="$out/faction.jsonl"
  uv run --quiet --with matplotlib --with pillow python3 "$REPO/scripts/life.py" "$bg" "$dest/life.jsonl" "$dest/life.gif" > /dev/null
fi
if [ -s "$out/replay.jsonl" ]; then
  cp "$out/replay.jsonl" "$dest/"
  uv run --quiet --with matplotlib --with pillow python3 "$REPO/scripts/replay.py" "$dest/replay.jsonl" "$dest/raid.gif" > /dev/null
fi
grep -E "^(PASS|FAIL|DONE)" "$out/results.txt" | sed "s/^/[$RUN] /"
grep -q "^DONE ALL PASSED" "$out/results.txt"
