#!/usr/bin/env bash
# Quick regression: scenarios that strike run from forks (only the minutes around the strike; forks are made
# once per growth code, scripts/fork.sh), short ones run in full. About 2-3 minutes on one seed.
#   scripts/regress.sh [seed] [--full|--quick]      --full adds the long growth scenarios (grow, assault, faction,
#                                           uplink, lively, convoy, fall): confirmation at milestones.
#   --area=a,b and --changed leave out the nightly set (NIGHTLY: the slowest variants of families still run); LP_NIGHTLY=1
#   keeps it.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/env.sh"
"$DIR/lint_notices.sh" || exit 1
python3 -I "$DIR/lint_names.py" --register "$REPO/landing-party/locale/en/locale.cfg" || exit 1
SEED="${1:-12345}"; FULL="${2:-}"
# A seed is a number: "scripts/regress.sh --full" once ran every scenario on seed "--full", all failing at once.
case "$SEED" in ''|*[!0-9]*) echo "usage: scripts/regress.sh [seed] [--full|--quick]  (seed a number, got '$SEED')"; exit 2;; esac
# Ten at a time on a 14-core machine (four took the full list an hour and a half, 2026-10-23); LP_JOBS overrides.
JOBS="${LP_JOBS:-10}"
# Each run's profile is named by scenario, seed and tag (sim.sh): two regressions at once (agents in two worktrees) shared
# them and swapped each other's mod links; LP_REG_TAG gives one its own.
RTAG="${LP_REG_TAG:-reg}"
logs="$(mktemp -d)"; T0=$(date +%s)
# name | env | minutes | every | strike
RUNS=(
  "cut||50|50|30" "raid||50|50|30" "occupy||48|48|30" "defend||41|41|30" "army||41|41|30" "train||36|36|30" "train|LP_MIX=truce|36|36|30"
  "siege|LP_MIX=20,10,10|28|28|15"
  "orders||3|1|1" "control||4|1|1" "rivals||40|40|1" "phases||44|44|1" "phases|LP_MIX=left|16|16|1" "budget||60|60|1" "develop||3|1|1" "evolution||3|1|1" "arcflamer||1|1|1" "cards||1|1|1" "nests||30|30|1" "hq||18|18|1" "temper||25|25|1" "line||18|18|1" "line|LP_MIX=back|18|18|1" "line|LP_MIX=built|18|18|1" "line|LP_MIX=turret|18|18|1" "snatch||8|8|1" "snatch|LP_MIX=open|8|8|1" "strip||25|25|1" "artillery||3|1|1" "circuit||5|1|1" "ops||12|12|1" "abort||12|12|1" "bombard||20|20|1" "caps||10|10|1" "dev||6|6|3" "grudge||6|6|1" "weigh||8|8|1" "siegetier|LP_MIX=2|30|30|1" "siegetier|LP_MIX=3|30|30|1" "siegetier|LP_MIX=sally|30|30|1" "siegetier|LP_MIX=convoy|30|30|1" "techup||7|7|1" "techup|LP_MIX=era0|7|7|1" "plate||16|16|1" "plate|LP_MIX=grubstake|16|16|1" "arms||5|5|1" "unitnode|LP_MIX=lance|16|16|1" "unitnode|LP_MIX=slug|16|16|1" "unitnode|LP_MIX=shock|16|16|1" "unitnode|LP_MIX=sapper|16|16|1" "unitnode|LP_MIX=aegis|16|16|1" "unitnode|LP_MIX=counter|16|16|1" "unitnode|LP_MIX=scavenger|16|16|1" "unitnode|LP_MIX=dozer|16|16|1" "unitnode|LP_MIX=prism|16|16|1" "unitnode|LP_MIX=tesla|16|16|1" "unitnode|LP_MIX=scorcher|16|16|1" "unitnode|LP_MIX=skyguard|16|16|1" "unitnode|LP_MIX=flak-buggy|16|16|1" "arc||3|3|1" "ability|LP_MIX=loot|14|14|1" "ability|LP_MIX=hardened|14|14|1" "ability|LP_MIX=prospector|14|14|1" "sneak||12|12|1" "mended||18|18|1" "pool||26|26|1" "chart||4|4|1" "levers||16|16|1" "scanner||2|2|1" "roads||1|1|1" "muster||1|1|1" "scanresponse||3|3|1" "podland||1|1|1" "podland|LP_MIX=off|1|1|1" "landfx||3|3|1" "landfx|LP_MIX=off|3|3|1" "remembered||16|16|1" "gates||20|20|1" "gates|LP_MIX=shut|20|20|1" "fortress||30|30|1" "fortress|LP_MIX=old|30|30|1" "fortress|LP_MIX=jammer|30|30|1" "fortress|LP_MIX=howitzer|45|45|1" "fortress|LP_MIX=grubstake|30|30|1" "blackout||40|40|1" "blackout|LP_MIX=fed|40|40|1" "strangle||30|30|1" "strangle|LP_MIX=off|30|30|1" "strangle|LP_MIX=ore|30|30|1" "strangle|LP_MIX=oreoff|30|30|1" "strangle|LP_MIX=sever|5|5|1" "hazard||75|75|1" "hazard|LP_MIX=off|40|40|1" "hazard|LP_MIX=pay|60|60|1" "hazard|LP_MIX=unpaid|60|60|1" "hazard|LP_MIX=disputed|60|60|1" "hazard|LP_MIX=clean|60|60|1" "hazard|LP_MIX=worm|60|60|1" "hazard|LP_MIX=norails|60|60|1" "hazard|LP_MIX=research|60|60|1" "skim||45|45|1" "skim|LP_MIX=guarded|30|30|1" "skim|LP_MIX=raid|45|45|1" "skim|LP_MIX=night|45|45|1" "prowl||50|50|1" "prowl|LP_MIX=off|50|50|1" "artyprobe||5|5|1" "artyprobe|LP_MIX=mil|5|5|1" "arcguard||7|7|1" "arcguard|LP_MIX=grubstake|7|7|1" "director||40|40|1" "director|LP_MIX=off|20|20|1" "director|LP_MIX=hurt|20|20|1" "director|LP_MIX=cmd|3|3|1" "director|LP_MIX=repel|14|14|1" "director|LP_MIX=jammer|8|8|1" "director|LP_MIX=blackout|10|10|1" "director|LP_MIX=bounty|8|8|1" "director|LP_MIX=targets|8|8|1" "director|LP_MIX=sweep|20|20|1" "director|LP_MIX=sweepoff|20|20|1" "director|LP_MIX=salvage|8|8|1" "director|LP_MIX=research|4|4|1" "director|LP_MIX=wave|20|20|1" "director|LP_MIX=focus|12|12|1" "director|LP_MIX=drop|16|16|1" "director|LP_MIX=step4|8|8|1" "director|LP_MIX=supplykill|8|8|1" "director|LP_MIX=recall|30|30|1" "director|LP_MIX=recallback|30|30|1" "director|LP_MIX=recallfar|16|16|1" "director|LP_MIX=climax|60|60|1" "dome||8|8|1" "dome|LP_MIX=battery|8|8|1" "dome|LP_MIX=hull|8|8|1" "dome|LP_MIX=whole|8|8|1" "dome|LP_MIX=ring|8|8|1" "domehub||40|40|1" "standsiege||40|40|1" "standsiege|LP_MIX=nests|40|40|1" "launches||2|2|1" "dome|LP_MIX=dark|8|8|1" "dome|LP_MIX=off|8|8|1" "armed||8|8|1" "armed|LP_MIX=era2|8|8|1" "armed|LP_MIX=relay|8|8|1" "armed|LP_MIX=starved|20|20|1" "orbital||25|25|1" "orbital|LP_MIX=spotter|25|25|1" "orbital|LP_MIX=standing|30|30|1" "dismantle||14|14|1" "dismantle|LP_MIX=ambush|14|14|1" "leader||14|14|1" "leader|LP_MIX=serenity|14|14|1" "leader|LP_MIX=haul|14|14|1" "leader|LP_MIX=rails|14|14|1" "factory|LP_MIX=engage|30|30|1" "mended|LP_MIX=provoked|18|18|1" "mended|LP_MIX=serenity|18|18|1" "mended|LP_MIX=dozers|18|18|1" "airraid||20|20|1" "airraid|LP_MIX=aa|20|20|1" "airraid|LP_MIX=detour|20|20|1" "airraid|LP_MIX=cmd|12|12|1" "airraid|LP_MIX=grubstake|35|35|1" "retire||3|3|1" "squad||3|3|1" "tutorial||1|1|1" "veteran||3|3|1" "veteran|LP_MIX=camp|25|25|1" "cannon||14|14|1" "turretmodel||1|1|1" "rankreads||1|1|1" "biters|LP_MIX=outpost|14|14|1" "biters|LP_MIX=camp|6|6|1" "maxevo||8|8|1" "maxevo|LP_MIX=bare|8|8|1" "country||8|8|1" "clearing||3|3|1" "pads||3|3|1" "idle||4|4|1" "idle|LP_MIX=pillbox|4|4|1" "idle|LP_MIX=truce|8|8|1" "ladder|LP_MIX=soft|12|12|1" "ladder|LP_MIX=desperate|12|12|1" "heist||20|20|1" "push||40|40|1" "guns||7|7|1" "guns|LP_MIX=fewest|7|7|1" "guns|LP_MIX=fewestpod|7|7|1" "async||5|5|1" "reinforce||16|16|1" "reinforce|LP_MIX=starved|16|16|1" "reinforce|LP_MIX=column|16|16|1" "pact||14|14|1" "pact|LP_MIX=nopact|14|14|1" "rail||3|3|1" "rail|LP_MIX=line|3|3|1" "clear||60|60|1" "clear|LP_MIX=worms|45|45|1" "clear|LP_MIX=culture|75|75|1" "quiet||30|30|1" "quiet|LP_MIX=streak|70|70|1" "pdome||4|4|1" "pdome|LP_MIX=break|4|4|1" "studies||1|1|1" "flak||3|3|1" "jumper||10|10|1" "jumper|LP_MIX=rigkill|10|10|1" "loot||8|8|1" "tap||14|14|1" "tap|LP_MIX=natural|40|40|1" "fuze||3|3|1" "fuze|LP_MIX=plain|3|3|1" "jumper|LP_MIX=cmd|10|10|1" "tap|LP_MIX=cmd|14|14|1" "bait||10|10|1" "rifle||3|3|1" "crew||8|8|1" "crew|LP_MIX=killed|10|10|1" "crew|LP_MIX=grown|25|25|1" "crew|LP_MIX=drone|8|8|1" "crew|LP_MIX=rebuild|10|10|1" "crew|LP_MIX=doomed|10|10|1" "crew|LP_MIX=island|14|14|1" "crew|LP_MIX=walled|10|10|1" "crew|LP_MIX=around|10|10|1" "crew|LP_MIX=dronekill|8|8|1" "crew|LP_MIX=answered|10|10|1" "cordon||20|20|1" "cordon|LP_MIX=breach|20|20|1" "cordon|LP_MIX=contact|20|20|1" "cordon|LP_MIX=rail|20|20|1" "cordon|LP_MIX=ore|20|20|1" "cordon|LP_MIX=held|20|20|1" "cordon|LP_MIX=broken|50|50|1" "cordon|LP_MIX=ring|20|20|1" "prospect||25|25|1" "prospect|LP_MIX=stake|25|25|1" "prospect|LP_MIX=pulled|25|25|1" "prospect|LP_MIX=truck|25|25|1" "standing||20|20|1" "road||25|25|1" "road|LP_MIX=cut|25|25|1" "bend||20|20|1" "strike||10|10|1" "crystal||10|10|1" "crystal|LP_MIX=marker|14|14|1" "labs||30|30|1" "breach|LP_MIX=arty|30|30|1" "parked||5|5|1" "reprisal||20|20|1" "belts||30|30|1" "heavies||5|5|1" "herd||30|30|1" "herd|LP_MIX=keep|30|30|1" "herd|LP_MIX=second|30|30|1" "herd|LP_MIX=scout|30|30|1" "herd|LP_MIX=belt|30|30|1" "herd|LP_MIX=wild|30|30|1" "herd|LP_MIX=blind|30|30|1" "herd|LP_MIX=mega|30|30|1" "herd|LP_MIX=megaburst|30|30|1" "herd|LP_MIX=spit|30|30|1" "herd|LP_MIX=probe|30|30|1" "herd|LP_MIX=stomp|30|30|1" "herd|LP_MIX=burst|30|30|1" "herd|LP_MIX=deep|30|30|1" "herd|LP_MIX=deepdrop|30|30|1" "herd|LP_MIX=core|30|30|1" "herd|LP_MIX=fire|30|30|1" "herd|LP_MIX=flamer|30|30|1" "herd|LP_MIX=stray|30|30|1" "herd|LP_MIX=wallgoal|30|30|1" "herd|LP_MIX=ranks|30|30|1" "herd|LP_MIX=ranks-mend|30|30|1" "cinder||3|3|1" "cinder|LP_MIX=spores|3|3|1" "cinder|LP_MIX=windup|3|3|1" "farm||50|50|1" "farm|LP_MIX=strike|12|12|1" "farm|LP_MIX=raid|50|50|1" "farm|LP_MIX=killed|40|40|1" "farm|LP_MIX=wave|40|40|1" "farm|LP_MIX=wave200|40|40|1" "farm|LP_MIX=starve|40|40|1" "farm|LP_MIX=quiet|50|50|1" "farm|LP_MIX=techs|40|40|1" "farm|LP_MIX=clinic|45|45|1" "farm|LP_MIX=evocap|20|20|1" "farm|LP_MIX=seed|40|40|1" "farm|LP_MIX=seedcap|40|40|1" "farm|LP_MIX=siege|90|90|1" "farm|LP_MIX=siegepoor|60|60|1" "farm|LP_MIX=siegestall|75|75|1" "farm|LP_MIX=bigpens|90|90|1" "farm|LP_MIX=behind|75|75|1" "farm|LP_MIX=seedkill|40|40|1" "farm|LP_MIX=fed|40|40|1" "farm|LP_MIX=found|60|60|1" "farm|LP_MIX=seedbare|40|40|1" "farm|LP_MIX=moat|60|60|1" "farm|LP_MIX=artillery|60|60|1" "town||8|8|1" "town|LP_MIX=lake|8|8|1" "creep||10|10|1" "creep|LP_MIX=spread|30|30|1" "creep|LP_MIX=killed|12|12|1" "creep|LP_MIX=clean|20|20|1" "creep|LP_MIX=smog|20|20|1" "creep|LP_MIX=strong|20|20|1" "creep|LP_MIX=break|10|10|1" "creep|LP_MIX=uproot|8|8|1" "creep|LP_MIX=uprootp|8|8|1" "creep|LP_MIX=berth|20|20|1" "creep|LP_MIX=edge|14|14|1" "system||40|40|1" "compose||3|3|1" "feeds||3|3|1" "perceive||3|3|1" "perceive|LP_MIX=twofeed|3|3|1" "perceive|LP_MIX=sprawl|3|3|1" "wayout|LP_MIX=gap|3|3|1" "wayout|LP_MIX=gate|3|3|1" "wayout|LP_MIX=shut|3|3|1" "wayout|LP_MIX=lane3|3|3|1" "blockexit||4|4|1" "watchdog|LP_MIX=economy|20|20|1" "watchdog|LP_MIX=army|20|20|1" "system|LP_MIX=solo LP_SEED=777|60|60|1" "fortress|LP_MIX=closed|30|30|1" "herd|LP_MIX=ranks-crowd|30|30|1" "teslawall|LP_MIX=grid|4|4|1" "stun||4|4|1" "suppress||4|4|1" "shotdown||2|2|1" "hulls||2|2|1" "artyreply||2|2|1" "counterbattery||14|14|1" "phases|LP_MIX=nogrubstake|44|44|1" "phases|LP_MIX=noserenity|44|44|1" "phases|LP_MIX=grubprod|44|44|1" "phases|LP_MIX=interval|44|44|1" "phases|LP_MIX=camps|44|44|1" "farm|LP_MIX=off|5|5|1" "farm|LP_MIX=late|5|5|1" "farm|LP_MIX=smallwaves|5|5|1" "farm|LP_MIX=unlearned|50|50|1" "grudge|LP_MIX=norevenge|6|6|1" "orbital|LP_MIX=nostrike|25|25|1" "skim|LP_MIX=notheft|30|30|1" "strip|LP_MIX=notheft|25|25|1" "owngates|LP_MIX=gate|3|3|1" "owngates|LP_MIX=gap|3|3|1" "owngates|LP_MIX=shut|3|3|1"
)
# hazard runs 75 minutes (0.2.20): with the railgunner a nest clearer, weaker against biters on their feet, its camp
# bleeds more to the scripted waves and starts clearing later; it cleared every nest by 75 on seeds 12345 and 1.
# clear culture runs 50 minutes (0.2.17): with bursters from evolution 0.45 the incubators' bursters can burst on the
# first mortar (seed 12345), and the clearance razes its target at minute 41 instead of before 40; seeds 1, 777, 4242 at 40.
FORKED=" cut raid occupy defend army train siege "
# --quick: one or two a layer of the AI graph (docs/ai-graph.md) and the day's mechanics, for iterating (a few minutes);
# the whole list before committing a batch, --full before one that touches growth, landings or the fall.
# (clearing, evolution, arcflamer, cards: 2026-11-12, after clearing failed unseen for six versions outside it; each 1 to 3 minutes.)
QUICK=" ops| mended| mended|LP_MIX=serenity sneak| crew|LP_MIX=answered snatch| line|LP_MIX=turret remembered|
  gates| blockexit| fortress| fortress|LP_MIX=howitzer leader|LP_MIX=haul blackout| strangle| strangle|LP_MIX=ore pool| levers| scanner| scanresponse| roads| muster| podland| jumper| tap| prospect|LP_MIX=truck strip| cordon|
  standing| temper| nests| country| bombard| siegetier|LP_MIX=2 arms| dev| chart| heist| herd| herd|LP_MIX=scout farm| creep|
  clearing| evolution| arcflamer| cards| turretmodel| rankreads| "
if [ "$FULL" = "--quick" ]; then
  QUICK=" $(echo $QUICK) "
  kept=()
  for r in "${RUNS[@]}"; do
    IFS='|' read -r sc envs _ <<< "$r"
    case "$QUICK" in *" $sc|$envs "*) kept+=("$r");; esac
  done
  RUNS=("${kept[@]}")
  echo "quick: ${#RUNS[@]} scenarios"
fi
if [ "$FULL" = "--full" ]; then
  RUNS+=("grow||60|10|30" "assault||60|10|30" "faction||60|10|30" "uplink||60|10|30" "lively||60|10|30"
    "convoy||60|10|30" "convoy|LP_MIX=grown|45|45|1" "fall||15|5|10" "strip|LP_MIX=claim|40|40|1")
fi
# Areas (the user, 2026-10-29: the whole list had grown to 40 minutes): every scenario belongs to one, and
# --area a,b (or --changed) runs the quick set plus those areas' scenarios, every variant. --changed reads the areas
# from what differs from HEAD (LP_SINCE=<ref> to read from a ref instead): a module of one area runs that area, a
# shared one (threat, know, tune, control.lua, shared.lua, the data stage...) runs everything. The test harness and the
# docs choose nothing: changed alone, a scenario's own checks need --area or LP_ONLY. The whole list stays the
# milestone's, and --full the growth change's.
area_of_scenario() {
  case "$1" in
    herd|farm|creep|clear|cinder|town|quiet|biters|maxevo|stun|shotdown) echo biotech;;
    cut|raid|occupy|defend|army|train|siege|orders|control|retire|squad|cards|tutorial|veteran|cannon|rifle|bait|flak|pdome|studies|owngates|suppress|hulls) echo player;;
    compose|feeds|perceive|wayout|blockexit) echo perception;;
    grow|assault|faction|uplink|lively|convoy|fall|phases|budget|develop|evolution|nests|hq|temper|line|snatch|strip|\
      artillery|circuit|caps|techup|plate|arms|unitnode|arc|ability|podland|landfx|roads|muster|pads|idle|clearing|country|system|\
      watchdog|async) echo growth;;
    # A film instrument (the trailer's staged beats): not in the run lists above; run it by hand (sim.sh trailer).
    trailer) echo ops;;
    *) echo ops;;
  esac
}
# A module's areas ("all": everything).
areas_of_file() {
  case "$1" in
    landing-party/info.json|docs/*|*.md|scripts/*.py|tests/*) ;;
    scripts/*) echo quick;;
    landing-party/biotech.lua|landing-party/counters.lua|landing-party/burstlook.lua) echo biotech;;
    landing-party/player.lua) echo player;;
    landing-party/scripts/*.lua)
      m="${1##*/}"; m="${m%.lua}"
      case "$m" in
        herd|farm|creep|cell|pods|costmap|valuemap|biters|scorcher|stun|fall|burstfx) echo biotech;;
        separate) echo all;;
        command|cards|aim|bait|marker|studies) echo player;;
        layout|site|planner|blocks|wfc|wfc_serenity|construction|modules|names|phases|roads|lots_grubstake|map|chart) echo growth;;
        airraid|answers|assault|cuts|jammer|perimeter|pool|siege|stance|strip|strategy|war|crew|cordon|prospect|skim|prowl|dome|orbital|tap|jumper|ledger|\
          road|standing|pact|belts|strike|oplog|scanner|lights|director|director_gui) echo ops;;
        base|faction|army|rd|ops) echo growth ops;;
        veterancy) echo player ops;;
        landfx) echo growth;;
        *) echo all;;
      esac;;
    *) echo all;;
  esac
}
AREAS=""
case "$FULL" in
  --area=*) AREAS=" $(echo "${FULL#--area=}" | tr ',' ' ') ";;
  --changed)
    for f in $(git -C "$DIR/.." diff --name-only "${LP_SINCE:-HEAD}"; git -C "$DIR/.." ls-files --others --exclude-standard); do
      AREAS="$AREAS $(areas_of_file "$f")"
    done
    AREAS=" $(echo $AREAS | tr ' ' '\n' | sort -u | tr '\n' ' ') "
    echo "changed: areas$AREAS";;
esac
# The nightly set (the user, 2026-10-31: "keep regressions to a minimum we are losing a lot of time"): the slowest variants
# of families another variant of which still runs (hazard 60 to 75 game minutes each, the long farm runs, clear culture,
# system solo), left out of --area and --changed runs; the whole list and LP_NIGHTLY=1 keep them.
NIGHTLY=" hazard|LP_MIX=pay hazard|LP_MIX=unpaid hazard|LP_MIX=disputed hazard|LP_MIX=clean hazard|LP_MIX=worm
  hazard|LP_MIX=norails hazard|LP_MIX=research farm|LP_MIX=found farm|LP_MIX=moat farm|LP_MIX=artillery
  farm|LP_MIX=seedbare farm|LP_MIX=behind clear|LP_MIX=culture system|LP_MIX=solo~LP_SEED=777 "
if [ -n "$AREAS" ] && [ "${AREAS#* all }" = "$AREAS" ]; then
  QUICK=" $(echo $QUICK) "
  NIGHTLY=" $(echo $NIGHTLY) "
  kept=()
  for r in "${RUNS[@]}"; do
    IFS='|' read -r sc envs _ <<< "$r"
    case "$QUICK" in *" $sc|$envs "*) kept+=("$r"); continue;; esac
    [ -z "${LP_NIGHTLY:-}" ] && case "$NIGHTLY" in *" $sc|${envs// /~} "*) continue;; esac
    case "$AREAS" in *" $(area_of_scenario "$sc") "*) kept+=("$r");; esac
  done
  RUNS=("${kept[@]}")
  echo "areas$AREAS: ${#RUNS[@]} scenarios"
fi
# LP_ONLY="name|env name|env ...": just those (a regression's failures run again), as the list has them.
if [ -n "${LP_ONLY:-}" ]; then
  kept=()
  for r in "${RUNS[@]}"; do
    IFS='|' read -r sc envs _ <<< "$r"
    case " $LP_ONLY " in *" $sc|$envs "*) kept+=("$r");; esac
  done
  RUNS=("${kept[@]}")
  echo "only: ${#RUNS[@]} scenarios"
fi
# LP_DRY=1: the runs it would make, and their minutes, without making them.
if [ -n "${LP_DRY:-}" ]; then
  printf "%s\n" "${RUNS[@]}"; printf "%s\n" "${RUNS[@]}" | awk -F'|' '{m+=$3} END {print NR " runs, " m " game minutes"}'; exit 0
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
  tag=$RTAG; [ -n "$envs" ] && tag="$RTAG-$(echo "$envs" | tr -c 'a-zA-Z0-9' '-')"
  name="$sc${envs:+-$tag}"
  # An entry may carry its own seed (LP_SEED=n in its env): a fault only some maps show (Synthexis's march, seed 777).
  seed="$SEED"; case " $envs " in *" LP_SEED="*) seed="${envs##*LP_SEED=}"; seed="${seed%% *}";; esac
  ( t0=$(date +%s); env $envs LP_FORK=$fork LP_TAG=$tag "$DIR/sim.sh" "$sc" "$seed" "$minutes" "$every" "$strike" > "$logs/$name.log" 2>&1
    echo $(( $(date +%s) - t0 )) > "$logs/$name.secs" ) &
  names+=("$name")
done
wait
fail=0
for n in "${names[@]}"; do
  line=$(grep -hE "DONE|SIM FAILED" "$logs/$n.log" | tail -1)
  case "$line" in *"ALL PASSED"*) printf "  pass  %s\n" "$n";; *) printf "  FAIL  %s  %s\n" "$n" "$line"; grep -hE "FAIL " "$logs/$n.log" | sed "s/^/        /"; [ -n "$line" ] || tail -5 "$logs/$n.log" | sed "s/^/        /"; fail=1;; esac
done
# What it cost: the whole list grew to 40 minutes ten scenarios a day before anyone measured it (2026-10-29).
for n in "${names[@]}"; do echo "$(cat "$logs/$n.secs" 2>/dev/null || echo 0) $n"; done | sort -rn > "$logs/secs"
echo "  $(wc -l < "$logs/secs" | tr -d ' ') runs, $(( $(date +%s) - T0 )) s; slowest: $(head -5 "$logs/secs" | awk '{printf "%s %ss, ", $2, $1}')"
exit $fail
