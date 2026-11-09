import sys
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageFilter
S = sys.argv[1]
F = "/System/Library/Fonts/Supplemental/Impact.ttf"
def thumb(src, out, box, head, sub, hx=60, hy=40, anchor="la"):
    im = Image.open(f"{S}/{src}").convert("RGB").crop(box).resize((1280, 720), Image.LANCZOS)
    im = ImageEnhance.Contrast(im).enhance(1.25); im = ImageEnhance.Color(im).enhance(1.3); im = ImageEnhance.Brightness(im).enhance(1.08)
    # vignette
    v = Image.new("L", (1280, 720), 0); d = ImageDraw.Draw(v); d.ellipse((-260, -200, 1540, 920), fill=255)
    v = v.filter(ImageFilter.GaussianBlur(140))
    im = Image.composite(im, Image.new("RGB", im.size, (0, 0, 0)), v)
    d = ImageDraw.Draw(im)
    f1 = ImageFont.truetype(F, 150); f2 = ImageFont.truetype(F, 54)
    d.text((hx, hy), head, font=f1, fill=(255, 255, 255), stroke_width=9, stroke_fill=(0, 0, 0), anchor=anchor)
    d.text((hx + 4, hy + 165 if anchor == "la" else hy + 20), sub, font=f2, fill=(255, 196, 40), stroke_width=6, stroke_fill=(0, 0, 0), anchor=anchor)
    im.save(f"{S}/{out}")

thumb("f-97.3.png", "A1-notalone.png", (180, 20, 1740, 897), "YOU'RE NOT ALONE", "RIVAL AI FACTIONS  |  FACTORIO MOD", 50, 470)
thumb("f-97.3.png", "A2-fightback.png", (180, 20, 1740, 897), "THEY FIGHT BACK", "RIVAL AI FACTIONS  |  FACTORIO MOD", 50, 470)
thumb("f-97.3.png", "A3-invaded.png", (180, 20, 1740, 897), "AI INVASION", "RIVAL FACTIONS LAND ON NAUVIS  |  FACTORIO MOD", 50, 470)
thumb("f-97.3.png", "A4-landingparty.png", (180, 20, 1740, 897), "LANDING PARTY", "A FACTORIO MOD", 50, 470)
