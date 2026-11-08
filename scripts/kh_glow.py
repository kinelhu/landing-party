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
SRC = APP + "/data/base/graphics/entity/laser-turret/laser-turret-shooting-light.png"
OUT = os.path.join(os.path.dirname(__file__), "..", "landing-party", "graphics", "serenity", "laser-turret",
                   "laser-turret-shooting-light.png")
CYAN = np.array((0.35, 0.75, 1.0))                     # the beam's tint (data.lua, KH_LASER)
a = np.asarray(Image.open(SRC).convert("RGBA")).astype(np.float64) / 255
v = a[..., :3].max(-1, keepdims=True)                  # each pixel's brightness, its colour the beam's
a[..., :3] = np.clip(v * CYAN / CYAN.max(), 0, 1)
Image.fromarray((a * 255).round().astype(np.uint8)).save(OUT, optimize=True)
print(OUT, os.path.getsize(OUT) // 1024, "KB")
