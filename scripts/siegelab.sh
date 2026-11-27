#!/usr/bin/env bash
# The siege lab (the user, 2026-10-30: "test quickly various adaptation techniques a player might think of"): a fortress
# and one grown Synthexis culture in a save; trials of its real AI against the fortress, back to back, its defences
# rebuilt between trials and what it learned kept; the save it ends with carries the learning, for the next edit.
#   scripts/siegelab.sh play <save.zip>            open a copy in the game window (its own profile, this checkout's mod) to
#                                                  build on; plot: an empty plot to build a fortress on (build ... plot)
#   scripts/siegelab.sh build [seed] [square|star|plot|fed|lane] grow the lab (the siege test's fortress, a star fort, an empty plot, the square powered from outside, or a lane: a corridor closed by water, one wall from water to water, LAB_LANE="walls=2,gap=4,step=6,inset=3,mines=out|in|between|none", saved as lab-lane[-LAB_TAG].zip; a culture of 8 or more
#                                                  incubators at full evolution): factorio-lp-lab/lab.zip
#   scripts/siegelab.sh run <save.zip> [trials]    (LAB_WAY: a corporation's way at a closed wall forced) trials against a COPY of the save (never the original); report and
#                                                  lab-out.zip (the learning kept) in docs/sim/lab-<save>/
# Edit a save's defences in the game's map editor (/editor), time paused, and run it again. LAB_BIOMASS: what the
# culture holds at each trial's start (20000); LAB_HOLD: game minutes a trial waits for a wave before it records why
# none came (15); LAB_REBUILD_AFTER: game minutes after a trial ends before its defences are rebuilt (0: before the next
# trial; later, the next attack may find the hole open).
# Both run as a headless server at speed (a benchmark cannot save), in their own profile.
set -euo pipefail
source "$(dirname "$0")/env.sh"
CMD="${1:?usage: scripts/siegelab.sh build [seed] [square|star|plot|fed|lane] | run <save.zip> [trials] | play <save.zip>}"
LAB="$HOME/Library/Application Support/factorio-lp-lab"
mkdir -p "$LAB"

profile() {  # $1: the profile's folder
  local P="$1"
  case "$P" in *"/factorio/"*) echo "refusing: $P is inside the real profile"; exit 1;; esac
  if pgrep -f -- "--config $P/config/config.ini" > /dev/null; then echo "refusing: a game is running on $P"; exit 1; fi
  mkdir -p "$P/config" "$P/mods" "$P/saves"
  printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$P" > "$P/config/config.ini"
  ln -sfn "$REPO/landing-party" "$P/mods/landing-party"
  ln -sfn "$REPO/landing-party-graphics" "$P/mods/landing-party-graphics"
  rm -rf "$P/mods/lp-sim"; cp -R "$REPO/tests/lp-sim" "$P/mods/lp-sim"
  echo '{"mods": [{"name": "base", "enabled": true}, {"name": "space-age", "enabled": true}, {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}, {"name": "landing-party", "enabled": true},{"name":"landing-party-graphics","enabled":true}, {"name": "lp-sim", "enabled": true}]}' > "$P/mods/mod-list.json"
  python3 - "$APP/data/server-settings.example.json" "$P/server-settings.json" <<'PY'
import json, re, sys
s = json.loads(re.sub(r"^\s*//.*$", "", open(sys.argv[1]).read(), flags=re.M))
s.update({"name": "lp-lab", "description": "", "visibility": {"public": False, "lan": False},
          "require_user_verification": False, "auto_pause": False, "autosave_interval": 0, "autosave_slots": 1})
json.dump(s, open(sys.argv[2], "w"))
PY
}

serve() {  # $1 profile, $2 save, $3 file whose appearance ends it, $4 seconds at most
  local P="$1" SAVE="$2" DONE="$3" MAX="$4"
  "$FACTORIO" --config "$P/config/config.ini" --start-server "$SAVE" --server-settings "$P/server-settings.json" \
    --port $((34300 + $$ % 3000)) > "$P/server.out" 2>&1 &
  local pid=$!
  trap "kill $pid 2>/dev/null || true" EXIT
  for _ in $(seq 1 "$MAX"); do
    [ -f "$DONE" ] && break
    # (A scenario error is a FAIL line, not a stopped server: a lane with gaps waited out the whole limit.)
    if grep -qs '^FAIL' "$(dirname "$DONE")/results.txt"; then
      kill $pid 2>/dev/null || true; trap - EXIT
      echo "LAB FAILED:"; grep -h '^FAIL' "$(dirname "$DONE")/results.txt" | head -5; exit 1
    fi
    kill -0 $pid 2>/dev/null || { echo "LAB FAILED: the server stopped"; grep -hA8 Error "$P/server.out" | head -20; exit 1; }
    sleep 1
  done
  sleep 5
  kill $pid 2>/dev/null || true; wait $pid 2>/dev/null || true
  trap - EXIT
  [ -f "$DONE" ] || { echo "LAB FAILED: not done within $MAX s"; tail -20 "$P/server.out"; exit 1; }
}

case "$CMD" in
build)
  SEED="${2:-12345}"; FORT="${3:-square}"
  P="$LAB/build-$FORT${LAB_TAG:+-$LAB_TAG}"
  profile "$P"
  printf 'return {scenario = "farm", minutes = 120, every = 120, strike = 1, distance = 300, radius = 220, doctrine = nil, units = 0, move = false, fast = false, mix = "lab", lab = "build", fort = "%s", lane = "%s", lab_pens = %s}\n' "$FORT" "${LAB_LANE:-}" "${LAB_PENS:-0}" > "$P/mods/lp-sim/params.lua"
  out="$P/script-output/landing-party"
  rm -rf "$out" "$P/saves/"*.zip
  # A lane: a ribbon map (the base game's ribbon world: a band of its height), HALF either side of the axis.
  GEN="$REPO/scripts/map-gen.json"
  if [ "$FORT" = "lane" ]; then
    HALF="$(printf '%s' "${LAB_LANE:-}" | sed -n 's/.*half=\([0-9]*\).*/\1/p')"
    GEN="$P/map-gen.json"
    python3 -I -c 'import json,sys; s=json.load(open(sys.argv[1])); s["height"]=2*int(sys.argv[2]); json.dump(s, open(sys.argv[3],"w"))' \
      "$REPO/scripts/map-gen.json" "${HALF:-64}" "$GEN"
  fi
  "$FACTORIO" --config "$P/config/config.ini" --create "$P/saves/start.zip" --map-gen-seed "$SEED" \
    --map-gen-settings "$GEN" > "$P/create.out" 2>&1 || {
    echo "LAB FAILED: map creation"; grep -A6 Error "$P/create.out" | head -12; exit 1; }
  serve "$P" "$P/saves/start.zip" "$out/lab-saved.txt" 1800
  OUTSAVE="$LAB/lab.zip"; [ "$FORT" != "square" ] && OUTSAVE="$LAB/lab-$FORT${LAB_TAG:+-$LAB_TAG}.zip"
  cp "$P/saves/lab.zip" "$OUTSAVE"
  echo "lab built ($(cat "$out/lab-saved.txt")): $OUTSAVE"
  grep -h "lab: " "$out/results.txt" 2>/dev/null || true
  ;;
run)
  SAVE="${2:?usage: scripts/siegelab.sh run <save.zip> [trials]}"; TRIALS="${3:-3}"
  # (LAB_FACTION: a corporation (serenity, grubstake) in place of the culture, its own choice each trial at war with the player (LAB_KIND auto), or a raid or siege forced
  # at the fort (LAB_KIND raid, siege); on a lane built with faces=both, its front toward the camp. LAB_SEED: its farm's random source reseeded at the start, for replicates of one save: a lane is the same map
  # whatever its build seed, and its farm seeds by the tick it first chose. LAB_RUN_TAG: the run's own name.)
  NAME="$(basename "$SAVE" .zip)${LAB_RUN_TAG:+-$LAB_RUN_TAG}"
  P="$LAB/run-$NAME"
  profile "$P"
  RUN="$(date +%s)"
  printf 'return {scenario = "lab", minutes = 600, every = 600, strike = 1, distance = 300, radius = 220, doctrine = nil, units = 0, move = false, fast = false, mix = "lab", lab = "run", lab_run = %s, lab_trials = %s, lab_biomass = %s, lab_hold = %s, lab_rebuild_after = %s, lab_time = %s, lab_seed = %s, lab_faction = "%s", lab_kind = "%s", lab_parts = %s, lab_level = %s, lab_era = %s, lab_chest = %s, lab_way = "%s"}\n' \
    "$RUN" "$TRIALS" "${LAB_BIOMASS:-20000}" "${LAB_HOLD:-15}" "${LAB_REBUILD_AFTER:-0}" "${LAB_TIME:-false}" "${LAB_SEED:-nil}" \
    "${LAB_FACTION:-biotech}" "${LAB_KIND:-auto}" "${LAB_PARTS:-1000}" "${LAB_LEVEL:-2}" "${LAB_ERA:-2}" "${LAB_CHEST:-3000}" "${LAB_WAY:-}" > "$P/mods/lp-sim/params.lua"
  out="$P/script-output/landing-party"
  rm -rf "$out" "$P/saves/"*.zip
  cp "$SAVE" "$P/saves/in.zip"
  # (The last run's results cleared first: a run that died left them, and they were read as the new one's, 2026-10-30.)
  dest="$REPO/docs/sim/lab-$NAME"
  mkdir -p "$dest"
  rm -rf "$dest"/lab*.jsonl "$dest/costmaps" "$dest/report.md" "$dest/report.html" "$dest/decisions.txt"
  serve "$P" "$P/saves/in.zip" "$out/lab-done.txt" $((TRIALS * 900 + 300))
  if grep -q "Error while running event" "$P/server.out"; then echo "LAB FAILED: the mod errored"; grep -A4 "Error while running event" "$P/server.out" | head -8; exit 1; fi
  cp "$out"/lab*.jsonl "$out/decisions.txt" "$dest/" 2>/dev/null || true; cp -R "$out/costmaps" "$dest/" 2>/dev/null || true
  cp "$P/saves/lab-out.zip" "$dest/lab-out.zip"
  uv run --quiet --with matplotlib python3 -I "$REPO/scripts/lab_report.py" "$dest/lab.jsonl" "$dest" || echo "report skipped"
  echo "trials: $dest/report.md; the learning kept: $dest/lab-out.zip"
  ;;
play)
  # A lab save in the game window, to build a fortress on it: its own profile (factorio-lp-lab/play) with this checkout's
  # Landing Party (and Editor Extensions and flib, copied from the real profile when made for 2.1), no test mod. The save
  # is copied once as <name>-edit.zip in that profile's saves and opened from there after: what you save is kept.
  SAVE="${2:?usage: scripts/siegelab.sh play <save.zip>}"
  NAME="$(basename "$SAVE" .zip)"; NAME="${NAME%-edit}"
  P="$LAB/play"
  case "$P" in *"/factorio/"*) echo "refusing: $P is inside the real profile"; exit 1;; esac
  if pgrep -f -- "--config $P/config/config.ini" > /dev/null; then echo "refusing: a game is running on $P"; exit 1; fi
  mkdir -p "$P/config" "$P/mods" "$P/saves"
  [ -f "$P/config/config.ini" ] || printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$P" > "$P/config/config.ini"
  EDIT="$P/saves/$NAME-edit.zip"
  if [ -f "$EDIT" ]; then echo "opening your edit: $EDIT"; else cp "$SAVE" "$EDIT"; echo "copied to $EDIT"; fi
  rm -rf "$P/mods/lp-sim"
  ln -sfn "$REPO/landing-party" "$P/mods/landing-party"
  ln -sfn "$REPO/landing-party-graphics" "$P/mods/landing-party-graphics"
  REAL="$HOME/Library/Application Support/factorio/mods"
  extra=""
  for m in EditorExtensions flib; do
    z=$(ls "$REAL/${m}_"*.zip 2>/dev/null | sort -V | tail -1 || true)
    if [ -n "$z" ] && unzip -p "$z" '*/info.json' 2>/dev/null | grep -q '"factorio_version": *"2.1"'; then
      cp "$z" "$P/mods/"; extra="$extra, {\"name\": \"$m\", \"enabled\": true}"
    else
      rm -f "$P/mods/${m}_"*.zip
    fi
  done
  echo "{\"mods\": [{\"name\": \"base\", \"enabled\": true}, {\"name\": \"space-age\", \"enabled\": true}, {\"name\": \"quality\", \"enabled\": true}, {\"name\": \"elevated-rails\", \"enabled\": true}, {\"name\": \"landing-party\", \"enabled\": true}$extra]}" > "$P/mods/mod-list.json"
  echo "build in the map editor (/editor, time paused); save over $NAME-edit; then: scripts/siegelab.sh run \"$EDIT\" [trials]"
  L="$P/launch"; mkdir -p "$L"; echo 427520 > "$L/steam_appid.txt"
  cd "$L"
  exec "$FACTORIO" --config "$P/config/config.ini" --load-game "$EDIT"
  ;;
*) echo "usage: scripts/siegelab.sh build [seed] [square|star|plot|fed|lane] | run <save.zip> [trials] | play <save.zip>"; exit 1;;
esac
