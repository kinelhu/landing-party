#!/usr/bin/env bash
# The arena to watch (tests/lp-arena, play mode): a fresh map, you in the air over a pen of lab tiles, a panel to set up
# each side (the corporations' units, yours, your lines, biters at any evolution) and Fight. /arena opens the panel again.
# Its own profile; close your game first (Steam allows one copy).
#   scripts/play-arena.sh
set -euo pipefail
source "$(dirname "$0")/env.sh"
PLAY="$HOME/Library/Application Support/factorio-lp-arena-play"
mkdir -p "$PLAY/config" "$PLAY/mods" "$PLAY/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$PLAY" > "$PLAY/config/config.ini"
ln -sfn "$REPO/landing-party" "$PLAY/mods/landing-party"
rm -rf "$PLAY/mods/lp-arena"; cp -R "$REPO/tests/lp-arena" "$PLAY/mods/lp-arena"
echo 'return {mode = "play"}' > "$PLAY/mods/lp-arena/params.lua"
cat > "$PLAY/mods/mod-list.json" <<JSON
{"mods": [{"name": "base", "enabled": true}, {"name": "landing-party", "enabled": true},
  {"name": "lp-arena", "enabled": true}, {"name": "space-age", "enabled": true},
  {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}]}
JSON
rm -f "$PLAY/saves/arena.zip"
"$FACTORIO" --config "$PLAY/config/config.ini" --create "$PLAY/saves/arena.zip" \
  --map-gen-settings "$REPO/scripts/map-gen.json" > "$PLAY/create.out" 2>&1 || { tail -20 "$PLAY/create.out"; exit 1; }
# Started from a folder holding steam_appid.txt, the game does not hand itself to Steam to relaunch.
L="$PLAY/launch"; mkdir -p "$L"; echo 427520 > "$L/steam_appid.txt"
cd "$L"
exec "$FACTORIO" --config "$PLAY/config/config.ini" --load-game "$PLAY/saves/arena.zip"
