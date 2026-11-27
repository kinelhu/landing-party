"""The corporations' landers, modelled: the ship that brought each camp down, its first power source, the centrepiece of
the camp (the last repaint of the vanilla crash-site ship; the first modelled landers, faction_buildings.py, "read as
smooth loaves beside vanilla's hand-made crash ship", 2026-11-10: a lofted hull with nothing on it). Each keeps the
crash-site ship's footprint (collision_box {{-8.7, -3.3}, {6.9, 4.5}}: 15.6 by 7.8 tiles, its middle 0.9 west and 0.6
south of the entity's origin) so the camp's layout is unchanged.

Clay concepts (one grey, the game's camera, the footprint drawn under each):
  gs-barge    Grubstake: a beached bulk freighter, its belly dug in on skids, holds open and a derrick rigged over them,
              scorched bells aft, a ramp down to the south, its cargo spilled.
  gs-capsule  Grubstake: a re-entry capsule tipped on its side, heat shield west, its hatch open, retro pods and cargo
              pods strewn about, a tarp over its nose.
  gs-tug      Grubstake: a stubby tug on legs pushing a cargo sled ploughed into the dirt, containers and a rig on it.
  kh-dropship Kessler-Hayashi: an armoured drop ship on four articulated legs, hull in segmented plates, bridge west,
              twin shrouded engines and a tail fin aft, a ramp south, a sensor mast.
  kh-tower    Kessler-Hayashi: a vertical lander, a module tower on an engine skirt, legs to the footprint's corners,
              a pod either side on walkways.
  kh-delta    Kessler-Hayashi: a flat arrowhead lifting body on three legs, two engine nacelles aft, a clamshell cargo
              door south.
Picked (2026-11-12, by silhouette at game scale): gs-barge and kh-dropship. What the clay and the first material renders
taught: a 16-tile hull's top is the picture from the game's camera, and in paint it read as a pale raft (Grubstake) or a
granite slab (KH): both now carry a dark plated deck over the paint, their flanks plated in courses, and medium parts
(dress) over the decks, lpkit.scatter's being specks at this size. Burns on the ground behind the bells were black
discs on the grass: dropped (the landing draws its own scorch, descent.lua). Review pictures: lander_sheets.py.
Round 2 (the coordinator, 2026-11-12: "not good enough yet": flat areas with specks, a rounded rectangle, mid-grey all over,
a flat lid with boxes on it): hulls tapered with a ridge down the back (chine), yawed and (Grubstake) listing, every facet
the camera sees skinned in uneven bevelled plates over a dark frame (facet_plates: big plates, a sparse layer of small ones
over them, recessed panels), pale trim panels among KH's blue, pipe bundles along the chines, cables between posts, Poly
Haven ducts, valves and boxes for the kit (no crate cubes), oil on Grubstake's deck, a harder sun with less sky. Measured
(lander_sheets.py tone, share of opaque pixels under 25 % and over 75 % luminance): vanilla's crash ship 56 % / 3.3 %,
cargo pad 64 % / 2.4 %; round 5 KH 38 % / 0.8 %, Grubstake 72 % / 0.5 %. The highlights stay short of vanilla's: lpkit's
worn and grimed materials halve the paint's albedo, and vanilla's 3 % are its saturated yellow in the sun.

    Blender -b -P tools/blender/landers.py -- concept <name> <out.png>          (clay, one still with its shadow)
    Blender -b -P tools/blender/landers.py -- build <kh|gs> <out_dir>           (body, glow, shadow; LP_CLAY=1 grey)
    then: uv run --with pillow python tools/blender/sheet.py <out_dir> landing-party-graphics/graphics/<serenity|grubstake>/lander
          uv run --with pillow python tools/blender/lander_sheets.py trim landing-party-graphics/graphics/<corp>/lander   (one frame wide)
          uv run --with pillow --with numpy python tools/blender/shadow_solid.py landing-party-graphics/graphics/<corp>/lander/shadow.png
"""
import math, os, sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh, mathutils
import lpkit, lptex

args = sys.argv[sys.argv.index("--") + 1:]
MODE, WHO, OUT = args[0], args[1], args[2]
CLAY = MODE == "concept" or os.environ.get("LP_CLAY") == "1"
scene = lpkit.reset(); scene.cycles.samples = int(os.environ.get("LP_SAMPLES", 24 if MODE == "concept" else 96))
TEX = os.path.isdir(lptex.TEX) and not CLAY
B, cyl, rod, sph, tor = lpkit.box, lpkit.cyl, lpkit.rod, lpkit.sphere, lpkit.torus
V = mathutils.Vector

# The footprint: the crash-site ship's collision box, Blender's y north.
X0, X1, Y0, Y1 = -8.7, 6.9, -4.5, 3.3
CX, CY = (X0 + X1) / 2, (Y0 + Y1) / 2          # -0.9, -0.6


def palette(f):
    """faction_works.palette's materials (the 5/5 models' family look): KH worn blue-grey, Grubstake grimed ochre and
    CC0 rust plates; and a scorched black for nozzles and burns, a window glass."""
    W = lpkit.palette_worn()
    if f == "kh":
        hull = lpkit.worn("kh-hull", (0.09, 0.14, 0.21), metal=0.35, rough=0.5, seams=3, rivets=False, wear=0.3)
        trim = lpkit.worn("kh-trim", (0.2, 0.22, 0.24), metal=0.4, rough=0.5, seams=2, rivets=False, wear=0.35)
        accent = lpkit.worn("kh-haz", (0.42, 0.34, 0.08), metal=0.2, rough=0.6, seams=8, rivets=False, wear=0.3)
        light = lpkit.mat("kh-light", (0.2, 0.5, 0.6), metal=0.2, rough=0.3, emit=(0.45, 0.85, 1.0), strength=0.0, grime=0.0)
        glass = lpkit.mat("kh-glass", (0.02, 0.035, 0.045), metal=0.6, rough=0.12, emit=(0.3, 0.7, 0.9), strength=0.0, grime=0.0)
    else:
        hull = lpkit.mat("gs-hull", (0.4, 0.23, 0.05), metal=0.3, rough=0.65, grime=0.85)
        trim = lptex.textured("gs-rust", "MetalPlates013", val=0.6, scale=0.8, edge=(0.4, 0.33, 0.25)) if TEX \
            else lpkit.worn("gs-rust", (0.25, 0.11, 0.05), metal=0.5, rough=0.7, seams=6)
        accent = lpkit.worn("gs-red", (0.13, 0.05, 0.03), metal=0.35, rough=0.7, seams=6, rivets=True, wear=0.4)
        light = lpkit.mat("gs-light", (0.6, 0.4, 0.05), metal=0.1, rough=0.3, emit=(1.0, 0.62, 0.15), strength=0.0, grime=0.0)
        glass = lpkit.mat("gs-glass", (0.08, 0.06, 0.03), metal=0.1, rough=0.2, emit=(1.0, 0.55, 0.15), strength=0.0, grime=0.0)
    cloth = lpkit.worn(f + "-cloth", (0.3, 0.25, 0.16), metal=0.0, rough=0.95, seams=14, wear=0.3, streaks=0.6, rivets=False)
    gunmetal = lpkit.worn(f + "-gunmetal", (0.06, 0.06, 0.065), metal=0.25, rough=0.7, seams=3, rivets=False, wear=0.25)
    skid = lpkit.worn(f + "-skid", (0.3, 0.28, 0.24), metal=0.5, rough=0.6, seams=4, rivets=True, wear=0.45)
    scorch = lpkit.mat(f + "-scorch", (0.025, 0.022, 0.02), metal=0.1, rough=0.95, grime=0.4)
    P = {"hull": hull, "trim": trim, "dark": W["dark"], "steel": W["steel"], "accent": accent, "light": light, "glass": glass,
         "rubber": W["rubber"], "hazard": W["hazard"], "cloth": cloth, "gunmetal": gunmetal, "skid": skid, "scorch": scorch}
    if CLAY:
        clay = lpkit.mat("clay", (0.5, 0.5, 0.5), metal=0.0, rough=0.7, grime=0.0)
        dark = lpkit.mat("clay-dark", (0.2, 0.2, 0.2), metal=0.0, rough=0.8, grime=0.0)
        P = {k: (v if k in ("light", "glass") else (dark if k in ("scorch", "dark") else clay)) for k, v in P.items()}
    return P


P = palette(WHO.split("-")[0])


def tones(name, rgb, ks, maker):
    return [maker(f"{name}-{i}", tuple(c * k for c in rgb)) for i, k in enumerate(ks)]


# Plate materials in a few tones each (one tone over a 16-tile hull read as a slab): the hull's paint, its trim, and
# Grubstake's deck plate (dark, rusted, the dirtiest part of the ship).
if CLAY:
    PLATES = {k: [P["hull"]] * 3 for k in ("gs-hull", "gs-deck", "kh-hull", "kh-trim", "gs-bright", "kh-bright")}
else:
    PLATES = {
        "gs-hull": tones("gs-plate", (0.55, 0.33, 0.08), (0.7, 1.0, 1.35), lambda n, c: lpkit.mat(n, c, metal=0.3, rough=0.65, grime=0.7)),
        "gs-deck": tones("gs-deck", (0.2, 0.18, 0.15), (0.7, 1.0, 1.5), lambda n, c: lpkit.worn(n, c, metal=0.5, rough=0.75, seams=4, rivets=True, wear=0.45, streaks=0.35)),
        "kh-hull": tones("kh-plate", (0.1, 0.16, 0.25), (0.75, 1.0, 1.35), lambda n, c: lpkit.worn(n, c, metal=0.35, rough=0.5, seams=3, rivets=False, wear=0.3, streaks=0.3)),
        # (The pale trim of KH's fabricator, rated 5: pale panels on the dark frame give the contrast one blue-grey could not.)
        "kh-trim": tones("kh-trimplate", (0.5, 0.52, 0.52), (0.8, 1.15), lambda n, c: lpkit.worn(n, c, metal=0.4, rough=0.5, seams=2, rivets=False, wear=0.35, streaks=0.3)),
        # Bare steel, a plate in eight: the highlights vanilla's paint carries (3 % of its pixels over 75 % luminance, ours 0.5 %).
        "gs-bright": tones("gs-bright", (0.5, 0.48, 0.44), (1.0,), lambda n, c: lpkit.worn(n, c, metal=0.85, rough=0.3, seams=5, rivets=True, wear=0.5)),
        "kh-bright": tones("kh-bright", (0.42, 0.45, 0.5), (1.0,), lambda n, c: lpkit.worn(n, c, metal=0.8, rough=0.3, seams=3, rivets=False, wear=0.5)),
    }


def group(fn):
    before = set(scene.objects); fn(); return [o for o in scene.objects if o not in before]


# --- Props: Poly Haven's CC0 models (LP_PROPS), toned into the palette (faction_works.prop); none without them.
PROPS = os.path.expanduser(os.environ.get("LP_PROPS", "~/lp-props"))
_props = {}
def prop(name, asset, at, rz=0.0, k=1.0):
    path = f"{PROPS}/{asset}/{asset}_1k.blend"
    if CLAY or not os.path.exists(path): return None
    key = (asset, name)
    if key not in _props:
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = [name] if name in src.objects else []
        objs = [o for o in dst.objects if o]
        if not objs: return None
        base = objs[0]
        for slot in base.material_slots:
            m = slot.material
            if not m or not m.use_nodes or m.get("lp_toned"): continue
            nt = m.node_tree
            bsdf = next((x for x in nt.nodes if x.type == "BSDF_PRINCIPLED"), None)
            if not bsdf or not bsdf.inputs["Base Color"].is_linked: continue
            link = bsdf.inputs["Base Color"].links[0]
            hs = nt.nodes.new("ShaderNodeHueSaturation")
            hs.inputs["Saturation"].default_value = 0.45; hs.inputs["Value"].default_value = 0.6
            nt.links.new(link.from_socket, hs.inputs["Color"]); nt.links.new(hs.outputs["Color"], bsdf.inputs["Base Color"])
            m["lp_toned"] = True
        base.parent = None
        _props[key] = base
        o = base
    else:
        o = _props[key].copy()
    scene.collection.objects.link(o)
    o.location = at; o.rotation_euler = (o.rotation_euler[0], o.rotation_euler[1], math.radians(rz)); o.scale = (2.5 / 1.5 * k,) * 3
    return o


# --- Forms --------------------------------------------------------------------------------------------------------
def loft_x(secs, m, bevel=0.06, cap=True):
    """A hull through cross-sections along x: [(x, [(y, z), ...]), ...], every ring the same count of points."""
    bm = bmesh.new()
    rings = [[bm.verts.new((x, y, z)) for y, z in pts] for x, pts in secs]
    n = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    if cap:
        bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("loft"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("loft", me); scene.collection.objects.link(o); me.materials.append(m)
    if bevel:
        md = o.modifiers.new("b", "BEVEL"); md.width = bevel; md.segments = 3; md.limit_method = "ANGLE"
    return o


def ring(cy, w, h, z0, c=0.5, top=1.0):
    """A chamfered box section about y = cy, w wide, h high from z0; c its chamfer, top the top's width as a share."""
    tw = w * top
    return [(cy - w / 2 + c, z0), (cy + w / 2 - c, z0), (cy + w / 2, z0 + c), (cy + w / 2, z0 + h - c),
            (cy + tw / 2 - c * 0.6, z0 + h), (cy - tw / 2 + c * 0.6, z0 + h), (cy - w / 2, z0 + h - c), (cy - w / 2, z0 + c)]


def octo(cy, w, h, z0, c):
    """A regular-ish octagon section (an armoured hull's)."""
    return [(cy - w / 2 + c, z0), (cy + w / 2 - c, z0), (cy + w / 2, z0 + c), (cy + w / 2, z0 + h - c),
            (cy + w / 2 - c, z0 + h), (cy - w / 2 + c, z0 + h), (cy - w / 2, z0 + h - c), (cy - w / 2, z0 + c)]


def cone(x, y, z, r0, r1, L, m, axis="x", verts=28, open_end=False):
    """A cone along an axis, r0 at its start and r1 at its end (east for x, north for y, up for z)."""
    rot = {"x": (0, math.pi / 2, 0), "y": (-math.pi / 2, 0, 0), "z": (0, 0, 0)}[axis]
    d = {"x": (L / 2, 0, 0), "y": (0, L / 2, 0), "z": (0, 0, L / 2)}[axis]
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r0, radius2=r1, depth=L, location=(x + d[0], y + d[1], z + d[2]),
                                    rotation=rot, end_fill_type="NOTHING" if open_end else "NGON")
    o = bpy.context.object; o.data.materials.append(m); return o


def bell(x, y, z, r0, r1, L, P):
    """A scorched retro nozzle pointing east from x: its shell open at the mouth, a dark throat inside, a lip ring."""
    cone(x, y, z, r0, r1, L, P["gunmetal"], open_end=True)
    cone(x + 0.04, y, z, r0 * 0.75, r1 * 0.9, L * 0.96, P["scorch"])
    tor(r1 * 0.98, 0.05, x + L, y, z, P["trim"]).rotation_euler = (0, math.pi / 2, 0)
    tor(r0 * 1.15, 0.07, x, y, z, P["dark"]).rotation_euler = (0, math.pi / 2, 0)


def lie(r, L, x, y, z, m, axis="x", verts=16):
    rot = (0, math.pi / 2, 0) if axis == "x" else (math.pi / 2, 0, 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=L, location=(x, y, z), rotation=rot)
    o = bpy.context.object; o.data.materials.append(m); return o


def pipe(pts, r, m, flange=None):
    for a, b in zip(pts, pts[1:]):
        rod(a, b, r, m, verts=12)
    for p in pts[1:-1] if flange else ():
        sph(r * 1.25, p[0], p[1], p[2], flange)


def cable(p0, p1, sag, m, r=0.012, n=8):
    """A cable hung from p0 to p1, sagging."""
    pts = []
    for j in range(n + 1):
        u = j / n
        pts.append((p0[0] + (p1[0] - p0[0]) * u, p0[1] + (p1[1] - p0[1]) * u, p0[2] + (p1[2] - p0[2]) * u - sag * math.sin(u * math.pi)))
    for a, b in zip(pts, pts[1:]): rod(a, b, r, m, verts=6)


def plate(sx, sy, t, x, y, z, m, tilt=0.0, rot=0.0, bevel=0.01):
    """A plate sx by sy, t thick, its centre at (x, y, z), tilted about x (a ramp, a lid) and turned about z."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z), rotation=(tilt, 0, rot))
    o = bpy.context.object; o.scale = (sx, sy, t)
    if bevel:
        md = o.modifiers.new("b", "BEVEL"); md.width = bevel; md.segments = 2
    o.data.materials.append(m); return o


def ramp(x, w, y_top, z_top, y_foot, P, m=None):
    """A ramp w wide at x, from the hull's side (y_top, z_top) down to the ground at y_foot (south of it), hazard
    stripes along its edges, its foot plate."""
    L = math.hypot(y_top - y_foot, z_top)
    a = math.atan2(z_top, y_top - y_foot)
    o = plate(w, L, 0.12, x, (y_top + y_foot) / 2, z_top / 2 + 0.06, m or P["skid"], tilt=a, bevel=0.02)
    for sx in (-1, 1):
        plate(0.12, L * 0.96, 0.06, x + sx * (w / 2 - 0.08), (y_top + y_foot) / 2, z_top / 2 + 0.16, P["accent"], tilt=a, bevel=0.0)
    for k in range(int(L / 0.45)):
        u = (k + 0.5) / int(L / 0.45)
        plate(w * 0.9, 0.05, 0.03, x, y_foot + (y_top - y_foot) * u, z_top * u + 0.14, P["dark"], tilt=a, bevel=0.0)
    B(w + 0.4, 0.5, 0.06, x, y_foot - 0.2, 0, P["skid"], bevel=0.01)
    return o


def leg(hip, knee, foot, P, r=0.2):
    """An articulated landing leg: an upper strut from the hip to the knee, a piston beside it, the lower strut to the
    pad, the pad on the ground."""
    hx, hy, hz = hip; kx, ky, kz = knee; fx, fy = foot
    rod((hx, hy, hz), (kx, ky, kz), r, P["steel"], verts=12)
    rod((hx + (kx - hx) * 0.15, hy + (ky - hy) * 0.15, hz + 0.45), (kx, ky, kz + 0.25), r * 0.45, P["trim"], verts=10)
    sph(r * 1.3, kx, ky, kz, P["dark"])
    rod((kx, ky, kz), (fx, fy, 0.22), r * 0.85, P["gunmetal"], verts=12)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.62, depth=0.2, location=(fx, fy, 0.1), rotation=(0, 0, math.pi / 8))
    o = bpy.context.object; o.data.materials.append(P["skid"])
    md = o.modifiers.new("b", "BEVEL"); md.width = 0.04; md.segments = 2
    cyl(0.3, 0.1, fx, fy, 0.2, P["dark"], verts=8)


def crates(x, y, z, n, rng, mats, k=1.0):
    for i in range(n):
        cx, cy = x + (i % 2) * 0.62 * k + rng.uniform(-0.05, 0.05), y + ((i // 2) % 2) * 0.62 * k
        cz = z + (i // 4) * 0.56 * k
        B(0.58 * k, 0.58 * k, 0.54 * k, cx, cy, cz, rng.choice(mats), rot=rng.uniform(-0.25, 0.25), bevel=0.02)


def drums(x, y, z, n, rng, mats, k=1.0):
    for i in range(n):
        a = i * 2.4
        cx, cy = x + math.cos(a) * 0.36 * k * (i > 0), y + math.sin(a) * 0.36 * k * (i > 0)
        cyl(0.22 * k, 0.64 * k, cx, cy, z, rng.choice(mats), verts=14); tor(0.22 * k, 0.015, cx, cy, z + 0.44 * k, P["dark"])


def scorch_ring(x, y, r, P, rx=1.0):
    """A burn on the ground: a flat dark disc (the retro flames' mark), stretched along x."""
    o = cyl(r, 0.012, x, y, 0.0, P["scorch"], verts=28); o.scale = (rx, 1.0, 1.0); return o


def lamp(x, y, z, P, r=0.1, post=0.0):
    if post:
        rod((x, y, z - post), (x, y, z), 0.03, P["steel"], verts=6)
    sph(r, x, y, z, P["light"])


def hull_width(secs, x):
    """The width of a lofted hull's section at x (its rings' y extent), interpolated."""
    xs = [s[0] for s in secs]
    ws = [max(p[0] for p in s[1]) - min(p[0] for p in s[1]) for s in secs]
    zs = [max(p[1] for p in s[1]) for s in secs]
    bs = [min(p[1] for p in s[1]) for s in secs]
    for (xa, wa, za, ba), (xb, wb, zb, bb) in zip(zip(xs, ws, zs, bs), zip(xs[1:], ws[1:], zs[1:], bs[1:])):
        if xa <= x <= xb:
            u = (x - xa) / (xb - xa)
            return wa + (wb - wa) * u, za + (zb - za) * u, ba + (bb - ba) * u
    return ws[-1], zs[-1], bs[-1]


# --- Grubstake ----------------------------------------------------------------------------------------------------
def dress(rng, spots, P, mats, n, k=1.0):
    """Medium parts over a region (lpkit.scatter's are specks on a 16-tile hull): vents, boxes, drums, pipe stubs,
    hatches, half a tile to a tile across, seeded over spots [(x0, x1, y0, y1, z), ...]."""
    for _ in range(n):
        x0, x1, y0, y1, z = rng.choice(spots)
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        kind = rng.random()
        if kind < 0.3:
            B(rng.uniform(0.4, 0.9) * k, rng.uniform(0.4, 0.8) * k, rng.uniform(0.2, 0.5) * k, x, y, z, rng.choice(mats), rot=rng.choice((0, math.pi / 2)), bevel=0.02)
        elif kind < 0.5:
            w = rng.uniform(0.5, 0.9) * k
            B(w, w * 0.6, 0.08, x, y, z, P["dark"], rot=rng.choice((0, math.pi / 2)), bevel=0.01)
            for j in range(4): B(w * 0.85, 0.05, 0.05, x, y - w * 0.22 + j * w * 0.15, z + 0.08, P["steel"], bevel=0.0)
        elif kind < 0.65:
            cyl(rng.uniform(0.15, 0.3) * k, rng.uniform(0.3, 0.7) * k, x, y, z, rng.choice(mats), verts=14)
        elif kind < 0.8:
            r = rng.uniform(0.04, 0.07)
            pipe([(x, y, z), (x, y, z + rng.uniform(0.3, 0.6)), (x + rng.uniform(-0.8, 0.8), y + rng.uniform(-0.5, 0.5), z + rng.uniform(0.3, 0.6))], r, P["steel"], P["dark"])
        else:
            w = rng.uniform(0.5, 0.8) * k
            B(w, w, 0.1, x, y, z, P["trim"], rot=rng.uniform(0, 0.3), bevel=0.01); cyl(0.06, 0.08, x, y, z + 0.1, P["dark"], verts=8)


def facet_plates(xa, xb, p0, p1, centre, mats, rng, size=0.9, t=0.05, gap=0.08, bevel=0.025, skip=0.0, recess=0.0, dark=None, ny=None,
                 end=None, jitter=0.35, lift=0.0):
    """A planar facet of a hull (the edge p0 to p1 of its section, in (y, z), run from xa to xb along x; `end` the same
    edge at xb where the hull tapers) skinned with bevelled plates, their columns and rows of uneven size (jitter; a
    regular grid read as tiles), dark gaps between them (the frame under shows), some left out (skip) and some recessed
    (a dark panel flush with the frame): the mid-frequency detail vanilla's hulls carry, where a lofted paint read as a
    slab (the coordinator's round 2, 2026-11-12)."""
    (y0a, z0a), (y1a, z1a) = p0, p1
    (y0b, z0b), (y1b, z1b) = end or (p0, p1)
    La = math.hypot(y1a - y0a, z1a - z0a); Lb = math.hypot(y1b - y0b, z1b - z0b)
    if max(La, Lb) < 0.15 or xb - xa < 0.15: return
    nx = max(1, round((xb - xa) / size)); ny = ny or max(1, round(max(La, Lb) / size))
    def splits(n):
        w = [rng.uniform(1 - jitter, 1 + jitter) for _ in range(n)]; s = sum(w); acc = [0.0]
        for v in w: acc.append(acc[-1] + v / s)
        return acc
    cx, cys = splits(nx), splits(ny)
    for i in range(nx):
        ux = (cx[i] + cx[i + 1]) / 2; x = xa + (xb - xa) * ux; lx = (xb - xa) * (cx[i + 1] - cx[i])
        y0, z0 = y0a + (y0b - y0a) * ux, z0a + (z0b - z0a) * ux
        y1, z1 = y1a + (y1b - y1a) * ux, z1a + (z1b - z1a) * ux
        dy, dz = y1 - y0, z1 - z0; L = math.hypot(dy, dz)
        if L < 0.1: continue
        uy, uz = dy / L, dz / L
        ny_, nz_ = uz, -uy
        if ny_ * ((y0 + y1) / 2 - centre[0]) + nz_ * ((z0 + z1) / 2 - centre[1]) < 0: ny_, nz_ = -ny_, -nz_
        a = math.atan2(uz, uy)
        for j in range(ny):
            r = rng.random()
            if r < skip: continue
            u = L * (cys[j] + cys[j + 1]) / 2; ly = L * (cys[j + 1] - cys[j])
            if r < skip + recess:
                plate(lx - gap, ly - gap, 0.012, x, y0 + uy * u + ny_ * 0.006, z0 + uz * u + nz_ * 0.006, dark or P["dark"], tilt=a, bevel=0.0)
                continue
            y = y0 + uy * u + ny_ * (t / 2 + lift); z = z0 + uz * u + nz_ * (t / 2 + lift)
            plate(max(0.1, lx - gap), max(0.1, ly - gap), t, x, y, z, rng.choice(mats), tilt=a, bevel=bevel)


def chine(cy, w, h, z0, c, ridge=0.0):
    """An octagon section with its top raised to a ridge along the middle (nine points): two top facets that grade the
    light from the game's camera where a flat lid read as a slab."""
    return [(cy - w / 2 + c, z0), (cy + w / 2 - c, z0), (cy + w / 2, z0 + c), (cy + w / 2, z0 + h - c),
            (cy + w / 2 - c, z0 + h), (cy, z0 + h + ridge), (cy - w / 2 + c, z0 + h), (cy - w / 2, z0 + h - c), (cy - w / 2, z0 + c)]


def stain(x, y, z, r, rng, m):
    """An oil stain: a flat dark disc, stretched a little, on a deck."""
    o = cyl(r, 0.006, x, y, z, m, verts=20); o.scale = (rng.uniform(0.7, 1.4), 1.0, 1.0); o.rotation_euler.z = rng.uniform(0, 3)


def rooted(objs, at, rot):
    """Objects parented to an empty at `at`, turned by rot (roll about x, pitch about y, yaw about z, degrees)."""
    bpy.ops.object.empty_add(location=at); root = bpy.context.object
    for o in objs:
        if o.parent is None:
            o.parent = root; o.matrix_parent_inverse = root.matrix_world.inverted()
    root.rotation_euler = tuple(math.radians(v) for v in rot)
    bpy.context.view_layer.update()
    return root


def gs_barge(detail=True):
    """A beached bulk freighter, listing and dug in: a riveted barge hull, its bow raked up west and its stern narrowing
    aft, on two skids, its crowned deck skinned in scrap plate (the dirtiest part of it: oil, mud, holes), the two holds
    open with their lids thrown back and a derrick rigged over them, a wheelhouse forward with a soot stack and a torn
    fin, an engine house aft over three scorched bells in cowls, a fuel tank slung on the north flank, a ramp down to
    the south and the prospecting kit (props) spilled round its foot. Yawed and listing: a hard landing, not a box."""
    rng = random.Random(7)
    cy = CY
    pm = PLATES
    secs = [(-8.5, chine(cy, 1.8, 1.8, 1.3, 0.4, 0.15)), (-7.2, chine(cy, 3.8, 3.0, 0.6, 0.5, 0.2)),
            (-5.2, chine(cy, 5.4, 3.8, 0.2, 0.55, 0.25)), (-1.5, chine(cy, 5.8, 3.9, 0.12, 0.55, 0.25)),
            (2.5, chine(cy, 5.6, 3.85, 0.14, 0.55, 0.25)), (4.6, chine(cy, 4.8, 3.5, 0.3, 0.5, 0.2)),
            (5.9, chine(cy, 3.6, 2.8, 0.6, 0.45, 0.15))]
    def top(x): return hull_width(secs, x)[1]
    def ship():
        hull = loft_x(secs, P["dark"], bevel=0.04)                            # the frame: dark, seen in the plates' gaps
        # The skin: plates over each facet the camera sees, segment by segment (constant sections between -5.2 and 2.5,
        # the tapers skinned with the paint's own loft).
        loft_x(secs[:3], P["hull"], bevel=0.06); loft_x(secs[4:], P["hull"], bevel=0.06)
        for xa, xb, s in ((-5.2, -1.5, secs[2][1]), (-1.5, 2.5, secs[3][1])):
            ctr = (cy, 2.0)
            deck = [pm["gs-deck"][0], pm["gs-deck"][1], pm["gs-deck"][2], pm["gs-hull"][0], pm["gs-hull"][1], pm["gs-hull"][2], P["skid"], pm["gs-bright"][0]]
            facet_plates(xa, xb, s[4], s[5], ctr, deck, rng, size=1.5, t=0.06, gap=0.1, skip=0.04, recess=0.08, dark=P["scorch"], ny=2, jitter=0.45)
            facet_plates(xa, xb, s[5], s[6], ctr, deck, rng, size=1.5, t=0.06, gap=0.1, skip=0.04, recess=0.08, dark=P["scorch"], ny=2, jitter=0.45)
            facet_plates(xa, xb, s[4], s[5], ctr, deck + [P["accent"], P["dark"]], rng, size=0.5, t=0.04, gap=0.08, skip=0.7, ny=4, lift=0.06)
            facet_plates(xa, xb, s[5], s[6], ctr, deck + [P["accent"], P["dark"]], rng, size=0.5, t=0.04, gap=0.08, skip=0.7, ny=4, lift=0.06)
            side = [pm["gs-hull"][0], pm["gs-hull"][1], pm["gs-hull"][2], pm["gs-hull"][2], P["trim"], P["accent"], P["skid"], pm["gs-bright"][0]]
            facet_plates(xa, xb, s[6], s[7], ctr, side, rng, size=1.2, t=0.07, gap=0.12, skip=0.05, recess=0.06, ny=1, jitter=0.45)
            facet_plates(xa, xb, s[7], s[8], ctr, side, rng, size=1.3, t=0.07, gap=0.12, skip=0.05, recess=0.1, ny=2, jitter=0.45)
            facet_plates(xa, xb, s[7], s[8], ctr, side + [P["dark"]], rng, size=0.45, t=0.04, gap=0.08, skip=0.72, ny=5, lift=0.07)
            facet_plates(xa, xb, s[8], s[0], ctr, [P["skid"], P["skid"], P["trim"]], rng, size=1.0, t=0.06, gap=0.1, ny=1)
        # The tapers fore and aft, plated the same way but sparser (the paint shows through).
        for xa, xb, A, Bk in ((-7.2, -5.2, secs[1][1], secs[2][1]), (2.5, 4.6, secs[4][1], secs[5][1]), (4.6, 5.9, secs[5][1], secs[6][1])):
            ctr = (cy, 2.0)
            for i, j, mats, n_, rec, sk in ((4, 5, deck, 2, 0.08, 0.15), (5, 6, deck, 2, 0.08, 0.15), (6, 7, side, 1, 0.05, 0.2), (7, 8, side, 2, 0.08, 0.2)):
                facet_plates(xa, xb, A[i], A[j], ctr, mats, rng, size=1.0, t=0.06, gap=0.11, skip=sk, recess=rec, dark=P["scorch"], ny=n_, end=(Bk[i], Bk[j]))
        # Ribs down the flank between the plates, a gunwale rail, the bow and stern tapers' patches.
        for x in [-7.4 + k * 1.35 for k in range(10)]:
            w, zt, zb = hull_width(secs, x)
            B(0.14, 0.14, zt - zb - 0.6, x, cy - w / 2 - 0.06, zb + 0.25, P["dark"], bevel=0.01)
        for x in [-7.6 + k * 1.3 for k in range(11)]:
            w, zt, zb = hull_width(secs, x)
            B(1.2, 0.14, 0.18, x, cy - w / 2 - 0.04, zt - 0.32, P["trim"], bevel=0.01)
        for k in range(7):
            x = rng.choice((rng.uniform(-7.8, -5.4), rng.uniform(2.7, 5.6))); w, zt, zb = hull_width(secs, x)
            plate(rng.uniform(0.7, 1.3), 0.07, rng.uniform(0.6, 1.1), x, cy - w / 2 - 0.04, zb + rng.uniform(0.8, zt - zb - 0.9),
                  rng.choice((P["trim"], P["accent"], P["skid"], pm["gs-hull"][1])), rot=rng.uniform(-0.08, 0.08), bevel=0.01)
        # Oil and mud on the deck, hoses lying across it, a hatch or two.
        for k in range(9):
            x = rng.uniform(-6.5, 3.5); stain(x, cy + rng.uniform(-2.0, 2.0), top(x) + 0.09, rng.uniform(0.25, 0.6), rng, P["scorch"])
        pipe([(-5.4, cy - 1.9, top(-5.4) + 0.1), (-3.0, cy - 2.2, top(-3.0) + 0.1), (0.6, cy - 2.1, top(0.6) + 0.1), (2.6, cy - 1.6, top(2.6) + 0.1)], 0.05, P["rubber"])
        pipe([(2.8, cy + 2.0, top(2.8) + 0.1), (1.2, cy + 1.6, top(1.2) + 0.1), (-0.6, cy + 2.2, top(-0.6) + 0.1)], 0.045, P["rubber"])
        # Skids under the belly.
        for sy in (-1, 1):
            B(11.0, 0.5, 0.45, -1.2, cy + sy * 2.1, 0.0, P["skid"], bevel=0.04)
        # The holds: a coaming round each, the well dark within, the lid thrown back and leaning north, kit still in it.
        for hx in (-3.6, 0.4):
            zt = top(hx)
            B(3.0, 2.4, 0.28, hx, cy + 0.3, zt - 0.02, P["dark"], bevel=0.02)
            B(2.7, 2.1, 0.02, hx, cy + 0.3, zt + 0.26, P["scorch"], bevel=0.0)
            for sx in (-1, 1):
                B(0.12, 2.4, 0.34, hx + sx * 1.45, cy + 0.3, zt + 0.26, P["trim"], bevel=0.005)
            plate(2.9, 2.3, 0.1, hx, cy + 2.1, zt + 1.0, P["trim"], tilt=math.radians(-64), bevel=0.01)
            for k in range(4): B(2.7, 0.05, 0.05, hx, cy + 1.55 + k * 0.42, zt + 0.55 + k * 0.4, P["dark"], tilt=0, bevel=0.0) if False else None
            drums(hx - 0.8, cy, zt + 0.26, 3, rng, [P["accent"], P["steel"], P["hull"]], 1.0)
            prop("small_lpg_tank" if hx < 0 else "propane_tank", "small_lpg_tank" if hx < 0 else "propane_tank", (hx + 0.7, cy + 0.2, zt + 0.26), 30, 0.6)
            lie(0.1, 2.2, hx + 0.3, cy - 0.6, zt + 0.36, P["steel"], "x", 10); lie(0.1, 2.0, hx + 0.1, cy - 0.4, zt + 0.52, P["trim"], "x", 10)
        # The derrick: an A-frame over the holds, a back stay, a boom swung out south-east with its cable and a slung tank.
        ax, az = -1.6, top(-1.6) + 4.4
        for sy in (-1, 1):
            rod((-1.2, cy + sy * 2.3, top(-1.2)), (ax, cy, az), 0.09, P["steel"], verts=8)
            cyl(0.14, 0.5, -1.2, cy + sy * 2.3, top(-1.2) - 0.1, P["dark"], verts=8)
        rod((ax, cy, az), (-5.6, cy + 0.4, top(-5.6)), 0.03, P["rubber"], verts=6)
        sph(0.18, ax, cy, az, P["dark"])
        bx, by, bz = 2.4, cy - 3.6, top(1.0) + 2.0
        rod((-0.8, cy, top(-0.8) + 0.3), (bx, by, bz), 0.1, P["trim"], verts=8)
        cyl(0.32, 0.45, -0.8, cy, top(-0.8), P["dark"], verts=12)
        rod((ax, cy, az), (bx, by, bz), 0.02, P["rubber"], verts=6)
        rod((bx, by, bz), (bx, by, bz - 1.5), 0.02, P["rubber"], verts=6)
        lie(0.4, 1.1, bx, by, bz - 1.9, P["accent"], "y", 16); tor(0.41, 0.03, bx, by, bz - 1.9, P["dark"]).rotation_euler = (0, math.pi / 2, 0)
        lamp(ax, cy, az + 0.25, P, 0.12)
        # The wheelhouse forward: a plated cabin, its windows lit amber, a soot-streaked stack, an aerial, a torn fin.
        wx = -6.3; wz = top(wx)
        B(2.2, 2.6, 1.3, wx, cy + 0.1, wz - 0.1, pm["gs-hull"][1], bevel=0.04)
        B(2.3, 2.7, 0.12, wx, cy + 0.1, wz + 1.2, P["trim"], bevel=0.02)
        for k in range(3):
            B(0.45, 0.04, 0.34, wx - 0.7 + k * 0.7, cy - 1.23, wz + 0.55, P["glass"], bevel=0.0)
        B(0.04, 1.4, 0.34, wx - 1.13, cy + 0.1, wz + 0.55, P["glass"], bevel=0.0)
        for k in range(4): B(2.2, 0.04, 0.06, wx, cy - 1.25, wz + 0.1 + k * 0.3, P["dark"], bevel=0.0)
        cyl(0.32, 2.2, wx + 1.9, cy + 0.6, top(wx + 1.9) - 0.1, P["gunmetal"], verts=14)
        tor(0.34, 0.05, wx + 1.9, cy + 0.6, top(wx + 1.9) + 2.1, P["trim"])
        rod((wx - 0.6, cy + 0.9, wz + 1.3), (wx - 0.8, cy + 1.0, wz + 3.4), 0.025, P["steel"], verts=6)
        cone(wx + 0.5, cy + 0.9, wz + 1.5, 0.04, 0.36, 0.2, P["skid"], axis="z", open_end=True).rotation_euler = (math.radians(125), 0, math.radians(-35))
        lamp(wx + 0.5, cy - 0.9, wz + 1.65, P, 0.1, post=0.3)
        o = plate(1.9, 0.12, 1.7, wx - 1.6, cy + 1.2, wz + 0.6, pm["gs-hull"][0], bevel=0.02); o.rotation_euler = (math.radians(20), math.radians(35), 0)
        plate(1.6, 0.14, 0.25, wx - 1.5, cy + 1.2, wz + 1.0, P["accent"], bevel=0.0).rotation_euler = (math.radians(20), math.radians(35), 0)
        # The bow: a dozer-blade nose plate dug in.
        o = plate(0.12, 2.0, 1.5, -8.6, cy, 1.5, P["skid"], bevel=0.02); o.rotation_euler.y = math.radians(-20)
        # The stern: an engine house over the bells, its vents and stacks, the bells in their cowls, a tail fin.
        ex = 4.3; ez = top(ex)
        B(2.6, 3.8, 1.1, ex, cy, ez - 0.1, P["trim"], bevel=0.04)
        for k in range(4): B(0.5, 0.9, 0.1, ex - 0.9 + k * 0.6, cy + 1.1, ez + 1.0, P["dark"], bevel=0.01)
        for yy in (-0.9, 0.2):
            cyl(0.22, 1.1, ex + 0.5, cy + yy, ez + 1.0, P["gunmetal"], verts=12); tor(0.24, 0.04, ex + 0.5, cy + yy, ez + 2.05, P["trim"])
        prop("modular_airduct_circular_fan", "modular_airduct_circular_01", (ex - 0.8, cy - 1.2, ez + 1.0), 0, 0.8)
        for k, yy in enumerate((-1.3, 0.0, 1.3)):
            z = 1.6 + (0.3 if k == 1 else 0)
            cyl(0.78, 1.0, 5.5, cy + yy, z, P["gunmetal"], verts=24, rot=(0, math.pi / 2, 0))
            bell(6.0, cy + yy, z, 0.4, 0.68, 1.2, P)
        for k in range(5):
            B(0.5, 0.8, 0.08, 5.5, cy - 1.8 + k * 0.9, 3.4, P["trim"], bevel=0.005)
        plate(2.4, 0.14, 2.4, ex + 0.3, cy - 0.3, ez + 2.1, pm["gs-hull"][2], bevel=0.02).rotation_euler.y = math.radians(-28)
        plate(2.1, 0.18, 0.3, ex + 0.5, cy - 0.3, ez + 2.5, P["accent"], bevel=0.0).rotation_euler.y = math.radians(-28)
        lamp(ex - 0.5, cy - 0.3, ez + 3.3, P, 0.1)
        # A fuel tank slung on the north flank aft, its straps and a pipe forward along the chine.
        lie(0.7, 3.2, 2.8, cy + 3.15, 2.3, P["accent"], "x", 20)
        for x in (1.8, 3.8): tor(0.72, 0.04, x, cy + 3.15, 2.3, P["dark"]).rotation_euler = (0, math.pi / 2, 0)
        for x in (1.8, 3.8): B(0.2, 0.9, 1.2, x, cy + 2.75, 1.0, P["skid"], bevel=0.02)
        # The ramp south from the hold's flank, the opening dark behind it; hoses along the flank.
        rx = 2.2; w, zt, zb = hull_width(secs, rx)
        B(2.4, 0.3, 2.2, rx, cy - w / 2 + 0.1, zb + 0.4, P["scorch"], bevel=0.0)
        ramp(rx, 2.5, cy - w / 2 - 0.05, zb + 0.55, cy - 5.3, P, m=P["gunmetal"])
        pipe([(5.2, cy - w / 2 - 0.1, 1.3), (3.6, cy - w / 2 - 0.1, 1.2), (0.6, cy - 2.95, 1.0), (-2.0, cy - 3.0, 1.1), (-4.5, cy - 2.7, 1.4)], 0.07, P["steel"], P["dark"])
        cable((-6.0, cy - 2.6, 2.6), (-3.2, cy - 2.9, 2.5), 0.3, P["rubber"]); cable((-3.2, cy - 2.9, 2.5), (0.2, cy - 2.95, 2.4), 0.35, P["rubber"])
        lamp(5.6, cy - 2.0, 3.9, P, 0.1, post=0.5)
        lamp(-3.4, cy - 2.9, 4.3, P, 0.1, post=0.45)
        lamp(1.6, cy - 2.9, 4.2, P, 0.1, post=0.45)
        if detail:
            prop("modular_industrial_pipes_01_pipe03", "modular_industrial_pipes_01", (-0.8, cy + 2.0, top(-0.8) + 0.1), 90, 0.7)
            prop("modular_industrial_pipes_01_pipe05", "modular_industrial_pipes_01", (2.9, cy - 1.8, top(2.9) + 0.1), 0, 0.7)
            prop("pipe_valve_large_metal", "modular_pipes", (-5.0, cy - 1.6, top(-5.0) + 0.1), 0, 0.8)
            prop("utility_box_01_box_low", "utility_box_01", (-5.6, cy + 2.0, top(-5.6) + 0.1), 0, 0.5)
            prop("security_light", "security_light", (-6.3, cy - 1.3, top(-6.3) + 1.2), 180, 0.6)
            dress(rng, [(-5.6, -4.4, cy + 1.4, cy + 2.2, top(-5.0) + 0.1), (-1.0, 2.6, cy + 1.3, cy + 2.2, top(1.0) + 0.1),
                        (-5.8, 2.6, cy - 2.2, cy - 1.6, top(-1.0) + 0.1)], P, [pm["gs-hull"][0], P["trim"], P["skid"]], 10, 0.8)
    def kit():
        # The prospecting kit at the ramp's foot: props, drums, tyres, pipe and plate stock; no crates (placeholder cubes).
        prop("old_military_compressor", "old_military_compressor", (-2.6, cy - 4.6, 0), 20, 0.7)
        prop("propane_tank", "propane_tank", (5.6, cy - 3.9, 0), 90, 0.6)
        prop("small_lpg_tank", "small_lpg_tank", (-4.7, cy - 3.9, 0), 0, 0.6)
        prop("utility_box_02", "utility_box_02", (4.4, cy - 4.9, 0), 160, 0.5)
        prop("modular_airduct_circular_double", "modular_airduct_circular_01", (0.2, cy - 5.2, 0), 10, 0.8)
        prop("exterior_aircon_unit_rusted", "exterior_aircon_unit", (6.2, cy - 2.6, 0), 90, 0.5)
        drums(0.6, cy - 4.3, 0, 4, rng, [P["accent"], P["steel"], pm["gs-hull"][1]], 1.0)
        for k in range(3):
            for z in range(2): tor(0.32, 0.12, -6.4 + k * 0.75, cy - 3.9, 0.12 + z * 0.22, P["rubber"])
        for k in range(5): lie(0.07, 2.2, -1.2 + k * 0.02, cy - 5.4 + k * 0.16, 0.07 + (k // 3) * 0.14, rng.choice((P["steel"], P["trim"])), "x", 8)
        for k in range(4): plate(1.2, 0.9, 0.05, 3.2 + k * 0.1, cy - 5.3 + k * 0.05, 0.03 + k * 0.05, rng.choice((P["trim"], P["skid"])), rot=rng.uniform(-0.15, 0.15), bevel=0.005)
        pipe([(-4.7, cy - 3.9, 0.6), (-4.7, cy - 3.4, 0.9), (-5.2, cy - 2.8, 1.5)], 0.05, P["rubber"])
        pipe([(-2.0, cy - 4.4, 0.5), (-1.0, cy - 3.9, 0.3), (-0.2, cy - 3.3, 1.2)], 0.045, P["rubber"])
        stain(-1.8, cy - 4.0, 0.01, 0.6, rng, P["scorch"]); stain(1.4, cy - 4.5, 0.01, 0.45, rng, P["scorch"])
    s = group(ship); k = group(kit) if detail else []
    rooted(s, (CX, CY, 0), (-3.0, 2.0, 5.0))      # listing to the south, bow up, yawed
    rooted(k, (CX, CY, 0), (0, 0, 5.0))
    return s + k




def gs_capsule(detail=True):
    """A re-entry capsule tipped on its side: a truncated cone, heat shield west, lying in a crumpled skirt, its hatch
    open on top with a ladder, four retro pods round its waist, cargo pods strewn about, a tarp over its nose."""
    rng = random.Random(11)
    cy = CY
    o = cone(-8.3, cy, 2.2, 3.5, 1.3, 12.0, P["hull"])
    o.rotation_euler = (0, math.pi / 2, 0); o.rotation_euler.y += math.radians(-6)
    cyl(3.55, 0.3, -8.3, cy, 2.2, P["scorch"], verts=48, rot=(0, math.pi / 2, 0))
    # A crumpled skirt under it, retro pods, a hatch and ladder, antenna.
    B(10.0, 6.0, 0.5, -3.0, cy, 0.0, P["skid"], bevel=0.1)
    for a in (0.8, 2.3, 3.9, 5.5):
        x, y, z = -4.0, cy + math.cos(a) * 2.9, 2.2 + math.sin(a) * 2.9
        if z < 0.3: continue
        lie(0.5, 1.4, x, y, z, P["gunmetal"], "x"); bell(-3.3, y, z, 0.3, 0.55, 0.7, P)
    B(1.4, 1.4, 0.3, -1.0, cy, 4.3, P["dark"], bevel=0.02)
    o = plate(1.3, 1.3, 0.08, -1.0, cy + 1.2, 4.9, P["trim"], tilt=math.radians(-70))
    for k in range(6):
        rod((1.2, cy - 1.6 - k * 0.0, 0), (1.2, cy - 1.6, 0.2), 0.02, P["steel"], verts=5)
    rod((0.8, cy - 1.2, 0.0), (-0.6, cy - 0.6, 4.2), 0.04, P["steel"], verts=6)
    rod((1.2, cy - 1.6, 0.0), (-0.2, cy - 1.0, 4.2), 0.04, P["steel"], verts=6)
    # A tarp over the nose, cargo pods about, drums.
    bpy.ops.mesh.primitive_uv_sphere_add(radius=2.0, location=(2.8, cy, 1.0), segments=24, ring_count=12)
    o = bpy.context.object; o.scale = (1.4, 1.2, 0.9); o.data.materials.append(P["cloth"])
    for k, (x, y) in enumerate(((5.6, cy - 2.6), (5.0, cy + 2.4), (-6.0, cy - 4.4), (3.5, cy - 5.0))):
        lie(0.7, 2.0, x, y, 0.7, P["trim"] if k % 2 else P["accent"], "x" if k % 2 else "y")
    if detail:
        crates(-1.5, cy - 5.4, 0, 5, rng, [P["hull"], P["trim"], P["accent"]])
        drums(1.8, cy - 4.4, 0, 3, rng, [P["accent"], P["steel"]])
        lamp(-1.0, cy, 5.2, P, 0.12, post=0.6)
        lamp(5.8, cy - 1.2, 2.2, P, 0.1, post=0.4)
    return []


def gs_tug(detail=True):
    """A stubby tug on four legs pushing a cargo sled ploughed into the dirt: the sled a flat deck of plate with
    containers, drums and a drill rig on it, a dozer blade dug in at its bow; the tug a boxy hull with a cab, two big
    scorched bells east."""
    rng = random.Random(5)
    cy = CY
    # The sled.
    B(10.0, 6.2, 0.55, -3.6, cy, 0.0, P["skid"], bevel=0.05)
    for sy in (-1, 1): B(10.2, 0.25, 0.3, -3.6, cy + sy * 3.0, 0.55, P["trim"], bevel=0.02)
    o = plate(0.15, 5.0, 1.6, -8.7, cy, 0.6, P["gunmetal"], bevel=0.02); o.rotation_euler.y = math.radians(-25)
    for k, (x, y, rz) in enumerate(((-7.0, cy - 1.6, 0.0), (-7.0, cy + 1.5, 0.0), (-4.2, cy - 1.7, 0.1), (-4.2, cy + 1.2, -0.08), (-1.6, cy + 1.4, 0.0))):
        B(2.3, 1.3, 1.3, x, y, 0.55, rng.choice((P["hull"], P["accent"], P["trim"])), rot=rz, bevel=0.03)
    for sx in (-1, 1):
        for sy in (-1, 1): rod((-1.6 + sx * 0.8, cy - 1.6 + sy * 0.8, 0.55), (-1.6, cy - 1.6, 4.6), 0.07, P["steel"], verts=6)
    cyl(0.2, 1.0, -1.6, cy - 1.6, 0.55, P["dark"], verts=12)
    # The tug.
    secs = [(1.2, octo(cy, 3.6, 2.6, 1.4, 0.5)), (2.2, octo(cy, 4.8, 3.4, 1.0, 0.6)), (5.4, octo(cy, 4.8, 3.4, 1.0, 0.6)), (6.4, octo(cy, 4.0, 3.0, 1.2, 0.5))]
    hull = loft_x(secs, P["hull"], bevel=0.08)
    B(2.0, 2.2, 1.2, 2.6, cy + 0.3, 4.4, P["hull"], bevel=0.04)
    for k in range(3): B(0.45, 0.04, 0.4, 1.9 + k * 0.5, cy - 0.83, 4.8, P["glass"], bevel=0.0)
    for yy in (-1.3, 1.3):
        bell(6.4, cy + yy, 2.5, 0.5, 0.95, 1.5, P); scorch_ring(9.0, cy + yy, 1.0, P, rx=1.5)
    for x in (2.4, 5.2):
        for sy in (-1, 1):
            leg((x, cy + sy * 2.2, 1.3), (x, cy + sy * 3.3, 0.9), (x, cy + sy * 3.8), P, 0.17)
    B(1.2, 1.2, 0.7, 0.6, cy, 1.5, P["gunmetal"], bevel=0.03)
    if detail:
        drums(-1.6, cy - 5.0, 0, 4, rng, [P["accent"], P["steel"]])
        crates(4.0, cy - 4.8, 0, 4, rng, [P["hull"], P["trim"]])
        lamp(2.6, cy + 0.3, 5.9, P, 0.12, post=0.3)
        lamp(-1.6, cy - 1.6, 4.8, P, 0.1)
    return [hull]


# --- Kessler-Hayashi ----------------------------------------------------------------------------------------------
def kh_dropship(detail=True):
    """An armoured drop ship on four articulated legs, yawed a little: a tapered hull with a ridge down its back (two
    top facets grading the light), its back and flanks skinned in bevelled plates with dark seams and recessed panels,
    the nose long with the bridge glazing lit cyan, a comms pod on the north shoulder and a sponson on the south (the
    outline asymmetric), pipe bundles along the chines, cables slung between posts, ducts and tanks on the back, twin
    bells in cowls and a swept tail fin aft, the lower courses gunmetal under the paint, a lit bay with a ramp south."""
    rng = random.Random(21)
    cy = CY
    pm = PLATES
    Z = 1.2
    W, H, C, R = 4.9, 3.5, 0.5, 0.45
    secs = [(-8.6, chine(cy, 1.5, 1.3, Z + 0.95, 0.3, 0.12)), (-7.4, chine(cy, 3.4, 2.6, Z + 0.4, 0.45, 0.3)), (-6.0, chine(cy, W, H, Z, C, R)),
            (2.6, chine(cy, W, H, Z, C, R)), (4.6, chine(cy, W - 0.5, H - 0.2, Z + 0.1, C, R - 0.1)), (6.0, chine(cy, 3.6, 2.6, Z + 0.4, 0.45, 0.2))]
    def ship():
        out = [loft_x(secs, P["dark"], bevel=0.03)]                           # the frame, dark in every seam
        loft_x(secs[:3], P["hull"], bevel=0.06)                               # the nose's paint
        loft_x(secs[3:], P["hull"], bevel=0.06)                               # the stern's
        ctr = (cy, Z + 1.6)
        s = secs[2][1]
        back = [pm["kh-hull"][0], pm["kh-hull"][1], pm["kh-hull"][2], pm["kh-hull"][1], pm["kh-trim"][0], pm["kh-trim"][1], pm["kh-trim"][0], P["gunmetal"], pm["kh-bright"][0]]
        side = [pm["kh-hull"][0], pm["kh-hull"][1], pm["kh-hull"][2], pm["kh-trim"][0], pm["kh-trim"][1], P["gunmetal"], pm["kh-bright"][0]]
        low = [P["gunmetal"], pm["kh-trim"][1], P["gunmetal"]]
        for xa, xb in ((-5.9, -2.1), (-1.9, 0.4), (0.6, 2.5)):
            # Big plates first (uneven), then a sparse layer of small plates and panels over them: the hierarchy vanilla's
            # hulls have (large smooth panels, dense clusters); one size of plate everywhere read as tiles (round 3).
            facet_plates(xa, xb, s[4], s[5], ctr, back, rng, size=1.5, t=0.06, gap=0.12, recess=0.1, ny=2, jitter=0.45)   # the north top facet
            facet_plates(xa, xb, s[5], s[6], ctr, back, rng, size=1.5, t=0.06, gap=0.12, recess=0.1, ny=2, jitter=0.45)   # the south top facet
            facet_plates(xa, xb, s[5], s[6], ctr, back + [P["dark"]], rng, size=0.5, t=0.04, gap=0.08, skip=0.72, ny=4, lift=0.06)
            facet_plates(xa, xb, s[4], s[5], ctr, back + [P["dark"]], rng, size=0.5, t=0.04, gap=0.08, skip=0.72, ny=4, lift=0.06)
            facet_plates(xa, xb, s[6], s[7], ctr, side, rng, size=1.2, t=0.06, gap=0.09, recess=0.08, ny=1, jitter=0.45)  # the south chine
            facet_plates(xa, xb, s[7], s[8], ctr, side, rng, size=1.3, t=0.07, gap=0.13, recess=0.1, ny=2, jitter=0.45)    # the south flank
            facet_plates(xa, xb, s[7], s[8], ctr, side + [P["dark"]], rng, size=0.45, t=0.04, gap=0.08, skip=0.75, ny=5, lift=0.07)
            facet_plates(xa, xb, s[8], s[0], ctr, low, rng, size=1.0, t=0.06, gap=0.09, ny=1)                             # the lower chine
            facet_plates(xa, xb, s[3], s[4], ctr, side, rng, size=1.2, t=0.06, gap=0.09, recess=0.08, ny=1, jitter=0.45)  # the north chine
            # A rib frame at each segment's end, standing proud, the corporate stripe low on the flank.
            B(0.16, W + 0.16, H + R + 0.1, xb + 0.1, cy, Z - 0.04, P["dark"], bevel=0.02)
            plate(xb - xa - 0.5, 0.05, 0.1, (xa + xb) / 2, cy - W / 2 - 0.12, Z + 0.95, P["accent"], bevel=0.0)
        # The nose and the stern, tapering: plated the same way, the plates following the taper.
        for xa, xb, A, Bk in ((-8.5, -7.4, secs[0][1], secs[1][1]), (-7.4, -6.0, secs[1][1], secs[2][1]), (2.7, 4.6, secs[3][1], secs[4][1]), (4.7, 5.9, secs[4][1], secs[5][1])):
            for i, j, mats, n_, rec in ((4, 5, back, 2, 0.1), (5, 6, back, 2, 0.1), (6, 7, side, 1, 0.08), (7, 8, side, 2, 0.1), (8, 0, low, 1, 0.0), (3, 4, side, 1, 0.08)):
                facet_plates(xa, xb, A[i], A[j], ctr, mats, rng, size=1.1, t=0.06, gap=0.09, recess=rec, ny=n_, end=(Bk[i], Bk[j]), jitter=0.45)
        # Pipe bundles along both chines, their supports; cable slung between posts along the ridge.
        for sy, zz in ((-1, Z + H - 0.35), (1, Z + H - 0.35)):
            for k, r in enumerate((0.07, 0.05, 0.06)):
                lie(r, 8.4, -1.7, cy + sy * (W / 2 + 0.02 - k * 0.02), zz - k * 0.17, P["steel"] if k != 1 else P["accent"], "x", 10)
            for x in (-5.0, -2.5, 0.0, 2.2): B(0.12, 0.3, 0.55, x, cy + sy * (W / 2 - 0.05), zz - 0.5, P["dark"], bevel=0.0)
        posts = [(-5.4, cy, Z + H + R), (-3.2, cy, Z + H + R), (-0.8, cy, Z + H + R), (1.6, cy, Z + H + R)]
        for x, y, z in posts: rod((x, y, z), (x, y, z + 0.7), 0.035, P["steel"], verts=6)
        for (x0, y0, z0), (x1, y1, z1) in zip(posts, posts[1:]):
            cable((x0, y0, z0 + 0.7), (x1, y1, z1 + 0.7), 0.22, P["rubber"]); cable((x0, y0 - 0.06, z0 + 0.62), (x1, y1 - 0.06, z1 + 0.62), 0.25, P["rubber"], r=0.009)
        # On the back: ducts and a fan north, two tanks aft, a cabinet, hatches with hinges; the sensor mast.
        prop("modular_airduct_circular_triple", "modular_airduct_circular_01", (-4.4, cy + 1.3, Z + H + 0.1), 90, 0.9)
        prop("modular_airduct_circular_fan", "modular_airduct_circular_01", (-2.2, cy + 1.4, Z + H + 0.15), 0, 0.9)
        prop("modular_airduct_rectangular_converter", "modular_airduct_circular_01", (-0.6, cy + 1.2, Z + H + 0.1), 90, 0.9)
        prop("pipe_valve_large_metal", "modular_pipes", (0.9, cy - 1.3, Z + H + 0.15), 0, 0.8)
        prop("power_box_01_box", "power_box_01", (2.0, cy - 1.4, Z + H + 0.2), -90, 0.5)
        prop("utility_box_01_box_low", "utility_box_01", (-3.6, cy - 1.5, Z + H + 0.15), 0, 0.45)
        for x in (1.4, 2.2):
            lie(0.36, 1.5, x, cy + 1.5, Z + H + 0.5, pm["kh-trim"][0], "y", 18); sph(0.36, x, cy + 2.2, Z + H + 0.5, pm["kh-trim"][0])
            B(0.2, 0.9, 0.5, x, cy + 1.4, Z + H + 0.02, P["dark"], bevel=0.01)
        for x, y in ((-4.8, cy - 1.0), (-2.6, cy - 0.3), (0.2, cy - 1.0), (-1.4, cy + 0.6)):
            B(0.8, 0.6, 0.12, x, y, Z + H + 0.25, P["dark"], bevel=0.01)
            for sx in (-0.3, 0.3): cyl(0.03, 0.14, x + sx, y - 0.32, Z + H + 0.25, P["steel"], verts=6, rot=(math.pi / 2, 0, 0))
        mx, my = -4.6, cy + 0.6
        rod((mx, my, Z + H + R), (mx, my, Z + H + R + 2.2), 0.06, P["steel"], verts=8)
        cone(mx, my, Z + H + R + 1.8, 0.05, 0.42, 0.25, pm["kh-trim"][0], axis="z", open_end=True).rotation_euler = (math.radians(120), 0, math.radians(-40))
        lamp(mx, my, Z + H + R + 2.35, P, 0.11)
        # The comms pod on the north shoulder forward (asymmetric), the sponson on the south flank aft.
        lie(0.42, 2.4, -3.6, cy + 1.9, Z + H + 0.25, pm["kh-trim"][1], "x", 18)
        sph(0.42, -4.8, cy + 1.9, Z + H + 0.25, pm["kh-trim"][1]); cone(-2.4, cy + 1.9, Z + H + 0.25, 0.42, 0.2, 0.8, P["gunmetal"])
        B(2.8, 1.1, 1.3, 1.0, cy - W / 2 - 0.5, Z + 1.0, pm["kh-hull"][1], bevel=0.06)
        plate(2.6, 0.08, 0.4, 1.0, cy - W / 2 - 1.08, Z + 1.7, pm["kh-trim"][0], bevel=0.01)
        B(2.2, 0.05, 0.12, 1.0, cy - W / 2 - 1.1, Z + 1.3, P["glass"], bevel=0.0)
        for k in range(3): B(0.5, 0.9, 0.18, 0.0 + k * 1.0, cy - W / 2 - 0.5, Z + 2.3, P["dark"], bevel=0.01)
        # The bridge west: a raked glazing band on the nose's south face and its front, lit; a brow over it.
        for k in range(3):
            plate(0.5, 0.06, 0.36, -6.9 + k * 0.55, cy - 2.2 - k * 0.06, Z + 2.65 - k * 0.04, P["glass"], bevel=0.0).rotation_euler.z = math.radians(-6)
        o = plate(0.06, 1.3, 0.4, -8.4, cy, Z + 2.3, P["glass"], bevel=0.0); o.rotation_euler.y = math.radians(-25)
        plate(1.9, 0.08, 0.14, -6.9, cy - 2.28, Z + 2.95, pm["kh-trim"][0], bevel=0.0).rotation_euler.z = math.radians(-6)
        # The stern: an engine block, two bells in cowls east, a tail fin with the corporate stripe.
        B(1.2, 3.4, 2.4, 6.0, cy, Z + 0.45, P["gunmetal"], bevel=0.08)
        for yy in (-1.15, 1.15):
            cyl(0.9, 1.5, 5.5, cy + yy, Z + 1.7, pm["kh-trim"][1], verts=28, rot=(0, math.pi / 2, 0))
            tor(0.9, 0.06, 6.4, cy + yy, Z + 1.7, P["dark"]).rotation_euler = (0, math.pi / 2, 0)
            bell(6.7, cy + yy, Z + 1.7, 0.55, 0.8, 1.1, P)
        plate(2.4, 0.16, 2.3, 4.3, cy + 0.0, Z + H + 1.1, pm["kh-hull"][0], bevel=0.03).rotation_euler.y = math.radians(-22)
        plate(2.1, 0.2, 0.26, 4.5, cy + 0.0, Z + H + 1.5, P["accent"], bevel=0.0).rotation_euler.y = math.radians(-22)
        lamp(3.3, cy, Z + H + 2.2, P, 0.09)
        # Legs at the hull's shoulders, a pad each on the ground.
        for x in (-5.0, 3.4):
            for sy in (-1, 1):
                leg((x, cy + sy * (W / 2 - 0.3), Z + 0.5), (x + 0.2, cy + sy * (W / 2 + 0.9), 1.15), (x + 0.3, cy + sy * (W / 2 + 1.4)), P, 0.2)
        # The bay south: a lit opening, its door raised, the ramp down.
        B(2.4, 0.3, 2.1, -1.2, cy - W / 2 + 0.1, Z + 0.3, P["scorch"], bevel=0.0)
        B(2.2, 0.06, 1.9, -1.2, cy - W / 2 + 0.17, Z + 0.4, P["glass"], bevel=0.0)
        plate(2.6, 1.4, 0.12, -1.2, cy - W / 2 - 0.55, Z + 3.0, P["gunmetal"], tilt=math.radians(22), bevel=0.02)
        ramp(-1.2, 2.3, cy - W / 2 - 0.05, Z + 0.25, cy - 5.2, P, m=P["gunmetal"])
        for x in (-5.2, -3.4, 3.2):
            B(0.3, 0.05, 0.1, x, cy - W / 2 - 0.14, Z + 2.85, P["light"], bevel=0.0)
        lamp(-1.2, cy - W / 2 - 0.3, Z + H + 0.3, P, 0.1, post=0.3)
        return out
    def kit():
        drums(-3.8, cy - 4.3, 0, 3, rng, [pm["kh-trim"][1], P["steel"]], 0.9)
        prop("utility_box_02", "utility_box_02", (1.6, cy - 4.6, 0), 170, 0.45)
        prop("power_box_01_box", "power_box_01", (2.6, cy - 4.3, 0), 90, 0.5)
    s = group(ship); k = group(kit) if detail else []
    rooted(s, (CX, CY, 0), (0, 0, -4.0)); rooted(k, (CX, CY, 0), (0, 0, -4.0))
    return s + k


def kh_tower(detail=True):
    """A vertical lander: an octagonal module tower on a flared engine skirt at the footprint's middle, four long legs
    to its corners, a pod either side on a trussed walkway, a ramp south, a mast and dish on top."""
    rng = random.Random(3)
    cy = CY
    cone(CX, cy, 0.6, 3.6, 2.6, 1.6, P["gunmetal"], axis="z")
    for a in (0.6, 2.2, 3.9, 5.5):
        bell(CX + math.cos(a) * 2.0 - 0.3, cy + math.sin(a) * 2.0, 0.5, 0.35, 0.6, 0.6, P)
    for k, (h, r) in enumerate(((2.2, 2.3), (2.4, 2.4), (2.0, 2.1), (1.6, 1.7))):
        z = 2.2 + sum(x[0] for x in ((2.2, 2.3), (2.4, 2.4), (2.0, 2.1), (1.6, 1.7))[:k])
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=r, depth=h, location=(CX, cy, z + h / 2), rotation=(0, 0, math.pi / 8))
        o = bpy.context.object; o.data.materials.append(P["hull"] if k % 2 == 0 else P["trim"])
        md = o.modifiers.new("b", "BEVEL"); md.width = 0.08; md.segments = 3
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=r + 0.12, depth=0.15, location=(CX, cy, z + h), rotation=(0, 0, math.pi / 8))
        bpy.context.object.data.materials.append(P["dark"])
    for k in range(4):
        B(0.5, 0.05, 0.35, CX - 0.9 + k * 0.6, cy - 2.25, 5.2, P["glass"], bevel=0.0)
    rod((CX, cy, 10.4), (CX, cy, 12.6), 0.06, P["steel"], verts=8); lamp(CX, cy, 12.7, P, 0.12)
    for sx, sy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        leg((CX + sx * 2.6, cy + sy * 2.0, 3.0), (CX + sx * 5.0, cy + sy * 3.0, 1.6), (CX + sx * 6.8, cy + sy * 3.5), P, 0.22)
    for sx in (-1, 1):
        B(3.2, 3.0, 2.2, CX + sx * 5.6, cy + 0.2, 0.6, P["hull"], bevel=0.08)
        B(3.4, 3.2, 0.14, CX + sx * 5.6, cy + 0.2, 2.8, P["trim"], bevel=0.02)
        for k in range(2):
            rod((CX + sx * 2.3, cy + 0.2 + (k - 0.5) * 1.2, 2.6), (CX + sx * 4.0, cy + 0.2 + (k - 0.5) * 1.2, 2.6), 0.06, P["steel"], verts=8)
        B(1.8, 1.4, 0.1, CX + sx * 3.2, cy + 0.2, 2.5, P["dark"], bevel=0.0)
        for y in (-0.9, 0.9): B(0.3, 0.05, 0.1, CX + sx * 5.6, cy - 1.32, 2.0, P["light"], bevel=0.0)
    ramp(CX + 0.4, 2.4, cy - 2.4, 2.1, cy - 6.0, P, m=P["trim"])
    if detail:
        crates(CX + 2.6, cy - 5.2, 0, 4, rng, [P["hull"], P["trim"]], 0.9)
    return []


def kh_delta(detail=True):
    """A flat arrowhead lifting body on three legs: a blended wedge hull, nose west, two engine nacelles aft with
    their bells east, a raised cockpit on the nose, a clamshell cargo door raised south, a fin on each nacelle."""
    rng = random.Random(9)
    cy = CY
    Z = 0.9
    secs = [(-8.5, octo(cy, 1.4, 1.0, Z + 0.5, 0.3)), (-6.0, octo(cy, 3.4, 1.9, Z + 0.2, 0.5)), (-2.0, octo(cy, 5.8, 2.6, Z, 0.7)),
            (2.5, octo(cy, 7.4, 2.9, Z, 0.8)), (5.6, octo(cy, 7.0, 2.8, Z, 0.8))]
    hull = loft_x(secs, P["hull"], bevel=0.1)
    B(2.0, 1.6, 0.9, -5.6, cy, Z + 2.0, P["trim"], bevel=0.06)
    for k in range(3): B(0.4, 0.04, 0.3, -6.1 + k * 0.45, cy - 0.82, Z + 2.4, P["glass"], bevel=0.0)
    for sy in (-1, 1):
        lie(1.05, 5.0, 3.6, cy + sy * 2.4, Z + 1.6, P["trim"], "x", 28)
        bell(6.1, cy + sy * 2.4, Z + 1.6, 0.6, 0.95, 1.4, P); scorch_ring(8.9, cy + sy * 2.4, 1.0, P, rx=1.5)
        plate(1.8, 0.14, 1.6, 4.4, cy + sy * 2.4, Z + 3.4, P["hull"], bevel=0.03).rotation_euler.y = math.radians(-25)
        lamp(3.6, cy + sy * 2.4, Z + 4.2, P, 0.08)
    leg((-5.0, cy, Z + 0.3), (-5.2, cy - 0.6, 0.9), (-5.3, cy - 0.9), P, 0.18)
    for sy in (-1, 1): leg((3.2, cy + sy * 3.0, Z + 0.3), (3.4, cy + sy * 3.9, 0.9), (3.5, cy + sy * 4.3), P, 0.2)
    B(3.2, 0.3, 1.6, -0.5, cy - 2.6, Z + 0.4, P["scorch"], bevel=0.0)
    plate(3.4, 2.0, 0.12, -0.5, cy - 3.4, Z + 2.6, P["trim"], tilt=math.radians(35), bevel=0.02)
    ramp(-0.5, 3.0, cy - 2.7, Z + 0.3, cy - 6.2, P, m=P["trim"])
    for x in (-4.0, 1.5, 4.0): B(0.3, 0.05, 0.1, x, cy - hull_width(secs, x)[0] / 2 - 0.02, Z + 2.0, P["light"], bevel=0.0)
    if detail:
        crates(2.0, cy - 5.0, 0, 4, rng, [P["hull"], P["trim"]], 0.9)
    return [hull]


CONCEPTS = {"gs-barge": gs_barge, "gs-capsule": gs_capsule, "gs-tug": gs_tug,
            "kh-dropship": kh_dropship, "kh-tower": kh_tower, "kh-delta": kh_delta}
PICK = {"gs": "gs-barge", "kh": "kh-dropship"}

if MODE == "concept":
    fn = CONCEPTS[WHO]
    model = group(lambda: fn(detail=True))
    lpkit.bevel_all(model, 0.02)
    # The footprint under it: a thin dark frame, the ground within its own.
    frame = lpkit.mat("fp", (0.12, 0.12, 0.12), metal=0.0, rough=0.9, grime=0.0)
    for (x, y, sx, sy) in ((CX, Y0, X1 - X0, 0.08), (CX, Y1, X1 - X0, 0.08), (X0, CY, 0.08, Y1 - Y0), (X1, CY, 0.08, Y1 - Y0)):
        B(sx, sy, 0.02, x, y, 0, frame, bevel=0.0)
    ground, sun, world = lpkit.stage(scene, 20, 3.5)
    lpkit.emission(P["light"], 3.0); lpkit.emission(P["glass"], 2.0)
    ground.hide_render = False
    lpkit.render(scene, OUT)
    print("concept", WHO, OUT)
    sys.exit(0)

if MODE == "build":
    name = PICK[WHO]
    fn = CONCEPTS[name]
    model = group(lambda: fn(detail=True))
    # Grime: dirt and dust over the hulls (lpkit.dirty, as the units carry), Grubstake's caked with mud up its flank.
    if not CLAY:
        for o in model:
            for sl in o.material_slots:
                m = sl.material
                if m and m.name.split("-")[0] in ("gs", "kh") and m.name.split("-")[1] in ("hull", "plate", "trim", "trimplate", "deck") and not m.get("lp_dirty"):
                    for nd in m.node_tree.nodes:                             # deeper occlusion between plates
                        if nd.type == "AMBIENT_OCCLUSION": nd.inputs["Distance"].default_value = 0.9
                    if WHO == "gs":
                        lpkit.dirty(m, dirt=0.5, dust=0.25, rust=0.6, mud=0.75, mud_top=1.6)
                    else:
                        lpkit.dirty(m, dirt=0.2, dust=0.12, rust=0.12, mud=0.3, mud_top=1.4)
                    m["lp_dirty"] = True
        model += lpkit.scatter(model, {P["hull"], P["trim"]}, P["dark"], P["steel"], 17, density=float(os.environ.get("LP_DENSITY", 5.0)))
    lpkit.bevel_all(model, 0.02)
    ground, sun, world = lpkit.stage(scene, 20, 3.5)
    # (A harder sun and less sky: the first renders were mid-grey all over, no dark recesses, no highlights.)
    sun.data.energy = 4.6; sun.data.angle = math.radians(2)
    # (The lights lower than the small buildings': white-hot emitters by day read as toys, lpkit.palette_faction.)
    lpkit.emission(P["light"], 2.4); lpkit.emission(P["glass"], 1.0 if WHO == "gs" else 1.6)
    FILL = 0.3
    lpkit.passes(scene, OUT, 1, lambda f: None, model, {P["light"], P["glass"]}, ground, sun, world, fill=FILL)
    print("rendered", name, OUT)
