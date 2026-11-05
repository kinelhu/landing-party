#!/usr/bin/env bash
# A film's frames (scripts/film.sh, its stills named in order) to an mp4 at 30 a second: the film toolkit's
# (~/Dev/factorio-film, FILM_HOME).
#   scripts/clip.sh <frames dir> <out.mp4> [fps=30]
set -euo pipefail
exec "${FILM_HOME:-$HOME/Dev/factorio-film}/scripts/clip.sh" "$@"
