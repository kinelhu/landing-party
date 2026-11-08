"""Kessler-Hayashi's laser turret glow in cyan (the user, 2026-11-08: Kessler-Hayashi's lasers recoloured from red; its
beam is a tinted copy, but the turret's charge glow is a red-orange image, which a tint can only darken): the glow's
hue turned to its lights' cyan at its own brightness, written beside its recolours.
    uv run --with pillow --with numpy python scripts/kh_glow.py
"""
import os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
APP = os.environ.get("APP") or sys.exit("source scripts/env.sh first (APP)")
# The beam's own images too (its tint read yellow-white on film, 2026-11-08: a cyan tint over a red-orange image), and the
# turret's glow; each pixel's brightness kept, its colour the beam's cyan, the white-hot core kept nearly white.
SRC = APP + "/data/base/graphics/entity/laser-turret/"
OUT = os.path.join(os.path.dirname(__file__), "..", "landing-party", "graphics", "serenity", "laser-turret")
FILES = ["laser-turret-shooting-light.png", "laser-body.png", "laser-body-light.png", "laser-end.png", "laser-end-light.png",
         "laser-ground-light-body.png", "laser-ground-light-head.png", "laser-ground-light-tail.png"]
CYAN = np.array((0.35, 0.75, 1.0))                     # the beam's colour (data.lua, KH_LASER)
# And the Prism's split beam violet (units.lua, lp-prism-split: its tint over the red image read red on film too).
VIOLET = np.array((0.85, 0.45, 1.0))
JOBS = [(OUT, CYAN, FILES), (OUT + "-violet", VIOLET, [f for f in FILES if f != "laser-turret-shooting-light.png"])]
for OUT, CYAN, FILES in JOBS:
  os.makedirs(OUT, exist_ok=True)
  for f in FILES:
      a = np.asarray(Image.open(SRC + f).convert("RGBA")).astype(np.float64) / 255
      v = a[..., :3].max(-1, keepdims=True)
      # Where it was white-hot (the beam's core), kept near white; a light mask (white by design) takes the colour whole.
      core = 0 if "light" in f else np.clip((a[..., :3].min(-1, keepdims=True) - 0.55) / 0.4, 0, 1)
      rgb = v * CYAN / CYAN.max()
      a[..., :3] = np.clip(rgb + (v - rgb) * core, 0, 1)
      Image.fromarray((a * 255).round().astype(np.uint8)).save(os.path.join(OUT, f), optimize=True)
      print(f, os.path.getsize(os.path.join(OUT, f)) // 1024, "KB")
