#!/usr/bin/env bash
# Watch a visit yourself: a fresh copy of a save scripts/visit.sh copied (its profile's original.zip, never the real
# file), in a game window, with Landing Party (and Editor Extensions and flib, copied from the real profile, to fly
# round). No test mod: nothing is scripted. Use /lp land serenity <tiles>, /lp fast, /lp list, /lp raid ... in game.
#   scripts/play-visit.sh [name]      (default visit; the profile factorio-lp-visit/<name>)
set -euo pipefail
source "$(dirname "$0")/env.sh"
NAME="${1:-visit}"
V="$HOME/Library/Application Support/factorio-lp-visit/$NAME"
[ -f "$V/saves/original.zip" ] || { echo "no $V/saves/original.zip: run scripts/visit.sh on a save first"; exit 1; }
cp "$V/saves/original.zip" "$V/saves/watch.zip"
rm -rf "$V/mods/lp-sim"
ln -sfn "$REPO/landing-party" "$V/mods/landing-party"
REAL="$HOME/Library/Application Support/factorio/mods"
extra=""
for m in EditorExtensions flib; do
  z=$(ls "$REAL/${m}_"*.zip 2>/dev/null | sort -V | tail -1 || true)
  if [ -n "$z" ]; then cp "$z" "$V/mods/"; extra="$extra, {\"name\": \"$m\", \"enabled\": true}"; fi
done
echo "{\"mods\": [{\"name\": \"base\", \"enabled\": true}, {\"name\": \"space-age\", \"enabled\": true}, {\"name\": \"quality\", \"enabled\": true}, {\"name\": \"elevated-rails\", \"enabled\": true}, {\"name\": \"landing-party\", \"enabled\": true}$extra]}" > "$V/mods/mod-list.json"
# Started from a folder holding steam_appid.txt, the game does not hand itself to Steam to relaunch.
L="$V/launch"; mkdir -p "$L"; echo 427520 > "$L/steam_appid.txt"
cd "$L"
exec "$FACTORIO" --config "$V/config/config.ini" --load-game "$V/saves/watch.zip"
