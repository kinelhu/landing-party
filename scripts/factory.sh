#!/usr/bin/env bash
# The factory instrument across seeds (tests/lp-sim scenario `factory`): each mix on each seed, in parallel, then each
# mix's income (mean and spread) and losses. Single runs of one seed varied by 15% or more (a turtle on seed 777 made
# 62k to 80k across runs), so decisions rest on means.
#   scripts/factory.sh [minutes] [mixes] [seeds]     e.g. scripts/factory.sh 120 "control turtle engage" "12345 777 4242 1"
set -euo pipefail
source "$(dirname "$0")/env.sh"
MIN="${1:-120}"; MIXES="${2:-control turtle engage}"; SEEDS="${3:-12345 777 4242 1}"
TAG="fx$(date +%H%M)"
for m in $MIXES; do for s in $SEEDS; do
  LP_MIX=$m LP_TAG=$TAG$m "$REPO/scripts/sim.sh" factory "$s" "$MIN" "$MIN" 1 > /dev/null 2>&1 &
done; done
wait
python3 -I - "$TAG" "$MIXES" "$SEEDS" <<'PY'
import os, re, sys, statistics
tag, mixes, seeds = sys.argv[1], sys.argv[2].split(), sys.argv[3].split()
base = os.path.expanduser("~/Library/Application Support/factorio-lp-sim")
print(f"{'mix':8} {'income mean':>12} {'sd':>8} {'lost':>6}  per seed")
for m in mixes:
    inc, lost, per = [], [], []
    for s in seeds:
        p = f"{base}/factory-{s}-{tag}{m}/script-output/landing-party/results.txt"
        try: t = open(p).read()
        except OSError: per.append(f"{s}:missing"); continue
        r = re.search(r"INFO factory end: income (\d+) ore; lost (\d+)", t)
        if not r: per.append(f"{s}:no end"); continue
        inc.append(int(r.group(1))); lost.append(int(r.group(2))); per.append(f"{s}:{r.group(1)}")
    if inc:
        sd = statistics.stdev(inc) if len(inc) > 1 else 0
        print(f"{m:8} {statistics.mean(inc):12.0f} {sd:8.0f} {statistics.mean(lost):6.0f}  " + " ".join(per))
PY
