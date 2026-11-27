#!/usr/bin/env bash
# Build a save to look at in game: the showcase scenario (tests/lp-sim) run on a headless server, which saves
# at the strike minute; then copy it to the play profile (base game and Landing Party only).
#   scripts/showcase.sh [seed] [minute]      then: scripts/play-showcase.sh
#   LP_MIX=tour scripts/showcase.sh 12345 20  then: scripts/play-showcase.sh tour   (/lp dev tools' playground)
set -euo pipefail
source "$(dirname "$0")/env.sh"
SEED="${1:-12345}"; MINUTE="${2:-15}"
SIM="$HOME/Library/Application Support/factorio-lp-sim/showcase-$SEED"
PLAY="$HOME/Library/Application Support/factorio-lp-play"
mkdir -p "$SIM/config" "$SIM/mods" "$SIM/saves" "$PLAY/config" "$PLAY/mods" "$PLAY/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$SIM" > "$SIM/config/config.ini"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$PLAY" > "$PLAY/config/config.ini"
ln -sfn "$REPO/landing-party" "$SIM/mods/landing-party"
ln -sfn "$REPO/landing-party-graphics" "$SIM/mods/landing-party-graphics"
ln -sfn "$REPO/landing-party" "$PLAY/mods/landing-party"
ln -sfn "$REPO/landing-party-graphics" "$PLAY/mods/landing-party-graphics"
rm -rf "$SIM/mods/lp-sim"; cp -R "$REPO/tests/lp-sim" "$SIM/mods/lp-sim"
printf 'return {scenario = "showcase", minutes = %s, every = %s, strike = %s, distance = 300, radius = 220, doctrine = nil, units = 0, move = false, fast = false, mix = "%s"}\n' \
  "$((MINUTE + 1))" "$((MINUTE + 1))" "$MINUTE" "${LP_MIX:-}" > "$SIM/mods/lp-sim/params.lua"
mods='{"name": "base", "enabled": true}, {"name": "landing-party", "enabled": true},{"name":"landing-party-graphics","enabled":true}, {"name": "space-age", "enabled": true}, {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}'
echo "{\"mods\": [$mods, {\"name\": \"lp-sim\", \"enabled\": true}]}" > "$SIM/mods/mod-list.json"
# Editor Extensions (and flib) for flying round without pausing: copied from the real profile, never linked.
REAL="$HOME/Library/Application Support/factorio/mods"
extra=""
for m in EditorExtensions flib; do
  z=$(ls "$REAL/${m}_"*.zip 2>/dev/null | sort -V | tail -1 || true)
  if [ -n "$z" ]; then cp "$z" "$PLAY/mods/"; extra="$extra, {\"name\": \"$m\", \"enabled\": true}"; fi
done
echo "{\"mods\": [$mods$extra]}" > "$PLAY/mods/mod-list.json"
# The server wants every key of the example settings: start from it, never public, never paused.
python3 - "$APP/data/server-settings.example.json" > "$SIM/server-settings.json" <<'PY'
import json, re, sys
d = json.loads(re.sub(r"^\s*//.*$", "", open(sys.argv[1]).read(), flags=re.M))
d.update(name="lp-showcase", description="", auto_pause=False, require_user_verification=False,
         visibility={"public": False, "lan": False})
print(json.dumps(d))
PY
out="$SIM/script-output/landing-party"
rm -rf "$out" "$SIM/saves/"*.zip
"$FACTORIO" --config "$SIM/config/config.ini" --create "$SIM/saves/sim.zip" --map-gen-seed "$SEED" \
  --map-gen-settings "$REPO/scripts/map-gen.json" > "$SIM/create.out" 2>&1
"$FACTORIO" --config "$SIM/config/config.ini" --start-server "$SIM/saves/sim.zip" \
  --server-settings "$SIM/server-settings.json" --port 34299 > "$SIM/server.out" 2>&1 &
pid=$!
trap 'kill $pid 2>/dev/null || true' EXIT
for _ in $(seq 1 600); do
  [ -f "$out/saved.txt" ] && [ -f "$SIM/saves/lp-showcase.zip" ] && break
  kill -0 $pid 2>/dev/null || { echo "server exited early"; tail -30 "$SIM/server.out"; exit 1; }
  sleep 2
done
sleep 5
[ -f "$SIM/saves/lp-showcase.zip" ] || { echo "no save written"; tail -30 "$SIM/server.out"; exit 1; }
NAME="lp-${LP_MIX:-showcase}"; [ -n "${LP_MIX:-}" ] || NAME=lp-showcase
cp "$SIM/saves/lp-showcase.zip" "$PLAY/saves/$NAME.zip"
echo "saved at tick $(cat "$out/saved.txt"): $PLAY/saves/$NAME.zip"
