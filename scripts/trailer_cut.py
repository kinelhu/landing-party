"""The trailer's cut (docs/trailer/storyboard.md sections 4 and 5): the film toolkit's cut.py (~/Dev/factorio-film,
FILM_HOME; its README has the edit list's format) on Landing Party's edit list, run from the repository's root.

  uv run --with pillow scripts/trailer_cut.py docs/trailer/cut.json media/trailer/rough-cut.mp4
"""
import os
import runpy
import sys

TOOL = os.path.join(os.environ.get("FILM_HOME") or os.path.expanduser("~/Dev/factorio-film"), "scripts", "cut.py")
if not os.path.exists(TOOL):
    raise SystemExit(f"trailer_cut: no film toolkit at {TOOL} (FILM_HOME)")
sys.argv[0] = TOOL
runpy.run_path(TOOL, run_name="__main__")
