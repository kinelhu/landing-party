#!/bin/bash
# Render the template proof and its pages as PNGs, to look at (pages/p-NN.png at 110 dpi, pages/spreads-N.png as
# the booklet reads on screen: the cover alone, then two pages side by side).
#   docs/manual/_proof/render.sh
set -euo pipefail
cd "$(dirname "$0")"
quarto render proof.qmd --to lp-manual-pdf --quiet
mkdir -p pages
rm -f pages/*.png
pdftoppm -r 110 -png proof.pdf pages/p
n=$(ls pages/p-*.png | wc -l | tr -d ' ')
# spreads: (1), (2,3), (4,5) ... (n)
args=()
for ((i = 2; i < n; i += 2)); do
  a=$(printf "pages/p-%02d.png" "$i"); b=$(printf "pages/p-%02d.png" "$((i + 1))")
  magick "$a" "$b" +append "pages/s-$(printf %02d "$i").png"
done
echo "proof.pdf: $n pages; pages/ holds the pages and spreads"
