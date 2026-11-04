#!/usr/bin/env bash
# A film's frames (scripts/film.sh, its stills named in order) to an mp4 at 30 a second.
#   scripts/clip.sh <frames dir> <out.mp4> [fps=30]
set -euo pipefail
ffmpeg -loglevel error -y -framerate "${3:-30}" -pattern_type glob -i "$1/*.png" -c:v libx264 -pix_fmt yuv420p -crf 23 \
  -movflags +faststart "$2"
echo "clip: $2 ($(ls "$1"/*.png | wc -l | tr -d ' ') frames)"
