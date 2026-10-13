#!/usr/bin/env bash
# Open the showcase save (scripts/showcase.sh) in the game window, on the play profile (base + Landing Party).
# Started from a folder holding steam_appid.txt, the game does not hand itself to Steam to relaunch.
set -euo pipefail
source "$(dirname "$0")/env.sh"
PLAY="$HOME/Library/Application Support/factorio-lp-play"
L="$PLAY/launch"; mkdir -p "$L"; echo 427520 > "$L/steam_appid.txt"
cd "$L"
exec "$FACTORIO" --config "$PLAY/config/config.ini" --load-game "$PLAY/saves/lp-showcase.zip"
