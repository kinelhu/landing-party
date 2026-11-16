#!/usr/bin/env bash
# A visit's moments as saves (films: docs/trailer): the visit visit.sh prepared (its profile, LP_MIX with saveatN...)
# run again as a headless server, which writes the saves (a benchmark writes none), at speed, till its last save point.
#   LP_MIX=<the visit's mix, with saveatN-...> scripts/visit_saves.sh <save.zip>    (after scripts/visit.sh with the same)
# Saves: <profile>/saves/tN.zip.
set -euo pipefail
source "$(dirname "$0")/env.sh"
SAVE="${1:?usage: scripts/visit_saves.sh <save.zip>}"
NAME="$(basename "$SAVE" .zip)"
# (The same profile name as visit.sh's, LP_OFF, LP_DIRECTOR and LP_TUNETAG included: it read LP_MIX alone and found no
# visit prepared with a director, 2026-11-16.)
V="$HOME/Library/Application Support/factorio-lp-visit/$NAME${LP_MIX:+-$LP_MIX}${LP_OFF:+-no-${LP_OFF//,/-}}${LP_DIRECTOR:+-dir-$LP_DIRECTOR}${LP_TUNETAG:+-$LP_TUNETAG}"
[ -f "$V/saves/visit.zip" ] || { echo "no prepared visit at $V (run scripts/visit.sh first)"; exit 1; }
LAST=$(echo "${LP_MIX:-}" | grep -oE "saveat[0-9]+" | grep -oE "[0-9]+" | sort -n | tail -1)
[ -n "$LAST" ] || { echo "LP_MIX has no saveatN"; exit 1; }
python3 - "$APP/data/server-settings.example.json" > "$V/server-settings.json" <<'PY'
import json, re, sys
d = json.loads(re.sub(r"^\s*//.*$", "", open(sys.argv[1]).read(), flags=re.M))
d.update(name="lp-visit-saves", description="", auto_pause=False, require_user_verification=False,
         visibility={"public": False, "lan": False})
print(json.dumps(d))
PY
# The harness as it is now (its params kept): the visit's copy is from when visit.sh ran.
cp "$REPO/tests/lp-sim/control.lua" "$V/mods/lp-sim/control.lua"
out="$V/script-output/landing-party"
rm -f "$out"/saved-*.txt
# On a copy: a server saves the map it loaded when it quits, and visit.zip overwritten so made a second run start mid-visit
# with its harness state gone and its save points past (it ran on and never saved; 2026-11-06).
cp "$V/saves/visit.zip" "$V/saves/visit-server.zip"
"$FACTORIO" --config "$V/config/config.ini" --start-server "$V/saves/visit-server.zip" --server-settings "$V/server-settings.json" \
  --port $((34300 + $$ % 3000)) > "$V/server.out" 2>&1 &
pid=$!
trap 'kill $pid 2>/dev/null || true' EXIT
for _ in $(seq 1 7200); do
  [ -f "$out/saved-$LAST.txt" ] && break
  kill -0 $pid 2>/dev/null || { echo "VISIT SAVES FAILED: server exited"; grep -A8 Error "$V/server.out" | head -20; exit 1; }
  sleep 1
done
sleep 5
ls "$V/saves/" | grep -E "^t[0-9]+\.zip$" | sed "s|^|saved: $V/saves/|"
