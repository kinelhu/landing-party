#!/usr/bin/env bash
# Quick regression: scenarios that strike run from forks (only the minutes around the strike; forks are made
# once per growth code, scripts/fork.sh), short ones run in full. About 2-3 minutes on one seed.
#   scripts/regress.sh [seed] [--full]      --full adds the long growth scenarios (grow, assault, faction,
#                                           uplink, lively, convoy, fall): confirmation at milestones.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/env.sh"
SEED="${1:-12345}"; FULL="${2:-}"
JOBS="${LP_JOBS:-4}"
logs="$(mktemp -d)"
# name | env | minutes | every | strike
RUNS=(
  "cut||50|50|30" "raid||50|50|30" "occupy||48|48|30" "defend||37|37|30" "army||41|41|30" "train||36|36|30"
  "siege|LP_MIX=20,10,10|28|28|15"
  "orders||3|1|1" "control||4|1|1" "rivals||40|40|1" "phases||36|36|1" "phases|LP_MIX=left|16|16|1" "budget||60|60|1" "develop||3|1|1" "evolution||3|1|1" "nests||30|30|1" "hq||18|18|1" "circuit||5|1|1" "ops||12|12|1" "abort||12|12|1" "bombard||20|20|1" "caps||10|10|1"
)
FORKED=" cut raid occupy defend army train siege "
if [ "$FULL" = "--full" ]; then
  RUNS+=("grow||60|10|30" "assault||60|10|30" "faction||60|10|30" "uplink||60|10|30" "lively||60|10|30"
    "convoy||60|10|30" "fall||15|5|10")
fi
names=()
for r in "${RUNS[@]}"; do
  IFS='|' read -r sc envs minutes every strike <<< "$r"
  while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do sleep 1; done
  fork=""; case "$FORKED" in *" $sc "*) fork=1;; esac
  # Two runs of one scenario (variants) need their own tag and log.
  tag=reg; [ -n "$envs" ] && tag="reg-$(echo "$envs" | tr -c 'a-zA-Z0-9' '-')"
  name="$sc${envs:+-$tag}"
  ( env $envs LP_FORK=$fork LP_TAG=$tag "$DIR/sim.sh" "$sc" "$SEED" "$minutes" "$every" "$strike" > "$logs/$name.log" 2>&1 ) &
  names+=("$name")
done
wait
fail=0
for n in "${names[@]}"; do
  line=$(grep -hE "DONE|SIM FAILED" "$logs/$n.log" | tail -1)
  case "$line" in *"ALL PASSED"*) printf "  pass  %s\n" "$n";; *) printf "  FAIL  %s  %s\n" "$n" "$line"; grep -hE "FAIL " "$logs/$n.log" | sed "s/^/        /"; [ -n "$line" ] || tail -5 "$logs/$n.log" | sed "s/^/        /"; fail=1;; esac
done
exit $fail
