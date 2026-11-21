"""The ammunition tiers' order icons (0.2.481; shared.ORDER_TIERS): each its unit's icon with its round's badge on a dark
disc, as cut.py badges the base orders (the tiers had copied their base order's vanilla icon: player.lua makes them
before icons.lua sets the mod's own). From the unit icons (graphics/icons/units, 64 px) and vanilla's round icons.

    uv run --with pillow --with numpy python3 -I tools/icons/tiers.py
"""
import os, re
import numpy as np
from PIL import Image, ImageFilter, ImageDraw
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ICONS = os.path.join(REPO, "landing-party", "graphics", "icons")
APP = os.path.expanduser("~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/data/base/graphics/icons")
src = open(os.path.join(REPO, "landing-party", "shared.lua")).read()
block = src[src.index("shared.ORDER_TIERS = {"):]
block = block[:block.index("\n}\n")]
TIERS = re.findall(r'\["(lp-[a-z-]+)"\] = \{base = "(lp-[a-z-]+)-order", round = "([a-z-]+)"', block)
assert len(TIERS) >= 8, TIERS


def square(im, pad=0.06):
    bb = im.split()[3].point(lambda v: 255 if v > 0 else 0).getbbox()
    im = im.crop(bb)
    s = int(max(im.size) * (1 + 2 * pad))
    sq = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sq.alpha_composite(im, ((s - im.width) // 2, (s - im.height) // 2))
    return sq


def badged(im, badge, at=0.42):
    im = square(im, pad=0.1)
    s = im.width
    b = Image.open(badge).convert("RGBA")
    b = b.crop((0, 0, min(b.size), min(b.size)))
    bs = int(s * at)
    disc = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(disc).ellipse((s - bs - 2, s - bs - 2, s - 2, s - 2), fill=(24, 24, 26, 230))
    im.alpha_composite(disc)
    b = b.resize((int(bs * 0.82), int(bs * 0.82)), Image.LANCZOS)
    im.alpha_composite(b, (s - bs - 2 + (bs - b.width) // 2, s - bs - 2 + (bs - b.height) // 2))
    return im


for name, unit, rnd in TIERS:
    body = Image.open(os.path.join(ICONS, "units", unit + ".png")).convert("RGBA").resize((256, 256), Image.LANCZOS)
    im = square(badged(body, os.path.join(APP, rnd + ".png")))
    im.resize((64, 64), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=0.8, percent=60, threshold=2)).save(
        os.path.join(ICONS, name + ".png"), optimize=True)
print(len(TIERS), "tier icons")
