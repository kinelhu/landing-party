#!/usr/bin/env bash
# Watch a scenario in a game window (the factory instrument by default): the same map and test mod as scripts/sim.sh,
# loaded with a renderer so the scenario's screenshots land in "$W/script-output/lp-watch/" (shots.txt lists them).
# Needs the display awake (nothing renders when it sleeps) and the user's own game closed. The tips bubble's Tab is
# sent as scripts/shots.sh does.
#   LP_MIX=engage scripts/watch.sh [scenario] [seed] [minutes] [speed]
set -euo pipefail
source "$(dirname "$0")/env.sh"
SCENARIO="${1:-factory}"; SEED="${2:-12345}"; MINUTES="${3:-120}"; SPEED="${4:-10}"
W="$HOME/Library/Application Support/factorio-lp-watch"
mkdir -p "$W/config" "$W/mods" "$W/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$W" > "$W/config/config.ini"
ln -sfn "$REPO/landing-party" "$W/mods/landing-party"
rm -rf "$W/mods/lp-sim"; cp -R "$REPO/tests/lp-sim" "$W/mods/lp-sim"
printf 'return {scenario = "%s", minutes = %s, every = %s, strike = 1, distance = 300, radius = 220, doctrine = nil, units = 0, move = false, fast = false, mix = "%s", watch = true, watch_speed = %s}\n' \
  "$SCENARIO" "$MINUTES" "$MINUTES" "${LP_MIX:-}" "$SPEED" > "$W/mods/lp-sim/params.lua"
cat > "$W/mods/mod-list.json" <<JSON
{"mods": [{"name": "base", "enabled": true}, {"name": "landing-party", "enabled": true},
  {"name": "lp-sim", "enabled": true}, {"name": "space-age", "enabled": true},
  {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}]}
JSON
out="$W/script-output"
close_game() {
  pkill -f "$W/config/config.ini" 2>/dev/null || true
  for _ in 1 2 3 4 5; do pgrep -f "$W/config/config.ini" > /dev/null || return 0; sleep 1; done
  pkill -9 -f "$W/config/config.ini" 2>/dev/null || true
}
close_game
rm -rf "$out/lp-watch" "$out/landing-party" "$W/saves/watch.zip"
"$FACTORIO" --config "$W/config/config.ini" --create "$W/saves/watch.zip" --map-gen-seed "$SEED" \
  --map-gen-settings "$REPO/scripts/map-gen.json" > "$W/run.out" 2>&1 || { echo "WATCH FAILED: map"; exit 1; }
echo 427520 > "$W/steam_appid.txt"
(cd "$W" && exec "$FACTORIO" --config "$W/config/config.ini" --load-game "$W/saves/watch.zip" >> "$W/run.out" 2>&1) &
started=0; tabs=0; status=timeout
for i in $(seq 1 $((MINUTES * 60 / SPEED + 600))); do
  sleep 1
  [ -f "$out/landing-party/results.txt" ] && grep -q "^DONE" "$out/landing-party/results.txt" && { status=done; break; }
  grep -q "caused a non-recoverable error" "$W/factorio-current.log" 2>/dev/null && { status=error; break; }
  if pgrep -f "$W/config/config.ini" > /dev/null; then started=1; elif [ "$started" = 1 ]; then status=exited; break; fi
  if [ "$started" = 1 ] && [ $tabs -lt 6 ] && [ $((i % 5)) -eq 0 ]; then
    pid=$(pgrep -f "$W/config/config.ini" | head -1)
    osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $pid) to true" \
      -e 'delay 0.5' -e 'tell application "System Events" to key code 48' > /dev/null 2>&1 && tabs=$((tabs + 1)) || true
  fi
done
close_game
echo "WATCH: $status; shots in $out/lp-watch"
cat "$out/lp-watch/shots.txt" 2>/dev/null | tail -40
