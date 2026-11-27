#!/usr/bin/env bash
# Watch a test scenario yourself: the scenario as scripts/sim.sh sets it up (same map, test mod, params), opened in a game
# window at normal speed instead of run headless. Your own game must be closed (Steam allows one copy).
#   scripts/watch-sim.sh <scenario> [seed]     e.g. LP_MIX=worms scripts/watch-sim.sh clear
# Editor Extensions (copied from the real profile) lets you watch untouchable: /editor, or its own toggle.
# In game: the map (M) to find the action; `/c game.player.teleport{x, y}` to go there (a test profile: achievements
# do not matter). The scenario's events happen on its own clock (clear: nests at 2 min, the first clearance soon after).
set -euo pipefail
source "$(dirname "$0")/env.sh"
SCENARIO="${1:?usage: scripts/watch-sim.sh <scenario> [seed]}"; SEED="${2:-12345}"; MINUTES="${LP_MINUTES:-60}"
SIM="$HOME/Library/Application Support/factorio-lp-watch/$SCENARIO-$SEED${LP_MIX:+-$LP_MIX}"
mkdir -p "$SIM/config" "$SIM/mods" "$SIM/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$SIM" > "$SIM/config/config.ini"
ln -sfn "$REPO/landing-party" "$SIM/mods/landing-party"
ln -sfn "$REPO/landing-party-graphics" "$SIM/mods/landing-party-graphics"
rm -rf "$SIM/mods/lp-sim"; cp -R "$REPO/tests/lp-sim" "$SIM/mods/lp-sim"
printf 'return {scenario = "%s", minutes = %s, every = %s, strike = 1, distance = %s, radius = %s, doctrine = nil, units = 0, move = false, fast = false, mix = "%s"}\n' \
  "$SCENARIO" "$MINUTES" "$MINUTES" "${LP_DISTANCE:-300}" "${LP_RADIUS:-220}" "${LP_MIX:-}" > "$SIM/mods/lp-sim/params.lua"
# Editor Extensions and flib, copied from the real profile (never written to), to fly round untouchable.
REAL="$HOME/Library/Application Support/factorio/mods"
extra=""
for m in EditorExtensions flib; do
  z=$(ls "$REAL/${m}_"*.zip 2>/dev/null | sort -V | tail -1 || true)
  if [ -n "$z" ]; then cp "$z" "$SIM/mods/"; extra="$extra, {\"name\": \"$m\", \"enabled\": true}"; else echo "no $m in $REAL"; fi
done
cat > "$SIM/mods/mod-list.json" <<JSON
{"mods": [{"name": "base", "enabled": true}, {"name": "landing-party", "enabled": true},{"name":"landing-party-graphics","enabled":true},
  {"name": "lp-sim", "enabled": true}, {"name": "space-age", "enabled": true},
  {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}$extra]}
JSON
rm -f "$SIM/saves/watch.zip"
"$FACTORIO" --config "$SIM/config/config.ini" --create "$SIM/saves/watch.zip" --map-gen-seed "$SEED" \
  --map-gen-settings "$REPO/scripts/map-gen.json" > "$SIM/create.out" 2>&1
echo "decisions: $SIM/script-output/landing-party/decisions.txt"
L="$SIM/launch"; mkdir -p "$L"; echo 427520 > "$L/steam_appid.txt"
cd "$L"
exec "$FACTORIO" --config "$SIM/config/config.ini" --load-game "$SIM/saves/watch.zip"
