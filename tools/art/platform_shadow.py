"""The orbital platform's shadow (the user, 2026-11-04: its three flat strips "Yes" to a real silhouette): a ship seen
from below, long along its course (north in the image), a tapered bow, a ribbed hull, three engine bells, two solar wings
in panels, a radiator cross and an antenna mast; softened at the edges, as a shadow from high up is. White on alpha: the
game tints it dark (orbital.lua).

    uv run --with pillow python tools/art/platform_shadow.py landing-party/graphics/serenity/platform-shadow.png
"""
import sys
from PIL import Image, ImageDraw, ImageFilter

W, H = 512, 640                     # 8 px a tile: 64 tiles across the wings, 80 long
im = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(im)
cx = W // 2
def rect(xa, xb, y0, y1): d.rectangle([min(xa, xb), y0, max(xa, xb), y1], fill=255)
# The hull: bow tapered to a point, the body, ribs gapped across it.
d.polygon([(cx, 40), (cx + 40, 130), (cx + 46, 520), (cx - 46, 520), (cx - 40, 130)], fill=255)
for y in range(170, 500, 46):
    d.rectangle([cx - 52, y, cx + 52, y + 10], fill=255)            # ribs proud of the hull
# Engine bells at the stern.
for ox in (-28, 0, 28):
    d.polygon([(cx + ox - 10, 520), (cx + ox + 10, 520), (cx + ox + 16, 575), (cx + ox - 16, 575)], fill=255)
# Two solar wings on booms, in panels with gaps.
for side in (-1, 1):
    x0 = cx + side * 46
    rect(x0, x0 + side * 34, 300, 312)                                  # boom
    for k in range(4):
        px0 = x0 + side * (34 + k * 46)
        rect(px0, px0 + side * 42, 240, 372)
# A radiator cross forward, fins.
for side in (-1, 1):
    for k in range(3):
        x = cx + side * (52 + k * 20)
        rect(x, x + side * 14, 150, 200)
# An antenna mast off the bow.
d.line([(cx, 40), (cx, 4)], fill=255, width=4)
d.line([(cx - 18, 18), (cx + 18, 18)], fill=255, width=3)
im = im.filter(ImageFilter.GaussianBlur(5))
out = Image.new("RGBA", (W, H), (255, 255, 255, 0))
out.putalpha(im)
out.save(sys.argv[1], optimize=True)
print("written", sys.argv[1], W, H)
