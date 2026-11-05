#!/bin/bash
# Impose the A5 manual for printing as a folded booklet: A4 sheets, landscape, two A5 pages a side, in booklet order
# (print double-sided, flip on the short edge, fold, staple). The manual already pads itself to a multiple of four
# pages, so the back cover lands on the last sheet.
#   _extensions/lp-manual/impose.sh manual.pdf [manual-booklet.pdf]
set -euo pipefail
in="$1"; out="${2:-${1%.pdf}-booklet.pdf}"
pdfjam --quiet --booklet true --landscape --a4paper --outfile "$out" "$in"
echo "$out"
