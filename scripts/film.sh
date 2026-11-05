#!/usr/bin/env bash
# Stills (and clips' frames) for the trailer, in a game window: Landing Party's call of the film toolkit
# (~/Dev/factorio-film, FILM_HOME; its README has every param), with Landing Party linked, its plugin
# (tests/lp-film-hooks: sieges, waves, bursts, /lp tools, dome looks) and, given LP_FILM_SIM, its scenario harness.
#   scripts/film.sh <visit profile name> <save in its saves> <params.lua> [out dir]
# Frames go to [out dir] (default docs/sim/film-<name>).
set -euo pipefail
source "$(dirname "$0")/env.sh"
FILM_HOME="${FILM_HOME:-$HOME/Dev/factorio-film}"
[ -x "$FILM_HOME/scripts/film.sh" ] || { echo "FILM FAILED: no film toolkit at $FILM_HOME (FILM_HOME)"; exit 1; }
NAME="$1"; SAVE="$2"; PARAMS="$3"
V="$HOME/Library/Application Support/factorio-lp-visit/$NAME"
case "$V" in *"/factorio/"*) echo "refusing: $V is inside the real profile"; exit 1;; esac
[ -f "$V/saves/$SAVE" ] || { echo "no $V/saves/$SAVE"; exit 1; }
if pgrep -f -- "--config $V/config/config.ini" > /dev/null; then echo "refusing: a game is running on $V"; exit 1; fi
FN=$(grep -o 'return {name = "[^"]*"' "$PARAMS" | head -1 | cut -d'"' -f2)
OUT="${4:-$REPO/docs/sim/film-$FN}"
# (Read before the profile's mods are cleared: LP_FILM_SIM may be this very profile, whose params went with its lp-sim and
# the harness loaded on none, 2026-11-04.)
SIMPARAMS=""
if [ -n "${LP_FILM_SIM:-}" ]; then
  SIMPARAMS=$(sed 's/, save_at = [0-9]*//; s/-saveat[0-9]*//g' "$LP_FILM_SIM/mods/lp-sim/params.lua")
  grep -q "return {" <<< "$SIMPARAMS" || { echo "FILM FAILED: no harness params in $LP_FILM_SIM"; exit 1; }
fi
# (lp-film was the helper before the toolkit, 2026-11-05: a profile's old copy would load beside it.)
rm -rf "$V/mods/lp-sim" "$V/mods/lp-film"
# LP_FILM_SIM=<a fork's sim dir>: its scenario harness along (lp-sim with the fork's params), so a scenario saved before its
# own steps (a defence built, a siege forced) goes on playing in the window.
COPY=""
if [ -n "${LP_FILM_SIM:-}" ]; then
  H="$V/film-harness"; rm -rf "$H"; mkdir -p "$H"
  cp -R "$REPO/tests/lp-sim" "$H/lp-sim"; echo "$SIMPARAMS" > "$H/lp-sim/params.lua"
  COPY="lp-sim=$H/lp-sim"
fi
export APP FACTORIO
FILM_MODS="space-age quality elevated-rails" FILM_LINK="landing-party=$REPO/landing-party" \
  FILM_PLUGIN="lp-film-hooks=$REPO/tests/lp-film-hooks" FILM_COPY="$COPY" \
  exec "$FILM_HOME/scripts/film.sh" "$V" "$SAVE" "$PARAMS" "$OUT"
