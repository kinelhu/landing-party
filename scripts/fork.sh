#!/usr/bin/env bash
# Grow a scenario to its strike once, on a headless server, and keep the save: scripts/sim.sh with LP_FORK=1
# then runs only what follows the strike, from it (the growth was half of every siege run).
#   scripts/fork.sh <scenario> <seed> <strike minute>     (saved FORK_LEAD minutes before the strike; LP_FORK_MIX: a variant)
# The fork holds the settlement as the mod's code grew it then: confirm with full runs (no LP_FORK).
set -euo pipefail
source "$(dirname "$0")/env.sh"
SCENARIO="$1"; SEED="$2"; STRIKE="$3"
# LP_FORK_MIX: a variant forked as itself (its name and its scenario's mix); LP_MIX alone forks the plain scenario, as
# sim.sh LP_FORK reads it (the regression's siege 20-10-10 fork went missing when LP_MIX named it, 2026-11-04).
MIXTAG="${LP_FORK_MIX:+-$LP_FORK_MIX}"
SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-$SCENARIO$MIXTAG-$SEED-$STRIKE$WT"
mkdir -p "$FORKS" "$SIM/config" "$SIM/mods" "$SIM/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$SIM" > "$SIM/config/config.ini"
ln -sfn "$REPO/landing-party" "$SIM/mods/landing-party"
rm -rf "$SIM/mods/lp-sim"; cp -R "$REPO/tests/lp-sim" "$SIM/mods/lp-sim"
DOCTRINE="nil"; [ -n "${LP_DOCTRINE:-}" ] && DOCTRINE="\"$LP_DOCTRINE\""
printf 'return {scenario = "%s", minutes = %s, every = %s, strike = %s, distance = 300, radius = 220, doctrine = %s, units = 0, move = false, fast = %s, mix = "%s", save_at = %s}\n' \
  "$SCENARIO" "$((STRIKE + 1))" "$((STRIKE + 1))" "$STRIKE" "$DOCTRINE" "${LP_FAST:-false}" "${LP_FORK_MIX:-}" "$((STRIKE - FORK_LEAD))" > "$SIM/mods/lp-sim/params.lua"
cat > "$SIM/mods/mod-list.json" <<JSON
{"mods": [{"name": "base", "enabled": true}, {"name": "landing-party", "enabled": true},
  {"name": "lp-sim", "enabled": true}, {"name": "space-age", "enabled": true},
  {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}]}
JSON
python3 - "$APP/data/server-settings.example.json" > "$SIM/server-settings.json" <<'PY'
import json, re, sys
d = json.loads(re.sub(r"^\s*//.*$", "", open(sys.argv[1]).read(), flags=re.M))
d.update(name="lp-fork", description="", auto_pause=False, require_user_verification=False,
         visibility={"public": False, "lan": False})
print(json.dumps(d))
PY
out="$SIM/script-output/landing-party"
rm -rf "$out" "$SIM/saves/"*.zip
"$FACTORIO" --config "$SIM/config/config.ini" --create "$SIM/saves/sim.zip" --map-gen-seed "$SEED" \
  --map-gen-settings "$REPO/scripts/map-gen.json" > "$SIM/create.out" 2>&1 || {
  echo "FORK FAILED: map creation"; grep -A6 Error "$SIM/create.out" | head -12; exit 1; }
"$FACTORIO" --config "$SIM/config/config.ini" --start-server "$SIM/saves/sim.zip" \
  --server-settings "$SIM/server-settings.json" --port $((34300 + $$ % 3000)) > "$SIM/server.out" 2>&1 &
pid=$!
trap 'kill $pid 2>/dev/null || true' EXIT
for _ in $(seq 1 600); do
  [ -f "$out/saved.txt" ] && [ -f "$SIM/saves/fork.zip" ] && break
  kill -0 $pid 2>/dev/null || { echo "FORK FAILED: server exited"; grep -A8 Error "$SIM/server.out" | head -20; exit 1; }
  sleep 1
done
sleep 3
[ -f "$SIM/saves/fork.zip" ] || { echo "FORK FAILED: no save"; exit 1; }
cp "$SIM/saves/fork.zip" "$FORKS/$SCENARIO$MIXTAG-$SEED-$STRIKE-$FORK_HASH.zip"
echo "fork at tick $(cat "$out/saved.txt"): $FORKS/$SCENARIO$MIXTAG-$SEED-$STRIKE-$FORK_HASH.zip"
