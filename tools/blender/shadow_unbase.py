"""A turret's head shadow cleared where it falls on its own base (the user, 2026-11-11, an annotated still of the gun
nest: its plate darker under the box than its own top strip). The game draws a turret's head layers, its shadow among
them, over the base's picture: where the head's shadow crossed the base's footprint it darkened the base itself, a shadow
laid on top of the turret. Vanilla's head shadows never cover its base sprite. Each head-shadow frame is cleared where
the base's body is opaque (alpha over 128), the sheets aligned as the game draws them: centred on the entity plus each
sheet's shift, 64 pixels a tile (scale 0.5). Several base folders (a flamer's four directions): their union.

    uv run --with pillow --with numpy python tools/blender/shadow_unbase.py <head dir> <base dir>...
"""
import json, sys
import numpy as np
from PIL import Image

PX = 64


def load(d):
    return json.load(open(f"{d}/sheet.json")), np.asarray(Image.open(f"{d}/body.png").convert("RGBA"))[..., 3]


head = sys.argv[1]
hj = json.load(open(f"{head}/sheet.json"))
hw, hh, ll = hj["width"], hj["height"], hj["line_length"]
mask = np.zeros((hh, hw), bool)          # the bases' opaque pixels, in a head frame's coordinates
for bd in sys.argv[2:]:
    bj, ba = load(bd)
    bw, bh = bj["width"], bj["height"]
    b = ba[:bh, :bw] > 128               # (a base is one frame)
    dx = (bj["shift"][0] - hj["shift"][0]) * PX + hw / 2 - bw / 2
    dy = (bj["shift"][1] - hj["shift"][1]) * PX + hh / 2 - bh / 2
    ys, xs = np.nonzero(b)
    X, Y = np.round(xs + dx).astype(int), np.round(ys + dy).astype(int)
    ok = (X >= 0) & (X < hw) & (Y >= 0) & (Y < hh)
    mask[Y[ok], X[ok]] = True
im = np.asarray(Image.open(f"{head}/shadow.png").convert("RGBA")).copy()
before = int((im[..., 3] > 0).sum())
for f in range(hj["frames"]):
    x0, y0 = (f % ll) * hw, (f // ll) * hh
    im[y0:y0 + hh, x0:x0 + hw, 3][mask] = 0
Image.fromarray(im, "RGBA").save(f"{head}/shadow.png", optimize=True)
print(f"{head}: base footprint {int(mask.sum())} px a frame; shadow pixels {before} -> {int((im[..., 3] > 0).sum())}")
