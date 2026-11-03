"""Beside vanilla: a Blender frame (factorio_frame.py at 32 px a tile) next to the tesla turret, radar and laser turret.

    uv run --with pillow python tools/blender/compare.py "$APP" <unused dir> <frame32.png> <out.png>
"""
import sys, json, os
from PIL import Image, ImageDraw
APP, S = sys.argv[1], sys.argv[2]
d = json.load(open(os.path.expanduser("~/Library/Application Support/factorio-lp-check/script-output/data-raw-dump.json")))
def path(f):
    roots = {"__base__": APP + "/data/base", "__space-age__": APP + "/data/space-age", "__landing-party__": os.path.expanduser("~/Dev/landing-party/landing-party")}
    for k, v in roots.items():
        if f.startswith(k): return v + f[len(k):]
def draw(canvas, cx, cy, layers):
    for L in layers:
        f = path(L.get("filename") or "")
        if not f or not os.path.exists(f): continue
        if "mask" in (L.get("flags") or []) or L.get("apply_runtime_tint"): continue
        img = Image.open(f).convert("RGBA")
        w, h = L.get("width"), L.get("height")
        crop = img.crop((L.get("x", 0), L.get("y", 0), L.get("x", 0) + w, L.get("y", 0) + h))
        s = L.get("scale") or 1
        crop = crop.resize((max(1, round(w * s)), max(1, round(h * s))))
        if L.get("draw_as_glow") or L.get("blend_mode") == "additive": crop.putalpha(crop.split()[3].point(lambda v: v // 2))
        sh = L.get("shift") or [0, 0]
        canvas.alpha_composite(crop, (int(cx + sh[0] * 32 - crop.width / 2), int(cy + sh[1] * 32 - crop.height / 2)))
t = d["electric-turret"]["tesla-turret"]
bv = t["graphics_set"]["base_visualisation"]; bv = bv if isinstance(bv, dict) else bv[0]
head = [dict(l, x=0, y=0) for l in t["prepared_animation"]["layers"]]
radar = d["radar"]["radar"]["pictures"]["layers"]
lt = d["electric-turret"]["laser-turret"]; lbv = lt["graphics_set"]["base_visualisation"]; lbv = lbv if isinstance(lbv, dict) else lbv[0]
W, H = 1000, 340
sheet = Image.new("RGBA", (W, H), (96, 82, 62, 255))
dr = ImageDraw.Draw(sheet)
cols = [("vanilla tesla turret (4x4)", bv["animation"]["layers"] + head, 4), ("Blender tower (3x3)", None, 3),
        ("vanilla radar (3x3)", radar, 3), ("vanilla laser turret (2x2)", lbv["animation"]["layers"], 2)]
for i, (name, layers, size) in enumerate(cols):
    cx, cy = 125 + i * 250, 210
    dr.rectangle([cx - size * 16, cy - size * 16, cx + size * 16, cy + size * 16], outline=(130, 112, 86, 255))
    if layers: draw(sheet, cx, cy, layers)
    else:
        fr = Image.open(sys.argv[3])
        sheet.alpha_composite(fr, (cx - fr.width // 2, cy - fr.height // 2))
    dr.text((cx - 100, 315), name, fill=(245, 238, 222, 255))
sheet.save(sys.argv[4]); print("ok")
