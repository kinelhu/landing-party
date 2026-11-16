#!/usr/bin/env bash
# The night shift's visits (2026-11-16): the director at 0.2.429 on the user's other saves, steady against off, and the
# calibration's sweep on the reference factories (difficulty easy/normal/hard by director gentle/steady/chaotic). Each a
# scripts/visit.sh of its own profile (copies only), LP_JOBS at once (default 8). Writes docs/sim/visit-*-v429 dirs.
#   scripts/night_visits.sh visits|calibration [minutes]
set -u
cd "$(dirname "$0")/.."
JOBS="${LP_JOBS:-8}"; WHAT="${1:-visits}"; MIN="${2:-180}"
S="$HOME/Library/Application Support/factorio/saves"; R="$HOME/Library/Application Support/factorio-lp-ref"
runs=()
if [ "$WHAT" = visits ]; then
  for save in nwa deathworld10x; do for k in 1 2 3; do for d in steady off; do
    runs+=("$S/$save.zip|record-seed$k|$d")
  done; done; done
  for k in 2 3 4 5; do runs+=("$S/railbase_end.zip|record-seed$k|steady"); done
else
  for ref in belt laser artillery; do for diff in easy normal hard; do for d in gentle steady chaotic; do
    runs+=("$R/$ref.zip|record-seed1-diff_$diff|$d")
  done; done; done
fi
mkdir -p "$HOME/lp-night"
for r in "${runs[@]}"; do
  IFS='|' read -r save mix dir <<< "$r"
  while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do sleep 5; done
  log="$HOME/lp-night/$(basename "$save" .zip)-$mix-$dir.log"
  ( env LP_MIX="$mix" LP_OFF=biotech LP_DIRECTOR="$dir" LP_TUNETAG=v429 scripts/visit.sh "$save" "$MIN" > "$log" 2>&1
    echo "done $(basename "$save" .zip) $mix $dir: $(grep -h 'METRIC razed_worth' "$log" | head -1)" >> "$HOME/lp-night/$WHAT.done" ) &
done
wait
echo "ALL DONE $WHAT" >> "$HOME/lp-night/$WHAT.done"
