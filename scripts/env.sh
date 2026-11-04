# Shared paths. Sourced by the other scripts.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# A worktree's runs get profiles of their own: profiles were named by scenario and seed only, and agents' regressions in
# three worktrees at once ran the same scenarios in one profile, each relinking its mod to its own code (2026-11-05).
case "$REPO" in */.claude/worktrees/*) WT="-wt-$(basename "$REPO")" ;; *) WT="" ;; esac
APP="$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents"
FACTORIO="$APP/MacOS/factorio"
# The dev profile is shared with ~/Dev/factorio-mods (Empirical Science): each repository links its own
# mod into it, so both can be played together. The real profile (…/factorio/) is never written to.
DEV="$HOME/Library/Application Support/factorio-dev"
CONFIG="$DEV/config/config.ini"
# Forks (scripts/fork.sh) save FORK_LEAD minutes before a scenario's strike (some measure the minutes before
# it, raid's income window), keyed by FORK_HASH: the mod's code that runs before a strike. Changing what only
# acts after it (operations, the player's army) keeps the forks; changing growth rebuilds them.
FORK_LEAD=6
FORK_HASH="$(cd "$REPO/landing-party" && find . -type f \( -name '*.lua' -o -name '*.json' -o -name '*.cfg' \) \
  ! -name ops.lua ! -name command.lua ! -name player.lua | sort | xargs cat | shasum | cut -c1-8)"
FORKS="$HOME/Library/Application Support/factorio-lp-sim/forks"
