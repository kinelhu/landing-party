"""Frames of one animation (a Blender render) to a Factorio sheet: each stretched by sqrt(2), cropped to their union, 8 a
row; sheet.png and sheet.json (frame size, count, shift in tiles at `px` a tile) in <out>; a preview GIF if asked.

    uv run --with pillow python tools/blender/anim_sheet.py <frames dir> <out dir> <px per tile> [gif]
"""
import json, math, os, sys
from PIL import Image

src, out, px = sys.argv[1], sys.argv[2], int(sys.argv[3])
gif = sys.argv[4] if len(sys.argv) > 4 else None
frames = [Image.open(f"{src}/{n}").convert("RGBA") for n in sorted(os.listdir(src)) if n.endswith(".png")]
frames = [im.resize((im.width, int(im.height * math.sqrt(2))), Image.LANCZOS) for im in frames]
for im in frames: im.putalpha(im.split()[3].point(lambda v: v if v > 3 else 0))
W, H = frames[0].size
box = None
for im in frames:
    b = im.getbbox()
    if b: box = b if not box else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
box = (max(0, box[0] - 2), max(0, box[1] - 2), min(W, box[2] + 2), min(H, box[3] + 2))
fw, fh, LINE = box[2] - box[0], box[3] - box[1], 8
rows = math.ceil(len(frames) / LINE)
sheet = Image.new("RGBA", (fw * LINE, fh * rows), (0, 0, 0, 0))
for i, im in enumerate(frames): sheet.paste(im.crop(box), ((i % LINE) * fw, (i // LINE) * fh))
os.makedirs(out, exist_ok=True)
sheet.save(f"{out}/sheet.png", optimize=True)
meta = {"width": fw, "height": fh, "frames": len(frames), "line_length": LINE,
        "shift": [((box[0] + box[2]) / 2 - W / 2) / px, ((box[1] + box[3]) / 2 - H / 2) / px]}
json.dump(meta, open(f"{out}/sheet.json", "w")); print(meta)
if gif:
    shots = []
    for im in frames:
        fr = Image.new("RGBA", (W, H), (96, 82, 62, 255)); fr.alpha_composite(im)
        shots.append(fr.crop(box).convert("P", palette=Image.ADAPTIVE))
    shots[0].save(gif, save_all=True, append_images=shots[1:], duration=50, loop=0); print("gif", gif)
