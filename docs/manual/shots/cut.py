"""Cut the manual's pictures from the films' stills, as docs/manual/shots/cut.json lists them.

    uv run --with pillow python docs/manual/shots/cut.py <films dir> docs/manual/media [preview dir]

<films dir> holds the films' frame folders (film-m-trailer, film-m-khwall, ...: docs/sim by default, as each params file's
header says). Each item: `src` (a still, relative to the films dir), `box` (x0, y0, x1, y1 in the still's pixels), `width`
(the output's, height by the box's aspect), `out` (relative to the media dir; .jpg or .png). An item with `callouts` also
writes <out>.json beside it: the output's size and each callout's number, label and pixel x, y in the output. A callout
gives `world` (x, y on the map; the item's `view`, {center, zoom}, maps it to the still) or `px` (the still's pixels),
and `dx`, `dy` (output pixels) to set the dot on the thing's body rather than its foot. With a preview dir, each item
with callouts is drawn there with its numbered dots, to check them by eye.

Fails if a still is missing or an output passes 1 MB.
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

films, media = sys.argv[1], sys.argv[2]
preview = sys.argv[3] if len(sys.argv) > 3 else None
spec = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "cut.json")))
LIMIT = 1024 * 1024
made = 0
# CUT_ONLY=out1,out2 cuts those pictures alone (the rest keep the files they have): a refilm of some films, the others'
# stills gone from docs/sim (2026-11-12). A named one whose still is missing still stops the run.
ONLY = set(filter(None, os.environ.get("CUT_ONLY", "").split(",")))
for it in spec["items"]:
    if ONLY and it["out"] not in ONLY:
        continue
    src = os.path.join(films, it["src"])
    if not os.path.exists(src):
        sys.exit(f"missing still: {src}")
    im = Image.open(src).convert("RGB")
    x0, y0, x1, y1 = it["box"]
    w = it.get("width", x1 - x0)
    s = w / (x1 - x0)
    out_im = im.crop((x0, y0, x1, y1)).resize((round(w), round((y1 - y0) * s)), Image.LANCZOS)
    dst = os.path.join(media, it["out"])
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    q = it.get("quality", 88)
    while True:
        if dst.endswith(".png"):
            out_im.save(dst, optimize=True)
        else:
            out_im.save(dst, quality=q, optimize=True, progressive=True)
        if os.path.getsize(dst) <= LIMIT or dst.endswith(".png") or q <= 60:
            break
        q -= 4
    if os.path.getsize(dst) > LIMIT:
        sys.exit(f"over 1 MB: {dst} ({os.path.getsize(dst)} bytes)")
    made += 1
    print(f"{it['out']}: {out_im.size[0]}x{out_im.size[1]}, {os.path.getsize(dst) // 1024} KB (q{q})")
    if "callouts" in it:
        W, H = im.size
        v = it.get("view", {})
        pts = []
        for n, c in enumerate(it["callouts"], 1):
            if "world" in c:
                cx, cy = v["center"]
                px = W / 2 + (c["world"][0] - cx) * 32 * v["zoom"]
                py = H / 2 + (c["world"][1] - cy) * 32 * v["zoom"]
            else:
                px, py = c["px"]
            ox, oy = (px - x0) * s + c.get("dx", 0), (py - y0) * s + c.get("dy", 0)
            if not (0 <= ox < out_im.size[0] and 0 <= oy < out_im.size[1]):
                sys.exit(f"{it['out']}: callout {n} ({c['label']}) falls outside the picture at {ox:.0f},{oy:.0f}")
            pts.append({"n": n, "x": round(ox), "y": round(oy), "label": c["label"]})
        meta = {"image": os.path.basename(dst), "width": out_im.size[0], "height": out_im.size[1],
                "caption": it.get("caption", ""), "callouts": pts}
        with open(os.path.splitext(dst)[0] + ".json", "w") as f:
            json.dump(meta, f, indent=1)
            f.write("\n")
        if preview:
            os.makedirs(preview, exist_ok=True)
            p = out_im.copy()
            d = ImageDraw.Draw(p)
            try:
                font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 26)
            except OSError:
                font = ImageFont.load_default()
            for c in pts:
                r = 20
                d.ellipse((c["x"] - r, c["y"] - r, c["x"] + r, c["y"] + r), fill=(250, 250, 250), outline=(20, 20, 20), width=3)
                d.text((c["x"], c["y"]), str(c["n"]), fill=(20, 20, 20), font=font, anchor="mm")
            y = 10
            for c in pts:
                d.text((12, y), f"{c['n']}. {c['label']}", fill=(255, 255, 0), font=font, stroke_width=3, stroke_fill=(0, 0, 0))
                y += 32
            p.save(os.path.join(preview, os.path.basename(os.path.splitext(dst)[0]) + "-callouts.jpg"), quality=85)
print(f"{made} of {len(spec['items'])} cut")
if made != len(spec["items"]):
    sys.exit("not every item was cut")
