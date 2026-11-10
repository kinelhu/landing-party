"""The mod's item icons (the user, 2026-11-10: every item, recipe and technology reused a vanilla icon; "Do all"): each
item's picture from what shows it best, cut to a square on transparency, written at 64 px (an icon) and 256 px (a source
for the technologies' icons, tools/icons/techs.py).
  buildings  the icon film (docs/release/icons-film.lua): the entity's own sprite, difference-matted (a dark and a white
             still), its shadow dropped (vanilla's icons have none)
  orders     their unit's cut-out (docs/manual/shots/matte.py), its shadow dropped
  components the Blender renders (tools/blender/component_icons.py); a schematic: the blueprint with its part in a corner
  the cannon and the targeting array: their own sprites (platform only, not in the film)

    uv run --with pillow --with numpy python tools/icons/cut.py <icon film dir> <component renders> <unit cut-outs> <out dir>
Fails on an item it has no source for.
"""
import glob, os, sys
import numpy as np
from PIL import Image, ImageFilter

film, comps, units, out = sys.argv[1:5]
REPO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
os.makedirs(os.path.join(out, "src"), exist_ok=True)


def load(f):
    return np.asarray(Image.open(f).convert("RGB")).astype(np.float32)


def ground(kind):
    return np.median(load(os.path.join(film, f"ground-{kind}.png")).reshape(-1, 3), axis=0)


DBG, WBG = ground("dark"), ground("white")
SPAN = np.maximum(1.0, WBG - DBG)


def matte(dark, white):
    a = 1 - np.clip(((white - dark) / SPAN).mean(axis=2), 0, 1)
    a = np.where(a < 0.03, 0, a)
    col = (dark - (1 - a[..., None]) * DBG) / np.maximum(a[..., None], 1e-3)
    return np.dstack([np.clip(col, 0, 255), a * 255]).astype(np.uint8)


def unshadow(rgba):
    """A shadow is see-through and near black: gone. The body's own soft edges keep their colour, and stay."""
    a = rgba[..., 3].astype(np.float32) / 255
    dark = rgba[..., :3].max(axis=2) < 40
    keep = ~(dark & (a < 0.92))
    out = rgba.copy()
    out[..., 3] = np.where(keep, rgba[..., 3], 0)
    return out


def square(im, pad=0.06, thr=0):
    """Cropped to what is there (alpha over thr: a unit's faint shadow rim had widened its box, the order icons tiny),
    centred in a square with a margin."""
    bb = im.split()[3].point(lambda v: 255 if v > thr else 0).getbbox()
    im = im.crop(bb)
    s = int(max(im.size) * (1 + 2 * pad))
    sq = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sq.alpha_composite(im, ((s - im.width) // 2, (s - im.height) // 2))
    return sq


def write(name, im, thr=0):
    im = square(im, thr=thr)
    im.resize((256, 256), Image.LANCZOS).save(os.path.join(out, "src", name + ".png"))
    small = im.resize((64, 64), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=0.8, percent=60, threshold=2))
    small.save(os.path.join(out, name + ".png"), optimize=True)


done = []
# Buildings, from the film.
for d in sorted(glob.glob(os.path.join(film, "lp-*-dark.png"))):
    name = os.path.basename(d)[:-len("-dark.png")]
    w = d.replace("-dark.png", "-white.png")
    m = unshadow(matte(load(d), load(w)))
    write(name, Image.fromarray(m, "RGBA"), thr=120); done.append(name)
# Orders, from their units.
ORDERS = {"lp-trooper-order": "lp-trooper", "lp-breacher-order": "lp-breacher", "lp-rocket-trooper-order": "lp-rocket-trooper",
          "lp-flame-trooper-order": "lp-flame-trooper", "lp-battle-tank-order": "lp-battle-tank"}
for item, unit in ORDERS.items():
    src = os.path.join(units, unit + ".png")
    write(item, Image.fromarray(unshadow(np.asarray(Image.open(src).convert("RGBA"))), "RGBA"), thr=200); done.append(item)
# Components, from the renders.
COMP = {"lp-command-core": "command-core", "lp-pheromone-gland": "pheromone-gland", "lp-pacifier-crystal": "pacifier-crystal",
        "lp-drill-head": "drill-head", "lp-rail-coil": "rail-coil", "lp-cluster-fuze": "cluster-fuze",
        "lp-orbital-beacon": "orbital-beacon", "lp-orbital-shell": "orbital-shell", "lp-targeting-core": "targeting-core",
        "lp-defoliant": "defoliant", "lp-mortar-shell": "mortar-shell", "lp-rail-slug": "rail-slug",
        "lp-cluster-artillery-shell": "cluster-artillery-shell", "lp-rail-rifle": "rail-rifle"}
for item, f in COMP.items():
    write(item, Image.open(os.path.join(comps, f + ".png")).convert("RGBA")); done.append(item)
# Schematics: the blueprint, its part over its lower right.
SCHEM = {"lp-gland-schematic": "pheromone-gland", "lp-crystal-schematic": "pacifier-crystal", "lp-coil-schematic": "rail-coil",
         "lp-beacon-schematic": "orbital-beacon", "lp-fuze-schematic": "cluster-fuze"}
base = square(Image.open(os.path.join(comps, "schematic.png")).convert("RGBA")).resize((512, 512), Image.LANCZOS)
for item, part in SCHEM.items():
    im = base.copy()
    p = square(Image.open(os.path.join(comps, part + ".png")).convert("RGBA")).resize((300, 300), Image.LANCZOS)
    im.alpha_composite(p, (512 - 300 - 4, 512 - 300 - 4))
    write(item, im); done.append(item)
# The cannon and the array, from their sprites (the cannon's body with its barrel laid on, north).
oc = os.path.join(REPO, "landing-party", "graphics", "player", "orbital-cannon")
body = Image.open(os.path.join(oc, "north-body.png")).convert("RGBA")
import json
meta = json.load(open(os.path.join(oc, "dirs.json")))["north"]
br = Image.open(os.path.join(oc, "north-barrel.png")).convert("RGBA")
canvas = Image.new("RGBA", body.size, (0, 0, 0, 0)); canvas.alpha_composite(body)
bx = int((meta["barrel"]["shift"][0] - meta["shift"][0]) * 64 + body.width / 2 - br.width / 2)
by = int((meta["barrel"]["shift"][1] - meta["shift"][1]) * 64 + body.height / 2 - br.height / 2)
canvas.alpha_composite(br, (bx, by))
# (Its breech, towers and first coils: whole, at 64 px it was a stick.)
cb = canvas.getbbox()
canvas = canvas.crop((cb[0], cb[1] + int((cb[3] - cb[1]) * 0.38), cb[2], cb[3]))
write("lp-orbital-cannon", canvas); done.append("lp-orbital-cannon")
# Stand-ins: the bait is a splat on the ground (its item: the gland it is made of); the retired strike beacon's sprite is
# its charge's sparks (its item: the orbital beacon it was built round).
for item, like in (("lp-bait", "pheromone-gland"), ("lp-strike-beacon", "orbital-beacon")):
    write(item, Image.open(os.path.join(comps, like + ".png")).convert("RGBA")); done.append(item)
ta = os.path.join(REPO, "landing-party", "graphics", "player", "targeting-array")
tm = json.load(open(os.path.join(ta, "sheet.json")))
sheet = Image.open(os.path.join(ta, "body.png")).convert("RGBA")
write("lp-targeting-array", sheet.crop((0, 0, tm["width"], tm["height"]))); done.append("lp-targeting-array")
print(len(done), "icons:", ", ".join(sorted(done)))
