import sys
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageFilter
S, OUT = sys.argv[1], sys.argv[2]
F = "/System/Library/Fonts/Supplemental/Impact.ttf"
W, H = 1280, 720
def grade(im):
    im = ImageEnhance.Contrast(im).enhance(1.3); im = ImageEnhance.Color(im).enhance(1.35)
    return ImageEnhance.Brightness(im).enhance(1.12)
# (source, crop box 600x888, faction name, colour)
panels = [("gc.png", (330, 22, 1030, 1058), "GRUBSTAKE", (204, 140, 51)),
          ("f-77.6.png", (650, 0, 1250, 888), "KESSLER-HAYASHI", (140, 204, 217)),
          ("f-63.0.png", (810, 0, 1410, 888), "SYNTHEXIS", (115, 217, 51))]
# slanted borders: x at top, x at bottom
B = [(-60, -60), (470, 390), (900, 820), (1340, 1340)]
canvas = Image.new("RGB", (W, H))
for i, (src, box, name, col) in enumerate(panels):
    im = grade(Image.open(f"{S}/{src}").convert("RGB").crop(box).resize((487, 720), Image.LANCZOS))
    (t0, b0), (t1, b1) = B[i], B[i + 1]
    cx = (t0 + b0 + t1 + b1) / 4
    layer = Image.new("RGB", (W, H)); layer.paste(im, (int(cx - 243), 0))
    m = Image.new("L", (W, H), 0); ImageDraw.Draw(m).polygon([(t0, 0), (t1, 0), (b1, H), (b0, H)], fill=255)
    canvas.paste(layer, (0, 0), m)
d = ImageDraw.Draw(canvas)
# bottom band for the title
band = Image.new("L", (W, H), 0); bd = ImageDraw.Draw(band)
for y in range(H):
    a = max(0, min(200, int((y - 430) / 290 * 230)))
    bd.line([(0, y), (W, y)], fill=a)
canvas = Image.composite(Image.new("RGB", (W, H)), canvas, band)
d = ImageDraw.Draw(canvas)
for i in (1, 2):
    (t, b), col = B[i], panels[i - 1][3]
    d.line([(t, 0), (b, H)], fill=(0, 0, 0), width=14)
    d.line([(t, 0), (b, H)], fill=(235, 235, 235), width=6)
f1, f2 = ImageFont.truetype(F, 150), ImageFont.truetype(F, 46)
for i, (src, box, name, col) in enumerate(panels):
    (t0, b0), (t1, b1) = B[i], B[i + 1]
    x = (max(t0, 0) + min(t1, W)) / 2 + (8 if i == 0 else 0)
    d.text((x, 22), name, font=f2, fill=col, stroke_width=6, stroke_fill=(0, 0, 0), anchor="ma")
d.text((W / 2, 690), "LANDING PARTY", font=f1, fill=(255, 255, 255), stroke_width=10, stroke_fill=(0, 0, 0), anchor="md")
canvas.save(OUT)
