#!/usr/bin/env bash
# Link Landing Party into the shared dev profile (created here if missing). Idempotent.
set -euo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$DEV/config" "$DEV/mods" "$DEV/saves"
[ -f "$CONFIG" ] || printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$DEV" > "$CONFIG"
ln -sfn "$REPO/landing-party" "$DEV/mods/landing-party"
echo "dev profile ready: $DEV"
