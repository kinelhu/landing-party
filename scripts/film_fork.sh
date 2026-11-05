#!/usr/bin/env bash
# A scenario's fork (scripts/fork.sh) as a film profile, for scripts/film.sh: the trailer's action comes from scenarios
# set up for it, an event at a known tick on a known wall, not from visits, whose replays drift (2026-11-04).
#   scripts/film_fork.sh <scenario> <seed> <strike> [mix]     (forks first if the fork is missing)
# Then: LP_FILM_SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-<scenario>[-mix]-<seed>-<strike>" \
#   scripts/film.sh <scenario>[-mix]-film fork.zip <params.lua>
# Its course headless is its rehearsal (FILM_REHEARSE=<ticks> before the same film.sh line), not a sim.sh run of the
# fork: the window's new player takes an entity number the headless run never does (DESIGN.md, "Films follow their
# rehearsal"). A sim.sh run of a variant's fork: LP_FORK=1 LP_FORK_MIX=<mix> LP_MIX=<mix>.
set -euo pipefail
source "$(dirname "$0")/env.sh"
SCENARIO="$1"; SEED="$2"; STRIKE="$3"; MIX="${4:-}"
TAG="$SCENARIO${MIX:+-$MIX}"
SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-$TAG-$SEED-$STRIKE$WT"
if [ ! -f "$SIM/saves/fork.zip" ]; then
  LP_FORK_MIX="$MIX" "$REPO/scripts/fork.sh" "$SCENARIO" "$SEED" "$STRIKE"
fi
[ -f "$SIM/saves/fork.zip" ] || { echo "film_fork: no fork at $SIM"; exit 1; }
V="$HOME/Library/Application Support/factorio-lp-visit/$TAG-film"
mkdir -p "$V/config" "$V/mods" "$V/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$V" > "$V/config/config.ini"
[ -f "$SIM/mods/mod-settings.dat" ] && cp "$SIM/mods/mod-settings.dat" "$V/mods/"
cp "$SIM/saves/fork.zip" "$V/saves/fork.zip"
echo "film profile: $V (fork of $TAG $SEED at $STRIKE); LP_FILM_SIM=\"$SIM\" scripts/film.sh $TAG-film fork.zip <params>"
