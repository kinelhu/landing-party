#!/usr/bin/env bash
# Launch the game on the dev profile (real saves and mods untouched). In game: /lp-land [distance].
set -euo pipefail
source "$(dirname "$0")/env.sh"
exec "$FACTORIO" --config "$CONFIG" "$@"
