"""Recolour vanilla sprites into each corporation's own graphics (the user, 2026-10-14: "more refined recolored sprites.
Like we did in empirical science. That means custom files. Instead of just tinting the full thing"; "the lander should
also get a nicer recolor").

Run: uv run --with pillow --with numpy python3 scripts/make_sprites.py [--sheet out.png] [--write]

Factorio's `tint` multiplies every pixel, so steel, highlights and shadows all darken towards the colour and a building
looks flat. The user chose a mixed treatment (2026-10-14):
  Serenity   its steel colourised: pixels of low-to-middle saturation in the middle of the value range move towards its
             colour at their own luminance; highlights, shadows and coloured parts (lenses, lamps) stay. Its defences
             (walls, turrets, poles) in a darker grey-blue.
  Grubstake  vanilla's rusty body kept under a light warm wash, its paint repainted: blue and teal panels (the
             assembler's, the turrets') turned amber.
  The lander, the centrepiece, takes both more strongly.
--write recolours every body file of each building (shadows, lights, glows, remnants, circuit connectors left as they
are) into landing-party/graphics/<corp>/<path under graphics/entity> and writes landing-party/graphics/manifest.lua,
which corps.lua reads to point each corporation's prototypes at its files (and drop the whole-sprite tint on them).
--sheet draws a review sheet: vanilla, today's tint, the new recolour, for each corporation.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

DATA = Path.home() / "Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/data"
DUMP = Path.home() / "Library/Application Support/factorio-lp-check/script-output/data-raw-dump.json"
REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "landing-party" / "graphics"

# Serenity in two colours (the user, 2026-10-13; again 2026-10-14: "you threw out the bicolor idea for Serenity?"):
# slate-teal machines, charcoal defences (walls, turrets, poles, lamps, gates).
CORPS = {
    "serenity": {"body": (0.62, 0.80, 1.00), "defence": (0.32, 0.35, 0.38)},
    "grubstake": {"body": (1.00, 0.72, 0.38), "defence": (1.00, 0.72, 0.38)},
}
KINDS = [
    # The lander is the crash site's spaceship (data.lua); the accumulator is the generator.
    ("lp-lander", "container", "crash-site-spaceship", "lander"),
    ("lp-generator", "electric-energy-interface", "electric-energy-interface", "body"),
    ("lp-pylon", "electric-pole", "medium-electric-pole", "defence"),
    ("lp-drill", "mining-drill", "electric-mining-drill", "body"),
    ("lp-bin", "container", "iron-chest", "body"),
    ("lp-fabricator", "assembling-machine", "assembling-machine-2", "body"),
    ("lp-turret", "electric-turret", "laser-turret", "defence"),
    ("lp-gun-turret", "ammo-turret", "gun-turret", "defence"),
    ("lp-radar", "radar", "radar", "body"),
    ("lp-wall", "wall", "stone-wall", "defence"),
    ("lp-flamer", "fluid-turret", "flamethrower-turret", "defence"),
    ("lp-lamp", "lamp", "small-lamp", "defence"),
    ("lp-gate", "gate", "gate", "defence"),
    # Space Age's buildings as the corporations' (the graphics pass, 0.2.173): the files these prototypes draw, not the
    # whole Space Age building (its other states would only add size).
    ("lp-optics-lab", "lab", "lp-optics-lab", "body"),
    ("lp-optics-lab-busy", "animation", "lp-optics-lab-busy", "body"),
    ("lp-line-lab", "lab", "lp-line-lab", "body"),
    ("lp-line-lab-busy", "animation", "lp-line-lab-busy", "body"),
    # (Not the siege lab: the foundry's animation is 128 frames on two sheets, 35 MB recoloured for two corporations; its
    # dark iron and molten orange read as a siege workshop as they are.)
    # (Not the dome projector: its tower is rendered in Kessler-Hayashi's colours, tools/blender.)
    ("lp-uplink", "radar", "lp-uplink", "body"),
]
# Glows repainted to each corporation's colour (a glow is otherwise left as it is): the fusion reactor's red-pink (hue 342 to
# 354, measured) as the uplink's, its own colour read as nobody's.
# Sheets of which only the first frame is drawn (the dome projector: the tesla turret's head at rest), recoloured cropped.
FIRST_FRAME = ("tesla-turret-head-attacking",)
GLOWS = [("__space-age__/graphics/entity/fusion-reactor/fusion-reactor-glow.png", 345, 25)]
ROOTS = {"__base__/graphics/entity/": ("base", ""), "__space-age__/graphics/entity/": ("space-age", "space-age/")}
SKIP = ("shadow", "light", "glow", "remnants", "reflection", "integration", "circuit-connector", "explosion",
        "visualization", "frozen", "underground", "mask")
LUM = np.array([0.299, 0.587, 0.114])


def hsv(rgb):
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    nz = d > 1e-9
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    rm = nz & (mx == r)
    gm = nz & (mx == g) & ~rm
    bm = nz & ~rm & ~gm
    h[rm] = ((g - b)[rm] / d[rm]) % 6
    h[gm] = (b - r)[gm] / d[gm] + 2
    h[bm] = (r - g)[bm] / d[bm] + 4
    s = np.where(mx > 1e-9, d / np.maximum(mx, 1e-9), 0)
    return h * 60, s, mx


def colourise(a, c, strength, sat_max=0.55, dark=1.0):
    """`dark` scales the target's luminance: Serenity's charcoal defences are darker paint, not just a hue."""
    rgb = a[..., :3]
    _, sat, mx = hsv(rgb)
    w = np.clip((sat_max - sat) / 0.2, 0, 1) * np.clip((mx - 0.10) / 0.10, 0, 1) * np.clip((0.95 - mx) / 0.10, 0, 1)
    col = np.array(c)
    target = dark * (rgb @ LUM)[..., None] * col / (col @ LUM)
    out = a.copy()
    out[..., :3] = np.clip(rgb + (target - rgb) * (strength * w)[..., None], 0, 1)
    return out


def repaint(a, centre, half, c, feather=15.0):
    """Pixels whose hue is within `half` of `centre` (and saturated) take colour c at their own luminance."""
    rgb = a[..., :3]
    h, sat, _ = hsv(rgb)
    dist = np.abs((h - centre + 180) % 360 - 180)
    w = np.clip((half + feather - dist) / feather, 0, 1) * np.clip((sat - 0.15) / 0.1, 0, 1)
    col = np.array(c)
    target = (rgb @ LUM)[..., None] * col / (col @ LUM)
    out = a.copy()
    out[..., :3] = np.clip(rgb + (target - rgb) * w[..., None], 0, 1)
    return out


def treat(a, corp, role):
    c = CORPS[corp]
    # The lander (the crash site's spaceship) is painted yellow (hue about 55): that paint is repainted, slate-teal for
    # Serenity, a deeper amber for Grubstake (colourising alone left it yellow under a blue-grey or warm body).
    if role == "lander":
        a = repaint(a, 55, 22, c["body"] if corp == "serenity" else (1.0, 0.55, 0.22))
    if corp == "serenity":
        if role == "lander":
            return colourise(a, c["body"], 1.0, sat_max=0.7)
        if role == "defence":
            return colourise(a, c["defence"], 0.95, sat_max=0.7, dark=0.55)
        return colourise(a, c[role], 0.9)
    a = repaint(a, 205, 35, c["body"])
    return colourise(a, c["body"], 0.85 if role == "lander" else 0.5)


def body_files(proto):
    found = []

    def walk(o):
        if isinstance(o, dict):
            f = o.get("filename")
            if isinstance(f, str):
                found.append((f, o))
            for g in o.get("filenames") or []:
                if isinstance(g, str):
                    found.append((g, o))
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    walk(proto)
    # (A prototype already pointed at a recolour, as the default corporation's are once corps.lua has run: back to its
    # original, else its files fell out of the manifest on the next run, 260 to 248.)
    def original(f):
        for corp in CORPS:
            pre = f"__landing-party__/graphics/{corp}/"
            if f.startswith(pre):
                r = f[len(pre):]
                return ("__space-age__/graphics/entity/" + r[len("space-age/"):]) if r.startswith("space-age/") \
                    else "__base__/graphics/entity/" + r
        return f
    found = [(original(f), o) for f, o in found]
    return [(f, o) for f, o in found if any(f.startswith(r) for r in ROOTS) and not any(w in f for w in SKIP)]


def rel(f):
    """Where a recolour of f goes under graphics/<corp>/: its path below graphics/entity, Space Age's under space-age/."""
    for r, (_, sub) in ROOTS.items():
        if f.startswith(r):
            return sub + f[len(r):]


def resolve(f):
    for r, (mod, _) in ROOTS.items():
        if f.startswith(r):
            return DATA / mod / "graphics" / "entity" / f[len(r):]


def load(f):
    return np.asarray(Image.open(resolve(f)).convert("RGBA")).astype(float) / 255


def save(arr, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray((np.clip(arr, 0, 1) * 255).round().astype(np.uint8), "RGBA").save(path, optimize=True)


def main():
    dump = json.load(open(DUMP))
    write = "--write" in sys.argv
    sheet = sys.argv[sys.argv.index("--sheet") + 1] if "--sheet" in sys.argv else None
    manifest = {corp: set() for corp in CORPS}
    rows = []
    for kind, t, n, role in KINDS:
        files = body_files(dump[t][n])
        if not files:
            print("no body files for", n)
            continue
        if write:
            size_of = {f: (o.get("width"), o.get("height")) for f, o in files}
            for f in sorted({f for f, _ in files}):
                a = load(f)
                if any(k in f for k in FIRST_FRAME) and size_of[f][0]:
                    a = a[:size_of[f][1], :size_of[f][0]]
                for corp in CORPS:
                    save(treat(a, corp, role), OUT / corp / rel(f))
                    manifest[corp].add(f)
        framed = [(f, o) for f, o in files if "width" in o]
        f, o = max(framed, key=lambda x: x[1]["width"] * x[1]["height"]) if framed else files[0]
        x, y, w, h = o.get("x", 0), o.get("y", 0), o.get("width"), o.get("height")
        frame = load(f)[y:y + h, x:x + w] if w else load(f)
        cells = [frame]
        for corp, c in CORPS.items():
            cells.append(frame * np.array(list(c["body" if role == "lander" else role]) + [1]))
            cells.append(treat(frame, corp, role))
        rows.append((kind, cells))
        print(kind, len({f for f, _ in files}), "files")
    if write:
        for f, centre, half in GLOWS:
            a = load(f)
            for corp in CORPS:
                save(repaint(a, centre, half, CORPS[corp]["body"]), OUT / corp / rel(f))
                manifest[corp].add(f)
        # Rendered buildings (tools/blender) another corporation has its own render of, under the same names.
        for d in sorted((OUT / "serenity").iterdir()):
            if d.name in ("mortar", "howitzer", "pacifier"):
                for f in sorted(d.glob("*.png")):
                    for corp in CORPS:
                        if corp != "serenity" and (OUT / corp / d.name / f.name).exists():
                            manifest[corp].add(f"__landing-party__/graphics/serenity/{d.name}/{f.name}")
        lines = ["-- Written by scripts/make_sprites.py: the vanilla files each corporation has its own recolour of.",
                 "return {"]
        for corp, fs in manifest.items():
            lines.append(f"  {corp} = {{")
            for f in sorted(fs):
                to = f.replace("/graphics/serenity/", f"/graphics/{corp}/") if f.startswith("__landing-party__") \
                    else f"__landing-party__/graphics/{corp}/{rel(f)}"
                lines.append(f'    ["{f}"] = "{to}",')
            lines.append("  },")
        lines.append("}")
        (OUT / "manifest.lua").write_text("\n".join(lines) + "\n")
        print("manifest:", sum(len(v) for v in manifest.values()), "files")
    if sheet:
        cw = max(c.shape[1] for _, cs in rows for c in cs)
        ch = max(c.shape[0] for _, cs in rows for c in cs)
        head = 24
        out = Image.new("RGBA", (5 * cw + 120, len(rows) * ch + head), (60, 60, 60, 255))
        d = ImageDraw.Draw(out)
        for i, lab in enumerate(["vanilla", "Serenity tint", "Serenity recolour", "Grubstake tint", "Grubstake recolour"]):
            d.text((120 + i * cw + 4, 6), lab, fill=(255, 255, 255, 255))
        for r, (kind, cells) in enumerate(rows):
            d.text((6, head + r * ch + ch // 2), kind, fill=(255, 255, 255, 255))
            for i, c in enumerate(cells):
                im = Image.fromarray((np.clip(c, 0, 1) * 255).astype(np.uint8), "RGBA")
                out.alpha_composite(im, (120 + i * cw, head + r * ch))
        Path(sheet).parent.mkdir(parents=True, exist_ok=True)
        out.save(sheet)
        print("sheet:", sheet, out.size)


if __name__ == "__main__":
    main()
