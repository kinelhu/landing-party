"""Sheets packed before 0.2.321 at 0.55 of their shadows' alpha (sheet.py's old shade(): int(v * 0.55) above 12) to full
strength, as vanilla's shadow sprites are (the game draws every shadow at its own opacity; ours drew at half of
vanilla's). For sheets whose raw renders are gone (the units: tank, drones, buggy, crawler, hauler, harrier, scavenger):
alpha a becomes round(a / 0.55), so 7..140 maps back to 13..255, within one level of a repack. Refuses a sheet already at
full strength (alpha over 145), so a second run changes nothing.

    uv run --with pillow --with numpy python tools/blender/shadow_full.py <shadow.png>...
"""
import sys
import numpy as np
from PIL import Image

for p in sys.argv[1:]:
    im = np.asarray(Image.open(p).convert("RGBA")).copy()
    a = im[..., 3].astype(np.float32)
    if a.max() > 145:
        print(f"skip {p}: already full strength (alpha {int(a.max())})")
        continue
    im[..., 3] = np.clip(np.round(a / 0.55), 0, 255).astype(np.uint8)
    Image.fromarray(im, "RGBA").save(p, optimize=True)
    print(f"{p}: alpha max {int(a.max())} -> {int(im[..., 3].max())}")
