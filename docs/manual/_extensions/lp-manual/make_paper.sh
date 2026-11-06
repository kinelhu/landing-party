#!/bin/bash
# The booklet's paper grounds, generated (ImageMagick, seeded, so a rebuild gives the same files):
#   docs/manual/_extensions/lp-manual/make_paper.sh
# writes docs/manual/media/ornaments/paper.jpg (every inner page: near white, a fine grain and a faint mottle) and
# paper-lore.jpg (the lore spreads: the old LPPaper tint, a stronger grain, fibres and a darker edge, an archive file).
# Both are A5 at 150 dpi. The style prints each from one saved box, so the PDF holds each image once.
# Keep them light: body text sits on them, and they must survive a greyscale print (the lore ground is at most 10%
# grey; the body ground at most 3%).
set -euo pipefail
cd "$(dirname "$0")/../../media"
mkdir -p ornaments
W=874; H=1240

# grain(seed, amplitude%): fine noise centred on mid grey, for an overlay.
grain() { magick -size ${W}x${H} xc:gray50 -seed "$1" -attenuate 1 +noise Gaussian -colorspace gray \
  -blur 0x0.5 -level "$((50 - $2))%,$((50 + $2))%" -level-colors gray0,gray100 "$3"; }

T=$(mktemp -d)
# Body paper: #FBF9F4 with a 3% grain and a soft cloudy mottle.
grain 11 60 "$T/g.png"
magick -size ${W}x${H} -seed 12 plasma:gray50-gray50 -colorspace gray -blur 0x24 -auto-level "$T/m.png"
magick -size ${W}x${H} xc:'#FBF9F4' \
  \( "$T/m.png" -evaluate multiply 0.035 -evaluate add 98.25% \) -compose multiply -composite \
  \( "$T/g.png" -evaluate multiply 0.03 -evaluate add 98.5% \) -compose multiply -composite \
  -quality 88 -sampling-factor 1x1 ornaments/paper.jpg

# Lore paper: #F3EDE0, grain, horizontal fibres (motion-blurred specks), a mottle and a darker edge.
grain 21 70 "$T/g2.png"
magick -size ${W}x${H} xc:white -seed 22 +noise Random -colorspace gray -threshold 99.4% -negate \
  -motion-blur 0x9+8 -motion-blur 0x5+-12 -auto-level "$T/f.png"
magick -size ${W}x${H} -seed 23 plasma:gray50-gray50 -colorspace gray -blur 0x40 -auto-level "$T/m2.png"
magick -size ${W}x${H} radial-gradient:white-gray40 -level 30%,100% "$T/v.png"
magick -size ${W}x${H} xc:'#F4EEE1' \
  \( "$T/m2.png" -evaluate multiply 0.05 -evaluate add 97.5% \) -compose multiply -composite \
  \( "$T/g2.png" -evaluate multiply 0.05 -evaluate add 97.5% \) -compose multiply -composite \
  \( "$T/f.png" -negate -evaluate multiply 0.05 -negate \) -compose multiply -composite \
  \( "$T/v.png" -evaluate multiply 0.06 -evaluate add 95% \) -compose multiply -composite \
  -quality 88 -sampling-factor 1x1 ornaments/paper-lore.jpg
mv "$T" "${TMPDIR:-/tmp}/lp-paper-$$-done"
for f in ornaments/paper.jpg ornaments/paper-lore.jpg; do
  printf '%s: ' "$f"; magick "$f" -colorspace gray -format 'mean %[fx:mean] min %[fx:minima]\n' info:
done
