"""Headless sprite preview: prototypes from the data dump (scripts/check.sh) drawn at true relative scale (32 px a tile,
each layer at its scale and shift, shadows, masks and runtime-tinted layers left out, glows at half), beside vanilla ones.
A look before the game window, not instead of it (masks, emissives and lighting are only right in game).

    source scripts/env.sh; uv run --with pillow python scripts/sprite_preview.py "$APP" <data-raw-dump.json> <out.png>
"""
import json, sys, os
from PIL import Image, ImageDraw
APP, DUMP, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(DUMP))
roots = {"__base__": APP + "/data/base", "__core__": APP + "/data/core", "__space-age__": APP + "/data/space-age",
         "__landing-party__": os.path.expanduser("~/Dev/landing-party/landing-party"),
         "__landing-party-graphics__": os.path.expanduser("~/Dev/landing-party/landing-party-graphics")}
def path(f):
    for k, v in roots.items():
        if f.startswith(k): return v + f[len(k):]
PX = 32
def draw_layers(canvas, cx, cy, layers, frame=0):
    for L in layers:
        if L.get("draw_as_shadow"): continue
        f = path(L.get("filename") or (L.get("filenames") or [None])[0] or "")
        if not f or not os.path.exists(f): continue
        img = Image.open(f).convert("RGBA")
        w, h = L.get("width") or L.get("size"), L.get("height") or L.get("size")
        if isinstance(w, list): w, h = w
        w, h = w or img.width, h or img.height
        ll = L.get("line_length") or 1
        fr = frame % max(1, L.get("frame_count") or 1)
        x = (L.get("x") or 0) + (fr % ll) * w; y = (L.get("y") or 0) + (fr // ll) * h
        crop = img.crop((x, y, x + w, y + h))
        s = (L.get("scale") or 1)
        crop = crop.resize((max(1, round(w * s * PX / 32)), max(1, round(h * s * PX / 32))))
        sh = L.get("shift") or [0, 0]
        if isinstance(sh, dict): sh = [sh.get("x", 0), sh.get("y", 0)]
        t = L.get("tint")
        if t:
            tr = [t.get("r", 1), t.get("g", 1), t.get("b", 1)] if isinstance(t, dict) else t[:3]
            tr = [v / 255 if v > 1 else v for v in tr]
            px = crop.split(); crop = Image.merge("RGBA", [px[i].point(lambda v, m=tr[i]: int(v * m)) for i in range(3)] + [px[3]])
        if "mask" in (L.get("flags") or []) or L.get("apply_runtime_tint"):
            continue
        if L.get("draw_as_glow") or L.get("blend_mode") == "additive":
            crop.putalpha(crop.split()[3].point(lambda v: v // 2))
        canvas.alpha_composite(crop, (int(cx + sh[0] * PX - crop.width / 2), int(cy + sh[1] * PX - crop.height / 2)))
def get(t, n): return d.get(t, {}).get(n)
def lab(n):
    return get("lab", n)["on_animation"]["layers"] + (get("animation", n + "-busy") or {}).get("layers", [])
items = []
for corp, pre in (("Kessler-Hayashi", "lp-"), ("Grubstake", "lp-grubstake-")):
    items += [(corp + " optics lab", lab(pre + "optics-lab"), 4), (corp + " line lab", lab(pre + "line-lab"), 4),
              (corp + " siege lab", lab(pre + "siege-lab"), 4)]
    for n, k, size in (("dome-projector", "projector", 3), ("uplink", "uplink", 6)):
        p = get("radar", pre + n)
        if p: items.append((corp + " " + k, p["pictures"]["layers"], size))
CELL = 280
sheet = Image.new("RGBA", (CELL * 5, (CELL + 24) * 2), (74, 66, 54, 255))
dr = ImageDraw.Draw(sheet)
for i, (name, layers, size) in enumerate(items):
    cx, cy = (i % 5) * CELL + CELL // 2, (i // 5) * (CELL + 24) + CELL // 2 + 20
    dr.rectangle([cx - size * PX / 2, cy - size * PX / 2, cx + size * PX / 2, cy + size * PX / 2], outline=(110, 100, 80, 255))
    draw_layers(sheet, cx, cy, layers, frame=5)
    dr.text(((i % 5) * CELL + 6, (i // 5) * (CELL + 24) + CELL + 4), f"{name} ({size}x{size})", fill=(240, 235, 220, 255))
sheet.save(OUT); print("wrote", OUT)
