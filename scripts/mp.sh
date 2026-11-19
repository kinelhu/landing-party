#!/usr/bin/env bash
# Multiplayer check: a headless server on a copy of a visit's save and one client in a game window, both on Landing
# Party from this repository; the corporations' events forced over RCON while they play; any desync in either log fails.
#   scripts/mp.sh [visit name] [save in its saves] [minutes]     (default nw-playtest-saveat45 t45.zip 8)
# First, with the server alone, heavy mode (the game saves and loads every tick and compares the two: state kept outside
# storage shows there) for LP_HEAVY seconds (default 90; about 2.7 s a tick on nw at minute 45, so a few dozen ticks:
# a first pass, short of the planners' 300- and 600-tick looks; the client run is the test). LP_NOCLIENT=1: heavy mode only, no window.
# Never the real profile or a real save: the save is a visit profile's copy, copied again into factorio-lp-mp.
# LP_ARMY=1 (0.2.467): no save, a fresh map; two clients in windows, and the player's army used from both at once
# (tests/lp-mp, driven over RCON): a's cards, b's squad panel and hover rings, each its own; a dry unit's alert for both.
set -uo pipefail
source "$(dirname "$0")/env.sh"
NAME="${1:-nw-playtest-saveat45}"; SAVE="${2:-t45.zip}"; MINUTES="${3:-8}"
SRC="$HOME/Library/Application Support/factorio-lp-visit/$NAME/saves/$SAVE"
[ -n "${LP_ARMY:-}" ] && NAME="army"
[ -n "${LP_ARMY:-}" ] || [ -f "$SRC" ] || { echo "no $SRC"; exit 1; }
ROOT="$HOME/Library/Application Support/factorio-lp-mp"
PORT=34299; RPORT=27299; RPASS="lp-mp"
OUT="$REPO/docs/sim/mp-$NAME"; mkdir -p "$OUT"
profile() {
  local p="$1"
  mkdir -p "$p/config" "$p/mods" "$p/saves"
  printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n[graphics]\nfullscreen=false\n' "$p" > "$p/config/config.ini"
  rm -rf "$p/mods/lp-sim" "$p/mods/lp-mp"
  ln -sfn "$REPO/landing-party" "$p/mods/landing-party"
  local extra=""
  if [ -n "${LP_ARMY:-}" ]; then ln -sfn "$REPO/tests/lp-mp" "$p/mods/lp-mp"; extra=', {"name": "lp-mp", "enabled": true}'; fi
  echo '{"mods": [{"name": "base", "enabled": true}, {"name": "space-age", "enabled": true}, {"name": "quality", "enabled": true}, {"name": "elevated-rails", "enabled": true}, {"name": "landing-party", "enabled": true}'"$extra"']}' > "$p/mods/mod-list.json"
  rm -rf "$p/desync-report"* "$p/temp/desync-report"* 2>/dev/null
}
S="$ROOT/server"; C="$ROOT/client"; C2="$ROOT/client2"
for p in "$S" "$C" ${LP_ARMY:+"$C2"}; do
  if pgrep -f -- "--config $p/config/config.ini" > /dev/null; then echo "refusing: a game is running on $p"; exit 1; fi
  profile "$p"
done
if [ -n "${LP_ARMY:-}" ]; then
  rm -f "$S/saves/mp.zip" "$OUT/army.txt"
  "$FACTORIO" --config "$S/config/config.ini" --create "$S/saves/mp.zip" --map-gen-seed 4242 > "$OUT/create.log" 2>&1 \
    || { echo "MP FAILED: could not create the map"; tail -20 "$OUT/create.log"; exit 1; }
  echo '{"service-username": "lp-mp-b"}' > "$C2/player-data.json"
else
  cp "$SRC" "$S/saves/mp.zip"
fi
cat > "$S/server-settings.json" <<'EOF'
{"name": "lp-mp", "description": "", "visibility": {"public": false, "lan": false}, "require_user_verification": false,
 "max_players": 4, "auto_pause": false, "only_admins_can_pause_the_game": true, "autosave_interval": 0,
 "autosave_only_on_server": true, "non_blocking_saving": false}
EOF
echo '{"service-username": "lp-mp-client"}' > "$C/player-data.json"
L="$ROOT/launch"; mkdir -p "$L"; echo 427520 > "$L/steam_appid.txt"; cd "$L"
rcon() { python3 "$REPO/scripts/rcon.py" "$RPORT" "$RPASS" "$@"; }
spid=""; cpid=""; c2pid=""
stop() { [ -n "$c2pid" ] && kill "$c2pid" 2>/dev/null; [ -n "$cpid" ] && kill "$cpid" 2>/dev/null; [ -n "$spid" ] && kill "$spid" 2>/dev/null; cpid=""; c2pid=""; spid=""; }
trap stop EXIT

# Its stdin held open by this script (on EOF the server logs an error and stops reading it).
rm -f "$ROOT/stdin"; mkfifo "$ROOT/stdin"; exec 3<> "$ROOT/stdin"
"$FACTORIO" --config "$S/config/config.ini" --start-server "$S/saves/mp.zip" --server-settings "$S/server-settings.json" \
  --port "$PORT" --rcon-port "$RPORT" --rcon-password "$RPASS" < "$ROOT/stdin" > "$OUT/server.log" 2>&1 &
spid=$!
for _ in $(seq 1 180); do grep -q "to(InGame)" "$OUT/server.log" && break; kill -0 $spid 2>/dev/null || break; sleep 1; done
grep -q "to(InGame)" "$OUT/server.log" || { echo "MP FAILED: the server never reached the game"; tail -20 "$OUT/server.log"; exit 1; }
echo "server up: $(rcon '/sc rcon.print(game.tick)') ticks"

tick() { rcon '/sc rcon.print(game.tick)' | tail -1; }

if [ -n "${LP_ARMY:-}" ]; then
  step() { rcon "/sc rcon.print(remote.call('lp-mp', 'step', '$1'))"; }
  joined() { grep -cE "joined the game|Player .* joined" "$OUT/server.log"; }
  "$FACTORIO" --config "$C/config/config.ini" --mp-connect "127.0.0.1:$PORT" --disable-audio > "$OUT/client.log" 2>&1 &
  cpid=$!
  for _ in $(seq 1 300); do [ "$(joined)" -ge 1 ] && break; kill -0 $cpid 2>/dev/null || break; sleep 1; done
  "$FACTORIO" --config "$C2/config/config.ini" --mp-connect "127.0.0.1:$PORT" --disable-audio > "$OUT/client2.log" 2>&1 &
  c2pid=$!
  for _ in $(seq 1 300); do [ "$(joined)" -ge 2 ] && break; kill -0 $c2pid 2>/dev/null || break; sleep 1; done
  [ "$(joined)" -ge 2 ] || { echo "MP FAILED: $(joined) of 2 clients joined"; tail -20 "$OUT/client2.log"; exit 1; }
  echo "both clients joined at tick $(tick)"
  { step setup; sleep 3; step gui; sleep 3; step read_gui; } | tee "$OUT/army.txt"
  for _ in $(seq 1 "${LP_ARMY_POLLS:-120}"); do
    kill -0 $cpid 2>/dev/null && kill -0 $c2pid 2>/dev/null || { echo "CHECK BAD clients: one quit" | tee -a "$OUT/army.txt"; break; }
    step poll > "$OUT/poll.txt"; sleep 1
  done
  tail -1 "$OUT/poll.txt"
  step report | tee -a "$OUT/army.txt"
  cp -R "$C/script-output/lp-mp" "$OUT/client-a" 2>/dev/null; cp -R "$C2/script-output/lp-mp" "$OUT/client-b" 2>/dev/null
  MINUTES=0
fi
HEAVY="${LP_HEAVY:-90}"
# The director's beats forced first (2026-11-15, 0.2.422), so heavy mode saves and reloads their state: strike forces
# by kind, a joint strike, a contract, a rotation, salvage with its data core, a bounty, the masts, a lull and a climax.
# (Two runs before the director had no beat of its own in either.)
# (strike|power last and only with LP_POWER=1: a power strike holds every other strike force till it is over, so the
# joint after it was "no joint possible", 2026-11-16; its heavy-mode passes are the runs of 2026-11-15.)
# (No lull and no unforced strike unless LP_HOLDS=1: a lull's truce leaves no corporation at war for its length, the
# whole test, and an unforced strike may be a power strike; the joint and the climax were then impossible.)
director_beats="strike|research strike|logistics joint contract rotation salvage|core bounty jammer blackout climax${LP_HOLDS:+ strike lull}${LP_POWER:+ strike|power}"
[ -n "${LP_ARMY:-}" ] && director_beats=""
[ -n "${LP_ARMY:-}" ] || rcon "/sc remote.call('landing-party', 'director_cmd', 'on')" > /dev/null
for b in $director_beats; do
  a="${b%%|*}"; arg="${b#*|}"; [ "$arg" = "$b" ] && arg=""
  r=$(rcon "/sc rcon.print(tostring(remote.call('landing-party', 'director_cmd', '$a'${arg:+, '$arg'})))" | tail -1)
  echo "  director $b: $r"
done
if [ -z "${LP_ARMY:-}" ]; then
t0=$(tick); rcon "/toggle-heavy-mode" > /dev/null; sleep "$HEAVY"; rcon "/toggle-heavy-mode" > /dev/null; t1=$(tick)
echo "heavy mode: ticks $t0 to $t1 ($((t1 - t0)) ticks)"
fi

# The camps' landers (their forces and positions) and the events forced at each, every half a minute.
landers=$(rcon '/sc local o = {} for _, e in pairs(game.surfaces[1].find_entities_filtered{name = {"lp-lander", "lp-grubstake-lander"}}) do o[#o+1] = e.force.name .. "@" .. math.floor(e.position.x) .. "," .. math.floor(e.position.y) end rcon.print(table.concat(o, " "))' | tail -1)
echo "landers: $landers"
events=()
for l in $landers; do
  xy="${l#*@}"; x="${xy%,*}"; y="${xy#*,}"
  case "$l" in
    lp-serenity@*) events+=("siege|$x|$y" "strike|$x|$y" "perimeter|$x|$y");;
    lp-grubstake@*)
      # Its raid and strip are on the player's buildings near where they are called: the player's drill nearest its camp.
      near=$(rcon "/sc local s = game.surfaces[1] local d = s.find_entities_filtered{force = 'player', type = 'mining-drill', position = {$x, $y}, radius = 600} local best, bd for _, e in pairs(d) do local q = (e.position.x - $x) ^ 2 + (e.position.y - $y) ^ 2 if not bd or q < bd then best, bd = e, q end end rcon.print(best and (math.floor(best.position.x) .. ',' .. math.floor(best.position.y)) or '$x,$y')" | tail -1)
      events+=("raid|${near%,*}|${near#*,}" "strip|${near%,*}|${near#*,}");;
  esac
done
# (provoke first: a joint strike wants two corporations at war, and Grubstake landed unprovoked on the belt reference
# save, so the joint was "no joint possible", 2026-11-16.)
events+=("provoke|0|0" "director joint|0|0" "wave|0|0" "land serenity 400|0|0" "raid|0|0" "director joint|0|0")

# (The game at LP_SPEED, default 0.5, while the client plays: on nw at minute 45 with the director's strikes out, the
# client was dropped for not keeping up at full speed, 2026-11-15. A desync is the same at any speed.)
rcon "/sc game.speed = ${LP_SPEED:-0.5}" > /dev/null
if [ -z "${LP_NOCLIENT:-}" ] && [ -z "${LP_ARMY:-}" ]; then
  "$FACTORIO" --config "$C/config/config.ini" --mp-connect "127.0.0.1:$PORT" --disable-audio > "$OUT/client.log" 2>&1 &
  cpid=$!
  # (LP_JOIN seconds to join, default 600: on nw at minute 45 with the director's beats out, the client caught up 82,000
  # ticks in 135 s and the old 240 s ran out as it was about to start, 2026-11-15.)
  for _ in $(seq 1 "${LP_JOIN:-600}"); do grep -qE "joined the game|Player .* joined" "$OUT/server.log" && break; kill -0 $cpid 2>/dev/null || break; sleep 1; done
  grep -qE "joined the game|Player .* joined" "$OUT/server.log" || { echo "MP FAILED: the client never joined"; tail -20 "$OUT/client.log"; exit 1; }
  echo "client joined at tick $(tick)"
  end=$(( $(date +%s) + MINUTES * 60 )); i=0
  while [ "$(date +%s)" -lt "$end" ]; do
    kill -0 $cpid 2>/dev/null || { echo "MP FAILED: the client quit"; break; }
    e="${events[$((i % ${#events[@]}))]}"; i=$((i + 1))
    verb="${e%%|*}"; rest="${e#*|}"; x="${rest%%|*}"; y="${rest#*|}"
    args=$(printf '"%s",' $verb); args="{${args%,}}"
    case "$verb" in
      director\ *) echo "    -> $(rcon "/sc rcon.print(tostring(remote.call('landing-party', 'director_cmd', '${verb#director }')))" | tail -1)";;
      *) rcon "/sc remote.call('landing-party', 'dev', $args, {$x, $y}, 1)" > /dev/null;;
    esac
    echo "  $(tick): $verb at $x,$y"
    sleep 30
  done
fi
echo "ended at tick $(tick)"
stop; trap - EXIT; exec 3>&-; sleep 3
fail=0
grep -q "CHECK BAD" "$OUT/army.txt" 2>/dev/null && { grep "CHECK BAD" "$OUT/army.txt"; fail=1; }
[ -n "${LP_ARMY:-}" ] && [ "$(grep -c "CHECK ok" "$OUT/army.txt")" -lt 7 ] && { echo "army: $(grep -c "CHECK ok" "$OUT/army.txt") of 7 checks ok"; fail=1; }
for f in "$OUT/server.log" "$OUT/client.log" "$OUT/client2.log"; do
  [ -f "$f" ] || continue
  if grep -inE "desync|crc mismatch|heavy mode.*(differ|mismatch)" "$f" | grep -v "toggle-heavy-mode" | head -5 | grep .; then fail=1; fi
  if grep -nE "Error|Lua error|Script error" "$f" | grep -viE "steam|achievement|ErrorCode::0" | head -5 | grep .; then fail=1; fi
done
reports=$(ls -d "$S"/desync-report* "$C"/desync-report* "$C2"/desync-report* "$C2"/temp/desync-report* "$S"/temp/desync-report* "$C"/temp/desync-report* 2>/dev/null)
[ -n "$reports" ] && { echo "desync reports: $reports"; fail=1; }
[ $fail -eq 0 ] && echo "MP PASSED" || echo "MP FAILED (logs in $OUT)"
exit $fail
