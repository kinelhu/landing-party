#!/usr/bin/env bash
# Screenshot scenes in a real game window (tests/lp-shots, own profile): what headless runs cannot judge, seen. About
# two minutes; then the game closes and the shots are in "$SH/script-output/lp-shots/" (shots.txt says what to look for
# in each). Steam must be running and the user's own game closed (one copy at a time). The game's tips bubble waits for
# one Tab press after launch (empirical-science's GUI test found this): the script sends it through System Events,
# which needs the terminal to have Accessibility permission; without it, press Tab in the game window once.
set -euo pipefail
source "$(dirname "$0")/env.sh"
SH="$HOME/Library/Application Support/factorio-lp-shots"
mkdir -p "$SH/config" "$SH/mods" "$SH/saves"
# (The tips bubble off, 2026-11-19: on the Studio, over ssh, the Tab below asks macOS for leave to control System
# Events, and nobody is at that screen to give it. LP_NOTAB=1 skips the Tab.)
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n[interface]\nshow-tips-and-tricks-notifications=false\n' "$SH" > "$SH/config/config.ini"
ln -sfn "$REPO/landing-party" "$SH/mods/landing-party"
ln -sfn "$REPO/landing-party-graphics" "$SH/mods/landing-party-graphics"
ln -sfn "$REPO/tests/lp-shots" "$SH/mods/lp-shots"
# LP_SHOTS=town: Grubstake's town only, grown at once; LP_SHOTS=culture: a Synthexis culture eight minutes on
# (tests/lp-shots/mode.lua, not in git).
echo "return \"${LP_SHOTS:-all}\"" > "$REPO/tests/lp-shots/mode.lua"
cat > "$SH/mods/mod-list.json" <<JSON
{"mods": [{"name": "base", "enabled": true}, {"name": "space-age", "enabled": true}, {"name": "quality", "enabled": true},
  {"name": "elevated-rails", "enabled": true}, {"name": "landing-party", "enabled": true},{"name":"landing-party-graphics","enabled":true}, {"name": "lp-shots", "enabled": true}]}
JSON
out="$SH/script-output/lp-shots"
close_game() {
  pkill -f "$SH/config/config.ini" 2>/dev/null || true
  for _ in 1 2 3 4 5; do pgrep -f "$SH/config/config.ini" > /dev/null || return 0; sleep 1; done
  pkill -9 -f "$SH/config/config.ini" 2>/dev/null || true
}
close_game
rm -rf "$out" "$SH/saves/shots.zip"
"$FACTORIO" --config "$SH/config/config.ini" --create "$SH/saves/shots.zip" --map-gen-seed 4242 > "$SH/run.out" 2>&1 \
  || { echo "SHOTS FAILED: could not create map"; tail -20 "$SH/run.out"; exit 1; }
echo 427520 > "$SH/steam_appid.txt"
(cd "$SH" && exec "$FACTORIO" --config "$SH/config/config.ini" --load-game "$SH/saves/shots.zip" >> "$SH/run.out" 2>&1) &
status="timeout"; started=0; tabs=0
for i in $(seq 1 1500); do
  sleep 1
  [ -f "$out/done.txt" ] && { status="done"; break; }
  grep -q "caused a non-recoverable error" "$SH/factorio-current.log" 2>/dev/null && { status="error"; break; }
  if pgrep -f "$SH/config/config.ini" > /dev/null; then started=1; elif [ "$started" = 1 ]; then status="exited"; break; fi
  # The tips bubble's Tab: a few tries once the window is up.
  if [ -z "${LP_NOTAB:-}" ] && [ "$started" = 1 ] && [ $tabs -lt 6 ] && [ $((i % 5)) -eq 0 ]; then
    pid=$(pgrep -f "$SH/config/config.ini" | head -1)
    osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $pid) to true" \
      -e 'delay 0.5' -e 'tell application "System Events" to key code 48' > "$SH/tab.out" 2>&1 && tabs=$((tabs + 1)) || true
  fi
done
close_game
case "$status" in
  done) echo "SHOTS: $out"; cat "$out/shots.txt" ;;
  error) echo "SHOTS FAILED: mod error"; grep -A8 "non-recoverable" "$SH/factorio-current.log" | head -14; exit 1 ;;
  *) echo "SHOTS FAILED: $status (Tab sent $tabs times)"; tail -15 "$SH/factorio-current.log"; [ -f "$out/shots.txt" ] && cat "$out/shots.txt"; exit 1 ;;
esac
