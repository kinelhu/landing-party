#!/usr/bin/env bash
# Watch a visit yourself: a fresh copy of a save scripts/visit.sh copied (its profile's original.zip, never the real
# file), in a game window, with Landing Party (and Editor Extensions and flib, copied from the real profile, to fly
# round). No test mod: nothing is scripted. Use /lp land serenity <tiles>, /lp fast, /lp list, /lp raid ... in game.
#   scripts/play-visit.sh [name]      (default visit; the profile factorio-lp-visit/<name>)
#   LP_WATCH=<save in that profile's saves>: that save instead of a fresh copy (a siege saved by LP_MIX=savesiege).
set -euo pipefail
source "$(dirname "$0")/env.sh"
NAME="${1:-visit}"
V="$HOME/Library/Application Support/factorio-lp-visit/$NAME"
# A game already on this profile (a play-visit.sh window, another visit): touching its mods and saves under it
# unlinked Landing Party from a game being played (2026-10-17).
if pgrep -f -- "--config $V/config/config.ini" > /dev/null; then
  echo "refusing: a game is running on $V (close it, or use another LP_MIX)"; exit 1
fi
[ -f "$V/saves/original.zip" ] || { echo "no $V/saves/original.zip: run scripts/visit.sh on a save first"; exit 1; }
if [ -n "${LP_WATCH:-}" ]; then
  [ -f "$V/saves/$LP_WATCH" ] || { echo "no $V/saves/$LP_WATCH"; exit 1; }
  cp "$V/saves/$LP_WATCH" "$V/saves/watch.zip"
else
  cp "$V/saves/original.zip" "$V/saves/watch.zip"
fi
rm -rf "$V/mods/lp-sim"
ln -sfn "$REPO/landing-party" "$V/mods/landing-party"
REAL="$HOME/Library/Application Support/factorio/mods"
extra=""
for m in EditorExtensions flib; do
  z=$(ls "$REAL/${m}_"*.zip 2>/dev/null | sort -V | tail -1 || true)
  # Only a copy made for this Factorio (2.1): the real profile's 2.0 copies are refused at load (the user, 2026-10-26).
  if [ -n "$z" ] && unzip -p "$z" '*/info.json' 2>/dev/null | grep -q '"factorio_version": *"2.1"'; then
    cp "$z" "$V/mods/"; extra="$extra, {\"name\": \"$m\", \"enabled\": true}"
  else
    rm -f "$V/mods/${m}_"*.zip
  fi
done
echo "{\"mods\": [{\"name\": \"base\", \"enabled\": true}, {\"name\": \"space-age\", \"enabled\": true}, {\"name\": \"quality\", \"enabled\": true}, {\"name\": \"elevated-rails\", \"enabled\": true}, {\"name\": \"landing-party\", \"enabled\": true}$extra]}" > "$V/mods/mod-list.json"
# Started from a folder holding steam_appid.txt, the game does not hand itself to Steam to relaunch.
L="$V/launch"; mkdir -p "$L"; echo 427520 > "$L/steam_appid.txt"
cd "$L"
exec "$FACTORIO" --config "$V/config/config.ini" --load-game "$V/saves/watch.zip"
