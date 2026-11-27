"""workshop_clay.py's renders composited at game scale (64 px a tile, hr) beside vanilla's lab and Grubstake's own
fabricator (its first frame and shadow), on grass-1 and sand-1 from the game's data: <name>-grass.png, <name>-desert.png,
each also x2 (nearest) for a close look, and all.png, every candidate on both grounds.

    uv run --with pillow python tools/blender/workshop_clay_sheet.py <render dir> <out dir>
"""
import json, math, os, sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
APP = os.path.expanduser("~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents")
G = f"{APP}/data/base/graphics"
T = 64
COLS, ROWS = 14, 6
SHADOW = 0.5   # how dark the game draws a shadow sprite (approximate)


def ground(tile):
    # (The sheet's 1x1 variants, its top row, laid at random: its larger bands carry transitions and read as dark
    # blocks behind the candidates.)
    import random
    sheet = Image.open(f"{G}/terrain/{tile}.png").convert("RGBA")
    rnd = random.Random(1)
    full = [(k * T, r * T) for r in range(sheet.height // T) for k in range(sheet.width // T)
            if sheet.crop((k * T, r * T, k * T + T, r * T + T)).split()[3].getextrema()[0] == 255]
    g = Image.new("RGBA", (COLS * T, ROWS * T))
    for i in range(COLS):
        for j in range(ROWS):
            x, y = rnd.choice(full)
            g.paste(sheet.crop((x, y, x + T, y + T)), (i * T, j * T))
    return g


def shadow_of(im):
    a = im.split()[3].point(lambda v: int(v * SHADOW))
    s = Image.new("RGBA", im.size, (0, 0, 0, 255)); s.putalpha(a)
    return s


def put(canvas, im, cx, cy, shift=(0, 0)):
    canvas.alpha_composite(im, (int(round(cx - im.width / 2 + shift[0])), int(round(cy - im.height / 2 + shift[1]))))


def lab(canvas, cx, cy):
    # util.by_pixel at scale 0.5: a by_pixel unit is 2 px here.
    put(canvas, shadow_of(Image.open(f"{G}/entity/lab/lab-shadow.png").convert("RGBA")), cx, cy, (26, 22))
    put(canvas, Image.open(f"{G}/entity/lab/lab.png").convert("RGBA").crop((0, 0, 194, 174)), cx, cy, (0, 3))


def fabricator(canvas, cx, cy):
    d = f"{REPO}/landing-party-graphics/graphics/grubstake/fabricator"
    j = json.load(open(f"{d}/sheet.json"))
    w, h, sh = j["width"], j["height"], j["shift"]
    shift = (sh[0] * T, sh[1] * T)
    put(canvas, shadow_of(Image.open(f"{d}/shadow.png").convert("RGBA")), cx, cy, shift)
    put(canvas, Image.open(f"{d}/body.png").convert("RGBA").crop((0, 0, w, h)), cx, cy, shift)


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
        y = 3.2 * T
        lab(c, 2.2 * T, y)
        put(c, ours(f"{src}/{n}.png"), 6.6 * T, y)
        fabricator(c, 11.2 * T, y)
        c.save(f"{out}/{n}-{gname}.png")
        c.resize((c.width * 2, c.height * 2), Image.NEAREST).save(f"{out}/{n}-{gname}-x2.png")
        tiles.append(c)
W, H = COLS * T, ROWS * T
sheet = Image.new("RGBA", (W * 2, H * len(names)), (0, 0, 0, 255))
for i, c in enumerate(tiles):
    sheet.paste(c, ((i % 2) * W, (i // 2) * H))
sheet.save(f"{out}/all.png")
print("wrote", len(tiles), "composites to", out)
