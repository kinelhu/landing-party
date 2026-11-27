"""The units' own icons, 64 px (the user, 2026-11-10: "did you make icons for enemy units too? Those are going to show up
in the threat scanner, no?"): every unit of every faction from its cut-out (docs/manual/shots/matte.py, from the matte
films docs/manual/shots/portraits-matte.lua (the gun buggy's alone, 0.2.481), docs/release/units-extra-matte.lua and walkers-matte.lua), its shadow
dropped as cut.py drops it, squared on transparency. A unit's resistance variants (-fire, -laser, -physical) take their
base unit's (icons.lua). Written to landing-party-graphics/graphics/icons/units/<unit>.png.

    uv run --with pillow --with numpy python tools/icons/units.py <cut-outs dir>... <out dir>
Fails on a unit it has no cut-out for (UNITS: the mod's base units, as the dump lists them).
"""
import os, sys
import numpy as np
from PIL import Image, ImageFilter

*srcs, out = sys.argv[1:]
os.makedirs(out, exist_ok=True)
UNITS = """lp-aegis lp-battle-tank lp-breacher lp-bred-behemoth-biter lp-bred-big-biter lp-bred-big-burster lp-bred-carrier
lp-bred-cinder lp-bred-medium-biter lp-bred-medium-spitter lp-bred-scout lp-bred-small-biter lp-bred-spore lp-bred-stomper
lp-buggy lp-constructor lp-dozer lp-gun-buggy lp-flak-buggy lp-flame-trooper lp-grubstake-aegis lp-grubstake-buggy lp-grubstake-dozer
lp-grubstake-flak-buggy lp-grubstake-harrier lp-grubstake-hauler lp-grubstake-howitzer-truck lp-grubstake-infantry
lp-grubstake-lance lp-grubstake-laser-drone lp-grubstake-prism lp-grubstake-railgunner lp-grubstake-sapper
lp-grubstake-scavenger lp-grubstake-scorcher lp-grubstake-shock lp-grubstake-skyguard lp-grubstake-slug lp-grubstake-tank
lp-grubstake-tesla lp-grubstake-walker lp-harrier lp-hauler lp-howitzer-truck lp-infantry lp-lance lp-laser-drone lp-prism
lp-railgunner lp-rocket-trooper lp-runt lp-sapper lp-scavenger lp-scorcher lp-shock lp-shotgun-hand lp-skyguard lp-slug
lp-sweeper lp-tank lp-technician lp-tesla lp-trooper lp-walker""".split()


def unshadow(rgba):
    """(cut.py's: a shadow is see-through and near black; and grey, here: the stomper's dark purple legs, see-through at
    their edges, had gone with it and left a ghost.)"""
    a = rgba[..., 3].astype(np.float32) / 255
    c = rgba[..., :3].astype(np.int16)
    grey = (c.max(axis=2) - c.min(axis=2)) < 14
    keep = ~((c.max(axis=2) < 40) & grey & (a < 0.92))
    o = rgba.copy()
    o[..., 3] = np.where(keep, rgba[..., 3], 0)
    return o


def keyed(rgba):
    """The stomper's cut-out (the first matte film's) has its body near see-through and its shadow near opaque: right
    only laid on the dark ground it was filmed on. Laid there, then keyed on what a shadow is not: colour, or light."""
    bg = Image.new("RGBA", (rgba.shape[1], rgba.shape[0]), (49, 48, 49, 255))
    bg.alpha_composite(Image.fromarray(rgba, "RGBA"))
    c = np.asarray(bg.convert("RGB")).astype(np.int16)
    body = ((c.max(axis=2) - c.min(axis=2)) >= 14) | (c.max(axis=2) > 80)
    return np.dstack([c.astype(np.uint8), np.where(body, 255, 0).astype(np.uint8)])


KEYED = {"lp-bred-stomper"}
missing = []
for u in UNITS:
    f = next((os.path.join(d, u + ".png") for d in srcs if os.path.exists(os.path.join(d, u + ".png"))), None)
    im = f and Image.fromarray((keyed if u in KEYED else unshadow)(np.asarray(Image.open(f).convert("RGBA"))), "RGBA")
    bb = im and im.split()[3].point(lambda v: 255 if v > 200 else 0).getbbox()
    if not bb:
        missing.append(u); continue
    im = im.crop(bb)
    s = int(max(im.size) * 1.08)
    sq = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sq.alpha_composite(im, ((s - im.width) // 2, (s - im.height) // 2))
    small = sq.resize((64, 64), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=0.8, percent=60, threshold=2))
    small.save(os.path.join(out, u + ".png"), optimize=True)
if missing:
    sys.exit("no cut-out for " + " ".join(missing))
print(len(UNITS), "unit icons")
