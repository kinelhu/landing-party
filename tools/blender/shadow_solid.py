"""Shadows as solid shapes, as vanilla's are (the user, 2026-11-11, of the factions' turrets: "You didn't fix any of the
shadows"). Blender's shadow catcher keeps a shadow as a gradient: partly dark under the ambient fill, and a faint halo of
the ground's occlusion round the model. Packed as rendered, Grubstake's gun nest had 8 % of its shadow near solid (alpha
over 200) and spread over twice vanilla's area; vanilla's gun turret has 72 %. Its core sat on a plateau near 105 of 255
(the head's shadow under the fill) and its halo at 17 to 36; KH's autocannon at 108 and 252. Alpha a becomes a ramp:
nothing below LO, solid above HI (a scale by the sheet's maximum left the gun nest at 24 %, a few dark pixels setting it).
The ambient occlusion beside a base reached 60 (a ramp from 45 left it a grey slab west of the flamers, where no
shadow falls); from 70 it goes. A second run changes nothing.

    uv run --with pillow --with numpy python tools/blender/shadow_solid.py <shadow.png>...
"""
import sys
import numpy as np
from PIL import Image

LO, HI = 70, 100


def solid(a):
    return (np.clip((a - LO) / (HI - LO), 0, 1) * 255).round().astype(np.uint8)


# Nothing west of what casts it: the sun comes from the west (lpkit.SUN_DIR, x 1.1), so a cast shadow lies east of its
# caster. The flamers' heads carried a band reaching 64 px west of the head itself, its pass's ambient occlusion under the
# hidden base, kept at 70 to 140 and drawn as a dark slab beside them (2026-11-11). Each frame (sheet.json's grid) is cut
# west of its body's westmost pixel, less MARGIN.
MARGIN = 2


def west_clip(alpha, body, sheet):
    w, h, ll = sheet["width"], sheet["height"], sheet["line_length"]
    for f in range(sheet["frames"]):
        x0, y0 = (f % ll) * w, (f // ll) * h
        b = body[y0:y0 + h, x0:x0 + w]
        cols = np.nonzero(b.max(0) > 128)[0]
        if len(cols):
            alpha[y0:y0 + h, x0:x0 + max(0, cols[0] - MARGIN)] = 0
    return alpha


if __name__ == "__main__":
    import json, os
    for p in sys.argv[1:]:
        im = np.asarray(Image.open(p).convert("RGBA")).copy()
        a = im[..., 3].astype(np.float32)
        before = (a[a > 0] > 200).mean()
        d = os.path.dirname(p)
        if os.path.exists(f"{d}/body.png") and os.path.exists(f"{d}/sheet.json"):
            body = np.asarray(Image.open(f"{d}/body.png").convert("RGBA"))[..., 3]
            a = west_clip(a, body, json.load(open(f"{d}/sheet.json")))
        im[..., 3] = solid(a)
        Image.fromarray(im, "RGBA").save(p, optimize=True)
        nz = im[..., 3][im[..., 3] > 0]
        print(f"{p}: near solid {before:.2f} -> {(nz > 200).mean():.2f}, area {(a > 0).mean():.3f} -> {(im[..., 3] > 0).mean():.3f}")
