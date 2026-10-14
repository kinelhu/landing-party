#!/usr/bin/env bash
# The campaign instrument (docs/reviews/2026-10-14-next-slice-consult.md): the spread base and a reactive player
# (answers losses with lasers, strikes the nearest settlement every 45 minutes, era up every 90) for hours at
# real clocks, from contact's fork. A milestone run, not a regression. Timeline and events in
# docs/sim/contact-<seed>-vcampaign/; the player's moves are the "campaign" lines of results.txt.
#   scripts/campaign.sh [seed] [minutes]
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
SEED="${1:-12345}"; MINUTES="${2:-360}"
source "$DIR/env.sh"
[ -f "$FORKS/contact-$SEED-20-$FORK_HASH.zip" ] || "$DIR/fork.sh" contact "$SEED" 20 > /dev/null || exit 1
f="$DIR/../docs/sim/contact-$SEED-vcampaign"
# A crashed run leaves the last run's results behind: clear them, and show the error when it fails.
rm -f "$f/results.txt"
log="$(mktemp)"
# sim.sh also exits non-zero when a check fails: a run failed only when it crashed or wrote no results.
LP_FORK=1 LP_MIX=campaign LP_TAG=vcampaign "$DIR/sim.sh" contact "$SEED" "$MINUTES" 30 20 > "$log" 2>&1
if grep -q "Error while running" "$log" || [ ! -f "$f/results.txt" ]; then
  echo "RUN FAILED"; grep -A6 "Error while running" "$log" | head -12; exit 1
fi
[ -f "$f/results.txt" ] || { echo "RUN FAILED (no results)"; exit 1; }
grep -hE "campaign|PASS|FAIL" "$f/results.txt" | grep -vE "PASS (lander alive|mined|made parts|power)"
echo "== $(grep -cE "raid on|siege of|strip-mining beside" "$f/timeline.md") operations, $(grep -c "aborted" "$f/timeline.md") aborted"
