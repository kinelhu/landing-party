#!/usr/bin/env bash
# Stills (and later shots) for the trailer, in a game window: a copy of a prepared save in a visit profile, the film helper
# (tests/lp-film) given a schedule, the game closed once its last still is written.
#   scripts/film.sh <visit profile name> <save in its saves> <params.lua> [out dir]
# Frames: <profile>/script-output/lp-film/<name>/, copied to [out dir] (default docs/sim/film-<name>).
set -euo pipefail
source "$(dirname "$0")/env.sh"
NAME="$1"; SAVE="$2"; PARAMS="$3"
V="$HOME/Library/Application Support/factorio-lp-visit/$NAME"
case "$V" in *"/factorio/"*) echo "refusing: $V is inside the real profile"; exit 1;; esac
[ -f "$V/saves/$SAVE" ] || { echo "no $V/saves/$SAVE"; exit 1; }
if pgrep -f -- "--config $V/config/config.ini" > /dev/null; then echo "refusing: a game is running on $V"; exit 1; fi
FN=$(grep -o 'return {name = "[^"]*"' "$PARAMS" | head -1 | cut -d'"' -f2)
OUT="${4:-$REPO/docs/sim/film-$FN}"
cp "$V/saves/$SAVE" "$V/saves/film.zip"
rm -rf "$V/mods/lp-sim" "$V/mods/lp-film" "$V/script-output/lp-film/$FN"
ln -sfn "$REPO/landing-party" "$V/mods/landing-party"
cp -R "$REPO/tests/lp-film" "$V/mods/lp-film"; cp "$PARAMS" "$V/mods/lp-film/params.lua"
# LP_FILM_SIM=<a fork's sim dir>: its scenario harness along (lp-sim with the fork's params), so a scenario saved before its
# own steps (a defence built, a siege forced) goes on playing in the window.
SIMMOD=""
if [ -n "${LP_FILM_SIM:-}" ]; then
  cp -R "$REPO/tests/lp-sim" "$V/mods/lp-sim"; sed 's/, save_at = [0-9]*//' "$LP_FILM_SIM/mods/lp-sim/params.lua" > "$V/mods/lp-sim/params.lua"
  SIMMOD=', {"name": "lp-sim", "enabled": true}'
fi
echo '{"mods": [{"name": "base", "enabled": true}, {"name": "space-age", "enabled": true}, {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}, {"name": "landing-party", "enabled": true}, {"name": "lp-film", "enabled": true}'"$SIMMOD"']}' > "$V/mods/mod-list.json"
L="$V/launch"; mkdir -p "$L"; echo 427520 > "$L/steam_appid.txt"
cd "$L"
# Reels (the user's Mac, 2026-11-04: a windowed game stops advancing about 720 ticks after it loads, every time): the helper
# saves the game before then while stills remain (reel.txt names the save) and film.sh opens it again in a fresh session.
REEL="$V/script-output/lp-film/$FN/reel.txt"
launch() {
  rm -f "$V/factorio-current.log" "$REEL"   # (its error check reads this run's log, not the last)
  "$FACTORIO" --config "$V/config/config.ini" --load-game "$1" > "$V/film.out" 2>&1 &
  PID=$!
}
launch "$V/saves/film.zip"
REELS=1
for _ in $(seq 1 1800); do
  [ -f "$V/script-output/lp-film/$FN/done.txt" ] && break
  if [ -f "$REEL" ]; then
    NEXT="$V/saves/$(cat "$REEL").zip"
    for _ in $(seq 1 60); do [ -f "$NEXT" ] && break; sleep 1; done
    sleep 3; kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true
    [ -f "$NEXT" ] || { echo "FILM FAILED: its reel's save $NEXT never came"; exit 1; }
    REELS=$((REELS + 1)); launch "$NEXT"
    continue
  fi
  kill -0 "$PID" 2>/dev/null || { echo "FILM FAILED: the game stopped"; tail -20 "$V/film.out"; exit 1; }
  # (A script error holds the window on its dialog: a dome film waited out its 30 minutes on one, 2026-11-04.)
  if grep -q "non-recoverable error" "$V/factorio-current.log" 2>/dev/null; then
    echo "FILM FAILED: a script error"; grep -A4 "non-recoverable error" "$V/factorio-current.log" | head -8
    kill "$PID" 2>/dev/null || true; exit 1
  fi
  sleep 1
done
sleep 3; kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true
[ -f "$V/script-output/lp-film/$FN/done.txt" ] || { echo "FILM FAILED: no done.txt within 30 minutes"; exit 1; }
mkdir -p "$OUT"; cp "$V/script-output/lp-film/$FN/"*.png "$OUT/"
# (The profile's copy goes once copied out: every frame was kept twice, 5 GB of clip frames a side, 2026-11-04.)
rm -rf "$V/script-output/lp-film/$FN"
echo "stills: $OUT ($(ls "$OUT"/*.png | wc -l | tr -d ' '), $REELS reels)"
