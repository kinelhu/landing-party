#!/usr/bin/env bash
# The mod page's loops (docs/release/modpage.md): each as a GIF (palette-optimised) and an MP4 (H.264, no sound; the
# portal plays mp4 and webm inline with the image syntax, a fraction of a GIF's size), WIDTH wide, into media/release/gifs/,
# with manifest.json (name, caption, size, seconds).
#   docs/release/gifs.sh
# Sources: the director film's frames (docs/release/strike-film.lua, docs/sim/film-strike-loops) and the loops of
# 2026-11-12 (media/release/loops/*.mp4, docs/release/loops.py and the trailer's culture reel).
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")/../.."
OUT=media/release/gifs; mkdir -p "$OUT"
WIDTH=${WIDTH:-720}
FR=docs/sim/film-strike-loops
# One loop: name, input args (ffmpeg), filter before scaling, fps, caption.
man=()
loop() {
  local name=$1 fps=$2 pre=$3 caption=$4; shift 4
  local vf="${pre:+$pre,}fps=$fps,scale=$WIDTH:-2:flags=lanczos"
  # (The GIF a fallback: the desert's grain defeats a GIF's compression, 32 MB at 30 fps and 720 wide; 12 fps, 560 wide,
  # 96 colours about 5 MB, banded. The MP4 of the same loop is a few hundred kB and the portal plays it inline.)
  local gf="${pre:+$pre,}fps=$(( fps < 12 ? fps : 12 )),scale=560:-2:flags=lanczos"
  ffmpeg -loglevel error -y "$@" -vf "$gf,split[a][b];[a]palettegen=max_colors=96:stats_mode=full[p];[b][p]paletteuse=dither=none" -loop 0 "$OUT/$name.gif"
  ffmpeg -loglevel error -y "$@" -vf "$vf" -an -c:v libx264 -pix_fmt yuv420p -crf 26 -preset slow -movflags +faststart "$OUT/$name.mp4"
  local s; s=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/$name.mp4")
  man+=("$(printf '{"name": "%s", "caption": "%s", "seconds": %.1f, "gif_bytes": %d, "mp4_bytes": %d}' "$name" "$caption" "$s" \
    "$(stat -f %z "$OUT/$name.gif")" "$(stat -f %z "$OUT/$name.mp4")")")
  echo "$name: $(du -h "$OUT/$name.gif" | cut -f1) gif, $(du -h "$OUT/$name.mp4" | cut -f1) mp4, ${s}s"
}
# (The director's set: cropped to the cluster, the set's power unit at the right left out.)
CROP="crop=860:540:80:40"
loop pods 30 "$CROP" "A Kessler-Hayashi strike force's pods coming down beside a factory's labs." -framerate 30 -i "$FR/pods-%05d.png"
loop strike-fight 30 "$CROP" "The strike force among the labs." -framerate 30 -i "$FR/fight-%05d.png"
loop walk-home 30 "" "A strike force broken by a ring of guns, walking home through the cluster it hit." -framerate 30 -i "$FR/home-%05d.png"
L=media/release/loops
loop tesla 30 "" "Kessler-Hayashi's Tesla units' lightning on your troops." -i "$L/tesla.mp4"
loop bombers 30 "" "Grubstake's bomb drones diving on your troopers on the march." -i "$L/bombers.mp4"
loop prism 30 "" "Kessler-Hayashi's Prisms, with its tanks and a Tesla, against your troops." -i "$L/prism.mp4"
loop flak 30 "" "Grubstake's flak buggies against Kessler-Hayashi's scout drones." -i "$L/flak.mp4"
loop arcflamer 10 "" "Kessler-Hayashi's arc flamer: lightning that sets its targets burning blue." -i "$L/arcflamer.mp4"
loop cannon-strike 10 "" "Your orbital cannons' strike on a Synthexis culture." -i "$L/strike.mp4"
(IFS=,; echo "[${man[*]}]") | python3 -m json.tool > "$OUT/manifest.json"
echo "$OUT/manifest.json"
