"""The landers' review pictures (landers.py): the clay concept sheet, and a rendered lander beside vanilla's crash-site
ship, Space Age's cargo landing pad and the rocket silo on grass and on desert at 64 px a tile (the game's own pixels),
with full-size crops; judged there, never on a grey preview (the user, 2026-11-10, of the first cannon).

    uv run --with pillow python tools/blender/lander_sheets.py concepts <out.png> <label=render.png> ...
    uv run --with pillow python tools/blender/lander_sheets.py compare "$APP" <sheet dir> <out dir> <label>
"""
import math, os, re, sys
from PIL import Image, ImageDraw

PX = 64
SHADOW = 0.5          # every shadow layer drawn at half: vanilla's and ours alike (the game's own strength is its own)


def stretch(im):
    return im.resize((im.width, int(im.height * math.sqrt(2))), Image.LANCZOS)


def concepts(out, items):
    tiles = []
    for label, path in items:
        im = stretch(Image.open(path).convert("RGBA"))
        b = im.getbbox()
        im = im.crop((max(0, b[0] - 20), max(0, b[1] - 20), min(im.width, b[2] + 20), min(im.height, b[3] + 20)))
        tiles.append((label, im))
    W = max(im.width for _, im in tiles); H = max(im.height for _, im in tiles)
    cols = 3; rows = math.ceil(len(tiles) / cols)
    sheet = Image.new("RGBA", (cols * (W + 20) + 20, rows * (H + 50) + 20), (96, 82, 62, 255))
    dr = ImageDraw.Draw(sheet)
    for i, (label, im) in enumerate(tiles):
        x, y = 20 + (i % cols) * (W + 20), 20 + (i // cols) * (H + 50)
        sheet.alpha_composite(im, (x + (W - im.width) // 2, y + (H - im.height) // 2))
        dr.text((x + 6, y + H + 12), label, fill=(245, 238, 222, 255))
    sheet = sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS)
    sheet.save(out); print("wrote", out, sheet.size)


def lua_sprite(path):
    """A util.sprite_load's .lua beside its png: width, height, shift (by_pixel, normal-res pixels)."""
    t = open(path).read()
    w = int(re.search(r"width\s*=\s*(\d+)", t).group(1)); h = int(re.search(r"height\s*=\s*(\d+)", t).group(1))
    m = re.search(r"by_pixel\(\s*([-\d.]+)\s*,\s*([-\d.]+)", t)
    sx, sy = (float(m.group(1)) / 32, float(m.group(2)) / 32) if m else (0, 0)
    return w, h, (sx, sy)


def ground(app, kind, w, h):
    """A ground w by h pixels tiled from a terrain sheet's 4 by 4 variants (256 px at 64 a tile; the sheet's rows are
    the 1 by 1 at 0, the 2 by 2 at 64, the 4 by 4 at 320)."""
    sheet = Image.open(f"{app}/data/base/graphics/terrain/{kind}.png").convert("RGBA")
    g = Image.new("RGBA", (w, h))
    k = 0
    for y in range(0, h, 256):
        for x in range(0, w, 256):
            v = (k * 7) % 16; k += 1
            g.paste(sheet.crop((v * 256, 320, v * 256 + 256, 576)), (x, y))
    return g


def draw(canvas, cx, cy, img, shift, shadow=False, glow=False, scale=1.0):
    """A sprite layer centred at (cx, cy) pixels, shifted by its shift in tiles; the game draws these at scale 0.5 on a
    64 px tile, one sprite pixel a screen pixel."""
    if scale != 1.0:
        img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    if shadow:
        img = img.copy(); img.putalpha(img.split()[3].point(lambda v: int(v * SHADOW)))
    if glow:
        img = img.copy(); img.putalpha(img.split()[3].point(lambda v: int(v * 0.6)))
    canvas.alpha_composite(img, (int(cx + shift[0] * PX - img.width / 2), int(cy + shift[1] * PX - img.height / 2)))


def by_pixel(x, y):
    return (x / 32, y / 32)


def vanilla_ship(app, canvas, cx, cy):
    d = f"{app}/data/base/graphics/entity/crash-site-spaceship/"
    draw(canvas, cx, cy, Image.open(d + "spaceship-shadow.png").convert("RGBA"), by_pixel(-23, 50), shadow=True)
    draw(canvas, cx, cy, Image.open(d + "spaceship.png").convert("RGBA"), by_pixel(-13, 34))


def silo(app, canvas, cx, cy):
    d = f"{app}/data/base/graphics/entity/rocket-silo/"
    draw(canvas, cx, cy, Image.open(d + "00-rocket-silo-shadow.png").convert("RGBA"), by_pixel(20, -4), shadow=True)
    draw(canvas, cx, cy, Image.open(d + "01-rocket-silo-hole.png").convert("RGBA"), by_pixel(-5, 16))
    draw(canvas, cx, cy, Image.open(d + "04-door-back.png").convert("RGBA"), by_pixel(37, 12))
    draw(canvas, cx, cy, Image.open(d + "05-door-front.png").convert("RGBA"), by_pixel(-28, 33))
    draw(canvas, cx, cy, Image.open(d + "06-rocket-silo.png").convert("RGBA"), by_pixel(2, 3.5))
    draw(canvas, cx, cy, Image.open(d + "14-rocket-silo-front.png").convert("RGBA"), by_pixel(1, 78))


def pad(app, canvas, cx, cy):
    d = f"{app}/data/base/graphics/entity/cargo-hubs/hubs/"
    for name in ("planet-hub-shadow", "planet-hub-0-A", "planet-hub-0-B", "planet-hub-0-C", "planet-hub-0-D", "planet-hub-1-A",
                 "planet-hub-1-B", "planet-hub-1-C", "planet-hub-2", "planet-hub-3"):
        w, h, sh = lua_sprite(d + name + ".lua")
        im = Image.open(d + name + ".png").convert("RGBA").crop((0, 0, w, h))
        draw(canvas, cx, cy, im, (sh[0], sh[1] - 1), shadow="shadow" in name)


def ours(sheet_dir, canvas, cx, cy):
    import json
    m = json.load(open(f"{sheet_dir}/sheet.json"))
    w, h = m["width"], m["height"]
    def frame(name):
        p = f"{sheet_dir}/{name}.png"
        return Image.open(p).convert("RGBA").crop((0, 0, w, h)) if os.path.exists(p) else None
    sh = tuple(m["shift"])
    s = frame("shadow"); b = frame("body"); g = frame("glow")
    if s: draw(canvas, cx, cy, s, sh, shadow=True)
    if b: draw(canvas, cx, cy, b, sh)
    if g: draw(canvas, cx, cy, g, sh, glow=True)


def box(canvas, cx, cy, bb, colour=(255, 255, 255, 110)):
    dr = ImageDraw.Draw(canvas)
    (x0, y0), (x1, y1) = bb
    dr.rectangle([cx + x0 * PX, cy + y0 * PX, cx + x1 * PX, cy + y1 * PX], outline=colour, width=2)


def compare(app, sheet_dir, out, label):
    os.makedirs(out, exist_ok=True)
    TW, TH = 62, 19
    spots = {"ship": (11, 10), "ours": (30, 10), "pad": (44.5, 10), "silo": (55, 10)}
    for kind, name in (("grass-1", "grass"), ("sand-1", "desert")):
        for boxes in (False, True):
            canvas = ground(app, kind, TW * PX, TH * PX)
            # (Drawn in the game's order, by the entity's southern edge: all share a row here, the west first.)
            vanilla_ship(app, canvas, spots["ship"][0] * PX, spots["ship"][1] * PX)
            ours(sheet_dir, canvas, spots["ours"][0] * PX, spots["ours"][1] * PX)
            pad(app, canvas, spots["pad"][0] * PX, spots["pad"][1] * PX)
            silo(app, canvas, spots["silo"][0] * PX, spots["silo"][1] * PX)
            if boxes:
                box(canvas, spots["ship"][0] * PX, spots["ship"][1] * PX, ((-8.7, -3.3), (6.9, 4.5)))
                box(canvas, spots["ours"][0] * PX, spots["ours"][1] * PX, ((-8.7, -3.3), (6.9, 4.5)))
                box(canvas, spots["pad"][0] * PX, spots["pad"][1] * PX, ((-3.9, -3.9), (3.9, 3.9)))
                box(canvas, spots["silo"][0] * PX, spots["silo"][1] * PX, ((-4.4, -4.4), (4.4, 4.4)))
            dr = ImageDraw.Draw(canvas)
            for key, text in (("ship", "vanilla crash-site ship"), ("ours", label), ("pad", "cargo landing pad"), ("silo", "rocket silo")):
                dr.text((spots[key][0] * PX - 60, (TH - 1) * PX), text, fill=(245, 238, 222, 255))
            suffix = "-boxes" if boxes else ""
            canvas.convert("RGB").save(f"{out}/{label}-{name}{suffix}.jpg", quality=90)
            if not boxes:
                # Full-size crops: ours and vanilla's ship, 22 by 15 tiles each, the game's pixels.
                for key in ("ours", "ship"):
                    x, y = spots[key][0] * PX, spots[key][1] * PX
                    canvas.crop((int(x - 11.5 * PX), int(y - 8 * PX), int(x + 10.5 * PX), int(y + 7 * PX))).convert("RGB").save(
                        f"{out}/{label}-{name}-crop-{key}.jpg", quality=92)
                # The whole strip at the game's usual zoom (about 40 px a tile on the user's screen).
                z = canvas.resize((int(canvas.width * 0.6), int(canvas.height * 0.6)), Image.LANCZOS)
                z.convert("RGB").save(f"{out}/{label}-{name}-zoomed.jpg", quality=88)
    print("wrote", out)


def trim(sheet_dir):
    """A one-frame sheet cut to its frame: sheet.py packs 8 a row whatever the count, and a lander's frame 8 wide is
    12,000 px, past the engine's 8192 limit on a sprite's size. line_length becomes 1."""
    import json
    p = f"{sheet_dir}/sheet.json"; m = json.load(open(p))
    assert m["frames"] == 1, m
    for name in ("body", "glow", "shadow"):
        f = f"{sheet_dir}/{name}.png"
        if os.path.exists(f):
            im = Image.open(f).convert("RGBA")
            if im.width > m["width"]:
                im.crop((0, 0, m["width"], m["height"])).save(f, optimize=True)
    m["line_length"] = 1
    json.dump(m, open(p, "w")); print("trimmed", sheet_dir, m)


def tone(app, sheet_dirs):
    """Tonal range: of a sprite's opaque pixels (alpha over 128, body only, no shadow), the share with luminance under
    25 % and over 75 %, for ours beside vanilla's crash ship, cargo landing pad and rocket silo (the coordinator's
    round 2, 2026-11-12: "mid-grey-blue all over, no dark recesses and no highlights")."""
    import json
    def measure(im):
        px = im.convert("RGBA").getdata()
        n = lo = hi = 0; tot = 0.0
        for r, g, b, a in px:
            if a <= 128: continue
            y = (0.299 * r + 0.587 * g + 0.114 * b) / 255
            n += 1; tot += y
            lo += y < 0.25; hi += y > 0.75
        return n, lo / n, hi / n, tot / n
    rows = []
    d = f"{app}/data/base/graphics/entity/"
    rows.append(("vanilla crash ship", measure(Image.open(d + "crash-site-spaceship/spaceship.png"))))
    rows.append(("rocket silo", measure(Image.open(d + "rocket-silo/06-rocket-silo.png"))))
    c = Image.new("RGBA", (800, 800), (0, 0, 0, 0)); pad(app, c, 400, 400); rows.append(("cargo landing pad", measure(c)))
    for sd in sheet_dirs:
        m = json.load(open(f"{sd}/sheet.json"))
        rows.append(("/".join(sd.rstrip("/").split("/")[-2:]), measure(Image.open(f"{sd}/body.png").crop((0, 0, m["width"], m["height"])))))
    print("%-22s %8s %9s %9s %7s" % ("sprite", "pixels", "dark<25%", "light>75%", "mean"))
    for name, (n, lo, hi, mean) in rows:
        print("%-22s %8d %8.1f%% %8.1f%% %6.2f" % (name, n, lo * 100, hi * 100, mean))


if __name__ == "__main__":
    if sys.argv[1] == "tone":
        tone(sys.argv[2], sys.argv[3:])
    elif sys.argv[1] == "trim":
        trim(sys.argv[2])
    elif sys.argv[1] == "concepts":
        concepts(sys.argv[2], [a.split("=", 1) for a in sys.argv[3:]])
    elif sys.argv[1] == "compare":
        compare(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
