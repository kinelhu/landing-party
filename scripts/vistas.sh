#!/usr/bin/env bash
# The field guide's vistas (docs/guide, scripts/roster_page.py): a game window on a copy of the all-factions save
# (LP_MIX=all scripts/showcase.sh 12345 30 first), with tests/lp-vista taking each faction's base, then closing. Steam
# running and the user's own game closed (one copy at a time). Shots in "$SH/script-output/lp-vista/".
#   scripts/vistas.sh
set -euo pipefail
source "$(dirname "$0")/env.sh"
SH="$HOME/Library/Application Support/factorio-lp-vista"
mkdir -p "$SH/config" "$SH/mods" "$SH/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$SH" > "$SH/config/config.ini"
ln -sfn "$REPO/landing-party" "$SH/mods/landing-party"
ln -sfn "$REPO/landing-party-graphics" "$SH/mods/landing-party-graphics"
ln -sfn "$REPO/tests/lp-vista" "$SH/mods/lp-vista"
cat > "$SH/mods/mod-list.json" <<JSON
{"mods": [{"name": "base", "enabled": true}, {"name": "space-age", "enabled": true}, {"name": "quality", "enabled": true},
  {"name": "elevated-rails", "enabled": true}, {"name": "landing-party", "enabled": true},{"name":"landing-party-graphics","enabled":true}, {"name": "lp-vista", "enabled": true}]}
JSON
out="$SH/script-output/lp-vista"
close_game() {
  pkill -f "$SH/config/config.ini" 2>/dev/null || true
  for _ in 1 2 3 4 5; do pgrep -f "$SH/config/config.ini" > /dev/null || return 0; sleep 1; done
  pkill -9 -f "$SH/config/config.ini" 2>/dev/null || true
}
close_game
rm -rf "$out" "$SH/saves/shots.zip"
cp "$HOME/Library/Application Support/factorio-lp-play/saves/lp-all.zip" "$SH/saves/shots.zip"
echo 427520 > "$SH/steam_appid.txt"
(cd "$SH" && exec "$FACTORIO" --config "$SH/config/config.ini" --load-game "$SH/saves/shots.zip" >> "$SH/run.out" 2>&1) &
status="timeout"; started=0; tabs=0
for i in $(seq 1 900); do
  sleep 1
  [ -f "$out/done.txt" ] && { status="done"; break; }
  grep -q "caused a non-recoverable error" "$SH/factorio-current.log" 2>/dev/null && { status="error"; break; }
  if pgrep -f "$SH/config/config.ini" > /dev/null; then started=1; elif [ "$started" = 1 ]; then status="exited"; break; fi
  # The tips bubble's Tab: a few tries once the window is up.
  if [ "$started" = 1 ] && [ $tabs -lt 6 ] && [ $((i % 5)) -eq 0 ]; then
    pid=$(pgrep -f "$SH/config/config.ini" | head -1)
    osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $pid) to true" \
      -e 'delay 0.5' -e 'tell application "System Events" to key code 48' > "$SH/tab.out" 2>&1 && tabs=$((tabs + 1)) || true
  fi
done
close_game
case "$status" in
  done) echo "SHOTS: $out"; cat "$out/notes.txt" ;;
  error) echo "SHOTS FAILED: mod error"; grep -A8 "non-recoverable" "$SH/factorio-current.log" | head -14; exit 1 ;;
  *) echo "SHOTS FAILED: $status (Tab sent $tabs times)"; tail -15 "$SH/factorio-current.log"; [ -f "$out/shots.txt" ] && cat "$out/notes.txt"; exit 1 ;;
esac
