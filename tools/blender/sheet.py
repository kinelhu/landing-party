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
shadow = stretch(Image.open(f"{src}/shadow.png").convert("RGBA"))
# (Below 12 of 255 nothing: the catcher leaves a faint alpha over its whole plane, and the crop took the full frame.)
shadow.putalpha(shadow.split()[3].point(lambda v: int(v * 0.55) if v > 12 else 0))
for frames in (body, glow):
    for im in frames:
        im.putalpha(im.split()[3].point(lambda v: v if v > 3 else 0))
W, H = body[0].size
box = None
for im in body + glow + [shadow]:
    b = im.getbbox()
    if b: box = b if not box else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
box = (box[0] - 2, box[1] - 2, box[2] + 2, box[3] + 2)
fw, fh = box[2] - box[0], box[3] - box[1]
LINE = 8
rows = math.ceil(len(names) / LINE)
os.makedirs(out, exist_ok=True)
for key, frames in (("body", body), ("glow", glow), ("shadow", [shadow] * len(names))):
    sheet = Image.new("RGBA", (fw * LINE, fh * rows), (0, 0, 0, 0))
    for i, im in enumerate(frames):
        sheet.paste(im.crop(box), ((i % LINE) * fw, (i // LINE) * fh))
    sheet.save(f"{out}/{key}.png", optimize=True)
# The entity's centre is the render's centre (the camera looks at the ground's origin): the crop's offset from it.
cx, cy = (box[0] + box[2]) / 2 - W / 2, (box[1] + box[3]) / 2 - H / 2
meta = {"width": fw, "height": fh, "frames": len(names), "line_length": LINE, "shift": [cx / 64, cy / 64]}
json.dump(meta, open(f"{out}/sheet.json", "w"))
print(meta)
if gif:
    bg = (96, 82, 62, 255)
    shots = []
    for b, g in zip(body, glow):
        fr = Image.new("RGBA", (W, H), bg)
        fr.alpha_composite(shadow); fr.alpha_composite(b)
        glo = g.copy(); glo.putalpha(glo.split()[3].point(lambda v: v // 2)); fr.alpha_composite(glo)
        fr = fr.crop(box).resize((fw // 2, fh // 2), Image.LANCZOS)
        shots.append(fr.convert("P", palette=Image.ADAPTIVE))
    shots[0].save(gif, save_all=True, append_images=shots[1:], duration=60, loop=0)
    print("gif", gif)
