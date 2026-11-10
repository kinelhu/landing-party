"""Cut the units out of the matte film (docs/manual/shots/portraits-matte.lua) by difference matting: each still shot on a
flat dark ground and on a white one; where the two differ by all the grounds differ, nothing is there; where they agree,
the unit is opaque. alpha = 1 - mean over channels of (white - dark) / (white ground - dark ground), and the colour
unmixed from the dark still: (dark - (1 - alpha) * dark ground) / alpha. A shadow comes out as a soft, see-through dark.

    uv run --with pillow --with numpy python docs/manual/shots/matte.py <film dir> <out dir>

Writes, in <out dir>:
  cutouts/<unit>.png        the unit at the portraits' three-quarter view, transparent, at PX_TILE px a tile
  turntables/<unit>.png     its eight facings as an animated PNG (full alpha), and <unit>.gif on the mod page's dark
  class/<faction>.png       a faction's units side by side at one scale, smallest at the ends (a class photo), and
                            <faction>-paper.png on the manual's paper
  portraits-in/             the dark facing-0 stills renamed for docs/manual/shots/portraits.py (the manual's cards)
Fails on a unit missing a still.
"""
import glob, json, os, shutil, sys
import numpy as np
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
PX_TILE = 96             # cut-outs, turntables and class photos at one scale: px a tile
FACINGS = 8
FACTION = {"kh": "kessler-hayashi", "gs": "grubstake", "sx": "synthexis", "pl": "player"}
PAPER = (241, 236, 224)
MODPAGE = (46, 46, 46)


def load(f):
    return np.asarray(Image.open(f).convert("RGB")).astype(np.float32)


def ground(kind):
    g = load(os.path.join(src, f"ground-{kind}-z3.png"))
    return np.median(g.reshape(-1, 3), axis=0)


DBG, WBG = ground("dark"), ground("white")
SPAN = np.maximum(1.0, WBG - DBG)
print("grounds", DBG, WBG)


def matte(dark, white):
    a = 1 - np.clip(((white - dark) / SPAN).mean(axis=2), 0, 1)
    a = np.where(a < 0.02, 0, a)                      # (the screenshots' noise on the bare ground)
    col = (dark - (1 - a[..., None]) * DBG) / np.maximum(a[..., None], 1e-3)
    return np.dstack([np.clip(col, 0, 255), a * 255]).astype(np.uint8)


def zoom_of(f):
    return float(f.rsplit("-z", 1)[1][:-4].replace("p", "."))


def bbox(alpha, thr=12):
    ys, xs = np.nonzero(alpha > thr)
    if len(xs) < 30:
        return None
    return xs.min(), ys.min(), xs.max(), ys.max()


units = sorted({os.path.basename(f).split("-f0-dark")[0] for f in glob.glob(os.path.join(src, "lp-*-f0-dark-z*.png"))})
lua = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "portraits-matte.lua")).read()
faction_of = {}
for line in lua.splitlines():
    for u, k in __import__("re").findall(r'\{"(lp-[a-z-]+)", "(kh|gs|sx|pl)"\}', line):
        faction_of[u] = k
faction_of["lp-bred-stomper"] = "sx"
# (The units the book prints a card for: its own LaTeX, as check_images reads it.)
_tex = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Landing-Party.tex")).read()
CARDS = set(__import__("re").findall(r"portraits/(lp-[a-z-]+)", _tex))
for d in ("cutouts", "turntables", "class", "portraits-in", "portraits-in/white"):
    os.makedirs(os.path.join(out, d), exist_ok=True)
missing, cut = [], {}
for u in units:
    facings = [f for f in range(FACINGS) if glob.glob(os.path.join(src, f"{u}-f{f}-dark-z*.png"))]
    zooms = sorted({zoom_of(f) for f in glob.glob(os.path.join(src, f"{u}-f0-dark-z*.png"))}, reverse=True)
    pick = None
    for z in zooms:   # closest first: every facing clear of the frame's edge
        zs = ("%g" % z).replace(".", "p")
        frames = []
        ok = True
        for f in facings:
            d = glob.glob(os.path.join(src, f"{u}-f{f}-dark-z{zs}.png"))
            w = glob.glob(os.path.join(src, f"{u}-f{f}-white-z{zs}.png"))
            if not (d and w):
                ok = False; break
            m = matte(load(d[0]), load(w[0]))
            bb = bbox(m[..., 3])
            H, W = m.shape[:2]
            last = z == zooms[-1]
            # (At the widest zoom, a unit whose gun runs off the frame at some facing is kept, clipped: the howitzer
            # truck's barrel, turned east.)
            if bb is None or (not last and (bb[0] < 8 or bb[1] < 8 or bb[2] > W - 8 or bb[3] > H - 8)):
                ok = False; break
            frames.append(m)
        if ok and frames:
            pick = (z, frames)
            break
    if pick is None:
        missing.append(u); print("NO CUT", u); continue
    z, frames = pick
    # The cut-out: as tight as the unit and its shadow.
    k = PX_TILE / (32 * z)                            # a screenshot at zoom z draws a tile in 32 z px
    def crop(m, b):
        im = Image.fromarray(m[b[1]:b[3], b[0]:b[2]], "RGBA")
        return im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
    b0 = bbox(frames[0][..., 3])
    ims = [crop(frames[0], (b0[0] - 6, b0[1] - 6, b0[2] + 6, b0[3] + 6))]
    ims[0].save(os.path.join(out, "cutouts", u + ".png"), optimize=True)
    # The turntable: one square for every facing (it does not jump), centred on the unit's solid body (alpha near 1: not
    # its shadow, which pulled it off centre, the user: "the gifs are not centered on the unit (they cut to the
    # shadow)"), round the body with a margin and as much shadow as fits in 1.6 times the body's half-size.
    bodies = [bbox(m[..., 3], thr=235) or bbox(m[..., 3]) for m in frames]
    alls = [bbox(m[..., 3]) for m in frames]
    bx0, by0 = min(b[0] for b in bodies), min(b[1] for b in bodies)
    bx1, by1 = max(b[2] for b in bodies), max(b[3] for b in bodies)
    cx, cy = (bx0 + bx1) / 2, (by0 + by1) / 2
    bhalf = max(bx1 - bx0, by1 - by0) / 2
    shalf = max(max(cx - a[0], a[2] - cx, cy - a[1], a[3] - cy) for a in alls)
    half = int(max(bhalf * 1.3, min(shalf * 1.05, bhalf * 1.6)) + 8)
    Hf, Wf = frames[0].shape[:2]
    half = int(min(half, cx, cy, Wf - cx, Hf - cy))
    sq = (int(cx - half), int(cy - half), int(cx + half), int(cy + half))
    turn = [crop(m, sq) for m in frames]
    if len(turn) > 1:
        turn[0].save(os.path.join(out, "turntables", u + ".png"), save_all=True, append_images=turn[1:], duration=160,
                     loop=0, disposal=1)
        gif = []
        for im in turn:
            bg = Image.new("RGBA", im.size, MODPAGE + (255,)); bg.alpha_composite(im)
            gif.append(bg.convert("P", palette=Image.ADAPTIVE))
        gif[0].save(os.path.join(out, "turntables", u + ".gif"), save_all=True, append_images=gif[1:], duration=160, loop=0)
    cut[u] = ims[0]
    # For the manual's cards (portraits.py): the dark facing-0 stills under its names, of the units its cards show only
    # (a portrait the book never prints fails its check_images).
    if u not in CARDS:
        print(f"{u}: no card in the manual"); continue
    for f in glob.glob(os.path.join(src, f"{u}-f0-dark-z*.png")):
        shutil.copy(f, os.path.join(out, "portraits-in", u + "-z" + f.rsplit("-z", 1)[1]))
    # (And their white twins, for portraits.py's light cards.)
    for f in glob.glob(os.path.join(src, f"{u}-f0-white-z*.png")):
        shutil.copy(f, os.path.join(out, "portraits-in", "white", u + "-z" + f.rsplit("-z", 1)[1]))
    print(f"{u}: zoom {z}, {len(ims)} facings, {ims[0].width}x{ims[0].height}")
shutil.copy(os.path.join(src, "ground-dark-z3.png"), os.path.join(out, "portraits-in", "ground-z3.png"))
shutil.copy(os.path.join(src, "ground-white-z3.png"), os.path.join(out, "portraits-in", "white", "ground-z3.png"))
# Class photos: each faction's units at one scale, the tallest in the middle, smaller to each end, overlapping a little.
for key, fname in FACTION.items():
    row = sorted([u for u in cut if faction_of.get(u) == key], key=lambda u: cut[u].height)
    if not row:
        continue
    order = []
    for i, u in enumerate(row):            # smallest outside, tallest centre
        (order.append if i % 2 == 0 else (lambda v: order.insert(0, v)))(u)
    gapx = -int(PX_TILE * 0.35)
    W = sum(cut[u].width for u in order) + gapx * (len(order) - 1) + 40
    H = max(cut[u].height for u in order) + 40
    photo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x = 20
    for u in order:
        im = cut[u]
        photo.alpha_composite(im, (x, H - 20 - im.height))
        x += im.width + gapx
    photo.save(os.path.join(out, "class", fname + ".png"), optimize=True)
    paper = Image.new("RGBA", photo.size, PAPER + (255,)); paper.alpha_composite(photo)
    paper.convert("RGB").save(os.path.join(out, "class", fname + "-paper.png"), optimize=True)
    print("class", fname, len(order), photo.size)
json.dump({"px_tile": PX_TILE, "units": sorted(cut)}, open(os.path.join(out, "cut.json"), "w"), indent=1)
if missing:
    sys.exit("no cut for: " + ", ".join(missing))
