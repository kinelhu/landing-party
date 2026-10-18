#!/usr/bin/env bash
# Build a reference factory (tests/lp-ref) on a map with default biters, without Landing Party, and keep its save for
# scripts/visit.sh: the corporations against a control base of a known kind.
#   scripts/make_reference.sh <belt|laser|artillery> [seed] [evolution]
#   then: scripts/visit.sh "$HOME/Library/Application Support/factorio-lp-ref/<kind>.zip" 180
# Its own profile (factorio-lp-ref-build); mods as a visit's base (Space Age, Quality, Elevated Rails).
set -euo pipefail
source "$(dirname "$0")/env.sh"
KIND="${1:?usage: scripts/make_reference.sh <belt|laser|artillery> [seed] [evolution]}"; SEED="${2:-1234}"; EVO="${3:-}"
case "$KIND" in belt) EVO="${EVO:-0.3}";; laser) EVO="${EVO:-0.6}";; artillery) EVO="${EVO:-0.8}";;
  *) echo "kind: belt, laser or artillery"; exit 1;; esac
SIM="$HOME/Library/Application Support/factorio-lp-ref-build/$KIND"
OUT="$HOME/Library/Application Support/factorio-lp-ref"
mkdir -p "$SIM/config" "$SIM/mods" "$SIM/saves" "$OUT"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$SIM" > "$SIM/config/config.ini"
rm -rf "$SIM/mods/lp-ref"; cp -R "$REPO/tests/lp-ref" "$SIM/mods/lp-ref"
printf 'return {kind = "%s", save_at = 600, evolution = %s}\n' "$KIND" "$EVO" > "$SIM/mods/lp-ref/params.lua"
cat > "$SIM/mods/mod-list.json" <<JSON
{"mods": [{"name": "base", "enabled": true}, {"name": "space-age", "enabled": true}, {"name": "quality", "enabled": true},
  {"name": "elevated-rails", "enabled": true}, {"name": "lp-ref", "enabled": true}]}
JSON
python3 - "$APP/data/server-settings.example.json" > "$SIM/server-settings.json" <<'PY'
import json, re, sys
d = json.loads(re.sub(r"^\s*//.*$", "", open(sys.argv[1]).read(), flags=re.M))
d.update(name="lp-ref", description="", auto_pause=False, require_user_verification=False,
         visibility={"public": False, "lan": False})
print(json.dumps(d))
PY
out="$SIM/script-output/lp-ref"
rm -rf "$out" "$SIM/saves/"*.zip
"$FACTORIO" --config "$SIM/config/config.ini" --create "$SIM/saves/start.zip" --map-gen-seed "$SEED" > "$SIM/create.out" 2>&1 || {
  echo "REFERENCE FAILED: map creation"; grep -A6 Error "$SIM/create.out" | head -12; exit 1; }
"$FACTORIO" --config "$SIM/config/config.ini" --start-server "$SIM/saves/start.zip" \
  --server-settings "$SIM/server-settings.json" --port $((34300 + $$ % 3000)) > "$SIM/server.out" 2>&1 &
pid=$!
trap 'kill $pid 2>/dev/null || true' EXIT
for _ in $(seq 1 600); do
  [ -f "$out/saved.txt" ] && [ -f "$SIM/saves/ref.zip" ] && break
  kill -0 $pid 2>/dev/null || { echo "REFERENCE FAILED: server exited"; grep -A8 Error "$SIM/server.out" | head -20; exit 1; }
  sleep 1
done
sleep 3
[ -f "$SIM/saves/ref.zip" ] || { echo "REFERENCE FAILED: no save"; exit 1; }
cp "$SIM/saves/ref.zip" "$OUT/$KIND.zip"
echo "reference $(cat "$out/built.txt" | tr -d '\n'); saved at tick $(cat "$out/saved.txt"): $OUT/$KIND.zip"
