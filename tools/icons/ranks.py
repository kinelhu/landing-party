"""The rank badges (veterancy.lua): one chevron for a Veteran, two for an Elite, three for a Hero, worn by the unit from
its promotion on (the turret-rank mods keep a badge on the entity; a label that faded left nothing to see). Gold on a
dark outline, so they read on sand, grass and snow, at the scale a unit is seen at.

    uv run --with pillow python tools/icons/ranks.py landing-party/graphics/icons/ranks
"""
import os, sys
from PIL import Image, ImageDraw

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
S, K = 64, 4          # the sprite's size, and the supersampling it is drawn at
GOLD, LIGHT, DARK = (232, 182, 58, 255), (255, 228, 140, 255), (28, 22, 12, 235)


def chevron(d, cx, top, w, h, t, fill, edge):
    """A chevron pointing up: its apex at (cx, top), arms w wide and h down, t thick."""
    pts = [(cx, top), (cx + w / 2, top + h), (cx + w / 2 - t, top + h), (cx, top + t * 1.15),
           (cx - w / 2 + t, top + h), (cx - w / 2, top + h)]
    pts = [(x * K, y * K) for x, y in pts]
    d.polygon(pts, fill=fill)
    if edge:
        d.line(pts + [pts[0]], fill=edge, width=int(2.2 * K), joint="curve")


for rank in (1, 2, 3):
    im = Image.new("RGBA", (S * K, S * K), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    w, h, t, gap = 40, 15, 7.5, 11
    total = h + (rank - 1) * gap
    top = (S - total) / 2
    tops = [top + i * gap for i in range(rank)]
    for y in tops:                       # outlines first, under every chevron
        chevron(d, S / 2, y, w, h, t, DARK, DARK)
    for y in tops:
        chevron(d, S / 2, y, w, h, t, GOLD, None)
        chevron(d, S / 2, y + 1.2, w - 9, h - 4, 2.2, LIGHT, None)   # a highlight along the upper edge
    im.resize((S, S), Image.LANCZOS).save(os.path.join(out, f"rank-{rank}.png"), optimize=True)
print("3 rank badges")
