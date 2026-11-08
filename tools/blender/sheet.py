"""Blender frames to Factorio sprite sheets (tesla_tower.py with FRAMES): each frame stretched by sqrt(2), all cropped
to their union's bounding box, 8 a row; the shadow (one render) repeated for every frame (a rotated sprite's layers
share their direction count) at vanilla's strength. Writes body.png, glow.png, shadow.png and sheet.json (frame size,
count, line length, shift in tiles at 64 px a tile), and a preview GIF.

    uv run --with pillow python tools/blender/sheet.py <frames dir> <out dir> [gif]
"""
import json, math, os, sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
gif = sys.argv[3] if len(sys.argv) > 3 else None
names = sorted(os.listdir(src + "/body"))
def stretch(im):
    return im.resize((im.width, int(im.height * math.sqrt(2))), Image.LANCZOS)
body = [stretch(Image.open(f"{src}/body/{n}").convert("RGBA")) for n in names]
glow = [stretch(Image.open(f"{src}/glow/{n}").convert("RGBA")) for n in names]
# One shadow, or one a frame (a shadow/ folder: a shape that moves).
def shade(im):
    # (Below 12 of 255 nothing: the catcher leaves a faint alpha over its whole plane, and the crop took the full frame.)
    im.putalpha(im.split()[3].point(lambda v: int(v * 0.55) if v > 12 else 0)); return im
# None: a layer drawn over another's shadow (buggy.py's chassis: each weapon module's sheet carries the whole shadow).
if os.path.isdir(f"{src}/shadow"):
    shadows = [shade(stretch(Image.open(f"{src}/shadow/{n}").convert("RGBA"))) for n in names]
elif os.path.exists(f"{src}/shadow.png"):
    shadows = [shade(stretch(Image.open(f"{src}/shadow.png").convert("RGBA")))] * len(names)
else:
    shadows = []
for frames in (body, glow):
    for im in frames:
        im.putalpha(im.split()[3].point(lambda v: v if v > 3 else 0))
W, H = body[0].size
box = None
for im in body + glow + shadows:
    b = im.getbbox()
    if b: box = b if not box else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
box = (box[0] - 2, box[1] - 2, box[2] + 2, box[3] + 2)
fw, fh = box[2] - box[0], box[3] - box[1]
LINE = 8
rows = math.ceil(len(names) / LINE)
os.makedirs(out, exist_ok=True)
# A sheet taller than MAXH goes to several files, LPF rows each (<key>-1.png...; filenames and lines_per_file in the
# prototype): the antenna's 512 frames made one 16,000 pixels tall. Vanilla keeps its sheets small (the car on six files).
MAXH = 8192
LPF = MAXH // fh
nfiles = math.ceil(rows / LPF)
for key, frames in (("body", body), ("glow", glow), ("shadow", shadows)):
    if not frames:
        continue
    for f in range(nfiles):
        part = frames[f * LPF * LINE:(f + 1) * LPF * LINE]
        sheet = Image.new("RGBA", (fw * LINE, fh * math.ceil(len(part) / LINE)), (0, 0, 0, 0))
        for i, im in enumerate(part):
            sheet.paste(im.crop(box), ((i % LINE) * fw, (i // LINE) * fh))
        sheet.save(f"{out}/{key}.png" if nfiles == 1 else f"{out}/{key}-{f + 1}.png", optimize=True)
# The entity's centre is the render's centre (the camera looks at the ground's origin): the crop's offset from it.
cx, cy = (box[0] + box[2]) / 2 - W / 2, (box[1] + box[3]) / 2 - H / 2
meta = {"width": fw, "height": fh, "frames": len(names), "line_length": LINE, "shift": [cx / 64, cy / 64]}
if nfiles > 1:
    meta.update(files=nfiles, lines_per_file=LPF)
json.dump(meta, open(f"{out}/sheet.json", "w"))
print(meta)
if gif:
    bg = (96, 82, 62, 255)
    shots = []
    for b, g, sh in zip(body, glow, shadows or [Image.new("RGBA", body[0].size)] * len(body)):
        fr = Image.new("RGBA", (W, H), bg)
        fr.alpha_composite(sh); fr.alpha_composite(b)
        glo = g.copy(); glo.putalpha(glo.split()[3].point(lambda v: v // 2)); fr.alpha_composite(glo)
        fr = fr.crop(box).resize((fw // 2, fh // 2), Image.LANCZOS)
        shots.append(fr.convert("P", palette=Image.ADAPTIVE))
    shots[0].save(gif, save_all=True, append_images=shots[1:], duration=60, loop=0)
    print("gif", gif)
