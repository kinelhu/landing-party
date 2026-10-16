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
  "cut||50|50|30" "raid||50|50|30" "occupy||48|48|30" "defend||41|41|30" "army||41|41|30" "train||36|36|30"
  "siege|LP_MIX=20,10,10|28|28|15"
  "orders||3|1|1" "control||4|1|1" "rivals||40|40|1" "phases||44|44|1" "phases|LP_MIX=left|16|16|1" "budget||60|60|1" "develop||3|1|1" "evolution||3|1|1" "nests||30|30|1" "hq||18|18|1" "temper||25|25|1" "line||12|12|1" "line|LP_MIX=back|12|12|1" "strip||25|25|1" "artillery||3|1|1" "circuit||5|1|1" "ops||12|12|1" "abort||12|12|1" "bombard||20|20|1" "caps||10|10|1" "dev||6|6|3" "grudge||6|6|1" "weigh||8|8|1" "siegetier|LP_MIX=2|30|30|1" "siegetier|LP_MIX=3|30|30|1" "siegetier|LP_MIX=sally|30|30|1" "siegetier|LP_MIX=convoy|30|30|1" "techup||7|7|1" "techup|LP_MIX=era0|7|7|1" "plate||16|16|1" "plate|LP_MIX=grubstake|16|16|1" "arms||5|5|1" "unitnode|LP_MIX=lance|16|16|1" "unitnode|LP_MIX=slug|16|16|1" "unitnode|LP_MIX=shock|16|16|1" "unitnode|LP_MIX=sapper|16|16|1" "unitnode|LP_MIX=aegis|16|16|1" "unitnode|LP_MIX=counter|16|16|1" "unitnode|LP_MIX=scavenger|16|16|1" "unitnode|LP_MIX=dozer|16|16|1" "arc||3|3|1" "ability|LP_MIX=loot|14|14|1" "ability|LP_MIX=hardened|14|14|1" "ability|LP_MIX=prospector|14|14|1" "sneak||12|12|1" "biters|LP_MIX=outpost|14|14|1" "biters|LP_MIX=camp|6|6|1" "maxevo||8|8|1" "maxevo|LP_MIX=bare|8|8|1" "country||8|8|1" "clearing||3|3|1" "pads||3|3|1" "ladder|LP_MIX=soft|12|12|1" "ladder|LP_MIX=desperate|12|12|1" "heist||20|20|1" "push||40|40|1" "guns||7|7|1" "async||5|5|1" "reinforce||16|16|1" "reinforce|LP_MIX=starved|16|16|1" "reinforce|LP_MIX=column|16|16|1" "pact||14|14|1" "pact|LP_MIX=nopact|14|14|1" "rail||3|3|1" "rail|LP_MIX=line|3|3|1" "clear||40|40|1" "clear|LP_MIX=worms|30|30|1" "quiet||30|30|1" "flak||3|3|1" "flare||8|8|1" "flare|LP_MIX=nopact|8|8|1" "flare|LP_MIX=natural|25|25|1" "jumper||8|8|1" "jumper|LP_MIX=rigkill|8|8|1" "loot||8|8|1"
)
FORKED=" cut raid occupy defend army train siege "
if [ "$FULL" = "--full" ]; then
  RUNS+=("grow||60|10|30" "assault||60|10|30" "faction||60|10|30" "uplink||60|10|30" "lively||60|10|30"
    "convoy||60|10|30" "convoy|LP_MIX=grown|45|45|1" "fall||15|5|10" "strip|LP_MIX=claim|40|40|1")
fi
# Every scenario listed must exist in the test mod (twice a scenario was cut by an edit to its neighbour, and the run
# failed only once the game reported "unknown scenario").
missing=""
for r in "${RUNS[@]}"; do
  sc="${r%%|*}"
  grep -q "^scenarios\.$sc = " "$DIR/../tests/lp-sim/control.lua" || missing="$missing $sc"
done
[ -z "$missing" ] || { echo "REGRESS FAILED: no such scenario in tests/lp-sim/control.lua:$missing"; exit 1; }
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
