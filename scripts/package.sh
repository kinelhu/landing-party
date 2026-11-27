#!/usr/bin/env bash
# The mods as the portal takes them: landing-party_<version>.zip and landing-party-graphics_<version>.zip (one folder of
# that name inside each), in media/release/, from the mod folders as committed (git archive: nothing untracked or ignored
# goes in), then loaded together in a profile of their own (the zips, not the links the dev profiles use: data stage and
# a fresh map, as check.sh), so zips that do not load are never handed over. The graphics' zip only changes with its art
# (the user, 2026-11-27: Landing Party's updates were 192 MB, its art all but 3 MB of it): released when its version is
# new on the portal (portal.py).
#   scripts/package.sh
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$REPO"
OUT="$REPO/media/release"; mkdir -p "$OUT"
ZIPS=()
for M in landing-party landing-party-graphics; do
  [ -z "$(git status --porcelain $M)" ] || { echo "PACKAGE FAILED: $M/ has uncommitted changes: commit first"; exit 1; }
  V=$(python3 -c "import json; print(json.load(open('$M/info.json'))['version'])")
  N="${M}_$V"
  ZIP="$OUT/$N.zip"
  rm -f "$ZIP"
  git archive --format=zip --prefix="$N/" -o "$ZIP" HEAD:$M
  echo "zip: $ZIP ($(du -h "$ZIP" | cut -f1), $(unzip -l "$ZIP" | tail -1 | awk '{print $2}') files)"
  ZIPS+=("$ZIP")
done
# Its own profile: the zip in mods/, Space Age beside it; the data stage and a fresh map.
P="$HOME/Library/Application Support/factorio-lp-package"
rm -rf "$P"; mkdir -p "$P/config" "$P/mods" "$P/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$P" > "$P/config/config.ini"
cp "${ZIPS[@]}" "$P/mods/"
cat > "$P/mods/mod-list.json" <<JSON
{"mods": [{"name": "base", "enabled": true}, {"name": "landing-party", "enabled": true},{"name":"landing-party-graphics","enabled":true}, {"name": "space-age", "enabled": true},
  {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}]}
JSON
"$FACTORIO" --config "$P/config/config.ini" --create "$P/saves/t.zip" > "$P/create.out" 2>&1 || {
  echo "PACKAGE FAILED: the zip does not load"; grep -nE -A6 "Error" "$P/factorio-current.log" | head -20; exit 1; }
grep -q "landing-party" "$P/factorio-current.log" || { echo "PACKAGE FAILED: the game did not load the mod"; exit 1; }
grep -q "landing-party-graphics" "$P/factorio-current.log" || { echo "PACKAGE FAILED: the game did not load the graphics"; exit 1; }
grep -E "Loading mod landing-party" "$P/factorio-current.log" | head -2
echo "loads: ${ZIPS[*]##*/}"
