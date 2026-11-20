"""depot_clay.py's renders composited at game scale (64 px a tile, hr) beside vanilla's requester and steel chests, on
grass-1 and sand-1 from the game's data: <name>-grass.png, <name>-desert.png, each also x3 (nearest) for a close look,
and all.png, every candidate on both grounds.

    uv run --with pillow python tools/blender/depot_clay_sheet.py <render dir> <out dir>
"""
import math, os, sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
APP = os.path.expanduser("~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents")
G = f"{APP}/data/base/graphics"
T = 64
COLS, ROWS = 7, 3
SHADOW = 0.5   # how dark the game draws a shadow sprite (approximate)


def ground(tile):
    sheet = Image.open(f"{G}/terrain/{tile}.png").convert("RGBA")
    # The 4x4-tile variants: the sheet's last 256 px band.
    band = sheet.crop((0, sheet.height - 256, sheet.width, sheet.height))
    g = Image.new("RGBA", (COLS * T, ROWS * T))
    for i in range(0, COLS * T, 256):
        g.paste(band.crop((i * 2 % band.width, 0, i * 2 % band.width + 256, 256)), (i, 0))
    return g.crop((0, 0, COLS * T, ROWS * T))


def shadow_layer(path, box=None):
    im = Image.open(path).convert("RGBA")
    if box: im = im.crop(box)
    a = im.split()[3].point(lambda v: int(v * SHADOW))
    s = Image.new("RGBA", im.size, (0, 0, 0, 255)); s.putalpha(a)
    return s


def put(canvas, im, cx, cy, shift=(0, 0)):
    canvas.alpha_composite(im, (int(round(cx - im.width / 2 + shift[0])), int(round(cy - im.height / 2 + shift[1]))))


def vanilla(canvas, kind, cx, cy):
    # util.by_pixel at scale 0.5: a by_pixel unit is 2 px here.
    if kind == "requester":
        put(canvas, shadow_layer(f"{G}/entity/logistic-chest/logistic-chest-shadow.png"), cx, cy, (24, 9))
        body = Image.open(f"{G}/entity/logistic-chest/requester-chest.png").convert("RGBA").crop((0, 0, 66, 74))
        put(canvas, body, cx, cy, (0, -4))
    else:
        put(canvas, shadow_layer(f"{G}/entity/steel-chest/steel-chest-shadow.png"), cx, cy, (24.5, 16))
        put(canvas, Image.open(f"{G}/entity/steel-chest/steel-chest.png").convert("RGBA"), cx, cy, (-0.5, -1))


def ours(path):
    im = Image.open(path).convert("RGBA")
    im.putalpha(im.split()[3].point(lambda v: v if v > 12 else 0))
    return im.resize((im.width, int(round(im.height * math.sqrt(2)))), Image.LANCZOS)


names = sorted(os.path.splitext(n)[0] for n in os.listdir(src) if n.endswith(".png"))
grounds = {"grass": ground("grass-1"), "desert": ground("sand-1")}
tiles = []
for n in names:
    for gname, g in grounds.items():
        c = g.copy()
        y = 1.5 * T
        vanilla(c, "requester", 1.5 * T, y)
        put(c, ours(f"{src}/{n}.png"), 3.5 * T, y)
        vanilla(c, "steel", 5.5 * T, y)
        c.save(f"{out}/{n}-{gname}.png")
        c.resize((c.width * 3, c.height * 3), Image.NEAREST).save(f"{out}/{n}-{gname}-x3.png")
        tiles.append(c)
W, H = COLS * T, ROWS * T
sheet = Image.new("RGBA", (W * 2, H * len(names)), (0, 0, 0, 255))
for i, c in enumerate(tiles):
    sheet.paste(c, ((i % 2) * W, (i // 2) * H))
sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(f"{out}/all-x2.png")
sheet.save(f"{out}/all.png")
print("wrote", len(tiles), "composites to", out)
