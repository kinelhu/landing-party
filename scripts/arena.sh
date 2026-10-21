#!/usr/bin/env bash
# The arena's balance table: every matchup of tests/lp-arena/batch.lua fought headless (three rounds), the results in
# docs/arena/results.jsonl and the table in docs/arena.md (scripts/arena_report.py).
#   scripts/arena.sh
set -euo pipefail
source "$(dirname "$0")/env.sh"
SIM="$HOME/Library/Application Support/factorio-lp-arena${LP_TAG:+-$LP_TAG}"
mkdir -p "$SIM/config" "$SIM/mods" "$SIM/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$SIM" > "$SIM/config/config.ini"
ln -sfn "$REPO/landing-party" "$SIM/mods/landing-party"
rm -rf "$SIM/mods/lp-arena"; cp -R "$REPO/tests/lp-arena" "$SIM/mods/lp-arena"
# LP_ARENA_ONLY: a trial of the matchups whose label holds that text; LP_ARENA_ROUNDS: rounds (3).
printf 'return {mode = "batch", only = "%s", rounds = %s}\n' "${LP_ARENA_ONLY:-}" "${LP_ARENA_ROUNDS:-3}" > "$SIM/mods/lp-arena/params.lua"
cat > "$SIM/mods/mod-list.json" <<JSON
{"mods": [{"name": "base", "enabled": true}, {"name": "landing-party", "enabled": true},
  {"name": "lp-arena", "enabled": true}, {"name": "space-age", "enabled": true},
  {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}]}
JSON
out="$SIM/script-output/lp-arena"
rm -rf "$out" "$SIM/saves/arena.zip"
run() { "$FACTORIO" --config "$SIM/config/config.ini" "$@" > "$SIM/arena.out" 2>&1 || {
  echo "ARENA FAILED: factorio exited non-zero"; grep -hnE -A8 "Error" "$SIM/factorio-current.log" "$SIM/arena.out" | head -40; exit 1; }; }
run --create "$SIM/saves/arena.zip" --map-gen-seed "${LP_ARENA_SEED:-1}" --map-gen-settings "$REPO/scripts/map-gen.json"
run --benchmark "$SIM/saves/arena.zip" --benchmark-ticks "${LP_ARENA_TICKS:-36000}" --benchmark-runs 1
[ -f "$out/done.txt" ] || { echo "ARENA FAILED: not every fight was decided ($(wc -l < "$out/results.jsonl" 2>/dev/null || echo 0) written)"; exit 1; }
echo "$(cat "$out/done.txt")"
[ -z "${LP_ARENA_ONLY:-}" ] || { cat "$out/results.jsonl"; exit 0; }
mkdir -p "$REPO/docs/arena"
cp "$out/results.jsonl" "$REPO/docs/arena/results.jsonl"
python3 -I "$REPO/scripts/arena_report.py" "$REPO/docs/arena/results.jsonl" "$REPO/docs/arena.md"
