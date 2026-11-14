#!/usr/bin/env bash
# What the director reads of a real factory (the user, 2026-11-14: "Get me readings on my saves"): a COPY of each save
# (never the original, never a real profile) in its own profile, Landing Party and the test mod added (scenario
# readings), run 120 ticks; prints its readings (director.readings) beside a fuller one.
#   scripts/readings.sh <save.zip>...
set -uo pipefail
source "$(dirname "$0")/env.sh"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
for SAVE in "$@"; do
  NAME="$(basename "$SAVE" .zip)"
  V="$HOME/Library/Application Support/factorio-lp-read/$NAME"
  case "$V" in *"/factorio/"*) echo "refusing: $V is inside the real profile"; exit 1;; esac
  mkdir -p "$V/config" "$V/mods" "$V/saves"
  printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$V" > "$V/config/config.ini"
  cp "$SAVE" "$V/saves/copy.zip"
  ln -sfn "$REPO/landing-party" "$V/mods/landing-party"
  rm -rf "$V/mods/lp-sim"; cp -R "$REPO/tests/lp-sim" "$V/mods/lp-sim"
  printf 'return {scenario = "readings", minutes = 1, every = 1, strike = 1, distance = 300, radius = 220, doctrine = nil, units = 0, move = false, fast = false, mix = "", off = "", air = "", director = ""}\n' \
    > "$V/mods/lp-sim/params.lua"
  echo '{"mods": [{"name": "base", "enabled": true}, {"name": "space-age", "enabled": true}, {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}, {"name": "landing-party", "enabled": true}, {"name": "lp-sim", "enabled": true}]}' \
    > "$V/mods/mod-list.json"
  rm -f "$V/script-output/landing-party/readings.json"
  if ! "$FACTORIO" --config "$V/config/config.ini" --benchmark "$V/saves/copy.zip" --benchmark-ticks 120 --benchmark-runs 1 \
    > "$V/run.out" 2>&1; then
    echo "== $NAME: FAILED to load"; grep -hE "Error|error" "$V/run.out" | head -3; continue
  fi
  f="$V/script-output/landing-party/readings.json"
  if [ -f "$f" ]; then echo "== $NAME"; cat "$f"; echo; else echo "== $NAME: no readings"; tail -3 "$V/run.out"; fi
done
