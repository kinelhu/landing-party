#!/usr/bin/env bash
# Load check in its own profile, with Space Age and Quality: the data stage loads (prototypes dumped to
# script-output/data-raw-dump.json) and a fresh map runs on_init. The sims run the base game only, so
# this is the run that sees the mod beside Space Age.
set -euo pipefail
source "$(dirname "$0")/env.sh"
"$(dirname "$0")/lint_notices.sh"
"$(dirname "$0")/lint_globals.sh"
# The AI's generated graph (docs/ai-graph.md) must match the code: regenerate with scripts/ai_graph.py.
python3 -I "$(dirname "$0")/ai_graph.py" --check
P="$HOME/Library/Application Support/factorio-lp-check"
mkdir -p "$P/config" "$P/mods" "$P/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$P" > "$P/config/config.ini"
ln -sfn "$REPO/landing-party" "$P/mods/landing-party"
cat > "$P/mods/mod-list.json" <<JSON
{"mods": [{"name": "base", "enabled": true}, {"name": "landing-party", "enabled": true},
  {"name": "space-age", "enabled": true}, {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}]}
JSON
log="$P/factorio-current.log"
fail() { echo "CHECK FAILED ($1)"; grep -hnE -A6 "Error|Failed" "$log" "$P/check.out" | head -30; exit 1; }
"$FACTORIO" --config "$P/config/config.ini" --dump-data > "$P/check.out" 2>&1 || fail "data stage"
grep -qE "Error|Failed to load mods" "$log" && fail "data stage"
echo "data stage ok: $(grep -c 'Checksum of' "$log") mods loaded"
rm -f "$P/saves/_check.zip"
"$FACTORIO" --config "$P/config/config.ini" --create "$P/saves/_check.zip" > "$P/check.out" 2>&1 || fail "control stage"
echo "control stage ok: fresh map created, on_init ran"
