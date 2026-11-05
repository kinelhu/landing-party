"""The trailer's score (the user, 2026-11-05: "Go ahead. Game sounds allowed. Surprise me"): the film toolkit's score.py
(~/Dev/factorio-film, FILM_HOME) on Landing Party's edit list, its acts, chords, motif and hits in docs/trailer/score.json
(cut.json names it). Run from the repository's root.

  uv run --with numpy --with scipy --with pyloudnorm scripts/trailer_score.py docs/trailer/cut.json media/trailer/score.wav
"""
import os
import runpy
import sys

TOOL = os.path.join(os.environ.get("FILM_HOME") or os.path.expanduser("~/Dev/factorio-film"), "scripts", "score.py")
if not os.path.exists(TOOL):
    raise SystemExit(f"trailer_score: no film toolkit at {TOOL} (FILM_HOME)")
sys.argv[0] = TOOL
runpy.run_path(TOOL, run_name="__main__")
