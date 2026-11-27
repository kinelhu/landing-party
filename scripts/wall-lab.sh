#!/usr/bin/env bash
# The wall lab: waves of the biotech's breeds at a stretch of nw's north wall rebuilt in the arena (tests/lp-arena/
# nwwall.lua), headless, three rounds; one line a fight in script-output/lp-arena/wall.jsonl, a table on stdout.
#   scripts/wall-lab.sh            LP_ARENA_ONLY=<text>: the waves whose label holds it; LP_ARENA_ROUNDS: rounds (3)
set -euo pipefail
source "$(dirname "$0")/env.sh"
SIM="$HOME/Library/Application Support/factorio-lp-wall${LP_TAG:+-$LP_TAG}"
mkdir -p "$SIM/config" "$SIM/mods" "$SIM/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$SIM" > "$SIM/config/config.ini"
ln -sfn "$REPO/landing-party" "$SIM/mods/landing-party"
ln -sfn "$REPO/landing-party-graphics" "$SIM/mods/landing-party-graphics"
rm -rf "$SIM/mods/lp-arena"; cp -R "$REPO/tests/lp-arena" "$SIM/mods/lp-arena"
printf 'return {mode = "wall", only = "%s", rounds = %s}\n' "${LP_ARENA_ONLY:-}" "${LP_ARENA_ROUNDS:-3}" > "$SIM/mods/lp-arena/params.lua"
cat > "$SIM/mods/mod-list.json" <<JSON
{"mods": [{"name": "base", "enabled": true}, {"name": "landing-party", "enabled": true},{"name":"landing-party-graphics","enabled":true},
  {"name": "lp-arena", "enabled": true}, {"name": "space-age", "enabled": true},
  {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}]}
JSON
out="$SIM/script-output/lp-arena"
rm -rf "$out" "$SIM/saves/wall.zip"
run() { "$FACTORIO" --config "$SIM/config/config.ini" "$@" > "$SIM/wall.out" 2>&1 || {
  echo "WALL LAB FAILED: factorio exited non-zero"; grep -hnE -A8 "Error" "$SIM/factorio-current.log" "$SIM/wall.out" | head -40; exit 1; }; }
run --create "$SIM/saves/wall.zip" --map-gen-seed 1 --map-gen-settings "$REPO/scripts/map-gen.json"
run --benchmark "$SIM/saves/wall.zip" --benchmark-ticks "${LP_ARENA_TICKS:-60000}" --benchmark-runs 1
[ -f "$out/done.txt" ] || { echo "WALL LAB FAILED: not every fight was decided ($(wc -l < "$out/wall.jsonl" 2>/dev/null || echo 0) written)"; exit 1; }
cat "$out/done.txt"; echo
uv run python3 -I "$REPO/scripts/wall_report.py" "$out/wall.jsonl"
