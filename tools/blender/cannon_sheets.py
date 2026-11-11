"""The big orbital cannon's renders (orbital_cannon.py) to sheets, a set a direction: body.png (one frame), glow.png
(its frames, at half size: a glow needs no detail, and four directions of a sprite 8 by 23 tiles are a lot of memory),
shadow.png (one frame), each frame stretched by sqrt(2) and cropped to the union of body, glow and shadow, so all three
share a frame size and a shift. Writes dirs.json (sheets_lua.py reads it): per direction width, height, shift (tiles at 64 px a tile), glow
frames and line length. And a preview of each direction over a platform's grey.

    uv run --with pillow python tools/blender/cannon_sheets.py <render dir> <out dir>
"""
import json, math, os, sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
LINE = 4
meta = {}
def stretch(im):
    return im.resize((im.width, int(im.height * math.sqrt(2))), Image.LANCZOS)
for d in sorted(os.listdir(src)):
    base = f"{src}/{d}"
    if not os.path.isdir(f"{base}/body"):
        continue
    # (A body of many frames, player_buildings.py's ANIM: the claim marker's flag, the bait's cloud; its shadow one a frame.)
    bodies = [stretch(Image.open(f"{base}/body/{n}").convert("RGBA")) for n in sorted(os.listdir(f"{base}/body"))]
    body = bodies[0]
    glows = [stretch(Image.open(f"{base}/glow/{n}").convert("RGBA")) for n in sorted(os.listdir(f"{base}/glow"))]
    # (The catcher's faint alpha over the whole plane cut before the stretch, and after it: stretched first, its ringing
    # read as shadow to the frame's edge and the crop took all of it.)
    def shade(path):
        im = Image.open(path).convert("RGBA")
        im.putalpha(im.split()[3].point(lambda v: v if v > 12 else 0))
        return stretch(im)
    if os.path.isdir(f"{base}/shadow"):
        shadows = [shade(f"{base}/shadow/{n}") for n in sorted(os.listdir(f"{base}/shadow"))]
    else:
        shadows = [shade(f"{base}/shadow.png")]
    shadow = shadows[0]
    # (Full strength, as vanilla's shadow sprites are, alpha 255 where solid: the game draws every shadow at its own opacity. At
    # 0.55 of it, "vanilla's strength" as first assumed, ours drew at half of that, faint beside vanilla's, 0.2.321.)
    for im in shadows:
        im.putalpha(im.split()[3].point(lambda v: v if v > 12 else 0))
    for im in bodies + glows:
        im.putalpha(im.split()[3].point(lambda v: v if v > 3 else 0))
    box = None
    for im in bodies + shadows + glows:
        b = im.getbbox()
        if b: box = b if not box else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    # (Even, so the half-size glow's frame is exactly half.)
    box = (box[0] - 2, box[1] - 2, box[2] + 2 + (box[2] - box[0]) % 2, box[3] + 2 + (box[3] - box[1]) % 2)
    fw, fh = box[2] - box[0], box[3] - box[1]
    def pack(frames, path):
        if len(frames) == 1:
            frames[0].crop(box).save(path, optimize=True); return
        sh = Image.new("RGBA", (fw * LINE, fh * math.ceil(len(frames) / LINE)), (0, 0, 0, 0))
        for i, im in enumerate(frames):
            sh.paste(im.crop(box), ((i % LINE) * fw, (i // LINE) * fh))
        sh.save(path, optimize=True)
    pack(bodies, f"{out}/{d}-body.png")
    pack(shadows if len(shadows) == len(bodies) else shadows[:1], f"{out}/{d}-shadow.png")
    gw, gh = fw // 2, fh // 2
    rows = math.ceil(len(glows) / LINE)
    sheet = Image.new("RGBA", (gw * LINE, gh * rows), (0, 0, 0, 0))
    for i, im in enumerate(glows):
        sheet.paste(im.crop(box).resize((gw, gh), Image.LANCZOS), ((i % LINE) * gw, (i // LINE) * gh))
    sheet.save(f"{out}/{d}-glow.png", optimize=True)
    W, H = body.size
    cx, cy = (box[0] + box[2]) / 2 - W / 2, (box[1] + box[3]) / 2 - H / 2
    meta[d] = {"width": fw, "height": fh, "shift": [cx / 64, cy / 64], "glow_frames": len(glows), "line_length": LINE}
    if len(bodies) > 1: meta[d]["body_frames"] = len(bodies)
    # The barrel: its own still, cropped to its own box (the script draws it over the body and slides it as it fires).
    if os.path.exists(f"{base}/barrel/000.png"):
        br = stretch(Image.open(f"{base}/barrel/000.png").convert("RGBA"))
        br.putalpha(br.split()[3].point(lambda v: v if v > 3 else 0))
        bb = br.getbbox(); bb = (bb[0] - 2, bb[1] - 2, bb[2] + 2, bb[3] + 2)
        br.crop(bb).save(f"{out}/{d}-barrel.png", optimize=True)
        meta[d]["barrel"] = {"width": bb[2] - bb[0], "height": bb[3] - bb[1],
                             "shift": [((bb[0] + bb[2]) / 2 - W / 2) / 64, ((bb[1] + bb[3]) / 2 - H / 2) / 64]}
    # The fans: full size, cropped to their own box over all frames (a small sheet laid over the body).
    if os.path.isdir(f"{base}/fans"):
        fans = [stretch(Image.open(f"{base}/fans/{n}").convert("RGBA")) for n in sorted(os.listdir(f"{base}/fans"))]
        fb = None
        for im in fans:
            im.putalpha(im.split()[3].point(lambda v: v if v > 3 else 0))
            b2 = im.getbbox()
            if b2: fb = b2 if not fb else (min(fb[0], b2[0]), min(fb[1], b2[1]), max(fb[2], b2[2]), max(fb[3], b2[3]))
        fb = (fb[0] - 2, fb[1] - 2, fb[2] + 2, fb[3] + 2)
        ww, hh = fb[2] - fb[0], fb[3] - fb[1]
        sheet = Image.new("RGBA", (ww * LINE, hh * math.ceil(len(fans) / LINE)), (0, 0, 0, 0))
        for i, im in enumerate(fans):
            sheet.paste(im.crop(fb), ((i % LINE) * ww, (i // LINE) * hh))
        sheet.save(f"{out}/{d}-fans.png", optimize=True)
        fx, fy = (fb[0] + fb[2]) / 2 - W / 2, (fb[1] + fb[3]) / 2 - H / 2
        meta[d]["fans"] = {"width": ww, "height": hh, "shift": [fx / 64, fy / 64], "frames": len(fans)}
    prev = Image.new("RGBA", (fw, fh), (78, 80, 84, 255))
    prev.alpha_composite(shadow.crop(box)); prev.alpha_composite(body.crop(box))
    if os.path.exists(f"{base}/barrel/000.png"):
        bfull = stretch(Image.open(f"{base}/barrel/000.png").convert("RGBA")); prev.alpha_composite(bfull.crop(box))
    g = glows[len(glows) // 2].crop(box); g.putalpha(g.split()[3].point(lambda v: v // 2)); prev.alpha_composite(g)
    prev.convert("RGB").save(f"{src}/preview-{d}.jpg", quality=85)
json.dump(meta, open(f"{out}/dirs.json", "w"), indent=1)
print(json.dumps(meta))
