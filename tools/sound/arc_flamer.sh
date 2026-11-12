#!/usr/bin/env bash
# The arc flamer's bolt (the user's pick of six on the rating page, 2026-11-12: D, "Crack and ignition"): the tesla
# turret's beam a quarter slower, cut to its bolt, with the flamethrower turret's ignition under it, normalised.
#   tools/sound/arc_flamer.sh   -> landing-party/sound/arc-flamer.ogg (the game's own sounds, read from its install)
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/env.sh
SA="$APP/data/space-age/sound"; BA="$APP/data/base/sound"
T=$(mktemp -d)
sox "$SA/entity/tesla-turret/tesla-turret-beam.ogg" -r 44100 -c 1 "$T/bolt.wav" speed 0.75 trim 0 0.36 fade 0.01 0.36 0.12
sox "$BA/fight/flamethrower-turret-activate-1.ogg" -r 44100 -c 1 "$T/ign.wav" vol 0.8 pad 0.03
sox -m "$T/bolt.wav" "$T/ign.wav" "$T/mix.wav"
sox "$T/mix.wav" "$T/out.wav" norm -3
sox "$T/out.wav" -C 5 landing-party/sound/arc-flamer.ogg   # (sox: this ffmpeg has no Vorbis encoder)
echo "landing-party/sound/arc-flamer.ogg $(soxi -D "$T/out.wav") s"
