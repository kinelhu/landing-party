"""Cut the manual's unit portraits from the portraits film (docs/manual/shots/portraits.lua).

    uv run --with pillow --with numpy python docs/manual/shots/portraits.py <film dir> docs/manual/media/portraits

For each unit, of its stills at three zooms the closest that holds the unit and its shadow clear of the frame's edge;
a square round them, the unit centred, scaled to SIDE px; the flat lab ground (and the shadow on it) lifted to a soft
vignette, the unit itself untouched. Prints each unit's zoom and crop, and fails on a unit with no still.
"""
import glob, os, sys
import numpy as np
from PIL import Image

SIDE = 760
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
ground = np.asarray(Image.open(glob.glob(os.path.join(src, "ground-z3.png"))[0]).convert("RGB")).astype(np.float32)
BG = np.median(ground.reshape(-1, 3), axis=0)
print("ground", BG)


def masks(a):
    d = np.abs(a - BG).max(axis=2)
    lum, blum = a.mean(axis=2), BG.mean()
    chroma = a.max(axis=2) - a.min(axis=2)
    shadow = (d > 5) & (lum < blum - 2) & (chroma < 7)
    body = (d > 5) & ~shadow
    # (Specks: a body pixel needs body pixels near it.)
    return body, shadow


def bbox(m):
    ys, xs = np.nonzero(m)
    if len(xs) < 30:
        return None
    # Robust: the 0.3 and 99.7 percentiles, so a stray pixel does not stretch the box.
    return (np.percentile(xs, 0.3), np.percentile(ys, 0.3), np.percentile(xs, 99.7), np.percentile(ys, 99.7))


names = sorted({os.path.basename(f).rsplit("-z", 1)[0] for f in glob.glob(os.path.join(src, "lp-*.png"))})
missing = []
for n in names:
    stills = sorted(glob.glob(os.path.join(src, n + "-z*.png")),
                    key=lambda f: -float(f.rsplit("-z", 1)[1][:-4].replace("p", ".")))
    pick = None
    for f in stills:   # closest first
        a = np.asarray(Image.open(f).convert("RGB")).astype(np.float32)
        body, shadow = masks(a)
        bb = bbox(body)
        if bb is None:
            continue
        allb = bbox(body | shadow)
        H, W = body.shape
        # The square: centred on the unit's body, round it with a margin and as much of its shadow as fits in 1.6
        # times the body's own half-size (a trooper's shadow runs long to the east; a drone's lies far below it).
        cx, cy = (bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2
        bhalf = max(bb[2] - bb[0], bb[3] - bb[1]) / 2
        shalf = max(cx - allb[0], allb[2] - cx, cy - allb[1], allb[3] - cy)
        half = max(bhalf * 1.3, min(shalf * 1.05, bhalf * 1.6)) + 10
        # (No square under 600 px: a drone's sprite is small, and blown up to the portrait it showed its pixels.)
        half = max(half, 300)
        if cx - half >= 0 and cy - half >= 0 and cx + half <= W and cy + half <= H:
            pick = (f, a, body, cx, cy, half)
            break
        # (Widest still, last: the square clamped to the frame. The stomper walks off its mark.)
        if f == stills[-1]:
            half = min(half, cx, cy, W - cx, H - cy)
            if half > bhalf:
                pick = (f, a, body, cx, cy, half)
    if pick is None:
        missing.append(n)
        print("NO PORTRAIT", n)
        continue
    f, a, body, cx, cy, half = pick
    x0, y0 = int(cx - half), int(cy - half)
    s = int(2 * half)
    crop = a[y0:y0 + s, x0:x0 + s]
    bm = body[y0:y0 + s, x0:x0 + s]
    # The vignette: the ground (and the shadow on it) scaled from 1.35 at the centre to 0.85 in the corners.
    yy, xx = np.mgrid[0:s, 0:s]
    r = np.sqrt((xx - s / 2) ** 2 + (yy - s / 2) ** 2) / (s / 2 * 1.414)
    g = 1.35 - 0.5 * r ** 1.5
    lifted = np.clip(crop * g[..., None], 0, 255)
    res = np.where(bm[..., None], crop, lifted).astype(np.uint8)
    im = Image.fromarray(res).resize((SIDE, SIDE), Image.LANCZOS)
    dst = os.path.join(out, n + ".png")
    im.save(dst, optimize=True)
    print(f"{n}: {os.path.basename(f)} crop {s}px at {x0},{y0} -> {dst} ({os.path.getsize(dst) // 1024} KB)")
if missing:
    sys.exit("no portrait for: " + ", ".join(missing))
