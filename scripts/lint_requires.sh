#!/usr/bin/env bash
# Every require in the mod at its file's top level, `local x = require(...)` at column 0 (or the data stage's own
# top-level requires): Factorio allows require only while a file loads, and one inside a function crashed the game when
# it ran (dev.lua's /lp director, "Require can't be used outside of control.lua parsing", the playtest, 2026-11-23).
set -euo pipefail
cd "$(dirname "$0")/../landing-party"
# (The control stage alone, control.lua and scripts/: the data stage may require anywhere. A require on an indented line
# is inside a block; one at column 0, a top-level table's included, runs as the file loads.)
bad=$(grep -n "require(" control.lua scripts/*.lua | grep -E '^[^:]+:[0-9]+:[[:space:]]+[^-[:space:]]' || true)
if [ -n "$bad" ]; then echo "requires lint: a require below a file's top level (it errors when run):"; echo "$bad"; exit 1; fi
echo "requires lint ok"
