#!/usr/bin/env bash
# The arena panel's GUI test (tests/lp-arena, guitest mode): a game window opens on the arena, the panel is built for
# every pick of every side (errors written, not raised), then ten troopers against a burster; the panel's text goes to
# gui.txt and a screenshot with the GUI to panel.png. The game is closed when done. Its own profile; close your game
# first (Steam allows one copy).
#   scripts/arena-gui.sh
set -euo pipefail
source "$(dirname "$0")/env.sh"
PLAY="$HOME/Library/Application Support/factorio-lp-arena-gui"
mkdir -p "$PLAY/config" "$PLAY/mods" "$PLAY/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$PLAY" > "$PLAY/config/config.ini"
ln -sfn "$REPO/landing-party" "$PLAY/mods/landing-party"
rm -rf "$PLAY/mods/lp-arena"; cp -R "$REPO/tests/lp-arena" "$PLAY/mods/lp-arena"
echo 'return {mode = "guitest"}' > "$PLAY/mods/lp-arena/params.lua"
cat > "$PLAY/mods/mod-list.json" <<JSON
{"mods": [{"name": "base", "enabled": true}, {"name": "landing-party", "enabled": true},
  {"name": "lp-arena", "enabled": true}, {"name": "space-age", "enabled": true},
  {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}]}
JSON
rm -f "$PLAY/saves/arena.zip"
"$FACTORIO" --config "$PLAY/config/config.ini" --create "$PLAY/saves/arena.zip" \
  --map-gen-settings "$REPO/scripts/map-gen.json" > "$PLAY/create.out" 2>&1 || { tail -20 "$PLAY/create.out"; exit 1; }
rm -rf "$PLAY/script-output/lp-arena"
# Started from a folder holding steam_appid.txt, the game does not hand itself to Steam to relaunch.
L="$PLAY/launch"; mkdir -p "$L"; echo 427520 > "$L/steam_appid.txt"
cd "$L"
"$FACTORIO" --config "$PLAY/config/config.ini" --load-game "$PLAY/saves/arena.zip" > "$PLAY/run.out" 2>&1 &
GAME=$!
OUT="$PLAY/script-output/lp-arena"
for _ in $(seq 1 180); do [ -f "$OUT/done.txt" ] && break; sleep 1; done
kill "$GAME" 2>/dev/null || true
wait "$GAME" 2>/dev/null || true
[ -f "$OUT/done.txt" ] || { echo "arena-gui: no result in 3 minutes"; tail -20 "$PLAY/run.out"; exit 1; }
cat "$OUT/gui.txt"
echo "screenshot: $OUT/panel.png"
grep -q "^built [0-9]* panels, 0 errors" "$OUT/gui.txt" || { echo "arena-gui: FAILED"; exit 1; }
