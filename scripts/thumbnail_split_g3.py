# The split (scripts/thumbnail_split.py's layout, unchanged) with G3's Grubstake panel, in four variants:
# labels on/off x the current grade / a softer one. KH and Synthexis frames: cut-25.mp4 at 77.6 and 63.0 s
# (they reproduce thumbnail-split.png's panels exactly under the current grade); Grubstake: cut-30.mp4 at 64.8 s.
import os
from PIL import Image, ImageDraw, ImageFont, ImageEnhance
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = os.path.join(REPO, "media", "trailer", "thumb-src")  # (each frame: ffmpeg -ss <seconds> -i <cut> -frames:v 1)
D = os.path.join(REPO, "media", "trailer")
F = "/System/Library/Fonts/Supplemental/Impact.ttf"
W, H = 1280, 720
GRADES = {"graded": (1.3, 1.35, 1.12), "soft": (1.12, 1.08, 1.04)}  # contrast, saturation, brightness
panels = [("f64.8.png", (520, 22, 1220, 1058), "GRUBSTAKE", (204, 140, 51)),
          ("f-77.6.png", (650, 0, 1250, 888), "KESSLER-HAYASHI", (140, 204, 217)),
          ("f-63.0.png", (810, 0, 1410, 888), "SYNTHEXIS", (115, 217, 51))]
B = [(-60, -60), (470, 390), (900, 820), (1340, 1340)]
def build(grade_name, labels):
    c, s, b = GRADES[grade_name]
    def grade(im):
        im = ImageEnhance.Contrast(im).enhance(c); im = ImageEnhance.Color(im).enhance(s)
        return ImageEnhance.Brightness(im).enhance(b)
    canvas = Image.new("RGB", (W, H))
    for i, (src, box, name, col) in enumerate(panels):
        im = grade(Image.open(f"{S}/{src}").convert("RGB").crop(box).resize((487, 720), Image.LANCZOS))
        (t0, b0), (t1, b1) = B[i], B[i + 1]
        cx = (t0 + b0 + t1 + b1) / 4
        layer = Image.new("RGB", (W, H)); layer.paste(im, (int(cx - 243), 0))
        m = Image.new("L", (W, H), 0); ImageDraw.Draw(m).polygon([(t0, 0), (t1, 0), (b1, H), (b0, H)], fill=255)
        canvas.paste(layer, (0, 0), m)
    band = Image.new("L", (W, H), 0); bd = ImageDraw.Draw(band)
    for y in range(H):
        bd.line([(0, y), (W, y)], fill=max(0, min(200, int((y - 430) / 290 * 230))))
    canvas = Image.composite(Image.new("RGB", (W, H)), canvas, band)
    d = ImageDraw.Draw(canvas)
    for i in (1, 2):
        t, bb = B[i]
        d.line([(t, 0), (bb, H)], fill=(0, 0, 0), width=14)
        d.line([(t, 0), (bb, H)], fill=(235, 235, 235), width=6)
    f1, f2 = ImageFont.truetype(F, 150), ImageFont.truetype(F, 46)
    if labels:
        for i, (src, box, name, col) in enumerate(panels):
            (t0, b0), (t1, b1) = B[i], B[i + 1]
            x = (max(t0, 0) + min(t1, W)) / 2 + (8 if i == 0 else 0)
            d.text((x, 22), name, font=f2, fill=col, stroke_width=6, stroke_fill=(0, 0, 0), anchor="ma")
    d.text((W / 2, 690), "LANDING PARTY", font=f1, fill=(255, 255, 255), stroke_width=10, stroke_fill=(0, 0, 0), anchor="md")
    n = f"thumbnail-split-G3-{'labels' if labels else 'nolabels'}-{grade_name}.png"
    canvas.save(f"{D}/{n}", optimize=True)
    print(n, os.path.getsize(f"{D}/{n}"))
for g in ("graded", "soft"):
    for l in (True, False):
        build(g, l)
