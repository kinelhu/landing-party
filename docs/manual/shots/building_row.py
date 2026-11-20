"""The army chapter's row of your army buildings (the user, 2026-11-21: "Shouldn't we show buildings?", then "Good"): the
barracks, the supply depot, the command relay and the rally beacon side by side at one scale (matte.py's cut-outs, one
px a tile for all), standing on one ground line, on the manual's paper, each named from the locale (entity-name) under
the building itself, not its shadow.

    scripts/film.sh gallery fresh.zip docs/manual/shots/buildings-matte.lua docs/sim/film-buildings
    scripts/film.sh gallery fresh.zip docs/manual/shots/buildings-matte-beacon.lua docs/sim/film-beacon
    (the rally beacon alone: its hold ring crossed the relays' frames and the cut lost them)
    uv run --with pillow --with numpy python docs/manual/shots/matte.py docs/sim/film-buildings <tmp>/b
    uv run --with pillow --with numpy python docs/manual/shots/matte.py docs/sim/film-beacon <tmp>/bb
    uv run --with pillow --with numpy python docs/manual/shots/building_row.py <tmp>/b <tmp>/bb docs/manual/media/buildings/army.png
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
FONT = os.path.join(REPO, "docs", "manual", "_extensions", "lp-manual", "fonts", "TitilliumWeb-SemiBold.ttf")
names, sec = {}, None
for line in open(os.path.join(REPO, "landing-party", "locale", "en", "locale.cfg"), encoding="utf-8"):
    line = line.rstrip("\n")
    if line.startswith("["): sec = line.strip("[]")
    elif "=" in line and sec == "entity-name":
        k, v = line.split("=", 1); names.setdefault(k, v)
B, BB, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
ITEMS = [(B, "lp-barracks"), (B, "lp-supply-depot"), (B, "lp-command-relay"), (BB, "lp-rally-beacon")]
PAPER, PAPER_DARK = (0xF5, 0xF0, 0xE6), (0xE7, 0xDF, 0xD0)
ims = [(Image.open(os.path.join(d, "cutouts", n + ".png")).convert("RGBA"), names[n]) for d, n in ITEMS]
import numpy as np
def clean(im):
    # (Matting leftovers: faint, light pixels round a building, where its two grounds' stills differed by a light's glow.
    # A shadow is dark and kept; a faint light pixel goes.)
    a = np.asarray(im).astype(np.float32)
    lum = a[:, :, :3].mean(axis=2)
    halo = ((a[:, :, 3] < 150) & (lum > 95)) | (a[:, :, 3] < 32)   # (and the faintest veil: a light's glow, alpha ~13)
    a[halo, 3] = 0
    return Image.fromarray(a.astype(np.uint8), "RGBA")
ims = [(clean(im), label) for im, label in ims]
ims = [(im.crop(im.getbbox()), label) for im, label in ims]
def body_centre(im):
    # (The label under the building, not under it and its shadow: the centre of its opaque pixels.)
    a = np.asarray(im)[:, :, 3]
    cols = np.where((a > 220).sum(axis=0) > 0)[0]
    return (cols.min() + cols.max()) / 2 if len(cols) else im.width / 2
GAP, PAD, LABEL = 70, 50, 90
base = max(im.height for im, _ in ims)
W = sum(im.width for im, _ in ims) + GAP * (len(ims) - 1) + 2 * PAD
H = base + LABEL + 2 * PAD
out = Image.new("RGB", (W, H), PAPER)
# A soft vignette of the paper, as the portraits have.
vig = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(vig)
for k in range(60):
    d.rectangle([k * 3, k * 3, W - k * 3, H - k * 3], outline=int(255 * (1 - k / 60)))
out = Image.composite(Image.new("RGB", (W, H), PAPER_DARK), out, vig.point(lambda v: int(v * 0.6)))
font = ImageFont.truetype(FONT, 46)
draw = ImageDraw.Draw(out)
x = PAD
for im, label in ims:
    y = PAD + base - im.height   # bottoms aligned: all stand on one ground line
    out.paste(im, (x, y), im)
    tw = draw.textlength(label, font=font)
    draw.text((x + body_centre(im) - tw / 2, PAD + base + 24), label, fill=(0x3A, 0x36, 0x30), font=font)
    x += im.width + GAP
out.save(OUT)
print(OUT, out.size)
