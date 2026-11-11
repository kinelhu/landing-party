"""A sheet's shadow cleared under its own body (the user, 2026-11-11, an annotated still of Grubstake's gun nest: the
plate darker under the box than its top strip, its sandbags dark grey in game where the sprite's are light tan). A
turret's base layers draw in order, its shadow over its body: the base's shadow, the ground under the plate solid since
0.2.333, was laid on the turret. Vanilla's base shadows (laser, flamethrower) are cut where their body stands; these are
now too: each frame's shadow cleared where its body's alpha is over 128.

    uv run --with pillow --with numpy python tools/blender/shadow_underbody.py <sheet dir | body.png:shadow.png>...
(a gun's base: base.png:base_shadow.png)
"""
import sys
import numpy as np
from PIL import Image

for d in sys.argv[1:]:
    bp, sp = d.split(":") if ":" in d else (f"{d}/body.png", f"{d}/shadow.png")
    body = np.asarray(Image.open(bp).convert("RGBA"))[..., 3]
    im = np.asarray(Image.open(sp).convert("RGBA")).copy()
    before = int((im[..., 3] > 0).sum())
    if body.shape != im.shape[:2]:
        # (A gun's sheets are cropped apart: gun.json's boxes place each in the render, gun_sheet.py.)
        import json, os
        g = json.load(open(os.path.join(os.path.dirname(sp), "gun.json")))
        kb, ks = os.path.basename(bp)[:-4], os.path.basename(sp)[:-4]
        ox, oy = g[kb]["box"][0] - g[ks]["box"][0], g[kb]["box"][1] - g[ks]["box"][1]
        ys, xs = np.nonzero(body > 128)
        X, Y = xs + ox, ys + oy
        ok = (X >= 0) & (X < im.shape[1]) & (Y >= 0) & (Y < im.shape[0])
        im[Y[ok], X[ok], 3] = 0
    else:
        im[..., 3][body > 128] = 0
    Image.fromarray(im, "RGBA").save(sp, optimize=True)
    print(f"{d}: shadow pixels {before} -> {int((im[..., 3] > 0).sum())}")
