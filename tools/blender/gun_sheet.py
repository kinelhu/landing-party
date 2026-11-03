"""kh_guns.py's renders to Factorio sheets: base.png and base_shadow.png (one frame each), and the cannon's barrel,
housing and shadow sheets (N directions, 8 a row), all stretched by sqrt(2); each set cropped to its union; gun.json
with every sheet's frame size and shift (tiles at 64 px a tile).

    uv run --with pillow python tools/blender/gun_sheet.py <renders dir> <out dir> [preview.png|-] [like gun.json]
"""
import json, math, os, sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
prev = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] != "-" else None
# Another corporation's renders of the same gun take the first one's crops (its gun.json): the prototype is sized once,
# and shadows differing by a pixel had made Grubstake's sheets another size.
like = json.load(open(sys.argv[4])) if len(sys.argv) > 4 else None
def load(p, shadow=False):
    im = Image.open(p).convert("RGBA"); im = im.resize((im.width, int(im.height * math.sqrt(2))), Image.LANCZOS)
    im.putalpha(im.split()[3].point((lambda v: int(v * 0.55) if v > 12 else 0) if shadow else (lambda v: v if v > 3 else 0)))
    return im
def union(ims):
    box = None
    for im in ims:
        b = im.getbbox()
        if b: box = b if not box else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    return (box[0] - 2, box[1] - 2, box[2] + 2, box[3] + 2)
os.makedirs(out, exist_ok=True)
meta = {}
def write(name, ims, box, W, H):
    if like:
        box = tuple(like[name]["box"])
    fw, fh = box[2] - box[0], box[3] - box[1]
    if len(ims) == 1:
        ims[0].crop(box).save(f"{out}/{name}.png", optimize=True)
    else:
        rows = math.ceil(len(ims) / 8)
        sh = Image.new("RGBA", (fw * 8, fh * rows), (0, 0, 0, 0))
        for i, im in enumerate(ims): sh.paste(im.crop(box), ((i % 8) * fw, (i // 8) * fh))
        sh.save(f"{out}/{name}.png", optimize=True)
    meta[name] = {"width": fw, "height": fh, "count": len(ims), "box": list(box),
                  "shift": [((box[0] + box[2]) / 2 - W / 2) / 64, ((box[1] + box[3]) / 2 - H / 2) / 64]}
base, bshadow = load(f"{src}/base.png"), load(f"{src}/base_shadow.png", True)
W, H = base.size
write("base", [base], union([base]), W, H)
write("base_shadow", [bshadow], union([bshadow]), W, H)
names = sorted(os.listdir(f"{src}/barrel"))
barrel = [load(f"{src}/barrel/{n}") for n in names]
housing = [load(f"{src}/housing/{n}") for n in names]
cshadow = [load(f"{src}/cshadow/{n}", True) for n in names]
cbox = union(barrel + housing)
write("barrel", barrel, cbox, W, H)
write("housing", housing, cbox, W, H)
write("cannon_shadow", cshadow, union(cshadow), W, H)
json.dump(meta, open(f"{out}/gun.json", "w"), indent=1); print(json.dumps(meta))
if prev:
    picks = [0, len(names) // 8, len(names) // 4, 3 * len(names) // 8, len(names) // 2, 5 * len(names) // 8, 3 * len(names) // 4]
    strip = Image.new("RGBA", (W * len(picks), H), (96, 82, 62, 255))
    for i, d in enumerate(picks):
        fr = Image.new("RGBA", (W, H), (96, 82, 62, 255))
        for im in (bshadow, cshadow[d], base, barrel[d], housing[d]): fr.alpha_composite(im)
        strip.paste(fr, (i * W, 0))
    strip.resize((strip.width // 2, strip.height // 2)).save(prev); print("preview", prev)
