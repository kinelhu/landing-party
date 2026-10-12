# Shared paths. Sourced by the other scripts.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents"
FACTORIO="$APP/MacOS/factorio"
# The dev profile is shared with ~/Dev/factorio-mods (Empirical Science): each repository links its own
# mod into it, so both can be played together. The real profile (…/factorio/) is never written to.
DEV="$HOME/Library/Application Support/factorio-dev"
CONFIG="$DEV/config/config.ini"
