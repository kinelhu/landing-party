#!/usr/bin/env bash
# A save to watch a Synthexis siege in a window: the nw breach lab (LP_MIX breachlab, savesiege) run as a headless server
# at speed until a siege's wave sets out, saved there (saves/siege.zip in the visit profile), then stopped. Watch it with
#   LP_WATCH=siege.zip scripts/play-visit.sh nw-waves0-breachlabsavesiege
#   scripts/siege-save.sh <copy of a save.zip>     (scripts/visit.sh first, so its profile exists)
set -euo pipefail
source "$(dirname "$0")/env.sh"
SAVE="${1:?usage: scripts/siege-save.sh <save.zip>}"
NAME="$(basename "$SAVE" .zip)"
# LP_MIX, LP_SAVE, LP_MINUTES: another visit saved the same way (LP_MIX=rich-saveat200 LP_SAVE=t200 LP_MINUTES=210: the
# fed nw visit saved at minute 200, the user, 2026-11-01).
MIX="${LP_MIX:-waves0-breachlabsavesiege}"; SNAME="${LP_SAVE:-siege}"; MINS="${LP_MINUTES:-60}"
V="$HOME/Library/Application Support/factorio-lp-visit/$NAME-$MIX"
case "$V" in *"/factorio/"*) echo "refusing: $V is inside the real profile"; exit 1;; esac
mkdir -p "$V/config" "$V/mods" "$V/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$V" > "$V/config/config.ini"
cp "$SAVE" "$V/saves/original.zip"; cp "$SAVE" "$V/saves/visit.zip"; rm -f "$V/saves/$SNAME.zip" "$V/saves/_autosave-$SNAME.zip"
ln -sfn "$REPO/landing-party" "$V/mods/landing-party"
ln -sfn "$REPO/landing-party-graphics" "$V/mods/landing-party-graphics"
rm -rf "$V/mods/lp-sim"; cp -R "$REPO/tests/lp-sim" "$V/mods/lp-sim"
printf 'return {scenario = "visit", minutes = %s, every = %s, strike = 1, distance = 300, radius = 220, doctrine = nil, units = 0, move = false, fast = false, mix = "%s"}\n' "$MINS" "$MINS" "$MIX" > "$V/mods/lp-sim/params.lua"
echo '{"mods": [{"name": "base", "enabled": true}, {"name": "space-age", "enabled": true}, {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}, {"name": "landing-party", "enabled": true},{"name":"landing-party-graphics","enabled":true}, {"name": "lp-sim", "enabled": true}]}' > "$V/mods/mod-list.json"
# (The game's own example, with nothing public and nothing paused or autosaved: a partial file is refused.)
python3 - "$APP/data/server-settings.example.json" "$V/server-settings.json" <<'PY2'
import json, sys
s = json.load(open(sys.argv[1]))
s.update({"name": "lp-siege", "description": "", "visibility": {"public": False, "lan": False},
          "require_user_verification": False, "auto_pause": False, "autosave_interval": 0, "autosave_slots": 1})
json.dump(s, open(sys.argv[2], "w"))
PY2
"$FACTORIO" --config "$V/config/config.ini" --start-server "$V/saves/visit.zip" --server-settings "$V/server-settings.json" --port 34297 > "$V/server.out" 2>&1 &
PID=$!
for _ in $(seq 1 7200); do
  [ -f "$V/saves/_autosave-$SNAME.zip" ] && break
  kill -0 "$PID" 2>/dev/null || { echo "SIEGE SAVE FAILED: the server stopped"; tail -20 "$V/server.out"; exit 1; }
  sleep 1
done
sleep 10
kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true
[ -f "$V/saves/_autosave-$SNAME.zip" ] || { echo "SIEGE SAVE FAILED: no save within two hours"; exit 1; }
cp "$V/saves/_autosave-$SNAME.zip" "$V/saves/$SNAME.zip"
grep -h "siege of farm" "$V/script-output/landing-party/results.txt" 2>/dev/null || true
echo "saved: $V/saves/$SNAME.zip"
