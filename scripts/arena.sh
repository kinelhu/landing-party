#!/usr/bin/env bash
# The arena's balance table: every matchup of tests/lp-arena/batch.lua fought headless (three rounds), the results in
# docs/arena/results.jsonl and the table in docs/arena.md (scripts/arena_report.py).
#   scripts/arena.sh
# LP_ARENA_ONLY: a trial of the matchups whose label holds that text; LP_ARENA_ROUNDS: rounds (3).
# LP_ARENA_TIER: the player's tiered units (shared.TIERED) fire that round (an item name: ammunition tiers, 0.2.470).
# LP_ARENA_JOBS: games in parallel (4), each with its own profile and every n-th matchup (batch.lua's shard); their
# results merged. The machine-load rule holds: 4 at most, none while a game window is open.
set -euo pipefail
source "$(dirname "$0")/env.sh"
JOBS="${LP_ARENA_JOBS:-4}"
[ "$JOBS" -le 4 ] || { echo "LP_ARENA_JOBS at most 4"; exit 1; }
BASE="$HOME/Library/Application Support/factorio-lp-arena${LP_TAG:+-$LP_TAG}"
shard() {   # shard <i> <n>: one game's share, into its own profile
  local i="$1" n="$2"
  local SIM="$BASE"; [ "$n" -gt 1 ] && SIM="$BASE-s$i"
  mkdir -p "$SIM/config" "$SIM/mods" "$SIM/saves"
  printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$SIM" > "$SIM/config/config.ini"
  ln -sfn "$REPO/landing-party" "$SIM/mods/landing-party"
  rm -rf "$SIM/mods/lp-arena"; cp -R "$REPO/tests/lp-arena" "$SIM/mods/lp-arena"
  local sh="nil"; [ "$n" -gt 1 ] && sh="{$i, $n}"
  printf 'return {mode = "batch", only = "%s", rounds = %s, shard = %s, tier = "%s", tier_exp = "%s"}\n' "${LP_ARENA_ONLY:-}" "${LP_ARENA_ROUNDS:-3}" "$sh" "${LP_ARENA_TIER:-}" "${LP_ARENA_TIER_EXP:-}" \
    > "$SIM/mods/lp-arena/params.lua"
  cat > "$SIM/mods/mod-list.json" <<JSON
{"mods": [{"name": "base", "enabled": true}, {"name": "landing-party", "enabled": true},
  {"name": "lp-arena", "enabled": true}, {"name": "space-age", "enabled": true},
  {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}]}
JSON
  local out="$SIM/script-output/lp-arena"
  rm -rf "$out" "$SIM/saves/arena.zip"
  "$FACTORIO" --config "$SIM/config/config.ini" --create "$SIM/saves/arena.zip" --map-gen-seed "${LP_ARENA_SEED:-1}" \
    --map-gen-settings "$REPO/scripts/map-gen.json" > "$SIM/arena.out" 2>&1 || { echo "shard $i: create failed"; return 1; }
  "$FACTORIO" --config "$SIM/config/config.ini" --benchmark "$SIM/saves/arena.zip" --benchmark-ticks "${LP_ARENA_TICKS:-36000}" \
    --benchmark-runs 1 >> "$SIM/arena.out" 2>&1 || { echo "shard $i: factorio exited non-zero"
    grep -hnE -A8 "Error" "$SIM/factorio-current.log" "$SIM/arena.out" | head -40; return 1; }
}
dirs=()
pids=()
for ((i = 0; i < JOBS; i++)); do
  SIM="$BASE"; [ "$JOBS" -gt 1 ] && SIM="$BASE-s$i"
  dirs+=("$SIM/script-output/lp-arena")
  shard "$i" "$JOBS" & pids+=($!)
done
fail=0
for p in "${pids[@]}"; do wait "$p" || fail=1; done
[ "$fail" -eq 0 ] || { echo "ARENA FAILED: a shard failed"; exit 1; }
merged="$BASE/results.jsonl"
mkdir -p "$BASE"   # (with shards, nothing else makes it: a new LP_TAG failed here, 2026-11-20)
: > "$merged"
for d in "${dirs[@]}"; do
  [ -f "$d/done.txt" ] || { echo "ARENA FAILED: not every fight was decided in $d ($(wc -l < "$d/results.jsonl" 2>/dev/null || echo 0) written)"; exit 1; }
  echo "$(cat "$d/done.txt")"
  cat "$d/results.jsonl" >> "$merged"
done
echo "$(wc -l < "$merged") results from $JOBS games"
[ -z "${LP_ARENA_ONLY:-}" ] || { cat "$merged"; exit 0; }
mkdir -p "$REPO/docs/arena"
cp "$merged" "$REPO/docs/arena/results.jsonl"
uv run --with matplotlib --with scipy python3 -I "$REPO/scripts/arena_report.py" "$REPO/docs/arena/results.jsonl" "$REPO/docs/arena.md"
