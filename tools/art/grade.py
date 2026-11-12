"""Synthexis's colour grade: its borrowed organic art (the pen's captive-spawner flesh, the creep's jellynut soil, the
tumor's Gleba raft) regraded in OKLCh instead of tinted (the user, 2026-11-12: "Your tinting is a little rudimentary.
It's also hitting the metal parts. Even the fleshy bits deserve a progressive grading depending on the base color").

A tint multiplies every pixel by one colour: the pen's grey metal took it as much as its flesh, and the flesh's pinks,
oranges and veins all collapsed toward one hue. Here each pixel is moved in OKLCh (perceptual lightness, chroma, hue):
  - a soft mask on chroma leaves the greys (metal, cables, glass) as they are and grades only what has colour;
  - hue is rotated so the art's own mean organic hue lands on the palette's hue, its spread round that mean kept but
    narrowed (pinks stay apart from oranges, veins from skin), and shifted with lightness (shadows one way, highlights
    the other: a gradient map's split);
  - chroma is scaled, lightness lifted or lowered by a gamma.

  uv run -q --with numpy --with pillow tools/art/grade.py <palette> <out dir>
writes <out dir>/pen.png, creep.png, tumor-1.png, tumor-2.png and, for a palette with a floor, floor*.png (the same layouts as the sources, so the prototypes only
change their filename). Palettes below; the source art is read from the game's install (scripts/env.sh's APP).
"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image

# Each palette: per asset class, the target hue (OKLCh degrees: 0 pink-red, 30 red, 60 orange, 110 olive, 140 green,
# 200 teal, 330 magenta), spread (the kept fraction of the art's own hue spread), split (degrees of hue shift from
# shadows to highlights), chroma (scale), gamma (lightness: above 1 darker), and the chroma mask's soft edge.
PALETTES = {
    # Bruise creep, moss-green flesh: the culture in Synthexis's green, the ground a dark mauve under it. (A first pass
    # kept 0.45 of the flesh's hue spread: its orange rings and purple veins went to one flat mint; 0.8 keeps them.)
    "moss": {"creep": dict(hue=345, spread=0.6, split=-10, chroma=0.5, gamma=1.25),
             "flesh": dict(hue=125, spread=0.8, split=-25, chroma=1.0, gamma=1.05),
             "tumor": dict(hue=135, spread=0.7, split=-15, chroma=1.0, gamma=1.0)},
    # Bruise creep, olive flesh: greener than raw meat, less than the herd; the tumors the herd's green.
    "olive": {"creep": dict(hue=345, spread=0.6, split=-10, chroma=0.5, gamma=1.25),
              "flesh": dict(hue=100, spread=0.8, split=-20, chroma=0.8, gamma=1.08),
              "tumor": dict(hue=130, spread=0.7, split=-15, chroma=0.95, gamma=1.0)},
    # Wine creep, flesh kept as flesh but muted toward it: raw meat on dark wine, the tumors green.
    "wine": {"creep": dict(hue=10, spread=0.6, split=-8, chroma=0.6, gamma=1.3),
             "flesh": dict(hue=20, spread=0.8, split=12, chroma=0.7, gamma=1.1),
             "tumor": dict(hue=135, spread=0.7, split=-15, chroma=1.0, gamma=1.0)},
    # The second round (the user: "Yes" to another iteration): Moss's pen kept; the creep given back its life (0.5 of its
    # chroma read as gravel), three ways; the tumors darker in the body with yellow-green highlights (they sat flat).
    "moss-mauve": {"creep": dict(hue=350, spread=0.6, split=-8, chroma=0.75, gamma=1.15),
                   "flesh": dict(hue=125, spread=0.8, split=-25, chroma=1.0, gamma=1.05),
                   "tumor": dict(hue=135, spread=0.7, split=-30, chroma=0.95, gamma=1.25)},
    # The same, its highlights leaning green (a gradient map's second stop: the ground tied to the faction).
    "moss-sheen": {"creep": dict(hue=350, spread=0.6, split=-8, chroma=0.75, gamma=1.15, hi_hue=120, hi_mix=0.55),
                   "flesh": dict(hue=125, spread=0.8, split=-25, chroma=1.0, gamma=1.05),
                   "tumor": dict(hue=135, spread=0.7, split=-30, chroma=0.95, gamma=1.25)},
    # Darker plum.
    "moss-plum": {"creep": dict(hue=330, spread=0.6, split=-8, chroma=0.7, gamma=1.35),
                  "flesh": dict(hue=125, spread=0.8, split=-25, chroma=1.0, gamma=1.05),
                  "tumor": dict(hue=135, spread=0.7, split=-30, chroma=0.95, gamma=1.25)},
    # The user: "returning the tumors more purple and switching from green to mauve nests": the rooted things (creep,
    # pens, tumors) one mauve family, the herd alone green; the tumors lighter and more magenta than the plum creep so
    # they still read as the targets they are.
    "mauve-plum": {"creep": dict(hue=330, spread=0.6, split=-8, chroma=0.7, gamma=1.35),
                   "flesh": dict(hue=345, spread=0.8, split=15, chroma=0.75, gamma=1.0),
                   "tumor": dict(hue=320, spread=0.7, split=20, chroma=1.15, gamma=0.85)},
    # The user: "the switch from fleshy nests to all green is a little jarring ... wild nests look so different from
    # captured ones": a captive is the same creature (its machinery, creep and lamps say captive), its flesh moved only
    # part of the way from the wild nest's orange (mean hue 50): kin a third (deep raw red-pink), half to rose-mauve.
    "kin-plum": {"creep": dict(hue=330, spread=0.6, split=-8, chroma=0.7, gamma=1.35),
                 "flesh": dict(hue=28, spread=0.9, split=10, chroma=1.05, gamma=1.12),
                 "tumor": dict(hue=320, spread=0.7, split=20, chroma=1.15, gamma=0.85)},
    "half-plum": {"creep": dict(hue=330, spread=0.6, split=-8, chroma=0.7, gamma=1.35),
                  "flesh": dict(hue=5, spread=0.9, split=10, chroma=0.95, gamma=1.12),
                  "tumor": dict(hue=320, spread=0.7, split=20, chroma=1.15, gamma=0.85),
                  # The cells' floor (0.2.345; the user on the acid-green pads: "not sure about the patches of bright
                  # green concrete anymore"): vanilla's grey refined concrete, which has no hue of its own to rotate, given
                  # one (add: chroma added, not scaled), a dark slate-plum a step off the creep, its highlights rosier.
                  "floor": dict(hue=325, spread=0.0, split=12, chroma=0.0, add=0.03, gamma=1.55),
                  # The clinic's brain: the pens' rose, its chroma raised (a pale pink-grey brain: as flesh it took 12%
                  # of the sheet and still read grey from afar).
                  "brain": dict(hue=5, spread=0.8, split=10, chroma=1.5, gamma=1.08)},
    # Kessler-Hayashi's arc flamer's burn (the user, 2026-11-12, of its tinted fire: "that looks real bad"): vanilla's
    # flame rotated from its orange to electric blue, its bright core toward cyan-white, its dark edges toward violet (a
    # light blue tint over orange had left it pale green and yellow).
    "arcfire": {"flame": dict(hue=272, spread=0.5, split=-50, chroma=1.05, gamma=1.0)},
    # Dark teal creep, moss flesh: the faction off purple altogether (the arc flamer's violet is Kessler-Hayashi's).
    "teal": {"creep": dict(hue=200, spread=0.6, split=-10, chroma=0.45, gamma=1.3),
             "flesh": dict(hue=125, spread=0.8, split=-25, chroma=1.0, gamma=1.05),
             "tumor": dict(hue=135, spread=0.7, split=-15, chroma=1.0, gamma=1.0)},
}
MASK = (0.025, 0.06)  # chroma below the first is grey (untouched), above the second fully graded
# The creep is ground through and through: no metal in it, and the mask left 62% of it as it was (its low-chroma
# browns): graded whole.
MASKS = {"creep": (-1.0, 0.0), "floor": (-1.0, 0.0), "brain": (0.012, 0.035), "flame": (-1.0, 0.0)}

SOURCES = {
    "pen": ("space-age/graphics/entity/captive-spawner/captive-anim.png", "flesh"),
    "creep": ("space-age/graphics/terrain/artificial-jellynut-soil.png", "creep"),
    "tumor-1": ("space-age/graphics/entity/gleba-spawner/small/spawner-upper-small-1.png", "tumor"),
    "tumor-2": ("space-age/graphics/entity/gleba-spawner/small/spawner-upper-small-2.png", "tumor"),
}
# The clinic (a biolab: a brain under a glass dome; the user, 2026-11-12, of the growth reel: "a weird gray nest, what
# is that?"): its brain graded as the pens' flesh, its glass and metal as they are (its lights layer left alone).
SOURCES["clinic"] = ("space-age/graphics/entity/biolab/biolab-anim.png", "brain")
# Vanilla's flame, four sheets (the fire's and the burning sticker's), for a palette with a flame.
for _k in range(1, 5):
    SOURCES[f"fire-flame-0{_k}"] = (f"base/graphics/entity/fire-flame/fire-flame-0{_k}.png", "flame")
# The floor's sheets (refined concrete's: the tile and its transitions; their masks are shapes, left as they are), for
# a palette with a floor.
for _k in ("", "-inner-corner", "-outer-corner", "-side", "-u", "-o"):
    SOURCES["floor" + _k] = (f"base/graphics/terrain/concrete/refined-concrete{_k}.png", "floor")


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566],
               [0.0883024619, 0.2817188376, 0.6299787005]])
M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099],
               [0.0259040371, 0.7827717662, -0.8086757660]])


def to_oklab(rgb):
    lms = srgb_to_linear(rgb) @ M1.T
    return np.cbrt(lms) @ M2.T


def from_oklab(lab):
    lms = (lab @ np.linalg.inv(M2).T) ** 3
    return linear_to_srgb(lms @ np.linalg.inv(M1).T)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def grade(img, p, mask=MASK):
    a = np.asarray(img.convert("RGBA"), dtype=np.float64) / 255
    rgb, alpha = a[..., :3], a[..., 3]
    lab = to_oklab(rgb)
    L, A, B = lab[..., 0], lab[..., 1], lab[..., 2]
    C = np.hypot(A, B)
    h = np.degrees(np.arctan2(B, A))
    m = (smoothstep(*mask, C) if mask[1] > 0 else np.ones_like(C)) * (alpha > 0.02)
    # The art's own mean organic hue (circular, weighted by chroma and mask).
    w = m * C
    h0 = np.degrees(np.arctan2((w * np.sin(np.radians(h))).sum(), (w * np.cos(np.radians(h))).sum()))
    dh = (h - h0 + 180) % 360 - 180
    nh = p["hue"] + p["spread"] * dh + p["split"] * (L - 0.5) * 2
    # A second stop (hi_hue): the highlights drawn toward it by hi_mix, along the hue circle's shorter way.
    if "hi_hue" in p:
        mix = p["hi_mix"] * smoothstep(0.35, 0.75, L)
        nh = nh + mix * ((p["hi_hue"] - nh + 180) % 360 - 180)
    nC = np.minimum(C * p["chroma"] + p.get("add", 0.0), 0.25)
    nL = np.clip(L, 0, 1) ** p["gamma"]
    out = np.stack([nL, nC * np.cos(np.radians(nh)), nC * np.sin(np.radians(nh))], -1)
    graded = from_oklab(out)
    res = rgb * (1 - m[..., None]) + graded * m[..., None]
    o = np.concatenate([res, alpha[..., None]], -1)
    return Image.fromarray((np.clip(o, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA"), h0, float(m.mean())


def game_data():
    env = os.path.join(os.path.dirname(__file__), "..", "..", "scripts", "env.sh")
    app = subprocess.run(["bash", "-c", f'source "{env}" >/dev/null; printf %s "$APP"'], capture_output=True,
                         text=True).stdout
    return os.path.join(app, "data")


def main():
    name, out = sys.argv[1], sys.argv[2]
    pal = PALETTES[name]
    os.makedirs(out, exist_ok=True)
    data = game_data()
    for key, (src, cls) in SOURCES.items():
        if cls not in pal:
            continue
        img = Image.open(os.path.join(data, src))
        g, h0, cover = grade(img, pal[cls], MASKS.get(cls, MASK))
        g.save(os.path.join(out, key + ".png"), optimize=True)
        print(f"{name} {key}: from mean hue {h0:.0f} to {pal[cls]['hue']}, graded {cover:.0%} of its pixels")


if __name__ == "__main__":
    main()
