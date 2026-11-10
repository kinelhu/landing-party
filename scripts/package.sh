#!/usr/bin/env bash
# The mod as the portal takes it: landing-party_<version>.zip (one folder of that name inside), in media/release/, from the
# mod folder as committed (git archive: nothing untracked or ignored goes in), then loaded in a profile of its own (the
# zip, not the link the dev profiles use: data stage and a fresh map, as check.sh), so a zip that does not load is never
# handed over.
#   scripts/package.sh
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$REPO"
[ -z "$(git status --porcelain landing-party)" ] || { echo "PACKAGE FAILED: landing-party/ has uncommitted changes: commit first"; exit 1; }
V=$(python3 -c 'import json; print(json.load(open("landing-party/info.json"))["version"])')
N="landing-party_$V"
OUT="$REPO/media/release"; mkdir -p "$OUT"
ZIP="$OUT/$N.zip"
rm -f "$ZIP"
git archive --format=zip --prefix="$N/" -o "$ZIP" HEAD:landing-party
echo "zip: $ZIP ($(du -h "$ZIP" | cut -f1), $(unzip -l "$ZIP" | tail -1 | awk '{print $2}') files)"
# Its own profile: the zip in mods/, Space Age beside it; the data stage and a fresh map.
P="$HOME/Library/Application Support/factorio-lp-package"
rm -rf "$P"; mkdir -p "$P/config" "$P/mods" "$P/saves"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$P" > "$P/config/config.ini"
cp "$ZIP" "$P/mods/"
cat > "$P/mods/mod-list.json" <<JSON
{"mods": [{"name": "base", "enabled": true}, {"name": "landing-party", "enabled": true}, {"name": "space-age", "enabled": true},
  {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}]}
JSON
"$FACTORIO" --config "$P/config/config.ini" --create "$P/saves/t.zip" > "$P/create.out" 2>&1 || {
  echo "PACKAGE FAILED: the zip does not load"; grep -nE -A6 "Error" "$P/factorio-current.log" | head -20; exit 1; }
grep -q "landing-party" "$P/factorio-current.log" || { echo "PACKAGE FAILED: the game did not load the mod"; exit 1; }
grep -E "Loading mod landing-party" "$P/factorio-current.log" | head -1
echo "loads: $N"
