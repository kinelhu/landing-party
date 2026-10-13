#!/usr/bin/env bash
# First-contact timelines for the three player variants (passive, robots, walled), two hours each, all from one
# shared fork of the faction's first 14 minutes (the player's base goes down at minute 20). Prints the summary
# rows; plots and event lists are in docs/sim/contact-<seed>-v<variant>/timeline.{png,md}.
#   scripts/contact.sh [seed] [minutes]
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
SEED="${1:-12345}"; MINUTES="${2:-120}"
source "$DIR/env.sh"
# The fork first, once: three runs finding it missing built it at the same time and two failed silently.
[ -f "$FORKS/contact-$SEED-20-$FORK_HASH.zip" ] || "$DIR/fork.sh" contact "$SEED" 20 > /dev/null || exit 1
pids=()
for m in passive robots walled; do
  rm -f "$DIR/../docs/sim/contact-$SEED-v$m/results.txt"
  mix=$m; [ "$m" = passive ] && mix=""
  ( LP_FORK=1 LP_MIX=$mix LP_TAG=v$m "$DIR/sim.sh" contact "$SEED" "$MINUTES" 30 20 > /dev/null 2>&1 ) &
  pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; done
for m in passive robots walled; do
  f="$DIR/../docs/sim/contact-$SEED-v$m"
  [ -f "$f/results.txt" ] || { echo "== $m: RUN FAILED (no results)"; continue; }
  echo "== $m: $(grep -cE "raid on|siege of" "$f/timeline.md") operations, $(grep -c "aborted" "$f/timeline.md") aborted"
  grep -E "player at the end" "$f/results.txt" | sed "s/INFO contact: //"
done
